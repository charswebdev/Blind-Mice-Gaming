local _, ns = ...

local HBD = LibStub("HereBeDragons-2.0")

local TravelRegions = {}
ns.TravelRegions = TravelRegions

-- Midnight expansion Quel'Thalas zones (canonical MapIDs).
TravelRegions.MIDNIGHT_MAPS = {
    [2537] = true, -- Quel'Thalas (continent)
    [2393] = true, -- Silvermoon City
    [2395] = true, -- Eversong Woods
    [2405] = true, -- Voidstorm
    [2413] = true, -- Harandar
    [2424] = true, -- Isle of Quel'Danas
    [2437] = true, -- Zul'Aman
    [2541] = true, -- Arcantina
}

-- Legacy BC-era Quel'Thalas MapIDs — must not be used when routing to Midnight destinations.
TravelRegions.LEGACY_QUELTHALAS_MAPS = {
    [94] = true,   -- Eversong Woods
    [95] = true,   -- Ghostlands
    [110] = true,  -- Silvermoon City
    [122] = true,  -- Isle of Quel'Danas
}

-- Instance / micro maps that belong to Midnight zones but are not zone MapIDs.
TravelRegions.MIDNIGHT_INSTANCE_MAPS = {
    [2771] = 2405, -- Voidstorm interior
    [2694] = 2413, -- Harandar interior
}

-- The Maw (Shadowlands) — no flying; cliff/void terrain needs corridor routing.
TravelRegions.MAW_MAPS = {
    [1543] = true, -- The Maw
    [1648] = true, -- The Maw (intro)
    [1960] = true, -- The Maw (quest variant)
}

TravelRegions.MAW_RELATED_MAPS = {
    [1961] = true, -- Korthia (reachable via Maw animaflow)
}

function TravelRegions:GetMapEra(mapId)
    mapId = tonumber(mapId)
    if not mapId then
        return nil
    end
    if self.MIDNIGHT_MAPS[mapId] then
        return "midnight"
    end
    if self.LEGACY_QUELTHALAS_MAPS[mapId] then
        return "legacy"
    end
    return nil
end

function TravelRegions:IsMidnightMap(mapId)
    mapId = tonumber(mapId)
    if not mapId then
        return false
    end
    if self.MIDNIGHT_MAPS[mapId] then
        return true
    end
    local resolved = self:ResolveZoneMapId(mapId)
    return resolved and self.MIDNIGHT_MAPS[resolved] == true
end

function TravelRegions:IsLegacyQuelThalasMap(mapId)
    mapId = tonumber(mapId)
    if not mapId then
        return false
    end
    if self.LEGACY_QUELTHALAS_MAPS[mapId] then
        return true
    end
    local resolved = self:ResolveZoneMapId(mapId)
    return resolved and self.LEGACY_QUELTHALAS_MAPS[resolved] == true
end

function TravelRegions:IsMawMap(mapId)
    mapId = tonumber(mapId)
    if not mapId then
        return false
    end
    if self.MAW_MAPS[mapId] then
        return true
    end

    -- Walk parents for Maw micros.
    local guard = 0
    local current = mapId
    while current and guard < 16 do
        guard = guard + 1
        if self.MAW_MAPS[current] then
            return true
        end
        if not C_Map or not C_Map.GetMapInfo then
            break
        end
        local info = C_Map.GetMapInfo(current)
        if not info or not info.parentMapID or info.parentMapID == 0 then
            break
        end
        current = info.parentMapID
    end
    return false
end

function TravelRegions:IsMawRelatedDest(mapId)
    mapId = tonumber(mapId)
    if not mapId then
        return false
    end
    return self:IsMawMap(mapId) or self.MAW_RELATED_MAPS[mapId] == true
end

function TravelRegions:GetCanonicalMawMapId(mapId)
    if self:IsMawMap(mapId) then
        return 1543
    end
    return tonumber(mapId)
end

-- Walk parent maps until we hit a known zone MapID.
function TravelRegions:ResolveZoneMapId(mapId)
    mapId = tonumber(mapId)
    if not mapId then
        return nil
    end

    local guard = 0
    local current = mapId
    while current and guard < 16 do
        guard = guard + 1
        if self.MIDNIGHT_MAPS[current] or self.LEGACY_QUELTHALAS_MAPS[current] then
            return current
        end
        if not C_Map or not C_Map.GetMapInfo then
            break
        end
        local info = C_Map.GetMapInfo(current)
        if not info or not info.parentMapID or info.parentMapID == 0 then
            break
        end
        current = info.parentMapID
    end

    return mapId
end

function TravelRegions:GetMapName(mapId)
    if not mapId then
        return nil
    end
    local info = C_Map.GetMapInfo(mapId)
    return info and info.name
end

function TravelRegions:GetPlayerMapId()
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then
        return nil
    end
    return self:ResolveZoneMapId(mapId) or mapId
end

function TravelRegions:GetRawPlayerMapId()
    return C_Map.GetBestMapForUnit("player")
end

-- Player position using resolved zone MapID + UI coordinates on that map.
function TravelRegions:GetPlayerMapCoords()
    local rawMap = C_Map.GetBestMapForUnit("player")
    if not rawMap then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(rawMap, "player")
    if not pos then
        return nil
    end

    local zoneMap = self:ResolveZoneMapId(rawMap) or rawMap
    local x, y = pos.x, pos.y

    if zoneMap ~= rawMap then
        local tx, ty = HBD:TranslateZoneCoordinates(x, y, rawMap, zoneMap, true)
        if tx and ty then
            x, y = tx, ty
        end
    end

    return {
        mapId = zoneMap,
        rawMapId = rawMap,
        x = x,
        y = y,
        era = self:GetMapEra(zoneMap),
    }
