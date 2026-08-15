--[[
  AllQuest — bootstrap
  Lua 5.1 only.
]]

local addonName = ...

AllQuest = AllQuest or {}
local AQ = AllQuest

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        if AQ.DB and AQ.DB.Merge then
            AQ.DB.Merge()
        end
    elseif event == "ADDON_LOADED" and arg1 ~= addonName then
        if AQ.Plugins and AQ.Plugins.OnExternalAddonLoaded then
            AQ.Plugins.OnExternalAddonLoaded(arg1)
        end
    elseif event == "PLAYER_LOGIN" then
        if AQ.Data and AQ.Data.DiscoverAndLoad then
            AQ.Data:DiscoverAndLoad()
        end
        if AQ.Plugins and AQ.Plugins.EnableAll then
            AQ.Plugins.EnableAll()
        end
        if AQ.HideBlizzard then
            AQ.HideBlizzard.Apply()
        end
        if AQ.Tracker then
            AQ.Tracker.Init()
        end
        if AQ.MinimapButton then
            AQ.MinimapButton.Update()
        end
        local flavor = AQ.Compat and AQ.Compat.GetFlavor and AQ.Compat.GetFlavor() or "?"
        AQ:Print("v" .. tostring(AQ.version) .. " loaded (" .. flavor .. "). /aq settings · /aqline journal · /aqtrack tracker")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
