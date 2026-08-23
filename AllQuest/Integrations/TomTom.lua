--[[
  AllQuest — TomTom crazy arrow from tracker / journal
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.TomTom = AQ.TomTom or {}

local function NormalizeXY(x, y)
    x = tonumber(x)
    y = tonumber(y)
    if not x or not y then
        return nil
    end
    if x > 1 or y > 1 then
        x = x / 100
        y = y / 100
    end
    if x < 0 or y < 0 or x > 1 or y > 1 then
        return nil
    end
    return x, y
end

local function TomTomReady()
    if not TomTom or type(TomTom.AddWaypoint) ~= "function" then
        return false
    end
    if AQ.Plugins and AQ.Plugins.IsEnabled and not AQ.Plugins.IsEnabled("TomTom") then
        return false
    end
    return true
end

function AQ.TomTom.AddPoint(mapID, x, y, title)
    if not TomTomReady() then
        return false
    end
    if type(mapID) ~= "number" then
        return false
    end
    x, y = NormalizeXY(x, y)
    if not x then
        return false
    end
    local ok, uid = pcall(TomTom.AddWaypoint, TomTom, mapID, x, y, {
        title = title or "AllQuest",
        from = "AllQuest",
        persistent = false,
        minimap = true,
        world = true,
        crazy = true,
    })
    if ok and uid then
        if AQ.Speech then
            AQ.Speech.Say("TomTom arrow set for " .. (title or "point"))
        end
        return true
    end
    return ok and true or false
end

function AQ.TomTom.WaypointForQuest(questID, title)
    if not questID then
        return false
    end
    local mapID, x, y
    if AQ.QuestSources and AQ.QuestSources.ResolveLocation then
        mapID, x, y = AQ.QuestSources.ResolveLocation(questID)
    else
        mapID, x, y = AQ.Compat.GetQuestLocation(questID)
    end
    if type(mapID) == "number" and x and y and AQ.TomTom.AddPoint(mapID, x, y, title) then
        return true
    end
    if not TomTom then
        if AQ.Speech then
            AQ.Speech.Say("TomTom is not loaded")
        end
        return false
    end
    if AQ.Speech then
        AQ.Speech.Say("No map point available for TomTom")
    end
    return false
end

AQ:RegisterPlugin({
    id = "TomTom",
    kind = "integration",
    optionalAddon = "TomTom",
    onEnable = function()
        AQ:Print("TomTom: left-click a tracker quest, pet, or rare for an arrow. Shift-right-click and /aqtomtom also work.")
    end,
})

SLASH_AQTOMTOM1 = "/aqtomtom"
SlashCmdList["AQTOMTOM"] = function()
    local id = AQ.Compat.GetSuperTrackedQuestID()
    if not id then
        AQ:Print("No super-tracked quest.")
        return
    end
    AQ.TomTom.WaypointForQuest(id, AQ.Compat.GetQuestTitle(id))
end
