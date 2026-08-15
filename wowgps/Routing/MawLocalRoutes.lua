local _, ns = ...

-- Hand-authored Maw corridor breadcrumbs.
-- Pins are road/bridge/safe-platform only. Off-road pins are used only when
-- the segment is known drop-safe. Never invent straight-line chords across void.

local MawLocalRoutes = {}
ns.MawLocalRoutes = MawLocalRoutes

local MAW_MAP = 1543
local KORTHIA_MAP = 1961
local STEP_NEAR_YARDS = 35
local SNAP_NODE_UI = 0.035 -- ~snap dest onto a graph node
local FINAL_PIN_UI = 0.030 -- allow exact dest pin only when this close to spine

-- Breadcrumb nodes (UI 0-1 on The Maw). Only places players should walk.
MawLocalRoutes.NODES = {
    venari = { x = 0.4690, y = 0.4150, label = "Ve'nari's Refuge", hub = true, goals = { venari = true } },
    torghast = { x = 0.4820, y = 0.3950, label = "Torghast portal", goals = { torghast = true } },
    korthia_pad = {
        x = 0.4732,
        y = 0.4376,
        label = "Take the animaflow teleporter to Korthia",
        goals = { korthia = true },
        portalTo = KORTHIA_MAP,
    },

    road_s1 = { x = 0.4900, y = 0.4800, label = "Follow the road south" },
    road_s2 = { x = 0.5050, y = 0.5450, label = "Follow the road south" },
    bridge_n = { x = 0.5200, y = 0.6000, label = "Approach the Beastwarrens bridge" },
    bridge_mid = { x = 0.5350, y = 0.6400, label = "Cross the bridge" },
    bridge_s = { x = 0.5500, y = 0.6800, label = "Cross the bridge" },

    bw1 = { x = 0.5700, y = 0.7000, label = "Follow the Beastwarrens road" },
    bw2 = { x = 0.5950, y = 0.6800, label = "Follow the Beastwarrens road" },
    desmo1 = { x = 0.6200, y = 0.6200, label = "Travel toward Desmotaeron" },
    desmo2 = { x = 0.6400, y = 0.5600, label = "Travel toward Desmotaeron" },

    -- Outer path around Helgarde — prefer road over keep courtyard elites.
    bypass1 = { x = 0.6600, y = 0.5000, label = "Take the outer path around Helgarde", caution = true },
    bypass2 = { x = 0.6800, y = 0.4500, label = "Stay on the outer path", caution = true },
    bypass3 = { x = 0.6900, y = 0.3900, label = "Continue toward the raid platform", caution = true },

    approach = { x = 0.6950, y = 0.3500, label = "Approach the Sanctum platform" },
    sanctum = { x = 0.6974, y = 0.3201, label = "Sanctum of Domination", goals = { sanctum = true } },
}

-- Undirected road-safe links only.
MawLocalRoutes.EDGES = {
    { "venari", "torghast" },
    { "venari", "korthia_pad" },
    { "venari", "road_s1" },
    { "road_s1", "road_s2" },
    { "road_s2", "bridge_n" },
    { "bridge_n", "bridge_mid" },
    { "bridge_mid", "bridge_s" },
    { "bridge_s", "bw1" },
    { "bw1", "bw2" },
    { "bw2", "desmo1" },
    { "desmo1", "desmo2" },
    { "desmo2", "bypass1" },
    { "bypass1", "bypass2" },
    { "bypass2", "bypass3" },
    { "bypass3", "approach" },
    { "approach", "sanctum" },
}

function MawLocalRoutes:IsMawMap(mapId)
    return ns.TravelRegions and ns.TravelRegions:IsMawMap(mapId)
end

function MawLocalRoutes:CanonicalMap(mapId)
    if self:IsMawMap(mapId) then
        return MAW_MAP
    end
    return tonumber(mapId)
end

-- Prefer raw unit map + translate onto Maw 1543 (TravelRegions can miss micros).
function MawLocalRoutes:GetPlayerMawPosition()
    local rawMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    if not rawMap or not self:IsMawMap(rawMap) then
        local viaRegions = ns.TravelRegions and ns.TravelRegions:GetPlayerMapCoords()
        if viaRegions and self:IsMawMap(viaRegions.mapId) then
            return {
                mapId = MAW_MAP,
                x = viaRegions.x,
                y = viaRegions.y,
            }
        end
        return nil
    end

    local pos = C_Map.GetPlayerMapPosition(rawMap, "player")
    if not pos then
        return nil
    end

    local x, y = pos.x, pos.y
    if rawMap ~= MAW_MAP then
        local HBD = LibStub("HereBeDragons-2.0", true)
        if HBD and HBD.TranslateZoneCoordinates then
            local tx, ty = HBD:TranslateZoneCoordinates(x, y, rawMap, MAW_MAP, true)
            if tx and ty then
                x, y = tx, ty
            end
        end
    end

    if not x or not y then
        return nil
    end

    return { mapId = MAW_MAP, x = x, y = y, rawMapId = rawMap }
