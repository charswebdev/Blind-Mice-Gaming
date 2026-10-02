local _, GPS = ...

GPS.Travel = GPS.Travel or {}
local Travel = GPS.Travel

local KALIMDOR = {
    [1411] = true, [1412] = true, [1413] = true, [1439] = true, [1440] = true,
    [1441] = true, [1442] = true, [1443] = true, [1444] = true, [1445] = true,
    [1446] = true, [1447] = true, [1448] = true, [1449] = true, [1450] = true,
    [1451] = true, [1452] = true, [1454] = true, [1456] = true,
}

local TELDRASSIL = {
    [1438] = true, [1457] = true,
}

local EASTERN = {
    [1416] = true, [1417] = true, [1418] = true, [1419] = true, [1420] = true,
    [1421] = true, [1422] = true, [1423] = true, [1424] = true, [1425] = true,
    [1426] = true, [1427] = true, [1428] = true, [1429] = true, [1430] = true,
    [1431] = true, [1432] = true, [1433] = true, [1434] = true, [1435] = true,
    [1436] = true, [1437] = true, [1453] = true, [1455] = true, [1458] = true,
}

local SOUTH_EK = {
    [1418] = true, [1419] = true, [1427] = true, [1428] = true, [1434] = true, [1435] = true,
}

-- Docks on this client's vanilla maps. Each link is one ride.
local LINKS = {
    { kind = "zeppelin", faction = "Horde", a = { name = "Orgrimmar", mapId = 1411, x = 0.509, y = 0.139 }, b = { name = "Undercity", mapId = 1420, x = 0.607, y = 0.588 } },
    { kind = "zeppelin", faction = "Horde", a = { name = "Orgrimmar", mapId = 1411, x = 0.506, y = 0.126 }, b = { name = "Grom'gol", mapId = 1434, x = 0.314, y = 0.302 } },
    { kind = "zeppelin", faction = "Horde", a = { name = "Undercity", mapId = 1420, x = 0.619, y = 0.591 }, b = { name = "Grom'gol", mapId = 1434, x = 0.316, y = 0.291 } },
    { kind = "boat", faction = "Neutral", a = { name = "Ratchet", mapId = 1413, x = 0.637, y = 0.384 }, b = { name = "Booty Bay", mapId = 1434, x = 0.259, y = 0.730 } },
    { kind = "boat", faction = "Alliance", a = { name = "Menethil Harbor", mapId = 1437, x = 0.046, y = 0.572 }, b = { name = "Auberdine", mapId = 1439, x = 0.324, y = 0.438 } },
    { kind = "boat", faction = "Alliance", a = { name = "Menethil Harbor", mapId = 1437, x = 0.051, y = 0.634 }, b = { name = "Theramore", mapId = 1445, x = 0.715, y = 0.563 } },
    { kind = "boat", faction = "Alliance", a = { name = "Menethil Harbor", mapId = 1437, x = 0.046, y = 0.572 }, b = { name = "Southshore", mapId = 1424, x = 0.506, y = 0.697 } },
    { kind = "boat", faction = "Alliance", a = { name = "Auberdine", mapId = 1439, x = 0.324, y = 0.438 }, b = { name = "Southshore", mapId = 1424, x = 0.506, y = 0.697 } },
    { kind = "boat", faction = "Alliance", a = { name = "Rut'theran Village", mapId = 1438, x = 0.549, y = 0.968 }, b = { name = "Auberdine", mapId = 1439, x = 0.332, y = 0.401 } },
    { kind = "boat", faction = "Alliance", a = { name = "Auberdine", mapId = 1439, x = 0.307, y = 0.410 }, b = { name = "Stormwind Harbor", mapId = 1453, x = 0.225, y = 0.562 } },
    { kind = "tram", a = { name = "Stormwind", mapId = 1453, x = 0.690, y = 0.307 }, b = { name = "Ironforge", mapId = 1455, x = 0.767, y = 0.511 } },
    { kind = "boat", faction = "Neutral", a = { name = "Tanaris", mapId = 1446, x = 0.681, y = 0.225 }, b = { name = "Riverglades", mapId = 2548, x = 0.802, y = 0.541 } },
}

local RIDE = {
    zeppelin = "Zeppelin to ",
    boat = "Boat to ",
    tram = "Tram to ",
}

function Travel:Continent(mapId)
    if TELDRASSIL[mapId] then
        return "teldrassil"
    end
    if KALIMDOR[mapId] then
        return "kalimdor"
    end
    if EASTERN[mapId] then
        return "eastern"
    end
    return "other"
end

function Travel:Faction()
    if type(UnitFactionGroup) ~= "function" then
        return nil
    end
    local ok, faction = pcall(UnitFactionGroup, "player")
    if not ok then
        return nil
    end
    return GPS:PlainString(faction)
end

function Travel:MapName(mapId)
    if not mapId or not C_Map or not C_Map.GetMapInfo then
        return nil
    end
    local ok, info = pcall(C_Map.GetMapInfo, mapId)
    if not ok or type(info) ~= "table" then
        return nil
    end
    return GPS:PlainString(info.name)
end

