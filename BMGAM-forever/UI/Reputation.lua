local _, BMGAM = ...

BMGAM.Reputation = BMGAM.Reputation or {}
local Reputation = BMGAM.Reputation
local Theme = BMGAM.Theme

local HEADER = 26
local ROW = 28
local TEAL = { 0.30, 0.78, 0.86 }
local FALLBACK = {
    [1] = { 0.8, 0.3, 0.22 },
    [2] = { 0.8, 0.3, 0.22 },
    [3] = { 0.75, 0.27, 0 },
    [4] = { 0.9, 0.7, 0 },
    [5] = { 0, 0.6, 0.1 },
    [6] = { 0, 0.6, 0.1 },
    [7] = { 0, 0.6, 0.1 },
    [8] = { 0, 0.6, 0.1 },
}

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
    if type(text) ~= "string" or text == "" then
        return false
    end
    return string.find(string.lower(text), query, 1, true) ~= nil
end

local function Comma(value)
    local number = tonumber(value) or 0
    local sign = ""
    if number < 0 then
        sign = "-"
        number = -number
    end
    local text = tostring(math.floor(number + 0.5))
    local guard = 0
    while guard < 8 do
        guard = guard + 1
        local nextText, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
        text = nextText
        if count == 0 then
            break
        end
    end
    return sign .. text
end

local function ShownProgress(entry)
    local standing = entry.standing or ""
    local level = nil
    if string.find(standing, "Level", 1, true) then
        level = tonumber(string.match(standing, "%d+"))
    end
    local current = tonumber(entry.current) or 0
    local maximum = tonumber(entry.maximum) or 0
    if level then
        current = level
        if maximum > 500 or maximum < level then
            maximum = level
        end
    elseif maximum > 0 and current > maximum then
        current = maximum
    end
    return current, maximum
end

local function ProgressText(entry)
    local current, maximum = ShownProgress(entry)
    return Comma(current) .. " / " .. Comma(maximum)
end

local function StandingColor(entry)
    if entry.kind == "renown" then
        return TEAL
    end
    local reaction = tonumber(entry.reaction)
    if reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction] then
        local color = FACTION_BAR_COLORS[reaction]
        local red = color.r or color[1]
        local green = color.g or color[2]
        local blue = color.b or color[3]
        if type(red) == "number" and type(green) == "number" and type(blue) == "number" then
            return { red, green, blue }
        end
    end
    if reaction and FALLBACK[reaction] then
        return FALLBACK[reaction]
    end
    return Theme.CREAM
end

local function BarFill(entry)
    local current, maximum = ShownProgress(entry)
    local floor = tonumber(entry.floor)
    if floor and maximum > floor and not string.find(entry.standing or "", "Level", 1, true) then
        local gained = current - floor
        local span = maximum - floor
        if gained < 0 then
            gained = 0
        end
        if gained > span then
            gained = span
        end
        return gained / span
    end
    if maximum > 0 and current >= maximum then
        return 1
    end
    if maximum <= 0 then
        return 0
    end
    local ratio = current / maximum
    if ratio < 0 then
        ratio = 0
    end
    if ratio > 1 then
        ratio = 1
    end
    return ratio
end

