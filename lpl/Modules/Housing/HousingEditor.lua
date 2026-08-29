local addonName, LPL = ...

LPL.HousingEditor = {}

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

    container.scroll = scroll
    container.editBox = editBox
    container.UpdateEditBoxLayout = UpdateEditBoxLayout
    return container
end

function LPL.HousingEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame:EnableMouse(false)
    frame.draft = nil

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
    title:SetText("Housing Blueprint")
    title:SetTextColor(LPL.Theme:GetColor("textBright"))
    DisableFontStringMouse(title)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    status:SetJustifyH("LEFT")
    status:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    DisableFontStringMouse(status)
    frame.statusLabel = status

    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -10)
    instructions:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    instructions:SetJustifyH("LEFT")
    instructions:SetWordWrap(true)
    instructions:SetTextColor(LPL.Theme:GetColor("textMuted"))
    instructions:SetText("Paste a Blizzard blueprint code. On your housing plot: Housing HUD → Blueprint → Import. After a good import, re-save in-game so the code stays yours if the creator deletes theirs.")
    DisableFontStringMouse(instructions)

    local notesTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    notesTitle:SetPoint("TOPLEFT", instructions, "BOTTOMLEFT", 0, -12)
    notesTitle:SetText("Notes")
    notesTitle:SetTextColor(LPL.Theme:GetColor("textLabel"))
    DisableFontStringMouse(notesTitle)

    local notesBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    notesBox:SetAutoFocus(false)
    notesBox:SetHeight(24)
    notesBox:SetPoint("TOPLEFT", notesTitle, "BOTTOMLEFT", 0, -4)
    notesBox:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    notesBox:SetMaxLetters(200)
    frame.notesBox = notesBox

    local pasteLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pasteLabel:SetPoint("TOPLEFT", notesBox, "BOTTOMLEFT", 0, -14)
    pasteLabel:SetText("Blueprint code")
    pasteLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))
    DisableFontStringMouse(pasteLabel)

    local sizeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sizeLabel:SetPoint("LEFT", pasteLabel, "RIGHT", 12, 0)
    sizeLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    DisableFontStringMouse(sizeLabel)
    frame.sizeLabel = sizeLabel

    local pasteInput = CreatePasteInput(frame)
    pasteInput:SetPoint("TOPLEFT", pasteLabel, "BOTTOMLEFT", 0, -8)
    pasteInput:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
    frame.pasteInput = pasteInput

    local function SyncDraftFromUI()
        if not frame.draft then
            return
        end
        frame.draft.notes = notesBox:GetText() or ""
        frame.draft.code = pasteInput:GetText() or ""
    end

    local function RefreshStatus()
        if not frame.draft then
            frame.statusLabel:SetText("No draft.")
            return
        end
        SyncDraftFromUI()
        frame.statusLabel:SetText(LPL.HousingStore:GetSummaryLine(frame.draft))
        local bytes = #(frame.draft.code or "")
        frame.sizeLabel:SetText(string.format("%d characters", bytes))
    end

    notesBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput and frame.draft then
            SyncDraftFromUI()
            RefreshStatus()
        end
    end)

    pasteInput.onTextChanged = function(text)
        if not frame.draft then
            return
        end
        frame.draft.code = text or ""
        RefreshStatus()
    end

    function frame:Refresh()
        if not self.draft then
            return
        end
        self.draft.code = self.draft.code or ""
        self.draft.notes = self.draft.notes or ""
        notesBox:SetText(self.draft.notes or "")
        pasteInput:SetText(self.draft.code or "")
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

function LPL.HousingEditor:Destroy(editor)
    if not editor then
        return
    end
    editor:Hide()
    editor:SetParent(nil)
end
