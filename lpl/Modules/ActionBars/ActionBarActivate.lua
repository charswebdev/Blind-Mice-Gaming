local addonName, LPL = ...

LPL.ActionBarActivate = {}

local defs = LPL.ActionBarDefinitions
local PET_SLOT_MAX = defs.PET_SLOT_MAX

local ActionCacheA, ActionCacheB = {}, {}

local function Fail(message)
    print("|cffff6060LPL:|r " .. (message or "Could not apply action bar set."))
    return false, message
end

local function Success(message)
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play()
    end
    print("|cff33cc33LPL:|r " .. message)
    return true
end

local function Trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or ""
end

local function Push(tbl, ...)
    local n = select("#", ...)
    for i = 1, n do
        tbl[i] = select(i, ...)
    end
    tbl.n = n
end

local function CompareCursor(a, b)
    if a.n ~= b.n then
        return false
    end
    for i = 1, a.n do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

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

-- Utility spells that may not appear in Main Spec (Skyriding) or the spellbook at all (Housing),
-- or that PickupSpellBookItem fails to resolve reliably (General / account utilities).
local SWITCH_FLIGHT_STYLE = 436854
local WARBAND_DISTANCE_INHIBITOR = 460905
local TELEPORT_HOME = 1233637

local UTILITY_SPELL_IDS = {
    [SWITCH_FLIGHT_STYLE] = true, -- Switch Flight Style (base)
    [459988] = true, -- Switch Flight Style related override controller
    [WARBAND_DISTANCE_INHIBITOR] = true, -- Warband Bank Distance Inhibitor
    [TELEPORT_HOME] = true, -- Teleport Home / Teleport to Plot
}

-- Skyriding bar abilities (often live in a spellbook flyout; PickupSpellBookItem grabs the flyout).
local SKYRIDING_SPELL_IDS = {
    [372608] = true, -- Surge Forward
    [372610] = true, -- Skyward Ascent
    [361584] = true, -- Whirling Surge
    [418592] = true, -- Lightning Rush
    [403092] = true, -- Aerial Halt
    [425782] = true, -- Second Wind
}

local function IsSkyridingSpellID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return false
    end
    if SKYRIDING_SPELL_IDS[spellID] then
        return true
    end
    local base = FindBaseSpellByID(spellID)
    return base and SKYRIDING_SPELL_IDS[base] == true
end

local function IsSkyridingBarSlot(slot)
    slot = tonumber(slot)
    return slot and slot >= 121 and slot <= 132
end

local function GetSpellOverrideID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil
    end
    if C_Spell and C_Spell.GetOverrideSpell then
        local ok, override = pcall(C_Spell.GetOverrideSpell, spellID)
        if ok and type(override) == "number" and override > 0 then
            return override
        end
    end
    if FindSpellOverrideByID then
        local override = FindSpellOverrideByID(spellID)
        if type(override) == "number" and override > 0 then
            return override
        end
    end
    return spellID
end

-- Store / compare as the stable base id (Switch Flight Style has live overrides per flight mode).
local function NormalizeUtilitySpellID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil
    end
    local base = FindBaseSpellByID(spellID) or spellID
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
    if spellID == WARBAND_DISTANCE_INHIBITOR or base == WARBAND_DISTANCE_INHIBITOR then
        return WARBAND_DISTANCE_INHIBITOR
    end
    if spellID == TELEPORT_HOME or base == TELEPORT_HOME then
        return TELEPORT_HOME
    end
    if UTILITY_SPELL_IDS[base] then
        return base
    end
    -- Talent replacements (e.g. Blessing of Spellwarding) must keep their live id.
    return spellID
end

