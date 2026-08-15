local _, ns = ...

local RouteTracker = {}
ns.RouteTracker = RouteTracker

local HBD = LibStub("HereBeDragons-2.0")

local PERSIST_STEP_KEYS = {
    "index", "text", "mapId", "x", "y", "z",
    "completionMapId", "completionX", "completionY",
    "checkDistance", "actionOptions", "instantUse", "completed", "isSubStep",
    "isPortalStep", "portalDestMap", "worldX", "worldY",
}

function RouteTracker:CopyStep(step)
    if not step then
        return nil
    end
    local copy = {}
    for _, key in ipairs(PERSIST_STEP_KEYS) do
        if step[key] ~= nil then
            copy[key] = step[key]
        end
    end
    return copy
end

function RouteTracker:SerializeRoute(route)
    if not route then
        return nil
    end

    local steps = {}
    for i, step in ipairs(route.steps or {}) do
        steps[i] = self:CopyStep(step)
    end

    local subSteps = {}
    for idx, subs in pairs(route.subSteps or {}) do
        subSteps[tostring(idx)] = {}
        for j, sub in ipairs(subs) do
            subSteps[tostring(idx)][j] = self:CopyStep(sub)
        end
    end

    return {
        destination = route.destination,
        steps = steps,
        optimizedPath = route.optimizedPath,
        activeStepIndex = route.activeStepIndex,
        subSteps = subSteps,
        warning = route.warning,
        startedAt = route.startedAt,
        fallback = route.fallback,
    }
end

function RouteTracker:DeserializeSubSteps(subSteps)
    local result = {}
    for idx, subs in pairs(subSteps or {}) do
        result[tonumber(idx) or idx] = subs
    end
    return result
end

function RouteTracker:PersistSession()
    local profile = ns.Database:GetProfile()
    if not self.route then
        profile.activeRoute = nil
        return
    end
    profile.activeRoute = self:SerializeRoute(self.route)
end

function RouteTracker:RestoreSession()
    local data = ns.Database:GetProfile().activeRoute
    if not data or not data.destination or not data.steps or #data.steps == 0 then
        return false
    end

    self.route = {
        destination = data.destination,
        steps = data.steps,
        optimizedPath = data.optimizedPath,
        activeStepIndex = math.max(1, math.min(data.activeStepIndex or 1, #data.steps)),
        subSteps = self:DeserializeSubSteps(data.subSteps),
        warning = data.warning,
        startedAt = data.startedAt or time(),
        fallback = data.fallback,
    }

    for _, step in ipairs(self.route.steps) do
        ns.TravelActions:EvaluateStep(step)
    end
    for _, subs in pairs(self.route.subSteps) do
        for _, sub in ipairs(subs) do
            ns.TravelActions:EvaluateStep(sub)
        end
    end

    if self.addon and self.addon.StartTicker then
        self.addon:StartTicker()
    end

    C_Timer.After(0.1, function()
        if self.route then
            self:AdvancePastCompletedSteps()
            self:ApplyActiveStep()
            if ns.MainFrame then
                ns.MainFrame:RefreshRouteTab()
            end
        end
    end)

    if ns.TomTomIntegration:IsAvailable() and not ns.TomTomIntegration:IsReady() then
        C_Timer.After(0.5, function()
            if self.route then
                self:ApplyActiveStep()
            end
        end)
        C_Timer.After(1.5, function()
            if self.route then
                local navStep = self:GetNavigationStep()
                if navStep then
                    ns.TomTomIntegration:ReattachActiveStep(navStep, self.route.destination)
                end
            end
        end)
    end

    return true
end

function RouteTracker:Init(addon)
    self.addon = addon
    addon.RouteTracker = self
    self.route = nil
    self.calculating = false
    self.pendingDest = nil
    self._completedOnStart = false
    self.seenDestZone = false
    self.zoneChangedAt = nil
    self.lastPlayerZone = nil
    self.tick = 0
    addon:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        RouteTracker:OnPlayerEnteringWorld()
    end)
    addon:RegisterEvent("BAG_UPDATE_DELAYED", function()
        RouteTracker:OnTravelInventoryChanged()
    end)
    addon:RegisterEvent("PLAYER_ALIVE", function()
        RouteTracker:OnTravelInventoryChanged()
    end)
    if C_ToyBox then
        addon:RegisterEvent("TOYS_UPDATED", function()
            RouteTracker:OnTravelInventoryChanged()
        end)
    end
    addon:RegisterEvent("SPELLS_CHANGED", function()
        RouteTracker:OnTravelInventoryChanged()
    end)
    addon:RegisterEvent("HEARTHSTONE_BOUND", function()
        RouteTracker:OnHearthstoneBound()
    end)
    addon:RegisterEvent("ZONE_CHANGED", function()
        RouteTracker:OnZoneChanged()
    end)
    addon:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
        RouteTracker:OnZoneChanged()
    end)
    addon:RegisterEvent("PLAYER_LOGOUT", function()
        ns.Database:PersistAllState()
    end)
    addon:RegisterEvent("ADDONS_UNLOADING", function()
        ns.Database:PersistAllState()
    end)
