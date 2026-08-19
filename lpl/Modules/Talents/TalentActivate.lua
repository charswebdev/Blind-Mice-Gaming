local addonName, LPL = ...

LPL.TalentActivate = {}

local BATCH_SIZE = 100
local applyToken = 0
local pendingSpecSwitchBuildID = nil
local completeCallback = nil

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:SetScript("OnEvent", function()
    if not pendingSpecSwitchBuildID then
        return
    end
    local buildID = pendingSpecSwitchBuildID
    pendingSpecSwitchBuildID = nil
    C_Timer.After(0.15, function()
        local build = LPL.BuildStore:Get(buildID)
        if build then
            LPL.TalentActivate:ApplyBuildNow(build)
        else
            LPL.TalentActivate:NotifyComplete(false)
        end
    end)
end)

local function InvokeComplete(ok)
    local cb = completeCallback
    completeCallback = nil
    if cb then
        C_Timer.After(0, function()
            cb(ok and true or false)
        end)
    end
end

function LPL.TalentActivate:NotifyComplete(ok)
    InvokeComplete(ok)
end

local function GetLib()
    return LibStub and LibStub:GetLibrary("LibTalentTree-1.0", true)
end

local function Fail(message)
    print("|cffff6060LPL:|r " .. (message or "Could not activate build."))
    InvokeComplete(false)
    return false, message
end

local function Success(message)
    print("|cff33cc33LPL:|r " .. message)
    InvokeComplete(true)
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play()
    end
    return true
end

local function EnsureTalentAPIs()
    if C_ClassTalents and C_Traits and C_Traits.ResetTree then
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

    return C_ClassTalents ~= nil and C_Traits ~= nil and C_Traits.ResetTree ~= nil
end

local function GetPlayerClassID()
    local classID = LPL.TalentTree and LPL.TalentTree.GetPlayerIdentity and select(1, LPL.TalentTree:GetPlayerIdentity())
    return tonumber(classID)
end

local function GetPlayerSpecID()
    local specID = LPL.TalentTree and LPL.TalentTree.GetPlayerIdentity and select(2, LPL.TalentTree:GetPlayerIdentity())
    return tonumber(specID)
end

local function GetSpecIndexForSpecID(specID)
    specID = tonumber(specID)
    if not specID then
        return nil
    end

    local function InfoID(index)
        if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
            local result = C_SpecializationInfo.GetSpecializationInfo(index)
            if type(result) == "table" then
                return tonumber(result.specID or result.id)
            end
            return tonumber(result)
        end
        if GetSpecializationInfo then
            return tonumber(select(1, GetSpecializationInfo(index)))
        end
        return nil
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializations then
        for index = 1, C_SpecializationInfo.GetNumSpecializations() do
            if InfoID(index) == specID then
                return index
            end
        end
    end

    if GetNumSpecializations then
        for index = 1, GetNumSpecializations() do
            if InfoID(index) == specID then
                return index
            end
        end
    end

    return nil
end

local function SwitchToSpec(specID)
    local specIndex = GetSpecIndexForSpecID(specID)
    if not specIndex then
        return false, "Could not find that specialization on your character."
    end

    if C_SpecializationInfo and C_SpecializationInfo.SetSpecialization then
        C_SpecializationInfo.SetSpecialization(specIndex)
        return true
    end

    if SetSpecialization then
        SetSpecialization(specIndex)
        return true
    end

    return false, "Spec change is unavailable."
end

local function ResolveTreeID(build, configID)
    if configID and C_Traits.GetConfigInfo then
        local configInfo = C_Traits.GetConfigInfo(configID)
        if configInfo and type(configInfo.treeIDs) == "table" and configInfo.treeIDs[1] then
            return configInfo.treeIDs[1]
        end
    end
    local lib = GetLib()
    if lib and build.classID then
        return lib:GetClassTreeID(build.classID)
    end
    if C_ClassTalents and C_ClassTalents.GetTraitTreeForSpec and build.specID then
        return C_ClassTalents.GetTraitTreeForSpec(build.specID)
    end
    return nil
end

local function IsChoiceNodeType(nodeType)
    return nodeType == Enum.TraitNodeType.Selection
        or nodeType == Enum.TraitNodeType.SubTreeSelection
end

local function GetNodeSortKey(nodeID)
    local lib = GetLib()
    if lib and lib.GetNodeGridPosition then
        local col, row = lib:GetNodeGridPosition(nodeID)
        if col and row then
            return row, col
        end
    end
    return nil, nil
end

local function GetOrderedTreeNodes(treeID)
    local orderedNodes = C_Traits.GetTreeNodes(treeID)
    table.sort(orderedNodes, function(a, b)
        local aRow, aCol = GetNodeSortKey(a)
        local bRow, bCol = GetNodeSortKey(b)
        if aRow and aCol and bRow and bCol then
            if aRow ~= bRow then
                return aRow < bRow
            end
            return aCol < bCol
        end
        return a < b
    end)
    return orderedNodes
