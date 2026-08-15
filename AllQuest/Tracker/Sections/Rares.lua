--[[
  AllQuest — rares from RareScanner and SilverDragon
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

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

local function GetRows()
    local rows = RowsFromRareScanner()
    local seen = {}
    for i = 1, #rows do
        seen[rows[i].title] = true
    end
    local extra = RowsFromSilverDragon()
    for i = 1, #extra do
        if not seen[extra[i].title] then
            rows[#rows + 1] = extra[i]
            seen[extra[i].title] = true
        end
    end
    return rows
end

AQ.Tracker.RegisterSection({
    id = "rares",
    title = "Rares",
    order = 65,
    flavor = "all",
    requiresAnyPlugin = { "RareScanner", "SilverDragon" },
    GetRows = GetRows,
})
