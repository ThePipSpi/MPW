-- UI.lua
-- Clean layout: Settings + Send UI with per-row Preview + Thank all button.
-- LFG disables Message 2.
--
-- Snapshot/refresh rules:
--   M+  → snapshot is locked at completion; ShowWhisperWindow skips live refresh.
--          Unlock on window close so next manual open works normally.
--   LFG → snapshot is NEVER locked; ShowWhisperWindow always calls MergeSnapshotMembers
--          (sticky), which preserves leavers. This is safe and the simplest approach.

MPW    = MPW or {}
MPW.UI = MPW.UI or {}

-- =========================================
-- Class icon helper
-- =========================================
local CLASS_ICON_TOKEN = {
    WARRIOR     = "Warrior",    PALADIN     = "Paladin",
    HUNTER      = "Hunter",     ROGUE       = "Rogue",
    PRIEST      = "Priest",     DEATHKNIGHT = "DeathKnight",
    SHAMAN      = "Shaman",     MAGE        = "Mage",
    WARLOCK     = "Warlock",    MONK        = "Monk",
    DRUID       = "Druid",      DEMONHUNTER = "DemonHunter",
    EVOKER      = "Evoker",
}

local function ClassIconTag(classFile, size)
    size = size or 16
    if not classFile then return "" end
    local token = CLASS_ICON_TOKEN[classFile]
    if not token then return "" end
    local path = "Interface\\Icons\\ClassIcon_" .. token
    return ("|T%s:%d:%d:0:0|t "):format(path, size, size)
end

local function SpecIconTag(specID, size)
    size   = size or 16
    specID = tonumber(specID)
    if not specID or specID <= 0     then return "" end
    if not GetSpecializationInfoByID then return "" end
    local _, _, _, icon = GetSpecializationInfoByID(specID)
    if not icon then return "" end
    return ("|T%s:%d:%d:0:0|t "):format(tostring(icon), size, size)
end

local function RoleIconTag(role, size)
    size = size or 14
    if not CreateAtlasMarkup then return "" end
    role = tostring(role or "")
    if role == "TANK"    then return CreateAtlasMarkup("roleicon-tiny-tank",   size, size) .. " " end
    if role == "HEALER"  then return CreateAtlasMarkup("roleicon-tiny-healer", size, size) .. " " end
    if role == "DAMAGER" then return CreateAtlasMarkup("roleicon-tiny-dps",    size, size) .. " " end
    return ""
end

local function RoleText(role)
    role = tostring(role or "")
    if role == "TANK"    then return "Tank"   end
    if role == "HEALER"  then return "Healer" end
    if role == "DAMAGER" then return "DPS"    end
    return "Role?"
end

local function GetClassColorStr(classFile)
    local c = (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
           or (RAID_CLASS_COLORS and RAID_CLASS_COLORS["PRIEST"])
    return (c and c.colorStr) or "ffffffff"
end

local function FormatTime(sec)
    sec = tonumber(sec) or 0
    if sec <= 0 then return "" end
    local m = math.floor(sec / 60)
    local s = math.floor(sec % 60)
    return string.format(" (%d:%02d)", m, s)
end

-- Robust M+ context
function MPW.RefreshRunContext()
    MPW.RunContext.level, MPW.RunContext.timeStr = "", ""
    if MPW.CurrentRunType ~= "MPLUS" then return end

    -- Safely get keystone level
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local success, a, b = pcall(C_ChallengeMode.GetActiveKeystoneInfo)
        if success then
            local level
            if     type(b) == "number" then level = b
            elseif type(a) == "table"  then level = a.level or a.keystoneLevel or a[2]
            elseif type(b) == "table"  then level = b.level or b.keystoneLevel or b[2]
            end
            if type(level) == "number" then MPW.RunContext.level = tostring(level) end
        end
    end

    -- Safely get completion time
    if C_ChallengeMode and C_ChallengeMode.GetCompletionInfo then
        local success, _, _, t = pcall(C_ChallengeMode.GetCompletionInfo)
        if success and t then
            MPW.RunContext.timeStr = FormatTime(t)
        end
    end
end

-- =========================================
-- SETTINGS WINDOW
-- =========================================

local configWin = CreateFrame("Frame", "MPW_ConfigFrame", UIParent, "BasicFrameTemplateWithInset")
configWin:SetSize(520, 720)
configWin:SetPoint("CENTER", 0, 60)
configWin:SetMovable(true)
configWin:EnableMouse(true)
configWin:RegisterForDrag("LeftButton")
configWin:SetScript("OnDragStart", configWin.StartMoving)
configWin:SetScript("OnDragStop",  configWin.StopMovingOrSizing)
configWin:Hide()

configWin.title = configWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
configWin.title:SetPoint("TOPLEFT", 14, -10)
configWin.title:SetText("Mythic Plus Whisperer - Settings")

-- Section separator helper
local function AddSectionHeader(parent, text, yOff)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 14, yOff)
    sep:SetPoint("TOPRIGHT", -14, yOff)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.6)

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", 18, yOff - 6)
    lbl:SetTextColor(1, 0.82, 0)
    lbl:SetText(text)
    return yOff - 22