end

local function NodeMatchesEntry(configID, entry)
    local nodeInfo = C_Traits.GetNodeInfo(configID, entry.nodeID)
    if not nodeInfo or nodeInfo.ID == 0 then
        return false
    end
    local currentRank = nodeInfo.ranksPurchased or 0
    if currentRank < (entry.ranksPurchased or 0) then
        return false
    end
    if entry.isChoiceNode and entry.selectionEntryID then
        local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
        return activeEntryID == entry.selectionEntryID
    end
    return true
end

local function CountEntries(entryInfo)
    local count = 0
    for _ in pairs(entryInfo) do
        count = count + 1
    end
    return count
end

local function BuildEntryInfo(build, configID, specID)
    local lib = GetLib()
    local entryInfo = {}

    local function AddEntry(nodeID, rank, entryID, isChoiceNode)
        if lib and lib.IsNodeGrantedForSpec and lib:IsNodeGrantedForSpec(specID, nodeID) then
            return
        end
        entryInfo[nodeID] = {
            nodeID = nodeID,
            ranksPurchased = rank,
            selectionEntryID = entryID,
            isChoiceNode = isChoiceNode,
        }
    end

    if build.subTreeID and lib and lib.GetSubTreeSelectionNodeIDAndEntryIDBySpecID then
        local heroNodeID, heroEntryID = lib:GetSubTreeSelectionNodeIDAndEntryIDBySpecID(specID, build.subTreeID)
        if heroNodeID and heroEntryID then
            AddEntry(heroNodeID, 1, heroEntryID, true)
        end
    end

    for rawNodeID, value in pairs(build.nodes or {}) do
        local nodeID = tonumber(rawNodeID)
        if nodeID then
            local rank, entryID
            if type(value) == "number" then
                rank = value
            elseif type(value) == "table" then
                rank = tonumber(value.rank or value.ranks or value[1])
                entryID = tonumber(value.entryID or value.entryId)
            end
            if rank and rank > 0 then
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo and nodeInfo.ID ~= 0 then
                    local isChoice = IsChoiceNodeType(nodeInfo.type)
                    if isChoice and not entryID and nodeInfo.entryIDs and nodeInfo.entryIDs[1] then
                        entryID = nodeInfo.entryIDs[1]
                    end
                    AddEntry(nodeID, rank, entryID, isChoice)
                end
            end
        end
    end

    if type(build.entries) == "table" then
        for rawNodeID, entryID in pairs(build.entries) do
            local nodeID = tonumber(rawNodeID)
            entryID = tonumber(entryID)
            if nodeID and entryID then
                if entryInfo[nodeID] then
                    entryInfo[nodeID].selectionEntryID = entryID
                    entryInfo[nodeID].isChoiceNode = true
                else
                    AddEntry(nodeID, 1, entryID, true)
                end
            end
        end
    end

    return entryInfo
end

local function TryPurchaseEntry(configID, entry)
    if NodeMatchesEntry(configID, entry) then
        return true
    end

    if entry.isChoiceNode then
        if not entry.selectionEntryID then
            return false
        end
        if C_Traits.SetSelection(configID, entry.nodeID, entry.selectionEntryID) then
            return NodeMatchesEntry(configID, entry)
        end
        return false
    end

    if not entry.ranksPurchased then
        return false
    end

    local nodeInfo = C_Traits.GetNodeInfo(configID, entry.nodeID)
    local currentRank = nodeInfo and nodeInfo.ranksPurchased or 0
    for _ = currentRank + 1, entry.ranksPurchased do
        if not C_Traits.PurchaseRank(configID, entry.nodeID) then
            break
        end
    end
    return NodeMatchesEntry(configID, entry)
end

local function ResetAndPurchase(configID, treeID, entryInfo, onComplete)
    applyToken = applyToken + 1
    local myToken = applyToken

    C_Traits.ResetTree(configID, treeID)

    local orderedNodes = GetOrderedTreeNodes(treeID)
    local index = 1
    local passProgress = 0
    local idlePasses = 0
    local MAX_IDLE_PASSES = 5

    local function finish()
        local remaining = CountEntries(entryInfo)
        if remaining > 0 then
            print(string.format(
                "|cffffcc00LPL:|r Talent apply incomplete: %d node%s could not be purchased (often class-tree choices). Open the talent window to finish manually.",
                remaining,
                remaining == 1 and "" or "s"
            ))
        end
        if onComplete then
            onComplete(remaining == 0)
        end
    end

    local function step()
        if myToken ~= applyToken then
            return
        end

        local processed = 0
        while index <= #orderedNodes and processed < BATCH_SIZE do
            local nodeID = orderedNodes[index]
            local entry = entryInfo[nodeID]
            if entry and TryPurchaseEntry(configID, entry) then
                passProgress = passProgress + 1
                entryInfo[nodeID] = nil
            end
            index = index + 1
            processed = processed + 1
        end

        if index <= #orderedNodes then
            C_Timer.After(0, step)
            return
        end

        if not next(entryInfo) then
            finish()
            return
        end

        if passProgress > 0 then
            idlePasses = 0
            index = 1
            passProgress = 0
            C_Timer.After(0, step)
            return
        end

        idlePasses = idlePasses + 1
        if idlePasses < MAX_IDLE_PASSES then
            index = 1
            C_Timer.After(0, step)
            return
        end

        finish()
    end

    -- Purchases in the same frame as ResetTree often fail on class-tree choice nodes.
    C_Timer.After(0, step)
