local addonName, LPL = ...

LPL.SetRestrictions = {}

-- Full list-filter set used by vault tabs (Classic Era — no hero / covenant).
LPL.SetRestrictions.ALL_LIST_FILTERS = {
    "character",
    "class",
    "spec",
    "role",
    "race",
}

-- Limits menu types (role is filter-only; derived from specs).
LPL.SetRestrictions.ALL_RESTRICTION_TYPES = {
    "character",
    "class",
    "spec",
    "race",
}

-- Playable race IDs (same set LightPawsLoadouts uses).
LPL.SetRestrictions.RACE_IDS = {
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 22, 25, 26, 27, 28, 29, 30, 31, 32, 34, 35, 36, 37, 52, 70, 84, 85,
}

local COVENANT_FALLBACKS = {
    { id = 1, name = "Kyrian", kit = "Kyrian" },
    { id = 2, name = "Venthyr", kit = "Venthyr" },
    { id = 3, name = "Night Fae", kit = "NightFae" },
    { id = 4, name = "Necrolord", kit = "Necrolord" },
}

local function ContainsOrMatches(setValue, filterValue)
    if setValue == nil then
        return true
    end
    if type(setValue) == "table" then
        if setValue[filterValue] then
            return true
        end
        for _, value in pairs(setValue) do
            if value == filterValue or tostring(value) == tostring(filterValue) then
                return true
            end
        end
        return false
    end
    return setValue == filterValue or tostring(setValue) == tostring(filterValue)
end

function LPL.SetRestrictions:NormalizeRestrictions(restrictions)
    if type(restrictions) ~= "table" then
        return {}
    end
    local copy = {}
    for key, value in pairs(restrictions) do
        if key == "class" and type(value) == "string" then
            copy.class = { [value] = true }
        elseif type(value) == "table" then
            local bucket = {}
            for id, enabled in pairs(value) do
                if enabled then
                    bucket[tonumber(id) or id] = true
                end
            end
            if next(bucket) then
                copy[key] = bucket
            end
        elseif value ~= nil and value ~= false and value ~= "" then
            copy[key] = value
        end
    end
    return copy
end

function LPL.SetRestrictions:CopyRestrictions(restrictions)
    return self:NormalizeRestrictions(restrictions)
end

local function ClassRestrictionMatches(classBucket, classFile, classID)
    if type(classBucket) == "string" then
        classBucket = { [classBucket] = true }
    end
    if type(classBucket) ~= "table" or not next(classBucket) then
        return true
    end
    if classFile and classBucket[classFile] then
        return true
    end
    if type(classFile) == "string" then
        local upper = classFile:upper()
        if classBucket[upper] then
            return true
        end
        for key in pairs(classBucket) do
            if type(key) == "string" and key:upper() == upper then
                return true
            end
        end
    end
    if classID then
        if classBucket[classID] then
            return true
        end
        local classFileForID = LPL.SetRestrictions:GetClassFileForClassID(classID)
        if classFileForID and classBucket[classFileForID] then
            return true
        end
        for key in pairs(classBucket) do
            local restrictedClassID = tonumber(key)
            if restrictedClassID and restrictedClassID == classID then
                return true
            end
            local restrictedFile = type(key) == "string" and key or nil
            if restrictedFile and classFile and restrictedFile == classFile then
                return true
            end
            if restrictedFile then
                local restrictedID = LPL.SetRestrictions:GetClassIDForClassFile(restrictedFile)
                if restrictedID and classID and restrictedID == classID then
                    return true
                end
            end
        end
    end
    return false
end

local function BucketRestrictionMatches(bucket, playerValue)
    if type(bucket) ~= "table" or not next(bucket) then
        return true
    end
    if playerValue == nil then
        return false
    end
    if bucket[playerValue] then
        return true
    end
    local numericValue = tonumber(playerValue)
    if numericValue and bucket[numericValue] then
        return true
    end
    for key in pairs(bucket) do
        if tostring(key) == tostring(playerValue) then
            return true
        end
    end
    return false
