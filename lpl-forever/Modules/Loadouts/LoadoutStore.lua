local addonName, LPL = ...

LPL.LoadoutStore = {}

LPL.LoadoutStore.MAX_NAME_LENGTH = 150

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_LOADOUT"

local SEGMENT_DEFS = {
    { singular = "talentBuildID", plural = "talentBuildIDs", label = "Talents" },
    { singular = "actionBarSetID", plural = "actionBarSetIDs", label = "Action Bars" },
    { singular = "keybindSetID", plural = "keybindSetIDs", label = "Keybinds" },
    { singular = "equipmentSetID", plural = "equipmentSetIDs", label = "Equipment" },
    { singular = "pvpTalentSetID", plural = "pvpTalentSetIDs", label = "PvP" },
    { singular = "cooldownManagerSetID", plural = "cooldownManagerSetIDs", label = "Cooldown Manager" },
    { singular = "editModeSetID", plural = "editModeSetIDs", label = "Edit Mode" },
    { singular = "addonSetID", plural = "addonSetIDs", label = "Addon Sets" },
}

-- Legacy singular list kept for older call sites.
local SEGMENT_FIELDS = {}
for _, def in ipairs(SEGMENT_DEFS) do
    SEGMENT_FIELDS[#SEGMENT_FIELDS + 1] = def.singular
end

LPL.LoadoutStore.SEGMENT_DEFS = SEGMENT_DEFS

local function GetLoadoutsData()
    return LPL.DB:GetLoadouts()
end

local function NormalizeSegmentID(value)
    if value == nil or value == "" then
        return nil
    end
    return tostring(value)
end

local function NormalizeSegmentIDs(value)
    local out = {}
    local seen = {}
    local function push(entry)
        local id = NormalizeSegmentID(entry)
        if id and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    if type(value) == "table" then
        for _, entry in ipairs(value) do
            push(entry)
        end
    else
        push(value)
    end
    return out
end

function LPL.LoadoutStore:NormalizeSegmentIDs(value)
    return NormalizeSegmentIDs(value)
end

function LPL.LoadoutStore:GetSegmentIDs(set, pluralField)
    if type(set) ~= "table" or type(pluralField) ~= "string" then
        return {}
    end
    local ids = NormalizeSegmentIDs(set[pluralField])
    if #ids > 0 then
        return ids
    end
    for _, def in ipairs(SEGMENT_DEFS) do
        if def.plural == pluralField then
            return NormalizeSegmentIDs(set[def.singular])
        end
    end
    return {}
end

function LPL.LoadoutStore:SetSegmentIDs(set, pluralField, ids)
    if type(set) ~= "table" or type(pluralField) ~= "string" then
        return
    end
    local normalized = NormalizeSegmentIDs(ids)
    set[pluralField] = normalized
    for _, def in ipairs(SEGMENT_DEFS) do
        if def.plural == pluralField then
            set[def.singular] = normalized[1]
            break
        end
    end
end

local function SyncSegmentFields(set)
    for _, def in ipairs(SEGMENT_DEFS) do
        local ids = NormalizeSegmentIDs(set[def.plural])
        if #ids == 0 then
            ids = NormalizeSegmentIDs(set[def.singular])
        end
        set[def.plural] = ids
        set[def.singular] = ids[1]
    end
end

function LPL.LoadoutStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Loadout"
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

function LPL.LoadoutStore:EnsureSetsTable()
    local data = GetLoadoutsData()
    if type(data.sets) ~= "table" then
        data.sets = {}
    end
    if data.nextSetId == nil then
        data.nextSetId = 0
    end
    return data.sets
end

function LPL.LoadoutStore:GenerateID()
    local data = GetLoadoutsData()
    data.nextSetId = (data.nextSetId or 0) + 1
    return "loadout_" .. data.nextSetId
end

function LPL.LoadoutStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, "New Loadout")

    SyncSegmentFields(set)

    if LPL.SetRestrictions then
        set.restrictions = LPL.SetRestrictions:NormalizeRestrictions(set.restrictions)
        if set.restrictions and next(set.restrictions) then
            set.classID = LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
        else
            -- Infer class from first linked talent build when Universal.
            local buildID = set.talentBuildIDs and set.talentBuildIDs[1] or set.talentBuildID
            local build = buildID and LPL.BuildStore and LPL.BuildStore:Get(buildID)
            if build and build.classID then
                set.classID = tonumber(build.classID)
                set.specID = tonumber(build.specID)
                set.subTreeID = tonumber(build.subTreeID)
            else
                set.classID = nil
                set.specID = nil
                set.subTreeID = nil
            end
        end
        LPL.SetRestrictions:UpdateActionBarSetFilters(set)
    end

    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt

    return set
