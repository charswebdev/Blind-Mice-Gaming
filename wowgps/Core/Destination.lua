local _, ns = ...

local Destination = {}
ns.Destination = Destination

--- Official static destinations: AreaTable catalog first, seed only as fallback.
local function getOfficial()
    if ns.DestinationsCatalog and #ns.DestinationsCatalog > 0 then
        return ns.DestinationsCatalog
    end
    return ns.DestinationsSeed or {}
end

local function normalize(text)
    return (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function flavor()
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        return "retail"
    elseif WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        return "vanilla"
    elseif WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC then
        return "tbc"
    elseif WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC then
        return "wrath"
    elseif WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC then
        return "cata"
    elseif WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC then
        return "mists"
    end
    return "retail"
end

function Destination:GetFlavor()
    return flavor()
end

function Destination:NormalizeUICoord(value)
    local v = tonumber(value)
    if not v then
        return nil
    end
    if v > 1 then
        if v >= 100 then
            return v / 10000
        end
        return v / 100
    end
    if v < 0 then
        return nil
    end
    return v
end

function Destination:GetZoneName(entry)
    if not entry then
        return nil
    end

    local area = entry.areaName
    if type(area) == "string" and area ~= "" then
        return area
    end

    local mapId = tonumber(entry.mapId)
    if not mapId then
        return nil
    end

    if ns.TravelRegions then
        local resolved = ns.TravelRegions:ResolveZoneMapId(mapId) or mapId
        local name = ns.TravelRegions:GetMapName(resolved)
        if name and name ~= "" then
            return name
        end
    end

    if C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapId)
        if info and info.name and info.name ~= "" then
            return info.name
        end
    end

    return nil
end

function Destination:FormatZoneLine(entry)
    local name = self:GetZoneName(entry)
    if not name then
        return nil
    end
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS", true)
    local fmt = (L and L["ZONE_LINE"]) or "Zone: %s"
    return string.format(fmt, name)
end

function Destination:NormalizeMapCoords(mapId, x, y)
    mapId = tonumber(mapId)
    x = self:NormalizeUICoord(x)
    y = self:NormalizeUICoord(y)
    if not mapId or not x or not y or x > 1 or y > 1 then
        return nil
    end
    return mapId, x, y
end

function Destination:ToNavStep(dest, text)
    if not dest then
        return nil
    end
    local mapId, x, y = self:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
    if not mapId then
        return nil
    end
    local label = text or dest.name or "Destination"
    return {
        text = label,
        mapId = mapId,
        x = x,
        y = y,
        z = dest.z or 0,
        completionMapId = mapId,
        completionX = x,
        completionY = y,
    }
end

function Destination:ParseCoordinateInput(text)
    -- /way Zone 45.2 60.1  or  45.2, 60.1
    local zone, x, y = text:match("^%s*([%w%s'%-%?]+)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s*$")
    if zone and x and y then
        local dest = self:ResolveByName(zone)
        if dest then
            return {
                id = "coord:" .. dest.id,
                name = string.format("%s (%.1f, %.1f)", dest.name, tonumber(x), tonumber(y)),
                type = ns.Constants.DEST_TYPES.COORD,
                mapId = dest.mapId,
                x = tonumber(x) / 100,
                y = tonumber(y) / 100,
                z = 0,
            }
        end
    end

    local px, py = text:match("^%s*(%d+%.?%d*)[%s,]+(%d+%.?%d*)%s*$")
    if px and py then
        local mapId = C_Map.GetBestMapForUnit("player")
        if mapId then
            return {
                id = "coord:here",
                name = string.format("(%.1f, %.1f)", tonumber(px), tonumber(py)),
                type = ns.Constants.DEST_TYPES.COORD,
                mapId = mapId,
                x = tonumber(px) / 100,
                y = tonumber(py) / 100,
                z = 0,
            }
        end
    end
end

function Destination:FromMapPin(mapId, x, y, displayName)
    mapId, x, y = self:NormalizeMapCoords(mapId, x, y)
    if not mapId then
        return nil
    end

    local name = displayName
    if name and name ~= "" then
        local linkLabel = name:match("|h(.-)|h")
        if linkLabel and linkLabel ~= "" then
            name = linkLabel
        end
        name = name:gsub("|c%x%x%x%x%x%x%x%x", "")
        name = name:gsub("|r", "")
        name = name:gsub("|h", "")
        name = name:gsub("|H[^|]+|h", "")
        name = name:gsub("[%[%]]", "")
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
    end
    if not name or name == "" then
        local mapInfo = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapId)
        local zone = (mapInfo and mapInfo.name) or ("Map " .. tostring(mapId))
        name = string.format("%s (%.1f, %.1f)", zone, x * 100, y * 100)
    end

    return {
        id = string.format("mappin:%d:%.4f:%.4f", mapId, x, y),
        name = name,
        type = ns.Constants.DEST_TYPES.COORD,
        mapId = mapId,
        x = x,
        y = y,
        z = 0,
    }
end

function Destination:ResolveByName(name)
    local query = normalize(name)
    if query == "" then
        return nil
    end

    local coord = self:ParseCoordinateInput(name)
    if coord then
        return coord
    end

    local best
    for _, entry in ipairs(getOfficial()) do
        if entry.flavor == flavor() or entry.flavor == "all" then
            local n = normalize(entry.name)
            if n == query then
                return entry
            end
            if not best and n:find(query, 1, true) then
                best = entry
            end
        end
    end

    if best then
        return best
    end

    local custom = ns.CustomLocations:FindByName(name)
    if custom then
        return custom
    end

    return nil
end

function Destination:Search(query, filters)
    filters = filters or {}
    local q = normalize(query)
    local results = {}

    local function matchesType(entry)
        return ns.LocationTags:EntryMatchesType(entry, filters.type)
    end

    if q == "" then
        return results
    end

    for _, entry in ipairs(ns.CustomLocations:Search(q, filters)) do
        results[#results + 1] = entry
    end

    for _, entry in ipairs(getOfficial()) do
        if (entry.flavor == flavor() or entry.flavor == "all") and matchesType(entry) then
            if normalize(entry.name):find(q, 1, true) then
                results[#results + 1] = entry
            end
        end
    end

    table.sort(results, function(a, b)
        local aCustom = a.custom and 0 or 1
        local bCustom = b.custom and 0 or 1
        if aCustom ~= bCustom then
            return aCustom < bCustom
        end
        return tostring(a.name or "") < tostring(b.name or "")
    end)

    return results
end

function Destination:GetAllOfficial()
    local list = {}
    for _, entry in ipairs(getOfficial()) do
        if entry.flavor == flavor() or entry.flavor == "all" then
            list[#list + 1] = entry
        end
    end
    return list
end

--- Raw AreaTable (pack -> uiMapID -> points). Primary static data structure.
function Destination:GetAreaTable()
    return ns.AreaTable or {}
end

--- Exploration points for a uiMapID across all packs.
function Destination:GetPointsForMap(mapId)
    mapId = tonumber(mapId)
    if not mapId or not ns.AreaTable then
        return {}
    end
    local out = {}
    for _, maps in pairs(ns.AreaTable) do
        local points = maps[mapId]
        if points then
            for _, p in ipairs(points) do
                out[#out + 1] = p
            end
        end
    end
    return out
end

--- Lookup by Blizzard areaID when present on the catalog entry.
function Destination:GetByAreaID(areaID)
    areaID = tonumber(areaID)
    if not areaID then
        return nil
    end
    for _, entry in ipairs(getOfficial()) do
        if entry.areaID == areaID then
            return entry
        end
    end
    return nil
end
