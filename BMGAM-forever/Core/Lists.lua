local _, BMGAM = ...

BMGAM.Scan = BMGAM.Scan or {}
local Scan = BMGAM.Scan

local questQuiet = 0
local collectionQuiet = 0

local function Secret(value)
    if value == nil or type(issecretvalue) ~= "function" then
        return false
    end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

local function SafeText(value)
    if value == nil or Secret(value) then
        return nil
    end
    local ok, text = pcall(tostring, value)
    if not ok or Secret(text) or type(text) ~= "string" or text == "" or text == "nil" then
        return nil
    end
    return text
end

local function AsNumber(value)
    if value == nil or Secret(value) then
        return nil
    end
    local ok, number = pcall(tonumber, value)
    if ok and type(number) == "number" then
        return number
    end
    return nil
end

local function Flag(value)
    if value == nil or Secret(value) then
        return false
    end
    local ok, yes = pcall(function()
        return value == true or value == 1
    end)
    return ok and yes == true
end

local function Now()
    if type(GetTime) == "function" then
        local ok, value = pcall(GetTime)
        if ok and type(value) == "number" then
            return value
        end
    end
    return 0
end

local function PlayerRecord()
    if type(UnitGUID) ~= "function" or not BMGAM.DB or type(BMGAM.DB.Get) ~= "function" then
        return nil
    end
    local ok, guid = pcall(UnitGUID, "player")
    if not ok or type(guid) ~= "string" or guid == "" then
        return nil
    end
    return BMGAM.DB.Get(guid)
end

local function RefreshTab(tab)
    if BMGAM.Window and BMGAM.Window.tab == tab and BMGAM.Window.Refresh then
        pcall(BMGAM.Window.Refresh)
    end
end

local function IconValue(value)
    local number = AsNumber(value)
    if number and number > 0 then
        return number
    end
    return SafeText(value)
end

local function SameName(left, right)
    if not left or not right then
        return false
    end
    return string.lower(left) == string.lower(right)
end

