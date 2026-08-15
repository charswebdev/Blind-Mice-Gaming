local addon = Exploration

local DOT_SIZE = 8
local DOT_SIZE_CURRENT = 12
local LINE_THICKNESS = 2
local STROKE_SIZE = 1
local LINE_STROKE_EXTRA = 2
local UPDATE_DISTANCE_SQ = 1 -- squared yards before triggering redraw
local ZOOM_REF_RADIUS = 230  -- reference radius for zoom scaling (max zoom-out ~233 yards)
local ZOOM_MIN_SCALE = 1.0
local ZOOM_MAX_SCALE = 1.5

local COLOR_CURRENT     = { 0.22, 0.92, 0.35, 1.0 }
local COLOR_UPCOMING    = { 1.0, 0.92, 0.4, 1.0 }
local COLOR_PREVIOUS    = { 0.5, 0.5, 0.5, 0.4 }
local COLOR_LINE        = { 1.0, 0.84, 0.0, 0.75 }
local COLOR_LINE_TRAVEL = { 0.53, 0.90, 0.91, 0.85 } -- |cFF87e6e8 — zone complete, travel segment
local COLOR_LINE_STROKE = { 0.0, 0.0, 0.0, 0.5 }

local LINE_TEXTURE = "Interface\\AddOns\\Exploration\\Textures\\line"
local LINEFACTOR   = 128 / 122
local LINEFACTOR_2 = LINEFACTOR / 2

local math_sin = math.sin
local math_cos = math.cos
local math_max = math.max
local math_min = math.min

-- Minimap reference (can be redirected by FarmHUD etc.)
local minimapFrame = Minimap

-- Raw SetParent from the Frame metatable, bypasses per-instance hooks (FarmHUD replaces
-- SetParent on Minimap children with dummyOnly_SetParent and may not restore it)
local rawSetParent = getmetatable(Minimap).__index.SetParent

-- State
local container       -- frame parented to minimapFrame, holds all line textures
local circularMask    -- shared MaskTexture for circular clipping
local dotPool = {}
local activeDots = {}
local linePool = {}
local activeLines = {}
local cachedData = nil -- rebuilt on route change: array of { worldX, worldY, instanceID, color, size, data, index, flatIdx }
local cachedIsTravelSegment = false
local rotateMinimap = false
local lastPlayerX, lastPlayerY
local lastFacing
local needsFullRedraw = false
local initialized = false
local lastArrowRemapMap = nil

-- Cache continent lookups (zone mapID -> continent mapID)
-- Walks up map hierarchy until parent is Azeroth/Cosmic (same as GetTopLevelMap in Waypoints.lua)
local continentCache = {}

local function GetContinentMapID(mapID)
    if continentCache[mapID] then return continentCache[mapID] end

    local info = C_Map.GetMapInfo(mapID)
    if not info then return nil end

    while info and info.parentMapID and info.parentMapID ~= 0 do
        local parentInfo = C_Map.GetMapInfo(info.parentMapID)
        if parentInfo then
            if parentInfo.name == "Azeroth" or parentInfo.name == "Cosmic" then
                continentCache[mapID] = info.mapID
                return info.mapID
            end
            info = parentInfo
        else
            break
        end
    end

    if info then
        continentCache[mapID] = info.mapID
        return info.mapID
    end
    return nil
end

---------------------------------------------------------------------------
-- Dot pool
---------------------------------------------------------------------------

