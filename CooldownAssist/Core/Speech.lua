--[[
  Cooldown Assist — own TTS queue (does not use Accessibility Helper speech)
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Speech = CA.Speech or {}
local Speech = CA.Speech

Speech.PRIORITY_CRITICAL = 1
Speech.PRIORITY_STATUS = 2
Speech.PRIORITY_INFO = 3
Speech.PRIORITY_LOW = 4

local queue = {}
local speaking = false
local speakGen = 0
local lastSpoken = nil
local activeUtteranceID = nil
local activeSpeakGen = 0
local flushUntil = 0
local flushGen = 0

local CHUNK_MAX = 220
local GAP_SEC = 0.35
local FLUSH_LOCK_SEC = 1.0
local CHAR_SEC = 0.055

local function Now()
    return (GetTime and GetTime()) or 0
end

local function Trim(s)
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function StripMarkup(s)
    s = Trim(s)
    if s == "" then
        return ""
    end
    s = s:gsub("|T.-|t", " ")
    s = s:gsub("|A.-|a", " ")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("|n", " ")
    s = s:gsub("%s+", " ")
    return Trim(s)
end

function Speech.ChunkText(text)
    text = StripMarkup(text)
    if text == "" then
        return {}
    end
    if #text <= CHUNK_MAX then
        return { text }
    end
    local chunks = {}
    local rest = text
    while #rest > CHUNK_MAX do
        local slice = rest:sub(1, CHUNK_MAX)
        local breakAt = slice:match(".*()[%s%p]") or CHUNK_MAX
        if breakAt < math.floor(CHUNK_MAX * 0.5) then
            breakAt = CHUNK_MAX
        end
        chunks[#chunks + 1] = Trim(rest:sub(1, breakAt))
        rest = Trim(rest:sub(breakAt + 1))
    end
    if rest ~= "" then
        chunks[#chunks + 1] = rest
    end
    return chunks
end

local function EchoToChat(body)
    if not (CA.DB and CA.DB.IsChatEchoEnabled and CA.DB.IsChatEchoEnabled()) then
        return
    end
    print("|cff66ccff[Cooldown Assist]|r " .. tostring(body))
end

local function InFlushLock()
    return Now() < flushUntil
end

local function EstimateDelay(text, rate)
    rate = rate or 0
    local rateFactor = 1.0 - (rate * 0.055)
    if rateFactor < 0.4 then
        rateFactor = 0.4
    end
    return GAP_SEC + math.min(12, math.max(0.6, #text * CHAR_SEC * rateFactor))
end

local function GetVoiceParams()
    local volume = 100
    if CA.DB and CA.DB.GetTtsVolume then
        volume = CA.DB.GetTtsVolume()
    end
    local rate = 0
    if CA.DB and CA.DB.GetTtsRate then
        rate = CA.DB.GetTtsRate()
    end
    local voiceID = nil
    if CA.Compat and CA.Compat.GetTtsVoiceID then
        voiceID = CA.Compat.GetTtsVoiceID()
    end
    return rate, volume, voiceID
end

local PumpQueue

local function FinishUtterance(myGen, utteranceID)
    if myGen ~= speakGen then
        return
    end
    if not speaking then
        return
    end
    if utteranceID ~= nil and activeUtteranceID ~= nil and utteranceID ~= activeUtteranceID then
        return
    end
    speaking = false
    activeUtteranceID = nil
    PumpQueue()
end

local function StopEngineSoft()
    if CA.Compat and CA.Compat.StopSpeakText then
        CA.Compat.StopSpeakText()
    end
end

local function FlushBlizzardTts()
    if CA.Compat and CA.Compat.FlushSpeakText then
        CA.Compat.FlushSpeakText()
    else
        StopEngineSoft()
    end
end

local function BeginFlushLock()
    flushGen = flushGen + 1
    local myFlush = flushGen
    flushUntil = Now() + FLUSH_LOCK_SEC
    if C_Timer and C_Timer.After then
        C_Timer.After(FLUSH_LOCK_SEC + 0.02, function()
            if myFlush ~= flushGen then
                return
            end
            flushUntil = 0
            PumpQueue()
        end)
    else
        flushUntil = 0
    end
end

PumpQueue = function()
    if InFlushLock() then
        return
    end
    if speaking then
        return
    end
    if #queue == 0 then
        return
    end
    if CA.DB and CA.DB.IsMasterEnabled and not CA.DB.IsMasterEnabled() then
        wipe(queue)
        return
    end

    local bestIdx = 1
    for i = 2, #queue do
        if queue[i].p < queue[bestIdx].p then
            bestIdx = i
        end
    end
    local item = table.remove(queue, bestIdx)
    speaking = true
    activeUtteranceID = nil
    local myGen = speakGen
    activeSpeakGen = myGen
    local rate, volume, voiceID = GetVoiceParams()

    local ok, utteranceID = false, nil
    if CA.Compat and CA.Compat.SpeakText then
        ok, utteranceID = CA.Compat.SpeakText(item.text, rate, volume, false, voiceID)
    end
    if not ok then
        speaking = false
        activeUtteranceID = nil
        if C_Timer and C_Timer.After then
            C_Timer.After(0.05, function()
                if myGen == speakGen then
                    PumpQueue()
                end
            end)
        end
        return
    end
    if type(utteranceID) == "number" then
        activeUtteranceID = utteranceID
    end

    local delay = EstimateDelay(item.text, rate)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, function()
            FinishUtterance(myGen, nil)
        end)
    else
        speaking = false
    end
end

local function EnqueuePieces(pieces, priority)
    for i = 1, #pieces do
        queue[#queue + 1] = { text = pieces[i], p = priority }
    end
end

local function InterruptForCritical()
    speakGen = speakGen + 1
    activeSpeakGen = speakGen
    speaking = false
    activeUtteranceID = nil
    StopEngineSoft()
end

function Speech.ClearQueue()
    wipe(queue)
    speakGen = speakGen + 1
    activeSpeakGen = speakGen
    speaking = false
    activeUtteranceID = nil
    FlushBlizzardTts()
    BeginFlushLock()
end

function Speech.Stop()
    Speech.ClearQueue()
end

function Speech.ClearAnnouncementCache(quiet)
    local pending = #queue
    Speech.ClearQueue()
    lastSpoken = nil
    if not quiet then
        local msg = "TTS announcements cleared."
        if pending > 0 then
            msg = string.format("TTS announcements cleared (%d queued).", pending)
        end
        print("|cff66ccff[Cooldown Assist]|r " .. msg)
    end
    return pending
end

function Speech.RepeatLast()
    if type(lastSpoken) ~= "string" or lastSpoken == "" then
        Speech.Say("Nothing to repeat.", Speech.PRIORITY_LOW)
        return false
    end
    Speech.Say(lastSpoken, Speech.PRIORITY_INFO)
    return true
end

function Speech.Say(text, priority, opts)
    opts = opts or {}
    text = StripMarkup(text)
    if text == "" then
        return
    end
    if CA.DB and CA.DB.IsMasterEnabled and not CA.DB.IsMasterEnabled() then
        return
    end

    priority = priority or Speech.PRIORITY_INFO
    lastSpoken = text

    if opts.forceEcho or (CA.DB and CA.DB.IsChatEchoEnabled and CA.DB.IsChatEchoEnabled()) then
        EchoToChat(text)
    end

    local pieces
    if opts.noChunk then
        pieces = { text }
    else
        pieces = Speech.ChunkText(text)
    end
    if #pieces == 0 then
        return
    end

    if priority == Speech.PRIORITY_CRITICAL then
        InterruptForCritical()
    end

    -- During flush lock, keep the line queued; PumpQueue resumes when the lock ends.
    EnqueuePieces(pieces, priority)
    if not InFlushLock() then
        PumpQueue()
    end
end

function Speech.SpeakTest()
    local mode = CA.Compat and CA.Compat.GetSpeakMode and CA.Compat.GetSpeakMode() or "unknown"
    local msg = "Cooldown Assist text to speech test. Speak mode " .. tostring(mode) .. "."
    Speech.ClearQueue()
    local myFlush = flushGen
    if C_Timer and C_Timer.After then
        C_Timer.After(FLUSH_LOCK_SEC + 0.05, function()
            if myFlush ~= flushGen then
                return
            end
            Speech.Say(msg, Speech.PRIORITY_LOW)
        end)
    else
        Speech.Say(msg, Speech.PRIORITY_LOW)
    end
    print("|cff66ccff[Cooldown Assist]|r TTS test sent (" .. tostring(mode) .. ").")
end

function Speech.PreviewSample(text, rate, voiceID)
    if type(text) ~= "string" or text == "" then
        return
    end
    speakGen = speakGen + 1
    activeSpeakGen = speakGen
    speaking = false
    activeUtteranceID = nil
    wipe(queue)
    StopEngineSoft()

    local volume = 100
    if CA.DB and CA.DB.GetTtsVolume then
        volume = CA.DB.GetTtsVolume()
    end
    if type(rate) ~= "number" and CA.DB and CA.DB.GetTtsRate then
        rate = CA.DB.GetTtsRate()
    end
    rate = rate or 0
    if type(voiceID) ~= "number" and CA.Compat and CA.Compat.GetTtsVoiceID then
        voiceID = CA.Compat.GetTtsVoiceID()
    end
    if CA.Compat and CA.Compat.SpeakText then
        speaking = true
        local myGen = speakGen
        activeSpeakGen = myGen
        local ok, utteranceID = CA.Compat.SpeakText(text, rate, volume, true, voiceID)
        if ok and type(utteranceID) == "number" then
            activeUtteranceID = utteranceID
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(EstimateDelay(text, rate), function()
                FinishUtterance(myGen, nil)
            end)
        else
            speaking = false
        end
    end
end

local ttsEvents = CreateFrame("Frame")
local function SafeReg(ev)
    if CA.Compat and CA.Compat.SafeRegisterEvent then
        CA.Compat.SafeRegisterEvent(ttsEvents, ev)
    else
        pcall(ttsEvents.RegisterEvent, ttsEvents, ev)
    end
end
SafeReg("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
SafeReg("VOICE_CHAT_TTS_PLAYBACK_FAILED")
SafeReg("VOICE_CHAT_TTS_SPEAK_TEXT_UPDATE")
ttsEvents:SetScript("OnEvent", function(_, event, ...)
    if event == "VOICE_CHAT_TTS_SPEAK_TEXT_UPDATE" then
        local status, utteranceID = ...
        local success = 0
        if Enum and Enum.VoiceTtsStatusCode and Enum.VoiceTtsStatusCode.Success ~= nil then
            success = Enum.VoiceTtsStatusCode.Success
        end
        if status == success and type(utteranceID) == "number" and speaking then
            activeUtteranceID = utteranceID
        end
        return
    end
    if event == "VOICE_CHAT_TTS_PLAYBACK_FINISHED" or event == "VOICE_CHAT_TTS_PLAYBACK_FAILED" then
        local utteranceID = ...
        FinishUtterance(activeSpeakGen, utteranceID)
    end
end)

Speech.ClearAnnouncementCache(true)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    Speech.ClearAnnouncementCache(true)
    self:UnregisterEvent("PLAYER_LOGIN")
end)
