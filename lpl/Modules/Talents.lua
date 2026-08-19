local addonName, LPL = ...

local TalentsModule = {
    id = "talents",
    label = "Talents",
    description = "Plan and manage talent loadouts for any class.",
    iconStem = "talents_64",
    order = 20,
    instance = nil,
}

local function RefreshTree(frame)
    if frame.canvas then
        frame.canvas:Render()
    end
    if frame.picker then
        frame.picker:UpdatePoints()
    end
    if frame.picker and frame.picker.UpdateSandboxStatus then
        frame.picker:UpdateSandboxStatus()
    end
    if frame.viewMode == "tree" and frame.actionBar then
        local view = LPL.TalentTree:ResolveViewState()
        local canUpdate = LPL.TalentTree:PlayerMatchesView(view.classID, view.specID)
        frame.actionBar:UpdateTreeActions(frame.activeBuildID ~= nil, canUpdate)
    end
end

local function RefreshSandboxView(frame)
    if not LPL.TalentTree:IsAvailable() then
        return
    end

    local view = LPL.TalentTree:ResolveViewState()
    if frame.picker and frame.picker.LoadHeroes then
        frame.picker:LoadHeroes()
    end
    if frame.canvas then
        frame.canvas:Render()
    end
    if frame.picker then
        frame.picker:UpdatePoints()
        if frame.picker.UpdateSandboxStatus then
            frame.picker:UpdateSandboxStatus()
        end
    end
    if frame.actionBar then
        frame.actionBar:UpdateTreeActions(
            frame.activeBuildID ~= nil,
            LPL.TalentTree:PlayerMatchesView(view.classID, view.specID)
        )
    end
end

local function RefreshTreeEditor(frame)
    if not LPL.TalentTree:IsAvailable() then
        if frame.canvas and frame.canvas.loadingLabel then
            frame.canvas.loadingLabel:SetText("Talent APIs unavailable on this client.")
            frame.canvas.loadingLabel:Show()
        end
        return
    end

    local view = LPL.TalentTree:ResolveViewState()
    frame.picker:Refresh()
    frame.canvas:Render()
    local canUpdate = LPL.TalentTree:PlayerMatchesView(view.classID, view.specID)
    frame.actionBar:UpdateTreeActions(frame.activeBuildID ~= nil, canUpdate)
end

local function ResetSandboxForView(frame)
    if not frame.sandbox then
        return
    end
    frame.sandbox:Clear()
    if frame.viewMode == "tree" then
        RefreshTreeEditor(frame)
    else
        RefreshTree(frame)
    end
end

local function UpdateListViewLayout(frame, hasBuilds)
    frame.listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)
end

local function UpdateTreeViewLayout(frame)
    frame.treeView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
end

local function SelectBuild(frame, buildID)
    frame.selectedBuildID = buildID
    frame.buildList:SetSelectedBuildID(buildID)
    frame.actionBar:SetListSelectionEnabled(buildID ~= nil)
end

local function ShowListView(frame)
    frame.viewMode = "list"
    frame.activeBuildID = nil
    frame.isNewBuild = false
    frame.listView:Show()
    frame.treeView:Hide()
    frame.treeView:EnableMouse(false)
    frame.buildList:SetSelectedBuildID(frame.selectedBuildID)
    frame.buildList:Refresh()
    local hasBuilds = #LPL.BuildStore:GetAll() > 0
    UpdateListViewLayout(frame, hasBuilds)
    frame.actionBar:SetMode("list", not hasBuilds)
    frame.actionBar:SetListSelectionEnabled(frame.selectedBuildID ~= nil)
end

local function ShowTreeView(frame, buildID, isNew)
    frame.viewMode = "tree"
    frame.isNewBuild = isNew or false
    frame.treeView:EnableMouse(true)

    if isNew then
        frame.activeBuildID = nil
        local playerClassID, playerSpecID = LPL.TalentTree:GetPlayerIdentity()
        local classID = playerClassID or LPL.TalentTree:GetDefaultClassID()
        local specs = LPL.TalentTree:GetSpecsForClass(classID)
        local specID = playerSpecID
        if not specID then
            specID = specs[1] and specs[1].id
        end
        local heroes = specID and LPL.TalentTree:GetHeroTalentsForSpec(specID) or {}
        local view = LPL.DB:GetTalentView()
        view.classID = classID
        view.specID = specID
        view.subTreeID = heroes[1] and heroes[1].id
        if GetMaxLevelForPlayerExpansion then
            view.level = GetMaxLevelForPlayerExpansion()
        end
        frame.sandbox:Clear()
    elseif buildID then
        local build = LPL.BuildStore:Get(buildID)
        if not build then
            ShowListView(frame)
            return
        end
        frame.activeBuildID = buildID
        frame.selectedBuildID = buildID
        frame.editRestrictions = CopyTable(build.restrictions or {})
        LPL.BuildStore:ApplyToView(build)
        frame.sandbox:LoadFromBuild(build)
    end

    if isNew then
        frame.editRestrictions = {}
    end

    frame.listView:Hide()
    frame.treeView:Show()
    UpdateTreeViewLayout(frame)
    frame.actionBar:SetMode("tree")
    if isNew or not buildID then
        frame.actionBar:SetBuildName(LPL.BuildStore:SuggestBuildName(LPL.DB:GetTalentView()))
    else
        local build = LPL.BuildStore:Get(buildID)
        frame.actionBar:SetBuildName(build and build.name or "")
    end
    RefreshTreeEditor(frame)
