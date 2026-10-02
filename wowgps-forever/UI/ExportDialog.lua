local _, GPS = ...

GPS.ExportDialog = GPS.ExportDialog or {}
local Dialog = GPS.ExportDialog

function Dialog:Init()
    if self.frame then
        return
    end
    local theme = GPS.Theme
    local c = theme.colors

    local frame = CreateFrame("Frame", "WowGPSForeverExportDialog", UIParent, "BackdropTemplate")
    frame:SetSize(420, 132)
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
    frame.title:SetText("Copy this string (Ctrl+C).")
    theme:SetTextColor(frame.title, c.text)

    local single = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    single:SetAutoFocus(false)
    single:SetPoint("TOPLEFT", 14, -40)
    single:SetPoint("TOPRIGHT", -14, -40)
    single:SetHeight(28)
    single:SetMaxLetters(512)
    theme:StyleEditBox(single)
    single:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    single:SetScript("OnEditFocusGained", function(box)
        box:HighlightText()
    end)
    frame.single = single

    local multi = CreateFrame("EditBox", nil, frame)
    multi:SetMultiLine(true)
    multi:SetAutoFocus(false)
    multi:SetFontObject("ChatFontNormal")
    multi:SetPoint("TOPLEFT", 16, -36)
    multi:SetPoint("BOTTOMRIGHT", -16, 46)
    multi:SetMaxLetters(8000)
    multi:Hide()
    theme:StyleEditBox(multi)
    multi:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    multi:SetScript("OnEditFocusGained", function(box)
        box:HighlightText()
    end)
    frame.multi = multi

    local closeBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    closeBtn:SetSize(88, 26)
    closeBtn:SetPoint("BOTTOM", 0, 12)
    closeBtn:SetText(CLOSE or "Close")
    theme:StyleSmallButton(closeBtn)
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)

    self.frame = frame
end

function Dialog:Show(text)
    text = GPS:PlainString(text)
    if not text then
        return
    end
    self:Init()
    local multi = string.find(text, "\n", 1, true) ~= nil
    local frame = self.frame
    frame:SetHeight(multi and 180 or 132)
    frame.single:SetShown(not multi)
    frame.multi:SetShown(multi == true)
    local edit = multi and frame.multi or frame.single
    if multi then
        local width = GPS:PlainNumber(frame:GetWidth())
        if width and width > 40 then
            edit:SetWidth(width - 32)
        end
    end
    edit:SetText(text)
    frame:Show()
    frame:Raise()
    edit:SetFocus()
    edit:HighlightText()
end
