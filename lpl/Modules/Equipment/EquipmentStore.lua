local addonName, LPL = ...

LPL.EquipmentStore = {}

LPL.EquipmentStore.MAX_NAME_LENGTH = 150

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_EQUIPMENT_SET"

local INVSLOT_BODY = 4
local INVSLOT_TABARD = 19

local function GetEquipmentData()
    return LPL.DB:GetEquipment()
end

local function SyncEquipmentGlobal(equipment)
    _G.LPLDB = _G.LPLDB or {}
    _G.LPLDB.equipment = equipment
    if LPL.DB then
        LPL.DB.data = _G.LPLDB
    end
    return equipment
end

local function CountTableKeys(tbl)
    if type(tbl) ~= "table" then
        return 0
    end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function LPL.EquipmentStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Equipment Set"
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

function LPL.EquipmentStore:DefaultIgnoredSlots()
    return {
        [INVSLOT_BODY] = true,
        [INVSLOT_TABARD] = true,
    }
end

function LPL.EquipmentStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end

    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end

    set.name = self:NormalizeSetName(set.name, "New Equipment Set")
    if type(set.slots) ~= "table" then
        set.slots = {}
    end
    if type(set.ignored) ~= "table" then
        set.ignored = {}
    end
    set.classID = tonumber(set.classID)
    set.specID = tonumber(set.specID)
    set.subTreeID = tonumber(set.subTreeID)

    if LPL.SetRestrictions then
        set.restrictions = LPL.SetRestrictions:NormalizeRestrictions(set.restrictions)
        if set.restrictions and next(set.restrictions) then
            if not set.classID then
                set.classID = LPL.SetRestrictions:GetEffectiveEquipmentClassID(set)
            end
        else
            set.classID = nil
            set.specID = nil
            set.subTreeID = nil
        end
        LPL.SetRestrictions:UpdateEquipmentSetFilters(set)
    end

    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt

    return set
end

function LPL.EquipmentStore:EnsureSetsTable()
    local equipment = SyncEquipmentGlobal(GetEquipmentData())
    if type(equipment.sets) ~= "table" then
        equipment.sets = {}
    end
    if equipment.nextSetId == nil then
        equipment.nextSetId = 0
    end
    return equipment.sets
end

function LPL.EquipmentStore:MigrateStorage()
    local equipment = SyncEquipmentGlobal(GetEquipmentData())
    local sets = self:EnsureSetsTable()

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

    local maxID = equipment.nextSetId or 0
    for setID in pairs(sets) do
        local numericID = tostring(setID):match("^eqset_(%d+)$")
        if numericID then
            maxID = math.max(maxID, tonumber(numericID) or 0)
        end
    end
    equipment.nextSetId = maxID
end

function LPL.EquipmentStore:GenerateID()
    local equipment = GetEquipmentData()
    equipment.nextSetId = (equipment.nextSetId or 0) + 1
    return "eqset_" .. equipment.nextSetId
end

function LPL.EquipmentStore:CommitSet(set)
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

    local numericID = tostring(set.id):match("^eqset_(%d+)$")
    if numericID then
        local equipment = GetEquipmentData()
        equipment.nextSetId = math.max(equipment.nextSetId or 0, tonumber(numericID) or 0)
    end

    return true
end

function LPL.EquipmentStore:GetAll()
    local sets = self:EnsureSetsTable()
    local list = {}
    for _, set in pairs(sets) do
        list[#list + 1] = set
    end
    return list
end

function LPL.EquipmentStore:Get(setID)
    if not setID then
        return nil
    end
    return self:EnsureSetsTable()[setID]
end

function LPL.EquipmentStore:FindByName(name)
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

function LPL.EquipmentStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end

    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, importData.name or "Imported Equipment Set"),
        slots = CopyTable(importData.slots or {}),
        ignored = CopyTable(importData.ignored or {}),
        restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(importData.restrictions or {})
            or CopyTable(importData.restrictions or {}),
        createdAt = now,
        updatedAt = now,
    }

    if LPL.EquipmentCodec and LPL.EquipmentCodec.SanitizeDraft then
        LPL.EquipmentCodec:SanitizeDraft(set)
    end

    if not self:CommitSet(set) then
        return nil
    end
    return set
end

function LPL.EquipmentStore:ApplyImport(importData, setName, options)
    if type(importData) ~= "table" or type(options) ~= "table" or options.equipment ~= true then
        return nil
    end

    setName = self:NormalizeSetName(setName, importData.name or "Imported Equipment Set")
    local existing = options.existingEquipmentID and self:Get(options.existingEquipmentID)
        or self:FindByName(setName)

    if existing then
        existing.name = setName
        existing.slots = CopyTable(importData.slots or {})
        existing.ignored = CopyTable(importData.ignored or {})
        existing.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(importData.restrictions or {})
            or CopyTable(importData.restrictions or {})
        if LPL.EquipmentCodec and LPL.EquipmentCodec.SanitizeDraft then
            LPL.EquipmentCodec:SanitizeDraft(existing)
        end
        existing.updatedAt = time()
        if not self:CommitSet(existing) then
            return nil
        end
        return existing
    end

    return self:CreateFromImport(importData, setName)
