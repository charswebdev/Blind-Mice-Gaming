--[[
  BMG Unit Frames — speech wrapper
  Uses Accessibility Helper when present, then C_VoiceChat, then chat.
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Speech = UF.Speech or {}
local Speech = UF.Speech

function Speech.Say(text)
    if type(text) ~= "string" or text == "" then
        return
    end
    local profile = UF.DB and UF.DB.Get and UF.DB.Get()
    if profile and profile.speech and profile.speech.enabled == false then
        print("|cff66ccff[BMG Unit Frames]|r " .. text)
        return
    end
    if AccessibilityHelper and AccessibilityHelper.Speech and AccessibilityHelper.Speech.Say then
        AccessibilityHelper.Speech.Say(text, AccessibilityHelper.Speech.PRIORITY_STATUS or 2)
        return
    end
    if C_VoiceChat and C_VoiceChat.SpeakText then
        local dest = Enum and Enum.VoiceTtsDestination and Enum.VoiceTtsDestination.QueuedLocalPlayback or 4
        pcall(C_VoiceChat.SpeakText, 0, text, dest, 0, 100)
        return
    end
    print("|cff66ccff[BMG Unit Frames]|r " .. text)
end
