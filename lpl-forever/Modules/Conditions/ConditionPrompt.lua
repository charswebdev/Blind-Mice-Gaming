local addonName, LPL = ...

LPL.ConditionPrompt = {}

local FRAME_NAME = "LPLConditionPrompt"
local DIALOG_WIDTH = 440

local function SetTextColor(fontString, colorKey)
    fontString:SetTextColor(LPL.Theme:GetColor(colorKey))
end

local function HidePrompt(frame)
    if frame then
        frame:Hide()
        frame.match = nil
        frame.selectedTarget = nil
        frame.onAccept = nil
        frame.onDecline = nil
    end
end

function LPL.ConditionPrompt:IsShown()
    return self.frame and self.frame:IsShown()
end

function LPL.ConditionPrompt:Hide()
    HidePrompt(self.frame)
end

function LPL.ConditionPrompt:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(DIALOG_WIDTH, 220)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(210)
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
    titleText:SetText("LPL Conditions")

    local closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        local onDecline = frame.onDecline
        HidePrompt(frame)
        if onDecline then
            onDecline()
        end
    end)

    local header = LPL:CreateLabel(frame, "bold")
    header:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 16, -14)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, 0)
    header:SetJustifyH("LEFT")
    SetTextColor(header, "textLabel")
    frame.header = header

    local body = LPL:CreateLabel(frame, "body")
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    body:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, 0)
    body:SetJustifyH("LEFT")
    SetTextColor(body, "textSecondary")
    frame.body = body

    local chooserLabel = LPL:CreateLabel(frame, "bold")
    chooserLabel:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -14)
    chooserLabel:SetText("Choose what to apply")
    SetTextColor(chooserLabel, "textLabel")
    frame.chooserLabel = chooserLabel

    local chooser = CreateFrame("Frame", nil, frame)
    chooser:SetPoint("TOPLEFT", chooserLabel, "BOTTOMLEFT", 0, -6)
    chooser:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -16, 0)
    chooser:SetHeight(72)
    frame.chooser = chooser
    frame.chooserRows = {}

    local applyButton = LPL:CreateButton(nil, frame)
    applyButton:SetSize(110, 28)
    applyButton:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 16)
    applyButton:SetText("Apply")
    frame.applyButton = applyButton

    local declineButton = LPL:CreateButton(nil, frame)
    declineButton:SetSize(110, 28)
    declineButton:SetPoint("RIGHT", applyButton, "LEFT", -8, 0)
    declineButton:SetText("Not now")
    frame.declineButton = declineButton

    applyButton:SetScript("OnClick", function()
        local onAccept = frame.onAccept
        local target = frame.selectedTarget
        local match = frame.match
        HidePrompt(frame)
        if onAccept then
            onAccept(match, target)
        end
    end)

    declineButton:SetScript("OnClick", function()
        local onDecline = frame.onDecline
        HidePrompt(frame)
        if onDecline then
            onDecline()
        end
    end)

    self.frame = frame
    return frame
end

local function ClearChooserRows(frame)
    for _, row in ipairs(frame.chooserRows or {}) do
        row:Hide()
        row:SetParent(nil)
    end
    frame.chooserRows = {}
end

local function TargetKey(target)
    if not target then
        return nil
    end
    return LPL.ConditionStore:LinkKey(target.type, target.id)
end

local function FormatTargetLabel(target)
    local badge = target.badge or LPL.ConditionDefs:GetLinkBadge(target.type)
    return string.format("[%s] %s", badge, target.name or "Item")
end

local function BuildChooser(frame, targets)
    ClearChooserRows(frame)
    frame.selectedTarget = nil

    if #targets <= 1 then
        frame.chooserLabel:Hide()
        frame.chooser:Hide()
        if targets[1] then
            frame.selectedTarget = targets[1]
        end
        return 0
    end

    frame.chooserLabel:Show()
    frame.chooser:Show()

    local y = 0
    for index, target in ipairs(targets) do
        local row = CreateFrame("Button", nil, frame.chooser)
        row:SetHeight(22)
        row:SetPoint("TOPLEFT", frame.chooser, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", frame.chooser, "TOPRIGHT", 0, -y)

        local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        check:SetSize(20, 20)
        check:SetPoint("LEFT", row, "LEFT", 0, 0)

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", check, "RIGHT", 4, 0)
        label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        label:SetJustifyH("LEFT")
        label:SetText(FormatTargetLabel(target))
        label:SetTextColor(LPL.Theme:GetColor("textBright"))

        local key = TargetKey(target)
        local function Select()
            frame.selectedTarget = target
            for _, other in ipairs(frame.chooserRows) do
                other.check:SetChecked(TargetKey(other.target) == key)
            end
            frame.applyButton:SetEnabled(true)
        end

        check:SetScript("OnClick", Select)
        row:SetScript("OnClick", Select)
        row.check = check
        row.target = target
        frame.chooserRows[#frame.chooserRows + 1] = row

        if index == 1 then
            Select()
        end
        y = y + 24
    end

    frame.chooser:SetHeight(math.max(24, y))
    return y
end

function LPL.ConditionPrompt:Show(match, onAccept, onDecline)
    if type(match) ~= "table" or type(match.rule) ~= "table" then
        return false
    end

    local targets = match.targets or match.loadouts or {}
    -- Normalize legacy loadout records into targets.
    if #targets > 0 and targets[1].type == nil and targets[1].id then
        local normalized = {}
        for _, record in ipairs(targets) do
            normalized[#normalized + 1] = {
                type = "loadout",
                id = tostring(record.id),
                name = record.name,
                badge = "LOADOUT",
                record = record,
            }
        end
        targets = normalized
    end

    if #targets == 0 then
        return false
    end

    local frame = self:EnsureFrame()
    frame.match = match
    frame.onAccept = onAccept
    frame.onDecline = onDecline

    local ruleName = match.rule.name or "Condition"
    frame.header:SetText(string.format('Apply "%s"?', ruleName))

    if #targets == 1 then
        frame.body:SetText(string.format(
            "Situation matches. Apply %s?",
            FormatTargetLabel(targets[1])
        ))
    else
        frame.body:SetText(string.format(
            "%d linked items fit this character. Pick one to apply.",
            #targets
        ))
    end

    local chooserHeight = BuildChooser(frame, targets)
    local height = 150
    if #targets > 1 then
        height = 170 + chooserHeight
    end
    frame:SetHeight(height)

    frame.applyButton:SetEnabled(frame.selectedTarget ~= nil)
    frame:Show()
    return true
end
