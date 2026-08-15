-- Equipment activation modeled on LightPawsLoadouts/Modules/Equipment.lua.
-- Pickup runs synchronously on the Activate click, then retries on bag/equipment events.

local addonName, LPL = ...

LPL.EquipmentActivate = {}

local defs = LPL.EquipmentDefinitions
local codec = LPL.EquipmentCodec

local ClearCursor = ClearCursor
local PickupInventoryItem = PickupInventoryItem
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemsForSlot = _G.GetInventoryItemsForSlot
local IsInventoryItemLocked = IsInventoryItemLocked
local GetItemFamily = GetItemFamily
local GetItemInfoInstant = C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant
local CursorHasItem = _G.CursorHasItem

local PickupContainerItem = C_Container and C_Container.PickupContainerItem or PickupContainerItem
local GetContainerFreeSlots = C_Container and C_Container.GetContainerFreeSlots or GetContainerFreeSlots
local GetContainerItemLink = C_Container and C_Container.GetContainerItemLink or GetContainerItemLink
local GetContainerNumSlots = C_Container and C_Container.GetContainerNumSlots or GetContainerNumSlots

local EquipmentManager_UnpackLocation = EquipmentManager_UnpackLocation or function(packedLocation)
    local locationData = EquipmentManager_GetLocationData(packedLocation)
    return locationData.isPlayer or false, locationData.isBank or false, locationData.isBags or false, false,
        locationData.slot, locationData.bag, nil, nil
end

local BACKPACK_CONTAINER = Enum.BagIndex.Backpack or BACKPACK_CONTAINER or 0
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS or 5
local INVSLOT_FIRST = INVSLOT_FIRST_EQUIPPED or 1
local INVSLOT_LAST = INVSLOT_LAST_EQUIPPED or 19

local freeSlotsCache = {}
local possibleItems = {}
local correctSlots = {}
local bestMatchForSlot = {}

local activateFrame = CreateFrame("Frame", nil, UIParent)
activateFrame:Hide()

local retryTimer

local activateSession = {
    active = false,
    dirty = false,
    setName = nil,
    refreshFrame = nil,
    runtimeSet = nil,
    applySnapshot = nil,
    passCount = 0,
    madeProgress = false,
}

local function Fail(message)
    print("|cffff6060LPL:|r " .. (message or "Could not apply equipment set."))
    return false, message
end

local function Success(message)
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play()
    end
    print("|cff33cc33LPL:|r " .. message)
    return true
end

local function PlainLink(link)
    if not link then
        return nil
    end
    if LPL.PlainString then
        return LPL:PlainString(link)
    end
    return link
end

local function PackLocation(bag, slot)
    if bag == nil then
        return codec:PackInventoryLocation(slot)
    end
    return codec:PackBagLocation(bag, slot)
end

local function SlotOccupied(inventorySlotId)
    if codec and codec.InventorySlotHasItem then
        return codec:InventorySlotHasItem(inventorySlotId)
    end
    return GetInventoryItemLink("player", inventorySlotId) ~= nil
end

