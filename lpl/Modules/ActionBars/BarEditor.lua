local addonName, LPL = ...

LPL.ActionBarEditor = {}

local defs = LPL.ActionBarDefinitions

local function LayoutScrollChild(frame)
    local scroll = frame.scroll
    local child = frame.scrollChild
    if not scroll or not child then
        return
    end

    local scrollWidth = scroll:GetWidth()
    if scrollWidth < 1 then
        scrollWidth = defs.MIN_SCROLL_WIDTH
    end

    local contentWidth = defs:GetMaxContentWidth()
    child:SetWidth(math.max(scrollWidth - 28, contentWidth))

    local y = defs.SCROLL_PADDING
    for _, row in ipairs(frame.rows) do
        row:SetPoint("TOPLEFT", child, "TOPLEFT", defs.SCROLL_PADDING, -y)
        row:SetWidth(contentWidth - (defs.SCROLL_PADDING * 2))
        y = y + defs.ROW_HEIGHT + defs.ROW_GAP
    end

    child:SetHeight(math.max(1, y + defs.SCROLL_PADDING))
    scroll:UpdateScrollChildRect()
end

function LPL.ActionBarEditor:CreateRow(parent, rowDef, editorFrame)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(defs.ROW_HEIGHT)

    local slotOptions = {
        getDraftSet = function()
            return editorFrame.draftSet
        end,
        onChanged = function()
            editorFrame:Refresh()
        end,
    }

    local label = LPL:CreateLabel(row, "small")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(defs.LABEL_WIDTH)
    label:SetJustifyH("LEFT")
    label:SetTextColor(LPL.Theme:GetColor("textLabel"))
    label:SetText(rowDef.label or "")
    row.label = label

    row.slots = {}
    local x = defs.LABEL_WIDTH
    local endSlot = defs:GetRowEndSlot(rowDef)
    for slotID = rowDef.firstSlot, endSlot do
        local slotButton = LPL.ActionBarSlotButton:Create(row, slotID, rowDef.isPet, slotOptions)
        slotButton:SetPoint("LEFT", row, "LEFT", x, 0)
        row.slots[#row.slots + 1] = slotButton
        x = x + defs.SLOT_SIZE + defs.SLOT_GAP
    end

    row.lock = LPL.ActionBarSlotButton:CreateRowLock(row, {
        label = rowDef.label,
        firstSlot = rowDef.firstSlot,
        lastSlot = endSlot,
        isPet = rowDef.isPet,
    }, slotOptions)
    row.lock:SetPoint("LEFT", row, "LEFT", x + 4, 0)
    row.rowDef = rowDef

    function row:Refresh(draftSet)
        for _, slotButton in ipairs(self.slots) do
            slotButton:UpdateFromDraft(draftSet)
        end
        self.lock:UpdateFromDraft(draftSet)
    end

    return row
end

function LPL.ActionBarEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -12)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)

    local hint = LPL:CreateLabel(frame, "small")
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    hint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    hint:SetText("Left-click to move · Shift+ignore · Right-click clear · Drag from spellbook (incl. Flight Style / Teleport to Plot), bags, or macros.")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -4, -8)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -24, 4)
    scroll:EnableMouse(true)

    local scrollChild = CreateFrame("Frame", nil, scroll)
    scrollChild:SetSize(1, 1)
    scroll:SetScrollChild(scrollChild)

    frame.scroll = scroll
    frame.scrollChild = scrollChild
    frame.rows = {}
    frame.draftSet = nil

    for _, rowDef in ipairs(defs.PANEL_ROWS) do
        frame.rows[#frame.rows + 1] = self:CreateRow(scrollChild, rowDef, frame)
    end

    scroll:HookScript("OnSizeChanged", function()
        LayoutScrollChild(frame)
    end)

    function frame:SetDraftSet(draftSet)
        self.draftSet = draftSet
        self:Refresh()
    end

    function frame:Refresh()
        if not self.draftSet then
            return
        end
        for _, row in ipairs(self.rows) do
            row:Refresh(self.draftSet)
        end
        LayoutScrollChild(self)
    end

    C_Timer.After(0, function()
        if frame:IsShown() then
            LayoutScrollChild(frame)
        end
    end)

    return frame
end
