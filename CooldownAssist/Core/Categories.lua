--[[
  Cooldown Assist — tracker categories + Cooldowns-tab groups
  Combat is derived from the player's spellbook skill lines (spec/class),
  not from "anything on an action bar".
  Groups: Combat / Pet / Racial / Teleport / Toys / General / Utility
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Categories = CA.Categories or {}
local Categories = CA.Categories

Categories.ABILITY = "ability"
Categories.UTILITY = "utility"
Categories.GENERAL = "general"
Categories.ITEM = "item"
Categories.BUFF = "buff"

Categories.LABELS = {
    ability = "Ability",
    utility = "Utility",
    general = "General",
    item = "Item",
    buff = "Buff",
}

-- Display order for Cooldowns tab section headers.
Categories.GROUP_ORDER = {
    { id = "combat", label = "Combat" },
    { id = "items", label = "Items" },
    { id = "pet", label = "Pet" },
    { id = "racial", label = "Racial" },
    { id = "teleport", label = "Teleport" },
    { id = "toys", label = "Toys" },
    { id = "general", label = "General" },
    { id = "utility", label = "Utility" },
    { id = "other", label = "Other" },
}

Categories.GROUP_LABELS = {}
for i = 1, #Categories.GROUP_ORDER do
    local g = Categories.GROUP_ORDER[i]
    Categories.GROUP_LABELS[g.id] = g.label
end

-- [spellID] = { lineKind, lineName, specID, harmful, helpful, autoAttack }
local spellBookMap = {}
local mapBuilt = false

local function SV()
    return CA.DB and CA.DB.Get and CA.DB.Get() or {}
end

local function SafeCall(fn, ...)
    if CA.Compat and CA.Compat.SafeCall then
        return CA.Compat.SafeCall(fn, ...)
    end
    if not fn then
        return
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        return
    end
    return unpack(results, 2, #results)
end

function Categories.Label(cat)
    return Categories.LABELS[cat] or "Ability"
end

function Categories.GroupLabel(groupId)
    return Categories.GROUP_LABELS[groupId] or "Other"
end

function Categories.IsEnabled(cat)
    local sv = SV()
    if cat == Categories.UTILITY then
        return sv.trackCategoryUtility ~= false
    end
    if cat == Categories.GENERAL then
        return sv.trackCategoryGeneral ~= false
    end
    if cat == Categories.ITEM then
        return sv.trackCategoryItem ~= false
    end
    if cat == Categories.BUFF then
        return sv.trackCategoryBuff ~= false
    end
    return sv.trackCategoryAbility ~= false
end

function Categories.IsRacialSkillLineName(name)
    return type(name) == "string" and name:lower():find("racial", 1, true) ~= nil
end

--- Spellbook subtext like "Racial" / "Racial Passive" (racials now live under General).
function Categories.IsRacialSubName(subName)
    return type(subName) == "string" and subName:lower():find("racial", 1, true) ~= nil
end

function Categories.EffectiveLineKind(lineKind, lineName, subName)
    if lineKind == "racial"
        or Categories.IsRacialSkillLineName(lineName)
        or Categories.IsRacialSubName(subName)
    then
        return "racial"
    end
    return lineKind
end

function Categories.IsGeneralSkillLineName(name)
    if type(name) ~= "string" then
        return false
    end
    local lower = name:lower()
    if lower:find("general", 1, true)
        or lower:find("teleport", 1, true)
        or lower:find("portal", 1, true)
        or lower:find("skyriding", 1, true)
        or lower:find("dragonriding", 1, true)
        or lower:find("riding", 1, true)
        or lower:find("mount", 1, true)
        or lower:find("covenant", 1, true)
        or lower:find("kyrian", 1, true)
        or lower:find("venthyr", 1, true)
        or lower:find("night fae", 1, true)
        or lower:find("necrolord", 1, true)
    then
        return true
    end
    return false
end

function Categories.IsProfessionSkillLineName(name)
    if type(name) ~= "string" then
        return false
    end
    local lower = name:lower()
    return lower:find("profession", 1, true) ~= nil
        or lower:find("cooking", 1, true)
        or lower:find("fishing", 1, true)
        or lower:find("archaeology", 1, true)
        or lower:find("first aid", 1, true)
        or lower:find("crafting", 1, true)
end

--- Class-page utilities that are not combat cooldowns (name fallback only).
function Categories.IsNonCombatUtilityName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local lower = name:lower()
    if lower:find("flight style", 1, true)
        or lower:find("switch flight", 1, true)
        or lower:find("skyriding", 1, true)
        or lower:find("steady flight", 1, true)
        or lower:find("dragonriding", 1, true)
        or lower:find("whirling surge", 1, true)
        or lower:find("aerial halt", 1, true)
        or lower:find("mount special", 1, true)
        or lower == "dismount"
        or lower == "attack"
        or lower == "auto attack"
        or lower:find("conjure refreshment", 1, true)
        or lower:find("conjure food", 1, true)
        or lower:find("conjure water", 1, true)
        or lower:find("ritual of refreshment", 1, true)
        or lower:find("create soulwell", 1, true)
        or lower:find("create healthstone", 1, true)
        or (lower:find("soulstone", 1, true) and lower:find("create", 1, true))
        or lower:find("basic campfire", 1, true)
        or lower:find("cooking fire", 1, true)
        or lower:find("mailbox", 1, true)
        or lower:find("transmog", 1, true)
        or lower:find("find minerals", 1, true)
        or lower:find("find herbs", 1, true)
        or lower:find("find fish", 1, true)
        or (lower:find("fishing", 1, true) and not lower:find("net", 1, true))
        or lower:find("survey", 1, true)
        or lower:find("crafting order", 1, true)
    then
        return true
    end
    return false
end

function Categories.IsTeleportName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    if Categories.IsHearthstoneName(name) then
        return false
    end
    local lower = name:lower()
    if lower:find("teleport", 1, true)
        or lower:find("portal", 1, true)
        or lower:find("gateway", 1, true)
        or lower:find("wormhole", 1, true)
        or lower:find("dimensional", 1, true)
        or lower:find("ultrasafe transporter", 1, true)
        or lower:find("town portal", 1, true)
        or lower:find("path of the", 1, true)
        or lower:find("death gate", 1, true)
        or lower:find("zen pilgrimage", 1, true)
        or lower:find("astral recall", 1, true)
        or lower:find("dreamwalk", 1, true)
        or lower:find("mole machine", 1, true)
        or lower:find("ancient waygate", 1, true)
        or lower:find("homestead", 1, true)
        or lower:find("admirals compass", 1, true)
        or lower:find("admiral's compass", 1, true)
        or (lower:find("kirin tor", 1, true) and (
            lower:find("ring", 1, true)
            or lower:find("band", 1, true)
            or lower:find("signet", 1, true)
            or lower:find("loop", 1, true)
            or lower:find("beacon", 1, true)
        ))
        or lower:find("direbrew", 1, true)
        or lower:find("wrap gate", 1, true)
        or lower:find("recall beacon", 1, true)
        or lower:find("lightveil", 1, true)
        or lower:find("nature's beacon", 1, true)
        or lower:find("natures beacon", 1, true)
        or (lower:find("beacon", 1, true) and (lower:find("recall", 1, true) or lower:find("nature", 1, true) or lower:find("telemancy", 1, true) or lower:find("kirin tor", 1, true) or lower:find("sunreaver", 1, true)))
        or lower:find("dimensional ripper", 1, true)
        or lower:find("transporter:", 1, true)
        or lower:find("wyrmhole", 1, true)
        or lower:find("ruby slippers", 1, true)
        or lower:find("scarlet slippers", 1, true)
        or lower:find("time-lost artifact", 1, true)
        or lower:find("lodestone", 1, true)
        or lower:find("telemancy", 1, true)
        or lower:find("unstable portal", 1, true)
        or lower:find("innkeeper's daughter", 1, true)
        or lower:find("innkeepers daughter", 1, true)
        or lower:find("ethereal portal", 1, true)
        or lower:find("dark portal", 1, true)
        or lower:find("tome of town portal", 1, true)
        or lower:find("scroll of recall", 1, true)
        or lower:find("scroll of town portal", 1, true)
        or lower:find("seeking crystal", 1, true)
        or lower:find("potion of deepholm", 1, true)
        or lower:find("silas' stone", 1, true)
        or lower:find("silas's stone", 1, true)
    then
        return true
    end
    return false
end

function Categories.IsHearthstoneName(name)
    if type(name) ~= "string" then
        return false
    end
    local lower = name:lower()
    return lower:find("hearthstone", 1, true) ~= nil
        or lower:find("hearth stone", 1, true) ~= nil
        or lower == "hearth"
end

function Categories.IsBankName(name)
    if type(name) ~= "string" then
        return false
    end
    local lower = name:lower()
    if lower:find("warband", 1, true) then
        return true
    end
    if lower:find("bank", 1, true) and (lower:find("account", 1, true) or lower:find("guild", 1, true) or lower:find("warband", 1, true)) then
        return true
    end
    if lower:find("reagent bank", 1, true) then
        return true
    end
    return false
end

local function PlayerBank()
    if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player ~= nil then
        return Enum.SpellBookSpellBank.Player
    end
    return 0
end

local function SpellTypeEnum()
    if Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell ~= nil then
        return Enum.SpellBookItemType.Spell
    end
    return 1
end

local function FlyoutTypeEnum()
    if Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout ~= nil then
        return Enum.SpellBookItemType.Flyout
    end
    return 4
end

local function NormalizeSpellID(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end
    if C_Spell and C_Spell.GetBaseSpell then
        local base = SafeCall(C_Spell.GetBaseSpell, spellID)
        if type(base) == "number" and base > 0 then
            return base
        end
    end
    if C_SpellBook and C_SpellBook.FindBaseSpellByID then
        local base = SafeCall(C_SpellBook.FindBaseSpellByID, spellID)
        if type(base) == "number" and base > 0 then
            return base
        end
    end
    return spellID
end

local function IsSpellHarmful(spellID)
    if C_Spell and C_Spell.IsSpellHarmful then
        return SafeCall(C_Spell.IsSpellHarmful, spellID) and true or false
    end
    if IsHarmfulSpell then
        return SafeCall(IsHarmfulSpell, spellID) and true or false
    end
    return false
end

local function IsSpellHelpful(spellID)
    if C_Spell and C_Spell.IsSpellHelpful then
        return SafeCall(C_Spell.IsSpellHelpful, spellID) and true or false
    end
    if IsHelpfulSpell then
        return SafeCall(IsHelpfulSpell, spellID) and true or false
    end
    return false
end

function Categories.IsPassiveSpell(spellID)
    spellID = NormalizeSpellID(spellID)
    if not spellID then
        return false
    end
    if C_Spell and C_Spell.IsSpellPassive then
        if SafeCall(C_Spell.IsSpellPassive, spellID) then
            return true
        end
    end
    if IsPassiveSpell then
        -- Classic-style global; some clients still expose it.
        if SafeCall(IsPassiveSpell, spellID) then
            return true
        end
    end
    local meta = spellBookMap[spellID]
    if meta and meta.passive then
        return true
    end
    return false
end

--- Classify a spellbook tab: spec | class | racial | general | profession | guild | other
function Categories.ClassifySkillLineInfo(skillLineInfo)
    if type(skillLineInfo) ~= "table" then
        return "other", nil
    end
    local name = skillLineInfo.name
    if skillLineInfo.isRacial == true or Categories.IsRacialSkillLineName(name) then
        return "racial", name
    end
    if skillLineInfo.isTradeSkill == true or Categories.IsProfessionSkillLineName(name) then
        return "profession", name
    end
    if skillLineInfo.isGuild == true or (type(name) == "string" and name:lower():find("guild", 1, true)) then
        return "guild", name
    end
    if Categories.IsGeneralSkillLineName(name) then
        return "general", name
    end
    local specID = skillLineInfo.specID
    if type(specID) == "number" and specID > 0 then
        return "spec", name
    end
    -- Remaining class pages (no specID) — mixed combat + utility.
    return "class", name
end

local function StoreMapEntry(spellID, meta)
    spellID = NormalizeSpellID(spellID)
    if not spellID then
        return
    end
    local prev = spellBookMap[spellID]
    -- Prefer the strongest combat signal if a spell appears on multiple lines.
    -- Racial beats general (same tab in modern clients); class/spec still win for combat.
    local rank = { other = 0, guild = 1, profession = 2, general = 3, racial = 5, class = 6, spec = 7 }
    if prev and (rank[prev.lineKind] or 0) >= (rank[meta.lineKind] or 0) then
        return
    end
    spellBookMap[spellID] = meta
end

local function SpellBookSubName(slot, bank, info)
    if type(info) == "table" and type(info.subName) == "string" and info.subName ~= "" then
        return info.subName
    end
    if C_SpellBook and C_SpellBook.GetSpellBookItemName then
        local _, sub = SafeCall(C_SpellBook.GetSpellBookItemName, slot, bank)
        if type(sub) == "string" and sub ~= "" then
            return sub
        end
    end
    return nil
end

local function MetaForSlot(lineKind, lineName, specID, slot, bank)
    local harmful = false
    local helpful = false
    local autoAttack = false
    local passive = false
    if C_SpellBook and C_SpellBook.IsSpellBookItemHarmful then
        harmful = SafeCall(C_SpellBook.IsSpellBookItemHarmful, slot, bank) and true or false
    end
    if C_SpellBook and C_SpellBook.IsSpellBookItemHelpful then
        helpful = SafeCall(C_SpellBook.IsSpellBookItemHelpful, slot, bank) and true or false
    end
    if C_SpellBook and C_SpellBook.IsSpellBookItemPassive then
        passive = SafeCall(C_SpellBook.IsSpellBookItemPassive, slot, bank) and true or false
    end
    if C_SpellBook and C_SpellBook.IsAutoAttackSpellBookItem then
        autoAttack = SafeCall(C_SpellBook.IsAutoAttackSpellBookItem, slot, bank) and true or false
    end
    if C_SpellBook and C_SpellBook.IsRangedAutoAttackSpellBookItem then
        autoAttack = autoAttack or (SafeCall(C_SpellBook.IsRangedAutoAttackSpellBookItem, slot, bank) and true or false)
    end
    return {
        lineKind = lineKind,
        lineName = lineName,
        specID = specID,
        harmful = harmful,
        helpful = helpful,
        autoAttack = autoAttack,
        passive = passive,
    }
end

--- Rebuild spellID → spellbook tab metadata. Call on login / spec change / rescan.
function Categories.RebuildSpellBookMap()
    wipe(spellBookMap)
    mapBuilt = false
    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo) then
        mapBuilt = true
        return
    end

    local bank = PlayerBank()
    local spellType = SpellTypeEnum()
    local flyoutType = FlyoutTypeEnum()
    local numLines = SafeCall(C_SpellBook.GetNumSpellBookSkillLines) or 0

    for i = 1, numLines do
        local skillLineInfo = SafeCall(C_SpellBook.GetSpellBookSkillLineInfo, i)
        if type(skillLineInfo) == "table" then
            local lineKind, lineName = Categories.ClassifySkillLineInfo(skillLineInfo)
            local specID = skillLineInfo.specID
            local offset = skillLineInfo.itemIndexOffset or 0
            local numSlots = skillLineInfo.numSpellBookItems or 0
            for j = offset + 1, offset + numSlots do
                local info = SafeCall(C_SpellBook.GetSpellBookItemInfo, j, bank)
                if type(info) == "table" and not info.isOffSpec and not info.isPassive then
                    local subName = SpellBookSubName(j, bank, info)
                    local sidHint = info.spellID or info.actionID
                    local effKind = Categories.EffectiveLineKind(lineKind, lineName, subName)
                    if effKind ~= "racial"
                        and type(sidHint) == "number"
                        and CA.Racials and CA.Racials.IsRacialSpellID
                        and CA.Racials.IsRacialSpellID(sidHint)
                    then
                        effKind = "racial"
                    end
                    local effName = (effKind == "racial") and "Racial" or lineName
                    local meta = MetaForSlot(effKind, effName, specID, j, bank)
                    meta.lineKind = effKind
                    meta.lineName = effName
                    if meta.passive then
                        -- Skip passives entirely (not tracked, not Combat).
                    elseif info.itemType == spellType then
                        local sid = info.spellID or info.actionID
                        if type(sid) == "number" and not Categories.IsPassiveSpell(sid) then
                            if not meta.harmful and not meta.helpful then
                                meta.harmful = IsSpellHarmful(sid)
                                meta.helpful = IsSpellHelpful(sid)
                            end
                            StoreMapEntry(sid, meta)
                        end
                    elseif info.itemType == flyoutType and type(info.actionID) == "number" and GetFlyoutInfo and GetFlyoutSlotInfo then
                        local _, _, numFly = SafeCall(GetFlyoutInfo, info.actionID)
                        if type(numFly) == "number" then
                            for k = 1, numFly do
                                local spellID, _, isKnown = SafeCall(GetFlyoutSlotInfo, info.actionID, k)
                                if isKnown and type(spellID) == "number" and not Categories.IsPassiveSpell(spellID) then
                                    local flyMeta = {
                                        lineKind = effKind,
                                        lineName = effName,
                                        specID = specID,
                                        harmful = IsSpellHarmful(spellID),
                                        helpful = IsSpellHelpful(spellID),
                                        autoAttack = false,
                                        passive = false,
                                    }
                                    StoreMapEntry(spellID, flyMeta)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    mapBuilt = true
end

function Categories.EnsureSpellBookMap()
    if not mapBuilt then
        Categories.RebuildSpellBookMap()
    end
end

function Categories.LookupSpellBook(spellID)
    spellID = NormalizeSpellID(spellID)
    if not spellID then
        return nil
    end
    Categories.EnsureSpellBookMap()
    local hit = spellBookMap[spellID]
    if hit then
        return hit
    end

    -- Live fallback for spells added after the last rebuild.
    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell and C_SpellBook.GetSpellBookItemSkillLineIndex then
        local slot, bank = SafeCall(C_SpellBook.FindSpellBookSlotForSpell, spellID, true, true, false, false)
        if type(slot) == "number" then
            bank = bank or PlayerBank()
            local lineIndex = SafeCall(C_SpellBook.GetSpellBookItemSkillLineIndex, slot, bank)
            if type(lineIndex) == "number" then
                local skillLineInfo = SafeCall(C_SpellBook.GetSpellBookSkillLineInfo, lineIndex)
                local lineKind, lineName = Categories.ClassifySkillLineInfo(skillLineInfo)
                local info = SafeCall(C_SpellBook.GetSpellBookItemInfo, slot, bank)
                local subName = SpellBookSubName(slot, bank, info)
                lineKind = Categories.EffectiveLineKind(lineKind, lineName, subName)
                if lineKind == "racial" then
                    lineName = "Racial"
                end
                if C_SpellBook.IsSpellBookItemPassive and SafeCall(C_SpellBook.IsSpellBookItemPassive, slot, bank) then
                    return nil
                end
                if Categories.IsPassiveSpell(spellID) then
                    return nil
                end
                local meta = MetaForSlot(lineKind, lineName, skillLineInfo and skillLineInfo.specID, slot, bank)
                meta.lineKind = lineKind
                meta.lineName = lineName
                if meta.passive then
                    return nil
                end
                if not meta.harmful and not meta.helpful then
                    meta.harmful = IsSpellHarmful(spellID)
                    meta.helpful = IsSpellHelpful(spellID)
                end
                StoreMapEntry(spellID, meta)
                return spellBookMap[spellID]
            end
        end
    end
    return nil
end

--- True when this spell belongs on the Combat tab.
-- Combat = every non-passive spell the player has on their Class / specialization
-- spellbook tabs (not General, Racial, Skyriding, professions, etc.).
function Categories.IsCombatSpell(spellID, spellName, skillLineName)
    if Categories.IsPassiveSpell(spellID) then
        return false
    end
    local meta = Categories.LookupSpellBook(spellID)
    if not meta then
        -- Not in the class spellbook → do not put in Combat.
        return false
    end
    if meta.passive or meta.autoAttack then
        return false
    end
    -- Class tab + specialization tabs only.
    return meta.lineKind == "class" or meta.lineKind == "spec"
end

--- Classify announce category (ability/utility/general/...).
function Categories.ClassifySpell(spellID, source, skillLineName, spellName)
    if type(source) == "string" then
        if source:find("^toy:") or source:find("^hearth:") then
            return Categories.GENERAL
        end
        if source:find("^general:") or source:find("^teleport:") then
            return Categories.GENERAL
        end
        if source:find("^pet:") then
            return Categories.UTILITY
        end
        if source:find("^stance:") then
            return Categories.UTILITY
        end
        if source:find("^racial:") then
            return Categories.UTILITY
        end
        if source:find("^item:") then
            return Categories.ITEM
        end
    end

    if Categories.IsHearthstoneName(spellName) or Categories.IsTeleportName(spellName) or Categories.IsBankName(spellName) then
        return Categories.GENERAL
    end
    if Categories.IsRacialSkillLineName(skillLineName) or (type(source) == "string" and source:find("^racial:")) then
        return Categories.UTILITY
    end

    local meta = Categories.LookupSpellBook(spellID)
    if meta then
        if meta.lineKind == "racial" then
            return Categories.UTILITY
        end
        if meta.lineKind == "general" then
            return Categories.GENERAL
        end
        if meta.lineKind == "profession" or meta.lineKind == "guild" then
            return Categories.UTILITY
        end
    elseif Categories.IsGeneralSkillLineName(skillLineName) then
        return Categories.GENERAL
    elseif Categories.IsProfessionSkillLineName(skillLineName) then
        return Categories.UTILITY
    end

    if Categories.IsCombatSpell(spellID, spellName, skillLineName or (meta and meta.lineName)) then
        return Categories.ABILITY
    end
    return Categories.UTILITY
end

--- UI group for Cooldowns tab section headers.
function Categories.ResolveGroup(info)
    info = info or {}
    local name = info.name
    local key = tostring(info.key or "")
    local kind = info.kind
    local category = info.category
    local spellID = info.spellID
    local itemID = info.itemID
    local skillLineName = info.skillLineName
    local lineKind = info.lineKind

    -- Toys first so toy-box entries are not swallowed by category=general.
    if kind == "toy" or key:find("^toy:") then
        -- Teleport / hearth toys still belong on the Teleport tab.
        if Categories.IsHearthstoneName(name)
            or Categories.IsTeleportName(name)
            or (CA.Teleports and CA.Teleports.IsTeleportItemID and CA.Teleports.IsTeleportItemID(itemID))
        then
            return "teleport"
        end
        return "toys"
    end
    -- Teleport gear/toys/spells. Racial teleports (e.g. Mole Machine) stay here.
    if kind == "hearth"
        or kind == "teleport"
        or key:find("^hearth:")
        or key:find("^teleport:")
        or Categories.IsHearthstoneName(name)
        or Categories.IsTeleportName(name)
        or (CA.Teleports and CA.Teleports.IsTeleportSpellID and CA.Teleports.IsTeleportSpellID(spellID))
        or (CA.Teleports and CA.Teleports.IsTeleportItemID and CA.Teleports.IsTeleportItemID(itemID))
    then
        return "teleport"
    end

    -- Equipped trinkets / on-use gear / bag consumables.
    if kind == "trinket"
        or kind == "gear"
        or kind == "consumable"
        or key:find("^trinket:")
        or key:find("^gear:")
        or key:find("^consumable:")
    then
        return "items"
    end

    -- Pet / minion abilities (action bar + pet spellbook) get their own tab.
    if kind == "pet" or lineKind == "pet" or key:find("^pet:") then
        return "pet"
    end
    local sources = info.sources
    if type(sources) == "table" then
        for src in pairs(sources) do
            if type(src) == "string" and src:find("^pet:") then
                return "pet"
            end
        end
    end

    local meta = nil
    if type(spellID) == "number" then
        meta = Categories.LookupSpellBook(spellID)
        if meta then
            lineKind = lineKind or meta.lineKind
            skillLineName = skillLineName or meta.lineName
        end
    end

    -- Racial before general: active racials sit on the General spellbook page.
    if lineKind == "racial"
        or kind == "racial"
        or key:find("^racial:")
        or Categories.IsRacialSkillLineName(skillLineName)
        or (CA.Racials and CA.Racials.IsRacialSpellID and CA.Racials.IsRacialSpellID(spellID))
    then
        return "racial"
    end
    if type(sources) == "table" then
        for src in pairs(sources) do
            if type(src) == "string" and src:find("^racial:") then
                return "racial"
            end
        end
    end
    if Categories.IsBankName(name) then
        return "general"
    end
    -- Skyriding / conjure / profession utilities that live on class pages.
    if Categories.IsNonCombatUtilityName(name) then
        return "general"
    end
    if lineKind == "general" or Categories.IsGeneralSkillLineName(skillLineName) or category == "general" or key:find("^general:") then
        return "general"
    end
    if type(sources) == "table" then
        for src in pairs(sources) do
            if type(src) == "string" and src:find("^general:") then
                return "general"
            end
        end
    end

    -- Combat only when spellbook + harmful/helpful rules say so.
    if type(spellID) == "number" and Categories.IsCombatSpell(spellID, name, skillLineName) then
        return "combat"
    end

    if category == "ability" and type(spellID) ~= "number" then
        return "combat"
    end

    if lineKind == "profession" or lineKind == "guild" or lineKind == "class" or category == "utility" then
        return "utility"
    end
    return "utility"
end

function Categories.GroupEntries(list)
    local buckets = {}
    for i = 1, #Categories.GROUP_ORDER do
        buckets[Categories.GROUP_ORDER[i].id] = {}
    end
    for i = 1, #list do
        local entry = list[i]
        local groupId = entry.group or Categories.ResolveGroup(entry)
        entry.group = groupId
        entry.groupLabel = Categories.GroupLabel(groupId)
        if not buckets[groupId] then
            buckets[groupId] = {}
        end
        buckets[groupId][#buckets[groupId] + 1] = entry
    end
    for _, bucket in pairs(buckets) do
        table.sort(bucket, function(a, b)
            return tostring(a.name):lower() < tostring(b.name):lower()
        end)
    end
    return buckets
end
