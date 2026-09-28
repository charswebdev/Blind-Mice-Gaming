local _, LPL = ...

LPL.EquipmentAPI = LPL.EquipmentAPI or {}
local API = LPL.EquipmentAPI

local KEY = "equipment"

local SLOTS = {
    { id = 1, label = "Head" },
    { id = 2, label = "Neck" },
    { id = 3, label = "Shoulder" },
    { id = 15, label = "Back" },
    { id = 5, label = "Chest" },
    { id = 9, label = "Wrist" },
    { id = 10, label = "Hands" },
    { id = 6, label = "Waist" },
    { id = 7, label = "Legs" },
    { id = 8, label = "Feet" },
    { id = 11, label = "Finger" },
    { id = 12, label = "Finger" },
    { id = 13, label = "Trinket" },
    { id = 14, label = "Trinket" },
    { id = 16, label = "Main Hand" },
    { id = 17, label = "Off Hand" },
    { id = 18, label = "Ranged" },
    { id = 0, label = "Ammo" },
}

function API:Available()
    return GetInventoryItemID ~= nil or (C_Item and C_Item.GetItemID ~= nil)
end

function API:Slots()
    return SLOTS
end

local function EquippedID(slotID)
    if GetInventoryItemID then
        local itemID = LPL:PlainNumber(GetInventoryItemID("player", slotID))
        if itemID and itemID > 0 then
            return itemID
        end
    end
    if GetInventoryItemLink then
        local link = LPL:PlainString(GetInventoryItemLink("player", slotID))
        if link then
            return tonumber(link:match("item:(%d+)"))
        end
    end
    return nil
end

local function BagCount()
    return NUM_BAG_SLOTS or 4
end

local function BagSlots(bag)
    local result
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, count = pcall(C_Container.GetContainerNumSlots, bag)
        if ok then
            result = count
        end
    end
    if result == nil and GetContainerNumSlots then
        local ok, count = pcall(GetContainerNumSlots, bag)
        if ok then
            result = count
        end
    end
    return LPL:PlainNumber(result) or 0
end

local function BagItemID(bag, slot)
    local result
    if C_Container and C_Container.GetContainerItemID then
        local ok, itemID = pcall(C_Container.GetContainerItemID, bag, slot)
        if ok then
            result = itemID
        end
    end
    if result == nil and GetContainerItemID then
        local ok, itemID = pcall(GetContainerItemID, bag, slot)
        if ok then
            result = itemID
        end
    end
    local itemID = LPL:PlainNumber(result)
    if itemID and itemID > 0 then
        return itemID
    end
    return nil
end

local function CopyIgnored(ignored)
    local out = {}
    if type(ignored) ~= "table" then
        return out
    end
    for key, value in pairs(ignored) do
        if value == true then
            local id = LPL:PlainString(key)
            if not id and LPL:PlainNumber(key) then
                id = tostring(LPL:PlainNumber(key))
            end
            if id then
                out[id] = true
            end
        end
    end
    return out
end

local function SlotIgnored(set, slotID)
    return type(set) == "table" and type(set.ignored) == "table" and set.ignored[tostring(slotID)] == true
end

local function CopySlots(slots)
    local out = {}
    if type(slots) ~= "table" then
        return out
    end
    for _, info in ipairs(SLOTS) do
        local key = tostring(info.id)
        local entry = slots[key] or slots[info.id]
        local itemID = type(entry) == "table" and LPL:PlainNumber(entry.itemID) or nil
        if itemID and itemID > 0 then
            out[key] = { itemID = itemID }
        end
    end
    return out
end

function API:Capture()
    local slots = {}
    local skipped = 0
    for i = 1, #SLOTS do
        local slotID = SLOTS[i].id
        local raw
        if GetInventoryItemID then
            raw = GetInventoryItemID("player", slotID)
        end
        if raw and issecretvalue and issecretvalue(raw) then
            skipped = skipped + 1
        else
            local itemID = EquippedID(slotID)
            if itemID then
                slots[tostring(slotID)] = { itemID = itemID }
            end
        end
    end
    return { slots = slots, skipped = skipped }
end

function API:Count(set)
    local count = 0
    if type(set) == "table" and type(set.slots) == "table" then
        for _, info in ipairs(SLOTS) do
            local entry = set.slots[tostring(info.id)]
            if type(entry) == "table" and LPL:PlainNumber(entry.itemID) then
                count = count + 1
            end
        end
    end
    return count
end

function API:Summary(set)
    local count = self:Count(set)
    if count == 1 then
        return "1 item"
    end
    return tostring(count) .. " items"
