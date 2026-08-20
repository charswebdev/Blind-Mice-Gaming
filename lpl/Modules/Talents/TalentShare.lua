local addonName, LPL = ...

LPL.TalentShare = {}

local BIT_WIDTH_HEADER_VERSION = 8
local BIT_WIDTH_SPEC_ID = 16
local BIT_WIDTH_RANKS_PURCHASED = 6

local VIEW_CONFIG_ID = Constants and Constants.TraitConsts and Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID or -3

local function GetLib()
    return LibStub and LibStub:GetLibrary("LibTalentTree-1.0", true)
end

local function GetCachedNodeInfo(lib, nodeID)
    if not lib or not nodeID then
        return nil
    end
    local nodeInfo
    if lib.GetLibNodeInfo then
        nodeInfo = lib:GetLibNodeInfo(nodeID)
    end
    if not nodeInfo or not nodeInfo.ID or nodeInfo.ID == 0 then
        nodeInfo = lib:GetNodeInfo(nodeID)
    end
    if nodeInfo then
        nodeInfo.ID = nodeID
    end
    return nodeInfo
end

local function Trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or text
end

local function FormatTableKey(key)
    if type(key) == "number" then
        return "[" .. key .. "]"
    end
    if type(key) == "string" then
        if key:match("^[%a_][%w_]*$") then
            return key
        end
        return "[" .. string.format("%q", key) .. "]"
    end
    error("Invalid key type in export")
end

local function QuoteNumericTableKeys(text)
    if type(text) ~= "string" then
        return text
    end
    return text:gsub("([{,])(%d+)=", "%1[%2]=")
end

local function StringToTable(text)
    if type(text) ~= "string" or text:sub(1, 1) ~= "{" then
        return false, "Invalid share string."
    end
    text = QuoteNumericTableKeys(text)
    local func, err = loadstring("return " .. text, "LPLImport")
    if not func and load then
        func, err = load("return " .. text, "LPLImport", "t", {})
    end
    if not func then
        return false, err or "Invalid share string."
    end
    if setfenv then
        setfenv(func, {})
    end
    return pcall(func)
end

