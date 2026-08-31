--[[
  AllQuest — client / quest API compatibility
  Lua 5.1 only. Nil-guard every Retail-only API.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Compat = AQ.Compat or {}
local Compat = AQ.Compat

local function Safe(fn, ...)
    return AQ:SafeCall(fn, ...)
end

function Compat.GetInterfaceVersion()
    return select(4, GetBuildInfo()) or 0
end

function Compat.GetFlavor()
    local pid = WOW_PROJECT_ID
    if pid == WOW_PROJECT_MAINLINE then
        return "retail"
    end
    if pid == WOW_PROJECT_CLASSIC then
        return "era"
    end
    if pid == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        return "tbc"
    end
    if pid == WOW_PROJECT_WRATH_CLASSIC then
        return "wrath"
    end
    if pid == WOW_PROJECT_CATACLYSM_CLASSIC then
        return "cata"
    end
    if WOW_PROJECT_MISTS_CLASSIC and pid == WOW_PROJECT_MISTS_CLASSIC then
        return "mop"
    end
    local iface = Compat.GetInterfaceVersion()
    if iface >= 120000 then
        return "retail"
    end
    if iface >= 50000 then
        return "mop"
    end
    if iface >= 40000 then
        return "cata"
    end
    if iface >= 30000 then
        return "wrath"
    end
    if iface >= 20000 then
        return "tbc"
    end
    return "era"
end

function Compat.IsRetail()
    return Compat.GetFlavor() == "retail"
end

--- Expansions whose data plugins should load on this client.
function Compat.AllowedExpansionIDs()
    local flavor = Compat.GetFlavor()
    if flavor == "retail" then
        -- Classic Era IDs do not match Retail Chromie / starter-zone quests.
        return { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
    end
    if flavor == "mop" then
        return { 0, 1, 2, 3, 4 }
    end
    if flavor == "cata" then
        return { 0, 1, 2, 3 }
    end
    if flavor == "wrath" then
        return { 0, 1, 2 }
    end
    if flavor == "tbc" then
        return { 0, 1 }
    end
    return { 0 }
end

function Compat.ExpansionAllowed(id)
    local allowed = Compat.AllowedExpansionIDs()
    for i = 1, #allowed do
        if allowed[i] == id then
            return true
        end
    end
    return false
end

function Compat.IsSecretValue(v)
    if v == nil or not issecretvalue then
        return false
    end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret and true or false
end

function Compat.CanUseNumber(v)
    if type(v) ~= "number" then
        return false
    end
    if not Compat.IsSecretValue(v) then
        return true
    end
    if canaccessvalue then
        local ok, access = pcall(canaccessvalue, v)
        return ok and access and true or false
    end
    return false
end

function Compat.GetNumAddOns()
    if C_AddOns and C_AddOns.GetNumAddOns then
        return Safe(C_AddOns.GetNumAddOns) or 0
    end
    return Safe(GetNumAddOns) or 0
end

function Compat.GetAddOnInfo(index)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        return Safe(C_AddOns.GetAddOnInfo, index)
    end
    return Safe(GetAddOnInfo, index)
end

function Compat.GetAddOnMetadata(name, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return Safe(C_AddOns.GetAddOnMetadata, name, field)
    end
    return Safe(GetAddOnMetadata, name, field)
end

function Compat.LoadAddOn(name)
    if C_AddOns and C_AddOns.LoadAddOn then
        return Safe(C_AddOns.LoadAddOn, name)
    end
    return Safe(LoadAddOn, name)
end

function Compat.IsAddOnLoaded(name)
    return AQ:AddonLoaded(name)
end

function Compat.DoesAddOnExist(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    if C_AddOns and C_AddOns.DoesAddOnExist then
        local ok, exists = pcall(C_AddOns.DoesAddOnExist, name)
        if ok then
            return exists and true or false
        end
    end
    local addonName, _, _, _, reason = Compat.GetAddOnInfo(name)
    if type(addonName) == "string" and addonName ~= "" and reason ~= "MISSING" then
        return true
    end
    local n = Compat.GetNumAddOns()
    for i = 1, n do
        local id = Compat.GetAddOnInfo(i)
        if id == name then
            return true
        end
    end
    return false
end

function Compat.IsAddOnEnabled(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local player = UnitName and UnitName("player") or nil
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        local ok, state = pcall(C_AddOns.GetAddOnEnableState, name, player)
        if not ok then
            ok, state = pcall(C_AddOns.GetAddOnEnableState, name)
        end
        if ok and type(state) == "number" then
            return state ~= 0
        end
    end
    if GetAddOnEnableState then
        local ok, state = pcall(GetAddOnEnableState, player, name)
        if ok and type(state) == "number" then
            return state ~= 0
        end
    end
    return true
end

function Compat.GetNumQuestLogEntries()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        return Safe(C_QuestLog.GetNumQuestLogEntries) or 0
    end
    return Safe(GetNumQuestLogEntries) or 0
end

local function HeaderTitleFromInfo(info)
    if type(info) ~= "table" then
        return ""
    end
    return info.title or info.Title or ""
end

--- Iterate visible quest log. callback(info)
-- info: questID, title, level, isHeader, isCollapsed, isComplete, isHidden,
--       headerTitle, suggestedGroup, frequency, isOnMap, isTask, isBounty, isStory, logIndex
function Compat.ForEachQuestLog(callback)
    if type(callback) ~= "function" then
        return
    end
    local n = Compat.GetNumQuestLogEntries()
    local headerTitle = ""
    if C_QuestLog and C_QuestLog.GetInfo then
        for i = 1, n do
            local info = Safe(C_QuestLog.GetInfo, i)
            if type(info) == "table" then
                if info.isHeader then
                    headerTitle = HeaderTitleFromInfo(info)
                    callback({
                        logIndex = i,
                        questID = 0,
                        title = headerTitle,
                        level = 0,
                        isHeader = true,
                        isCollapsed = info.isCollapsed and true or false,
                        isComplete = false,
                        isHidden = info.isHidden and true or false,
                        headerTitle = headerTitle,
                    })
                else
                    local questID = info.questID or 0
                    if Compat.CanUseNumber(questID) then
                        callback({
                            logIndex = i,
                            questID = questID,
                            title = info.title or "",
                            level = info.level or 0,
                            isHeader = false,
                            isCollapsed = false,
                            isComplete = (C_QuestLog.IsComplete and Safe(C_QuestLog.IsComplete, questID)) and true or false,
                            isHidden = info.isHidden and true or false,
                            headerTitle = headerTitle,
                            suggestedGroup = info.suggestedGroup or 0,
                            frequency = info.frequency,
                            isOnMap = info.isOnMap and true or false,
                            isTask = info.isTask and true or false,
                            isBounty = info.isBounty and true or false,
                            isStory = info.isStory and true or false,
                            isCampaign = info.campaignID and info.campaignID ~= 0,
                            isAutoComplete = info.isAutoComplete and true or false,
                        })
                    end
                end
            end
        end
        return
    end
    for i = 1, n do
        local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID, _, _, isOnMap, _, isTask, isBounty, isStory = Safe(GetQuestLogTitle, i)
        if isHeader then
            headerTitle = title or ""
            callback({
                logIndex = i,
                questID = 0,
                title = headerTitle,
                level = 0,
                isHeader = true,
                isCollapsed = isCollapsed and true or false,
                isComplete = false,
                isHidden = false,
                headerTitle = headerTitle,
            })
        else
            questID = questID or 0
            if Compat.CanUseNumber(questID) then
                callback({
                    logIndex = i,
                    questID = questID,
                    title = title or "",
                    level = level or 0,
                    isHeader = false,
                    isCollapsed = false,
                    isComplete = isComplete == 1,
                    failed = isComplete == -1,
                    isHidden = false,
                    headerTitle = headerTitle,
                    suggestedGroup = suggestedGroup or 0,
                    frequency = frequency,
                    isOnMap = isOnMap and true or false,
                    isTask = isTask and true or false,
                    isBounty = isBounty and true or false,
                    isStory = isStory and true or false,
                    isAutoComplete = GetQuestLogIsAutoComplete and Safe(GetQuestLogIsAutoComplete, i) and true or false,
                })
            end
        end
    end
end

local questTitleCache = {}

local function StoreQuestTitle(questID, title)
    if type(title) == "string" and title ~= "" then
        questTitleCache[questID] = title
        return title
    end
    return nil
end

function Compat.GetQuestTitle(questID)
    if not Compat.CanUseNumber(questID) then
        return nil
    end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local t = StoreQuestTitle(questID, Safe(C_QuestLog.GetTitleForQuestID, questID))
        if t then
            return t
        end
    end
    if QuestUtils_GetQuestName then
        local t = StoreQuestTitle(questID, Safe(QuestUtils_GetQuestName, questID))
        if t then
            return t
        end
    end
    if C_TaskQuest and C_TaskQuest.GetQuestInfoByQuestID then
        local t = StoreQuestTitle(questID, Safe(C_TaskQuest.GetQuestInfoByQuestID, questID))
        if t then
            return t
        end
    end
    if C_QuestLog and C_QuestLog.GetQuestInfo then
        local t = StoreQuestTitle(questID, Safe(C_QuestLog.GetQuestInfo, questID))
        if t then
            return t
        end
    end
    return questTitleCache[questID]
end

function Compat.IsQuestComplete(questID)
    if not Compat.CanUseNumber(questID) then
        return false
    end
    if C_QuestLog and C_QuestLog.IsComplete then
        return Safe(C_QuestLog.IsComplete, questID) and true or false
    end
    return false
end

function Compat.IsQuestFlaggedCompleted(questID)
    if not Compat.CanUseNumber(questID) then
        return false
    end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        return Safe(C_QuestLog.IsQuestFlaggedCompleted, questID) and true or false
    end
    if IsQuestFlaggedCompleted then
        return Safe(IsQuestFlaggedCompleted, questID) and true or false
    end
    return false
end

function Compat.IsQuestFlaggedCompletedOnAccount(questID)
    if not Compat.CanUseNumber(questID) then
        return false
    end
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount then
        return Safe(C_QuestLog.IsQuestFlaggedCompletedOnAccount, questID) and true or false
    end
    return Compat.IsQuestFlaggedCompleted(questID)
end

function Compat.IsQuestActive(questID)
    if not Compat.CanUseNumber(questID) then
        return false
    end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local idx = Safe(C_QuestLog.GetLogIndexForQuestID, questID)
        return type(idx) == "number" and idx > 0
    end
    if GetQuestLogIndexByID then
        local idx = Safe(GetQuestLogIndexByID, questID)
        return type(idx) == "number" and idx > 0
    end
    local found = false
    Compat.ForEachQuestLog(function(info)
        if not found and not info.isHeader and info.questID == questID then
            found = true
        end
    end)
    return found
end

function Compat.GetLogIndexForQuestID(questID)
    if not Compat.CanUseNumber(questID) then
        return nil
    end
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then
        local idx = Safe(C_QuestLog.GetLogIndexForQuestID, questID)
        if type(idx) == "number" and idx > 0 then
            return idx
        end
        return nil
    end
    if GetQuestLogIndexByID then
        local idx = Safe(GetQuestLogIndexByID, questID)
        if type(idx) == "number" and idx > 0 then
            return idx
        end
    end
    return nil
end

function Compat.IsQuestAutoComplete(questID, logIndex)
    local idx = logIndex or Compat.GetLogIndexForQuestID(questID)
    if idx and C_QuestLog and C_QuestLog.GetInfo then
        local info = Safe(C_QuestLog.GetInfo, idx)
        if type(info) == "table" and info.isAutoComplete then
            return true
        end
    end
    if idx and GetQuestLogIsAutoComplete then
        return Safe(GetQuestLogIsAutoComplete, idx) and true or false
    end
    return false
end

function Compat.CompleteQuestFromTracker(questID)
    if not Compat.CanUseNumber(questID) then
        return false
    end
    if RemoveAutoQuestPopUp then
        Safe(RemoveAutoQuestPopUp, questID)
    end
    if not ShowQuestComplete then
        return false
    end
    local idx = Compat.GetLogIndexForQuestID(questID)
    if Compat.IsRetail() then
        local ok = pcall(ShowQuestComplete, questID)
        return ok and true or false
    end
    if idx then
        local ok = pcall(ShowQuestComplete, idx)
        if ok then
            return true
        end
    end
    local ok = pcall(ShowQuestComplete, questID)
    return ok and true or false
end

function Compat.ShowQuestOffer(questID)
    if not Compat.CanUseNumber(questID) then
        return false
    end
    if RemoveAutoQuestPopUp then
        Safe(RemoveAutoQuestPopUp, questID)
    end
    if not ShowQuestOffer then
        return false
    end
    local idx = Compat.GetLogIndexForQuestID(questID)
    if Compat.IsRetail() then
        local ok = pcall(ShowQuestOffer, questID)
        return ok and true or false
    end
    if idx then
        local ok = pcall(ShowQuestOffer, idx)
        if ok then
            return true
        end
    end
    local ok = pcall(ShowQuestOffer, questID)
    return ok and true or false
end

function Compat.GetAutoQuestPopUps()
    local out = {}
    if not GetNumAutoQuestPopUps or not GetAutoQuestPopUp then
        return out
    end
    local n = Safe(GetNumAutoQuestPopUps) or 0
    for i = 1, n do
        local questID, popType = Safe(GetAutoQuestPopUp, i)
        if Compat.CanUseNumber(questID) then
            local offer = popType == "OFFER" or popType == "offer" or popType == 0
            if LE_AUTOCOMPLETEQUESTPOPUPTYPE_OFFER and popType == LE_AUTOCOMPLETEQUESTPOPUPTYPE_OFFER then
                offer = true
            end
            out[#out + 1] = {
                questID = questID,
                popupType = offer and "OFFER" or "COMPLETE",
            }
        end
    end
    return out
end

function Compat.GetQuestObjectives(questID, logIndex)
    local out = {}
    if Compat.CanUseNumber(questID) and C_QuestLog and C_QuestLog.GetQuestObjectives then
        local objectives = Safe(C_QuestLog.GetQuestObjectives, questID)
        if type(objectives) == "table" then
            for i = 1, #objectives do
                local o = objectives[i]
                if type(o) == "table" and type(o.text) == "string" and o.text ~= "" then
                    local fulfilled = o.numFulfilled
                    local needed = o.numNeeded
                    if type(fulfilled) ~= "number" or type(needed) ~= "number" then
                        local a, b = string.match(o.text, "(%d+)%s*/%s*(%d+)")
                        fulfilled = fulfilled or tonumber(a)
                        needed = needed or tonumber(b)
                    end
                    out[#out + 1] = {
                        text = o.text,
                        finished = o.finished and true or false,
                        type = o.type,
                        numFulfilled = fulfilled,
                        numNeeded = needed,
                    }
                end
            end
            return out
        end
    end
    local idx = logIndex or Compat.GetLogIndexForQuestID(questID)
    if not idx then
        return out
    end
    local n = Safe(GetNumQuestLeaderBoards, idx) or 0
    for i = 1, n do
        local text, otype, finished = Safe(GetQuestLogLeaderBoard, i, idx)
        if type(text) == "string" and text ~= "" and otype ~= "spell" then
            local a, b = string.match(text, "(%d+)%s*/%s*(%d+)")
            out[#out + 1] = {
                text = text,
                finished = finished and true or false,
                type = otype,
                numFulfilled = tonumber(a),
                numNeeded = tonumber(b),
            }
        end
    end
    return out
end

function Compat.GetQuestTagInfo(questID)
    if not Compat.CanUseNumber(questID) then
        return nil
    end
    if C_QuestLog and C_QuestLog.GetQuestTagInfo then
        return Safe(C_QuestLog.GetQuestTagInfo, questID)
    end
    if GetQuestTagInfo then
        local tagID = Safe(GetQuestTagInfo, questID)
        if tagID then
            return { tagID = tagID }
        end
    end
    return nil
end

function Compat.GetQuestIconSpec(data)
    if type(data) ~= "table" then
        return nil
    end
    if data.achievementID then
        return { file = "Interface\\AchievementFrame\\UI-Achievement-TinyShield" }
    end
    if data.recipeID then
        return { atlas = "Mobile-Professions", file = "Interface\\Minimap\\Tracking\\Profession" }
    end
    if data.activityID then
        return { file = "Interface\\Icons\\INV_Misc_Note_01" }
    end
    if data.collectibleID then
        return { file = "Interface\\Icons\\INV_Misc_Bag_10" }
    end
    if data.pet then
        return { file = "Interface\\Minimap\\Tracking\\StableMaster" }
    end
    if data.areaPoiID or data.eventMapID then
        return { atlas = data.atlas or "VignetteEvent", file = "Interface\\Minimap\\POIIcons" }
    end
    if data.findKind == "treasure" then
        return { atlas = data.atlas or "VignetteLoot", file = "Interface\\Minimap\\ObjectIcons" }
    end
    if data.findKind == "rare" or data.rareTarget or data.rareMapID then
        return { atlas = data.atlas or "VignetteKill", file = "Interface\\Minimap\\ObjectIcons" }
    end
    if data.popupType == "OFFER" then
        return { file = "Interface\\GossipFrame\\AvailableQuestIcon" }
    end
    if data.status == "FAILED" then
        return { file = "Interface\\RaidFrame\\ReadyCheck-NotReady" }
    end
    if data.status == "DONE" or data.popupType == "COMPLETE" then
        return { atlas = "questlog-questtypeicon-completed", file = "Interface\\GossipFrame\\ActiveQuestIcon" }
    end
    if data.isWorldQuest then
        if QuestUtil and QuestUtil.GetWorldQuestAtlasInfo and data.questID then
            local ok, atlas = pcall(QuestUtil.GetWorldQuestAtlasInfo, data.questID)
            if ok and type(atlas) == "string" then
                return { atlas = atlas, file = "Interface\\GossipFrame\\AvailableQuestIcon" }
            end
            if ok and type(atlas) == "table" and type(atlas.atlas) == "string" then
                return { atlas = atlas.atlas, file = "Interface\\GossipFrame\\AvailableQuestIcon" }
            end
        end
        return { atlas = "worldquest-tracker-questmarker", file = "Interface\\GossipFrame\\AvailableQuestIcon" }
    end
    if data.isCampaign then
        return { atlas = "questlog-questtypeicon-campaign", file = "Interface\\GossipFrame\\AvailableQuestIcon" }
    end
    local tag = data.questID and Compat.GetQuestTagInfo(data.questID)
    local tagID = type(tag) == "table" and (tag.tagID or tag.worldQuestType) or nil
    local QT = Enum and Enum.QuestTag
    local function TagIs(enumVal, numeric)
        if tagID == nil then
            return false
        end
        if enumVal and tagID == enumVal then
            return true
        end
        return numeric and tagID == numeric
    end
    if TagIs(QT and QT.Legendary, 83) then
        return { atlas = "questlog-questtypeicon-legendary", file = "Interface\\GossipFrame\\AvailableLegendaryQuestIcon" }
    end
    if TagIs(QT and QT.Dungeon, 81) then
        return { atlas = "questlog-questtypeicon-dungeon", file = "Interface\\Minimap\\Tracking\\Class" }
    end
    if TagIs(QT and QT.Raid, 62) or tagID == 88 or tagID == 89 then
        return { atlas = "questlog-questtypeicon-raid", file = "Interface\\Minimap\\Tracking\\Class" }
    end
    if TagIs(QT and (QT.PvP or QT.Pvp), 41) then
        return { atlas = "questlog-questtypeicon-pvp", file = "Interface\\Minimap\\Tracking\\BattleMaster" }
    end
    if TagIs(QT and QT.Heroic, 85) then
        return { atlas = "questlog-questtypeicon-heroic", file = "Interface\\LFGFrame\\UI-LFG-ICON-HEROIC" }
    end
    if TagIs(QT and QT.Group, 1) then
        return { atlas = "questlog-questtypeicon-group", file = "Interface\\GossipFrame\\AvailableQuestIcon" }
    end
    local freq = data.frequency
    if not freq and data.questID then
        local idx = Compat.GetLogIndexForQuestID(data.questID)
        if idx and C_QuestLog and C_QuestLog.GetInfo then
            local info = Safe(C_QuestLog.GetInfo, idx)
            if type(info) == "table" then
                freq = info.frequency
            end
        elseif idx and GetQuestLogTitle then
            freq = select(7, Safe(GetQuestLogTitle, idx))
        end
    end
    local QF = Enum and Enum.QuestFrequency
    if freq == 3 or (QF and freq == QF.Weekly) then
        return { atlas = "questlog-questtypeicon-weekly", file = "Interface\\GossipFrame\\DailyQuestIcon" }
    end
    if freq == 2 or (QF and freq == QF.Daily) then
        return { atlas = "questlog-questtypeicon-daily", file = "Interface\\GossipFrame\\DailyQuestIcon" }
    end
    return { file = "Interface\\GossipFrame\\AvailableQuestIcon" }
end

function Compat.GetWatchedQuestIDs()
    local ids = {}
    if C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatchIndex then
        local n = Safe(C_QuestLog.GetNumQuestWatches) or 0
        for i = 1, n do
            local id = Safe(C_QuestLog.GetQuestIDForQuestWatchIndex, i)
            if Compat.CanUseNumber(id) and id > 0 then
                ids[#ids + 1] = id
            end
        end
        return ids
    end
    local n = Safe(GetNumQuestWatches) or 0
    for i = 1, n do
        local logIndex = Safe(GetQuestIndexForWatch, i)
        if type(logIndex) == "number" then
            local questID
            if GetQuestLogTitle then
                questID = select(8, Safe(GetQuestLogTitle, logIndex))
            end
            if Compat.CanUseNumber(questID) and questID > 0 then
                ids[#ids + 1] = questID
            end
        end
    end
    return ids
end

function Compat.AddQuestWatch(questID)
    if not Compat.CanUseNumber(questID) then
        return
    end
    if C_QuestLog and C_QuestLog.AddQuestWatch then
        Safe(C_QuestLog.AddQuestWatch, questID)
        return
    end
    local idx = Compat.GetLogIndexForQuestID(questID)
    if idx and AddQuestWatch then
        Safe(AddQuestWatch, idx)
    end
end

function Compat.RemoveQuestWatch(questID)
    if type(questID) ~= "number" then
        return
    end
    if C_QuestLog and C_QuestLog.RemoveQuestWatch then
        pcall(C_QuestLog.RemoveQuestWatch, questID)
        if Enum and Enum.QuestWatchType then
            pcall(C_QuestLog.RemoveQuestWatch, questID, Enum.QuestWatchType.Automatic)
            pcall(C_QuestLog.RemoveQuestWatch, questID, Enum.QuestWatchType.Manual)
        end
    end
    local idx = Compat.GetLogIndexForQuestID(questID)
    if idx and RemoveQuestWatch then
        pcall(RemoveQuestWatch, idx)
    end
end

function Compat.GetQuestLogSpecialItemInfo(logIndex)
    if not logIndex or not GetQuestLogSpecialItemInfo then
        return nil
    end
    local link, tex, charges, showWhenComplete = Safe(GetQuestLogSpecialItemInfo, logIndex)
    if type(link) == "string" then
        return link, tex, charges, showWhenComplete
    end
    return nil
end

function Compat.GetQuestTrackerItem(questID, logIndex, isComplete)
    local idx = logIndex
    if not idx then
        idx = Compat.GetLogIndexForQuestID(questID)
    end
    local link, tex, charges, showWhenComplete = Compat.GetQuestLogSpecialItemInfo(idx)
    if type(link) ~= "string" then
        return nil
    end
    if isComplete and showWhenComplete == false then
        return nil
    end
    return {
        questID = questID,
        logIndex = idx,
        link = link,
        texture = tex,
        charges = charges,
    }
end

function Compat.SuperTrackQuest(questID)
    if not Compat.CanUseNumber(questID) then
        return
    end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        Safe(C_SuperTrack.SetSuperTrackedQuestID, questID)
        return
    end
    if SetSuperTrackedQuestID then
        Safe(SetSuperTrackedQuestID, questID)
    end
end

function Compat.ClearSuperTrack()
    if C_SuperTrack then
        if C_SuperTrack.SetSuperTrackedQuestID then
            pcall(C_SuperTrack.SetSuperTrackedQuestID, 0)
        end
        if C_SuperTrack.ClearAllSuperTracked then
            pcall(C_SuperTrack.ClearAllSuperTracked)
        end
        return
    end
    if SetSuperTrackedQuestID then
        pcall(SetSuperTrackedQuestID, 0)
    end
end

function Compat.OpenQuestDetails(questID)
    if not Compat.CanUseNumber(questID) then
        return
    end
    if QuestUtil and QuestUtil.OpenQuestDetails then
        Safe(QuestUtil.OpenQuestDetails, questID)
        return
    end
    if QuestMapFrame_OpenToQuestDetails then
        Safe(QuestMapFrame_OpenToQuestDetails, questID)
        return
    end
    local idx = Compat.GetLogIndexForQuestID(questID)
    if idx and SelectQuestLogEntry then
        Safe(SelectQuestLogEntry, idx)
    end
    if ShowUIPanel and QuestLogFrame then
        Safe(ShowUIPanel, QuestLogFrame)
    elseif ToggleQuestLog then
        Safe(ToggleQuestLog)
    end
end

function Compat.ShowQuestOnMap(questID)
    if not Compat.CanUseNumber(questID) then
        return
    end
    if QuestMapFrame_OpenToQuestDetails then
        Safe(QuestMapFrame_OpenToQuestDetails, questID)
        return
    end
    if C_QuestLog and C_QuestLog.GetQuestUiMapID then
        local mapID = Safe(C_QuestLog.GetQuestUiMapID, questID)
        if type(mapID) == "number" then
            if OpenWorldMap then
                Safe(OpenWorldMap, mapID)
            elseif WorldMapFrame and ShowUIPanel then
                Safe(ShowUIPanel, WorldMapFrame)
            end
            Compat.OpenQuestDetails(questID)
            return
        end
    end
    local mapID = select(1, Compat.GetQuestLocation(questID))
    if type(mapID) == "number" and OpenWorldMap then
        Safe(OpenWorldMap, mapID)
    end
    Compat.OpenQuestDetails(questID)
end

function Compat.CanShareQuest(questID)
    if not Compat.CanUseNumber(questID) then
        return false
    end
    if IsInGroup and not IsInGroup() then
        return false
    end
    if C_QuestLog and C_QuestLog.IsPushableQuest then
        return Safe(C_QuestLog.IsPushableQuest, questID) and true or false
    end
    local idx = Compat.GetLogIndexForQuestID(questID)
    if idx and GetQuestLogPushable then
        if SelectQuestLogEntry then
            Safe(SelectQuestLogEntry, idx)
        end
        return Safe(GetQuestLogPushable) and true or false
    end
    return false
end

function Compat.ShareQuest(questID)
    if not Compat.CanUseNumber(questID) then
        return
    end
    if QuestUtil and QuestUtil.ShareQuest then
        Safe(QuestUtil.ShareQuest, questID)
        return
    end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        Safe(C_QuestLog.SetSelectedQuest, questID)
    else
        local idx = Compat.GetLogIndexForQuestID(questID)
        if idx and SelectQuestLogEntry then
            Safe(SelectQuestLogEntry, idx)
        end
    end
    if QuestLogPushQuest then
        Safe(QuestLogPushQuest)
    end
end

function Compat.PromptAbandonQuest(questID)
    if not Compat.CanUseNumber(questID) then
        return
    end
    if QuestMapQuestOptions_AbandonQuest then
        pcall(QuestMapQuestOptions_AbandonQuest, questID)
        return
    end
    local name = Compat.GetQuestTitle(questID) or "Quest"
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        Safe(C_QuestLog.SetSelectedQuest, questID)
        if C_QuestLog.SetAbandonQuest then
            Safe(C_QuestLog.SetAbandonQuest)
        end
        if C_QuestLog.GetAbandonQuestName then
            name = Safe(C_QuestLog.GetAbandonQuestName) or name
        end
    else
        local idx = Compat.GetLogIndexForQuestID(questID)
        if idx and SelectQuestLogEntry then
            Safe(SelectQuestLogEntry, idx)
        end
        if SetAbandonQuest then
            Safe(SetAbandonQuest)
        end
        if GetAbandonQuestName then
            name = Safe(GetAbandonQuestName) or name
        end
    end
    if StaticPopup_Show then
        pcall(StaticPopup_Show, "ABANDON_QUEST", name)
    end
end

function Compat.RemoveWorldQuestWatch(questID)
    if type(questID) ~= "number" then
        return
    end
    if QuestUtil and QuestUtil.UntrackWorldQuest then
        pcall(QuestUtil.UntrackWorldQuest, questID)
    end
    if C_QuestLog and C_QuestLog.RemoveWorldQuestWatch then
        pcall(C_QuestLog.RemoveWorldQuestWatch, questID)
    end
    Compat.RemoveQuestWatch(questID)
end

local function ContentTrackingType(name, fallback)
    local e = Enum and Enum.ContentTrackingType and Enum.ContentTrackingType[name]
    if type(e) == "number" then
        return e
    end
    return fallback
end

local function ContentTrackingStopManual()
    local e = Enum and Enum.ContentTrackingStopType and Enum.ContentTrackingStopType.Manual
    if type(e) == "number" then
        return e
    end
    return 2
end

function Compat.UntrackContent(trackType, id)
    if type(id) ~= "number" then
        return false
    end
    local CT = C_ContentTracking
    if not CT then
        return false
    end
    local stopEnum = ContentTrackingStopManual()
    local function stop(t)
        if t == nil then
            return
        end
        if CT.StopTracking then
            pcall(CT.StopTracking, t, id, stopEnum)
            pcall(CT.StopTracking, t, id, 2)
        end
    end
    if trackType ~= nil then
        stop(trackType)
    else
        stop(0)
        stop(1)
        stop(2)
        stop(3)
    end
    return true
end

function Compat.UntrackAchievement(id)
    if type(id) ~= "number" then
        return false
    end
    Compat.UntrackContent(ContentTrackingType("Achievement", 2), id)
    if RemoveTrackedAchievement then
        pcall(RemoveTrackedAchievement, id)
    end
    if AchievementFrameAchievements_ForceUpdate then
        pcall(AchievementFrameAchievements_ForceUpdate)
    end
    return true
end

function Compat.OpenAchievement(id)
    if type(id) ~= "number" then
        return
    end
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AchievementUI")
    elseif LoadAddOn then
        pcall(LoadAddOn, "Blizzard_AchievementUI")
    end
    if AchievementFrame_LoadUI then
        pcall(AchievementFrame_LoadUI)
    end
    if ShowAchievementFrameForAchievement then
        pcall(ShowAchievementFrameForAchievement, id)
        return
    end
    if OpenAchievementFrameToAchievement then
        pcall(OpenAchievementFrameToAchievement, id)
        return
    end
    if ShowUIPanel and AchievementFrame then
        pcall(ShowUIPanel, AchievementFrame)
    end
    if AchievementFrame_SelectAchievement then
        pcall(AchievementFrame_SelectAchievement, id)
    end
end

function Compat.WowheadURL(kind, id)
    if not Compat.CanUseNumber(id) then
        return nil
    end
    local flavor = Compat.GetFlavor()
    local base = "https://www.wowhead.com/"
    if flavor == "era" then
        base = base .. "classic/"
    elseif flavor == "tbc" then
        base = base .. "tbc/"
    elseif flavor == "wrath" then
        base = base .. "wotlk/"
    elseif flavor == "cata" then
        base = base .. "cata/"
    elseif flavor == "mop" then
        base = base .. "mop-classic/"
    end
    if kind == "achievement" then
        return base .. "achievement=" .. tostring(id)
    end
    if kind == "spell" or kind == "recipe" then
        return base .. "spell=" .. tostring(id)
    end
    return base .. "quest=" .. tostring(id)
end

function Compat.GetSuperTrackedQuestID()
    if C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local id = Safe(C_SuperTrack.GetSuperTrackedQuestID)
        if Compat.CanUseNumber(id) then
            return id
        end
    end
    if GetSuperTrackedQuestID then
        local id = Safe(GetSuperTrackedQuestID)
        if Compat.CanUseNumber(id) then
            return id
        end
    end
    return nil
end

function Compat.IsWorldQuest(questID)
    if not Compat.CanUseNumber(questID) then
        return false
    end
    if C_QuestLog and C_QuestLog.IsWorldQuest then
        return Safe(C_QuestLog.IsWorldQuest, questID) and true or false
    end
    return false
end

function Compat.GetWatchedWorldQuestIDs()
    local ids = {}
    if C_QuestLog and C_QuestLog.GetNumWorldQuestWatches and C_QuestLog.GetQuestIDForWorldQuestWatchIndex then
        local n = Safe(C_QuestLog.GetNumWorldQuestWatches) or 0
        for i = 1, n do
            local id = Safe(C_QuestLog.GetQuestIDForWorldQuestWatchIndex, i)
            if Compat.CanUseNumber(id) and id > 0 then
                ids[#ids + 1] = id
            end
        end
    end
    return ids
end

function Compat.IsInInstance()
    local inInstance = Safe(IsInInstance)
    return inInstance and true or false
end

function Compat.InCombat()
    return InCombatLockdown and InCombatLockdown() and true or false
end

function Compat.UnitLevel()
    return Safe(UnitLevel, "player") or 1
end

function Compat.UnitFaction()
    local f = Safe(UnitFactionGroup, "player")
    if type(f) == "string" and not Compat.IsSecretValue(f) then
        return f
    end
    return nil
end

function Compat.UnitClassFile()
    local _, classFile = Safe(UnitClass, "player")
    if type(classFile) == "string" and not Compat.IsSecretValue(classFile) then
        return classFile
    end
    return nil
end

function Compat.QuestIDFromAccepted(arg1, arg2)
    if type(arg2) == "number" and Compat.CanUseNumber(arg2) and arg2 > 0 then
        return arg2
    end
    if type(arg1) ~= "number" then
        return nil
    end
    if Compat.IsRetail() then
        return Compat.CanUseNumber(arg1) and arg1 or nil
    end
    if C_QuestLog and C_QuestLog.GetInfo then
        local info = Safe(C_QuestLog.GetInfo, arg1)
        if type(info) == "table" and Compat.CanUseNumber(info.questID) and info.questID > 0 then
            return info.questID
        end
    end
    if GetQuestLogTitle then
        local questID = select(8, Safe(GetQuestLogTitle, arg1))
        if Compat.CanUseNumber(questID) and questID > 0 then
            return questID
        end
    end
    if Compat.CanUseNumber(arg1) and arg1 > 0 then
        return arg1
    end
    return nil
end

function Compat.GetQuestLocation(questID)
    if not Compat.CanUseNumber(questID) then
        return nil
    end
    if C_QuestLog and C_QuestLog.GetNextWaypoint then
        local mapID, x, y = Safe(C_QuestLog.GetNextWaypoint, questID)
        if type(mapID) == "number" and x and y then
            return mapID, x, y
        end
    end
    if C_QuestLog and C_QuestLog.GetNextWaypointForMap then
        local playerMap = Compat.GetPlayerMapPosition()
        if type(playerMap) == "number" then
            local mapID, x, y = Safe(C_QuestLog.GetNextWaypointForMap, questID, playerMap)
            if x and y then
                return mapID or playerMap, x, y
            end
        end
    end
    if C_TaskQuest then
        local mapID = C_TaskQuest.GetQuestZoneID and Safe(C_TaskQuest.GetQuestZoneID, questID)
        local x, y = C_TaskQuest.GetQuestLocation and Safe(C_TaskQuest.GetQuestLocation, questID)
        if not mapID then
            mapID = Compat.GetPlayerMapPosition()
        end
        if type(mapID) == "number" and x and y then
            return mapID, x, y
        end
    end
    return nil
end

function Compat.GetPlayerMapPosition()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = Safe(C_Map.GetBestMapForUnit, "player")
        if type(mapID) == "number" then
            local pos = Safe(C_Map.GetPlayerMapPosition, mapID, "player")
            if pos and pos.GetXY then
                local x, y = pos:GetXY()
                return mapID, x, y
            end
        end
        return mapID
    end
    return nil
end

--- Map names from a map ID up to the continent. Empty if unknown.
function Compat.GetMapNameChainFrom(mapID)
    local names = {}
    if type(mapID) ~= "number" or not C_Map or not C_Map.GetMapInfo then
        return names, mapID
    end
    local id = mapID
    local guard = 0
    while type(id) == "number" and guard < 8 do
        guard = guard + 1
        local info = Safe(C_Map.GetMapInfo, id)
        if type(info) ~= "table" then
            break
        end
        if type(info.name) == "string" and info.name ~= "" then
            names[#names + 1] = info.name
        end
        id = info.parentMapID
        if id == 0 then
            break
        end
    end
    return names, mapID
end

function Compat.GetQuestUiMapID(questID)
    if not Compat.CanUseNumber(questID) then
        return nil
    end
    if C_QuestLog and C_QuestLog.GetQuestUiMapID then
        local mapID = Safe(C_QuestLog.GetQuestUiMapID, questID)
        if type(mapID) == "number" and mapID > 0 then
            return mapID
        end
    end
    return nil
end

--- Map names from the current zone up to the continent. Empty if unknown.
function Compat.GetMapNameChain()
    return Compat.GetMapNameChainFrom(select(1, Compat.GetPlayerMapPosition()))
end

function Compat.QuestLogIsFull()
    local maxQ = 25
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        maxQ = Safe(C_QuestLog.GetMaxNumQuestsCanAccept) or maxQ
    elseif MAX_QUESTS then
        maxQ = MAX_QUESTS
    end
    local numQuests = 0
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local _, quests = Safe(C_QuestLog.GetNumQuestLogEntries)
        numQuests = quests or 0
    else
        local _, quests = Safe(GetNumQuestLogEntries)
        numQuests = quests or 0
    end
    return numQuests >= maxQ
end

local function GossipList(list)
    if type(list) ~= "table" then
        return {}
    end
    if list[1] ~= nil or #list > 0 then
        return list
    end
    local out = {}
    for _, v in pairs(list) do
        out[#out + 1] = v
    end
    return out
end

function Compat.GetGossipAvailableQuests()
    if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
        return GossipList(Safe(C_GossipInfo.GetAvailableQuests))
    end
    local n = Safe(GetNumGossipAvailableQuests) or 0
    local out = {}
    for i = 1, n do
        out[i] = { index = i }
    end
    return out
end

function Compat.GetGossipActiveQuests()
    if C_GossipInfo and C_GossipInfo.GetActiveQuests then
        return GossipList(Safe(C_GossipInfo.GetActiveQuests))
    end
    local n = Safe(GetNumGossipActiveQuests) or 0
    local out = {}
    local data = {}
    if n > 0 and GetGossipActiveQuests then
        local packed = { pcall(GetGossipActiveQuests) }
        if packed[1] then
            for i = 2, #packed do
                data[#data + 1] = packed[i]
            end
        end
    end
    local stride = 0
    if n > 0 and #data >= n then
        stride = math.floor(#data / n)
    end
    for i = 1, n do
        local isComplete = false
        if stride >= 4 then
            isComplete = data[(i - 1) * stride + 4] and true or false
        end
        out[i] = { index = i, isComplete = isComplete }
    end
    return out
end

function Compat.SelectGossipAvailableQuest(entry, index)
    local id = type(entry) == "table" and (entry.questID or entry.questId) or nil
    if C_GossipInfo and C_GossipInfo.SelectAvailableQuest then
        if Compat.CanUseNumber(id) then
            Safe(C_GossipInfo.SelectAvailableQuest, id)
            return
        end
        Safe(C_GossipInfo.SelectAvailableQuest, index)
        return
    end
    if SelectGossipAvailableQuest then
        Safe(SelectGossipAvailableQuest, index)
    end
end

function Compat.SelectGossipActiveQuest(entry, index)
    local id = type(entry) == "table" and (entry.questID or entry.questId) or nil
    if C_GossipInfo and C_GossipInfo.SelectActiveQuest then
        if Compat.CanUseNumber(id) then
            Safe(C_GossipInfo.SelectActiveQuest, id)
            return
        end
        Safe(C_GossipInfo.SelectActiveQuest, index)
        return
    end
    if SelectGossipActiveQuest then
        Safe(SelectGossipActiveQuest, index)
    end
end

function Compat.RequestQuestData(questID)
    if not Compat.CanUseNumber(questID) then
        return
    end
    if C_QuestLog and C_QuestLog.RequestLoadQuestByID then
        Safe(C_QuestLog.RequestLoadQuestByID, questID)
    end
end

function Compat.GetMapName(mapID)
    if type(mapID) ~= "number" then
        return nil
    end
    if C_Map and C_Map.GetMapInfo then
        local info = Safe(C_Map.GetMapInfo, mapID)
        if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
            return info.name
        end
    end
    return nil
end

function Compat.GetQuestDescription(questID)
    if not Compat.CanUseNumber(questID) then
        return nil
    end
    if C_QuestLog and C_QuestLog.GetQuestDescription then
        local t = Safe(C_QuestLog.GetQuestDescription, questID)
        if type(t) == "string" and t ~= "" then
            return t
        end
    end
    if C_TooltipInfo and C_TooltipInfo.GetHyperlink then
        local info = Safe(C_TooltipInfo.GetHyperlink, "quest:" .. tostring(questID))
        if type(info) == "table" then
            local lines = info.lines or info
            local parts = {}
            local start = 2
            for i = start, math.min(#lines, 8) do
                local line = lines[i]
                local text = type(line) == "table" and (line.leftText or line.text) or nil
                if type(text) == "string" and text ~= "" then
                    parts[#parts + 1] = text
                end
            end
            if #parts > 0 then
                return table.concat(parts, " ")
            end
        end
    end
    return nil
end

local function NormalizeMapXY(x, y)
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

local function ScanQuestLineMap(mapID, questID)
    if type(mapID) ~= "number" or not C_QuestLine then
        return nil
    end
    if C_QuestLine.RequestQuestLinesForMap then
        pcall(C_QuestLine.RequestQuestLinesForMap, mapID)
    end
    local lines
    if C_QuestLine.GetAvailableQuestLines then
        lines = Safe(C_QuestLine.GetAvailableQuestLines, mapID)
    end
    if type(lines) ~= "table" then
        return nil
    end
    for i = 1, #lines do
        local row = lines[i]
        if type(row) == "table" then
            local qid = row.questID or row.QuestID
            if qid == questID then
                local x, y = NormalizeMapXY(row.x or row.X, row.y or row.Y)
                if x then
                    return mapID, x, y
                end
            end
        end
    end
    return nil
end

function Compat.GetQuestPickupLocation(questID)
    if not Compat.CanUseNumber(questID) then
        return nil
    end
    local mapID, x, y = Compat.GetQuestLocation(questID)
    if type(mapID) == "number" and x and y then
        return mapID, x, y, "blizzard"
    end
    if QuestPOIGetIconInfo then
        local _, px, py = Safe(QuestPOIGetIconInfo, questID)
        local mx, my = NormalizeMapXY(px, py)
        if mx then
            local poiMap = Compat.GetPlayerMapPosition()
            if C_QuestLog and C_QuestLog.GetQuestUiMapID then
                poiMap = Safe(C_QuestLog.GetQuestUiMapID, questID) or poiMap
            end
            if type(poiMap) == "number" then
                return poiMap, mx, my, "blizzard"
            end
        end
    end
    local maps = {}
    local playerMap = Compat.GetPlayerMapPosition()
    if type(playerMap) == "number" then
        maps[#maps + 1] = playerMap
    end
    if C_QuestLog and C_QuestLog.GetQuestUiMapID then
        local qMap = Safe(C_QuestLog.GetQuestUiMapID, questID)
        if type(qMap) == "number" then
            maps[#maps + 1] = qMap
        end
    end
    for i = 1, #maps do
        local foundMap, fx, fy = ScanQuestLineMap(maps[i], questID)
        if foundMap then
            return foundMap, fx, fy, "blizzard"
        end
    end
    if C_QuestLog and C_QuestLog.GetQuestUiMapID then
        local qMap = Safe(C_QuestLog.GetQuestUiMapID, questID)
        if type(qMap) == "number" then
            return qMap, nil, nil, "blizzard"
        end
    end
    return nil
end