end

-- ── Section 1: Custom Text Lines ──
local y = AddSectionHeader(configWin, "CUSTOM MESSAGE LINES  (excluded from Random)", -38)

local custLabel = configWin:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
custLabel:SetPoint("TOPLEFT", 18, y)
custLabel:SetWidth(480)
custLabel:SetJustifyH("LEFT")
custLabel:SetText("Write your own messages below. They appear in the send window message dropdown but are never picked by \"Random\".\nPlaceholders: {name}, {praise}, {role}, {spec}, {btag}")

local CUSTOM_BOX_H = 22
local CUSTOM_GAP   = 4
local customBoxes  = {}

for ci = 1, MPW.MAX_CUSTOM_LINES do
    local boxY = y - 32 - ((ci - 1) * (CUSTOM_BOX_H + CUSTOM_GAP))
    local numLbl = configWin:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    numLbl:SetPoint("TOPLEFT", 18, boxY - 3)
    numLbl:SetText(tostring(ci) .. ".")

    local box = CreateFrame("EditBox", "MPW_CustomBox" .. ci, configWin, "InputBoxTemplate")
    box:SetSize(440, CUSTOM_BOX_H)
    box:SetPoint("TOPLEFT", 36, boxY)
    box:SetAutoFocus(false)
    box:SetMaxLetters(140)
    box.idx = ci
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEditFocusLost", function(self)
        if not MPW_Config then return end
        MPW_Config.customLines = MPW_Config.customLines or {}
        local val = strtrim(self:GetText())
        MPW_Config.customLines[self.idx] = (val ~= "") and val or nil
        -- Rebuild row message dropdowns with updated custom lines
        if MPW.UI.RebuildRowMessageDropdowns then MPW.UI.RebuildRowMessageDropdowns() end
    end)

    customBoxes[ci] = box
end

-- ── Section 2: Behavior ──
local yBehav = y - 32 - (MPW.MAX_CUSTOM_LINES * (CUSTOM_BOX_H + CUSTOM_GAP)) - 10
yBehav = AddSectionHeader(configWin, "BEHAVIOR", yBehav)

local lblDelay = configWin:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblDelay:SetPoint("TOPLEFT", 18, yBehav)
lblDelay:SetText("LIVE delay after OK (seconds):")

local delayBox = CreateFrame("EditBox", "MPW_DelayBox", configWin, "InputBoxTemplate")
delayBox:SetSize(60, 24)
delayBox:SetPoint("LEFT", lblDelay, "RIGHT", 10, 0)
delayBox:SetAutoFocus(false)
delayBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    local v = tonumber(self:GetText())
    if not v then v = MPW.DEFAULT_PRE_SEND_DELAY end
    MPW_Config.preSendDelay = math.max(0, v)
end)

local cbRewardThanks = CreateFrame("CheckButton", nil, configWin, "ChatConfigCheckButtonTemplate")
cbRewardThanks:SetPoint("TOPLEFT", 18, yBehav - 30)
cbRewardThanks.Text:ClearAllPoints()
cbRewardThanks.Text:SetPoint("LEFT", cbRewardThanks, "RIGHT", 6, 1)
cbRewardThanks.Text:SetWidth(440)
cbRewardThanks.Text:SetJustifyH("LEFT")
cbRewardThanks.Text:SetText("Auto party 'ty!' when LFG reward triggers")
cbRewardThanks:SetScript("OnClick", function(self)
    MPW_Config.autoPartyThanksOnReward = self:GetChecked() and true or false
end)

