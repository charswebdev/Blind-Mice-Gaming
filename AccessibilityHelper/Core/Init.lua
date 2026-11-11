--[[
  Accessibility Helper — bootstrap (Phase 9)
  Author: Blind Mice Gaming
  Lua 5.1 only.
]]

local ADDON_NAME = ...

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

if AH.DB and AH.DB.Merge then
    AH.DB.Merge()
end

-- TTS test
SLASH_AHHELPERTEST1 = "/ahs"
SlashCmdList["AHHELPERTEST"] = function()
    if AH.Speech and AH.Speech.SpeakTest then
        AH.Speech.SpeakTest()
    else
        print("|cffff6600[Accessibility Helper]|r Speech module missing.")
    end
end

-- Settings: /ah and /ahelp (locked). Optional: /ah cmds|commands|help → command list.
SLASH_AHSETTINGS1 = "/ah"
SLASH_AHSETTINGS2 = "/ahelp"
SlashCmdList["AHSETTINGS"] = function(msg)
    msg = type(msg) == "string" and msg:lower():gsub("^%s+", ""):gsub("%s+$", "") or ""
    if msg == "cmds" or msg == "commands" or msg == "help" or msg == "?" then
        if AH.Window and AH.Window.ShowCommands then
            AH.Window.ShowCommands()
        end
        return
    end
    if AH.Settings and AH.Settings.Toggle then
        AH.Settings.Toggle()
    else
        print("|cffff6600[Accessibility Helper]|r Settings module missing.")
    end
end

local function SayLow(msg)
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_LOW, { noEcho = true })
    end
end

function AccessibilityHelper_OpenSettingsBinding()
    if AH.Settings and AH.Settings.Toggle then
        AH.Settings.Toggle()
    end
end

function AccessibilityHelper_StopSpeakBinding()
    if AH.Speech and AH.Speech.Stop then
        AH.Speech.Stop()
        return
    end
    if AH.Speech and AH.Speech.ClearQueue then
        AH.Speech.ClearQueue()
    end
end

function AccessibilityHelper_RepeatLastBinding()
    if AH.Speech and AH.Speech.RepeatLast then
        AH.Speech.RepeatLast()
    end
end

function AccessibilityHelper_ReadUnderMouseBinding()
    SayLow("Text under the mouse is not read on this version.")
end

function AccessibilityHelper_TargetDistanceBinding()
    SayLow("Target distance is not read on this version.")
end

function AccessibilityHelper_ReadTargetBinding()
    SayLow("The target reader is not on this version.")
end

function AccessibilityHelper_ReadQuestObjectivesBinding()
    SayLow("This key is not reading objectives on this version.")
end

function AccessibilityHelper_ReadQuestWindowBinding()
    SayLow("This key is not reading the quest window on this version.")
end

SLASH_AHSTOP1 = "/ahstop"
SlashCmdList["AHSTOP"] = function()
    AccessibilityHelper_StopSpeakBinding()
end

SLASH_AHREPEAT1 = "/ahrepeat"
SLASH_AHREPEAT2 = "/ahr"
SlashCmdList["AHREPEAT"] = function()
    AccessibilityHelper_RepeatLastBinding()
end

SLASH_AHCLEAR1 = "/ahclear"
SlashCmdList["AHCLEAR"] = function()
    if AH.Speech and AH.Speech.ClearAnnouncementCache then
        AH.Speech.ClearAnnouncementCache(false)
        return
    end
    AccessibilityHelper_StopSpeakBinding()
end

do
    local mode = "unknown"
    local iface = "?"
    if AH.Compat and AH.Compat.GetSpeakMode then
        mode = AH.Compat.GetSpeakMode()
    end
    if AH.Compat and AH.Compat.GetInterfaceVersion then
        iface = tostring(AH.Compat.GetInterfaceVersion())
    elseif GetBuildInfo then
        iface = tostring(select(4, GetBuildInfo()) or "?")
    end
    print("|cff00ff00[Accessibility Helper - Retail]|r v3.7.3 loaded. TTS: " .. tostring(mode) .. " · Interface: " .. iface)
    print("|cff00ff00[Accessibility Helper - Retail]|r |cff00ff00/ah|r opens the new window.")
end
