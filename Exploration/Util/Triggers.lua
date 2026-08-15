local addon = Exploration

local activeTrigger = nil -- "proximity" | "zone" | "buff" | nil
local triggerFrame = nil
-- Keep clear radius tight so pins don't complete across half a subzone.
local PROXIMITY_DEFAULT_RADIUS = 20
local PROXIMITY_INTERVAL = 0.2
-- After clearing a pin, block the next pin until the player leaves this radius
-- so nearby pins don't cascade-complete in one flyover.
local PROXIMITY_REARM_YARDS = 25

local elapsed = 0
local rearmContinent = nil
local rearmWorldX, rearmWorldY = nil, nil
local rearmRadiusSq = nil

---------------------------------------------------------------------------
-- Shared advancement helper
---------------------------------------------------------------------------

local function refreshAfterStep()
    if addon.ui and addon.ui.SegmentFrame then addon.ui.SegmentFrame:Refresh() end
    addon:RefreshProgressUI()
    addon:RefreshWorldMapOverlay()
    addon:RefreshMinimapOverlay()
    addon:SaveProgress()
end

local function ArmProximityRearm(playerContinent, playerWorld)
    if not playerContinent or not playerWorld then
        rearmContinent, rearmWorldX, rearmWorldY, rearmRadiusSq = nil, nil, nil, nil
        return
    end
    rearmContinent = playerContinent
    rearmWorldX = playerWorld.x
    rearmWorldY = playerWorld.y
    rearmRadiusSq = PROXIMITY_REARM_YARDS * PROXIMITY_REARM_YARDS
end

local function ProximityRearmed(playerContinent, playerWorld)
    if not rearmContinent or not rearmWorldX or not rearmRadiusSq then
        return true
    end
    if not playerContinent or not playerWorld or playerContinent ~= rearmContinent then
        rearmContinent, rearmWorldX, rearmWorldY, rearmRadiusSq = nil, nil, nil, nil
        return true
    end
    local dx = playerWorld.x - rearmWorldX
    local dy = playerWorld.y - rearmWorldY
    if (dx * dx + dy * dy) >= rearmRadiusSq then
        rearmContinent, rearmWorldX, rearmWorldY, rearmRadiusSq = nil, nil, nil, nil
        return true
    end
    return false
end

function addon:ArmProximityRearmFromPlayer()
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerPos = playerMapID and C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerMapID or not playerPos then
        ArmProximityRearm(nil, nil)
        return
    end
    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(playerMapID, playerPos)
    ArmProximityRearm(playerContinent, playerWorld)
end

local function TriggerDiscovery(playerContinent, playerWorld)
    local wpIndex = addon.waypoint.index
    if not wpIndex or not addon.segment.route or not addon.segment.route[wpIndex] then return end
    addon.segment.route[wpIndex].discovered = true
    if playerContinent and playerWorld then
        ArmProximityRearm(playerContinent, playerWorld)
    else
        addon:ArmProximityRearmFromPlayer()
    end
    addon:DetermineNextWaypoint()
    addon:UpdateWaypointArrow()
    refreshAfterStep()
end

--- Exploration fog pins wait for a real discovery message; only travel /
--- navigation steps (travel segments or travel=true breadcrumbs) auto-complete
--- by walking into the pin.
function addon:WaypointCompletesOnProximity(data)
    if not data then return false end
    if data.travel then return true end
    local routeName = addon.active and addon.active.path and addon.active.path[#addon.active.path]
    if not routeName or not addon.IsTravelSegment then return false end
    return addon:IsTravelSegment(routeName)
end

local function MarkProximityReached(index, playerContinent, playerWorld)
    if not index or not addon.segment.route or not addon.segment.route[index] then return end
    if addon.segment.route[index].discovered then return end
    -- Strict sequential: only the active pin may complete via proximity.
    if index ~= addon.waypoint.index then return end
    local data = addon.segment.route[index].data
    if not addon:WaypointCompletesOnProximity(data) then return end
    TriggerDiscovery(playerContinent, playerWorld)
end

---------------------------------------------------------------------------
-- Proximity trigger
---------------------------------------------------------------------------

local function proximityRadius(trigger)
    return (trigger and trigger.radius) or PROXIMITY_DEFAULT_RADIUS
end

local function distSqToWaypoint(playerContinent, playerWorld, data)
    if not data then return nil end
    local mapID = addon:GetWaypointMapID(data)
    local x, y = addon:GetWaypointNavCoords(data)
    if not mapID or not x or not y then return nil end
    local wpX = x / 100
    local wpY = y / 100
    local continent, worldPos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(wpX, wpY))
    if not continent or not worldPos or continent ~= playerContinent then return nil end
    local dx = playerWorld.x - worldPos.x
    local dy = playerWorld.y - worldPos.y
    return dx * dx + dy * dy
