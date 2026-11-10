local _, BMGAM = ...

BMGAM.Mail = BMGAM.Mail or {}
local Mail = BMGAM.Mail
local Theme = BMGAM.Theme

local HEADER = 26
local ICON = 28

local SLOT_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
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
    if not text or text == "" then
        return false
    end
    return string.find(string.lower(text), query, 1, true) ~= nil
end

local function DaysRemaining(letter)
    if letter.kind == "notice" or letter.daysLeft == nil then
        return nil
    end
    local left = tonumber(letter.daysLeft) or 0
    local marked = tonumber(letter.markedAt) or 0
    if marked > 0 then
        left = left - ((time() - marked) / 86400)
    end
    if left < 0 then
        left = 0
    end
    return left
end

local function DaysText(left)
    local shown = math.floor(left)
    if left > 0 and shown < 1 then
        shown = 1
    end
    if shown == 1 then
        return "1 day"
    end
    return tostring(shown) .. " days"
end

local function LetterItems(letter)
    if type(letter.items) ~= "table" then
        return nil
    end
    return letter.items
end

local function HasMoney(letter)
    return (tonumber(letter.money) or 0) > 0
end

local function HasItemRow(letter)
    local items = LetterItems(letter)
    return (items and items[1]) or HasMoney(letter)
end

local function LetterHeight(letter)
    local height = 44
    if HasItemRow(letter) then
        height = height + 34
    end
    return height
end

local function ShowTip(owner, link)
    if not link or link == "" then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if ok then
        if TooltipUtil and TooltipUtil.SurfaceArgs then
            pcall(TooltipUtil.SurfaceArgs, GameTooltip)
        end
        GameTooltip:Show()
    end
end

local function QualityRGB(quality)
    local color = Theme.QualityColor(quality or 1)
    return color[1], color[2], color[3]
end

