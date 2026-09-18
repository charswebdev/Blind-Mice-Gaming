local addonName, LPL = ...

LPL.AddonSetStore = {}

LPL.AddonSetStore.MAX_NAME_LENGTH = 150
LPL.AddonSetStore.SCOPE_ACCOUNT = "account"
LPL.AddonSetStore.SCOPE_CHARACTER = "character"

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_ADDON_SET"

local function GetAddonSetsData()
    return LPL.DB:GetAddonSets()
end

function LPL.AddonSetStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Addon Set"
    if type(name) ~= "string" then
        return fallback
    end
    name = name:match("^%s*(.-)%s*$") or ""
    if name == "" then
        return fallback
    end
    if #name > self.MAX_NAME_LENGTH then
        name = name:sub(1, self.MAX_NAME_LENGTH)
    end
    return name
end

function LPL.AddonSetStore:NormalizeScope(scope)
    if scope == self.SCOPE_CHARACTER then
        return self.SCOPE_CHARACTER
    end
    return self.SCOPE_ACCOUNT
end

function LPL.AddonSetStore:NormalizeAddonList(addons)
    local list = {}
    local seen = {}
    if type(addons) ~= "table" then
        return list
    end
    for _, name in ipairs(addons) do
        if type(name) == "string" then
            name = name:match("^%s*(.-)%s*$") or ""
            if name ~= "" and not seen[name] then
                seen[name] = true
                list[#list + 1] = name
            end
        end
    end
    table.sort(list)
    return list
end

function LPL.AddonSetStore:EnsureSetsTable()
    local data = GetAddonSetsData()
    if type(data.sets) ~= "table" then
        data.sets = {}
    end
    if data.nextSetId == nil then
        data.nextSetId = 0
    end
    return data.sets
end

function LPL.AddonSetStore:GenerateID()
    local data = GetAddonSetsData()
    data.nextSetId = (data.nextSetId or 0) + 1
    return "addonset_" .. data.nextSetId
end

function LPL.AddonSetStore:SuggestSetName()
    return "New Addon Set"
end

function LPL.AddonSetStore:NormalizeIncludeList(includes, excludeSetID)
    local list = {}
    local seen = {}
    excludeSetID = excludeSetID and tostring(excludeSetID) or nil
    if type(includes) ~= "table" then
        return list
    end
    local function Add(id)
        if type(id) ~= "string" and type(id) ~= "number" then
            return
        end
        id = tostring(id)
        if id == "" or (excludeSetID and id == excludeSetID) or seen[id] then
            return
        end
        seen[id] = true
        list[#list + 1] = id
    end
    for key, value in pairs(includes) do
        if type(key) == "number" then
            Add(value)
        elseif value then
            Add(key)
        end
    end
    table.sort(list)
    return list
end

function LPL.AddonSetStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, self:SuggestSetName())
    set.scope = self:NormalizeScope(set.scope)
    set.addons = self:NormalizeAddonList(set.addons)
    set.includes = self:NormalizeIncludeList(set.includes, set.id)
    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt
    return set
end

function LPL.AddonSetStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        scope = self.SCOPE_ACCOUNT,
        addons = {},
        includes = {},
    }
end

function LPL.AddonSetStore:Get(setID)
    if not setID then
        return nil
    end
    local sets = self:EnsureSetsTable()
    return self:NormalizeSetRecord(sets[tostring(setID)])
end

