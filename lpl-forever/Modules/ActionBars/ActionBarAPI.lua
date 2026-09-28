local _, LPL = ...

LPL.ActionBarAPI = LPL.ActionBarAPI or {}
local API = LPL.ActionBarAPI

local KEY = "actionbars"

local ROWS = {
    { label = "Main Bar", first = 1, last = 12 },
    { label = "Page 2", first = 13, last = 24 },
    { label = "Bar 2", first = 61, last = 72 },
    { label = "Bar 3", first = 49, last = 60 },
    { label = "Bar 4", first = 25, last = 36 },
    { label = "Bar 5", first = 37, last = 48 },
    { label = "Bar 6", first = 145, last = 156 },
    { label = "Bar 7", first = 157, last = 168 },
    { label = "Bar 8", first = 169, last = 180 },
    { label = "Form 1", first = 73, last = 84 },
    { label = "Form 2", first = 85, last = 96 },
    { label = "Form 3", first = 97, last = 108 },
    { label = "Form 4", first = 109, last = 120 },
    { label = "Pet Bar", first = 1, last = 10, isPet = true },
}

function API:Available()
    return GetActionInfo ~= nil
end

local function CopyAction(action)
    if type(action) ~= "table" or type(action.kind) ~= "string" then
        return nil
    end
    if action.kind == "spell" then
        local spellID = LPL:PlainNumber(action.spellID)
        if not spellID or spellID < 1 then
            return nil
        end
        return { kind = "spell", spellID = spellID }
    end
    if action.kind == "item" then
        local itemID = LPL:PlainNumber(action.itemID)
        if not itemID or itemID < 1 then
            return nil
        end
        return { kind = "item", itemID = itemID }
    end
    if action.kind == "macro" then
        local copy = { kind = "macro" }
        copy.macroIndex = LPL:PlainNumber(action.macroIndex)
        copy.macroName = LPL:PlainString(action.macroName)
        copy.macroBody = LPL:PlainString(action.macroBody)
        if not copy.macroName and not copy.macroBody and not copy.macroIndex then
            return nil
        end
        return copy
    end
    return nil
end

local function CopySlots(slots)
    local out = {}
    if type(slots) ~= "table" then
        return out
    end
    for key, action in pairs(slots) do
        local slotKey = tostring(key)
        local copy = CopyAction(action)
        if copy then
            out[slotKey] = copy
        end
    end
    return out
end

function API:ReadSlot(slot)
    slot = LPL:PlainNumber(slot)
    if not slot or not GetActionInfo then
        return nil
    end
    local actionType, id, subType = GetActionInfo(slot)
    if actionType ~= nil and issecretvalue then
        local ok, secret = pcall(issecretvalue, actionType)
        if ok and secret then
            return nil, true
        end
    end
    actionType = LPL:PlainString(actionType)
    if not actionType then
        if C_ActionBar and C_ActionBar.GetSpell then
            local spellID = LPL:PlainNumber(C_ActionBar.GetSpell(slot))
            if spellID and spellID > 0 then
                return { kind = "spell", spellID = spellID }
            end
        end
        return nil
    end
    if actionType == "spell" then
        local spellID = LPL:PlainNumber(id)
        if not spellID or spellID < 1 then
            return nil, true
        end
        return { kind = "spell", spellID = spellID }
    end
    if actionType == "item" then
        local itemID = LPL:PlainNumber(id)
        if not itemID or itemID < 1 then
            return nil, true
        end
        return { kind = "item", itemID = itemID }
    end
    if actionType == "macro" then
        local macroIndex = LPL:PlainNumber(id)
        if not macroIndex or macroIndex < 1 then
            return nil, true
        end
        local name, _, body
        if GetMacroInfo then
            name, _, body = GetMacroInfo(macroIndex)
        end
        return {
            kind = "macro",
            macroIndex = macroIndex,
            macroName = LPL:PlainString(name),
            macroBody = LPL:PlainString(body) or (GetMacroBody and LPL:PlainString(GetMacroBody(macroIndex))) or nil,
        }
    end
    return nil, "leave"
end

