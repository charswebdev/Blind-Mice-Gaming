local _, ns = ...

local AddTab = {}
ns.AddTab = AddTab

AddTab.FORM_WIDTH = 268

function AddTab:FormatCoordPercent(value)
    if not value then
        return ""
    end
    return string.format("%.1f", value * 100)
end

function AddTab:GetSelectedTagsList()
    return ns.LocationTags:CollectSelected(self.selectedTags)
end

function AddTab:IsUseCurrentLocation()
    if not self.useCurrentCheck then
        return false
    end
    return not not self.useCurrentCheck:GetChecked()
end

function AddTab:RefreshTagDropdownText()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local text = ns.LocationTags:FormatList(self:GetSelectedTagsList()) or L["TAG_NONE"]
    UIDropDownMenu_SetText(self.tagDropdown, text)
end

function AddTab:ToggleTag(tag, checked)
    if checked == nil then
        checked = not self.selectedTags[tag]
    end
    if checked then
        self.selectedTags[tag] = true
    else
        self.selectedTags[tag] = nil
    end
    self:RefreshTagDropdownText()
end

function AddTab:ClearSelectedTags()
    wipe(self.selectedTags)
    self:RefreshTagDropdownText()
end

function AddTab:UpdateLocationMode()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local useCurrent = self:IsUseCurrentLocation()
    self.manualPanel:SetShown(not useCurrent)
    self.locationHint:SetShown(useCurrent)
    if useCurrent then
        self.locationHint:SetText(L["LOCATION_CURRENT_HINT"])
        self.locationCard:SetHeight(56)
    else
        self.locationCard:SetHeight(128)
    end
    self:UpdateFormHeight()
end

function AddTab:UpdateFormHeight()
    if not self.formContent then
        return
    end
    local height = self.manualPanel:IsShown() and 410 or 340
    self.formContent:SetHeight(height)
    self:ClampScroll()
end

function AddTab:ClampScroll()
    if not self.scroll then
        return
    end
    local maxScroll = math.max(0, (self.formContent:GetHeight() or 0) - (self.scroll:GetHeight() or 0))
    local current = self.scroll:GetVerticalScroll() or 0
    if current > maxScroll then
        self.scroll:SetVerticalScroll(maxScroll)
    elseif current < 0 then
        self.scroll:SetVerticalScroll(0)
    end
end

function AddTab:ResetScroll()
    if not self.scroll then
        return
    end
    self.scroll:SetVerticalScroll(0)
    local bar = self.scroll.ScrollBar
    if bar and bar.SetValue then
        bar:SetValue(0)
    end
end

function AddTab:FillFromPlayer()
    local loc = ns.CustomLocations:GetPlayerLocation()
    if not loc then
        return
    end

    self.useCurrentCheck:SetChecked(false)
    self.zoneBox:SetText(loc.areaName or "")
    self.mapIdBox:SetText(tostring(loc.mapId))
    self.xBox:SetText(self:FormatCoordPercent(loc.x))
    self.yBox:SetText(self:FormatCoordPercent(loc.y))
    self:UpdateLocationMode()
end

function AddTab:GetSaveLocation()
    if self:IsUseCurrentLocation() then
        return ns.CustomLocations:GetPlayerLocation()
    end

    return ns.CustomLocations:ResolveManualLocation(
        self.zoneBox:GetText(),
        self.mapIdBox:GetText(),
        self.xBox:GetText(),
        self.yBox:GetText()
    )
end

function AddTab:ClearManualFields()
    self.zoneBox:SetText("")
    self.mapIdBox:SetText("")
    self.xBox:SetText("")
    self.yBox:SetText("")
end

function AddTab:ClearForm()
    self.nameBox:SetText("")
    self.noteBox:SetText("")
    self:ClearSelectedTags()
    self.useCurrentCheck:SetChecked(false)
    self:ClearManualFields()
    self:UpdateLocationMode()
end

function AddTab:GoToSavedTab()
    if ns.MainFrame then
        ns.MainFrame:SelectTab("saved")
    elseif ns.SavedTab then
        ns.SavedTab:RefreshList()
    end
end

function AddTab:ClearEditing()
    self.editingRecord = nil
    self:UpdateSaveButtonLabel()
end

function AddTab:UpdateSaveButtonLabel()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    if self.editingRecord then
        self.saveBtn:SetText(L["UPDATE"])
        self.cancelBtn:Show()
        self.modeLabel:SetText(L["ADD_EDITING"])
        self.modeLabel:Show()
        self.importBtn:SetPoint("LEFT", self.cancelBtn, "RIGHT", 8, 0)
    else
        self.saveBtn:SetText(L["SAVE"])
        self.cancelBtn:Hide()
        self.modeLabel:Hide()
        self.importBtn:SetPoint("LEFT", self.saveBtn, "RIGHT", 8, 0)
    end
