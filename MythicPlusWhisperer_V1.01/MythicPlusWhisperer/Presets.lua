-- Presets.lua
-- Friendly, low-drama message presets.
-- Kept intentionally neutral (no role/performance callouts) so it won't read like sarcasm.

MPW = MPW or {}

-- Msg1 = short thank-you / gg
-- Placeholders:
--   {name}   (no realm)
--   {praise} (neutral + randomized)
--   {role}   (Tank / Healer / DPS)
--   {spec}   (best effort, e.g. "Holy")
MPW.MSG1_PRESETS = {
    "gg {name}, {praise}",
    "ty {name}!",
    "thanks for the run {name}!",
    "Random",
    "{praise} {name}",
    "gg {name} :)",
    "ty again!",
}

-- Msg2 = optional BTag (ONLY for M+; UI disables in LFG)
MPW.MSG2_PRESETS = {
    "if you wanna run again sometime: {btag}",
    "feel free to add me: {btag}",
    "up for more keys later? {btag}",
    "Random",
    "if you ever need a +1: {btag}",
}

-- =========================================
-- Helpers
-- =========================================
local function IsAllowed(list, s)
    if not s then return false end
    for _, v in ipairs(list) do
        if s == v then return true end
    end
    return false
end

function MPW.CleanOutgoing(s)
    s = tostring(s or "")
    s = s:gsub("\r", " ")
    s = s:gsub("\n", " ")
    if #s > (MPW.MAX_LEN or 140) then
        s = s:sub(1, MPW.MAX_LEN or 140)
    end
    return s
end

local function PresetByIndex(list, idx)
    idx = tonumber(idx) or 1
    if idx < 1 or idx > #list then idx = 1 end

    local current = list[idx]
    local isRandom = (type(current) == "string") and current:lower():find("random", 1, true) ~= nil

    if isRandom then
        -- Pick from all non-"Random" presets in the list
        local candidates = {}
        for _, v in ipairs(list) do
            if type(v) == "string" and v:lower():find("random", 1, true) == nil then
                table.insert(candidates, v)
            end
        end

        if #candidates == 0 then
            return tostring(list[1] or ""), idx
        end

        local r = (type(math.random) == "function") and math.random(1, #candidates) or 1
        return candidates[r], idx
    end

    return list[idx], idx
end

local function GetSafeTemplate(list, idx, fallbackIdx)
    local tpl
    tpl, idx = PresetByIndex(list, idx)
    tpl = MPW.CleanOutgoing(tpl)

    if not IsAllowed(list, tpl) then
        tpl, _ = PresetByIndex(list, fallbackIdx or 1)
        tpl = MPW.CleanOutgoing(tpl)
    end
    return tpl
end

local function RoleText(role)
    role = tostring(role or "")
    if role == "TANK" then return "Tank" end
    if role == "HEALER" then return "Healer" end
    if role == "DAMAGER" then return "DPS" end
    return "" -- unknown
end

local function InferRoleFromSpecID(specID)
    if not specID or specID <= 0 then return nil end
    if not GetSpecializationInfoByID then return nil end
    local _, _, _, _, specRole = GetSpecializationInfoByID(specID)
    if specRole == "TANK" or specRole == "HEALER" or specRole == "DAMAGER" then
        return specRole
    end
    return nil
end

local function SpecNameFromID(specID)
    if not specID or specID <= 0 then return "" end
    if not GetSpecializationInfoByID then return "" end
    local _, specName = GetSpecializationInfoByID(specID)
    return tostring(specName or "")
end

local function PraiseForRole(role)
    -- Keep this intentionally neutral: role/performance comments can be read as sarcasm.
    local pool = {
        "thanks!",
        "ty!",
        "cheers!",
        "appreciate it!",
        "thanks again!",
    }
    if type(math.random) == "function" then
        return pool[math.random(1, #pool)]
    end
    return pool[1]
end

local function CleanupArtifacts(s)
    -- Remove dashes ("-") entirely so messages don't look templated/addon-y
    -- Examples: "gg x - ty" -> "gg x ty" ; "word-word" -> "word word"
    s = s:gsub("%s*%-%s*", " ")

    -- Remove leftover double spaces
    s = s:gsub("%s%s+", " ")

    -- If name is empty: "Thanks !" -> "Thanks!" ; "GG ," -> "GG"
    s = s:gsub("%s+!", "!")
    s = s:gsub("%s+,", ",")
    s = s:gsub(",%s*%.", ".")

    -- Remove trailing commas/spaces
    s = s:gsub("%s*,%s*$", "")

    -- Trim
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

-- =========================================
-- Build final messages
-- meta:
--   meta.role   = "TANK"|"HEALER"|"DAMAGER"|"NONE"
--   meta.specID = number
-- =========================================
function MPW.BuildMessagesForTarget(targetFullName, includeName, includeSecond, meta)
    meta = meta or {}

    local clean = MPW.CleanName(targetFullName)
    local namePart = includeName and clean or ""

    local role = meta.role
    if role == "NONE" or role == "" or role == nil then
        role = InferRoleFromSpecID(tonumber(meta.specID) or 0) or role
    end

    local roleTxt = RoleText(role)
    local praise = PraiseForRole(role)
    local specName = SpecNameFromID(tonumber(meta.specID) or 0)

    local tpl1 = GetSafeTemplate(MPW.MSG1_PRESETS, MPW_Config and MPW_Config.msg1Index, 1)
    local tpl2 = GetSafeTemplate(MPW.MSG2_PRESETS, MPW_Config and MPW_Config.msg2Index, 1)

    local myBtag = MPW.GetMyBattleTag()

    local msg1 = MPW.CleanOutgoing(
        tpl1
            :gsub("{name}", namePart)
            :gsub("{btag}", myBtag)
            :gsub("{praise}", praise)
            :gsub("{role}", roleTxt)
            :gsub("{spec}", specName)
    )
    msg1 = CleanupArtifacts(msg1)

    local msg2 = ""
    if includeSecond then
        msg2 = MPW.CleanOutgoing(
            tpl2
                :gsub("{name}", namePart)
                :gsub("{btag}", myBtag)
                :gsub("{praise}", praise)
                :gsub("{role}", roleTxt)
                :gsub("{spec}", specName)
        )
        msg2 = CleanupArtifacts(msg2)

        if myBtag == "" then
            msg2 = ""
        end
    end

    return msg1, msg2
end