local function BookSpellID(index, bank)
    index = LPL:PlainNumber(index)
    if not index or index < 1 then
        return nil
    end
    if type(bank) == "string" then
        if bank == "pet" then
            bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet or 1
        else
            bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        end
    end
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, bank)
        if ok and type(info) == "table" then
            local spellID = LPL:PlainNumber(info.spellID) or LPL:PlainNumber(info.actionID)
            if spellID and spellID > 0 then
                return spellID
            end
        end
    end
    if GetSpellBookItemInfo then
        local _, spellID = GetSpellBookItemInfo(index, bank)
        spellID = LPL:PlainNumber(spellID)
        if spellID and spellID > 0 then
            return spellID
        end
    end
    return nil
end

function API:FromCursor()
    if not GetCursorInfo then
        return nil
    end
    local cursorType, a2, a3, a4 = GetCursorInfo()
    if cursorType ~= nil and issecretvalue then
        local ok, secret = pcall(issecretvalue, cursorType)
        if ok and secret then
            return nil
        end
    end
    cursorType = LPL:PlainString(cursorType)
    if cursorType == "spell" or cursorType == "petaction" then
        local spellID = LPL:PlainNumber(a4) or BookSpellID(a2, a3) or LPL:PlainNumber(a2)
        if spellID and spellID > 0 then
            return { kind = "spell", spellID = spellID }
        end
    elseif cursorType == "mount" then
        local mountID = LPL:PlainNumber(a2)
        local spellID
        if mountID and C_MountJournal and C_MountJournal.GetMountInfoByID then
            local ok, _, mountSpell = pcall(C_MountJournal.GetMountInfoByID, mountID)
            if ok then
                spellID = LPL:PlainNumber(mountSpell)
            end
        end
        spellID = spellID or LPL:PlainNumber(a4) or LPL:PlainNumber(a2)
        if spellID and spellID > 0 then
            return { kind = "spell", spellID = spellID }
        end
    elseif cursorType == "item" then
        local itemID = LPL:PlainNumber(a2)
        if itemID and itemID > 0 then
            return { kind = "item", itemID = itemID }
        end
    elseif cursorType == "macro" then
        local macroIndex = LPL:PlainNumber(a2)
        if not macroIndex or macroIndex < 1 then
            return nil
        end
        local name, _, body
        if GetMacroInfo then
            name, _, body = GetMacroInfo(macroIndex)
        end
        return {
            kind = "macro",
            macroIndex = macroIndex,
            macroName = LPL:PlainString(name),
            macroBody = LPL:PlainString(body) or (GetMacroBody and LPL:PlainString(GetMacroBody(macroIndex))) or nil,
        }
    end
    return nil
end

function API:Capture()
    local slots = {}
    local petSlots = {}
    local skipped = 0
    for rowIndex = 1, #ROWS do
        local row = ROWS[rowIndex]
        if not row.isPet then
            for slot = row.first, row.last do
                local action, hidden = self:ReadSlot(slot)
                if action then
                    slots[tostring(slot)] = action
                elseif hidden == true then
                    skipped = skipped + 1
                end
            end
        end
    end
    if GetPetActionInfo then
        for slot = 1, 10 do
            local _, _, _, _, _, _, spellID = GetPetActionInfo(slot)
            spellID = LPL:PlainNumber(spellID)
            if spellID and spellID > 0 then
                petSlots[tostring(slot)] = { kind = "spell", spellID = spellID }
            end
        end
    end
    return { slots = slots, petSlots = petSlots, skipped = skipped }
end

function API:Count(set)
    local count = 0
    if type(set) == "table" and type(set.slots) == "table" then
        for _, action in pairs(set.slots) do
            if CopyAction(action) then
                count = count + 1
            end
        end
    end
    return count
end

function API:Summary(set)
    local count = self:Count(set)
    if count == 1 then
        return "1 button"
    end
    return tostring(count) .. " buttons"
end

