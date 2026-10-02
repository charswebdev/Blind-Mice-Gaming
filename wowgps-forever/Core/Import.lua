local _, GPS = ...

GPS.Import = GPS.Import or {}
local Import = GPS.Import

local function Trim(text)
    return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function NormalizeCoord(value)
    local n = GPS:PlainNumber(value)
    if not n then
        n = tonumber(value)
        n = GPS:PlainNumber(n)
    end
    if not n then
        return nil
    end
    if n > 1 and n <= 100 then
        n = n / 100
    end
    if n < 0 or n > 1 then
        return nil
    end
    return n
end

local function MapName(mapId)
    if not mapId or not C_Map or not C_Map.GetMapInfo then
        return nil
    end
    local ok, info = pcall(C_Map.GetMapInfo, mapId)
    if not ok or type(info) ~= "table" then
        return nil
    end
    return GPS:PlainString(info.name) or ""
end

local function PlayerMap()
    if not C_Map or not C_Map.GetBestMapForUnit then
        return nil
    end
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    if not ok then
        return nil
    end
    return GPS:PlainNumber(id)
end

function Import:FindZone(zoneName)
    zoneName = Trim(zoneName)
    if zoneName == "" or not GPS.World or not GPS.World.List then
        return nil
    end
    local want = string.lower(zoneName)
    local ok, list = pcall(function()
        return GPS.World:List()
    end)
    if not ok or type(list) ~= "table" then
        return nil
    end
    local partial, partialCount
    for i = 1, #list do
        local row = list[i]
        if row.kind == "zone" or row.kind == "city" then
            local name = string.lower(row.name or "")
            if name == want then
                return row.mapId, row.name
            end
            if name ~= "" and (string.find(name, want, 1, true) or string.find(want, name, 1, true)) then
                partial = row
                partialCount = (partialCount or 0) + 1
            end
        end
    end
    if partialCount == 1 and partial then
        return partial.mapId, partial.name
    end
    return nil
end

function Import:NormalizeWay(line)
    line = Trim(line)
    line = line:gsub("^[/%\\]*[Tt]om[Tt]om[Ww]ay%s+", "")
    line = line:gsub("^[/%\\]*[Tt]way%s+", "")
    line = line:gsub("^[/%\\]*[Ww]ay%s+", "")
    line = line:gsub("(%d)[%.,]%s+(%d)", "%1 %2")
    if tonumber("1.1") then
        line = line:gsub("(%d),(%d)", "%1.%2")
    end
    return line
end

function Import:Finish(name, mapId, x, y, zone, tag, note, scope)
    mapId = GPS:PlainNumber(mapId)
    x = NormalizeCoord(x)
    y = NormalizeCoord(y)
    if not mapId or not x or not y then
        return nil
    end
    local area = MapName(mapId)
    if area == nil then
        return nil
    end
    if not name or name == "" then
        local label = area ~= "" and area or "Waypoint"
        name = string.format("%s (%.1f, %.1f)", label, x * 100, y * 100)
    end
    if scope ~= "character" then
        scope = "account"
    end
    return {
        name = name,
        mapId = mapId,
        x = x,
        y = y,
        zone = zone ~= "" and zone or area,
        tag = tag ~= "" and tag or nil,
        note = note or "",
        scope = scope,
    }
end

function Import:ParseWgps(line)
    local name, mapId, x, y, tagField, scope, note =
        line:match("^WGPS:([^:]+):(%d+):([%d%.]+):([%d%.]+):([^:]*):([^:]+):?(.*)$")
    if not name then
        return nil
    end
    local tag = tagField or ""
    local comma = string.find(tag, ",", 1, true)
    if comma then
        tag = string.sub(tag, 1, comma - 1)
    end
    return self:Finish(name, mapId, x, y, "", Trim(tag), note or "", scope)
end

function Import:ParseWay(line)
    line = self:NormalizeWay(line)
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
    local first = string.lower(tokens[1])
    if first == "local" or first == "list" or first == "arrow" or first == "block" or first == "reset" then
        return nil
    end

    local mapId, x, y, name, zone
    local hashId = tokens[1]:match("^#(%d+)$")
    if hashId then
        mapId = hashId
        x = tokens[2]
        y = tokens[3]
        if tokens[4] then
            name = table.concat(tokens, " ", 4)
        end
    elseif tonumber(tokens[1]) then
        x = tokens[1]
        y = tokens[2]
        mapId = PlayerMap()
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
        zone = table.concat(tokens, " ", 1, zoneEnd)
        x = tokens[zoneEnd + 1]
        y = tokens[zoneEnd + 2]
        if tokens[zoneEnd + 3] then
            name = table.concat(tokens, " ", zoneEnd + 3)
        end
        mapId = self:FindZone(zone)
    end
    return self:Finish(name, mapId, x, y, zone or "", "", "", "account")
end

function Import:ParseLine(line)
    line = Trim(line)
    if line == "" then
        return nil
    end
    return self:ParseWgps(line) or self:ParseWay(line)
end

function Import:Clean(text)
    text = GPS:PlainString(text) or ""
    return (text:gsub(":", " "):gsub("[\r\n]", " "))
end

function Import:Format(dest)
    if type(dest) ~= "table" then
        return nil
    end
    local name = self:Clean(dest.name)
    local mapId = GPS:PlainNumber(dest.mapId)
    local x = GPS:PlainNumber(dest.x)
    local y = GPS:PlainNumber(dest.y)
    if name == "" or not mapId or not x or not y then
        return nil
    end
    local scope = dest.scope == "character" and "character" or "account"
    return string.format(
        "WGPS:%s:%d:%.4f:%.4f:%s:%s:%s",
        name,
        mapId,
        x,
        y,
        self:Clean(dest.tag),
        scope,
        self:Clean(dest.note)
    )
end

function Import:FormatList(list)
    if type(list) ~= "table" then
        return nil
    end
    local lines = {}
    for i = 1, #list do
        local line = self:Format(list[i])
        if line then
            lines[#lines + 1] = line
        end
    end
    if #lines == 0 then
        return nil
    end
    return table.concat(lines, "\n")
end

function Import:Run(dataString)
    local text = GPS:PlainString(dataString)
    if not text then
        GPS:Print("Import failed. Paste a WowGPS string or /way Zone X Y Name.")
        return 0
    end
    local count = 0
    local sawLine = false
    for line in (text .. "\n"):gmatch("(.-)\r?\n") do
        local parsed = self:ParseLine(line)
        if Trim(line) ~= "" then
            sawLine = true
        end
        if parsed and GPS.Places and GPS.Places.Add then
            local saved = GPS.Places:Add(parsed)
            if saved then
                count = count + 1
            end
        end
    end
    if count == 0 and not sawLine then
        local parsed = self:ParseLine(text)
        if parsed and GPS.Places and GPS.Places.Add then
            local saved = GPS.Places:Add(parsed)
            if saved then
                count = 1
            end
        end
    end
    if count == 0 then
        GPS:Print("Import failed. Paste a WowGPS string or /way Zone X Y Name.")
        return 0
    end
    if count == 1 then
        GPS:Print("Imported 1 location.")
    else
        GPS:Print("Imported " .. count .. " locations.")
    end
    if GPS.Saved and GPS.Saved.Refresh then
        GPS.Saved:Refresh()
    end
    if GPS.Search and GPS.Search.Refresh then
        GPS.Search:Refresh()
    end
    if GPS.Main and GPS.Main.SelectTab and GPS.Main.frame then
        local shown = GPS.Main.frame:IsShown()
        if shown == true then
            GPS.Main:SelectTab("saved", false)
        end
    end
    return count
end
