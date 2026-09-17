--[[
  BMG Unit Frames — high-contrast theme and class colors
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Theme = UF.Theme or {}
local Theme = UF.Theme

Theme.bg = { 0.02, 0.02, 0.02, 1 }
Theme.border = { 1, 1, 1, 1 }
Theme.text = { 1, 1, 1, 1 }
Theme.accent = { 1, 0.92, 0.4, 1 }
Theme.hint = { 0.78, 0.78, 0.78, 1 }
Theme.row = { 0.07, 0.07, 0.07, 1 }
Theme.btn = { 0.08, 0.08, 0.08, 1 }
Theme.btnHover = { 0.22, 0.22, 0.1, 1 }
Theme.health = { 0.12, 0.72, 0.18, 1 }
Theme.healthLow = { 1, 0.28, 0.22, 1 }
Theme.power = { 0.25, 0.55, 1, 1 }

-- TBC+ / retail-like. Era RAID_CLASS_COLORS keeps Shaman pink.
Theme.MODERN_CLASS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    MONK = { r = 0.00, g = 1.00, b = 0.59 },
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
}

function Theme.FontPath()
    return "Fonts\\FRIZQT__.TTF"
end

function Theme.ClassColor(unit)
    local _, class = UnitClass(unit)
    if not class then
        return 1, 1, 1
    end
    local profile = UF.DB and UF.DB.Get and UF.DB.Get()
    local mode = profile and profile.classColors or "classic"
    if mode == "modern" then
        local c = Theme.MODERN_CLASS[class]
        if c then
            return c.r, c.g, c.b
        end
    end
    if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class] then
        local c = CUSTOM_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
        local c = RAID_CLASS_COLORS[class]
        return c.r, c.g, c.b
    end
    return 1, 1, 1
end
