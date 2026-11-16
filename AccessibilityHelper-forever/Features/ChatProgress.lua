--[[
  Accessibility Helper — chat page progress and collections
  These lines are not chat messages. Read chat does not have to be on.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.ChatProgress = AH.ChatProgress or {}
local Progress = AH.ChatProgress

AH.QuestTitles = AH.QuestTitles or {}

local recent = {}
local questCount = {}
local criteriaCount = {}
local criteriaCursor = {}
local knownMounts = {}
local knownCompanions = {}
local knownPets = {}
local knownHeirlooms = {}
local live = false
local seedGen = 0
local achDirty = false
local achWait = 0
local achPrimed = false
local achQuiet = true
local achCats = nil
local achCatIndex = 1
local achInCat = 1
local achTrackedPending = false
local questQuiet = true
local questCursor = 1
local questMode = nil
local questDirty = false
local watchDirty = false
local achSerial = 0
local achMark = 0
local seeded = false

local function Num(v)
    if AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(v) then
        return v
    end
    if type(v) == "number" then
        return v
    end
    return nil
end

local function Text(v)
    if AH.Compat and AH.Compat.UsableString then
        return AH.Compat.UsableString(v)
    end
    if type(v) == "string" and v ~= "" then
        return v
    end
    return nil
end

local function Flag(v)
    if AH.Compat and AH.Compat.CanUseValue and not AH.Compat.CanUseValue(v) then
        return nil
    end
    if v == true or v == 1 then
        return true
    end
    return false
end

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function On(key)
    return DB()[key] == true
end

local function Say(msg)
    msg = Text(msg)
    if not msg then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_INFO, { noEcho = true })
    end
end

local function Claim(key)
    local now = 0
    if GetTime then
        local ok, t = pcall(GetTime)
        if ok and type(t) == "number" then
            now = t
        end
    end
    local seen = recent[key]
    if type(seen) == "number" and (now - seen) >= 0 and (now - seen) < 0.6 then
        return false
    end
    recent[key] = now
    return true
end

local function Digits(n)
    n = Num(n)
    if not n then
        return nil
    end
    if n < 0 then
        n = 0
    end
    return tostring(math.floor(n + 0.5))
end

local function ItemName(itemID)
    itemID = Num(itemID)
    if not itemID then
        return nil
    end
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        name = ok and Text(name) or nil
        if name then
            return name
        end
    end
    if GetItemInfo then
        local ok, name = pcall(GetItemInfo, itemID)
        if ok then
            return Text(name)
        end
    end
    return nil
end

function Progress.SpeakPickup(name, qty)
    if not live or not On("chatItemPickup") then
        return
    end
    name = Text(name)
    if not name then
        return
    end
    if not Claim("pick:" .. string.lower(name)) then
        return
    end
    qty = Num(qty)
    if not qty or qty < 1 then
        qty = 1
    end
    local count = Digits(qty) or "1"
    Say("You picked up: " .. name .. " x" .. count .. ".")
end

local function SplitObjective(text)
    text = Text(text)
    if not text then
        return nil, nil, nil
    end
    local cur, need, label = string.match(text, "^(%d+)%s*/%s*(%d+)%s+(.+)$")
    if not cur then
        label, cur, need = string.match(text, "^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    end
    if not cur then
        cur, need = string.match(text, "(%d+)%s*/%s*(%d+)")
        label = string.gsub(text, "%d+%s*/%s*%d+", "")
        label = string.gsub(label or "", "^[:%s]+", "")
        label = string.gsub(label, "[:%s]+$", "")
    end
    return Text(label), Num(tonumber(cur)), Num(tonumber(need))
end

local function NoteQuest(questID, title, index, label, cur, need, raw)
    questID = Num(questID)
    title = Text(title)
    if questID and title then
        AH.QuestTitles[questID] = title
    end
    cur = Num(cur)
    if not questID or not cur then
        return
    end
    local key = tostring(questID) .. ":" .. tostring(index)
    local prev = questCount[key]
    questCount[key] = cur
    if not live or not On("chatQuestProgress") or not prev or cur <= prev then
        return
    end
    local curText = Digits(cur)
    local needText = Digits(need)
    if not title then
        title = "Quest"
    end
    label = Text(label)
    if not label then
        label = Text(raw)
    end
    local line = "Quest progress. " .. title .. "."
    if label and curText and needText then
        line = line .. " " .. label .. ", " .. curText .. " / " .. needText .. "."
    elseif curText and needText then
        line = line .. " " .. curText .. " / " .. needText .. "."
    elseif Text(raw) then
        line = line .. " " .. Text(raw) .. "."
    end
    Say(line)
end

local function NoteObjectives(questID, title, objectives)
    if type(objectives) ~= "table" then
        return
    end
    local j
    for j = 1, #objectives do
        local obj = objectives[j]
        if type(obj) == "table" then
            local label, cur, need = SplitObjective(obj.text)
            if not cur then
                cur = Num(obj.numFulfilled)
            end
            if not need then
                need = Num(obj.numRequired)
            end
            NoteQuest(questID, title, j, label, cur, need, obj.text)
        end
    end
end

local function ScanModernEntry(i)
    local infoOk, info = pcall(C_QuestLog.GetInfo, i)
    if not infoOk or type(info) ~= "table" or Flag(info.isHeader) == true then
        return
    end
    local questID = Num(info.questID)
    local title = Text(info.title)
    if not questID or not C_QuestLog.GetQuestObjectives then
        return
    end
    local objOk, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if objOk then
        NoteObjectives(questID, title, objectives)
    end
end

local function ScanClassicEntry(i)
    if not GetQuestLogTitle then
        return
    end
    local titleOk, title, _, _, isHeader, _, _, _, questID = pcall(GetQuestLogTitle, i)
    if not titleOk or Flag(isHeader) == true then
        return
    end
    if not GetNumQuestLeaderBoards or not GetQuestLogLeaderBoard then
        return
    end
    local boardsOk, boards = pcall(GetNumQuestLeaderBoards, i)
    boards = boardsOk and Num(boards) or nil
    if not boards or boards < 1 then
        return
    end
    local j
    for j = 1, boards do
        local boardOk, text = pcall(GetQuestLogLeaderBoard, j, i)
        if boardOk then
            local label, cur, need = SplitObjective(text)
            NoteQuest(questID, title, j, label, cur, need, text)
        end
    end
end

local function BeginQuestMode()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
        questMode = "modern"
        return
    end
    if GetNumQuestLogEntries and GetQuestLogTitle then
        questMode = "classic"
        return
    end
    questMode = "none"
end

local function QuestCount()
    if questMode == "modern" then
        local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)
        return ok and Num(count) or 0
    end
    if questMode == "classic" then
        local ok, count = pcall(GetNumQuestLogEntries)
        return ok and Num(count) or 0
    end
    return 0
end

local function ScanQuestID(questID)
    questID = Num(questID)
    if not questID or not C_QuestLog or not C_QuestLog.GetQuestObjectives then
        return
    end
    local title
    if C_QuestLog.GetTitleForQuestID then
        local ok, name = pcall(C_QuestLog.GetTitleForQuestID, questID)
        title = ok and Text(name) or nil
    end
    if not title then
        title = Text(AH.QuestTitles[questID])
    end
    local objOk, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    if objOk then
        NoteObjectives(questID, title, objectives)
    end
end

local function ScanWatchedNow()
    if C_QuestLog and C_QuestLog.GetNumQuestWatches and C_QuestLog.GetQuestIDForQuestWatch then
        local ok, n = pcall(C_QuestLog.GetNumQuestWatches)
        n = ok and Num(n) or 0
        if n and n > 0 then
            local i
            for i = 1, n do
                local idOk, questID = pcall(C_QuestLog.GetQuestIDForQuestWatch, i)
                if idOk then
                    ScanQuestID(questID)
                end
            end
            return
        end
    end
    if not GetNumQuestWatches or not GetQuestIndexForWatch then
        return
    end
    local ok, n = pcall(GetNumQuestWatches)
    n = ok and Num(n) or 0
    if not n or n < 1 then
        return
    end
    local i
    for i = 1, n do
        local idxOk, index = pcall(GetQuestIndexForWatch, i)
        index = idxOk and Num(index) or nil
        if index then
            if questMode == "modern" and C_QuestLog and C_QuestLog.GetInfo then
                ScanModernEntry(index)
            else
                ScanClassicEntry(index)
            end
        end
    end
end

local function StepQuests()
    if questMode == "none" then
        questMode = nil
    end
    if not questMode then
        BeginQuestMode()
    end
    if questMode == "none" then
        return false
    end
    local count = QuestCount()
    if not count or count < 1 then
        questCursor = 1
        questQuiet = false
        return true
    end
    if questCursor < 1 or questCursor > count then
        questCursor = 1
    end
    local n = 0
    while n < 3 and questCursor <= count do
        if questMode == "modern" then
            ScanModernEntry(questCursor)
        elseif questMode == "classic" then
            ScanClassicEntry(questCursor)
        end
        questCursor = questCursor + 1
        n = n + 1
    end
    if questCursor > count then
        questCursor = 1
        questQuiet = false
        return true
    end
    return false
end

local function AchievementComplete(id)
    if not GetAchievementInfo then
        return false
    end
    local ok, _, _, _, completed = pcall(GetAchievementInfo, id)
    if not ok then
        return false
    end
    return Flag(completed) == true
end

local function SpeakAchievementProgress(name, cur, need)
    if not On("chatAchievementProgress") then
        return
    end
    local curText = Digits(cur)
    local needText = Digits(need)
    name = Text(name)
    if not name or not curText or not needText then
        return
    end
    if not Claim("aprogress:" .. string.lower(name) .. ":" .. curText) then
        return
    end
    Say("Achievement progress. " .. name .. ". " .. curText .. " / " .. needText .. ".")
end

local function ScanOneAchievement(id, name, silent)
    if not GetAchievementNumCriteria or not GetAchievementCriteriaInfo then
        return true
    end
    id = Num(id)
    name = Text(name)
    if not id or not name then
        return true
    end
    if AchievementComplete(id) then
        return true
    end
    local numOk, n = pcall(GetAchievementNumCriteria, id)
    n = numOk and Num(n) or nil
    if not n or n < 1 then
        return true
    end
    local startAt = criteriaCursor[id] or 1
    if startAt < 1 or startAt > n then
        startAt = 1
    end
    local last = startAt + 7
    if last > n then
        last = n
    end
    local finished = 0
    local i
    for i = startAt, last do
        local ok, _, _, completed, quantity, reqQuantity = pcall(GetAchievementCriteriaInfo, id, i)
        quantity = ok and Num(quantity) or nil
        reqQuantity = ok and Num(reqQuantity) or nil
        if Flag(completed) == true or (quantity and reqQuantity and reqQuantity > 0 and quantity >= reqQuantity) then
            finished = finished + 1
        end
        local key = tostring(id) .. ":" .. tostring(i)
        local prev = criteriaCount[key]
        if quantity then
            criteriaCount[key] = quantity
        end
        if not silent and live and prev and quantity and quantity > prev then
            if reqQuantity and quantity < reqQuantity then
                SpeakAchievementProgress(name, quantity, reqQuantity)
            elseif startAt == 1 and last == n and n > 1 and finished < n then
                SpeakAchievementProgress(name, finished, n)
            end
        end
    end
    if last >= n then
        criteriaCursor[id] = 1
        return true
    end
    criteriaCursor[id] = last + 1
    return false
end

local function ScanTracked(silent)
    if not GetTrackedAchievements then
        return true
    end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(GetTrackedAchievements)
    if not ok then
        return true
    end
    local ids = { a, b, c, d, e, f, g, h, i, j }
    local n
    for n = 1, #ids do
        local id = Num(ids[n])
        if id and GetAchievementInfo then
            local infoOk, _, name = pcall(GetAchievementInfo, id)
            if not ScanOneAchievement(id, infoOk and name or nil, silent) then
                return false
            end
        end
    end
    return true
end

local function StepAchievements()
    if not GetCategoryList or not GetCategoryNumAchievements or not GetAchievementInfo then
        ScanTracked(achQuiet)
        achQuiet = false
        achPrimed = true
        return true
    end
    if not achCats then
        local ok, cats = pcall(GetCategoryList)
        if not ok or type(cats) ~= "table" then
            ScanTracked(achQuiet)
            achQuiet = false
            achPrimed = true
            return true
        end
        achCats = cats
        achCatIndex = 1
        achInCat = 1
    end
    local budget = 2
    while budget > 0 and achCatIndex <= #achCats do
        local numOk, num = pcall(GetCategoryNumAchievements, achCats[achCatIndex])
        num = numOk and Num(num) or 0
        if not num or num < 1 or achInCat > num then
            achCatIndex = achCatIndex + 1
            achInCat = 1
            budget = budget - 1
        else
            local infoOk, id, name, _, completed = pcall(GetAchievementInfo, achCats[achCatIndex], achInCat)
            id = infoOk and Num(id) or nil
            name = infoOk and Text(name) or nil
            achInCat = achInCat + 1
            budget = budget - 1
            if id and name and Flag(completed) ~= true then
                if not ScanOneAchievement(id, name, achQuiet) then
                    achInCat = achInCat - 1
                end
            end
            if achInCat > num then
                achCatIndex = achCatIndex + 1
                achInCat = 1
            end
        end
    end
    if achCatIndex > #achCats then
        achQuiet = false
        achPrimed = true
        achCatIndex = 1
        achInCat = 1
        return true
    end
    return false
end

local function Remember(store, name)
    name = Text(name)
    if not name then
        return false
    end
    local key = string.lower(name)
    if store[key] then
        return false
    end
    store[key] = true
    return true
end

local function AnnounceNew(store, name, toggle, line)
    name = Text(name)
    if not name then
        return
    end
    local fresh = Remember(store, name)
    if not live or not fresh or not On(toggle) then
        return
    end
    Say(line .. ": " .. name .. ".")
end

local function ScanCompanionKind(kind, store, toggle, line)
    if not GetNumCompanions or not GetCompanionInfo then
        return
    end
    local ok, count = pcall(GetNumCompanions, kind)
    count = ok and Num(count) or nil
    if not count or count < 1 then
        return
    end
    local i
    for i = 1, count do
        local infoOk, _, name = pcall(GetCompanionInfo, kind, i)
        if infoOk then
            AnnounceNew(store, name, toggle, line)
        end
    end
end

local function ScanMounts()
    if C_MountJournal and C_MountJournal.GetNumMounts and C_MountJournal.GetMountInfo then
        local ok, count = pcall(C_MountJournal.GetNumMounts)
        count = ok and Num(count) or nil
        if count and count > 0 then
            local i
            for i = 1, count do
                local infoOk, name, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfo, i)
                if infoOk and Flag(collected) == true then
                    AnnounceNew(knownMounts, name, "chatMount", "Mount added")
                end
            end
            return
        end
    end
    ScanCompanionKind("MOUNT", knownMounts, "chatMount", "Mount added")
