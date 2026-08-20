local addonName, LPL = ...

LPL.TalentTree = {
    lib = nil,
    ready = false,
    pendingCallbacks = {},
}

local VIEW_CONFIG_ID = Constants and Constants.TraitConsts and Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID

local function GetLib()
    if not LPL.TalentTree.lib then
        if not LibStub then
            return nil
        end
        LPL.TalentTree.lib = LibStub:GetLibrary("LibTalentTree-1.0", true)
    end
    return LPL.TalentTree.lib
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

function LPL.TalentTree:GetNodeMaxRanks(nodeInfo)
    if not nodeInfo then
        return 1
    end
    if nodeInfo.totalMaxRanks and nodeInfo.totalMaxRanks > 0 then
        return nodeInfo.totalMaxRanks
    end
    return nodeInfo.maxRanks or 1
end

function LPL.TalentTree:GetEntryType(entryID)
    entryID = tonumber(entryID)
    if not entryID then
        return nil
    end
    local lib = GetLib()
    local entryInfo = lib and lib.GetEntryInfo and lib:GetEntryInfo(entryID)
    if entryInfo and entryInfo.type then
        return entryInfo.type
    end
    local configID = VIEW_CONFIG_ID or -3
    entryInfo = C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, entryID)
    return entryInfo and entryInfo.type
end

function LPL.TalentTree:GetNodeArtKind(nodeInfo)
    if not nodeInfo then
        return "circle"
    end

    local nodeType = Enum and Enum.TraitNodeType
    local isChoice = nodeInfo.isSubTreeSelection
        or (nodeType and (nodeInfo.type == nodeType.Selection or nodeInfo.type == nodeType.SubTreeSelection))
    if isChoice then
        return "choice"
    end

    local entryType = self:GetEntryType(nodeInfo.entryIDs and nodeInfo.entryIDs[1])
    local square = Enum.TraitNodeEntryType and (
        entryType == Enum.TraitNodeEntryType.SpendSquare
        or entryType == Enum.TraitNodeEntryType.SpendCapstoneSquare
    )

    if nodeInfo.isApexTalent then
        return square and "square" or "circle"
    end

    return square and "square" or "circle"
end

function LPL.TalentTree:IsAvailable()
    local lib = GetLib()
    return lib and lib.IsCompatible and lib:IsCompatible()
end

