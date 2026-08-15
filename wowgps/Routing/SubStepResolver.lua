local _, ns = ...

local SubStepResolver = {}
ns.SubStepResolver = SubStepResolver

local HBD = LibStub("HereBeDragons-2.0")

local SUB_STEP_YARDS = 40

function SubStepResolver:GetPlayerInstance()
    local _, _, instance = HBD:GetPlayerWorldPosition()
    return instance
end

function SubStepResolver:GetCompletionCoords(step)
    if not step then
        return nil
    end
    local mapId = step.completionMapId or step.mapId
    local x = ns.Destination and ns.Destination:NormalizeUICoord(step.completionX or step.x)
    local y = ns.Destination and ns.Destination:NormalizeUICoord(step.completionY or step.y)
    if not mapId or not x or not y then
        return nil
    end
    return mapId, x, y
end

function SubStepResolver:IsCompletionReachable(step)
    local mapId, x, y = self:GetCompletionCoords(step)
    if not mapId then
        return false
    end

    local playerInst = self:GetPlayerInstance()
    local _, _, compInst = HBD:GetWorldCoordinatesFromZone(x, y, mapId)
    if not playerInst or not compInst then
        return false
    end
    return playerInst == compInst
end

function SubStepResolver:IsPlayerAtCoords(mapId, x, y, yards)
    if not mapId or x == nil or y == nil then
        return false
    end

    x = ns.Destination and ns.Destination:NormalizeUICoord(x)
    y = ns.Destination and ns.Destination:NormalizeUICoord(y)
    if not x or not y then
        return false
    end

    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then
        return false
    end

    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then
        return false
    end

    local playerZone = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(playerMap) or playerMap
    local targetZone = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(mapId) or mapId
    if playerZone == targetZone and ns.MapCoords then
        local distance = ns.MapCoords:GetZoneDistance(playerMap, pos.x, pos.y, mapId, x, y)
        if distance then
            return distance <= (yards or ns.Constants.STEP_COMPLETE_YARDS)
        end
    end

    local _, _, playerInst = HBD:GetWorldCoordinatesFromZone(pos.x, pos.y, playerMap)
    local _, _, targetInst = HBD:GetWorldCoordinatesFromZone(x, y, mapId)
    if not playerInst or not targetInst or playerInst ~= targetInst then
        return false
    end

    local distance = ns.MapCoords and ns.MapCoords:GetZoneDistance(playerMap, pos.x, pos.y, mapId, x, y)
    if not distance and HBD then
        distance = HBD:GetZoneDistance(playerMap, pos.x, pos.y, mapId, x, y)
    end
    return distance and distance <= (yards or ns.Constants.STEP_COMPLETE_YARDS)
end

function SubStepResolver:IsTransitStep(step)
    if not step then
        return false
    end

    local startMap = step.mapId
    local startX = ns.Destination and ns.Destination:NormalizeUICoord(step.x)
    local startY = ns.Destination and ns.Destination:NormalizeUICoord(step.y)
    local compMap = step.completionMapId or step.mapId
    local compX = ns.Destination and ns.Destination:NormalizeUICoord(step.completionX or step.x)
    local compY = ns.Destination and ns.Destination:NormalizeUICoord(step.completionY or step.y)

    if not startMap or not compMap or not startX or not startY or not compX or not compY then
        return false
    end

    if startMap ~= compMap then
        return true
    end

    local _, _, startInst = HBD:GetWorldCoordinatesFromZone(startX, startY, startMap)
    local _, _, compInst = HBD:GetWorldCoordinatesFromZone(compX, compY, compMap)
    if startInst and compInst and startInst ~= compInst then
        return true
    end

    return false
end

function SubStepResolver:IsPlayerAtCompletion(step)
    if not self:IsCompletionReachable(step) then
        return false
    end

    local mapId, x, y = self:GetCompletionCoords(step)
    if not mapId then
        return false
    end

    return self:IsPlayerAtCoords(mapId, x, y)
end

function SubStepResolver:GetStepInstance(step)
    local mapId, x, y = self:GetNavCoords(step)
    if not mapId or not x or not y then
        return nil
    end
    local _, _, instance = HBD:GetWorldCoordinatesFromZone(x, y, mapId)
    return instance
