local addonName, LPL = ...

LPL.ActionBarCodec = {}

local defs = LPL.ActionBarDefinitions
local DEFAULT_ICON = 134400

local function Trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or ""
end

local SWITCH_FLIGHT_STYLE = 436854
local WARBAND_DISTANCE_INHIBITOR = 460905
local TELEPORT_HOME = 1233637

local SKYRIDING_SPELL_IDS = {
    [372608] = true, -- Surge Forward
    [372610] = true, -- Skyward Ascent
    [361584] = true, -- Whirling Surge
    [418592] = true, -- Lightning Rush
    [403092] = true, -- Aerial Halt
    [425782] = true, -- Second Wind
}

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
    return nil
end

local function GetSpellNameAndIcon(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil, nil
    end
    local name, icon
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" then
            name = info.name
            icon = info.iconID or info.originalIconID
        end
    end
    if (not icon or icon == 0) and C_Spell and C_Spell.GetSpellTexture then
        local ok, tex = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and tex and tex ~= 0 then
            icon = tex
        end
    end
    if name and icon then
        return name, icon
    end
    if GetSpellInfo then
        local nameOrInfo, _, legacyIcon = GetSpellInfo(spellID)
        if type(nameOrInfo) == "table" then
            return name or nameOrInfo.name, icon or nameOrInfo.iconID or nameOrInfo.originalIconID
        end
        return name or nameOrInfo, icon or legacyIcon
    end
    return name, icon
end

-- Collapse only known utility overrides (flight style, skyriding, housing).
-- Talent replacements such as Blessing of Spellwarding must keep their live spell id.
local function NormalizeCapturedSpellID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return nil
    end
    local baseID = FindBaseSpellByID(spellID) or spellID
    if SKYRIDING_SPELL_IDS[spellID] or SKYRIDING_SPELL_IDS[baseID] then
        return SKYRIDING_SPELL_IDS[baseID] and baseID or spellID
    end
    if spellID == WARBAND_DISTANCE_INHIBITOR or baseID == WARBAND_DISTANCE_INHIBITOR then
        return WARBAND_DISTANCE_INHIBITOR
    end
    if spellID == TELEPORT_HOME or baseID == TELEPORT_HOME then
        return TELEPORT_HOME
    end
    if spellID == SWITCH_FLIGHT_STYLE or baseID == SWITCH_FLIGHT_STYLE or spellID == 459988 or baseID == 459988 then
        return SWITCH_FLIGHT_STYLE
    end
    local flightOverride = GetSpellOverrideID(SWITCH_FLIGHT_STYLE)
    if flightOverride and flightOverride == spellID then
        return SWITCH_FLIGHT_STYLE
    end
    return spellID
end

local function IsUtilityStoreSpellID(spellID)
    spellID = tonumber(spellID)
    if not spellID then
        return false
    end
    local baseID = FindBaseSpellByID(spellID) or spellID
    return spellID == SWITCH_FLIGHT_STYLE
        or baseID == SWITCH_FLIGHT_STYLE
        or spellID == 459988
        or baseID == 459988
        or spellID == WARBAND_DISTANCE_INHIBITOR
        or baseID == WARBAND_DISTANCE_INHIBITOR
        or spellID == TELEPORT_HOME
        or baseID == TELEPORT_HOME
        or SKYRIDING_SPELL_IDS[spellID] == true
        or SKYRIDING_SPELL_IDS[baseID] == true
end

-- When the bar reports a base spell (Blessing of Protection) but the slot shows
-- the talent replacement (Blessing of Spellwarding), keep the replacement.
local function PreferDisplayedOverrideSpellID(slot, spellID)
    spellID = tonumber(spellID)
    if not spellID or IsUtilityStoreSpellID(spellID) then
        return spellID
    end

    local slotTex = GetActionTexture and GetActionTexture(slot)
    local function IconMatchesSlot(candidate)
        if not slotTex or slotTex == 0 or not candidate then
            return false
        end
        local _, icon = GetSpellNameAndIcon(candidate)
        return icon ~= nil and icon == slotTex
    end

    if C_ActionBar and C_ActionBar.GetSpell then
        local barSpell = tonumber(C_ActionBar.GetSpell(slot))
        if barSpell and barSpell > 0 and barSpell ~= spellID and not IsUtilityStoreSpellID(barSpell) then
            local barBase = FindBaseSpellByID(barSpell) or barSpell
            local reportedBase = FindBaseSpellByID(spellID) or spellID
            local sameFamily = barBase == reportedBase or barBase == spellID or reportedBase == barSpell
            -- Prefer the specific override id (Spellwarding) over the base (Protection).
            if sameFamily and barSpell ~= barBase then
                spellID = barSpell
            elseif IconMatchesSlot(barSpell) and not IconMatchesSlot(spellID) then
                spellID = barSpell
            end
        end
    end

    local override = GetSpellOverrideID(spellID)
    if override and override ~= spellID and not IsUtilityStoreSpellID(override) then
        if IconMatchesSlot(override) and not IconMatchesSlot(spellID) then
            return override
        end
    end
    return spellID
end

function LPL.ActionBarCodec:ResolveStoredSpellID(spellID, slot)
    if slot and C_ActionBar and C_ActionBar.GetSpell then
        local barSpell = tonumber(C_ActionBar.GetSpell(slot))
        if barSpell and barSpell > 0 and IsUtilityStoreSpellID(barSpell) then
            spellID = barSpell
        end
    end
    spellID = NormalizeCapturedSpellID(spellID)
    if slot then
        spellID = PreferDisplayedOverrideSpellID(slot, spellID)
    end
    return spellID
end

local function IsSpellBookBank(value)
    if value == "spell" or value == "pet" or value == "professions" then
        return true
    end
    local banks = Enum and Enum.SpellBookSpellBank
    if banks then
        return value == banks.Player or value == banks.Pet
    end
    return type(value) == "number" and value >= 0 and value <= 2
end

local function SpellIDFromBookItem(index, bank)
    index = tonumber(index)
    if not index or index < 1 then
        return nil
    end
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo then
        local resolvedBank = bank
        local banks = Enum and Enum.SpellBookSpellBank
        if banks then
            if bank == "pet" then
                resolvedBank = banks.Pet
            elseif bank == "spell" or bank == "professions" or bank == nil then
                resolvedBank = banks.Player
            end
        end
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, index, resolvedBank)
        if ok and type(info) == "table" then
            return tonumber(info.spellID) or tonumber(info.actionID)
        end
    end
    if GetSpellBookItemInfo then
        local bookType = (bank == "pet") and "pet" or "spell"
        local skillType, id = GetSpellBookItemInfo(index, bookType)
        if (skillType == "SPELL" or skillType == "PETACTION") and tonumber(id) then
            return tonumber(id)
        end
    end
    return nil