end

--- True when the player is within radiusYards of the waypoint pin (world space).
function addon:IsPlayerNearWaypoint(data, radiusYards)
    if not data then return false end
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerPos = playerMapID and C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerMapID or not playerPos then return false end
    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(playerMapID, playerPos)
    if not playerContinent or not playerWorld then return false end
    local distSq = distSqToWaypoint(playerContinent, playerWorld, data)
    if not distSq then return false end
    local radius = tonumber(radiusYards) or PROXIMITY_DEFAULT_RADIUS
    return distSq <= radius * radius
end

--- Same-map map-% proximity. Used when world projection fails (thorns, zone
--- seams, micro-maps) so named-subzone clears still work on top of the pin.
--- Orphan maps (Coldridge Valley 427) project the player onto the authored
--- zone map so % distance still works.
function addon:IsPlayerNearWaypointMapPct(data, radiusPct)
    if not data or not data.x or not data.y then return false end
    local wpMap = addon:GetWaypointMapID(data)
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerPos = playerMapID and C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not wpMap or not playerMapID or not playerPos then return false end

    local px, py
    if playerMapID == wpMap then
        px, py = playerPos.x * 100, playerPos.y * 100
    else
        local pCont, pWorld = C_Map.GetWorldPosFromMapPos(playerMapID, playerPos)
        if not pCont or not pWorld or not C_Map.GetMapPosFromWorldPos then
            return false
        end
        local _, mapPos = C_Map.GetMapPosFromWorldPos(pCont, pWorld, wpMap)
        if not mapPos or not mapPos.x or not mapPos.y then
            return false
        end
        px, py = mapPos.x * 100, mapPos.y * 100
    end

    local dx, dy = px - data.x, py - data.y
    local r = tonumber(radiusPct) or 5
    return (dx * dx + dy * dy) <= (r * r)
end

function addon:GetDefaultProximityRadius()
    return PROXIMITY_DEFAULT_RADIUS
end

local function CheckProximity()
    if not addon.segment or not addon.segment.route then return end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then return end

    local playerPos = C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerPos then return end

    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(playerMapID, playerPos)
    if not playerContinent or not playerWorld then return end

    if not ProximityRearmed(playerContinent, playerWorld) then
        return
    end

    local currentIndex = addon.waypoint.index
    if not currentIndex then return end
    local wp = addon.segment.route[currentIndex]
    if not wp or wp.discovered then return end

    local data = wp.data
    local trigger = data and data.trigger
    if not data or not trigger or trigger.type ~= "proximity" then return end
    if not addon:WaypointCompletesOnProximity(data) then return end

    local distSq = distSqToWaypoint(playerContinent, playerWorld, data)
    local radius = proximityRadius(trigger)
    local near = distSq ~= nil and distSq <= radius * radius
    -- Orgrimmar / capital interiors often fail world projection mid-story;
    -- map% fallback clears travel pins when standing on the NPC.
    if not near then
        local mapRadius = tonumber(trigger.mapRadius) or (data.travel and 3) or 5
        if addon:IsPlayerNearWaypointMapPct(data, mapRadius) then
            near = true
        end
    end
    if near then
        MarkProximityReached(currentIndex, playerContinent, playerWorld)
    end
end

local function OnProximityUpdate(self, dt)
    elapsed = elapsed + dt
    if elapsed < PROXIMITY_INTERVAL then return end
    elapsed = 0
    CheckProximity()
end

local function ActivateProximity()
    elapsed = 0
    -- Keep rearm across exploration pins so a flythrough doesn't cascade-clear
    -- a string of fog stops. Travel hops often sit on the same dock you just
    -- finished (e.g. Leave Silver Landing) — clear rearm so they can complete.
    local wp = addon.segment and addon.waypoint.index and addon.segment.route[addon.waypoint.index]
    if wp and wp.data and wp.data.travel then
        ArmProximityRearm(nil, nil)
    end

    if not triggerFrame then
        triggerFrame = CreateFrame("Frame")
    end
    triggerFrame:SetScript("OnUpdate", OnProximityUpdate)
    triggerFrame:Show()

    activeTrigger = "proximity"
    return true
