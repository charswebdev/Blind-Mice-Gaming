local _, BMGAM = ...

BMGAM.Gear = BMGAM.Gear or {}
local Gear = BMGAM.Gear
local Theme = BMGAM.Theme

local LEFT = {
    { slot = 1, key = "INVTYPE_HEAD", fallback = "Head" },
    { slot = 2, key = "INVTYPE_NECK", fallback = "Neck" },
    { slot = 3, key = "INVTYPE_SHOULDER", fallback = "Shoulder" },
    { slot = 15, key = "INVTYPE_CLOAK", fallback = "Back" },
    { slot = 5, key = "INVTYPE_CHEST", fallback = "Chest" },
    { slot = 9, key = "INVTYPE_WRIST", fallback = "Wrist" },
    { slot = 10, key = "INVTYPE_HAND", fallback = "Hands" },
    { slot = 6, key = "INVTYPE_WAIST", fallback = "Waist" },
    { slot = 16, key = "INVTYPE_WEAPONMAINHAND", fallback = "Main hand" },
}

local RIGHT = {
    { slot = 7, key = "INVTYPE_LEGS", fallback = "Legs" },
    { slot = 8, key = "INVTYPE_FEET", fallback = "Feet" },
    { slot = 11, key = "INVTYPE_FINGER", fallback = "Finger" },
    { slot = 13, key = "INVTYPE_TRINKET", fallback = "Trinket" },
    { slot = 4, key = "INVTYPE_BODY", fallback = "Shirt" },
    { slot = 19, key = "INVTYPE_TABARD", fallback = "Tabard" },
    { slot = 12, key = "INVTYPE_FINGER", fallback = "Finger" },
    { slot = 14, key = "INVTYPE_TRINKET", fallback = "Trinket" },
    { slot = 17, key = "INVTYPE_WEAPONOFFHAND", fallback = "Off hand" },
}

local GREEN = { Theme.RGB(80, 210, 90) }
local RED = { Theme.RGB(220, 50, 50) }
local ROW_H = 118
local GAP = 8
local TEXT_X = 46

local function SlotName(info)
    local text = _G[info.key]
    if type(text) == "string" and text ~= "" then
        return text
    end
    return info.fallback
end

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

local function Hex(r, g, b)
    return string.format("%02x%02x%02x", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
end

local function GearItem(gear, slot)
    if not gear then
        return nil
    end
    return gear[slot] or gear[tostring(slot)]
end

local function ShownHeight(fontString)
    local textOk, text = pcall(fontString.GetText, fontString)
    if not textOk or type(text) ~= "string" or text == "" then
        fontString.savedHeight = nil
        return 0
    end
    local ok, height = pcall(fontString.GetStringHeight, fontString)
    if ok and type(height) == "number" and height > 1 then
        fontString.savedHeight = height
        return height
    end
    if type(fontString.savedHeight) == "number" and fontString.savedHeight > 1 then
        return fontString.savedHeight
    end
    return 16
end

local function FitRow(row, textWidth)
    row.enchant:SetWidth(textWidth)
    row.gem:SetWidth(textWidth)
    local enchantHeight = ShownHeight(row.enchant)
    local gemTop = 76
    if enchantHeight > 0 then
        gemTop = 76 + enchantHeight + 4
    end
    row.gem:ClearAllPoints()
    row.gem:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -gemTop)
    local gemHeight = ShownHeight(row.gem)
    local height = ROW_H
    if gemHeight > 0 then
        height = gemTop + gemHeight + 8
    elseif enchantHeight > 0 then
        height = 76 + enchantHeight + 8
    end
    if height < ROW_H then
        height = ROW_H
    end
    row:SetHeight(height)
    return height
end

local function PaintBar(row, current, maximum)
    local percent = 0
    if maximum and maximum > 0 then
        percent = current / maximum
    end
    if percent < 0 then
        percent = 0
    end
    if percent > 1 then
        percent = 1
    end
    local color = GREEN
    if percent < 0.25 then
        color = RED
    elseif percent < 0.60 then
        color = Theme.GOLD
    end
    local shown = math.floor((percent * 100) + 0.5)
    local text = shown .. "%"
    if current == 0 then
        text = string.format("0%%  0 / %d", maximum)
    end
    row.bar:Show()
    row.fill:Show()
    row.percent:Show()
    row.bar:SetVertexColor(0.15, 0.12, 0.1, 1)
    row.fill:SetVertexColor(color[1], color[2], color[3], 1)
    local width = math.floor(64 * percent)
    if width < 4 then
        width = 4
    end
    row.fill:SetWidth(width)
    row.percent:SetText(text)
    Theme.Font(row.percent, 12, color, "OUTLINE")
end

local function EnchantLine(item)
    local name = item.enchantName
    if item.enchantName == "cannot" then
        return "Enchant: Cannot be enchanted", Theme.DIM
    end
    if name == "not-enchanted" then
        return "Enchant: Not enchanted", Theme.GOLD
    end
    if name and name ~= "" then
        return "Enchant: " .. name, Theme.CREAM
    end
    return "Enchant: Not enchanted", Theme.GOLD
