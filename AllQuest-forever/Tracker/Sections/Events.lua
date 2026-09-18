--[[
  AllQuest — scheduled world events (Retail Event Scheduler)
  Same sources as Kaliel's Tracker: C_EventScheduler + area POIs.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local LONG_LIMIT = 86400
local FALLBACK_MAP = {
    [8174] = 2215,
    [8263] = 2346,
}

local ticker
local refreshPending

local function RefreshSoon()
    if refreshPending then
        return
    end
    refreshPending = true
    local function run()
        refreshPending = false
        if AQ.Tracker and AQ.Tracker.Refresh then
            AQ.Tracker.Refresh()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, run)
    else
        run()
    end
end

local function SetTicker(need)
    if need then
        if not ticker and C_Timer and C_Timer.NewTicker then
            ticker = C_Timer.NewTicker(15, RefreshSoon)
        end
    elseif ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local function SchedulerReady()
    return C_EventScheduler
        and type(C_EventScheduler.GetScheduledEvents) == "function"
        and (not C_EventScheduler.CanShowEvents or C_EventScheduler.CanShowEvents())
end

local function EnsureData()
    if not C_EventScheduler then
        return
    end
    if C_EventScheduler.HasData and not C_EventScheduler.HasData() then
        if C_EventScheduler.RequestEvents then
            AQ:SafeCall(C_EventScheduler.RequestEvents)
        end
    end
end

local function EventMapID(areaPoiID)
    if C_EventScheduler and C_EventScheduler.GetEventUiMapID then
        local mapID = AQ:SafeCall(C_EventScheduler.GetEventUiMapID, areaPoiID)
        if type(mapID) == "number" then
            return mapID
        end
    end
    return FALLBACK_MAP[areaPoiID]
end

local function EventPOI(areaPoiID)
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo) then
        return nil
    end
    local mapID = EventMapID(areaPoiID)
    local info = AQ:SafeCall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, areaPoiID)
    if type(info) ~= "table" then
        info = AQ:SafeCall(C_AreaPoiInfo.GetAreaPOIInfo, nil, areaPoiID)
    end
    if type(info) ~= "table" then
        return nil
    end
    if info.tooltipWidgetSet == 1016 then
        info.description = nil
    end
    return info
end

local function ShowTimeLeft(poiInfo)
    return not (type(poiInfo) == "table" and poiInfo.tooltipWidgetSet == 1355)
end

local function TimeLeftLabel(seconds)
    if type(seconds) ~= "number" or seconds <= 0 then
        return nil
    end
    local clock
    if SecondsToTime then
        clock = SecondsToTime(seconds)
    else
        local h = math.floor(seconds / 3600)
        local m = math.floor((seconds % 3600) / 60)
        if h > 0 then
            clock = string.format("%dh %dm", h, m)
        else
            clock = string.format("%dm", m)
        end
    end
    if BONUS_OBJECTIVE_TIME_LEFT then
        return BONUS_OBJECTIVE_TIME_LEFT:format(clock)
    end
    return "Time Left: " .. clock
end

local function POICoords(poiInfo)
    if type(poiInfo) ~= "table" or not poiInfo.position or not poiInfo.position.GetXY then
        return nil, nil
    end
    return poiInfo.position:GetXY()
end

local function POIArt(poiInfo)
    if type(poiInfo) ~= "table" then
        return "VignetteEvent", nil
    end
    local atlas = poiInfo.atlasName or poiInfo.atlas
    local icon = poiInfo.iconFileID or poiInfo.fileDataID or poiInfo.texture
    if type(atlas) ~= "string" or atlas == "" then
        atlas = "VignetteEvent"
    end
    return atlas, icon
end

