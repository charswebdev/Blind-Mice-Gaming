local addonName, LPL = ...

LPL.PvpTalentActive = {}

local function GetSelectedTalentID(slotIndex)
    if not C_SpecializationInfo or not C_SpecializationInfo.GetPvpTalentSlotInfo then
        return nil
    end
    local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex)
    return slotInfo and tonumber(slotInfo.selectedTalentID) or nil
end

function LPL.PvpTalentActive:IsActive(set)
    if type(set) ~= "table" then
        return false
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(set) then
        return false
    end

    local _, playerSpecID = LPL.PvpTalentCodec:GetPlayerClassAndSpec()
    local setSpecID = tonumber(set.specID)
    if setSpecID and playerSpecID and setSpecID ~= playerSpecID then
        return false
    end

    local slotCount = (LPL.PvpTalentStore and LPL.PvpTalentStore.SLOT_COUNT) or 3
    local hasAny = false
    for slot = 1, slotCount do
        local wanted = set.talents and tonumber(set.talents[slot])
        if wanted and wanted > 0 then
            hasAny = true
            if GetSelectedTalentID(slot) ~= wanted then
                return false
            end
        end
    end

    -- Empty sets are never "active" (avoids every blank set lighting up).
    return hasAny
end
