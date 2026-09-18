local addonName, LPL = ...

LPL.initError = nil
local initialized = false

function LPL_ToggleMainFrame()
    if not initialized then
        local ok, err = pcall(LPL.Initialize)
        if not ok then
            print("|cffff6060LPL Error:|r " .. tostring(err))
            return
        end
    end

    if LPL.initError then
        print("|cffff6060LPL Error:|r " .. tostring(LPL.initError))
        return
    end

    if not LPL.MainFrame or not LPL.MainFrame.frame then
        print("|cffff6060LPL:|r UI not initialized. Try |cffffcc00/reload|r.")
        return
    end

    LPL.MainFrame:Toggle()
end

_G.LPL_ToggleMainFrame = LPL_ToggleMainFrame

local function RegisterSlashCommand()
    SLASH_LPL1 = "/lpl"
    SlashCmdList["LPL"] = LPL_ToggleMainFrame
end

function LPL.Initialize()
    if initialized then
        return
    end

    LPL.DB:Initialize()
    LPL.Theme:InitFonts()
    LPL.Theme:InitClassColors()
    LPL.MainFrame:Create()
    if LPL.Minimap then
        LPL.Minimap:Create()
    end
    LPL.Theme:ApplyScale(LPL.DB:GetUI().scale)
    LPL.MainFrame:EnsureHidden()
    if LPL.ConditionWatcher and LPL.ConditionWatcher.Start then
        LPL.ConditionWatcher:Start()
    end

    initialized = true
    LPL.initError = nil
end

RegisterSlashCommand()

local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function()
    if LPL.DB and LPL.DB.SyncFromGlobal then
        LPL.DB:SyncFromGlobal()
    end
    if LPL.BuildStore and LPL.BuildStore.MigrateStorage then
        LPL.BuildStore:MigrateStorage()
    end
    if LPL.ActionBarStore and LPL.ActionBarStore.MigrateStorage then
        LPL.ActionBarStore:MigrateStorage()
    end
    if LPL.EquipmentStore and LPL.EquipmentStore.MigrateStorage then
        LPL.EquipmentStore:MigrateStorage()
    end
end)

local bootFrame = CreateFrame("Frame")
bootFrame:RegisterEvent("ADDON_LOADED")
bootFrame:SetScript("OnEvent", function(self, event, name)
    if name ~= addonName then
        return
    end
    self:UnregisterEvent("ADDON_LOADED")
    local ok, err = pcall(LPL.Initialize)
    if not ok then
        LPL.initError = err
        print("|cffff6060LPL Error:|r " .. tostring(err))
    end
end)

if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName) then
    local ok, err = pcall(LPL.Initialize)
    if not ok then
        LPL.initError = err
        print("|cffff6060LPL Error:|r " .. tostring(err))
    end
end
