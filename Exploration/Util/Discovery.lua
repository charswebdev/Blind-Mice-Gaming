local addon = Exploration

local PREFIX = "|cff00ccffExploration:|r "

local eventFrame
local lastSubzone
local subzonePoll

local function normalizeName(name)
    return addon:NormalizeWaypointName(name)
end

--- Build bidirectional rename map from pack maps[].subzoneAliases
--- (e.g. Dreadmaul Hold ↔ Okril'lon Hold) plus Generated ExplorationDiscoveryAliases
--- (packs are build-time only and are not loaded by the TOC).
local function discoveryAliasMap()
    if addon._discoveryAliases then
        return addon._discoveryAliases
    end
    local aliases = {}
    local function link(a, b)
        if not a or not b or a == "" or b == "" then return end
        aliases[a] = aliases[a] or {}
        aliases[b] = aliases[b] or {}
        aliases[a][b] = true
        aliases[b][a] = true
    end
    for _, route in pairs(ExplorationRoutes or {}) do
        for _, mapDef in pairs(route.maps or {}) do
            for canonical, list in pairs(mapDef.subzoneAliases or {}) do
                local c = normalizeName(canonical)
                for _, alias in ipairs(list) do
                    link(c, normalizeName(alias))
                end
            end
        end
    end
    -- Emitted into Data/Routes/Generated.lua from pack D(..., { aliases }).
    for a, targets in pairs(ExplorationDiscoveryAliases or {}) do
        local na = normalizeName(a)
        if type(targets) == "table" then
            for b in pairs(targets) do
                link(na, normalizeName(b))
            end
        end
    end
    addon._discoveryAliases = aliases
    return aliases
end

--- Exact / colon-title match only (no pack aliases).
local function discoveryNamesExact(discovered, waypoint)
    if not discovered or discovered == "" or not waypoint or waypoint == "" then
        return false
    end
    if discovered == waypoint then
        return true
    end
    -- Colon titles where only the left side was captured ("Acherus" ↔ "Acherus: The Ebon Hold").
    if waypoint:sub(1, #discovered + 1) == discovered .. ":" then
        return true
    end
    if discovered:sub(1, #waypoint + 1) == waypoint .. ":" then
        return true
    end
    return false
end

--- True when discovery text matches a pin, including shared-fog rename aliases
--- (e.g. Portal Clearing → Marshlight Lake). Prefer exact match when both exist.
local function discoveryNamesMatch(discovered, waypoint)
    if discoveryNamesExact(discovered, waypoint) then
        return true
    end
    local aliases = discoveryAliasMap()
    if aliases[discovered] and aliases[discovered][waypoint] then
        return true
    end
    return false
end

function addon:DiscoveryNamesMatch(discovered, waypoint)
    return discoveryNamesMatch(discovered, waypoint)
end

--- Exact name first, then alias. Prevents Discover↔Discover alias pairs (and
--- cross-expansion name collisions) from clearing the wrong pin in a cluster.
function addon:FindWaypointIndex(name, mapID)
    if not addon.segment.route or not name then return nil end
    local target = normalizeName(addon:LocalizedString(name))

    local function mapOk(wpMap)
        if not mapID or not wpMap or wpMap == mapID then
            return true
        end
        -- Boralus (1161) Discover must clear Tiragarde (895) district pins.
        return addon.MapsAreParentOrChild and addon:MapsAreParentOrChild(wpMap, mapID)
    end

    local function pinMatchName(waypoint)
        local data = waypoint and waypoint.data
        if not data then return false end
        local wpName = normalizeName(addon:LocalizedString(data.name))
        if discoveryNamesExact(target, wpName) then
            return true
        end
        -- Locale-safe: compare toast text to the client's localized area name.
        local areaID = tonumber(data.areaID or data.explorationID)
        if areaID and addon.LocalizedAreaName then
            local areaName = addon:LocalizedAreaName(areaID)
            if areaName and discoveryNamesExact(target, normalizeName(areaName)) then
                return true
            end
        end
        return false
    end

    local function scan(matcher)
        local fallback = nil
        for index, waypoint in ipairs(addon.segment.route) do
            if not waypoint.discovered and not (waypoint.data and waypoint.data.travel) then
                if matcher(waypoint) then
                    if mapOk(waypoint.data.map) then
                        return index
                    end
                    if not mapID and not fallback then
                        fallback = index
                    end
                end
            end
        end
        return mapID and nil or fallback
    end

    local exact = scan(pinMatchName)
    if exact then return exact end

    return scan(function(waypoint)
        local data = waypoint and waypoint.data
        if not data then return false end
        local wpName = normalizeName(addon:LocalizedString(data.name))
        if discoveryNamesExact(target, wpName) then
            return false
        end
        local aliases = discoveryAliasMap()
        return aliases[target] and aliases[target][wpName] or false
    end)
end

function addon:HasLearnedNameOnMap(name, mapID)
    if not name then return false end
    local account = addon.data and addon.data.account
    local learned = account and account.learnedWaypoints
    if not learned then return false end
    local target = addon:NormalizeWaypointName(name)
    for _, entry in pairs(learned) do
        if type(entry) == "table" and entry.name
            and addon:NormalizeWaypointName(entry.name) == target
        then
            if not mapID or entry.map == mapID then
                return true
            end
            if entry.map and addon.MapsAreParentOrChild
                and addon:MapsAreParentOrChild(entry.map, mapID)
            then
                return true
            end
        end
    end
    return false
end

function addon:MarkLearnedWaypoint(name, mapID, x, y)
    addon.data.account = addon.data.account or { learnedWaypoints = {} }
    local key = string.format("%s|%s|%s|%s", name or "", mapID or "", x or "", y or "")
    local entry = {
        name = name,
        map = mapID,
        x = x,
        y = y,
        learnedAt = time(),
    }
    addon.data.account.learnedWaypoints[key] = entry
    return entry
end

function addon:ResetSubzoneTracking()
    lastSubzone = nil
end

local function currentSubzoneName()
    local subzone = GetSubZoneText()
    if subzone and subzone ~= "" then
        return subzone
    end
    if GetMinimapZoneText then
        subzone = GetMinimapZoneText()
        if subzone and subzone ~= "" then
            return subzone
        end
    end
    return nil
end

local function formatCoords(x, y)
    if x and y then
        return string.format("%.1f, %.1f", x, y)
    end
    return "unknown coordinates"
end

function addon:AnnounceEnter(subzone)
    -- Entering <subzone> chat spam removed; discoveries use AnnounceNewLocation.
end

function addon:AnnounceDiscovered(subzone, x, y)
    -- Curated pin clears stay silent; only new locations are announced.
end

function addon:AnnounceNewLocation(subzone, saved, routeName)
    local coords = formatCoords(saved and saved.x, saved and saved.y)
    local mapID = saved and saved.map
    local zoneName = "unknown zone"
    if mapID and C_Map and C_Map.GetMapInfo then
        local info = C_Map.GetMapInfo(mapID)
        if info and info.name and info.name ~= "" then
            zoneName = info.name
        end
    end
    local routeLabel = nil
    if routeName and addon.data and addon.data.routes and addon.data.routes[routeName] then
        local route = addon.data.routes[routeName]
        routeLabel = addon:LocalizedString(route.display or routeName)
    end
    local chatMsg
    local speakMsg
    if routeLabel then
        chatMsg = string.format(
            "New Location added %s in %s (%s) at %s",
            subzone or "unknown",
            zoneName,
            routeLabel,
            coords
        )
        speakMsg = string.format(
            "New location added, %s, in %s, on the %s route, at %s.",
            subzone or "unknown",
            zoneName,
            routeLabel,
            coords
        )
    else
        chatMsg = string.format(
            "New Location added %s in %s at %s",
            subzone or "unknown",
            zoneName,
            coords
        )
        speakMsg = string.format(
            "New location added, %s, in %s, at %s.",
            subzone or "unknown",
            zoneName,
            coords
        )
    end
    -- System chat channel (same pipeline as Blizzard system lines).
    addon:SystemMessage(chatMsg)
    addon:SpeakText(speakMsg)
end

function addon:AnnounceSegment(sectionName)
    local route = addon.data.routes[sectionName]
    local label = addon:LocalizedString(route and route.display or sectionName)
    addon:SystemMessage(PREFIX .. "New chapter: " .. label)
    addon:SpeakText("New chapter, " .. label .. ".")
end

local function onSubzoneChanged()
    -- Zone-change side effects only; no "Entering …" announce.
    if not addon.active then return end
    local subzone = currentSubzoneName()
    if subzone then
        lastSubzone = subzone
    end
end

local function startSubzonePoll()
    -- Poll kept only so lastSubzone stays warm for discovery edge cases.
    if subzonePoll then return end
    subzonePoll = C_Timer.NewTicker(1.0, function()
        if addon.active then
            onSubzoneChanged()
        end
    end)
end

function addon:FindWaypointIndexForDiscovery(name, mapID, x, y)
    local index = addon:FindWaypointIndex(name, mapID)
    if index then return index end
    if not addon.segment.route then return nil end

    -- Name match only — never clear an exploration pin just because the player
    -- is standing near it when an unrelated Discover toast fires.
    local target = addon:NormalizeWaypointName(name)
    for i, wp in ipairs(addon.segment.route) do
        if not wp.discovered and wp.data and not wp.data.travel then
            local wpName = wp.data and wp.data.name
            if wpName and addon:NormalizeWaypointName(wpName) == target then
                local wpMap = wp.data.map
                if not mapID or not wpMap or wpMap == mapID
                    or (addon.MapsAreParentOrChild and addon:MapsAreParentOrChild(wpMap, mapID))
                then
                    return i
                end
            end
        end
    end

    return nil
end

function addon:RefreshProgressUI()
    if addon.ui and addon.ui.SegmentFrame and addon.ui.SegmentFrame.UpdateProgressBars then
        addon.ui.SegmentFrame:UpdateProgressBars()
    end
end

local function stripChatDecorations(msg)
    if not msg then return msg end
    return msg
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|T.-|t", "")
        :gsub("|A.-|a", "")
end

local function patternFromGlobal(globalStr)
    if not globalStr then return nil end
    -- Use greedy (.+) for %s so names with colons ("Acherus: The Ebon Hold")
    -- aren't truncated before the ": %d experience" suffix.
    return globalStr:gsub("1%$", ""):gsub("2%$", ""):gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
end

local function trimZone(zone)
    if not zone then return nil end
    -- Only strip a trailing XP suffix — never chop at the first colon
    -- (that broke "Acherus: The Ebon Hold" → "Acherus").
    zone = zone:gsub(":%s*%d+%s*[Ee]xperience.*$", "")
    zone = zone:gsub(":%s*%d+%s*XP.*$", "")
    if strtrim then zone = strtrim(zone) end
    if zone == "" then return nil end
    return zone
end

function addon:ParseDiscoveryZoneName(msg)
    if not msg or type(msg) ~= "string" or msg == "" then return nil end
    msg = stripChatDecorations(msg)

    local patterns = {
        patternFromGlobal(ERR_ZONE_EXPLORED_XP),
        patternFromGlobal(ERR_ZONE_EXPLORED),
    }
    -- English fallbacks only on enUS — other locales rely on ERR_ZONE_EXPLORED*.
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "enUS" or locale == "enGB" then
        patterns[#patterns + 1] = "[Dd]iscovered%s+(.+):%s*%d+"
        patterns[#patterns + 1] = "[Dd]iscovered%s*:?%s*(.+)$"
    end
    for _, pattern in ipairs(patterns) do
        if pattern then
            local _, _, zone = string.find(msg, pattern)
            zone = trimZone(zone)
            if zone then return zone end
        end
    end

    return nil
end

--- Clear the active pin only when discovery XP matches it by name / alias.
--- Standing on the pin (or parent-zone fog) is not enough — exploration stops
--- wait for a real "Discovered …" toast for that stop.
local function tryClearActiveDiscoveryPin(zone, mapID, px, py)
    if not addon.active or not addon.segment or not addon.segment.route then
        return false
    end
    local index = addon.waypoint.index
    local wp = index and addon.segment.route[index]
    if not wp or wp.discovered or not wp.data or wp.data.travel then
        return false
    end

    local target = addon:NormalizeWaypointName(zone)
    local wpName = wp.data.name and addon:NormalizeWaypointName(addon:LocalizedString(wp.data.name))
    if discoveryNamesExact(target, wpName) then
        addon:ClearDatabaseWaypoint(index, zone, mapID, px, py)
        return true
    end
    local areaID = tonumber(wp.data.areaID or wp.data.explorationID)
    if areaID and addon.LocalizedAreaName then
        local areaName = addon:LocalizedAreaName(areaID)
        if areaName and discoveryNamesExact(target, addon:NormalizeWaypointName(areaName)) then
            addon:ClearDatabaseWaypoint(index, zone, mapID, px, py)
            return true
        end
    end

    -- Alias (shared-fog secondary toast) may clear the active primary, but only
    -- when no other pin on this map owns the toast name exactly — otherwise a
    -- Discover sibling in the same fog cluster would be skipped.
    if discoveryNamesMatch(target, wpName) then
        for i, other in ipairs(addon.segment.route) do
            if i ~= index and not other.discovered and other.data and not other.data.travel then
                local otherName = other.data.name
                    and addon:NormalizeWaypointName(addon:LocalizedString(other.data.name))
                if discoveryNamesExact(target, otherName) then
                    local otherMap = other.data.map
                    if not mapID or not otherMap or otherMap == mapID
                        or (addon.MapsAreParentOrChild and addon:MapsAreParentOrChild(otherMap, mapID))
                    then
                        return false
                    end
                end
            end
        end
        addon:ClearDatabaseWaypoint(index, zone, mapID, px, py)
        return true
    end

    return false
end

function addon:ProcessDiscoveryZone(zone, mapID, px, py)
    if not zone or zone == "" then return end

    addon._recentDiscoveries = addon._recentDiscoveries or {}
    local key = addon:NormalizeWaypointName(zone)
    local now = GetTime()
    if addon._recentDiscoveries[key] and (now - addon._recentDiscoveries[key]) < 2 then
        return
    end

    if not addon.active then
        -- Always record Discover toasts while the addon is loaded, even with
        -- no journey running. Route insert may fail (no pack / filtered); the
        -- account learnedWaypoints store + announce still fire.
        addon._recentDiscoveries[key] = now
        local wasNew = not addon:HasLearnedNameOnMap(zone, mapID)
        local saved = addon:MarkLearnedWaypoint(zone, mapID, px, py)
        local _, storageRoute, isNewLocation = addon:InsertLearnedWaypoint(zone, mapID, px, py)
        if isNewLocation or wasNew then
            addon:AnnounceNewLocation(zone, saved, storageRoute)
        end
        return
    end

    -- Active pin wins on name / alias match only.
    if tryClearActiveDiscoveryPin(zone, mapID, px, py) then
        addon._recentDiscoveries[key] = now
        return
    end

    local routeName = addon.active.path[#addon.active.path]

    -- Name match in the live route always clears, even when GetBestMapForUnit
    -- is a micro-map and ResolveExplorationRouteName points elsewhere.
    if not addon:IsTravelSegment(routeName) then
        local byName = addon:FindWaypointIndex(zone, mapID)
        if byName then
            addon._recentDiscoveries[key] = now
            addon:ClearDatabaseWaypoint(byName, zone, mapID, px, py)
            return
        end
    end

    local lookupRoute = addon:ResolveExplorationRouteName(routeName, mapID)
    local index = addon:ResolveDatabaseWaypointIndex(zone, mapID, px, py, lookupRoute)
    if index then
        addon._recentDiscoveries[key] = now
        if routeName ~= lookupRoute or addon:IsTravelSegment(routeName) then
            -- Still clear the live pin when it is the same segment under another name key.
            if routeName == lookupRoute and addon.segment and addon.segment.route[index] then
                addon:ClearDatabaseWaypoint(index, zone, mapID, px, py)
            else
                addon:MarkStaticRouteDiscovered(lookupRoute, zone, mapID, px, py)
            end
            return
        end
        -- Mark the matching pin discovered even out of route order so a later
        -- revisit doesn't leave a stuck fog pin after the XP message already fired.
        addon:ClearDatabaseWaypoint(index, zone, mapID, px, py)
        return
    end

    addon._recentDiscoveries[key] = now

    -- Parent-zone names (e.g. "Harandar") are not subzone stops — don't spawn
    -- phantom pins that can get stuck requiring a second discovery message.
    local mapInfo = mapID and C_Map.GetMapInfo(mapID)
    if mapInfo and mapInfo.name
        and addon:NormalizeWaypointName(mapInfo.name) == addon:NormalizeWaypointName(zone)
    then
        return
    end

    local wasNew = not addon:HasLearnedNameOnMap(zone, mapID)
    local saved = addon:MarkLearnedWaypoint(zone, mapID, px, py)
    local insertAt, storageRoute, isNewLocation = addon:InsertLearnedWaypoint(zone, mapID, px, py)

    if isNewLocation or wasNew then
        addon:AnnounceNewLocation(zone, saved, storageRoute)
    end

    if insertAt and addon.ui and addon.ui.SegmentFrame then
        addon.ui.SegmentFrame._scrollToIndex = insertAt
        addon.ui.SegmentFrame:Refresh()
    elseif storageRoute and addon.active and addon.active.path
        and addon.active.path[#addon.active.path] == storageRoute
        and addon.SyncActiveSegmentLearnedInserts then
        addon:SyncActiveSegmentLearnedInserts()
    end
    addon:RefreshProgressUI()
    addon:SaveProgress()
end

function addon:HandleDiscoveryMessage(msg)
    local zone = addon:ParseDiscoveryZoneName(msg)
    if not zone then return end

    local mapID = C_Map.GetBestMapForUnit("player")
    local pos = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    local px, py
    if pos then
        px = math.floor(pos.x * 10000) / 100
        py = math.floor(pos.y * 10000) / 100
    end

    addon:ProcessDiscoveryZone(zone, mapID, px, py)
end

function addon:HandleChatMsgSystem(msg)
    addon:HandleDiscoveryMessage(msg)
end

function addon:RegisterDiscoveryEvents()
    if eventFrame then return end
    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
    eventFrame:RegisterEvent("UI_INFO_MESSAGE")
    eventFrame:RegisterEvent("ZONE_CHANGED")
    eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
    eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    eventFrame:SetScript("OnEvent", function(_, event, ...)
        if event == "CHAT_MSG_SYSTEM" then
            addon:HandleDiscoveryMessage(...)
        elseif event == "UI_INFO_MESSAGE" then
            local errorType, message = ...
            if type(errorType) == "string" and not message then
                message = errorType
            elseif type(message) ~= "string" and type(errorType) == "string" then
                message = errorType
            end
            if type(message) == "string" then
                -- Prefer Blizzard's typed discovery messages when available.
                if GetGameMessageInfo and type(errorType) == "number" then
                    local stringId = GetGameMessageInfo(errorType)
                    if stringId == "ERR_ZONE_EXPLORED"
                        or stringId == "ERR_ZONE_EXPLORED_XP"
                        or addon:ParseDiscoveryZoneName(message)
                    then
                        addon:HandleDiscoveryMessage(message)
                    end
                else
                    addon:HandleDiscoveryMessage(message)
                end
            end
        elseif addon.active then
            if event == "ZONE_CHANGED_NEW_AREA" then
                addon:ResetSubzoneTracking()
            end
            if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
                onSubzoneChanged()
                if addon.CheckZoneTrigger then addon:CheckZoneTrigger() end
            end
        end
    end)
    startSubzonePoll()
end
