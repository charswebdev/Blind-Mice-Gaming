--[[
  AllQuest — minimap button
  Left-click: settings. Right-click: journal. Shift-left: toggle tracker.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.MinimapButton = AQ.MinimapButton or {}
local MB = AQ.MinimapButton

local BUTTON_NAME = "AllQuestMinimapButton"
local button

local function DB()
    return AQ.DB.Get()
end

local function UpdatePosition()
    if not button or not Minimap then
        return
    end
    local angle = math.rad(DB().minimapButtonAngle or 200)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Ensure()
    if button then
        return button
    end
    if not Minimap then
        return nil
    end
    button = CreateFrame("Button", BUTTON_NAME, Minimap)
    button:SetSize(36, 36)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", -1, 1)
    icon:SetTexture(AQ.Logo)
    if icon.SetTexCoord then
        icon:SetTexCoord(0, 1, 0, 1)
    end
    button.Icon = icon

    local hi = button:CreateTexture(nil, "HIGHLIGHT")
    hi:SetAllPoints(icon)
    hi:SetColorTexture(1, 0.92, 0.4, 0.18)
    if hi.SetBlendMode then
        hi:SetBlendMode("ADD")
    end

    button:SetScript("OnDragStart", function()
        button:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            px, py = px / scale, py / scale
            DB().minimapButtonAngle = math.deg(math.atan2(py - my, px - mx))
            UpdatePosition()
        end)
    end)
    button:SetScript("OnDragStop", function()
        button:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnClick", function(_, mouse)
        if IsShiftKeyDown and IsShiftKeyDown() then
            if AQ.Tracker then
                AQ.Tracker.Toggle()
            end
            return
        end
        if mouse == "RightButton" then
            if AQ.Journal then
                AQ.Journal.Toggle()
            end
            return
        end
        if AQ.Settings then
            AQ.Settings.Toggle()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("AllQuest", 1, 0.92, 0.4)
        GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: questline journal", 1, 1, 1)
        GameTooltip:AddLine("Shift-click: toggle tracker", 1, 1, 1)
        GameTooltip:Show()
        AQ.Speech.Replace("AllQuest. Left click settings. Right click journal. Shift click toggle tracker.")
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    UpdatePosition()
    return button
end

function MB.Update()
    local b = Ensure()
    if not b then
        return
    end
    if DB().minimapButtonEnabled == false then
        b:Hide()
    else
        b:Show()
        UpdatePosition()
    end
end
