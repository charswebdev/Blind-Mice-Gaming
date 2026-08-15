local addon = Exploration

addon.theme = {
    title       = { 0.92, 0.78, 0.32 },
    subtitle    = { 0.55, 0.52, 0.48 },
    accent      = { 0.95, 0.78, 0.22 },
    breadcrumb  = { 0.45, 0.82, 0.92 },
    panel       = { 0.06, 0.06, 0.08, 0.92 },
    rowBg       = { 0.11, 0.11, 0.14, 0.75 },
    rowActive   = { 0.16, 0.20, 0.28, 0.90 },
    rowHover    = { 0.22, 0.24, 0.30, 0.35 },
    text        = { 0.88, 0.86, 0.82 },
    textDim     = { 0.48, 0.46, 0.44 },
    textDone    = { 0.40, 0.80, 0.40 },
    textActive  = { 0.98, 0.92, 0.62 },
    progress    = { 0.92, 0.74, 0.18 },
    progressBg  = { 0.05, 0.05, 0.07, 0.90 },
    tabBg       = { 0.10, 0.10, 0.13, 0.85 },
    tabActive   = { 0.16, 0.16, 0.20, 0.95 },
    tabBorder   = { 0.38, 0.32, 0.18, 0.70 },
    btnBg       = { 0.10, 0.18, 0.30, 0.98 },
    btnBgHover  = { 0.14, 0.24, 0.38, 0.98 },
    btnHover    = { 0.20, 0.32, 0.48, 0.35 },
    btnDisabled = { 0.08, 0.12, 0.18, 0.70 },
    rule        = { 0.28, 0.26, 0.22, 0.55 },
}

local T = addon.theme

function addon:ColorTexture(tex, color)
    if tex and tex.SetColorTexture then
        tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    end
end

local function tintFrameTextures(frame, r, g, b)
    if not frame then return end
    if frame.SetVertexColor then
        frame:SetVertexColor(r, g, b)
    end
    if frame.GetNumRegions then
        for i = 1, frame:GetNumRegions() do
            local region = select(i, frame:GetRegions())
            if region and region.SetVertexColor and region ~= frame then
                region:SetVertexColor(r, g, b)
            end
        end
    end
end

function addon:ApplyTheme(frame)
    if frame.TitleText then
        frame.TitleText:SetText("Exploration")
        frame.TitleText:SetTextColor(T.title[1], T.title[2], T.title[3])
    end

    tintFrameTextures(frame.Bg, 0.07, 0.07, 0.09)
    tintFrameTextures(frame.TitleBg, 0.05, 0.05, 0.07)
    tintFrameTextures(frame.TopTileStreaks, 0.09, 0.09, 0.11)
    tintFrameTextures(frame.BotLeftCorner, 0.07, 0.07, 0.09)
    tintFrameTextures(frame.BotRightCorner, 0.07, 0.07, 0.09)
    tintFrameTextures(frame.TopLeftCorner, 0.07, 0.07, 0.09)
    tintFrameTextures(frame.TopRightCorner, 0.07, 0.07, 0.09)
    tintFrameTextures(frame.LeftBorder, 0.07, 0.07, 0.09)
    tintFrameTextures(frame.RightBorder, 0.07, 0.07, 0.09)
    tintFrameTextures(frame.BottomBorder, 0.07, 0.07, 0.09)

    local inset = frame.Inset
    if inset then
        tintFrameTextures(inset.Bg, 0.04, 0.04, 0.06)
        tintFrameTextures(inset.BorderTopLeft, 0.22, 0.20, 0.14)
        tintFrameTextures(inset.BorderTopRight, 0.22, 0.20, 0.14)
        tintFrameTextures(inset.BorderBottomLeft, 0.22, 0.20, 0.14)
        tintFrameTextures(inset.BorderBottomRight, 0.22, 0.20, 0.14)
        tintFrameTextures(inset.BorderBottom, 0.22, 0.20, 0.14)
        tintFrameTextures(inset.BorderLeft, 0.22, 0.20, 0.14)
        tintFrameTextures(inset.BorderRight, 0.22, 0.20, 0.14)
        -- Top border sits on the title band and cuts through title/icon.
        if inset.BorderTop then
            inset.BorderTop:Hide()
        end
    end

    if frame.TopLeftCorner then
        frame.TopLeftCorner:Hide()
    end

    if frame.Content and not frame.Content._darkBg then
        local bg = frame.Content:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetAllPoints(frame.Content)
        addon:ColorTexture(bg, T.panel)
        frame.Content._darkBg = bg
    end
