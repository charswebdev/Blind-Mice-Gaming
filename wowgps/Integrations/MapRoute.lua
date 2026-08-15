local _, ns = ...

local MapRoute = {}
ns.MapRoute = MapRoute

local HBD = LibStub("HereBeDragons-2.0")

local busy = false
local hooksReady = false
local userWaypointActive = false
local activeRoute = nil

local CYAN = { 0, 0.92, 1, 1 }
local WHITE = { 1, 1, 1, 1 }
local BLACK = { 0, 0, 0, 1 }

local function safeCall(fn, ...)
    if not fn then
        return false
    end
    return pcall(fn, ...)
end

local function getMinimapEdgeDistance(angle, width, height)
    local hw = (width / 2) - 8
    local hh = (height / 2) - 8
    -- HBD angles use 0 = north; on the minimap that is +Y.
    local dirX = math.abs(math.sin(angle))
    local dirY = math.abs(math.cos(angle))
    if dirX < 0.001 then
        return hh
    end
    if dirY < 0.001 then
        return hw
    end
    return math.min(hw / dirX, hh / dirY)
end

local function bearingToMinimapOffset(angle, distance)
    return math.sin(angle) * distance, math.cos(angle) * distance
end

local function normalizeHBDAngle(deltaX, deltaYNorth)
    local angle = math.atan2(-deltaX, deltaYNorth)
    if angle > 0 then
        angle = math.pi * 2 - angle
    else
        angle = -angle
    end
    return angle
end

function MapRoute:GetTomTomBearing()
    local uid = ns.TomTomIntegration and ns.TomTomIntegration.waypointUid
    if not uid or not TomTom or not TomTom.GetDirectionToWaypoint then
        return nil
    end
    return TomTom:GetDirectionToWaypoint(uid)
end

function MapRoute:GetTomTomWaypointCoords()
    local uid = ns.TomTomIntegration and ns.TomTomIntegration.waypointUid
    if not uid or type(uid) ~= "table" then
        return nil
    end
    if uid.m and uid.x and uid.y then
        return uid.m, uid.x, uid.y
    end
    if uid[1] and uid[2] and uid[3] then
        return uid[1], uid[2], uid[3]
    end
    return nil
end

function MapRoute:GetTargetCoordsForOverlay(step, route)
    route = route or activeRoute

    local mapId, x, y = self:GetStepCoords(step, route and route.destination)
    if mapId and x and y then
        return mapId, x, y
    end

    mapId, x, y = self:GetTomTomWaypointCoords()
    if mapId then
        return mapId, x, y
    end

    if route and route.destination then
        return ns.Destination:NormalizeMapCoords(
            route.destination.mapId,
            route.destination.x,
            route.destination.y
        )
    end

    return nil
end

function MapRoute:GetNavTargetOnMap(displayMapId, step, route)
    route = route or activeRoute
    if not displayMapId or not step then
        return nil
    end

    local targetMap, x, y = self:GetStepCoords(step, route and route.destination)
    if not targetMap or not x or not y then
        return nil
    end

    if ns.MapCoords then
        targetMap, x, y = ns.MapCoords:ToDisplayMap(targetMap, x, y, displayMapId)
    end

    local tx, ty = self:GetCanvasXY(displayMapId, targetMap, x, y)
    if tx and ty then
        return tx, ty
    end

    if ns.MapCoords then
        local wx, wy = ns.MapCoords:ZoneToWorld(targetMap, x, y)
        if wx and wy then
            tx, ty = ns.MapCoords:WorldToMap(wx, wy, displayMapId)
            if tx and ty then
                return tx, ty
            end
        end
    end

    return nil
end

function MapRoute:GetPlanarBearingOnMap(displayMapId, targetMapId, targetX, targetY)
    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap or not displayMapId then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then
        return nil
    end

    local px, py = self:GetCanvasXY(displayMapId, playerMap, pos.x, pos.y)
    local tx, ty

    if targetMapId and targetX and targetY then
        tx, ty = self:GetCanvasXY(displayMapId, targetMapId, targetX, targetY)
    end

    if (not tx or not ty) and targetMapId and targetX and targetY and ns.MapCoords then
        local wx, wy = ns.MapCoords:ZoneToWorld(targetMapId, targetX, targetY)
        if wx and wy then
            tx, ty = ns.MapCoords:WorldToMap(wx, wy, displayMapId)
        end
    end

    if not px or not py or not tx or not ty then
        return nil
    end

    return normalizeHBDAngle(tx - px, py - ty)
