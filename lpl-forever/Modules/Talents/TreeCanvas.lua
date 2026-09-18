local addonName, LPL = ...

LPL.TalentCanvas = {}

local BASE_COL_WIDTH = 66
local BASE_ROW_HEIGHT = 66
local BASE_NODE_SIZE = 48
local HERO_NODE_SCALE = 1.45
local APEX_NODE_SCALE = 1.0
local CHOICE_NODE_SCALE = 1.2
local HERO_EMBLEM_GAP = 8
local CANVAS_PADDING = 20
local POS_STEP = 600
local COLUMN_GAP = 0.85
local BORDER_SCALE = 1.18
local SHADOW_SCALE = 1.12
local GLOW_SCALE = 1.28

-- Blizzard TalentButtonArtMixin.ArtSet (class/spec/hero nodes). No tree backgrounds.
local ART_SETS = {
    square = {
        iconMask = nil,
        shadow = "talents-node-square-shadow",
        normal = "talents-node-square-yellow",
        disabled = "talents-node-square-gray",
        selectable = "talents-node-square-green",
        maxed = "talents-node-square-yellow",
        locked = "talents-node-square-locked",
        glow = "talents-node-square-greenglow",
        iconInset = 0.12,
    },
    circle = {
        iconMask = "talents-node-circle-mask",
        shadow = "talents-node-circle-shadow",
        normal = "talents-node-circle-yellow",
        disabled = "talents-node-circle-gray",
        selectable = "talents-node-circle-green",
        maxed = "talents-node-circle-yellow",
        locked = "talents-node-circle-locked",
        glow = "talents-node-circle-greenglow",
        iconInset = 0.16,
    },
    choice = {
        iconMask = "talents-node-choice-mask",
        shadow = "talents-node-choice-shadow",
        normal = "talents-node-choice-yellow",
        disabled = "talents-node-choice-gray",
        selectable = "talents-node-choice-green",
        maxed = "talents-node-choice-yellow",
        locked = "talents-node-choice-locked",
        glow = "talents-node-choice-greenglow",
        iconInset = 0.14,
        borderScale = 1.22,
        shadowScale = 1.16,
        glowScale = 1.32,
    },
    apexCircle = {
        iconMask = "talents-node-circle-mask",
        shadow = nil,
        normal = "talents-node-apex-large-yellow",
        disabled = "talents-node-apex-large-gray",
        selectable = "talents-node-apex-large-green",
        maxed = "talents-node-apex-large-yellow",
        locked = "talents-node-apex-large-locked",
        glow = "talents-node-apex-large-glow",
        iconInset = 0.26,
        borderScale = 1.02,
        glowScale = 1.1,
    },
    apexSquare = {
        iconMask = nil,
        shadow = nil,
        normal = "talents-node-apex-active-large-yellow",
        disabled = "talents-node-apex-active-large-gray",
        selectable = "talents-node-apex-active-large-green",
        maxed = "talents-node-apex-active-large-yellow",
        locked = "talents-node-apex-active-large-locked",
        glow = "talents-node-apex-active-large-glow",
        iconInset = 0.22,
        borderScale = 1.02,
        glowScale = 1.1,
    },
}

local LINE_GOLD = { 1, 0.82, 0.12, 1 }
local LINE_BLUE = { 0.38, 0.78, 1.0, 1 }
local LINE_THICKNESS = 3
local RANK_GOLD = { 1, 0.82, 0 }
local RANK_GREEN = { 0.1, 1, 0.1 }
local RANK_GRAY = { 0.6, 0.6, 0.6 }

local function TrySetAtlas(texture, atlasName, useAtlasSize)
    if not texture or not atlasName or not texture.SetAtlas then
        return false
    end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlasName) then
        return false
    end
    return pcall(texture.SetAtlas, texture, atlasName, useAtlasSize == true)
end

local function ApplyIconMask(texture, mask, atlasName)
    if not texture or not texture.AddMaskTexture or not mask then
        return
    end
    if atlasName and TrySetAtlas(mask, atlasName, false) then
        mask:SetAllPoints(texture)
        mask:Show()
        texture:AddMaskTexture(mask)
    else
        mask:Hide()
        if texture.RemoveMaskTexture then
            pcall(texture.RemoveMaskTexture, texture, mask)
        end
    end