end

function RouteTracker:IsUseNowActive()
    local step = self:GetActiveStep()
    return step and ns.TravelActions:IsInstantUseStep(step)
end

function RouteTracker:IsInZoneChangeHysteresis()
    return self.zoneChangedAt and (GetTime() - self.zoneChangedAt) < 1.2
end

function RouteTracker:ShouldPreferDestAim()
    return self.seenDestZone == true and self:IsInZoneChangeHysteresis()
end

function RouteTracker:NotePlayerZone()
    local zone = ns.TravelRegions and ns.TravelRegions:GetPlayerMapId()
    if not zone then
        return
    end
    self.lastPlayerZone = zone
    local dest = self.route and self.route.destination
    if dest and dest.mapId then
        local destZone = ns.TravelRegions:ResolveZoneMapId(dest.mapId)
        if destZone == zone then
            self.seenDestZone = true
        end
    end
    local step = self:GetActiveStep()
    if step then
        local destMap = step.portalDestMap or step.completionMapId
        if not destMap and ns.SubStepResolver then
            destMap = ns.SubStepResolver:InferPortalDestMap(step)
        end
        if destMap then
            local destZone = ns.TravelRegions:ResolveZoneMapId(destMap)
            if destZone == zone then
                self.seenDestZone = true
            end
        end
    end
end

function RouteTracker:OnZoneChanged()
    if not self.route then
        return
    end
    self.zoneChangedAt = GetTime()
    self:NotePlayerZone()
    self:AdvancePastCompletedSteps()
    self:CheckInstantUseArrival()
    self:ApplyActiveStep()
end

function RouteTracker:IsPortalStep(step)
    if not step then
        return false
    end
    if step.isPortalStep then
        return true
    end
    return ns.SubStepResolver and ns.SubStepResolver:IsPortalStep(step)
end

function RouteTracker:ShouldAdvancePortalStep(step)
    local playerZone = ns.TravelRegions and ns.TravelRegions:GetPlayerMapId()
    if not playerZone then
        return false
    end

    local destMap = step.portalDestMap
    if not destMap and ns.SubStepResolver then
        destMap = ns.SubStepResolver:InferPortalDestMap(step)
    end
    destMap = destMap or step.completionMapId
    local destZone = destMap and ns.TravelRegions:ResolveZoneMapId(destMap)
    if destZone and playerZone == destZone then
        self.seenDestZone = true
        return true
    end
    if self.seenDestZone then
        return true
    end

    -- Left the start map (wait out GetBestMapForUnit flicker first).
    local startZone = step.mapId and ns.TravelRegions:ResolveZoneMapId(step.mapId)
    if startZone and playerZone ~= startZone and not self:IsInZoneChangeHysteresis() then
        return true
    end

    return false
end

function RouteTracker:ShouldAdvanceStep(step)
    if not step or step.completed then
        return false
    end

    if self:IsPortalStep(step) then
        return self:ShouldAdvancePortalStep(step)
    end

    if ns.SubStepResolver:IsTransitStep(step) then
        return ns.SubStepResolver:IsPlayerAtCompletion(step)
    end

    if not step.checkDistance then
        return self:IsPlayerAtDestination() or ns.SubStepResolver:IsPlayerAtCompletion(step)
    end

    local yards = self:DistanceToStep(step)
    return yards and yards <= ns.Constants.STEP_COMPLETE_YARDS
