--[[
  AllQuest — quest tracker section (all clients)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local lastProgressKey = ""

local function IsDaily(info)
    local freq = info.frequency
    if freq == 2 then
        return true
    end
    local QF = Enum and Enum.QuestFrequency
    return QF and freq == QF.Daily
end

local function IsWeekly(info)
    local freq = info.frequency
    if freq == 3 then
        return true
    end
    local QF = Enum and Enum.QuestFrequency
    return QF and freq == QF.Weekly
end

local function TagText(info)
    local parts = {}
    if IsDaily(info) then
        parts[#parts + 1] = "D"
    elseif IsWeekly(info) then
        parts[#parts + 1] = "W"
    end
    local tag = AQ.Compat.GetQuestTagInfo(info.questID)
    if type(tag) == "table" then
        local id = tag.tagID or tag.worldQuestType
        local QT = Enum and Enum.QuestTag
        if QT then
            if id == QT.Dungeon then
                parts[#parts + 1] = "dungeon"
            elseif id == QT.Raid or id == QT.Raid10 or id == QT.Raid25 then
                parts[#parts + 1] = "raid"
            elseif id == QT.Group then
                parts[#parts + 1] = "group"
            elseif id == QT.PvP or id == QT.Pvp then
                parts[#parts + 1] = "pvp"
            elseif id == QT.Heroic then
                parts[#parts + 1] = "heroic"
            elseif id == QT.Legendary then
                parts[#parts + 1] = "legendary"
            end
        end
    end
    if info.suggestedGroup and info.suggestedGroup > 0 then
        parts[#parts + 1] = tostring(info.suggestedGroup) .. "p"
    end
    return table.concat(parts, " ")
end

local function Filters()
    return AQ.DB.Get().filters or {}
end

local function GetRows()
    local watched = {}
    local watchList = AQ.Compat.GetWatchedQuestIDs()
    for i = 1, #watchList do
        watched[watchList[i]] = true
    end
    local hasWatch = #watchList > 0
    local byZone = {}
    local zoneOrder = {}
    local progressBits = {}

    AQ.Compat.ForEachQuestLog(function(info)
        if info.isHeader or info.isHidden then
            return
        end
        if info.isTask or info.isBounty then
            return
        end
        if AQ.Compat.IsWorldQuest(info.questID) then
            return
        end
        if C_CampaignInfo and C_CampaignInfo.IsCampaignQuest then
            if AQ:SafeCall(C_CampaignInfo.IsCampaignQuest, info.questID) then
                return
            end
        end
        if hasWatch and not watched[info.questID] then
            return
        end
        if AQ.Tracker and AQ.Tracker.IsSuppressed and AQ.Tracker.IsSuppressed("quest", info.questID) then
            return
        end
        local f = Filters()
        if f.hideComplete and info.isComplete then
            return
        end
        if f.hideDaily and IsDaily(info) then
            return
        end
        if f.hideWeekly and IsWeekly(info) then
            return
        end
        local zone = info.headerTitle
        if type(zone) ~= "string" or zone == "" then
            zone = "Quests"
        end
        if not byZone[zone] then
            byZone[zone] = {}
            zoneOrder[#zoneOrder + 1] = zone
        end
        byZone[zone][#byZone[zone] + 1] = info
    end)

    local rows = {}
    local closestLink, closestDist
    local mapID, px, py = AQ.Compat.GetPlayerMapPosition()

    for z = 1, #zoneOrder do
        local zone = zoneOrder[z]
        rows[#rows + 1] = {
            kind = "header",
            id = "zone:" .. zone,
            title = zone,
            speech = "Zone " .. zone,
            fontSize = 12,
            indent = 4,
        }
        local list = byZone[zone]
        for i = 1, #list do
            local info = list[i]
            local status = "ACTIVE"
            if info.failed then
                status = "FAILED"
            elseif info.isComplete then
                status = "DONE"
            end
            local objectives = AQ.Compat.GetQuestObjectives(info.questID, info.logIndex)
            local detailParts = {}
            local speechParts = { info.title, status }
            local item = AQ.Compat.GetQuestTrackerItem and AQ.Compat.GetQuestTrackerItem(info.questID, info.logIndex, status == "DONE")
            local itemLink = item and item.link
            local autoComplete = info.isAutoComplete or AQ.Compat.IsQuestAutoComplete(info.questID, info.logIndex)
            rows[#rows + 1] = {
                kind = "quest",
                questID = info.questID,
                title = info.title,
                level = info.level,
                tags = TagText(info),
                status = status,
                itemLink = itemLink,
                itemTexture = item and item.texture,
                itemCharges = item and item.charges,
                logIndex = info.logIndex,
                indent = 8,
                autoComplete = autoComplete and true or false,
                speech = table.concat(speechParts, ". "),
                detail = autoComplete and status == "DONE" and "Left-click to complete this quest from the tracker." or ("Quest ID " .. tostring(info.questID)),
            }
            local showDone = AQ.DB.Get().trackerShowCompletedObjectives ~= false
            if autoComplete and status == "DONE" and AQ.AutoQuest and AQ.AutoQuest.AddClickToComplete then
                AQ.AutoQuest.AddClickToComplete(rows, info.questID, info.logIndex, true)
            else
            for o = 1, #objectives do
                local obj = objectives[o]
                if showDone or not obj.finished then
                    local ot = obj.finished and (obj.text .. " (complete)") or obj.text
                    rows[#rows + 1] = {
                        kind = "objective",
                        title = "  " .. ot,
                        finished = obj.finished,
                        numFulfilled = obj.numFulfilled,
                        numNeeded = obj.numNeeded,
                        indent = 16,
                        speech = ot,
                        questID = info.questID,
                    }
                    detailParts[#detailParts + 1] = ot
                    progressBits[#progressBits + 1] = ot
                end
            end
            end
            if itemLink and px and py and info.isOnMap then
                closestLink = closestLink or itemLink
            elseif itemLink and not closestLink then
                closestLink = itemLink
            end
        end
    end

    local key = table.concat(progressBits, "|")
    if key ~= lastProgressKey then
        if lastProgressKey ~= "" and AQ.DB.Get().speechOnQuestProgress then
            AQ.Speech.Say("Quest progress updated")
        end
        lastProgressKey = key
    end

    if AQ.Items then
        AQ.Items.SetExtraItem(closestLink)
    end
    return rows
end

AQ.Tracker.RegisterSection({
    id = "quests",
    title = "Quests",
    order = 20,
    flavor = "all",
    GetRows = GetRows,
})