end

function LPL.LoadoutStore:MigrateStorage()
    local sets = self:EnsureSetsTable()
    local data = GetLoadoutsData()

    for setID, set in pairs(sets) do
        if type(set) == "table" then
            set.id = set.id or tostring(setID)
            self:NormalizeSetRecord(set)
        end
    end

    local maxID = data.nextSetId or 0
    for setID in pairs(sets) do
        local numericID = tostring(setID):match("^loadout_(%d+)$")
        if numericID then
            maxID = math.max(maxID, tonumber(numericID) or 0)
        end
    end
    data.nextSetId = maxID
end

function LPL.LoadoutStore:CommitSet(set)
    set = self:NormalizeSetRecord(set)
    if not set then
        return false
    end
    local sets = self:EnsureSetsTable()
    set.updatedAt = time()
    if not set.createdAt then
        set.createdAt = set.updatedAt
    end
    sets[set.id] = set

    local numericID = tostring(set.id):match("^loadout_(%d+)$")
    if numericID then
        local data = GetLoadoutsData()
        data.nextSetId = math.max(data.nextSetId or 0, tonumber(numericID) or 0)
    end

    return true
end

function LPL.LoadoutStore:GetAll()
    local sets = self:EnsureSetsTable()
    local list = {}
    for _, set in pairs(sets) do
        if type(set) == "table" then
            list[#list + 1] = set
        end
    end
    return list
end

function LPL.LoadoutStore:Get(setID)
    if not setID then
        return nil
    end
    return self:EnsureSetsTable()[setID]
end

function LPL.LoadoutStore:FindByName(name)
    name = self:NormalizeSetName(name, ""):lower()
    if name == "" then
        return nil
    end
    for _, set in pairs(self:EnsureSetsTable()) do
        if type(set) == "table" and (set.name or ""):lower() == name then
            return set
        end
    end
    return nil
end

function LPL.LoadoutStore:GetEffectiveClassID(set)
    if not set then
        return nil
    end
    if set.classID then
        return tonumber(set.classID)
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetEffectiveActionBarClassID then
        return LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
    end
    local buildID = set.talentBuildIDs and set.talentBuildIDs[1] or set.talentBuildID
    local build = buildID and LPL.BuildStore and LPL.BuildStore:Get(buildID)
    return build and tonumber(build.classID) or nil
end

function LPL.LoadoutStore:GetEffectiveSpecID(set)
    if not set then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetSingleRestrictedSpecID then
        local inferred = LPL.SetRestrictions:GetSingleRestrictedSpecID(set.restrictions)
        if inferred then
            return inferred
        end
    end
    if set.filters and set.filters.spec then
        return tonumber(set.filters.spec)
    end
    local buildID = set.talentBuildIDs and set.talentBuildIDs[1] or set.talentBuildID
    local build = buildID and LPL.BuildStore and LPL.BuildStore:Get(buildID)
    return build and tonumber(build.specID) or tonumber(set.specID)
end

function LPL.LoadoutStore:GetEffectiveHeroID(set)
    if not set then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetSingleRestrictedHeroID then
        local inferred = LPL.SetRestrictions:GetSingleRestrictedHeroID(set.restrictions)
        if inferred then
            return inferred
        end
    end
    if set.filters and set.filters.herotalents then
        return tonumber(set.filters.herotalents)
    end
    local buildID = set.talentBuildIDs and set.talentBuildIDs[1] or set.talentBuildID
    local build = buildID and LPL.BuildStore and LPL.BuildStore:Get(buildID)
    return build and tonumber(build.subTreeID) or tonumber(set.subTreeID)
end

function LPL.LoadoutStore:CountAttachedSegments(set)
    if type(set) ~= "table" then
        return 0
    end
    local count = 0
    for _, def in ipairs(SEGMENT_DEFS) do
        local ids = self:GetSegmentIDs(set, def.plural)
        if #ids > 0 then
            count = count + 1
        end
    end
    return count
end

function LPL.LoadoutStore:GetAttachedSegmentLabels(set)
    local labels = {}
    if type(set) ~= "table" then
        return labels
    end
    for _, def in ipairs(SEGMENT_DEFS) do
        local ids = self:GetSegmentIDs(set, def.plural)
        if #ids > 0 then
            if #ids == 1 then
                labels[#labels + 1] = def.label
            else
                labels[#labels + 1] = string.format("%s ×%d", def.label, #ids)
            end
        end
    end
    return labels
end

function LPL.LoadoutStore:GetSummaryLine(set)
    if not set then
        return ""
    end
    local labels = self:GetAttachedSegmentLabels(set)
    if #labels == 0 then
        return "No segments attached"
    end
    if #labels <= 3 then
        return table.concat(labels, " · ")
    end
    return string.format("%d segments", #labels)
end

function LPL.LoadoutStore:SuggestSetName()
    return "New Loadout"
end

function LPL.LoadoutStore:CreateDraftSet(name)
    local draft = {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        restrictions = {},
    }
    for _, def in ipairs(SEGMENT_DEFS) do
        draft[def.plural] = {}
        draft[def.singular] = nil
    end
    return draft
end

function LPL.LoadoutStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end
    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, importData.name or "Imported Loadout"),
        restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(importData.restrictions or {})
            or CopyTable(importData.restrictions or {}),
        createdAt = now,
        updatedAt = now,
    }
    for _, def in ipairs(SEGMENT_DEFS) do
        local ids = NormalizeSegmentIDs(importData[def.plural])
        if #ids == 0 then
            ids = NormalizeSegmentIDs(importData[def.singular])
        end
        set[def.plural] = ids
        set[def.singular] = ids[1]
    end
    if not self:CommitSet(set) then
        return nil
    end
    return set
end

function LPL.LoadoutStore:ApplyImport(importData, setName, options)
    if type(importData) ~= "table" or type(options) ~= "table" or options.loadout ~= true then
        return nil
    end
    setName = self:NormalizeSetName(setName, importData.name or "Imported Loadout")
    local existing = options.existingLoadoutID and self:Get(options.existingLoadoutID)
        or self:FindByName(setName)
    if existing then
        existing.name = setName
        for _, def in ipairs(SEGMENT_DEFS) do
            if importData[def.plural] ~= nil or importData[def.singular] ~= nil then
                local ids = NormalizeSegmentIDs(importData[def.plural])
                if #ids == 0 then
                    ids = NormalizeSegmentIDs(importData[def.singular])
                end
                existing[def.plural] = ids
                existing[def.singular] = ids[1]
            end
        end
        existing.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(importData.restrictions or {})
            or CopyTable(importData.restrictions or {})
        existing.updatedAt = time()
        if not self:CommitSet(existing) then
            return nil
        end
        return existing
    end
    return self:CreateFromImport(importData, setName)
end

function LPL.LoadoutStore:SaveFromEditor(setID, name, draftSet, onSaved)
    name = self:NormalizeSetName(name, self:SuggestSetName())
    draftSet = draftSet or {}

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        for _, def in ipairs(SEGMENT_DEFS) do
            local ids = NormalizeSegmentIDs(draftSet[def.plural])
            if #ids == 0 then
                ids = NormalizeSegmentIDs(draftSet[def.singular])
            end
            set[def.plural] = ids
            set[def.singular] = ids[1]
        end
        set.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or set.restrictions or {})
            or CopyTable(draftSet.restrictions or set.restrictions or {})
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved loadout \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or {})
            or CopyTable(draftSet.restrictions or {}),
        createdAt = time(),
        updatedAt = time(),
    }
    for _, def in ipairs(SEGMENT_DEFS) do
        local ids = NormalizeSegmentIDs(draftSet[def.plural])
        if #ids == 0 then
            ids = NormalizeSegmentIDs(draftSet[def.singular])
        end
        set[def.plural] = ids
        set[def.singular] = ids[1]
    end
    if not self:CommitSet(set) then
        return false
    end
    if onSaved then
        onSaved(set.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Saved loadout \"%s\".", name))
    return true
end

function LPL.LoadoutStore:Delete(setID)
    if not setID then
        return false
    end
    local sets = self:EnsureSetsTable()
    if sets[setID] then
        sets[setID] = nil
        return true
    end
    return false
end

function LPL.LoadoutStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete loadout \"%s\"? Linked segment sets are kept. This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.LoadoutStore:Delete(data.setID) then
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

    StaticPopup_Show(DELETE_DIALOG, set.name or "Unnamed Loadout", nil, {
        setID = setID,
        onConfirm = onConfirm,
    })
end

LPL.LoadoutStore.SEGMENT_FIELDS = SEGMENT_FIELDS
