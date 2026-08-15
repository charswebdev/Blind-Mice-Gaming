local addonName, LPL = ...

LPL.ActionBarActive = {}

local defs = LPL.ActionBarDefinitions

local function FindBaseSpellByID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil
    end
    if C_Spell and C_Spell.GetBaseSpell then
        local base = C_Spell.GetBaseSpell(spellID)
        if base and base > 0 then
            return base
        end
    end
    return spellID
end

local SWITCH_FLIGHT_STYLE = 436854

local SKYRIDING_SPELL_IDS = {
    [372608] = true, -- Surge Forward
    [372610] = true, -- Skyward Ascent
    [361584] = true, -- Whirling Surge
    [418592] = true, -- Lightning Rush
    [403092] = true, -- Aerial Halt
    [425782] = true, -- Second Wind
}

local function NormalizeFlightStyleSpellID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil
    end
    local base = FindBaseSpellByID(spellID) or spellID
    if SKYRIDING_SPELL_IDS[spellID] or SKYRIDING_SPELL_IDS[base] then
        return SKYRIDING_SPELL_IDS[base] and base or spellID
    end
    if spellID == SWITCH_FLIGHT_STYLE or base == SWITCH_FLIGHT_STYLE or spellID == 459988 or base == 459988 then
        return SWITCH_FLIGHT_STYLE
    end
    -- Live bar may show the active override; map it back when it overrides Switch Flight Style.
    if C_Spell and C_Spell.GetOverrideSpell then
        local ok, override = pcall(C_Spell.GetOverrideSpell, SWITCH_FLIGHT_STYLE)
        if ok and override and tonumber(override) == spellID then
            return SWITCH_FLIGHT_STYLE
        end
    end
    if FindSpellOverrideByID then
        local override = FindSpellOverrideByID(SWITCH_FLIGHT_STYLE)
        if override and tonumber(override) == spellID then
            return SWITCH_FLIGHT_STYLE
        end
    end
    return base
end

local function CompareSlot(slot, tbl)
    local actionType, id, subType = GetActionInfo(slot)

    if subType == "assistedcombat" then
        id = 1229376
        subType = "spell"
        actionType = actionType or "spell"
    end

    if (not actionType or actionType == "spell") and C_ActionBar and C_ActionBar.GetSpell then
        local barSpell = C_ActionBar.GetSpell(slot)
        if barSpell and barSpell > 0 then
            actionType = "spell"
            id = barSpell
            subType = subType or "spell"
        end
    end

    if actionType == "spell" and id then
        id = NormalizeFlightStyleSpellID(id) or FindBaseSpellByID(id)
        if id == 460905 then
            subType = "spell"
        elseif id == SWITCH_FLIGHT_STYLE then
            subType = "spell"
        end
    end

    if tbl == nil or tbl.type == nil then
        return actionType == nil
    end

    if actionType == "macro" and tbl.type == "macro" then
        return true
    end

    if actionType == "companion" and subType == "MOUNT" and tbl.type == "summonmount" then
        return id == select(2, C_MountJournal.GetDisplayedMountInfo(tbl.id))
    end

    if tbl.type == "companion" and tbl.subType == "MOUNT" and actionType == "summonmount" then
        return tbl.id == select(2, C_MountJournal.GetDisplayedMountInfo(id))
    end

    local targetId = tbl.id
    if tbl.type == "spell" and targetId then
        targetId = NormalizeFlightStyleSpellID(targetId) or FindBaseSpellByID(targetId)
    end

    if tbl.type == "spell" and actionType == "spell" then
        local liveSub = subType or "spell"
        local storedSub = tbl.subType or "spell"
        return targetId == id and liveSub == storedSub
    end

    return tbl.type == actionType and targetId == id and tbl.subType == subType
end

local function IsPetActionTextureValue(value)
    if type(value) == "number" and value > 0 then
        return true
    end
    if type(value) == "string" and value ~= "" then
        return true
    end
    return false
end

local function GetPetActionSlotFields(slot)
    local r1, r2, r3, r4, r5, r6, r7, r8 = GetPetActionInfo(slot)
    if r1 == nil and r2 == nil then
        return nil, nil, nil, nil, nil, nil, nil
    end
    if IsPetActionTextureValue(r2) then
        return r1, r2, r3, r4, r5, r6, r7
    end
    if IsPetActionTextureValue(r3) then
        return r1, r3, r4, r5, r6, r7, r8
    end
    return r1, r2, r3, r4, r5, r6, r7
end

local function ComparePetSlot(slot, tbl)
    if not GetPetActionInfo then
        return tbl == nil
    end

    local name, texture, isToken, _, _, _, spellID = GetPetActionSlotFields(slot)
    local hasAction = (name and name ~= "") or IsPetActionTextureValue(texture)
    if not hasAction then
        return tbl == nil or tbl.type == nil
    end
    if tbl == nil or tbl.type == nil or tbl.type ~= "petspell" then
        return false
    end
    if tbl.petActionNameToken and type(tbl.petActionNameToken) == "string" and tbl.petActionNameToken ~= "" then
        return isToken and name == tbl.petActionNameToken
    end
    if tbl.petTextureToken and type(tbl.petTextureToken) == "string" and tbl.petTextureToken:match("^PET_") then
        if not isToken then
            return false
        end
        local barToken = (type(texture) == "string" and texture:match("^PET_[A-Z0-9_]+$")) and texture or nil
        return barToken == tbl.petTextureToken
    end
    if type(tbl.rawTexture) == "string" and tbl.rawTexture:match("^PET_") then
        if not isToken then
            return false
        end
        local barToken = (type(texture) == "string" and texture:match("^PET_[A-Z0-9_]+$")) and texture or nil
        return barToken == tbl.rawTexture
    end
    if tbl.petBookActionID and tbl.petBookActionID ~= 0 then
        return false
    end
    spellID = spellID and spellID ~= 0 and (FindBaseSpellByID(spellID) or spellID) or spellID
    local targetID = tbl.id and (FindBaseSpellByID(tbl.id) or tbl.id) or tbl.id
    if tbl.spellID and tbl.spellID ~= 0 then
        local spellTarget = FindBaseSpellByID(tbl.spellID) or tbl.spellID
        if spellTarget == spellID then
            return true
        end
    end
    return targetID == spellID
end

function LPL.ActionBarActive:IsActive(set)
    if type(set) ~= "table" then
        return false
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayer(set.restrictions) then
        return false
    end

    local hasDefinedSlots = false

    for _, slot in ipairs(defs:GetManagedPlayerSlots()) do
        if not set.ignored or not set.ignored[slot] then
            local action = set.actions and set.actions[slot]
            if action and action.type then
                hasDefinedSlots = true
                if not CompareSlot(slot, action) then
                    return false
                end
            end
        end
    end

    for slot = 1, defs.PET_SLOT_MAX do
        if not set.petIgnored or not set.petIgnored[slot] then
            local action = set.petActions and set.petActions[slot]
            if action and action.type then
                hasDefinedSlots = true
                if not ComparePetSlot(slot, action) then
                    return false
                end
            end
        end
    end

    return hasDefinedSlots
end
