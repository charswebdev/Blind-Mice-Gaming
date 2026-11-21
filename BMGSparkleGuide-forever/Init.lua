local _, G = ...

G.VERSION = "1.1.2"

G.KINDS = {
    { key = "herbs", label = "Herbs", blurb = "Sparkles on herbs", sample = "Herbs", model = 219481 },
    { key = "ore", label = "Ore", blurb = "Sparkles on ore", sample = "Copper Vein", model = 219514 },
    { key = "treasure", label = "Treasure", blurb = "Sparkles on chests and coffers", sample = "Treasure", model = 219372 },
    { key = "quests", label = "Quest objects", blurb = "Sparkles on things a quest sends you to", sample = "Quest object", model = 200960 },
    { key = "bobber", label = "Fishing bobber", blurb = "Sparkles on your fishing bobber", sample = "Fishing bobber", model = 201000 },
    { key = "loot", label = "Loot", blurb = "Sparkles on corpses you can loot", sample = "Loot", model = 0 },
    { key = "skinning", label = "Skinning", blurb = "Sparkles on corpses you can skin", sample = "Skin", model = 0 },
    { key = "others", label = "Other objects", blurb = "Sparkles on the other objects checked below", sample = "Object", model = 200912 },
    { key = "flight", label = "Flight path", blurb = "Sparkles on a flight master", sample = "Flight path", model = 0 },
}

G.STYLES = {
    { key = "lightbeam", label = "Light beam" },
    { key = "twinkle", label = "Twinkle" },
    { key = "glints", label = "Glints" },
    { key = "pollen", label = "Pollen" },
    { key = "starcrown", label = "Star crown" },
}

G.COLORS = {
    { key = "gold", label = "Gold and white", r1 = 0.95, g1 = 0.62, b1 = 0.02, r2 = 1, g2 = 0.9, b2 = 0.55 },
    { key = "nature", label = "Nature", r1 = 0.02, g1 = 0.62, b1 = 0.08, r2 = 0.35, g2 = 0.95, b2 = 0.2 },
    { key = "arcane", label = "Arcane", r1 = 0.48, g1 = 0.05, b1 = 0.92, r2 = 0.75, g2 = 0.35, b2 = 1 },
    { key = "frost", label = "Frost", r1 = 0.35, g1 = 0.9, b1 = 1, r2 = 0.75, g2 = 1, b2 = 1 },
    { key = "fire", label = "Fire", r1 = 1, g1 = 0.28, b1 = 0, r2 = 1, g2 = 0.58, b2 = 0.05 },
    { key = "shadow", label = "Shadow", r1 = 0.22, g1 = 0.02, b1 = 0.32, r2 = 0.42, g2 = 0.12, b2 = 0.62 },
    { key = "holy", label = "Holy", r1 = 1, g1 = 0.72, b1 = 0.84, r2 = 1, g2 = 0.9, b2 = 0.94 },
    { key = "blood", label = "Blood", r1 = 0.68, g1 = 0, b1 = 0.04, r2 = 1, g2 = 0.12, b2 = 0.12 },
    { key = "white", label = "White", r1 = 1, g1 = 1, b1 = 1, r2 = 1, g2 = 0.98, b2 = 0.92 },
    { key = "sun", label = "Sun", r1 = 1, g1 = 0.96, b1 = 0, r2 = 1, g2 = 1, b2 = 0.45 },
    { key = "fel", label = "Fel", r1 = 0.55, g1 = 1, b1 = 0, r2 = 0.78, g2 = 1, b2 = 0.2 },
    { key = "sea", label = "Sea", r1 = 0, g1 = 0.42, b1 = 0.4, r2 = 0.1, g2 = 0.78, b2 = 0.65 },
    { key = "royal", label = "Royal blue", r1 = 0.05, g1 = 0.16, b1 = 0.95, r2 = 0.28, g2 = 0.45, b2 = 1 },
    { key = "rose", label = "Rose", r1 = 0.95, g1 = 0.02, b1 = 0.4, r2 = 1, g2 = 0.35, b2 = 0.6 },
    { key = "copper", label = "Copper", r1 = 0.55, g1 = 0.26, b1 = 0.08, r2 = 0.82, g2 = 0.48, b2 = 0.18 },
    { key = "moon", label = "Moon", r1 = 0.5, g1 = 0.54, b1 = 0.6, r2 = 0.78, g2 = 0.8, b2 = 0.84 },
}

local ON = { herbs = true, ore = true, treasure = true, quests = true, bobber = true, flight = true }