end

local function SetIconInset(texture, button, inset)
    local pad = math.max(2, math.floor((button:GetWidth() or 30) * (inset or 0.14)))
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", pad, -pad)
    texture:SetPoint("BOTTOMRIGHT", -pad, pad)
end

local function ApplySplitChoiceIcons(button, nodeInfo, isAvailable, canInteract, art)
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
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", button, "CENTER", 0, 0)
    button.secondaryIcon:ClearAllPoints()
    button.secondaryIcon:SetPoint("TOPLEFT", button, "CENTER", 0, 0)
    button.secondaryIcon:SetPoint("BOTTOMRIGHT", -3, 3)
    ApplyIconMask(button.icon, button.iconMask, art.iconMask)
    ApplyIconMask(button.secondaryIcon, button.secondaryMask, art.iconMask)
    return true
end

local function GetVisualBorderAtlas(art, state)
    local isSelected = state.activeRank > 0 or state.isGranted
    local maxed = isSelected and state.activeRank >= (state.maxRank or 1)
    if not state.meetsGates and not isSelected then
        return art.locked, "locked"
    end
    if not state.meetsEdges and not isSelected then
        return art.disabled, "disabled"
    end
    if state.canPurchase then
        return art.selectable, "selectable"
    end
    if maxed or state.isGranted then
        return art.maxed, "maxed"
    end
    if isSelected then
        return art.normal, "normal"
    end
    return art.disabled, "disabled"
end

local function ApplyNodeVisuals(button, state, nodeSize)
    local nodeInfo = button.nodeInfo
    local artKind = LPL.TalentTree:GetNodeArtKind(nodeInfo)
    local art = ART_SETS[artKind] or ART_SETS.circle
    button.artKind = artKind

    local isSelected = state.activeRank > 0 or state.isGranted
    local isAvailable = state.meetsEdges and state.meetsGates
    local canInteract = not state.isGranted and (state.canPurchase or state.canRefund)
    local showSplit = state.hasMultipleIcons
        and state.isChoice
        and not state.isGranted
        and not state.selectedEntryID
        and #(nodeInfo.entryIDs or {}) >= 2

    if art.shadow and TrySetAtlas(button.shadow, art.shadow, false) then
        button.shadow:SetSize(nodeSize * (art.shadowScale or SHADOW_SCALE), nodeSize * (art.shadowScale or SHADOW_SCALE))
        button.shadow:Show()
    else
        button.shadow:Hide()
    end

    if showSplit then
        ApplySplitChoiceIcons(button, nodeInfo, isAvailable, canInteract, art)
    else
        button.secondaryIcon:Hide()
        local iconInset = art.iconInset
        if nodeInfo and nodeInfo.isApexTalent and not nodeInfo.subTreeID then
            iconInset = math.max(iconInset or 0.16, 0.24)
        end
        SetIconInset(button.icon, button, iconInset)
        ApplyIconMask(button.icon, button.iconMask, art.iconMask)
        ApplyIconMask(button.disabledOverlay, button.disabledMask, art.iconMask)
        button.icon:SetDesaturated(not isSelected and not canInteract)
        button.icon:SetAlpha(isSelected and 1 or (isAvailable and 0.95 or 0.55))
    end

    local borderAtlas, visual = GetVisualBorderAtlas(art, state)
    local borderScale = art.borderScale or BORDER_SCALE
    if TrySetAtlas(button.stateBorder, borderAtlas, false) then
        button.stateBorder:SetSize(nodeSize * borderScale, nodeSize * borderScale)
        button.stateBorder:Show()
    else
        button.stateBorder:Hide()
    end
    if TrySetAtlas(button.stateBorderHover, borderAtlas, false) then
        button.stateBorderHover:SetSize(nodeSize * borderScale, nodeSize * borderScale)
        button.stateBorderHover:SetAlpha(visual == "selectable" and 1 or 0.7)
    end

    local glowScale = art.glowScale or GLOW_SCALE
    if visual == "selectable" and TrySetAtlas(button.glow, art.glow, false) then
        button.glow:SetSize(nodeSize * glowScale, nodeSize * glowScale)
        button.glow:Show()
    else
        button.glow:Hide()
    end

    if state.isGranted then
        button.grantedOverlay:Show()
    else
        button.grantedOverlay:Hide()
    end

    if not isAvailable and not isSelected then
        button.disabledOverlay:SetAlpha(0.45)
        button.disabledOverlay:Show()
    else
        button.disabledOverlay:Hide()
    end

    if state.isChoice and state.usesFlyout then
        button.choiceArrow:Show()
        button.choiceArrow:SetSize(math.max(12, nodeSize * 0.42), math.max(8, nodeSize * 0.28))
    else
        button.choiceArrow:Hide()
    end
