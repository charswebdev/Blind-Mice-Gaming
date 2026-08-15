--[[
  AllQuest — QuestCompletist incomplete quests for the current map
  Reads QuestCompletist globals at runtime. Does not copy its database files.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local MAX_ROWS = 12
local cacheCat
local cacheRows
local cacheAt = 0

local function PluginOn()
    return AQ.Plugins and AQ.Plugins.IsEnabled("QuestCompletist") and AQ:AddonLoaded("QuestCompletist")
end

local function CategoryForMap(mapID)
    local map = qcAreaIDToCategoryID
    if type(map) ~= "table" or type(mapID) ~= "number" then
        return nil
    end
    return map[mapID]
end

local function FactionOk(flag)
    if type(flag) ~= "number" or flag == 0 or flag == 3 then
        return true
    end
    local fac = AQ.Compat.UnitFaction()
    if flag == 1 then
        return fac == "Alliance"
    end
    if flag == 2 then
        return fac == "Horde"
    end
    return true
end

local function IsDone(questID)
    if AQ.Compat.IsQuestFlaggedCompleted(questID) then
        return true
    end
    local done = qcCompletedQuests
    if type(done) == "table" and type(done[questID]) == "table" then
        local c = done[questID]["C"]
        if c == 1 or c == 2 then
            return true
        end
    end
    return false
end

local function PinForQuest(questID, categoryId)
    local pins = qcPinDB
    if type(pins) ~= "table" or type(questID) ~= "number" then
        return nil
    end
    local lists = {}
    if categoryId and type(pins[categoryId]) == "table" then
        lists[1] = pins[categoryId]
    end
    if #lists == 0 then
        return nil
    end
    for li = 1, #lists do
        local list = lists[li]
        for i = 1, #list do
            local pin = list[i]
            if type(pin) == "table" then
                local qids = pin[7]
                if type(qids) == "table" then
                    for q = 1, #qids do
                        if qids[q] == questID then
                            return pin
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function GetRows()
    local rows = {}
    if not PluginOn() then
        return rows
    end
    local db = qcQuestDatabase
    if type(db) ~= "table" then
        return rows
    end
    local mapID = AQ.Compat.GetPlayerMapPosition and select(1, AQ.Compat.GetPlayerMapPosition())
    local cat = CategoryForMap(mapID)
    if not cat then
        return rows
    end
    local now = GetTime and GetTime() or 0
    if cacheCat == cat and cacheRows and (now - cacheAt) < 2 then
        return cacheRows
    end
    local pending = {}
    for _, e in pairs(db) do
        if type(e) == "table" and e[5] == cat then
            local qid = e[1]
            local name = e[2]
            if type(qid) == "number" and type(name) == "string" and name ~= ""
                and FactionOk(e[7]) and not IsDone(qid) then
                pending[#pending + 1] = {
                    id = qid,
                    name = name,
                    level = tonumber(e[3]) or 0,
                }
            end
        end
    end
    table.sort(pending, function(a, b)
        if a.level ~= b.level then
            return a.level < b.level
        end
        return a.name < b.name
    end)
    for i = 1, math.min(#pending, MAX_ROWS) do
        local e = pending[i]
        local pin = PinForQuest(e.id, cat)
        local x, y
        if pin then
            x = pin[5]
            y = pin[6]
        end
        local st = "READY"
        if AQ.Compat.IsQuestActive(e.id) then
            st = "ACTIVE"
        end
        rows[#rows + 1] = {
            kind = "quest",
            title = e.name,
            status = st,
            indent = 8,
            questID = e.id,
            rareMapID = mapID,
            rareX = x,
            rareY = y,
            speech = e.name .. " " .. st,
        }
    end
    cacheCat = cat
    cacheRows = rows
    cacheAt = now
    return rows
end

AQ.Tracker.RegisterSection({
    id = "questcompletist",
    title = "QuestCompletist",
    order = 62,
    flavor = "all",
    requiresPlugin = "QuestCompletist",
    requiresAddon = "QuestCompletist",
    GetRows = GetRows,
})

AQ:RegisterPlugin({
    id = "QuestCompletist",
    kind = "integration",
    label = "QuestCompletist",
    optionalAddon = "QuestCompletist",
    onEnable = function()
        cacheCat = nil
        AQ:Print("QuestCompletist: incomplete quests for this zone appear in the AllQuest tracker.")
        if AQ.Tracker and AQ.Tracker.Refresh then
            AQ.Tracker.Refresh()
        end
    end,
})