local function AddEventRows(rows, poiInfo, eventInfo)
    if type(poiInfo) ~= "table" or type(poiInfo.name) ~= "string" or poiInfo.name == "" then
        return
    end
    local poiID = poiInfo.areaPoiID or (eventInfo and eventInfo.areaPoiID)
    local mapID = EventMapID(poiID)
    local zone
    if C_EventScheduler and C_EventScheduler.GetEventZoneName and type(poiID) == "number" then
        zone = AQ:SafeCall(C_EventScheduler.GetEventZoneName, poiID)
    end
    local x, y = POICoords(poiInfo)
    local atlas, icon = POIArt(poiInfo)
    local desc = poiInfo.description
    rows[#rows + 1] = {
        kind = "quest",
        title = poiInfo.name,
        status = "ACTIVE",
        indent = 8,
        areaPoiID = poiID,
        eventMapID = mapID,
        eventX = x,
        eventY = y,
        atlas = atlas,
        icon = icon,
        speech = "Event " .. poiInfo.name .. (type(zone) == "string" and (" " .. zone) or ""),
        detail = type(desc) == "string" and desc or nil,
    }
    if type(zone) == "string" and zone ~= "" then
        rows[#rows + 1] = {
            kind = "objective",
            title = zone,
            finished = false,
            goldBullet = true,
            areaPoiID = poiID,
            eventMapID = mapID,
            eventX = x,
            eventY = y,
            speech = zone,
        }
    end
    if eventInfo and ShowTimeLeft(poiInfo) and type(eventInfo.endTime) == "number" then
        local label = TimeLeftLabel(eventInfo.endTime - time())
        if label then
            rows[#rows + 1] = {
                kind = "objective",
                title = label,
                finished = false,
                areaPoiID = poiID,
                eventMapID = mapID,
                eventX = x,
                eventY = y,
                speech = label,
            }
        end
    end
end

local function GetRows()
    local rows = {}
    EnsureData()
    if not SchedulerReady() then
        SetTicker(false)
        return rows
    end

    local showLong = true
    if AQ.DB and AQ.DB.Get then
        local db = AQ.DB.Get()
        if db and db.trackerShowLongEvents == false then
            showLong = false
        end
    end

    local now = time()
    local hasCountdown = false
    local long = {}

    local scheduled = AQ:SafeCall(C_EventScheduler.GetScheduledEvents)
    if type(scheduled) == "table" then
        local list = {}
        for i = 1, #scheduled do
            list[i] = scheduled[i]
        end
        table.sort(list, function(a, b)
            return (a and a.startTime or 0) < (b and b.startTime or 0)
        end)
        for i = 1, #list do
            local eventInfo = list[i]
            if type(eventInfo) == "table" and not eventInfo.rewardsClaimed and type(eventInfo.areaPoiID) == "number" then
                if type(eventInfo.startTime) == "number" and eventInfo.startTime <= now
                    and type(eventInfo.endTime) == "number" and eventInfo.endTime > now
                then
                    local poiInfo = EventPOI(eventInfo.areaPoiID)
                    if poiInfo then
                        local duration = eventInfo.endTime - eventInfo.startTime
                        if duration < LONG_LIMIT then
                            AddEventRows(rows, poiInfo, eventInfo)
                            hasCountdown = true
                        elseif showLong then
                            long[#long + 1] = { poiInfo, eventInfo }
                        end
                    end
                end
            end
        end
        for i = 1, #long do
            AddEventRows(rows, long[i][1], long[i][2])
            hasCountdown = true
        end
    end

    if showLong and C_EventScheduler.GetOngoingEvents then
        local ongoing = AQ:SafeCall(C_EventScheduler.GetOngoingEvents)
        if type(ongoing) == "table" then
            for i = 1, #ongoing do
                local eventInfo = ongoing[i]
                if type(eventInfo) == "table" and not eventInfo.rewardsClaimed and type(eventInfo.areaPoiID) == "number" then
                    local poiInfo = EventPOI(eventInfo.areaPoiID)
                    if poiInfo then
                        AddEventRows(rows, poiInfo, eventInfo)
                    end
                end
            end
        end
    end

    SetTicker(hasCountdown)
    return rows
end

AQ.Tracker.RegisterSection({
    id = "events",
    title = (EVENTS_LABEL or "Events"),
    order = 50,
    flavor = "retail",
    GetRows = GetRows,
})

AQ.Events.Register("EVENT_SCHEDULER_UPDATE", RefreshSoon)
AQ.Events.Register("PLAYER_ENTERING_WORLD", function()
    EnsureData()
    RefreshSoon()
end)
