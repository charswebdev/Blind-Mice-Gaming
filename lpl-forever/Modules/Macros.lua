local addonName, LPL = ...

local MacrosModule = {
    id = "macros",
    label = "Macro Manager",
    description = "Store macro name, icon, and body for sharing and reuse.",
    iconStem = "macros_64",
    order = 58,
    instance = nil,
}

local VAULT_BAR_OPTIONS = {
    newButtonLabel = "+ New Macro",
    nameLabel = "Macro name",
    editTooltip = "Edit the selected macro",
    showActivate = false,
    showUpdate = false,
    showReset = false,
    showLimits = false,
    showListImport = true,
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.MacroStore:CreateDraftSet()
    end
    return {
        name = set.name,
        icon = set.icon,
        body = set.body or "",
        sourceMacroIndex = set.sourceMacroIndex,
        sourceMacroScope = set.sourceMacroScope,
        sourceMacroName = set.sourceMacroName,
    }
end

local function DestroyEditor(frame)
    if frame.macroEditor then
        LPL.MacroEditor:Destroy(frame.macroEditor)
        frame.macroEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.macroEditor = LPL.MacroEditor:Create(frame.editorView)
    return frame.macroEditor
end

local function RefreshEditor(frame)
    local editor = frame.macroEditor
    if not editor then
        editor = BuildEditor(frame)
    end
    if not editor then
        return
    end
    if frame.draftSet then
        editor:SetDraft(frame.draftSet)
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

local function SetMouseTreeEnabled(root, enabled)
    if not root then
        return
    end
    root:EnableMouse(enabled)
    if root.EnableMouseWheel then
        root:EnableMouseWheel(enabled)
    end
    if root.SetMouseClickEnabled then
        root:SetMouseClickEnabled(enabled)
    end
    local children = { root:GetChildren() }
    for i = 1, #children do
        SetMouseTreeEnabled(children[i], enabled)
    end
end

local function ShowListView(frame)
    frame.viewMode = "list"
    frame.activeSetID = nil
    frame.isNewSet = false
    frame.draftSet = nil
    DestroyEditor(frame)
    frame.editorView:Hide()
    frame.editorView:EnableMouse(false)
    frame.listView:Show()
    SetMouseTreeEnabled(frame.listView, true)
    frame.setList:SetSelectedSetID(frame.selectedSetID)
    frame.setList:Refresh()
    local hasSets = #LPL.MacroStore:GetAll() > 0
    UpdateListViewLayout(frame, hasSets)
    frame.actionBar:SetMode("list", not hasSets)
    frame.actionBar:SetListSelectionEnabled(frame.selectedSetID ~= nil)
end

local function ShowEditorView(frame, setID, isNew)
    frame.viewMode = "editor"
    frame.isNewSet = isNew or false

    -- List can sit under the editor and still steal clicks if left mouse-enabled.
    frame.listView:Hide()
    SetMouseTreeEnabled(frame.listView, false)

    if isNew then
        frame.activeSetID = nil
        frame.draftSet = LPL.MacroStore:CreateDraftSet()
    elseif setID then
        local set = LPL.MacroStore:Get(setID)
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

    frame.editorView:SetFrameLevel(frame:GetFrameLevel() + 40)
    frame.editorView:EnableMouse(false)
    frame.editorView:Show()
    UpdateEditorViewLayout(frame)
    BuildEditor(frame)
    if frame.macroEditor and frame.macroEditor.SetOnNameLoaded then
        frame.macroEditor:SetOnNameLoaded(function(name)
            if name and name ~= "" then
                frame.actionBar:SetBuildName(name)
            end
        end)
    end
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.MacroStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, false)
    RefreshEditor(frame)
end

function MacrosModule.create(parent)
    local frame = CreateFrame("Frame", "LPLMacrosModule", parent)
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
        onImport = function()
            if LPL.ImportExport and LPL.ImportExport.OpenImport then
                LPL.ImportExport:OpenImport("macros")
            end
        end,
        onExport = function()
            local body
            if frame.viewMode == "editor" and frame.draftSet then
                if frame.macroEditor and frame.macroEditor.GetDraft then
                    frame.draftSet = frame.macroEditor:GetDraft() or frame.draftSet
                end
                body = frame.draftSet.body or ""
            elseif frame.selectedSetID then
                local set = LPL.MacroStore:Get(frame.selectedSetID)
                body = set and set.body or ""
            end
            if not body or body == "" then
                print("|cffffcc00LPL:|r Nothing to export — macro body is empty.")
                return
            end
            if LPL.ImportExport and LPL.ImportExport.OpenExport then
                LPL.ImportExport:OpenExport(body, "Macro body")
            end
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            local linkedIndex = frame.draftSet.sourceMacroIndex
            local linkedScope = frame.draftSet.sourceMacroScope
            local linkedName = frame.draftSet.sourceMacroName
            if frame.macroEditor and frame.macroEditor.GetDraft then
                frame.draftSet = frame.macroEditor:GetDraft() or frame.draftSet
            end
            -- Keep Blizzard link even if the editor draft table was replaced.
            frame.draftSet.sourceMacroIndex = frame.draftSet.sourceMacroIndex or linkedIndex
            frame.draftSet.sourceMacroScope = frame.draftSet.sourceMacroScope or linkedScope
            frame.draftSet.sourceMacroName = frame.draftSet.sourceMacroName or linkedName
            local name = frame.actionBar:GetBuildName()
            frame.draftSet.name = name
            LPL.MacroStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
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
            LPL.MacroStore:ConfirmDelete(setID, function()
                if setID == frame.activeSetID then
                    frame.activeSetID = nil
                    frame.draftSet = nil
                end
                frame.selectedSetID = nil
                if frame.viewMode == "list" then
                    frame.setList:Refresh()
                    local hasSets = #LPL.MacroStore:GetAll() > 0
                    UpdateListViewLayout(frame, hasSets)
                    frame.actionBar:SetMode("list", not hasSets)
                    frame.actionBar:SetListSelectionEnabled(false)
                else
                    ShowListView(frame)
                end
            end)
        end,
    }, VAULT_BAR_OPTIONS)

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local setList = LPL.MacroSetList:Create(listView, 0)
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
    frame.macroEditor = nil

    function frame:ShowList()
        ShowListView(self)
    end

    function frame:Refresh()
        if self.viewMode == "editor" then
            RefreshEditor(self)
        else
            self.setList:Refresh()
            local hasSets = #LPL.MacroStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            self.actionBar:SetListSelectionEnabled(self.selectedSetID ~= nil)
        end
    end

    ShowListView(frame)
    return frame
end

function MacrosModule:OnActivate(frame)
    if frame and frame.Refresh then
        frame:Refresh()
    end
end

LPL.Modules:Register(MacrosModule)
