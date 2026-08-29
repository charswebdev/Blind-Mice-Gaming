local addonName, LPL = ...

local HousingModule = {
    id = "housing",
    label = "Housing Blueprints",
    description = "Store Blizzard player-housing blueprint codes for copy and paste.",
    iconStem = "housing_64",
    order = 61,
    instance = nil,
}

local VAULT_BAR_OPTIONS = {
    newButtonLabel = "+ New Blueprint",
    nameLabel = "Blueprint name",
    editTooltip = "Edit the selected housing blueprint",
    showActivate = true,
    activateButtonLabel = "Copy for House",
    activateButtonWidth = 128,
    activateTooltipTitle = "Copy for House",
    activateTooltipBody = "Copy the blueprint code to the clipboard. On your plot: Housing HUD → Blueprint → Import. After a good import, re-save in-game. LPL does not place the house.",
    showUpdate = false,
    showReset = false,
    showLimits = false,
    showListImport = true,
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.HousingStore:CreateDraftSet()
    end
    return {
        name = set.name,
        code = set.code or "",
        notes = set.notes or "",
    }
end

local function DestroyEditor(frame)
    if frame.housingEditor then
        LPL.HousingEditor:Destroy(frame.housingEditor)
        frame.housingEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.housingEditor = LPL.HousingEditor:Create(frame.editorView)
    return frame.housingEditor
end

local function RefreshEditor(frame)
    local editor = frame.housingEditor
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

local function UpdateListViewLayout(frame)
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
    local hasSets = #LPL.HousingStore:GetAll() > 0
    UpdateListViewLayout(frame)
    frame.actionBar:SetMode("list", not hasSets)
    frame.actionBar:SetListSelectionEnabled(frame.selectedSetID ~= nil)
end

local function ShowEditorView(frame, setID, isNew)
    frame.viewMode = "editor"
    frame.isNewSet = isNew or false

    frame.listView:Hide()
    SetMouseTreeEnabled(frame.listView, false)

    if isNew then
        frame.activeSetID = nil
        frame.draftSet = LPL.HousingStore:CreateDraftSet()
    elseif setID then
        local set = LPL.HousingStore:Get(setID)
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
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.HousingStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, false)
    RefreshEditor(frame)
end

function HousingModule.create(parent)
    local frame = CreateFrame("Frame", "LPLHousingModule", parent)
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
            LPL.HousingStore:CopyForHouse(frame.selectedSetID)
        end,
        onImport = function()
            if LPL.ImportExport and LPL.ImportExport.OpenImport then
                LPL.ImportExport:OpenImport("housing")
            end
        end,
        onExport = function()
            local payload
            if frame.viewMode == "editor" and frame.draftSet then
                if frame.housingEditor and frame.housingEditor.GetDraft then
                    frame.draftSet = frame.housingEditor:GetDraft() or frame.draftSet
                end
                payload = frame.draftSet.code or ""
            elseif frame.selectedSetID then
                local set = LPL.HousingStore:Get(frame.selectedSetID)
                payload = set and set.code or ""
            end
            if not payload or payload == "" then
                print("|cffffcc00LPL:|r Nothing to export — blueprint code is empty.")
                return
            end
            if LPL.ImportExport and LPL.ImportExport.OpenExport then
                LPL.ImportExport:OpenExport(payload, "Housing blueprint code")
            end
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            if frame.housingEditor and frame.housingEditor.GetDraft then
                frame.draftSet = frame.housingEditor:GetDraft() or frame.draftSet
            end
            local name = frame.actionBar:GetBuildName()
            frame.draftSet.name = name
            LPL.HousingStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
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
            LPL.HousingStore:ConfirmDelete(setID, function()
                if setID == frame.activeSetID then
                    frame.activeSetID = nil
                    frame.draftSet = nil
                end
                frame.selectedSetID = nil
                if frame.viewMode == "list" then
                    frame.setList:Refresh()
                    local hasSets = #LPL.HousingStore:GetAll() > 0
                    UpdateListViewLayout(frame)
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

    local setList = LPL.HousingSetList:Create(listView, 0)
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
    frame.housingEditor = nil

    function frame:ShowList()
        ShowListView(self)
    end

    function frame:Refresh()
        if self.viewMode == "editor" then
            RefreshEditor(self)
        else
            self.setList:Refresh()
            local hasSets = #LPL.HousingStore:GetAll() > 0
            UpdateListViewLayout(self)
            self.actionBar:SetMode("list", not hasSets)
            self.actionBar:SetListSelectionEnabled(self.selectedSetID ~= nil)
        end
    end

    ShowListView(frame)
    return frame
end

function HousingModule:OnActivate(frame)
    if frame and frame.Refresh then
        frame:Refresh()
    end
end

LPL.Modules:Register(HousingModule)
