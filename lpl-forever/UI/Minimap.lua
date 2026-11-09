local _, LPL = ...

LPL.Minimap = LPL.Minimap or {}

local BUTTON_NAME = "LPLForeverMinimapButton"
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

function LPL.Minimap:Settings()
    local db = LPL.DB:Bind(false)
    db.ui = type(db.ui) == "table" and db.ui or {}
    if type(db.ui.minimap) ~= "table" then
        db.ui.minimap = {}
    end
    local settings = db.ui.minimap
    if settings.shown == nil then
        settings.shown = true
    end
    if type(settings.angle) ~= "number" then
        settings.angle = 195
    end
    return settings
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
    local settings = self:Settings()
    if settings.shown then
        button:Show()
        self:Reposition(button, settings.angle or 195)
    else
        button:Hide()
    end
    if self.check then
        self.check:SetChecked(settings.shown == true)
    end
end

function LPL.Minimap:SetShown(shown)
    local settings = self:Settings()
    settings.shown = shown and true or false
    self:Refresh()
end

function LPL.Minimap.OnDragUpdate(button)
    if not button.isDragging or not Minimap then
        return
    end
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not scale or scale == 0 then
        scale = 1
    end
    px, py = px / scale, py / scale
    local mx, my = Minimap:GetCenter()
    local angle = math.deg(math.atan2(py - my, px - mx))
    local settings = LPL.Minimap:Settings()
    settings.angle = angle
    LPL.Minimap:Reposition(button, angle)
end

function LPL.Minimap:Create()
    if not Minimap then
        return nil
    end
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
        icon:SetTexture(LPL.Icons.ADDON)
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
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Light Paws Loadouts", 1, 0.82, 0)
        GameTooltip:AddLine("Left-click to open or close.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click to hide this button.", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Turn it back on in Settings.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetScript("OnUpdate", LPL.Minimap.OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)

    if not self.minimapHooked then
        self.minimapHooked = true
        Minimap:HookScript("OnSizeChanged", function()
            if LPL.Minimap.button and LPL.Minimap.button:IsShown() then
                local settings = LPL.Minimap:Settings()
                LPL.Minimap:Reposition(LPL.Minimap.button, settings.angle or 195)
            end
        end)
    end

    self.button = button
    self:Refresh()
    return button
end
