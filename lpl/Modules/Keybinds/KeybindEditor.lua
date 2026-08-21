local addonName, LPL = ...

LPL.KeybindEditor = {}

local HEADER_HEIGHT = 26
local ROW_HEIGHT = 28
local KEY_WIDTH = 150
local SCROLL_BOTTOM_PAD = 12

local IGNORE_KEYS = {
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

local function NormalizeSearch(text)
    if type(text) ~= "string" then
        return ""
    end
    return (text:lower():match("^%s*(.-)%s*$")) or ""
end

local function BindingKeys(draft, command)
    local keys = draft and draft.bindings and draft.bindings[command]
    if type(keys) ~= "table" then
        return nil, nil
    end
    return keys.key1, keys.key2
end

local function MatchesQuery(entry, query)
    if query == "" then
        return true
    end
    if (entry.name or ""):lower():find(query, 1, true) then
        return true
    end
    if (entry.command or ""):lower():find(query, 1, true) then
        return true
    end
    local key1 = LPL.KeybindCodec:FormatKey(entry.key1)
    local key2 = LPL.KeybindCodec:FormatKey(entry.key2)
    if key1:lower():find(query, 1, true) or key2:lower():find(query, 1, true) then
        return true
    end
    return false
end

local function SetExpandIcon(texture, collapsed)
    if not texture then
        return
    end
    if texture.SetAtlas then
        texture:SetAtlas(collapsed and "plus" or "minus")
        return
    end
    texture:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
end

local function AttachKeepHoverTooltip(button, title, body)
    local onEnter = button:GetScript("OnEnter")
    local onLeave = button:GetScript("OnLeave")
    button:SetScript("OnEnter", function(self)
        if onEnter then
            onEnter(self)
        end
        LPL:ShowAccessibleGameTooltip(self, title, body)
    end)
    button:SetScript("OnLeave", function(self)
        if onLeave then
            onLeave(self)
        end
        LPL:ClearGameTooltipData(GameTooltip)
    end)
end

function LPL.KeybindEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetAllPoints(parent)
    LPL.Theme:ApplyBackdrop(frame, "panel", "bgPrimary", "border")
    frame.draft = nil
    frame.searchText = ""
    frame.boundOnly = false
    frame.collapsed = {}
    frame.rows = {}
    frame.filtered = {}
    frame.listening = nil

    local footerHeight = LPL.TalentActionBar and LPL.TalentActionBar.TREE_HEIGHT or 84

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -12)
    title:SetText("Keybinding Profile")
    title:SetTextColor(LPL.Theme:GetColor("textBright"))

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")
    status:SetWordWrap(false)
    if status.SetMaxLines then
        status:SetMaxLines(1)
    end
    status:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    frame.statusLabel = status

    local scopeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scopeLabel:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10)
    scopeLabel:SetText("Scope")
    scopeLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))

    local accountButton = LPL:CreateButton(nil, frame)
    accountButton:SetSize(110, 28)
    accountButton:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", 0, -8)
    accountButton:SetText("Account")
    AttachKeepHoverTooltip(accountButton, "Account scope", "Activate writes this profile to account-wide key bindings. Other characters on this WoW account pick it up unless they use Character-specific key bindings.")

    local characterButton = LPL:CreateButton(nil, frame)
    characterButton:SetSize(110, 28)
    characterButton:SetPoint("LEFT", accountButton, "RIGHT", 8, 0)
    characterButton:SetText("Character")
    AttachKeepHoverTooltip(characterButton, "Character scope", "Activate writes this profile only for this character.")

    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("LEFT", characterButton, "RIGHT", 16, 0)
    searchLabel:SetText("Search")
    searchLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetSize(180, 24)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local boundOnly = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    boundOnly:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)
    boundOnly:SetSize(24, 24)
    local boundOnlyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    boundOnlyLabel:SetPoint("LEFT", boundOnly, "RIGHT", 2, 0)
    boundOnlyLabel:SetText("Bound only")
    boundOnlyLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))

    local expandAll = LPL:CreateButton(nil, frame)
    expandAll:SetSize(110, 24)
    expandAll:SetPoint("TOPLEFT", accountButton, "BOTTOMLEFT", 0, -10)
    expandAll:SetText("Expand All")

    local collapseAll = LPL:CreateButton(nil, frame)
    collapseAll:SetSize(110, 24)
    collapseAll:SetPoint("LEFT", expandAll, "RIGHT", 8, 0)
    collapseAll:SetText("Collapse All")

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("LEFT", collapseAll, "RIGHT", 12, 0)
    hint:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("MIDDLE")
    hint:SetWordWrap(false)
    if hint.SetMaxLines then
        hint:SetMaxLines(1)
    end
    hint:SetTextColor(LPL.Theme:GetColor("textMuted"))
    hint:SetText("Categories start collapsed. Click a header to expand, then click a key slot and press a key. Right-click or Esc clears. Activate to apply.")

    local listHost = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listHost:SetPoint("TOPLEFT", expandAll, "BOTTOMLEFT", 0, -8)
    listHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, footerHeight + 8)
    LPL.Theme:ApplyBackdrop(listHost, "panel", "actionBarSlotBg", "border")

    local scroll = CreateFrame("ScrollFrame", nil, listHost, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listHost, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", listHost, "BOTTOMRIGHT", -28, 8)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    content:EnableMouse(true)
    scroll:SetScrollChild(content)

    local emptyListLabel = listHost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyListLabel:SetPoint("CENTER", listHost, "CENTER", -10, 0)
    emptyListLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    emptyListLabel:SetText("No keybinds match your search or filters.")
    emptyListLabel:Hide()

    local capture = CreateFrame("Button", "LPLKeybindCaptureOverlay", UIParent)
    capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:SetAllPoints(UIParent)
    capture:EnableMouse(true)
    capture:EnableMouseWheel(true)
    capture:Hide()
    capture:RegisterForClicks("AnyUp")
    local captureDim = capture:CreateTexture(nil, "BACKGROUND")
    captureDim:SetAllPoints(capture)
    captureDim:SetColorTexture(0, 0, 0, 0.35)
    local captureLabel = capture:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    captureLabel:SetPoint("CENTER", capture, "CENTER", 0, 40)
    captureLabel:SetTextColor(LPL.Theme:GetColor("textBright"))
    captureLabel:SetText("Press a key, mouse button, or mouse wheel")
    local captureHint = capture:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    captureHint:SetPoint("TOP", captureLabel, "BOTTOM", 0, -8)
    captureHint:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    captureHint:SetText("Esc clears this slot · Click to cancel")

    frame.accountButton = accountButton
    frame.characterButton = characterButton
    frame.searchBox = searchBox
    frame.boundOnlyBox = boundOnly
    frame.scroll = scroll
    frame.content = content
    frame.listHost = listHost
    frame.emptyListLabel = emptyListLabel
    frame.capture = capture

    local function RefreshScopeButtons()
        local scope = frame.draft and frame.draft.scope or LPL.KeybindStore.SCOPE_ACCOUNT
        if scope == LPL.KeybindStore.SCOPE_CHARACTER then
            LPL.Theme:ApplyBackdrop(characterButton, "button", "tabActive", "borderActive")
            LPL.Theme:ClearBackdrop(accountButton)
        else
            LPL.Theme:ApplyBackdrop(accountButton, "button", "tabActive", "borderActive")
            LPL.Theme:ClearBackdrop(characterButton)
        end
    end

    local function RefreshStatus()
        if not frame.draft then
            frame.statusLabel:SetText("No profile loaded.")
            return
        end
        local extra = frame.listening and "  ·  Waiting for input..." or ""
        frame.statusLabel:SetText(LPL.KeybindStore:GetSummaryLine(frame.draft) .. extra)
    end

    local function StopListening()
        frame.listening = nil
        if capture:IsShown() then
            capture:Hide()
        end
        if capture.EnableKeyboard then
            capture:EnableKeyboard(false)
        end
        RefreshStatus()
        if frame.RebuildList then
            frame:RebuildList()
        end
    end

    local function ApplyCapturedKey(key)
        local listening = frame.listening
        if not listening or not frame.draft then
            StopListening()
            return
        end
        frame.draft.bindings = LPL.KeybindCodec:AssignDraftKey(
            frame.draft.bindings,
            listening.command,
            listening.slot,
            key
        )
        StopListening()
    end

    local function StartListening(command, slot)
        if not command then
            return
        end
        frame.listening = { command = command, slot = slot }
        capture:Show()
        capture:Raise()
        if capture.EnableKeyboard then
            capture:EnableKeyboard(true)
        end
        if capture.SetPropagateKeyboardInput then
            capture:SetPropagateKeyboardInput(false)
        end
        RefreshStatus()
        frame:RebuildList()
    end

    local function BuildFiltered()
        wipe(frame.filtered)
        if not frame.draft then
            return
        end

        local query = NormalizeSearch(frame.searchText)
        local forceExpand = query ~= ""
        local catalog = LPL.KeybindCodec:GetCatalog()
        local seen = {}

        local function AddCommand(sectionHeader, name, command)
            seen[command] = true
            local key1, key2 = BindingKeys(frame.draft, command)
            local bound = (key1 and key1 ~= "") or (key2 and key2 ~= "")
            if frame.boundOnly and not bound then
                return nil
            end
            local entry = {
                kind = "command",
                header = sectionHeader,
                name = name or LPL.KeybindCodec:GetCommandDisplayName(command),
                command = command,
                key1 = key1,
                key2 = key2,
            }
            if not MatchesQuery(entry, query) then
                return nil
            end
            return entry
        end

        for _, section in ipairs(catalog) do
            local visible = {}
            for _, cmd in ipairs(section.commands) do
                local entry = AddCommand(section.header, cmd.name, cmd.command)
                if entry then
                    visible[#visible + 1] = entry
                end
            end
            if #visible > 0 then
                frame.filtered[#frame.filtered + 1] = {
                    kind = "header",
                    header = section.header,
                    title = section.title,
                    count = #visible,
                }
                if forceExpand or not frame.collapsed[section.header] then
                    for _, entry in ipairs(visible) do
                        frame.filtered[#frame.filtered + 1] = entry
                    end
                end
            end
        end

        local leftover = {}
        for command in pairs(frame.draft.bindings or {}) do
            if not seen[command] then
                local entry = AddCommand("BINDING_HEADER_OTHER", nil, command)
                if entry then
                    leftover[#leftover + 1] = entry
                end
            end
        end
        if #leftover > 0 then
            table.sort(leftover, function(a, b)
                return (a.name or "") < (b.name or "")
            end)
            local header = "LPL_UNLISTED"
            frame.filtered[#frame.filtered + 1] = {
                kind = "header",
                header = header,
                title = "Other",
                count = #leftover,
            }
            if forceExpand or not frame.collapsed[header] then
                for _, entry in ipairs(leftover) do
                    frame.filtered[#frame.filtered + 1] = entry
                end
            end
        end
    end

    local function ClampScroll()
        if not scroll.GetVerticalScroll or not scroll.SetVerticalScroll then
            return
        end
        local maxScroll = 0
        if scroll.GetVerticalScrollRange then
            maxScroll = scroll:GetVerticalScrollRange() or 0
        end
        local current = scroll:GetVerticalScroll() or 0
        if current < 0 then
            scroll:SetVerticalScroll(0)
        elseif current > maxScroll then
            scroll:SetVerticalScroll(maxScroll)
        end
    end

    local function LayoutRows()
        local width = scroll:GetWidth() or 400
        if width < 40 then
            width = 400
        end
        content:SetWidth(width)

        local y = 0
        local shown = 0
        for index, entry in ipairs(frame.filtered) do
            local row = frame.rows[index]
            if row then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
                row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
                local height = entry.kind == "header" and HEADER_HEIGHT or ROW_HEIGHT
                row:SetHeight(height)
                y = y + height
                shown = shown + 1
            end
        end
        for index = shown + 1, #frame.rows do
            frame.rows[index]:Hide()
        end
        content:SetHeight(math.max(y + SCROLL_BOTTOM_PAD, 1))
        if scroll.UpdateScrollChildRect then
            scroll:UpdateScrollChildRect()
        end
        ClampScroll()
        emptyListLabel:SetShown(shown == 0)
    end

    local function RefreshRow(row, entry)
        row.entry = entry
        if not entry then
            row:Hide()
            return
        end
        row:Show()
        local isHeader = entry.kind == "header"
        row.expandIcon:SetShown(isHeader)
        row.headerLabel:SetShown(isHeader)
        row.nameLabel:SetShown(not isHeader)
        row.key1:SetShown(not isHeader)
        row.key2:SetShown(not isHeader)

        if isHeader then
            local collapsed = frame.collapsed[entry.header] and NormalizeSearch(frame.searchText) == ""
            SetExpandIcon(row.expandIcon, collapsed)
            row.headerLabel:SetText(string.format("%s  (%d)", entry.title or "Other", entry.count or 0))
            LPL.Theme:ApplyListHeaderBackdrop(row)
            return
        end

        LPL.Theme:ClearListHeaderBackdrop(row)

        row.nameLabel:SetText(entry.name or entry.command)
        local listening = frame.listening
        local function PaintKey(button, slot, key)
            local waiting = listening and listening.command == entry.command and listening.slot == slot
            if waiting then
                button:SetText("...")
            else
                button:SetText(LPL.KeybindCodec:FormatKey(key))
            end
        end
        PaintKey(row.key1, 1, entry.key1)
        PaintKey(row.key2, 2, entry.key2)
    end

    local function EnsureRows(count)
        while #frame.rows < count do
            local row = CreateFrame("Button", nil, content, "BackdropTemplate")
            row:SetHeight(ROW_HEIGHT)
            row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta)
                if frame.listening then
                    return
                end
                local handler = scroll:GetScript("OnMouseWheel")
                if handler then
                    handler(scroll, delta)
                end
            end)

            local expand = row:CreateTexture(nil, "ARTWORK")
            expand:SetSize(12, 12)
            expand:SetPoint("LEFT", row, "LEFT", 6, 0)
            SetExpandIcon(expand, false)
            row.expandIcon = expand

            local headerLabel = row:CreateFontString(nil, "OVERLAY")
            headerLabel:SetFontObject(LPL.Theme.fonts.bodyBold)
            headerLabel:SetPoint("LEFT", expand, "RIGHT", 6, 0)
            headerLabel:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            headerLabel:SetJustifyH("LEFT")
            headerLabel:SetTextColor(LPL.Theme:GetColor("textBright"))
            row.headerLabel = headerLabel

            local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            nameLabel:SetPoint("LEFT", row, "LEFT", 8, 0)
            nameLabel:SetPoint("RIGHT", row, "RIGHT", -(KEY_WIDTH * 2 + 20), 0)
            nameLabel:SetJustifyH("LEFT")
            nameLabel:SetTextColor(LPL.Theme:GetColor("textBright"))
            row.nameLabel = nameLabel

            local key2 = LPL:CreateButton(nil, row)
            key2:SetSize(KEY_WIDTH, 22)
            key2:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            key2:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.key2 = key2

            local key1 = LPL:CreateButton(nil, row)
            key1:SetSize(KEY_WIDTH, 22)
            key1:SetPoint("RIGHT", key2, "LEFT", -8, 0)
            key1:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            row.key1 = key1

            local function OnKeyClick(slot, button)
                local entry = row.entry
                if not entry or entry.kind ~= "command" or not frame.draft then
                    return
                end
                if button == "RightButton" then
                    frame.draft.bindings = LPL.KeybindCodec:AssignDraftKey(frame.draft.bindings, entry.command, slot, nil)
                    StopListening()
                    return
                end
                if frame.listening and frame.listening.command == entry.command and frame.listening.slot == slot then
                    StopListening()
                    return
                end
                StartListening(entry.command, slot)
            end

            key1:SetScript("OnClick", function(_, button)
                OnKeyClick(1, button)
            end)
            key2:SetScript("OnClick", function(_, button)
                OnKeyClick(2, button)
            end)

            row:SetScript("OnClick", function()
                local entry = row.entry
                if not entry or entry.kind ~= "header" then
                    return
                end
                if frame.collapsed[entry.header] then
                    frame.collapsed[entry.header] = nil
                else
                    frame.collapsed[entry.header] = true
                end
                frame:RebuildList()
            end)

            frame.rows[#frame.rows + 1] = row
        end
    end

    function frame:RebuildList()
        BuildFiltered()
        EnsureRows(#frame.filtered)
        for index, entry in ipairs(frame.filtered) do
            RefreshRow(frame.rows[index], entry)
        end
        LayoutRows()
        RefreshStatus()
    end

    local function SetScope(scope)
        if not frame.draft then
            return
        end
        frame.draft.scope = LPL.KeybindStore:NormalizeScope(scope)
        RefreshScopeButtons()
        RefreshStatus()
    end

    accountButton:SetScript("OnClick", function()
        SetScope(LPL.KeybindStore.SCOPE_ACCOUNT)
    end)
    characterButton:SetScript("OnClick", function()
        SetScope(LPL.KeybindStore.SCOPE_CHARACTER)
    end)

    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then
            return
        end
        frame.searchText = self:GetText() or ""
        frame:RebuildList()
    end)

    boundOnly:SetScript("OnClick", function(self)
        frame.boundOnly = self:GetChecked() == true
        frame:RebuildList()
    end)

    expandAll:SetScript("OnClick", function()
        wipe(frame.collapsed)
        frame:RebuildList()
    end)
    collapseAll:SetScript("OnClick", function()
        wipe(frame.collapsed)
        for _, entry in ipairs(frame.filtered) do
            if entry.kind == "header" then
                frame.collapsed[entry.header] = true
            end
        end
        -- Collapse currently visible headers; rebuild to hide their commands.
        local headers = {}
        for _, entry in ipairs(LPL.KeybindCodec:GetCatalog()) do
            headers[entry.header] = true
        end
        headers.LPL_UNLISTED = true
        for header in pairs(headers) do
            frame.collapsed[header] = true
        end
        frame:RebuildList()
    end)

    scroll:HookScript("OnSizeChanged", function()
        LayoutRows()
    end)

    capture:SetScript("OnKeyDown", function(_, key)
        if not frame.listening then
            return
        end
        if IGNORE_KEYS[key] then
            return
        end
        if key == "ESCAPE" then
            ApplyCapturedKey(nil)
            return
        end
        local keyPressed = key
        if IsShiftKeyDown and IsShiftKeyDown() then
            keyPressed = "SHIFT-" .. keyPressed
        end
        if IsControlKeyDown and IsControlKeyDown() then
            keyPressed = "CTRL-" .. keyPressed
        end
        if IsAltKeyDown and IsAltKeyDown() then
            keyPressed = "ALT-" .. keyPressed
        end
        ApplyCapturedKey(keyPressed)
    end)

    capture:SetScript("OnMouseDown", function(_, button)
        if not frame.listening then
            return
        end
        if button == "LeftButton" or button == "RightButton" then
            StopListening()
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
        local keyPressed = key
        if IsShiftKeyDown and IsShiftKeyDown() then
            keyPressed = "SHIFT-" .. keyPressed
        end
        if IsControlKeyDown and IsControlKeyDown() then
            keyPressed = "CTRL-" .. keyPressed
        end
        if IsAltKeyDown and IsAltKeyDown() then
            keyPressed = "ALT-" .. keyPressed
        end
        ApplyCapturedKey(keyPressed)
    end)

    capture:SetScript("OnMouseWheel", function(_, delta)
        if not frame.listening then
            return
        end
        local key = (delta and delta >= 0) and "MOUSEWHEELUP" or "MOUSEWHEELDOWN"
        local keyPressed = key
        if IsShiftKeyDown and IsShiftKeyDown() then
            keyPressed = "SHIFT-" .. keyPressed
        end
        if IsControlKeyDown and IsControlKeyDown() then
            keyPressed = "CTRL-" .. keyPressed
        end
        if IsAltKeyDown and IsAltKeyDown() then
            keyPressed = "ALT-" .. keyPressed
        end
        ApplyCapturedKey(keyPressed)
    end)

    capture:SetScript("OnShow", function(self)
        if self.EnableKeyboard then
            self:EnableKeyboard(true)
        end
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end
    end)

    capture:SetScript("OnHide", function()
        if capture.EnableKeyboard then
            capture:EnableKeyboard(false)
        end
    end)

    local function CollapseAllHeaders()
        wipe(frame.collapsed)
        for _, section in ipairs(LPL.KeybindCodec:GetCatalog()) do
            if section.header then
                frame.collapsed[section.header] = true
            end
        end
        frame.collapsed.LPL_UNLISTED = true
    end

    function frame:SetDraft(draft)
        StopListening()
        self.draft = draft
        self.searchText = ""
        self.boundOnly = false
        CollapseAllHeaders()
        self.searchBox:SetText("")
        self.boundOnlyBox:SetChecked(false)
        if self.draft then
            self.draft.scope = LPL.KeybindStore:NormalizeScope(self.draft.scope)
            self.draft.bindings = LPL.KeybindStore:NormalizeBindings(self.draft.bindings)
        end
        RefreshScopeButtons()
        self:RebuildList()
    end

    function frame:GetDraft()
        return self.draft
    end

    function frame:Refresh()
        RefreshScopeButtons()
        self:RebuildList()
    end

    function frame:UpdateFromLive()
        if not self.draft then
            return
        end
        StopListening()
        self.draft.bindings = LPL.KeybindStore:CaptureLiveBindings()
        self:RebuildList()
        local count = LPL.KeybindStore:CountAssignedBindings(self.draft.bindings)
        print(string.format(
            "|cff33cc33LPL:|r Updated profile from live keybinds (%d bound).",
            count
        ))
    end

    function frame:StopListening()
        StopListening()
    end

    frame.RefreshScopeButtons = RefreshScopeButtons
    return frame
end

function LPL.KeybindEditor:Destroy(frame)
    if frame then
        if frame.StopListening then
            frame:StopListening()
        end
        if frame.capture then
            frame.capture:Hide()
            frame.capture:SetParent(nil)
        end
        frame:Hide()
        frame:SetParent(nil)
    end
end
