local addonName, LPL = ...

LPL.EquipmentCodec = {}

local defs = LPL.EquipmentDefinitions

local EQUIP_LOC_TO_SLOTS = {
    INVTYPE_HEAD = { 1 },
    INVTYPE_NECK = { 2 },
    INVTYPE_SHOULDER = { 3 },
    INVTYPE_BODY = { 4 },
    INVTYPE_CHEST = { 5 },
    INVTYPE_ROBE = { 5 },
    INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 },
    INVTYPE_FEET = { 8 },
    INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 },
    INVTYPE_FINGER = { 11, 12 },
    INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 },
    INVTYPE_WEAPON = { 16, 17 },
    INVTYPE_WEAPONMAINHAND = { 16 },
    INVTYPE_2HWEAPON = { 16 },
    INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_SHIELD = { 17 },
    INVTYPE_HOLDABLE = { 17 },
    INVTYPE_RANGED = { 18 },
    INVTYPE_RANGEDRIGHT = { 18 },
    INVTYPE_TABARD = { 19 },
}

-- Enum.InventoryType values from C_Item.GetItemInventoryTypeByID
local INV_TYPE_TO_SLOTS = {
    [1] = { 1 },
    [2] = { 2 },
    [3] = { 3 },
    [4] = { 4 },
    [5] = { 5 },
    [6] = { 6 },
    [7] = { 7 },
    [8] = { 8 },
    [9] = { 9 },
    [10] = { 10 },
    [11] = { 11, 12 },
    [12] = { 13, 14 },
    [13] = { 16, 17 },
    [14] = { 17 },
    [15] = { 18 },
    [16] = { 15 },
    [17] = { 16 },
    [20] = { 19 },
    [21] = { 5 },
    [22] = { 16 },
    [23] = { 17 },
    [24] = { 17 },
    [26] = { 16 },
    [27] = { 18 },
}

local function Trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or ""
end

function LPL.EquipmentCodec:CanEdit()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot edit equipment sets in combat."
    end
    return true
end

function LPL.EquipmentCodec:SafeItemNumber(value)
    if value == nil then
        return nil
    end
    if type(value) == "number" then
        return value > 0 and value or nil
    end
    if type(value) == "string" then
        return tonumber(value)
    end
    if LPL.PlainString then
        local text = LPL:PlainString(value)
        if text then
            return tonumber(text)
        end
    end
    return nil
end

function LPL.EquipmentCodec:GetItemIDFromLink(link)
    if not link then
        return nil
    end
    if LPL.PlainString then
        link = LPL:PlainString(link)
    end
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

function LPL.EquipmentCodec:GetEquipmentItemLocation(invSlotID)
    invSlotID = tonumber(invSlotID)
    if not invSlotID or not ItemLocation or not ItemLocation.CreateFromEquipmentSlot then
        return nil
    end
    local loc = ItemLocation:CreateFromEquipmentSlot(invSlotID)
    if loc and loc.IsValid and loc:IsValid() then
        return loc
    end
    return nil
end

function LPL.EquipmentCodec:GetBagItemLocation(bagID, slotIndex)
    bagID = tonumber(bagID)
    slotIndex = tonumber(slotIndex)
    if not bagID or not slotIndex or not ItemLocation or not ItemLocation.CreateFromBagAndSlot then
        return nil
    end
    local loc = ItemLocation:CreateFromBagAndSlot(bagID, slotIndex)
    if loc and loc.IsValid and loc:IsValid() then
        return loc
    end
    return nil
end

function LPL.EquipmentCodec:GetEquippedItemID(invSlotID)
    invSlotID = tonumber(invSlotID)
    if not invSlotID then
        return nil
    end

    if C_Item and C_Item.GetItemID then
        local loc = self:GetEquipmentItemLocation(invSlotID)
        if loc then
            local itemID = C_Item.GetItemID(loc)
            if itemID then
                return itemID
            end
        end
    end

    if GetInventoryItemID then
        local itemID = self:SafeItemNumber(GetInventoryItemID("player", invSlotID))
        if itemID then
            return itemID
        end
    end

    if GetInventoryItemLink then
        return self:GetItemIDFromLink(GetInventoryItemLink("player", invSlotID))
    end

    return nil
end

