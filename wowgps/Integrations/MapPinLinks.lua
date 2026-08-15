local _, ns = ...

local MapPinLinks = {}
ns.MapPinLinks = MapPinLinks

local DEBOUNCE_SECONDS = 1

function MapPinLinks:Init(addon)
    if self.initialized then
        return
    end
    self.initialized = true
    self.addon = addon
    self.lastRouteKey = nil
    self.lastRouteTime = 0

    if not self.setItemRefInstalled then
        self.setItemRefInstalled = true
        local origSetItemRef = SetItemRef
        _G.SetItemRef = function(link, text, button, chatFrame)
            if MapPinLinks:TryConsumeLink(link, text, button) then
                return
            end
            return origSetItemRef(link, text, button, chatFrame)
        end
    end

    self:RegisterWorldMapHandlerWhenReady()
end

function MapPinLinks:GetMode()
    if not ns.Database then
        return ns.Constants.MAP_PIN_CLICK.SHIFT
    end
    local profile = ns.Database:GetProfile()
    if profile.chatPinRouteMode then
        return ns.Constants.MAP_PIN_CLICK.ALWAYS
    end
    local mode = profile.routeOnMapPinClick
    if mode == ns.Constants.MAP_PIN_CLICK.OFF
        or mode == ns.Constants.MAP_PIN_CLICK.SHIFT
        or mode == ns.Constants.MAP_PIN_CLICK.ALWAYS then
        return mode
    end
    return ns.Constants.MAP_PIN_CLICK.SHIFT
end

function MapPinLinks:SetMode(mode)
    if not ns.Database then
        return false
    end
    if mode ~= ns.Constants.MAP_PIN_CLICK.OFF
        and mode ~= ns.Constants.MAP_PIN_CLICK.SHIFT
        and mode ~= ns.Constants.MAP_PIN_CLICK.ALWAYS then
        return false
    end
    ns.Database:GetProfile().routeOnMapPinClick = mode
    return true
end

