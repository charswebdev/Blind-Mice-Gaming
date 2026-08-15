local addon = Exploration

local PROXIMITY_MATCH_RADIUS = 1.0
local PROXIMITY_AT_PIN_RADIUS = 20 -- yards; matches default proximity trigger clear radius
-- Keep small: Quel'Danas Armory (~48,30) must not stick onto Harbor curated pins.
local MAX_ADJUST_DIST = 5 -- map percent; discovery nudges farther than this are discarded

local DISCOVERY_NAME_ALIASES = {
    ["ironclad overlook"] = "ironmaul overlook",
}

-- Leading articles stripped once (any locale) after lowercasing.
local LEADING_ARTICLES = {
    the = true,
    die = true,
    der = true,
    das = true,
    dem = true,
    den = true,
    les = true,
    des = true,
    le = true,
    la = true,
    el = true,
    los = true,
    las = true,
}

local normalizeCache = {}
-- Per-route caches for backfill / map resolution (built once per login).
local staticNameCache = {} -- [routeName] = { [normName] = true }
local mapCountCache = {} -- [routeName] = { [mapID] = count }
local resolveMapCache = {} -- [mapID] = explorationMapID

local function waypointPinRadius(data)
    local trigger = data and data.trigger
    if trigger and trigger.type == "proximity" and trigger.radius then
        return trigger.radius
    end
    return PROXIMITY_AT_PIN_RADIUS
end

-- True when player position is within pin clear range of stored waypoint coords.
local function isAtWaypointPin(data, mapID, x, y)
    if not data or not mapID or not x or not y then
        return false
    end
    local navMap = addon:GetWaypointMapID(data)
    local nx, ny = addon:GetWaypointNavCoords(data)
    if not navMap or not nx or not ny then return false end

    local wpX = nx / 100
    local wpY = ny / 100
    local playerX = x / 100
    local playerY = y / 100

    local continent, wpWorld = C_Map.GetWorldPosFromMapPos(navMap, CreateVector2D(wpX, wpY))
    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(playerX, playerY))
    if not continent or not wpWorld or not playerContinent or not playerWorld then
        return false
    end
    if continent ~= playerContinent then return false end

    local dx = playerWorld.x - wpWorld.x
    local dy = playerWorld.y - wpWorld.y
    local radius = waypointPinRadius(data)
    return dx * dx + dy * dy <= radius * radius
end

function addon:NormalizeWaypointName(name)
    if not name then return "" end
    local cached = normalizeCache[name]
    if cached then return cached end

    -- Strip leading articles after lowercasing so "The Ring of Blood" and
    -- generated alias keys ("the ring of blood") normalize identically.
    -- Collapse curly/smart apostrophes so Discover toasts match curated names
    -- (e.g. Rhonin’s Shield ↔ Rhonin's Shield).
    local lower = name:lower()
    if lower:find("\226", 1, true) or lower:find("`", 1, true) then
        lower = lower
            :gsub("\226\128\152", "'") -- U+2018 LEFT SINGLE QUOTATION MARK
            :gsub("\226\128\153", "'") -- U+2019 RIGHT SINGLE QUOTATION MARK
            :gsub("`", "'")
    end
    if lower:sub(1, 2) == "l'" then
        lower = lower:sub(3)
    else
        local first, rest = lower:match("^(%S+)%s+(.+)$")
        if first and rest and LEADING_ARTICLES[first] then
            lower = rest
        end
    end
    local result = DISCOVERY_NAME_ALIASES[lower] or lower
    normalizeCache[name] = result
    return result
end

function addon:InvalidateRouteLookupCaches()
    wipe(normalizeCache)
    wipe(staticNameCache)
    wipe(mapCountCache)
    wipe(resolveMapCache)
end

function addon:RouteHasWaypoint(route, name)
    if not route or not name then return false end
    local target = addon:NormalizeWaypointName(addon:LocalizedString(name))
    for _, wp in ipairs(route) do
        local wpName = wp.data and wp.data.name
        if wpName and addon:NormalizeWaypointName(addon:LocalizedString(wpName)) == target then
            return true
        end
    end
    return false
end

local function waypointWorldDistSq(mapID, x, y, wp)
    local data = wp and wp.data
    if not data or not x or not y then
        return nil
    end
    local wpMap = addon:GetWaypointMapID(data)
    local nx, ny = addon:GetWaypointNavCoords(data)
    if not wpMap or not nx or not ny then
        return nil
    end
    local wpX, wpY = nx / 100, ny / 100
    local playerX, playerY = x / 100, y / 100
    local continent, wpWorld = C_Map.GetWorldPosFromMapPos(wpMap, CreateVector2D(wpX, wpY))
    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(playerX, playerY))
    if not continent or not wpWorld or not playerContinent or not playerWorld then
        return nil
    end
    if continent ~= playerContinent then
        return nil
    end
    local dx = playerWorld.x - wpWorld.x
    local dy = playerWorld.y - wpWorld.y
    return dx * dx + dy * dy
end

local function routeWpData(wp)
    if not wp then return nil end
    return wp.data or wp
end

function addon:IsCuratedStaticRoute(routeName)
    if not routeName then return false end
    local route = addon.data and addon.data.routes and addon.data.routes[routeName]
    return route and route.curated == true
end

function addon:PurgeLearnedWaypointsForRoute(routeName)
    local account = addon.data and addon.data.account
    local learned = account and account.learnedWaypoints
    if not learned or not routeName then return 0 end
    local route = addon.data.routes and addon.data.routes[routeName]
    local list = route and route.route
    if not list then return 0 end

    local names = {}
    for _, wp in ipairs(list) do
        if wp.name then
            names[addon:NormalizeWaypointName(wp.name)] = true
        end
    end

    local removed = 0
    for key, entry in pairs(learned) do
        if type(entry) == "table" and entry.name
            and names[addon:NormalizeWaypointName(entry.name)]
        then
            learned[key] = nil
            removed = removed + 1
        end
    end
    return removed