end

-- GetCursorInfo("spell") is: spellIndex, bookType, spellID, baseSpellID.
-- Using the first number as a spell id maps General-tab slots onto unrelated
-- spells (e.g. book index 53 -> Backstab).
local function ResolveCursorSpell()
    local cursorType, a2, a3, a4, a5 = GetCursorInfo()
    if cursorType ~= "spell" then
        return nil
    end

    local spellID
    if type(a4) == "number" and a4 > 0 then
        spellID = a4
    elseif IsSpellBookBank(a3) then
        spellID = SpellIDFromBookItem(a2, a3) or tonumber(a2)
    else
        spellID = tonumber(a2)
    end

    local subType = "spell"
    if a3 == "pet" or (Enum and Enum.SpellBookSpellBank and a3 == Enum.SpellBookSpellBank.Pet) then
        subType = "pet"
    end

    return spellID, subType, tonumber(a5)
end

local function IsQuestionMarkIcon(icon)
    if icon == nil or icon == false or icon == 0 then
        return true
    end
    if icon == DEFAULT_ICON then
        return true
    end
    if type(icon) == "string" then
        local lower = icon:lower()
        if lower == "" or lower:find("inv_misc_questionmark", 1, true) then
            return true
        end
    end
    return false
end

local function PreferResolvedIcon(preferred, fallback)
    if preferred and not IsQuestionMarkIcon(preferred) then
        return preferred
    end
    if fallback and not IsQuestionMarkIcon(fallback) then
        return fallback
    end
    return preferred or fallback