end

function RouteTracker:IsPlayerAtDestination()
    local dest = self.route and self.route.destination
    if not dest or not dest.mapId then
        return false
    end

    local mapId, x, y = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
    if not mapId or not x or not y then
        return false
    end

    return ns.SubStepResolver:IsPlayerAtCoords(mapId, x, y)
end

function RouteTracker:ShouldSkipTravelStep(step)
    if not step or step.completed then
        return false
    end

    if not self:IsPlayerAtDestination() then
        return false
    end

    if ns.SubStepResolver:IsPlayerAtCompletion(step) then
        return false
    end

    if ns.TravelActions:IsRemoteTravelStep(step) then
        return true
    end

    local dest = self.route.destination
    local stepMap = step.completionMapId or step.mapId
    local stepX = step.completionX or step.x
    local stepY = step.completionY or step.y
    local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
    if destMap and stepMap and stepX and stepY and destX and destY then
        if stepMap ~= destMap
            or math.abs(stepX - destX) > 0.02
            or math.abs(stepY - destY) > 0.02 then
            return true
        end
    end

    return false
end

function RouteTracker:AdvancePastCompletedSteps()
    if not self.route or not self.route.steps then
        return
    end

    local maxSteps = #self.route.steps
    local guard = 0

    while guard < maxSteps + 2 do
        guard = guard + 1
        local step = self:GetActiveStep()
        if not step then
            break
        end

        if self:IsPlayerAtDestination() then
            if self.route.activeStepIndex >= maxSteps then
                self:AdvanceStep(false)
                return
            end
            if self:ShouldSkipTravelStep(step) then
                self:AdvanceStep(false)
            else
                break
            end
        elseif self:ShouldAdvanceStep(step) then
            self:AdvanceStep(false)
        else
            break
        end
    end
end

function RouteTracker:CheckInstantUseArrival()
    local step = self:GetActiveStep()
    if not step then
        return
    end
    if ns.TravelActions:HasArrivedAfterInstantUse(step) then
        self:AdvanceStep(false)
    end
end

function RouteTracker:BuildDirectWalkRoute(dest)
    local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest and dest.mapId, dest and dest.x, dest and dest.y)
    if not destMap or not destX or not destY then
        return nil
    end

    -- Never invent a straight Maw pin — cliffs/void drops are lethal.
    if ns.TravelRegions then
        if ns.TravelRegions:IsMawMap(destMap) then
            return nil
        end
        local playerMap = ns.TravelRegions:GetPlayerMapId()
        if playerMap and ns.TravelRegions:IsMawMap(playerMap) then
            return nil
        end
    end

    local loc = {
        mapId = destMap,
        pos = { x = destX, y = destY, z = dest.z or 0 },
        isUI = true,
    }
    return {
        optimizedPath = {
            {
                loca = string.format("Travel to %s", dest.name or "destination"),
                loc = loc,
                completionLoc = loc,
                checkDistance = true,
            },
        },
        path = {},
        edges = {},
        destination = dest,
        fallback = true,
        directWalk = true,
    }
end

function RouteTracker:StartViaLocalFallback(dest)
    -- Maw corridors first: never fall through to an unsafe straight walk in The Maw.
    if ns.MawLocalRoutes then
        local mawRoute = ns.MawLocalRoutes:TryRoute(dest)
        if mawRoute then
            return self:FinishStart(dest, mawRoute, nil)
        end
        local playerMap = ns.TravelRegions and ns.TravelRegions:GetPlayerMapId()
        local inMaw = ns.TravelRegions and ns.TravelRegions:IsMawMap(playerMap)
        local destMaw = ns.TravelRegions and ns.TravelRegions:IsMawRelatedDest(dest and dest.mapId)
        if inMaw and destMaw then
            return false, "maw_unsafe"
        end
    end

    if ns.MidnightLocalRoutes then
        local routeResult = ns.MidnightLocalRoutes:TryRoute(dest)
        if routeResult then
            return self:FinishStart(dest, routeResult, nil)
        end
    end

    local walkRoute = self:BuildDirectWalkRoute(dest)
    if walkRoute then
        return self:FinishStart(dest, walkRoute, nil)
    end

    if dest and dest.mapId and ns.TravelRegions and ns.TravelRegions:IsMawMap(dest.mapId) then
        return false, "maw_unsafe"
    end
    return false, "no_path"
