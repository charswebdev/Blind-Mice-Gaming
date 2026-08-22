local addonName, LPL = ...

LPL.ActionBarCursor = {
    pending = nil,
    wowCursorPickup = false,
}

local codec = LPL.ActionBarCodec

local pickupFrame

local function EnsurePickupFrame()
    if pickupFrame then
        return pickupFrame
    end

    pickupFrame = CreateFrame("Frame", "LPLActionBarPickupCursor", UIParent)
    pickupFrame:SetFrameStrata("TOOLTIP")
    pickupFrame:SetFrameLevel(200)
    pickupFrame:SetSize(33, 33)
    pickupFrame:EnableMouse(false)
    pickupFrame:Hide()

    local border = pickupFrame:CreateTexture(nil, "BACKGROUND")
    border:SetPoint("TOPLEFT", pickupFrame, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", pickupFrame, "BOTTOMRIGHT", 2, -2)
    border:SetColorTexture(0, 0, 0, 0.65)

    local icon = pickupFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", pickupFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", pickupFrame, "BOTTOMRIGHT", -1, 1)
    pickupFrame.icon = icon

    pickupFrame:SetScript("OnUpdate", function(self)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    end)

    return pickupFrame
end

function LPL.ActionBarCursor:ShowPickupVisual(action)
    if not action or not action.type then
        self:HidePickupVisual()
        return
    end

    local iconTexture = codec:ResolveActionDisplay(action, false)
    if not iconTexture then
        self:HidePickupVisual()
        return
    end

    local frame = EnsurePickupFrame()
    frame.icon:SetTexture(iconTexture)
    frame:Show()
end

function LPL.ActionBarCursor:HidePickupVisual()
    if pickupFrame then
        pickupFrame:Hide()
    end
end

function LPL.ActionBarCursor:Clear()
    self.pending = nil
    self.wowCursorPickup = false
    self:HidePickupVisual()
    if ClearCursor then
        ClearCursor()
    end
end

function LPL.ActionBarCursor:HasPickup()
    return self.pending ~= nil
end

function LPL.ActionBarCursor:IsPendingFrom(slotID, isPet)
    local pending = self.pending
    if not pending then
        return false
    end
    return pending.sourceSlot == slotID and pending.sourceIsPet == isPet
end

function LPL.ActionBarCursor:PickupFromDraft(draftSet, slotID, isPet)
    local action = codec:GetStoredAction(draftSet, slotID, isPet)
    if not action or not action.type then
        return false
    end
    self.pending = {
        action = CopyTable(action),
        sourceSlot = slotID,
        sourceIsPet = isPet,
    }
    codec:ClearSlotAction(draftSet, slotID, isPet)

    -- Put the action on the real cursor so it can be dropped on Blizzard bars.
    -- If that succeeds, do not keep an LPL-only pending pickup: the game cursor
    -- is what both LPL slots and live bars will receive.
    if LPL.ActionBarActivate and LPL.ActionBarActivate.PickupAction then
        LPL.ActionBarActivate:PickupAction(action)
        if GetCursorInfo and GetCursorInfo() then
            self.pending = nil
            self.wowCursorPickup = false
            self:HidePickupVisual()
            return true
        end
    end

    self:ShowPickupVisual(self.pending.action)
    return true
end

function LPL.ActionBarCursor:PlaceOnSlot(draftSet, slotID, isPet)
    local newAction
    local sourceSlot
    local sourceIsPet

    if self.pending then
        newAction = CopyTable(self.pending.action)
        sourceSlot = self.pending.sourceSlot
        sourceIsPet = self.pending.sourceIsPet
        self.pending = nil
        self.wowCursorPickup = false
        self:HidePickupVisual()
        if ClearCursor then
            ClearCursor()
        end
    else
        if isPet then
            newAction = codec:BuildPetActionTableFromCursor()
            if not newAction then
                newAction = codec:BuildActionTableFromCursor()
                if newAction and newAction.type == "spell" then
                    newAction = {
                        type = "petspell",
                        id = newAction.id,
                        spellID = newAction.id,
                        icon = newAction.icon,
                        name = newAction.name,
                    }
                end
            end
        else
            newAction = codec:BuildActionTableFromCursor()
        end
        if not newAction or not newAction.type then
            return false
        end
        if ClearCursor then
            ClearCursor()
        end
    end

    local oldDest = codec:GetStoredAction(draftSet, slotID, isPet)
    codec:SetSlotAction(draftSet, slotID, isPet, newAction)

    if sourceSlot then
        if sourceSlot ~= slotID or sourceIsPet ~= isPet then
            if oldDest and oldDest.type then
                codec:SetSlotAction(draftSet, sourceSlot, sourceIsPet, oldDest)
            else
                codec:ClearSlotAction(draftSet, sourceSlot, sourceIsPet)
            end
        end
    end

    return true
end

function LPL.ActionBarCursor:CanEdit()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot edit action bars in combat."
    end
    return true
end
