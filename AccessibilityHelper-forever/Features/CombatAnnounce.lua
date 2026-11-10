--[[
  Accessibility Helper — combat lines
  Fight, health, power, attacks, control, and auras.
  The words are spoken from the game. They are not printed.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

local live = false
local seedGen = 0
local healthLow = false
local powerLow = false
local targeting = {}
local secondaryState = {}
local knownBuffs = {}
local knownDebuffs = {}
local activeControl = {}
local casting = {}

local POWER_WORD = {
    MANA = "Mana",
    RAGE = "Rage",
    FOCUS = "Focus",
    ENERGY = "Energy",
    RUNIC_POWER = "Runic power",
    LUNAR_POWER = "Astral power",
    MAELSTROM = "Maelstrom",
    INSANITY = "Insanity",
    FURY = "Fury",
    PAIN = "Pain",
}

local SECONDARY = {
    { name = "Combo points", token = "COMBO_POINTS", id = 4 },
    { name = "Holy power", token = "HOLY_POWER", id = 9 },
    { name = "Soul shards", token = "SOUL_SHARDS", id = 7 },
    { name = "Chi", token = "CHI", id = 12 },
    { name = "Arcane charges", token = "ARCANE_CHARGES", id = 16 },
    { name = "Essence", token = "ESSENCE", id = 19 },
}

local LOC_LINE = {
    STUN = { "combatStun", "Stunned." },
    STUN_MECHANIC = { "combatStun", "Stunned." },
    ROOT = { "combatRoot", "Rooted." },
    SILENCE = { "combatSilence", "Silenced." },
    POSSESS = { "combatPossessed", "Possessed." },
    POLYMORPH = { "combatPolymorph", "Polymorphed." },
    FEAR = { "combatCrowd", "Crowd control." },
    HORROR = { "combatCrowd", "Crowd control." },
    DISORIENT = { "combatCrowd", "Crowd control." },
    CONFUSE = { "combatCrowd", "Crowd control." },
    CYCLONE = { "combatCrowd", "Crowd control." },
    INCAPACITATE = { "combatCrowd", "Crowd control." },
    SLEEP = { "combatCrowd", "Crowd control." },
    SNOOZE = { "combatCrowd", "Crowd control." },
    CHARM = { "combatCrowd", "Crowd control." },
    BANISH = { "combatCrowd", "Crowd control." },
    SHACKLE_UNDEAD = { "combatCrowd", "Crowd control." },
}

local function DB()
    if AH.DB and AH.DB.Get then
        return AH.DB.Get()
    end
    return {}
end

local function Want(key)
    local sv = DB()
    if sv.combatReadEnabled ~= true then
        return false
    end
    return sv[key] == true
end

local function Say(msg)
    if not live or type(msg) ~= "string" or msg == "" then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_INFO, { noEcho = true })
    end
end

local function Plain(v)
    if AH.Compat and AH.Compat.UsableString then
        return AH.Compat.UsableString(v)
    end
    if type(v) == "string" and v ~= "" then
        return v
    end
    return nil
end

local function Num(v)
    if AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(v) then
        return v
    end
    return nil
end

local function PlainBool(v)
    if AH.Compat and AH.Compat.IsSecretValue and AH.Compat.IsSecretValue(v) then
        return nil
    end
    if v == true then
        return true
    end
    if v == false then
        return false
    end
    return nil
end

local function Bool(fn, a, b)
    if AH.Compat and AH.Compat.SafeBool then
        return AH.Compat.SafeBool(fn, a, b)
    end
    return false
end

local function Same(a, b)
    if AH.Compat and AH.Compat.SameUnit then
        return AH.Compat.SameUnit(a, b)
    end
    return false
end

local function Guid(unit)
    if not UnitGUID then
        return nil
    end
    local ok, g = pcall(UnitGUID, unit)
    if ok then
        return Plain(g)
    end
    return nil
end

local function UnitNamePlain(unit)
    if not UnitName then
        return nil
    end
    local ok, name = pcall(UnitName, unit)
    if ok then
        return Plain(name)
    end
    return nil
end

local function Percent(cur, maxv)
    cur = Num(cur)
    maxv = Num(maxv)
    if not cur or not maxv or maxv <= 0 then
        return nil
    end
    return math.floor((cur * 100 / maxv) + 0.5)
end

local function WatchedUnits()
    local units = { "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }
    for i = 1, 30 do
        units[#units + 1] = "nameplate" .. i
    end
    return units
end

local function EnemyTargetsYou(unit)
    if Same(unit, "player") then
        return false
    end
    if not Bool(UnitCanAttack, "player", unit) then
        return false
    end
    return Same(unit .. "target", "player")
end

local function CheckEnemyTargets()
    local seen = {}
    local units = WatchedUnits()
    for i = 1, #units do
        local unit = units[i]
        if EnemyTargetsYou(unit) then
            local guid = Guid(unit)
            local name = UnitNamePlain(unit)
            if guid and name then
                seen[guid] = name
                if not targeting[guid] then
                    targeting[guid] = true
                    if Want("combatEnemyTarget") then
                        Say(name .. " is targeting you.")
                    end
                end
            end
        end
    end
    for guid in pairs(targeting) do
        if not seen[guid] then
            targeting[guid] = nil
        end
    end
end

local function AnnounceYourTarget()
    if not Want("combatYourTarget") then
        return
    end
    local name = UnitNamePlain("target")
    if name then
        Say("Target. " .. name .. ".")
    end
end

local function CheckHealth()
    local cur, maxv
    if UnitHealth then
        local ok, v = pcall(UnitHealth, "player")
        if ok then
            cur = v
        end
    end
    if UnitHealthMax then
        local ok, v = pcall(UnitHealthMax, "player")
        if ok then
            maxv = v
        end
    end
    local pct = Percent(cur, maxv)
    if not pct then
        return
    end
    if pct < 35 then
        if not healthLow then
            healthLow = true
            if Want("combatHealthLow") then
                Say("Health. " .. pct .. " percent.")
            end
        end
    else
        healthLow = false
    end
end

local function PrimaryPowerWord()
    if not UnitPowerType then
        return "Power"
    end
    local token
    pcall(function()
        local _, powerToken = UnitPowerType("player")
        token = Plain(powerToken)
    end)
    if token and POWER_WORD[token] then
        return POWER_WORD[token]
    end
    return "Power"
end

local function PrimaryPowerType()
    if not UnitPowerType then
        return nil
    end
    local value
    pcall(function()
        local powerType = UnitPowerType("player")
        value = Num(powerType)
    end)
    return value
end

local function IsPlayerUnit(unit)
    if type(unit) ~= "string" then
        return false
    end
    if AH.Compat and AH.Compat.IsSecretValue and AH.Compat.IsSecretValue(unit) then
        return false
    end
    return unit == "player"
end

local function PowerPair(unit, powerId)
    local cur, maxv
    if UnitPower then
        local ok, v
        if powerId == nil then
            ok, v = pcall(UnitPower, unit)
        else
            ok, v = pcall(UnitPower, unit, powerId)
        end
        if ok then
            cur = Num(v)
        end
    end
    if UnitPowerMax then
        local ok, v
        if powerId == nil then
            ok, v = pcall(UnitPowerMax, unit)
        else
            ok, v = pcall(UnitPowerMax, unit, powerId)
        end
        if ok then
            maxv = Num(v)
        end
    end
    return cur, maxv
end

local function CheckMainPower()
    local cur, maxv = PowerPair("player", nil)
    local pct = Percent(cur, maxv)
    if not pct then
        return
    end
    if pct < 35 then
        if not powerLow then
            powerLow = true
            if Want("combatPowerLow") then
                Say(PrimaryPowerWord() .. ". " .. pct .. " percent.")
            end
        end
    else
        powerLow = false
    end
end

local function SecondaryId(row)
    if Enum and Enum.PowerType and row.token then
        local value = Enum.PowerType[row.token]
        if type(value) == "number" then
            return value
        end
    end
    return row.id
end

local function CheckSecondary()
    local primary = PrimaryPowerType()
    for i = 1, #SECONDARY do
        local row = SECONDARY[i]
        local id = SecondaryId(row)
        if not primary or id ~= primary then
            local cur, maxv = PowerPair("player", id)
            if cur and maxv and maxv > 0 then
                local state = "mid"
                if cur <= 0 then
                    state = "low"
                elseif cur >= maxv then
                    state = "full"
                end
                local prev = secondaryState[id]
                secondaryState[id] = state
                if prev and prev ~= state then
                    if state == "low" and Want("combatSecondaryLow") then
                        Say(row.name .. " low.")
                    end
                    if state == "full" and Want("combatSecondaryFull") then
                        Say(row.name .. " full.")
                    end
                end
            end
        end
    end
end

local function ReadCast(unit)
    local name
    local noInt
    if UnitCastingInfo then
        pcall(function()
            local n, _, _, _, _, _, _, interruptFlag = UnitCastingInfo(unit)
            local plain = Plain(n)
            if plain then
                name = plain
                noInt = PlainBool(interruptFlag)
            end
        end)
    end
    if not name and UnitChannelInfo then
        pcall(function()
            local n, _, _, _, _, _, interruptFlag = UnitChannelInfo(unit)
            local plain = Plain(n)
            if plain then
                name = plain
                noInt = PlainBool(interruptFlag)
            end
        end)
    end
    return name, noInt
end

local function HandleCast(unit)
    if Same(unit, "player") then
        return
    end
    if not EnemyTargetsYou(unit) then
        return
    end
    local spell, noInt = ReadCast(unit)
    local guid = Guid(unit)
    local who = UnitNamePlain(unit)
    if not spell or not guid or not who then
        return
    end
    if casting[guid] == spell then
        return
    end
    casting[guid] = spell
    if Want("combatCastAtYou") then
        Say(who .. " casting " .. spell .. ".")
    end
    if noInt == false and Want("combatInterrupt") then
        Say("Interrupt " .. spell .. ".")
    end
end

local function ClearCast(unit)
    local guid = Guid(unit)
    if guid then
        casting[guid] = nil
    end
end

local function ReadAura(unit, index, filter)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, data = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if ok and type(data) == "table" then
            local name = Plain(data.name)
            if not name then
                return nil
            end
            return name, Plain(data.dispelName)
        end
    end
    if filter == "HARMFUL" and UnitDebuff then
        local ok, name, _, _, dispelType = pcall(UnitDebuff, unit, index)
        if ok then
            name = Plain(name)
            if name then
                return name, Plain(dispelType)
            end
        end
    end
    if filter == "HELPFUL" and UnitBuff then
        local ok, name = pcall(UnitBuff, unit, index)
        if ok then
            name = Plain(name)
            if name then
                return name, nil
            end
        end
    end
    return nil
end

local function AddControl(list, seen, key, text)
    if seen[text] then
        return
    end
    seen[text] = true
    list[#list + 1] = { key = key, text = text }
end

local function ControlFromAura(name, dispel)
    local lower = string.lower(name)
    if string.find(lower, "polymorph", 1, true) then
        return "combatPolymorph", "Polymorphed."
    end
    if string.find(lower, "possess", 1, true) then
        return "combatPossessed", "Possessed."
    end
    if dispel == "Poison" then
        return "combatPoisoned", "Poisoned."
    end
    return nil
end

local function CanDispel(dispel)
    if dispel == "Magic" or dispel == "Curse" or dispel == "Disease" or dispel == "Poison" then
        return true
    end
    return false
end

local function ReadLossControls(list, seen)
    if not (C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount) then
        return
    end
    local count
    pcall(function()
        count = C_LossOfControl.GetActiveLossOfControlDataCount()
    end)
    count = Num(count)
    if not count or count < 1 then
        return
    end
    if count > 10 then
        count = 10
    end
    for i = 1, count do
        local data
        pcall(function()
            data = C_LossOfControl.GetActiveLossOfControlData(i)
        end)
        if type(data) == "table" then
            local locType = Plain(data.locType)
            if locType then
                local map = LOC_LINE[locType]
                if map then
                    AddControl(list, seen, map[1], map[2])
                else
                    AddControl(list, seen, "combatLossOther", "Loss of control.")
                end
            end
        end
    end
end

local function SyncControl(list)
    local now = {}
    for i = 1, #list do
        now[list[i].text] = list[i]
    end
    for text, item in pairs(now) do
        if not activeControl[text] then
            activeControl[text] = true
            if Want(item.key) then
                Say(item.text)
            end
        end
    end
    local gone = {}
    for text in pairs(activeControl) do
        if not now[text] then
            gone[#gone + 1] = text
        end
    end
    for i = 1, #gone do
        activeControl[gone[i]] = nil
    end
end

local function ScanAuras()
    local buffs = {}
    local debuffs = {}
    local controls = {}
    local seenControl = {}
    local i = 1
    while i <= 40 do
        local name = ReadAura("player", i, "HELPFUL")
        if not name then
            break
        end
        buffs[name] = true
        i = i + 1
    end
    i = 1
    while i <= 40 do
        local name, dispel = ReadAura("player", i, "HARMFUL")
        if not name then
            break
        end
        debuffs[name] = dispel or ""
        local key, text = ControlFromAura(name, dispel)
        if key then
            AddControl(controls, seenControl, key, text)
        end
        i = i + 1
    end
    ReadLossControls(controls, seenControl)
    if live then
        for name in pairs(buffs) do
            if not knownBuffs[name] and Want("combatBuffGain") then
                Say("Buff. " .. name .. ".")
            end
        end
        for name, dispel in pairs(debuffs) do
            if not knownDebuffs[name] then
                if Want("combatDebuffGain") then
                    Say("Debuff. " .. name .. ".")
                end
                if CanDispel(dispel) and Want("combatDispel") then
                    Say("Dispel " .. name .. ".")
                end
            end
        end
    end
    knownBuffs = buffs
    knownDebuffs = debuffs
    SyncControl(controls)
end

local function PollBars()
    CheckHealth()
    CheckMainPower()
    CheckSecondary()
    CheckEnemyTargets()
end

local function Seed()
    live = false
    seedGen = seedGen + 1
    local gen = seedGen
    healthLow = false
    powerLow = false
    targeting = {}
    secondaryState = {}
    knownBuffs = {}
    knownDebuffs = {}
    activeControl = {}
    casting = {}
    PollBars()
    ScanAuras()
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if gen ~= seedGen then
                return
            end
            PollBars()
            ScanAuras()
            live = true
        end)
    else
        live = true
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UNIT_TARGET")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
pcall(frame.RegisterEvent, frame, "UNIT_POWER_UPDATE")
pcall(frame.RegisterEvent, frame, "UNIT_POWER_FREQUENT")
pcall(frame.RegisterEvent, frame, "LOSS_OF_CONTROL_UPDATE")
pcall(frame.RegisterEvent, frame, "LOSS_OF_CONTROL_ADDED")

frame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Seed()
        return
    end
    if not live then
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        if Want("combatStarted") then
            Say("Combat started.")
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        if Want("combatStarted") then
            Say("Combat ended.")
        end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        AnnounceYourTarget()
        return
    end
    if event == "UNIT_TARGET" then
        CheckEnemyTargets()
        return
    end
    if event == "UNIT_HEALTH" then
        if IsPlayerUnit(unit) then
            CheckHealth()
        end
        return
    end
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        if IsPlayerUnit(unit) then
            CheckMainPower()
            CheckSecondary()
        end
        return
    end
    if event == "UNIT_AURA" or event == "LOSS_OF_CONTROL_UPDATE" or event == "LOSS_OF_CONTROL_ADDED" then
        if event ~= "UNIT_AURA" or IsPlayerUnit(unit) then
            ScanAuras()
        end
        return
    end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        HandleCast(unit)
        return
    end
    if event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        ClearCast(unit)
    end
end)

local elapsed = 0
frame:SetScript("OnUpdate", function(_, delta)
    if not live then
        return
    end
    elapsed = elapsed + (delta or 0)
    if elapsed < 0.5 then
        return
    end
    elapsed = 0
    CheckEnemyTargets()
end)