end

function LPL.TalentActivate:ApplyBuildNow(build)
    if not build or not build.specID then
        return Fail("Invalid build.")
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayer(build.restrictions) then
        local summary = LPL.SetRestrictions:GetSummaryLine(build.restrictions)
            or "another character, class, or specialization"
        return Fail("This build is restricted to " .. summary .. ".")
    end

    if not EnsureTalentAPIs() then
        return Fail("Talent APIs are unavailable.")
    end

    if InCombatLockdown and InCombatLockdown() then
        return Fail("Cannot change talents in combat.")
    end

    local playerClassID = GetPlayerClassID()
    if not playerClassID or playerClassID ~= tonumber(build.classID) then
        return Fail("This build is for a different class.")
    end

    local playerSpecID = GetPlayerSpecID()
    if not playerSpecID or playerSpecID ~= tonumber(build.specID) then
        return Fail("Specialization mismatch. Try activating again.")
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return Fail("No active talent loadout found.")
    end

    local treeID = ResolveTreeID(build, configID)
    if not treeID then
        return Fail("Could not resolve the talent tree.")
    end

    local entryInfo = BuildEntryInfo(build, configID, build.specID)
    if not next(entryInfo) then
        return Fail("This build has no talents to apply.")
    end

    local buildName = build.name or "Build"
    ResetAndPurchase(configID, treeID, entryInfo, function(fullyApplied)
        if not C_Traits.ConfigHasStagedChanges or not C_Traits.ConfigHasStagedChanges(configID) then
            if fullyApplied then
                Success(string.format('Applied "%s".', buildName))
            else
                Fail(string.format('Could not fully apply "%s".', buildName))
            end
            return
        end

        local commitID = configID
        if C_ClassTalents.GetLastSelectedSavedConfigID then
            commitID = C_ClassTalents.GetLastSelectedSavedConfigID(build.specID) or configID
        end

        if not C_ClassTalents.CommitConfig(commitID) then
            Fail("Could not commit talents. Open the talent window and apply changes manually.")
            return
        end

        if fullyApplied then
            Success(string.format('Applied "%s" to your active loadout.', buildName))
        else
            -- Partial apply still commits what succeeded (usually spec); warn instead of hard-failing the loadout.
            print(string.format(
                '|cffffcc00LPL:|r Applied "%s" with missing talent nodes. Check the class tree.',
                buildName
            ))
            InvokeComplete(true)
            if LPL.ActivateFeedback then
                LPL.ActivateFeedback:Play()
            end
        end
    end)

    return true
end

function LPL.TalentActivate:ApplyBuild(buildID, onComplete)
    if completeCallback and completeCallback ~= onComplete then
        local previous = completeCallback
        completeCallback = nil
        C_Timer.After(0, function()
            previous(false)
        end)
    end
    completeCallback = onComplete

    if not buildID then
        return Fail("No build selected.")
    end

    local build = LPL.BuildStore:Get(buildID)
    if not build then
        return Fail("Build not found.")
    end

    if not EnsureTalentAPIs() then
        return Fail("Talent APIs are unavailable.")
    end

    if InCombatLockdown and InCombatLockdown() then
        return Fail("Cannot change talents in combat.")
    end

    local playerClassID = GetPlayerClassID()
    if not playerClassID then
        return Fail("Could not determine your class.")
    end

    if playerClassID ~= tonumber(build.classID) then
        return Fail("This build is for a different class.")
    end

    local playerSpecID = GetPlayerSpecID()
    if playerSpecID and playerSpecID == tonumber(build.specID) then
        return self:ApplyBuildNow(build)
    end

    if pendingSpecSwitchBuildID then
        return Fail("A specialization change is already in progress.")
    end

    pendingSpecSwitchBuildID = buildID
    local ok, err = SwitchToSpec(build.specID)
    if not ok then
        pendingSpecSwitchBuildID = nil
        return Fail(err)
    end

    local _, specName = GetSpecializationInfoByID and GetSpecializationInfoByID(build.specID)
    LPL:SafePrintf(
        "|cff33cc33LPL:|r Switching to %s, then applying \"%s\"...",
        LPL:PlainStringOr(specName, "specialization"),
        LPL:PlainStringOr(build.name, "build")
    )
    return true
end