function LPL.EquipmentCodec:GetBagItemID(bagID, slotIndex)
    bagID = tonumber(bagID)
    slotIndex = tonumber(slotIndex)
    if not bagID or not slotIndex then
        return nil
    end

    if C_Item and C_Item.GetItemID then
        local loc = self:GetBagItemLocation(bagID, slotIndex)
        if loc then
            local itemID = C_Item.GetItemID(loc)
            if itemID then
                return itemID
            end
        end
    end

    local itemID
    if C_Container and C_Container.GetContainerItemID then
        itemID = self:SafeItemNumber(C_Container.GetContainerItemID(bagID, slotIndex))
    elseif GetContainerItemID then
        itemID = self:SafeItemNumber(GetContainerItemID(bagID, slotIndex))
    end
    if itemID then
        return itemID
    end

    local link
    if C_Container and C_Container.GetContainerItemLink then
        link = C_Container.GetContainerItemLink(bagID, slotIndex)
    elseif GetContainerItemLink then
        link = GetContainerItemLink(bagID, slotIndex)
    end
    return self:GetItemIDFromLink(link)
end

function LPL.EquipmentCodec:BagSlotIsEmpty(bagID, slotIndex)
    if self:GetBagItemLocation(bagID, slotIndex) then
        return false
    end
    if C_Container and C_Container.GetContainerItemInfo then
        local info = C_Container.GetContainerItemInfo(bagID, slotIndex)
        return not info or not info.iconFileID
    end
    return not self:GetBagItemID(bagID, slotIndex)
end

function LPL.EquipmentCodec:SlotMatchesEntry(invSlotID, entry)
    invSlotID = tonumber(invSlotID)
    if not invSlotID or type(entry) ~= "table" then
        return false
    end

    if entry.cleared then
        return not self:InventorySlotHasItem(invSlotID)
    end

    local targetItemID = tonumber(entry.itemID)
    if not targetItemID or targetItemID < 1 then
        return false
    end

    if not self:InventorySlotHasItem(invSlotID) then
        return false
    end

    local equippedID = self:GetEquippedItemID(invSlotID)
    if not equippedID and GetInventoryItemLink then
        local equippedLink = GetInventoryItemLink("player", invSlotID)
        equippedID = self:GetItemIDFromLink(equippedLink)
    end
    if equippedID then
        return equippedID == targetItemID
    end

    if entry.link and GetInventoryItemLink then
        local equippedLink = GetInventoryItemLink("player", invSlotID)
        if LPL.PlainString then
            equippedLink = LPL:PlainString(equippedLink)
        end
        local entryLink = entry.link
        if LPL.PlainString then
            entryLink = LPL:PlainString(entryLink)
        end
        if equippedLink and entryLink and equippedLink == entryLink then
            return true
        end
    end

    return false
end

function LPL.EquipmentCodec:InventorySlotHasItem(invSlotID)
    invSlotID = tonumber(invSlotID)
    if not invSlotID then
        return false
    end

    if self:GetEquipmentItemLocation(invSlotID) then
        return true
    end

    if GetInventoryItemLink and GetInventoryItemLink("player", invSlotID) ~= nil then
        return true
    end

    if GetInventoryItemTexture then
        local texture = GetInventoryItemTexture("player", invSlotID)
        if texture then
            return true
        end
    end

    return self:GetEquippedItemID(invSlotID) ~= nil
end

function LPL.EquipmentCodec:IsSlotCleared(set, slotID)
    if not set or not slotID then
        return false
    end
    local entry = set.slots and set.slots[slotID]
    return type(entry) == "table" and entry.cleared == true
end

function LPL.EquipmentCodec:GetSlotItemID(entry)
    if type(entry) ~= "table" or entry.cleared then
        return nil
    end
    local itemID = tonumber(entry.itemID)
    if itemID and itemID > 0 then
        return itemID
    end
    if entry.link then
        return self:GetItemIDFromLink(entry.link)
    end
    return nil
end

function LPL.EquipmentCodec:IsSlotIgnored(draftSet, slotID)
    if not draftSet or not slotID then
        return false
    end
    -- Explicit clear means this slot must be emptied on activate.
    if self:IsSlotCleared(draftSet, slotID) then
        return false
    end
    return draftSet.ignored and draftSet.ignored[slotID] == true
end

function LPL.EquipmentCodec:ToggleSlotIgnore(draftSet, slotID)
    if not draftSet or not slotID then
        return
    end
    draftSet.ignored = draftSet.ignored or {}
    if draftSet.ignored[slotID] then
        draftSet.ignored[slotID] = nil
    else
        draftSet.ignored[slotID] = true
    end
end

function LPL.EquipmentCodec:GetSlotEntry(draftSet, slotID)
    if not draftSet or not slotID then
        return nil
    end
    return draftSet.slots and draftSet.slots[slotID]
