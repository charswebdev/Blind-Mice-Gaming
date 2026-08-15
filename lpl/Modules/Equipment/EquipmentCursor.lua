local addonName, LPL = ...

LPL.EquipmentCursor = {
    pending = nil,
}

local codec = LPL.EquipmentCodec
local defs = LPL.EquipmentDefinitions

local pickupFrame

local function EnsurePickupFrame()
    if pickupFrame then
        return pickupFrame
    end

    pickupFrame = CreateFrame("Frame", "LPLEquipmentPickupCursor", UIParent)
    pickupFrame:SetFrameStrata("TOOLTIP")
    pickupFrame:SetFrameLevel(200)
    pickupFrame:SetSize(defs.SLOT_SIZE, defs.SLOT_SIZE)
    pickupFrame:EnableMouse(false)
    pickupFrame:Hide()

    local border = pickupFrame:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", pickupFrame, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", pickupFrame, "BOTTOMRIGHT", 2, -2)
    border:SetColorTexture(0, 0, 0, 0.65)

    local icon = pickupFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", pickupFrame, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", pickupFrame, "BOTTOMRIGHT", -3, 3)
    pickupFrame.icon = icon

    pickupFrame:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)

    return pickupFrame
end

local function ResolveEntryIcon(entry)
    if not entry then
        return defs.EMPTY_SLOT_TEXTURE
    end
    if entry.icon then
        return entry.icon
    end
    local itemID = codec:GetSlotItemID(entry)
    if itemID and C_Item and C_Item.GetItemIconByID then
        return C_Item.GetItemIconByID(itemID) or defs.EMPTY_SLOT_TEXTURE
    end
    if itemID and GetItemIcon then
        return GetItemIcon(itemID) or defs.EMPTY_SLOT_TEXTURE
    end
    return defs.EMPTY_SLOT_TEXTURE
end

function LPL.EquipmentCursor:ShowPickupVisual(entry)
    if not entry or not codec:GetSlotItemID(entry) then
        self:HidePickupVisual()
        return
    end

    local frame = EnsurePickupFrame()
    frame.icon:SetTexture(ResolveEntryIcon(entry))
    frame:Show()
end

function LPL.EquipmentCursor:HidePickupVisual()
    if pickupFrame then
        pickupFrame:Hide()
    end
end

function LPL.EquipmentCursor:Clear()
    self.pending = nil
    self:HidePickupVisual()
    if ClearCursor then
        ClearCursor()
    end
end

function LPL.EquipmentCursor:HasPickup()
    return self.pending ~= nil
end

function LPL.EquipmentCursor:IsPendingFrom(slotID)
    local pending = self.pending
    if not pending then
        return false
    end
    return pending.sourceSlot == slotID
end

function LPL.EquipmentCursor:PickupFromDraft(draftSet, slotID)
    slotID = tonumber(slotID)
    if not draftSet or not slotID then
        return false
    end

    local entry = codec:GetSlotEntry(draftSet, slotID)
    if not entry or entry.cleared or not codec:GetSlotItemID(entry) then
        return false
    end

    self.pending = {
        entry = codec:CloneSlotEntry(entry),
        sourceSlot = slotID,
    }
    codec:RemoveSlot(draftSet, slotID)
    self:ShowPickupVisual(self.pending.entry)
    return true
end

function LPL.EquipmentCursor:PlaceOnSlot(draftSet, slotID)
    slotID = tonumber(slotID)
    if not draftSet or not slotID then
        return false, "No equipment set is open."
    end

    if codec:IsSlotIgnored(draftSet, slotID) then
        return false, "That slot is ignored."
    end

    if self.pending then
        local newEntry = codec:CloneSlotEntry(self.pending.entry)
        local sourceSlot = self.pending.sourceSlot
        self.pending = nil
        self:HidePickupVisual()

        if not newEntry or not codec:GetSlotItemID(newEntry) then
            return false
        end

        if not codec:ItemFitsInventorySlot(newEntry.itemID, slotID) then
            if sourceSlot then
                codec:SetSlotEntry(draftSet, sourceSlot, newEntry)
            end
            return false, "That item does not belong in this slot."
        end

        local destEntry = codec:GetSlotEntry(draftSet, slotID)
        local oldDest = destEntry and codec:CloneSlotEntry(destEntry) or nil
        local hadDestItem = oldDest and codec:GetSlotItemID(oldDest) and not oldDest.cleared

        codec:SetSlotEntry(draftSet, slotID, newEntry)

        if sourceSlot and sourceSlot ~= slotID then
            if hadDestItem and codec:ItemFitsInventorySlot(oldDest.itemID, sourceSlot) then
                codec:SetSlotEntry(draftSet, sourceSlot, oldDest)
            else
                codec:RemoveSlot(draftSet, sourceSlot)
            end
        end

        return true
    end

    return codec:TryAssignCursorToSlot(draftSet, slotID)
end