local function PlaceColumns(row, entry, width, nameWidget)
    local standingW = 128
    local amountW = 96
    local accountW = 72
    local gap = 8
    local barW = 120
    local nameLeft = 0
    if nameWidget == row.title then
        nameLeft = 20
    end
    local used = nameLeft + standingW + amountW + accountW + barW + (gap * 4)
    if width - used < 150 then
        barW = barW - (150 - (width - used))
        if barW < 64 then
            barW = 64
        end
    end
    local color = StandingColor(entry)
    Theme.Font(nameWidget, nameWidget == row.title and 15 or 13, nameWidget == row.title and Theme.GOLD or Theme.CREAM, nameWidget == row.title and "OUTLINE" or "")
    nameWidget:SetText(entry.name or nameWidget:GetText() or "")
    local nameW = width - nameLeft - (standingW + amountW + accountW + barW + (gap * 4))
    if nameW < 80 then
        nameW = 80
    end
    nameWidget:ClearAllPoints()
    nameWidget:SetPoint("LEFT", row, "LEFT", nameLeft, 0)
    nameWidget:SetWidth(nameW)
    Theme.Font(row.standing, 13, color, "")
    row.standing:SetText(entry.standing or "")
    row.standing:SetJustifyH("LEFT")
    row.standing:Show()
    row.standing:ClearAllPoints()
    row.standing:SetWidth(standingW)
    row.standing:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    Theme.Font(row.amount, 12, Theme.CREAM, "")
    row.amount:SetText(ProgressText(entry))
    row.amount:SetJustifyH("RIGHT")
    row.amount:Show()
    row.amount:ClearAllPoints()
    row.amount:SetWidth(amountW)
    row.amount:SetPoint("RIGHT", row.standing, "LEFT", -gap, 0)
    row.track:ClearAllPoints()
    row.track:Show()
    row.track:SetSize(barW, 8)
    row.track:SetPoint("RIGHT", row.amount, "LEFT", -gap, 0)
    local fill = BarFill(entry)
    row.fill:SetColorTexture(color[1], color[2], color[3], 1)
    row.fill:ClearAllPoints()
    row.fill:SetPoint("LEFT", row.track, "LEFT", 0, 0)
    local fillWidth = math.floor(barW * fill)
    if fillWidth < 1 then
        row.fill:Hide()
    else
        row.fill:Show()
        row.fill:SetWidth(fillWidth)
    end
    Theme.Font(row.tag, 12, Theme.DIM, "")
    row.tag:ClearAllPoints()
    row.tag:SetWidth(accountW)
    row.tag:SetJustifyH("LEFT")
    row.tag:SetPoint("RIGHT", row.track, "LEFT", -gap, 0)
    if entry.shared then
        row.tag:SetText("Warband")
        row.tag:Show()
    else
        row.tag:SetText("")
        row.tag:Hide()
    end
end

local function Chevron(texture, opened)
    if opened then
        texture:SetRotation(0)
    else
        texture:SetRotation(math.pi)
    end
end

local function IsOpen(frame, id)
    if frame.open[id] == nil then
        return true
    end
    return frame.open[id]
end

