local addonName, LPL = ...

LPL.CooldownManagerStore = {}

LPL.CooldownManagerStore.MAX_NAME_LENGTH = 150

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_COOLDOWN_MANAGER_SET"

local function GetCooldownData()
    return LPL.DB:GetCooldownManager()
end

function LPL.CooldownManagerStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Cooldown Manager Set"
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

function LPL.CooldownManagerStore:EnsureSetsTable()
    local data = GetCooldownData()
    if type(data.sets) ~= "table" then
        data.sets = {}
    end
    if data.nextSetId == nil then
        data.nextSetId = 0
    end
    return data.sets
end

function LPL.CooldownManagerStore:GenerateID()
    local data = GetCooldownData()
    data.nextSetId = (data.nextSetId or 0) + 1
    return "cdmset_" .. data.nextSetId
end

function LPL.CooldownManagerStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, "New Cooldown Manager Set")
    if type(set.layoutString) ~= "string" then
        set.layoutString = ""
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

function LPL.CooldownManagerStore:MigrateStorage()
    local sets = self:EnsureSetsTable()
    local data = GetCooldownData()

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
        local numericID = tostring(setID):match("^cdmset_(%d+)$")
        if numericID then
            maxID = math.max(maxID, tonumber(numericID) or 0)
        end
    end
    data.nextSetId = maxID
end

function LPL.CooldownManagerStore:CommitSet(set)
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

    local numericID = tostring(set.id):match("^cdmset_(%d+)$")
    if numericID then
        local data = GetCooldownData()
        data.nextSetId = math.max(data.nextSetId or 0, tonumber(numericID) or 0)
    end

    return true
end

function LPL.CooldownManagerStore:GetAll()
    local sets = self:EnsureSetsTable()
    local list = {}
    for _, set in pairs(sets) do
        if type(set) == "table" then
            list[#list + 1] = set
        end
    end
    return list
end

function LPL.CooldownManagerStore:Get(setID)
    if not setID then
        return nil
    end
    return self:EnsureSetsTable()[setID]
end

function LPL.CooldownManagerStore:FindByName(name)
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

function LPL.CooldownManagerStore:GetEffectiveClassID(set)
    if not set then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetEffectiveActionBarClassID then
        return LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
    end
    return nil
end

function LPL.CooldownManagerStore:GetEffectiveSpecID(set)
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

function LPL.CooldownManagerStore:GetEffectiveHeroID(set)
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

function LPL.CooldownManagerStore:GetSummaryLine(set)
    if not set then
        return ""
    end
    local layout = set.layoutString
    if type(layout) ~= "string" or layout:match("^%s*$") then
        return "Empty layout"
    end
    return string.format("Layout string (%d chars)", #layout)
end

function LPL.CooldownManagerStore:SuggestSetName()
    return "New Cooldown Manager Set"
end

function LPL.CooldownManagerStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        layoutString = "",
        restrictions = {},
    }
end

function LPL.CooldownManagerStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end
    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, importData.name or "Imported Cooldown Manager Set"),
        layoutString = importData.layoutString or "",
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

function LPL.CooldownManagerStore:ApplyImport(importData, setName, options)
    if type(importData) ~= "table" or type(options) ~= "table" or options.cooldownManager ~= true then
        return nil
    end
    setName = self:NormalizeSetName(setName, importData.name or "Imported Cooldown Manager Set")
    local existing = options.existingCooldownManagerID and self:Get(options.existingCooldownManagerID)
        or self:FindByName(setName)
    if existing then
        existing.name = setName
        existing.layoutString = importData.layoutString or existing.layoutString or ""
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

function LPL.CooldownManagerStore:SaveFromEditor(setID, name, draftSet, onSaved)
    name = self:NormalizeSetName(name, self:SuggestSetName())
    draftSet = draftSet or {}

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.layoutString = type(draftSet.layoutString) == "string" and draftSet.layoutString or set.layoutString or ""
        set.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or set.restrictions or {})
            or CopyTable(draftSet.restrictions or set.restrictions or {})
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved Cooldown Manager set \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        layoutString = type(draftSet.layoutString) == "string" and draftSet.layoutString or "",
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
    print(string.format("|cff33cc33LPL:|r Saved Cooldown Manager set \"%s\".", name))
    return true
end

function LPL.CooldownManagerStore:Delete(setID)
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

function LPL.CooldownManagerStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete Cooldown Manager set \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.CooldownManagerStore:Delete(data.setID) then
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
