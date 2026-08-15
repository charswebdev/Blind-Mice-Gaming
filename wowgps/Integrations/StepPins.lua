local _, ns = ...

local StepPins = {}
ns.StepPins = StepPins

local HBDP = LibStub("HereBeDragons-Pins-2.0")

local PIN_REF = "WowGPS"
local pins = {}

local COLORS = {
    active = { 0, 0.92, 1, 1 },
    upcoming = { 1, 0.82, 0, 1 },
    completed = { 0.45, 0.45, 0.45, 0.85 },
    missing = { 0.9, 0.25, 0.2, 1 },
}

function StepPins:GetStepCoords(step)
    if not step then
        return nil
    end
    local mapId, x, y
    if ns.SubStepResolver and ns.SubStepResolver.GetNavCoords then
        mapId, x, y = ns.SubStepResolver:GetNavCoords(step)
    else
        mapId = step.completionMapId or step.mapId
        x = step.completionX or step.x
        y = step.completionY or step.y
    end
    if not mapId or not x or not y then
        return nil
    end
    if ns.MapCoords then
        mapId, x, y = ns.MapCoords:OnPlayerMap(mapId, x, y)
    end
    x = ns.Destination and ns.Destination:NormalizeUICoord(x)
    y = ns.Destination and ns.Destination:NormalizeUICoord(y)
    if not x or not y then
        return nil
    end
    return mapId, x, y
end

function StepPins:AttachTooltip(pin)
    pin:SetScript("OnEnter", function(self)
        if self.tooltipTitle then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.tooltipTitle, 1, 1, 1)
            if self.tooltipLines then
                for _, line in ipairs(self.tooltipLines) do
                    GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
                end
            elseif self.tooltipBody then
                GameTooltip:AddLine(self.tooltipBody, 0.9, 0.9, 0.9, true)
            end
            GameTooltip:Show()
        end
    end)
    pin:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function StepPins:CreateNumberPin(label)
    local pin = CreateFrame("Frame", nil, UIParent)
    pin:SetSize(20, 20)
    pin:EnableMouse(true)

    local bg = pin:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Buttons\\WHITE8X8")
    pin.bg = bg

    local ring = pin:CreateTexture(nil, "BORDER")
    ring:SetPoint("TOPLEFT", -1, 1)
    ring:SetPoint("BOTTOMRIGHT", 1, -1)
    ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    ring:SetVertexColor(0, 0, 0, 1)
    pin.ring = ring

    local text = pin:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(label or "?")
    pin.label = text
    pin.icon = nil
    pin.redX = nil

    self:AttachTooltip(pin)
    return pin
end

function StepPins:CreateActionPin(iconId)
    local pin = CreateFrame("Frame", nil, UIParent)
    pin:SetSize(28, 28)
    pin:EnableMouse(true)

    local ring = pin:CreateTexture(nil, "BACKGROUND")
    ring:SetSize(30, 30)
    ring:SetPoint("CENTER")
    ring:SetTexture("Interface\\Buttons\\WHITE8X8")
    ring:SetVertexColor(0, 0, 0, 1)
    pin.ring = ring

    local icon = pin:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetPoint("CENTER")
    icon:SetTexture(iconId)
    pin.icon = icon
    pin.bg = nil
    pin.label = nil

    local redX = pin:CreateTexture(nil, "OVERLAY")
    redX:SetSize(18, 18)
    redX:SetPoint("CENTER", 6, -6)
    redX:SetTexture(ns.TravelActions.RED_X_TEXTURE)
    redX:Hide()
    pin.redX = redX

    self:AttachTooltip(pin)
    return pin
end

function StepPins:SetNumberPinStyle(pin, color, size)
    pin:SetSize(size or 20, size or 20)
    if pin.bg then
        pin.bg:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
    if pin.label then
        pin.label:SetTextColor(0, 0, 0, 1)
    end
    if pin.redX then
        pin.redX:Hide()
    end
end

