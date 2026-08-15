local _, ns = ...



local TomTomIntegration = {}

ns.TomTomIntegration = TomTomIntegration



TomTomIntegration.waypointUid = nil

TomTomIntegration.SOURCE = "WowGPS"



function TomTomIntegration:IsAvailable()

    return TomTom ~= nil and type(TomTom.AddWaypoint) == "function"

end



function TomTomIntegration:IsReady()

    return self:IsAvailable()

        and TomTom.db ~= nil

        and TomTom.profile ~= nil

end



function TomTomIntegration:CanShowArrow()

    if not self:IsReady() then

        return false

    end

    return TomTom.profile.arrow and TomTom.profile.arrow.enable ~= false

end



function TomTomIntegration:ArrowIsActive()

    if not self:IsReady() then

        return false

    end

    if TomTomCrazyArrow and TomTomCrazyArrow.IsShown and TomTomCrazyArrow:IsShown() then

        return true

    end

    return false

end



function TomTomIntegration:ClearArrowOnly()

    if not self:IsAvailable() then

        return

    end

    if TomTom.SetCrazyArrow then

        pcall(TomTom.SetCrazyArrow, TomTom, nil)

    end

end



function TomTomIntegration:Clear(removeWaypoint)

    if removeWaypoint == nil then

        removeWaypoint = true

    end



    if not self:IsAvailable() then

        self.waypointUid = nil

        return

    end



    if removeWaypoint and self.waypointUid then

        TomTom:RemoveWaypoint(self.waypointUid)

    end

    self.waypointUid = nil

    self:ClearArrowOnly()

end



function TomTomIntegration:GetStepCoords(step, destFallback)
    if not step then
        return nil
    end

    if ns.SubStepResolver and ns.SubStepResolver.GetNavCoords then
        local mapId, x, y = ns.SubStepResolver:GetNavCoords(step)
        if mapId and x and y then
            return mapId, x, y
        end
    end

    local mapId = step.completionMapId or step.mapId
    local x = ns.Destination and ns.Destination:NormalizeUICoord(step.completionX or step.x)
    local y = ns.Destination and ns.Destination:NormalizeUICoord(step.completionY or step.y)
    if (not mapId or not x or not y) and destFallback then
        mapId, x, y = ns.Destination:NormalizeMapCoords(destFallback.mapId, destFallback.x, destFallback.y)
    end
    if not mapId or not x or not y then
        return nil
    end
    return mapId, x, y
end



function TomTomIntegration:GetStepTitle(step)

    if ns.TravelActions then

        return ns.TravelActions:GetStepDisplayText(step) or "WowGPS"

    end

    return step and (step.text or "WowGPS") or "WowGPS"

end



function TomTomIntegration:WaypointMatchesStep(uid, step)

    if not uid or not step or not TomTom:IsValidWaypoint(uid) then

        return false

    end

    local mapId, x, y = self:GetStepCoords(step)

    if not mapId then

        return false

    end

    return TomTom:WaypointHasSameMapXYTitle(uid, mapId, x, y, self:GetStepTitle(step))

end



function TomTomIntegration:FindWaypointForStep(step)

    if not self:IsReady() or not step then

        return nil

    end



    local mapId, x, y = self:GetStepCoords(step)

    if not mapId then

        return nil

    end



    local title = self:GetStepTitle(step)

    if TomTom:WaypointExists(mapId, x, y, title) then

        local key = TomTom:GetKeyArgs(mapId, x, y, title)

        if TomTom.waypoints and TomTom.waypoints[mapId] then

            return TomTom.waypoints[mapId][key]

        end

    end



    if TomTom.waypoints then

        for _, zoneWaypoints in pairs(TomTom.waypoints) do

            for _, uid in pairs(zoneWaypoints) do

                if uid.from == self.SOURCE and self:WaypointMatchesStep(uid, step) then

                    return uid

                end

            end

        end

    end



    if TomTom.waypointprofile then

        for _, zoneWaypoints in pairs(TomTom.waypointprofile) do

            for _, uid in pairs(zoneWaypoints) do

                if uid.from == self.SOURCE and self:WaypointMatchesStep(uid, step) then

                    return uid

                end

            end

        end

    end



    return nil

end



function TomTomIntegration:SetStep(step, destFallback)

    if not step or not self:IsReady() then

        return false

    end



    local ok, result = pcall(function()
        local mapId, x, y = self:GetStepCoords(step, destFallback)
        if not mapId then
            return false
        end

        local title = self:GetStepTitle(step)
        local existing = self:FindWaypointForStep(step)

        if existing then
            if self.waypointUid and self.waypointUid ~= existing then
                TomTom:RemoveWaypoint(self.waypointUid)
            end
            self.waypointUid = existing
        else
            if self.waypointUid then
                TomTom:RemoveWaypoint(self.waypointUid)
                self.waypointUid = nil
            end

            self.waypointUid = TomTom:AddWaypoint(mapId, x, y, {
                title = title,
                from = self.SOURCE,
                persistent = true,
                minimap = true,
                world = true,
                crazy = true,
                silent = true,
            })
        end

        if not self.waypointUid then
            return false
        end

        if self:CanShowArrow() then
            local arrival = TomTom.profile.arrow.arrival or 15
            TomTom:SetCrazyArrow(self.waypointUid, arrival, title)
        end

        return true
    end)

    if not ok then
        return false
    end

    return result == true

end



function TomTomIntegration:ReattachActiveStep(step, destFallback)

    if not step or not self:IsReady() then

        return false

    end



    local existing = self:FindWaypointForStep(step)

    if not existing then

        return self:SetStep(step, destFallback)

    end



    self.waypointUid = existing

    if self:CanShowArrow() then

        local arrival = TomTom.profile.arrow.arrival or 15

        TomTom:SetCrazyArrow(self.waypointUid, arrival, self:GetStepTitle(step))

    end

    return true

end

-- Pin a destination on TomTom without starting a WowGPS route.
function TomTomIntegration:SetDestinationArrow(dest)
    if not dest then
        return false, "no_dest"
    end

    local step = ns.Destination and ns.Destination:ToNavStep(dest, dest.name)
    if not step then
        return false, "bad_dest"
    end

    if ns.RouteTracker and (ns.RouteTracker.route or ns.RouteTracker.calculating) then
        ns.RouteTracker:End({ keepTab = true })
    end

    local setOk = false
    if self:IsReady() then
        setOk = self:SetStep(step, dest)
    end

    if setOk then
        if ns.FallbackArrow then
            ns.FallbackArrow:Hide()
        end
        return true
    end

    if ns.FallbackArrow then
        ns.FallbackArrow:ShowStep(step)
    end
    if WowGPS and WowGPS.StartTicker then
        WowGPS:StartTicker()
    end

    return true
end