end

function MawLocalRoutes:MakeLoc(mapId, x, y)
    return {
        mapId = mapId,
        pos = { x = x, y = y, z = 0 },
        isUI = true,
    }
end

function MawLocalRoutes:MakeEdge(loca, mapId, x, y, opts)
    opts = opts or {}
    local loc = self:MakeLoc(mapId, x, y)
    return {
        loca = loca,
        loc = loc,
        completionLoc = loc,
        checkDistance = opts.checkDistance ~= false,
        isPortalStep = opts.isPortalStep,
        portalDestMap = opts.portalDestMap,
        mawCaution = opts.caution,
    }
end

function MawLocalRoutes:DistanceSq(xA, yA, xB, yB)
    if not xA or not yA or not xB or not yB then
        return math.huge
    end
    local dx, dy = xA - xB, yA - yB
    return dx * dx + dy * dy
end

function MawLocalRoutes:Yards(mapId, xA, yA, xB, yB)
    if ns.MapCoords and ns.MapCoords.GetZoneDistance then
        local yards = ns.MapCoords:GetZoneDistance(mapId, xA, yA, mapId, xB, yB)
        if yards then
            return yards
        end
    end
    return math.sqrt(self:DistanceSq(xA, yA, xB, yB)) * 1000
end

function MawLocalRoutes:IsNear(mapId, xA, yA, xB, yB)
    return self:Yards(mapId, xA, yA, xB, yB) <= STEP_NEAR_YARDS
end

