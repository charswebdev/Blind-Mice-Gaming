local addonName, LPL = ...

-- Chooser when the Import hub cannot tell Macro vs Addon Profile apart.
LPL.VaultImportChooser = {}

local FRAME_NAME = "LPLVaultImportChooser"

function LPL.VaultImportChooser:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(480, 180)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(240)
    frame:EnableMouse(true)
    frame:Hide()
    LPL.Theme:ApplyBackdrop(frame, "panel", "bgPrimary", "border")

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(32)
    LPL.Theme:ApplyBackdrop(titleBar, "panel", "titleBar", "border")

    local title = LPL:CreateLabel(titleBar, "header")
    title:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    title:SetText("Save Import As")

    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function()
        frame:Hide()
        if frame.onCancel then
            frame.onCancel()
        end
    end)

    local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    body:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 16, -16)
    body:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, -16)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    body:SetText("This doesn’t look like a known LPL share string. Save it as a Macro body or an Addon Profile?")
    body:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    frame.body = body

    local buttonGap = 8
    local buttonHeight = 28

    local cancelButton = LPL:CreateButton(nil, frame)
    cancelButton:SetSize(90, buttonHeight)
    cancelButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    cancelButton:SetText("Cancel")
    frame.cancelButton = cancelButton

    local addonButton = LPL:CreateButton(nil, frame)
    addonButton:SetSize(150, buttonHeight)
    addonButton:SetPoint("RIGHT", cancelButton, "LEFT", -buttonGap, 0)
    addonButton:SetText("Addon Profile")
    frame.addonButton = addonButton

    local macroButton = LPL:CreateButton(nil, frame)
    macroButton:SetSize(110, buttonHeight)
    macroButton:SetPoint("RIGHT", addonButton, "LEFT", -buttonGap, 0)
    macroButton:SetText("Macro")
    frame.macroButton = macroButton
    cancelButton:SetScript("OnClick", function()
        frame:Hide()
        if frame.onCancel then
            frame.onCancel()
        end
    end)

    macroButton:SetScript("OnClick", function()
        frame:Hide()
        if frame.onPick then
            frame.onPick("macros")
        end
    end)

    addonButton:SetScript("OnClick", function()
        frame:Hide()
        if frame.onPick then
            frame.onPick("addonprofiles")
        end
    end)

    self.frame = frame
    return frame
end

function LPL.VaultImportChooser:Show(onPick, onCancel)
    local frame = self:EnsureFrame()
    frame.onPick = onPick
    frame.onCancel = onCancel
    frame:Show()
end

function LPL.VaultImportChooser:Hide()
    if self.frame then
        self.frame:Hide()
    end
end
