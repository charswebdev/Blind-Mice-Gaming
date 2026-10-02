local _, GPS = ...

GPS.Search = GPS.Search or {}
local Search = GPS.Search

function Search:Later()
    GPS:Print(GPS.LATER.destinations)
end

function Search:Build(parent)
    local theme = GPS.Theme
    local c = theme.colors

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, -10)
    header:SetText("Where do you want to go?")
    theme:SetReadableFont(header, 14)
    theme:SetTextColor(header, c.text)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Pick a destination below, then click Start Route. Or type a name and press Enter.")
    theme:SetTextColor(hint, c.textMuted)

    local here = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    here:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    here:SetPoint("TOPRIGHT", hint, "BOTTOMRIGHT", 0, -8)
    here:SetHeight(44)
    theme:StyleCard(here)

    here.zone = here:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    here.zone:SetPoint("TOPLEFT", 10, -6)
    here.zone:SetPoint("TOPRIGHT", -10, -6)
    here.zone:SetJustifyH("LEFT")
    here.zone:SetText("You are here")
    theme:SetTextColor(here.zone, c.accent)

    here.coords = here:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    here.coords:SetPoint("TOPLEFT", here.zone, "BOTTOMLEFT", 0, -2)
    here.coords:SetPoint("TOPRIGHT", here.zone, "BOTTOMRIGHT", 0, -2)
    here.coords:SetJustifyH("LEFT")
    here.coords:SetText("Reading position...")
    theme:SetTextColor(here.coords, c.text)
    self.hereZone = here.zone
    self.hereCoords = here.coords

    local searchBox = CreateFrame("EditBox", "WowGPSForeverSearchBox", parent, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetPoint("TOPLEFT", here, "BOTTOMLEFT", 0, -8)
    searchBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, 0)
    searchBox:SetHeight(28)
    searchBox:SetMaxLetters(80)
    theme:StyleEditBox(searchBox)
    searchBox:SetScript("OnTextChanged", function(edit)
        Search:Refresh(edit:GetText())
    end)
    searchBox:SetScript("OnEnterPressed", function(edit)
        Search:StartSelected(true)
        edit:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(edit)
        edit:ClearFocus()
    end)
    self.searchBox = searchBox

    local filterLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterLabel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -10)
    filterLabel:SetText("Type:")
    theme:SetTextColor(filterLabel, c.text)

    local dropdown = theme:CreateDropdown(parent, "WowGPSForeverSearchFilter", 180, "All", function()
        return { { text = "All", checked = true } }
    end)
    if dropdown then
        dropdown:SetPoint("TOPLEFT", filterLabel, "TOPRIGHT", -8, 4)
    end

    local listLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    listLabel:SetPoint("TOPLEFT", filterLabel, "BOTTOMLEFT", 0, -24)
    listLabel:SetText("Zones, flights, and saved places")
    theme:SetTextColor(listLabel, c.textMuted)
    self.listLabel = listLabel

    local selected = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    selected:SetPoint("BOTTOMLEFT", 12, 42)
    selected:SetPoint("BOTTOMRIGHT", -12, 42)
    selected:SetJustifyH("LEFT")
    selected:SetText("")
    theme:SetTextColor(selected, c.accent)
    self.selectedLabel = selected

    local scroll = CreateFrame("ScrollFrame", "WowGPSForeverSearchScroll", parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", -4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 62)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(280, 1)
    scroll:SetScrollChild(content)
    self.scroll = scroll
    self.content = content
    self.rows = {}

    local startBtn = CreateFrame("Button", "WowGPSForeverStartRouteButton", parent, "UIPanelButtonTemplate")
    startBtn:SetSize(148, 28)
    startBtn:SetPoint("BOTTOM", parent, "BOTTOM", -58, 10)
    startBtn:SetText("Start Route")
    startBtn:SetScript("OnClick", function()
        Search:StartSelected(true)
    end)

    local arrowBtn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    arrowBtn:SetSize(108, 28)
    arrowBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)
    arrowBtn:SetText("Set Arrow")
    theme:StyleSmallButton(arrowBtn, "royal")
    arrowBtn:SetScript("OnClick", function()
        Search:StartSelected(false)
    end)

    self:Refresh("")

    function self:Focus()
        if self.searchBox then
            self.searchBox:SetFocus()
        end
    end
end

function Search:Query(text)
    text = GPS:PlainString(text) or ""
    return string.lower(text)
end

