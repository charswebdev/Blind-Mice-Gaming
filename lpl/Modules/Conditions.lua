local addonName, LPL = ...

local ConditionsModule = {
    id = "conditions",
    label = "Conditions",
    description = "Prompt to apply loadouts or builds based on situations.",
    iconStem = "conditions_64",
    order = 57,
    instance = nil,
}

local function CopyDraftFromRule(rule)
    if not rule then
        return LPL.ConditionStore:CreateDraftRule()
    end
    return {
        name = rule.name,
        enabled = rule.enabled ~= false,
        priority = rule.priority or 100,
        links = CopyTable(rule.links or {}),
        loadoutIDs = CopyTable(rule.loadoutIDs or {}),
        situations = LPL.ConditionStore:NormalizeSituations(rule.situations),
    }
end

local function NotifyWatcher()
    if LPL.ConditionWatcher and LPL.ConditionWatcher.NotifySettingsChanged then
        LPL.ConditionWatcher:NotifySettingsChanged()
    end
end

local function DestroyEditor(frame)
    if frame.conditionEditor then
        LPL.ConditionEditor:Destroy(frame.conditionEditor)
        frame.conditionEditor = nil
    end
end

local function BuildEditor(frame)
    DestroyEditor(frame)
    if not frame.editorView then
        return nil
    end
    frame.conditionEditor = LPL.ConditionEditor:Create(frame.editorView)
    return frame.conditionEditor
end

local function RefreshEditor(frame)
    local editor = frame.conditionEditor
    if not editor then
        editor = BuildEditor(frame)
    end
    if not editor then
        return
    end
    if frame.draftRule then
        editor:SetDraft(frame.draftRule)
    else
        editor:Refresh()
    end
end

local function UpdateListViewLayout(frame, hasRules)
    local bottomInset = hasRules and LPL.TalentActionBar.LIST_HEIGHT or 0
    frame.listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, bottomInset)
end

local function UpdateEditorViewLayout(frame)
    frame.editorView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
end

local function SelectRule(frame, ruleID)
    frame.selectedRuleID = ruleID
    frame.ruleList:SetSelectedSetID(ruleID)
    frame.actionBar:SetListSelectionEnabled(ruleID ~= nil)
end

local function RefreshMasterToggle(frame)
    if frame.masterCheck then
        frame.masterCheck:SetChecked(LPL.ConditionStore:IsMasterEnabled())
    end
end

local function ShowListView(frame)
    frame.viewMode = "list"
    frame.activeRuleID = nil
    frame.isNewRule = false
    frame.draftRule = nil
    DestroyEditor(frame)
    frame.listView:Show()
    frame.editorView:Hide()
    frame.editorView:EnableMouse(false)
    frame.ruleList:SetSelectedSetID(frame.selectedRuleID)
    frame.ruleList:Refresh()
    local hasRules = #LPL.ConditionStore:GetAll() > 0
    UpdateListViewLayout(frame, hasRules)
    frame.actionBar:SetMode("list", not hasRules)
    frame.actionBar:SetListSelectionEnabled(frame.selectedRuleID ~= nil)
    RefreshMasterToggle(frame)
end

local function ShowEditorView(frame, ruleID, isNew)
    frame.viewMode = "editor"
    frame.isNewRule = isNew or false
    frame.editorView:EnableMouse(true)

    if isNew then
        frame.activeRuleID = nil
        frame.draftRule = LPL.ConditionStore:CreateDraftRule()
    elseif ruleID then
        local rule = LPL.ConditionStore:Get(ruleID)
        if not rule then
            ShowListView(frame)
            return
        end
        frame.activeRuleID = ruleID
        frame.selectedRuleID = ruleID
        frame.draftRule = CopyDraftFromRule(rule)
    else
        ShowListView(frame)
        return
    end

    frame.listView:Hide()
    frame.editorView:Show()
    UpdateEditorViewLayout(frame)
    BuildEditor(frame)
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draftRule.name or LPL.ConditionStore:SuggestRuleName())
    frame.actionBar:UpdateTreeActions(frame.activeRuleID ~= nil, true)
    RefreshEditor(frame)
end

function ConditionsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLConditionsModule", parent)
    frame:SetAllPoints(parent)

    frame.viewMode = "list"
    frame.selectedRuleID = nil
    frame.activeRuleID = nil
    frame.isNewRule = false
    frame.draftRule = nil

    local actionBar = LPL.TalentActionBar:Create(frame, {
        onBack = function()
            ShowListView(frame)
        end,
        onEdit = function()
            if frame.selectedRuleID then
                ShowEditorView(frame, frame.selectedRuleID, false)
            end
        end,
        onActivate = function()
            if not (LPL.ConditionWatcher and LPL.ConditionWatcher.EvaluateNow) then
                return
            end
            if not LPL.ConditionStore:IsMasterEnabled() then
                print("|cffffcc00LPL:|r Conditions are disabled (master switch).")
                return
            end
            if InCombatLockdown and InCombatLockdown() then
                print("|cffffcc00LPL:|r Conditions will prompt after combat ends.")
                LPL.ConditionWatcher:EvaluateNow(true)
                return
            end
            local matched = LPL.ConditionWatcher:EvaluateNow(true)
            if not matched then
                print("|cffffcc00LPL:|r No matching condition for the current situation.")
            end
        end,
        onImport = function()
            LPL.ImportExport:OpenImport()
        end,
        onUpdate = function()
            if frame.draftRule then
                RefreshEditor(frame)
            end
        end,
        onReset = function()
            if not frame.draftRule then
                return
            end
            frame.draftRule.links = {}
            frame.draftRule.loadoutIDs = {}
            frame.draftRule.situations = LPL.ConditionStore:CreateEmptySituations()
            frame.draftRule.enabled = true
            RefreshEditor(frame)
        end,
        onSave = function()
            if not frame.draftRule then
                return
            end
            if frame.conditionEditor and frame.conditionEditor.GetDraft then
                frame.draftRule = frame.conditionEditor:GetDraft() or frame.draftRule
            end
            local name = frame.actionBar:GetBuildName()
            if frame.conditionEditor and frame.conditionEditor.GetName then
                local editorName = frame.conditionEditor:GetName()
                if editorName and editorName ~= "" then
                    name = editorName
                end
            end
            frame.draftRule.name = name
            LPL.ConditionStore:SaveFromEditor(frame.activeRuleID, name, frame.draftRule, function(ruleID)
                frame.selectedRuleID = ruleID
                ShowListView(frame)
                NotifyWatcher()
            end)
        end,
        onNewBuild = function()
            ShowEditorView(frame, nil, true)
        end,
        onDelete = function()
            local ruleID = frame.activeRuleID or frame.selectedRuleID
            if not ruleID then
                return
            end
            LPL.ConditionStore:ConfirmDelete(ruleID, function()
                if ruleID == frame.activeRuleID then
                    frame.activeRuleID = nil
                    frame.draftRule = nil
                end
                frame.selectedRuleID = nil
                if frame.viewMode == "list" then
                    frame.ruleList:Refresh()
                    local hasRules = #LPL.ConditionStore:GetAll() > 0
                    UpdateListViewLayout(frame, hasRules)
                    frame.actionBar:SetMode("list", not hasRules)
                    frame.actionBar:SetListSelectionEnabled(false)
                else
                    ShowListView(frame)
                end
                NotifyWatcher()
            end)
        end,
    }, {
        newButtonLabel = "+ New Condition",
        nameLabel = "Condition name",
        editTooltip = "Edit the selected condition",
        showExport = false,
        showLimits = false,
        showUpdate = false,
    })

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local masterBar = CreateFrame("Frame", nil, listView)
    masterBar:SetPoint("TOPLEFT", listView, "TOPLEFT", 16, -10)
    masterBar:SetPoint("TOPRIGHT", listView, "TOPRIGHT", -16, -10)
    masterBar:SetHeight(28)

    local masterCheck = CreateFrame("CheckButton", nil, masterBar, "UICheckButtonTemplate")
    masterCheck:SetSize(24, 24)
    masterCheck:SetPoint("LEFT", masterBar, "LEFT", 0, 0)
    masterCheck:SetScript("OnClick", function(self)
        LPL.ConditionStore:SetMasterEnabled(self:GetChecked())
        local state = self:GetChecked() and "enabled" or "disabled"
        print(string.format("|cff33cc33LPL:|r Conditions master switch %s.", state))
        NotifyWatcher()
    end)
    frame.masterCheck = masterCheck

    local masterLabel = masterBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    masterLabel:SetPoint("LEFT", masterCheck, "RIGHT", 4, 0)
    masterLabel:SetText("Enable Conditions (master)")
    masterLabel:SetTextColor(LPL.Theme:GetColor("textBright"))

    local ruleList = LPL.ConditionSetList:Create(listView, 0)
    ruleList:ClearAllPoints()
    ruleList:SetPoint("TOPLEFT", masterBar, "BOTTOMLEFT", -16, -4)
    ruleList:SetPoint("BOTTOMRIGHT", listView, "BOTTOMRIGHT", 0, 0)

    ruleList:SetOnSelect(function(ruleID)
        if frame.selectedRuleID == ruleID then
            SelectRule(frame, nil)
        else
            SelectRule(frame, ruleID)
        end
    end)
    ruleList:SetOnActivate(function(ruleID)
        SelectRule(frame, ruleID)
        ShowEditorView(frame, ruleID, false)
    end)
    ruleList:SetOnNewSet(function()
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
    frame.ruleList = ruleList
    frame.conditionEditor = nil

    function frame:ShowList()
        ShowListView(self)
    end

    function frame:Refresh()
        if self.viewMode == "editor" then
            RefreshEditor(self)
        else
            self.ruleList:Refresh()
            RefreshMasterToggle(self)
            local hasRules = #LPL.ConditionStore:GetAll() > 0
            UpdateListViewLayout(self, hasRules)
            self.actionBar:SetMode("list", not hasRules)
            self.actionBar:SetListSelectionEnabled(self.selectedRuleID ~= nil)
        end
    end

    ShowListView(frame)
    return frame
end

function ConditionsModule:OnActivate(frame)
    if frame and frame.Refresh then
        frame:Refresh()
    end
end

LPL.Modules:Register(ConditionsModule)