function Mail.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { header = {}, letter = {}, note = {} }
    frame.used = { header = 0, letter = 0, note = 0 }
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

    local function MakeHeader(owner)
        local row = CreateFrame("Button", nil, owner)
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
        row.title:SetText("Inbox")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(self, delta)
            if self.page and self.page.ScrollBy then
                self.page:ScrollBy(delta)
            end
        end)
        return row
    end

    local function MakeNote(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(18)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetPoint("LEFT", 8, 0)
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

    local function MakeIcon(letter)
        local icon = CreateFrame("Button", nil, letter, "BackdropTemplate")
        icon:SetSize(ICON, ICON)
        icon.texture = icon:CreateTexture(nil, "ARTWORK")
        icon.texture:SetPoint("TOPLEFT", 2, -2)
        icon.texture:SetPoint("BOTTOMRIGHT", -2, 2)
        icon.count = icon:CreateFontString(nil, "OVERLAY")
        icon.count:SetPoint("BOTTOMRIGHT", -1, 2)
        icon.count:SetJustifyH("RIGHT")
        Theme.Font(icon.count, 11, Theme.WHITE, "OUTLINE")
        icon:SetScript("OnEnter", function(self)
            ShowTip(self, self.link)
        end)
        icon:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        icon:EnableMouseWheel(true)
        icon:SetScript("OnMouseWheel", function(self, delta)
            if self.page and self.page.ScrollBy then
                self.page:ScrollBy(delta)
            end
        end)
        return icon
    end

    local function MakeLetter(owner)
        local row = CreateFrame("Frame", nil, owner)
        row.sender = row:CreateFontString(nil, "OVERLAY")
        row.sender:SetPoint("TOPLEFT", 8, -4)
        row.sender:SetJustifyH("LEFT")
        row.sender:SetWordWrap(false)
        Theme.Font(row.sender, 14, Theme.CREAM, "")
        row.days = row:CreateFontString(nil, "OVERLAY")
        row.days:SetPoint("TOPRIGHT", -8, -4)
        row.days:SetJustifyH("RIGHT")
        row.days:SetWordWrap(false)
        Theme.Font(row.days, 13, Theme.CREAM, "OUTLINE")
        row.subject = row:CreateFontString(nil, "OVERLAY")
        row.subject:SetPoint("TOPLEFT", 8, -22)
        row.subject:SetJustifyH("LEFT")
        row.subject:SetWordWrap(false)
        Theme.Font(row.subject, 13, Theme.CREAM, "")
        row.copper = row:CreateFontString(nil, "OVERLAY")
        row.copper:SetJustifyH("RIGHT")
        Theme.Font(row.copper, 13, Theme.CREAM, "OUTLINE")
        row.copperIcon = row:CreateTexture(nil, "ARTWORK")
        row.copperIcon:SetSize(14, 14)
        row.copperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
        row.silver = row:CreateFontString(nil, "OVERLAY")
        row.silver:SetJustifyH("RIGHT")
        Theme.Font(row.silver, 13, Theme.CREAM, "OUTLINE")
        row.silverIcon = row:CreateTexture(nil, "ARTWORK")
        row.silverIcon:SetSize(14, 14)
        row.silverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
        row.gold = row:CreateFontString(nil, "OVERLAY")
        row.gold:SetJustifyH("RIGHT")
        Theme.Font(row.gold, 13, Theme.CREAM, "OUTLINE")
        row.goldIcon = row:CreateTexture(nil, "ARTWORK")
        row.goldIcon:SetSize(14, 14)
        row.goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        row.icons = {}
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(self, delta)
            if self.page and self.page.ScrollBy then
                self.page:ScrollBy(delta)
            end
        end)
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
        row.placed = true
        row:Show()
        return row
    end

    local function HidePool()
        local kinds = { "header", "letter", "note" }
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
        frame.used.letter = 0
        frame.used.note = 0
    end

    local function HideIcons(letter)
        local index = 1
        while letter.icons[index] do
            letter.icons[index]:Hide()
            index = index + 1
        end
        letter.iconUsed = 0
    end

    local function AcquireIcon(letter)
        local count = (letter.iconUsed or 0) + 1
        letter.iconUsed = count
        local icon = letter.icons[count]
        if not icon then
            icon = MakeIcon(letter)
            icon.page = frame
            letter.icons[count] = icon
        end
        icon:Show()
        return icon
    end

    local function PaintMoney(letter, copper, anchor)
        local gold = math.floor(copper / 10000)
        local silver = math.floor((copper % 10000) / 100)
        local rest = copper % 100
        letter.copper:ClearAllPoints()
        letter.copper:SetPoint("RIGHT", anchor, "RIGHT", -8, 0)
        letter.copper:SetText(tostring(rest))
        letter.copper:Show()
        letter.copperIcon:ClearAllPoints()
        letter.copperIcon:SetPoint("RIGHT", letter.copper, "LEFT", -2, 0)
        letter.copperIcon:Show()
        letter.silver:ClearAllPoints()
        letter.silver:SetPoint("RIGHT", letter.copperIcon, "LEFT", -8, 0)
        letter.silver:SetText(tostring(silver))
        letter.silver:Show()
        letter.silverIcon:ClearAllPoints()
        letter.silverIcon:SetPoint("RIGHT", letter.silver, "LEFT", -2, 0)
        letter.silverIcon:Show()
        letter.gold:ClearAllPoints()
        letter.gold:SetPoint("RIGHT", letter.silverIcon, "LEFT", -8, 0)
        letter.gold:SetText(tostring(gold))
        letter.gold:Show()
        letter.goldIcon:ClearAllPoints()
        letter.goldIcon:SetPoint("RIGHT", letter.gold, "LEFT", -2, 0)
        letter.goldIcon:Show()
    end

    local function HideMoney(letter)
        letter.copper:Hide()
        letter.copperIcon:Hide()
        letter.silver:Hide()
        letter.silverIcon:Hide()
        letter.gold:Hide()
        letter.goldIcon:Hide()
    end

    local function PaintLetter(letter, entry, width)
        HideIcons(letter)
        local sender = entry.sender or ""
        local subject = entry.subject or ""
        if entry.kind == "notice" then
            if sender == "" then
                sender = "New mail"
                subject = ""
            else
                subject = "New mail"
            end
        elseif subject == "" then
            subject = "(No subject)"
        end
        Theme.Font(letter.sender, 14, Theme.CREAM, "")
        letter.sender:SetText(sender)
        letter.sender:ClearAllPoints()
        letter.sender:SetPoint("TOPLEFT", 8, -4)
        letter.sender:SetWidth(math.max(80, width - 120))
        local left = DaysRemaining(entry)
        if left == nil then
            letter.days:SetText("")
            letter.days:Hide()
        else
            local color = Theme.CREAM
            if left < 3 then
                color = Theme.GOLD
            end
            Theme.Font(letter.days, 13, color, "OUTLINE")
            letter.days:SetText(DaysText(left))
            letter.days:Show()
        end
        local unread = entry.kind == "notice" or entry.read ~= true
        Theme.Font(letter.subject, 13, Theme.CREAM, unread and "OUTLINE" or "")
        letter.subject:SetText(subject)
        letter.subject:ClearAllPoints()
        letter.subject:SetPoint("TOPLEFT", 8, -22)
        letter.subject:SetWidth(math.max(80, width - 24))
        local items = LetterItems(entry)
        local money = tonumber(entry.money) or 0
        if items and items[1] then
            local index = 1
            local x = 8
            while items[index] do
                local item = items[index]
                local icon = AcquireIcon(letter)
                icon.link = item.link
                icon:ClearAllPoints()
                icon:SetPoint("TOPLEFT", x, -42)
                if item.icon then
                    icon.texture:SetTexture(item.icon)
                else
                    icon.texture:SetTexture(nil)
                end
                local red, green, blue = QualityRGB(item.quality)
                icon:SetBackdrop(SLOT_BACKDROP)
                icon:SetBackdropColor(Theme.PANEL[1], Theme.PANEL[2], Theme.PANEL[3], 1)
                icon:SetBackdropBorderColor(red, green, blue, 1)
                if (tonumber(item.count) or 1) > 1 then
                    icon.count:SetText(tostring(item.count))
                else
                    icon.count:SetText("")
                end
                x = x + ICON + 6
                index = index + 1
            end
        end
        if money > 0 then
            PaintMoney(letter, money, letter)
            letter.copper:ClearAllPoints()
            letter.copper:SetPoint("BOTTOMRIGHT", -8, 8)
            letter.copperIcon:ClearAllPoints()
            letter.copperIcon:SetPoint("RIGHT", letter.copper, "LEFT", -2, 0)
            letter.silver:ClearAllPoints()
            letter.silver:SetPoint("RIGHT", letter.copperIcon, "LEFT", -8, 0)
            letter.silverIcon:ClearAllPoints()
            letter.silverIcon:SetPoint("RIGHT", letter.silver, "LEFT", -2, 0)
            letter.gold:ClearAllPoints()
            letter.gold:SetPoint("RIGHT", letter.silverIcon, "LEFT", -8, 0)
            letter.goldIcon:ClearAllPoints()
            letter.goldIcon:SetPoint("RIGHT", letter.gold, "LEFT", -2, 0)
        else
            HideMoney(letter)
        end
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
        local kinds = { "header", "letter", "note" }
        local kindIndex = 1
        while kinds[kindIndex] do
            local pool = self.pools[kinds[kindIndex]]
            local index = 1
            while pool[index] do
                local widget = pool[index]
                if widget.placed then
                    local top = -(widget.placeY or 0) + offset
                    if top < 8 and top > -(height + (widget.placeH or 4)) then
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

    local function IsOpen(id)
        if frame.open[id] == nil then
            return true
        end
        return frame.open[id]
    end

    local function Collect(mail, query)
        local rows = {}
        if type(mail) ~= "table" then
            return rows, false
        end
        local headerHit = query == "" or Hit(query, "Inbox")
        local notice = mail.notice
        local index = 1
        while type(notice) == "table" and notice[index] do
            local sender = notice[index]
            if type(sender) ~= "string" then
                sender = ""
            end
            local entry = { kind = "notice", sender = sender, subject = "New mail", read = false }
            if headerHit or Hit(query, entry.sender) or Hit(query, entry.subject) then
                rows[#rows + 1] = entry
            end
            index = index + 1
        end
        local function Take(list)
            local rowIndex = 1
            while type(list) == "table" and list[rowIndex] do
                local entry = list[rowIndex]
                local matched = headerHit or Hit(query, entry.sender) or Hit(query, entry.subject)
                if not matched then
                    local items = LetterItems(entry)
                    local itemIndex = 1
                    while items and items[itemIndex] do
                        if Hit(query, items[itemIndex].name) then
                            matched = true
                        end
                        itemIndex = itemIndex + 1
                    end
                end
                if matched then
                    rows[#rows + 1] = entry
                end
                rowIndex = rowIndex + 1
            end
        end
        Take(mail.sent)
        Take(mail.letters)
        return rows, mail.scanned == true, mail.noticeChecked == true
    end

    function frame:Refresh(record, queryText)
        if record and UnitGUID and record.guid == UnitGUID("player") and BMGAM.Scan and BMGAM.Scan.ReadMailNotice then
            pcall(BMGAM.Scan.ReadMailNotice)
        end
        self.record = record
        HidePool()
        local width = self:ViewSize()
        local query = Query(queryText)
        local mail = record and record.mail
        local rows, scanned, noticeChecked = Collect(mail, query)
        local y = 4
        local header = Acquire("header", MakeHeader)
        header.placeX = 8
        header.placeY = y
        header.placeH = HEADER
        header:SetWidth(math.max(80, width - 36))
        Theme.Font(header.title, 15, Theme.GOLD, "OUTLINE")
        header.title:SetText("Inbox")
        local sectionId = "mail-inbox"
        local sectionOpen = query ~= "" or IsOpen(sectionId)
        if sectionOpen then
            header.chevron:SetRotation(0)
        else
            header.chevron:SetRotation(math.pi)
        end
        header.sectionId = sectionId
        header:SetScript("OnClick", function(button)
            if query ~= "" then
                return
            end
            frame.open[button.sectionId] = not IsOpen(button.sectionId)
            frame:Refresh(frame.record, queryText)
        end)
        y = y + HEADER + 6
        if sectionOpen then
            if not rows[1] and query == "" then
                local note = Acquire("note", MakeNote)
                note.placeX = 8
                note.placeY = y
                note.placeH = 18
                note:SetWidth(math.max(80, width - 40))
                Theme.Font(note.text, 13, Theme.DIM, "")
                if scanned then
                    note.text:SetText("Inbox is empty")
                elseif noticeChecked then
                    note.text:SetText("No new mail")
                else
                    note.text:SetText("Not scanned yet")
                end
                y = y + 22
            end
            local index = 1
            while rows[index] do
                local entry = rows[index]
                local line = Acquire("letter", MakeLetter)
                local height = LetterHeight(entry)
                line.placeX = 8
                line.placeY = y
                line.placeH = height
                line:SetWidth(math.max(200, width - 36))
                line:SetHeight(height)
                PaintLetter(line, entry, math.max(200, width - 36))
                y = y + height + 8
                index = index + 1
            end
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