local cbAutoGreet = CreateFrame("CheckButton", nil, configWin, "ChatConfigCheckButtonTemplate")
cbAutoGreet:SetPoint("TOPLEFT", cbRewardThanks, "BOTTOMLEFT", 0, -4)
cbAutoGreet.Text:ClearAllPoints()
cbAutoGreet.Text:SetPoint("LEFT", cbAutoGreet, "RIGHT", 6, 1)
cbAutoGreet.Text:SetWidth(440)
cbAutoGreet.Text:SetJustifyH("LEFT")
cbAutoGreet.Text:SetText("Auto greeting in party (accessibility)")
cbAutoGreet:SetScript("OnClick", function(self)
    MPW_Config.autoGreetEnabled = self:GetChecked() and true or false
end)

local hint = configWin:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
hint:SetPoint("TOPLEFT", cbAutoGreet, "BOTTOMLEFT", 0, -8)
hint:SetWidth(480)
hint:SetJustifyH("LEFT")
hint:SetText("LFG disables Message 2 for safety. Custom lines support all placeholders.")

local closeBtnCfg = CreateFrame("Button", nil, configWin, "UIPanelButtonTemplate")
closeBtnCfg:SetSize(120, 30)
closeBtnCfg:SetPoint("BOTTOM", 0, 14)
closeBtnCfg:SetText("Close")
closeBtnCfg:SetScript("OnClick", function() configWin:Hide() end)

-- Rebuild row message dropdowns when custom messages change
function MPW.UI.RebuildRowMessageDropdowns()
    if not rows then return end
    
    local messages = MPW.GetMsg1WithCustom and MPW.GetMsg1WithCustom() or MPW.MSG1_PRESETS
    
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r and r.msgDD then
            -- Preserve current selection
            local currentIdx = UIDropDownMenu_GetSelectedID(r.msgDD) or 1
            if currentIdx < 1 or currentIdx > #messages then currentIdx = 1 end
            
            -- Rebuild the dropdown
            UIDropDownMenu_Initialize(r.msgDD, function(self, level)
                local selected = UIDropDownMenu_GetSelectedID(r.msgDD) or currentIdx
                for idx, txt in ipairs(messages) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = txt
                    info.checked = (idx == selected)
                    info.func = function()
                        UIDropDownMenu_SetSelectedID(r.msgDD, idx)
                        UIDropDownMenu_SetText(r.msgDD, txt)
                        -- Store the selected index for this row
                        if r.playerName then
                            MPW.UI.rowMessageOverrides = MPW.UI.rowMessageOverrides or {}
                            MPW.UI.rowMessageOverrides[r.playerName] = idx
                        end
                        CloseDropDownMenus()
                        if MPW.UI.UpdateRowPreview then MPW.UI.UpdateRowPreview(r) end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end)
            
            UIDropDownMenu_SetSelectedID(r.msgDD, currentIdx)
            UIDropDownMenu_SetText(r.msgDD, messages[currentIdx])
        end
    end
end

configWin:SetScript("OnShow", function()
    cbRewardThanks:SetChecked(MPW_Config and MPW_Config.autoPartyThanksOnReward)
    cbAutoGreet:SetChecked(MPW_Config and MPW_Config.autoGreetEnabled)

    -- Populate custom line edit boxes
    for ci = 1, MPW.MAX_CUSTOM_LINES do
        local box = customBoxes[ci]
        if box then
            local val = (MPW_Config and MPW_Config.customLines and MPW_Config.customLines[ci]) or ""
            box:SetText(val)
        end
    end

    -- Rebuild row message dropdowns with latest custom lines
    if MPW.UI.RebuildRowMessageDropdowns then MPW.UI.RebuildRowMessageDropdowns() end

    delayBox:SetText(tostring(MPW_Config and MPW_Config.preSendDelay or MPW.DEFAULT_PRE_SEND_DELAY))
end)

function MPW.ShowSettings()
    configWin:Show()
end

-- =========================================
-- SEND WINDOW
-- =========================================
local PAD = 16

local sendWin = CreateFrame("Frame", "MPW_SendWin", UIParent, "BasicFrameTemplateWithInset")
sendWin:SetSize(800, 480)
sendWin:SetPoint("CENTER")
sendWin:SetMovable(true)
sendWin:EnableMouse(true)
sendWin:RegisterForDrag("LeftButton")
sendWin:SetScript("OnDragStart", sendWin.StartMoving)
sendWin:SetScript("OnDragStop",  sendWin.StopMovingOrSizing)
sendWin:Hide()

