local addonName, LPL = ...

local EquipmentModule = {
    id = "equipment",
    label = "Equipment",
    description = "Save, edit, and activate equipment layouts.",
    iconStem = "equipment_64",
    order = 50,
    instance = nil,
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.EquipmentStore:CreateDraftSet(LPL.EquipmentStore:SuggestSetName())
    end
    return {
        name = set.name,
        slots = CopyTable(set.slots or {}),
        ignored = CopyTable(set.ignored or {}),
        restrictions = CopyTable(set.restrictions or {}),
    }
end

local function DestroyEquipmentEditor(frame)
    if frame.equipmentEditor then
        LPL.EquipmentEditor:Destroy(frame.equipmentEditor)
        frame.equipmentEditor = nil
    end
end

local function BuildEquipmentEditor(frame)
    DestroyEquipmentEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.equipmentEditor = LPL.EquipmentEditor:Create(frame.editorView)
    return frame.equipmentEditor
end
local function RefreshEditor(frame)
    local editor = frame.equipmentEditor
    if not editor then
        editor = BuildEquipmentEditor(frame)
    end
    if not editor then
        return
    end
    if frame.draftSet then
        editor:SetDraftSet(frame.draftSet)
    else
        editor:Refresh()
    end
end

local function UpdateListViewLayout(frame, hasSets)
    local bottomInset = hasSets and LPL.TalentActionBar.LIST_HEIGHT or 0
    frame.listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomInset)
end

local function UpdateEditorViewLayout(frame)
    frame.editorView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
end

local function ConfigureListToolbar(frame, hasSelection)
    frame.actionBar:SetListSelectionEnabled(hasSelection)
end

local function SelectSet(frame, setID)
    frame.selectedSetID = setID
    frame.setList:SetSelectedSetID(setID)
    ConfigureListToolbar(frame, setID ~= nil)
end

local function ShowListView(frame)
    frame.viewMode = "list"
    frame.activeSetID = nil
    frame.isNewSet = false
    frame.draftSet = nil
    DestroyEquipmentEditor(frame)
    frame.listView:Show()
    frame.editorView:Hide()
    frame.editorView:EnableMouse(false)
    frame.setList:SetSelectedSetID(frame.selectedSetID)
    frame.setList:Refresh()
    local hasSets = #LPL.EquipmentStore:GetAll() > 0
    UpdateListViewLayout(frame, hasSets)
    frame.actionBar:SetMode("list", not hasSets)
    ConfigureListToolbar(frame, frame.selectedSetID ~= nil)
end

local function ShowEditorView(frame, setID, isNew)
    frame.viewMode = "editor"
    frame.isNewSet = isNew or false
    frame.editorView:EnableMouse(true)

    if isNew then
        frame.activeSetID = nil
        if setID then
            local set = LPL.EquipmentStore:Get(setID)
            frame.draftSet = CopyDraftFromSet(set)
            frame.selectedSetID = setID
        else
            frame.draftSet = LPL.EquipmentStore:CreateDraftSet(LPL.EquipmentStore:SuggestSetName())
        end
    elseif setID then
        local set = LPL.EquipmentStore:Get(setID)
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

    frame.listView:Hide()
    frame.editorView:Show()
    UpdateEditorViewLayout(frame)
    BuildEquipmentEditor(frame)
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.EquipmentStore:SuggestSetName())
    if LPL.EquipmentCodec and LPL.EquipmentCodec.SanitizeDraft then
        LPL.EquipmentCodec:SanitizeDraft(frame.draftSet)
    end
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, true)
    RefreshEditor(frame)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if frame.editorView and frame.editorView:IsShown() then
                RefreshEditor(frame)
            end
        end)
    end
end