end

function SubStepResolver:IsPortalStep(step)
    if not step then
        return false
    end
    if step.isPortalStep then
        return true
    end
    local text = (step.text or ""):lower()
    if text:find("^travel to", 1, false) then
        return false
    end
    return text:find("click the portal", 1, true) ~= nil
        or text:find("click portal", 1, true) ~= nil
        or text:find("take the portal", 1, true) ~= nil
        or text:find("take portal", 1, true) ~= nil
        or text:find("take ship", 1, true) ~= nil
        or text:find("take tram", 1, true) ~= nil
        or text:find("take zeppelin", 1, true) ~= nil
        or (text:find("portal to", 1, true) ~= nil and text:find("^travel to", 1, false) == nil)
end

function SubStepResolver:InferPortalDestMap(step)
    if step and step.portalDestMap then
        return step.portalDestMap
    end
    local text = (step.text or ""):lower()
    if text:find("voidstorm", 1, true) then
        return 2405
    end
    if text:find("harandar", 1, true) then
        return 2413
    end
    if text:find("arcantina", 1, true) then
        return 2541
    end
    if text:find("silvermoon", 1, true) and step and step.mapId == 2405 then
        return 2393
    end
    return nil
end

function SubStepResolver:GetPortalEntranceCoords(step)
    if not step or not self:IsPortalStep(step) then
        return nil
    end

    -- Always look up from the step's start map. Using the player's current map
    -- after a zone cross returns the A-side entrance projected onto B (behind you).
    local destMap = self:InferPortalDestMap(step)
    local startMap = step.mapId
    if startMap and ns.TravelRegions then
        startMap = ns.TravelRegions:ResolveZoneMapId(startMap) or startMap
    end
    if destMap and startMap and ns.MidnightLocalRoutes then
        local mapId, x, y = ns.MidnightLocalRoutes:GetPortalEntrance(startMap, destMap)
        if mapId and x and y then
            return mapId, x, y
        end
    end

    local mapId = step.mapId
    local x = ns.Destination and ns.Destination:NormalizeUICoord(step.x)
    local y = ns.Destination and ns.Destination:NormalizeUICoord(step.y)
    if mapId and x and y then
        return mapId, x, y
    end
    return nil
end

function SubStepResolver:GetDestAimCoords(step)
    local dest = ns.RouteTracker and ns.RouteTracker.route and ns.RouteTracker.route.destination
    if dest then
        local mapId, x, y = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
        if mapId then
            return mapId, x, y
        end
    end
    return self:GetCompletionCoords(step)
end

function SubStepResolver:PlayerIsInDestZone(step)
    local playerZone = ns.TravelRegions and ns.TravelRegions:GetPlayerMapId()
    if not playerZone then
        return false
    end

    local startZone = step.mapId and ns.TravelRegions:ResolveZoneMapId(step.mapId)

    local function sameZone(mapId)
        if not mapId then
            return false
        end
        local zone = ns.TravelRegions:ResolveZoneMapId(mapId) or mapId
        -- Completion coords on the start map are the entrance, not the dest.
        if startZone and zone == startZone then
            return false
        end
        return zone == playerZone
    end

    if sameZone(step.completionMapId) then
        return true
    end
    if sameZone(step.portalDestMap) then
        return true
    end
    if sameZone(self:InferPortalDestMap(step)) then
        return true
    end
    local dest = ns.RouteTracker and ns.RouteTracker.route and ns.RouteTracker.route.destination
    if dest and sameZone(dest.mapId) then
        return true
    end
    if ns.RouteTracker and ns.RouteTracker.ShouldPreferDestAim and ns.RouteTracker:ShouldPreferDestAim() then
        return true
    end
    return false
end

