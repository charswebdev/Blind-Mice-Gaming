local addonName, LPL = ...

local ActionBarsModule = {
    id = "actionbars",
    label = "Action Bars",
    description = "Save, edit, and activate action bar layouts.",
    iconStem = "actionbars_64",
    order = 40,
    instance = nil,
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.ActionBarStore:CreateDraftSet(LPL.ActionBarStore:SuggestSetName())
    end
    return {
        name = set.name,
        actions = CopyTable(set.actions or {}),
        ignored = CopyTable(set.ignored or {}),
        petActions = CopyTable(set.petActions or {}),
        petIgnored = CopyTable(set.petIgnored or {}),
        restrictions = CopyTable(set.restrictions or {}),
        classID = set.classID,
        specID = set.specID,
        subTreeID = set.subTreeID,
    }
end

local function RefreshBarEditor(frame)
    if frame.barEditor and frame.draftSet then
        frame.barEditor:SetDraftSet(frame.draftSet)
    end
end

local function UpdateListViewLayout(frame, hasSets)
    local bottomInset = hasSets and LPL.TalentActionBar.LIST_HEIGHT or 0
    frame.listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomInset)
end

local function UpdateTreeViewLayout(frame)
    frame.treeView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
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
    LPL.ActionBarCursor:Clear()
    frame.listView:Show()
    frame.treeView:Hide()
    frame.treeView:EnableMouse(false)
    frame.setList:SetSelectedSetID(frame.selectedSetID)
    frame.setList:Refresh()
    local hasSets = #LPL.ActionBarStore:GetAll() > 0
    UpdateListViewLayout(frame, hasSets)
    frame.actionBar:SetMode("list", not hasSets)
    frame.actionBar:SetListSelectionEnabled(frame.selectedSetID ~= nil)
end

local function ShowTreeView(frame, setID, isNew)
    frame.viewMode = "tree"
    frame.isNewSet = isNew or false
    frame.treeView:EnableMouse(true)

    if isNew then
        frame.activeSetID = nil
        frame.draftSet = LPL.ActionBarStore:CreateDraftSet(LPL.ActionBarStore:SuggestSetName())
        LPL.ActionBarCodec:SanitizeDraft(frame.draftSet)
    elseif setID then
        local set = LPL.ActionBarStore:Get(setID)
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

    LPL.ActionBarCursor:Clear()
    LPL.ActionBarCodec:SanitizeDraft(frame.draftSet)

    frame.listView:Hide()
    frame.treeView:Show()
    UpdateTreeViewLayout(frame)
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.ActionBarStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, true)
    RefreshBarEditor(frame)
end

function ActionBarsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLActionBarsModule", parent)
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
                ShowTreeView(frame, frame.selectedSetID, false)
            end
        end,
        onActivate = function()
            if frame.viewMode == "tree" and frame.draftSet then
                local name = frame.actionBar:GetBuildName()
                LPL.ActionBarActivate:ApplyDraft(frame.draftSet, name)
            elseif frame.selectedSetID then
                LPL.ActionBarActivate:ApplySet(frame.selectedSetID)
            end
        end,
        onExport = function()
            local exportText, err
            local exportName

            if frame.viewMode == "tree" and frame.draftSet then
                exportName = frame.actionBar:GetBuildName()
                LPL.ActionBarCodec:SanitizeDraft(frame.draftSet)
                exportText, err = LPL.ActionBarShare:ExportDraft(frame.draftSet, exportName)
            elseif frame.selectedSetID then
                local set = LPL.ActionBarStore:Get(frame.selectedSetID)
                if set then
                    exportName = set.name
                    exportText, err = LPL.ActionBarShare:ExportSet(set)
                end
            end

            if exportText and exportText ~= "" then
                LPL.ImportExport:OpenExport(exportText, exportName)
            else
                print("|cffff6060LPL:|r " .. (err or "Select or edit an action bar set to export."))
            end
        end,
        onImport = function()
            LPL.ImportExport:OpenImport()
        end,
        onUpdate = function()
            if not frame.draftSet then
                return
            end
            local ok, err = LPL.ActionBarCursor:CanEdit()
            if not ok then
                print("|cffff6060LPL:|r " .. (err or "Cannot edit action bars in combat."))
                return
            end
            LPL.ActionBarCodec:CaptureFromCharacter(frame.draftSet)
            LPL.ActionBarCursor:Clear()
            RefreshBarEditor(frame)
            print("|cff33cc33LPL:|r Loaded action bars from your character.")
        end,
        onReset = function()
            if not frame.draftSet then
                return
            end
            LPL.ActionBarCursor:Clear()
            frame.draftSet.actions = {}
            frame.draftSet.ignored = {}
            frame.draftSet.petActions = {}
            frame.draftSet.petIgnored = {}
            RefreshBarEditor(frame)
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            LPL.ActionBarCursor:Clear()
            local name = frame.actionBar:GetBuildName()
            LPL.ActionBarCodec:SanitizeDraft(frame.draftSet)
            LPL.ActionBarStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
                frame.selectedSetID = setID
                ShowListView(frame)
            end)
        end,
        onNewBuild = function()
            ShowTreeView(frame, nil, true)
        end,
        onDelete = function()
            local setID = frame.activeSetID or frame.selectedSetID
            if not setID then
                return
            end
            LPL.ActionBarStore:ConfirmDelete(setID, function()
                if setID == frame.activeSetID then
                    frame.activeSetID = nil
                    frame.draftSet = nil
                end
                frame.selectedSetID = nil
                if frame.viewMode == "list" then
                    frame.setList:Refresh()
                    local hasSets = #LPL.ActionBarStore:GetAll() > 0
                    UpdateListViewLayout(frame, hasSets)
                    frame.actionBar:SetMode("list", not hasSets)
                    frame.actionBar:SetListSelectionEnabled(false)
                else
                    ShowListView(frame)
                end
            end)
        end,
    }, {
        newButtonLabel = "+ New Set",
        nameLabel = "Set name",
    })

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local setList = LPL.ActionBarSetList:Create(listView, 0)
    setList:SetOnSelect(function(setID)
        if frame.selectedSetID == setID then
            SelectSet(frame, nil)
        else
            SelectSet(frame, setID)
        end
    end)
    setList:SetOnActivate(function(setID)
        SelectSet(frame, setID)
        ShowTreeView(frame, setID, false)
    end)
    setList:SetOnNewSet(function()
        ShowTreeView(frame, nil, true)
    end)

    local treeView = CreateFrame("Frame", nil, frame)
    treeView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    treeView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
    treeView:SetFrameLevel(frame:GetFrameLevel() + 1)
    treeView:EnableMouse(false)
    treeView:Hide()

    local barEditor = LPL.ActionBarEditor:Create(treeView)

    frame.actionBar = actionBar
    frame.listView = listView
    frame.treeView = treeView
    frame.setList = setList
    frame.barEditor = barEditor

    LPL.RestrictionsMenu:Attach(actionBar.limitsButton, function()
        return frame.draftSet
    end, function()
        if frame.draftSet and LPL.SetRestrictions then
            frame.draftSet.restrictions = LPL.SetRestrictions:NormalizeRestrictions(frame.draftSet.restrictions or {})
            if frame.draftSet.restrictions and next(frame.draftSet.restrictions) then
                frame.draftSet.classID = LPL.SetRestrictions:GetEffectiveActionBarClassID(frame.draftSet)
            else
                frame.draftSet.classID = nil
                frame.draftSet.specID = nil
                frame.draftSet.subTreeID = nil
            end
            LPL.SetRestrictions:UpdateActionBarSetFilters(frame.draftSet)
        end
        RefreshBarEditor(frame)
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))

    LPL.RestrictionsMenu:Attach(actionBar.listLimitsButton, function()
        return frame.selectedSetID and LPL.ActionBarStore:Get(frame.selectedSetID)
    end, function(record)
        if not frame.selectedSetID or not record then
            return
        end
        local set = LPL.ActionBarStore:Get(frame.selectedSetID)
        if set then
            set.restrictions = CopyTable(record.restrictions or {})
            LPL.ActionBarStore:CommitSet(set)
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
            local hasSets = #LPL.ActionBarStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            self.actionBar:SetListSelectionEnabled(self.selectedSetID ~= nil)
        elseif self.viewMode == "tree" then
            RefreshBarEditor(self)
            self.actionBar:UpdateTreeActions(self.activeSetID ~= nil, true)
        end
    end

    frame:Hide()
    ActionBarsModule.instance = frame
    return frame
end

function ActionBarsModule:OnShow()
    if LPL.DB and LPL.DB.SyncFromGlobal then
        LPL.DB:SyncFromGlobal()
    end
    if LPL.ActionBarStore and LPL.ActionBarStore.MigrateStorage then
        LPL.ActionBarStore:MigrateStorage()
    end
    if self.instance then
        self.instance:ShowList()
        self.instance:Refresh()
    end
end

LPL.Modules:Register({
    id = ActionBarsModule.id,
    label = ActionBarsModule.label,
    description = ActionBarsModule.description,
    icon = ActionBarsModule.icon,
    iconStem = ActionBarsModule.iconStem,
    order = ActionBarsModule.order,
    create = ActionBarsModule.create,
    OnShow = function()
        ActionBarsModule:OnShow()
    end,
})