local function CanPickupSpellByID(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID < 1 then
        return false
    end

    local function check(id)
        if not id or id < 1 then
            return false
        end
        if IsSpellKnown and IsSpellKnown(id, false) then
            return true
        end
        if IsPlayerSpell and IsPlayerSpell(id) then
            return true
        end
        if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
            local ok, known = pcall(C_SpellBook.IsSpellKnownOrInSpellBook, id)
            if ok and known then
                return true
            end
        end
        if C_Spell and C_Spell.IsSpellUsable then
            local ok, usable = pcall(C_Spell.IsSpellUsable, id)
            if ok and usable then
                return true
            end
        end
        return false
    end

    if check(spellID) then
        return true
    end

    local override = GetSpellOverrideID(spellID)
    if override and override ~= spellID and check(override) then
        return true
    end

    local base = NormalizeUtilitySpellID(spellID) or spellID
    if UTILITY_SPELL_IDS[spellID] or UTILITY_SPELL_IDS[base] or IsSkyridingSpellID(spellID) then
        if C_Spell and C_Spell.DoesSpellExist then
            local ok, exists = pcall(C_Spell.DoesSpellExist, base)
            if ok and exists then
                return true
            end
            if override and override ~= base then
                ok, exists = pcall(C_Spell.DoesSpellExist, override)
                if ok and exists then
                    return true
                end
            end
        end
        return true
    end
    return false
end

local function PickupSpellDirect(spellID, test)
    if test then
        return true
    end
    spellID = tonumber(spellID)
    if not spellID then
        return false
    end
    if C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(spellID)
    elseif PickupSpell then
        PickupSpell(spellID)
    else
        return false
    end
    return GetCursorInfo() ~= nil
end


local function GetMacroByText(macroText)
    macroText = Trim(macroText)
    if macroText == "" then
        return nil
    end
    local maxGlobal = MAX_ACCOUNT_MACROS or 120
    local maxChar = MAX_CHARACTER_MACROS or 12
    for index = 1, maxGlobal + maxChar do
        local body = GetMacroBody and GetMacroBody(index)
        if body and Trim(body) == macroText then
            return index
        end
    end
    return nil
end

local function CreateMissingMacro(tbl)
    local macroText = Trim(tbl.macroText)
    if macroText == "" then
        return nil
    end
    local name = tbl.name or "LPL Macro"
    if not CreateMacro then
        return nil
    end
    local numGlobal = GetNumMacros and select(1, GetNumMacros()) or 0
    if numGlobal < (MAX_ACCOUNT_MACROS or 120) then
        return CreateMacro(name, "INV_Misc_QuestionMark", macroText, false)
    end
    local _, numChar = GetNumMacros()
    if numChar < (MAX_CHARACTER_MACROS or 12) then
        return CreateMacro(name, "INV_Misc_QuestionMark", macroText, true)
    end
    return nil
end

local function IsPetActionTextureValue(value)
    if value == nil then
        return false
    end
    if type(value) == "number" then
        return true
    end
    if type(value) == "string" then
        if value == "" then
            return false
        end
        if value:match("^PET_[A-Z0-9_]+$") then
            local globalValue = rawget(_G, value)
            if (type(globalValue) == "string" and globalValue ~= "")
                or (type(globalValue) == "number" and globalValue > 0) then
                return true
            end
        end
        if tonumber(value) then
            return true
        end
        if value:find("Interface\\", 1, true) or value:find("interface\\", 1, true) then
            return true
        end
        if C_Texture and C_Texture.GetAtlasInfo then
            local ok, info = pcall(C_Texture.GetAtlasInfo, value)
            if ok and info then
                return true
            end
        end
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

local function FindPetBarTokenSourceSlot(nameKey)
    if type(nameKey) ~= "string" or nameKey == "" then
        return nil
    end
    for slot = 1, PET_SLOT_MAX do
        local name, texture, isToken = GetPetActionSlotFields(slot)
        if isToken and type(name) == "string" and name ~= "" and name == nameKey then
            return slot
        end
        if isToken and type(texture) == "string" and texture == nameKey then
            return slot
        end
    end
    return nil
end

local function GetPetBarMoveTokenKey(tbl)
    if not tbl or tbl.type ~= "petspell" then
        return nil
    end
    if tbl.petBookActionID and tbl.petBookActionID ~= 0 then
        return nil
    end
    if tbl.spellID and tbl.spellID ~= 0 then
        return nil
    end
    if tbl.id and tbl.id ~= 0 then
        return nil
    end
    if type(tbl.petActionNameToken) == "string" and tbl.petActionNameToken ~= "" then
        return tbl.petActionNameToken
    end
    if type(tbl.petTextureToken) == "string" and tbl.petTextureToken:match("^PET_[A-Z0-9_]+$") then
        return tbl.petTextureToken
    end
    if type(tbl.rawTexture) == "string" and tbl.rawTexture:match("^PET_[A-Z0-9_]+$") then
        return tbl.rawTexture
    end
    return nil
end

local function PetSpellBookSlotCount()
    local n = 0
    if C_SpellBook and C_SpellBook.HasPetSpells then
        n = C_SpellBook.HasPetSpells() or 0
    end
    if type(n) ~= "number" or n < 0 then
        n = 0
    end
    if n == 0 and UnitExists and UnitExists("pet") then
        return 120
    end
    return n
end

local function SpellBookItemSpellIDForPet(info)
    if not info then
        return nil
    end
    if type(info.spellID) == "number" and info.spellID ~= 0 then
        return info.spellID
    end
    if type(info.actionID) == "number" and info.actionID ~= 0 then
        local sid
        if bit and bit.band then
            sid = bit.band(info.actionID, 0xFFFFFF)
        else
            sid = info.actionID % 16777216
        end
        if sid and sid ~= 0 then
            return sid
        end
    end
    if type(info.baseSpellID) == "number" and info.baseSpellID ~= 0 then
        return info.baseSpellID
    end
    return nil
end

local function PetSpellBookActionIDNorm(aid)
    if type(aid) ~= "number" or aid == 0 then
        return nil
    end
    if bit and bit.band then
        return bit.band(aid, 0xFFFFFF)
    end
    return aid % 16777216
end

local function PetSpellBookActionIDsMatch(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then
        return false
    end
    if a == b then
        return true
    end
    local na, nb = PetSpellBookActionIDNorm(a), PetSpellBookActionIDNorm(b)
    return na and nb and na == nb
end

local function GetGlobalKeyTextureFileID(globalKey)
    if type(globalKey) ~= "string" then
        return nil
    end
    local g = rawget(_G, globalKey)
    if type(g) == "number" and g > 0 then
        return g
    end
    if type(g) == "string" and g ~= "" and C_Texture and C_Texture.GetFileIDFromPath then
        local ok, fid = pcall(C_Texture.GetFileIDFromPath, g)
        if ok and type(fid) == "number" and fid > 0 then
            return fid
        end
    end
    return nil
end

local function FindPetSpellBookIndexByActionID(actionID)
    if not actionID or actionID == 0 then
        return nil
    end
    local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    local n = PetSpellBookSlotCount()
    if not (C_SpellBook and petBank and C_SpellBook.GetSpellBookItemInfo and n > 0) then
        return nil
    end
    for i = 1, n do
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, petBank)
        if ok and info and type(info.actionID) == "number" and PetSpellBookActionIDsMatch(info.actionID, actionID) then
            return i
        end
    end
    return nil
end

local function FindPetSpellBookPickupIndex(wantBase, rawSpellID)
    wantBase = tonumber(wantBase)
    rawSpellID = tonumber(rawSpellID)
    local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    local numPet = PetSpellBookSlotCount()
    if C_SpellBook and petBank and C_SpellBook.GetSpellBookItemInfo and numPet > 0 then
        for pass = 1, 3 do
            for i = 1, numPet do
                local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, petBank)
                if ok and info then
                    local sid = SpellBookItemSpellIDForPet(info)
                    if sid and sid ~= 0 then
                        local bookBase = FindBaseSpellByID(sid) or sid
                        local match = (pass == 1 and rawSpellID and rawSpellID ~= 0 and sid == rawSpellID)
                            or (pass == 2 and wantBase and sid == wantBase)
                            or (pass == 3 and wantBase and bookBase == wantBase)
                        if match then
                            return i
                        end
                    end
                end
            end
        end
    end
    if not GetSpellBookItemInfo then
        return nil
    end
    local spellIndex = 1
    local skillType, id = GetSpellBookItemInfo(spellIndex, "pet")
    while skillType do
        if id and id ~= 0 and (skillType == "SPELL" or skillType == "PETACTION") then
            local bookBase = FindBaseSpellByID(id) or id
            if (rawSpellID and rawSpellID ~= 0 and id == rawSpellID)
                or (wantBase and (id == wantBase or bookBase == wantBase)) then
                return spellIndex
            end
        end
        spellIndex = spellIndex + 1
        skillType, id = GetSpellBookItemInfo(spellIndex, "pet")
    end
    return nil
