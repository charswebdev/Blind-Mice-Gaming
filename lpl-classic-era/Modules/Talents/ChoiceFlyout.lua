local addonName, LPL = ...

LPL.TalentChoiceFlyout = {}

local FLYOUT_ART = {
    circle = {
        iconMask = "talents-node-circle-mask",
        shadow = "talents-node-choiceflyout-circle-shadow",
        normal = "talents-node-choiceflyout-circle-gray",
        selectable = "talents-node-choiceflyout-circle-green",
        maxed = "talents-node-choiceflyout-circle-yellow",
        glow = "talents-node-choiceflyout-circle-greenglow",
        iconInset = 0.16,
    },
    square = {
        iconMask = "talents-node-choiceflyout-mask",
        shadow = "talents-node-choiceflyout-square-shadow",
        normal = "talents-node-choiceflyout-square-gray",
        selectable = "talents-node-choiceflyout-square-green",
        maxed = "talents-node-choiceflyout-square-yellow",
        glow = "talents-node-choiceflyout-square-greenglow",
        iconInset = 0.12,
    },
}

local LINE_GOLD = { 1, 0.82, 0, 0.95 }
local LINE_GRAY = { 0.55, 0.55, 0.55, 0.75 }

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

local function GetOptionArt(entryID)
    local entryType = LPL.TalentTree:GetEntryType(entryID)
    if Enum.TraitNodeEntryType and (
        entryType == Enum.TraitNodeEntryType.SpendSquare
        or entryType == Enum.TraitNodeEntryType.SpendCapstoneSquare
    ) then
        return FLYOUT_ART.square
    end
    return FLYOUT_ART.circle
end

local function GetArcOffset(index, count, radius)
    if count <= 1 then
        return 0, radius
    end

    -- Sweep left-to-right so entryIDs[1] matches Blizzard's first (top) choice.
    local minAngle = math.rad(128)
    local maxAngle = math.rad(52)
    local angle = minAngle + (index - 1) * (maxAngle - minAngle) / (count - 1)
    return math.cos(angle) * radius, math.sin(angle) * radius
end

local function ApplyOptionVisual(option, art, isSelected, canSelect)
    local pad = math.max(4, math.floor(option:GetWidth() * (art.iconInset or 0.14)))
    option.icon:ClearAllPoints()
    option.icon:SetPoint("TOPLEFT", pad, -pad)
    option.icon:SetPoint("BOTTOMRIGHT", -pad, pad)
    ApplyIconMask(option.icon, option.iconMask, art.iconMask)

    if TrySetAtlas(option.shadow, art.shadow, false) then
        option.shadow:SetSize(option:GetWidth() * 1.3, option:GetHeight() * 1.3)
        option.shadow:Show()
    else
        option.shadow:Hide()
    end

    local borderAtlas = art.normal
    if isSelected then
        borderAtlas = art.maxed
    elseif canSelect then
        borderAtlas = art.selectable
    end
    if TrySetAtlas(option.ring, borderAtlas, false) then
        option.ring:SetSize(option:GetWidth() * 1.4, option:GetHeight() * 1.4)
        option.ring:Show()
    end
    if TrySetAtlas(option.hoverGlow, borderAtlas, false) then
        option.hoverGlow:SetSize(option:GetWidth() * 1.4, option:GetHeight() * 1.4)
    end

    if canSelect and not isSelected and TrySetAtlas(option.glow, art.glow, false) then
        option.glow:SetSize(option:GetWidth() * 1.55, option:GetHeight() * 1.55)
        option.glow:Show()
    else
        option.glow:Hide()
    end

    option.icon:SetDesaturated(not isSelected and not canSelect)
    option.icon:SetAlpha(isSelected and 1 or (canSelect and 1 or 0.5))
end

local function AcquireConnectorLine(flyout, index)
    if not flyout.linePool[index] then
        local line
        if flyout.frame.CreateLine then
            line = flyout.frame:CreateLine(nil, "BACKGROUND")
            line:SetThickness(2.5)
        end
        flyout.linePool[index] = line
    end
    return flyout.linePool[index]
end

local function AcquireOptionButton(flyout, index, size)
    if not flyout.optionPool[index] then
        local button = CreateFrame("Button", nil, flyout.frame)
        button:SetSize(size, size)
        button:SetFrameLevel(flyout.frame:GetFrameLevel() + 2)

        local shadow = button:CreateTexture(nil, "BACKGROUND", nil, 0)
        shadow:SetPoint("CENTER")
        button.shadow = shadow

        local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
        icon:SetPoint("TOPLEFT", 6, -6)
        icon:SetPoint("BOTTOMRIGHT", -6, 6)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon = icon

        local iconMask = button:CreateMaskTexture(nil, "ARTWORK")
        iconMask:SetAllPoints(icon)
        iconMask:Hide()
        button.iconMask = iconMask

        local glow = button:CreateTexture(nil, "OVERLAY", nil, 0)
        glow:SetPoint("CENTER")
        glow:SetBlendMode("ADD")
        glow:Hide()
        button.glow = glow

        local ring = button:CreateTexture(nil, "OVERLAY", nil, 1)
        ring:SetPoint("CENTER")
        button.ring = ring

        local hoverGlow = button:CreateTexture(nil, "OVERLAY", nil, 2)
        hoverGlow:SetPoint("CENTER")
        hoverGlow:SetBlendMode("ADD")
        hoverGlow:Hide()
        button.hoverGlow = hoverGlow

        button:SetScript("OnEnter", function(self)
            self.hoverGlow:Show()
            if self.entryID and self.nodeInfo then
                LPL.TalentTree:ShowEntryTooltip(self, self.entryID, self.nodeInfo, self.tooltipRank or 1)
            end
        end)
        button:SetScript("OnLeave", function(self)
            self.hoverGlow:Hide()
            LPL:ClearGameTooltipData(GameTooltip)
        end)

        flyout.optionPool[index] = button
    end

    local button = flyout.optionPool[index]
    button:SetSize(size, size)
    button:Show()
    return button
