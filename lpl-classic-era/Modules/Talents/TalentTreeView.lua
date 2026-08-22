local addonName, LPL = ...

LPL.TalentTreeView = {}

local NODE = 40
local GAP_X = 18
local GAP_Y = 22
local PAD = 14
local HEADER_H = 28
local TREE_GAP = 18
local COLS = 4
local LINE_THICKNESS = 4
local LINE_GOLD = { 1, 0.82, 0.2, 1 }
local LINE_BLUE = { 0.35, 0.75, 1, 1 }
local LINE_GREY = { 0.55, 0.55, 0.58, 1 }

local function TreeWidth()
    return PAD * 2 + COLS * (NODE + GAP_X) - GAP_X
end

local function NodeCenter(tier, column)
    local x = PAD + (column or 0) * (NODE + GAP_X) + NODE / 2
    local y = HEADER_H + PAD + (tier or 0) * (NODE + GAP_Y) + NODE / 2
    return x, y
end

function LPL.TalentTreeView:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)

    local toolbar = CreateFrame("Frame", nil, frame)
    toolbar:SetPoint("TOPLEFT", 12, -8)
    toolbar:SetPoint("TOPRIGHT", -12, -8)
    toolbar:SetHeight(88)

    local classDrop = LPL:CreateDropdown("LPLClassicEraClassDrop", toolbar, 180)
    classDrop:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 0, 0)
    classDrop:SetLabel("Class")

    local pointsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pointsLabel:SetPoint("TOPRIGHT", toolbar, "TOPRIGHT", 0, -18)
    pointsLabel:SetJustifyH("RIGHT")

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", classDrop, "TOPRIGHT", 16, -22)
    hint:SetPoint("RIGHT", pointsLabel, "LEFT", -12, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Plan any class at max level  ·  Left-click: add  ·  Right-click: remove")

    local levelRow = CreateFrame("Frame", nil, toolbar)
    levelRow:SetPoint("TOPLEFT", classDrop, "BOTTOMLEFT", 0, -6)
    levelRow:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    levelRow:SetHeight(28)

    local levelLabel = levelRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    levelLabel:SetPoint("LEFT", levelRow, "LEFT", 0, 0)
    levelLabel:SetText("Level")

    local levelValue = levelRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelValue:SetPoint("LEFT", levelLabel, "RIGHT", 8, 0)

    local levelSlider = CreateFrame("Slider", "LPLClassicEraLevelSlider", levelRow, "OptionsSliderTemplate")
    levelSlider:SetPoint("LEFT", levelValue, "RIGHT", 16, 0)
    levelSlider:SetWidth(200)
    levelSlider:SetMinMaxValues(LPL.TalentAPI:GetMinPlanLevel(), LPL.TalentAPI:GetMaxLevel())
    levelSlider:SetValueStep(1)
    levelSlider:SetObeyStepOnDrag(true)
    if levelSlider.Low then
        levelSlider.Low:SetText(tostring(LPL.TalentAPI:GetMinPlanLevel()))
        levelSlider.High:SetText(tostring(LPL.TalentAPI:GetMaxLevel()))
        levelSlider.Text:SetText("")
    end

    local canvas = CreateFrame("Frame", nil, frame)
    canvas:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -6)
    canvas:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    local canvasBg = canvas:CreateTexture(nil, "BACKGROUND")
    canvasBg:SetAllPoints()
    canvasBg:SetColorTexture(0, 0, 0, 1)

    local scroll = CreateFrame("ScrollFrame", nil, canvas, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(900, 500)
    scroll:SetScrollChild(content)

    -- Lines parented to content (not a zero-size overlay) so Classic scroll clipping cannot cull them.
    local lineLayer = CreateFrame("Frame", nil, content)
    lineLayer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    lineLayer:SetSize(900, 500)
    lineLayer:SetFrameLevel((content:GetFrameLevel() or 1) + 1)

    local nodeLayer = CreateFrame("Frame", nil, content)
    nodeLayer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    nodeLayer:SetSize(900, 500)
    nodeLayer:SetFrameLevel((content:GetFrameLevel() or 1) + 2)

    frame.classDrop = classDrop
    frame.pointsLabel = pointsLabel
    frame.levelSlider = levelSlider
    frame.levelValue = levelValue
    frame.content = content
    frame.nodeLayer = nodeLayer
    frame.lineLayer = lineLayer
    frame.linePool = {}
    frame.treeColumns = {}
    frame.nodes = {}
    frame.nodeByTalentID = {}
    frame.draft = nil
    frame.readOnly = false
    frame.suppressLevelSync = false

    levelSlider:SetScript("OnValueChanged", function(_, value)
        if frame.suppressLevelSync or not frame.draft or frame.readOnly then
            return
        end
        local level = math.floor(value + 0.5)
        LPL.TalentAPI:SetDraftLevel(frame.draft, level)
        frame.levelValue:SetText(tostring(LPL.TalentAPI:GetDraftLevel(frame.draft)))
        if frame.onDraftChanged then
            frame.onDraftChanged(frame.draft)
        end
        frame:RefreshPoints()
        frame:RefreshTrees()
    end)

    local function ColorLine(line, style)
        local color = LINE_GREY
        if style == "gold" then
            color = LINE_GOLD
        elseif style == "blue" then
            color = LINE_BLUE
        end
        if line.SetColorTexture then
            line:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        elseif line.SetVertexColor then
            line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        end
    end

    local function AcquireLine(index)
        local line = frame.linePool[index]
        if line then
            return line
        end

        -- Solid color only — Classic Era often lacks WHITE8x8.
        line = frame.lineLayer:CreateTexture(nil, "ARTWORK", nil, 0)
        if line.SetColorTexture then
            line:SetColorTexture(1, 1, 1, 1)
        else
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetVertexColor(1, 1, 1, 1)
        end
        line:Hide()
        frame.linePool[index] = line
        return line
    end

    -- Axis-aligned segment (no SetRotation — reliable on Classic Era).
    local function DrawSegment(lineIndex, x1, y1, x2, y2, style)
        local dx = x2 - x1
        local dy = y2 - y1
        if math.abs(dx) < 1 and math.abs(dy) < 1 then
            return lineIndex
        end

        local line = AcquireLine(lineIndex)
        ColorLine(line, style)
        line:ClearAllPoints()

        if math.abs(dy) >= math.abs(dx) then
            local height = math.max(math.abs(dy), 1)
            line:SetSize(LINE_THICKNESS, height)
            line:SetPoint("CENTER", frame.content, "TOPLEFT", (x1 + x2) / 2, -((y1 + y2) / 2))
        else
            local width = math.max(math.abs(dx), 1)
            line:SetSize(width, LINE_THICKNESS)
            line:SetPoint("CENTER", frame.content, "TOPLEFT", (x1 + x2) / 2, -((y1 + y2) / 2))
        end
        line:Show()
        return lineIndex + 1
    end

    -- Classic talent UI: straight when aligned, elbow when offset.
    local function DrawEdge(lineIndex, x1, y1, x2, y2, style)
        local inset = NODE / 2 - 2
        if math.abs(x1 - x2) < 2 then
            local top = math.min(y1, y2) + inset
            local bottom = math.max(y1, y2) - inset
            if bottom > top then
                return DrawSegment(lineIndex, x1, top, x2, bottom, style)
            end
            return lineIndex
        end
        if math.abs(y1 - y2) < 2 then
            local left = math.min(x1, x2) + inset
            local right = math.max(x1, x2) - inset
            if right > left then
                return DrawSegment(lineIndex, left, y1, right, y2, style)
            end
            return lineIndex
        end

        local midY = (y1 + y2) / 2
        local fromY = y1 < y2 and (y1 + inset) or (y1 - inset)
        local toY = y2 < y1 and (y2 + inset) or (y2 - inset)
        lineIndex = DrawSegment(lineIndex, x1, fromY, x1, midY, style)
        lineIndex = DrawSegment(lineIndex, x1, midY, x2, midY, style)
        lineIndex = DrawSegment(lineIndex, x2, midY, x2, toY, style)
        return lineIndex
    end

    local function EnsureTreeColumn(tabIndex)
        local col = frame.treeColumns[tabIndex]
        if col then
            return col
        end

        col = CreateFrame("Frame", nil, frame.content)
        col:SetSize(TreeWidth(), 400)

        local headerIcon = col:CreateTexture(nil, "ARTWORK")
        headerIcon:SetSize(22, 22)
        headerIcon:SetPoint("TOPLEFT", 4, -2)
        headerIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        col.headerIcon = headerIcon

        local headerName = col:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        headerName:SetPoint("LEFT", headerIcon, "RIGHT", 6, 0)
        headerName:SetJustifyH("LEFT")
        col.headerName = headerName

        local points = col:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        points:SetPoint("TOPRIGHT", -4, -6)
        points:SetJustifyH("RIGHT")
        col.points = points

        frame.treeColumns[tabIndex] = col
        return col
    end

    local function Tooltip(node)
        local talent = node.talentInfo
        if not talent then
            return
        end

        local requirement
        if frame.draft and not frame.readOnly then
            local rank = node.currentRank or 0
            local maxRank = talent.maxRank or 0
            if rank < maxRank then
                local ok, err = LPL.TalentAPI:CanIncreaseDraftRank(frame.draft, node.tabIndex, node.talentIndex)
                if not ok and err and err ~= "Already at max rank." then
                    requirement = err
                end
            end
        end

        LPL.TalentAPI:ShowTalentTooltip(node, talent, node.currentRank or 0, {
            readOnly = frame.readOnly,
            requirementText = requirement,
        })
    end

    function frame:EnsureNode(key)
        local node = self.nodes[key]
        if node then
            return node
        end

        node = CreateFrame("Button", nil, self.nodeLayer)
        node:SetSize(NODE, NODE)

        local border = node:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0.2, 0.2, 0.22, 1)
        node.border = border

        local icon = node:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        node.icon = icon

        local rankText = node:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rankText:SetPoint("BOTTOMRIGHT", -1, 1)
        node.rankText = rankText

        node:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        node:SetScript("OnEnter", function(selfBtn)
            Tooltip(selfBtn)
        end)
        node:SetScript("OnLeave", function()
            if LPL.ClearGameTooltipData then
                LPL:ClearGameTooltipData(GameTooltip)
            elseif GameTooltip_Hide then
                GameTooltip_Hide()
            else
                GameTooltip:Hide()
            end
        end)
        node:SetScript("OnClick", function(selfBtn, mouseButton)
            if frame.readOnly or not frame.draft then
                return
            end
            if mouseButton == "LeftButton" then
                local ok, err = LPL.TalentAPI:IncreaseDraftRank(frame.draft, selfBtn.tabIndex, selfBtn.talentIndex)
                if not ok and err then
                    print("|cffffcc00LPL:|r " .. err)
                end
            else
                LPL.TalentAPI:DecreaseDraftRank(frame.draft, selfBtn.tabIndex, selfBtn.talentIndex)
            end
            frame:Refresh()
            if frame.onDraftChanged then
                frame.onDraftChanged(frame.draft)
            end
            if GameTooltip:IsOwned(selfBtn) then
                Tooltip(selfBtn)
            end
        end)

        self.nodes[key] = node
        return node
    end

    function frame:RefreshPoints()
        if not self.draft then
            self.pointsLabel:SetText("")
            return
        end
        LPL.TalentAPI:RecalcDraftPoints(self.draft)
        local spent = tonumber(self.draft.totalPoints) or 0
        local budget = LPL.TalentAPI:GetDraftPointBudget(self.draft)
        local spentText = spent > budget
            and string.format("|cffff6060%d|r/%d", spent, budget)
            or string.format("%d/%d", spent, budget)
        self.pointsLabel:SetText(string.format(
            "%s   %s",
            LPL.TalentAPI:SummarizeBuild(self.draft),
            spentText
        ))
    end

    function frame:RefreshLevel()
        if not self.draft then
            return
        end
        LPL.TalentAPI:SetDraftLevel(self.draft, self.draft.level or LPL.TalentAPI:GetMaxLevel())
        local level = LPL.TalentAPI:GetDraftLevel(self.draft)
        self.suppressLevelSync = true
        self.levelSlider:SetValue(level)
        self.suppressLevelSync = false
        self.levelValue:SetText(tostring(level))
        if self.readOnly then
            self.levelSlider:Disable()
            self.levelSlider:SetAlpha(0.5)
        else
            self.levelSlider:Enable()
            self.levelSlider:SetAlpha(1)
        end
    end

    function frame:RefreshClassDrop()
        local classes = LPL.TalentAPI:GetClassList()
        local selected = self.draft and tonumber(self.draft.classID) or LPL.TalentAPI:GetPlayerClassID()
        self.classDrop:SetItems(classes, selected, function(classID)
            if not self.draft then
                return
            end
            if tonumber(self.draft.classID) == tonumber(classID) then
                return
            end
            LPL.TalentAPI:EnsureDraftClass(self.draft, classID)
            if self.onDraftChanged then
                self.onDraftChanged(self.draft)
            end
            self:Refresh()
        end)
    end

    function frame:RefreshTrees()
        for _, node in pairs(self.nodes) do
            node:Hide()
        end
        for _, line in ipairs(self.linePool) do
            line:Hide()
        end
        wipe(self.nodeByTalentID)

        local classID = self.draft and tonumber(self.draft.classID) or LPL.TalentAPI:GetPlayerClassID()
        local tabs = LPL.TalentAPI:GetCatalogTabs(classID)
        local treeW = TreeWidth()
        local maxH = 0
        local lineIndex = 1
        local positions = {}

        -- Pass 1: place nodes and measure bounds.
        for tabIndex, tab in ipairs(tabs) do
            local col = EnsureTreeColumn(tabIndex)
            local xOff = (tabIndex - 1) * (treeW + TREE_GAP)
            col:ClearAllPoints()
            col:SetPoint("TOPLEFT", self.content, "TOPLEFT", xOff, 0)
            col.headerIcon:SetTexture(tab.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            col.headerName:SetText(tab.name or ("Tree " .. tabIndex))

            local points = 0
            if self.draft and self.draft.tabs then
                local draftTab = self.draft.tabs[tostring(tabIndex)] or self.draft.tabs[tabIndex]
                points = draftTab and tonumber(draftTab.points) or 0
            end
            col.points:SetText(tostring(points))
            col:Show()

            local talents = LPL.TalentAPI:IteratePlannerTalents(classID, tabIndex)
            local maxTier = 0

            for _, talent in ipairs(talents) do
                local key = tabIndex .. ":" .. talent.talentID
                local node = self:EnsureNode(key)
                local rank = self.draft and LPL.TalentAPI:GetDraftRank(self.draft, tabIndex, talent.talentIndex) or 0
                local lx, ly = NodeCenter(talent.tier, talent.column)

                node.tabIndex = tabIndex
                node.talentIndex = talent.talentIndex
                node.liveTalentIndex = talent.talentIndex
                node.talentID = talent.talentID
                node.talentInfo = talent
                node.currentRank = rank
                node:ClearAllPoints()
                node:SetPoint("TOPLEFT", col, "TOPLEFT", lx - NODE / 2, -(ly - NODE / 2))
                node.icon:SetTexture(talent.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                node.rankText:SetText(string.format("%d/%d", rank, talent.maxRank or 0))

                local can = false
                if self.draft and not self.readOnly then
                    can = LPL.TalentAPI:CanIncreaseDraftRank(self.draft, tabIndex, talent.talentIndex)
                end

                if rank >= (talent.maxRank or 0) and (talent.maxRank or 0) > 0 then
                    node.icon:SetDesaturated(false)
                    node.border:SetColorTexture(1, 0.82, 0, 1)
                elseif rank > 0 then
                    node.icon:SetDesaturated(false)
                    node.border:SetColorTexture(0.2, 0.8, 0.2, 1)
                else
                    node.icon:SetDesaturated(not can)
                    node.border:SetColorTexture(can and 0.15 or 0.25, can and 0.55 or 0.25, can and 0.2 or 0.28, 1)
                end

                node:Show()
                self.nodeByTalentID[talent.talentID] = node
                positions[talent.talentID] = {
                    x = xOff + lx,
                    y = ly,
                    rank = rank,
                    maxRank = talent.maxRank or 0,
                    tabIndex = tabIndex,
                }

                if (talent.tier or 0) > maxTier then
                    maxTier = talent.tier
                end
            end

            local h = HEADER_H + PAD * 2 + (maxTier + 1) * (NODE + GAP_Y)
            col:SetHeight(h)
            if h > maxH then
                maxH = h
            end
        end

        for tabIndex = #tabs + 1, #self.treeColumns do
            if self.treeColumns[tabIndex] then
                self.treeColumns[tabIndex]:Hide()
            end
        end

        -- Size content/layers BEFORE drawing lines so Classic does not cull zero-size parents.
        local totalW = math.max(1, #tabs) * treeW + math.max(0, #tabs - 1) * TREE_GAP + 20
        local totalH = math.max(maxH, 360)
        self.content:SetSize(totalW, totalH)
        self.lineLayer:SetSize(totalW, totalH)
        self.nodeLayer:SetSize(totalW, totalH)

        -- Pass 2: prerequisite connectors.
        for tabIndex = 1, #tabs do
            local talents = LPL.TalentAPI:IteratePlannerTalents(classID, tabIndex)
            for _, talent in ipairs(talents) do
                local dest = positions[talent.talentID]
                if dest and type(talent.prereqs) == "table" then
                    for _, req in ipairs(talent.prereqs) do
                        local src = positions[req.talentID]
                        if src then
                            local need = (tonumber(req.rank) or 0) + 1
                            local style = "grey"
                            if src.rank >= need and dest.rank > 0 then
                                style = "gold"
                            elseif src.rank >= need then
                                style = "blue"
                            end
                            lineIndex = DrawEdge(lineIndex, src.x, src.y, dest.x, dest.y, style)
                        end
                    end
                end
            end
        end
    end

    function frame:Refresh()
        if self.draft then
            LPL.TalentAPI:EnsureDraftClass(self.draft, self.draft.classID or LPL.TalentAPI:GetPlayerClassID())
            if not self.draft.level then
                LPL.TalentAPI:SetDraftLevel(self.draft, LPL.TalentAPI:GetMaxLevel())
            end
        end
        self:RefreshClassDrop()
        self:RefreshLevel()
        self:RefreshTrees()
        self:RefreshPoints()
    end

    function frame:SetDraft(draft, readOnly)
        self.draft = draft
        self.readOnly = readOnly and true or false
        if self.draft then
            LPL.TalentAPI:EnsureDraftClass(self.draft, self.draft.classID or LPL.TalentAPI:GetPlayerClassID())
            LPL.TalentAPI:SetDraftLevel(self.draft, self.draft.level or LPL.TalentAPI:GetMaxLevel())
        end
        self:Refresh()
    end

    return frame
end
