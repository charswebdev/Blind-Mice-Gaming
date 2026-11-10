local _, BMGAM = ...

BMGAM.Scan = BMGAM.Scan or {}
local Scan = BMGAM.Scan

local capturedThisLoad = false
local talentTries = 0
local talentWait = false
local gearTries = 0
local gearWait = false
local bagTries = 0
local bagWait = false
local bagEventWait = false
local professionListTries = 0
local professionListWait = false
local professionTries = 0
local professionWait = false
local currencyTries = 0
local currencyWait = false
local currencyScan = false
local currencyExpanded = false
local reputationTries = 0
local reputationWait = false
local reputationScan = false
local reputationReady = false

local function Round(value)
    local number = tonumber(value) or 0
    return math.floor(number + 0.5)
end

function Scan.Comma(value)
    local text = tostring(math.floor((tonumber(value) or 0) + 0.5))
    while true do
        local replaced
        text, replaced = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if replaced == 0 then
            break
        end
    end
    return text
end

local function SafeText(value)
    if value == nil then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(value) then
        if type(canaccessvalue) ~= "function" or not canaccessvalue(value) then
            return nil
        end
    end
    local ok, text = pcall(tostring, value)
    if not ok or type(text) ~= "string" or text == "" or text == "nil" then
        return nil
    end
    return text
end

local function AsNumber(value)
    if value == nil then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(value) then
        if type(canaccessvalue) ~= "function" or not canaccessvalue(value) then
            return nil
        end
    end
    local ok, number = pcall(tonumber, value)
    if ok and type(number) == "number" then
        return number
    end
    return nil
end

local function CallNumber(fn, ...)
    if type(fn) ~= "function" then
        return 0
    end
    local ok, value = pcall(fn, ...)
    if not ok then
        return 0
    end
    return AsNumber(value) or 0
end

local function ItemLevel()
    if type(GetAverageItemLevel) ~= "function" then
        return 0
    end
    local ok, _, equipped = pcall(GetAverageItemLevel)
    if not ok then
        return 0
    end
    return Round(equipped or 0)
end

local function ItemLevelQuality()
    local best = 1
    if type(GetInventoryItemQuality) ~= "function" then
        return best
    end
    local slot = 0
    while slot <= 19 do
        if slot ~= 4 then
            local ok, quality = pcall(GetInventoryItemQuality, "player", slot)
            quality = ok and AsNumber(quality) or nil
            if quality and quality > best then
                best = quality
            end
        end
        slot = slot + 1
    end
    return best
end

local function Stat(index)
    if type(UnitStat) ~= "function" then
        return 0
    end
    local ok, base, effective = pcall(UnitStat, "player", index)
    if not ok then
        return 0
    end
    local number = AsNumber(effective)
    if number and number > 0 then
        return number
    end
    return AsNumber(base) or 0
end

local function Armor()
    if type(UnitArmor) ~= "function" then
        return 0
    end
    local ok, base, effective = pcall(UnitArmor, "player")
    if not ok then
        return 0
    end
    local number = AsNumber(effective)
    if number and number > 0 then
        return number
    end
    return AsNumber(base) or 0
end

local function Versatility()
    local rating = CR_VERSATILITY_DAMAGE_DONE
    if not rating then
        return 0
    end
    return Round(CallNumber(GetCombatRatingBonus, rating) + CallNumber(GetVersatilityBonus, rating))
end

local function SpecFromAPI()
    if type(GetSpecialization) == "function" and type(GetSpecializationInfo) == "function" then
        local ok, index = pcall(GetSpecialization)
        if ok and index then
            local infoOk, _, name = pcall(GetSpecializationInfo, index)
            if infoOk then
                return SafeText(name)
            end
        end
    end
    return nil
end

local function AddName(names, value)
    local text = SafeText(value)
    if text then
        names[#names + 1] = text
    end
end

local function ClearNames(names)
    local index = #names
    while index > 0 do
        names[index] = nil
        index = index - 1
    end
end

local function SpecializationNames()
    local names = {}
    local classID = nil
    if PlayerUtil and PlayerUtil.GetClassID then
        local ok, id = pcall(PlayerUtil.GetClassID)
        if ok then
            classID = AsNumber(id)
        end
    end
    if not classID and type(UnitClass) == "function" then
        local ok, _, _, id = pcall(UnitClass, "player")
        if ok then
            classID = AsNumber(id)
        end
    end
    local getter = nil
    if type(GetSpecializationInfoForClassID) == "function" then
        getter = GetSpecializationInfoForClassID
    elseif C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID then
        getter = C_SpecializationInfo.GetSpecializationInfoForClassID
    end
    if classID and getter then
        local index = 1
        while index <= 3 do
            local packed = { pcall(getter, classID, index) }
            if packed[1] then
                if type(packed[2]) == "table" then
                    AddName(names, packed[2].name or packed[2].specName)
                else
                    AddName(names, packed[3])
                end
            end
            index = index + 1
        end
    end
    if names[3] then
        return names
    end
    ClearNames(names)
    if type(GetTalentTabInfo) == "function" then
        local index = 1
        while index <= 3 do
            local ok, name = pcall(GetTalentTabInfo, index)
            if ok then
                if type(name) == "table" then
                    AddName(names, name.name)
                else
                    AddName(names, name)
                end
            end
            index = index + 1
        end
    end
    return names
end

local function TalentFromTab(tab, index)
    if type(GetTalentInfo) ~= "function" then
        return nil
    end
    local ok, a, b, _, _, rank = pcall(GetTalentInfo, tab, index)
    if not ok then
        return nil
    end
    local name = nil
    local icon = nil
    local points = 0
    if type(a) == "table" then
        name = SafeText(a.name)
        icon = a.icon
        points = AsNumber(a.rank) or AsNumber(a.currentRank) or 0
    else
        name = SafeText(a)
        icon = b
        points = AsNumber(rank) or 0
    end
    if not name or points < 1 then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(icon) then
        icon = nil
    end
    return {
        name = name,
        icon = icon,
        rank = points,
        tab = tab,
        index = index,
        tree = "class",
    }
end

local function ClassicTalents()
    if type(GetNumTalentTabs) ~= "function" or type(GetTalentInfo) ~= "function" then
        return nil, nil
    end
    local ok, count = pcall(GetNumTalentTabs)
    count = ok and AsNumber(count) or nil
    if not count or count < 1 then
        return nil, nil
    end
    local talents = {}
    local bestTab = nil
    local bestPoints = 0
    local bestName = nil
    local tab = 1
    while tab <= count and tab <= 4 do
        local tabOk, tabName, _, pointsSpent = pcall(GetTalentTabInfo, tab)
        local spent = 0
        local label = nil
        if tabOk then
            if type(tabName) == "table" then
                label = SafeText(tabName.name)
                spent = AsNumber(tabName.pointsSpent) or 0
            else
                label = SafeText(tabName)
                spent = AsNumber(pointsSpent) or 0
            end
        end
        if spent > bestPoints then
            bestPoints = spent
            bestTab = tab
            bestName = label
        end
        local talentCount = 0
        if type(GetNumTalents) == "function" then
            local numOk, num = pcall(GetNumTalents, tab)
            talentCount = numOk and (AsNumber(num) or 0) or 0
        end
        local index = 1
        while index <= talentCount do
            local row = TalentFromTab(tab, index)
            if row then
                talents[#talents + 1] = row
            end
            index = index + 1
        end
        tab = tab + 1
    end
    local index = 1
    while talents[index] do
        if bestTab and talents[index].tab == bestTab then
            talents[index].tree = "spec"
        else
            talents[index].tree = "class"
        end
        index = index + 1
    end
    if bestPoints < 1 then
        bestName = nil
    end
    return talents, bestName
end

local function SpellName(spellID)
    local number = AsNumber(spellID)
    if not number then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, number)
        if ok then
            local text = SafeText(name)
            if text then
                return text
            end
        end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, number)
        if ok and type(info) == "table" then
            return SafeText(info.name)
        end
    end
    if type(GetSpellInfo) == "function" then
        local ok, name = pcall(GetSpellInfo, number)
        if ok then
            return SafeText(name)
        end
    end
    return nil
end

local function SpellIcon(spellID)
    local number = AsNumber(spellID)
    if not number or not C_Spell or not C_Spell.GetSpellTexture then
        return nil
    end
    local ok, iconID, original = pcall(C_Spell.GetSpellTexture, number)
    if not ok then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(original) then
        original = nil
    end
    if type(issecretvalue) == "function" and issecretvalue(iconID) then
        iconID = nil
    end
    return original or iconID
end

local function ActiveConfigID()
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        id = ok and AsNumber(id) or nil
        if id and id > 0 then
            return id
        end
    end
    if not (C_Traits and C_Traits.GetConfigsByType) then
        return nil
    end
    local configType = 1
    if Enum and Enum.TraitConfigType and Enum.TraitConfigType.Combat then
        configType = Enum.TraitConfigType.Combat
    end
    local ok, ids = pcall(C_Traits.GetConfigsByType, configType)
    if not ok or type(ids) ~= "table" then
        return nil
    end
    local index = 1
    while ids[index] do
        local id = AsNumber(ids[index])
        if id and id > 0 then
            return id
        end
        index = index + 1
    end
    return nil
end