function Travel:NearestFlight(mapId, x, y)
    if not mapId or not GPS.World or not GPS.World.List then
        return nil
    end
    local ok, list = pcall(function()
        return GPS.World:List()
    end)
    if not ok or type(list) ~= "table" then
        return nil
    end
    local best, bestDist
    for i = 1, #list do
        local row = list[i]
        if row.kind == "flight" and row.mapId == mapId and row.x and row.y then
            local dist = 0
            if x and y then
                local dx = row.x - x
                local dy = row.y - y
                dist = dx * dx + dy * dy
            end
            if not best or dist < bestDist then
                best = row
                bestDist = dist
            end
        end
    end
    if not best then
        return nil
    end
    return {
        name = best.name,
        mapId = best.mapId,
        x = best.x,
        y = best.y,
        zone = best.zone,
        kind = "flight",
        detail = "Take a flight",
    }
end

function Travel:Orient(link, hereMap, destMap)
    local a, b = link.a, link.b
    local hereCont = self:Continent(hereMap)
    local destCont = self:Continent(destMap)
    if self:Continent(a.mapId) == hereCont and self:Continent(b.mapId) == destCont and hereCont ~= destCont then
        return a, b
    end
    if self:Continent(b.mapId) == hereCont and self:Continent(a.mapId) == destCont and hereCont ~= destCont then
        return b, a
    end
    if a.mapId == hereMap then
        return a, b
    end
    if b.mapId == hereMap then
        return b, a
    end
    if b.mapId == destMap then
        return a, b
    end
    if a.mapId == destMap then
        return b, a
    end
    return nil, nil
end

function Travel:Allowed(link, faction)
    if not link.faction or link.faction == "Neutral" or not faction then
        return true
    end
    return link.faction == faction
end

function Travel:Score(link, hereMap, destMap, faction)
    if not self:Allowed(link, faction) then
        return nil
    end
    local depart, arrive = self:Orient(link, hereMap, destMap)
    if not depart or not arrive then
        return nil
    end
    if self:Continent(depart.mapId) ~= self:Continent(hereMap) then
        return nil
    end
    if self:Continent(arrive.mapId) ~= self:Continent(destMap) then
        return nil
    end
    local score = 0
    if depart.mapId == hereMap then
        score = score - 50
    end
    if arrive.mapId == destMap then
        score = score - 40
    end
    if link.faction and faction and link.faction == faction then
        score = score - 25
    end
    if SOUTH_EK[destMap] and arrive.mapId == 1434 then
        score = score - 30
    end
    if not SOUTH_EK[destMap] and (arrive.mapId == 1420 or arrive.mapId == 1437 or arrive.mapId == 1453) then
        score = score - 20
    end
    return score, depart, arrive
end

function Travel:NeedsRide(hereMap, destMap)
    if not hereMap or not destMap or hereMap == destMap then
        return false
    end
    if (hereMap == 1453 and destMap == 1455) or (hereMap == 1455 and destMap == 1453) then
        return true
    end
    return self:Continent(hereMap) ~= self:Continent(destMap)
end

function Travel:PickLink(hereMap, destMap, faction)
    local best, bestScore, bestDepart, bestArrive
    for i = 1, #LINKS do
        local score, depart, arrive = self:Score(LINKS[i], hereMap, destMap, faction)
        if score and (not bestScore or score < bestScore) then
            best = LINKS[i]
            bestScore = score
            bestDepart = depart
            bestArrive = arrive
        end
    end
    return best, bestDepart, bestArrive
end

function Travel:DestinationStep(dest)
    local coords = ""
    if dest.x and dest.y then
        coords = string.format("%.1f, %.1f", dest.x * 100, dest.y * 100)
    end
    local zone = dest.zone or self:MapName(dest.mapId) or ""
    local detail = zone
    if zone ~= "" and coords ~= "" then
        detail = zone .. "  " .. coords
    elseif coords ~= "" then
        detail = coords
    end
    return {
        name = dest.name,
        mapId = dest.mapId,
        x = dest.x,
        y = dest.y,
        zone = zone,
        kind = dest.kind or "place",
        detail = detail,
    }
end

function Travel:Plan(dest, here)
    local steps = {}
    if not dest or not dest.mapId then
        return steps
    end
    local hereMap = here and here.mapId
    if hereMap and hereMap ~= dest.mapId then
        local faction = self:Faction()
        if self:NeedsRide(hereMap, dest.mapId) then
            local link, depart, arrive = self:PickLink(hereMap, dest.mapId, faction)
            if link and depart and arrive then
                if hereMap ~= depart.mapId then
                    local flight = self:NearestFlight(hereMap, here.x, here.y)
                    if flight then
                        steps[#steps + 1] = flight
                    end
                end
                local ride = RIDE[link.kind] or "Ride to "
                local zone = self:MapName(depart.mapId) or depart.name
                steps[#steps + 1] = {
                    name = ride .. arrive.name,
                    mapId = depart.mapId,
                    x = depart.x,
                    y = depart.y,
                    zone = zone,
                    kind = link.kind,
                    detail = zone,
                }
                if arrive.mapId ~= dest.mapId then
                    local flight = self:NearestFlight(arrive.mapId, arrive.x, arrive.y)
                    if flight then
                        steps[#steps + 1] = flight
                    end
                end
            end
        else
            local flight = self:NearestFlight(hereMap, here.x, here.y)
            if flight then
                steps[#steps + 1] = flight
            end
        end
    end
    steps[#steps + 1] = self:DestinationStep(dest)
    return steps
end
