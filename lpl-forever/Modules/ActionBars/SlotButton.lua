local addonName, LPL = ...

LPL.ActionBarSlotButton = {}

local defs = LPL.ActionBarDefinitions
local codec = LPL.ActionBarCodec
local cursor = LPL.ActionBarCursor

local function ApplySlotChrome(frame)
    LPL.Theme:ApplyBackdrop(frame, "button", "actionBarSlotBg", "actionBarSlotBorder")
end

local function ApplyLockIconTexture(texture, dimmed)
    if not texture then
        return
    end
    if LPL:SetIconTexture(texture, "lock_64") then
        if dimmed then
            texture:SetVertexColor(0.75, 0.75, 0.75, 1)
        else
            texture:SetVertexColor(1, 1, 1, 1)
        end
    else
        texture:SetTexture(LPL.Icons.LOCK or "Interface\\Buttons\\WHITE8X8")
        if dimmed then
            texture:SetVertexColor(0.65, 0.08, 0.08, 1)
        else
            texture:SetVertexColor(0.9, 0.14, 0.14, 1)
        end
    end
end

local function IsRightMouseButton(button)
    return button == "RightButton" or button == 2
end

local function NotifyCombatError()
    local ok, err = cursor:CanEdit()
    if not ok then
        print("|cffff6060LPL:|r " .. (err or "Cannot edit action bars in combat."))
    end
    return ok
end

local function TruncateMacroName(name, maxLen)
    name = tostring(name or "")
    if name == "" then
        return "Macro"
    end
    if #name <= maxLen then
        return name
    end
    return name:sub(1, maxLen - 1) .. "..."
end

function LPL.ActionBarSlotButton:Create(parent, slotID, isPet, options)
    options = options or {}

    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(defs.SLOT_SIZE, defs.SLOT_SIZE)
    ApplySlotChrome(button)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:EnableMouse(true)

    local icon = button:CreateTexture(nil, "ARTWORK")
    -- Equal insets keep the icon square; macro name overlays the bottom.
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    button.Icon = icon

    local macroName = button:CreateFontString(nil, "OVERLAY", nil, 2)
    macroName:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
    macroName:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
    macroName:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
    macroName:SetJustifyH("CENTER")
    macroName:SetHeight(8)
    macroName:SetTextColor(1, 1, 1, 1)
    macroName:Hide()
    button.macroName = macroName

    local pickupGlow = button:CreateTexture(nil, "OVERLAY", nil, 0)
    pickupGlow:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
    pickupGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
    pickupGlow:SetColorTexture(1, 1, 0.4, 0.45)
    pickupGlow:Hide()
    button.pickupGlow = pickupGlow

    local errorBorder = button:CreateTexture(nil, "OVERLAY", nil, 1)
    errorBorder:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    errorBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
    errorBorder:SetColorTexture(1, 0, 0, 0.35)
    errorBorder:Hide()
    button.errorBorder = errorBorder

    button.slotID = slotID
    button.isPet = isPet
    button.action = nil
    button.isIgnored = false
    button.errorText = nil

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

    local function PlaceOnSlot()
        local draftSet = GetDraftSet()
        if not draftSet then
            return
        end
        if cursor:PlaceOnSlot(draftSet, button.slotID, button.isPet) then
            OnChanged()
        end
    end

    button:SetScript("OnDragStart", function(self)
        if not NotifyCombatError() then
            return
        end
        local draftSet = GetDraftSet()
        if not draftSet then
            return
        end
        if cursor:HasPickup() then
            return
        end
        if GetCursorInfo and GetCursorInfo() then
            return
        end
        local action = codec:GetStoredAction(draftSet, self.slotID, self.isPet)
        if not action or not action.type then
            return
        end
        if cursor:PickupFromDraft(draftSet, self.slotID, self.isPet) then
            OnChanged()
        end
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        if not NotifyCombatError() then
            return
        end

        local draftSet = GetDraftSet()
        if not draftSet then
            return
        end

        if IsRightMouseButton(mouseButton) then
            cursor:Clear()
            codec:ClearSlotAction(draftSet, self.slotID, self.isPet)
            OnChanged()
            return
        end

        if IsModifiedClick and IsModifiedClick("SHIFT") then
            cursor:Clear()
            codec:ToggleSlotIgnore(draftSet, self.slotID, self.isPet)
            OnChanged()
            return
        end

        local hasWoWCursor = GetCursorInfo and GetCursorInfo()
        if hasWoWCursor or cursor:HasPickup() then
            PlaceOnSlot()
            return
        end

        if cursor:PickupFromDraft(draftSet, self.slotID, self.isPet) then
            OnChanged()
        end
    end)

    button:SetScript("OnReceiveDrag", function()
        if not NotifyCombatError() then
            return
        end
        if not GetDraftSet() then
            return
        end
        if GetCursorInfo and not GetCursorInfo() and not cursor:HasPickup() then
            return
        end
        PlaceOnSlot()
    end)

    button:SetScript("OnEnter", function(self)
        LPL:ShowGameTooltip(self, codec:BuildActionTooltipSpec(self.action, self.slotID, self.isPet, {
            ignored = self.isIgnored,
            hasPickup = cursor:HasPickup(),
            errorText = self.errorText,
        }))
    end)
    button:SetScript("OnLeave", function()
        LPL:ClearGameTooltipData(GameTooltip)
    end)

    function button:UpdateFromDraft(draftSet)
        local action = codec:GetStoredAction(draftSet, self.slotID, self.isPet)
        local ignored = codec:IsSlotIgnored(draftSet, self.slotID, self.isPet)
        self.action = action
        self.isIgnored = ignored

        if action and action.type then
            local iconTexture, displayName, errorText = codec:ResolveActionDisplay(action, ignored)
            self.Icon:SetTexture(iconTexture)
            self.Icon:Show()
            self.errorText = errorText
            self.errorBorder:SetShown(errorText ~= nil and not ignored)

            if action.type == "macro" then
                local macroLabel = displayName or action.name or "Macro"
                self.macroName:SetText(TruncateMacroName(macroLabel, 10))
                self.macroName:Show()
            else
                self.macroName:Hide()
            end
        else
            self.Icon:SetTexture(nil)
            self.errorText = nil
            self.errorBorder:Hide()
            self.macroName:Hide()
        end

        LPL.ActionBarSlotVisuals:ApplyIgnoredState(self, ignored)
        self.pickupGlow:SetShown(cursor:IsPendingFrom(self.slotID, self.isPet))
    end

    return button
