local addonName, LPL = ...

LPL.TalentPicker = {}

local MIN_LEVEL = 10
local TOOLBAR_HEIGHT_COMPACT = 82
local TOOLBAR_HEIGHT_WITH_LEVEL = 118

local function GetMaxLevel()
    if GetMaxLevelForPlayerExpansion then
        return GetMaxLevelForPlayerExpansion()
    end
    return 90
end

local function IsLevelSliderEnabled()
    return LPL.DB:GetUI().showLevelSlider == true
end

local function FormatPool(spent, max)
    spent = spent or 0
    max = max or 0
    if spent > max then
        return string.format("|cffff6060%d|r/%d", spent, max)
    end
    return string.format("%d/%d", spent, max)
end

function LPL.TalentPicker:Create(parent, onChange, talentsFrame)
    local toolbar = LPL:CreatePanel(nil, parent)
    toolbar:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -8)
    toolbar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, -8)
    toolbar:SetHeight(TOOLBAR_HEIGHT_COMPACT)
    toolbar:SetClipsChildren(true)

    local classDrop = LPL:CreateDropdown("LPLClassDrop", toolbar, 155)
    classDrop:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 14, -10)
    classDrop:SetLabel("Class")

    local specDrop = LPL:CreateDropdown("LPLSpecDrop", toolbar, 155)
    specDrop:SetPoint("TOPLEFT", classDrop, "TOPRIGHT", 12, 0)
    specDrop:SetLabel("Specialization")

    local heroDrop = LPL:CreateDropdown("LPLHeroDrop", toolbar, 195)
    heroDrop:SetPoint("TOPLEFT", specDrop, "TOPRIGHT", 12, 0)
    heroDrop:SetLabel("Hero Talents")

    local pointsLabel = LPL:CreateLabel(toolbar, "bold")
    pointsLabel:SetPoint("TOPRIGHT", toolbar, "TOPRIGHT", -14, -16)
    pointsLabel:SetJustifyH("RIGHT")
    pointsLabel:SetWidth(360)
    pointsLabel:SetTextColor(LPL.Theme:GetColor("textBright"))

    local statusLabel = LPL:CreateLabel(toolbar, "small")
    statusLabel:SetPoint("TOPRIGHT", pointsLabel, "BOTTOMRIGHT", 0, -4)
    statusLabel:SetPoint("TOPLEFT", heroDrop, "TOPRIGHT", 16, -22)
    statusLabel:SetJustifyH("RIGHT")
    statusLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    statusLabel:SetText("Left-click to assign · Right-click to refund · Choice nodes open a flyout")

    local levelRow = CreateFrame("Frame", nil, toolbar)
    levelRow:SetPoint("TOPLEFT", classDrop, "BOTTOMLEFT", 0, -8)
    levelRow:SetPoint("RIGHT", toolbar, "RIGHT", -14, 0)
    levelRow:SetHeight(36)

    local levelLabel = LPL:CreateLabel(levelRow, "small")
    levelLabel:SetPoint("TOPLEFT", levelRow, "TOPLEFT", 0, -2)
    levelLabel:SetTextColor(LPL.Theme:GetColor("textMuted"))
    levelLabel:SetText("Level")

    local levelValue = LPL:CreateLabel(levelRow, "body")
    levelValue:SetPoint("LEFT", levelLabel, "RIGHT", 8, 0)
    levelValue:SetTextColor(LPL.Theme:GetColor("accent"))

    local levelSlider = CreateFrame("Slider", "LPLLevelSlider", levelRow, "OptionsSliderTemplate")
    levelSlider:SetPoint("TOPLEFT", levelLabel, "BOTTOMLEFT", 0, -12)
    levelSlider:SetWidth(200)
    levelSlider:SetMinMaxValues(MIN_LEVEL, GetMaxLevel())
    levelSlider:SetValueStep(1)
    levelSlider:SetObeyStepOnDrag(true)
    if levelSlider.Low then
        levelSlider.Low:SetText(tostring(MIN_LEVEL))
        levelSlider.High:SetText(tostring(GetMaxLevel()))
        levelSlider.Text:SetText("")
    end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -6)
    frame:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -6)
    frame:SetHeight(1)

    frame.toolbar = toolbar
    frame.classDrop = classDrop
    frame.specDrop = specDrop
    frame.heroDrop = heroDrop
    frame.pointsLabel = pointsLabel
    frame.statusLabel = statusLabel
    frame.levelRow = levelRow
    frame.levelSlider = levelSlider
    frame.levelValue = levelValue
    frame.onChange = onChange
    frame.talentsFrame = talentsFrame

    local function RenderTreeForLevel()
        local talentsFrame = frame.talentsFrame
        if talentsFrame and talentsFrame.canvas then
            talentsFrame.canvas:Render()
        end
    end

    levelSlider:SetScript("OnValueChanged", function(_, value)
        if not IsLevelSliderEnabled() then
            return
        end
        local level = math.floor(value + 0.5)
        local view = LPL.DB:GetTalentView()
        view.level = level
        levelValue:SetText(tostring(level))
        frame:UpdatePoints()
        RenderTreeForLevel()
    end)

    function frame:UpdateLevelSlider()
        local enabled = IsLevelSliderEnabled()
        if enabled then
            self.levelRow:Show()
            toolbar:SetHeight(TOOLBAR_HEIGHT_WITH_LEVEL)
            local view = LPL.DB:GetTalentView()
            LPL.TalentTree:ResolveViewLevel(view)
            self.levelSlider:SetMinMaxValues(MIN_LEVEL, GetMaxLevel())
            if self.levelSlider.High then
                self.levelSlider.High:SetText(tostring(GetMaxLevel()))
            end
            self.levelSlider:SetValue(view.level)
            self.levelValue:SetText(tostring(view.level))
        else
            self.levelRow:Hide()
            toolbar:SetHeight(TOOLBAR_HEIGHT_COMPACT)
            LPL.TalentTree:ResolveViewLevel(LPL.DB:GetTalentView())
        end
    end

    function frame:UpdateSandboxStatus()
        local sandbox = self.talentsFrame and self.talentsFrame.sandbox
        if not sandbox then
            self.statusLabel:SetText("Open a build to plan talents")
            return
        end
        if sandbox:IsEmpty() then
            self.statusLabel:SetText("Click talents to plan your build · points update as you spend")
            return
        end
        local view = LPL.DB:GetTalentView()
        local summary = sandbox:GetSpentSummary(view.classID, view.specID, view.subTreeID, view.level)
        if summary then
        self.statusLabel:SetText(string.format(
            "Sandbox: %d nodes · Class %d · Spec %d · Hero %d · Save to keep changes",
            sandbox:CountPurchasedNodes(),
            summary.classSpent,
            summary.specSpent,
            summary.heroSpent
        ))
            return
        end
        self.statusLabel:SetText(string.format(
            "Sandbox: %d nodes, %d ranks loaded",
            sandbox:CountPurchasedNodes(),
            sandbox:CountPurchasedRanks()
        ))
    end

    function frame:UpdatePoints()
        local view = LPL.DB:GetTalentView()
        LPL.TalentTree:ResolveViewLevel(view)
        local sandbox = self.talentsFrame and self.talentsFrame.sandbox
        local summary = LPL.TalentTree:GetPointSummary(view.classID, view.specID, view.subTreeID, view.level, sandbox)
        if not summary then
            self.pointsLabel:SetText("")
            return
        end
        self.pointsLabel:SetText(string.format(
            "Class %s   Spec %s   Hero %s",
            FormatPool(summary.classSpent, summary.classMax),
            FormatPool(summary.specSpent, summary.specMax),
            FormatPool(summary.heroSpent, summary.heroMax)
        ))
        self:UpdateSandboxStatus()
    end

    function frame:LoadHeroes()
        local view = LPL.DB:GetTalentView()
        local heroes = LPL.TalentTree:GetHeroTalentsForSpec(view.specID)
        local valid = false
        for _, hero in ipairs(heroes) do
            if hero.id == view.subTreeID then
                valid = true
                break
            end
        end
        if not valid then
            view.subTreeID = heroes[1] and heroes[1].id
        end
        self.heroDrop:SetItems(heroes, view.subTreeID, function(id)
            view.subTreeID = id
            self:UpdatePoints()
            if self.onChange then
                self.onChange()
            end
        end)
    end

    function frame:LoadSpecs()
        local view = LPL.DB:GetTalentView()
        local specs = LPL.TalentTree:GetSpecsForClass(view.classID)
        local valid = false
        for _, spec in ipairs(specs) do
            if spec.id == view.specID then
                valid = true
                break
            end
        end
        if not valid then
            view.specID = specs[1] and specs[1].id
        end
        self.specDrop:SetItems(specs, view.specID, function(id)
            view.specID = id
            view.subTreeID = nil
            self:LoadHeroes()
            self:UpdatePoints()
            if self.onChange then
                self.onChange()
            end
        end)
        self:LoadHeroes()
    end

    function frame:LoadClasses()
        local view = LPL.DB:GetTalentView()
        local classes = LPL.TalentTree:GetClasses()
        self.classDrop:SetItems(classes, view.classID, function(id)
            view.classID = id
            view.specID = nil
            view.subTreeID = nil
            self:LoadSpecs()
            self:UpdatePoints()
            if self.onChange then
                self.onChange()
            end
        end)
        self:LoadSpecs()
    end

    function frame:Refresh()
        LPL.TalentTree:ResolveViewState()
        self:UpdateLevelSlider()
        self:LoadClasses()
        self:UpdatePoints()
        self:UpdateSandboxStatus()
    end

    frame:UpdateLevelSlider()

    return frame
end
