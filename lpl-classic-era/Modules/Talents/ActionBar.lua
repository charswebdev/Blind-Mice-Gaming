local addonName, LPL = ...

LPL.TalentActionBar = {
    LIST_HEIGHT = 44,
    TREE_HEIGHT = 84,
    HEIGHT = 44,
    LIST_MARGIN = 12,
    LIST_MIN_GAP = 8,
    TREE_NAME_ROW_INSET = 6,
    TREE_BUTTON_ROW_INSET = 8,
}

function LPL.TalentActionBar:Create(parent, handlers, options)
    options = options or {}
    local showActivate = options.showActivate ~= false
    local showUpdate = options.showUpdate ~= false
    local showReset = options.showReset ~= false
    local showLimits = options.showLimits ~= false
    local showExport = options.showExport ~= false
    local showListImport = options.showListImport == true
    local showEnableSet = options.showEnableSet == true
    local showDisableSet = options.showDisableSet == true
    local showImport = options.showImport ~= false
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    bar:SetHeight(self.LIST_HEIGHT)
    bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bar:SetFrameLevel(parent:GetFrameLevel() + 20)
    if bar.SetClipsChildren then
        bar:SetClipsChildren(true)
    end
    LPL.Theme:ApplyBackdrop(bar, "panel", "titleBar", "border")

    bar.treeCanDelete = false
    bar.treeCanUpdate = false

    local listButtons = {}
    local treeButtons = {}

    local function AttachTooltip(button, tooltipTitle, tooltipBody)
        if not tooltipTitle then
            return
        end

        local onEnter = button:GetScript("OnEnter")
        local onLeave = button:GetScript("OnLeave")
        button:SetScript("OnEnter", function(self)
            if onEnter then
                onEnter(self)
            end
            if self:IsEnabled() then
                LPL:ShowAccessibleGameTooltip(self, tooltipTitle, tooltipBody)
            end
        end)
        button:SetScript("OnLeave", function(self)
            if onLeave then
                onLeave(self)
            end
            LPL:ClearGameTooltipData(GameTooltip)
        end)
    end

    local function CreateActionButton(text, width, handlerKey, tooltipTitle, tooltipBody)
        local button = LPL:CreateButton(nil, bar)
        button:SetSize(width, 28)
        button:SetText(text)
        button:Hide()
        button:SetScript("OnClick", function()
            if handlers and handlers[handlerKey] then
                handlers[handlerKey]()
            end
        end)
        AttachTooltip(button, tooltipTitle, tooltipBody)
        return button
    end

    local function CreateListActionButton(text, width, handlerKey, tooltipTitle, tooltipBody)
        local button = CreateActionButton(text, width, handlerKey, tooltipTitle, tooltipBody)
        listButtons[#listButtons + 1] = button
        return button
    end

    local function CreateTreeActionButton(text, width, handlerKey, tooltipTitle, tooltipBody)
        local button = CreateActionButton(text, width, handlerKey, tooltipTitle, tooltipBody)
        treeButtons[#treeButtons + 1] = button
        return button
    end

    local newButton = CreateListActionButton(
        options.newButtonLabel or "+ New Build",
        options.newButtonWidth or 118,
        "onNewBuild",
        options.newButtonTooltipTitle or options.newButtonLabel or "+ New Build",
        options.newButtonTooltipBody
    )
    local editButton = CreateListActionButton(
        "Edit",
        72,
        "onEdit",
        "Edit",
        options.editTooltip or "Edit the selected build in the talent tree"
    )
    local activateButton = CreateActionButton(
        "Activate",
        options.activateButtonWidth or 88,
        "onActivate",
        options.activateTooltipTitle or "Activate",
        options.activateTooltipBody or "Apply this build to your character"
    )
    if showActivate then
        listButtons[#listButtons + 1] = activateButton
    end
    local enableSetButton = CreateActionButton(
        "Enable",
        options.enableSetButtonWidth or 76,
        "onEnableSet",
        options.enableSetTooltipTitle or "Enable Set",
        options.enableSetTooltipBody or "Enable addons in the selected set(s) without disabling others"
    )
    if showEnableSet then
        listButtons[#listButtons + 1] = enableSetButton
    end
    local disableSetButton = CreateActionButton(
        "Disable",
        options.disableSetButtonWidth or 80,
        "onDisableSet",
        options.disableSetTooltipTitle or "Disable Set",
        options.disableSetTooltipBody or "Disable addons in the selected set(s) without changing others"
    )
    if showDisableSet then
        listButtons[#listButtons + 1] = disableSetButton
    end
    local listImportButton = CreateActionButton("Import", 76, "onImport", "Import", "Import from a share string")
    if showListImport then
        listButtons[#listButtons + 1] = listImportButton
    end
    local listExportButton = CreateActionButton("Export", 76, "onExport", "Export", "Copy this build for sharing")
    if showExport then
        listButtons[#listButtons + 1] = listExportButton
    end
    local listLimitsButton = CreateActionButton("Limits", 72, "onLimits", "Limits", "Restrict this build to specific characters, specs, or races")
    if showLimits then
        listButtons[#listButtons + 1] = listLimitsButton
    end
    local deleteButton = CreateActionButton(
        "Delete",
        76,
        "onDelete",
        options.deleteTooltipTitle or "Delete",
        options.deleteTooltipBody or "Remove this build from your library"
    )
    listButtons[#listButtons + 1] = deleteButton

    local backButton = LPL:CreateButton(nil, bar)
    backButton:SetSize(88, 28)
    backButton:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 12, 8)
    backButton:SetText("Back")
    backButton:Hide()
    backButton:SetScript("OnClick", function()
        if handlers and handlers.onBack then
            handlers.onBack()
        end
    end)
    AttachTooltip(
        backButton,
        options.backTooltipTitle or "Back",
        options.backTooltipBody or "Return to the build list"
    )

    local updateButton = CreateActionButton("Update", 80, "onUpdate")
    do
        local updateTooltipTitle = options.updateTooltipTitle or "Update"
        local updateTooltipBody = options.updateTooltipBody
            or "Load your character's current talents into the planner"
        local updateTooltipDisabled = options.updateTooltipDisabled
            or "Your character must match this build's class and specialization."
        local hoverEnter = updateButton:GetScript("OnEnter")
        local hoverLeave = updateButton:GetScript("OnLeave")
        updateButton:SetScript("OnEnter", function(self)
            if hoverEnter then
                hoverEnter(self)
            end
            if self:IsEnabled() then
                LPL:ShowAccessibleGameTooltip(self, updateTooltipTitle, updateTooltipBody)
            else
                LPL:ShowAccessibleGameTooltip(self, updateTooltipTitle, updateTooltipDisabled)
            end
        end)
        updateButton:SetScript("OnLeave", function(self)
            if hoverLeave then
                hoverLeave(self)
            end
            LPL:ClearGameTooltipData(GameTooltip)
        end)
    end
    if showUpdate then
        treeButtons[#treeButtons + 1] = updateButton
    end
    local saveButton = CreateTreeActionButton(
        "Save",
        72,
        "onSave",
        options.saveTooltipTitle or "Save",
        options.saveTooltipBody or "Save this build using the name field"
    )
    local importButton = CreateActionButton(
        "Import",
        76,
        "onImport",
        options.importTooltipTitle or "Import",
        options.importTooltipBody or "Import a build from a share string"
    )
    if showImport then
        treeButtons[#treeButtons + 1] = importButton
    end
    local exportButton = CreateActionButton("Export", 76, "onExport", "Export", "Copy this build for sharing")
    if showExport then
        treeButtons[#treeButtons + 1] = exportButton
    end
    local resetButton = CreateActionButton("Reset", 72, "onReset", "Reset", "Clear all selected talents in the planner")
    if showReset then
        treeButtons[#treeButtons + 1] = resetButton
    end
    local limitsButton = CreateActionButton("Limits", 72, "onLimits", "Limits", "Restrict this set to specific characters, classes, or specs")
    if showLimits then
        treeButtons[#treeButtons + 1] = limitsButton
    end
    treeButtons[#treeButtons + 1] = deleteButton

    local nameLabel = LPL:CreateLabel(bar, "small")
    nameLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))
    nameLabel:SetText(options.nameLabel or "Build name")
    nameLabel:Hide()

    local nameBox = LPL:CreateEditBox(nil, bar, 320)
    nameBox:SetHeight(28)
    nameBox:Hide()
    nameBox:SetOnEnterPressed(function()
        if handlers and handlers.onSave then
            handlers.onSave()
        end
    end)

    local function SetButtonEnabled(button, enabled)
        if enabled then
            button:Enable()
        else
            button:Disable()
        end
    end

    function bar:LayoutListButtons()
        if self.mode ~= "list" then
            return
        end

        local barWidth = self:GetWidth()
        if barWidth < 1 then
            return
        end

        local totalButtonWidth = 0
        for _, button in ipairs(listButtons) do
            totalButtonWidth = totalButtonWidth + button:GetWidth()
        end

        local margin = LPL.TalentActionBar.LIST_MARGIN
        local gap = LPL.TalentActionBar.LIST_MIN_GAP
        if #listButtons > 1 then
            local available = barWidth - (margin * 2)
            local needed = totalButtonWidth + gap * (#listButtons - 1)
            if needed > available then
                gap = math.max(4, (available - totalButtonWidth) / (#listButtons - 1))
            end
        end

        local offset = margin
        for index = #listButtons, 1, -1 do
            local button = listButtons[index]
            button:ClearAllPoints()
            button:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -offset, 8)
            offset = offset + button:GetWidth()
            if index > 1 then
                offset = offset + gap
            end
        end
    end

    function bar:LayoutTreeButtons()
        if self.mode ~= "tree" then
            return
        end

        local barWidth = self:GetWidth()
        if barWidth < 1 then
            local host = self:GetParent()
            barWidth = host and host:GetWidth() or 0
        end
        if barWidth < 1 then
            return
        end

        local margin = LPL.TalentActionBar.LIST_MARGIN
        local nameRowInset = LPL.TalentActionBar.TREE_NAME_ROW_INSET
        local buttonRowInset = LPL.TalentActionBar.TREE_BUTTON_ROW_INSET
        local nameRowHeight = 28
        local nameRowTop = -nameRowInset
        local labelHeight = nameLabel:GetStringHeight()
        if not labelHeight or labelHeight < 1 then
            labelHeight = 11
        end
        local labelTop = nameRowTop - math.floor((nameRowHeight - labelHeight) / 2)

        nameLabel:ClearAllPoints()
        nameLabel:SetPoint("TOPLEFT", bar, "TOPLEFT", margin, labelTop)

        nameBox:ClearAllPoints()
        nameBox:SetPoint("TOP", bar, "TOP", 0, nameRowTop)
        nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
        nameBox:SetPoint("RIGHT", bar, "RIGHT", -margin, 0)
        nameBox:SetHeight(nameRowHeight)

        backButton:ClearAllPoints()
        backButton:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", margin, buttonRowInset)

        local totalButtonWidth = 0
        for _, button in ipairs(treeButtons) do
            totalButtonWidth = totalButtonWidth + button:GetWidth()
        end

        local gap = LPL.TalentActionBar.LIST_MIN_GAP
        if #treeButtons > 1 then
            local available = barWidth - (margin * 2)
            local needed = totalButtonWidth + gap * (#treeButtons - 1)
            if needed > available then
                gap = math.max(4, (available - totalButtonWidth) / (#treeButtons - 1))
            end
        end

        local offset = margin
        for index = #treeButtons, 1, -1 do
            local button = treeButtons[index]
            button:ClearAllPoints()
            button:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -offset, buttonRowInset)
            offset = offset + button:GetWidth()
            if index > 1 then
                offset = offset + gap
            end
        end
    end

    function bar:SetBuildName(name)
        nameBox:SetText(name or "")
    end

    function bar:GetBuildName()
        return nameBox:GetText()
    end

    function bar:SetListSelectionEnabled(enabled)
        SetButtonEnabled(editButton, enabled)
        if showActivate then
            SetButtonEnabled(activateButton, enabled)
        end
        if showEnableSet then
            SetButtonEnabled(enableSetButton, enabled)
        end
        if showDisableSet then
            SetButtonEnabled(disableSetButton, enabled)
        end
        if showExport then
            SetButtonEnabled(listExportButton, enabled)
        end
        if showLimits then
            SetButtonEnabled(listLimitsButton, enabled)
        end
        SetButtonEnabled(deleteButton, enabled)
        if showListImport then
            SetButtonEnabled(listImportButton, true)
        end
    end

    function bar:SetEditEnabled(enabled)
        SetButtonEnabled(editButton, enabled)
    end

    function bar:SetTreeActionState(canDelete, canUpdate)
        self.treeCanDelete = canDelete and true or false
        self.treeCanUpdate = canUpdate and true or false
        if self.mode == "tree" then
            if showUpdate then
                SetButtonEnabled(updateButton, self.treeCanUpdate)
            end
            SetButtonEnabled(deleteButton, self.treeCanDelete)
        end
    end

    function bar:SetMode(mode, listEmpty)
        self.mode = mode
        listEmpty = listEmpty or false
        self.listEmpty = listEmpty

        if mode == "tree" then
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
            self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
            self:SetHeight(LPL.TalentActionBar.TREE_HEIGHT)
            self:Show()
            backButton:Show()
            nameLabel:Show()
            nameBox:Show()

            for _, button in ipairs(listButtons) do
                button:Hide()
            end

            for _, button in ipairs(treeButtons) do
                button:Show()
            end

            if showUpdate then
                SetButtonEnabled(updateButton, self.treeCanUpdate)
            end
            SetButtonEnabled(saveButton, true)
            if showImport then
                SetButtonEnabled(importButton, true)
            end
            if showExport then
                SetButtonEnabled(exportButton, true)
            end
            if showReset then
                SetButtonEnabled(resetButton, true)
            end
            SetButtonEnabled(deleteButton, self.treeCanDelete)

            self:LayoutTreeButtons()
        else
            self:ClearAllPoints()
            self:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
            self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
            self:SetHeight(LPL.TalentActionBar.LIST_HEIGHT)
            self:Show()
            backButton:Hide()
            nameLabel:Hide()
            nameBox:Hide()

            for _, button in ipairs(treeButtons) do
                if button ~= deleteButton then
                    button:Hide()
                end
            end

            for _, button in ipairs(listButtons) do
                button:Show()
            end

            self:LayoutListButtons()
        end
    end

    function bar:UpdateTreeActions(canDelete, canUpdate)
        self:SetTreeActionState(canDelete, canUpdate)
        if self.mode == "tree" then
            self:LayoutTreeButtons()
        end
    end

    function bar:SetListEmpty(isEmpty)
        if self.mode == "list" then
            self:SetMode("list", isEmpty)
        end
    end

    function bar:SetDeleteEnabled(enabled)
        if self.mode == "list" then
            self:SetListSelectionEnabled(enabled)
            return
        end
        self:SetTreeActionState(enabled, self.treeCanUpdate)
    end

    bar:SetScript("OnSizeChanged", function()
        if bar.mode == "list" then
            bar:LayoutListButtons()
        elseif bar.mode == "tree" then
            bar:LayoutTreeButtons()
        end
    end)

    bar.newButton = newButton
    bar.editButton = editButton
    bar.activateButton = activateButton
    bar.enableSetButton = enableSetButton
    bar.disableSetButton = disableSetButton
    bar.listImportButton = listImportButton
    bar.listExportButton = listExportButton
    bar.listLimitsButton = listLimitsButton
    bar.updateButton = updateButton
    bar.saveButton = saveButton
    bar.importButton = importButton
    bar.exportButton = exportButton
    bar.resetButton = resetButton
    bar.limitsButton = limitsButton
    bar.deleteButton = deleteButton
    bar.showActivate = showActivate
    bar.showEnableSet = showEnableSet
    bar.showDisableSet = showDisableSet
    bar.showUpdate = showUpdate
    bar.showReset = showReset
    bar.showLimits = showLimits
    bar.showExport = showExport
    bar.showImport = showImport
    bar.showListImport = showListImport
    bar.backButton = backButton
    bar.nameLabel = nameLabel
    bar.nameBox = nameBox
    bar.listButtons = listButtons
    bar.treeButtons = treeButtons
    bar:SetMode("list")
    bar:SetListSelectionEnabled(false)

    return bar
end
