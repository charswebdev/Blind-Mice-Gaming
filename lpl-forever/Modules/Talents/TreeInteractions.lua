local addonName, LPL = ...

LPL.TalentInteractions = {}

local edgeCache = {}
local incomingCache = {}

local function GetLib()
    return LibStub and LibStub:GetLibrary("LibTalentTree-1.0", true)
end

local function GetCachedNodeInfo(lib, nodeID)
    nodeID = tonumber(nodeID) or nodeID
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

local function IsChoiceNode(nodeInfo)
    if not nodeInfo or not Enum or not Enum.TraitNodeType then
        return false
    end
    return nodeInfo.type == Enum.TraitNodeType.Selection
        or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection
        or nodeInfo.isSubTreeSelection
end

local function HasExpandedSelection(nodeInfo)
    if not nodeInfo or not nodeInfo.flags or not Enum or not Enum.TraitNodeFlag then
        return false
    end
    if FlagsUtil and FlagsUtil.IsSet then
        return FlagsUtil.IsSet(nodeInfo.flags, Enum.TraitNodeFlag.ShowExpandedSelection)
    end
    return bit.band(nodeInfo.flags, Enum.TraitNodeFlag.ShowExpandedSelection) ~= 0
end

local function HasMultipleIcons(nodeInfo)
    if not nodeInfo or not nodeInfo.flags or not Enum or not Enum.TraitNodeFlag then
        return false
    end
    if FlagsUtil and FlagsUtil.IsSet then
        return FlagsUtil.IsSet(nodeInfo.flags, Enum.TraitNodeFlag.ShowMultipleIcons)
    end
    return bit.band(nodeInfo.flags, Enum.TraitNodeFlag.ShowMultipleIcons) ~= 0
end

function LPL.TalentInteractions:IsChoiceNode(nodeInfo)
    return IsChoiceNode(nodeInfo)
end

function LPL.TalentInteractions:UsesChoiceFlyout(nodeInfo)
    return IsChoiceNode(nodeInfo) and #(nodeInfo.entryIDs or {}) > 1
end
function LPL.TalentInteractions:HasSplitChoiceDisplay(nodeInfo)
    if not IsChoiceNode(nodeInfo) then
        return false
    end
    local entries = nodeInfo.entryIDs or {}
    if #entries == 2 then
        return true
    end
    return #entries > 1 and HasMultipleIcons(nodeInfo)
end

function LPL.TalentInteractions:ClearCaches()
    wipe(edgeCache)
    wipe(incomingCache)
end

function LPL.TalentInteractions:GetActiveRank(sandbox, nodeInfo, specID)
    if not nodeInfo or not nodeInfo.ID then
        return 0
    end
    if LPL.TalentTree:IsNodeGranted(nodeInfo, specID) then
        return LPL.TalentTree:GetNodeMaxRanks(nodeInfo)
    end
    if IsChoiceNode(nodeInfo) then
        local entryID = sandbox:GetNodeEntryID(nodeInfo.ID)
        if entryID then
            return 1
        end
        return 0
    end
    return sandbox:GetNodeRank(nodeInfo.ID)
end

function LPL.TalentInteractions:GetSelectedEntryID(sandbox, nodeID)
    return sandbox:GetNodeEntryID(nodeID)
end

local function GetTreeID(classID)
    return LPL.TalentTree:GetTreeIDForClass(classID)
end

local function GetNodeEdges(nodeID)
    if not edgeCache[nodeID] then
        edgeCache[nodeID] = LPL.TalentTree:GetNodeEdges(nodeID) or {}
    end
    return edgeCache[nodeID]
end

