-- Core.lua
-- Core utilities + SavedVariables init + slash commands + armed toggle helper

MPW = MPW or {}

local ADDON_NAME = "MythicPlusWhisperer"

MPW.MAX_ROWS = 5
MPW.SEND_DELAY = 0.35
MPW.DEFAULT_PRE_SEND_DELAY = 3.5
MPW.MAX_LEN = 140
MPW.MAX_CUSTOM_LINES = 6
MPW.MAX_AUTO_MESSAGES = 8
MPW.MAX_AUTO_CUSTOM_MESSAGES = 5

MPW.CurrentRunType = MPW.CurrentRunType or "MPLUS" -- "MPLUS" or "LFG"
MPW.RunContext = MPW.RunContext or { level = "", timeStr = "" }
MPW.IsTesting = false

-- Session statistics (reset on login)
MPW.SessionStats = { sent = 0 }

function MPW.GetSessionStats()
    return MPW.SessionStats
end

function MPW.IncrementSentCount()
    MPW.SessionStats.sent = (MPW.SessionStats.sent or 0) + 1
end

function MPW.Now()
    return GetTime and GetTime() or time()
end

function MPW.Print(msg)
    print("|cFF00FFAA[MPW]|r " .. tostring(msg))
end

function MPW.CleanName(fullName)
    if not fullName then return "" end
    return (tostring(fullName):gsub("%-.+", ""))
end

function MPW.GetMyBattleTag()
    local success, _, btag = pcall(function() 
        if BNGetInfo then
            return BNGetInfo() 
        end
        return nil, nil
    end)
    if success and btag then
        btag = tostring(btag)
        if btag:find("#") then return btag end
    end
    return ""
end

function MPW.IsArmed()
    MPW_CharConfig = MPW_CharConfig or {}
    return not not MPW_CharConfig.isArmed
end

function MPW.ModeText(isTest)
    if isTest then return "|cFFFFFF00TEST MODE|r" end
    if MPW.IsArmed() then return "|cFFFF2020LIVE MODE|r" end
    return "|cFF00FFFFSAFE MODE|r"
end

function MPW.ToggleArmed()
    MPW_CharConfig = MPW_CharConfig or {}
    MPW_CharConfig.isArmed = not MPW.IsArmed()

    MPW.Print("Mode: " .. (MPW.IsArmed() and "|cffff2020LIVE|r" or "|cff00ffffSAFE|r"))

    -- update minimap color immediately if button exists
    local btn = _G["MPW_MinimapButton"]
    if btn and btn.icon then
        if MPW.IsArmed() then
            btn.icon:SetVertexColor(1, 0.25, 0.25) -- LIVE
        else
            btn.icon:SetVertexColor(0.25, 1, 1) -- SAFE
        end
    end
end

-- =========================================
-- ADDON_LOADED init
-- =========================================

local core = CreateFrame("Frame")
core:RegisterEvent("ADDON_LOADED")

local function ClampIndex(i, list)
    i = tonumber(i) or 1
    if i < 1 or i > #list then i = 1 end
    return i
end

core:SetScript("OnEvent", function(self, event, arg1)
    if event ~= "ADDON_LOADED" or arg1 ~= ADDON_NAME then return end

    -- Account-wide config
    if not MPW_Config then
        MPW_Config = {
            msg1Index = 1,
            msg2Index = 1,
            preSendDelay = MPW.DEFAULT_PRE_SEND_DELAY,
            showOnLeave = false,
            autoPartyThanksOnReward = false,
            autoGreetEnabled = true,
        }
    end
    -- Migrations: fill in keys missing from older saved configs
    if MPW_Config.autoPartyThanksOnReward == nil then
        MPW_Config.autoPartyThanksOnReward = false
    end
    if MPW_Config.autoGreetEnabled == nil then
        MPW_Config.autoGreetEnabled = true
    end
    if not MPW_Config.customLines then
        MPW_Config.customLines = {}
    end
    if not MPW_Config.autoMessageIndex then
        MPW_Config.autoMessageIndex = 1
    end
    if not MPW_Config.autoCustomMessages then
        MPW_Config.autoCustomMessages = {}
    end

    -- Per-character config (LIVE default ON)
    if not MPW_CharConfig then
        MPW_CharConfig = {
            isArmed = true,
            minimap = { angle = 220 },
            access = {},
            antispam = {},
        }
    end
    if MPW_CharConfig.isArmed == nil then
        MPW_CharConfig.isArmed = true
    end

    -- Clamp dropdown indices if presets already loaded
    -- msg1 uses the combined list (presets + custom lines), but at load time
    -- custom lines may not be populated yet, so just clamp to base presets
    if MPW.MSG1_PRESETS then
        local combinedLen = #MPW.MSG1_PRESETS
        if MPW_Config.customLines then
            for i = 1, MPW.MAX_CUSTOM_LINES do
                if MPW_Config.customLines[i] and MPW_Config.customLines[i] ~= "" then
                    combinedLen = combinedLen + 1
                end
            end
        end
        local i1 = tonumber(MPW_Config.msg1Index) or 1
        if i1 < 1 or i1 > combinedLen then MPW_Config.msg1Index = 1 end
    end
    if MPW.MSG2_PRESETS then MPW_Config.msg2Index = ClampIndex(MPW_Config.msg2Index, MPW.MSG2_PRESETS) end

    -- Seed RNG safely
    if math and type(math.randomseed) == "function" then
        math.randomseed(time())
        if type(math.random) == "function" then
            math.random(); math.random(); math.random()
        end
    end

    MPW.Print("Loaded. Mode: " .. (MPW.IsArmed() and "|cffff2020LIVE|r" or "|cff00ffffSAFE|r"))
    MPW.Print("Commands: /mpw (settings)  /mpw show  /mpw test  /mpw arm  /mpw stats")
end)

-- =========================================
-- Slash commands
-- =========================================
SLASH_MPW1 = "/mpw"
SlashCmdList["MPW"] = function(msg)
    msg = msg or ""
    local cmd = strtrim(string.lower(msg))

    if cmd == "test" then
        MPW.IsTesting = true
        MPW.CurrentRunType = "MPLUS"
        if MPW.ShowWhisperWindow then MPW.ShowWhisperWindow(true) end
        return
    end

    if cmd == "show" then
        MPW.IsTesting = false
        if MPW.ShowWhisperWindow then MPW.ShowWhisperWindow(false) end
        return
    end

    if cmd == "arm" then
        MPW.ToggleArmed()
        return
    end

    if cmd == "stats" then
        local stats = MPW.GetSessionStats()
        MPW.Print("Session stats: " .. (stats.sent or 0) .. " whisper(s) sent.")
        return
    end

    if MPW.ShowSettings then
        MPW.ShowSettings()
    end
end
