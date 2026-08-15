local addonName, LPL = ...

LPL.PvpTalentEditor = {}

local SLOT_SIZE = 56
local ROW_HEIGHT = 40
local LIST_PAD = 8

local function CountFilled(draft)
    local count = 0
    local talents = draft and draft.talents or {}
    for slot = 1, LPL.PvpTalentStore.SLOT_COUNT do
        if tonumber(talents[slot]) then
            count = count + 1
        end
    end
    return count
end

local function CreateSlotButton(parent, slotIndex, editor)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(SLOT_SIZE + 100, SLOT_SIZE + 8)
    button.slotIndex = slotIndex

    local iconBg = button:CreateTexture(nil, "BACKGROUND")
    iconBg:SetSize(SLOT_SIZE, SLOT_SIZE)
    iconBg:SetPoint("LEFT", button, "LEFT", 0, 0)
    iconBg:SetColorTexture(LPL.Theme:GetColor("bgElevated"))
    button.iconBg = iconBg

    local border = button:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", iconBg, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", iconBg, "BOTTOMRIGHT", 1, -1)
    border:SetColorTexture(LPL.Theme:GetColor("border"))
    button.border = border

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconBg, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", iconBg, "BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon = icon

    local empty = button:CreateTexture(nil, "ARTWORK")
    empty:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
    empty:SetSize(24, 24)
    empty:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    empty:SetDesaturated(true)
    empty:SetAlpha(0.45)
    button.emptyIcon = empty

    local selected = button:CreateTexture(nil, "OVERLAY")
    selected:SetPoint("TOPLEFT", border, "TOPLEFT", -2, 2)
    selected:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", 2, -2)
    selected:SetColorTexture(LPL.Theme:GetColor("accent"))
    selected:SetAlpha(0.35)
    selected:Hide()
    button.selectedHighlight = selected

    local slotLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slotLabel:SetPoint("BOTTOMLEFT", iconBg, "TOPLEFT", 0, 4)
    slotLabel:SetText(string.format("Slot %d", slotIndex))
    slotLabel:SetTextColor(LPL.Theme:GetColor("textMuted"))
    button.slotLabel = slotLabel

    local name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", iconBg, "RIGHT", 10, 0)
    name:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(true)
    name:SetTextColor(LPL.Theme:GetColor("textBright"))
    button.nameLabel = name

    button:SetScript("OnEnter", function(self)
        local talentID = editor.draftSet and editor.draftSet.talents and editor.draftSet.talents[self.slotIndex]
        if talentID then
            LPL.PvpTalentCodec:ShowTalentTooltip(self, talentID)
        else
            LPL:ShowAccessibleGameTooltip(self, string.format("PvP Talent Slot %d", self.slotIndex), "Click to choose a talent. Right-click to clear.")
        end
        self.border:SetColorTexture(LPL.Theme:GetColor("accent"))
    end)
    button:SetScript("OnLeave", function(self)
        LPL.PvpTalentCodec:HideTalentTooltip(self)
        if editor.selectedSlot ~= self.slotIndex then
            self.border:SetColorTexture(LPL.Theme:GetColor("border"))
        end
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if editor.draftSet then
                LPL.PvpTalentCodec:AssignTalent(editor.draftSet, self.slotIndex, nil)
                editor:Refresh()
            end
            return
        end
        editor:SelectSlot(self.slotIndex)
    end)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    function button:Update(draft, isSelected)
        local talentID = draft and draft.talents and tonumber(draft.talents[self.slotIndex])
        self.selectedHighlight:SetShown(isSelected)
        if isSelected then
            self.border:SetColorTexture(LPL.Theme:GetColor("accent"))
        else
            self.border:SetColorTexture(LPL.Theme:GetColor("border"))
        end

        if talentID then
            local info = LPL.PvpTalentCodec:GetTalentInfo(talentID)
            if info and info.icon then
                self.icon:SetTexture(info.icon)
            else
                self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            end
            self.icon:Show()
            self.emptyIcon:Hide()
            self.nameLabel:SetText(info and info.name or ("Talent " .. talentID))
            self.nameLabel:SetTextColor(LPL.Theme:GetColor("textBright"))
        else
            self.icon:Hide()
            self.emptyIcon:Show()
            self.nameLabel:SetText("Empty")
            self.nameLabel:SetTextColor(LPL.Theme:GetColor("textMuted"))
        end
    end

    return button
end

