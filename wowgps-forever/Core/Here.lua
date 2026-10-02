local _, GPS = ...

GPS.Here = GPS.Here or {}
local Here = GPS.Here

local function AsFraction(value)
    local n = GPS:PlainNumber(value)
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

local function VectorXY(pos)
    if type(pos) ~= "table" then
        return nil, nil
    end
    local rawX, rawY
    if type(pos.GetXY) == "function" then
        local ok, a, b = pcall(pos.GetXY, pos)
        if ok then
            rawX, rawY = a, b
        end
    end
    local x = AsFraction(rawX)
    local y = AsFraction(rawY)
    if x and y then
        return x, y
    end
    return AsFraction(pos.x), AsFraction(pos.y)
end

local function MapName(mapId)
    if not mapId or not C_Map or not C_Map.GetMapInfo then
        return nil
    end
    local ok, info = pcall(C_Map.GetMapInfo, mapId)
    if not ok or type(info) ~= "table" then
        return nil
    end
    return GPS:PlainString(info.name)
end

local function CallText(fn)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, value = pcall(fn)
    if not ok then
        return nil
    end
    return GPS:PlainString(value)
end

function Here:Read()
    local zone = CallText(GetZoneText)
    local sub = CallText(GetSubZoneText)
    local mapId
    local x, y

    if C_Map and C_Map.GetBestMapForUnit then
        local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
        if ok then
            mapId = GPS:PlainNumber(id)
        end
    end

    if mapId and C_Map.GetPlayerMapPosition then
        local ok, pos = pcall(C_Map.GetPlayerMapPosition, mapId, "player")
        if ok then
            x, y = VectorXY(pos)
        end
    end

    if (not x or not y) and GetPlayerMapPosition then
        local ok, px, py = pcall(GetPlayerMapPosition, "player")
        if ok then
            x = x or AsFraction(px)
            y = y or AsFraction(py)
        end
    end

    local name = MapName(mapId) or zone
    if sub and zone and sub ~= zone then
        name = sub .. ", " .. zone
    elseif sub and not name then
        name = sub
    end

    return {
        zone = name,
        x = x,
        y = y,
        mapId = mapId,
    }
end

function Here:FormatZone(here)
    if here and here.zone then
        return here.zone
    end
    return "You are here"
end

function Here:FormatCoords(here)
    if here and here.x and here.y then
        return string.format("%.1f, %.1f", here.x * 100, here.y * 100)
    end
    return "Coordinates are not available."
end

function Here:Update()
    local ok, here = pcall(function()
        return self:Read()
    end)
    if not ok or type(here) ~= "table" then
        here = nil
    end
    if GPS.Search and GPS.Search.SetHere then
        GPS.Search:SetHere(self:FormatZone(here), self:FormatCoords(here))
    end
end

function Here:Start()
    self:Update()
    if self.ticker then
        return
    end
    if C_Timer and type(C_Timer.NewTicker) == "function" then
        self.ticker = C_Timer.NewTicker(0.5, function()
            Here:Update()
        end)
        return
    end
    if not self.pulse then
        self.pulse = CreateFrame("Frame")
        self.pulse.elapsed = 0
        self.pulse:SetScript("OnUpdate", function(frame, elapsed)
            local step = GPS:PlainNumber(elapsed) or 0
            frame.elapsed = frame.elapsed + step
            if frame.elapsed < 0.5 then
                return
            end
            frame.elapsed = 0
            Here:Update()
        end)
    end
    self.pulse:Show()
end

function Here:Stop()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    if self.pulse then
        self.pulse:Hide()
    end
end