-- Unlock M+ snapshot when window is closed
sendWin:SetScript("OnHide", function()
    if MPW.UnlockSnapshot then MPW.UnlockSnapshot() end
end)

MPW.UI.sendWin = sendWin

sendWin.title = sendWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
sendWin.title:SetPoint("TOPLEFT", 14, -10)
sendWin.title:SetText("Mythic Plus Whisperer")

sendWin.statusText = sendWin:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sendWin.statusText:SetPoint("TOPLEFT", PAD, -34)

sendWin.subText = sendWin:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
sendWin.subText:SetPoint("TOPLEFT", PAD, -52)
sendWin.subText:SetWidth(600)
sendWin.subText:SetJustifyH("LEFT")

sendWin.noteLine = sendWin:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
sendWin.noteLine:SetPoint("TOPLEFT", PAD, -68)
sendWin.noteLine:SetWidth(600)
sendWin.noteLine:SetJustifyH("LEFT")

local COL_PLAYER_X  = 30
local COL_NAME_CB_X = 340
local COL_2ND_CB_X  = 440
local COL_MSG_DD_X  = 550

local header = CreateFrame("Frame", nil, sendWin)
header:SetSize(760, 18)
header:SetPoint("TOPLEFT", PAD, -96)

local h1 = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
h1:SetPoint("LEFT", COL_PLAYER_X, 0)
h1:SetText("Player")

local h2 = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
h2:SetPoint("LEFT", COL_NAME_CB_X + 25, 0)
h2:SetText("Name")

local h3 = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
h3:SetPoint("LEFT", COL_2ND_CB_X + 25, 0)
h3:SetText("2nd Msg")

local h4 = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
h4:SetPoint("LEFT", COL_MSG_DD_X, 0)
h4:SetText("Message")

local ROW_H     = 44
local ROW_GAP   = 6
local ROW_START_Y = -118

local rows = {}
MPW.UI.rows = rows