end

function LPL.ActionBarSlotButton:CreateRowLock(parent, rowDef, options)
    options = options or {}

    local lock = CreateFrame("Button", nil, parent, "BackdropTemplate")
    lock:SetSize(defs.LOCK_SIZE, defs.LOCK_SIZE)
    ApplySlotChrome(lock)
    lock:EnableMouse(true)

    local icon = lock:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", lock, "TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", lock, "BOTTOMRIGHT", -3, 3)
    lock.icon = icon
    ApplyLockIconTexture(icon, true)

    lock.rowDef = rowDef

    lock:SetScript("OnClick", function()
        if not NotifyCombatError() then
            return
        end
        local draftSet = options.getDraftSet and options.getDraftSet()
        if not draftSet or not rowDef then
            return
        end
        cursor:Clear()
        local endSlot = rowDef.lastSlot or defs:GetRowEndSlot(rowDef)
        codec:ToggleRowIgnore(draftSet, rowDef.firstSlot, endSlot, rowDef.isPet)
        if options.onChanged then
            options.onChanged()
        end
    end)

    lock:SetScript("OnEnter", function(self)
        local tooltipTitle = self.rowDef and self.rowDef.isPet and "Ignores full pet bar" or "Ignores full bar"
        LPL:ShowGameTooltipLines(self, {
            { text = tooltipTitle, color = "title" },
            { text = "Click to ignore or unignore every slot in this row.", color = "gray" },
            { text = "Shift+left-click a slot to ignore it individually.", color = "gray" },
            { text = "Right-click a slot to clear it.", color = "gray" },
        })
    end)
    lock:SetScript("OnLeave", function()
        LPL:ClearGameTooltipData(GameTooltip)
    end)

    function lock:UpdateFromDraft(draftSet)
        local rowDef = self.rowDef
        if not rowDef or not draftSet then
            ApplyLockIconTexture(self.icon, true)
            return
        end
        local endSlot = rowDef.lastSlot or defs:GetRowEndSlot(rowDef)
        local fullyIgnored = codec:IsRangeFullyIgnored(
            draftSet,
            rowDef.firstSlot,
            endSlot,
            rowDef.isPet
        )
        ApplyLockIconTexture(self.icon, not fullyIgnored)
    end

    return lock
end
