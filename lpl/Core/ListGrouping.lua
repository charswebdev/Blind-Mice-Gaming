local addonName, LPL = ...

LPL.ListGrouping = {}

local OTHER_KEY = "other"
local NO_SPEC = 0
local NO_HERO = 0

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
    if item.restrictions and LPL.SetRestrictions and LPL.SetRestrictions.GetSingleRestrictedSpecID then
        local specID = LPL.SetRestrictions:GetSingleRestrictedSpecID(item.restrictions)
        if specID and LPL.SetRestrictions.GetClassIDForSpecID then
            return LPL.SetRestrictions:GetClassIDForSpecID(specID)
        end
    end
    return nil
end

local function ResolveSpecID(item, getSpecKey)
    if getSpecKey then
        local key = getSpecKey(item)
        if key then
            return tonumber(key)
        end
    end
    local specID = tonumber(item.specID)
    if specID then
        return specID
    end
    if item.filters and item.filters.spec then
        return tonumber(item.filters.spec)
    end
    if item.restrictions and item.restrictions.herotalents and LPL.SetRestrictions and LPL.SetRestrictions.ParseHeroTalentKey then
        for heroKey in pairs(item.restrictions.herotalents) do
            local specID = LPL.SetRestrictions:ParseHeroTalentKey(heroKey)
            if specID then
                return specID
            end
        end
    end
    return nil
end

local function ResolveHeroKey(item, getHeroKey)
    if getHeroKey then
        local key = getHeroKey(item)
        if key then
            local numeric = tonumber(key)
            if numeric then
                return numeric
            end
            if LPL.SetRestrictions and LPL.SetRestrictions.ParseHeroTalentKey then
                local _, heroID = LPL.SetRestrictions:ParseHeroTalentKey(key)
                if heroID then
                    return heroID
                end
            end
        end
    end
    local heroID = tonumber(item.subTreeID)
    if heroID then
        return heroID
    end
    if item.filters and item.filters.herotalents then
        local filterHero = tonumber(item.filters.herotalents)
        if filterHero then
            return filterHero
        end
        if LPL.SetRestrictions and LPL.SetRestrictions.ParseHeroTalentKey then
            local _, parsed = LPL.SetRestrictions:ParseHeroTalentKey(item.filters.herotalents)
            if parsed then
                return parsed
            end
        end
    end
    if item.restrictions and item.restrictions.herotalents and LPL.SetRestrictions and LPL.SetRestrictions.ParseHeroTalentKey then
        for heroKey in pairs(item.restrictions.herotalents) do
            local _, parsed = LPL.SetRestrictions:ParseHeroTalentKey(heroKey)
            if parsed then
                return parsed
            end
        end
    end
    return nil
end

local function SafeIsActive(item, isActive)
    if not isActive then
        return false
    end
    local ok, result = pcall(isActive, item)
    return ok and result == true
end

local function SortItems(items, getName, isActive)
    table.sort(items, function(a, b)
        local aActive = SafeIsActive(a, isActive)
        local bActive = SafeIsActive(b, isActive)
        if aActive ~= bActive then
            return aActive
        end
        local aName = getName and getName(a) or a.name or ""
        local bName = getName and getName(b) or b.name or ""
        return aName:lower() < bName:lower()
    end)
end

function LPL.ListGrouping:GetCollapsedStorage(listKey)
    LPL.DB:SyncFromGlobal()
    LPLDB.listCollapsed = LPLDB.listCollapsed or {}
    LPLDB.listCollapsed[listKey] = LPLDB.listCollapsed[listKey] or {}
    return LPLDB.listCollapsed[listKey]
end

function LPL.ListGrouping:GetClassName(classID)
    if not classID then
        return "Other"
    end
    if LPL.BuildStore and LPL.BuildStore.ResolveName and LPL.TalentTree then
        return LPL.BuildStore:ResolveName(classID, LPL.TalentTree:GetClasses(), "Other")
    end
    if GetClassInfo then
        return select(1, GetClassInfo(classID)) or "Other"
    end
    return "Other"
end

function LPL.ListGrouping:GetSpecName(classID, specID)
    if not specID or specID == NO_SPEC then
        return "General"
    end
    if LPL.BuildStore and LPL.BuildStore.ResolveName and LPL.TalentTree then
        return LPL.BuildStore:ResolveName(specID, LPL.TalentTree:GetSpecsForClass(classID or 1), "General")
    end
    if GetSpecializationInfoByID then
        return select(2, GetSpecializationInfoByID(specID)) or "General"
    end
    return "General"
end

function LPL.ListGrouping:GetHeroName(classID, specID, subTreeID)
    if not subTreeID or subTreeID == NO_HERO then
        return "General"
    end
    if LPL.BuildStore and LPL.BuildStore.ResolveName and LPL.TalentTree then
        return LPL.BuildStore:ResolveName(subTreeID, LPL.TalentTree:GetHeroTalentsForSpec(specID or 0), "General")
    end
    return "Hero"
