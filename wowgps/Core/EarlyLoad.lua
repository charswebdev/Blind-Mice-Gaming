local addonName, ns = ...

ns.addonName = addonName

local WowGPS = LibStub("AceAddon-3.0"):NewAddon(addonName, "AceEvent-3.0", "AceConsole-3.0")
_G.WowGPS = WowGPS

SLASH_WOWGPS1 = "/gps"
SLASH_WOWGPS2 = "/wowgps"
SlashCmdList["WOWGPS"] = function(input)
    if WowGPS and WowGPS.SlashHandler then
        WowGPS:SlashHandler(input or "")
        return
    end

    local msg = "|cffFF4444WowGPS|r failed to load."
    if WowGPS and WowGPS.initError then
        msg = msg .. " " .. tostring(WowGPS.initError)
    else
        msg = msg .. " Enable WowGPS on the character select AddOns screen, then |cffFFFF00/reload|r."
    end

    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(msg)
    end
end
