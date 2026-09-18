local addonName, LPL = ...

LPL.MacroEditor = {}

-- Plain multiline EditBox (no ScrollFrame). Macros are capped at 255 chars,
-- and ScrollFrame scroll-children frequently fail click-to-focus in retail.
local function CreateBodyInput(parent, maxLetters)
    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    LPL.Theme:ApplyBackdrop(container, "panel", "bgElevated", "border")
    container:EnableMouse(true)

    local editBox = CreateFrame("EditBox", nil, container)
    editBox:SetPoint("TOPLEFT", container, "TOPLEFT", 10, -10)
    editBox:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -10, 10)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(maxLetters or 255)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetTextColor(LPL.Theme:GetColor("textBright"))
    editBox:SetTextInsets(4, 4, 4, 4)
    editBox:SetJustifyH("LEFT")
    editBox:SetJustifyV("TOP")
    editBox:EnableMouse(true)
    editBox:EnableKeyboard(true)
    editBox:SetFrameLevel(container:GetFrameLevel() + 5)

    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    editBox:SetScript("OnTextChanged", function(self, userInput)
        if container.onTextChanged then
            container.onTextChanged(self:GetText() or "", userInput == true)
        end
    end)

    -- Click empty padding around the text to focus.
    container:SetScript("OnMouseDown", function()
        editBox:SetFocus()
    end)

    function container:GetText()
        return editBox:GetText() or ""
    end

    function container:SetText(text)
        editBox:SetText(text or "")
    end

    function container:ClearFocus()
        editBox:ClearFocus()
    end

    function container:Focus()
        editBox:SetFocus()
    end

    container.editBox = editBox
    return container
end

function LPL.MacroEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:EnableMouse(false)
    frame.draft = nil

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
    title:SetText("Macro")
    title:SetTextColor(LPL.Theme:GetColor("textBright"))

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    status:SetJustifyH("LEFT")
    status:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    if status.SetMouseClickEnabled then
        status:SetMouseClickEnabled(false)
    end
    frame.statusLabel = status

    local iconButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    iconButton:SetSize(48, 48)
    iconButton:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -14)
    LPL.Theme:ApplyBackdrop(iconButton, "button", "bgElevated", "border")
    local iconTex = iconButton:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", iconButton, "TOPLEFT", 4, -4)
    iconTex:SetPoint("BOTTOMRIGHT", iconButton, "BOTTOMRIGHT", -4, 4)
    frame.iconTex = iconTex
    frame.iconButton = iconButton

    local changeIcon = LPL:CreateButton(nil, frame)
    changeIcon:SetSize(110, 28)
    changeIcon:SetPoint("LEFT", iconButton, "RIGHT", 12, 8)
    changeIcon:SetText("Change Icon")

    local loadButton = LPL:CreateButton(nil, frame)
    loadButton:SetSize(150, 28)
    loadButton:SetPoint("LEFT", changeIcon, "RIGHT", 8, 0)
    loadButton:SetText("Load from macros…")

    local bodyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bodyLabel:SetPoint("TOPLEFT", iconButton, "BOTTOMLEFT", 0, -16)
    bodyLabel:SetText("Macro body")
    bodyLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))
    if bodyLabel.SetMouseClickEnabled then
        bodyLabel:SetMouseClickEnabled(false)
    end

    local counter = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    counter:SetPoint("LEFT", bodyLabel, "RIGHT", 12, 0)
    counter:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    if counter.SetMouseClickEnabled then
        counter:SetMouseClickEnabled(false)
    end
    frame.counter = counter

    local bodyInput = CreateBodyInput(frame, LPL.MacroStore.MAX_BODY_LENGTH)
    -- Anchor to the icon row (a real frame), not the fontstring — more reliable sizing.
    bodyInput:SetPoint("TOPLEFT", iconButton, "BOTTOMLEFT", 0, -40)
    bodyInput:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
    bodyInput:SetFrameLevel((parent:GetFrameLevel() or 0) + 50)
    frame.bodyInput = bodyInput

    local function SyncDraftFromUI()
        if not frame.draft then
            return
        end
        frame.draft.body = LPL.MacroStore:NormalizeBody(bodyInput:GetText())
        frame.draft.icon = LPL.MacroStore:NormalizeIcon(frame.draft.icon)
    end

    local function RefreshCounter()
        local text = bodyInput:GetText() or ""
        local len = #text
        local maxLen = LPL.MacroStore.MAX_BODY_LENGTH
        frame.counter:SetText(string.format("%d / %d", len, maxLen))
        if len >= maxLen then
            frame.counter:SetTextColor(1, 0.35, 0.35)
        else
            frame.counter:SetTextColor(LPL.Theme:GetColor("textSecondary"))
        end
    end

    local function RefreshIcon()
        LPL.MacroIcons:SetTexture(frame.iconTex, frame.draft and frame.draft.icon)
    end

    local function RefreshStatus()
        if not frame.draft then
            frame.statusLabel:SetText("No draft.")
            return
        end
        SyncDraftFromUI()
        frame.statusLabel:SetText(LPL.MacroStore:GetSummaryLine(frame.draft))
    end

    bodyInput.onTextChanged = function(_, userInput)
        if userInput and frame.draft then
            SyncDraftFromUI()
            RefreshCounter()
            RefreshStatus()
        end
    end

    changeIcon:SetScript("OnClick", function()
        if not frame.draft then
            return
        end
        LPL.MacroIconPicker:Show(frame.draft.icon, function(texture)
            frame.draft.icon = LPL.MacroStore:NormalizeIcon(texture)
            RefreshIcon()
            RefreshStatus()
        end)
    end)

    iconButton:SetScript("OnClick", function()
        changeIcon:Click()
    end)

    loadButton:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            print("|cffffcc00LPL:|r Cannot load macros while in combat.")
            return
        end
        LPL.MacroLoadPopup:Show(function(macro)
            if not frame.draft or not macro then
                return
            end
            LPL.MacroStore:ApplyLiveMacroSource(frame.draft, macro)
            bodyInput:SetText(frame.draft.body or "")
            RefreshIcon()
            RefreshCounter()
            RefreshStatus()
            if frame.onNameLoaded then
                frame.onNameLoaded(frame.draft.name)
            end
            print(string.format(
                "|cff33cc33LPL:|r Loaded \"%s\" from %s macros. Edit, then Save to update both LPL and the Blizzard macro.",
                frame.draft.name or "macro",
                macro.scope or "Blizzard"
            ))
        end)
    end)

    function frame:Refresh()
        if not self.draft then
            return
        end
        self.draft.icon = LPL.MacroStore:NormalizeIcon(self.draft.icon)
        self.draft.body = LPL.MacroStore:NormalizeBody(self.draft.body)
        bodyInput:SetText(self.draft.body or "")
        RefreshIcon()
        RefreshCounter()
        RefreshStatus()
    end

    function frame:SetDraft(draft)
        self.draft = draft
        self:Refresh()
    end

    function frame:GetDraft()
        SyncDraftFromUI()
        return self.draft
    end

    function frame:SetOnNameLoaded(callback)
        self.onNameLoaded = callback
    end

    return frame
end

function LPL.MacroEditor:Destroy(editor)
    if not editor then
        return
    end
    if LPL.MacroIconPicker then
        LPL.MacroIconPicker:Hide()
    end
    editor:Hide()
    editor:SetParent(nil)
end
