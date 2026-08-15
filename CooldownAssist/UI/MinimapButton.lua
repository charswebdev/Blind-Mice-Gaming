--[[
  Cooldown Assist — minimap button (Media\Icon)
  Left-click: open settings. Drag to reposition.
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.MinimapButton = CA.MinimapButton or {}
local MB = CA.MinimapButton

local ICON_PATH = "Interface\\AddOns\\CooldownAssist\\Media\\Icon.tga"
local BUTTON_NAME = "CooldownAssistMinimapButton"

local button

local function DB()
    return CA.DB and CA.DB.Get and CA.DB.Get() or {}
end

local function Enabled()
    return DB().minimapButtonEnabled ~= false
end

local function GetAngle()
    local a = DB().minimapButtonAngle
    if type(a) ~= "number" then
        return 200
    end
    return a
end

local function SetAngle(angle)
    DB().minimapButtonAngle = angle
end

local function UpdatePosition()
    if not button or not Minimap then
        return
    end
    local angle = math.rad(GetAngle())
    local radius = (Minimap:GetWidth() / 2) + 5
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDrag()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    local angle = math.deg(math.atan2(py - my, px - mx))
    SetAngle(angle)
    UpdatePosition()
end

local function EnsureButton()
    if button then
        return button
    end
    if not Minimap then
        return nil
    end

    button = CreateFrame("Button", BUTTON_NAME, Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = button:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(54, 54)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT", 0, 0)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(20, 20)
    bg:SetPoint("CENTER", 0, 1)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)
    icon:SetTexture(ICON_PATH)
    button.icon = icon

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton ~= "LeftButton" then
            return
        end
        if CA.Settings and CA.Settings.Toggle then
            CA.Settings.Toggle()
        end
    end)

    button:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", OnDrag)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
        UpdatePosition()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Cooldown Assist", 1, 1, 1)
        GameTooltip:AddLine("Left-click: open settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move button", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    UpdatePosition()
    return button
end

function MB.Refresh()
    local btn = EnsureButton()
    if not btn then
        return
    end
    if Enabled() then
        btn:Show()
        UpdatePosition()
    else
        btn:Hide()
    end
end

function MB.IsEnabled()
    return Enabled()
end

local eventFrame = CreateFrame("Frame")
if CA.Compat and CA.Compat.SafeRegisterEvent then
    CA.Compat.SafeRegisterEvent(eventFrame, "PLAYER_LOGIN")
    CA.Compat.SafeRegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
else
    pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_LOGIN")
    pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_ENTERING_WORLD")
end
eventFrame:SetScript("OnEvent", function()
    MB.Refresh()
end)