end

function addon:StyleFont(fs, kind)
    local c = T.text
    if kind == "title" or kind == "accent" then c = T.accent
    elseif kind == "subtitle" or kind == "dim" then c = T.textDim
    elseif kind == "done" then c = T.textDone
    elseif kind == "active" or kind == "hi" then c = T.textActive
    elseif kind == "crumb" then c = T.breadcrumb end
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
end

function addon:StyleFontString(fs, kind)
    addon:StyleFont(fs, kind)
end

function addon:StyleButtonVisual(btn, enabled, hovered)
    if enabled == nil then enabled = btn:IsEnabled() end
    if enabled then
        addon:ColorTexture(btn.bg, hovered and T.btnBgHover or T.btnBg)
        addon:StyleFont(btn.label, hovered and "active" or "accent")
    else
        addon:ColorTexture(btn.bg, T.btnDisabled)
        addon:StyleFont(btn.label, "dim")
    end
end

function addon:CreateButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn)
    btn.highlight:SetBlendMode("ADD")
    addon:ColorTexture(btn.highlight, T.btnHover)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("CENTER")
    btn.label:SetText(text or "")
    addon:StyleFont(btn.label, "accent")

    function btn:SetText(t)
        self.label:SetText(t or "")
    end

    function btn:GetTextWidth()
        return self.label:GetStringWidth() or 0
    end

    btn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then addon:StyleButtonVisual(self, true, true) end
    end)
    btn:SetScript("OnLeave", function(self)
        addon:StyleButtonVisual(self)
    end)

    local baseEnable, baseDisable = btn.Enable, btn.Disable
    btn.Enable = function(self)
        baseEnable(self)
        addon:StyleButtonVisual(self, true)
    end
    btn.Disable = function(self)
        baseDisable(self)
        addon:StyleButtonVisual(self, false)
    end

    addon:StyleButtonVisual(btn, true)
    return btn
end

--- Same look as CreateButton, but inherits SecureActionButtonTemplate for macros / housing teleport.
function addon:CreateSecureActionButton(parent, width, height, text)
    local btn = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    btn:SetSize(width, height)

    -- Hide Blizzard's default label so it doesn't stack on our themed label.
    -- Set*FontObject(nil) is invalid on retail; clear the stock string instead.
    local stock = btn.Text or btn:GetFontString()
    if stock then
        stock:SetText("")
        stock:Hide()
    end

    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints(btn)

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints(btn)
    btn.highlight:SetBlendMode("ADD")
    addon:ColorTexture(btn.highlight, T.btnHover)

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.label:SetJustifyH("CENTER")
    btn.label:SetText(text or "")
    addon:StyleFont(btn.label, "accent")

    function btn:SetText(t)
        if self.Text then
            self.Text:SetText("")
            self.Text:Hide()
        end
        local fs = self:GetFontString()
        if fs and fs ~= self.label then
            fs:SetText("")
            fs:Hide()
        end
        self.label:SetText(t or "")
    end

    function btn:GetTextWidth()
        return self.label:GetStringWidth() or 0
    end

    btn:SetScript("OnEnter", function(self)
        if self:IsEnabled() then addon:StyleButtonVisual(self, true, true) end
    end)
    btn:SetScript("OnLeave", function(self)
        addon:StyleButtonVisual(self)
    end)

    local baseEnable, baseDisable = btn.Enable, btn.Disable
    btn.Enable = function(self)
        baseEnable(self)
        addon:StyleButtonVisual(self, true)
    end
    btn.Disable = function(self)
        baseDisable(self)
        addon:StyleButtonVisual(self, false)
    end

    addon:StyleButtonVisual(btn, true)
    return btn
