local _, ns = ...

ns.Theme = {
    colors = {
        bg = { 0.08, 0.08, 0.10, 0.95 },
        panel = { 0.12, 0.12, 0.15, 1.0 },
        border = { 0.25, 0.25, 0.30, 1.0 },
        text = { 0.98, 0.98, 0.98, 1.0 },
        textMuted = { 0.82, 0.84, 0.88, 1.0 },
        accent = { 1.00, 0.82, 0.00, 1.0 },
        active = { 0.35, 0.75, 1.00, 1.0 },
        tabBar = { 0.10, 0.10, 0.12, 1.0 },
        tabActiveBg = { 0.17, 0.17, 0.21, 1.0 },
        tabActiveText = { 0.98, 0.98, 0.98, 1.0 },
        tabInactiveBg = { 0.12, 0.12, 0.15, 0.0 },
        tabInactiveText = { 0.62, 0.64, 0.68, 1.0 },
        tabHoverBg = { 0.15, 0.15, 0.18, 1.0 },
        tabHoverText = { 0.88, 0.89, 0.92, 1.0 },
        button = { 0.18, 0.18, 0.22, 1.0 },
        buttonHover = { 0.24, 0.24, 0.30, 1.0 },
        danger = { 0.85, 0.25, 0.25, 1.0 },
        card = { 0.14, 0.14, 0.17, 1.0 },
        cardHover = { 0.17, 0.17, 0.21, 1.0 },
        sectionHeader = { 0.55, 0.57, 0.62, 1.0 },
        success = { 0.45, 0.82, 0.55, 1.0 },
        royal = { 0.16, 0.28, 0.72, 1.0 },
        royalHover = { 0.22, 0.38, 0.88, 1.0 },
        gold = { 1.00, 0.84, 0.00, 1.0 },
        notice = { 0.35, 0.75, 1.00, 1.0 },
    },
    fonts = {
        header = GameFontNormalLarge,
        body = GameFontHighlight,
        small = GameFontHighlightSmall,
    },
}

local function ensureBackdrop(frame)
    if frame and not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
end

local BACKDROP_FLAT = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function ns.Theme:SetTextColor(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function ns.Theme:SetReadableFont(fontString, size)
    if size and size >= 16 then
        fontString:SetFontObject("GameFontNormalLarge")
    else
        fontString:SetFontObject("GameFontNormal")
    end
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 0.9)
end

function ns.Theme:ApplyBackdrop(frame)
    ensureBackdrop(frame)
    frame:SetBackdrop(BACKDROP_FLAT)
    local c = self.colors
    frame:SetBackdropColor(c.bg[1], c.bg[2], c.bg[3], c.bg[4])
    frame:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
end

function ns.Theme:StyleButton(button)
    ensureBackdrop(button)
    local c = self.colors
    button:SetBackdrop(BACKDROP_FLAT)
    button:SetBackdropColor(c.button[1], c.button[2], c.button[3], 1)
    button:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
    if not button:GetFontString() then
        local fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER")
        button:SetFontString(fs)
    end
    local fs = button:GetFontString()
    self:SetReadableFont(fs, 13)
    self:SetTextColor(fs, c.text)
    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(c.buttonHover[1], c.buttonHover[2], c.buttonHover[3], 1)
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(c.button[1], c.button[2], c.button[3], 1)
    end)
end

function ns.Theme:StyleEditBox(editBox)
    local c = self.colors
    -- InputBoxTemplate already has its own chrome; do not SetBackdrop here.
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetTextColor(c.text[1], c.text[2], c.text[3])
end

function ns.Theme:StyleTabBar(frame)
    ensureBackdrop(frame)
    local c = self.colors
    frame:SetBackdrop(BACKDROP_FLAT)
    frame:SetBackdropColor(c.tabBar[1], c.tabBar[2], c.tabBar[3], c.tabBar[4] or 1)
    frame:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 0.6)
end

function ns.Theme:InitTab(button, label)
    ensureBackdrop(button)
    local c = self.colors
    button:SetBackdrop(BACKDROP_FLAT)

    local fs = button:GetFontString()
    if not fs then
        fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", 0, 0)
        button:SetFontString(fs)
    end
    fs:SetFontObject("GameFontHighlightSmall")
    fs:SetShadowOffset(0, 0)
    fs:SetText(label or "")

    button.activeLine = button:CreateTexture(nil, "OVERLAY")
    button.activeLine:SetHeight(2)
    button.activeLine:SetPoint("BOTTOMLEFT", 6, 1)
    button.activeLine:SetPoint("BOTTOMRIGHT", -6, 1)
    button.activeLine:SetColorTexture(c.accent[1], c.accent[2], c.accent[3], 1)
    button.activeLine:Hide()

    button.label = label
    button.isTabActive = false

    button:SetScript("OnEnter", function(self)
        if self.isTabActive then
            return
        end
        self:SetBackdropColor(c.tabHoverBg[1], c.tabHoverBg[2], c.tabHoverBg[3], 1)
        self:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 0.35)
        ns.Theme:SetTextColor(self:GetFontString(), c.tabHoverText)
    end)
    button:SetScript("OnLeave", function(self)
        if self.isTabActive then
            return
        end
        ns.Theme:StyleTab(self, false)
    end)