end

function LPL.SetRestrictions:AreValidForPlayer(restrictions)
    restrictions = self:NormalizeRestrictions(restrictions)
    if not next(restrictions) then
        return true
    end

    local character = LPL.Character
    if restrictions.character and type(restrictions.character) == "string" then
        local slug = character:GetSlug()
        if not slug or slug ~= restrictions.character then
            return false
        end
    end

    if restrictions.class then
        local classFile = character:GetClassFile()
        local classID = character:GetClassID()
        if not ClassRestrictionMatches(restrictions.class, classFile, classID) then
            return false
        end
    end

    if restrictions.spec and not BucketRestrictionMatches(restrictions.spec, character:GetSpecID()) then
        return false
    end

    if restrictions.race and not BucketRestrictionMatches(restrictions.race, character:GetRaceID()) then
        return false
    end

    return true
end

function LPL.SetRestrictions:AreValidForPlayerRecord(record)
    if type(record) ~= "table" then
        return true
    end

    local restrictions = self:CopyRestrictions(record.restrictions)
    if not restrictions.class and record.filters and record.filters.class then
        local classFilter = record.filters.class
        if type(classFilter) == "string" then
            restrictions.class = { [classFilter] = true }
        elseif type(classFilter) == "table" then
            restrictions.class = {}
            for _, classFile in ipairs(classFilter) do
                restrictions.class[classFile] = true
            end
            for classFile in pairs(classFilter) do
                restrictions.class[classFile] = true
            end
        end
    end

    return self:AreValidForPlayer(restrictions)
end