local function CreateDot()
    local dot = CreateFrame("Frame", nil, UIParent)
    rawSetParent(dot, minimapFrame)
    dot:SetSize(DOT_SIZE, DOT_SIZE)
    dot:SetFrameLevel(minimapFrame:GetFrameLevel() + 5)
    dot:EnableMouse(true)
    if dot.SetMouseMotionEnabled then
        dot:SetMouseMotionEnabled(true)
    end
    if dot.SetMouseClickEnabled then
        dot:SetMouseClickEnabled(false)
    end

    dot.bg = dot:CreateTexture(nil, "ARTWORK")
    dot.bg:SetPoint("TOPLEFT", dot, "TOPLEFT", -STROKE_SIZE, STROKE_SIZE)
    dot.bg:SetPoint("BOTTOMRIGHT", dot, "BOTTOMRIGHT", STROKE_SIZE, -STROKE_SIZE)
    dot.bg:SetColorTexture(0, 0, 0, 1)

    dot.bgMask = dot:CreateMaskTexture()
    dot.bgMask:SetAllPoints(dot.bg)
    dot.bgMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    dot.bg:AddMaskTexture(dot.bgMask)

    dot.texture = dot:CreateTexture(nil, "OVERLAY")
    dot.texture:SetAllPoints(dot)
    dot.texture:SetColorTexture(1, 1, 1, 1)

    dot.mask = dot:CreateMaskTexture()
    dot.mask:SetAllPoints(dot.texture)
    dot.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    dot.texture:AddMaskTexture(dot.mask)

    dot:SetScript("OnEnter", function(self)
        local data = self.waypointData
        if not data or not data.name then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local gold = addon.theme.accent
        GameTooltip:SetText(addon:LocalizedString(data.name), gold[1], gold[2], gold[3])
        if data.note and data.note ~= "" then
            GameTooltip:AddLine(data.note, 1, 0.82, 0, true)
        end
        if self.waypointIndex == addon.waypoint.index then
            GameTooltip:AddLine("Current waypoint", 0.5, 0.5, 0.5)
        end
        GameTooltip:Show()
    end)
    dot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return dot
end

