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

local GEAR_SLOTS = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 4, 19, 16, 17 }
local NO_DURABILITY = { [2] = true, [4] = true, [11] = true, [12] = true, [13] = true, [14] = true, [19] = true }
local NO_ENCHANT = { [4] = true, [13] = true, [14] = true, [19] = true }
local NO_SOCKET = { [4] = true, [13] = true, [14] = true, [19] = true }

local JOURNEY_NAMES = {
    ["Delver's Journey"] = "delver",
    ["Delvers Journey"] = "delver",
    ["Prey"] = "prey",
    ["Traveler's Journey"] = "traveler",
    ["Traveller's Journey"] = "traveler",
}

local function JourneyKey(name)
    if not name or name == "" then
        return nil
    end
    if JOURNEY_NAMES[name] then
        return JOURNEY_NAMES[name]
    end
    local plain = string.lower(string.gsub(name, "’", "'"))
    if string.find(plain, "delver", 1, true) and string.find(plain, "journey", 1, true) then
        return "delver"
    end
    if string.find(plain, "travel", 1, true) and string.find(plain, "journey", 1, true) then
        return "traveler"
    end
    if string.find(plain, "prey", 1, true) and (string.find(plain, "journey", 1, true) or string.find(plain, "season", 1, true)) then
        return "prey"
    end
    return nil
end

local function Round(value)
    local ok, number = pcall(tonumber, value)
    if not ok or type(number) ~= "number" then
        return 0
    end
    return math.floor(number + 0.5)
end

local function Comma(value)
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

function Scan.Comma(value)
    return Comma(value)
end

local function ItemLevel()
    if not GetAverageItemLevel then
        return 0
    end
    local _, equipped = GetAverageItemLevel()
    return Round(equipped or 0)
end

local function ItemLevelQuality()
    local best = 1
    if not GetInventoryItemQuality then
        return best
    end
    local slot = 1
    while slot <= 17 do
        if slot ~= 4 then
            local quality = GetInventoryItemQuality("player", slot)
            if quality and quality > best then
                best = quality
            end
        end
        slot = slot + 1
    end
    return best
end

local function RatingPercent(reader, rating)
    if type(reader) ~= "function" or not rating then
        return 0
    end
    local ok, value = pcall(reader, rating)
    if not ok then
        return 0
    end
    local numberOk, number = pcall(tonumber, value)
    if numberOk and type(number) == "number" then
        return number
    end
    return 0
end

local function Versatility()
    local rating = CR_VERSATILITY_DAMAGE_DONE
    local total = RatingPercent(GetCombatRatingBonus, rating) + RatingPercent(GetVersatilityBonus, rating)
    return Round(total)
end
local function SafeText(value)
    if value == nil then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(value) then
        if type(string.concat) == "function" then
            local ok, text = pcall(string.concat, value)
            if ok and type(text) == "string" and text ~= "" and text ~= "nil" then
                return text
            end
        end
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

local function IsPositive(value)
    local number = AsNumber(value)
    return number ~= nil and number > 0
end

local function LoadSpellUI()
    local names = { "Blizzard_PlayerSpells", "Blizzard_ClassTalentUI" }
    local index = 1
    while names[index] do
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, names[index])
        elseif LoadAddOn then
            pcall(LoadAddOn, names[index])
        end
        index = index + 1
    end
end

local function AddTreeID(list, seen, treeID)
    local number = AsNumber(treeID)
    if number and number > 0 and not seen[number] then
        seen[number] = true
        list[#list + 1] = number
    end
end

local function SubTreeInfo(configID, subTreeID)
    if subTreeID == nil or not C_Traits or not C_Traits.GetSubTreeInfo then
        return nil
    end
    local ok, info = pcall(C_Traits.GetSubTreeInfo, configID, subTreeID)
    if not ok or type(info) ~= "table" then
        ok, info = pcall(C_Traits.GetSubTreeInfo, subTreeID)
    end
    if ok and type(info) == "table" then
        return info
    end
    return nil
end

local function SpellName(spellID)
    if spellID == nil then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, spellID)
        if ok then
            local text = SafeText(name)
            if text then
                return text
            end
        end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            local text = SafeText(info.name)
            if text then
                return text
            end
        end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, spellID)
        if ok then
            return SafeText(name)
        end
    end
    return nil
end

local function CurrentSpecID()
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecializationInfo then
        local ok, index = pcall(C_SpecializationInfo.GetSpecialization)
        if ok and index then
            local infoOk, specID = pcall(C_SpecializationInfo.GetSpecializationInfo, index)
            if infoOk then
                local number = AsNumber(specID)
                if number then
                    return number
                end
            end
        end
    end
    if GetSpecialization and GetSpecializationInfo then
        local ok, index = pcall(GetSpecialization)
        if ok and index then
            local infoOk, specID = pcall(GetSpecializationInfo, index)
            if infoOk then
                local number = AsNumber(specID)
                if number then
                    return number
                end
            end
        end
    end
    if PlayerUtil and PlayerUtil.GetCurrentSpecID then
        local ok, specID = pcall(PlayerUtil.GetCurrentSpecID)
        if ok then
            return AsNumber(specID)
        end
    end
    return nil
end

local function ActiveConfigID(specID)
    LoadSpellUI()
    local id = nil
    if C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local ok, value = pcall(C_ClassTalents.GetActiveConfigID)
        if ok then
            id = AsNumber(value)
        end
    end
    if id and id > 0 then
        return id
    end
    if specID and C_ClassTalents and C_ClassTalents.GetLastSelectedSavedConfigID then
        local ok, value = pcall(C_ClassTalents.GetLastSelectedSavedConfigID, specID)
        if ok then
            id = AsNumber(value)
        end
    end
    if id and id > 0 then
        return id
    end
    if specID and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID then
        local ok, ids = pcall(C_ClassTalents.GetConfigIDsBySpecID, specID)
        if ok and type(ids) == "table" then
            local index = 1
            while ids[index] do
                id = AsNumber(ids[index])
                if id and id > 0 then
                    return id
                end
                index = index + 1
            end
        end
    end
    if C_Traits and C_Traits.GetConfigsByType and Enum and Enum.TraitConfigType and Enum.TraitConfigType.Combat then
        local ok, ids = pcall(C_Traits.GetConfigsByType, Enum.TraitConfigType.Combat)
        if ok and type(ids) == "table" then
            local index = 1
            while ids[index] do
                id = AsNumber(ids[index])
                if id and id > 0 then
                    return id
                end
                index = index + 1
            end
        end
    end
    return nil
end

local function TalentName(configID, entryID)
    if not entryID or not C_Traits or not C_Traits.GetEntryInfo or not C_Traits.GetDefinitionInfo then
        return nil
    end
    local ok, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
    if not ok or type(entry) ~= "table" then
        ok, entry = pcall(C_Traits.GetEntryInfo, entryID)
    end
    if not ok or type(entry) ~= "table" then
        return nil
    end
    local defOk, definition = pcall(C_Traits.GetDefinitionInfo, entry.definitionID)
    if not defOk or type(definition) ~= "table" then
        return nil
    end
    local overrideName = SafeText(definition.overrideName)
    if overrideName then
        return overrideName
    end
    return SpellName(definition.spellID)
end

local IsSelectionNode

local function NodeTaken(nodeInfo)
    if type(nodeInfo) ~= "table" then
        return false
    end
    if AsNumber(nodeInfo.ID) == 0 then
        return false
    end
    local visibleOk, visible = pcall(function()
        return nodeInfo.isVisible ~= false
    end)
    if visibleOk and not visible then
        return false
    end
    local hiddenOk, hidden = pcall(function()
        return nodeInfo.subTreeActive == false
    end)
    if hiddenOk and hidden then
        return false
    end
    return IsPositive(nodeInfo.ranksPurchased)
end

local function FirstEntryID(nodeInfo)
    if type(nodeInfo.activeEntry) == "table" and nodeInfo.activeEntry.entryID then
        return nodeInfo.activeEntry.entryID
    end
    if type(nodeInfo.entryIDs) == "table" and nodeInfo.entryIDs[1] and not nodeInfo.entryIDs[2] then
        return nodeInfo.entryIDs[1]
    end
    return nil
end

function IsSelectionNode(nodeInfo)
    local ok, match = pcall(function()
        if nodeInfo.isSubTreeSelection then
            return true
        end
        local selectionType = Enum and Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection
        if selectionType and nodeInfo.type == selectionType then
            return true
        end
        return false
    end)
    return ok and match or false
end

local function SpecKind(configID, nodeInfo, specID)
    if not specID or type(nodeInfo.conditionIDs) ~= "table" or not C_Traits.GetConditionInfo or not C_SpecializationInfo or not C_SpecializationInfo.GetSpecIDs then
        return "class"
    end
    local sawSpec = false
    local matches = false
    local index = 1
    while nodeInfo.conditionIDs[index] do
        local ok, condition = pcall(C_Traits.GetConditionInfo, configID, nodeInfo.conditionIDs[index])
        local specSetID = ok and condition and AsNumber(condition.specSetID)
        if specSetID and specSetID > 0 then
            sawSpec = true
            local specOk, specIDs = pcall(C_SpecializationInfo.GetSpecIDs, specSetID)
            if specOk and type(specIDs) == "table" then
                local specIndex = 1
                while specIDs[specIndex] do
                    if AsNumber(specIDs[specIndex]) == specID then
                        matches = true
                    end
                    specIndex = specIndex + 1
                end
            end
        end
        index = index + 1
    end
    if sawSpec and matches then
        return "spec"
    end
    return "class"
end

local function Classify(configID, nodeInfo, heroSubTreeID, specID)
    local subNumber = AsNumber(nodeInfo.subTreeID)
    if subNumber and subNumber > 0 then
        local active = AsNumber(heroSubTreeID)
        if active and subNumber ~= active then
            return nil
        end
        local hiddenOk, hidden = pcall(function()
            return nodeInfo.subTreeActive == false
        end)
        if hiddenOk and hidden then
            return nil
        end
        return "hero"
    end
    local ok, kind = pcall(SpecKind, configID, nodeInfo, specID)
    if ok and kind then
        return kind
    end
    return "class"
end

local function RememberHero(state, configID, subTreeID)
    local number = AsNumber(subTreeID)
    if number and number > 0 then
        state.heroSubTreeID = number
    end
    local info = SubTreeInfo(configID, subTreeID)
    local name = info and SafeText(info.name)
    if name then
        state.heroName = name
    end
    if info then
        AddTreeID(state.trees, state.seenTrees, info.traitTreeID)
    end
end

local function ReadOneNode(state, configID, specID, nodeInfo, seen)
    if not NodeTaken(nodeInfo) then
        return
    end
    local entryID = FirstEntryID(nodeInfo)
    if not entryID then
        return
    end
    if IsSelectionNode(nodeInfo) then
        local ok, entry = pcall(C_Traits.GetEntryInfo, configID, entryID)
        if (not ok or type(entry) ~= "table") and C_Traits.GetEntryInfo then
            ok, entry = pcall(C_Traits.GetEntryInfo, entryID)
        end
        if ok and type(entry) == "table" and entry.subTreeID then
            RememberHero(state, configID, entry.subTreeID)
        end
        return
    end
    local name = TalentName(configID, entryID)
    if not name then
        return
    end
    local key = AsNumber(entryID) or AsNumber(nodeInfo.ID) or name
    if seen[key] then
        return
    end
    local tree = Classify(configID, nodeInfo, state.heroSubTreeID, specID)
    if not tree then
        return
    end
    seen[key] = true
    local rank = AsNumber(nodeInfo.ranksPurchased) or AsNumber(nodeInfo.ranksIncreased) or AsNumber(nodeInfo.activeRank) or 1
    if type(nodeInfo.activeEntry) == "table" then
        local entryRank = AsNumber(nodeInfo.activeEntry.rank)
        if entryRank and entryRank > 0 then
            rank = entryRank
        end
    end
    state.talents[#state.talents + 1] = {
        entryID = AsNumber(entryID),
        name = name,
        tree = tree,
        rank = rank,
    }
end

local function ReadTalents()
    local state = {
        talents = {},
        heroName = nil,
        heroSubTreeID = nil,
        trees = {},
        seenTrees = {},
    }
    local specID = nil
    local configID = nil
    pcall(function()
        specID = CurrentSpecID()
        configID = ActiveConfigID(specID)
        if C_ClassTalents and C_ClassTalents.GetActiveHeroTalentSpec then
            local ok, heroID = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
            if ok and heroID ~= nil then
                RememberHero(state, configID, heroID)
            end
        end
    end)
    if not configID then
        return state.talents, state.heroName
    end
    pcall(function()
        if C_Traits.GetConfigInfo then
            local ok, config = pcall(C_Traits.GetConfigInfo, configID)
            if ok and type(config) == "table" and type(config.treeIDs) == "table" then
                local index = 1
                while index < 20 do
                    local readOk, treeID = pcall(function()
                        return config.treeIDs[index]
                    end)
                    if not readOk or treeID == nil then
                        break
                    end
                    AddTreeID(state.trees, state.seenTrees, treeID)
                    index = index + 1
                end
            end
        end
        if specID and C_ClassTalents and C_ClassTalents.GetTraitTreeForSpec then
            local ok, treeID = pcall(C_ClassTalents.GetTraitTreeForSpec, specID)
            if ok then
                AddTreeID(state.trees, state.seenTrees, treeID)
            end
        end
        local seen = {}
        local treeIndex = 1
        while state.trees[treeIndex] do
            local nodesOk, nodes = pcall(C_Traits.GetTreeNodes, state.trees[treeIndex])
            local nodeIndex = 1
            while nodesOk and type(nodes) == "table" and nodeIndex < 5000 do
                local readOk, nodeID = pcall(function()
                    return nodes[nodeIndex]
                end)
                if not readOk or nodeID == nil then
                    break
                end
                local nodeOk, nodeInfo = pcall(C_Traits.GetNodeInfo, configID, nodeID)
                if nodeOk and type(nodeInfo) == "table" then
                    pcall(ReadOneNode, state, configID, specID, nodeInfo, seen)
                end
                nodeIndex = nodeIndex + 1
            end
            treeIndex = treeIndex + 1
        end
    end)
    return state.talents, state.heroName
end
local function ReadJourneys()
    local journeys = {}
    if not C_MajorFactions or not C_MajorFactions.GetMajorFactionIDs or not C_MajorFactions.GetMajorFactionData then
        return journeys
    end
    local ids = C_MajorFactions.GetMajorFactionIDs()
    local index = 1
    while ids and ids[index] do
        local data = C_MajorFactions.GetMajorFactionData(ids[index])
        local key = data and data.name and JourneyKey(data.name)
        if key then
            local candidate = {
                current = tonumber(data.renownReputationEarned) or 0,
                maximum = tonumber(data.renownLevelThreshold) or 0,
                rank = tonumber(data.renownLevel) or 0,
            }
            local previous = journeys[key]
            if not previous or candidate.rank > previous.rank or (candidate.rank == previous.rank and candidate.current > previous.current) then
                journeys[key] = candidate
            end
        end
        index = index + 1
    end
    return journeys
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

function Scan.ApplyTalentIcon(texture, entryID)
    if not texture or not entryID or not C_Traits or not C_Traits.GetEntryInfo or not C_Traits.GetDefinitionInfo then
        return false
    end
    local configID = ActiveConfigID(CurrentSpecID())
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
    if defOk and type(definition) == "table" then
        local overrideOk, hasOverride = pcall(function()
            return definition.overrideIcon ~= nil and definition.overrideIcon ~= ""
        end)
        if overrideOk and hasOverride and ApplyClientIcon(texture, definition.overrideIcon) then
            return true
        end
        if definition.spellID and C_Spell and C_Spell.GetSpellTexture then
            local texOk, iconID, originalIconID = pcall(C_Spell.GetSpellTexture, definition.spellID)
            if texOk and ApplyClientIcon(texture, originalIconID) then
                return true
            end
            if texOk and ApplyClientIcon(texture, iconID) then
                return true
            end
        end
    end
    if entry.subTreeID then
        local shown = false
        pcall(function()
            local info = SubTreeInfo(configID, entry.subTreeID)
            if info and info.iconElementID and info.iconElementID ~= "" and ApplyClientIcon(texture, info.iconElementID) then
                shown = true
            end
        end)
        if shown then
            return true
        end
    end
    return false
end

local function LinkBody(link)
    if type(link) ~= "string" then
        return nil
    end
    return link:match("item:([%d:%-]+)")
end

local function LinkNumber(link, index)
    local body = LinkBody(link)
    if not body then
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
    if GetInventoryItemQuality then
        local ok, quality = pcall(GetInventoryItemQuality, "player", slot)
        if ok and type(quality) == "number" then
            return quality
        end
    end
    if C_Item and C_Item.GetItemQualityByID and itemID then
        local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
        if ok and type(quality) == "number" then
            return quality
        end
    end
    return 1
end

local function ItemIcon(itemID, slot)
    if GetInventoryItemTexture then
        local ok, texture = pcall(GetInventoryItemTexture, "player", slot)
        if ok and texture and texture ~= 0 then
            return texture
        end
    end
    if C_Item and C_Item.GetItemIconByID and itemID then
        local ok, texture = pcall(C_Item.GetItemIconByID, itemID)
        if ok and texture and texture ~= 0 then
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
    if type(line.type) == "number" then
        return line.type
    end
    local ok, number = pcall(tonumber, line.type)
    if ok and type(number) == "number" then
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

local function EnchantName(slot, link)
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
    local link
    if GetInventoryItemLink then
        local ok, value = pcall(GetInventoryItemLink, "player", slot)
        if ok then
            link = SafeText(value)
        end
    end
    local name, looked = EnchantName(slot, link)
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
    local currentOk, current = pcall(tonumber, info.currentLevel)
    local maxOk, maximum = pcall(tonumber, info.maxLevel)
    if track and currentOk and maxOk and type(current) == "number" and type(maximum) == "number" and maximum > 0 then
        return string.format("%s %d/%d", track, current, maximum), true
    end
    return nil, true
end

local function SocketCount(link)
    if C_Item and C_Item.GetItemNumSockets then
        local ok, count = pcall(C_Item.GetItemNumSockets, link)
        local numberOk, number = pcall(tonumber, count)
        if ok and numberOk and type(number) == "number" and number >= 0 then
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
    while GEAR_SLOTS[index] do
        local slot = GEAR_SLOTS[index]
        local itemID
        if GetInventoryItemID then
            local ok, id = pcall(GetInventoryItemID, "player", slot)
            if ok and type(id) == "number" and id > 0 then
                itemID = id
            end
        end
        if not itemID then
            gear[slot] = { slot = slot, empty = true }
        else
            if C_Item and C_Item.RequestLoadItemDataByID then
                pcall(C_Item.RequestLoadItemDataByID, itemID)
            end
            local link
            if GetInventoryItemLink then
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
            if not NO_DURABILITY[slot] and GetInventoryItemDurability then
                local ok, current, maximum = pcall(GetInventoryItemDurability, slot)
                local currentOk, currentN = pcall(tonumber, current)
                local maxOk, maxN = pcall(tonumber, maximum)
                if ok and currentOk and maxOk and type(maxN) == "number" and maxN > 0 and type(currentN) == "number" then
                    row.durabilityCurrent = currentN
                    row.durabilityMax = maxN
                end
            end
            if NO_ENCHANT[slot] then
                row.enchantID = 0
                row.enchantName = "cannot"
            else
                local enchantID = LinkNumber(link, 2)
                local enchantName, looked = EnchantName(slot, link)
                row.enchantID = enchantID
                if enchantName then
                    row.enchantName = enchantName
                elseif looked then
                    row.enchantName = "not-enchanted"
                elseif enchantID > 0 then
                    ready = false
                else
                    row.enchantName = "not-enchanted"
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
                    if (not gemName or gemName == "") and C_Item and C_Item.GetItemGem and link then
                        local gemOk, apiName = pcall(C_Item.GetItemGem, link, filled)
                        if gemOk then
                            gemName = SafeText(apiName)
                        end
                    end
                    local gemQuality = 1
                    if C_Item and C_Item.GetItemQualityByID then
                        local qualityOk, quality = pcall(C_Item.GetItemQualityByID, gemID)
                        if qualityOk and type(quality) == "number" then
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

local function BagSize(bag)
    if not C_Container or not C_Container.GetContainerNumSlots then
        return 0
    end
    local ok, count = pcall(C_Container.GetContainerNumSlots, bag)
    local number = ok and AsNumber(count) or nil
    if number and number > 0 then
        return number
    end
    return 0
end

local function ContainerInfo(bag, slot)
    if not C_Container or not C_Container.GetContainerItemInfo then
        return nil
    end
    local ok, first, count, _, quality, _, _, link, _, _, itemID = pcall(C_Container.GetContainerItemInfo, bag, slot)
    if not ok or first == nil then
        return nil
    end
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

