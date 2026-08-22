local addonName, LPL = ...

local TalentsModule = {
    id = "talents",
    label = "Talents",
    description = "Classic Era talent builds (3 trees, 51 points).",
    icon = "Interface\\Icons\\Ability_Marksmanship",
    iconStem = "talents_64",
    order = 20,
}

local function CopyDraft(build)
    if not build then
        return LPL.TalentStore:CreateDraft()
    end
    return {
        name = build.name,
        classID = build.classID,
        level = build.level or LPL.TalentAPI:GetMaxLevel(),
        talentGroup = build.talentGroup,
        tabs = CopyTable(build.tabs or {}),
        totalPoints = build.totalPoints,
        restrictions = CopyTable(build.restrictions or {}),
    }
end

local function ShowList(frame)
    frame.mode = "list"
    frame.activeBuildID = nil
    frame.draft = nil
    frame.listView:Show()
    frame.editorView:Hide()
    frame.actionBar:SetMode("list", #LPL.TalentStore:GetAll() == 0)
    frame.actionBar:SetListSelectionEnabled(frame.selectedBuildID ~= nil)
    frame.buildList:SetSelectedID(frame.selectedBuildID)
    frame.buildList:Refresh()
end

local function ShowEditor(frame, buildID, isNew)
    frame.mode = "editor"
    frame.isNew = isNew and true or false

    if isNew then
        frame.activeBuildID = nil
        frame.draft = LPL.TalentStore:CreateDraft()
    else
        local build = LPL.TalentStore:Get(buildID)
        if not build then
            ShowList(frame)
            return
        end
        frame.activeBuildID = buildID
        frame.selectedBuildID = buildID
        frame.draft = CopyDraft(build)
    end

    frame.listView:Hide()
    frame.editorView:Show()
    frame.actionBar:SetMode("tree")
    frame.actionBar:SetBuildName(frame.draft.name or LPL.TalentStore:SuggestName(frame.draft))
    frame.actionBar:UpdateTreeActions(frame.activeBuildID ~= nil, true)
    frame.treeView:SetDraft(frame.draft, false)
end

function TalentsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLClassicEraTalentsModule", parent)
    frame:SetAllPoints(parent)
    frame.mode = "list"
    frame.selectedBuildID = nil
    frame.activeBuildID = nil
    frame.draft = nil

    local actionBar = LPL.TalentActionBar:Create(frame, {
        onBack = function()
            ShowList(frame)
        end,
        onEdit = function()
            if frame.selectedBuildID then
                ShowEditor(frame, frame.selectedBuildID, false)
            end
        end,
        onActivate = function()
            if frame.mode == "editor" and frame.draft then
                if LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(frame.draft) then
                    local summary = LPL.SetRestrictions:GetSummaryLine(frame.draft.restrictions)
                        or "another character, class, or race"
                    print("|cffff6060LPL:|r This talent build is restricted to " .. summary .. ".")
                    return
                end
                LPL.TalentActivate:ApplyDraft(frame.draft)
            elseif frame.selectedBuildID then
                local build = LPL.TalentStore:Get(frame.selectedBuildID)
                if build and LPL.SetRestrictions and not LPL.SetRestrictions:AreValidForPlayerRecord(build) then
                    local summary = LPL.SetRestrictions:GetSummaryLine(build.restrictions)
                        or "another character, class, or race"
                    print("|cffff6060LPL:|r This talent build is restricted to " .. summary .. ".")
                    return
                end
                LPL.TalentActivate:ApplySet(frame.selectedBuildID)
            end
            if frame.buildList then
                frame.buildList:Refresh()
            end
        end,
        onUpdate = function()
            if not frame.draft then
                return
            end
            local live = LPL.TalentAPI:CaptureLiveBuild()
            frame.draft.tabs = CopyTable(live.tabs or {})
            frame.draft.classID = live.classID
            frame.draft.talentGroup = live.talentGroup
            LPL.TalentAPI:RecalcDraftPoints(frame.draft)
            frame.treeView:SetDraft(frame.draft, false)
            print("|cff33cc33LPL:|r Loaded talents from your character.")
        end,
        onReset = function()
            if not frame.draft then
                return
            end
            local classID = frame.draft.classID or LPL.TalentAPI:GetPlayerClassID()
            frame.draft.tabs = {}
            LPL.TalentAPI:EnsureDraftClass(frame.draft, classID)
            frame.treeView:SetDraft(frame.draft, false)
        end,
        onSave = function()
            if not frame.draft then
                return
            end
            local name = frame.actionBar:GetBuildName()
            LPL.TalentStore:SaveFromEditor(frame.activeBuildID, name, frame.draft, function(buildID)
                frame.selectedBuildID = buildID
                ShowList(frame)
            end)
        end,
        onNewBuild = function()
            ShowEditor(frame, nil, true)
        end,
        onDelete = function()
            local buildID = frame.activeBuildID or frame.selectedBuildID
            if not buildID then
                return
            end
            LPL.TalentStore:ConfirmDelete(buildID, function()
                frame.selectedBuildID = nil
                frame.activeBuildID = nil
                ShowList(frame)
            end)
        end,
    }, {
        newButtonLabel = "+ New Build",
        nameLabel = "Build name",
    })

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local buildList = LPL.SetListView:Create(listView, {
        bottomInset = 0,
        listKey = "talents",
        flatList = false,
        supportedFilters = CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
        title = "Saved Talent Builds",
        hint = "Universal by default | Use Limits to restrict by class, character, or race | Green dot = matches your current talents.",
        emptyButtonLabel = "New Talent Build",
        emptyButtonWidth = 170,
        getItems = function()
            return LPL.TalentStore:GetAll()
        end,
        getID = function(build)
            return build.id
        end,
        getName = function(build)
            return build.name
        end,
        getFilters = function(build)
            return build.filters
        end,
        getClassKey = function(build)
            return LPL.TalentStore:GetEffectiveClassID(build)
        end,
        getSpecKey = function()
            return nil
        end,
        getHeroKey = function()
            return nil
        end,
        isActive = function(build)
            return LPL.TalentActivate:IsActive(build)
        end,
        getSubtitle = function(build)
            return LPL.TalentStore:GetSummaryLine(build)
        end,
        getSubtitleColor = function(build)
            return LPL.TalentStore:GetClassColor(build.classID)
        end,
    })

    buildList:SetOnSelect(function(buildID)
        if frame.selectedBuildID == buildID then
            frame.selectedBuildID = nil
        else
            frame.selectedBuildID = buildID
        end
        frame.actionBar:SetListSelectionEnabled(frame.selectedBuildID ~= nil)
        buildList:SetSelectedID(frame.selectedBuildID)
        buildList:Refresh()
    end)
    buildList:SetOnActivate(function(buildID)
        frame.selectedBuildID = buildID
        ShowEditor(frame, buildID, false)
    end)
    buildList:SetOnNew(function()
        ShowEditor(frame, nil, true)
    end)

    local editorView = CreateFrame("Frame", nil, frame)
    editorView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    editorView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
    editorView:Hide()

    local treeView = LPL.TalentTreeView:Create(editorView)
    treeView.onDraftChanged = function(draft)
        frame.draft = draft
        if frame.actionBar and draft then
            local summary = LPL.TalentAPI:SummarizeBuild(draft)
            local current = frame.actionBar:GetBuildName()
            if current and current:find("%d+/%d+/%d+") then
                local className = LPL.ListGrouping and LPL.ListGrouping:GetClassName(draft.classID)
                if not className and GetClassInfo and draft.classID then
                    className = GetClassInfo(draft.classID)
                end
                frame.actionBar:SetBuildName(string.format("%s %s", className or "Talent", summary))
            end
        end
    end

    frame.actionBar = actionBar
    frame.listView = listView
    frame.editorView = editorView
    frame.buildList = buildList
    frame.treeView = treeView

    LPL.RestrictionsMenu:Attach(actionBar.limitsButton, function()
        if not frame.draft then
            return { restrictions = {} }
        end
        frame.draft.restrictions = frame.draft.restrictions or {}
        return {
            classID = frame.draft.classID,
            restrictions = frame.draft.restrictions,
        }
    end, function(record)
        if not frame.draft then
            return
        end
        frame.draft.restrictions = LPL.SetRestrictions:NormalizeRestrictions(record.restrictions or {})
        if frame.activeBuildID then
            local build = LPL.TalentStore:Get(frame.activeBuildID)
            if build then
                build.restrictions = CopyTable(frame.draft.restrictions)
                LPL.SetRestrictions:UpdateTalentBuildFilters(build)
                LPL.TalentStore:CommitBuild(build)
            end
        end
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))

    LPL.RestrictionsMenu:Attach(actionBar.listLimitsButton, function()
        local build = frame.selectedBuildID and LPL.TalentStore:Get(frame.selectedBuildID)
        if not build then
            return { restrictions = {} }
        end
        return build
    end, function(record)
        if not frame.selectedBuildID or not record then
            return
        end
        local build = LPL.TalentStore:Get(frame.selectedBuildID)
        if build then
            build.restrictions = CopyTable(record.restrictions or {})
            LPL.SetRestrictions:UpdateTalentBuildFilters(build)
            LPL.TalentStore:CommitBuild(build)
            frame.buildList:Refresh()
        end
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))

    frame:Hide()
    TalentsModule.instance = frame
    return frame
end

function TalentsModule:OnShow()
    if LPL.DB and LPL.DB.SyncFromGlobal then
        LPL.DB:SyncFromGlobal()
    end
    if self.instance then
        ShowList(self.instance)
    end
end

LPL.Modules:Register({
    id = TalentsModule.id,
    label = TalentsModule.label,
    description = TalentsModule.description,
    icon = TalentsModule.icon,
    iconStem = TalentsModule.iconStem,
    order = TalentsModule.order,
    create = TalentsModule.create,
    OnShow = function()
        TalentsModule:OnShow()
    end,
})
