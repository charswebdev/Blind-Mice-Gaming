--[[
  AllQuest — high-contrast widgets
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Widgets = AQ.Widgets or {}
local W = AQ.Widgets

function W.ApplyBackdrop(frame, edgeSize)
    if not frame then
        return
    end
    local bg = AQ.Theme.bg
    local border = AQ.Theme.border
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = edgeSize or 2,
        })
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
        return
    end
    if not frame.AQBg then
        local tex = frame:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        tex:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
        frame.AQBg = tex
        local e = edgeSize or 2
        local function Edge(name, p1, p2, w, h)
            local t = frame:CreateTexture(nil, "BORDER")
            t:SetColorTexture(border[1], border[2], border[3], 1)
            t:SetPoint(p1)
            t:SetPoint(p2)
            if w then
                t:SetWidth(w)
            end
            if h then
                t:SetHeight(h)
            end
            frame[name] = t
        end
        Edge("AQEdgeT", "TOPLEFT", "TOPRIGHT", nil, e)
        Edge("AQEdgeB", "BOTTOMLEFT", "BOTTOMRIGHT", nil, e)
        Edge("AQEdgeL", "TOPLEFT", "BOTTOMLEFT", e, nil)
        Edge("AQEdgeR", "TOPRIGHT", "BOTTOMRIGHT", e, nil)
    end
end

