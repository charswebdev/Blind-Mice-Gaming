local addonName, LPL = ...

LPL.PvpTalentStore = {}

LPL.PvpTalentStore.MAX_NAME_LENGTH = 150
LPL.PvpTalentStore.SLOT_COUNT = 3

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_PVP_TALENT_SET"

local function GetPvpData()
    return LPL.DB:GetPvpTalents()
end

local function CountFilledTalents(talents)
    if type(talents) ~= "table" then
        return 0
    end
    local count = 0
    for slot = 1, LPL.PvpTalentStore.SLOT_COUNT do
        local talentID = tonumber(talents[slot])
        if talentID and talentID > 0 then
            count = count + 1
        end
    end
    return count
end

local function NormalizeTalents(talents)
    local normalized = {}
    if type(talents) ~= "table" then
        return normalized
    end

    -- Prefer explicit slot indexes when present.
    local hasSlotKeys = false
    for slot = 1, LPL.PvpTalentStore.SLOT_COUNT do
        local talentID = tonumber(talents[slot])
        if talentID and talentID > 0 then
            normalized[slot] = talentID
            hasSlotKeys = true
        end
    end
    if hasSlotKeys then
        return normalized
    end

    -- BtW / legacy share strings use { [talentID] = true }.
    local packed = {}
    for key, value in pairs(talents) do
        local talentID = tonumber(key)
        if talentID and talentID > 0 and value then
            packed[#packed + 1] = talentID
        else
            talentID = tonumber(value)
            if talentID and talentID > 0 then
                packed[#packed + 1] = talentID
            end
        end
    end
    table.sort(packed)
    for index = 1, math.min(LPL.PvpTalentStore.SLOT_COUNT, #packed) do
        normalized[index] = packed[index]
    end
    return normalized
end

function LPL.PvpTalentStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New PvP Set"
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

function LPL.PvpTalentStore:EnsureSetsTable()
    local pvp = GetPvpData()
    if type(pvp.sets) ~= "table" then
        pvp.sets = {}
    end
    if pvp.nextSetId == nil then
        pvp.nextSetId = 0
    end
    return pvp.sets
end

function LPL.PvpTalentStore:GenerateID()
    local pvp = GetPvpData()
    pvp.nextSetId = (pvp.nextSetId or 0) + 1
    return "pvpset_" .. pvp.nextSetId
end

function LPL.PvpTalentStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, "New PvP Set")
    set.talents = NormalizeTalents(set.talents)
    -- Planning context for the talent pool (kept even when Limits are empty / Other grouping).
    set.specID = tonumber(set.specID)
    set.subTreeID = tonumber(set.subTreeID)
    if set.specID and LPL.TalentTree and LPL.TalentTree.GetClassIDForSpec then
        set.classID = LPL.TalentTree:GetClassIDForSpec(set.specID)
    else
        set.classID = tonumber(set.classID)
    end

    if LPL.SetRestrictions then
        set.restrictions = LPL.SetRestrictions:NormalizeRestrictions(set.restrictions)
        LPL.SetRestrictions:UpdateActionBarSetFilters(set)
    end

    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt

    return set
end

function LPL.PvpTalentStore:MigrateStorage()
    local sets = self:EnsureSetsTable()
    local pvp = GetPvpData()

    for setID, set in pairs(sets) do
        if type(set) == "table" then
            set.id = set.id or tostring(setID)
            self:NormalizeSetRecord(set)
        end
    end

    local maxID = pvp.nextSetId or 0
    for setID in pairs(sets) do
        local numericID = tostring(setID):match("^pvpset_(%d+)$")
        if numericID then
            maxID = math.max(maxID, tonumber(numericID) or 0)
        end
    end
    pvp.nextSetId = maxID
end

function LPL.PvpTalentStore:CommitSet(set)
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

    local numericID = tostring(set.id):match("^pvpset_(%d+)$")
    if numericID then
        local pvp = GetPvpData()
        pvp.nextSetId = math.max(pvp.nextSetId or 0, tonumber(numericID) or 0)
    end

    return true
end

function LPL.PvpTalentStore:GetAll()
    local sets = self:EnsureSetsTable()
    local list = {}
    for _, set in pairs(sets) do
        if type(set) == "table" then
            list[#list + 1] = set
        end
    end
    return list
end

function LPL.PvpTalentStore:Get(setID)
    if not setID then
        return nil
    end
    return self:EnsureSetsTable()[setID]
end

function LPL.PvpTalentStore:FindByName(name)
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

function LPL.PvpTalentStore:GetEffectiveClassID(set)
    if not set then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetEffectiveActionBarClassID then
        return LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
    end
    return nil
end

function LPL.PvpTalentStore:GetEffectiveSpecID(set)
    if not set then
        return nil
    end
    local restrictions = set.restrictions
    if type(restrictions) ~= "table" or not next(restrictions) then
        return nil
    end
    if type(restrictions.spec) == "table" then
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
        if inferred then
            return inferred
        end
    end
    if set.filters and set.filters.spec then
        return tonumber(set.filters.spec)
    end
    return tonumber(set.specID)
end

function LPL.PvpTalentStore:GetEffectiveHeroID(set)
    if not set then
        return nil
    end
    local restrictions = set.restrictions
    if type(restrictions) ~= "table" or not next(restrictions) then
        return nil
    end
    if type(restrictions.herotalents) == "table" then
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
        if inferred then
            return inferred
        end
    end
    if set.filters and set.filters.herotalents then
        return tonumber(set.filters.herotalents)
    end
    return tonumber(set.subTreeID)
end

function LPL.PvpTalentStore:GetSummaryLine(set)
    if not set then
        return ""
    end
    local filled = CountFilledTalents(set.talents)
    if filled == 0 then
        return "Empty set"
    end
    return string.format("%d of %d talent%s", filled, self.SLOT_COUNT, filled == 1 and "" or "s")
end

function LPL.PvpTalentStore:SuggestSetName()
    return "New PvP Set"
end

function LPL.PvpTalentStore:CreateDraftSet(name)
    local classID, specID
    if LPL.PvpTalentCodec and LPL.PvpTalentCodec.GetPlayerClassAndSpec then
        classID, specID = LPL.PvpTalentCodec:GetPlayerClassAndSpec()
    elseif LPL.TalentTree and LPL.TalentTree.GetPlayerIdentity then
        classID, specID = LPL.TalentTree:GetPlayerIdentity()
    end
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        talents = {},
        restrictions = {},
        classID = classID,
        specID = specID,
    }
end

function LPL.PvpTalentStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end
    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, importData.name or "Imported PvP Set"),
        talents = NormalizeTalents(importData.talents),
        specID = tonumber(importData.specID),
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

function LPL.PvpTalentStore:ApplyImport(importData, setName, options)
    if type(importData) ~= "table" or type(options) ~= "table" or options.pvpTalents ~= true then
        return nil
    end
    setName = self:NormalizeSetName(setName, importData.name or "Imported PvP Set")
    local existing = options.existingPvpTalentID and self:Get(options.existingPvpTalentID)
        or self:FindByName(setName)
    if existing then
        existing.name = setName
        existing.talents = NormalizeTalents(importData.talents)
        existing.specID = tonumber(importData.specID) or existing.specID
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

function LPL.PvpTalentStore:SaveFromEditor(setID, name, draftSet, onSaved)
    name = self:NormalizeSetName(name, self:SuggestSetName())
    draftSet = draftSet or {}

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.talents = NormalizeTalents(draftSet.talents or set.talents)
        set.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or set.restrictions or {})
            or CopyTable(draftSet.restrictions or set.restrictions or {})
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved PvP set \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        talents = NormalizeTalents(draftSet.talents),
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
    print(string.format("|cff33cc33LPL:|r Saved PvP set \"%s\".", name))
    return true
end

function LPL.PvpTalentStore:Delete(setID)
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

function LPL.PvpTalentStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete PvP set \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.PvpTalentStore:Delete(data.setID) then
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
