-- Snapshot.lua
-- Captures party members and keeps a "sticky" list for LFG runs (so leavers stay).
-- Enhanced:
--   • stores assigned ROLE (TANK/HEALER/DAMAGER)
--   • best-effort specialization capture (specID) + caching via INSPECT_READY
--
-- Snapshot strategy:
--   M+  → clean SnapshotGroupMembers at key completion (non-sticky, instant).
--          Locked immediately so late leavers don't overwrite the roster.
--   LFG → sticky MergeSnapshotMembers throughout the run (leavers are NEVER removed).
--          No locking needed: sticky merge always preserves previous members.

MPW = MPW or {}

MPW.PartySnapshot = MPW.PartySnapshot or {
    takenAt = 0,
    runType = "NONE",
    members = {},
    valid   = false,
    locked  = false,  -- M+ only: prevents ShowWhisperWindow from re-snapshotting
}

local SNAPSHOT_FRESH_SECONDS = 900 -- 15 minutes

-- ============================================================
-- Specialization cache (best effort)
-- ============================================================
MPW.SpecCache = MPW.SpecCache or {} -- [guid] = specID

local Inspect = {
    queue   = {},
    queued  = {},
    current = nil,
}

local INSPECT_TIMEOUT = 2.0
local INSPECT_GAP     = 0.35
local lastInspectAt   = 0