function W.FontString(parent, size, r, g, b, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local path = AQ.Theme.FontPath()
    local px = AQ.Theme.FontSize(size or 14)
    local ok = fs:SetFont(path, px, flags or "OUTLINE")
    if not ok then
        fs:SetFontObject(GameFontHighlight)
    end
    if r then
        fs:SetTextColor(r, g or 1, b or 1, 1)
    else
        local t = AQ.Theme.text
        fs:SetTextColor(t[1], t[2], t[3], 1)
    end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

function W.SetFont(fs, size, r, g, b)
    if not fs then
        return
    end
    local path = AQ.Theme.FontPath()
    local px = AQ.Theme.FontSize(size or 14)
    fs:SetFont(path, px, "OUTLINE")
    if r then
        fs:SetTextColor(r, g or 1, b or 1, 1)
    end
end

function W.Button(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 28)
    W.ApplyBackdrop(btn, 2)
    local label = W.FontString(btn, 14)
    local acc = AQ.Theme.accent
    label:SetPoint("CENTER")
    label:SetText(text or "")
    label:SetTextColor(acc[1], acc[2], acc[3], 1)
    btn.Label = label
    btn:SetScript("OnEnter", function(self)
        W.ApplyBackdrop(self, 2)
        if self.SetBackdropColor then
            local on = AQ.Theme.tabOn
            self:SetBackdropColor(on[1], on[2], on[3], on[4] or 0.55)
        end
        if AQ.Speech and AQ.Speech.Hover then
            AQ.Speech.Hover(self.Label and self.Label:GetText() or "")
        end
    end)
    btn:SetScript("OnLeave", function(self)
        W.ApplyBackdrop(self, 2)
        if AQ.Speech and AQ.Speech.HoverClear then
            AQ.Speech.HoverClear()
        end
    end)
    return btn
end

function W.Scroll(parent, name)
    local scroll = CreateFrame("ScrollFrame", name, parent, "UIPanelScrollFrameTemplate")
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(1, 1)
    scroll:SetScrollChild(child)
    scroll.Child = child
    return scroll
end

function W.ApplyTrackerBackdrop(frame)
    if not frame then
        return
    end
    local t = AQ.Theme.Tracker
    local bg = t.bg
    local border = t.border
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
        return
    end
    W.ApplyBackdrop(frame, 1)
    if frame.SetBackdropColor then
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
        frame:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
    end
end

function W.SetTrackerFont(fs, size, r, g, b)
    if not fs then
        return
    end
    local path = AQ.Theme.FontPath()
    local px = AQ.Theme.FontSize(size or 12)
    fs:SetFont(path, px, "OUTLINE")
    if fs.SetShadowColor then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    end
    if r then
        fs:SetTextColor(r, g or 1, b or 1, 1)
    end
end

function W.TrackerFontString(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    W.SetTrackerFont(fs, size, r, g, b)
    if not r then
        local t = AQ.Theme.Tracker.title
        fs:SetTextColor(t[1], t[2], t[3], 1)
    end
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

function W.TrackerButton(parent, text, width, height, fontSize)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 22, height or 18)
    local t = AQ.Theme.Tracker
    local label = W.TrackerFontString(btn, fontSize or 11, t.header[1], t.header[2], t.header[3])
    label:SetPoint("CENTER")
    label:SetText(text or "")
    btn.Label = label
    btn:SetScript("OnEnter", function(self)
        local h = AQ.Theme.Tracker.btnHover
        if self.Label then
            self.Label:SetTextColor(h[1], h[2], h[3], 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local a = AQ.Theme.Tracker.header
        if self.Label then
            self.Label:SetTextColor(a[1], a[2], a[3], 1)
        end
    end)
    return btn
end

function W.TrackerIconButton(parent, texture, width, height, natural)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width or 18, height or 18)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetSize((width or 18) - 2, (height or 18) - 2)
    icon:SetTexture(texture)
    btn.AQNatural = natural and true or false
    if btn.AQNatural then
        icon:SetVertexColor(1, 1, 1, 1)
    else
        local a = AQ.Theme.Tracker.header
        icon:SetVertexColor(a[1], a[2], a[3], 1)
    end
    btn.Icon = icon
    btn:SetScript("OnEnter", function(self)
        if self.Icon then
            if self.AQNatural then
                self.Icon:SetVertexColor(1, 1, 1, 1)
                self.Icon:SetAlpha(1)
            else
                local h = AQ.Theme.Tracker.btnHover
                self.Icon:SetVertexColor(h[1], h[2], h[3], 1)
            end
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.Icon then
            if self.AQNatural then
                self.Icon:SetVertexColor(1, 1, 1, 1)
                self.Icon:SetAlpha(0.92)
            else
                local gold = AQ.Theme.Tracker.header
                self.Icon:SetVertexColor(gold[1], gold[2], gold[3], 1)
            end
        end
    end)
    if btn.AQNatural then
        icon:SetAlpha(0.92)
    end
    return btn
end

--- Gold-on-black media icon with tooltip + TTS. Does not recolor the art.
function W.MediaIconButton(parent, texture, size, tip)
    local btn = CreateFrame("Button", nil, parent)
    local dim = size or 32
    btn:SetSize(dim, dim)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(texture)
    btn.Icon = icon
    btn.AQTip = tip or ""
    local glow = btn:CreateTexture(nil, "OVERLAY")
    glow:SetAllPoints()
    glow:SetColorTexture(1, 0.82, 0, 0.18)
    glow:Hide()
    btn.AQGlow = glow
    btn:SetScript("OnEnter", function(self)
        if self.AQGlow then
            self.AQGlow:Show()
        end
        local text = self.AQTip or ""
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(text)
            GameTooltip:Show()
        end
        if AQ.Speech and AQ.Speech.Hover then
            AQ.Speech.Hover(text)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.AQGlow then
            self.AQGlow:Hide()
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
        if AQ.Speech and AQ.Speech.HoverClear then
            AQ.Speech.HoverClear()
        end
    end)
    return btn
end

local openDrop

function W.CloseDropdown()
    if not openDrop then
        return
    end
    if openDrop.AQMenu then
        openDrop.AQMenu:Hide()
    end
    if openDrop.AQCatcher then
        openDrop.AQCatcher:Hide()
    end
    if openDrop.AQSetOpen then
        openDrop:AQSetOpen(false)
    end
    openDrop = nil
end

local function BoxEdge(parent, r, g, b, thickness)
    thickness = thickness or 2
    local function Edge(p1, p2, w, h)
        local t = parent:CreateTexture(nil, "BORDER")
        t:SetColorTexture(r, g, b, 1)
        t:SetPoint(p1)
        t:SetPoint(p2)
        if w then
            t:SetWidth(w)
        end
        if h then
            t:SetHeight(h)
        end
        return t
    end
    Edge("TOPLEFT", "TOPRIGHT", nil, thickness)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, thickness)
    Edge("TOPLEFT", "BOTTOMLEFT", thickness, nil)
    Edge("TOPRIGHT", "BOTTOMRIGHT", thickness, nil)
end

