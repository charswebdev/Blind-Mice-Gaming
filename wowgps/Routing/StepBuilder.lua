local _, ns = ...

local StepBuilder = {}
ns.StepBuilder = StepBuilder

function StepBuilder:ReadLocCoords(loc)
    if not loc or not loc.mapId or not loc.pos then
        return nil
    end
    local x = ns.Destination:NormalizeUICoord(loc.pos.x)
    local y = ns.Destination:NormalizeUICoord(loc.pos.y)
    if not x or not y then
        return nil
    end
    return loc.mapId, x, y, loc.pos.z or 0
end

function StepBuilder:EnsureCoordDestination(steps, dest)
    if not dest or not dest.mapId then
        return steps
    end
    if dest.type ~= ns.Constants.DEST_TYPES.COORD and dest.type ~= ns.Constants.DEST_TYPES.CUSTOM then
        return steps
    end

    local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
    if not destMap then
        return steps
    end

    if #steps == 0 then
        steps[1] = {
            index = 1,
            text = string.format("Travel to %s", dest.name),
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
        return steps
    end

    local last = steps[#steps]
    if last then
        local mapId = last.completionMapId or last.mapId
        local x = ns.Destination:NormalizeUICoord(last.completionX or last.x)
        local y = ns.Destination:NormalizeUICoord(last.completionY or last.y)
        if not mapId or not x or not y then
            last.mapId = destMap
            last.x = destX
            last.y = destY
            last.completionMapId = destMap
            last.completionX = destX
            last.completionY = destY
        end
    end

    last = steps[#steps]
    if last then
        local mapId = last.completionMapId or last.mapId
        local x = last.completionX or last.x
        local y = last.completionY or last.y
        if mapId == destMap
            and math.abs((x or 0) - destX) <= 0.02
            and math.abs((y or 0) - destY) <= 0.02 then
            return steps
        end
    end

    steps[#steps + 1] = {
        index = #steps + 1,
        text = string.format("Arrive at %s", dest.name),
        mapId = destMap,
        x = destX,
        y = destY,
        z = dest.z or 0,
        completionMapId = destMap,
        completionX = destX,
        completionY = destY,
        checkDistance = false,
        completed = false,
    }

    return steps
end

function StepBuilder:IsCrossZoneDirectTravel(edge)
    if not edge or not ns.TravelRegions then
        return false
    end
    if not ns.TravelRegions:IsDirectTravelEdge(edge) then
        return false
    end
    return ns.TravelRegions:StepCrossesMidnightZones({
        mapId = edge.loc and edge.loc.mapId,
        completionMapId = edge.completionLoc and edge.completionLoc.mapId,
        loca = edge.loca,
    })
end

-- Skip legacy direct-travel stubs when they would send the player the wrong way.
function StepBuilder:ShouldSkipEdge(edge)
    if self:IsCrossZoneDirectTravel(edge) then
        return true
    end
    if not edge or not ns.TravelRegions or not ns.TravelRegions.IsDirectTravelEdge(edge) then
        return false
    end
    if not ns.TravelRegions:IsDirectTravelEdge(edge) then
        return false
    end
    for _, loc in ipairs({ edge.loc, edge.completionLoc }) do
        if loc and loc.mapId and ns.TravelRegions:IsMidnightMap(loc.mapId) then
            return true
        end
    end
    return false
end

function StepBuilder:IsDuplicatePortalStep(prevStep, step)
    if not prevStep or not step or not ns.SubStepResolver then
        return false
    end
    if not ns.SubStepResolver:IsPortalStep(prevStep) or not ns.SubStepResolver:IsPortalStep(step) then
        return false
    end

    local prevDest = prevStep.portalDestMap or ns.SubStepResolver:InferPortalDestMap(prevStep)
    local dest = step.portalDestMap or ns.SubStepResolver:InferPortalDestMap(step)
    if prevDest and dest and prevDest == dest then
        return true
    end

    local prevText = (prevStep.text or ""):lower()
    local text = (step.text or ""):lower()
    if prevText ~= "" and prevText == text then
        return true
    end

    return false
end

function StepBuilder:PolishStepText(text, edge, dest)
    if not text or text == "" then
        return text
    end
    if text:lower():find("reach the destination", 1, true) then
        local compMap = edge and edge.completionLoc and edge.completionLoc.mapId
        local locMap = edge and edge.loc and edge.loc.mapId
        if compMap and locMap and compMap == locMap then
            return "Continue on foot"
        end
        if dest and dest.name then
            return string.format("Travel toward %s", dest.name)
        end
        return "Continue on foot"
    end
    return text
end

function StepBuilder:FromRoute(routeResult)
    local steps = {}
    local optimized = routeResult.optimizedPath
    local dest = routeResult.destination

    for i, edge in ipairs(optimized) do
        if not self:ShouldSkipEdge(edge) then
            local loc = edge.loc or edge.completionLoc
            local comp = edge.completionLoc or edge.loc
            local mapId, x, y, z = self:ReadLocCoords(loc)
            local compMap, compX, compY = self:ReadLocCoords(comp)
        local step = {
            index = #steps + 1,
            text = self:PolishStepText(edge.loca or ("Step " .. i), edge, dest),
            mapId = mapId,
            x = x,
            y = y,
            z = z or 0,
            completionMapId = compMap,
            completionX = compX,
            completionY = compY,
            checkDistance = edge.checkDistance,
            actionOptions = edge.actionOptions,
            item = edge.item,
            spell = edge.spell,
            toy = edge.toy,
            initfunc = edge.initfunc,
            actionTitle = edge.actionTitle,
            housingTeleport = edge.housingTeleport,
            housingReturn = edge.housingReturn,
            instantUse = edge.checkDistance == false and edge.actionOptions and #edge.actionOptions > 0,
            completed = false,
            isPortalStep = edge.isPortalStep,
            portalDestMap = edge.portalDestMap,
            worldX = edge.worldX,
            worldY = edge.worldY,
        }
            if ns.SubStepResolver then
                if not step.isPortalStep and ns.SubStepResolver:IsPortalStep(step) then
                    step.isPortalStep = true
                end
                if step.isPortalStep and not step.portalDestMap then
                    step.portalDestMap = ns.SubStepResolver:InferPortalDestMap(step)
                end
                if step.isPortalStep then
                    step.checkDistance = false
                end
            end
            if ns.TravelActions then
                if ns.TravelActions.MarkHousingFromStep then
                    ns.TravelActions:MarkHousingFromStep(step)
                end
                ns.TravelActions:EvaluateStep(step)
            end
            local lastStep = steps[#steps]
            if not lastStep or not self:IsDuplicatePortalStep(lastStep, step) then
                steps[#steps + 1] = step
            end
        end
    end
    if dest and (dest.type == ns.Constants.DEST_TYPES.COORD or dest.type == ns.Constants.DEST_TYPES.CUSTOM) then
        -- Maw corridors already place safe pins; do not append a straight final chord.
        if not routeResult.mawLocal and not routeResult.fallback then
            steps = self:EnsureCoordDestination(steps, dest)
        end
    elseif dest and not routeResult.fallback and not routeResult.mawLocal then
        local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
        if destMap then
            local last = steps[#steps]
            if not last or last.mapId ~= destMap
                or math.abs((last.x or 0) - destX) > 0.01
                or math.abs((last.y or 0) - destY) > 0.01 then
                steps[#steps + 1] = {
                    index = #steps + 1,
                    text = string.format("Arrive at %s", dest.name),
                    mapId = destMap,
                    x = destX,
                    y = destY,
                    z = dest.z or 0,
                    completionMapId = destMap,
                    completionX = destX,
                    completionY = destY,
                    checkDistance = false,
                    completed = false,
                }
            end
        end
    end

    return steps
end
