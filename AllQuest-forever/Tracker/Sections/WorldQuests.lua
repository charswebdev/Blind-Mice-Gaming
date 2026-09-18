--[[
  AllQuest — world quest / bonus objective tracker section (Retail-gated)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function GetRows()
    local rows = {}
    if not (C_QuestLog and C_QuestLog.GetNumWorldQuestWatches) then
        return rows
    end
    local seen = {}
    local ids = AQ.Compat.GetWatchedWorldQuestIDs()
    if C_QuestLog and C_QuestLog.GetBountiesForMapID and C_Map and C_Map.GetBestMapForUnit then
        -- Bonus/world tasks also appear as isTask in the log.
    end
    AQ.Compat.ForEachQuestLog(function(info)
        if info.isHeader or info.isHidden then
            return
        end
        local isWQ = AQ.Compat.IsWorldQuest(info.questID)
        local isBonus = info.isTask and not isWQ
        if not isWQ and not isBonus then
            return
        end
        if isWQ then
            local watchedWQ = false
            for w = 1, #ids do
                if ids[w] == info.questID then
                    watchedWQ = true
                    break
                end
            end
            if not watchedWQ then
                return
            end
        end
        if AQ.Tracker and AQ.Tracker.IsSuppressed and AQ.Tracker.IsSuppressed("quest", info.questID) then
            return
        end
        local status = info.isComplete and "DONE" or "ACTIVE"
        local title = info.title
        if isWQ then
            title = "WQ " .. title
        else
            title = "Bonus " .. title
        end
        seen[info.questID] = true
        local autoComplete = info.isAutoComplete or AQ.Compat.IsQuestAutoComplete(info.questID, info.logIndex)
        local item = AQ.Compat.GetQuestTrackerItem and AQ.Compat.GetQuestTrackerItem(info.questID, info.logIndex, status == "DONE")
        rows[#rows + 1] = {
            kind = "quest",
            questID = info.questID,
            title = title,
            level = info.level,
            status = status,
            indent = 8,
            autoComplete = autoComplete and true or false,
            isWorldQuest = isWQ and true or false,
            itemLink = item and item.link,
            itemTexture = item and item.texture,
            itemCharges = item and item.charges,
            logIndex = info.logIndex,
            speech = title .. " " .. status,
            detail = autoComplete and status == "DONE" and "Left-click to complete this quest from the tracker." or nil,
        }
        if autoComplete and status == "DONE" and AQ.AutoQuest and AQ.AutoQuest.AddClickToComplete then
            AQ.AutoQuest.AddClickToComplete(rows, info.questID, info.logIndex, true)
        else
        local objectives = AQ.Compat.GetQuestObjectives(info.questID, info.logIndex)
        for o = 1, #objectives do
            local obj = objectives[o]
            rows[#rows + 1] = {
                kind = "objective",
                title = "  " .. obj.text,
                finished = obj.finished,
                numFulfilled = obj.numFulfilled,
                numNeeded = obj.numNeeded,
                objType = obj.type,
                questID = info.questID,
                indent = 16,
                speech = obj.text,
            }
        end
        end
    end)
    -- Watched world quests that may not be in the main log
    for i = 1, #ids do
        local id = ids[i]
        if seen[id] then
            -- already listed from the quest log
        elseif AQ.Tracker and AQ.Tracker.IsSuppressed and AQ.Tracker.IsSuppressed("quest", id) then
            -- hidden from tracker
        else
        seen[id] = true
        local title = AQ.Compat.GetQuestTitle(id) or ("World quest " .. tostring(id))
        if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
            local n = AQ:SafeCall(C_TaskQuest.GetQuestInfoByQuestID, id)
            if type(n) == "string" and n ~= "" then
                title = n
            end
        end
        local item = AQ.Compat.GetQuestTrackerItem and AQ.Compat.GetQuestTrackerItem(id, nil, false)
        rows[#rows + 1] = {
            kind = "quest",
            questID = id,
            title = "WQ " .. title,
            status = "ACTIVE",
            indent = 8,
            isWorldQuest = true,
            itemLink = item and item.link,
            itemTexture = item and item.texture,
            itemCharges = item and item.charges,
            logIndex = item and item.logIndex,
            speech = title .. " world quest ACTIVE",
        }
        end
    end
    return rows
end

AQ.Tracker.RegisterSection({
    id = "worldquests",
    title = "World Quests",
    order = 30,
    flavor = "retail",
    GetRows = GetRows,
})
