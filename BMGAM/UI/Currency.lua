local _, BMGAM = ...

BMGAM.Currency = BMGAM.Currency or {}
local Currency = BMGAM.Currency
local Theme = BMGAM.Theme

local HEADER = 26
local MONEY = 24
local ROW = 28

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

local function MoneyParts(copper)
    local amount = tonumber(copper) or 0
    if amount < 0 then
        amount = 0
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local rest = amount % 100
    return gold, silver, rest
end

local function AccountCopper()
    local total = 0
    local list = BMGAM.DB.List()
    local index = 1
    while list[index] do
        local copper = tonumber(list[index].moneyCopper)
        if copper and copper >= 0 then
            total = total + copper
        end
        index = index + 1
    end
    return total
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

local function AmountText(entry)
    local amount = tonumber(entry.amount) or 0
    local cap = tonumber(entry.max)
    if cap and cap > 0 then
        return Comma(amount) .. "/" .. Comma(cap)
    end
    return Comma(amount)
end

local function TagText(tag)
    if tag == "account" then
        return "Account"
    end
    if tag == "pvp" then
        return "PvP"
    end
    return ""
end

local function ShowCurrencyTip(owner, currencyID)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local shown = false
    if currencyID and GameTooltip.SetCurrencyTokenByID then
        shown = pcall(GameTooltip.SetCurrencyTokenByID, GameTooltip, currencyID)
    end
    if not shown and currencyID and GameTooltip.SetCurrencyByID then
        shown = pcall(GameTooltip.SetCurrencyByID, GameTooltip, currencyID)
    end
    if shown then
        GameTooltip:Show()
        return
    end
    GameTooltip:Hide()
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
    Theme.Font(row.title, 15, Theme.GOLD, "OUTLINE")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeMoney(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(MONEY)
    row.copper = row:CreateFontString(nil, "OVERLAY")
    row.copper:SetPoint("RIGHT", -4, 0)
    row.copper:SetJustifyH("RIGHT")
    Theme.Font(row.copper, 13, Theme.CREAM, "OUTLINE")
    row.copperIcon = row:CreateTexture(nil, "ARTWORK")
    row.copperIcon:SetSize(14, 14)
    row.copperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
    row.copperIcon:SetPoint("RIGHT", row.copper, "LEFT", -2, 0)
    row.silver = row:CreateFontString(nil, "OVERLAY")
    row.silver:SetPoint("RIGHT", row.copperIcon, "LEFT", -8, 0)
    row.silver:SetJustifyH("RIGHT")
    Theme.Font(row.silver, 13, Theme.CREAM, "OUTLINE")
    row.silverIcon = row:CreateTexture(nil, "ARTWORK")
    row.silverIcon:SetSize(14, 14)
    row.silverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
    row.silverIcon:SetPoint("RIGHT", row.silver, "LEFT", -2, 0)
    row.gold = row:CreateFontString(nil, "OVERLAY")
    row.gold:SetPoint("RIGHT", row.silverIcon, "LEFT", -8, 0)
    row.gold:SetJustifyH("RIGHT")
    Theme.Font(row.gold, 13, Theme.CREAM, "OUTLINE")
    row.goldIcon = row:CreateTexture(nil, "ARTWORK")
    row.goldIcon:SetSize(14, 14)
    row.goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    row.goldIcon:SetPoint("RIGHT", row.gold, "LEFT", -2, 0)
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetJustifyH("LEFT")
    Theme.Font(row.label, 13, Theme.CREAM, "")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 0, 0)
    row.amount = row:CreateFontString(nil, "OVERLAY")
    row.amount:SetPoint("RIGHT", -4, 0)
    row.amount:SetJustifyH("RIGHT")
    Theme.Font(row.amount, 13, Theme.CREAM, "OUTLINE")
    row.tag = row:CreateFontString(nil, "OVERLAY")
    row.tag:SetJustifyH("LEFT")
    Theme.Font(row.tag, 12, Theme.DIM, "")
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    Theme.Font(row.name, 13, Theme.CREAM, "")
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
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
    local kinds = { "header", "money", "row", "note", "line" }
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
    frame.used.money = 0
    frame.used.row = 0
    frame.used.note = 0
    frame.used.line = 0
end

local function PaintMoney(row, label, copper)
    Theme.Font(row.label, 13, Theme.CREAM, "")
    row.label:SetText(label)
    local gold, silver, rest = MoneyParts(copper)
    Theme.Font(row.gold, 13, Theme.CREAM, "OUTLINE")
    row.gold:SetText(tostring(gold))
    Theme.Font(row.silver, 13, Theme.CREAM, "OUTLINE")
    row.silver:SetText(tostring(silver))
    Theme.Font(row.copper, 13, Theme.CREAM, "OUTLINE")
    row.copper:SetText(tostring(rest))
end