end

function LPL.ListGrouping:GetClassSpecLabel(classID, specID)
    local className = self:GetClassName(classID)
    local specName = self:GetSpecName(classID, specID)
    return self:WrapClassText(classID, className .. " " .. specName)
end

function LPL.ListGrouping:WrapClassText(classID, text)
    if not classID or not LPL.BuildStore then
        return text
    end
    local r, g, b = LPL.BuildStore:GetClassColor(classID)
    return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

function LPL.ListGrouping:IsCollapsed(storage, key, defaultCollapsed)
    local value = storage[key]
    if value == nil then
        return defaultCollapsed == true
    end
    return value == true
end

function LPL.ListGrouping:SetCollapsed(storage, key, collapsed)
    storage[key] = collapsed == true
end

function LPL.ListGrouping:ToggleCollapsed(storage, key, defaultCollapsed)
    self:SetCollapsed(storage, key, not self:IsCollapsed(storage, key, defaultCollapsed))
end

function LPL.ListGrouping:DefaultClassCollapsed(classID, playerClassID)
    if not classID then
        return false
    end
    return playerClassID == nil or classID ~= playerClassID
end

function LPL.ListGrouping:DefaultSpecCollapsed(classID, specID, playerClassID, playerSpecID)
    if not specID or specID == NO_SPEC then
        return true
    end
    if playerClassID and classID == playerClassID then
        return playerSpecID == nil or specID ~= playerSpecID
    end
    return true
end

function LPL.ListGrouping:DefaultHeroCollapsed(classID, specID, subTreeID, playerClassID, playerSpecID)
    if not subTreeID or subTreeID == NO_HERO then
        return true
    end
    if playerClassID and classID == playerClassID and playerSpecID and specID == playerSpecID then
        return false
    end
    return true
end

