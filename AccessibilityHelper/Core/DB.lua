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
    tooltipCompare = true,
    tooltipTitanEnabled = true,

    -- Visible UI labels under the cursor (not tooltips; those stay on /ahtip).
    -- underMouseMode: "keybind" | "hover" | "off"
    underMouseMode = "keybind",
    underMouseEnabled = true,
    underMouseHover = false,
    cursorAnnounceEnabled = true,

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

    tomtomReadEnabled = true,
    zygorReadEnabled = true,
    distanceEnabled = true,

    -- Clock facing (arrow auto: out of combat only; target: always in combat). Default on.
    facingArrowEnabled = true,
    facingTargetEnabled = true,

    locationSubzoneEnabled = true,
    -- Discovery TTS removed; chat System Messages covers "Discovered: …".
    locationDiscoveryEnabled = false,
    uiErrorsEnabled = true,
    uiErrorCooldownSec = 1.0,

    -- Loot + currency (items and non-gold currencies, including quest rewards)
    lootItemsEnabled = true,
    lootCurrencyEnabled = true,

    -- Player state (Phase 7) — all default on per plan
    stateFollow = true,
    stateFly = true,
    stateMount = true,
    stateSwim = true,
    stateIndoors = true,
    stateCombat = true,
    stateDead = true,
    stateGhost = true,
    stateResurrected = true,
    stateStuck = true,
    stateResting = true,
    stateTaxi = true,
    stateVehicle = true,
    stateFalling = true,
    stateFatigue = true,
    stateBreath = true,
    stateHealthLow = true,
    stateAFK = true,
    statePvP = true,
    stateStealth = true,
    stateShapeshift = true,
    statePet = true,
    stateGroup = true,
    stateInstance = true,
    stateQueue = true,
    stateLevelUp = true,
    stateQuest = true,

    -- Quest readers
    questObjectivesEnabled = true,
    questWindowEnabled = true,
    questObjectiveProgressEnabled = false, -- auto-speak on objective progress (noisy)
    stateBagFull = true,
    stateDurability = true,
    stateMoney = true,
    stateTarget = true,
    stateTargetOfTarget = true,
    stateBNFriends = true,

    -- Progress (Phase 8)
    progressSkill = true,
    progressXP = true,
    progressRep = true,
    progressRepStanding = true,

    -- Combat LoC / debuffs (Phase 8)
    combatLocEnabled = true,
    combatAnnounceSpellNames = true,
    combatLocStun = true,
    combatLocRoot = true,
    combatLocSilence = true,
    combatLocFear = true,
    combatLocHorror = true,
    combatLocDisorient = true,
    combatLocCyclone = true,
    combatLocIncap = true,
    combatLocCharm = true,
    combatLocPacify = true,
    combatLocDisarm = true,
    combatLocBanish = true,
    combatLocLockout = true,
    combatLocOther = true,
    combatAurasEnabled = true,
    combatAuraPoison = true,
    combatAuraDisease = true,
    combatAuraCurse = true,
    combatAuraMagic = true,

    -- Combat buffs (in combat; all helpful including self)
    combatBuffsEnabled = true,
    combatBuffsApply = true,
    combatBuffsFade = true,
    combatBuffsStacks = true,
    combatBuffsDuration = true,

    -- Cast / duration bars and interrupt cue
    castsEnabled = true,
    castsPlayerEnabled = true,
    castsEnemyEnabled = true,
    interruptAlertEnabled = true,

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
    AccessibilityHelperDB = AccessibilityHelperDB or {}
    local sv = AccessibilityHelperDB
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
