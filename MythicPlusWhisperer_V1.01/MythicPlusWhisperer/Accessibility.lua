-- Accessibility.lua
-- One-Tap Mode + big visual cue + optional sound during LIVE countdown
-- Designed for people who struggle with keyboard/many clicks.

MPW = MPW or {}
MPW.Access = MPW.Access or {}

-- Defaults (can be exposed later in settings)
MPW.Access.DEFAULTS = {
    oneTapMode = true,           -- show big "Send Thanks" button
    bigCue = true,               -- show big countdown text
    soundCue = true,             -- play sound on countdown ticks
    autoThankOnLeave = false,    -- if true, sends automatically when leaving group after completion (we'll wire later if you want)
}

local function EnsureCharConfig()
    MPW_CharConfig = MPW_CharConfig or {}
    MPW_CharConfig.access = MPW_CharConfig.access or {}
    local a = MPW_CharConfig.access
    for k, v in pairs(MPW.Access.DEFAULTS) do
        if a[k] == nil then a[k] = v end
    end
    return a
end

function MPW.Access.Get()
    return EnsureCharConfig()
end

-- =========================================
-- Big cue overlay inside send window
-- =========================================
local function EnsureBigCue(sendWin)
    if not sendWin or sendWin.MPW_BigCue then return end

    local t = sendWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
    t:SetPoint("CENTER", sendWin, "CENTER", 0, 40)
    t:SetText("")
    t:Hide()
    sendWin.MPW_BigCue = t
end

local function PlayTickSound()
    -- light UI sound (no custom assets needed)
    -- This is intentionally subtle.
    if PlaySound then
        pcall(function() PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end)
    end
end

-- Public: show a countdown overlay (used from Send.lua)
function MPW.Access.ShowCountdown(sendWin, seconds)
    local cfg = EnsureCharConfig()
    if not cfg.bigCue then return end

    EnsureBigCue(sendWin)
    if not sendWin.MPW_BigCue then return end

    local remain = math.max(0, tonumber(seconds) or 0)
    if remain <= 0 then
        sendWin.MPW_BigCue:Hide()
        return
    end

    sendWin.MPW_BigCue:Show()

    local function Tick()
        if remain <= 0 then
            sendWin.MPW_BigCue:SetText("")
            sendWin.MPW_BigCue:Hide()
            return
        end

        sendWin.MPW_BigCue:SetText("Sending in " .. tostring(remain) .. "...")
        if cfg.soundCue then PlayTickSound() end

        remain = remain - 1
        C_Timer.After(1, Tick)
    end

    Tick()
end

-- =========================================
-- One-Tap Mode button injected into UI window
-- =========================================
local function EnsureOneTapButton(sendWin)
    if not sendWin or sendWin.MPW_OneTapBtn then return end

    local btn = CreateFrame("Button", nil, sendWin, "UIPanelButtonTemplate")
    btn:SetSize(240, 42)
    btn:SetPoint("BOTTOM", sendWin, "BOTTOM", 0, 58)
    btn:SetText("Send Thanks (One Tap)")
    btn:SetScript("OnClick", function()
        -- This sends Msg1 to everyone shown, without name by default.
        -- (Matches your preference: Thank-all without names.)
        if not MPW.ProcessWhispers then return end

        local isTest = MPW.IsTesting and true or false
        if isTest or not MPW.IsArmed() then
            MPW.ProcessWhispers(isTest, { forceMsg1Only = true, forceName = false, selectAll = true })
        else
            MPW._SendOverride = { forceMsg1Only = true, forceName = false, selectAll = true }
            StaticPopup_Show("MPW_LIVE_CONFIRM")
        end
    end)

    btn:SetAlpha(0.95)
    sendWin.MPW_OneTapBtn = btn
end

-- Called from UI.lua after window creation/show
function MPW.Access.ApplyToSendWindow(sendWin)
    local cfg = EnsureCharConfig()
    EnsureBigCue(sendWin)

    if cfg.oneTapMode then
        EnsureOneTapButton(sendWin)
        sendWin.MPW_OneTapBtn:Show()
    else
        if sendWin.MPW_OneTapBtn then sendWin.MPW_OneTapBtn:Hide() end
    end
end
