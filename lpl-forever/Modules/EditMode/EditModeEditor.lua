local addonName, LPL = ...

LPL.EditModeEditor = {}

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

local function CreateLayoutInput(parent)
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
    editBox:SetMaxLetters(0)
    editBox:SetFontObject(LPL.Theme.fonts.body)
    editBox:SetTextColor(LPL.Theme:GetColor("textBright"))
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
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

    container.scroll = scroll
    container.editBox = editBox
    container.UpdateEditBoxLayout = UpdateEditBoxLayout
    return container
end

function LPL.EditModeEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.draftSet = nil
    frame.suppressTextChanged = false

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
    title:SetText("Edit Mode Layout")
    title:SetTextColor(LPL.Theme:GetColor("textBright"))

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    status:SetJustifyH("LEFT")
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
    AttachKeepHoverTooltip(
        accountButton,
        "Account scope",
        "Activate writes this as an account-wide Edit Mode layout. Other characters on this WoW account can use it."
    )

    local characterButton = LPL:CreateButton(nil, frame)
    characterButton:SetSize(110, 28)
    characterButton:SetPoint("LEFT", accountButton, "RIGHT", 8, 0)
    characterButton:SetText("Character")
    AttachKeepHoverTooltip(
        characterButton,
        "Character scope",
        "Activate writes this as a character-specific Edit Mode layout for this character only."
    )

    frame.accountButton = accountButton
    frame.characterButton = characterButton

    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", accountButton, "BOTTOMLEFT", 0, -10)
    hint:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Paste a Blizzard Edit Mode string, or use Update to copy from your active layout.")
    hint:SetTextColor(LPL.Theme:GetColor("textMuted"))

    local input = CreateLayoutInput(frame)
    input:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
    input:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    frame.input = input

    local function RefreshScopeButtons()
        local characterSpecific = not frame.draftSet or frame.draftSet.editModeCharacterSpecific ~= false
        if characterSpecific then
            LPL.Theme:ApplyBackdrop(characterButton, "button", "tabActive", "borderActive")
            LPL.Theme:ClearBackdrop(accountButton)
        else
            LPL.Theme:ApplyBackdrop(accountButton, "button", "tabActive", "borderActive")
            LPL.Theme:ClearBackdrop(characterButton)
        end
    end

    local function SetCharacterSpecific(characterSpecific)
        if not frame.draftSet then
            return
        end
        frame.draftSet.editModeCharacterSpecific = characterSpecific ~= false
        RefreshScopeButtons()
        frame:RefreshStatus()
    end

    accountButton:SetScript("OnClick", function()
        SetCharacterSpecific(false)
    end)
    characterButton:SetScript("OnClick", function()
        SetCharacterSpecific(true)
    end)

    input.onTextChanged = function(text, userInput)
        if frame.suppressTextChanged or not frame.draftSet then
            return
        end
        if userInput then
            frame.draftSet.layoutString = LPL.EditModeCodec:NormalizeLayoutString(text)
            frame:RefreshStatus()
        end
    end

    function frame:RefreshStatus()
        local layout = self.draftSet and self.draftSet.layoutString or ""
        layout = LPL.EditModeCodec:NormalizeLayoutString(layout)
        if layout == "" then
            self.statusLabel:SetText("Empty layout — paste a string or Update from your character.")
        else
            local scope = (self.draftSet and self.draftSet.editModeCharacterSpecific ~= false) and "Character" or "Account"
            self.statusLabel:SetText(string.format("%s layout ready (%d characters).", scope, #layout))
        end
    end

    function frame:SyncDraftFromInput()
        if not self.draftSet then
            return
        end
        self.draftSet.layoutString = LPL.EditModeCodec:NormalizeLayoutString(self.input:GetText())
        LPL.EditModeCodec:SanitizeDraft(self.draftSet)
        RefreshScopeButtons()
        self:RefreshStatus()
    end

    function frame:Refresh()
        if not self.draftSet then
            return
        end
        LPL.EditModeCodec:SanitizeDraft(self.draftSet)
        self.suppressTextChanged = true
        self.input:SetText(self.draftSet.layoutString or "")
        self.suppressTextChanged = false
        RefreshScopeButtons()
        self:RefreshStatus()
        if self.input.UpdateEditBoxLayout then
            self.input:UpdateEditBoxLayout()
        end
    end

    function frame:SetDraftSet(draft)
        self.draftSet = draft
        self:Refresh()
    end

    frame.RefreshScopeButtons = RefreshScopeButtons
    RefreshScopeButtons()

    return frame
end

function LPL.EditModeEditor:Destroy(editor)
    if not editor then
        return
    end
    if editor.input and editor.input.ClearFocus then
        editor.input:ClearFocus()
    end
    editor:Hide()
    editor:SetParent(nil)
end
