local _, GPS = ...

GPS.ImportDialog = GPS.ImportDialog or {}
local Dialog = GPS.ImportDialog

function Dialog:Init()
    if self.frame then
        return
    end
    local theme = GPS.Theme
    local c = theme.colors

    local frame = CreateFrame("Frame", "WowGPSForeverImportDialog", UIParent, "BackdropTemplate")
    frame:SetSize(420, 200)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(500)
    frame:EnableMouse(true)
    frame:Hide()
    theme:ApplyBackdrop(frame)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.title:SetPoint("TOPLEFT", 14, -12)
    frame.title:SetPoint("TOPRIGHT", -14, -12)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(true)
    frame.title:SetText("Paste WowGPS strings or /way lines. One place per line.")
    theme:SetTextColor(frame.title, c.text)

    local edit = CreateFrame("EditBox", nil, frame)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetPoint("TOPLEFT", 16, -40)
    edit:SetPoint("BOTTOMRIGHT", -16, 48)
    edit:SetMaxLetters(8000)
    edit:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    theme:StyleEditBox(edit)
    frame.editBox = edit
    frame:SetScript("OnShow", function(selfFrame)
        local width = GPS:PlainNumber(selfFrame:GetWidth())
        if width and width > 40 then
            edit:SetWidth(width - 32)
        end
    end)

    local acceptBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    acceptBtn:SetSize(88, 26)
    acceptBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    acceptBtn:SetText(ACCEPT or "Accept")
    theme:StyleSmallButton(acceptBtn, "royal")
    acceptBtn:SetScript("OnClick", function()
        Dialog:Accept()
    end)

    local cancelBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    cancelBtn:SetSize(88, 26)
    cancelBtn:SetPoint("RIGHT", acceptBtn, "LEFT", -8, 0)
    cancelBtn:SetText(CANCEL or "Cancel")
    theme:StyleSmallButton(cancelBtn)
    cancelBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    self.frame = frame
end

function Dialog:Accept()
    if not self.frame or not self.frame.editBox then
        return
    end
    local text = GPS:PlainString(self.frame.editBox:GetText())
    if not text then
        return
    end
    local count = GPS.Import and GPS.Import:Run(text) or 0
    if count > 0 then
        self.frame:Hide()
    end
end

function Dialog:Show()
    self:Init()
    self.frame.editBox:SetText("")
    self.frame:Show()
    self.frame:Raise()
    self.frame.editBox:SetFocus()
end