end

local function AcquireNodeButton(canvas, index, nodeSize)
    if not canvas.nodePool[index] then
        local button = CreateFrame("Button", nil, canvas.content)
        button:SetSize(nodeSize, nodeSize)
        if button.SetClipsChildren then
            button:SetClipsChildren(false)
        end

        local shadow = button:CreateTexture(nil, "BACKGROUND", nil, 0)
        shadow:SetPoint("CENTER")
        shadow:Hide()
        button.shadow = shadow

        local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
        icon:SetPoint("TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", -4, 4)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon = icon

        local iconMask = button:CreateMaskTexture(nil, "ARTWORK")
        iconMask:SetAllPoints(icon)
        iconMask:Hide()
        button.iconMask = iconMask

        local secondaryIcon = button:CreateTexture(nil, "ARTWORK", nil, 1)
        secondaryIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        secondaryIcon:Hide()
        button.secondaryIcon = secondaryIcon

        local secondaryMask = button:CreateMaskTexture(nil, "ARTWORK")
        secondaryMask:SetAllPoints(secondaryIcon)
        secondaryMask:Hide()
        button.secondaryMask = secondaryMask

        local disabledOverlay = button:CreateTexture(nil, "ARTWORK", nil, 3)
        disabledOverlay:SetAllPoints()
        disabledOverlay:SetColorTexture(0, 0, 0, 0.45)
        disabledOverlay:Hide()
        button.disabledOverlay = disabledOverlay

        local disabledMask = button:CreateMaskTexture(nil, "ARTWORK")
        disabledMask:SetAllPoints(disabledOverlay)
        disabledMask:Hide()
        button.disabledMask = disabledMask

        local glow = button:CreateTexture(nil, "OVERLAY", nil, 0)
        glow:SetPoint("CENTER")
        glow:SetBlendMode("ADD")
        glow:Hide()
        button.glow = glow

        local stateBorder = button:CreateTexture(nil, "OVERLAY", nil, 1)
        stateBorder:SetPoint("CENTER")
        button.stateBorder = stateBorder

        local stateBorderHover = button:CreateTexture(nil, "OVERLAY", nil, 2)
        stateBorderHover:SetPoint("CENTER")
        stateBorderHover:SetBlendMode("ADD")
        stateBorderHover:Hide()
        button.stateBorderHover = stateBorderHover

        local grantedOverlay = button:CreateTexture(nil, "OVERLAY", nil, 3)
        grantedOverlay:SetPoint("BOTTOMRIGHT", 1, -1)
        if not TrySetAtlas(grantedOverlay, "talents-reason-granted", true) then
            grantedOverlay:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon")
            grantedOverlay:SetSize(14, 14)
        end
        grantedOverlay:Hide()
        button.grantedOverlay = grantedOverlay

        local choiceArrow = button:CreateTexture(nil, "OVERLAY", nil, 4)
        choiceArrow:SetPoint("TOP", button, "BOTTOM", 0, 4)
        if not TrySetAtlas(choiceArrow, "talents-icon-choice", true) then
            choiceArrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up")
            choiceArrow:SetSize(12, 8)
        end
        choiceArrow:Hide()
        button.choiceArrow = choiceArrow

        local rankBadge = button:CreateTexture(nil, "OVERLAY", nil, 4)
        rankBadge:SetPoint("BOTTOMRIGHT", 4, -4)
        rankBadge:SetSize(12, 12)
        rankBadge:Hide()
        button.rankBadge = rankBadge

        local rankText = button:CreateFontString(nil, "OVERLAY")
        rankText:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        rankText:SetPoint("CENTER", rankBadge, "CENTER", 0, 0)
        rankText:SetTextColor(RANK_GOLD[1], RANK_GOLD[2], RANK_GOLD[3], 1)
        rankText:SetJustifyH("CENTER")
        button.rankText = rankText

        button.apexPips = {}
        for pipIndex = 1, 4 do
            local pip = CreateFrame("Frame", nil, button)
            pip:SetSize(12, 12)
            pip:Hide()

            local ring = pip:CreateTexture(nil, "ARTWORK")
            ring:SetAllPoints()
            pip.ring = ring

            local label = pip:CreateFontString(nil, "OVERLAY")
            label:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
            label:SetPoint("CENTER", 0, 0)
            label:SetText("1")
            label:SetTextColor(RANK_GOLD[1], RANK_GOLD[2], RANK_GOLD[3], 1)
            pip.label = label

            button.apexPips[pipIndex] = pip
        end

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

