local _, GPS = ...

GPS.Add = GPS.Add or {}
local Add = GPS.Add

local TYPE_OPTIONS = {
    "Farm",
    "Quest",
    "Rare",
    "Delve entrance",
    "Labyrinth",
    "Dungeon entrance",
    "Raid entrance",
    "Scenario entrance",
    "Cave entrance",
    "Covenant Sanctum",
    "NPC",
    "Elite",
    "Hunter pet",
    "Battle Pet",
    "Transmog",
    "Toys",
    "Mount",
    "Glyphs",
    "Treasures",
    "Ritual Sites",
    "Decor",
    "Trainers",
    "Services",
    "Travel point",
    "Vendor",
    "Other",
}

function Add:FieldLabel(parent, text, anchor, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", x or 0, y or -8)
    label:SetText(text)
    GPS.Theme:SetTextColor(label, GPS.Theme.colors.textMuted)
    return label
end

function Add:EditBox(parent, anchor)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, 0)
    box:SetHeight(22)
    box:SetAutoFocus(false)
    GPS.Theme:StyleEditBox(box)
    box:SetScript("OnEscapePressed", function(edit)
        edit:ClearFocus()
    end)
    return box
end

function Add:UpdateLocationMode()
    local useCurrent = self.useCurrent == true
    if self.manualPanel then
        self.manualPanel:SetShown(not useCurrent)
    end
    if self.locationHint then
        self.locationHint:SetShown(useCurrent)
    end
    if self.locationCard then
        self.locationCard:SetHeight(useCurrent and 56 or 128)
    end
end

