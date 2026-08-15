--[[
  AllQuest — tracked collectibles (appearances / mounts) via C_ContentTracking
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function TrackedIDs(enumVal)
    local CT = C_ContentTracking
    if not (CT and CT.GetTrackedIDs and enumVal) then
        return {}
    end
    local list = AQ:SafeCall(CT.GetTrackedIDs, enumVal)
    if type(list) ~= "table" then
        return {}
    end
    return list
end

local function GetRows()
    local rows = {}
    local E = Enum and Enum.ContentTrackingType
    if not E or not C_ContentTracking then
        return rows
    end
    local groups = {
        { E.Appearance, "Appearance" },
        { E.Mount, "Mount" },
    }
    for g = 1, #groups do
        local enumVal, label = groups[g][1], groups[g][2]
        if enumVal then
            local ids = TrackedIDs(enumVal)
            for i = 1, #ids do
                local id = ids[i]
                if type(id) == "number" then
                    if AQ.Tracker and AQ.Tracker.IsSuppressed and AQ.Tracker.IsSuppressed("collectible", id) then
                        -- skipped
                    else
                    rows[#rows + 1] = {
                        kind = "quest",
                        title = label .. " " .. tostring(id),
                        status = "ACTIVE",
                        collectibleID = id,
                        collectibleType = enumVal,
                        indent = 8,
                        speech = label .. " " .. tostring(id),
                    }
                    end
                end
            end
        end
    end
    return rows
end

AQ.Tracker.RegisterSection({
    id = "collectibles",
    title = "Collectibles",
    order = 60,
    flavor = "retail",
    GetRows = GetRows,
})