local function GetIncomingNodeIDs(treeID, nodeID)
    local cacheKey = treeID .. ":" .. nodeID
    if incomingCache[cacheKey] then
        return incomingCache[cacheKey]
    end

    local incoming = {}
    if treeID and C_Traits and C_Traits.GetTreeNodes then
        for _, sourceNodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
            for _, edge in ipairs(GetNodeEdges(sourceNodeID)) do
                if edge.targetNode == nodeID then
                    incoming[#incoming + 1] = sourceNodeID
                    break
                end
            end
        end
    end

    incomingCache[cacheKey] = incoming
    return incoming
end

function LPL.TalentInteractions:MeetsEdgeRequirements(sandbox, specID, classID, nodeID)
    local lib = GetLib()
    if not lib or not nodeID then
        return true
    end

    local treeID = GetTreeID(classID)
    if not treeID then
        return true
    end

    local incoming = GetIncomingNodeIDs(treeID, nodeID)
    if #incoming == 0 then
        return true
    end

    local hasActiveIncomingEdge = false
    local hasInactiveIncomingEdge = false

    for _, sourceNodeID in ipairs(incoming) do
        local nodeInfo = GetCachedNodeInfo(lib, sourceNodeID)
        if nodeInfo and lib:IsNodeVisibleForSpec(specID, sourceNodeID) then
            local maxRank = LPL.TalentTree:GetNodeMaxRanks(nodeInfo)
            local activeRank = self:GetActiveRank(sandbox, nodeInfo, specID)
            local isEdgeActive = activeRank >= maxRank
            if isEdgeActive then
                hasActiveIncomingEdge = true
            else
                hasInactiveIncomingEdge = true
            end
        end
    end

    return not hasInactiveIncomingEdge or hasActiveIncomingEdge
end

local VIEW_CONFIG_ID = Constants and Constants.TraitConsts and Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID

local function ResolveTraitCurrencyID(nodeID, nodeInfo, pool, subTreeID, currencies)
    if C_Traits and C_Traits.GetNodeCost and VIEW_CONFIG_ID then
        local ok, nodeCost = pcall(C_Traits.GetNodeCost, VIEW_CONFIG_ID, nodeID)
        if ok and nodeCost and next(nodeCost) then
            for _, cost in pairs(nodeCost) do
                if cost.ID then
                    for _, currency in ipairs(currencies) do
                        if currency.traitCurrencyID == cost.ID then
                            if currency.isClassCurrency or currency.isSpecCurrency then
                                return cost.ID
                            end
                            if subTreeID and LPL.TalentTree:CurrencyMatchesSubTree(currency, subTreeID) then
                                if nodeInfo and nodeInfo.subTreeID and nodeInfo.subTreeID ~= subTreeID then
                                    return nil
                                end
                                return cost.ID
                            end
                        end
                    end
                end
            end
            return nil
        end
    end
    if not pool then
        return nil
    end
    for _, currency in ipairs(currencies) do
        local matches = (pool == "class" and currency.isClassCurrency)
            or (pool == "spec" and currency.isSpecCurrency)
            or (pool == "hero" and subTreeID and LPL.TalentTree:CurrencyMatchesSubTree(currency, subTreeID))
        if matches and currency.traitCurrencyID then
            return currency.traitCurrencyID
        end
    end
    return nil
end

function LPL.TalentInteractions:GetCurrencySpending(sandbox, classID, specID, subTreeID, level)
    if not LPL.TalentTree:ApplyView(classID, specID, subTreeID, level) then
        return {}
    end
    local lib = GetLib()
    local treeID = GetTreeID(classID)
    if not lib or not treeID then
        return {}
    end

    local currencies = lib:GetTreeCurrencies(treeID) or {}
    local spending = {}

    for _, currency in ipairs(currencies) do
        if currency.traitCurrencyID then
            spending[currency.traitCurrencyID] = 0
        end
    end

    if not sandbox.nodes then
        return spending
    end

    for rawNodeID, rank in pairs(sandbox.nodes) do
        rank = tonumber(rank) or 0
        if rank > 0 then
            local nodeInfo = GetCachedNodeInfo(lib, rawNodeID)
            if nodeInfo and not nodeInfo.isSubTreeSelection and not lib:IsNodeGrantedForSpec(specID, rawNodeID) then
                if not lib.IsNodeVisibleForSpec or lib:IsNodeVisibleForSpec(specID, rawNodeID) then
                    if not nodeInfo.subTreeID or not subTreeID or nodeInfo.subTreeID == subTreeID then
                        local pool = LPL.TalentTree:GetNodePointPool(rawNodeID, subTreeID)
                        local currencyID = ResolveTraitCurrencyID(rawNodeID, nodeInfo, pool, subTreeID, currencies)
                        if currencyID then
                            spending[currencyID] = (spending[currencyID] or 0) + rank
                        end
                    end
                end
            end
        end
    end

    return spending
end

function LPL.TalentInteractions:MeetsGateRequirements(sandbox, specID, classID, subTreeID, level, nodeInfo)
    local lib = GetLib()
    if not lib or not nodeInfo or not nodeInfo.conditionIDs then
        return true
    end

    local gates = lib:GetGates(specID) or {}
    local gateByCondition = {}
    for _, gate in ipairs(gates) do
        gateByCondition[gate.conditionID] = gate
    end

    local spending = self:GetCurrencySpending(sandbox, classID, specID, subTreeID, level)

    for _, conditionID in ipairs(nodeInfo.conditionIDs) do
        local gate = gateByCondition[conditionID]
        if gate and gate.traitCurrencyID then
            local spent = spending[gate.traitCurrencyID] or 0
            local required = gate.spentAmountRequired or 0
            if spent < required then
                return false
            end
        end
    end

    return true
end

function LPL.TalentInteractions:GetPoolRemaining(sandbox, classID, specID, subTreeID, level, pool)
    local summary = LPL.TalentTree:GetPointSummary(classID, specID, subTreeID, level, sandbox)
    if not summary then
        return 0
    end
    if pool == "class" then
        return summary.classMax - summary.classSpent
    elseif pool == "spec" then
        return summary.specMax - summary.specSpent
    elseif pool == "hero" then
        return summary.heroMax - summary.heroSpent
    end
    return 0
end

function LPL.TalentInteractions:GetNodeState(sandbox, nodeInfo, specID, classID, subTreeID, level)
    local nodeID = nodeInfo and nodeInfo.ID
    local maxRank = nodeInfo and LPL.TalentTree:GetNodeMaxRanks(nodeInfo) or 1
    local isGranted = nodeInfo and LPL.TalentTree:IsNodeGranted(nodeInfo, specID)
    local isChoice = IsChoiceNode(nodeInfo)
    local activeRank = self:GetActiveRank(sandbox, nodeInfo, specID)
    local selectedEntryID = isChoice and sandbox:GetNodeEntryID(nodeID) or nil
    local meetsEdges = self:MeetsEdgeRequirements(sandbox, specID, classID, nodeID)
    local meetsGates = self:MeetsGateRequirements(sandbox, specID, classID, subTreeID, level, nodeInfo)
    local pool = LPL.TalentTree:GetNodePointPool(nodeID, subTreeID)
    local remaining = pool and self:GetPoolRemaining(sandbox, classID, specID, subTreeID, level, pool) or 0

    local canPurchase = not isGranted and meetsEdges and meetsGates
    if nodeInfo.isSubTreeSelection then
        if isChoice then
            canPurchase = canPurchase and not selectedEntryID
        end
    elseif isChoice then
        canPurchase = canPurchase and not selectedEntryID and remaining >= 1
    else
        canPurchase = canPurchase and activeRank < maxRank and remaining >= 1
    end

    local canRefund = not isGranted and activeRank > 0

    return {
        nodeID = nodeID,
        maxRank = maxRank,
        activeRank = activeRank,
        isGranted = isGranted,
        isChoice = isChoice,
        selectedEntryID = selectedEntryID,
        meetsEdges = meetsEdges,
        meetsGates = meetsGates,
        canPurchase = canPurchase,
        canRefund = canRefund,
        pool = pool,
        remaining = remaining,
        usesFlyout = self:UsesChoiceFlyout(nodeInfo),
        hasMultipleIcons = self:HasSplitChoiceDisplay(nodeInfo),
    }
end

local function FormatConditionTooltipText(condInfo)
    if not condInfo or not condInfo.tooltipFormat then
        return condInfo and condInfo.tooltipText or nil
    end

    local tooltipFormat = condInfo.tooltipFormat
    if condInfo.questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        return tooltipFormat:format(C_QuestLog.GetTitleForQuestID(condInfo.questID) or "")
    elseif condInfo.achievementID and GetAchievementInfo then
        local _, achievementName = GetAchievementInfo(condInfo.achievementID)
        return tooltipFormat:format(achievementName or "")
    elseif condInfo.playerLevel then
        return tooltipFormat:format(condInfo.playerLevel)
    elseif condInfo.spentAmountRequired then
        return tooltipFormat:format(condInfo.spentAmountRequired, "")
    end

    return condInfo.tooltipText or tooltipFormat
end

local function GetPoolDisplayName(pool, subTreeID)
    if pool == "class" then
        return "Class"
    elseif pool == "spec" then
        return "Specialization"
    elseif pool == "hero" then
        local lib = GetLib()
        if lib and subTreeID then
            local info = lib:GetSubTreeInfo(subTreeID)
            if info and info.name then
                return info.name
            end
        end
        return "Hero"
    end
    return "Talent"
end

function LPL.TalentInteractions:GetNodeUnavailabilityLines(sandbox, nodeInfo, specID, classID, subTreeID, level)
    local lines = {}
    if not sandbox or not nodeInfo or not nodeInfo.ID or not specID then
        return lines
    end

    local state = self:GetNodeState(sandbox, nodeInfo, specID, classID, subTreeID, level)
    if state.isGranted or state.canPurchase then
        return lines
    end

    local lib = GetLib()
    local configID = VIEW_CONFIG_ID or -3

    if nodeInfo.requiredPlayerLevel and level and level < nodeInfo.requiredPlayerLevel then
        lines[#lines + 1] = string.format("Requires Level %d", nodeInfo.requiredPlayerLevel)
    end

    if not state.meetsGates and lib and C_Traits and C_Traits.GetConditionInfo then
        local spending = self:GetCurrencySpending(sandbox, classID, specID, subTreeID, level)
        local gates = lib:GetGates(specID) or {}
        local gateByCondition = {}
        for _, gate in ipairs(gates) do
            gateByCondition[gate.conditionID] = gate
        end

        local bestGateConditionID
        local bestGateSpentRequired = -1
        for _, conditionID in ipairs(nodeInfo.conditionIDs or {}) do
            local condInfo = C_Traits.GetConditionInfo(configID, conditionID, true)
            if condInfo and condInfo.isGate and condInfo.spentAmountRequired then
                if condInfo.spentAmountRequired > bestGateSpentRequired then
                    bestGateConditionID = conditionID
                    bestGateSpentRequired = condInfo.spentAmountRequired
                end
            end
        end

        if bestGateConditionID then
            local gate = gateByCondition[bestGateConditionID]
            local condInfo = C_Traits.GetConditionInfo(configID, bestGateConditionID, true)
            if gate and gate.traitCurrencyID and condInfo then
                local spent = spending[gate.traitCurrencyID] or 0
                if spent < (gate.spentAmountRequired or 0) then
                    local text = FormatConditionTooltipText(condInfo)
                    if text then
                        lines[#lines + 1] = text
                    end
                end
            end
        end
    end

    if not state.meetsEdges and lib then
        local treeID = GetTreeID(classID)
        local incoming = treeID and GetIncomingNodeIDs(treeID, nodeInfo.ID) or {}
        local requiresAllPrecedingTraits = true
        local numEdges = 0
        local inactiveSources = {}

        for _, sourceNodeID in ipairs(incoming) do
            if lib:IsNodeVisibleForSpec(specID, sourceNodeID) then
                numEdges = numEdges + 1
                local edgeType
                for _, edge in ipairs(GetNodeEdges(sourceNodeID)) do
                    if edge.targetNode == nodeInfo.ID then
                        edgeType = edge.type
                        break
                    end
                end
                if edgeType and Enum.TraitEdgeType and edgeType ~= Enum.TraitEdgeType.RequiredForAvailability then
                    requiresAllPrecedingTraits = false
                end

                local sourceInfo = GetCachedNodeInfo(lib, sourceNodeID)
                if sourceInfo then
                    local maxRank = LPL.TalentTree:GetNodeMaxRanks(sourceInfo)
                    local activeRank = self:GetActiveRank(sandbox, sourceInfo, specID)
                    if activeRank < maxRank then
                        inactiveSources[#inactiveSources + 1] = {
                            nodeInfo = sourceInfo,
                            activeRank = activeRank,
                            maxRank = maxRank,
                        }
                    end
                end
            end
        end

        if requiresAllPrecedingTraits and numEdges > 1 and #inactiveSources > 0 then
            if GENERIC_TRAIT_FRAME_EDGE_REQUIREMENTS_BUTTON_TOOLTIP then
                lines[#lines + 1] = GENERIC_TRAIT_FRAME_EDGE_REQUIREMENTS_BUTTON_TOOLTIP
            else
                lines[#lines + 1] = "Requires all connected talents."
            end
        elseif #inactiveSources > 0 then
            if not requiresAllPrecedingTraits and #inactiveSources > 1 then
                local names = {}
                for _, src in ipairs(inactiveSources) do
                    names[#names + 1] = LPL.TalentTree:GetNodeTooltip(src.nodeInfo)
                end
                lines[#lines + 1] = "Requires one of: " .. table.concat(names, ", ")
            else
                for _, src in ipairs(inactiveSources) do
                    local name = LPL.TalentTree:GetNodeTooltip(src.nodeInfo) or "a prerequisite talent"
                    if src.maxRank > 1 then
                        lines[#lines + 1] = string.format(
                            "Requires rank %d/%d in %s",
                            src.activeRank,
                            src.maxRank,
                            name
                        )
                    else
                        lines[#lines + 1] = string.format("Requires %s", name)
                    end
                end
            end
        end
    end

    if state.meetsEdges and state.meetsGates then
        local needsPoints = false
        if state.isChoice and not state.selectedEntryID then
            needsPoints = state.remaining < 1
        elseif state.activeRank < state.maxRank then
            needsPoints = state.remaining < 1
        end
        if needsPoints and state.pool then
            local poolName = GetPoolDisplayName(state.pool, subTreeID)
            lines[#lines + 1] = string.format("Not enough %s talent points.", poolName)
        end
    end

    return lines
end

function LPL.TalentInteractions:InvalidateDependentNodes(sandbox, specID, classID, subTreeID, level)
    local lib = GetLib()
    if not lib then
        return false
    end

    local treeID = GetTreeID(classID)
    if not treeID or not C_Traits or not C_Traits.GetTreeNodes then
        return false
    end

    local changed = false
    repeat
        changed = false
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
            if sandbox:GetNodeRank(nodeID) > 0 or sandbox:GetNodeEntryID(nodeID) then
                local nodeInfo = GetCachedNodeInfo(lib, nodeID)
                if nodeInfo and not lib:IsNodeGrantedForSpec(specID, nodeID) then
                    if not self:MeetsEdgeRequirements(sandbox, specID, classID, nodeID)
                        or not self:MeetsGateRequirements(sandbox, specID, classID, subTreeID, level, nodeInfo) then
                        sandbox:SetNodeRank(nodeID, 0)
                        changed = true
                    end
                end
            end
        end
    until not changed

    return true
end

function LPL.TalentInteractions:PurchaseRank(sandbox, nodeInfo, specID, classID, subTreeID, level)
    if not nodeInfo or not nodeInfo.ID then
        return false
    end
    if IsChoiceNode(nodeInfo) then
        return false
    end

    local state = self:GetNodeState(sandbox, nodeInfo, specID, classID, subTreeID, level)
    if not state.canPurchase then
        return false
    end

    local rank = sandbox:GetNodeRank(nodeInfo.ID) + 1
    sandbox:SetNodeRank(nodeInfo.ID, rank)
    self:ClearCaches()
    return true
end

function LPL.TalentInteractions:RefundRank(sandbox, nodeInfo, specID, classID, subTreeID, level)
    if not nodeInfo or not nodeInfo.ID then
        return false
    end

    local state = self:GetNodeState(sandbox, nodeInfo, specID, classID, subTreeID, level)
    if not state.canRefund then
        return false
    end

    if IsChoiceNode(nodeInfo) then
        sandbox:SetNodeRank(nodeInfo.ID, 0)
    else
        sandbox:SetNodeRank(nodeInfo.ID, sandbox:GetNodeRank(nodeInfo.ID) - 1)
    end

    self:ClearCaches()
    self:InvalidateDependentNodes(sandbox, specID, classID, subTreeID, level)
    return true
end

function LPL.TalentInteractions:SetSelection(sandbox, nodeInfo, entryID, specID, classID, subTreeID, level)
    if not nodeInfo or not nodeInfo.ID or not IsChoiceNode(nodeInfo) then
        return false
    end

    if not entryID then
        return self:RefundRank(sandbox, nodeInfo, specID, classID, subTreeID, level)
    end

    local validEntry = false
    for _, id in ipairs(nodeInfo.entryIDs or {}) do
        if id == entryID then
            validEntry = true
            break
        end
    end
    if not validEntry then
        return false
    end

    local currentEntry = sandbox:GetNodeEntryID(nodeInfo.ID)
    if currentEntry == entryID then
        return true
    end

    if currentEntry then
        sandbox:SetNodeRank(nodeInfo.ID, 1, entryID)
        self:ClearCaches()
        return true
    end

    local state = self:GetNodeState(sandbox, nodeInfo, specID, classID, subTreeID, level)
    if not state.canPurchase then
        return false
    end

    sandbox:SetNodeRank(nodeInfo.ID, 1, entryID)
    self:ClearCaches()
    return true
end

function LPL.TalentInteractions:HandleNodeClick(sandbox, nodeInfo, button, specID, classID, subTreeID, level, onFlyout)
    if not nodeInfo or not nodeInfo.ID then
        return false
    end

    local state = self:GetNodeState(sandbox, nodeInfo, specID, classID, subTreeID, level)

    if button == "RightButton" then
        if state.canRefund then
            return self:RefundRank(sandbox, nodeInfo, specID, classID, subTreeID, level)
        end
        return false
    end

    if state.isChoice and self:UsesChoiceFlyout(nodeInfo) then
        if onFlyout then
            onFlyout(nodeInfo, state)
        end
        return false
    end

    if state.canPurchase then
        return self:PurchaseRank(sandbox, nodeInfo, specID, classID, subTreeID, level)
    end

    return false
end