end

function LPL.EquipmentStore:CountFilledSlots(set)
    if not set or type(set.slots) ~= "table" then
        return 0
    end
    local count = 0
    for _, entry in pairs(set.slots) do
        if LPL.EquipmentCodec and LPL.EquipmentCodec.GetSlotItemID then
            if LPL.EquipmentCodec:GetSlotItemID(entry) then
                count = count + 1
            end
        elseif type(entry) == "table" and tonumber(entry.itemID) then
            count = count + 1
        end
    end
    return count
end

function LPL.EquipmentStore:CountIgnoredSlots(set)
    if not set or type(set.ignored) ~= "table" then
        return 0
    end
    return CountTableKeys(set.ignored)
end

function LPL.EquipmentStore:GetPlayerSetMetadata()
    local classID = LPL.Character and LPL.Character:GetClassID()
    local specID = LPL.Character and LPL.Character:GetSpecID()
    local subTreeID
    if LPL.TalentTree and LPL.TalentTree.GetPlayerActiveSubTreeID and specID then
        subTreeID = LPL.TalentTree:GetPlayerActiveSubTreeID(specID)
    end
    return classID, specID, subTreeID
end

function LPL.EquipmentStore:GetEffectiveClassID(set)
    if not set then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetEffectiveEquipmentClassID then
        return LPL.SetRestrictions:GetEffectiveEquipmentClassID(set)
    end
    return tonumber(set.classID)
end

function LPL.EquipmentStore:GetEffectiveSpecID(set)
    if not set then
        return nil
    end
    local specID = tonumber(set.specID)
    if specID then
        return specID
    end
    if set.filters and set.filters.spec then
        return tonumber(set.filters.spec)
    end
    local restrictions = set.restrictions
    if type(restrictions) == "table" and type(restrictions.spec) == "table" then
        local inferred
        for restrictedSpecID in pairs(restrictions.spec) do
            restrictedSpecID = tonumber(restrictedSpecID)
            if restrictedSpecID then
                if inferred and inferred ~= restrictedSpecID then
                    return nil
                end
                inferred = restrictedSpecID
            end
        end
        return inferred
    end
    return nil
end

function LPL.EquipmentStore:GetEffectiveHeroID(set)
    if not set then
        return nil
    end
    local subTreeID = tonumber(set.subTreeID)
    if subTreeID then
        return subTreeID
    end
    if set.filters and set.filters.herotalents then
        return tonumber(set.filters.herotalents)
    end
    local restrictions = set.restrictions
    if type(restrictions) == "table" and type(restrictions.herotalents) == "table" then
        local inferred
        for heroID in pairs(restrictions.herotalents) do
            heroID = tonumber(heroID)
            if heroID then
                if inferred and inferred ~= heroID then
                    return nil
                end
                inferred = heroID
            end
        end
        return inferred
    end
    return nil
end

function LPL.EquipmentStore:GetSummaryLine(set)
    if not set then
        return ""
    end
    local filled = self:CountFilledSlots(set)
    local ignored = self:CountIgnoredSlots(set)
    if filled == 0 and ignored == 0 then
        return "Empty set"
    end
    if ignored > 0 then
        return string.format("%d slot%s | %d ignored", filled, filled == 1 and "" or "s", ignored)
    end
    return string.format("%d slot%s", filled, filled == 1 and "" or "s")
end

function LPL.EquipmentStore:SuggestSetName()
    return "New Equipment Set"
end

function LPL.EquipmentStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        slots = {},
        ignored = CopyTable(self:DefaultIgnoredSlots()),
        restrictions = {},
    }
end

function LPL.EquipmentStore:SaveFromEditor(setID, name, draftSet, onSaved)
    name = self:NormalizeSetName(name, self:SuggestSetName())
    draftSet = draftSet or {}
    if LPL.EquipmentCodec and LPL.EquipmentCodec.SanitizeDraft then
        LPL.EquipmentCodec:SanitizeDraft(draftSet)
    end

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.slots = CopyTable(draftSet.slots or set.slots or {})
        set.ignored = CopyTable(draftSet.ignored or set.ignored or {})
        set.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or set.restrictions or {}) or CopyTable(draftSet.restrictions or set.restrictions or {})
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved equipment set \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        slots = CopyTable(draftSet.slots or {}),
        ignored = CopyTable(draftSet.ignored or self:DefaultIgnoredSlots()),
        restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or {}) or CopyTable(draftSet.restrictions or {}),
        createdAt = time(),
        updatedAt = time(),
    }
    if not self:CommitSet(set) then
        return false
    end
    if onSaved then
        onSaved(set.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Saved equipment set \"%s\".", name))
    return true
end

function LPL.EquipmentStore:Delete(setID)
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

function LPL.EquipmentStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete equipment set \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.EquipmentStore:Delete(data.setID) then
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