local function AcquireDot(wpInfo)
    local dot = tremove(dotPool) or CreateDot()
    dot:SetSize(wpInfo.size, wpInfo.size)
    dot.texture:SetVertexColor(wpInfo.color[1], wpInfo.color[2], wpInfo.color[3], wpInfo.color[4])
    dot.bg:SetAlpha(wpInfo.color[4])
    dot.waypointData = wpInfo.data
    dot.waypointIndex = wpInfo.index
    dot:Show()
    activeDots[#activeDots + 1] = dot
    return dot
end

local function ReleaseAllDots()
    for i = #activeDots, 1, -1 do
        local dot = activeDots[i]
        if GameTooltip:IsOwned(dot) then
            GameTooltip:Hide()
        end
        dot.waypointData = nil
        dot.waypointIndex = nil
        dot:Hide()
        dot:ClearAllPoints()
        dotPool[#dotPool + 1] = dot
        activeDots[i] = nil
    end
end

---------------------------------------------------------------------------
-- Line pool
---------------------------------------------------------------------------

local function AcquireLine(layer)
    local tex = tremove(linePool)
    if not tex then
        tex = container:CreateTexture(nil, layer)
        tex:SetTexture(LINE_TEXTURE)
        tex:SetTexelSnappingBias(0)
        tex:SetSnapToPixelGrid(false)
        if circularMask then
            tex:AddMaskTexture(circularMask)
        end
    end
    tex:SetDrawLayer(layer)
    tex:Show()
    activeLines[#activeLines + 1] = tex
    return tex
end

local function ReleaseAllLines()
    for i = #activeLines, 1, -1 do
        local tex = activeLines[i]
        tex:Hide()
        tex:ClearAllPoints()
        linePool[#linePool + 1] = tex
        activeLines[i] = nil
    end
end

---------------------------------------------------------------------------
-- Line drawing (pixel coordinates on container, same SetTexCoord rotation)
---------------------------------------------------------------------------

local function DrawMinimapLine(sx, sy, ex, ey, w, color, layer)
    local tex = AcquireLine(layer)
    tex:SetVertexColor(color[1], color[2], color[3], color[4])

    local dx, dy = ex - sx, ey - sy
    local l = (dx * dx + dy * dy) ^ 0.5
    if l < 0.01 then tex:Hide() return end

    local cx, cy = (sx + ex) / 2, (sy + ey) / 2

    if dx < 0 then
        dx, dy = -dx, -dy
    end

    local s, c = -dy / l, dx / l
    local sc = s * c

    local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
    if dy >= 0 then
        Bwid = ((l * c) - (w * s)) * LINEFACTOR_2
        Bhgt = ((w * c) - (l * s)) * LINEFACTOR_2
        BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc
        BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
        TRy = BRx
    else
        Bwid = ((l * c) + (w * s)) * LINEFACTOR_2
        Bhgt = ((w * c) + (l * s)) * LINEFACTOR_2
        BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc
        BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
        TRx = TLy
    end

    tex:ClearAllPoints()
    tex:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
    tex:SetPoint("BOTTOMLEFT", container, "CENTER", cx - Bwid, cy - Bhgt)
    tex:SetPoint("TOPRIGHT",   container, "CENTER", cx + Bwid, cy + Bhgt)
end

---------------------------------------------------------------------------
-- Data rebuild (called on route/waypoint changes)
---------------------------------------------------------------------------

local function RebuildCachedData()
    cachedData = nil
    cachedIsTravelSegment = false

    if not addon.data or not addon.data.settings.mapOverlay then return end
    if not addon.segment or not addon.segment.route or not addon.waypoint.index then return end
    if not addon.active or not addon.active.path or #addon.active.path == 0 then return end

    -- Filter by continent of the current target waypoint (not the player's position)
    local currentWp = addon.segment.route[addon.waypoint.index]
    if not currentWp then return end
    local targetMapID = addon:GetWaypointMapID(currentWp.data)
    -- If current waypoint has no map (trigger-only), use player's continent for filtering
    local targetContinent
    if targetMapID then
        targetContinent = GetContinentMapID(targetMapID)
    else
        local playerMapID = C_Map.GetBestMapForUnit("player")
        if playerMapID then
            targetContinent = GetContinentMapID(playerMapID)
        end
    end
    if not targetContinent then return end

    local currentLeafName = addon.active.path[#addon.active.path]
    cachedIsTravelSegment = addon:IsTravelSegment(currentLeafName)

    local allWaypoints = {}
    addon:CollectLeafWaypoints(currentLeafName, allWaypoints)

    local pastCurrentWaypoint = false
    local result = {}

    -- Prefer world-pos continent IDs (reliable on Draenor/Outland) over uiMap hierarchy walks.
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerWorldContinent
    if playerMapID then
        playerWorldContinent = C_Map.GetWorldPosFromMapPos(playerMapID, CreateVector2D(0.5, 0.5))
    end

    for flatIdx, wp in ipairs(allWaypoints) do
        local isCurrentWp = wp.wpIndex == addon.waypoint.index

        if pastCurrentWaypoint or isCurrentWp then
            if isCurrentWp then pastCurrentWaypoint = true end

            local wpMapID = addon:GetWaypointMapID(wp.data)
            if wpMapID then
                local nx, ny = addon:GetWaypointNavCoords(wp.data)
                local wpX = (tonumber(nx) or 0) / 100
                local wpY = (tonumber(ny) or 0) / 100

                -- Remap through the player's Midnight map tree so Eversong pins
                -- keep a world instance while the client reports 2569/Great Sea.
                local continentID, worldPos
                if addon.GetWaypointWorldPos then
                    continentID, worldPos = addon:GetWaypointWorldPos(wpMapID, wpX, wpY)
                else
                    continentID, worldPos = C_Map.GetWorldPosFromMapPos(wpMapID, CreateVector2D(wpX, wpY))
                end
                if continentID and worldPos then
                    -- Keep pins on the player's world continent (Draenor/Pandaria-safe).
                    -- Also accept uiMap-continent matches and the active target map.
                    local sameWorld = (not playerWorldContinent) or continentID == playerWorldContinent
                    local sameUiContinent = targetContinent and GetContinentMapID(wpMapID) == targetContinent
                    if sameWorld or sameUiContinent or wpMapID == targetMapID or isCurrentWp then
                        local color, size, lineSkip
                        local isDiscovered = addon.segment.route[wp.wpIndex]
                            and addon.segment.route[wp.wpIndex].discovered

                        if isCurrentWp then
                            color = COLOR_CURRENT
                            size = DOT_SIZE_CURRENT
                        elseif isDiscovered then
                            color = COLOR_PREVIOUS
                            size = DOT_SIZE
                            lineSkip = true
                        else
                            color = COLOR_UPCOMING
                            size = DOT_SIZE
                        end

                        result[#result + 1] = {
                            worldX = worldPos.x,
                            worldY = worldPos.y,
                            instanceID = continentID,
                            color = color,
                            size = size,
                            data = wp.data,
                            index = wp.wpIndex,
                            flatIdx = flatIdx,
                            lineSkip = lineSkip,
                            forceDraw = isCurrentWp,
                        }
                    end
                end
            end
        end
    end

    if #result > 0 then
        cachedData = result
    end

    -- Force position recalculation
    lastPlayerX = nil
    lastPlayerY = nil
end

---------------------------------------------------------------------------
-- Per-frame position update
---------------------------------------------------------------------------

local function UpdatePositions()
    if not cachedData then return end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerContinent, playerWorld

    if playerMapID then
        local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
        if playerPos then
            playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(playerMapID, playerPos)
        end
    end

    -- Over water / Great Sea / some Midnight maps: map position is nil — fall back
    -- to UnitPosition so the travel line stays up for the whole flight.
    if not playerContinent or not playerWorld then
        local uy, ux, _, instanceID = UnitPosition("player")
        if ux and uy and instanceID then
            playerContinent = instanceID
            playerWorld = { x = uy, y = ux }
        else
            return
        end
    end

    -- GetWorldPosFromMapPos: .x = north-south, .y = east-west
    -- HereBeDragons convention: worldX = E/W (.y), worldY = N/S (.x)
    local px, py = playerWorld.y, playerWorld.x

    -- Check if we need to update (before releasing anything)
    local facing
    if rotateMinimap then
        facing = GetPlayerFacing()
        if not facing then return end
    end

    if lastPlayerX and lastPlayerY then
        local dx = px - lastPlayerX
        local dy = py - lastPlayerY
        local movedSq = dx * dx + dy * dy
        if movedSq < UPDATE_DISTANCE_SQ and facing == lastFacing and not needsFullRedraw then
            return
        end
    end

    -- Now release and redraw
    ReleaseAllDots()
    ReleaseAllLines()

    lastPlayerX = px
    lastPlayerY = py
    lastFacing = facing
    needsFullRedraw = false

    local mapRadius = C_Minimap.GetViewRadius()
    local halfW = minimapFrame:GetWidth() / 2
    local halfH = minimapFrame:GetHeight() / 2
    local zoomScale = math_max(ZOOM_MIN_SCALE, math_min(ZOOM_MAX_SCALE, ZOOM_REF_RADIUS / mapRadius))

    local sin_f, cos_f
    if rotateMinimap and facing then
        sin_f = math_sin(facing)
        cos_f = math_cos(facing)
    end

    -- Calculate screen positions for all visible waypoints
    -- Axis mapping: worldY (.y) = E/W → screen X, worldX (.x) = N/S → screen Y
    local screenPositions = {}

    for i, wp in ipairs(cachedData) do
        -- Current travel pin: draw even when Midnight alias maps disagree on
        -- continentID (player on 2569 / Great Sea, pin authored on 2395).
        if wp.instanceID == playerContinent or wp.forceDraw then
            local xDist = px - wp.worldY  -- E/W distance → screen X
            local yDist = py - wp.worldX  -- N/S distance → screen Y

            if rotateMinimap then
                local dx, dy = xDist, yDist
                xDist = dx * cos_f - dy * sin_f
                yDist = dx * sin_f + dy * cos_f
            end

            local normX = xDist / mapRadius
            local normY = yDist / mapRadius
            local distSq = normX * normX + normY * normY

            local screenX = normX * halfW
            local screenY = -normY * halfH

            screenPositions[i] = {
                x = screenX,
                y = screenY,
                distSq = distSq,
                visible = distSq <= 1.5, -- show slightly beyond radius for line continuity
                onMap = distSq <= 0.81, -- 0.9^2, inside the visible circle
            }
        end
    end

    -- Build line pairs (skip discovered upcoming waypoints, connect directly between non-skipped)
    local linePairs = {}
    local lastLineIdx = nil
    local lastFlatIdx = nil
    local playerCenter = { x = 0, y = 0, visible = true, onMap = true }

    for i, wp in ipairs(cachedData) do
        local sp = screenPositions[i]
        if sp then
            if lastFlatIdx and wp.flatIdx ~= lastFlatIdx + 1 then
                lastLineIdx = nil -- segment boundary, break the chain
            end
            lastFlatIdx = wp.flatIdx

            if not wp.lineSkip then
                if lastLineIdx then
                    local prevSp = screenPositions[lastLineIdx]
                    if prevSp and (prevSp.visible or sp.visible) then
                        if prevSp.onMap or sp.onMap then
                            linePairs[#linePairs + 1] = { prevSp, sp }
                        else
                            local ldx = sp.x - prevSp.x
                            local ldy = sp.y - prevSp.y
                            if (ldx * ldx + ldy * ldy) <= halfW * halfW * 9 then
                                linePairs[#linePairs + 1] = { prevSp, sp }
                            end
                        end
                    end
                elseif wp.color == COLOR_CURRENT then
                    -- Line from player toward current waypoint, offset 15% from center
                    local dx, dy = sp.x, sp.y
                    local dist = (dx * dx + dy * dy) ^ 0.5
                    local startX, startY = 0, 0
                    if dist > 0 then
                        local offset = halfW * 0.02
                        startX = dx / dist * offset
                        startY = dy / dist * offset
                    end
                    linePairs[#linePairs + 1] = { { x = startX, y = startY }, sp }
                end
                lastLineIdx = i
            end
        else
            lastLineIdx = nil
            lastFlatIdx = nil
        end
    end

    -- Draw lines (stroke pass then main pass), scaled by zoom
    local lineColor = cachedIsTravelSegment and COLOR_LINE_TRAVEL or COLOR_LINE
    for pass = 1, 2 do
        local w, color, layer
        if pass == 1 then
            w = (LINE_THICKNESS + LINE_STROKE_EXTRA) * zoomScale
            color = COLOR_LINE_STROKE
            layer = "ARTWORK"
        else
            w = LINE_THICKNESS * zoomScale
            color = lineColor
            layer = "OVERLAY"
        end

        for _, pair in ipairs(linePairs) do
            DrawMinimapLine(pair[1].x, pair[1].y, pair[2].x, pair[2].y, w, color, layer)
        end
    end

    -- Draw dots (only for waypoints inside the visible circle), scaled by zoom
    for i, wp in ipairs(cachedData) do
        local sp = screenPositions[i]
        if sp and sp.onMap then
            local dot = AcquireDot(wp)
            local scaledSize = wp.size * zoomScale
            dot:SetSize(scaledSize, scaledSize)
            dot:ClearAllPoints()
            dot:SetPoint("CENTER", minimapFrame, "CENTER", sp.x, sp.y)
        end
    end
end

---------------------------------------------------------------------------
-- OnUpdate handler
---------------------------------------------------------------------------

local updateFrame

local function OnUpdate(self, elapsed)
    if not initialized then return end
    if not addon.data or not addon.data.settings.mapOverlay then return end

    -- Auto-restore to real Minimap if tracked frame is hidden (FarmHUD deactivation)
    if minimapFrame ~= Minimap and not minimapFrame:IsVisible() and Minimap:IsVisible() then
        addon:ReparentMinimapOverlay(Minimap)
    end

    if not minimapFrame:IsVisible() then return end
    if not cachedData then return end

    UpdatePositions()
end

---------------------------------------------------------------------------
-- Event handler
---------------------------------------------------------------------------

local function OnEvent(self, event, ...)
    if event == "CVAR_UPDATE" then
        local cvar, value = ...
        if cvar == "rotateMinimap" or cvar == "ROTATE_MINIMAP" then
            rotateMinimap = (value == "1")
            needsFullRedraw = true
        end
    elseif event == "MINIMAP_UPDATE_ZOOM" then
        needsFullRedraw = true
    elseif event == "PLAYER_ENTERING_WORLD"
        or event == "ZONE_CHANGED"
        or event == "ZONE_CHANGED_NEW_AREA"
        or event == "ZONE_CHANGED_INDOORS"
    then
        RebuildCachedData()
        needsFullRedraw = true
        if event ~= "PLAYER_ENTERING_WORLD" and addon.UpdateWaypointArrow then
            -- Only remount the arrow when the uiMap swaps (2424 ↔ 2569 ↔ Great Sea).
            local map = C_Map.GetBestMapForUnit("player")
            if map and map ~= lastArrowRemapMap then
                lastArrowRemapMap = map
                addon:UpdateWaypointArrow()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            lastArrowRemapMap = C_Map.GetBestMapForUnit("player")
        end
    end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function addon:InitializeMinimapOverlay()
    -- Container frame for line textures
    container = CreateFrame("Frame", nil, minimapFrame)
    container:SetAllPoints(minimapFrame)
    container:SetFrameLevel(minimapFrame:GetFrameLevel() + 3)

    -- Circular mask for line clipping
    circularMask = container:CreateMaskTexture()
    circularMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    circularMask:SetAllPoints(container)

    -- Update frame
    updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", OnUpdate)
    updateFrame:SetScript("OnEvent", OnEvent)
    updateFrame:RegisterEvent("CVAR_UPDATE")
    updateFrame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
    updateFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    updateFrame:RegisterEvent("ZONE_CHANGED")
    updateFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    updateFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

    rotateMinimap = GetCVar("rotateMinimap") == "1"

    -- Hook HereBeDragons-Pins for FarmHUD compatibility
    local HBDPins = LibStub and LibStub("HereBeDragons-Pins-2.0", true)
    if HBDPins then
        hooksecurefunc(HBDPins, "SetMinimapObject", function(_, minimapObject)
            addon:ReparentMinimapOverlay(minimapObject or Minimap)
        end)
    end

    initialized = true
end

function addon:ReparentMinimapOverlay(newMinimap)
    if not initialized or not newMinimap then return end

    ReleaseAllDots()
    ReleaseAllLines()

    minimapFrame = newMinimap

    -- Reparent container (use raw SetParent to bypass FarmHUD's dummyOnly_SetParent hook)
    rawSetParent(container, minimapFrame)
    container:SetAllPoints(minimapFrame)
    container:SetFrameLevel(minimapFrame:GetFrameLevel() + 3)

    -- Reparent pooled dots
    for _, dot in ipairs(dotPool) do
        rawSetParent(dot, minimapFrame)
        dot:SetFrameLevel(minimapFrame:GetFrameLevel() + 5)
    end

    -- Rebuild circular mask on new parent
    circularMask:SetAllPoints(container)
    container:Show()

    needsFullRedraw = true
    lastPlayerX = nil
    lastPlayerY = nil
end

function addon:RefreshMinimapOverlay()
    if not initialized then return end
    RebuildCachedData()
    needsFullRedraw = true

    if not addon.data or not addon.data.settings.mapOverlay or not cachedData then
        ReleaseAllDots()
        ReleaseAllLines()
    end
end