end

local function GetItemIconSafe(item)
    if item == nil or item == "" then
        return nil
    end
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, item)
        if ok and icon and icon ~= 0 then
            return icon
        end
    end
    if GetItemIcon then
        local icon = GetItemIcon(item)
        if icon and icon ~= 0 then
            return icon
        end
    end
    if GetItemInfoInstant then
        local icon = select(5, GetItemInfoInstant(item))
        if icon and icon ~= 0 then
            return icon
        end
    end
    return nil
end

local function ParseSecureToken(text)
    text = Trim(text)
    if text == "" then
        return ""
    end
    text = text:gsub("%-%-.*$", "")
    text = Trim(text)
    if text ~= "" and SecureCmdOptionParse then
        local ok, parsed = pcall(SecureCmdOptionParse, text)
        if ok and type(parsed) == "string" then
            text = Trim(parsed)
        end
    end
    return text
end

local function FirstMacroActionToken(body)
    if type(body) ~= "string" or body == "" then
        return nil
    end

    local tooltip = body:match("^%s*#showtooltip%s*([^\r\n]*)")
        or body:match("^%s*#show%s*([^\r\n]*)")
    tooltip = ParseSecureToken(tooltip or "")
    if tooltip ~= "" then
        local first = Trim((tooltip:match("^([^,;]+)") or tooltip))
        if first ~= "" then
            return first
        end
    end

    for line in body:gmatch("([^\r\n]+)") do
        local cmd, rest = Trim(line):match("^/(%w+)%s*(.*)$")
        if cmd then
            cmd = cmd:lower()
            rest = ParseSecureToken(rest or "")
            if cmd == "castsequence" or cmd == "castrandom" or cmd == "userandom" then
                rest = Trim(rest:gsub("[Rr]eset=[^%s]+%s*", ""))
            end
            if (cmd == "cast" or cmd == "use" or cmd == "spell"
                or cmd == "castsequence" or cmd == "castrandom" or cmd == "userandom")
                and rest ~= "" then
                local first = Trim((rest:match("^([^,;]+)") or rest))
                if first ~= "" then
                    return first
                end
            end
        end
    end
    return nil
end

local function IconFromActionToken(token)
    token = Trim(token)
    if token == "" then
        return nil
    end

    local itemID = token:match("^[Ii]tem:(%d+)")
    if itemID then
        return GetItemIconSafe(tonumber(itemID))
    end

    if token:match("^%d+$") then
        local _, spellIcon = GetSpellNameAndIcon(tonumber(token))
        if spellIcon and not IsQuestionMarkIcon(spellIcon) then
            return spellIcon
        end
        return GetItemIconSafe(tonumber(token))
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, token)
        if ok and type(info) == "table" then
            local spellIcon = info.iconID or info.originalIconID
            if spellIcon and not IsQuestionMarkIcon(spellIcon) then
                return spellIcon
            end
        end
    end
    if GetSpellInfo then
        local nameOrInfo, _, legacyIcon = GetSpellInfo(token)
        if type(nameOrInfo) == "table" then
            local spellIcon = nameOrInfo.iconID or nameOrInfo.originalIconID
            if spellIcon and not IsQuestionMarkIcon(spellIcon) then
                return spellIcon
            end
        elseif legacyIcon and not IsQuestionMarkIcon(legacyIcon) then
            return legacyIcon
        end
    end

    return GetItemIconSafe(token)
end

local function MacroIndexExists(id)
    if id == nil or id == false or id == 0 or id == "" then
        return false
    end
    if not GetMacroInfo then
        return false
    end
    local name = GetMacroInfo(id)
    return type(name) == "string" and name ~= ""
end

-- GetCursorInfo("macro") is normally the global slot, but extra returns and
-- names show up the same way spell-book indexes did on the General tab.
local function ResolveCursorMacroID()
    local cursorType, a2, a3, a4, a5 = GetCursorInfo()
    if cursorType ~= "macro" then
        return nil
    end

    local candidates = { a2, a3, a4, a5 }
    for _, cand in ipairs(candidates) do
        if MacroIndexExists(cand) then
            return cand
        end
    end

    if type(a2) == "string" and a2 ~= "" and GetMacroIndexByName then
        local index = GetMacroIndexByName(a2)
        if index and index > 0 then
            return index
        end
    end

    return a2
