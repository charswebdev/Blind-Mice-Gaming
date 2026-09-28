local _, LPL = ...

LPL.Sections = LPL.Sections or {}
local UI = LPL.Sections

local LIST_BAR_H = 44
local EDITOR_BAR_H = 78
local BG = { 0.00, 0.00, 0.00, 1 }
local TITLE_BG = { 0.08, 0.08, 0.10, 1 }
local BORDER = { 0.25, 0.27, 0.32, 1 }
local TEXT = { 0.95, 0.95, 0.97, 1 }
local GOLD = { 1.00, 0.92, 0.40, 1 }
local SELECTED = { 0.28, 0.05, 0.09, 1 }
local BUTTON_BG = { 0.18, 0.18, 0.22, 1 }
local BUTTON_HOVER = { 0.24, 0.24, 0.30, 1 }
local BUTTON_PRESSED = { 0.14, 0.14, 0.18, 1 }
local BUTTON_BORDER = { 0.96, 0.55, 0.73, 1 }

local SECTIONS = {
    actionbars = {
        title = "Saved Action Bar Sets",
        hint = "Green dot = on your bars. Double-click a set to edit.",
        detail = "Drag a spell, item, or macro onto a slot, or drag a slot onto your action bar to place it. Drag a slot onto another slot to move it. Right-click clears. Shift+left-click ignores one slot.",
        newLabel = "New Bars",
        emptyLabel = "New Action Bar Set",
        noun = "action bar set",
        api = function()
            return LPL.ActionBarAPI
        end,
    },
    keybinds = {
        title = "Saved Keybinding Profiles",
        hint = "Green dot = the keys on this character. Double-click a profile to view it.",
        detail = "Categories start collapsed. Click a header to expand it. Click a gold-bordered key box, then press a key. Right-click or Esc clears that box.",
        newLabel = "New Profile",
        emptyLabel = "New Profile",
        noun = "keybinding profile",
        api = function()
            return LPL.KeybindAPI
        end,
    },
    equipment = {
        title = "Saved Equipment",
        hint = "Green dot = the gear on this character. Double-click a set to view it.",
        detail = "Slots sit beside your character, the same way as the other Light Paws packages. Drag an item onto a slot. Shift+left-click ignores that slot. Right-click clears it. Shirt and tabard stay as they are. Apply equips the rest from your bags.",
        newLabel = "New Gear",
        emptyLabel = "New Equipment Set",
        noun = "equipment set",
        api = function()
            return LPL.EquipmentAPI
        end,
    },
}

local sectionId
local mode = "list"
local selectedId
local draft
local listButtons = {}
local iconRows = {}
local lineButtons = {}
local actionRows = {}
local gearDoll
local keyCollapsed
local keyListen
local keyCapture

local function Paint(target, bg, border)
    if not target.SetBackdrop then
        return
    end
    target:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    target:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    if border then
        target:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    end
end

local function Spec()
    return SECTIONS[sectionId]
end

local function API()
    local spec = Spec()
    if not spec then
        return nil
    end
    return spec.api()
end

local function Speak(text)
    print("|cff00ff00[Light Paws Loadouts]|r " .. tostring(text))
end

local function Notice(text, warn)
    Speak(text)
    local page = UI.page
    if page and page.notice then
        page.notice:SetText(text or "")
        if warn then
            page.notice:SetTextColor(1, 0.35, 0.35)
        else
            page.notice:SetTextColor(1, 0.82, 0)
        end
    end
    if page and page.editorNotice then
        page.editorNotice:SetText(text or "")
        if warn then
            page.editorNotice:SetTextColor(1, 0.35, 0.35)
        else
            page.editorNotice:SetTextColor(1, 0.82, 0)
        end
    end
    if not warn or not StaticPopup_Show then
        return
    end
    if not StaticPopupDialogs["LPL_FOREVER_APPLY"] then
        StaticPopupDialogs["LPL_FOREVER_APPLY"] = {
            text = "%s",
            button1 = OKAY or "Okay",
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    pcall(StaticPopup_Show, "LPL_FOREVER_APPLY", text)
end

local function BarButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 24)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(label)
    text:SetTextColor(1, 1, 1)
    Paint(button, BUTTON_BG, BUTTON_BORDER)
    button:SetScript("OnEnter", function()
        Paint(button, BUTTON_HOVER, BUTTON_BORDER)
    end)
    button:SetScript("OnLeave", function()
        Paint(button, BUTTON_BG, BUTTON_BORDER)
    end)
    button:SetScript("OnMouseDown", function()
        Paint(button, BUTTON_PRESSED, BUTTON_BORDER)
    end)
    button:SetScript("OnMouseUp", function()
        Paint(button, BUTTON_HOVER, BUTTON_BORDER)
    end)
    return button
end

