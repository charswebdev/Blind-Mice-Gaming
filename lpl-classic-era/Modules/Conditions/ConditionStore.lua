local addonName, LPL = ...

LPL.ConditionStore = {}

LPL.ConditionStore.MAX_NAME_LENGTH = 150

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_CONDITION"

local VALID_LINK_TYPES = {
    loadout = true,
    talent = true,
    actionBar = true,
    equipment = true,
    editMode = true,
}

local function GetConditionsData()
    return LPL.DB:GetConditions()
end

function LPL.ConditionStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Condition"
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

function LPL.ConditionStore:EnsureRulesTable()
    local data = GetConditionsData()
    if type(data.rules) ~= "table" then
        data.rules = {}
    end
    if data.nextRuleId == nil then
        data.nextRuleId = 0
    end
    return data.rules
end

function LPL.ConditionStore:GenerateID()
    local data = GetConditionsData()
    data.nextRuleId = (data.nextRuleId or 0) + 1
    return "condition_" .. data.nextRuleId
end

function LPL.ConditionStore:IsMasterEnabled()
    local data = GetConditionsData()
    return data.enabled ~= false
end

function LPL.ConditionStore:SetMasterEnabled(enabled)
    local data = GetConditionsData()
    data.enabled = enabled and true or false
end

function LPL.ConditionStore:GetSettings()
    local data = GetConditionsData()
    return {
        enabled = data.enabled ~= false,
        limitConditions = data.limitConditions == true,
        noSpecSwitch = data.noSpecSwitch == true,
    }
end

function LPL.ConditionStore:SetLimitConditions(enabled)
    local data = GetConditionsData()
    data.limitConditions = enabled and true or false
end

function LPL.ConditionStore:SetNoSpecSwitch(enabled)
    local data = GetConditionsData()
    data.noSpecSwitch = enabled and true or false
end

function LPL.ConditionStore:NormalizeLoadoutIDs(value)
    local out = {}
    local seen = {}
    local function push(id)
        if id == nil or id == "" then
            return
        end
        id = tostring(id)
        if not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    if type(value) == "table" then
        for _, id in ipairs(value) do
            push(id)
        end
    else
        push(value)
    end
    return out
end

function LPL.ConditionStore:LinkKey(linkType, id)
    return tostring(linkType or "") .. ":" .. tostring(id or "")
end

