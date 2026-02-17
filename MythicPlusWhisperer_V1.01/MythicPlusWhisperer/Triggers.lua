-- Triggers.lua
-- Completion detection (M+ + LFG) + fallback for runs without reward.
-- Uses sticky snapshot for LFG so leavers stay in the list.
--
-- Snapshot strategy:
--   M+  → clean snapshot at CHALLENGE_MODE_COMPLETED → locked → open UI.
--          Lock prevents ShowWhisperWindow from overwriting with a smaller group
--          if people leave right after the key ends.
--
--   LFG → sticky merge throughout the entire run (reset only on NEW instance entry).
--          Leavers accumulate and are NEVER removed.
--          No locking needed: sticky merge is inherently safe.
--          The window is opened only after the run ends.

MPW = MPW or {}

local triggerFrame = CreateFrame("Frame")
triggerFrame:RegisterEvent("CHALLENGE_MODE_START")
triggerFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
triggerFrame:RegisterEvent("LFG_COMPLETION_REWARD")
triggerFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
triggerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
triggerFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
triggerFrame:RegisterEvent("BOSS_KILL")

local openedThisMplus = false
local lastOpenAt      = 0
local WasInGroup      = false

-- LFG run state
local LFG_InInstance = false
local LFG_EnteredAt  = 0
local LFG_RunActive  = false
local LFG_BossKills  = 0

-- ============================================================
-- Helpers
-- ============================================================

local function IsInLFGPartyInstance()
    local inInstance, instType = IsInInstance()
    if not inInstance then return false end
    if instType ~= "party" and instType ~= "scenario" and instType ~= "raid" then
        return false
    end
    -- Exclude active M+ challenge
    if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
       and C_ChallengeMode.IsChallengeModeActive() then
        return false
    end
    return true
end

local function ThrottleOpen()
    local t = MPW.Now()
    if (t - lastOpenAt) < 1 then return false end
    lastOpenAt = t
    return true
end

-- Open the UI from the current snapshot (no re-snapshotting).
-- Used for the leave-group fallback path in LFG.
local function OpenUIFromSnapshot(runType)
    if not MPW.IsSnapshotFresh() then
        MPW.Print("No snapshot available (party list empty).")
        return
    end
    MPW.CurrentRunType = runType
    if MPW.RefreshRunContext then MPW.RefreshRunContext() end
    MPW.PendingOpen = false
    C_Timer.After(0.1, function()
        MPW.ShowWhisperWindow(false)
    end)
end

-- Take a snapshot (or merge for LFG), optionally lock it, then open the UI.
--   snapshotNow : whether to capture members right now
--   lockAfter   : lock snapshot so ShowWhisperWindow won't re-snapshot (M+ only)
local function FinalizeAndOpen(runType, snapshotNow, lockAfter)
    if not ThrottleOpen() then return end

    MPW.CurrentRunType = runType
    if MPW.RefreshRunContext then MPW.RefreshRunContext() end

    if snapshotNow then
        if runType == "LFG" then
            -- Sticky: adds anyone still present without touching leavers
            if MPW.MergeSnapshotMembers then MPW.MergeSnapshotMembers("LFG") end
        else
            -- Clean: exact group at this moment (M+)
            if MPW.SnapshotGroupMembers then MPW.SnapshotGroupMembers(runType) end
        end
    end

    if lockAfter and MPW.LockSnapshot then
        MPW.LockSnapshot()
    end

    MPW.PendingOpen = true

    if MPW_Config and MPW_Config.showOnLeave then
        MPW.Print("Completion detected. Will show when you leave the group.")
        return
    end

    C_Timer.After(0.4, function()
        if MPW.PendingOpen then
            MPW.PendingOpen = false
            MPW.ShowWhisperWindow(false)
        end
    end)
end

-- ============================================================
-- Event handler
-- ============================================================

