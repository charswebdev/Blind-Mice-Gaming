--[[
  AllQuest — SilverDragon last-seen rares and treasures
  Uses SilverDragon callbacks at runtime. Does not copy its mob database.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.SilverDragon = AQ.SilverDragon or {}
local SD = AQ.SilverDragon
SD.recent = SD.recent or {}

local MAX = 12
local hooked

local function RefreshSoon()
    if AQ.Tracker and AQ.Tracker.Refresh then
        AQ.Tracker.Refresh()
    end
end

local function Core()
    return SilverDragon
end

local function Push(id, zone, x, y, dead, source, unit, kind, title)
    kind = kind or "rare"
    local name = title
    if type(name) ~= "string" or name == "" then
        local core = Core()
        if core and type(core.GetMobLabel) == "function" then
            name = AQ:SafeCall(core.GetMobLabel, core, id)
        end
        if (not name or name == "") and core and type(core.NameForMob) == "function" then
            name = AQ:SafeCall(core.NameForMob, core, id, unit)
        end
    end
    if type(name) ~= "string" or name == "" then
        name = (kind == "treasure" and "Treasure " or "Rare ") .. tostring(id or "")
    end
    local key = tostring(id or name) .. ":" .. kind
    local list = {}
    list[1] = {
        id = id,
        key = key,
        title = name,
        mapID = zone,
        x = x,
        y = y,
        dead = dead and true or false,
        source = source,
        unit = unit,
        kind = kind,
        atlas = kind == "treasure" and "VignetteLoot" or "VignetteKill",
    }
    for i = 1, #SD.recent do
        if SD.recent[i].key ~= key then
            list[#list + 1] = SD.recent[i]
        end
        if #list >= MAX then
            break
        end
    end
    SD.recent = list
    RefreshSoon()
end

local function Hook()
    local core = Core()
    if hooked or type(core) ~= "table" or type(core.RegisterCallback) ~= "function" then
        return
    end
    hooked = true
    local handler = {}
    function handler:Announce(_, id, zone, x, y, dead, source, unit)
        Push(id, zone, x, y, dead, source, unit, "rare")
    end
    function handler:AnnounceLoot(_, name, id, zone, x, y)
        Push(id, zone, x, y, false, "loot", nil, "treasure", name)
    end
    function handler:SeenLoot(_, name, vignetteID, uiMapID, x, y)
        Push(vignetteID, uiMapID, x, y, false, "vignette", nil, "treasure", name)
    end
    pcall(core.RegisterCallback, handler, "Announce")
    pcall(core.RegisterCallback, handler, "AnnounceLoot")
    pcall(core.RegisterCallback, handler, "SeenLoot")
    local hist = core.GetModule and AQ:SafeCall(core.GetModule, core, "History", true)
    if hist and type(hist.GetRares) == "function" then
        local ok, rares = pcall(hist.GetRares, hist)
        if ok and type(rares) == "table" then
            for i = #rares, 1, -1 do
                local r = rares[i]
                if type(r) == "table" then
                    Push(r.id, r.zone, r.x, r.y, r.dead, r.source, r.unit, r.type == "loot" and "treasure" or "rare", r.name or r.title)
                end
            end
        end
    end
end

function SD.GetRecent()
    return SD.recent
end

AQ:RegisterPlugin({
    id = "SilverDragon",
    kind = "integration",
    label = "SilverDragon",
    optionalAddon = "SilverDragon",
    onEnable = function()
        Hook()
        AQ:Print("SilverDragon: seen rares and treasures appear in the AllQuest tracker.")
        RefreshSoon()
    end,
})
