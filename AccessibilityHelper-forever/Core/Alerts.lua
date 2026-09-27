--[[
  Accessibility Helper — TTS, sound, or both per alert item
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Alerts = AH.Alerts or {}
local Alerts = AH.Alerts

Alerts.MODE_TTS = "tts"
Alerts.MODE_SOUND = "sound"
Alerts.MODE_BOTH = "both"

Alerts.MODES = {
    { id = "tts", name = "TTS only" },
    { id = "sound", name = "Sound only" },
    { id = "both", name = "Both" },
}

local CATEGORY_KEYS = {
    loc = "alertLocMode",
    debuff = "alertDebuffMode",
    buff = "alertBuffMode",
    duration = "alertDurationMode",
    interrupt = "alertInterruptMode",
    vital = "alertVitalMode",
}

local CATEGORY_DEFAULTS = {
    interrupt = "sound",
}

local function Saved()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function Items()
    local sv = Saved()
    if type(sv.alertItems) ~= "table" then
        sv.alertItems = {}
    end
    return sv.alertItems
end

local function ValidMode(mode)
    return mode == "tts" or mode == "sound" or mode == "both"
end

function Alerts.ModeChoices()
    return Alerts.MODES
end

function Alerts.ModeName(mode)
    for i = 1, #Alerts.MODES do
        if Alerts.MODES[i].id == mode then
            return Alerts.MODES[i].name
        end
    end
    return "TTS only"
end

function Alerts.GetMode(category)
    local key = CATEGORY_KEYS[category]
    local sv = Saved()
    local mode = key and sv[key]
    if not ValidMode(mode) then
        return CATEGORY_DEFAULTS[category] or "tts"
    end
    return mode
end

function Alerts.GetItemMode(itemKey, category)
    if type(itemKey) == "string" then
        local item = Items()[itemKey]
        if type(item) == "table" and ValidMode(item.mode) then
            return item.mode
        end
    end
    return Alerts.GetMode(category)
end

function Alerts.GetItemSound(itemKey)
    if type(itemKey) == "string" then
        local item = Items()[itemKey]
        if type(item) == "table" and type(item.sound) == "string" and item.sound ~= "" then
            return item.sound
        end
    end
    if AH.DB and AH.DB.GetSoundPackID then
        return AH.DB.GetSoundPackID()
    end
    return "raidWarning"
end

function Alerts.HasCustomSound(itemKey)
    if type(itemKey) ~= "string" then
        return false
    end
    local item = Items()[itemKey]
    return type(item) == "table" and type(item.sound) == "string" and item.sound ~= ""
end

function Alerts.SetItemMode(itemKey, mode)
    if type(itemKey) ~= "string" or not ValidMode(mode) then
        return
    end
    local items = Items()
    local item = items[itemKey]
    if type(item) ~= "table" then
        item = {}
        items[itemKey] = item
    end
    item.mode = mode
end

function Alerts.SetItemSound(itemKey, soundId)
    if type(itemKey) ~= "string" then
        return
    end
    local items = Items()
    local item = items[itemKey]
    if type(item) ~= "table" then
        item = {}
        items[itemKey] = item
    end
    if type(soundId) ~= "string" or soundId == "" then
        item.sound = nil
    else
        item.sound = soundId
    end
end

function Alerts.WantsSpeech(category, itemKey)
    local mode = Alerts.GetItemMode(itemKey, category)
    return mode == "tts" or mode == "both"
end

function Alerts.WantsSound(category, itemKey)
    local mode = Alerts.GetItemMode(itemKey, category)
    return mode == "sound" or mode == "both"
end

function Alerts.PlaySound(itemKey)
    local soundId = Alerts.GetItemSound(itemKey)
    if AH.Sounds and AH.Sounds.Play then
        return AH.Sounds.Play(soundId)
    end
    return false
end

-- Short lines that match in-game wording, used by the settings speaker.
local PREVIEW_LINES = {
    stateCombat = "In combat.",
    stateDead = "Dead.",
    stateGhost = "Ghost.",
    stateResurrected = "Resurrected.",
    stateHealthLow = "Health below 35%.",
    stateBreath = "Breath low.",
    stateFatigue = "Fatigue.",
    castsPlayerEnabled = "Casting Frostbolt. 2 seconds.",
    castsEnemyEnabled = "Target casting Frostbolt. 2 seconds. Can interrupt.",
    interruptAlertEnabled = "Interrupt ready.",
    combatLocStun = "Stun.",
    combatLocRoot = "Root.",
    combatLocSilence = "Silence.",
    combatLocFear = "Fear.",
    combatLocHorror = "Horror.",
    combatLocDisorient = "Disorient.",
    combatLocCyclone = "Cyclone.",
    combatLocIncap = "Incapacitate.",
    combatLocCharm = "Charm.",
    combatLocPacify = "Pacify.",
    combatLocDisarm = "Disarm.",
    combatLocBanish = "Banish.",
    combatLocLockout = "Interrupted. School lockout.",
    combatLocOther = "Loss of control.",
    combatAuraPoison = "Poison.",
    combatAuraDisease = "Disease.",
    combatAuraCurse = "Curse.",
    combatAuraMagic = "Magic.",
    combatBuffsApply = "Power Infusion. 20 seconds.",
    combatBuffsFade = "Power Infusion faded.",
    combatBuffsStacks = "Mark of the Wild. 3 stacks. 15 seconds.",
}

function Alerts.PreviewText(itemKey, fallback)
    if type(itemKey) == "string" and PREVIEW_LINES[itemKey] then
        return PREVIEW_LINES[itemKey]
    end
    if type(fallback) == "string" and fallback ~= "" then
        return fallback
    end
    return "Alert."
end

--- Preview this item the same way Announce would: TTS, sound, or both.
function Alerts.Preview(category, itemKey, sampleText)
    sampleText = Alerts.PreviewText(itemKey, sampleText)
    if Alerts.WantsSound(category, itemKey) then
        Alerts.PlaySound(itemKey)
    end
    if Alerts.WantsSpeech(category, itemKey) then
        if AH.Speech and AH.Speech.PreviewSample then
            AH.Speech.PreviewSample(sampleText)
        elseif AH.Speech and AH.Speech.Say then
            AH.Speech.Say(sampleText, AH.Speech.PRIORITY_CRITICAL)
        end
    end
end

--- Speak and/or play this item's sound.
-- @param category string  loc|debuff|buff|duration|interrupt|vital
-- @param text string|nil
-- @param priority number|nil
-- @param itemKey string|nil  settings key for this alert (e.g. combatLocStun)
function Alerts.Announce(category, text, priority, itemKey)
    if AH.DB and AH.DB.IsMasterEnabled and not AH.DB.IsMasterEnabled() then
        return
    end
    if Alerts.WantsSound(category, itemKey) then
        Alerts.PlaySound(itemKey)
    end
    if type(text) == "string" and text ~= "" and Alerts.WantsSpeech(category, itemKey) then
        if AH.Speech and AH.Speech.Say then
            AH.Speech.Say(text, priority or AH.Speech.PRIORITY_STATUS)
        else
            print("|cff66ccff[Helper]|r " .. text)
        end
    end
end