do
    local function SkipTitle(name)
        if not name then
            return true
        end
        if name == "Tracking Quest" then
            return true
        end
        if string.sub(name, 1, 5) == "[DNT]" then
            return true
        end
        if string.match(name, "^Level %d+$") then
            return true
        end
        return false
    end

    local function QuestCount()
        if C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function" then
            local ok, count = pcall(C_QuestLog.GetNumQuestLogEntries)
            local number = ok and AsNumber(count) or nil
            if number then
                return number
            end
        end
        if type(GetNumQuestLogEntries) == "function" then
            local ok, count = pcall(GetNumQuestLogEntries)
            return ok and AsNumber(count) or 0
        end
        return 0
    end

    local function QuestInfo(index)
        if C_QuestLog and type(C_QuestLog.GetInfo) == "function" then
            local ok, info = pcall(C_QuestLog.GetInfo, index)
            if ok and type(info) == "table" then
                return info
            end
        end
        if type(GetQuestLogTitle) ~= "function" then
            return nil
        end
        local ok, title, level, _, isHeader, isCollapsed, _, _, questID = pcall(GetQuestLogTitle, index)
        if not ok then
            return nil
        end
        return {
            title = title,
            level = level,
            isHeader = isHeader,
            isCollapsed = isCollapsed,
            questID = questID,
        }
    end

    local function SetHeader(index, collapsed)
        if collapsed then
            if type(CollapseQuestHeader) == "function" then
                pcall(CollapseQuestHeader, index)
                return
            end
        elseif type(ExpandQuestHeader) == "function" then
            pcall(ExpandQuestHeader, index)
            return
        end
        if C_QuestLog and type(C_QuestLog.SetCollapsed) == "function" then
            pcall(C_QuestLog.SetCollapsed, index, collapsed and true or false)
        end
    end

    local function ExpandClosed()
        local closed = {}
        local guard = 0
        while guard < 40 do
            local count = QuestCount()
            local index = 1
            local found = false
            while index <= count do
                local info = QuestInfo(index)
                if info and Flag(info.isHeader) and Flag(info.isCollapsed) then
                    local title = SafeText(info.title)
                    if title then
                        closed[#closed + 1] = title
                    end
                    SetHeader(index, false)
                    found = true
                    break
                end
                index = index + 1
            end
            if not found then
                break
            end
            guard = guard + 1
        end
        return closed
    end

    local function RestoreClosed(closed)
        local index = #closed
        while index >= 1 do
            local want = closed[index]
            local count = QuestCount()
            local row = count
            while row >= 1 do
                local info = QuestInfo(row)
                if info and Flag(info.isHeader) and SafeText(info.title) == want and not Flag(info.isCollapsed) then
                    SetHeader(row, true)
                    break
                end
                row = row - 1
            end
            index = index - 1
        end
    end

    local function MapID(questID)
        if not questID then
            return nil
        end
        if C_QuestLog and type(C_QuestLog.GetQuestUiMapID) == "function" then
            local ok, id = pcall(C_QuestLog.GetQuestUiMapID, questID)
            local number = ok and AsNumber(id) or nil
            if number and number > 0 then
                return number
            end
        end
        if C_QuestLog and type(C_QuestLog.GetMapForQuest) == "function" then
            local ok, id = pcall(C_QuestLog.GetMapForQuest, questID)
            local number = ok and AsNumber(id) or nil
            if number and number > 0 then
                return number
            end
        end
        return nil
    end

    local function QuestPlace(questID)
        local mapID = MapID(questID)
        if not mapID or not C_Map or type(C_Map.GetMapInfo) ~= "function" then
            return nil, nil, nil
        end
        local chain = {}
        local guard = 0
        local current = mapID
        while current and current > 0 and guard < 8 do
            local ok, info = pcall(C_Map.GetMapInfo, current)
            if not ok or type(info) ~= "table" then
                break
            end
            chain[#chain + 1] = info
            local parent = AsNumber(info.parentMapID)
            if not parent or parent <= 0 or parent == current then
                break
            end
            current = parent
            guard = guard + 1
        end
        local zone, content, world = nil, nil, nil
        local index = 1
        while chain[index] do
            local info = chain[index]
            local name = SafeText(info.name)
            local kind = AsNumber(info.mapType)
            if name then
                if kind == 3 and not zone then
                    zone = name
                elseif kind == 2 and not content then
                    content = name
                elseif kind == 1 and not world then
                    world = name
                end
            end
            index = index + 1
        end
        if not zone and chain[1] then
            zone = SafeText(chain[1].name)
        end
        if content == zone then
            content = nil
        end
        if world == zone or world == content then
            world = nil
        end
        return world, content, zone
    end

    local function QuestTitle(questID)
        if C_QuestLog and type(C_QuestLog.GetTitleForQuestID) == "function" then
            local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
            local text = ok and SafeText(title) or nil
            if text then
                return text
            end
        end
        if C_QuestLog and type(C_QuestLog.GetQuestInfo) == "function" then
            local ok, title = pcall(C_QuestLog.GetQuestInfo, questID)
            if ok and type(title) == "table" then
                return SafeText(title.title or title.name)
            end
            return ok and SafeText(title) or nil
        end
        return nil
    end

    local function QuestLevel(questID, fallback)
        local level = AsNumber(fallback)
        if level and level > 0 then
            return level
        end
        if C_QuestLog and type(C_QuestLog.GetQuestDifficultyLevel) == "function" then
            local ok, value = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
            level = ok and AsNumber(value) or nil
            if level and level > 0 then
                return level
            end
        end
        return nil
    end

    local function QuestActivity(questID)
        if not questID then
            return nil
        end
        if C_QuestLog and type(C_QuestLog.GetQuestTagInfo) == "function" then
            local ok, info, name = pcall(C_QuestLog.GetQuestTagInfo, questID)
            if ok and type(info) == "table" then
                return SafeText(info.tagName)
            end
            if ok then
                return SafeText(name) or SafeText(info)
            end
        end
        if type(GetQuestTagInfo) == "function" then
            local ok, _, name = pcall(GetQuestTagInfo, questID)
            if ok then
                return SafeText(name)
            end
        end
        return nil
    end

    local function OnAccount(questID)
        if not questID or not C_QuestLog or type(C_QuestLog.IsQuestFlaggedCompletedOnAccount) ~= "function" then
            return false
        end
        local ok, flagged = pcall(C_QuestLog.IsQuestFlaggedCompletedOnAccount, questID)
        return ok and Flag(flagged)
    end

    local function AddQuest(list, seen, questID, name, level, headerZone)
        if SkipTitle(name) then
            return
        end
        if questID and seen[questID] then
            return
        end
        if questID then
            seen[questID] = true
        end
        local row = { name = name }
        if questID then
            row.id = questID
        end
        local questLevel = QuestLevel(questID, level)
        if questLevel then
            row.level = questLevel
        end
        local activity = QuestActivity(questID)
        if activity then
            row.activity = activity
        end
        local world, content, zone = QuestPlace(questID)
        if not zone then
            zone = headerZone
        end
        if world then
            row.world = world
        end
        if content then
            row.content = content
        end
        if zone then
            row.zone = zone
        end
        if OnAccount(questID) then
            row.account = true
        end
        list[#list + 1] = row
    end

    local function ReadCurrent()
        local list = {}
        local seen = {}
        local header = nil
        local count = QuestCount()
        local index = 1
        while index <= count do
            local info = QuestInfo(index)
            if info then
                local title = SafeText(info.title)
                if Flag(info.isHeader) then
                    header = title
                else
                    AddQuest(list, seen, AsNumber(info.questID), title, info.level, header)
                end
            end
            index = index + 1
        end
        return list
    end

    local function CompletedIDs()
        if C_QuestLog and type(C_QuestLog.GetAllCompletedQuestIDs) == "function" then
            local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
            if ok and type(ids) == "table" then
                return ids, true
            end
        end
        if type(GetQuestsCompleted) ~= "function" then
            return nil, false
        end
        local ok, map = pcall(GetQuestsCompleted)
        if not ok or type(map) ~= "table" then
            return nil, false
        end
        local ids = {}
        local id, done = next(map)
        while id do
            if done and type(id) == "number" then
                ids[#ids + 1] = id
            end
            id, done = next(map, id)
        end
        return ids, true
    end

    local function ReadCompleted()
        local ids, ready = CompletedIDs()
        if not ready or type(ids) ~= "table" then
            return nil, false
        end
        local list = {}
        local seen = {}
        local index = 1
        while ids[index] do
            local questID = AsNumber(ids[index])
            if questID then
                AddQuest(list, seen, questID, QuestTitle(questID), nil, nil)
            end
            index = index + 1
        end
        return list, true
    end

    function Scan.ReadQuests(full)
        local now = Now()
        if now < questQuiet then
            return
        end
        questQuiet = now + 1.5
        local record = PlayerRecord()
        if not record then
            return
        end
        local closed = ExpandClosed()
        local current = ReadCurrent()
        local completed, ready = nil, false
        if full == true or type(record.quests) ~= "table" or record.quests.completedReady ~= true then
            completed, ready = ReadCompleted()
        end
        RestoreClosed(closed)
        local pack = record.quests
        if type(pack) ~= "table" then
            pack = {}
            record.quests = pack
        end
        pack.current = current
        pack.scanned = true
        if ready then
            pack.completed = completed
            pack.completedReady = true
        end
        RefreshTab("quests")
    end
end

do
    local function CategoryName(categoryID)
        if type(GetCategoryInfo) ~= "function" then
            return nil, nil
        end
        local ok, name, parent = pcall(GetCategoryInfo, categoryID)
        if not ok then
            return nil, nil
        end
        if type(name) == "table" then
            return SafeText(name.name or name.title), AsNumber(name.parentCategoryID or name.parent)
        end
        return SafeText(name), AsNumber(parent)
    end

    local function Statistic(flags, marked)
        if Flag(marked) then
            return true
        end
        local number = AsNumber(flags)
        if not number or not bit or type(bit.band) ~= "function" then
            return false
        end
        local ok, banded = pcall(bit.band, number, 1)
        return ok and banded ~= 0
    end

    local function AccountWide(flags)
        local number = AsNumber(flags)
        if not number or not bit or type(bit.band) ~= "function" then
            return false
        end
        local ok, banded = pcall(bit.band, number, 131072)
        return ok and banded ~= 0
    end

    local function AchievementAt(category, index)
        if type(GetAchievementInfo) ~= "function" then
            return nil
        end
        local ok, id, name, points, completed, month, day, year, description, flags, _, _, _, wasMe, earnedBy, isStatistic = pcall(GetAchievementInfo, category, index)
        if not ok then
            return nil
        end
        if type(id) == "table" then
            return id
        end
        return {
            id = id,
            name = name,
            points = points,
            completed = completed,
            month = month,
            day = day,
            year = year,
            description = description,
            flags = flags,
            wasEarnedByMe = wasMe,
            earnedBy = earnedBy,
            isStatistic = isStatistic,
        }
    end

    local function Requirements(achID)
        if type(GetAchievementNumCriteria) ~= "function" or type(GetAchievementCriteriaInfo) ~= "function" then
            return nil, nil
        end
        local countOk, count = pcall(GetAchievementNumCriteria, achID)
        count = countOk and AsNumber(count) or 0
        if not count or count < 1 then
            return nil, nil
        end
        local needs = {}
        local done = 0
        local progress = nil
        local index = 1
        while index <= count do
            local infoOk, description, kind, completed, have, required, _, _, asset, quantity = pcall(GetAchievementCriteriaInfo, achID, index)
            if infoOk then
                local entry = { name = SafeText(description) or "" }
                if Flag(completed) then
                    entry.done = true
                    done = done + 1
                end
                local left = SafeText(quantity)
                local haveN = AsNumber(have)
                local needN = AsNumber(required)
                if not left and haveN and needN and needN > 1 then
                    left = tostring(haveN) .. "/" .. tostring(needN)
                end
                if left and not entry.done then
                    entry.left = left
                end
                if AsNumber(kind) == 8 then
                    local other = AsNumber(asset)
                    if other then
                        entry.achievement = other
                    end
                end
                needs[#needs + 1] = entry
                if count == 1 and needN and needN > 1 and left then
                    progress = left
                end
            end
            index = index + 1
        end
        if not progress then
            progress = tostring(done) .. "/" .. tostring(count)
        end
        if not needs[1] then
            needs = nil
        end
        return progress, needs
    end

    local function AttachSeries(rows)
        if type(GetPreviousAchievement) ~= "function" then
            return
        end
        local byId = {}
        local index = 1
        while rows[index] do
            local row = rows[index]
            if type(row.id) == "number" then
                byId[row.id] = row
            end
            index = index + 1
        end
        index = 1
        while rows[index] do
            local row = rows[index]
            if row.id and not row.series then
                local root = row.id
                local guard = 0
                while guard < 24 do
                    local ok, prev = pcall(GetPreviousAchievement, root)
                    prev = ok and AsNumber(prev) or nil
                    if not prev or prev <= 0 or prev == root then
                        break
                    end
                    root = prev
                    guard = guard + 1
                end
                local step = 1
                local current = root
                guard = 0
                while current and guard < 24 do
                    local other = byId[current]
                    if other and not other.series then
                        other.series = root
                        other.step = step
                        step = step + 1
                    end
                    if type(GetNextAchievement) ~= "function" then
                        break
                    end
                    local ok, nxt = pcall(GetNextAchievement, current)
                    nxt = ok and AsNumber(nxt) or nil
                    if not nxt or nxt <= 0 or nxt == current then
                        break
                    end
                    current = nxt
                    guard = guard + 1
                end
            end
            index = index + 1
        end
    end

    function Scan.ReadAchievements()
        if type(GetCategoryList) ~= "function" or type(GetCategoryInfo) ~= "function" or type(GetAchievementInfo) ~= "function" then
            return
        end
        local record = PlayerRecord()
        if not record then
            return
        end
        local listed, list = pcall(GetCategoryList)
        if not listed or type(list) ~= "table" then
            return
        end
        local stats = {}
        local categories = {}
        local index = 1
        while list[index] do
            local categoryID = AsNumber(list[index])
            local name, parent = CategoryName(categoryID)
            if categoryID and name then
                if name == "Statistics" or (parent and stats[parent]) then
                    stats[categoryID] = true
                else
                    local row = { id = categoryID, name = name, order = index }
                    if parent and parent > 0 then
                        row.parent = parent
                    end
                    categories[#categories + 1] = row
                end
            end
            index = index + 1
        end
        local changed = true
        while changed do
            changed = false
            local kept = {}
            index = 1
            while categories[index] do
                local cat = categories[index]
                if stats[cat.id] or (cat.parent and stats[cat.parent]) then
                    stats[cat.id] = true
                    changed = true
                else
                    kept[#kept + 1] = cat
                end
                index = index + 1
            end
            categories = kept
        end
        local rows = {}
        local seen = {}
        local player = SafeText(UnitName("player"))
        index = 1
        while categories[index] do
            local categoryID = categories[index].id
            local count = 0
            if type(GetCategoryNumAchievements) == "function" then
                local countOk, total = pcall(GetCategoryNumAchievements, categoryID)
                count = countOk and AsNumber(total) or 0
            end
            local step = 1
            while count and step <= count do
                local info = AchievementAt(categoryID, step)
                local achID = info and AsNumber(info.id or info.achievementID) or nil
                local name = info and SafeText(info.name) or nil
                if achID and name and not seen[achID] and not Statistic(info.flags, info.isStatistic) then
                    seen[achID] = true
                    local row = {
                        id = achID,
                        name = name,
                        category = categoryID,
                        points = AsNumber(info.points) or 0,
                    }
                    local detail = SafeText(info.description)
                    if detail and detail ~= name then
                        row.detail = detail
                    end
                    local progress, needs = Requirements(achID)
                    if needs then
                        row.needs = needs
                    end
                    if Flag(info.completed) then
                        row.earned = true
                        local month = AsNumber(info.month)
                        local day = AsNumber(info.day)
                        local year = AsNumber(info.year)
                        if month and day and year and month >= 1 and month <= 12 and day >= 1 and day <= 31 then
                            if year < 100 then
                                year = year + 2000
                            end
                            row.month = month
                            row.day = day
                            row.year = year
                        end
                        local named = SafeText(info.earnedBy)
                        if named and not SameName(named, player) then
                            row.who = named
                        elseif AccountWide(info.flags) then
                            row.who = "Account Wide"
                        else
                            row.who = player
                        end
                    elseif progress then
                        row.progress = progress
                    end
                    rows[#rows + 1] = row
                end
                step = step + 1
            end
            index = index + 1
        end
        AttachSeries(rows)
        record.achievements = {
            scanned = true,
            categories = categories,
            rows = rows,
        }
        RefreshTab("achievements")
    end
end

do
    local function Add(items, row)
        if type(row) ~= "table" or type(row.type) ~= "string" or type(row.name) ~= "string" or row.name == "" then
            return false
        end
        row.collected = row.collected == true
        items[#items + 1] = row
        return true
    end

    local function ItemQuality(itemID)
        itemID = AsNumber(itemID)
        if not itemID or not C_Item or type(C_Item.GetItemQualityByID) ~= "function" then
            return nil
        end
        local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
        return ok and AsNumber(quality) or nil
    end

    local function ReadMounts(items)
        local journal = C_MountJournal
        if journal and type(journal.GetMountIDs) == "function" and type(journal.GetMountInfoByID) == "function" then
            local ok, ids = pcall(journal.GetMountIDs)
            if ok and type(ids) == "table" then
                local any = false
                local index = 1
                while ids[index] do
                    local mountID = AsNumber(ids[index])
                    if mountID then
                        local infoOk, name, spellID, icon, _, _, _, _, _, _, hide, collected = pcall(journal.GetMountInfoByID, mountID)
                        name = infoOk and SafeText(name) or nil
                        if name and not Flag(hide) then
                            local source = ""
                            if type(journal.GetMountInfoExtraByID) == "function" then
                                local extraOk, _, _, extraSource = pcall(journal.GetMountInfoExtraByID, mountID)
                                if extraOk then
                                    source = SafeText(extraSource) or ""
                                end
                            end
                            if Add(items, {
                                type = "mount",
                                id = mountID,
                                name = name,
                                icon = infoOk and IconValue(icon) or nil,
                                spellID = infoOk and AsNumber(spellID) or nil,
                                collected = Flag(collected),
                                source = source,
                            }) then
                                any = true
                            end
                        end
                    end
                    index = index + 1
                end
                return any
            end
        end
        if type(GetNumCompanions) ~= "function" or type(GetCompanionInfo) ~= "function" then
            return false
        end
        local ok, count = pcall(GetNumCompanions, "MOUNT")
        count = ok and AsNumber(count) or 0
        local any = false
        local index = 1
        while count and index <= count do
            local infoOk, _, name, spellID, icon = pcall(GetCompanionInfo, "MOUNT", index)
            name = infoOk and SafeText(name) or nil
            if name and Add(items, {
                type = "mount",
                id = AsNumber(spellID) or index,
                name = name,
                icon = IconValue(icon),
                spellID = AsNumber(spellID),
                collected = true,
                source = "",
            }) then
                any = true
            end
            index = index + 1
        end
        return any
    end

    local function ReadPets(items)
        local journal = C_PetJournal
        if not journal or type(journal.GetNumPets) ~= "function" or type(journal.GetPetInfoByIndex) ~= "function" then
            return false
        end
        local saved = {}
        local collectedFilter = LE_PET_JOURNAL_FILTER_COLLECTED or 1
        local missingFilter = LE_PET_JOURNAL_FILTER_NOT_COLLECTED or 2
        if type(journal.IsFilterChecked) == "function" and type(journal.SetFilterChecked) == "function" then
            local ownedOk, owned = pcall(journal.IsFilterChecked, collectedFilter)
            local missingOk, missing = pcall(journal.IsFilterChecked, missingFilter)
            if ownedOk then
                saved.owned = owned
            end
            if missingOk then
                saved.missing = missing
            end
            pcall(journal.SetFilterChecked, collectedFilter, true)
            pcall(journal.SetFilterChecked, missingFilter, true)
        end
        local countOk, count = pcall(journal.GetNumPets)
        count = countOk and AsNumber(count) or 0
        local any = false
        local seen = {}
        local index = 1
        while count and index <= count do
            local infoOk, _, speciesID, owned, _, _, _, seventh, eighth, ninth = pcall(journal.GetPetInfoByIndex, index)
            speciesID = infoOk and AsNumber(speciesID) or nil
            local name, icon = nil, nil
            if infoOk and type(eighth) == "string" then
                name = SafeText(eighth)
                icon = IconValue(ninth)
            elseif infoOk and type(seventh) == "string" then
                name = SafeText(seventh)
                icon = IconValue(eighth)
            end
            local source = ""
            if speciesID and type(journal.GetPetInfoBySpeciesID) == "function" then
                local sourceOk, _, _, _, _, sourceText = pcall(journal.GetPetInfoBySpeciesID, speciesID)
                if sourceOk then
                    source = SafeText(sourceText) or ""
                end
            end
            if name and speciesID then
                local prior = seen[speciesID]
                if prior then
                    if Flag(owned) then
                        prior.collected = true
                    end
                elseif Add(items, {
                    type = "pet",
                    id = speciesID,
                    name = name,
                    icon = icon,
                    collected = Flag(owned),
                    source = source,
                }) then
                    seen[speciesID] = items[#items]
                    any = true
                end
            end
            index = index + 1
        end
        if type(journal.SetFilterChecked) == "function" then
            if saved.owned ~= nil then
                pcall(journal.SetFilterChecked, collectedFilter, saved.owned)
            end
            if saved.missing ~= nil then
                pcall(journal.SetFilterChecked, missingFilter, saved.missing)
            end
        end
        return any
    end

    local function ReadToys(items)
        local box = C_ToyBox
        if not box or type(box.GetNumToys) ~= "function" then
            return false
        end
        local saved = {}
        if type(box.GetCollectedShown) == "function" and type(box.SetCollectedShown) == "function" then
            local ok, value = pcall(box.GetCollectedShown)
            if ok then
                saved.collected = value
            end
            pcall(box.SetCollectedShown, true)
        end
        if type(box.GetUncollectedShown) == "function" and type(box.SetUncollectedShown) == "function" then
            local ok, value = pcall(box.GetUncollectedShown)
            if ok then
                saved.missing = value
            end
            pcall(box.SetUncollectedShown, true)
        end
        local countOk, count = pcall(box.GetNumToys)
        count = countOk and AsNumber(count) or 0
        local any = false
        local index = 1
        while count and index <= count do
            local itemID = nil
            if type(box.GetToyFromIndex) == "function" then
                local idOk, id = pcall(box.GetToyFromIndex, index)
                itemID = idOk and AsNumber(id) or nil
            end
            local name, icon, quality, collected = nil, nil, nil, false
            if itemID and type(box.GetToyInfo) == "function" then
                local infoOk, _, toyName, toyIcon, _, _, toyQuality = pcall(box.GetToyInfo, itemID)
                if infoOk then
                    name = SafeText(toyName)
                    icon = IconValue(toyIcon)
                    quality = AsNumber(toyQuality)
                end
            end
            if itemID and type(PlayerHasToy) == "function" then
                local ownedOk, owned = pcall(PlayerHasToy, itemID)
                collected = ownedOk and Flag(owned)
            end
            if name and Add(items, {
                type = "toy",
                id = itemID or index,
                name = name,
                icon = icon,
                itemID = itemID,
                quality = quality or ItemQuality(itemID),
                collected = collected,
                source = "",
            }) then
                any = true
            end
            index = index + 1
        end
        if saved.collected ~= nil and type(box.SetCollectedShown) == "function" then
            pcall(box.SetCollectedShown, saved.collected)
        end
        if saved.missing ~= nil and type(box.SetUncollectedShown) == "function" then
            pcall(box.SetUncollectedShown, saved.missing)
        end
        return any
    end

    local function ReadHeirlooms(items)
        local api = C_Heirloom
        if not api or type(api.GetHeirloomItemIDs) ~= "function" then
            return false
        end
        local ok, ids = pcall(api.GetHeirloomItemIDs)
        if not ok or type(ids) ~= "table" then
            return false
        end
        local any = false
        local index = 1
        while ids[index] do
            local itemID = AsNumber(ids[index])
            if itemID and type(api.GetHeirloomInfo) == "function" then
                local infoOk, name, _, _, icon, _, source = pcall(api.GetHeirloomInfo, itemID)
                name = infoOk and SafeText(name) or nil
                local collected = false
                if type(api.PlayerHasHeirloom) == "function" then
                    local ownedOk, owned = pcall(api.PlayerHasHeirloom, itemID)
                    collected = ownedOk and Flag(owned)
                end
                if name and Add(items, {
                    type = "heirloom",
                    id = itemID,
                    name = name,
                    icon = infoOk and IconValue(icon) or nil,
                    itemID = itemID,
                    quality = ItemQuality(itemID),
                    collected = collected,
                    source = infoOk and SafeText(source) or "",
                }) then
                    any = true
                end
            end
            index = index + 1
        end
        return any
    end

    local function SourceDetails(entry, category)
        local api = C_TransmogCollection
        if not api then
            return nil, nil, nil, nil
        end
        local sourceID = AsNumber(entry.sourceID)
        if not sourceID and type(entry.visualID) == "number" and type(api.GetAppearanceSources) == "function" then
            local ok, sources = pcall(api.GetAppearanceSources, entry.visualID, category or entry.categoryID)
            if (not ok or type(sources) ~= "table") then
                ok, sources = pcall(api.GetAppearanceSources, entry.visualID)
            end
            if ok and type(sources) == "table" and type(sources[1]) == "table" then
                return SafeText(sources[1].name), AsNumber(sources[1].itemID), IconValue(sources[1].icon), AsNumber(sources[1].quality)
            end
            if ok and type(sources) == "table" then
                sourceID = AsNumber(sources[1] and (sources[1].sourceID or sources[1]))
            end
        end
        if not sourceID and type(entry.visualID) == "number" and type(api.GetAllAppearanceSources) == "function" then
            local ok, sources = pcall(api.GetAllAppearanceSources, entry.visualID)
            if ok and type(sources) == "table" then
                sourceID = AsNumber(sources[1])
            end
        end
        if not sourceID then
            return nil, nil, nil, nil
        end
        local info = nil
        if type(api.GetSourceInfo) == "function" then
            local ok, value = pcall(api.GetSourceInfo, sourceID)
            if ok and type(value) == "table" then
                info = value
            end
        end
        if not info and type(api.GetAppearanceSourceInfo) == "function" then
            local ok, category, itemID, name, quality, icon = pcall(api.GetAppearanceSourceInfo, sourceID)
            if ok and type(category) == "table" then
                info = category
            elseif ok then
                return SafeText(name), AsNumber(itemID), IconValue(icon), AsNumber(quality)
            end
        end
        if not info then
            return nil, nil, nil, nil
        end
        return SafeText(info.name), AsNumber(info.itemID), IconValue(info.icon), AsNumber(info.quality)
    end

    local function CategoryTitle(category)
        local api = C_TransmogCollection
        if not api or type(api.GetCategoryInfo) ~= "function" then
            return nil
        end
        local ok, info = pcall(api.GetCategoryInfo, category)
        if ok and type(info) == "table" then
            return SafeText(info.name)
        end
        if ok and type(info) == "string" then
            return SafeText(info)
        end
        return nil
    end

    local function ReadTransmog(items)
        local api = C_TransmogCollection
        if not api or type(api.GetCategoryAppearances) ~= "function" then
            return false
        end
        local categories = {}
        local enum = Enum and Enum.TransmogCollectionType
        if type(enum) == "table" then
            local key, value = next(enum)
            while key do
                if type(value) == "number" and value > 0 then
                    categories[#categories + 1] = value
                end
                key, value = next(enum, key)
            end
        end
        if not categories[1] then
            local category = 1
            while category <= 12 do
                categories[#categories + 1] = category
                category = category + 1
            end
        end
        local any = false
        local named = 0
        local missed = 0
        local catIndex = 1
        while categories[catIndex] do
            local category = categories[catIndex]
            local ok, list = pcall(api.GetCategoryAppearances, category)
            if not ok or type(list) ~= "table" then
                ok, list = pcall(api.GetCategoryAppearances, category, 0)
            end
            if ok and type(list) == "table" and list[1] then
                local section = CategoryTitle(category)
                local index = 1
                while list[index] do
                    local entry = list[index]
                    if type(entry) == "number" then
                        entry = { visualID = entry }
                    end
                    if type(entry) == "table" then
                        local name = SafeText(entry.name)
                        local itemID = AsNumber(entry.itemID)
                        local icon = IconValue(entry.icon)
                        local quality = AsNumber(entry.quality)
                        if not name then
                            local sourceName, sourceItem, sourceIcon, sourceQuality = SourceDetails(entry, category)
                            name = sourceName
                            itemID = itemID or sourceItem
                            icon = icon or sourceIcon
                            quality = quality or sourceQuality
                        end
                        if not name and itemID and C_Item and type(C_Item.GetItemNameByID) == "function" then
                            local nameOk, text = pcall(C_Item.GetItemNameByID, itemID)
                            name = nameOk and SafeText(text) or nil
                        end
                        if not icon and itemID and C_Item and type(C_Item.GetItemIconByID) == "function" then
                            local iconOk, texture = pcall(C_Item.GetItemIconByID, itemID)
                            icon = iconOk and IconValue(texture) or nil
                        end
                        if name then
                            named = named + 1
                            local visual = AsNumber(entry.visualID or entry.sourceID) or itemID or named
                            if Add(items, {
                                type = "transmog",
                                id = visual,
                                name = name,
                                icon = icon,
                                itemID = itemID,
                                quality = quality or ItemQuality(itemID),
                                collected = Flag(entry.isCollected),
                                section = section,
                                sectionOrder = category,
                                source = SafeText(entry.source) or "",
                            }) then
                                any = true
                            end
                        else
                            missed = missed + 1
                            if missed >= 40 and named == 0 then
                                return any
                            end
                        end
                    end
                    index = index + 1
                end
            end
            catIndex = catIndex + 1
        end
        return any
    end

    local function SetCollected(setID, row)
        if type(row) == "table" and (row.collected == true or row.collected == 1) then
            return true
        end
        local api = C_TransmogSets
        if api and type(api.IsBaseSetCollected) == "function" then
            local ok, owned = pcall(api.IsBaseSetCollected, setID)
            if ok then
                return Flag(owned)
            end
        end
        if api and type(api.GetBaseSetCollected) == "function" then
            local ok, owned = pcall(api.GetBaseSetCollected, setID)
            if ok then
                return Flag(owned)
            end
        end
        return false
    end

    local function ReadSets(items)
        local api = C_TransmogSets
        if not api then
            return false
        end
        local list = nil
        if type(api.GetBaseSets) == "function" then
            local ok, value = pcall(api.GetBaseSets)
            if ok and type(value) == "table" then
                list = value
            end
        end
        if not list and type(api.GetAllSets) == "function" then
            local ok, value = pcall(api.GetAllSets)
            if ok and type(value) == "table" then
                list = value
            end
        end
        if not list then
            return false
        end
        local any = false
        local index = 1
        while list[index] do
            local row = list[index]
            if type(row) == "table" then
                local setID = AsNumber(row.setID or row.baseSetID)
                local name = SafeText(row.name)
                if name and Add(items, {
                    type = "set",
                    id = setID or index,
                    name = name,
                    icon = IconValue(row.icon),
                    collected = SetCollected(setID, row),
                    source = SafeText(row.description or row.label) or "",
                }) then
                    any = true
                end
            end
            index = index + 1
        end
        return any
    end

    function Scan.ReadCollections()
        local now = Now()
        if now < collectionQuiet then
            return
        end
        collectionQuiet = now + 2
        local record = PlayerRecord()
        if not record then
            return
        end
        local items = {}
        ReadMounts(items)
        ReadPets(items)
        ReadToys(items)
        ReadHeirlooms(items)
        ReadTransmog(items)
        ReadSets(items)
        record.collections = {
            scanned = true,
            items = items,
        }
        RefreshTab("collections")
    end
end
