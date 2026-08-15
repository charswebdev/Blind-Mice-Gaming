local addonName, LPL = ...

local SettingsModule = {
    id = "settings",
    label = "Settings",
    description = "Configure LPL appearance and behavior.",
    iconStem = "settings_64",
    order = 100,
    instance = nil,
}

local function GetAddonVersion()
    local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
    return version or "dev"
end

local function AddCheckRow(parent, anchor, text, getChecked, setChecked, onChanged)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    if anchor then
        check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
    end
    check:SetSize(24, 24)
    check:SetChecked(getChecked() and true or false)

    local label = LPL:CreateLabel(parent, "body")
    label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    label:SetText(text)

    check:SetScript("OnClick", function(self)
        setChecked(self:GetChecked() and true or false)
        if onChanged then
            onChanged(self:GetChecked() and true or false)
        end
    end)

    return check
end

function SettingsModule.create(parent)
    local frame = CreateFrame("Frame", "LPLSettingsModule", parent)
    frame:SetAllPoints(parent)

    local title = LPL:CreateLabel(frame, "title")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -24)
    title:SetText("Settings")

    local scaleLabel = LPL:CreateLabel(frame, "bold")
    scaleLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -28)
    scaleLabel:SetText("UI Scale")

    local scaleValue = LPL:CreateLabel(frame, "body")
    scaleValue:SetPoint("LEFT", scaleLabel, "RIGHT", 12, 0)
    scaleValue:SetTextColor(LPL.Theme:GetColor("accent"))

    local slider = CreateFrame("Slider", "LPLScaleSlider", frame, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -16)
    slider:SetWidth(280)
    slider:SetMinMaxValues(0.8, 1.2)
    slider:SetValueStep(0.05)
    slider:SetObeyStepOnDrag(true)
    if slider.Low then
        slider.Low:SetText("80%")
        slider.High:SetText("120%")
        slider.Text:SetText("")
    end

    local ui = LPL.DB:GetUI()
    slider:SetValue(ui.scale or 1.0)
    scaleValue:SetText(string.format("%.0f%%", (ui.scale or 1.0) * 100))

    slider:SetScript("OnValueChanged", function(self, value)
        local clamped = LPL.Theme:ApplyScale(value)
        ui.scale = clamped
        scaleValue:SetText(string.format("%.0f%%", clamped * 100))
    end)

    local levelSliderCheck = CreateFrame("CheckButton", "LPLShowLevelSliderCheck", frame, "UICheckButtonTemplate")
    levelSliderCheck:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, -36)
    levelSliderCheck:SetSize(24, 24)
    levelSliderCheck:SetChecked(ui.showLevelSlider == true)

    local levelSliderLabel = LPL:CreateLabel(frame, "body")
    levelSliderLabel:SetPoint("LEFT", levelSliderCheck, "RIGHT", 4, 0)
    levelSliderLabel:SetText("Show level slider on Talents tab")

    local function RefreshTalentsLevelSlider()
        local talents = LPL.Modules:Get("talents")
        if talents and talents.instance and talents.instance.viewMode == "tree" and talents.instance.picker then
            talents.instance.picker:Refresh()
        end
    end

    levelSliderCheck:SetScript("OnClick", function(self)
        ui.showLevelSlider = self:GetChecked() and true or false
        RefreshTalentsLevelSlider()
    end)

    local minimapCheck = CreateFrame("CheckButton", "LPLShowMinimapCheck", frame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", levelSliderCheck, "BOTTOMLEFT", 0, -16)
    minimapCheck:SetSize(24, 24)

    local minimapLabel = LPL:CreateLabel(frame, "body")
    minimapLabel:SetPoint("LEFT", minimapCheck, "RIGHT", 4, 0)
    minimapLabel:SetText("Show minimap button")

    local minimapSettings = ui.minimap or {}
    minimapCheck:SetChecked(minimapSettings.shown ~= false)

    minimapCheck:SetScript("OnClick", function(self)
        local settings = LPL.DB:GetUI().minimap
        settings.shown = self:GetChecked() and true or false
        if LPL.Minimap then
            LPL.Minimap:Refresh()
        end
    end)

    local conditionsHeader = LPL:CreateLabel(frame, "bold")
    conditionsHeader:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -28)
    conditionsHeader:SetText("Conditions")

    local masterCheck = AddCheckRow(
        frame,
        conditionsHeader,
        "Enable Conditions (master)",
        function()
            return LPL.ConditionStore:IsMasterEnabled()
        end,
        function(enabled)
            LPL.ConditionStore:SetMasterEnabled(enabled)
        end,
        function()
            if LPL.ConditionWatcher and LPL.ConditionWatcher.NotifySettingsChanged then
                LPL.ConditionWatcher:NotifySettingsChanged()
            end
            local conditions = LPL.Modules:Get("conditions")
            if conditions and conditions.instance and conditions.instance.Refresh then
                conditions.instance:Refresh()
            end
        end
    )
    masterCheck:ClearAllPoints()
    masterCheck:SetPoint("TOPLEFT", conditionsHeader, "BOTTOMLEFT", -4, -12)

    local limitCheck = AddCheckRow(
        frame,
        masterCheck,
        "Limit condition suggestions",
        function()
            return LPL.ConditionStore:GetSettings().limitConditions
        end,
        function(enabled)
            LPL.ConditionStore:SetLimitConditions(enabled)
        end,
        function()
            if LPL.ConditionWatcher and LPL.ConditionWatcher.NotifySettingsChanged then
                LPL.ConditionWatcher:NotifySettingsChanged()
            end
        end
    )

    local limitHint = LPL:CreateLabel(frame, "small")
    limitHint:SetPoint("TOPLEFT", limitCheck, "BOTTOMLEFT", 28, -2)
    limitHint:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    limitHint:SetJustifyH("LEFT")
    limitHint:SetTextColor(LPL.Theme:GetColor("textMuted"))
    limitHint:SetText("When several rules match, only offer the highest-priority match tier.")

    local noSpecCheck = AddCheckRow(
        frame,
        limitHint,
        "Don’t offer conditions of a different specialization",
        function()
            return LPL.ConditionStore:GetSettings().noSpecSwitch
        end,
        function(enabled)
            LPL.ConditionStore:SetNoSpecSwitch(enabled)
        end,
        function()
            if LPL.ConditionWatcher and LPL.ConditionWatcher.NotifySettingsChanged then
                LPL.ConditionWatcher:NotifySettingsChanged()
            end
        end
    )
    noSpecCheck:ClearAllPoints()
    noSpecCheck:SetPoint("TOPLEFT", limitHint, "BOTTOMLEFT", -28, -12)

    local noSpecHint = LPL:CreateLabel(frame, "small")
    noSpecHint:SetPoint("TOPLEFT", noSpecCheck, "BOTTOMLEFT", 28, -2)
    noSpecHint:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    noSpecHint:SetJustifyH("LEFT")
    noSpecHint:SetTextColor(LPL.Theme:GetColor("textMuted"))
    noSpecHint:SetText("Skip linked builds/loadouts whose specialization doesn’t match your current one.")

    local versionLabel = LPL:CreateLabel(frame, "small")
    versionLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 24, 20)
    versionLabel:SetTextColor(LPL.Theme:GetColor("textMuted"))
    versionLabel:SetText(string.format("LPL v%s - Blind Mice Gaming", GetAddonVersion()))

    function frame:Refresh()
        masterCheck:SetChecked(LPL.ConditionStore:IsMasterEnabled())
        limitCheck:SetChecked(LPL.ConditionStore:GetSettings().limitConditions)
        noSpecCheck:SetChecked(LPL.ConditionStore:GetSettings().noSpecSwitch)
        versionLabel:SetText(string.format("LPL v%s - Blind Mice Gaming", GetAddonVersion()))
    end

    frame:Hide()
    SettingsModule.instance = frame
    return frame
end

LPL.Modules:Register({
    id = SettingsModule.id,
    label = SettingsModule.label,
    description = SettingsModule.description,
    iconStem = SettingsModule.iconStem,
    order = SettingsModule.order,
    create = SettingsModule.create,
    OnShow = function()
        local instance = SettingsModule.instance
        if instance and instance.Refresh then
            instance:Refresh()
        end
    end,
})