end

local function GemLine(item)
    if not item.sockets or not item.sockets[1] then
        return "Gem Slot: No gem slot", false
    end
    local bits = {}
    local index = 1
    while item.sockets[index] do
        local socket = item.sockets[index]
        if socket.empty then
            bits[#bits + 1] = "|cffffec40Gem Slot: Empty socket|r"
        else
            local r, g, b = QualityRGB(socket.quality or 1)
            local name = socket.name or ""
            bits[#bits + 1] = string.format("|cff%sGem Slot: %s|r", Hex(r, g, b), name)
        end
        index = index + 1
    end
    return table.concat(bits, "   "), true
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_H)
    row.header = row:CreateFontString(nil, "OVERLAY")
    row.header:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.header:SetJustifyH("LEFT")
    Theme.Font(row.header, 13, Theme.GOLD, "OUTLINE")
    row.iconPlate = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconPlate:SetSize(36, 36)
    row.iconPlate:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -22)
    Theme.Paint(row.iconPlate, Theme.PANEL, Theme.GOLD_DIM)
    row.icon = row.iconPlate:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -22)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetWidth(220)
    Theme.Font(row.name, 12, Theme.CREAM, "OUTLINE")
    row.track = row:CreateFontString(nil, "OVERLAY")
    row.track:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -40)
    row.track:SetJustifyH("LEFT")
    Theme.Font(row.track, 12, Theme.CREAM, "")
    row.duraLabel = row:CreateFontString(nil, "OVERLAY")
    row.duraLabel:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -58)
    Theme.Font(row.duraLabel, 12, Theme.YELLOW, "OUTLINE")
    row.duraLabel:SetText("Durability")
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetSize(64, 8)
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X + 78, -62)
    row.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.fill = row:CreateTexture(nil, "OVERLAY")
    row.fill:SetHeight(8)
    row.fill:SetPoint("LEFT", row.bar, "LEFT", 0, 0)
    row.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    row.percent = row:CreateFontString(nil, "OVERLAY")
    row.percent:SetPoint("LEFT", row.bar, "RIGHT", 6, 0)
    row.percent:SetJustifyH("LEFT")
    Theme.Font(row.percent, 12, Theme.CREAM, "OUTLINE")
    row.enchant = row:CreateFontString(nil, "OVERLAY")
    row.enchant:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -76)
    row.enchant:SetJustifyH("LEFT")
    row.enchant:SetWordWrap(true)
    Theme.Font(row.enchant, 12, Theme.CREAM, "")
    row.gem = row:CreateFontString(nil, "OVERLAY")
    row.gem:SetPoint("TOPLEFT", row, "TOPLEFT", TEXT_X, -94)
    row.gem:SetJustifyH("LEFT")
    row.gem:SetWordWrap(true)
    Theme.Font(row.gem, 12, Theme.DIM, "")
    row.left = row.header
    row.right = row.name
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        if not self.link or self.link == "" then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        if ok then
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.gear and self.gear.ScrollBy then
            self.gear:ScrollBy(delta)
        end
    end)
    return row
end

local function HideDetails(row)
    row.track:SetText("")
    row.duraLabel:Hide()
    row.bar:Hide()
    row.fill:Hide()
    row.percent:Hide()
    row.enchant:SetText("")
    row.enchant:Hide()
    row.gem:SetText("")
    row.gem:Hide()
end

local function ShowEmpty(row, label, message)
    row.link = nil
    row.icon:SetTexture(nil)
    Theme.Paint(row.iconPlate, Theme.PANEL, Theme.GOLD_DIM)
    row.header:SetText(label)
    row.name:SetText(message)
    Theme.Font(row.name, 12, Theme.DIM, "")
    HideDetails(row)
end

local function WornEnchant(item)
    if not item or not item.slot or not item.link or not GetInventoryItemLink or not BMGAM.Scan or not BMGAM.Scan.EnchantText then
        return nil
    end
    local ok, worn = pcall(GetInventoryItemLink, "player", item.slot)
    if not ok or type(worn) ~= "string" or worn ~= item.link then
        return nil
    end
    return BMGAM.Scan.EnchantText(item.slot)
end

