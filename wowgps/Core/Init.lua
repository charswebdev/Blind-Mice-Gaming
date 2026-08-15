local addonName, ns = ...

local WowGPS = _G.WowGPS or LibStub("AceAddon-3.0"):GetAddon(addonName, true)
if not WowGPS then
    error("WowGPS EarlyLoad.lua must load before Init.lua")
end

local LOCALE_APP = "WowGPS"

local function GetL()
    local aceLocale = LibStub("AceLocale-3.0", true)
    if not aceLocale then
        return {}
    end
    return aceLocale:GetLocale(LOCALE_APP, true) or {}
end

local function SafeLocale(key, fallback)
    local L = GetL()
    return L[key] or fallback or key
end

function WowGPS:OnInitialize()
    self.ready = false
    self.initError = nil

    self:RegisterChatCommand("gps", "SlashHandler")
    self:RegisterChatCommand("wowgps", "SlashHandler")

    self:RegisterEvent("ADDONS_UNLOADING", function()
        if ns.Database and ns.Database.addon then
            ns.Database:PersistAllState()
        end
    end)

    BINDING_HEADER_WOWGPS = "WOWGPS"
    BINDING_NAME_WOWGPS_TOGGLE = SafeLocale("BIND_TOGGLE", "Toggle WowGPS window")
    BINDING_NAME_WOWGPS_STEP_COMPLETE = SafeLocale("BIND_STEP_COMPLETE", "Mark step complete")
    BINDING_NAME_WOWGPS_STEP_BACK = SafeLocale("BIND_STEP_BACK", "Go back one step")
    BINDING_NAME_WOWGPS_WORLDMAP_ROUTE = SafeLocale("BIND_WORLDMAP_ROUTE", "Toggle world map click routing")
    BINDING_NAME_WOWGPS_CHAT_PIN_ROUTE = SafeLocale("BIND_CHAT_PIN_ROUTE", "Toggle chat map pin click routing")
end

function WowGPS:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    local ok, err = pcall(function()
        self:Bootstrap()
    end)
    if not ok and self.Print then
        self.initError = tostring(err)
        self:Print("|cffFF4444WowGPS|r failed during enable: " .. self.initError)
    end
end

function WowGPS:OnPlayerEnteringWorld()
    self:Bootstrap()
    if ns.MainFrame then
        ns.MainFrame:ApplyRestoredVisibility()
    end
end

function WowGPS:Bootstrap()
    if self.ready then
        return true
    end

    if self._bootstrapping then
        return false
    end

    self._bootstrapping = true
    local ok, err = pcall(function()
        self:SetupAddon()
    end)
    self._bootstrapping = false

    if ok then
        self.ready = true
        self.initError = nil
        if not self._announcedReady then
            self._announcedReady = true
            self:Print("|cff33CCFFWowGPS|r loaded. Type |cffFFFF00/gps|r to open navigation.")
            self:CheckZygorDependency()
        end
        return true
    end

    self.ready = false
    self.initError = tostring(err)
    self:Print("|cffFF4444WowGPS|r failed to initialize: " .. self.initError)
    return false
end

function WowGPS:CheckZygorDependency()
    if ns.ZygorTravel and ns.ZygorTravel:IsAvailable() then
        return
    end
    local msg = ns.ZygorTravel and ns.ZygorTravel:GetStatusMessage()
    if msg then
        self:Print("|cffFFCC00WowGPS:|r " .. msg)
    end
end

function WowGPS:SetupAddon()
    if not self._coreInitialized then
        ns.Database:Init(self)
        ns.FallbackArrow:Init()
        ns.RouteTracker:Init(self)
        ns.MainFrame:Init(self)

        pcall(function()
            if ns.MapRoute and ns.MapRoute.Init then
                ns.MapRoute:Init()
            end
        end)
        pcall(function()
            if ns.MapPinLinks and ns.MapPinLinks.Init then
                ns.MapPinLinks:Init(self)
            end
        end)

        if not self.ticker then
            self.ticker = CreateFrame("Frame")
            self.ticker:Hide()
            self.ticker:SetScript("OnUpdate", function(_, elapsed)
                ns.RouteTracker:OnTick(elapsed)
                ns.FallbackArrow:OnTick()
                ns.MapRoute:OnTick()
            end)
        end

        self._coreInitialized = true
    end

    if ns.RouteTracker then
        ns.RouteTracker:RestoreSession()
    end
    if ns.MainFrame then
        ns.MainFrame:RestoreSession()
    end
end

function WowGPS:StartTicker()
    if self.ticker then
        self.ticker:Show()
    end
end

function WowGPS:StopTicker()
    if self.ticker then
        self.ticker:Hide()
    end
end

function WowGPS:ToggleMainFrame()
    if not self.ready then
        self:Bootstrap()
    end

    if not self.ready or not ns.MainFrame.frame then
        local msg = "|cffFFCC00WowGPS|r is not fully loaded."
        if self.initError then
            msg = msg .. " Reason: " .. self.initError
        else
            msg = msg .. " Try |cffFFFF00/reload|r."
        end
        self:Print(msg)
        return
    end

    ns.MainFrame:Toggle()
end