function Add:Build(parent)
    local theme = GPS.Theme
    local c = theme.colors

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, -10)
    header:SetText("Save location")
    theme:SetReadableFont(header, 14)
    theme:SetTextColor(header, c.text)
    self.header = header

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    hint:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Create a personal waypoint for quick routing.")
    theme:SetTextColor(hint, c.textMuted)

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 44)
    self.scroll = scroll
    local form = CreateFrame("Frame", nil, scroll)
    form:SetSize(268, 420)
    scroll:SetScrollChild(form)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(frame, delta)
        Add:CloseTypeMenu()
        local maxScroll = math.max(0, form:GetHeight() - frame:GetHeight())
        local nextScroll = math.min(maxScroll, math.max(0, frame:GetVerticalScroll() - (delta * 28)))
        frame:SetVerticalScroll(nextScroll)
    end)

    local details = form:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    details:SetPoint("TOPLEFT", 4, -4)
    details:SetText("Details")
    theme:SetTextColor(details, c.sectionHeader)

    local nameLabel = self:FieldLabel(form, "Name", details, 0, -6)
    local nameBox = self:EditBox(form, nameLabel)
    local noteLabel = self:FieldLabel(form, "Note", nameBox, 0, -8)
    local noteBox = self:EditBox(form, noteLabel)

    local locationHeader = form:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    locationHeader:SetPoint("TOPLEFT", noteBox, "BOTTOMLEFT", 0, -12)
    locationHeader:SetText("Location")
    theme:SetTextColor(locationHeader, c.sectionHeader)

    local locationCard = CreateFrame("Frame", nil, form, "BackdropTemplate")
    locationCard:SetPoint("TOPLEFT", locationHeader, "BOTTOMLEFT", 0, -6)
    locationCard:SetPoint("TOPRIGHT", form, "TOPRIGHT", -4, 0)
    locationCard:SetHeight(128)
    theme:StyleCard(locationCard)
    self.locationCard = locationCard

    local useCurrent = CreateFrame("CheckButton", nil, locationCard, "UICheckButtonTemplate")
    useCurrent:SetPoint("TOPLEFT", 8, -8)
    useCurrent.text = useCurrent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    useCurrent.text:SetPoint("LEFT", useCurrent, "RIGHT", 4, 0)
    useCurrent.text:SetText("Use my current position")
    theme:SetTextColor(useCurrent.text, c.text)
    useCurrent:SetChecked(false)
    self.useCurrent = false
    useCurrent:SetScript("OnClick", function(btn)
        local checked = btn:GetChecked()
        if issecretvalue and issecretvalue(checked) then
            Add.useCurrent = false
        else
            Add.useCurrent = checked == true or checked == 1
        end
        Add:UpdateLocationMode()
    end)
    self.useCurrentCheck = useCurrent

    local locationHint = locationCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    locationHint:SetPoint("TOPLEFT", useCurrent, "BOTTOMLEFT", 2, -4)
    locationHint:SetPoint("TOPRIGHT", -8, 0)
    locationHint:SetJustifyH("LEFT")
    locationHint:SetText("Saves where you are standing when you click Save.")
    theme:SetTextColor(locationHint, c.textMuted)
    locationHint:Hide()
    self.locationHint = locationHint

    local manual = CreateFrame("Frame", nil, locationCard)
    manual:SetPoint("TOPLEFT", useCurrent, "BOTTOMLEFT", 2, -4)
    manual:SetPoint("TOPRIGHT", locationCard, "TOPRIGHT", -8, 0)
    manual:SetHeight(92)
    self.manualPanel = manual

    local zoneLabel = manual:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    zoneLabel:SetPoint("TOPLEFT", 0, 0)
    zoneLabel:SetText("Zone")
    theme:SetTextColor(zoneLabel, c.textMuted)

    local fillBtn = CreateFrame("Button", nil, manual, "BackdropTemplate")
    fillBtn:SetSize(72, 20)
    fillBtn:SetPoint("TOP", zoneLabel, "BOTTOM", 0, -2)
    fillBtn:SetPoint("RIGHT", manual, "RIGHT", 0, 0)
    fillBtn:SetText("Auto fill")
    theme:StyleSmallButton(fillBtn)
    fillBtn:SetScript("OnClick", function()
        Add:FillFromHere()
    end)

    local zoneBox = CreateFrame("EditBox", nil, manual, "InputBoxTemplate")
    zoneBox:SetPoint("TOPLEFT", zoneLabel, "BOTTOMLEFT", 0, -2)
    zoneBox:SetPoint("RIGHT", fillBtn, "LEFT", -8, 0)
    zoneBox:SetHeight(20)
    zoneBox:SetAutoFocus(false)
    theme:StyleEditBox(zoneBox)
    zoneBox:SetScript("OnEscapePressed", function(edit)
        edit:ClearFocus()
    end)

    local mapLabel = manual:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mapLabel:SetPoint("TOPLEFT", zoneBox, "BOTTOMLEFT", 0, -8)
    mapLabel:SetText("Map ID")
    theme:SetTextColor(mapLabel, c.textMuted)
    local mapBox = CreateFrame("EditBox", nil, manual, "InputBoxTemplate")
    mapBox:SetPoint("TOPLEFT", mapLabel, "BOTTOMLEFT", 0, -2)
    mapBox:SetSize(70, 20)
    mapBox:SetAutoFocus(false)
    theme:StyleEditBox(mapBox)

    local xLabel = manual:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    xLabel:SetPoint("TOPLEFT", mapLabel, "TOPRIGHT", 16, 0)
    xLabel:SetText("X")
    theme:SetTextColor(xLabel, c.textMuted)
    local xBox = CreateFrame("EditBox", nil, manual, "InputBoxTemplate")
    xBox:SetPoint("TOPLEFT", xLabel, "BOTTOMLEFT", 0, -2)
    xBox:SetSize(70, 20)
    xBox:SetAutoFocus(false)
    theme:StyleEditBox(xBox)

    local yLabel = manual:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    yLabel:SetPoint("TOPLEFT", xLabel, "TOPRIGHT", 16, 0)
    yLabel:SetText("Y")
    theme:SetTextColor(yLabel, c.textMuted)
    local yBox = CreateFrame("EditBox", nil, manual, "InputBoxTemplate")
    yBox:SetPoint("TOPLEFT", yLabel, "BOTTOMLEFT", 0, -2)
    yBox:SetSize(70, 20)
    yBox:SetAutoFocus(false)
    theme:StyleEditBox(yBox)

    local organize = form:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    organize:SetPoint("TOPLEFT", locationCard, "BOTTOMLEFT", 0, -12)
    organize:SetText("Type & scope")
    theme:SetTextColor(organize, c.sectionHeader)

    local organizeCard = CreateFrame("Frame", nil, form, "BackdropTemplate")
    organizeCard:SetPoint("TOPLEFT", organize, "BOTTOMLEFT", 0, -6)
    organizeCard:SetPoint("TOPRIGHT", form, "TOPRIGHT", -4, 0)
    organizeCard:SetHeight(72)
    theme:StyleCard(organizeCard)

    local tagLabel = organizeCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tagLabel:SetPoint("TOPLEFT", 10, -10)
    tagLabel:SetText("Type")
    theme:SetTextColor(tagLabel, c.textMuted)

    self.selectedTags = {}
    local typeBtn = CreateFrame("Button", nil, organizeCard, "BackdropTemplate")
    typeBtn:SetHeight(22)
    typeBtn:SetPoint("LEFT", tagLabel, "RIGHT", 8, 0)
    typeBtn:SetPoint("RIGHT", organizeCard, "RIGHT", -10, 0)
    typeBtn:SetFrameLevel(organizeCard:GetFrameLevel() + 5)
    typeBtn:SetText("Select type...")
    theme:StyleSmallButton(typeBtn)
    typeBtn:SetBackdropColor(0, 0, 0, 1)
    typeBtn:SetBackdropBorderColor(0.82, 0.68, 0.22, 1)
    typeBtn._themeBaseBg = { 0, 0, 0, 1 }
    typeBtn._themeHoverBg = { 0.08, 0.08, 0.08, 1 }
    local typeText = typeBtn:GetFontString()
    if typeText then
        typeText:ClearAllPoints()
        typeText:SetPoint("LEFT", 8, 0)
        typeText:SetPoint("RIGHT", -8, 0)
        typeText:SetJustifyH("LEFT")
    end
    typeBtn:SetScript("OnClick", function()
        Add:ToggleTypeMenu()
    end)
    self.typeButton = typeBtn
    self:BuildTypeMenu()
    if parent.HookScript then
        parent:HookScript("OnHide", function()
            Add:CloseTypeMenu()
        end)
    end

    local scopeLabel = organizeCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scopeLabel:SetPoint("TOPLEFT", tagLabel, "BOTTOMLEFT", 0, -16)
    scopeLabel:SetText("Scope")
    theme:SetTextColor(scopeLabel, c.textMuted)

    self.selectedScope = "account"
    local scopeDropdown = theme:CreateDropdown(organizeCard, "WowGPSForeverScopeDropdown", 160, "Account-wide", function()
        return {
            { text = "Account-wide", value = "account", checked = Add.selectedScope == "account" },
            { text = "This character", value = "character", checked = Add.selectedScope == "character" },
        }
    end, function(item)
        Add.selectedScope = item.value
    end)
    if scopeDropdown then
        scopeDropdown:SetPoint("TOPLEFT", scopeLabel, "TOPRIGHT", -8, 4)
    end
    self.scopeDropdown = scopeDropdown

    local saveBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    saveBtn:SetSize(80, 26)
    saveBtn:SetPoint("BOTTOMLEFT", 12, 12)
    saveBtn:SetText("Save")
    theme:StyleSmallButton(saveBtn)
    saveBtn:SetScript("OnClick", function()
        Add:Save()
    end)
    self.saveBtn = saveBtn

    local cancelBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    cancelBtn:SetSize(80, 26)
    cancelBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    cancelBtn:SetText("Cancel")
    theme:StyleSmallButton(cancelBtn)
    cancelBtn:SetScript("OnClick", function()
        Add:CancelEdit()
    end)
    cancelBtn:Hide()
    self.cancelBtn = cancelBtn

    local importBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    importBtn:SetSize(80, 26)
    importBtn:SetPoint("LEFT", saveBtn, "RIGHT", 8, 0)
    importBtn:SetText("Import")
    theme:StyleSmallButton(importBtn)
    importBtn:SetScript("OnClick", function()
        if GPS.ImportDialog then
            GPS.ImportDialog:Show()
        end
    end)
    self.importBtn = importBtn

    self.nameBox = nameBox
    self.noteBox = noteBox
    self.zoneBox = zoneBox
    self.mapBox = mapBox
    self.xBox = xBox
    self.yBox = yBox
    self:UpdateLocationMode()
    self:RefreshTypeButton()
    self:RefreshEditor()
