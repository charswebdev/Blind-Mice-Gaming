local addonName, LPL = ...

local AddonsManagerModule = {
    id = "addonsmanager",
    label = "Addons Manager",
    description = "Store other addons' profile strings for easy copy and paste.",
    iconStem = "addons_64",
    order = 60,
    instance = nil,
}

local VAULT_BAR_OPTIONS = {
    newButtonLabel = "+ New Addon Profile",
    nameLabel = "Profile name",
    editTooltip = "Edit the selected addon profile",
    showActivate = false,
    showUpdate = false,
    showReset = false,
    showLimits = false,
    showListImport = true,
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.AddonProfileStore:CreateDraftSet()
    end
    return {
        name = set.name,
        addonKey = set.addonKey or "custom",
        addonLabel = set.addonLabel or "",
        profileString = set.profileString or "",
        notes = set.notes or "",
    }
end

local function DestroyEditor(frame)
    if frame.addonProfileEditor then
        LPL.AddonProfileEditor:Destroy(frame.addonProfileEditor)
        frame.addonProfileEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.addonProfileEditor = LPL.AddonProfileEditor:Create(frame.editorView)
    return frame.addonProfileEditor
end

local function RefreshEditor(frame)
    local editor = frame.addonProfileEditor
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
    local hasSets = #LPL.AddonProfileStore:GetAll() > 0
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
        frame.draftSet = LPL.AddonProfileStore:CreateDraftSet()
    elseif setID then
        local set = LPL.AddonProfileStore:Get(setID)
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
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.AddonProfileStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, false)
    RefreshEditor(frame)
end

function AddonsManagerModule.create(parent)
    local frame = CreateFrame("Frame", "LPLAddonsManagerModule", parent)
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
                LPL.ImportExport:OpenImport("addonsmanager")
            end
        end,
        onExport = function()
            local payload
            if frame.viewMode == "editor" and frame.draftSet then
                if frame.addonProfileEditor and frame.addonProfileEditor.GetDraft then
                    frame.draftSet = frame.addonProfileEditor:GetDraft() or frame.draftSet
                end
                payload = frame.draftSet.profileString or ""
            elseif frame.selectedSetID then
                local set = LPL.AddonProfileStore:Get(frame.selectedSetID)
                payload = set and set.profileString or ""
            end
            if not payload or payload == "" then
                print("|cffffcc00LPL:|r Nothing to export — profile string is empty.")
                return
            end
            if LPL.ImportExport and LPL.ImportExport.OpenExport then
                LPL.ImportExport:OpenExport(payload, "Addon profile string")
            end
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            if frame.addonProfileEditor and frame.addonProfileEditor.GetDraft then
                frame.draftSet = frame.addonProfileEditor:GetDraft() or frame.draftSet
            end
            local name = frame.actionBar:GetBuildName()
            frame.draftSet.name = name
            LPL.AddonProfileStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
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
            LPL.AddonProfileStore:ConfirmDelete(setID, function()
                if setID == frame.activeSetID then
                    frame.activeSetID = nil
                    frame.draftSet = nil
                end
                frame.selectedSetID = nil
                if frame.viewMode == "list" then
                    frame.setList:Refresh()
                    local hasSets = #LPL.AddonProfileStore:GetAll() > 0
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

    local setList = LPL.AddonProfileSetList:Create(listView, 0)
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
    frame.addonProfileEditor = nil

    function frame:ShowList()
        ShowListView(self)
    end

    function frame:Refresh()
        if self.viewMode == "editor" then
            RefreshEditor(self)
        else
            self.setList:Refresh()
            local hasSets = #LPL.AddonProfileStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            self.actionBar:SetListSelectionEnabled(self.selectedSetID ~= nil)
        end
    end

    ShowListView(frame)
    return frame
end

function AddonsManagerModule:OnActivate(frame)
    if frame and frame.Refresh then
        frame:Refresh()
    end
end

LPL.Modules:Register(AddonsManagerModule)
