-- AutoGreet.lua
-- One delayed greeting when you enter/join a group (accessibility feature).
-- Controlled by MPW_Config.autoGreetEnabled
--
-- NOTE: this feature is intentionally independent of LIVE/SAFE mode.
-- Greeting in party chat is social and does NOT send whispers.

MPW = MPW or {}

local GREET_DELAY    = 4.0
local GREET_COOLDOWN = 60 * 3  -- 3 minutes

local lastGreetAt = 0
local pending     = false

local GREET_PRESETS = { "hey all", "hi!", "hi all", "o/", "heya", "yo" }

local function PickGreeting()
    if type(math.random) == "function" then
        return GREET_PRESETS[math.random(1, #GREET_PRESETS)]
    end
    return GREET_PRESETS[1]
end

local function ChooseChannel()
    -- Use INSTANCE_CHAT inside a queued LFG instance; PARTY otherwise.
    local inInstance, instType = IsInInstance()
    if inInstance
       and (instType == "party" or instType == "scenario")
       and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end
    return "PARTY"
end

local function ShouldGreetNow()
    -- Feature must be enabled in settings
    if not (MPW_Config and MPW_Config.autoGreetEnabled) then return false end
    -- Must be in a group to have someone to greet
    if not IsInGroup() then return false end
    -- Respect cooldown (avoids spam on rapid roster updates)
    local now = (MPW.Now and MPW.Now()) or (GetTime and GetTime()) or time()
    if (now - lastGreetAt) < GREET_COOLDOWN then return false end
    return true
    -- No IsArmed() check: greeting in /p or INSTANCE_CHAT is not a whisper.
end

local function DoGreet()
    if not ShouldGreetNow() then return end
    lastGreetAt = (MPW.Now and MPW.Now()) or (GetTime and GetTime()) or time()

    SendChatMessage(PickGreeting(), ChooseChannel())
end

local function ScheduleOneGreet()
    if pending then return end
    pending = true
    C_Timer.After(GREET_DELAY, function()
        pending = false
        DoGreet()
    end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(self, event)
    -- Any join/roster change -> schedule ONE greet (not per member)
    if event == "PLAYER_ENTERING_WORLD" then
        ScheduleOneGreet()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" then
        ScheduleOneGreet()
        return
    end
end)
