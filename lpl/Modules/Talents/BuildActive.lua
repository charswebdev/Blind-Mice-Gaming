local addonName, LPL = ...

LPL.BuildActive = {}

function LPL.BuildActive:IsActive(build)
    if type(build) ~= "table" or type(build.nodes) ~= "table" then
        return false
    end

    if C_SpecializationInfo and C_SpecializationInfo.CanPlayerUseTalentSpecUI
        and not C_SpecializationInfo.CanPlayerUseTalentSpecUI() then
        return false
    end

    if not C_ClassTalents or not C_Traits or not C_ClassTalents.GetActiveConfigID then
        return false
    end

    local selectionType = Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection
    local subTreeSelectionType = Enum and Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection

    local playerSpecID = LPL.Character:GetSpecID()
    if playerSpecID and build.specID and tonumber(build.specID) ~= tonumber(playerSpecID) then
        return false
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return false
    end

    for rawNodeID, value in pairs(build.nodes) do
        local nodeID = tonumber(rawNodeID)
        if nodeID then
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo and nodeInfo.ID ~= 0 and nodeInfo.isVisible then
                local rank, entryID
                if type(value) == "table" then
                    rank = tonumber(value.rank or value.ranks or value[1]) or 0
                    entryID = tonumber(value.entryID or value.entryId)
                else
                    rank = tonumber(value) or 0
                end

                local isChoice = (selectionType and nodeInfo.type == selectionType)
                    or (subTreeSelectionType and nodeInfo.type == subTreeSelectionType)

                if isChoice and nodeInfo.entryIDs and #nodeInfo.entryIDs > 1 then
                    local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
                    local expectedEntryID = entryID or nodeInfo.entryIDs[rank] or nodeInfo.entryIDs[1]
                    if activeEntryID ~= expectedEntryID then
                        return false
                    end
                elseif (nodeInfo.ranksPurchased or 0) ~= rank then
                    return false
                end
            end
        end
    end

    return true
end