function SubStepResolver:GetNavCoords(step)
    if not step then
        return nil
    end

    -- Once the player is in the destination / completion zone, never aim back
    -- at a start-zone portal entrance (projects as the border behind you).
    if self:PlayerIsInDestZone(step) then
        local destMap, destX, destY = self:GetDestAimCoords(step)
        if destMap and destX and destY then
            local playerZone = ns.TravelRegions and ns.TravelRegions:GetPlayerMapId()
            local destZone = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(destMap) or destMap
            if playerZone and destZone and playerZone == destZone and ns.MapCoords then
                local m, x, y = ns.MapCoords:OnPlayerMap(destMap, destX, destY)
                if m and x and y and not ns.MapCoords:IsRimCoord(x, y) then
                    return m, x, y
                end
            end
            return destMap, destX, destY
        end
    end

    if self:IsPortalStep(step) and not self:IsPlayerAtCompletion(step) then
        local portalMap, portalX, portalY = self:GetPortalEntranceCoords(step)
        if portalMap and portalX and portalY then
            local portalZone = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(portalMap) or portalMap
            local playerZone = ns.TravelRegions and ns.TravelRegions:GetPlayerMapId()

            -- Approaching on the zone map: use verified UI entrance, not world projection
            -- (C_Map can place the portal ~20% farther north than it actually is).
            if playerZone and playerZone == portalZone then
                if ns.MapCoords then
                    return ns.MapCoords:OnPlayerMap(portalMap, portalX, portalY)
                end
                return portalMap, portalX, portalY
            end

            if step.worldX and step.worldY and ns.MapCoords then
                local mapId, x, y = ns.MapCoords:WorldToPlayerMap(step.worldX, step.worldY)
                if mapId and x and y then
                    return mapId, x, y
                end
            end

            if ns.MapCoords then
                return ns.MapCoords:OnPlayerMap(portalMap, portalX, portalY)
            end
            return portalMap, portalX, portalY
        end
    end

    if step.worldX and step.worldY and ns.MapCoords and not self:IsPortalStep(step) then
        local mapId, x, y = ns.MapCoords:WorldToPlayerMap(step.worldX, step.worldY)
        if mapId and x and y then
            return mapId, x, y
        end
    end

    local startMap = step.mapId
    local startX = ns.Destination and ns.Destination:NormalizeUICoord(step.x)
    local startY = ns.Destination and ns.Destination:NormalizeUICoord(step.y)
    local compMap = step.completionMapId or step.mapId
    local compX = ns.Destination and ns.Destination:NormalizeUICoord(step.completionX or step.x)
    local compY = ns.Destination and ns.Destination:NormalizeUICoord(step.completionY or step.y)

    -- Portal / zone-change steps: guide to the entrance while still on the start side.
    if self:IsTransitStep(step) and not self:IsPlayerAtCompletion(step) then
        if startMap and startX and startY then
            local playerZone = ns.TravelRegions and ns.TravelRegions:GetPlayerMapId()
            local resolvedStart = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(startMap) or startMap
            if playerZone and playerZone == resolvedStart then
                return startMap, startX, startY
            end
        end
    end

    local playerInst = self:GetPlayerInstance()
    if compMap and compX and compY and playerInst then
        local _, _, compInst = HBD:GetWorldCoordinatesFromZone(compX, compY, compMap)
        if compInst and compInst ~= playerInst and startMap and startX and startY then
            local _, _, startInst = HBD:GetWorldCoordinatesFromZone(startX, startY, startMap)
            if startInst == playerInst then
                if ns.MapCoords then
                    return ns.MapCoords:OnPlayerMap(startMap, startX, startY)
                end
                return startMap, startX, startY
            end
        end
    end

    if compMap and compX and compY then
        if ns.MapCoords then
            return ns.MapCoords:OnPlayerMap(compMap, compX, compY)
        end
        return compMap, compX, compY
    end

    local mapId = step.mapId
    local x = ns.Destination and ns.Destination:NormalizeUICoord(step.x)
    local y = ns.Destination and ns.Destination:NormalizeUICoord(step.y)
    if mapId and x and y then
        if ns.MapCoords then
            return ns.MapCoords:OnPlayerMap(mapId, x, y)
        end
        return mapId, x, y
    end

    return nil
end

function SubStepResolver:IsTomTomReachable(step)
    if not step then
        return false
    end

    if step.actionOptions then
        for _, opt in ipairs(step.actionOptions) do
            if opt.type == "item" or opt.type == "spell" then
                if not self:IsCompletionReachable(step) then
                    return false
                end
                break
            end
        end
    end

    local mapId, x, y = self:GetNavCoords(step)
    if mapId and x and y and ns.MapCoords then
        return ns.MapCoords:IsNavTargetReachable(mapId, x, y)
    end

    return false
