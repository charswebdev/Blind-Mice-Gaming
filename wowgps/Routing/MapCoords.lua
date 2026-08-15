local _, ns = ...

local HBD = LibStub("HereBeDragons-2.0")

local MapCoords = {}
ns.MapCoords = MapCoords

function MapCoords:Norm(value)
    return ns.Destination and ns.Destination:NormalizeUICoord(value)
end

function MapCoords:ResolveZone(mapId)
    if ns.TravelRegions then
        return ns.TravelRegions:ResolveZoneMapId(mapId) or mapId
    end
    return mapId
end

function MapCoords:ZoneToWorld(mapId, x, y)
    x = self:Norm(x)
    y = self:Norm(y)
    mapId = tonumber(mapId)
    if not mapId or not x or not y then
        return nil
    end

    if C_Map and C_Map.GetWorldPosFromMapPos then
        local _, worldPos = C_Map.GetWorldPosFromMapPos(mapId, CreateVector2D(x, y))
        if worldPos and worldPos.x and worldPos.y then
            return worldPos.x, worldPos.y
        end
    end

    if HBD and HBD.GetWorldCoordinatesFromZone then
        local wx, wy = HBD:GetWorldCoordinatesFromZone(x, y, mapId)
        if wx and wy then
            return wx, wy
        end
    end

    return nil
end

function MapCoords:ZoneToZone(fromMap, x, y, toMap)
    x = self:Norm(x)
    y = self:Norm(y)
    fromMap = tonumber(fromMap)
    toMap = tonumber(toMap)
    if not fromMap or not toMap or not x or not y then
        return nil
    end
    if fromMap == toMap then
        return x, y
    end

    local wx, wy = self:ZoneToWorld(fromMap, x, y)
    if wx and wy and C_Map and C_Map.GetMapPosFromWorldPos then
        local uiMapId, localPos = C_Map.GetMapPosFromWorldPos(0, CreateVector2D(wx, wy), toMap)
        if localPos then
            local tx = self:Norm(localPos.x)
            local ty = self:Norm(localPos.y)
            if tx and ty then
                return tx, ty
            end
        end
    end

    if HBD and HBD.TranslateZoneCoordinates then
        return HBD:TranslateZoneCoordinates(x, y, fromMap, toMap, true)
    end

    return nil
end

function MapCoords:WorldToMap(worldX, worldY, mapId)
    if not worldX or not worldY or not mapId or not C_Map or not C_Map.GetMapPosFromWorldPos then
        return nil
    end
    local _, localPos = C_Map.GetMapPosFromWorldPos(0, CreateVector2D(worldX, worldY), mapId)
    if not localPos then
        return nil
    end
    local x = self:Norm(localPos.x)
    local y = self:Norm(localPos.y)
    if not x or not y then
        return nil
    end
    return x, y
end

function MapCoords:GetZoneDistance(mapA, xA, yA, mapB, xB, yB)
    xA = self:Norm(xA)
    yA = self:Norm(yA)
    xB = self:Norm(xB)
    yB = self:Norm(yB)
    if not mapA or not mapB or not xA or not yA or not xB or not yB then
        return nil
    end

    local wxA, wyA = self:ZoneToWorld(mapA, xA, yA)
    local wxB, wyB = self:ZoneToWorld(mapB, xB, yB)
    if wxA and wyA and wxB and wyB then
        local dx = wxA - wxB
        local dy = wyA - wyB
        return math.sqrt(dx * dx + dy * dy)
    end

    if HBD and HBD.GetZoneDistance then
        return HBD:GetZoneDistance(mapA, xA, yA, mapB, xB, yB)
    end

    return nil
end

function MapCoords:WorldToPlayerMap(worldX, worldY)
    if not worldX or not worldY or not C_Map or not C_Map.GetMapPosFromWorldPos then
        return nil
    end

    local playerMap = self:GetPlayerMapId()
    if not playerMap then
        return nil
    end

    local function project(hintMap)
        local _, localPos = C_Map.GetMapPosFromWorldPos(0, CreateVector2D(worldX, worldY), hintMap)
        if localPos then
            local x = self:Norm(localPos.x)
            local y = self:Norm(localPos.y)
            if x and y and not self:IsRimCoord(x, y) then
                return hintMap, x, y
            end
        end
        return nil
    end

    local mapId, x, y = project(playerMap)
    if mapId then
        return mapId, x, y
    end

    local zoneMap = ns.TravelRegions and ns.TravelRegions:GetPlayerMapId()
    if zoneMap and zoneMap ~= playerMap then
        return project(zoneMap)
    end

    return nil
end

function MapCoords:GetPlayerMapId()
    return C_Map and C_Map.GetBestMapForUnit("player")
end

-- Projections of another zone onto this map often land on the border
-- (x/y near 0 or 1). Treating those as "on this map" aims the arrow backward.
function MapCoords:IsRimCoord(x, y)
    if not x or not y then
        return false
    end
    return x < 0.02 or x > 0.98 or y < 0.02 or y > 0.98
end

function MapCoords:OnPlayerMap(mapId, x, y)
    local playerMap = self:GetPlayerMapId()
    if not playerMap or not mapId or not x or not y then
        return mapId, x, y
    end
    if playerMap == mapId then
        return playerMap, x, y
    end
    local tx, ty = self:ZoneToZone(mapId, x, y, playerMap)
    if tx and ty and not self:IsRimCoord(tx, ty) then
        return playerMap, tx, ty
    end

    local wx, wy = self:ZoneToWorld(mapId, x, y)
    if wx and wy then
        local px, py = self:WorldToMap(wx, wy, playerMap)
        if px and py and not self:IsRimCoord(px, py) then
            return playerMap, px, py
        end
    end

    return mapId, x, y
end

function MapCoords:ToDisplayMap(mapId, x, y, displayMapId)
    displayMapId = displayMapId or self:GetPlayerMapId()
    if not displayMapId or not mapId or not x or not y then
        return mapId, x, y
    end
    if displayMapId == mapId then
        return displayMapId, x, y
    end
    local tx, ty = self:ZoneToZone(mapId, x, y, displayMapId)
    if tx and ty then
        return displayMapId, tx, ty
    end
    local wx, wy = self:ZoneToWorld(mapId, x, y)
    if wx and wy then
        local px, py = self:WorldToMap(wx, wy, displayMapId)
        if px and py then
            return displayMapId, px, py
        end
    end
    return mapId, x, y
end

function MapCoords:IsNavTargetReachable(mapId, x, y)
    local playerMap = self:GetPlayerMapId()
    if not playerMap or not mapId or not x or not y then
        return false
    end

    local navMap, navX, navY = self:OnPlayerMap(mapId, x, y)
    if not navMap or not navX or not navY then
        return false
    end

    if navMap == playerMap then
        if mapId ~= playerMap and self:IsRimCoord(navX, navY) then
            return false
        end
        return true
    end

    local wx, wy = self:ZoneToWorld(navMap, navX, navY)
    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then
        return false
    end
    local px, py = self:ZoneToWorld(playerMap, pos.x, pos.y)
    return wx ~= nil and px ~= nil
end
