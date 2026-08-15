--[[
  AllQuest — quest complete sounds
  Same Blizzard FileDataIDs Kaliel's Tracker offers. Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Sounds = AQ.Sounds or {}
local Sounds = AQ.Sounds

-- FileDataIDs are in-game audio. Stored here as AllQuest media options.
local CATALOG = {
    { id = "Default", file = 558132 },
    { id = "BloodElf (M)", file = 539400 },
    { id = "BloodElf (F)", file = 539175 },
    { id = "Draenei (M)", file = 539661 },
    { id = "Draenei (F)", file = 539676 },
    { id = "Dwarf (M)", file = 540042 },
    { id = "Dwarf (F)", file = 539981 },
    { id = "Gnome (M)", file = 540512 },
    { id = "Gnome (F)", file = 540432 },
    { id = "Goblin (M)", file = 542005 },
    { id = "Goblin (F)", file = 541735 },
    { id = "Human (M)", file = 540703 },
    { id = "Human (F)", file = 540654 },
    { id = "NightElf (M)", file = 541085 },
    { id = "NightElf (F)", file = 541031 },
    { id = "Orc (M)", file = 541401 },
    { id = "Orc (F)", file = 541317 },
    { id = "Pandaren (M)", file = 630070 },
    { id = "Pandaren (F)", file = 636419 },
    { id = "Tauren (M)", file = 561484 },
    { id = "Tauren (F)", file = 542997 },
    { id = "Troll (M)", file = 543307 },
    { id = "Troll (F)", file = 543273 },
    { id = "Undead (M)", file = 542775 },
    { id = "Undead (F)", file = 542684 },
    { id = "Worgen (M)", file = 542228 },
    { id = "Worgen (F)", file = 542028 },
}

local CHANNELS = {
    { id = "Master", label = "Master" },
    { id = "SFX", label = "SFX" },
    { id = "Music", label = "Music" },
    { id = "Ambience", label = "Ambience" },
}

function Sounds.List()
    return CATALOG
end

function Sounds.Channels()
    return CHANNELS
end

function Sounds.FileFor(id)
    for i = 1, #CATALOG do
        if CATALOG[i].id == id then
            return CATALOG[i].file
        end
    end
    return CATALOG[1].file
end

local locked = false

function Sounds.Play(id, channel)
    if locked then
        return
    end
    local file = Sounds.FileFor(id)
    if not file or not PlaySoundFile then
        return
    end
    locked = true
    pcall(PlaySoundFile, file, channel or "Master")
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function()
            locked = false
        end)
    else
        locked = false
    end
end

function Sounds.PlayQuestComplete()
    local db = AQ.DB and AQ.DB.Get and AQ.DB.Get() or {}
    if db.soundQuest == false then
        return
    end
    Sounds.Play(db.soundQuestComplete or "Default", db.soundChannel or "Master")
end
