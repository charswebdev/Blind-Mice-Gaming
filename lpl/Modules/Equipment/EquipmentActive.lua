local addonName, LPL = ...

LPL.EquipmentActive = {}

local defs = LPL.EquipmentDefinitions
local codec = LPL.EquipmentCodec

function LPL.EquipmentActive:IsActive(set)
    if type(set) ~= "table" then
        return false
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(set) then
        return false
    end

    for _, slotID in ipairs(defs:GetAllSlotIDs()) do
        if not codec:IsSlotIgnored(set, slotID) then
            local entry = set.slots and set.slots[slotID]
            local targetItemID = codec:GetSlotItemID(entry)

            if targetItemID then
                if not codec:SlotMatchesEntry(slotID, entry) then
                    return false
                end
            elseif codec:InventorySlotHasItem(slotID) then
                return false
            end
        end
    end

    return true
end
