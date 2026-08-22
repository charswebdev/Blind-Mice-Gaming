local addonName, LPL = ...

-- Blizzard-style Situations categories adapted for Classic Era Conditions.

LPL.ConditionDefs = {}

LPL.ConditionDefs.LOCATIONS = {
    { key = "world", label = "Open World" },
    { key = "rested", label = "Rest Area" },
    { key = "dungeon", label = "Dungeons" },
    { key = "raid", label = "Raids" },
    { key = "battleground", label = "Battlegrounds" },
}

LPL.ConditionDefs.MOVEMENT = {
    { key = "unmounted", label = "Unmounted" },
    { key = "swimming", label = "Swimming" },
    { key = "groundMount", label = "Ground Mount" },
    { key = "flyingMount", label = "Flying Mount" },
}

LPL.ConditionDefs.WEATHER = {
    { key = "clear", label = "Clear" },
    { key = "rain", label = "Rain" },
    { key = "snow", label = "Snow" },
    { key = "sand", label = "Sandstorm" },
}

LPL.ConditionDefs.TIME_OF_DAY = {
    { key = "morning", label = "Morning" },
    { key = "day", label = "Midday" },
    { key = "evening", label = "Evening" },
    { key = "night", label = "Night" },
}

LPL.ConditionDefs.RACIAL_FORMS = {
    { key = "native", label = "Native form" },
    { key = "nonNative", label = "Alternate form" },
}

-- Apply targets a rule can link. "all" is UI filter-only.
LPL.ConditionDefs.LINK_TYPES = {
    { key = "all", label = "All", badge = nil, filterOnly = true },
    { key = "loadout", label = "Loadouts", badge = "LOADOUT" },
    { key = "talent", label = "Talents", badge = "TALENTS" },
    { key = "actionBar", label = "Action Bars", badge = "BARS" },
    { key = "equipment", label = "Equipment", badge = "GEAR" },
    { key = "editMode", label = "Edit Mode", badge = "UI" },
}

function LPL.ConditionDefs:GetLinkTypeDef(key)
    for _, def in ipairs(self.LINK_TYPES) do
        if def.key == key then
            return def
        end
    end
    return nil
end

function LPL.ConditionDefs:GetLinkBadge(key)
    local def = self:GetLinkTypeDef(key)
    return def and def.badge or "LINK"
end

function LPL.ConditionDefs:GetLinkLabel(key)
    local def = self:GetLinkTypeDef(key)
    return def and def.label or key
end

-- difficultyID values from GetInstanceInfo(); empty selection = all difficulties.
LPL.ConditionDefs.DIFFICULTIES = {
    dungeon = {
        { id = 1, label = "Normal" },
    },
    raid = {
        { id = 0, label = "Any raid" },
    },
    battleground = {
        { id = 0, label = "Any battleground" },
    },
}

function LPL.ConditionDefs:EmptyFlagTable(defs)
    local out = {}
    for _, def in ipairs(defs or {}) do
        out[def.key] = false
    end
    return out
end

function LPL.ConditionDefs:NormalizeFlagTable(source, defs)
    local out = self:EmptyFlagTable(defs)
    if type(source) ~= "table" then
        return out
    end
    for _, def in ipairs(defs or {}) do
        if source[def.key] then
            out[def.key] = true
        end
    end
    return out
end

function LPL.ConditionDefs:CountFlags(flags)
    local count = 0
    if type(flags) ~= "table" then
        return 0
    end
    for _, value in pairs(flags) do
        if value then
            count = count + 1
        end
    end
    return count
end

function LPL.ConditionDefs:NormalizeDifficultyIDs(source)
    local out = {}
    local seen = {}
    if type(source) ~= "table" then
        return out
    end
    local function push(id)
        id = tonumber(id)
        if id and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    if #source > 0 then
        for _, id in ipairs(source) do
            push(id)
        end
    else
        for id, enabled in pairs(source) do
            if enabled then
                push(id)
            end
        end
    end
    table.sort(out)
    return out
end

function LPL.ConditionDefs:DifficultySetFromList(list)
    local set = {}
    for _, id in ipairs(list or {}) do
        set[tonumber(id)] = true
    end
    return set
end

function LPL.ConditionDefs:SummarizeFlags(flags, defs)
    local labels = {}
    for _, def in ipairs(defs or {}) do
        if flags and flags[def.key] then
            labels[#labels + 1] = def.label
        end
    end
    return labels
end
