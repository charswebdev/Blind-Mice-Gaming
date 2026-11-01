local _, BMGAM = ...

BMGAM.Bank = BMGAM.Bank or {}
local Bank = BMGAM.Bank
local Theme = BMGAM.Theme

local SLOT = 36
local GAP = 4
local HEADER = 34

local QUALITY_COLOR = {
    [0] = { 157 / 255, 157 / 255, 157 / 255 },
    [1] = { 1, 1, 1 },
    [2] = { 30 / 255, 1, 0 },
    [3] = { 0, 112 / 255, 221 / 255 },
    [4] = { 163 / 255, 53 / 255, 238 / 255 },
    [5] = { 1, 128 / 255, 0 },
    [6] = { 230 / 255, 204 / 255, 128 / 255 },
    [7] = { 0, 204 / 255, 1 },
    [8] = { 0, 204 / 255, 1 },
}

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

local function QualityRGB(quality, link)
    if type(link) == "string" then
        local hex = link:match("|cff(%x%x%x%x%x%x)")
        if hex then
            local red = tonumber(hex:sub(1, 2), 16)
            local green = tonumber(hex:sub(3, 4), 16)
            local blue = tonumber(hex:sub(5, 6), 16)
            if red and green and blue then
                return red / 255, green / 255, blue / 255
            end
        end
    end
    if type(quality) == "number" and QUALITY_COLOR[quality] then
        local color = QUALITY_COLOR[quality]
        return color[1], color[2], color[3]
    end
    return 1, 1, 1
end

local function PaintQuality(frame, fill, r, g, b)
    if not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop(SLOT_BACKDROP)
    frame:SetBackdropColor(fill[1], fill[2], fill[3], fill[4] or 1)
    frame:SetBackdropBorderColor(r, g, b, 1)
end

local function ShowTip(owner, link)
    if not link or link == "" then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if ok then
        GameTooltip:Show()
    end
end

local function MakeHeader(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(HEADER)
    row.chevron = row:CreateTexture(nil, "ARTWORK")
    row.chevron:SetSize(14, 14)
    row.chevron:SetPoint("LEFT", 0, 2)
    row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
    row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
    row.iconPlate = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconPlate:SetSize(28, 28)
    row.iconPlate:SetPoint("LEFT", row.chevron, "RIGHT", 6, 2)
    Theme.Paint(row.iconPlate, Theme.PANEL, Theme.GOLD_DIM)
    row.icon = row.iconPlate:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    row.icon:SetTexture("Interface\\Minimap\\Tracking\\Banker")
    row.count = row:CreateFontString(nil, "OVERLAY")
    row.count:SetPoint("RIGHT", -4, 2)
    row.count:SetJustifyH("RIGHT")
    Theme.Font(row.count, 13, Theme.CREAM, "")
    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetPoint("LEFT", row.iconPlate, "RIGHT", 8, 2)
    row.title:SetPoint("RIGHT", row.count, "LEFT", -8, 2)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    Theme.Font(row.title, 14, Theme.GOLD, "OUTLINE")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.bank and self.bank.ScrollBy then
            self.bank:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeSlot(parent)
    local slot = CreateFrame("Button", nil, parent, "BackdropTemplate")
    slot:SetSize(SLOT, SLOT)
    Theme.Paint(slot, Theme.PANEL, Theme.GOLD_DIM)
    slot.icon = slot:CreateTexture(nil, "ARTWORK")
    slot.icon:SetPoint("TOPLEFT", 2, -2)
    slot.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    slot.count = slot:CreateFontString(nil, "OVERLAY")
    slot.count:SetPoint("BOTTOMRIGHT", -2, 2)
    slot.count:SetJustifyH("RIGHT")
    Theme.Font(slot.count, 11, Theme.WHITE, "OUTLINE")
    slot:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    slot:EnableMouseWheel(true)
    slot:SetScript("OnMouseWheel", function(self, delta)
        if self.bank and self.bank.ScrollBy then
            self.bank:ScrollBy(delta)
        end
    end)
    return slot
end

local function MakeNote(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetPoint("LEFT", 0, 0)
    Theme.Font(row.text, 13, Theme.DIM, "")
    row.text:SetText("Not scanned yet")
    return row
end

local function Acquire(frame, kind, builder)
    local pool = frame.pools[kind]
    local count = frame.used[kind] + 1
    frame.used[kind] = count
    local row = pool[count]
    if not row then
        row = builder(frame)
        row.bank = frame
        pool[count] = row
    end
    row.placed = true
    row:Show()
    return row
end

local function HidePool(frame)
    local kinds = { "header", "slot", "note" }
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
    frame.used.slot = 0
    frame.used.note = 0
end

local function IsOpen(frame, id)
    if frame.open[id] == nil then
        return true
    end
    return frame.open[id]
end

local function FillSlot(slot, item)
    if not item or item.empty then
        slot.link = nil
        slot.icon:SetTexture(nil)
        slot.count:SetText("")
        Theme.Paint(slot, Theme.BG, { 0.22, 0.18, 0.12, 1 })
        slot:SetScript("OnEnter", nil)
        return
    end
    slot.link = item.link
    if type(item.icon) == "number" or type(item.icon) == "string" then
        slot.icon:SetTexture(item.icon)
    else
        slot.icon:SetTexture(nil)
    end
    slot.icon:SetVertexColor(1, 1, 1)
    local r, g, b = QualityRGB(item.quality, item.link)
    PaintQuality(slot, Theme.PANEL, r, g, b)
    if item.count and item.count > 1 then
        slot.count:SetText(item.count)
    else
        slot.count:SetText("")
    end
    slot:SetScript("OnEnter", function(self)
        ShowTip(self, self.link)
    end)
end

local function WarbandIcon()
    if C_Item and C_Item.GetItemInfoInstant then
        local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, 216665)
        if ok and icon and icon ~= 0 then
            return icon
        end
    end
    if C_Item and C_Item.GetItemIconByID then
        local ok, icon = pcall(C_Item.GetItemIconByID, 216665)
        if ok and icon and icon ~= 0 then
            return icon
        end
    end
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, 460905)
        if ok and icon and icon ~= 0 then
            return icon
        end
    end
    return nil