end

local function ScanCompanions()
    ScanCompanionKind("CRITTER", knownCompanions, "chatCompanion", "Companion added")
end

local function ScanPets()
    if not C_PetJournal or not C_PetJournal.GetNumPets or not C_PetJournal.GetPetInfoByIndex then
        return
    end
    local ok, _, owned = pcall(C_PetJournal.GetNumPets)
    owned = ok and Num(owned) or nil
    if not owned or owned < 1 then
        return
    end
    local i
    for i = 1, owned do
        local infoOk, _, _, _, _, _, _, _, name = pcall(C_PetJournal.GetPetInfoByIndex, i)
        if infoOk then
            AnnounceNew(knownPets, name, "chatBattlePet", "Battle pet added")
        end
    end
end

local function ScanHeirlooms()
    if not C_Heirloom or not C_Heirloom.GetHeirloomItemIDs then
        return
    end
    local ok, ids = pcall(C_Heirloom.GetHeirloomItemIDs)
    if not ok or type(ids) ~= "table" then
        return
    end
    local i
    for i = 1, #ids do
        local id = Num(ids[i])
        if id and C_Heirloom.PlayerHasHeirloom then
            local hasOk, has = pcall(C_Heirloom.PlayerHasHeirloom, id)
            if hasOk and Flag(has) == true then
                local name = ItemName(id)
                if not name and C_Heirloom.GetHeirloomInfo then
                    local infoOk, heirName = pcall(C_Heirloom.GetHeirloomInfo, id)
                    if infoOk then
                        name = Text(heirName)
                    end
                end
                local fresh = Remember(knownHeirlooms, name)
                if live and fresh and On("chatHeirloom") and name then
                    Say("Heirloom added: " .. name .. ".")
                end
            end
        end
    end