end

function AddTab:LoadRecord(record)
    if not record then
        return
    end

    self.editingRecord = { id = record.id, scope = record.scope }
    self.nameBox:SetText(record.name or "")
    self.noteBox:SetText(record.note or "")
    self.selectedScope = record.scope or "account"
    UIDropDownMenu_SetText(
        self.scopeDropdown,
        self.selectedScope == "account" and LibStub("AceLocale-3.0"):GetLocale("WowGPS")["SCOPE_ACCOUNT"]
            or LibStub("AceLocale-3.0"):GetLocale("WowGPS")["SCOPE_CHARACTER"]
    )

    ns.LocationTags:SetSelectedFromRecord(self.selectedTags, record)
    self:RefreshTagDropdownText()

    self.useCurrentCheck:SetChecked(false)
    self.zoneBox:SetText(record.areaName or "")
    self.mapIdBox:SetText(tostring(record.mapId or ""))
    self.xBox:SetText(self:FormatCoordPercent(record.x))
    self.yBox:SetText(self:FormatCoordPercent(record.y))
    self:UpdateLocationMode()
    self:UpdateSaveButtonLabel()
end

function AddTab:CreateFieldLabel(parent, text, anchor, x, y)
    local theme = ns.Theme
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -8)
    label:SetText(text)
    theme:SetTextColor(label, theme.colors.textMuted)
    return label
end