local function PositionHeroEmblem(canvas, subTreeID, specID, heroBounds, nodeSize, fitScale)
    if not canvas.heroEmblem or not subTreeID or not heroBounds then
        HideHeroEmblem(canvas)
        return
    end

    local heroSize = math.max(nodeSize * HERO_NODE_SCALE, 36)
    local emblem = canvas.heroEmblem
    emblem:SetSize(heroSize, heroSize)
    emblem.subTreeID = subTreeID
    emblem.specID = specID

    local emblemX = (heroBounds.minX + heroBounds.maxX) / 2 - heroSize / 2
    local emblemY = heroBounds.minY - heroSize - (HERO_EMBLEM_GAP * fitScale)
    if emblemY < 0 then
        emblemY = 0
    end
    emblem:ClearAllPoints()
    emblem:SetPoint("TOPLEFT", canvas.content, "TOPLEFT", emblemX, -emblemY)

    local lib = LibStub and LibStub:GetLibrary("LibTalentTree-1.0", true)
    local subTreeInfo = lib and lib:GetSubTreeInfo(subTreeID)
    if subTreeInfo and subTreeInfo.iconElementID then
        emblem.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        emblem.icon:SetAtlas(subTreeInfo.iconElementID)
    else
        emblem.icon:SetTexture(136243)
        emblem.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    emblem.icon:SetDesaturated(false)
    emblem.icon:SetAlpha(1)

    local ar, ag, ab = LPL.Theme:GetColor("accent")
    emblem:SetBackdropBorderColor(ar, ag, ab, 1)
    emblem.bg:SetVertexColor(1, 1, 1)
    emblem:Show()
end

local function HideApexPips(button)
    local pips = button and button.apexPips
    if not pips then
        return
    end
    for i = 1, #pips do
        pips[i]:SetParent(button)
        pips[i]:Hide()
    end
end

local function HideExtraNodes(canvas, usedCount)
    for index = usedCount + 1, #canvas.nodePool do
        local button = canvas.nodePool[index]
        HideApexPips(button)
        button:Hide()
    end
end

local function HideExtraLines(canvas, usedCount)
    for index = usedCount + 1, #canvas.linePool do
        canvas.linePool[index]:Hide()
    end
end

local function AxisScale(values)
    local minValue = math.huge
    for i = 1, #values do
        minValue = math.min(minValue, values[i])
    end
    local map = {}
    for i = 1, #values do
        map[values[i]] = (values[i] - minValue) / POS_STEP
    end
    return map
end

local function AxisSpan(map)
    local maxValue = 0
    for _, scaled in pairs(map) do
        if scaled > maxValue then
            maxValue = scaled
        end
    end
    return maxValue
end

local function IsApexNode(nodeInfo)
    return nodeInfo and nodeInfo.isApexTalent and not nodeInfo.subTreeID