end

local function GuildData(record)
    if not record or not record.guildName or record.guildName == "" then
        return nil
    end
    local account = BMGAM.DB.Account()
    local banks = account and account.guildBanks
    if type(banks) ~= "table" then
        return nil
    end
    return banks[(record.realm or "") .. "-" .. record.guildName]
end

local function Sections(record)
    local account = BMGAM.DB.Account()
    return {
        { id = "personal", title = "Personal bank", data = record and record.bank },
        { id = "warband", title = "Warband bank", data = account and account.warbandBank },
        { id = "guild", title = "Guild bank", data = GuildData(record) },
    }
end

function Bank.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { header = {}, slot = {}, note = {} }
    frame.used = { header = 0, slot = 0, note = 0 }
    frame.offset = 0

    local bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(8)
    bar:SetPoint("TOPRIGHT", -2, -4)
    bar:SetPoint("BOTTOMRIGHT", -2, 4)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.95)
    thumb:SetSize(8, 28)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    frame.bar = bar

    function frame:ViewSize()
        local width = 0
        local height = 0
        local okW, w = pcall(self.GetWidth, self)
        local okH, h = pcall(self.GetHeight, self)
        if okW and type(w) == "number" and w >= 80 then
            width = w
        end
        if okH and type(h) == "number" and h >= 80 then
            height = h
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
        local kinds = { "header", "slot", "note" }
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
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        self:ScrollBy(delta)
    end)

    function frame:Refresh(record, queryText)
        self.record = record
        self.query = Query(queryText)
        HidePool(self)
        local width = self:ViewSize()
        local columns = math.floor((width - 24) / (SLOT + GAP))
        if columns < 4 then
            columns = 4
        end
        local y = 0
        local sections = Sections(record)
        local sectionIndex = 1
        while sections[sectionIndex] do
            local section = sections[sectionIndex]
            local data = section.data
            local scanned = data and data.scanned
            local matches = {}
            if scanned and data.slots then
                local slotIndex = 1
                while data.slots[slotIndex] do
                    local item = data.slots[slotIndex]
                    if self.query == "" then
                        matches[#matches + 1] = item
                    elseif item and not item.empty and Hit(self.query, item.name) then
                        matches[#matches + 1] = item
                    end
                    slotIndex = slotIndex + 1
                end
            end
            local show = self.query == "" or matches[1]
            if show then
                local header = Acquire(self, "header", MakeHeader)
                header.placeX = 0
                header.placeY = y
                header.placeH = HEADER
                header:SetWidth(math.max(80, width - 20))
                header.title:SetText(section.title)
                Theme.Font(header.title, 14, Theme.GOLD, "OUTLINE")
                if section.id == "warband" then
                    local icon = WarbandIcon()
                    if icon then
                        header.icon:SetTexture(icon)
                    else
                        header.icon:SetTexture("Interface\\Minimap\\Tracking\\Banker")
                    end
                elseif type(data) == "table" and (type(data.icon) == "number" or type(data.icon) == "string") then
                    header.icon:SetTexture(data.icon)
                else
                    header.icon:SetTexture("Interface\\Minimap\\Tracking\\Banker")
                end
                header.icon:SetVertexColor(1, 1, 1)
                if scanned then
                    header.count:SetText((data.filled or 0) .. " / " .. (data.size or 0))
                else
                    header.count:SetText("")
                end
                local opened = self.query ~= "" or IsOpen(self, section.id)
                if opened then
                    header.chevron:SetRotation(0)
                else
                    header.chevron:SetRotation(math.pi)
                end
                local sectionId = section.id
                header.sectionId = sectionId
                header:SetScript("OnClick", function(button)
                    if self.query ~= "" then
                        return
                    end
                    self.open[button.sectionId] = not IsOpen(self, button.sectionId)
                    self:Refresh(self.record, self.query)
                end)
                y = y + HEADER + 4
                if opened and not scanned then
                    local note = Acquire(self, "note", MakeNote)
                    note.text:SetText("Not scanned yet")
                    Theme.Font(note.text, 13, Theme.DIM, "")
                    note:SetWidth(math.max(80, width - 48))
                    note.placeX = 28
                    note.placeY = y
                    note.placeH = 18
                    y = y + 24
                elseif opened and matches[1] then
                    local shown = 1
                    while matches[shown] do
                        local column = (shown - 1) % columns
                        local line = math.floor((shown - 1) / columns)
                        local slot = Acquire(self, "slot", MakeSlot)
                        slot.placeX = column * (SLOT + GAP)
                        slot.placeY = y + (line * (SLOT + GAP))
                        slot.placeH = SLOT
                        FillSlot(slot, matches[shown])
                        shown = shown + 1
                    end
                    local lines = math.floor((shown - 2) / columns) + 1
                    y = y + (lines * (SLOT + GAP)) + 8
                end
            end
            sectionIndex = sectionIndex + 1
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
