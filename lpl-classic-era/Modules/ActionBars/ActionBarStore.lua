local addonName, LPL = ...

LPL.ActionBarStore = {}

LPL.ActionBarStore.MAX_NAME_LENGTH = 150

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_ACTION_BAR_SET"

local function GetActionBarsData()
    return LPL.DB:GetActionBars()
end

local function SyncActionBarsGlobal(actionBars)
    if type(LPLClassicEraDB) ~= "table" then
        LPLClassicEraDB = type(_G.LPLClassicEraDB) == "table" and _G.LPLClassicEraDB or {}
    end
    LPLClassicEraDB.actionBars = actionBars
    _G.LPLClassicEraDB = LPLClassicEraDB
    if LPL.DB then
        LPL.DB.data = LPLClassicEraDB
    end
    return actionBars
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

function LPL.ActionBarStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Action Bar Set"
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

function LPL.ActionBarStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end

    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end

    set.name = self:NormalizeSetName(set.name, "New Action Bar Set")
    if type(set.actions) ~= "table" then
        set.actions = {}
    end
    if type(set.ignored) ~= "table" then
        set.ignored = {}
    end
    if type(set.petActions) ~= "table" then
        set.petActions = {}
    end
    if type(set.petIgnored) ~= "table" then
        set.petIgnored = {}
    end
    set.classID = tonumber(set.classID)
    set.specID = tonumber(set.specID)
    set.subTreeID = tonumber(set.subTreeID)

    if LPL.SetRestrictions then
        set.restrictions = LPL.SetRestrictions:NormalizeRestrictions(set.restrictions)
        if set.restrictions and next(set.restrictions) then
            if not set.classID then
                set.classID = LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
            end
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

function LPL.ActionBarStore:EnsureSetsTable()
    local actionBars = SyncActionBarsGlobal(GetActionBarsData())
    if type(actionBars.sets) ~= "table" then
        actionBars.sets = {}
    end
    if actionBars.nextSetId == nil then
        actionBars.nextSetId = 0
    end
    return actionBars.sets
end

function LPL.ActionBarStore:MigrateStorage()
    local actionBars = SyncActionBarsGlobal(GetActionBarsData())
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

    local maxID = actionBars.nextSetId or 0
    for setID in pairs(sets) do
        local numericID = tostring(setID):match("^abset_(%d+)$")
        if numericID then
            maxID = math.max(maxID, tonumber(numericID) or 0)
        end
    end
    actionBars.nextSetId = maxID
end

function LPL.ActionBarStore:GenerateID()
    local actionBars = GetActionBarsData()
    actionBars.nextSetId = (actionBars.nextSetId or 0) + 1
    return "abset_" .. actionBars.nextSetId
end

function LPL.ActionBarStore:CommitSet(set)
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

    local numericID = tostring(set.id):match("^abset_(%d+)$")
    if numericID then
        local actionBars = GetActionBarsData()
        actionBars.nextSetId = math.max(actionBars.nextSetId or 0, tonumber(numericID) or 0)
    end

    return true
end

function LPL.ActionBarStore:GetAll()
    local sets = self:EnsureSetsTable()
    local list = {}
    for _, set in pairs(sets) do
        list[#list + 1] = set
    end
    return list
end

function LPL.ActionBarStore:Get(setID)
    if not setID then
        return nil
    end
    return self:EnsureSetsTable()[setID]
end

function LPL.ActionBarStore:FindByName(name)
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

function LPL.ActionBarStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end

    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, importData.name or "Imported Action Bar Set"),
        actions = CopyTable(importData.actions or {}),
        ignored = CopyTable(importData.ignored or {}),
        petActions = CopyTable(importData.petActions or {}),
        petIgnored = CopyTable(importData.petIgnored or {}),
        restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(importData.restrictions or {})
            or CopyTable(importData.restrictions or {}),
        createdAt = now,
        updatedAt = now,
    }

    if LPL.ActionBarCodec and LPL.ActionBarCodec.SanitizeDraft then
        LPL.ActionBarCodec:SanitizeDraft(set)
    end

    if not self:CommitSet(set) then
        return nil
    end
    return set
end

