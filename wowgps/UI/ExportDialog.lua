local _, ns = ...

local ExportDialog = {}
ns.ExportDialog = ExportDialog

function ExportDialog:Init()
    if self.frame then
        return
    end

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme

    local f = CreateFrame("Frame", "WowGPSExportDialog", UIParent, "BackdropTemplate")
    f:SetSize(420, 132)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(500)
    f:EnableMouse(true)
    f:Hide()
    theme:ApplyBackdrop(f)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetPoint("TOPRIGHT", -14, -12)
    f.title:SetJustifyH("LEFT")
    f.title:SetText(L["EXPORT_PROMPT"])
    theme:SetTextColor(f.title, theme.colors.text)

    local edit = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    edit:SetAutoFocus(false)
    edit:SetPoint("TOPLEFT", 14, -38)
    edit:SetPoint("TOPRIGHT", -14, -38)
    edit:SetHeight(28)
    edit:SetMaxLetters(512)
    theme:StyleEditBox(edit)
    edit:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    edit:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    f.editBox = edit

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -38)
    scroll:SetPoint("BOTTOMRIGHT", -34, 48)
    scroll:Hide()

    local block = CreateFrame("EditBox", nil, scroll)
    block:SetMultiLine(true)
    block:SetAutoFocus(false)
    block:SetFontObject("ChatFontNormal")
    block:SetWidth(360)
    block:SetHeight(180)
    block:SetMaxLetters(262144)
    block:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    block:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    theme:StyleEditBox(block)
    scroll:SetScrollChild(block)
    f.scroll = scroll
    f.blockBox = block

    local closeBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    closeBtn:SetSize(88, 26)
    closeBtn:SetPoint("BOTTOM", 0, 14)
    closeBtn:SetText(CLOSE)
    closeBtn:RegisterForClicks("LeftButtonUp")
    theme:StyleButton(closeBtn)
    closeBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    self.frame = f
end

function ExportDialog:Show(text)
    self:Init()
    local frame = self.frame
    frame:SetSize(420, 132)
    frame.scroll:Hide()
    frame.editBox:Show()
    frame.title:SetText(LibStub("AceLocale-3.0"):GetLocale("WowGPS")["EXPORT_PROMPT"])
    frame.editBox:SetText(text or "")
    frame:Show()
    frame:Raise()
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
end

function ExportDialog:ShowBlock(text, title)
    self:Init()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local frame = self.frame
    frame:SetSize(460, 300)
    frame.editBox:Hide()
    frame.scroll:Show()
    frame.title:SetText(title or L["PROFILE_EXPORT_PROMPT"])
    local block = frame.blockBox
    block:SetText(text or "")
    frame:Show()
    frame:Raise()
    block:SetFocus()
    block:HighlightText()
end
