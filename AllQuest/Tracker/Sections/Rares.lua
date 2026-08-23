--[[
  AllQuest — nearby rares in the tracker
  Native map vignettes, plus RareScanner and SilverDragon.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local function PlayerMap()
    if AQ.Compat and AQ.Compat.GetPlayerMapPosition then
        return AQ.Compat.GetPlayerMapPosition()
    end
    if C_Map and C_Map.GetBestMapForUnit then
        return AQ:SafeCall(C_Map.GetBestMapForUnit, "player")
    end
    return nil
end

local function LooksLikeRare(info)
    if type(info) ~= "table" then
        return false
    end
    local name = string.lower(tostring(info.name or ""))
    local atlas = string.lower(tostring(info.atlasName or ""))
    if name == "" then
        return false
    end
    if atlas:find("pet", 1, true) or name:find("battle pet", 1, true) then
        return false
    end
    if atlas:find("treasure", 1, true) or name:find("treasure", 1, true) then
        return false
    end
    if atlas:find("rare", 1, true) or atlas:find("elite", 1, true) or atlas:find("vignettekill", 1, true) then
        return true
    end
    if info.isDead then
        return true
    end
    local vtype = info.type or info.vignetteType
    local E = Enum and Enum.VignetteType
    if E then
        if E.Normal and vtype == E.Normal and (atlas:find("vignette", 1, true) or atlas:find("kill", 1, true)) then
            return true
        end
        if E.Rare and vtype == E.Rare then
            return true
        end
    end
    if atlas:find("vignette", 1, true) then
        return true
    end
    return false
end

local function RowsFromVignettes()
    local rows = {}
    if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then
        return rows
    end
    local mapID = PlayerMap()
    local guids = AQ:SafeCall(C_VignetteInfo.GetVignettes)
    if type(guids) ~= "table" then
        return rows
    end
    local seen = {}
    for i = 1, #guids do
        local guid = guids[i]
        local info = C_VignetteInfo.GetVignetteInfo and AQ:SafeCall(C_VignetteInfo.GetVignetteInfo, guid)
        if LooksLikeRare(info) and not seen[info.name] then
            seen[info.name] = true
            local x, y
            if type(mapID) == "number" and C_VignetteInfo.GetVignettePosition then
                local pos = AQ:SafeCall(C_VignetteInfo.GetVignettePosition, guid, mapID)
                if pos and pos.GetXY then
                    x, y = pos:GetXY()
                end
            end
            rows[#rows + 1] = {
                kind = "quest",
                title = info.name,
                status = info.isDead and "DONE" or "ACTIVE",
                indent = 8,
                rareTarget = info.name,
                rareMapID = mapID,
                rareX = x,
                rareY = y,
                speech = "Rare " .. info.name .. (info.isDead and " dead" or ""),
            }
        end
    end
    return rows
end

local function RowsFromRareScanner()
    local rows = {}
    if not (AQ.Plugins and AQ.Plugins.IsEnabled("RareScanner") and AQ:AddonLoaded("RareScanner")) then
        return rows
    end
    if AQ.RareScanner and AQ.RareScanner.EnsureHook then
        AQ.RareScanner.EnsureHook()
    end
    local btn = _G.RARESCANNER_BUTTON
    if not btn or not btn.IsShown or not btn:IsShown() then
        return rows
    end
    local name = btn.name
    if type(name) ~= "string" or name == "" then
        return rows
    end
    rows[#rows + 1] = {
        kind = "quest",
        title = name,
        status = "ACTIVE",
        indent = 8,
        rareTarget = name,
        rareMapID = btn.mapID,
        rareX = btn.x,
        rareY = btn.y,
        speech = "Rare " .. name,
    }
    return rows
end

local function RowsFromSilverDragon()
    local rows = {}
    if not (AQ.Plugins and AQ.Plugins.IsEnabled("SilverDragon") and AQ:AddonLoaded("SilverDragon")) then
        return rows
    end
    local recent = AQ.SilverDragon and AQ.SilverDragon.GetRecent and AQ.SilverDragon.GetRecent()
    if type(recent) ~= "table" then
        return rows
    end
    for i = 1, #recent do
        local r = recent[i]
        if type(r) == "table" and type(r.title) == "string" then
            local st = r.dead and "DONE" or "ACTIVE"
            rows[#rows + 1] = {
                kind = "quest",
                title = r.title,
                status = st,
                indent = 8,
                rareTarget = r.unit or r.title,
                rareMapID = r.mapID,
                rareX = r.x,
                rareY = r.y,
                speech = "Rare " .. r.title .. " " .. st,
            }
        end
    end
    return rows
end

local function MergeRows(base, extra)
    local seen = {}
    for i = 1, #base do
        seen[base[i].title] = true
    end
    for i = 1, #extra do
        if not seen[extra[i].title] then
            base[#base + 1] = extra[i]
            seen[extra[i].title] = true
        end
    end
    return base
end

local function GetRows()
    local rows = RowsFromVignettes()
    rows = MergeRows(rows, RowsFromRareScanner())
    rows = MergeRows(rows, RowsFromSilverDragon())
    return rows
end

AQ.Tracker.RegisterSection({
    id = "rares",
    title = "Rares",
    order = 65,
    flavor = "all",
    GetRows = GetRows,
})

local function RefreshRares()
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end

AQ.Events.Register("VIGNETTES_UPDATED", RefreshRares)
AQ.Events.Register("VIGNETTE_MINIMAP_UPDATED", RefreshRares)
AQ.Events.Register("PLAYER_TARGET_CHANGED", RefreshRares)