function LPL.ActionBarStore:ApplyImport(importData, setName, options)
    if type(importData) ~= "table" or type(options) ~= "table" or options.actionBars ~= true then
        return nil
    end

    setName = self:NormalizeSetName(setName, importData.name or "Imported Action Bar Set")
    local existing = options.existingActionBarID and self:Get(options.existingActionBarID)
        or self:FindByName(setName)

    if existing then
        existing.name = setName
        existing.actions = CopyTable(importData.actions or {})
        existing.ignored = CopyTable(importData.ignored or {})
        existing.petActions = CopyTable(importData.petActions or {})
        existing.petIgnored = CopyTable(importData.petIgnored or {})
        existing.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(importData.restrictions or {})
            or CopyTable(importData.restrictions or {})
        if LPL.ActionBarCodec and LPL.ActionBarCodec.SanitizeDraft then
            LPL.ActionBarCodec:SanitizeDraft(existing)
        end
        existing.updatedAt = time()
        if not self:CommitSet(existing) then
            return nil
        end
        return existing
    end

    return self:CreateFromImport(importData, setName)
end

function LPL.ActionBarStore:CountFilledSlots(set)
    if not set then
        return 0
    end
    return CountTableKeys(set.actions) + CountTableKeys(set.petActions)
end

function LPL.ActionBarStore:CountIgnoredSlots(set)
    if not set then
        return 0
    end
    return CountTableKeys(set.ignored) + CountTableKeys(set.petIgnored)
end

function LPL.ActionBarStore:GetPlayerSetMetadata()
    local classID = LPL.Character and LPL.Character:GetClassID()
    local specID = LPL.Character and LPL.Character:GetSpecID()
    local subTreeID
    if LPL.TalentTree and LPL.TalentTree.GetPlayerActiveSubTreeID and specID then
        subTreeID = LPL.TalentTree:GetPlayerActiveSubTreeID(specID)
    end
    return classID, specID, subTreeID
end

function LPL.ActionBarStore:ApplyPlayerMetadata(set)
    -- Intentionally no-op: action bar sets stay universal (Other)
    -- until the player sets Limits. Capture/Update must not stamp class.
    if type(set) ~= "table" then
        return
    end
end

function LPL.ActionBarStore:GetEffectiveClassID(set)
    if not set then
        return nil
    end
    if LPL.SetRestrictions and LPL.SetRestrictions.GetEffectiveActionBarClassID then
        return LPL.SetRestrictions:GetEffectiveActionBarClassID(set)
    end
    return tonumber(set.classID)
end

function LPL.ActionBarStore:GetEffectiveSpecID(set)
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

function LPL.ActionBarStore:GetEffectiveHeroID(set)
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

function LPL.ActionBarStore:GetSummaryLine(set)
    if not set then
        return ""
    end
    local filled = self:CountFilledSlots(set)
    local ignored = self:CountIgnoredSlots(set)
    if filled == 0 and ignored == 0 then
        return "Empty set"
    end
    if ignored > 0 then
        return string.format("%d slot%s · %d ignored", filled, filled == 1 and "" or "s", ignored)
    end
    return string.format("%d slot%s", filled, filled == 1 and "" or "s")
end

function LPL.ActionBarStore:CreateNew(name)
    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, "New Action Bar Set"),
        actions = {},
        ignored = {},
        petActions = {},
        petIgnored = {},
        restrictions = {},
        createdAt = now,
        updatedAt = now,
    }
    if not self:CommitSet(set) then
        return nil
    end
    return set
end

function LPL.ActionBarStore:SuggestSetName()
    return "New Action Bar Set"
end

function LPL.ActionBarStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, "New Action Bar Set"),
        actions = {},
        ignored = {},
        petActions = {},
        petIgnored = {},
        restrictions = {},
    }
end

function LPL.ActionBarStore:SaveFromEditor(setID, name, draftSet, onSaved)
    name = self:NormalizeSetName(name, self:SuggestSetName())
    draftSet = draftSet or {}
    if LPL.ActionBarCodec and LPL.ActionBarCodec.SanitizeDraft then
        LPL.ActionBarCodec:SanitizeDraft(draftSet)
    end

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.actions = draftSet.actions or set.actions or {}
        set.ignored = draftSet.ignored or set.ignored or {}
        set.petActions = draftSet.petActions or set.petActions or {}
        set.petIgnored = draftSet.petIgnored or set.petIgnored or {}
        set.restrictions = LPL.SetRestrictions and LPL.SetRestrictions:CopyRestrictions(draftSet.restrictions or set.restrictions or {})
            or CopyTable(draftSet.restrictions or set.restrictions or {})
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved action bar set \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        actions = draftSet.actions or {},
        ignored = draftSet.ignored or {},
        petActions = draftSet.petActions or {},
        petIgnored = draftSet.petIgnored or {},
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
    print(string.format("|cff33cc33LPL:|r Saved action bar set \"%s\".", name))
    return true
end

function LPL.ActionBarStore:Delete(setID)
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

function LPL.ActionBarStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete action bar set \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.ActionBarStore:Delete(data.setID) then
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