end

function addon:ClearProgressForRoute(routeName)
    if not routeName or not addon.data or not addon.data.progress then return 0 end
    local cleared = 0
    for charID, saved in pairs(addon.data.progress) do
        if type(saved) == "table" and saved.activePath then
            local leaf = saved.activePath[#saved.activePath]
            if leaf == routeName then
                -- Curated route revisions invalidate the active run, not the
                -- character's permanent record of discovered subzones.
                saved.activePath = nil
                saved.segmentDiscoveries = nil
                saved.waypointIndex = nil
                cleared = cleared + 1
            end
        end
    end
    if addon.active and addon.active.path
        and addon.active.path[#addon.active.path] == routeName
    then
        addon:ClearActive()
    end
    return cleared
end

function addon:MigrateCuratedRouteRevisions()
    local account = addon.data and addon.data.account
    if not account or not addon.data.routes then return 0 end
    account.routeRevisions = account.routeRevisions or {}
    local changed = 0

    for routeName, route in pairs(addon.data.routes) do
        if route.curated and route.dataVersion then
            local seen = account.routeRevisions[routeName]
            if seen ~= route.dataVersion then
                -- Purge corrupted inserts/nudges only. Never clear segment progress —
                -- wiping sessions on dataVersion bumps made Classic EK abandon on
                -- every /reload after the curated-route rollout.
                local wiped = 0
                if addon.PurgeRouteCoordAdjustments then
                    wiped = wiped + (addon:PurgeRouteCoordAdjustments(routeName) or 0)
                end
                if addon.PurgeRouteLearnedInserts then
                    wiped = wiped + (addon:PurgeRouteLearnedInserts(routeName) or 0)
                end
                wiped = wiped + addon:PurgeLearnedWaypointsForRoute(routeName)
                -- Relocated Explore pins: drop false proximity/Mark saves so the
                -- new coords are not skipped as "already discovered".
                if type(route.forgetDiscoveries) == "table" and addon.ForgetCharacterDiscoveries then
                    wiped = wiped + (addon:ForgetCharacterDiscoveries(route.forgetDiscoveries) or 0)
                end
                account.routeRevisions[routeName] = route.dataVersion
                changed = changed + 1
                if wiped > 0 then
                    print(string.format(
                        "|cff00ccffExploration:|r Updated %s (data v%d): cleared %d outdated pin adjust/insert(s).",
                        routeName,
                        route.dataVersion,
                        wiped
                    ))
                end
            end
        end
    end
    return changed
end

--- Clear matching discoveredSubzones / segmentDiscoveries keys for every character.
--- Accepts mixed forgetDiscoveries lists:
---   "Name"                  → wipe that name on every map
---   { name = "Name", map = N } → wipe only name|N
--- Used when curated pin coords were wrong and proximity/Mark saved a false clear.
function addon:ForgetCharacterDiscoveries(entries)
    if type(entries) ~= "table" or not addon.data or not addon.data.progress then
        return 0
    end

    -- anyMap[normalizedName] = true  → wipe all maps for that name
    -- scoped[normalizedName][mapID] = true → wipe only that map
    local anyMap = {}
    local scoped = {}

    for _, entry in ipairs(entries) do
        if type(entry) == "string" and entry ~= "" then
            anyMap[addon:NormalizeWaypointName(entry)] = true
        elseif type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
            local key = addon:NormalizeWaypointName(entry.name)
            local mapID = tonumber(entry.map)
            if mapID then
                scoped[key] = scoped[key] or {}
                scoped[key][mapID] = true
            else
                anyMap[key] = true
            end
        end
    end
    if not next(anyMap) and not next(scoped) then
        return 0
    end

    local function shouldWipe(savedName, savedMap)
        local norm = addon:NormalizeWaypointName(savedName)
        if anyMap[norm] then
            return true
        end
        local maps = scoped[norm]
        return maps and savedMap and maps[savedMap] or false
    end

    local wiped = 0
    for _, saved in pairs(addon.data.progress) do
        if type(saved) == "table" and type(saved.discoveredSubzones) == "table" then
            for key in pairs(saved.discoveredSubzones) do
                if type(key) == "string" then
                    local savedName, savedMap = key:match("^(.-)|(%d+)$")
                    savedMap = tonumber(savedMap)
                    if savedName and shouldWipe(savedName, savedMap) then
                        saved.discoveredSubzones[key] = nil
                        wiped = wiped + 1
                    end
                end
            end
        end
        if type(saved) == "table" and type(saved.segmentDiscoveries) == "table" then
            for key in pairs(saved.segmentDiscoveries) do
                if type(key) == "string" then
                    local savedName, savedMap = key:match("^(.-)|(%d+)$")
                    savedMap = tonumber(savedMap)
                    if savedName and shouldWipe(savedName, savedMap) then
                        saved.segmentDiscoveries[key] = nil
                    end
                end
            end
        end
    end
    return wiped
end

--- Every-login purge for routes flagged purgeLearned = true (dense layouts).
--- Call after BackfillLearnedRouteInserts so autodug inserts cannot stick.
function addon:PurgeFlaggedRouteLearning()
    if not addon.data or not addon.data.routes then
        return 0
    end
    local wiped = 0
    for routeName, route in pairs(addon.data.routes) do
        if type(route) == "table" and route.purgeLearned then
            if addon.PurgeRouteCoordAdjustments then
                wiped = wiped + (addon:PurgeRouteCoordAdjustments(routeName) or 0)
            end
            if addon.PurgeRouteLearnedInserts then
                wiped = wiped + (addon:PurgeRouteLearnedInserts(routeName) or 0)
            end
        end
    end
    return wiped
end

-- Map-percent distance for same-map insert scoring (avoids C_Map world conversions).
local function routeWpMapDistSq(mapID, x, y, wp)
    local data = routeWpData(wp)
    if not data or data.travel or not mapID or not x or not y then
        return nil
    end
    local wpMap = data.map
    if not wpMap or wpMap ~= mapID then
        return nil
    end
    local nx, ny = data.x, data.y
    if not nx or not ny then
        return nil
    end
    local dx, dy = x - nx, y - ny
    return dx * dx + dy * dy
end

local function sameMapRange(route, mapID)
    local firstSame, lastSame = nil, nil
    if not mapID then return nil, nil end
    for i, wp in ipairs(route) do
        local data = routeWpData(wp)
        local wpMap = data and data.map
        if data and not data.travel and wpMap
            and (wpMap == mapID
                or (addon.MapsAreLocallyCompatible and addon:MapsAreLocallyCompatible(wpMap, mapID)))
        then
            firstSame = firstSame or i
            lastSame = i
        end
    end
    return firstSame, lastSame
end

function addon:BestInsertIndex(route, mapID, x, y)
    if not route then return 1 end
    if #route == 0 then return 1 end
    if not mapID or not x or not y then
        local idx = addon.waypoint.index or #route
        return math.min(idx + 1, #route + 1)
    end

    -- Keep new discoveries inside the zone block they belong to when the
    -- active path spans multiple maps (e.g. WoD - Exploration).
    local firstSame, lastSame = sameMapRange(route, mapID)
    local lo, hi = 1, #route + 1
    if firstSame and lastSame then
        lo, hi = firstSame, lastSame + 1
    end

    local bestIdx = hi
    local bestCost = math.huge
    for insertAt = lo, hi do
        local prev = route[insertAt - 1]
        local nextWp = route[insertAt]
        local dPrev = prev and routeWpMapDistSq(mapID, x, y, prev)
        local dNext = nextWp and routeWpMapDistSq(mapID, x, y, nextWp)
        local cost
        if dPrev and dNext then
            cost = dPrev + dNext
        elseif dPrev then
            cost = dPrev
        elseif dNext then
            cost = dNext
        else
            cost = math.huge
        end
        if cost < bestCost then
            bestCost = cost
            bestIdx = insertAt
        end
    end
    if bestCost == math.huge then
        if firstSame and lastSame then
            return lastSame + 1
        end
        return math.min((addon.waypoint.index or #route) + 1, #route + 1)
    end
    return bestIdx
end

-- Geographic insert into the owning zone (not current progress index).
function addon:InsertIndexForPlayerPosition(route, mapID, x, y)
    return addon:BestInsertIndex(route, mapID, x, y)
end

function addon:HasNearbyStaticWaypoint(routeName, mapID, x, y)
    local route = addon.data.routes[routeName]
    if not route or not route.route or not mapID or not x or not y then
        return false
    end
    local radiusSq = PROXIMITY_MATCH_RADIUS * PROXIMITY_MATCH_RADIUS
    for _, wp in ipairs(route.route) do
        if wp.map == mapID and wp.x and wp.y then
            local dx, dy = x - wp.x, y - wp.y
            if dx * dx + dy * dy <= radiusSq then
                return true
            end
        end
    end
    return false
end

function addon:RegisterCoordAdjustment(routeName, name, mapID, x, y)
    if addon:IsCuratedStaticRoute(routeName) then return end
    if not routeName or not name or not mapID or not x or not y then return end
    addon.data.account.coordAdjustments = addon.data.account.coordAdjustments or {}
    local bucket = addon.data.account.coordAdjustments[routeName]
    if not bucket then
        bucket = {}
        addon.data.account.coordAdjustments[routeName] = bucket
    end
    local key = string.format("%s|%s", addon:NormalizeWaypointName(name), mapID)
    bucket[key] = {
        map = mapID,
        x = x,
        y = y,
        adjustedAt = time(),
    }
end

function addon:CoordAdjustmentKey(name, mapID)
    if not name or not mapID then return nil end
    return string.format("%s|%s", addon:NormalizeWaypointName(name), mapID)
end

function addon:ApplyCoordAdjustments(segment, routeName)
    if addon:IsCuratedStaticRoute(routeName) then
        local bucket = addon.data.account.coordAdjustments
        if bucket then
            bucket[routeName] = nil
        end
        return
    end
    -- Dense Midnight Quel'Danas layout: Armory/Ramparts sit on old Harbor coords.
    -- Always use curated pins for this segment (nudges were dragging Harbor there).
    if routeName == "Midnight - Silvermoon & Quel'Danas" then
        if addon.data.account.coordAdjustments then
            addon.data.account.coordAdjustments[routeName] = nil
        end
        return
    end

    local bucket = addon.data.account.coordAdjustments
        and addon.data.account.coordAdjustments[routeName]
    if not bucket or not segment or not segment.route then return end

    for _, wp in ipairs(segment.route) do
        local data = wp.data
        local name = data and data.name
        if name and not data.learned and not data.travel then
            local key = addon:CoordAdjustmentKey(name, data.map)
            local adj = bucket[key] or bucket[addon:NormalizeWaypointName(name)]
            if adj and adj.map and adj.x and adj.y then
                local ox, oy = data.x, data.y
                local tooFar = false
                if ox and oy and adj.map == data.map then
                    local dx, dy = adj.x - ox, adj.y - oy
                    tooFar = (dx * dx + dy * dy) > (MAX_ADJUST_DIST * MAX_ADJUST_DIST)
                else
                    tooFar = true
                end
                if tooFar then
                    bucket[key] = nil
                    bucket[addon:NormalizeWaypointName(name)] = nil
                else
                    data.map = adj.map
                    data.x = adj.x
                    data.y = adj.y
                    data.coordAdjusted = true
                end
            end
        end
    end
end

-- Move a curated route pin to where discovery XP fired when player was not at the pin.
function addon:NudgeWaypointCoords(index, mapID, x, y, discoveredName)
    if not index or not mapID or not x or not y then return false end
    if not addon.segment or not addon.segment.route then return false end

    local routeName = addon.active and addon.active.path and addon.active.path[#addon.active.path]
    if routeName then
        local route = addon.data and addon.data.routes and addon.data.routes[routeName]
        -- curated / forbidCoordNudge: never autodug over authored pins (Quel'Danas density).
        if route and (route.curated == true or route.forbidCoordNudge == true) then
            return false
        end
        if addon:IsCuratedStaticRoute(routeName) then
            return false
        end
    end

    local wp = addon.segment.route[index]
    local data = wp and wp.data
    if not data or data.learned or data.travel then return false end

    if discoveredName and data.name then
        if not addon.DiscoveryNamesMatch
            or not addon:DiscoveryNamesMatch(discoveredName, data.name) then
            return false
        end
    end

    if data.map and data.map ~= mapID then return false end

    if isAtWaypointPin(data, mapID, x, y) then return false end

    -- Don't yank pins across the zone (wrong-map coords / ocean discoveries).
    if data.x and data.y then
        local dx, dy = x - data.x, y - data.y
        if (dx * dx + dy * dy) > (12 * 12) then
            return false
        end
    end

    data.map = mapID
    data.x = x
    data.y = y
    data.coordAdjusted = true

    routeName = addon.active and addon.active.path and addon.active.path[#addon.active.path]
    if routeName then
        addon:RegisterCoordAdjustment(routeName, data.name, mapID, x, y)
    end
    return true
end

function addon:MergeLearnedWaypoints(segment, routeName)
    -- Static curation controls the shipped order, but it must not suppress a
    -- legitimate DB2-backed discovery that the shipped data omitted.
    if addon:IsTravelSegment(routeName) then
        return
    end
    local inserts = addon.data.account.learnedRouteInserts
        and addon.data.account.learnedRouteInserts[routeName]
    if not inserts or not segment or not segment.route then return end

    local function findInSegment(seg, name, mapID)
        if not seg or not seg.route or not name then return nil end
        local target = addon:NormalizeWaypointName(addon:LocalizedString(name))
        for index, waypoint in ipairs(seg.route) do
            local data = waypoint.data
            if data and data.name and not data.travel then
                local wpName = addon:NormalizeWaypointName(addon:LocalizedString(data.name))
                if wpName == target then
                    if not mapID or not data.map or data.map == mapID
                        or (addon.MapsAreParentOrChild and addon:MapsAreParentOrChild(data.map, mapID))
                    then
                        return index
                    end
                end
            end
        end
        return nil
    end

    local pending = {}
    local present = {}
    for _, wp in ipairs(segment.route) do
        local wpName = wp.data and wp.data.name
        if wpName then
            present[addon:NormalizeWaypointName(addon:LocalizedString(wpName))] = true
        end
    end

    for _, entry in ipairs(inserts) do
        if entry.name then
            local key = addon:NormalizeWaypointName(entry.name)
            -- Drop parent-zone phantoms (e.g. learned insert named "Harandar").
            local mapInfo = entry.map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(entry.map)
            local Filter = ExplorationSubzoneFilter
            local excluded = Filter and Filter.IsExcluded
                and Filter:IsExcluded(entry.name, entry.areaID or entry.explorationID, entry.map)
            if excluded then
                -- Hard/soft excluded (e.g. Blackrock Mountain — no Discover toast).
            elseif mapInfo and mapInfo.name and addon:NormalizeWaypointName(mapInfo.name) == key then
                -- skip; do not inject zone-title pins into the route
            elseif present[key] then
                -- Curated stop already learned: mark discovered on resume so a
                -- dataVersion restore of the pin doesn't stick after Explore XP.
                -- Search the segment being built — not addon.segment (still the
                -- previous route while LoadWaypoints is running).
                local existing = findInSegment(segment, entry.name, entry.map)
                if existing then
                    segment.route[existing].discovered = true
                end
            elseif not present[key] then
                local existing = findInSegment(segment, entry.name, entry.map)
                if existing then
                    segment.route[existing].discovered = true
                elseif addon:HasNearbyStaticWaypoint(routeName, entry.map, entry.x, entry.y) then
                    -- Covered by curated data; no duplicate row.
                elseif addon.ShouldAcceptLearnedInsert
                    and not addon:ShouldAcceptLearnedInsert(routeName, entry.name, entry.map)
                then
                    -- Filtered / unknown for this map.
                else
                    pending[#pending + 1] = entry
                end
            end
        end
    end

    table.sort(pending, function(a, b)
        local ia = a.insertAt or 99999
        local ib = b.insertAt or 99999
        if ia ~= ib then return ia > ib end
        return (a.learnedAt or 0) > (b.learnedAt or 0)
    end)

    local mapRangeCache = {}
    for _, entry in ipairs(pending) do
        local insertAt = entry.insertAt
        local firstSame, lastSame
        if entry.map then
            local cached = mapRangeCache[entry.map]
            if cached then
                firstSame, lastSame = cached[1], cached[2]
            else
                firstSame, lastSame = sameMapRange(segment.route, entry.map)
                mapRangeCache[entry.map] = { firstSame, lastSame }
            end
        end
        if firstSame and lastSame and insertAt
            and (insertAt < firstSame or insertAt > lastSame + 1) then
            insertAt = nil
        end
        if not insertAt then
            insertAt = addon:BestInsertIndex(segment.route, entry.map, entry.x, entry.y)
        end
        insertAt = math.max(1, math.min(insertAt, #segment.route + 1))
        table.insert(segment.route, insertAt, {
            discovered = true,
            data = {
                name = entry.name,
                map = entry.map,
                x = entry.x,
                y = entry.y,
                trigger = { type = "proximity" },
                learned = true,
            },
        })
        present[addon:NormalizeWaypointName(entry.name)] = true
    end
end

--- Refuse phantom inserts that don't belong on this map (e.g. Farstrider Enclave
--- on Quel'Danas) or SubzoneFilter-excluded / NotExplorable areas.
function addon:ShouldAcceptLearnedInsert(routeName, name, mapID)
    if not routeName or not name or not mapID then return false end
    if addon:IsTravelSegment(routeName) then
        return false
    end
    -- Curated stops are advanced via ClearDatabaseWaypoint, not inserts.
    if addon:IsInStaticRoute(routeName, name) then return false end

    mapID = addon:ResolveExplorationMapID(mapID) or mapID

    local Filter = ExplorationSubzoneFilter
    local matched = false
    if ExplorationDB2Coords then
        local target = addon:NormalizeWaypointName(name)
        for _, entry in pairs(ExplorationDB2Coords) do
            if entry.name and addon:NormalizeWaypointName(entry.name) == target then
                local entryMap = entry.map
                local mapOk = entryMap == mapID
                    or (addon.MapsAreLocallyCompatible
                        and addon:MapsAreLocallyCompatible(entryMap, mapID))
                if mapOk then
                    matched = true
                    local eid = entry.areaID
                    if Filter and Filter.IsExcluded and Filter:IsExcluded(name, eid, entryMap or mapID) then
                        return false
                    end
                end
            end
        end
    end
    -- Unknown name for this map → do not invent a route stop.
    return matched
end

function addon:RegisterLearnedRouteInsert(routeName, name, mapID, x, y, learnedAt, insertAt)
    if not routeName or not name then return false end
    if not addon:ShouldAcceptLearnedInsert(routeName, name, mapID) then
        return false
    end
    addon.data.account.learnedRouteInserts = addon.data.account.learnedRouteInserts or {}
    local bucket = addon.data.account.learnedRouteInserts[routeName]
    if not bucket then
        bucket = {}
        addon.data.account.learnedRouteInserts[routeName] = bucket
    end
    local target = addon:NormalizeWaypointName(name)
    for _, entry in ipairs(bucket) do
        if addon:NormalizeWaypointName(entry.name) == target then
            return false
        end
    end
    bucket[#bucket + 1] = {
        name = name,
        map = mapID,
        x = x,
        y = y,
        learnedAt = learnedAt or time(),
        insertAt = insertAt,
    }
    return true
end

local function getStaticNameSet(routeName)
    local cached = staticNameCache[routeName]
    if cached then return cached end
    local set = {}
    local route = addon.data.routes and addon.data.routes[routeName]
    if route and route.route then
        for _, wp in ipairs(route.route) do
            if wp.name then
                set[addon:NormalizeWaypointName(wp.name)] = true
            end
        end
    end
    staticNameCache[routeName] = set
    return set
end

local function segmentStaticHasWaypoint(routeName, name)
    if not routeName or not name then return false end
    return getStaticNameSet(routeName)[addon:NormalizeWaypointName(name)] == true
end

function addon:IsInStaticRoute(routeName, name)
    return segmentStaticHasWaypoint(routeName, name)
end

function addon:CountLearnedRouteInserts(routeName)
    local inserts = addon.data.account.learnedRouteInserts
        and addon.data.account.learnedRouteInserts[routeName]
    if not inserts then return 0 end
    local count = 0
    for _, entry in ipairs(inserts) do
        if entry.name and not segmentStaticHasWaypoint(routeName, entry.name) then
            count = count + 1
        end
    end
    return count
end

local function countSegmentMapWaypoints(routeName, mapID)
    if not routeName or not mapID then return 0 end
    local byMap = mapCountCache[routeName]
    if not byMap then
        byMap = {}
        mapCountCache[routeName] = byMap
        local route = addon.data.routes and addon.data.routes[routeName]
        if route and route.route then
            for _, wp in ipairs(route.route) do
                if wp.map and not wp.travel then
                    byMap[wp.map] = (byMap[wp.map] or 0) + 1
                end
            end
        end
    end
    return byMap[mapID] or 0
end

--- Climb from a micro/orphan map to the zone map that owns exploration pins.
function addon:ResolveExplorationMapID(mapID)
    mapID = tonumber(mapID)
    if not mapID then return nil end
    local cached = resolveMapCache[mapID]
    if cached ~= nil then
        return cached
    end

    local leafNames = addon:GetSegmentLeafNames()
    local function totalForMap(mid)
        local total = 0
        for _, routeName in ipairs(leafNames) do
            if not addon:IsTravelSegment(routeName) then
                total = total + countSegmentMapWaypoints(routeName, mid)
            end
        end
        return total
    end

    local bestMap, bestCount = mapID, totalForMap(mapID)
    if not C_Map or not C_Map.GetMapInfo then
        resolveMapCache[mapID] = bestMap
        return bestMap
    end

    local info = C_Map.GetMapInfo(mapID)
    local guard = 0
    while info and info.parentMapID and info.parentMapID ~= 0 and guard < 20 do
        local parent = info.parentMapID
        local count = totalForMap(parent)
        if count > bestCount then
            bestCount = count
            bestMap = parent
        end
        -- Zone maps are the usual exploration owners; stop after a continent.
        if Enum and Enum.UIMapType and info.mapType == Enum.UIMapType.Continent then
            break
        end
        info = C_Map.GetMapInfo(parent)
        guard = guard + 1
    end
    resolveMapCache[mapID] = bestMap
    return bestMap
end

function addon:IsTravelSegment(routeName)
    if not routeName then return false end
    -- Transition / Getting There segments only — never exploration zone routes.
    if routeName:find("Getting There", 1, true) then
        return true
    end
    -- Pack travel keys look like "Midnight - Harandar to Voidstorm"
    -- or "Cataclysm - Travel - To Vashj'ir - Horde" (capital To).
    local lower = routeName:lower()
    if lower:find(" to ", 1, true) or lower:find("travel -", 1, true) then
        return true
    end
    local route = addon.data and addon.data.routes and addon.data.routes[routeName]
    if not route or not route.route then return false end
    local travelCount, total = 0, 0
    for _, wp in ipairs(route.route) do
        total = total + 1
        if wp.travel then
            travelCount = travelCount + 1
        end
    end
    return total > 0 and travelCount == total
end

function addon:FindExplorationSegmentForMap(mapID)
    mapID = addon:ResolveExplorationMapID(mapID) or mapID
    if not mapID then return nil end
    local function bestAmong(names)
        local bestName, bestCount = nil, 0
        for _, routeName in ipairs(names) do
            if not addon:IsTravelSegment(routeName) then
                local count = countSegmentMapWaypoints(routeName, mapID)
                if count > bestCount then
                    bestCount = count
                    bestName = routeName
                end
            end
        end
        return bestName
    end
    local fromJourney = bestAmong(addon:GetSegmentLeafNames())
    if fromJourney then
        return fromJourney
    end
    -- Fallback: any curated exploration route that owns this map (e.g. discover
    -- while mid-travel before the zone pack was in the active path).
    local all = {}
    if addon.data and addon.data.routes then
        for routeName, route in pairs(addon.data.routes) do
            if type(routeName) == "string" and type(route) == "table" and route.curated then
                all[#all + 1] = routeName
            end
        end
    end
    return bestAmong(all)
end

function addon:ResolveExplorationRouteName(routeName, mapID)
    -- Always prefer the exploration segment that owns this map, even when the
    -- player is mid-journey on a different zone or travel segment.
    if mapID then
        local byMap = addon:FindExplorationSegmentForMap(mapID)
        if byMap then
            return byMap
        end
    end
    return routeName
end

function addon:MigrateLearnedInsertsOffTravelSegments()
    local account = addon.data and addon.data.account
    local inserts = account and account.learnedRouteInserts
    if not inserts then return 0 end

    local moved = 0
    for travelRoute, bucket in pairs(inserts) do
        if addon:IsTravelSegment(travelRoute) and type(bucket) == "table" then
            for i = #bucket, 1, -1 do
                local entry = bucket[i]
                if entry and entry.name and entry.map then
                    local target = addon:FindExplorationSegmentForMap(entry.map)
                    if target and target ~= travelRoute then
                        if addon:RegisterLearnedRouteInsert(
                            target, entry.name, entry.map, entry.x, entry.y, entry.learnedAt
                        ) then
                            moved = moved + 1
                        end
                        table.remove(bucket, i)
                    end
                end
            end
            if #bucket == 0 then
                inserts[travelRoute] = nil
            end
        end
    end
    return moved
end

--- Drop saved pin nudges for a route so rebuilt static coords are used.
function addon:PurgeRouteCoordAdjustments(routeName)
    local adjustments = addon.data and addon.data.account and addon.data.account.coordAdjustments
    if not adjustments or not routeName or not adjustments[routeName] then
        return 0
    end
    local n = 0
    for _ in pairs(adjustments[routeName]) do
        n = n + 1
    end
    adjustments[routeName] = nil
    return n
end

--- Drop learned inserts for a route (bad discovery stubs like wrong-zone names).
function addon:PurgeRouteLearnedInserts(routeName)
    local inserts = addon.data and addon.data.account and addon.data.account.learnedRouteInserts
    if not inserts or not routeName or not inserts[routeName] then
        return 0
    end
    local route = addon.data.routes and addon.data.routes[routeName]
    local list = route and route.route
    -- Keep discovery receipts for curated stops; only drop orphans left after
    -- a route rewrite (removed/renamed pins). Wiping curated receipts on every
    -- dataVersion bump re-stuck already-explored areas that no longer toast.
    local curated = {}
    if list then
        for _, wp in ipairs(list) do
            if wp.name and not wp.travel then
                curated[addon:NormalizeWaypointName(wp.name)] = true
            end
        end
    end
    local bucket = inserts[routeName]
    local kept = {}
    local removed = 0
    for _, entry in ipairs(bucket) do
        if entry and entry.name and curated[addon:NormalizeWaypointName(entry.name)] then
            kept[#kept + 1] = entry
        else
            removed = removed + 1
        end
    end
    if #kept > 0 then
        inserts[routeName] = kept
    else
        inserts[routeName] = nil
    end
    return removed
end

--- Drop learned inserts that fail ShouldAcceptLearnedInsert (wrong map / no XP).
function addon:PurgeInvalidLearnedInserts()
    local inserts = addon.data and addon.data.account and addon.data.account.learnedRouteInserts
    if not inserts then return 0 end
    local removed = 0
    for routeName, bucket in pairs(inserts) do
        if type(bucket) == "table" then
            for i = #bucket, 1, -1 do
                local entry = bucket[i]
                if not entry or not addon:ShouldAcceptLearnedInsert(routeName, entry.name, entry.map) then
                    table.remove(bucket, i)
                    removed = removed + 1
                end
            end
            if #bucket == 0 then
                inserts[routeName] = nil
            end
        end
    end
    return removed
end

--- Remove coord adjustments that drifted too far from current curated pins.
function addon:PurgeStaleCoordAdjustments()
    local adjustments = addon.data and addon.data.account and addon.data.account.coordAdjustments
    if not adjustments or not addon.data.routes then
        return 0
    end
    local removed = 0
    local maxDistSq = MAX_ADJUST_DIST * MAX_ADJUST_DIST
    for routeName, bucket in pairs(adjustments) do
        local route = addon.data.routes[routeName]
        local list = route and route.route
        if type(bucket) == "table" and list then
            for key, adj in pairs(bucket) do
                local keep = false
                if type(adj) == "table" and adj.map and adj.x and adj.y then
                    local target = key:match("^(.-)|") or key
                    for _, wp in ipairs(list) do
                        if wp.name and not wp.travel
                            and addon:NormalizeWaypointName(wp.name) == target
                            and wp.map == adj.map and wp.x and wp.y
                        then
                            local dx, dy = adj.x - wp.x, adj.y - wp.y
                            if (dx * dx + dy * dy) <= maxDistSq then
                                keep = true
                            end
                            break
                        end
                    end
                end
                if not keep then
                    bucket[key] = nil
                    removed = removed + 1
                end
            end
            if not next(bucket) then
                adjustments[routeName] = nil
            end
        end
    end
    return removed
end

--- Remove learned inserts named for the zone itself (not a subzone), which used
--- to stuck the route on parent-zone fog discoveries like "Harandar".
function addon:PurgeZoneTitleLearnedInserts()
    local inserts = addon.data and addon.data.account and addon.data.account.learnedRouteInserts
    if not inserts or not C_Map or not C_Map.GetMapInfo then return 0 end

    local removed = 0
    for routeName, bucket in pairs(inserts) do
        if type(bucket) == "table" then
            for i = #bucket, 1, -1 do
                local entry = bucket[i]
                if entry and entry.name and entry.map then
                    local info = C_Map.GetMapInfo(entry.map)
                    if info and info.name
                        and addon:NormalizeWaypointName(info.name)
                            == addon:NormalizeWaypointName(entry.name)
                    then
                        table.remove(bucket, i)
                        removed = removed + 1
                    end
                end
            end
            if #bucket == 0 then
                inserts[routeName] = nil
            end
        end
    end
    return removed
end

local function bestSegmentForLearned(segmentNames, mapID, name)
    mapID = addon:ResolveExplorationMapID(mapID) or mapID
    local norm = addon:NormalizeWaypointName(name)
    local bestName, bestCount = nil, 0
    for _, routeName in ipairs(segmentNames) do
        if not addon:IsTravelSegment(routeName)
            and not getStaticNameSet(routeName)[norm]
        then
            local count = countSegmentMapWaypoints(routeName, mapID)
            if count > bestCount then
                bestCount = count
                bestName = routeName
            end
        end
    end
    return bestName
end

function addon:GetSegmentLeafNames()
    local names = {}
    local root = addon.menu and addon.menu["Exploration Mega-Journey"]
    if not root or not addon.GetAllLeaves then return names end
    for _, leaf in ipairs(addon:GetAllLeaves(root)) do
        names[#names + 1] = leaf.path[#leaf.path]
    end
    return names
end

function addon:BackfillLearnedRouteInserts()
    local account = addon.data.account
    if not account or not account.learnedWaypoints then return 0 end

    local segmentNames = addon:GetSegmentLeafNames()
    if #segmentNames == 0 then return 0 end

    -- Warm per-route name/map indexes once before the learned-waypoint loop.
    for _, routeName in ipairs(segmentNames) do
        if not addon:IsTravelSegment(routeName) then
            getStaticNameSet(routeName)
            countSegmentMapWaypoints(routeName, 0)
        end
    end

    account.learnedRouteInserts = account.learnedRouteInserts or {}
    local added = 0

    for _, entry in pairs(account.learnedWaypoints) do
        if type(entry) == "table" and entry.name and entry.map then
            local routeName = bestSegmentForLearned(segmentNames, entry.map, entry.name)
            if routeName and addon:RegisterLearnedRouteInsert(
                routeName, entry.name, entry.map, entry.x, entry.y, entry.learnedAt
            ) then
                added = added + 1
            end
        end
    end

    return added
end

function addon:BackfillCoordAdjustments()
    local account = addon.data.account
    if not account or not account.learnedWaypoints then return 0 end

    local segmentNames = addon:GetSegmentLeafNames()
    if #segmentNames == 0 then return 0 end

    account.coordAdjustments = account.coordAdjustments or {}
    local updated = 0
    local maxDistSq = MAX_ADJUST_DIST * MAX_ADJUST_DIST

    for _, entry in pairs(account.learnedWaypoints) do
        if type(entry) == "table" and entry.name and entry.map and entry.x and entry.y then
            local key = addon:NormalizeWaypointName(entry.name)
            for _, routeName in ipairs(segmentNames) do
                local route = addon.data.routes[routeName]
                if addon:IsCuratedStaticRoute(routeName) or (route and route.forbidCoordNudge) then
                    -- curated / dense authored routes: never autodug
                elseif route and route.route then
                    for _, wp in ipairs(route.route) do
                        if wp.name and addon:NormalizeWaypointName(wp.name) == key then
                            if wp.map == entry.map and wp.x and wp.y then
                                local staticData = {
                                    map = wp.map,
                                    x = wp.x,
                                    y = wp.y,
                                    trigger = { type = "proximity" },
                                }
                                local adjKey = addon:CoordAdjustmentKey(entry.name, entry.map)
                                local bucket = account.coordAdjustments[routeName]
                                local dx, dy = entry.x - wp.x, entry.y - wp.y
                                local tooFar = (dx * dx + dy * dy) > maxDistSq
                                if isAtWaypointPin(staticData, entry.map, entry.x, entry.y) or tooFar then
                                    if bucket then
                                        if bucket[adjKey] then bucket[adjKey] = nil end
                                        if bucket[key] then bucket[key] = nil end
                                    end
                                elseif not (bucket and (bucket[adjKey] or bucket[key])) then
                                    addon:RegisterCoordAdjustment(
                                        routeName, entry.name, entry.map, entry.x, entry.y
                                    )
                                    updated = updated + 1
                                end
                            end
                            break
                        end
                    end
                end
            end
        end
    end

    return updated
end

function addon:MarkStaticRouteDiscovered(routeName, zone, mapID, px, py)
    if not routeName or not zone then return end
    -- Only track curated stops by name. Never mark a nearby pin discovered
    -- just because the player was standing on it for an unrelated toast.
    if addon:IsInStaticRoute(routeName, zone) then
        addon:RegisterLearnedRouteInsert(routeName, zone, mapID, px, py)
    end
    addon:AnnounceDiscovered(zone, px, py)
end

function addon:ResolveDatabaseWaypointIndex(zone, mapID, px, py, routeName)
    if not routeName then return nil end

    local activeName = addon.active and addon.active.path and addon.active.path[#addon.active.path]
    if activeName == routeName and addon.segment and addon.segment.route then
        local index = addon:FindWaypointIndexForDiscovery(zone, mapID, px, py)
        if index then return index end
    end

    -- Exploration stops clear only on a matching Discover name — never by
    -- standing near a curated pin when the toast names something else.
    if not addon:IsInStaticRoute(routeName, zone) then
        return nil
    end

    local staticRoute = addon.data.routes[routeName]
    local staticList = staticRoute and staticRoute.route
    if not staticList then return nil end

    local target = addon:NormalizeWaypointName(zone)
    for i, wp in ipairs(staticList) do
        if wp.name and not wp.travel and addon:NormalizeWaypointName(wp.name) == target then
            return i
        end
    end

    return nil
end

function addon:ClearDatabaseWaypoint(index, zone, mapID, px, py)
    if not index or not addon.segment or not addon.segment.route[index] then return end

    local nudged = addon:NudgeWaypointCoords(index, mapID, px, py, zone)
    addon:AnnounceDiscovered(zone, px, py)
    addon.segment.route[index].discovered = true
    if addon.ArmProximityRearmFromPlayer then
        addon:ArmProximityRearmFromPlayer()
    end
    if addon.ui and addon.ui.SegmentFrame then
        addon.ui.SegmentFrame._scrollToIndex = index
    end
    if index == addon.waypoint.index then
        addon:DetermineNextWaypoint()
    else
        addon:UpdateWaypointArrow()
        addon:RefreshWorldMapOverlay()
        addon:RefreshMinimapOverlay()
    end
    if nudged then
        addon:UpdateWaypointArrow()
        addon:RefreshWorldMapOverlay()
        addon:RefreshMinimapOverlay()
    end
    if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
    addon:RefreshProgressUI()
    addon:SaveProgress()
end

function addon:InsertLearnedWaypoint(name, mapID, x, y)
    if not name then
        return nil, nil, false
    end

    local zoneMap = addon:ResolveExplorationMapID(mapID) or mapID

    local activeRoute = addon.active and addon.active.path and addon.active.path[#addon.active.path]
    -- Prefer the pack/segment that owns this zone map (correct expansion zone).
    local storageRoute = addon:FindExplorationSegmentForMap(zoneMap)
        or addon:ResolveExplorationRouteName(activeRoute, zoneMap)
        or activeRoute
    if not storageRoute then
        return nil, nil, false
    end
    -- Never attach zone Discovers to travel / Getting There segments.
    if addon:IsTravelSegment(storageRoute) then
        local owned = addon:FindExplorationSegmentForMap(zoneMap)
        if not owned then
            return nil, nil, false
        end
        storageRoute = owned
    end

    -- Already curated by name: clear that stop, don't insert a duplicate.
    if addon:IsInStaticRoute(storageRoute, name) then
        if activeRoute == storageRoute and addon.segment and addon.segment.route then
            local dbIndex = addon:ResolveDatabaseWaypointIndex(name, mapID, x, y, storageRoute)
            if dbIndex then
                addon:ClearDatabaseWaypoint(dbIndex, name, mapID, x, y)
                return dbIndex, storageRoute, false
            end
        end
        addon:MarkStaticRouteDiscovered(storageRoute, name, mapID, x, y)
        return nil, storageRoute, false
    end

    local staticRoute = addon.data.routes[storageRoute]
    local insertAt
    if staticRoute and staticRoute.route then
        -- Use zoneMap so inserts land inside that zone's curated block.
        insertAt = addon:BestInsertIndex(staticRoute.route, zoneMap, x, y)
    end

    -- Persist against the zone map so later merges align with curated pins.
    local storeMap = zoneMap or mapID
    local registered = addon:RegisterLearnedRouteInsert(
        storageRoute, name, storeMap, x, y, nil, insertAt
    )
    if not registered then
        return nil, storageRoute, false
    end

    -- Live segment is this zone's pack (or a multi-map pack containing it):
    -- inject into the correct map block so it shows up immediately.
    local activeOwnsRoute = activeRoute == storageRoute
        and addon.segment
        and addon.segment.route
        and not addon:IsTravelSegment(activeRoute)

    if activeOwnsRoute then
        local existing = addon:FindWaypointIndexForDiscovery(name, mapID, x, y)
        if existing then
            addon:ClearDatabaseWaypoint(existing, name, mapID, x, y)
            return existing, storageRoute, false
        end

        if not addon:RouteHasWaypoint(addon.segment.route, name) then
            insertAt = addon:BestInsertIndex(addon.segment.route, zoneMap, x, y)
            table.insert(addon.segment.route, insertAt, {
                discovered = true,
                data = {
                    name = name,
                    map = storeMap,
                    x = x,
                    y = y,
                    trigger = { type = "proximity" },
                    learned = true,
                },
            })

            if addon.waypoint.index and insertAt <= addon.waypoint.index then
                addon.waypoint.index = addon.waypoint.index + 1
            end

            addon:UpdateWaypointArrow()
            addon:RefreshWorldMapOverlay()
            addon:RefreshMinimapOverlay()
            if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
            addon:RefreshProgressUI()
            addon:SaveProgress()
        end
        return insertAt, storageRoute, true
    end

    -- Different segment: saved on the owning zone route; merges when that segment loads.
    return nil, storageRoute, true
end

function addon:SyncActiveSegmentLearnedInserts()
    if not addon.active or not addon.segment then return end
    local routeName = addon.active.path[#addon.active.path]
    local before = #addon.segment.route
    addon:MergeLearnedWaypoints(addon.segment, routeName)
    if #addon.segment.route ~= before then
        if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
        addon:RefreshProgressUI()
        addon:SaveProgress()
    end
end
