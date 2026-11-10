local _, BMGAM = ...

BMGAM.Auction = BMGAM.Auction or {}
local Auction = BMGAM.Auction
local Theme = BMGAM.Theme

local HEADER = 26
local COLS = 20
local ROW = 32
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

local bandMax = { 1800, 7200, 43200, 172800 }
local bandsLoaded = false

local function LoadBands()
    if bandsLoaded or not C_AuctionHouse or type(C_AuctionHouse.GetTimeLeftBandInfo) ~= "function" then
        return
    end
    local band = 0
    local loaded = false
    while band <= 3 do
        local ok, _, maxValue = pcall(C_AuctionHouse.GetTimeLeftBandInfo, band)
        local number = ok and tonumber(maxValue) or nil
        if number and number > 0 then
            bandMax[band + 1] = number
            loaded = true
        end
        band = band + 1
    end
    if loaded then
        bandsLoaded = true
    end
end

local function BandText(band)
    if band == 0 then
        return "30 min"
    end
    if band == 1 then
        return "2 hours"
    end
    if band == 2 then
        return "12 hours"
    end
    if band == 3 then
        return "2 days"
    end
    return ""
end

local function BandForSeconds(seconds)
    LoadBands()
    local band = 0
    while band <= 3 do
        local limit = bandMax[band + 1]
        if limit and seconds <= limit then
            return band
        end
        band = band + 1
    end
    return 3
end

local function TimeLeftText(entry)
    local seconds = tonumber(entry.timeLeft)
    if seconds then
        local marked = tonumber(entry.markedAt) or 0
        if marked > 0 then
            seconds = seconds - (time() - marked)
        end
        if seconds < 1 then
            return "Expired"
        end
        return BandText(BandForSeconds(seconds))
    end
    return BandText(tonumber(entry.timeBand))
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
    if quality == nil then
        quality = 1
    end
    local color = Theme.QualityColor(quality)
    return color[1], color[2], color[3]
end