local function SameAction(a, b)
    a = CopyAction(a)
    b = CopyAction(b)
    if not a and not b then
        return true
    end
    if not a or not b or a.kind ~= b.kind then
        return false
    end
    if a.kind == "spell" then
        return a.spellID == b.spellID
    end
    if a.kind == "item" then
        return a.itemID == b.itemID
    end
    if a.macroName and b.macroName then
        return a.macroName == b.macroName
    end
    if a.macroBody and b.macroBody then
        return a.macroBody == b.macroBody
    end
    return a.macroIndex ~= nil and a.macroIndex == b.macroIndex
end

function API:Matches(set, live)
    if type(set) ~= "table" then
        return false
    end
    live = live or self:Capture()
    for rowIndex = 1, #ROWS do
        local row = ROWS[rowIndex]
        if not row.isPet then
            for slot = row.first, row.last do
                local key = tostring(slot)
                if type(set.ignored) == "table" and set.ignored[key] then
                    -- Ignored slots stay as they are on the character.
                else
                    local saved = set.slots and set.slots[key]
                    local current = live.slots and live.slots[key]
                    if not SameAction(saved, current) then
                        return false
                    end
                end
            end
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

local function CopyIgnored(ignored)
    local out = {}
    if type(ignored) ~= "table" then
        return out
    end
    for key, value in pairs(ignored) do
        if value == true and type(key) == "string" then
            out[key] = true
        end
    end
    return out
end

function API:Save(draft, name)
    local record = {
        slots = CopySlots(draft and draft.slots),
        petSlots = CopySlots(draft and draft.petSlots),
        ignored = CopyIgnored(draft and draft.ignored),
    }
    return LPL.SetStore:Save(KEY, record, name, LPL.SetStore:SuggestName(KEY, "Bars"))
end

function API:Update(id, draft, name)
    local record = {
        slots = CopySlots(draft and draft.slots),
        petSlots = CopySlots(draft and draft.petSlots),
        ignored = CopyIgnored(draft and draft.ignored),
    }
    return LPL.SetStore:Update(KEY, id, record, name, "Bars")
end

function API:Delete(id)
    return LPL.SetStore:Delete(KEY, id)
end

function API:SuggestName()
    return LPL.SetStore:SuggestName(KEY, "Bars")
end

local function SpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and type(texture) == "number" and not (issecretvalue and issecretvalue(texture)) then
            return texture
        end
    end
    if GetSpellTexture then
        local texture = GetSpellTexture(spellID)
        if type(texture) == "number" and not (issecretvalue and issecretvalue(texture)) then
            return texture
        end
    end
    return nil
end

local function ItemIcon(itemID)
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

function API:Icon(action)
    action = CopyAction(action)
    if not action then
        return nil
    end
    if action.kind == "spell" then
        return SpellIcon(action.spellID)
    end
    if action.kind == "item" then
        return ItemIcon(action.itemID)
    end
    if action.macroIndex and GetMacroInfo then
        local _, texture = GetMacroInfo(action.macroIndex)
        if type(texture) == "number" and not (issecretvalue and issecretvalue(texture)) then
            return texture
        end
    end
    return 134400
end

function API:Rows()
    return ROWS
end

local function PickupSpell(spellID)
    if C_Spell and C_Spell.PickupSpell then
        pcall(C_Spell.PickupSpell, spellID)
    elseif _G.PickupSpell then
        pcall(_G.PickupSpell, spellID)
    end
    return GetCursorInfo and GetCursorInfo() ~= nil
end

local function FindMacro(action)
    if action.macroName and GetMacroIndexByName then
        local index = GetMacroIndexByName(action.macroName)
        index = LPL:PlainNumber(index)
        if index and index > 0 then
            return index
        end
    end
    if action.macroBody and GetMacroBody then
        local maxGlobal = MAX_ACCOUNT_MACROS or 120
        local maxChar = MAX_CHARACTER_MACROS or 18
        for index = 1, maxGlobal + maxChar do
            local body = LPL:PlainString(GetMacroBody(index))
            if body and body == action.macroBody then
                return index
            end
        end
    end
    return action.macroIndex
end

local function CursorHasItem()
    return GetCursorInfo and GetCursorInfo() ~= nil
end