--- Combo-box / menu button. options.width, options.height, options.fixedLabel
function W.Dropdown(parent, options)
    options = options or {}
    local width = options.width or 240
    local height = options.height or 32
    local gold = AQ.Theme.Tracker.header
    local title = AQ.Theme.Tracker.title

    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    local fill = btn:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(0.08, 0.08, 0.08, 1)
    btn.AQFill = fill
    BoxEdge(btn, gold[1], gold[2], gold[3], 2)

    local well = btn:CreateTexture(nil, "ARTWORK")
    well:SetWidth(28)
    well:SetPoint("TOPRIGHT", -2, -2)
    well:SetPoint("BOTTOMRIGHT", -2, 2)
    well:SetColorTexture(0.22, 0.18, 0.04, 1)
    btn.AQWell = well

    local divider = btn:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(2)
    divider:SetPoint("TOPRIGHT", well, "TOPLEFT", 0, 0)
    divider:SetPoint("BOTTOMRIGHT", well, "BOTTOMLEFT", 0, 0)
    divider:SetColorTexture(gold[1], gold[2], gold[3], 1)

    local arrow = CreateFrame("Frame", nil, btn)
    arrow:SetSize(14, 10)
    arrow:SetPoint("CENTER", well, "CENTER", 0, 0)
    arrow:EnableMouse(false)
    local bars = {}
    local widths = { 12, 8, 4 }
    for i = 1, 3 do
        local bar = arrow:CreateTexture(nil, "OVERLAY")
        bar:SetColorTexture(gold[1], gold[2], gold[3], 1)
        bar:SetSize(widths[i], 2)
        bars[i] = bar
    end
    btn.AQArrow = arrow
    btn.AQArrowBars = bars
    btn.AQArrowWidths = widths

    local label = W.TrackerFontString(btn, 13, title[1], title[2], title[3])
    label:SetPoint("LEFT", 10, 0)
    label:SetPoint("RIGHT", well, "LEFT", -8, 0)
    label:SetJustifyH("LEFT")
    if options.fixedLabel then
        label:SetText(options.fixedLabel)
    else
        label:SetText(options.placeholder or "Select")
    end
    btn.AQLabel = label
    btn.AQFixedLabel = options.fixedLabel
    btn.AQItems = {}
    btn.AQValue = nil

    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:Hide()
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:SetFrameLevel(90)
    catcher:EnableMouse(true)
    catcher:RegisterForClicks("AnyUp")
    btn.AQCatcher = catcher

    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:Hide()
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(100)
    menu:EnableMouse(true)
    local menuFill = menu:CreateTexture(nil, "BACKGROUND")
    menuFill:SetAllPoints()
    menuFill:SetColorTexture(0.05, 0.05, 0.05, 1)
    BoxEdge(menu, gold[1], gold[2], gold[3], 2)
    btn.AQMenu = menu
    btn.AQMenuRows = {}

    function btn:AQSetOpen(open)
        if open then
            self.AQFill:SetColorTexture(0.16, 0.14, 0.05, 1)
            self.AQWell:SetColorTexture(0.42, 0.34, 0.06, 1)
        else
            self.AQFill:SetColorTexture(0.08, 0.08, 0.08, 1)
            self.AQWell:SetColorTexture(0.22, 0.18, 0.04, 1)
        end
        local bars = self.AQArrowBars
        local widths = self.AQArrowWidths
        for i = 1, #bars do
            local bar = bars[i]
            local idx = open and (#bars + 1 - i) or i
            bar:ClearAllPoints()
            bar:SetWidth(widths[idx])
            bar:SetPoint("TOP", self.AQArrow, "TOP", 0, -((i - 1) * 3))
        end
    end
    btn:AQSetOpen(false)

    local function HideMenu()
        if openDrop == btn then
            W.CloseDropdown()
        else
            menu:Hide()
            catcher:Hide()
            btn:AQSetOpen(false)
        end
    end

    local function RebuildMenu()
        local items = btn.AQItems or {}
        local y = -4
        local rowH = 26
        local count = 0
        for i = 1, #btn.AQMenuRows do
            btn.AQMenuRows[i]:Hide()
        end
        for i = 1, #items do
            local item = items[i]
            local row = btn.AQMenuRows[i]
            if not row then
                row = CreateFrame("Button", nil, menu)
                row:SetHeight(rowH)
                local hover = row:CreateTexture(nil, "BACKGROUND")
                hover:SetAllPoints()
                hover:Hide()
                row.Hover = hover
                local mark = W.TrackerFontString(row, 13, gold[1], gold[2], gold[3])
                mark:SetPoint("LEFT", 8, 0)
                mark:SetWidth(14)
                mark:SetText("")
                row.Mark = mark
                local fs = W.TrackerFontString(row, 13, title[1], title[2], title[3])
                fs:SetPoint("LEFT", 26, 0)
                fs:SetPoint("RIGHT", -10, 0)
                row.Text = fs
                row:SetScript("OnEnter", function(self)
                    if not self.AQDisabled then
                        local h = AQ.Theme.Tracker.hover
                        self.Hover:SetColorTexture(h[1], h[2], h[3], 0.35)
                        self.Hover:Show()
                    end
                    if AQ.Speech and AQ.Speech.Hover then
                        AQ.Speech.Hover(self.AQSpeak or "")
                    end
                end)
                row:SetScript("OnLeave", function(self)
                    self.Hover:Hide()
                    if AQ.Speech and AQ.Speech.HoverClear then
                        AQ.Speech.HoverClear()
                    end
                end)
                btn.AQMenuRows[i] = row
            end
            row:Show()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 4, y)
            row:SetPoint("TOPRIGHT", -4, y)
            row.AQDisabled = item.disabled and true or false
            row.Text:SetText(item.text or tostring(item.value or ""))
            local speak = item.text or tostring(item.value or "")
            if item.disabled then
                speak = speak .. ". unavailable"
            end
            row.AQSpeak = speak
            if item.disabled then
                row.Text:SetTextColor(0.45, 0.45, 0.45, 1)
                row.Mark:SetText("")
            else
                row.Text:SetTextColor(title[1], title[2], title[3], 1)
                if btn.AQValue ~= nil and item.value == btn.AQValue then
                    row.Mark:SetText(">")
                else
                    row.Mark:SetText("")
                end
            end
            row:SetScript("OnClick", function()
                if item.disabled then
                    return
                end
                HideMenu()
                if not btn.AQFixedLabel then
                    btn:SetValue(item.value)
                end
                if type(btn.AQCallback) == "function" then
                    btn.AQCallback(item.value, item)
                end
            end)
            y = y - rowH
            count = count + 1
        end
        menu:SetWidth(math.max(width, 160))
        menu:SetHeight(math.max(8 + count * rowH, 36))
    end

    function btn:SetItems(items)
        self.AQItems = items or {}
        if self.AQMenu:IsShown() then
            RebuildMenu()
        end
    end

    function btn:SetValue(value)
        self.AQValue = value
        if not self.AQFixedLabel then
            local shown = tostring(value or "")
            local items = self.AQItems or {}
            for i = 1, #items do
                if items[i].value == value then
                    shown = items[i].text or shown
                    break
                end
            end
            self.AQLabel:SetText(shown)
        end
    end

    function btn:SetCallback(fn)
        self.AQCallback = fn
    end

    function btn:ToggleMenu()
        if openDrop == self and self.AQMenu:IsShown() then
            HideMenu()
            return
        end
        W.CloseDropdown()
        RebuildMenu()
        self.AQMenu:ClearAllPoints()
        self.AQMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        self.AQMenu:Show()
        self.AQCatcher:Show()
        self:AQSetOpen(true)
        openDrop = self
    end

    catcher:SetScript("OnClick", function()
        HideMenu()
    end)

    btn:SetScript("OnClick", function(self)
        self:ToggleMenu()
    end)
    btn:SetScript("OnEnter", function(self)
        if openDrop ~= self then
            self.AQFill:SetColorTexture(0.14, 0.12, 0.04, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if openDrop ~= self then
            self.AQFill:SetColorTexture(0.08, 0.08, 0.08, 1)
        end
    end)

    return btn
end

function W.HideScrollBar(scroll)
    if not scroll then
        return
    end
    local sb = scroll.ScrollBar
    if not sb and scroll.GetName then
        sb = _G[scroll:GetName() .. "ScrollBar"]
    end
    if sb then
        sb:SetAlpha(0)
        sb:SetWidth(1)
        sb:Hide()
        sb:SetScript("OnShow", sb.Hide)
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = 0
        if self.GetVerticalScrollRange then
            max = self:GetVerticalScrollRange() or 0
        end
        local nextY = cur - (delta * 28)
        if nextY < 0 then
            nextY = 0
        end
        if nextY > max then
            nextY = max
        end
        self:SetVerticalScroll(nextY)
    end)
end
