local addonName, LPL = ...

LPL.Minimap = {}

local BUTTON_NAME = "LPLMinimapButton"
local BUTTON_SIZE = 32
local ICON_SIZE = 20

local minimapShapes = {
    ["ROUND"] = { true, true, true, true },
    ["SQUARE"] = { false, false, false, false },
    ["CORNER-TOPLEFT"] = { false, false, false, true },
    ["CORNER-TOPRIGHT"] = { false, false, true, false },
    ["CORNER-BOTTOMLEFT"] = { false, true, false, false },
    ["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
    ["SIDE-LEFT"] = { false, true, false, true },
    ["SIDE-RIGHT"] = { true, false, true, false },
    ["SIDE-TOP"] = { false, false, true, true },
    ["SIDE-BOTTOM"] = { true, true, false, false },
    ["TRICORNER-TOPLEFT"] = { false, true, true, true },
    ["TRICORNER-TOPRIGHT"] = { true, false, true, true },
    ["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
    ["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local function GetSettings()
    return LPL.DB:GetUI().minimap
end

function LPL.Minimap:Reposition(button, degrees)
    if not button or not Minimap then
        return
    end

    local rounding = 10
    local angle = math.rad(degrees or 195)
    local cos, sin = math.cos(angle), math.sin(angle)
    local q = 1
    if cos < 0 then
        q = q + 1
    end
    if sin > 0 then
        q = q + 2
    end

    local hRadius = (Minimap:GetWidth() / 2) + 5
    local vRadius = (Minimap:GetHeight() / 2) + 5
    local shape = GetMinimapShape and GetMinimapShape() or "ROUND"
    local quadTable = minimapShapes[shape]
    local x, y

    if quadTable and quadTable[q] then
        x = cos * hRadius
        y = sin * vRadius
    else
        local hDiagRadius = math.sqrt(2 * (hRadius ^ 2)) - rounding
        local vDiagRadius = math.sqrt(2 * (vRadius ^ 2)) - rounding
        x = math.max(-hRadius, math.min(cos * hDiagRadius, hRadius))
        y = math.max(-vRadius, math.min(sin * vDiagRadius, vRadius))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function LPL.Minimap:Refresh()
    local button = self.button
    if not button then
        return
    end

    local settings = GetSettings()
    if settings.shown then
        button:Show()
        self:Reposition(button, settings.angle or 195)
    else
        button:Hide()
    end
end

function LPL.Minimap:SetShown(shown)
    local settings = GetSettings()
    settings.shown = shown and true or false
    self:Refresh()
end

function LPL.Minimap:Create()
    if self.button then
        self:Refresh()
        return self.button
    end

    local button = CreateFrame("Button", BUTTON_NAME, Minimap)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(52, 52)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    if not LPL:SetIconTexture(icon, "lpl_32") then
        icon:SetTexture(LPL.Icons.ADDON or LPL:GetIconPath("lpl", 32))
    end
    button.icon = icon

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            LPL.Minimap:SetShown(false)
            return
        end
        if LPL_ToggleMainFrame then
            LPL_ToggleMainFrame()
        end
    end)

    button:SetScript("OnEnter", function(self)
        LPL:ShowGameTooltipLines(self, {
            { text = "Light Paws Loadouts", color = "title" },
            { text = "Left-click to open or close.", color = "gray" },
            { text = "Right-click to hide this button.", color = "gray" },
            { text = "Re-enable in Settings.", color = "gray" },
        }, { anchor = "ANCHOR_LEFT" })
    end)

    button:SetScript("OnLeave", function()
        LPL:ClearGameTooltipData(GameTooltip)
    end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", LPL.Minimap.OnDragUpdate)
        self.isDragging = true
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self.isDragging = false
    end)

    if not self.minimapHooked and Minimap then
        self.minimapHooked = true
        Minimap:HookScript("OnSizeChanged", function()
            if LPL.Minimap.button and LPL.Minimap.button:IsShown() then
                local settings = GetSettings()
                LPL.Minimap:Reposition(LPL.Minimap.button, settings.angle or 195)
            end
        end)
    end

    self.button = button
    self:Refresh()
    return button
end

function LPL.Minimap.OnDragUpdate(frame)
    if not frame.isDragging or not Minimap then
        return
    end

    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local mx, my = Minimap:GetCenter()
    local angle = math.deg(math.atan2(py - my, px - mx))

    local settings = GetSettings()
    settings.angle = angle
    LPL.Minimap:Reposition(frame, angle)
end
