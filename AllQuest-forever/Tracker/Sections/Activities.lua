--[[
  AllQuest — tracked Traveler's Log / perks activities (Retail)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function GetRows()
    local rows = {}
    if not C_PerksActivities then
        return rows
    end
    local tracked = AQ:SafeCall(C_PerksActivities.GetTrackedPerksActivities)
    local ids = {}
    if type(tracked) == "table" then
        if tracked[1] then
            ids = tracked
        else
            local pending = tracked.trackedIDs or tracked.pendingIDs or tracked.activities
            if type(pending) == "table" then
                ids = pending
            end
        end
    end
    for i = 1, #ids do
        local id = ids[i]
        if type(id) == "table" then
            id = id.activityID or id.ID or id.id
        end
        if type(id) == "number" then
            if AQ.Tracker and AQ.Tracker.IsSuppressed and AQ.Tracker.IsSuppressed("activity", id) then
                -- skipped
            else
            local name = "Activity " .. tostring(id)
            local info = C_PerksActivities.GetPerksActivityInfo and AQ:SafeCall(C_PerksActivities.GetPerksActivityInfo, id)
            if type(info) == "table" and type(info.activityName) == "string" then
                name = info.activityName
            elseif type(info) == "table" and type(info.name) == "string" then
                name = info.name
            end
            rows[#rows + 1] = {
                kind = "quest",
                title = name,
                status = "ACTIVE",
                activityID = id,
                indent = 8,
                speech = "Activity " .. name,
            }
            end
        end
    end
    return rows
end

AQ.Tracker.RegisterSection({
    id = "activities",
    title = "Activities",
    order = 55,
    flavor = "retail",
    GetRows = GetRows,
})