local function MakeHeader(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(HEADER)
    row.chevron = row:CreateTexture(nil, "ARTWORK")
    row.chevron:SetSize(14, 14)
    row.chevron:SetPoint("LEFT", 0, 0)
    row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
    row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetPoint("LEFT", row.chevron, "RIGHT", 6, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    Theme.Font(row.title, 15, Theme.GOLD, "OUTLINE")
    row.standing = row:CreateFontString(nil, "OVERLAY")
    row.standing:SetPoint("RIGHT", -2, 0)
    row.standing:SetWidth(150)
    row.standing:SetJustifyH("RIGHT")
    row.standing:SetWordWrap(false)
    Theme.Font(row.standing, 13, Theme.CREAM, "")
    row.amount = row:CreateFontString(nil, "OVERLAY")
    row.amount:SetJustifyH("RIGHT")
    row.amount:SetWordWrap(false)
    Theme.Font(row.amount, 12, Theme.CREAM, "")
    row.track = row:CreateTexture(nil, "ARTWORK")
    row.track:SetHeight(8)
    row.track:SetColorTexture(0.16, 0.13, 0.08, 0.95)
    row.fill = row:CreateTexture(nil, "OVERLAY")
    row.fill:SetHeight(8)
    row.fill:SetPoint("LEFT", row.track, "LEFT", 0, 0)
    row.tag = row:CreateFontString(nil, "OVERLAY")
    row.tag:SetJustifyH("LEFT")
    row.tag:SetWordWrap(false)
    Theme.Font(row.tag, 12, Theme.DIM, "")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW)
    row.standing = row:CreateFontString(nil, "OVERLAY")
    row.standing:SetPoint("RIGHT", -2, 0)
    row.standing:SetWidth(150)
    row.standing:SetJustifyH("RIGHT")
    row.standing:SetWordWrap(false)
    Theme.Font(row.standing, 13, Theme.CREAM, "")
    row.amount = row:CreateFontString(nil, "OVERLAY")
    row.amount:SetJustifyH("RIGHT")
    row.amount:SetWordWrap(false)
    Theme.Font(row.amount, 12, Theme.CREAM, "")
    row.track = row:CreateTexture(nil, "ARTWORK")
    row.track:SetHeight(8)
    row.track:SetColorTexture(0.16, 0.13, 0.08, 0.95)
    row.fill = row:CreateTexture(nil, "OVERLAY")
    row.fill:SetHeight(8)
    row.fill:SetPoint("LEFT", row.track, "LEFT", 0, 0)
    row.tag = row:CreateFontString(nil, "OVERLAY")
    row.tag:SetJustifyH("LEFT")
    row.tag:SetWordWrap(false)
    Theme.Font(row.tag, 12, Theme.DIM, "")
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("LEFT", 0, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    Theme.Font(row.name, 13, Theme.CREAM, "")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeNote(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetPoint("LEFT", 0, 0)
    Theme.Font(row.text, 13, Theme.DIM, "")
    row.text:SetText("Not scanned yet")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeLine(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(1)
    row.texture = row:CreateTexture(nil, "ARTWORK")
    row.texture:SetAllPoints(row)
    row.texture:SetColorTexture(Theme.LINE[1], Theme.LINE[2], Theme.LINE[3], 0.85)
    return row
end

local function Acquire(frame, kind, builder)
    local pool = frame.pools[kind]
    local count = frame.used[kind] + 1
    frame.used[kind] = count
    local row = pool[count]
    if not row then
        row = builder(frame)
        row.page = frame
        pool[count] = row
    end
    row.placed = true
    row:Show()
    return row
end

local function HidePool(frame)
    local kinds = { "header", "row", "note", "line" }
    local kindIndex = 1
    while kinds[kindIndex] do
        local pool = frame.pools[kinds[kindIndex]]
        local index = 1
        while pool[index] do
            pool[index].placed = false
            pool[index]:Hide()
            index = index + 1
        end
        kindIndex = kindIndex + 1
    end
    frame.used.header = 0
    frame.used.row = 0
    frame.used.note = 0
    frame.used.line = 0
end

local function PaintRow(row, entry)
    local width = row:GetWidth()
    if not width or width < 200 then
        width = 560
    end
    PlaceColumns(row, entry, width, row.name)
end

local function HideStanding(row)
    row.standing:Hide()
    row.amount:Hide()
    row.track:Hide()
    row.fill:Hide()
    row.tag:Hide()
end

local function PaintHeaderStanding(header, entry)
    local width = header:GetWidth()
    if not width or width < 200 then
        width = 560
    end
    if not entry then
        HideStanding(header)
        header.title:ClearAllPoints()
        header.title:SetPoint("LEFT", header.chevron, "RIGHT", 6, 0)
        header.title:SetWidth(math.max(80, width - 28))
        return
    end
    local shown = {
        name = header.title:GetText() or "",
        standing = entry.standing,
        current = entry.current,
        maximum = entry.maximum,
        floor = entry.floor,
        kind = entry.kind,
        reaction = entry.reaction,
        shared = entry.shared,
    }
    PlaceColumns(header, shown, width, header.title)
end

function Reputation.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { header = {}, row = {}, note = {}, line = {} }
    frame.used = { header = 0, row = 0, note = 0, line = 0 }
    frame.offset = 0

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

    function frame:Place()
        local _, height = self:ViewSize()
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
        end
        if (self.offset or 0) < 0 then
            self.offset = 0
        end
        local offset = self.offset or 0
        local kinds = { "header", "row", "note", "line" }
        local kindIndex = 1
        while kinds[kindIndex] do
            local pool = self.pools[kinds[kindIndex]]
            local index = 1
            while pool[index] do
                local widget = pool[index]
                if widget.placed then
                    local top = -(widget.placeY or 0) + offset
                    if top < 8 and top > -(height + 4) then
                        widget:Show()
                        widget:ClearAllPoints()
                        widget:SetPoint("TOPLEFT", self, "TOPLEFT", widget.placeX or 0, top)
                    else
                        widget:Hide()
                    end
                end
                index = index + 1
            end
            kindIndex = kindIndex + 1
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

    function frame:Refresh(record, queryText)
        self.record = record
        self.query = Query(queryText)
        if record and UnitGUID and record.guid == UnitGUID("player") and type(record.reputationSections) ~= "table" then
            if BMGAM.Scan and BMGAM.Scan.ReadReputations then
                pcall(BMGAM.Scan.ReadReputations)
            end
        end
        HidePool(self)
        local width = self:ViewSize()
        local y = 4
        local query = self.query
        local groups = {}
        local stored = record and record.reputationSections
        local sectionIndex = 1
        while type(stored) == "table" and stored[sectionIndex] do
            local section = stored[sectionIndex]
            local headerName = section.name or ""
            local rows = {}
            local storedRows = section.rows
            local rowIndex = 1
            local headerEntry = section.headerRow
            local headerHit = query == "" or Hit(query, headerName)
            if type(headerEntry) == "table" and (Hit(query, headerEntry.standing) or Hit(query, headerEntry.name) or (headerEntry.shared and (Hit(query, "Warband") or Hit(query, "Account")))) then
                headerHit = true
            end
            while type(storedRows) == "table" and storedRows[rowIndex] do
                local entry = storedRows[rowIndex]
                local account = entry.shared and "Warband" or ""
                if headerHit or Hit(query, entry.name) or Hit(query, entry.standing) or (account ~= "" and Hit(query, account)) then
                    rows[#rows + 1] = entry
                end
                rowIndex = rowIndex + 1
            end
            if query == "" or rows[1] or headerHit then
                local shownHeader = nil
                if query == "" or headerHit then
                    shownHeader = headerEntry
                end
                groups[#groups + 1] = { name = headerName, depth = section.depth or 0, rows = rows, headerRow = shownHeader }
            end
            sectionIndex = sectionIndex + 1
        end
        local groupIndex = 1
        local hiddenDepth = nil
        while groups[groupIndex] do
            local group = groups[groupIndex]
            local depth = group.depth or 0
            if hiddenDepth and depth > hiddenDepth then
                groupIndex = groupIndex + 1
            else
                hiddenDepth = nil
                local named = group.name and group.name ~= ""
                if not named then
                    local rowIndex = 1
                    while group.rows[rowIndex] do
                        local line = Acquire(self, "row", MakeRow)
                        line.placeX = 24
                        line.placeY = y
                        line.placeH = ROW
                        line:SetWidth(math.max(200, width - 52))
                        PaintRow(line, group.rows[rowIndex])
                        y = y + ROW
                        rowIndex = rowIndex + 1
                    end
                    groupIndex = groupIndex + 1
                else
                local header = Acquire(self, "header", MakeHeader)
                header.placeX = 8 + (depth * 16)
                header.placeY = y
                header.placeH = HEADER
                header:SetWidth(math.max(80, width - 36 - (depth * 16)))
                Theme.Font(header.title, 15, Theme.GOLD, "OUTLINE")
                header.title:ClearAllPoints()
                header.chevron:Show()
                header.title:SetPoint("LEFT", header.chevron, "RIGHT", 6, 0)
                header.title:SetText(group.name or "")
                PaintHeaderStanding(header, group.headerRow)
                local sectionId = "rep-" .. tostring(depth) .. "-" .. (group.name or "")
                local sectionOpen = self.query ~= "" or IsOpen(self, sectionId)
                Chevron(header.chevron, sectionOpen)
                header.sectionId = sectionId
                header:SetScript("OnClick", function(button)
                    if self.query ~= "" then
                        return
                    end
                    self.open[button.sectionId] = not IsOpen(self, button.sectionId)
                    self:Refresh(self.record, self.query)
                end)
                y = y + HEADER
                local rowIndex = 1
                if sectionOpen then
                    while group.rows[rowIndex] do
                        local line = Acquire(self, "row", MakeRow)
                        line.placeX = 24 + (depth * 16)
                        line.placeY = y
                        line.placeH = ROW
                        line:SetWidth(math.max(200, width - 52 - (depth * 16)))
                        PaintRow(line, group.rows[rowIndex])
                        y = y + ROW
                        rowIndex = rowIndex + 1
                    end
                else
                    hiddenDepth = depth
                end
                y = y + 4
                local rule = Acquire(self, "line", MakeLine)
                rule.placeX = 8
                rule.placeY = y
                rule.placeH = 1
                rule:SetWidth(math.max(80, width - 36))
                y = y + 10
                groupIndex = groupIndex + 1
                end
            end
        end
        if type(stored) ~= "table" and not groups[1] then
            local note = Acquire(self, "note", MakeNote)
            note.text:SetText("Not scanned yet")
            Theme.Font(note.text, 13, Theme.DIM, "")
            note:SetWidth(math.max(80, width - 40))
            note.placeX = 8
            note.placeY = y
            note.placeH = 18
            y = y + 22
        end
        self.contentHeight = y
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
        end
        self:Place()
    end

    frame:Refresh(nil, "")
    return frame
end
