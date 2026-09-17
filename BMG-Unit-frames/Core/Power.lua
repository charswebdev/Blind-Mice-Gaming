--[[
  BMG Unit Frames — primary and secondary power (mana, holy power, combo, …)
  Lua 5.1 only. Works on Classic Era through retail: missing APIs are skipped.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Power = UF.Power or {}
local Power = UF.Power

local FALLBACK = {
    MANA = 0,
    RAGE = 1,
    FOCUS = 2,
    ENERGY = 3,
    COMBO_POINTS = 4,
    RUNES = 5,
    RUNIC_POWER = 6,
    SOUL_SHARDS = 7,
    LUNAR_POWER = 8,
    HOLY_POWER = 9,
    ALTERNATE = 10,
    MAELSTROM = 11,
    CHI = 12,
    INSANITY = 13,
    BURNING_EMBERS = 14,
    DEMONIC_FURY = 15,
    ARCANE_CHARGES = 16,
    FURY = 17,
    PAIN = 18,
    ESSENCE = 19,
}

local NAMES = {
    MANA = "Mana",
    RAGE = "Rage",
    FOCUS = "Focus",
    ENERGY = "Energy",
    COMBO_POINTS = "Combo",
    RUNES = "Runes",
    RUNIC_POWER = "Runic",
    SOUL_SHARDS = "Shards",
    LUNAR_POWER = "Astral",
    HOLY_POWER = "Holy Power",
    ALTERNATE = "Alt",
    MAELSTROM = "Maelstrom",
    CHI = "Chi",
    INSANITY = "Insanity",
    BURNING_EMBERS = "Embers",
    DEMONIC_FURY = "Demonic Fury",
    ARCANE_CHARGES = "Arcane",
    FURY = "Fury",
    PAIN = "Pain",
    ESSENCE = "Essence",
}

local COLORS = {
    MANA = { 0.25, 0.50, 1.00 },
    RAGE = { 0.90, 0.18, 0.18 },
    FOCUS = { 0.90, 0.49, 0.13 },
    ENERGY = { 1.00, 0.96, 0.41 },
    COMBO_POINTS = { 1.00, 0.80, 0.00 },
    RUNES = { 0.77, 0.12, 0.23 },
    RUNIC_POWER = { 0.00, 0.82, 1.00 },
    SOUL_SHARDS = { 0.58, 0.51, 0.79 },
    LUNAR_POWER = { 0.30, 0.52, 0.90 },
    HOLY_POWER = { 0.95, 0.90, 0.60 },
    ALTERNATE = { 0.70, 0.70, 0.30 },
    MAELSTROM = { 0.00, 0.50, 1.00 },
    CHI = { 0.00, 1.00, 0.59 },
    INSANITY = { 0.40, 0.00, 0.80 },
    BURNING_EMBERS = { 0.90, 0.37, 0.05 },
    DEMONIC_FURY = { 0.70, 0.30, 0.90 },
    ARCANE_CHARGES = { 0.41, 0.80, 0.94 },
    FURY = { 0.64, 0.19, 0.79 },
    PAIN = { 0.80, 0.55, 0.00 },
    ESSENCE = { 0.20, 0.58, 0.50 },
}

local CLASS_ALT = {
    ROGUE = { "COMBO_POINTS" },
    DRUID = { "COMBO_POINTS", "LUNAR_POWER" },
    PALADIN = { "HOLY_POWER" },
    WARLOCK = { "SOUL_SHARDS", "BURNING_EMBERS", "DEMONIC_FURY" },
    DEATHKNIGHT = { "RUNES" },
    PRIEST = { "INSANITY" },
    MONK = { "CHI" },
    MAGE = { "ARCANE_CHARGES" },
    SHAMAN = { "MAELSTROM" },
    EVOKER = { "ESSENCE" },
}

local TOKEN_BY_ID = {}

local function IdOf(token)
    if Enum and Enum.PowerType and type(Enum.PowerType[token]) == "number" then
        return Enum.PowerType[token]
    end
    local spell = _G["SPELL_POWER_" .. token]
    if type(spell) == "number" then
        return spell
    end
    return FALLBACK[token]
end

local function TokenOf(id)
    if type(id) ~= "number" then
        return nil
    end
    if TOKEN_BY_ID[id] then
        return TOKEN_BY_ID[id]
    end
    if Enum and Enum.PowerType then
        for name, value in pairs(Enum.PowerType) do
            if value == id and type(name) == "string" and NAMES[name] then
                TOKEN_BY_ID[id] = name
                return name
            end
        end
    end
    for name, value in pairs(FALLBACK) do
        if value == id then
            TOKEN_BY_ID[id] = name
            return name
        end
    end
    return nil
end

function Power.Name(tokenOrId)
    if type(tokenOrId) == "number" then
        tokenOrId = TokenOf(tokenOrId)
    end
    return (tokenOrId and NAMES[tokenOrId]) or "Power"
end

function Power.Color(tokenOrId)
    local token = tokenOrId
    if type(tokenOrId) == "number" then
        token = TokenOf(tokenOrId)
    end
    local c = token and COLORS[token]
    if c then
        return c[1], c[2], c[3]
    end
    return UF.Theme.power[1], UF.Theme.power[2], UF.Theme.power[3]
end

local function SafePower(unit, ptype)
    if not UnitPower or type(ptype) ~= "number" then
        return nil, nil
    end
    local okc, cur = pcall(UnitPower, unit, ptype)
    local okm, max = pcall(UnitPowerMax, unit, ptype)
    if not okc or type(cur) ~= "number" then
        cur = 0
    end
    if not okm or type(max) ~= "number" then
        max = 0
    end
    return cur, max
end

local function Combo(unit)
    local id = IdOf("COMBO_POINTS")
    local cur, max = 0, 0
    if id then
        cur, max = SafePower(unit, id)
        cur = cur or 0
        max = max or 0
    end
    local mine = unit == "player" or unit == "target" or unit == "focus" or unit == "targettarget"
    if mine and GetComboPoints then
        local dest = (unit == "focus" and "focus") or "target"
        local ok, n = pcall(GetComboPoints, "player", dest)
        if ok and type(n) == "number" and n > cur then
            cur = n
        end
    end
    if max < 1 then
        if mine or cur > 0 then
            max = MAX_COMBO_POINTS or 5
        else
            return nil
        end
    end
    return id or 4, cur, max, "Combo"
end

local function HasMax(unit, token)
    local id = IdOf(token)
    if not id then
        return false, 0, 0, nil
    end
    local cur, max = SafePower(unit, id)
    if max and max > 0 then
        return true, cur, max, id
    end
    return false, 0, 0, id
end

function Power.Primary(unit)
    local ptype = UnitPowerType and UnitPowerType(unit)
    local token = TokenOf(ptype)
    if not token and UnitPowerType then
        local _, ptoken = UnitPowerType(unit)
        if type(ptoken) == "string" then
            token = ptoken
        end
    end
    local cur = UnitPower and UnitPower(unit) or 0
    local max = UnitPowerMax and UnitPowerMax(unit) or 0
    if type(cur) ~= "number" then
        cur = 0
    end
    if type(max) ~= "number" then
        max = 0
    end
    local r, g, b
    if token then
        r, g, b = Power.Color(token)
    else
        r, g, b = Power.Color(ptype)
    end
    if PowerBarColor and ptype ~= nil and PowerBarColor[ptype] and PowerBarColor[ptype].r then
        local c = PowerBarColor[ptype]
        r, g, b = c.r, c.g, c.b
    end
    return {
        id = ptype,
        token = token,
        cur = cur,
        max = max,
        name = Power.Name(token or ptype),
        r = r,
        g = g,
        b = b,
        discrete = max > 0 and max <= 10,
    }
end

function Power.Secondary(unit)
    if not unit or (UnitExists and not UnitExists(unit)) then
        return nil
    end
    local _, class = UnitClass(unit)
    local primary = UnitPowerType and UnitPowerType(unit)
    local primaryToken = TokenOf(primary)

    if class and CLASS_ALT[class] then
        for i = 1, #CLASS_ALT[class] do
            local token = CLASS_ALT[class][i]
            if token == "COMBO_POINTS" then
                local id, cur, max, name = Combo(unit)
                if (not max or max < 1) and class == "ROGUE" then
                    max = MAX_COMBO_POINTS or 5
                    id = id or 4
                    name = name or "Combo"
                end
                if id and max and max > 0 and token ~= primaryToken then
                    local r, g, b = Power.Color("COMBO_POINTS")
                    return {
                        id = id,
                        token = "COMBO_POINTS",
                        cur = cur or 0,
                        max = max,
                        name = name,
                        r = r,
                        g = g,
                        b = b,
                        discrete = true,
                    }
                end
            else
                local ok, cur, max, id = HasMax(unit, token)
                if ok and id ~= primary then
                    local r, g, b = Power.Color(token)
                    return {
                        id = id,
                        token = token,
                        cur = cur,
                        max = max,
                        name = Power.Name(token),
                        r = r,
                        g = g,
                        b = b,
                        discrete = max <= 10,
                    }
                end
            end
        end
    end

    local altId = IdOf("ALTERNATE")
    if altId then
        local cur, max = SafePower(unit, altId)
        if max and max > 0 and altId ~= primary then
            local r, g, b = Power.Color("ALTERNATE")
            return {
                id = altId,
                token = "ALTERNATE",
                cur = cur,
                max = max,
                name = "Alt",
                r = r,
                g = g,
                b = b,
                discrete = max <= 10,
            }
        end
    end
    return nil
end

function Power.Format(cur, max, mode, unknown)
    mode = mode or "both"
    if mode == "none" then
        return ""
    end
    cur = tonumber(cur) or 0
    max = tonumber(max) or 0
    local pct = 0
    if max > 0 then
        pct = cur / max
        if pct < 0 then
            pct = 0
        end
        if pct > 1 then
            pct = 1
        end
    end
    local function Short(n)
        n = math.floor((n or 0) + 0.5)
        if n >= 10000000 then
            return string.format("%.1fM", n / 1000000)
        end
        if n >= 10000 then
            return string.format("%.1fK", n / 1000)
        end
        return tostring(n)
    end
    if unknown then
        return string.format("%d%% ?", math.floor(pct * 100 + 0.5))
    end
    if mode == "current" then
        return Short(cur)
    end
    if mode == "percent" then
        return string.format("%d%%", math.floor(pct * 100 + 0.5))
    end
    if max <= 10 and max > 0 then
        return string.format("%s / %s", Short(cur), Short(max))
    end
    return string.format("%s  %d%%", Short(cur), math.floor(pct * 100 + 0.5))
end
