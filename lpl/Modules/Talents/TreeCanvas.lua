local addonName, LPL = ...

LPL.TalentCanvas = {}

local BASE_COL_WIDTH = 38
local BASE_ROW_HEIGHT = 38
local BASE_NODE_SIZE = 30
local HERO_NODE_SCALE = 1.55
local HERO_EMBLEM_GAP = 8
local CANVAS_PADDING = 24

local VISUAL_ATLASES = {
    granted = "talents-reason-granted",
    choiceArrow = "talents-icon-choice",
    ringPurchased = "talents-node-green",
    ringLearnable = "talents-node-yellow",
}
local LEARNABLE_BORDER = { 0.55, 1, 0.15, 1 }

local function TrySetAtlas(texture, atlasName, useAtlasSize)
    if not texture or not atlasName or not texture.SetAtlas then
        return false
    end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlasName) then
        return false
    end
    return pcall(texture.SetAtlas, texture, atlasName, useAtlasSize == true)
end

local function ApplySplitChoiceIcons(button, nodeInfo, isAvailable, canInteract)
    local entries = nodeInfo.entryIDs or {}
    if #entries < 2 then
        return false
    end
    LPL.TalentTree:ApplyEntryIcon(button.icon, entries[1])
    LPL.TalentTree:ApplyEntryIcon(button.secondaryIcon, entries[2])
    local desat = not canInteract
    local alpha = isAvailable and 0.95 or 0.55
    button.icon:SetDesaturated(desat)
    button.icon:SetAlpha(alpha)
    button.secondaryIcon:SetDesaturated(desat)
    button.secondaryIcon:SetAlpha(alpha)
    button.secondaryIcon:Show()
    button.icon:ClearAllPoints()
    button.icon:SetPoint("TOPLEFT", 2, -2)
    button.icon:SetPoint("BOTTOMRIGHT", button, "CENTER", 0, 0)
    button.secondaryIcon:ClearAllPoints()
    button.secondaryIcon:SetPoint("TOPLEFT", button, "CENTER", 0, 0)
    button.secondaryIcon:SetPoint("BOTTOMRIGHT", -2, 2)
    if button.splitBg then
        button.splitBg:Show()
    end
    return true
