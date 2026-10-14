--[[
  AllQuest — quest complete sound
  Blizzard's own quest-complete sound kit. Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Sounds = AQ.Sounds or {}
local Sounds = AQ.Sounds

local locked = false

local function CompleteKit()
    if not SOUNDKIT then
        return nil
    end
    return SOUNDKIT.IG_QUEST_LIST_COMPLETE or SOUNDKIT.QUEST_COMPLETED
end

function Sounds.Play()
    if locked or not PlaySound then
        return
    end
    local kit = CompleteKit()
    if not kit then
        return
    end
    locked = true
    pcall(PlaySound, kit, "Master")
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
    Sounds.Play()
end