end

---------------------------------------------------------------------------
-- Zone trigger
---------------------------------------------------------------------------

local function ActivateZone()
    activeTrigger = "zone"
    return true
end

function addon:CheckZoneTrigger()
    if activeTrigger ~= "zone" then return false end
    if not addon.waypoint.index or not addon.segment.route then return false end

    local wp = addon.segment.route[addon.waypoint.index]
    if not wp then return false end

    local trigger = wp.data.trigger
    local targetMapID = tonumber(trigger and trigger.map or wp.data.map)
    if not targetMapID then return false end

    local playerMapID = C_Map.GetBestMapForUnit("player")
    if not playerMapID then return false end

    -- Direct match
    if playerMapID == targetMapID then
        TriggerDiscovery()
        return true
    end

    -- Walk up parent hierarchy for sub-zone matching
    local info = C_Map.GetMapInfo(playerMapID)
    while info and info.parentMapID do
        if info.parentMapID == targetMapID then
            TriggerDiscovery()
            return true
        end
        info = C_Map.GetMapInfo(info.parentMapID)
    end

    return false
end

---------------------------------------------------------------------------
-- Buff trigger
---------------------------------------------------------------------------

local buffPollElapsed = 0
local BUFF_POLL_INTERVAL = 0.25

local function buffConditionMet(trigger)
    if not trigger or not trigger.spellId then return false end
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(trigger.spellId)
    if not aura and trigger.spell and AuraUtil and AuraUtil.FindAuraByName then
        aura = AuraUtil.FindAuraByName(trigger.spell, "player")
    end
    local hasAura = aura ~= nil
    local wantGained = trigger.gained ~= false -- default true
    return hasAura == wantGained
end

local function CheckBuffState()
    if activeTrigger ~= "buff" then return end
    if not addon.waypoint.index or not addon.segment.route then return end

    local wp = addon.segment.route[addon.waypoint.index]
    if not wp or not wp.data or not wp.data.trigger then return end

    if buffConditionMet(wp.data.trigger) then
        TriggerDiscovery()
    end
end

local function OnBuffEvent(self, event, unit)
    if event ~= "UNIT_AURA" or unit ~= "player" then return end
    if activeTrigger ~= "buff" then return end
    CheckBuffState()
end

local function OnBuffPoll(self, dt)
    buffPollElapsed = buffPollElapsed + dt
    if buffPollElapsed < BUFF_POLL_INTERVAL then return end
    buffPollElapsed = 0
    CheckBuffState()
end

local function ActivateBuff(trigger)
    if not trigger.spellId then return false end

    if not triggerFrame then
        triggerFrame = CreateFrame("Frame")
    end
    triggerFrame:SetScript("OnUpdate", OnBuffPoll)
    triggerFrame:SetScript("OnEvent", OnBuffEvent)
    triggerFrame:RegisterEvent("UNIT_AURA")
    triggerFrame:Show()

    activeTrigger = "buff"
    buffPollElapsed = 0
    -- Lorewalking can apply while the prior "Head to …" pin is still active;
    -- check immediately so we don't wait for another UNIT_AURA edge.
    CheckBuffState()
    return true
end

---------------------------------------------------------------------------
-- Cast trigger
---------------------------------------------------------------------------

local function OnCastEvent(self, event, unit, _, spellId)
    if event ~= "UNIT_SPELLCAST_SUCCEEDED" or unit ~= "player" then return end
    if activeTrigger ~= "cast" then return end
    if not addon.waypoint.index or not addon.segment.route then return end

    local wp = addon.segment.route[addon.waypoint.index]
    if not wp or not wp.data.trigger then return end

    if spellId == wp.data.trigger.spellId then
        TriggerDiscovery()
    end
end

local function ActivateCast(trigger)
    if not trigger.spellId then return false end

    if not triggerFrame then
        triggerFrame = CreateFrame("Frame")
    end
    triggerFrame:SetScript("OnUpdate", nil)
    triggerFrame:SetScript("OnEvent", OnCastEvent)
    triggerFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    triggerFrame:Show()

    activeTrigger = "cast"
    return true