end

function RouteTracker:OnLocalFallbackFailed(err)
    self:ClearCalculating()
    if ns.MainFrame and ns.MainFrame.RefreshRouteTab then
        ns.MainFrame:RefreshRouteTab()
    end
    if not self.addon then
        return
    end
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    if err == "maw_unsafe" then
        self.addon:Print(L["ROUTE_MAW_UNSAFE"] or L["ROUTE_FAILED"])
    else
        self.addon:Print(L["ROUTE_FAILED"])
    end
end

function RouteTracker:StartViaZygor(dest)
    if not ns.ZygorTravel:IsAvailable() then
        return self:StartViaLocalFallback(dest)
    end

    self:BeginCalculating(dest)

    local queued = ns.ZygorTravel:RequestRoute(dest, function(routeResult, err)
        if routeResult then
            local ok, finishErr = RouteTracker:FinishStart(dest, routeResult, nil)
            if not ok then
                if RouteTracker.addon then
                    RouteTracker.addon:Print("|cffFF4444WowGPS:|r Zygor route failed: " .. tostring(finishErr or "no_steps"))
                end
                local okFb, fbErr = RouteTracker:StartViaLocalFallback(dest)
                if not okFb then
                    RouteTracker:OnLocalFallbackFailed(fbErr)
                end
            end
        else
            local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
            if RouteTracker.addon then
                RouteTracker.addon:Print(L["ZYGOR_ROUTE_FALLBACK"] or "Zygor travel failed; trying local routing.")
            end
            local okFb, fbErr = RouteTracker:StartViaLocalFallback(dest)
            if not okFb then
                RouteTracker:OnLocalFallbackFailed(fbErr)
            end
        end
    end)

    if not queued then
        if self.route or self._completedOnStart then
            return true
        end
        self:ClearCalculating()
        if ns.MainFrame and ns.MainFrame.RefreshRouteTab then
            ns.MainFrame:RefreshRouteTab()
        end
        return false, "zygor_not_ready"
    end

    -- LibRover sometimes finishes before QueueFindPath returns.
    if not self.calculating then
        return self.route ~= nil or self._completedOnStart
    end

    if self.addon then
        local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
        self.addon:Print(L["ROUTE_CALCULATING_ZYGOR"] or "Calculating route with Zygor travel...")
    end
    return true, "calculating"
end

function RouteTracker:BeginCalculating(dest)
    self.calculating = true
    self.pendingDest = dest
    self._completedOnStart = false
    self.route = nil
    if ns.TomTomIntegration then
        ns.TomTomIntegration:Clear()
    end
    if ns.FallbackArrow then
        ns.FallbackArrow:Hide()
    end
    if ns.MapRoute then
        ns.MapRoute:Clear()
    end
    if ns.StepPins then
        ns.StepPins:Clear()
    end
    if ns.MainFrame and ns.MainFrame.ShowRouteTab then
        ns.MainFrame:ShowRouteTab()
    elseif ns.MainFrame and ns.MainFrame.RefreshRouteTab then
        ns.MainFrame:RefreshRouteTab()
    end
end

function RouteTracker:ClearCalculating()
    self.calculating = false
    self.pendingDest = nil
end

function RouteTracker:Start(dest)
    self._completedOnStart = false
    self.seenDestZone = false
    self.zoneChangedAt = nil
    self.lastPlayerZone = nil
    if not dest then
        return false, "no_dest"
    end

    local mapId, x, y = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
    if not mapId then
        return false, "bad_dest"
    end

    local normalized = {}
    for k, v in pairs(dest) do
        normalized[k] = v
    end
    normalized.mapId = mapId
    normalized.x = x
    normalized.y = y
    dest = normalized

    -- In The Maw, prefer road corridors over Zygor (safer vs cliffs/void).
    if ns.MawLocalRoutes and ns.MawLocalRoutes:ShouldUseFor(dest) then
        local mawRoute = ns.MawLocalRoutes:TryRoute(dest)
        if mawRoute then
            return self:FinishStart(dest, mawRoute, nil)
        end
    end

    if ns.ZygorTravel and ns.ZygorTravel:IsAvailable() then
        return self:StartViaZygor(dest)
    end

    if self.addon and ns.ZygorTravel then
        local msg = ns.ZygorTravel:GetStatusMessage()
        if msg then
            self.addon:Print("|cffFFCC00WowGPS:|r " .. msg)
        end
    end

    return self:StartViaLocalFallback(dest)