end

function LPL.EquipmentCodec:CloneSlotEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end
    if entry.cleared then
        return { cleared = true }
    end
    if not self:GetSlotItemID(entry) then
        return nil
    end
    return CopyTable(entry)
end

function LPL.EquipmentCodec:SetSlotEntry(draftSet, slotID, entry)
    if not draftSet or not slotID then
        return
    end
    draftSet.slots = draftSet.slots or {}
    if entry then
        draftSet.slots[slotID] = entry
    else
        draftSet.slots[slotID] = nil
    end
end

function LPL.EquipmentCodec:RemoveSlot(draftSet, slotID)
    if draftSet and draftSet.slots then
        draftSet.slots[slotID] = nil
    end
end

function LPL.EquipmentCodec:ClearSlot(draftSet, slotID)
    if not draftSet or not slotID then
        return
    end
    draftSet.slots = draftSet.slots or {}
    draftSet.slots[slotID] = { cleared = true }
    if draftSet.ignored and draftSet.ignored[slotID] then
        draftSet.ignored[slotID] = nil
    end
end

function LPL.EquipmentCodec:NormalizeSlotEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if entry.cleared then
        return { cleared = true }
    end

    local itemID = tonumber(entry.itemID)
    if not itemID or itemID < 1 then
        return nil
    end

    local normalized = {
        itemID = itemID,
    }

    if type(entry.link) == "string" and entry.link ~= "" then
        normalized.link = entry.link
    end

    if type(entry.name) == "string" and entry.name ~= "" then
        normalized.name = Trim(entry.name)
    elseif C_Item and C_Item.GetItemNameByID then
        local name = C_Item.GetItemNameByID(itemID)
        if LPL.PlainString then
            name = LPL:PlainString(name)
        end
        if name then
            normalized.name = name
        end
    end

    local icon = tonumber(entry.icon)
    if icon then
        normalized.icon = icon
    elseif C_Item and C_Item.GetItemIconByID then
        normalized.icon = C_Item.GetItemIconByID(itemID)
    elseif GetItemIcon then
        normalized.icon = GetItemIcon(itemID)
    end

    if entry.location then
        normalized.location = entry.location
    end

    if LPL.EquipmentItemInfo then
        LPL.EquipmentItemInfo:EnrichEntry(normalized, normalized.link)
    end

    return normalized
end

function LPL.EquipmentCodec:GetItemEquipLoc(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    if GetItemInfoInstant then
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfoInstant(itemID)
        if type(equipLoc) == "string" and equipLoc ~= "" then
            return equipLoc
        end
    end

    if GetItemInfo then
        local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemID)
        if type(equipLoc) == "string" and equipLoc ~= "" then
            return equipLoc
        end
    end

    return nil
end

function LPL.EquipmentCodec:GetAllowedSlotsForItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return nil
    end

    if C_Item and C_Item.GetItemInventoryTypeByID then
        local invType = C_Item.GetItemInventoryTypeByID(itemID)
        if type(invType) == "number" and INV_TYPE_TO_SLOTS[invType] then
            return INV_TYPE_TO_SLOTS[invType]
        end
    end

    local equipLoc = self:GetItemEquipLoc(itemID)
    if equipLoc then
        return EQUIP_LOC_TO_SLOTS[equipLoc]
    end

    return nil
end

function LPL.EquipmentCodec:ItemFitsInventorySlot(itemID, slotID)
    itemID = tonumber(itemID)
    slotID = tonumber(slotID)
    if not itemID or not slotID then
        return false
    end

    local allowedSlots = self:GetAllowedSlotsForItem(itemID)
    if not allowedSlots then
        return false
    end

    for _, allowedSlot in ipairs(allowedSlots) do
        if allowedSlot == slotID then
            return true
        end
    end

    return false
end

function LPL.EquipmentCodec:BuildSlotEntryFromItemID(itemID, link)
    itemID = tonumber(itemID)
    if not itemID or itemID < 1 then
        return nil
    end

    if LPL.PlainString and link then
        link = LPL:PlainString(link)
    end

    local name
    local icon
    if GetItemInfo then
        name, _, _, _, _, _, _, _, _, icon = GetItemInfo(itemID)
    end
    if not name and C_Item and C_Item.GetItemNameByID then
        name = C_Item.GetItemNameByID(itemID)
    end
    if not icon and C_Item and C_Item.GetItemIconByID then
        icon = C_Item.GetItemIconByID(itemID)
    end
    if not icon and GetItemIcon then
        icon = GetItemIcon(itemID)
    end
    if LPL.PlainString then
        name = LPL:PlainString(name)
    end

    return {
        itemID = itemID,
        link = link,
        name = name,
        icon = icon,
    }
