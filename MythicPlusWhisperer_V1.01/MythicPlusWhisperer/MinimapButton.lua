-- MinimapButton.lua
-- Minimap icon with preset logo (WoW texture) + quick controls
-- Left click: /mpw show
-- Right click: settings
-- Shift + Left click: toggle SAFE/LIVE

MPW = MPW or {}

local ICON_TEX = "Interface\\Icons\\inv_misc_key_03" -- preset logo (keystone-style)
local BTN_NAME = "MPW_MinimapButton"

-- Saved per character (optional position)
-- (Core.lua should create MPW_CharConfig; we fallback if not)
local function GetCharCfg()
    MPW_CharConfig = MPW_CharConfig or {}
    MPW_CharConfig.minimap = MPW_CharConfig.minimap or { angle = 220 }
    return MPW_CharConfig
end

local function UpdateIconVisual(btn)
    if not btn or not btn.icon then return end
    local armed = MPW.IsArmed and MPW.IsArmed() or false
    -- simple “glow” via vertex color
    if armed then
        btn.icon:SetVertexColor(1, 0.25, 0.25) -- reddish = LIVE
    else
        btn.icon:SetVertexColor(0.25, 1, 1) -- cyan-ish = SAFE
    end
end

-- Distance from minimap center to place the button around the edge
-- Minimap radius is about 70-75 pixels, so 80 places it just outside
local MINIMAP_RADIUS = 80

local function SetAngle(btn, angle)
    local cfg = GetCharCfg()
    cfg.minimap.angle = angle

    local rad = math.rad(angle)
    local x = math.cos(rad) * MINIMAP_RADIUS
    local y = math.sin(rad) * MINIMAP_RADIUS

    -- Position relative to Minimap center
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end


local function CreateButton()
    if _G[BTN_NAME] then
        UpdateIconVisual(_G[BTN_NAME])
        return
    end

    local btn = CreateFrame("Button", BTN_NAME, Minimap)
    btn:SetClampedToScreen(true)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")

    -- Circular border (nice and centered)
    btn.border = btn:CreateTexture(nil, "BACKGROUND")
    btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border:SetAllPoints()

    -- Icon (bigger) + circular mask so it stays inside the circle
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetTexture(ICON_TEX)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.icon:SetPoint("CENTER", 0, 0)
    btn.icon:SetSize(20, 20)

    -- Mask the icon to a circle (built-in texture)
    btn.mask = btn:CreateMaskTexture()
    btn.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    btn.mask:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.mask:SetSize(22, 22)

    btn.icon:AddMaskTexture(btn.mask)


    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Mythic Plus Whisperer")
        GameTooltip:AddLine("Left click: open window", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Right click: settings", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("Shift+Left: toggle SAFE/LIVE", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(self, button)
        if IsShiftKeyDown() and button == "LeftButton" then
            -- toggle armed
            if MPW.ToggleArmed then
                MPW.ToggleArmed()
            elseif MPW_CharConfig then
                MPW_CharConfig.isArmed = not MPW_CharConfig.isArmed
            end
            UpdateIconVisual(self)
            if MPW.Print and MPW.IsArmed then
                MPW.Print("Mode: " .. (MPW.IsArmed() and "|cffff2020LIVE|r" or "|cff00ffffSAFE|r"))
            end
            return
        end

        if button == "RightButton" then
            if MPW.ShowSettings then MPW.ShowSettings() end
        else
            if MPW.ShowWhisperWindow then
                -- show with current snapshot if available; else just opens empty UI
                MPW.ShowWhisperWindow(false)
            end
        end
    end)

    btn:SetScript("OnDragStart", function(self)
        self:StartMoving()
        self.isDragging = true
    end)

    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.isDragging = false

        -- save angle based on current cursor position around minimap
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetScale()
        cx, cy = cx / scale, cy / scale

        local dx, dy = cx - mx, cy - my
        local angle = math.deg(math.atan2(dy, dx))
        SetAngle(self, angle)
    end)

    local cfg = GetCharCfg()
    SetAngle(btn, cfg.minimap.angle or 220)

    UpdateIconVisual(btn)
end

-- Create on login (safe)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    CreateButton()
end)
