-- Mark Discovered UX: stuck-at-pin hints + safer manual clears.
-- Fog pins stay toast-strict; Mark only writes this character's progress.

local addon = Exploration

local STUCK_HINT_DELAY = 10 -- seconds near a fog pin with no Discover toast
local STUCK_NEAR_YARDS = 35
local MARK_CONFIRM_YARDS = 80 -- confirm Mark when farther than this
local POLL_INTERVAL = 0.5

local watchFrame = nil
local elapsed = 0
local nearSince = nil
local hintedForKey = nil
local pendingMarkIndex = nil

local function pinKey(index, data)
    if not index or not data or not data.name then return nil end
    return string.format("%s|%s|%s", index, tostring(data.map or 0), addon:NormalizeWaypointName(data.name))
end

local function currentFogPin()
    if not addon.active or not addon.waypoint.index or not addon.segment or not addon.segment.route then
        return nil, nil
    end
    local index = addon.waypoint.index
    local wp = addon.segment.route[index]
    if not wp or wp.discovered or not wp.data then
        return nil, nil
    end
    -- Travel / navigation hops clear on proximity — no Mark tip needed.
    if addon.WaypointCompletesOnProximity and addon:WaypointCompletesOnProximity(wp.data) then
        return nil, nil
    end
    return index, wp.data
end

local function yardsToPin(data)
    if not data or not addon.IsPlayerNearWaypoint then return nil end
    local playerMapID = C_Map.GetBestMapForUnit("player")
    local playerPos = playerMapID and C_Map.GetPlayerMapPosition(playerMapID, "player")
    if not playerMapID or not playerPos then return nil end
    local playerContinent, playerWorld = C_Map.GetWorldPosFromMapPos(playerMapID, playerPos)
    if not playerContinent or not playerWorld then return nil end

    local mapID = addon:GetWaypointMapID(data)
    local x, y = addon:GetWaypointNavCoords(data)
    if not mapID or not x or not y then return nil end
    local continent, worldPos = C_Map.GetWorldPosFromMapPos(mapID, CreateVector2D(x / 100, y / 100))
    if not continent or not worldPos or continent ~= playerContinent then return nil end
    local dx = playerWorld.x - worldPos.x
    local dy = playerWorld.y - worldPos.y
    return math.sqrt(dx * dx + dy * dy)
end

local function bindingHint()
    local key = GetBindingKey and GetBindingKey("CLICK ExplorationMarkDiscoveredButton:LeftButton")
    if key and key ~= "" then
        return "keybind " .. key
    end
    return "Mark Discovered keybind or Mark button"
end

local function showStuckHint(data)
    local name = addon:LocalizedString(data.name)
    if addon.UpdateNote and addon.data and addon.data.note and addon.data.note.visible ~= false then
        addon.note_active = true
        addon:UpdateNote(string.format(
            "No Discover toast.\nMark |cffffd200%s|r if this pin will not grant XP.\n(%s)",
            name,
            bindingHint()
        ))
    end
end

local function resetStuckState()
    nearSince = nil
    -- Keep hintedForKey so we don't re-spam the same pin after flying out and back.
end

local function doMarkCurrent(source)
    local index = addon.waypoint.index
    if not index or not addon.segment or not addon.segment.route or not addon.segment.route[index] then
        return false
    end
    local data = addon.segment.route[index].data

    addon.segment.route[index].discovered = true
    if addon.ArmProximityRearmFromPlayer then
        addon:ArmProximityRearmFromPlayer()
    end
    -- Persist under this character before advancing (DetermineNextWaypoint also saves).
    if addon.SaveProgress then
        addon:SaveProgress()
    end
    addon:DetermineNextWaypoint()
    if addon.ui and addon.ui.SegmentFrame and addon.ui.SegmentFrame.Refresh then
        addon.ui.SegmentFrame:Refresh()
    end
    if addon.RefreshProgressUI then
        addon:RefreshProgressUI()
    end

    if addon.UpdateWaypointNote then
        addon:UpdateWaypointNote()
    end
    return true
end

local function pollStuckHint(dt)
    elapsed = elapsed + dt
    if elapsed < POLL_INTERVAL then return end
    elapsed = 0

    local index, data = currentFogPin()
    if not index or not data then
        resetStuckState()
        return
    end

    local key = pinKey(index, data)
    local near = addon:IsPlayerNearWaypoint(data, STUCK_NEAR_YARDS)
        or (addon.IsPlayerNearWaypointMapPct and addon:IsPlayerNearWaypointMapPct(data, 4))
    if not near then
        nearSince = nil
        return
    end

    local now = GetTime()
    if not nearSince then
        nearSince = now
        return
    end
    if (now - nearSince) < STUCK_HINT_DELAY then
        return
    end
    if hintedForKey == key then
        return
    end
    hintedForKey = key
    showStuckHint(data)
end

function addon:SyncMarkUXWatcher()
    if not watchFrame then
        watchFrame = CreateFrame("Frame")
        watchFrame:SetScript("OnUpdate", function(_, dt)
            pollStuckHint(dt)
        end)
    end
    if addon.active and addon.waypoint.index then
        watchFrame:Show()
        elapsed = 0
        -- New active pin: allow a fresh near-timer; suppress repeat for same key.
        local index, data = currentFogPin()
        local key = index and data and pinKey(index, data)
        if key ~= hintedForKey then
            nearSince = nil
        end
    else
        watchFrame:Hide()
        nearSince = nil
        hintedForKey = nil
    end
end

function addon:ClearMarkUXState()
    nearSince = nil
    hintedForKey = nil
    pendingMarkIndex = nil
    if watchFrame then
        watchFrame:Hide()
    end
end

--- Mark the active pin discovered for this character.
--- Fog pins always ask for confirmation (no chat spam). Travel / nav steps
--- never need Discover confirmation — Next advances them immediately.
function addon:MarkCurrentDiscovered(source)
    if not addon.active then
        return false
    end
    local index, data = nil, nil
    if addon.waypoint.index and addon.segment and addon.segment.route then
        index = addon.waypoint.index
        local wp = addon.segment.route[index]
        data = wp and wp.data
    end
    if not index or not data then
        return false
    end

    local isTravel = data.travel
        or (addon.WaypointCompletesOnProximity and addon:WaypointCompletesOnProximity(data))
    if isTravel then
        return doMarkCurrent(source or "next")
    end

    pendingMarkIndex = index
    local name = addon:LocalizedString(data.name)
    local yards = yardsToPin(data)
    local distNote = ""
    if yards ~= nil and yards > MARK_CONFIRM_YARDS then
        distNote = string.format(
            "\n\nYou are about |cffffd200%d|r yards away.",
            math.floor(yards + 0.5)
        )
    end
    StaticPopup_Show("EXPLORATION_MARK_DISCOVERED", name, distNote)
    return false
end

StaticPopupDialogs["EXPLORATION_MARK_DISCOVERED"] = {
    text = "Mark |cffffd200%s|r discovered for this character only?\n\nConfirm only if this pin will not grant Discover XP.%s",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if not addon.active or not addon.waypoint.index then return end
        if pendingMarkIndex and pendingMarkIndex ~= addon.waypoint.index then
            pendingMarkIndex = nil
            return
        end
        pendingMarkIndex = nil
        doMarkCurrent("confirmed")
    end,
    OnCancel = function()
        pendingMarkIndex = nil
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

--- True when the Next footer button should read "Mark" (fog pin waiting on toast).
function addon:ActivePinNeedsMark()
    local _, data = currentFogPin()
    return data ~= nil
end
