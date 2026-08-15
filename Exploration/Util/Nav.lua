local addon = Exploration

function addon:ClearTomTomWaypoints()
    if not TomTom or not TomTom.waypoints then return end
    local toRemove = {}
    for _, waypoints in pairs(TomTom.waypoints) do
        for _, uid in pairs(waypoints) do
            if type(uid) == "table" and uid.from == "Exploration" then
                toRemove[#toRemove + 1] = uid
            end
        end
    end
    for _, uid in ipairs(toRemove) do
        TomTom:RemoveWaypoint(uid)
    end
end

function addon:ShouldUseTomTom()
    if not TomTom then return false end
    local s = addon.data.settings.tomtom or "auto"
    if s == "disable" then return false end
    return true
end

function addon:ShouldUsePins()
    local s = addon.data.settings.pins or "auto"
    if s == "enable" then return true end
    if s == "disable" then return false end
    return not addon:ShouldUseTomTom()
end

local function mapIsAncestor(child, ancestor)
    child, ancestor = tonumber(child), tonumber(ancestor)
    if not child or not ancestor or not C_Map or not C_Map.GetMapInfo then
        return false
    end
    local info = C_Map.GetMapInfo(child)
    local guard = 0
    while info and info.parentMapID and info.parentMapID ~= 0 and guard < 20 do
        if info.parentMapID == ancestor then
            return true
        end
        info = C_Map.GetMapInfo(info.parentMapID)
        guard = guard + 1
    end
    return false
end

--- True when maps are the same or one is a parent of the other (e.g. Boralus
--- 1161 under Tiragarde 895). Used so Discover toasts on a city/micro map
--- still clear curated pins authored on the parent zone map.
function addon:MapsAreParentOrChild(mapA, mapB)
    mapA, mapB = tonumber(mapA), tonumber(mapB)
    if not mapA or not mapB then return false end
    if mapA == mapB then return true end
    return mapIsAncestor(mapA, mapB) or mapIsAncestor(mapB, mapA)
end

--- True when one map is the other, an ancestor, or a sibling under the same
--- parent (e.g. Quel'Danas ↔ Eversong under Quel'Thalas). Continent-only
--- matches across different continent parents still return false.
function addon:MapsAreLocallyCompatible(mapA, mapB)
    mapA, mapB = tonumber(mapA), tonumber(mapB)
    if not mapA or not mapB then return false end
    if mapA == mapB then return true end

    if mapIsAncestor(mapA, mapB) or mapIsAncestor(mapB, mapA) then
        return true
    end

    local infoA = C_Map.GetMapInfo(mapA)
    local infoB = C_Map.GetMapInfo(mapB)
    local parentA = infoA and infoA.parentMapID
    local parentB = infoB and infoB.parentMapID
    if parentA and parentB and parentA ~= 0 and parentA == parentB then
        return true
    end
    return false
end

--- Travel / taxi hops always keep a destination arrow. Hiding the arrow when
--- maps weren't "locally compatible" left players over water (Great Sea /
--- Shining Span) with no guidance — worse than a rare void projection.
function addon:EnsureReachableTravelStep()
    return true
end

function addon:UpdateWaypointArrow()
    if addon.ClearTomTomWaypoints then
        addon:ClearTomTomWaypoints()
    elseif addon.waypoint.arrow and TomTom then
        TomTom:RemoveWaypoint(addon.waypoint.arrow)
    end
    addon.waypoint.arrow = nil
    C_Map.ClearUserWaypoint()
    C_SuperTrack.SetSuperTrackedUserWaypoint(false)

    if not addon.waypoint.index or not addon.segment.route then
        addon:UpdateWaypointNote()
        return
    end

    local allowArrow = addon:EnsureReachableTravelStep()
    local wp = addon.segment.route[addon.waypoint.index]
    if not wp then
        addon:UpdateWaypointNote()
        return
    end
    if wp.discovered and addon.IsCurrentSegmentFullyDiscovered
        and addon:IsCurrentSegmentFullyDiscovered()
    then
        addon:UpdateWaypointNote()
        return
    end
    local data = wp.data
    local mapID = addon:GetWaypointMapID(data)
    if not mapID and data.trigger and data.trigger.type == "zone" then
        mapID = tonumber(data.trigger.map)
    end

    if allowArrow and mapID then
        local nx, ny = addon:GetWaypointNavCoords(data)
        local wx = (tonumber(nx) or 0) / 100
        local wy = (tonumber(ny) or 0) / 100

        -- Project onto the player's current Midnight map tree so TomTom / Blizzard
        -- keep a crazy arrow + minimap tip while flying Quel'Danas → Eversong.
        local placeMap, placeX, placeY = mapID, wx, wy
        if addon.ResolveNavPlacement then
            placeMap, placeX, placeY = addon:ResolveNavPlacement(mapID, wx, wy)
            placeMap = placeMap or mapID
            placeX = placeX or wx
            placeY = placeY or wy
        end
        -- Never let a remap sit underfoot while the list pin is still elsewhere
        -- (TomTom "1 yards away" with Honeyback still at 63,26).
        if addon.NavPlacementIsUnderfoot
            and addon:NavPlacementIsUnderfoot(mapID, wx, wy, placeMap, placeX, placeY)
        then
            placeMap, placeX, placeY = mapID, wx, wy
        end
        if placeX < 0 or placeX > 1 or placeY < 0 or placeY > 1 then
            placeMap, placeX, placeY = mapID, wx, wy
        end

        local placed = false
        local isTravel = data.travel or data.taxiDest
        if addon:ShouldUseTomTom() and TomTom then
            addon.waypoint.arrow = TomTom:AddWaypoint(placeMap, placeX, placeY, {
                title = data.name,
                cleardistance = 0,
                crazy = true,
                minimap = true,
                world = true,
                persistent = false,
                from = "Exploration",
            })
            placed = addon.waypoint.arrow ~= nil
        end
        -- Travel: always SuperTrack too — TomTom may "place" without a visible arrow
        -- when autoqueue is off or maps are mid-flight aliases.
        if addon:ShouldUsePins() or not placed or isTravel then
            if placeMap and placeX and placeY
                and placeX >= 0 and placeX <= 1 and placeY >= 0 and placeY <= 1
            then
                local point = UiMapPoint.CreateFromCoordinates(placeMap, placeX, placeY)
                C_Map.SetUserWaypoint(point)
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end
    end

    addon:UpdateWaypointNote()
    addon:ActivateTrigger()
    if addon.SyncMarkUXWatcher then
        addon:SyncMarkUXWatcher()
    end
    addon:RefreshWorldMapOverlay()
    addon:RefreshMinimapOverlay()
end
