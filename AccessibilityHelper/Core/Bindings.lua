--[[
  Accessibility Helper — bindings contract (Phase 3)
  Preserved binding IDs must never change.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Bindings = AH.Bindings or {}
local Bindings = AH.Bindings

-- Display names for Key Bindings UI.
_G.BINDING_HEADER_ACCESSIBILITYHELPER = "Accessibility Helper"
_G.BINDING_NAME_ACCESSIBILITYHELPER_READTOOLTIP = "Read hovered tooltip (TTS)"
_G["BINDING_NAME_CLICK AccessibilityHelperTomTomReadBindProxy:LeftButton"] = "Read TomTom waypoint distance (TTS)"
_G["BINDING_NAME_CLICK AccessibilityHelperZygorReadBindProxy:LeftButton"] = "Read Zygor waypoint arrow (TTS)"
_G.BINDING_NAME_ACCESSIBILITYHELPER_OPENSETTINGS = "Open Accessibility Helper settings"
_G.BINDING_NAME_ACCESSIBILITYHELPER_TARGETDISTANCE = "Read target distance (TTS)"
_G.BINDING_NAME_ACCESSIBILITYHELPER_READTARGET = "Read target (TTS)"
_G.BINDING_NAME_ACCESSIBILITYHELPER_STOPSPEAK = "Stop speaking (TTS)"
_G.BINDING_NAME_ACCESSIBILITYHELPER_REPEATLAST = "Repeat last speech (TTS)"
_G.BINDING_NAME_ACCESSIBILITYHELPER_READQUESTOBJECTIVES = "Read quest objectives (TTS)"
_G.BINDING_NAME_ACCESSIBILITYHELPER_READQUESTWINDOW = "Read quest window (TTS)"

local function SayStub(msg)
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_LOW)
    else
        print("|cff66ccff[Accessibility Helper]|r " .. tostring(msg))
    end
end

-- Preserved: tooltip keybind entry point.
function AccessibilityHelper_ReadTooltipBinding()
    if AH.Tooltips and AH.Tooltips.ReadHovered then
        AH.Tooltips.ReadHovered()
        return
    end
    SayStub("Tooltip reader unavailable.")
end

-- Settings keybind.
function AccessibilityHelper_OpenSettingsBinding()
    if AH.Settings and AH.Settings.Toggle then
        AH.Settings.Toggle()
        return
    end
    SayStub("Settings not available.")
end

-- Target distance keybind.
function AccessibilityHelper_TargetDistanceBinding()
    if AH.Distance and AH.Distance.AnnounceTarget then
        AH.Distance.AnnounceTarget()
        return
    end
    SayStub("Target distance reader unavailable.")
end

function AccessibilityHelper_ReadTargetBinding()
    if AH.Facing and AH.Facing.ReadTarget then
        AH.Facing.ReadTarget()
        return
    end
    SayStub("Target reader unavailable.")
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
        return
    end
    SayStub("Repeat unavailable.")
end

function AccessibilityHelper_ReadQuestObjectivesBinding()
    if AH.Quests and AH.Quests.ReadObjectives then
        AH.Quests.ReadObjectives()
        return
    end
    SayStub("Quest objectives reader unavailable.")
end

function AccessibilityHelper_ReadQuestWindowBinding()
    if AH.Quests and AH.Quests.ReadWindow then
        AH.Quests.ReadWindow()
        return
    end
    SayStub("Quest window reader unavailable.")
end

local function EnsureSecureProxy(frameName, macrotext)
    local btn = _G[frameName]
    if btn then
        return btn
    end
    btn = CreateFrame("Button", frameName, nil, "SecureActionButtonTemplate")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", macrotext)
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:Show()
    return btn
end

function Bindings.EnsureProxies()
    -- Preserved CLICK binding frame names — do not rename.
    EnsureSecureProxy("AccessibilityHelperTomTomReadBindProxy", "/ahtt")
    EnsureSecureProxy("AccessibilityHelperZygorReadBindProxy", "/ahz")
end

function Bindings.RegisterSlashStubs()
    SLASH_AHTOMTOM1 = "/ahtt"
    SLASH_AHTOMTOM2 = "/aharrow"
    SLASH_AHTOMTOM3 = "/ahtomtom"
    SlashCmdList["AHTOMTOM"] = function()
        if AH.Waypoints and AH.Waypoints.ReadTomTom then
            AH.Waypoints.ReadTomTom()
            return
        end
        SayStub("TomTom reader unavailable.")
    end

    SLASH_AHZYGOR1 = "/ahzygor"
    SLASH_AHZYGOR2 = "/ahz"
    SlashCmdList["AHZYGOR"] = function()
        if AH.Waypoints and AH.Waypoints.ReadZygor then
            AH.Waypoints.ReadZygor()
            return
        end
        SayStub("Zygor reader unavailable.")
    end

    SLASH_AHREADTIP1 = "/ahreadtip"
    SLASH_AHREADTIP2 = "/ahtip"
    SlashCmdList["AHREADTIP"] = function()
        AccessibilityHelper_ReadTooltipBinding()
    end

    SLASH_AHDISTANCE1 = "/ahdist"
    SLASH_AHDISTANCE2 = "/ahdistance"
    SlashCmdList["AHDISTANCE"] = function()
        AccessibilityHelper_TargetDistanceBinding()
    end

    SLASH_AHTARGET1 = "/ahtarget"
    SLASH_AHTARGET2 = "/ahrt"
    SlashCmdList["AHTARGET"] = function()
        AccessibilityHelper_ReadTargetBinding()
    end

    SLASH_AHSTOP1 = "/ahstop"
    SlashCmdList["AHSTOP"] = function()
        AccessibilityHelper_StopSpeakBinding()
    end

    SLASH_AHCLEAR1 = "/ahclear"
    SLASH_AHCLEAR2 = "/ahflush"
    SlashCmdList["AHCLEAR"] = function()
        if AH.Speech and AH.Speech.ClearAnnouncementCache then
            AH.Speech.ClearAnnouncementCache(false)
            return
        end
        AccessibilityHelper_StopSpeakBinding()
        print("|cff66ccff[Helper]|r TTS announcements cleared.")
    end

    SLASH_AHREPEAT1 = "/ahrepeat"
    SLASH_AHREPEAT2 = "/ahr"
    SlashCmdList["AHREPEAT"] = function()
        AccessibilityHelper_RepeatLastBinding()
    end

    SLASH_AHTARGETFACING1 = "/ahtf"
    SlashCmdList["AHTARGETFACING"] = function()
        if AH.Facing and AH.Facing.ToggleTargetAnnounce then
            AH.Facing.ToggleTargetAnnounce()
            return
        end
        SayStub("Target facing toggle unavailable.")
    end

    SLASH_AHQUESTOBJ1 = "/ahquest"
    SLASH_AHQUESTOBJ2 = "/ahqo"
    SLASH_AHQUESTOBJ3 = "/ahobjectives"
    SlashCmdList["AHQUESTOBJ"] = function()
        AccessibilityHelper_ReadQuestObjectivesBinding()
    end

    SLASH_AHQUESTWIN1 = "/ahqw"
    SLASH_AHQUESTWIN2 = "/ahquestwin"
    SlashCmdList["AHQUESTWIN"] = function()
        AccessibilityHelper_ReadQuestWindowBinding()
    end
end

Bindings.EnsureProxies()
Bindings.RegisterSlashStubs()