end

local function HandleMountAdded(mountID)
    local name
    mountID = Num(mountID)
    if mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
        local ok, mountName = pcall(C_MountJournal.GetMountInfoByID, mountID)
        if ok then
            name = Text(mountName)
        end
    end
    if name then
        AnnounceNew(knownMounts, name, "chatMount", "Mount added")
    else
        ScanMounts()
    end
end

local function HandlePetAdded(petID)
    local name
    if petID ~= nil and C_PetJournal and C_PetJournal.GetPetInfoByPetID then
        local ok, _, _, _, _, _, _, _, petName = pcall(C_PetJournal.GetPetInfoByPetID, petID)
        if ok then
            name = Text(petName)
        end
    end
    if name then
        AnnounceNew(knownPets, name, "chatBattlePet", "Battle pet added")
    else
        ScanPets()
    end
end

local function HandleToy(itemID)
    if not live or not On("chatToy") then
        return
    end
    local name = ItemName(itemID)
    if not name and itemID ~= nil and C_ToyBox and C_ToyBox.GetToyInfo then
        local ok, _, toyName = pcall(C_ToyBox.GetToyInfo, itemID)
        if ok then
            name = Text(toyName)
        end
    end
    name = Text(name)
    if not name then
        return
    end
    if not Claim("toy:" .. string.lower(name)) then
        return
    end
    Say("Toy added: " .. name .. ".")