function MapPinLinks:CleanLinkText(text)
    if not text or text == "" then
        return nil
    end

    local name = text:match("|h(.-)|h") or text
    name = name:gsub("|c%x%x%x%x%x%x%x%x", "")
    name = name:gsub("|r", "")
    name = name:gsub("|h", "")
    name = name:gsub("|H[^|]+|h", "")
    name = name:gsub("|A:[^|]+|a", "")
    name = name:gsub("[%[%]]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return nil
    end
    return name
end

function MapPinLinks:ShouldHandleClick(mode, button)
    if mode == ns.Constants.MAP_PIN_CLICK.OFF then
        return false
    end
    if button == "RightButton" then
        return false
    end
    if mode == ns.Constants.MAP_PIN_CLICK.ALWAYS then
        return true
    end
    return IsShiftKeyDown()
end

function MapPinLinks:IsWorldMapRouteModeActive()
    if not ns.Database then
        return false
    end
    return ns.Database:GetProfile().worldMapRouteMode == true
end

function MapPinLinks:IsChatPinRouteModeActive()
    if not ns.Database then
        return false
    end
    return ns.Database:GetProfile().chatPinRouteMode == true
end

function MapPinLinks:ToggleWorldMapRouteMode()
    if not ns.Database then
        return
    end
    local profile = ns.Database:GetProfile()
    profile.worldMapRouteMode = not profile.worldMapRouteMode
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local addon = self.addon or WowGPS
    if profile.worldMapRouteMode then
        addon:Print(L["BIND_WORLDMAP_ROUTE_ON"])
    else
        addon:Print(L["BIND_WORLDMAP_ROUTE_OFF"])
    end
    self:UpdateWorldMapHandler()
end

function MapPinLinks:ToggleChatPinRouteMode()
    if not ns.Database then
        return
    end
    local profile = ns.Database:GetProfile()
    profile.chatPinRouteMode = not profile.chatPinRouteMode
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local addon = self.addon or WowGPS
    if profile.chatPinRouteMode then
        addon:Print(L["BIND_CHAT_PIN_ROUTE_ON"])
    else
        addon:Print(L["BIND_CHAT_PIN_ROUTE_OFF"])
    end
end

function MapPinLinks:ShouldShowWorldMapHandler()
    if self:IsWorldMapRouteModeActive() then
        return true
    end
    return IsControlKeyDown() and not IsAltKeyDown()
end

function MapPinLinks:ShouldRouteWorldMapClick(button)
    if self:IsWorldMapRouteModeActive() then
        return button == "MiddleButton"
    end
    return button == "MiddleButton" and IsControlKeyDown() and not IsAltKeyDown()
end

function MapPinLinks:GetOpenWorldMapId()
    if not WorldMapFrame then
        return nil
    end
    local mapId = WorldMapFrame.mapID
    if not mapId or mapId == 0 then
        local map = WorldMapFrame.GetMap and WorldMapFrame:GetMap()
        mapId = map and map.GetMapID and map:GetMapID()
    end
    if not mapId or mapId == 0 then
        return nil
    end
    return mapId
end

function MapPinLinks:RegisterWorldMapHandlerWhenReady()
    if self.worldMapHandlerInstalled then
        return
    end
    if not WorldMapFrame or not WorldMapFrame.ScrollContainer then
        C_Timer.After(1, function()
            MapPinLinks:RegisterWorldMapHandlerWhenReady()
        end)
        return
    end
    self:InstallWorldMapHandler()
end

function MapPinLinks:InstallWorldMapHandler()
    if self.worldMapHandlerInstalled then
        return
    end
    self.worldMapHandlerInstalled = true

    local parent = WorldMapFrame.ScrollContainer
    local handler = CreateFrame("Frame", "WowGPSWorldMapClickHandler", parent)
    handler:SetAllPoints(parent)
    handler:Hide()
    handler:EnableMouse(true)
    handler:SetFrameStrata(parent:GetFrameStrata())
    handler:SetFrameLevel(parent:GetFrameLevel() + 20)
    self.worldMapHandler = handler

    handler:RegisterEvent("MODIFIER_STATE_CHANGED")
    handler:SetScript("OnEvent", function()
        MapPinLinks:UpdateWorldMapHandler()
    end)
    handler:SetScript("OnUpdate", function()
        MapPinLinks:UpdateWorldMapHandler()
    end)
    handler:SetScript("OnMouseUp", function(_, button)
        MapPinLinks:OnWorldMapClick(button)
    end)

    if WorldMapFrame.HookScript then
        WorldMapFrame:HookScript("OnShow", function()
            MapPinLinks:UpdateWorldMapHandler()
        end)
        WorldMapFrame:HookScript("OnHide", function()
            if MapPinLinks.worldMapHandler then
                MapPinLinks.worldMapHandler:Hide()
            end
        end)
    end

    self:UpdateWorldMapHandler()
end

function MapPinLinks:UpdateWorldMapHandler()
    local handler = self.worldMapHandler
    if not handler or not WorldMapFrame or not WorldMapFrame:IsShown() then
        if handler then
            handler:Hide()
        end
        return
    end

    if self:ShouldShowWorldMapHandler() then
        handler:Show()
        if handler.SetPassThroughButtons and not InCombatLockdown() then
            handler:SetPassThroughButtons("LeftButton", "RightButton", "Button4", "Button5")
        end
    else
        handler:Hide()
        if handler.SetPassThroughButtons and not InCombatLockdown() then
            handler:SetPassThroughButtons("LeftButton", "RightButton", "MiddleButton", "Button4", "Button5")
        end
    end
end

function MapPinLinks:OnWorldMapClick(button)
    if not self:ShouldRouteWorldMapClick(button) then
        return
    end
    if not WorldMapFrame or not WorldMapFrame:IsShown() then
        return
    end

    local mapId = self:GetOpenWorldMapId()
    local x, y = WorldMapFrame:GetNormalizedCursorPosition()
    if not mapId or not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
        return
    end

    local rawX = math.floor(x * 10000 + 0.5)
    local rawY = math.floor(y * 10000 + 0.5)
    local routeKey = string.format("wm:%d:%d:%d", mapId, rawX, rawY)
    local now = GetTime()
    if self.lastRouteKey == routeKey and (now - self.lastRouteTime) < DEBOUNCE_SECONDS then
        return
    end
    self.lastRouteKey = routeKey
    self.lastRouteTime = now

    local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapId)
    local zoneName = (mapInfo and mapInfo.name) or ("Map " .. tostring(mapId))
    local name = string.format("%s (%.1f, %.1f)", zoneName, x * 100, y * 100)

    local dest = ns.Destination:FromMapPin(mapId, rawX, rawY, name)
    if not dest then
        local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
        local addon = self.addon or WowGPS
        addon:Print(L["MAP_PIN_INVALID"])
        return
    end

    self:RouteToPin(dest, "MAP_CLICK_ROUTE_STARTED")
