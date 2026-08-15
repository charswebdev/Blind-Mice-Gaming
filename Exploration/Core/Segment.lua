local addon = Exploration

local L = addon.uiLayout
local W = L.listWidth or (L.contentWidth - L.scrollW)
local scrollInset = L.scrollW or 24
local frame = addon.ui.SegmentFrame
local rowH = 22
local routeRowH = 34
local visibleRows = 10
local MEGA_JOURNEY = "Exploration Mega-Journey"

local function shortenLabel(text, maxLen)
    text = tostring(text or "")
    if #text <= maxLen then
        return text
    end
    return text:sub(1, maxLen - 3) .. "..."
end

local function setContextText(text)
    local maxW = W - 24
    text = tostring(text or "")
    frame.context:SetText(text)
    local guard = 0
    while frame.context:GetStringWidth() > maxW and guard < 300 do
        guard = guard + 1
        local len = #text
        if len <= 12 then break end
        text = text:sub(1, len - 4) .. "..."
        frame.context:SetText(text)
    end
end

local function routeLabel(name)
    local route = addon.data.routes[name]
    return shortenLabel(addon:LocalizedString(route and route.display or name), 32)
end

local function sortRouteItems(items)
    table.sort(items, function(a, b)
        if a._beginJourney ~= b._beginJourney then
            return a._beginJourney == true
        end
        local aLeaf = not a.children or #a.children == 0
        local bLeaf = not b.children or #b.children == 0
        if aLeaf ~= bLeaf then return not aLeaf end
        return (a.display or a.name):lower() < (b.display or b.name):lower()
    end)
end

local function countWaypoints(routeDef)
    if not routeDef or not routeDef.route then return 0 end
    local n = 0
    for _, step in ipairs(routeDef.route) do
        -- Name-only travel steps (zone/buff triggers) still count as runnable.
        if type(step) == "table"
            and not step.switch
            and not step.condition
            and (step.map or step.x or step.name)
        then
            n = n + 1
        end
    end
    return n
end

local function routeHasWaypoints(name)
    return countWaypoints(addon.data.routes[name]) > 0
end

local function hasChildren(node)
    return node.children and #node.children > 0
end

local function startRunFromNode(node)
    if not node then
        print("|cff00ccffExploration:|r Can't start — segment missing.")
        return
    end
    frame.browsingStack = {}
    -- Start must work even if a parked/leftover run exists — never require Abandon.
    if addon.active and addon.ParkActiveJourney then
        addon:ParkActiveJourney()
    elseif addon.waypoint and addon.waypoint.index and addon.ParkActiveJourney then
        addon:ParkActiveJourney()
    end
    local leaf = addon.FindFirstLeaf and addon:FindFirstLeaf(node) or node
    addon:UpdateActive(leaf)
    if addon.active and addon.waypoint and addon.waypoint.index then
        local label = node.display or node.name
        if node.name == MEGA_JOURNEY or label == node.name then
            local rootName = leaf.path and leaf.path[1]
            local root = rootName and addon.data.routes and addon.data.routes[rootName]
            label = (root and root.display) or rootName or leaf.name
        end
        print("|cff00ccffExploration:|r Route started: " .. addon:LocalizedString(label))
    else
        print("|cff00ccffExploration:|r Could not start that segment. Try /exp abandon then Begin again.")
    end
    frame:Refresh()
end