local function CopyLook()
    return { style = "lightbeam", color = "gold", size = 100, height = -24, brightness = 100, count = 8 }
end

function G.Secret(value)
    if issecretvalue == nil then
        return false
    end
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == true
end

function G.PlainNumber(value)
    if G.Secret(value) or value == nil then
        return nil
    end
    local ok, number = pcall(tonumber, value)
    if ok and type(number) == "number" then
        return number
    end
    return nil
end

function G.PlainString(value)
    if G.Secret(value) or value == nil then
        return nil
    end
    if type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

function G.IsTrue(fn, ...)
    if type(fn) ~= "function" then
        return false
    end
    local ok, value = pcall(fn, ...)
    if not ok then
        return false
    end
    if G.Secret(value) then
        if value then
            return true
        end
        return false
    end
    return value == true or value == 1
end

function G.ColorByKey(key)
    for _, color in ipairs(G.COLORS) do
        if color.key == key then
            return color
        end
    end
    return G.COLORS[1]
end

function G.KindInfo(key)
    for _, info in ipairs(G.KINDS) do
        if info.key == key then
            return info
        end
    end
    return G.KINDS[1]
end

local function DefaultDB()
    local look = {}
    local enabled = {}
    for _, info in ipairs(G.KINDS) do
        look[info.key] = CopyLook()
        enabled[info.key] = ON[info.key] == true
    end
    return {
        enabled = enabled,
        look = look,
        voice = true,
        steps = { ["50"] = true, ["45"] = true, ["40"] = true, ["35"] = true, ["30"] = true, ["25"] = true, ["20"] = true, ["15"] = true, ["10"] = true, ["5"] = true, at = true },
        hideCombat = false,
        hideInstance = true,
        minimap = true,
        minimapAngle = 220,
        windowWidth = 980,
        windowHeight = 900,
        cvarSaved = {},
    }
end

function G.LoadDB()
    local defaults = DefaultDB()
    local saved = BMGSparkleGuideForeverDB
    if type(saved) ~= "table" then
        saved = {}
    end
    if type(saved.enabled) ~= "table" then
        saved.enabled = {}
    end
    if type(saved.look) ~= "table" then
        saved.look = {}
    end
    if type(saved.steps) ~= "table" then
        saved.steps = {}
    end
    if type(saved.cvarSaved) ~= "table" then
        saved.cvarSaved = {}
    end
    if type(saved.track) ~= "table" then
        saved.track = {}
    end
    for _, info in ipairs(G.KINDS) do
        if type(saved.track[info.key]) ~= "table" then
            saved.track[info.key] = {}
        end
    end
    for _, info in ipairs(G.KINDS) do
        if saved.enabled[info.key] == nil then
            saved.enabled[info.key] = defaults.enabled[info.key]
        end
        local look = saved.look[info.key]
        if type(look) ~= "table" then
            look = {}
            saved.look[info.key] = look
        end
        local base = defaults.look[info.key]
        for key, value in pairs(base) do
            if look[key] == nil then
                look[key] = value
            end
        end
    end
    if saved.voice == nil then
        saved.voice = true
    end
    for key, value in pairs(defaults.steps) do
        if saved.steps[key] == nil then
            saved.steps[key] = value
        end
    end
    if saved.hideCombat == nil then
        saved.hideCombat = false
    end
    if saved.hideInstance == nil then
        saved.hideInstance = true
    end
    if saved.minimap == nil then
        saved.minimap = true
    end
    if type(saved.minimapAngle) ~= "number" then
        saved.minimapAngle = 220
    end
    if type(saved.windowWidth) ~= "number" then
        saved.windowWidth = 980
    elseif saved.windowWidth < 820 then
        saved.windowWidth = 820
    elseif saved.windowWidth > 1800 then
        saved.windowWidth = 1800
    end
    if type(saved.windowHeight) ~= "number" then
        saved.windowHeight = 900
    elseif saved.windowHeight < 640 then
        saved.windowHeight = 640
    elseif saved.windowHeight > 1400 then
        saved.windowHeight = 1400
    end
    BMGSparkleGuideForeverDB = saved
    G.db = saved
    if G.ApplyTrackDefaults then
        G.ApplyTrackDefaults()
    end
end

function G.AnySparkleOn()
    for _, info in ipairs(G.KINDS) do
        if G.db.enabled[info.key] then
            return true
        end
    end
    return false
end

function G.Paused()
    if G.db.hideCombat and G.IsTrue(UnitAffectingCombat, "player") then
        return true
    end
    if G.db.hideInstance and G.IsTrue(IsInInstance) then
        return true
    end
    return false
end
