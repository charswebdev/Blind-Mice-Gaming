local _, GPS = ...

GPS.Theme = {
    colors = {
        bg = { 0.08, 0.08, 0.10, 0.95 },
        panel = { 0.12, 0.12, 0.15, 1.0 },
        border = { 0.25, 0.25, 0.30, 1.0 },
        text = { 0.98, 0.98, 0.98, 1.0 },
        textMuted = { 0.82, 0.84, 0.88, 1.0 },
        accent = { 1.00, 0.82, 0.00, 1.0 },
        tabBar = { 0.10, 0.10, 0.12, 1.0 },
        tabActiveBg = { 0.17, 0.17, 0.21, 1.0 },
        tabActiveText = { 0.98, 0.98, 0.98, 1.0 },
        tabInactiveBg = { 0.12, 0.12, 0.15, 0.0 },
        tabInactiveText = { 0.62, 0.64, 0.68, 1.0 },
        tabHoverBg = { 0.15, 0.15, 0.18, 1.0 },
        tabHoverText = { 0.88, 0.89, 0.92, 1.0 },
        button = { 0.18, 0.18, 0.22, 1.0 },
        buttonHover = { 0.24, 0.24, 0.30, 1.0 },
        card = { 0.14, 0.14, 0.17, 1.0 },
        cardHover = { 0.17, 0.17, 0.21, 1.0 },
        sectionHeader = { 0.55, 0.57, 0.62, 1.0 },
        royal = { 0.16, 0.28, 0.72, 1.0 },
        royalHover = { 0.22, 0.38, 0.88, 1.0 },
        gold = { 1.00, 0.84, 0.00, 1.0 },
    },
}

local Theme = GPS.Theme

local BACKDROP_FLAT = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = false,
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local function ensureBackdrop(frame)
    if frame and not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
end

function Theme:SetTextColor(fontString, color)
    if not fontString or not color then
        return
    end
    fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

function Theme:SetReadableFont(fontString, size)
    if not fontString then
        return
    end
    if size and size >= 16 then
        fontString:SetFontObject("GameFontNormalLarge")
    else
        fontString:SetFontObject("GameFontNormal")
    end
    fontString:SetShadowOffset(1, -1)
    fontString:SetShadowColor(0, 0, 0, 0.9)
end

function Theme:ApplyBackdrop(frame)
    ensureBackdrop(frame)
    frame:SetBackdrop(BACKDROP_FLAT)
    local c = self.colors
    frame:SetBackdropColor(c.bg[1], c.bg[2], c.bg[3], c.bg[4])
    frame:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], c.border[4])
end

function Theme:StyleEditBox(editBox)
    local c = self.colors
    editBox:SetFontObject("GameFontHighlight")
    editBox:SetTextColor(c.text[1], c.text[2], c.text[3])
end

function Theme:StyleTabBar(frame)
    ensureBackdrop(frame)
    local c = self.colors
    frame:SetBackdrop(BACKDROP_FLAT)
    frame:SetBackdropColor(c.tabBar[1], c.tabBar[2], c.tabBar[3], c.tabBar[4] or 1)
    frame:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 0.6)
end

function Theme:InitTab(button, label)
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
        Theme:SetTextColor(self:GetFontString(), c.tabHoverText)
    end)
    button:SetScript("OnLeave", function(self)
        if self.isTabActive then
            return
        end
        Theme:StyleTab(self, false)
    end)
end

function Theme:StyleTab(button, active, label)
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

function Theme:StyleCard(frame)
    ensureBackdrop(frame)
    local c = self.colors
    frame:SetBackdrop(BACKDROP_FLAT)
    frame:SetBackdropColor(c.card[1], c.card[2], c.card[3], 1)
    frame:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 0.45)
end

function Theme:StyleSmallButton(button, variant)
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
    if variant == "royal" then
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

function Theme:CreateDropdown(parent, name, width, initialText, getItems, onPick)
    if not UIDropDownMenu_Initialize or not UIDropDownMenuTemplate then
        return nil
    end
    local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dropdown, width or 160)
    UIDropDownMenu_Initialize(dropdown, function(_, level)
        local items = getItems() or {}
        for i = 1, #items do
            local item = items[i]
            local info = UIDropDownMenu_CreateInfo()
            info.text = item.text
            info.checked = item.checked
            info.func = function()
                UIDropDownMenu_SetText(dropdown, item.text)
                if onPick then
                    onPick(item)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(dropdown, initialText or "")
    return dropdown
end