local function openNode(node)
    local current = node
    while hasChildren(current) and #current.children == 1 do
        local child = current.children[1]
        if hasChildren(child) then
            frame.browsingStack[#frame.browsingStack + 1] = current
            current = child
        elseif routeHasWaypoints(child.name) then
            startRunFromNode(child)
            return
        else
            frame.browsingStack[#frame.browsingStack + 1] = current
            current = child
        end
    end

    if hasChildren(current) then
        frame.browsingStack[#frame.browsingStack + 1] = current
        frame:Refresh()
        return
    end

    if routeHasWaypoints(current.name) then
        startRunFromNode(current)
        return
    end

    -- Last resort: first leaf under the original node (covers name-only steps).
    local leaf = addon.FindFirstLeaf and addon:FindFirstLeaf(node) or current
    if leaf then
        startRunFromNode(leaf)
        return
    end
    print("|cff00ccffExploration:|r Can't start that segment (no steps found).")
end

local function getBrowseRoots()
    local roots = {}
    for _, node in pairs(addon.menu) do
        roots[#roots + 1] = node
    end
    table.sort(roots, function(a, b)
        return (a.display or a.name):lower() < (b.display or b.name):lower()
    end)
    return roots
end

local function findChildByName(parent, name)
    for _, child in ipairs(parent.children or {}) do
        if child.name == name then
            return child
        end
    end
    return nil
end

-- Mega-Journey "Getting There" entries that open a player-facing chapter.
local function isChapterGettingThere(routeName, route)
    if type(routeName) ~= "string" or not routeName:find("Getting There", 1, true) then
        return false
    end
    local display = route and route.display or ""
    if display:find("Getting There", 1, true) then
        return true
    end
    -- e.g. "Legion - Getting There", "Midnight - Getting There"
    if routeName:match("Getting There$") then
        return true
    end
    -- e.g. "MoP - Getting There - Standard"
    if routeName:find("Getting There %- Standard", 1, true) then
        return true
    end
    return false
end

local function chapterTitle(routeName, route)
    local display = route and route.display or routeName
    local cleaned = display
        :gsub("%s*%-%s*|c%x+|Getting There|r", "")
        :gsub("%s*%-%s*Getting There.*", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if cleaned ~= "" and cleaned ~= display then
        return cleaned
    end
    local fromName = routeName:match("^(.-) %- Getting There") or routeName
    return (fromName:gsub(" %- Standard$", ""))
end

local function buildMegaChapterItems(megaNode)
    local items = {
        {
            name = megaNode.name,
            display = "Full Journey (10–90)",
            path = megaNode.path,
            children = {},
            _beginJourney = true,
            _startNode = megaNode,
            _meta = "Start from the beginning",
        },
    }
    local megaRoute = addon.data.routes and addon.data.routes[megaNode.name]
    for _, routeName in ipairs(megaRoute and megaRoute.route or {}) do
        local route = addon.data.routes and addon.data.routes[routeName]
        if isChapterGettingThere(routeName, route) then
            local startNode = findChildByName(megaNode, routeName)
            if startNode then
                items[#items + 1] = {
                    name = routeName,
                    display = chapterTitle(routeName, route),
                    path = startNode.path,
                    children = {},
                    _beginJourney = true,
                    _startNode = startNode,
                    _meta = "Begin Getting There",
                }
            end
        end
    end
    return items
end

local function appendOtherJourneyRoots(items, roots, skipName)
    for _, node in ipairs(roots) do
        if node.name ~= skipName then
            items[#items + 1] = {
                name = node.name,
                display = node.display or node.name,
                path = node.path,
                children = {},
                _beginJourney = true,
                _startNode = node,
                _meta = "Begin this journey",
            }
        end
    end
end

function frame:Initialize()
    if frame._built or frame._building then return end
    frame._building = true

    frame.browsingStack = {}

    frame.contextBar = CreateFrame("Frame", nil, frame)
    frame.contextBar:SetPoint("TOPLEFT", frame, "TOPLEFT", L.pad, 0)
    frame.contextBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -L.pad, 0)
    frame.contextBar:SetHeight(L.contextH)

    frame.context = frame.contextBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.context:SetPoint("LEFT", frame.contextBar, "LEFT", 0, 0)
    frame.context:SetPoint("RIGHT", frame.contextBar, "RIGHT", -22, 0)
    frame.context:SetHeight(L.contextH)
    frame.context:SetJustifyH("LEFT")
    frame.context:SetJustifyV("MIDDLE")
    frame.context:SetWordWrap(false)
    addon:StyleFont(frame.context, "crumb")

    frame.back = CreateFrame("Button", nil, frame.contextBar)
    frame.back:SetSize(18, 18)
    frame.back:SetPoint("RIGHT", frame.contextBar, "RIGHT", 0, 0)
    frame.back:SetNormalTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Up")
    frame.back:SetPushedTexture("Interface\\Buttons\\UI-Panel-BiggerButton-Down")
    frame.back:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    frame.back:SetScript("OnClick", function()
        table.remove(frame.browsingStack)
        frame:Refresh()
    end)
    frame.back:Hide()

    addon:HRule(frame, -(L.contextH + 2), L.pad)

    local top = -(L.contextH + 6)

    local function setupScroll(scroll)
        scroll:SetClipsChildren(true)
        local bar = scroll.ScrollBar
        if not bar then return end
        bar:SetWidth(8)
        if bar.ScrollUpButton then bar.ScrollUpButton:Hide() end
        if bar.ScrollDownButton then bar.ScrollDownButton:Hide() end
    end

    frame.footer = CreateFrame("Frame", nil, frame)
    frame.footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.footer:SetHeight(L.footerH)
    frame.footer:SetFrameLevel(frame:GetFrameLevel() + 30)
    frame.footer:EnableMouse(true)
    -- Opaque band so progress bars never paint over the journey list.
    frame.footer.bg = frame.footer:CreateTexture(nil, "BACKGROUND")
    frame.footer.bg:SetAllPoints(frame.footer)
    addon:ColorTexture(frame.footer.bg, addon.theme.panel)
    addon:HRule(frame.footer, 0, L.pad)

    frame.routesscroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.routesscroll:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.routesscroll:EnableMouse(true)
    frame.routesscroll:SetPoint("TOPLEFT", frame, "TOPLEFT", L.pad, top)
    frame.routesscroll:SetPoint("BOTTOMRIGHT", frame.footer, "TOPRIGHT", -L.pad - scrollInset, 4)
    frame.routescontent = CreateFrame("Frame", nil, frame.routesscroll)
    frame.routescontent:EnableMouse(false)
    frame.routesscroll:SetScrollChild(frame.routescontent)
    frame.routes = {}
    setupScroll(frame.routesscroll)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", L.pad, top)
    frame.scroll:SetPoint("BOTTOMRIGHT", frame.footer, "TOPRIGHT", -L.pad - scrollInset, 4)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.scroll:SetScrollChild(frame.content)
    frame.rows = {}
    frame.scroll:Hide()
    setupScroll(frame.scroll)

    -- Stretch to footer width (content is inset; L.width would overflow the window).
    frame.zoneBar = addon:CreateProgressBar(frame.footer, nil, "Zone")
    frame.zoneBar:SetPoint("BOTTOMLEFT", frame.footer, "BOTTOMLEFT", L.pad, 56)
    frame.zoneBar:SetPoint("BOTTOMRIGHT", frame.footer, "BOTTOMRIGHT", -L.pad, 56)
    frame.journeyBar = addon:CreateProgressBar(frame.footer, nil, "Journey")
    frame.journeyBar:SetPoint("BOTTOMLEFT", frame.footer, "BOTTOMLEFT", L.pad, 36)
    frame.journeyBar:SetPoint("BOTTOMRIGHT", frame.footer, "BOTTOMRIGHT", -L.pad, 36)

    frame.leftBtns = CreateFrame("Frame", nil, frame.footer)
    frame.leftBtns:SetPoint("BOTTOMLEFT", frame.footer, "BOTTOMLEFT", L.pad, 6)
    frame.leftBtns:SetSize(1, 22)
    frame.leftBtns:SetFrameLevel(frame.footer:GetFrameLevel() + 5)

    frame.rightBtns = CreateFrame("Frame", nil, frame.footer)
    frame.rightBtns:SetPoint("BOTTOMRIGHT", frame.footer, "BOTTOMRIGHT", -L.pad, 6)
    frame.rightBtns:SetSize(1, 22)
    frame.rightBtns:SetFrameLevel(frame.footer:GetFrameLevel() + 5)

    -- Journey controls live in the window title bar so long footer actions
    -- (e.g. "Use Lucky Tortollan Charm") never overlap Abandon/Change.
    local host = addon.ui
    frame.headerBtns = CreateFrame("Frame", nil, host)
    frame.headerBtns:SetSize(1, 18)
    frame.headerBtns:SetFrameStrata(host:GetFrameStrata())
    frame.headerBtns:SetFrameLevel(
        (host.lockBtn and host.lockBtn:GetFrameLevel() or host:GetFrameLevel()) + 20
    )

    local function addHeaderBtn(text, width)
        return addon:CreateButton(frame.headerBtns, width, 18, text)
    end

    local function addLeftBtn(text, width)
        return addon:CreateButton(frame.leftBtns, width, 22, text)
    end

    local function addRightBtn(text, width)
        return addon:CreateButton(frame.rightBtns, width, 22, text)
    end

    frame.abandon = addHeaderBtn("Abandon", 56)
    frame.abandon:SetScript("OnClick", function() addon:ClearActive(); frame:Refresh() end)
    frame.abandon:Disable()

    frame.change = addHeaderBtn("Change", 48)
    frame.change:SetScript("OnClick", function()
        if addon.active and addon.SaveProgress then
            addon:SaveProgress()
        end
        if addon.ParkActiveJourney then
            addon:ParkActiveJourney()
        end
        frame.browsingStack = {}
        frame:Refresh()
    end)
    frame.change:Hide()

    frame.resume = addHeaderBtn("Resume", 48)
    frame.resume:SetScript("OnClick", function()
        if addon.ResumeProgress and addon:ResumeProgress() then
            if addon.SyncActiveSegmentLearnedInserts then
                addon:SyncActiveSegmentLearnedInserts()
            end
            if addon.ui and addon.ui.Refresh then addon.ui:Refresh() end
            frame:Refresh()
        end
    end)
    frame.resume:Hide()

    frame.prevStep = addLeftBtn("Prev", 40)
    frame.prevStep:SetScript("OnClick", function() addon:PreviousStep() end)
    frame.prevStep:Disable()

    frame.prevSeg = addLeftBtn("Prev Seg", 58)
    frame.prevSeg:SetScript("OnClick", function() addon:JumpToPreviousSegment(); frame:Refresh() end)
    frame.prevSeg:Disable()

    frame.nextSeg = addRightBtn("Next Seg", 58)
    frame.nextSeg:SetScript("OnClick", function() addon:JumpToNextSegment(); frame:Refresh() end)
    frame.nextSeg:Disable()

    frame.next = addRightBtn("Mark", 40)
    frame.next:SetScript("OnClick", function()
        if addon.ActivePinNeedsMark and addon:ActivePinNeedsMark() then
            if addon.MarkCurrentDiscovered then
                addon:MarkCurrentDiscovered("button")
            end
        elseif addon.AdvanceStep then
            addon:AdvanceStep("button")
        elseif addon.MarkCurrentDiscovered then
            -- AdvanceStep delegates here; travel skips confirm inside Mark UX.
            addon:MarkCurrentDiscovered("button")
        end
    end)
    frame.next:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if addon.ActivePinNeedsMark and addon:ActivePinNeedsMark() then
            GameTooltip:SetText("Mark Discovered", 1, 0.82, 0)
            GameTooltip:AddLine("Skip this fog pin for this character when Discover XP will not fire.", 1, 1, 1, true)
        else
            GameTooltip:SetText("Next", 1, 0.82, 0)
            GameTooltip:AddLine("Advance the current stop.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    frame.next:SetScript("OnLeave", GameTooltip_Hide)
    frame.next:Disable()

    frame.actionBtns = {}
    for i = 1, 3 do
        local btn = addon:CreateSecureActionButton(frame.footer, 72, 22, "Use")
        btn:SetFrameLevel(frame.footer:GetFrameLevel() + 6)
        btn:RegisterForClicks("AnyUp", "AnyDown")
        btn:Hide()
        frame.actionBtns[i] = btn
    end
    frame.actionBtn = frame.actionBtns[1]

    frame._built = true
    frame._building = nil
    frame:Refresh()
end

function frame:UpdateFooterAction(actions)
    if actions and actions.macro then
        actions = { actions }
    end
    actions = actions or {}

    for i, btn in ipairs(self.actionBtns or {}) do
        local act = actions[i]
        if act and addon.active and (act.macro or act.housingTeleport) then
            local label = act.label or "Use"
            btn:SetText(label)
            btn:SetWidth(math.min(160, math.max(72, btn:GetTextWidth() + 16)))
            if act.housingTeleport then
                local ready = addon:ConfigureHousingTeleportButton(btn)
                if ready then
                    btn:Enable()
                    btn:Show()
                else
                    -- Still show so the player can retry after house list loads / combat ends.
                    btn:Enable()
                    btn:Show()
                    btn:SetScript("PreClick", function()
                        addon:ConfigureHousingTeleportButton(btn)
                    end)
                end
            else
                if addon.ClearHousingTeleportButton then
                    addon:ClearHousingTeleportButton(btn)
                end
                btn:SetScript("PreClick", nil)
                btn:SetAttribute("type", "macro")
                btn:SetAttribute("macrotext", act.macro)
                btn:Enable()
                btn:Show()
            end
        else
            if addon.ClearHousingTeleportButton then
                addon:ClearHousingTeleportButton(btn)
            end
            btn:SetScript("PreClick", nil)
            btn:Hide()
            btn:SetAttribute("type", nil)
            btn:SetAttribute("macrotext", nil)
        end
    end

    if addon.SyncActionKeybindButtons then
        addon:SyncActionKeybindButtons(actions)
    end
end

function frame:LayoutHeaderButtons()
    if not frame.headerBtns then return end
    local gap = 3
    local shown = {}
    for _, btn in ipairs({ frame.abandon, frame.change, frame.resume }) do
        if btn and btn:IsShown() then
            shown[#shown + 1] = btn
        end
    end

    local totalW = 0
    for i, btn in ipairs(shown) do
        totalW = totalW + btn:GetWidth() + (i > 1 and gap or 0)
    end
    frame.headerBtns:SetWidth(math.max(1, totalW))
    frame.headerBtns:ClearAllPoints()

    local host = addon.ui
    if host and host.lockBtn then
        frame.headerBtns:SetPoint("RIGHT", host.lockBtn, "LEFT", -4, 0)
    elseif host and host.CloseButton then
        frame.headerBtns:SetPoint("RIGHT", host.CloseButton, "LEFT", -4, 0)
    elseif host then
        frame.headerBtns:SetPoint("TOPRIGHT", host, "TOPRIGHT", -28, -5)
    end

    local x = 0
    for _, btn in ipairs(shown) do
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", frame.headerBtns, "LEFT", x, 0)
        x = x + btn:GetWidth() + gap
    end

    -- Keep title-bar controls only while the Segment tab is visible.
    frame.headerBtns:SetShown(frame:IsShown() and #shown > 0)
end

function frame:LayoutFooterButtons()
    local gap = 4
    local x = 0
    for _, btn in ipairs({ frame.prevStep, frame.prevSeg }) do
        btn:ClearAllPoints()
        if btn:IsShown() then
            btn:SetPoint("LEFT", frame.leftBtns, "LEFT", x, 0)
            x = x + btn:GetWidth() + gap
        end
    end
    frame.leftBtns:SetWidth(math.max(1, x > 0 and (x - gap) or 1))

    x = 0
    for _, btn in ipairs({ frame.nextSeg, frame.next }) do
        btn:ClearAllPoints()
        if btn:IsShown() then
            btn:SetPoint("RIGHT", frame.rightBtns, "RIGHT", -x, 0)
            x = x + btn:GetWidth() + gap
        end
    end
    frame.rightBtns:SetWidth(math.max(1, x > 0 and (x - gap) or 1))

    local shown = {}
    for _, btn in ipairs(frame.actionBtns or {}) do
        if btn:IsShown() then
            shown[#shown + 1] = btn
        end
    end
    if #shown > 0 then
        local actionGap = 4
        local totalW = -actionGap
        for _, btn in ipairs(shown) do
            totalW = totalW + btn:GetWidth() + actionGap
        end
        local ax = -totalW / 2
        for _, btn in ipairs(shown) do
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOM", frame.footer, "BOTTOM", ax + btn:GetWidth() / 2, 6)
            ax = ax + btn:GetWidth() + actionGap
        end
    end
end

function frame:UpdateProgressBars()
    if not frame.zoneBar or not frame.journeyBar then
        if not frame._building then
            frame:Initialize()
        end
        if not frame.zoneBar or not frame.journeyBar then
            return
        end
    end
    local zoneDone, zoneTotal = addon:GetZoneProgress()
    local journeyDone, journeyTotal = addon:GetJourneyProgress()
    if zoneTotal > 0 then
        frame.zoneBar:SetMinMaxValues(0, zoneTotal)
        frame.zoneBar:SetValue(zoneDone)
        addon:SetProgressBarText(frame.zoneBar, zoneDone, zoneTotal)
        frame.zoneBar:Show()
    else
        frame.zoneBar:Hide()
    end
    if journeyTotal > 0 then
        frame.journeyBar:SetMinMaxValues(0, journeyTotal)
        frame.journeyBar:SetValue(journeyDone)
        addon:SetProgressBarText(frame.journeyBar, journeyDone, journeyTotal)
        frame.journeyBar:Show()
    else
        frame.journeyBar:Hide()
    end
end

function frame:Refresh()
    if not frame._built then
        if not frame._building then
            frame:Initialize()
        end
        if not frame._built then
            return
        end
    end
    frame:UpdateProgressBars()
    if addon.waypoint.index then
        frame.routesscroll:Hide()
        frame.back:Hide()
        frame:ShowActiveSegment()
    else
        frame.scroll:Hide()
        frame:ShowBrowseView()
    end
    local hasActive = addon.active ~= nil
    local hasSavedRun = addon.HasSavedActiveJourney and addon:HasSavedActiveJourney()
    frame.abandon:SetShown(hasActive or hasSavedRun)
    frame.abandon:SetEnabled(hasActive or hasSavedRun)
    frame.change:SetShown(hasActive)
    frame.change:SetEnabled(hasActive)
    frame.resume:SetShown(hasSavedRun and not hasActive)
    frame.resume:SetEnabled(hasSavedRun and not hasActive)
    frame.next:SetShown(hasActive)
    frame.next:SetEnabled(hasActive and addon.waypoint.index ~= nil)
    if hasActive and frame.next then
        if addon.ActivePinNeedsMark and addon:ActivePinNeedsMark() then
            frame.next:SetText("Mark")
            frame.next:SetWidth(math.max(40, frame.next:GetTextWidth() + 16))
        else
            frame.next:SetText("Next")
            frame.next:SetWidth(math.max(40, frame.next:GetTextWidth() + 16))
        end
    end
    if hasActive then
        local root = addon.menu[addon.active.path[1]]
        local canPrevSeg = addon:FindPreviousLeaf(root, addon.active.path) ~= nil
        local canNextSeg = addon:FindNextLeaf(root, addon.active.path) ~= nil
        local canPrevStep = addon.waypoint.index and addon.waypoint.index > 1
        frame.prevStep:SetShown(canPrevStep)
        frame.prevStep:SetEnabled(canPrevStep)
        frame.prevSeg:SetShown(canPrevSeg)
        frame.prevSeg:SetEnabled(canPrevSeg)
        frame.nextSeg:SetShown(canNextSeg)
        frame.nextSeg:SetEnabled(canNextSeg)
    else
        frame.prevStep:Hide()
        frame.prevSeg:Hide()
        frame.nextSeg:Hide()
    end
    frame:LayoutHeaderButtons()
    frame:LayoutFooterButtons()
end

function frame:ShowBrowseView()
    local items = {}
    local roots = getBrowseRoots()
    local parent
    local preserveOrder = false

    local megaRoot
    for _, node in ipairs(roots) do
        if node.name == MEGA_JOURNEY then
            megaRoot = node
            break
        end
    end

    if #frame.browsingStack == 0 and megaRoot then
        -- Journey picker: Full tour + each expansion Getting There + other segment roots.
        items = buildMegaChapterItems(megaRoot)
        appendOtherJourneyRoots(items, roots, MEGA_JOURNEY)
        frame.context:SetText("Select a journey")
        frame.back:Hide()
        preserveOrder = true
    elseif #frame.browsingStack == 0 and #roots == 1 then
        parent = roots[1]
        setContextText(addon:LocalizedString(parent.display or parent.name))
        frame.back:Hide()
    elseif #frame.browsingStack == 0 then
        for _, node in ipairs(roots) do
            items[#items + 1] = node
        end
        frame.context:SetText("Select a journey")
        frame.back:Hide()
    else
        parent = frame.browsingStack[#frame.browsingStack]
        local parts = {}
        for _, node in ipairs(frame.browsingStack) do
            parts[#parts + 1] = shortenLabel(addon:LocalizedString(node.display or node.name), 32)
        end
        setContextText(table.concat(parts, "  ›  "))
        frame.back:Show()
    end

    if parent then
        if parent.name == MEGA_JOURNEY then
            items = buildMegaChapterItems(parent)
            preserveOrder = true
        else
            for _, child in ipairs(parent.children) do
                items[#items + 1] = child
            end
        end
    end

    if not preserveOrder then
        sortRouteItems(items)
    end
    for i, node in ipairs(items) do frame:UpdateRoutesRow(i, node) end
    if #items < #frame.routes then
        for i = #items + 1, #frame.routes do frame.routes[i]:Hide() end
    end
    frame.routescontent:SetSize(W, math.max(1, #items) * routeRowH)
    frame.routesscroll:Show()
end

function frame:ShowActiveSegment()
    if not addon.active or not addon.active.path then
        addon.waypoint.index = nil
        frame.scroll:Hide()
        frame:ShowBrowseView()
        return
    end
    local parts = {}
    if #addon.active.path > 3 then
        parts[1] = routeLabel(addon.active.path[1])
        parts[2] = "…"
        parts[3] = routeLabel(addon.active.path[#addon.active.path])
    else
        for _, name in ipairs(addon.active.path) do
            parts[#parts + 1] = routeLabel(name)
        end
    end
    setContextText(table.concat(parts, "  ›  "))

    local routeLen = #addon.segment.route
    if routeLen ~= frame._lastRouteLen then
        frame._lastRouteLen = routeLen
        for i = 1, routeLen do
            if frame.rows[i] then
                frame.rows[i]:ClearAllPoints()
                frame.rows[i]:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(i - 1) * rowH)
                frame.rows[i].rowIndex = i
            end
        end
    end

    for index, waypoint in ipairs(addon.segment.route) do
        frame:UpdateRow(index, waypoint)
    end
    if routeLen < #frame.rows then
        for i = routeLen + 1, #frame.rows do frame.rows[i]:Hide() end
    end
    frame.content:SetSize(W, routeLen * rowH)

    local half = math.floor(visibleRows / 2)
    local maxScroll = math.max(0, frame.content:GetHeight() - frame.scroll:GetHeight())
    local idx = frame._scrollToIndex or addon.waypoint.index or 1
    frame._scrollToIndex = nil
    local scrollPos = 0
    if idx > half and routeLen > visibleRows then
        scrollPos = math.min(maxScroll, (idx - half - 1) * rowH)
    elseif idx > 1 and routeLen > visibleRows then
        scrollPos = math.min(maxScroll, (idx - 1) * rowH)
    end
    frame.scroll:Show()
    frame.scroll:SetVerticalScroll(scrollPos)
end

local function rowLeft(index)
    addon.segment.route[index].discovered = false
    addon.waypoint.index = index
    addon:UpdateWaypointArrow()
    frame:Refresh()
    addon:SaveProgress()
end

local function rowRight(index)
    local markingDone = not addon.segment.route[index].discovered
    addon.segment.route[index].discovered = not addon.segment.route[index].discovered
    if index == addon.waypoint.index then
        if markingDone and addon.ArmProximityRearmFromPlayer then
            addon:ArmProximityRearmFromPlayer()
        end
        addon:DetermineNextWaypoint()
        addon:UpdateWaypointArrow()
    else
        addon:SaveProgress()
    end
    frame:Refresh()
end

function frame:UpdateRow(index, waypoint)
    if #frame.rows < index then
        local row = addon:CreateRow(frame.content, W, rowH)
        row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(index - 1) * rowH)
        row.rowIndex = index
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            local i = self.rowIndex
            if button == "RightButton" then rowRight(i) else rowLeft(i) end
        end)
        row.x = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.x:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.y = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.y:SetPoint("LEFT", row, "LEFT", 48, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row, "LEFT", 88, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        row.name:SetJustifyH("LEFT")
        frame.rows[index] = row
    end

    local row = frame.rows[index]
    -- A discovered row stays green even if it is the retained index for a
    -- fully completed segment.
    local active = index == addon.waypoint.index and not waypoint.discovered
    row.x:SetText(string.format("%.1f", tonumber(waypoint.data.x) or 0))
    row.y:SetText(string.format("%.1f", tonumber(waypoint.data.y) or 0))
    row.name:SetText(addon:LocalizedString(waypoint.data.name))

    local kind = waypoint.discovered and "done" or "text"
    if active then kind = "active" end
    addon:StyleFont(row.x, kind)
    addon:StyleFont(row.y, kind)
    addon:StyleFont(row.name, kind)
    if active then
        addon:ColorTexture(row.bg, addon.theme.rowActive)
    else
        addon:ColorTexture(row.bg, addon.theme.rowBg)
    end
    row:Show()
end

function frame:UpdateRoutesRow(index, node)
    local route = addon.data.routes and addon.data.routes[node.name]
    local childCount = node.children and #node.children or 0
    local isFolder = childCount > 0
    local wpCount = countWaypoints(route)
    -- Synthetic root CTA: start the whole mega-journey from the first leaf.
    local isJourneyStart = node._beginJourney == true

    if #frame.routes < index then
        local row = addon:CreateRow(frame.routescontent, W, routeRowH)
        row:SetPoint("TOPLEFT", frame.routescontent, "TOPLEFT", 0, -(index - 1) * routeRowH)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:EnableMouse(true)
        row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -6)
        row.title:SetPoint("RIGHT", row, "RIGHT", -52, -6)
        row.title:SetJustifyH("LEFT")
        row.meta = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.meta:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 6)
        row.meta:SetPoint("RIGHT", row, "RIGHT", -52, 6)
        row.meta:SetJustifyH("LEFT")
        row.action = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.action:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.action:SetWidth(44)
        row.action:SetJustifyH("RIGHT")
        frame.routes[index] = row
    end

    local row = frame.routes[index]
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local title
    if isJourneyStart then
        title = node.display or "Begin Journey"
    else
        title = (route and route.display) or node.display or node.name
    end
    row.title:SetText(addon:LocalizedString(title))
    addon:StyleFont(row.title, "accent")

    local function onActivate()
        if isJourneyStart or not isFolder then
            startRunFromNode(node._startNode or node)
        else
            openNode(node)
        end
    end
    row:SetScript("OnMouseUp", nil)
    row:SetScript("OnClick", onActivate)

    if isJourneyStart then
        row.meta:SetText(node._meta or "Start from the beginning")
        row.action:SetText("Begin")
    elseif isFolder then
        if childCount > 1 then
            row.meta:SetText("Choose path")
            row.action:SetText("›")
        else
            row.meta:SetText("Setup steps")
            row.action:SetText("Begin")
        end
    else
        row.meta:SetText(string.format("%d waypoints", wpCount))
        row.action:SetText("Start")
    end
    addon:StyleFont(row.meta, "dim")
    addon:StyleFont(row.action, "active")
    row:Show()
end