function LPL.ConditionStore:NormalizeLinks(source, legacyLoadoutIDs)
    local out = {}
    local seen = {}
    local function push(linkType, id)
        linkType = tostring(linkType or "")
        id = tostring(id or "")
        if not VALID_LINK_TYPES[linkType] or id == "" then
            return
        end
        local key = self:LinkKey(linkType, id)
        if seen[key] then
            return
        end
        seen[key] = true
        out[#out + 1] = { type = linkType, id = id }
    end

    if type(source) == "table" then
        if #source > 0 then
            for _, link in ipairs(source) do
                if type(link) == "table" then
                    push(link.type, link.id)
                end
            end
        else
            for linkType, ids in pairs(source) do
                if type(ids) == "table" then
                    for _, id in ipairs(ids) do
                        push(linkType, id)
                    end
                end
            end
        end
    end

    for _, id in ipairs(self:NormalizeLoadoutIDs(legacyLoadoutIDs)) do
        push("loadout", id)
    end

    return out
end

function LPL.ConditionStore:LoadoutIDsFromLinks(links)
    local out = {}
    for _, link in ipairs(links or {}) do
        if link.type == "loadout" then
            out[#out + 1] = link.id
        end
    end
    return out
end

function LPL.ConditionStore:GetStoreForLinkType(linkType)
    if linkType == "loadout" then
        return LPL.LoadoutStore
    elseif linkType == "talent" then
        return LPL.TalentStore or LPL.BuildStore
    elseif linkType == "actionBar" then
        return LPL.ActionBarStore
    elseif linkType == "equipment" then
        return LPL.EquipmentStore
    elseif linkType == "editMode" then
        return LPL.EditModeStore
    end
    return nil
end

function LPL.ConditionStore:GetRecord(linkType, id)
    local store = self:GetStoreForLinkType(linkType)
    if not store or not store.Get then
        return nil
    end
    return store:Get(id)
end

function LPL.ConditionStore:GetLinkDisplayName(link)
    if type(link) ~= "table" then
        return "Missing"
    end
    local record = self:GetRecord(link.type, link.id)
    if record and record.name and record.name ~= "" then
        return record.name
    end
    return string.format("%s (%s)", LPL.ConditionDefs:GetLinkLabel(link.type), tostring(link.id))
end

function LPL.ConditionStore:IsRecordValidForPlayer(record)
    if not record then
        return false
    end
    if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(record) then
        return false
    end

    local settings = self:GetSettings()
    if settings.noSpecSwitch then
        local playerSpec = LPL.Character and LPL.Character:GetSpecID()
        local recordSpec = self:GetRecordSpecID(record)
        if playerSpec and recordSpec and tonumber(playerSpec) ~= tonumber(recordSpec) then
            return false
        end
    end
    return true
end

function LPL.ConditionStore:GetRecordSpecID(record)
    if type(record) ~= "table" then
        return nil
    end
    if tonumber(record.specID) then
        return tonumber(record.specID)
    end
    if record.filters and tonumber(record.filters.spec) then
        return tonumber(record.filters.spec)
    end
    if record.restrictions and type(record.restrictions.spec) == "table" then
        local only
        for specID in pairs(record.restrictions.spec) do
            specID = tonumber(specID)
            if specID then
                if only and only ~= specID then
                    return nil
                end
                only = specID
            end
        end
        return only
    end
    -- Loadouts: Classic Era talent builds have no Retail specID.
    if type(record.talentBuildIDs) == "table" and LPL.TalentStore then
        local only
        for _, buildID in ipairs(record.talentBuildIDs) do
            local build = LPL.TalentStore:Get(buildID)
            local specID = build and tonumber(build.specID)
            if specID then
                if only and only ~= specID then
                    return nil
                end
                only = specID
            end
        end
        if only then
            return only
        end
    end
    if record.talentBuildID and LPL.TalentStore then
        local build = LPL.TalentStore:Get(record.talentBuildID)
        return build and tonumber(build.specID) or nil
    end
    return nil
end

function LPL.ConditionStore:ListAvailableLinks(linkTypeFilter)
    local list = {}
    for _, def in ipairs(LPL.ConditionDefs.LINK_TYPES) do
        if not def.filterOnly and (linkTypeFilter == "all" or linkTypeFilter == def.key or not linkTypeFilter) then
            local store = self:GetStoreForLinkType(def.key)
            local items = store and store.GetAll and store:GetAll() or {}
            for _, record in ipairs(items) do
                if record and record.id then
                    local subtitle = nil
                    if LPL.SetRestrictions and LPL.SetRestrictions.GetSummaryLine then
                        subtitle = LPL.SetRestrictions:GetSummaryLine(record.restrictions)
                    end
                    list[#list + 1] = {
                        type = def.key,
                        id = tostring(record.id),
                        name = record.name or tostring(record.id),
                        badge = def.badge,
                        subtitle = subtitle,
                        record = record,
                    }
                end
            end
        end
    end
    table.sort(list, function(a, b)
        if a.type ~= b.type then
            return a.type < b.type
        end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function LPL.ConditionStore:CreateEmptySituations()
    local defs = LPL.ConditionDefs
    return {
        locations = defs:EmptyFlagTable(defs.LOCATIONS),
        difficultyIDs = {},
        movement = defs:EmptyFlagTable(defs.MOVEMENT),
        weather = defs:EmptyFlagTable(defs.WEATHER),
        timeOfDay = defs:EmptyFlagTable(defs.TIME_OF_DAY),
        racialForms = defs:EmptyFlagTable(defs.RACIAL_FORMS),
        equipmentSetIDs = {},
    }
end

function LPL.ConditionStore:NormalizeSituations(source)
    local defs = LPL.ConditionDefs
    source = type(source) == "table" and source or {}
    local situations = self:CreateEmptySituations()
    situations.locations = defs:NormalizeFlagTable(source.locations, defs.LOCATIONS)
    situations.difficultyIDs = defs:NormalizeDifficultyIDs(source.difficultyIDs)
    situations.movement = defs:NormalizeFlagTable(source.movement, defs.MOVEMENT)
    situations.weather = defs:NormalizeFlagTable(source.weather, defs.WEATHER)
    situations.timeOfDay = defs:NormalizeFlagTable(source.timeOfDay, defs.TIME_OF_DAY)
    situations.racialForms = defs:NormalizeFlagTable(source.racialForms, defs.RACIAL_FORMS)
    situations.equipmentSetIDs = self:NormalizeLoadoutIDs(source.equipmentSetIDs)
    return situations
end

function LPL.ConditionStore:NormalizeRule(rule)
    if type(rule) ~= "table" then
        return nil
    end
    rule.id = tostring(rule.id or "")
    if rule.id == "" then
        return nil
    end
    rule.name = self:NormalizeSetName(rule.name, "New Condition")
    rule.enabled = rule.enabled ~= false
    rule.priority = tonumber(rule.priority) or 100
    rule.links = self:NormalizeLinks(rule.links, rule.loadoutIDs)
    rule.loadoutIDs = self:LoadoutIDsFromLinks(rule.links)
    rule.situations = self:NormalizeSituations(rule.situations)
    rule.createdAt = tonumber(rule.createdAt) or time()
    rule.updatedAt = tonumber(rule.updatedAt) or rule.createdAt
    return rule
end

function LPL.ConditionStore:CreateDraftRule(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestRuleName()),
        enabled = true,
        priority = 100,
        links = {},
        loadoutIDs = {},
        situations = self:CreateEmptySituations(),
    }
end

function LPL.ConditionStore:SuggestRuleName()
    return "New Condition"
end

function LPL.ConditionStore:Get(ruleID)
    if not ruleID then
        return nil
    end
    local rules = self:EnsureRulesTable()
    local rule = rules[tostring(ruleID)]
    return rule and self:NormalizeRule(rule) or nil
end

function LPL.ConditionStore:GetAll()
    local rules = self:EnsureRulesTable()
    local list = {}
    for _, rule in pairs(rules) do
        local normalized = self:NormalizeRule(rule)
        if normalized then
            list[#list + 1] = normalized
        end
    end
    table.sort(list, function(a, b)
        if a.priority ~= b.priority then
            return a.priority > b.priority
        end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function LPL.ConditionStore:FindByName(name)
    name = self:NormalizeSetName(name, "")
    if name == "" then
        return nil
    end
    for _, rule in ipairs(self:GetAll()) do
        if rule.name == name then
            return rule
        end
    end
    return nil
end

function LPL.ConditionStore:CommitRule(rule)
    rule = self:NormalizeRule(rule)
    if not rule then
        return false
    end
    local rules = self:EnsureRulesTable()
    rule.updatedAt = time()
    rules[rule.id] = rule
    return true
end

function LPL.ConditionStore:Delete(ruleID)
    if not ruleID then
        return false
    end
    local rules = self:EnsureRulesTable()
    ruleID = tostring(ruleID)
    if not rules[ruleID] then
        return false
    end
    rules[ruleID] = nil
    return true
end

function LPL.ConditionStore:ValidateForSave(draft)
    if type(draft) ~= "table" then
        return false, "Nothing to save."
    end

    local situations = self:NormalizeSituations(draft.situations)
    local defs = LPL.ConditionDefs
    local hasLocation = defs:CountFlags(situations.locations) > 0
    local hasMovement = defs:CountFlags(situations.movement) > 0
    local hasWeather = defs:CountFlags(situations.weather) > 0
    local hasTime = defs:CountFlags(situations.timeOfDay) > 0
    local hasForm = defs:CountFlags(situations.racialForms) > 0
    local hasEquip = #(situations.equipmentSetIDs or {}) > 0

    if not (hasLocation or hasMovement or hasWeather or hasTime or hasForm or hasEquip) then
        return false, "Select at least one situation before saving."
    end

    local links = self:NormalizeLinks(draft.links, draft.loadoutIDs)
    if #links == 0 then
        return false, "Link at least one loadout or build before saving."
    end

    for _, link in ipairs(links) do
        local record = self:GetRecord(link.type, link.id)
        if not record then
            return false, "A linked item no longer exists."
        end
    end

    return true
end

function LPL.ConditionStore:GetSummaryLine(rule)
    rule = self:NormalizeRule(rule)
    if not rule then
        return "Invalid condition"
    end
    local defs = LPL.ConditionDefs
    local parts = defs:SummarizeFlags(rule.situations.locations, defs.LOCATIONS)
    if #rule.situations.difficultyIDs > 0 then
        parts[#parts + 1] = string.format("%d difficulty", #rule.situations.difficultyIDs)
            .. (#rule.situations.difficultyIDs == 1 and "" or "s")
    end
    local move = defs:SummarizeFlags(rule.situations.movement, defs.MOVEMENT)
    for _, label in ipairs(move) do
        parts[#parts + 1] = label
    end
    local linkCount = #(rule.links or {})
    if linkCount > 0 then
        parts[#parts + 1] = string.format("%d link%s", linkCount, linkCount == 1 and "" or "s")
    end
    if #parts == 0 then
        return "No situations set"
    end
    if #parts <= 4 then
        return table.concat(parts, " · ")
    end
    return string.format("%d triggers · %d links", #parts - (linkCount > 0 and 1 or 0), linkCount)
end

function LPL.ConditionStore:SaveFromEditor(ruleID, name, draft, onSaved)
    local ok, err = self:ValidateForSave(draft)
    if not ok then
        print("|cffff6060LPL:|r " .. (err or "Could not save condition."))
        return false
    end

    name = self:NormalizeSetName(name, self:SuggestRuleName())
    draft = draft or {}
    local links = self:NormalizeLinks(draft.links, draft.loadoutIDs)

    if ruleID then
        local rule = self:Get(ruleID)
        if not rule then
            return false
        end
        rule.name = name
        rule.enabled = draft.enabled ~= false
        rule.priority = tonumber(draft.priority) or rule.priority or 100
        rule.links = links
        rule.loadoutIDs = self:LoadoutIDsFromLinks(links)
        rule.situations = self:NormalizeSituations(draft.situations)
        if not self:CommitRule(rule) then
            return false
        end
        if onSaved then
            onSaved(ruleID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved condition \"%s\".", name))
        return true
    end

    local rule = {
        id = self:GenerateID(),
        name = name,
        enabled = draft.enabled ~= false,
        priority = tonumber(draft.priority) or 100,
        links = links,
        loadoutIDs = self:LoadoutIDsFromLinks(links),
        situations = self:NormalizeSituations(draft.situations),
        createdAt = time(),
        updatedAt = time(),
    }
    if not self:CommitRule(rule) then
        return false
    end
    if onSaved then
        onSaved(rule.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Created condition \"%s\".", name))
    return true
end

function LPL.ConditionStore:ConfirmDelete(ruleID, onConfirm)
    local rule = self:Get(ruleID)
    if not rule then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete condition \"%s\"? Linked items are kept. This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.ruleID and LPL.ConditionStore:Delete(data.ruleID) then
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

    StaticPopup_Show(DELETE_DIALOG, rule.name or "Unnamed Condition", nil, {
        ruleID = ruleID,
        onConfirm = onConfirm,
    })
end

--- Linked targets valid for the current player (Limits / Universal).
function LPL.ConditionStore:GetAggregatedFilters(rule)
    rule = self:NormalizeRule(rule)
    local filters = {}
    if not rule then
        return filters
    end

    local function MergeValue(bucket, key, value)
        if value == nil or value == false or value == "" then
            return
        end
        if bucket[key] == nil then
            bucket[key] = value
            return
        end
        if bucket[key] == value or tostring(bucket[key]) == tostring(value) then
            return
        end
        local list = {}
        local seen = {}
        local function push(v)
            local id = tostring(v)
            if not seen[id] then
                seen[id] = true
                list[#list + 1] = v
            end
        end
        if type(bucket[key]) == "table" then
            for _, v in pairs(bucket[key]) do
                push(v)
            end
        else
            push(bucket[key])
        end
        if type(value) == "table" then
            for _, v in pairs(value) do
                push(v)
            end
        else
            push(value)
        end
        if #list == 1 then
            bucket[key] = list[1]
        else
            bucket[key] = list
        end
    end

    for _, link in ipairs(rule.links or {}) do
        local record = self:GetRecord(link.type, link.id)
        if record then
            if LPL.SetRestrictions then
                if link.type == "talent" then
                    LPL.SetRestrictions:UpdateTalentBuildFilters(record)
                else
                    LPL.SetRestrictions:UpdateActionBarSetFilters(record)
                end
            end
            local source = record.filters or {}
            for key, value in pairs(source) do
                MergeValue(filters, key, value)
            end
        end
    end

    return filters
end

--- Linked targets valid for the current player (Limits / Universal).
function LPL.ConditionStore:GetEligibleTargetsForPlayer(rule)
    rule = self:NormalizeRule(rule)
    local eligible = {}
    if not rule then
        return eligible
    end
    for _, link in ipairs(rule.links or {}) do
        local record = self:GetRecord(link.type, link.id)
        if record and self:IsRecordValidForPlayer(record) then
            eligible[#eligible + 1] = {
                type = link.type,
                id = tostring(link.id),
                name = record.name or tostring(link.id),
                badge = LPL.ConditionDefs:GetLinkBadge(link.type),
                record = record,
            }
        end
    end
    return eligible
end

--- Back-compat helper used by older matcher/prompt paths.
function LPL.ConditionStore:GetEligibleLoadoutsForPlayer(rule)
    local eligible = {}
    for _, target in ipairs(self:GetEligibleTargetsForPlayer(rule)) do
        if target.type == "loadout" then
            eligible[#eligible + 1] = target.record
        end
    end
    return eligible
end

function LPL.ConditionStore:ApplyLink(linkType, id)
    if InCombatLockdown and InCombatLockdown() then
        print("|cffff6060LPL:|r Cannot apply in combat.")
        return false
    end

    if linkType == "loadout" then
        if LPL.LoadoutActivate and LPL.LoadoutActivate:IsBusy() then
            print("|cffffcc00LPL:|r A loadout activate is already in progress.")
            return false
        end
        return LPL.LoadoutActivate and LPL.LoadoutActivate:ApplySet(id)
    elseif linkType == "talent" then
        return LPL.TalentActivate and LPL.TalentActivate:ApplyBuild(id)
    elseif linkType == "actionBar" then
        return LPL.ActionBarActivate and LPL.ActionBarActivate:ApplySet(id)
    elseif linkType == "equipment" then
        return LPL.EquipmentActivate and LPL.EquipmentActivate:ApplySet(id)
    elseif linkType == "editMode" then
        return LPL.EditModeActivate and LPL.EditModeActivate:ApplySet(id)
    end

    print("|cffff6060LPL:|r Unknown condition link type.")
    return false
end

function LPL.ConditionStore:ApplyTarget(target)
    if type(target) ~= "table" then
        return false
    end
    return self:ApplyLink(target.type, target.id)
end
