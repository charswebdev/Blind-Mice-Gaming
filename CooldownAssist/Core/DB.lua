--[[
  Cooldown Assist — account-wide SavedVariables
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.DB = CA.DB or {}
local DB = CA.DB

local defaults = {
    masterEnable = true,
    announceInCombatOnly = true,
    minCooldownSeconds = 5,
    announceCharges = true,
    announceBuffFaded = true,
    announceReady = true,
    chatEcho = false,

    -- Discovery toggles / categories
    trackCategoryAbility = true,
    trackCategoryUtility = true,
    trackCategoryGeneral = true, -- hearthstone, teleports, warband bank, toys
    trackCategoryItem = true,
    trackCategoryBuff = true,
    -- Spellbook / toy discovery (settings General tab)
    includeSpellbookAbilities = true,
    includeSpellbookRacials = true,
    includeSpellbookGeneral = true, -- General spellbook: teleports, warband bank, etc.
    includePetAbilities = true, -- Controllable pet / minion abilities
    includeHearthstone = true,
    includeToys = true,
    toysFavoritesOnly = false, -- Toys tab: all owned toys not already in Teleport/etc.
    includeTeleportItems = true, -- bags / toys / known teleport spells
    includeTrinkets = true, -- equipped trinket slots
    includeOnUseGear = true, -- other equipped on-use gear (cloak, gloves, etc.)
    includeCombatPotions = true, -- bag consumables: potions, flasks/phials, elixirs, food, bandages
    includeHealthstones = true, -- bag healthstones
    includeSpellbook = true, -- legacy
    majorCooldownSeconds = 45,
    cooldownListFilter = "all", -- all | combat | pet | items | teleport | toys | racial | general

    ttsVolume = 100,
    ttsRate = 0, -- 0..10
    ttsVoiceID = -1, -- -1 = system default

    minimapButtonEnabled = true,
    minimapButtonAngle = 200,

    -- [key] = true means opted out; missing means tracked (default everything on)
    disabledTrackers = {},

    -- Tracking profiles (account-wide)
    profiles = {},
    nextProfileId = 1,
    activeProfileId = nil,
}

local function CopyDefaults(src)
    local t = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            local nested = {}
            for nk, nv in pairs(v) do
                nested[nk] = nv
            end
            t[k] = nested
        else
            t[k] = v
        end
    end
    return t
end

function DB.Merge()
    if type(CooldownAssistDB) ~= "table" then
        CooldownAssistDB = CopyDefaults(defaults)
        return CooldownAssistDB
    end
    for k, v in pairs(defaults) do
        if CooldownAssistDB[k] == nil then
            if type(v) == "table" then
                CooldownAssistDB[k] = CopyDefaults(v)
            else
                CooldownAssistDB[k] = v
            end
        end
    end
    if type(CooldownAssistDB.disabledTrackers) ~= "table" then
        CooldownAssistDB.disabledTrackers = {}
    end
    if type(CooldownAssistDB.profiles) ~= "table" then
        CooldownAssistDB.profiles = {}
    end
    if type(CooldownAssistDB.nextProfileId) ~= "number" then
        CooldownAssistDB.nextProfileId = 1
    end
    -- Migrate legacy includeSpellbook → abilities + racials flags.
    if CooldownAssistDB.includeSpellbookAbilities == nil or CooldownAssistDB.includeSpellbookRacials == nil then
        local legacy = CooldownAssistDB.includeSpellbook ~= false
        if CooldownAssistDB.includeSpellbookAbilities == nil then
            CooldownAssistDB.includeSpellbookAbilities = legacy
        end
        if CooldownAssistDB.includeSpellbookRacials == nil then
            CooldownAssistDB.includeSpellbookRacials = legacy
        end
    end
    -- One-time: Toys tab was empty under favorites-only default; show all owned toys.
    if CooldownAssistDB._caToysTabAllOwned == nil then
        CooldownAssistDB.toysFavoritesOnly = false
        CooldownAssistDB._caToysTabAllOwned = 1
    end
    return CooldownAssistDB
end

function DB.Get()
    if type(CooldownAssistDB) ~= "table" then
        return DB.Merge()
    end
    -- Ensure newly added defaults exist even if Init load order changes.
    for k, v in pairs(defaults) do
        if CooldownAssistDB[k] == nil then
            if type(v) == "table" then
                CooldownAssistDB[k] = CopyDefaults(v)
            else
                CooldownAssistDB[k] = v
            end
        end
    end
    return CooldownAssistDB
end

function DB.IsMasterEnabled()
    return DB.Get().masterEnable ~= false
end

function DB.GetTtsVolume()
    local v = DB.Get().ttsVolume
    if type(v) ~= "number" then
        return 100
    end
    if v < 0 then return 0 end
    if v > 100 then return 100 end
    return v
end

function DB.GetTtsRate()
    local v = DB.Get().ttsRate
    if type(v) ~= "number" then
        return 0
    end
    if v < 0 then return 0 end
    if v > 10 then return 10 end
    return v
end

function DB.GetSavedTtsVoiceID()
    local v = DB.Get().ttsVoiceID
    if type(v) == "number" and v >= 0 then
        return v
    end
    return nil
end

function DB.IsChatEchoEnabled()
    return DB.Get().chatEcho == true
end

-- Missing key = enabled (default everything on). disabledTrackers[key] == true means off.
function DB.IsTrackerEnabled(key)
    if type(key) ~= "string" or key == "" then
        return false
    end
    return not DB.IsTrackerDisabled(key)
end

function DB.SetTrackerEnabled(key, enabled)
    if type(key) ~= "string" or key == "" then
        return
    end
    local sv = DB.Get()
    if type(sv.disabledTrackers) ~= "table" then
        sv.disabledTrackers = {}
    end
    if enabled then
        sv.disabledTrackers[key] = nil
    else
        sv.disabledTrackers[key] = true
    end
end

function DB.IsTrackerDisabled(key)
    local disabled = DB.Get().disabledTrackers
    return type(disabled) == "table" and disabled[key] == true
end
