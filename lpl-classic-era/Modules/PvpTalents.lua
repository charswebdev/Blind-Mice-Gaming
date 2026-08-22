local addonName, LPL = ...

local PvpTalentsModule = {
    id = "pvp",
    label = "PVP Talents",
    description = "Plan and save PvP talent layouts.",
    iconStem = "pvp_64",
    order = 30,
    instance = nil,
}

local function CopyDraftFromSet(set)
    if not set then
        return LPL.PvpTalentStore:CreateDraftSet(LPL.PvpTalentStore:SuggestSetName())
    end
    return {
        name = set.name,
        talents = CopyTable(set.talents or {}),
        restrictions = CopyTable(set.restrictions or {}),
        classID = set.classID,
        specID = set.specID,
        subTreeID = set.subTreeID,
    }
end

local function ApplyPvpRestrictions(record)
    if not record or not LPL.SetRestrictions then
        return
    end
    local planningSpecID = tonumber(record.specID)
    record.restrictions = LPL.SetRestrictions:NormalizeRestrictions(record.restrictions or {})
    if planningSpecID then
        record.specID = planningSpecID
        if LPL.TalentTree and LPL.TalentTree.GetClassIDForSpec then
            record.classID = LPL.TalentTree:GetClassIDForSpec(planningSpecID)
        end
    end
    LPL.SetRestrictions:UpdateActionBarSetFilters(record)
end

local function DestroyEditor(frame)
    if frame.pvpEditor then
        LPL.PvpTalentEditor:Destroy(frame.pvpEditor)
        frame.pvpEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.pvpEditor = LPL.PvpTalentEditor:Create(frame.editorView)
    return frame.pvpEditor
end

local function RefreshEditor(frame)
    local editor = frame.pvpEditor
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
    local hasSets = #LPL.PvpTalentStore:GetAll() > 0
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
        frame.draftSet = LPL.PvpTalentStore:CreateDraftSet(LPL.PvpTalentStore:SuggestSetName())
    elseif setID then
        local set = LPL.PvpTalentStore:Get(setID)
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

    if LPL.PvpTalentCodec then
        LPL.PvpTalentCodec:SanitizeDraft(frame.draftSet)
    end

    frame.listView:Hide()
    frame.editorView:Show()
    UpdateEditorViewLayout(frame)
    BuildEditor(frame)
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftSet.name or LPL.PvpTalentStore:SuggestSetName())
    frame.actionBar:UpdateTreeActions(frame.activeSetID ~= nil, true)
    RefreshEditor(frame)
end

function PvpTalentsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLPvpTalentsModule", parent)
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
                    specID = frame.draftSet.specID,
                    classID = frame.draftSet.classID,
                }
                if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(draftRecord) then
                    local summary = LPL.SetRestrictions:GetSummaryLine(frame.draftSet.restrictions)
                        or "another character, class, or specialization"
                    print("|cffff6060LPL:|r This PvP set is restricted to " .. summary .. ".")
                    return
                end
                LPL.PvpTalentActivate:ApplyDraft(frame.draftSet, frame.actionBar:GetBuildName())
            elseif frame.selectedSetID then
                local set = LPL.PvpTalentStore:Get(frame.selectedSetID)
                if set and LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(set) then
                    local summary = LPL.SetRestrictions:GetSummaryLine(set.restrictions)
                        or "another character, class, or specialization"
                    print("|cffff6060LPL:|r This PvP set is restricted to " .. summary .. ".")
                    return
                end
                LPL.PvpTalentActivate:ApplySet(frame.selectedSetID)
            else
                print("|cffff6060LPL:|r Select or edit a PvP set to activate.")
            end
            if frame.viewMode == "list" then
                frame.setList:Refresh()
            end
        end,
        onExport = function()
            local exportText, err
            local exportName

            if frame.viewMode == "editor" and frame.draftSet then
                exportName = frame.actionBar:GetBuildName()
                if LPL.PvpTalentCodec then
                    LPL.PvpTalentCodec:SanitizeDraft(frame.draftSet)
                end
                exportText, err = LPL.PvpTalentShare:ExportDraft(frame.draftSet, exportName)
            elseif frame.selectedSetID then
                local set = LPL.PvpTalentStore:Get(frame.selectedSetID)
                if set then
                    exportName = set.name
                    exportText, err = LPL.PvpTalentShare:ExportSet(set)
                end
            end

            if exportText and exportText ~= "" then
                LPL.ImportExport:OpenExport(exportText, exportName)
            else
                print("|cffff6060LPL:|r " .. (err or "Select or edit a PvP set to export."))
            end
        end,
        onImport = function()
            LPL.ImportExport:OpenImport()
        end,
        onUpdate = function()
            if not frame.draftSet then
                return
            end
            local ok, err = LPL.PvpTalentCodec:CanCaptureFromCharacter(frame.draftSet)
            if not ok then
                print("|cffff6060LPL:|r " .. (err or "Cannot update from character."))
                return
            end
            local captured, captureErr = LPL.PvpTalentCodec:CaptureFromCharacter(frame.draftSet)
            if not captured then
                print("|cffff6060LPL:|r " .. (captureErr or "Failed to read PvP talents."))
                return
            end
            RefreshEditor(frame)
            print("|cff33cc33LPL:|r Loaded PvP talents from your character.")
        end,
        onReset = function()
            if not frame.draftSet then
                return
            end
            frame.draftSet.talents = {}
            RefreshEditor(frame)
        end,
        onSave = function()
            if not frame.draftSet then
                return
            end
            local name = frame.actionBar:GetBuildName()
            if LPL.PvpTalentCodec then
                LPL.PvpTalentCodec:SanitizeDraft(frame.draftSet)
            end
            LPL.PvpTalentStore:SaveFromEditor(frame.activeSetID, name, frame.draftSet, function(setID)
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
            LPL.PvpTalentStore:ConfirmDelete(setID, function()
                if setID == frame.activeSetID then
                    frame.activeSetID = nil
                    frame.draftSet = nil
                end
                frame.selectedSetID = nil
                if frame.viewMode == "list" then
                    frame.setList:Refresh()
                    local hasSets = #LPL.PvpTalentStore:GetAll() > 0
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

    local setList = LPL.PvpTalentSetList:Create(listView, 0)
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
    frame.pvpEditor = nil

    LPL.RestrictionsMenu:Attach(actionBar.limitsButton, function()
        return frame.draftSet
    end, function()
        ApplyPvpRestrictions(frame.draftSet)
        if frame.activeSetID and frame.draftSet then
            local set = LPL.PvpTalentStore:Get(frame.activeSetID)
            if set then
                set.restrictions = LPL.SetRestrictions:CopyRestrictions(frame.draftSet.restrictions)
                set.specID = frame.draftSet.specID
                set.classID = frame.draftSet.classID
                ApplyPvpRestrictions(set)
                LPL.PvpTalentStore:CommitSet(set)
            end
        end
        RefreshEditor(frame)
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))

    LPL.RestrictionsMenu:Attach(actionBar.listLimitsButton, function()
        return frame.selectedSetID and LPL.PvpTalentStore:Get(frame.selectedSetID)
    end, function(record)
        if not frame.selectedSetID or not record then
            return
        end
        local set = LPL.PvpTalentStore:Get(frame.selectedSetID)
        if set then
            local planningSpecID = set.specID
            set.restrictions = LPL.SetRestrictions:CopyRestrictions(record.restrictions)
            set.specID = planningSpecID or set.specID
            ApplyPvpRestrictions(set)
            LPL.PvpTalentStore:CommitSet(set)
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
            local hasSets = #LPL.PvpTalentStore:GetAll() > 0
            UpdateListViewLayout(self, hasSets)
            self.actionBar:SetMode("list", not hasSets)
            self.actionBar:SetListSelectionEnabled(self.selectedSetID ~= nil)
        elseif self.viewMode == "editor" then
            RefreshEditor(self)
            self.actionBar:UpdateTreeActions(self.activeSetID ~= nil, true)
        end
    end

    frame:Hide()
    PvpTalentsModule.instance = frame

    if not PvpTalentsModule.eventFrame then
        local eventFrame = CreateFrame("Frame")
        eventFrame:RegisterEvent("PLAYER_PVP_TALENT_UPDATE")
        eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("SELECTED_PVP_TALENTS_CHANGED") then
            eventFrame:RegisterEvent("SELECTED_PVP_TALENTS_CHANGED")
        end
        eventFrame:SetScript("OnEvent", function()
            local instance = PvpTalentsModule.instance
            if instance and instance:IsShown() and instance.viewMode == "list" and instance.setList then
                instance.setList:Refresh()
            end
        end)
        PvpTalentsModule.eventFrame = eventFrame
    end

    return frame
end

function PvpTalentsModule:OnShow()
    if LPL.DB and LPL.DB.SyncFromGlobal then
        LPL.DB:SyncFromGlobal()
    end
    if LPL.PvpTalentStore and LPL.PvpTalentStore.MigrateStorage then
        LPL.PvpTalentStore:MigrateStorage()
    end
    if self.instance then
        self.instance:ShowList()
        self.instance:Refresh()
    end
end

LPL.Modules:Register({
    id = PvpTalentsModule.id,
    label = PvpTalentsModule.label,
    description = PvpTalentsModule.description,
    icon = PvpTalentsModule.icon,
    iconStem = PvpTalentsModule.iconStem,
    order = PvpTalentsModule.order,
    create = PvpTalentsModule.create,
    OnShow = function()
        PvpTalentsModule:OnShow()
    end,
})
