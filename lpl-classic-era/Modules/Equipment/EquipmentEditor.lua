local addonName, LPL = ...

LPL.EquipmentEditor = {}

local defs = LPL.EquipmentDefinitions

local function BuildSlotOptions(editorFrame)
    return {
        getDraftSet = function()
            return editorFrame.draftSet
        end,
        onChanged = function()
            editorFrame:Refresh()
        end,
    }
end

local function AnchorColumnSlots(model, side, slotIDs, editorFrame)
    local layout = side == "left" and "left" or "right"
    local options = BuildSlotOptions(editorFrame)

    for index, slotID in ipairs(slotIDs) do
        local offsetY = defs:GetColumnOffsetY(#slotIDs, index)
        local button = LPL.EquipmentSlotButton:Create(editorFrame.doll, slotID, {
            layout = layout,
            getDraftSet = options.getDraftSet,
            onChanged = options.onChanged,
        })
        if side == "left" then
            button.Row:SetPoint("RIGHT", model, "LEFT", -defs.COLUMN_GAP, offsetY)
        else
            button.Row:SetPoint("LEFT", model, "RIGHT", defs.COLUMN_GAP, offsetY)
        end
        editorFrame.slotButtons[slotID] = button
    end
end

local function AnchorWeaponSlots(editorFrame)
    local model = editorFrame.model
    local weaponBar = editorFrame.weaponBar
    if not model or not weaponBar then
        return
    end

    local layouts = { [16] = "left", [17] = "right", [18] = "left" }
    local options = BuildSlotOptions(editorFrame)
    local weaponSlots = defs:GetVisibleWeaponSlots()
    local stride = defs.SLOT_SIZE + defs.DETAIL_WIDTH + 2 + defs.WEAPON_GAP

    weaponBar:ClearAllPoints()
    weaponBar:SetPoint("TOP", model, "CENTER", 0, defs:GetWeaponRowTopOffsetY())

    for index, slotID in ipairs(weaponSlots) do
        local layout = layouts[slotID] or "left"
        local button = LPL.EquipmentSlotButton:Create(weaponBar, slotID, {
            layout = layout,
            getDraftSet = options.getDraftSet,
            onChanged = options.onChanged,
        })
        local offsetX = (index - (#weaponSlots + 1) / 2) * stride
        button.Row:SetPoint("CENTER", weaponBar, "CENTER", offsetX, 0)
        editorFrame.slotButtons[slotID] = button
    end

    local barWidth = (#weaponSlots * stride) - defs.WEAPON_GAP
    weaponBar:SetSize(math.max(barWidth, 1), defs:GetRowHeight())
end

function LPL.EquipmentEditor:Destroy(editorFrame)
    if not editorFrame then
        return
    end
    editorFrame:Hide()
    editorFrame:SetParent(nil)
    editorFrame:ClearAllPoints()
end

function LPL.EquipmentEditor:Create(parent)
    local frame = CreateFrame("Frame", "LPLEquipmentEditor", parent)
    frame:SetAllPoints(parent)

    local hint = LPL:CreateLabel(frame, "small")
    hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
    hint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    hint:SetText("Drag from bags or between slots | Update loads gear | Shift+click ignore | Right-click clear")

    local doll = CreateFrame("Frame", nil, frame)
    doll:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -26)
    doll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    local model = CreateFrame("PlayerModel", nil, doll)
    model:SetSize(defs.MODEL_WIDTH, defs.MODEL_HEIGHT)
    model:SetPoint("CENTER", doll, "CENTER", 0, defs.MODEL_VERTICAL_OFFSET or 28)
    if model.SetUnit then
        model:SetUnit("player")
    end
    if model.SetFacing then
        model:SetFacing(0.4)
    end
    if model.SetCamDistanceScale then
        model:SetCamDistanceScale(1.05)
    end
    if model.SetPosition then
        model:SetPosition(0, 0, 0)
    end
    if model.SetDoBlend then
        model:SetDoBlend(false)
    end

    local weaponBar = CreateFrame("Frame", nil, doll)

    frame.hint = hint
    frame.doll = doll
    frame.model = model
    frame.weaponBar = weaponBar
    frame.slotButtons = {}
    frame.draftSet = nil

    AnchorColumnSlots(model, "left", defs.LEFT_SLOTS, frame)
    AnchorColumnSlots(model, "right", defs.RIGHT_SLOTS, frame)
    AnchorWeaponSlots(frame)

    function frame:SetDraftSet(draftSet)
        self.draftSet = draftSet
        self:Refresh()
    end

    function frame:Refresh()
        for _, button in pairs(self.slotButtons) do
            local ok, err = pcall(function()
                button:UpdateFromDraft(self.draftSet)
            end)
            if not ok then
                -- Keep the editor usable; surface a short player-facing message.
                print("|cffff6060LPL:|r Could not refresh an equipment slot.")
            end
        end
        if self.model and self.model.SetUnit then
            self.model:SetUnit("player")
        end
    end

    frame:Show()
    return frame
end