local function CanTryInspect(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsUnit(unit, "player")        then return false end
    if UnitIsDeadOrGhost(unit)           then return false end
    if not CanInspect                    then return false end
    if not NotifyInspect                 then return false end
    return CanInspect(unit, false)
end

local function QueueInspect(unit)
    if not CanTryInspect(unit) then return end
    local guid = UnitGUID(unit)
    if not guid or guid == ""  then return end
    if MPW.SpecCache[guid]      then return end
    if Inspect.queued[guid]     then return end
    table.insert(Inspect.queue, { unit = unit, guid = guid })
    Inspect.queued[guid] = true
end

local function PopNextInspectable()
    while #Inspect.queue > 0 do
        local item = table.remove(Inspect.queue, 1)
        if item and item.guid and Inspect.queued[item.guid] then
            if UnitExists(item.unit) and UnitGUID(item.unit) == item.guid and CanTryInspect(item.unit) then
                return item
            end
            Inspect.queued[item.guid] = nil
        end
    end
    return nil
end

local function ProcessInspectQueue()
    if Inspect.current then return end
    local now = MPW.Now and MPW.Now() or time()
    if (now - lastInspectAt) < INSPECT_GAP then
        C_Timer.After(INSPECT_GAP, ProcessInspectQueue)
        return
    end

    local item = PopNextInspectable()
    if not item then return end

    Inspect.current = { unit = item.unit, guid = item.guid, startedAt = now }
    lastInspectAt = now
    NotifyInspect(item.unit)

    C_Timer.After(INSPECT_TIMEOUT, function()
        if Inspect.current and Inspect.current.guid == item.guid then
            if ClearInspectPlayer then ClearInspectPlayer() end
            Inspect.queued[item.guid] = nil
            Inspect.current = nil
            C_Timer.After(0.1, ProcessInspectQueue)
        end
    end)
end

local inspectFrame = CreateFrame("Frame")
inspectFrame:RegisterEvent("INSPECT_READY")
inspectFrame:SetScript("OnEvent", function(_, _, guid)
    if not guid or not Inspect.current or guid ~= Inspect.current.guid then return end

    local unit   = Inspect.current.unit
    local specID = 0
    if unit and UnitExists(unit) and UnitGUID(unit) == guid and GetInspectSpecialization then
        specID = GetInspectSpecialization(unit) or 0
    end

    if specID and specID > 0 then MPW.SpecCache[guid] = specID end

    if ClearInspectPlayer then ClearInspectPlayer() end
    Inspect.queued[guid] = nil
    Inspect.current = nil
    C_Timer.After(0.1, ProcessInspectQueue)
end)

function MPW.QueueInspectForGroup()
    if not IsInGroup() then return end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do QueueInspect("raid" .. i) end
    else
        for i = 1, 4 do QueueInspect("party" .. i) end
    end
    ProcessInspectQueue()
end

-- ============================================================
-- Lock helpers (M+ only)
-- ============================================================

-- Lock: prevents ShowWhisperWindow from re-snapshotting (M+ use only).
-- For LFG we never lock; sticky merge already handles leavers correctly.
function MPW.LockSnapshot()
    if MPW.PartySnapshot then MPW.PartySnapshot.locked = true end
end

-- Unlock: called when the send window is closed or a new run starts.
function MPW.UnlockSnapshot()
    if MPW.PartySnapshot then MPW.PartySnapshot.locked = false end
end

-- ============================================================
-- State helpers
-- ============================================================

function MPW.IsSnapshotFresh()
    if not MPW.PartySnapshot or not MPW.PartySnapshot.valid then return false end
    local age = (MPW.Now() or time()) - (MPW.PartySnapshot.takenAt or 0)
    return age >= 0 and age <= SNAPSHOT_FRESH_SECONDS
end

-- Hard reset: wipes the snapshot. Must be called at the start of every new run
-- so members from previous runs never bleed through.
function MPW.ResetPartySnapshot(runType)
    MPW.PartySnapshot = {
        takenAt = MPW.Now(),
        runType = runType or "NONE",
        members = {},
        valid   = false,
        locked  = false,
    }
end

-- ============================================================
-- Internal helpers
-- ============================================================

local function GetMyGUID()
    return UnitGUID("player")
end

local function InferRoleFromSpec(specID)
    if not specID or specID <= 0     then return nil end
    if not GetSpecializationInfoByID then return nil end
    local _, _, _, _, specRole = GetSpecializationInfoByID(specID)
    if specRole == "TANK" or specRole == "HEALER" or specRole == "DAMAGER" then
        return specRole
    end
    return nil
end

local function AddMember(tbl, existing, unit)
    if not UnitExists(unit) then return end
    local name, realm = UnitName(unit)
    if not name then return end

    local full = name
    if realm and realm ~= "" then full = name .. "-" .. realm end

    -- Skip self: compare by GUID (reliable) and by name as fallback
    local myGUID = GetMyGUID()
    local unitGUID = UnitGUID(unit)
    if myGUID and unitGUID and unitGUID == myGUID then return end
    if UnitIsUnit(unit, "player") then return end

    if existing[full] then return end

    local classFile = select(2, UnitClass(unit))
    local guid      = unitGUID
    local role      = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"

    local specID = 0
    if guid and MPW.SpecCache and MPW.SpecCache[guid] then
        specID = MPW.SpecCache[guid]
    elseif GetInspectSpecialization then
        specID = GetInspectSpecialization(unit) or 0
    end

    if (role == "NONE" or role == "") and specID > 0 then
        role = InferRoleFromSpec(specID) or role
    end

    table.insert(tbl, {
        fullName  = full,
        classFile = classFile,
        role      = role,
        guid      = guid,
        specID    = specID > 0 and specID or nil,
    })
    existing[full] = true
end

-- ============================================================
-- Clean snapshot (non-sticky) — M+ and manual use
-- ============================================================
function MPW.SnapshotGroupMembers(runType)
    if not IsInGroup() then
        MPW.PartySnapshot = {
            takenAt = MPW.Now(),
            runType = runType or "NONE",
            members = {},
            valid   = false,
            locked  = false,
        }
        return false
    end

    if MPW.QueueInspectForGroup then MPW.QueueInspectForGroup() end

    local members  = {}
    local existing = {}

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            AddMember(members, existing, "raid" .. i)
            if #members >= (MPW.MAX_ROWS or 5) then break end
        end
    else
        for i = 1, 4 do
            AddMember(members, existing, "party" .. i)
            if #members >= (MPW.MAX_ROWS or 5) then break end
        end
    end

    MPW.PartySnapshot.takenAt = MPW.Now()
    MPW.PartySnapshot.runType = runType or "NONE"
    MPW.PartySnapshot.members = members
    MPW.PartySnapshot.valid   = (#members > 0)
    MPW.PartySnapshot.locked  = false

    return MPW.PartySnapshot.valid
end

-- ============================================================
-- Sticky merge — LFG use
-- Adds new members, NEVER removes existing ones (leavers stay forever).
-- No cap trimming: we reset at run start so overflow cannot happen across runs,
-- and a single 5-person dungeon can never overflow MAX_ROWS = 5.
-- ============================================================
function MPW.MergeSnapshotMembers(runType)
    -- Not in group: keep snapshot as-is (leavers must stay visible)
    if not IsInGroup() then
        return MPW.PartySnapshot and MPW.PartySnapshot.valid
    end

    if MPW.QueueInspectForGroup then MPW.QueueInspectForGroup() end

    -- If run type changed, start fresh
    if not MPW.PartySnapshot or MPW.PartySnapshot.runType ~= runType then
        MPW.PartySnapshot = {
            takenAt = MPW.Now(),
            runType = runType,
            members = {},
            valid   = false,
            locked  = false,
        }
    end

    -- Build existing set from current snapshot
    local existing = {}
    for _, m in ipairs(MPW.PartySnapshot.members or {}) do
        existing[m.fullName] = true
    end

    -- Add any members not yet in snapshot (leavers already in table are untouched)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            AddMember(MPW.PartySnapshot.members, existing, "raid" .. i)
        end
    else
        for i = 1, 4 do
            AddMember(MPW.PartySnapshot.members, existing, "party" .. i)
        end
    end

    MPW.PartySnapshot.takenAt = MPW.Now()
    MPW.PartySnapshot.runType = runType
    MPW.PartySnapshot.valid   = (#MPW.PartySnapshot.members > 0)
    -- NOTE: never set locked here; LFG snapshots are never locked

    return MPW.PartySnapshot.valid
end