function LPL.TalentTree:WhenReady(callback)
    if self.ready then
        callback()
        return
    end

    self.pendingCallbacks[#self.pendingCallbacks + 1] = callback
    local lib = GetLib()
    if not lib then
        return
    end

    lib:RegisterOnCacheWarmup(function()
        self.ready = true
        for _, pending in ipairs(self.pendingCallbacks) do
            pending()
        end
        wipe(self.pendingCallbacks)
    end)
end

function LPL.TalentTree:GetDefaultClassID()
    local _, classFile = UnitClass("player")
    if classFile then
        for classID = 1, GetNumClasses() do
            local _, file = GetClassInfo(classID)
            if file == classFile then
                return classID
            end
        end
    end
    return 1
end

function LPL.TalentTree:GetClasses()
    local classes = {}
    for classID = 1, GetNumClasses() do
        local className, classFile = GetClassInfo(classID)
        if className then
            classes[#classes + 1] = {
                id = classID,
                name = className,
                file = classFile,
            }
        end
    end
    table.sort(classes, function(a, b)
        return a.name < b.name
    end)
    return classes
end

function LPL.TalentTree:GetSpecsForClass(classID)
    local specs = {}
    local numSpecs = 0
    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID then
        numSpecs = C_SpecializationInfo.GetNumSpecializationsForClassID(classID) or 0
    elseif GetNumSpecializationsForClassID then
        numSpecs = GetNumSpecializationsForClassID(classID) or 0
    end

    local getInfo = GetSpecializationInfoForClassID
    if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoForClassID then
        getInfo = C_SpecializationInfo.GetSpecializationInfoForClassID
    end
    if not getInfo then
        return specs
    end

    for specIndex = 1, numSpecs do
        local specID, specName = getInfo(classID, specIndex)
        if type(specID) == "table" then
            specName = specID.name or specName
            specID = specID.specID or specID.id
        end
        specID = tonumber(specID)
        if specID then
            specs[#specs + 1] = {
                id = specID,
                name = specName,
                index = specIndex,
            }
        end
    end
    return specs
end

function LPL.TalentTree:GetHeroTalentsForSpec(specID)
    local lib = GetLib()
    if not lib then
        return {}
    end

    local heroes = {}
    local subTreeMap = lib:GetSubTreeIDsForSpecID(specID) or {}
    for _, subTreeID in pairs(subTreeMap) do
        local subTreeInfo = lib:GetSubTreeInfo(subTreeID)
        if subTreeInfo then
            heroes[#heroes + 1] = {
                id = subTreeID,
                name = subTreeInfo.name or ("Hero " .. subTreeID),
            }
        end
    end

    table.sort(heroes, function(a, b)
        return a.name < b.name
    end)

    return heroes
end

function LPL.TalentTree:GetTreeIDForClass(classID)
    local lib = GetLib()
    if not lib then
        return nil
    end
    return lib:GetClassTreeID(classID)
end

function LPL.TalentTree:ApplyView(classID, specID, subTreeID, level)
    if not C_ClassTalents or not C_ClassTalents.InitializeViewLoadout then
        return false
    end

    if not specID then
        return false
    end

    if GetMaxLevelForPlayerExpansion then
        level = GetMaxLevelForPlayerExpansion()
    else
        level = level or 90
    end

    C_ClassTalents.InitializeViewLoadout(specID, level)
    C_ClassTalents.ViewLoadout({})

    if subTreeID and VIEW_CONFIG_ID then
        local lib = GetLib()
        if lib then
            local nodeID, entryID = lib:GetSubTreeSelectionNodeIDAndEntryIDBySpecID(specID, subTreeID)
            if nodeID and entryID and C_Traits.SetSelection then
                C_Traits.SetSelection(VIEW_CONFIG_ID, nodeID, entryID)
            end
        end
    end

    return true
end

function LPL.TalentTree:GetClassIDForSpec(specID)
    for _, class in ipairs(self:GetClasses()) do
        for _, spec in ipairs(self:GetSpecsForClass(class.id)) do
            if spec.id == specID then
                return class.id
            end
        end
    end
    return self:GetDefaultClassID()
end

function LPL.TalentTree:GetVisibleNodes(classID, specID, subTreeID, level)
    local lib = GetLib()
    if not lib then
        return {}
    end

    local view = self:ResolveViewState()
    classID = classID or view.classID
    specID = specID or view.specID
    subTreeID = subTreeID or view.subTreeID
    level = level or view.level

    if not specID then
        return {}
    end

    classID = classID or self:GetClassIDForSpec(specID)
    if not self:ApplyView(classID, specID, subTreeID, level) then
        return {}
    end

    local treeID = lib:GetClassTreeID(classID)
    if not treeID then
        return {}
    end

    local nodes = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        if lib:IsNodeVisibleForSpec(specID, nodeID) then
            local nodeInfo = GetCachedNodeInfo(lib, nodeID)
            if nodeInfo then
                local nodeSubTreeID = nodeInfo.subTreeID
                local show = true
                if nodeSubTreeID and subTreeID and nodeSubTreeID ~= subTreeID and not nodeInfo.isSubTreeSelection then
                    show = false
                end
                if show and not nodeInfo.isSubTreeSelection and (not nodeInfo.entryIDs or not nodeInfo.entryIDs[1]) then
                    show = false
                end
                if show then
                    nodes[#nodes + 1] = nodeInfo
                end
            end
        end
    end

    return nodes
end

function LPL.TalentTree:CurrencyMatchesSubTree(currency, subTreeID)
    if not currency or not subTreeID then
        return false
    end
    if currency.subTreeID == subTreeID then
        return true
    end
    if currency.subTreeIDs then
        for _, id in ipairs(currency.subTreeIDs) do
            if id == subTreeID then
                return true
            end
        end
    end
    return false
end

function LPL.TalentTree:GetNodePointPool(nodeID, selectedSubTreeID)
    local lib = GetLib()
    if not lib or not nodeID then
        return nil
    end

    nodeID = tonumber(nodeID)
    if not nodeID then
        return nil
    end

    local nodeInfo = GetCachedNodeInfo(lib, nodeID)
    if not nodeInfo then
        return nil
    end

    if nodeInfo.isSubTreeSelection then
        return nil
    end

    if nodeInfo.subTreeID then
        if selectedSubTreeID and nodeInfo.subTreeID == selectedSubTreeID then
            return "hero"
        end
        return nil
    end

    if lib:IsClassNode(nodeID) then
        return "class"
    end

    return "spec"
end

function LPL.TalentTree:CountSandboxSpent(sandbox, subTreeID, specID, classID, level)
    local classSpent, specSpent, heroSpent = 0, 0, 0
    if not sandbox or not sandbox.nodes then
        return classSpent, specSpent, heroSpent
    end

    specID = tonumber(specID)
    classID = classID or (specID and self:GetClassIDForSpec(specID))
    if not classID or not specID or not LPL.TalentInteractions then
        return classSpent, specSpent, heroSpent
    end

    local spending = LPL.TalentInteractions:GetCurrencySpending(sandbox, classID, specID, subTreeID, level)
    local lib = GetLib()
    local treeID = lib and lib:GetClassTreeID(classID)
    local currencies = treeID and lib:GetTreeCurrencies(treeID) or {}

    for _, currency in ipairs(currencies) do
        if currency.traitCurrencyID then
            local spent = spending[currency.traitCurrencyID] or 0
            if currency.isClassCurrency then
                classSpent = spent
            elseif currency.isSpecCurrency then
                specSpent = spent
            elseif subTreeID and self:CurrencyMatchesSubTree(currency, subTreeID) then
                heroSpent = spent
            end
        end
    end

    return classSpent, specSpent, heroSpent
end

function LPL.TalentTree:GetNodePosition(nodeID)
    local lib = GetLib()
    if not lib or not nodeID then
        return nil, nil
    end
    if lib.GetNodePosition then
        return lib:GetNodePosition(nodeID)
    end
    local nodeInfo = GetCachedNodeInfo(lib, nodeID)
    if not nodeInfo then
        return nil, nil
    end
    return nodeInfo.posX, nodeInfo.posY
end

function LPL.TalentTree:GetNodeGridPosition(nodeID)
    local lib = GetLib()
    if not lib then
        return nil, nil
    end
    return lib:GetNodeGridPosition(nodeID)
end

function LPL.TalentTree:GetNodeEdges(nodeID)
    local lib = GetLib()
    if not lib then
        return {}
    end
    return lib:GetNodeEdges(nodeID) or {}
end

function LPL.TalentTree:IsNodeGranted(nodeInfo, specID)
    local lib = GetLib()
    if not lib or not nodeInfo or not nodeInfo.ID then
        return false
    end
    return lib:IsNodeGrantedForSpec(specID, nodeInfo.ID)
end

local function SurfaceTooltipData(tooltipData)
    if not tooltipData then
        return
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        TooltipUtil.SurfaceArgs(tooltipData)
        if tooltipData.lines then
            for _, line in ipairs(tooltipData.lines) do
                TooltipUtil.SurfaceArgs(line)
            end
        end
    end
end

local function AppendPlainPart(parts, value)
    local text = LPL:PlainString(value)
    if text then
        parts[#parts + 1] = text
    end
end

local function GetSpellNameByID(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID < 1 then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        local name = LPL:PlainString(C_Spell.GetSpellName(spellID))
        if name then
            return name
        end
    end
    if GetSpellInfo then
        return LPL:PlainString(GetSpellInfo(spellID))
    end
    return nil
end

-- Matches Blizzard TalentUtil.GetTalentName / TalentDisplayMixin:GetName.
function LPL.TalentTree:GetEntryTalentName(entryID)
    entryID = tonumber(entryID)
    if not entryID then
        return nil
    end

    local configID = VIEW_CONFIG_ID or -3
    local lib = GetLib()
    local entryInfo = C_Traits.GetEntryInfo(configID, entryID) or (lib and lib:GetEntryInfo(entryID))
    if not entryInfo then
        return nil
    end

    if entryInfo.subTreeID then
        local subTreeInfo = lib and lib:GetSubTreeInfo(entryInfo.subTreeID)
        local subTreeName = LPL:PlainString(subTreeInfo and subTreeInfo.name)
        if subTreeName then
            return subTreeName
        end
    end

    if not entryInfo.definitionID then
        return nil
    end

    local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
    if not defInfo then
        return nil
    end

    local overrideName = LPL:PlainString(defInfo.overrideName)
    if overrideName then
        return overrideName
    end

    return GetSpellNameByID(defInfo.spellID)
end

local function SetTooltipTitle(tooltip, name)
    if not tooltip or not name then
        return
    end
    if GameTooltip_SetTitle then
        GameTooltip_SetTitle(tooltip, name)
        return
    end
    local r, g, b = LPL:GetTooltipColor("title")
    tooltip:SetText(name, r, g, b)
end

local function AddTooltipBlankLine(tooltip)
    if not tooltip then
        return
    end
    if GameTooltip_AddBlankLineToTooltip then
        GameTooltip_AddBlankLineToTooltip(tooltip)
    else
        tooltip:AddLine(" ")
    end
end

function LPL.TalentTree:BuildTraitEntryPlainText(entryID, rank, nodeInfo, liveInfo, includeSupplemental)
    includeSupplemental = includeSupplemental ~= false
    local parts = {}
    local talentName = self:GetEntryTalentName(entryID)
    AppendPlainPart(parts, talentName)

    if entryID and C_TooltipInfo and C_TooltipInfo.GetTraitEntry then
        local data = C_TooltipInfo.GetTraitEntry(entryID, rank or 1)
        SurfaceTooltipData(data)
        if data and data.lines then
            for _, line in ipairs(data.lines) do
                local left = LPL:PlainString(line.leftText)
                if not (talentName and left == talentName) then
                    AppendPlainPart(parts, line.leftText)
                end
                AppendPlainPart(parts, line.rightText)
            end
        end
    end

    if includeSupplemental then
        local maxRank = nodeInfo and self:GetNodeMaxRanks(nodeInfo) or 1
        local purchased = (type(liveInfo) == "number" and liveInfo)
            or (liveInfo and (liveInfo.sandboxRank or liveInfo.activeRank or liveInfo.currentRank))
            or 0
        if maxRank > 1 and TALENT_BUTTON_TOOLTIP_RANK_FORMAT then
            AppendPlainPart(parts, string.format(TALENT_BUTTON_TOOLTIP_RANK_FORMAT, purchased, maxRank))
        end

        if purchased > 0 and purchased < maxRank and TALENT_BUTTON_TOOLTIP_NEXT_RANK then
            local nextEntryID = (type(liveInfo) == "table" and liveInfo.nextEntry and liveInfo.nextEntry.entryID)
                or entryID
            if nextEntryID then
                AppendPlainPart(parts, TALENT_BUTTON_TOOLTIP_NEXT_RANK)
                local nextData = C_TooltipInfo.GetTraitEntry(nextEntryID, purchased + 1)
                SurfaceTooltipData(nextData)
                if nextData and nextData.lines then
                    for index = 2, #nextData.lines do
                        local line = nextData.lines[index]
                        AppendPlainPart(parts, line.leftText)
                        AppendPlainPart(parts, line.rightText)
                    end
                end
            end
        end
    end

    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " ")
end

local function AppendTraitEntryBody(tooltip, entryID, rank, talentName)
    if tooltip.AppendInfo then
        local ok = pcall(tooltip.AppendInfo, tooltip, "GetTraitEntry", entryID, rank)
        if ok then
            return true
        end
    end

    if C_TooltipInfo and C_TooltipInfo.GetTraitEntry then
        local data = C_TooltipInfo.GetTraitEntry(entryID, rank)
        if data and data.lines then
            SurfaceTooltipData(data)
            local first = data.lines[1]
            local firstText = first and LPL:PlainString(first.leftText)
            local skipHeader = talentName and firstText and firstText == talentName
            LPL.TalentTree:AddPlainTooltipDataLines(tooltip, data, skipHeader)
            return true
        end
    end

    return false
end

local function ApplyTraitEntryTooltip(owner, entryID, rank, nodeInfo, liveInfo)
    if not owner or not entryID or not GameTooltip then
        return false
    end

    rank = rank or 1
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if LPL.ResetGameTooltipContent then
        LPL:ResetGameTooltipContent(GameTooltip)
    elseif GameTooltip.ClearLines then
        GameTooltip:ClearLines()
    end

    local talentName = LPL.TalentTree:GetEntryTalentName(entryID)
    if talentName then
        SetTooltipTitle(GameTooltip, talentName)
        AddTooltipBlankLine(GameTooltip)
    end

    local shown = AppendTraitEntryBody(GameTooltip, entryID, rank, talentName)
    if not shown and not talentName then
        local plainOnly = LPL.TalentTree:BuildTraitEntryPlainText(entryID, rank, nodeInfo, liveInfo, true)
        if not plainOnly then
            return false
        end
        GameTooltip:SetText(plainOnly, LPL:GetTooltipColor("title"))
        GameTooltip:Show()
        LPL:SetGameTooltipAccessibilityPlain(GameTooltip, owner, plainOnly)
        return true
    end

    local maxRank = nodeInfo and LPL.TalentTree:GetNodeMaxRanks(nodeInfo) or 1
    local purchased = (liveInfo and (liveInfo.sandboxRank or liveInfo.activeRank or liveInfo.currentRank)) or 0
    if maxRank > 1 and TALENT_BUTTON_TOOLTIP_RANK_FORMAT then
        GameTooltip:AddLine(string.format(TALENT_BUTTON_TOOLTIP_RANK_FORMAT, purchased, maxRank), 1, 0.82, 0)
    end

    if purchased > 0 and purchased < maxRank and TALENT_BUTTON_TOOLTIP_NEXT_RANK then
        local nextEntryID = (liveInfo and liveInfo.nextEntry and liveInfo.nextEntry.entryID) or entryID
        if nextEntryID then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(TALENT_BUTTON_TOOLTIP_NEXT_RANK, 1, 0.82, 0)
            local nextData = C_TooltipInfo.GetTraitEntry(nextEntryID, purchased + 1)
            LPL.TalentTree:AddPlainTooltipDataLines(GameTooltip, nextData, true)
        end
    end

    local plain = LPL.TalentTree:BuildTraitEntryPlainText(entryID, rank, nodeInfo, liveInfo, true)
    LPL:SetGameTooltipAccessibilityPlain(GameTooltip, owner, plain)
    GameTooltip:Show()
    return true
end

function LPL.TalentTree:AddPlainTooltipDataLines(tooltip, tooltipData, skipHeader)
    if not tooltip or not tooltipData or not tooltipData.lines then
        return
    end

    SurfaceTooltipData(tooltipData)

    local startIndex = skipHeader and 2 or 1
    for index = startIndex, #tooltipData.lines do
        local line = tooltipData.lines[index]
        if line then
            local text = LPL:PlainString(line.leftText)
            if text then
                local r, g, b = LPL:GetTooltipColor(index == startIndex and not skipHeader and "title" or "normal")
                tooltip:AddLine(text, r, g, b, true)
            end
        end
    end
end

function LPL.TalentTree:GetSandboxEntryID(nodeInfo, sandbox, specID)
    if not nodeInfo or not nodeInfo.ID then
        return nil
    end
    if sandbox then
        local entryID = sandbox:GetNodeEntryID(nodeInfo.ID)
        if entryID then
            return entryID
        end
        if LPL.TalentInteractions and LPL.TalentInteractions:GetActiveRank(sandbox, nodeInfo, specID) > 0 then
            return nodeInfo.entryIDs and nodeInfo.entryIDs[1]
        end
    end
    return nil
end

function LPL.TalentTree:GetNodeEntryAndRank(nodeInfo, sandbox, specID)
    local configID = VIEW_CONFIG_ID or -3
    local liveInfo = nodeInfo and nodeInfo.ID and C_Traits.GetNodeInfo(configID, nodeInfo.ID)
    local sandboxEntryID = sandbox and self:GetSandboxEntryID(nodeInfo, sandbox, specID)
    local entryID = sandboxEntryID
        or (liveInfo and liveInfo.activeEntry and liveInfo.activeEntry.entryID)
        or (nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID)
        or (nodeInfo and nodeInfo.entryIDs and nodeInfo.entryIDs[1])

    local purchased = 0
    if sandbox and specID and LPL.TalentInteractions then
        purchased = LPL.TalentInteractions:GetActiveRank(sandbox, nodeInfo, specID) or 0
    else
        purchased = liveInfo and (liveInfo.activeRank or liveInfo.currentRank) or 0
    end
    if liveInfo then
        liveInfo.sandboxRank = purchased
    else
        liveInfo = { sandboxRank = purchased }
    end

    local tooltipRank = purchased > 0 and purchased or 1
    return entryID, tooltipRank, liveInfo
end

function LPL.TalentTree:ShowHeroEmblemTooltip(owner, subTreeID)
    local lib = GetLib()
    if not owner or not subTreeID or not lib then
        return
    end

    local subTreeInfo = lib:GetSubTreeInfo(subTreeID)
    if not subTreeInfo then
        return
    end

    local lines = {
        { text = LPL:PlainString(subTreeInfo.name) or "Hero Talents", color = "title" },
    }

    local description = LPL:PlainString(subTreeInfo.description)
    if description then
        lines[#lines + 1] = { text = description, color = "normal" }
    end

    if subTreeInfo.requiredPlayerLevel and subTreeInfo.requiredPlayerLevel > 1 then
        lines[#lines + 1] = {
            text = string.format("Requires Level %d", subTreeInfo.requiredPlayerLevel),
            color = "gold",
        }
    end

    LPL:ShowGameTooltipLines(owner, lines)
end

local function AddTooltipErrorLine(tooltip, text)
    if not tooltip or not text then
        return
    end
    if GameTooltip_AddErrorLine then
        GameTooltip_AddErrorLine(tooltip, text)
    else
        tooltip:AddLine(text, 1, 0.1, 0.1, true)
    end
end

function LPL.TalentTree:AppendNodeAvailabilityToTooltip(owner, nodeInfo, specID, sandbox, basePlain)
    if not sandbox or not nodeInfo or not LPL.TalentInteractions then
        return basePlain
    end

    local view = self:ResolveViewState()
    local lines = LPL.TalentInteractions:GetNodeUnavailabilityLines(
        sandbox,
        nodeInfo,
        specID,
        view.classID,
        view.subTreeID,
        view.level
    )
    if #lines == 0 then
        return basePlain
    end

    GameTooltip:AddLine(" ")
    local plainParts = { basePlain or "" }
    for _, line in ipairs(lines) do
        AddTooltipErrorLine(GameTooltip, line)
        local plainLine = LPL:PlainString(line)
        if plainLine then
            plainParts[#plainParts + 1] = plainLine
        end
    end

    GameTooltip:Show()
    local plain = table.concat(plainParts, " ")
    LPL:SetGameTooltipAccessibilityPlain(GameTooltip, owner, plain)
    return plain
end

function LPL.TalentTree:ShowEntryTooltip(owner, entryID, nodeInfo, rank)
    if not owner or not entryID then
        return
    end
    ApplyTraitEntryTooltip(owner, entryID, rank or 1, nodeInfo, nil)
end

function LPL.TalentTree:ShowNodeTooltip(owner, nodeInfo, specID, sandbox)
    if not owner or not nodeInfo then
        return
    end

    local entryID, rank, liveInfo = self:GetNodeEntryAndRank(nodeInfo, sandbox, specID)
    local plain

    if ApplyTraitEntryTooltip(owner, entryID, rank, nodeInfo, liveInfo) then
        plain = self:BuildTraitEntryPlainText(entryID, rank, nodeInfo, liveInfo, true)
        self:AppendNodeAvailabilityToTooltip(owner, nodeInfo, specID, sandbox, plain)
        return
    end

    if entryID and nodeInfo.ID and C_Traits and C_Traits.GetTraitDescription then
        local description = LPL:PlainString(C_Traits.GetTraitDescription(nodeInfo.ID, entryID))
        local title = LPL:PlainString(self:GetNodeTooltip(nodeInfo)) or "Talent"
        local lines = {
            { text = title, color = "title" },
        }
        if description then
            lines[#lines + 1] = { text = description, color = "normal" }
        end
        LPL:ShowGameTooltipLines(owner, lines)
        plain = title
        if description then
            plain = plain .. " " .. description
        end
        self:AppendNodeAvailabilityToTooltip(owner, nodeInfo, specID, sandbox, plain)
        return
    end

    local title = LPL:PlainString(self:GetNodeTooltip(nodeInfo)) or "Talent"
    LPL:ShowGameTooltipLines(owner, {
        { text = title, color = "title" },
    })
    self:AppendNodeAvailabilityToTooltip(owner, nodeInfo, specID, sandbox, title)
end

local function ResolveEntryInfo(entryID)
    if not entryID then
        return nil
    end
    local lib = GetLib()
    local configID = VIEW_CONFIG_ID or -3
    local liveInfo = C_Traits.GetEntryInfo and C_Traits.GetEntryInfo(configID, entryID)
    local cachedInfo = lib and lib.GetEntryInfo and lib:GetEntryInfo(entryID)
    if liveInfo and cachedInfo then
        return Mixin(liveInfo, cachedInfo)
    end
    return cachedInfo or liveInfo
end

function LPL.TalentTree:ApplyEntryIcon(texture, entryID)
    if not texture or not entryID then
        texture:SetTexture(136243)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end

    local lib = GetLib()
    local entryInfo = ResolveEntryInfo(entryID)
    if not entryInfo then
        texture:SetTexture(136243)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end

    local definitionID = entryInfo.definitionID
    if definitionID then
        local defInfo = C_Traits.GetDefinitionInfo(definitionID)
        if defInfo then
            if defInfo.overrideIcon then
                texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                if type(defInfo.overrideIcon) == "string" then
                    texture:SetAtlas(defInfo.overrideIcon)
                else
                    texture:SetTexture(defInfo.overrideIcon)
                end
                return
            end

            if defInfo.spellID and defInfo.spellID > 0 then
                local spellTexture
                if C_Spell and C_Spell.GetSpellTexture then
                    spellTexture = C_Spell.GetSpellTexture(defInfo.spellID)
                end
                if not spellTexture and GetSpellTexture then
                    spellTexture = GetSpellTexture(defInfo.spellID)
                end
                if spellTexture then
                    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    if type(spellTexture) == "string" and not spellTexture:find("^Interface") then
                        texture:SetAtlas(spellTexture)
                    else
                        texture:SetTexture(spellTexture)
                    end
                    return
                end
            end
        end
    end

    if entryInfo.subTreeID and lib then
        local subTreeInfo = lib:GetSubTreeInfo(entryInfo.subTreeID)
        if subTreeInfo and subTreeInfo.iconElementID then
            texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            texture:SetAtlas(subTreeInfo.iconElementID)
            return
        end
    end

    texture:SetTexture(136243)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
end

function LPL.TalentTree:ApplyNodeIcon(texture, nodeInfo, sandbox, specID)
    if not texture or not nodeInfo or not nodeInfo.entryIDs or not nodeInfo.entryIDs[1] then
        texture:SetTexture(136243)
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end

    local entryID = self:GetSandboxEntryID(nodeInfo, sandbox, specID)
    if not entryID then
        local configID = VIEW_CONFIG_ID or -3
        local liveInfo = nodeInfo.ID and C_Traits.GetNodeInfo(configID, nodeInfo.ID)
        entryID = liveInfo and liveInfo.activeEntry and liveInfo.activeEntry.entryID
            or nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
            or nodeInfo.entryIDs[1]
    end

    self:ApplyEntryIcon(texture, entryID)
end

function LPL.TalentTree:GetNodeIcon(nodeInfo)
    if not nodeInfo or not nodeInfo.entryIDs or not nodeInfo.entryIDs[1] then
        return 136243, false
    end

    local lib = GetLib()
    local configID = VIEW_CONFIG_ID or -3
    local liveInfo = nodeInfo.ID and C_Traits.GetNodeInfo(configID, nodeInfo.ID)
    local entryID = liveInfo and liveInfo.activeEntry and liveInfo.activeEntry.entryID
        or nodeInfo.entryIDs[1]

    local entryInfo = ResolveEntryInfo(entryID)
    if not entryInfo then
        return 136243, false
    end

    local definitionID = entryInfo.definitionID
    if definitionID then
        local defInfo = C_Traits.GetDefinitionInfo(definitionID)
        if defInfo then
            if defInfo.overrideIcon then
                return defInfo.overrideIcon, type(defInfo.overrideIcon) == "string"
            end
            if defInfo.spellID and defInfo.spellID > 0 then
                local spellTexture
                if C_Spell and C_Spell.GetSpellTexture then
                    spellTexture = C_Spell.GetSpellTexture(defInfo.spellID)
                end
                if not spellTexture and GetSpellTexture then
                    spellTexture = GetSpellTexture(defInfo.spellID)
                end
                if spellTexture then
                    local isAtlas = type(spellTexture) == "string" and not spellTexture:find("^Interface")
                    return spellTexture, isAtlas
                end
            end
        end
    end

    if entryInfo.subTreeID and lib then
        local subTreeInfo = lib:GetSubTreeInfo(entryInfo.subTreeID)
        if subTreeInfo and subTreeInfo.iconElementID then
            return subTreeInfo.iconElementID, true
        end
    end

    return 136243, false
end

function LPL.TalentTree:GetNodeTooltip(nodeInfo)
    if not nodeInfo then
        return "Unknown"
    end

    local configID = VIEW_CONFIG_ID or -3
    local liveInfo = C_Traits.GetNodeInfo(configID, nodeInfo.ID)
    local entryID = liveInfo and liveInfo.activeEntry and liveInfo.activeEntry.entryID
        or nodeInfo.entryIDs and nodeInfo.entryIDs[1]

    if entryID then
        local name = self:GetEntryTalentName(entryID)
        if name then
            return name
        end
    end

    if nodeInfo.isSubTreeSelection then
        return "Hero Talents"
    end

    return "Talent"
end

function LPL.TalentTree:GetPointSummary(classID, specID, subTreeID, level, sandbox)
    local lib = GetLib()
    if not lib then
        return nil
    end

    local view = self:ResolveViewState()
    classID = classID or view.classID
    specID = specID or view.specID
    subTreeID = subTreeID or view.subTreeID
    level = level or view.level

    if not specID then
        return nil
    end

    classID = classID or self:GetClassIDForSpec(specID)
    if not self:ApplyView(classID, specID, subTreeID, level) then
        return nil
    end
    local treeID = lib:GetClassTreeID(classID)
    if not treeID then
        return nil
    end

    local currencies = lib:GetTreeCurrencies(treeID)
    if not currencies or not currencies[1] then
        return nil
    end

    local classMax = currencies[1].maxQuantity or 0
    local specMax = currencies[2] and currencies[2].maxQuantity or 0
    local heroMax = 0
    if subTreeID then
        for _, currency in ipairs(currencies) do
            if self:CurrencyMatchesSubTree(currency, subTreeID) then
                heroMax = currency.maxQuantity or 0
                break
            end
        end
    end

    local classSpent, specSpent, heroSpent = 0, 0, 0
    if sandbox then
        classSpent, specSpent, heroSpent = self:CountSandboxSpent(sandbox, subTreeID, specID, classID, level)
    end

    return {
        classSpent = classSpent,
        classMax = classMax,
        specSpent = specSpent,
        specMax = specMax,
        heroSpent = heroSpent,
        heroMax = heroMax,
        level = level,
    }
end

function LPL.TalentTree:ResolveViewState()
    local view = LPL.DB:GetTalentView()
    view.classID = view.classID or self:GetDefaultClassID()

    local specs = self:GetSpecsForClass(view.classID)
    local specValid = false
    for _, spec in ipairs(specs) do
        if spec.id == view.specID then
            specValid = true
            break
        end
    end
    if not specValid then
        view.specID = specs[1] and specs[1].id
        view.subTreeID = nil
    end

    if view.specID then
        local heroes = self:GetHeroTalentsForSpec(view.specID)
        local heroValid = false
        for _, hero in ipairs(heroes) do
            if hero.id == view.subTreeID then
                heroValid = true
                break
            end
        end
        if not heroValid then
            view.subTreeID = heroes[1] and heroes[1].id
        end
    else
        view.subTreeID = nil
    end

    self:ResolveViewLevel(view)
    return view
end

function LPL.TalentTree:ResolveViewLevel(view)
    local maxLevel = 90
    if GetMaxLevelForPlayerExpansion then
        maxLevel = GetMaxLevelForPlayerExpansion()
    end

    if LPL.DB:GetUI().showLevelSlider then
        local level = tonumber(view and view.level) or maxLevel
        level = math.max(10, math.min(maxLevel, level))
        if view then
            view.level = level
        end
        return level
    end

    if view then
        view.level = maxLevel
    end
    return maxLevel
end

function LPL.TalentTree:GetPlayerIdentity()
    local classID = self:GetDefaultClassID()
    local specID = LPL.Character and LPL.Character.GetSpecID and LPL.Character:GetSpecID()
    return classID, specID
end

function LPL.TalentTree:GetPlayerActiveSubTreeID(specID, configID)
    specID = tonumber(specID)
    if not specID and LPL.Character and LPL.Character.GetSpecID then
        specID = LPL.Character:GetSpecID()
    end
    if not configID and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        configID = C_ClassTalents.GetActiveConfigID()
    end

    local lib = GetLib()
    if not lib or not specID or not configID or not C_Traits or not C_Traits.GetNodeInfo then
        return nil
    end

    local subTreeMap = lib:GetSubTreeIDsForSpecID(specID) or {}
    for _, subTreeID in pairs(subTreeMap) do
        local nodeID, entryID = lib:GetSubTreeSelectionNodeIDAndEntryIDBySpecID(specID, subTreeID)
        if nodeID and entryID then
            local liveInfo = C_Traits.GetNodeInfo(configID, nodeID)
            local activeEntryID = liveInfo and liveInfo.activeEntry and liveInfo.activeEntry.entryID
            if activeEntryID == entryID then
                return subTreeID
            end
        end
    end

    local classID = self:GetClassIDForSpec(specID)
    local treeID = lib:GetClassTreeID(classID)
    if treeID and C_Traits.GetTreeNodes then
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
            local nodeInfo = lib:GetNodeInfo(nodeID)
            if nodeInfo and nodeInfo.isSubTreeSelection then
                local liveInfo = C_Traits.GetNodeInfo(configID, nodeID)
                local activeEntryID = liveInfo and liveInfo.activeEntry and liveInfo.activeEntry.entryID
                if activeEntryID and C_Traits.GetEntryInfo then
                    local entryInfo = C_Traits.GetEntryInfo(configID, activeEntryID)
                    if entryInfo and entryInfo.subTreeID then
                        return entryInfo.subTreeID
                    end
                end
            end
        end
    end

    return nil
end

function LPL.TalentTree:PlayerMatchesView(classID, specID)
    classID = tonumber(classID)
    specID = tonumber(specID)
    if not classID or not specID then
        return false
    end

    local playerClassID, playerSpecID = self:GetPlayerIdentity()
    playerClassID = tonumber(playerClassID)
    playerSpecID = tonumber(playerSpecID)
    if not playerClassID or not playerSpecID then
        return false
    end

    return playerClassID == classID and playerSpecID == specID
end

local function GetPurchasedNodeFromLive(liveInfo, maxRanks)
    if not liveInfo then
        return 0, nil
    end

    local rank = liveInfo.ranksPurchased or 0
    if rank <= 0 then
        return 0, nil
    end

    maxRanks = tonumber(maxRanks) or rank
    if rank > maxRanks then
        rank = maxRanks
    end

    local entryID = liveInfo.activeEntry and liveInfo.activeEntry.entryID
    return rank, entryID
end

local function IsNodeVisibleForEditor(lib, nodeInfo, nodeID, specID, subTreeID)
    if not nodeInfo or not lib:IsNodeVisibleForSpec(specID, nodeID) then
        return false
    end

    local nodeSubTreeID = nodeInfo.subTreeID
    if nodeSubTreeID and subTreeID and nodeSubTreeID ~= subTreeID and not nodeInfo.isSubTreeSelection then
        return false
    end

    return true
end

function LPL.TalentTree:LoadPlayerTalentsIntoSandbox(sandbox, view)
    if not sandbox or not view or not view.specID then
        return false, nil, "Invalid planner state."
    end

    if not self:PlayerMatchesView(view.classID, view.specID) then
        return false, nil, "Switch to the matching class and specialization."
    end

    if not C_ClassTalents or not C_ClassTalents.GetActiveConfigID or not C_Traits or not C_Traits.GetTreeNodes then
        return false, nil, "Talent APIs unavailable."
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return false, nil, "No active talent loadout found."
    end

    local lib = GetLib()
    if not lib then
        return false, nil, "Talent data is still loading."
    end

    local classID = view.classID or self:GetClassIDForSpec(view.specID)
    local subTreeID = self:GetPlayerActiveSubTreeID(view.specID, configID) or view.subTreeID

    local pendingNodes = {}
    local treeIDs = {}

    if C_Traits.GetConfigInfo then
        local configInfo = C_Traits.GetConfigInfo(configID)
        if configInfo and configInfo.treeIDs then
            treeIDs = configInfo.treeIDs
        end
    end

    if #treeIDs == 0 then
        local treeID = lib:GetClassTreeID(classID)
        if treeID then
            treeIDs = { treeID }
        end
    end

    if #treeIDs == 0 then
        return false, nil, "Could not resolve the talent tree."
    end

    for _, treeID in ipairs(treeIDs) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
            if lib:IsNodeVisibleForSpec(view.specID, nodeID) then
                local nodeInfo = lib:GetLibNodeInfo(nodeID)
                if nodeInfo and IsNodeVisibleForEditor(lib, nodeInfo, nodeID, view.specID, subTreeID) then
                    if not nodeInfo.isSubTreeSelection and not lib:IsNodeGrantedForSpec(view.specID, nodeID) then
                        local liveInfo = C_Traits.GetNodeInfo(configID, nodeID)
                        local rank, entryID = GetPurchasedNodeFromLive(liveInfo, nodeInfo.maxRanks)
                        if rank > 0 then
                            pendingNodes[#pendingNodes + 1] = {
                                nodeID = nodeID,
                                rank = rank,
                                entryID = entryID,
                            }
                        end
                    end
                end
            end
        end
    end

    if #pendingNodes == 0 then
        return false, subTreeID, "No purchased talents were found on your character."
    end

    sandbox:Clear()
    for _, node in ipairs(pendingNodes) do
        sandbox:SetNodeRank(node.nodeID, node.rank, node.entryID)
    end

    return true, subTreeID, nil
end
