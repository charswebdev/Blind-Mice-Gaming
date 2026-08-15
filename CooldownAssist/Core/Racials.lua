--[[
  Cooldown Assist — active racial ability spell IDs
  Modern clients fold racials into the General spellbook tab (no isRacial flag /
  reliable "Racial" subtext), so we key known active racials by race file token.
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Racials = CA.Racials or {}
local Racials = CA.Racials

-- Active (non-passive) racials with cooldowns worth tracking.
-- Keys are UnitRace() english file tokens.
Racials.BY_RACE = {
    Human = { 59752 }, -- Every Man for Himself
    Orc = { 20572, 33697, 33702 }, -- Blood Fury variants
    Dwarf = { 20594 }, -- Stoneform
    NightElf = { 58984 }, -- Shadowmeld
    Scourge = { 7744, 20577 }, -- Will of the Forsaken, Cannibalism
    Tauren = { 20549 }, -- War Stomp
    Gnome = { 20589 }, -- Escape Artist
    Troll = { 26297 }, -- Berserking
    Goblin = { 69070, 69041, 69046 }, -- Rocket Jump, Rocket Barrage, Pack Hobgoblin
    BloodElf = {
        28730, 25046, 50613, 69179, 80483, 129597, 155145, 202719, 232633, -- Arcane Torrent
    },
    Draenei = {
        28880, 59542, 59543, 59544, 59545, 59547, 59548, 121093, -- Gift of the Naaru
    },
    Worgen = { 68992, 68996 }, -- Darkflight, Two Forms
    Pandaren = { 107079 }, -- Quaking Palm
    Nightborne = { 260364 }, -- Arcane Pulse
    HighmountainTauren = { 255654 }, -- Bull Rush
    VoidElf = { 256948 }, -- Spatial Rift
    LightforgedDraenei = { 255647 }, -- Light's Judgment
    ZandalariTroll = { 291944, 281954 }, -- Regeneratin', Pterrordax Swoop
    KulTiran = { 287712 }, -- Haymaker
    DarkIronDwarf = { 265221, 265225 }, -- Fireblood, Mole Machine
    Vulpera = { 312411, 312370, 312372 }, -- Bag of Tricks, Make Camp, Return to Camp
    MagharOrc = { 274738 }, -- Ancestral Call
    Mechagnome = { 312924 }, -- Hyper Organic Light Originator
    Dracthyr = { 357214, 368970, 357210, 369536 }, -- Wing Buffet, Tail Swipe, Hover?, Soar
    EarthenDwarf = { 436344 }, -- Azerite Surge
}

local spellSet = {}
local raceSpellSets = {}

local function BuildSets()
    wipe(spellSet)
    wipe(raceSpellSets)
    for raceFile, list in pairs(Racials.BY_RACE) do
        local set = {}
        for i = 1, #list do
            local id = list[i]
            set[id] = true
            spellSet[id] = true
        end
        raceSpellSets[raceFile] = set
    end
end
BuildSets()

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

function Racials.PlayerRaceFile()
    if not UnitRace then
        return nil
    end
    local _, raceFile = UnitRace("player")
    return raceFile
end

function Racials.IsRacialSpellID(spellID)
    return type(spellID) == "number" and spellSet[spellID] == true
end

function Racials.IsRacialForPlayer(spellID)
    if not Racials.IsRacialSpellID(spellID) then
        return false
    end
    local raceFile = Racials.PlayerRaceFile()
    if not raceFile then
        return true
    end
    local set = raceSpellSets[raceFile]
    return set and set[spellID] == true
end

function Racials.PlayerKnowsSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end
    if IsPlayerSpell and SafeCall(IsPlayerSpell, spellID) then
        return true
    end
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        if SafeCall(C_SpellBook.IsSpellKnownOrInSpellBook, spellID) then
            return true
        end
    end
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        if SafeCall(C_SpellBook.IsSpellInSpellBook, spellID) then
            return true
        end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        if SafeCall(C_SpellBook.IsSpellKnown, spellID) then
            return true
        end
    end
    if IsSpellKnown and SafeCall(IsSpellKnown, spellID) then
        return true
    end
    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
        local slot = SafeCall(C_SpellBook.FindSpellBookSlotForSpell, spellID, true, true, false, false)
        if type(slot) == "number" and slot > 0 then
            return true
        end
    end
    return false
end

--- Spell IDs for the current character's race that they currently know.
function Racials.GetKnownSpellIDs()
    local out = {}
    local seen = {}
    local function addIfKnown(id)
        if not seen[id] and Racials.PlayerKnowsSpell(id) then
            seen[id] = true
            out[#out + 1] = id
        end
    end

    local raceFile = Racials.PlayerRaceFile()
    local list = raceFile and Racials.BY_RACE[raceFile]
    if type(list) == "table" then
        for i = 1, #list do
            addIfKnown(list[i])
        end
    end

    -- Always also probe all curated IDs (covers renamed race tokens / shared variants).
    if #out == 0 or type(list) ~= "table" then
        for _, ids in pairs(Racials.BY_RACE) do
            for i = 1, #ids do
                addIfKnown(ids[i])
            end
        end
    end
    return out
end