end

-- Pip centers sit on the gold ring at each corner, not over the icon.
local APEX_PIP_ANCHORS = {
    { "CENTER", "TOPLEFT", 1, -1 },
    { "CENTER", "TOPRIGHT", -1, -1 },
    { "CENTER", "BOTTOMRIGHT", -1, 1 },
    { "CENTER", "BOTTOMLEFT", 1, 1 },
}

local function EnsureApexPipArt(pip)
    if pip.apexArtReady then
        return
    end
    pip.fill = pip.fill or pip:CreateTexture(nil, "ARTWORK", nil, 1)
    pip.ringMask = pip.ringMask or pip:CreateMaskTexture()
    pip.fillMask = pip.fillMask or pip:CreateMaskTexture()
    pip.ringMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    pip.fillMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    pip.ringMask:SetAllPoints(pip.ring)
    pip.fillMask:SetAllPoints(pip.fill)
    if pip.ring.AddMaskTexture then
        pip.ring:AddMaskTexture(pip.ringMask)
    end
    if pip.fill.AddMaskTexture then
        pip.fill:AddMaskTexture(pip.fillMask)
    end
    pip.apexArtReady = true
end

local function PaintApexPip(pip, pipSize, filled)
    EnsureApexPipArt(pip)
    pip:SetSize(pipSize, pipSize)
    pip:EnableMouse(false)
    pip.label:Hide()
    if pip.fill then
        pip.fill:Hide()
    end

    pip.ring:ClearAllPoints()
    pip.ring:SetAllPoints()
    pip.ringMask:ClearAllPoints()
    pip.ringMask:SetAllPoints(pip.ring)
    pip.ring:SetVertexColor(1, 1, 1, 1)
    if filled then
        pip.ring:SetColorTexture(RANK_GOLD[1], RANK_GOLD[2], RANK_GOLD[3], 1)
    else
        pip.ring:SetColorTexture(0.32, 0.32, 0.32, 1)
    end
end

local function ApplyApexPips(button, state, nodeSize, sandbox)
    local pips = button.apexPips
    if not pips then
        return false
    end

    if not IsApexNode(button.nodeInfo) then
        HideApexPips(button)
        return false
    end

    local maxRank = state.maxRank or LPL.TalentTree:GetNodeMaxRanks(button.nodeInfo)
    local pipCount = math.min(4, math.max(1, maxRank))
    local pipSize = math.max(10, math.floor(nodeSize * 0.2))
    local active = 0
    if sandbox and sandbox.GetNodeRank and button.nodeInfo then
        active = tonumber(sandbox:GetNodeRank(button.nodeInfo.ID)) or 0
    else
        active = tonumber(state.activeRank) or 0
        if state.isGranted and active >= pipCount then
            active = 0
        end
    end
    if active < 0 then
        active = 0
    elseif active > pipCount then
        active = pipCount
    end

    for i = 1, 4 do
        local pip = pips[i]
        pip:SetParent(button)
        if i > pipCount then
            pip:Hide()
        else
            pip:ClearAllPoints()
            local anchor = APEX_PIP_ANCHORS[i]
            pip:SetPoint(anchor[1], button, anchor[2], anchor[3], anchor[4])
            PaintApexPip(pip, pipSize, active >= i)
            pip:SetFrameLevel((button:GetFrameLevel() or 1) + 6)
            pip:Show()
        end
    end

    return true
end

local function ColorLine(line, accent)
    local color = accent and LINE_GOLD or LINE_BLUE
    if line.SetVertexColor then
        line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
    if line.SetAlpha then
        line:SetAlpha(color[4] or 1)
    end
end

local function AcquireLine(canvas, index)
    if canvas.linePool[index] then
        return canvas.linePool[index]
    end

    local parent = canvas.lineLayer or canvas.content
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetBlendMode("BLEND")
    line:Hide()
    canvas.linePool[index] = line
    return line
end

