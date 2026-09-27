local addonName, LPL = ...

local ADDON = addonName or LPL.ADDON_NAME or "lpl-forever"
local announced = false

function LPL_ToggleMainFrame()
    if LPL.Talents and LPL.Talents.Toggle then
        LPL.Talents:Toggle()
    end
end

_G.LPL_ToggleMainFrame = LPL_ToggleMainFrame

SLASH_LPL1 = "/lpl"
SlashCmdList["LPL"] = LPL_ToggleMainFrame

local function Boot(countLoad)
    if countLoad then
        LPL.DB:Bind(true)
    else
        LPL.DB:Bind(false)
    end
    if not announced then
        announced = true
        local talents = (LPL.TalentAPI and LPL.TalentAPI:Available()) and "Talents ready." or "Talents are not available on this client."
        print("|cff00ff00[" .. LPL.TITLE .. "]|r v" .. LPL.VERSION .. " loaded. " .. talents .. " |cff00ff00/lpl|r")
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterEvent("CHARACTER_POINTS_CHANGED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then
            return
        end
        Boot(true)
    elseif event == "PLAYER_ENTERING_WORLD" then
        LPL.DB:Bind(false)
        if not announced then
            Boot(true)
        elseif LPL.Talents and LPL.Talents.OnWorld then
            LPL.Talents:OnWorld()
        end
    elseif event == "CHARACTER_POINTS_CHANGED" then
        if LPL.Talents and LPL.Talents.OnWorld then
            LPL.Talents:OnWorld()
        end
    elseif event == "PLAYER_LOGOUT" then
        LPL.DB:Bind(false)
    end
end)

if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(ADDON) then
    Boot(true)
end
