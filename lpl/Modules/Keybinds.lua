local addonName, LPL = ...

local KeybindsModule = {
    id = "keybinds",
    label = "Keybinding Profiles",
    description = "Save and activate account-wide or character keybinding profiles.",
    iconStem = "keybinds_64",
    order = 45,
    instance = nil,
}

local VAULT_BAR_OPTIONS = {
    newButtonLabel = "+ New Profile",
    newButtonWidth = 118,
    newButtonTooltipTitle = "New Profile",
    newButtonTooltipBody = "Create a keybinding profile from your current live binds",
    nameLabel = "Profile name",
    editTooltip = "Edit the selected keybinding profile",
    showActivate = true,
    activateButtonWidth = 80,
    activateTooltipTitle = "Activate",
    activateTooltipBody = "Replace all current key bindings with the selected profile",
    showEnableSet = false,
    showDisableSet = false,
    showUpdate = true,
    updateTooltipTitle = "Update",
    updateTooltipBody = "Fill this profile from your current live key bindings",
    updateTooltipDisabled = "Open a profile in the editor to update from live binds.",
    showReset = false,
    showLimits = false,
    showExport = true,
    showImport = true,
    showListImport = true,
    backTooltipTitle = "Back",
    backTooltipBody = "Return to the keybinding profile list",
    saveTooltipTitle = "Save",
    saveTooltipBody = "Save this profile name, scope, and key bindings",
    deleteTooltipTitle = "Delete",
    deleteTooltipBody = "Remove the selected keybinding profile from your library",
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.KeybindStore:CreateDraftSet()
    end
    return {
        name = set.name,
        scope = set.scope or LPL.KeybindStore.SCOPE_ACCOUNT,
        bindings = CopyTable(set.bindings or {}),
    }
end

local function DestroyEditor(frame)
    if frame.keybindEditor then
        LPL.KeybindEditor:Destroy(frame.keybindEditor)
        frame.keybindEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.keybindEditor = LPL.KeybindEditor:Create(frame.editorView)
    return frame.keybindEditor
end

local function RefreshEditor(frame)
    local editor = frame.keybindEditor
    if not editor then
        editor = BuildEditor(frame)
    end
    if not editor then
        return
    end
    if frame.draftSet then
        editor:SetDraft(frame.draftSet, frame.activeSetID)
    else
        editor:Refresh()
    end
end

local function UpdateListViewLayout(frame, hasSets)
    local bottomInset = hasSets and LPL.TalentActionBar.LIST_HEIGHT or 0
    frame.listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomInset)
end

local function UpdateEditorViewLayout(frame)
    frame.editorView:ClearAllPoints()
    frame.editorView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.editorView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
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
    local hasSets = #LPL.KeybindStore:GetAll() > 0
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
        frame.draftSet = LPL.KeybindStore:CreateDraftSet()
    elseif setID then
        local set = LPL.KeybindStore:Get(setID)
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
    BuildEditor(frame)
    frame.actionBar:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.KeybindStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, true)
    RefreshEditor(frame)
end

function KeybindsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLKeybindsModule", parent)
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
                if frame.keybindEditor and frame.keybindEditor.GetDraft then
                    frame.draftSet = frame.keybindEditor:GetDraft() or frame.draftSet
                end
                local name = frame.actionBar:GetBuildName()
                frame.draftSet.name = name
                LPL.KeybindActivate:ApplyDraft(frame.draftSet, name)
                return
            end
            if frame.selectedSetID then
                LPL.KeybindActivate:ApplySet(frame.selectedSetID)
            else
                print("|cffff6060LPL:|r Select a keybinding profile to activate.")
            end
            if frame.viewMode == "list" then
                frame.setList:Refresh()
            end
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            if frame.keybindEditor and frame.keybindEditor.GetDraft then
                frame.draftSet = frame.keybindEditor:GetDraft() or frame.draftSet
            end
            local name = frame.actionBar:GetBuildName()
            frame.draftSet.name = name
            LPL.KeybindStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
                frame.selectedSetID = setID
                ShowListView(frame)
            end)
        end,
        onUpdate = function()
            if not frame.draftSet then
                return
            end
            if frame.keybindEditor and frame.keybindEditor.UpdateFromLive then
                frame.keybindEditor:UpdateFromLive()
                frame.draftSet = frame.keybindEditor:GetDraft() or frame.draftSet
            end
        end,
        onExport = function()
            local exportText, err
            local exportName

            if frame.viewMode == "editor" and frame.draftSet then
                if frame.keybindEditor and frame.keybindEditor.GetDraft then
                    frame.draftSet = frame.keybindEditor:GetDraft() or frame.draftSet
                end
                exportName = frame.actionBar:GetBuildName()
                frame.draftSet.name = exportName
                exportText, err = LPL.KeybindShare:ExportDraft(frame.draftSet, exportName)
            elseif frame.selectedSetID then
                local set = LPL.KeybindStore:Get(frame.selectedSetID)
                if set then
                    exportName = set.name
                    exportText, err = LPL.KeybindShare:ExportSet(set)
                end
            end

            if exportText and exportText ~= "" then
                LPL.ImportExport:OpenExport(exportText, exportName)
            else
                print("|cffff6060LPL:|r " .. (err or "Select or edit a keybinding profile to export."))
            end
        end,
        onImport = function()
            LPL.ImportExport:OpenImport()
        end,
        onNewBuild = function()
            ShowEditorView(frame, nil, true)
        end,
        onDelete = function()
            if frame.viewMode == "editor" then
                local setID = frame.activeSetID
                if not setID then
                    return
                end
                LPL.KeybindStore:ConfirmDelete(setID, function()
                    frame.activeSetID = nil
                    frame.draftSet = nil
                    frame.selectedSetID = nil
                    ShowListView(frame)
                end)
                return
            end

            local setID = frame.selectedSetID
            if not setID then
                return
            end
            LPL.KeybindStore:ConfirmDelete(setID, function()
                frame.selectedSetID = nil
                frame.setList:Refresh()
                local hasSets = #LPL.KeybindStore:GetAll() > 0
                UpdateListViewLayout(frame, hasSets)
                frame.actionBar:SetMode("list", not hasSets)
                frame.actionBar:SetListSelectionEnabled(false)
            end)
        end,
    }, VAULT_BAR_OPTIONS)

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local setList = LPL.KeybindSetList:Create(listView, 0)
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
    editorView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    editorView:SetFrameLevel(frame:GetFrameLevel() + 1)
    editorView:EnableMouse(false)
    editorView:Hide()

    frame.actionBar = actionBar
    frame.listView = listView
    frame.editorView = editorView
    frame.setList = setList
    frame.keybindEditor = nil

    function frame:ShowList()
        ShowListView(self)
    end

    function frame:Refresh()
        if self.viewMode == "editor" then
            RefreshEditor(self)
        else
            self.setList:Refresh()
            local hasSets = #LPL.KeybindStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            self.actionBar:SetListSelectionEnabled(self.selectedSetID ~= nil)
        end
    end

    ShowListView(frame)
    return frame
end

function KeybindsModule:OnShow()
    if self.instance and self.instance.Refresh then
        self.instance:Refresh()
    end
end

function KeybindsModule:OnActivate(frame)
    if frame and frame.Refresh then
        frame:Refresh()
    end
end

LPL.Modules:Register(KeybindsModule)