function LPL.ListGrouping:GetHeroOrder(classID, specID, heroBuckets, playerClassID, playerSpecID)
    local ordered = {}
    local sortable = {}
    for subTreeID in pairs(heroBuckets) do
        sortable[#sortable + 1] = subTreeID
    end
    table.sort(sortable, function(a, b)
        if a == NO_HERO then
            return false
        end
        if b == NO_HERO then
            return true
        end
        return self:GetHeroName(classID, specID, a):lower() < self:GetHeroName(classID, specID, b):lower()
    end)
    for _, subTreeID in ipairs(sortable) do
        ordered[#ordered + 1] = subTreeID
    end
    return ordered
end

function LPL.ListGrouping:GetClassOrder(classIDs, playerClassID)
    local ordered = {}
    local seen = {}

    if playerClassID and classIDs[playerClassID] then
        ordered[#ordered + 1] = playerClassID
        seen[playerClassID] = true
    end

    local sortable = {}
    for classID in pairs(classIDs) do
        if not seen[classID] then
            sortable[#sortable + 1] = classID
        end
    end

    table.sort(sortable, function(a, b)
        return self:GetClassName(a):lower() < self:GetClassName(b):lower()
    end)

    for _, classID in ipairs(sortable) do
        ordered[#ordered + 1] = classID
    end

    return ordered
end

function LPL.ListGrouping:GetSpecOrder(classID, specBuckets, playerSpecID)
    local ordered = {}
    local seen = {}

    if playerSpecID and specBuckets[playerSpecID] then
        ordered[#ordered + 1] = playerSpecID
        seen[playerSpecID] = true
    end

    local sortable = {}
    for specID in pairs(specBuckets) do
        if not seen[specID] then
            sortable[#sortable + 1] = specID
        end
    end

    table.sort(sortable, function(a, b)
        return self:GetSpecName(classID, a):lower() < self:GetSpecName(classID, b):lower()
    end)

    for _, specID in ipairs(sortable) do
        ordered[#ordered + 1] = specID
    end

    return ordered
end

function LPL.ListGrouping:EnsureExpandedForItem(storage, listKey, itemID, options)
    if not itemID then
        return
    end

    storage = storage or self:GetCollapsedStorage(listKey)
    options = options or {}
    local items = options.items or {}
    local getID = options.getID
    local getClassKey = options.getClassKey
    local getSpecKey = options.getSpecKey
    local getHeroKey = options.getHeroKey
    local playerClassID = LPL.Character and LPL.Character:GetClassID()
    local playerSpecID = LPL.Character and LPL.Character:GetSpecID()

    for _, item in ipairs(items) do
        if getID and getID(item) == itemID then
            local classID = ResolveClassID(item, getClassKey)
            local specID = ResolveSpecID(item, getSpecKey)
            local subTreeID = ResolveHeroKey(item, getHeroKey)

            if not classID then
                self:SetCollapsed(storage, OTHER_KEY, false)
                return
            end

            local classKey = "class:" .. classID
            self:SetCollapsed(storage, classKey, false)

            if specID then
                local specKey = "spec:" .. classID .. ":" .. specID
                self:SetCollapsed(storage, specKey, false)
                if subTreeID then
                    local heroKey = "hero:" .. classID .. ":" .. specID .. ":" .. subTreeID
                    self:SetCollapsed(storage, heroKey, false)
                end
            end
            return
        end
    end
end

function LPL.ListGrouping:BuildDisplayList(items, options)
    options = options or {}
    local getName = options.getName or function(item) return item.name or "" end
    local getClassKey = options.getClassKey
    local getSpecKey = options.getSpecKey
    local getHeroKey = options.getHeroKey
    local isActive = options.isActive
    local listKey = options.listKey or "default"
    local groupBySpec = options.groupBySpec ~= false
    local groupByHero = options.groupByHero == true
    local storage = self:GetCollapsedStorage(listKey)

    if options.flatList then
        local list = {}
        for _, item in ipairs(items or {}) do
            list[#list + 1] = item
        end
        SortItems(list, getName, isActive)
        local entries = {}
        for _, item in ipairs(list) do
            entries[#entries + 1] = {
                type = "item",
                item = item,
                depth = 0,
            }
        end
        return entries, storage
    end

    local playerClassID = LPL.Character and LPL.Character:GetClassID()
    local playerSpecID = LPL.Character and LPL.Character:GetSpecID()

    local byClass = {}
    local otherItems = {}

    for _, item in ipairs(items) do
        local classID = ResolveClassID(item, getClassKey)
        local specID = ResolveSpecID(item, getSpecKey)

        if not classID then
            otherItems[#otherItems + 1] = item
        else
            byClass[classID] = byClass[classID] or { specs = {}, noSpec = {} }
            if specID and groupBySpec then
                byClass[classID].specs[specID] = byClass[classID].specs[specID] or { heroes = {}, noHero = {} }
                local specBucket = byClass[classID].specs[specID]
                if groupByHero then
                    local subTreeID = ResolveHeroKey(item, getHeroKey) or NO_HERO
                    if subTreeID == NO_HERO then
                        specBucket.noHero[#specBucket.noHero + 1] = item
                    else
                        specBucket.heroes[subTreeID] = specBucket.heroes[subTreeID] or {}
                        specBucket.heroes[subTreeID][#specBucket.heroes[subTreeID] + 1] = item
                    end
                else
                    specBucket.items = specBucket.items or {}
                    specBucket.items[#specBucket.items + 1] = item
                end
            else
                byClass[classID].noSpec[#byClass[classID].noSpec + 1] = item
            end
        end
    end

    for classID, bucket in pairs(byClass) do
        for specID, specBucket in pairs(bucket.specs) do
            if groupByHero then
                for subTreeID, heroItems in pairs(specBucket.heroes or {}) do
                    SortItems(heroItems, getName, isActive)
                end
                SortItems(specBucket.noHero or {}, getName, isActive)
            else
                SortItems(specBucket.items or {}, getName, isActive)
            end
        end
        SortItems(bucket.noSpec, getName, isActive)
    end
    SortItems(otherItems, getName, isActive)

    -- Only auto-expand active groups when the user has not chosen collapse state yet.
    for _, item in ipairs(items) do
        if SafeIsActive(item, isActive) then
            local classID = ResolveClassID(item, getClassKey)
            local specID = ResolveSpecID(item, getSpecKey)
            local subTreeID = ResolveHeroKey(item, getHeroKey)
            if not classID then
                if storage[OTHER_KEY] == nil then
                    self:SetCollapsed(storage, OTHER_KEY, false)
                end
            else
                local classKey = "class:" .. classID
                if storage[classKey] == nil then
                    self:SetCollapsed(storage, classKey, false)
                end
                if specID and groupBySpec then
                    local specKey = "spec:" .. classID .. ":" .. specID
                    if storage[specKey] == nil then
                        self:SetCollapsed(storage, specKey, false)
                    end
                    if groupByHero and subTreeID then
                        local heroKey = "hero:" .. classID .. ":" .. specID .. ":" .. subTreeID
                        if storage[heroKey] == nil then
                            self:SetCollapsed(storage, heroKey, false)
                        end
                    end
                end
            end
        end
    end

    local entries = {}
    local classOrder = self:GetClassOrder(byClass, playerClassID)

    local function appendItems(itemList, depth)
        for _, item in ipairs(itemList) do
            entries[#entries + 1] = {
                type = "item",
                item = item,
                depth = depth,
            }
        end
    end

    local function appendHeroGroups(specBucket, classID, specID, baseDepth)
        local heroOrder = self:GetHeroOrder(classID, specID, specBucket.heroes or {}, playerClassID, playerSpecID)
        local hasHeroGroups = #heroOrder > 0

        for _, subTreeID in ipairs(heroOrder) do
            local heroKey = "hero:" .. classID .. ":" .. specID .. ":" .. subTreeID
            local heroCollapsed = self:IsCollapsed(
                storage,
                heroKey,
                self:DefaultHeroCollapsed(classID, specID, subTreeID, playerClassID, playerSpecID)
            )
            entries[#entries + 1] = {
                type = "hero",
                key = heroKey,
                classID = classID,
                specID = specID,
                subTreeID = subTreeID,
                label = self:GetHeroName(classID, specID, subTreeID),
                collapsed = heroCollapsed,
                depth = baseDepth,
            }
            if not heroCollapsed then
                appendItems(specBucket.heroes[subTreeID], baseDepth + 1)
            end
        end

        local noHero = specBucket.noHero or {}
        if #noHero > 0 then
            if hasHeroGroups then
                local generalKey = "hero:" .. classID .. ":" .. specID .. ":general"
                local generalCollapsed = self:IsCollapsed(storage, generalKey, true)
                entries[#entries + 1] = {
                    type = "hero",
                    key = generalKey,
                    classID = classID,
                    specID = specID,
                    subTreeID = NO_HERO,
                    label = "General",
                    collapsed = generalCollapsed,
                    depth = baseDepth,
                }
                if not generalCollapsed then
                    appendItems(noHero, baseDepth + 1)
                end
            else
                appendItems(noHero, baseDepth)
            end
        end
    end

    for _, classID in ipairs(classOrder) do
        local bucket = byClass[classID]
        local classKey = "class:" .. classID
        local classCollapsed = self:IsCollapsed(storage, classKey, self:DefaultClassCollapsed(classID, playerClassID))

        entries[#entries + 1] = {
            type = "class",
            key = classKey,
            classID = classID,
            label = self:GetClassName(classID),
            collapsed = classCollapsed,
            depth = 0,
        }

        if not classCollapsed then
            local specOrder = self:GetSpecOrder(classID, bucket.specs, classID == playerClassID and playerSpecID or nil)
            local hasSpecGroups = #specOrder > 0

            for _, specID in ipairs(specOrder) do
                local specBucket = bucket.specs[specID]
                local specKey = "spec:" .. classID .. ":" .. specID
                local specCollapsed = self:IsCollapsed(
                    storage,
                    specKey,
                    self:DefaultSpecCollapsed(classID, specID, playerClassID, playerSpecID)
                )
                local label
                local useClassColor = false
                if groupByHero then
                    label = self:GetClassSpecLabel(classID, specID)
                    useClassColor = true
                else
                    local specName = self:GetSpecName(classID, specID)
                    label = specName
                    if classID == playerClassID then
                        label = self:WrapClassText(classID, self:GetClassName(classID)) .. " " .. specName
                        useClassColor = true
                    end
                end

                local heroOnly = false
                if groupByHero then
                    local heroOrder = self:GetHeroOrder(classID, specID, specBucket.heroes or {}, playerClassID, playerSpecID)
                    heroOnly = #heroOrder > 0 and #(specBucket.noHero or {}) == 0
                end

                if heroOnly then
                    appendHeroGroups(specBucket, classID, specID, 1)
                else
                    entries[#entries + 1] = {
                        type = "spec",
                        key = specKey,
                        classID = classID,
                        specID = specID,
                        label = label,
                        useClassColor = useClassColor,
                        collapsed = specCollapsed,
                        depth = 1,
                    }

                    if not specCollapsed then
                        if groupByHero then
                            appendHeroGroups(specBucket, classID, specID, 2)
                        else
                            appendItems(specBucket.items or {}, 2)
                        end
                    end
                end
            end

            if #bucket.noSpec > 0 then
                if hasSpecGroups then
                    local generalKey = "spec:" .. classID .. ":general"
                    local generalCollapsed = self:IsCollapsed(storage, generalKey, true)
                    entries[#entries + 1] = {
                        type = "spec",
                        key = generalKey,
                        classID = classID,
                        specID = NO_SPEC,
                        label = "General",
                        collapsed = generalCollapsed,
                        depth = 1,
                    }
                    if not generalCollapsed then
                        appendItems(bucket.noSpec, 2)
                    end
                else
                    appendItems(bucket.noSpec, 1)
                end
            end
        end
    end

    if #otherItems > 0 then
        local otherCollapsed = self:IsCollapsed(storage, OTHER_KEY, false)
        entries[#entries + 1] = {
            type = "class",
            key = OTHER_KEY,
            classID = nil,
            label = "Other",
            collapsed = otherCollapsed,
            depth = 0,
        }
        if not otherCollapsed then
            appendItems(otherItems, 1)
        end
    end

    return entries, storage
end
