local addon = Exploration

local MEGA_ROOT = "Exploration Mega-Journey"

-- Count path rows without LoadWaypoints / MergeLearnedWaypoints (those are too
-- heavy to run for every mega-journey leaf on each UI refresh).
local function countStaticPathRows(routeArray)
    local n = 0
    if not routeArray then return 0 end
    for _, waypoint in ipairs(routeArray) do
        if type(waypoint) == "table" then
            if waypoint.switch then
                local travelName = addon:ResolveRouteEntry(waypoint)
                local travel = travelName and addon.data.routes and addon.data.routes[travelName]
                if travel and travel.route then
                    n = n + countStaticPathRows(travel.route)
                end
            elseif waypoint.map or waypoint.x or waypoint.name then
                n = n + 1
            end
        end
    end
    return n
end

local function staticRouteHasName(routeArray, name)
    if not routeArray or not name then return false end
    local target = addon:NormalizeWaypointName(addon:LocalizedString(name))
    for _, waypoint in ipairs(routeArray) do
        if type(waypoint) == "table" then
            if waypoint.switch then
                local travelName = addon:ResolveRouteEntry(waypoint)
                local travel = travelName and addon.data.routes and addon.data.routes[travelName]
                if travel and travel.route and staticRouteHasName(travel.route, name) then
                    return true
                end
            elseif waypoint.name
                and addon:NormalizeWaypointName(addon:LocalizedString(waypoint.name)) == target
            then
                return true
            end
        end
    end
    return false
end

local function countLearnedExtras(routeName, routeArray)
    local inserts = addon.data.account
        and addon.data.account.learnedRouteInserts
        and addon.data.account.learnedRouteInserts[routeName]
    if not inserts then return 0 end
    local extra = 0
    for _, entry in ipairs(inserts) do
        if entry.name and not staticRouteHasName(routeArray, entry.name) then
            if not (addon.HasNearbyStaticWaypoint
                and addon:HasNearbyStaticWaypoint(routeName, entry.map, entry.x, entry.y))
            then
                extra = extra + 1
            end
        end
    end
    return extra
end

local function countRouteWaypoints(routeName)
    if not routeName then return 0 end
    routeName = addon:ResolvePathRouteName(routeName)
    local route = addon.data.routes[routeName]
    if not route then return 0 end
    if route.class == "path" then
        return countStaticPathRows(route.route) + countLearnedExtras(routeName, route.route)
    end
    if route.class == "segment" then
        local total = 0
        for _, child in ipairs(addon:ResolveRouteList(route.route)) do
            total = total + countRouteWaypoints(child)
        end
        return total
    end
    return 0
end

local function collectMegaLeaves()
    local root = addon.menu[MEGA_ROOT]
    if not root then return {} end
    return addon:GetAllLeaves(root)
end

function addon:GetZoneProgress()
    if not addon.segment.route or #addon.segment.route == 0 then
        return 0, 0
    end
    local done = 0
    for _, wp in ipairs(addon.segment.route) do
        if wp.discovered then done = done + 1 end
    end
    return done, #addon.segment.route
end

function addon:GetJourneyProgress()
    local leaves = collectMegaLeaves()
    local currentLeaf = addon.active and addon.active.path[#addon.active.path]
    local total = 0
    for _, leaf in ipairs(leaves) do
        local name = leaf.path[#leaf.path]
        if name == currentLeaf and addon.segment.route then
            total = total + #addon.segment.route
        else
            total = total + countRouteWaypoints(name)
        end
    end
    if total == 0 then return 0, 0 end

    if not addon.active or addon.active.path[1] ~= MEGA_ROOT then
        return 0, total
    end

    local done = 0
    local passedCurrent = false
    for _, leaf in ipairs(leaves) do
        local name = leaf.path[#leaf.path]
        if name == currentLeaf then
            passedCurrent = true
            for _, wp in ipairs(addon.segment.route or {}) do
                if wp.discovered then done = done + 1 end
            end
        elseif not passedCurrent then
            done = done + countRouteWaypoints(name)
        end
    end
    return done, total
end

function addon:GetMegaJourneyTotal()
    return countRouteWaypoints(MEGA_ROOT)
end