local function CreateListRow(parent, editor)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_HEIGHT)
    row:EnableMouse(true)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", row, "LEFT", 8, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local check = row:CreateTexture(nil, "OVERLAY")
    check:SetSize(16, 16)
    check:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:Hide()
    row.check = check

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    name:SetPoint("RIGHT", check, "LEFT", -8, 0)
    name:SetJustifyH("LEFT")
    name:SetTextColor(LPL.Theme:GetColor("textBright"))
    row.nameLabel = name

    local used = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    used:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    used:SetTextColor(LPL.Theme:GetColor("textMuted"))
    used:Hide()
    row.usedLabel = used

    row:SetScript("OnEnter", function(self)
        if self.talentID then
            LPL.PvpTalentCodec:ShowTalentTooltip(self, self.talentID)
        end
    end)
    row:SetScript("OnLeave", function(self)
        LPL.PvpTalentCodec:HideTalentTooltip(self)
    end)
    row:SetScript("OnClick", function(self)
        if not self.talentID or not editor.draftSet then
            return
        end
        local slot = editor.selectedSlot or 1
        if tonumber(editor.draftSet.talents and editor.draftSet.talents[slot]) == self.talentID then
            LPL.PvpTalentCodec:AssignTalent(editor.draftSet, slot, nil)
        else
            LPL.PvpTalentCodec:AssignTalent(editor.draftSet, slot, self.talentID)
        end
        editor:Refresh()
    end)

    function row:SetTalent(talentID, draft, selectedSlot)
        self.talentID = talentID
        local info = LPL.PvpTalentCodec:GetTalentInfo(talentID)
        if info and info.icon then
            self.icon:SetTexture(info.icon)
        else
            self.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        self.nameLabel:SetText(info and info.name or ("Talent " .. tostring(talentID)))

        local usedSlot
        if draft and draft.talents then
            for slot = 1, LPL.PvpTalentStore.SLOT_COUNT do
                if tonumber(draft.talents[slot]) == talentID then
                    usedSlot = slot
                    break
                end
            end
        end

        self.check:SetShown(usedSlot ~= nil)
        if usedSlot and usedSlot ~= selectedSlot then
            self.usedLabel:SetText(string.format("In slot %d", usedSlot))
            self.usedLabel:Show()
            self.nameLabel:ClearAllPoints()
            self.nameLabel:SetPoint("LEFT", self.icon, "RIGHT", 10, 6)
            self.nameLabel:SetPoint("RIGHT", self.check, "LEFT", -8, 6)
        else
            self.usedLabel:Hide()
            self.nameLabel:ClearAllPoints()
            self.nameLabel:SetPoint("LEFT", self.icon, "RIGHT", 10, 0)
            self.nameLabel:SetPoint("RIGHT", self.check, "LEFT", -8, 0)
        end

        if usedSlot == selectedSlot then
            self.nameLabel:SetTextColor(LPL.Theme:GetColor("accent"))
        else
            self.nameLabel:SetTextColor(LPL.Theme:GetColor("textBright"))
        end
    end

    return row
end