function LPL.AddonSetStore:GetAll()
    local list = {}
    for _, set in pairs(self:EnsureSetsTable()) do
        local normalized = self:NormalizeSetRecord(set)
        if normalized then
            list[#list + 1] = normalized
        end
    end
    table.sort(list, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function LPL.AddonSetStore:GetSummaryLine(set)
    if type(set) ~= "table" then
        return "Invalid set"
    end
    local scopeLabel = set.scope == self.SCOPE_CHARACTER and "Character" or "Account"
    local count = type(set.addons) == "table" and #set.addons or 0
    local includeCount = type(set.includes) == "table" and #set.includes or 0
    local missing = self:CountMissingAddons(set.addons)
    local parts = {
        string.format("%s · %d addon%s", scopeLabel, count, count == 1 and "" or "s"),
    }
    if includeCount > 0 then
        parts[#parts + 1] = string.format("%d linked", includeCount)
    end
    if missing > 0 then
        parts[#parts + 1] = string.format("%d missing", missing)
    end
    return table.concat(parts, " · ")
end

function LPL.AddonSetStore:GetSummaryWarning(set)
    return self:CountMissingAddons(set and set.addons) > 0
end

function LPL.AddonSetStore:GetCharacterToken()
    if UnitGUID then
        local guid = UnitGUID("player")
        if type(guid) == "string" and guid ~= "" then
            return guid
        end
    end
    return UnitName and UnitName("player") or nil
end

function LPL.AddonSetStore:GetEnableCharacterArg(scope)
    if self:NormalizeScope(scope) == self.SCOPE_CHARACTER then
        return self:GetCharacterToken()
    end
    return nil
end

function LPL.AddonSetStore:IsManagedAddon(indexOrName)
    if not C_AddOns or not C_AddOns.GetAddOnInfo then
        return false
    end
    local name, title, _, _, _, security = C_AddOns.GetAddOnInfo(indexOrName)
    if not name or name == "" then
        return false
    end
    if security == "SECURE" then
        return false
    end
    return true, name, title or name
end

function LPL.AddonSetStore:GetAddonMetadata(name, key)
    if not name or not C_AddOns or not C_AddOns.GetAddOnMetadata then
        return nil
    end
    local ok, value = pcall(C_AddOns.GetAddOnMetadata, name, key)
    if ok and type(value) == "string" and value ~= "" then
        return value
    end
    return nil
end

function LPL.AddonSetStore:GetAddonDependencies(name)
    local deps = {}
    if not name or not C_AddOns or not C_AddOns.GetAddOnDependencies then
        return deps
    end
    local values = { C_AddOns.GetAddOnDependencies(name) }
    for _, dep in ipairs(values) do
        if type(dep) == "string" and dep ~= "" then
            deps[#deps + 1] = dep
        end
    end
    return deps
end

function LPL.AddonSetStore:EnsureProtectedTable()
    local data = GetAddonSetsData()
    if type(data.protected) ~= "table" then
        data.protected = {}
    end
    return data.protected
end

function LPL.AddonSetStore:IsAlwaysProtected(name)
    if type(name) ~= "string" then
        return false
    end
    local folder = (addonName or "lpl"):lower()
    return name:lower() == folder
end

function LPL.AddonSetStore:IsProtected(name)
    if self:IsAlwaysProtected(name) then
        return true
    end
    if type(name) ~= "string" or name == "" then
        return false
    end
    return self:EnsureProtectedTable()[name] == true
end

function LPL.AddonSetStore:SetProtected(name, protected)
    if type(name) ~= "string" or name == "" or self:IsAlwaysProtected(name) then
        return false
    end
    local tableRef = self:EnsureProtectedTable()
    if protected then
        tableRef[name] = true
    else
        tableRef[name] = nil
    end
    return true
end

function LPL.AddonSetStore:ResolveParentName(info, byName)
    if not info or not byName then
        return nil
    end
    if info.group and byName[info.group] and info.group ~= info.name then
        return info.group
    end
    local nameLower = (info.name or ""):lower()
    local titleLower = (info.title or ""):lower()
    local best
    local bestLen = 0
    for _, dep in ipairs(info.deps or {}) do
        local parent = byName[dep]
        if parent and dep ~= info.name then
            local depLower = dep:lower()
            local parentTitle = (parent.title or dep):lower()
            local related = nameLower:sub(1, #depLower) == depLower
                or titleLower:sub(1, #parentTitle) == parentTitle
                or titleLower:find(depLower, 1, true)
            if related and #depLower > bestLen then
                best = dep
                bestLen = #depLower
            elseif #info.deps == 1 and #depLower > bestLen then
                -- Single required dependency: nest as a module of that parent.
                best = dep
                bestLen = #depLower
            end
        end
    end
    if best then
        return best
    end
    for parentName in pairs(byName) do
        if parentName ~= info.name then
            local parentLower = parentName:lower()
            if #parentLower >= 3
                and nameLower:sub(1, #parentLower) == parentLower
                and #parentLower > bestLen then
                local nextChar = nameLower:sub(#parentLower + 1, #parentLower + 1)
                if nextChar == "_" or nextChar == "-" or nextChar == ":" then
                    best = parentName
                    bestLen = #parentLower
                end
            end
        end
    end
    return best
end

function LPL.AddonSetStore:NormalizeIconTexture(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:match("^%s*(.-)%s*$") or ""
    if value == "" then
        return nil
    end
    value = value:gsub("/", "\\")
    return value
end

function LPL.AddonSetStore:GetOwnAddonIcon(info)
    if not info then
        return nil, nil
    end
    return info.ownIconTexture, info.ownIconAtlas
end

function LPL.AddonSetStore:InheritIconFromMainAddon(info, byName)
    if not info or not byName then
        return nil, nil
    end
    if info.ownIconTexture or info.ownIconAtlas then
        return info.ownIconTexture, info.ownIconAtlas
    end

    local function OwnIcon(sourceName)
        local source = sourceName and byName[sourceName]
        if not source then
            return nil, nil
        end
        if source.ownIconTexture or source.ownIconAtlas then
            return source.ownIconTexture, source.ownIconAtlas
        end
        return nil, nil
    end

    -- Sub-addons only: use the main addon's own icon.
    if info.parent then
        local texture, atlas = OwnIcon(info.parent)
        if texture or atlas then
            return texture, atlas
        end
    end
    if info.group then
        local texture, atlas = OwnIcon(info.group)
        if texture or atlas then
            return texture, atlas
        end
    end

    local title = (info.title or ""):lower()
    if title ~= "" then
        local best
        local bestLen = 0
        for _, other in pairs(byName) do
            if other.name ~= info.name and (other.ownIconTexture or other.ownIconAtlas) then
                local otherTitle = (other.title or ""):lower()
                if #otherTitle >= 3 and #otherTitle > bestLen and title:sub(1, #otherTitle) == otherTitle then
                    local nextChar = title:sub(#otherTitle + 1, #otherTitle + 1)
                    if nextChar == " " or nextChar == "-" or nextChar == ":" then
                        best = other
                        bestLen = #otherTitle
                    end
                end
            end
        end
        if best then
            return best.ownIconTexture, best.ownIconAtlas
        end
    end

    return nil, nil
end

function LPL.AddonSetStore:GetInstalledAddons()
    local list = {}
    local byName = {}
    if not C_AddOns or not C_AddOns.GetNumAddOns then
        return list
    end
    local count = C_AddOns.GetNumAddOns() or 0
    for index = 1, count do
        local ok, name, title = self:IsManagedAddon(index)
        if ok then
            local ownTexture = self:NormalizeIconTexture(self:GetAddonMetadata(name, "IconTexture"))
            local ownAtlas = self:GetAddonMetadata(name, "IconAtlas")
            local info = {
                index = index,
                name = name,
                title = title or name,
                category = self:GetAddonMetadata(name, "Category") or "Other",
                group = self:GetAddonMetadata(name, "Group"),
                ownIconTexture = ownTexture,
                ownIconAtlas = ownAtlas,
                iconTexture = ownTexture,
                iconAtlas = ownAtlas,
                deps = self:GetAddonDependencies(name),
            }
            list[#list + 1] = info
            byName[name] = info
        end
    end
    for _, info in ipairs(list) do
        info.parent = self:ResolveParentName(info, byName)
        if info.parent and not byName[info.parent] then
            info.parent = nil
        end
        -- Avoid cycles: child cannot parent its own parent.
        if info.parent and byName[info.parent] and byName[info.parent].parent == info.name then
            info.parent = nil
        end
    end
    for _, info in ipairs(list) do
        if not info.ownIconTexture and not info.ownIconAtlas then
            local texture, atlas = self:InheritIconFromMainAddon(info, byName)
            info.iconTexture = texture
            info.iconAtlas = atlas
        end
    end
    table.sort(list, function(a, b)
        local ca, cb = a.category or "Other", b.category or "Other"
        if ca ~= cb then
            return ca < cb
        end
        return (a.title or a.name or "") < (b.title or b.name or "")
    end)
    return list
end

function LPL.AddonSetStore:BuildDisplayEntries(options)
    options = options or {}
    local query = type(options.query) == "string" and options.query:lower() or ""
    local selectedOnly = options.selectedOnly == true
    local selectedMap = options.selectedMap or {}
    local collapsed = options.collapsed or {}
    local installed = self:GetInstalledAddons()
    local byName = {}
    for _, info in ipairs(installed) do
        byName[info.name] = info
    end

    local function MatchesFilter(info)
        local selected = selectedMap[info.name] == true
        if selectedOnly and not selected then
            return false
        end
        if query == "" then
            return true
        end
        return (info.title and info.title:lower():find(query, 1, true))
            or (info.name and info.name:lower():find(query, 1, true))
            or (info.category and info.category:lower():find(query, 1, true))
    end

    local children = {}
    local rootsByCategory = {}
    for _, info in ipairs(installed) do
        if info.parent and byName[info.parent] then
            children[info.parent] = children[info.parent] or {}
            children[info.parent][#children[info.parent] + 1] = info
        else
            local category = info.category or "Other"
            rootsByCategory[category] = rootsByCategory[category] or {}
            rootsByCategory[category][#rootsByCategory[category] + 1] = info
        end
    end

    for _, kids in pairs(children) do
        table.sort(kids, function(a, b)
            return (a.title or a.name) < (b.title or b.name)
        end)
    end

    local function HasVisibleDescendant(info)
        local kids = children[info.name]
        if not kids then
            return false
        end
        for _, child in ipairs(kids) do
            if MatchesFilter(child) or HasVisibleDescendant(child) then
                return true
            end
        end
        return false
    end

    local function ShouldShow(info)
        return MatchesFilter(info) or HasVisibleDescendant(info)
    end

    local categories = {}
    for category in pairs(rootsByCategory) do
        categories[#categories + 1] = category
    end
    table.sort(categories)

    local entries = {}
    local function PushAddon(info, depth)
        if not ShouldShow(info) then
            return
        end
        entries[#entries + 1] = {
            kind = "addon",
            depth = depth or 0,
            info = info,
        }
        local kids = children[info.name]
        if kids then
            for _, child in ipairs(kids) do
                PushAddon(child, (depth or 0) + 1)
            end
        end
    end

    for _, category in ipairs(categories) do
        local roots = rootsByCategory[category]
        table.sort(roots, function(a, b)
            return (a.title or a.name) < (b.title or b.name)
        end)

        local visibleRoots = {}
        for _, root in ipairs(roots) do
            if ShouldShow(root) then
                visibleRoots[#visibleRoots + 1] = root
            end
        end

        if #visibleRoots > 0 then
            local categoryKey = category
            entries[#entries + 1] = {
                kind = "header",
                category = category,
                categoryKey = categoryKey,
                collapsed = collapsed[categoryKey] == true,
            }
            if not collapsed[categoryKey] then
                for _, root in ipairs(visibleRoots) do
                    PushAddon(root, 0)
                end
            end
        end
    end

    if options.draftAddons then
        local missing = {}
        for _, name in ipairs(options.draftAddons) do
            if type(name) == "string" and name ~= "" and not byName[name] then
                local selected = selectedMap[name] == true
                if (not selectedOnly or selected)
                    and (query == "" or name:lower():find(query, 1, true)) then
                    missing[#missing + 1] = {
                        name = name,
                        title = name .. " (missing)",
                        missing = true,
                        category = "Missing",
                    }
                end
            end
        end
        if #missing > 0 then
            table.sort(missing, function(a, b)
                return (a.title or a.name) < (b.title or b.name)
            end)
            local categoryKey = "Missing"
            entries[#entries + 1] = {
                kind = "header",
                category = "Missing",
                categoryKey = categoryKey,
                collapsed = collapsed[categoryKey] == true,
            }
            if not collapsed[categoryKey] then
                for _, info in ipairs(missing) do
                    entries[#entries + 1] = {
                        kind = "addon",
                        depth = 0,
                        info = info,
                    }
                end
            end
        end
    end

    return entries
end

function LPL.AddonSetStore:IsAddonEnabledLive(name, scope)
    if not name or not C_AddOns or not C_AddOns.GetAddOnEnableState then
        return false
    end
    local character = self:GetEnableCharacterArg(scope)
    local state = C_AddOns.GetAddOnEnableState(name, character)
    return (tonumber(state) or 0) > 0
end

function LPL.AddonSetStore:CaptureLiveEnabledAddons(scope)
    local list = {}
    local installed = self:GetInstalledAddons()
    for _, info in ipairs(installed) do
        if self:IsAddonEnabledLive(info.name, scope) then
            list[#list + 1] = info.name
        end
    end
    return self:NormalizeAddonList(list)
end

function LPL.AddonSetStore:BuildMembershipMap(addons)
    local map = {}
    if type(addons) ~= "table" then
        return map
    end
    for _, name in ipairs(addons) do
        if type(name) == "string" and name ~= "" then
            map[name] = true
        end
    end
    return map
end

function LPL.AddonSetStore:SetMembership(addons, addonName, enabled)
    local map = self:BuildMembershipMap(addons)
    if enabled then
        map[addonName] = true
    else
        map[addonName] = nil
    end
    local list = {}
    for name in pairs(map) do
        list[#list + 1] = name
    end
    return self:NormalizeAddonList(list)
end

function LPL.AddonSetStore:BuildIncludeMap(includes)
    local map = {}
    for _, id in ipairs(self:NormalizeIncludeList(includes)) do
        map[id] = true
    end
    return map
end

function LPL.AddonSetStore:SetInclude(includes, setID, enabled)
    local map = self:BuildIncludeMap(includes)
    setID = setID and tostring(setID) or nil
    if not setID or setID == "" then
        return self:NormalizeIncludeList(includes)
    end
    if enabled then
        map[setID] = true
    else
        map[setID] = nil
    end
    return self:NormalizeIncludeList(map)
end

function LPL.AddonSetStore:GetIncludableSets(excludeSetID)
    local list = {}
    excludeSetID = excludeSetID and tostring(excludeSetID) or nil
    for _, set in ipairs(self:GetAll()) do
        if not excludeSetID or set.id ~= excludeSetID then
            list[#list + 1] = set
        end
    end
    return list
end

function LPL.AddonSetStore:CollectExpandedSets(setIDs)
    local result = {}
    local seen = {}

    local function Visit(setID)
        setID = setID and tostring(setID) or nil
        if not setID or setID == "" or seen[setID] then
            return
        end
        seen[setID] = true
        local set = self:Get(setID)
        if not set then
            return
        end
        result[#result + 1] = set
        for _, includedID in ipairs(set.includes or {}) do
            Visit(includedID)
        end
    end

    if type(setIDs) == "table" then
        for _, setID in ipairs(setIDs) do
            Visit(setID)
        end
    end
    return result
end

function LPL.AddonSetStore:CountMissingAddons(addons)
    local missing = 0
    if type(addons) ~= "table" or not C_AddOns or not C_AddOns.DoesAddOnExist then
        return 0
    end
    for _, name in ipairs(addons) do
        if type(name) == "string" and name ~= "" and not C_AddOns.DoesAddOnExist(name) then
            missing = missing + 1
        end
    end
    return missing
end

function LPL.AddonSetStore:GetEditorStatusLine(draft)
    if type(draft) ~= "table" then
        return "No draft."
    end
    local scopeLabel = draft.scope == self.SCOPE_CHARACTER and "Character" or "Account"
    local count = type(draft.addons) == "table" and #draft.addons or 0
    local includeCount = type(draft.includes) == "table" and #draft.includes or 0
    local missing = self:CountMissingAddons(draft.addons)
    local parts = { string.format("%s · %d addon%s selected", scopeLabel, count, count == 1 and "" or "s") }
    if includeCount > 0 then
        parts[#parts + 1] = string.format("%d linked set%s", includeCount, includeCount == 1 and "" or "s")
    end
    if missing > 0 then
        parts[#parts + 1] = string.format("%d missing from this install", missing)
    end
    return table.concat(parts, " · ")
end

function LPL.AddonSetStore:FindByName(name)
    name = self:NormalizeSetName(name, ""):lower()
    if name == "" then
        return nil
    end
    for _, set in pairs(self:EnsureSetsTable()) do
        if type(set) == "table" and (set.name or ""):lower() == name then
            return self:NormalizeSetRecord(set)
        end
    end
    return nil
end

function LPL.AddonSetStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end
    local includeIDs = {}
    if LPL.AddonSetShare and LPL.AddonSetShare.IncludeIDsFromNames then
        includeIDs = LPL.AddonSetShare.IncludeIDsFromNames(importData.includeNames or importData.includes)
    end
    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, importData.name or "Imported Addon Set"),
        scope = self:NormalizeScope(importData.scope),
        addons = self:NormalizeAddonList(importData.addons),
        includes = self:NormalizeIncludeList(includeIDs),
        createdAt = now,
        updatedAt = now,
    }
    if not self:CommitSet(set) then
        return nil
    end
    return set
end

function LPL.AddonSetStore:ApplyImport(importData, setName, options)
    if type(importData) ~= "table" or type(options) ~= "table" or options.addonSets ~= true then
        return nil
    end
    setName = self:NormalizeSetName(setName, importData.name or "Imported Addon Set")
    local includeIDs = {}
    if LPL.AddonSetShare and LPL.AddonSetShare.IncludeIDsFromNames then
        includeIDs = LPL.AddonSetShare.IncludeIDsFromNames(importData.includeNames or importData.includes)
    end
    local existing = options.existingAddonSetID and self:Get(options.existingAddonSetID)
        or self:FindByName(setName)
    if existing then
        existing.name = setName
        existing.scope = self:NormalizeScope(importData.scope)
        existing.addons = self:NormalizeAddonList(importData.addons)
        existing.includes = self:NormalizeIncludeList(includeIDs, existing.id)
        existing.updatedAt = time()
        if not self:CommitSet(existing) then
            return nil
        end
        return existing
    end
    return self:CreateFromImport(importData, setName)
end

function LPL.AddonSetStore:CommitSet(set)
    set = self:NormalizeSetRecord(set)
    if not set then
        return false
    end
    local sets = self:EnsureSetsTable()
    set.updatedAt = time()
    sets[set.id] = set
    return true
end

function LPL.AddonSetStore:Delete(setID)
    if not setID then
        return false
    end
    local sets = self:EnsureSetsTable()
    setID = tostring(setID)
    if not sets[setID] then
        return false
    end
    sets[setID] = nil
    for _, set in pairs(sets) do
        if type(set) == "table" and type(set.includes) == "table" then
            set.includes = self:NormalizeIncludeList(set.includes, setID)
        end
    end
    return true
end

function LPL.AddonSetStore:ValidateForSave(draft)
    if type(draft) ~= "table" then
        return false, "Nothing to save."
    end
    local name = self:NormalizeSetName(draft.name, "")
    if name == "" then
        return false, "Enter a set name before saving."
    end
    return true
end

function LPL.AddonSetStore:SaveFromEditor(setID, name, draft, onSaved)
    draft = draft or {}
    draft.name = name
    local ok, err = self:ValidateForSave(draft)
    if not ok then
        print("|cffff6060LPL:|r " .. (err or "Could not save addon set."))
        return false
    end

    name = self:NormalizeSetName(name, self:SuggestSetName())
    local scope = self:NormalizeScope(draft.scope)
    local addons = self:NormalizeAddonList(draft.addons)
    local includes = self:NormalizeIncludeList(draft.includes, setID)

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.scope = scope
        set.addons = addons
        set.includes = includes
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved addon set \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        scope = scope,
        addons = addons,
        includes = self:NormalizeIncludeList(draft.includes),
        createdAt = time(),
        updatedAt = time(),
    }
    if not self:CommitSet(set) then
        return false
    end
    if onSaved then
        onSaved(set.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Created addon set \"%s\".", name))
    return true
end

function LPL.AddonSetStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete addon set \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.AddonSetStore:Delete(data.setID) then
                    if data.onConfirm then
                        data.onConfirm()
                    end
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show(DELETE_DIALOG, set.name or "Unnamed Set", nil, {
        setID = setID,
        onConfirm = onConfirm,
    })
end
