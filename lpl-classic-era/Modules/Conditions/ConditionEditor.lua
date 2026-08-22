local addonName, LPL = ...

LPL.ConditionEditor = {}

local SIT_COL_WIDTH = 260
local APPLY_COL_WIDTH = 300
local ROW_H = 22

local function CreateSectionLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text)
    label:SetTextColor(LPL.Theme:GetColor("textLabel"))
    return label
end

local function CreateCheckRow(parent, labelText, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width or SIT_COL_WIDTH, ROW_H)

    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetSize(20, 20)
    check:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.check = check

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    label:SetTextColor(LPL.Theme:GetColor("textBright"))
    row.label = label

    return row
end

local function CreateDivider(parent)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(0.35, 0.35, 0.40, 0.85)
    line:SetWidth(1)
    return line
end

function LPL.ConditionEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.draft = nil
    frame.checkRows = {}
    frame.linkTypeFilter = "all"
    frame.searchText = ""

    -- Header
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -12)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -12)
    header:SetHeight(36)

    local enabled = CreateFrame("CheckButton", nil, header, "UICheckButtonTemplate")
    enabled:SetSize(24, 24)
    enabled:SetPoint("LEFT", header, "LEFT", 0, 0)
    enabled:SetScript("OnClick", function(self)
        if frame.draft then
            frame.draft.enabled = self:GetChecked() and true or false
        end
    end)
    frame.enabledCheck = enabled

    local enabledLabel = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    enabledLabel:SetPoint("LEFT", enabled, "RIGHT", 2, 0)
    enabledLabel:SetText("Enabled")
    enabledLabel:SetTextColor(LPL.Theme:GetColor("textBright"))

    local nameLabel = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("LEFT", enabledLabel, "RIGHT", 16, 0)
    nameLabel:SetText("Name")
    nameLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))

    local nameBox = CreateFrame("EditBox", nil, header, "InputBoxTemplate")
    nameBox:SetAutoFocus(false)
    nameBox:SetSize(220, 24)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 8, 0)
    nameBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput and frame.draft then
            frame.draft.name = self:GetText()
        end
    end)
    frame.nameBox = nameBox

    local summary = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    summary:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    summary:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    summary:SetJustifyH("LEFT")
    summary:SetTextColor(LPL.Theme:GetColor("textMuted"))
    frame.summaryLabel = summary

    -- Body columns
    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -10)
    body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 12)

    local sitHeader = CreateSectionLabel(body, "SITUATIONS")
    sitHeader:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)

    local applyHeader = CreateSectionLabel(body, "APPLY")
    applyHeader:SetPoint("TOPLEFT", body, "TOPLEFT", SIT_COL_WIDTH + 28, 0)

    local divider = CreateDivider(body)
    divider:SetPoint("TOP", sitHeader, "BOTTOM", 0, -8)
    divider:SetPoint("BOTTOM", body, "BOTTOM", 0, 0)
    divider:SetPoint("LEFT", body, "LEFT", SIT_COL_WIDTH + 12, 0)

    local sitScroll = CreateFrame("ScrollFrame", nil, body, "UIPanelScrollFrameTemplate")
    sitScroll:SetPoint("TOPLEFT", sitHeader, "BOTTOMLEFT", 0, -8)
    sitScroll:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
    sitScroll:SetWidth(SIT_COL_WIDTH + 8)

    local sitContent = CreateFrame("Frame", nil, sitScroll)
    sitContent:SetSize(SIT_COL_WIDTH, 1)
    sitScroll:SetScrollChild(sitContent)
    frame.sitContent = sitContent

    local applyPanel = CreateFrame("Frame", nil, body)
    applyPanel:SetPoint("TOPLEFT", applyHeader, "BOTTOMLEFT", 0, -8)
    applyPanel:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -20, 0)
    frame.applyPanel = applyPanel

    -- Situations checks
    local function AddCheckGroup(defs, flagKey, y)
        for _, def in ipairs(defs) do
            local row = CreateCheckRow(sitContent, def.label)
            row:SetPoint("TOPLEFT", sitContent, "TOPLEFT", 0, -y)
            row.key = def.key
            row.flagKey = flagKey
            row.check:SetScript("OnClick", function(self)
                if not frame.draft or not frame.draft.situations then
                    return
                end
                frame.draft.situations[flagKey] = frame.draft.situations[flagKey] or {}
                frame.draft.situations[flagKey][def.key] = self:GetChecked() and true or false
                frame:RefreshSummary()
            end)
            frame.checkRows[#frame.checkRows + 1] = row
            y = y + 24
        end
        return y
    end

    local y = 0
    local locLabel = CreateSectionLabel(sitContent, "Location")
    locLabel:SetPoint("TOPLEFT", sitContent, "TOPLEFT", 0, -y)
    y = y + 18
    y = AddCheckGroup(LPL.ConditionDefs.LOCATIONS, "locations", y) + 6

    local diffLabel = CreateSectionLabel(sitContent, "Difficulties (empty = all)")
    diffLabel:SetPoint("TOPLEFT", sitContent, "TOPLEFT", 0, -y)
    y = y + 18
    frame.difficultyRows = {}
    local seenDiff = {}
    for _, group in pairs(LPL.ConditionDefs.DIFFICULTIES) do
        for _, def in ipairs(group) do
            if def.id ~= 0 and not seenDiff[def.id] then
                seenDiff[def.id] = true
                local row = CreateCheckRow(sitContent, def.label)
                row:SetPoint("TOPLEFT", sitContent, "TOPLEFT", 0, -y)
                row.difficultyID = def.id
                row.check:SetScript("OnClick", function()
                    if not frame.draft or not frame.draft.situations then
                        return
                    end
                    local set = {}
                    for _, r in ipairs(frame.difficultyRows) do
                        if r.check:GetChecked() then
                            set[#set + 1] = r.difficultyID
                        end
                    end
                    frame.draft.situations.difficultyIDs = LPL.ConditionDefs:NormalizeDifficultyIDs(set)
                    frame:RefreshSummary()
                end)
                frame.difficultyRows[#frame.difficultyRows + 1] = row
                y = y + 24
            end
        end
    end
    y = y + 6

    local moveLabel = CreateSectionLabel(sitContent, "Movement")
    moveLabel:SetPoint("TOPLEFT", sitContent, "TOPLEFT", 0, -y)
    y = y + 18
    y = AddCheckGroup(LPL.ConditionDefs.MOVEMENT, "movement", y) + 6

    local weatherLabel = CreateSectionLabel(sitContent, "Weather")
    weatherLabel:SetPoint("TOPLEFT", sitContent, "TOPLEFT", 0, -y)
    y = y + 18
    y = AddCheckGroup(LPL.ConditionDefs.WEATHER, "weather", y) + 6

    local timeLabel = CreateSectionLabel(sitContent, "Time of day")
    timeLabel:SetPoint("TOPLEFT", sitContent, "TOPLEFT", 0, -y)
    y = y + 18
    y = AddCheckGroup(LPL.ConditionDefs.TIME_OF_DAY, "timeOfDay", y) + 6

    local formLabel = CreateSectionLabel(sitContent, "Racial form")
    formLabel:SetPoint("TOPLEFT", sitContent, "TOPLEFT", 0, -y)
    y = y + 18
    y = AddCheckGroup(LPL.ConditionDefs.RACIAL_FORMS, "racialForms", y)
    sitContent:SetHeight(math.max(y + 8, 200))
    frame.sitHeight = y + 8

    -- Apply: type dropdown + search + available + linked
    local typeDrop = LPL:CreateDropdown(nil, applyPanel, 180)
    typeDrop:SetPoint("TOPLEFT", applyPanel, "TOPLEFT", 0, 0)
    typeDrop:SetLabel("Type")
    frame.typeDrop = typeDrop

    local searchLabel = applyPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("TOPLEFT", typeDrop, "TOPRIGHT", 12, 0)
    searchLabel:SetText("Search")
    searchLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))

    local searchBox = CreateFrame("EditBox", nil, applyPanel, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetSize(140, 24)
    searchBox:SetPoint("TOPLEFT", searchLabel, "BOTTOMLEFT", 0, -4)
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            frame.searchText = string.lower(self:GetText() or "")
            frame:RebuildAvailableRows()
        end
    end)
    frame.searchBox = searchBox

    local availableLabel = CreateSectionLabel(applyPanel, "Available")
    availableLabel:SetPoint("TOPLEFT", typeDrop, "BOTTOMLEFT", 0, -10)

    local availScroll = CreateFrame("ScrollFrame", nil, applyPanel, "UIPanelScrollFrameTemplate")
    availScroll:SetPoint("TOPLEFT", availableLabel, "BOTTOMLEFT", 0, -6)
    availScroll:SetPoint("RIGHT", applyPanel, "RIGHT", -20, 0)
    availScroll:SetHeight(180)

    local availContent = CreateFrame("Frame", nil, availScroll)
    availContent:SetSize(APPLY_COL_WIDTH, 1)
    availScroll:SetScrollChild(availContent)
    frame.availContent = availContent
    frame.availRows = {}

    local linkedLabel = CreateSectionLabel(applyPanel, "Linked")
    linkedLabel:SetPoint("TOPLEFT", availScroll, "BOTTOMLEFT", 0, -12)
    frame.linkedLabel = linkedLabel

    local linkedHost = CreateFrame("Frame", nil, applyPanel)
    linkedHost:SetPoint("TOPLEFT", linkedLabel, "BOTTOMLEFT", 0, -6)
    linkedHost:SetPoint("BOTTOMRIGHT", applyPanel, "BOTTOMRIGHT", -4, 0)
    frame.linkedHost = linkedHost
    frame.linkedRows = {}

    local typeItems = {}
    for _, def in ipairs(LPL.ConditionDefs.LINK_TYPES) do
        typeItems[#typeItems + 1] = { id = def.key, name = def.label }
    end
    typeDrop:SetItems(typeItems, "all", function(id)
        frame.linkTypeFilter = id or "all"
        frame:RebuildAvailableRows()
    end)

    function frame:EnsureLinks()
        if not self.draft then
            return {}
        end
        self.draft.links = LPL.ConditionStore:NormalizeLinks(self.draft.links, self.draft.loadoutIDs)
        self.draft.loadoutIDs = LPL.ConditionStore:LoadoutIDsFromLinks(self.draft.links)
        return self.draft.links
    end

    function frame:IsLinked(linkType, id)
        local key = LPL.ConditionStore:LinkKey(linkType, id)
        for _, link in ipairs(self:EnsureLinks()) do
            if LPL.ConditionStore:LinkKey(link.type, link.id) == key then
                return true
            end
        end
        return false
    end

    function frame:SetLinked(linkType, id, linked)
        local links = self:EnsureLinks()
        local key = LPL.ConditionStore:LinkKey(linkType, id)
        local nextLinks = {}
        for _, link in ipairs(links) do
            if LPL.ConditionStore:LinkKey(link.type, link.id) ~= key then
                nextLinks[#nextLinks + 1] = link
            end
        end
        if linked then
            nextLinks[#nextLinks + 1] = { type = linkType, id = tostring(id) }
        end
        self.draft.links = nextLinks
        self.draft.loadoutIDs = LPL.ConditionStore:LoadoutIDsFromLinks(nextLinks)
        self:RebuildAvailableRows()
        self:RebuildLinkedRows()
        self:RefreshSummary()
    end

    function frame:RefreshSummary()
        if not self.draft then
            self.summaryLabel:SetText("")
            return
        end
        self.summaryLabel:SetText(LPL.ConditionStore:GetSummaryLine(self.draft))
    end

    function frame:RebuildAvailableRows()
        for _, row in ipairs(self.availRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(self.availRows)

        local items = LPL.ConditionStore:ListAvailableLinks(self.linkTypeFilter or "all")
        local search = self.searchText or ""
        local yOff = 0
        for _, item in ipairs(items) do
            if search == "" or string.find(string.lower(item.name), search, 1, true) then
                local row = CreateFrame("Frame", nil, self.availContent)
                row:SetSize(APPLY_COL_WIDTH, 28)
                row:SetPoint("TOPLEFT", self.availContent, "TOPLEFT", 0, -yOff)

                local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
                check:SetSize(20, 20)
                check:SetPoint("LEFT", row, "LEFT", 0, 0)
                check:SetChecked(self:IsLinked(item.type, item.id))
                check:SetScript("OnClick", function(btn)
                    self:SetLinked(item.type, item.id, btn:GetChecked())
                end)

                local badge = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                badge:SetPoint("LEFT", check, "RIGHT", 4, 0)
                badge:SetText(item.badge or "")
                badge:SetTextColor(LPL.Theme:GetColor("textLabel"))
                badge:SetWidth(54)
                badge:SetJustifyH("LEFT")

                local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                name:SetPoint("LEFT", badge, "RIGHT", 4, 4)
                name:SetPoint("RIGHT", row, "RIGHT", 0, 4)
                name:SetJustifyH("LEFT")
                name:SetText(item.name)
                name:SetTextColor(LPL.Theme:GetColor("textBright"))

                if item.subtitle and item.subtitle ~= "" then
                    local sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
                    sub:SetPoint("RIGHT", row, "RIGHT", 0, 0)
                    sub:SetJustifyH("LEFT")
                    sub:SetText(item.subtitle)
                    sub:SetTextColor(LPL.Theme:GetColor("textMuted"))
                end

                self.availRows[#self.availRows + 1] = row
                yOff = yOff + 30
            end
        end

        if yOff == 0 then
            local empty = self.availContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            empty:SetPoint("TOPLEFT", self.availContent, "TOPLEFT", 4, -4)
            empty:SetText("Nothing available for this filter.")
            -- keep a dummy row so we can wipe later
            local holder = CreateFrame("Frame", nil, self.availContent)
            holder:Hide()
            holder.text = empty
            self.availRows[#self.availRows + 1] = holder
            yOff = 24
        end

        self.availContent:SetHeight(math.max(yOff, 40))
    end

    function frame:RebuildLinkedRows()
        for _, row in ipairs(self.linkedRows) do
            row:Hide()
            row:SetParent(nil)
        end
        wipe(self.linkedRows)

        local links = self:EnsureLinks()
        self.linkedLabel:SetText(string.format("Linked (%d)", #links))

        local yOff = 0
        for _, link in ipairs(links) do
            local row = CreateFrame("Frame", nil, self.linkedHost)
            row:SetSize(APPLY_COL_WIDTH, 24)
            row:SetPoint("TOPLEFT", self.linkedHost, "TOPLEFT", 0, -yOff)

            local badge = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            badge:SetPoint("LEFT", row, "LEFT", 0, 0)
            badge:SetWidth(54)
            badge:SetJustifyH("LEFT")
            badge:SetText(LPL.ConditionDefs:GetLinkBadge(link.type))
            badge:SetTextColor(LPL.Theme:GetColor("textLabel"))

            local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            name:SetPoint("LEFT", badge, "RIGHT", 4, 0)
            name:SetPoint("RIGHT", row, "RIGHT", -28, 0)
            name:SetJustifyH("LEFT")
            name:SetText(LPL.ConditionStore:GetLinkDisplayName(link))
            name:SetTextColor(LPL.Theme:GetColor("textBright"))

            local remove = CreateFrame("Button", nil, row, "UIPanelCloseButton")
            remove:SetSize(22, 22)
            remove:SetPoint("RIGHT", row, "RIGHT", 2, 0)
            remove:SetScript("OnClick", function()
                self:SetLinked(link.type, link.id, false)
            end)

            self.linkedRows[#self.linkedRows + 1] = row
            yOff = yOff + 24
        end

        if #links == 0 then
            local empty = self.linkedHost:CreateFontString(nil, "OVERLAY", "GameFontDisable")
            empty:SetPoint("TOPLEFT", self.linkedHost, "TOPLEFT", 0, 0)
            empty:SetText("Select items above to link them.")
            local holder = CreateFrame("Frame", nil, self.linkedHost)
            holder:Hide()
            holder.text = empty
            self.linkedRows[#self.linkedRows + 1] = holder
        end
    end

    function frame:Refresh()
        if not self.draft then
            return
        end
        self.draft.situations = LPL.ConditionStore:NormalizeSituations(self.draft.situations)
        self:EnsureLinks()
        self.enabledCheck:SetChecked(self.draft.enabled ~= false)
        self.nameBox:SetText(self.draft.name or "")

        for _, row in ipairs(self.checkRows) do
            local flags = self.draft.situations[row.flagKey]
            row.check:SetChecked(flags and flags[row.key] == true)
        end

        local diffSet = LPL.ConditionDefs:DifficultySetFromList(self.draft.situations.difficultyIDs)
        for _, row in ipairs(self.difficultyRows) do
            row.check:SetChecked(diffSet[row.difficultyID] == true)
        end

        self.typeDrop.selectedID = self.linkTypeFilter or "all"
        self.typeDrop:Refresh()
        self:RebuildAvailableRows()
        self:RebuildLinkedRows()
        self:RefreshSummary()
    end

    function frame:SetDraft(draft)
        self.draft = draft
        self:Refresh()
    end

    function frame:GetDraft()
        if self.draft then
            self.draft.name = self.nameBox:GetText()
            self:EnsureLinks()
        end
        return self.draft
    end

    function frame:GetName()
        return self.nameBox:GetText()
    end

    return frame
end

function LPL.ConditionEditor:Destroy(editor)
    if not editor then
        return
    end
    editor:Hide()
    editor:SetParent(nil)
end
