local addonName, LPL = ...

LPL.TalentChoiceFlyout = {}

local ATLAS = {
    circle = "talents-node-circle",
    green = "talents-node-green",
    yellow = "talents-node-yellow",
    mask = "talents-node-circle-mask",
    shadow = "talents-node-circle-shadow",
    hover = "talents-node-circle-hover",
}

local function TrySetAtlas(texture, atlasName, useAtlasSize)
    if not texture or not atlasName or not texture.SetAtlas then
        return false
    end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlasName) then
        return false
    end
    return pcall(texture.SetAtlas, texture, atlasName, useAtlasSize == true)
end

local function GetArcOffset(index, count, radius)
    if count <= 1 then
        return 0, radius
    end

    -- Fan options in an arc above the anchor node (Blizzard-style).
    local minAngle = math.rad(52)
    local maxAngle = math.rad(128)
    local angle = minAngle + (index - 1) * (maxAngle - minAngle) / (count - 1)
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    return x, y
end

local function ApplyOptionVisual(option, isSelected, canSelect)
    local ringAtlas = ATLAS.circle
    if isSelected then
        ringAtlas = ATLAS.green
    elseif canSelect then
        ringAtlas = ATLAS.yellow
    end

    if not TrySetAtlas(option.ring, ringAtlas, true) then
        option.ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
    end

    option.icon:SetDesaturated(not isSelected and not canSelect)
    option.icon:SetAlpha(isSelected and 1 or (canSelect and 1 or 0.45))
    option.selectedGlow:SetShown(isSelected)
    option.hoverGlow:SetShown(false)
end

local function AcquireConnectorLine(flyout, index)
    if not flyout.linePool[index] then
        local line
        if flyout.frame.CreateLine then
            line = flyout.frame:CreateLine(nil, "BACKGROUND")
            line:SetThickness(1.25)
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
        if not TrySetAtlas(shadow, ATLAS.shadow, true) then
            shadow:Hide()
        end
        button.shadow = shadow

        local ring = button:CreateTexture(nil, "ARTWORK", nil, 1)
        ring:SetPoint("CENTER")
        if not TrySetAtlas(ring, ATLAS.circle, true) then
            ring:SetAllPoints()
            ring:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        end
        button.ring = ring

        local icon = button:CreateTexture(nil, "ARTWORK", nil, 2)
        icon:SetPoint("TOPLEFT", 6, -6)
        icon:SetPoint("BOTTOMRIGHT", -6, 6)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.icon = icon

        if button.icon.AddMaskTexture then
            local mask = button:CreateMaskTexture(nil, "ARTWORK")
            if TrySetAtlas(mask, ATLAS.mask, true) then
                mask:SetAllPoints(icon)
                icon:AddMaskTexture(mask)
                button.iconMask = mask
            end
        end

        local selectedGlow = button:CreateTexture(nil, "OVERLAY", nil, 1)
        selectedGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        selectedGlow:SetBlendMode("ADD")
        selectedGlow:SetPoint("TOPLEFT", -4, 4)
        selectedGlow:SetPoint("BOTTOMRIGHT", 4, -4)
        selectedGlow:Hide()
        button.selectedGlow = selectedGlow

        local hoverGlow = button:CreateTexture(nil, "OVERLAY", nil, 2)
        hoverGlow:SetPoint("CENTER")
        if not TrySetAtlas(hoverGlow, ATLAS.hover, true) then
            hoverGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            hoverGlow:SetBlendMode("ADD")
            hoverGlow:SetPoint("TOPLEFT", -6, 6)
            hoverGlow:SetPoint("BOTTOMRIGHT", 6, -6)
        end
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
    frame:SetFrameStrata("TOOLTIP")
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
        local optionSize = math.max(44, math.floor(anchorSize * 1.45))
        local radius = math.max(optionSize * 0.95, anchorSize * 1.35)

        frame:ClearAllPoints()
        frame:SetPoint("BOTTOM", nodeButton, "TOP", 0, -10)
        frame:SetSize(radius * 2 + optionSize, radius + optionSize)

        local br, bg, bb = LPL.Theme:GetColor("border")
        local ar, ag, ab = LPL.Theme:GetColor("accent")
        local centerX = frame:GetWidth() / 2
        local baseY = 6

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
            ApplyOptionVisual(option, isSelected, canSelect)

            local line = AcquireConnectorLine(self, index)
            if line and line.SetStartPoint then
                line:SetColorTexture(ar, ag, ab, isSelected and 0.95 or 0.45)
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