local function TableToString(tbl, visited)
    visited = visited or {}
    if visited[tbl] then
        error("Circular table in export")
    end
    visited[tbl] = true

    local parts = {}
    for key, value in pairs(tbl) do
        local keyText = FormatTableKey(key)

        local valueText
        if type(value) == "table" then
            valueText = TableToString(value, visited)
        elseif type(value) == "string" then
            valueText = string.format("%q", value)
        elseif type(value) == "number" or type(value) == "boolean" then
            valueText = tostring(value)
        else
            error("Invalid value type in export")
        end
        parts[#parts + 1] = keyText .. "=" .. valueText
    end
    table.sort(parts)
    return "{" .. table.concat(parts, ",") .. "}"
end

local Base64Encode, Base64Decode
do
    local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    function Base64Encode(data)
        return ((data:gsub(".", function(char)
            local bits = ""
            local byte = char:byte()
            for i = 8, 1, -1 do
                bits = bits .. (byte % (2 ^ i) - byte % (2 ^ (i - 1)) > 0 and "1" or "0")
            end
            return bits
        end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(group)
            if #group < 6 then
                return ""
            end
            local value = 0
            for i = 1, 6 do
                value = value + ((group:sub(i, i) == "1") and (2 ^ (6 - i)) or 0)
            end
            return alphabet:sub(value + 1, value + 1)
        end) .. ({ "", "==", "=" })[#data % 3 + 1])
    end

    function Base64Decode(data)
        data = string.gsub(data, "[^" .. alphabet .. "=]", "")
        return (data:gsub(".", function(char)
            if char == "=" then
                return ""
            end
            local position = alphabet:find(char, 1, true)
            if not position then
                return ""
            end
            local bits = ""
            local value = position - 1
            for i = 6, 1, -1 do
                bits = bits .. (value % (2 ^ i) - value % (2 ^ (i - 1)) > 0 and "1" or "0")
            end
            return bits
        end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(group)
            if #group ~= 8 then
                return ""
            end
            local value = 0
            for i = 1, 8 do
                value = value + ((group:sub(i, i) == "1") and (2 ^ (8 - i)) or 0)
            end
            return string.char(value)
        end))
    end
end

local function Encode(content, format)
    format = format or "BN"
    if #format == 1 then
        if format == "N" then
            return "N" .. content
        elseif format == "B" then
            return "B" .. Base64Encode(content)
        end
        error("Unsupported export format")
    end
    local prefix, rest = format:match("^([A-Z])([A-Z]*)$")
    return Encode(Encode(content, rest), prefix)
end

local function Decode(content)
    if type(content) ~= "string" then
        return false, "Invalid share string."
    end
    local format, body = content:match("^([A-Z])(.*)$")
    if format == "N" then
        return true, body
    elseif format == "B" then
        return Decode(Base64Decode(body))
    end
    return false, "Unsupported share string format."
end

local function ReadLoadoutHeader(importStream)
    local headerBitWidth = BIT_WIDTH_HEADER_VERSION + BIT_WIDTH_SPEC_ID + 128
    if importStream:GetNumberOfBits() < headerBitWidth then
        return false
    end
    local serializationVersion = importStream:ExtractValue(BIT_WIDTH_HEADER_VERSION)
    local specID = importStream:ExtractValue(BIT_WIDTH_SPEC_ID)
    local treeHash = {}
    for i = 1, 16 do
        treeHash[i] = importStream:ExtractValue(8)
    end
    return true, serializationVersion, specID, treeHash
end

local function CopyTreeNodes(treeID)
    local nodes = C_Traits.GetTreeNodes(treeID)
    if not nodes then
        return {}
    end
    local copy = {}
    for _, nodeID in ipairs(nodes) do
        copy[#copy + 1] = nodeID
    end
    return copy
end

-- Blizzard V2 loadouts are positional: bit n describes C_Traits.GetTreeNodes(treeID)[n].
-- TLM, ZugZug, PeaversTalents, and TalentTreeTweaks all use that live ipairs order.
-- Sorting or remapping those bits onto another ID list is what produced 15/29/10 builds.
local function ExtractBits(importStream, width)
    local ok, value = pcall(importStream.ExtractValue, importStream, width)
    if not ok then
        return 0, false
    end
    return value or 0, true
end

local function ReadLoadoutContent(importStream, treeID)
    local results = {}
    local treeNodes = CopyTreeNodes(treeID)
    for i, nodeID in ipairs(treeNodes) do
        local selectedValue, ok = ExtractBits(importStream, 1)
        if not ok then
            break
        end

        local isNodeSelected = selectedValue == 1
        local isNodePurchased = false
        local isPartiallyRanked = false
        local partialRanksPurchased = 0
        local isChoiceNode = false
        local choiceNodeSelection = 0

        if isNodeSelected then
            local purchasedValue
            purchasedValue, ok = ExtractBits(importStream, 1)
            if not ok then
                break
            end
            isNodePurchased = purchasedValue == 1
            if isNodePurchased then
                local partialValue
                partialValue, ok = ExtractBits(importStream, 1)
                if not ok then
                    break
                end
                isPartiallyRanked = partialValue == 1
                if isPartiallyRanked then
                    partialRanksPurchased, ok = ExtractBits(importStream, BIT_WIDTH_RANKS_PURCHASED)
                    if not ok then
                        break
                    end
                end
                local choiceValue
                choiceValue, ok = ExtractBits(importStream, 1)
                if not ok then
                    break
                end
                isChoiceNode = choiceValue == 1
                if isChoiceNode then
                    choiceNodeSelection, ok = ExtractBits(importStream, 2)
                    if not ok then
                        break
                    end
                end
            end
        end

        results[i] = {
            nodeID = nodeID,
            isNodeSelected = isNodeSelected,
            isNodeGranted = isNodeSelected and not isNodePurchased,
            isNodePurchased = isNodePurchased,
            isPartiallyRanked = isPartiallyRanked,
            partialRanksPurchased = partialRanksPurchased,
            isChoiceNode = isChoiceNode,
            choiceNodeSelection = choiceNodeSelection + 1,
        }
    end
    return results
end

local function GetEntryIndexFromNodeInfo(nodeInfo, entryID)
    if not nodeInfo or not nodeInfo.entryIDs then
        return 0
    end

    entryID = entryID and tonumber(entryID)
    if entryID then
        for index, candidateEntryID in ipairs(nodeInfo.entryIDs) do
            if candidateEntryID == entryID then
                return index
            end
        end
    end

    if #nodeInfo.entryIDs == 1 then
        return 1
    end

    return 0
end

local function NormalizeStoredNode(value)
    if type(value) == "number" then
        if value > 0 then
            return value, nil
        end
        return nil, nil
    end
    if type(value) == "table" then
        local rank = tonumber(value.rank or value.ranks or value[1])
        local entryID = tonumber(value.entryID or value.entryId)
        if rank and rank > 0 then
            return rank, entryID
        end
    end
    return nil, nil
end

local function ResolveSelectionEntryID(nodeID, entryID)
    entryID = entryID and tonumber(entryID)
    if entryID and entryID > 0 then
        return entryID
    end

    local lib = GetLib()
    if lib then
        local nodeInfo = GetCachedNodeInfo(lib, nodeID)
        if nodeInfo and nodeInfo.entryIDs and nodeInfo.entryIDs[1] then
            return nodeInfo.entryIDs[1]
        end
    end

    return 0
end

local function BuildNodePurchaseMap(specID, subTreeID, nodes, extraEntries)
    local lib = GetLib()
    local purchaseMap = {}

    local function AddPurchase(nodeID, rank, entryID)
        nodeID = tonumber(nodeID)
        rank = tonumber(rank)
        if not nodeID or not rank or rank <= 0 then
            return
        end
        if lib and lib.IsNodeGrantedForSpec and lib:IsNodeGrantedForSpec(specID, nodeID) then
            return
        end
        purchaseMap[nodeID] = {
            rank = rank,
            entryID = ResolveSelectionEntryID(nodeID, entryID),
        }
    end

    for rawNodeID, value in pairs(nodes or {}) do
        local rank, entryID = NormalizeStoredNode(value)
        if rank then
            AddPurchase(rawNodeID, rank, entryID)
        end
    end

    if type(extraEntries) == "table" then
        for rawNodeID, entryID in pairs(extraEntries) do
            local nodeID = tonumber(rawNodeID)
            entryID = tonumber(entryID)
            if nodeID and entryID then
                if purchaseMap[nodeID] then
                    purchaseMap[nodeID].entryID = entryID
                else
                    AddPurchase(nodeID, 1, entryID)
                end
            end
        end
    end

    if subTreeID and lib and lib.GetSubTreeSelectionNodeIDAndEntryIDBySpecID then
        local heroNodeID, heroEntryID = lib:GetSubTreeSelectionNodeIDAndEntryIDBySpecID(specID, subTreeID)
        if heroNodeID and heroEntryID then
            AddPurchase(heroNodeID, 1, heroEntryID)
        end
    end

    return purchaseMap
end

local function WriteLoadoutContentFromBuild(exportStream, specID, treeID, nodes, extraEntries, subTreeID)
    local lib = GetLib()
    local purchaseMap = BuildNodePurchaseMap(specID, subTreeID, nodes, extraEntries)

    for _, nodeID in ipairs(CopyTreeNodes(treeID)) do
        local nodeInfo = lib and GetCachedNodeInfo(lib, nodeID)
        local purchase = purchaseMap[nodeID]
        local isNodeGranted = lib and lib.IsNodeGrantedForSpec and lib:IsNodeGrantedForSpec(specID, nodeID)

        exportStream:AddValue(1, (purchase or isNodeGranted) and 1 or 0)
        if purchase or isNodeGranted then
            exportStream:AddValue(1, purchase and 1 or 0)
        end
        if purchase then
            local rank = purchase.rank
            local entryID = purchase.entryID
            local maxRanks = 1
            if nodeInfo then
                maxRanks = nodeInfo.totalMaxRanks or nodeInfo.maxRanks or 1
            end
            local isPartiallyRanked = rank ~= maxRanks
            local isChoiceNode = nodeInfo
                and (nodeInfo.type == Enum.TraitNodeType.Selection
                    or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection
                    or nodeInfo.isSubTreeSelection)

            exportStream:AddValue(1, isPartiallyRanked and 1 or 0)
            if isPartiallyRanked then
                exportStream:AddValue(BIT_WIDTH_RANKS_PURCHASED, rank)
            end
            exportStream:AddValue(1, isChoiceNode and 1 or 0)
            if isChoiceNode then
                local entryIndex = GetEntryIndexFromNodeInfo(nodeInfo, entryID)
                if entryIndex <= 0 or entryIndex > 4 then
                    return false, string.format(
                        "Could not export node %s (missing or invalid choice selection).",
                        tostring(nodeID)
                    )
                end
                exportStream:AddValue(2, entryIndex - 1)
            end
        end
    end

    return true
end

local function GetTreeIDForSpec(specID, classID)
    local lib = GetLib()
    if lib and lib.GetClassTreeID then
        classID = classID
            or (LPL.TalentTree and LPL.TalentTree.GetClassIDForSpec and LPL.TalentTree:GetClassIDForSpec(specID))
        if classID then
            local treeID = lib:GetClassTreeID(classID)
            if treeID then
                return treeID
            end
        end
    end

    if C_ClassTalents and C_ClassTalents.GetTraitTreeForSpec then
        return C_ClassTalents.GetTraitTreeForSpec(specID)
    end

    return nil
end

local function WriteLoadoutHeader(exportStream, serializationVersion, specID, treeHash)
    exportStream:AddValue(BIT_WIDTH_HEADER_VERSION, serializationVersion)
    exportStream:AddValue(BIT_WIDTH_SPEC_ID, specID)
    for i = 1, 16 do
        exportStream:AddValue(8, treeHash[i] or 0)
    end
end

local function EnsureTalentExportAPIs()
    if ExportUtil and C_Traits and C_Traits.GetTreeNodes and C_Traits.GetTreeHash then
        return true
    end

    local addons = { "Blizzard_PlayerSpells", "Blizzard_ClassTalentUI" }
    for _, addonName in ipairs(addons) do
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, addonName)
        elseif LoadAddOn then
            pcall(LoadAddOn, addonName)
        end
    end

    return ExportUtil ~= nil
        and C_Traits ~= nil
        and C_Traits.GetTreeNodes ~= nil
        and C_Traits.GetTreeHash ~= nil
end

local function EncodeLPLExportString(specID, classID, subTreeID, level, name, nodes)
    local payload = {
        type = "lpltalents",
        version = 1,
        name = name,
        classID = classID,
        specID = specID,
        subTreeID = subTreeID,
        level = level,
        nodes = LPL.BuildStore:NormalizeNodesForStorage(nodes),
    }
    return Encode(TableToString(payload), "BN")
end

local function ExportBlizzardLoadout(specID, subTreeID, level, nodes, extraEntries, classID)
    if not EnsureTalentExportAPIs() then
        return nil, "Talent export APIs are unavailable."
    end
    if not specID or not GetSpecializationInfoByID(specID) then
        return nil, "Invalid specialization."
    end

    local treeID = GetTreeIDForSpec(specID, classID)
    if not treeID then
        return nil, "Could not resolve talent tree."
    end

    local purchaseMap = BuildNodePurchaseMap(specID, subTreeID, nodes, extraEntries)
    local hasPurchases = false
    for _ in pairs(purchaseMap) do
        hasPurchases = true
        break
    end
    if not hasPurchases then
        return nil, "Nothing to export."
    end

    local exportStream = ExportUtil.MakeExportDataStream()
    local serializationVersion = C_Traits.GetLoadoutSerializationVersion()
    local treeHash = C_Traits.GetTreeHash(treeID)
    WriteLoadoutHeader(exportStream, serializationVersion, specID, treeHash)

    local ok, err = WriteLoadoutContentFromBuild(exportStream, specID, treeID, nodes, extraEntries, subTreeID)
    if not ok then
        return nil, err or "Could not encode export string."
    end

    local exportString = exportStream:GetExportString()
    if not exportString or exportString == "" then
        return nil, "Could not generate export string."
    end

    return exportString
end

local function GetImportedRanks(nodeInfo, indexInfo)
    if indexInfo.isPartiallyRanked then
        return indexInfo.partialRanksPurchased or 1
    end
    if nodeInfo.totalMaxRanks and nodeInfo.totalMaxRanks > 0 then
        return nodeInfo.totalMaxRanks
    end
    return nodeInfo.maxRanks or 1
end

local function ConvertBlizzardContentToNodes(configID, treeID, loadoutContent, specID, preferredSubTreeID)
    local nodes = {}
    local subTreeID = preferredSubTreeID
    local lib = GetLib()

    local function ResolveImportNodeInfo(nodeID)
        local nodeInfo = GetCachedNodeInfo(lib, nodeID)
        if nodeInfo and nodeInfo.ID and nodeInfo.ID ~= 0 then
            return nodeInfo
        end
        nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
        if nodeInfo then
            nodeInfo.ID = nodeID
            if nodeInfo.ID ~= 0 then
                return nodeInfo
            end
        end
        return GetCachedNodeInfo(lib, nodeID)
    end

    local function ResolveEntryInfo(entryID)
        if not entryID then
            return nil
        end
        if lib and lib.GetEntryInfo then
            local entryInfo = lib:GetEntryInfo(entryID)
            if entryInfo then
                return entryInfo
            end
        end
        return C_Traits.GetEntryInfo(configID, entryID)
    end

    local function BelongsToImportedSpec(nodeInfo, nodeID)
        if not nodeInfo then
            return false
        end
        if nodeInfo.isSubTreeSelection or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection then
            return false
        end
        if nodeInfo.subTreeID then
            if preferredSubTreeID then
                return nodeInfo.subTreeID == preferredSubTreeID
            end
            if specID and lib and lib.IsNodeVisibleForSpec then
                return lib:IsNodeVisibleForSpec(specID, nodeID)
            end
            return true
        end
        if lib and lib.IsClassNode and lib:IsClassNode(nodeID) then
            return true
        end
        if specID and lib and lib.IsNodeVisibleForSpec then
            return lib:IsNodeVisibleForSpec(specID, nodeID)
        end
        return true
    end

    for _, indexInfo in ipairs(loadoutContent) do
        if indexInfo.isNodePurchased then
            local nodeID = indexInfo.nodeID
            local nodeInfo = ResolveImportNodeInfo(nodeID)
            if nodeInfo then
                local isChoice = nodeInfo.type == Enum.TraitNodeType.Selection
                    or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection
                    or nodeInfo.isSubTreeSelection
                local ranks = GetImportedRanks(nodeInfo, indexInfo)

                if nodeInfo.type == Enum.TraitNodeType.SubTreeSelection or nodeInfo.isSubTreeSelection then
                    local choiceIdx = indexInfo.isChoiceNode and indexInfo.choiceNodeSelection or 1
                    local entryID = nodeInfo.entryIDs and (nodeInfo.entryIDs[choiceIdx] or nodeInfo.entryIDs[1])
                    if entryID then
                        local entryInfo = ResolveEntryInfo(entryID)
                        if entryInfo and entryInfo.subTreeID then
                            subTreeID = entryInfo.subTreeID
                        end
                    end
                elseif BelongsToImportedSpec(nodeInfo, nodeID) then
                    if isChoice and nodeInfo.entryIDs and #nodeInfo.entryIDs > 0 then
                        local choiceIdx = indexInfo.isChoiceNode and indexInfo.choiceNodeSelection or 1
                        local entryID = nodeInfo.entryIDs[choiceIdx] or nodeInfo.entryIDs[1]
                        if entryID then
                            nodes[tostring(nodeID)] = {
                                rank = ranks > 0 and ranks or 1,
                                entryID = entryID,
                            }
                        end
                    else
                        nodes[tostring(nodeID)] = ranks
                    end
                end
            end
        end
    end

    return nodes, subTreeID
end

local function PeekImportedSubTreeID(configID, loadoutContent)
    local lib = GetLib()
    for _, indexInfo in ipairs(loadoutContent) do
        if indexInfo.isNodePurchased then
            local nodeInfo = GetCachedNodeInfo(lib, indexInfo.nodeID)
            if not nodeInfo or not nodeInfo.ID or nodeInfo.ID == 0 then
                nodeInfo = C_Traits.GetNodeInfo(configID, indexInfo.nodeID)
            end
            if nodeInfo and (nodeInfo.type == Enum.TraitNodeType.SubTreeSelection or nodeInfo.isSubTreeSelection) then
                local choiceIdx = indexInfo.isChoiceNode and indexInfo.choiceNodeSelection or nil
                if choiceIdx and nodeInfo.entryIDs and nodeInfo.entryIDs[choiceIdx] then
                    local entryID = nodeInfo.entryIDs[choiceIdx]
                    local entryInfo = (lib and lib.GetEntryInfo and lib:GetEntryInfo(entryID))
                        or C_Traits.GetEntryInfo(configID, entryID)
                    if entryInfo and entryInfo.subTreeID then
                        return entryInfo.subTreeID
                    end
                end
            end
        end
    end
    return nil
end

local function ParseBlizzardExportString(exportString)
    if not ExportUtil or not C_Traits or not C_ClassTalents then
        return nil, "Talent import APIs are unavailable."
    end

    local ok, importStream = pcall(ExportUtil.MakeImportDataStream, exportString)
    if not ok or not importStream then
        return nil, "Failed to decode Blizzard export string."
    end

    local headerValid, serializationVersion, specID = ReadLoadoutHeader(importStream)
    if not headerValid then
        return nil, "Invalid Blizzard export string."
    end

    local liveVersion = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion()
    if liveVersion and serializationVersion ~= liveVersion then
        return nil, "Export string version does not match this game version."
    end
    if not liveVersion and serializationVersion ~= 2 then
        return nil, "Unsupported talent string version."
    end

    if not specID or not GetSpecializationInfoByID(specID) then
        return nil, "Invalid specialization in export string."
    end

    local level = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 90
    C_ClassTalents.InitializeViewLoadout(specID, level)
    C_ClassTalents.ViewLoadout({})

    local classID = LPL.TalentTree:GetClassIDForSpec(specID)
    local treeID = GetTreeIDForSpec(specID, classID) or C_ClassTalents.GetTraitTreeForSpec(specID)
    if not treeID then
        return nil, "Could not resolve talent tree for this specialization."
    end

    local loadoutContent = ReadLoadoutContent(importStream, treeID)
    local peekedHero = PeekImportedSubTreeID(VIEW_CONFIG_ID, loadoutContent)
    if peekedHero and LPL.TalentTree and LPL.TalentTree.ApplyView then
        LPL.TalentTree:ApplyView(classID, specID, peekedHero, level)
    end

    local nodes, subTreeID = ConvertBlizzardContentToNodes(
        VIEW_CONFIG_ID, treeID, loadoutContent, specID, peekedHero
    )
    subTreeID = subTreeID or peekedHero

    local _, specName = GetSpecializationInfoByID(specID)

    return {
        name = specName and (specName .. " Build") or "Imported Build",
        classID = classID,
        specID = specID,
        subTreeID = subTreeID,
        level = level,
        nodes = nodes or {},
    }
end

local function IsSelectionNodeInfo(nodeInfo)
    if not nodeInfo then
        return false
    end
    local nodeType = Enum and Enum.TraitNodeType
    return nodeInfo.isSubTreeSelection == true
        or (nodeType and (nodeInfo.type == nodeType.Selection or nodeInfo.type == nodeType.SubTreeSelection))
end

-- Older dftalents strings stored choice index as a bare number. Current LPL
-- storage uses that same number as rank, including apex/tiered nodes that have
-- several entryIDs. Only rewrite numbers on real choice nodes.
local function ConvertLegacyNodes(rawNodes, specID)
    local lib = GetLib()
    if type(rawNodes) ~= "table" then
        return {}
    end

    local converted = {}
    for rawNodeID, value in pairs(rawNodes) do
        local nodeID = tonumber(rawNodeID)
        if nodeID then
            local nodeInfo = lib and GetCachedNodeInfo(lib, nodeID)
            if type(value) == "table" then
                local rank = tonumber(value.rank or value.ranks or value[1]) or 1
                local entryID = tonumber(value.entryID or value.entryId)
                if entryID then
                    converted[tostring(nodeID)] = {
                        rank = rank,
                        entryID = entryID,
                    }
                elseif rank > 0 then
                    converted[tostring(nodeID)] = rank
                end
            elseif type(value) == "number" and value > 0 then
                if IsSelectionNodeInfo(nodeInfo) and nodeInfo.entryIDs and nodeInfo.entryIDs[value] then
                    converted[tostring(nodeID)] = {
                        rank = 1,
                        entryID = nodeInfo.entryIDs[value],
                    }
                else
                    converted[tostring(nodeID)] = math.floor(value)
                end
            end
        end
    end
    return converted
end

local function MergeEntriesIntoNodes(nodes, entries)
    local stored = LPL.BuildStore:NormalizeNodesForStorage(nodes)
    if type(entries) ~= "table" then
        return stored
    end

    for rawNodeID, entryID in pairs(entries) do
        local key = tostring(rawNodeID)
        entryID = tonumber(entryID)
        local current = stored[key]
        if current and entryID then
            if type(current) == "number" then
                stored[key] = {
                    rank = current,
                    entryID = entryID,
                }
            elseif type(current) == "table" and not current.entryID then
                current.entryID = entryID
            end
        end
    end
    return stored
end

local function MergeImportSources(primary, secondary)
    if not secondary then
        return primary
    end
    primary.nodes = primary.nodes or {}
    for nodeID, value in pairs(secondary.nodes or {}) do
        primary.nodes[nodeID] = value
    end
    if secondary.subTreeID and not primary.subTreeID then
        primary.subTreeID = secondary.subTreeID
    end
    if secondary.specID and not primary.specID then
        primary.specID = secondary.specID
    end
    if secondary.classID and not primary.classID then
        primary.classID = secondary.classID
    end
    return primary
end

local function ResolveSpecIDForSubTree(subTreeID)
    subTreeID = tonumber(subTreeID)
    if not subTreeID or not LPL.TalentTree then
        return nil
    end

    for _, class in ipairs(LPL.TalentTree:GetClasses()) do
        for _, spec in ipairs(LPL.TalentTree:GetSpecsForClass(class.id)) do
            for _, hero in ipairs(LPL.TalentTree:GetHeroTalentsForSpec(spec.id)) do
                if hero.id == subTreeID then
                    return spec.id
                end
            end
        end
    end

    return nil
end

local function WithSegmentType(segmentType, source)
    if type(source) ~= "table" then
        return nil
    end
    if source.type == segmentType then
        return source
    end

    local wrapped = {}
    for key, value in pairs(source) do
        wrapped[key] = value
    end
    wrapped.type = segmentType
    return wrapped
end

local function ApplyLoadoutContext(segment, context)
    if type(segment) ~= "table" or type(context) ~= "table" then
        return segment
    end

    segment.name = segment.name or context.name
    segment.specID = segment.specID or context.specID
    segment.classID = segment.classID or context.classID
    return segment
end

local NormalizeImportTable

local function NormalizeLoadoutImport(source)
    if type(source) ~= "table" or source.type ~= "loadout" then
        return nil, "Invalid loadout import."
    end

    if (source.version or 2) ~= 2 then
        return nil, "Unsupported loadout version."
    end

    local specID = tonumber(source.specID)
    if not specID or not GetSpecializationInfoByID(specID) then
        return nil, "Invalid specialization in loadout."
    end

    local context = {
        name = source.name,
        specID = specID,
        classID = source.classID or LPL.TalentTree:GetClassIDForSpec(specID),
    }

    local primary
    local err

    if type(source.dftalents) == "table" then
        for _, segment in ipairs(source.dftalents) do
            if type(segment) == "table" then
                local wrapped = ApplyLoadoutContext(WithSegmentType("dftalents", segment), context)
                primary, err = NormalizeImportTable(wrapped)
                if primary then
                    break
                end
            end
        end
    end

    if not primary and type(source.herotalents) == "table" then
        for _, segment in ipairs(source.herotalents) do
            if type(segment) == "table" then
                local wrapped = ApplyLoadoutContext(WithSegmentType("herotalents", segment), context)
                primary, err = NormalizeImportTable(wrapped)
                if primary then
                    break
                end
            end
        end
    end

    if not primary then
        return nil, err or "Loadout has no importable talent data."
    end

    primary.name = source.name or primary.name
    primary.specID = primary.specID or specID
    primary.classID = primary.classID or context.classID

    if type(source.herotalents) == "table" then
        for _, segment in ipairs(source.herotalents) do
            if type(segment) == "table" then
                local wrapped = ApplyLoadoutContext(WithSegmentType("herotalents", segment), context)
                local heroData, heroErr = NormalizeImportTable(wrapped)
                if heroData then
                    if not primary.subTreeID and heroData.subTreeID then
                        primary.subTreeID = heroData.subTreeID
                    end
                    -- Older loadouts cloned the full tree into herotalents.
                    -- Merging that copy would overwrite a correct talent string
                    -- with ranks rewritten as choice indexes.
                    if not primary.nodes or not next(primary.nodes) then
                        primary = MergeImportSources(primary, heroData)
                    end
                elseif heroErr and not primary.nodes then
                    return nil, heroErr
                end
            end
        end
    end

    return primary
end

NormalizeImportTable = function(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end

    local importType = source.type
    if importType == "lpltalents" then
        if (source.version or 1) ~= 1 then
            return nil, "Unsupported LPL export version."
        end
        return {
            name = source.name,
            classID = source.classID,
            specID = source.specID,
            subTreeID = source.subTreeID,
            level = source.level,
            nodes = LPL.BuildStore:NormalizeNodesForStorage(source.nodes),
        }
    end

    if importType == "dftalents" then
        if (source.version or 1) > 2 then
            return nil, "Unsupported talent export version."
        end
        local specID = source.specID
        if not specID or not GetSpecializationInfoByID(specID) then
            return nil, "Invalid specialization in import string."
        end
        if type(source.string) == "string" and source.string ~= "" then
            local blizzardData = ParseBlizzardExportString(source.string)
            if blizzardData then
                blizzardData.name = source.name or blizzardData.name
                blizzardData.subTreeID = blizzardData.subTreeID or source.subTreeID
                blizzardData.classID = source.classID or blizzardData.classID
                blizzardData.level = source.level or blizzardData.level
                return blizzardData
            end
        end
        return {
            name = source.name,
            classID = source.classID or LPL.TalentTree:GetClassIDForSpec(specID),
            specID = specID,
            subTreeID = source.subTreeID,
            level = source.level or (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()) or 90,
            nodes = MergeEntriesIntoNodes(ConvertLegacyNodes(source.nodes, specID), source.entries),
        }
    end

    if importType == "herotalents" then
        if (source.version or 1) ~= 1 then
            return nil, "Unsupported hero talent export version."
        end

        local subTreeID = tonumber(source.subTreeID)
        local specID = tonumber(source.specID) or ResolveSpecIDForSubTree(subTreeID)
        if not specID then
            return nil, "Could not determine specialization for hero talents."
        end

        return {
            name = source.name,
            classID = source.classID or LPL.TalentTree:GetClassIDForSpec(specID),
            specID = specID,
            subTreeID = subTreeID,
            level = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or 90,
            nodes = ConvertLegacyNodes(source.nodes, specID),
        }
    end

    if importType == "loadout" then
        return NormalizeLoadoutImport(source)
    end

    return nil, "Unrecognized import string type. Supported: WoW, LPL, BtWLoadouts, LightPawsLoadouts."
end

function LPL.TalentShare:BuildExportPayload(build)
    if not build then
        return nil
    end
    return {
        type = "lpltalents",
        version = 1,
        name = build.name,
        classID = build.classID,
        specID = build.specID,
        subTreeID = build.subTreeID,
        level = build.level,
        nodes = LPL.BuildStore:NormalizeNodesForStorage(build.nodes),
    }
end

function LPL.TalentShare:BuildExportPayloadFromSandbox(sandbox, view, name)
    if not sandbox or not view then
        return nil
    end
    return {
        type = "lpltalents",
        version = 1,
        name = name,
        classID = view.classID,
        specID = view.specID,
        subTreeID = view.subTreeID,
        level = view.level,
        nodes = sandbox:ExportToBuildNodes(),
    }
end

function LPL.TalentShare:ExportBuild(build)
    if not build then
        return nil, "Nothing to export."
    end

    local ok, exportText, err = pcall(ExportBlizzardLoadout,
        build.specID,
        build.subTreeID,
        build.level,
        build.nodes,
        build.entries,
        build.classID
    )
    if ok and exportText and exportText ~= "" then
        return exportText
    end

    if not ok then
        err = exportText
    end

    local fallback = EncodeLPLExportString(
        build.specID,
        build.classID,
        build.subTreeID,
        build.level,
        build.name,
        build.nodes
    )
    if fallback and fallback ~= "" then
        return fallback, err
    end

    return nil, err or "Could not export build."
end

function LPL.TalentShare:ExportSandbox(sandbox, view, name)
    if not sandbox or not view then
        return nil, "Nothing to export."
    end

    local nodes = sandbox:ExportToBuildNodes()
    local ok, exportText, err = pcall(ExportBlizzardLoadout,
        view.specID,
        view.subTreeID,
        view.level,
        nodes,
        sandbox.entries,
        view.classID
    )
    if ok and exportText and exportText ~= "" then
        return exportText
    end

    if not ok then
        err = exportText
    end

    local fallback = EncodeLPLExportString(
        view.specID,
        view.classID,
        view.subTreeID,
        view.level,
        name,
        nodes
    )
    if fallback and fallback ~= "" then
        return fallback, err
    end

    return nil, err or "Could not export build."
end

function LPL.TalentShare:BuildLoadoutTalentSegment(build)
    if not build then
        return nil
    end

    local blizzardString = self:ExportBuild(build)
    if type(blizzardString) ~= "string" or blizzardString == "" then
        blizzardString = nil
    end

    local segment = {
        type = "dftalents",
        version = 2,
        name = build.name,
        classID = build.classID,
        specID = build.specID,
        subTreeID = build.subTreeID,
        level = build.level,
        nodes = MergeEntriesIntoNodes(build.nodes, build.entries),
        string = blizzardString,
    }
    local entries = LPL.BuildStore:NormalizeEntriesForStorage(build.entries)
    if entries then
        segment.entries = entries
    end
    return segment
end

function LPL.TalentShare:ParseImportString(text)
    text = Trim(text)
    if text == "" then
        return true, nil, ""
    end

    if text:match("^[A-Za-z][A-Za-z0-9+/=]+$") and not text:match("^{") then
        local blizzardData, blizzardErr = ParseBlizzardExportString(text)
        if blizzardData then
            return true, blizzardData, ""
        end
        if blizzardErr and not text:match("^[BN]") then
            return false, nil, blizzardErr
        end
    end

    local decodedText = text
    if text:match("^[BN]") then
        local ok, decoded = Decode(text)
        if not ok then
            return false, nil, decoded or "Could not decode share string."
        end
        decodedText = decoded
    end

    if decodedText:sub(1, 1) == "{" then
        local ok, source = StringToTable(decodedText)
        if not ok then
            return false, nil, source or "Invalid share string."
        end
        local importData, err = NormalizeImportTable(source)
        if not importData then
            return false, nil, err or "Unrecognized share string."
        end
        return true, importData, ""
    end

    local blizzardData, blizzardErr = ParseBlizzardExportString(text)
    if blizzardData then
        return true, blizzardData, ""
    end

    return false, nil, blizzardErr or "Unrecognized share string."
end

function LPL.TalentShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.TalentShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a share string to import."
    end
    if options then
        local build = LPL.BuildStore:ApplyImport(importData, name, options)
        if not build then
            return nil, "Could not save imported build."
        end
        return build
    end
    local build = LPL.BuildStore:CreateFromImport(importData, name)
    if not build then
        return nil, "Could not save imported build."
    end
    return build
end

local function GetRawImportSource(text)
    text = Trim(text)
    if text == "" then
        return nil
    end

    local decodedText = text
    if text:match("^[BN]") then
        local ok, decoded = Decode(text)
        if not ok then
            return nil
        end
        decodedText = decoded
    end

    if type(decodedText) == "string" and decodedText:sub(1, 1) == "{" then
        local ok, source = StringToTable(decodedText)
        if ok then
            return source
        end
    end

    return nil
end

function LPL.TalentShare:BuildImportPreview(importData, buildName, rawSource)
    if type(importData) ~= "table" then
        return nil
    end

    rawSource = rawSource or {}
    buildName = LPL.BuildStore:NormalizeBuildName(buildName, importData.name or "Imported Build")
    local loadoutPath = LPL.BuildStore:FormatLoadoutPath(importData, buildName)
    local existingBuild = LPL.BuildStore:FindByLoadoutPath(loadoutPath)

    local hasActionBarData = type(rawSource.actionbars) == "table" and #rawSource.actionbars > 0
        or type(rawSource.actionBars) == "table" and #rawSource.actionBars > 0
        or type(importData.actionBars) == "table"

    local hasHeroData = importData.subTreeID ~= nil
        or type(rawSource.herotalents) == "table"
        or type(rawSource.heroTalents) == "table"

    local sections = {}

    local talentsExists = existingBuild ~= nil
    sections[#sections + 1] = {
        id = "talents",
        label = "Talents",
        path = loadoutPath,
        available = true,
        exists = talentsExists,
        checkboxLabel = talentsExists
            and string.format('Use existing Talents set "%s"', loadoutPath)
            or string.format('Add Talents set "%s"', loadoutPath),
        defaultChecked = true,
    }

    if hasHeroData then
        local heroExists = existingBuild ~= nil
            and existingBuild.subTreeID
            and importData.subTreeID
            and existingBuild.subTreeID == importData.subTreeID
        sections[#sections + 1] = {
            id = "hero",
            label = "Hero Talents",
            path = loadoutPath,
            available = true,
            exists = heroExists,
            checkboxLabel = heroExists
                and string.format('Use existing Hero Talents set "%s"', loadoutPath)
                or string.format('Add Hero Talents set "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    if hasActionBarData then
        local existingActionBar = LPL.ActionBarStore and LPL.ActionBarStore:FindByName(loadoutPath)
        sections[#sections + 1] = {
            id = "actionBars",
            label = "Action Bars",
            path = loadoutPath,
            available = true,
            exists = existingActionBar ~= nil,
            checkboxLabel = existingActionBar
                and string.format('Use existing Action Bars set "%s"', loadoutPath)
                or string.format('Add Action Bars set "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    local existingActionBar = LPL.ActionBarStore and LPL.ActionBarStore:FindByName(loadoutPath)

    return {
        loadoutPath = loadoutPath,
        buildName = buildName,
        existingBuildID = existingBuild and existingBuild.id or nil,
        existingActionBarID = existingActionBar and existingActionBar.id or nil,
        importKind = "talents",
        sections = sections,
        importData = importData,
    }
end

function LPL.TalentShare:BuildImportPreviewFromText(text, buildName)
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err
    end
    local rawSource = GetRawImportSource(text) or {}
    return self:BuildImportPreview(importData, buildName, rawSource)
end

function LPL.TalentShare:DecodeShareString(text)
    text = Trim(text)
    if text == "" then
        return false, "Empty share string."
    end

    local decodedText = text
    if text:match("^[BN]") then
        local ok, decoded = Decode(text)
        if not ok then
            return false, decoded or "Could not decode share string."
        end
        decodedText = decoded
    end

    if type(decodedText) == "string" and decodedText:sub(1, 1) == "{" then
        return StringToTable(decodedText)
    end

    return false, "Unrecognized share string."
end

function LPL.TalentShare:EncodeShareTable(payload)
    if type(payload) ~= "table" then
        return nil, "Nothing to export."
    end
    return Encode(TableToString(payload), "BN")
end

function LPL.TalentShare:GetRawImportSource(text)
    return GetRawImportSource(text)
end
