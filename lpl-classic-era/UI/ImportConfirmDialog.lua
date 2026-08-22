local addonName, LPL = ...

LPL.ImportConfirmDialog = {}

local FRAME_NAME = "LPLImportConfirmDialog"
local DIALOG_WIDTH = 520
local SECTION_SPACING = 12
local ROW_HEIGHT = 18

local function SetTextColor(fontString, colorKey)
    fontString:SetTextColor(LPL.Theme:GetColor(colorKey))
end

local function CreateSectionRow(parent, frameLevel)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(ROW_HEIGHT)

    local title = LPL:CreateLabel(row, "bold")
    title:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    SetTextColor(title, "textLabel")

    local path = LPL:CreateLabel(row, "body")
    path:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    path:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    path:SetJustifyH("LEFT")
    path:SetTextColor(0.45, 1, 0.55)

    local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", path, "BOTTOMLEFT", -4, -6)
    check:SetSize(24, 24)
    check:SetFrameLevel(frameLevel + 2)

    local checkLabel = check:CreateFontString(nil, "OVERLAY")
    checkLabel:SetFontObject(LPL.Theme.fonts.body)
    checkLabel:SetPoint("LEFT", check, "RIGHT", 2, 0)
    checkLabel:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    checkLabel:SetJustifyH("LEFT")
    SetTextColor(checkLabel, "textLabel")

    row.title = title
    row.path = path
    row.check = check
    row.checkLabel = checkLabel

    function row:SetSection(section)
        self.sectionId = section.id
        self.title:SetText(section.label or "")
        self.path:SetText(section.path or "")
        self.checkLabel:SetText(section.checkboxLabel or "")
        self.check:SetChecked(section.defaultChecked ~= false)
        self.check:Enable()
        self.check:Show()
        self:Show()
    end

    function row:IsIncluded()
        return self.check:GetChecked()
    end

    function row:GetSectionId()
        return self.sectionId
    end

    row:SetHeight(ROW_HEIGHT + 44)
    return row
end

function LPL.ImportConfirmDialog:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(DIALOG_WIDTH, 360)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(200)
    frame:EnableMouse(true)
    frame:Hide()
    LPL.Theme:ApplyBackdrop(frame, "panel", "bgPrimary", "border")

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(32)
    LPL.Theme:ApplyBackdrop(titleBar, "panel", "titleBar", "border")

    local titleText = LPL:CreateLabel(titleBar, "header")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 12, 0)
    titleText:SetText("Light Paws Loadouts - Classic Era")

    local closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local header = LPL:CreateLabel(frame, "bold")
    header:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 16, -16)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, 0)
    header:SetJustifyH("LEFT")
    SetTextColor(header, "textLabel")

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -12)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 52)
    content.sectionRows = {}

    local importButton = LPL:CreateButton(nil, frame)
    importButton:SetSize(100, 28)
    importButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    importButton:SetText("Import")

    local cancelButton = LPL:CreateButton(nil, frame)
    cancelButton:SetSize(100, 28)
    cancelButton:SetPoint("RIGHT", importButton, "LEFT", -8, 0)
    cancelButton:SetText("Cancel")

    cancelButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    importButton:SetScript("OnClick", function()
        if frame.onConfirm then
            local options = {
                talents = false,
                hero = false,
                actionBars = false,
                keybinds = false,
                equipment = false,
                pvpTalents = false,
                cooldownManager = false,
                editMode = false,
                addonSets = false,
            }
            for _, row in ipairs(content.sectionRows) do
                if row:IsShown() then
                    local sectionId = row:GetSectionId()
                    if sectionId == "talents" then
                        options.talents = row:IsIncluded()
                    elseif sectionId == "hero" then
                        options.hero = row:IsIncluded()
                    elseif sectionId == "actionBars" then
                        options.actionBars = row:IsIncluded()
                    elseif sectionId == "keybinds" then
                        options.keybinds = row:IsIncluded()
                    elseif sectionId == "equipment" then
                        options.equipment = row:IsIncluded()
                    elseif sectionId == "pvpTalents" then
                        options.pvpTalents = row:IsIncluded()
                    elseif sectionId == "cooldownManager" then
                        options.cooldownManager = row:IsIncluded()
                    elseif sectionId == "editMode" then
                        options.editMode = row:IsIncluded()
                    elseif sectionId == "addonSets" then
                        options.addonSets = row:IsIncluded()
                    end
                end
            end
            if not options.talents and not options.hero and not options.actionBars
                and not options.keybinds
                and not options.equipment and not options.pvpTalents
                and not options.cooldownManager and not options.editMode
                and not options.addonSets then
                return
            end
            frame.onConfirm(options)
        end
        frame:Hide()
    end)

    frame.titleBar = titleBar
    frame.header = header
    frame.content = content
    frame.importButton = importButton
    frame.cancelButton = cancelButton

    table.insert(UISpecialFrames, FRAME_NAME)
    self.frame = frame
    return frame
end

function LPL.ImportConfirmDialog:Show(preview, onConfirm)
    if not preview or not preview.sections or #preview.sections == 0 then
        return false
    end

    local frame = self:EnsureFrame()
    frame.onConfirm = onConfirm

    frame.header:SetText(string.format('Importing Loadout "%s"', preview.loadoutPath or preview.buildName or "Imported Build"))

    local content = frame.content
    for _, row in ipairs(content.sectionRows) do
        row:Hide()
    end

    local yOffset = 0
    local frameLevel = content:GetFrameLevel()
    for index, section in ipairs(preview.sections) do
        local row = content.sectionRows[index]
        if not row then
            row = CreateSectionRow(content, frameLevel)
            content.sectionRows[index] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -yOffset)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -yOffset)
        row:SetSection(section)
        yOffset = yOffset + row:GetHeight() + SECTION_SPACING
    end

    local dialogHeight = 120 + yOffset + 52
    frame:SetHeight(math.max(240, dialogHeight))
    frame:Show()
    frame:Raise()
    return true
end
