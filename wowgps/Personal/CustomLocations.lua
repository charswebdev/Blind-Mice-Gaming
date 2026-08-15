local _, ns = ...

local CustomLocations = {}
ns.CustomLocations = CustomLocations

local function newId()
    return tostring(time()) .. "-" .. tostring(math.random(1000, 9999))
end

function CustomLocations:NormalizeTags(tags)
    if type(tags) == "string" then
        if tags == "" then
            return {}
        end
        local result = {}
        local sep = ns.Constants.TAG_SEPARATOR
        for part in tags:gmatch("[^" .. sep .. "]+") do
            part = part:match("^%s*(.-)%s*$")
            if part ~= "" then
                result[#result + 1] = part
            end
        end
        return result
    end

    if type(tags) ~= "table" then
        return {}
    end

    local result = {}
    local seen = {}
    for _, tag in ipairs(tags) do
        if type(tag) == "string" and tag ~= "" and not seen[tag] then
            seen[tag] = true
            result[#result + 1] = tag
        end
    end
    return result
end

function CustomLocations:GetTags(record)
    if not record then
        return {}
    end
    local tags
    if record.tags then
        tags = self:NormalizeTags(record.tags)
    elseif record.tag and record.tag ~= "" then
        tags = self:NormalizeTags(record.tag)
    else
        tags = {}
    end
    if ns.LocationTags then
        return ns.LocationTags:FilterValid(tags)
    end
    return tags
end

function CustomLocations:RecordHasTag(record, filterTag)
    if not filterTag or filterTag == "all" then
        return true
    end
    for _, tag in ipairs(self:GetTags(record)) do
        if tag == filterTag then
            return true
        end
    end
    return false
end

function CustomLocations:FormatTagsForExport(record)
    return table.concat(self:GetTags(record), ns.Constants.TAG_SEPARATOR)
end

function CustomLocations:NormalizeRecordId(id)
    return tostring(id or ""):gsub("^custom:", "")
end

function CustomLocations:GetStore(scope)
    return ns.Database:GetPersonalStore(scope or "account")
end

function CustomLocations:ToDestination(record)
    local mapId, x, y = ns.Destination:NormalizeMapCoords(record.mapId, record.x, record.y)
    if not mapId then
        mapId = record.mapId
        x = record.x
        y = record.y
    end

    return {
        id = "custom:" .. record.id,
        name = record.name,
        type = ns.Constants.DEST_TYPES.CUSTOM,
        mapId = mapId,
        x = x,
        y = y,
        z = record.z or 0,
        tags = self:GetTags(record),
        note = record.note,
        scope = record.scope,
        areaName = record.areaName,
        custom = true,
        flavor = record.flavor,
    }
end

function CustomLocations:GetPlayerLocation()
    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then
        return nil, "no_map"
    end

    local pos = C_Map.GetPlayerMapPosition(mapId, "player")
    if not pos then
        return nil, "no_position"
    end

    local zoneMapId = mapId
    local x, y = pos.x, pos.y
    if ns.TravelRegions then
        local player = ns.TravelRegions:GetPlayerMapCoords()
        if player and player.mapId then
            zoneMapId = player.mapId
            x = player.x or x
            y = player.y or y
        else
            zoneMapId = ns.TravelRegions:ResolveZoneMapId(mapId) or mapId
        end
    end

    local mapInfo = C_Map.GetMapInfo(zoneMapId)
    return {
        mapId = zoneMapId,
        x = x,
        y = y,
        z = 0,
        areaName = mapInfo and mapInfo.name or "",
    }
end

function CustomLocations:NormalizeCoord(value)
    local n = tonumber(value)
    if not n then
        return nil
    end
    if n > 1 then
        n = n / 100
    end
    if n < 0 or n > 1 then
        return nil
    end
    return n
end

function CustomLocations:ResolveMapId(zoneName, mapIdText)
    local mapId = tonumber(mapIdText)
    if mapId then
        local mapInfo = C_Map.GetMapInfo(mapId)
        if mapInfo then
            return mapId, mapInfo.name or zoneName or ""
        end
        return nil
    end

    zoneName = (zoneName or ""):match("^%s*(.-)%s*$")
    if not zoneName or zoneName == "" then
        return nil
    end

    local hashId = zoneName:match("^#(%d+)$")
    if hashId then
        mapId = tonumber(hashId)
        local mapInfo = mapId and C_Map.GetMapInfo(mapId)
        if mapInfo then
            return mapId, mapInfo.name or zoneName
        end
    end

    local dest = ns.Destination and ns.Destination:ResolveByName(zoneName)
    if dest and dest.mapId then
        local mapInfo = C_Map.GetMapInfo(dest.mapId)
        return dest.mapId, mapInfo and mapInfo.name or dest.name or zoneName
    end

    local playerMapId = C_Map.GetBestMapForUnit("player")
    if playerMapId then
        local mapInfo = C_Map.GetMapInfo(playerMapId)
        if mapInfo and mapInfo.name and mapInfo.name:lower() == zoneName:lower() then
            return playerMapId, mapInfo.name
        end
    end

    local hbd = LibStub("HereBeDragons-2.0", true)
    if hbd and hbd.mapData then
        local lzone = zoneName:lower():gsub("%s+", "")
        local exactId, exactName, partialId, partialName
        for id, data in pairs(hbd.mapData) do
            local name = data and data.name
            if name then
                local lname = name:lower():gsub("%s+", "")
                if lname == lzone then
                    exactId, exactName = id, name
                    break
                elseif not partialId and lname:find(lzone, 1, true) then
                    partialId, partialName = id, name
                end
            end
        end
        if exactId then
            return exactId, exactName
        end
        if partialId then
            return partialId, partialName
        end
    end

    return nil
end

function CustomLocations:ResolveManualLocation(zoneName, mapIdText, xText, yText)
    local x = self:NormalizeCoord(xText)
    local y = self:NormalizeCoord(yText)
    if not x or not y then
        return nil, "bad_coords"
    end

    local mapId, areaName = self:ResolveMapId(zoneName, mapIdText)
    if not mapId then
        return nil, "bad_map"
    end

    return {
        mapId = mapId,
        x = x,
        y = y,
        z = 0,
        areaName = areaName or zoneName or "",
    }
end

function CustomLocations:GetRecord(id, scope)
    local store = self:GetStore(scope)
    return store[self:NormalizeRecordId(id)]
end

function CustomLocations:FormatCoords(record)
    if not record then
        return ""
    end
    return string.format("%.1f, %.1f", (record.x or 0) * 100, (record.y or 0) * 100)
end

function CustomLocations:FormatLocationLine(record)
    if not record then
        return ""
    end
    local area = record.areaName or ""
    local coords = self:FormatCoords(record)
    if area ~= "" then
        return string.format("%s (%s)", area, coords)
    end
    return coords
end

function CustomLocations:Save(name, scope, tags, note, location)
    if not location then
        location = self:GetPlayerLocation()
    end
    if not location or not location.mapId then
        return false, "no_map"
    end
    if location.x == nil or location.y == nil then
        return false, "bad_coords"
    end

    local mapInfo = C_Map.GetMapInfo(location.mapId)
    local normalizedTags = self:NormalizeTags(tags)
    if ns.LocationTags then
        normalizedTags = ns.LocationTags:FilterValid(normalizedTags)
    end
    local record = {
        id = newId(),
        name = name,
        scope = scope or ns.Database:GetProfile().defaultCustomScope or "account",
        tags = normalizedTags,
        note = note or "",
        mapId = location.mapId,
        x = location.x,
        y = location.y,
        z = location.z or 0,
        areaName = location.areaName or (mapInfo and mapInfo.name) or "",
        flavor = ns.Destination:GetFlavor(),
        createdAt = time(),
    }

    local store = self:GetStore(record.scope)
    store[record.id] = record
    return true, record
end

function CustomLocations:Update(id, scope, name, tags, note, location, originalScope)
    id = self:NormalizeRecordId(id)
    originalScope = originalScope or scope or "account"
    scope = scope or originalScope

    local store = self:GetStore(originalScope)
    local record = store[id]
    if not record then
        return false, "not_found"
    end
    if not location or not location.mapId or location.x == nil or location.y == nil then
        return false, "bad_coords"
    end

    local mapInfo = C_Map.GetMapInfo(location.mapId)
    local normalizedTags = self:NormalizeTags(tags)
    if ns.LocationTags then
        normalizedTags = ns.LocationTags:FilterValid(normalizedTags)
    end

    record.name = name
    record.tags = normalizedTags
    record.tag = nil
    record.note = note or ""
    record.mapId = location.mapId
    record.x = location.x
    record.y = location.y
    record.z = location.z or 0
    record.areaName = location.areaName or (mapInfo and mapInfo.name) or ""
    record.scope = scope

    if scope ~= originalScope then
        store[id] = nil
        self:GetStore(scope)[id] = record
    end

    return true, record
end

function CustomLocations:Delete(id, scope)
    local store = self:GetStore(scope)
    store[self:NormalizeRecordId(id)] = nil
end

function CustomLocations:FindByName(name)
    local query = name:lower()
    for _, scope in ipairs({ "account", "character" }) do
        local store = self:GetStore(scope)
        for _, record in pairs(store) do
            if record.name:lower() == query then
                return self:ToDestination(record)
            end
        end
    end
end

function CustomLocations:Search(query, filters)
    local q = query:lower()
    local results = {}
    filters = filters or {}

    local function include(record)
        local dest = self:ToDestination(record)
        if not ns.LocationTags:EntryMatchesType(dest, filters.type) then
            return false
        end
        if filters.tag and filters.tag ~= "all" and not self:RecordHasTag(record, filters.tag) then
            return false
        end
        if filters.scope and filters.scope ~= "all" and record.scope ~= filters.scope then
            return false
        end
        return record.name:lower():find(q, 1, true) ~= nil
            or (record.note and record.note:lower():find(q, 1, true))
    end

    for _, scope in ipairs({ "account", "character" }) do
        local store = self:GetStore(scope)
        for _, record in pairs(store) do
            if include(record) then
                results[#results + 1] = self:ToDestination(record)
            end
        end
    end

    return results
end

function CustomLocations:List(scope)
    local list = {}
    local store = self:GetStore(scope)
    for _, record in pairs(store) do
        list[#list + 1] = record
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

function CustomLocations:Export(id, scope)
    id = self:NormalizeRecordId(id)
    local store = self:GetStore(scope)
    local record = store[id]
    if not record then
        return nil
    end
    return string.format(
        "WGPS:%s:%d:%.4f:%.4f:%s:%s:%s",
        record.name:gsub(":", " "),
        record.mapId,
        record.x,
        record.y,
        self:FormatTagsForExport(record):gsub(":", " "),
        record.scope or "account",
        (record.note or ""):gsub(":", " ")
    )
end

function CustomLocations:FindMapIdByZoneName(zoneName)
    return select(1, self:ResolveMapId(zoneName, nil))
end

function CustomLocations:NormalizeWayLine(line)
    line = (line or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if line == "" then
        return ""
    end

    -- Strip common slash command prefixes (TomTom / Wowhead / WOWNavs style).
    line = line:gsub("^[/%\\]*[Tt]om[Tt]om[Ww]ay%s+", "")
    line = line:gsub("^[/%\\]*[Tt]way%s+", "")
    line = line:gsub("^[/%\\]*[Ww]ay%s+", "")

    -- "45.2, 60.1" / "45,2 60,1" style separators.
    local wrongSep = "(%d)" .. (tonumber("1.1") and "," or ".") .. "(%d)"
    local rightSep = "%1" .. (tonumber("1.1") and "." or ",") .. "%2"
    line = line:gsub("(%d)[%.,]%s+(%d)", "%1 %2"):gsub(wrongSep, rightSep)
    return line
end

function CustomLocations:ParseWayLine(line)
    line = self:NormalizeWayLine(line)
    if line == "" or line:match("^[Ww][Gg][Pp][Ss]:") then
        return nil
    end

    local tokens = {}
    for token in line:gmatch("%S+") do
        tokens[#tokens + 1] = token
    end
    if #tokens < 2 then
        return nil
    end

    local first = tokens[1]:lower()
    if first == "local" or first == "list" or first == "arrow" or first == "block" or first == "reset" then
        return nil
    end

    local mapId, x, y, name
    local hashId = tokens[1]:match("^#(%d+)$")
    if hashId then
        mapId = tonumber(hashId)
        x = tonumber(tokens[2])
        y = tonumber(tokens[3])
        if tokens[4] then
            name = table.concat(tokens, " ", 4)
        end
    elseif tonumber(tokens[1]) then
        x = tonumber(tokens[1])
        y = tonumber(tokens[2])
        mapId = C_Map.GetBestMapForUnit("player")
        if ns.TravelRegions then
            mapId = ns.TravelRegions:ResolveZoneMapId(mapId) or mapId
        end
        if tokens[3] then
            name = table.concat(tokens, " ", 3)
        end
    else
        local zoneEnd
        for i = 1, #tokens do
            if tonumber(tokens[i]) then
                zoneEnd = i - 1
                break
            end
        end
        if not zoneEnd or zoneEnd < 1 then
            return nil
        end
        local zone = table.concat(tokens, " ", 1, zoneEnd)
        x = tonumber(tokens[zoneEnd + 1])
        y = tonumber(tokens[zoneEnd + 2])
        if tokens[zoneEnd + 3] then
            name = table.concat(tokens, " ", zoneEnd + 3)
        end
        mapId = self:FindMapIdByZoneName(zone)
    end

    x = self:NormalizeCoord(x)
    y = self:NormalizeCoord(y)
    mapId = tonumber(mapId)
    if not mapId or not x or not y then
        return nil
    end

    local mapInfo = C_Map.GetMapInfo(mapId)
    if not mapInfo then
        return nil
    end

    local areaName = mapInfo.name or ""
    if not name or name == "" then
        name = string.format("%s (%.1f, %.1f)", areaName ~= "" and areaName or "Waypoint", x * 100, y * 100)
    end

    return {
        name = name,
        mapId = mapId,
        x = x,
        y = y,
        areaName = areaName,
        tags = {},
        note = "",
        scope = (ns.Database and ns.Database:GetProfile().defaultCustomScope) or "account",
    }
end

function CustomLocations:ParseWgpsLine(line)
    line = (line or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local name, mapId, x, y, tagField, scope, note =
        line:match("^WGPS:([^:]+):(%d+):([%d%.]+):([%d%.]+):([^:]*):([^:]+):?(.*)$")
    if not name then
        return nil
    end

    mapId = tonumber(mapId)
    x = tonumber(x)
    y = tonumber(y)
    if not mapId or not x or not y then
        return nil
    end

    -- WGPS exports fractional 0-1 coords; accept percent values too.
    if x > 1 then
        x = self:NormalizeCoord(x)
    end
    if y > 1 then
        y = self:NormalizeCoord(y)
    end
    if not x or not y or x > 1 or y > 1 then
        return nil
    end

    local mapInfo = C_Map.GetMapInfo(mapId)
    return {
        name = name,
        mapId = mapId,
        x = x,
        y = y,
        areaName = mapInfo and mapInfo.name or "",
        tags = self:NormalizeTags(tagField or ""),
        note = note or "",
        scope = scope or "account",
    }
end

function CustomLocations:StoreImported(parsed)
    if not parsed or not parsed.mapId or parsed.x == nil or parsed.y == nil then
        return nil
    end

    local scope = parsed.scope or "account"
    if scope ~= "account" and scope ~= "character" then
        scope = "account"
    end

    local record = {
        id = newId(),
        name = parsed.name,
        mapId = parsed.mapId,
        x = parsed.x,
        y = parsed.y,
        areaName = parsed.areaName or "",
        tags = self:NormalizeTags(parsed.tags or {}),
        tag = nil,
        scope = scope,
        note = parsed.note or "",
        z = 0,
        flavor = ns.Destination:GetFlavor(),
        createdAt = time(),
    }
    local store = self:GetStore(record.scope)
    store[record.id] = record
    return record
end

function CustomLocations:Import(dataString)
    dataString = (dataString or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if dataString == "" then
        return false, "bad_format", 0
    end

    local imported = 0
    local lastRecord

    -- Prefer line-by-line so multi-/way pastes and mixed WGPS lines both work.
    for line in (dataString .. "\n"):gmatch("(.-)\r?\n") do
        local trimmed = line:match("^%s*(.-)%s*$") or ""
        if trimmed ~= "" then
            local parsed = self:ParseWgpsLine(trimmed) or self:ParseWayLine(trimmed)
            if parsed then
                local record = self:StoreImported(parsed)
                if record then
                    imported = imported + 1
                    lastRecord = record
                end
            end
        end
    end

    -- Fallback: whole blob as a single WGPS string (legacy / no newline).
    if imported == 0 then
        local parsed = self:ParseWgpsLine(dataString) or self:ParseWayLine(dataString)
        if parsed then
            lastRecord = self:StoreImported(parsed)
            if lastRecord then
                imported = 1
            end
        end
    end

    if imported == 0 then
        return false, "bad_format", 0
    end
    return true, lastRecord, imported
end
