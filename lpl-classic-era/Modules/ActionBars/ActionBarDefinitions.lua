local addonName, LPL = ...

LPL.ActionBarDefinitions = {
    SLOT_SIZE = 33,
    SLOT_GAP = 2,
    LABEL_WIDTH = 88,
    LOCK_SIZE = 28,
    ROW_HEIGHT = 36,
    ROW_GAP = 6,
    SCROLL_PADDING = 12,
    MIN_SCROLL_WIDTH = 580,
    PET_SLOT_MAX = _G.NUM_PET_ACTION_SLOTS or 10,
}

-- Classic Era slot map: Main through Bar 8 + stance forms + pet.
-- No Skyriding (121–132). Possess (133–144) is never managed.
LPL.ActionBarDefinitions.PANEL_ROWS = {
    { label = "Main Bar", firstSlot = 1, lastSlot = 12, isPet = false },
    { label = "Page 2", firstSlot = 13, lastSlot = 24, isPet = false },
    { label = "Bar 2", firstSlot = 61, lastSlot = 72, isPet = false },
    { label = "Bar 3", firstSlot = 49, lastSlot = 60, isPet = false },
    { label = "Bar 4", firstSlot = 25, lastSlot = 36, isPet = false },
    { label = "Bar 5", firstSlot = 37, lastSlot = 48, isPet = false },
    { label = "Bar 6", firstSlot = 145, lastSlot = 156, isPet = false },
    { label = "Bar 7", firstSlot = 157, lastSlot = 168, isPet = false },
    { label = "Bar 8", firstSlot = 169, lastSlot = 180, isPet = false },
    { label = "Form 1", firstSlot = 73, lastSlot = 84, isPet = false },
    { label = "Form 2", firstSlot = 85, lastSlot = 96, isPet = false },
    { label = "Form 3", firstSlot = 97, lastSlot = 108, isPet = false },
    { label = "Form 4", firstSlot = 109, lastSlot = 120, isPet = false },
    { label = "Pet Bar", firstSlot = 1, lastSlot = nil, isPet = true },
}

function LPL.ActionBarDefinitions:IsManagedPlayerSlot(slotID)
    slotID = tonumber(slotID)
    if not slotID then
        return false
    end
    -- Possess / vehicle override range — never manage.
    if slotID >= 133 and slotID <= 144 then
        return false
    end
    -- Skyriding bar — not on Classic Era.
    if slotID >= 121 and slotID <= 132 then
        return false
    end
    -- Standard bars 1–120 and extra bars 6–8 (145–180).
    if slotID >= 1 and slotID <= 120 then
        return true
    end
    if slotID >= 145 and slotID <= 180 then
        return true
    end
    return false
end

function LPL.ActionBarDefinitions:GetRowSlotCount(rowDef)
    if not rowDef then
        return 0
    end
    if rowDef.isPet then
        return self.PET_SLOT_MAX
    end
    return rowDef.lastSlot - rowDef.firstSlot + 1
end

function LPL.ActionBarDefinitions:GetRowEndSlot(rowDef)
    if not rowDef then
        return 0
    end
    if rowDef.isPet then
        return self.PET_SLOT_MAX
    end
    return rowDef.lastSlot
end

function LPL.ActionBarDefinitions:GetRowContentWidth(rowDef)
    local defs = self
    local slots = self:GetRowSlotCount(rowDef)
    return defs.LABEL_WIDTH
        + (slots * (defs.SLOT_SIZE + defs.SLOT_GAP))
        + defs.LOCK_SIZE
        + 8
end

function LPL.ActionBarDefinitions:GetMaxContentWidth()
    local maxWidth = self.MIN_SCROLL_WIDTH
    for _, rowDef in ipairs(self.PANEL_ROWS) do
        maxWidth = math.max(maxWidth, self:GetRowContentWidth(rowDef))
    end
    return maxWidth
end

function LPL.ActionBarDefinitions:GetManagedPlayerSlots()
    if self._managedPlayerSlots then
        return self._managedPlayerSlots
    end

    local seen = {}
    local slots = {}
    for _, rowDef in ipairs(self.PANEL_ROWS) do
        if not rowDef.isPet then
            for slotID = rowDef.firstSlot, rowDef.lastSlot do
                if self:IsManagedPlayerSlot(slotID) and not seen[slotID] then
                    seen[slotID] = true
                    slots[#slots + 1] = slotID
                end
            end
        end
    end
    table.sort(slots)
    self._managedPlayerSlots = slots
    return slots
end
