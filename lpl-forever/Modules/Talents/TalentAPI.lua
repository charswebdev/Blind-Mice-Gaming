local _, LPL = ...

LPL.TalentAPI = LPL.TalentAPI or {}
local API = LPL.TalentAPI

local SHARE_PREFIX = "!LPLF1!"

local function PlainString(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

local function PlainNumber(value)
    if type(value) ~= "number" then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return nil
    end
    return value
end

function API:ConfigID()
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local ok, id = pcall(C_ClassTalents.GetActiveConfigID)
        id = ok and PlainNumber(id) or nil
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
    for i = 1, #ids do
        local id = PlainNumber(ids[i])
        if id and id > 0 then
            return id
        end
    end
    return nil
end

function API:Available()
    return self:ConfigID() ~= nil and self:TabCount() > 0
end

function API:PlayerClass()
    if type(UnitClass) ~= "function" then
        return nil, nil
    end
    local ok, _, classFile, classID = pcall(UnitClass, "player")
    if not ok then
        return nil, nil
    end
    return PlainString(classFile), PlainNumber(classID)
end

local CLASS_TREES = {
    WARRIOR = { "Arms", "Fury", "Protection" },
    PALADIN = { "Holy", "Protection", "Retribution" },
    HUNTER = { "Beast Mastery", "Marksmanship", "Survival" },
    ROGUE = { "Assassination", "Combat", "Subtlety" },
    PRIEST = { "Discipline", "Holy", "Shadow" },
    SHAMAN = { "Elemental", "Enhancement", "Restoration" },
    MAGE = { "Arcane", "Fire", "Frost" },
    WARLOCK = { "Affliction", "Demonology", "Destruction" },
    DRUID = { "Balance", "Feral Combat", "Restoration" },
}

local function ClassFile()
    local classID
    if PlayerUtil and PlayerUtil.GetClassID then
        local ok, id = pcall(PlayerUtil.GetClassID)
        if ok and type(id) == "number" and id > 0 then
            classID = id
        end
    end
    if classID and type(GetClassInfo) == "function" then
        local ok, _, file = pcall(GetClassInfo, classID)
        if ok and type(file) == "string" and file ~= "" then
            return file
        end
    end
    return nil
end

function API:SpecializationNames()
    local names = {}
    local function Add(name)
        if name == nil then
            return
        end
        if issecretvalue and issecretvalue(name) then
            names[#names + 1] = name
            return
        end
        name = PlainString(name)
        if name and name ~= "" then
            names[#names + 1] = name
        end
    end
    local function AddSpecCall(fn, ...)
        local packed = { pcall(fn, ...) }
        if not packed[1] then
            return
        end
        if type(packed[2]) == "table" then
            Add(packed[2].name or packed[2].specName)
            return
        end
        Add(packed[3])
    end

    local classID
    if PlayerUtil and PlayerUtil.GetClassID then
        local ok, id = pcall(PlayerUtil.GetClassID)
        if ok and type(id) == "number" and id > 0 then
            classID = id
        end
    end
    if not classID and type(GetClassInfo) == "function" then
        local classFile
        if type(UnitClassBase) == "function" then
            local ok, file = pcall(UnitClassBase, "player")
            if ok and type(file) == "string" then
                classFile = file
            end
        end
        if classFile then
            for id = 1, 20 do
                local ok, _, file = pcall(GetClassInfo, id)
                if ok and file == classFile then
                    classID = id
                    break
                end
            end
        end
    end

    local getter = type(GetSpecializationInfoForClassID) == "function" and GetSpecializationInfoForClassID or nil
    if not getter and C_SpecializationInfo then
        getter = C_SpecializationInfo.GetSpecializationInfoForClassID
    end
    if classID and getter then
        local count = 4
        if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
            local ok, num = pcall(C_SpecializationInfo.GetNumSpecializationsForClassID, classID)
            if ok and type(num) == "number" and num > 0 and num < 5 then
                count = num
            end
        end
        for index = 1, count do
            AddSpecCall(getter, classID, index)
        end
    end
    if #names > 0 and #names < 3 then
        for i = #names, 1, -1 do
            names[i] = nil
        end
    end
    if #names == 0 and C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
        for index = 1, 4 do
            AddSpecCall(C_SpecializationInfo.GetSpecializationInfo, index)
        end
    end
    if #names == 0 and type(GetSpecializationInfo) == "function" then
        for index = 1, 4 do
            AddSpecCall(GetSpecializationInfo, index)
        end
    end
    if #names == 0 and type(GetTalentTabInfo) == "function" then
        for index = 1, 4 do
            local tabOk, name = pcall(GetTalentTabInfo, index)
            if tabOk then
                Add(name)
            end
        end
    end
    if #names < 3 then
        for i = #names, 1, -1 do
            names[i] = nil
        end
    end
    if #names < 3 then
        for i = #names, 1, -1 do
            names[i] = nil
        end
        local trees = CLASS_TREES[ClassFile() or ""]
        if trees then
            for index = 1, #trees do
                Add(trees[index])
            end
        end
    end
    return names
end

function API:ClassName()
    if PlayerUtil and PlayerUtil.GetClassName then
        local ok, name = pcall(PlayerUtil.GetClassName)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

function API:Unspent()
    local configID = self:ConfigID()
    local tabs = self:Tabs()
    local treeID = tabs[1] and tabs[1].treeID
    if not configID or not treeID or not (C_Traits and C_Traits.GetTreeCurrencyInfo) then
        return 0
    end
    local ok, infos = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
    if not ok or type(infos) ~= "table" then
        return 0
    end
    local total = 0
    for i = 1, #infos do
        local quantity = type(infos[i]) == "table" and PlainNumber(infos[i].quantity) or nil
        if quantity and quantity > 0 then
            total = total + quantity
        end
    end
    return total
end

local collectedHeaders = {}

local function ClearHeaders()
    for i = #collectedHeaders, 1, -1 do
        collectedHeaders[i] = nil
    end
end

local function DisplayString(value)
    if value == nil then
        return nil
    end
    if issecretvalue and issecretvalue(value) then
        return value
    end
    return PlainString(value)
end

local function UsefulLabel(text)
    if issecretvalue and issecretvalue(text) then
        return nil
    end
    text = PlainString(text)
    if not text or text == "" then
        return nil
    end
    if text:match("^Rank %d") or text == "Passive" or text == "Talent" then
        return nil
    end
    return text
end

local function SubTreeDisplayName(configID, subTreeID)
    if subTreeID == nil or not (C_Traits and C_Traits.GetSubTreeInfo) then
        return nil
    end
    local function FromCall(...)
        local ok, info = pcall(C_Traits.GetSubTreeInfo, ...)
        if not ok or type(info) ~= "table" then
            return nil
        end
        return UsefulLabel(info.name) or DisplayString(info.name)
    end
    if configID ~= nil then
        local name = FromCall(configID, subTreeID)
        if name then
            return name
        end
    end
    return FromCall(subTreeID)
end

local function RememberHeader(posX, posY, name)
    name = UsefulLabel(name)
    if name == nil then
        return
    end
    collectedHeaders[#collectedHeaders + 1] = {
        posX = posX or 0,
        posY = posY or 0,
        name = name,
    }
end

function API:TreeHeaders()
    return collectedHeaders
end

local function SpellName(spellID)
    spellID = PlainNumber(spellID)
    if not spellID then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok then
            return PlainString(name)
        end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok then
            return PlainString(name)
        end
    end
    return nil
end

local function SpellSubtext(spellID)
    spellID = PlainNumber(spellID)
    if not spellID then
        return nil
    end
    if C_Spell and C_Spell.GetSpellSubtext then
        local ok, text = pcall(C_Spell.GetSpellSubtext, spellID)
        if ok then
            return UsefulLabel(text)
        end
    end
    if type(GetSpellSubtext) == "function" then
        local ok, text = pcall(GetSpellSubtext, spellID)
        if ok then
            return UsefulLabel(text)
        end
    end
    return nil
end

local function SpellIcon(spellID)
    spellID = PlainNumber(spellID)
    if not spellID then
        return nil
    end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and (type(icon) == "number" or type(icon) == "string") then
            if not (issecretvalue and issecretvalue(icon)) then
                return icon
            end
        end
    end
    return nil
end

local function SpellDescription(spellID)
    spellID = PlainNumber(spellID)
    if not spellID or not (C_Spell and C_Spell.GetSpellDescription) then
        return nil
    end
    local ok, text = pcall(C_Spell.GetSpellDescription, spellID)
    if not ok then
        return nil
    end
    return DisplayString(text)
end

local function NodeRecord(configID, nodeID, node)
    local entryID = node.entryIDs and node.entryIDs[1]
    if node.activeEntry and node.activeEntry.entryID then
        entryID = node.activeEntry.entryID
    end
    entryID = PlainNumber(entryID)
    local name, icon, tabName, entrySubTreeID, spellID, description
    if entryID and C_Traits.GetEntryInfo then
        local ok, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
        if ok and type(entry) == "table" then
            entrySubTreeID = entry.subTreeID
        end
        local definitionID = ok and type(entry) == "table" and PlainNumber(entry.definitionID) or nil
        if definitionID and C_Traits.GetDefinitionInfo then
            local defOk, def = pcall(C_Traits.GetDefinitionInfo, definitionID)
            if defOk and type(def) == "table" then
                spellID = PlainNumber(def.spellID)
                description = DisplayString(def.overrideDescription) or SpellDescription(spellID)
                name = PlainString(def.overrideName) or SpellName(spellID)
                tabName = UsefulLabel(def.overrideSubtext) or SpellSubtext(def.spellID)
                if not tabName then
                    pcall(function()
                        for key, value in pairs(def) do
                            if type(key) == "string" and type(value) == "string" and key ~= "overrideName" and not key:find("escription") and not key:find("[Ii]con") then
                                local label = UsefulLabel(value)
                                if label and label ~= name and #label < 40 then
                                    tabName = label
                                    break
                                end
                            end
                        end
                    end)
                end
                if not tabName and C_TooltipInfo and C_TooltipInfo.GetTraitEntry then
                    local tipOk, tip = pcall(C_TooltipInfo.GetTraitEntry, configID, entryID)
                    if tipOk and type(tip) == "table" and type(tip.lines) == "table" then
                        for i = 1, math.min(#tip.lines, 6) do
                            local line = tip.lines[i]
                            local label = line and UsefulLabel(line.leftText)
                            if label and label ~= name and #label < 40 then
                                tabName = label
                                break
                            end
                        end
                    end
                end
                icon = def.overrideIcon
                if type(icon) ~= "number" and type(icon) ~= "string" then
                    icon = nil
                elseif issecretvalue and issecretvalue(icon) then
                    icon = nil
                end
                icon = icon or SpellIcon(def.spellID)
            end
        end
    end
    local maxRank = PlainNumber(node.maxRanks) or 1
    local rawSubTreeID = node.subTreeID
    local treeName = SubTreeDisplayName(configID, rawSubTreeID) or SubTreeDisplayName(configID, entrySubTreeID)
    if treeName == nil and type(node.subTreeInfo) == "table" then
        treeName = UsefulLabel(node.subTreeInfo.name) or DisplayString(node.subTreeInfo.name)
    end
    local posX = PlainNumber(node.posX) or 0
    local posY = PlainNumber(node.posY) or 0
    if maxRank < 1 then
        RememberHeader(posX, posY, treeName or UsefulLabel(name) or tabName)
        return nil
    end
    local entryCount = 0
    if type(node.entryIDs) == "table" then
        entryCount = #node.entryIDs
    end
    local edges = {}
    local function AddEdgeList(list)
        if type(list) ~= "table" then
            return
        end
        for i = 1, #list do
            local edge = list[i]
            if type(edge) == "table" then
                local target = PlainNumber(edge.targetNode) or PlainNumber(edge.targetNodeID)
                if target and target ~= nodeID then
                    edges[#edges + 1] = {
                        target = target,
                        active = edge.isActive == true,
                    }
                end
            end
        end
    end
    AddEdgeList(node.visibleEdges)
    AddEdgeList(node.incomingEdges)
    RememberHeader(posX, posY, treeName)
    return {
        talentIndex = nodeID,
        name = name or ("Talent " .. tostring(nodeID)),
        icon = icon,
        tabName = tabName,
        posX = posX,
        posY = posY,
        rank = PlainNumber(node.currentRank) or PlainNumber(node.activeRank) or 0,
        maxRank = maxRank,
        subTreeID = PlainNumber(node.subTreeID),
        rawSubTreeID = rawSubTreeID,
        treeName = treeName,
        entryCount = entryCount,
        edges = edges,
        configID = configID,
        entryID = entryID,
        spellID = spellID,
        description = description,
    }
end

local function ReadNodes(configID, treeID)
    local list = {}
    if not (C_Traits and C_Traits.GetTreeNodes and C_Traits.GetNodeInfo) then
        return list
    end
    local ok, nodeIDs = pcall(C_Traits.GetTreeNodes, treeID)
    if not ok or type(nodeIDs) ~= "table" then
        return list
    end
    for i = 1, #nodeIDs do
        local nodeID = PlainNumber(nodeIDs[i])
        if nodeID then
            local nodeOk, node = pcall(C_Traits.GetNodeInfo, configID, nodeID)
            if nodeOk and type(node) == "table" then
                local record = NodeRecord(configID, nodeID, node)
                if record then
                    list[#list + 1] = record
                end
            end
        end
    end
    return list
end

local function AssignGrid(nodes)
    local xs, ys = {}, {}
    local xList, yList = {}, {}
    for i = 1, #nodes do
        local x = nodes[i].posX or 0
        local y = nodes[i].posY or 0
        if not xs[x] then
            xs[x] = true
            xList[#xList + 1] = x
        end
        if not ys[y] then
            ys[y] = true
            yList[#yList + 1] = y
        end
    end
    table.sort(xList)
    table.sort(yList)
    local xIndex, yIndex = {}, {}
    for i = 1, #xList do
        xIndex[xList[i]] = i
    end
    for i = 1, #yList do
        yIndex[yList[i]] = i
    end
    for i = 1, #nodes do
        nodes[i].column = xIndex[nodes[i].posX or 0] or 1
        nodes[i].tier = yIndex[nodes[i].posY or 0] or 1
    end
end

function API:Tabs()
    ClearHeaders()
    local configID = self:ConfigID()
    if not configID or not (C_Traits and C_Traits.GetConfigInfo) then
        return {}
    end
    local ok, info = pcall(C_Traits.GetConfigInfo, configID)
    local treeIDs = ok and type(info) == "table" and info.treeIDs or nil
    if type(treeIDs) ~= "table" or #treeIDs < 1 then
        return {}
    end
    local tabs = {}
    if #treeIDs > 1 then
        for i = 1, #treeIDs do
            local treeID = PlainNumber(treeIDs[i])
            if treeID then
                local treeOk, treeInfo = pcall(C_Traits.GetTreeInfo, treeID)
                local name = treeOk and type(treeInfo) == "table" and PlainString(treeInfo.name) or nil
                local nodes = ReadNodes(configID, treeID)
                AssignGrid(nodes)
                tabs[#tabs + 1] = {
                    index = #tabs + 1,
                    treeID = treeID,
                    name = name or ("Tree " .. tostring(#tabs + 1)),
                    nodes = nodes,
                }
            end
        end
    else
        local treeID = PlainNumber(treeIDs[1])
        local nodes = treeID and ReadNodes(configID, treeID) or {}
        local groups, order = {}, {}
        for i = 1, #nodes do
            local key = nodes[i].subTreeID or 0
            if not groups[key] then
                groups[key] = {}
                order[#order + 1] = key
            end
            groups[key][#groups[key] + 1] = nodes[i]
        end
        if #order <= 1 then
            AssignGrid(nodes)
            local treeOk, treeInfo = pcall(C_Traits.GetTreeInfo, treeID)
            local name = treeOk and type(treeInfo) == "table" and PlainString(treeInfo.name) or nil
            tabs[1] = {
                index = 1,
                treeID = treeID,
                name = name or "Talents",
                nodes = nodes,
            }
        else
            for i = 1, #order do
                local key = order[i]
                local grouped = groups[key]
                AssignGrid(grouped)
                local name = "Tree " .. tostring(i)
                if key ~= 0 and C_Traits.GetSubTreeInfo then
                    local subOk, sub = pcall(C_Traits.GetSubTreeInfo, key)
                    if subOk and type(sub) == "table" and PlainString(sub.name) then
                        name = PlainString(sub.name)
                    end
                end
                tabs[#tabs + 1] = {
                    index = #tabs + 1,
                    treeID = treeID,
                    name = name,
                    nodes = grouped,
                }
            end
        end
    end
    return tabs
end

function API:TabCount()
    return #self:Tabs()
end

function API:TabInfo(tabIndex)
    local tab = self:Tabs()[tabIndex]
    if not tab then
        return { index = tabIndex, name = "Tree " .. tostring(tabIndex), points = 0 }
    end
    local points = 0
    for i = 1, #tab.nodes do
        points = points + (tab.nodes[i].rank or 0)
    end
    return {
        index = tabIndex,
        name = tab.name,
        points = points,
    }
end

function API:TalentInfo(tabIndex, talentIndex)
    local talents = self:Talents(tabIndex)
    for i = 1, #talents do
        if talents[i].talentIndex == talentIndex then
            return talents[i]
        end
    end
    return nil
end

function API:Talents(tabIndex)
    local tab = self:Tabs()[tabIndex]
    local list = {}
    if not tab then
        return list
    end
    for i = 1, #tab.nodes do
        list[#list + 1] = tab.nodes[i]
    end
    table.sort(list, function(a, b)
        if a.tier ~= b.tier then
            return a.tier < b.tier
        end
        if a.column ~= b.column then
            return a.column < b.column
        end
        return a.talentIndex < b.talentIndex
    end)
    return list
end

function API:TierBase(tabIndex)
    local talents = self:Talents(tabIndex)
    local lowest = nil
    for i = 1, #talents do
        if lowest == nil or talents[i].tier < lowest then
            lowest = talents[i].tier
        end
    end
    if lowest == 0 then
        return 0
    end
    return 1
end

function API:PointsRequired(tabIndex, tier)
    local base = self:TierBase(tabIndex)
    local row = (tonumber(tier) or base) - base
    if row < 0 then
        row = 0
    end
    return row * 5
end

function API:DraftRank(build, tabIndex, talentIndex)
    if type(build) ~= "table" or type(build.tabs) ~= "table" then
        return 0
    end
    local tab = build.tabs[tostring(tabIndex)]
    if type(tab) ~= "table" or type(tab.ranks) ~= "table" then
        return 0
    end
    return tonumber(tab.ranks[tostring(talentIndex)]) or 0
end

function API:SetDraftRank(build, tabIndex, talentIndex, rank)
    build.tabs = build.tabs or {}
    local key = tostring(tabIndex)
    local tab = build.tabs[key]
    if type(tab) ~= "table" then
        local info = self:TabInfo(tabIndex)
        tab = { name = info.name, points = 0, ranks = {} }
        build.tabs[key] = tab
    end
    if type(tab.ranks) ~= "table" then
        tab.ranks = {}
    end
    rank = tonumber(rank) or 0
    if rank <= 0 then
        tab.ranks[tostring(talentIndex)] = nil
    else
        tab.ranks[tostring(talentIndex)] = rank
    end
    local points = 0
    for _, value in pairs(tab.ranks) do
        points = points + (tonumber(value) or 0)
    end
    tab.points = points
    local total = 0
    for tabNumber = 1, 3 do
        local stored = build.tabs[tostring(tabNumber)]
        if type(stored) == "table" then
            total = total + (tonumber(stored.points) or 0)
        end
    end
    build.totalPoints = total
end

function API:PointsBeforeTier(build, tabIndex, tier)
    local total = 0
    local talents = self:Talents(tabIndex)
    for i = 1, #talents do
        local talent = talents[i]
        if talent.tier < tier then
            total = total + self:DraftRank(build, tabIndex, talent.talentIndex)
        end
    end
    return total
end

function API:Prereq(tabIndex, talentIndex)
    if type(GetTalentPrereqs) ~= "function" then
        return nil
    end
    local ok, tier, column = pcall(GetTalentPrereqs, tabIndex, talentIndex)
    if not ok then
        return nil
    end
    tier = PlainNumber(tier)
    column = PlainNumber(column)
    if not tier or not column then
        return nil
    end
    local talents = self:Talents(tabIndex)
    for i = 1, #talents do
        local talent = talents[i]
        if talent.tier == tier and talent.column == column then
            return talent
        end
    end
    return nil
end

function API:PointBudget()
    return 51
end

function API:CanAdd(build, tabIndex, talentIndex)
    local info = self:TalentInfo(tabIndex, talentIndex)
    if not info then
        return false, "That talent is not on this character."
    end
    local current = self:DraftRank(build, tabIndex, talentIndex)
    if current >= info.maxRank then
        return false, info.name .. " is already at max rank."
    end
    local spent = tonumber(build.totalPoints) or 0
    if spent >= self:PointBudget() then
        return false, "This build already has 51 points."
    end
    local required = self:PointsRequired(tabIndex, info.tier)
    local before = self:PointsBeforeTier(build, tabIndex, info.tier)
    if before < required then
        return false, "Need " .. tostring(required) .. " points in earlier rows of this tree."
    end
    local prereq = self:Prereq(tabIndex, talentIndex)
    if prereq then
        local have = self:DraftRank(build, tabIndex, prereq.talentIndex)
        if have < prereq.maxRank then
            return false, "Learn " .. prereq.name .. " first."
        end
    end
    return true
end

function API:CanRemove(build, tabIndex, talentIndex)
    local current = self:DraftRank(build, tabIndex, talentIndex)
    if current <= 0 then
        return false, "That talent has no ranks in this build."
    end
    self:SetDraftRank(build, tabIndex, talentIndex, current - 1)
    local ok = true
    local reason = nil
    local tabs = self:TabCount()
    for tab = 1, tabs do
        local talents = self:Talents(tab)
        for i = 1, #talents do
            local talent = talents[i]
            local rank = self:DraftRank(build, tab, talent.talentIndex)
            if rank > 0 then
                local required = self:PointsRequired(tab, talent.tier)
                local before = self:PointsBeforeTier(build, tab, talent.tier)
                if before < required then
                    ok = false
                    reason = "Remove later rows in this tree first."
                end
                local prereq = self:Prereq(tab, talent.talentIndex)
                if prereq then
                    local have = self:DraftRank(build, tab, prereq.talentIndex)
                    if have < prereq.maxRank then
                        ok = false
                        reason = "Remove talents that require " .. prereq.name .. " first."
                    end
                end
            end
            if not ok then
                break
            end
        end
        if not ok then
            break
        end
    end
    self:SetDraftRank(build, tabIndex, talentIndex, current)
    if not ok then
        return false, reason
    end
    return true
end

function API:Capture()
    local classFile, classID = self:PlayerClass()
    local tabs = {}
    local total = 0
    local tabCount = self:TabCount()
    for tabIndex = 1, tabCount do
        local info = self:TabInfo(tabIndex)
        local ranks = {}
        local talents = self:Talents(tabIndex)
        for i = 1, #talents do
            local talent = talents[i]
            if talent.rank > 0 then
                ranks[tostring(talent.talentIndex)] = talent.rank
            end
            total = total + talent.rank
        end
        tabs[tostring(tabIndex)] = {
            name = info.name,
            points = info.points,
            ranks = ranks,
        }
    end
    return {
        classFile = classFile,
        classID = classID,
        tabs = tabs,
        totalPoints = total,
    }
end

function API:Summary(build)
    if type(build) ~= "table" or type(build.tabs) ~= "table" then
        return "0/0/0"
    end
    local parts = {}
    for tabIndex = 1, 3 do
        local tab = build.tabs[tostring(tabIndex)]
        local points = 0
        if type(tab) == "table" then
            points = tonumber(tab.points) or 0
        end
        parts[#parts + 1] = tostring(points)
    end
    return table.concat(parts, "/")
end

function API:SameClass(build)
    if type(build) ~= "table" then
        return false
    end
    local classFile, classID = self:PlayerClass()
    if build.classFile and classFile then
        return build.classFile == classFile
    end
    if build.classID and classID then
        return tonumber(build.classID) == classID
    end
    return false
end

local function RanksEqual(savedRanks, liveRanks)
    savedRanks = type(savedRanks) == "table" and savedRanks or {}
    liveRanks = type(liveRanks) == "table" and liveRanks or {}
    local seen = {}
    for key, rank in pairs(savedRanks) do
        if type(key) == "string" or type(key) == "number" then
            seen[key] = true
            if (tonumber(rank) or 0) ~= (tonumber(liveRanks[key]) or 0) then
                return false
            end
        end
    end
    for key, rank in pairs(liveRanks) do
        if (type(key) == "string" or type(key) == "number") and not seen[key] and (tonumber(rank) or 0) > 0 then
            return false
        end
    end
    return true
end

function API:MatchesLive(build)
    if not self:SameClass(build) or type(build.tabs) ~= "table" then
        return false
    end
    local live = self:Capture()
    if type(live) ~= "table" or type(live.tabs) ~= "table" then
        return false
    end
    for tabIndex = 1, 3 do
        local saved = build.tabs[tostring(tabIndex)]
        local current = live.tabs[tostring(tabIndex)]
        local savedRanks = type(saved) == "table" and saved.ranks or nil
        local liveRanks = type(current) == "table" and current.ranks or nil
        if not RanksEqual(savedRanks, liveRanks) then
            return false
        end
    end
    return true
end

function API:Encode(build)
    if type(build) ~= "table" then
        return ""
    end
    local parts = { SHARE_PREFIX .. tostring(build.classFile or "") }
    for tabIndex = 1, 3 do
        local ranks = {}
        local tab = build.tabs and build.tabs[tostring(tabIndex)]
        if type(tab) == "table" and type(tab.ranks) == "table" then
            for index, rank in pairs(tab.ranks) do
                local rankNumber = tonumber(rank)
                local indexNumber = tonumber(index)
                if indexNumber and rankNumber and rankNumber > 0 then
                    ranks[#ranks + 1] = tostring(indexNumber) .. ":" .. tostring(rankNumber)
                end
            end
            table.sort(ranks)
        end
        parts[#parts + 1] = table.concat(ranks, ",")
    end
    return table.concat(parts, "!")
end

function API:Decode(text)
    if type(text) ~= "string" then
        return nil, "Paste a Light Paws talent code."
    end
    if text:sub(1, #SHARE_PREFIX) ~= SHARE_PREFIX then
        return nil, "That code is not a Forever talent build."
    end
    local body = text:sub(#SHARE_PREFIX + 1)
    local fields = {}
    for field in string.gmatch(body, "[^!]+") do
        fields[#fields + 1] = field
    end
    if #fields < 1 then
        return nil, "That talent code is empty."
    end
    local classFile = fields[1]
    if classFile == "" then
        classFile = nil
    end
    local tabs = {}
    local total = 0
    for tabIndex = 1, 3 do
        local ranks = {}
        local points = 0
        local blob = fields[tabIndex + 1] or ""
        if blob ~= "" then
            for piece in string.gmatch(blob, "[^,]+") do
                local indexText, rankText = piece:match("^(%d+):(%d+)$")
                local indexNumber = tonumber(indexText)
                local rankNumber = tonumber(rankText)
                if indexNumber and rankNumber and rankNumber > 0 then
                    ranks[tostring(indexNumber)] = rankNumber
                    points = points + rankNumber
                end
            end
        end
        local info = self:Available() and self:TabInfo(tabIndex) or nil
        tabs[tostring(tabIndex)] = {
            name = info and info.name or ("Tree " .. tostring(tabIndex)),
            points = points,
            ranks = ranks,
        }
        total = total + points
    end
    return {
        classFile = classFile,
        tabs = tabs,
        totalPoints = total,
    }
end

local function SurfaceTooltipData(data)
    if type(data) ~= "table" or not (TooltipUtil and TooltipUtil.SurfaceArgs) then
        return
    end
    pcall(TooltipUtil.SurfaceArgs, data)
    if type(data.lines) ~= "table" then
        return
    end
    for i = 1, #data.lines do
        pcall(TooltipUtil.SurfaceArgs, data.lines[i])
    end
end

local function FetchTraitTooltip(entryID, configID, rank)
    if not entryID or not (C_TooltipInfo and C_TooltipInfo.GetTraitEntry) then
        return nil
    end
    local calls = {}
    if rank then
        calls[#calls + 1] = function() return C_TooltipInfo.GetTraitEntry(entryID, rank) end
        calls[#calls + 1] = function() return C_TooltipInfo.GetTraitEntry(configID, entryID, rank) end
    end
    calls[#calls + 1] = function() return C_TooltipInfo.GetTraitEntry(configID, entryID) end
    calls[#calls + 1] = function() return C_TooltipInfo.GetTraitEntry(entryID) end
    for i = 1, #calls do
        local ok, data = pcall(calls[i])
        if ok and type(data) == "table" and type(data.lines) == "table" and #data.lines > 0 then
            SurfaceTooltipData(data)
            return data
        end
    end
    return nil
end

local function AddTooltipLine(text, r, g, b)
    if text == nil or text == "" then
        return false
    end
    local ok = pcall(GameTooltip.AddLine, GameTooltip, text, r or 1, g or 1, b or 1, true)
    return ok
end

local function SamePlainText(a, b)
    if a == nil or b == nil then
        return false
    end
    if (issecretvalue and issecretvalue(a)) or (issecretvalue and issecretvalue(b)) then
        return false
    end
    return PlainString(a) == PlainString(b)
end

local function TooltipBody(data, talentName)
    local lines = {}
    if type(data) ~= "table" or type(data.lines) ~= "table" then
        return lines, nil
    end
    local parts = {}
    for i = 1, #data.lines do
        local line = data.lines[i]
        local text = line and line.leftText
        if text and text ~= "" and not SamePlainText(text, talentName) then
            local plain = (issecretvalue and issecretvalue(text)) and nil or PlainString(text)
            if not (plain and (plain:match("^Rank %d") or plain == "Passive" or plain == "Talent")) then
                lines[#lines + 1] = line
                if not plain then
                    parts = nil
                elseif parts then
                    parts[#parts + 1] = plain
                end
            end
        end
    end
    if not parts then
        return lines, nil
    end
    if #parts == 0 then
        return lines, ""
    end
    return lines, table.concat(parts, "\n")
end

local function AddBodyLines(lines)
    local painted = false
    for i = 1, #lines do
        local line = lines[i]
        local r, g, b = 1, 1, 1
        if type(line.leftColor) == "table" then
            r = line.leftColor.r or line.leftColor[1] or 1
            g = line.leftColor.g or line.leftColor[2] or 1
            b = line.leftColor.b or line.leftColor[3] or 1
        end
        if AddTooltipLine(line.leftText, r, g, b) then
            painted = true
        end
    end
    return painted
end

function API:ShowTooltip(owner, talent, draftRank)
    if not owner or not GameTooltip or type(talent) ~= "table" then
        return
    end
    draftRank = tonumber(draftRank) or 0
    local maxRank = tonumber(talent.maxRank) or 1
    if maxRank < 1 then
        maxRank = 1
    end
    if maxRank > 5 then
        maxRank = 5
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if GameTooltip.ClearLines then
        GameTooltip:ClearLines()
    end

    local title = talent.name or "Talent"
    if issecretvalue and issecretvalue(title) then
        GameTooltip:SetText(title)
    else
        GameTooltip:SetText(tostring(title), 1, 0.82, 0)
    end
    GameTooltip:AddLine("Rank " .. tostring(draftRank) .. "/" .. tostring(maxRank), 1, 1, 1, true)

    local sections = {}
    local sharedKey = nil
    local varied = false
    for rank = 1, maxRank do
        local data = FetchTraitTooltip(talent.entryID, talent.configID, rank)
        local lines, key = TooltipBody(data, title)
        sections[rank] = lines
        if key == nil then
            varied = true
        elseif sharedKey == nil then
            sharedKey = key
        elseif key ~= sharedKey then
            varied = true
        end
    end

    if not varied then
        if not AddBodyLines(sections[1] or {}) then
            AddTooltipLine(talent.description, 1, 1, 1)
        end
        GameTooltip:Show()
        return
    end

    for rank = 1, maxRank do
        local header = "Rank " .. tostring(rank)
        local r, g, b = 0.75, 0.75, 0.75
        if rank == draftRank then
            header = header .. " (in this build)"
            r, g, b = 0.2, 1, 0.2
        elseif rank == draftRank + 1 then
            header = header .. " (next point)"
            r, g, b = 1, 0.82, 0
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(header, r, g, b, true)
        if not AddBodyLines(sections[rank] or {}) and rank == 1 then
            AddTooltipLine(talent.description, 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

function API:LearnOne(tabIndex, talentIndex)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot change talents in combat."
    end
    local configID = self:ConfigID()
    if not configID or not (C_Traits and C_Traits.PurchaseRank) then
        return false, "Talent purchase is not available."
    end
    local nodeID = PlainNumber(talentIndex)
    if not nodeID then
        return false, "That talent cannot be learned."
    end
    if C_Traits.CanPurchaseRank then
        local allowedOk, allowed = pcall(C_Traits.CanPurchaseRank, configID, nodeID)
        if allowedOk and allowed == false then
            return false, "That talent cannot be learned yet."
        end
    end
    local ok, purchased = pcall(C_Traits.PurchaseRank, configID, nodeID)
    if not ok or purchased == false then
        return false, "The game did not accept that talent."
    end
    if C_Traits.CommitConfig then
        pcall(C_Traits.CommitConfig, configID)
    end
    return true
end

function API:Apply(build)
    if type(build) ~= "table" then
        return false, "No talent build selected."
    end
    if not self:Available() then
        return false, "Talents are not available on this client."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot apply talents in combat."
    end
    if not self:SameClass(build) then
        return false, "This build is for a different class."
    end

    local tabCount = self:TabCount()
    for tabIndex = 1, tabCount do
        local talents = self:Talents(tabIndex)
        for i = 1, #talents do
            local talent = talents[i]
            local wanted = self:DraftRank(build, tabIndex, talent.talentIndex)
            if talent.rank > wanted then
                return false, "Your character already spent points this build does not use. Reset talents at your class trainer, then apply again."
            end
        end
    end

    local learned = 0
    local skipped = {}
    local guard = 0
    while guard < 200 do
        guard = guard + 1
        local choice = nil
        local choiceTab = nil
        local choiceKey = nil
        for tabIndex = 1, tabCount do
            local talents = self:Talents(tabIndex)
            for i = 1, #talents do
                local talent = talents[i]
                local wanted = self:DraftRank(build, tabIndex, talent.talentIndex)
                local key = tostring(tabIndex) .. ":" .. tostring(talent.talentIndex)
                if talent.rank < wanted and not skipped[key] then
                    if not choice or talent.tier < choice.tier or (talent.tier == choice.tier and talent.column < choice.column) then
                        choice = talent
                        choiceTab = tabIndex
                        choiceKey = key
                    end
                end
            end
        end
        if not choice then
            break
        end
        if self:Unspent() < 1 then
            if learned > 0 then
                return true, "Applied " .. tostring(learned) .. " ranks. No unspent talent points left."
            end
            if not self:MatchesLive(build) then
                return false, "All of your talent points are already spent, and this build is different. Reset talents at your class trainer, then apply again."
            end
            return false, "All of your talent points are already spent."
        end
        local before = choice.rank
        local ok, err = self:LearnOne(choiceTab, choice.talentIndex)
        if not ok and (err == "Cannot change talents in combat." or err == "Talent purchase is not available.") then
            return false, err
        end
        local afterInfo = ok and self:TalentInfo(choiceTab, choice.talentIndex) or nil
        local after = afterInfo and afterInfo.rank or before
        if ok and after > before then
            learned = learned + 1
        else
            skipped[choiceKey] = true
        end
    end

    local remaining = false
    for tabIndex = 1, tabCount do
        local talents = self:Talents(tabIndex)
        for i = 1, #talents do
            local talent = talents[i]
            local wanted = self:DraftRank(build, tabIndex, talent.talentIndex)
            if talent.rank < wanted then
                remaining = true
                break
            end
        end
        if remaining then
            break
        end
    end
    if not remaining then
        return true, "Talents applied (" .. self:Summary(build) .. ")."
    end
    if learned > 0 then
        return true, "Applied " .. tostring(learned) .. " ranks. The rest of this build needs more talent points."
    end
    return false, "No talents from this build could be learned yet."
end