end
local function ApplyNodeVisuals(button, state, nodeSize)
    local isSelected = state.activeRank > 0 or state.isGranted
    local isAvailable = state.meetsEdges and state.meetsGates
    local canInteract = not state.isGranted and (state.canPurchase or state.canRefund)
    local showSplit = state.hasMultipleIcons
        and state.isChoice
        and not state.isGranted
        and not state.selectedEntryID
        and #(button.nodeInfo.entryIDs or {}) >= 2
    if showSplit then
        ApplySplitChoiceIcons(button, button.nodeInfo, isAvailable, canInteract)
    else
        if button.secondaryIcon then
            button.secondaryIcon:Hide()
        end
        if button.splitBg then
            button.splitBg:Hide()
        end
        button.icon:ClearAllPoints()
        button.icon:SetPoint("TOPLEFT", 3, -3)
        button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
        button.icon:SetDesaturated(not isSelected and not canInteract)
        button.icon:SetAlpha(isSelected and 1 or (isAvailable and 0.9 or 0.55))
    end

    if state.isGranted then
        button.grantedOverlay:Show()
    else
        button.grantedOverlay:Hide()
    end

    if not isAvailable and not isSelected then
        button.disabledOverlay:Show()
    else
        button.disabledOverlay:Hide()
    end

    if state.isChoice and state.usesFlyout then
        button.choiceArrow:Show()
    else
        button.choiceArrow:Hide()
    end

    local br, bg, bb = LPL.Theme:GetColor("border")
    if state.isGranted then
        button:SetBackdropBorderColor(0.85, 0.72, 0.2, 1)
        button.bg:SetVertexColor(1, 1, 1)
        if button.purchasedRing then
            button.purchasedRing:Hide()
        end
        if button.learnableRing then
            button.learnableRing:Hide()
        end
    elseif isSelected then
        local ar, ag, ab = LPL.Theme:GetColor("accent")
        button:SetBackdropBorderColor(ar, ag, ab, 1)
        button.bg:SetVertexColor(1, 1, 1)
        if button.learnableRing then
            button.learnableRing:Hide()
        end
        if button.purchasedRing and TrySetAtlas(button.purchasedRing, VISUAL_ATLASES.ringPurchased, true) then
            button.purchasedRing:Show()
            button.purchasedRing:SetSize(nodeSize * 1.35, nodeSize * 1.35)
        elseif button.purchasedRing then
            button.purchasedRing:Hide()
        end
    elseif state.canPurchase then
        button:SetBackdropBorderColor(LEARNABLE_BORDER[1], LEARNABLE_BORDER[2], LEARNABLE_BORDER[3], LEARNABLE_BORDER[4])
        button.bg:SetVertexColor(1, 1, 1)
        if button.purchasedRing then
            button.purchasedRing:Hide()
        end
        if button.learnableRing then
            if TrySetAtlas(button.learnableRing, VISUAL_ATLASES.ringLearnable, true) then
                button.learnableRing:SetVertexColor(LEARNABLE_BORDER[1], LEARNABLE_BORDER[2], LEARNABLE_BORDER[3], 1)
                button.learnableRing:SetSize(nodeSize * 1.35, nodeSize * 1.35)
                button.learnableRing:Show()
            else
                button.learnableRing:Hide()
            end
        end
    elseif canInteract then
        button:SetBackdropBorderColor(br, bg, bb, 1)
        button.bg:SetVertexColor(0.95, 0.95, 0.95)
        if button.purchasedRing then
            button.purchasedRing:Hide()
        end
        if button.learnableRing then
            button.learnableRing:Hide()
        end
    else
        button:SetBackdropBorderColor(br, bg, bb, 0.5)
        button.bg:SetVertexColor(0.7, 0.7, 0.7)
        if button.purchasedRing then
            button.purchasedRing:Hide()
        end
        if button.learnableRing then
            button.learnableRing:Hide()
        end
    end
end

local function AcquireNodeButton(canvas, index, nodeSize)
    if not canvas.nodePool[index] then
        local button = CreateFrame("Button", nil, canvas.content)
        button:SetSize(nodeSize, nodeSize)

        local purchasedRing = button:CreateTexture(nil, "BACKGROUND", nil, 1)
        purchasedRing:SetPoint("CENTER")
        purchasedRing:Hide()
        button.purchasedRing = purchasedRing
        local learnableRing = button:CreateTexture(nil, "OVERLAY", nil, 0)
        learnableRing:SetPoint("CENTER")
        learnableRing:Hide()
        button.learnableRing = learnableRing
        local bg = button:CreateTexture(nil, "BACKGROUND", nil, 2)
        bg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        bg:SetAllPoints()
        button.bg = bg
        local splitBg = button:CreateTexture(nil, "BACKGROUND", nil, 1)
        splitBg:SetAllPoints()
        splitBg:SetColorTexture(0.04, 0.04, 0.04, 1)
        splitBg:Hide()
        button.splitBg = splitBg
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 3, -3)
        icon:SetPoint("BOTTOMRIGHT", -3, 3)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon = icon

        local secondaryIcon = button:CreateTexture(nil, "ARTWORK")
        secondaryIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        secondaryIcon:Hide()
        button.secondaryIcon = secondaryIcon

        local disabledOverlay = button:CreateTexture(nil, "OVERLAY", nil, 1)
        disabledOverlay:SetAllPoints()
        disabledOverlay:SetColorTexture(0, 0, 0, 0.45)
        disabledOverlay:Hide()
        button.disabledOverlay = disabledOverlay

        local grantedOverlay = button:CreateTexture(nil, "OVERLAY", nil, 2)
        grantedOverlay:SetPoint("BOTTOMRIGHT", 1, -1)
        if not TrySetAtlas(grantedOverlay, VISUAL_ATLASES.granted, true) then
            grantedOverlay:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
            grantedOverlay:SetSize(14, 14)
        end
        grantedOverlay:Hide()
        button.grantedOverlay = grantedOverlay

        local choiceArrow = button:CreateTexture(nil, "OVERLAY", nil, 3)
        choiceArrow:SetPoint("TOP", button, "BOTTOM", 0, 2)
        if not TrySetAtlas(choiceArrow, VISUAL_ATLASES.choiceArrow, true) then
            choiceArrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            choiceArrow:SetSize(12, 8)
        end
        choiceArrow:Hide()
        button.choiceArrow = choiceArrow

        local border = button:CreateTexture(nil, "OVERLAY", nil, 4)
        border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        border:SetBlendMode("ADD")
        border:SetPoint("TOPLEFT", -8, 8)
        border:SetPoint("BOTTOMRIGHT", 8, -8)
        border:Hide()
        button.border = border

        LPL.Theme:EnsureBackdrop(button)
        button:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        local br, bg, bb = LPL.Theme:GetColor("border")
        button:SetBackdropBorderColor(br, bg, bb, 0.9)
        button:SetBackdropColor(0, 0, 0, 0)

        local rankText = button:CreateFontString(nil, "OVERLAY", nil)
        rankText:SetFontObject(LPL.Theme.fonts.small)
        rankText:SetPoint("BOTTOMRIGHT", -1, 1)
        rankText:SetTextColor(1, 0.92, 0.4, 1)
        button.rankText = rankText

        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        canvas.nodePool[index] = button
    end

    local button = canvas.nodePool[index]
    button:SetSize(nodeSize, nodeSize)
    button:Show()
    return button
