local addonName, LPL = ...

LPL.EquipmentSlotButton = {}

local defs = LPL.EquipmentDefinitions
local codec = LPL.EquipmentCodec
local itemInfo = LPL.EquipmentItemInfo
local cursor = LPL.EquipmentCursor

local GEM_ICON_SIZE = defs.GEM_ICON_SIZE or 12
local SOCKET_ICON = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Blue"
local MAX_SOCKET_PIPS = 3
local TRACK_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local TRACK_FILL_COLOR = { 1.00, 0.85, 0.25, 1.00 }
local TRACK_EMPTY_COLOR = { 0.20, 0.20, 0.24, 0.95 }
local TRACK_BG_COLOR = { 0.10, 0.10, 0.12, 0.90 }

local function ApplySlotChrome(frame)
    LPL.Theme:ApplyBackdrop(frame, "button", "actionBarSlotBg", "actionBarSlotBorder")
end

local function IsRightMouseButton(button)
    return button == "RightButton" or button == 2
end

local function NotifyCombatError()
    local ok, err = codec:CanEdit()
    if not ok then
        print("|cffff6060LPL:|r " .. (err or "Cannot edit equipment sets in combat."))
    end
    return ok
end

local function SetLabelColor(label, r, g, b, a)
    if label and type(r) == "number" and type(g) == "number" and type(b) == "number" then
        label:SetTextColor(r, g, b, type(a) == "number" and a or 1)
    end
end

local function HideGemIcons(gemIcons)
    for _, icon in ipairs(gemIcons) do
        icon:Hide()
    end
end

local function HideSocketPips(socketPips)
    for _, pip in ipairs(socketPips) do
        pip:Hide()
    end
end

local function SetTextureColor(texture, color)
    if texture and color then
        texture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
end

local function CreateUpgradeTrack(parent)
    local trackHeight = defs.UPGRADE_TRACK_HEIGHT or 3
    local track = CreateFrame("Frame", nil, parent)
    track:SetHeight(trackHeight)
    track:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", defs.UPGRADE_TRACK_INSET or 3, 2)
    track:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(defs.UPGRADE_TRACK_INSET or 3), 2)
    track:Hide()

    track.BG = track:CreateTexture(nil, "BACKGROUND")
    track.BG:SetAllPoints()
    track.BG:SetTexture(TRACK_TEXTURE)
    SetTextureColor(track.BG, TRACK_BG_COLOR)

    track.Segments = {}
    local maxSegments = defs.MAX_UPGRADE_SEGMENTS or 16
    for index = 1, maxSegments do
        local segment = track:CreateTexture(nil, "ARTWORK")
        segment:SetTexture(TRACK_TEXTURE)
        segment:Hide()
        track.Segments[index] = segment
    end

    return track
end

local function UpdateUpgradeTrack(track, upgradeInfo)
    if not track then
        return false
    end

    local maxLevel = upgradeInfo and tonumber(upgradeInfo.maxLevel)
    local currentLevel = upgradeInfo and tonumber(upgradeInfo.currentLevel) or 0
    if not maxLevel or maxLevel < 1 then
        track:Hide()
        return false
    end

    maxLevel = math.min(math.floor(maxLevel + 0.5), #track.Segments)
    currentLevel = math.max(0, math.min(math.floor(currentLevel + 0.5), maxLevel))

    track:Show()
    local width = track:GetWidth()
    if width <= 0 then
        width = (defs.DETAIL_WIDTH or 130) - ((defs.UPGRADE_TRACK_INSET or 3) * 2)
    end

    local gap = defs.UPGRADE_TRACK_GAP or 1
    local totalGaps = math.max(0, maxLevel - 1) * gap
    local segmentWidth = (width - totalGaps) / maxLevel
    if segmentWidth < 1 then
        gap = 0
        segmentWidth = width / maxLevel
    end

    local offsetX = 0
    for index = 1, #track.Segments do
        local segment = track.Segments[index]
        if index <= maxLevel then
            segment:ClearAllPoints()
            segment:SetPoint("LEFT", track, "LEFT", offsetX, 0)
            segment:SetSize(segmentWidth, track:GetHeight())
            if index <= currentLevel then
                SetTextureColor(segment, TRACK_FILL_COLOR)
            else
                SetTextureColor(segment, TRACK_EMPTY_COLOR)
            end
            segment:Show()
            offsetX = offsetX + segmentWidth + gap
        else
            segment:Hide()
        end
    end

    return true
end

local function GetGemRowBottomInset(hasUpgradeTrack)
    if hasUpgradeTrack then
        return 3 + (defs.UPGRADE_TRACK_HEIGHT or 3) + 2
    end
    return 3
end

local function LayoutDetailLabels(detail)
    detail.NameLabel:Hide()
    detail.UpgradeLabel:ClearAllPoints()
    detail.EnchantLabel:ClearAllPoints()
    detail.GemRow:ClearAllPoints()

    detail.UpgradeLabel:SetPoint("TOPLEFT", detail, "TOPLEFT", 4, -2)
    detail.UpgradeLabel:SetPoint("RIGHT", detail, "RIGHT", -4, 0)

    detail.EnchantLabel:SetPoint("TOPLEFT", detail.UpgradeLabel, "BOTTOMLEFT", 0, 0)
    detail.EnchantLabel:SetPoint("RIGHT", detail.GemRow, "LEFT", -2, 0)
    detail.GemRow:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -3, GetGemRowBottomInset(false))
