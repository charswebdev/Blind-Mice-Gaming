local _, BMGAM = ...

BMGAM.Collections = BMGAM.Collections or {}
local Collections = BMGAM.Collections
local Theme = BMGAM.Theme

local HEADER = 26
local ROW = 22
local NOTE = 18

local TYPES = {
    { id = "mount", title = "Mounts" },
    { id = "manuscript", title = "Manuscripts" },
    { id = "pet", title = "Pets" },
    { id = "transmog", title = "Transmog" },
    { id = "set", title = "Transmog Sets" },
    { id = "toy", title = "Toys" },
    { id = "decor", title = "Decor" },
}

local function QualityColor(quality)
    local ok, color = pcall(Theme.QualityColor, quality or 1)
    if ok and type(color) == "table" and type(color[1]) == "number" then
        return color
    end
    return Theme.WHITE
end

local function ShowCollectionTip(owner)
    if not GameTooltip or not owner then
        return
    end
    local placed = pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_CURSOR_RIGHT", 16, 0)
    if not placed then
        pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_CURSOR")
    end
    local shown = false
    if type(owner.itemID) == "number" then
        if GameTooltip.SetItemByID then
            shown = pcall(GameTooltip.SetItemByID, GameTooltip, owner.itemID)
        end
        if not shown then
            shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. owner.itemID)
        end
    elseif type(owner.spellID) == "number" and GameTooltip.SetSpellByID then
        shown = pcall(GameTooltip.SetSpellByID, GameTooltip, owner.spellID)
    end
    if not shown then
        GameTooltip:ClearLines()
        local title = owner.itemName or ""
        GameTooltip:SetText(title, Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, GameTooltip)
    end
    pcall(GameTooltip.Show, GameTooltip)
end

local function Query(text)
    if not text or text == "" then
        return ""
    end
    return string.lower(text)
end

local function Hit(query, text)
    if query == "" then
        return true
    end
    if not text or text == "" then
        return false
    end
    return string.find(string.lower(text), query, 1, true) ~= nil
end