local function RefreshFreeBagSlots()
    for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        if not freeSlotsCache[bagID] then
            freeSlotsCache[bagID] = {}
        else
            wipe(freeSlotsCache[bagID])
        end

        if GetContainerFreeSlots then
            GetContainerFreeSlots(bagID, freeSlotsCache[bagID])
        end

        if #freeSlotsCache[bagID] == 0 then
            local numSlots = GetContainerNumSlots(bagID) or 0
            for slotIndex = 1, numSlots do
                if codec:BagSlotIsEmpty(bagID, slotIndex) then
                    freeSlotsCache[bagID][#freeSlotsCache[bagID] + 1] = slotIndex
                end
            end
        end
    end
end

local function CountFreeBagSlots()
    local count = 0
    for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local slots = freeSlotsCache[bagID]
        if slots then
            count = count + #slots
        end
    end
    return count
end

local function FindBagSlotForUnequip(inventorySlotId)
    local itemBagType = GetItemFamily(GetInventoryItemLink("player", inventorySlotId)) or 0

    for bagID = NUM_BAG_SLOTS, BACKPACK_CONTAINER, -1 do
        local bagType = 0
        if C_Container and C_Container.GetContainerNumFreeSlots then
            _, bagType = C_Container.GetContainerNumFreeSlots(bagID)
        end
        local freeSlots = freeSlotsCache[bagID]
        if freeSlots and #freeSlots > 0 and (bit.band(bagType or 0, itemBagType) > 0 or (bagType or 0) == 0) then
            local slotId = freeSlots[#freeSlots]
            freeSlots[#freeSlots] = nil
            return bagID, slotId
        end
    end

    return nil, nil
end

local function PerformPickupUnequip(inventorySlotId, containerId, slotId)
    ClearCursor()
    PickupInventoryItem(inventorySlotId)

    local complete = false
    if CursorHasItem and CursorHasItem() then
        PickupContainerItem(containerId, slotId)
        if CursorHasItem and not CursorHasItem() then
            complete = true
        end
    end

    ClearCursor()
    return complete
end

local function EmptyInventorySlot(inventorySlotId)
    local containerId, slotId = FindBagSlotForUnequip(inventorySlotId)
    if not containerId then
        return false, false
    end

    local complete = PerformPickupUnequip(inventorySlotId, containerId, slotId)
    return complete, true
end

local function SwapInventorySlot(inventorySlotId, location)
    if not location then
        return false
    end

    local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location)
    if voidStorage or (player and not bags and slot == inventorySlotId) then
        return false
    end

    ClearCursor()
    if bag == nil then
        PickupInventoryItem(slot)
    else
        PickupContainerItem(bag, slot)
    end

    local complete = false
    if CursorHasItem and CursorHasItem() then
        PickupInventoryItem(inventorySlotId)
        if CursorHasItem and not CursorHasItem() then
            complete = true
        end
    end

    ClearCursor()
    return complete
end

local function ItemLinkMatchesSlot(inventorySlotId, itemLink)
    local equippedLink = GetInventoryItemLink("player", inventorySlotId)
    if not equippedLink or not itemLink then
        return false
    end
    local targetID = GetItemInfoInstant(itemLink)
    local equippedID = GetItemInfoInstant(equippedLink)
    if targetID and equippedID then
        return targetID == equippedID
    end
    return PlainLink(equippedLink) == PlainLink(itemLink)
end

local function FindItemLocation(inventorySlotId, itemLink, reservedLocations)
    reservedLocations = reservedLocations or {}
    local targetID = GetItemInfoInstant(itemLink)
    if not targetID then
        return nil
    end

    if GetInventoryItemsForSlot then
        wipe(possibleItems)
        GetInventoryItemsForSlot(inventorySlotId, possibleItems)
        for completedSlotId in pairs(correctSlots) do
            possibleItems[PackLocation(nil, completedSlotId)] = nil
        end
        for location, locationLink in pairs(possibleItems) do
            if not reservedLocations[location] and GetItemInfoInstant(locationLink) == targetID then
                return location
            end
        end
    end

    for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        local numSlots = GetContainerNumSlots(bagID) or 0
        for slotIndex = 1, numSlots do
            local location = PackLocation(bagID, slotIndex)
            if not reservedLocations[location] then
                local bagLink = GetContainerItemLink(bagID, slotIndex)
                if bagLink and GetItemInfoInstant(bagLink) == targetID then
                    return location
                end
            end
        end
    end

    return nil
end

local function BuildRuntimeSet(setData)
    local runtime = {
        equipment = {},
        locations = {},
        ignored = {},
    }

    if LPL.EquipmentStore and LPL.EquipmentStore.DefaultIgnoredSlots then
        for slotID in pairs(LPL.EquipmentStore:DefaultIgnoredSlots()) do
            runtime.ignored[slotID] = true
        end
    end

    if setData.ignored then
        for slotID, value in pairs(setData.ignored) do
            if value then
                runtime.ignored[slotID] = true
            end
        end
    end

    for inventorySlotId = INVSLOT_FIRST, INVSLOT_LAST do
        local entry = setData.slots and setData.slots[inventorySlotId]
        if entry and entry.cleared then
            runtime.ignored[inventorySlotId] = nil
        end
    end

    for inventorySlotId = INVSLOT_FIRST, INVSLOT_LAST do
        if not runtime.ignored[inventorySlotId] then
            local entry = setData.slots and setData.slots[inventorySlotId]
            if entry and not entry.cleared and codec:GetSlotItemID(entry) then
                local link = PlainLink(entry.link)
                if not link and C_Item and C_Item.GetItemLinkByID then
                    link = C_Item.GetItemLinkByID(codec:GetSlotItemID(entry))
                end
                if link then
                    runtime.equipment[inventorySlotId] = link
                    if entry.location then
                        runtime.locations[inventorySlotId] = entry.location
                    end
                end
            end
        end
    end

    if LPL.EquipmentItemInfo then
        LPL.EquipmentItemInfo:ApplyUniqueLimits(runtime)
    end

    return runtime
end

local function CountSlotsNeedingUnequip(runtime)
    local count = 0
    for inventorySlotId = INVSLOT_FIRST, INVSLOT_LAST do
        if not runtime.ignored[inventorySlotId] and not runtime.equipment[inventorySlotId] and SlotOccupied(inventorySlotId) then
            count = count + 1
        end
    end
    return count
end

local function CountSlotsNeedingEquip(runtime)
    local count = 0
    for inventorySlotId = INVSLOT_FIRST, INVSLOT_LAST do
        if not runtime.ignored[inventorySlotId] and runtime.equipment[inventorySlotId] and not ItemLinkMatchesSlot(inventorySlotId, runtime.equipment[inventorySlotId]) then
            count = count + 1
        end
    end
    return count
end

local function DescribeBlockedSlot(runtime)
    RefreshFreeBagSlots()
    for inventorySlotId = INVSLOT_FIRST, INVSLOT_LAST do
        if not runtime.ignored[inventorySlotId] then
            if runtime.equipment[inventorySlotId] then
                if not ItemLinkMatchesSlot(inventorySlotId, runtime.equipment[inventorySlotId]) then
                    local label = defs and defs.GetSlotLabel and defs:GetSlotLabel(inventorySlotId) or ("slot " .. inventorySlotId)
                    return label .. " (equip)"
                end
            elseif SlotOccupied(inventorySlotId) then
                local label = defs and defs.GetSlotLabel and defs:GetSlotLabel(inventorySlotId) or ("slot " .. inventorySlotId)
                if IsInventoryItemLocked(inventorySlotId) then
                    return label .. " (locked)"
                end
                local bagID = FindBagSlotForUnequip(inventorySlotId)
                if not bagID then
                    return label .. " (no bag space)"
                end
                return label .. " (unequip)"
            end
        end
    end
    return nil
end

local function ActivateEquipmentSetPass(runtime)
    local ignored = runtime.ignored
    local expected = runtime.equipment
    local locations = runtime.locations

    local anyLockedSlots
    local anyFoundFreeSlots
    local anyChangedSlots

    wipe(correctSlots)
    wipe(bestMatchForSlot)
    RefreshFreeBagSlots()

    for inventorySlotId = INVSLOT_FIRST, INVSLOT_LAST do
        if not ignored[inventorySlotId] then
            local slotLocked = IsInventoryItemLocked(inventorySlotId)
            anyLockedSlots = anyLockedSlots or slotLocked

            local itemLink = expected[inventorySlotId]
            if itemLink then
                if ItemLinkMatchesSlot(inventorySlotId, itemLink) then
                    correctSlots[inventorySlotId] = true
                    ignored[inventorySlotId] = true
                else
                    local location = locations[inventorySlotId]
                    if location and location > 0 then
                        local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location)
                        if player and not bags and slot == inventorySlotId then
                            correctSlots[inventorySlotId] = true
                            ignored[inventorySlotId] = true
                        else
                            bestMatchForSlot[inventorySlotId] = location
                        end
                    else
                        location = FindItemLocation(inventorySlotId, itemLink, bestMatchForSlot)
                        if not location then
                            ignored[inventorySlotId] = true
                        else
                            local player, bank, bags, voidStorage, slot, bag = EquipmentManager_UnpackLocation(location)
                            if player and not bags and slot == inventorySlotId then
                                correctSlots[inventorySlotId] = true
                                ignored[inventorySlotId] = true
                            else
                                bestMatchForSlot[inventorySlotId] = location
                            end
                        end
                    end
                end
            elseif SlotOccupied(inventorySlotId) then
                if not slotLocked then
                    local complete, foundSlot = EmptyInventorySlot(inventorySlotId)
                    anyChangedSlots = anyChangedSlots or complete
                    anyFoundFreeSlots = anyFoundFreeSlots or foundSlot
                end
            else
                ignored[inventorySlotId] = true
            end
        end
    end

    for inventorySlotId = INVSLOT_FIRST, INVSLOT_LAST do
        if not ignored[inventorySlotId] and not IsInventoryItemLocked(inventorySlotId) and expected[inventorySlotId] then
            if SwapInventorySlot(inventorySlotId, bestMatchForSlot[inventorySlotId]) then
                anyChangedSlots = true
            end
        end
    end

    ClearCursor()

    local complete = not anyLockedSlots and not anyChangedSlots
    if complete then
        if anyFoundFreeSlots == false then
            return false, "Need more empty bag space to unequip gear for this set."
        end
        for inventorySlotId = INVSLOT_FIRST, INVSLOT_LAST do
            if not ignored[inventorySlotId] then
                complete = false
                break
            end
        end
    end

    return complete, nil, anyChangedSlots
end

local function CancelActivate()
    if retryTimer then
        retryTimer:Cancel()
        retryTimer = nil
    end
    activateSession.active = false
    activateSession.dirty = false
    activateSession.setName = nil
    activateSession.refreshFrame = nil
    activateSession.runtimeSet = nil
    activateSession.applySnapshot = nil
    activateSession.passCount = 0
    activateSession.madeProgress = false
end

local function ScheduleRetry(delay)
    if retryTimer then
        return
    end
    retryTimer = C_Timer.NewTimer(delay or 0.35, function()
        retryTimer = nil
        if activateSession.active then
            activateSession.dirty = true
        end
    end)
end

local function FinishActivate(successMessage)
    local frame = activateSession.refreshFrame
    CancelActivate()
    if frame and frame.Refresh then
        frame:Refresh()
    end
    if successMessage then
        Success(successMessage)
    end
end

local function SafeTraceback(err)
    if type(debug) == "table" and debug.traceback then
        return debug.traceback(err, 2)
    end
    return tostring(err)
end

local function ContinueActivate()
    if not activateSession.active or not activateSession.runtimeSet then
        activateSession.dirty = false
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        activateSession.dirty = true
        return
    end

    activateSession.dirty = false
    activateSession.passCount = activateSession.passCount + 1

    if activateSession.passCount > 30 then
        local blocked = DescribeBlockedSlot(activateSession.runtimeSet)
        if blocked then
            Fail("Equipment change timed out at " .. blocked .. ". Try /reload, then Activate again while standing still out of combat.")
        else
            Fail("Equipment change timed out. Try /reload, then Activate again while standing still out of combat.")
        end
        FinishActivate()
        return
    end

    if activateSession.passCount == 4 then
        print("|cffffcc00LPL:|r Still changing equipment...")
    end

    local ok, err = xpcall(function()
        local complete, message, changed = ActivateEquipmentSetPass(activateSession.runtimeSet)
        if changed then
            activateSession.madeProgress = true
        end
        if complete then
            if activateSession.applySnapshot and LPL.EquipmentActive and not LPL.EquipmentActive:IsActive(activateSession.applySnapshot) then
                ScheduleRetry(0.35)
                return
            end
            local setName = activateSession.setName or "Equipment Set"
            FinishActivate(string.format('Applied "%s" to your character.', setName))
        elseif message then
            Fail(message)
            FinishActivate()
        elseif activateSession.passCount >= 6 and not activateSession.madeProgress then
            local blocked = DescribeBlockedSlot(activateSession.runtimeSet)
            if blocked then
                Fail("Could not move equipment at " .. blocked .. ". Stand still out of combat and click Activate again.")
            else
                Fail("Could not move equipment. Stand still out of combat and click Activate again.")
            end
            FinishActivate()
        else
            ScheduleRetry(0.35)
        end
    end, SafeTraceback)

    if not ok then
        Fail("Equipment apply failed: " .. tostring(err))
        FinishActivate()
    end
end

activateFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
activateFrame:RegisterEvent("BAG_UPDATE_DELAYED")
activateFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
activateFrame:RegisterEvent("ITEM_UNLOCKED")
activateFrame:RegisterEvent("PLAYER_STOPPED_MOVING")
activateFrame:SetScript("OnEvent", function()
    if activateSession.active then
        activateSession.dirty = true
    end
end)
activateFrame:SetScript("OnUpdate", function()
    if activateSession.active and activateSession.dirty then
        ContinueActivate()
    end
end)

local function CopyApplySnapshot(setData)
    if type(setData) ~= "table" then
        return nil
    end
    return {
        name = setData.name,
        slots = CopyTable(setData.slots or {}),
        ignored = CopyTable(setData.ignored or {}),
        restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(setData.restrictions) or CopyTable(setData.restrictions or {}),
    }
end

local function StartActivate(setData, setName, refreshFrame)
    if type(setData) ~= "table" then
        return Fail("Invalid equipment set.")
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(setData) then
        local summary = LPL.SetRestrictions:GetSummaryLine(setData.restrictions) or "another character, class, or specialization"
        return Fail("This set is restricted to " .. summary .. ".")
    end

    local snapshot = CopyApplySnapshot(setData)
    if not snapshot then
        return Fail("Invalid equipment set.")
    end

    if codec.SanitizeDraft then
        codec:SanitizeDraft(snapshot)
    end

    if InCombatLockdown and InCombatLockdown() then
        return Fail("Cannot change equipment in combat.")
    end

    local runtime = BuildRuntimeSet(snapshot)
    RefreshFreeBagSlots()

    local slotsToClear = CountSlotsNeedingUnequip(runtime)
    local slotsToEquip = CountSlotsNeedingEquip(runtime)
    local freeBagSlots = CountFreeBagSlots()
    if slotsToClear > freeBagSlots then
        return Fail(string.format(
            "Need %d empty bag slot%s to unequip gear for this set, but only %d %s free.",
            slotsToClear,
            slotsToClear == 1 and "" or "s",
            freeBagSlots,
            freeBagSlots == 1 and "is" or "are"
        ))
    end

    if activateSession.active then
        CancelActivate()
    end

    activateSession.setName = setName or snapshot.name
    activateSession.refreshFrame = refreshFrame
    activateSession.runtimeSet = runtime
    activateSession.applySnapshot = snapshot
    activateSession.active = true
    activateSession.dirty = false
    activateSession.passCount = 0
    activateSession.madeProgress = false

    print(string.format(
        "|cffffcc00LPL:|r Applying equipment set... (unequip %d, equip %d)",
        slotsToClear,
        slotsToEquip
    ))

    ContinueActivate()
    return true
end

function LPL.EquipmentActivate:ApplySet(setID, refreshFrame)
    if not setID then
        return Fail("No equipment set selected.")
    end
    local set = LPL.EquipmentStore:Get(setID)
    if not set then
        return Fail("Equipment set not found.")
    end
    return StartActivate(set, set.name, refreshFrame)
end

function LPL.EquipmentActivate:ApplyDraft(draftSet, name, refreshFrame)
    if not draftSet then
        return Fail("No equipment set to apply.")
    end
    return StartActivate(draftSet, name or draftSet.name, refreshFrame)
end
