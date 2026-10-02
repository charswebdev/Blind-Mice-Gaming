local _, GPS = ...

GPS.Guide = GPS.Guide or {}
local Guide = GPS.Guide

function Guide:FormatCoords(dest)
    if dest and dest.x and dest.y then
        return string.format("%.1f, %.1f", dest.x * 100, dest.y * 100)
    end
    return ""
end

function Guide:SetBlizzardPin(dest)
    if not C_Map or not C_Map.SetUserWaypoint or not UiMapPoint or not UiMapPoint.CreateFromCoordinates then
        return false
    end
    local ok, point = pcall(UiMapPoint.CreateFromCoordinates, dest.mapId, dest.x, dest.y)
    if not ok then
        return false
    end
    local setOk = pcall(C_Map.SetUserWaypoint, point)
    if setOk and C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
    return setOk
end

function Guide:ClearBlizzardPin()
    if C_Map and C_Map.ClearUserWaypoint then
        pcall(C_Map.ClearUserWaypoint)
    end
end

function Guide:SetTomTom(dest)
    if not TomTom or type(TomTom.AddWaypoint) ~= "function" then
        return false
    end
    if self.tomtomUid and type(TomTom.RemoveWaypoint) == "function" then
        pcall(TomTom.RemoveWaypoint, TomTom, self.tomtomUid)
        self.tomtomUid = nil
    end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, dest.mapId, dest.x, dest.y, {
        title = dest.name or "WowGPS",
        persistent = false,
        from = "WowGPS",
    })
    if not ok or not uid then
        return false
    end
    self.tomtomUid = uid
    return true
end

function Guide:ClearTomTom()
    if self.tomtomUid and TomTom and type(TomTom.RemoveWaypoint) == "function" then
        pcall(TomTom.RemoveWaypoint, TomTom, self.tomtomUid)
    end
    self.tomtomUid = nil
end

function Guide:ArrowTarget()
    local dest = self.dest
    local steps = self.steps
    if not dest then
        return nil
    end
    if not steps or #steps == 0 then
        return dest
    end
    local here = GPS.Here and GPS.Here:Read()
    if not here or not here.mapId then
        return steps[1]
    end
    if here.mapId == dest.mapId then
        return steps[#steps]
    end
    local function CloseTo(step)
        if step.mapId ~= here.mapId or not here.x or not here.y or not step.x or not step.y then
            return false
        end
        local dx = here.x - step.x
        local dy = here.y - step.y
        return (dx * dx + dy * dy) < 0.0004
    end
    for i = 1, #steps - 1 do
        local step = steps[i]
        if step.mapId == here.mapId and not CloseTo(step) then
            return step
        end
    end
    local lastDone = 0
    for i = 1, #steps - 1 do
        if CloseTo(steps[i]) then
            lastDone = i
        end
    end
    if lastDone > 0 then
        return steps[lastDone + 1]
    end
    if GPS.Travel and GPS.Travel.NearestFlight then
        local flight = GPS.Travel:NearestFlight(here.mapId, here.x, here.y)
        if flight then
            return flight
        end
    end
    return steps[#steps]
end

function Guide:ActiveIndex()
    local target = self:ArrowTarget()
    local steps = self.steps or {}
    if target then
        for i = 1, #steps do
            local step = steps[i]
            if step.mapId == target.mapId and step.name == target.name then
                return i
            end
        end
    end
    return #steps > 0 and #steps or 1
end

function Guide:Refresh()
    if not self.dest then
        return
    end
    local target = self:ArrowTarget()
    if not target or not target.mapId or not target.x or not target.y then
        return
    end
    local key = target.mapId .. ":" .. target.x .. ":" .. target.y .. ":" .. (target.name or "")
    if key ~= self.arrowKey then
        self.arrowKey = key
        self:SetBlizzardPin(target)
        if self:SetTomTom(target) then
            if GPS.Arrow then
                GPS.Arrow:Hide()
            end
        elseif GPS.Arrow then
            GPS.Arrow:Show(target)
        end
    end
    if GPS.Route and GPS.Route.ShowSteps then
        GPS.Route:ShowSteps(self.steps, self:ActiveIndex())
    end
end

function Guide:StartWatch()
    if self.watch then
        return
    end
    if not C_Timer or type(C_Timer.NewTicker) ~= "function" then
        return
    end
    self.watch = C_Timer.NewTicker(0.5, function()
        Guide:Refresh()
    end)
end

function Guide:StopWatch()
    if self.watch then
        self.watch:Cancel()
        self.watch = nil
    end
end

function Guide:Start(dest, openRoute)
    if not dest or not dest.mapId or not dest.x or not dest.y or not dest.name then
        GPS:Print("That destination has no map coordinates.")
        return
    end
    self.dest = dest
    self.arrowKey = nil
    local here = GPS.Here and GPS.Here:Read()
    if GPS.Travel and GPS.Travel.Plan then
        self.steps = GPS.Travel:Plan(dest, here)
    else
        self.steps = { dest }
    end
    self:Refresh()
    self:StartWatch()
    local count = self.steps and #self.steps or 1
    if count > 1 then
        GPS:Print("Route set to " .. dest.name .. ". " .. count .. " steps.")
    else
        GPS:Print("Arrow set to " .. dest.name .. ".")
    end
    if openRoute and GPS.Main and GPS.Main.SelectTab then
        GPS.Main:Show()
        GPS.Main:SelectTab("route", false)
    end
end

function Guide:Clear()
    self.dest = nil
    self.steps = nil
    self.arrowKey = nil
    self:StopWatch()
    self:ClearTomTom()
    self:ClearBlizzardPin()
    if GPS.Arrow then
        GPS.Arrow:Hide()
    end
    if GPS.Route and GPS.Route.ShowSteps then
        GPS.Route:ShowSteps(nil)
    end
end