local function TreeIDs(configID)
    local list = {}
    local seen = {}
    if not (C_Traits and C_Traits.GetConfigInfo) then
        return list
    end
    local ok, config = pcall(C_Traits.GetConfigInfo, configID)
    if not ok or type(config) ~= "table" or type(config.treeIDs) ~= "table" then
        return list
    end
    local index = 1
    while index < 20 do
        local readOk, treeID = pcall(function()
            return config.treeIDs[index]
        end)
        if not readOk or treeID == nil then
            break
        end
        local number = AsNumber(treeID)
        if number and number > 0 and not seen[number] then
            seen[number] = true
            list[#list + 1] = number
        end
        index = index + 1
    end
    return list
end

local function IsSelection(node)
    local ok, match = pcall(function()
        if node.isSubTreeSelection then
            return true
        end
        local selectionType = Enum and Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection
        return selectionType ~= nil and node.type == selectionType
    end)
    return ok and match or false
end

local function NodeRank(node)
    local rank = AsNumber(node.ranksPurchased) or AsNumber(node.currentRank) or AsNumber(node.activeRank) or 0
    if type(node.activeEntry) == "table" then
        local entryRank = AsNumber(node.activeEntry.rank)
        if entryRank and entryRank > 0 then
            rank = entryRank
        end
    end
    return rank
end

local function NodeTalent(configID, node)
    if type(node) ~= "table" or IsSelection(node) then
        return nil
    end
    local subTree = AsNumber(node.subTreeID)
    if subTree and subTree > 0 then
        return nil
    end
    local rank = NodeRank(node)
    if rank < 1 then
        return nil
    end
    local entryID = nil
    if type(node.activeEntry) == "table" then
        entryID = AsNumber(node.activeEntry.entryID)
    end
    if not entryID and type(node.entryIDs) == "table" then
        entryID = AsNumber(node.entryIDs[1])
    end
    local name = nil
    local icon = nil
    local spellID = nil
    if entryID and C_Traits and C_Traits.GetEntryInfo and C_Traits.GetDefinitionInfo then
        local ok, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
        if ok and type(entry) == "table" then
            local defOk, definition = pcall(C_Traits.GetDefinitionInfo, entry.definitionID)
            if defOk and type(definition) == "table" then
                spellID = AsNumber(definition.spellID)
                name = SafeText(definition.overrideName) or SpellName(spellID)
                icon = definition.overrideIcon
                if type(issecretvalue) == "function" and issecretvalue(icon) then
                    icon = nil
                end
                if type(icon) ~= "number" and type(icon) ~= "string" then
                    icon = SpellIcon(spellID)
                end
            end
        end
    end
    if not name then
        return nil
    end
    return {
        entryID = entryID,
        spellID = spellID,
        name = name,
        icon = icon,
        rank = rank,
        posX = AsNumber(node.posX) or 0,
        tree = "class",
    }
end

local function SplitByX(nodes)
    local groups = {}
    if not nodes[1] then
        return groups
    end
    table.sort(nodes, function(left, right)
        return (left.posX or 0) < (right.posX or 0)
    end)
    local step = nil
    local index = 2
    while nodes[index] do
        local gap = (nodes[index].posX or 0) - (nodes[index - 1].posX or 0)
        if gap > 0 and (not step or gap < step) then
            step = gap
        end
        index = index + 1
    end
    if not step or step < 1 then
        step = 1
    end
    groups[1] = { nodes[1] }
    index = 2
    while nodes[index] do
        local gap = (nodes[index].posX or 0) - (nodes[index - 1].posX or 0)
        local current = groups[#groups]
        if gap >= step * 1.9 then
            groups[#groups + 1] = { nodes[index] }
        else
            current[#current + 1] = nodes[index]
        end
        index = index + 1
    end
    while #groups > 3 do
        local smallest = 2
        local smallGap = nil
        local groupIndex = 2
        while groups[groupIndex] do
            local left = groups[groupIndex - 1]
            local right = groups[groupIndex]
            local gap = (right[1].posX or 0) - (left[#left].posX or 0)
            if not smallGap or gap < smallGap then
                smallGap = gap
                smallest = groupIndex
            end
            groupIndex = groupIndex + 1
        end
        local merged = groups[smallest - 1]
        local extra = groups[smallest]
        local extraIndex = 1
        while extra[extraIndex] do
            merged[#merged + 1] = extra[extraIndex]
            extraIndex = extraIndex + 1
        end
        local shift = smallest
        while groups[shift + 1] do
            groups[shift] = groups[shift + 1]
            shift = shift + 1
        end
        groups[shift] = nil
    end
    return groups
end

local function GroupPoints(group)
    local total = 0
    local index = 1
    while group[index] do
        total = total + (group[index].rank or 0)
        index = index + 1
    end
    return total
end

local function TraitTalents()
    if not (C_Traits and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then
        return nil, nil
    end
    local configID = ActiveConfigID()
    if not configID then
        return nil, nil
    end
    local trees = TreeIDs(configID)
    local nodes = {}
    local treeIndex = 1
    while trees[treeIndex] do
        local nodesOk, nodeIDs = pcall(C_Traits.GetTreeNodes, trees[treeIndex])
        local nodeIndex = 1
        while nodesOk and type(nodeIDs) == "table" and nodeIndex < 5000 do
            local readOk, nodeID = pcall(function()
                return nodeIDs[nodeIndex]
            end)
            if not readOk or nodeID == nil then
                break
            end
            local nodeOk, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            if nodeOk and type(nodeInfo) == "table" then
                local row = NodeTalent(configID, nodeInfo)
                if row then
                    nodes[#nodes + 1] = row
                end
            end
            nodeIndex = nodeIndex + 1
        end
        treeIndex = treeIndex + 1
    end
    local groups = SplitByX(nodes)
    local best = 1
    local bestPoints = -1
    local groupIndex = 1
    while groups[groupIndex] do
        local points = GroupPoints(groups[groupIndex])
        if points > bestPoints then
            bestPoints = points
            best = groupIndex
        end
        groupIndex = groupIndex + 1
    end
    local names = SpecializationNames()
    local specName = nil
    if bestPoints > 0 and names[best] and #names == #groups then
        specName = names[best]
    end
    groupIndex = 1
    while groups[groupIndex] do
        local tree = "class"
        if groupIndex == best and bestPoints > 0 then
            tree = "spec"
        end
        local rowIndex = 1
        while groups[groupIndex][rowIndex] do
            groups[groupIndex][rowIndex].tree = tree
            rowIndex = rowIndex + 1
        end
        groupIndex = groupIndex + 1
    end
    if not nodes[1] then
        return {}, specName
    end
    return nodes, specName
end

local function ReadTalents()
    local talents, specName = TraitTalents()
    if talents then
        return talents, specName
    end
    return ClassicTalents()
end

local function ApplyClientIcon(texture, icon)
    if not texture or icon == nil then
        return false
    end
    local ok = pcall(function()
        if type(icon) == "string" then
            if string.find(icon, "\\", 1, true) or string.find(icon, "/", 1, true) then
                texture:SetTexCoord(0, 1, 0, 1)
                texture:SetTexture(icon)
            else
                texture:SetAtlas(icon)
            end
        else
            texture:SetTexCoord(0, 1, 0, 1)
            texture:SetTexture(icon)
        end
    end)
    return ok
end

Scan.ApplyClientIcon = ApplyClientIcon

function Scan.ApplyTalentIcon(texture, entryID)
    if not texture or not entryID or not C_Traits or not C_Traits.GetEntryInfo or not C_Traits.GetDefinitionInfo then
        return false
    end
    local configID = ActiveConfigID()
    local ok, entry = false, nil
    if configID then
        ok, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
    end
    if not ok or type(entry) ~= "table" then
        ok, entry = pcall(C_Traits.GetEntryInfo, entryID)
    end
    if not ok or type(entry) ~= "table" then
        return false
    end
    local defOk, definition = pcall(C_Traits.GetDefinitionInfo, entry.definitionID)
    if not defOk or type(definition) ~= "table" then
        return false
    end
    if definition.overrideIcon and ApplyClientIcon(texture, definition.overrideIcon) then
        return true
    end
    local icon = SpellIcon(definition.spellID)
    if icon and ApplyClientIcon(texture, icon) then
        return true
    end
    return false
end

function Scan.Capture(create)
    local guid = UnitGUID("player")
    local name = SafeText(UnitName("player"))
    if not guid or not name then
        return
    end
    local record = BMGAM.DB.Get(guid)
    if not record and not create then
        return
    end
    if not record then
        record = BMGAM.DB.Ensure(guid)
    end
    local classOk, localizedClass, classFile = pcall(UnitClass, "player")
    local raceOk, localizedRace, raceFile = pcall(UnitRace, "player")
    local sideOk, side = pcall(UnitFactionGroup, "player")
    record.guid = guid
    local realmOk, realm = pcall(GetRealmName)
    if realmOk then
        record.realm = SafeText(realm) or record.realm
    end
    record.name = name
    if classOk then
        record.classFile = SafeText(classFile)
        record.className = SafeText(localizedClass)
    end
    if raceOk then
        record.raceFile = SafeText(raceFile)
        record.raceName = SafeText(localizedRace)
    end
    local sexOk, sex = pcall(UnitSex, "player")
    if sexOk then
        record.sex = AsNumber(sex)
    end
    local levelOk, level = pcall(UnitLevel, "player")
    if levelOk then
        record.level = AsNumber(level) or record.level or 0
    end
    if sideOk then
        record.side = SafeText(side)
    end
    local moneyOk, moneyValue = pcall(GetMoney)
    if moneyOk then
        local money = AsNumber(moneyValue)
        if money then
            record.moneyCopper = money
        end
    end
    record.itemLevel = ItemLevel()
    record.itemLevelQuality = ItemLevelQuality()
    record.scannedAt = time()
    local guildOk, guildName = pcall(GetGuildInfo, "player")
    if guildOk then
        record.guildName = SafeText(guildName) or ""
    end
    record.specName = SpecFromAPI()
    record.heroName = nil
    record.journeys = nil
    record.stats = {
        strength = Round(Stat(1)),
        stamina = Round(Stat(3)),
        armor = Round(Armor()),
        crit = Round(CallNumber(GetCritChance)),
        haste = Round(CallNumber(GetHaste)),
        mastery = Round(CallNumber(GetMasteryEffect)),
        versatility = Versatility(),
    }
    if type(GetBindLocation) == "function" then
        local bindOk, place = pcall(GetBindLocation)
        if bindOk then
            record.hearthstone = SafeText(place)
        end
    end
    local talents, specName = ReadTalents()
    if specName then
        record.specName = specName
    end
    if talents and talents[1] then
        record.talents = talents
        talentTries = 8
    elseif (record.level or 0) >= 10 and talentTries < 8 and not talentWait and C_Timer and C_Timer.After then
        talentWait = true
        talentTries = talentTries + 1
        C_Timer.After(2, function()
            talentWait = false
            Scan.Capture(false)
        end)
    elseif talents then
        record.talents = talents
    end
    if Scan.ReadGear then
        local gear, gearReady = Scan.ReadGear()
        if gear then
            record.gear = gear
        end
        if not gearReady and gearTries < 5 and not gearWait and C_Timer and C_Timer.After then
            gearWait = true
            gearTries = gearTries + 1
            C_Timer.After(1, function()
                gearWait = false
                Scan.Capture(false)
            end)
        end
    end
    if Scan.ReadBags then
        local bags, bagsReady = Scan.ReadBags()
        if bags and bags[1] then
            record.bags = bags
        end
        if not bagsReady and bagTries < 5 and not bagWait and C_Timer and C_Timer.After then
            bagWait = true
            bagTries = bagTries + 1
            C_Timer.After(1, function()
                bagWait = false
                Scan.Capture(false)
            end)
        end
    end
    if Scan.ReadProfessionList then
        pcall(Scan.ReadProfessionList)
    end
    if Scan.ReadCurrencies then
        pcall(Scan.ReadCurrencies)
    end
    if Scan.ReadReputations then
        pcall(Scan.ReadReputations)
    end
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

function Scan.OnEnteringWorld()
    if not UnitGUID("player") then
        if C_Timer and C_Timer.After then
            C_Timer.After(1, Scan.OnEnteringWorld)
        end
        return
    end
    local first = not capturedThisLoad
    capturedThisLoad = true
    if first then
        talentTries = 0
        gearTries = 0
        bagTries = 0
        professionListTries = 0
        currencyTries = 0
        currencyExpanded = false
        reputationTries = 0
        reputationReady = false
    end
    Scan.Capture(first)
    if Scan.ReadMailNotice then
        pcall(Scan.ReadMailNotice)
    end
    if Scan.ReadAuctions then
        pcall(Scan.ReadAuctions)
    end
    if Scan.ReadQuests then
        pcall(Scan.ReadQuests, true)
    end
    if Scan.ReadAchievements then
        pcall(Scan.ReadAchievements)
    end
    if Scan.ReadCollections then
        pcall(Scan.ReadCollections)
    end
end

function Scan.OnUpdate()
    Scan.Capture(false)
end

function Scan.OnEquip()
    gearTries = 0
    Scan.Capture(false)
end

function Scan.OnBags()
    if bagEventWait or not C_Timer or not C_Timer.After then
        if not C_Timer or not C_Timer.After then
            bagTries = 0
            Scan.Capture(false)
        end
        return
    end
    bagEventWait = true
    C_Timer.After(0.4, function()
        bagEventWait = false
        bagTries = 0
        Scan.Capture(false)
    end)
end

do
local GEAR_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 4, 19, 16, 17, 18, 0 }
local NO_DURABILITY = { [0] = true, [2] = true, [4] = true, [11] = true, [12] = true, [13] = true, [14] = true, [19] = true }
local NO_ENCHANT = { [0] = true, [4] = true, [13] = true, [14] = true, [19] = true }
local NO_SOCKET = { [0] = true, [4] = true, [13] = true, [14] = true, [19] = true }

local function LinkBody(link)
    if type(link) ~= "string" then
        return nil
    end
    return link:match("item:([%d:%-]+)")
end

local function LinkNumber(link, index)
    local body = LinkBody(link)
    if not body or type(strsplit) ~= "function" then
        return 0
    end
    local parts = { strsplit(":", body) }
    local value = tonumber(parts[index])
    if value and value > 0 then
        return value
    end
    return 0
end

local function ItemName(itemID, link)
    if C_Item and C_Item.GetItemNameByID and itemID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        name = ok and SafeText(name) or nil
        if name then
            return name
        end
    end
    if type(link) == "string" then
        return link:match("%[(.-)%]")
    end
    return nil
end

local function ItemQuality(itemID, slot)
    if type(GetInventoryItemQuality) == "function" then
        local ok, quality = pcall(GetInventoryItemQuality, "player", slot)
        quality = ok and AsNumber(quality) or nil
        if quality then
            return quality
        end
    end
    if C_Item and C_Item.GetItemQualityByID and itemID then
        local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
        quality = ok and AsNumber(quality) or nil
        if quality then
            return quality
        end
    end
    return 1
end

local function PlainIcon(value)
    if value == nil or value == 0 or value == "" then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(value) then
        return nil
    end
    if type(value) == "number" or type(value) == "string" then
        return value
    end
    return nil
end

local function ItemIcon(itemID, slot)
    if type(GetInventoryItemTexture) == "function" then
        local ok, texture = pcall(GetInventoryItemTexture, "player", slot)
        texture = ok and PlainIcon(texture) or nil
        if texture then
            return texture
        end
    end
    if C_Item and C_Item.GetItemIconByID and itemID then
        local ok, texture = pcall(C_Item.GetItemIconByID, itemID)
        texture = ok and PlainIcon(texture) or nil
        if texture then
            return texture
        end
    end
    return nil
end

local function SurfaceLine(line)
    if type(line) ~= "table" then
        return
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, line)
    end
end

local function CleanLine(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|A:[^|]+|a", "")
    text = text:gsub("|T[^|]+|t", "")
    text = text:match("^%s*(.-)%s*$")
    if not text or text == "" then
        return nil
    end
    return text
end

local function LineText(line)
    SurfaceLine(line)
    local text = SafeText(line.leftText)
    if not text and type(line.args) == "table" then
        local index = 1
        while line.args[index] do
            local arg = line.args[index]
            if type(arg) == "table" then
                text = SafeText(arg.stringVal)
                if text then
                    break
                end
            end
            index = index + 1
        end
    end
    return CleanLine(text)
end

local function LineIs(line, enumName, fallbackNumber)
    local expected = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType[enumName]
    if not expected then
        expected = fallbackNumber
    end
    if not expected then
        return false
    end
    local ok, match = pcall(function()
        return line.type == expected
    end)
    return ok and match == true
end

local function InventoryLines(slot)
    if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
        return nil
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, data)
    end
    return data.lines
end

local function TypeNumber(line)
    SurfaceLine(line)
    local number = AsNumber(line.type)
    if number then
        return number
    end
    return nil
end

local function CleanEnchant(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    text = text:gsub("^Enchanted:%s*", "")
    text = text:gsub("^Enchant:%s*", "")
    text = text:gsub("^Equip:%s*", "")
    text = text:match("^%s*(.-)%s*$")
    if not text or text == "" then
        return nil
    end
    return text
end

local function MissingEnchant(text)
    if type(text) ~= "string" then
        return false
    end
    return text == "Not enchanted" or text:find("^Not enchanted", 1, true) ~= nil
end

local function EnchantName(slot)
    local lines = InventoryLines(slot)
    local fallback = nil
    if lines then
        local index = 1
        while lines[index] do
            local line = lines[index]
            if type(line) == "table" then
                local text = LineText(line)
                if MissingEnchant(text) then
                    return nil, true
                end
                local cleaned = CleanEnchant(text)
                local kind = TypeNumber(line)
                local isEnchant = kind == 15 or LineIs(line, "ItemEnchantmentPermanent", 15)
                if isEnchant and cleaned and not MissingEnchant(cleaned) then
                    return cleaned, true
                end
                if not fallback and text and (text:find("^Enchanted:%s*%S", 1) or text:find("^Enchant:%s*%S", 1)) and not MissingEnchant(cleaned) then
                    fallback = cleaned
                end
            end
            index = index + 1
        end
    end
    if fallback then
        return fallback, true
    end
    if lines then
        return nil, true
    end
    return nil, false
end

function Scan.EnchantText(slot)
    local name, looked = EnchantName(slot)
    if type(name) == "string" and name ~= "" then
        return name
    end
    if looked then
        return "not-enchanted"
    end
    return nil
end

local function TooltipGems(slot)
    local lines = InventoryLines(slot)
    if not lines then
        return nil
    end
    local names = {}
    local index = 1
    while lines[index] do
        local line = lines[index]
        if type(line) == "table" and (LineIs(line, "Gem") or LineIs(line, "GemSocket", 3)) then
            local text = LineText(line)
            if text then
                text = text:gsub("^Gem Slot:%s*", "")
                text = text:gsub("^Gem:%s*", "")
                if text ~= "" and not text:find("Socket", 1, true) and text ~= "Empty" then
                    names[#names + 1] = text
                end
            end
        end
        index = index + 1
    end
    return names
end

local function GemNameAt(link, index)
    if not link or not C_Item or not C_Item.GetItemGem then
        return nil
    end
    local ok, name = pcall(C_Item.GetItemGem, link, index)
    if not ok then
        return nil
    end
    return SafeText(name)
end

local function UpgradeText(link, itemID)
    if not link or not C_Item or not C_Item.GetItemUpgradeInfo then
        return nil, true
    end
    local ok, info = pcall(C_Item.GetItemUpgradeInfo, link)
    if not ok then
        return nil, false
    end
    if type(info) ~= "table" then
        if itemID and C_Item.IsItemDataCachedByID then
            local cacheOk, isCached = pcall(C_Item.IsItemDataCachedByID, itemID)
            if cacheOk and isCached == false then
                return nil, false
            end
        end
        return nil, true
    end
    local track = SafeText(info.trackString)
    local current = AsNumber(info.currentLevel)
    local maximum = AsNumber(info.maxLevel)
    if track and current and maximum and maximum > 0 then
        return string.format("%s %d/%d", track, current, maximum), true
    end
    return nil, true
end

local function SocketCount(link)
    if C_Item and C_Item.GetItemNumSockets then
        local ok, count = pcall(C_Item.GetItemNumSockets, link)
        local number = ok and AsNumber(count) or nil
        if number and number >= 0 then
            return number
        end
    end
    local stats
    if C_Item and C_Item.GetItemStats then
        local ok, result = pcall(C_Item.GetItemStats, link)
        if ok and type(result) == "table" then
            stats = result
        end
    end
    if not stats then
        return 0
    end
    local count = 0
    for key, value in pairs(stats) do
        if type(key) == "string" and key:find("EMPTY_SOCKET", 1, true) then
            local amount = tonumber(value) or 1
            if amount < 1 then
                amount = 1
            end
            count = count + amount
        end
    end
    return count
end

local function ReadGear()
    local gear = {}
    local ready = true
    local index = 1
    while index <= #GEAR_SLOTS do
        local slot = GEAR_SLOTS[index]
        local itemID = nil
        if type(GetInventoryItemID) == "function" then
            local ok, id = pcall(GetInventoryItemID, "player", slot)
            itemID = ok and AsNumber(id) or nil
            if itemID and itemID <= 0 then
                itemID = nil
            end
        end
        if not itemID then
            gear[slot] = { slot = slot, empty = true }
        else
            if C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, itemID)
            end
            local link = nil
            if type(GetInventoryItemLink) == "function" then
                local ok, value = pcall(GetInventoryItemLink, "player", slot)
                if ok then
                    link = SafeText(value)
                end
            end
            local name = ItemName(itemID, link)
            if not name then
                ready = false
            end
            local upgrade, upgradeReady = UpgradeText(link, itemID)
            if not upgradeReady then
                ready = false
            end
            local row = {
                slot = slot,
                empty = false,
                itemID = itemID,
                link = link,
                name = name,
                quality = ItemQuality(itemID, slot),
                icon = ItemIcon(itemID, slot),
                upgrade = upgrade,
            }
            if type(GetInventoryItemCount) == "function" then
                local countOk, count = pcall(GetInventoryItemCount, "player", slot)
                if not countOk then
                    countOk, count = pcall(GetInventoryItemCount, slot)
                end
                count = countOk and AsNumber(count) or nil
                if count and count > 1 then
                    row.count = count
                end
            end
            if not NO_DURABILITY[slot] and type(GetInventoryItemDurability) == "function" then
                local ok, current, maximum = pcall(GetInventoryItemDurability, slot)
                local currentN = ok and AsNumber(current) or nil
                local maxN = ok and AsNumber(maximum) or nil
                if currentN and maxN and maxN > 0 then
                    row.durabilityCurrent = currentN
                    row.durabilityMax = maxN
                end
            end
            if NO_ENCHANT[slot] then
                row.enchantID = 0
                row.enchantName = "cannot"
            else
                local enchantID = LinkNumber(link, 2)
                local enchantName, looked = EnchantName(slot)
                row.enchantID = enchantID
                if enchantName then
                    row.enchantName = enchantName
                elseif looked or enchantID == 0 then
                    row.enchantName = "not-enchanted"
                else
                    ready = false
                end
            end
            if not NO_SOCKET[slot] then
                local sockets = {}
                local gems = {}
                local gemIndex = 3
                while gemIndex <= 6 do
                    local gemID = LinkNumber(link, gemIndex)
                    if gemID > 0 then
                        gems[#gems + 1] = gemID
                    end
                    gemIndex = gemIndex + 1
                end
                local count = SocketCount(link)
                if count < #gems then
                    count = #gems
                end
                local filled = 1
                while filled <= #gems do
                    local gemID = gems[filled]
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        pcall(C_Item.RequestLoadItemDataByID, gemID)
                    end
                    local gemName = ItemName(gemID)
                    if (not gemName or gemName == "") and link then
                        gemName = GemNameAt(link, filled)
                    end
                    local gemQuality = 1
                    if C_Item and C_Item.GetItemQualityByID then
                        local qualityOk, quality = pcall(C_Item.GetItemQualityByID, gemID)
                        quality = qualityOk and AsNumber(quality) or nil
                        if quality then
                            gemQuality = quality
                        end
                    end
                    if not gemName then
                        ready = false
                    end
                    sockets[#sockets + 1] = { gemID = gemID, name = gemName, quality = gemQuality }
                    filled = filled + 1
                end
                local emptyIndex = #gems + 1
                while emptyIndex <= count do
                    sockets[#sockets + 1] = { empty = true }
                    emptyIndex = emptyIndex + 1
                end
                local probe = 1
                while probe <= 4 do
                    local apiName = GemNameAt(link, probe)
                    if apiName then
                        local placed = false
                        local socketIndex = 1
                        while sockets[socketIndex] do
                            if sockets[socketIndex].name == apiName then
                                placed = true
                                break
                            end
                            if sockets[socketIndex].empty or not sockets[socketIndex].name or sockets[socketIndex].name == "" then
                                sockets[socketIndex].empty = nil
                                sockets[socketIndex].name = apiName
                                placed = true
                                break
                            end
                            socketIndex = socketIndex + 1
                        end
                        if not placed then
                            sockets[#sockets + 1] = { name = apiName, quality = 1 }
                        end
                    end
                    probe = probe + 1
                end
                if not sockets[1] then
                    local names = TooltipGems(slot)
                    local nameIndex = 1
                    while names and names[nameIndex] do
                        sockets[#sockets + 1] = { name = names[nameIndex], quality = 1 }
                        nameIndex = nameIndex + 1
                    end
                else
                    local names = TooltipGems(slot)
                    local nameIndex = 1
                    local socketIndex = 1
                    while names and names[nameIndex] and sockets[socketIndex] do
                        if sockets[socketIndex].empty or not sockets[socketIndex].name or sockets[socketIndex].name == "" then
                            sockets[socketIndex].empty = nil
                            sockets[socketIndex].name = names[nameIndex]
                            nameIndex = nameIndex + 1
                        end
                        socketIndex = socketIndex + 1
                    end
                end
                if sockets[1] then
                    row.sockets = sockets
                end
            end
            gear[slot] = row
        end
        index = index + 1
    end
    return gear, ready
end

function Scan.ReadGear()
    return ReadGear()
end
end

do
local function AddBag(ids, seen, bag)
    local number = AsNumber(bag)
    if number == nil or seen[number] then
        return
    end
    seen[number] = true
    ids[#ids + 1] = number
end

local function BagIds()
    local ids = {}
    local seen = {}
    AddBag(ids, seen, 0)
    AddBag(ids, seen, 1)
    AddBag(ids, seen, 2)
    AddBag(ids, seen, 3)
    AddBag(ids, seen, 4)
    local reagent = 5
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag ~= nil then
        local number = AsNumber(Enum.BagIndex.ReagentBag)
        if number then
            reagent = number
        end
    end
    AddBag(ids, seen, reagent)
    if Enum and Enum.BagIndex and Enum.BagIndex.Keyring ~= nil then
        AddBag(ids, seen, Enum.BagIndex.Keyring)
    end
    return ids
end

local function BagSize(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, count = pcall(C_Container.GetContainerNumSlots, bag)
        local number = ok and AsNumber(count) or nil
        if number and number > 0 then
            return number
        end
        if ok then
            return 0
        end
    end
    if type(GetContainerNumSlots) == "function" then
        local ok, count = pcall(GetContainerNumSlots, bag)
        local number = ok and AsNumber(count) or nil
        if number and number > 0 then
            return number
        end
    end
    return 0
end

local function PlainIcon(value)
    if value == nil or value == 0 or value == "" then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(value) then
        return nil
    end
    if type(value) == "number" or type(value) == "string" then
        return value
    end
    return nil
end

local function ItemName(itemID, link)
    if C_Item and C_Item.GetItemNameByID and itemID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        name = ok and SafeText(name) or nil
        if name then
            return name
        end
    end
    if type(GetItemInfo) == "function" and itemID then
        local ok, name = pcall(GetItemInfo, itemID)
        name = ok and SafeText(name) or nil
        if name then
            return name
        end
    end
    if type(link) == "string" then
        return link:match("%[(.-)%]")
    end
    return nil
end

local function ItemIcon(itemID)
    if C_Item and C_Item.GetItemIconByID and itemID then
        local ok, texture = pcall(C_Item.GetItemIconByID, itemID)
        texture = ok and PlainIcon(texture) or nil
        if texture then
            return texture
        end
    end
    if type(GetItemIcon) == "function" and itemID then
        local ok, texture = pcall(GetItemIcon, itemID)
        texture = ok and PlainIcon(texture) or nil
        if texture then
            return texture
        end
    end
    return nil
end

local function ContainerInfo(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, first, count, _, quality, _, _, link, _, _, itemID = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and first ~= nil then
            if type(first) == "table" then
                return first
            end
            return {
                iconFileID = first,
                stackCount = count,
                quality = quality,
                hyperlink = link,
                itemID = itemID,
            }
        end
    end
    if type(GetContainerItemInfo) ~= "function" then
        return nil
    end
    local ok, texture, count, _, quality, _, _, link, _, _, itemID = pcall(GetContainerItemInfo, bag, slot)
    if not ok or texture == nil then
        return nil
    end
    if type(texture) == "table" then
        return texture
    end
    return {
        iconFileID = texture,
        stackCount = count,
        quality = quality,
        hyperlink = link,
        itemID = itemID,
    }
end

local function BagName(bag)
    if C_Container and C_Container.GetBagName then
        local ok, name = pcall(C_Container.GetBagName, bag)
        name = ok and SafeText(name) or nil
        if name then
            return name
        end
    end
    if type(GetBagName) == "function" then
        local ok, name = pcall(GetBagName, bag)
        name = ok and SafeText(name) or nil
        if name then
            return name
        end
    end
    return nil
end

local function ReadBags()
    local ids = BagIds()
    local keyring = nil
    local reagent = 5
    if Enum and Enum.BagIndex then
        keyring = AsNumber(Enum.BagIndex.Keyring)
        if Enum.BagIndex.ReagentBag ~= nil then
            local number = AsNumber(Enum.BagIndex.ReagentBag)
            if number then
                reagent = number
            end
        end
    end
    local bags = {}
    local ready = true
    local index = 1
    while index <= #ids do
        local bag = ids[index]
        local size = BagSize(bag)
        if size > 0 then
            local row = { bag = bag, size = size, slots = {} }
            if bag == 0 then
                row.name = BagName(bag) or "Backpack"
                row.icon = "Interface\\Buttons\\Button-Backpack-Up"
            else
                local inv = nil
                if C_Container and C_Container.ContainerIDToInventoryID then
                    local ok, id = pcall(C_Container.ContainerIDToInventoryID, bag)
                    if ok then
                        inv = AsNumber(id)
                    end
                end
                local link = nil
                if inv and type(GetInventoryItemLink) == "function" then
                    local ok, value = pcall(GetInventoryItemLink, "player", inv)
                    if ok then
                        link = SafeText(value)
                    end
                end
                local itemID = nil
                if inv and type(GetInventoryItemID) == "function" then
                    local ok, id = pcall(GetInventoryItemID, "player", inv)
                    if ok then
                        itemID = AsNumber(id)
                        if itemID and itemID <= 0 then
                            itemID = nil
                        end
                    end
                end
                if itemID and C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, itemID)
                end
                row.itemID = itemID
                row.link = link
                row.name = ItemName(itemID, link) or BagName(bag)
                if not row.name then
                    if keyring and bag == keyring then
                        row.name = "Keyring"
                    elseif bag == reagent then
                        row.name = "Reagent Bag"
                    else
                        row.name = "Bag"
                        if itemID then
                            ready = false
                        end
                    end
                end
                row.quality = 1
                if itemID and C_Item and C_Item.GetItemQualityByID then
                    local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
                    quality = ok and AsNumber(quality) or nil
                    if quality then
                        row.quality = quality
                    end
                end
                row.icon = ItemIcon(itemID)
                if not row.icon and keyring and bag == keyring then
                    row.icon = "Interface\\ContainerFrame\\KeyRing-Bag-Icon"
                end
            end
            local filled = 0
            local slot = 1
            while slot <= size do
                local info = ContainerInfo(bag, slot)
                local itemID = info and AsNumber(info.itemID) or nil
                if not itemID or itemID < 1 then
                    row.slots[slot] = { empty = true }
                else
                    if C_Item and C_Item.RequestLoadItemDataByID then
                        pcall(C_Item.RequestLoadItemDataByID, itemID)
                    end
                    local link = SafeText(info.hyperlink) or SafeText(info.itemLink)
                    if not link and C_Container and C_Container.GetContainerItemLink then
                        local linkOk, value = pcall(C_Container.GetContainerItemLink, bag, slot)
                        if linkOk then
                            link = SafeText(value)
                        end
                    end
                    if not link and type(GetContainerItemLink) == "function" then
                        local linkOk, value = pcall(GetContainerItemLink, bag, slot)
                        if linkOk then
                            link = SafeText(value)
                        end
                    end
                    local name = ItemName(itemID, link) or SafeText(info.itemName)
                    if not name or not link then
                        ready = false
                    end
                    local count = AsNumber(info.stackCount) or AsNumber(info.stack) or 1
                    if count < 1 then
                        count = 1
                    end
                    local quality = AsNumber(info.quality)
                    if quality == nil then
                        quality = AsNumber(info.itemQuality)
                    end
                    if quality == nil and C_Item and C_Item.GetItemQualityByID then
                        local qualityOk, value = pcall(C_Item.GetItemQualityByID, itemID)
                        quality = qualityOk and AsNumber(value) or nil
                    end
                    local icon = PlainIcon(info.iconFileID) or PlainIcon(info.icon) or ItemIcon(itemID)
                    row.slots[slot] = {
                        empty = false,
                        itemID = itemID,
                        link = link,
                        name = name,
                        quality = quality,
                        icon = icon,
                        count = count,
                    }
                    filled = filled + 1
                end
                slot = slot + 1
            end
            row.filled = filled
            bags[#bags + 1] = row
        end
        index = index + 1
    end
    return bags, ready
end

function Scan.ReadBags()
    return ReadBags()
end

local bankOpen = false
local guildOpen = false
local bankWait = false
local guildWait = false
local bankTries = 0
local guildTries = 0
local guildQueried = false

local function EnumBag(name)
    if not Enum or not Enum.BagIndex then
        return nil
    end
    return AsNumber(Enum.BagIndex[name])
end

local function EnumBags(prefix, count)
    local ids = {}
    local index = 1
    while index <= count do
        local id = EnumBag(prefix .. index)
        if id then
            ids[#ids + 1] = id
        end
        index = index + 1
    end
    return ids
end

local function ReadContainerSlots(ids)
    local slots = {}
    local filled = 0
    local ready = true
    local index = 1
    while index <= #ids do
        local bag = ids[index]
        local size = BagSize(bag)
        local slot = 1
        while slot <= size do
            local info = ContainerInfo(bag, slot)
            local itemID = info and AsNumber(info.itemID) or nil
            if not itemID or itemID < 1 then
                slots[#slots + 1] = { empty = true }
            else
                if C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, itemID)
                end
                local link = SafeText(info.hyperlink) or SafeText(info.itemLink)
                if not link and C_Container and C_Container.GetContainerItemLink then
                    local linkOk, value = pcall(C_Container.GetContainerItemLink, bag, slot)
                    if linkOk then
                        link = SafeText(value)
                    end
                end
                local name = ItemName(itemID, link) or SafeText(info.itemName)
                if not name or not link then
                    ready = false
                end
                local count = AsNumber(info.stackCount) or AsNumber(info.stack) or 1
                if count < 1 then
                    count = 1
                end
                local quality = AsNumber(info.quality)
                if quality == nil then
                    quality = AsNumber(info.itemQuality)
                end
                if quality == nil and C_Item and C_Item.GetItemQualityByID then
                    local qualityOk, value = pcall(C_Item.GetItemQualityByID, itemID)
                    quality = qualityOk and AsNumber(value) or nil
                end
                local icon = PlainIcon(info.iconFileID) or PlainIcon(info.icon) or ItemIcon(itemID)
                slots[#slots + 1] = {
                    empty = false,
                    itemID = itemID,
                    link = link,
                    name = name,
                    quality = quality,
                    icon = icon,
                    count = count,
                }
                filled = filled + 1
            end
            slot = slot + 1
        end
        index = index + 1
    end
    return slots, filled, ready
end

local function SlotsNeedNames(slots)
    local index = 1
    while slots[index] do
        local item = slots[index]
        if item and not item.empty and (not item.name or item.name == "" or not item.link) then
            return true
        end
        index = index + 1
    end
    return false
end

local function BankTabIcon(bankType)
    if not C_Bank or not C_Bank.FetchPurchasedBankTabData or bankType == nil then
        return nil
    end
    local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
    if not ok or type(tabs) ~= "table" or type(tabs[1]) ~= "table" then
        return nil
    end
    return PlainIcon(tabs[1].icon)
end

local function SavePersonalBank()
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB.Get(guid) or nil
    if not record then
        return true
    end
    local bankType = Enum and Enum.BankType and Enum.BankType.Character
    local slots, filled, ready = ReadContainerSlots(EnumBags("CharacterBankTab_", 9))
    if not slots[1] then
        local answered = false
        if C_Bank and C_Bank.FetchPurchasedBankTabData and bankType ~= nil then
            local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
            answered = ok and type(tabs) == "table"
        end
        if not answered and not (C_Bank and C_Bank.FetchPurchasedBankTabData) then
            return false
        end
        if not answered then
            return false
        end
    end
    record.bank = {
        scanned = true,
        scannedAt = time(),
        filled = filled,
        size = #slots,
        icon = BankTabIcon(bankType),
        slots = slots,
    }
    return ready and not SlotsNeedNames(slots)
end

local function GuildStorageKey()
    if type(GetGuildInfo) ~= "function" then
        return nil
    end
    local ok, name = pcall(GetGuildInfo, "player")
    name = ok and SafeText(name) or nil
    if not name or name == "" then
        return nil
    end
    local realmOk, realm = pcall(GetRealmName)
    realm = realmOk and SafeText(realm) or ""
    return (realm or "") .. "-" .. name
end

local function SaveGuildBank()
    local key = GuildStorageKey()
    if not key or type(GetNumGuildBankTabs) ~= "function" or type(GetGuildBankTabInfo) ~= "function" or type(GetGuildBankItemLink) ~= "function" then
        return false
    end
    local tabsOk, tabCount = pcall(GetNumGuildBankTabs)
    tabCount = tabsOk and AsNumber(tabCount) or 0
    if not tabCount or tabCount < 1 then
        return false
    end
    local slots = {}
    local filled = 0
    local ready = true
    local icon = nil
    local tab = 1
    while tab <= tabCount do
        local infoOk, _, tabIcon, viewable = pcall(GetGuildBankTabInfo, tab)
        local hidden = infoOk and (viewable == false or viewable == 0)
        if not hidden then
            if not icon then
                icon = PlainIcon(tabIcon)
            end
            local slot = 1
            while slot <= 98 do
                local linkOk, link = pcall(GetGuildBankItemLink, tab, slot)
                link = linkOk and SafeText(link) or nil
                if not link then
                    slots[#slots + 1] = { empty = true }
                else
                    local itemID = nil
                    if C_Item and C_Item.GetItemInfoInstant then
                        local idOk, id = pcall(C_Item.GetItemInfoInstant, link)
                        itemID = idOk and AsNumber(id) or nil
                    end
                    if itemID and C_Item.RequestLoadItemDataByID then
                        pcall(C_Item.RequestLoadItemDataByID, itemID)
                    end
                    local name = ItemName(itemID, link)
                    if not name then
                        ready = false
                    end
                    local count = 1
                    local quality = nil
                    local texture = nil
                    if type(GetGuildBankItemInfo) == "function" then
                        local itemOk, tex, stack, _, _, itemQuality = pcall(GetGuildBankItemInfo, tab, slot)
                        if itemOk then
                            texture = PlainIcon(tex)
                            count = AsNumber(stack) or 1
                            quality = AsNumber(itemQuality)
                        end
                    end
                    if count < 1 then
                        count = 1
                    end
                    slots[#slots + 1] = {
                        empty = false,
                        itemID = itemID,
                        link = link,
                        name = name,
                        quality = quality,
                        icon = texture or ItemIcon(itemID),
                        count = count,
                    }
                    filled = filled + 1
                end
                slot = slot + 1
            end
        end
        tab = tab + 1
    end
    if not slots[1] then
        return false
    end
    local account = BMGAM.DB.Account()
    if type(account.guildBanks) ~= "table" then
        account.guildBanks = {}
    end
    account.guildBanks[key] = {
        scanned = true,
        scannedAt = time(),
        filled = filled,
        size = #slots,
        icon = icon,
        slots = slots,
    }
    return ready and not SlotsNeedNames(slots)
end

function Scan.ReadOpenBank()
    if not bankOpen then
        return
    end
    local personalReady = SavePersonalBank()
    if not personalReady and bankTries < 5 and not bankWait and C_Timer and C_Timer.After then
        bankTries = bankTries + 1
        bankWait = true
        C_Timer.After(0.6, function()
            bankWait = false
            Scan.ReadOpenBank()
        end)
    end
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

function Scan.ReadOpenGuildBank()
    if not guildOpen then
        return
    end
    if not guildQueried and type(GetNumGuildBankTabs) == "function" and type(QueryGuildBankTab) == "function" then
        local tabsOk, tabCount = pcall(GetNumGuildBankTabs)
        tabCount = tabsOk and AsNumber(tabCount) or 0
        local tab = 1
        while tabCount and tab <= tabCount do
            pcall(QueryGuildBankTab, tab)
            tab = tab + 1
        end
        if tabCount and tabCount >= 1 then
            guildQueried = true
        end
    end
    local ready = SaveGuildBank()
    if not ready and guildTries < 5 and not guildWait and C_Timer and C_Timer.After then
        guildTries = guildTries + 1
        guildWait = true
        C_Timer.After(0.6, function()
            guildWait = false
            Scan.ReadOpenGuildBank()
        end)
    end
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

function Scan.OnBank(opened)
    if opened then
        bankOpen = true
        bankTries = 0
        Scan.ReadOpenBank()
        return
    end
    bankOpen = false
end

function Scan.OnGuildBank(opened)
    if opened then
        guildOpen = true
        guildTries = 0
        Scan.ReadOpenGuildBank()
        return
    end
    guildOpen = false
    guildQueried = false
end
end

do
local PROFESSION_SPELLS = {
    { line = 171, spell = 2259, secondary = false },
    { line = 164, spell = 2018, secondary = false },
    { line = 333, spell = 7411, secondary = false },
    { line = 202, spell = 4036, secondary = false },
    { line = 165, spell = 2108, secondary = false },
    { line = 197, spell = 3908, secondary = false },
    { line = 755, spell = 25229, secondary = false },
    { line = 773, spell = 45357, secondary = false },
    { line = 182, spell = 9134, secondary = false },
    { line = 186, spell = 2575, secondary = false },
    { line = 393, spell = 8613, secondary = false },
    { line = 185, spell = 2550, secondary = true },
    { line = 356, spell = 7620, secondary = true },
    { line = 794, spell = 78670, secondary = true },
    { line = 129, spell = 3273, secondary = true },
}

local function RealName(value)
    local text = SafeText(value)
    if not text or string.match(text, "^%d+$") then
        return nil
    end
    return text
end

local function IconValue(value)
    local number = AsNumber(value)
    if number and number > 0 then
        return number
    end
    return SafeText(value)
end

local function SpellTitle(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            return RealName(info.name)
        end
        if ok then
            return RealName(info)
        end
    end
    if type(GetSpellInfo) == "function" then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok then
            return RealName(name)
        end
    end
    return nil
end

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok then
            return IconValue(texture)
        end
    end
    if type(GetSpellTexture) == "function" then
        local ok, texture = pcall(GetSpellTexture, spellID)
        if ok then
            return IconValue(texture)
        end
    end
    return nil
end

local function LineTexture(skillLine)
    if not skillLine or not C_TradeSkillUI or not C_TradeSkillUI.GetTradeSkillTexture then
        return nil
    end
    local ok, texture = pcall(C_TradeSkillUI.GetTradeSkillTexture, skillLine)
    if ok then
        return IconValue(texture)
    end
    return nil
end

local function PlayerRecord()
    local guid = UnitGUID("player")
    if not guid or not BMGAM.DB then
        return nil
    end
    local record = BMGAM.DB.Get(guid)
    if not record and BMGAM.DB.Ensure then
        record = BMGAM.DB.Ensure(guid)
    end
    return record
end

local function FindProfession(list, skillLine, name)
    if type(list) ~= "table" then
        return nil
    end
    local index = 1
    while list[index] do
        local row = list[index]
        if skillLine and row.skillLine == skillLine then
            return row
        end
        index = index + 1
    end
    if not name then
        return nil
    end
    index = 1
    while list[index] do
        if list[index].name == name then
            return list[index]
        end
        index = index + 1
    end
    return nil
end

local function EnsureLine(prof, lineName, skillLine, skill, maxSkill)
    if type(prof.expansions) ~= "table" then
        prof.expansions = {}
    end
    local found = nil
    local index = 1
    while prof.expansions[index] do
        local line = prof.expansions[index]
        if (skillLine and line.skillLine == skillLine) or (lineName and line.name == lineName) then
            found = line
        end
        index = index + 1
    end
    if not found then
        found = { name = lineName, skillLine = skillLine, scanned = false }
        prof.expansions[#prof.expansions + 1] = found
    end
    if lineName then
        found.name = lineName
    end
    if skillLine then
        found.skillLine = skillLine
    end
    if skill then
        found.skill = skill
    end
    if maxSkill then
        found.maxSkill = maxSkill
    end
    return found
end

local function TakeProfession(list, old, info)
    if not info or not info.name then
        return nil
    end
    local previous = FindProfession(old, info.skillLine, info.name)
    local row = FindProfession(list, info.skillLine, info.name)
    if not row then
        row = {
            skillLine = info.skillLine,
            name = info.name,
            icon = info.icon,
            skill = info.skill,
            maxSkill = info.maxSkill,
            primary = info.primary and true or false,
            fromSlots = info.fromSlots and true or false,
            expansions = {},
        }
        if previous and type(previous.expansions) == "table" then
            row.expansions = previous.expansions
        end
        list[#list + 1] = row
    end
    row.name = info.name
    if info.skillLine then
        row.skillLine = info.skillLine
    end
    if info.icon then
        row.icon = info.icon
    elseif not row.icon and info.skillLine then
        row.icon = LineTexture(info.skillLine)
    end
    if info.skill then
        row.skill = info.skill
    end
    if info.maxSkill then
        row.maxSkill = info.maxSkill
    end
    if info.fromSlots then
        row.primary = info.primary and true or false
        row.fromSlots = true
    elseif not row.fromSlots and info.primary ~= nil then
        row.primary = info.primary and true or false
    end
    local lineName = info.lineName or info.name
    if lineName then
        EnsureLine(row, lineName, info.lineID or info.skillLine, info.skill, info.maxSkill)
    end
    return row
end

local function ReadSlot(slot, primary)
    local ok, a, b, c, d, _, _, g = pcall(GetProfessionInfo, slot)
    if not ok then
        return nil
    end
    local name, icon, skill, maxSkill, skillLine
    if type(a) == "table" then
        name = RealName(a.parentProfessionName) or RealName(a.professionName) or RealName(a.name)
        icon = IconValue(a.professionIcon or a.icon or a.texture)
        skill = AsNumber(a.skillLevel or a.rank)
        maxSkill = AsNumber(a.maxSkillLevel or a.maxRank)
        skillLine = AsNumber(a.parentProfessionID) or AsNumber(a.professionID) or AsNumber(a.skillLine)
    else
        name = RealName(a)
        icon = IconValue(b)
        skill = AsNumber(c)
        maxSkill = AsNumber(d)
        skillLine = AsNumber(g)
    end
    if not name then
        return nil
    end
    return {
        name = name,
        icon = icon,
        skill = skill,
        maxSkill = maxSkill,
        skillLine = skillLine,
        primary = primary,
        lineName = name,
        fromSlots = true,
    }
end

local function ReadSlots(list, old)
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then
        return false
    end
    local ok, first, second, archaeology, fishing, cooking = pcall(GetProfessions)
    if not ok then
        return false
    end
    local order = { first, second, cooking, fishing, archaeology }
    local primarySlot = { true, true, false, false, false }
    local saw = false
    local index = 1
    while index <= 5 do
        local slot = AsNumber(order[index])
        if slot and slot > 0 then
            local info = ReadSlot(slot, primarySlot[index])
            if info then
                saw = true
                TakeProfession(list, old, info)
            end
        end
        index = index + 1
    end
    return saw
end

local function SkillLineAt(index)
    local ok, a, b, _, d, _, _, g = pcall(GetSkillLineInfo, index)
    if not ok then
        return nil
    end
    if type(a) == "table" then
        return {
            name = RealName(a.name or a.skillName),
            header = a.isHeader and true or false,
            rank = AsNumber(a.skillRank or a.rank),
            maxRank = AsNumber(a.skillMaxRank or a.maxRank),
        }
    end
    return {
        name = RealName(a),
        header = b and true or false,
        rank = AsNumber(d),
        maxRank = AsNumber(g),
    }
end

local function ProfessionByName(name)
    local index = 1
    while PROFESSION_SPELLS[index] do
        local row = PROFESSION_SPELLS[index]
        local title = SpellTitle(row.spell)
        if title and title == name then
            return row
        end
        index = index + 1
    end
    return nil
end

local function ReadSkillWindow(list, old)
    if type(GetNumSkillLines) ~= "function" or type(GetSkillLineInfo) ~= "function" then
        return
    end
    local ok, count = pcall(GetNumSkillLines)
    count = ok and AsNumber(count) or 0
    if not count or count < 1 then
        return
    end
    if count > 200 then
        count = 200
    end
    local index = 1
    while index <= count do
        local line = SkillLineAt(index)
        if line and not line.header and line.name then
            local known = ProfessionByName(line.name)
            if known then
                TakeProfession(list, old, {
                    name = line.name,
                    skillLine = known.line,
                    skill = line.rank,
                    maxSkill = line.maxRank,
                    primary = not known.secondary,
                    lineName = line.name,
                    icon = SpellIcon(known.spell),
                })
            end
        end
        index = index + 1
    end
end

function Scan.ReadProfessionList()
    local record = PlayerRecord()
    if not record then
        return
    end
    local old = record.professions
    local professions = {}
    ReadSlots(professions, old)
    ReadSkillWindow(professions, old)
    if not professions[1] then
        if type(old) == "table" and old[1] then
            return
        end
        if professionListTries < 4 then
            if not professionListWait and C_Timer and C_Timer.After then
                professionListTries = professionListTries + 1
                professionListWait = true
                C_Timer.After(1, function()
                    professionListWait = false
                    Scan.ReadProfessionList()
                    if BMGAM.Window and BMGAM.Window.Refresh then
                        BMGAM.Window.Refresh()
                    end
                end)
            end
            return
        end
    end
    record.professions = professions
end

local function RecipeCount(recipes)
    local count = 0
    while type(recipes) == "table" and recipes[count + 1] do
        count = count + 1
    end
    return count
end

local function CopyRecipeIDs(list)
    local ids = {}
    if type(list) ~= "table" then
        return ids
    end
    if list[1] then
        local index = 1
        while list[index] and index <= 5000 do
            local id = AsNumber(list[index])
            if id then
                ids[#ids + 1] = id
            end
            index = index + 1
        end
        return ids
    end
    pcall(function()
        for _, value in pairs(list) do
            local id = AsNumber(value)
            if id then
                ids[#ids + 1] = id
            end
            if #ids >= 5000 then
                break
            end
        end
    end)
    return ids
end

local function OutputLink(recipeID, info)
    local link = nil
    local icon = info and IconValue(info.icon) or nil
    local quality = nil
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeOutputItemData then
        local ok, output = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
        if ok and type(output) == "table" then
            link = SafeText(output.hyperlink)
            icon = icon or IconValue(output.icon)
            quality = AsNumber(output.quality)
        end
    end
    if not link and C_TradeSkillUI and C_TradeSkillUI.GetRecipeItemLink then
        local ok, value = pcall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
        if ok then
            link = SafeText(value)
        end
    end
    if not link and C_TradeSkillUI and C_TradeSkillUI.GetRecipeLink then
        local ok, value = pcall(C_TradeSkillUI.GetRecipeLink, recipeID)
        if ok then
            link = SafeText(value)
        end
    end
    return link, icon, quality
end

local function LearnedFlag(info)
    if type(info) ~= "table" then
        return true
    end
    local ok, flag = pcall(function()
        return info.learned
    end)
    if not ok or flag == nil then
        return true
    end
    if flag == false or flag == 0 then
        return false
    end
    return true
end

local function ModernRecipes()
    if not C_TradeSkillUI then
        return nil, false
    end
    local usedAll = false
    local ids = {}
    if C_TradeSkillUI.GetAllRecipeIDs then
        local ok, list = pcall(C_TradeSkillUI.GetAllRecipeIDs)
        if ok then
            ids = CopyRecipeIDs(list)
            usedAll = ids[1] ~= nil
        end
    end
    if not ids[1] and C_TradeSkillUI.GetFilteredRecipeIDs then
        local filtered = false
        if C_TradeSkillUI.GetRecipeItemNameFilter then
            local ok, filter = pcall(C_TradeSkillUI.GetRecipeItemNameFilter)
            if ok and RealName(filter) then
                filtered = true
            end
        end
        if not filtered then
            local ok, list = pcall(C_TradeSkillUI.GetFilteredRecipeIDs)
            if ok then
                ids = CopyRecipeIDs(list)
            end
        end
    end
    if not ids[1] or not C_TradeSkillUI.GetRecipeInfo then
        return nil, usedAll
    end
    local recipes = {}
    local index = 1
    while ids[index] do
        local recipeID = ids[index]
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        local name = ok and type(info) == "table" and RealName(info.name) or nil
        if name then
            local link, icon, quality = OutputLink(recipeID, info)
            recipes[#recipes + 1] = {
                id = recipeID,
                name = name,
                icon = icon,
                learned = LearnedFlag(info),
                quality = quality,
                link = link,
            }
        end
        index = index + 1
    end
    if not recipes[1] then
        return nil, usedAll
    end
    return recipes, usedAll
end

local function LinkID(link, fallback)
    if type(link) == "string" then
        local id = AsNumber(string.match(link, "enchant:(%d+)")) or AsNumber(string.match(link, "item:(%d+)"))
        if id then
            return id
        end
    end
    return fallback
end

local function ClassicRecipes()
    if type(GetNumTradeSkills) ~= "function" or type(GetTradeSkillInfo) ~= "function" then
        return nil
    end
    local ok, count = pcall(GetNumTradeSkills)
    count = ok and AsNumber(count) or 0
    if not count or count < 1 then
        return nil
    end
    if count > 2000 then
        count = 2000
    end
    local recipes = {}
    local index = 1
    while index <= count do
        local infoOk, name, skillType = pcall(GetTradeSkillInfo, index)
        local title = infoOk and RealName(name) or nil
        local kind = infoOk and SafeText(skillType) or nil
        if title and kind ~= "header" then
            local link = nil
            if type(GetTradeSkillItemLink) == "function" then
                local linkOk, value = pcall(GetTradeSkillItemLink, index)
                if linkOk then
                    link = SafeText(value)
                end
            end
            if not link and type(GetTradeSkillRecipeLink) == "function" then
                local linkOk, value = pcall(GetTradeSkillRecipeLink, index)
                if linkOk then
                    link = SafeText(value)
                end
            end
            local icon = nil
            if type(GetTradeSkillIcon) == "function" then
                local iconOk, value = pcall(GetTradeSkillIcon, index)
                if iconOk then
                    icon = IconValue(value)
                end
            end
            recipes[#recipes + 1] = {
                id = LinkID(link, title),
                name = title,
                icon = icon,
                learned = true,
                link = link,
            }
        end
        index = index + 1
    end
    if not recipes[1] then
        return nil
    end
    return recipes
end

local function OpenIdentity()
    local name, skillLine, skill, maxSkill, lineName, icon
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok and type(info) == "table" then
            name = RealName(info.parentProfessionName) or RealName(info.professionName)
            skillLine = AsNumber(info.parentProfessionID) or AsNumber(info.professionID)
            skill = AsNumber(info.skillLevel)
            maxSkill = AsNumber(info.maxSkillLevel)
            icon = IconValue(info.professionIcon or info.icon)
        end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetChildProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetChildProfessionInfo)
        if ok and type(info) == "table" then
            local childName = RealName(info.professionName)
            name = name or childName
            lineName = childName
            skillLine = skillLine or AsNumber(info.parentProfessionID) or AsNumber(info.professionID)
            skill = AsNumber(info.skillLevel) or skill
            maxSkill = AsNumber(info.maxSkillLevel) or maxSkill
            icon = icon or IconValue(info.professionIcon or info.icon)
        end
    end
    if not name and type(GetTradeSkillLine) == "function" then
        local ok, line = pcall(GetTradeSkillLine)
        if ok then
            name = RealName(line)
        end
    end
    if not lineName then
        lineName = name
    end
    return name, skillLine, skill, maxSkill, lineName, icon
end

local function NameFilterActive()
    if not C_TradeSkillUI or not C_TradeSkillUI.GetRecipeItemNameFilter then
        return false
    end
    local ok, filter = pcall(C_TradeSkillUI.GetRecipeItemNameFilter)
    if ok and RealName(filter) then
        return true
    end
    return false
end

function Scan.ReadOpenProfession()
    local record = PlayerRecord()
    if not record then
        return
    end
    if type(record.professions) ~= "table" then
        Scan.ReadProfessionList()
    end
    if type(record.professions) ~= "table" then
        record.professions = {}
    end
    local name, skillLine, skill, maxSkill, lineName, icon = OpenIdentity()
    if not name then
        if professionTries < 5 and not professionWait and C_Timer and C_Timer.After then
            professionTries = professionTries + 1
            professionWait = true
            C_Timer.After(0.6, function()
                professionWait = false
                Scan.ReadOpenProfession()
            end)
        end
        return
    end
    local known = ProfessionByName(name)
    if not skillLine and known then
        skillLine = known.line
    end
    local primary = true
    if known then
        primary = not known.secondary
    end
    local row = TakeProfession(record.professions, record.professions, {
        name = name,
        skillLine = skillLine,
        skill = skill,
        maxSkill = maxSkill,
        primary = primary,
        lineName = lineName,
        icon = icon or (known and SpellIcon(known.spell) or nil),
    })
    local recipes, usedAll = ModernRecipes()
    if not recipes then
        recipes = ClassicRecipes()
        usedAll = false
    end
    local line = row and EnsureLine(row, lineName or name, skillLine, skill, maxSkill) or nil
    local saved = false
    if line and recipes and recipes[1] then
        local oldCount = RecipeCount(line.recipes)
        local newCount = RecipeCount(recipes)
        if usedAll or newCount >= oldCount or NameFilterActive() == false and oldCount == 0 then
            if not (NameFilterActive() and not usedAll and oldCount > newCount) then
                line.recipes = recipes
                line.scanned = true
                line.scannedAt = time()
                row.scanned = true
                saved = true
            end
        end
    end
    if saved then
        professionTries = 0
    elseif professionTries < 5 and not professionWait and C_Timer and C_Timer.After then
        professionTries = professionTries + 1
        professionWait = true
        C_Timer.After(0.6, function()
            professionWait = false
            Scan.ReadOpenProfession()
        end)
        return
    elseif line and not line.scanned then
        line.recipes = {}
        line.scanned = true
        line.scannedAt = time()
        if row then
            row.scanned = true
        end
    end
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

function Scan.OnProfession()
    professionTries = 0
    if professionWait or not C_Timer or not C_Timer.After then
        Scan.ReadOpenProfession()
        return
    end
    professionWait = true
    C_Timer.After(0.4, function()
        professionWait = false
        Scan.ReadOpenProfession()
    end)
end
end

do
local function Flag(value)
    local ok, result = pcall(function()
        return value == true or value == 1
    end)
    return ok and result or false
end

local function RealName(value)
    local text = SafeText(value)
    if not text or string.match(text, "^%d+$") then
        return nil
    end
    return text
end

local function IconValue(value)
    local number = AsNumber(value)
    if number and number > 0 then
        return number
    end
    return SafeText(value)
end

local function CurrencyTag(name, info)
    local plain = string.gsub(name, "’", "'")
    if plain == "Trader's Tender" then
        return "account"
    end
    if plain == "Honor" or plain == "Honor Points" then
        return "pvp"
    end
    if type(info) == "table" and Flag(info.isAccountWide) then
        return "account"
    end
    return nil
end

local function ListSize()
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        local ok, value = pcall(C_CurrencyInfo.GetCurrencyListSize)
        local size = ok and AsNumber(value) or 0
        if size and size > 0 then
            return size
        end
    end
    if type(GetCurrencyListSize) == "function" then
        local ok, value = pcall(GetCurrencyListSize)
        local size = ok and AsNumber(value) or 0
        if size and size > 0 then
            return size
        end
    end
    return 0
end

local function ReadCurrencyInfo(index)
    local ok, first, second, third, fourth, _, sixth, seventh, eighth
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListInfo then
        ok, first, second, third, fourth, _, sixth, seventh, eighth = pcall(C_CurrencyInfo.GetCurrencyListInfo, index)
    end
    if (not ok or first == nil) and type(GetCurrencyListInfo) == "function" then
        ok, first, second, third, fourth, _, sixth, seventh, eighth = pcall(GetCurrencyListInfo, index)
    end
    if not ok or first == nil then
        return nil
    end
    if type(first) == "table" then
        return first
    end
    return {
        name = first,
        isHeader = second,
        isHeaderExpanded = third,
        isTypeUnused = fourth,
        quantity = sixth,
        iconFileID = seventh,
        maxQuantity = eighth,
    }
end

local function HeaderCollapsed(info)
    if not info then
        return false
    end
    if Flag(info.isHeaderExpanded) or Flag(info.isExpanded) then
        return false
    end
    local ok, result = pcall(function()
        return info.isHeaderExpanded == false or info.isHeaderExpanded == 0 or info.isExpanded == false or info.isExpanded == 0
    end)
    return ok and result or false
end

local function ExpandAt(index)
    if C_CurrencyInfo and C_CurrencyInfo.ExpandCurrencyList then
        pcall(C_CurrencyInfo.ExpandCurrencyList, index, true)
        return
    end
    if type(ExpandCurrencyList) == "function" then
        pcall(ExpandCurrencyList, index, true)
    end
end

local function ExpandHeaders()
    local pass = 1
    while pass <= 4 do
        local size = ListSize()
        if size < 1 then
            return
        end
        if size > 400 then
            size = 400
        end
        local grew = false
        local index = 1
        while index <= size do
            local info = ReadCurrencyInfo(index)
            if info and RealName(info.name) and Flag(info.isHeader) and HeaderCollapsed(info) then
                local before = ListSize()
                ExpandAt(index)
                local after = ListSize()
                if after > before then
                    grew = true
                    size = after
                    if size > 400 then
                        size = 400
                    end
                end
            end
            index = index + 1
        end
        if not grew then
            return
        end
        pass = pass + 1
    end
end

local function LinkID(index)
    local function parse(link)
        local text = SafeText(link)
        if not text then
            return nil
        end
        return AsNumber(string.match(text, "currency:(%d+)"))
    end
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListLink then
        local ok, link = pcall(C_CurrencyInfo.GetCurrencyListLink, index)
        if ok then
            local id = parse(link)
            if id then
                return id
            end
        end
    end
    if type(GetCurrencyListLink) == "function" then
        local ok, link = pcall(GetCurrencyListLink, index)
        if ok then
            return parse(link)
        end
    end
    return nil
end

local function SavedCount(record)
    local count = 0
    if type(record.currencies) ~= "table" then
        return 0
    end
    while record.currencies[count + 1] do
        count = count + 1
    end
    return count
end

local KNOWN_CURRENCIES = {
    { id = 1792, header = "Player vs. Player", name = "Honor Points" },
    { id = 3468, header = "Player vs. Player", name = "Rank Points" },
    { id = 3469, header = "Dungeon and Raid", name = "Tarnished Undermine Real" },
    { id = 3402, header = "Professions & Tradeskills", name = "Merchant's Favor" },
    { id = 515, header = "Miscellaneous", name = "Darkmoon Prize Ticket" },
}

local function InfoByID(currencyID)
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then
        return nil
    end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
    if ok and type(info) == "table" then
        return info
    end
    return nil
end

local cachedHeaders = nil

local function CategoryHeaders()
    if cachedHeaders then
        return cachedHeaders
    end
    local found = {}
    if not C_CurrencyInfo or not C_CurrencyInfo.GetPlayerCurrencyCategoryInfo then
        return found
    end
    local wanted = {}
    local knownIndex = 1
    while KNOWN_CURRENCIES[knownIndex] do
        wanted[KNOWN_CURRENCIES[knownIndex].id] = true
        knownIndex = knownIndex + 1
    end
    local id = 1
    while id <= 120 do
        local ok, info = pcall(C_CurrencyInfo.GetPlayerCurrencyCategoryInfo, id)
        local header = ok and type(info) == "table" and RealName(info.categoryName or info.name) or nil
        local listed = header and header ~= "Unknown" and (info.currencyTypes or info.currencyIDs or info.currencies) or nil
        if header and type(listed) == "table" then
            if listed[1] then
                local index = 1
                while listed[index] do
                    local currencyID = AsNumber(listed[index])
                    if currencyID and wanted[currencyID] and not found[currencyID] then
                        found[currencyID] = header
                    end
                    index = index + 1
                end
            else
                pcall(function()
                    for _, value in pairs(listed) do
                        local currencyID = AsNumber(value)
                        if currencyID and wanted[currencyID] and not found[currencyID] then
                            found[currencyID] = header
                        end
                    end
                end)
            end
        end
        id = id + 1
    end
    cachedHeaders = found
    return found
end

local function CollectCurrencies()
    local size = ListSize()
    if size > 400 then
        size = 400
    end
    local sections = {}
    local current = nil
    local seen = {}
    local index = 1
    while size > 0 and index <= size do
        local info = ReadCurrencyInfo(index)
        local name = info and RealName(info.name) or nil
        if info and name and Flag(info.isHeader) then
            current = {
                name = name,
                depth = AsNumber(info.depth) or 0,
                rows = {},
            }
            sections[#sections + 1] = current
        elseif info and name then
            if not current then
                current = { name = "", depth = 0, rows = {} }
                sections[#sections + 1] = current
            end
            local amount = AsNumber(info.quantity)
            if not amount or amount < 0 then
                amount = 0
            end
            local maxQty = AsNumber(info.maxQuantity)
            if not maxQty or maxQty <= 0 then
                maxQty = nil
            end
            local row = {
                id = AsNumber(info.currencyID) or AsNumber(info.currencyTypesID) or LinkID(index),
                name = name,
                icon = IconValue(info.iconFileID),
                expansion = current.name,
                amount = amount,
                max = maxQty,
                tag = CurrencyTag(name, info),
            }
            current.rows[#current.rows + 1] = row
            if row.id then
                seen[row.id] = true
            end
        end
        index = index + 1
    end
    local headers = CategoryHeaders()
    local knownIndex = 1
    while KNOWN_CURRENCIES[knownIndex] do
        local known = KNOWN_CURRENCIES[knownIndex]
        if not seen[known.id] then
            local info = InfoByID(known.id)
            local name = info and RealName(info.name) or known.name
            local amount = info and AsNumber(info.quantity) or 0
            if not amount or amount < 0 then
                amount = 0
            end
            local maxQty = info and AsNumber(info.maxQuantity) or nil
            if not maxQty or maxQty <= 0 then
                maxQty = nil
            end
            local headerName = headers[known.id] or known.header
            local section = nil
            local sectionIndex = 1
            while sections[sectionIndex] do
                if sections[sectionIndex].name == headerName then
                    section = sections[sectionIndex]
                end
                sectionIndex = sectionIndex + 1
            end
            if not section then
                section = { name = headerName, depth = 0, rows = {} }
                sections[#sections + 1] = section
            end
            section.rows[#section.rows + 1] = {
                id = known.id,
                name = name,
                icon = info and IconValue(info.iconFileID) or nil,
                expansion = headerName,
                amount = amount,
                max = maxQty,
                tag = CurrencyTag(name, info),
            }
            seen[known.id] = true
        end
        knownIndex = knownIndex + 1
    end
    local keptSections = {}
    local kept = {}
    local sectionIndex = 1
    while sections[sectionIndex] do
        local section = sections[sectionIndex]
        if section.rows[1] then
            keptSections[#keptSections + 1] = section
            local rowIndex = 1
            while section.rows[rowIndex] do
                kept[#kept + 1] = section.rows[rowIndex]
                rowIndex = rowIndex + 1
            end
        end
        sectionIndex = sectionIndex + 1
    end
    return { currencies = kept, sections = keptSections, size = size }
end

local function PlayerRecord()
    local guid = UnitGUID("player")
    if not guid or not BMGAM.DB then
        return nil
    end
    return BMGAM.DB.Get(guid)
end

function Scan.ReadCurrencies()
    if currencyScan or currencyWait then
        return
    end
    local record = PlayerRecord()
    if not record then
        return
    end
    currencyScan = true
    if not currencyExpanded then
        ExpandHeaders()
        currencyExpanded = true
    end
    local pack = CollectCurrencies()
    currencyScan = false
    local oldCount = SavedCount(record)
    local newCount = 0
    if pack and type(pack.currencies) == "table" then
        while pack.currencies[newCount + 1] do
            newCount = newCount + 1
        end
    end
    if newCount > 0 then
        record.currencies = pack.currencies
        record.currencySections = pack.sections
        currencyTries = 0
        return
    end
    if not pack or not pack.size or pack.size < 1 then
        if oldCount > 0 then
            return
        end
        if currencyTries < 3 and C_Timer and C_Timer.After then
            currencyTries = currencyTries + 1
            currencyExpanded = false
            currencyWait = true
            C_Timer.After(1, function()
                currencyWait = false
                Scan.ReadCurrencies()
                if BMGAM.Window and BMGAM.Window.Refresh then
                    BMGAM.Window.Refresh()
                end
            end)
            return
        end
        record.currencies = {}
        record.currencySections = {}
        return
    end
    record.currencies = pack.currencies
    record.currencySections = pack.sections
    currencyTries = 0
end
end

do
local function Flag(value)
    local ok, result = pcall(function()
        return value == true or value == 1
    end)
    return ok and result or false
end

local function RealName(value)
    local text = SafeText(value)
    if not text or string.match(text, "^%d+$") then
        return nil
    end
    return text
end

local function StandingLabel(reaction)
    local index = AsNumber(reaction)
    if not index then
        return ""
    end
    local key = "FACTION_STANDING_LABEL" .. tostring(math.floor(index))
    local label = _G[key]
    return SafeText(label) or ""
end

local function SideName(name)
    if not name then
        return false
    end
    local alliance = SafeText(FACTION_ALLIANCE) or "Alliance"
    local horde = SafeText(FACTION_HORDE) or "Horde"
    return name == alliance or name == horde or name == "Alliance" or name == "Horde"
end

local function FriendshipLabel(factionID)
    if not factionID or not C_GossipInfo or not C_GossipInfo.GetFriendshipReputation then
        return nil
    end
    local ok, info = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
    if not ok or type(info) ~= "table" then
        return nil
    end
    local id = AsNumber(info.friendshipFactionID)
    if not id or id <= 0 then
        return nil
    end
    return RealName(info.reaction) or RealName(info.text)
end

local function FactionCount()
    if C_Reputation and C_Reputation.GetNumFactions then
        local ok, value = pcall(C_Reputation.GetNumFactions)
        local size = ok and AsNumber(value) or 0
        if size and size > 0 then
            return size
        end
    end
    if type(GetNumFactions) == "function" then
        local ok, value = pcall(GetNumFactions)
        local size = ok and AsNumber(value) or 0
        if size and size > 0 then
            return size
        end
    end
    return 0
end

local function ReadFaction(index)
    if C_Reputation and C_Reputation.GetFactionDataByIndex then
        local ok, data = pcall(C_Reputation.GetFactionDataByIndex, index)
        if ok and type(data) == "table" then
            return data
        end
    end
    if type(GetFactionInfo) ~= "function" then
        return nil
    end
    local ok, name, _, standingID, barMin, barMax, barValue, _, _, isHeader, isCollapsed, hasRep, _, isChild, factionID = pcall(GetFactionInfo, index)
    if not ok or name == nil then
        return nil
    end
    return {
        name = name,
        factionID = factionID,
        reaction = standingID,
        currentReactionThreshold = barMin,
        nextReactionThreshold = barMax,
        currentStanding = barValue,
        isHeader = isHeader,
        isCollapsed = isCollapsed,
        isHeaderWithRep = hasRep,
        isChild = isChild,
    }
end

local function HeaderCollapsed(info)
    if not info or not Flag(info.isHeader) then
        return false
    end
    if Flag(info.isCollapsed) then
        return true
    end
    local ok, result = pcall(function()
        return info.isHeaderExpanded == false or info.isHeaderExpanded == 0
    end)
    return ok and result or false
end

local function ExpandAt(index)
    if C_Reputation and C_Reputation.ExpandFactionHeader then
        pcall(C_Reputation.ExpandFactionHeader, index)
    end
    if type(ExpandFactionHeader) == "function" then
        pcall(ExpandFactionHeader, index)
    end
end

local function CollapseAt(index)
    if C_Reputation and C_Reputation.CollapseFactionHeader then
        pcall(C_Reputation.CollapseFactionHeader, index)
    end
    if type(CollapseFactionHeader) == "function" then
        pcall(CollapseFactionHeader, index)
    end
end

local function CollapsedNames()
    local names = {}
    local size = FactionCount()
    if size > 500 then
        size = 500
    end
    local index = 1
    while index <= size do
        local info = ReadFaction(index)
        local name = info and RealName(info.name) or nil
        if name and HeaderCollapsed(info) then
            names[name] = true
        end
        index = index + 1
    end
    return names
end

local function ExpandAll()
    if C_Reputation and C_Reputation.ExpandAllFactionHeaders then
        pcall(C_Reputation.ExpandAllFactionHeaders)
    end
    ExpandAt(0)
    local guard = 0
    while guard < 12 do
        guard = guard + 1
        local size = FactionCount()
        if size > 500 then
            size = 500
        end
        local grew = false
        local index = 1
        while index <= size do
            local info = ReadFaction(index)
            if HeaderCollapsed(info) then
                local before = size
                ExpandAt(index)
                size = FactionCount()
                if size > 500 then
                    size = 500
                end
                if size > before then
                    grew = true
                end
            end
            index = index + 1
        end
        if not grew then
            return
        end
    end
end

local function RestoreCollapsed(names)
    local size = FactionCount()
    if size > 500 then
        size = 500
    end
    local index = size
    while index >= 1 do
        local info = ReadFaction(index)
        local name = info and RealName(info.name) or nil
        if name and names[name] and Flag(info.isHeader) and not HeaderCollapsed(info) then
            CollapseAt(index)
        end
        index = index - 1
    end
end

local function MakeRow(info, group)
    local name = RealName(info.name)
    if not name then
        return nil
    end
    local id = AsNumber(info.factionID)
    local current = AsNumber(info.currentStanding)
    if current == nil then
        current = 0
    end
    local floor = AsNumber(info.currentReactionThreshold)
    local maximum = AsNumber(info.nextReactionThreshold)
    if maximum == nil then
        maximum = 0
    end
    local reaction = AsNumber(info.reaction)
    local standing = FriendshipLabel(id) or StandingLabel(reaction)
    local row = {
        id = id,
        name = name,
        group = group,
        kind = "standard",
        standing = standing,
        current = current,
        maximum = maximum,
        reaction = reaction,
    }
    if floor then
        row.floor = floor
    end
    return row
end

local KNOWN_FACTIONS = {
    { header = "Alliance", id = 69, name = "Darnassus" },
    { header = "Alliance", id = 54, name = "Gnomeregan Exiles" },
    { header = "Alliance", id = 47, name = "Ironforge" },
    { header = "Alliance", id = 72, name = "Stormwind" },
    { header = "Alliance Forces", id = 890, name = "Silverwing Sentinels" },
    { header = "Alliance Forces", id = 730, name = "Stormpike Guard" },
    { header = "Alliance Forces", id = 509, name = "The League of Arathor" },
    { header = "Alliance Forces", id = 2799, name = "Theramore Expeditionary Force" },
    { header = "Horde", id = 530, name = "Darkspear Trolls" },
    { header = "Horde", id = 76, name = "Orgrimmar" },
    { header = "Horde", id = 81, name = "Thunder Bluff" },
    { header = "Horde", id = 68, name = "Undercity" },
    { header = "Horde Forces", id = 2798, name = "Darkspear Raiders" },
    { header = "Horde Forces", id = 729, name = "Frostwolf Clan" },
    { header = "Horde Forces", id = 510, name = "The Defilers" },
    { header = "Horde Forces", id = 889, name = "Warsong Outriders" },
    { header = "Steamwheedle Cartel", id = 21, name = "Booty Bay" },
    { header = "Steamwheedle Cartel", id = 577, name = "Everlook" },
    { header = "Steamwheedle Cartel", id = 369, name = "Gadgetzan" },
    { header = "Steamwheedle Cartel", id = 2827, name = "Powderfuse" },
    { header = "Steamwheedle Cartel", id = 470, name = "Ratchet" },
    { header = "Other", id = 529, name = "Argent Dawn" },
    { header = "Other", id = 2586, name = "Azeroth Commerce Authority" },
    { header = "Other", id = 2747, name = "Barkskin Burrow" },
    { header = "Other", id = 87, name = "Bloodsail Buccaneers" },
    { header = "Other", id = 2782, name = "Bolder'ok Clan" },
    { header = "Other", id = 910, name = "Brood of Nozdormu" },
    { header = "Other", id = 2826, name = "Brotherhood of the Horse" },
    { header = "Other", id = 609, name = "Cenarion Circle" },
    { header = "Other", id = 2719, name = "Cenarion Scouts" },
    { header = "Other", id = 909, name = "Darkmoon Faire" },
    { header = "Other", id = 2587, name = "Durotar Supply and Logistics" },
    { header = "Other", id = 2787, name = "Earthen Ring" },
    { header = "Other", id = 2641, name = "Emerald Wardens" },
    { header = "Other", id = 92, name = "Gelkis Clan Centaur" },
    { header = "Other", id = 2765, name = "Guardians of Hyjal" },
    { header = "Other", id = 2779, name = "High Order" },
    { header = "Other", id = 749, name = "Hydraxian Waterlords" },
    { header = "Other", id = 2740, name = "Kirin Tor" },
    { header = "Other", id = 93, name = "Magram Clan Centaur" },
    { header = "Other", id = 2758, name = "Nightclaw Druids" },
    { header = "Other", id = 630, name = "Ravasaur Trainers" },
    { header = "Other", id = 349, name = "Ravenholdt" },
    { header = "Other", id = 809, name = "Shen'dralar" },
    { header = "Other", id = 70, name = "Syndicate" },
    { header = "Other", id = 2819, name = "The Watchers" },
    { header = "Other", id = 59, name = "Thorium Brotherhood" },
    { header = "Other", id = 576, name = "Timbermaw Hold" },
    { header = "Other", id = 471, name = "Wildhammer Clan" },
    { header = "Other", id = 2778, name = "Windshapers" },
    { header = "Other", id = 589, name = "Wintersaber Trainers" },
    { header = "Other", id = 270, name = "Zandalar Tribe" },
}

local function FactionByID(factionID)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
        if ok and type(data) == "table" and RealName(data.name) then
            return data
        end
    end
    if type(GetFactionInfoByID) ~= "function" then
        return nil
    end
    local ok, name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, hasRep, _, isChild, returnedID = pcall(GetFactionInfoByID, factionID)
    if not ok or name == nil then
        return nil
    end
    return {
        name = name,
        factionID = returnedID or factionID,
        reaction = standingID,
        currentReactionThreshold = barMin,
        nextReactionThreshold = barMax,
        currentStanding = barValue,
        isHeader = isHeader,
        isHeaderWithRep = hasRep,
        isChild = isChild,
    }
end

local function IndexRows(sections)
    local byID = {}
    local byName = {}
    local sectionIndex = 1
    while sections[sectionIndex] do
        local section = sections[sectionIndex]
        local headerRow = section.headerRow
        if type(headerRow) == "table" then
            if headerRow.id then
                byID[headerRow.id] = headerRow
            end
            if headerRow.name then
                byName[headerRow.name] = headerRow
            end
        end
        local rowIndex = 1
        while section.rows[rowIndex] do
            local row = section.rows[rowIndex]
            if row.id then
                byID[row.id] = row
            end
            if row.name then
                byName[row.name] = row
            end
            rowIndex = rowIndex + 1
        end
        sectionIndex = sectionIndex + 1
    end
    return byID, byName
end

local function WithKnown(sections)
    local byID, byName = IndexRows(sections)
    local used = {}
    local grouped = {}
    local order = {}
    local index = 1
    while KNOWN_FACTIONS[index] do
        local known = KNOWN_FACTIONS[index]
        local header = known.header
        if not grouped[header] then
            grouped[header] = { name = header, depth = 0, rows = {} }
            order[#order + 1] = header
        end
        local row = nil
        if known.id and byID[known.id] then
            row = byID[known.id]
        elseif byName[known.name] then
            row = byName[known.name]
        end
        if row then
            used[row] = true
        else
            local info = FactionByID(known.id)
            if not info then
                info = {
                    name = known.name,
                    factionID = known.id,
                    reaction = 4,
                    currentStanding = 0,
                    currentReactionThreshold = 0,
                    nextReactionThreshold = 3000,
                }
            else
                if AsNumber(info.currentStanding) == nil then
                    info.currentStanding = 0
                end
                if AsNumber(info.reaction) == nil then
                    info.reaction = 4
                end
                if AsNumber(info.nextReactionThreshold) == nil then
                    info.currentReactionThreshold = 0
                    info.nextReactionThreshold = 3000
                end
            end
            row = MakeRow(info, header)
        end
        if row then
            row.group = header
            grouped[header].rows[#grouped[header].rows + 1] = row
        end
        index = index + 1
    end
    local result = {}
    local orderIndex = 1
    while order[orderIndex] do
        local section = grouped[order[orderIndex]]
        local liveIndex = 1
        while sections[liveIndex] do
            local live = sections[liveIndex]
            if live.name == section.name and type(live.headerRow) == "table" and not used[live.headerRow] then
                section.headerRow = live.headerRow
                used[live.headerRow] = true
            end
            liveIndex = liveIndex + 1
        end
        result[#result + 1] = section
        orderIndex = orderIndex + 1
    end
    local liveIndex = 1
    while sections[liveIndex] do
        local live = sections[liveIndex]
        local extraRows = {}
        local rowIndex = 1
        while live.rows[rowIndex] do
            local row = live.rows[rowIndex]
            if not used[row] then
                extraRows[#extraRows + 1] = row
                used[row] = true
            end
            rowIndex = rowIndex + 1
        end
        local extraHeader = nil
        if type(live.headerRow) == "table" and not used[live.headerRow] then
            extraHeader = live.headerRow
            used[live.headerRow] = true
        end
        if extraHeader or extraRows[1] then
            result[#result + 1] = {
                name = live.name or "",
                depth = live.depth or 0,
                rows = extraRows,
                headerRow = extraHeader,
            }
        end
        liveIndex = liveIndex + 1
    end
    return result
end

local function CollectReputations()
    local collapsed = CollapsedNames()
    ExpandAll()
    local size = FactionCount()
    if size > 500 then
        size = 500
    end
    local sections = {}
    local current = nil
    local index = 1
    while size > 0 and index <= size do
        local info = ReadFaction(index)
        local name = info and RealName(info.name) or nil
        if info and name and Flag(info.isHeader) then
            local depth = Flag(info.isChild) and 1 or 0
            current = { name = name, depth = depth, rows = {} }
            if Flag(info.isHeaderWithRep) then
                current.headerRow = MakeRow(info, name)
            end
            sections[#sections + 1] = current
        elseif info and name and not SideName(name) then
            if not current then
                current = { name = "", depth = 0, rows = {} }
                sections[#sections + 1] = current
            end
            local row = MakeRow(info, current.name)
            if row then
                current.rows[#current.rows + 1] = row
            end
        end
        index = index + 1
    end
    RestoreCollapsed(collapsed)
    local kept = {}
    local sectionIndex = 1
    while sections[sectionIndex] do
        local section = sections[sectionIndex]
        if section.headerRow or section.rows[1] then
            kept[#kept + 1] = section
        end
        sectionIndex = sectionIndex + 1
    end
    return WithKnown(kept)
end

local function PlayerRecord()
    local guid = UnitGUID("player")
    if not guid or not BMGAM.DB then
        return nil
    end
    return BMGAM.DB.Get(guid)
end

function Scan.ReadReputations(force)
    if reputationScan or reputationWait then
        return
    end
    local record = PlayerRecord()
    if not record then
        return
    end
    if not force and reputationReady and type(record.reputationSections) == "table" and record.reputationSections[1] then
        return
    end
    reputationScan = true
    local sections = CollectReputations()
    reputationScan = false
    local count = 0
    while type(sections) == "table" and sections[count + 1] do
        count = count + 1
    end
    if count < 1 then
        if reputationTries < 4 and C_Timer and C_Timer.After then
            reputationTries = reputationTries + 1
            reputationWait = true
            C_Timer.After(1, function()
                reputationWait = false
                Scan.ReadReputations(true)
                if BMGAM.Window and BMGAM.Window.Refresh then
                    BMGAM.Window.Refresh()
                end
            end)
        end
        return
    end
    record.reputationSections = sections
    reputationReady = true
    reputationTries = 0
end
end

do
local mailboxOpen = false
local inboxUpdated = false
local pendingSend = nil

local function TrueFlag(value)
    local ok, result = pcall(function()
        return value == true or value == 1
    end)
    return ok and result or false
end

local function MailRecord(record)
    if type(record.mail) ~= "table" then
        record.mail = {}
    end
    if type(record.mail.letters) ~= "table" then
        record.mail.letters = {}
    end
    if type(record.mail.sent) ~= "table" then
        record.mail.sent = {}
    end
    return record.mail
end

local function AttachmentName(itemID, link)
    if itemID and C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        name = ok and SafeText(name) or nil
        if name then
            return name
        end
    end
    if type(link) == "string" then
        return SafeText(string.match(link, "%[(.-)%]"))
    end
    return nil
end

local function AttachmentIcon(itemID, texture)
    if texture and texture ~= 0 and texture ~= "" then
        return texture
    end
    if itemID and C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon and icon ~= 0 and icon ~= "" then
            return icon
        end
    end
    if itemID and type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon and icon ~= 0 and icon ~= "" then
            return icon
        end
    end
    return nil
end

local function AttachmentQuality(itemID, reported)
    local quality = AsNumber(reported)
    if quality then
        return quality
    end
    if itemID and C_Item and C_Item.GetItemQualityByID then
        local ok, value = pcall(C_Item.GetItemQualityByID, itemID)
        quality = ok and AsNumber(value) or nil
        if quality then
            return quality
        end
    end
    return 1
end

local function ReadSendAttachments()
    local items = {}
    local limit = ATTACHMENTS_MAX_SEND or 12
    local slot = 1
    while slot <= limit do
        local name, itemID, texture, count, quality
        if type(GetSendMailItem) == "function" then
            local ok, a, b, c, d, e = pcall(GetSendMailItem, slot)
            if ok then
                name = SafeText(a)
                itemID = AsNumber(b)
                texture = c
                count = AsNumber(d)
                quality = e
            end
        end
        local link
        if type(GetSendMailItemLink) == "function" then
            local ok, value = pcall(GetSendMailItemLink, slot)
            if ok then
                link = SafeText(value)
            end
        end
        if itemID and itemID > 0 then
            if not name then
                name = AttachmentName(itemID, link)
            end
            if not count or count < 1 then
                count = 1
            end
            items[#items + 1] = {
                itemID = itemID,
                link = link,
                name = name,
                quality = AttachmentQuality(itemID, quality),
                icon = AttachmentIcon(itemID, texture),
                count = count,
            }
        end
        slot = slot + 1
    end
    return items
end

local function FindAlt(recipient)
    local text = SafeText(recipient)
    if not text or text == "" or not BMGAM.DB or not BMGAM.DB.List then
        return nil
    end
    local name, realm = string.match(text, "^(.-)%-(.+)$")
    if not name or name == "" then
        name = text
        realm = nil
    end
    name = string.lower(name)
    if realm then
        realm = string.lower(realm)
    end
    local playerRealm = ""
    if type(GetRealmName) == "function" then
        playerRealm = string.lower(SafeText(GetRealmName()) or "")
    end
    local list = BMGAM.DB.List()
    local sameRealm = nil
    local only = nil
    local count = 0
    local index = 1
    while list[index] do
        local record = list[index]
        local recordName = string.lower(record.name or "")
        if recordName == name then
            local recordRealm = string.lower(record.realm or "")
            if realm and recordRealm == realm then
                return record
            end
            if recordRealm == playerRealm then
                sameRealm = record
            end
            only = record
            count = count + 1
        end
        index = index + 1
    end
    if sameRealm then
        return sameRealm
    end
    if count == 1 then
        return only
    end
    return nil
end

local function CaptureOutgoing(recipient, subject)
    if type(GetSendMailCOD) == "function" then
        local ok, cod = pcall(GetSendMailCOD)
        if ok and (AsNumber(cod) or 0) > 0 then
            pendingSend = nil
            return
        end
    end
    local money = 0
    if type(GetSendMailMoney) == "function" then
        local ok, value = pcall(GetSendMailMoney)
        if ok then
            money = AsNumber(value) or 0
        end
    end
    pendingSend = {
        recipient = SafeText(recipient),
        subject = SafeText(subject) or "",
        money = money,
        items = ReadSendAttachments(),
        at = time(),
    }
end

local function ReadInboxAttachment(index, slot)
    local name, itemID, texture, count, quality
    if type(GetInboxItem) == "function" then
        local ok, a, b, c, d, e = pcall(GetInboxItem, index, slot)
        if ok then
            name = SafeText(a)
            itemID = AsNumber(b)
            texture = c
            count = AsNumber(d)
            quality = e
        end
    end
    local link
    if type(GetInboxItemLink) == "function" then
        local ok, value = pcall(GetInboxItemLink, index, slot)
        if ok then
            link = SafeText(value)
        end
    end
    if not itemID or itemID < 1 then
        return nil
    end
    if not name then
        name = AttachmentName(itemID, link)
    end
    if not count or count < 1 then
        count = 1
    end
    return {
        itemID = itemID,
        link = link,
        name = name,
        quality = AttachmentQuality(itemID, quality),
        icon = AttachmentIcon(itemID, texture),
        count = count,
    }
end

local function HeaderFields(index)
    if type(GetInboxHeaderInfo) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e, f, g, h, i = pcall(GetInboxHeaderInfo, index)
    if not ok or a == nil then
        return nil
    end
    if type(a) == "table" then
        return {
            sender = SafeText(a.sender),
            subject = SafeText(a.subject) or "",
            money = AsNumber(a.money) or 0,
            codAmount = AsNumber(a.codAmount or a.CODAmount) or 0,
            daysLeft = AsNumber(a.daysLeft),
            read = TrueFlag(a.wasRead or a.read),
        }
    end
    return {
        sender = SafeText(c),
        subject = SafeText(d) or "",
        money = AsNumber(e) or 0,
        codAmount = AsNumber(f) or 0,
        daysLeft = AsNumber(g),
        read = TrueFlag(i),
    }
end

local function ReadInboxLetter(index)
    local header = HeaderFields(index)
    if not header then
        return nil
    end
    if header.codAmount > 0 then
        return nil
    end
    if not header.sender and header.subject == "" then
        return nil
    end
    local items = {}
    local slot = 1
    local limit = ATTACHMENTS_MAX_RECEIVE or 16
    while slot <= limit do
        local item = ReadInboxAttachment(index, slot)
        if item then
            items[#items + 1] = item
        end
        slot = slot + 1
    end
    return {
        kind = "inbox",
        sender = header.sender or "",
        subject = header.subject,
        money = header.money,
        daysLeft = header.daysLeft,
        markedAt = time(),
        read = header.read,
        items = items,
    }
end

local function ReadInboxLetters()
    if type(GetInboxNumItems) ~= "function" or type(GetInboxHeaderInfo) ~= "function" then
        return nil
    end
    local ok, numItems, totalItems = pcall(GetInboxNumItems)
    if not ok then
        return nil
    end
    numItems = AsNumber(numItems) or 0
    totalItems = AsNumber(totalItems) or numItems
    if totalItems > numItems and type(CheckInbox) == "function" and C_Mail and C_Mail.CanCheckInbox then
        local canOk, canCheck = pcall(C_Mail.CanCheckInbox)
        if canOk and canCheck == true then
            pcall(CheckInbox)
        end
    end
    local letters = {}
    local index = 1
    while index <= numItems and index <= 250 do
        local letter = ReadInboxLetter(index)
        if letter then
            letters[#letters + 1] = letter
        end
        index = index + 1
    end
    return letters, numItems, totalItems
end

function Scan.ReadMailNotice()
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB and BMGAM.DB.Get(guid) or nil
    if not record and guid and BMGAM.DB and BMGAM.DB.Ensure then
        record = BMGAM.DB.Ensure(guid)
    end
    if not record then
        return
    end
    local mail = MailRecord(record)
    mail.noticeChecked = true
    local has = false
    if type(HasNewMail) == "function" then
        local ok, value = pcall(HasNewMail)
        if ok then
            has = TrueFlag(value)
        end
    end
    if not has and MiniMapMailFrame and MiniMapMailFrame.IsShown then
        local shownOk, shown = pcall(MiniMapMailFrame.IsShown, MiniMapMailFrame)
        if shownOk and shown then
            has = true
        end
    end
    if not has then
        mail.notice = nil
        mail.noticeAt = nil
        return
    end
    local senders = {}
    if type(GetLatestThreeSenders) == "function" then
        local sentOk, first, second, third = pcall(GetLatestThreeSenders)
        if sentOk then
            local names = { first, second, third }
            local index = 1
            while names[index] ~= nil do
                local text = SafeText(names[index])
                if text then
                    senders[#senders + 1] = text
                end
                index = index + 1
            end
        end
    end
    if not senders[1] then
        senders[1] = ""
    end
    mail.notice = senders
    mail.noticeAt = time()
end

function Scan.ReadOpenMailbox()
    if not mailboxOpen then
        return
    end
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB and BMGAM.DB.Get(guid) or nil
    if not record then
        return
    end
    local letters, numItems = ReadInboxLetters()
    if not letters then
        return
    end
    if (numItems or 0) < 1 and not inboxUpdated then
        return
    end
    if numItems > 0 and not letters[1] then
        return
    end
    local mail = MailRecord(record)
    local now = time()
    mail.scanned = true
    mail.scannedAt = now
    mail.letters = letters
    mail.notice = nil
    mail.noticeAt = nil
    local kept = {}
    local index = 1
    while mail.sent[index] do
        local sentAt = mail.sent[index].markedAt or 0
        if sentAt > now then
            kept[#kept + 1] = mail.sent[index]
        end
        index = index + 1
    end
    mail.sent = kept
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

function Scan.OnInboxUpdate()
    if not mailboxOpen then
        return
    end
    inboxUpdated = true
    Scan.ReadOpenMailbox()
end

function Scan.OnMailbox(opened)
    mailboxOpen = opened and true or false
    if not mailboxOpen then
        inboxUpdated = false
        return
    end
    if type(CheckInbox) == "function" and C_Mail and C_Mail.CanCheckInbox then
        local ok, canCheck = pcall(C_Mail.CanCheckInbox)
        if ok and canCheck == true then
            pcall(CheckInbox)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.3, function()
            Scan.ReadOpenMailbox()
        end)
    else
        Scan.ReadOpenMailbox()
    end
end

function Scan.OnMailSent()
    local pending = pendingSend
    pendingSend = nil
    if not pending then
        return
    end
    local record = FindAlt(pending.recipient)
    if not record then
        return
    end
    local mail = MailRecord(record)
    mail.sent[#mail.sent + 1] = {
        kind = "sent",
        sender = SafeText(UnitName("player")) or "",
        subject = pending.subject or "",
        money = pending.money or 0,
        daysLeft = 30,
        markedAt = pending.at or time(),
        read = false,
        items = pending.items or {},
    }
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

function Scan.OnMailFailed()
    pendingSend = nil
end

if type(hooksecurefunc) == "function" then
    if type(SendMail) == "function" then
        hooksecurefunc("SendMail", function(recipient, subject)
            CaptureOutgoing(recipient, subject)
        end)
    end
    if C_Mail and type(C_Mail.SendMail) == "function" then
        hooksecurefunc(C_Mail, "SendMail", function(recipient, subject)
            CaptureOutgoing(recipient, subject)
        end)
    end
end
end

do
local auctionOpen = false
local ownedReady = false
local bidsReady = false
local ownedAsked = false
local bidsAsked = false
local auctionTries = 0
local auctionGuid = nil
local auctionRetry = false
local legacyOwned = false
local legacyBids = false

local function TrueFlag(value)
    local ok, result = pcall(function()
        return value == true or value == 1
    end)
    return ok and result or false
end

local function ItemName(itemID, link)
    if itemID and C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        name = ok and SafeText(name) or nil
        if name then
            return name
        end
    end
    if type(link) == "string" then
        return SafeText(string.match(link, "%[(.-)%]"))
    end
    return nil
end

local function ItemQuality(itemID)
    if itemID and C_Item and C_Item.GetItemQualityByID then
        local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
        quality = ok and AsNumber(quality) or nil
        if quality then
            return quality
        end
    end
    return 1
end

local function ItemIcon(itemID, texture)
    if texture and texture ~= 0 and texture ~= "" then
        return texture
    end
    if itemID and C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
        if ok and icon and icon ~= 0 and icon ~= "" then
            return icon
        end
    end
    if itemID and type(GetItemIcon) == "function" then
        local ok, icon = pcall(GetItemIcon, itemID)
        if ok and icon and icon ~= 0 and icon ~= "" then
            return icon
        end
    end
    return nil
end

local function LegacyAuction()
    if type(IsUsingLegacyAuctionClient) == "function" then
        local ok, legacy = pcall(IsUsingLegacyAuctionClient)
        if ok and legacy == true then
            return true
        end
        if ok and legacy == false then
            return false
        end
    end
    return not (C_AuctionHouse and type(C_AuctionHouse.QueryOwnedAuctions) == "function")
end

local function AuctionRecord(record)
    if type(record.auctions) ~= "table" then
        record.auctions = {}
    end
    return record.auctions
end

local function PlayerRecord()
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB and BMGAM.DB.Get(guid) or nil
    if not record and guid and BMGAM.DB and BMGAM.DB.Ensure then
        record = BMGAM.DB.Ensure(guid)
    end
    return record
end

local function RefreshWindow()
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

local function KeyDetails(info)
    local details = nil
    if C_AuctionHouse and C_AuctionHouse.GetItemKeyInfo and info.itemKey then
        local ok, value = pcall(C_AuctionHouse.GetItemKeyInfo, info.itemKey)
        if ok and type(value) == "table" then
            details = value
        end
    end
    local itemID = nil
    if type(info.itemKey) == "table" then
        itemID = AsNumber(info.itemKey.itemID)
    end
    local link = SafeText(info.itemLink)
    if not link and details then
        link = SafeText(details.battlePetLink)
    end
    if not link and itemID and C_Item and C_Item.GetItemInfo then
        local ok, _, itemLink = pcall(C_Item.GetItemInfo, itemID)
        if ok then
            link = SafeText(itemLink)
        end
    end
    local name = details and SafeText(details.itemName) or nil
    if not name then
        name = ItemName(itemID, link)
    end
    local quality = details and AsNumber(details.quality) or nil
    if quality == nil then
        quality = ItemQuality(itemID)
    end
    local icon = details and (AsNumber(details.iconFileID) or SafeText(details.iconFileID)) or nil
    if not icon then
        icon = ItemIcon(itemID, nil)
    end
    local commodity = details and TrueFlag(details.isCommodity)
    return itemID, link, name, quality, icon, commodity
end

local function ItemClassID(itemID)
    if not itemID or not C_Item or type(C_Item.GetItemInfoInstant) ~= "function" then
        return nil
    end
    local results = { pcall(C_Item.GetItemInfoInstant, itemID) }
    if not results[1] then
        return nil
    end
    return AsNumber(results[7])
end

local function StackUsesUnitPrice(commodity, itemID, count)
    if commodity then
        return true
    end
    if count <= 1 then
        return false
    end
    local classID = ItemClassID(itemID)
    if classID == 0 or classID == 3 or classID == 5 or classID == 7 or classID == 8 or classID == 9 or classID == 16 or classID == 19 then
        return true
    end
    return false
end

local function CopyRow(info, skipSold)
    if type(info) ~= "table" then
        return nil
    end
    if skipSold and AsNumber(info.status) == 1 then
        return nil
    end
    local itemID, link, name, quality, icon, commodity = KeyDetails(info)
    local count = AsNumber(info.quantity) or 1
    if count < 1 then
        count = 1
    end
    local row = {
        itemID = itemID,
        link = link,
        name = name or "",
        quality = quality,
        icon = icon,
        count = count,
        timeLeft = AsNumber(info.timeLeftSeconds),
        timeBand = AsNumber(info.timeLeft),
        markedAt = time(),
    }
    local bid = AsNumber(info.bidAmount)
    local buyout = AsNumber(info.buyoutAmount)
    if StackUsesUnitPrice(commodity, itemID, count) then
        if bid and bid > 0 then
            bid = bid * count
        end
        if buyout and buyout > 0 then
            buyout = buyout * count
        end
    end
    if bid and bid > 0 then
        row.bid = bid
    end
    if buyout and buyout > 0 then
        row.buyout = buyout
    end
    return row
end

local function ReadIndexed(countFn, infoFn, skipSold)
    local rows = {}
    if type(countFn) ~= "function" or type(infoFn) ~= "function" then
        return rows, false
    end
    local countOk, count = pcall(countFn)
    if not countOk then
        return rows, false
    end
    count = AsNumber(count) or 0
    local index = 1
    while index <= count and index <= 500 do
        local infoOk, info = pcall(infoFn, index)
        if infoOk and type(info) == "table" then
            local rowOk, row = pcall(CopyRow, info, skipSold)
            if rowOk and type(row) == "table" then
                rows[#rows + 1] = row
            end
        end
        index = index + 1
    end
    return rows, true
end

local function SaveOwned()
    if not C_AuctionHouse then
        return false
    end
    local rows, read = ReadIndexed(C_AuctionHouse.GetNumOwnedAuctions, C_AuctionHouse.GetOwnedAuctionInfo, true)
    if not read then
        return false
    end
    local record = PlayerRecord()
    if not record then
        return false
    end
    local pack = AuctionRecord(record)
    pack.owned = rows
    ownedReady = true
    if bidsReady then
        pack.scanned = true
        pack.scannedAt = time()
    end
    return true
end

local function ReadBidList()
    if not C_AuctionHouse or type(C_AuctionHouse.GetBids) ~= "function" then
        return nil, false
    end
    local ok, bids = pcall(C_AuctionHouse.GetBids)
    if not ok or type(bids) ~= "table" then
        return nil, false
    end
    local rows = {}
    local index = 1
    while type(bids[index]) == "table" do
        local rowOk, row = pcall(CopyRow, bids[index], false)
        if rowOk and type(row) == "table" then
            rows[#rows + 1] = row
        end
        index = index + 1
    end
    return rows, true
end

local function SaveBids()
    if not C_AuctionHouse then
        return false
    end
    local rows, read = ReadIndexed(C_AuctionHouse.GetNumBids, C_AuctionHouse.GetBidInfo, false)
    if not read then
        rows, read = ReadBidList()
    end
    if not read then
        return false
    end
    local record = PlayerRecord()
    if not record then
        return false
    end
    local pack = AuctionRecord(record)
    pack.bids = rows
    bidsReady = true
    if ownedReady then
        pack.scanned = true
        pack.scannedAt = time()
    end
    return true
end

local function LegacyRow(listType, index, skipSold)
    if type(GetAuctionItemInfo) ~= "function" then
        return nil
    end
    local ok, name, texture, count, quality, _, _, _, minBid, _, buyoutPrice, bidAmount, _, _, _, _, saleStatus, itemID = pcall(GetAuctionItemInfo, listType, index)
    if not ok then
        return nil
    end
    if skipSold and AsNumber(saleStatus) == 1 then
        return nil
    end
    itemID = AsNumber(itemID)
    name = SafeText(name)
    if not name and not itemID then
        return nil
    end
    local link
    if type(GetAuctionItemLink) == "function" then
        local linkOk, value = pcall(GetAuctionItemLink, listType, index)
        if linkOk then
            link = SafeText(value)
        end
    end
    count = AsNumber(count) or 1
    if count < 1 then
        count = 1
    end
    local timeBand = nil
    if type(GetAuctionItemTimeLeft) == "function" then
        local timeOk, left = pcall(GetAuctionItemTimeLeft, listType, index)
        left = timeOk and AsNumber(left) or nil
        if left and left >= 1 then
            timeBand = left - 1
            if timeBand > 3 then
                timeBand = 3
            end
        end
    end
    local row = {
        itemID = itemID,
        link = link,
        name = name or ItemName(itemID, link) or "",
        quality = AsNumber(quality) or ItemQuality(itemID),
        icon = ItemIcon(itemID, texture),
        count = count,
        timeBand = timeBand,
        markedAt = time(),
    }
    local bid = AsNumber(bidAmount)
    if not bid or bid <= 0 then
        bid = AsNumber(minBid)
    end
    local buyout = AsNumber(buyoutPrice)
    if bid and bid > 0 then
        row.bid = bid
    end
    if buyout and buyout > 0 then
        row.buyout = buyout
    end
    return row
end

local function LegacyRows(listType, skipSold)
    if type(GetNumAuctionItems) ~= "function" then
        return nil
    end
    local ok, count = pcall(GetNumAuctionItems, listType)
    if not ok then
        return nil
    end
    count = AsNumber(count) or 0
    local rows = {}
    local index = 1
    while index <= count and index <= 500 do
        local row = LegacyRow(listType, index, skipSold)
        if row then
            rows[#rows + 1] = row
        end
        index = index + 1
    end
    return rows
end

local function FinishLegacy(pack)
    if legacyOwned and legacyBids then
        pack.scanned = true
        pack.scannedAt = time()
    end
end

local function SaveLegacyOwned()
    local rows = LegacyRows("owner", true)
    if not rows then
        return false
    end
    local record = PlayerRecord()
    if not record then
        return false
    end
    local pack = AuctionRecord(record)
    pack.owned = rows
    legacyOwned = true
    FinishLegacy(pack)
    return true
end

local function SaveLegacyBids()
    local rows = LegacyRows("bidder", false)
    if not rows then
        return false
    end
    local record = PlayerRecord()
    if not record then
        return false
    end
    local pack = AuctionRecord(record)
    pack.bids = rows
    legacyBids = true
    FinishLegacy(pack)
    return true
end

local function ThrottleReady()
    if not C_AuctionHouse or type(C_AuctionHouse.IsThrottledMessageSystemReady) ~= "function" then
        return true
    end
    local ok, ready = pcall(C_AuctionHouse.IsThrottledMessageSystemReady)
    if not ok then
        return true
    end
    return ready ~= false
end

local function AuctionSorts()
    local order = 1
    if Enum and Enum.AuctionHouseSortOrder and type(Enum.AuctionHouseSortOrder.Name) == "number" then
        order = Enum.AuctionHouseSortOrder.Name
    end
    return {
        { sortOrder = order, reverseSort = false },
    }
end

local function QueryLists()
    if auctionOpen or LegacyAuction() or not C_AuctionHouse or not ThrottleReady() then
        return
    end
    if auctionTries >= 4 then
        return
    end
    local sorts = AuctionSorts()
    local sent = false
    if not ownedReady and not ownedAsked and type(C_AuctionHouse.QueryOwnedAuctions) == "function" then
        local ok = pcall(C_AuctionHouse.QueryOwnedAuctions, sorts)
        if ok then
            ownedAsked = true
            sent = true
        end
    end
    if not bidsReady and not bidsAsked and type(C_AuctionHouse.QueryBids) == "function" then
        local ok = pcall(C_AuctionHouse.QueryBids, sorts)
        if ok then
            bidsAsked = true
            sent = true
        end
    end
    if sent then
        auctionTries = auctionTries + 1
    end
end

local function PullIfFull()
    if not C_AuctionHouse or LegacyAuction() then
        return
    end
    if not ownedReady and ownedAsked and type(C_AuctionHouse.HasFullOwnedAuctionResults) == "function" then
        local ok, full = pcall(C_AuctionHouse.HasFullOwnedAuctionResults)
        if ok and TrueFlag(full) then
            if SaveOwned() then
                RefreshWindow()
            end
        end
    end
    if not bidsReady and bidsAsked and type(C_AuctionHouse.HasFullBidResults) == "function" then
        local ok, full = pcall(C_AuctionHouse.HasFullBidResults)
        if ok and TrueFlag(full) then
            if SaveBids() then
                RefreshWindow()
            end
        end
    end
end

function Scan.ReadAuctions()
    local guid = UnitGUID("player")
    if not guid then
        return
    end
    if guid ~= auctionGuid then
        auctionGuid = guid
        ownedReady = false
        bidsReady = false
        ownedAsked = false
        bidsAsked = false
        auctionTries = 0
        auctionRetry = false
        legacyOwned = false
        legacyBids = false
    end
    if LegacyAuction() then
        if auctionOpen then
            if SaveLegacyOwned() or SaveLegacyBids() then
                RefreshWindow()
            end
        end
        return
    end
    if auctionOpen then
        return
    end
    QueryLists()
    if auctionRetry or (ownedReady and bidsReady) or not C_Timer or not C_Timer.After then
        return
    end
    auctionRetry = true
    C_Timer.After(1.5, function()
        auctionRetry = false
        if auctionOpen or UnitGUID("player") ~= auctionGuid then
            return
        end
        PullIfFull()
        if ownedReady and bidsReady then
            return
        end
        if auctionTries >= 4 then
            return
        end
        if not ownedReady then
            ownedAsked = false
        end
        if not bidsReady then
            bidsAsked = false
        end
        QueryLists()
    end)
end

function Scan.OnOwnedAuctions()
    if LegacyAuction() then
        return
    end
    if SaveOwned() then
        RefreshWindow()
    end
end

function Scan.OnBidsUpdated()
    if LegacyAuction() then
        return
    end
    if SaveBids() then
        RefreshWindow()
    end
end

function Scan.OnLegacyOwned()
    if not LegacyAuction() or not auctionOpen then
        return
    end
    if SaveLegacyOwned() then
        RefreshWindow()
    end
end

function Scan.OnLegacyBids()
    if not LegacyAuction() or not auctionOpen then
        return
    end
    if SaveLegacyBids() then
        RefreshWindow()
    end
end

function Scan.OnAuctionThrottle()
    if auctionOpen or LegacyAuction() then
        return
    end
    if not ownedReady then
        ownedAsked = false
    end
    if not bidsReady then
        bidsAsked = false
    end
    QueryLists()
end

function Scan.OnAuctionChanged()
    if auctionOpen or LegacyAuction() then
        return
    end
    ownedReady = false
    bidsReady = false
    ownedAsked = false
    bidsAsked = false
    auctionTries = 0
    QueryLists()
end

function Scan.OnAuctionHouse(opened)
    auctionOpen = opened and true or false
    if auctionOpen then
        if LegacyAuction() and C_Timer and C_Timer.After then
            C_Timer.After(1.5, function()
                if auctionOpen and LegacyAuction() then
                    if SaveLegacyOwned() or SaveLegacyBids() then
                        RefreshWindow()
                    end
                end
            end)
        end
        return
    end
    if LegacyAuction() then
        return
    end
    ownedReady = false
    bidsReady = false
    ownedAsked = false
    bidsAsked = false
    auctionTries = 0
    auctionRetry = false
    Scan.ReadAuctions()
end
end
