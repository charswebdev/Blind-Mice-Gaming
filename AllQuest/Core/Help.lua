--[[
  AllQuest — slash commands and help
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

BINDING_HEADER_ALLQUEST = "AllQuest"
_G["BINDING_NAME_ALLQUEST_TOGGLETRACKER"] = "Toggle tracker"
_G["BINDING_NAME_ALLQUEST_TOGGLEJOURNAL"] = "Toggle questline journal"
_G["BINDING_NAME_ALLQUEST_READFOCUS"] = "Read focused row"
_G["BINDING_NAME_ALLQUEST_OPENSETTINGS"] = "Open settings"

AQ.Help = AQ.Help or {}

function AQ.Help.PrintCommands()
    AQ:Print("/aq — settings")
    AQ:Print("/aqtrack — toggle tracker")
    AQ:Print("/aqline — toggle questline journal")
    AQ:Print("/aqread — read focused tracker or journal row")
    AQ:Print("/aqstop — stop speech")
    AQ:Print("/aqtomtom — TomTom waypoint for super-tracked quest")
    AQ:Print("/aqbtw — open super-tracked quest in BtWQuests")
    AQ:Print("Plugins: PetTracker, Battle Pet Completionist, RareScanner, SilverDragon, QuestCompletist, All The Things, Zygor, TomTom, Masque, BtWQuests.")
    AQ:Print("/aqdebug — data recorder")
    AQ:Print("Unlock the tracker to move it or drag the bottom-right corner to resize. Quest items appear outside the top-right.")
    AQ:Print("Hold Shift at an NPC to skip auto-accept and auto-turn-in.")
end

SLASH_ALLQUEST1 = "/aq"
SLASH_ALLQUEST2 = "/allquest"
SlashCmdList["ALLQUEST"] = function(msg)
    msg = AQ:Trim(msg or ""):lower()
    if msg == "track" or msg == "tracker" then
        AQ.Tracker.Toggle()
        return
    end
    if msg == "line" or msg == "journal" then
        AQ.Journal.Toggle()
        return
    end
    if msg == "read" then
        local jf = AQ.Journal.GetFrame and AQ.Journal.GetFrame()
        if jf and jf:IsShown() then
            AQ.Journal.ReadFocus()
        else
            AQ.Tracker.ReadFocus()
        end
        return
    end
    if msg == "help" or msg == "cmds" then
        AQ.Help.PrintCommands()
        return
    end
    AQ.Settings.Toggle()
end

SLASH_AQTRACK1 = "/aqtrack"
SlashCmdList["AQTRACK"] = function()
    AQ.Tracker.Toggle()
end

SLASH_AQLINE1 = "/aqline"
SLASH_AQLINE2 = "/aqjournal"
SlashCmdList["AQLINE"] = function()
    AQ.Journal.Toggle()
end

SLASH_AQREAD1 = "/aqread"
SlashCmdList["AQREAD"] = function()
    local jf = AQ.Journal.GetFrame and AQ.Journal.GetFrame()
    if jf and jf:IsShown() then
        AQ.Journal.ReadFocus()
    else
        AQ.Tracker.ReadFocus()
    end
end

SLASH_AQSTOP1 = "/aqstop"
SlashCmdList["AQSTOP"] = function()
    AQ.Speech.Stop()
end

SLASH_AQHELP1 = "/aqhelp"
SlashCmdList["AQHELP"] = function()
    AQ.Help.PrintCommands()
end

function AllQuest_ToggleTrackerBinding()
    if AQ.Tracker then
        AQ.Tracker.Toggle()
    end
end

function AllQuest_ToggleJournalBinding()
    if AQ.Journal then
        AQ.Journal.Toggle()
    end
end

function AllQuest_ReadFocusBinding()
    SlashCmdList["AQREAD"]()
end

function AllQuest_OpenSettingsBinding()
    if AQ.Settings then
        AQ.Settings.Open()
    end
end