end

function RouteTracker:FinishStart(dest, routeResult, err)
    if not routeResult then
        self:ClearCalculating()
        return false, err or "no_path"
    end

    local warning = ns.PlayerContext:GetPhaseWarning(dest)
    if routeResult.zygorTravel then
        warning = (warning and (warning .. " ") or "")
            .. "|cff88ccffWowGPS:|r Route planned with Zygor travel."
    elseif routeResult.mawLocal then
        warning = (warning and (warning .. " ") or "")
            .. "|cffFFCC00WowGPS:|r Using Maw road corridor pins (stay on the marked path)."
    elseif routeResult.midnightLocal then
        warning = (warning and (warning .. " ") or "")
            .. "|cffFFCC00WowGPS:|r Using local Midnight portal routing (Zygor unavailable or no path)."
    end

    local stepsOk, steps = pcall(ns.StepBuilder.FromRoute, ns.StepBuilder, routeResult)
    if not stepsOk then
        self:ClearCalculating()
        return false, tostring(steps)
    end

    if #steps == 0 then
        local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
        -- Never invent a straight Maw pin — cliffs/void drops are lethal.
        if destMap and ns.TravelRegions and ns.TravelRegions:IsMawMap(destMap) then
            self:ClearCalculating()
            return false, "maw_unsafe"
        end
        if destMap and destX and destY then
            steps[1] = {
                index = 1,
                text = string.format("Travel to %s", dest.name or "destination"),
                mapId = destMap,
                x = destX,
                y = destY,
                z = dest.z or 0,
                completionMapId = destMap,
                completionX = destX,
                completionY = destY,
                checkDistance = true,
                completed = false,
            }
        end
    end

    self.route = {
        destination = dest,
        steps = steps,
        optimizedPath = routeResult.optimizedPath,
        activeStepIndex = 1,
        subSteps = {},
        warning = warning,
        routeWarnings = nil,
        startedAt = time(),
        fallback = routeResult.fallback,
    }

    if ns.RouteValidator then
        local analyzeOk, analyzeErr = pcall(function()
            self.route.routeWarnings = ns.RouteValidator:Analyze(self.route)
            local validatorText = ns.RouteValidator:FormatWarnings(self.route.routeWarnings)
            if validatorText then
                warning = (warning and (warning .. " ") or "") .. validatorText
                self.route.warning = warning
            end
        end)
        if not analyzeOk and self.addon then
            self.addon:Print("|cffFFCC00WowGPS:|r Route warning check skipped: " .. tostring(analyzeErr))
        end
    end

    if #self.route.steps == 0 then
        self.route = nil
        self:ClearCalculating()
        return false, "no_steps"
    end

    self:ClearCalculating()
    self.seenDestZone = false
    self.zoneChangedAt = nil
    self:NotePlayerZone()

    local advanceOk, advanceErr = pcall(function()
        self:AdvancePastCompletedSteps()
    end)
    if not advanceOk then
        return false, tostring(advanceErr)
    end

    -- Already at the destination: AdvancePastCompletedSteps called End().
    if not self.route then
        self._completedOnStart = true
        return true
    end

    local applyOk, applyErr = pcall(function()
        self:ApplyActiveStep()
    end)
    if not applyOk then
        if self.addon then
            self.addon:Print("|cffFFCC00WowGPS:|r Route started, but map overlay failed: " .. tostring(applyErr))
        end
    end

    if ns.TomTomIntegration:IsAvailable() and not ns.TomTomIntegration:IsReady() then
        C_Timer.After(0.5, function()
            if self.route then
                pcall(function() self:ApplyActiveStep() end)
            end
        end)
        C_Timer.After(1.5, function()
            if self.route then
                local navStep = self:GetNavigationStep()
                if navStep then
                    ns.TomTomIntegration:ReattachActiveStep(navStep, self.route.destination)
                end
            end
        end)
    end

    if ns.MainFrame and ns.MainFrame.ShowRouteTab then
        ns.MainFrame:ShowRouteTab()
    end
    if self.addon and self.addon.StartTicker then
        self.addon:StartTicker()
    end

    if warning and self.addon then
        self.addon:Print(warning)
    end

    if self.addon then
        local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
        self.addon:Print(string.format(L["ROUTE_STARTED"] or "|cff33CCFFWowGPS:|r Route started to %s. See the Route tab.", dest.name or "destination"))
    end

    self:PersistSession()
    return true