local function PaintRow(row, entry)
    if type(entry.icon) == "number" or type(entry.icon) == "string" then
        row.icon:SetTexture(entry.icon)
    else
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    row.icon:SetVertexColor(1, 1, 1)
    local amount = tonumber(entry.amount) or 0
    local color = amount > 0 and Theme.CREAM or Theme.DIM
    Theme.Font(row.amount, 13, color, "OUTLINE")
    row.amount:SetText(AmountText(entry))
    Theme.Font(row.name, 13, Theme.CREAM, "")
    row.name:SetText(entry.name or "")
    local tag = TagText(entry.tag)
    Theme.Font(row.tag, 12, Theme.DIM, "")
    row.tag:SetText(tag)
    row.name:ClearAllPoints()
    row.tag:ClearAllPoints()
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    local reserve = 120
    if tag ~= "" then
        reserve = 200
    end
    local room = row:GetWidth() - 36 - reserve
    if room < 80 then
        room = 80
    end
    local textWidth = row.name:GetStringWidth()
    if not textWidth or textWidth < 1 then
        textWidth = room
    elseif textWidth > room then
        textWidth = room
    end
    row.name:SetWidth(textWidth + 2)
    if tag ~= "" then
        row.tag:Show()
        row.tag:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
    else
        row.tag:Hide()
    end
    row.currencyID = entry.id
    row:SetScript("OnEnter", function(self)
        ShowCurrencyTip(self, self.currencyID)
    end)
end

function Currency.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { header = {}, money = {}, row = {}, note = {}, line = {} }
    frame.used = { header = 0, money = 0, row = 0, note = 0, line = 0 }
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
        local kinds = { "header", "money", "row", "note", "line" }
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
        if record and UnitGUID and record.guid == UnitGUID("player") and type(record.currencies) ~= "table" then
            if BMGAM.Scan and BMGAM.Scan.ReadCurrencies then
                pcall(BMGAM.Scan.ReadCurrencies)
            end
        end
        HidePool(self)
        local width = self:ViewSize()
        local y = 4
        local query = self.query
        local showMoney = query == "" or Hit(query, "Money") or Hit(query, "Character") or Hit(query, "Account Wide")
        if showMoney and record then
            local header = Acquire(self, "header", MakeHeader)
            header.placeX = 8
            header.placeY = y
            header.placeH = HEADER
            header:SetWidth(math.max(80, width - 36))
            Theme.Font(header.title, 15, Theme.GOLD, "OUTLINE")
            header.title:ClearAllPoints()
            header.title:SetPoint("LEFT", 0, 0)
            header.chevron:Hide()
            header:SetScript("OnClick", nil)
            header.title:SetText("Money")
            y = y + HEADER
            local character = Acquire(self, "money", MakeMoney)
            character.placeX = 8
            character.placeY = y
            character.placeH = MONEY
            character:SetWidth(math.max(80, width - 36))
            PaintMoney(character, "Character:", record.moneyCopper)
            y = y + MONEY
            local account = Acquire(self, "money", MakeMoney)
            account.placeX = 8
            account.placeY = y
            account.placeH = MONEY
            account:SetWidth(math.max(80, width - 36))
            PaintMoney(account, "Account Wide:", AccountCopper())
            y = y + MONEY + 4
            local rule = Acquire(self, "line", MakeLine)
            rule.placeX = 8
            rule.placeY = y
            rule.placeH = 1
            rule:SetWidth(math.max(80, width - 36))
            y = y + 10
        end
        local currencies = record and record.currencies
        local groups = {}
        local storedSections = record and record.currencySections
        if type(storedSections) == "table" and storedSections[1] then
            local sectionIndex = 1
            while storedSections[sectionIndex] do
                local section = storedSections[sectionIndex]
                local headerName = section.name or ""
                local rows = {}
                local storedRows = section.rows
                local rowIndex = 1
                local headerHit = query == "" or Hit(query, headerName)
                while type(storedRows) == "table" and storedRows[rowIndex] do
                    local entry = storedRows[rowIndex]
                    local tag = TagText(entry.tag)
                    if headerHit or Hit(query, entry.name) or (tag ~= "" and Hit(query, tag)) then
                        rows[#rows + 1] = entry
                    end
                    rowIndex = rowIndex + 1
                end
                if query == "" or rows[1] or Hit(query, headerName) then
                    groups[#groups + 1] = { name = headerName, depth = section.depth or 0, rows = rows }
                end
                sectionIndex = sectionIndex + 1
            end
        else
            local index = 1
            while type(currencies) == "table" and currencies[index] do
                local entry = currencies[index]
                local headerName = entry.expansion or ""
                local tag = TagText(entry.tag)
                local show = query == "" or Hit(query, entry.name) or Hit(query, headerName) or (tag ~= "" and Hit(query, tag))
                if show then
                    local group = groups[#groups]
                    if not group or group.name ~= headerName then
                        group = { name = headerName, depth = 0, rows = {} }
                        groups[#groups + 1] = group
                    end
                    group.rows[#group.rows + 1] = entry
                end
                index = index + 1
            end
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
                local sectionId = "cur-" .. tostring(depth) .. "-" .. (group.name or "")
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
                        line:SetWidth(math.max(120, width - 52 - (depth * 16)))
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
        if type(currencies) ~= "table" and not groups[1] then
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