end

-- Blizzard bars show GetActionTexture / GetMacroSpell, not the saved macro
-- icon. Macros that keep the default question mark (#showtooltip) would
-- otherwise be stored and drawn as INV_Misc_QuestionMark.
local function ResolveMacroVisual(id, slot)
    local name, icon, body
    if id ~= nil and GetMacroInfo then
        name, icon, body = GetMacroInfo(id)
    end
    body = Trim(body or (id ~= nil and GetMacroBody and GetMacroBody(id)) or "")

    local displayIcon = icon
    if slot and GetActionTexture then
        displayIcon = PreferResolvedIcon(GetActionTexture(slot), displayIcon)
    end

    if id ~= nil and GetMacroSpell then
        local spellID = tonumber(GetMacroSpell(id))
        if spellID and spellID > 0 then
            local _, spellIcon = GetSpellNameAndIcon(spellID)
            displayIcon = PreferResolvedIcon(spellIcon, displayIcon)
        end
    end

    if IsQuestionMarkIcon(displayIcon) and id ~= nil and GetMacroItem then
        local itemName, itemLink = GetMacroItem(id)
        displayIcon = PreferResolvedIcon(GetItemIconSafe(itemLink or itemName), displayIcon)
    end

    if IsQuestionMarkIcon(displayIcon) then
        displayIcon = PreferResolvedIcon(IconFromActionToken(FirstMacroActionToken(body)), displayIcon)
    end

    return name, displayIcon, body
end

local function BuildMacroAction(id, slot)
    if id == nil or id == false or id == 0 then
        return nil
    end

    local name, icon, body = ResolveMacroVisual(id, slot)
    if (not name or name == "") and body == "" then
        return nil
    end

    local numericID = tonumber(id)
    if not numericID and type(id) == "string" and GetMacroIndexByName then
        numericID = GetMacroIndexByName(id)
        if numericID == 0 then
            numericID = nil
        end
    end

    return {
        type = "macro",
        id = numericID or id,
        icon = icon,
        name = name,
        macroText = body,
    }
end

local function CopyAction(action)
    if type(action) ~= "table" or not action.type then
        return nil
    end
    return CopyTable(action)
end

local function GetActionsTable(draftSet, isPet)
    if isPet then
        draftSet.petActions = draftSet.petActions or {}
        return draftSet.petActions
    end
    draftSet.actions = draftSet.actions or {}
    return draftSet.actions
end

local function GetIgnoredTable(draftSet, isPet)
    if isPet then
        draftSet.petIgnored = draftSet.petIgnored or {}
        return draftSet.petIgnored
    end
    draftSet.ignored = draftSet.ignored or {}
    return draftSet.ignored
end

function LPL.ActionBarCodec:SanitizeDraft(draftSet)
    if not draftSet then
        return
    end
    draftSet.actions = draftSet.actions or {}
    draftSet.ignored = draftSet.ignored or {}
    draftSet.petActions = draftSet.petActions or {}
    draftSet.petIgnored = draftSet.petIgnored or {}
    for slot = 133, 144 do
        draftSet.actions[slot] = nil
        draftSet.ignored[slot] = true
    end
end

function LPL.ActionBarCodec:SetSlotAction(draftSet, slotID, isPet, action)
    if not draftSet or not slotID then
        return
    end
    local actions = GetActionsTable(draftSet, isPet)
    if action and action.type then
        actions[slotID] = CopyAction(action)
    else
        actions[slotID] = nil
    end
end

function LPL.ActionBarCodec:ClearSlotAction(draftSet, slotID, isPet)
    self:SetSlotAction(draftSet, slotID, isPet, nil)
end

function LPL.ActionBarCodec:ToggleSlotIgnore(draftSet, slotID, isPet)
    if not draftSet or not slotID then
        return
    end
    local ignored = GetIgnoredTable(draftSet, isPet)
    if ignored[slotID] then
        ignored[slotID] = nil
    else
        ignored[slotID] = true
    end
end

function LPL.ActionBarCodec:ToggleRowIgnore(draftSet, startID, endID, isPet)
    if not draftSet or not startID or not endID then
        return
    end
    local ignored = GetIgnoredTable(draftSet, isPet)
    local allIgnored = true
    for slotID = startID, endID do
        if not ignored[slotID] then
            allIgnored = false
            break
        end
    end
    for slotID = startID, endID do
        if allIgnored then
            ignored[slotID] = nil
        else
            ignored[slotID] = true
        end
    end
end

function LPL.ActionBarCodec:GetActionInfoFromSlot(slot)
    if not GetActionInfo then
        return nil
    end

    local actionType, id, subType = GetActionInfo(slot)
    -- General-tab utilities (Switch Flight Style, Warband Bank Distance Inhibitor)
    -- are more reliably identified by C_ActionBar.GetSpell than GetActionInfo.
    if C_ActionBar and C_ActionBar.GetSpell then
        local barSpell = tonumber(C_ActionBar.GetSpell(slot))
        if barSpell and barSpell > 0 then
            if not actionType then
                actionType = "spell"
                id = barSpell
                subType = "spell"
            elseif actionType == "spell" and IsUtilityStoreSpellID(barSpell) then
                id = barSpell
                subType = subType or "spell"
            end
        elseif not actionType then
            return nil
        end
    elseif not actionType then
        return nil
    end

    if subType == "assistedcombat" then
        id = 1229376
        subType = "spell"
        actionType = "spell"
    end

    -- Normalize only known utility overrides. Talent replacements keep their live spell id.
    if actionType == "spell" and id then
        id = self:ResolveStoredSpellID(id, slot)
        subType = subType or "spell"
    elseif actionType == "macro" and id and id ~= 0 then
        return BuildMacroAction(id, slot)
    elseif actionType == "macro" and (not id or id == 0) then
        return nil
    end

    local icon = GetActionTexture and GetActionTexture(slot)
    local name = GetActionText and GetActionText(slot)
    if actionType == "spell" and id then
        local spellName, spellIcon = GetSpellNameAndIcon(id)
        name = spellName or name
        -- Prefer the resolved spell's icon so talent replacements are not shown as their base.
        icon = spellIcon or icon
    end
    return {
        type = actionType,
        id = id,
        subType = subType or (actionType == "spell" and "spell" or nil),
        icon = icon,
        name = name,
    }
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

function LPL.ActionBarCodec:GetPetActionInfoFromSlot(slot)
    if not GetPetActionInfo then
        return nil
    end

    local name, texture, isToken, _, _, _, spellID = GetPetActionSlotFields(slot)
    if (not name or name == "") and not IsPetActionTextureValue(texture) then
        return nil
    end

    local petActionNameToken
    if isToken and type(name) == "string" and name ~= "" then
        petActionNameToken = name
    end
    local petTextureToken
    if type(texture) == "string" and texture:match("^PET_[A-Z0-9_]+$") then
        petTextureToken = texture
    end

    local displayName = name
    local rawTexture = texture
    if isToken and type(name) == "string" then
        displayName = _G[name] or name
    end
    if isToken and type(texture) == "string" and texture:match("^PET_[A-Z0-9_]+$") then
        local g = rawget(_G, texture)
        if type(g) == "number" or type(g) == "string" then
            texture = g
        end
    end

    spellID = spellID and spellID ~= 0 and spellID or nil
    local storeId = spellID and (FindBaseSpellByID(spellID) or spellID) or nil
    local icon = texture
    if type(icon) == "string" and tonumber(icon) then
        icon = tonumber(icon)
    end
    if spellID and GetSpellInfo then
        local spellName, _, spellIcon = GetSpellInfo(spellID)
        displayName = displayName or spellName
        icon = icon or spellIcon
    end

    return {
        type = "petspell",
        id = storeId,
        spellID = spellID,
        icon = icon,
        name = displayName,
        petActionNameToken = petActionNameToken,
        petTextureToken = petTextureToken,
        petBookActionID = nil,
        rawTexture = rawTexture,
    }
end

function LPL.ActionBarCodec:CaptureFromCharacter(draftSet)
    if not draftSet then
        return false
    end

    draftSet.actions = {}
    draftSet.petActions = {}
    draftSet.ignored = draftSet.ignored or {}
    draftSet.petIgnored = draftSet.petIgnored or {}

    for _, slot in ipairs(defs:GetManagedPlayerSlots()) do
        local action = self:GetActionInfoFromSlot(slot)
        if action then
            draftSet.actions[slot] = action
        end
    end

    for slot = 1, defs.PET_SLOT_MAX do
        local action = self:GetPetActionInfoFromSlot(slot)
        if action then
            draftSet.petActions[slot] = action
        end
    end

    self:SanitizeDraft(draftSet)
    LPL.ActionBarStore:ApplyPlayerMetadata(draftSet)

    return true
end

function LPL.ActionBarCodec:BuildActionTableFromCursor()
    if not GetCursorInfo then
        return nil
    end

    local cursorType, a2, a3 = GetCursorInfo()
    if not cursorType then
        return nil
    end

    if cursorType == "battlepet" then
        return { type = "summonpet", id = a2 }
    elseif cursorType == "mount" then
        return { type = "summonmount", id = a2 }
    elseif cursorType == "petaction" then
        local rawId = a2
        local name, _, icon = GetSpellInfo and GetSpellInfo(rawId)
        return {
            type = "spell",
            id = FindBaseSpellByID(rawId) or rawId,
            subType = "pet",
            icon = icon,
            name = name,
        }
    elseif cursorType == "spell" then
        local rawId, subType, baseSpellID = ResolveCursorSpell()
        if not rawId then
            return nil
        end
        local dragName, dragIcon = GetSpellNameAndIcon(rawId)
        local id = NormalizeCapturedSpellID(rawId) or rawId
        if baseSpellID then
            local baseNorm = NormalizeCapturedSpellID(baseSpellID)
            if baseNorm and IsUtilityStoreSpellID(baseNorm) then
                id = baseNorm
            end
        end
        if id == SWITCH_FLIGHT_STYLE or id == WARBAND_DISTANCE_INHIBITOR or id == TELEPORT_HOME then
            subType = "spell"
        end
        local name, icon = GetSpellNameAndIcon(id)
        return {
            type = "spell",
            id = id,
            subType = subType or "spell",
            icon = icon or dragIcon,
            name = name or dragName,
        }
    elseif cursorType == "equipmentset" then
        local id = a2
        local name, icon
        if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
            local resolved = C_EquipmentSet.GetEquipmentSetID(id)
            name, icon = C_EquipmentSet.GetEquipmentSetInfo(resolved)
        end
        return { type = "equipmentset", id = id, icon = icon, name = name }
    elseif cursorType == "macro" then
        return BuildMacroAction(ResolveCursorMacroID() or a2)
    elseif cursorType == "flyout" then
        return { type = "flyout", id = a2, icon = a3 }
    elseif cursorType == "item" then
        return { type = "item", id = a2 }
    end

    return nil
end

local function FindPetSpellBookIndexByActionID(actionID)
    if not actionID or actionID == 0 then
        return nil
    end
    local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    if not (C_SpellBook and petBank and C_SpellBook.GetSpellBookItemInfo) then
        return nil
    end
    local n = 0
    if C_SpellBook.HasPetSpells then
        n = C_SpellBook.HasPetSpells() or 0
    end
    if type(n) ~= "number" or n < 1 then
        if UnitExists and UnitExists("pet") then
            n = 120
        else
            return nil
        end
    end
    local function Norm(aid)
        if type(aid) ~= "number" or aid == 0 then
            return nil
        end
        if bit and bit.band then
            return bit.band(aid, 0xFFFFFF)
        end
        return aid % 16777216
    end
    local want = Norm(actionID) or actionID
    for i = 1, n do
        local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, petBank)
        if ok and info and type(info.actionID) == "number" then
            if info.actionID == actionID or Norm(info.actionID) == want then
                return i, info
            end
        end
    end
    return nil
