--[[
  BMG Unit Frames — high-contrast widgets
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Widgets = UF.Widgets or {}
local W = UF.Widgets

local function Template()
    return UF.Compat and UF.Compat.BackdropTemplate and UF.Compat.BackdropTemplate() or nil
end

function W.Paint(frame, r, g, b, a, br, bg, bb)
    if not frame then
        return
    end
    a = a or 1
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        frame:SetBackdropColor(r, g, b, a)
        frame:SetBackdropBorderColor(br or 1, bg or 1, bb or 1, 1)
        return
    end
    if not frame._ufBg then
        local tex = frame:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints()
        frame._ufBg = tex
    end
    frame._ufBg:SetColorTexture(r, g, b, a)
end

function W.Label(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local ok = fs:SetFont(UF.Theme.FontPath(), size or 13, "")
    if not ok then
        fs:SetFontObject(GameFontHighlight)
    end
    fs:SetTextColor(r or 0.92, g or 0.92, b or 0.92, 1)
    fs:SetJustifyH("LEFT")
    return fs
end

function W.Header(parent, text)
    local fs = W.Label(parent, 13, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    fs:SetText(string.upper(text or ""))
    return fs
end

function W.Tabs(parent, items, width, onPick)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width or 480, 30)
    bar.buttons = {}
    bar.selected = items[1] and items[1].id
    local w = math.floor(((width or 480) - ((#items - 1) * 6)) / #items)
    for i = 1, #items do
        local info = items[i]
        local btn = W.Button(bar, info.label, w, 28)
        btn:SetPoint("LEFT", (i - 1) * (w + 6), 0)
        btn.tabId = info.id
        local function PaintTab(b, active)
            if active then
                W.Paint(b, 0.16, 0.14, 0.06, 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
                b.Label:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
            else
                W.Paint(b, UF.Theme.btn[1], UF.Theme.btn[2], UF.Theme.btn[3], 1, 0.35, 0.35, 0.35)
                b.Label:SetTextColor(0.85, 0.85, 0.85, 1)
            end
        end
        btn:SetScript("OnClick", function()
            bar.selected = info.id
            for j = 1, #bar.buttons do
                PaintTab(bar.buttons[j], bar.buttons[j].tabId == info.id)
            end
            if onPick then
                onPick(info.id, info.label)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            PaintTab(self, bar.selected == self.tabId)
            if GameTooltip then
                GameTooltip:Hide()
            end
        end)
        bar.buttons[#bar.buttons + 1] = btn
    end
    function bar:Select(id)
        for i = 1, #bar.buttons do
            if bar.buttons[i].tabId == id then
                bar.buttons[i]:GetScript("OnClick")(bar.buttons[i])
                return
            end
        end
    end
    if bar.buttons[1] then
        W.Paint(bar.buttons[1], 0.16, 0.14, 0.06, 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
        bar.buttons[1].Label:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
    end
    return bar
end

function W.FontString(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local ok = fs:SetFont(UF.Theme.FontPath(), size or 14, "OUTLINE")
    if not ok then
        fs:SetFontObject(GameFontHighlight)
    end
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    fs:SetJustifyH("LEFT")
    return fs
end

function W.Button(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, Template())
    btn:SetSize(width or 96, height or 32)
    btn:RegisterForClicks("LeftButtonUp")
    W.Paint(btn, UF.Theme.btn[1], UF.Theme.btn[2], UF.Theme.btn[3], 1, 1, 1, 1)
    local fs = W.FontString(btn, 13, 1, 1, 1)
    fs:SetPoint("LEFT", 8, 0)
    fs:SetPoint("RIGHT", -8, 0)
    fs:SetJustifyH("CENTER")
    if fs.SetWordWrap then
        fs:SetWordWrap(false)
    end
    fs:SetText(text or "")
    btn.Label = fs
    btn:SetScript("OnEnter", function(self)
        W.Paint(self, UF.Theme.btnHover[1], UF.Theme.btnHover[2], UF.Theme.btnHover[3], 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
        fs:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
        if self._tip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self._tip, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
            if self._hint then
                GameTooltip:AddLine(self._hint, 0.9, 0.9, 0.9, true)
            end
            GameTooltip:Show()
        end
        if self._speak then
            UF.Speech.Say(self._speak)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        W.Paint(self, UF.Theme.btn[1], UF.Theme.btn[2], UF.Theme.btn[3], 1, 1, 1, 1)
        fs:SetTextColor(1, 1, 1, 1)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    function btn:SetLabel(s)
        fs:SetText(s or "")
    end
    return btn
end

local openDrop

function W.CloseDropdowns()
    if openDrop and openDrop.Close then
        openDrop:Close()
    end
    openDrop = nil
    if W._dropCatcher then
        W._dropCatcher:Hide()
    end
end

local function Catcher()
    if W._dropCatcher then
        return W._dropCatcher
    end
    local catch = CreateFrame("Button", "BMGUnitFramesDropCatcher", UIParent)
    catch:SetAllPoints(UIParent)
    catch:SetFrameStrata("FULLSCREEN_DIALOG")
    catch:SetFrameLevel(1)
    catch:Hide()
    catch:SetScript("OnClick", function()
        W.CloseDropdowns()
    end)
    W._dropCatcher = catch
    return catch
end

function W.Dropdown(parent, title, width, titleWidth)
    local row = CreateFrame("Frame", nil, parent)
    width = width or 486
    titleWidth = titleWidth or math.min(132, math.floor(width * 0.34))
    row:SetSize(width, 32)

    local label = W.FontString(row, 13, 1, 1, 1)
    label:SetPoint("LEFT", 0, 0)
    label:SetWidth(titleWidth)
    if label.SetWordWrap then
        label:SetWordWrap(false)
    end
    label:SetText(title or "")
    row.Title = label

    local btn = CreateFrame("Button", nil, row, Template())
    btn:SetPoint("LEFT", label, "RIGHT", 8, 0)
    btn:SetPoint("RIGHT", 0, 0)
    btn:SetHeight(28)
    btn:RegisterForClicks("LeftButtonUp")
    W.Paint(btn, UF.Theme.btn[1], UF.Theme.btn[2], UF.Theme.btn[3], 1, 1, 1, 1)

    local valueFs = W.FontString(btn, 13, 1, 1, 1)
    valueFs:SetPoint("LEFT", 10, 0)
    valueFs:SetPoint("RIGHT", -22, 0)
    valueFs:SetJustifyH("LEFT")
    if valueFs.SetWordWrap then
        valueFs:SetWordWrap(false)
    end

    local arrow = W.FontString(btn, 12, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    arrow:SetPoint("RIGHT", -8, 0)
    arrow:SetText("v")

    local menu = CreateFrame("Frame", nil, UIParent, Template())
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(20)
    menu:SetClampedToScreen(true)
    menu:Hide()
    W.Paint(menu, 0.04, 0.04, 0.04, 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])

    row.options = {}
    row.value = nil
    row.items = {}
    row._onChange = nil
    row._tip = nil
    row._hint = nil
    row._speakOpen = nil

    local function LabelOf(id)
        for i = 1, #row.options do
            if row.options[i].id == id then
                return row.options[i].label
            end
        end
        return tostring(id or "")
    end

    local function PaintBtn(hover)
        if hover then
            W.Paint(btn, UF.Theme.btnHover[1], UF.Theme.btnHover[2], UF.Theme.btnHover[3], 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
            valueFs:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
        else
            W.Paint(btn, UF.Theme.btn[1], UF.Theme.btn[2], UF.Theme.btn[3], 1, 1, 1, 1)
            valueFs:SetTextColor(1, 1, 1, 1)
        end
    end

    local function PlaceMenu()
        menu:ClearAllPoints()
        local count = #row.options
        local h = (count * 26) + 8
        menu:SetHeight(h)
        menu:SetWidth(math.max(btn:GetWidth() or 160, 240))
        local bottom = btn:GetBottom()
        if bottom and (bottom - h) < 24 then
            menu:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
        else
            menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        end
    end

    local function RefreshItems()
        for i = 1, #row.options do
            local opt = row.options[i]
            local item = row.items[i]
            if not item then
                item = CreateFrame("Button", nil, menu, Template())
                item:SetHeight(26)
                item:RegisterForClicks("LeftButtonUp")
                local fs = W.FontString(item, 13, 1, 1, 1)
                fs:SetPoint("LEFT", 10, 0)
                fs:SetPoint("RIGHT", -10, 0)
                if fs.SetWordWrap then
                    fs:SetWordWrap(false)
                end
                item.Label = fs
                item:SetScript("OnEnter", function(self)
                    W.Paint(self, UF.Theme.btnHover[1], UF.Theme.btnHover[2], UF.Theme.btnHover[3], 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
                    if UF.Speech and UF.Speech.Say then
                        UF.Speech.Say(self._label or "")
                    end
                end)
                item:SetScript("OnLeave", function(self)
                    local selected = self._id == row.value
                    if selected then
                        W.Paint(self, 0.16, 0.14, 0.06, 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
                        self.Label:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
                    else
                        W.Paint(self, 0.08, 0.08, 0.08, 1, 0.45, 0.45, 0.45)
                        self.Label:SetTextColor(1, 1, 1, 1)
                    end
                end)
                item:SetScript("OnClick", function(self)
                    local id = self._id
                    local text = self._label
                    row:Close()
                    if id ~= row.value then
                        row.value = id
                        valueFs:SetText(text or "")
                        if row._onChange then
                            row._onChange(id, text)
                        end
                    elseif UF.Speech and UF.Speech.Say then
                        UF.Speech.Say(text .. " already selected.")
                    end
                end)
                row.items[i] = item
            end
            item._id = opt.id
            item._label = opt.label
            item.Label:SetText(opt.label)
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", 4, -4 - ((i - 1) * 26))
            item:SetPoint("RIGHT", -4, 0)
            item:Show()
            local selected = opt.id == row.value
            if selected then
                W.Paint(item, 0.16, 0.14, 0.06, 1, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
                item.Label:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
            else
                W.Paint(item, 0.08, 0.08, 0.08, 1, 0.45, 0.45, 0.45)
                item.Label:SetTextColor(1, 1, 1, 1)
            end
        end
        for i = #row.options + 1, #row.items do
            row.items[i]:Hide()
        end
    end

    function row:Close()
        menu:Hide()
        if openDrop == row then
            openDrop = nil
        end
        if W._dropCatcher then
            W._dropCatcher:Hide()
        end
        arrow:SetText("v")
    end

    function row:Open()
        if openDrop and openDrop ~= row then
            openDrop:Close()
        end
        RefreshItems()
        PlaceMenu()
        local catch = Catcher()
        catch:SetFrameLevel(1)
        catch:Show()
        menu:Show()
        menu:Raise()
        openDrop = row
        arrow:SetText("^")
        local names = {}
        for i = 1, #row.options do
            names[#names + 1] = row.options[i].label
        end
        if UF.Speech and UF.Speech.Say then
            UF.Speech.Say((row._speakOpen or (title or "Menu")) .. ". " .. table.concat(names, ", ") .. ".")
        end
    end

    function row:Toggle()
        if menu:IsShown() then
            row:Close()
        else
            row:Open()
        end
    end

    function row:SetOptions(opts)
        row.options = opts or {}
        if row.value then
            valueFs:SetText(LabelOf(row.value))
        end
    end

    function row:SetValue(id)
        row.value = id
        valueFs:SetText(LabelOf(id))
        if menu:IsShown() then
            RefreshItems()
        end
    end

    function row:GetValue()
        return row.value
    end

    function row:SetOnChange(fn)
        row._onChange = fn
    end

    btn:SetScript("OnClick", function()
        row:Toggle()
    end)
    btn:SetScript("OnEnter", function()
        PaintBtn(true)
        if row._tip then
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(row._tip, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
            if row._hint then
                GameTooltip:AddLine(row._hint, 0.9, 0.9, 0.9, true)
            end
            GameTooltip:Show()
        end
        if row._speak then
            UF.Speech.Say(row._speak)
        end
    end)
    btn:SetScript("OnLeave", function()
        PaintBtn(false)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)

    row.Button = btn
    row.Menu = menu
    return row
end

function W.Stepper(parent, title, width)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width or 380, 36)
    local label = W.FontString(row, 13, 1, 1, 1)
    label:SetPoint("LEFT", 0, 0)
    label:SetText(title or "")
    row.Title = label
    local plus = W.Button(row, "+", 32, 32)
    plus:SetPoint("RIGHT", 0, 0)
    local value = W.FontString(row, 14, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    value:SetWidth(64)
    value:SetJustifyH("CENTER")
    value:SetPoint("RIGHT", plus, "LEFT", -8, 0)
    local minus = W.Button(row, "-", 32, 32)
    minus:SetPoint("RIGHT", value, "LEFT", -8, 0)
    row.minus = minus
    row.plus = plus
    function row:SetValueText(text)
        value:SetText(text or "")
    end
    return row
end
