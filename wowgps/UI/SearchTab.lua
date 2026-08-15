local _, ns = ...

local SearchTab = {}
ns.SearchTab = SearchTab

local ROW_HEIGHT = 50
local POOL_SIZE = 24

function SearchTab:Build(parent, mainFrame)
    self.parent = parent
    self.mainFrame = mainFrame
    self.filters = { type = "all" }
    self.selectedDest = nil
    self.results = {}

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, -10)
    header:SetText(L["SEARCH_HEADER"])
    theme:SetReadableFont(header, 14)
    theme:SetTextColor(header, theme.colors.text)

    local hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText(L["SEARCH_HINT"])
    theme:SetTextColor(hint, theme.colors.textMuted)
    self.hint = hint

    local searchBox = CreateFrame("EditBox", "WowGPSSearchBox", parent, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    searchBox:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, 0)
    searchBox:SetHeight(28)
    searchBox:SetMaxLetters(80)
    theme:StyleEditBox(searchBox)
    searchBox:SetScript("OnTextChanged", function(edit)
        self:UpdateResults(edit:GetText())
    end)
    searchBox:SetScript("OnEnterPressed", function(edit)
        self:StartSelectedOrQuery()
        edit:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(edit)
        edit:ClearFocus()
    end)
    self.searchBox = searchBox

    local filterLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    filterLabel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -10)
    filterLabel:SetText(L["FILTER_TYPE"] .. ":")
    theme:SetTextColor(filterLabel, theme.colors.text)

    local filterDropdown = CreateFrame("Frame", "WowGPSSearchFilter", parent, "UIDropDownMenuTemplate")
    filterDropdown:SetPoint("TOPLEFT", filterLabel, "TOPRIGHT", -8, 4)
    UIDropDownMenu_SetWidth(filterDropdown, 180)
    UIDropDownMenu_Initialize(filterDropdown, function(_, level)
        for _, t in ipairs(ns.LocationTags:GetTypeOptions(true)) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = t.label
            info.func = function()
                self.filters.type = t.key
                UIDropDownMenu_SetText(filterDropdown, t.label)
                self:UpdateResults(searchBox:GetText())
            end
            info.checked = self.filters.type == t.key
            UIDropDownMenu_AddButton(info, level)
        end
    end)
    UIDropDownMenu_SetText(filterDropdown, L["FILTER_ALL"])
    self.filterDropdown = filterDropdown

    local listLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    listLabel:SetPoint("TOPLEFT", filterLabel, "BOTTOMLEFT", 0, -24)
    listLabel:SetText(L["SEARCH_RESULTS"])
    theme:SetTextColor(listLabel, theme.colors.textMuted)
    self.listLabel = listLabel

    local selectedLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    selectedLabel:SetPoint("BOTTOMLEFT", 12, 38)
    selectedLabel:SetPoint("BOTTOMRIGHT", -12, 38)
    selectedLabel:SetJustifyH("LEFT")
    selectedLabel:SetText("")
    theme:SetTextColor(selectedLabel, theme.colors.accent)
    self.selectedLabel = selectedLabel

    local startBtn = CreateFrame("Button", "WowGPSStartRouteButton", parent, "UIPanelButtonTemplate")
    startBtn:SetSize(148, 28)
    startBtn:SetPoint("BOTTOM", parent, "BOTTOM", -58, 10)
    startBtn:SetText(L["START_ROUTE"])
    startBtn:SetScript("OnClick", function()
        self:StartSelectedOrQuery()
    end)
    self.startBtn = startBtn

    local arrowBtn = CreateFrame("Button", "WowGPSSetArrowButton", parent, "BackdropTemplate")
    arrowBtn:SetSize(108, 28)
    arrowBtn:SetPoint("LEFT", startBtn, "RIGHT", 8, 0)
    arrowBtn:SetText(L["SET_ARROW"] or "Set Arrow")
    arrowBtn:RegisterForClicks("LeftButtonUp")
    theme:StyleSmallButton(arrowBtn, "royal")
    arrowBtn:SetScript("OnClick", function()
        self:SetArrowSelectedOrQuery()
    end)
    self.arrowBtn = arrowBtn

    local scroll = CreateFrame("ScrollFrame", "WowGPSSearchScroll", parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", -4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 62)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(280, 1)
    scroll:SetScrollChild(content)

    scroll:SetScript("OnVerticalScroll", function()
        self:RefreshVisibleRows()
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local maxScroll = math.max(0, content:GetHeight() - scroll:GetHeight())
        local step = ROW_HEIGHT * 3
        local nextScroll = math.min(maxScroll, math.max(0, scroll:GetVerticalScroll() - (delta * step)))
        scroll:SetVerticalScroll(nextScroll)
        self:RefreshVisibleRows()
    end)
    scroll:SetScript("OnSizeChanged", function()
        self:RefreshVisibleRows()
    end)

    self.scroll = scroll
    self.content = content
    self.resultButtons = {}

    for i = 1, POOL_SIZE do
        local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
        btn:SetSize(280, ROW_HEIGHT - 2)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        btn.text:SetPoint("TOPLEFT", 8, -4)
        btn.text:SetPoint("TOPRIGHT", -8, -4)
        btn.text:SetJustifyH("LEFT")
        btn.text:SetWordWrap(false)
        theme:SetReadableFont(btn.text, 13)

        btn.zone = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.zone:SetPoint("TOPLEFT", btn.text, "BOTTOMLEFT", 0, -1)
        btn.zone:SetPoint("TOPRIGHT", btn.text, "BOTTOMRIGHT", 0, -1)
        btn.zone:SetJustifyH("LEFT")
        btn.zone:SetWordWrap(false)
        theme:SetReadableFont(btn.zone, 11)

        btn.note = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.note:SetPoint("TOPLEFT", btn.zone, "BOTTOMLEFT", 0, -1)
        btn.note:SetPoint("TOPRIGHT", btn.zone, "BOTTOMRIGHT", 0, -1)
        btn.note:SetJustifyH("LEFT")
        btn.note:SetWordWrap(false)
        theme:SetReadableFont(btn.note, 11)
        btn.note:Hide()

        btn:SetScript("OnClick", function(b)
            if b.dest then
                self:SelectDestination(b.dest)
            end
        end)
        btn:SetScript("OnDoubleClick", function(b)
            if b.dest then
                self:SelectDestination(b.dest)
                self:StartRoute(b.dest)
            end
        end)
        btn:SetScript("OnEnter", function(b)
            if not b.dest then
                return
            end
            local zoneLine = ns.Destination and ns.Destination:FormatZoneLine(b.dest)
            local note = b.dest.note
            if (not zoneLine or zoneLine == "") and (not note or note == "") then
                return
            end
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:SetText(b.dest.name or "?", 1, 1, 1)
            if zoneLine then
                GameTooltip:AddLine(zoneLine, 0.75, 0.78, 0.85)
            end
            if note and note ~= "" then
                GameTooltip:AddLine(note, 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        btn:Hide()
        self.resultButtons[i] = btn
    end

    self.emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.emptyLabel:SetPoint("TOPLEFT", 8, -8)
    self.emptyLabel:SetJustifyH("LEFT")
    self.emptyLabel:Hide()

    self:LayoutFooterButtons()
    self:UpdateResults("")
end

function SearchTab:GetResults(query)
    query = query or ""
    if query:gsub("^%s+", ""):gsub("%s+$", "") == "" then
        local results = {}
        local function matchesType(entry)
            return ns.LocationTags:EntryMatchesType(entry, self.filters.type)
        end
        for _, entry in ipairs(ns.CustomLocations:List("account")) do
            local dest = ns.CustomLocations:ToDestination(entry)
            if matchesType(dest) then
                results[#results + 1] = dest
            end
        end
        for _, entry in ipairs(ns.CustomLocations:List("character")) do
            local dest = ns.CustomLocations:ToDestination(entry)
            if matchesType(dest) then
                results[#results + 1] = dest
            end
        end
        for _, entry in ipairs(ns.Destination:GetAllOfficial()) do
            if matchesType(entry) then
                results[#results + 1] = entry
            end
        end
        table.sort(results, function(a, b)
            local aCustom = a.custom and 0 or 1
            local bCustom = b.custom and 0 or 1
            if aCustom ~= bCustom then
                return aCustom < bCustom
            end
            return tostring(a.name or "") < tostring(b.name or "")
        end)
        return results
    end
    return ns.Destination:Search(query, self.filters)
end

function SearchTab:IsSelected(dest)
    return self.selectedDest and dest and self.selectedDest.id == dest.id
end

function SearchTab:SelectDestination(dest)
    self.selectedDest = dest
    self:RefreshSelectionLabel()
    self:RefreshVisibleRows()
end

function SearchTab:RefreshSelectionLabel()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    if self.selectedDest then
        self.selectedLabel:SetText(string.format(L["SELECTED"], self.selectedDest.name))
    else
        self.selectedLabel:SetText("")
    end
end

function SearchTab:StyleResultButton(btn, dest, theme)
    local c = theme.colors
    local prefix = ""
    if dest.custom then
        local tagText = ns.LocationTags:FormatBracket(dest.tags)
        prefix = tagText and (tagText .. " ") or "★ "
    end
    local label = prefix .. (dest.name or "?")
    if dest.pack and not dest.custom then
        label = string.format("%s  |cff888888(%s)|r", label, dest.pack)
    end
    btn.text:SetText(label)

    local zoneLine = ns.Destination and ns.Destination:FormatZoneLine(dest)
    btn.note:Hide()
    if zoneLine then
        btn.zone:SetText(zoneLine)
        btn.zone:Show()
        btn.text:ClearAllPoints()
        btn.text:SetPoint("TOPLEFT", 8, -4)
        btn.text:SetPoint("TOPRIGHT", -8, -4)
    else
        btn.zone:SetText("")
        btn.zone:Hide()
        btn.text:ClearAllPoints()
        btn.text:SetPoint("LEFT", 8, 0)
        btn.text:SetPoint("RIGHT", -8, 0)
    end

    if self:IsSelected(dest) then
        btn:SetBackdropColor(c.tabActiveBg[1], c.tabActiveBg[2], c.tabActiveBg[3], 1)
        btn:SetBackdropBorderColor(c.accent[1], c.accent[2], c.accent[3], 1)
        theme:SetTextColor(btn.text, c.tabActiveText)
        theme:SetTextColor(btn.zone, c.textMuted)
    else
        btn:SetBackdropColor(c.button[1], c.button[2], c.button[3], 1)
        btn:SetBackdropBorderColor(c.border[1], c.border[2], c.border[3], 1)
        theme:SetTextColor(btn.text, dest.custom and c.accent or c.text)
        theme:SetTextColor(btn.zone, c.textMuted)
    end
end

function SearchTab:OnParentResize()
    self:LayoutFooterButtons()
    if self.scroll and self.content then
        self.content:SetWidth(math.max(200, (self.scroll:GetWidth() or 280) - 4))
        self:RefreshVisibleRows()
    end
end

function SearchTab:LayoutFooterButtons()
    local startBtn = self.startBtn
    local arrowBtn = self.arrowBtn
    local parent = self.parent
    if not startBtn or not arrowBtn or not parent then
        return
    end

    local w = parent:GetWidth() or 300
    local pad = 12
    local gap = 8
    local avail = math.max(160, w - pad * 2)
    local startW, arrowW = 148, 108
    if startW + gap + arrowW > avail then
        local scale = (avail - gap) / (startW + arrowW)
        startW = math.max(90, math.floor(startW * scale))
        arrowW = math.max(72, math.floor(arrowW * scale))
    end
    startBtn:SetWidth(startW)
    arrowBtn:SetWidth(arrowW)

    local total = startW + gap + arrowW
    local left = math.max(pad, (w - total) / 2)
    startBtn:ClearAllPoints()
    startBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", left, 10)
    arrowBtn:ClearAllPoints()
    arrowBtn:SetPoint("LEFT", startBtn, "RIGHT", gap, 0)
end

function SearchTab:RefreshVisibleRows()
    local theme = ns.Theme
    local results = self.results or {}
    local offset = self.scroll:GetVerticalScroll() or 0
    local first = math.floor(offset / ROW_HEIGHT) + 1
    if first < 1 then
        first = 1
    end

    local viewH = self.scroll:GetHeight() or 200
    local visible = math.ceil(viewH / ROW_HEIGHT) + 2
    if visible > POOL_SIZE then
        visible = POOL_SIZE
    end

    for i = 1, POOL_SIZE do
        local btn = self.resultButtons[i]
        local index = first + i - 1
        local dest = results[index]
        if dest and i <= visible then
            btn.dest = dest
            self:StyleResultButton(btn, dest, theme)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT) - 4)
            btn:SetWidth(math.max(200, (self.scroll:GetWidth() or 280) - 4))
            btn:SetHeight(ROW_HEIGHT - 2)
            btn:Show()
        else
            btn.dest = nil
            btn:Hide()
        end
    end
end

function SearchTab:GetFilterTypeLabel()
    return ns.LocationTags:GetTypeLabel(self.filters and self.filters.type)
end

function SearchTab:UpdateResultsCountLabel(count, isEmptyQuery)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local typeLabel = self:GetFilterTypeLabel()
    if typeLabel then
        self.listLabel:SetText(string.format(L["SEARCH_RESULTS_COUNT_TYPED"], count, typeLabel))
    elseif isEmptyQuery then
        self.listLabel:SetText(string.format(L["SEARCH_SUGGESTIONS_COUNT"], count))
    else
        self.listLabel:SetText(string.format(L["SEARCH_RESULTS_COUNT"], count))
    end
end

function SearchTab:UpdateResults(query)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local results = self:GetResults(query)
    self.results = results
    local isEmptyQuery = (query or ""):gsub("^%s+", ""):gsub("%s+$", "") == ""

    self:UpdateResultsCountLabel(#results, isEmptyQuery)

    local selectionStillValid = false
    if self.selectedDest then
        for _, dest in ipairs(results) do
            if dest.id == self.selectedDest.id then
                selectionStillValid = true
                break
            end
        end
    end
    if not selectionStillValid then
        self.selectedDest = results[1]
    end
    self:RefreshSelectionLabel()

    local contentHeight = math.max(1, (#results * ROW_HEIGHT) + 8)
    self.content:SetWidth(math.max(200, (self.scroll:GetWidth() or 280) - 4))
    self.content:SetHeight(contentHeight)

    if #results == 0 then
        self.selectedDest = nil
        self:RefreshSelectionLabel()
        local typeLabel = self:GetFilterTypeLabel()
        if typeLabel and isEmptyQuery then
            self.emptyLabel:SetText(string.format(L["SEARCH_NO_TYPE_MATCHES"], typeLabel:lower()))
        else
            self.emptyLabel:SetText(isEmptyQuery and L["SEARCH_EMPTY"] or L["NO_RESULTS"])
        end
        ns.Theme:SetTextColor(self.emptyLabel, ns.Theme.colors.textMuted)
        self.emptyLabel:Show()
        for _, btn in ipairs(self.resultButtons) do
            btn:Hide()
        end
        self.scroll:SetVerticalScroll(0)
        return
    end

    self.emptyLabel:Hide()
    local maxScroll = math.max(0, contentHeight - (self.scroll:GetHeight() or 0))
    if self.scroll:GetVerticalScroll() > maxScroll then
        self.scroll:SetVerticalScroll(maxScroll)
    end
    self:RefreshVisibleRows()
end

function SearchTab:ResolveSelectedOrQuery()
    if self.selectedDest then
        return self.selectedDest
    end

    local query = (self.searchBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then
        return nil
    end

    local dest = ns.Destination:ResolveByName(query)
    if dest then
        return dest
    end

    local results = ns.Destination:Search(query, self.filters)
    if results[1] then
        self:SelectDestination(results[1])
        return results[1]
    end

    return nil
end

function SearchTab:StartSelectedOrQuery()
    local dest = self:ResolveSelectedOrQuery()
    if dest then
        self:StartRoute(dest)
        return
    end

    WowGPS:Print(LibStub("AceLocale-3.0"):GetLocale("WowGPS")["NO_RESULTS"])
end

function SearchTab:SetArrowSelectedOrQuery()
    local dest = self:ResolveSelectedOrQuery()
    if dest then
        self:SetArrow(dest)
        return
    end

    WowGPS:Print(LibStub("AceLocale-3.0"):GetLocale("WowGPS")["NO_RESULTS"])
end

function SearchTab:SetArrow(dest)
    if not dest then
        WowGPS:Print("|cffFFCC00WowGPS:|r No destination selected.")
        return
    end

    if not WowGPS.ready then
        WowGPS:Bootstrap()
    end

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local ok
    if ns.TomTomIntegration and ns.TomTomIntegration.SetDestinationArrow then
        ok = ns.TomTomIntegration:SetDestinationArrow(dest)
    end

    if ok then
        WowGPS:Print(string.format(L["ARROW_SET"] or "|cff33CCFFWowGPS:|r Arrow set to %s.", dest.name or "destination"))
    else
        WowGPS:Print(L["ARROW_SET_FAILED"] or "Could not set an arrow for that destination.")
    end
end

function SearchTab:GoToQuery(query)
    query = (query or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return end
    self.searchBox:SetText(query)
    self:UpdateResults(query)
    self:StartSelectedOrQuery()
end

function SearchTab:StartRoute(dest)
    if not dest then
        WowGPS:Print("|cffFFCC00WowGPS:|r No destination selected.")
        return
    end

    local ok, err = pcall(function()
        if not WowGPS.ready then
            WowGPS:Bootstrap()
        end
        if not ns.RouteTracker or not ns.RouteTracker.Start then
            error("RouteTracker not loaded")
        end
        local started, startErr = ns.RouteTracker:Start(dest)
        if not started then
            error(startErr or "no_path")
        end
    end)

    if ok then
        return
    end

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    -- pcall prefixes errors with "file:line: "; match the trailing code.
    local errMsg = tostring(err or ""):gsub("^.-:%s*", "")
    if errMsg:find("not_ready", 1, true) or errMsg:find("zygor_not_ready", 1, true) then
        local msg = ns.ZygorTravel and ns.ZygorTravel:GetStatusMessage()
        WowGPS:Print(msg or L["ROUTE_FAILED"])
    elseif errMsg:find("bad_dest", 1, true) or errMsg:find("no_dest", 1, true) then
        WowGPS:Print(L["ROUTE_BAD_DEST"] or L["ROUTE_FAILED"])
    elseif errMsg:find("maw_unsafe", 1, true) then
        WowGPS:Print(L["ROUTE_MAW_UNSAFE"] or L["ROUTE_FAILED"])
    elseif errMsg:find("no_path", 1, true) or errMsg:find("no_steps", 1, true) then
        local playerMap = ns.TravelRegions and ns.TravelRegions:GetRawPlayerMapId()
        if ns.TravelRegions and ns.TravelRegions:IsMawMap(playerMap) then
            WowGPS:Print(L["ROUTE_MAW_UNSAFE"] or L["ROUTE_FAILED"])
        else
            WowGPS:Print(L["ROUTE_FAILED"])
        end
    else
        WowGPS:Print("|cffFF4444WowGPS:|r Route failed: " .. tostring(err))
    end
end

function SearchTab:Show(focusSearch)
    self.parent:Show()
    self:UpdateResults(self.searchBox:GetText())
    if focusSearch then
        self.searchBox:SetFocus()
    end
end

function SearchTab:Hide()
    self.parent:Hide()
end
