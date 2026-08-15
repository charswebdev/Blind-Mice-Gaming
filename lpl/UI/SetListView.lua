local addonName, LPL = ...

LPL.SetListView = {}

local ROW_HEIGHT = 44
local CLASS_HEADER_HEIGHT = 28
local SPEC_HEADER_HEIGHT = 24
local HERO_HEADER_HEIGHT = 22
local ROW_GAP = 2
local CHROME_GAP = 8
local META_WIDTH = 148
local META_RIGHT_PAD = 10

local function FormatDateOnly(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 or not date then
        return "—"
    end
    return (date("%b %d, %Y", timestamp):gsub("^0", ""))
end

local function FormatDateTime(timestamp)
    timestamp = tonumber(timestamp)
    if not timestamp or timestamp <= 0 or not date then
        return "—"
    end
    return (date("%b %d, %Y %I:%M %p", timestamp):gsub(" 0", " "):gsub("^0", ""))
end

local function FormatListMetaText(item)
    if type(item) ~= "table" then
        return "Created  —", "Modified —"
    end
    return "Created  " .. FormatDateOnly(item.createdAt),
        "Modified " .. FormatDateTime(item.updatedAt or item.createdAt)
end

function LPL.SetListView:Create(parent, config)
    config = config or {}
    local bottomInset = config.bottomInset or 0
    local groupBySpec = config.groupBySpec ~= false
    local groupByHero = config.groupByHero ~= false

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -8)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, bottomInset)

    local header = LPL:CreateLabel(frame, "header")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    header:SetText(config.title or "Saved Sets")

    local hint = LPL:CreateLabel(frame, "small")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    hint:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    hint:SetText(config.hint or "Click headers to expand · Click to select · Double-click to edit.")

    local chrome = LPL.ListChrome:Create(frame, {
        listKey = config.listKey or "default",
        supportedFilters = config.supportedFilters or CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS),
    })
    chrome:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -CHROME_GAP)
    chrome:SetPoint("TOPRIGHT", hint, "BOTTOMRIGHT", 4, -CHROME_GAP)
    chrome:SetHeight(LPL.ListChrome.HEIGHT)

    local emptyFilterLabel = LPL:CreateLabel(frame, "body")
    emptyFilterLabel:SetPoint("TOP", chrome, "BOTTOM", 0, -24)
    emptyFilterLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    emptyFilterLabel:SetText(config.emptyFilterText or "No sets match your search or filters.")
    emptyFilterLabel:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", chrome, "BOTTOMLEFT", 0, -CHROME_GAP)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 4)
    scroll:EnableMouse(true)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(1, 1)
    scrollChild:EnableMouse(true)
    scroll:SetScrollChild(scrollChild)

    local emptyNewButton = LPL:CreateGlowButton(nil, frame)
    emptyNewButton:SetSize(config.emptyButtonWidth or 160, 36)
    emptyNewButton:SetPoint("CENTER", frame, "CENTER", 0, 0)
    emptyNewButton:SetText(config.emptyButtonLabel or "New")
    emptyNewButton:Hide()
    emptyNewButton:SetScript("OnClick", function()
        if frame.onNew then
            frame.onNew()
        end
    end)

    frame.config = config
    frame.groupBySpec = groupBySpec
    frame.groupByHero = groupByHero
    frame.scroll = scroll
    frame.scrollChild = scrollChild
    frame.header = header
    frame.hint = hint
    frame.chrome = chrome
    frame.emptyFilterLabel = emptyFilterLabel
    frame.emptyNewButton = emptyNewButton
    frame.rows = {}
    frame.selectedID = nil
    frame.selectedIDs = {}
    frame.multiSelect = config.multiSelect == true
    frame.onSelect = nil
    frame.onActivate = nil
    frame.onNew = nil
    frame.collapsedStorage = nil

    chrome:SetOnChanged(function()
        frame:Refresh()
    end)

    function frame:SetOnSelect(callback)
        self.onSelect = callback
    end

    function frame:SetOnActivate(callback)
        self.onActivate = callback
    end

    function frame:SetOnNew(callback)
        self.onNew = callback
    end

    function frame:IsIDSelected(itemID)
        if itemID == nil then
            return false
        end
        local key = tostring(itemID)
        if self.multiSelect then
            return self.selectedIDs[key] == true
        end
        return self.selectedID == itemID or tostring(self.selectedID or "") == key
    end

    function frame:GetSelectedIDs()
        local list = {}
        if self.multiSelect then
            for id in pairs(self.selectedIDs) do
                list[#list + 1] = id
            end
            table.sort(list)
            return list
        end
        if self.selectedID then
            list[1] = self.selectedID
        end
        return list
    end

    function frame:CountSelected()
        if self.multiSelect then
            local count = 0
            for _ in pairs(self.selectedIDs) do
                count = count + 1
            end
            return count
        end
        return self.selectedID and 1 or 0
    end

    function frame:SetSelectedIDs(idMap)
        wipe(self.selectedIDs)
        self.selectedID = nil
        if type(idMap) == "table" then
            for id, selected in pairs(idMap) do
                if selected and id ~= nil then
                    local key = tostring(id)
                    self.selectedIDs[key] = true
                    if not self.selectedID then
                        self.selectedID = key
                    end
                end
            end
        end
        self:Refresh()
    end

    function frame:SetSelectedID(itemID)
        if self.multiSelect then
            wipe(self.selectedIDs)
            if itemID then
                local key = tostring(itemID)
                self.selectedIDs[key] = true
                self.selectedID = key
            else
                self.selectedID = nil
            end
        else
            self.selectedID = itemID
        end
        if itemID and LPL.ListGrouping then
            local items = config.getItems and config.getItems() or {}
            LPL.ListGrouping:EnsureExpandedForItem(self.collapsedStorage, config.listKey, itemID, {
                items = items,
                getID = config.getID,
                getClassKey = config.getClassKey,
                getSpecKey = config.getSpecKey,
                getHeroKey = config.getHeroKey,
            })
        end
        self:Refresh()
    end

    function frame:GetVisibleItems()
        local items = config.getItems and config.getItems() or {}
        return LPL.ListFiltering:Process(items, {
            query = chrome:GetQuery(),
            filters = chrome:GetFilters(),
            getName = config.getName,
            getFilters = config.getFilters,
            isActive = config.isActive,
            getClassKey = config.getClassKey,
        })
    end

    function frame:GetEntryHeight(entry)
        if entry.type == "class" then
            return CLASS_HEADER_HEIGHT
        end
        if entry.type == "spec" or entry.type == "hero" then
            return entry.type == "hero" and HERO_HEADER_HEIGHT or SPEC_HEADER_HEIGHT
        end
        return ROW_HEIGHT
    end

    function frame:ToggleHeader(entry)
        if not entry or not entry.key or not LPL.ListGrouping then
            return
        end
        local storage = LPL.ListGrouping:GetCollapsedStorage(config.listKey)
        self.collapsedStorage = storage
        local playerClassID = LPL.Character and LPL.Character:GetClassID()
        local playerSpecID = LPL.Character and LPL.Character:GetSpecID()
        local defaultCollapsed
        if entry.type == "class" then
            defaultCollapsed = LPL.ListGrouping:DefaultClassCollapsed(entry.classID, playerClassID)
        elseif entry.type == "hero" then
            defaultCollapsed = LPL.ListGrouping:DefaultHeroCollapsed(
                entry.classID, entry.specID, entry.subTreeID, playerClassID, playerSpecID
            )
        else
            defaultCollapsed = LPL.ListGrouping:DefaultSpecCollapsed(entry.classID, entry.specID, playerClassID, playerSpecID)
        end
        LPL.ListGrouping:ToggleCollapsed(storage, entry.key, defaultCollapsed)
        self:Refresh()
    end

    function frame:Refresh()
        local items = self:GetVisibleItems()
        local child = self.scrollChild
        local width = self.scroll:GetWidth()
        if width < 1 then
            width = 400
        end
        child:SetWidth(width)

        for _, row in ipairs(self.rows) do
            row:Hide()
        end

        local hasSourceItems = config.getItems and #(config.getItems() or {}) > 0
        if not hasSourceItems then
            self.header:Hide()
            self.hint:Hide()
            self.chrome:Hide()
            self.scroll:Hide()
            self.emptyNewButton:Show()
            child:SetHeight(1)
            return
        end

        self.header:Show()
        self.hint:Show()
        self.chrome:Show()
        self.emptyNewButton:Hide()
        self.emptyFilterLabel:Hide()

        if #items == 0 then
            self.scroll:Hide()
            self.emptyFilterLabel:Show()
            child:SetHeight(1)
            return
        end

        self.emptyFilterLabel:Hide()
        self.scroll:Show()

        local entries, storage = LPL.ListGrouping:BuildDisplayList(items, {
            listKey = config.listKey,
            getName = config.getName,
            getClassKey = config.getClassKey,
            getSpecKey = config.getSpecKey,
            getHeroKey = config.getHeroKey,
            isActive = config.isActive,
            groupBySpec = self.groupBySpec,
            groupByHero = self.groupByHero,
        })
        self.collapsedStorage = storage

        local y = 0
        for index, entry in ipairs(entries) do
            local row = self.rows[index]
            if not row then
                row = self:CreateRow(child)
                self.rows[index] = row
            end

            row:SetWidth(width)
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            row:Show()

            if entry.type == "item" then
                row:SetItem(entry.item, entry.depth or 0)
                local itemID = config.getID and config.getID(entry.item)
                row:SetSelected(self:IsIDSelected(itemID and tostring(itemID) or itemID))
            else
                row:SetHeader(entry)
            end

            y = y + self:GetEntryHeight(entry) + ROW_GAP
        end

        child:SetHeight(math.max(1, y))
    end

    function frame:CreateRow(parent)
        local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetHeight(ROW_HEIGHT)
        row:EnableMouse(true)
        row:RegisterForClicks("LeftButtonUp")
        LPL.Theme:ApplyListRowBackdrop(row, false, false, false)

        local expandIcon = row:CreateTexture(nil, "ARTWORK")
        expandIcon:SetSize(12, 12)
        expandIcon:SetPoint("LEFT", row, "LEFT", 6, 0)
        expandIcon:Hide()

        local activeBadge = row:CreateTexture(nil, "OVERLAY")
        activeBadge:SetSize(8, 8)
        activeBadge:SetPoint("LEFT", row, "LEFT", 4, 0)
        activeBadge:SetColorTexture(LPL.Theme:GetColor("greenGlow"))
        activeBadge:Hide()

        local title = LPL:CreateLabel(row, "bold")
        title:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -6)
        title:SetPoint("RIGHT", row, "RIGHT", -(META_WIDTH + META_RIGHT_PAD), 0)
        title:SetJustifyH("LEFT")

        local subtitle = LPL:CreateLabel(row, "small")
        subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
        subtitle:SetPoint("RIGHT", row, "RIGHT", -(META_WIDTH + META_RIGHT_PAD), 0)
        subtitle:SetJustifyH("LEFT")

        local createdLabel = LPL:CreateLabel(row, "small")
        createdLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", -META_RIGHT_PAD, -6)
        createdLabel:SetWidth(META_WIDTH)
        createdLabel:SetJustifyH("RIGHT")
        createdLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
        createdLabel:Hide()

        local modifiedLabel = LPL:CreateLabel(row, "small")
        modifiedLabel:SetPoint("TOPRIGHT", createdLabel, "BOTTOMRIGHT", 0, -2)
        modifiedLabel:SetWidth(META_WIDTH)
        modifiedLabel:SetJustifyH("RIGHT")
        modifiedLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
        modifiedLabel:Hide()

        row.expandIcon = expandIcon
        row.activeBadge = activeBadge
        row.title = title
        row.subtitle = subtitle
        row.createdLabel = createdLabel
        row.modifiedLabel = modifiedLabel
        row.itemID = nil
        row.isActive = false
        row.rowKind = "item"
        row.headerEntry = nil

        row:SetScript("OnEnter", function(self)
            if self.rowKind == "header" then
                LPL.Theme:ApplyListHeaderBackdrop(self)
            elseif not self.isSelected then
                LPL.Theme:ApplyListRowBackdrop(self, false, true, self.isActive)
            end
        end)
        row:SetScript("OnLeave", function(self)
            if self.rowKind == "header" then
                LPL.Theme:ApplyListHeaderBackdrop(self)
            elseif not self.isSelected then
                LPL.Theme:ApplyListRowBackdrop(self, false, false, self.isActive)
            end
        end)
        row:SetScript("OnClick", function(self, button)
            if self.rowKind == "header" and self.headerEntry then
                frame:ToggleHeader(self.headerEntry)
                return
            end
            if not self.itemID then
                return
            end
            if frame.onSelect then
                frame.onSelect(self.itemID)
            end
        end)
        row:SetScript("OnDoubleClick", function(self)
            if self.rowKind ~= "item" or not self.itemID or not frame.onActivate then
                return
            end
            frame.onActivate(self.itemID)
        end)

        function row:SetExpandIcon(collapsed)
            if expandIcon.SetAtlas then
                expandIcon:SetAtlas(collapsed and "plus" or "minus")
                return
            end
            expandIcon:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        end

        function row:SetHeader(entry)
            self.rowKind = "header"
            self.headerEntry = entry
            self.headerKey = entry.key
            self.itemID = nil
            self.isActive = false
            self.isSelected = false

            local depth = entry.depth or 0
            local indent = 8 + depth * 14
            local height = CLASS_HEADER_HEIGHT
            if entry.type == "spec" then
                height = SPEC_HEADER_HEIGHT
            elseif entry.type == "hero" then
                height = HERO_HEADER_HEIGHT
            end

            self:SetHeight(height)
            self:EnableMouse(true)
            self:RegisterForClicks("LeftButtonUp")
            self.expandIcon:Show()
            self.expandIcon:ClearAllPoints()
            self.expandIcon:SetPoint("LEFT", self, "LEFT", indent, 0)
            self:SetExpandIcon(entry.collapsed)

            self.activeBadge:Hide()
            self.title:ClearAllPoints()
            self.title:SetPoint("LEFT", self.expandIcon, "RIGHT", 4, 0)
            self.title:SetPoint("RIGHT", self, "RIGHT", -8, 0)
            self.title:SetJustifyH("LEFT")
            self.createdLabel:Hide()
            self.modifiedLabel:Hide()

            if entry.type == "class" and entry.classID and LPL.ListGrouping then
                self.title:SetText(LPL.ListGrouping:WrapClassText(entry.classID, entry.label or "Other"))
            elseif entry.type == "spec" and entry.useClassColor then
                self.title:SetText(entry.label or "")
            elseif entry.type == "hero" then
                self.title:SetText(entry.label or "")
                self.title:SetTextColor(LPL.Theme:GetColor("textSecondary"))
            elseif entry.type == "class" then
                self.title:SetText(entry.label or "Other")
                self.title:SetTextColor(LPL.Theme:GetColor("textSecondary"))
            else
                self.title:SetText(entry.label or "")
                self.title:SetTextColor(LPL.Theme:GetColor("textSecondary"))
            end

            if entry.type == "class" and entry.classID then
                self.title:SetFontObject(LPL.Theme.fonts.bodyBold)
            else
                self.title:SetFontObject(LPL.Theme.fonts.small)
            end

            self.subtitle:SetText("")
            self.subtitle:Hide()
            LPL.Theme:ApplyListHeaderBackdrop(self)
        end

        function row:SetItem(item, depth)
            self.rowKind = "item"
            self.headerEntry = nil
            self.headerKey = nil
            LPL.Theme:ClearListHeaderBackdrop(self)
            self:SetHeight(ROW_HEIGHT)

            depth = depth or 0
            local indent = 16 + depth * 14

            self.expandIcon:Hide()
            self.title:ClearAllPoints()
            self.title:SetPoint("TOPLEFT", self, "TOPLEFT", indent, -6)
            self.title:SetPoint("RIGHT", self, "RIGHT", -(META_WIDTH + META_RIGHT_PAD), 0)
            self.title:SetJustifyH("LEFT")
            self.title:SetFontObject(LPL.Theme.fonts.bodyBold)
            self.title:SetTextColor(LPL.Theme:GetColor("textBright"))

            self.subtitle:Show()
            self.subtitle:ClearAllPoints()
            self.subtitle:SetPoint("TOPLEFT", self.title, "BOTTOMLEFT", 0, -2)
            self.subtitle:SetPoint("RIGHT", self, "RIGHT", -(META_WIDTH + META_RIGHT_PAD), 0)

            self.itemID = config.getID and config.getID(item)
            local active = false
            if config.isActive then
                local ok, result = pcall(config.isActive, item)
                active = ok and result == true
            end
            self.isActive = active
            self.title:SetText((config.getName and config.getName(item)) or item.name or "Unnamed")
            self.subtitle:SetText(config.getSubtitle and config.getSubtitle(item) or "")
            if config.getSubtitleColor then
                self.subtitle:SetTextColor(config.getSubtitleColor(item))
            else
                self.subtitle:SetTextColor(LPL.Theme:GetColor("textSecondary"))
            end

            local createdText, modifiedText
            if config.getMetaText then
                createdText, modifiedText = config.getMetaText(item)
            end
            if not createdText or not modifiedText then
                createdText, modifiedText = FormatListMetaText(item)
            end
            self.createdLabel:SetText(createdText or "")
            self.modifiedLabel:SetText(modifiedText or "")
            self.createdLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
            self.modifiedLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
            self.createdLabel:Show()
            self.modifiedLabel:Show()

            self.activeBadge:ClearAllPoints()
            self.activeBadge:SetPoint("LEFT", self, "LEFT", math.max(4, indent - 12), 0)
            self.activeBadge:SetShown(self.isActive)
            if self.isActive and not self.isSelected then
                LPL.Theme:ApplyListRowBackdrop(self, false, false, true)
            end
        end

        function row:SetSelected(selected)
            self.isSelected = selected
            if self.rowKind ~= "item" then
                return
            end
            LPL.Theme:ApplyListRowBackdrop(self, selected, false, self.isActive)
        end

        return row
    end

    frame:SetScript("OnShow", function()
        C_Timer.After(0, function()
            if frame:IsShown() then
                frame:Refresh()
            end
        end)
    end)

    frame:HookScript("OnSizeChanged", function()
        frame:Refresh()
    end)

    return frame
end
