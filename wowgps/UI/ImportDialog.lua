local _, ns = ...

local ImportDialog = {}
ns.ImportDialog = ImportDialog

function ImportDialog:Init()
    if self.frame then
        return
    end

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme

    local f = CreateFrame("Frame", "WowGPSImportDialog", UIParent, "BackdropTemplate")
    f:SetSize(460, 220)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(500)
    f:EnableMouse(true)
    f:Hide()
    theme:ApplyBackdrop(f)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.title:SetPoint("TOPLEFT", 14, -10)
    f.title:SetPoint("TOPRIGHT", -14, -10)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(true)
    f.title:SetText(L["IMPORT_PROMPT"])
    theme:SetTextColor(f.title, theme.colors.text)

    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 14, -48)
    scroll:SetPoint("BOTTOMRIGHT", -34, 48)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject("ChatFontNormal")
    edit:SetWidth(400)
    edit:SetHeight(120)
    edit:SetMaxLetters(8000)
    edit:SetScript("OnEscapePressed", function()
        f:Hide()
    end)
    theme:StyleEditBox(edit)
    scroll:SetScrollChild(edit)
    f.editBox = edit

    local acceptBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    acceptBtn:SetSize(88, 26)
    acceptBtn:SetPoint("BOTTOMRIGHT", -14, 14)
    acceptBtn:SetText(ACCEPT)
    acceptBtn:RegisterForClicks("LeftButtonUp")
    theme:StyleButton(acceptBtn)
    acceptBtn:SetScript("OnClick", function()
        ImportDialog:Accept()
    end)

    local cancelBtn = CreateFrame("Button", nil, f, "BackdropTemplate")
    cancelBtn:SetSize(88, 26)
    cancelBtn:SetPoint("RIGHT", acceptBtn, "LEFT", -8, 0)
    cancelBtn:SetText(CANCEL)
    cancelBtn:RegisterForClicks("LeftButtonUp")
    theme:StyleButton(cancelBtn)
    cancelBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    self.frame = f
end

function ImportDialog:Accept()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local text = (self.frame.editBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" then
        return
    end

    local ok, _, count = ns.CustomLocations:Import(text)
    if ok then
        count = tonumber(count) or 1
        if count > 1 then
            WowGPS:Print(string.format(L["IMPORT_SUCCESS_COUNT"], count))
        else
            WowGPS:Print(L["IMPORT_SUCCESS"])
        end
        self.frame:Hide()
        if ns.MainFrame then
            ns.MainFrame:SelectTab("saved")
        end
        if ns.SavedTab and ns.SavedTab.RefreshList then
            ns.SavedTab:RefreshList()
        end
    else
        WowGPS:Print(L["IMPORT_FAILED"])
    end
end

function ImportDialog:Show()
    self:Init()
    self.frame.editBox:SetText("")
    self.frame:Show()
    self.frame:Raise()
    self.frame.editBox:SetFocus()
end
