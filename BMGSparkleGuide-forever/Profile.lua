local _, G = ...

local STEPS = { "20", "15", "10", "5", "at" }

local function Known(list, key)
    for _, item in ipairs(list) do
        if item.key == key then
            return true
        end
    end
    return false
end

local function Clamp(number, low, high)
    number = math.floor(number + 0.5)
    if number < low then
        number = low
    end
    if number > high then
        number = high
    end
    return number
end

local function Bit(text, index)
    local mark = text:sub(index, index)
    if mark ~= "0" and mark ~= "1" then
        return nil
    end
    return mark == "1"
end

local function Flag(value)
    if value then
        return "1"
    end
    return "0"
end

function G.ExportProfile()
    local lines = { "SG1" }
    local on = {}
    for _, info in ipairs(G.KINDS) do
        on[#on + 1] = Flag(G.db.enabled[info.key])
    end
    lines[#lines + 1] = "on:" .. table.concat(on)
    lines[#lines + 1] = "voice:" .. Flag(G.db.voice)
    local steps = {}
    for _, key in ipairs(STEPS) do
        steps[#steps + 1] = Flag(G.db.steps[key])
    end
    lines[#lines + 1] = "steps:" .. table.concat(steps)
    lines[#lines + 1] = "hide:" .. Flag(G.db.hideCombat) .. Flag(G.db.hideInstance)
    lines[#lines + 1] = "map:" .. Flag(G.db.minimap)
    for _, info in ipairs(G.KINDS) do
        local look = G.db.look[info.key]
        lines[#lines + 1] = info.key .. ":" .. table.concat({
            look.style or "lightbeam",
            look.color or "gold",
            tostring(look.size or 100),
            tostring(look.height or -24),
            tostring(look.brightness or 100),
            tostring(look.count or 8),
        }, ",")
    end
    local skipped = {}
    for _, info in ipairs(G.KINDS) do
        local saved = G.db.track and G.db.track[info.key]
        local keys = G.TRACK_KEY and G.TRACK_KEY[info.key]
        if type(saved) == "table" and keys then
            local names = {}
            for key, value in pairs(saved) do
                if value == false and keys[key] then
                    names[#names + 1] = key
                end
            end
            table.sort(names)
            if names[1] then
                skipped[#skipped + 1] = info.key .. "=" .. table.concat(names, ",")
            end
        end
    end
    if skipped[1] then
        lines[#lines + 1] = "off:" .. table.concat(skipped, "|")
    end
    return table.concat(lines, "\n")
end

function G.ImportProfile(text)
    if type(text) ~= "string" then
        return false
    end
    text = text:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lines = {}
    for line in text:gmatch("[^\n]+") do
        lines[#lines + 1] = line:gsub("^%s+", ""):gsub("%s+$", "")
    end
    if lines[1] ~= "SG1" then
        return false
    end
    local found = {}
    for index = 2, #lines do
        local key, value = lines[index]:match("^([%w]+):(.*)$")
        if not key or found[key] then
            return false
        end
        found[key] = value
    end
    if not found.on or #found.on ~= #G.KINDS then
        return false
    end
    local enabled = {}
    for index, info in ipairs(G.KINDS) do
        local bit = Bit(found.on, index)
        if bit == nil then
            return false
        end
        enabled[info.key] = bit
    end
    if not found.voice or #found.voice ~= 1 then
        return false
    end
    local voice = Bit(found.voice, 1)
    if voice == nil or not found.steps or #found.steps ~= #STEPS then
        return false
    end
    local steps = {}
    for index, key in ipairs(STEPS) do
        local bit = Bit(found.steps, index)
        if bit == nil then
            return false
        end
        steps[key] = bit
    end
    if not found.hide or #found.hide ~= 2 or not found.map or #found.map ~= 1 then
        return false
    end
    local hideCombat = Bit(found.hide, 1)
    local hideInstance = Bit(found.hide, 2)
    local minimap = Bit(found.map, 1)
    if hideCombat == nil or hideInstance == nil or minimap == nil then
        return false
    end
    local looks = {}
    for _, info in ipairs(G.KINDS) do
        local value = found[info.key]
        if not value then
            return false
        end
        local style, color, size, height, bright, count = value:match("^([%w]+),([%w]+),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)$")
        size, height, bright, count = tonumber(size), tonumber(height), tonumber(bright), tonumber(count)
        if not style or not size or not Known(G.STYLES, style) or not Known(G.COLORS, color) then
            return false
        end
        looks[info.key] = {
            style = style,
            color = color,
            size = Clamp(size, 60, 240),
            height = Clamp(height, -80, 40),
            brightness = Clamp(bright, 20, 100),
            count = Clamp(count, 3, 12),
        }
    end
    local track = {}
    for _, info in ipairs(G.KINDS) do
        track[info.key] = {}
    end
    if found.off and found.off ~= "" then
        for piece in found.off:gmatch("[^|]+") do
            local kind, names = piece:match("^([%w]+)=([%w_,]+)$")
            local keys = kind and G.TRACK_KEY and G.TRACK_KEY[kind]
            if not kind or not keys then
                return false
            end
            for name in names:gmatch("[^,%s]+") do
                if not keys[name] then
                    return false
                end
                track[kind][name] = false
            end
        end
    end
    for _, info in ipairs(G.KINDS) do
        G.db.enabled[info.key] = enabled[info.key]
        local look = G.db.look[info.key]
        local incoming = looks[info.key]
        look.style = incoming.style
        look.color = incoming.color
        look.size = incoming.size
        look.height = incoming.height
        look.brightness = incoming.brightness
        look.count = incoming.count
        G.db.track[info.key] = track[info.key]
    end
    G.db.voice = voice
    for key, value in pairs(steps) do
        G.db.steps[key] = value
    end
    G.db.hideCombat = hideCombat
    G.db.hideInstance = hideInstance
    G.db.minimap = minimap
    return true
end
