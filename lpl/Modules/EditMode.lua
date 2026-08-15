local addonName, LPL = ...

local EditModeModule = {
    id = "editmode",
    label = "Edit Mode",
    description = "Save and activate Blizzard Edit Mode layout strings.",
    iconStem = "editmode_64",
    order = 55,
    instance = nil,
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.EditModeStore:CreateDraftSet(LPL.EditModeStore:SuggestSetName())
    end
    return {
        name = set.name,
        layoutString = set.layoutString or "",
        editModeCharacterSpecific = set.editModeCharacterSpecific ~= false,
        restrictions = CopyTable(set.restrictions or {}),
    }
end

local function ApplyEditModeRestrictions(record)
    if not record or not LPL.SetRestrictions then
        return
    end
    record.restrictions = LPL.SetRestrictions:NormalizeRestrictions(record.restrictions or {})
    if record.restrictions and next(record.restrictions) then
        record.classID = LPL.SetRestrictions:GetEffectiveActionBarClassID(record)
    else
        record.classID = nil
        record.specID = nil
        record.subTreeID = nil
    end
    LPL.SetRestrictions:UpdateActionBarSetFilters(record)
end

local function DestroyEditor(frame)
    if frame.editModeEditor then
        LPL.EditModeEditor:Destroy(frame.editModeEditor)
        frame.editModeEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.editModeEditor = LPL.EditModeEditor:Create(frame.editorView)
    return frame.editModeEditor
end

local function RefreshEditor(frame)
    local editor = frame.editModeEditor
    if not editor then
        editor = BuildEditor(frame)
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

local function SyncDraftFromEditor(frame)
    if frame.editModeEditor and frame.editModeEditor.SyncDraftFromInput then
        frame.editModeEditor:SyncDraftFromInput()
    end
    if frame.draftSet and LPL.EditModeCodec then
        LPL.EditModeCodec:SanitizeDraft(frame.draftSet)
    end
end

local function UpdateListViewLayout(frame, hasSets)
    local bottomInset = hasSets and LPL.TalentActionBar.LIST_HEIGHT or 0
    frame.listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomInset)
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
    local hasSets = #LPL.EditModeStore:GetAll() > 0
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
        frame.draftSet = LPL.EditModeStore:CreateDraftSet(LPL.EditModeStore:SuggestSetName())
    elseif setID then
        local set = LPL.EditModeStore:Get(setID)
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

    if LPL.EditModeCodec then
        LPL.EditModeCodec:SanitizeDraft(frame.draftSet)
    end

    frame.listView:Hide()
    frame.editorView:Show()
    UpdateEditorViewLayout(frame)
    BuildEditor(frame)
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.EditModeStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, true)
    RefreshEditor(frame)
end