end

function addon:StylePanelButton(btn)
    if btn.label then
        addon:StyleButtonVisual(btn)
        return
    end
    btn:SetNormalFontObject("GameFontNormalSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    btn:SetDisabledFontObject("GameFontDisableSmall")
end

function addon:CreateTitleCompass(frame)
    if frame._compassIcon then
        return frame._compassIcon
    end

    local L = addon.uiLayout
    local iconSize = L.iconSize or 44

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(L.titleH or 26)
    header:SetFrameLevel(frame:GetFrameLevel() + 100)
    header:SetClipsChildren(false)
    header:EnableMouse(false)
    frame._headerOverlay = header

    local holder = CreateFrame("Frame", nil, header)
    holder:SetSize(iconSize, iconSize)
    holder:SetPoint("TOPLEFT", header, "TOPLEFT", 8, -4)
    holder:SetClipsChildren(false)
    frame._compassHolder = holder

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\Exploration\\Textures\\compass.tga")
    icon:SetSize(iconSize, iconSize)
    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetPoint("CENTER", holder, "CENTER", 0, 0)
    frame._compassIcon = icon

    if frame.TitleText then
        frame.TitleText:ClearAllPoints()
        frame.TitleText:SetPoint("CENTER", header, "CENTER", 0, 0)
        frame.TitleText:SetJustifyH("CENTER")
        if frame.TitleText.SetDrawLayer then
            frame.TitleText:SetDrawLayer("OVERLAY", 7)
        end
    end

    return icon
end

function addon:CreateRow(parent, width, height)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, height)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    addon:ColorTexture(row.bg, T.rowBg)
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints(row)
    row.highlight:SetBlendMode("ADD")
    addon:ColorTexture(row.highlight, T.rowHover)
    return row
end

function addon:CreateProgressBar(parent, width, label)
    local bar = CreateFrame("StatusBar", nil, parent)
    if width and width > 0 then
        bar:SetSize(width, 14)
    else
        bar:SetHeight(14)
    end
    bar:EnableMouse(false)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(T.progress[1], T.progress[2], T.progress[3])
    bar:SetMinMaxValues(0, 1)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)
    addon:ColorTexture(bar.bg, T.progressBg)
    bar.kind = label or ""

    local function styleCaption(fs)
        fs:SetTextColor(0.98, 0.96, 0.90, 1)
        if fs.SetShadowColor then
            fs:SetShadowColor(0, 0, 0, 0.95)
            fs:SetShadowOffset(1, -1)
        end
        fs:SetWordWrap(false)
        fs:SetMaxLines(1)
    end

    -- Label left, count right — never stacked on the same pixels.
    bar.label = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.label:SetPoint("LEFT", bar, "LEFT", 6, 0)
    bar.label:SetJustifyH("LEFT")
    bar.label:SetText(bar.kind)
    styleCaption(bar.label)

    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    bar.text:SetJustifyH("RIGHT")
    styleCaption(bar.text)
    return bar
end

function addon:SetProgressBarText(bar, done, total)
    if not bar then return end
    if bar.label then
        bar.label:SetText(bar.kind or "")
    end
    if bar.text then
        if total and total > 0 then
            bar.text:SetText(string.format("%d/%d", done or 0, total))
        else
            bar.text:SetText("")
        end
    end
end

function addon:HRule(parent, y, inset)
    inset = inset or 0
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, y)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, y)
    addon:ColorTexture(line, T.rule)
    return line
end

function addon:CreateDivider(parent, y, inset)
    return addon:HRule(parent, y, inset)
end

function addon:CreateDarkRow(parent, w, h)
    return addon:CreateRow(parent, w, h)
end

function addon:CreateListRow(parent, w, h)
    return addon:CreateRow(parent, w, h)
end

function addon:FillPanel() end
function addon:ApplyShell() end
function addon:ApplyBackdrop() end
