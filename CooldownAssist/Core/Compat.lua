--[[
  Cooldown Assist — client / API compatibility (all WoW flavors)
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Compat = CA.Compat or {}
local Compat = CA.Compat

-- "overlap" = Patch 12.0+ SpeakText(voiceID, text, rate, volume [, overlap])
-- "destination" = older SpeakText(voiceID, text, destination, rate, volume)
-- "none" = SpeakText unavailable
local speakMode

function Compat.GetInterfaceVersion()
    return select(4, GetBuildInfo()) or 0
end

function Compat.IsMainline()
    local iface = Compat.GetInterfaceVersion()
    -- Mainline retail/midnight/tww are 10xxxxxx–12xxxxxx (and future).
    return iface >= 100000
end

function Compat.HasToyBox()
    return C_ToyBox ~= nil and type(C_ToyBox.GetNumToys) == "function"
end

function Compat.HasModernSpellBook()
    return C_SpellBook ~= nil
        and type(C_SpellBook.GetNumSpellBookSkillLines) == "function"
        and type(C_SpellBook.GetSpellBookItemInfo) == "function"
end

function Compat.HasSecretValues()
    return type(issecretvalue) == "function"
end

--- pcall that preserves WoW API multi-returns without allocating a results table.
--- 10 slots covers GetPetActionInfo (7) and similar; do not use { pcall(...) }.
function Compat.SafeCall(fn, ...)
    if not fn then
        return
    end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if not ok then
        return
    end
    return a, b, c, d, e, f, g, h, i, j
end

--- Register an event only if the client knows it (avoids Classic load errors).
function Compat.SafeRegisterEvent(frame, event)
    if not frame or type(event) ~= "string" or event == "" then
        return false
    end
    if type(frame.RegisterEvent) ~= "function" then
        return false
    end
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok and true or false
end

function Compat.SafeRegisterUnitEvent(frame, event, ...)
    if not frame or type(event) ~= "string" then
        return false
    end
    if type(frame.RegisterUnitEvent) == "function" then
        local ok = pcall(frame.RegisterUnitEvent, frame, event, ...)
        if ok then
            return true
        end
    end
    return Compat.SafeRegisterEvent(frame, event)
end

function Compat.IsSecretValue(v)
    if v == nil or not issecretvalue then
        return false
    end
    local ok, secret = pcall(issecretvalue, v)
    return ok and secret and true or false
end

-- Cache restriction for this frame (GetTime is stable within a frame).
local secretsFrameTime = nil
local secretsRestricted = false

function Compat.SecretsRestricted()
    if not issecretvalue then
        return false
    end
    local t = (GetTime and GetTime()) or 0
    if secretsFrameTime == t then
        return secretsRestricted
    end
    secretsFrameTime = t
    secretsRestricted = true
    if C_Secrets and C_Secrets.ShouldSpellCooldownBeSecret then
        local ok, v = pcall(C_Secrets.ShouldSpellCooldownBeSecret)
        if ok then
            secretsRestricted = v and true or false
        end
    end
    return secretsRestricted
end

function Compat.CanUseNumber(v)
    if type(v) ~= "number" then
        return false
    end
    if not issecretvalue or not Compat.SecretsRestricted() then
        return true
    end
    if not Compat.IsSecretValue(v) then
        return true
    end
    if canaccessvalue then
        local ok, access = pcall(canaccessvalue, v)
        return ok and access and true or false
    end
    return false
end

local function EqTrue(v)
    return v == true
end

local function EqFalse(v)
    return v == false
end

function Compat.SafeFlagTrue(v)
    if v == nil then
        return false
    end
    local ok, result = pcall(EqTrue, v)
    return ok and result and true or false
end

function Compat.SafeFlagFalse(v)
    if v == nil then
        return false
    end
    local ok, result = pcall(EqFalse, v)
    return ok and result and true or false
end

--- Unified spell cooldown across Classic multi-return and Retail table APIs.
--- Returns a reused table { isActive, isEnabled, isOnGCD, duration, startTime } or nil.
--- Callers must read fields immediately; do not store the table.
local cdState = {
    isActive = false,
    isEnabled = true,
    isOnGCD = false,
    duration = nil,
    startTime = nil,
}

function Compat.GetSpellCooldownState(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = Compat.SafeCall(C_Spell.GetSpellCooldown, spellID)
        if type(info) == "table" then
            local duration = Compat.CanUseNumber(info.duration) and info.duration or nil
            local startTime = Compat.CanUseNumber(info.startTime) and info.startTime or nil
            local isActive = Compat.SafeFlagTrue(info.isActive)
            if not isActive and type(duration) == "number" and duration > 0
                and type(startTime) == "number" and startTime > 0
            then
                isActive = true
            end
            cdState.isActive = isActive
            cdState.isEnabled = not Compat.SafeFlagFalse(info.isEnabled)
            cdState.isOnGCD = Compat.SafeFlagTrue(info.isOnGCD)
            cdState.duration = duration
            cdState.startTime = startTime
            return cdState
        end
    end
    if GetSpellCooldown then
        local startTime, duration, enable = Compat.SafeCall(GetSpellCooldown, spellID)
        local dur = Compat.CanUseNumber(duration) and duration or nil
        local start = Compat.CanUseNumber(startTime) and startTime or nil
        local isActive = false
        if type(dur) == "number" and type(start) == "number" then
            isActive = dur > 0 and start > 0
        end
        local isEnabled = true
        if enable == 0 or enable == false then
            isEnabled = false
            isActive = false
        end
        cdState.isActive = isActive
        cdState.isEnabled = isEnabled
        cdState.isOnGCD = (type(dur) == "number" and dur > 0 and dur <= 1.6) or false
        cdState.duration = dur
        cdState.startTime = start
        return cdState
    end
    return nil
end

--- Spell charges; returns nil when values are secret or API missing.
function Compat.GetSpellChargesState(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end
    if C_Spell and C_Spell.GetSpellCharges then
        local info = Compat.SafeCall(C_Spell.GetSpellCharges, spellID)
        if type(info) == "table" then
            local cur = info.currentCharges
            local maxc = info.maxCharges
            if not Compat.CanUseNumber(cur) or not Compat.CanUseNumber(maxc) then
                return nil
            end
            return { current = cur, max = maxc }
        end
    end
    if GetSpellCharges then
        local cur, maxc = Compat.SafeCall(GetSpellCharges, spellID)
        if not Compat.CanUseNumber(cur) or not Compat.CanUseNumber(maxc) then
            return nil
        end
        return { current = cur, max = maxc }
    end
    return nil
end

local function DetectSpeakMode()
    if not (C_VoiceChat and C_VoiceChat.SpeakText) then
        return "none"
    end
    local iface = Compat.GetInterfaceVersion()
    local hasDestEnum = Enum and Enum.VoiceTtsDestination ~= nil
    -- Midnight+ overlap signature.
    if iface >= 120000 then
        return "overlap"
    end
    -- Older retail / Classic with destination enum.
    if hasDestEnum then
        return "destination"
    end
    -- Ambiguous: prefer destination-style args first (more common historically).
    return "destination"
end

function Compat.GetSpeakMode()
    if not speakMode then
        speakMode = DetectSpeakMode()
    end
    return speakMode
end

function Compat.GetSystemTtsVoiceID()
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        local voiceType = 0
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

function Compat.GetTtsVoiceID()
    if CA.DB and CA.DB.GetSavedTtsVoiceID then
        local saved = CA.DB.GetSavedTtsVoiceID()
        if type(saved) == "number" then
            return saved
        end
    end
    return Compat.GetSystemTtsVoiceID()
end

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

local flushGen = 0

local function SpeakWithMode(mode, voiceID, payload, speakRate, volume, overlap)
    if mode == "overlap" then
        return pcall(C_VoiceChat.SpeakText, voiceID, payload, speakRate, volume, overlap and true or false)
    end
    local dest = 1
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

--- Speak via Blizzard TTS. Returns ok, utteranceID|nil
function Compat.SpeakText(text, rate, volume, overlap, voiceID)
    if type(text) ~= "string" or text == "" then
        return false, nil
    end
    local mode = Compat.GetSpeakMode()
    if mode == "none" then
        return false, nil
    end
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

    if C_TTSSettings and C_TTSSettings.SetSpeechRate then
        pcall(C_TTSSettings.SetSpeechRate, speakRate)
    end

    local speakText = text
    if not text:find("^<rate%s", 1) then
        speakText = string.format('<rate absspeed="%d"/>%s', speakRate, text)
    end

    local function tryBoth(payload)
        local ok, a, b = SpeakWithMode(mode, voiceID, payload, speakRate, volume, overlap)
        if ok then
            return ok, a, b
        end
        local alt = (mode == "overlap") and "destination" or "overlap"
        ok, a, b = SpeakWithMode(alt, voiceID, payload, speakRate, volume, overlap)
        if ok then
            speakMode = alt
        end
        return ok, a, b
    end

    local ok, a, b = tryBoth(speakText)
    if not ok then
        ok, a, b = tryBoth(text)
    end
    if not ok then
        return false, nil
    end
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

local function TryBlizzardTtsStopSlash()
    if type(SlashCmdList) ~= "table" then
        return false
    end
    local keys = { "TEXTTOSPEECH", "TTS", "TextToSpeech" }
    for i = 1, #keys do
        local fn = SlashCmdList[keys[i]]
        if type(fn) == "function" then
            local ok = pcall(fn, "stop")
            if ok then
                return true
            end
        end
    end
    return false
end

function Compat.FlushSpeakText()
    flushGen = flushGen + 1
    local myFlush = flushGen

    local function purgePulse()
        if myFlush ~= flushGen then
            return
        end
        Compat.StopSpeakText()
        TryBlizzardTtsStopSlash()
        if C_VoiceChat and C_VoiceChat.SpeakText then
            local voiceID = Compat.GetTtsVoiceID()
            local mode = Compat.GetSpeakMode()
            if mode == "overlap" then
                pcall(C_VoiceChat.SpeakText, voiceID, " ", 0, 0, true)
            else
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
