--[[
  Accessibility Helper — client / API compatibility (Phase 1.1)
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Compat = AH.Compat or {}
local Compat = AH.Compat

-- "overlap" = Patch 12.0+ SpeakText(voiceID, text, rate, volume [, overlap])
-- "destination" = older SpeakText(voiceID, text, destination, rate, volume)
-- "none" = SpeakText unavailable
local speakMode -- nil until first detect

local function DetectSpeakMode()
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then
        return "none"
    end
    local iface = select(4, GetBuildInfo()) or 0
    local hasDestEnum = Enum and Enum.VoiceTtsDestination ~= nil
    -- Mainline 12.0+ removed destination. Some Classic builds share the new API
    -- even with lower Interface numbers — prefer overlap when destination enum is gone.
    if iface >= 120000 or not hasDestEnum then
        return "overlap"
    end
    return "destination"
end

function Compat.GetSpeakMode()
    if not speakMode then
        speakMode = DetectSpeakMode()
    end
    return speakMode
end

function Compat.GetInterfaceVersion()
    return select(4, GetBuildInfo()) or 0
end

--- True if value is a Midnight+ secret (opaque) value.
function Compat.IsSecretValue(v)
    if v == nil or not issecretvalue then
        return false
    end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret and true or false
end

--- True if we may compare, concatenate, or do logic on v.
function Compat.CanUseValue(v)
    if v == nil or not Compat.IsSecretValue(v) then
        return true
    end
    if canaccessvalue then
        local ok, access = pcall(canaccessvalue, v)
        return ok and access and true or false
    end
    return false
end

--- True if we may do arithmetic/compare on v (non-secret, or secret we can access).
function Compat.CanUseNumber(v)
    if type(v) ~= "number" then
        return false
    end
    return Compat.CanUseValue(v)
end

function Compat.GetSystemTtsVoiceID()
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        local voiceType = 0 -- Enum.TtsVoiceType.Standard
        if Enum and Enum.TtsVoiceType and Enum.TtsVoiceType.Standard then
            voiceType = Enum.TtsVoiceType.Standard
        end
        local ok, vid = pcall(C_TTSSettings.GetVoiceOptionID, voiceType)
        if ok and type(vid) == "number" then
            return vid
        end
    end
    return 0
end

--- Active voice: addon choice if set, otherwise Blizzard system default.
function Compat.GetTtsVoiceID()
    if AH.DB and AH.DB.GetSavedTtsVoiceID then
        local saved = AH.DB.GetSavedTtsVoiceID()
        if type(saved) == "number" then
            return saved
        end
    end
    return Compat.GetSystemTtsVoiceID()
end

--- Local TTS voices available on this machine.
function Compat.ListTtsVoices()
    local list = {}
    local seen = {}
    local function add(voices)
        if type(voices) ~= "table" then
            return
        end
        for i = 1, #voices do
            local v = voices[i]
            if type(v) == "table" and type(v.voiceID) == "number" and not seen[v.voiceID] then
                seen[v.voiceID] = true
                local name = v.name
                if type(name) ~= "string" or name == "" then
                    name = "Voice " .. tostring(v.voiceID)
                end
                list[#list + 1] = { voiceID = v.voiceID, name = name }
            end
        end
    end
    if C_VoiceChat and C_VoiceChat.GetTtsVoices then
        local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
        if ok then
            add(voices)
        end
    end
    table.sort(list, function(a, b)
        return tostring(a.name):lower() < tostring(b.name):lower()
    end)
    return list
end

function Compat.GetTtsVoiceName(voiceID)
    if type(voiceID) ~= "number" then
        return "System default"
    end
    local list = Compat.ListTtsVoices()
    for i = 1, #list do
        if list[i].voiceID == voiceID then
            return list[i].name
        end
    end
    return "Voice " .. tostring(voiceID)
end

-- Invalidates delayed StopSpeakingText from a prior FlushSpeakText when a new flush starts.
-- SpeakText does NOT bump this — otherwise a Say right after clear cancels the drain.
local flushGen = 0

--- Speak via Blizzard TTS. Returns ok, utteranceID|nil
-- @param text string
-- @param rate number|nil  UI rate 0-10 (0 = slowest/normal, 10 = fastest)
-- @param volume number|nil  0-100, default 100
-- @param overlap boolean|nil  Midnight only; ignored on destination API
-- @param voiceID number|nil  override voice; default Compat.GetTtsVoiceID()
function Compat.SpeakText(text, rate, volume, overlap, voiceID)
    if type(text) ~= "string" or text == "" then
        return false, nil
    end
    local mode = Compat.GetSpeakMode()
    if mode == "none" then
        return false, nil
    end
    -- UI 0 = default/slowest (SpeakText 0). 1–10 each step faster up to SpeakText 10.
    rate = rate or 0
    if rate < 0 then rate = 0 end
    if rate > 10 then rate = 10 end
    local speakRate = rate
    volume = volume or 100
    if volume < 0 then volume = 0 end
    if volume > 100 then volume = 100 end
    if type(voiceID) ~= "number" then
        voiceID = Compat.GetTtsVoiceID()
    end

    -- Keep Blizzard TTS settings in sync so destinations that read system rate match.
    if C_TTSSettings and C_TTSSettings.SetSpeechRate then
        pcall(C_TTSSettings.SetSpeechRate, speakRate)
    end

    -- Windows SAPI rate tag — honored even when the rate argument is ignored.
    local speakText = text
    if not text:find("^<rate%s", 1) then
        speakText = string.format('<rate absspeed="%d"/>%s', speakRate, text)
    end

    local function callSpeak(payload)
        if mode == "overlap" then
            return pcall(C_VoiceChat.SpeakText, voiceID, payload, speakRate, volume, overlap and true or false)
        end
        local dest = 1 -- LocalPlayback
        local E = Enum and Enum.VoiceTtsDestination
        if E then
            if E.LocalPlayback ~= nil then
                dest = E.LocalPlayback
            elseif E.QueuedLocalPlayback ~= nil then
                dest = E.QueuedLocalPlayback
            elseif E.ScreenReader ~= nil then
                dest = E.ScreenReader
            end
        end
        return pcall(C_VoiceChat.SpeakText, voiceID, payload, dest, speakRate, volume)
    end

    local ok, a, b = callSpeak(speakText)
    if not ok then
        ok, a, b = callSpeak(text)
    end
    if not ok then
        return false, nil
    end
    -- Some clients return utteranceID; otherwise SPEAK_TEXT_UPDATE supplies it.
    local utteranceID = nil
    if type(a) == "number" then
        utteranceID = a
    elseif type(b) == "number" then
        utteranceID = b
    end
    return true, utteranceID
end

function Compat.StopSpeakText()
    if C_VoiceChat and C_VoiceChat.StopSpeakingText then
        pcall(C_VoiceChat.StopSpeakingText)
    end
end

--- Invoke Blizzard /tts stop via the real slash handler when present.
local function TryBlizzardTtsStopSlash()
    if type(SlashCmdList) ~= "table" then
        return false
    end
    local keys = {
        "TEXTTOSPEECH",
        "TTS",
        "TextToSpeech",
        "ACECONSOLE_TTS",
        "ACECONSOLE_TEXTTOSPEECH",
    }
    for i = 1, #keys do
        local fn = SlashCmdList[keys[i]]
        if type(fn) == "function" then
            local ok = pcall(fn, "stop")
            if ok then
                return true
            end
        end
    end
    -- Prefer known SLASH_* names over scanning all of _G.
    local slashNames = {
        "SLASH_TEXTTOSPEECH1",
        "SLASH_TEXTTOSPEECH2",
        "SLASH_TTS1",
        "SLASH_TTS2",
    }
    for i = 1, #slashNames do
        local slash = _G[slashNames[i]]
        if type(slash) == "string" and slash:lower() == "/tts" then
            local id = slashNames[i]:match("^SLASH_(.-)%d+$")
            if id and type(SlashCmdList[id]) == "function" then
                local ok = pcall(SlashCmdList[id], "stop")
                if ok then
                    return true
                end
            end
        end
    end
    return false
end

--- Hard flush: stop current speech and drain Blizzard's TTS synthesizer queue.
function Compat.FlushSpeakText()
    flushGen = flushGen + 1
    local myFlush = flushGen

    local function purgePulse()
        if myFlush ~= flushGen then
            return
        end
        Compat.StopSpeakText()
        TryBlizzardTtsStopSlash()
        -- Force SAPI interrupt: speak a silent blank with overlap, then stop again.
        -- Some clients keep mid-utterance audio until a new SpeakText preempts it.
        if C_VoiceChat and C_VoiceChat.SpeakText then
            local voiceID = Compat.GetTtsVoiceID()
            local mode = Compat.GetSpeakMode()
            if mode == "overlap" then
                pcall(C_VoiceChat.SpeakText, voiceID, " ", 0, 0, true)
            elseif mode == "destination" then
                local dest = 1
                local E = Enum and Enum.VoiceTtsDestination
                if E and E.LocalPlayback ~= nil then
                    dest = E.LocalPlayback
                end
                pcall(C_VoiceChat.SpeakText, voiceID, " ", dest, 0, 0)
            end
            Compat.StopSpeakText()
        end
    end

    purgePulse()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, purgePulse)
        C_Timer.After(0.05, purgePulse)
        C_Timer.After(0.15, purgePulse)
        C_Timer.After(0.35, purgePulse)
        C_Timer.After(0.6, purgePulse)
        C_Timer.After(0.9, purgePulse)
    end
end