end

function LPL.ActionBarCodec:BuildPetActionTableFromCursor()
    if not GetCursorInfo then
        return nil
    end

    local cursorType, a2, a3 = GetCursorInfo()
    if not cursorType then
        return nil
    end

    if cursorType == "petaction" then
        local rawId = a2
        if rawId and IsSpellKnown and IsSpellKnown(rawId, true) then
            local storeId = FindBaseSpellByID(rawId) or rawId
            local name, _, icon = GetSpellInfo and GetSpellInfo(rawId)
            return {
                type = "petspell",
                id = storeId,
                spellID = rawId,
                icon = icon,
                name = name,
                petBookActionID = nil,
                petTextureToken = nil,
                petActionNameToken = nil,
                rawTexture = nil,
            }
        end
        local _, info = FindPetSpellBookIndexByActionID(rawId)
        local icon, name
        if info then
            name = info.name
            icon = type(info.iconID) == "number" and info.iconID or nil
        end
        return {
            type = "petspell",
            id = nil,
            spellID = nil,
            icon = icon,
            name = name,
            petBookActionID = rawId,
            petTextureToken = nil,
            petActionNameToken = nil,
            rawTexture = nil,
        }
    elseif cursorType == "spell" and a3 == "pet" then
        local rawId = a2
        local name, _, icon = GetSpellInfo and GetSpellInfo(rawId)
        return {
            type = "petspell",
            id = FindBaseSpellByID(rawId) or rawId,
            spellID = rawId,
            icon = icon,
            name = name,
            petBookActionID = nil,
            petTextureToken = nil,
            petActionNameToken = nil,
            rawTexture = nil,
        }
    end

    return nil