end

local function FindPetSpellBookIndexForPetToken(petToken, localizedName)
    local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    local n = PetSpellBookSlotCount()
    local petActionTy = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.PetAction
    if not (C_SpellBook and petBank and C_SpellBook.GetSpellBookItemInfo and n > 0) then
        return nil
    end
    local wantIcon
    if type(petToken) == "string" and petToken:match("^PET_[A-Z0-9_]+$") then
        wantIcon = GetGlobalKeyTextureFileID(petToken)
    end
    if wantIcon then
        for pass = 1, 2 do
            for i = 1, n do
                local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, petBank)
                if ok and info and type(info.iconID) == "number" and info.iconID == wantIcon then
                    if pass == 1 and petActionTy and info.itemType == petActionTy then
                        return i
                    end
                    if pass == 2 then
                        return i
                    end
                end
            end
        end
    end
    if type(localizedName) == "string" and localizedName ~= "" and petActionTy then
        for i = 1, n do
            local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, petBank)
            if ok and info and info.itemType == petActionTy and info.name == localizedName then
                return i
            end
        end
    end
    return nil
end

local function PickupPetBookIndex(idx, test)
    if not idx then
        return false
    end
    if test then
        return true
    end
    local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    if C_SpellBook and C_SpellBook.PickupSpellBookItem and petBank then
        C_SpellBook.PickupSpellBookItem(idx, petBank)
    elseif PickupSpellBookItem then
        PickupSpellBookItem(idx, "pet")
    else
        return false
    end
    return GetCursorInfo() ~= nil
end