end

function RouteTracker:End(opts)
    opts = opts or {}
    if ns.ZygorTravel then
        ns.ZygorTravel:CancelRequest()
    end
    self:ClearCalculating()
    self.route = nil
    self.seenDestZone = false
    self.zoneChangedAt = nil
    self.lastPlayerZone = nil
    ns.Database:GetProfile().activeRoute = nil
    ns.TomTomIntegration:Clear()
    ns.FallbackArrow:Hide()
    ns.MapRoute:Clear()
    ns.StepPins:Clear()
    self.addon:StopTicker()
    if not opts.keepTab then
        ns.MainFrame:ShowSearchTab()
    end
end

function RouteTracker:GetActiveStep()
    if not self.route then return nil end
    return self.route.steps[self.route.activeStepIndex]
end

function RouteTracker:GetNavigationStep()
    if not self.route then return nil end
    return self:ResolveNavStep(ns.SubStepResolver:GetNavigationStep(self.route))
end

function RouteTracker:ResolveNavStep(step)
    step = self:NormalizeStepCoords(step)
    if step then
        return step
    end

    if self.route and self.route.destination then
        return ns.Destination:ToNavStep(self.route.destination)
    end

    return nil
end

function RouteTracker:NormalizeStepCoords(step)
    if not step then
        return nil
    end

    local mapId = step.completionMapId or step.mapId
    local x = ns.Destination:NormalizeUICoord(step.completionX or step.x)
    local y = ns.Destination:NormalizeUICoord(step.completionY or step.y)
    if not mapId or not x or not y then
        return nil
    end

    step.mapId = mapId
    step.x = x
    step.y = y
    step.completionMapId = mapId
    step.completionX = x
    step.completionY = y
    return step
end

function RouteTracker:ApplyActiveStep()
    local step = self:GetActiveStep()
    if not step then return end

    ns.TravelActions:EvaluateStep(step)

    if self:IsUseNowActive() then
        ns.TomTomIntegration:Clear()
        ns.FallbackArrow:ShowUseNow(step)
        ns.MapRoute:Update(self.route)
        ns.StepPins:Update(self.route)
        ns.MainFrame:RefreshRouteTab()
        return
    end

    local navStep = self:GetNavigationStep()

    if ns.TomTomIntegration:IsAvailable() then
        if navStep then
            local setOk = ns.TomTomIntegration:SetStep(navStep, self.route and self.route.destination)
            if not setOk and self.route and self.route.destination then
                ns.TomTomIntegration:SetStep(
                    ns.Destination:ToNavStep(self.route.destination, navStep.text),
                    self.route.destination
                )
            end
        else
            ns.TomTomIntegration:Clear()
        end
    end

    if ns.TomTomIntegration:ArrowIsActive() then
        ns.FallbackArrow:Hide()
    elseif navStep then
        ns.FallbackArrow:ShowStep(navStep)
    else
        ns.FallbackArrow:Hide()
    end

    pcall(function()
        ns.MapRoute:Update(self.route)
    end)
    pcall(function()
        ns.StepPins:Update(self.route)
    end)
    ns.MainFrame:RefreshRouteTab()
end

function RouteTracker:OnTravelInventoryChanged()
    if not self.route then
        return
    end
    self:ApplyActiveStep()
end

function RouteTracker:OnHearthstoneBound()
    if not self.route or not self.route.destination then
        return
    end
    self:Recalculate()
