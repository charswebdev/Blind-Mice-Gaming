local addon = Exploration

local btn
local dragging = false
local dragAngle

local function getAngle()
    addon.data.ui = addon.data.ui or {}
    return addon.data.ui.minimapAngle or 220
end

local function saveAngle(angle)
    addon.data.ui = addon.data.ui or {}
    addon.data.ui.minimapAngle = angle
end

local function positionButton()
    if not btn then return end
    local angle = math.rad(getAngle())
    local radius = (Minimap:GetWidth() / 2) + 10
    btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function updateDrag()
    if not dragging or not btn then return end
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx))
    if angle < 0 then angle = angle + 360 end
    dragAngle = angle
    saveAngle(angle)
    positionButton()
end

function addon:InitMinimapButton()
    if btn then
        positionButton()
        return
    end

    btn = CreateFrame("Button", "ExplorationMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("HIGH")
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\AddOns\\Exploration\\Textures\\compass.tga")

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(52, 52)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -12, 12)

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" and not dragging then
            ExplorationFrame:Show()
            if addon.ui and addon.ui.Refresh then
                addon.ui:Refresh()
            end
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Exploration", 1, 1, 1)
        GameTooltip:AddLine("Left-click to open", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click and drag to move", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:RegisterForDrag("RightButton")
    btn:SetScript("OnDragStart", function()
        dragging = true
        dragAngle = getAngle()
        btn:SetScript("OnUpdate", updateDrag)
    end)
    btn:SetScript("OnDragStop", function()
        dragging = false
        btn:SetScript("OnUpdate", nil)
        if dragAngle then
            saveAngle(dragAngle)
        end
        positionButton()
    end)

    positionButton()
    btn:Show()
end
