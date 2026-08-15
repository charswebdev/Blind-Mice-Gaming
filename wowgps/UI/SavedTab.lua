local _, ns = ...

local SavedTab = {}
ns.SavedTab = SavedTab

SavedTab.LIST_WIDTH = 280
SavedTab.CARD_MIN_HEIGHT = 72
SavedTab.CARD_GAP = 6
SavedTab.SECTION_GAP = 10
SavedTab.ACTION_HEIGHT = 22
SavedTab.ACTION_BOTTOM_PAD = 6

function SavedTab:ExportRecord(record)
    if not record then
        return
    end

    local str = ns.CustomLocations:Export(record.id, record.scope)
    if not str then
        local addon = WowGPS or (self.mainFrame and self.mainFrame.addon)
        if addon then
            local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
            addon:Print(L["EXPORT_FAILED"])
        end
        return
    end

    ns.ExportDialog:Show(str)
end

function SavedTab:StartRoute(record)
    local addon = WowGPS or (self.mainFrame and self.mainFrame.addon)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")

    local function fail(key)
        if addon then
            addon:Print(L[key] or L["SAVED_START_FAILED"])
        end
    end

    if not record then
        fail("SAVED_START_FAILED")
        return
    end

    local dest = ns.CustomLocations:ToDestination(record)
    if not dest or not dest.mapId then
        fail("SAVED_START_BAD_COORDS")
        return
    end

    local mapId = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
    if not mapId then
        fail("SAVED_START_BAD_COORDS")
        return
    end

    if ns.SearchTab and ns.SearchTab.StartRoute then
        ns.SearchTab:StartRoute(dest)
    elseif ns.RouteTracker then
        ns.RouteTracker:Start(dest)
    else
        fail("SAVED_START_FAILED")
    end
end

function SavedTab:SetArrow(record)
    local addon = WowGPS or (self.mainFrame and self.mainFrame.addon)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")

    local function fail(key)
        if addon then
            addon:Print(L[key] or L["ARROW_SET_FAILED"])
        end
    end

    if not record then
        fail("ARROW_SET_FAILED")
        return
    end

    local dest = ns.CustomLocations:ToDestination(record)
    if not dest or not dest.mapId then
        fail("SAVED_START_BAD_COORDS")
        return
    end

    local mapId = ns.Destination:NormalizeMapCoords(dest.mapId, dest.x, dest.y)
    if not mapId then
        fail("SAVED_START_BAD_COORDS")
        return
    end

    if not ns.TomTomIntegration or not ns.TomTomIntegration.SetDestinationArrow then
        fail("ARROW_SET_FAILED")
        return
    end

    local ok = ns.TomTomIntegration:SetDestinationArrow(dest)
    if ok and addon then
        addon:Print(string.format(L["ARROW_SET"] or "|cff33CCFFWowGPS:|r Arrow set to %s.", dest.name or record.name or "destination"))
    elseif addon then
        addon:Print(L["ARROW_SET_FAILED"] or "Could not set an arrow for that destination.")
    end
end