end

function LPL.EquipmentCodec:BuildSlotEntryFromBag(bagID, slotIndex)
    bagID = tonumber(bagID)
    slotIndex = tonumber(slotIndex)
    if not bagID or not slotIndex then
        return nil
    end

    local itemID
    local link
    if C_Container then
        if C_Container.GetContainerItemID then
            itemID = C_Container.GetContainerItemID(bagID, slotIndex)
        end
        if C_Container.GetContainerItemLink then
            link = C_Container.GetContainerItemLink(bagID, slotIndex)
        end
    end
    if not itemID and GetContainerItemID then
        itemID = GetContainerItemID(bagID, slotIndex)
    end
    if not link and GetContainerItemLink then
        link = GetContainerItemLink(bagID, slotIndex)
    end

    local entry = self:BuildSlotEntryFromItemID(itemID, link)
    if entry then
        entry.location = self:PackBagLocation(bagID, slotIndex)
    end
    return entry
end

function LPL.EquipmentCodec:GetBagCursorItem()
    if not GetCursorInfo then
        return nil
    end

    local cursorType, itemID, itemLink, bagID, slotIndex = GetCursorInfo()
    if cursorType ~= "item" then
        return nil
    end

    itemID = tonumber(itemID)
    if not itemID or itemID < 1 then
        return nil
    end

    if LPL.PlainString and itemLink then
        itemLink = LPL:PlainString(itemLink)
    end

    return {
        itemID = itemID,
        link = itemLink,
        bagID = tonumber(bagID),
        slotIndex = tonumber(slotIndex),
    }
end

function LPL.EquipmentCodec:AssignItemToSlot(draftSet, invSlotID, itemID, itemLink, bagID, slotIndex)
    if not draftSet or not invSlotID then
        return false, "No equipment set is open."
    end

    if self:IsSlotIgnored(draftSet, invSlotID) then
        return false, "That slot is ignored."
    end

    local entry
    if bagID and slotIndex then
        entry = self:BuildSlotEntryFromBag(bagID, slotIndex)
    else
        entry = self:BuildSlotEntryFromItemID(itemID, itemLink)
    end

    if not entry then
        return false, "Could not read that item."
    end

    if not self:ItemFitsInventorySlot(entry.itemID, invSlotID) then
        return false, "That item does not belong in this slot."
    end

    draftSet.slots = draftSet.slots or {}
    draftSet.slots[invSlotID] = entry
    return true
end

function LPL.EquipmentCodec:TryAssignCursorToSlot(draftSet, invSlotID)
    if LPL.EquipmentCursor and LPL.EquipmentCursor:HasPickup() then
        return LPL.EquipmentCursor:PlaceOnSlot(draftSet, invSlotID)
    end

    local cursorItem = self:GetBagCursorItem()
    if not cursorItem then
        return false
    end

    local ok, err = self:AssignItemToSlot(
        draftSet,
        invSlotID,
        cursorItem.itemID,
        cursorItem.link,
        cursorItem.bagID,
        cursorItem.slotIndex
    )

    if ok and ClearCursor then
        ClearCursor()
    end

    return ok, err
end

function LPL.EquipmentCodec:SanitizeDraft(draftSet)
    if not draftSet then
        return
    end

    draftSet.slots = draftSet.slots or {}
    draftSet.ignored = draftSet.ignored or {}

    for slotID, entry in pairs(draftSet.slots) do
        local normalized = self:NormalizeSlotEntry(entry)
        if normalized then
            draftSet.slots[slotID] = normalized
        else
            draftSet.slots[slotID] = nil
        end
    end
end

function LPL.EquipmentCodec:PackInventoryLocation(invSlotID)
    invSlotID = tonumber(invSlotID)
    if not invSlotID then
        return nil
    end
    return bit.bor(ITEM_INVENTORY_LOCATION_PLAYER, invSlotID)
end

function LPL.EquipmentCodec:PackBagLocation(bagID, slotIndex)
    bagID = tonumber(bagID)
    slotIndex = tonumber(slotIndex)
    if not bagID or not slotIndex then
        return nil
    end
    return bit.bor(
        ITEM_INVENTORY_LOCATION_PLAYER,
        ITEM_INVENTORY_LOCATION_BAGS,
        bit.lshift(bagID, ITEM_INVENTORY_BAG_BIT_OFFSET),
        slotIndex
    )