end

function API:ItemID(set, slotID)
    if type(set) ~= "table" or type(set.slots) ~= "table" then
        return nil
    end
    local entry = set.slots[tostring(slotID)]
    if type(entry) ~= "table" then
        return nil
    end
    return LPL:PlainNumber(entry.itemID)
end

function API:Matches(set, live)
    if type(set) ~= "table" then
        return false
    end
    live = live or self:Capture()
    for i = 1, #SLOTS do
        if SlotIgnored(set, SLOTS[i].id) then
            -- Ignored slots are not part of the match.
        elseif self:ItemID(set, SLOTS[i].id) ~= self:ItemID(live, SLOTS[i].id) then
            return false
        end
    end
    return true
end

function API:List()
    return LPL.SetStore:List(KEY)
end

function API:Get(id)
    return LPL.SetStore:Get(KEY, id)
end

function API:Save(draft, name)
    return LPL.SetStore:Save(KEY, {
        slots = CopySlots(draft and draft.slots),
        ignored = CopyIgnored(draft and draft.ignored),
    }, name, LPL.SetStore:SuggestName(KEY, "Gear"))
end

function API:Update(id, draft, name)
    return LPL.SetStore:Update(KEY, id, {
        slots = CopySlots(draft and draft.slots),
        ignored = CopyIgnored(draft and draft.ignored),
    }, name, "Gear")
end

function API:Delete(id)
    return LPL.SetStore:Delete(KEY, id)
end

function API:SuggestName()
    return LPL.SetStore:SuggestName(KEY, "Gear")
end

function API:ClearSlot(set, slotID)
    if type(set) == "table" and type(set.slots) == "table" then
        set.slots[tostring(slotID)] = nil
    end
end

function API:Icon(itemID)
    itemID = LPL:PlainNumber(itemID)
    if not itemID then
        return nil
    end
    if C_Item and C_Item.GetItemIconByID then
        local ok, texture = pcall(C_Item.GetItemIconByID, itemID)
        if ok and type(texture) == "number" and not (issecretvalue and issecretvalue(texture)) then
            return texture
        end
    end
    if GetItemIcon then
        local texture = GetItemIcon(itemID)
        if type(texture) == "number" and not (issecretvalue and issecretvalue(texture)) then
            return texture
        end
    end
    return nil
end

function API:ItemName(itemID)
    itemID = LPL:PlainNumber(itemID)
    if not itemID then
        return "Empty"
    end
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        local plain = ok and LPL:PlainString(name) or nil
        if plain then
            return plain
        end
    end
    if C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    end
    return "Item " .. tostring(itemID)
end

local function CursorHasItem()
    if _G.CursorHasItem then
        return _G.CursorHasItem()
    end
    local cursor = GetCursorInfo and GetCursorInfo()
    return cursor == "item"
end