function SavedTab:CreateCard(index)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme
    local card = CreateFrame("Frame", nil, self.listContent, "BackdropTemplate")
    card:SetSize(self.LIST_WIDTH, self.CARD_MIN_HEIGHT)
    theme:StyleCard(card)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.title:SetPoint("TOPLEFT", 10, -8)
    card.title:SetPoint("TOPRIGHT", -10, -8)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(true)
    card.title:SetNonSpaceWrap(false)

    card.zone = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.zone:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -2)
    card.zone:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
    card.zone:SetJustifyH("LEFT")
    card.zone:SetWordWrap(false)

    card.tags = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.tags:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -2)
    card.tags:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
    card.tags:SetJustifyH("LEFT")
    card.tags:SetWordWrap(true)

    card.note = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.note:SetPoint("TOPLEFT", card.tags, "BOTTOMLEFT", 0, -1)
    card.note:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
    card.note:SetJustifyH("LEFT")
    card.note:SetWordWrap(true)

    card.detail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.detail:SetPoint("TOPLEFT", card.note, "BOTTOMLEFT", 0, -1)
    card.detail:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
    card.detail:SetJustifyH("LEFT")
    card.detail:SetWordWrap(true)

    card.actionBar = CreateFrame("Frame", nil, card)
    card.actionBar:SetPoint("BOTTOMLEFT", 6, self.ACTION_BOTTOM_PAD)
    card.actionBar:SetPoint("BOTTOMRIGHT", -6, self.ACTION_BOTTOM_PAD)
    card.actionBar:SetHeight(self.ACTION_HEIGHT)

    local function makeAction(label, variant, width)
        local btn = CreateFrame("Button", nil, card.actionBar, "BackdropTemplate")
        btn:SetSize(width, self.ACTION_HEIGHT)
        btn:SetText(label)
        btn:RegisterForClicks("LeftButtonUp")
        btn:EnableMouse(true)
        btn:SetFrameLevel(card:GetFrameLevel() + 4)
        theme:StyleSmallButton(btn, variant)
        return btn
    end

    -- Left-to-right: Start - Arrow - Edit - Export - Delete
    card.start = makeAction(L["START"] or L["START_ROUTE"], "success", 44)
    card.arrow = makeAction(L["ARROW"] or "Arrow", "royal", 48)
    card.edit = makeAction(L["EDIT"], nil, 38)
    card.export = makeAction(L["EXPORT"], nil, 52)
    card.del = makeAction(L["DELETE"], "danger", 46)

    card.start:SetPoint("BOTTOMLEFT", card.actionBar, "BOTTOMLEFT", 0, 0)
    card.arrow:SetPoint("LEFT", card.start, "RIGHT", 4, 0)
    card.edit:SetPoint("LEFT", card.arrow, "RIGHT", 4, 0)
    card.export:SetPoint("LEFT", card.edit, "RIGHT", 4, 0)
    card.del:SetPoint("LEFT", card.export, "RIGHT", 4, 0)

    card.start:SetScript("OnClick", function(self)
        ns.SavedTab:StartRoute(self.record)
    end)
    card.arrow:SetScript("OnClick", function(self)
        ns.SavedTab:SetArrow(self.record)
    end)
    card.edit:SetScript("OnClick", function(self)
        ns.MainFrame:EditSavedLocation(self.record)
    end)
    card.export:SetScript("OnClick", function(self)
        ns.SavedTab:ExportRecord(self.record)
    end)
    card.del:SetScript("OnClick", function(self)
        ns.CustomLocations:Delete(self.record.id, self.record.scope)
        ns.SavedTab:RefreshList()
    end)

    card:EnableMouse(true)
    card:SetScript("OnEnter", function(self)
        local record = self.record
        if not record then
            return
        end
        local zoneLine = ns.Destination and ns.Destination:FormatZoneLine(record)
        local note = record.note
        if (not zoneLine or zoneLine == "") and (not note or note == "") then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(record.name or "?", 1, 1, 1)
        if zoneLine then
            GameTooltip:AddLine(zoneLine, 0.75, 0.78, 0.85)
        end
        if note and note ~= "" then
            GameTooltip:AddLine(note, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.listRows[index] = card
    return card
end

function SavedTab:GetOrCreateSection(index)
    local section = self.sectionRows[index]
    if section then
        return section
    end

    local theme = ns.Theme
    section = CreateFrame("Frame", nil, self.listContent)
    section:SetSize(self.LIST_WIDTH, 18)

    section.label = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.label:SetPoint("TOPLEFT", 2, -2)
    section.label:SetJustifyH("LEFT")
    theme:SetTextColor(section.label, theme.colors.sectionHeader)

    section.rule = section:CreateTexture(nil, "ARTWORK")
    section.rule:SetHeight(1)
    section.rule:SetPoint("LEFT", section.label, "RIGHT", 8, 0)
    section.rule:SetPoint("RIGHT", section, "RIGHT", -2, 0)
    section.rule:SetColorTexture(0.25, 0.25, 0.30, 0.45)

    self.sectionRows[index] = section
    return section
end

function SavedTab:MeasureCardHeight(card, record)
    local topPad = 8
    local bottomPad = 8
    local gap = 2

    card.title:SetText(record.name or "")
    local titleHeight = card.title:GetStringHeight() or 14

    local zoneLine = ns.Destination and ns.Destination:FormatZoneLine(record)
    local zoneHeight = 0
    if zoneLine then
        card.zone:SetText(zoneLine)
        zoneHeight = (card.zone:GetStringHeight() or 12) + 4
    end

    local tagText = ns.LocationTags:FormatList(ns.CustomLocations:GetTags(record))
    local tagsHeight = 0
    if tagText and tagText ~= "" then
        card.tags:SetText(tagText)
        tagsHeight = (card.tags:GetStringHeight() or 12) + gap
    end

    local note = record.note
    local noteHeight = 0
    if note and note ~= "" then
        card.note:SetText(note)
        noteHeight = (card.note:GetStringHeight() or 12) + gap
    end

    card.detail:SetText(ns.CustomLocations:FormatCoords(record))
    local detailHeight = card.detail:GetStringHeight() or 12

    local actionBlock = self.ACTION_BOTTOM_PAD + self.ACTION_HEIGHT + 4
    return math.max(
        self.CARD_MIN_HEIGHT,
        topPad + titleHeight + zoneHeight + tagsHeight + noteHeight + detailHeight + actionBlock + bottomPad
    )
end

function SavedTab:StyleCard(card, record)
    local theme = ns.Theme
    local c = theme.colors

    card.record = record
    card.title:SetText(record.name or "")
    theme:SetTextColor(card.title, c.text)

    local anchorBelow = card.title
    local anchorOffset = -2

    local zoneLine = ns.Destination and ns.Destination:FormatZoneLine(record)
    if zoneLine then
        card.zone:SetText(zoneLine)
        theme:SetTextColor(card.zone, c.textMuted)
        card.zone:ClearAllPoints()
        card.zone:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -2)
        card.zone:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
        card.zone:Show()
        anchorBelow = card.zone
        anchorOffset = -4
    else
        card.zone:SetText("")
        card.zone:Hide()
    end

    local tagText = ns.LocationTags:FormatList(ns.CustomLocations:GetTags(record))
    if tagText and tagText ~= "" then
        card.tags:SetText(tagText)
        theme:SetTextColor(card.tags, c.accent)
        card.tags:ClearAllPoints()
        card.tags:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, anchorOffset)
        card.tags:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
        card.tags:Show()
        anchorBelow = card.tags
        anchorOffset = -1
    else
        card.tags:Hide()
    end

    local note = record.note
    if note and note ~= "" then
        card.note:SetText(note)
        theme:SetTextColor(card.note, c.textMuted)
        card.note:ClearAllPoints()
        card.note:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, anchorOffset)
        card.note:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
        card.note:Show()
        anchorBelow = card.note
        anchorOffset = -1
    else
        card.note:SetText("")
        card.note:Hide()
    end

    card.detail:ClearAllPoints()
    card.detail:SetPoint("TOPLEFT", anchorBelow, "BOTTOMLEFT", 0, anchorOffset)
    card.detail:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
    card.detail:SetText(ns.CustomLocations:FormatCoords(record))
    theme:SetTextColor(card.detail, c.textMuted)

    card:SetHeight(self:MeasureCardHeight(card, record))

    card.start.record = record
    card.arrow.record = record
    card.edit.record = record
    card.export.record = record
    card.del.record = record
    self:LayoutCardActions(card)
