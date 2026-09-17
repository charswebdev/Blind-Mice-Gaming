--[[
  BMG Unit Frames — bootstrap
  Author: Blind Mice Gaming
  Lua 5.1 only.
]]

local ADDON_NAME = ...

BMGUF = BMGUF or {}
local UF = BMGUF

function UF.ApplyProfile(profile)
    if UF.Config and UF.Config.Refresh then
        UF.Config.Refresh()
    end
    if UF.Frames and UF.Frames.Apply then
        UF.Frames.Apply(profile)
    end
end

local function PrintHelp()
    print("|cff00ff00[BMG Unit Frames]|r Commands:")
    print("|cff00ff00/bmguf|r open or close the settings window")
    print("|cff00ff00/bmguf save Name|r save the current layout as a named profile")
    print("|cff00ff00/bmguf load Name|r switch this character to that profile")
    print("|cff00ff00/bmguf profiles|r list saved profiles")
    print("|cff00ff00/bmguf export|r create a shareable layout code")
    print("|cff00ff00/bmguf import CODE|r apply a pasted layout code")
    print("|cff00ff00/bmguf lock|r or |cff00ff00unlock|r frames")
    print("|cff00ff00/bmguf reset|r restore the Default profile")
    print("|cff00ff00/bmguf read|r speak the current target")
    print("|cff00ff00/bmguf read player|r speak a named unit")
    print("|cff00ff00/bmguf snap|r place frames on your current Blizzard positions")
    print("|cff00ff00Key Bindings|r → BMG Unit Frames → Open settings")
end

local function HandleSlash(msg)
    msg = type(msg) == "string" and msg:gsub("^%s+", ""):gsub("%s+$", "") or ""
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        UF.Config.Toggle()
        return
    end
    if cmd == "help" or cmd == "cmds" or cmd == "?" then
        PrintHelp()
        UF.Speech.Say("Command list printed to chat.")
        return
    end
    if cmd == "save" then
        local ok, text = UF.DB.SaveAs(rest)
        UF.Speech.Say(text)
        print((ok and "|cff00ff00" or "|cffff6600") .. "[BMG Unit Frames]|r " .. text)
        UF.Config.Refresh()
        return
    end
    if cmd == "load" then
        local ok, text = UF.DB.Switch(rest)
        UF.Speech.Say(text)
        print((ok and "|cff00ff00" or "|cffff6600") .. "[BMG Unit Frames]|r " .. text)
        UF.Config.Refresh()
        return
    end
    if cmd == "profiles" then
        local names = UF.DB.ListProfiles()
        print("|cff00ff00[BMG Unit Frames]|r Profiles: " .. table.concat(names, ", "))
        UF.Speech.Say("Profiles. " .. table.concat(names, ". "))
        return
    end
    if cmd == "export" then
        UF.Config.ShowExport()
        return
    end
    if cmd == "import" then
        local ok, text = UF.Share.Import(rest)
        UF.Speech.Say(text)
        print((ok and "|cff00ff00" or "|cffff6600") .. "[BMG Unit Frames]|r " .. text)
        UF.Config.Refresh()
        return
    end
    if cmd == "lock" then
        UF.DB.Get().locked = true
        UF.Speech.Say("Frames locked.")
        UF.ApplyProfile(UF.DB.Get())
        return
    end
    if cmd == "unlock" then
        if UF.Compat.InCombat() then
            UF.Speech.Say("Frames are locked in combat.")
            return
        end
        UF.DB.Get().locked = false
        UF.Speech.Say("Frames unlocked.")
        UF.ApplyProfile(UF.DB.Get())
        return
    end
    if cmd == "reset" then
        UF.DB.Switch("Default")
        UF.Speech.Say("Default profile loaded.")
        UF.ApplyProfile(UF.DB.Get())
        UF.Config.Refresh()
        return
    end
    if cmd == "read" then
        if UF.Frames and UF.Frames.Read then
            UF.Frames.Read(rest ~= "" and rest or "target")
        end
        return
    end
    if cmd == "snap" then
        if UF.Compat.InCombat() then
            UF.Speech.Say("Frames are locked in combat.")
            return
        end
        UF.DB.CaptureAndMaybeSnap(true)
        UF.ApplyProfile(UF.DB.Get())
        UF.Speech.Say("Frames moved to your current UI positions.")
        return
    end
    PrintHelp()
end

SLASH_BMGUNITFRAMES1 = "/bmguf"
SLASH_BMGUNITFRAMES2 = "/uf"
SlashCmdList["BMGUNITFRAMES"] = HandleSlash

local function Start()
    UF.Compat.Detect()
    UF.DB.CaptureAndMaybeSnap(false)
    UF.Frames.Create()
    UF.Frames.Apply(UF.DB.Get())
    if UF.HideBlizzard and UF.HideBlizzard.Apply then
        UF.HideBlizzard.Apply()
    end
    local iface = UF.Compat.interface or "?"
    local title = (UF.Flavor and UF.Flavor.title) or "BMG Unit Frames"
    print("|cff00ff00[" .. title .. "]|r v1.1.0 loaded. Interface: " .. tostring(iface))
    print("|cff00ff00[" .. title .. "]|r |cff00ff00/bmguf|r settings · Key Bindings: Open settings")
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("PLAYER_REGEN_ENABLED")
boot:RegisterEvent("PLAYER_TARGET_CHANGED")
boot:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON_NAME then
        UF.DB.Init()
    elseif event == "PLAYER_LOGIN" then
        if UF.Compat.InCombat() then
            UF.Frames.pendingCreate = true
            return
        end
        Start()
    elseif event == "PLAYER_ENTERING_WORLD" then
        if UF.HideBlizzard and UF.HideBlizzard.Apply then
            UF.HideBlizzard.Apply()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if UF.Frames and UF.Frames.pendingCreate then
            UF.Frames.pendingCreate = nil
            Start()
        elseif UF.Frames and UF.Frames.pendingApply then
            UF.Frames.pendingApply = nil
            UF.Frames.Apply(UF.DB.Get())
        end
        if UF.HideBlizzard and UF.HideBlizzard.Apply then
            UF.HideBlizzard.Apply()
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        local profile = UF.DB and UF.DB.Get and UF.DB.Get()
        if profile and profile.speech and profile.speech.targetChange then
            if UF.Frames and UF.Frames.Read then
                if UnitExists and UnitExists("target") then
                    UF.Frames.Read("target")
                else
                    UF.Speech.Say("Target cleared.")
                end
            end
        end
    end
end)