end

function ns.Theme:StyleCard(frame)
    ensureBackdrop(frame)
    local c = self.colors
    frame:SetBackdrop(BACKDROP_FLAT)
    frame:SetBackdropColor(c.card[1], c.card[2], c.card[3], 1)
    frame:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 0.45)
end

function ns.Theme:SetCardHover(frame, hovered)
    ensureBackdrop(frame)
    local c = self.colors
    if hovered then
        frame:SetBackdropColor(c.cardHover[1], c.cardHover[2], c.cardHover[3], 1)
        frame:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 0.75)
    else
        frame:SetBackdropColor(c.card[1], c.card[2], c.card[3], 1)
        frame:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 0.45)
    end
end

function ns.Theme:StyleSmallButton(button, variant)
    ensureBackdrop(button)
    local c = self.colors
    button:SetBackdrop(BACKDROP_FLAT)

    local fs = button:GetFontString()
    if not fs then
        fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER", 0, 0)
        button:SetFontString(fs)
    end
    fs:SetFontObject("GameFontHighlightSmall")
    fs:SetShadowOffset(0, 0)
    local label = button:GetText()
    if label and label ~= "" then
        fs:SetText(label)
    end

    local baseBg, hoverBg, textColor, borderAlpha = c.button, c.buttonHover, c.text, 0.5
    if variant == "danger" then
        baseBg = { 0.22, 0.14, 0.14, 1.0 }
        hoverBg = { 0.32, 0.16, 0.16, 1.0 }
        textColor = { 0.98, 0.78, 0.78, 1.0 }
        borderAlpha = 0.65
    elseif variant == "success" then
        baseBg = { 0.14, 0.28, 0.16, 1.0 }
        hoverBg = { 0.18, 0.40, 0.22, 1.0 }
        textColor = { 0.75, 0.98, 0.80, 1.0 }
        borderAlpha = 0.65
    elseif variant == "royal" then
        baseBg = c.royal
        hoverBg = c.royalHover
        textColor = c.gold
        borderAlpha = 0.8
    end

    button:SetBackdropColor(baseBg[1], baseBg[2], baseBg[3], 1)
    button:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], borderAlpha)
    self:SetTextColor(fs, textColor)

    button._themeBaseBg = baseBg
    button._themeHoverBg = hoverBg

    button:SetScript("OnEnter", function(self)
        local h = self._themeHoverBg or hoverBg
        self:SetBackdropColor(h[1], h[2], h[3], 1)
    end)
    button:SetScript("OnLeave", function(self)
        local b = self._themeBaseBg or baseBg
        self:SetBackdropColor(b[1], b[2], b[3], 1)
    end)
end

function ns.Theme:GetButtonTextWidth(button)
    if not button then
        return 0
    end
    local fs = button.label or button:GetFontString()
    if fs and fs.GetStringWidth then
        return fs:GetStringWidth() or 0
    end
    return 0
end

function ns.Theme:StyleNoticeCard(frame, tone)
    self:StyleCard(frame)
    local c = self.colors
    local border = tone == "warn" and c.accent or c.notice
    frame:SetBackdropBorderColor(border[1], border[2], border[3], 0.55)
end

function ns.Theme:StyleTab(button, active, label)
    ensureBackdrop(button)
    if label then
        button.label = label
    end

    local fs = button:GetFontString()
    if fs and button.label then
        fs:SetText(button.label)
    end

    button.isTabActive = active
    local c = self.colors

    if active then
        button:SetBackdropColor(c.tabActiveBg[1], c.tabActiveBg[2], c.tabActiveBg[3], 1)
        button:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 0.5)
        if fs then
            self:SetTextColor(fs, c.tabActiveText)
        end
        if button.activeLine then
            button.activeLine:Show()
        end
    else
        button:SetBackdropColor(c.tabInactiveBg[1], c.tabInactiveBg[2], c.tabInactiveBg[3], c.tabInactiveBg[4] or 0)
        button:SetBackdropBorderColor(0, 0, 0, 0)
        if fs then
            self:SetTextColor(fs, c.tabInactiveText)
        end
        if button.activeLine then
            button.activeLine:Hide()
        end
    end
end