end

function SavedTab:LayoutCardActions(card)
    local btns = { card.start, card.arrow, card.edit, card.export, card.del }
    local wants = { 44, 48, 38, 52, 46 }
    local gap = 4
    local barW = math.max(80, (card:GetWidth() or self.LIST_WIDTH) - 12)
    local total = 0
    for i = 1, #btns do
        total = total + wants[i] + (i > 1 and gap or 0)
    end
    local scale = 1
    if total > barW then
        scale = (barW - gap * (#btns - 1)) / (total - gap * (#btns - 1))
    end
    local x = 0
    for i, btn in ipairs(btns) do
        if btn then
            local w = math.max(32, math.floor(wants[i] * scale))
            btn:SetWidth(w)
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMLEFT", card.actionBar, "BOTTOMLEFT", x, 0)
            x = x + w + gap
        end
    end
end

function SavedTab:GetListWidth()
    if self.scroll then
        return math.max(200, (self.scroll:GetWidth() or self.LIST_WIDTH) - 4)
    end
    return self.LIST_WIDTH
end

function SavedTab:OnParentResize()
    if self.listContent then
        self:RefreshList()
    end
end

function SavedTab:Build(parent, mainFrame)
    self.parent = parent
    self.mainFrame = mainFrame
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme

    local headerRow = CreateFrame("Frame", nil, parent)
    headerRow:SetPoint("TOPLEFT", 12, -10)
    headerRow:SetPoint("TOPRIGHT", -12, -10)
    headerRow:SetHeight(20)

    self.header = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.header:SetPoint("LEFT", 0, 0)
    self.header:SetText(L["SAVED_HEADER"])
    theme:SetReadableFont(self.header, 14)
    theme:SetTextColor(self.header, theme.colors.text)

    self.countLabel = headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.countLabel:SetPoint("RIGHT", 0, 0)
    theme:SetTextColor(self.countLabel, theme.colors.textMuted)

    self.hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.hint:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    self.hint:SetPoint("TOPRIGHT", -12, 0)
    self.hint:SetJustifyH("LEFT")
    self.hint:SetText(L["SAVED_HINT"])
    theme:SetTextColor(self.hint, theme.colors.textMuted)

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", self.hint, "BOTTOMLEFT", -4, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    self.scroll = scroll
    self.listContent = content
    self.listRows = {}
    self.sectionRows = {}
    self.emptyState = nil

    ns.ExportDialog:Init()

    self:RefreshList()
end

function SavedTab:HideDynamicRows()
    for _, row in ipairs(self.listRows) do
        row:Hide()
    end
    for _, section in ipairs(self.sectionRows) do
        section:Hide()
    end
    if self.emptyState then
        self.emptyState:Hide()
    end
end

function SavedTab:ShowEmptyState(y)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme

    if not self.emptyState then
        local frame = CreateFrame("Frame", nil, self.listContent, "BackdropTemplate")
        frame:SetSize(self:GetListWidth(), 72)
        theme:StyleCard(frame)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.title:SetPoint("TOP", 0, -16)
        frame.title:SetText(L["SAVED_EMPTY"])

        frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        frame.hint:SetPoint("TOP", frame.title, "BOTTOM", 0, -4)
        frame.hint:SetWidth(240)
        frame.hint:SetJustifyH("CENTER")
        frame.hint:SetText(L["SAVED_EMPTY_HINT"])

        self.emptyState = frame
    end

    theme:SetTextColor(self.emptyState.title, theme.colors.textMuted)
    theme:SetTextColor(self.emptyState.hint, theme.colors.textMuted)
    self.emptyState:SetWidth(self:GetListWidth())
    self.emptyState:SetPoint("TOPLEFT", 0, y)
    self.emptyState:Show()
    return y - 72 - self.CARD_GAP
end

function SavedTab:RefreshList()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    self:HideDynamicRows()

    local totalCount = 0
    for _, scope in ipairs({ "account", "character" }) do
        totalCount = totalCount + #ns.CustomLocations:List(scope)
    end
    self.countLabel:SetText(string.format(L["SAVED_COUNT"], totalCount))

    local listWidth = self:GetListWidth()
    local y = -2
    local cardIndex = 0
    local sectionIndex = 0
    local sections = {
        { scope = "account", label = L["SAVED_SECTION_ACCOUNT"] },
        { scope = "character", label = L["SAVED_SECTION_CHARACTER"] },
    }

    for _, sectionInfo in ipairs(sections) do
        local records = ns.CustomLocations:List(sectionInfo.scope)
        if #records > 0 then
            sectionIndex = sectionIndex + 1
            local section = self:GetOrCreateSection(sectionIndex)
            section:SetWidth(listWidth)
            section.label:SetText(string.format("%s (%d)", sectionInfo.label, #records))
            section:SetPoint("TOPLEFT", 0, y)
            section:Show()
            y = y - 18 - 4

            for _, record in ipairs(records) do
                cardIndex = cardIndex + 1
                local card = self.listRows[cardIndex] or self:CreateCard(cardIndex)
                record.scope = sectionInfo.scope
                card:SetWidth(listWidth)
                self:StyleCard(card, record)
                card:SetPoint("TOPLEFT", 0, y)
                card:Show()
                y = y - card:GetHeight() - self.CARD_GAP
            end

            y = y - self.SECTION_GAP
        end
    end

    if cardIndex == 0 then
        y = self:ShowEmptyState(y)
    end

    self.listContent:SetSize(listWidth, math.max(1, -y))
end

function SavedTab:Show()
    self.parent:Show()
    self:RefreshList()
end

function SavedTab:Hide()
    self.parent:Hide()
end