end

local function HideHeroEmblem(canvas)
    if canvas.heroEmblem then
        canvas.heroEmblem:Hide()
    end
end

local function PositionHeroEmblem(canvas, subTreeID, specID, layout, minCol, minRow, colWidth, rowHeight, nodeSize, padding, fitScale, emblemReserve)
    emblemReserve = emblemReserve or 0
    if not canvas.heroEmblem or not subTreeID then
        HideHeroEmblem(canvas)
        return
    end

    local heroMinCol, heroMaxCol, heroMinRow = math.huge, 0, math.huge
    for nodeID, data in pairs(layout) do
        local info = data.info
        if info.subTreeID == subTreeID and not info.isSubTreeSelection then
            heroMinCol = math.min(heroMinCol, data.col)
            heroMaxCol = math.max(heroMaxCol, data.col)
            heroMinRow = math.min(heroMinRow, data.row)
        end
    end

    if heroMinCol == math.huge then
        HideHeroEmblem(canvas)
        return
    end

    local heroSize = math.max(nodeSize * HERO_NODE_SCALE, 36)
    local emblem = canvas.heroEmblem
    emblem:SetSize(heroSize, heroSize)
    emblem.subTreeID = subTreeID
    emblem.specID = specID

    local centerCol = (heroMinCol + heroMaxCol) / 2
    local emblemX = padding + (centerCol - minCol) * colWidth - (heroSize - nodeSize) / 2
    local emblemY = emblemReserve + padding + (heroMinRow - minRow) * rowHeight - heroSize - (HERO_EMBLEM_GAP * fitScale)
    emblem:SetPoint("TOPLEFT", canvas.content, "TOPLEFT", emblemX, -emblemY)

    local lib = LibStub and LibStub:GetLibrary("LibTalentTree-1.0", true)
    local subTreeInfo = lib and lib:GetSubTreeInfo(subTreeID)
    if subTreeInfo and subTreeInfo.iconElementID then
        emblem.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        emblem.icon:SetAtlas(subTreeInfo.iconElementID)
    end
    emblem.icon:SetDesaturated(false)
    emblem.icon:SetAlpha(1)

    local ar, ag, ab = LPL.Theme:GetColor("accent")
    emblem:SetBackdropBorderColor(ar, ag, ab, 1)
    emblem.bg:SetVertexColor(1, 1, 1)
    emblem:Show()
