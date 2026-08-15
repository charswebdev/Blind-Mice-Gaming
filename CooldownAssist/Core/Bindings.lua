--[[
  Cooldown Assist — key bindings
  Header display name: "Cooldown Assist"
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Bindings = CA.Bindings or {}

-- Key Bindings UI header + names (matches Bindings.xml category).
_G.BINDING_HEADER_COOLDOWNASSIST = "Cooldown Assist"
_G.BINDING_NAME_COOLDOWNASSIST_OPENSETTINGS = "Open Cooldown Assist settings"
_G.BINDING_NAME_COOLDOWNASSIST_STOPSPEAK = "Stop speaking (TTS)"
_G.BINDING_NAME_COOLDOWNASSIST_CHECKREADY = "Read ready cooldowns (TTS)"
_G.BINDING_NAME_COOLDOWNASSIST_TESTSPEECH = "Test text to speech"

local function SayStub(msg)
    if CA.Speech and CA.Speech.Say then
        CA.Speech.Say(msg, CA.Speech.PRIORITY_LOW)
    else
        print("|cff66ccff[Cooldown Assist]|r " .. tostring(msg))
    end
end

function CooldownAssist_OpenSettingsBinding()
    if CA.Settings and CA.Settings.Toggle then
        CA.Settings.Toggle()
        return
    end
    SayStub("Settings not available.")
end

function CooldownAssist_StopSpeakBinding()
    if CA.Speech and CA.Speech.Stop then
        CA.Speech.Stop()
    end
end

function CooldownAssist_CheckReadyBinding()
    if CA.Ready and CA.Ready.Announce then
        CA.Ready.Announce()
        return
    end
    SayStub("Ready check unavailable.")
end

function CooldownAssist_TestSpeechBinding()
    if CA.Speech and CA.Speech.SpeakTest then
        CA.Speech.SpeakTest()
        return
    end
    SayStub("Speech module missing.")
end