local function DrawEdge(canvas, lineIndex, startID, endID, accent)
    local startPos = canvas.nodePositions and canvas.nodePositions[startID]
    local endPos = canvas.nodePositions and canvas.nodePositions[endID]
    if not startPos or not endPos then
        return lineIndex
    end

    local dx = endPos.x - startPos.x
    local dy = endPos.y - startPos.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 4 then
        return lineIndex
    end

    local line = AcquireLine(canvas, lineIndex)
    ColorLine(line, accent)
    line:SetSize(length, LINE_THICKNESS)
    line:ClearAllPoints()
    line:SetPoint(
        "CENTER",
        canvas.content,
        "TOPLEFT",
        (startPos.x + endPos.x) / 2,
        -((startPos.y + endPos.y) / 2)
    )
    if line.SetRotation then
        line:SetRotation(-math.atan2(dy, dx))
    end
    line:Show()
    return lineIndex + 1
end

function LPL.TalentCanvas:Create(parent, options)
    options = options or {}
    local bottomInset = options.bottomInset or 12

    local frame = LPL:CreatePanel(nil, parent)
    LPL.Theme:ApplyBackdrop(frame, "panel", "bgPrimary", "border")
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -96)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, bottomInset)

    local viewport = CreateFrame("Frame", nil, frame)
    viewport:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -10)
    viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    viewport:SetClipsChildren(true)
    local viewportBg = viewport:CreateTexture(nil, "BACKGROUND")
    viewportBg:SetAllPoints()
    viewportBg:SetColorTexture(0, 0, 0, 1)
    viewport.background = viewportBg

    local content = CreateFrame("Frame", nil, viewport)
    content:SetPoint("CENTER")
    content:SetSize(400, 300)

    local lineLayer = CreateFrame("Frame", nil, content)
    lineLayer:SetAllPoints(content)
    lineLayer:SetFrameLevel((content:GetFrameLevel() or 1) + 1)

    frame.viewport = viewport
    frame.content = content
    frame.lineLayer = lineLayer
    frame.nodePool = {}
    frame.linePool = {}
    frame.nodePositions = {}
    frame.nodeButtons = {}
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
        local maxRank = LPL.TalentTree:GetNodeMaxRanks(nodeInfo)
        state.maxRank = maxRank
        local isSelected = state.activeRank > 0 or state.isGranted
        local showApexPips = ApplyApexPips(button, state, nodeSize, sandbox)
        if showApexPips then
            button.rankText:Hide()
            if button.rankBadge then
                button.rankBadge:Hide()
            end
        elseif maxRank > 1 and not state.isChoice then
            local badgeSize = math.max(12, math.floor(nodeSize * 0.32))
            local fontSize = math.max(11, math.floor(nodeSize * 0.36))
            if button.rankBadge then
                button.rankBadge:SetSize(badgeSize, badgeSize)
                local badgeAtlas = "talents-node-circle-gray"
                if isSelected or state.canPurchase then
                    badgeAtlas = "talents-node-circle-yellow"
                end
                if not TrySetAtlas(button.rankBadge, badgeAtlas, false) then
                    button.rankBadge:SetColorTexture(0, 0, 0, 0.8)
                end
                button.rankBadge:Show()
            end
            button.rankText:SetText(tostring(state.activeRank))
            local color = RANK_GOLD
            if state.canPurchase then
                color = RANK_GREEN
            elseif not isSelected and not state.meetsGates then
                color = RANK_GRAY
            end
            button.rankText:SetTextColor(color[1], color[2], color[3], 1)
            button.rankText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
            button.rankText:Show()
        else
            button.rankText:Hide()
            if button.rankBadge then
                button.rankBadge:Hide()
            end
        end

        ApplyNodeVisuals(button, state, nodeSize)

        button:SetScript("OnEnter", function(self)
            if self.stateBorderHover then
                self.stateBorderHover:Show()
            end
            LPL.TalentTree:ShowNodeTooltip(self, self.nodeInfo, self.specID, sandbox)
        end)
        button:SetScript("OnLeave", function(self)
            if self.stateBorderHover then
                self.stateBorderHover:Hide()
            end
            LPL:ClearGameTooltipData(GameTooltip)
        end)

        button:SetScript("OnClick", function(self, mouseButton)
            local ctx = GetInteractionContext(view)
            if not ctx.sandbox then
                return
            end

            local clickedNode = self.nodeInfo
            if not clickedNode then
                return
            end

            local changed = LPL.TalentInteractions:HandleNodeClick(
                ctx.sandbox,
                clickedNode,
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
        if self._rendering then
            return
        end
        self._rendering = true

        if not LPL.TalentTree.ready then
            self.loadingLabel:Show()
            self._rendering = false
            return
        end
        self.loadingLabel:Hide()

        local view = LPL.TalentTree:ResolveViewState()
        local sandbox = self.getSandbox and self.getSandbox()
        local nodes = LPL.TalentTree:GetVisibleNodes(view.classID, view.specID, view.subTreeID, view.level)
        wipe(self.nodePositions)
        if self.nodeButtons then
            wipe(self.nodeButtons)
        else
            self.nodeButtons = {}
        end

        local grouped = {
            class = { items = {}, xs = {}, ys = {} },
            hero = { items = {}, xs = {}, ys = {} },
            spec = { items = {}, xs = {}, ys = {} },
        }

        for _, nodeInfo in ipairs(nodes) do
            if not nodeInfo.isSubTreeSelection then
                local posX, posY = LPL.TalentTree:GetNodePosition(nodeInfo.ID)
                if posX and posY then
                    local pool = LPL.TalentTree:GetNodePointPool(nodeInfo.ID, view.subTreeID) or "spec"
                    local group = grouped[pool]
                    if group then
                        group.items[#group.items + 1] = { info = nodeInfo, posX = posX, posY = posY }
                        group.xs[#group.xs + 1] = posX
                        group.ys[#group.ys + 1] = posY
                    end
                end
            end
        end

        local columns = {}
        for _, pool in ipairs({ "class", "hero", "spec" }) do
            local group = grouped[pool]
            if #group.items > 0 then
                local xMap = AxisScale(group.xs)
                local yMap = AxisScale(group.ys)
                columns[#columns + 1] = {
                    pool = pool,
                    items = group.items,
                    xMap = xMap,
                    yMap = yMap,
                    spanX = AxisSpan(xMap),
                    spanY = AxisSpan(yMap),
                }
            end
        end

        if #columns == 0 then
            self.loadingLabel:SetText("No talent nodes to display.")
            self.loadingLabel:Show()
            HideExtraNodes(self, 0)
            HideExtraLines(self, 0)
            HideHeroEmblem(self)
            self._rendering = false
            return
        end

        local totalCellsX = 0
        local maxCellsY = 0
        for index, column in ipairs(columns) do
            if index > 1 then
                totalCellsX = totalCellsX + COLUMN_GAP
            end
            column.originX = totalCellsX
            totalCellsX = totalCellsX + column.spanX + 1
            maxCellsY = math.max(maxCellsY, column.spanY + 1)
        end

        local heroEmblemReserve = 0
        if view.subTreeID then
            heroEmblemReserve = math.max(BASE_NODE_SIZE * HERO_NODE_SCALE, 36) + HERO_EMBLEM_GAP
        end
        local rawWidth = totalCellsX * BASE_COL_WIDTH + CANVAS_PADDING * 2
        local rawHeight = maxCellsY * BASE_ROW_HEIGHT + CANVAS_PADDING * 2 + heroEmblemReserve

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
        local emblemReserve = 0
        if view.subTreeID then
            emblemReserve = math.max(nodeSize * HERO_NODE_SCALE, 36) + HERO_EMBLEM_GAP * fitScale
        end

        local contentWidth = totalCellsX * colWidth + padding * 2
        local contentHeight = maxCellsY * rowHeight + padding * 2 + emblemReserve
        self.content:SetSize(contentWidth, contentHeight)
        self.content:SetScale(1)
        self.content:ClearAllPoints()
        self.content:SetPoint("CENTER", self.viewport, "CENTER")

        local layout = {}
        local heroBounds
        local nodeIndex = 0
        local contentLevel = self.content:GetFrameLevel()

        for _, column in ipairs(columns) do
            local yOffset = padding
            if column.pool == "hero" then
                yOffset = yOffset + emblemReserve
            end
            for _, item in ipairs(column.items) do
                nodeIndex = nodeIndex + 1
                local info = item.info
                local artKind = LPL.TalentTree:GetNodeArtKind(info)
                local size = math.max(nodeSize, 18)
                if artKind == "choice" then
                    size = math.max(nodeSize * CHOICE_NODE_SCALE, 18)
                elseif IsApexNode(info) then
                    size = math.max(nodeSize * APEX_NODE_SCALE, 18)
                end
                local button = AcquireNodeButton(self, nodeIndex, size)
                local x = padding + (column.originX + column.xMap[item.posX]) * colWidth
                local y = yOffset + column.yMap[item.posY] * rowHeight
                if size ~= nodeSize then
                    x = x - (size - nodeSize) / 2
                    y = y - (size - nodeSize) / 2
                end
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, -y)
                button:SetFrameLevel(contentLevel + 10)
                self.nodeButtons[info.ID] = button
                self.nodePositions[info.ID] = { x = x + size / 2, y = y + size / 2 }
                layout[info.ID] = { info = info, pool = column.pool }

                if column.pool == "hero" then
                    heroBounds = heroBounds or { minX = math.huge, maxX = 0, minY = math.huge }
                    heroBounds.minX = math.min(heroBounds.minX, x)
                    heroBounds.maxX = math.max(heroBounds.maxX, x + size)
                    heroBounds.minY = math.min(heroBounds.minY, y)
                end

                WireNodeButton(button, info, view, size)
            end
        end
        HideExtraNodes(self, nodeIndex)

        PositionHeroEmblem(self, view.subTreeID, view.specID, heroBounds, nodeSize, fitScale)

        local lineIndex = 1
        if self.lineLayer then
            self.lineLayer:SetFrameLevel((self.content:GetFrameLevel() or 1) + 1)
        end
        for nodeID, data in pairs(layout) do
            local edges = LPL.TalentTree:GetNodeEdges(nodeID)
            if edges then
                local edgeActive = false
                if sandbox then
                    local activeRank = LPL.TalentInteractions:GetActiveRank(sandbox, data.info, view.specID)
                    edgeActive = activeRank >= LPL.TalentTree:GetNodeMaxRanks(data.info)
                end
                for _, edge in pairs(edges) do
                    local targetID = type(edge) == "table" and edge.targetNode
                    if targetID and layout[targetID] then
                        lineIndex = DrawEdge(self, lineIndex, nodeID, targetID, edgeActive)
                    end
                end
            end
        end
        HideExtraLines(self, lineIndex - 1)

        for index = 1, nodeIndex do
            self.nodePool[index]:Raise()
            local pips = self.nodePool[index].apexPips
            if pips then
                for pipIndex = 1, #pips do
                    if pips[pipIndex]:IsShown() then
                        pips[pipIndex]:Raise()
                    end
                end
            end
        end
        if self.heroEmblem then
            self.heroEmblem:Raise()
        end
        if self.choiceFlyout and self.choiceFlyout.frame then
            if self.choiceFlyout.nodeInfo and self.nodeButtons[self.choiceFlyout.nodeInfo.ID] then
                local anchor = self.nodeButtons[self.choiceFlyout.nodeInfo.ID]
                self.choiceFlyout.anchorButton = anchor
                self.choiceFlyout.frame:ClearAllPoints()
                self.choiceFlyout.frame:SetPoint("BOTTOM", anchor, "TOP", 0, -10)
                self.choiceFlyout.frame:Raise()
            elseif self.choiceFlyout.frame:IsShown() then
                self.choiceFlyout:Hide()
            end
        end

        self._rendering = false
    end

    frame:SetScript("OnHide", function()
        if frame.choiceFlyout then
            frame.choiceFlyout:Hide()
        end
    end)

    frame:SetScript("OnSizeChanged", function()
        if frame:IsShown() and not frame._rendering then
            frame:Render()
        end
    end)

    return frame
end