function Auction.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { header = {}, columns = {}, row = {}, note = {} }
    frame.used = { header = 0, columns = 0, row = 0, note = 0 }
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

    local function Wheel(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end

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
        row.title:SetText("Auctions")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
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
        row:SetScript("OnMouseWheel", Wheel)
        return row
    end

    local function MakeLabel(owner)
        local text = owner:CreateFontString(nil, "OVERLAY")
        text:SetJustifyH("LEFT")
        Theme.Font(text, 12, Theme.WHITE, "OUTLINE")
        return text
    end

    local function MakeColumns(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(COLS)
        row.item = MakeLabel(row)
        row.item:SetPoint("LEFT", 4, 0)
        row.item:SetText("Item")
        row.time = MakeLabel(row)
        row.time:SetJustifyH("RIGHT")
        row.time:SetText("Time left")
        row.bid = MakeLabel(row)
        row.bid:SetJustifyH("RIGHT")
        row.bid:SetText("Bid")
        row.buy = MakeLabel(row)
        row.buy:SetJustifyH("RIGHT")
        row.buy:SetText("Buyout")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        return row
    end

    local function MakeCoin(owner)
        local icon = owner:CreateTexture(nil, "ARTWORK")
        icon:SetSize(14, 14)
        return icon
    end

    local function MakeMoneyText(owner)
        local text = owner:CreateFontString(nil, "OVERLAY")
        text:SetJustifyH("RIGHT")
        Theme.Font(text, 13, Theme.CREAM, "OUTLINE")
        return text
    end

    local function MakeRow(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(ROW)
        row:EnableMouse(true)
        row.icon = CreateFrame("Button", nil, row, "BackdropTemplate")
        row.icon:SetSize(ICON, ICON)
        row.icon:SetPoint("LEFT", 4, 0)
        row.icon.texture = row.icon:CreateTexture(nil, "ARTWORK")
        row.icon.texture:SetPoint("TOPLEFT", 2, -2)
        row.icon.texture:SetPoint("BOTTOMRIGHT", -2, 2)
        row.icon.count = row.icon:CreateFontString(nil, "OVERLAY")
        row.icon.count:SetPoint("BOTTOMRIGHT", -1, 2)
        row.icon.count:SetJustifyH("RIGHT")
        Theme.Font(row.icon.count, 11, Theme.WHITE, "OUTLINE")
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        Theme.Font(row.name, 13, Theme.CREAM, "")
        row.time = row:CreateFontString(nil, "OVERLAY")
        row.time:SetJustifyH("RIGHT")
        row.time:SetWordWrap(false)
        Theme.Font(row.time, 13, Theme.CREAM, "")
        row.bidEmpty = MakeMoneyText(row)
        row.buyEmpty = MakeMoneyText(row)
        row.bidCopper = MakeMoneyText(row)
        row.bidSilver = MakeMoneyText(row)
        row.bidGold = MakeMoneyText(row)
        row.buyCopper = MakeMoneyText(row)
        row.buySilver = MakeMoneyText(row)
        row.buyGold = MakeMoneyText(row)
        row.bidCopperIcon = MakeCoin(row)
        row.bidCopperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
        row.bidSilverIcon = MakeCoin(row)
        row.bidSilverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
        row.bidGoldIcon = MakeCoin(row)
        row.bidGoldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        row.buyCopperIcon = MakeCoin(row)
        row.buyCopperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
        row.buySilverIcon = MakeCoin(row)
        row.buySilverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
        row.buyGoldIcon = MakeCoin(row)
        row.buyGoldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        row.icon:SetScript("OnEnter", function(self)
            ShowTip(self, self.link)
        end)
        row.icon:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:SetScript("OnEnter", function(self)
            ShowTip(self, self.link)
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        row.icon.page = frame
        row.icon:EnableMouseWheel(true)
        row.icon:SetScript("OnMouseWheel", Wheel)
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
        local kinds = { "header", "columns", "row", "note" }
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
        frame.used.columns = 0
        frame.used.row = 0
        frame.used.note = 0
    end

    local function HideMoney(row, prefix)
        row[prefix .. "Empty"]:Hide()
        row[prefix .. "Copper"]:Hide()
        row[prefix .. "Silver"]:Hide()
        row[prefix .. "Gold"]:Hide()
        row[prefix .. "CopperIcon"]:Hide()
        row[prefix .. "SilverIcon"]:Hide()
        row[prefix .. "GoldIcon"]:Hide()
    end

    local function ShowMoney(row, prefix, copper, right)
        HideMoney(row, prefix)
        if not copper or copper <= 0 then
            local empty = row[prefix .. "Empty"]
            Theme.Font(empty, 13, Theme.DIM, "")
            empty:SetText(prefix == "bid" and "No bids" or "None")
            empty:ClearAllPoints()
            empty:SetPoint("RIGHT", row, "RIGHT", right, 0)
            empty:Show()
            return
        end
        local gold = math.floor(copper / 10000)
        local silver = math.floor((copper % 10000) / 100)
        local rest = copper % 100
        local copperText = row[prefix .. "Copper"]
        local silverText = row[prefix .. "Silver"]
        local goldText = row[prefix .. "Gold"]
        local copperIcon = row[prefix .. "CopperIcon"]
        local silverIcon = row[prefix .. "SilverIcon"]
        local goldIcon = row[prefix .. "GoldIcon"]
        Theme.Font(copperText, 13, Theme.CREAM, "OUTLINE")
        Theme.Font(silverText, 13, Theme.CREAM, "OUTLINE")
        Theme.Font(goldText, 13, Theme.CREAM, "OUTLINE")
        local function PlacePart(text, icon, value, anchor)
            text:SetText(tostring(value))
            text:ClearAllPoints()
            if anchor then
                text:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
            else
                text:SetPoint("RIGHT", row, "RIGHT", right, 0)
            end
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT", text, "LEFT", -2, 0)
            text:Show()
            icon:Show()
            return icon
        end
        local edge = nil
        if rest > 0 then
            edge = PlacePart(copperText, copperIcon, rest, nil)
        end
        if silver > 0 then
            edge = PlacePart(silverText, silverIcon, silver, edge)
        end
        if gold > 0 or not edge then
            PlacePart(goldText, goldIcon, gold, edge)
        end
    end

    local function PaintColumns(row, kind, width)
        local timeRight = -280
        local bidRight = -150
        local buyRight = -8
        if kind == "bids" then
            timeRight = -8
            bidRight = -160
        end
        row.time:ClearAllPoints()
        row.time:SetPoint("RIGHT", row, "RIGHT", timeRight, 0)
        row.bid:ClearAllPoints()
        row.bid:SetPoint("RIGHT", row, "RIGHT", bidRight, 0)
        Theme.Font(row.item, 12, Theme.WHITE, "OUTLINE")
        Theme.Font(row.time, 12, Theme.WHITE, "OUTLINE")
        Theme.Font(row.bid, 12, Theme.WHITE, "OUTLINE")
        row.item:SetText("Item")
        row.time:SetText("Time left")
        if kind == "bids" then
            row.bid:SetText("My bid")
            row.buy:Hide()
        else
            row.bid:SetText("Bid")
            row.buy:SetText("Buyout")
            row.buy:ClearAllPoints()
            row.buy:SetPoint("RIGHT", row, "RIGHT", buyRight, 0)
            Theme.Font(row.buy, 12, Theme.WHITE, "OUTLINE")
            row.buy:Show()
        end
        row:SetWidth(width)
    end

    local function PaintRow(row, entry, kind, width)
        local timeRight = -280
        local bidRight = -150
        local buyRight = -8
        local nameStop = timeRight
        if kind == "bids" then
            timeRight = -8
            bidRight = -160
            nameStop = bidRight
        end
        row.link = entry.link
        row.icon.link = entry.link
        if entry.icon then
            row.icon.texture:SetTexture(entry.icon)
        else
            row.icon.texture:SetTexture(nil)
        end
        local red, green, blue = QualityRGB(entry.quality)
        row.icon:SetBackdrop(SLOT_BACKDROP)
        row.icon:SetBackdropColor(Theme.PANEL[1], Theme.PANEL[2], Theme.PANEL[3], 1)
        row.icon:SetBackdropBorderColor(red, green, blue, 1)
        if (tonumber(entry.count) or 1) > 1 then
            row.icon.count:SetText(tostring(entry.count))
        else
            row.icon.count:SetText("")
        end
        local name = entry.name or ""
        if name == "" then
            name = "(Unknown item)"
        end
        Theme.Font(row.name, 13, Theme.QualityColor(entry.quality == nil and 1 or entry.quality), "")
        row.name:SetText(name)
        row.name:ClearAllPoints()
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
        row.name:SetWidth(math.max(80, width + nameStop - 160))
        local timeText = TimeLeftText(entry)
        local timeColor = Theme.CREAM
        if timeText == "Expired" then
            timeColor = Theme.GOLD
        end
        Theme.Font(row.time, 13, timeColor, "")
        row.time:SetText(timeText)
        row.time:ClearAllPoints()
        row.time:SetPoint("RIGHT", row, "RIGHT", timeRight, 0)
        ShowMoney(row, "bid", tonumber(entry.bid) or 0, bidRight)
        if kind == "bids" then
            HideMoney(row, "buy")
        else
            ShowMoney(row, "buy", tonumber(entry.buyout) or 0, buyRight)
        end
        row:SetWidth(width)
        row:SetHeight(ROW)
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
        local kinds = { "header", "columns", "row", "note" }
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
        return frame.open[id] ~= false
    end

    local function Visible(list, query)
        local out = {}
        local had = false
        local index = 1
        while type(list) == "table" and list[index] do
            had = true
            local entry = list[index]
            if query == "" or Hit(query, entry.name) then
                out[#out + 1] = entry
            end
            index = index + 1
        end
        return out, had
    end

    local function PlaceNote(text, y, width)
        local note = Acquire("note", MakeNote)
        note.placeX = 8
        note.placeY = y
        note.placeH = 18
        note:SetWidth(math.max(80, width - 40))
        Theme.Font(note.text, 13, Theme.DIM, "")
        note.text:SetText(text)
        return y + 22
    end

    function frame:Refresh(record, queryText)
        if record and UnitGUID and record.guid == UnitGUID("player") and BMGAM.Scan and BMGAM.Scan.ReadAuctions then
            pcall(BMGAM.Scan.ReadAuctions)
        end
        self.record = record
        self.queryText = queryText or ""
        HidePool()
        local width = self:ViewSize()
        local rowWidth = math.max(200, width - 36)
        local query = Query(queryText)
        local pack = record and record.auctions
        local scanned = type(pack) == "table" and pack.scanned == true
        local y = 4
        if not scanned then
            y = PlaceNote("Not scanned yet", y, width)
            self.contentHeight = y
            self:Place()
            return
        end
        local sections = {
            { id = "auctions", title = "Auctions", kind = "owned", empty = "No auctions", list = pack.owned },
            { id = "bids", title = "Bids", kind = "bids", empty = "No bids", list = pack.bids },
        }
        local index = 1
        while sections[index] do
            local section = sections[index]
            local rows, had = Visible(section.list, query)
            local skip = query ~= "" and had and not rows[1]
            if not skip then
                local header = Acquire("header", MakeHeader)
                header.placeX = 8
                header.placeY = y
                header.placeH = HEADER
                header:SetWidth(rowWidth)
                Theme.Font(header.title, 15, Theme.GOLD, "OUTLINE")
                header.title:SetText(section.title)
                local sectionOpen = query ~= "" or IsOpen(section.id)
                if sectionOpen then
                    header.chevron:SetRotation(0)
                else
                    header.chevron:SetRotation(math.pi)
                end
                header.sectionId = section.id
                header:SetScript("OnClick", function(button)
                    if query ~= "" then
                        return
                    end
                    frame.open[button.sectionId] = frame.open[button.sectionId] == false
                    frame:Refresh(frame.record, frame.queryText)
                end)
                y = y + HEADER + 4
                if sectionOpen then
                    if not rows[1] then
                        y = PlaceNote(section.empty, y, width)
                    else
                        local columns = Acquire("columns", MakeColumns)
                        columns.placeX = 8
                        columns.placeY = y
                        columns.placeH = COLS
                        columns:SetWidth(rowWidth)
                        PaintColumns(columns, section.kind, rowWidth)
                        y = y + COLS + 2
                        local rowIndex = 1
                        while rows[rowIndex] do
                            local line = Acquire("row", MakeRow)
                            line.placeX = 8
                            line.placeY = y
                            line.placeH = ROW
                            PaintRow(line, rows[rowIndex], section.kind, rowWidth)
                            y = y + ROW + 4
                            rowIndex = rowIndex + 1
                        end
                    end
                end
                y = y + 8
            end
            index = index + 1
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
