local addonName, LPL = ...

LPL.ListFiltering = {}

local restrictions = LPL.SetRestrictions

local function Trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or ""
end

function LPL.ListFiltering:MatchesSearch(item, query, getName)
    query = Trim(query):lower()
    if query == "" then
        return true
    end
    local name = getName and getName(item) or item.name
    if type(name) ~= "string" then
        return false
    end
    return name:lower():find(query, 1, true) ~= nil
end

function LPL.ListFiltering:FilterItems(items, options)
    options = options or {}
    local query = options.query
    local activeFilters = options.filters
    local getName = options.getName
    local getFilters = options.getFilters

    local filtered = {}
    for _, item in ipairs(items) do
        if self:MatchesSearch(item, query, getName) then
            local setFilters = getFilters and getFilters(item) or item.filters
            if restrictions:FiltersMatch(activeFilters, setFilters) then
                filtered[#filtered + 1] = item
            end
        end
    end
    return filtered
end

local OTHER_CLASS_SORT_KEY = "zzz_other"

local function ResolveClassID(item, getClassKey)
    if getClassKey then
        local key = getClassKey(item)
        if key then
            local classID = tonumber(key)
            if classID then
                return classID
            end
            if LPL.SetRestrictions and LPL.SetRestrictions.GetClassIDForClassFile then
                return LPL.SetRestrictions:GetClassIDForClassFile(key)
            end
        end
    end

    local classID = tonumber(item.classID)
    if classID then
        return classID
    end

    if LPL.SetRestrictions and LPL.SetRestrictions.GetEffectiveActionBarClassID then
        return LPL.SetRestrictions:GetEffectiveActionBarClassID(item)
    end

    if item.filters and item.filters.class and LPL.SetRestrictions then
        return LPL.SetRestrictions:GetClassIDForClassFile(item.filters.class)
    end

    return nil
end

local function GetClassNameForSort(classID)
    if LPL.BuildStore and LPL.BuildStore.ResolveName and LPL.TalentTree then
        return LPL.BuildStore:ResolveName(classID, LPL.TalentTree:GetClasses(), "ZZZ"):lower()
    end
    if GetClassInfo then
        local className = select(1, GetClassInfo(classID))
        if className then
            return className:lower()
        end
    end
    return tostring(classID)
end

function LPL.ListFiltering:GetClassSortKey(item, getClassKey)
    local classID = ResolveClassID(item, getClassKey)
    if not classID then
        return OTHER_CLASS_SORT_KEY
    end

    local playerClassID = LPL.Character and LPL.Character:GetClassID()
    local className = GetClassNameForSort(classID)
    if playerClassID and classID == playerClassID then
        return "0_" .. className
    end
    return "1_" .. className
end

function LPL.ListFiltering:SortItems(items, options)
    options = options or {}
    local isActive = options.isActive
    local getName = options.getName or function(item) return item.name or "" end
    local getClassKey = options.getClassKey

    local function SafeIsActive(item)
        if not isActive then
            return false
        end
        local ok, result = pcall(isActive, item)
        return ok and result == true
    end

    table.sort(items, function(a, b)
        local aActive = SafeIsActive(a)
        local bActive = SafeIsActive(b)
        if aActive ~= bActive then
            return aActive
        end

        local aClass = self:GetClassSortKey(a, getClassKey)
        local bClass = self:GetClassSortKey(b, getClassKey)
        if aClass ~= bClass then
            return aClass < bClass
        end

        return getName(a):lower() < getName(b):lower()
    end)

    return items
end

function LPL.ListFiltering:Process(items, options)
    local copy = {}
    for index, item in ipairs(items) do
        copy[index] = item
    end
    copy = self:FilterItems(copy, options)
    return self:SortItems(copy, options)
end
