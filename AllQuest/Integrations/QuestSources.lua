--[[
  AllQuest — quest details / pickup coords from public APIs.
  Queries Blizzard, then BtWQuests / All The Things / Zygor if those addons are loaded.
  Does not copy other addons' databases. Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.QuestSources = AQ.QuestSources or {}
local Sources = AQ.QuestSources

local function NormalizeXY(x, y)
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y then
        return nil
    end
    if x > 1 or y > 1 then
        x = x / 100
        y = y / 100
    end
    if x < 0 or y < 0 or x > 1 or y > 1 then
        return nil
    end
    return x, y
end

local function CoordsFromTable(obj)
    if type(obj) ~= "table" then
        return nil
    end
    if type(obj.coord) == "table" then
        local c = obj.coord
        local x, y = NormalizeXY(c[1] or c.x, c[2] or c.y)
        local mapID = c[3] or c.mapID or obj.mapID
        if x and type(mapID) == "number" then
            return mapID, x, y
        end
    end
    local coords = obj.coords
    if type(coords) ~= "table" then
        return nil
    end
    if coords[1] and type(coords[1]) == "table" and (coords[1][1] or coords[1].x) then
        local c = coords[1]
        local x, y = NormalizeXY(c[1] or c.x, c[2] or c.y)
        local mapID = c[3] or c.mapID or obj.mapID
        if x and type(mapID) == "number" then
            return mapID, x, y
        end
    end
    for mapID, list in pairs(coords) do
        if type(mapID) == "number" and type(list) == "table" then
            local c = list[1] or list
            if type(c) == "table" then
                local x, y = NormalizeXY(c[1] or c.x, c[2] or c.y)
                if x then
                    return mapID, x, y
                end
            end
        end
    end
    return nil
end

local function FromAllTheThings(questID)
    local att = AllTheThings
    if type(att) ~= "table" then
        return nil
    end
    local search = att.SearchForField
    if type(search) ~= "function" then
        return nil
    end
    local ok, results = pcall(search, att, "questID", questID)
    if not ok or type(results) ~= "table" then
        ok, results = pcall(search, "questID", questID)
    end
    if not ok or type(results) ~= "table" then
        return nil
    end
    for i = 1, #results do
        local mapID, x, y = CoordsFromTable(results[i])
        if mapID then
            return mapID, x, y, "allthethings"
        end
    end
    for _, obj in pairs(results) do
        local mapID, x, y = CoordsFromTable(obj)
        if mapID then
            return mapID, x, y, "allthethings"
        end
    end
    return nil
end

local function FromZygor(questID)
    local zgv = ZGV or ZygorGuidesViewer
    if type(zgv) ~= "table" then
        return nil
    end
    local byid = zgv.questsbyid
    if type(byid) == "table" then
        local q = byid[questID]
        if type(q) == "table" then
            local mapID = q.map or q.m or q.mapID
            local x, y = NormalizeXY(q.x, q.y)
            if type(mapID) == "number" and x then
                return mapID, x, y, "zygor"
            end
        end
    end
    return nil
end

local function PluginOn(id)
    return AQ.Plugins and AQ.Plugins.IsEnabled(id) and true or false
end

local function FromQuestCompletist(questID)
    if not PluginOn("QuestCompletist") then
        return nil
    end
    local pins = qcPinDB
    if type(pins) ~= "table" then
        return nil
    end
    local playerMap = AQ.Compat.GetPlayerMapPosition and select(1, AQ.Compat.GetPlayerMapPosition())
    local cat
    if type(qcAreaIDToCategoryID) == "table" and type(playerMap) == "number" then
        cat = qcAreaIDToCategoryID[playerMap]
    end
    local lists = {}
    if cat and type(pins[cat]) == "table" then
        lists[1] = pins[cat]
    end
    for li = 1, #lists do
        local list = lists[li]
        for i = 1, #list do
            local pin = list[i]
            if type(pin) == "table" and type(pin[7]) == "table" then
                for q = 1, #pin[7] do
                    if pin[7][q] == questID then
                        local x, y = NormalizeXY(pin[5], pin[6])
                        if x and type(playerMap) == "number" then
                            return playerMap, x, y, "questcompletist"
                        end
                    end
                end
            end
        end
    end
    return nil
end

function Sources.ResolveLocation(questID)
    if type(questID) ~= "number" then
        return nil
    end
    local mapID, x, y, src = AQ.Compat.GetQuestPickupLocation(questID)
    if type(mapID) == "number" then
        return mapID, x, y, src or "blizzard"
    end
    if PluginOn("BtWQuests") and AQ.BtWQuests and AQ.BtWQuests.ResolveLocation then
        mapID, x, y, src = AQ.BtWQuests.ResolveLocation(questID)
        if type(mapID) == "number" then
            return mapID, x, y, src
        end
    end
    if PluginOn("AllTheThings") then
        mapID, x, y, src = FromAllTheThings(questID)
        if type(mapID) == "number" then
            return mapID, x, y, src
        end
    end
    if PluginOn("ZygorGuidesViewer") then
        mapID, x, y, src = FromZygor(questID)
        if type(mapID) == "number" then
            return mapID, x, y, src
        end
    end
    if PluginOn("QuestCompletist") then
        mapID, x, y, src = FromQuestCompletist(questID)
        if type(mapID) == "number" then
            return mapID, x, y, src
        end
    end
    return nil
end

function Sources.SetWaypoint(questID, title)
    if type(questID) ~= "number" then
        return false
    end
    AQ.Compat.RequestQuestData(questID)
    AQ.Compat.SuperTrackQuest(questID)
    local mapID, x, y = Sources.ResolveLocation(questID)
    local placed = false
    if type(mapID) == "number" and x and y and AQ.TomTom and AQ.TomTom.AddPoint then
        placed = AQ.TomTom.AddPoint(mapID, x, y, title or "AllQuest") and true or false
    end
    if not placed and not (x and y) then
        if AQ.Compat.ShowQuestOnMap then
            AQ.Compat.ShowQuestOnMap(questID)
        elseif type(mapID) == "number" and OpenWorldMap then
            AQ:SafeCall(OpenWorldMap, mapID)
        end
    end
    return placed, mapID, x, y
end
