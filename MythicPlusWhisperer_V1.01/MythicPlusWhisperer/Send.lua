-- Send.lua
-- Builds the send queue + preview modes + LIVE confirm + pre-send delay

MPW = MPW or {}

-- Internal helper: count selected
local function CountSelectedTargets(rows)
    local n = 0
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r and r:IsShown() and r.cbMain:GetChecked() and r.playerName and r.playerName ~= "" then
            n = n + 1
        end
    end
    return n
end

local function PreviewLine(label, text)
    MPW.Print(label .. " " .. text)
end

-- =========================================
-- Public: process whispers
-- opts:
--   forceMsg1Only (bool): always suppress msg2
--   forceName (bool): always include name in msg1
--   selectAll (bool): treat all shown rows as selected
-- =========================================
function MPW.ProcessWhispers(isTest, opts)
    opts = opts or {}
    local forceMsg1Only = not not opts.forceMsg1Only
    local forceName = not not opts.forceName
    local selectAll = not not opts.selectAll

    local sendWin = MPW.UI and MPW.UI.sendWin
    local rows = MPW.UI and MPW.UI.rows
    if not sendWin or not rows then
        MPW.Print("UI not ready.")
        return
    end

    -- Anti-spam: throttle bursts (LIVE only)
    if MPW.AntiSpam and not isTest and MPW.IsArmed() then
        local ok, reason = MPW.AntiSpam.CanStartBurst()
        if not ok then
            MPW.Print("Not sending: " .. tostring(reason))
            return
        end
    end

    local queue = {}
    local selected = 0

    local function Enqueue(target, text)
        if text and text ~= "" then
            table.insert(queue, { target = target, text = text })
        end
    end

    if isTest then
        MPW.Print("================================================")
        MPW.Print("TEST MODE PREVIEW - NOTHING IS SENT")
        MPW.Print("================================================")
    elseif not MPW.IsArmed() then
        MPW.Print("SAFE MODE: preview only (no whispers sent).")
    else
        MPW.Print("LIVE MODE: sending whispers (rate-limited)...")
    end

    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r and r:IsShown() then
            local isSelected = selectAll or r.cbMain:GetChecked()
            if isSelected then
                if not r.playerName or r.playerName == "" then
                    MPW.Print("Row " .. i .. " selected but has no target name.")
                else
                    local includeName = forceName or r.cbName:GetChecked()
                    local includeSecond = (not forceMsg1Only) and r.cbBnet:GetChecked()

                    -- LFG safety: never allow second message
                    if MPW.CurrentRunType == "LFG" then
                        includeSecond = false
                    end

                    -- Get the selected message index for this row
                    local msg1Idx = nil
                    if r.msgDD then
                        msg1Idx = UIDropDownMenu_GetSelectedID(r.msgDD)
                    end
                    -- Fallback to override if set
                    if not msg1Idx and MPW.UI.rowMessageOverrides and MPW.UI.rowMessageOverrides[r.playerName] then
                        msg1Idx = MPW.UI.rowMessageOverrides[r.playerName]
                    end
                    -- Final fallback to default
                    if not msg1Idx then
                        msg1Idx = 1
                    end

                    local msg1, msg2 = MPW.BuildMessagesForTarget(r.playerName, includeName, includeSecond, {
                        role = r.role,
                        specID = r.specID,
                        msg1Index = msg1Idx,
                    })
                    local clean = MPW.CleanName(r.playerName)

                    if isTest then
                        PreviewLine("[TEST -> " .. clean .. "]", msg1)
                        if includeSecond and msg2 ~= "" then
                            PreviewLine("[TEST -> " .. clean .. " - 2nd]", msg2)
                        end

                    elseif MPW.IsArmed() then
                        Enqueue(r.playerName, msg1)
                        if includeSecond and msg2 ~= "" then
                            Enqueue(r.playerName, msg2)
                        end

                    else
                        PreviewLine("[SAFE -> " .. clean .. "]", msg1)
                        if includeSecond and msg2 ~= "" then
                            PreviewLine("[SAFE -> " .. clean .. " - 2nd]", msg2)
                        end
                    end

                    selected = selected + 1
                end
            end
        end
    end

    if selected == 0 then
        MPW.Print("No players selected.")
        return
    end

    -- close the window in all modes (consistent)
    sendWin:Hide()

    -- TEST/SAFE: preview only
    if isTest or not MPW.IsArmed() then
        return
    end

    if #queue == 0 then
        MPW.Print("Queue empty (nothing to send).")
        return
    end

    local idx = 0
    MPW.Print("Sending " .. #queue .. " whisper(s)...")

    if MPW.AntiSpam then
        MPW.AntiSpam.MarkBurstStart()
    end

    local function SendNext()
        idx = idx + 1
        local item = queue[idx]
        if not item then
            MPW.Print("Done.")
            return
        end

        -- Anti-spam per target + per run cap
        if MPW.AntiSpam then
            local ok, reason = MPW.AntiSpam.CanWhisperTarget(item.target)
            if not ok then
                MPW.Print("Skip whisper: " .. tostring(reason))
                C_Timer.After(MPW.SEND_DELAY or 0.35, SendNext)
                return
            end
        end

        -- Send the whisper with error handling
        local success, err = pcall(SendChatMessage, item.text, "WHISPER", nil, item.target)
        if not success then
            MPW.Print("Failed to send whisper to " .. MPW.CleanName(item.target) .. ": " .. tostring(err))
        else
            if MPW.IncrementSentCount then MPW.IncrementSentCount() end
        end

        if MPW.AntiSpam then
            MPW.AntiSpam.MarkWhisper(item.target)
        end

        C_Timer.After(MPW.SEND_DELAY or 0.35, SendNext)
    end

    -- ✅ start the queue
    SendNext()
end

-- =========================================
-- LIVE confirm + pre-send delay
-- =========================================
local function ConfirmText()
    local delay = tonumber(MPW_Config and MPW_Config.preSendDelay) or MPW.DEFAULT_PRE_SEND_DELAY
    local run = (MPW.CurrentRunType == "LFG") and "LFG dungeon" or "Mythic+"
    return "You are in LIVE mode. Send whispers for this " .. run .. "?\n\nAfter OK, it will wait " .. tostring(delay) .. "s before sending."
end

function MPW.StartPreSendCountdownAndSend(isTest)
    local delay = tonumber(MPW_Config and MPW_Config.preSendDelay) or MPW.DEFAULT_PRE_SEND_DELAY
    delay = math.max(0, delay)

    local sendWin = MPW.UI and MPW.UI.sendWin

    -- disable buttons while waiting
    if MPW.UI and MPW.UI.SetSendUIEnabled then
        MPW.UI.SetSendUIEnabled(false)
    end

    -- Big accessibility cue (if enabled)
    if MPW.Access and MPW.Access.ShowCountdown and sendWin and not isTest and MPW.IsArmed() and delay > 0 then
        MPW.Access.ShowCountdown(sendWin, math.floor(delay + 0.5))
    end

    if delay <= 0 then
        local opts = MPW._SendConfirmedOverride
        MPW._SendConfirmedOverride = nil
        MPW.ProcessWhispers(isTest, opts)
        return
    end

    local remaining = math.floor(delay + 0.5)

    local function Tick()
        if remaining <= 0 then
            local opts = MPW._SendConfirmedOverride
            MPW._SendConfirmedOverride = nil
            MPW.ProcessWhispers(isTest, opts)
            return
        end

        if sendWin and sendWin.subText then
            sendWin.subText:SetText("|cFFFF2020LIVE|r: sending in " .. remaining .. "…")
        end

        remaining = remaining - 1
        C_Timer.After(1, Tick)
    end

    Tick()
end

StaticPopupDialogs["MPW_LIVE_CONFIRM"] = {
    text = "LIVE CONFIRM",
    button1 = OKAY,
    button2 = CANCEL,
    OnShow = function(self)
        if self and self.text then
            self.text:SetText(ConfirmText())
        end
    end,
    OnAccept = function()
        -- transfer any override (Thank all / OneTap uses this)
        MPW._SendConfirmedOverride = MPW._SendOverride
        MPW._SendOverride = nil
        MPW.StartPreSendCountdownAndSend(false)
    end,
    OnCancel = function()
        MPW._SendOverride = nil
        MPW._SendConfirmedOverride = nil
        if MPW.UI and MPW.UI.SetSendUIEnabled then
            MPW.UI.SetSendUIEnabled(true)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Called from UI Send button
function MPW.OnSendClicked()
    local isTest = MPW.IsTesting and true or false

    -- TEST/SAFE: immediate
    if isTest or not MPW.IsArmed() then
        MPW.ProcessWhispers(isTest, nil)
        return
    end

    local rows = MPW.UI and MPW.UI.rows
    if not rows then
        MPW.Print("UI not ready.")
        return
    end

    if CountSelectedTargets(rows) == 0 then
        MPW.Print("No players selected.")
        return
    end

    StaticPopup_Show("MPW_LIVE_CONFIRM")
end