end

local function FindMacroIndexByText(macroText)
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

function LPL.ActionBarCodec:IsSlotIgnored(draftSet, slotID, isPet)
    if not draftSet or not slotID then
        return false
    end
    if isPet then
        return draftSet.petIgnored and draftSet.petIgnored[slotID] == true
    end
    return draftSet.ignored and draftSet.ignored[slotID] == true
end

function LPL.ActionBarCodec:GetStoredAction(draftSet, slotID, isPet)
    if not draftSet or not slotID then
        return nil
    end
    if isPet then
        return draftSet.petActions and draftSet.petActions[slotID]
    end
    return draftSet.actions and draftSet.actions[slotID]
end

function LPL.ActionBarCodec:IsRangeFullyIgnored(draftSet, startID, endID, isPet)
    if not draftSet or not startID or not endID then
        return false
    end
    for slotID = startID, endID do
        if not self:IsSlotIgnored(draftSet, slotID, isPet) then
            return false
        end
    end
    return true
end

function LPL.ActionBarCodec:ResolveActionDisplay(action, ignored)
    if type(action) ~= "table" or not action.type then
        return nil, nil, nil
    end

    local icon = action.icon
    local name = action.name
    local errorText

    if action.type == "item" then
        if GetItemInfoInstant then
            name = name or select(1, GetItemInfoInstant(action.id))
            icon = icon or select(5, GetItemInfoInstant(action.id))
        end
    elseif action.type == "spell" or action.type == "petspell" then
        local spellID = action.id or action.spellID
        local spellName, spellIcon = GetSpellNameAndIcon(spellID)
        name = spellName or name
        icon = spellIcon or icon
    elseif action.type == "macro" then
        local index = FindMacroIndexByText(action.macroText)
        if not index and action.name and GetMacroIndexByName then
            local byName = GetMacroIndexByName(action.name)
            if byName and byName > 0 then
                index = byName
            end
        end
        if not index and action.id and MacroIndexExists(action.id) then
            index = action.id
        end
        if index then
            local liveName, liveIcon = ResolveMacroVisual(index)
            name = liveName or name or action.name or "Macro"
            icon = PreferResolvedIcon(liveIcon, icon)
        else
            name = name or action.name or "Macro"
            if IsQuestionMarkIcon(icon) then
                icon = PreferResolvedIcon(IconFromActionToken(FirstMacroActionToken(action.macroText)), icon)
            end
            if not ignored then
                errorText = "Macro missing"
            end
        end
    elseif action.type == "summonmount" then
        if action.id == 0xFFFFFFF then
            icon = icon or 413588
            name = name or "Random mount"
        elseif C_MountJournal and C_MountJournal.GetMountInfoByID then
            name = name or select(1, C_MountJournal.GetMountInfoByID(action.id))
            icon = icon or select(3, C_MountJournal.GetMountInfoByID(action.id))
        end
    elseif action.type == "summonpet" then
        if C_PetJournal and C_PetJournal.GetPetInfoByPetID then
            name = name or select(1, C_PetJournal.GetPetInfoByPetID(action.id))
            icon = icon or select(9, C_PetJournal.GetPetInfoByPetID(action.id))
        end
    elseif action.type == "flyout" then
        icon = icon or action.icon
        name = name or "Flyout"
    elseif action.type == "equipmentset" then
        if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
            local setID = C_EquipmentSet.GetEquipmentSetID(action.id)
            if setID then
                name, icon = C_EquipmentSet.GetEquipmentSetInfo(setID)
            elseif not ignored then
                errorText = "Equipment set missing"
            end
        end
    end

    if not icon or icon == 0 then
        icon = DEFAULT_ICON
    end

    return icon, name, errorText
