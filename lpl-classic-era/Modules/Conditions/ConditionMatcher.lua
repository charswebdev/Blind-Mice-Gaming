local addonName, LPL = ...

LPL.ConditionMatcher = {}

local TIME_BUCKETS = {
    { key = "morning", startHour = 5, endHour = 11 },
    { key = "day", startHour = 11, endHour = 17 },
    { key = "evening", startHour = 17, endHour = 21 },
    { key = "night", startHour = 21, endHour = 5 },
}

local function SafeCall(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c
end

local function IsDelveActive()
    return false
end

local function IsInsideHousing()
    return false
end

local function IsWarModeOn()
    return false
end

local function DetectMovement()
    if IsSwimming and IsSwimming("player") then
        return "swimming"
    end
    local mounted = IsMounted and IsMounted()
    if not mounted then
        return "unmounted"
    end
    if IsFlying and IsFlying("player") then
        return "flyingMount"
    end
    return "groundMount"
end

local function DetectTimeOfDay()
    local hour = SafeCall(GetGameTime)
    hour = tonumber(hour) or 12
    for _, bucket in ipairs(TIME_BUCKETS) do
        if bucket.startHour < bucket.endHour then
            if hour >= bucket.startHour and hour < bucket.endHour then
                return bucket.key
            end
        else
            if hour >= bucket.startHour or hour < bucket.endHour then
                return bucket.key
            end
        end
    end
    return "day"
end

local function DetectRacialForm()
    if not (C_PlayerInfo and C_PlayerInfo.GetAlternateFormInfo) then
        return "native"
    end
    local hasAlt, inAlt = SafeCall(C_PlayerInfo.GetAlternateFormInfo)
    if not hasAlt then
        return "native"
    end
    return inAlt and "nonNative" or "native"
end

local function DetectWeather()
    -- Best-effort: Blizzard weather APIs vary by build. Unknown = nil (wildcard).
    if C_WeatherInfo then
        if C_WeatherInfo.GetCurrentWeatherEffect then
            local effect = SafeCall(C_WeatherInfo.GetCurrentWeatherEffect)
            if type(effect) == "number" then
                if effect == 0 then
                    return "clear"
                end
                -- Effect IDs are not stable across patches; leave unknown.
            elseif type(effect) == "string" then
                local lower = effect:lower()
                if lower:find("rain", 1, true) then
                    return "rain"
                end
                if lower:find("snow", 1, true) then
                    return "snow"
                end
                if lower:find("sand", 1, true) then
                    return "sand"
                end
                if lower:find("clear", 1, true) or lower == "" then
                    return "clear"
                end
            end
        end
        if C_WeatherInfo.GetWeatherType then
            local weatherType = SafeCall(C_WeatherInfo.GetWeatherType)
            if weatherType == 0 or weatherType == "Clear" then
                return "clear"
            end
        end
    end
    return nil
end

local function CollectActiveEquipmentSetKeys()
    local active = {}

    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs and C_EquipmentSet.GetEquipmentSetInfo then
        local ids = SafeCall(C_EquipmentSet.GetEquipmentSetIDs) or {}
        for _, setID in ipairs(ids) do
            local name, _, _, isEquipped = SafeCall(C_EquipmentSet.GetEquipmentSetInfo, setID)
            if isEquipped then
                active[tostring(setID)] = true
                if name then
                    active["blizzard:" .. tostring(setID)] = true
                end
            end
        end
    end

    if LPL.EquipmentStore and LPL.EquipmentActive then
        local sets = LPL.EquipmentStore.GetAll and LPL.EquipmentStore:GetAll()
        if type(sets) == "table" then
            for _, set in ipairs(sets) do
                if set and set.id and LPL.EquipmentActive:IsActive(set) then
                    active[tostring(set.id)] = true
                end
            end
        end
    end

    return active
end

local function LocationFlagsFromContext(ctx)
    local flags = {}
    if ctx.isRested then
        flags.rested = true
    end
    if ctx.instanceType == "party" then
        flags.dungeon = true
    elseif ctx.instanceType == "raid" then
        flags.raid = true
    elseif ctx.instanceType == "pvp" then
        flags.battleground = true
    elseif ctx.instanceType == "none" or not ctx.inInstance then
        flags.world = true
    end
    return flags
end

function LPL.ConditionMatcher:BuildContext()
    local name, instanceType, difficultyID = GetInstanceInfo()
    instanceType = instanceType or "none"
    difficultyID = tonumber(difficultyID) or 0

    local inInstance = false
    if IsInInstance then
        inInstance = IsInInstance() and true or false
    else
        inInstance = instanceType ~= "none"
    end

    local isRested = IsResting and IsResting() and true or false

    local ctx = {
        name = name,
        instanceType = instanceType,
        difficultyID = difficultyID,
        inInstance = inInstance,
        isDelve = false,
        isHousing = false,
        isRested = isRested,
        warMode = false,
        movement = DetectMovement(),
        weather = DetectWeather(),
        timeOfDay = DetectTimeOfDay(),
        racialForm = DetectRacialForm(),
        equipmentSets = CollectActiveEquipmentSetKeys(),
    }
    ctx.locationFlags = LocationFlagsFromContext(ctx)
    return ctx
end

function LPL.ConditionMatcher:GetSituationKey(ctx)
    ctx = ctx or self:BuildContext()
    local locParts = {}
    for key, enabled in pairs(ctx.locationFlags or {}) do
        if enabled then
            locParts[#locParts + 1] = key
        end
    end
    table.sort(locParts)

    local equipParts = {}
    for key in pairs(ctx.equipmentSets or {}) do
        equipParts[#equipParts + 1] = key
    end
    table.sort(equipParts)

    return table.concat({
        table.concat(locParts, ","),
        tostring(ctx.difficultyID or 0),
        tostring(ctx.movement or ""),
        tostring(ctx.weather or "unknown"),
        tostring(ctx.timeOfDay or ""),
        tostring(ctx.racialForm or ""),
        table.concat(equipParts, ","),
    }, "|")
end

local function CategoryMatches(selectedFlags, currentKey, unknownMeansMatch)
    if LPL.ConditionDefs:CountFlags(selectedFlags) == 0 then
        return true -- empty = wildcard
    end
    if currentKey == nil then
        return unknownMeansMatch ~= false
    end
    return selectedFlags[currentKey] == true
end

local function LocationMatches(situations, ctx)
    local selected = situations.locations
    if LPL.ConditionDefs:CountFlags(selected) == 0 then
        return true
    end

    local current = ctx.locationFlags or {}
    for key, enabled in pairs(selected) do
        if enabled and current[key] then
            -- Difficulty filter only applies to instanced location types.
            local needsDifficulty = (key == "dungeon" or key == "raid" or key == "battleground")
            if not needsDifficulty then
                return true
            end

            local wanted = situations.difficultyIDs or {}
            if #wanted == 0 then
                return true
            end

            local difficultySet = LPL.ConditionDefs:DifficultySetFromList(wanted)
            -- id 0 in defs means "any" for arena/bg/scenario/delve.
            if difficultySet[0] or difficultySet[ctx.difficultyID] then
                return true
            end
            -- Matched location but wrong difficulty; try other selected location ticks.
        end
    end
    return false
end

local function EquipmentMatches(situations, ctx)
    local wanted = situations.equipmentSetIDs or {}
    if #wanted == 0 then
        return true
    end
    local active = ctx.equipmentSets or {}
    for _, id in ipairs(wanted) do
        if active[tostring(id)] then
            return true
        end
    end
    return false
end

function LPL.ConditionMatcher:RuleMatches(rule, ctx)
    rule = LPL.ConditionStore:NormalizeRule(rule)
    if not rule or not rule.enabled then
        return false
    end
    ctx = ctx or self:BuildContext()
    local situations = rule.situations or LPL.ConditionStore:CreateEmptySituations()

    if not LocationMatches(situations, ctx) then
        return false
    end
    if not CategoryMatches(situations.movement, ctx.movement, true) then
        return false
    end
    if not CategoryMatches(situations.weather, ctx.weather, true) then
        return false
    end
    if not CategoryMatches(situations.timeOfDay, ctx.timeOfDay, true) then
        return false
    end
    if not CategoryMatches(situations.racialForms, ctx.racialForm, true) then
        return false
    end
    if not EquipmentMatches(situations, ctx) then
        return false
    end
    return true
end

--- Highest-priority matching rule that still has Limits-eligible targets.
--- When limitConditions is off, eligible targets from all matching rules are merged.
function LPL.ConditionMatcher:FindMatch(ctx)
    ctx = ctx or self:BuildContext()
    if not LPL.ConditionStore:IsMasterEnabled() then
        return nil
    end

    local matches = {}
    for _, rule in ipairs(LPL.ConditionStore:GetAll()) do
        if self:RuleMatches(rule, ctx) then
            local eligible = LPL.ConditionStore:GetEligibleTargetsForPlayer(rule)
            if #eligible > 0 then
                matches[#matches + 1] = {
                    rule = rule,
                    targets = eligible,
                    priority = tonumber(rule.priority) or 100,
                }
            end
        end
    end

    if #matches == 0 then
        return nil
    end

    table.sort(matches, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return (a.rule.name or "") < (b.rule.name or "")
    end)

    local settings = LPL.ConditionStore:GetSettings()
    local selected = { matches[1] }
    if not settings.limitConditions then
        selected = matches
    else
        local topPriority = matches[1].priority
        selected = {}
        for _, match in ipairs(matches) do
            if match.priority == topPriority then
                selected[#selected + 1] = match
            else
                break
            end
        end
    end

    local targets = {}
    local seen = {}
    for _, match in ipairs(selected) do
        for _, target in ipairs(match.targets) do
            local key = tostring(target.type) .. ":" .. tostring(target.id)
            if not seen[key] then
                seen[key] = true
                targets[#targets + 1] = target
            end
        end
    end

    if #targets == 0 then
        return nil
    end

    return {
        rule = selected[1].rule,
        targets = targets,
        loadouts = targets,
        context = ctx,
        situationKey = self:GetSituationKey(ctx),
        matchCount = #selected,
    }
end
