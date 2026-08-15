local addon = Exploration

local function plainText(text)
    if not text or text == "" then return nil end
    local ok, out = pcall(string.format, "%s", text)
    if not ok or type(out) ~= "string" or out == "" then
        return nil
    end
    local okR, rebuilt = pcall(function()
        local parts = {}
        for i = 1, #out do
            parts[i] = string.char(out:byte(i, i))
        end
        return table.concat(parts)
    end)
    if okR and type(rebuilt) == "string" and rebuilt ~= "" then
        return rebuilt
    end
    return out
end

function addon:SystemMessage(text)
    text = plainText(text)
    if not text then return end

    -- Prefer Blizzard helpers so the line lands in chat frames that show System.
    if ChatFrameUtil and ChatFrameUtil.AddSystemMessage then
        local ok = pcall(ChatFrameUtil.AddSystemMessage, text)
        if ok then return end
    end
    if ChatFrameUtil and ChatFrameUtil.DisplaySystemMessageInPrimary then
        local ok = pcall(ChatFrameUtil.DisplaySystemMessageInPrimary, text)
        if ok then return end
    end
    if ChatFrame_DisplaySystemMessageInPrimary then
        local ok = pcall(ChatFrame_DisplaySystemMessageInPrimary, text)
        if ok then return end
    end

    local info = ChatTypeInfo and ChatTypeInfo.SYSTEM
    local r, g, b = 1.0, 1.0, 0.0
    local id
    if info then
        r = info.r or r
        g = info.g or g
        b = info.b or b
        id = info.id
    end

    local shown = false
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.AddMessage and frame:IsEventRegistered("CHAT_MSG_SYSTEM") then
            pcall(frame.AddMessage, frame, text, r, g, b, id)
            shown = true
        end
    end
    if not shown then
        local cf = _G.DEFAULT_CHAT_FRAME
        if cf and cf.AddMessage then
            pcall(cf.AddMessage, cf, text, r, g, b, id)
        else
            print(text)
        end
    end
end

local function resolveVoiceID()
    if C_TTSSettings and C_TTSSettings.GetVoiceOptionID then
        for _, scope in ipairs({ 0, 1, 2 }) do
            local ok, voiceID = pcall(C_TTSSettings.GetVoiceOptionID, scope)
            if ok and type(voiceID) == "number" and voiceID >= 0 then
                return voiceID
            end
        end
    end
    if C_VoiceChat and C_VoiceChat.GetTtsVoices then
        local ok, voices = pcall(C_VoiceChat.GetTtsVoices)
        if ok and type(voices) == "table" then
            for i = 1, #voices do
                local voice = voices[i]
                if type(voice) == "table" and voice.voiceID ~= nil then
                    return voice.voiceID
                end
            end
        end
    end
    return 0
end

local function ttsDestination(preferQueued)
    local dest = Enum and Enum.VoiceTtsDestination
    if preferQueued and dest and dest.QueuedLocalPlayback ~= nil then
        return dest.QueuedLocalPlayback
    end
    if dest and dest.LocalPlayback ~= nil then
        return dest.LocalPlayback
    end
    if dest and dest.QueuedLocalPlayback ~= nil then
        return dest.QueuedLocalPlayback
    end
    return preferQueued and 4 or 1
end

function addon:SpeakText(text)
    if not addon.data or not addon.data.settings or not addon.data.settings.tts then
        return
    end
    text = plainText(text)
    if not text or not (C_VoiceChat and C_VoiceChat.SpeakText) then
        return
    end

    local voiceID = resolveVoiceID()
    local ok = pcall(C_VoiceChat.SpeakText, voiceID, text, ttsDestination(true), 0, 100)
    if ok then return end
    C_Timer.After(0.05, function()
        pcall(C_VoiceChat.SpeakText, voiceID, text, ttsDestination(false), 0, 100)
    end)
end
