local _, ns = ...

local RouteTab = {}
ns.RouteTab = RouteTab

RouteTab.LIST_WIDTH = 280
RouteTab.STEP_HEIGHT = 36
RouteTab.SUBSTEP_HEIGHT = 30
RouteTab.STEP_GAP = 4

function RouteTab:FormatTravelSuffix(step, route)
    if not ns.TravelActions then
        return ""
    end
    return ns.TravelActions:FormatStepSuffix(step, route)
end

function RouteTab:GetStepText(step)
    if ns.TravelActions then
        return ns.TravelActions:GetStepDisplayText(step)
    end
    return step.text or ""
end

function RouteTab:GetListWidth()
    if self.scroll then
        return math.max(200, (self.scroll:GetWidth() or self.LIST_WIDTH) - 4)
    end
    return self.LIST_WIDTH
end

function RouteTab:OnParentResize()
    if self.parent then
        self:Refresh()
    end
end

RouteTab.FOOTER_PAD_LEFT = 10
RouteTab.FOOTER_PAD_RIGHT = 18
RouteTab.FOOTER_GAP = 6
RouteTab.FOOTER_BTN_HEIGHT = 26
RouteTab.FOOTER_BTN_BOTTOM = 10
RouteTab.MAX_USE_BUTTONS = 3

function RouteTab:GetOrCreateStepRow(index)
    local row = self.stepRows[index]
    if row then
        return row
    end

    local theme = ns.Theme
    row = CreateFrame("Frame", nil, self.listContent, "BackdropTemplate")
    row:SetSize(self.LIST_WIDTH, self.STEP_HEIGHT)
    theme:StyleCard(row)

    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetWidth(3)
    row.bar:SetPoint("TOPLEFT", 1, -1)
    row.bar:SetPoint("BOTTOMLEFT", 1, 1)
    row.bar:SetColorTexture(0, 0, 0, 0)

    row.num = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.num:SetPoint("TOPLEFT", 10, -8)
    row.num:SetWidth(22)
    row.num:SetJustifyH("RIGHT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", 34, -8)
    row.text:SetWidth(238)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(true)

    self.stepRows[index] = row
    return row
end

function RouteTab:StyleStepRow(row, stepNum, step, route, active, isNav, isSubStep)
    local theme = ns.Theme
    local c = theme.colors
    local completed = step.completed
    local text = self:GetStepText(step) .. self:FormatTravelSuffix(step, route)
    local height = isSubStep and self.SUBSTEP_HEIGHT or self.STEP_HEIGHT

    row:SetHeight(height)
    local listWidth = self:GetListWidth()
    row:SetWidth(isSubStep and math.max(160, listWidth - 8) or listWidth)
    row.text:SetWidth(math.max(120, listWidth - (isSubStep and 54 or 42)))

    if isSubStep then
        row.num:SetText(string.char(96 + stepNum) .. ".")
    else
        row.num:SetText(tostring(stepNum) .. ".")
    end
    row.text:SetText(text)

    if isNav then
        theme:SetCardHover(row, true)
        row.bar:SetColorTexture(c.active[1], c.active[2], c.active[3], 1)
        theme:SetTextColor(row.num, c.active)
        theme:SetTextColor(row.text, c.text)
    elseif completed then
        theme:SetCardHover(row, false)
        row.bar:SetColorTexture(c.success[1], c.success[2], c.success[3], 0.85)
        theme:SetTextColor(row.num, c.success)
        theme:SetTextColor(row.text, c.textMuted)
    else
        theme:SetCardHover(row, false)
        row.bar:SetColorTexture(0, 0, 0, 0)
        theme:SetTextColor(row.num, c.textMuted)
        theme:SetTextColor(row.text, c.text)
    end
end