end

function MapRoute:GetMinimapViewRadius()
    if C_Minimap and C_Minimap.GetViewRadius then
        local ok, radius = pcall(C_Minimap.GetViewRadius)
        if ok and radius and radius > 0 then
            return radius
        end
    end
    return nil
end

function MapRoute:UsesTomTom()
    return ns.TomTomIntegration and ns.TomTomIntegration:IsAvailable()
end

function MapRoute:ShouldUseBlizzardWaypoint()
    return not self:UsesTomTom()
end

function MapRoute:EnsureWorldOverlayFrames()
    if not WorldMapFrame or not WorldMapFrame.GetCanvas then
        return
    end

    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then
        return
    end

    if self.worldOverlay and self.worldCanvas == canvas then
        return
    end

    if self.worldOverlay then
        self.worldOverlay:SetParent(canvas)
        self.worldOverlay:SetAllPoints(canvas)
        self.worldCanvas = canvas
        return
    end

    local world = CreateFrame("Frame", "WowGPSWorldOverlay", canvas)
    world:SetAllPoints(canvas)
    world:SetFrameStrata("TOOLTIP")
    world:SetFrameLevel(canvas:GetFrameLevel() + 30)
    world:EnableMouse(false)
    world:Hide()

    self.worldOverlay = world
    self.worldCanvas = canvas
    self.worldLineBorder = world:CreateTexture(nil, "BACKGROUND")
    self.worldLineBorder:SetColorTexture(BLACK[1], BLACK[2], BLACK[3], BLACK[4])
    self.worldLine = world:CreateTexture(nil, "ARTWORK")
    self.worldLine:SetColorTexture(WHITE[1], WHITE[2], WHITE[3], WHITE[4])
    self.worldPinBorder = world:CreateTexture(nil, "OVERLAY")
    self.worldPinBorder:SetColorTexture(BLACK[1], BLACK[2], BLACK[3], BLACK[4])
    self.worldPin = world:CreateTexture(nil, "OVERLAY")
    self.worldPin:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], CYAN[4])
end

function MapRoute:EnsureMinimapOverlayFrames()
    if self.minimapOverlay or not Minimap then
        return
    end

    local mini = CreateFrame("Frame", "WowGPSMinimapOverlay", Minimap)
    mini:SetAllPoints()
    mini:SetFrameStrata("TOOLTIP")
    mini:SetFrameLevel(Minimap:GetFrameLevel() + 50)
    mini:EnableMouse(false)
    mini:Hide()

    self.minimapOverlay = mini
    self.miniLineBorder = mini:CreateTexture(nil, "BACKGROUND")
    self.miniLineBorder:SetColorTexture(BLACK[1], BLACK[2], BLACK[3], BLACK[4])
    self.miniLine = mini:CreateTexture(nil, "ARTWORK")
    self.miniLine:SetColorTexture(WHITE[1], WHITE[2], WHITE[3], WHITE[4])
    self.miniPinBorder = mini:CreateTexture(nil, "OVERLAY")
    self.miniPinBorder:SetColorTexture(BLACK[1], BLACK[2], BLACK[3], BLACK[4])
    self.miniPin = mini:CreateTexture(nil, "OVERLAY")
    self.miniPin:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], CYAN[4])
end

function MapRoute:EnsureOverlayFrames()
    self:EnsureWorldOverlayFrames()
    self:EnsureMinimapOverlayFrames()
end

function MapRoute:EnsureHooks()
    if hooksReady then
        return
    end
    hooksReady = true

    if WorldMapFrame then
        WorldMapFrame:HookScript("OnShow", function()
            MapRoute:EnsureWorldOverlayFrames()
            MapRoute:RefreshWorldOverlay()
        end)

        if type(WorldMapFrame.OnMapChanged) == "function" then
            hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
                MapRoute:EnsureWorldOverlayFrames()
                C_Timer.After(0, function()
                    MapRoute:RefreshWorldOverlay()
                end)
            end)
        end
    end
end

function MapRoute:Init()
    if self.eventFrame then
        return
    end

    self:EnsureOverlayFrames()
    self:EnsureHooks()

    self.eventFrame = CreateFrame("Frame")
    self.eventFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
    self.eventFrame:RegisterEvent("ZONE_CHANGED")
    self.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self.eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    self.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            MapRoute:EnsureOverlayFrames()
            MapRoute:EnsureHooks()
        end
        MapRoute:RefreshMinimapOverlay()
        if WorldMapFrame and WorldMapFrame:IsShown() then
            MapRoute:RefreshWorldOverlay()
        end
    end)
