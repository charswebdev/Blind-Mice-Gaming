local _, ns = ...

local FallbackArrow = {}
ns.FallbackArrow = FallbackArrow

function FallbackArrow:Init()
    if self.frame then
        return
    end

    local f = CreateFrame("Frame", "WowGPSFallbackArrow", UIParent)
    f:SetSize(64, 64)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, -100)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:Hide()

    f.arrow = f:CreateTexture(nil, "ARTWORK")
    f.arrow:SetSize(52, 52)
    f.arrow:SetPoint("CENTER")
    f.arrow:SetTexture("Interface\\Minimap\\Minimap-Arrow")

    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.label:SetPoint("TOP", f, "BOTTOM", 0, -4)
    f.label:SetTextColor(0.95, 0.95, 0.95)
    f.label:SetWidth(320)
    f.label:SetJustifyH("CENTER")

    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOP", f.label, "BOTTOM", 0, -2)
    f.hint:SetTextColor(0.55, 0.95, 0.55)
    f.hint:SetWidth(320)
    f.hint:SetJustifyH("CENTER")

    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    self.frame = f
    self.mode = nil
end

function FallbackArrow:ShowUseNow(step)
    self:Init()
    if not self.frame or not step then
        self:Hide()
        return
    end

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS", true)
    local action = ns.TravelActions and ns.TravelActions:GetBestAction(step)
    local icon = (action and action.icon) or 134400

    self.mode = "use"
    self.step = step
    self.frame.arrow:SetTexture(icon)
    self.frame.arrow:SetSize(48, 48)
    self.frame.arrow:SetRotation(0)
    self.frame.label:SetText(
        (ns.TravelActions and ns.TravelActions:GetStepDisplayText(step))
            or (action and action.name)
            or ""
    )
    self.frame.hint:SetText(L and L["USE_NOW"] or "Use now")
    self.frame.hint:Show()
    self.frame:Show()
end

function FallbackArrow:ShowStep(step)
    self:Init()
    if not self.frame or not step then
        self:Hide()
        return
    end

    self.mode = "nav"
    self.step = step
    self.frame.arrow:SetTexture("Interface\\Minimap\\Minimap-Arrow")
    self.frame.arrow:SetSize(52, 52)
    self.frame.label:SetText(
        (ns.TravelActions and ns.TravelActions:GetStepDisplayText(step)) or ""
    )
    self.frame.hint:Hide()
    self.frame:Show()
    self:UpdateDirection()
end

function FallbackArrow:Hide()
    if self.frame then
        self.frame:Hide()
    end
    self.step = nil
    self.mode = nil
end

function FallbackArrow:UpdateDirection()
    if not self.frame or not self.step or self.mode ~= "nav" then
        return
    end

    local route = ns.RouteTracker and ns.RouteTracker.route
    local angle = ns.MapRoute:GetBearingToStep(self.step, route)
    if not angle then
        return
    end

    local facing = GetPlayerFacing() or 0
    self.frame.arrow:SetRotation(angle - facing)
end

function FallbackArrow:OnTick()
    if self.frame and self.frame:IsShown() and self.mode == "nav" then
        self:UpdateDirection()
    end
end

function FallbackArrow:IsUseNowShown()
    return self.frame and self.frame:IsShown() and self.mode == "use"
end