end

function MapPinLinks:ParseWorldMapLink(link)
    if not link then
        return nil
    end
    local linkType, mapIdStr, xStr, yStr = strsplit(":", link)
    if linkType ~= "worldmap" or not mapIdStr or not xStr or not yStr then
        return nil
    end
    local mapId = tonumber(mapIdStr)
    local rawX = tonumber(xStr)
    local rawY = tonumber(yStr)
    if not mapId or not rawX or not rawY then
        return nil
    end
    return mapId, rawX, rawY
end

function MapPinLinks:RouteToPin(dest, startedLocaleKey)
    local addon = self.addon or WowGPS
    if not addon.ready then
        addon:Bootstrap()
    end
    if not addon.ready then
        addon:Print("|cffFFCC00WowGPS|r could not start route. " .. (addon.initError or "Try /reload."))
        return false
    end

    local ok, err = ns.RouteTracker:Start(dest)
    if ok then
        if startedLocaleKey and dest and dest.name then
            local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
            local fmt = L[startedLocaleKey]
            if fmt then
                addon:Print(string.format(fmt, dest.name))
            end
        end
        return true
    end

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    if err and (err:match("^not_ready") or err:match("^zygor_not_ready")) then
        local msg = ns.ZygorTravel and ns.ZygorTravel:GetStatusMessage()
        addon:Print(msg or L["ROUTE_FAILED"])
    elseif err == "no_path" or err == "no_steps" then
        addon:Print(L["ROUTE_FAILED"])
    else
        addon:Print("|cffFF4444WowGPS:|r Route failed: " .. tostring(err))
    end
    return false
end

function MapPinLinks:TryConsumeLink(link, text, button)
    local mapId, rawX, rawY = self:ParseWorldMapLink(link)
    if not mapId then
        return false
    end

    local mode = self:GetMode()
    if not self:ShouldHandleClick(mode, button) then
        return false
    end

    local routeKey = string.format("%d:%d:%d", mapId, rawX, rawY)
    local now = GetTime()
    if self.lastRouteKey == routeKey and (now - self.lastRouteTime) < DEBOUNCE_SECONDS then
        return true
    end
    self.lastRouteKey = routeKey
    self.lastRouteTime = now

    local dest = ns.Destination:FromMapPin(mapId, rawX, rawY, self:CleanLinkText(text))
    if not dest then
        local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
        local addon = self.addon or WowGPS
        addon:Print(L["MAP_PIN_INVALID"])
        return true
    end

    self:RouteToPin(dest)
    return true
end

function MapPinLinks:GetModeLabel(mode)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    if mode == ns.Constants.MAP_PIN_CLICK.OFF then
        return L["MAP_PIN_MODE_OFF"]
    end
    if mode == ns.Constants.MAP_PIN_CLICK.ALWAYS then
        return L["MAP_PIN_MODE_ALWAYS"]
    end
    return L["MAP_PIN_MODE_SHIFT"]
end

function MapPinLinks:HandleSlash(modeArg)
    local addon = self.addon or WowGPS
    if not addon.ready then
        addon:Bootstrap()
    end
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    modeArg = (modeArg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

    if modeArg == "" then
        addon:Print(string.format(L["MAP_PIN_MODE_CURRENT"], self:GetModeLabel(self:GetMode())))
        addon:Print(L["MAP_PIN_MODE_USAGE"])
        addon:Print(L["MAP_CLICK_HINT"])
        if self:IsWorldMapRouteModeActive() then
            addon:Print(L["BIND_WORLDMAP_ROUTE_ON"])
        end
        if self:IsChatPinRouteModeActive() then
            addon:Print(L["BIND_CHAT_PIN_ROUTE_ON"])
        end
        return
    end

    if modeArg == ns.Constants.MAP_PIN_CLICK.OFF
        or modeArg == ns.Constants.MAP_PIN_CLICK.SHIFT
        or modeArg == ns.Constants.MAP_PIN_CLICK.ALWAYS then
        self:SetMode(modeArg)
        addon:Print(string.format(L["MAP_PIN_MODE_SET"], self:GetModeLabel(modeArg)))
        return
    end

    addon:Print(L["MAP_PIN_MODE_USAGE"])
end
