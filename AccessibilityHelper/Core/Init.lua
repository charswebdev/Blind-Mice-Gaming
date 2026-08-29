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
        if AH.Help and AH.Help.PrintCommands then
            AH.Help.PrintCommands()
        end
        return
    end
    if AH.Settings and AH.Settings.Toggle then
        AH.Settings.Toggle()
    else
        print("|cffff6600[Accessibility Helper]|r Settings module missing.")
    end
end

-- Dedicated command list (does not conflict with /ahelp settings).
SLASH_AHCMDS1 = "/ahcmds"
SlashCmdList["AHCMDS"] = function()
    if AH.Help and AH.Help.PrintCommands then
        AH.Help.PrintCommands()
    end
end

-- Toggle TomTom / Zygor arrow facing clock announcements.
SLASH_AHARROWFACING1 = "/aha"
SlashCmdList["AHARROWFACING"] = function()
    if AH.Facing and AH.Facing.ToggleArrowAnnounce then
        AH.Facing.ToggleArrowAnnounce()
    else
        print("|cffff6600[Accessibility Helper]|r Facing module missing.")
    end
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
    print("|cff00ff00[Accessibility Helper]|r v3.6.3 loaded. TTS: " .. tostring(mode) .. " · Interface: " .. iface)
    print("|cff00ff00[Accessibility Helper]|r |cff00ff00/ah|r settings · |cff00ff00/ahcmds|r · |cff00ff00/ahclear|r · |cff00ff00/ahstop|r · |cff00ff00/ahs|r")
end
