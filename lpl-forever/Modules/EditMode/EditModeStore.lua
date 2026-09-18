local addonName, LPL = ...

LPL.EditModeStore = {}

LPL.EditModeStore.MAX_NAME_LENGTH = 150

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_EDIT_MODE_SET"

local function GetEditModeData()
    return LPL.DB:GetEditMode()
end

function LPL.EditModeStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Edit Mode Layout"
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

function LPL.EditModeStore:EnsureSetsTable()
    local editMode = GetEditModeData()
    if type(editMode.sets) ~= "table" then
        editMode.sets = {}
    end
    if editMode.nextSetId == nil then
        editMode.nextSetId = 0
    end
    return editMode.sets
end

function LPL.EditModeStore:GenerateID()
    local editMode = GetEditModeData()
    editMode.nextSetId = (editMode.nextSetId or 0) + 1
    return "editset_" .. editMode.nextSetId
end

function LPL.EditModeStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, "New Edit Mode Layout")
    if type(set.layoutString) ~= "string" then
        set.layoutString = ""
    end
    if set.editModeCharacterSpecific == nil then
        set.editModeCharacterSpecific = true
    end

    if LPL.SetRestrictions then
        set.restrictions = LPL.SetRestrictions:NormalizeRestrictions(set.restrictions)
        if set.restrictions and next(set.restrictions) then
            set.classID = LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
        else
            -- Universal until Limits are set — group under Other.
            set.classID = nil
            set.specID = nil
            set.subTreeID = nil
        end
        LPL.SetRestrictions:UpdateActionBarSetFilters(set)
    end

    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt

    return set
end

function LPL.EditModeStore:MigrateStorage()
    local sets = self:EnsureSetsTable()
    local data = GetEditModeData()

    for setID, set in pairs(sets) do
        if type(set) == "table" then
            set.id = set.id or tostring(setID)
            if not set.restrictions or not next(set.restrictions) then
                set.classID = nil
                set.specID = nil
                set.subTreeID = nil
            end
            self:NormalizeSetRecord(set)
        end
    end

    local maxID = data.nextSetId or 0
    for setID in pairs(sets) do
        local numericID = tostring(setID):match("^editset_(%d+)$")
        if numericID then
            maxID = math.max(maxID, tonumber(numericID) or 0)
        end
    end
    data.nextSetId = maxID
end

function LPL.EditModeStore:CommitSet(set)
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

    local numericID = tostring(set.id):match("^editset_(%d+)$")
    if numericID then
        local data = GetEditModeData()
        data.nextSetId = math.max(data.nextSetId or 0, tonumber(numericID) or 0)
    end

    return true
end

function LPL.EditModeStore:GetAll()
    local sets = self:EnsureSetsTable()
    local list = {}
    for _, set in pairs(sets) do
        if type(set) == "table" then
            list[#list + 1] = set
        end
    end
    return list
end

function LPL.EditModeStore:Get(setID)
    if not setID then
        return nil
    end
    return self:EnsureSetsTable()[setID]
end

function LPL.EditModeStore:FindByName(name)
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

function LPL.EditModeStore:GetEffectiveClassID(set)
    if not set then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetEffectiveActionBarClassID then
        return LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
    end
    return nil
end

function LPL.EditModeStore:GetEffectiveSpecID(set)
    if not set then
        return nil
    end
    local restrictions = set.restrictions
    if type(restrictions) ~= "table" or not next(restrictions) then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetSingleRestrictedSpecID then
        local inferred = LPL.SetRestrictions:GetSingleRestrictedSpecID(restrictions)
        if inferred then
            return inferred
        end
    end
    if set.filters and set.filters.spec then
        return tonumber(set.filters.spec)
    end
    return tonumber(set.specID)
end

function LPL.EditModeStore:GetEffectiveHeroID(set)
    if not set then
        return nil
    end
    local restrictions = set.restrictions
    if type(restrictions) ~= "table" or not next(restrictions) then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetSingleRestrictedHeroID then
        local inferred = LPL.SetRestrictions:GetSingleRestrictedHeroID(restrictions)
        if inferred then
            return inferred
        end
    end
    if set.filters and set.filters.herotalents then
        return tonumber(set.filters.herotalents)
    end
    return tonumber(set.subTreeID)
end

function LPL.EditModeStore:GetSummaryLine(set)
    if not set then
        return ""
    end
    local layout = set.layoutString
    if type(layout) ~= "string" or layout:match("^%s*$") then
        return "Empty layout"
    end
    local scope = set.editModeCharacterSpecific ~= false and "Character" or "Account"
    return string.format("%s · Layout string (%d chars)", scope, #layout)
end

function LPL.EditModeStore:SuggestSetName()
    return "New Edit Mode Layout"
end

function LPL.EditModeStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        layoutString = "",
        editModeCharacterSpecific = true,
        restrictions = {},
    }
end

function LPL.EditModeStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end
    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, importData.name or "Imported Edit Mode Layout"),
        layoutString = importData.layoutString or "",
        editModeCharacterSpecific = importData.editModeCharacterSpecific ~= false,
        restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(importData.restrictions or {})
            or CopyTable(importData.restrictions or {}),
        createdAt = now,
        updatedAt = now,
    }
    if not self:CommitSet(set) then
        return nil
    end
    return set
end

function LPL.EditModeStore:ApplyImport(importData, setName, options)
    if type(importData) ~= "table" or type(options) ~= "table" or options.editMode ~= true then
        return nil
    end
    setName = self:NormalizeSetName(setName, importData.name or "Imported Edit Mode Layout")
    local existing = options.existingEditModeID and self:Get(options.existingEditModeID)
        or self:FindByName(setName)
    if existing then
        existing.name = setName
        existing.layoutString = importData.layoutString or existing.layoutString or ""
        existing.editModeCharacterSpecific = importData.editModeCharacterSpecific ~= false
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

function LPL.EditModeStore:SaveFromEditor(setID, name, draftSet, onSaved)
    name = self:NormalizeSetName(name, self:SuggestSetName())
    draftSet = draftSet or {}

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.layoutString = type(draftSet.layoutString) == "string" and draftSet.layoutString or set.layoutString or ""
        if draftSet.editModeCharacterSpecific ~= nil then
            set.editModeCharacterSpecific = draftSet.editModeCharacterSpecific ~= false
        end
        set.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or set.restrictions or {})
            or CopyTable(draftSet.restrictions or set.restrictions or {})
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved Edit Mode layout \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        layoutString = type(draftSet.layoutString) == "string" and draftSet.layoutString or "",
        editModeCharacterSpecific = draftSet.editModeCharacterSpecific ~= false,
        restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or {})
            or CopyTable(draftSet.restrictions or {}),
        createdAt = time(),
        updatedAt = time(),
    }
    if not self:CommitSet(set) then
        return false
    end
    if onSaved then
        onSaved(set.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Saved Edit Mode layout \"%s\".", name))
    return true
end

function LPL.EditModeStore:Delete(setID)
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

function LPL.EditModeStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete Edit Mode layout \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.EditModeStore:Delete(data.setID) then
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

    StaticPopup_Show(DELETE_DIALOG, set.name or "Unnamed Layout", nil, {
        setID = setID,
        onConfirm = onConfirm,
    })
end
