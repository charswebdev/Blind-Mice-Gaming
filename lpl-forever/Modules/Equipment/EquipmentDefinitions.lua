local addonName, LPL = ...

LPL.EquipmentDefinitions = {
    SLOT_SIZE = 38,
    SLOT_GAP = 4,
    WEAPON_GAP = 8,
    MODEL_WIDTH = 200,
    MODEL_HEIGHT = 280,
    MODEL_VERTICAL_OFFSET = 28,
    COLUMN_GAP = 10,
    WEAPON_ROW_GAP = 12,
    DETAIL_WIDTH = 130,
    DETAIL_HEIGHT = 34,
    NAME_ROW_HEIGHT = 12,
    SLOT_ROW_HEIGHT = 36,
    GEM_ICON_SIZE = 12,
    ITEM_LEVEL_FONT_SIZE = 14,
    UPGRADE_TRACK_HEIGHT = 3,
    UPGRADE_TRACK_INSET = 3,
    UPGRADE_TRACK_GAP = 1,
    MAX_UPGRADE_SEGMENTS = 16,
    EMPTY_SLOT_TEXTURE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot",
}

LPL.EquipmentDefinitions.LEFT_SLOTS = {
    1, 2, 3, 15, 5, 4, 19, 9,
}

LPL.EquipmentDefinitions.RIGHT_SLOTS = {
    10, 6, 7, 8, 11, 12, 13, 14,
}

LPL.EquipmentDefinitions.WEAPON_SLOTS = {
    16, 17, 18,
}

LPL.EquipmentDefinitions.SLOT_LABELS = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [4] = "Shirt",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Finger 1",
    [12] = "Finger 2",
    [13] = "Trinket 1",
    [14] = "Trinket 2",
    [15] = "Back",
    [16] = "Main Hand",
    [17] = "Off Hand",
    [18] = "Ranged",
    [19] = "Tabard",
}

function LPL.EquipmentDefinitions:GetSlotLabel(slotID)
    slotID = tonumber(slotID)
    if not slotID then
        return "Slot"
    end
    return self.SLOT_LABELS[slotID] or string.format("Slot %d", slotID)
end

function LPL.EquipmentDefinitions:GetRowHeight()
    return self.NAME_ROW_HEIGHT + self.SLOT_ROW_HEIGHT
end

function LPL.EquipmentDefinitions:GetRowStride()
    return self:GetRowHeight() + self.SLOT_GAP
end

function LPL.EquipmentDefinitions:GetColumnOffsetY(slotCount, index)
    return ((slotCount - 1) / 2 - (index - 1)) * self:GetRowStride()
end

function LPL.EquipmentDefinitions:GetLowestColumnBottomOffsetY(slotCount)
    slotCount = slotCount or math.max(#self.LEFT_SLOTS, #self.RIGHT_SLOTS)
    local lastOffsetY = self:GetColumnOffsetY(slotCount, slotCount)
    return lastOffsetY - (self:GetRowHeight() / 2)
end

function LPL.EquipmentDefinitions:GetWeaponRowTopOffsetY()
    return self:GetLowestColumnBottomOffsetY() - self.WEAPON_ROW_GAP
end

function LPL.EquipmentDefinitions:GetWeaponRowBottomOffsetY()
    return self:GetWeaponRowTopOffsetY() - self:GetRowHeight()
end

function LPL.EquipmentDefinitions:PlayerUsesRangedSlot()
    if UnitClass then
        local _, classFile = UnitClass("player")
        if classFile == "HUNTER" then
            return true
        end
    end
    return false
end

function LPL.EquipmentDefinitions:ShouldShowSlot(slotID)
    slotID = tonumber(slotID)
    if slotID == 18 then
        return self:PlayerUsesRangedSlot()
    end
    return slotID ~= nil
end

function LPL.EquipmentDefinitions:GetVisibleWeaponSlots()
    local slots = {}
    for _, slotID in ipairs(self.WEAPON_SLOTS) do
        if self:ShouldShowSlot(slotID) then
            slots[#slots + 1] = slotID
        end
    end
    return slots
end

function LPL.EquipmentDefinitions:GetAllSlotIDs()
    local slots = {}
    local seen = {}
    for _, group in ipairs({ self.LEFT_SLOTS, self.RIGHT_SLOTS, self.WEAPON_SLOTS }) do
        for _, slotID in ipairs(group) do
            if not seen[slotID] then
                seen[slotID] = true
                slots[#slots + 1] = slotID
            end
        end
    end
    return slots
end

function LPL.EquipmentDefinitions:GetEditorSlotIDs()
    local slots = {}
    for _, slotID in ipairs(self:GetAllSlotIDs()) do
        if self:ShouldShowSlot(slotID) then
            slots[#slots + 1] = slotID
        end
    end
    return slots
end