function MawLocalRoutes:BuildAdjacency()
    if self._adj then
        return self._adj
    end
    local adj = {}
    for id in pairs(self.NODES) do
        adj[id] = {}
    end
    for _, edge in ipairs(self.EDGES) do
        local a, b = edge[1], edge[2]
        if self.NODES[a] and self.NODES[b] then
            adj[a][#adj[a] + 1] = b
            adj[b][#adj[b] + 1] = a
        end
    end
    self._adj = adj
    return adj
end

function MawLocalRoutes:FindNearestNode(x, y, preferHub)
    local bestId, bestDist, bestHubId, bestHubDist
    for id, node in pairs(self.NODES) do
        local d = self:DistanceSq(x, y, node.x, node.y)
        if not bestDist or d < bestDist then
            bestDist = d
            bestId = id
        end
        if preferHub and node.hub and (not bestHubDist or d < bestHubDist) then
            bestHubDist = d
            bestHubId = id
        end
    end
    if preferHub and bestHubId and bestHubDist and bestHubDist <= (SNAP_NODE_UI * SNAP_NODE_UI * 4) then
        return bestHubId, math.sqrt(bestHubDist)
    end
    return bestId, bestDist and math.sqrt(bestDist) or nil
end

function MawLocalRoutes:FindNodePath(fromId, toId)
    if not fromId or not toId then
        return nil
    end
    if fromId == toId then
        return { fromId }
    end

    local adj = self:BuildAdjacency()
    local queue = { fromId }
    local prev = { [fromId] = false }
    local qi = 1

    while qi <= #queue do
        local current = queue[qi]
        qi = qi + 1
        for _, nextId in ipairs(adj[current] or {}) do
            if prev[nextId] == nil then
                prev[nextId] = current
                if nextId == toId then
                    local path = { toId }
                    local walk = toId
                    while prev[walk] do
                        walk = prev[walk]
                        table.insert(path, 1, walk)
                    end
                    return path
                end
                queue[#queue + 1] = nextId
            end
        end
    end
    return nil
end

function MawLocalRoutes:MatchGoal(dest)
    if not dest then
        return nil
    end

    local name = string.lower(tostring(dest.name or ""))
    local mapId = tonumber(dest.mapId)
    local journalId = tonumber(dest.journalId)

    if mapId == KORTHIA_MAP or name:find("korthia", 1, true) then
        return "korthia"
    end
    -- Sanctum of Domination journalId 1193
    if journalId == 1193
        or name:find("sanctum of domination", 1, true)
        or (name:find("sanctum", 1, true) and name:find("domination", 1, true)) then
        return "sanctum"
    end
    if name:find("torghast", 1, true) then
        return "torghast"
    end
    if name:find("ve'nari", 1, true) or name:find("venari", 1, true) then
        return "venari"
    end

    return nil
end

function MawLocalRoutes:NodeForGoal(goal)
    if not goal then
        return nil
    end
    for id, node in pairs(self.NODES) do
        if node.goals and node.goals[goal] then
            return id
        end
    end
    return nil
end

function MawLocalRoutes:ResolveEndNode(dest)
    local goal = self:MatchGoal(dest)
    if goal then
        local id = self:NodeForGoal(goal)
        if id then
            return id, self.NODES[id], true
        end
    end

    local destMap = self:CanonicalMap(dest.mapId)
    if destMap ~= MAW_MAP then
        return nil
    end

    local dx = ns.Destination:NormalizeUICoord(dest.x)
    local dy = ns.Destination:NormalizeUICoord(dest.y)
    if not dx or not dy then
        return nil
    end

    local nearestId, dist = self:FindNearestNode(dx, dy)
    if not nearestId or not dist or dist > SNAP_NODE_UI then
        -- Dest is off the safe spine — refuse rather than invent pins.
        return nil
    end
    return nearestId, self.NODES[nearestId], dist <= FINAL_PIN_UI
end

function MawLocalRoutes:ShouldUseFor(dest)
    if not dest then
        return false
    end

    local player = self:GetPlayerMawPosition()
    if not player then
        return false
    end

    if self:MatchGoal(dest) then
        return true
    end

    if not dest.mapId then
        return false
    end

    if ns.TravelRegions and ns.TravelRegions:IsMawRelatedDest(dest.mapId) then
        return true
    end

    -- Dest pin sits on Maw even if typed oddly.
    return self:IsMawMap(dest.mapId)
end

function MawLocalRoutes:AppendNodeStep(steps, nodeId, forceLabel)
    local node = self.NODES[nodeId]
    if not node then
        return
    end

    local label = forceLabel or node.label
    if node.caution then
        label = label .. " (elites nearby — stay on the outer path)"
    end

    local opts = {
        checkDistance = true,
        caution = node.caution,
    }
    if node.portalTo then
        opts.isPortalStep = true
        opts.portalDestMap = node.portalTo
        opts.checkDistance = true
    end

    steps[#steps + 1] = self:MakeEdge(label, MAW_MAP, node.x, node.y, opts)
end

function MawLocalRoutes:BuildRoute(dest)
    local player = self:GetPlayerMawPosition()
    if not player then
        return nil
    end

    local px = ns.Destination:NormalizeUICoord(player.x)
    local py = ns.Destination:NormalizeUICoord(player.y)
    if not px or not py then
        return nil
    end

    local endId, endNode, allowExact = self:ResolveEndNode(dest)
    if not endId or not endNode then
        return nil
    end

    local startId = self:FindNearestNode(px, py, true)
    if not startId then
        return nil
    end

    -- If player is far from the spine, funnel through Ve'nari hub first.
    local startNode = self.NODES[startId]
    local distToStart = math.sqrt(self:DistanceSq(px, py, startNode.x, startNode.y))
    if distToStart > SNAP_NODE_UI * 1.6 and startId ~= "venari" then
        local viaHub = self:FindNodePath("venari", endId)
        if viaHub then
            startId = "venari"
        end
    end

    local nodePath = self:FindNodePath(startId, endId)
    if not nodePath then
        return nil
    end

    local steps = {}

    -- Guide onto the first spine pin if not already there.
    if not self:IsNear(MAW_MAP, px, py, self.NODES[nodePath[1]].x, self.NODES[nodePath[1]].y) then
        self:AppendNodeStep(steps, nodePath[1], "Return to the safe road: " .. self.NODES[nodePath[1]].label)
    end

    for i = 2, #nodePath do
        self:AppendNodeStep(steps, nodePath[i])
    end

    -- Exact dest pin only when already on/near the spine end (drop-safe).
    local destMap, destX, destY = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
    if allowExact and destMap and destX and destY and self:CanonicalMap(destMap) == MAW_MAP then
        local last = steps[#steps]
        local lastX = last and last.loc and last.loc.pos and last.loc.pos.x
        local lastY = last and last.loc and last.loc.pos and last.loc.pos.y
        if lastX and lastY and self:DistanceSq(lastX, lastY, destX, destY) > (0.008 * 0.008) then
            if math.sqrt(self:DistanceSq(endNode.x, endNode.y, destX, destY)) <= FINAL_PIN_UI then
                steps[#steps + 1] = self:MakeEdge(
                    string.format("Arrive at %s", dest.name or endNode.label),
                    MAW_MAP,
                    destX,
                    destY,
                    { checkDistance = true }
                )
            end
        end
    elseif endNode.portalTo and destMap == endNode.portalTo then
        -- Korthia: final step already the teleporter pin.
    end

    if #steps == 0 then
        self:AppendNodeStep(steps, endId, string.format("Arrive at %s", dest.name or endNode.label))
    end

    return {
        optimizedPath = steps,
        path = {},
        edges = {},
        destination = dest,
        mawLocal = true,
        fallback = true, -- prevent StepBuilder from appending unsafe straight arrive
    }
end

function MawLocalRoutes:TryRoute(dest)
    if not self:ShouldUseFor(dest) then
        return nil
    end
    local ok, result = pcall(self.BuildRoute, self, dest)
    if not ok then
        if WowGPS and WowGPS.Print then
            WowGPS:Print("|cffFF4444WowGPS:|r Maw route error: " .. tostring(result))
        end
        return nil
    end
    return result
end
