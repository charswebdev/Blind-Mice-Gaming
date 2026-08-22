local addonName, LPL = ...

local LoadoutsModule = {
    id = "loadouts",
    label = "Loadouts",
    description = "Combine talents, action bars, equipment, and more into full loadouts.",
    iconStem = "builds_64",
    order = 10,
    instance = nil,
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.LoadoutStore:CreateDraftSet(LPL.LoadoutStore:SuggestSetName())
    end
    local draft = {
        name = set.name,
        restrictions = CopyTable(set.restrictions or {}),
    }
    for _, def in ipairs(LPL.LoadoutStore.SEGMENT_DEFS or {}) do
        local ids = LPL.LoadoutStore:GetSegmentIDs(set, def.plural)
        draft[def.plural] = CopyTable(ids)
        draft[def.singular] = ids[1]
    end
    return draft
end

local function ApplyLoadoutRestrictions(record)
    if not record or not LPL.SetRestrictions then
        return
    end
    record.restrictions = LPL.SetRestrictions:NormalizeRestrictions(record.restrictions or {})
    if record.restrictions and next(record.restrictions) then
        record.classID = LPL.SetRestrictions:GetEffectiveActionBarClassID(record)
    else
        local buildIDs = LPL.LoadoutStore and LPL.LoadoutStore:GetSegmentIDs(record, "talentBuildIDs") or {}
        local build = buildIDs[1] and LPL.TalentStore and LPL.TalentStore:Get(buildIDs[1])
        if build and build.classID then
            record.classID = tonumber(build.classID)
            record.specID = nil
            record.subTreeID = nil
        else
            record.classID = nil
            record.specID = nil
            record.subTreeID = nil
        end
    end
    LPL.SetRestrictions:UpdateActionBarSetFilters(record)
end

local function DestroyEditor(frame)
    if frame.loadoutEditor then
        LPL.LoadoutEditor:Destroy(frame.loadoutEditor)
        frame.loadoutEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.loadoutEditor = LPL.LoadoutEditor:Create(frame.editorView)
    return frame.loadoutEditor
end

local function RefreshEditor(frame)
    local editor = frame.loadoutEditor
    if not editor then
        editor = BuildEditor(frame)
    end
    if not editor then
        return
    end
    if frame.draftSet then
        ApplyLoadoutRestrictions(frame.draftSet)
        editor:SetDraftSet(frame.draftSet)
    else
        editor:Refresh()
    end
end

local function UpdateListViewLayout(frame, hasSets)
    frame.listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)
end

local function UpdateEditorViewLayout(frame)
    frame.editorView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
end

local function SelectSet(frame, setID)
    frame.selectedSetID = setID
    frame.setList:SetSelectedSetID(setID)
    frame.actionBar:SetListSelectionEnabled(setID ~= nil)
end

local function ShowListView(frame)
    frame.viewMode = "list"
    frame.activeSetID = nil
    frame.isNewSet = false
    frame.draftSet = nil
    DestroyEditor(frame)
    frame.listView:Show()
    frame.editorView:Hide()
    frame.editorView:EnableMouse(false)
    frame.setList:SetSelectedSetID(frame.selectedSetID)
    frame.setList:Refresh()
    local hasSets = #LPL.LoadoutStore:GetAll() > 0
    UpdateListViewLayout(frame, hasSets)
    frame.actionBar:SetMode("list", not hasSets)
    frame.actionBar:SetListSelectionEnabled(frame.selectedSetID ~= nil)
end

local function ShowEditorView(frame, setID, isNew)
    frame.viewMode = "editor"
    frame.isNewSet = isNew or false
    frame.editorView:EnableMouse(true)

    if isNew then
        frame.activeSetID = nil
        frame.draftSet = LPL.LoadoutStore:CreateDraftSet(LPL.LoadoutStore:SuggestSetName())
    elseif setID then
        local set = LPL.LoadoutStore:Get(setID)
        if not set then
            ShowListView(frame)
            return
        end
        frame.activeSetID = setID
        frame.selectedSetID = setID
        frame.draftSet = CopyDraftFromSet(set)
    else
        ShowListView(frame)
        return
    end

    ApplyLoadoutRestrictions(frame.draftSet)
    frame.listView:Hide()
    frame.editorView:Show()
    UpdateEditorViewLayout(frame)
    BuildEditor(frame)
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.LoadoutStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, true)
    RefreshEditor(frame)
end

function LoadoutsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLLoadoutsModule", parent)
    frame:SetAllPoints(parent)

    frame.viewMode = "list"
    frame.selectedSetID = nil
    frame.activeSetID = nil
    frame.isNewSet = false
    frame.draftSet = nil

    local actionBar = LPL.TalentActionBar:Create(frame, {
        onBack = function()
            ShowListView(frame)
        end,
        onEdit = function()
            if frame.selectedSetID then
                ShowEditorView(frame, frame.selectedSetID, false)
            end
        end,
        onActivate = function()
            if frame.viewMode == "editor" and frame.draftSet then
                ApplyLoadoutRestrictions(frame.draftSet)
                local name = frame.actionBar:GetBuildName()
                LPL.LoadoutActivate:ApplyDraft(frame.draftSet, name)
                return
            end
            if not frame.selectedSetID then
                print("|cffff6060LPL:|r Select a loadout to activate.")
                return
            end
            LPL.LoadoutActivate:ApplySet(frame.selectedSetID)
        end,
        onExport = function()
            local exportText, err
            local exportName

            if frame.viewMode == "editor" and frame.draftSet then
                ApplyLoadoutRestrictions(frame.draftSet)
                exportName = frame.actionBar:GetBuildName()
                exportText, err = LPL.LoadoutShare:ExportDraft(frame.draftSet, exportName)
            elseif frame.selectedSetID then
                local set = LPL.LoadoutStore:Get(frame.selectedSetID)
                if set then
                    exportName = set.name
                    exportText, err = LPL.LoadoutShare:ExportSet(set)
                end
            end

            if exportText and exportText ~= "" then
                LPL.ImportExport:OpenExport(exportText, exportName)
            else
                print("|cffff6060LPL:|r " .. (err or "Select or edit a loadout to export."))
            end
        end,
        onImport = function()
            LPL.ImportExport:OpenImport()
        end,
        onUpdate = function()
            if not frame.draftSet then
                return
            end
            RefreshEditor(frame)
            print("|cff33cc33LPL:|r Refreshed available segment sets.")
        end,
        onReset = function()
            if not frame.draftSet then
                return
            end
            for _, def in ipairs(LPL.LoadoutStore.SEGMENT_DEFS or {}) do
                frame.draftSet[def.plural] = {}
                frame.draftSet[def.singular] = nil
            end
            ApplyLoadoutRestrictions(frame.draftSet)
            RefreshEditor(frame)
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            ApplyLoadoutRestrictions(frame.draftSet)
            local name = frame.actionBar:GetBuildName()
            LPL.LoadoutStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
                frame.selectedSetID = setID
                ShowListView(frame)
            end)
        end,
        onNewBuild = function()
            ShowEditorView(frame, nil, true)
        end,
        onDelete = function()
            local setID = frame.activeSetID or frame.selectedSetID
            if not setID then
                return
            end
            LPL.LoadoutStore:ConfirmDelete(setID, function()
                if setID == frame.activeSetID then
                    frame.activeSetID = nil
                    frame.draftSet = nil
                end
                frame.selectedSetID = nil
                if frame.viewMode == "list" then
                    frame.setList:Refresh()
                    local hasSets = #LPL.LoadoutStore:GetAll() > 0
                    UpdateListViewLayout(frame, hasSets)
                    frame.actionBar:SetMode("list", not hasSets)
                    frame.actionBar:SetListSelectionEnabled(false)
                else
                    ShowListView(frame)
                end
            end)
        end,
    }, {
        newButtonLabel = "+ New Loadout",
        nameLabel = "Loadout name",
    })

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local setList = LPL.LoadoutSetList:Create(listView, 0)
    setList:SetOnSelect(function(setID)
        if frame.selectedSetID == setID then
            SelectSet(frame, nil)
        else
            SelectSet(frame, setID)
        end
    end)
    setList:SetOnActivate(function(setID)
        SelectSet(frame, setID)
        ShowEditorView(frame, setID, false)
    end)
    setList:SetOnNewSet(function()
        ShowEditorView(frame, nil, true)
    end)

    local editorView = CreateFrame("Frame", nil, frame)
    editorView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    editorView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
    editorView:SetFrameLevel(frame:GetFrameLevel() + 1)
    editorView:EnableMouse(false)
    editorView:Hide()

    frame.actionBar = actionBar
    frame.listView = listView
    frame.editorView = editorView
    frame.setList = setList
    frame.loadoutEditor = nil

    LPL.RestrictionsMenu:Attach(actionBar.limitsButton, function()
        return frame.draftSet
    end, function()
        ApplyLoadoutRestrictions(frame.draftSet)
        if frame.activeSetID and frame.draftSet then
            local set = LPL.LoadoutStore:Get(frame.activeSetID)
            if set then
                set.restrictions = LPL.SetRestrictions:CopyRestrictions(frame.draftSet.restrictions)
                ApplyLoadoutRestrictions(set)
                LPL.LoadoutStore:CommitSet(set)
            end
        end
        RefreshEditor(frame)
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))

    LPL.RestrictionsMenu:Attach(actionBar.listLimitsButton, function()
        return frame.selectedSetID and LPL.LoadoutStore:Get(frame.selectedSetID)
    end, function(record)
        if not frame.selectedSetID or not record then
            return
        end
        local set = LPL.LoadoutStore:Get(frame.selectedSetID)
        if set then
            set.restrictions = LPL.SetRestrictions:CopyRestrictions(record.restrictions)
            ApplyLoadoutRestrictions(set)
            LPL.LoadoutStore:CommitSet(set)
            frame.setList:Refresh()
        end
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))

    function frame:ShowList()
        ShowListView(self)
    end

    function frame:Refresh()
        if self.viewMode == "list" then
            self.setList:SetSelectedSetID(self.selectedSetID)
            self.setList:Refresh()
            local hasSets = #LPL.LoadoutStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            self.actionBar:SetListSelectionEnabled(self.selectedSetID ~= nil)
        elseif self.viewMode == "editor" then
            RefreshEditor(self)
            self.actionBar:UpdateTreeActions(self.activeSetID ~= nil, true)
        end
    end

    frame:Hide()
    LoadoutsModule.instance = frame
    return frame
end

function LoadoutsModule:OnShow()
    if LPL.DB and LPL.DB.SyncFromGlobal then
        LPL.DB:SyncFromGlobal()
    end
    if LPL.LoadoutStore and LPL.LoadoutStore.MigrateStorage then
        LPL.LoadoutStore:MigrateStorage()
    end
    if self.instance then
        self.instance:ShowList()
        self.instance:Refresh()
    end
end

LPL.Modules:Register({
    id = LoadoutsModule.id,
    label = LoadoutsModule.label,
    description = LoadoutsModule.description,
    icon = LoadoutsModule.icon,
    iconStem = LoadoutsModule.iconStem,
    order = LoadoutsModule.order,
    create = LoadoutsModule.create,
    OnShow = function()
        LoadoutsModule:OnShow()
    end,
})