function AddTab:Build(parent, mainFrame)
    self.parent = parent
    self.mainFrame = mainFrame
    self.editingRecord = nil
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme
    local addTab = self

    local headerRow = CreateFrame("Frame", nil, parent)
    headerRow:SetPoint("TOPLEFT", 12, -10)
    headerRow:SetPoint("TOPRIGHT", -12, -10)
    headerRow:SetHeight(20)

    self.header = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.header:SetPoint("LEFT", 0, 0)
    self.header:SetText(L["ADD_HEADER"])
    theme:SetReadableFont(self.header, 14)
    theme:SetTextColor(self.header, theme.colors.text)

    self.modeLabel = headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.modeLabel:SetPoint("RIGHT", 0, 0)
    theme:SetTextColor(self.modeLabel, theme.colors.accent)
    self.modeLabel:Hide()

    self.hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.hint:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    self.hint:SetPoint("TOPRIGHT", -12, 0)
    self.hint:SetJustifyH("LEFT")
    self.hint:SetText(L["ADD_HINT"])
    theme:SetTextColor(self.hint, theme.colors.textMuted)

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", self.hint, "BOTTOMLEFT", -4, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 44)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)
    local formContent = CreateFrame("Frame", nil, scroll)
    formContent:SetSize(self.FORM_WIDTH, 420)
    scroll:SetScrollChild(formContent)
    scroll:SetScript("OnMouseWheel", function(frame, delta)
        local maxScroll = math.max(0, formContent:GetHeight() - frame:GetHeight())
        local step = 28
        local nextScroll = math.min(maxScroll, math.max(0, frame:GetVerticalScroll() - (delta * step)))
        frame:SetVerticalScroll(nextScroll)
    end)
    scroll:SetScript("OnShow", function()
        addTab:ResetScroll()
    end)
    self.scroll = scroll
    self.formContent = formContent

    local detailsHeader = formContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detailsHeader:SetPoint("TOPLEFT", 4, -4)
    detailsHeader:SetText(L["ADD_SECTION_DETAILS"])
    theme:SetTextColor(detailsHeader, theme.colors.sectionHeader)

    local nameLabel = self:CreateFieldLabel(formContent, L["NAME"], detailsHeader, 0, -6)
    local nameBox = CreateFrame("EditBox", nil, formContent, "InputBoxTemplate")
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameBox:SetPoint("TOPRIGHT", formContent, "TOPRIGHT", -4, 0)
    nameBox:SetHeight(22)
    theme:StyleEditBox(nameBox)
    self.nameBox = nameBox

    local noteLabel = self:CreateFieldLabel(formContent, L["NOTE"], nameBox, 0, -8)
    local noteBox = CreateFrame("EditBox", nil, formContent, "InputBoxTemplate")
    noteBox:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 0, -4)
    noteBox:SetPoint("TOPRIGHT", formContent, "TOPRIGHT", -4, 0)
    noteBox:SetHeight(22)
    theme:StyleEditBox(noteBox)
    self.noteBox = noteBox

    local locationHeader = formContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    locationHeader:SetPoint("TOPLEFT", noteBox, "BOTTOMLEFT", 0, -12)
    locationHeader:SetText(L["ADD_SECTION_LOCATION"])
    theme:SetTextColor(locationHeader, theme.colors.sectionHeader)

    local locationCard = CreateFrame("Frame", nil, formContent, "BackdropTemplate")
    locationCard:SetPoint("TOPLEFT", locationHeader, "BOTTOMLEFT", 0, -6)
    locationCard:SetPoint("TOPRIGHT", formContent, "TOPRIGHT", -4, 0)
    locationCard:SetHeight(128)
    theme:StyleCard(locationCard)
    self.locationCard = locationCard

    local useCurrentCheck = CreateFrame("CheckButton", nil, locationCard, "UICheckButtonTemplate")
    useCurrentCheck:SetPoint("TOPLEFT", 8, -8)
    useCurrentCheck:SetFrameLevel(locationCard:GetFrameLevel() + 2)
    useCurrentCheck:EnableMouse(true)
    useCurrentCheck:RegisterForClicks("LeftButtonUp")
    useCurrentCheck.text = useCurrentCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    useCurrentCheck.text:SetPoint("LEFT", useCurrentCheck, "RIGHT", 4, 0)
    useCurrentCheck.text:SetText(L["USE_CURRENT_LOCATION"])
    theme:SetTextColor(useCurrentCheck.text, theme.colors.text)
    useCurrentCheck:SetHitRectInsets(-(useCurrentCheck.text:GetStringWidth() + 8), 0, -4, -4)
    useCurrentCheck:SetChecked(false)
    useCurrentCheck:SetScript("OnClick", function()
        addTab:UpdateLocationMode()
    end)
    self.useCurrentCheck = useCurrentCheck

    local locationHint = locationCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    locationHint:SetPoint("TOPLEFT", useCurrentCheck, "BOTTOMLEFT", 2, -4)
    locationHint:SetPoint("TOPRIGHT", -8, 0)
    locationHint:SetJustifyH("LEFT")
    locationHint:SetText(L["LOCATION_CURRENT_HINT"])
    theme:SetTextColor(locationHint, theme.colors.textMuted)
    self.locationHint = locationHint

    local manualPanel = CreateFrame("Frame", nil, locationCard)
    manualPanel:SetPoint("TOPLEFT", useCurrentCheck, "BOTTOMLEFT", 2, -4)
    manualPanel:SetPoint("TOPRIGHT", locationCard, "TOPRIGHT", -8, 0)
    manualPanel:SetHeight(92)
    self.manualPanel = manualPanel

    local zoneLabel = manualPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneLabel:SetPoint("TOPLEFT", 0, 0)
    zoneLabel:SetText(L["LOCATION_ZONE"])
    theme:SetTextColor(zoneLabel, theme.colors.textMuted)

    local fillHereBtn = CreateFrame("Button", nil, manualPanel, "BackdropTemplate")
    fillHereBtn:SetSize(72, 20)
    fillHereBtn:SetPoint("TOP", zoneLabel, "BOTTOM", 0, -2)
    fillHereBtn:SetPoint("RIGHT", manualPanel, "RIGHT", 0, 0)
    theme:StyleSmallButton(fillHereBtn)
    fillHereBtn:SetText(L["LOCATION_FILL_HERE"])
    fillHereBtn:SetScript("OnClick", function()
        addTab:FillFromPlayer()
    end)

    local zoneBox = CreateFrame("EditBox", nil, manualPanel, "InputBoxTemplate")
    zoneBox:SetPoint("TOPLEFT", zoneLabel, "BOTTOMLEFT", 0, -2)
    zoneBox:SetPoint("RIGHT", fillHereBtn, "LEFT", -8, 0)
    zoneBox:SetHeight(20)
    theme:StyleEditBox(zoneBox)
    self.zoneBox = zoneBox

    local coordRow = CreateFrame("Frame", nil, manualPanel)
    coordRow:SetPoint("TOPLEFT", zoneBox, "BOTTOMLEFT", 0, -8)
    coordRow:SetPoint("TOPRIGHT", manualPanel, "TOPRIGHT", 0, 0)
    coordRow:SetHeight(44)

    local colGap = 8
    local colWidth = math.floor((self.FORM_WIDTH - 36 - (colGap * 2)) / 3)
    if colWidth < 56 then
        colWidth = 56
    end

    local mapIdLabel = coordRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mapIdLabel:SetPoint("TOPLEFT", 0, 0)
    mapIdLabel:SetWidth(colWidth)
    mapIdLabel:SetJustifyH("LEFT")
    mapIdLabel:SetText(L["LOCATION_MAP_ID"])
    theme:SetTextColor(mapIdLabel, theme.colors.textMuted)

    local mapIdBox = CreateFrame("EditBox", nil, coordRow, "InputBoxTemplate")
    mapIdBox:SetPoint("TOPLEFT", mapIdLabel, "BOTTOMLEFT", 0, -2)
    mapIdBox:SetSize(colWidth, 20)
    theme:StyleEditBox(mapIdBox)
    self.mapIdBox = mapIdBox

    local xLabel = coordRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xLabel:SetPoint("TOPLEFT", mapIdLabel, "TOPRIGHT", colGap, 0)
    xLabel:SetWidth(colWidth)
    xLabel:SetJustifyH("LEFT")
    xLabel:SetText(L["LOCATION_X"])
    theme:SetTextColor(xLabel, theme.colors.textMuted)

    local xBox = CreateFrame("EditBox", nil, coordRow, "InputBoxTemplate")
    xBox:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -2)
    xBox:SetSize(colWidth, 20)
    theme:StyleEditBox(xBox)
    self.xBox = xBox

    local yLabel = coordRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yLabel:SetPoint("TOPLEFT", xLabel, "TOPRIGHT", colGap, 0)
    yLabel:SetWidth(colWidth)
    yLabel:SetJustifyH("LEFT")
    yLabel:SetText(L["LOCATION_Y"])
    theme:SetTextColor(yLabel, theme.colors.textMuted)

    local yBox = CreateFrame("EditBox", nil, coordRow, "InputBoxTemplate")
    yBox:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -2)
    yBox:SetSize(colWidth, 20)
    theme:StyleEditBox(yBox)
    self.yBox = yBox

    local organizeHeader = formContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    organizeHeader:SetPoint("TOPLEFT", locationCard, "BOTTOMLEFT", 0, -12)
    organizeHeader:SetText(L["ADD_SECTION_ORGANIZE"])
    theme:SetTextColor(organizeHeader, theme.colors.sectionHeader)

    local organizeCard = CreateFrame("Frame", nil, formContent, "BackdropTemplate")
    organizeCard:SetPoint("TOPLEFT", organizeHeader, "BOTTOMLEFT", 0, -6)
    organizeCard:SetPoint("TOPRIGHT", formContent, "TOPRIGHT", -4, 0)
    organizeCard:SetHeight(72)
    theme:StyleCard(organizeCard)

    local tagLabel = organizeCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tagLabel:SetPoint("TOPLEFT", 10, -10)
    tagLabel:SetText(L["TAG"])
    theme:SetTextColor(tagLabel, theme.colors.textMuted)

    self.selectedTags = {}
    local tagDropdown = CreateFrame("Frame", "WowGPSTagDropdown", organizeCard, "UIDropDownMenuTemplate")
    tagDropdown:SetPoint("TOPLEFT", tagLabel, "TOPRIGHT", -8, 4)
    UIDropDownMenu_SetWidth(tagDropdown, 180)
    UIDropDownMenu_Initialize(tagDropdown, function(_, level)
        for _, opt in ipairs(ns.LocationTags:GetTypeOptions(false)) do
            local info = UIDropDownMenu_CreateInfo()
            local tag = opt.key
            info.text = opt.label
            info.isNotRadio = 1
            info.keepShownOnClick = 1
            info.notCheckable = nil
            info.checked = function()
                return addTab.selectedTags[tag] and true or false
            end
            info.func = function(_, _, _, checked)
                addTab:ToggleTag(tag, checked)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    self.tagDropdown = tagDropdown
    self:RefreshTagDropdownText()

    local scopeLabel = organizeCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scopeLabel:SetPoint("TOPLEFT", tagLabel, "BOTTOMLEFT", 0, -16)
    scopeLabel:SetText(L["SCOPE"])
    theme:SetTextColor(scopeLabel, theme.colors.textMuted)

    local scopeDropdown = CreateFrame("Frame", "WowGPSScopeDropdown", organizeCard, "UIDropDownMenuTemplate")
    scopeDropdown:SetPoint("TOPLEFT", scopeLabel, "TOPRIGHT", -8, 4)
    self.selectedScope = ns.Database:GetProfile().defaultCustomScope or "account"
    UIDropDownMenu_SetWidth(scopeDropdown, 160)
    UIDropDownMenu_Initialize(scopeDropdown, function(_, level)
        local info = UIDropDownMenu_CreateInfo()
        info.text = L["SCOPE_ACCOUNT"]
        info.func = function()
            addTab.selectedScope = "account"
            UIDropDownMenu_SetText(scopeDropdown, L["SCOPE_ACCOUNT"])
        end
        UIDropDownMenu_AddButton(info, level)
        info.text = L["SCOPE_CHARACTER"]
        info.func = function()
            addTab.selectedScope = "character"
            UIDropDownMenu_SetText(scopeDropdown, L["SCOPE_CHARACTER"])
        end
        UIDropDownMenu_AddButton(info, level)
    end)
    UIDropDownMenu_SetText(scopeDropdown, self.selectedScope == "account" and L["SCOPE_ACCOUNT"] or L["SCOPE_CHARACTER"])
    self.scopeDropdown = scopeDropdown

    local saveBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    saveBtn:SetSize(80, 26)
    saveBtn:SetPoint("BOTTOMLEFT", 12, 12)
    saveBtn:SetText(L["SAVE"])
    theme:StyleSmallButton(saveBtn)
    saveBtn:SetScript("OnClick", function()
        addTab:SaveLocation()
    end)
    self.saveBtn = saveBtn

    local cancelBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    cancelBtn:SetSize(80, 26)
    cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    cancelBtn:SetText(L["CANCEL"])
    theme:StyleSmallButton(cancelBtn)
    cancelBtn:Hide()
    cancelBtn:SetScript("OnClick", function()
        local wasEditing = addTab.editingRecord ~= nil
        addTab:ClearForm()
        addTab:ClearEditing()
        if wasEditing then
            addTab:GoToSavedTab()
        end
    end)
    self.cancelBtn = cancelBtn

    local importBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    importBtn:SetSize(80, 26)
    importBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    importBtn:SetText(L["IMPORT"])
    importBtn:RegisterForClicks("LeftButtonUp")
    importBtn:EnableMouse(true)
    theme:StyleButton(importBtn)
    importBtn:SetScript("OnClick", function()
        addTab:PromptImport()
    end)
    self.importBtn = importBtn

    ns.ImportDialog:Init()

    self:UpdateLocationMode()
    self:UpdateSaveButtonLabel()
    self:ResetScroll()
end

function AddTab:SaveLocation()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local name = self.nameBox:GetText()
    if not name or name:gsub("%s", "") == "" then
        return
    end

    local location, err = self:GetSaveLocation()
    if not location then
        if err == "bad_coords" then
            WowGPS:Print(string.format(L["SAVE_LOCATION_FAILED"], L["SAVE_LOCATION_BAD_COORDS"]))
        elseif err == "bad_map" or err == "no_map" then
            WowGPS:Print(string.format(L["SAVE_LOCATION_FAILED"], L["SAVE_LOCATION_BAD_MAP"]))
        else
            WowGPS:Print(string.format(L["SAVE_LOCATION_FAILED"], err or L["SAVE_LOCATION_BAD_MAP"]))
        end
        return
    end

    local tags = self:GetSelectedTagsList()
    local note = self.noteBox:GetText()
    local ok, saveErr
    local wasEditing = self.editingRecord ~= nil

    if wasEditing then
        ok, saveErr = ns.CustomLocations:Update(
            self.editingRecord.id,
            self.selectedScope or self.editingRecord.scope,
            name,
            tags,
            note,
            location,
            self.editingRecord.scope
        )
    else
        ok, saveErr = ns.CustomLocations:Save(name, self.selectedScope, tags, note, location)
    end

    if ok then
        self:ClearForm()
        self:ClearEditing()
        self:GoToSavedTab()
        if wasEditing then
            WowGPS:Print(string.format(L["UPDATED_LOCATION"], name))
        else
            WowGPS:Print(string.format(L["SAVED_LOCATION"], name))
        end
    elseif saveErr then
        WowGPS:Print(string.format(L["SAVE_LOCATION_FAILED"], saveErr))
    end
end

function AddTab:PromptImport()
    ns.ImportDialog:Show()
end

function AddTab:Show()
    self.parent:Show()
    self:OnParentResize()
    self:ResetScroll()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if self.parent and self.parent:IsShown() then
                self:ResetScroll()
            end
        end)
    end
end

function AddTab:OnParentResize()
    if not self.scroll or not self.formContent then
        return
    end
    local width = math.max(self.FORM_WIDTH, (self.scroll:GetWidth() or self.FORM_WIDTH) - 4)
    self.formContent:SetWidth(width)
    self:UpdateFormHeight()
end

function AddTab:Hide()
    self.parent:Hide()
end