end

function TravelRegions:IsSameTravelRegion(mapIdA, mapIdB)
    mapIdA = self:ResolveZoneMapId(mapIdA) or tonumber(mapIdA)
    mapIdB = self:ResolveZoneMapId(mapIdB) or tonumber(mapIdB)
    if not mapIdA or not mapIdB then
        return false
    end
    if mapIdA == mapIdB then
        return true
    end

    local eraA = self:GetMapEra(mapIdA)
    local eraB = self:GetMapEra(mapIdB)

    -- Midnight and legacy Quel'Thalas share geography but not the same travel graph.
    if eraA == "midnight" and eraB == "midnight" then
        return true
    end
    if eraA == "legacy" and eraB == "legacy" then
        return true
    end

    return false
end

function TravelRegions:GetEdgeMapId(edge)
    if not edge then
        return nil
    end
    local loc = edge.completionLoc or edge.loc
    if not loc then
        return nil
    end
    return loc.mapId
end

function TravelRegions:RouteUsesLegacyMapsForMidnightDest(optimizedPath, destMapId)
    if not self:IsMidnightMap(destMapId) then
        return false
    end

    for _, edge in ipairs(optimizedPath or {}) do
        for _, loc in ipairs({ edge.loc, edge.completionLoc }) do
            if loc and loc.mapId then
                local resolved = self:ResolveZoneMapId(loc.mapId) or loc.mapId
                if self:IsLegacyQuelThalasMap(resolved) then
                    return true
                end
            end
        end
    end

    return false
end

function TravelRegions:RouteLeavesRegionForMidnightDest(optimizedPath, playerMapId, destMapId)
    if not self:IsMidnightMap(destMapId) then
        return false
    end
    if not self:IsSameTravelRegion(playerMapId, destMapId) then
        return false
    end

    local first = optimizedPath and optimizedPath[1]
    if not first then
        return false
    end

    if self:IsItemOrSpellEdge(first) then
        local targetMap = self:GetEdgeMapId(first)
        if targetMap and not self:IsSameTravelRegion(playerMapId, targetMap) then
            return true
        end
    end

    return false
end

function TravelRegions:IsItemOrSpellEdge(edge)
    if not edge or not edge.actionOptions then
        return false
    end
    for _, opt in ipairs(edge.actionOptions) do
        if opt.type == "item" or opt.type == "spell" then
            return true
        end
    end
    return false
end

function TravelRegions:IsMidnightRouteMap(mapId)
    mapId = tonumber(mapId)
    if not mapId then
        return false
    end
    if self:IsMidnightMap(mapId) then
        return true
    end
    if self.MIDNIGHT_INSTANCE_MAPS[mapId] then
        return true
    end
    return false
end

function TravelRegions:RouteLeavesMidnightWhenLocal(optimizedPath, playerMapId, destMapId)
    if not self:IsMidnightMap(destMapId) then
        return false
    end
    if not playerMapId or not self:IsSameTravelRegion(playerMapId, destMapId) then
        return false
    end

    for _, edge in ipairs(optimizedPath or {}) do
        for _, loc in ipairs({ edge.loc, edge.completionLoc }) do
            if loc and loc.mapId and not self:IsMidnightRouteMap(loc.mapId) then
                return true
            end
        end
    end

    return false
end

function TravelRegions:IsDirectTravelEdge(edge)
    if not edge then
        return false
    end
    local text = (edge.loca or edge.text or ""):lower()
    return text:find("reach the destination", 1, true) ~= nil
end

function TravelRegions:StepCrossesMidnightZones(step)
    if not step then
        return false
    end
    local startMap = self:ResolveZoneMapId(step.mapId or step.loc and step.loc.mapId) or step.mapId
    local compMap = self:ResolveZoneMapId(step.completionMapId or step.completionLoc and step.completionLoc.mapId)
        or step.completionMapId or step.mapId
    if not startMap or not compMap or startMap == compMap then
        return false
    end
    return self:IsMidnightMap(startMap) and self:IsMidnightMap(compMap)
end

function TravelRegions:RouteHasInvalidDirectTravel(optimizedPath, playerMapId, destMapId)
    if not playerMapId or not destMapId or not self:IsMidnightMap(destMapId) then
        return false
    end
    if not self:IsSameTravelRegion(playerMapId, destMapId) then
        return false
    end

    for _, edge in ipairs(optimizedPath or {}) do
        if self:IsDirectTravelEdge(edge) and self:StepCrossesMidnightZones({
            mapId = edge.loc and edge.loc.mapId,
            completionMapId = edge.completionLoc and edge.completionLoc.mapId,
            loca = edge.loca,
        }) then
            return true
        end
    end
    return false
end

function TravelRegions:IsValidRouteForDestination(optimizedPath, destMapId, playerMapId)
    if not optimizedPath or #optimizedPath == 0 then
        return false
    end
    if self:RouteUsesLegacyMapsForMidnightDest(optimizedPath, destMapId) then
        return false
    end
    if playerMapId and self:RouteLeavesRegionForMidnightDest(optimizedPath, playerMapId, destMapId) then
        return false
    end
    if playerMapId and self:RouteLeavesMidnightWhenLocal(optimizedPath, playerMapId, destMapId) then
        return false
    end
    if playerMapId and self:RouteHasInvalidDirectTravel(optimizedPath, playerMapId, destMapId) then
        return false
    end
    return true
end
