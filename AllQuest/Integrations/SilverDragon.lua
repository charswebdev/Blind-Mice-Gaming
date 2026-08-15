--[[
  AllQuest — SilverDragon last-seen rares
  Uses SilverDragon callbacks at runtime. Does not copy its mob database.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.SilverDragon = AQ.SilverDragon or {}
local SD = AQ.SilverDragon
SD.recent = SD.recent or {}

local MAX = 8
local hooked

local function RefreshSoon()
    if AQ.Tracker and AQ.Tracker.Refresh then
        AQ.Tracker.Refresh()
    end
end

local function Core()
    return SilverDragon
end

local function Push(id, zone, x, y, dead, source, unit)
    if type(id) ~= "number" then
        return
    end
    local core = Core()
    local name
    if core and type(core.GetMobLabel) == "function" then
        name = AQ:SafeCall(core.GetMobLabel, core, id)
    end
    if (not name or name == "") and core and type(core.NameForMob) == "function" then
        name = AQ:SafeCall(core.NameForMob, core, id, unit)
    end
    if type(name) ~= "string" or name == "" then
        name = "Rare " .. tostring(id)
    end
    local list = {}
    list[1] = {
        id = id,
        title = name,
        mapID = zone,
        x = x,
        y = y,
        dead = dead and true or false,
        source = source,
        unit = unit,
    }
    for i = 1, #SD.recent do
        if SD.recent[i].id ~= id then
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
        Push(id, zone, x, y, dead, source, unit)
    end
    pcall(core.RegisterCallback, handler, "Announce")
    local hist = core.GetModule and AQ:SafeCall(core.GetModule, core, "History", true)
    if hist and type(hist.GetRares) == "function" then
        local ok, rares = pcall(hist.GetRares, hist)
        if ok and type(rares) == "table" then
            for i = #rares, 1, -1 do
                local r = rares[i]
                if type(r) == "table" then
                    Push(r.id, r.zone, r.x, r.y, r.dead, r.source, r.unit)
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
        AQ:Print("SilverDragon: seen rares appear in the AllQuest tracker.")
        RefreshSoon()
    end,
})