end

function RouteTracker:AdvanceStep(manual)
    if not self.route then return end
    local step = self:GetActiveStep()
    if step then
        step.completed = true
    end

    if self.route.activeStepIndex >= #self.route.steps then
        local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
        self.addon:Print(L["ARRIVED"])
        self:End()
        return
    end

    self.route.activeStepIndex = self.route.activeStepIndex + 1
    if self.route.subSteps then
        self.route.subSteps[self.route.activeStepIndex - 1] = nil
    end
    self:PersistSession()
    self:ApplyActiveStep()
end

function RouteTracker:PreviousStep()
    if not self.route then return end
    if self.route.activeStepIndex <= 1 then return end

    self.route.activeStepIndex = self.route.activeStepIndex - 1
    local step = self:GetActiveStep()
    if step then
        step.completed = false
    end
    self:PersistSession()
    self:ApplyActiveStep()
end

function RouteTracker:Recalculate()
    if not self.route or not self.route.destination then return end
    self:Start(self.route.destination)
end

function RouteTracker:DistanceToStep(step)
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId or not step then return nil end

    local pos = C_Map.GetPlayerMapPosition(mapId, "player")
    if not pos then return nil end

    local cx, cy, targetMap
    if ns.SubStepResolver and ns.SubStepResolver.GetNavCoords then
        targetMap, cx, cy = ns.SubStepResolver:GetNavCoords(step)
    else
        cx = step.completionX or step.x
        cy = step.completionY or step.y
        targetMap = step.completionMapId or step.mapId
    end
    if not cx or not cy or not targetMap then return nil end

    if ns.MapCoords then
        local dist = ns.MapCoords:GetZoneDistance(mapId, pos.x, pos.y, targetMap, cx, cy)
        if dist then
            return dist
        end
    end

    return HBD:GetZoneDistance(mapId, pos.x, pos.y, targetMap, cx, cy)
end

function RouteTracker:OnTick(elapsed)
    if not self.route then return end

    self.persistTick = (self.persistTick or 0) + elapsed
    if self.persistTick >= 15 then
        self.persistTick = 0
        self:PersistSession()
    end

    self.tick = self.tick + elapsed
    if self.tick < 0.5 then return end
    self.tick = 0

    self:AdvancePastCompletedSteps()
    if not self.route then
        return
    end

    self:CheckInstantUseArrival()
    if not self.route then
        return
    end

    if self:IsUseNowActive() then
        ns.TomTomIntegration:Clear()
        ns.FallbackArrow:ShowUseNow(self:GetActiveStep())
        ns.MapRoute:Update(self.route)
        ns.TravelActions:RefreshRoute(self.route)
        ns.StepPins:RefreshVisuals(self.route)
        ns.MainFrame:RefreshRouteTab()
        return
    end

    local navStep = self:GetNavigationStep()
    if navStep and navStep.isSubStep and navStep.checkDistance then
        local yards = self:DistanceToStep(navStep)
        if yards and yards <= ns.SubStepResolver.SUB_STEP_YARDS then
            ns.SubStepResolver:CompleteNavigationStep(self.route, navStep)
            self:ApplyActiveStep()
            return
        end
    end

    if ns.TomTomIntegration:IsAvailable() and ns.TomTomIntegration.waypointUid then
        if ns.TomTomIntegration:ArrowIsActive() then
            ns.FallbackArrow:Hide()
        elseif not ns.FallbackArrow:IsUseNowShown() then
            local currentNav = self:GetNavigationStep()
            if currentNav then
                ns.FallbackArrow:ShowStep(currentNav)
            end
        end
    end

    ns.TravelActions:RefreshRoute(self.route)
    ns.StepPins:RefreshVisuals(self.route)
    ns.MainFrame:RefreshRouteTab()

    local step = self:GetActiveStep()
    if not step then return end

    if self:ShouldAdvanceStep(step) then
        self:AdvanceStep(false)
    end
end

function RouteTracker:OnPlayerEnteringWorld()
    if self.route then
        self:AdvancePastCompletedSteps()
        self:ApplyActiveStep()
        if ns.MainFrame then
            ns.MainFrame:RefreshRouteTab()
        end
    end
end