function LPL.PvpTalentEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.draftSet = nil
    frame.selectedSlot = 1
    frame.rows = {}

    local toolbar = LPL:CreatePanel(nil, frame)
    toolbar:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -8)
    toolbar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -8)
    toolbar:SetHeight(72)

    local classDrop = LPL:CreateDropdown("LPLPvpClassDrop", toolbar, 170)
    classDrop:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 14, -10)
    classDrop:SetLabel("Class")

    local specDrop = LPL:CreateDropdown("LPLPvpSpecDrop", toolbar, 190)
    specDrop:SetPoint("TOPLEFT", classDrop, "TOPRIGHT", 12, 0)
    specDrop:SetLabel("Specialization")

    local status = toolbar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPRIGHT", toolbar, "TOPRIGHT", -14, -18)
    status:SetJustifyH("RIGHT")
    status:SetTextColor(LPL.Theme:GetColor("textBright"))
    frame.statusLabel = status

    local hint = toolbar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPRIGHT", status, "BOTTOMRIGHT", 0, -4)
    hint:SetJustifyH("RIGHT")
    hint:SetText("Click a slot · Pick from the list · Right-click slot to clear")
    hint:SetTextColor(LPL.Theme:GetColor("textMuted"))

    local slotsPanel = CreateFrame("Frame", nil, frame)
    slotsPanel:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 4, -16)
    slotsPanel:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", -4, -16)
    slotsPanel:SetHeight(SLOT_SIZE + 28)

    frame.slotButtons = {}
    for slot = 1, LPL.PvpTalentStore.SLOT_COUNT do
        local button = CreateSlotButton(slotsPanel, slot, frame)
        if slot == 1 then
            button:SetPoint("LEFT", slotsPanel, "LEFT", 8, -4)
        else
            button:SetPoint("LEFT", frame.slotButtons[slot - 1], "RIGHT", 24, 0)
        end
        frame.slotButtons[slot] = button
    end

    local listHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", slotsPanel, "BOTTOMLEFT", 8, -14)
    listHeader:SetText("Available PvP Talents")
    listHeader:SetTextColor(LPL.Theme:GetColor("textBright"))
    frame.listHeader = listHeader

    local listHint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    listHint:SetPoint("LEFT", listHeader, "RIGHT", 12, 0)
    listHint:SetTextColor(LPL.Theme:GetColor("textMuted"))
    frame.listHint = listHint

    local listPanel = LPL:CreatePanel(nil, frame)
    listPanel:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", -4, -8)
    listPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)

    local scroll = CreateFrame("ScrollFrame", "LPLPvpTalentScroll", listPanel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", LIST_PAD, -LIST_PAD)
    scroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -28, LIST_PAD)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(100, 100)
    scroll:SetScrollChild(scrollChild)

    frame.toolbar = toolbar
    frame.classDrop = classDrop
    frame.specDrop = specDrop
    frame.listPanel = listPanel
    frame.scroll = scroll
    frame.scrollChild = scrollChild

    local function OnViewChanged()
        if not frame.draftSet then
            return
        end
        frame.draftSet.classID = frame.viewClassID
        frame.draftSet.specID = frame.viewSpecID
        LPL.PvpTalentCodec:SanitizeDraft(frame.draftSet)
        frame:Refresh()
    end

    function frame:RefreshDropdowns()
        local classes = LPL.TalentTree:GetClasses()
        self.classDrop:SetItems(classes, self.viewClassID, function(id)
            self.viewClassID = id
            local specs = LPL.TalentTree:GetSpecsForClass(id)
            self.viewSpecID = specs[1] and specs[1].id
            self:RefreshDropdowns()
            OnViewChanged()
        end)

        local specs = LPL.TalentTree:GetSpecsForClass(self.viewClassID)
        local hasSpec = false
        for _, spec in ipairs(specs) do
            if spec.id == self.viewSpecID then
                hasSpec = true
                break
            end
        end
        if not hasSpec then
            self.viewSpecID = specs[1] and specs[1].id
        end
        self.specDrop:SetItems(specs, self.viewSpecID, function(id)
            self.viewSpecID = id
            OnViewChanged()
        end)
    end

    function frame:SelectSlot(slotIndex)
        self.selectedSlot = slotIndex or 1
        self:Refresh()
    end

    function frame:RefreshList()
        local talentIDs, isLive = LPL.PvpTalentCodec:GetAvailableTalentIDs(self.viewSpecID, self.selectedSlot or 1)
        if isLive then
            self.listHint:SetText("(from your character)")
        else
            self.listHint:SetText("(catalog)")
        end

        local width = math.max(200, (self.scroll:GetWidth() or 400) - 4)
        for index, talentID in ipairs(talentIDs) do
            local row = self.rows[index]
            if not row then
                row = CreateListRow(self.scrollChild, self)
                self.rows[index] = row
            end
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self.scrollChild, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
            row:SetWidth(width)
            row:SetTalent(talentID, self.draftSet, self.selectedSlot)
            row:Show()
        end

        for index = #talentIDs + 1, #self.rows do
            self.rows[index]:Hide()
        end

        self.scrollChild:SetWidth(width)
        self.scrollChild:SetHeight(math.max(1, #talentIDs * ROW_HEIGHT))
        self.scroll:UpdateScrollChildRect()

        if #talentIDs == 0 then
            self.listHeader:SetText("Available PvP Talents — none found for this specialization")
        else
            self.listHeader:SetText(string.format("Available PvP Talents for slot %d", self.selectedSlot or 1))
        end
    end

    function frame:Refresh()
        if not self.draftSet then
            return
        end
        LPL.PvpTalentCodec:SanitizeDraft(self.draftSet)
        self.viewClassID = self.draftSet.classID or self.viewClassID
        self.viewSpecID = self.draftSet.specID or self.viewSpecID
        if not self.viewClassID or not self.viewSpecID then
            local classID, specID = LPL.PvpTalentCodec:GetPlayerClassAndSpec()
            self.viewClassID = self.viewClassID or classID
            self.viewSpecID = self.viewSpecID or specID
            self.draftSet.classID = self.viewClassID
            self.draftSet.specID = self.viewSpecID
        end

        self:RefreshDropdowns()

        for slot, button in ipairs(self.slotButtons) do
            button:Update(self.draftSet, slot == self.selectedSlot)
        end

        local filled = CountFilled(self.draftSet)
        self.statusLabel:SetText(string.format("%d / %d selected", filled, LPL.PvpTalentStore.SLOT_COUNT))
        self:RefreshList()
    end

    function frame:SetDraftSet(draft)
        self.draftSet = draft
        self.selectedSlot = 1
        if draft then
            self.viewClassID = draft.classID
            self.viewSpecID = draft.specID
        end
        self:Refresh()
    end

    -- Layout pass when shown / sized
    frame:SetScript("OnSizeChanged", function(self)
        if self.draftSet then
            self:RefreshList()
        end
    end)

    return frame
end

function LPL.PvpTalentEditor:Destroy(editor)
    if not editor then
        return
    end
    editor:Hide()
    editor:SetParent(nil)
end