function WowGPS:SlashHandler(input)
    input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")

    if input == "debug" then
        self:Print("addonName=" .. tostring(addonName))
        self:Print("ready=" .. tostring(self.ready))
        self:Print("frame=" .. tostring(ns.MainFrame and ns.MainFrame.frame ~= nil))
        if ns.Database and ns.Database.addon then
            self:Print("frameOpen(saved)=" .. tostring(ns.Database:GetFrameOpen()))
            self:Print("frameOpen(want)=" .. tostring(ns.MainFrame and ns.MainFrame._wantFrameOpen))
            self:Print("frameShown=" .. tostring(ns.MainFrame and ns.MainFrame.frame and ns.MainFrame.frame:IsShown()))
            self:Print("activeTab=" .. tostring(ns.Database:GetActiveTab()))
        end
        self:Print("initError=" .. tostring(self.initError))
        self:Print("MapPinLinks=" .. tostring(ns.MapPinLinks ~= nil))
        self:Print("Zygor=" .. tostring(_G.ZygorGuidesViewer ~= nil))
        self:Print("ZygorReady=" .. tostring(ns.ZygorTravel and ns.ZygorTravel:IsAvailable()))
        self:Print("TomTom=" .. tostring(TomTom ~= nil))
        self:Print("TomTomReady=" .. tostring(ns.TomTomIntegration and ns.TomTomIntegration:IsReady()))
        if ns.TomTomIntegration and ns.TomTomIntegration.waypointUid then
            self:Print("TomTomArrow=" .. tostring(ns.TomTomIntegration:ArrowIsActive()))
        end
        if ns.TravelRegions then
            local raw = ns.TravelRegions:GetRawPlayerMapId()
            local resolved = ns.TravelRegions:GetPlayerMapId()
            local player = ns.TravelRegions:GetPlayerMapCoords()
            self:Print("playerMapRaw=" .. tostring(raw) .. " (" .. tostring(ns.TravelRegions:GetMapName(raw)) .. ")")
            self:Print("playerMapResolved=" .. tostring(resolved) .. " (" .. tostring(ns.TravelRegions:GetMapName(resolved)) .. ")")
            if player then
                self:Print(string.format("playerCoords=%.3f, %.3f era=%s", player.x or 0, player.y or 0, tostring(player.era)))
            end
        end
        return
    end

    if input == "" or input == "toggle" then
        self:ToggleMainFrame()
        return
    end

    local cmd, rest = input:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or input:lower()
    rest = rest or ""

    if cmd == "save" then
        local name = rest:gsub("^%s+", "")
        if name == "" then
            self:Print("Usage: /gps save <name>")
            return
        end
        local ok = ns.CustomLocations:Save(name)
        if ok then
            self:Print("Saved: " .. name)
        end
        return
    end

    if cmd == "delete" then
        local dest = ns.CustomLocations:FindByName(rest)
        if dest then
            local id = dest.id:gsub("^custom:", "")
            ns.CustomLocations:Delete(id, dest.scope)
            self:Print("Deleted: " .. rest)
        end
        return
    end

    if cmd == "list" then
        for _, scope in ipairs({ "account", "character" }) do
            for _, record in ipairs(ns.CustomLocations:List(scope)) do
                local tags = table.concat(ns.CustomLocations:GetTags(record), ", ")
                if tags ~= "" then
                    self:Print(string.format("[%s] %s (%s)", tags, record.name, record.scope))
                else
                    self:Print(string.format("%s (%s)", record.name, record.scope))
                end
            end
        end
        return
    end

    if cmd == "export" then
        local dest = ns.CustomLocations:FindByName(rest)
        if dest then
            local id = dest.id:gsub("^custom:", "")
            local str = ns.CustomLocations:Export(id, dest.scope)
            if str then
                self:Print("Export: " .. str)
            end
        end
        return
    end

    if cmd == "import" then
        if rest ~= "" then
            local ok, _, count = ns.CustomLocations:Import(rest)
            if ok then
                count = tonumber(count) or 1
                self:Print(count > 1 and ("Imported " .. count .. " locations.") or "Imported.")
            else
                self:Print("Import failed.")
            end
        end
        return
    end

    if cmd == "end" or cmd == "cancel" then
        if ns.RouteTracker then
            ns.RouteTracker:End()
        end
        return
    end

    if cmd == "pin" then
        if ns.MapPinLinks then
            ns.MapPinLinks:HandleSlash(rest)
        end
        return
    end

    if not self.ready then
        self:Bootstrap()
    end

    if not self.ready then
        self:Print("|cffFFCC00WowGPS|r could not open search. " .. (self.initError or "Try /reload."))
        return
    end

    self:ToggleMainFrame()
    ns.MainFrame:SelectTab("search", false, false)
    ns.SearchTab.searchBox:SetText(input)
    ns.SearchTab:GoToQuery(input)
end

function WowGPS:ToggleWorldMapRouteMode()
    if ns.MapPinLinks then
        ns.MapPinLinks:ToggleWorldMapRouteMode()
    end
end

function WowGPS:ToggleChatPinRouteMode()
    if ns.MapPinLinks then
        ns.MapPinLinks:ToggleChatPinRouteMode()
    end
end

WowGPS.RouteTracker = ns.RouteTracker