local function PickupPetSpellDirect(spellID, test)
    spellID = tonumber(spellID)
    if not spellID or spellID < 1 then
        return false
    end
    if test then
        return true
    end
    if PickupPetSpell then
        PickupPetSpell(spellID)
        if GetCursorInfo() then
            return true
        end
    end
    if C_Spell and C_Spell.PickupSpell then
        C_Spell.PickupSpell(spellID)
        if GetCursorInfo() then
            return true
        end
    end
    return false
end

local function CompareSlot(slot, tbl)
    local actionType, id, subType = GetActionInfo(slot)

    if subType == "assistedcombat" then
        id = 1229376
        subType = "spell"
        actionType = actionType or "spell"
    end

    -- Prefer the authoritative spell id when GetActionInfo is incomplete.
    if (not actionType or not id) and C_ActionBar and C_ActionBar.GetSpell then
        local barSpell = C_ActionBar.GetSpell(slot)
        if barSpell and barSpell > 0 then
            actionType = "spell"
            id = barSpell
            subType = subType or "spell"
        end
    end

    if actionType == "spell" and id then
        id = LPL.ActionBarCodec:ResolveStoredSpellID(id, slot)
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
        targetId = LPL.ActionBarCodec:ResolveStoredSpellID(targetId)
    end

    if tbl.type == "spell" and actionType == "spell" then
        local liveSub = subType or "spell"
        local storedSub = tbl.subType or "spell"
        return targetId == id and liveSub == storedSub
    end

    return tbl.type == actionType and targetId == id and tbl.subType == subType
end

local function ComparePetSlot(slot, tbl)
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

local function FindSpellBookIndexForSpell(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil, nil
    end

    local playerBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
    local spellItemType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
    local flyoutItemType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout

    local function MatchesSpell(info)
        if not info then
            return false
        end
        local itemSpellID = info.spellID or info.actionID
        if not itemSpellID then
            return false
        end
        if itemSpellID == spellID then
            return true
        end
        local base = FindBaseSpellByID(itemSpellID)
        return base == spellID or itemSpellID == FindBaseSpellByID(spellID)
    end

    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
        -- includeHidden=true so Skyriding flyout utilities resolve.
        local ok, slot, bank = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellID, true, true, false, false)
        bank = bank or playerBank
        if ok and type(slot) == "number" and slot > 0 and C_SpellBook.GetSpellBookItemInfo then
            local info = C_SpellBook.GetSpellBookItemInfo(slot, bank)
            -- Reject flyouts: picking those up places the flyout, not the skyriding ability.
            if info and (not spellItemType or info.itemType == spellItemType) and MatchesSpell(info) then
                return slot, bank
            end
        end
    end

    if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookItemInfo then
        local numLines = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for lineIndex = 1, numLines do
            local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
            if skillLineInfo and skillLineInfo.numSpellBookItems and skillLineInfo.numSpellBookItems > 0 then
                local first = (skillLineInfo.itemIndexOffset or 0) + 1
                local last = (skillLineInfo.itemIndexOffset or 0) + skillLineInfo.numSpellBookItems
                for spellIndex = first, last do
                    local spellBookItem = C_SpellBook.GetSpellBookItemInfo(spellIndex, playerBank)
                    if spellBookItem then
                        if (not spellItemType or spellBookItem.itemType == spellItemType) and MatchesSpell(spellBookItem) then
                            return spellIndex, playerBank
                        end
                        -- Scan flyout contents for skyriding / general utilities.
                        if flyoutItemType and spellBookItem.itemType == flyoutItemType and spellBookItem.actionID and GetFlyoutInfo and GetFlyoutSlotInfo then
                            local _, _, numSlots, isKnown = GetFlyoutInfo(spellBookItem.actionID)
                            if isKnown and numSlots and numSlots > 0 then
                                for flyoutSlot = 1, numSlots do
                                    local flyoutSpellID, overrideSpellID = GetFlyoutSlotInfo(spellBookItem.actionID, flyoutSlot)
                                    local candidate = overrideSpellID and overrideSpellID ~= 0 and overrideSpellID or flyoutSpellID
                                    if candidate == spellID or FindBaseSpellByID(candidate) == spellID then
                                        -- Cannot pickup a flyout child via book index; signal caller to use direct pickup.
                                        return nil, nil, candidate
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return nil, nil
end