local function ShowItem(row, label, item)
    row.link = item.link
    row.header:SetText(label)
    row.name:SetText(item.name or "")
    local r, g, b = QualityRGB(item.quality, item.link)
    row.name:SetTextColor(r, g, b, 1)
    PaintQuality(row.iconPlate, Theme.PANEL, r, g, b)
    if type(item.icon) == "number" or type(item.icon) == "string" then
        row.icon:SetTexture(item.icon)
    else
        row.icon:SetTexture(nil)
    end
    row.track:SetText(item.upgrade or "")
    Theme.Font(row.track, 12, Theme.CREAM, "")
    row.duraLabel:Show()
    if item.durabilityMax and item.durabilityMax > 0 then
        PaintBar(row, item.durabilityCurrent or 0, item.durabilityMax)
    else
        row.bar:Hide()
        row.fill:Hide()
        row.percent:Show()
        row.percent:ClearAllPoints()
        row.percent:SetPoint("LEFT", row.duraLabel, "RIGHT", 8, 0)
        row.percent:SetText("No durability")
        Theme.Font(row.percent, 12, Theme.DIM, "")
    end
    if item.durabilityMax and item.durabilityMax > 0 then
        row.percent:ClearAllPoints()
        row.percent:SetPoint("LEFT", row.bar, "RIGHT", 6, 0)
    end
    local live = WornEnchant(item)
    if live == "not-enchanted" or (live and live ~= "") then
        item.enchantName = live
    end
    local enchant, enchantColor = EnchantLine(item)
    row.enchant:Show()
    row.enchant:SetText(enchant)
    Theme.Font(row.enchant, 12, enchantColor, "")
    local gem, coded = GemLine(item)
    row.gem:Show()
    row.gem:SetText(gem)
    if coded then
        row.gem:SetTextColor(1, 1, 1, 1)
    else
        Theme.Font(row.gem, 12, Theme.DIM, "")
    end
end

local function Fill(row, info, gear)
    local label = SlotName(info)
    if not gear then
        ShowEmpty(row, label, "Not scanned yet")
        return
    end
    local item = GearItem(gear, info.slot)
    if not item or item.empty then
        ShowEmpty(row, label, "Empty Slot")
        return
    end
    ShowItem(row, label, item)
end

function Gear.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.offset = 0
    frame.left = {}
    frame.right = {}
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)

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

    local index = 1
    while LEFT[index] do
        local row = MakeRow(frame)
        row.gear = frame
        row.header:SetText(SlotName(LEFT[index]))
        frame.left[index] = row
        local other = MakeRow(frame)
        other.gear = frame
        other.header:SetText(SlotName(RIGHT[index]))
        frame.right[index] = other
        index = index + 1
    end

    function frame:ViewSize()
        local width = 0
        local height = 0
        local okW, w = pcall(self.GetWidth, self)
        local okH, h = pcall(self.GetHeight, self)
        if okW and type(w) == "number" then
            local compared, wide = pcall(function()
                return w >= 80
            end)
            if compared and wide then
                width = w
            end
        end
        if okH and type(h) == "number" then
            local compared, tall = pcall(function()
                return h >= 80
            end)
            if compared and tall then
                height = h
            end
        end
        if width < 80 then
            width = 640
        end
        if height < 80 then
            height = 480
        end
        local column = math.floor((width - 28) / 2)
        if column < 160 then
            column = 160
        end
        return width, height, column
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
        local _, height, column = self:ViewSize()
        local textWidth = math.max(40, column - TEXT_X - 8)
        local index = 1
        local content = 0
        while self.left[index] do
            local row = self.left[index]
            local right = self.right[index]
            row:SetWidth(column)
            right:SetWidth(column)
            row.header:SetWidth(column - 4)
            right.header:SetWidth(column - 4)
            row.name:SetWidth(textWidth)
            right.name:SetWidth(textWidth)
            row.track:SetWidth(textWidth)
            right.track:SetWidth(textWidth)
            row:Show()
            right:Show()
            local leftHeight = FitRow(row, textWidth)
            local rightHeight = FitRow(right, textWidth)
            local rowHeight = leftHeight
            if rightHeight > rowHeight then
                rowHeight = rightHeight
            end
            local y = -content + (self.offset or 0)
            local onPage = y < 4 and y > -(height + 4)
            if onPage then
                row:ClearAllPoints()
                right:ClearAllPoints()
                row:SetPoint("TOPLEFT", self, "TOPLEFT", 4, y)
                right:SetPoint("TOPLEFT", self, "TOPLEFT", column + 8, y)
            else
                row:Hide()
                right:Hide()
            end
            content = content + rowHeight + GAP
            index = index + 1
        end
        self.contentHeight = content
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
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
        local offset = (self.offset or 0) - (delta * (ROW_H + GAP))
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
    frame:SetScript("OnMouseWheel", function(self, delta)
        self:ScrollBy(delta)
    end)

    function frame:Refresh(record)
        self.record = record
        local gear = record and record.gear
        local index = 1
        while self.left[index] do
            local filled, err = pcall(Fill, self.left[index], LEFT[index], gear)
            if not filled then
                ShowEmpty(self.left[index], SlotName(LEFT[index]), tostring(err))
            end
            local otherFilled, otherErr = pcall(Fill, self.right[index], RIGHT[index], gear)
            if not otherFilled then
                ShowEmpty(self.right[index], SlotName(RIGHT[index]), tostring(otherErr))
            end
            index = index + 1
        end
        self:Place()
    end

    frame:Place()
    return frame
end