local function GlowButton(parent, label, width, height)
    local pad = 8
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width + pad * 2, height + pad * 2)

    local halo = container:CreateTexture(nil, "BACKGROUND")
    halo:SetPoint("TOPLEFT", 0, 0)
    halo:SetPoint("BOTTOMRIGHT", 0, 0)
    halo:SetColorTexture(0.30, 0.90, 0.40, 0.28)

    local ring = CreateFrame("Frame", nil, container, "BackdropTemplate")
    ring:SetPoint("TOPLEFT", 3, -3)
    ring:SetPoint("BOTTOMRIGHT", -3, 3)
    ring:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ring:SetBackdropColor(0, 0, 0, 0)
    ring:SetBackdropBorderColor(0.50, 1.00, 0.55, 0.90)

    local button = CreateFrame("Button", nil, container, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint("CENTER")
    button:SetFrameLevel(container:GetFrameLevel() + 2)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(0.58, 0.10, 0.16, 1)
    button:SetBackdropBorderColor(0.72, 0.18, 0.26, 1)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(label)
    text:SetTextColor(1, 0.92, 0.40)

    local function PaintGlow(hover, pressed)
        if pressed then
            button:SetBackdropColor(0.42, 0.08, 0.12, 1)
            halo:SetColorTexture(0.35, 0.95, 0.45, 0.40)
        elseif hover then
            button:SetBackdropColor(0.68, 0.14, 0.22, 1)
            halo:SetColorTexture(0.35, 0.95, 0.45, 0.40)
        else
            button:SetBackdropColor(0.58, 0.10, 0.16, 1)
            halo:SetColorTexture(0.30, 0.90, 0.40, 0.28)
        end
    end
    button:SetScript("OnEnter", function()
        PaintGlow(true, false)
    end)
    button:SetScript("OnLeave", function()
        PaintGlow(false, false)
    end)
    button:SetScript("OnMouseDown", function()
        PaintGlow(true, true)
    end)
    button:SetScript("OnMouseUp", function()
        PaintGlow(true, false)
    end)

    function container:SetClick(handler)
        button:SetScript("OnClick", handler)
    end
    function container:SetLabel(value)
        text:SetText(value)
    end
    return container
end

local function ReadName(edit, fallback)
    local plain = edit and LPL:PlainString(edit:GetText()) or nil
    if not plain then
        return fallback
    end
    plain = plain:match("^%s*(.-)%s*$") or ""
    if plain == "" then
        return fallback
    end
    return plain
end

local function HidePools()
    for i = 1, #iconRows do
        iconRows[i]:Hide()
    end
    for i = 1, #lineButtons do
        lineButtons[i]:Hide()
    end
    for i = 1, #actionRows do
        actionRows[i]:Hide()
    end
    if gearDoll then
        gearDoll:Hide()
    end
end

local SLOT = 33
local SLOT_GAP = 2
local LABEL_W = 88
local LOCK = 28
local SLOT_BG = { 0, 0, 0, 1 }
local SLOT_BORDER = { 1, 0.92, 0.40, 1 }
local IGNORED_BORDER = { 0.45, 0.45, 0.45, 1 }

local function IgnoreKey(slotID, isPet)
    if isPet then
        return "pet:" .. tostring(slotID)
    end
    return tostring(slotID)
end

local held
local heldFrame

local function HideHeld()
    if heldFrame then
        heldFrame:Hide()
    end
end

local function ShowHeld(action)
    if not heldFrame then
        heldFrame = CreateFrame("Frame", nil, UIParent)
        heldFrame:SetFrameStrata("TOOLTIP")
        heldFrame:EnableMouse(false)
        heldFrame:SetSize(33, 33)
        heldFrame.icon = heldFrame:CreateTexture(nil, "ARTWORK")
        heldFrame.icon:SetAllPoints()
        heldFrame:SetScript("OnUpdate", function(self)
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            if not scale or scale == 0 then
                scale = 1
            end
            self:ClearAllPoints()
            self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        end)
    end
    local texture = LPL.ActionBarAPI and LPL.ActionBarAPI:Icon(action)
    if texture then
        heldFrame.icon:SetTexture(texture)
        heldFrame:Show()
    else
        heldFrame:Hide()
    end
end

local function CopyDragAction(action)
    if type(action) ~= "table" or type(action.kind) ~= "string" then
        return nil
    end
    return {
        kind = action.kind,
        spellID = action.spellID,
        itemID = action.itemID,
        macroIndex = action.macroIndex,
        macroName = action.macroName,
        macroBody = action.macroBody,
    }
end

local function DraftBucket(isPet)
    if not draft then
        return nil
    end
    if isPet then
        draft.petSlots = draft.petSlots or {}
        return draft.petSlots
    end
    draft.slots = draft.slots or {}
    return draft.slots
end

local function ReleaseHold()
    if held and held.onCursor and ClearCursor then
        ClearCursor()
    elseif held and draft and not held.onCursor then
        local bucket = DraftBucket(held.isPet)
        if bucket and bucket[tostring(held.slotID)] == nil then
            bucket[tostring(held.slotID)] = held.action
        end
    end
    held = nil
    HideHeld()
end

local function BeginHold(slotID, isPet)
    if InCombatLockdown and InCombatLockdown() then
        Notice("Leave combat before moving a button onto your bars.", true)
        return false
    end
    local bucket = DraftBucket(isPet)
    if not bucket then
        return false
    end
    local action = CopyDragAction(bucket[tostring(slotID)])
    if not action then
        return false
    end
    local api = LPL.ActionBarAPI
    if api and api.Pickup and api:Pickup(action) then
        -- Real cursor, so a character action bar can take the drop.
        -- The saved slot stays until the drop lands on another editor slot.
        held = { action = action, slotID = slotID, isPet = isPet, onCursor = true }
        HideHeld()
        return true
    end
    bucket[tostring(slotID)] = nil
    held = { action = action, slotID = slotID, isPet = isPet }
    ShowHeld(action)
    return true
end

local RefreshEditor

local function DropOn(slotID, isPet, api)
    local fromCursor = api and api:FromCursor()
    if fromCursor then
        local dest = DraftBucket(isPet)
        local previous = dest and CopyDragAction(dest[tostring(slotID)]) or nil
        if dest then
            dest[tostring(slotID)] = fromCursor
        end
        if held and (held.slotID ~= slotID or held.isPet ~= isPet) then
            local source = DraftBucket(held.isPet)
            if source then
                source[tostring(held.slotID)] = previous
            end
        end
        held = nil
        HideHeld()
        if ClearCursor then
            ClearCursor()
        end
        RefreshEditor()
        return true
    end
    if not held then
        return false
    end
    if held.slotID == slotID and held.isPet == isPet then
        local bucket = DraftBucket(isPet)
        if bucket then
            bucket[tostring(slotID)] = held.action
        end
        held = nil
        HideHeld()
        RefreshEditor()
        return true
    end
    local dest = DraftBucket(isPet)
    local previous = dest and CopyDragAction(dest[tostring(slotID)]) or nil
    if dest then
        dest[tostring(slotID)] = held.action
    end
    local source = DraftBucket(held.isPet)
    if source then
        source[tostring(held.slotID)] = previous
    end
    held = nil
    HideHeld()
    RefreshEditor()
    return true
end

local function AcquireActionRow(parent, index)
    local row = actionRows[index]
    if row then
        return row
    end
    row = CreateFrame("Frame", nil, parent)
    row:SetHeight(36)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetWidth(LABEL_W)
    row.label:SetJustifyH("LEFT")
    row.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    row.buttons = {}
    for slotIndex = 1, 12 do
        local button = CreateFrame("Button", nil, row, "BackdropTemplate")
        button.lplSlot = true
        button:SetSize(SLOT, SLOT)
        button:SetPoint("LEFT", LABEL_W + (slotIndex - 1) * (SLOT + SLOT_GAP), 0)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        Paint(button, SLOT_BG, SLOT_BORDER)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        button.ignore = button:CreateTexture(nil, "OVERLAY")
        button.ignore:SetSize(29, 29)
        button.ignore:SetPoint("CENTER")
        LPL:SetIconTexture(button.ignore, "ignore_64")
        button.ignore:Hide()
        row.buttons[slotIndex] = button
    end
    local lock = CreateFrame("Button", nil, row, "BackdropTemplate")
    lock:SetSize(LOCK, LOCK)
    lock:SetPoint("LEFT", LABEL_W + 12 * (SLOT + SLOT_GAP) + 4, 0)
    Paint(lock, SLOT_BG, SLOT_BORDER)
    lock.icon = lock:CreateTexture(nil, "ARTWORK")
    lock.icon:SetPoint("TOPLEFT", 3, -3)
    lock.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    LPL:SetIconTexture(lock.icon, "lock_64")
    row.lock = lock
    actionRows[index] = row
    return row
end

local function RefreshActionBars(page, api)
    local rows = api:Rows()
    local width = LABEL_W + 12 * (SLOT + SLOT_GAP) + LOCK + 16
    local y = 4
    for rowIndex = 1, #rows do
        local info = rows[rowIndex]
        local row = AcquireActionRow(page.editorChild, rowIndex)
        row:SetParent(page.editorChild)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 12, -y)
        row:SetSize(width, 36)
        row.label:SetText(info.label)
        local isPet = info.isPet == true
        local slotCount = info.last - info.first + 1
        local allIgnored = slotCount > 0
        for slotIndex = 1, 12 do
            local button = row.buttons[slotIndex]
            if slotIndex > slotCount then
                button:Hide()
            else
                local slotID = info.first + slotIndex - 1
                local key = IgnoreKey(slotID, isPet)
                local bucket = isPet and draft.petSlots or draft.slots
                local action = bucket and bucket[tostring(slotID)]
                local ignored = draft.ignored and draft.ignored[key] == true
                if not ignored then
                    allIgnored = false
                end
                Paint(button, SLOT_BG, ignored and IGNORED_BORDER or SLOT_BORDER)
                local texture = api:Icon(action)
                if texture then
                    button.icon:SetTexture(texture)
                    button.icon:SetDesaturated(ignored)
                    button.icon:SetAlpha(ignored and 0.8 or 1)
                    button.icon:Show()
                else
                    button.icon:Hide()
                end
                if button.ignore then
                    button.ignore:SetShown(ignored)
                end
                local slotLabel = info.label .. " " .. tostring(slotID)
                button:SetScript("OnEnter", function(self)
                    api:ShowTooltip(self, action, slotLabel)
                    if GameTooltip then
                        GameTooltip:AddLine("Shift+left-click to ignore this slot.", 0.7, 0.7, 0.7)
                        GameTooltip:Show()
                    end
                end)
                button:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                local function PlaceHere()
                    DropOn(slotID, isPet, api)
                end
                button:SetScript("OnDragStart", function(self)
                    if GetCursorInfo and GetCursorInfo() then
                        return
                    end
                    if held then
                        return
                    end
                    if BeginHold(slotID, isPet) then
                        if held then
                            held.fromDrag = true
                        end
                    end
                end)
                button:SetScript("OnClick", function(self, mouse)
                    if self.receivedDrag then
                        self.receivedDrag = false
                        if GetCursorInfo and GetCursorInfo() or held then
                            DropOn(slotID, isPet, api)
                        end
                        return
                    end
                    if mouse == "RightButton" then
                        if held or (GetCursorInfo and GetCursorInfo()) then
                            ReleaseHold()
                            if ClearCursor then
                                ClearCursor()
                            end
                            RefreshEditor()
                            return
                        end
                        if isPet and draft.petSlots then
                            draft.petSlots[tostring(slotID)] = nil
                        elseif draft.slots then
                            draft.slots[tostring(slotID)] = nil
                        end
                        RefreshEditor()
                        return
                    end
                    local shift = (IsShiftKeyDown and IsShiftKeyDown()) or (IsModifiedClick and IsModifiedClick("SHIFT"))
                    if shift then
                        draft.ignored = draft.ignored or {}
                        draft.ignored[key] = not draft.ignored[key] and true or nil
                        RefreshEditor()
                        return
                    end
                    if (GetCursorInfo and GetCursorInfo()) or held then
                        DropOn(slotID, isPet, api)
                        return
                    end
                    if BeginHold(slotID, isPet) then
                        RefreshEditor()
                    end
                end)
                button:SetScript("OnReceiveDrag", function(self)
                    self.receivedDrag = true
                    DropOn(slotID, isPet, api)
                end)
                button:Show()
            end
        end
        local lockX = LABEL_W + slotCount * (SLOT + SLOT_GAP) + 4
        row.lock:ClearAllPoints()
        row.lock:SetPoint("LEFT", lockX, 0)
        if row.lock.icon then
            row.lock.icon:SetVertexColor(allIgnored and 1 or 0.75, allIgnored and 1 or 0.75, allIgnored and 1 or 0.75)
        end
        row.lock:SetScript("OnClick", function()
            draft.ignored = draft.ignored or {}
            local turnOn = not allIgnored
            for slotID = info.first, info.last do
                draft.ignored[IgnoreKey(slotID, isPet)] = turnOn and true or nil
            end
            RefreshEditor()
        end)
        row.lock:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(isPet and "Ignores full pet bar" or "Ignores full bar", 1, 0.82, 0)
            GameTooltip:AddLine("Click to ignore or unignore every slot in this row.", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        row.lock:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        row:Show()
        y = y + 42
    end
    page.editorChild:SetWidth(width + 24)
    page.editorChild:SetHeight(math.max(y + 8, 40))
end

local function AcquireIconRow(parent, index)
    local row = iconRows[index]
    if row then
        return row
    end
    row = CreateFrame("Frame", nil, parent)
    row:SetHeight(40)
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.label:SetPoint("LEFT", 8, 0)
    row.label:SetWidth(84)
    row.label:SetJustifyH("RIGHT")
    row.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    row.note = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.note:SetJustifyH("LEFT")
    row.note:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    row.buttons = {}
    for slotIndex = 1, 12 do
        local button = CreateFrame("Button", nil, row, "BackdropTemplate")
        button:SetSize(32, 32)
        button:SetPoint("LEFT", 100 + (slotIndex - 1) * 36, 0)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        Paint(button, { 0.12, 0.12, 0.14, 1 }, BORDER)
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetPoint("TOPLEFT", 2, -2)
        button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
        row.buttons[slotIndex] = button
    end
    row.note:SetPoint("LEFT", row.buttons[1], "RIGHT", 8, 0)
    row.note:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    iconRows[index] = row
    return row
end

local KEY_BOX_W = 132
local KEY_BORDER = { 1, 0.92, 0.40, 1 }
local KEY_LISTEN_BORDER = { 0.50, 1, 0.55, 1 }

local KEY_IGNORE = {
    BUTTON1 = true,
    BUTTON2 = true,
    UNKNOWN = true,
    LSHIFT = true,
    LCTRL = true,
    LALT = true,
    RSHIFT = true,
    RCTRL = true,
    RALT = true,
}

local function WithModifiers(key)
    if IsShiftKeyDown and IsShiftKeyDown() then
        key = "SHIFT-" .. key
    end
    if IsControlKeyDown and IsControlKeyDown() then
        key = "CTRL-" .. key
    end
    if IsAltKeyDown and IsAltKeyDown() then
        key = "ALT-" .. key
    end
    return key
end

local function PaintKeyBox(box, listening)
    if not box or not box.SetBackdrop then
        return
    end
    box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    box:SetBackdropColor(0, 0, 0, 1)
    local border = listening and KEY_LISTEN_BORDER or KEY_BORDER
    box:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
end

local function StopKeyListen()
    keyListen = nil
    if keyCapture then
        keyCapture:Hide()
        if keyCapture.EnableKeyboard then
            keyCapture:EnableKeyboard(false)
        end
    end
end

local function EnsureKeyCapture()
    if keyCapture then
        return keyCapture
    end
    local capture = CreateFrame("Button", nil, UIParent)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:SetAllPoints(UIParent)
    capture:EnableMouse(true)
    capture:EnableMouseWheel(true)
    capture:RegisterForClicks("AnyUp")
    capture:Hide()
    local dim = capture:CreateTexture(nil, "BACKGROUND")
    dim:SetAllPoints(capture)
    dim:SetColorTexture(0, 0, 0, 0.35)
    local label = capture:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    label:SetPoint("CENTER", 0, 24)
    label:SetText("Press a key, mouse button, or mouse wheel")
    local hint = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOP", label, "BOTTOM", 0, -8)
    hint:SetText("Esc clears this box. Click to cancel.")
    capture:SetScript("OnShow", function(self)
        if self.EnableKeyboard then
            self:EnableKeyboard(true)
        end
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end
    end)
    capture:SetScript("OnHide", function(self)
        if self.EnableKeyboard then
            self:EnableKeyboard(false)
        end
    end)
    local function Finish(key)
        local listen = keyListen
        StopKeyListen()
        if listen and draft and API() then
            API():AssignKey(draft, listen.command, listen.slot, key)
        end
        RefreshEditor()
    end
    capture:SetScript("OnKeyDown", function(_, key)
        if not keyListen or KEY_IGNORE[key] then
            return
        end
        if key == "ESCAPE" then
            Finish(nil)
            return
        end
        Finish(WithModifiers(key))
    end)
    capture:SetScript("OnMouseDown", function(_, button)
        if not keyListen then
            return
        end
        if button == "LeftButton" or button == "RightButton" then
            StopKeyListen()
            RefreshEditor()
            return
        end
        local key = button
        if button == "MiddleButton" then
            key = "BUTTON3"
        elseif button == "Button4" then
            key = "BUTTON4"
        elseif button == "Button5" then
            key = "BUTTON5"
        end
        Finish(WithModifiers(key))
    end)
    capture:SetScript("OnMouseWheel", function(_, delta)
        if not keyListen then
            return
        end
        local key = (delta and delta >= 0) and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
        Finish(WithModifiers(key))
    end)
    keyCapture = capture
    return capture
end

local function StartKeyListen(command, slot)
    if not command then
        return
    end
    keyListen = { command = command, slot = slot }
    local capture = EnsureKeyCapture()
    capture:Show()
    capture:Raise()
    RefreshEditor()
end

local function MakeKeyBox(parent, offset)
    local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
    box:SetSize(KEY_BOX_W, 22)
    box:SetPoint("RIGHT", offset, 0)
    box:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    box.text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.text:SetPoint("CENTER")
    box.text:SetJustifyH("CENTER")
    box.text:SetWidth(KEY_BOX_W - 10)
    PaintKeyBox(box, false)
    return box
end

local function AcquireLine(parent, index)
    local button = lineButtons[index]
    if button then
        return button
    end
    button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetHeight(28)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button.left = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.left:SetPoint("LEFT", 12, 0)
    button.left:SetJustifyH("LEFT")
    button.left:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    button.expand = button:CreateTexture(nil, "ARTWORK")
    button.expand:SetSize(14, 14)
    button.expand:SetPoint("LEFT", 6, 0)
    button.expand:Hide()
    button.key2 = MakeKeyBox(button, -4)
    button.key1 = MakeKeyBox(button, -(KEY_BOX_W + 8))
    lineButtons[index] = button
    return button
end

local GEAR_SLOT = 38
local GEAR_DETAIL = 112
local GEAR_ROW = 46
local EMPTY_SLOT_TEXTURE = "Interface\\PaperDoll\\UI-Backpack-EmptySlot"

local GEAR_LEFT = {
    { id = 1, label = "Head" },
    { id = 2, label = "Neck" },
    { id = 3, label = "Shoulder" },
    { id = 15, label = "Back" },
    { id = 5, label = "Chest" },
    { id = 4, label = "Shirt", locked = true },
    { id = 19, label = "Tabard", locked = true },
    { id = 9, label = "Wrist" },
}
local GEAR_RIGHT = {
    { id = 10, label = "Hands" },
    { id = 6, label = "Waist" },
    { id = 7, label = "Legs" },
    { id = 8, label = "Feet" },
    { id = 11, label = "Finger 1" },
    { id = 12, label = "Finger 2" },
    { id = 13, label = "Trinket 1" },
    { id = 14, label = "Trinket 2" },
}
local GEAR_WEAPONS = {
    { id = 16, label = "Main Hand", side = "left" },
    { id = 17, label = "Off Hand", side = "right" },
    { id = 18, label = "Ranged", side = "left" },
    { id = 0, label = "Ammo", side = "right", emptyTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ammo" },
}

local function CursorItemID()
    if not GetCursorInfo then
        return nil
    end
    local kind, itemID = GetCursorInfo()
    if LPL:PlainString(kind) ~= "item" then
        return nil
    end
    return LPL:PlainNumber(itemID)
end

local function EnsureGearSlot(parent, info, side)
    local slot = parent.slots[info.id]
    if slot then
        if slot.button and not slot.button.ignore then
            slot.button.ignore = slot.button:CreateTexture(nil, "OVERLAY")
            slot.button.ignore:SetSize(29, 29)
            slot.button.ignore:SetPoint("CENTER")
            LPL:SetIconTexture(slot.button.ignore, "ignore_64")
            slot.button.ignore:Hide()
        end
        return slot
    end
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(GEAR_SLOT + GEAR_DETAIL + 4, GEAR_ROW)
    local button = CreateFrame("Button", nil, row, "BackdropTemplate")
    button:SetSize(GEAR_SLOT, GEAR_SLOT)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    Paint(button, SLOT_BG, SLOT_BORDER)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    button.ignore = button:CreateTexture(nil, "OVERLAY")
    button.ignore:SetSize(29, 29)
    button.ignore:SetPoint("CENTER")
    LPL:SetIconTexture(button.ignore, "ignore_64")
    button.ignore:Hide()
    local detail = CreateFrame("Frame", nil, row, "BackdropTemplate")
    detail:SetSize(GEAR_DETAIL, GEAR_SLOT)
    Paint(detail, { 0.08, 0.08, 0.10, 1 }, BORDER)
    detail:EnableMouse(true)
    detail.text = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail.text:SetPoint("LEFT", 6, 0)
    detail.text:SetPoint("RIGHT", -6, 0)
    detail.text:SetJustifyH(side == "right" and "RIGHT" or "LEFT")
    detail.text:SetWordWrap(false)
    if side == "right" then
        button:SetPoint("RIGHT", row, "RIGHT", 0, -4)
        detail:SetPoint("RIGHT", button, "LEFT", -4, 0)
    else
        button:SetPoint("LEFT", row, "LEFT", 0, -4)
        detail:SetPoint("LEFT", button, "RIGHT", 4, 0)
    end
    slot = { row = row, button = button, detail = detail, info = info }
    parent.slots[info.id] = slot
    return slot
end

local function RefreshGearDoll(page, api)
    if not gearDoll then
        gearDoll = CreateFrame("Frame", nil, page.editorChild)
        gearDoll.slots = {}
        gearDoll.model = CreateFrame("PlayerModel", nil, gearDoll)
        gearDoll.model:SetSize(180, 250)
        local shown = pcall(function()
            gearDoll.model:SetUnit("player")
            if gearDoll.model.SetFacing then
                gearDoll.model:SetFacing(0.4)
            end
        end)
        if not shown then
            gearDoll.model:Hide()
        end
    end
    gearDoll:SetParent(page.editorChild)
    gearDoll:ClearAllPoints()
    gearDoll:SetPoint("TOPLEFT", page.editorChild, "TOPLEFT", 0, 0)
    gearDoll:SetSize(math.max(640, page.editorScroll:GetWidth() or 640), 580)
    gearDoll.model:ClearAllPoints()
    gearDoll.model:SetPoint("CENTER", gearDoll, "CENTER", 0, 28)
    if gearDoll.model.SetUnit then
        pcall(gearDoll.model.SetUnit, gearDoll.model, "player")
    end
    gearDoll:Show()

    local function PlaceColumn(entries, side)
        local count = #entries
        local stride = GEAR_ROW + 4
        for index, info in ipairs(entries) do
            local slot = EnsureGearSlot(gearDoll, info, side)
            local offsetY = ((count - 1) / 2 - (index - 1)) * stride
            slot.row:ClearAllPoints()
            if side == "left" then
                slot.row:SetPoint("RIGHT", gearDoll.model, "LEFT", -10, offsetY)
            else
                slot.row:SetPoint("LEFT", gearDoll.model, "RIGHT", 10, offsetY)
            end
            slot.row:Show()
        end
    end

    PlaceColumn(GEAR_LEFT, "left")
    PlaceColumn(GEAR_RIGHT, "right")

    local weapons = {}
    for i = 1, #GEAR_WEAPONS do
        weapons[#weapons + 1] = GEAR_WEAPONS[i]
    end
    local columnStride = GEAR_ROW + 4
    local columnCount = math.max(#GEAR_LEFT, #GEAR_RIGHT)
    local columnBottom = -((columnCount - 1) / 2) * columnStride - (GEAR_ROW / 2)
    local stride = GEAR_SLOT + GEAR_DETAIL + 4
    for index, info in ipairs(weapons) do
        local slot = EnsureGearSlot(gearDoll, info, info.side or "left")
        local offsetX = (index - (#weapons + 1) / 2) * stride
        slot.row:ClearAllPoints()
        slot.row:SetPoint("TOP", gearDoll.model, "CENTER", offsetX, columnBottom - 8)
        slot.row:Show()
    end

    local function BindSlot(slot)
        local info = slot.info
        local itemID = (not info.locked) and api:ItemID(draft, info.id) or nil
        local ignored = draft.ignored and draft.ignored[tostring(info.id)] == true
        local texture = itemID and api:Icon(itemID) or nil
        if texture then
            slot.button.icon:SetTexture(texture)
        else
            slot.button.icon:SetTexture(info.emptyTexture or EMPTY_SLOT_TEXTURE)
        end
        slot.button.icon:SetDesaturated(ignored)
        slot.button.icon:SetAlpha(ignored and 0.8 or 1)
        slot.button.icon:Show()
        if slot.button.ignore then
            slot.button.ignore:SetShown(ignored)
        end
        Paint(slot.button, SLOT_BG, ignored and IGNORED_BORDER or SLOT_BORDER)
        local name = itemID and api:ItemName(itemID) or info.label
        slot.detail.text:SetText(name or info.label)
        if itemID then
            slot.detail.text:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
        else
            slot.detail.text:SetTextColor(0.55, 0.55, 0.55)
        end
        slot.button:SetScript("OnEnter", function(self)
            api:ShowTooltip(self, itemID, info.label)
            if GameTooltip then
                GameTooltip:AddLine("Shift+left-click to ignore this slot.", 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end
        end)
        slot.button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        slot.detail:SetScript("OnEnter", function(self)
            api:ShowTooltip(self, itemID, info.label)
        end)
        slot.detail:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        local function TakeItem()
            if info.locked or not draft then
                return
            end
            local dropped = CursorItemID()
            if not dropped then
                return
            end
            draft.slots = draft.slots or {}
            draft.slots[tostring(info.id)] = { itemID = dropped }
            if ClearCursor then
                ClearCursor()
            end
            RefreshEditor()
        end
        slot.button:SetScript("OnClick", function(_, mouse)
            local shift = (IsShiftKeyDown and IsShiftKeyDown()) or (IsModifiedClick and IsModifiedClick("SHIFT"))
            if mouse == "LeftButton" and shift then
                draft.ignored = draft.ignored or {}
                local key = tostring(info.id)
                draft.ignored[key] = not draft.ignored[key] and true or nil
                RefreshEditor()
                return
            end
            if info.locked then
                return
            end
            if mouse == "RightButton" then
                api:ClearSlot(draft, info.id)
                RefreshEditor()
                return
            end
            TakeItem()
        end)
        slot.button:SetScript("OnReceiveDrag", TakeItem)
    end

    for _, slot in pairs(gearDoll.slots) do
        if slot.row:IsShown() then
            BindSlot(slot)
        end
    end

    page.editorChild:SetWidth(gearDoll:GetWidth())
    page.editorChild:SetHeight(gearDoll:GetHeight())
end

function RefreshEditor()
    local page = UI.page
    local api = API()
    if not page or not api or not draft then
        return
    end
    HidePools()
    local width = math.max(520, (page.editorScroll:GetWidth() or 640) - 8)
    local y = 8
    if sectionId == "actionbars" then
        RefreshActionBars(page, api)
        return
    end
    if sectionId == "keybinds" then
        local lines = api:EditorLines(draft)
        if keyCollapsed == nil then
            keyCollapsed = {}
            for i = 1, #lines do
                local line = lines[i]
                if line.kind == "header" and line.id then
                    keyCollapsed[line.id] = true
                end
            end
        end
        local visible = {}
        local hidden = false
        for i = 1, #lines do
            local line = lines[i]
            if line.kind == "header" then
                hidden = keyCollapsed[line.id] == true
                visible[#visible + 1] = line
            elseif not hidden then
                visible[#visible + 1] = line
            end
        end
        local function PaintKey(box, text, bound, command, slot)
            local listening = keyListen and keyListen.command == command and keyListen.slot == slot
            box:Show()
            PaintKeyBox(box, listening)
            box.text:SetText(listening and "..." or (text or "Not Bound"))
            if bound and not listening then
                box.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            else
                box.text:SetTextColor(0.85, 0.85, 0.85)
            end
            box:SetScript("OnClick", function(_, mouse)
                if not command then
                    return
                end
                if mouse == "RightButton" then
                    StopKeyListen()
                    api:ClearKey(draft, command, slot)
                    RefreshEditor()
                    return
                end
                if listening then
                    StopKeyListen()
                    RefreshEditor()
                    return
                end
                StartKeyListen(command, slot)
            end)
        end
        for i = 1, #visible do
            local line = visible[i]
            local button = AcquireLine(page.editorChild, i)
            button:SetParent(page.editorChild)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 4, -y)
            button:SetSize(width - 8, line.kind == "header" and 26 or 28)
            button.left:ClearAllPoints()
            if line.kind == "header" then
                Paint(button, { 0.14, 0.14, 0.16, 1 }, KEY_BORDER)
                local collapsed = keyCollapsed[line.id] == true
                button.expand:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                button.expand:Show()
                button.left:SetPoint("LEFT", 26, 0)
                button.left:SetText((line.left or "Other") .. "  (" .. tostring(line.count or 0) .. ")")
                button.left:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                button.left:SetWidth(width - 40)
                button.key1:Hide()
                button.key2:Hide()
                local headerId = line.id
                button:SetScript("OnClick", function()
                    if keyCollapsed[headerId] then
                        keyCollapsed[headerId] = nil
                    else
                        keyCollapsed[headerId] = true
                    end
                    RefreshEditor()
                end)
            else
                Paint(button, { 0.10, 0.10, 0.12, 1 }, BORDER)
                button.expand:Hide()
                button.left:SetPoint("LEFT", 12, 0)
                button.left:SetText(line.left)
                button.left:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
                button.left:SetWidth(math.max(80, width - 8 - (KEY_BOX_W * 2) - 28))
                button:SetScript("OnClick", nil)
                PaintKey(button.key1, line.key1, line.bound1, line.command, 1)
                PaintKey(button.key2, line.key2, line.bound2, line.command, 2)
            end
            button:Show()
            y = y + (line.kind == "header" and 28 or 30)
        end
    else
        RefreshGearDoll(page, api)
        return
    end
    page.editorChild:SetWidth(width)
    page.editorChild:SetHeight(math.max(y + 8, 40))
end

local function CursorMatchesHold()
    local api = LPL.ActionBarAPI
    local from = api and held and held.action and api:FromCursor()
    if not from or not held.action then
        return false
    end
    local action = held.action
    if from.kind ~= action.kind then
        return false
    end
    if action.kind == "spell" then
        return from.spellID == action.spellID
    end
    if action.kind == "item" then
        return from.itemID == action.itemID
    end
    if action.kind == "macro" then
        return from.macroIndex == action.macroIndex or (from.macroName and from.macroName ~= "" and from.macroName == action.macroName)
    end
    return false
end

local function PointerOverLPLSlot()
    if GetMouseFoci then
        local ok, foci = pcall(GetMouseFoci)
        if ok and type(foci) == "table" then
            for i = 1, #foci do
                if foci[i] and foci[i].lplSlot then
                    return true
                end
            end
            return false
        end
    end
    if GetMouseFocus then
        local ok, focus = pcall(GetMouseFocus)
        if ok then
            return focus and focus.lplSlot and true or false
        end
    end
    return nil
end

local cursorWatch = CreateFrame("Frame")
cursorWatch:SetScript("OnUpdate", function()
    if not held then
        return
    end
    if held.onCursor then
        if CursorMatchesHold() then
            return
        end
        held = nil
        HideHeld()
        return
    end
    if not held.fromDrag or (IsMouseButtonDown and IsMouseButtonDown("LeftButton")) then
        return
    end
    if PointerOverLPLSlot() ~= false then
        return
    end
    ReleaseHold()
    if mode == "editor" then
        RefreshEditor()
    end
end)

local function CopySet(saved)
    local copy = {
        id = saved.id,
        name = saved.name,
        scope = saved.scope,
        slots = {},
        petSlots = {},
        ignored = {},
        bindings = {},
    }
    if type(saved.slots) == "table" then
        for key, entry in pairs(saved.slots) do
            if type(entry) == "table" then
                local slotCopy = {}
                for field, value in pairs(entry) do
                    slotCopy[field] = value
                end
                copy.slots[key] = slotCopy
            end
        end
    end
    if type(saved.petSlots) == "table" then
        for key, entry in pairs(saved.petSlots) do
            if type(entry) == "table" then
                local slotCopy = {}
                for field, value in pairs(entry) do
                    slotCopy[field] = value
                end
                copy.petSlots[key] = slotCopy
            end
        end
    end
    if type(saved.ignored) == "table" then
        for key, value in pairs(saved.ignored) do
            if value == true then
                copy.ignored[key] = true
            end
        end
    end
    if type(saved.bindings) == "table" then
        for command, keys in pairs(saved.bindings) do
            if type(keys) == "table" then
                copy.bindings[command] = {
                    key1 = keys.key1,
                    key2 = keys.key2,
                }
            end
        end
    end
    return copy
end

local function ShowEditor(set, isNew)
    local page = UI.page
    local spec = Spec()
    if not page or not spec then
        return
    end
    mode = "editor"
    draft = set
    keyCollapsed = nil
    StopKeyListen()
    page.listPage:Hide()
    page.editorPage:Show()
    page.nameBox:SetText(set.name or spec.api():SuggestName())
    local detail = spec.detail
    if set.skipped and set.skipped > 0 then
        detail = detail .. " " .. set.skipped .. " entries could not be read on this client."
    end
    page.detail:SetText(detail)
    page.detail:SetHeight(sectionId == "actionbars" and 18 or 48)
    page.editorScroll:ClearAllPoints()
    page.editorScroll:SetPoint("TOPLEFT", 8, sectionId == "actionbars" and -34 or -62)
    page.editorScroll:SetPoint("BOTTOMRIGHT", -28, EDITOR_BAR_H + 28)
    RefreshEditor()
    if isNew then
        Speak("New " .. spec.noun .. ".")
    end
end

local function RefreshList()
    local page = UI.page
    local api = API()
    local spec = Spec()
    if not page or not api or not spec then
        return
    end
    local sets = api:List()
    local query = ""
    if page.search then
        query = (LPL:PlainString(page.search:GetText()) or ""):lower()
    end
    local live = api:Capture()
    local shown = {}
    for i = 1, #sets do
        local name = (sets[i].name or ""):lower()
        if query == "" or name:find(query, 1, true) then
            shown[#shown + 1] = sets[i]
        end
    end
    for i = 1, #listButtons do
        listButtons[i]:Hide()
    end
    page.emptyButton:SetShown(#sets == 0)
    if page.emptyButton.SetLabel then
        local spec = Spec()
        page.emptyButton:SetLabel((spec and spec.emptyLabel) or "New")
    end
    if page.listBar then
        page.listBar:SetShown(#sets > 0)
    end
    if page.search then
        page.search:SetShown(#sets > 0)
    end
    page.listScroll:SetShown(#sets > 0)
    page.noMatch:SetShown(#sets > 0 and #shown == 0)
    local width = math.max(240, (page.listScroll:GetWidth() or 640) - 16)
    local y = 4
    for i = 1, #shown do
        local set = shown[i]
        local button = listButtons[i]
        if not button then
            button = CreateFrame("Button", nil, page.listChild, "BackdropTemplate")
            button:RegisterForClicks("LeftButtonUp")
            button.badge = button:CreateTexture(nil, "OVERLAY")
            button.badge:SetSize(8, 8)
            button.badge:SetColorTexture(0.40, 1.00, 0.50, 1)
            button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            button.label:SetJustifyH("LEFT")
            button.subtitle = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.subtitle:SetJustifyH("LEFT")
            button.subtitle:SetTextColor(0.78, 0.81, 0.88)
            listButtons[i] = button
        end
        button:SetParent(page.listChild)
        local selected = selectedId and tonumber(set.id) == tonumber(selectedId)
        local active = api:Matches(set, live)
        local border = BORDER
        local bg = { 0.18, 0.18, 0.22, 1 }
        if selected then
            bg = SELECTED
            border = { 0.48, 0.11, 0.16, 1 }
        elseif active then
            border = { 0.50, 1.00, 0.55, 1 }
        end
        button:SetSize(width, 40)
        Paint(button, bg, border)
        button.badge:SetShown(active)
        button.badge:ClearAllPoints()
        button.badge:SetPoint("LEFT", 8, 6)
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT", active and 22 or 12, -6)
        button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button.label:SetText(set.name or spec.noun)
        button.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
        button.subtitle:ClearAllPoints()
        button.subtitle:SetPoint("TOPLEFT", button.label, "BOTTOMLEFT", 0, -2)
        button.subtitle:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        button.subtitle:SetText(api:Summary(set))
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 8, -y)
        local id = set.id
        button:SetScript("OnClick", function()
            selectedId = id
            RefreshList()
        end)
        button:SetScript("OnDoubleClick", function()
            selectedId = id
            local saved = api:Get(id)
            if saved then
                ShowEditor(CopySet(saved), false)
            end
        end)
        button:Show()
        y = y + 44
    end
    page.listChild:SetWidth(width + 8)
    page.listChild:SetHeight(math.max(y, 40))
end

function UI:ShowList()
    local page = UI.page
    local spec = Spec()
    if not page or not spec then
        return
    end
    mode = "list"
    ReleaseHold()
    StopKeyListen()
    keyCollapsed = nil
    draft = nil
    page.editorPage:Hide()
    page.listPage:Show()
    page.heading:SetText(spec.title)
    page.hint:SetText(spec.hint)
    page.emptyButton:SetClick(function()
        UI:NewSet()
    end)
    if page.emptyButton.SetLabel then
        page.emptyButton:SetLabel(spec.emptyLabel or "New")
    end
    RefreshList()
end

function UI:NewSet()
    local api = API()
    local spec = Spec()
    if not api or not spec then
        return
    end
    if not api:Available() then
        Notice(spec.title .. " are not available on this client.", true)
        return
    end
    selectedId = nil
    ShowEditor({
        name = api:SuggestName(),
        slots = {},
        petSlots = {},
        ignored = {},
        bindings = {},
        scope = "account",
    }, true)
end

function UI:SaveDraft()
    local api = API()
    local spec = Spec()
    if not api or not draft or not spec then
        return
    end
    ReleaseHold()
    local name = ReadName(UI.page.nameBox, draft.name or api:SuggestName())
    local saved
    if draft.id then
        saved = api:Update(draft.id, draft, name)
    else
        saved = api:Save(draft, name)
    end
    selectedId = saved and saved.id
    Notice("Saved " .. ((saved and saved.name) or spec.noun) .. ". " .. api:Summary(saved))
    UI:ShowList()
end

function UI:ApplyCurrent()
    local api = API()
    local spec = Spec()
    if not api or not spec then
        return
    end
    local set = draft or api:Get(selectedId)
    if not set then
        Notice("Select a saved " .. spec.noun .. " first.", true)
        return
    end
    local ran, ok, message = pcall(api.Apply, api, set)
    if not ran then
        Notice("Apply could not finish. " .. tostring(ok), true)
        return
    end
    local name = (type(set.name) == "string" and set.name ~= "" and set.name) or spec.noun
    Notice(name .. ": " .. (message or "Apply finished."), ok ~= true)
    if mode == "list" then
        RefreshList()
    end
end

function UI:LoadFromCharacter()
    local api = API()
    if not api or not draft then
        return
    end
    if not api:Available() then
        Notice("This section is not available on this client.", true)
        return
    end
    local live = api:Capture()
    held = nil
    HideHeld()
    draft.slots = live.slots
    draft.petSlots = live.petSlots or {}
    draft.ignored = {}
    draft.bindings = live.bindings
    draft.scope = live.scope
    draft.skipped = live.skipped
    Notice("Updated this snapshot from your character.")
    local spec = Spec()
    if spec and UI.page then
        local detail = spec.detail
        if live.skipped and live.skipped > 0 then
            detail = detail .. " " .. live.skipped .. " entries could not be read on this client."
        end
        UI.page.detail:SetText(detail)
    end
    RefreshEditor()
end

function UI:DeleteSelected()
    local api = API()
    local spec = Spec()
    if not api or not spec then
        return
    end
    if not selectedId then
        Notice("Select a saved " .. spec.noun .. " first.", true)
        return
    end
    api:Delete(selectedId)
    selectedId = nil
    Notice("Deleted.")
    UI:ShowList()
end

function UI:Attach(host)
    if self.page or not host then
        return
    end
    local page = CreateFrame("Frame", nil, host)
    page:SetAllPoints(host)
    page:Hide()
    self.page = page

    local listPage = CreateFrame("Frame", nil, page)
    listPage:SetAllPoints(page)
    page.listPage = listPage

    local heading = listPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -12)
    heading:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    page.heading = heading

    local hint = listPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    hint:SetPoint("RIGHT", listPage, "RIGHT", -16, 0)
    hint:SetJustifyH("LEFT")
    hint:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    page.hint = hint

    local search = CreateFrame("EditBox", nil, listPage, "BackdropTemplate")
    search:SetSize(220, 24)
    search:SetPoint("TOPLEFT", 16, -56)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlight")
    search:SetTextInsets(8, 8, 0, 0)
    Paint(search, { 0.08, 0.08, 0.10, 1 }, BORDER)
    local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchHint:SetPoint("LEFT", 8, 0)
    searchHint:SetText("Search...")
    search:SetScript("OnTextChanged", function(self)
        searchHint:SetShown(self:GetText() == "")
        RefreshList()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    page.search = search

    local listScroll = CreateFrame("ScrollFrame", nil, listPage, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 8, -88)
    listScroll:SetPoint("BOTTOMRIGHT", -28, LIST_BAR_H + 44)
    page.listScroll = listScroll
    local listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(680, 40)
    listScroll:SetScrollChild(listChild)
    page.listChild = listChild

    local emptyButton = GlowButton(listPage, "New Action Bar Set", 180, 36)
    emptyButton:SetPoint("CENTER", listPage, "CENTER", 0, -10)
    emptyButton:SetFrameLevel(listPage:GetFrameLevel() + 5)
    page.emptyButton = emptyButton

    local noMatch = listPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    noMatch:SetPoint("CENTER", listScroll, "CENTER", 0, 0)
    noMatch:SetText("Nothing matches your search.")
    noMatch:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    noMatch:Hide()
    page.noMatch = noMatch

    local notice = listPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    notice:SetPoint("BOTTOMLEFT", listPage, "BOTTOMLEFT", 12, LIST_BAR_H + 6)
    notice:SetPoint("BOTTOMRIGHT", listPage, "BOTTOMRIGHT", -12, LIST_BAR_H + 6)
    notice:SetHeight(36)
    notice:SetJustifyH("LEFT")
    notice:SetJustifyV("MIDDLE")
    notice:SetTextColor(1, 0.82, 0)
    page.notice = notice

    local listBar = CreateFrame("Frame", nil, listPage, "BackdropTemplate")
    listBar:SetPoint("BOTTOMLEFT", listPage, "BOTTOMLEFT", 0, 0)
    listBar:SetPoint("BOTTOMRIGHT", listPage, "BOTTOMRIGHT", 0, 0)
    listBar:SetHeight(LIST_BAR_H)
    Paint(listBar, TITLE_BG, BORDER)
    page.listBar = listBar

    local newButton = GlowButton(listBar, "New", 110, 22)
    newButton:SetPoint("LEFT", 6, 0)
    newButton:SetClick(function()
        UI:NewSet()
    end)
    local deleteButton = BarButton(listBar, "Delete", 80)
    deleteButton:SetPoint("RIGHT", -12, 0)
    deleteButton:SetScript("OnClick", function()
        UI:DeleteSelected()
    end)
    local applyButton = BarButton(listBar, "Apply", 80)
    applyButton:SetPoint("RIGHT", deleteButton, "LEFT", -8, 0)
    applyButton:SetScript("OnClick", function()
        UI:ApplyCurrent()
    end)

    local editorPage = CreateFrame("Frame", nil, page)
    editorPage:SetAllPoints(page)
    editorPage:Hide()
    page.editorPage = editorPage

    local detail = editorPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detail:SetPoint("TOPLEFT", 16, -10)
    detail:SetPoint("RIGHT", editorPage, "RIGHT", -16, 0)
    detail:SetHeight(48)
    detail:SetJustifyH("LEFT")
    detail:SetJustifyV("TOP")
    detail:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    page.detail = detail

    local editorScroll = CreateFrame("ScrollFrame", nil, editorPage, "UIPanelScrollFrameTemplate")
    editorScroll:SetPoint("TOPLEFT", 8, -62)
    editorScroll:SetPoint("BOTTOMRIGHT", -28, EDITOR_BAR_H + 28)
    page.editorScroll = editorScroll
    local editorChild = CreateFrame("Frame", nil, editorScroll)
    editorChild:SetSize(680, 40)
    editorScroll:SetScrollChild(editorChild)
    page.editorChild = editorChild

    local editorNotice = editorPage:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    editorNotice:SetPoint("BOTTOMLEFT", 12, EDITOR_BAR_H + 6)
    editorNotice:SetPoint("BOTTOMRIGHT", -12, EDITOR_BAR_H + 6)
    editorNotice:SetHeight(18)
    editorNotice:SetJustifyH("LEFT")
    editorNotice:SetTextColor(1, 0.82, 0)
    page.editorNotice = editorNotice

    local editorBar = CreateFrame("Frame", nil, editorPage, "BackdropTemplate")
    editorBar:SetPoint("BOTTOMLEFT", 0, 0)
    editorBar:SetPoint("BOTTOMRIGHT", 0, 0)
    editorBar:SetHeight(EDITOR_BAR_H)
    Paint(editorBar, TITLE_BG, BORDER)

    local nameLabel = editorBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameLabel:SetPoint("TOPLEFT", 12, -12)
    nameLabel:SetText("Name")
    nameLabel:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local nameBox = CreateFrame("EditBox", nil, editorBar, "InputBoxTemplate")
    nameBox:SetSize(280, 24)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    nameBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    page.nameBox = nameBox

    local backButton = BarButton(editorBar, "Back", 70)
    backButton:SetPoint("BOTTOMLEFT", 12, 10)
    backButton:SetScript("OnClick", function()
        UI:ShowList()
    end)
    local saveButton = BarButton(editorBar, "Save", 70)
    saveButton:SetPoint("LEFT", backButton, "RIGHT", 8, 0)
    saveButton:SetScript("OnClick", function()
        UI:SaveDraft()
    end)
    local loadButton = BarButton(editorBar, "Update from current character", 230)
    loadButton:SetPoint("LEFT", saveButton, "RIGHT", 8, 0)
    loadButton:SetScript("OnClick", function()
        UI:LoadFromCharacter()
    end)
    local editorApply = BarButton(editorBar, "Apply", 80)
    editorApply:SetPoint("BOTTOMRIGHT", -12, 10)
    editorApply:SetScript("OnClick", function()
        UI:ApplyCurrent()
    end)
end

function UI:SetShown(shown)
    if self.page then
        self.page:SetShown(shown and true or false)
    end
end

function UI:Open(id)
    if not SECTIONS[id] or not self.page then
        return
    end
    sectionId = id
    selectedId = nil
    if self.page.search then
        self.page.search:SetText("")
    end
    self:ShowList()
    Speak(SECTIONS[id].title)
end

function UI:OnWorld()
    if self.page and self.page:IsShown() and mode == "list" then
        RefreshList()
    end
end
