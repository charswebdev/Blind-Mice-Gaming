--[[
  Accessibility Helper — new location announcements
  Speaks every time the place changes. A smaller place name is used when
  there is one. Otherwise the area name is spoken. Login stays quiet.
  Area discovery stays with chat System Messages.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Location = AH.Location or {}
local Location = AH.Location

local lastZone = nil
local lastName = nil
local primed = false
local readyAt = 0
local waitGen = 0
local poll = 0

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function SubzoneEnabled()
    return DB().locationSubzoneEnabled == true
end

local function Now()
    if not GetTime then
        return 0
    end
    local ok, t = pcall(GetTime)
    if ok ~= true then
        return 0
    end
    if AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(t) then
        return t
    end
    if type(t) == "number" then
        return t
    end
    return 0
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

local function Say(msg)
    msg = Plain(msg)
    if not msg then
        return
    end
    if not msg:find("%.$") then
        msg = msg .. "."
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_STATUS, { noEcho = true })
    end
end

local function ForSpeech(text)
    text = Plain(text)
    if not text then
        return ""
    end
    if AH.ChatText and AH.ChatText.ForChatMessage then
        local spoken = AH.ChatText.ForChatMessage(text)
        return Plain(spoken) or ""
    end
    if AH.ChatText and AH.ChatText.ForSpeech then
        local spoken = AH.ChatText.ForSpeech(text)
        return Plain(spoken) or ""
    end
    return text
end

local function ReadName(fn)
    if type(fn) ~= "function" then
        return ""
    end
    local ok, text = pcall(fn)
    if ok ~= true then
        return ""
    end
    return ForSpeech(text)
end

local function CurrentPlace()
    local zone = ReadName(GetZoneText)
    if zone == "" then
        zone = ReadName(GetRealZoneText)
    end
    local name = ReadName(GetSubZoneText)
    if name == "" then
        name = ReadName(GetMinimapZoneText)
    end
    if name == "" then
        name = zone
    end
    return zone, name
end

local function Remember(zone, name)
    if zone ~= "" then
        lastZone = zone
    end
    if name ~= "" then
        lastName = name
    end
end

local function SameCode(a, b)
    if AH.Compat and AH.Compat.CanUseValue then
        if not AH.Compat.CanUseValue(a) or not AH.Compat.CanUseValue(b) then
            return false
        end
    end
    return a == b
end

function Location.Check(force)
    if not SubzoneEnabled() then
        primed = false
        return
    end
    local zone, name = CurrentPlace()
    if name == "" and zone == "" then
        return
    end
    local now = Now()
    if force ~= true and (now < readyAt or not primed) then
        Remember(zone, name)
        if now >= readyAt and name ~= "" then
            primed = true
        end
        return
    end
    if name ~= "" and name ~= lastName then
        Remember(zone, name)
        Say(name)
        return
    end
    if zone ~= "" and zone ~= lastZone then
        Remember(zone, name)
        Say(zone)
        return
    end
    Remember(zone, name)
end

--- Silent. Discovery speech stays on the chat system-message switch.
local function NoteDiscoveryXP(messageType, message)
    local text = ForSpeech(message)
    if text == "" then
        return
    end
    local explored = _G.LE_GAME_ERR_ZONE_EXPLORED
    if type(explored) ~= "number" and type(Enum) == "table" then
        explored = Enum.LE_GAME_ERR_ZONE_EXPLORED
    end
    local exploredXp = _G.LE_GAME_ERR_ZONE_EXPLORED_XP
    if type(exploredXp) ~= "number" and type(Enum) == "table" then
        exploredXp = Enum.LE_GAME_ERR_ZONE_EXPLORED_XP
    end
    local isDiscovery = false
    if SameCode(messageType, exploredXp) or SameCode(messageType, explored) then
        isDiscovery = true
    elseif SameCode(messageType, 378) or SameCode(messageType, 379) or SameCode(messageType, 408) or SameCode(messageType, 409) then
        isDiscovery = true
    end
    if not isDiscovery then
        local lower = string.lower(text)
        if not lower:find("discovered", 1, true) then
            return
        end
    end
    if AH.Progress and AH.Progress.NoteRecentXPFromText then
        AH.Progress.NoteRecentXPFromText(text)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UI_INFO_MESSAGE")

local function ScheduleCheck()
    Location.Check(false)
    if not C_Timer or not C_Timer.After then
        return
    end
    waitGen = waitGen + 1
    local gen = waitGen
    C_Timer.After(0.2, function()
        if gen ~= waitGen then
            return
        end
        Location.Check(false)
    end)
end

frame:SetScript("OnUpdate", function(self, elapsed)
    if type(elapsed) ~= "number" then
        return
    end
    poll = poll + elapsed
    if poll < 0.3 then
        return
    end
    poll = 0
    Location.Check(false)
end)

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        readyAt = Now() + 2
        primed = false
        lastZone = nil
        lastName = nil
        waitGen = waitGen + 1
        return
    end
    if event == "UI_INFO_MESSAGE" then
        local a1, a2 = ...
        local messageType, message
        if Plain(a2) then
            messageType = a1
            message = a2
        elseif Plain(a1) then
            message = a1
        else
            return
        end
        NoteDiscoveryXP(messageType, message)
        return
    end
    ScheduleCheck()
end)
