local addon = Exploration

local db2MapByName

local function manualPackForRoute(routeName)
    if not routeName then return nil end
    if routeName:find("BFA Horde") then
        return "Battle for Azeroth - Horde"
    end
    if routeName:find("BFA Alliance") then
        return "Battle for Azeroth Alliance"
    end
    return nil
end

local function ensureDB2MapCache()
    if db2MapByName then return end
    db2MapByName = {}
    if not ExplorationDB2Coords then return end
    for _, entry in pairs(ExplorationDB2Coords) do
        if entry.name and entry.map then
            local key = addon:NormalizeWaypointName(entry.name)
            if not db2MapByName[key] then
                db2MapByName[key] = entry.map
            end
        end
    end
end

function addon:LookupDB2MapForSubzone(name)
    ensureDB2MapCache()
    return db2MapByName and db2MapByName[addon:NormalizeWaypointName(name)]
end

function addon:LookupManualCoord(packName, mapID, name)
    local pack = ExplorationManualCoords and ExplorationManualCoords[packName]
    local bucket = pack and pack[mapID]
    if not bucket then return nil, nil end
    local target = addon:NormalizeWaypointName(name)
    for _, row in ipairs(bucket) do
        if type(row) == "table" and row[1] and addon:NormalizeWaypointName(row[1]) == target then
            return row[2], row[3]
        end
    end
end

function addon:GetWaypointMapID(data)
    if not data then return nil end
    return tonumber(data.navMap or data.map)
end

function addon:GetWaypointNavCoords(data)
    if not data then return nil, nil end
    if data.navX and data.navY then
        return data.navX, data.navY
    end
    return data.x, data.y
end