function EditModeModule.create(parent)
    local frame = CreateFrame("Frame", "LPLEditModeModule", parent)
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
                SyncDraftFromEditor(frame)
                local draftRecord = {
                    restrictions = frame.draftSet.restrictions,
                    filters = frame.draftSet.filters,
                    layoutString = frame.draftSet.layoutString,
                    editModeCharacterSpecific = frame.draftSet.editModeCharacterSpecific,
                }
                if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(draftRecord) then
                    local summary = LPL.SetRestrictions:GetSummaryLine(frame.draftSet.restrictions)
                        or "another character, class, or specialization"
                    print("|cffff6060LPL:|r This Edit Mode layout is restricted to " .. summary .. ".")
                    return
                end
                LPL.EditModeActivate:ApplyDraft(frame.draftSet, frame.actionBar:GetBuildName())
                if EditModeModule.RefreshActiveSoon then
                    EditModeModule.RefreshActiveSoon()
                end
            elseif frame.selectedSetID then
                local set = LPL.EditModeStore:Get(frame.selectedSetID)
                if set and LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(set) then
                    local summary = LPL.SetRestrictions:GetSummaryLine(set.restrictions)
                        or "another character, class, or specialization"
                    print("|cffff6060LPL:|r This Edit Mode layout is restricted to " .. summary .. ".")
                    return
                end
                LPL.EditModeActivate:ApplySet(frame.selectedSetID)
                if EditModeModule.RefreshActiveSoon then
                    EditModeModule.RefreshActiveSoon()
                end
            else
                print("|cffff6060LPL:|r Select or edit an Edit Mode layout to activate.")
            end
            if frame.viewMode == "list" then
                frame.setList:Refresh()
            end
        end,
        onExport = function()
            local exportText, err
            local exportName

            if frame.viewMode == "editor" and frame.draftSet then
                SyncDraftFromEditor(frame)
                exportName = frame.actionBar:GetBuildName()
                exportText, err = LPL.EditModeShare:ExportDraft(frame.draftSet, exportName)
            elseif frame.selectedSetID then
                local set = LPL.EditModeStore:Get(frame.selectedSetID)
                if set then
                    exportName = set.name
                    exportText, err = LPL.EditModeShare:ExportSet(set)
                end
            end

            if exportText and exportText ~= "" then
                LPL.ImportExport:OpenExport(exportText, exportName)
            else
                print("|cffff6060LPL:|r " .. (err or "Select or edit an Edit Mode layout to export."))
            end
        end,
        onImport = function()
            LPL.ImportExport:OpenImport()
        end,
        onUpdate = function()
            if not frame.draftSet then
                return
            end
            local ok, err = LPL.EditModeCodec:CanCaptureFromCharacter()
            if not ok then
                print("|cffff6060LPL:|r " .. (err or "Cannot update from character."))
                return
            end
            local captured, captureErr = LPL.EditModeCodec:CaptureFromCharacter(frame.draftSet)
            if not captured then
                print("|cffff6060LPL:|r " .. (captureErr or "Failed to read Edit Mode layout."))
                return
            end
            RefreshEditor(frame)
            print("|cff33cc33LPL:|r Loaded Edit Mode layout from your character.")
        end,
        onReset = function()
            if not frame.draftSet then
                return
            end
            frame.draftSet.layoutString = ""
            RefreshEditor(frame)
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            SyncDraftFromEditor(frame)
            local name = frame.actionBar:GetBuildName()
            LPL.EditModeStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
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
            LPL.EditModeStore:ConfirmDelete(setID, function()
                if setID == frame.activeSetID then
                    frame.activeSetID = nil
                    frame.draftSet = nil
                end
                frame.selectedSetID = nil
                if frame.viewMode == "list" then
                    frame.setList:Refresh()
                    local hasSets = #LPL.EditModeStore:GetAll() > 0
                    UpdateListViewLayout(frame, hasSets)
                    frame.actionBar:SetMode("list", not hasSets)
                    frame.actionBar:SetListSelectionEnabled(false)
                else
                    ShowListView(frame)
                end
            end)
        end,
    }, {
        newButtonLabel = "+ New Layout",
        nameLabel = "Layout name",
    })

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local setList = LPL.EditModeSetList:Create(listView, 0)
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
    frame.editModeEditor = nil

    LPL.RestrictionsMenu:Attach(actionBar.limitsButton, function()
        return frame.draftSet
    end, function()
        SyncDraftFromEditor(frame)
        ApplyEditModeRestrictions(frame.draftSet)
        if frame.activeSetID and frame.draftSet then
            local set = LPL.EditModeStore:Get(frame.activeSetID)
            if set then
                set.restrictions = LPL.SetRestrictions:CopyRestrictions(frame.draftSet.restrictions)
                ApplyEditModeRestrictions(set)
                LPL.EditModeStore:CommitSet(set)
            end
        end
        RefreshEditor(frame)
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))

    LPL.RestrictionsMenu:Attach(actionBar.listLimitsButton, function()
        return frame.selectedSetID and LPL.EditModeStore:Get(frame.selectedSetID)
    end, function(record)
        if not frame.selectedSetID or not record then
            return
        end
        local set = LPL.EditModeStore:Get(frame.selectedSetID)
        if set then
            set.restrictions = LPL.SetRestrictions:CopyRestrictions(record.restrictions)
            ApplyEditModeRestrictions(set)
            LPL.EditModeStore:CommitSet(set)
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
            local hasSets = #LPL.EditModeStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            self.actionBar:SetListSelectionEnabled(self.selectedSetID ~= nil)
        elseif self.viewMode == "editor" then
            RefreshEditor(self)
            self.actionBar:UpdateTreeActions(self.activeSetID ~= nil, true)
        end
    end

    frame:Hide()
    EditModeModule.instance = frame

    if not EditModeModule.eventFrame then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("EDIT_MODE_LAYOUTS_UPDATED") then
            eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
        elseif eventFrame.RegisterEvent then
            pcall(eventFrame.RegisterEvent, eventFrame, "EDIT_MODE_LAYOUTS_UPDATED")
        end
        eventFrame:SetScript("OnEvent", function()
            local instance = EditModeModule.instance
            if instance and instance:IsShown() and instance.viewMode == "list" and instance.setList then
                instance.setList:Refresh()
            end
        end)
        EditModeModule.RefreshActiveSoon = function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.2, function()
                    local instance = EditModeModule.instance
                    if instance and instance:IsShown() and instance.viewMode == "list" and instance.setList then
                        instance.setList:Refresh()
                    end
                end)
            end
        end
        EditModeModule.eventFrame = eventFrame
    end

    return frame
end

function EditModeModule:OnShow()
    if LPL.DB and LPL.DB.SyncFromGlobal then
        LPL.DB:SyncFromGlobal()
    end
    if LPL.EditModeStore and LPL.EditModeStore.MigrateStorage then
        LPL.EditModeStore:MigrateStorage()
    end
    if self.instance then
        self.instance:ShowList()
        self.instance:Refresh()
    end
end

LPL.Modules:Register({
    id = EditModeModule.id,
    label = EditModeModule.label,
    description = EditModeModule.description,
    icon = EditModeModule.icon,
    iconStem = EditModeModule.iconStem,
    order = EditModeModule.order,
    create = EditModeModule.create,
    OnShow = function()
        EditModeModule:OnShow()
    end,
})