end

function LPL.ActionBarCodec:BuildTooltipLines(action, slotID, isPet)
    local lines = {}
    if not action then
        lines[#lines + 1] = { text = "Empty slot", color = "title" }
        if isPet then
            lines[#lines + 1] = { text = string.format("Pet slot %d", slotID or 0), color = "gray" }
        else
            lines[#lines + 1] = { text = string.format("Slot %d", slotID or 0), color = "gray" }
        end
        return lines
    end

    local _, name = self:ResolveActionDisplay(action, false)
    lines[#lines + 1] = { text = name or action.name or action.type or "Action", color = "title" }

    if action.type == "macro" and action.macroText then
        for line in string.gmatch(action.macroText, "([^\r\n]+)") do
            lines[#lines + 1] = { text = line, color = "normal" }
        end
    end

    return lines
end

function LPL.ActionBarCodec:BuildActionSlotLine(slotID, isPet)
    if isPet then
        return { text = string.format("Pet slot %d", slotID or 0), color = "gray" }
    end
    return { text = string.format("Slot %d", slotID or 0), color = "gray" }
end

function LPL.ActionBarCodec:BuildActionTooltipExtraLines(slotID, isPet, ignored, hasPickup, errorText, includeSlot)
    local lines = {}

    if includeSlot then
        lines[#lines + 1] = self:BuildActionSlotLine(slotID, isPet)
    end
    if ignored then
        lines[#lines + 1] = { text = "Ignored on activate", color = "gold" }
    end
    if hasPickup then
        lines[#lines + 1] = { text = "Click to place picked-up action", color = "gray" }
    end
    if errorText then
        lines[#lines + 1] = { text = errorText, color = "red" }
    end

    return lines
end

function LPL.ActionBarCodec:BuildActionTooltipSpec(action, slotID, isPet, options)
    options = options or {}

    if not action or not action.type then
        local lines = self:BuildTooltipLines(action, slotID, isPet)
        for _, line in ipairs(self:BuildActionTooltipExtraLines(slotID, isPet, options.ignored, options.hasPickup, options.errorText, false)) do
            lines[#lines + 1] = line
        end
        return { lines = lines }
    end

    local extraLines = self:BuildActionTooltipExtraLines(
        slotID,
        isPet,
        options.ignored,
        options.hasPickup,
        options.errorText,
        true
    )

    local spellID = action.id or action.spellID
    if (action.type == "spell" or action.type == "petspell") and spellID then
        return {
            spellID = spellID,
            lines = extraLines,
        }
    end

    if action.type == "item" and action.id then
        return {
            hyperlink = "item:" .. action.id,
            lines = extraLines,
        }
    end

    local lines = self:BuildTooltipLines(action, slotID, isPet)
    lines[#lines + 1] = self:BuildActionSlotLine(slotID, isPet)
    for _, line in ipairs(self:BuildActionTooltipExtraLines(slotID, isPet, options.ignored, options.hasPickup, options.errorText, false)) do
        lines[#lines + 1] = line
    end

    return { lines = lines }
end
