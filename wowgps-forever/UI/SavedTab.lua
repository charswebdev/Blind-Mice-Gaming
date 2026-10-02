local _, GPS = ...

GPS.Saved = GPS.Saved or {}
local Saved = GPS.Saved

function Saved:Build(parent)
    local theme = GPS.Theme
    local c = theme.colors
    self.parent = parent

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, -10)
    header:SetText("Saved locations")
    theme:SetReadableFont(header, 14)
    theme:SetTextColor(header, c.text)

    local count = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    count:SetPoint("TOPRIGHT", -12, -12)
    count:SetText("0 saved")
    theme:SetTextColor(count, c.textMuted)
    self.count = count

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    hint:SetPoint("TOPRIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Manage your personal waypoints.")
    theme:SetTextColor(hint, c.textMuted)

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 40)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(280, 1)
    scroll:SetScrollChild(content)
    self.scroll = scroll
    self.content = content
    self.rows = {}

    local empty = CreateFrame("Frame", nil, content, "BackdropTemplate")
    empty:SetPoint("TOPLEFT", 0, 0)
    empty:SetPoint("TOPRIGHT", 0, 0)
    empty:SetHeight(72)
    theme:StyleCard(empty)
    empty.title = empty:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty.title:SetPoint("TOP", 0, -16)
    empty.title:SetText("No saved locations yet.")
    theme:SetTextColor(empty.title, c.textMuted)
    empty.hint = empty:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    empty.hint:SetPoint("TOP", empty.title, "BOTTOM", 0, -4)
    empty.hint:SetWidth(240)
    empty.hint:SetJustifyH("CENTER")
    empty.hint:SetText("Use the Add tab to save your first waypoint.")
    theme:SetTextColor(empty.hint, c.textMuted)
    self.empty = empty

    local exportAll = CreateFrame("Button", nil, parent, "BackdropTemplate")
    exportAll:SetSize(88, 22)
    exportAll:SetPoint("BOTTOMLEFT", 12, 10)
    exportAll:SetText("Export all")
    theme:StyleSmallButton(exportAll)
    exportAll:SetScript("OnClick", function()
        local text = GPS.Import and GPS.Places and GPS.Import:FormatList(GPS.Places:List())
        if not text or not GPS.ExportDialog then
            GPS:Print("No saved locations to export.")
            return
        end
        GPS.ExportDialog:Show(text)
    end)
    exportAll:Hide()
    self.exportAll = exportAll

    self:Refresh()
end

function Saved:Row(index)
    local row = self.rows[index]
    if row then
        return row
    end
    local theme = GPS.Theme
    row = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    row:SetHeight(78)
    theme:StyleCard(row)
    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.title:SetPoint("TOPLEFT", 8, -8)
    row.title:SetPoint("TOPRIGHT", -8, -8)
    row.title:SetJustifyH("LEFT")
    theme:SetTextColor(row.title, theme.colors.text)
    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.detail:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.detail:SetPoint("RIGHT", -8, 0)
    row.detail:SetJustifyH("LEFT")
    theme:SetTextColor(row.detail, theme.colors.textMuted)

    local bar = CreateFrame("Frame", nil, row)
    bar:SetPoint("BOTTOMLEFT", 6, 6)
    bar:SetPoint("BOTTOMRIGHT", -6, 6)
    bar:SetHeight(22)
    row.actionBar = bar

    local function MakeAction(label, variant, width)
        local button = CreateFrame("Button", nil, bar, "BackdropTemplate")
        button:SetSize(width, 22)
        button:SetText(label)
        button:SetFrameLevel(row:GetFrameLevel() + 4)
        theme:StyleSmallButton(button, variant)
        return button
    end

    row.start = MakeAction("Start", "royal", 44)
    row.arrow = MakeAction("Arrow", nil, 48)
    row.exportBtn = MakeAction("Export", nil, 52)
    row.deleteBtn = MakeAction("Delete", nil, 52)

    row.start:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    row.arrow:SetPoint("LEFT", row.start, "RIGHT", 4, 0)
    row.exportBtn:SetPoint("LEFT", row.arrow, "RIGHT", 4, 0)
    row.deleteBtn:SetPoint("LEFT", row.exportBtn, "RIGHT", 4, 0)

    row.start:SetScript("OnClick", function(button)
        if button.dest and GPS.Guide then
            GPS.Guide:Start(button.dest, true)
        end
    end)
    row.arrow:SetScript("OnClick", function(button)
        if button.dest and GPS.Guide then
            GPS.Guide:Start(button.dest, false)
        end
    end)
    row.exportBtn:SetScript("OnClick", function(button)
        local dest = button.dest
        local line = dest and GPS.Import and GPS.Import:Format(dest)
        if not line or not GPS.ExportDialog then
            GPS:Print("Could not export that saved location.")
            return
        end
        GPS.ExportDialog:Show(line)
    end)
    row.deleteBtn:SetScript("OnClick", function(button)
        local dest = button.dest
        if dest and GPS.Places and GPS.Places:Delete(dest.id, dest.scope) then
            GPS:Print("Deleted " .. (dest.name or "location") .. ".")
            Saved:Refresh()
            if GPS.Search and GPS.Search.Refresh then
                GPS.Search:Refresh()
            end
        end
    end)
    self.rows[index] = row
    return row
end

function Saved:Refresh()
    if not self.content or not GPS.Places then
        return
    end
    local list = GPS.Places:List()
    local width = 260
    if self.scroll then
        local w = GPS:PlainNumber(self.scroll:GetWidth())
        if w and w > 80 then
            width = w - 8
        end
    end
    if self.count then
        self.count:SetText(string.format("%d saved", #list))
    end
    if #list == 0 then
        self.empty:Show()
        self.empty:SetWidth(width)
        if self.exportAll then
            self.exportAll:Hide()
        end
    else
        self.empty:Hide()
        if self.exportAll then
            self.exportAll:Show()
        end
    end
    for i = 1, #list do
        local row = self:Row(i)
        local dest = list[i]
        row.title:SetText(dest.name)
        local scope = dest.scope == "character" and "This character" or "Account-wide"
        local coords = ""
        if dest.x and dest.y then
            coords = string.format("%.1f, %.1f", dest.x * 100, dest.y * 100)
        end
        row.detail:SetText(scope .. "  " .. (dest.zone or "") .. "  " .. coords)
        row.start.dest = dest
        row.arrow.dest = dest
        row.exportBtn.dest = dest
        row.deleteBtn.dest = dest
        row:SetWidth(width)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * 84))
        row:Show()
    end
    for i = #list + 1, #self.rows do
        self.rows[i]:Hide()
    end
    local height = #list == 0 and 72 or (#list * 84)
    self.content:SetWidth(width)
    self.content:SetHeight(height)
end
