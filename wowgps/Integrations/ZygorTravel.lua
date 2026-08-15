local _, ns = ...



local ZygorTravel = {}

ns.ZygorTravel = ZygorTravel



local REQUEST_TIMEOUT = 25



function ZygorTravel:GetLibRover()

    if not LibStub then

        return nil

    end

    return LibStub("LibRover-1.0", true)

end



function ZygorTravel:GetZygor()

    return _G.ZygorGuidesViewer

end



function ZygorTravel:IsAvailable()

    local zgv = self:GetZygor()

    local lr = self:GetLibRover()

    if not zgv or not lr then

        return false

    end

    if lr.initializing and not lr.ready then

        return false

    end

    if not lr.ready then

        return false

    end

    if not zgv.db or not zgv.db.profile or not zgv.db.profile.pathfinding then

        return false

    end

    return true

end



function ZygorTravel:GetStatusMessage()

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")

    local zgv = self:GetZygor()

    if not zgv then

        return L["ZYGOR_MISSING"]

    end

    local lr = self:GetLibRover()

    if not lr then

        return L["ZYGOR_LIBROVER_MISSING"]

    end

    if lr.initializing and not lr.ready then

        return L["ZYGOR_INITIALIZING"]

    end

    if not lr.ready then

        return L["ZYGOR_NOT_READY"]

    end

    if not zgv.db.profile.pathfinding then

        return L["ZYGOR_PATHFINDING_OFF"]

    end

    return nil

end



function ZygorTravel:IsRouteAcceptable(routeResult, dest)

    if not routeResult or not routeResult.optimizedPath or #routeResult.optimizedPath == 0 then

        return false

    end

    if not ns.TravelRegions or not dest then

        return true

    end

    local playerMap = ns.TravelRegions:GetPlayerMapId()

    return ns.TravelRegions:IsValidRouteForDestination(routeResult.optimizedPath, dest.mapId, playerMap)

end



function ZygorTravel:NodeLabel(node, prevNode, nextNode)

    if not node then

        return nil

    end

    local text = node.text

    if not text and node.GetTextAsItinerary then

        text = node:GetTextAsItinerary()

    end

    if not text and node.GetText then

        text = node:GetText(prevNode, nextNode)

    end

    if not text and node.GetActionTitle then

        text = node:GetActionTitle(prevNode, nextNode)

    end

    if not text then

        text = node.title

    end

    if type(text) == "function" then

        text = text(node, prevNode, nextNode)

    end

    return text or "Continue"

end



function ZygorTravel:IsPortalEdge(edge)

    if not edge then

        return false

    end

    if edge.isPortalStep then

        return true

    end

    if ns.SubStepResolver and ns.SubStepResolver.IsPortalStep then

        return ns.SubStepResolver:IsPortalStep({ text = edge.loca or "" })

    end

    return false

end



function ZygorTravel:GetPortalDedupKey(edge)

    if not self:IsPortalEdge(edge) then

        return nil

    end

    local destMap = edge.portalDestMap

    if not destMap and ns.SubStepResolver then

        local loc = edge.loc or edge.completionLoc

        destMap = ns.SubStepResolver:InferPortalDestMap({

            text = edge.loca,

            portalDestMap = edge.portalDestMap,

            mapId = loc and loc.mapId,

        })

    end

    if not destMap then

        return nil

    end

    local loc = edge.loc or edge.completionLoc

    return string.format("%s:%s:%.3f:%.3f",

        tostring(destMap),

        tostring(loc and loc.mapId),

        loc and loc.pos and loc.pos.x or 0,

        loc and loc.pos and loc.pos.y or 0)

end



function ZygorTravel:ApplyPortalEdgeMetadata(edge, fromMapId, nextNode)

    if not edge then

        return

    end

    if not edge.isPortalStep and ns.SubStepResolver then

        if ns.SubStepResolver:IsPortalStep({ text = edge.loca or "" }) then

            edge.isPortalStep = true

        end

    end

    if not edge.isPortalStep then

        return

    end

    if not edge.portalDestMap then

        if nextNode and nextNode.m then

            edge.portalDestMap = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(nextNode.m) or nextNode.m

        end

        if not edge.portalDestMap and ns.SubStepResolver then

            edge.portalDestMap = ns.SubStepResolver:InferPortalDestMap({

                text = edge.loca,

                mapId = fromMapId,

            })

        end

    end

    local destMap = edge.portalDestMap

    if destMap and ns.MidnightLocalRoutes then

        local fromMap = ns.TravelRegions and ns.TravelRegions:ResolveZoneMapId(fromMapId) or fromMapId

        local entMap, entX, entY = ns.MidnightLocalRoutes:GetPortalEntrance(fromMap, destMap)

        if entMap and entX and entY then

            edge.loc = self:MakeLoc(entMap, entX, entY)

            edge.completionLoc = edge.loc

        end

    end

end



function ZygorTravel:MakeLoc(mapId, x, y)

    return {

        mapId = mapId,

        pos = { x = x, y = y, z = 0 },

        isUI = true,

    }

end



