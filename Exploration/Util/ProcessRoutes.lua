local addon = Exploration

function addon:ResolveRouteEntry(entry)
    if type(entry) == "string" then
        return entry
    elseif type(entry) == "table" then
        if entry.switch then
            for _, case in ipairs(entry.switch) do
                if not case.condition or addon:EvaluateCondition(case.condition) then
                    return case.route
                end
            end
            return nil
        elseif entry.condition then
            if addon:EvaluateCondition(entry.condition) then
                return entry.pass
            else
                return entry.fail
            end
        end
    end
    return nil
end

local function appendResolved(result, value)
    if type(value) == "string" then
        result[#result + 1] = value
    elseif type(value) == "table" then
        local resolved = addon:ResolveRouteList(value)
        for _, name in ipairs(resolved) do
            result[#result + 1] = name
        end
    end
end

function addon:ResolveRouteList(routeArray)
    local result = {}
    for _, entry in ipairs(routeArray or {}) do
        if type(entry) == "table" and entry.switch then
            for _, case in ipairs(entry.switch) do
                if not case.condition or addon:EvaluateCondition(case.condition) then
                    if case.route then
                        result[#result + 1] = case.route
                    elseif case.routes then
                        appendResolved(result, case.routes)
                    end
                    break
                end
            end
        elseif type(entry) == "table" and entry.condition then
            if addon:EvaluateCondition(entry.condition) then
                appendResolved(result, entry.pass)
            else
                appendResolved(result, entry.fail)
            end
        else
            local resolved = addon:ResolveRouteEntry(entry)
            if resolved then
                result[#result + 1] = resolved
            end
        end
    end
    return result
end

-- Paths that already contain map waypoints (e.g. Cataclysm exploration with
-- mid-route travel switches) must stay a single leaf. Promoting those switches
-- to menu children skips the discovery waypoints and jumps to travel-only leaves.
local function routeHasMapWaypoints(route)
    if not route or not route.route then return false end
    for _, entry in ipairs(route.route) do
        if type(entry) == "table"
            and not entry.switch
            and not entry.condition
            and (entry.map or entry.x or entry.name)
        then
            return true
        end
    end
    return false
end

local function processRoutes(routes)
    local menuStructure = {}
    local function processRoute(name, route, path)
        local entryPath = {}
        for i = 1, #path do entryPath[i] = path[i] end
        entryPath[#entryPath + 1] = name
        local menuEntry = {
            display = route.display or name,
            name = name,
            path = entryPath,
            children = {},
        }
        if route.route and not routeHasMapWaypoints(route) then
            local resolved = addon:ResolveRouteList(route.route)
            for _, sub in ipairs(resolved) do
                if routes[sub] then
                    menuEntry.children[#menuEntry.children + 1] = processRoute(sub, routes[sub], entryPath)
                end
            end
        end
        return menuEntry
    end
    for name, route in pairs(routes) do
        if route.class == "segment" then
            menuStructure[name] = processRoute(name, route, {})
        end
    end
    return menuStructure
end

addon.processRoutes = processRoutes

function addon:FindFirstLeaf(item)
    if item.children and #item.children > 0 then
        return addon:FindFirstLeaf(item.children[1])
    end
    return item
end
