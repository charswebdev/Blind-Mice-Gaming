--[[
  AllQuest — campaign quests section (Retail C_CampaignInfo)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function GetRows()
    local rows = {}
    if not C_CampaignInfo then
        return rows
    end
    local byCampaign = {}
    local order = {}
    AQ.Compat.ForEachQuestLog(function(info)
        if info.isHeader or info.isHidden or not info.questID then
            return
        end
        local isCampaign = AQ:SafeCall(C_CampaignInfo.IsCampaignQuest, info.questID)
        if not isCampaign then
            return
        end
        if AQ.Tracker and AQ.Tracker.IsSuppressed and AQ.Tracker.IsSuppressed("quest", info.questID) then
            return
        end
        local campaignID = AQ:SafeCall(C_CampaignInfo.GetCampaignID, info.questID) or 0
        if not byCampaign[campaignID] then
            byCampaign[campaignID] = {}
            order[#order + 1] = campaignID
        end
        byCampaign[campaignID][#byCampaign[campaignID] + 1] = info
    end)
    for i = 1, #order do
        local campaignID = order[i]
        local name = "Campaign"
        local info = AQ:SafeCall(C_CampaignInfo.GetCampaignInfo, campaignID)
        if type(info) == "table" and type(info.name) == "string" then
            name = info.name
        end
        rows[#rows + 1] = {
            kind = "header",
            id = "campaign:" .. tostring(campaignID),
            title = name,
            speech = "Campaign " .. name,
            fontSize = 12,
            indent = 14,
            subheader = true,
        }
        local list = byCampaign[campaignID]
        for q = 1, #list do
            local quest = list[q]
            local status = quest.isComplete and "DONE" or "ACTIVE"
            local autoComplete = quest.isAutoComplete or AQ.Compat.IsQuestAutoComplete(quest.questID, quest.logIndex)
            local item = AQ.Compat.GetQuestTrackerItem and AQ.Compat.GetQuestTrackerItem(quest.questID, quest.logIndex, status == "DONE")
            rows[#rows + 1] = {
                kind = "quest",
                questID = quest.questID,
                title = quest.title,
                level = quest.level,
                status = status,
                indent = 8,
                autoComplete = autoComplete and true or false,
                isCampaign = true,
                itemLink = item and item.link,
                itemTexture = item and item.texture,
                itemCharges = item and item.charges,
                logIndex = quest.logIndex,
                speech = quest.title .. " " .. status,
                detail = autoComplete and status == "DONE" and "Left-click to complete this quest from the tracker." or nil,
            }
            if autoComplete and status == "DONE" and AQ.AutoQuest and AQ.AutoQuest.AddClickToComplete then
                AQ.AutoQuest.AddClickToComplete(rows, quest.questID, quest.logIndex, true)
            else
            local objectives = AQ.Compat.GetQuestObjectives(quest.questID, quest.logIndex)
            for o = 1, #objectives do
                local obj = objectives[o]
                rows[#rows + 1] = {
                    kind = "objective",
                    title = "  " .. obj.text,
                    finished = obj.finished,
                    numFulfilled = obj.numFulfilled,
                    numNeeded = obj.numNeeded,
                    questID = quest.questID,
                    indent = 16,
                    speech = obj.text,
                }
            end
            end
        end
    end
    return rows
end

AQ.Tracker.RegisterSection({
    id = "campaigns",
    title = "Campaigns",
    order = 15,
    flavor = "retail",
    GetRows = GetRows,
})