end

function TalentsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLTalentsModule", parent)
    frame:SetAllPoints(parent)

    frame.viewMode = "list"
    frame.selectedBuildID = nil
    frame.activeBuildID = nil
    frame.isNewBuild = false

    frame.sandbox = LPL.TalentSandbox:New()

    local actionBar = LPL.TalentActionBar:Create(frame, {
        onBack = function()
            ShowListView(frame)
        end,
        onEdit = function()
            if frame.selectedBuildID then
                ShowTreeView(frame, frame.selectedBuildID, false)
            end
        end,
        onActivate = function()
            if not frame.selectedBuildID then
                return
            end
            LPL.TalentActivate:ApplyBuild(frame.selectedBuildID)
        end,
        onExport = function()
            local exportText, err
            local buildName

            if frame.viewMode == "list" then
                if not frame.selectedBuildID then
                    return
                end
                local build = LPL.BuildStore:Get(frame.selectedBuildID)
                if not build then
                    return
                end
                exportText, err = LPL.TalentShare:ExportBuild(build)
                buildName = build.name
            else
                local view = LPL.TalentTree:ResolveViewState()
                local name = frame.actionBar:GetBuildName()
                exportText, err = LPL.TalentShare:ExportSandbox(frame.sandbox, view, name)
                buildName = name
            end

            if not exportText or exportText == "" then
                print("|cffff6060LPL:|r " .. (err or "Nothing to export."))
                return
            end

            if err then
                print("|cffffcc00LPL:|r WoW export failed; copied LPL share string instead. " .. err)
            end

            LPL.ImportExport:OpenExport(exportText, buildName)
        end,
        onImport = function()
            LPL.ImportExport:OpenImport()
        end,
        onUpdate = function()
            local view = LPL.TalentTree:ResolveViewState()
            if not LPL.TalentTree:PlayerMatchesView(view.classID, view.specID) then
                print("|cffff6060LPL:|r Update requires your character to match this build's class and specialization.")
                return
            end

            local ok, playerSubTreeID, err = LPL.TalentTree:LoadPlayerTalentsIntoSandbox(frame.sandbox, view)
            if not ok then
                print("|cffff6060LPL:|r " .. (err or "Could not load talents from your character."))
                return
            end

            if playerSubTreeID then
                view.subTreeID = playerSubTreeID
            end

            RefreshSandboxView(frame)
            print(string.format(
                "|cff33cc33LPL:|r Loaded %d talents from your character.",
                frame.sandbox:CountPurchasedNodes()
            ))
        end,
        onReset = function()
            frame.sandbox:Clear()
            RefreshSandboxView(frame)
        end,
        onSave = function()
            local view = LPL.TalentTree:ResolveViewState()
            local name = frame.actionBar:GetBuildName()
            LPL.BuildStore:SaveFromEditor(frame.activeBuildID, frame.sandbox, view, name, function(buildID)
                local build = LPL.BuildStore:Get(buildID)
                if build and frame.editRestrictions then
                    build.restrictions = CopyTable(frame.editRestrictions)
                    LPL.BuildStore:CommitBuild(build)
                end
                frame.selectedBuildID = buildID
                ShowListView(frame)
            end)
        end,
        onNewBuild = function()
            ShowTreeView(frame, nil, true)
        end,
        onDelete = function()
            local buildID = frame.activeBuildID or frame.selectedBuildID
            if not buildID then
                return
            end
            LPL.BuildStore:ConfirmDelete(buildID, function()
                if buildID == frame.activeBuildID then
                    frame.activeBuildID = nil
                end
                frame.selectedBuildID = nil
                if frame.viewMode == "list" then
                    frame.buildList:Refresh()
                    frame.actionBar:SetListSelectionEnabled(false)
                else
                    ShowListView(frame)
                end
            end)
        end,
    })

    local listView = CreateFrame("Frame", nil, frame)
    listView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    listView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.LIST_HEIGHT)

    local buildList = LPL.TalentBuildList:Create(listView, 0)
    buildList:SetOnSelect(function(buildID)
        if frame.selectedBuildID == buildID then
            SelectBuild(frame, nil)
        else
            SelectBuild(frame, buildID)
        end
    end)
    buildList:SetOnActivate(function(buildID)
        SelectBuild(frame, buildID)
        ShowTreeView(frame, buildID, false)
    end)
    buildList:SetOnNewBuild(function()
        ShowTreeView(frame, nil, true)
    end)

    local treeView = CreateFrame("Frame", nil, frame)
    treeView:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    treeView:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, LPL.TalentActionBar.TREE_HEIGHT)
    treeView:SetFrameLevel(frame:GetFrameLevel() + 1)
    treeView:EnableMouse(false)
    treeView:Hide()

    local picker = LPL.TalentPicker:Create(treeView, function()
        ResetSandboxForView(frame)
    end, frame)

    local canvas = LPL.TalentCanvas:Create(treeView, {
        bottomInset = 12,
        getSandbox = function()
            return frame.sandbox
        end,
        onNodeChanged = function()
            RefreshTree(frame)
        end,
    })

    frame.actionBar = actionBar
    frame.listView = listView
    frame.treeView = treeView
    frame.buildList = buildList
    frame.picker = picker
    frame.canvas = canvas
    frame.editRestrictions = {}

    LPL.RestrictionsMenu:Attach(actionBar.limitsButton, function()
        frame.editRestrictions = frame.editRestrictions or {}
        local classID = LPL.DB:GetTalentView().classID
        if frame.activeBuildID then
            local build = LPL.BuildStore:Get(frame.activeBuildID)
            classID = build and build.classID or classID
        end
        return {
            classID = classID,
            restrictions = frame.editRestrictions,
        }
    end, function(record)
        frame.editRestrictions = record.restrictions or frame.editRestrictions or {}
        if frame.activeBuildID then
            local build = LPL.BuildStore:Get(frame.activeBuildID)
            if build then
                build.restrictions = CopyTable(frame.editRestrictions)
                LPL.SetRestrictions:UpdateTalentBuildFilters(build)
                LPL.BuildStore:CommitBuild(build)
            end
        end
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))

    LPL.RestrictionsMenu:Attach(actionBar.listLimitsButton, function()
        local build = frame.selectedBuildID and LPL.BuildStore:Get(frame.selectedBuildID)
        if not build then
            return { restrictions = {} }
        end
        return build
    end, function(record)
        if not frame.selectedBuildID then
            return
        end
        local build = LPL.BuildStore:Get(frame.selectedBuildID)
        if build then
            build.restrictions = CopyTable(record.restrictions or {})
            LPL.SetRestrictions:UpdateTalentBuildFilters(build)
            LPL.BuildStore:CommitBuild(build)
            frame.buildList:Refresh()
        end
    end, CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES))
    function frame:RefreshTreeEditor()
        RefreshTreeEditor(frame)
    end

    function frame:Refresh()
        if frame.viewMode == "list" then
            frame.buildList:SetSelectedBuildID(frame.selectedBuildID)
            frame.buildList:Refresh()
            local hasBuilds = #LPL.BuildStore:GetAll() > 0
            UpdateListViewLayout(frame, hasBuilds)
            frame.actionBar:SetMode("list", not hasBuilds)
            frame.actionBar:SetListSelectionEnabled(frame.selectedBuildID ~= nil)
        else
            frame:RefreshTreeEditor()
        end
    end

    function frame:ShowList()
        ShowListView(frame)
    end

    LPL.TalentTree:WhenReady(function()
        if frame:IsShown() then
            C_Timer.After(0, function()
                if frame:IsShown() then
                    frame:Refresh()
                end
            end)
        end
    end)

    ShowListView(frame)
    frame:Hide()
    TalentsModule.instance = frame
    return frame
end

function TalentsModule:OnShow()
    if self.instance then
        C_Timer.After(0, function()
            if self.instance and self.instance:IsShown() then
                if LPL.DB and LPL.DB.SyncFromGlobal then
                    LPL.DB:SyncFromGlobal()
                end
                self.instance:ShowList()
                self.instance:Refresh()
            end
        end)
    end
end

LPL.Modules:Register({
    id = TalentsModule.id,
    label = TalentsModule.label,
    description = TalentsModule.description,
    icon = TalentsModule.icon,
    order = TalentsModule.order,
    create = TalentsModule.create,
    OnShow = function(module)
        TalentsModule:OnShow()
    end,
})
