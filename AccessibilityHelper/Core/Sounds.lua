--[[
  Accessibility Helper — Blizzard sound-kit packs
  Lua 5.1 only. Names follow SOUNDKIT in SharedXML; extras are tried as aliases.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Sounds = AH.Sounds or {}
local Sounds = AH.Sounds

-- Alert-useful kits from Blizzard's SOUNDKIT table. Missing names are hidden
-- on this client (Classic will not show Cata+ / Retail-only entries).
Sounds.PACKS = {
    { id = "raidWarning", name = "Raid Warning", kits = { "RAID_WARNING" }, fallback = 8959 },
    { id = "raidBossEmote", name = "Raid Boss Emote", kits = { "RAID_BOSS_EMOTE_WARNING" }, fallback = 12197 },
    { id = "raidBossWhisper", name = "Raid Boss Whisper", kits = { "UI_RAID_BOSS_WHISPER_WARNING" }, fallback = 37666 },
    { id = "readyCheck", name = "Ready Check", kits = { "READY_CHECK" }, fallback = 8960 },
    { id = "alarm1", name = "Alarm Clock 1", kits = { "ALARM_CLOCK_WARNING_1" }, fallback = 18871 },
    { id = "alarm2", name = "Alarm Clock 2", kits = { "ALARM_CLOCK_WARNING_2" }, fallback = 12867 },
    { id = "alarm3", name = "Alarm Clock 3", kits = { "ALARM_CLOCK_WARNING_3" }, fallback = 12889 },
    { id = "gmWarning", name = "GM Chat Warning", kits = { "GM_CHAT_WARNING" }, fallback = 15273 },
    { id = "tutorialPopup", name = "Tutorial Popup", kits = { "TUTORIAL_POPUP" }, fallback = 7355 },
    { id = "locStart", name = "Loss of Control", kits = { "UI_LOSS_OF_CONTROL_START" }, fallback = 34468 },
    { id = "powerAura", name = "Power Aura", kits = { "UI_POWER_AURA_GENERIC" }, fallback = 23287 },
    { id = "mapPing", name = "Map Ping", kits = { "MAP_PING", "MapPing" }, fallback = 3175 },
    { id = "whisper", name = "Whisper", kits = { "TELL_MESSAGE", "TellMessage" }, fallback = 3081 },
    { id = "bnetToast", name = "Battle.net Toast", kits = { "UI_BNET_TOAST" }, fallback = 18019 },
    { id = "playerInvite", name = "Player Invite", kits = { "IG_PLAYER_INVITE" }, fallback = 880 },
    { id = "auction", name = "Auction Open", kits = { "AUCTION_WINDOW_OPEN", "AuctionWindowOpen" }, fallback = 5274 },
    { id = "questFail", name = "Quest Failed", kits = { "IG_QUEST_LOG_ABANDON_QUEST", "igQuestFailed" }, fallback = 846 },
    { id = "questComplete", name = "Quest Complete", kits = { "UI_AUTO_QUEST_COMPLETE", "IG_QUEST_LIST_COMPLETE" }, fallback = 878 },
    { id = "questAdded", name = "Quest Added", kits = { "IG_QUEST_LIST_OPEN" }, fallback = 875 },
    { id = "worldQuest", name = "World Quest Complete", kits = { "UI_WORLDQUEST_COMPLETE" }, fallback = 73277 },
    { id = "levelUp", name = "Level Up", kits = { "LEVELUPSOUND", "LEVEL_UP" }, fallback = 888 },
    { id = "achievement", name = "Achievement Open", kits = { "ACHIEVEMENT_MENU_OPEN" }, fallback = 13832 },
    { id = "queueReady", name = "Queue Ready", kits = { "LFG_REWARDS", "UI_GROUP_FINDER_RECEIVE_APPLICATION" }, fallback = 17316 },
    { id = "lfgRole", name = "LFG Role Check", kits = { "LFG_ROLE_CHECK" }, fallback = 17317 },
    { id = "lfgDenied", name = "LFG Denied", kits = { "LFG_DENIED" }, fallback = 17341 },
    { id = "pvpEnter", name = "PvP Enter Queue", kits = { "PVP_ENTER_QUEUE", "PVPENTERQUEUE" }, fallback = 8458 },
    { id = "pvpThrough", name = "PvP Through Queue", kits = { "PVP_THROUGH_QUEUE" }, fallback = 8459 },
    { id = "pvpUpdate", name = "PvP Update", kits = { "IG_PVP_UPDATE" }, fallback = 4574 },
    { id = "bgCountdown", name = "Battleground Countdown", kits = { "UI_BATTLEGROUND_COUNTDOWN_TIMER" }, fallback = 25477 },
    { id = "bgFinished", name = "Battleground Finished", kits = { "UI_BATTLEGROUND_COUNTDOWN_FINISHED" }, fallback = 25478 },
    { id = "raidBossDead", name = "Raid Boss Defeated", kits = { "UI_RAID_BOSS_DEFEATED" }, fallback = 50111 },
    { id = "scenarioEnd", name = "Scenario Ending", kits = { "UI_SCENARIO_ENDING" }, fallback = 31754 },
    { id = "challengeRecord", name = "Challenge New Record", kits = { "UI_CHALLENGES_NEW_RECORD", "UI_70_CHALLENGE_MODE_NEW_RECORD" }, fallback = 33338 },
    { id = "epicLoot", name = "Epic Loot Toast", kits = { "UI_EPICLOOT_TOAST" }, fallback = 31578 },
    { id = "legendaryLoot", name = "Legendary Loot Toast", kits = { "UI_LEGENDARY_LOOT_TOAST" }, fallback = 63971 },
    { id = "lootCoin", name = "Loot Coin", kits = { "LOOT_WINDOW_COIN_SOUND" }, fallback = 120 },
    { id = "moneyOpen", name = "Money Frame Open", kits = { "MONEY_FRAME_OPEN" }, fallback = 891 },
    { id = "menuOpen", name = "Main Menu Open", kits = { "IG_MAINMENU_OPEN" }, fallback = 850 },
    { id = "menuOption", name = "Main Menu Option", kits = { "IG_MAINMENU_OPTION" }, fallback = 852 },
    { id = "checkboxOn", name = "Checkbox On", kits = { "IG_MAINMENU_OPTION_CHECKBOX_ON" }, fallback = 856 },
    { id = "abilityOpen", name = "Ability Open", kits = { "IG_ABILITY_OPEN" }, fallback = 834 },
    { id = "spellbookOpen", name = "Spellbook Open", kits = { "IG_SPELLBOOK_OPEN" }, fallback = 829 },
    { id = "charInfo", name = "Character Info Open", kits = { "IG_CHARACTER_INFO_OPEN" }, fallback = 839 },
    { id = "backpack", name = "Backpack Open", kits = { "IG_BACKPACK_OPEN" }, fallback = 862 },
    { id = "minimapOpen", name = "Minimap Open", kits = { "IG_MINIMAP_OPEN" }, fallback = 821 },
    { id = "creatureAggro", name = "Creature Aggro Select", kits = { "IG_CREATURE_AGGRO_SELECT" }, fallback = 873 },
    { id = "lostTarget", name = "Lost Target", kits = { "INTERFACE_SOUND_LOST_TARGET_UNIT" }, fallback = 684 },
    { id = "fishing", name = "Fishing Reel In", kits = { "FISHING_REEL_IN" }, fallback = 3407 },
    { id = "itemRepair", name = "Item Repair", kits = { "ITEM_REPAIR" }, fallback = 7994 },
    { id = "talentReady", name = "Order Hall Talent Ready", kits = { "UI_ORDERHALL_TALENT_READY_CHECK", "UI_ORDERHALL_TALENT_READY_TOAST" }, fallback = 73281 },
    { id = "recipeLearned", name = "Recipe Learned", kits = { "UI_PROFESSIONS_NEW_RECIPE_LEARNED_TOAST" }, fallback = 73919 },
    { id = "petBattle", name = "Pet Battle Start", kits = { "UI_PET_BATTLE_START" }, fallback = 31584 },
    { id = "petTrap", name = "Pet Battle Trap Ready", kits = { "UI_PET_BATTLES_TRAP_READY" }, fallback = 28814 },
    { id = "voiceJoin", name = "Voice Chat Join", kits = { "UI_VOICECHAT_JOINCHANNEL" }, fallback = 110981 },
    { id = "voiceTalk", name = "Voice Chat Talk", kits = { "UI_VOICECHAT_TALKSTART" }, fallback = 110983 },
}

local function KitNames(pack)
    if type(pack) ~= "table" then
        return {}
    end
    if type(pack.kits) == "table" then
        return pack.kits
    end
    if type(pack.kit) == "string" then
        return { pack.kit }
    end
    return {}
end

local function GetLSM()
    if not LibStub then
        return nil
    end
    local ok, lsm = pcall(LibStub, "LibSharedMedia-3.0", true)
    if ok and type(lsm) == "table" then
        return lsm
    end
    ok, lsm = pcall(LibStub, "LibSharedMedia-3.0")
    if ok and type(lsm) == "table" then
        return lsm
    end
    return nil
end

local function ListLSMKeys(lsm)
    local names = {}
    local seen = {}
    local function add(key)
        if type(key) == "string" and key ~= "" and not seen[key] then
            seen[key] = true
            names[#names + 1] = key
        end
    end
    if lsm.List then
        local ok, list = pcall(lsm.List, lsm, "sound")
        if ok and type(list) == "table" then
            for i, v in ipairs(list) do
                add(v)
            end
            for k, v in pairs(list) do
                if type(k) == "string" then
                    add(k)
                end
                if type(v) == "string" then
                    add(v)
                end
            end
        end
    end
    if lsm.HashTable then
        local ok, hash = pcall(lsm.HashTable, lsm, "sound")
        if ok and type(hash) == "table" then
            for k in pairs(hash) do
                add(k)
            end
        end
    end
    return names
end

local function LSMKeyFromID(id)
    if type(id) ~= "string" then
        return nil
    end
    if id:sub(1, 4) == "lsm:" then
        return id:sub(5)
    end
    return nil
end

local function MakeLSMSound(key, sourceId)
    return {
        id = "lsm:" .. key,
        name = key,
        lsm = key,
        source = sourceId,
        hint = "From an installed sound pack.",
    }
end

local function DisplayAddonName(folder)
    if type(folder) ~= "string" or folder == "" then
        return "Other sounds"
    end
    return folder:gsub("_", " ")
end

local function SourceFromPath(path)
    if type(path) == "number" then
        return "other", "Other sounds"
    end
    if type(path) ~= "string" or path == "" then
        return "other", "Other sounds"
    end
    local addon = path:match("[Aa]dd[Oo]ns[\\/]+([^\\/]+)")
    if type(addon) == "string" and addon ~= "" then
        return "addon:" .. addon, DisplayAddonName(addon)
    end
    return "other", "Other sounds"
end

local catalog

local function InvalidateCatalog()
    catalog = nil
end

local function SortByName(a, b)
    return string.lower(a.name or "") < string.lower(b.name or "")
end

local function BuildCatalog()
    if catalog then
        return catalog
    end

    local sources = {}
    local bySource = {}
    local byId = {}
    local sourceName = {}

    local function EnsureSource(id, name)
        if bySource[id] then
            return
        end
        bySource[id] = {}
        sourceName[id] = name
        sources[#sources + 1] = {
            id = id,
            name = name,
            hint = (id == "blizzard")
                and "Built-in WoW UI sounds. Always available."
                or ("Sounds registered by " .. name .. ". Pick any sound from this pack."),
        }
    end

    EnsureSource("blizzard", "Blizzard")
    for i = 1, #Sounds.PACKS do
        local pack = Sounds.PACKS[i]
        if Sounds.IsAvailable(pack) then
            local rec = {
                id = pack.id,
                name = pack.name,
                kits = pack.kits,
                kit = pack.kit,
                fallback = pack.fallback,
                source = "blizzard",
                hint = "Blizzard UI sound.",
            }
            bySource.blizzard[#bySource.blizzard + 1] = rec
            byId[pack.id] = rec
        end
    end
    if #bySource.blizzard == 0 then
        for i = 1, #Sounds.PACKS do
            local pack = Sounds.PACKS[i]
            local rec = {
                id = pack.id,
                name = pack.name,
                kits = pack.kits,
                kit = pack.kit,
                fallback = pack.fallback,
                source = "blizzard",
                hint = "Blizzard UI sound.",
            }
            bySource.blizzard[#bySource.blizzard + 1] = rec
            byId[pack.id] = rec
        end
    end

    local lsm = GetLSM()
    if lsm then
        local names = ListLSMKeys(lsm)
        for i = 1, #names do
            local key = names[i]
            local path
            if lsm.Fetch then
                local ok, fetched = pcall(lsm.Fetch, lsm, "sound", key, true)
                if ok then
                    path = fetched
                end
                if path == nil then
                    ok, fetched = pcall(lsm.Fetch, lsm, "sound", key)
                    if ok then
                        path = fetched
                    end
                end
            end
            local sid, sname = SourceFromPath(path)
            EnsureSource(sid, sname)
            local rec = MakeLSMSound(key, sid)
            rec.hint = "From " .. sname .. "."
            bySource[sid][#bySource[sid] + 1] = rec
            byId[rec.id] = rec
        end
    end

    for _, list in pairs(bySource) do
        table.sort(list, SortByName)
    end
    table.sort(sources, function(a, b)
        if a.id == "blizzard" then
            return true
        end
        if b.id == "blizzard" then
            return false
        end
        return SortByName(a, b)
    end)

    catalog = {
        sources = sources,
        bySource = bySource,
        byId = byId,
        sourceName = sourceName,
    }
    return catalog
end

function Sounds.GetSources()
    InvalidateCatalog()
    return BuildCatalog().sources
end

function Sounds.GetBrowseSources()
    local out = {
        { id = "all", name = "All packs", hint = "Every sound from every installed pack, not just the default." },
    }
    local sources = Sounds.GetSources()
    for i = 1, #sources do
        out[#out + 1] = sources[i]
    end
    return out
end

function Sounds.GetSounds(sourceId)
    local cat = BuildCatalog()
    if sourceId == "all" or sourceId == nil then
        local out = {}
        for i = 1, #cat.sources do
            local src = cat.sources[i]
            local list = cat.bySource[src.id]
            if list then
                for j = 1, #list do
                    local rec = list[j]
                    out[#out + 1] = {
                        id = rec.id,
                        name = src.name .. ": " .. rec.name,
                        hint = rec.hint or ("From " .. src.name .. "."),
                        source = src.id,
                    }
                end
            end
        end
        return out
    end
    return cat.bySource[sourceId] or {}
end

function Sounds.SourceOf(soundId)
    local cat = BuildCatalog()
    local rec = type(soundId) == "string" and cat.byId[soundId]
    if rec and rec.source then
        return rec.source, cat.sourceName[rec.source] or rec.source
    end
    if LSMKeyFromID(soundId) then
        return "other", cat.sourceName.other or "Other sounds"
    end
    return "blizzard", "Blizzard"
end

function Sounds.SourceName(sourceId)
    local cat = BuildCatalog()
    if type(sourceId) == "string" and cat.sourceName[sourceId] then
        return cat.sourceName[sourceId]
    end
    return "Blizzard"
end

function Sounds.SoundName(id)
    local cat = BuildCatalog()
    local rec = type(id) == "string" and cat.byId[id]
    if rec and rec.name then
        return rec.name
    end
    local pack = Sounds.FindPack(id)
    return pack and pack.name or "Raid Warning"
end

function Sounds.ResolveKit(pack)
    pack = pack or Sounds.FindPack(AH.DB and AH.DB.GetSoundPackID and AH.DB.GetSoundPackID())
    if type(pack) == "string" then
        pack = Sounds.FindPack(pack)
    end
    if type(pack) ~= "table" then
        return 8959
    end
    if SOUNDKIT then
        local names = KitNames(pack)
        for i = 1, #names do
            local kit = SOUNDKIT[names[i]]
            if type(kit) == "number" then
                return kit
            end
        end
    end
    return pack.fallback or 8959
end

function Sounds.IsAvailable(pack)
    if type(pack) ~= "table" then
        return false
    end
    if not SOUNDKIT then
        return pack.fallback ~= nil
    end
    local names = KitNames(pack)
    for i = 1, #names do
        if type(SOUNDKIT[names[i]]) == "number" then
            return true
        end
    end
    return false
end

function Sounds.GetPacks()
    local cat = BuildCatalog()
    local out = {}
    for i = 1, #cat.sources do
        local list = cat.bySource[cat.sources[i].id]
        if list then
            for j = 1, #list do
                out[#out + 1] = list[j]
            end
        end
    end
    return out
end

function Sounds.FindPack(id)
    if type(id) ~= "string" then
        return Sounds.PACKS[1]
    end
    local cat = BuildCatalog()
    if cat.byId[id] then
        return cat.byId[id]
    end
    local lsmKey = LSMKeyFromID(id)
    if lsmKey then
        return MakeLSMSound(lsmKey, "other")
    end
    for i = 1, #Sounds.PACKS do
        if Sounds.PACKS[i].id == id then
            return Sounds.PACKS[i]
        end
    end
    return Sounds.PACKS[1]
end

local function PlayFile(path)
    if path == nil or not PlaySoundFile then
        return false
    end
    local ok = pcall(PlaySoundFile, path, "Master")
    if ok then
        return true
    end
    ok = pcall(PlaySoundFile, path)
    return ok and true or false
end

function Sounds.Play(packID)
    if AH.DB and AH.DB.IsMasterEnabled and not AH.DB.IsMasterEnabled() then
        return false
    end
    local pack = packID
    if type(packID) == "string" then
        pack = Sounds.FindPack(packID)
    end
    if type(pack) == "table" and pack.lsm then
        local lsm = GetLSM()
        if lsm and lsm.Fetch then
            local path = lsm:Fetch("sound", pack.lsm, true)
            if PlayFile(path) then
                return true
            end
        end
        return false
    end
    local kit = Sounds.ResolveKit(pack)
    if PlaySound then
        local ok = pcall(PlaySound, kit, "Master", true)
        if ok then
            return true
        end
        ok = pcall(PlaySound, kit, "SFX")
        if ok then
            return true
        end
        ok = pcall(PlaySound, kit)
        if ok then
            return true
        end
    end
    return false
end

function Sounds.PlaySelected()
    return Sounds.Play(AH.DB and AH.DB.GetSoundPackID and AH.DB.GetSoundPackID())
end

function Sounds.ChoiceName(id)
    if type(id) ~= "string" or id == "" then
        return "Use default sound"
    end
    local _, sourceName = Sounds.SourceOf(id)
    local soundName = Sounds.SoundName(id)
    if sourceName and sourceName ~= "" then
        return sourceName .. ": " .. soundName
    end
    return soundName
end

function Sounds.GetChoiceList(sourceId)
    InvalidateCatalog()
    local out = {
        {
            id = "",
            name = "Use default sound",
            hint = "Uses the default sound from Sounds → Default sound.",
        },
    }
    local list = Sounds.GetSounds(sourceId or "all")
    for i = 1, #list do
        out[#out + 1] = list[i]
    end
    return out
end

function Sounds.PackName(id)
    return Sounds.SoundName(id)
end

function Sounds.HasSharedMedia()
    return GetLSM() ~= nil
end

local function WatchLSM()
    local lsm = GetLSM()
    if not lsm or not lsm.RegisterCallback or Sounds._lsmWatched then
        return
    end
    Sounds._lsmWatched = true
    lsm.RegisterCallback(Sounds, "LibSharedMedia_Registered", function(_, mediaType)
        if mediaType == "sound" or mediaType == nil then
            Sounds._lsmCache = nil
            InvalidateCatalog()
        end
    end)
end

WatchLSM()
local lsmBoot = CreateFrame("Frame")
lsmBoot:RegisterEvent("ADDON_LOADED")
lsmBoot:RegisterEvent("PLAYER_LOGIN")
lsmBoot:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "LibSharedMedia-3.0" or name == "SharedMedia" or (type(name) == "string" and name:find("SharedMedia", 1, true)) then
            InvalidateCatalog()
            WatchLSM()
        end
        return
    end
    InvalidateCatalog()
    WatchLSM()
    lsmBoot:UnregisterEvent("PLAYER_LOGIN")
end)