end

function SubStepResolver:EdgeToStep(edge, useStart)
    local loc
    if useStart then
        loc = edge.loc or edge.completionLoc
    else
        loc = edge.completionLoc or edge.loc
    end
    if not loc or not loc.mapId or not loc.pos then
        return nil
    end

    return {
        text = edge.loca or "Continue",
        mapId = loc.mapId,
        x = ns.Destination:NormalizeUICoord(loc.pos.x),
        y = ns.Destination:NormalizeUICoord(loc.pos.y),
        z = loc.pos.z or 0,
        completionMapId = loc.mapId,
        completionX = ns.Destination:NormalizeUICoord(loc.pos.x),
        completionY = ns.Destination:NormalizeUICoord(loc.pos.y),
        checkDistance = edge.checkDistance ~= false,
        actionOptions = edge.actionOptions,
        isSubStep = true,
        completed = false,
    }
end

function SubStepResolver:EdgeToReachableStep(edge)
    local sub = self:EdgeToStep(edge, false)
    if sub and self:IsTomTomReachable(sub) then
        return sub
    end
    sub = self:EdgeToStep(edge, true)
    if sub and self:IsTomTomReachable(sub) then
        return sub
    end
    return nil
end

function SubStepResolver:BuildPathSubSteps(route, mainStep)
    local subs = {}
    local playerInst = self:GetPlayerInstance()
    if not playerInst then
        return subs
    end

    local playerMap = C_Map.GetBestMapForUnit("player")
    local pos = playerMap and C_Map.GetPlayerMapPosition(playerMap, "player")

    local function tryAdd(edge)
        local sub = self:EdgeToReachableStep(edge)
        if not sub then
            return false
        end
        if playerMap and pos and sub.completionMapId == playerMap then
            local yards = HBD:GetZoneDistance(
                playerMap, pos.x, pos.y,
                sub.completionMapId, sub.completionX, sub.completionY
            )
            if yards and yards < 30 then
                return false
            end
        end
        subs[#subs + 1] = sub
        if ns.TravelActions then
            ns.TravelActions:EvaluateStep(sub)
        end
        return true
    end

    if #subs == 0 and route.optimizedPath then
        local startIdx = route.activeStepIndex or 1
        for i = startIdx, #route.optimizedPath do
            local edge = route.optimizedPath[i]
            local sub = self:EdgeToReachableStep(edge)
            if sub then
                local stepInst = self:GetStepInstance(sub)
                if stepInst == playerInst then
                    if not tryAdd(edge) then
                        break
                    end
                elseif #subs > 0 then
                    break
                else
                    break
                end
            end
        end
    end

    return subs
end

function SubStepResolver:CreateBearingSubStep(mainStep, route)
    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then
        return nil
    end

    -- Fake pins near a zone edge send the arrow back out after a crossing.
    if pos.x < 0.04 or pos.x > 0.96 or pos.y < 0.04 or pos.y > 0.96 then
        return nil
    end

    local destMap, destX, destY = self:GetNavCoords(mainStep)
    if destMap and destX and destY then
        local destZone = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(destMap) or destMap
        local playerZone = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(playerMap) or playerMap
        if destZone == playerZone then
            return nil
        end
        if ns.MapCoords then
            local m, x, y = ns.MapCoords:OnPlayerMap(destMap, destX, destY)
            if m == playerMap and x and y and not ns.MapCoords:IsRimCoord(x, y) then
                return nil
            end
        end
    end

    -- Geometric bearing only. TomTom's current arrow angle can already be
    -- pointing at a rim pin, which would keep a fake waypoint ping-ponging.
    local angle
    if destMap and destX and destY and ns.MapRoute and ns.MapRoute.GetPlanarBearingOnMap then
        angle = ns.MapRoute:GetPlanarBearingOnMap(playerMap, destMap, destX, destY)
    end
    if not angle then
        return nil
    end

    local dist = 0.22
    local subX = pos.x + math.sin(angle) * dist
    local subY = pos.y + math.cos(angle) * dist
    if subX < 0.04 or subX > 0.96 or subY < 0.04 or subY > 0.96 then
        return nil
    end

    local label = mainStep.text or "next leg"
    if #label > 42 then
        label = label:sub(1, 39) .. "..."
    end

    return {
        text = string.format("Head toward: %s", label),
        mapId = playerMap,
        x = subX,
        y = subY,
        z = 0,
        completionMapId = playerMap,
        completionX = subX,
        completionY = subY,
        checkDistance = true,
        isSubStep = true,
        completed = false,
    }
end

function SubStepResolver:GetIncompleteSubs(route, mainIndex)
    local subs = route.subSteps and route.subSteps[mainIndex]
    if not subs then
        return {}
    end

    local list = {}
    for _, sub in ipairs(subs) do
        if not sub.completed then
            list[#list + 1] = sub
        end
    end
    return list
end

function SubStepResolver:EnsureSubSteps(route)
    if not route then
        return
    end

    local idx = route.activeStepIndex or 1
    local mainStep = route.steps[idx]
    if not mainStep then
        return
    end

    route.subSteps = route.subSteps or {}

    if ns.TravelActions and ns.TravelActions:IsInstantUseStep(mainStep) then
        route.subSteps[idx] = nil
        return
    end

    if mainStep.checkDistance == false and not (mainStep.actionOptions and #mainStep.actionOptions > 0) then
        route.subSteps[idx] = nil
        return
    end

    if self:IsPortalStep(mainStep) then
        route.subSteps[idx] = nil
        return
    end

    if self:IsTomTomReachable(mainStep) then
        route.subSteps[idx] = nil
        return
    end

    local incomplete = self:GetIncompleteSubs(route, idx)
    if #incomplete > 0 and self:IsTomTomReachable(incomplete[1]) then
        route.subSteps[idx] = incomplete
        return
    end

    local subs = self:BuildPathSubSteps(route, mainStep)
    if #subs == 0 or not self:IsTomTomReachable(subs[1]) then
        local bearing = self:CreateBearingSubStep(mainStep, route)
        if bearing and self:IsTomTomReachable(bearing) then
            if ns.TravelActions then
                ns.TravelActions:EvaluateStep(bearing)
            end
            subs = { bearing }
        end
    end

    route.subSteps[idx] = subs
end

function SubStepResolver:GetNavigationStep(route)
    if not route then
        return nil
    end

    self:EnsureSubSteps(route)

    local idx = route.activeStepIndex or 1
    local mainStep = route.steps[idx]
    if not mainStep then
        return nil
    end

    if ns.TravelActions and ns.TravelActions:IsInstantUseStep(mainStep) then
        return nil
    end

    if mainStep and not mainStep.completed and self:IsPortalStep(mainStep) then
        return mainStep
    end

    if self:IsTomTomReachable(mainStep) then
        return mainStep
    end

    local incomplete = self:GetIncompleteSubs(route, idx)
    for _, sub in ipairs(incomplete) do
        if self:IsTomTomReachable(sub) then
            return sub
        end
    end

    if incomplete[1] then
        return incomplete[1]
    end

    if mainStep and not mainStep.completed then
        local mapId, x, y = self:GetNavCoords(mainStep)
        if mapId and x and y then
            return mainStep
        end
    end

    if route.destination and route.destination.mapId then
        local destStep = ns.Destination:ToNavStep(route.destination)
        if destStep and self:IsTomTomReachable(destStep) then
            return destStep
        end
    end

    return mainStep
end

function SubStepResolver:CompleteNavigationStep(route, step)
    if not route or not step or not step.isSubStep then
        return false
    end

    step.completed = true
    local idx = route.activeStepIndex or 1
    if route.subSteps and route.subSteps[idx] then
        local kept = {}
        for _, sub in ipairs(route.subSteps[idx]) do
            if not sub.completed then
                kept[#kept + 1] = sub
            end
        end
        route.subSteps[idx] = kept
    end

    self:EnsureSubSteps(route)
    return true
end

function SubStepResolver:GetSubStepsForDisplay(route, mainIndex)
    if not route or not route.subSteps then
        return {}
    end
    return route.subSteps[mainIndex] or {}
end

SubStepResolver.SUB_STEP_YARDS = SUB_STEP_YARDS
