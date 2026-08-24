--[[
  AllQuest — nearby rares and treasures in the tracker
  Native vignettes, nameplates, area POIs, plus RareScanner and SilverDragon.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local nearbyPlates = {}
local plateByUnit = {}
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
        C_Timer.After(0.2, run)
    else
        run()
    end
end

local function PlayerMap()
    if AQ.Compat and AQ.Compat.GetPlayerMapPosition then
        return AQ.Compat.GetPlayerMapPosition()
    end
    if C_Map and C_Map.GetBestMapForUnit then
        return AQ:SafeCall(C_Map.GetBestMapForUnit, "player")
    end
    return nil
end

local function LooksLikePet(name, atlas)
    local blob = string.lower(tostring(name or "") .. " " .. tostring(atlas or ""))
    if blob:find("treasure", 1, true) or blob:find("chest", 1, true) then
        return false
    end
    return blob:find("battle pet", 1, true)
        or blob:find("wildpet", 1, true)
        or (blob:find("pet", 1, true) and not blob:find("rare", 1, true))
end

local function KindFromAtlasName(name, atlas, vtype)
    if LooksLikePet(name, atlas) then
        return nil
    end
    local n = string.lower(tostring(name or ""))
    local a = string.lower(tostring(atlas or ""))
    if n == "" and a == "" and vtype == nil then
        return nil
    end
    local E = Enum and Enum.VignetteType
    if E and E.Treasure and vtype == E.Treasure then
        return "treasure"
    end
    if a:find("loot", 1, true)
        or a:find("treasure", 1, true)
        or a:find("chest", 1, true)
        or n:find("treasure", 1, true)
        or n:find("chest", 1, true)
        or n:find("cache", 1, true)
        or n:find("coffer", 1, true)
        or n:find("strongbox", 1, true)
    then
        return "treasure"
    end
    if E and E.Rare and vtype == E.Rare then
        return "rare"
    end
    if a:find("rare", 1, true)
        or a:find("elite", 1, true)
        or a:find("vignettekill", 1, true)
        or a:find("boss", 1, true)
    then
        return "rare"
    end
    if vtype ~= nil then
        if E and E.Normal and vtype == E.Normal and (a:find("vignette", 1, true) or a:find("kill", 1, true)) then
            return "rare"
        end
    end
    if a:find("vignette", 1, true) then
        return "rare"
    end
    return nil
end

local function DefaultAtlas(kind)
    if kind == "treasure" then
        return "VignetteLoot"
    end
    return "VignetteKill"
end

local function MakeRow(kind, title, mapID, x, y, dead, target, atlas, icon)
    local label = kind == "treasure" and "Treasure" or "Rare"
    local st = dead and "DONE" or "ACTIVE"
    if type(atlas) ~= "string" or atlas == "" then
        atlas = DefaultAtlas(kind)
    end
    return {
        kind = "quest",
        title = title,
        status = st,
        indent = 8,
        findKind = kind,
        rareTarget = (kind == "rare") and (target or title) or nil,
        rareMapID = mapID,
        rareX = x,
        rareY = y,
        atlas = atlas,
        icon = icon,
        speech = label .. " " .. title .. (dead and " done" or ""),
    }
end

local function AddRow(rows, seen, kind, title, mapID, x, y, dead, target, atlas, icon)
    if type(title) ~= "string" or title == "" or not kind then
        return
    end
    if seen[title] then
        return
    end
    seen[title] = true
    rows[#rows + 1] = MakeRow(kind, title, mapID, x, y, dead, target, atlas, icon)
end

local function RowsFromVignettes()
    local rows = {}
    local seen = {}
    if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then
        return rows, seen
    end
    local mapID = PlayerMap()
    local guids = AQ:SafeCall(C_VignetteInfo.GetVignettes)
    if type(guids) ~= "table" then
        return rows, seen
    end
    for i = 1, #guids do
        local guid = guids[i]
        local info = C_VignetteInfo.GetVignetteInfo and AQ:SafeCall(C_VignetteInfo.GetVignetteInfo, guid)
        if type(info) == "table" then
            local findKind = KindFromAtlasName(info.name, info.atlasName, info.type or info.vignetteType)
            if findKind then
                local x, y
                if type(mapID) == "number" and C_VignetteInfo.GetVignettePosition then
                    local pos = AQ:SafeCall(C_VignetteInfo.GetVignettePosition, guid, mapID)
                    if pos and pos.GetXY then
                        x, y = pos:GetXY()
                    end
                end
                AddRow(rows, seen, findKind, info.name, mapID, x, y, info.isDead, info.name, info.atlasName)
            end
        end
    end
    return rows, seen
end

local function RowsFromAreaPOIs(rows, seen)
    local mapID = PlayerMap()
    if type(mapID) ~= "number" or not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap) then
        return
    end
    local pois = AQ:SafeCall(C_AreaPoiInfo.GetAreaPOIForMap, mapID)
    if type(pois) ~= "table" then
        return
    end
    for i = 1, #pois do
        local info = C_AreaPoiInfo.GetAreaPOIInfo and AQ:SafeCall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, pois[i])
        if type(info) == "table" then
            local findKind = KindFromAtlasName(info.name, info.atlasName)
            if findKind then
                local x, y
                if info.position and info.position.GetXY then
                    x, y = info.position:GetXY()
                end
                AddRow(rows, seen, findKind, info.name, mapID, x, y, false, info.name, info.atlasName, info.iconFileID or info.texture)
            end
        end
    end
end

local function RowsFromNameplates(rows, seen)
    local now = GetTime and GetTime() or 0
    for name, info in pairs(nearbyPlates) do
        if type(info) == "table" and (now - (info.time or 0)) < 90 then
            AddRow(rows, seen, "rare", name, PlayerMap(), nil, nil, info.dead, name)
        else
            nearbyPlates[name] = nil
        end
    end
end

local function RowsFromRareScanner(rows, seen)
    if not (AQ.Plugins and AQ.Plugins.IsEnabled("RareScanner") and AQ:AddonLoaded("RareScanner")) then
        return
    end
    if AQ.RareScanner and AQ.RareScanner.EnsureHook then
        AQ.RareScanner.EnsureHook()
    end
    local recent = AQ.RareScanner and AQ.RareScanner.GetRecent and AQ.RareScanner.GetRecent()
    if type(recent) ~= "table" then
        return
    end
    for i = 1, #recent do
        local r = recent[i]
        if type(r) == "table" and type(r.title) == "string" then
            AddRow(rows, seen, r.kind or "rare", r.title, r.mapID, r.x, r.y, r.dead, r.unit or r.title, r.atlas, r.icon)
        end
    end
end

local function RowsFromSilverDragon(rows, seen)
    if not (AQ.Plugins and AQ.Plugins.IsEnabled("SilverDragon") and AQ:AddonLoaded("SilverDragon")) then
        return
    end
    local recent = AQ.SilverDragon and AQ.SilverDragon.GetRecent and AQ.SilverDragon.GetRecent()
    if type(recent) ~= "table" then
        return
    end
    for i = 1, #recent do
        local r = recent[i]
        if type(r) == "table" and type(r.title) == "string" then
            AddRow(rows, seen, r.kind or "rare", r.title, r.mapID, r.x, r.y, r.dead, r.unit or r.title, r.atlas, r.icon)
        end
    end
end

local function GroupRows(flat)
    local rares, treasures = {}, {}
    for i = 1, #flat do
        if flat[i].findKind == "treasure" then
            treasures[#treasures + 1] = flat[i]
        else
            rares[#rares + 1] = flat[i]
        end
    end
    if #rares == 0 or #treasures == 0 then
        return flat
    end
    local rows = {
        {
            kind = "header",
            id = "rares:creatures",
            title = "Rares",
            speech = "Rares",
            fontSize = 12,
            indent = 14,
            subheader = true,
        },
    }
    for i = 1, #rares do
        rows[#rows + 1] = rares[i]
    end
    rows[#rows + 1] = {
        kind = "header",
        id = "rares:treasures",
        title = "Treasures",
        speech = "Treasures",
        fontSize = 12,
        indent = 14,
        subheader = true,
    }
    for i = 1, #treasures do
        rows[#rows + 1] = treasures[i]
    end
    return rows
end

local function GetRows()
    local rows, seen = RowsFromVignettes()
    RowsFromAreaPOIs(rows, seen)
    RowsFromNameplates(rows, seen)
    RowsFromRareScanner(rows, seen)
    RowsFromSilverDragon(rows, seen)
    return GroupRows(rows)
end

AQ.Tracker.RegisterSection({
    id = "rares",
    title = "Rares",
    order = 65,
    flavor = "all",
    GetRows = GetRows,
})

local function NotePlate(unit, gone)
    if type(unit) ~= "string" or unit == "" then
        return
    end
    if gone then
        local name = plateByUnit[unit]
        plateByUnit[unit] = nil
        if name then
            nearbyPlates[name] = nil
            RefreshSoon()
        end
        return
    end
    if not UnitExists or not UnitExists(unit) then
        return
    end
    if UnitIsPlayer and UnitIsPlayer(unit) then
        return
    end
    local class = UnitClassification and UnitClassification(unit)
    if class ~= "rare" and class ~= "rareelite" and class ~= "worldboss" then
        return
    end
    local name = UnitName and UnitName(unit)
    if type(name) ~= "string" or name == "" then
        return
    end
    plateByUnit[unit] = name
    nearbyPlates[name] = {
        time = GetTime and GetTime() or 0,
        dead = (UnitIsDead and UnitIsDead(unit)) and true or false,
    }
    RefreshSoon()
end

AQ.Events.Register("VIGNETTES_UPDATED", RefreshSoon)
AQ.Events.Register("VIGNETTE_MINIMAP_UPDATED", RefreshSoon)
AQ.Events.Register("PLAYER_TARGET_CHANGED", RefreshSoon)
AQ.Events.Register("PLAYER_ENTERING_WORLD", RefreshSoon)
AQ.Events.Register("ZONE_CHANGED_NEW_AREA", RefreshSoon)
AQ.Events.Register("NAME_PLATE_UNIT_ADDED", function(_, unit)
    NotePlate(unit, false)
end)
AQ.Events.Register("NAME_PLATE_UNIT_REMOVED", function(_, unit)
    NotePlate(unit, true)
end)