end

local function SetItemLevelDisplay(button, entry)
    local itemLevel = button.ItemLevel
    if not itemLevel then
        return
    end

    if entry and entry.itemLevel then
        itemLevel:SetText(tostring(entry.itemLevel))
        if itemInfo then
            SetLabelColor(itemLevel, itemInfo:GetItemQualityColor(entry.link))
        else
            SetLabelColor(itemLevel, LPL.Theme:GetColor("textBright"))
        end
        itemLevel:Show()
    else
        itemLevel:Hide()
    end
end

local function ApplyRowLayout(row, button, detail, nameLabel, layout)
    button:ClearAllPoints()
    detail:ClearAllPoints()
    nameLabel:ClearAllPoints()

    local rowWidth = defs.SLOT_SIZE + defs.DETAIL_WIDTH + 2
    local rowHeight = defs:GetRowHeight()
    row:SetSize(rowWidth, rowHeight)

    nameLabel:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    nameLabel:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    nameLabel:SetHeight(defs.NAME_ROW_HEIGHT)

    detail:SetSize(defs.DETAIL_WIDTH, defs.SLOT_ROW_HEIGHT)

    if layout == "right" then
        button:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        detail:SetPoint("RIGHT", button, "LEFT", -2, 0)
    else
        button:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
        detail:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        detail:SetPoint("LEFT", button, "RIGHT", 2, 0)
    end
end