function EquipmentModule.create(parent)
    local frame = CreateFrame("Frame", "LPLEquipmentModule", parent)
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
                local draftRecord = {
                    restrictions = frame.draftSet.restrictions,
                    filters = frame.draftSet.filters,
                }
                if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(draftRecord) then
                    local summary = LPL.SetRestrictions:GetSummaryLine(frame.draftSet.restrictions) or "another character, class, or specialization"
                    print("|cffff6060LPL:|r This equipment set is restricted to " .. summary .. ".")
                    return
                end
                LPL.EquipmentActivate:ApplyDraft(frame.draftSet, frame.actionBar:GetBuildName(), frame)
            elseif frame.selectedSetID then
                local set = LPL.EquipmentStore:Get(frame.selectedSetID)
                if set and LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(set) then
                    local summary = LPL.SetRestrictions:GetSummaryLine(set.restrictions) or "another character, class, or specialization"
                    print("|cffff6060LPL:|r This equipment set is restricted to " .. summary .. ".")
                    return
                end
                LPL.EquipmentActivate:ApplySet(frame.selectedSetID, frame)
            end
        end,
        onExport = function()
            local exportText, err
            local exportName
            if frame.viewMode == "editor" and frame.draftSet then
                exportName = frame.actionBar:GetBuildName()
                if LPL.EquipmentCodec and LPL.EquipmentCodec.SanitizeDraft then
                    LPL.EquipmentCodec:SanitizeDraft(frame.draftSet)
                end
                exportText, err = LPL.EquipmentShare:ExportDraft(frame.draftSet, exportName)
            elseif frame.selectedSetID then
                local set = LPL.EquipmentStore:Get(frame.selectedSetID)
                if set then
                    exportName = set.name
                    exportText, err = LPL.EquipmentShare:ExportSet(set)
                end
            end
            if exportText and exportText ~= "" then
                LPL.ImportExport:OpenExport(exportText, exportName)
            else
                print("|cffff6060LPL:|r " .. (err or "Select or edit an equipment set to export."))
            end
        end,
        onImport = function()
            LPL.ImportExport:OpenImport()
        end,
        onUpdate = function()
            if not frame.draftSet then
                return
            end
            local ok, err = LPL.EquipmentCodec:CanEdit()
            if not ok then
                print("|cffff6060LPL:|r " .. (err or "Cannot edit equipment sets in combat."))
                return
            end
            local filled = LPL.EquipmentCodec:CaptureFromCharacter(frame.draftSet)
            RefreshEditor(frame)
            print(string.format("|cff33cc33LPL:|r Loaded %d equipped item%s.", filled, filled == 1 and "" or "s"))
        end,
        onReset = function()
            if not frame.draftSet then
                return
            end
            frame.draftSet.slots = {}
            if LPL.EquipmentCodec and LPL.EquipmentCodec.SanitizeDraft then
                LPL.EquipmentCodec:SanitizeDraft(frame.draftSet)
            end
            RefreshEditor(frame)
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            local name = frame.actionBar:GetBuildName()
            LPL.EquipmentStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(savedID)
                frame.selectedSetID = savedID
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
            LPL.EquipmentStore:ConfirmDelete(setID, function()
                if setID == frame.activeSetID then
                    frame.activeSetID = nil
                    frame.draftSet = nil
                end
                frame.selectedSetID = nil
                ShowListView(frame)
            end)
        end,
    }, {
        newButtonLabel = "+ New Set",
        nameLabel = "Set name",
    })

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local setList = LPL.EquipmentSetList:Create(listView, 0)
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
    frame.equipmentEditor = nil
    local function ApplyEquipmentRestrictions(record)
        if not record or not LPL.SetRestrictions then
            return
        end
        LPL.SetRestrictions:UpdateEquipmentSetFilters(record)
        if not record.classID then
            record.classID = LPL.SetRestrictions:GetEffectiveEquipmentClassID(record)
        end
    end
    LPL.RestrictionsMenu:Attach(actionBar.limitsButton, function()
        return frame.draftSet
    end, function()
        ApplyEquipmentRestrictions(frame.draftSet)
        if frame.activeSetID and frame.draftSet then
            local set = LPL.EquipmentStore:Get(frame.activeSetID)
            if set then
                set.restrictions = LPL.SetRestrictions:CopyRestrictions(frame.draftSet.restrictions)
                ApplyEquipmentRestrictions(set)
                LPL.EquipmentStore:CommitSet(set)
            end
        end
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))
    LPL.RestrictionsMenu:Attach(actionBar.listLimitsButton, function()
        return frame.selectedSetID and LPL.EquipmentStore:Get(frame.selectedSetID)
    end, function(record)
        if not frame.selectedSetID or not record then
            return
        end
        local set = LPL.EquipmentStore:Get(frame.selectedSetID)
        if set then
            set.restrictions = LPL.SetRestrictions:CopyRestrictions(record.restrictions)
            ApplyEquipmentRestrictions(set)
            LPL.EquipmentStore:CommitSet(set)
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
            local hasSets = #LPL.EquipmentStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            ConfigureListToolbar(self, self.selectedSetID ~= nil)
        elseif self.viewMode == "editor" then
            RefreshEditor(self)
            self.actionBar:UpdateTreeActions(self.activeSetID ~= nil, true)
        end
    end

    frame:Hide()
    EquipmentModule.instance = frame
    return frame
end

function EquipmentModule:OnShow()
    if LPL.DB and LPL.DB.SyncFromGlobal then
        LPL.DB:SyncFromGlobal()
    end
    if LPL.EquipmentStore and LPL.EquipmentStore.MigrateStorage then
        LPL.EquipmentStore:MigrateStorage()
    end
    if self.instance then
        if self.instance.viewMode == "editor" then
            self.instance:Refresh()
        else
            self.instance:ShowList()
            self.instance:Refresh()
        end
    end
end

LPL.Modules:Register({
    id = EquipmentModule.id,
    label = EquipmentModule.label,
    description = EquipmentModule.description,
    iconStem = EquipmentModule.iconStem,
    order = EquipmentModule.order,
    create = EquipmentModule.create,
    OnShow = function()
        EquipmentModule:OnShow()
    end,
})