end

function MapRoute:EnsureMapLoaded(mapId)
    if not mapId or not C_Map or not C_Map.GetMapInfo then
        return
    end

    local info = C_Map.GetMapInfo(mapId)
    local guard = 0
    while info and guard < 16 do
        guard = guard + 1
        if C_Map.RequestPreloadMap then
            safeCall(C_Map.RequestPreloadMap, C_Map, info.mapID)
        end
        if not info.parentMapID or info.parentMapID == 0 then
            break
        end
        info = C_Map.GetMapInfo(info.parentMapID)
    end
end

function MapRoute:GetStepCoords(step, destFallback)
    if not step then
        return nil
    end

    if ns.SubStepResolver and ns.SubStepResolver.GetNavCoords then
        local mapId, x, y = ns.SubStepResolver:GetNavCoords(step)
        if mapId and x and y then
            return mapId, x, y
        end
    end

    local mapId = step.completionMapId or step.mapId
    local x = ns.Destination and ns.Destination:NormalizeUICoord(step.completionX or step.x)
    local y = ns.Destination and ns.Destination:NormalizeUICoord(step.completionY or step.y)
    if (not mapId or not x or not y) and destFallback then
        mapId, x, y = ns.Destination:NormalizeMapCoords(destFallback.mapId, destFallback.x, destFallback.y)
    end
    if not mapId or not x or not y then
        return nil
    end
    return mapId, x, y
end

function MapRoute:GetWorldCoords(step, destFallback)
    local mapId, x, y = self:GetStepCoords(step, destFallback)
    if not mapId then
        return nil
    end

    self:EnsureMapLoaded(mapId)
    local wx, wy, instance = HBD:GetWorldCoordinatesFromZone(x, y, mapId)
    if wx and wy and instance then
        return wx, wy, instance
    end
    return nil
end

function MapRoute:GetPlayerWorld()
    self:EnsureMapLoaded(C_Map.GetBestMapForUnit("player"))
    local wx, wy, instance = HBD:GetPlayerWorldPosition()
    if wx and wy and instance then
        return wx, wy, instance
    end

    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap then
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not pos then
        return nil
    end

    self:EnsureMapLoaded(playerMap)
    wx, wy, instance = HBD:GetWorldCoordinatesFromZone(pos.x, pos.y, playerMap)
    if wx and wy and instance then
        return wx, wy, instance
    end
    return nil
end

function MapRoute:GetBearingToStep(step, route)
    route = route or activeRoute

    local tomTomAngle = self:GetTomTomBearing()
    if tomTomAngle then
        return tomTomAngle
    end

    local targetMap, tx, ty = self:GetTargetCoordsForOverlay(step, route)
    if targetMap and tx and ty then
        local playerMap = C_Map.GetBestMapForUnit("player")
        if playerMap then
            local planar = self:GetPlanarBearingOnMap(playerMap, targetMap, tx, ty)
            if planar then
                return planar
            end
        end
    end

    local px, py, pinst = HBD:GetPlayerWorldPosition()
    if not px or not py or not pinst then
        px, py, pinst = self:GetPlayerWorld()
    end
    if not px then
        return nil
    end

    if not targetMap then
        targetMap, tx, ty = self:GetTargetCoordsForOverlay(step, route)
    end
    if not targetMap or not tx or not ty then
        return nil
    end

    self:EnsureMapLoaded(targetMap)
    local wx, wy, tinst = HBD:GetWorldCoordinatesFromZone(tx, ty, targetMap)
    if (not wx or not wy or not tinst) and ns.MapCoords then
        wx, wy = ns.MapCoords:ZoneToWorld(targetMap, tx, ty)
        tinst = pinst
    end
    if not wx or not wy or not tinst or tinst ~= pinst then
        return nil
    end

    return HBD:GetWorldVector(pinst, px, py, wx, wy)
end

function MapRoute:ClearUserWaypoint()
    if not userWaypointActive then
        return
    end
    safeCall(C_Map.SetUserWaypoint, C_Map, nil)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        safeCall(C_SuperTrack.SetSuperTrackedUserWaypoint, C_SuperTrack, false)
    end
    userWaypointActive = false
end