local function PickupBag(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    elseif PickupContainerItem then
        PickupContainerItem(bag, slot)
    end
end

local function PutInBag(bag, slot)
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    elseif PickupContainerItem then
        PickupContainerItem(bag, slot)
    end
end

local function FindSource(itemID, reserved)
    for bag = 0, BagCount() do
        local count = BagSlots(bag)
        for slot = 1, count do
            local found = BagItemID(bag, slot)
            local mark = "b:" .. bag .. ":" .. slot
            if found == itemID and not reserved[mark] then
                return "bag", bag, slot, mark
            end
        end
    end
    for i = 1, #SLOTS do
        local slotID = SLOTS[i].id
        local mark = "e:" .. slotID
        if EquippedID(slotID) == itemID and not reserved[mark] then
            return "equip", slotID, nil, mark
        end
    end
    return nil
end

local function FirstEmptyBag(reserved)
    reserved = reserved or {}
    for bag = 0, BagCount() do
        if C_Container and C_Container.GetContainerFreeSlots then
            local ok, free = pcall(C_Container.GetContainerFreeSlots, bag)
            if ok and type(free) == "table" then
                for index = 1, #free do
                    local slot = LPL:PlainNumber(free[index])
                    local mark = "bag:" .. bag .. ":" .. tostring(slot)
                    if slot and slot > 0 and not reserved[mark] then
                        return bag, slot, mark
                    end
                end
            end
        end
        local count = BagSlots(bag)
        for slot = 1, count do
            local mark = "bag:" .. bag .. ":" .. slot
            if not reserved[mark] and not BagItemID(bag, slot) then
                return bag, slot, mark
            end
        end
    end
    return nil
end

local function MoveToSlot(kind, a, b, destSlot)
    ClearCursor()
    if kind == "bag" then
        PickupBag(a, b)
    else
        PickupInventoryItem(a)
    end
    if not CursorHasItem() then
        ClearCursor()
        return false
    end
    PickupInventoryItem(destSlot)
    ClearCursor()
    return EquippedID(destSlot) ~= nil
end

local function Unequip(slotID, reserved)
    local bag, slot, mark = FirstEmptyBag(reserved)
    if not bag or not PickupInventoryItem then
        return false
    end
    if reserved and mark then
        reserved[mark] = true
    end
    if ClearCursor then
        ClearCursor()
    end
    PickupInventoryItem(slotID)
    if not (CursorHasItem and CursorHasItem()) then
        if ClearCursor then
            ClearCursor()
        end
        return false
    end
    if C_Container and C_Container.PickupContainerItem then
        C_Container.PickupContainerItem(bag, slot)
    elseif PickupContainerItem then
        PickupContainerItem(bag, slot)
    end
    local placed = not (CursorHasItem and CursorHasItem())
    if ClearCursor then
        ClearCursor()
    end
    return placed
end

function API:Apply(set)
    if not self:Available() then
        return false, "Equipment is not available on this client."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat, then apply equipment."
    end
    if type(set) ~= "table" then
        return false, "Select a saved equipment set first."
    end
    local wanted = CopySlots(set.slots)
    local emptied = {}
    local moved = 0
    for _ = 1, 4 do
        local progress = false
        local reserved = {}
        for i = 1, #SLOTS do
            local slotID = SLOTS[i].id
            if SlotIgnored(set, slotID) then
                -- Leave this worn item alone.
            else
            local have = EquippedID(slotID)
            local entry = wanted[tostring(slotID)]
            local want = entry and entry.itemID or nil
            if emptied[slotID] then
                -- The bag already accepted this item. The worn slot can still
                -- report the old item for a moment.
            elseif have == want then
                if want then
                    reserved["e:" .. slotID] = true
                end
            elseif want then
                local kind, a, b, mark = FindSource(want, reserved)
                if kind == "equip" and a == slotID then
                    reserved[mark] = true
                elseif kind then
                    reserved[mark] = true
                    local ok, movedOk = pcall(MoveToSlot, kind, a, b, slotID)
                    if ok and movedOk and EquippedID(slotID) == want then
                        moved = moved + 1
                        progress = true
                        reserved["e:" .. slotID] = true
                    end
                end
            elseif have then
                local ok, cleared = pcall(Unequip, slotID, reserved)
                if ok and cleared then
                    emptied[slotID] = true
                    moved = moved + 1
                    progress = true
                end
            end
            end
        end
        if not progress then
            break
        end
    end
    local missing, blocked, wantedCount = 0, 0, 0
    for i = 1, #SLOTS do
        local slotID = SLOTS[i].id
        local entry = wanted[tostring(slotID)]
        local want = entry and entry.itemID or nil
        local have = EquippedID(slotID)
        if want then
            wantedCount = wantedCount + 1
        end
        if want and have ~= want and not emptied[slotID] and not SlotIgnored(set, slotID) then
            missing = missing + 1
        elseif not want and have and not emptied[slotID] and not SlotIgnored(set, slotID) then
            blocked = blocked + 1
        end
    end
    if missing > 0 or blocked > 0 then
        local message
        if missing > 0 and blocked > 0 then
            message = "Equipped what was in your bags."
        elseif blocked > 0 then
            message = "This set leaves those slots empty."
        else
            message = "Equipped what was in your bags."
        end
        if missing > 0 then
            message = message .. " " .. missing .. " item" .. (missing == 1 and " is" or "s are") .. " still missing."
        end
        if blocked > 0 then
            message = message .. " " .. blocked .. " slot" .. (blocked == 1 and "" or "s") .. " could not be emptied. Make bag space and apply again."
        end
        return false, message
    end
    if moved == 0 then
        return true, "This equipment set already matches your character. Shirt and tabard stay on."
    end
    if wantedCount == 0 then
        return true, "Removed the gear this set leaves empty. Shirt and tabard stay on."
    end
    return true, "Equipped this set. Shirt and tabard stay on."
end

function API:ShowTooltip(owner, itemID, slotLabel)
    if not owner or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    itemID = LPL:PlainNumber(itemID)
    if itemID and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(itemID)
    else
        GameTooltip:SetText(slotLabel or "Empty", 1, 0.82, 0)
    end
    if slotLabel then
        GameTooltip:AddLine(slotLabel .. ". Right-click to clear.", 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end
