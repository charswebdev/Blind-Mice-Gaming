--[[
  Accessibility Helper — SavedVariables defaults
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.DB = AH.DB or {}
local DB = AH.DB

local defaults = {
    masterEnable = true,
    addonTtsVolume = 100,
    addonTtsRate = 0, -- 0 = default/slowest, 1..10 each step faster (SpeakText 0..10)
    addonTtsVoiceID = -1, -- -1 = Blizzard system default voice
    chatEcho = false,
    minimapButtonEnabled = true,
    minimapButtonAngle = 220,

    tooltipsEnabled = true,
    tooltipCompare = false,
    tooltipTitanEnabled = false,

    -- Visible UI labels under the cursor (not tooltips; those stay on /ahtip).
    -- underMouseMode: "keybind" | "hover" | "off"
    underMouseMode = "off",
    underMouseEnabled = false,
    underMouseHover = false,
    cursorAnnounceEnabled = false,

    -- Chat channel TTS (all default off; master gate also off)
    chatReadEnabled = false,
    -- Player
    chatSay = false,
    chatYell = false,
    chatEmote = false,
    chatTextEmote = false,
    chatWhisper = false,
    chatWhisperOut = false,
    chatBNWhisper = false,
    chatBNWhisperOut = false,
    chatParty = false,
    chatPartyLeader = false,
    chatRaid = false,
    chatRaidLeader = false,
    chatRaidWarning = false,
    chatInstance = false,
    chatInstanceLeader = false,
    chatGuild = false,
    chatOfficer = false,
    chatGuildAnnounce = false,
    chatAchievement = false,
    chatCommunities = false,
    chatAFK = false,
    chatDND = false,
    chatVoiceText = false,
    -- Zone channels
    chatGeneral = false,
    chatTrade = false,
    chatLocalDefense = false,
    chatWorldDefense = false,
    chatServices = false,
    chatChannelOther = false,
    -- Creature / boss
    chatMonsterSay = false,
    chatMonsterYell = false,
    chatMonsterEmote = false,
    chatMonsterWhisper = false,
    chatBossEmote = false,
    chatBossWhisper = false,
    chatBossWarning = false,
    -- Combat (unique to Chat; loot/XP/rep/skill/money live on other tabs)
    chatTradeskills = false,
    chatOpening = false,
    chatPetInfo = false,
    chatMiscInfo = false,
    -- PvP
    chatBGNeutral = false,
    chatBGAlliance = false,
    chatBGHorde = false,
    -- Other
    chatSystem = false,
    chatIgnored = false,
    chatChannelNotice = false,
    chatTargetIcons = false,
    chatBNAlert = false,
    chatPetBattleCombat = false,
    chatPetBattleInfo = false,
    chatPing = false,

    -- Addon chat printers (Chat tab → Addons; default off)
    chatAddonZygor = false,
    chatAddonMountSpy = false,
    chatAddonQuestCompletist = false,
    chatAddonRareScanner = false,
    chatAddonSilverDragon = false,
    chatAddonLoremaster = false,
    chatAddonZugzug = false,

    tomtomReadEnabled = false,
    zygorReadEnabled = false,
    distanceEnabled = false,

    -- Clock facing (arrow auto: out of combat only; target: always in combat).
    facingArrowEnabled = false,
    facingTargetEnabled = false,

    locationSubzoneEnabled = false,
    -- Discovery TTS removed; chat System Messages covers "Discovered: …".
    locationDiscoveryEnabled = false,
    uiErrorsEnabled = false,
    uiErrorCooldownSec = 1.0,

    -- Loot + currency (items and non-gold currencies, including quest rewards)
    lootItemsEnabled = false,
    lootCurrencyEnabled = false,

    -- Player state. Off until the player turns a reader on.
    stateFollow = false,
    stateFly = false,
    stateMount = false,
    stateSwim = false,
    stateIndoors = false,
    stateCombat = false,
    stateDead = false,
    stateGhost = false,
    stateResurrected = false,
    stateStuck = false,
    stateResting = false,
    stateTaxi = false,
    stateVehicle = false,
    stateFalling = false,
    stateFatigue = false,
    stateBreath = false,
    stateHealthLow = false,
    stateAFK = false,
    statePvP = false,
    stateStealth = false,
    stateShapeshift = false,
    statePet = false,
    stateGroup = false,
    stateInstance = false,
    stateQueue = false,
    stateLevelUp = false,
    stateQuest = false,

    -- Quest readers
    questObjectivesEnabled = false,
    questWindowEnabled = false,
    questObjectiveProgressEnabled = false, -- auto-speak on objective progress (noisy)
    stateBagFull = false,
    stateDurability = false,
    stateMoney = false,
    stateTarget = false,
    stateTargetOfTarget = false,
    stateBNFriends = false,

    -- Progress (Phase 8)
    progressSkill = false,
    progressXP = false,
    progressRep = false,
    progressRepStanding = false,

    -- Combat LoC / debuffs (Phase 8)
    combatLocEnabled = false,
    combatAnnounceSpellNames = false,
    combatLocStun = false,
    combatLocRoot = false,
    combatLocSilence = false,
    combatLocFear = false,
    combatLocHorror = false,
    combatLocDisorient = false,
    combatLocCyclone = false,
    combatLocIncap = false,
    combatLocCharm = false,
    combatLocPacify = false,
    combatLocDisarm = false,
    combatLocBanish = false,
    combatLocLockout = false,
    combatLocOther = false,
    combatAurasEnabled = false,
    combatAuraPoison = false,
    combatAuraDisease = false,
    combatAuraCurse = false,
    combatAuraMagic = false,

    -- Combat buffs (in combat; all helpful including self)
    combatBuffsEnabled = false,
    combatBuffsApply = false,
    combatBuffsFade = false,
    combatBuffsStacks = false,
    combatBuffsDuration = false,

    -- Cast / duration bars and interrupt cue
    castsEnabled = false,
    castsPlayerEnabled = false,
    castsEnemyEnabled = false,
    interruptAlertEnabled = false,

    -- Alert delivery: tts | sound | both
    alertLocMode = "tts",
    alertDebuffMode = "tts",
    alertBuffMode = "tts",
    alertDurationMode = "tts",
    alertInterruptMode = "sound",
    alertVitalMode = "tts",
    soundPack = "raidWarning",
    -- Per-item overrides: alertItems[dbKey] = { mode = "tts"|"sound"|"both", sound = "<id>" }
    alertItems = {},
}

function DB.GetDefaults()
    return defaults
end

function DB.Merge()
    AccessibilityHelperForeverDB = AccessibilityHelperForeverDB or {}
    local sv = AccessibilityHelperForeverDB
    if sv.underMouseMode ~= "off" and sv.underMouseMode ~= "keybind" and sv.underMouseMode ~= "hover" then
        if sv.underMouseEnabled == false then
            sv.underMouseMode = "off"
        elseif sv.underMouseHover == true then
            sv.underMouseMode = "hover"
        else
            sv.underMouseMode = "keybind"
        end
    end
    for k, v in pairs(defaults) do
        if sv[k] == nil then
            sv[k] = v
        end
    end
    if type(sv.alertItems) ~= "table" then
        sv.alertItems = {}
    end
    sv.underMouseEnabled = sv.underMouseMode ~= "off"
    sv.underMouseHover = sv.underMouseMode == "hover"
    return sv
end

function DB.GetUnderMouseMode()
    local sv = DB.Get()
    local m = sv.underMouseMode
    if m == "off" or m == "keybind" or m == "hover" then
        return m
    end
    return "keybind"
end

function DB.SetUnderMouseMode(mode)
    if mode ~= "off" and mode ~= "keybind" and mode ~= "hover" then
        mode = "keybind"
    end
    local sv = DB.Get()
    sv.underMouseMode = mode
    sv.underMouseEnabled = mode ~= "off"
    sv.underMouseHover = mode == "hover"
end

function DB.Get()
    return DB.Merge()
end

function DB.IsMasterEnabled()
    local sv = DB.Get()
    return sv.masterEnable ~= false
end

function DB.GetTtsVolume()
    local sv = DB.Get()
    local v = sv.addonTtsVolume
    if type(v) ~= "number" then
        return 100
    end
    if v < 0 then return 0 end
    if v > 100 then return 100 end
    return v
end

--- Speech rate UI value (0–10). 0 = default/slowest; each step up is faster.
function DB.GetTtsRate()
    local sv = DB.Get()
    local v = sv.addonTtsRate
    if type(v) ~= "number" then
        return 0
    end
    if v < 0 then return 0 end
    if v > 10 then return 10 end
    return v
end

--- Saved voice ID, or nil when using the Blizzard system default (-1).
function DB.GetSavedTtsVoiceID()
    local sv = DB.Get()
    local v = sv.addonTtsVoiceID
    if type(v) == "number" and v >= 0 then
        return v
    end
    return nil
end

function DB.IsChatEchoEnabled()
    local sv = DB.Get()
    return sv.chatEcho == true
end

function DB.GetSoundPackID()
    local sv = DB.Get()
    local id = sv.soundPack
    if type(id) ~= "string" or id == "" then
        return "raidWarning"
    end
    return id
end