end

local function HandleTransmog(sourceID)
    if not live or not On("chatTransmog") then
        return
    end
    sourceID = Num(sourceID)
    if not sourceID or not C_TransmogCollection or not C_TransmogCollection.GetSourceInfo then
        return
    end
    local ok, info = pcall(C_TransmogCollection.GetSourceInfo, sourceID)
    if not ok or type(info) ~= "table" then
        return
    end
    local name = Text(info.name)
    if not name then
        name = ItemName(info.itemID)
    end
    name = Text(name)
    if not name then
        return
    end
    if not Claim("mog:" .. string.lower(name)) then
        return
    end
    Say("Transmog added: " .. name .. ".")
end

local function Seed()
    if seeded then
        return
    end
    seeded = true
    live = false
    seedGen = seedGen + 1
    local gen = seedGen
    local function finish()
        if gen ~= seedGen then
            return
        end
        ScanMounts()
        ScanCompanions()
        ScanPets()
        ScanHeirlooms()
        live = true
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(2, finish)
    else
        finish()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_LOG_UPDATE")
local function TryEvent(name)
    pcall(frame.RegisterEvent, frame, name)
end
TryEvent("QUEST_WATCH_UPDATE")
TryEvent("CRITERIA_UPDATE")
TryEvent("NEW_MOUNT_ADDED")
TryEvent("NEW_PET_ADDED")
TryEvent("NEW_TOY_ADDED")
TryEvent("COMPANION_LEARNED")
TryEvent("TRANSMOG_COLLECTION_SOURCE_ADDED")
TryEvent("HEIRLOOMS_UPDATED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Seed()
        return
    end
    if event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE" then
        if live and On("chatQuestProgress") then
            questDirty = true
            watchDirty = true
        end
        return
    end
    if event == "CRITERIA_UPDATE" then
        if live and On("chatAchievementProgress") then
            achDirty = true
            achTrackedPending = true
            achSerial = achSerial + 1
        end
        return
    end
    if event == "NEW_MOUNT_ADDED" then
        HandleMountAdded(...)
        return
    end
    if event == "NEW_PET_ADDED" then
        HandlePetAdded(...)
        return
    end
    if event == "NEW_TOY_ADDED" then
        HandleToy(...)
        return
    end
    if event == "COMPANION_LEARNED" then
        ScanMounts()
        ScanCompanions()
        return
    end
    if event == "TRANSMOG_COLLECTION_SOURCE_ADDED" then
        HandleTransmog(...)
        return
    end
    if event == "HEIRLOOMS_UPDATED" then
        ScanHeirlooms()
    end
end)

local pulse = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    if not live then
        return
    end
    pulse = pulse + (elapsed or 0)
    if pulse < 0.5 then
        return
    end
    pulse = 0
    if On("chatQuestProgress") then
        if questQuiet then
            questDirty = true
            questCursor = 1
            questQuiet = false
        end
        if watchDirty then
            ScanWatchedNow()
            watchDirty = false
        end
        if questDirty then
            if StepQuests() then
                questDirty = false
            end
        end
    else
        questCursor = 1
        questDirty = false
        watchDirty = false
        questQuiet = true
    end
    if not On("chatAchievementProgress") then
        achPrimed = false
        achDirty = false
        achTrackedPending = false
        achCatIndex = 1
        achInCat = 1
        return
    end
    if not achPrimed then
        if ScanTracked(true) then
            achPrimed = true
            achDirty = true
            achCatIndex = 1
            achInCat = 1
            achMark = achSerial
        end
    end
    if achTrackedPending then
        if ScanTracked(false) then
            achTrackedPending = false
        end
    end
    if achDirty then
        if achCatIndex == 1 and achInCat == 1 then
            achMark = achSerial
        end
        if StepAchievements() then
            if achSerial ~= achMark then
                achDirty = true
            else
                achDirty = false
            end
        end
    end
end)