end

---------------------------------------------------------------------------
-- Vehicle trigger
---------------------------------------------------------------------------

local vehicleSawInVehicle = false
local vehicleStepElapsed = 0

local function playerInVehicle()
    if UnitInVehicle and UnitInVehicle("player") then return true end
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return true end
    if UnitOnTaxi and UnitOnTaxi("player") then return true end
    return false
end

local function hasLorewalkingBuff()
    if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        if C_UnitAuras.GetPlayerAuraBySpellID(463943) then return true end
    end
    if AuraUtil and AuraUtil.FindAuraByName then
        return AuraUtil.FindAuraByName("Lorewalking", "player") ~= nil
    end
    return false
end

local function vehicleConditionMet(trigger)
    if not trigger then return false end
    local wantEntered = trigger.entered ~= false
    local inVehicle = playerInVehicle()
    if wantEntered then
        return inVehicle
    end
    -- Leave the bench: prefer sit-then-exit. Fallback for lorewalking seats that
    -- never fire vehicle APIs — once seated/activated, leaving completes when
    -- not in a vehicle while still lorewalking (or after a short wait).
    if vehicleSawInVehicle then
        return not inVehicle
    end
    if vehicleStepElapsed >= 1.5 and not inVehicle and hasLorewalkingBuff() then
        return true
    end
    return false
end

local function CheckVehicleState()
    if activeTrigger ~= "vehicle" then return end
    if not addon.waypoint.index or not addon.segment.route then return end

    local wp = addon.segment.route[addon.waypoint.index]
    if not wp or not wp.data or not wp.data.trigger then return end

    if playerInVehicle() then
        vehicleSawInVehicle = true
    end

    if vehicleConditionMet(wp.data.trigger) then
        TriggerDiscovery()
    end
end

local function OnVehicleEvent(self, event, unit)
    if unit ~= "player" then return end
    if activeTrigger ~= "vehicle" then return end
    if event == "UNIT_ENTERED_VEHICLE" then
        vehicleSawInVehicle = true
    end
    CheckVehicleState()
end

local vehiclePollElapsed = 0
local VEHICLE_POLL_INTERVAL = 0.25

local function OnVehiclePoll(self, dt)
    vehiclePollElapsed = vehiclePollElapsed + dt
    vehicleStepElapsed = vehicleStepElapsed + dt
    if vehiclePollElapsed < VEHICLE_POLL_INTERVAL then return end
    vehiclePollElapsed = 0
    CheckVehicleState()
end

local function ActivateVehicle(trigger)
    if not triggerFrame then
        triggerFrame = CreateFrame("Frame")
    end
    triggerFrame:SetScript("OnUpdate", OnVehiclePoll)
    triggerFrame:SetScript("OnEvent", OnVehicleEvent)
    triggerFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    triggerFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    triggerFrame:Show()

    activeTrigger = "vehicle"
    vehiclePollElapsed = 0
    vehicleStepElapsed = 0
    vehicleSawInVehicle = playerInVehicle()
    CheckVehicleState()
    return true
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function addon:DeactivateTrigger()
    if triggerFrame then
        triggerFrame:SetScript("OnUpdate", nil)
        triggerFrame:SetScript("OnEvent", nil)
        triggerFrame:UnregisterAllEvents()
        triggerFrame:Hide()
    end
    activeTrigger = nil
    vehicleSawInVehicle = false
    vehicleStepElapsed = 0
    buffPollElapsed = 0
    vehiclePollElapsed = 0
end

function addon:ActivateTrigger()
    addon:DeactivateTrigger()

    if not addon.waypoint.index or not addon.segment.route then return end

    local wp = addon.segment.route[addon.waypoint.index]
    if not wp or not wp.data.trigger then return end

    local trigger = wp.data.trigger
    local triggerType = trigger.type

    if triggerType == "proximity" then
        -- Exploration subzone pins use discovery chat/UI messages, not proximity.
        if addon:WaypointCompletesOnProximity(wp.data) then
            ActivateProximity()
        end
    elseif triggerType == "zone" then
        ActivateZone()
        addon:CheckZoneTrigger()
    elseif triggerType == "buff" then
        ActivateBuff(trigger)
    elseif triggerType == "cast" then
        ActivateCast(trigger)
    elseif triggerType == "vehicle" then
        ActivateVehicle(trigger)
    end
end