function LPL.SetRestrictions:GetSummaryLine(restrictions)
    restrictions = self:NormalizeRestrictions(restrictions)
    if not next(restrictions) then
        return nil
    end

    local parts = {}

    if restrictions.character and type(restrictions.character) == "string" then
        local slug = restrictions.character
        parts[#parts + 1] = slug:match("%-(.+)$") or slug
    end

    if restrictions.class then
        local classBucket = restrictions.class
        if type(classBucket) == "string" then
            classBucket = { [classBucket] = true }
        end
        if type(classBucket) == "table" then
            for classFile in pairs(classBucket) do
                local className = tostring(classFile)
                if LPL.TalentTree and LPL.TalentTree.GetClasses then
                    for _, class in ipairs(LPL.TalentTree:GetClasses()) do
                        if class.file == classFile or class.id == classFile or tonumber(classFile) == class.id then
                            className = class.name or class.file
                            break
                        end
                    end
                end
                parts[#parts + 1] = className
            end
        end
    end

    if restrictions.spec and type(restrictions.spec) == "table" then
        for specID in pairs(restrictions.spec) do
            specID = tonumber(specID)
            local specName = tostring(specID)
            if specID and LPL.TalentTree and LPL.TalentTree.GetClasses and LPL.TalentTree.GetSpecsForClass then
                for _, class in ipairs(LPL.TalentTree:GetClasses()) do
                    for _, spec in ipairs(LPL.TalentTree:GetSpecsForClass(class.id)) do
                        if spec.id == specID then
                            local className = class.name or class.file
                            specName = className .. " - " .. (spec.name or specID)
                            break
                        end
                    end
                end
            end
            parts[#parts + 1] = specName
        end
    end

    if restrictions.herotalents and type(restrictions.herotalents) == "table"
        and LPL.FlavorCompat and LPL.FlavorCompat.hasHeroTalents then
        for heroID in pairs(restrictions.herotalents) do
            heroID = tonumber(heroID)
            local heroName = "Hero " .. tostring(heroID)
            if heroID and LPL.TalentTree and LPL.TalentTree.GetClasses and LPL.TalentTree.GetHeroTalentsForSpec then
                for _, class in ipairs(LPL.TalentTree:GetClasses()) do
                    for _, spec in ipairs(LPL.TalentTree:GetSpecsForClass(class.id)) do
                        for _, hero in ipairs(LPL.TalentTree:GetHeroTalentsForSpec(spec.id)) do
                            if hero.id == heroID then
                                heroName = hero.name or heroName
                                break
                            end
                        end
                    end
                end
            end
            parts[#parts + 1] = heroName
        end
    end

    if restrictions.race and type(restrictions.race) == "table" then
        for raceID in pairs(restrictions.race) do
            raceID = tonumber(raceID)
            local raceName = "Race " .. tostring(raceID)
            if raceID and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
                local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)
                if raceInfo and raceInfo.raceName then
                    raceName = raceInfo.raceName
                end
            end
            parts[#parts + 1] = raceName
        end
    end

    if restrictions.covenant and type(restrictions.covenant) == "table"
        and LPL.FlavorCompat and LPL.FlavorCompat.hasCovenant then
        for covenantID in pairs(restrictions.covenant) do
            covenantID = tonumber(covenantID)
            local covenantName = "Covenant " .. tostring(covenantID)
            if covenantID and C_Covenants and C_Covenants.GetCovenantData then
                local data = C_Covenants.GetCovenantData(covenantID)
                if data and data.name then
                    covenantName = data.name
                end
            end
            parts[#parts + 1] = covenantName
        end
    end

    table.sort(parts)
    if #parts == 0 then
        return "Restricted"
    end
    return table.concat(parts, ", ")
end

function LPL.SetRestrictions:FiltersMatch(activeFilters, setFilters)
    if type(activeFilters) ~= "table" or not next(activeFilters) then
        return true
    end
    setFilters = setFilters or {}
    for filterKey, filterValue in pairs(activeFilters) do
        if filterKey == "characterOnly" then
            if filterValue then
                local slug = LPL.Character:GetSlug()
                if not slug then
                    return true
                end
                local chars = setFilters.character
                if not chars then
                    return true
                end
                if not ContainsOrMatches(chars, slug) then
                    return false
                end
            end
        elseif filterValue ~= nil and filterValue ~= false and filterValue ~= "" then
            if not ContainsOrMatches(setFilters[filterKey], filterValue) then
                return false
            end
        end
    end
    return true
end

function LPL.SetRestrictions:GetClassFileForClassID(classID)
    classID = tonumber(classID)
    if not classID or not LPL.TalentTree or not LPL.TalentTree.GetClasses then
        return nil
    end
    for _, class in ipairs(LPL.TalentTree:GetClasses()) do
        if class.id == classID then
            return class.file
        end
    end
    return nil
end

function LPL.SetRestrictions:GetClassIDForClassFile(classFile)
    if type(classFile) ~= "string" or classFile == "" then
        return nil
    end
    if not LPL.TalentTree or not LPL.TalentTree.GetClasses then
        return nil
    end
    for _, class in ipairs(LPL.TalentTree:GetClasses()) do
        if class.file == classFile then
            return class.id
        end
    end
    return nil
end

function LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
    if type(set) ~= "table" then
        return nil
    end

    local restrictions = self:NormalizeRestrictions(set.restrictions)
    if not next(restrictions) then
        return nil
    end

    if restrictions.class and type(restrictions.class) == "table" then
        for classFile in pairs(restrictions.class) do
            return self:GetClassIDForClassFile(classFile)
        end
    end

    if restrictions.spec and type(restrictions.spec) == "table" and LPL.TalentTree and LPL.TalentTree.GetClassIDForSpec then
        local inferred
        for specID in pairs(restrictions.spec) do
            local specClassID = LPL.TalentTree:GetClassIDForSpec(specID)
            if specClassID then
                if inferred and inferred ~= specClassID then
                    return nil
                end
                inferred = specClassID
            end
        end
        if inferred then
            return inferred
        end
    end

    -- Only trust stored classID when Limits are present (legacy / editor drafts).
    return tonumber(set.classID)
end

function LPL.SetRestrictions:UpdateTalentBuildFilters(build)
    if type(build) ~= "table" then
        return
    end

    local filters = {}
    local classFile = self:GetClassFileForClassID(build.classID)
    if classFile then
        filters.class = classFile
    end
    if build.specID then
        filters.spec = build.specID
    end
    if build.subTreeID then
        filters.herotalents = build.subTreeID
    end

    local restrictions = self:NormalizeRestrictions(build.restrictions)
    if restrictions.character and type(restrictions.character) == "string" then
        filters.character = { restrictions.character }
    end

    for key, value in pairs(restrictions) do
        if type(value) == "table" then
            local list = {}
            for id in pairs(value) do
                list[#list + 1] = id
            end
            if #list == 1 then
                filters[key] = list[1]
            elseif #list > 1 then
                filters[key] = list
            end
        end
    end

    if filters.spec then
        self:AppendRoleFilter(filters, filters.spec)
    elseif build.specID then
        self:AppendRoleFilter(filters, build.specID)
    end

    build.filters = filters
end

function LPL.SetRestrictions:UpdateActionBarSetFilters(set)
    if type(set) ~= "table" then
        return
    end

    local filters = {}
    local restrictions = self:NormalizeRestrictions(set.restrictions)

    if restrictions.character and type(restrictions.character) == "string" then
        filters.character = { restrictions.character }
    end

    local classID = self:GetEffectiveActionBarClassID(set)
    local classFile = self:GetClassFileForClassID(classID)
    if classFile then
        filters.class = classFile
    end

    if restrictions.spec and type(restrictions.spec) == "table" then
        for specID in pairs(restrictions.spec) do
            filters.spec = specID
            break
        end
    end

    if restrictions.herotalents and type(restrictions.herotalents) == "table"
        and LPL.FlavorCompat and LPL.FlavorCompat.hasHeroTalents then
        for heroID in pairs(restrictions.herotalents) do
            filters.herotalents = heroID
            break
        end
    end

    if restrictions.race and type(restrictions.race) == "table" then
        local list = {}
        for raceID in pairs(restrictions.race) do
            list[#list + 1] = raceID
        end
        if #list == 1 then
            filters.race = list[1]
        elseif #list > 1 then
            filters.race = list
        end
    end

    if restrictions.covenant and type(restrictions.covenant) == "table"
        and LPL.FlavorCompat and LPL.FlavorCompat.hasCovenant then
        local list = {}
        for covenantID in pairs(restrictions.covenant) do
            list[#list + 1] = covenantID
        end
        if #list == 1 then
            filters.covenant = list[1]
        elseif #list > 1 then
            filters.covenant = list
        end
    end

    if filters.spec then
        self:AppendRoleFilter(filters, filters.spec)
    end

    set.filters = filters
end

function LPL.SetRestrictions:GetEffectiveEquipmentClassID(set)
    return self:GetEffectiveActionBarClassID(set)
end

function LPL.SetRestrictions:UpdateEquipmentSetFilters(set)
    return self:UpdateActionBarSetFilters(set)
end

function LPL.SetRestrictions:GetFilterStorage(listKey)
    LPL.DB:SyncFromGlobal()
    LPLClassicEraDB.listFilters = LPLClassicEraDB.listFilters or {}
    LPLClassicEraDB.listFilters[listKey] = LPLClassicEraDB.listFilters[listKey] or {}
    return LPLClassicEraDB.listFilters[listKey]
end

function LPL.SetRestrictions:GetClassFilterOptions()
    local options = {}
    if LPL.TalentTree and LPL.TalentTree.GetClasses then
        for _, class in ipairs(LPL.TalentTree:GetClasses()) do
            local name = class.name or class.file
            options[#options + 1] = {
                id = class.file,
                label = LPL.Theme:WrapClassFileText(class.file, name),
            }
        end
    end
    if #options == 0 and GetNumClasses and GetClassInfo then
        for classID = 1, GetNumClasses() do
            local className, classFile = GetClassInfo(classID)
            if classFile then
                options[#options + 1] = {
                    id = classFile,
                    label = LPL.Theme:WrapClassFileText(classFile, className or classFile),
                }
            end
        end
    end
    return options
end

function LPL.SetRestrictions:GetSpecFilterOptions(classFile)
    local options = {}
    if LPL.TalentTree and LPL.TalentTree.GetClasses and LPL.TalentTree.GetSpecsForClass then
        for _, class in ipairs(LPL.TalentTree:GetClasses()) do
            if not classFile or class.file == classFile then
                for _, spec in ipairs(LPL.TalentTree:GetSpecsForClass(class.id)) do
                    local specName = spec.name or tostring(spec.id)
                    local label
                    if classFile then
                        label = LPL.Theme:WrapClassFileText(class.file, specName)
                    else
                        local className = class.name or class.file
                        label = LPL.Theme:WrapClassFileText(class.file, className) .. " - " .. specName
                    end
                    options[#options + 1] = {
                        id = spec.id,
                        label = label,
                    }
                end
                if classFile then
                    break
                end
            end
        end
    end
    return options
end

function LPL.SetRestrictions:GetRaceFilterOptions()
    local options = {}
    for _, raceID in ipairs(self.RACE_IDS) do
        local raceName
        if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
            local raceInfo = C_CreatureInfo.GetRaceInfo(raceID)
            raceName = raceInfo and raceInfo.raceName
        end
        raceName = raceName or ("Race " .. raceID)
        options[#options + 1] = {
            id = raceID,
            sortName = raceName,
            label = LPL.Theme:WrapRaceText(raceID, raceName),
        }
    end
    table.sort(options, function(a, b)
        return a.sortName < b.sortName
    end)
    return options
end

function LPL.SetRestrictions:GetCovenantFilterOptions()
    local options = {}
    for _, fallback in ipairs(COVENANT_FALLBACKS) do
        local name = fallback.name
        local kit = fallback.kit
        if C_Covenants and C_Covenants.GetCovenantData then
            local data = C_Covenants.GetCovenantData(fallback.id)
            if data then
                name = data.name or name
                kit = data.textureKit or kit
            end
        end
        local label = name
        if kit and COVENANT_COLORS and COVENANT_COLORS[kit] and COVENANT_COLORS[kit].WrapTextInColorCode then
            label = COVENANT_COLORS[kit]:WrapTextInColorCode(name)
        elseif LPL.Theme and LPL.Theme.WrapCovenantText then
            label = LPL.Theme:WrapCovenantText(fallback.id, name)
        end
        options[#options + 1] = {
            id = fallback.id,
            sortName = name,
            label = label,
        }
    end
    table.sort(options, function(a, b)
        return a.sortName < b.sortName
    end)
    return options
end

function LPL.SetRestrictions:GetRoleFilterOptions()
    return {
        { id = "TANK", label = _G.TANK or "Tank" },
        { id = "HEALER", label = _G.HEALER or "Healer" },
        { id = "DAMAGER", label = _G.DAMAGER or "Damage" },
    }
end

local function RoleForSpecID(specID)
    specID = tonumber(specID)
    if not specID or not GetSpecializationInfoByID then
        return nil
    end
    return select(5, GetSpecializationInfoByID(specID))
end

function LPL.SetRestrictions:AppendRoleFilter(filters, specValue)
    if not filters then
        return
    end
    local roles = {}
    local function consider(specID)
        local role = RoleForSpecID(specID)
        if role then
            roles[role] = true
        end
    end
    if type(specValue) == "table" then
        for _, specID in pairs(specValue) do
            consider(specID)
        end
        for specID in pairs(specValue) do
            if type(specID) ~= "boolean" then
                consider(specID)
            end
        end
    else
        consider(specValue)
    end
    local list = {}
    for role in pairs(roles) do
        list[#list + 1] = role
    end
    if #list == 1 then
        filters.role = list[1]
    elseif #list > 1 then
        filters.role = list
    end
end