function ZygorTravel:NodeToEdge(node, prevNode, nextNode, dest)

    if not node then

        return nil

    end



    if node.type == "start" and node.player then

        return nil

    end



    local mapId = node.m

    local x = node.x

    local y = node.y



    if node.type == "end" then

        local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)

        if destMap and destX and destY then

            mapId, x, y = destMap, destX, destY

        end

    end



    x = ns.Destination and ns.Destination:NormalizeUICoord(x)

    y = ns.Destination and ns.Destination:NormalizeUICoord(y)

    if not mapId or not x or not y then

        return nil

    end



    local loc = self:MakeLoc(mapId, x, y)

    local edge = {

        loca = self:NodeLabel(node, prevNode, nextNode),

        loc = loc,

        completionLoc = loc,

        checkDistance = node.type ~= "end",

    }



    if node.type == "portal" then

        edge.isPortalStep = true

    end

    self:ApplyPortalEdgeMetadata(edge, mapId, nextNode)



    if node.actionOptions then

        edge.actionOptions = node.actionOptions

    end



    return edge

end



function ZygorTravel:BuildRouteResult(path, dest)

    local optimizedPath = {}

    local lastPortalKey

    for i, node in ipairs(path or {}) do

        local edge = self:NodeToEdge(node, path[i - 1], path[i + 1], dest)

        if edge then

            if self:IsPortalEdge(edge) then

                local key = self:GetPortalDedupKey(edge)

                if key and key == lastPortalKey then

                    edge = nil

                elseif key then

                    lastPortalKey = key

                end

            end

            if edge then

                optimizedPath[#optimizedPath + 1] = edge

            end

        end

    end



    if #optimizedPath == 0 then

        return nil

    end



    local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)

    if destMap and destX and destY then

        local last = optimizedPath[#optimizedPath]

        local lastMap = last.completionLoc and last.completionLoc.mapId

        local lastX = last.completionLoc and last.completionLoc.pos and last.completionLoc.pos.x

        local lastY = last.completionLoc and last.completionLoc.pos and last.completionLoc.pos.y

        if not lastMap or lastMap ~= destMap

            or math.abs((lastX or 0) - destX) > 0.015

            or math.abs((lastY or 0) - destY) > 0.015 then

            optimizedPath[#optimizedPath + 1] = {

                loca = string.format("Travel to %s", dest.name or "destination"),

                loc = self:MakeLoc(destMap, destX, destY),

                completionLoc = self:MakeLoc(destMap, destX, destY),

                checkDistance = true,

            }

        end

    end



    return {

        optimizedPath = optimizedPath,

        path = {},

        edges = {},

        destination = dest,

        zygorTravel = true,

    }

end



function ZygorTravel:TryLocalFallback(dest)
    if ns.MawLocalRoutes then
        local mawRoute = ns.MawLocalRoutes:TryRoute(dest)
        if mawRoute then
            return mawRoute
        end
    end

    if ns.MidnightLocalRoutes then
        return ns.MidnightLocalRoutes:TryRoute(dest)
    end

    return nil
end



function ZygorTravel:CancelRequest()

    self.activeRequest = nil

    if self.timeoutHandle and self.timeoutHandle.Cancel then

        self.timeoutHandle:Cancel()

    end

    self.timeoutHandle = nil

    local lr = self:GetLibRover()

    if lr and lr.Abort then

        pcall(lr.Abort, lr, "wowgps")

    end

end



function ZygorTravel:RequestRoute(dest, callback)

    if not callback then

        return false

    end



    local lr = self:GetLibRover()

    if not self:IsAvailable() or not lr then

        callback(nil, "zygor_not_ready")

        return false

    end



    local mapId, x, y = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)

    if not mapId or not x or not y then

        callback(nil, "bad_dest")

        return false

    end



    self:CancelRequest()



    local token = {}

    self.activeRequest = {

        token = token,

        dest = dest,

        callback = callback,

        startedAt = GetTime(),

    }



    local function finish(result, err)

        if not self.activeRequest or self.activeRequest.token ~= token then

            return

        end

        self:CancelRequest()



        if result and not self:IsRouteAcceptable(result, dest) then

            local fallback = self:TryLocalFallback(dest)

            if fallback then

                callback(fallback)

                return

            end

            callback(nil, "zygor_bad_route")

            return

        end



        if not result then

            local fallback = self:TryLocalFallback(dest)

            if fallback then

                callback(fallback)

                return

            end

        end



        callback(result, err)

    end



    if C_Timer then

        self.timeoutHandle = C_Timer.NewTimer(REQUEST_TIMEOUT, function()

            finish(nil, "zygor_timeout")

        end)

    end



    pcall(lr.Abort, lr, "wowgps")



    lr:QueueFindPath(0, 0, 0, mapId, x, y, function(state, path, ext, reason)

        if self.activeRequest == nil or self.activeRequest.token ~= token then

            return

        end

        local status = type(state) == "string" and state:lower() or state

        if status == "progress" then

            return

        end

        if status == "arrival" then

            finish(self:BuildRouteResult(path or lr.RESULTS, dest))

            return

        end

        if status == "failure" or status ~= "success" or not path or #path == 0 then

            finish(nil, reason or "zygor_no_path")

            return

        end

        finish(self:BuildRouteResult(path, dest))

    end, {

        title = dest.name or "Destination",

        player = true,

        direct = false,

    })



    return true

end


