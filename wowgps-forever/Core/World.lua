local _, GPS = ...

GPS.World = GPS.World or {}
local World = GPS.World

local CITY_MAPS = {
    [1453] = true,
    [1454] = true,
    [1455] = true,
    [1456] = true,
    [1457] = true,
    [1458] = true,
}

local function FlagTrue(value)
    if value == nil then
        return false
    end
    if issecretvalue and issecretvalue(value) then
        return false
    end
    return value == true
end

local function VectorXY(pos)
    if pos == nil or (issecretvalue and issecretvalue(pos)) then
        return nil, nil
    end
    local kind = type(pos)
    if kind ~= "table" and kind ~= "userdata" then
        return nil, nil
    end
    local rawX, rawY
    if type(pos.GetXY) == "function" then
        local ok, a, b = pcall(pos.GetXY, pos)
        if ok then
            rawX, rawY = a, b
        end
    end
    local x = GPS:PlainNumber(rawX)
    local y = GPS:PlainNumber(rawY)
    if x and y then
        return x, y
    end
    return GPS:PlainNumber(pos.x), GPS:PlainNumber(pos.y)
end

local function MapName(mapId)
    if not C_Map or not C_Map.GetMapInfo then
        return nil
    end
    local ok, info = pcall(C_Map.GetMapInfo, mapId)
    if not ok or type(info) ~= "table" then
        return nil
    end
    return GPS:PlainString(info.name)
end

local function Add(list, seen, dest)
    local name = GPS:PlainString(dest.name)
    local mapId = GPS:PlainNumber(dest.mapId)
    local x = GPS:PlainNumber(dest.x)
    local y = GPS:PlainNumber(dest.y)
    if not name or not mapId or not x or not y then
        return
    end
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return
    end
    local key = (dest.kind or "place") .. ":" .. mapId .. ":" .. name .. ":" .. string.format("%.3f", x) .. ":" .. string.format("%.3f", y)
    if seen[key] then
        return
    end
    seen[key] = true
    list[#list + 1] = {
        id = key,
        name = name,
        mapId = mapId,
        x = x,
        y = y,
        zone = GPS:PlainString(dest.zone) or name,
        kind = dest.kind or "zone",
    }
end

function World:AddFlights(list, seen, mapId, zoneName)
    if not C_TaxiMap or type(C_TaxiMap.GetTaxiNodesForMap) ~= "function" then
        return
    end
    local ok, nodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapId)
    if not ok or type(nodes) ~= "table" then
        return
    end
    for i = 1, #nodes do
        local node = nodes[i]
        if type(node) == "table" and not FlagTrue(node.isMapLayerTransition) then
            local x, y = VectorXY(node.position)
            Add(list, seen, {
                name = GPS:PlainString(node.name),
                mapId = mapId,
                x = x,
                y = y,
                zone = zoneName,
                kind = "flight",
            })
        end
    end
end

function World:AddKnownEntrances(list, seen)
    local rows = GPS.Entrances or {}
    for i = 1, #rows do
        local row = rows[i]
        local mapId = GPS:PlainNumber(row.mapId)
        local zoneName = MapName(mapId)
        if zoneName then
            Add(list, seen, {
                name = row.name,
                mapId = mapId,
                x = row.x,
                y = row.y,
                zone = zoneName,
                kind = row.kind or "dungeon",
            })
        end
    end
end

function World:AddEntrances(list, seen, mapId, zoneName)
    local journal = C_EncounterJournal
    if not journal or type(journal.GetDungeonEntrancesForMap) ~= "function" then
        return
    end
    local ok, entrances = pcall(journal.GetDungeonEntrancesForMap, mapId)
    if not ok or type(entrances) ~= "table" then
        return
    end
    for i = 1, #entrances do
        local entrance = entrances[i]
        if type(entrance) == "table" then
            local x, y = VectorXY(entrance.position)
            local name = GPS:PlainString(entrance.name)
            if not name and entrance.journalInstanceID and type(journal.GetInstanceInfo) == "function" then
                local infoOk, instanceName = pcall(journal.GetInstanceInfo, entrance.journalInstanceID)
                if infoOk then
                    name = GPS:PlainString(instanceName)
                end
            end
            Add(list, seen, {
                name = name,
                mapId = mapId,
                x = x,
                y = y,
                zone = zoneName,
                kind = "dungeon",
            })
        end
    end
end

function World:List()
    if self.cache and #self.cache > 0 then
        return self.cache
    end
    local list = {}
    local seen = {}
    local maps = GPS.ZoneMaps or {}
    for i = 1, #maps do
        local mapId = maps[i]
        local name = MapName(mapId)
        if name then
            Add(list, seen, {
                name = name,
                mapId = mapId,
                x = 0.5,
                y = 0.5,
                zone = name,
                kind = CITY_MAPS[mapId] and "city" or "zone",
            })
            self:AddFlights(list, seen, mapId, name)
            self:AddEntrances(list, seen, mapId, name)
        end
    end
    self:AddKnownEntrances(list, seen)
    table.sort(list, function(a, b)
        if a.name == b.name then
            return (a.kind or "") < (b.kind or "")
        end
        return a.name < b.name
    end)
    if #list > 0 then
        self.cache = list
    end
    return list
end
