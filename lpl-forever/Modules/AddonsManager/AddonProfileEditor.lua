local addonName, LPL = ...

LPL.AddonProfileEditor = {}

local function FormatByteSize(bytes)
    bytes = tonumber(bytes) or 0
    if bytes >= 1024 * 1024 then
        return string.format("%.2f MB", bytes / (1024 * 1024))
    end
    if bytes >= 1024 then
        return string.format("%.1f KB", bytes / 1024)
    end
    return string.format("%d characters", bytes)
end

local function DisableFontStringMouse(fontString)
    if fontString and fontString.SetMouseClickEnabled then
        fontString:SetMouseClickEnabled(false)
    end
end

local function CreatePasteInput(parent)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    LPL.Theme:ApplyBackdrop(container, "panel", "bgElevated", "border")
    container:EnableMouse(true)
    container:SetClipsChildren(true)

    local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -26, 8)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(LPL.Theme.fonts.body)
    editBox:SetTextColor(LPL.Theme:GetColor("textBright"))
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    editBox:SetFrameLevel(scroll:GetFrameLevel() + 5)
    -- Profile strings can be large; no hard cap (soft-warn lives in the editor).
    if editBox.SetMaxLetters then
        editBox:SetMaxLetters(0)
    end
    scroll:SetScrollChild(editBox)

    local function UpdateEditBoxLayout()
        local width = scroll:GetWidth()
        if not width or width < 40 then
            return
        end
        editBox:SetWidth(width)
        local fontHeight = select(2, editBox:GetFont()) or 12
        local lineCount = editBox:GetNumLines() or 1
        local contentHeight = math.max(lineCount * fontHeight + 16, scroll:GetHeight())
        editBox:SetHeight(contentHeight)
        scroll:UpdateScrollChildRect()
    end

    scroll:HookScript("OnSizeChanged", UpdateEditBoxLayout)
    editBox:HookScript("OnTextChanged", function(self, userInput)
        UpdateEditBoxLayout()
        if container.onTextChanged then
            container.onTextChanged(self:GetText() or "", userInput == true)
        end
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    editBox:SetScript("OnCursorChanged", function(_, _, y, _, cursorHeight)
        local fontHeight = select(2, editBox:GetFont()) or 12
        local scrollTop = scroll:GetVerticalScroll()
        local scrollHeight = scroll:GetHeight()
        local cursorOffset = math.abs(y or 0)
        local cursorBottom = cursorOffset + (cursorHeight or fontHeight)

        if cursorBottom > scrollTop + scrollHeight then
            scroll:SetVerticalScroll(cursorBottom - scrollHeight)
        elseif cursorOffset < scrollTop then
            scroll:SetVerticalScroll(cursorOffset)
        end
    end)

    local function FocusEditBox()
        editBox:SetFocus()
    end

    container:SetScript("OnMouseDown", FocusEditBox)
    scroll:SetScript("OnMouseDown", FocusEditBox)
    editBox:SetScript("OnMouseDown", FocusEditBox)

    function container:GetText()
        return editBox:GetText() or ""
    end

    function container:SetText(text)
        editBox:SetText(text or "")
        UpdateEditBoxLayout()
        scroll:SetVerticalScroll(0)
    end

    function container:ClearFocus()
        editBox:ClearFocus()
    end

    function container:Focus()
        editBox:SetFocus()
    end

    container.scroll = scroll
    container.editBox = editBox
    container.UpdateEditBoxLayout = UpdateEditBoxLayout
    return container
end

function LPL.AddonProfileEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:EnableMouse(false)
    frame.draft = nil
    frame.suppressDetect = false

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
    title:SetText("Addon Profile")
    title:SetTextColor(LPL.Theme:GetColor("textBright"))
    DisableFontStringMouse(title)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    status:SetJustifyH("LEFT")
    status:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    DisableFontStringMouse(status)
    frame.statusLabel = status

    local addonDrop = LPL:CreateDropdown(nil, frame, 180)
    addonDrop:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10)
    addonDrop:SetLabel("Addon")
    frame.addonDrop = addonDrop

    local customLabelTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    customLabelTitle:SetPoint("TOPLEFT", addonDrop, "TOPRIGHT", 16, 0)
    customLabelTitle:SetText("Custom name")
    customLabelTitle:SetTextColor(LPL.Theme:GetColor("textLabel"))
    DisableFontStringMouse(customLabelTitle)
    frame.customLabelTitle = customLabelTitle

    local customLabelBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    customLabelBox:SetAutoFocus(false)
    customLabelBox:SetSize(180, 24)
    customLabelBox:SetPoint("TOPLEFT", customLabelTitle, "BOTTOMLEFT", 0, -4)
    customLabelBox:SetMaxLetters(60)
    frame.customLabelBox = customLabelBox

    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", addonDrop, "BOTTOMLEFT", 0, -10)
    instructions:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    instructions:SetJustifyH("LEFT")
    instructions:SetWordWrap(true)
    instructions:SetTextColor(LPL.Theme:GetColor("textMuted"))
    DisableFontStringMouse(instructions)
    frame.instructionsLabel = instructions

    local pasteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pasteLabel:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 0, -14)
    pasteLabel:SetText("Profile string")
    pasteLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))
    DisableFontStringMouse(pasteLabel)

    local sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("LEFT", pasteLabel, "RIGHT", 12, 0)
    sizeLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    DisableFontStringMouse(sizeLabel)
    frame.sizeLabel = sizeLabel

    local warnLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warnLabel:SetPoint("LEFT", sizeLabel, "RIGHT", 12, 0)
    warnLabel:SetTextColor(1, 0.55, 0.2)
    DisableFontStringMouse(warnLabel)
    warnLabel:Hide()
    frame.warnLabel = warnLabel

    local pasteInput = CreatePasteInput(frame)
    pasteInput:SetPoint("TOPLEFT", pasteLabel, "BOTTOMLEFT", 0, -8)
    pasteInput:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
    frame.pasteInput = pasteInput

    local function SyncDraftFromUI()
        if not frame.draft then
            return
        end
        frame.draft.addonKey = frame.draft.addonKey or "custom"
        if frame.draft.addonKey == "custom" then
            local custom = customLabelBox:GetText() or ""
            custom = custom:match("^%s*(.-)%s*$") or ""
            frame.draft.addonLabel = custom
        end
        frame.draft.profileString = pasteInput:GetText() or ""
    end

    local function RefreshCustomVisibility()
        local isCustom = (frame.draft and frame.draft.addonKey or "custom") == "custom"
        customLabelTitle:SetShown(isCustom)
        customLabelBox:SetShown(isCustom)
        if isCustom then
            customLabelBox:SetText((frame.draft and frame.draft.addonLabel) or "")
        end
    end

    local function RefreshInstructions()
        local key = frame.draft and frame.draft.addonKey or "custom"
        frame.instructionsLabel:SetText(LPL.AddonCatalog:GetInstructions(key))
    end

    local function RefreshSize()
        local text = pasteInput:GetText() or ""
        local bytes = #text
        frame.sizeLabel:SetText(FormatByteSize(bytes))
        local soft = LPL.AddonProfileStore.SOFT_WARN_BYTES or (128 * 1024)
        if bytes >= soft then
            frame.warnLabel:SetText(string.format("Large string (%s) — SavedVariables may grow.", FormatByteSize(bytes)))
            frame.warnLabel:Show()
            frame.sizeLabel:SetTextColor(1, 0.55, 0.2)
        else
            frame.warnLabel:Hide()
            frame.sizeLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
        end
    end

    local function RefreshStatus()
        if not frame.draft then
            frame.statusLabel:SetText("No draft.")
            return
        end
        SyncDraftFromUI()
        frame.statusLabel:SetText(LPL.AddonProfileStore:GetSummaryLine(frame.draft))
    end

    local function ApplyAddonKey(key, fromDetect)
        if not frame.draft then
            return
        end
        key = key or "custom"
        frame.draft.addonKey = key
        if key ~= "custom" then
            frame.draft.addonLabel = ""
        end
        frame.suppressDetect = true
        addonDrop:SetItems(LPL.AddonCatalog:GetDropdownItems(), key, function(id)
            ApplyAddonKey(id or "custom", false)
        end)
        frame.suppressDetect = false
        RefreshCustomVisibility()
        RefreshInstructions()
        RefreshStatus()
        if fromDetect and key ~= "custom" then
            local label = LPL.AddonCatalog:GetLabel(key)
            frame.statusLabel:SetText(string.format("Detected %s · %s", label, LPL.AddonProfileStore:GetSummaryLine(frame.draft)))
        end
    end

    customLabelBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput and frame.draft then
            SyncDraftFromUI()
            RefreshStatus()
        end
    end)

    pasteInput.onTextChanged = function(text, userInput)
        if not frame.draft then
            return
        end
        frame.draft.profileString = text or ""
        RefreshSize()
        if userInput and not frame.suppressDetect and text ~= "" then
            local detected = LPL.AddonCatalog:Detect(text)
            if detected and detected ~= "custom" and detected ~= frame.draft.addonKey then
                ApplyAddonKey(detected, true)
                return
            end
        end
        RefreshStatus()
    end

    function frame:Refresh()
        if not self.draft then
            return
        end
        self.draft.addonKey = self.draft.addonKey or "custom"
        self.draft.addonLabel = self.draft.addonLabel or ""
        self.draft.profileString = self.draft.profileString or ""

        self.suppressDetect = true
        addonDrop:SetItems(LPL.AddonCatalog:GetDropdownItems(), self.draft.addonKey, function(id)
            ApplyAddonKey(id or "custom", false)
        end)
        customLabelBox:SetText(self.draft.addonLabel or "")
        pasteInput:SetText(self.draft.profileString or "")
        self.suppressDetect = false

        RefreshCustomVisibility()
        RefreshInstructions()
        RefreshSize()
        RefreshStatus()
        if pasteInput.UpdateEditBoxLayout then
            pasteInput:UpdateEditBoxLayout()
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if pasteInput and pasteInput.UpdateEditBoxLayout then
                    pasteInput:UpdateEditBoxLayout()
                end
            end)
        end
    end

    function frame:SetDraft(draft)
        self.draft = draft
        self:Refresh()
    end

    function frame:GetDraft()
        SyncDraftFromUI()
        return self.draft
    end

    return frame
end

function LPL.AddonProfileEditor:Destroy(editor)
    if not editor then
        return
    end
    editor:Hide()
    editor:SetParent(nil)
end