end

local function HideExtraNodes(canvas, usedCount)
    for index = usedCount + 1, #canvas.nodePool do
        canvas.nodePool[index]:Hide()
    end
end

local function HideExtraLines(canvas, usedCount)
    for index = usedCount + 1, #canvas.linePool do
        canvas.linePool[index]:Hide()
    end
end

local function DrawEdge(canvas, lineIndex, x1, y1, x2, y2, accent)
    local line = canvas.linePool[lineIndex]
    if not line then
        if canvas.content.CreateLine then
            line = canvas.content:CreateLine(nil, "BACKGROUND")
            line:SetThickness(1.5)
        end
        canvas.linePool[lineIndex] = line
    end

    if not line or not line.SetStartPoint then
        return lineIndex
    end

    if accent then
        line:SetColorTexture(LPL.Theme:GetColor("accent"))
    else
        line:SetColorTexture(LPL.Theme:GetColor("border"))
    end
    line:SetStartPoint("TOPLEFT", canvas.content, "TOPLEFT", x1, -y1)
    line:SetEndPoint("TOPLEFT", canvas.content, "TOPLEFT", x2, -y2)
    line:Show()
    return lineIndex + 1
end

function LPL.TalentCanvas:Create(parent, options)
    options = options or {}
    local bottomInset = options.bottomInset or 12

    local frame = LPL:CreatePanel(nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -96)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, bottomInset)

    local viewport = CreateFrame("Frame", nil, frame)
    viewport:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    viewport:SetClipsChildren(true)

    local content = CreateFrame("Frame", nil, viewport)
    content:SetPoint("CENTER")
    content:SetSize(400, 300)

    frame.viewport = viewport
    frame.content = content
    frame.nodePool = {}
    frame.linePool = {}
    frame.nodePositions = {}
    frame.getSandbox = options.getSandbox
    frame.onNodeChanged = options.onNodeChanged
    frame.choiceFlyout = LPL.TalentChoiceFlyout:Create(content)

    local heroEmblem = CreateFrame("Button", nil, content)
    heroEmblem:SetFrameLevel(content:GetFrameLevel() + 2)
    local heroBg = heroEmblem:CreateTexture(nil, "BACKGROUND")
    heroBg:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    heroBg:SetAllPoints()
    heroEmblem.bg = heroBg

    local heroIcon = heroEmblem:CreateTexture(nil, "ARTWORK")
    heroIcon:SetPoint("TOPLEFT", 4, -4)
    heroIcon:SetPoint("BOTTOMRIGHT", -4, 4)
    heroIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    heroEmblem.icon = heroIcon

    local heroBorder = heroEmblem:CreateTexture(nil, "OVERLAY")
    heroBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    heroBorder:SetBlendMode("ADD")
    heroBorder:SetPoint("TOPLEFT", -10, 10)
    heroBorder:SetPoint("BOTTOMRIGHT", 10, -10)
    heroBorder:Hide()
    heroEmblem.border = heroBorder

    LPL.Theme:EnsureBackdrop(heroEmblem)
    heroEmblem:SetBackdrop({
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 2,
    })
    local br, bg, bb = LPL.Theme:GetColor("border")
    heroEmblem:SetBackdropBorderColor(br, bg, bb, 0.9)
    heroEmblem:SetBackdropColor(0, 0, 0, 0)
    heroEmblem.isHeroEmblem = true
    heroEmblem:SetScript("OnEnter", function(self)
        self.border:Show()
        LPL.TalentTree:ShowHeroEmblemTooltip(self, self.subTreeID)
    end)
    heroEmblem:SetScript("OnLeave", function(self)
        self.border:Hide()
        LPL:ClearGameTooltipData(GameTooltip)
    end)
    heroEmblem:Hide()
    frame.heroEmblem = heroEmblem

    local loading = LPL:CreateLabel(frame, "body")
    loading:SetPoint("CENTER")
    loading:SetTextColor(LPL.Theme:GetColor("textLabel"))
    loading:SetText("Loading talent data...")
    frame.loadingLabel = loading

    local function GetInteractionContext(view)
        return {
            sandbox = frame.getSandbox and frame.getSandbox(),
            specID = view.specID,
            classID = view.classID,
            subTreeID = view.subTreeID,
            level = view.level,
            onChanged = function()
                if frame.onNodeChanged then
                    frame.onNodeChanged()
                end
            end,
        }
    end

    local function WireNodeButton(button, nodeInfo, view, nodeSize)
        local sandbox = frame.getSandbox and frame.getSandbox()
        if not sandbox then
            return
        end

        button.nodeInfo = nodeInfo
        button.specID = view.specID
        button.isHeroEmblem = nil
        button.canvas = frame

        local state = LPL.TalentInteractions:GetNodeState(
            sandbox, nodeInfo, view.specID, view.classID, view.subTreeID, view.level
        )
        state.usesFlyout = LPL.TalentInteractions:UsesChoiceFlyout(nodeInfo)
        state.hasMultipleIcons = LPL.TalentInteractions:HasSplitChoiceDisplay(nodeInfo)
        local showSplit = state.hasMultipleIcons
            and not state.selectedEntryID
            and not state.isGranted
            and #(nodeInfo.entryIDs or {}) >= 2
        if not showSplit then
            LPL.TalentTree:ApplyNodeIcon(button.icon, nodeInfo, sandbox, view.specID)
        end
        local maxRank = nodeInfo.maxRanks or 1
        if maxRank > 1 and not state.isChoice then
            button.rankText:SetText(state.activeRank .. "/" .. maxRank)
            button.rankText:Show()
        else
            button.rankText:Hide()
        end

        ApplyNodeVisuals(button, state, nodeSize)

        button:SetScript("OnEnter", function(self)
            self.border:Show()
            LPL.TalentTree:ShowNodeTooltip(self, self.nodeInfo, self.specID, sandbox)
        end)
        button:SetScript("OnLeave", function(self)
            self.border:Hide()
            LPL:ClearGameTooltipData(GameTooltip)
        end)

        button:SetScript("OnClick", function(self, mouseButton)
            local ctx = GetInteractionContext(view)
            if not ctx.sandbox then
                return
            end

            local currentState = LPL.TalentInteractions:GetNodeState(
                ctx.sandbox, nodeInfo, ctx.specID, ctx.classID, ctx.subTreeID, ctx.level
            )
            currentState.usesFlyout = LPL.TalentInteractions:UsesChoiceFlyout(nodeInfo)

            local changed = LPL.TalentInteractions:HandleNodeClick(
                ctx.sandbox,
                nodeInfo,
                mouseButton,
                ctx.specID,
                ctx.classID,
                ctx.subTreeID,
                ctx.level,
                function(flyoutNodeInfo, flyoutState)
                    frame.choiceFlyout:Toggle(self, flyoutNodeInfo, flyoutState, ctx)
                end
            )

            if changed then
                ctx.onChanged()
            end
        end)
    end

    function frame:Render()
        if not LPL.TalentTree.ready then
            self.loadingLabel:Show()
            return
        end
        self.loadingLabel:Hide()

        if self.choiceFlyout then
            self.choiceFlyout:Hide()
        end

        local view = LPL.TalentTree:ResolveViewState()
        local sandbox = self.getSandbox and self.getSandbox()
        local nodes = LPL.TalentTree:GetVisibleNodes(view.classID, view.specID, view.subTreeID, view.level)
        wipe(self.nodePositions)
        LPL.TalentInteractions:ClearCaches()

        local minCol, maxCol, minRow, maxRow = math.huge, 0, math.huge, 0
        local layout = {}

        for _, nodeInfo in ipairs(nodes) do
            if not nodeInfo.isSubTreeSelection then
                local col, row = LPL.TalentTree:GetNodeGridPosition(nodeInfo.ID)
                if col and row then
                    minCol = math.min(minCol, col)
                    maxCol = math.max(maxCol, col)
                    minRow = math.min(minRow, row)
                    maxRow = math.max(maxRow, row)
                    layout[nodeInfo.ID] = { col = col, row = row, info = nodeInfo }
                end
            end
        end

        if minCol == math.huge then
            self.loadingLabel:SetText("No talent nodes to display.")
            self.loadingLabel:Show()
            HideExtraNodes(self, 0)
            HideExtraLines(self, 0)
            HideHeroEmblem(self)
            return
        end

        local gridCols = maxCol - minCol + 1
        local gridRows = maxRow - minRow + 1
        local heroEmblemReserve = 0
        if view.subTreeID then
            heroEmblemReserve = BASE_NODE_SIZE * HERO_NODE_SCALE + HERO_EMBLEM_GAP
        end
        local rawWidth = gridCols * BASE_COL_WIDTH + CANVAS_PADDING * 2
        local rawHeight = gridRows * BASE_ROW_HEIGHT + CANVAS_PADDING * 2 + heroEmblemReserve

        local viewWidth = self.viewport:GetWidth()
        local viewHeight = self.viewport:GetHeight()
        if viewWidth <= 1 or viewHeight <= 1 then
            viewWidth = 700
            viewHeight = 420
        end

        local fitScale = math.min(viewWidth / rawWidth, viewHeight / rawHeight, 1)
        local colWidth = BASE_COL_WIDTH * fitScale
        local rowHeight = BASE_ROW_HEIGHT * fitScale
        local nodeSize = BASE_NODE_SIZE * fitScale
        local padding = CANVAS_PADDING * fitScale

        local contentWidth = gridCols * colWidth + padding * 2
        local emblemReserve = heroEmblemReserve * fitScale
        local contentHeight = gridRows * rowHeight + padding * 2 + emblemReserve
        self.content:SetSize(contentWidth, contentHeight)
        self.content:SetScale(1)
        self.content:ClearAllPoints()
        self.content:SetPoint("CENTER", self.viewport, "CENTER")

        local nodeIndex = 0

        for nodeID, data in pairs(layout) do
            nodeIndex = nodeIndex + 1
            local button = AcquireNodeButton(self, nodeIndex, math.max(nodeSize, 18))
            local x = padding + (data.col - minCol) * colWidth
            local y = emblemReserve + padding + (data.row - minRow) * rowHeight
            button:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
            self.nodePositions[nodeID] = { x = x + nodeSize / 2, y = y + nodeSize / 2 }

            WireNodeButton(button, data.info, view, math.max(nodeSize, 18))
        end
        HideExtraNodes(self, nodeIndex)

        PositionHeroEmblem(
            self, view.subTreeID, view.specID,
            layout, minCol, minRow, colWidth, rowHeight, nodeSize, padding, fitScale, emblemReserve
        )

        local lineIndex = 1
        for nodeID, data in pairs(layout) do
            local edges = LPL.TalentTree:GetNodeEdges(nodeID)
            local startPos = self.nodePositions[nodeID]
            if startPos and edges and sandbox then
                local state = LPL.TalentInteractions:GetNodeState(
                    sandbox, data.info, view.specID, view.classID, view.subTreeID, view.level
                )
                local edgeActive = state.activeRank >= (data.info.maxRanks or 1)
                for _, edge in ipairs(edges) do
                    local targetPos = self.nodePositions[edge.targetNode]
                    if targetPos and layout[edge.targetNode] then
                        lineIndex = DrawEdge(
                            self, lineIndex,
                            startPos.x, startPos.y,
                            targetPos.x, targetPos.y,
                            edgeActive
                        )
                    end
                end
            end
        end
        HideExtraLines(self, lineIndex - 1)
    end

    frame:SetScript("OnHide", function()
        if frame.choiceFlyout then
            frame.choiceFlyout:Hide()
        end
    end)

    frame:SetScript("OnSizeChanged", function()
        if frame:IsShown() then
            frame:Render()
        end
    end)

    return frame
end
