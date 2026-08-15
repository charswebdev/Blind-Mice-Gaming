--[[
  Accessibility Helper — subzone announcements
  Subzone: bare GetSubZoneText (not a chat line).
  Area discovery is left to chat (System Messages) so it is not spoken twice.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Location = AH.Location or {}
local Location = AH.Location

local lastSubzone = nil
local pendingSubzone = nil
local pendingGen = 0
local readyAt = 0
local lastSpeakAt = 0
local DEBOUNCE_SEC = 1.25

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function SubzoneEnabled()
    return DB().locationSubzoneEnabled ~= false
end

local function Say(msg)
    if type(msg) ~= "string" or msg == "" then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_STATUS)
    else
        print("|cff66ccff[Helper]|r " .. msg)
    end
end

local function ForSpeech(text)
    if AH.ChatText and AH.ChatText.ForChatMessage then
        return AH.ChatText.ForChatMessage(text)
    end
    if AH.ChatText and AH.ChatText.ForSpeech then
        return AH.ChatText.ForSpeech(text)
    end
    return tostring(text or "")
end

local function GetSubzone()
    if not GetSubZoneText then
        return ""
    end
    local ok, text = pcall(GetSubZoneText)
    if not ok or type(text) ~= "string" then
        return ""
    end
    return ForSpeech(text)
end

function Location.Check(force)
    if not SubzoneEnabled() then
        return
    end
    local now = GetTime and GetTime() or 0
    if now < readyAt and not force then
        return
    end

    local sub = GetSubzone()
    if sub == "" then
        lastSubzone = sub
        pendingSubzone = nil
        return
    end
    if not force and sub == lastSubzone and not pendingSubzone then
        return
    end
    if force then
        pendingSubzone = nil
        pendingGen = pendingGen + 1
        lastSubzone = sub
        lastSpeakAt = now
        Say(sub)
        return
    end

    -- During debounce: queue pending name; do NOT advance lastSubzone until spoken.
    if (now - lastSpeakAt) < DEBOUNCE_SEC then
        pendingSubzone = sub
        pendingGen = pendingGen + 1
        local myGen = pendingGen
        local wait = DEBOUNCE_SEC - (now - lastSpeakAt)
        if wait < 0.05 then
            wait = 0.05
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(wait, function()
                if myGen ~= pendingGen then
                    return
                end
                local pending = pendingSubzone
                pendingSubzone = nil
                if not pending or pending == "" or pending == lastSubzone then
                    return
                end
                lastSubzone = pending
                lastSpeakAt = GetTime and GetTime() or 0
                Say(pending)
            end)
        end
        return
    end

    pendingSubzone = nil
    lastSubzone = sub
    lastSpeakAt = now
    Say(sub)
end

--- Silent: discovery TTS removed (chat covers it). Still mark XP so Progress
-- does not also say exploration XP when the discovery line already included it.
local function NoteDiscoveryXP(messageType, message)
    local text = ForSpeech(message)
    if text == "" then
        return
    end
    local explored = _G.LE_GAME_ERR_ZONE_EXPLORED
        or (Enum and Enum.LE_GAME_ERR_ZONE_EXPLORED)
    local exploredXp = _G.LE_GAME_ERR_ZONE_EXPLORED_XP
        or (Enum and Enum.LE_GAME_ERR_ZONE_EXPLORED_XP)
    local isDiscovery = false
    if messageType ~= nil then
        if exploredXp ~= nil and messageType == exploredXp then
            isDiscovery = true
        elseif explored ~= nil and messageType == explored then
            isDiscovery = true
        elseif messageType == 378 or messageType == 379 or messageType == 408 or messageType == 409 then
            isDiscovery = true
        end
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

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        readyAt = (GetTime and GetTime() or 0) + 3
        lastSubzone = GetSubzone()
        pendingSubzone = nil
        pendingGen = pendingGen + 1
        lastSpeakAt = 0
        return
    end
    if event == "UI_INFO_MESSAGE" then
        local a1, a2 = ...
        local messageType, message
        if type(a2) == "string" then
            messageType = a1
            message = a2
        elseif type(a1) == "string" then
            message = a1
        else
            return
        end
        NoteDiscoveryXP(messageType, message)
        return
    end
    Location.Check(false)
end)
