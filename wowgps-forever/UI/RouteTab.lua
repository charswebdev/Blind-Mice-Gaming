local _, GPS = ...

GPS.Route = GPS.Route or {}
local Route = GPS.Route

function Route:Build(parent)
    local theme = GPS.Theme
    local c = theme.colors

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, -10)
    header:SetText("Active route")
    theme:SetReadableFont(header, 14)
    theme:SetTextColor(header, c.text)

    local empty = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    empty:SetPoint("TOPLEFT", 12, -40)
    empty:SetPoint("TOPRIGHT", -12, -40)
    empty:SetHeight(72)
    theme:StyleCard(empty)
    empty.title = empty:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty.title:SetPoint("TOP", 0, -16)
    empty.title:SetText("No active route.")
    theme:SetTextColor(empty.title, c.textMuted)
    empty.hint = empty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty.hint:SetPoint("TOP", empty.title, "BOTTOM", 0, -4)
    empty.hint:SetWidth(240)
    empty.hint:SetJustifyH("CENTER")
    empty.hint:SetText("Search for a destination and start a route.")
    theme:SetTextColor(empty.hint, c.textMuted)
    self.empty = empty

    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", 12, -40)
    card:SetPoint("TOPRIGHT", -12, -40)
    card:SetHeight(72)
    theme:StyleCard(card)
    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.title:SetPoint("TOPLEFT", 10, -12)
    card.title:SetPoint("TOPRIGHT", -10, -12)
    card.title:SetJustifyH("LEFT")
    theme:SetTextColor(card.title, c.text)
    card.detail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.detail:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.detail:SetPoint("TOPRIGHT", card.title, "BOTTOMRIGHT", 0, -4)
    card.detail:SetJustifyH("LEFT")
    theme:SetTextColor(card.detail, c.textMuted)
    card:Hide()
    self.card = card
    self.rows = {}
    self.parent = parent

    local endBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    endBtn:SetSize(100, 26)
    endBtn:SetPoint("BOTTOMLEFT", 12, 12)
    endBtn:SetText("End route")
    theme:StyleSmallButton(endBtn)
    endBtn:SetScript("OnClick", function()
        if GPS.Guide then
            GPS.Guide:Clear()
        end
    end)
    endBtn:Hide()
    self.endBtn = endBtn
end

function Route:Row(index)
    local row = self.rows[index]
    if row then
        return row
    end
    local theme = GPS.Theme
    row = CreateFrame("Frame", nil, self.parent, "BackdropTemplate")
    row:SetHeight(44)
    theme:StyleCard(row)
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.title:SetPoint("TOPLEFT", 10, -8)
    row.title:SetPoint("TOPRIGHT", -10, -8)
    row.title:SetJustifyH("LEFT")
    theme:SetReadableFont(row.title, 13)
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.detail:SetPoint("TOPRIGHT", row.title, "BOTTOMRIGHT", 0, -2)
    row.detail:SetJustifyH("LEFT")
    row:Hide()
    self.rows[index] = row
    return row
end

function Route:ShowSteps(steps, activeIndex)
    if not self.empty then
        return
    end
    local theme = GPS.Theme
    local c = theme.colors
    if self.card then
        self.card:Hide()
    end
    if not steps or #steps == 0 then
        for i = 1, #self.rows do
            self.rows[i]:Hide()
        end
        self.endBtn:Hide()
        self.empty:Show()
        return
    end
    self.empty:Hide()
    for i = 1, #steps do
        local row = self:Row(i)
        local step = steps[i]
        row.title:SetText(i .. ".  " .. (step.name or ""))
        row.detail:SetText(step.detail or step.zone or "")
        if i == activeIndex then
            theme:SetTextColor(row.title, c.gold)
        else
            theme:SetTextColor(row.title, c.text)
        end
        theme:SetTextColor(row.detail, c.textMuted)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 12, -36 - ((i - 1) * 48))
        row:SetPoint("TOPRIGHT", -12, -36 - ((i - 1) * 48))
        row:Show()
    end
    for i = #steps + 1, #self.rows do
        self.rows[i]:Hide()
    end
    self.endBtn:Show()
end

function Route:ShowDestination(dest)
    if not dest then
        self:ShowSteps(nil)
        return
    end
    self:ShowSteps({ dest }, 1)
end