triggerFrame:SetScript("OnEvent", function(self, event)

    -- ==========================================================
    -- Mythic+
    -- ==========================================================
    if event == "CHALLENGE_MODE_START" then
        openedThisMplus = false
        -- Clean slate for this key
        if MPW.ResetPartySnapshot then MPW.ResetPartySnapshot("MPLUS") end
        if MPW.QueueInspectForGroup then
            C_Timer.After(1.0, function() MPW.QueueInspectForGroup() end)
        end
        return
    end

    if event == "CHALLENGE_MODE_COMPLETED" then
        if openedThisMplus then return end
        openedThisMplus = true
        -- snapshotNow=true (clean M+ group), lockAfter=true (prevent late-leaver overwrite)
        FinalizeAndOpen("MPLUS", true, true)
        return
    end

    -- ==========================================================
    -- LFG reward completion
    -- ==========================================================
    if event == "LFG_COMPLETION_REWARD" then
        -- Merge immediately while all players are still present.
        -- This is sticky: anyone who already left is already in the snapshot.
        if MPW.MergeSnapshotMembers then
            MPW.MergeSnapshotMembers("LFG")
        end

        -- Optional: auto party thanks
        if MPW_Config and MPW_Config.autoPartyThanksOnReward then
            C_Timer.After(2.5, function()
                if IsInGroup() then
                    local ch     = (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and "INSTANCE_CHAT") or "PARTY"
                    local thanks = { "ty all!", "gg ty!", "thanks all!", "ggs!" }
                    local msg    = thanks[1]
                    if type(math.random) == "function" then
                        msg = thanks[math.random(1, #thanks)]
                    end
                    SendChatMessage(msg, ch)
                end
            end)
        end

        -- Open slightly later; snapshot is already up-to-date (no re-snapshot needed).
        -- No lock for LFG: sticky merge is safe even if ShowWhisperWindow re-merges.
        C_Timer.After(0.5, function()
            FinalizeAndOpen("LFG", false, false)
        end)
        return
    end

    -- ==========================================================
    -- Enter/exit instance tracking for LFG (no-reward path)
    -- ==========================================================
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        local nowIn = IsInLFGPartyInstance()

        if nowIn and not LFG_InInstance then
            -- Entering a new LFG instance: ALWAYS reset first to prevent
            -- ghost members from previous runs bleeding into this snapshot.
            LFG_InInstance = true
            LFG_RunActive  = true
            LFG_EnteredAt  = MPW.Now()
            LFG_BossKills  = 0

            if MPW.ResetPartySnapshot then MPW.ResetPartySnapshot("LFG") end
            if IsInGroup() and MPW.MergeSnapshotMembers then
                MPW.MergeSnapshotMembers("LFG")
            end
            return
        end

        -- Still inside: keep merging to track late joiners
        if nowIn and IsInGroup() and LFG_RunActive and MPW.MergeSnapshotMembers then
            MPW.MergeSnapshotMembers("LFG")
        end

        if (not nowIn) and LFG_InInstance then
            -- Exiting instance: treat as completion if it looked like a real run
            LFG_InInstance = false
            local dur       = MPW.Now() - (LFG_EnteredAt or 0)
            local looksReal = (LFG_BossKills or 0) > 0 or dur >= 20

            if LFG_RunActive and looksReal then
                LFG_RunActive = false
                -- Snapshot already up-to-date from in-run merges; no re-snapshot needed.
                FinalizeAndOpen("LFG", false, false)
            else
                LFG_RunActive = false
            end
        end

        return
    end

    -- ==========================================================
    -- Boss kill: progress marker + sticky snapshot update
    -- ==========================================================
    if event == "BOSS_KILL" then
        if IsInLFGPartyInstance() and IsInGroup() and LFG_RunActive then
            LFG_BossKills = (LFG_BossKills or 0) + 1
            if MPW.MergeSnapshotMembers then MPW.MergeSnapshotMembers("LFG") end
        end
        return
    end

    -- ==========================================================
    -- Group roster changes
    -- ==========================================================
    if event == "GROUP_ROSTER_UPDATE" then
        local nowInGroup    = IsInGroup()
        local nowInInstance = IsInLFGPartyInstance()

        -- Joined a brand-new LFG/instance group from outside any group:
        -- reset so old snapshot data doesn't carry over.
        if (not WasInGroup) and nowInGroup
           and (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or nowInInstance) then
            if MPW.ResetPartySnapshot then MPW.ResetPartySnapshot("LFG") end
        end

        -- Warm spec cache
        if nowInGroup and MPW.QueueInspectForGroup then
            MPW.QueueInspectForGroup()
        end

        -- Keep sticky snapshot updated during an active LFG run.
        -- This is the key sticky call: every roster change merges the current group
        -- into the snapshot WITHOUT removing anyone already there (leavers stay).
        if nowInGroup and nowInInstance and LFG_RunActive and MPW.MergeSnapshotMembers then
            MPW.MergeSnapshotMembers("LFG")
        end

        -- Left the group: open UI from the accumulated sticky snapshot
        if WasInGroup and (not nowInGroup) then
            local dur       = MPW.Now() - (LFG_EnteredAt or 0)
            local looksReal = (LFG_BossKills or 0) > 0 or dur >= 20

            if looksReal and MPW.IsSnapshotFresh()
               and MPW.PartySnapshot and MPW.PartySnapshot.runType == "LFG" then
                if ThrottleOpen() then
                    LFG_RunActive = false
                    OpenUIFromSnapshot("LFG")
                end
            end
        end

        WasInGroup = nowInGroup
        return
    end
end)