end

function Add:BuildTypeMenu()
    local theme = GPS.Theme
    local c = theme.colors
    local blocker = CreateFrame("Button", nil, UIParent)
    blocker:SetAllPoints(UIParent)
    blocker:SetFrameStrata("HIGH")
    blocker:Hide()
    blocker:SetScript("OnClick", function()
        Add:CloseTypeMenu()
    end)
    self.typeBlocker = blocker

    local rowHeight = 22
    local menuHeight = (#TYPE_OPTIONS * rowHeight) + 8
    if menuHeight > 286 then
        menuHeight = 286
    end
    local menu = CreateFrame("Frame", "WowGPSForeverTypeMenu", UIParent, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    menu:SetSize(200, menuHeight)
    theme:StyleCard(menu)
    menu:SetBackdropColor(0, 0, 0, 1)
    menu:SetBackdropBorderColor(0.82, 0.68, 0.22, 1)
    menu:Hide()
    menu:EnableMouse(true)
    self.typeMenu = menu
    self.typeRows = {}

    local scroll = CreateFrame("ScrollFrame", nil, menu)
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -16, 4)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(176, #TYPE_OPTIONS * rowHeight)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnMouseWheel", function(frame, delta)
        local maxScroll = math.max(0, content:GetHeight() - frame:GetHeight())
        local nextScroll = math.min(maxScroll, math.max(0, frame:GetVerticalScroll() - (delta * rowHeight)))
        frame:SetVerticalScroll(nextScroll)
    end)

    for i = 1, #TYPE_OPTIONS do
        local text = TYPE_OPTIONS[i]
        local row = CreateFrame("Button", nil, content)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", 0, -((i - 1) * rowHeight))
        row.check = row:CreateTexture(nil, "OVERLAY")
        row.check:SetSize(16, 16)
        row.check:SetPoint("LEFT", 2, 0)
        row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        row.check:Hide()
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", 22, 0)
        row.label:SetPoint("RIGHT", -4, 0)
        row.label:SetJustifyH("LEFT")
        row.label:SetText(text)
        theme:SetTextColor(row.label, c.text)
        row:SetScript("OnClick", function()
            if Add.selectedTags[text] then
                Add.selectedTags[text] = nil
            else
                Add.selectedTags[text] = true
            end
            Add:RefreshTypeButton()
        end)
        row:SetScript("OnMouseWheel", function(_, delta)
            local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
            local nextScroll = math.min(maxScroll, math.max(0, scroll:GetVerticalScroll() - (delta * rowHeight)))
            scroll:SetVerticalScroll(nextScroll)
        end)
        self.typeRows[i] = row
    end
end

function Add:RefreshTypeButton()
    local labels = {}
    for i = 1, #TYPE_OPTIONS do
        local text = TYPE_OPTIONS[i]
        local on = self.selectedTags and self.selectedTags[text]
        if on then
            labels[#labels + 1] = text
        end
        local row = self.typeRows and self.typeRows[i]
        if row then
            if on then
                row.check:Show()
                GPS.Theme:SetTextColor(row.label, GPS.Theme.colors.accent)
            else
                row.check:Hide()
                GPS.Theme:SetTextColor(row.label, GPS.Theme.colors.text)
            end
        end
    end
    if self.typeButton then
        if #labels == 0 then
            self.typeButton:SetText("Select type...")
        else
            self.typeButton:SetText(table.concat(labels, ", "))
        end
        local typeText = self.typeButton:GetFontString()
        if typeText then
            typeText:SetText(self.typeButton:GetText() or "")
        end
    end
end

function Add:ChosenTag()
    local labels = {}
    for i = 1, #TYPE_OPTIONS do
        local text = TYPE_OPTIONS[i]
        if self.selectedTags and self.selectedTags[text] then
            labels[#labels + 1] = text
        end
    end
    if #labels == 0 then
        return nil
    end
    return table.concat(labels, ";")
end

function Add:CloseTypeMenu()
    if self.typeMenu then
        self.typeMenu:Hide()
    end
    if self.typeBlocker then
        self.typeBlocker:Hide()
    end
end

function Add:ToggleTypeMenu()
    local menu = self.typeMenu
    local button = self.typeButton
    if not menu or not button then
        return
    end
    if menu:IsShown() then
        self:CloseTypeMenu()
        return
    end
    self:RefreshTypeButton()
    menu:ClearAllPoints()
    local left = button:GetLeft() or 0
    local bottom = button:GetBottom() or 0
    local top = button:GetTop() or bottom
    local width = button:GetWidth() or 180
    if width < 180 then
        width = 180
    end
    menu:SetWidth(width)
    local height = menu:GetHeight() or 0
    if bottom < height + 8 then
        menu:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, top)
    else
        menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    end
    menu:Show()
    if self.typeBlocker then
        self.typeBlocker:Show()
    end
end

function Add:ScopeLabel(scope)
    if scope == "character" then
        return "This character"
    end
    return "Account-wide"
end

function Add:SetScope(scope)
    self.selectedScope = scope == "character" and "character" or "account"
    if self.scopeDropdown and UIDropDownMenu_SetText then
        UIDropDownMenu_SetText(self.scopeDropdown, self:ScopeLabel(self.selectedScope))
    end
end

function Add:ApplyTags(tag)
    self.selectedTags = {}
    local text = GPS:PlainString(tag) or ""
    for part in string.gmatch(text, "[^;]+") do
        local trimmed = string.match(part, "^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            self.selectedTags[trimmed] = true
        end
    end
    self:RefreshTypeButton()
end

function Add:ButtonText(button, text)
    if not button then
        return
    end
    button:SetText(text)
    local font = button:GetFontString()
    if font then
        font:SetText(text)
    end
end

function Add:ClearForm()
    if self.nameBox then
        self.nameBox:SetText("")
    end
    if self.noteBox then
        self.noteBox:SetText("")
    end
    if self.zoneBox then
        self.zoneBox:SetText("")
    end
    if self.mapBox then
        self.mapBox:SetText("")
    end
    if self.xBox then
        self.xBox:SetText("")
    end
    if self.yBox then
        self.yBox:SetText("")
    end
    self.selectedTags = {}
    self.useCurrent = false
    if self.useCurrentCheck then
        self.useCurrentCheck:SetChecked(false)
    end
    self:UpdateLocationMode()
    self:CloseTypeMenu()
    self:RefreshTypeButton()
    if self.scroll then
        self.scroll:SetVerticalScroll(0)
    end
end

function Add:RefreshEditor()
    local editing = self.editing ~= nil
    if self.header then
        self.header:SetText(editing and "Edit location" or "Save location")
    end
    self:ButtonText(self.saveBtn, editing and "Update" or "Save")
    if self.cancelBtn then
        if editing then
            self.cancelBtn:Show()
        else
            self.cancelBtn:Hide()
        end
    end
    if self.importBtn and self.saveBtn then
        self.importBtn:ClearAllPoints()
        if editing and self.cancelBtn then
            self.importBtn:SetPoint("LEFT", self.cancelBtn, "RIGHT", 8, 0)
        else
            self.importBtn:SetPoint("LEFT", self.saveBtn, "RIGHT", 8, 0)
        end
    end
end

function Add:Load(dest)
    if not dest or not dest.id then
        return
    end
    self.editing = {
        id = dest.id,
        scope = dest.scope == "character" and "character" or "account",
    }
    if self.nameBox then
        self.nameBox:SetText(dest.name or "")
    end
    if self.noteBox then
        self.noteBox:SetText(dest.note or "")
    end
    self.useCurrent = false
    if self.useCurrentCheck then
        self.useCurrentCheck:SetChecked(false)
    end
    self:UpdateLocationMode()
    if self.zoneBox then
        self.zoneBox:SetText(dest.zone or "")
    end
    if self.mapBox then
        self.mapBox:SetText(dest.mapId and tostring(dest.mapId) or "")
    end
    if self.xBox then
        self.xBox:SetText(dest.x and string.format("%.1f", dest.x * 100) or "")
    end
    if self.yBox then
        self.yBox:SetText(dest.y and string.format("%.1f", dest.y * 100) or "")
    end
    self:SetScope(dest.scope)
    self:ApplyTags(dest.tag)
    self:CloseTypeMenu()
    self:RefreshEditor()
    if self.scroll then
        self.scroll:SetVerticalScroll(0)
    end
    if GPS.Main and GPS.Main.SelectTab then
        GPS.Main:SelectTab("add", false)
    end
end

function Add:CancelEdit()
    self.editing = nil
    self:ClearForm()
    self:SetScope("account")
    self:RefreshEditor()
    if GPS.Main and GPS.Main.SelectTab then
        GPS.Main:SelectTab("saved", false)
    end
end

function Add:BoxText(box)
    if not box then
        return ""
    end
    return GPS:PlainString(box:GetText()) or ""
end

function Add:AsFraction(text)
    local n = GPS:PlainNumber(text)
    if not n then
        n = tonumber(text)
    end
    n = GPS:PlainNumber(n)
    if not n then
        return nil
    end
    if n > 1 and n <= 100 then
        n = n / 100
    end
    if n < 0 or n > 1 then
        return nil
    end
    return n
end

function Add:FillFromHere()
    local here = GPS.Here and GPS.Here:Read()
    if not here or not here.mapId or not here.x or not here.y then
        GPS:Print("Could not read where you are standing.")
        return
    end
    self.useCurrent = false
    if self.useCurrentCheck then
        self.useCurrentCheck:SetChecked(false)
    end
    self:UpdateLocationMode()
    if self.zoneBox then
        self.zoneBox:SetText(here.zone or "")
    end
    if self.mapBox then
        self.mapBox:SetText(tostring(here.mapId))
    end
    if self.xBox then
        self.xBox:SetText(string.format("%.1f", here.x * 100))
    end
    if self.yBox then
        self.yBox:SetText(string.format("%.1f", here.y * 100))
    end
end

function Add:Save()
    local name = self:BoxText(self.nameBox)
    if name == "" then
        GPS:Print("Enter a name.")
        return
    end
    local mapId, x, y, zone
    if self.useCurrent == true then
        local here = GPS.Here and GPS.Here:Read()
        if not here or not here.mapId or not here.x or not here.y then
            GPS:Print("Could not read where you are standing.")
            return
        end
        mapId, x, y, zone = here.mapId, here.x, here.y, here.zone
    else
        mapId = GPS:PlainNumber(self:BoxText(self.mapBox))
        x = self:AsFraction(self:BoxText(self.xBox))
        y = self:AsFraction(self:BoxText(self.yBox))
        zone = self:BoxText(self.zoneBox)
        if not mapId or not x or not y then
            GPS:Print("Enter a map ID and X and Y coordinates (0-100).")
            return
        end
    end
    local payload = {
        name = name,
        note = self:BoxText(self.noteBox),
        mapId = mapId,
        x = x,
        y = y,
        zone = zone,
        tag = self:ChosenTag(),
        scope = self.selectedScope,
    }
    local wasEditing = self.editing ~= nil
    local saved, err
    if wasEditing then
        saved, err = GPS.Places:Update(self.editing.id, self.editing.scope, payload)
    else
        saved, err = GPS.Places:Add(payload)
    end
    if not saved then
        if err == "character" then
            GPS:Print("Could not save for this character.")
        elseif err == "missing" then
            GPS:Print("Could not find that saved location.")
        else
            GPS:Print("Could not save that location.")
        end
        return
    end
    self.editing = nil
    self:ClearForm()
    self:SetScope(self.selectedScope or "account")
    self:RefreshEditor()
    if wasEditing then
        GPS:Print("Updated location: " .. saved.name .. ".")
    else
        GPS:Print("Saved location: " .. saved.name .. ".")
    end
    if GPS.Saved and GPS.Saved.Refresh then
        GPS.Saved:Refresh()
    end
    if GPS.Search and GPS.Search.Refresh then
        GPS.Search:Refresh()
    end
    if GPS.Main and GPS.Main.SelectTab then
        GPS.Main:SelectTab("saved", false)
    end
end
