local _, BMGAM = ...

BMGAM.Minimap = BMGAM.Minimap or {}
local MinimapButton = BMGAM.Minimap

local ICON = "Interface\\AddOns\\BMGAM\\Media\\Icon.tga"
local button

local function UpdatePosition()
    if not button or not Minimap then
        return
    end
    local account = BMGAM.DB.Account()
    local angle = account.minimapAngle or 220
    local radians = math.rad(angle)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function OnDrag()
    local mx, my = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local px, py = GetCursorPosition()
    px, py = px / scale, py / scale
    BMGAM.DB.Account().minimapAngle = math.deg(math.atan2(py - my, px - mx))
    UpdatePosition()
end

local function Ensure()
    if button then
        return button
    end
    if not Minimap then
        return nil
    end
    button = CreateFrame("Button", "BMGAMMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")
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
    icon:SetTexture(ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button:SetScript("OnClick", function()
        if BMGAM.Window and BMGAM.Window.Toggle then
            BMGAM.Window.Toggle()
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
        GameTooltip:SetText("BMG Alt Manager", 1, 0.82, 0.29)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    UpdatePosition()
    return button
end

function MinimapButton.Refresh()
    local created = Ensure()
    if not created then
        return
    end
    if BMGAM.DB.Account().minimap ~= false then
        created:Show()
        UpdatePosition()
    else
        created:Hide()
    end
end
