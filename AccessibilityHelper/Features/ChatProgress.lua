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
local knownMounts = {}
local knownCompanions = {}
local knownPets = {}
local knownHeirlooms = {}
local live = false
local seedGen = 0
local achDirty = false
local achWait = 0
local achPrimed = false

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

local function ScanQuestLog()
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
        local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)
        count = ok and Num(count) or nil
        if not count then
            return
        end
        local i
        for i = 1, count do
            local infoOk, info = pcall(C_QuestLog.GetInfo, i)
            if infoOk and type(info) == "table" and Flag(info.isHeader) ~= true then
                local questID = Num(info.questID)
                local title = Text(info.title)
                if questID then
                    local objOk, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
                    if objOk and type(objectives) == "table" then
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
                end
            end
        end
        return
    end
    if not GetNumQuestLogEntries or not GetQuestLogTitle or not GetNumQuestLeaderBoards or not GetQuestLogLeaderBoard then
        return
    end
    local ok, count = pcall(GetNumQuestLogEntries)
    count = ok and Num(count) or nil
    if not count then
        return
    end
    local i
    for i = 1, count do
        local titleOk, title, _, _, isHeader, _, _, _, questID = pcall(GetQuestLogTitle, i)
        if titleOk and Flag(isHeader) ~= true then
            local boardsOk, boards = pcall(GetNumQuestLeaderBoards, i)
            boards = boardsOk and Num(boards) or nil
            if boards and boards > 0 then
                local j
                for j = 1, boards do
                    local boardOk, text = pcall(GetQuestLogLeaderBoard, j, i)
                    if boardOk then
                        local label, cur, need = SplitObjective(text)
                        NoteQuest(questID, title, j, label, cur, need, text)
                    end
                end
            end
        end
    end
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
        return
    end
    id = Num(id)
    name = Text(name)
    if not id or not name then
        return
    end
    if AchievementComplete(id) then
        return
    end
    local numOk, n = pcall(GetAchievementNumCriteria, id)
    n = numOk and Num(n) or nil
    if not n or n < 1 then
        return
    end
    local finished = 0
    local i
    for i = 1, n do
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
            elseif n > 1 and finished < n then
                SpeakAchievementProgress(name, finished, n)
            end
        end
    end
end

local function ScanAchievements(silent)
    if GetCategoryList and GetCategoryNumAchievements and GetAchievementInfo then
        local ok, cats = pcall(GetCategoryList)
        if ok and type(cats) == "table" then
            local c
            for c = 1, #cats do
                local numOk, num = pcall(GetCategoryNumAchievements, cats[c])
                num = numOk and Num(num) or nil
                if num and num > 0 then
                    local i
                    for i = 1, num do
                        local infoOk, id, name, _, completed = pcall(GetAchievementInfo, cats[c], i)
                        id = infoOk and Num(id) or nil
                        name = infoOk and Text(name) or nil
                        if id and name and Flag(completed) ~= true then
                            ScanOneAchievement(id, name, silent)
                        end
                    end
                end
            end
            return
        end
    end
    if not GetTrackedAchievements then
        return
    end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(GetTrackedAchievements)
    if not ok then
        return
    end
    local ids = { a, b, c, d, e, f, g, h, i, j }
    local n
    for n = 1, #ids do
        local id = Num(ids[n])
        if id and GetAchievementInfo then
            local infoOk, _, name = pcall(GetAchievementInfo, id)
            ScanOneAchievement(id, infoOk and name or nil, silent)
        end
    end
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
    live = false
    seedGen = seedGen + 1
    local gen = seedGen
    achPrimed = false
    ScanQuestLog()
    ScanAchievements(true)
    ScanMounts()
    ScanCompanions()
    ScanPets()
    ScanHeirlooms()
    local function finish()
        if gen ~= seedGen then
            return
        end
        ScanQuestLog()
        ScanAchievements(true)
        ScanMounts()
        ScanCompanions()
        ScanPets()
        ScanHeirlooms()
        live = true
        achPrimed = On("chatAchievementProgress")
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
        ScanQuestLog()
        return
    end
    if event == "CRITERIA_UPDATE" then
        achDirty = true
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

frame:SetScript("OnUpdate", function(_, elapsed)
    local switchedOn = On("chatAchievementProgress")
    if switchedOn and not achPrimed and live then
        ScanAchievements(true)
        achPrimed = true
        achDirty = false
        return
    end
    if not switchedOn then
        achPrimed = false
    end
    if not achDirty then
        return
    end
    achWait = achWait + (elapsed or 0)
    if achWait < 0.3 then
        return
    end
    achWait = 0
    achDirty = false
    if live and switchedOn then
        ScanAchievements(false)
    end
end)