function MapRoute:SetUserWaypoint(step, route)
    if not self:ShouldUseBlizzardWaypoint() then
        return false
    end

    route = route or activeRoute
    local mapId, x, y = self:GetStepCoords(step, route and route.destination)
    if not mapId then
        return false
    end
    if not (C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then
        return false
    end

    self:EnsureMapLoaded(mapId)
    local point = UiMapPoint.CreateFromCoordinates(mapId, x, y)
    if not point then
        return false
    end

    safeCall(C_Map.SetUserWaypoint, C_Map, point)
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        safeCall(C_SuperTrack.SetSuperTrackedUserWaypoint, C_SuperTrack, true)
    end
    userWaypointActive = true
    return true
end

function MapRoute:WorldToMapXY(mapId, wx, wy, instance)
    if not mapId or not wx or not wy or not instance then
        return nil
    end
    return HBD:GetZoneCoordinatesFromWorldInstance(wx, wy, instance, mapId, true)
end

function MapRoute:GetCanvasXY(displayMapId, sourceMapId, x, y)
    if not displayMapId or not sourceMapId or not x or not y then
        return nil
    end

    x = ns.Destination and ns.Destination:NormalizeUICoord(x)
    y = ns.Destination and ns.Destination:NormalizeUICoord(y)
    if not x or not y then
        return nil
    end

    if displayMapId == sourceMapId then
        return x, y
    end

    if ns.MapCoords then
        local tx, ty = ns.MapCoords:ZoneToZone(sourceMapId, x, y, displayMapId)
        if tx and ty then
            return tx, ty
        end
    end

    self:EnsureMapLoaded(displayMapId)
    self:EnsureMapLoaded(sourceMapId)
    return HBD:TranslateZoneCoordinates(x, y, sourceMapId, displayMapId, true)
end

function MapRoute:GetPlayerCanvasXY(displayMapId)
    local playerMap = C_Map.GetBestMapForUnit("player")
    if playerMap then
        local pos = C_Map.GetPlayerMapPosition(playerMap, "player")
        if pos then
            local px, py = self:GetCanvasXY(displayMapId, playerMap, pos.x, pos.y)
            if px and py then
                return px, py
            end
        end
    end

    local wx, wy, instance = self:GetPlayerWorld()
    if wx and wy and instance then
        return self:WorldToMapXY(displayMapId, wx, wy, instance)
    end

    return nil
end

function MapRoute:GetTargetCanvasXY(displayMapId, navStep, route)
    local tx, ty = self:GetNavTargetOnMap(displayMapId, navStep, route)
    if tx and ty then
        return tx, ty
    end

    local targetMap, x, y = self:GetTargetCoordsForOverlay(navStep, route)
    if targetMap and x and y then
        local canvasX, canvasY = self:GetCanvasXY(displayMapId, targetMap, x, y)
        if canvasX and canvasY then
            return canvasX, canvasY
        end

        self:EnsureMapLoaded(targetMap)
        local wx, wy, instance = HBD:GetWorldCoordinatesFromZone(x, y, targetMap)
        if wx and wy and instance then
            return self:WorldToMapXY(displayMapId, wx, wy, instance)
        end
    end

    return nil
end

function MapRoute:HideLinePair(borderTex, lineTex)
    if borderTex then
        borderTex:Hide()
    end
    if lineTex then
        lineTex:Hide()
    end
end

function MapRoute:HidePinPair(borderTex, pinTex)
    if borderTex then
        borderTex:Hide()
    end
    if pinTex then
        pinTex:Hide()
    end
end

function MapRoute:DrawLinePair(borderTex, lineTex, parent, x1, y1, x2, y2, thickness)
    if not borderTex or not lineTex or not parent or not x1 or not y1 or not x2 or not y2 then
        self:HideLinePair(borderTex, lineTex)
        return
    end

    local w, h = parent:GetSize()
    if w <= 0 or h <= 0 then
        self:HideLinePair(borderTex, lineTex)
        return
    end

    local px1, py1 = x1 * w, -y1 * h
    local px2, py2 = x2 * w, -y2 * h
    local dx, dy = px2 - px1, py2 - py1
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 2 then
        self:HideLinePair(borderTex, lineTex)
        return
    end

    local angle = math.atan2(dy, dx)
    local cx = px1 + dx * 0.5
    local cy = py1 + dy * 0.5
    local borderThick = (thickness or 3) + 2

    borderTex:ClearAllPoints()
    borderTex:SetSize(length, borderThick)
    borderTex:SetPoint("CENTER", parent, "TOPLEFT", cx, cy)
    borderTex:SetRotation(angle)
    borderTex:Show()

    lineTex:ClearAllPoints()
    lineTex:SetSize(length, thickness or 3)
    lineTex:SetPoint("CENTER", parent, "TOPLEFT", cx, cy)
    lineTex:SetRotation(angle)
    lineTex:Show()
end

function MapRoute:DrawRadialLinePair(borderTex, lineTex, parent, angle, startDist, endDist, thickness)
    if not borderTex or not lineTex or not parent then
        self:HideLinePair(borderTex, lineTex)
        return
    end

    local length = endDist - startDist
    if length < 2 then
        self:HideLinePair(borderTex, lineTex)
        return
    end

    local centerDist = startDist + length * 0.5
    local cx, cy = bearingToMinimapOffset(angle, centerDist)
    local borderThick = (thickness or 3) + 2
    local lineAngle = math.atan2(cy, cx)

    borderTex:ClearAllPoints()
    borderTex:SetSize(length, borderThick)
    borderTex:SetPoint("CENTER", parent, "CENTER", cx, cy)
    borderTex:SetRotation(lineAngle)
    borderTex:Show()

    lineTex:ClearAllPoints()
    lineTex:SetSize(length, thickness or 3)
    lineTex:SetPoint("CENTER", parent, "CENTER", cx, cy)
    lineTex:SetRotation(lineAngle)
    lineTex:Show()
end

function MapRoute:DrawCyanDot(borderTex, pinTex, parent, anchor, relX, relY, size)
    if not borderTex or not pinTex or not parent then
        self:HidePinPair(borderTex, pinTex)
        return
    end

    local dotSize = size or 12
    local borderSize = dotSize + 3

    borderTex:ClearAllPoints()
    borderTex:SetSize(borderSize, borderSize)
    borderTex:SetPoint("CENTER", parent, anchor or "CENTER", relX or 0, relY or 0)
    borderTex:Show()

    pinTex:ClearAllPoints()
    pinTex:SetSize(dotSize, dotSize)
    pinTex:SetPoint("CENTER", parent, anchor or "CENTER", relX or 0, relY or 0)
    pinTex:Show()
end

function MapRoute:DrawCyanDotOnCanvas(borderTex, pinTex, canvas, normX, normY, size)
    if not canvas or not normX or not normY then
        self:HidePinPair(borderTex, pinTex)
        return
    end

    local w, h = canvas:GetSize()
    local px = normX * w
    local py = -normY * h
    self:DrawCyanDot(borderTex, pinTex, canvas, "TOPLEFT", px, py, size or 14)
end

function MapRoute:GetNavigationStep(route)
    route = route or activeRoute

    if ns.RouteTracker and ns.RouteTracker.route == route and ns.RouteTracker.GetNavigationStep then
        return ns.RouteTracker:GetNavigationStep()
    end

    if ns.SubStepResolver then
        return ns.SubStepResolver:GetNavigationStep(route)
    end

    if not route then
        return nil
    end

    local idx = route.activeStepIndex or 1
    local step = route.steps and route.steps[idx]
    if step and self:GetStepCoords(step, route.destination) then
        return step
    end

    for i = idx + 1, #(route.steps or {}) do
        local nextStep = route.steps[i]
        if nextStep and self:GetStepCoords(nextStep, route.destination) then
            return nextStep
        end
    end

    if route.destination and route.destination.mapId then
        return ns.Destination:ToNavStep(route.destination, route.destination.name)
    end

    return step
end

function MapRoute:HideOverlay()
    self:HideLinePair(self.worldLineBorder, self.worldLine)
    self:HideLinePair(self.miniLineBorder, self.miniLine)
    self:HidePinPair(self.worldPinBorder, self.worldPin)
    self:HidePinPair(self.miniPinBorder, self.miniPin)
    if self.worldOverlay then
        self.worldOverlay:Hide()
    end
    if self.minimapOverlay then
        self.minimapOverlay:Hide()
    end
end

function MapRoute:Clear()
    activeRoute = nil
    self:HideOverlay()
    self:ClearUserWaypoint()
end

function MapRoute:ShouldShowNavigation(route)
    if not route then
        return false
    end
    local active = ns.RouteTracker and ns.RouteTracker:GetActiveStep()
    if active and ns.TravelActions and ns.TravelActions:IsInstantUseStep(active) then
        return false
    end
    return self:GetNavigationStep(route) ~= nil
end

function MapRoute:RefreshMinimapOverlay()
    self:EnsureOverlayFrames()

    if not self.minimapOverlay or not activeRoute or not Minimap or not Minimap:IsVisible() then
        if self.minimapOverlay then
            self.minimapOverlay:Hide()
        end
        return
    end

    if not self:ShouldShowNavigation(activeRoute) then
        self.minimapOverlay:Hide()
        return
    end

    local navStep = self:GetNavigationStep(activeRoute)
    if not navStep then
        self.minimapOverlay:Hide()
        return
    end

    local playerMap = C_Map.GetBestMapForUnit("player")
    local pos = playerMap and C_Map.GetPlayerMapPosition(playerMap, "player")
    local canvasTx, canvasTy = self:GetNavTargetOnMap(playerMap, navStep, activeRoute)

    local angle
    if pos and canvasTx and canvasTy then
        angle = normalizeHBDAngle(canvasTx - pos.x, pos.y - canvasTy)
    end
    if not angle then
        angle = self:GetBearingToStep(navStep, activeRoute)
    end
    if not angle then
        self.minimapOverlay:Hide()
        return
    end

    if GetCVar("rotateMinimap") == "1" then
        angle = angle - (GetPlayerFacing() or 0)
    end

    self.minimapOverlay:Show()

    local width = Minimap:GetWidth()
    local height = Minimap:GetHeight()
    local edgeDist = getMinimapEdgeDistance(angle, width, height)
    local startDist = 12
    local endDist = edgeDist - 2
    local pinDist = endDist

    if pos and canvasTx and canvasTy and ns.MapCoords then
        local yardDist = ns.MapCoords:GetZoneDistance(
            playerMap, pos.x, pos.y, playerMap, canvasTx, canvasTy
        )
        local viewRadius = self:GetMinimapViewRadius()
        if yardDist and viewRadius and yardDist <= viewRadius then
            local ratio = yardDist / viewRadius
            pinDist = math.max(startDist + 4, math.min(endDist, ratio * edgeDist))
        end
    end

    self:DrawRadialLinePair(self.miniLineBorder, self.miniLine, self.minimapOverlay, angle, startDist, endDist, 3)

    local pinX, pinY = bearingToMinimapOffset(angle, pinDist)
    self:DrawCyanDot(self.miniPinBorder, self.miniPin, self.minimapOverlay, "CENTER", pinX, pinY, 11)
end

function MapRoute:RefreshWorldOverlay()
    self:EnsureWorldOverlayFrames()

    if not self.worldOverlay or not activeRoute or not WorldMapFrame or not WorldMapFrame:IsShown() then
        if self.worldOverlay then
            self.worldOverlay:Hide()
        end
        return
    end

    local mapId = WorldMapFrame:GetMap():GetMapID()
    if not mapId then
        self.worldOverlay:Hide()
        return
    end

    if not self:ShouldShowNavigation(activeRoute) then
        self.worldOverlay:Hide()
        return
    end

    local navStep = self:GetNavigationStep(activeRoute)
    if not navStep then
        self.worldOverlay:Hide()
        return
    end

    local tx, ty = self:GetTargetCanvasXY(mapId, navStep, activeRoute)
    if not tx or not ty then
        self.worldOverlay:Hide()
        return
    end

    local px, py = self:GetPlayerCanvasXY(mapId)

    self.worldOverlay:Show()
    local canvas = self.worldCanvas or WorldMapFrame:GetCanvas()

    if px and py then
        self:DrawLinePair(self.worldLineBorder, self.worldLine, canvas, px, py, tx, ty, 3)
    else
        self:HideLinePair(self.worldLineBorder, self.worldLine)
    end

    self:DrawCyanDotOnCanvas(self.worldPinBorder, self.worldPin, canvas, tx, ty, 14)
end

function MapRoute:Update(route)
    if busy then
        return
    end
    busy = true

    activeRoute = route
    self:EnsureOverlayFrames()

    if route then
        local navStep = self:GetNavigationStep(route)
        if navStep and self:ShouldUseBlizzardWaypoint() then
            self:SetUserWaypoint(navStep, route)
        elseif self:UsesTomTom() then
            self:ClearUserWaypoint()
        end
        self:RefreshMinimapOverlay()
        self:RefreshWorldOverlay()
    else
        self:Clear()
    end

    busy = false
end

function MapRoute:OnTick()
    if not activeRoute then
        return
    end
    self:RefreshMinimapOverlay()
    if WorldMapFrame and WorldMapFrame:IsShown() then
        self:RefreshWorldOverlay()
    end
end
