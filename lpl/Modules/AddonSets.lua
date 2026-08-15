local addonName, LPL = ...

local AddonSetsModule = {
    id = "addonsets",
    label = "Addon Sets",
    description = "Save and apply lists of enabled addons for Account or Character.",
    iconStem = "addonsets_64",
    order = 59,
    instance = nil,
}

local VAULT_BAR_OPTIONS = {
    newButtonLabel = "+ New Set",
    newButtonWidth = 96,
    newButtonTooltipTitle = "New Addon Set",
    newButtonTooltipBody = "Create a new list of addons to enable or replace",
    nameLabel = "Set name",
    editTooltip = "Edit the selected addon set",
    showActivate = true,
    activateButtonWidth = 80,
    activateTooltipTitle = "Activate",
    activateTooltipBody = "Replace currently enabled addons with the selected set(s), including linked sets, then reload",
    showEnableSet = true,
    enableSetButtonWidth = 68,
    enableSetTooltipTitle = "Enable",
    enableSetTooltipBody = "Enable addons in the selected set(s) without disabling others, then reload",
    showDisableSet = true,
    disableSetButtonWidth = 72,
    disableSetTooltipTitle = "Disable",
    disableSetTooltipBody = "Disable addons in the selected set(s) (skips protected), then reload",
    showUpdate = true,
    updateTooltipTitle = "Update",
    updateTooltipBody = "Fill this set from addons currently enabled for the selected scope",
    updateTooltipDisabled = "Open a set in the editor to update from live addons.",
    showReset = false,
    showLimits = false,
    showExport = true,
    showImport = true,
    showListImport = true,
    backTooltipTitle = "Back",
    backTooltipBody = "Return to the addon set list",
    saveTooltipTitle = "Save",
    saveTooltipBody = "Save this addon set name, scope, checklist, and linked sets",
    deleteTooltipTitle = "Delete",
    deleteTooltipBody = "Remove the selected addon set(s) from your library",
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.AddonSetStore:CreateDraftSet()
    end
    return {
        name = set.name,
        scope = set.scope or LPL.AddonSetStore.SCOPE_ACCOUNT,
        addons = CopyTable(set.addons or {}),
        includes = CopyTable(set.includes or {}),
    }
end

local function DestroyEditor(frame)
    if frame.addonSetEditor then
        LPL.AddonSetEditor:Destroy(frame.addonSetEditor)
        frame.addonSetEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.addonSetEditor = LPL.AddonSetEditor:Create(frame.editorView)
    return frame.addonSetEditor
end

local function RefreshEditor(frame)
    local editor = frame.addonSetEditor
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
    frame.editorView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
end

local function CountSelected(frame)
    local count = 0
    for _ in pairs(frame.selectedSetIDs or {}) do
        count = count + 1
    end
    return count
end

local function GetSelectedSetIDs(frame)
    local list = {}
    for setID in pairs(frame.selectedSetIDs or {}) do
        list[#list + 1] = setID
    end
    table.sort(list)
    return list
end

local function GetPrimarySelectedSetID(frame)
    local ids = GetSelectedSetIDs(frame)
    if #ids == 1 then
        return ids[1]
    end
    return frame.selectedSetID
end

local function SyncListSelection(frame)
    frame.setList:SetSelectedIDs(frame.selectedSetIDs)
    local count = CountSelected(frame)
    local primary = GetPrimarySelectedSetID(frame)
    frame.selectedSetID = count == 1 and primary or (count > 0 and primary or nil)
    frame.actionBar:SetListSelectionEnabled(count > 0)
    if frame.actionBar.SetEditEnabled then
        frame.actionBar:SetEditEnabled(count == 1)
    end
end

local function ClearSelection(frame)
    wipe(frame.selectedSetIDs)
    frame.selectedSetID = nil
    SyncListSelection(frame)
end

local function ToggleSelectSet(frame, setID)
    if not setID then
        return
    end
    setID = tostring(setID)
    if frame.selectedSetIDs[setID] then
        frame.selectedSetIDs[setID] = nil
    else
        frame.selectedSetIDs[setID] = true
    end
    SyncListSelection(frame)
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
    SyncListSelection(frame)
    frame.setList:Refresh()
    local hasSets = #LPL.AddonSetStore:GetAll() > 0
    UpdateListViewLayout(frame, hasSets)
    frame.actionBar:SetMode("list", not hasSets)
    SyncListSelection(frame)
end

local function ShowEditorView(frame, setID, isNew)
    frame.viewMode = "editor"
    frame.isNewSet = isNew or false
    frame.editorView:EnableMouse(true)

    if isNew then
        frame.activeSetID = nil
        frame.draftSet = LPL.AddonSetStore:CreateDraftSet()
    elseif setID then
        local set = LPL.AddonSetStore:Get(setID)
        if not set then
            ShowListView(frame)
            return
        end
        frame.activeSetID = setID
        frame.selectedSetIDs = { [tostring(setID)] = true }
        frame.selectedSetID = tostring(setID)
        frame.draftSet = CopyDraftFromSet(set)
    else
        ShowListView(frame)
        return
    end

    frame.listView:Hide()
    frame.editorView:Show()
    UpdateEditorViewLayout(frame)
    BuildEditor(frame)
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.AddonSetStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, true)
    RefreshEditor(frame)
end

function AddonSetsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLAddonSetsModule", parent)
    frame:SetAllPoints(parent)

    frame.viewMode = "list"
    frame.selectedSetID = nil
    frame.selectedSetIDs = {}
    frame.activeSetID = nil
    frame.isNewSet = false
    frame.draftSet = nil

    local actionBar = LPL.TalentActionBar:Create(frame, {
        onBack = function()
            ShowListView(frame)
        end,
        onEdit = function()
            local setID = GetPrimarySelectedSetID(frame)
            if setID and CountSelected(frame) == 1 then
                ShowEditorView(frame, setID, false)
            end
        end,
        onActivate = function()
            local setIDs = GetSelectedSetIDs(frame)
            LPL.AddonSetActivate:ConfirmReplace(setIDs, function()
                LPL.AddonSetActivate:ApplyAndPromptReload(LPL.AddonSetActivate.MODE_REPLACE, setIDs)
            end)
        end,
        onEnableSet = function()
            local setIDs = GetSelectedSetIDs(frame)
            LPL.AddonSetActivate:ApplyAndPromptReload(LPL.AddonSetActivate.MODE_ENABLE, setIDs)
        end,
        onDisableSet = function()
            local setIDs = GetSelectedSetIDs(frame)
            LPL.AddonSetActivate:ApplyAndPromptReload(LPL.AddonSetActivate.MODE_DISABLE, setIDs)
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            if frame.addonSetEditor and frame.addonSetEditor.GetDraft then
                frame.draftSet = frame.addonSetEditor:GetDraft() or frame.draftSet
            end
            local name = frame.actionBar:GetBuildName()
            frame.draftSet.name = name
            LPL.AddonSetStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
                frame.selectedSetIDs = { [tostring(setID)] = true }
                frame.selectedSetID = tostring(setID)
                ShowListView(frame)
            end)
        end,
        onUpdate = function()
            if not frame.draftSet then
                return
            end
            if frame.addonSetEditor and frame.addonSetEditor.UpdateFromLive then
                frame.addonSetEditor:UpdateFromLive()
                frame.draftSet = frame.addonSetEditor:GetDraft() or frame.draftSet
            end
        end,
        onExport = function()
            local exportText, err
            local exportName

            if frame.viewMode == "editor" and frame.draftSet then
                if frame.addonSetEditor and frame.addonSetEditor.GetDraft then
                    frame.draftSet = frame.addonSetEditor:GetDraft() or frame.draftSet
                end
                exportName = frame.actionBar:GetBuildName()
                frame.draftSet.name = exportName
                exportText, err = LPL.AddonSetShare:ExportDraft(frame.draftSet, exportName)
            else
                local setIDs = GetSelectedSetIDs(frame)
                if #setIDs == 1 then
                    local set = LPL.AddonSetStore:Get(setIDs[1])
                    if set then
                        exportName = set.name
                        exportText, err = LPL.AddonSetShare:ExportSet(set)
                    end
                elseif #setIDs > 1 then
                    err = "Select a single addon set to export."
                end
            end

            if exportText and exportText ~= "" then
                LPL.ImportExport:OpenExport(exportText, exportName)
            else
                print("|cffff6060LPL:|r " .. (err or "Select or edit an addon set to export."))
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
                LPL.AddonSetStore:ConfirmDelete(setID, function()
                    frame.activeSetID = nil
                    frame.draftSet = nil
                    frame.selectedSetIDs[tostring(setID)] = nil
                    frame.selectedSetID = nil
                    ShowListView(frame)
                end)
                return
            end

            local setIDs = GetSelectedSetIDs(frame)
            if #setIDs == 0 then
                return
            end
            if #setIDs == 1 then
                LPL.AddonSetStore:ConfirmDelete(setIDs[1], function()
                    frame.selectedSetIDs[setIDs[1]] = nil
                    frame.selectedSetID = nil
                    frame.setList:Refresh()
                    local hasSets = #LPL.AddonSetStore:GetAll() > 0
                    UpdateListViewLayout(frame, hasSets)
                    frame.actionBar:SetMode("list", not hasSets)
                    SyncListSelection(frame)
                end)
                return
            end

            -- Multi-delete: confirm once, then delete each.
            if not StaticPopupDialogs["LPL_CONFIRM_DELETE_ADDON_SETS"] then
                StaticPopupDialogs["LPL_CONFIRM_DELETE_ADDON_SETS"] = {
                    text = "Delete %s selected addon sets? This cannot be undone.",
                    button1 = DELETE,
                    button2 = CANCEL,
                    OnAccept = function(self)
                        local data = self.data
                        if not data or type(data.setIDs) ~= "table" then
                            return
                        end
                        for _, setID in ipairs(data.setIDs) do
                            LPL.AddonSetStore:Delete(setID)
                        end
                        if data.onConfirm then
                            data.onConfirm()
                        end
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
            end
            StaticPopup_Show("LPL_CONFIRM_DELETE_ADDON_SETS", tostring(#setIDs), nil, {
                setIDs = setIDs,
                onConfirm = function()
                    ClearSelection(frame)
                    frame.setList:Refresh()
                    local hasSets = #LPL.AddonSetStore:GetAll() > 0
                    UpdateListViewLayout(frame, hasSets)
                    frame.actionBar:SetMode("list", not hasSets)
                    SyncListSelection(frame)
                end,
            })
        end,
    }, VAULT_BAR_OPTIONS)

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local setList = LPL.AddonSetSetList:Create(listView, 0)
    setList:SetOnSelect(function(setID)
        ToggleSelectSet(frame, setID)
    end)
    setList:SetOnActivate(function(setID)
        frame.selectedSetIDs = { [tostring(setID)] = true }
        frame.selectedSetID = tostring(setID)
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
    frame.addonSetEditor = nil

    function frame:ShowList()
        ShowListView(self)
    end

    function frame:Refresh()
        if self.viewMode == "editor" then
            RefreshEditor(self)
        else
            self.setList:Refresh()
            local hasSets = #LPL.AddonSetStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            SyncListSelection(self)
        end
    end

    ShowListView(frame)
    return frame
end

function AddonSetsModule:OnShow()
    if self.instance and self.instance.Refresh then
        self.instance:Refresh()
    end
end

function AddonSetsModule:OnActivate(frame)
    if frame and frame.Refresh then
        frame:Refresh()
    end
end

LPL.Modules:Register(AddonSetsModule)