function StepPins:ApplyVisual(pin, step, route, label, isActive, isCompleted, navMatch)
    local visual = ns.TravelActions:GetStepVisual(step, route)
    local size = (navMatch or isActive) and 28 or 22

    pin.tooltipTitle = string.format(
        "%s. %s",
        label,
        (ns.TravelActions and ns.TravelActions:GetStepDisplayText(step)) or step.text or "Step"
    )
    pin.tooltipLines = ns.TravelActions:GetStepTooltipLines(step, route)

    if visual.showActionIcon and pin.icon then
        pin:SetSize(size, size)
        pin.icon:SetSize(size - 4, size - 4)
        pin.icon:SetTexture(visual.icon)
        if step.completed then
            pin.icon:SetDesaturated(true)
            pin.icon:SetAlpha(0.55)
        else
            pin.icon:SetDesaturated(false)
            pin.icon:SetAlpha(1)
        end
        if pin.ring then
            local ringColor = COLORS.upcoming
            if isCompleted then
                ringColor = COLORS.completed
            elseif navMatch or isActive then
                ringColor = COLORS.active
            elseif visual.showRedX then
                ringColor = COLORS.missing
            end
            pin.ring:SetVertexColor(ringColor[1], ringColor[2], ringColor[3], 1)
        end
        if pin.redX then
            if visual.showRedX then
                pin.redX:Show()
            else
                pin.redX:Hide()
            end
        end
        return
    end

    local color = COLORS.upcoming
    if isCompleted then
        color = COLORS.completed
    elseif navMatch or isActive then
        color = COLORS.active
    elseif visual.showRedX then
        color = COLORS.missing
    end

    self:SetNumberPinStyle(pin, color, (navMatch or isActive) and 24 or 18)

    if not pin.redX and visual.showRedX then
        local redX = pin:CreateTexture(nil, "OVERLAY")
        redX:SetSize(14, 14)
        redX:SetPoint("CENTER", 5, -5)
        redX:SetTexture(ns.TravelActions.RED_X_TEXTURE)
        pin.redX = redX
    end
    if pin.redX then
        if visual.showRedX then
            pin.redX:Show()
        else
            pin.redX:Hide()
        end
    end
end

function StepPins:AddPin(route, step, label, isActive, isCompleted, navMatch)
    local mapId, x, y = self:GetStepCoords(step)
    if not mapId then
        return
    end

    local visual = ns.TravelActions:GetStepVisual(step, route)
    local worldPin
    if visual.showActionIcon then
        worldPin = self:CreateActionPin(visual.icon)
    else
        worldPin = self:CreateNumberPin(label)
    end
    worldPin.step = step
    pins[#pins + 1] = worldPin
    self:ApplyVisual(worldPin, step, route, label, isActive, isCompleted, navMatch)
    HBDP:AddWorldMapIconMap(PIN_REF, worldPin, mapId, x, y)

    if navMatch then
        local miniPin
        if visual.showActionIcon then
            miniPin = self:CreateActionPin(visual.icon)
        else
            miniPin = self:CreateNumberPin(label)
        end
        miniPin.step = step
        pins[#pins + 1] = miniPin
        self:ApplyVisual(miniPin, step, route, label, isActive, isCompleted, navMatch)
        HBDP:AddMinimapIconMap(PIN_REF, miniPin, mapId, x, y, true, true)
    end
end

function StepPins:CollectTargets(route)
    local navStep
    if ns.RouteTracker and ns.RouteTracker.route == route and ns.RouteTracker.GetNavigationStep then
        navStep = ns.RouteTracker:GetNavigationStep()
    end
    if not navStep and ns.SubStepResolver then
        navStep = ns.SubStepResolver:GetNavigationStep(route)
    end
    if not navStep then
        return {}
    end

    local label = tostring(navStep.index or "?")
    local activeIndex = route.activeStepIndex or 1
    for i, step in ipairs(route.steps or {}) do
        if step == navStep then
            label = tostring(i)
            break
        end
    end

    if navStep.isSubStep then
        label = string.format("%da", activeIndex)
    end

    return {
        {
            step = navStep,
            label = label,
            isActive = true,
            isCompleted = false,
            navMatch = true,
        },
    }
end

function StepPins:RefreshVisuals(route)
    if not route then
        return
    end

    local navStep = ns.SubStepResolver and ns.SubStepResolver:GetNavigationStep(route)
    local activeIndex = route.activeStepIndex or 1

    for _, pin in ipairs(pins) do
        local step = pin.step
        if step then
            local label = tostring(step.index or "?")
            local isActive = false
            local isCompleted = step.completed
            local navMatch = (navStep == step)

            for i, routeStep in ipairs(route.steps or {}) do
                if routeStep == step then
                    label = tostring(i)
                    isActive = (i == activeIndex)
                    isCompleted = routeStep.completed
                    break
                end
            end

            self:ApplyVisual(pin, step, route, label, isActive, isCompleted, navMatch)
        end
    end
end

function StepPins:Clear()
    for _, pin in ipairs(pins) do
        HBDP:RemoveWorldMapIcon(PIN_REF, pin)
        HBDP:RemoveMinimapIcon(PIN_REF, pin)
        pin:Hide()
        pin:SetParent(nil)
    end
    wipe(pins)
end

function StepPins:Update(route)
    self:Clear()
    if not route then
        return
    end

    for _, target in ipairs(self:CollectTargets(route)) do
        self:AddPin(
            route,
            target.step,
            target.label,
            target.isActive,
            target.isCompleted,
            target.navMatch
        )
    end
end