function LPL.EquipmentSlotButton:Create(parent, slotID, options)
    options = options or {}
    local layout = options.layout or "left"

    local row = CreateFrame("Frame", nil, parent)
    row:Show()

    local nameLabel = LPL:CreateLabel(row, "small")
    nameLabel:SetJustifyH("LEFT")
    if nameLabel.SetMaxLines then
        nameLabel:SetMaxLines(1)
    end
    nameLabel:Hide()

    local button = CreateFrame("Button", nil, row, "BackdropTemplate")
    button:SetSize(defs.SLOT_SIZE, defs.SLOT_SIZE)
    ApplySlotChrome(button)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:EnableMouse(true)
    button:Show()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3)
    icon:SetTexture(defs.EMPTY_SLOT_TEXTURE)
    button.Icon = icon

    local itemLevel = button:CreateFontString(nil, "OVERLAY")
    itemLevel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", defs.ITEM_LEVEL_FONT_SIZE or 14, "OUTLINE")
    itemLevel:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 2)
    itemLevel:SetJustifyH("RIGHT")
    button.ItemLevel = itemLevel

    local socketPips = {}
    for index = 1, MAX_SOCKET_PIPS do
        local pip = button:CreateTexture(nil, "OVERLAY")
        pip:SetSize(10, 10)
        pip:SetTexture(SOCKET_ICON)
        pip:Hide()
        socketPips[index] = pip
    end
    button.SocketPips = socketPips

    local pickupGlow = button:CreateTexture(nil, "OVERLAY", nil, 0)
    pickupGlow:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    pickupGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    pickupGlow:SetColorTexture(1, 1, 0.4, 0.45)
    pickupGlow:Hide()
    button.pickupGlow = pickupGlow

    local detail = CreateFrame("Frame", nil, row, "BackdropTemplate")
    LPL.Theme:ApplyBackdrop(detail, "panel", "bgElevated", "border")
    detail:Show()

    detail.NameLabel = LPL:CreateLabel(detail, "small")
    detail.NameLabel:Hide()

    detail.UpgradeLabel = LPL:CreateLabel(detail, "small")
    detail.UpgradeLabel:SetJustifyH("LEFT")
    if detail.UpgradeLabel.SetMaxLines then
        detail.UpgradeLabel:SetMaxLines(1)
    end
    SetLabelColor(detail.UpgradeLabel, 0.78, 0.55, 1.00)

    detail.EnchantLabel = LPL:CreateLabel(detail, "small")
    detail.EnchantLabel:SetJustifyH("LEFT")
    if detail.EnchantLabel.SetMaxLines then
        detail.EnchantLabel:SetMaxLines(1)
    end
    SetLabelColor(detail.EnchantLabel, LPL.Theme:GetColor("greenGlow"))

    detail.EnchantHit = CreateFrame("Frame", nil, detail)
    detail.EnchantHit:EnableMouse(true)
    detail.EnchantHit:Hide()

    detail.GemRow = CreateFrame("Frame", nil, detail)
    detail.GemRow:SetSize(GEM_ICON_SIZE * MAX_SOCKET_PIPS, GEM_ICON_SIZE)

    detail.UpgradeTrack = CreateUpgradeTrack(detail)

    detail.GemIcons = {}
    for index = 1, MAX_SOCKET_PIPS do
        local gemIcon = detail.GemRow:CreateTexture(nil, "ARTWORK")
        gemIcon:SetSize(GEM_ICON_SIZE, GEM_ICON_SIZE)
        gemIcon:SetPoint("RIGHT", detail.GemRow, "RIGHT", -((index - 1) * (GEM_ICON_SIZE + 1)), 0)
        gemIcon:Hide()
        detail.GemIcons[index] = gemIcon
    end

    LayoutDetailLabels(detail)
    ApplyRowLayout(row, button, detail, nameLabel, layout)

    button.Row = row
    button.NameLabel = nameLabel
    button.slotID = slotID
    button.isIgnored = false
    button.Detail = detail
    button.detailEntry = nil
    button.layout = layout

    local function GetDraftSet()
        if options.getDraftSet then
            return options.getDraftSet()
        end
    end

    local function OnChanged()
        if options.onChanged then
            options.onChanged()
        end
    end

    local function TryPlaceCursor()
        local draftSet = GetDraftSet()
        if not draftSet then
            return
        end
        local ok, err = codec:TryAssignCursorToSlot(draftSet, button.slotID)
        if ok then
            OnChanged()
        elseif err then
            print("|cffff6060LPL:|r " .. err)
        end
    end

    local function HandleClick(self, mouseButton)
        if not NotifyCombatError() then
            return
        end
        local draftSet = GetDraftSet()
        if not draftSet then
            return
        end
        if IsRightMouseButton(mouseButton) then
            if cursor and cursor:HasPickup() then
                cursor:Clear()
            end
            codec:ClearSlot(draftSet, self.slotID)
            OnChanged()
            return
        end
        if IsModifiedClick and IsModifiedClick("SHIFT") then
            codec:ToggleSlotIgnore(draftSet, self.slotID)
            OnChanged()
            return
        end
        if cursor and cursor:HasPickup() then
            TryPlaceCursor()
            return
        end
        if GetCursorInfo and GetCursorInfo() == "item" then
            TryPlaceCursor()
            return
        end
        if cursor and cursor:PickupFromDraft(draftSet, self.slotID) then
            OnChanged()
        end
    end

    button:SetScript("OnClick", HandleClick)
    detail:SetScript("OnMouseUp", HandleClick)
    detail:EnableMouse(true)
    row:EnableMouse(false)

    button:SetScript("OnReceiveDrag", function()
        if not NotifyCombatError() or not GetDraftSet() then
            return
        end
        if GetCursorInfo and GetCursorInfo() == "item" then
            TryPlaceCursor()
            return
        end
        if cursor and cursor:HasPickup() then
            TryPlaceCursor()
        end
    end)
    detail:SetScript("OnReceiveDrag", button:GetScript("OnReceiveDrag"))

    local function ShowSlotTooltip(owner)
        LPL:ShowGameTooltip(owner, codec:BuildTooltipSpec(GetDraftSet(), slotID))
    end

    local function ShowEnchantTooltip(owner)
        local entry = button.detailEntry
        local enchantName = entry and (entry.enchantName or entry.enchantText)
        if not enchantName then
            ShowSlotTooltip(owner)
            return
        end
        local lines = { { text = enchantName, color = "enchant" } }
        if entry.enchantDetails then
            for _, detailLine in ipairs(entry.enchantDetails) do
                lines[#lines + 1] = { text = detailLine, color = "green" }
            end
        end
        LPL:ShowGameTooltip(owner, { lines = lines })
    end

    local function ShowUpgradeTooltip(owner)
        local entry = button.detailEntry
        local upgradeText = entry and entry.upgradeText
        if not upgradeText and entry and entry.upgrade then
            local upgrade = entry.upgrade
            if upgrade.trackString and upgrade.currentLevel and upgrade.maxLevel then
                upgradeText = string.format("%s %d/%d", upgrade.trackString, upgrade.currentLevel, upgrade.maxLevel)
            elseif upgrade.trackString then
                upgradeText = upgrade.trackString
            end
        end
        if not upgradeText then
            ShowSlotTooltip(owner)
            return
        end
        LPL:ShowGameTooltip(owner, {
            lines = {
                { text = upgradeText, color = "gold" },
            },
        })
    end

    button:SetScript("OnEnter", ShowSlotTooltip)
    detail:SetScript("OnEnter", ShowSlotTooltip)
    detail.EnchantHit:SetScript("OnEnter", ShowEnchantTooltip)
    detail.EnchantHit:SetScript("OnLeave", function()
        LPL:ClearGameTooltipData(GameTooltip)
    end)
    detail.UpgradeTrack:EnableMouse(true)
    detail.UpgradeTrack:SetScript("OnEnter", ShowUpgradeTooltip)
    detail.UpgradeTrack:SetScript("OnLeave", function()
        LPL:ClearGameTooltipData(GameTooltip)
    end)
    button:SetScript("OnLeave", function()
        LPL:ClearGameTooltipData(GameTooltip)
    end)
    detail:SetScript("OnLeave", function()
        LPL:ClearGameTooltipData(GameTooltip)
    end)

    function button:UpdateDetailPanel(entry, ignored)
        local detailFrame = self.Detail
        self.detailEntry = entry

        if ignored or not entry or entry.cleared or not codec:GetSlotItemID(entry) then
            local slotLabel = defs:GetSlotLabel(slotID)
            self.NameLabel:SetText(slotLabel)
            SetLabelColor(self.NameLabel, LPL.Theme:GetColor("textMuted"))
            self.NameLabel:Show()
            detailFrame.UpgradeLabel:Hide()
            detailFrame.EnchantLabel:Hide()
            detailFrame.EnchantHit:Hide()
            detailFrame.UpgradeTrack:Hide()
            HideGemIcons(detailFrame.GemIcons)
            self.ItemLevel:Hide()
            HideSocketPips(self.SocketPips)
            detailFrame.GemRow:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", -3, GetGemRowBottomInset(false))
            return
        end

        if itemInfo then
            itemInfo:EnsureEntryEnriched(entry)
        end

        local name = entry.name
        if not name and entry.itemID and C_Item and C_Item.GetItemNameByID then
            name = C_Item.GetItemNameByID(entry.itemID)
        end
        if LPL.PlainString then
            name = LPL:PlainString(name) or name
        end

        if name then
            self.NameLabel:SetText(name)
            if itemInfo then
                SetLabelColor(self.NameLabel, itemInfo:GetItemQualityColor(entry.link))
            else
                SetLabelColor(self.NameLabel, LPL.Theme:GetColor("textBright"))
            end
            self.NameLabel:Show()
        else
            self.NameLabel:Hide()
        end

        if entry.upgradeText then
            detailFrame.UpgradeLabel:SetText(entry.upgradeText)
            detailFrame.UpgradeLabel:Show()
        else
            detailFrame.UpgradeLabel:Hide()
        end

        local hasUpgradeTrack = UpdateUpgradeTrack(detailFrame.UpgradeTrack, entry.upgrade)
        detailFrame.GemRow:ClearAllPoints()
        detailFrame.GemRow:SetPoint("BOTTOMRIGHT", detailFrame, "BOTTOMRIGHT", -3, GetGemRowBottomInset(hasUpgradeTrack))

        detailFrame.EnchantLabel:ClearAllPoints()
        local enchantName = entry.enchantName or entry.enchantText
        if enchantName then
            detailFrame.EnchantLabel:SetText(enchantName)
            SetLabelColor(detailFrame.EnchantLabel, LPL.Theme:GetColor("greenGlow"))
            detailFrame.EnchantLabel:Show()
            if entry.upgradeText then
                detailFrame.EnchantLabel:SetPoint("TOPLEFT", detailFrame.UpgradeLabel, "BOTTOMLEFT", 0, -1)
            else
                detailFrame.EnchantLabel:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 4, -3)
            end
            detailFrame.EnchantLabel:SetPoint("RIGHT", detailFrame.GemRow, "LEFT", -2, 0)
            detailFrame.EnchantHit:ClearAllPoints()
            detailFrame.EnchantHit:SetPoint("TOPLEFT", detailFrame.EnchantLabel, "TOPLEFT", -2, 2)
            detailFrame.EnchantHit:SetPoint("BOTTOMRIGHT", detailFrame.EnchantLabel, "BOTTOMRIGHT", 2, -2)
            detailFrame.EnchantHit:Show()
        elseif slotID ~= 4 and slotID ~= 19 and slotID ~= 11 and slotID ~= 12 and slotID ~= 13 and slotID ~= 14 then
            detailFrame.EnchantLabel:SetText("Not enchanted")
            SetLabelColor(detailFrame.EnchantLabel, 1, 0.2, 0.2)
            detailFrame.EnchantLabel:Show()
            if entry.upgradeText then
                detailFrame.EnchantLabel:SetPoint("TOPLEFT", detailFrame.UpgradeLabel, "BOTTOMLEFT", 0, -1)
            else
                detailFrame.EnchantLabel:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 4, -3)
            end
            detailFrame.EnchantLabel:SetPoint("RIGHT", detailFrame, "RIGHT", -4, 0)
            detailFrame.EnchantHit:Hide()
        else
            detailFrame.EnchantLabel:Hide()
            detailFrame.EnchantHit:Hide()
        end

        HideGemIcons(detailFrame.GemIcons)
        if entry.gems then
            for index, gem in ipairs(entry.gems) do
                local gemIcon = detailFrame.GemIcons[index]
                if gemIcon then
                    gemIcon:SetTexture(gem.icon or "Interface\\Icons\\INV_Jewelcrafting_Gem_01")
                    gemIcon:Show()
                end
            end
        end

        if entry.itemLevel then
            SetItemLevelDisplay(self, entry)
        else
            self.ItemLevel:Hide()
        end

        HideSocketPips(self.SocketPips)
        if entry.gems then
            for index = 1, math.min(#entry.gems, MAX_SOCKET_PIPS) do
                local pip = self.SocketPips[index]
                pip:ClearAllPoints()
                pip:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 2 + ((index - 1) * 9), 2)
                pip:Show()
            end
        end
    end

    function button:UpdateFromDraft(draftSet)
        draftSet = draftSet or GetDraftSet()
        local ignored = codec:IsSlotIgnored(draftSet, self.slotID)
        self.isIgnored = ignored

        local entry = draftSet and draftSet.slots and draftSet.slots[self.slotID]
        local itemID = entry and codec:GetSlotItemID(entry)
        local texture = defs.EMPTY_SLOT_TEXTURE

        if entry and entry.icon then
            texture = entry.icon
        elseif itemID then
            if C_Item and C_Item.GetItemIconByID then
                texture = C_Item.GetItemIconByID(itemID) or texture
            elseif GetItemIcon then
                texture = GetItemIcon(itemID) or texture
            end
        end

        self.Icon:SetTexture(texture)
        if LPL.ActionBarSlotVisuals then
            LPL.ActionBarSlotVisuals:ApplyIgnoredState(self, ignored)
        end
        if self.pickupGlow and cursor then
            self.pickupGlow:SetShown(cursor:IsPendingFrom(self.slotID))
        end
        self:UpdateDetailPanel(entry, ignored)
    end

    button:UpdateFromDraft(nil)
    return button
end
