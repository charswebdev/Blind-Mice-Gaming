--[[
  AllQuest — TTS announce
  Uses Accessibility Helper speech queue when present; otherwise SpeakText.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Speech = AQ.Speech or {}
local Speech = AQ.Speech

local lastSpoken = ""

local function DB()
    return AQ.DB and AQ.DB.Get and AQ.DB.Get() or {}
end

local function Enabled()
    return DB().speechEnabled ~= false
end

local function SpeakMode()
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then
        return "none"
    end
    local iface = AQ.Compat.GetInterfaceVersion()
    local hasDestEnum = Enum and Enum.VoiceTtsDestination ~= nil
    if iface >= 120000 or not hasDestEnum then
        return "overlap"
    end
    return "destination"
end

local function DirectSpeak(text, overlap)
    local mode = SpeakMode()
    if mode == "none" then
        return false
    end
    local db = DB()
    local rate = db.ttsRate or 0
    if rate < -10 then
        rate = -10
    end
    if rate > 10 then
        rate = 10
    end
    local volume = db.ttsVolume or 100
    if volume < 0 then
        volume = 0
    end
    if volume > 100 then
        volume = 100
    end
    local voiceID = 0
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        local ok, vid = pcall(C_TTSSettings.GetVoiceOptionID, 0)
        if ok and type(vid) == "number" then
            voiceID = vid
        end
    end
    if mode == "overlap" then
        return pcall(C_VoiceChat.SpeakText, voiceID, text, rate, volume, overlap and true or false)
    end
    if overlap and C_VoiceChat.StopSpeakingText then
        pcall(C_VoiceChat.StopSpeakingText)
    end
    local dest = 1
    local E = Enum and Enum.VoiceTtsDestination
    if E and E.LocalPlayback ~= nil then
        dest = E.LocalPlayback
    end
    return pcall(C_VoiceChat.SpeakText, voiceID, text, dest, rate, volume)
end

function Speech.Say(text, force)
    if not force and not Enabled() then
        return
    end
    text = AQ:StripMarkup(text)
    if text == "" then
        return
    end
    lastSpoken = text
    local AH = AccessibilityHelper
    if AH and AH.Speech and type(AH.Speech.Say) == "function" then
        pcall(AH.Speech.Say, text, AH.Speech.PRIORITY_NAV)
        return
    end
    DirectSpeak(text, false)
end

--- Speak this line now. Does not use Accessibility Helper Stop (that mutes new speech).
function Speech.Replace(text)
    if not Enabled() then
        return
    end
    text = AQ:StripMarkup(text)
    if text == "" then
        return
    end
    lastSpoken = text
    local AH = AccessibilityHelper
    if AH and AH.Speech then
        if type(AH.Speech.ClearNavQueue) == "function" then
            pcall(AH.Speech.ClearNavQueue)
        end
        if type(AH.Speech.Say) == "function" then
            pcall(AH.Speech.Say, text, AH.Speech.PRIORITY_NAV)
            return
        end
    end
    DirectSpeak(text, true)
end

function Speech.Stop()
    local AH = AccessibilityHelper
    if AH and AH.Speech and type(AH.Speech.Stop) == "function" then
        pcall(AH.Speech.Stop)
        return
    end
    if C_VoiceChat and C_VoiceChat.StopSpeakingText then
        pcall(C_VoiceChat.StopSpeakingText)
    end
end

function Speech.Repeat()
    if lastSpoken ~= "" then
        Speech.Say(lastSpoken, true)
    end
end

function Speech.Last()
    return lastSpoken
end

local hoverSpoken

function Speech.Hover(text)
    if type(text) ~= "string" then
        return
    end
    text = AQ:StripMarkup(text)
    if text == "" or text == hoverSpoken then
        return
    end
    hoverSpoken = text
    Speech.Replace(text)
end

function Speech.HoverClear()
    hoverSpoken = nil
end

--- Wrap OnEnter/OnLeave so hovering speaks getter (string or function).
function Speech.AttachHover(frame, getter)
    if not frame or frame.AQHoverBound then
        return frame
    end
    frame.AQHoverBound = true
    frame.AQHoverGetter = getter
    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
    local prevEnter = frame:GetScript("OnEnter")
    local prevLeave = frame:GetScript("OnLeave")
    frame:SetScript("OnEnter", function(self, ...)
        if prevEnter then
            prevEnter(self, ...)
        end
        local g = self.AQHoverGetter
        local text
        if type(g) == "function" then
            text = g(self)
        else
            text = g
        end
        Speech.Hover(text)
    end)
    frame:SetScript("OnLeave", function(self, ...)
        if prevLeave then
            prevLeave(self, ...)
        end
        Speech.HoverClear()
    end)
    return frame
end
