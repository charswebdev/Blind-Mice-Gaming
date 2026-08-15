local addon = Exploration

local houseInfos = nil
local pendingRefresh = false
local housingFrame = nil

local function pickHouseInfo(list)
    if type(list) ~= "table" or #list == 0 then
        return nil
    end
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    -- Prefer a house whose neighborhood matches the player's faction map when known.
    -- Alliance Founder's Point = 2352, Horde Razorwind Shores = 2351.
    local wantMap = (faction == "Horde") and 2351 or 2352
    local fallback = list[1]
    for _, info in ipairs(list) do
        if info and info.neighborhoodGUID and info.houseGUID and info.plotID then
            if C_Housing and C_Housing.GetUIMapIDForNeighborhood then
                local mapID = C_Housing.GetUIMapIDForNeighborhood(info.neighborhoodGUID)
                if mapID == wantMap then
                    return info
                end
            end
            if not fallback then
                fallback = info
            end
        end
    end
    if fallback and fallback.neighborhoodGUID and fallback.houseGUID and fallback.plotID then
        return fallback
    end
    return nil
end

local function refreshActiveActions()
    if not addon.UpdateWaypointNote then return end
    addon:UpdateWaypointNote()
end

function addon:RequestOwnedHouses()
    if not C_Housing or not C_Housing.GetPlayerOwnedHouses then
        return
    end
    if not housingFrame then
        housingFrame = CreateFrame("Frame")
        housingFrame:RegisterEvent("PLAYER_HOUSE_LIST_UPDATED")
        housingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        housingFrame:SetScript("OnEvent", function(_, event, payload)
            if event == "PLAYER_HOUSE_LIST_UPDATED" then
                houseInfos = payload
                if pendingRefresh then
                    pendingRefresh = false
                    refreshActiveActions()
                end
            elseif event == "PLAYER_REGEN_ENABLED" and pendingRefresh then
                pendingRefresh = false
                refreshActiveActions()
            end
        end)
    end
    C_Housing.GetPlayerOwnedHouses()
end

function addon:GetOwnedHouseForTeleport()
    return pickHouseInfo(houseInfos)
end

--- Configure a SecureActionButton for Blizzard's protected "teleporthome" action.
--- Returns true when the button is ready to click.
function addon:ConfigureHousingTeleportButton(btn)
    if not btn then return false end

    if InCombatLockdown and InCombatLockdown() then
        pendingRefresh = true
        addon:RequestOwnedHouses()
        return false
    end

    local info = addon:GetOwnedHouseForTeleport()
    if not info then
        pendingRefresh = true
        addon:RequestOwnedHouses()
        btn:SetAttribute("type", nil)
        btn:SetAttribute("house-neighborhood-guid", nil)
        btn:SetAttribute("house-guid", nil)
        btn:SetAttribute("house-plot-id", nil)
        return false
    end

    btn:SetAttribute("useOnKeyDown", false)
    btn:RegisterForClicks("AnyDown", "AnyUp")
    btn:SetAttribute("type", "teleporthome")
    btn:SetAttribute("house-neighborhood-guid", info.neighborhoodGUID)
    btn:SetAttribute("house-guid", info.houseGUID)
    btn:SetAttribute("house-plot-id", info.plotID)
    return true
end

function addon:ClearHousingTeleportButton(btn)
    if not btn or (InCombatLockdown and InCombatLockdown()) then return end
    btn:SetAttribute("type", nil)
    btn:SetAttribute("house-neighborhood-guid", nil)
    btn:SetAttribute("house-guid", nil)
    btn:SetAttribute("house-plot-id", nil)
end
