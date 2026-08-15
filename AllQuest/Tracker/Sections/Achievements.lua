--[[
  AllQuest — tracked achievements section
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function TrackedAchievementIDs()
    local ids = {}
    local CT = C_ContentTracking
    local enumType = Enum and Enum.ContentTrackingType and Enum.ContentTrackingType.Achievement
    if CT and CT.GetTrackedIDs and enumType then
        local list = AQ:SafeCall(CT.GetTrackedIDs, enumType)
        if type(list) == "table" then
            for i = 1, #list do
                if type(list[i]) == "number" then
                    ids[#ids + 1] = list[i]
                end
            end
            return ids
        end
    end
    if GetTrackedAchievements then
        local packed = { pcall(GetTrackedAchievements) }
        if packed[1] then
            for i = 2, #packed do
                if type(packed[i]) == "number" then
                    ids[#ids + 1] = packed[i]
                end
            end
        end
    end
    return ids
end

local function GetRows()
    local rows = {}
    local ids = TrackedAchievementIDs()
    for i = 1, #ids do
        local id = ids[i]
        if type(id) == "number" then
            if AQ.Tracker and AQ.Tracker.IsSuppressed and AQ.Tracker.IsSuppressed("achievement", id) then
                -- skipped
            else
            local _, name, _, completed = AQ:SafeCall(GetAchievementInfo, id)
            if type(name) == "string" then
                local status = completed and "DONE" or "ACTIVE"
                rows[#rows + 1] = {
                    kind = "quest",
                    title = name,
                    status = status,
                    indent = 8,
                    achievementID = id,
                    speech = "Achievement " .. name .. " " .. status,
                    detail = "Achievement ID " .. tostring(id),
                }
                local n = AQ:SafeCall(GetAchievementNumCriteria, id) or 0
                for c = 1, n do
                    local cName, _, cCompleted, qty, req = AQ:SafeCall(GetAchievementCriteriaInfo, id, c)
                    if type(cName) == "string" then
                        local extra = ""
                        if qty and req then
                            extra = string.format(" %s/%s", tostring(qty), tostring(req))
                        end
                        rows[#rows + 1] = {
                            kind = "objective",
                            title = "  " .. cName .. extra,
                            finished = cCompleted and true or false,
                            numFulfilled = qty,
                            numNeeded = req,
                            achievementID = id,
                            speech = cName .. extra,
                        }
                    end
                end
            end
            end
        end
    end
    return rows
end

AQ.Tracker.RegisterSection({
    id = "achievements",
    title = "Achievements",
    order = 40,
        flavor = "all",
    GetRows = GetRows,
})

AQ.Events.Register("TRACKED_ACHIEVEMENT_UPDATE", function()
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end)
AQ.Events.Register("TRACKED_ACHIEVEMENT_LIST_CHANGED", function()
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end)
AQ.Events.Register("CONTENT_TRACKING_UPDATE", function(_, trackableType, id, added)
    if added and type(id) == "number" and AQ.Tracker.ClearSuppress then
        AQ.Tracker.ClearSuppress("achievement", id)
        AQ.Tracker.ClearSuppress("collectible", id)
    end
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end)