local function PickupSpellFromBook(spellID, subType, test)
    local rawID = tonumber(spellID)
    local storedID = NormalizeUtilitySpellID(spellID) or spellID
    if IsSkyridingSpellID(rawID) then
        local base = FindBaseSpellByID(rawID) or rawID
        spellID = SKYRIDING_SPELL_IDS[base] and base or rawID
    else
        spellID = storedID
    end
    subType = subType or "spell"

    if subType == "pet" then
        if IsSpellKnown and IsSpellKnown(spellID, true) then
            if not test and PickupPetSpell then
                PickupPetSpell(spellID)
            end
            return true
        end
        return false
    end

    local candidates = {}
    local function pushCandidate(id)
        id = tonumber(id)
        if not id or id < 1 then
            return
        end
        for _, existing in ipairs(candidates) do
            if existing == id then
                return
            end
        end
        candidates[#candidates + 1] = id
    end

    -- Override-first only for Switch Flight Style (Steady vs Skyriding versions).
    if spellID == SWITCH_FLIGHT_STYLE then
        pushCandidate(GetSpellOverrideID(spellID))
    end
    pushCandidate(spellID)
    if rawID then
        pushCandidate(rawID)
    end

    -- Skyriding abilities: always try direct pickup first (book flyout pickup is wrong).
    if IsSkyridingSpellID(spellID) or IsSkyridingSpellID(rawID) then
        for _, tryID in ipairs(candidates) do
            if PickupSpellDirect(tryID, test) then
                return true
            end
        end
        if test and CanPickupSpellByID(spellID) then
            return true
        end
    end

    for _, tryID in ipairs(candidates) do
        local bookIndex, bookBank, flyoutSpellID = FindSpellBookIndexForSpell(tryID)
        if flyoutSpellID and not bookIndex then
            if PickupSpellDirect(flyoutSpellID, test) or PickupSpellDirect(tryID, test) then
                return true
            end
        elseif bookIndex then
            if not test then
                if C_SpellBook and C_SpellBook.PickupSpellBookItem then
                    C_SpellBook.PickupSpellBookItem(bookIndex, bookBank or Enum.SpellBookSpellBank.Player)
                elseif PickupSpellBookItem then
                    PickupSpellBookItem(bookIndex, "spell")
                else
                    if PickupSpellDirect(tryID, test) then
                        return true
                    end
                end
                if GetCursorInfo() then
                    local cursorType, cursorID = GetCursorInfo()
                    -- If we accidentally picked a flyout, clear and fall back to direct spell pickup.
                    if cursorType == "flyout" then
                        ClearCursor()
                        if PickupSpellDirect(tryID, test) then
                            return true
                        end
                    else
                        return true
                    end
                end
            else
                return true
            end
        end
    end

    if GetSpellBookItemInfo then
        for _, tryID in ipairs(candidates) do
            local spellIndex = 1
            local skillType, id = GetSpellBookItemInfo(spellIndex, subType)
            while skillType do
                if skillType == "SPELL" and (id == tryID or FindBaseSpellByID(id) == spellID) then
                    if not test and PickupSpellBookItem then
                        PickupSpellBookItem(spellIndex, subType)
                    end
                    if test or GetCursorInfo() then
                        return true
                    end
                end
                spellIndex = spellIndex + 1
                skillType, id = GetSpellBookItemInfo(spellIndex, subType)
            end
        end
    end

    if C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs and PickupPvpTalent then
        local pvpTalents = C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
        for _, talentID in ipairs(pvpTalents) do
            if select(6, GetPvpTalentInfoByID(talentID)) == spellID then
                if not test then
                    PickupPvpTalent(talentID)
                end
                return true
            end
        end
    end

    -- Utility / remaining fallback: direct pickup.
    if CanPickupSpellByID(spellID) or UTILITY_SPELL_IDS[spellID] or IsSkyridingSpellID(spellID) then
        for _, tryID in ipairs(candidates) do
            if PickupSpellDirect(tryID, test) then
                return true
            end
        end
        if test then
            return true
        end
    end

    return false
end

local function PickupActionTable(tbl, test, activating)
    if tbl == nil or tbl.type == nil then
        return true, "Success"
    end

    local success, msg = true, "Success"
    local ok, err = pcall(function()
        if tbl.type == "macro" then
            local index = GetMacroByText(tbl.macroText)
            if not index or index == 0 then
                if activating then
                    index = CreateMissingMacro(tbl)
                elseif tbl.name and GetMacroIndexByName then
                    index = GetMacroIndexByName(tbl.name)
                end
            end
            if not index or index == 0 then
                success, msg = false, "Could not find or create macro."
            elseif not test then
                PickupMacro(index)
            end
        elseif tbl.type == "spell" then
            local rawID = tonumber(tbl.id)
            local pickupID = rawID
            if IsSkyridingSpellID(rawID) then
                local base = FindBaseSpellByID(rawID) or rawID
                pickupID = SKYRIDING_SPELL_IDS[base] and base or rawID
            else
                pickupID = NormalizeUtilitySpellID(tbl.id) or rawID
            end
            if PickupSpellFromBook(pickupID, tbl.subType, test) then
                success = true
            else
                success, msg = false, "Spell not found."
            end
        elseif tbl.type == "item" then
            local itemEquipLoc = select(4, GetItemInfoInstant(tbl.id))
            if C_ToyBox and C_ToyBox.GetToyInfo(tbl.id)
                or (itemEquipLoc ~= "" and GetItemCount(tbl.id) > 0)
                or (itemEquipLoc == "" and IsUsableItem(tbl.id)) then
                if not test then
                    PickupItem(tbl.id)
                end
            else
                success, msg = false, "Item unavailable."
            end
        elseif tbl.type == "summonmount" then
            if tbl.id == 0xFFFFFFF then
                if not test then
                    C_MountJournal.Pickup(0)
                end
            elseif not select(11, C_MountJournal.GetMountInfoByID(tbl.id)) then
                success, msg = false, "Mount is not available."
            elseif not test then
                local index
                for i = 1, C_MountJournal.GetNumDisplayedMounts() do
                    if select(12, C_MountJournal.GetDisplayedMountInfo(i)) == tbl.id then
                        index = i
                        break
                    end
                end
                if index then
                    C_MountJournal.Pickup(index)
                else
                    PickupSpell(select(2, C_MountJournal.GetMountInfoByID(tbl.id)))
                end
            end
        elseif tbl.type == "summonpet" then
            if not C_PetJournal.GetPetInfoByPetID(tbl.id) then
                success, msg = false, "Pet is not available."
            elseif not test then
                C_PetJournal.PickupPet(tbl.id)
            end
        elseif tbl.type == "companion" and tbl.subType == "MOUNT" then
            if not test then
                PickupSpell(tbl.id)
            end
        elseif tbl.type == "equipmentset" then
            local setID = C_EquipmentSet.GetEquipmentSetID(tbl.id)
            if not setID then
                success, msg = false, "Equipment set is not available."
            elseif not test then
                C_EquipmentSet.PickupEquipmentSet(setID)
            end
        elseif tbl.type == "flyout" then
            if not GetFlyoutInfo(tbl.id) then
                success, msg = false, "Flyout is not available."
            else
                local index
                if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo then
                    local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(Enum.SpellBookSkillLineIndex.MainSpec)
                    for spellIndex = 1, skillLineInfo.itemIndexOffset + skillLineInfo.numSpellBookItems do
                        local spellBookItem = C_SpellBook.GetSpellBookItemInfo(spellIndex, Enum.SpellBookSpellBank.Player)
                        if spellBookItem.itemType == Enum.SpellBookItemType.Flyout and spellBookItem.actionID == tbl.id then
                            index = spellIndex
                            break
                        end
                    end
                end
                if not index then
                    success, msg = false, "Flyout is not in spell book."
                elseif not test then
                    if C_SpellBook and C_SpellBook.PickupSpellBookItem then
                        C_SpellBook.PickupSpellBookItem(index, Enum.SpellBookSpellBank.Player)
                    elseif PickupSpellBookItem then
                        PickupSpellBookItem(index, "spell")
                    end
                end
            end
        elseif tbl.type == "petspell" then
            local barMoveKey = GetPetBarMoveTokenKey(tbl)
            if test and barMoveKey and FindPetBarTokenSourceSlot(barMoveKey) then
                success = true
            else
                success = false
                if tbl.petBookActionID and tbl.petBookActionID ~= 0 then
                    local idx = FindPetSpellBookIndexByActionID(tbl.petBookActionID)
                    if idx and PickupPetBookIndex(idx, test) then
                        success = true
                    end
                end

                local rawId = tonumber(tbl.spellID)
                local wantBase
                if tbl.id and tbl.id ~= 0 then
                    wantBase = FindBaseSpellByID(tbl.id) or tonumber(tbl.id)
                elseif rawId and rawId ~= 0 then
                    wantBase = FindBaseSpellByID(rawId) or rawId
                end
                if wantBase and wantBase ~= 0 then
                    tbl.id = wantBase
                end

                if not success and wantBase and wantBase ~= 0 then
                    local knownPick
                    if rawId and rawId ~= 0 and IsSpellKnown and IsSpellKnown(rawId, true) then
                        knownPick = rawId
                    elseif IsSpellKnown and IsSpellKnown(wantBase, true) then
                        knownPick = wantBase
                    end
                    local bookIndex = FindPetSpellBookPickupIndex(wantBase, rawId)
                    if knownPick then
                        if PickupPetSpellDirect(knownPick, test) then
                            success = true
                        elseif test then
                            success = true
                        end
                    elseif bookIndex then
                        success = PickupPetBookIndex(bookIndex, test)
                    else
                        if PickupPetSpellDirect(rawId, test) or PickupPetSpellDirect(wantBase, test) then
                            success = true
                        elseif test then
                            success = CanPickupSpellByID(wantBase) or (rawId and CanPickupSpellByID(rawId))
                        end
                    end
                end

                if not success then
                    local petToken = tbl.petTextureToken
                    if type(petToken) ~= "string" or not petToken:match("^PET_") then
                        petToken = (type(tbl.rawTexture) == "string" and tbl.rawTexture:match("^PET_[A-Z0-9_]+$")) and tbl.rawTexture or nil
                    end
                    if petToken then
                        local idx = FindPetSpellBookIndexForPetToken(petToken, tbl.name)
                        if idx and PickupPetBookIndex(idx, test) then
                            success = true
                        end
                    end
                end

                if not success and not test then
                    success = PickupSpellFromBook(tbl.id or tbl.spellID, "pet", false)
                elseif not success and test and (tbl.id or tbl.spellID) then
                    success = PickupSpellFromBook(tbl.id or tbl.spellID, "pet", true)
                end
                if not success then
                    msg = "Pet spell not found."
                end
            end
        else
            success, msg = false, "Unsupported action type."
        end
    end)

    if not ok then
        success, msg = false, "Error: " .. tostring(err)
    end

    return success, msg
end

local function SetPlayerAction(slot, tbl)
    local success, done, msg = true, true, "Success"

    ClearCursor()
    success, msg = PickupActionTable(tbl, false, true)

    -- Skyriding bar: if book pickup failed, force direct spell pickup.
    if (not success or not GetCursorInfo()) and tbl and tbl.type == "spell" and (IsSkyridingBarSlot(slot) or IsSkyridingSpellID(tbl.id)) then
        ClearCursor()
        local rawID = tonumber(tbl.id)
        local tryIDs = { rawID, FindBaseSpellByID(rawID) }
        for _, tryID in ipairs(tryIDs) do
            if tryID and PickupSpellDirect(tryID, false) then
                success, msg = true, "Success"
                break
            end
        end
    end

    if success then
        if tbl == nil or tbl.type == nil then
            PickupAction(slot)
            ClearCursor()
        elseif GetCursorInfo() then
            Push(ActionCacheA, GetCursorInfo())
            PlaceAction(slot)
            Push(ActionCacheB, GetCursorInfo())
            if CompareCursor(ActionCacheA, ActionCacheB) then
                -- One more attempt for skyriding slots with direct pickup.
                if IsSkyridingBarSlot(slot) and tbl and tbl.type == "spell" then
                    ClearCursor()
                    if PickupSpellDirect(tonumber(tbl.id), false) then
                        Push(ActionCacheA, GetCursorInfo())
                        PlaceAction(slot)
                        Push(ActionCacheB, GetCursorInfo())
                        if not CompareCursor(ActionCacheA, ActionCacheB) then
                            ClearCursor()
                            return true, true, "Success"
                        end
                    end
                end
                success, done, msg = false, false, "Failed to place action."
            end
        else
            success, done, msg = false, false, "Failed to pickup action."
        end
    end

    ClearCursor()
    return success, done, msg
end

local function SetPetBarAction(slot, tbl)
    local success, done, msg = true, true, "Success"

    ClearCursor()
    if tbl == nil or tbl.type == nil then
        PickupPetAction(slot)
        ClearCursor()
        return true, true
    end

    local barMoveKey = GetPetBarMoveTokenKey(tbl)
    if barMoveKey then
        local sourceSlot = FindPetBarTokenSourceSlot(barMoveKey)
        if sourceSlot then
            if sourceSlot ~= slot then
                PickupPetAction(sourceSlot)
                PickupPetAction(slot)
            end
            ClearCursor()
            return true, true
        end
    end

    -- Prefer PickupPetSpell + PickupPetAction for known pet spells (in-game bar behavior).
    if tbl.type == "petspell" and not (tbl.petBookActionID and tbl.petBookActionID ~= 0) then
        local wantSpell = (tbl.spellID and tbl.spellID ~= 0) and tbl.spellID
            or ((tbl.id and tbl.id ~= 0) and tbl.id or nil)
        if wantSpell then
            local base = FindBaseSpellByID(wantSpell) or wantSpell
            local pickID
            if tbl.spellID and tbl.spellID ~= 0 and IsSpellKnown and IsSpellKnown(tbl.spellID, true) then
                pickID = tbl.spellID
            elseif IsSpellKnown and IsSpellKnown(base, true) then
                pickID = base
            end
            if pickID then
                if PickupPetSpellDirect(pickID, false) then
                    PickupPetAction(slot)
                    if not GetCursorInfo() then
                        ClearCursor()
                        return true, true
                    end
                end
                ClearCursor()
            end
        end
    end

    success, msg = PickupActionTable(tbl, false, true)

    -- Extra retries for pet spells (book index / direct / token).
    if (not success or not GetCursorInfo()) and tbl.type == "petspell" then
        ClearCursor()
        local rawId = tonumber(tbl.spellID)
        local wantBase = FindBaseSpellByID(tbl.id or rawId) or tonumber(tbl.id) or rawId
        local bookIndex = FindPetSpellBookPickupIndex(wantBase, rawId)
        if bookIndex and PickupPetBookIndex(bookIndex, false) then
            success, msg = true, "Success"
        end
        if (not success or not GetCursorInfo()) and (PickupPetSpellDirect(rawId, false) or PickupPetSpellDirect(wantBase, false)) then
            success, msg = true, "Success"
        end
        if (not success or not GetCursorInfo()) and tbl.petBookActionID and tbl.petBookActionID ~= 0 then
            local idx = FindPetSpellBookIndexByActionID(tbl.petBookActionID)
            if idx and PickupPetBookIndex(idx, false) then
                success, msg = true, "Success"
            end
        end
        if not success or not GetCursorInfo() then
            local petToken = tbl.petTextureToken
            if type(petToken) ~= "string" or not petToken:match("^PET_") then
                petToken = (type(tbl.rawTexture) == "string" and tbl.rawTexture:match("^PET_[A-Z0-9_]+$")) and tbl.rawTexture or nil
            end
            if petToken then
                local idx = FindPetSpellBookIndexForPetToken(petToken, tbl.name)
                if idx and PickupPetBookIndex(idx, false) then
                    success, msg = true, "Success"
                end
            end
        end
    end

    if success and GetCursorInfo() then
        Push(ActionCacheA, GetCursorInfo())
        PickupPetAction(slot)
        Push(ActionCacheB, GetCursorInfo())
        if CompareCursor(ActionCacheA, ActionCacheB) then
            -- One more direct attempt.
            ClearCursor()
            local tryID = tonumber(tbl.spellID) or tonumber(tbl.id)
            if tryID and PickupPetSpellDirect(tryID, false) then
                Push(ActionCacheA, GetCursorInfo())
                PickupPetAction(slot)
                Push(ActionCacheB, GetCursorInfo())
                if not CompareCursor(ActionCacheA, ActionCacheB) then
                    ClearCursor()
                    return true, true, "Success"
                end
            end
            success, done, msg = false, false, "Failed to place pet action."
        end
    elseif success then
        success, done, msg = false, false, "Failed to pickup pet action."
    end

    ClearCursor()
    return success, done, msg
end

local function ApplySetData(setData, setName)
    if not setData then
        return Fail("Invalid action bar set.")
    end

    if InCombatLockdown and InCombatLockdown() then
        return Fail("Cannot apply action bars in combat.")
    end

    if LPL.ActionBarCursor then
        LPL.ActionBarCursor:Clear()
    end

    if LPL.ActionBarCodec and LPL.ActionBarCodec.SanitizeDraft then
        LPL.ActionBarCodec:SanitizeDraft(setData)
    end

    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayer(setData.restrictions) then
        local summary = LPL.SetRestrictions:GetSummaryLine(setData.restrictions)
            or "another character, class, or specialization"
        return Fail("This set is restricted to " .. summary .. ".")
    end

    local complete = true
    local managedSlots = defs:GetManagedPlayerSlots()

    for _, slot in ipairs(managedSlots) do
        if not setData.ignored or not setData.ignored[slot] then
            local action = setData.actions and setData.actions[slot]
            local actionType = GetActionInfo(slot)
            if not CompareSlot(slot, action) or actionType == "macro" then
                local _, done = SetPlayerAction(slot, action)
                if not done then
                    complete = false
                end
            end
        end
    end

    setData.petActions = setData.petActions or {}
    setData.petIgnored = setData.petIgnored or {}
    for slot = 1, PET_SLOT_MAX do
        if not setData.petIgnored[slot] then
            local action = setData.petActions[slot]
            if not ComparePetSlot(slot, action) then
                local _, done = SetPetBarAction(slot, action)
                if not done then
                    complete = false
                end
            end
        end
    end

    setName = setName or setData.name or "Action Bar Set"
    if complete then
        return Success(string.format('Applied "%s" to your action bars.', setName))
    end
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play()
    end
    print(string.format(
        "|cffffcc00LPL:|r Applied \"%s\" with some slots skipped (missing spells, items, or unavailable actions).",
        setName
    ))
    return true
end

function LPL.ActionBarActivate:ApplySetNow(setData, setName)
    return ApplySetData(setData, setName)
end

function LPL.ActionBarActivate:ApplySet(setID)
    if not setID then
        return Fail("No action bar set selected.")
    end
    local set = LPL.ActionBarStore:Get(setID)
    if not set then
        return Fail("Action bar set not found.")
    end
    return ApplySetData(set, set.name)
end

function LPL.ActionBarActivate:ApplyDraft(draftSet, name)
    if not draftSet then
        return Fail("No action bar set to apply.")
    end
    return ApplySetData(draftSet, name or draftSet.name)
end

function LPL.ActionBarActivate:PickupAction(tbl)
    local success = PickupActionTable(tbl, false, false)
    return success == true
end
