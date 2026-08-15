local _, ns = ...



-- Local Midnight portal routing when Zygor cannot path (e.g. Voidstorm gaps).

local MidnightLocalRoutes = {}

ns.MidnightLocalRoutes = MidnightLocalRoutes



local STEP_NEAR_YARDS = 55



MidnightLocalRoutes.PORTALS = {

    {

        fromMap = 2393,

        toMap = 2405,

        entrance = { mapId = 2393, x = 0.3528, y = 0.6565 },

        label = "Take the portal to Voidstorm",

    },

    {

        fromMap = 2405,

        toMap = 2393,

        entrance = { mapId = 2405, x = 0.3528, y = 0.6565 },

        label = "Take the portal to Silvermoon",

    },

    {

        fromMap = 2393,

        toMap = 2413,

        entrance = { mapId = 2393, x = 0.3676, y = 0.6860 },

        label = "Take the portal to Harandar",

    },

    {

        fromMap = 2413,

        toMap = 2393,

        entrance = { mapId = 2413, x = 0.7589, y = 0.5477 },

        label = "Take the portal to Silvermoon",

    },

}



function MidnightLocalRoutes:GetPortalEntrance(fromMap, toMap)
    fromMap = self:ResolveMap(fromMap)
    toMap = self:ResolveMap(toMap)
    if not fromMap or not toMap then
        return nil
    end
    for _, portal in ipairs(self.PORTALS) do
        if portal.fromMap == fromMap and portal.toMap == toMap then
            return portal.entrance.mapId, portal.entrance.x, portal.entrance.y
        end
    end
    return nil
end



function MidnightLocalRoutes:ResolveMap(mapId)

    if ns.TravelRegions then

        return ns.TravelRegions:ResolveZoneMapId(mapId) or mapId

    end

    return mapId

end



function MidnightLocalRoutes:MakeLoc(mapId, x, y)

    return {

        mapId = mapId,

        pos = { x = x, y = y, z = 0 },

        isUI = true,

    }

end



function MidnightLocalRoutes:MakeEdge(loca, mapId, x, y, opts)

    opts = opts or {}

    local loc = self:MakeLoc(mapId, x, y)

    return {

        loca = loca,

        loc = loc,

        completionLoc = loc,

        checkDistance = opts.checkDistance ~= false,

        isPortalStep = opts.isPortalStep,

        portalDestMap = opts.portalDestMap,

    }

end



function MidnightLocalRoutes:DistanceSq(mapA, xA, yA, mapB, xB, yB)

    if mapA ~= mapB or not xA or not yA or not xB or not yB then

        return math.huge

    end

    local dx, dy = xA - xB, yA - yB

    return dx * dx + dy * dy

end



function MidnightLocalRoutes:IsNear(mapA, xA, yA, mapB, xB, yB)

    if mapA ~= mapB then

        return false

    end

    if ns.MapCoords then

        local yards = ns.MapCoords:GetZoneDistance(mapA, xA, yA, mapB, xB, yB)

        if yards then

            return yards <= STEP_NEAR_YARDS

        end

    end

    return self:DistanceSq(mapA, xA, yA, mapB, xB, yB) <= (0.012 * 0.012)

end



function MidnightLocalRoutes:BuildAdjacency()

    local adj = {}

    for _, portal in ipairs(self.PORTALS) do

        adj[portal.fromMap] = adj[portal.fromMap] or {}

        adj[portal.fromMap][#adj[portal.fromMap] + 1] = portal

    end

    return adj

end



function MidnightLocalRoutes:FindPortalPath(fromMap, toMap)

    if fromMap == toMap then

        return {}

    end



    local adj = self:BuildAdjacency()

    local queue = { { map = fromMap, path = {} } }

    local visited = { [fromMap] = true }



    while #queue > 0 do

        local current = table.remove(queue, 1)

        for _, portal in ipairs(adj[current.map] or {}) do

            if not visited[portal.toMap] then

                local path = {}

                for i, p in ipairs(current.path) do

                    path[i] = p

                end

                path[#path + 1] = portal

                if portal.toMap == toMap then

                    return path

                end

                visited[portal.toMap] = true

                queue[#queue + 1] = { map = portal.toMap, path = path }

            end

        end

    end



    return nil

end



function MidnightLocalRoutes:AppendWalk(steps, label, mapId, x, y)

    steps[#steps + 1] = self:MakeEdge(label, mapId, x, y, { checkDistance = true })

end



function MidnightLocalRoutes:AppendPortal(steps, portal)

    local ent = portal.entrance

    steps[#steps + 1] = self:MakeEdge(portal.label, ent.mapId, ent.x, ent.y, {

        checkDistance = true,

        isPortalStep = true,

        portalDestMap = portal.toMap,

    })

end



function MidnightLocalRoutes:BuildRoute(dest)

    local player = ns.TravelRegions and ns.TravelRegions:GetPlayerMapCoords()

    if not player or not player.mapId then

        return nil

    end



    local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)

    if not destMap or not destX or not destY then

        return nil

    end



    local playerMap = self:ResolveMap(player.mapId)

    destMap = self:ResolveMap(destMap)

    local px, py = player.x, player.y



    local portalPath = self:FindPortalPath(playerMap, destMap)

    if not portalPath then

        return nil

    end



    local steps = {}

    local cursorMap, cursorX, cursorY = playerMap, px, py



    for _, portal in ipairs(portalPath) do

        local ent = portal.entrance

        if not self:IsNear(cursorMap, cursorX, cursorY, ent.mapId, ent.x, ent.y) then

            self:AppendWalk(steps, string.format("Travel to %s", portal.label:lower()), ent.mapId, ent.x, ent.y)

        end

        self:AppendPortal(steps, portal)

        cursorMap = portal.toMap

        cursorX, cursorY = ent.x, ent.y

    end



    if not self:IsNear(cursorMap, cursorX, cursorY, destMap, destX, destY) then

        self:AppendWalk(steps, string.format("Travel to %s", dest.name or "destination"), destMap, destX, destY)

    else

        steps[#steps + 1] = self:MakeEdge(

            string.format("Arrive at %s", dest.name or "destination"),

            destMap, destX, destY,

            { checkDistance = true }

        )

    end



    if #steps == 0 then

        return nil

    end



    return {

        optimizedPath = steps,

        path = {},

        edges = {},

        destination = dest,

        midnightLocal = true,

    }

end



function MidnightLocalRoutes:ShouldUseFor(dest)

    if not dest or not dest.mapId or not ns.TravelRegions then

        return false

    end

    local destMap = self:ResolveMap(dest.mapId)

    if not ns.TravelRegions:IsMidnightMap(destMap) then

        return false

    end

    local playerMap = ns.TravelRegions:GetPlayerMapId()

    if not playerMap or not ns.TravelRegions:IsMidnightMap(playerMap) then

        return false

    end

    return self:FindPortalPath(self:ResolveMap(playerMap), destMap) ~= nil

end



function MidnightLocalRoutes:TryRoute(dest)

    if not self:ShouldUseFor(dest) then

        return nil

    end

    return self:BuildRoute(dest)

end