local function ReadBags()
    local reagent = 5
    if Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag ~= nil then
        local number = AsNumber(Enum.BagIndex.ReagentBag)
        if number then
            reagent = number
        end
    end
    local ids = { 0, 1, 2, 3, 4 }
    if reagent ~= 0 and reagent ~= 1 and reagent ~= 2 and reagent ~= 3 and reagent ~= 4 then
        ids[#ids + 1] = reagent
    end
    local bags = {}
    local ready = true
    local index = 1
    while ids[index] do
        local bag = ids[index]
        local size = BagSize(bag)
        if size > 0 then
            local row = { bag = bag, size = size, slots = {} }
            if bag == 0 then
                row.name = "Backpack"
                if C_Container.GetBagName then
                    local ok, name = pcall(C_Container.GetBagName, bag)
                    name = ok and SafeText(name) or nil
                    if name then
                        row.name = name
                    end
                end
                row.icon = "Interface\\Buttons\\Button-Backpack-Up"
            else
                local inv
                if C_Container.ContainerIDToInventoryID then
                    local ok, id = pcall(C_Container.ContainerIDToInventoryID, bag)
                    if ok then
                        inv = AsNumber(id)
                    end
                end
                local link
                if inv and GetInventoryItemLink then
                    local ok, value = pcall(GetInventoryItemLink, "player", inv)
                    if ok then
                        link = SafeText(value)
                    end
                end
                local itemID
                if inv and GetInventoryItemID then
                    local ok, id = pcall(GetInventoryItemID, "player", inv)
                    if ok then
                        itemID = AsNumber(id)
                    end
                end
                if itemID and C_Item and C_Item.RequestLoadItemDataByID then
                    pcall(C_Item.RequestLoadItemDataByID, itemID)
                end
                row.itemID = itemID
                row.link = link
                row.name = ItemName(itemID, link)
                if not row.name and C_Container.GetBagName then
                    local ok, name = pcall(C_Container.GetBagName, bag)
                    row.name = ok and SafeText(name) or nil
                end
                if not row.name then
                    row.name = "Bag"
                    ready = false
                end
                row.quality = 1
                if itemID and C_Item and C_Item.GetItemQualityByID then
                    local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
                    quality = ok and AsNumber(quality) or nil
                    if quality then
                        row.quality = quality
                    end
                end
                row.icon = ItemIcon(itemID, inv)
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
                    local link = SafeText(info.hyperlink)
                    if not link and C_Container.GetContainerItemLink then
                        local linkOk, value = pcall(C_Container.GetContainerItemLink, bag, slot)
                        if linkOk then
                            link = SafeText(value)
                        end
                    end
                    local name = ItemName(itemID, link)
                    if not name or not link then
                        ready = false
                    end
                    local count = AsNumber(info.stackCount) or 1
                    if count < 1 then
                        count = 1
                    end
                    local quality = AsNumber(info.quality)
                    if quality == nil and info.itemQuality ~= nil then
                        quality = AsNumber(info.itemQuality)
                    end
                    if quality == nil and C_Item and C_Item.GetItemQualityByID then
                        local qualityOk, value = pcall(C_Item.GetItemQualityByID, itemID)
                        quality = qualityOk and AsNumber(value) or nil
                    end
                    local icon = AsNumber(info.iconFileID)
                    if not icon then
                        icon = ItemIcon(itemID, nil)
                    end
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
    while ids[index] do
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
                local link = SafeText(info.hyperlink)
                if not link and C_Container and C_Container.GetContainerItemLink then
                    local linkOk, value = pcall(C_Container.GetContainerItemLink, bag, slot)
                    if linkOk then
                        link = SafeText(value)
                    end
                end
                local name = ItemName(itemID, link)
                if not name or not link then
                    ready = false
                end
                local count = AsNumber(info.stackCount) or 1
                if count < 1 then
                    count = 1
                end
                local quality = AsNumber(info.quality)
                if quality == nil and info.itemQuality ~= nil then
                    quality = AsNumber(info.itemQuality)
                end
                if quality == nil and C_Item and C_Item.GetItemQualityByID then
                    local qualityOk, value = pcall(C_Item.GetItemQualityByID, itemID)
                    quality = qualityOk and AsNumber(value) or nil
                end
                local icon = AsNumber(info.iconFileID)
                if not icon then
                    icon = ItemIcon(itemID, nil)
                end
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

local function BankTabIcon(bankType)
    if not C_Bank or not C_Bank.FetchPurchasedBankTabData or bankType == nil then
        return nil
    end
    local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
    if not ok or type(tabs) ~= "table" or type(tabs[1]) ~= "table" then
        return nil
    end
    return AsNumber(tabs[1].icon) or tabs[1].icon
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

local bankOpen = false
local guildOpen = false
local bankWait = false
local guildWait = false
local bankTries = 0
local guildTries = 0

local function SavePersonalBank()
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB.Get(guid) or nil
    if not record then
        return true
    end
    local bankType = Enum and Enum.BankType and Enum.BankType.Character
    local slots, filled, ready = ReadContainerSlots(EnumBags("CharacterBankTab_", 9))
    if not slots[1] then
        if not BankTabIcon(bankType) and not (C_Bank and C_Bank.FetchPurchasedBankTabData) then
            return false
        end
        local answered = false
        if C_Bank and C_Bank.FetchPurchasedBankTabData and bankType ~= nil then
            local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
            answered = ok and type(tabs) == "table"
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

local function SaveWarbandBank()
    local bankType = Enum and Enum.BankType and Enum.BankType.Account
    local slots, filled, ready = ReadContainerSlots(EnumBags("AccountBankTab_", 9))
    if not slots[1] then
        local answered = false
        if C_Bank and C_Bank.FetchPurchasedBankTabData and bankType ~= nil then
            local ok, tabs = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
            answered = ok and type(tabs) == "table"
        end
        if not answered then
            return false
        end
    end
    local account = BMGAM.DB.Account()
    account.warbandBank = {
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
    local name = GetGuildInfo and GetGuildInfo("player") or nil
    name = SafeText(name)
    if not name or name == "" then
        return nil
    end
    local realm = SafeText(GetRealmName and GetRealmName() or nil) or ""
    return realm .. "-" .. name
end

local function SaveGuildBank()
    local key = GuildStorageKey()
    if not key or not GetNumGuildBankTabs or not GetGuildBankTabInfo or not GetGuildBankItemLink then
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
        local canView = infoOk and (viewable == true or viewable == 1)
        if canView then
            if not icon and tabIcon then
                icon = AsNumber(tabIcon) or tabIcon
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
                    if GetGuildBankItemInfo then
                        local itemOk, tex, stack, _, _, itemQuality = pcall(GetGuildBankItemInfo, tab, slot)
                        if itemOk then
                            texture = AsNumber(tex) or tex
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
                        icon = texture or ItemIcon(itemID, nil),
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
    local warbandReady = SaveWarbandBank()
    if (not personalReady or not warbandReady) and bankTries < 5 and not bankWait and C_Timer and C_Timer.After then
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

local guildQueried = false

function Scan.ReadOpenGuildBank()
    if not guildOpen then
        return
    end
    if not guildQueried and GetNumGuildBankTabs and QueryGuildBankTab then
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

local currencyTries = 0
local currencyWait = false
local currencyScan = false

local function TrueFlag(value)
    return value == true or value == 1
end

local function CurrencyTag(name)
    local plain = string.gsub(name, "’", "'")
    if plain == "Trader's Tender" then
        return "account"
    end
    if plain == "Honor" or plain == "Honor Points" then
        return "pvp"
    end
    return nil
end

local function CurrencyLinkID(index)
    if not C_CurrencyInfo.GetCurrencyListLink then
        return nil
    end
    local ok, link = pcall(C_CurrencyInfo.GetCurrencyListLink, index)
    local text = ok and SafeText(link) or nil
    if not text then
        return nil
    end
    local parsed = string.match(text, "currency:(%d+)")
    return parsed and tonumber(parsed) or nil
end

local function ReadCurrencyInfo(index)
    local ok, first, second, third, fourth, fifth, sixth, seventh, eighth = pcall(C_CurrencyInfo.GetCurrencyListInfo, index)
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

local expandedHeader = {}
local categoryMap = nil

local function ListSize()
    local ok, value = pcall(C_CurrencyInfo.GetCurrencyListSize)
    local size = ok and AsNumber(value) or 0
    if not size or size < 1 then
        return 0
    end
    return size
end

local function HeaderOpen(info)
    if not info then
        return nil
    end
    if TrueFlag(info.isHeaderExpanded) or TrueFlag(info.isExpanded) then
        return true
    end
    if info.isHeaderExpanded == false or info.isHeaderExpanded == 0 or info.isExpanded == false or info.isExpanded == 0 then
        return false
    end
    return nil
end

local function ExpandCurrencyHeaders()
    if not C_CurrencyInfo.ExpandCurrencyList then
        return false
    end
    local opened = false
    local pass = 1
    while pass <= 8 do
        local size = ListSize()
        if size < 1 then
            return opened
        end
        local grew = false
        local index = 1
        while index <= size do
            local info = ReadCurrencyInfo(index)
            local headerName = info and SafeText(info.name) or nil
            local openState = HeaderOpen(info)
            if info and headerName and TrueFlag(info.isHeader) and openState ~= true and not expandedHeader[headerName] then
                local before = ListSize()
                pcall(C_CurrencyInfo.ExpandCurrencyList, index, true)
                local after = ListSize()
                if after < before then
                    pcall(C_CurrencyInfo.ExpandCurrencyList, index, true)
                    after = ListSize()
                end
                expandedHeader[headerName] = true
                if after > before then
                    grew = true
                    size = after
                end
                opened = true
            end
            index = index + 1
        end
        if not grew then
            return opened
        end
        pass = pass + 1
    end
    return opened
end

local function IndexValues(tbl)
    local out = {}
    if type(tbl) ~= "table" then
        return out
    end
    local function add(value)
        if value ~= nil and value ~= false then
            out[#out + 1] = value
        end
    end
    pcall(function()
        local index = 1
        while index <= 400 do
            local ok, value = pcall(function()
                return tbl[index]
            end)
            if not ok or value == nil then
                return
            end
            add(value)
            index = index + 1
        end
    end)
    if out[1] then
        return out
    end
    pcall(function()
        for key, value in pairs(tbl) do
            if type(value) == "number" or type(value) == "string" then
                add(value)
            elseif type(key) == "number" then
                add(key)
            else
                add(value)
            end
            if #out >= 400 then
                return
            end
        end
    end)
    return out
end

local function CurrencyRow(info, headerName)
    local name = info and SafeText(info.name) or nil
    if not name or TrueFlag(info.isHeader) then
        return nil
    end
    local amount = AsNumber(info.quantity)
    if not amount then
        amount = 0
    end
    local maxQty = AsNumber(info.maxQuantity)
    if not maxQty or maxQty <= 0 then
        maxQty = nil
    end
    return {
        id = AsNumber(info.currencyID),
        name = name,
        icon = AsNumber(info.iconFileID),
        expansion = headerName,
        amount = amount,
        max = maxQty,
        tag = CurrencyTag(name),
        unused = TrueFlag(info.isTypeUnused),
    }
end

local function HeaderOrder()
    local order = {}
    local sizeOk, sizeValue = pcall(C_CurrencyInfo.GetCurrencyListSize)
    local size = sizeOk and AsNumber(sizeValue) or 0
    if not size or size < 1 then
        return order
    end
    local index = 1
    local rank = 0
    while index <= size do
        local info = ReadCurrencyInfo(index)
        local name = info and SafeText(info.name) or nil
        if info and name and TrueFlag(info.isHeader) and not order[name] then
            rank = rank + 1
            order[name] = rank
        end
        index = index + 1
    end
    return order
end

local function CollectCategoryCurrencies()
    if not C_CurrencyInfo.GetPlayerCurrencyCategoryInfo or not C_CurrencyInfo.GetCurrencyInfo then
        return nil
    end
    local cache = categoryMap and categoryMap.cache or nil
    local childOf = categoryMap and categoryMap.childOf or nil
    if not cache then
        cache = {}
        childOf = {}
    local id = 0
    while id <= 2500 do
        local ok, info = pcall(C_CurrencyInfo.GetPlayerCurrencyCategoryInfo, id, true)
        local name = ok and type(info) == "table" and SafeText(info.categoryName) or nil
        if name then
            local children = {}
            local listed = IndexValues(info.childCategories or info.children or info.childCategoryIDs)
            local childIndex = 1
            while listed[childIndex] do
                local childId = AsNumber(listed[childIndex]) or listed[childIndex]
                if childId then
                    children[#children + 1] = childId
                    childOf[childId] = true
                end
                childIndex = childIndex + 1
            end
            local currencyIds = {}
            local listedIds = IndexValues(info.currencyTypes or info.currencyIDs or info.currencies)
            local typeIndex = 1
            while listedIds[typeIndex] do
                local currencyId = AsNumber(listedIds[typeIndex]) or listedIds[typeIndex]
                if currencyId then
                    currencyIds[#currencyIds + 1] = currencyId
                end
                typeIndex = typeIndex + 1
            end
            cache[id] = { id = id, name = name, children = children, currencyIds = currencyIds }
        end
        id = id + 1
    end
        local wave = 1
        while wave <= 6 do
            local missing = {}
            for _, category in pairs(cache) do
                local childIndex = 1
                while category.children[childIndex] do
                    local childId = category.children[childIndex]
                    if childId and not cache[childId] then
                        missing[#missing + 1] = childId
                    end
                    childIndex = childIndex + 1
                end
            end
            if not missing[1] then
                wave = 7
            else
                local missingIndex = 1
                while missing[missingIndex] do
                    local childId = missing[missingIndex]
                    if not cache[childId] then
                        local childOk, childInfo = pcall(C_CurrencyInfo.GetPlayerCurrencyCategoryInfo, childId, true)
                        local childName = childOk and type(childInfo) == "table" and SafeText(childInfo.categoryName) or nil
                        if childName then
                            local children = {}
                            local listed = IndexValues(childInfo.childCategories or childInfo.children or childInfo.childCategoryIDs)
                            local childListIndex = 1
                            while listed[childListIndex] do
                                local listedId = AsNumber(listed[childListIndex])
                                if listedId then
                                    children[#children + 1] = listedId
                                    childOf[listedId] = true
                                end
                                childListIndex = childListIndex + 1
                            end
                            local currencyIds = {}
                            local listedIds = IndexValues(childInfo.currencyTypes or childInfo.currencyIDs or childInfo.currencies)
                            local typeIndex = 1
                            while listedIds[typeIndex] do
                                local currencyId = AsNumber(listedIds[typeIndex]) or listedIds[typeIndex]
                                if currencyId then
                                    currencyIds[#currencyIds + 1] = currencyId
                                end
                                typeIndex = typeIndex + 1
                            end
                            cache[childId] = { id = childId, name = childName, children = children, currencyIds = currencyIds }
                        end
                    end
                    missingIndex = missingIndex + 1
                end
                wave = wave + 1
            end
        end
        local foundId = nil
        for categoryId in pairs(cache) do
            if not foundId then
                foundId = categoryId
            end
        end
        if foundId then
            categoryMap = { cache = cache, childOf = childOf }
        end
    end
    local seenCurrency = {}
    local heldUnused = {}
    local function TakeCurrencies(category, headerName)
        local rows = {}
        local index = 1
        while category.currencyIds[index] do
            local currencyId = category.currencyIds[index]
            local key = AsNumber(currencyId) or SafeText(currencyId)
            if key and not seenCurrency[key] then
                local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyId)
                local row = ok and CurrencyRow(info, headerName) or nil
                if row then
                    if not row.id then
                        row.id = AsNumber(currencyId)
                    end
                    seenCurrency[key] = true
                    if row.unused and headerName ~= "Unused" then
                        row.expansion = "Unused"
                        row.unused = nil
                        heldUnused[#heldUnused + 1] = row
                    else
                        row.unused = nil
                        rows[#rows + 1] = row
                    end
                end
            end
            index = index + 1
        end
        return rows
    end
    local seenCategory = {}
    local function BuildNode(categoryId)
        if seenCategory[categoryId] then
            return nil
        end
        seenCategory[categoryId] = true
        local category = cache[categoryId]
        if not category then
            return nil
        end
        local node = { name = category.name, rows = TakeCurrencies(category, category.name), children = {} }
        local index = 1
        while category.children[index] do
            local child = BuildNode(category.children[index])
            if child then
                node.children[#node.children + 1] = child
            end
            index = index + 1
        end
        if not node.rows[1] and not node.children[1] then
            return nil
        end
        return node
    end
    local roots = {}
    for categoryId, category in pairs(cache) do
        if not childOf[categoryId] then
            roots[#roots + 1] = category
        end
    end
    local order = HeaderOrder()
    table.sort(roots, function(a, b)
        local aRank = order[a.name] or 100000
        local bRank = order[b.name] or 100000
        if aRank == bRank then
            return a.id < b.id
        end
        return aRank < bRank
    end)
    local nodes = {}
    local rootIndex = 1
    while roots[rootIndex] do
        local node = BuildNode(roots[rootIndex].id)
        if node then
            if not node.rows[1] and node.children[1] then
                local childIndex = 1
                while node.children[childIndex] do
                    nodes[#nodes + 1] = node.children[childIndex]
                    childIndex = childIndex + 1
                end
            else
                nodes[#nodes + 1] = node
            end
        end
        rootIndex = rootIndex + 1
    end
    local sections = {}
    local list = {}
    local function Flatten(node, depth)
        local section = { name = node.name, depth = depth, rows = node.rows }
        sections[#sections + 1] = section
        local index = 1
        while node.rows[index] do
            list[#list + 1] = node.rows[index]
            index = index + 1
        end
        index = 1
        while node.children[index] do
            Flatten(node.children[index], depth + 1)
            index = index + 1
        end
    end
    local nodeIndex = 1
    while nodes[nodeIndex] do
        Flatten(nodes[nodeIndex], 0)
        nodeIndex = nodeIndex + 1
    end
    if heldUnused[1] then
        local unusedSection = nil
        local sectionIndex = 1
        while sections[sectionIndex] do
            if sections[sectionIndex].name == "Unused" then
                unusedSection = sections[sectionIndex]
            end
            sectionIndex = sectionIndex + 1
        end
        if not unusedSection then
            unusedSection = { name = "Unused", depth = 0, rows = {} }
            sections[#sections + 1] = unusedSection
        end
        local index = 1
        while heldUnused[index] do
            unusedSection.rows[#unusedSection.rows + 1] = heldUnused[index]
            list[#list + 1] = heldUnused[index]
            index = index + 1
        end
    end
    if not list[1] then
        return nil
    end
    return { currencies = list, sections = sections }
end

local function CollectCurrencies()
    local sizeOk, sizeValue = pcall(C_CurrencyInfo.GetCurrencyListSize)
    local size = sizeOk and AsNumber(sizeValue) or 0
    if not size or size < 1 then
        return nil
    end
    local sections = {}
    local list = {}
    local current = nil
    local index = 1
    while index <= size do
        local info = ReadCurrencyInfo(index)
        if info then
            local name = SafeText(info.name)
            if TrueFlag(info.isHeader) and name then
                current = { name = name, depth = AsNumber(info.depth) or 0, rows = {} }
                sections[#sections + 1] = current
            elseif name and current then
                local amount = AsNumber(info.quantity)
                if not amount then
                    amount = 0
                end
                local maxQty = AsNumber(info.maxQuantity)
                if not maxQty or maxQty <= 0 then
                    maxQty = nil
                end
                local row = {
                    id = AsNumber(info.currencyID) or AsNumber(info.currencyTypesID) or CurrencyLinkID(index),
                    name = name,
                    icon = AsNumber(info.iconFileID),
                    expansion = current.name,
                    amount = amount,
                    max = maxQty,
                    tag = CurrencyTag(name),
                }
                current.rows[#current.rows + 1] = row
                list[#list + 1] = row
            end
        end
        index = index + 1
    end
    if not list[1] then
        return nil
    end
    return { currencies = list, sections = sections }
end

local function PackCount(pack)
    local count = 0
    if type(pack) ~= "table" or type(pack.currencies) ~= "table" then
        return 0
    end
    local index = 1
    while pack.currencies[index] do
        count = count + 1
        index = index + 1
    end
    return count
end

local function PackHas(pack, headerName)
    if type(pack) ~= "table" or type(pack.sections) ~= "table" then
        return false
    end
    local index = 1
    while pack.sections[index] do
        if pack.sections[index].name == headerName then
            return true
        end
        index = index + 1
    end
    return false
end

local function MergePacks(primary, extra)
    if PackCount(extra) < 1 then
        return primary
    end
    if type(primary) ~= "table" or type(primary.currencies) ~= "table" then
        return extra
    end
    local seen = {}
    local index = 1
    while primary.currencies[index] do
        local id = primary.currencies[index].id
        if id then
            seen[id] = true
        end
        index = index + 1
    end
    if type(primary.sections) ~= "table" then
        primary.sections = {}
    end
    index = 1
    while extra.currencies[index] do
        local row = extra.currencies[index]
        if not row.id or not seen[row.id] then
            if row.id then
                seen[row.id] = true
            end
            primary.currencies[#primary.currencies + 1] = row
            local headerName = row.expansion or ""
            local section = nil
            local sectionIndex = 1
            while primary.sections[sectionIndex] do
                if primary.sections[sectionIndex].name == headerName then
                    section = primary.sections[sectionIndex]
                end
                sectionIndex = sectionIndex + 1
            end
            if not section then
                section = { name = headerName, depth = 0, rows = {} }
                primary.sections[#primary.sections + 1] = section
            end
            section.rows[#section.rows + 1] = row
        end
        index = index + 1
    end
    return primary
end

local function ChooseCurrencies(list, categoryList)
    local listCount = PackCount(list)
    local categoryCount = PackCount(categoryList)
    local primary = list
    local extra = categoryList
    if categoryCount > listCount or (PackHas(categoryList, "Legacy") and not PackHas(list, "Legacy")) then
        primary = categoryList
        extra = list
    end
    return MergePacks(primary, extra)
end

local function SavedCount(record)
    local count = 0
    if type(record.currencies) ~= "table" then
        return 0
    end
    local index = 1
    while record.currencies[index] do
        count = count + 1
        index = index + 1
    end
    return count
end

local function SaveCurrencies(record, pack)
    if PackCount(pack) < 1 or PackCount(pack) < SavedCount(record) then
        return
    end
    record.currencies = pack.currencies
    record.currencySections = pack.sections
end

local function RememberLine(lines, seen, id)
    local number = AsNumber(id)
    if number and number > 0 and not seen[number] then
        seen[number] = true
        lines[#lines + 1] = number
    end
end

local function LineKnown(skillLine)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        return true
    end
    local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
    if not ok or type(info) ~= "table" then
        return false
    end
    local skill = AsNumber(info.skillLevel)
    return skill ~= nil and skill > 0
end

local function ProfessionSkillLines()
    local lines = {}
    local seen = {}
    if GetProfessions and GetProfessionInfo then
        local ok, first, second, archaeology, fishing, cooking = pcall(GetProfessions)
        if ok then
            local slots = { first, second, archaeology, fishing, cooking }
            local index = 1
            while slots[index] do
                local infoOk, _, _, _, _, _, _, skillLine = pcall(GetProfessionInfo, slots[index])
                if infoOk then
                    RememberLine(lines, seen, skillLine)
                end
                index = index + 1
            end
        end
    end
    if C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines then
        local ok, listed = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
        if ok and type(listed) == "table" then
            local values = IndexValues(listed)
            if not values[1] then
                pcall(function()
                    for key, value in pairs(listed) do
                        local id = AsNumber(value) or AsNumber(key)
                        if id and LineKnown(id) then
                            RememberLine(lines, seen, id)
                        end
                    end
                end)
            else
                local index = 1
                while values[index] do
                    local id = AsNumber(values[index])
                    if id and LineKnown(id) then
                        RememberLine(lines, seen, id)
                    end
                    index = index + 1
                end
            end
        end
    end
    local index = 1
    local count = #lines
    while index <= count do
        local skillLine = lines[index]
        if C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID and C_TradeSkillUI.GetProfessionChildSkillLineID then
            local infoOk, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
            if infoOk and type(info) == "table" and info.profession ~= nil then
                local childOk, child = pcall(C_TradeSkillUI.GetProfessionChildSkillLineID, info.profession)
                if childOk then
                    RememberLine(lines, seen, child)
                end
            end
        end
        index = index + 1
        count = #lines
    end
    return lines
end

local function AddProfessionRow(rows, seen, currencyId)
    local id = AsNumber(currencyId)
    if not id or id <= 0 or seen[id] then
        return
    end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
    if not ok or type(info) ~= "table" then
        return
    end
    local row = CurrencyRow(info, "Professions")
    if not row or not row.name or row.name == "" then
        return
    end
    row.id = row.id or id
    row.expansion = "Professions"
    row.unused = nil
    seen[id] = true
    rows[#rows + 1] = row
end

local function SpendCurrencies(skillLine, rows, seen)
    if not C_ProfSpecs or not C_ProfSpecs.GetSpecTabIDsForSkillLine or not C_ProfSpecs.GetRootPathForTab or not C_ProfSpecs.GetSpendCurrencyForPath then
        return
    end
    local ok, tabs = pcall(C_ProfSpecs.GetSpecTabIDsForSkillLine, skillLine)
    if not ok or type(tabs) ~= "table" then
        return
    end
    local tabIds = IndexValues(tabs)
    local index = 1
    while tabIds[index] do
        local tabId = AsNumber(tabIds[index])
        if tabId then
            local rootOk, root = pcall(C_ProfSpecs.GetRootPathForTab, tabId)
            local rootId = rootOk and AsNumber(root) or nil
            if rootId then
                local curOk, currencyId = pcall(C_ProfSpecs.GetSpendCurrencyForPath, rootId)
                if curOk then
                    AddProfessionRow(rows, seen, currencyId)
                end
            end
        end
        index = index + 1
    end
end

local function CollectProfessionCurrencies()
    local rows = {}
    local seen = {}
    local lines = ProfessionSkillLines()
    local index = 1
    while lines[index] do
        local skillLine = lines[index]
        if C_TradeSkillUI and C_TradeSkillUI.GetConcentrationCurrencyID then
            local ok, currencyId = pcall(C_TradeSkillUI.GetConcentrationCurrencyID, skillLine)
            if ok then
                AddProfessionRow(rows, seen, currencyId)
            end
        end
        if C_TradeSkillUI then
            local names = { "GetProfessionCurrencyID", "GetArtisanCurrencyID", "GetKnowledgeCurrencyID" }
            local nameIndex = 1
            while names[nameIndex] do
                local func = C_TradeSkillUI[names[nameIndex]]
                if type(func) == "function" then
                    local ok, currencyId = pcall(func, skillLine)
                    if ok then
                        AddProfessionRow(rows, seen, currencyId)
                    end
                end
                nameIndex = nameIndex + 1
            end
        end
        SpendCurrencies(skillLine, rows, seen)
        index = index + 1
    end
    if not rows[1] then
        return nil
    end
    return { currencies = rows, sections = { { name = "Professions", depth = 0, rows = rows } } }
end

local function MoveSection(sections, name, afterName, beforeName)
    if type(sections) ~= "table" then
        return
    end
    local from = nil
    local index = 1
    while sections[index] do
        if sections[index].name == name then
            from = index
        end
        index = index + 1
    end
    if not from then
        return
    end
    local section = sections[from]
    local last = index - 1
    local shift = from
    while shift < last do
        sections[shift] = sections[shift + 1]
        shift = shift + 1
    end
    sections[last] = nil
    local afterIndex = nil
    local beforeIndex = nil
    index = 1
    while sections[index] do
        if sections[index].name == afterName and not afterIndex then
            afterIndex = index
        end
        if sections[index].name == beforeName and not beforeIndex then
            beforeIndex = index
        end
        index = index + 1
    end
    local at = index
    if afterIndex then
        at = afterIndex + 1
    elseif beforeIndex then
        at = beforeIndex
    end
    local spot = index
    while spot > at do
        sections[spot] = sections[spot - 1]
        spot = spot - 1
    end
    sections[at] = section
end

function Scan.ReadCurrencies()
    if currencyScan or currencyWait then
        return
    end
    if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then
        return
    end
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB.Get(guid) or nil
    if not record then
        return
    end
    currencyScan = true
    local opened = ExpandCurrencyHeaders()
    local categoryOk, categoryList = pcall(CollectCategoryCurrencies)
    local listOk, list = pcall(CollectCurrencies)
    local professionOk, professionList = pcall(CollectProfessionCurrencies)
    currencyScan = false
    local chosen = nil
    if categoryOk and PackCount(categoryList) > 0 then
        chosen = MergePacks(categoryList, listOk and list or nil)
    elseif listOk then
        chosen = list
    end
    if professionOk then
        chosen = MergePacks(chosen, professionList)
    end
    if type(chosen) == "table" and type(chosen.sections) == "table" then
        MoveSection(chosen.sections, "Professions", "Delves", "Season 2")
    end
    if chosen then
        SaveCurrencies(record, chosen)
    end
    if chosen and not PackHas(chosen, "Legacy") and currencyTries < 4 and C_Timer and C_Timer.After then
        currencyTries = currencyTries + 1
        categoryMap = nil
        currencyWait = true
        C_Timer.After(1.5, function()
            currencyWait = false
            Scan.ReadCurrencies()
            if BMGAM.Window and BMGAM.Window.Refresh then
                BMGAM.Window.Refresh()
            end
        end)
        return
    end
    if not chosen and currencyTries < 8 and C_Timer and C_Timer.After then
        currencyTries = currencyTries + 1
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
    currencyTries = 0
end

local reputationTries = 0
-- Helpers in this block leave scope when it ends. Lua allows 200 locals in one function.
do
local reputationWait = false
local reputationScan = false

local function StandingLabel(reaction)
    local index = AsNumber(reaction)
    if not index then
        return ""
    end
    local key = "FACTION_STANDING_LABEL" .. tostring(math.floor(index))
    local label = _G[key]
    local text = SafeText(label)
    if text then
        return text
    end
    return ""
end

local function FormatCount(pattern, level)
    if type(pattern) == "string" and string.find(pattern, "%%", 1, true) then
        local ok, text = pcall(string.format, pattern, level)
        local plain = ok and SafeText(text) or nil
        if plain then
            return plain
        end
    end
    return nil
end

local function IsSharedFaction(factionID, data)
    if type(data) == "table" and TrueFlag(data.isAccountWide) then
        return true
    end
    if not factionID or not C_Reputation or not C_Reputation.IsAccountWideReputation then
        return false
    end
    local ok, value = pcall(C_Reputation.IsAccountWideReputation, factionID)
    return ok and TrueFlag(value)
end

local function IsFriendshipFaction(factionID)
    if not factionID or not C_GossipInfo or not C_GossipInfo.GetFriendshipReputation then
        return false
    end
    local ok, info = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
    if not ok or type(info) ~= "table" then
        return false
    end
    local id = AsNumber(info.friendshipFactionID)
    return id ~= nil and id > 0
end

local function IsMajorFaction(factionID, majors)
    if factionID and majors[factionID] then
        return true
    end
    if not factionID or not C_Reputation or not C_Reputation.IsMajorFaction then
        return false
    end
    local ok, value = pcall(C_Reputation.IsMajorFaction, factionID)
    return ok and TrueFlag(value)
end

local function MajorFactionIDs()
    local set = {}
    local order = {}
    if not C_MajorFactions or not C_MajorFactions.GetMajorFactionIDs then
        return set, order
    end
    local ok, ids = pcall(C_MajorFactions.GetMajorFactionIDs)
    if not ok then
        return set, order
    end
    local listed = IndexValues(ids)
    local index = 1
    while listed[index] do
        local id = AsNumber(listed[index])
        if id and id > 0 and not set[id] then
            set[id] = true
            order[#order + 1] = id
        end
        index = index + 1
    end
    return set, order
end

local function RenownMaximum(factionID, data)
    local maxLevel = AsNumber(data.maxLevel)
    if maxLevel and maxLevel > 0 then
        return maxLevel
    end
    if C_MajorFactions and C_MajorFactions.GetRenownLevels then
        local ok, levels = pcall(C_MajorFactions.GetRenownLevels, factionID)
        if ok then
            local listed = IndexValues(levels)
            if listed[1] then
                return #listed
            end
        end
    end
    local level = AsNumber(data.renownLevel) or 0
    if level > 0 then
        return level
    end
    return 0
end

local function IsCompanionData(data, factionID, companionFaction)
    if factionID and companionFaction and factionID == companionFaction then
        return true
    end
    local name = type(data) == "table" and SafeText(data.name) or nil
    if not name then
        return false
    end
    local plain = string.lower(string.gsub(name, "’", "'"))
    return string.find(plain, "companion", 1, true) ~= nil
end

local function IsJourneyFaction(factionID)
    if not factionID or not C_MajorFactions or not C_MajorFactions.ShouldDisplayMajorFactionAsJourney then
        return false
    end
    local ok, value = pcall(C_MajorFactions.ShouldDisplayMajorFactionAsJourney, factionID)
    return ok and TrueFlag(value)
end

local function CompanionFactionID()
    if not C_DelvesUI or not C_DelvesUI.GetCompanionInfoForActivePlayer or not C_DelvesUI.GetFactionForCompanion then
        return nil
    end
    local idOk, companionID = pcall(C_DelvesUI.GetCompanionInfoForActivePlayer)
    local id = idOk and AsNumber(companionID) or nil
    if not id or id <= 0 then
        return nil
    end
    local factionOk, factionID = pcall(C_DelvesUI.GetFactionForCompanion, id)
    local faction = factionOk and AsNumber(factionID) or nil
    if faction and faction > 0 then
        return faction
    end
    return nil
end

local function ApplyRenownOrLevel(row, factionID, companionFaction)
    if not factionID or not C_MajorFactions or not C_MajorFactions.GetMajorFactionData then
        return false
    end
    local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
    if not ok or type(data) ~= "table" then
        return false
    end
    local level = AsNumber(data.renownLevel) or 0
    local journey = JourneyKey(row.name) or JourneyKey(SafeText(data.name))
    if journey then
        local earned = AsNumber(data.renownReputationEarned) or 0
        local threshold = AsNumber(data.renownLevelThreshold) or 0
        if earned > 100000 then
            earned = 0
        end
        row.kind = "renown"
        row.reaction = nil
        row.floor = 0
        row.standing = "Rank " .. tostring(level)
        if threshold > 0 then
            row.current = earned
            row.maximum = threshold
        else
            row.current = level
            row.maximum = RenownMaximum(factionID, data)
        end
        return true
    end
    local companion = IsCompanionData(data, factionID, companionFaction)
    if not companion and not IsMajorFaction(factionID, {}) then
        return false
    end
    row.current = level
    row.maximum = RenownMaximum(factionID, data)
    row.floor = 0
    if companion then
        row.kind = "companion"
        row.reaction = 5
        row.standing = FormatCount(UNIT_LEVEL_TEMPLATE, level) or ("Level " .. tostring(level))
    else
        row.kind = "renown"
        row.reaction = nil
        row.standing = FormatCount(RENOWN_LEVEL_LABEL, level) or ("Renown " .. tostring(level))
    end
    return true
end

local function ApplyFriendshipStanding(row, factionID)
    if not factionID or not C_GossipInfo or not C_GossipInfo.GetFriendshipReputation then
        return
    end
    local ok, info = pcall(C_GossipInfo.GetFriendshipReputation, factionID)
    if not ok or type(info) ~= "table" then
        return
    end
    local id = AsNumber(info.friendshipFactionID)
    if not id or id <= 0 then
        return
    end
    local label = SafeText(info.reaction)
    if label and not tonumber(label) then
        row.standing = label
    end
    if label and string.find(label, "Level", 1, true) then
        local level = tonumber(string.match(label, "%d+"))
        if level then
            row.kind = "companion"
            row.reaction = 5
            row.current = level
            row.floor = 0
            row.maximum = level
            row.standing = label
            return
        end
    end
    local current = AsNumber(info.standing)
    if current and current > 100000 then
        current = nil
    end
    local floor = AsNumber(info.reactionThreshold)
    local maximum = AsNumber(info.nextThreshold)
    local cap = AsNumber(info.maxRep)
    if current then
        row.current = current
    end
    if floor then
        row.floor = floor
    end
    if maximum and current and maximum > current then
        row.maximum = maximum
    elseif cap and cap > 0 then
        row.maximum = cap
    end
end

local WARBAND_RANK = {
    [2644] = 3022,
    [2683] = 3130,
    [2722] = 3271,
    [2742] = 3317,
    [2764] = 3386,
    [2796] = 3464,
    [2808] = 3514,
    [2839] = 3545,
}

local function ApplyWarbandTrack(row)
    local currencyID = row and row.id and WARBAND_RANK[row.id] or nil
    if not currencyID or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo then
        return
    end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyID)
    if not ok or type(info) ~= "table" then
        row.shared = true
        return
    end
    local quantity = AsNumber(info.quantity)
    local cap = AsNumber(info.maxQuantity)
    if not cap or cap <= 0 or cap > 20 then
        cap = 10
    end
    row.shared = true
    if quantity == nil then
        quantity = 0
    end
    if quantity > cap then
        quantity = cap
    end
    local shownRank = tonumber(string.match(row.standing or "", "%d+")) or 0
    local neutralBar = (tonumber(row.maximum) or 0) >= 3000 and shownRank == 0
    if quantity < shownRank and not neutralBar then
        return
    end
    local earned = nil
    local threshold = nil
    local level = quantity
    if C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo then
        local infoOk, renown = pcall(C_MajorFactions.GetMajorFactionRenownInfo, row.id)
        if infoOk and type(renown) == "table" then
            local renownLevel = AsNumber(renown.renownLevel)
            if renownLevel and renownLevel > level then
                level = renownLevel
            end
            earned = AsNumber(renown.renownReputationEarned)
            threshold = AsNumber(renown.renownLevelThreshold)
        end
    end
    if level > cap then
        level = cap
    end
    row.kind = "renown"
    row.reaction = nil
    row.floor = 0
    row.standing = "Rank " .. tostring(level)
    if threshold and threshold > 0 and earned and earned >= 0 and earned <= threshold + 1 then
        row.current = earned
        row.maximum = threshold
    else
        row.current = level
        row.maximum = cap
    end
end

local function StandardReputationRow(data, group, companionFaction)
    local id = AsNumber(data.factionID)
    local name = SafeText(data.name)
    if not name or name == "" then
        return nil
    end
    local current = AsNumber(data.currentStanding) or 0
    if current > 100000 then
        current = 0
    end
    local floor = AsNumber(data.currentReactionThreshold)
    local maximum = AsNumber(data.nextReactionThreshold) or 0
    if maximum <= current then
        maximum = current
    end
    local reaction = AsNumber(data.reaction)
    local row = {
        id = id,
        name = name,
        group = group,
        kind = "standard",
        standing = StandingLabel(reaction),
        current = current,
        maximum = maximum,
        reaction = reaction,
    }
    if floor then
        row.floor = floor
    end
    if IsSharedFaction(id, data) then
        row.shared = true
    end
    if not ApplyRenownOrLevel(row, id, companionFaction) then
        ApplyFriendshipStanding(row, id)
    end
    ApplyWarbandTrack(row)
    return row
end

local function AddReputationRow(section, row)
    if not section or not row then
        return
    end
    section.rows[#section.rows + 1] = row
end

local function NewReputationSection(sections, name, depth)
    local section = { name = name or "", depth = depth or 0, rows = {} }
    sections[#sections + 1] = section
    return section
end

local function CollapsedReputationHeaders()
    local collapsed = {}
    if not C_Reputation or not C_Reputation.GetNumFactions or not C_Reputation.GetFactionDataByIndex then
        return collapsed
    end
    local count = AsNumber(C_Reputation.GetNumFactions()) or 0
    local index = 1
    while index <= count and index <= 2500 do
        local ok, data = pcall(C_Reputation.GetFactionDataByIndex, index)
        if ok and type(data) == "table" and TrueFlag(data.isHeader) and TrueFlag(data.isCollapsed) then
            local id = AsNumber(data.factionID)
            if id and id > 0 then
                collapsed[#collapsed + 1] = id
            end
        end
        index = index + 1
    end
    return collapsed
end

local legacyCaptured = false
local legacyWasShown = true
local legacyRetried = false

local function LegacyShown()
    if not C_Reputation or not C_Reputation.AreLegacyReputationsShown then
        return nil
    end
    local ok, value = pcall(C_Reputation.AreLegacyReputationsShown)
    if not ok then
        return nil
    end
    if value == true or value == 1 then
        return true
    end
    if value == false or value == 0 then
        return false
    end
    return nil
end

local function ShowLegacyReputations()
    if not C_Reputation or not C_Reputation.SetLegacyReputationsShown then
        return
    end
    if not legacyCaptured then
        legacyCaptured = true
        legacyWasShown = LegacyShown()
    end
    if legacyWasShown ~= true then
        pcall(C_Reputation.SetLegacyReputationsShown, true)
    end
end

local function RestoreLegacyReputations()
    if legacyCaptured and legacyWasShown == false and C_Reputation and C_Reputation.SetLegacyReputationsShown then
        pcall(C_Reputation.SetLegacyReputationsShown, false)
    end
    legacyCaptured = false
    legacyWasShown = true
    legacyRetried = false
end

local function ExpandReputationHeaders()
    if not C_Reputation or not C_Reputation.GetNumFactions then
        return
    end
    local pass = 1
    while pass <= 8 do
        local before = AsNumber(C_Reputation.GetNumFactions()) or 0
        if ExpandAllFactionHeaders then
            pcall(ExpandAllFactionHeaders)
        end
        if C_Reputation.ExpandAllFactionHeaders then
            pcall(C_Reputation.ExpandAllFactionHeaders)
        end
        if C_Reputation.GetFactionDataByIndex and C_Reputation.ExpandFactionHeader then
            local count = AsNumber(C_Reputation.GetNumFactions()) or 0
            local index = 1
            while index <= count and index <= 2500 do
                local ok, data = pcall(C_Reputation.GetFactionDataByIndex, index)
                local factionID = ok and type(data) == "table" and AsNumber(data.factionID) or nil
                if ok and type(data) == "table" and (TrueFlag(data.isHeader) or factionID == 0) then
                    local sizeBefore = AsNumber(C_Reputation.GetNumFactions()) or count
                    pcall(C_Reputation.ExpandFactionHeader, index)
                    local sizeAfter = AsNumber(C_Reputation.GetNumFactions()) or sizeBefore
                    if sizeAfter < sizeBefore then
                        pcall(C_Reputation.ExpandFactionHeader, index)
                    end
                end
                index = index + 1
            end
        end
        local after = AsNumber(C_Reputation.GetNumFactions()) or 0
        if after <= before then
            return
        end
        pass = pass + 1
    end
end

local function RestoreReputationHeaders(collapsed)
    if not collapsed or not collapsed[1] or not C_Reputation or not C_Reputation.CollapseFactionHeader or not C_Reputation.GetNumFactions or not C_Reputation.GetFactionDataByIndex then
        return
    end
    local want = {}
    local wantIndex = 1
    while collapsed[wantIndex] do
        want[collapsed[wantIndex]] = true
        wantIndex = wantIndex + 1
    end
    local count = AsNumber(C_Reputation.GetNumFactions()) or 0
    local index = count
    while index >= 1 do
        local ok, data = pcall(C_Reputation.GetFactionDataByIndex, index)
        if ok and type(data) == "table" and TrueFlag(data.isHeader) and not TrueFlag(data.isCollapsed) then
            local id = AsNumber(data.factionID)
            if id and want[id] then
                pcall(C_Reputation.CollapseFactionHeader, index)
            end
        end
        index = index - 1
    end
end

local function SectionKeepsParent(sections, index)
    local section = sections[index]
    if section.headerRow or (section.rows and section.rows[1]) then
        return true
    end
    local depth = section.depth or 0
    local nextIndex = index + 1
    while sections[nextIndex] do
        local nextDepth = sections[nextIndex].depth or 0
        if nextDepth <= depth then
            return false
        end
        if sections[nextIndex].headerRow or (sections[nextIndex].rows and sections[nextIndex].rows[1]) then
            return true
        end
        nextIndex = nextIndex + 1
    end
    return false
end

local function DropEmptySections(sections)
    local kept = {}
    local index = 1
    while sections[index] do
        if SectionKeepsParent(sections, index) then
            kept[#kept + 1] = sections[index]
        end
        index = index + 1
    end
    return kept
end

local COMPANION_HEADER = "Delver's Companion"

local function EarnableName(name)
    if not name or name == "" then
        return false
    end
    if string.find(name, "DNT", 1, true) or string.find(name, "UNUSED", 1, true) then
        return false
    end
    if string.sub(name, 1, 1) == "[" then
        return false
    end
    local plain = string.lower(name)
    if string.find(plain, "deprecated", 1, true) or string.find(name, "(Paragon)", 1, true) then
        return false
    end
    return true
end

local function FindSection(sections, name)
    if not name or name == "" then
        return nil
    end
    local want = string.lower(name)
    local index = 1
    while sections[index] do
        local sectionName = string.lower(sections[index].name or "")
        if sectionName == want then
            return sections[index]
        end
        index = index + 1
    end
    return nil
end

local function EnsurePlacedSection(sections, name, parentName)
    local found = FindSection(sections, name)
    if found then
        return found
    end
    local parent = FindSection(sections, parentName)
    local depth = 0
    if parent then
        depth = (parent.depth or 0) + 1
    end
    local section = { name = name, depth = depth, rows = {} }
    if not parent then
        sections[#sections + 1] = section
        return section
    end
    local parentIndex = 1
    while sections[parentIndex] and sections[parentIndex] ~= parent do
        parentIndex = parentIndex + 1
    end
    local insertAt = parentIndex + 1
    while sections[insertAt] and (sections[insertAt].depth or 0) > (parent.depth or 0) do
        insertAt = insertAt + 1
    end
    local shift = #sections
    while shift >= insertAt do
        sections[shift + 1] = sections[shift]
        shift = shift - 1
    end
    sections[insertAt] = section
    return section
end

local function EnsureSection(sections, name)
    if name and name ~= "" then
        local found = FindSection(sections, name)
        if found then
            return found
        end
        return NewReputationSection(sections, name, 0)
    end
    local index = 1
    local count = 0
    while sections[index] do
        count = index
        index = index + 1
    end
    if count > 0 and (sections[count].name or "") == "" then
        return sections[count]
    end
    return NewReputationSection(sections, "", 0)
end

local function ExpansionTitle(expansionID)
    local id = AsNumber(expansionID)
    if id == nil then
        return nil
    end
    local key = "EXPANSION_NAME" .. tostring(math.floor(id))
    return SafeText(_G[key])
end

local function SeenFactions(sections)
    local seen = {}
    local index = 1
    while sections[index] do
        local header = sections[index].headerRow
        if header and header.id then
            seen[header.id] = true
        end
        local rows = sections[index].rows
        local rowIndex = 1
        while rows and rows[rowIndex] do
            if rows[rowIndex].id then
                seen[rows[rowIndex].id] = true
            end
            rowIndex = rowIndex + 1
        end
        index = index + 1
    end
    return seen
end

local function PullFaction(sections, factionID)
    local found = nil
    local index = 1
    while sections[index] do
        local section = sections[index]
        if section.headerRow and section.headerRow.id == factionID then
            if not found then
                found = section.headerRow
            end
            section.headerRow = nil
        end
        local rows = section.rows
        local kept = {}
        local rowIndex = 1
        while rows and rows[rowIndex] do
            if rows[rowIndex].id == factionID then
                if not found then
                    found = rows[rowIndex]
                end
            else
                kept[#kept + 1] = rows[rowIndex]
            end
            rowIndex = rowIndex + 1
        end
        section.rows = kept
        index = index + 1
    end
    return found
end

local function ParentSectionName(data)
    if type(data) ~= "table" then
        return nil
    end
    local parentID = AsNumber(data.parentFactionID) or AsNumber(data.parentFactionId) or AsNumber(data.parentID)
    if not parentID or parentID <= 0 or not C_Reputation or not C_Reputation.GetFactionDataByID then
        return nil
    end
    local ok, parent = pcall(C_Reputation.GetFactionDataByID, parentID)
    if not ok or type(parent) ~= "table" then
        return nil
    end
    return SafeText(parent.name)
end

local function AddMissingMajorFactions(sections, seen, companionFaction)
    local _, order = MajorFactionIDs()
    local index = 1
    while order[index] do
        local factionID = order[index]
        if not seen[factionID] and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
            local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
            if ok and type(data) == "table" and not IsCompanionData(data, factionID, companionFaction) then
                local name = SafeText(data.name)
                if EarnableName(name) then
                    local headerName = ExpansionTitle(data.expansionID) or ""
                    local section = EnsureSection(sections, headerName)
                    local level = AsNumber(data.renownLevel) or 0
                    local row = {
                        id = factionID,
                        name = name,
                        group = section.name,
                        kind = "renown",
                        standing = FormatCount(RENOWN_LEVEL_LABEL, level) or ("Renown " .. tostring(level)),
                        current = level,
                        maximum = RenownMaximum(factionID, data),
                        floor = 0,
                    }
                    if IsSharedFaction(factionID, nil) then
                        row.shared = true
                    end
                    AddReputationRow(section, row)
                    seen[factionID] = true
                end
            end
        end
        index = index + 1
    end
end

local function CatalogById()
    local byId = {}
    local headerIds = {}
    if type(BMGAM_FactionCatalog) ~= "table" then
        return byId, headerIds
    end
    local index = 1
    while BMGAM_FactionCatalog[index] do
        local entry = BMGAM_FactionCatalog[index]
        local factionID = entry[1]
        local parentID = entry[3]
        byId[factionID] = entry
        if parentID and parentID > 0 then
            headerIds[parentID] = true
        end
        index = index + 1
    end
    return byId, headerIds
end

local function ZeroReputationRow(factionID, name, group)
    local row = {
        id = factionID,
        name = name,
        group = group,
        kind = "standard",
        standing = StandingLabel(4),
        current = 0,
        maximum = 3000,
        floor = 0,
        reaction = 4,
    }
    if IsSharedFaction(factionID, nil) then
        row.shared = true
    end
    if not ApplyRenownOrLevel(row, factionID, nil) then
        ApplyFriendshipStanding(row, factionID)
    end
    ApplyWarbandTrack(row)
    return row
end

local function FactionDataByID(factionID)
    if not factionID or not C_Reputation or not C_Reputation.GetFactionDataByID then
        return nil
    end
    local ok, result = pcall(C_Reputation.GetFactionDataByID, factionID)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

local function SectionForParent(sections, byId, parentID, parentName)
    local found = FindSection(sections, parentName)
    if found then
        return found
    end
    local grandName = nil
    local header = byId[parentID]
    if header and header[4] and header[4] ~= "" then
        grandName = header[4]
    end
    return EnsurePlacedSection(sections, parentName, grandName)
end

local function AddUnlistedFactions(sections, seen)
    if type(BMGAM_FactionCatalog) ~= "table" then
        return
    end
    local byId, headerIds = CatalogById()
    local index = 1
    while BMGAM_FactionCatalog[index] do
        local entry = BMGAM_FactionCatalog[index]
        local factionID = entry[1]
        local catalogName = entry[2]
        local parentID = entry[3]
        local parentName = entry[4]
        if factionID and not seen[factionID] and EarnableName(catalogName) and EarnableName(parentName) then
            local data = FactionDataByID(factionID)
            if headerIds[factionID] then
                local section = EnsurePlacedSection(sections, catalogName, parentName)
                seen[factionID] = true
                if section and not section.headerRow and data and TrueFlag(data.isHeaderWithRep) then
                    section.headerRow = StandardReputationRow(data, catalogName, nil)
                end
            else
                local section = SectionForParent(sections, byId, parentID, parentName)
                local row = nil
                if data and not TrueFlag(data.isHeader) then
                    row = StandardReputationRow(data, section.name, nil)
                end
                if not row then
                    row = ZeroReputationRow(factionID, catalogName, section.name)
                end
                if row then
                    AddReputationRow(section, row)
                    seen[factionID] = true
                end
            end
        end
        index = index + 1
    end
end

local function CompanionIDs(companionFaction)
    local ids = {}
    local seen = {}
    if companionFaction and companionFaction > 0 then
        ids[#ids + 1] = companionFaction
        seen[companionFaction] = true
    end
    local _, order = MajorFactionIDs()
    local index = 1
    while order[index] do
        local factionID = order[index]
        if not seen[factionID] and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
            local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
            if ok and type(data) == "table" and IsCompanionData(data, factionID, companionFaction) then
                ids[#ids + 1] = factionID
                seen[factionID] = true
            end
        end
        index = index + 1
    end
    if C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason then
        local ok, seasonID = pcall(C_DelvesUI.GetDelvesFactionForSeason)
        local factionID = ok and AsNumber(seasonID) or nil
        if factionID and factionID > 0 and not seen[factionID] then
            local name = nil
            if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
                local dataOk, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
                name = dataOk and type(data) == "table" and SafeText(data.name) or nil
            end
            if not name and C_Reputation and C_Reputation.GetFactionDataByID then
                local dataOk, data = pcall(C_Reputation.GetFactionDataByID, factionID)
                name = dataOk and type(data) == "table" and SafeText(data.name) or nil
            end
            local plain = name and string.lower(string.gsub(name, "’", "'")) or ""
            if string.find(plain, "companion", 1, true) then
                ids[#ids + 1] = factionID
                seen[factionID] = true
            end
        end
    end
    return ids
end

local function CompanionStanding(level)
    return FormatCount(UNIT_LEVEL_TEMPLATE, level) or ("Level " .. tostring(level))
end

local function AddDelverCompanion(sections, companionFaction)
    local ids = CompanionIDs(companionFaction)
    local rows = {}
    local index = 1
    while ids[index] do
        local factionID = ids[index]
        local row = PullFaction(sections, factionID)
        if not row then
            if C_Reputation and C_Reputation.GetFactionDataByID then
                local ok, data = pcall(C_Reputation.GetFactionDataByID, factionID)
                if ok and type(data) == "table" then
                    row = StandardReputationRow(data, COMPANION_HEADER, factionID)
                end
            end
            if not row and C_MajorFactions and C_MajorFactions.GetMajorFactionData then
                local ok, data = pcall(C_MajorFactions.GetMajorFactionData, factionID)
                local name = ok and type(data) == "table" and SafeText(data.name) or nil
                if EarnableName(name) then
                    local level = AsNumber(data.renownLevel) or 0
                    row = {
                        id = factionID,
                        name = name,
                        current = level,
                        maximum = RenownMaximum(factionID, data),
                        floor = 0,
                    }
                end
            end
        end
        if row and EarnableName(row.name) then
            row.group = COMPANION_HEADER
            row.kind = "companion"
            row.reaction = 5
            local existing = row.standing or ""
            if not string.find(existing, "Level", 1, true) then
                local level = tonumber(row.current) or 0
                if level > 200 then
                    level = 0
                end
                row.current = level
                row.floor = 0
                row.standing = CompanionStanding(level)
            end
            if IsSharedFaction(factionID, nil) then
                row.shared = true
            end
            rows[#rows + 1] = row
        end
        index = index + 1
    end
    return rows
end

local function AppendNamedSection(sections, name, rows)
    if not rows or not rows[1] then
        return
    end
    local section = { name = name, depth = 0, rows = rows }
    local index = 1
    while rows[index] do
        rows[index].group = name
        index = index + 1
    end
    sections[#sections + 1] = section
end

local function RehomeByExpansion(sections)
    if type(BMGAM_FactionCatalog) ~= "table" then
        return
    end
    local byId = {}
    local index = 1
    while BMGAM_FactionCatalog[index] do
        local entry = BMGAM_FactionCatalog[index]
        byId[entry[1]] = entry
        index = index + 1
    end
    local moves = {}
    local sectionIndex = 1
    while sections[sectionIndex] do
        local section = sections[sectionIndex]
        local rows = section.rows
        local kept = {}
        local rowIndex = 1
        while rows and rows[rowIndex] do
            local row = rows[rowIndex]
            local entry = row and row.id and byId[row.id] or nil
            local parentName = entry and entry[4] or nil
            local shouldMove = false
            if parentName and parentName ~= "" and parentName ~= (section.name or "") then
                if JourneyKey(row.name) or string.find(row.name or "", "Delves:", 1, true) then
                    shouldMove = true
                end
            end
            if shouldMove then
                moves[#moves + 1] = { row = row, parentName = parentName }
            else
                kept[#kept + 1] = row
            end
            rowIndex = rowIndex + 1
        end
        section.rows = kept
        sectionIndex = sectionIndex + 1
    end
    local moveIndex = 1
    while moves[moveIndex] do
        local move = moves[moveIndex]
        local dest = EnsurePlacedSection(sections, move.parentName, nil)
        move.row.group = dest.name
        AddReputationRow(dest, move.row)
        moveIndex = moveIndex + 1
    end
end

local SILVERMOON_FRIENDS = {
    { 2773, "Captain Tokka" },
    { 2770, "Slayer's Duellum" },
    { 2744, "Valeera Sanguinar" },
}

local function EnsureSilvermoonFriends(sections)
    EnsurePlacedSection(sections, "Midnight", nil)
    local court = EnsurePlacedSection(sections, "Silvermoon Court", "Midnight")
    if not court then
        return
    end
    local index = 1
    while SILVERMOON_FRIENDS[index] do
        local factionID = SILVERMOON_FRIENDS[index][1]
        local fallbackName = SILVERMOON_FRIENDS[index][2]
        local row = PullFaction(sections, factionID)
        if not row then
            local data = FactionDataByID(factionID)
            if data and not TrueFlag(data.isHeader) then
                row = StandardReputationRow(data, court.name, nil)
            end
            if not row then
                row = ZeroReputationRow(factionID, fallbackName, court.name)
            end
        end
        if row then
            if not row.name or row.name == "" then
                row.name = fallbackName
            end
            row.group = court.name
            AddReputationRow(court, row)
        end
        index = index + 1
    end
end

local function CollectReputations()
    if not C_Reputation or not C_Reputation.GetNumFactions or not C_Reputation.GetFactionDataByIndex then
        return nil
    end
    ShowLegacyReputations()
    local collapsed = CollapsedReputationHeaders()
    ExpandReputationHeaders()
    local companionFaction = CompanionFactionID()
    local sections = {}
    local current = nil
    local count = AsNumber(C_Reputation.GetNumFactions()) or 0
    local index = 1
    while index <= count and index <= 2500 do
        local ok, data = pcall(C_Reputation.GetFactionDataByIndex, index)
        if ok and type(data) == "table" then
            local name = SafeText(data.name) or ""
            local factionID = AsNumber(data.factionID)
            if TrueFlag(data.isHeader) then
                local depth = 0
                if TrueFlag(data.isChild) then
                    depth = 1
                end
                current = NewReputationSection(sections, name, depth)
                if TrueFlag(data.isHeaderWithRep) then
                    current.headerRow = StandardReputationRow(data, name, companionFaction)
                end
            else
                if not current then
                    current = NewReputationSection(sections, "", 0)
                end
                AddReputationRow(current, StandardReputationRow(data, current.name, companionFaction))
            end
        end
        index = index + 1
    end
    local seen = SeenFactions(sections)
    AddMissingMajorFactions(sections, seen, companionFaction)
    AddUnlistedFactions(sections, seen)
    AppendNamedSection(sections, COMPANION_HEADER, AddDelverCompanion(sections, companionFaction))
    RehomeByExpansion(sections)
    EnsureSilvermoonFriends(sections)
    sections = DropEmptySections(sections)
    RestoreReputationHeaders(collapsed)
    local total = 0
    local check = 1
    while sections[check] do
        if sections[check].headerRow then
            total = total + 1
        end
        local rowIndex = 1
        while sections[check].rows[rowIndex] do
            total = total + 1
            rowIndex = rowIndex + 1
        end
        check = check + 1
    end
    if total < 1 then
        return nil
    end
    return sections
end

local function ReputationCount(sections)
    local total = 0
    if type(sections) ~= "table" then
        return 0
    end
    local index = 1
    while sections[index] do
        if sections[index].headerRow then
            total = total + 1
        end
        local rows = sections[index].rows
        local rowIndex = 1
        while type(rows) == "table" and rows[rowIndex] do
            total = total + 1
            rowIndex = rowIndex + 1
        end
        index = index + 1
    end
    return total
end

local function SaveReputations(record, sections)
    if ReputationCount(sections) < 1 then
        return
    end
    record.reputationSections = sections
    local flat = {}
    local index = 1
    while sections[index] do
        if sections[index].headerRow then
            flat[#flat + 1] = sections[index].headerRow
        end
        local rows = sections[index].rows
        local rowIndex = 1
        while type(rows) == "table" and rows[rowIndex] do
            flat[#flat + 1] = rows[rowIndex]
            rowIndex = rowIndex + 1
        end
        index = index + 1
    end
    record.reputations = flat
end

function Scan.ReadReputations()
    if reputationScan or reputationWait then
        return
    end
    if not C_Reputation or not C_Reputation.GetFactionDataByIndex then
        return
    end
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB.Get(guid) or nil
    if not record then
        return
    end
    reputationScan = true
    local ok, sections = pcall(CollectReputations)
    reputationScan = false
    if ok and sections then
        SaveReputations(record, sections)
    end
    if legacyWasShown == false and not legacyRetried and reputationTries < 6 and C_Timer and C_Timer.After then
        legacyRetried = true
        reputationTries = reputationTries + 1
        reputationWait = true
        C_Timer.After(0.5, function()
            reputationWait = false
            Scan.ReadReputations()
            if BMGAM.Window and BMGAM.Window.Refresh then
                BMGAM.Window.Refresh()
            end
        end)
        return
    end
    if (not ok or not sections) and reputationTries < 6 and C_Timer and C_Timer.After then
        reputationTries = reputationTries + 1
        reputationWait = true
        C_Timer.After(1, function()
            reputationWait = false
            Scan.ReadReputations()
            if BMGAM.Window and BMGAM.Window.Refresh then
                BMGAM.Window.Refresh()
            end
        end)
        return
    end
    RestoreLegacyReputations()
    reputationTries = 0
    reputationWait = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0.6, function()
            reputationWait = false
        end)
    else
        reputationWait = false
    end
end
end

-- Mail helpers leave scope here for the same 200-local limit.
do
local mailboxOpen = false
local inboxUpdated = false
local pendingSend = nil

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
        if GetSendMailItem then
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
        if GetSendMailItemLink then
            local ok, value = pcall(GetSendMailItemLink, slot)
            if ok then
                link = SafeText(value)
            end
        end
        if itemID and itemID > 0 then
            if not name then
                name = ItemName(itemID, link)
            end
            if not count or count < 1 then
                count = 1
            end
            items[#items + 1] = {
                itemID = itemID,
                link = link,
                name = name,
                quality = AttachmentQuality(itemID, quality),
                icon = texture or ItemIcon(itemID, nil),
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
    if GetRealmName then
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
    if GetSendMailCOD then
        local ok, cod = pcall(GetSendMailCOD)
        if ok and (AsNumber(cod) or 0) > 0 then
            pendingSend = nil
            return
        end
    end
    local money = 0
    if GetSendMailMoney then
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
    if GetInboxItem then
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
    if GetInboxItemLink then
        local ok, value = pcall(GetInboxItemLink, index, slot)
        if ok then
            link = SafeText(value)
        end
    end
    if not itemID or itemID < 1 then
        return nil
    end
    if not name then
        name = ItemName(itemID, link)
    end
    if not count or count < 1 then
        count = 1
    end
    return {
        itemID = itemID,
        link = link,
        name = name,
        quality = AttachmentQuality(itemID, quality),
        icon = texture or ItemIcon(itemID, nil),
        count = count,
    }
end

local function ReadInboxLetter(index)
    if not GetInboxHeaderInfo then
        return nil
    end
    local ok, _, _, sender, subject, money, codAmount, daysLeft, _, wasRead = pcall(GetInboxHeaderInfo, index)
    if not ok then
        return nil
    end
    if (AsNumber(codAmount) or 0) > 0 then
        return nil
    end
    sender = SafeText(sender)
    subject = SafeText(subject) or ""
    if not sender and subject == "" then
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
        sender = sender or "",
        subject = subject,
        money = AsNumber(money) or 0,
        daysLeft = AsNumber(daysLeft),
        markedAt = time(),
        read = TrueFlag(wasRead),
        items = items,
    }
end

local function ReadInboxLetters()
    if not GetInboxNumItems or not GetInboxHeaderInfo then
        return nil
    end
    local ok, numItems, totalItems = pcall(GetInboxNumItems)
    if not ok then
        return nil
    end
    numItems = AsNumber(numItems) or 0
    totalItems = AsNumber(totalItems) or numItems
    if totalItems > numItems and CheckInbox and C_Mail and C_Mail.CanCheckInbox then
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
    if GetLatestThreeSenders then
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
    local record = guid and BMGAM.DB.Get(guid) or nil
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
    if CheckInbox and C_Mail and C_Mail.CanCheckInbox then
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

function Scan.Capture(create, fresh, lists)
    if fresh then
        talentTries = 0
        gearTries = 0
        bagTries = 0
        currencyTries = 0
        reputationTries = 0
    end
    local guid = UnitGUID("player")
    local name = UnitName("player")
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
    local localizedClass, classFile = UnitClass("player")
    local localizedRace, raceFile = UnitRace("player")
    local side = UnitFactionGroup("player")
    record.guid = guid
    record.realm = GetRealmName()
    record.name = name
    record.classFile = classFile
    record.className = localizedClass
    record.raceFile = raceFile
    record.raceName = localizedRace
    record.sex = UnitSex("player")
    record.level = UnitLevel("player")
    record.side = side
    record.moneyCopper = GetMoney() or 0
    record.itemLevel = ItemLevel()
    record.itemLevelQuality = ItemLevelQuality()
    record.scannedAt = time()
    local guildName = GetGuildInfo("player")
    record.guildName = guildName or ""
    local specName = nil
    if GetSpecialization and GetSpecializationInfo then
        local specIndex = GetSpecialization()
        if specIndex then
            local _, name = GetSpecializationInfo(specIndex)
            specName = name
        end
    end
    record.specName = specName
    local function UnitNumber(first, second)
        local function AsNumber(value)
            local ok, number = pcall(tonumber, value)
            if ok and type(number) == "number" then
                return number
            end
            return 0
        end
        local effective = AsNumber(second)
        if effective > 0 then
            return effective
        end
        return AsNumber(first)
    end
    local strength, stamina, armor = 0, 0, 0
    if UnitStat then
        strength = UnitNumber(UnitStat("player", 1))
        stamina = UnitNumber(UnitStat("player", 3))
    end
    if UnitArmor then
        armor = UnitNumber(UnitArmor("player"))
    end
    record.stats = {
        strength = Round(strength),
        stamina = Round(stamina),
        armor = Round(armor),
        crit = Round(GetCritChance and GetCritChance() or 0),
        haste = Round(GetHaste and GetHaste() or 0),
        mastery = Round(GetMasteryEffect and GetMasteryEffect() or 0),
        versatility = Versatility(),
    }
    local talents, heroName = ReadTalents()
    if heroName then
        record.heroName = heroName
    end
    if talents and talents[1] then
        record.talents = talents
        talentTries = 8
    elseif talentTries < 8 and not talentWait and C_Timer and C_Timer.After then
        talentWait = true
        talentTries = talentTries + 1
        C_Timer.After(2, function()
            talentWait = false
            Scan.Capture(false)
        end)
    end
    local journeyOk, journeys = pcall(ReadJourneys)
    if journeyOk then
        record.journeys = journeys
    end
    if GetBindLocation then
        record.hearthstone = GetBindLocation()
    end
    local gear, gearReady = ReadGear()
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
    local bags, bagsReady = ReadBags()
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
    if lists then
        if Scan.ReadProfessionList then
            pcall(Scan.ReadProfessionList)
        end
        if Scan.ReadCurrencies then
            pcall(Scan.ReadCurrencies)
        end
        if Scan.ReadReputations then
            pcall(Scan.ReadReputations)
        end
        if Scan.ReadMailNotice then
            pcall(Scan.ReadMailNotice)
        end
        if Scan.ReadAuctions then
            pcall(Scan.ReadAuctions)
        end
        if Scan.ReadQuests then
            pcall(Scan.ReadQuests)
        end
        if Scan.ReadAchievements then
            pcall(Scan.ReadAchievements)
        end
        if Scan.ReadCollections then
            pcall(Scan.ReadCollections)
        end
        if BMGAM.Vault and BMGAM.Vault.Read then
            pcall(BMGAM.Vault.Read)
        end
    end
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

function Scan.OnBags()
    if bagWait or not C_Timer or not C_Timer.After then
        return
    end
    bagWait = true
    C_Timer.After(0.4, function()
        bagWait = false
        Scan.Capture(false)
        Scan.ReadOpenBank()
    end)
end

local professionWait = false
local professionTries = 0
local professionListWait = false
local professionListTries = 0

local function PlainIcon(value)
    local number = AsNumber(value)
    if number and number ~= 0 then
        return number
    end
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

local function NameClose(a, b)
    if type(a) ~= "string" or type(b) ~= "string" or a == "" or b == "" then
        return false
    end
    if a == b then
        return true
    end
    local left = string.lower(a)
    local right = string.lower(b)
    if string.find(left, right, 1, true) or string.find(right, left, 1, true) then
        return true
    end
    return false
end

local function LineHit(row, skillLine)
    if not skillLine or type(row) ~= "table" then
        return false
    end
    if row.skillLine == skillLine or row.altLine == skillLine then
        return true
    end
    return false
end

local function FindProfession(list, skillLine, altLine, name, altName)
    if type(list) ~= "table" then
        return nil
    end
    local index = 1
    while list[index] do
        local row = list[index]
        if LineHit(row, skillLine) or LineHit(row, altLine) then
            return row
        end
        if NameClose(row.name, name) or NameClose(row.name, altName) then
            return row
        end
        index = index + 1
    end
    return nil
end

local function UsableIndex(value)
    if value == nil then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(value) then
        if type(canaccessvalue) ~= "function" or not canaccessvalue(value) then
            return nil
        end
    end
    local number = AsNumber(value)
    if number and number > 0 then
        return number
    end
    return nil
end

local function RealName(value)
    local text = SafeText(value)
    if not text or text == "" or string.match(text, "^%d+$") then
        return nil
    end
    return text
end

local function ProfessionDisplayName(skillLine, rawName, parentName)
    local name = RealName(parentName)
    if not name then
        name = RealName(rawName)
    end
    if name then
        return name
    end
    if skillLine and C_TradeSkillUI and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        local ok, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, skillLine)
        if ok and type(info) == "table" then
            name = RealName(info.parentProfessionName) or RealName(info.professionName)
            if name then
                return name
            end
        end
    end
    if skillLine and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        local ok, text = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, skillLine)
        name = ok and RealName(text) or nil
        if name then
            return name
        end
    end
    return nil
end

local function ProfessionTexture(skillLine, icon)
    local plain = PlainIcon(icon)
    if plain then
        return plain
    end
    if skillLine and C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillTexture then
        local ok, texture = pcall(C_TradeSkillUI.GetTradeSkillTexture, skillLine)
        return ok and PlainIcon(texture) or nil
    end
    return nil
end

local EXPANSION_RANK = {
    ["Midnight"] = 1,
    ["Khaz Algar"] = 2,
    ["Dragon Isles"] = 3,
    ["Shadowlands"] = 4,
    ["Kul Tiran"] = 5,
    ["Zandalari"] = 5,
    ["Battle for Azeroth"] = 5,
    ["Legion"] = 6,
    ["Broken Isles"] = 6,
    ["Draenor"] = 7,
    ["Warlords of Draenor"] = 7,
    ["Pandaria"] = 8,
    ["Mists of Pandaria"] = 8,
    ["Cataclysm"] = 9,
    ["Northrend"] = 10,
    ["Wrath of the Lich King"] = 10,
    ["Outland"] = 11,
    ["The Burning Crusade"] = 11,
    ["Classic"] = 12,
}

local function ExpansionRank(label)
    if type(label) ~= "string" then
        return 50
    end
    if EXPANSION_RANK[label] then
        return EXPANSION_RANK[label]
    end
    for name, rank in pairs(EXPANSION_RANK) do
        if string.find(label, name, 1, true) == 1 then
            return rank
        end
    end
    return 50
end

local function ExpansionLabel(fullName, parentName)
    local full = RealName(fullName)
    local parent = RealName(parentName)
    if not full then
        return nil
    end
    if parent and full ~= parent then
        local stripped = string.match(full, "^(.-)%s+" .. parent .. "$")
        if stripped and stripped ~= "" then
            return stripped
        end
        return full
    end
    if string.find(full, "Classic", 1, true) == 1 then
        return "Classic"
    end
    if parent and full == parent then
        return nil
    end
    return full
end

local function ExpansionSame(have, expansion)
    if type(have) ~= "table" or type(expansion) ~= "table" then
        return false
    end
    if expansion.skillLine and have.skillLine and have.skillLine == expansion.skillLine then
        return true
    end
    if expansion.name and have.name and expansion.name == have.name then
        return true
    end
    return false
end

local function MergeExpansion(row, have, expansion)
    if expansion.name and expansion.name ~= "" then
        have.name = expansion.name
    end
    if expansion.skillLine and expansion.skillLine ~= have.skillLine then
        if not have.skillLine or have.skillLine == row.skillLine then
            have.skillLine = expansion.skillLine
        end
    end
    if expansion.skill then
        have.skill = expansion.skill
    end
    if expansion.maxSkill then
        have.maxSkill = expansion.maxSkill
    end
    if expansion.rank then
        have.rank = expansion.rank
    end
    if expansion.scanned and type(expansion.recipes) == "table" then
        have.scanned = true
        have.scannedAt = expansion.scannedAt
        have.recipes = expansion.recipes
    end
    return have
end

local function CopyOldRecipes(row, expansion)
    local oldList = row._oldExpansions
    local oldIndex = 1
    while type(oldList) == "table" and oldList[oldIndex] do
        local old = oldList[oldIndex]
        if old.scanned and ExpansionSame(old, expansion) then
            expansion.scanned = true
            expansion.scannedAt = old.scannedAt
            expansion.recipes = old.recipes
        end
        oldIndex = oldIndex + 1
    end
end

local function EnsureExpansion(row, expansion)
    if type(row) ~= "table" or type(expansion) ~= "table" then
        return nil
    end
    if not expansion.name or expansion.name == "" then
        return nil
    end
    if type(row.expansions) ~= "table" then
        row.expansions = {}
    end
    local index = 1
    while row.expansions[index] do
        local have = row.expansions[index]
        if ExpansionSame(have, expansion) then
            return MergeExpansion(row, have, expansion)
        end
        index = index + 1
    end
    CopyOldRecipes(row, expansion)
    row.expansions[#row.expansions + 1] = expansion
    return expansion
end

local function SortExpansions(row)
    local list = row and row.expansions
    if type(list) ~= "table" then
        return
    end
    local index = 1
    while list[index] do
        local nextIndex = index + 1
        while list[nextIndex] do
            local left = list[index].rank or 99
            local right = list[nextIndex].rank or 99
            if right < left then
                list[index], list[nextIndex] = list[nextIndex], list[index]
            end
            nextIndex = nextIndex + 1
        end
        index = index + 1
    end
end

local function RememberProfession(professions, old, row)
    local previous = FindProfession(old, row.skillLine, row.altLine, row.name, nil)
    if previous and previous.scanned then
        row.scanned = true
        row.scannedAt = previous.scannedAt
        row.recipes = previous.recipes
    end
    if previous and previous.expansions then
        row._oldExpansions = previous.expansions
    end
    if previous and previous.primary ~= nil and row.primary == nil then
        row.primary = previous.primary
    end
    if previous and previous.altLine and not row.altLine then
        row.altLine = previous.altLine
    end
    if previous and previous.icon and not row.icon then
        row.icon = previous.icon
    end
    local existing = FindProfession(professions, row.skillLine, row.altLine, row.name, nil)
    if existing then
        if existing.fromSlots then
            if row.altLine and not existing.altLine then
                existing.altLine = row.altLine
            end
        elseif row.altLine then
            existing.altLine = row.altLine
            if row.skill then
                existing.skill = row.skill
                existing.maxSkill = row.maxSkill
            end
        elseif row.skill and not existing.skill then
            existing.skill = row.skill
            existing.maxSkill = row.maxSkill
        end
        if row.icon and not existing.icon then
            existing.icon = row.icon
        end
        if row.scanned then
            existing.scanned = true
            existing.scannedAt = row.scannedAt
            existing.recipes = row.recipes
        end
        return existing
    end
    professions[#professions + 1] = row
    return row
end

local function ReadProfessionSlots(professions, old)
    if not GetProfessions or not GetProfessionInfo then
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
        local slot = UsableIndex(order[index])
        if slot then
            saw = true
            local infoOk, name, icon, skill, maxSkill, _, _, skillLine, _, _, _, expansionName = pcall(GetProfessionInfo, slot)
            if infoOk and type(name) == "table" then
                local info = name
                local infoLine = AsNumber(info.parentProfessionID) or AsNumber(info.professionID)
                expansionName = info.professionName
                name = info.parentProfessionName
                icon = info.professionIcon or info.icon
                skill = info.skillLevel
                maxSkill = info.maxSkillLevel
                skillLine = infoLine
            end
            skillLine = infoOk and AsNumber(skillLine) or nil
            expansionName = infoOk and RealName(expansionName) or nil
            local shown = nil
            if infoOk then
                shown = ProfessionDisplayName(skillLine, RealName(name), nil)
            end
            if shown and shown ~= "" then
                local childLine, childSkill, childMax = nil, nil, nil
                if expansionName and C_TradeSkillUI and C_TradeSkillUI.GetAllProfessionTradeSkillLines and C_TradeSkillUI.GetProfessionInfoBySkillLineID then
                    local linesOk, lines = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
                    if linesOk and type(lines) == "table" then
                        if not lines[1] then
                            pcall(function()
                                for key, value in pairs(lines) do
                                    local id = AsNumber(value) or AsNumber(key)
                                    if id then
                                        lines[#lines + 1] = id
                                    end
                                end
                            end)
                        end
                        local lineIndex = 1
                        while lines[lineIndex] do
                            local lineID = AsNumber(lines[lineIndex])
                            if lineID and lineID ~= skillLine then
                                local lineOk, lineInfo = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, lineID)
                                if lineOk and type(lineInfo) == "table" then
                                    local full = RealName(lineInfo.professionName)
                                    local parentID = AsNumber(lineInfo.parentProfessionID)
                                    local wanted = ExpansionLabel(expansionName, shown)
                                    local label = ExpansionLabel(full, shown)
                                    if full and wanted and label == wanted and (not skillLine or not parentID or parentID == skillLine) then
                                        childLine = lineID
                                        childSkill = AsNumber(lineInfo.skillLevel)
                                        childMax = AsNumber(lineInfo.maxSkillLevel)
                                    end
                                end
                            end
                            lineIndex = lineIndex + 1
                        end
                    end
                end
                local saved = RememberProfession(professions, old, {
                    skillLine = skillLine,
                    altLine = childLine,
                    name = shown,
                    icon = ProfessionTexture(childLine or skillLine, icon),
                    skill = childSkill or (infoOk and AsNumber(skill) or nil),
                    maxSkill = childMax or (infoOk and AsNumber(maxSkill) or nil),
                    scanned = false,
                    primary = primarySlot[index] and true or false,
                    fromSlots = true,
                })
                if saved then
                    saved.primary = primarySlot[index] and true or false
                    local label = ExpansionLabel(expansionName, saved.name)
                    if label then
                        EnsureExpansion(saved, {
                            name = label,
                            skillLine = childLine or skillLine,
                            skill = childSkill or (infoOk and AsNumber(skill) or nil),
                            maxSkill = childMax or (infoOk and AsNumber(maxSkill) or nil),
                            rank = ExpansionRank(label),
                        })
                    end
                end
            end
        end
        index = index + 1
    end
    return saw
end

local function ReadProfessionSkillLines(professions, old)
    if not C_TradeSkillUI or not C_TradeSkillUI.GetAllProfessionTradeSkillLines or not C_TradeSkillUI.GetProfessionInfoBySkillLineID then
        return false
    end
    local ok, lines = pcall(C_TradeSkillUI.GetAllProfessionTradeSkillLines)
    if not ok or type(lines) ~= "table" then
        return false
    end
    local saw = false
    local index = 1
    if not lines[1] then
        pcall(function()
            for key, value in pairs(lines) do
                local id = AsNumber(value) or AsNumber(key)
                if id then
                    lines[#lines + 1] = id
                end
            end
        end)
    end
    while lines[index] do
        local lineID = AsNumber(lines[index])
        if lineID then
            local infoOk, info = pcall(C_TradeSkillUI.GetProfessionInfoBySkillLineID, lineID)
            if infoOk and type(info) == "table" then
                local skill = AsNumber(info.skillLevel)
                if skill and skill > 0 then
                    saw = true
                    local parentLine = AsNumber(info.parentProfessionID)
                    local name = ProfessionDisplayName(parentLine or lineID, info.professionName, info.parentProfessionName)
                    if name and name ~= "" then
                        local skillLine = parentLine or lineID
                        local altLine = nil
                        if parentLine and parentLine ~= lineID then
                            altLine = lineID
                        end
                        local secondary = name == "Cooking" or name == "Fishing" or name == "Archaeology"
                        local saved = RememberProfession(professions, old, {
                            skillLine = skillLine,
                            altLine = altLine,
                            name = name,
                            icon = ProfessionTexture(skillLine, nil),
                            skill = skill,
                            maxSkill = AsNumber(info.maxSkillLevel),
                            scanned = false,
                            primary = not secondary,
                        })
                        if saved then
                            if saved.primary == nil then
                                saved.primary = not secondary
                            end
                            local label = ExpansionLabel(RealName(info.professionName), saved.name)
                            if label then
                                EnsureExpansion(saved, {
                                    name = label,
                                    skillLine = lineID,
                                    skill = skill,
                                    maxSkill = AsNumber(info.maxSkillLevel),
                                    rank = ExpansionRank(label),
                                })
                            end
                        end
                    end
                end
            end
        end
        index = index + 1
    end
    return saw
end

function Scan.ReadProfessionList()
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB.Get(guid) or nil
    if not record then
        return
    end
    local old = record.professions
    local professions = {}
    local sawSlots = ReadProfessionSlots(professions, old)
    ReadProfessionSkillLines(professions, old)
    if not professions[1] then
        if type(old) == "table" and old[1] then
            return
        end
        if professionListTries < 8 and not professionListWait and C_Timer and C_Timer.After then
            professionListTries = professionListTries + 1
            professionListWait = true
            C_Timer.After(1, function()
                professionListWait = false
                Scan.ReadProfessionList()
                if BMGAM.Window and BMGAM.Window.Refresh then
                    BMGAM.Window.Refresh()
                end
            end)
        elseif not sawSlots then
            record.professions = {}
        end
        return
    end
    professionListTries = 0
    local index = 1
    while professions[index] do
        professions[index].fromSlots = nil
        professions[index]._oldExpansions = nil
        SortExpansions(professions[index])
        index = index + 1
    end
    record.professions = professions
end

local function ProfessionOpen()
    if C_TradeSkillUI and C_TradeSkillUI.IsTradeSkillReady then
        local ok, ready = pcall(C_TradeSkillUI.IsTradeSkillReady)
        if ok and ready then
            return true
        end
    end
    if ProfessionsFrame and ProfessionsFrame.IsShown then
        local ok, shown = pcall(ProfessionsFrame.IsShown, ProfessionsFrame)
        if ok and shown then
            return true
        end
    end
    return false
end

local function RecipeLearned(info)
    if type(info) ~= "table" then
        return false, true
    end
    local ok, learned = pcall(function()
        if info.learned == true then
            return true
        end
        if type(info.learned) == "number" and info.learned > 0 then
            return true
        end
        return false
    end)
    if not ok then
        return false, false
    end
    return learned == true, true
end

local function LinkQuality(link)
    if type(link) ~= "string" then
        return nil
    end
    local marked = link:match("|cnIQ(%d+)")
    if marked then
        return tonumber(marked)
    end
    return nil
end

local function RecipeOutput(recipeID, info)
    local icon = PlainIcon(info and info.icon)
    local link = nil
    if C_TradeSkillUI.GetRecipeItemLink then
        local ok, itemLink = pcall(C_TradeSkillUI.GetRecipeItemLink, recipeID)
        if ok and type(itemLink) == "string" and itemLink ~= "" then
            link = itemLink
        end
    end
    if C_TradeSkillUI.GetRecipeOutputItemData then
        local ok, output = pcall(C_TradeSkillUI.GetRecipeOutputItemData, recipeID)
        if ok and type(output) == "table" then
            if type(output.hyperlink) == "string" and output.hyperlink ~= "" then
                link = output.hyperlink
            end
            icon = PlainIcon(output.icon) or icon
        end
    end
    return icon, LinkQuality(link), link
end

local function ChildExpansions(row)
    local children = {}
    if not C_TradeSkillUI.GetChildProfessionInfos then
        return children
    end
    local ok, infos = pcall(C_TradeSkillUI.GetChildProfessionInfos)
    if not ok or type(infos) ~= "table" then
        return children
    end
    local index = 1
    while infos[index] do
        local child = infos[index]
        if type(child) == "table" then
            local childLine = AsNumber(child.professionID)
            local parent = RealName(child.parentProfessionName) or row.name
            local label = ExpansionLabel(RealName(child.professionName), parent)
            local expansion = EnsureExpansion(row, {
                name = label,
                skillLine = childLine,
                skill = AsNumber(child.skillLevel),
                maxSkill = AsNumber(child.maxSkillLevel),
                rank = ExpansionRank(label),
            })
            if expansion then
                children[#children + 1] = expansion
            end
        end
        index = index + 1
    end
    SortExpansions(row)
    return children
end

local function RecipeInLine(recipeID, skillLine)
    if not recipeID or not skillLine or not C_TradeSkillUI.IsRecipeInSkillLine then
        return false
    end
    local ok, inside = pcall(function()
        return C_TradeSkillUI.IsRecipeInSkillLine(recipeID, skillLine) == true
    end)
    return ok and inside == true
end

local function ExpansionForRecipe(children, recipeID, currentLine)
    local index = 1
    while children[index] do
        if RecipeInLine(recipeID, children[index].skillLine) then
            return children[index]
        end
        index = index + 1
    end
    index = 1
    while children[index] do
        if currentLine and children[index].skillLine == currentLine then
            return children[index]
        end
        index = index + 1
    end
    return children[1]
end

function Scan.ReadOpenProfession()
    if not ProfessionOpen() then
        return
    end
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB.Get(guid) or nil
    if not record or not C_TradeSkillUI or not C_TradeSkillUI.GetAllRecipeIDs or not C_TradeSkillUI.GetRecipeInfo then
        return
    end
    if not record.professions then
        Scan.ReadProfessionList()
    end
    if type(record.professions) ~= "table" then
        record.professions = {}
    end
    local infoOk, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
    if not infoOk or type(info) ~= "table" then
        return
    end
    local currentName = RealName(info.professionName)
    local parentName = RealName(info.parentProfessionName)
    local currentLine = AsNumber(info.professionID)
    local parentLine = AsNumber(info.parentProfessionID)
    local name = parentName
    if not name or name == "" then
        name = currentName
    end
    local skillLine = parentLine or currentLine
    local altLine = currentLine
    if altLine == skillLine then
        altLine = nil
    end
    local skill = AsNumber(info.skillLevel)
    local maxSkill = AsNumber(info.maxSkillLevel)
    local idsOk, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not idsOk or type(ids) ~= "table" then
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
    local idList = {}
    local index = 1
    while ids[index] do
        idList[#idList + 1] = ids[index]
        index = index + 1
    end
    if not idList[1] then
        for key, value in pairs(ids) do
            local id = AsNumber(key) or AsNumber(value)
            if id then
                idList[#idList + 1] = id
            end
        end
    end
    local row = FindProfession(record.professions, skillLine, altLine, name, currentName)
    if not row then
        row = { skillLine = skillLine, name = name or "Profession", scanned = false, primary = true }
        record.professions[#record.professions + 1] = row
    end
    if parentName and parentName ~= "" then
        row.name = parentName
    elseif (not row.name or row.name == "" or string.match(row.name, "^%d+$")) and name and name ~= "" then
        row.name = name
    end
    if name == "Cooking" or name == "Fishing" or name == "Archaeology" then
        row.primary = false
    end
    if skillLine and not row.skillLine then
        row.skillLine = skillLine
    end
    if altLine and altLine ~= row.skillLine then
        row.altLine = altLine
    end
    if not row.icon and C_TradeSkillUI.GetTradeSkillTexture and (row.skillLine or skillLine) then
        local texOk, tex = pcall(C_TradeSkillUI.GetTradeSkillTexture, row.skillLine or skillLine)
        row.icon = texOk and PlainIcon(tex) or row.icon
    end
    if skill then
        row.skill = skill
    end
    if maxSkill then
        row.maxSkill = maxSkill
    end
    local children = ChildExpansions(row)
    local currentChild = nil
    if C_TradeSkillUI.GetProfessionChildSkillLineID then
        local childOk, childID = pcall(C_TradeSkillUI.GetProfessionChildSkillLineID)
        currentChild = childOk and AsNumber(childID) or nil
    end
    local recipesByLine = {}
    local scanFailed = false
    index = 1
    while idList[index] do
        local recipeID = AsNumber(idList[index])
        if recipeID then
            local recipeOk, recipe = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
            if recipeOk and type(recipe) == "table" then
                local learned, known = RecipeLearned(recipe)
                local recipeName = RealName(recipe.name)
                if not known or not recipeName then
                    scanFailed = true
                else
                    local icon, quality, link = RecipeOutput(recipeID, recipe)
                    local bucketLine = nil
                    local expansion = ExpansionForRecipe(children, recipeID, currentChild)
                    if expansion and expansion.skillLine then
                        bucketLine = expansion.skillLine
                    elseif currentChild then
                        bucketLine = currentChild
                    else
                        bucketLine = row.skillLine or 0
                    end
                    local bucket = recipesByLine[bucketLine]
                    if not bucket then
                        bucket = {}
                        recipesByLine[bucketLine] = bucket
                    end
                    bucket[#bucket + 1] = {
                        id = recipeID,
                        name = recipeName,
                        icon = icon,
                        learned = learned and true or false,
                        quality = quality,
                        link = link,
                    }
                end
            else
                scanFailed = true
            end
        end
        index = index + 1
    end
    if not idList[1] or scanFailed then
        if professionTries < 5 and not professionWait and C_Timer and C_Timer.After then
            professionTries = professionTries + 1
            professionWait = true
            C_Timer.After(0.6, function()
                professionWait = false
                Scan.ReadOpenProfession()
            end)
        end
    else
        local savedAny = false
        for lineKey, bucket in pairs(recipesByLine) do
            if bucket[1] then
                local expansion = nil
                local childIndex = 1
                while children[childIndex] do
                    if children[childIndex].skillLine == lineKey then
                        expansion = children[childIndex]
                    end
                    childIndex = childIndex + 1
                end
                if not expansion then
                    expansion = EnsureExpansion(row, {
                        name = ExpansionLabel(currentName, row.name),
                        skillLine = lineKey,
                        skill = skill,
                        maxSkill = maxSkill,
                        rank = ExpansionRank(ExpansionLabel(currentName, row.name)),
                    })
                end
                if expansion then
                    expansion.scanned = true
                    expansion.scannedAt = time()
                    expansion.recipes = bucket
                    savedAny = true
                end
            end
        end
        if savedAny then
            row.scanned = true
            row.scannedAt = time()
            SortExpansions(row)
        elseif professionTries < 5 and not professionWait and C_Timer and C_Timer.After then
            professionTries = professionTries + 1
            professionWait = true
            C_Timer.After(0.6, function()
                professionWait = false
                Scan.ReadOpenProfession()
            end)
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

function Scan.OnEnteringWorld()
    if not UnitGUID("player") then
        if C_Timer and C_Timer.After then
            C_Timer.After(1, Scan.OnEnteringWorld)
        end
        return
    end
    local first = not capturedThisLoad
    capturedThisLoad = true
    Scan.Capture(first, first, first)
end

function Scan.OnUpdate()
    Scan.Capture(false)
end

-- Auction helpers leave scope here for Lua's 200-local limit.
do
local auctionOpen = false
local ownedReady = false
local bidsReady = false
local ownedAsked = false
local bidsAsked = false
local auctionTries = 0
local auctionGuid = nil
local auctionRetry = false

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
        quality = ItemQuality(itemID, nil)
    end
    local icon = details and AsNumber(details.iconFileID) or nil
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
    while index <= count do
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

local function RefreshWindow()
    if BMGAM.Window and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
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
    if auctionOpen or not C_AuctionHouse or not ThrottleReady() then
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
    if not C_AuctionHouse then
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
    if SaveOwned() then
        RefreshWindow()
    end
end

function Scan.OnBidsUpdated()
    if SaveBids() then
        RefreshWindow()
    end
end

function Scan.OnAuctionThrottle()
    if auctionOpen then
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
    if auctionOpen then
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

-- Quest helpers leave scope here for Lua's 200-local limit.
do
local state = {
    guid = nil,
    wait = false,
    expand = false,
    token = 0,
    running = false,
    tries = 0,
    ids = nil,
    index = 1,
    limit = 0,
    build = nil,
    seen = nil,
    loads = 0,
    waiting = {},
    retry = {},
    retryIndex = 1,
    places = {},
    zoneRects = {},
    dates = {},
    byID = {},
    needZone = {},
    turnedIn = nil,
}

local function Bind()
    local zoneType = 3
    local dungeonType = 4
    local continentType = 2
    local worldType = 1
    if type(Enum) == "table" and type(Enum.UIMapType) == "table" then
        if type(Enum.UIMapType.Zone) == "number" then
            zoneType = Enum.UIMapType.Zone
        end
        if type(Enum.UIMapType.Dungeon) == "number" then
            dungeonType = Enum.UIMapType.Dungeon
        end
        if type(Enum.UIMapType.Continent) == "number" then
            continentType = Enum.UIMapType.Continent
        end
        if type(Enum.UIMapType.World) == "number" then
            worldType = Enum.UIMapType.World
        end
    end

    local function PlayerRecord()
        if not UnitGUID or not BMGAM.DB or not BMGAM.DB.Get then
            return nil, nil
        end
        local guid = UnitGUID("player")
        if not guid then
            return nil, nil
        end
        return BMGAM.DB.Get(guid), guid
    end

    local function Pack(record)
        local pack = nil
        if BMGAM.Store and BMGAM.Store.Quests then
            pack = BMGAM.Store.Quests(record, true)
        end
        if type(pack) ~= "table" then
            if type(record.quests) ~= "table" then
                record.quests = {}
            end
            pack = record.quests
        end
        if type(pack.current) ~= "table" then
            pack.current = {}
        end
        if type(pack.completed) ~= "table" then
            pack.completed = {}
        end
        return pack
    end

    local function Count(list)
        if type(list) ~= "table" then
            return 0
        end
        local count = 0
        while list[count + 1] do
            count = count + 1
        end
        return count
    end

    local function MapPlace(mapID)
        mapID = AsNumber(mapID)
        if not mapID or mapID <= 0 or not C_Map or type(C_Map.GetMapInfo) ~= "function" then
            return nil
        end
        local cached = state.places[mapID]
        if cached ~= nil then
            if cached == false then
                return nil
            end
            return cached
        end
        local steps = {}
        local current = mapID
        local guard = 0
        while current and current > 0 and guard < 8 do
            local ok, info = pcall(C_Map.GetMapInfo, current)
            if not ok or type(info) ~= "table" then
                break
            end
            local mapType = AsNumber(info.mapType)
            steps[#steps + 1] = {
                name = SafeText(info.name),
                mapType = mapType,
            }
            local parent = AsNumber(info.parentMapID)
            if mapType == worldType or not parent or parent == current or parent <= 0 then
                break
            end
            current = parent
            guard = guard + 1
        end
        local worldName = nil
        local contentName = nil
        local contentIndex = nil
        local index = 1
        while steps[index] do
            local step = steps[index]
            if step.mapType == continentType and step.name and not contentName then
                contentName = step.name
                contentIndex = index
            end
            if step.mapType == worldType and step.name and not worldName then
                worldName = step.name
            end
            index = index + 1
        end
        local zoneName = nil
        if contentIndex and contentIndex > 1 then
            local look = contentIndex - 1
            while look >= 1 do
                local step = steps[look]
                if step.mapType == zoneType and step.name then
                    zoneName = step.name
                    break
                end
                look = look - 1
            end
            if not zoneName and steps[contentIndex - 1].name then
                zoneName = steps[contentIndex - 1].name
            end
        end
        if not zoneName then
            index = 1
            while steps[index] do
                if steps[index].mapType == zoneType and steps[index].name then
                    zoneName = steps[index].name
                    break
                end
                index = index + 1
            end
        end
        if not worldName and not contentName and not zoneName then
            state.places[mapID] = false
            return nil
        end
        local place = {
            world = worldName,
            content = contentName,
            zone = zoneName,
        }
        state.places[mapID] = place
        return place
    end

    local function ZoneRects(parentMapID)
        local cached = state.zoneRects[parentMapID]
        if cached ~= nil then
            return cached
        end
        local list = {}
        if parentMapID and C_Map and type(C_Map.GetMapChildrenInfo) == "function" and type(C_Map.GetMapRectOnMap) == "function" then
            local ok, children = pcall(C_Map.GetMapChildrenInfo, parentMapID, zoneType, false)
            local index = 1
            while ok and type(children) == "table" and children[index] do
                local child = children[index]
                local childID = type(child) == "table" and AsNumber(child.mapID) or nil
                local childName = type(child) == "table" and SafeText(child.name) or nil
                if childID and childName then
                    local rectOk, minX, maxX, minY, maxY = pcall(C_Map.GetMapRectOnMap, childID, parentMapID)
                    minX = rectOk and AsNumber(minX) or nil
                    maxX = rectOk and AsNumber(maxX) or nil
                    minY = rectOk and AsNumber(minY) or nil
                    maxY = rectOk and AsNumber(maxY) or nil
                    if minX and maxX and minY and maxY and maxX > minX and maxY > minY then
                        list[#list + 1] = {
                            name = childName,
                            minX = minX,
                            maxX = maxX,
                            minY = minY,
                            maxY = maxY,
                        }
                    end
                end
                index = index + 1
            end
        end
        state.zoneRects[parentMapID] = list
        return list
    end

    local function ZoneContaining(parentMapID, x, y)
        x = AsNumber(x)
        y = AsNumber(y)
        if not parentMapID or not x or not y then
            return nil
        end
        if x > 1 then
            x = x / 100
        end
        if y > 1 then
            y = y / 100
        end
        if x <= 0 and y <= 0 then
            return nil
        end
        local rects = ZoneRects(parentMapID)
        local bestName = nil
        local bestArea = nil
        local index = 1
        while rects[index] do
            local rect = rects[index]
            if x >= rect.minX and x <= rect.maxX and y >= rect.minY and y <= rect.maxY then
                local area = (rect.maxX - rect.minX) * (rect.maxY - rect.minY)
                if not bestArea or area < bestArea then
                    bestArea = area
                    bestName = rect.name
                end
            end
            index = index + 1
        end
        return bestName
    end

    local function ZoneFromPoint(mapID, x, y)
        mapID = AsNumber(mapID)
        if not mapID or mapID <= 0 or x == nil or y == nil or not C_Map or type(C_Map.GetMapInfoAtPosition) ~= "function" then
            return nil
        end
        local px = AsNumber(x)
        local py = AsNumber(y)
        if px and py then
            if px > 1 then
                px = px / 100
            end
            if py > 1 then
                py = py / 100
            end
            if px <= 0 and py <= 0 then
                return nil
            end
            x = px
            y = py
        end
        local ok, info = pcall(C_Map.GetMapInfoAtPosition, mapID, x, y)
        if not ok or type(info) ~= "table" then
            return nil
        end
        local mapType = AsNumber(info.mapType)
        if mapType == worldType or mapType == continentType then
            return nil
        end
        local foundID = AsNumber(info.mapID)
        if foundID and foundID ~= mapID then
            local nested = MapPlace(foundID)
            if nested and nested.zone then
                return nested.zone
            end
        end
        local name = SafeText(info.name)
        if name and name ~= "" then
            return name
        end
        return nil
    end

    local function WithZone(place, mapID, x, y)
        if not place then
            return nil
        end
        if place.zone then
            return place
        end
        local zoneName = ZoneFromPoint(mapID, x, y)
        if not zoneName then
            zoneName = ZoneContaining(mapID, x, y)
        end
        if not zoneName or zoneName == place.world or zoneName == place.content then
            return place
        end
        return {
            world = place.world,
            content = place.content,
            zone = zoneName,
        }
    end

    local function PlaceScore(place)
        if not place then
            return 0
        end
        local score = 0
        if place.zone then
            score = score + 4
        end
        if place.content then
            score = score + 2
        end
        if place.world then
            score = score + 1
        end
        return score
    end

    local function KeepPlace(best, place)
        if PlaceScore(place) > PlaceScore(best) then
            return place
        end
        return best
    end

    local function LinePlace(questID, parentMapID)
        if not questID or not C_QuestLine or type(C_QuestLine.GetQuestLineInfo) ~= "function" then
            return nil
        end
        local ok, info = pcall(C_QuestLine.GetQuestLineInfo, questID, parentMapID, false)
        if not ok or type(info) ~= "table" then
            return nil
        end
        local mapID = AsNumber(info.startMapID)
        local place = WithZone(MapPlace(mapID), mapID, info.x, info.y)
        if place and place.zone then
            return place
        end
        local lineName = SafeText(info.questLineName)
        if not lineName or not parentMapID or not C_Map or type(C_Map.GetMapChildrenInfo) ~= "function" then
            return place
        end
        local childrenOk, children = pcall(C_Map.GetMapChildrenInfo, parentMapID, zoneType, false)
        local index = 1
        while childrenOk and type(children) == "table" and children[index] do
            local child = children[index]
            local childName = type(child) == "table" and SafeText(child.name) or nil
            if childName and childName == lineName then
                local base = place or MapPlace(parentMapID) or {}
                return {
                    world = base.world,
                    content = base.content,
                    zone = childName,
                }
            end
            index = index + 1
        end
        return place
    end

    local function CatalogPlace(questID)
        if type(qcQuestDatabase) ~= "table" or type(qcCategoryUiMapID) ~= "table" then
            return nil
        end
        local entry = qcQuestDatabase[questID]
        if type(entry) ~= "table" then
            return nil
        end
        local category = entry[3]
        if type(category) ~= "number" or category <= 0 then
            return nil
        end
        return MapPlace(qcCategoryUiMapID[category])
    end

    local function ChainPlace(questID)
        if not BtWQuestsDatabase or type(BtWQuestsDatabase.GetQuestByID) ~= "function" then
            return nil
        end
        local ok, quest = pcall(BtWQuestsDatabase.GetQuestByID, BtWQuestsDatabase, questID)
        if not ok or type(quest) ~= "table" then
            return nil
        end
        local mapID = nil
        if type(quest.GetSource) == "function" then
            local sourceOk, source = pcall(quest.GetSource, quest)
            if sourceOk and type(source) == "table" and type(source.GetLocation) == "function" then
                local locOk, located = pcall(source.GetLocation, source)
                if locOk then
                    mapID = AsNumber(located)
                end
            end
        end
        if not mapID and type(quest.target) == "table" then
            mapID = AsNumber(quest.target.uiMapID or quest.target.mapID)
        end
        return MapPlace(mapID)
    end

    local function QuestPlace(questID)
        if not questID or not C_QuestLog then
            return nil
        end
        local best = nil
        if type(C_QuestLog.GetQuestUiMapID) == "function" then
            local ok, mapID = pcall(C_QuestLog.GetQuestUiMapID, questID)
            if ok then
                best = KeepPlace(best, MapPlace(mapID))
            end
        end
        if (not best or not best.zone) and type(GetQuestUiMapID) == "function" then
            local ok, mapID = pcall(GetQuestUiMapID, questID, true)
            if not ok then
                ok, mapID = pcall(GetQuestUiMapID, questID)
            end
            if ok then
                best = KeepPlace(best, MapPlace(mapID))
            end
        end
        local pinMap = nil
        if (not best or not best.zone) and type(C_QuestLog.GetNextWaypoint) == "function" then
            local ok, mapID, x, y = pcall(C_QuestLog.GetNextWaypoint, questID)
            if ok then
                pinMap = AsNumber(mapID)
                best = KeepPlace(best, WithZone(MapPlace(mapID), pinMap, x, y))
            end
        end
        if not best or not best.zone then
            best = KeepPlace(best, LinePlace(questID, pinMap))
        end
        if (not best or not best.zone) and type(C_QuestLog.GetQuestAdditionalHighlights) == "function" then
            local ok, mapID = pcall(C_QuestLog.GetQuestAdditionalHighlights, questID)
            if ok then
                local highlight = AsNumber(mapID)
                local place = MapPlace(mapID)
                if not place or not place.zone then
                    place = KeepPlace(place, LinePlace(questID, highlight))
                end
                best = KeepPlace(best, place)
            end
        end
        if not best or not best.zone then
            best = KeepPlace(best, CatalogPlace(questID))
        end
        if (not best or not best.zone) and type(BMGAM_QuestMaps) == "table" then
            best = KeepPlace(best, MapPlace(BMGAM_QuestMaps[questID]))
        end
        if not best or not best.zone then
            best = KeepPlace(best, ChainPlace(questID))
        end
        return best
    end

    local function TitleFor(questID)
        if not questID or not C_QuestLog or type(C_QuestLog.GetTitleForQuestID) ~= "function" then
            return nil
        end
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        if not ok then
            return nil
        end
        return SafeText(title)
    end

    local function Difficulty(questID)
        if not questID or not C_QuestLog or type(C_QuestLog.GetQuestDifficultyLevel) ~= "function" then
            return nil
        end
        local ok, level = pcall(C_QuestLog.GetQuestDifficultyLevel, questID)
        if not ok then
            return nil
        end
        local number = AsNumber(level)
        if number and number > 0 then
            return number
        end
        return nil
    end

    local function TagID(questID)
        if not questID or not C_QuestLog or type(C_QuestLog.GetQuestTagInfo) ~= "function" then
            return nil
        end
        local ok, info = pcall(C_QuestLog.GetQuestTagInfo, questID)
        if ok and type(info) == "table" then
            return AsNumber(info.tagID)
        end
        return nil
    end

    local function Activity(questID)
        local tag = TagID(questID)
        if tag == 81 then
            return "Dungeon"
        end
        if tag == 62 or tag == 88 or tag == 89 then
            return "Raid"
        end
        if tag == 98 then
            return "Scenario"
        end
        if tag == 288 then
            return "Delve"
        end
        return nil
    end

    local function WarbandQuest(questID)
        local function ReadFlag(value)
            if value == true or value == 1 then
                return true
            end
            if type(issecretvalue) ~= "function" or type(string.concat) ~= "function" then
                return false
            end
            local secretOk, secret = pcall(issecretvalue, value)
            if not secretOk or not secret then
                return false
            end
            local ok, text = pcall(string.concat, value)
            return ok and (text == "true" or text == "1")
        end
        if questID and C_QuestLog and type(C_QuestLog.IsAccountQuest) == "function" then
            local ok, flag = pcall(C_QuestLog.IsAccountQuest, questID)
            if ok and ReadFlag(flag) then
                return true
            end
        end
        if TagID(questID) == 102 then
            return true
        end
        if type(qcQuestDatabase) == "table" then
            local entry = qcQuestDatabase[questID]
            if type(entry) == "table" and entry[3] == 1429 then
                return true
            end
        end
        local title = TitleFor(questID)
        if type(title) == "string" then
            if string.sub(title, 1, 14) == "Gain New Look:" or string.sub(title, 1, 21) == "Gain Even Newer Look:" then
                return true
            end
            if string.sub(title, 1, 13) == "Renowned with" or title == "Ritual Site Renowned" then
                return true
            end
        end
        if questID and C_QuestLog and type(C_QuestLog.GetQuestTagInfo) == "function" then
            local ok, info = pcall(C_QuestLog.GetQuestTagInfo, questID)
            if ok and type(info) == "table" then
                local tagName = SafeText(info.tagName)
                if tagName == "Account" or tagName == "Warband" then
                    return true
                end
            end
        end
        return false
    end

    local function HiddenQuest(title)
        if type(title) ~= "string" then
            return false
        end
        if title == "Tracking Quest" then
            return true
        end
        if string.match(title, "^Level %d+$") then
            return true
        end
        if string.sub(title, 1, 5) == "[DNT]" then
            return true
        end
        return false
    end

    local function ShownCount()
        if not C_QuestLog or type(C_QuestLog.GetNumQuestLogEntries) ~= "function" then
            return 0
        end
        local ok, shown = pcall(C_QuestLog.GetNumQuestLogEntries)
        if not ok then
            return 0
        end
        return AsNumber(shown) or 0
    end

    local function InfoAt(index)
        if not C_QuestLog or type(C_QuestLog.GetInfo) ~= "function" then
            return nil
        end
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        if ok and type(info) == "table" then
            return info
        end
        return nil
    end

    local function ReadCurrent(record, expandHeaders)
        local collapsed = nil
        if expandHeaders and type(ExpandQuestHeader) == "function" then
            collapsed = {}
            local shown = ShownCount()
            local index = 1
            while index <= shown do
                local info = InfoAt(index)
                if info and TrueFlag(info.isHeader) and TrueFlag(info.isCollapsed) then
                    local title = SafeText(info.title)
                    if title then
                        collapsed[title] = true
                    end
                end
                index = index + 1
            end
            local guard = 0
            while guard < 30 do
                shown = ShownCount()
                index = 1
                local opened = false
                while index <= shown do
                    local info = InfoAt(index)
                    if info and TrueFlag(info.isHeader) and TrueFlag(info.isCollapsed) then
                        pcall(ExpandQuestHeader, index)
                        opened = true
                        break
                    end
                    index = index + 1
                end
                if not opened then
                    break
                end
                guard = guard + 1
            end
        end
        local rows = {}
        local seen = {}
        local fallback = nil
        local shown = ShownCount()
        local index = 1
        while index <= shown do
            local info = InfoAt(index)
            if info then
                local header = TrueFlag(info.isHeader) and not TrueFlag(info.sortAsNormalQuest)
                if header then
                    fallback = SafeText(info.title) or fallback
                elseif not TrueFlag(info.isHidden) and not TrueFlag(info.isInternalOnly) then
                    local questID = AsNumber(info.questID)
                    local name = SafeText(info.title)
                    if questID and questID > 0 and name and not seen[questID] and not HiddenQuest(name) then
                        seen[questID] = true
                        local level = AsNumber(info.level)
                        if not level or level <= 0 then
                            level = AsNumber(info.difficultyLevel)
                        end
                        if not level or level <= 0 then
                            level = Difficulty(questID)
                        end
                        if level and level <= 0 then
                            level = nil
                        end
                        local place = QuestPlace(questID)
                        local row = {
                            name = name,
                            questID = questID,
                        }
                        if place and place.world then
                            row.world = place.world
                        end
                        if place and place.content then
                            row.content = place.content
                        end
                        local zoneName = place and place.zone or nil
                        if not zoneName and fallback and fallback ~= row.world and fallback ~= row.content then
                            zoneName = fallback
                        end
                        if zoneName then
                            row.zone = zoneName
                        end
                        if level then
                            row.level = level
                        end
                        local activity = Activity(questID)
                        if activity then
                            row.activity = activity
                        end
                        if WarbandQuest(questID) then
                            row.account = true
                        end
                        rows[#rows + 1] = row
                    end
                end
            end
            index = index + 1
        end
        if collapsed and type(CollapseQuestHeader) == "function" then
            shown = ShownCount()
            index = 1
            while index <= shown do
                local info = InfoAt(index)
                local title = info and SafeText(info.title)
                if info and TrueFlag(info.isHeader) and title and collapsed[title] and not TrueFlag(info.isCollapsed) then
                    pcall(CollapseQuestHeader, index)
                end
                index = index + 1
            end
        end
        local pack = Pack(record)
        pack.current = rows
        pack.scanned = true
        pack.scannedAt = time()
    end

    local function RefreshQuests()
        if BMGAM.Window and BMGAM.Window.tab == "quests" and BMGAM.Window.Refresh then
            BMGAM.Window.Refresh()
        end
    end

    local function ApplyPlace(row, questID)
        local place = QuestPlace(questID)
        if place then
            if place.world then
                row.world = place.world
            end
            if place.content then
                row.content = place.content
            end
            if place.zone then
                row.zone = place.zone
            end
        end
        if WarbandQuest(questID) then
            row.account = true
        end
    end

    local function MakeRow(questID, title)
        local row = {
            name = title,
            questID = questID,
        }
        local level = Difficulty(questID)
        if level then
            row.level = level
        end
        local activity = Activity(questID)
        if activity then
            row.activity = activity
        end
        ApplyPlace(row, questID)
        local when = state.dates and state.dates[questID]
        if type(when) == "number" and when > 0 then
            row.completedAt = when
        end
        return row
    end

    local function AddKnown(questID, title)
        state.seen[questID] = true
        local row = MakeRow(questID, title)
        state.build[#state.build + 1] = row
        state.byID[questID] = row
        return row
    end

    local function Publish(record, ready)
        if type(state.build) ~= "table" then
            return
        end
        local pack = Pack(record)
        local previousCount = 0
        if pack.completed ~= state.build then
            previousCount = Count(pack.completed)
        end
        if ready or Count(state.build) >= previousCount then
            pack.completed = state.build
        end
        pack.scanned = true
        if ready then
            pack.completed = state.build
            pack.completedReady = true
            pack.scannedAt = time()
        end
    end

    local function Request(questID)
        local needZone = state.needZone and state.needZone[questID]
        if not questID or state.waiting[questID] or ((state.seen and state.seen[questID]) and not needZone) then
            return
        end
        if state.loads >= 25 or not C_QuestLog or type(C_QuestLog.RequestLoadQuestByID) ~= "function" then
            state.retry[#state.retry + 1] = questID
            return
        end
        local ok = pcall(C_QuestLog.RequestLoadQuestByID, questID)
        if ok then
            state.waiting[questID] = true
            state.loads = state.loads + 1
        end
    end

    local function Pump()
        while state.retry[state.retryIndex] and state.loads < 25 do
            local questID = state.retry[state.retryIndex]
            state.retryIndex = state.retryIndex + 1
            Request(questID)
        end
    end

    local function WalkDone()
        if state.index <= state.limit then
            return false
        end
        if state.loads > 0 then
            return false
        end
        if state.retry[state.retryIndex] then
            return false
        end
        return true
    end

    local function Step(token)
        if token ~= state.token or not state.running then
            return
        end
        local record = PlayerRecord()
        if not record then
            state.running = false
            return
        end
        local steps = 0
        while state.index <= state.limit and steps < 60 do
            local questID = AsNumber(state.ids[state.index])
            state.index = state.index + 1
            steps = steps + 1
            if questID and questID > 0 and not state.seen[questID] then
                local title = TitleFor(questID)
                if title then
                    if HiddenQuest(title) then
                        state.seen[questID] = true
                    else
                        local row = AddKnown(questID, title)
                        if row and not row.zone then
                            state.needZone[questID] = true
                            Request(questID)
                        end
                    end
                else
                    Request(questID)
                end
            end
        end
        if state.index > state.limit then
            Pump()
        end
        if WalkDone() then
            Publish(record, true)
            state.running = false
            RefreshQuests()
            return
        end
        Publish(record, false)
        state.paints = (state.paints or 0) + 1
        if state.paints >= 8 then
            state.paints = 0
            RefreshQuests()
        end
        if state.index <= state.limit then
            C_Timer.After(0.05, function()
                Step(token)
            end)
        end
    end

    local function CompletedList()
        if not C_QuestLog or type(C_QuestLog.GetAllCompletedQuestIDs) ~= "function" then
            return nil, false
        end
        local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
        if not ok or type(ids) ~= "table" then
            return nil, false
        end
        return ids, true
    end

    local function StartWalk(record)
        state.token = state.token + 1
        local token = state.token
        local guid = state.guid
        state.running = true
        local ids, ok = CompletedList()
        if not ok then
            state.tries = state.tries + 1
            if state.tries <= 4 then
                C_Timer.After(1, function()
                    if state.token ~= token or state.guid ~= guid then
                        return
                    end
                    state.running = false
                    StartWalk(record)
                end)
                return
            end
            local pack = Pack(record)
            pack.scanned = true
            pack.completedReady = true
            state.running = false
            return
        end
        local limit = 0
        local reportedOk, reported = pcall(function()
            return #ids
        end)
        if reportedOk and type(reported) == "number" and reported > 0 then
            limit = reported
            if limit > 20000 then
                limit = 20000
            end
        else
            while ids[limit + 1] ~= nil and limit < 20000 do
                limit = limit + 1
            end
        end
        if limit == 0 and state.tries < 3 then
            state.tries = state.tries + 1
            C_Timer.After(1, function()
                if state.token ~= token or state.guid ~= guid then
                    return
                end
                state.running = false
                StartWalk(record)
            end)
            return
        end
        state.tries = 0
        local savedPack = BMGAM.Store and BMGAM.Store.Quests and BMGAM.Store.Quests(record, false) or record.quests
        local saved = savedPack and savedPack.completed
        local savedIndex = 1
        while type(saved) == "table" and saved[savedIndex] do
            local savedID = saved[savedIndex].questID
            local savedWhen = saved[savedIndex].completedAt
            if savedID and type(savedWhen) == "number" and savedWhen > 0 and not state.dates[savedID] then
                state.dates[savedID] = savedWhen
            end
            savedIndex = savedIndex + 1
        end
        state.ids = ids
        state.index = 1
        state.limit = limit
        state.build = {}
        state.seen = {}
        state.byID = {}
        state.needZone = {}
        state.loads = 0
        state.waiting = {}
        state.retry = {}
        state.retryIndex = 1
        state.paints = 0
        local pack = Pack(record)
        pack.completedReady = false
        pack.scanned = true
        if limit == 0 then
            Publish(record, true)
            state.running = false
            return
        end
        C_Timer.After(0.05, function()
            Step(token)
        end)
        C_Timer.After(45, function()
            if state.token ~= token or not state.running then
                return
            end
            local current = PlayerRecord()
            if current then
                Publish(current, true)
            end
            state.running = false
            RefreshQuests()
        end)
    end

    local function HasQuest(list, questID)
        local index = 1
        while type(list) == "table" and list[index] do
            if list[index].questID == questID then
                return true
            end
            index = index + 1
        end
        return false
    end

    local function Stamp(list, questID, when)
        local index = 1
        while type(list) == "table" and list[index] do
            if list[index].questID == questID then
                list[index].completedAt = when
                return true
            end
            index = index + 1
        end
        return false
    end

    local function AddTurnedIn(record, questID)
        questID = AsNumber(questID)
        if not questID or questID <= 0 or not record then
            return
        end
        state.dates = state.dates or {}
        state.dates[questID] = time()
        local title = TitleFor(questID)
        if not title then
            Request(questID)
            return
        end
        if state.running and state.seen and not state.seen[questID] then
            AddKnown(questID, title)
        end
        local pack = Pack(record)
        if Stamp(pack.completed, questID, state.dates[questID]) then
            return
        end
        pack.completed[#pack.completed + 1] = MakeRow(questID, title)
    end

    function Scan.ReadQuests()
        local record, guid = PlayerRecord()
        if not record or not guid then
            return
        end
        ReadCurrent(record, true)
        if state.guid ~= guid then
            state.guid = guid
            state.tries = 0
            state.dates = {}
            StartWalk(record)
        elseif not state.running then
            local pack = BMGAM.Store and BMGAM.Store.Quests and BMGAM.Store.Quests(record, false) or record.quests
            if type(pack) ~= "table" or pack.completedReady ~= true then
                StartWalk(record)
            end
        end
    end

    function Scan.OnQuests(expandHeaders)
        if expandHeaders then
            state.expand = true
        end
        if state.wait then
            return
        end
        state.wait = true
        C_Timer.After(0.4, function()
            local expand = state.expand
            state.wait = false
            state.expand = false
            local record = PlayerRecord()
            if record then
                ReadCurrent(record, expand)
            end
            if BMGAM.Window and BMGAM.Window.Refresh then
                BMGAM.Window.Refresh()
            end
        end)
    end

    function Scan.OnQuestTurnedIn(questID)
        questID = AsNumber(questID)
        state.turnedIn = questID
        local record = PlayerRecord()
        if record then
            ReadCurrent(record, true)
            AddTurnedIn(record, questID)
        end
        if BMGAM.Window and BMGAM.Window.Refresh then
            BMGAM.Window.Refresh()
        end
    end

    function Scan.OnQuestData(questID)
        questID = AsNumber(questID)
        if not questID then
            return
        end
        if state.waiting[questID] then
            state.waiting[questID] = nil
            state.loads = state.loads - 1
            if state.loads < 0 then
                state.loads = 0
            end
        end
        local record = PlayerRecord()
        if record then
            local title = TitleFor(questID)
            if title and HiddenQuest(title) then
                if state.seen then
                    state.seen[questID] = true
                end
            elseif title then
                if state.running and state.seen and not state.seen[questID] then
                    AddKnown(questID, title)
                    Publish(record, false)
                end
                local placed = state.byID and state.byID[questID]
                if placed and state.needZone and state.needZone[questID] then
                    state.needZone[questID] = nil
                    ApplyPlace(placed, questID)
                end
                if questID == state.turnedIn then
                    AddTurnedIn(record, questID)
                    state.turnedIn = nil
                end
            end
            if state.running and WalkDone() then
                Publish(record, true)
                state.running = false
            else
                Pump()
            end
        end
        RefreshQuests()
    end
end

Bind()
end

do
    local function Flag(value)
        if value == true or value == 1 then
            return true
        end
        if type(issecretvalue) ~= "function" or type(string.concat) ~= "function" then
            return false
        end
        local secretOk, secret = pcall(issecretvalue, value)
        if not secretOk or not secret then
            return false
        end
        local ok, text = pcall(string.concat, value)
        return ok and (text == "true" or text == "1")
    end

    local function StatisticSet()
        local set = { [1] = true }
        if type(GetStatisticsCategoryList) ~= "function" then
            return set
        end
        local ok, list = pcall(GetStatisticsCategoryList)
        if not ok or type(list) ~= "table" then
            return set
        end
        local index = 1
        while list[index] do
            local id = AsNumber(list[index])
            if id then
                set[id] = true
            end
            index = index + 1
        end
        return set
    end

    local function CategoryOrder(id)
        if type(BMGAM_AchievementOrder) == "table" and type(BMGAM_AchievementOrder[id]) == "number" then
            return BMGAM_AchievementOrder[id]
        end
        return 5000
    end

    local function Series(achId)
        local list = {}
        achId = AsNumber(achId)
        if not achId or achId <= 0 then
            return list
        end
        local root = achId
        local guard = 0
        while guard < 40 do
            guard = guard + 1
            if type(GetPreviousAchievement) ~= "function" then
                break
            end
            local ok, prev = pcall(GetPreviousAchievement, root)
            prev = ok and AsNumber(prev) or nil
            if not prev or prev <= 0 or prev == root then
                break
            end
            root = prev
        end
        list[1] = root
        local index = 1
        guard = 0
        while guard < 40 do
            guard = guard + 1
            local current = list[index]
            local nxt = nil
            if C_AchievementInfo and type(C_AchievementInfo.GetSupercedingAchievements) == "function" then
                local ok, nextIds = pcall(C_AchievementInfo.GetSupercedingAchievements, current)
                if ok and type(nextIds) == "table" then
                    nxt = AsNumber(nextIds[1])
                end
            end
            if (not nxt or nxt <= 0) and type(GetNextAchievement) == "function" then
                local ok, nextId = pcall(GetNextAchievement, current)
                nxt = ok and AsNumber(nextId) or nil
            end
            if not nxt or nxt <= 0 or nxt == current then
                break
            end
            local seen = 1
            local repeatId = false
            while list[seen] do
                if list[seen] == nxt then
                    repeatId = true
                    break
                end
                seen = seen + 1
            end
            if repeatId then
                break
            end
            index = index + 1
            list[index] = nxt
        end
        return list
    end

    local function HomeCategory(achId, fallback, kept)
        if type(GetAchievementCategory) == "function" then
            local ok, cat = pcall(GetAchievementCategory, achId)
            cat = ok and AsNumber(cat) or nil
            if cat and kept[cat] then
                return cat
            end
        end
        if fallback and kept[fallback] then
            return fallback
        end
        return nil
    end

    local function Requirements(achId)
        if type(GetAchievementNumCriteria) ~= "function" or type(GetAchievementCriteriaInfo) ~= "function" then
            return nil, nil
        end
        local countOk, count = pcall(GetAchievementNumCriteria, achId)
        count = countOk and AsNumber(count) or 0
        if not count or count < 1 then
            return nil, nil
        end
        local needs = {}
        local done = 0
        local index = 1
        local quantityStatus = nil
        while index <= count do
            local infoOk, criteriaString, criteriaType, completed, quantity, reqQuantity, _, _, assetID, quantityString = pcall(GetAchievementCriteriaInfo, achId, index)
            if infoOk then
                local text = SafeText(criteriaString)
                local kind = AsNumber(criteriaType)
                local asset = AsNumber(assetID)
                if not text and kind == 8 and asset then
                    local nameOk, _, otherName = pcall(GetAchievementInfo, asset)
                    if nameOk then
                        text = SafeText(otherName)
                    end
                end
                local finished = Flag(completed)
                if finished then
                    done = done + 1
                end
                local req = AsNumber(reqQuantity)
                local have = AsNumber(quantity)
                local qtyText = SafeText(quantityString)
                if text then
                    local entry = { name = text }
                    if finished then
                        entry.done = true
                    elseif qtyText then
                        entry.left = qtyText
                    elseif have and req and req > 1 then
                        entry.left = have .. "/" .. req
                    end
                    if kind == 8 and asset then
                        entry.achievement = asset
                    end
                    needs[#needs + 1] = entry
                end
                if count == 1 and req and req > 1 then
                    if qtyText then
                        quantityStatus = qtyText
                    elseif have then
                        quantityStatus = have .. "/" .. req
                    end
                end
            end
            index = index + 1
        end
        local status = quantityStatus
        if not status then
            status = done .. "/" .. count
        end
        if not needs[1] then
            needs = nil
        end
        return status, needs
    end

    local function SameCharacter(left, right)
        if not left or not right or left == "" or right == "" then
            return false
        end
        return string.lower(left) == string.lower(right)
    end

    local function CriterionEarner(achId, player)
        if type(GetAchievementNumCriteria) ~= "function" or type(GetAchievementCriteriaInfo) ~= "function" then
            return nil
        end
        local countOk, count = pcall(GetAchievementNumCriteria, achId)
        count = countOk and AsNumber(count) or 0
        if not count or count < 1 then
            return nil
        end
        local other = nil
        local index = 1
        while index <= count do
            local infoOk, _, _, completed, _, _, charName = pcall(GetAchievementCriteriaInfo, achId, index)
            local who = infoOk and Flag(completed) and SafeText(charName) or nil
            if who and not SameCharacter(who, player) then
                other = who
            end
            index = index + 1
        end
        return other
    end

    local function AccountWide(flags)
        local flagNumber = AsNumber(flags)
        if not flagNumber or not bit or not bit.band then
            return false
        end
        local bandOk, banded = pcall(bit.band, flagNumber, 131072)
        return bandOk and banded ~= 0
    end

    local function AddAchievement(achId, fallback, rows, seen, kept, stats, seriesRoot, stepNo)
        achId = AsNumber(achId)
        if not achId or achId <= 0 or seen[achId] then
            return
        end
        seen[achId] = true
        local achOk, _, name, points, completed, month, day, year, description, flags, _, _, _, wasMe, earnedBy, isStatistic = pcall(GetAchievementInfo, achId)
        if not achOk then
            return
        end
        name = SafeText(name)
        local statistic = Flag(isStatistic)
        if not statistic then
            local flagNumber = AsNumber(flags)
            if flagNumber and bit and bit.band then
                local bandOk, banded = pcall(bit.band, flagNumber, 1)
                if bandOk and banded ~= 0 then
                    statistic = true
                end
            end
        end
        if statistic or not name then
            return
        end
        local home = HomeCategory(achId, fallback, kept)
        if not home or stats[home] then
            return
        end
        local row = {
            id = achId,
            name = name,
            category = home,
        }
        local pts = AsNumber(points)
        if pts then
            row.points = pts
        end
        local detail = SafeText(description)
        if detail and detail ~= name then
            row.detail = detail
        end
        if type(seriesRoot) == "number" and type(stepNo) == "number" then
            row.series = seriesRoot
            row.step = stepNo
        end
        local progress, needs = Requirements(achId)
        if needs then
            row.needs = needs
        end
        if Flag(completed) then
            row.earned = true
            local earnedMonth = AsNumber(month)
            local earnedDay = AsNumber(day)
            local earnedYear = AsNumber(year)
            if earnedMonth and earnedDay and earnedYear and earnedMonth >= 1 and earnedMonth <= 12 and earnedDay >= 1 and earnedDay <= 31 then
                if earnedYear < 100 then
                    earnedYear = earnedYear + 2000
                end
                row.month = earnedMonth
                row.day = earnedDay
                row.year = earnedYear
            end
            local player = SafeText(UnitName("player"))
            local named = SafeText(earnedBy)
            local other = CriterionEarner(achId, player)
            local who = nil
            if other then
                who = other
            elseif named and not SameCharacter(named, player) then
                who = named
            elseif AccountWide(flags) or not named then
                who = "Account Wide"
            else
                who = named
            end
            row.who = who
        elseif progress then
            row.progress = progress
        end
        rows[#rows + 1] = row
    end

    local function DropStatistics(categories, stats)
        local changed = true
        while changed do
            changed = false
            local kept = {}
            local index = 1
            while categories[index] do
                local cat = categories[index]
                if stats[cat.id] or stats[cat.parent] then
                    stats[cat.id] = true
                    changed = true
                else
                    kept[#kept + 1] = cat
                end
                index = index + 1
            end
            categories = kept
        end
        return categories
    end

    function Scan.ReadAchievements()
        if type(GetCategoryList) ~= "function" or type(GetCategoryInfo) ~= "function" or type(GetAchievementInfo) ~= "function" then
            return
        end
        local guid = UnitGUID("player")
        if not guid or not BMGAM.DB or not BMGAM.DB.Get then
            return
        end
        local record = BMGAM.DB.Get(guid)
        if not record then
            return
        end
        local listed, list = pcall(GetCategoryList)
        if not listed or type(list) ~= "table" then
            return
        end
        local stats = StatisticSet()
        local categories = {}
        local index = 1
        while list[index] do
            local id = AsNumber(list[index])
            if id and not stats[id] then
                local infoOk, name, parent = pcall(GetCategoryInfo, id)
                name = infoOk and SafeText(name) or nil
                parent = infoOk and AsNumber(parent) or nil
                if name and parent then
                    categories[#categories + 1] = {
                        id = id,
                        name = name,
                        parent = parent,
                        order = CategoryOrder(id),
                    }
                end
            end
            index = index + 1
        end
        categories = DropStatistics(categories, stats)
        local kept = {}
        local keepIndex = 1
        while categories[keepIndex] do
            kept[categories[keepIndex].id] = true
            keepIndex = keepIndex + 1
        end
        local rows = {}
        local seen = {}
        local catIndex = 1
        while categories[catIndex] do
            local categoryID = categories[catIndex].id
            local total = 0
            if type(GetCategoryNumAchievements) == "function" then
                local countOk, count = pcall(GetCategoryNumAchievements, categoryID, true)
                if not countOk then
                    countOk, count = pcall(GetCategoryNumAchievements, categoryID)
                end
                if countOk then
                    total = AsNumber(count) or 0
                end
            end
            local step = 1
            while step <= total do
                local achOk, achId = pcall(GetAchievementInfo, categoryID, step)
                achId = achOk and AsNumber(achId) or nil
                if achId then
                    local series = Series(achId)
                    local seriesIndex = 1
                    if not series[1] then
                        series[1] = achId
                    end
                    local seriesCount = 0
                    while series[seriesCount + 1] do
                        seriesCount = seriesCount + 1
                    end
                    while series[seriesIndex] do
                        local root = nil
                        local stepNo = nil
                        if seriesCount > 1 then
                            root = series[1]
                            stepNo = seriesIndex
                        end
                        AddAchievement(series[seriesIndex], categoryID, rows, seen, kept, stats, root, stepNo)
                        seriesIndex = seriesIndex + 1
                    end
                end
                step = step + 1
            end
            catIndex = catIndex + 1
        end
        local achievementPack = {
            scanned = true,
            scannedAt = time(),
            categories = categories,
            rows = rows,
        }
        if BMGAM.Store and BMGAM.Store.Achievements then
            BMGAM.Store.Achievements(record, achievementPack)
        else
            record.achievements = achievementPack
        end
    end
end

do
    local namePump = nil
    local pumpAt = 1

    local function Flag(value)
        local ok, result = pcall(function()
            return value == true or value == 1
        end)
        return ok and result == true
    end

    local function IconValue(value)
        local number = AsNumber(value)
        if number and number > 0 then
            return number
        end
        local text = SafeText(value)
        if text and text ~= "" and text ~= "0" then
            return text
        end
        return nil
    end

    local function SaveChecks(countFunc, getFunc)
        local saved = {}
        if type(countFunc) ~= "function" or type(getFunc) ~= "function" then
            return saved
        end
        local ok, count = pcall(countFunc)
        count = ok and AsNumber(count) or 0
        if not count or count < 1 then
            return saved
        end
        local index = 1
        while index <= count do
            local checkedOk, checked = pcall(getFunc, index)
            if checkedOk then
                saved[index] = checked
            end
            index = index + 1
        end
        return saved
    end

    local function RestoreChecks(saved, setFunc)
        if type(setFunc) ~= "function" then
            return
        end
        local index = 1
        while saved[index] ~= nil do
            pcall(setFunc, index, saved[index])
            index = index + 1
        end
    end

    local function AddRow(rows, entry)
        if type(entry.name) ~= "string" or entry.name == "" then
            return nil
        end
        if type(entry.source) ~= "string" then
            entry.source = ""
        end
        if string.len(entry.source) > 400 then
            entry.source = string.sub(entry.source, 1, 400)
        end
        rows[#rows + 1] = entry
        return entry
    end

    local function QueueName(itemID, row)
        if not itemID or not row then
            return
        end
        if not namePump then
            namePump = {}
        end
        namePump[#namePump + 1] = { itemID = itemID, row = row }
    end

    local function PumpNames()
        if not namePump or not namePump[pumpAt] then
            namePump = nil
            pumpAt = 1
            return
        end
        local asked = 0
        local filled = 0
        while namePump[pumpAt] and asked < 80 do
            local entry = namePump[pumpAt]
            local name = nil
            if C_Item and type(C_Item.GetItemNameByID) == "function" then
                local ok, text = pcall(C_Item.GetItemNameByID, entry.itemID)
                name = ok and SafeText(text) or nil
            end
            if name then
                entry.row.name = name
                filled = filled + 1
            elseif C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                pcall(C_Item.RequestLoadItemDataByID, entry.itemID)
                asked = asked + 1
            end
            pumpAt = pumpAt + 1
        end
        if filled > 0 and BMGAM.Window and BMGAM.Window.tab == "collections" and BMGAM.Window.Refresh then
            BMGAM.Window.Refresh()
        end
        if namePump[pumpAt] and C_Timer and C_Timer.After then
            C_Timer.After(0.4, PumpNames)
        else
            namePump = nil
            pumpAt = 1
        end
    end

    local function ItemSource(itemID)
        if not itemID or not C_TooltipInfo or type(C_TooltipInfo.GetItemByID) ~= "function" then
            return ""
        end
        local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
        if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then
            return ""
        end
        if TooltipUtil and TooltipUtil.SurfaceArgs then
            pcall(TooltipUtil.SurfaceArgs, data)
        end
        local parts = {}
        local index = 2
        while data.lines[index] and #parts < 2 do
            local textOk, text = pcall(LineText, data.lines[index])
            if textOk and text and text ~= "" then
                parts[#parts + 1] = text
            end
            index = index + 1
        end
        if not parts[1] then
            return ""
        end
        return table.concat(parts, " ")
    end

    local sourceNames = nil
    local function SourceName(sourceType)
        local number = AsNumber(sourceType)
        if not number then
            return ""
        end
        if not sourceNames then
            sourceNames = {}
            local enum = Enum and Enum.TransmogSource
            if type(enum) == "table" then
                for key, value in pairs(enum) do
                    if type(key) == "string" and type(value) == "number" then
                        local words = string.lower(key)
                        words = string.gsub(words, "_", " ")
                        words = string.upper(string.sub(words, 1, 1)) .. string.sub(words, 2)
                        sourceNames[value] = words
                    end
                end
            end
        end
        return sourceNames[number] or ""
    end

    local function ReadMounts(rows)
        if not C_MountJournal or type(C_MountJournal.GetMountIDs) ~= "function" or type(C_MountJournal.GetMountInfoByID) ~= "function" then
            return false
        end
        local ok, ids = pcall(C_MountJournal.GetMountIDs)
        if not ok or type(ids) ~= "table" then
            return false
        end
        local any = false
        local index = 1
        while ids[index] do
            local mountID = AsNumber(ids[index])
            if mountID then
                local infoOk, name, spellID, icon, _, _, _, _, _, _, hide, collected = pcall(C_MountJournal.GetMountInfoByID, mountID)
                name = infoOk and SafeText(name) or nil
                if name and not Flag(hide) then
                    local source = ""
                    if type(C_MountJournal.GetMountInfoExtraByID) == "function" then
                        local extraOk, _, _, extraSource = pcall(C_MountJournal.GetMountInfoExtraByID, mountID)
                        if extraOk then
                            source = SafeText(extraSource) or ""
                        end
                    end
                    local row = AddRow(rows, {
                        type = "mount",
                        id = mountID,
                        name = name,
                        icon = infoOk and IconValue(icon) or nil,
                        spellID = infoOk and AsNumber(spellID) or nil,
                        collected = Flag(collected),
                        source = source,
                    })
                    if row then
                        any = true
                    end
                end
            end
            index = index + 1
        end
        return any
    end

    local function ReadPets(rows)
        if not C_PetJournal or type(C_PetJournal.GetNumPets) ~= "function" or type(C_PetJournal.GetPetInfoByIndex) ~= "function" then
            return false
        end
        local collectedFilter = LE_PET_JOURNAL_FILTER_COLLECTED or 1
        local missingFilter = LE_PET_JOURNAL_FILTER_NOT_COLLECTED or 2
        local savedCollected = nil
        local savedMissing = nil
        if type(C_PetJournal.IsFilterChecked) == "function" then
            local ok, value = pcall(C_PetJournal.IsFilterChecked, collectedFilter)
            if ok then
                savedCollected = value
            end
            ok, value = pcall(C_PetJournal.IsFilterChecked, missingFilter)
            if ok then
                savedMissing = value
            end
        end
        local savedSearch = nil
        if type(C_PetJournal.GetSearchFilter) == "function" then
            local ok, text = pcall(C_PetJournal.GetSearchFilter)
            if ok then
                savedSearch = text
            end
        end
        local savedSources = SaveChecks(C_PetJournal.GetNumPetSources, C_PetJournal.IsPetSourceChecked)
        local savedTypes = SaveChecks(C_PetJournal.GetNumPetTypes, C_PetJournal.IsPetTypeChecked)
        if type(C_PetJournal.SetFilterChecked) == "function" then
            pcall(C_PetJournal.SetFilterChecked, collectedFilter, true)
            pcall(C_PetJournal.SetFilterChecked, missingFilter, true)
        end
        if type(C_PetJournal.ClearSearchFilter) == "function" then
            pcall(C_PetJournal.ClearSearchFilter)
        end
        if savedSources[1] ~= nil and type(C_PetJournal.SetAllPetSourcesChecked) == "function" then
            pcall(C_PetJournal.SetAllPetSourcesChecked, true)
        end
        if savedTypes[1] ~= nil and type(C_PetJournal.SetAllPetTypesChecked) == "function" then
            pcall(C_PetJournal.SetAllPetTypesChecked, true)
        end
        local seen = {}
        local any = false
        local countOk, numPets = pcall(C_PetJournal.GetNumPets)
        local limit = countOk and AsNumber(numPets) or nil
        local index = 1
        local misses = 0
        local cap = limit or 4000
        while index <= cap and misses < 20 do
            local infoOk, petID, speciesID, owned, _, _, _, speciesName, icon = pcall(C_PetJournal.GetPetInfoByIndex, index)
            speciesID = infoOk and AsNumber(speciesID) or nil
            local name = infoOk and SafeText(speciesName) or nil
            if not speciesID or not name then
                misses = misses + 1
            else
                misses = 0
                local row = seen[speciesID]
                if not row then
                    row = AddRow(rows, {
                        type = "pet",
                        id = speciesID,
                        name = name,
                        icon = IconValue(icon),
                        collected = Flag(owned),
                        source = "",
                        petID = petID,
                    })
                    if row then
                        seen[speciesID] = row
                        any = true
                    end
                elseif Flag(owned) then
                    row.collected = true
                    row.petID = petID
                end
            end
            index = index + 1
        end
        local speciesID, row = next(seen)
        while speciesID do
            if type(C_PetJournal.GetPetInfoBySpeciesID) == "function" then
                local sourceOk, _, _, _, _, sourceText = pcall(C_PetJournal.GetPetInfoBySpeciesID, speciesID)
                if sourceOk then
                    row.source = SafeText(sourceText) or row.source or ""
                end
            end
            if row.petID and type(C_PetJournal.GetPetStats) == "function" then
                local statsOk, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, rarity = pcall(C_PetJournal.GetPetStats, row.petID)
                local quality = statsOk and AsNumber(rarity) or nil
                if quality and quality > 0 then
                    row.quality = quality - 1
                end
            end
            row.petID = nil
            speciesID, row = next(seen, speciesID)
        end
        if savedCollected ~= nil and type(C_PetJournal.SetFilterChecked) == "function" then
            pcall(C_PetJournal.SetFilterChecked, collectedFilter, savedCollected)
        end
        if savedMissing ~= nil and type(C_PetJournal.SetFilterChecked) == "function" then
            pcall(C_PetJournal.SetFilterChecked, missingFilter, savedMissing)
        end
        if savedSearch ~= nil and type(C_PetJournal.SetSearchFilter) == "function" then
            pcall(C_PetJournal.SetSearchFilter, savedSearch)
        end
        RestoreChecks(savedSources, C_PetJournal.SetPetSourceChecked)
        RestoreChecks(savedTypes, C_PetJournal.SetPetTypeChecked)
        return any
    end

    local function ReadToys(rows)
        if not C_ToyBox or type(C_ToyBox.GetNumFilteredToys) ~= "function" or type(C_ToyBox.GetToyFromIndex) ~= "function" then
            return false
        end
        local savedCollected = nil
        local savedMissing = nil
        local savedUnusable = nil
        local savedSearch = nil
        if type(C_ToyBox.GetCollectedShown) == "function" then
            local ok, value = pcall(C_ToyBox.GetCollectedShown)
            if ok then
                savedCollected = value
            end
        end
        if type(C_ToyBox.GetUncollectedShown) == "function" then
            local ok, value = pcall(C_ToyBox.GetUncollectedShown)
            if ok then
                savedMissing = value
            end
        end
        if type(C_ToyBox.GetUnusableShown) == "function" then
            local ok, value = pcall(C_ToyBox.GetUnusableShown)
            if ok then
                savedUnusable = value
            end
        end
        if type(C_ToyBox.GetFilterString) == "function" then
            local ok, text = pcall(C_ToyBox.GetFilterString)
            if ok then
                savedSearch = text
            end
        end
        local savedSources = SaveChecks(C_ToyBox.GetNumSources, C_ToyBox.IsSourceTypeFilterChecked)
        local savedExpansions = SaveChecks(C_ToyBox.GetNumExpansions, C_ToyBox.IsExpansionTypeFilterChecked)
        if type(C_ToyBox.SetCollectedShown) == "function" then
            pcall(C_ToyBox.SetCollectedShown, true)
        end
        if type(C_ToyBox.SetUncollectedShown) == "function" then
            pcall(C_ToyBox.SetUncollectedShown, true)
        end
        if type(C_ToyBox.SetUnusableShown) == "function" then
            pcall(C_ToyBox.SetUnusableShown, true)
        end
        if type(C_ToyBox.SetFilterString) == "function" then
            pcall(C_ToyBox.SetFilterString, "")
        end
        if savedSources[1] ~= nil and type(C_ToyBox.SetAllSourceTypeFilters) == "function" then
            pcall(C_ToyBox.SetAllSourceTypeFilters, true)
        end
        if savedExpansions[1] ~= nil and type(C_ToyBox.SetAllExpansionTypeFilters) == "function" then
            pcall(C_ToyBox.SetAllExpansionTypeFilters, true)
        end
        local any = false
        local countOk, count = pcall(C_ToyBox.GetNumFilteredToys)
        local limit = countOk and AsNumber(count) or 0
        local index = 1
        while limit and index <= limit do
            local idOk, itemID = pcall(C_ToyBox.GetToyFromIndex, index)
            itemID = idOk and AsNumber(itemID) or nil
            if itemID and type(C_ToyBox.GetToyInfo) == "function" then
                local infoOk, _, name, icon, _, _, quality = pcall(C_ToyBox.GetToyInfo, itemID)
                name = infoOk and SafeText(name) or nil
                local collected = false
                if type(PlayerHasToy) == "function" then
                    local hasOk, has = pcall(PlayerHasToy, itemID)
                    collected = hasOk and Flag(has)
                end
                local row = AddRow(rows, {
                    type = "toy",
                    id = itemID,
                    name = name,
                    icon = infoOk and IconValue(icon) or nil,
                    itemID = itemID,
                    quality = infoOk and AsNumber(quality) or nil,
                    collected = collected,
                    source = ItemSource(itemID),
                })
                if row then
                    any = true
                end
            end
            index = index + 1
        end
        if savedCollected ~= nil and type(C_ToyBox.SetCollectedShown) == "function" then
            pcall(C_ToyBox.SetCollectedShown, savedCollected)
        end
        if savedMissing ~= nil and type(C_ToyBox.SetUncollectedShown) == "function" then
            pcall(C_ToyBox.SetUncollectedShown, savedMissing)
        end
        if savedUnusable ~= nil and type(C_ToyBox.SetUnusableShown) == "function" then
            pcall(C_ToyBox.SetUnusableShown, savedUnusable)
        end
        if savedSearch ~= nil and type(C_ToyBox.SetFilterString) == "function" then
            pcall(C_ToyBox.SetFilterString, savedSearch)
        end
        if type(C_ToyBox.SetSourceTypeFilter) == "function" then
            RestoreChecks(savedSources, C_ToyBox.SetSourceTypeFilter)
        end
        if type(C_ToyBox.SetExpansionTypeFilter) == "function" then
            RestoreChecks(savedExpansions, C_ToyBox.SetExpansionTypeFilter)
        end
        return any
    end

    local function FirstSource(visualID, categoryID)
        if type(C_TransmogCollection.GetAppearanceSources) == "function" then
            local ok, sources = pcall(C_TransmogCollection.GetAppearanceSources, visualID, categoryID)
            if ok and type(sources) == "table" and type(sources[1]) == "table" then
                return sources[1]
            end
        end
        if type(C_TransmogCollection.GetAllAppearanceSources) == "function" then
            local ok, ids = pcall(C_TransmogCollection.GetAllAppearanceSources, visualID)
            if ok and type(ids) == "table" and ids[1] and type(C_TransmogCollection.GetSourceInfo) == "function" then
                local infoOk, info = pcall(C_TransmogCollection.GetSourceInfo, ids[1])
                if infoOk and type(info) == "table" then
                    return info
                end
                return { sourceID = ids[1] }
            end
        end
        return nil
    end

    local function ReadTransmog(rows)
        if not C_TransmogCollection or type(C_TransmogCollection.GetCategoryAppearances) ~= "function" then
            return false
        end
        local categories = {}
        local enum = Enum and Enum.TransmogCollectionType
        if type(enum) == "table" then
            for _, value in pairs(enum) do
                if type(value) == "number" and value > 0 then
                    categories[#categories + 1] = value
                end
            end
        end
        if not categories[1] then
            return false
        end
        local seen = {}
        local any = false
        local catIndex = 1
        while categories[catIndex] do
            local categoryID = categories[catIndex]
            local listOk, appearances = pcall(C_TransmogCollection.GetCategoryAppearances, categoryID)
            if listOk and type(appearances) == "table" then
                local index = 1
                while appearances[index] do
                    local entry = appearances[index]
                    local visualID = nil
                    local collected = false
                    local hidden = false
                    if type(entry) == "table" then
                        visualID = AsNumber(entry.visualID or entry.appearanceID)
                        collected = Flag(entry.isCollected)
                        hidden = Flag(entry.isHideVisual)
                    else
                        visualID = AsNumber(entry)
                    end
                    if visualID and not hidden and not seen[visualID] then
                        seen[visualID] = true
                        local source = FirstSource(visualID, categoryID)
                        local itemID = source and AsNumber(source.itemID) or nil
                        local name = source and SafeText(source.name) or nil
                        if not name and itemID and C_Item and type(C_Item.GetItemNameByID) == "function" then
                            local nameOk, text = pcall(C_Item.GetItemNameByID, itemID)
                            name = nameOk and SafeText(text) or nil
                        end
                        local icon = source and IconValue(source.icon) or nil
                        if not icon and source and source.sourceID and type(C_TransmogCollection.GetSourceIcon) == "function" then
                            local iconOk, texture = pcall(C_TransmogCollection.GetSourceIcon, source.sourceID)
                            icon = iconOk and IconValue(texture) or nil
                        end
                        if not icon and itemID and C_Item and type(C_Item.GetItemIconByID) == "function" then
                            local iconOk, texture = pcall(C_Item.GetItemIconByID, itemID)
                            icon = iconOk and IconValue(texture) or nil
                        end
                        local how = SourceName(source and source.sourceType)
                        local row = AddRow(rows, {
                            type = "transmog",
                            id = visualID,
                            name = name or "",
                            icon = icon,
                            itemID = itemID,
                            quality = source and AsNumber(source.quality) or nil,
                            collected = collected or (source and Flag(source.isCollected)) or false,
                            source = how,
                        })
                        if not name and itemID then
                            local placeholder = {
                                type = "transmog",
                                id = visualID,
                                name = "",
                                icon = icon,
                                itemID = itemID,
                                quality = source and AsNumber(source.quality) or nil,
                                collected = collected or (source and Flag(source.isCollected)) or false,
                                source = how,
                            }
                            rows[#rows + 1] = placeholder
                            QueueName(itemID, placeholder)
                            any = true
                        elseif row then
                            any = true
                        end
                    end
                    index = index + 1
                end
            end
            catIndex = catIndex + 1
        end
        return any
    end

    local function ReadSets(rows)
        if not C_TransmogSets then
            return false
        end
        local sets = nil
        if type(C_TransmogSets.GetBaseSets) == "function" then
            local ok, result = pcall(C_TransmogSets.GetBaseSets)
            if ok and type(result) == "table" then
                sets = result
            end
        end
        if not sets and type(C_TransmogSets.GetAllSets) == "function" then
            local ok, result = pcall(C_TransmogSets.GetAllSets)
            if ok and type(result) == "table" then
                sets = result
            end
        end
        if type(sets) ~= "table" then
            return false
        end
        local any = false
        local index = 1
        while sets[index] do
            local info = sets[index]
            if type(info) == "number" and type(C_TransmogSets.GetSetInfo) == "function" then
                local infoOk, result = pcall(C_TransmogSets.GetSetInfo, info)
                if infoOk and type(result) == "table" then
                    info = result
                    info.setID = info.setID or sets[index]
                end
            end
            if type(info) == "table" then
                local name = SafeText(info.name)
                local setID = AsNumber(info.setID) or index
                local how = SafeText(info.label) or ""
                local description = SafeText(info.description)
                if description and description ~= "" then
                    if how ~= "" then
                        how = how .. ". " .. description
                    else
                        how = description
                    end
                end
                local collected = Flag(info.collected)
                local icon = IconValue(info.icon)
                if not collected and type(C_TransmogSets.GetSetPrimaryAppearances) == "function" then
                    local appOk, appearances = pcall(C_TransmogSets.GetSetPrimaryAppearances, setID)
                    if appOk and type(appearances) == "table" and appearances[1] then
                        collected = true
                        local piece = 1
                        while appearances[piece] do
                            if not Flag(appearances[piece].collected) then
                                collected = false
                            end
                            piece = piece + 1
                        end
                    end
                end
                local row = AddRow(rows, {
                    type = "set",
                    id = setID,
                    name = name,
                    icon = icon,
                    collected = collected,
                    source = how,
                })
                if row then
                    any = true
                end
            end
            index = index + 1
        end
        return any
    end

    local function DecorEntry(info, rows)
        if type(info) ~= "table" then
            return false
        end
        local name = SafeText(info.name)
        local row = AddRow(rows, {
            type = "decor",
            id = AsNumber(info.entryID or info.itemID or info.id) or name,
            name = name,
            icon = IconValue(info.icon or info.iconFileID),
            itemID = AsNumber(info.itemID),
            quality = AsNumber(info.quality),
            collected = Flag(info.isCollected or info.collected),
            source = SafeText(info.sourceText or info.source or info.description) or "",
        })
        return row ~= nil
    end

    local function ReadDecor(rows)
        local api = C_HousingCatalog
        if type(api) ~= "table" or type(api.SearchCatalog) ~= "function" then
            return false
        end
        local before = #rows
        local ok, result = pcall(api.SearchCatalog, { showCollected = true, showUncollected = true })
        if not ok or type(result) ~= "table" then
            ok, result = pcall(api.SearchCatalog, api, { showCollected = true, showUncollected = true })
        end
        if not ok or type(result) ~= "table" then
            return false
        end
        local index = 1
        while result[index] do
            local entry = result[index]
            if type(entry) == "number" and type(api.GetCatalogEntryInfo) == "function" then
                local infoOk, info = pcall(api.GetCatalogEntryInfo, entry)
                if infoOk then
                    DecorEntry(info, rows)
                end
            else
                DecorEntry(entry, rows)
            end
            index = index + 1
        end
        return #rows > before
    end

    local function SpellTitle(spellID)
        if C_Spell and type(C_Spell.GetSpellName) == "function" then
            local ok, name = pcall(C_Spell.GetSpellName, spellID)
            name = ok and SafeText(name) or nil
            if name then
                return name
            end
        end
        if C_Spell and type(C_Spell.GetSpellInfo) == "function" then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and type(info) == "table" then
                local name = SafeText(info.name)
                if name then
                    return name
                end
            end
        end
        if type(GetSpellInfo) == "function" then
            local ok, name = pcall(GetSpellInfo, spellID)
            return ok and SafeText(name) or nil
        end
        return nil
    end

    local function SpellIcon(spellID)
        if C_Spell and type(C_Spell.GetSpellTexture) == "function" then
            local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
            return ok and IconValue(texture) or nil
        end
        return nil
    end

    local function KnownSpell(spellID)
        if C_SpellBook and type(C_SpellBook.IsSpellKnown) == "function" then
            local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
            if ok and Flag(known) then
                return true
            end
        end
        if type(IsPlayerSpell) == "function" then
            local ok, known = pcall(IsPlayerSpell, spellID)
            if ok and Flag(known) then
                return true
            end
        end
        return false
    end

    local function SpellSource(spellID)
        if C_Spell and type(C_Spell.GetSpellDescription) == "function" then
            local ok, text = pcall(C_Spell.GetSpellDescription, spellID)
            return ok and SafeText(text) or ""
        end
        return ""
    end

    local function ItemTitle(itemID)
        if C_Item and type(C_Item.GetItemNameByID) == "function" then
            local ok, name = pcall(C_Item.GetItemNameByID, itemID)
            return ok and SafeText(name) or nil
        end
        return nil
    end

    local function ItemIcon(itemID)
        if C_Item and type(C_Item.GetItemIconByID) == "function" then
            local ok, icon = pcall(C_Item.GetItemIconByID, itemID)
            return ok and IconValue(icon) or nil
        end
        return nil
    end

    local function ItemQuality(itemID)
        if C_Item and type(C_Item.GetItemQualityByID) == "function" then
            local ok, quality = pcall(C_Item.GetItemQualityByID, itemID)
            return ok and AsNumber(quality) or nil
        end
        return nil
    end

    local function QuestDone(questID)
        if not questID or not C_QuestLog then
            return false
        end
        if type(C_QuestLog.IsQuestFlaggedCompleted) == "function" then
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
            if ok and Flag(done) then
                return true
            end
        end
        if type(C_QuestLog.IsQuestFlaggedCompletedOnAccount) == "function" then
            local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompletedOnAccount, questID)
            if ok and Flag(done) then
                return true
            end
        end
        return false
    end

    local function RaceKnown(races)
        if type(races) ~= "table" or type(UnitRace) ~= "function" then
            return false
        end
        local ok, _, file = pcall(UnitRace, "player")
        file = ok and SafeText(file) or nil
        if not file then
            return false
        end
        local index = 1
        while races[index] do
            if races[index] == file then
                return true
            end
            index = index + 1
        end
        return false
    end

    local function AppearanceKnown(itemIDs)
        if type(itemIDs) ~= "table" or not C_TransmogCollection or type(C_TransmogCollection.PlayerHasTransmog) ~= "function" then
            return false
        end
        local index = 1
        while itemIDs[index] do
            local ok, has = pcall(C_TransmogCollection.PlayerHasTransmog, itemIDs[index])
            if ok and Flag(has) then
                return true
            end
            index = index + 1
        end
        return false
    end

    local function ReadManuscripts(rows)
        local catalog = BMGAM_Manuscripts
        if type(catalog) ~= "table" then
            return
        end
        local classFile = nil
        if type(UnitClass) == "function" then
            local classOk, _, file = pcall(UnitClass, "player")
            classFile = classOk and SafeText(file) or nil
        end
        local lists = { catalog.druid, catalog.hunter }
        local listIndex = 1
        while lists[listIndex] do
            local list = lists[listIndex]
            local index = 1
            while type(list) == "table" and list[index] do
            local entry = list[index]
            local collected = false
            if entry.questID and QuestDone(entry.questID) then
                collected = true
            elseif type(entry.transmog) == "table" and AppearanceKnown(entry.transmog) then
                collected = true
            elseif not entry.questID and type(entry.transmog) ~= "table" and entry.spellID and KnownSpell(entry.spellID) then
                collected = true
            end
            if not collected and classFile == "HUNTER" and RaceKnown(entry.races) then
                collected = true
            end
            local clientName = nil
            if entry.itemID then
                clientName = ItemTitle(entry.itemID)
            end
            local name = clientName
            if not name and entry.spellID then
                name = SpellTitle(entry.spellID)
            end
            if not name then
                name = SafeText(entry.name) or ""
            end
            local source = ""
            if type(entry.source) == "string" and entry.source ~= "" then
                source = entry.source
            elseif entry.itemID then
                source = ItemSource(entry.itemID)
            end
            if source == "" and entry.spellID then
                source = SpellSource(entry.spellID)
            end
            if source == "" and type(entry.source) == "string" then
                source = entry.source
            end
            local icon = nil
            if entry.itemID then
                icon = ItemIcon(entry.itemID)
            end
            if not icon and entry.spellID then
                icon = SpellIcon(entry.spellID)
            end
            local row = {
                type = "manuscript",
                id = entry.itemID or entry.spellID,
                name = name,
                icon = icon,
                itemID = entry.itemID,
                spellID = entry.spellID,
                quality = entry.itemID and ItemQuality(entry.itemID) or nil,
                collected = collected,
                source = source,
                section = entry.section,
                sectionOrder = entry.sectionOrder or 0,
            }
            if name ~= "" then
                AddRow(rows, row)
            else
                rows[#rows + 1] = row
            end
            if entry.itemID and not clientName then
                QueueName(entry.itemID, row)
            end
            index = index + 1
            end
            listIndex = listIndex + 1
        end
    end

    function Scan.ReadCollections()
        local guid = UnitGUID("player")
        local record = guid and BMGAM.DB.Get(guid) or nil
        if not record then
            return
        end
        local rows = {}
        pcall(ReadMounts, rows)
        pcall(ReadManuscripts, rows)
        pcall(ReadPets, rows)
        pcall(ReadTransmog, rows)
        pcall(ReadSets, rows)
        pcall(ReadToys, rows)
        pcall(ReadDecor, rows)
        local accountItems = {}
        local ownItems = {}
        local rowIndex = 1
        while rows[rowIndex] do
            local row = rows[rowIndex]
            if type(row) == "table" and row.type == "manuscript" then
                ownItems[#ownItems + 1] = row
            elseif type(row) == "table" then
                accountItems[#accountItems + 1] = row
            end
            rowIndex = rowIndex + 1
        end
        if BMGAM.Store and BMGAM.Store.SaveCollections then
            BMGAM.Store.SaveCollections(guid, accountItems, ownItems)
            record.collections = nil
        else
            record.collections = {
                scanned = true,
                scannedAt = time(),
                items = rows,
            }
        end
        if namePump and namePump[1] and C_Timer and C_Timer.After then
            pumpAt = 1
            C_Timer.After(0.4, PumpNames)
        end
    end
end