local function CreatePlayerRow(i)
    local row = CreateFrame("Frame", nil, sendWin)
    row:SetSize(760, ROW_H)
    row:SetPoint("TOPLEFT", PAD, ROW_START_Y - ((i - 1) * (ROW_H + ROW_GAP)))

    local cbMain = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    cbMain:SetPoint("LEFT", 0, 2)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", COL_PLAYER_X, 10)
    text:SetWidth(280)
    text:SetJustifyH("LEFT")

    local preview = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    preview:SetPoint("LEFT", COL_PLAYER_X, -6)
    preview:SetWidth(280)
    preview:SetJustifyH("LEFT")
    preview:SetText("")

    local cbName = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    cbName:SetPoint("LEFT", COL_NAME_CB_X, 2)

    local cbBnet = CreateFrame("CheckButton", nil, row, "ChatConfigCheckButtonTemplate")
    cbBnet:SetPoint("LEFT", COL_2ND_CB_X, 2)

    local lblName = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblName:SetPoint("LEFT", COL_NAME_CB_X + 24, 2)
    lblName:SetText("Name")

    local lblBnet = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblBnet:SetPoint("LEFT", COL_2ND_CB_X + 24, 2)
    lblBnet:SetText("2nd")

    -- Create message dropdown for this row
    local msgDD = CreateFrame("Frame", "MPW_Row" .. i .. "MsgDD", row, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(msgDD, 200)
    msgDD:SetPoint("LEFT", COL_MSG_DD_X - 12, -2)
    msgDD.rowIndex = i
    
    -- Initialize with combined message list (presets + custom)
    local messages = MPW.GetMsg1WithCustom and MPW.GetMsg1WithCustom() or MPW.MSG1_PRESETS
    local defaultIdx = 1
    if defaultIdx < 1 or defaultIdx > #messages then defaultIdx = 1 end
    
    UIDropDownMenu_Initialize(msgDD, function(self, level)
        local selected = UIDropDownMenu_GetSelectedID(msgDD) or defaultIdx
        for idx, txt in ipairs(messages) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = txt
            info.checked = (idx == selected)
            info.func = function()
                UIDropDownMenu_SetSelectedID(msgDD, idx)
                UIDropDownMenu_SetText(msgDD, txt)
                -- Store the selected index for this row
                if row.playerName then
                    MPW.UI.rowMessageOverrides = MPW.UI.rowMessageOverrides or {}
                    MPW.UI.rowMessageOverrides[row.playerName] = idx
                end
                CloseDropDownMenus()
                if MPW.UI.UpdateRowPreview then MPW.UI.UpdateRowPreview(row) end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    
    UIDropDownMenu_SetSelectedID(msgDD, defaultIdx)
    UIDropDownMenu_SetText(msgDD, messages[defaultIdx])

    local function SetEnabledSubs(enabled)
        cbName:SetEnabled(enabled)
        cbBnet:SetEnabled(enabled)
        msgDD:SetAlpha(enabled and 1 or 0.5)
        cbName:SetAlpha(enabled and 1 or 0.25)
        cbBnet:SetAlpha(enabled and 1 or 0.25)
        lblName:SetAlpha(enabled and 1 or 0.4)
        lblBnet:SetAlpha(enabled and 1 or 0.4)
        if not enabled then
            cbName:SetChecked(false)
            cbBnet:SetChecked(false)
        end
    end

    cbMain:SetScript("OnClick", function(self)
        SetEnabledSubs(self:GetChecked())
        if MPW.UI.UpdateRowPreview then MPW.UI.UpdateRowPreview(row) end
    end)
    cbName:SetScript("OnClick", function(self)
        if not cbMain:GetChecked() then self:SetChecked(false) end
        if MPW.UI.UpdateRowPreview then MPW.UI.UpdateRowPreview(row) end
    end)
    cbBnet:SetScript("OnClick", function(self)
        if not cbMain:GetChecked() then self:SetChecked(false) end
        if MPW.UI.UpdateRowPreview then MPW.UI.UpdateRowPreview(row) end
    end)

    row.cbMain         = cbMain
    row.text           = text
    row.preview        = preview
    row.cbName         = cbName
    row.cbBnet         = cbBnet
    row.msgDD          = msgDD
    row.playerName     = nil
    row.classFile      = nil
    row.role           = nil
    row.guid           = nil
    row.specID         = nil
    row.SetEnabledSubs = SetEnabledSubs

    SetEnabledSubs(false)
    return row
end

for i = 1, MPW.MAX_ROWS do
    rows[i] = CreatePlayerRow(i)
end

-- Buttons
local btnAll = CreateFrame("Button", nil, sendWin, "UIPanelButtonTemplate")
btnAll:SetSize(90, 28)
btnAll:SetPoint("BOTTOMLEFT", PAD, 16)
btnAll:SetText("All")

local btnNone = CreateFrame("Button", nil, sendWin, "UIPanelButtonTemplate")
btnNone:SetSize(90, 28)
btnNone:SetPoint("LEFT", btnAll, "RIGHT", 8, 0)
btnNone:SetText("None")

local btnThankAll = CreateFrame("Button", nil, sendWin, "UIPanelButtonTemplate")
btnThankAll:SetSize(140, 28)
btnThankAll:SetPoint("LEFT", btnNone, "RIGHT", 8, 0)
btnThankAll:SetText("Thank all")

local btnCancel = CreateFrame("Button", nil, sendWin, "UIPanelButtonTemplate")
btnCancel:SetSize(120, 30)
btnCancel:SetPoint("BOTTOMRIGHT", -PAD, 16)
btnCancel:SetText("Cancel")
btnCancel:SetScript("OnClick", function() sendWin:Hide() end)

local btnSend = CreateFrame("Button", nil, sendWin, "UIPanelButtonTemplate")
btnSend:SetSize(120, 30)
btnSend:SetPoint("RIGHT", btnCancel, "LEFT", -8, 0)
btnSend:SetText("Send")
btnSend:SetScript("OnClick", function()
    if MPW.OnSendClicked then MPW.OnSendClicked() end
end)

function MPW.UI.SetSendUIEnabled(enabled)
    btnSend:SetEnabled(enabled)
    btnAll:SetEnabled(enabled)
    btnNone:SetEnabled(enabled)
    btnThankAll:SetEnabled(enabled)
    btnCancel:SetEnabled(enabled)
    btnSend:SetAlpha(enabled and 1 or 0.35)
    btnAll:SetAlpha(enabled and 1 or 0.35)
    btnNone:SetAlpha(enabled and 1 or 0.35)
    btnThankAll:SetAlpha(enabled and 1 or 0.35)
    btnCancel:SetAlpha(enabled and 1 or 0.35)

    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r and r:IsShown() then
            r.cbMain:SetEnabled(enabled)
            r.cbMain:SetAlpha(enabled and 1 or 0.35)
            local subsEnabled = enabled and r.cbMain:GetChecked()
            r.cbName:SetEnabled(subsEnabled)
            r.cbBnet:SetEnabled(subsEnabled)
            r.cbName:SetAlpha(subsEnabled and 1 or 0.25)
            r.cbBnet:SetAlpha(subsEnabled and 1 or 0.25)
        end
    end
end

btnAll:SetScript("OnClick", function()
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r:IsShown() then
            r.cbMain:SetChecked(true)
            r:SetEnabledSubs(true)
            if MPW.UI.UpdateRowPreview then MPW.UI.UpdateRowPreview(r) end
        end
    end
end)

btnNone:SetScript("OnClick", function()
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r:IsShown() then
            r.cbMain:SetChecked(false)
            r:SetEnabledSubs(false)
            if r.preview then r.preview:SetText("") end
        end
    end
end)

btnThankAll:SetScript("OnClick", function()
    -- Randomly select one of the MSG1_PRESETS (excluding "Random" and custom messages)
    -- Build list of preset indices in the combined list
    local combinedList = MPW.GetMsg1WithCustom and MPW.GetMsg1WithCustom() or MPW.MSG1_PRESETS
    local presetIndices = {}
    
    -- Only include indices that correspond to non-Random MSG1_PRESETS
    for idx = 1, #MPW.MSG1_PRESETS do
        local preset = MPW.MSG1_PRESETS[idx]
        if type(preset) == "string" and preset ~= "Random" then
            table.insert(presetIndices, idx)
        end
    end
    
    local randomPresetIdx = 1
    if #presetIndices > 0 then
        -- Pick a random preset index
        randomPresetIdx = presetIndices[math.random(1, #presetIndices)]
    end
    
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r:IsShown() then
            r.cbMain:SetChecked(true)
            r:SetEnabledSubs(true)
            r.cbName:SetChecked(false)
            r.cbBnet:SetChecked(false)
            -- Set the dropdown to the randomly selected preset
            if r.msgDD then
                UIDropDownMenu_SetSelectedID(r.msgDD, randomPresetIdx)
                UIDropDownMenu_SetText(r.msgDD, combinedList[randomPresetIdx])
                -- Store the override
                if r.playerName then
                    MPW.UI.rowMessageOverrides = MPW.UI.rowMessageOverrides or {}
                    MPW.UI.rowMessageOverrides[r.playerName] = randomPresetIdx
                end
            end
            if MPW.UI.UpdateRowPreview then MPW.UI.UpdateRowPreview(r) end
        end
    end

    local isTest = MPW.IsTesting and true or false
    if isTest or not MPW.IsArmed() then
        MPW.ProcessWhispers(isTest, { forceMsg1Only = true, forceName = false })
    else
        MPW._SendOverride = { forceMsg1Only = true, forceName = false }
        StaticPopup_Show("MPW_LIVE_CONFIRM")
    end
end)

-- =========================================
-- Preview helpers
-- =========================================
function MPW.UI.UpdateRowPreview(r)
    if not r or not r.playerName or r.playerName == "" then
        if r and r.preview then r.preview:SetText("") end
        return
    end

    local includeName   = r.cbName:GetChecked()
    local includeSecond = r.cbBnet:GetChecked()
    if MPW.CurrentRunType == "LFG" then includeSecond = false end

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
        role   = r.role,
        specID = r.specID,
        msg1Index = msg1Idx,
    })

    local line = msg1
    if includeSecond and msg2 ~= "" then line = line .. " | " .. msg2 end

    if r.preview then r.preview:SetText("Preview: " .. line) end
end

function MPW.UI.UpdateAllPreviews()
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r and r:IsShown() then MPW.UI.UpdateRowPreview(r) end
    end
end

-- =========================================
-- Populate rows from snapshot
-- =========================================
local function ResetRows()
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        r.playerName = nil
        r.classFile  = nil
        r.role       = nil
        r.guid       = nil
        r.specID     = nil
        r:Hide()
        r.cbMain:SetChecked(false)
        r.cbName:SetChecked(false)
        r.cbBnet:SetChecked(false)
        r:SetEnabledSubs(false)
        if r.preview then r.preview:SetText("") end
        
        -- Reset message dropdown to default
        if r.msgDD then
            local messages = MPW.GetMsg1WithCustom and MPW.GetMsg1WithCustom() or MPW.MSG1_PRESETS
            local defaultIdx = 1
            if defaultIdx < 1 or defaultIdx > #messages then defaultIdx = 1 end
            UIDropDownMenu_SetSelectedID(r.msgDD, defaultIdx)
            UIDropDownMenu_SetText(r.msgDD, messages[defaultIdx])
        end
    end
end

local function PopulateFromSnapshot()
    local snap = MPW.PartySnapshot
    if not snap or not snap.valid or not snap.members then return false end

    local idx = 1
    for _, m in ipairs(snap.members) do
        if idx > MPW.MAX_ROWS then break end
        local r        = rows[idx]
        r.playerName   = m.fullName
        r.classFile    = m.classFile
        r.role         = m.role
        r.guid         = m.guid
        r.specID       = m.specID

        local clean    = MPW.CleanName(m.fullName)
        local roleIcon = RoleIconTag(m.role, 14)
        local icon     = SpecIconTag(m.specID, 16)
        if icon == "" then icon = ClassIconTag(m.classFile, 16) end
        local colorStr = GetClassColorStr(m.classFile)

        r.text:SetText(roleIcon .. icon .. "|c" .. colorStr .. clean .. "|r |cffaaaaaa(" .. RoleText(m.role) .. ")|r")
        
        -- Reset message dropdown to default for this player
        if r.msgDD then
            local autoMessages = MPW.GetMsg1WithCustom and MPW.GetMsg1WithCustom() or MPW.MSG1_PRESETS
            local defaultIdx = tonumber(MPW_Config and MPW_Config.autoMessageIndex) or 1
            if defaultIdx < 1 or defaultIdx > #autoMessages then defaultIdx = 1 end
            
            -- Check if there's an override for this player
            if MPW.UI.rowMessageOverrides and MPW.UI.rowMessageOverrides[m.fullName] then
                defaultIdx = MPW.UI.rowMessageOverrides[m.fullName]
            end
            
            UIDropDownMenu_SetSelectedID(r.msgDD, defaultIdx)
            UIDropDownMenu_SetText(r.msgDD, autoMessages[defaultIdx])
        end
        
        r:Show()
        idx = idx + 1
    end
    return true
end

-- =========================================
-- Live roster refresh (used while window is open and during manual open)
-- =========================================
local function CaptureSelections()
    local sel = {}
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r and r:IsShown() and r.playerName and r.playerName ~= "" and r.cbMain:GetChecked() then
            sel[r.playerName] = {
                name = r.cbName:GetChecked() and true or false,
                bnet = r.cbBnet:GetChecked() and true or false,
            }
        end
    end
    return sel
end

local function ApplySelections(sel)
    if not sel then return end
    for i = 1, MPW.MAX_ROWS do
        local r = rows[i]
        if r and r:IsShown() and r.playerName and sel[r.playerName] then
            r.cbMain:SetChecked(true)
            r:SetEnabledSubs(true)
            r.cbName:SetChecked(sel[r.playerName].name and true or false)
            r.cbBnet:SetChecked(sel[r.playerName].bnet and true or false)
        end
    end
end

-- Update the snapshot from the live group.
-- For LFG: sticky merge (preserves leavers).
-- For M+ (locked): skip entirely.
local function RefreshSnapshotFromCurrentGroup()
    -- M+ snapshot is locked: the clean post-completion snapshot must not be overwritten.
    if MPW.PartySnapshot and MPW.PartySnapshot.locked then return end

    if not IsInGroup() then return end

    if MPW.CurrentRunType == "LFG" and MPW.MergeSnapshotMembers then
        -- Sticky: adds anyone present, never removes leavers
        MPW.MergeSnapshotMembers("LFG")
    elseif MPW.SnapshotGroupMembers then
        MPW.SnapshotGroupMembers(MPW.CurrentRunType or "MANUAL")
    end
end

function MPW.UI.RefreshRosterAndRedraw()
    if not sendWin or not sendWin:IsShown() or MPW.IsTesting then return end
    local sel = CaptureSelections()
    RefreshSnapshotFromCurrentGroup()
    ResetRows()
    PopulateFromSnapshot()
    ApplySelections(sel)
    MPW.UI.UpdateAllPreviews()
end

-- =========================================
-- Status bar
-- =========================================
function MPW.UI.UpdateStatus(isTest)
    sendWin.statusText:SetText("Mode: " .. MPW.ModeText(isTest))

    if isTest then
        sendWin.subText:SetText("|cFFFFFF00TEST|r: preview only. Select players and press Send.")
    elseif MPW.IsArmed() then
        sendWin.subText:SetText("|cFFFF2020LIVE|r: will whisper other players. Double-check your selection.")
    else
        sendWin.subText:SetText("|cFF00FFFFSAFE|r: preview only. Use /mpw arm to enable LIVE.")
    end

    if MPW.CurrentRunType == "LFG" then
        sendWin.noteLine:SetText("LFG: Message 2 (BTag) is disabled. Use Thank all for quick party thanks.")
        h3:SetAlpha(0.35)
    else
        sendWin.noteLine:SetText("M+: optionally enable Message 2 (BTag) per player.")
        h3:SetAlpha(1)
    end
end

-- =========================================
-- Public: show window
-- =========================================
function MPW.ShowWhisperWindow(isTest)
    MPW.IsTesting = isTest and true or false

    ResetRows()
    if not MPW.IsTesting and MPW.RefreshRunContext then MPW.RefreshRunContext() end

    MPW.UI.UpdateStatus(MPW.IsTesting)

    if MPW.IsTesting then
        local t = {
            { fullName = "TestWarrior-Realm", classFile = "WARRIOR", role = "TANK",    specID = 73  },
            { fullName = "TestMage-Realm",    classFile = "MAGE",    role = "DAMAGER", specID = 63  },
            { fullName = "TestPriest-Realm",  classFile = "PRIEST",  role = "HEALER",  specID = 257 },
            { fullName = "TestHunter-Realm",  classFile = "HUNTER",  role = "DAMAGER", specID = 253 },
            { fullName = "TestPaladin-Realm", classFile = "PALADIN", role = "HEALER",  specID = 65  },
        }
        MPW.PartySnapshot = {
            takenAt = MPW.Now(), runType = MPW.CurrentRunType,
            members = t, valid = true, locked = false,
        }
        PopulateFromSnapshot()
        sendWin:Show()
        MPW.UI.SetSendUIEnabled(true)
        MPW.UI.UpdateAllPreviews()
        if MPW.Access and MPW.Access.ApplyToSendWindow then
            MPW.Access.ApplyToSendWindow(MPW.UI.sendWin)
        end
        return
    end

    -- Live: refresh snapshot before displaying.
    -- For M+ (locked): skipped. For LFG: sticky merge (leavers preserved).
    -- For manual open (/mpw show) when not in a run: pulls live group.
    RefreshSnapshotFromCurrentGroup()

    PopulateFromSnapshot()
    sendWin:Show()
    MPW.UI.SetSendUIEnabled(true)
    MPW.UI.UpdateAllPreviews()
    if MPW.Access and MPW.Access.ApplyToSendWindow then
        MPW.Access.ApplyToSendWindow(MPW.UI.sendWin)
    end
end

-- =========================================
-- Keep the UI roster in sync while the window is open
-- (respects M+ lock; LFG always uses sticky merge)
-- =========================================
local rosterWatcher = CreateFrame("Frame")
rosterWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterWatcher:RegisterEvent("PLAYER_ENTERING_WORLD")

rosterWatcher:SetScript("OnEvent", function()
    if not sendWin or not sendWin:IsShown() then return end
    if MPW.IsTesting then return end
    -- M+ locked snapshot: don't touch it
    if MPW.PartySnapshot and MPW.PartySnapshot.locked then return end
    if MPW.UI._rosterRefreshPending then return end

    MPW.UI._rosterRefreshPending = true
    C_Timer.After(0.20, function()
        MPW.UI._rosterRefreshPending = nil
        if MPW.UI and MPW.UI.RefreshRosterAndRedraw then
            MPW.UI.RefreshRosterAndRedraw()
        end
    end)
end)