-- Midnight has parallel Outdoor trees (Quel'Thalas 2537 vs Eastern Kingdoms 2481).
-- Authored pins use 2395/2424; the client often reports 2567/2569 mid-flight.
-- Only alias true parallel copies of the SAME zone (same AreaTable zone bit).
-- 2565/2432 are Zul'Aman-tree maps — never treat them as Quel'Danas.
local NAV_MAP_ALIASES = {
    [2395] = { 2567, 2594 },
    [2567] = { 2395 },
    [2424] = { 2569 },
    [2569] = { 2424 },
    [2437] = { 2568 },
    [2568] = { 2437 },
}

local function tryMapPosFromWorld(worldCont, worldPos, toMap)
    if not worldCont or not worldPos or not toMap or not C_Map.GetMapPosFromWorldPos then
        return nil
    end
    local _, mapPos = C_Map.GetMapPosFromWorldPos(worldCont, worldPos, toMap)
    if mapPos and mapPos.x and mapPos.y then
        return mapPos.x, mapPos.y
    end
end

local function validMapUnitCoord(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return false end
    return x >= 0 and x <= 1 and y >= 0 and y <= 1
end

--- True when remapped placement sits under the player while the authored pin
--- is still far away (orphan/micro maps often do this — "2 yards" lies).
local function remappedPlacementIsUnderfoot(authoredMap, authoredX, authoredY, placeMap, placeX, placeY, playerMap)
    if not playerMap or not authoredMap or not placeMap then return false end
    if placeMap == authoredMap
        and math.abs((placeX or 0) - (authoredX or 0)) < 0.0005
        and math.abs((placeY or 0) - (authoredY or 0)) < 0.0005
    then
        return false
    end
    local playerPos = C_Map.GetPlayerMapPosition(playerMap, "player")
    if not playerPos then return false end

    -- Fast map% guard: remapped onto the player's map underfoot while the
    -- authored zone% is clearly elsewhere (Honeyback 63,26 vs standing 67,26).
    if placeMap == playerMap then
        local pdx = (placeX or 0) - playerPos.x
        local pdy = (placeY or 0) - playerPos.y
        local adx = (authoredX or 0) - playerPos.x
        local ady = (authoredY or 0) - playerPos.y
        if (pdx * pdx + pdy * pdy) < (0.015 * 0.015)
            and (adx * adx + ady * ady) > (0.03 * 0.03)
        then
            return true
        end
    end

    local pCont, pWorld = C_Map.GetWorldPosFromMapPos(playerMap, playerPos)
    local aCont, aWorld = C_Map.GetWorldPosFromMapPos(authoredMap, CreateVector2D(authoredX, authoredY))
    local plCont, plWorld = C_Map.GetWorldPosFromMapPos(placeMap, CreateVector2D(placeX, placeY))
    if not pCont or not pWorld or not aCont or not aWorld or not plCont or not plWorld then
        return false
    end
    if pCont ~= aCont or pCont ~= plCont then return false end
    local dxA, dyA = pWorld.x - aWorld.x, pWorld.y - aWorld.y
    local dxP, dyP = pWorld.x - plWorld.x, pWorld.y - plWorld.y
    local authoredDistSq = dxA * dxA + dyA * dyA
    local placedDistSq = dxP * dxP + dyP * dyP
    -- ~15 yd underfoot vs ~80 yd still to go on the authored pin.
    return placedDistSq < (15 * 15) and authoredDistSq > (80 * 80)
end

function addon:NavPlacementIsUnderfoot(authoredMap, authoredX, authoredY, placeMap, placeX, placeY)
    local playerMap = C_Map.GetBestMapForUnit("player")
    return remappedPlacementIsUnderfoot(
        authoredMap, authoredX, authoredY,
        placeMap, placeX, placeY,
        playerMap
    )
end

--- Pick a map/coords TomTom + Blizzard can project from the player's current tree.
--- Returns mapID, x, y in 0-1 units.
function addon:ResolveNavPlacement(mapID, x, y)
    mapID = tonumber(mapID)
    x, y = tonumber(x), tonumber(y)
    if not mapID or x == nil or y == nil then
        return mapID, x, y
    end

    local playerMap = C_Map.GetBestMapForUnit("player")
    if not playerMap or playerMap == mapID then
        return mapID, x, y
    end

    local function isAncestor(child, ancestor)
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

    local function worldOf(fromMap, fromX, fromY)
        return C_Map.GetWorldPosFromMapPos(fromMap, CreateVector2D(fromX, fromY))
    end

    local function acceptRemap(placeMap, placeX, placeY)
        if not validMapUnitCoord(placeX, placeY) then return false end
        -- Over water / Great Sea the client often has no map%. World→playerMap
        -- projection then drops Kalimdor pins underfoot mid-ocean (Camp Narache).
        local playerPos = C_Map.GetPlayerMapPosition(playerMap, "player")
        if not playerPos and placeMap == playerMap and mapID ~= playerMap then
            return false
        end
        if remappedPlacementIsUnderfoot(mapID, x, y, placeMap, placeX, placeY, playerMap) then
            return false
        end
        return true
    end

    local function tryProjectToPlayer()
        local cont, wpos = worldOf(mapID, x, y)
        if cont and wpos then
            local px, py = tryMapPosFromWorld(cont, wpos, playerMap)
            if acceptRemap(playerMap, px, py) then
                return playerMap, px, py
            end
        end
        for _, alt in ipairs(NAV_MAP_ALIASES[mapID] or {}) do
            local altCont, altWorld = worldOf(alt, x, y)
            if altCont and altWorld then
                local px, py = tryMapPosFromWorld(altCont, altWorld, playerMap)
                if acceptRemap(playerMap, px, py) then
                    return playerMap, px, py
                end
            end
        end
        return nil
    end

    local function aliasLinked(a, b)
        for _, alt in ipairs(NAV_MAP_ALIASES[a] or {}) do
            if alt == b then return true end
        end
        for _, alt in ipairs(NAV_MAP_ALIASES[b] or {}) do
            if alt == a then return true end
        end
        return false
    end

    -- Parent continent while pin is on a child zone (EK → Quel'Danas): project
    -- through world space so TomTom aims at the island, not zone% on the continent.
    if isAncestor(mapID, playerMap) then
        local projected = { tryProjectToPlayer() }
        if projected[1] then
            return unpack(projected)
        end
        return mapID, x, y
    end

    -- Child micro/city map under the authored zone: keep authored (avoids underfoot).
    if isAncestor(playerMap, mapID) then
        return mapID, x, y
    end

    -- Orphan maps (Coldridge Valley 427) are not parent-linked to their zone, so
    -- the ancestor check misses them. Never remap zone % onto an orphan/micro —
    -- TomTom then reports "2 yards" underfoot while the list still shows zone coords.
    do
        local pInfo = C_Map.GetMapInfo(playerMap)
        local mapType = pInfo and pInfo.mapType
        if mapType == Enum.UIMapType.Orphan or mapType == Enum.UIMapType.Micro then
            return mapID, x, y
        end
    end

    -- Cross-continent hops (e.g. Hillsbrad → Blasted Lands) must keep authored
    -- map/coords; projecting onto the player's zone yields out-of-range values
    -- and breaks C_Map.SetUserWaypoint (1.04, 4.13, …).
    if addon.MapsAreLocallyCompatible
        and not addon:MapsAreLocallyCompatible(mapID, playerMap)
    then
        -- Still try world projection (Great Sea / odd ocean uiMaps often fail the
        -- local-compat check but share a continent instance with Quel'Danas).
        local projected = { tryProjectToPlayer() }
        if projected[1] then
            return unpack(projected)
        end
        return mapID, x, y
    end

    -- Sibling outdoor zones (Eversong ↔ Quel'Danas) or Great Sea approaches:
    -- project through world coords when the player is far from the pin so the
    -- crazy arrow points at the island instead of copying zone% onto the wrong map.
    do
        local infoA = C_Map.GetMapInfo(mapID)
        local infoB = C_Map.GetMapInfo(playerMap)
        local parentA = infoA and infoA.parentMapID
        local parentB = infoB and infoB.parentMapID
        if parentA and parentB and parentA ~= 0 and parentA == parentB
            and not aliasLinked(mapID, playerMap)
        then
            local projected = { tryProjectToPlayer() }
            if projected[1] then
                return unpack(projected)
            end
            return mapID, x, y
        end
    end

    local projected = { tryProjectToPlayer() }
    if projected[1] then
        return unpack(projected)
    end

    -- Parallel Midnight outdoor tree (2424 ↔ 2569): switch to the alias map the
    -- client is actually on, keeping authored zone%.
    for _, alt in ipairs(NAV_MAP_ALIASES[mapID] or {}) do
        if alt == playerMap then
            return alt, x, y
        end
    end

    return mapID, x, y
end

--- World position for overlay math; remaps through ResolveNavPlacement when needed
--- so pins stay on the player's continent/instance mid-flight.
function addon:GetWaypointWorldPos(mapID, x, y)
    mapID = tonumber(mapID)
    x, y = tonumber(x), tonumber(y)
    if not mapID or x == nil or y == nil then
        return nil
    end

    local placeMap, placeX, placeY = addon:ResolveNavPlacement(mapID, x, y)
    if not placeMap then
        return nil
    end

    local continentID, worldPos = C_Map.GetWorldPosFromMapPos(placeMap, CreateVector2D(placeX, placeY))
    if continentID and worldPos then
        return continentID, worldPos
    end

    continentID, worldPos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x, y))
    if continentID and worldPos then
        return continentID, worldPos
    end

    for _, alt in ipairs(NAV_MAP_ALIASES[mapID] or {}) do
        continentID, worldPos = C_Map.GetWorldPosFromMapPos(alt, CreateVector2D(x, y))
        if continentID and worldPos then
            return continentID, worldPos
        end
    end
end

-- Boralus (1161) districts use Tiragarde (895) coords for pins / proximity.
function addon:ApplyNavMapOverrides(segment, routeName)
    if not segment or not segment.route then return end
    local packName = manualPackForRoute(routeName)
    if not packName then return end

    for _, wp in ipairs(segment.route) do
        local data = wp.data
        if not data or data.navMap or not data.name or not data.map then
            -- skip
        else
            local db2Map = addon:LookupDB2MapForSubzone(data.name)
            if db2Map and db2Map ~= data.map then
                local nx, ny = addon:LookupManualCoord(packName, db2Map, data.name)
                data.navMap = db2Map
                if nx and ny then
                    data.navX = nx
                    data.navY = ny
                end
            end
        end
    end
end

function addon:GetCharacterID()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    if not name or name == "" or not realm or realm == "" then
        return nil
    end
    return name .. "-" .. realm
end

function addon:WaypointProgressKey(data)
    if not data or not data.name then return nil end
    local name = addon:NormalizeWaypointName(data.name)
    local map = data.map or 0
    return string.format("%s|%s", name, map)
end

-- Older builds stored the active run on ExplorationDB.progress itself (account-wide),
-- so alts inherited another character's journey and had to Abandon before starting.
function addon:MigrateLegacyProgress()
    local progress = addon.data and addon.data.progress
    if type(progress) ~= "table" then return false end

    local hasLegacy = progress.activePath ~= nil
        or progress.waypointIndex ~= nil
        or progress.segmentDiscoveries ~= nil
        or progress.discoveredSubzones ~= nil
    if not hasLegacy then return false end

    local charID = addon:GetCharacterID()
    if charID then
        local saved = progress[charID]
        local hadSlot = type(saved) == "table"
        if not hadSlot then
            saved = {}
            progress[charID] = saved
        end
        -- Only adopt a legacy mid-run onto a character that already had a slot.
        -- Brand-new alts must not inherit someone else's activePath (that forced
        -- /exp abandon before Start). Discoveries can still merge below.
        if hadSlot then
            if progress.activePath and not saved.activePath then
                local pathCopy = {}
                if type(progress.activePath) == "table" then
                    for i = 1, #progress.activePath do
                        pathCopy[i] = progress.activePath[i]
                    end
                end
                saved.activePath = pathCopy
                -- Require an explicit Resume / Save before auto-login resume.
                saved.allowAutoResume = false
            end
            if progress.waypointIndex and not saved.waypointIndex then
                saved.waypointIndex = progress.waypointIndex
            end
            if progress.segmentDiscoveries and not saved.segmentDiscoveries then
                saved.segmentDiscoveries = progress.segmentDiscoveries
            end
        end
        if type(progress.discoveredSubzones) == "table" then
            saved.discoveredSubzones = saved.discoveredSubzones or {}
            for key, discovered in pairs(progress.discoveredSubzones) do
                if discovered then
                    saved.discoveredSubzones[key] = true
                end
            end
        end
    end

    progress.activePath = nil
    progress.waypointIndex = nil
    progress.segmentDiscoveries = nil
    progress.discoveredSubzones = nil
    return true
end

function addon:GetCharacterProgress(create)
    addon.data.progress = addon.data.progress or {}
    local charID = addon:GetCharacterID()
    if not charID then return nil end

    local saved = addon.data.progress[charID]
    -- Re-key case variants onto the canonical Name-Realm id for this login.
    if not saved then
        local lower = charID:lower()
        for key, value in pairs(addon.data.progress) do
            if type(key) == "string" and type(value) == "table"
                and key:lower() == lower
            then
                saved = value
                addon.data.progress[charID] = saved
                if key ~= charID then
                    addon.data.progress[key] = nil
                end
                break
            end
        end
    end
    if not saved and create then
        saved = {}
        addon.data.progress[charID] = saved
    end
    if not saved then return nil end

    saved.discoveredSubzones = saved.discoveredSubzones or {}
    -- Migrate discoveries from saves made before cross-segment history existed.
    if saved.segmentDiscoveries and saved.segmentDiscoveries[1] == nil then
        for key, discovered in pairs(saved.segmentDiscoveries) do
            if discovered then
                saved.discoveredSubzones[key] = true
            end
        end
    end

    -- Explore achievement import pre-cleared fog pins (often account-wide Explore)
    -- before this character got Discover XP. One-time wipe so only toast/Mark remain.
    if saved.fogClearMode ~= "toast" then
        wipe(saved.discoveredSubzones)
        if type(saved.segmentDiscoveries) == "table" then
            wipe(saved.segmentDiscoveries)
        end
        saved.exploreCriterionNames = nil
        saved.exploreAreaIDs = nil
        saved.fogClearMode = "toast"
        if addon.InvalidateDiscoveredLookup then
            addon:InvalidateDiscoveredLookup()
        end
    end
    return saved
end

function addon:HasSavedActiveJourney()
    local saved = addon:GetCharacterProgress(false)
    return saved and type(saved.activePath) == "table" and saved.activePath[1] ~= nil
end

function addon:ShouldAutoResumeJourney()
    local saved = addon:GetCharacterProgress(false)
    if not saved or type(saved.activePath) ~= "table" or not saved.activePath[1] then
        return false
    end
    local charID = addon:GetCharacterID()
    if saved.activeOwner and charID and saved.activeOwner ~= charID then
        -- Stale run attached to the wrong character slot — drop it.
        saved.activePath = nil
        saved.segmentDiscoveries = nil
        saved.waypointIndex = nil
        saved.allowAutoResume = nil
        saved.activeOwner = nil
        return false
    end
    -- Change/Park clears this so a parked run never jumps back on login.
    if saved.allowAutoResume == false then
        return false
    end
    -- true, or nil on legacy saves from before this flag existed.
    return true
end

-- Clear in-memory journey state without abandoning this character's saved run.
function addon:ParkActiveJourney()
    if addon.DeactivateTrigger then
        addon:DeactivateTrigger()
    end
    local saved = addon:GetCharacterProgress(false)
    if saved then
        -- Parked runs must not jump back on the next login/reload.
        saved.allowAutoResume = false
    end
    addon.active = nil
    addon.segment = { route = {} }
    addon.waypoint.index = nil
    if addon.ClearTomTomWaypoints then
        addon:ClearTomTomWaypoints()
    end
    if addon.UpdateWaypointNote then
        addon:UpdateWaypointNote()
    end
    if addon.RefreshWorldMapOverlay then
        addon:RefreshWorldMapOverlay()
    end
    if addon.RefreshMinimapOverlay then
        addon:RefreshMinimapOverlay()
    end
    if addon.ClearMarkUXState then
        addon:ClearMarkUXState()
    end
end

local discoveredLookup = {
    charID = nil,
    source = nil, -- discoveredSubzones table reference
    byName = nil, -- [normalizedName] = { [mapID] = true }
}

function addon:InvalidateDiscoveredLookup()
    discoveredLookup.charID = nil
    discoveredLookup.source = nil
    discoveredLookup.byName = nil
end

local function buildDiscoveredByName(discoveredSubzones)
    local byName = {}
    if type(discoveredSubzones) ~= "table" then
        return byName
    end
    for key, discovered in pairs(discoveredSubzones) do
        if discovered and type(key) == "string" then
            local savedName, savedMap = key:match("^(.-)|(%d+)$")
            savedMap = tonumber(savedMap)
            if savedName and savedMap then
                local norm = addon:NormalizeWaypointName(savedName)
                if norm ~= "" then
                    local bucket = byName[norm]
                    if not bucket then
                        bucket = {}
                        byName[norm] = bucket
                    end
                    bucket[savedMap] = true
                end
            end
        end
    end
    return byName
end

local function getDiscoveredByName(saved)
    if not saved or type(saved.discoveredSubzones) ~= "table" then
        return nil
    end
    local charID = addon:GetCharacterID()
    if discoveredLookup.charID == charID
        and discoveredLookup.source == saved.discoveredSubzones
        and discoveredLookup.byName
    then
        return discoveredLookup.byName
    end
    local byName = buildDiscoveredByName(saved.discoveredSubzones)
    discoveredLookup.charID = charID
    discoveredLookup.source = saved.discoveredSubzones
    discoveredLookup.byName = byName
    return byName
end

function addon:IsWaypointPreviouslyDiscovered(data)
    if not data or data.travel then return false end
    local saved = addon:GetCharacterProgress(false)
    if not saved or not saved.discoveredSubzones then return false end

    -- Toast-strict / Mark only: never pre-clear from Explore achievement criteria.
    local name = data.name and addon:NormalizeWaypointName(addon:LocalizedString(data.name))
    local key = addon:WaypointProgressKey(data)
    if key and saved.discoveredSubzones[key] == true then
        return true
    end
    -- Discover toasts on a child map (Boralus 1161) may have been keyed to that
    -- map while the curated pin lives on the parent (Tiragarde 895), or reverse.
    local pinMap = tonumber(data.map)
    if not name or not pinMap then
        return false
    end

    local maps = getDiscoveredByName(saved)
    maps = maps and maps[name]
    if not maps then
        return false
    end
    if maps[pinMap] then
        return true
    end

    local pinZone = addon.ResolveExplorationMapID and addon:ResolveExplorationMapID(pinMap) or pinMap
    for savedMap in pairs(maps) do
        if addon.MapsAreParentOrChild and addon:MapsAreParentOrChild(pinMap, savedMap) then
            return true
        end
        local savedZone = addon.ResolveExplorationMapID and addon:ResolveExplorationMapID(savedMap) or savedMap
        if pinZone and savedZone and pinZone == savedZone then
            return true
        end
    end
    return false
end

function addon:ApplyCharacterDiscoveries(segment)
    if not segment or not segment.route then return end
    -- Warm the name→map index once for this apply pass.
    local saved = addon:GetCharacterProgress(false)
    if saved then
        getDiscoveredByName(saved)
    end
    for _, wp in ipairs(segment.route) do
        if wp.data and addon:IsWaypointPreviouslyDiscovered(wp.data) then
            wp.discovered = true
        end
    end
end

function addon:SaveProgress()
    if not addon.active or not addon.segment.route or not addon.waypoint.index then
        return
    end
    local saved = addon:GetCharacterProgress(true)
    if not saved then return end
    local discoveries = {}
    local addedDiscovery = false
    for _, wp in ipairs(addon.segment.route) do
        if wp.discovered and wp.data then
            local key = addon:WaypointProgressKey(wp.data)
            if key then
                discoveries[key] = true
                if not wp.data.travel then
                    if saved.discoveredSubzones[key] ~= true then
                        addedDiscovery = true
                    end
                    saved.discoveredSubzones[key] = true
                end
            end
        end
    end
    if addedDiscovery and addon.InvalidateDiscoveredLookup then
        addon:InvalidateDiscoveredLookup()
    end
    -- Copy path by value so characters never share one activePath table reference.
    local pathCopy = {}
    for i = 1, #addon.active.path do
        pathCopy[i] = addon.active.path[i]
    end
    saved.activePath = pathCopy
    saved.segmentDiscoveries = discoveries
    saved.waypointIndex = addon.waypoint.index
    saved.activeOwner = addon:GetCharacterID()
    saved.allowAutoResume = true
end

function addon:ClearProgress()
    local saved = addon:GetCharacterProgress(false)
    if not saved then return end
    -- Abandon only this character's active run; other characters keep theirs.
    saved.activePath = nil
    saved.segmentDiscoveries = nil
    saved.waypointIndex = nil
    saved.allowAutoResume = nil
    saved.activeOwner = nil
end

function addon:ResumeProgress()
    addon.data.progress = addon.data.progress or {}
    if addon.MigrateLegacyProgress then
        addon:MigrateLegacyProgress()
    end
    local saved = addon:GetCharacterProgress(false)
    if not saved or type(saved.activePath) ~= "table" or not saved.activePath[1] then
        return false
    end

    local charID = addon:GetCharacterID()
    if saved.activeOwner and charID and saved.activeOwner ~= charID then
        saved.activePath = nil
        saved.segmentDiscoveries = nil
        saved.waypointIndex = nil
        saved.allowAutoResume = nil
        saved.activeOwner = nil
        return false
    end

    local rootName = saved.activePath[1]
    if not addon.menu[rootName] then
        -- The route was removed or renamed. Drop only the stale active run;
        -- discoveries remain valid for other routes on this character.
        saved.activePath = nil
        saved.segmentDiscoveries = nil
        saved.waypointIndex = nil
        saved.allowAutoResume = nil
        saved.activeOwner = nil
        return false
    end

    local current = addon.menu[rootName]
    local truncated = false
    local orphanLeaf = nil
    for i = 2, #saved.activePath do
        local found = false
        if current.children then
            for _, child in ipairs(current.children) do
                if child.name == saved.activePath[i] then
                    current = child
                    found = true
                    break
                end
            end
        end
        if not found then
            -- Mid-path travel used to be menu children; parent now inlines them.
            truncated = true
            orphanLeaf = saved.activePath[i]
            break
        end
    end

    addon.active = current
    if current.children and #current.children > 0 then
        addon.active = addon:FindFirstLeaf(current)
    end
    local leaf = addon.active.path[#addon.active.path]
    leaf = addon:ResolvePathRouteName(leaf)
    -- Keep active.path leaf in sync with the resolved waypoint route.
    if leaf ~= addon.active.path[#addon.active.path] then
        local resolvedNode = nil
        if current.children then
            for _, child in ipairs(current.children) do
                if child.name == leaf then
                    resolvedNode = child
                    break
                end
            end
        end
        if resolvedNode then
            addon.active = resolvedNode
        else
            addon.active.path[#addon.active.path] = leaf
        end
    end
    addon.segment = addon:LoadWaypoints(leaf)
    local discoveries = saved.segmentDiscoveries or {}
    if discoveries["enter the den"] then
        discoveries["head to the den entrance"] = true
    end
    local legacy = discoveries[1] ~= nil
    if legacy then
        for i, discovered in ipairs(discoveries) do
            if addon.segment.route[i] then
                addon.segment.route[i].discovered = discovered
            end
        end
    else
        local nameCounts = {}
        for _, wp in ipairs(addon.segment.route) do
            local wpName = wp.data and wp.data.name
            if wpName then
                local norm = addon:NormalizeWaypointName(wpName)
                nameCounts[norm] = (nameCounts[norm] or 0) + 1
            end
        end
        for _, wp in ipairs(addon.segment.route) do
            if wp.data then
                local key = addon:WaypointProgressKey(wp.data)
                local norm = addon:NormalizeWaypointName(wp.data.name)
                if key and discoveries[key] then
                    wp.discovered = true
                elseif discoveries[norm] and nameCounts[norm] == 1 then
                    -- Legacy name-only saves: apply only when the name is unique.
                    wp.discovered = true
                elseif addon:IsWaypointPreviouslyDiscovered(wp.data) then
                    -- City/micro Discover keys (e.g. Boralus 1161) vs parent-zone pins.
                    wp.discovered = true
                end
            end
        end
    end

    -- After collapsing travel children into the parent path, jump to the player's
    -- current zone so mainland waypoints aren't replayed.
    if truncated and addon.segment.route then
        local playerMap = C_Map.GetBestMapForUnit("player")
        local startIdx = nil
        if playerMap then
            for i, wp in ipairs(addon.segment.route) do
                local data = wp.data
                if data and data.map == playerMap and not data.travel then
                    startIdx = i
                    break
                end
            end
            if not startIdx then
                for i, wp in ipairs(addon.segment.route) do
                    local data = wp.data
                    if data and data.map == playerMap then
                        startIdx = i
                        break
                    end
                end
            end
        end
        if not startIdx and orphanLeaf then
            local needle = orphanLeaf:match("To ([^%-]+)")
            if needle then
                needle = needle:gsub("%s+$", "")
                for i, wp in ipairs(addon.segment.route) do
                    local name = wp.data and wp.data.name
                    if name and name:find(needle, 1, true) then
                        startIdx = i
                        break
                    end
                end
            end
        end
        if startIdx then
            for i = 1, startIdx - 1 do
                addon.segment.route[i].discovered = true
            end
            addon.waypoint.index = startIdx
        end
    end

    addon.waypoint.index = addon.waypoint.index or saved.waypointIndex or 1
    if addon.waypoint.index > #addon.segment.route then
        addon.waypoint.index = #addon.segment.route
    end
    for i = 1, addon.waypoint.index - 1 do
        local wp = addon.segment.route[i]
        if wp and not wp.discovered and wp.data and wp.data.travel then
            addon.waypoint.index = i
            break
        end
    end
    addon:DetermineNextWaypoint()
    addon:ResetSubzoneTracking()
    addon:UpdateWaypointArrow()
    saved.activeOwner = charID or saved.activeOwner
    saved.allowAutoResume = true
    if addon.ui and addon.ui.Refresh then addon.ui:Refresh() end
    return true
end

function addon:ResolvePathRouteName(name)
    -- Path wrappers that only contain a faction/condition switch (e.g. WoD - Exploration)
    -- must resolve to the real waypoint list before LoadWaypoints.
    local guard = 0
    while name and guard < 10 do
        guard = guard + 1
        local segment = addon.data.routes and addon.data.routes[name]
        if not segment or not segment.route or #segment.route ~= 1 then
            return name
        end
        local only = segment.route[1]
        if type(only) ~= "table" or not only.switch then
            return name
        end
        local resolved = addon:ResolveRouteEntry(only)
        if not resolved or resolved == name or not addon.data.routes[resolved] then
            return name
        end
        name = resolved
    end
    return name
end

local function appendWaypointRows(dest, waypoint)
    if type(waypoint) ~= "table" then return end
    if waypoint.switch then
        -- Mid-path travel: splice the resolved travel route in place.
        local travelName = addon:ResolveRouteEntry(waypoint)
        local travel = travelName and addon.data.routes and addon.data.routes[travelName]
        if travel and travel.route then
            for _, step in ipairs(travel.route) do
                appendWaypointRows(dest, step)
            end
        end
        return
    end
    if waypoint.map or waypoint.x or waypoint.name then
        -- Travel/navigation steps are hand-authored and must never be filtered
        -- by the subzone name filter (e.g. "Entrance" matches INTERIOR_PATTERNS).
        local Filter = ExplorationSubzoneFilter
        if not waypoint.travel and Filter and Filter.IsExcluded
            and Filter:IsExcluded(
                waypoint.name,
                waypoint.areaID or waypoint.explorationID,
                waypoint.map
            )
        then
            return
        end
        dest[#dest + 1] = { discovered = false, data = waypoint }
    end
end

function addon:LoadWaypoints(name)
    name = addon:ResolvePathRouteName(name)
    local segment = addon.data.routes[name]
    local newSegment = { map = segment and segment.map, route = {} }
    if segment and segment.route then
        for _, waypoint in ipairs(segment.route) do
            appendWaypointRows(newSegment.route, waypoint)
        end
    end
    addon:MergeLearnedWaypoints(newSegment, name)
    addon:ApplyCoordAdjustments(newSegment, name)
    addon:ApplyNavMapOverrides(newSegment, name)
    -- Fog pins clear only from Discover toasts (or Mark). Do not import Explore
    -- achievement criteria — that pre-cleared pins before XP fired.
    local saved = addon:GetCharacterProgress(false)
    if saved then
        saved.exploreCriterionNames = nil
        saved.exploreAreaIDs = nil
    end
    addon:ApplyCharacterDiscoveries(newSegment)
    return newSegment
end

function addon:ClearActive()
    addon:DeactivateTrigger()
    if addon.ClearMarkUXState then
        addon:ClearMarkUXState()
    end
    addon:ClearProgress()
    addon:ResetSubzoneTracking()
    addon.active = nil
    addon.segment = { route = {} }
    addon.waypoint.index = nil
    addon:ClearTomTomWaypoints()
    addon:UpdateWaypointNote()
    addon:RefreshWorldMapOverlay()
    addon:RefreshMinimapOverlay()
    if addon.ui and addon.ui.Refresh then addon.ui:Refresh() end
end

function addon:UpdateActive(item)
    -- Starting a journey always replaces any current/parked run for this character.
    if addon.DeactivateTrigger then
        addon:DeactivateTrigger()
    end
    if addon.active and addon.SaveProgress then
        addon:SaveProgress()
    end
    local saved = addon:GetCharacterProgress(true)
    if saved then
        saved.activePath = nil
        saved.segmentDiscoveries = nil
        saved.waypointIndex = nil
        saved.allowAutoResume = nil
        saved.activeOwner = nil
    end

    addon.active = addon:FindFirstLeaf(item)
    addon:ResetSubzoneTracking()
    local leaf = addon.active.path[#addon.active.path]
    leaf = addon:ResolvePathRouteName(leaf)
    -- Copy path instead of mutating the shared menu node.
    if leaf ~= addon.active.path[#addon.active.path] then
        local pathCopy = {}
        for i = 1, #addon.active.path do
            pathCopy[i] = addon.active.path[i]
        end
        pathCopy[#pathCopy] = leaf
        addon.active = {
            display = addon.active.display,
            name = leaf,
            path = pathCopy,
            children = {},
        }
    end
    addon.segment = addon:LoadWaypoints(leaf)
    addon.waypoint.index = addon:SelectPendingWaypointIndex() or 1
    addon:UpdateWaypointArrow()
    addon:RefreshWorldMapOverlay()
    addon:RefreshMinimapOverlay()
    if addon.ui and addon.ui.SegmentFrame and addon.ui.SegmentFrame.Refresh then
        addon.ui.SegmentFrame:Refresh()
    elseif addon.ui and addon.ui.Refresh then
        addon.ui:Refresh()
    end
    addon:SaveProgress()
end

function addon:FindNextLeaf(menu, path)
    if not menu or not path or #path < 2 then return nil end
    local indices = {}
    local current = menu
    for i = 2, #path do
        if not current.children then return nil end
        local found = false
        for j, item in ipairs(current.children) do
            if item.name == path[i] then
                indices[#indices + 1] = j
                current = item
                found = true
                break
            end
        end
        if not found then return nil end
    end
    local working = { unpack(indices) }
    local depth = #working
    current = menu
    for i = 1, depth - 1 do
        current = current.children[working[i]]
    end
    while depth > 0 do
        if current.children and working[depth] < #current.children then
            working[depth] = working[depth] + 1
            current = menu
            for i = 1, depth - 1 do current = current.children[working[i]] end
            current = current.children[working[depth]]
            while current.children and #current.children > 0 do
                current = current.children[1]
            end
            return current
        else
            depth = depth - 1
            if depth > 0 then
                current = menu
                for i = 1, depth - 1 do current = current.children[working[i]] end
            end
        end
    end
    return nil
end

function addon:FirstUndiscoveredWaypoint()
    if not addon.segment or not addon.segment.route then return nil end
    for i, wp in ipairs(addon.segment.route) do
        if not wp.discovered then
            return i
        end
    end
    return nil
end

function addon:IsNearestUndiscoveredMode()
    return addon.data
        and addon.data.settings
        and addon.data.settings.nearestUndiscovered == true
end

local function playerWorldPos()
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerPos = playerMapID and C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerMapID or not playerPos then return nil end
    return C_Map.GetWorldPosFromMapPos(playerMapID, playerPos)
end

local function waypointWorldDistSq(playerContinent, playerWorld, data)
    if not data or not playerContinent or not playerWorld then return nil end
    local mapID = addon:GetWaypointMapID(data)
    local x, y = addon:GetWaypointNavCoords(data)
    if not mapID or not x or not y then return nil end
    local continent, worldPos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x / 100, y / 100))
    if not continent or not worldPos or continent ~= playerContinent then return nil end
    local dx = playerWorld.x - worldPos.x
    local dy = playerWorld.y - worldPos.y
    return dx * dx + dy * dy
end

--- Index of the nearest undiscovered pin in the active segment (world yards).
--- Prefers fog/Discover pins over travel breadcrumbs.
--- Zone-complete: while the route's current zone still has fog pins, only
--- consider pins on that map (or parent/child maps). Never yank the player
--- into a later zone early.
function addon:NearestUndiscoveredWaypoint()
    if not addon.segment or not addon.segment.route then return nil end
    local playerContinent, playerWorld = playerWorldPos()

    -- Active zone = map of the first undiscovered fog pin in route order.
    local activeMap = nil
    for _, wp in ipairs(addon.segment.route) do
        if not wp.discovered and wp.data and not wp.data.travel then
            local prox = addon.WaypointCompletesOnProximity
                and addon:WaypointCompletesOnProximity(wp.data)
            if not prox then
                activeMap = tonumber(wp.data.map)
                break
            end
        end
    end

    local function sameZone(data)
        if not activeMap then return true end
        local mid = tonumber(data and data.map)
        if not mid then return false end
        if mid == activeMap then return true end
        if addon.MapsAreParentOrChild and addon:MapsAreParentOrChild(mid, activeMap) then
            return true
        end
        if addon.ResolveExplorationMapID then
            local a = addon:ResolveExplorationMapID(mid) or mid
            local b = addon:ResolveExplorationMapID(activeMap) or activeMap
            if a and b and a == b then return true end
        end
        return false
    end

    local bestFog, bestFogDist = nil, nil
    local bestAny, bestAnyDist = nil, nil
    local firstFog, firstAny = nil, nil

    for i, wp in ipairs(addon.segment.route) do
        if not wp.discovered and wp.data and sameZone(wp.data) then
            if not firstAny then firstAny = i end
            local isTravel = wp.data.travel
                or (addon.WaypointCompletesOnProximity and addon:WaypointCompletesOnProximity(wp.data))
            if not isTravel and not firstFog then
                firstFog = i
            end

            local distSq = playerContinent and waypointWorldDistSq(playerContinent, playerWorld, wp.data)
            if distSq then
                if not isTravel and (not bestFogDist or distSq < bestFogDist) then
                    bestFog, bestFogDist = i, distSq
                end
                if not bestAnyDist or distSq < bestAnyDist then
                    bestAny, bestAnyDist = i, distSq
                end
            end
        end
    end

    return bestFog or bestAny or firstFog or firstAny
end

function addon:SelectPendingWaypointIndex()
    if addon:IsNearestUndiscoveredMode() then
        return addon:NearestUndiscoveredWaypoint()
    end
    return addon:FirstUndiscoveredWaypoint()
end

function addon:IsCurrentSegmentFullyDiscovered()
    return addon.segment
        and addon.segment.route
        and #addon.segment.route > 0
        and addon:FirstUndiscoveredWaypoint() == nil
end

function addon:DetermineNextWaypoint()
    if not addon.segment.route then return end
    while addon.segment.route[addon.waypoint.index]
        and addon.segment.route[addon.waypoint.index].discovered do
        local pending = addon:SelectPendingWaypointIndex()
        if pending then
            addon.waypoint.index = pending
            addon:UpdateWaypointArrow()
            break
        end
        -- Persist the completed segment before replacing it with the next
        -- leaf (or clearing the active journey).
        addon:SaveProgress()
        local nextLeaf = addon:FindNextLeaf(addon.menu[addon.active.path[1]], addon.active.path)
        if nextLeaf then
            addon.active = nextLeaf
            local section = addon.active.path[#addon.active.path]
            addon:AnnounceSegment(section)
            addon.segment = addon:LoadWaypoints(section)
            addon.waypoint.index = addon:SelectPendingWaypointIndex() or 1
            addon:SaveProgress()
            break
        else
            addon:ClearActive()
            print("|cff00ccffExploration:|r Mega-journey complete!")
            break
        end
    end
    -- Nearest mode: retarget if a closer undiscovered fog pin exists.
    if addon:IsNearestUndiscoveredMode()
        and addon.waypoint.index
        and addon.segment.route[addon.waypoint.index]
        and not addon.segment.route[addon.waypoint.index].discovered
    then
        local nearest = addon:NearestUndiscoveredWaypoint()
        if nearest and nearest ~= addon.waypoint.index then
            addon.waypoint.index = nearest
        end
    end
    addon:UpdateWaypointArrow()
    addon:SaveProgress()
end

function addon:AdvanceStep(source)
    if addon.MarkCurrentDiscovered then
        return addon:MarkCurrentDiscovered(source or "button")
    end
    if not addon.waypoint.index or not addon.segment.route[addon.waypoint.index] then
        return false
    end
    addon.segment.route[addon.waypoint.index].discovered = true
    if addon.ArmProximityRearmFromPlayer then
        addon:ArmProximityRearmFromPlayer()
    end
    addon:DetermineNextWaypoint()
    if addon.ui and addon.ui.SegmentFrame and addon.ui.SegmentFrame.Refresh then
        addon.ui.SegmentFrame:Refresh()
    end
    addon:RefreshProgressUI()
    return true
end

function addon:PreviousStep()
    if not addon.waypoint.index or addon.waypoint.index <= 1 then return end
    addon.waypoint.index = addon.waypoint.index - 1
    addon.segment.route[addon.waypoint.index].discovered = false
    addon:UpdateWaypointArrow()
    addon:SaveProgress()
    if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
end

function addon:FindPreviousLeaf(menu, path)
    if not menu or not path or #path < 2 then return nil end
    local indices = {}
    local current = menu
    for i = 2, #path do
        if not current.children then return nil end
        local found = false
        for j, item in ipairs(current.children) do
            if item.name == path[i] then
                indices[#indices + 1] = j
                current = item
                found = true
                break
            end
        end
        if not found then return nil end
    end
    local working = { unpack(indices) }
    local depth = #working
    current = menu
    for i = 1, depth - 1 do
        current = current.children[working[i]]
    end
    while depth > 0 do
        if current.children and working[depth] > 1 then
            working[depth] = working[depth] - 1
            current = menu
            for i = 1, depth - 1 do current = current.children[working[i]] end
            current = current.children[working[depth]]
            while current.children and #current.children > 0 do
                current = current.children[#current.children]
            end
            return current
        else
            depth = depth - 1
            if depth > 0 then
                current = menu
                for i = 1, depth - 1 do current = current.children[working[i]] end
            end
        end
    end
    return nil
end

function addon:GetAllLeaves(node)
    local leaves = {}
    local function collect(n)
        if not n.children or #n.children == 0 then
            leaves[#leaves + 1] = n
        else
            for _, child in ipairs(n.children) do
                collect(child)
            end
        end
    end
    collect(node)
    return leaves
end

function addon:JumpToSegment(leaf)
    if not leaf then return end
    if leaf.children and #leaf.children > 0 then
        leaf = addon:FindFirstLeaf(leaf)
    end
    -- Preserve discoveries from the route being replaced.
    addon:SaveProgress()
    addon.active = leaf
    local section = addon:ResolvePathRouteName(leaf.path[#leaf.path])
    if section ~= leaf.path[#leaf.path] then
        leaf.path[#leaf.path] = section
    end
    addon.segment = addon:LoadWaypoints(section)
    addon.waypoint.index = 1
    addon:AnnounceSegment(section)
    addon:UpdateWaypointArrow()
    addon:RefreshWorldMapOverlay()
    addon:RefreshMinimapOverlay()
    if addon.ui and addon.ui.Refresh then addon.ui:Refresh() end
    addon:SaveProgress()
end

function addon:JumpToPreviousSegment()
    if not addon.active then return end
    addon:JumpToSegment(addon:FindPreviousLeaf(addon.menu[addon.active.path[1]], addon.active.path))
end

function addon:JumpToNextSegment()
    if not addon.active then return end
    addon:JumpToSegment(addon:FindNextLeaf(addon.menu[addon.active.path[1]], addon.active.path))
end

--- Client-localized area name for an AreaTable ID, when available.
function addon:LocalizedAreaName(areaID)
    areaID = tonumber(areaID)
    if not areaID then return nil end
    if C_Map and C_Map.GetAreaInfo then
        local ok, info = pcall(C_Map.GetAreaInfo, areaID)
        if ok and info then
            if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
                return info.name
            end
            if type(info) == "string" and info ~= "" then
                return info
            end
        end
    end
    return nil
end

function addon:LocalizedString(text)
    return text or ""
end

--- Display name for a pin: prefer localized AreaTable name when areaID is set.
function addon:GetWaypointDisplayName(data)
    if not data then return "" end
    local areaID = tonumber(data.areaID or data.explorationID)
    if areaID then
        local localized = addon:LocalizedAreaName(areaID)
        if localized then return localized end
    end
    return data.name or ""
end