function Search:Stems(query)
    local stems = { query }
    if #query > 3 and string.sub(query, -3) == "ies" then
        stems[#stems + 1] = string.sub(query, 1, -4) .. "y"
    elseif #query > 1 and string.sub(query, -1) == "s" then
        stems[#stems + 1] = string.sub(query, 1, -2)
    end
    return stems
end

function Search:Matches(dest, query)
    if query == "" then
        return true
    end
    local name = string.lower(dest.name or "")
    local zone = string.lower(dest.zone or "")
    local kind = string.lower(dest.kind or "")
    local stems = self:Stems(query)
    for i = 1, #stems do
        local stem = stems[i]
        if string.find(name, stem, 1, true)
            or string.find(zone, stem, 1, true)
            or (kind ~= "" and (string.find(kind, stem, 1, true) or string.find(stem, kind, 1, true))) then
            return true
        end
    end
    return false
end

function Search:Collect(query)
    local list = {}
    local world = GPS.World and GPS.World:List() or {}
    for i = 1, #world do
        if self:Matches(world[i], query) then
            list[#list + 1] = world[i]
        end
    end
    if GPS.Places then
        local saved = GPS.Places:List()
        for i = 1, #saved do
            if self:Matches(saved[i], query) then
                list[#list + 1] = saved[i]
            end
        end
    end
    return list
end

function Search:Row(index)
    local row = self.rows[index]
    if row then
        return row
    end
    local theme = GPS.Theme
    row = CreateFrame("Button", nil, self.content, "BackdropTemplate")
    row:SetHeight(34)
    theme:StyleCard(row)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetPoint("RIGHT", -8, 0)
    row.label:SetJustifyH("LEFT")
    theme:SetTextColor(row.label, theme.colors.text)
    row:SetScript("OnClick", function(button)
        Search:Select(button.dest)
    end)
    row:SetScript("OnDoubleClick", function(button)
        Search:Select(button.dest)
        Search:StartSelected(true)
    end)
    self.rows[index] = row
    return row
end

function Search:Select(dest)
    self.selected = dest
    if self.selectedLabel then
        if dest and dest.name then
            local where = dest.zone
            if where and where ~= "" and where ~= dest.name then
                self.selectedLabel:SetText("Selected: " .. dest.name .. " (" .. where .. ")")
            else
                self.selectedLabel:SetText("Selected: " .. dest.name)
            end
        else
            self.selectedLabel:SetText("")
        end
    end
end

function Search:Refresh(text)
    if not self.content then
        return
    end
    local query = self:Query(text or (self.searchBox and self.searchBox:GetText()) or "")
    local results = self:Collect(query)
    self.results = results
    local width = 260
    if self.scroll then
        local w = GPS:PlainNumber(self.scroll:GetWidth())
        if w and w > 80 then
            width = w - 8
        end
    end
    for i = 1, #results do
        local row = self:Row(i)
        local dest = results[i]
        local suffix = ""
        if dest.custom then
            suffix = "  ·  Saved"
        elseif dest.kind == "flight" then
            suffix = "  ·  Flight"
        elseif dest.kind == "dungeon" then
            suffix = "  ·  Dungeon"
        elseif dest.kind == "raid" then
            suffix = "  ·  Raid"
        elseif dest.kind == "city" then
            suffix = "  ·  City"
        end
        local label = dest.name or "?"
        if (dest.kind == "dungeon" or dest.kind == "raid") and dest.zone and dest.zone ~= dest.name then
            label = label .. " (" .. dest.zone .. ")"
        end
        row.label:SetText(label .. suffix)
        row.dest = dest
        row:SetWidth(width)
        row:SetPoint("TOPLEFT", 0, -((i - 1) * 36))
        row:Show()
    end
    for i = #results + 1, #self.rows do
        self.rows[i]:Hide()
        self.rows[i].dest = nil
    end
    self.content:SetWidth(width)
    self.content:SetHeight(math.max(1, #results * 36))
    if self.listLabel then
        if #results == 0 then
            self.listLabel:SetText("No destinations found.")
        else
            self.listLabel:SetText("Zones, flights, and saved places")
        end
    end
    if self.selected then
        local still
        for i = 1, #results do
            if results[i].id == self.selected.id then
                still = results[i]
                break
            end
        end
        self:Select(still)
    end
end

function Search:StartSelected(openRoute)
    local dest = self.selected
    if not dest and self.results and #self.results == 1 then
        dest = self.results[1]
        self:Select(dest)
    end
    if not dest then
        GPS:Print("Pick a destination first.")
        return
    end
    if GPS.Guide then
        GPS.Guide:Start(dest, openRoute)
    end
end

function Search:SetHere(zone, coords)
    if self.hereZone then
        self.hereZone:SetText(zone or "You are here")
    end
    if self.hereCoords then
        self.hereCoords:SetText(coords or "")
    end
end