local function PutOnCursor(action)
    if InCombatLockdown and InCombatLockdown() then
        return false
    end
    action = CopyAction(action)
    if not action then
        return false
    end
    if ClearCursor then
        ClearCursor()
    end
    if action.kind == "spell" then
        if not PickupSpell(action.spellID) then
            local base = C_Spell and C_Spell.GetBaseSpell and LPL:PlainNumber(C_Spell.GetBaseSpell(action.spellID))
            if not base or not PickupSpell(base) then
                if ClearCursor then
                    ClearCursor()
                end
                return false
            end
        end
        return true
    end
    if action.kind == "item" then
        if C_Item and C_Item.PickupItem then
            pcall(C_Item.PickupItem, action.itemID)
        elseif PickupItem then
            pcall(PickupItem, action.itemID)
        end
    elseif action.kind == "macro" then
        local index = FindMacro(action)
        if index and PickupMacro then
            pcall(PickupMacro, index)
        end
    end
    if CursorHasItem() then
        return true
    end
    if ClearCursor then
        ClearCursor()
    end
    return false
end

function API:Pickup(action)
    return PutOnCursor(action)
end

local function PlaceSaved(slot, action)
    if not PutOnCursor(action) then
        return false
    end
    local function CursorToken()
        if not GetCursorInfo then
            return ""
        end
        local cursorType, cursorID = GetCursorInfo()
        if not cursorType then
            return ""
        end
        return tostring(cursorType) .. ":" .. tostring(LPL:PlainNumber(cursorID) or "")
    end
    local before = CursorToken()
    PlaceAction(slot)
    local after = CursorToken()
    ClearCursor()
    return before ~= "" and before ~= after
end

local function ClearSlot(slot)
    if not GetActionInfo(slot) and not (C_ActionBar and C_ActionBar.GetSpell and C_ActionBar.GetSpell(slot)) then
        return true
    end
    ClearCursor()
    PickupAction(slot)
    ClearCursor()
    return not GetActionInfo(slot)
end

function API:Apply(set)
    if not self:Available() then
        return false, "Action bars are not available on this client."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat, then apply action bars."
    end
    if type(set) ~= "table" then
        return false, "Select a saved action bar set first."
    end
    local placed, failed, cleared = 0, 0, 0
    for rowIndex = 1, #ROWS do
        local row = ROWS[rowIndex]
        if not row.isPet then
        for slot = row.first, row.last do
            local saved = CopyAction(set.slots and set.slots[tostring(slot)])
            local live, hidden = self:ReadSlot(slot)
            local ignored = type(set.ignored) == "table" and set.ignored[tostring(slot)] == true
            if ignored or hidden == "leave" then
                -- Leave this button alone.
            elseif hidden == true then
                failed = failed + 1
            elseif hidden then
                -- Flyouts and other buttons this version does not store stay as they are.
            elseif SameAction(saved, live) then
                -- already matches
            elseif not saved then
                local ok, clearedOk = pcall(ClearSlot, slot)
                if ok and clearedOk then
                    cleared = cleared + 1
                else
                    failed = failed + 1
                end
            else
                local ok, placedOk = pcall(PlaceSaved, slot, saved)
                if ok and placedOk then
                    placed = placed + 1
                else
                    failed = failed + 1
                end
            end
        end
        end
    end
    if failed > 0 then
        return false, "Put " .. placed .. " buttons on your bars. " .. failed .. " could not be placed. Those spells, items, or macros are missing."
    end
    if placed == 0 and cleared == 0 then
        return true, "These bars already match your character."
    end
    return true, "Updated your action bars (" .. placed .. " placed, " .. cleared .. " cleared)."
end

function API:ShowTooltip(owner, action, slotLabel)
    if not owner or not GameTooltip then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    action = CopyAction(action)
    if action and action.kind == "spell" and GameTooltip.SetSpellByID then
        GameTooltip:SetSpellByID(action.spellID)
    elseif action and action.kind == "item" and GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(action.itemID)
    elseif action and action.kind == "macro" then
        GameTooltip:SetText(action.macroName or "Macro", 1, 0.82, 0)
    else
        GameTooltip:SetText("Empty", 0.8, 0.8, 0.8)
    end
    if slotLabel then
        GameTooltip:AddLine(slotLabel, 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end