function RouteTab:UpdateDestCard(route)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme
    local c = theme.colors
    local dest = route.destination

    self.destCard:Show()
    self.destCard.title:SetText(dest.name or L["TAB_ROUTE"])
    theme:SetTextColor(self.destCard.title, c.text)

    local tagText = dest.custom and ns.LocationTags:FormatList(dest.tags)
    if tagText and tagText ~= "" then
        self.destCard.tags:SetText(tagText)
        theme:SetTextColor(self.destCard.tags, c.accent)
        self.destCard.tags:Show()
        self.destCard.detail:SetPoint("TOPLEFT", self.destCard.tags, "BOTTOMLEFT", 0, -1)
    else
        self.destCard.tags:Hide()
        self.destCard.detail:SetPoint("TOPLEFT", self.destCard.title, "BOTTOMLEFT", 0, -2)
    end

    if dest.custom then
        local lines = {}
        local mapInfo = dest.mapId and C_Map.GetMapInfo(dest.mapId)
        local area = (mapInfo and mapInfo.name) or dest.areaName or ""
        local coords = string.format("%.1f, %.1f", (dest.x or 0) * 100, (dest.y or 0) * 100)
        if area ~= "" then
            lines[#lines + 1] = string.format("%s (%s)", area, coords)
        else
            lines[#lines + 1] = coords
        end
        if dest.note and dest.note ~= "" then
            lines[#lines + 1] = dest.note
        end
        self.destCard.detail:SetText(table.concat(lines, "  ·  "))
    elseif dest.type then
        self.destCard.detail:SetText(dest.type:gsub("^%l", string.upper))
    else
        self.destCard.detail:SetText("")
    end
    theme:SetTextColor(self.destCard.detail, c.textMuted)

    local total = #route.steps
    local current = route.activeStepIndex or 1
    self.progressLabel:SetText(string.format(L["ROUTE_STEP_PROGRESS"], current, total))
end

function RouteTab:Build(parent, mainFrame)
    self.parent = parent
    self.mainFrame = mainFrame
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme

    local headerRow = CreateFrame("Frame", nil, parent)
    headerRow:SetPoint("TOPLEFT", 12, -10)
    headerRow:SetPoint("TOPRIGHT", -12, -10)
    headerRow:SetHeight(20)

    self.header = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    self.header:SetPoint("LEFT", 0, 0)
    self.header:SetText(L["ROUTE_HEADER"])
    theme:SetReadableFont(self.header, 14)
    theme:SetTextColor(self.header, theme.colors.text)

    self.progressLabel = headerRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.progressLabel:SetPoint("RIGHT", 0, 0)
    theme:SetTextColor(self.progressLabel, theme.colors.textMuted)

    self.destCard = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    self.destCard:SetPoint("TOPLEFT", 12, -34)
    self.destCard:SetPoint("TOPRIGHT", -12, -34)
    self.destCard:SetHeight(52)
    theme:StyleCard(self.destCard)
    self.destCard.title = self.destCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.destCard.title:SetPoint("TOPLEFT", 10, -8)
    self.destCard.title:SetPoint("TOPRIGHT", -10, -8)
    self.destCard.title:SetJustifyH("LEFT")
    self.destCard.tags = self.destCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.destCard.tags:SetPoint("TOPLEFT", self.destCard.title, "BOTTOMLEFT", 0, -2)
    self.destCard.tags:SetPoint("RIGHT", self.destCard.title, "RIGHT", 0, 0)
    self.destCard.tags:SetJustifyH("LEFT")
    self.destCard.detail = self.destCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.destCard.detail:SetPoint("TOPLEFT", self.destCard.tags, "BOTTOMLEFT", 0, -1)
    self.destCard.detail:SetPoint("RIGHT", self.destCard.title, "RIGHT", 0, 0)
    self.destCard.detail:SetJustifyH("LEFT")
    self.destCard:Hide()

    self.noticeCard = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    self.noticeCard:SetPoint("TOPLEFT", self.destCard, "BOTTOMLEFT", 0, -6)
    self.noticeCard:SetPoint("TOPRIGHT", self.destCard, "BOTTOMRIGHT", 0, -6)
    self.noticeCard:SetHeight(36)
    theme:StyleNoticeCard(self.noticeCard, "info")
    self.noticeCard.text = self.noticeCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.noticeCard.text:SetPoint("TOPLEFT", 10, -8)
    self.noticeCard.text:SetPoint("TOPRIGHT", -10, -8)
    self.noticeCard.text:SetJustifyH("LEFT")
    self.noticeCard.text:SetWordWrap(true)
    self.noticeCard:Hide()

    self.stepsHeader = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.stepsHeader:SetPoint("TOPLEFT", self.destCard, "BOTTOMLEFT", 0, -8)
    self.stepsHeader:SetText(L["ROUTE_STEPS_HEADER"])
    theme:SetTextColor(self.stepsHeader, theme.colors.sectionHeader)
    self.stepsHeader:Hide()

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", self.stepsHeader, "BOTTOMLEFT", -4, -4)
    local listContent = CreateFrame("Frame", nil, scroll)
    listContent:SetSize(1, 1)
    scroll:SetScrollChild(listContent)
    self.scroll = scroll
    self.listContent = listContent
    self.stepRows = {}

    self.emptyCard = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    self.emptyCard:SetPoint("TOPLEFT", 12, -34)
    self.emptyCard:SetPoint("TOPRIGHT", -12, -34)
    self.emptyCard:SetHeight(72)
    theme:StyleCard(self.emptyCard)
    self.emptyCard.title = self.emptyCard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    self.emptyCard.title:SetPoint("TOP", 0, -16)
    self.emptyCard.title:SetText(L["NO_ACTIVE_ROUTE"])
    self.emptyCard.hint = self.emptyCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.emptyCard.hint:SetPoint("TOP", self.emptyCard.title, "BOTTOM", 0, -4)
    self.emptyCard.hint:SetWidth(240)
    self.emptyCard.hint:SetJustifyH("CENTER")
    self.emptyCard.hint:SetText(L["ROUTE_EMPTY_HINT"])
    theme:SetTextColor(self.emptyCard.title, theme.colors.textMuted)
    theme:SetTextColor(self.emptyCard.hint, theme.colors.textMuted)

    local footer = CreateFrame("Frame", nil, parent)
    footer:SetPoint("BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", 0, 0)
    footer:SetHeight(46)
    footer:SetFrameLevel(parent:GetFrameLevel() + 8)
    footer:EnableMouse(true)
    self.footer = footer
    scroll:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", -20, 4)

    local function makeFooterBtn(label, variant, width)
        local btn = CreateFrame("Button", nil, footer, "BackdropTemplate")
        btn:SetSize(width or 80, self.FOOTER_BTN_HEIGHT)
        btn:SetText(label)
        theme:StyleSmallButton(btn, variant)
        return btn
    end

    local endBtn = makeFooterBtn(L["END_ROUTE"], "danger", 80)
    endBtn:SetScript("OnClick", function()
        ns.RouteTracker:End()
    end)

    local recalcBtn = makeFooterBtn(L["RECALCULATE"], nil, 88)
    recalcBtn:SetScript("OnClick", function()
        ns.RouteTracker:Recalculate()
    end)

    local completeBtn = makeFooterBtn(L["ROUTE_MARK_STEP"], nil, 96)
    completeBtn:SetScript("OnClick", function()
        if ns.RouteTracker and ns.RouteTracker.route then
            ns.RouteTracker:AdvanceStep(true)
        end
    end)
    completeBtn:SetScript("OnEnter", function(btn)
        local h = btn._themeHoverBg
        if h then
            btn:SetBackdropColor(h[1], h[2], h[3], 1)
        end
        GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        local key1, key2 = GetBindingKey("WOWGPS_STEP_COMPLETE")
        if key1 then
            local bindingText = GetBindingText(key1, "KEY_")
            if key2 then
                bindingText = bindingText .. ", " .. GetBindingText(key2, "KEY_")
            end
            GameTooltip:SetText(string.format(L["ROUTE_MARK_STEP_TIP"], bindingText), 1, 1, 1, true)
        else
            GameTooltip:SetText(L["ROUTE_MARK_STEP_TIP_UNBOUND"], 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    completeBtn:SetScript("OnLeave", function(btn)
        local b = btn._themeBaseBg
        if b then
            btn:SetBackdropColor(b[1], b[2], b[3], 1)
        end
        GameTooltip:Hide()
    end)

    self.endBtn = endBtn
    self.recalcBtn = recalcBtn
    self.completeBtn = completeBtn

    self.useBtns = {}
    for i = 1, self.MAX_USE_BUTTONS do
        local btn = CreateFrame("Button", nil, footer, "SecureActionButtonTemplate, BackdropTemplate")
        btn:SetSize(72, self.FOOTER_BTN_HEIGHT)
        btn:SetText(L["USE_ITEM"] or "Use")
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:SetFrameLevel(footer:GetFrameLevel() + 6)
        theme:StyleSmallButton(btn, "success")
        btn:SetScript("OnEnter", function(selfBtn)
            local h = selfBtn._themeHoverBg
            if h then
                selfBtn:SetBackdropColor(h[1], h[2], h[3], 1)
            end
            RouteTab:ShowUseTooltip(selfBtn)
        end)
        btn:SetScript("OnLeave", function(selfBtn)
            local b = selfBtn._themeBaseBg
            if b then
                selfBtn:SetBackdropColor(b[1], b[2], b[3], 1)
            end
            GameTooltip:Hide()
        end)
        btn:Hide()
        self.useBtns[i] = btn
    end

    if not self.combatFrame then
        local combatFrame = CreateFrame("Frame")
        combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        combatFrame:SetScript("OnEvent", function()
            if RouteTab._pendingUseUpdate then
                RouteTab:UpdateUseButtons()
                RouteTab:LayoutFooterButtons()
            end
        end)
        self.combatFrame = combatFrame
    end

    self:Refresh()
end

function RouteTab:ShowUseTooltip(btn)
    local act = btn and btn.useAction
    if not act then
        return
    end
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    GameTooltip:SetOwner(btn, "ANCHOR_TOP")
    GameTooltip:SetText(act.name or act.label or L["USE_ITEM"], 1, 1, 1)
    if act.available == false then
        GameTooltip:AddLine(L["TRAVEL_MISSING"], 1, 0.3, 0.3, true)
    else
        GameTooltip:AddLine(L["USE_ITEM_TIP"] or "Click to use this item.", 0.75, 0.98, 0.80, true)
    end
    if InCombatLockdown() then
        GameTooltip:AddLine(L["USE_ITEM_COMBAT"], 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

function RouteTab:ClearUseButton(btn)
    if not btn then
        return
    end
    btn:Hide()
    btn.useAction = nil
    if InCombatLockdown() then
        return
    end
    btn:SetAttribute("type", nil)
    btn:SetAttribute("macrotext", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("item", nil)
end

function RouteTab:UpdateUseButtons()
    if not self.useBtns then
        return
    end
    if InCombatLockdown() then
        self._pendingUseUpdate = true
        return
    end
    self._pendingUseUpdate = false

    local actions = {}
    local tracker = ns.RouteTracker
    local step = tracker and tracker.GetActiveStep and tracker:GetActiveStep()
    if step and ns.TravelActions and ns.TravelActions.GetStepUseActions then
        actions = ns.TravelActions:GetStepUseActions(step) or {}
    end

    for i, btn in ipairs(self.useBtns) do
        local act = actions[i]
        if act and act.macro then
            btn:SetText(act.label or "Use")
            if act.type == "spell" and act.id then
                btn:SetAttribute("type", "spell")
                btn:SetAttribute("spell", act.id)
                btn:SetAttribute("macrotext", nil)
            else
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", act.macro)
                btn:SetAttribute("spell", nil)
            end
            btn.useAction = act
            btn:Enable()
            btn:Show()
        else
            self:ClearUseButton(btn)
        end
    end
end

function RouteTab:LayoutFooterButtons()
    local footer = self.footer
    if not footer or not self.endBtn then
        return
    end

    local theme = ns.Theme
    local padL = self.FOOTER_PAD_LEFT
    local padR = self.FOOTER_PAD_RIGHT
    local gap = self.FOOTER_GAP
    local btnH = self.FOOTER_BTN_HEIGHT
    local bottom = self.FOOTER_BTN_BOTTOM
    local parentW = (self.parent and self.parent:GetWidth()) or footer:GetWidth() or 300
    local avail = math.max(120, parentW - padL - padR)

    local function shownList(...)
        local list = {}
        for i = 1, select("#", ...) do
            local btn = select(i, ...)
            if btn and btn:IsShown() then
                list[#list + 1] = btn
            end
        end
        return list
    end

    local function desiredWidth(btn, minW, maxW)
        local textW = (theme.GetButtonTextWidth and theme:GetButtonTextWidth(btn) or 50) + 16
        return math.max(minW, math.min(maxW, textW))
    end

    local function sumWidths(list)
        local w = 0
        for i, btn in ipairs(list) do
            w = w + (btn._want or btn:GetWidth() or 0) + (i > 1 and gap or 0)
        end
        return w
    end

    local function shrinkToFit(list, budget)
        local total = sumWidths(list)
        if total <= budget or #list == 0 then
            return
        end
        local scale = budget / total
        for _, btn in ipairs(list) do
            btn._want = math.max(48, math.floor((btn._want or 48) * scale))
        end
        total = sumWidths(list)
        while total > budget do
            local shrunk = false
            for _, btn in ipairs(list) do
                if btn._want > 48 then
                    btn._want = btn._want - 1
                    shrunk = true
                end
            end
            total = sumWidths(list)
            if not shrunk then
                break
            end
        end
    end

    local nav = shownList(self.endBtn, self.recalcBtn, self.completeBtn)
    local uses = shownList(unpack(self.useBtns or {}))

    for _, btn in ipairs(nav) do
        btn._want = desiredWidth(btn, 56, 110)
    end
    for _, btn in ipairs(uses) do
        btn._want = desiredWidth(btn, 56, 150)
    end

    local navW = sumWidths(nav)
    local useW = sumWidths(uses)
    local twoRow = #uses > 0 and (navW + (#uses > 0 and gap or 0) + useW) > avail

    if twoRow then
        shrinkToFit(nav, avail)
        shrinkToFit(uses, avail)
    else
        local navBudget = avail - (useW > 0 and (useW + gap) or 0)
        shrinkToFit(nav, math.max(120, navBudget))
        navW = sumWidths(nav)
        local useBudget = avail - navW - (#uses > 0 and gap or 0)
        shrinkToFit(uses, math.max(56, useBudget))
    end

    for _, btn in ipairs(nav) do
        btn:SetWidth(btn._want)
    end
    for _, btn in ipairs(uses) do
        btn:SetWidth(btn._want)
    end

    local function placeRow(list, y, fromLeft)
        if #list == 0 then
            return
        end
        if fromLeft then
            local x = padL
            for _, btn in ipairs(list) do
                btn:ClearAllPoints()
                btn:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", x, y)
                x = x + btn:GetWidth() + gap
            end
        else
            local total = sumWidths(list)
            local x = (parentW - total) / 2
            x = math.max(padL, math.min(x, parentW - padR - total))
            for _, btn in ipairs(list) do
                btn:ClearAllPoints()
                btn:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", x, y)
                x = x + btn:GetWidth() + gap
            end
        end
    end

    if twoRow then
        footer:SetHeight(bottom + btnH + gap + btnH + 8)
        placeRow(uses, bottom + btnH + gap, false)
        placeRow(nav, bottom, true)
    else
        footer:SetHeight(bottom + btnH + 8)
        self.endBtn:ClearAllPoints()
        if self.endBtn:IsShown() then
            self.endBtn:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", padL, bottom)
        end

        local rightX = padR
        if self.completeBtn:IsShown() then
            self.completeBtn:ClearAllPoints()
            self.completeBtn:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -rightX, bottom)
            rightX = rightX + self.completeBtn:GetWidth() + gap
        end
        if self.recalcBtn:IsShown() then
            self.recalcBtn:ClearAllPoints()
            self.recalcBtn:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -rightX, bottom)
        end

        if #uses > 0 then
            local leftEdge = padL + (self.endBtn:IsShown() and (self.endBtn:GetWidth() + gap) or 0)
            local rightEdge = parentW - padR
            if self.completeBtn:IsShown() then
                rightEdge = rightEdge - self.completeBtn:GetWidth() - gap
            end
            if self.recalcBtn:IsShown() then
                rightEdge = rightEdge - self.recalcBtn:GetWidth() - gap
            end
            local total = sumWidths(uses)
            local x = leftEdge + math.max(0, (rightEdge - leftEdge - total) / 2)
            x = math.max(leftEdge, math.min(x, math.max(leftEdge, rightEdge - total)))
            for _, btn in ipairs(uses) do
                btn:ClearAllPoints()
                btn:SetPoint("BOTTOMLEFT", footer, "BOTTOMLEFT", x, bottom)
                x = x + btn:GetWidth() + gap
            end
        end
    end
end

function RouteTab:FinishLayout()
    self:UpdateUseButtons()
    self:LayoutFooterButtons()
end

function RouteTab:Refresh()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme
    local tracker = ns.RouteTracker
    local route = tracker and tracker.route
    local pending = tracker and tracker.pendingDest
    local calculating = tracker and tracker.calculating

    for _, row in ipairs(self.stepRows) do
        row:Hide()
    end

    if not route then
        self.stepsHeader:Hide()
        self.listContent:Hide()
        self.recalcBtn:Hide()
        self.completeBtn:Hide()

        if calculating and pending then
            self.emptyCard:Hide()
            self:UpdateDestCard({
                destination = pending,
                steps = {},
                activeStepIndex = 0,
            })
            self.progressLabel:SetText(L["ROUTE_CALCULATING"])
            self.noticeCard.text:SetText(string.format(
                L["ROUTE_CALCULATING_HINT"],
                pending.name or L["TAB_ROUTE"]
            ))
            theme:SetTextColor(self.noticeCard.text, theme.colors.notice)
            theme:StyleNoticeCard(self.noticeCard, "info")
            self.noticeCard:Show()
            self.noticeCard:SetPoint("TOPLEFT", self.destCard, "BOTTOMLEFT", 0, -6)
            self.endBtn:Show()
            self:FinishLayout()
            return
        end

        self.progressLabel:SetText("")
        self.destCard:Hide()
        self.noticeCard:Hide()
        self.emptyCard.title:SetText(L["NO_ACTIVE_ROUTE"])
        self.emptyCard.hint:SetText(L["ROUTE_EMPTY_HINT"])
        self.emptyCard:Show()
        self.endBtn:Hide()
        self:FinishLayout()
        return
    end

    self.endBtn:Show()
    self.recalcBtn:Show()
    self.completeBtn:Show()
    self.emptyCard:Hide()
    self.listContent:Show()
    self:UpdateDestCard(route)

    local noticeText
    local noticeTone = "info"
    if route.routeWarnings and #route.routeWarnings > 0 then
        noticeText = table.concat(route.routeWarnings, " ")
        noticeTone = "warn"
    elseif route.warning and route.warning ~= "" then
        noticeText = route.warning
        noticeTone = "warn"
    elseif route.fallback then
        noticeText = L["ROUTE_FALLBACK_NOTE"]
    end

    if noticeText then
        self.noticeCard.text:SetText(noticeText)
        theme:SetTextColor(self.noticeCard.text, noticeTone == "warn" and theme.colors.accent or theme.colors.notice)
        theme:StyleNoticeCard(self.noticeCard, noticeTone)
        self.noticeCard:Show()
        self.noticeCard:SetPoint("TOPLEFT", self.destCard, "BOTTOMLEFT", 0, -6)
        self.stepsHeader:SetPoint("TOPLEFT", self.noticeCard, "BOTTOMLEFT", 0, -8)
    else
        self.noticeCard:Hide()
        self.stepsHeader:SetPoint("TOPLEFT", self.destCard, "BOTTOMLEFT", 0, -8)
    end
    self.stepsHeader:Show()

    local active = route.activeStepIndex
    local navStep = ns.SubStepResolver:GetNavigationStep(route)
    local rowIndex = 0
    local y = -2

    for i, step in ipairs(route.steps) do
        rowIndex = rowIndex + 1
        local row = self:GetOrCreateStepRow(rowIndex)
        local isNav = (i == active and not (navStep and navStep.isSubStep))
        self:StyleStepRow(row, i, step, route, i == active, isNav, false)
        row:SetPoint("TOPLEFT", 0, y)
        row:Show()
        y = y - self.STEP_HEIGHT - self.STEP_GAP

        if i == active then
            local subs = ns.SubStepResolver:GetSubStepsForDisplay(route, i)
            local subNum = 0
            for _, sub in ipairs(subs) do
                if not sub.completed then
                    subNum = subNum + 1
                    rowIndex = rowIndex + 1
                    local subRow = self:GetOrCreateStepRow(rowIndex)
                    local subNav = (navStep == sub)
                    self:StyleStepRow(subRow, subNum, sub, route, true, subNav, true)
                    subRow:SetPoint("TOPLEFT", 8, y)
                    subRow:Show()
                    y = y - self.SUBSTEP_HEIGHT - self.STEP_GAP
                end
            end
        end
    end

    self.listContent:SetSize(self:GetListWidth(), math.max(1, -y))
    self:FinishLayout()
end

function RouteTab:Show()
    self.parent:Show()
    self:Refresh()
end

function RouteTab:Hide()
    self.parent:Hide()
end
