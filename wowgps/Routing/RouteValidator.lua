local _, ns = ...

local RouteValidator = {}
ns.RouteValidator = RouteValidator

function RouteValidator:GetStepMapId(step)
    if not step then
        return nil
    end
    return step.completionMapId or step.mapId
end

function RouteValidator:RouteUsesLegacyMaps(route, dest)
    if not route or not dest or not ns.TravelRegions then
        return false
    end
    if not ns.TravelRegions:IsMidnightMap(dest.mapId) then
        return false
    end

    if ns.TravelRegions:RouteUsesLegacyMapsForMidnightDest(route.optimizedPath, dest.mapId) then
        return true
    end

    for _, step in ipairs(route.steps or {}) do
        local mapId = self:GetStepMapId(step)
        if mapId and ns.TravelRegions:IsLegacyQuelThalasMap(mapId) then
            return true
        end
    end

    return false
end

function RouteValidator:FirstStepLeavesCurrentRegion(route, playerMap)
    if not playerMap or not route or not ns.TravelRegions then
        return false
    end

    local dest = route.destination
    if not dest or not ns.TravelRegions:IsSameTravelRegion(playerMap, dest.mapId) then
        return false
    end

    if ns.TravelRegions:RouteLeavesMidnightWhenLocal(route.optimizedPath, playerMap, dest.mapId) then
        return true
    end

    return ns.TravelRegions:RouteLeavesRegionForMidnightDest(route.optimizedPath, playerMap, dest.mapId)
        or self:FirstBuiltStepLeavesRegion(route, playerMap, dest.mapId)
end

function RouteValidator:FirstBuiltStepLeavesRegion(route, playerMap, destMapId)
    local first = route.steps and route.steps[1]
    if not first or not ns.TravelRegions:IsMidnightMap(destMapId) then
        return false
    end

    if not (first.actionOptions and #first.actionOptions > 0) then
        return false
    end

    local targetMap = self:GetStepMapId(first)
    if targetMap and not ns.TravelRegions:IsSameTravelRegion(playerMap, targetMap) then
        return true
    end

    return false
end

function RouteValidator:Analyze(route)
    local warnings = {}
    if not route or not route.destination then
        return warnings
    end

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS", true)
    if not L then
        return warnings
    end

    local playerMap = ns.TravelRegions:GetPlayerMapId()
    local dest = route.destination

    if self:RouteUsesLegacyMaps(route, dest) then
        warnings[#warnings + 1] = L["ROUTE_WARN_LEGACY_MAPID"]
    end

    if self:FirstStepLeavesCurrentRegion(route, playerMap) then
        local here = ns.TravelRegions:GetMapName(playerMap) or "your zone"
        warnings[#warnings + 1] = string.format(L["ROUTE_WARN_UNNECESSARY_TELEPORT"], here)
    end

    return warnings
end

function RouteValidator:FormatWarnings(warnings)
    if not warnings or #warnings == 0 then
        return nil
    end
    return table.concat(warnings, " ")
end
