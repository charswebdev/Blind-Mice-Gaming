--[[
  Accessibility Helper — speech queue + TTS (Phase 1.2–1.4)
  Lua 5.1 only.

  Single-flight engine (Part 1A): only one Blizzard utterance at a time.
  Flush lock (Part 1B): after clear/stop, mute new SpeakText ~1s so flush finishes.
  /tts stop (Part 1C): wired in Compat.FlushSpeakText.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Speech = AH.Speech or {}
local Speech = AH.Speech

-- Lower number = higher priority (spoken sooner).
Speech.PRIORITY_CRITICAL = 1 -- combat, UI errors
Speech.PRIORITY_STATUS = 2   -- player state
Speech.PRIORITY_NAV = 3      -- tooltips, waypoints, distance
Speech.PRIORITY_INFO = 4     -- profession, reputation, XP
Speech.PRIORITY_LOW = 5      -- help, tests, load lines

local queue = {}
local held = {} -- lines held during flush lock (CRITICAL / STATUS / NAV)
local speaking = false
local speakGen = 0
local lastSpoken = nil
local activeUtteranceID = nil
local activeSpeakGen = 0
local flushUntil = 0
local flushGen = 0

local CHUNK_MAX = 220
local GAP_SEC = 0.35
-- Long enough for StopSpeakingText pulses to drain Blizzard/SAPI mid-utterance.
local FLUSH_LOCK_SEC = 1.0
-- Conservative timer fallback if PLAYBACK_FINISHED is missing (avoids stacking).
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

--- Prefer shared ChatText strip so speech matches chat/feature cleaning.
local function StripMarkup(s)
    if AH.ChatText and AH.ChatText.ForSpeech then
        return AH.ChatText.ForSpeech(s)
    end
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

--- Split long text into SpeakText-sized chunks without cutting mid-word when possible.
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
    if not (AH.DB and AH.DB.IsChatEchoEnabled and AH.DB.IsChatEchoEnabled()) then
        return
    end
    print("|cff66ccff[Helper]|r " .. tostring(body))
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
    if AH.DB and AH.DB.GetTtsVolume then
        volume = AH.DB.GetTtsVolume()
    end
    local rate = 0
    if AH.DB and AH.DB.GetTtsRate then
        rate = AH.DB.GetTtsRate()
    end
    local voiceID = nil
    if AH.Compat and AH.Compat.GetTtsVoiceID then
        voiceID = AH.Compat.GetTtsVoiceID()
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
    if AH.Compat and AH.Compat.StopSpeakText then
        AH.Compat.StopSpeakText()
    end
end

local function FlushBlizzardTts()
    if AH.Compat and AH.Compat.FlushSpeakText then
        AH.Compat.FlushSpeakText()
    else
        StopEngineSoft()
    end
end

--- Begin flush lock: drop ALL new Say() traffic so /ahclear stays silent.
-- Explicit HoldPieces (e.g. /ahrepeat) still lands in held and plays after unlock.
local function BeginFlushLock()
    flushGen = flushGen + 1
    local myFlush = flushGen
    flushUntil = Now() + FLUSH_LOCK_SEC
    -- Do not wipe held here — ClearQueue already wiped; RepeatLast may HoldPieces after.
    if C_Timer and C_Timer.After then
        C_Timer.After(FLUSH_LOCK_SEC + 0.02, function()
            if myFlush ~= flushGen then
                return
            end
            for i = 1, #held do
                queue[#queue + 1] = held[i]
            end
            wipe(held)
            flushUntil = 0
            PumpQueue()
        end)
    else
        for i = 1, #held do
            queue[#queue + 1] = held[i]
        end
        wipe(held)
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
    if AH.DB and AH.DB.IsMasterEnabled and not AH.DB.IsMasterEnabled() then
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

    -- Single-flight: never overlap into Blizzard's buffer.
    local ok, utteranceID = false, nil
    if AH.Compat and AH.Compat.SpeakText then
        ok, utteranceID = AH.Compat.SpeakText(item.text, rate, volume, false, voiceID)
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

    -- Timer fallback if PLAYBACK_FINISHED never arrives for this utterance.
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

local function HoldPieces(pieces, priority)
    for i = 1, #pieces do
        held[#held + 1] = { text = pieces[i], p = priority }
    end
end

--- Interrupt current speech so CRITICAL can speak now (still single-flight after stop).
local function InterruptForCritical()
    speakGen = speakGen + 1
    activeSpeakGen = speakGen
    speaking = false
    activeUtteranceID = nil
    StopEngineSoft()
end

function Speech.ClearQueue()
    wipe(queue)
    wipe(held)
    speakGen = speakGen + 1
    activeSpeakGen = speakGen
    speaking = false
    activeUtteranceID = nil
    FlushBlizzardTts()
    BeginFlushLock()
end

--- Stop all TTS immediately (keybind / /ahstop).
function Speech.Stop()
    Speech.ClearQueue()
end

--- Flush queued TTS and stop current speech (slash /ahclear, also on reload).
-- @param quiet boolean|nil  if true, no chat confirmation
function Speech.ClearAnnouncementCache(quiet)
    local pending = #queue + #held
    Speech.ClearQueue()
    lastSpoken = nil
    if not quiet then
        local msg = "TTS announcements cleared."
        if pending > 0 then
            msg = string.format("TTS announcements cleared (%d queued).", pending)
        end
        -- Chat only — do not SpeakText here (would fight the flush lock).
        print("|cff66ccff[Helper]|r " .. msg)
    end
    return pending
end

--- Clear only NAV-priority items (tooltips / waypoints / facing) and stop current speech.
-- Soft-stop only — do NOT begin flush lock. Tooltip / waypoint keybinds call this
-- then immediately Say(); a flush lock would swallow that speech for ~1s.
function Speech.ClearNavQueue()
    local kept = {}
    for i = 1, #queue do
        if queue[i].p ~= Speech.PRIORITY_NAV then
            kept[#kept + 1] = queue[i]
        end
    end
    wipe(queue)
    for i = 1, #kept do
        queue[i] = kept[i]
    end
    local keptHeld = {}
    for i = 1, #held do
        if held[i].p ~= Speech.PRIORITY_NAV then
            keptHeld[#keptHeld + 1] = held[i]
        end
    end
    wipe(held)
    for i = 1, #keptHeld do
        held[i] = keptHeld[i]
    end
    speakGen = speakGen + 1
    activeSpeakGen = speakGen
    speaking = false
    activeUtteranceID = nil
    StopEngineSoft()
end

--- Drop queued NAV lines without interrupting a higher-priority utterance in progress.
function Speech.TrimNavQueue()
    local kept = {}
    for i = 1, #queue do
        if queue[i].p ~= Speech.PRIORITY_NAV then
            kept[#kept + 1] = queue[i]
        end
    end
    wipe(queue)
    for i = 1, #kept do
        queue[i] = kept[i]
    end
end

--- Re-speak the last full utterance (not individual chunks).
function Speech.RepeatLast()
    if type(lastSpoken) ~= "string" or lastSpoken == "" then
        Speech.Say("Nothing to repeat.", Speech.PRIORITY_LOW)
        return false
    end
    local text = lastSpoken
    Speech.ClearQueue()
    if AH.DB and AH.DB.IsMasterEnabled and not AH.DB.IsMasterEnabled() then
        return false
    end
    if AH.DB and AH.DB.IsChatEchoEnabled and AH.DB.IsChatEchoEnabled() then
        EchoToChat(text)
    end
    -- NAV is held across flush lock, then spoken.
    local pieces = Speech.ChunkText(text)
    HoldPieces(pieces, Speech.PRIORITY_NAV)
    return true
end

--- Enqueue plain text (will be stripped / chunked).
-- @param text string
-- @param priority number|nil
-- @param opts table|nil  { forceEcho = bool, noChunk = bool }
function Speech.Say(text, priority, opts)
    opts = opts or {}
    text = StripMarkup(text)
    if text == "" then
        return
    end
    if AH.DB and AH.DB.IsMasterEnabled and not AH.DB.IsMasterEnabled() then
        return
    end

    priority = priority or Speech.PRIORITY_INFO
    lastSpoken = text

    if opts.forceEcho or (AH.DB and AH.DB.IsChatEchoEnabled and AH.DB.IsChatEchoEnabled()) then
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

    if InFlushLock() then
        -- True silence after /ahclear / /ahstop — do not hold STATUS/NAV/CRITICAL
        -- (that was causing speech to resume right after clear).
        return
    end

    if priority == Speech.PRIORITY_CRITICAL then
        InterruptForCritical()
    end

    EnqueuePieces(pieces, priority)
    PumpQueue()
end

--- Immediate test utterance (used by /ahs).
function Speech.SpeakTest()
    local mode = AH.Compat.GetSpeakMode()
    local msg = "Accessibility Helper text to speech test. Speak mode " .. tostring(mode) .. "."
    Speech.ClearQueue()
    -- LOW would be dropped during flush lock — speak after unlock.
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
    print("|cff66ccff[Helper]|r TTS test sent (" .. tostring(mode) .. ").")
end

--- Preview sample at current (or overridden) voice/rate without using the speech queue.
function Speech.PreviewSample(text, rate, voiceID)
    if type(text) ~= "string" or text == "" then
        return
    end
    speakGen = speakGen + 1
    activeSpeakGen = speakGen
    speaking = false
    activeUtteranceID = nil
    wipe(queue)
    wipe(held)
    StopEngineSoft()

    local volume = 100
    if AH.DB and AH.DB.GetTtsVolume then
        volume = AH.DB.GetTtsVolume()
    end
    if type(rate) ~= "number" and AH.DB and AH.DB.GetTtsRate then
        rate = AH.DB.GetTtsRate()
    end
    rate = rate or 0
    if type(voiceID) ~= "number" and AH.Compat and AH.Compat.GetTtsVoiceID then
        voiceID = AH.Compat.GetTtsVoiceID()
    end
    -- Instant preview: interrupt current engine speech (overlap true on Midnight).
    if AH.Compat and AH.Compat.SpeakText then
        speaking = true
        local myGen = speakGen
        activeSpeakGen = myGen
        local ok, utteranceID = AH.Compat.SpeakText(text, rate, volume, true, voiceID)
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

-- Advance queue when Blizzard finishes our utterance (single-flight).
local ttsEvents = CreateFrame("Frame")
ttsEvents:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FINISHED")
ttsEvents:RegisterEvent("VOICE_CHAT_TTS_PLAYBACK_FAILED")
ttsEvents:RegisterEvent("VOICE_CHAT_TTS_SPEAK_TEXT_UPDATE")
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

-- On load /reload, stop leftover Blizzard TTS and start empty.
Speech.ClearAnnouncementCache(true)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    Speech.ClearAnnouncementCache(true)
    self:UnregisterEvent("PLAYER_LOGIN")
end)
