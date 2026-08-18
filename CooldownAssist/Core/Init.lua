--[[
  Cooldown Assist — bootstrap
  Author: Blind Mice Gaming
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.VERSION = "1.1.0"

if CA.DB and CA.DB.Merge then
    CA.DB.Merge()
end

local function Trim(msg)
    if type(msg) ~= "string" then
        return ""
    end
    return msg:gsub("^%s+", ""):gsub("%s+$", "")
end

local function Print(msg)
    print("|cff66ccff[Cooldown Assist]|r " .. tostring(msg))
end

local function HandleSlash(msg)
    local raw = Trim(msg)
    local lower = raw:lower()

    if lower == "" or lower == "settings" or lower == "config" or lower == "options" then
        if CA.Settings and CA.Settings.Toggle then
            CA.Settings.Toggle()
        else
            print("|cffff6600[Cooldown Assist]|r Settings module missing.")
        end
        return
    end

    if lower == "c" or lower == "check" or lower == "ready" then
        if CA.Ready and CA.Ready.Announce then
            CA.Ready.Announce()
        else
            Print("Ready check unavailable.")
        end
        return
    end

    if lower == "test" or lower == "tts" then
        if CA.Speech and CA.Speech.SpeakTest then
            CA.Speech.SpeakTest()
        else
            print("|cffff6600[Cooldown Assist]|r Speech module missing.")
        end
        return
    end

    if lower == "stop" then
        if CA.Speech and CA.Speech.Stop then
            CA.Speech.Stop()
        end
        Print("Speech stopped.")
        return
    end

    if lower == "clear" or lower == "flush" then
        if CA.Speech and CA.Speech.ClearAnnouncementCache then
            CA.Speech.ClearAnnouncementCache(false)
        end
        return
    end

    if lower == "cooldowns" or lower == "cds" or lower == "tracking" then
        if CA.Settings and CA.Settings.OpenCooldownsTab then
            CA.Settings.OpenCooldownsTab()
        elseif CA.Settings and CA.Settings.Toggle then
            CA.Settings.Toggle()
        end
        return
    end

    if lower == "profiles" or lower == "profile" then
        if CA.Settings and CA.Settings.OpenProfilesTab then
            CA.Settings.OpenProfilesTab()
        elseif CA.Settings and CA.Settings.Toggle then
            CA.Settings.Toggle()
        end
        return
    end

    local renameTo = raw:match("^[Rr][Ee][Nn][Aa][Mm][Ee]%s+(.+)$")
    if renameTo then
        renameTo = Trim(renameTo)
        local id = CA.Profiles and CA.Profiles.GetActiveId and CA.Profiles.GetActiveId()
        if not id then
            Print("No active profile to rename. Open /ca profiles and select one.")
            return
        end
        local ok, name = CA.Profiles.Rename(id, renameTo)
        if ok then
            Print("Renamed profile to " .. tostring(name) .. ".")
            if CA.Speech and CA.Speech.Say then
                CA.Speech.Say("Renamed profile to " .. tostring(name) .. ".", CA.Speech.PRIORITY_LOW)
            end
            if CA.Settings and CA.Settings.RefreshProfiles then
                CA.Settings.RefreshProfiles()
            end
        else
            Print("Could not rename profile.")
        end
        return
    end

    if lower == "scan" then
        if CA.Spells and CA.Spells.ScanAll then
            local added = CA.Spells.ScanAll({ heavy = true })
            if CA.Spells.RefreshPending then
                CA.Spells.RefreshPending()
            end
            Print("Refreshed watched cooldowns: " .. tostring(added) .. ".")
            if CA.Settings and CA.Settings.RefreshTrackers then
                CA.Settings.RefreshTrackers()
            end
        end
        return
    end

    if lower == "rebuild" then
        if CA.Spells and CA.Spells.RebuildDiscovery then
            local added = CA.Spells.RebuildDiscovery()
            Print("Forgot used cooldowns. Use abilities again to watch them. Restored: " .. tostring(added) .. ".")
            if CA.Speech and CA.Speech.Say then
                CA.Speech.Say("Watched cooldowns cleared.", CA.Speech.PRIORITY_LOW)
            end
        end
        return
    end

    if lower == "list" then
        if not (CA.Spells and CA.Spells.GetTrackedList) then
            Print("Spell tracker missing.")
            return
        end
        local list = CA.Spells.GetTrackedList()
        Print("Tracked spells: " .. tostring(#list))
        for i = 1, #list do
            local e = list[i]
            local state = e.enabled and "|cff00ff00ON|r" or "|cffff6600OFF|r"
            print(string.format("  %s %s (%d)%s", state, e.name, e.spellID, e.pending and " [cooling]" or ""))
        end
        return
    end

    local offName = lower:match("^off%s+(.+)$")
    if offName then
        if CA.Spells and CA.Spells.SetEnabled then
            local entry, err = CA.Spells.SetEnabled(offName, false)
            if err == "notfound" then
                Print("Spell not found: " .. offName)
            else
                Print((entry.name or offName) .. " tracking off.")
                if CA.Speech and CA.Speech.Say then
                    CA.Speech.Say((entry.name or "Spell") .. " tracking off.", CA.Speech.PRIORITY_LOW)
                end
                if CA.Settings and CA.Settings.RefreshTrackers then
                    CA.Settings.RefreshTrackers()
                end
            end
        end
        return
    end

    local onName = lower:match("^on%s+(.+)$")
    if onName then
        if CA.Spells and CA.Spells.SetEnabled then
            local entry, err = CA.Spells.SetEnabled(onName, true)
            if err == "notfound" then
                Print("Spell not found: " .. onName)
            else
                Print((entry.name or onName) .. " tracking on.")
                if CA.Speech and CA.Speech.Say then
                    CA.Speech.Say((entry.name or "Spell") .. " tracking on.", CA.Speech.PRIORITY_LOW)
                end
                if CA.Settings and CA.Settings.RefreshTrackers then
                    CA.Settings.RefreshTrackers()
                end
            end
        end
        return
    end

    if lower == "help" or lower == "cmds" or lower == "commands" or lower == "?" then
        if CA.Help and CA.Help.PrintCommands then
            CA.Help.PrintCommands()
        end
        return
    end

    if lower == "about" or lower == "version" or lower == "ver" then
        if CA.Help and CA.Help.PrintAbout then
            CA.Help.PrintAbout()
        else
            Print("Cooldown Assist v" .. tostring(CA.VERSION or "1.0.0"))
        end
        return
    end

    Print("Unknown command. Try |cff00ff00/ca help|r.")
end

SLASH_COOLDOWNASSIST1 = "/ca"
SLASH_COOLDOWNASSIST2 = "/cooldownassist"
SlashCmdList["COOLDOWNASSIST"] = HandleSlash

SLASH_COOLDOWNASSISTTEST1 = "/cas"
SlashCmdList["COOLDOWNASSISTTEST"] = function()
    HandleSlash("test")
end

do
    local mode = "unknown"
    local iface = "?"
    if CA.Compat and CA.Compat.GetSpeakMode then
        mode = CA.Compat.GetSpeakMode()
    end
    if CA.Compat and CA.Compat.GetInterfaceVersion then
        iface = tostring(CA.Compat.GetInterfaceVersion())
    elseif GetBuildInfo then
        iface = tostring(select(4, GetBuildInfo()) or "?")
    end
    print("|cff00ff00[Cooldown Assist]|r v1.1.0 loaded. TTS: " .. tostring(mode) .. " · Interface: " .. iface)
    print("|cff00ff00[Cooldown Assist]|r |cff00ff00/ca|r settings · |cff00ff00/ca c|r · |cff00ff00/ca about|r · |cff00ff00/cas|r test")
end