end

local function HideExtra(flyout, optionCount, lineCount)
    for index = optionCount + 1, #flyout.optionPool do
        flyout.optionPool[index]:Hide()
    end
    for index = lineCount + 1, #flyout.linePool do
        if flyout.linePool[index] then
            flyout.linePool[index]:Hide()
        end
    end
end

local function ShouldDismissFlyout(flyout)
    if not flyout.frame:IsShown() then
        return false
    end

    if GetMouseFoci and DoesAncestryIncludeAny then
        local foci = GetMouseFoci()
        if DoesAncestryIncludeAny(flyout.frame, foci) then
            return false
        end
        if flyout.anchorButton and DoesAncestryIncludeAny(flyout.anchorButton, foci) then
            return false
        end
        return true
    end

    if MouseIsOver(flyout.frame) then
        return false
    end
    if flyout.anchorButton and MouseIsOver(flyout.anchorButton) then
        return false
    end
    for _, option in ipairs(flyout.optionPool) do
        if option:IsShown() and MouseIsOver(option) then
            return false
        end
    end
    return true
end

function LPL.TalentChoiceFlyout:Create(parent)
    local flyout = {
        optionPool = {},
        linePool = {},
        anchorButton = nil,
        nodeInfo = nil,
    }

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel((parent:GetFrameLevel() or 1) + 50)
    frame:EnableMouse(true)
    frame:Hide()

    flyout.frame = frame
    flyout.parent = parent

    flyout.dismissWatcher = CreateFrame("Frame", nil, UIParent)
    flyout.dismissWatcher:Hide()
    flyout.dismissWatcher:RegisterEvent("GLOBAL_MOUSE_UP")
    flyout.dismissWatcher:SetScript("OnEvent", function(_, _, button)
        if button == "LeftButton" and ShouldDismissFlyout(flyout) then
            flyout:Hide()
        end
    end)

    frame:SetScript("OnHide", function()
        flyout.anchorButton = nil
        flyout.nodeInfo = nil
        flyout.dismissWatcher:Hide()
    end)

    function flyout:Hide()
        self.frame:Hide()
    end

    function flyout:IsShownFor(nodeID)
        return self.frame:IsShown() and self.nodeInfo and self.nodeInfo.ID == nodeID
    end

    function flyout:Toggle(nodeButton, nodeInfo, state, context)
        if self:IsShownFor(nodeInfo.ID) then
            self:Hide()
            return
        end

        self.anchorButton = nodeButton
        self.nodeInfo = nodeInfo
        self.context = context

        local entries = nodeInfo.entryIDs or {}
        local count = #entries
        if count == 0 then
            return
        end

        local anchorSize = nodeButton:GetWidth() or 30
        local optionSize = math.max(46, math.floor(anchorSize * 1.55))
        local radius = math.max(optionSize * 1.05, anchorSize * 1.45)

        frame:ClearAllPoints()
        frame:SetPoint("BOTTOM", nodeButton, "TOP", 0, -8)
        frame:SetSize(radius * 2 + optionSize, radius + optionSize)
        frame:Raise()

        local centerX = frame:GetWidth() / 2
        local baseY = 8

        for index, entryID in ipairs(entries) do
            local offsetX, offsetY = GetArcOffset(index, count, radius)
            local option = AcquireOptionButton(self, index, optionSize)
            option:ClearAllPoints()
            option:SetPoint("CENTER", frame, "BOTTOM", offsetX, baseY + offsetY)
            option.entryID = entryID
            option.nodeInfo = nodeInfo
            option.tooltipRank = 1
            option.flyout = self

            LPL.TalentTree:ApplyEntryIcon(option.icon, entryID)

            local isSelected = state.selectedEntryID == entryID
            local canSelect = not isSelected and (state.canPurchase or state.selectedEntryID ~= nil)
            ApplyOptionVisual(option, GetOptionArt(entryID), isSelected, canSelect)

            local line = AcquireConnectorLine(self, index)
            if line and line.SetStartPoint then
                local color = isSelected and LINE_GOLD or LINE_GRAY
                if line.SetVertexColor then
                    line:SetVertexColor(color[1], color[2], color[3], color[4])
                elseif line.SetColorTexture then
                    line:SetColorTexture(color[1], color[2], color[3], color[4])
                end
                line:SetStartPoint("BOTTOM", frame, "BOTTOM", centerX, baseY)
                line:SetEndPoint("CENTER", option, "CENTER")
                line:Show()
            end

            option:SetScript("OnClick", function(btn)
                if btn.entryID == state.selectedEntryID then
                    return
                end
                local ctx = btn.flyout.context
                if LPL.TalentInteractions:SetSelection(
                    ctx.sandbox, nodeInfo, btn.entryID,
                    ctx.specID, ctx.classID, ctx.subTreeID, ctx.level
                ) then
                    if ctx.onChanged then
                        ctx.onChanged()
                    end
                end
                btn.flyout:Hide()
            end)
        end

        HideExtra(self, count, count)
        self.frame:Show()
        self.dismissWatcher:Show()
    end

    return flyout
end