end

function LPL.EquipmentCodec:BuildSlotEntryFromUnit(slotID)
    slotID = tonumber(slotID)
    if not slotID then
        return nil
    end

    local itemID = self:GetEquippedItemID(slotID)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", slotID)
    local entry = self:BuildSlotEntryFromItemID(itemID, link)
    if entry then
        entry.location = self:PackInventoryLocation(slotID)
    end
    return entry
end

function LPL.EquipmentCodec:CaptureFromCharacter(draftSet)
    if not draftSet then
        return 0
    end

    draftSet.slots = draftSet.slots or {}
    draftSet.ignored = draftSet.ignored or {}

    local filled = 0
    for _, slotID in ipairs(defs:GetAllSlotIDs()) do
        if not self:IsSlotIgnored(draftSet, slotID) then
            local entry = self:BuildSlotEntryFromUnit(slotID)
            if entry then
                draftSet.slots[slotID] = entry
                filled = filled + 1
            else
                draftSet.slots[slotID] = nil
            end
        end
    end

    self:SanitizeDraft(draftSet)
    return filled
end

function LPL.EquipmentCodec:BuildTooltipHintLines()
    return {
        { text = "Drag items from bags or between slots", color = "gray" },
        { text = "Click a filled slot to pick it up", color = "gray" },
        { text = "Shift+left-click to ignore", color = "gray" },
        { text = "Right-click to clear", color = "gray" },
    }
end

function LPL.EquipmentCodec:BuildTooltipExtraLines(draftSet, slotID)
    local lines = {}

    if self:IsSlotIgnored(draftSet, slotID) then
        lines[#lines + 1] = { text = "Ignored on activate", color = "gold" }
    end

    for _, hintLine in ipairs(self:BuildTooltipHintLines()) do
        lines[#lines + 1] = hintLine
    end

    return lines
end

function LPL.EquipmentCodec:BuildTooltipLines(draftSet, slotID)
    local lines = {
        { text = defs:GetSlotLabel(slotID), color = "title" },
    }

    if self:IsSlotIgnored(draftSet, slotID) then
        lines[#lines + 1] = { text = "Ignored on activate", color = "gold" }
    end

    local entry = draftSet and draftSet.slots and draftSet.slots[slotID]
    if entry and entry.cleared then
        lines[#lines + 1] = { text = "Empty | Unequips on activate", color = "gray" }
    elseif entry and entry.itemID then
        local name = entry.name
        if not name and C_Item and C_Item.GetItemNameByID then
            name = C_Item.GetItemNameByID(entry.itemID)
        end
        if name and LPL.PlainString then
            name = LPL:PlainString(name) or name
        end
        if name then
            lines[1] = { text = name, color = "title" }
        end
        if entry.upgradeText then
            lines[#lines + 1] = { text = entry.upgradeText, color = "purple" }
        end
        local enchantName = entry.enchantName or entry.enchantText
        if enchantName then
            lines[#lines + 1] = { text = enchantName, color = "enchant" }
        end
        if entry.enchantDetails then
            for _, detailLine in ipairs(entry.enchantDetails) do
                lines[#lines + 1] = { text = detailLine, color = "green" }
            end
        end
        if entry.gems then
            for _, gem in ipairs(entry.gems) do
                if gem.name then
                    lines[#lines + 1] = { text = gem.name, color = "normal" }
                end
            end
        end
        if entry.itemLevel then
            lines[#lines + 1] = { text = "Item Level " .. entry.itemLevel, color = "gray" }
        end
    else
        if not self:IsSlotIgnored(draftSet, slotID) then
            lines[#lines + 1] = { text = "Empty | Unequips on activate", color = "gray" }
        else
            lines[#lines + 1] = { text = "Empty", color = "gray" }
        end
    end

    for _, hintLine in ipairs(self:BuildTooltipHintLines()) do
        lines[#lines + 1] = hintLine
    end

    return lines
end

function LPL.EquipmentCodec:BuildTooltipSpec(draftSet, slotID)
    local entry = draftSet and draftSet.slots and draftSet.slots[slotID]
    if entry and entry.itemID and not entry.cleared then
        local link = entry.link
        if LPL.PlainString then
            link = LPL:PlainString(link)
        end
        if link then
            return {
                hyperlink = link,
                lines = self:BuildTooltipExtraLines(draftSet, slotID),
            }
        end
    end

    return {
        lines = self:BuildTooltipLines(draftSet, slotID),
    }
end