function Collections.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { header = {}, item = {}, obtain = {}, note = {} }
    frame.used = { header = 0, item = 0, obtain = 0, note = 0 }
    frame.offset = 0
    frame.layout = {}
    frame.searching = false

    local bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", -2, -4)
    bar:SetPoint("BOTTOMRIGHT", -2, 4)
    bar:SetFrameLevel(40)
    bar:EnableMouse(true)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.16, 0.13, 0.08, 0.95)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.95)
    thumb:SetSize(12, 36)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    frame.bar = bar

    local function Wheel(self, delta)
        local page = self.page or self
        if page and page.ScrollBy then
            page:ScrollBy(delta)
        end
    end

    local function MakeHeader(owner)
        local row = CreateFrame("Button", nil, owner)
        row:SetHeight(HEADER)
        row.chevron = row:CreateTexture(nil, "ARTWORK")
        row.chevron:SetSize(12, 12)
        row.chevron:SetPoint("LEFT", 4, 0)
        row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
        row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
        row.title = row:CreateFontString(nil, "OVERLAY")
        row.title:SetPoint("LEFT", row.chevron, "RIGHT", 4, 0)
        row.title:SetJustifyH("LEFT")
        Theme.Font(row.title, 15, Theme.GOLD, "OUTLINE")
        row.title:SetText("")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        row:SetScript("OnClick", function(self)
            if not self.sectionId or not self.page or self.page.searching then
                return
            end
            self.page.open[self.sectionId] = not self.page.open[self.sectionId]
            self.page:Refresh(self.page.record, self.page.queryText)
        end)
        return row
    end

    local function MakeItem(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(ROW)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 4, 0)
        row.chevron = row:CreateTexture(nil, "ARTWORK")
        row.chevron:SetSize(12, 12)
        row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
        row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("MIDDLE")
        row.name:SetWordWrap(false)
        Theme.Font(row.name, 13, Theme.CREAM, "")
        row.name:SetText("")
        row.hit = CreateFrame("Button", nil, row)
        row.hit:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -2, 2)
        row.hit:SetPoint("BOTTOMRIGHT", row.name, "BOTTOMRIGHT", 2, -2)
        row.hit:RegisterForClicks("LeftButtonUp")
        row.hit:EnableMouseWheel(true)
        row.hit:SetScript("OnMouseWheel", function(self, delta)
            Wheel(self:GetParent(), delta)
        end)
        row.hit:SetScript("OnEnter", function(self)
            ShowCollectionTip(self:GetParent())
        end)
        row.hit:SetScript("OnLeave", function(self)
            local parent = self:GetParent()
            if parent:IsMouseOver() then
                return
            end
            if GameTooltip and GameTooltip:GetOwner() == parent then
                GameTooltip:Hide()
            end
        end)
        row.hit:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            if not parent.openId or not parent.page or parent.page.searching then
                return
            end
            parent.page.open[parent.openId] = not parent.page.open[parent.openId]
            parent.page:Refresh(parent.page.record, parent.page.queryText)
        end)
        row:EnableMouse(true)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        row:SetScript("OnEnter", function(self)
            ShowCollectionTip(self)
        end)
        row:SetScript("OnLeave", function(self)
            if self:IsMouseOver() then
                return
            end
            if GameTooltip and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end)
        row:SetScript("OnHide", function(self)
            if GameTooltip and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end)
        return row
    end

    local function MakeObtain(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(NOTE)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetPoint("TOPLEFT", 8, -1)
        row.text:SetJustifyH("LEFT")
        row.text:SetJustifyV("TOP")
        row.text:SetWordWrap(true)
        Theme.Font(row.text, 13, Theme.WHITE, "")
        row.text:SetText("")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        return row
    end

    local function MakeNote(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(NOTE)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetJustifyH("LEFT")
        Theme.Font(row.text, 13, Theme.DIM, "")
        row.text:SetText("Not scanned yet")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        return row
    end

    local function Acquire(kind, builder)
        local pool = frame.pools[kind]
        local count = frame.used[kind] + 1
        frame.used[kind] = count
        local row = pool[count]
        if not row then
            row = builder(frame)
            row.page = frame
            pool[count] = row
        end
        row:Show()
        return row
    end

    local function HidePool()
        local kinds = { "header", "item", "obtain", "note" }
        local kindIndex = 1
        while kinds[kindIndex] do
            local pool = frame.pools[kinds[kindIndex]]
            local index = 1
            while pool[index] do
                pool[index]:Hide()
                index = index + 1
            end
            kindIndex = kindIndex + 1
        end
        frame.used.header = 0
        frame.used.item = 0
        frame.used.obtain = 0
        frame.used.note = 0
    end

    function frame:ViewSize()
        local width = 0
        local height = 0
        local okW, w = pcall(self.GetWidth, self)
        local okH, h = pcall(self.GetHeight, self)
        if okW then
            local converted, measuredW = pcall(tonumber, w)
            if converted and type(measuredW) == "number" and measuredW >= 80 then
                width = measuredW
            end
        end
        if okH then
            local converted, measuredH = pcall(tonumber, h)
            if converted and type(measuredH) == "number" and measuredH >= 80 then
                height = measuredH
            end
        end
        if width < 80 then
            width = 640
        end
        if height < 80 then
            height = 400
        end
        return width, height
    end

    function frame:MaxOffset()
        local _, height = self:ViewSize()
        local maxOffset = (self.contentHeight or 0) - height + 8
        if maxOffset < 0 then
            maxOffset = 0
        end
        return maxOffset
    end

    local function PaintHeader(entry, top)
        local row = Acquire("header", MakeHeader)
        row.sectionId = entry.id
        row:SetHeight(entry.h or HEADER)
        row:SetWidth(entry.width)
        Theme.Font(row.title, entry.fontSize or 15, Theme.GOLD, "OUTLINE")
        row.title:SetText(entry.title or "")
        row.chevron:ClearAllPoints()
        row.chevron:SetPoint("LEFT", entry.indent or 4, 0)
        row.title:ClearAllPoints()
        row.title:SetPoint("LEFT", row.chevron, "RIGHT", 4, 0)
        if entry.opened then
            row.chevron:SetRotation(0)
        else
            row.chevron:SetRotation(math.pi)
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    local function PaintItem(entry, top)
        local row = Acquire("item", MakeItem)
        row:SetWidth(entry.width)
        row:SetHeight(ROW)
        local color = Theme.YELLOW
        if entry.collected then
            color = QualityColor(entry.quality)
        end
        Theme.Font(row.name, 13, color, "OUTLINE")
        row.name:SetText(entry.name or "")
        row.icon:ClearAllPoints()
        row.icon:SetPoint("LEFT", entry.indent or 4, 0)
        if type(entry.icon) == "number" or type(entry.icon) == "string" then
            row.icon:SetTexture(entry.icon)
            row.icon:SetTexCoord(0, 1, 0, 1)
            row.icon:Show()
        else
            row.icon:SetTexture(nil)
            row.icon:Hide()
        end
        row.chevron:ClearAllPoints()
        row.chevron:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
        if entry.opened then
            row.chevron:SetRotation(0)
        else
            row.chevron:SetRotation(math.pi)
        end
        row.chevron:Show()
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.chevron, "RIGHT", 4, 0)
        row.name:SetPoint("RIGHT", -8, 0)
        row.hit:ClearAllPoints()
        row.hit:SetAllPoints(row)
        row.itemID = entry.itemID
        row.spellID = entry.spellID
        row.itemName = entry.name
        row.openId = entry.openId
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    local function PaintObtain(entry, top)
        local row = Acquire("obtain", MakeObtain)
        row:SetWidth(entry.width)
        row:SetHeight(entry.h or NOTE)
        Theme.Font(row.text, 13, Theme.WHITE, "")
        row.text:SetWidth(math.max(40, (entry.width or 40) - (entry.indent or 8) - 8))
        row.text:SetText(entry.text or "")
        row.text:ClearAllPoints()
        row.text:SetPoint("TOPLEFT", entry.indent or 8, -1)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    local function PaintNote(entry, top)
        local row = Acquire("note", MakeNote)
        row:SetWidth(entry.width)
        Theme.Font(row.text, 13, Theme.DIM, "")
        row.text:SetText(entry.text or "")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    function frame:Place()
        local _, height = self:ViewSize()
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
        end
        if (self.offset or 0) < 0 then
            self.offset = 0
        end
        HidePool()
        local offset = self.offset or 0
        local layout = self.layout
        local index = 1
        while layout and layout[index] do
            local entry = layout[index]
            local top = -(entry.y or 0) + offset
            if top < 8 and top > -(height + (entry.h or 4)) then
                if entry.kind == "header" then
                    PaintHeader(entry, top)
                elseif entry.kind == "item" then
                    PaintItem(entry, top)
                elseif entry.kind == "obtain" then
                    PaintObtain(entry, top)
                else
                    PaintNote(entry, top)
                end
            end
            index = index + 1
        end
        self.bar:SetFrameLevel((self:GetFrameLevel() or 1) + 40)
        self.barGuard = true
        self.bar:SetMinMaxValues(0, maxOffset)
        self.bar:SetValue(self.offset or 0)
        self.barGuard = false
        if maxOffset <= 1 then
            self.bar:Hide()
        else
            self.bar:Show()
        end
    end

    function frame:ScrollBy(delta)
        local offset = (self.offset or 0) - (delta * 48)
        if offset < 0 then
            offset = 0
        end
        local maxOffset = self:MaxOffset()
        if offset > maxOffset then
            offset = maxOffset
        end
        self.offset = offset
        self:Place()
    end

    bar:SetScript("OnValueChanged", function(_, value)
        if frame.barGuard then
            return
        end
        local offset = value or 0
        if offset < 0 then
            offset = 0
        end
        frame.offset = offset
        frame:Place()
    end)
    pcall(frame.SetClipsChildren, frame, true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        self:ScrollBy(delta)
    end)

    local function Add(layout, entry, y)
        entry.y = y
        layout[#layout + 1] = entry
        return y + (entry.h or ROW) + (entry.gap or 2)
    end

    local function TextHeight(text, textWidth)
        local measure = frame.measure
        if not measure then
            measure = frame:CreateFontString(nil, "OVERLAY")
            Theme.Font(measure, 13, Theme.WHITE, "")
            measure:SetJustifyH("LEFT")
            measure:SetJustifyV("TOP")
            measure:SetAlpha(0)
            frame.measure = measure
        end
        local width = textWidth
        if width < 80 then
            width = 80
        end
        measure:Show()
        measure:SetWordWrap(false)
        measure:SetWidth(4000)
        measure:SetText(text or "")
        local wideOk, wide = pcall(measure.GetStringWidth, measure)
        local px = wideOk and type(wide) == "number" and wide or width
        if px < 1 then
            px = width
        end
        local lines = math.ceil(px / width)
        if lines < 1 then
            lines = 1
        end
        measure:SetWordWrap(true)
        measure:SetWidth(width)
        local height = lines * 16
        local ok, measured = pcall(measure.GetStringHeight, measure)
        if ok and type(measured) == "number" and measured > height then
            height = measured
        end
        measure:Hide()
        local rowH = math.ceil(height + 4)
        if rowH < NOTE then
            rowH = NOTE
        end
        return rowH
    end

    local function SortNamed(list)
        table.sort(list, function(a, b)
            return (a.name or "") < (b.name or "")
        end)
    end

    local function Take(group, typeId, query)
        local source = group[typeId]
        local kept = {}
        local index = 1
        while source and source[index] do
            local item = source[index]
            if query == "" or Hit(query, item.name) or Hit(query, item.source) or Hit(query, item.section) then
                kept[#kept + 1] = item
            end
            index = index + 1
        end
        if kept[1] then
            SortNamed(kept)
        end
        return kept
    end

    local function SectionGroups(rows)
        local order = {}
        local buckets = {}
        local index = 1
        while rows[index] do
            local item = rows[index]
            local key = item.section
            if type(key) ~= "string" or key == "" then
                key = ""
            end
            local bucket = buckets[key]
            if not bucket then
                bucket = {
                    title = key,
                    order = item.sectionOrder or 0,
                    rows = {},
                }
                buckets[key] = bucket
                order[#order + 1] = bucket
            end
            bucket.rows[#bucket.rows + 1] = item
            index = index + 1
        end
        table.sort(order, function(a, b)
            if a.order == b.order then
                return a.title < b.title
            end
            return a.order < b.order
        end)
        return order
    end

    function frame:Refresh(record, queryText)
        if self.record ~= record or self.queryText ~= (queryText or "") then
            self.offset = 0
        end
        self.record = record
        self.queryText = queryText or ""
        local query = Query(self.queryText)
        self.searching = query ~= ""
        local width = self:ViewSize()
        local rowWidth = math.max(200, width - 36)
        local layout = {}
        local y = 4
        local pack = nil
        if record and BMGAM.Store and BMGAM.Store.Collections then
            pack = BMGAM.Store.Collections(record)
        elseif record then
            pack = record.collections
        end
        local scanned = type(pack) == "table" and pack.scanned == true
        if not scanned then
            y = Add(layout, {
                kind = "note",
                x = 8,
                h = NOTE,
                width = rowWidth,
                gap = 2,
                text = "Not scanned yet",
            }, y)
            self.layout = layout
            self.contentHeight = y
            self:Place()
            return
        end
        local collected = {}
        local missing = {}
        local items = pack.items
        local index = 1
        while type(items) == "table" and items[index] do
            local item = items[index]
            if type(item) == "table" and type(item.type) == "string" and type(item.name) == "string" and item.name ~= "" then
                local group = missing
                if item.collected == true then
                    group = collected
                end
                local list = group[item.type]
                if not list then
                    list = {}
                    group[item.type] = list
                end
                list[#list + 1] = item
            end
            index = index + 1
        end
        local groups = {
            { id = "collected", title = "Collected", items = collected },
            { id = "missing", title = "Not Collected", items = missing },
        }
        local drew = false
        local groupIndex = 1
        while groups[groupIndex] do
            local group = groups[groupIndex]
            local blocks = {}
            local typeIndex = 1
            while TYPES[typeIndex] do
                local kind = TYPES[typeIndex]
                local rows = Take(group.items, kind.id, query)
                if rows[1] then
                    blocks[#blocks + 1] = { kind = kind, rows = rows }
                end
                typeIndex = typeIndex + 1
            end
            if blocks[1] then
                drew = true
                local opened = query ~= "" or self.open[group.id] == true
                y = Add(layout, {
                    kind = "header",
                    id = group.id,
                    title = group.title,
                    opened = opened,
                    x = 4,
                    indent = 4,
                    fontSize = 15,
                    h = HEADER,
                    width = rowWidth,
                    gap = 2,
                }, y)
                if opened then
                    local blockIndex = 1
                    while blocks[blockIndex] do
                        local block = blocks[blockIndex]
                        local sectionId = group.id .. "/" .. block.kind.id
                        local typeOpen = query ~= "" or self.open[sectionId] == true
                        y = Add(layout, {
                            kind = "header",
                            id = sectionId,
                            title = block.kind.title,
                            opened = typeOpen,
                            x = 4,
                            indent = 22,
                            fontSize = 14,
                            h = HEADER,
                            width = rowWidth,
                            gap = 2,
                        }, y)
                        if typeOpen then
                            local sections = SectionGroups(block.rows)
                            local sectionIndex = 1
                            while sections[sectionIndex] do
                                local section = sections[sectionIndex]
                                local itemIndent = 40
                                local obtainIndent = 64
                                local showItems = true
                                if section.title ~= "" then
                                    local subId = sectionId .. "/" .. section.title
                                    local subOpen = query ~= "" or self.open[subId] == true
                                    y = Add(layout, {
                                        kind = "header",
                                        id = subId,
                                        title = section.title,
                                        opened = subOpen,
                                        x = 4,
                                        indent = 40,
                                        fontSize = 13,
                                        h = HEADER,
                                        width = rowWidth,
                                        gap = 2,
                                    }, y)
                                    itemIndent = 58
                                    obtainIndent = 82
                                    showItems = subOpen
                                end
                                if showItems then
                                    local rowIndex = 1
                                    while section.rows[rowIndex] do
                                        local item = section.rows[rowIndex]
                                        local openId = item.type .. ":" .. tostring(item.id)
                                        local showHow = self.open[openId] == true
                                        if query ~= "" and Hit(query, item.source) then
                                            showHow = true
                                        end
                                        y = Add(layout, {
                                            kind = "item",
                                            x = 4,
                                            indent = itemIndent,
                                            h = ROW,
                                            width = rowWidth,
                                            gap = 1,
                                            name = item.name,
                                            icon = item.icon,
                                            quality = item.quality,
                                            collected = item.collected == true,
                                            itemID = item.itemID,
                                            spellID = item.spellID,
                                            openId = openId,
                                            opened = showHow,
                                        }, y)
                                        if showHow then
                                            local how = item.source
                                            if type(how) ~= "string" or how == "" then
                                                how = "The client did not say how to obtain this."
                                            end
                                            local textWidth = math.max(80, rowWidth - obtainIndent)
                                            y = Add(layout, {
                                                kind = "obtain",
                                                x = 4,
                                                indent = obtainIndent,
                                                h = TextHeight(how, textWidth),
                                                width = rowWidth,
                                                gap = 2,
                                                text = how,
                                            }, y)
                                        end
                                        rowIndex = rowIndex + 1
                                    end
                                end
                                sectionIndex = sectionIndex + 1
                            end
                        end
                        blockIndex = blockIndex + 1
                    end
                end
            end
            groupIndex = groupIndex + 1
        end
        if not drew then
            y = Add(layout, {
                kind = "note",
                x = 8,
                h = NOTE,
                width = rowWidth,
                gap = 2,
                text = "No collections",
            }, y)
        end
        self.layout = layout
        self.contentHeight = y
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
        end
        self:Place()
    end

    frame:SetScript("OnSizeChanged", function(self)
        if self.sizing then
            return
        end
        self.sizing = true
        if self.record then
            self:Refresh(self.record, self.queryText)
        end
        self.sizing = false
    end)

    return frame
end
