local addonName, LPL = ...

LPL.ListChrome = {
    HEIGHT = 34,
}

local function ListContains(list, value)
    if type(list) ~= "table" then
        return false
    end
    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end
    return false
end

local function GetClassOptions()
    return LPL.SetRestrictions:GetClassFilterOptions()
end

local function GetSpecOptions(classFile)
    return LPL.SetRestrictions:GetSpecFilterOptions(classFile)
end

local function GetRaceOptions()
    return LPL.SetRestrictions:GetRaceFilterOptions()
end

local function GetCovenantOptions()
    return LPL.SetRestrictions:GetCovenantFilterOptions()
end

local function GetRoleOptions()
    return LPL.SetRestrictions:GetRoleFilterOptions()
end

local function HeroTalentExists(heroTalentID, classFile, specID)
    if not LPL.TalentTree or not LPL.TalentTree.GetClasses then
        return false
    end
    heroTalentID = tonumber(heroTalentID)
    specID = specID and tonumber(specID) or nil

    for _, class in ipairs(LPL.TalentTree:GetClasses()) do
        if not classFile or class.file == classFile then
            for _, spec in ipairs(LPL.TalentTree:GetSpecsForClass(class.id)) do
                if not specID or spec.id == specID then
                    for _, hero in ipairs(LPL.TalentTree:GetHeroTalentsForSpec(spec.id)) do
                        if hero.id == heroTalentID then
                            return true
                        end
                    end
                end
            end
            if classFile then
                break
            end
        end
    end
    return false
end

local function AddMenuTitle(text, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = text
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
end

function LPL.ListChrome:Create(parent, config)
    config = config or {}

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(self.HEIGHT)

    local search = LPL:CreateEditBox(nil, frame, 180)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    search:SetHeight(28)
    search.editBox:SetScript("OnTextChanged", function()
        if frame.onChanged then
            frame.onChanged()
        end
    end)

    local searchHint = search.editBox:CreateFontString(nil, "ARTWORK")
    searchHint:SetFontObject(LPL.Theme.fonts.small)
    searchHint:SetTextColor(LPL.Theme:GetColor("textMuted"))
    searchHint:SetPoint("LEFT", search.editBox, "LEFT", 4, 0)
    searchHint:SetText("Search...")
    searchHint:SetAlpha(0.85)
    search.editBox:HookScript("OnTextChanged", function(editBox)
        searchHint:SetShown(editBox:GetText() == "")
    end)
    search.editBox:HookScript("OnEditFocusGained", function()
        searchHint:Hide()
    end)
    search.editBox:HookScript("OnEditFocusLost", function(editBox)
        searchHint:SetShown(editBox:GetText() == "")
    end)

    local filterButton = LPL:CreateButton(nil, frame)
    filterButton:SetSize(72, 28)
    filterButton:SetPoint("LEFT", search, "RIGHT", 8, 0)
    filterButton:SetText("Filter")

    local clearButton = LPL:CreateButton(nil, frame)
    clearButton:SetSize(56, 28)
    clearButton:SetPoint("LEFT", filterButton, "RIGHT", 6, 0)
    clearButton:SetText("Clear")
    clearButton:Hide()

    frame.listKey = config.listKey or "default"
    local rawFilters = config.supportedFilters or CopyTable(LPL.SetRestrictions.ALL_LIST_FILTERS)
    frame.supportedFilters = {}
    for _, filterType in ipairs(rawFilters) do
        if not LPL.FlavorCompat or LPL.FlavorCompat:SupportsRestrictionType(filterType) then
            frame.supportedFilters[#frame.supportedFilters + 1] = filterType
        end
    end
    frame.filters = LPL.SetRestrictions:GetFilterStorage(frame.listKey)
    if LPL.FlavorCompat then
        if not LPL.FlavorCompat.hasHeroTalents then
            frame.filters.herotalents = nil
        end
        if not LPL.FlavorCompat.hasCovenant then
            frame.filters.covenant = nil
        end
    end
    frame.search = search
    frame.filterButton = filterButton
    frame.clearButton = clearButton

    local hasFilterTypes = #frame.supportedFilters > 0
    filterButton:SetShown(hasFilterTypes)
    if not hasFilterTypes then
        clearButton:ClearAllPoints()
        clearButton:SetPoint("LEFT", search, "RIGHT", 8, 0)
    end

    local function HasActiveFilters()
        if (search:GetText() or "") ~= "" then
            return true
        end
        for key, value in pairs(frame.filters) do
            if value and value ~= false then
                return true
            end
        end
        return false
    end

    local function UpdateClearButton()
        clearButton:SetShown(HasActiveFilters())
    end

    local function ClearInvalidDependentFilters()
        if frame.filters.spec and frame.filters.class then
            local valid = false
            for _, spec in ipairs(GetSpecOptions(frame.filters.class)) do
                if spec.id == frame.filters.spec then
                    valid = true
                    break
                end
            end
            if not valid then
                frame.filters.spec = nil
            end
        end
        if frame.filters.herotalents and not HeroTalentExists(frame.filters.herotalents, frame.filters.class, frame.filters.spec) then
            frame.filters.herotalents = nil
        end
    end

    function frame:GetQuery()
        return search:GetText() or ""
    end

    function frame:GetFilters()
        return frame.filters
    end

    function frame:ClearFilters()
        search:SetText("")
        wipe(frame.filters)
        UpdateClearButton()
        if self.onChanged then
            self.onChanged()
        end
    end

    clearButton:SetScript("OnClick", function()
        frame:ClearFilters()
    end)

    local function AddClassFilterMenu(level)
        local options = GetClassOptions()
        if #options == 0 then
            AddMenuTitle("No classes available", level)
            return
        end
        for _, class in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = class.label
            info.checked = frame.filters.class == class.id
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.notCheckable = false
            info.arg1 = class.id
            info.func = function(_, classFile)
                if frame.filters.class == classFile then
                    frame.filters.class = nil
                else
                    frame.filters.class = classFile
                end
                ClearInvalidDependentFilters()
                UpdateClearButton()
                if frame.onChanged then
                    frame.onChanged()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    local function AddSpecFilterMenu(level)
        local options = GetSpecOptions(frame.filters.class)
        if #options == 0 then
            AddMenuTitle("No specializations available", level)
            return
        end
        for _, spec in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = spec.label
            info.checked = frame.filters.spec == spec.id
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.notCheckable = false
            info.arg1 = spec.id
            info.func = function(_, specID)
                if frame.filters.spec == specID then
                    frame.filters.spec = nil
                else
                    frame.filters.spec = specID
                end
                ClearInvalidDependentFilters()
                UpdateClearButton()
                if frame.onChanged then
                    frame.onChanged()
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    local function AddHeroTalentFilterMenu(level)
        if not LPL.TalentTree or not LPL.TalentTree.GetClasses then
            return
        end

        local classFile = frame.filters.class
        local specID = frame.filters.spec and tonumber(frame.filters.spec) or nil
        local hasEntries = false

        for _, class in ipairs(LPL.TalentTree:GetClasses()) do
            if not classFile or class.file == classFile then
                local className = class.name or class.file
                local classHasHeroes = false

                for _, spec in ipairs(LPL.TalentTree:GetSpecsForClass(class.id)) do
                    if not specID or spec.id == specID then
                        local heroes = LPL.TalentTree:GetHeroTalentsForSpec(spec.id)
                        if #heroes > 0 then
                            if not classHasHeroes then
                                AddMenuTitle(LPL.Theme:WrapClassFileText(class.file, className), level)
                                classHasHeroes = true
                                hasEntries = true
                            end

                            local specName = spec.name or tostring(spec.id)
                            AddMenuTitle(LPL.Theme:WrapClassFileText(class.file, specName), level)

                            for _, hero in ipairs(heroes) do
                                local info = UIDropDownMenu_CreateInfo()
                                info.text = hero.name or tostring(hero.id)
                                info.checked = frame.filters.herotalents == hero.id
                                info.isNotRadio = true
                                info.keepShownOnClick = true
                                info.notCheckable = false
                                info.arg1 = hero.id
                                info.func = function(_, heroTalentID)
                                    if frame.filters.herotalents == heroTalentID then
                                        frame.filters.herotalents = nil
                                    else
                                        frame.filters.herotalents = heroTalentID
                                    end
                                    UpdateClearButton()
                                    if frame.onChanged then
                                        frame.onChanged()
                                    end
                                end
                                UIDropDownMenu_AddButton(info, level)
                            end
                        end
                    end
                end

                if classFile then
                    break
                end
            end
        end

        if not hasEntries then
            AddMenuTitle("No hero talents available", level)
        end
    end

    local function InitializeFilterMenu(_, level, menuList)
        level = level or 1
        menuList = menuList or UIDROPDOWNMENU_MENU_VALUE

        if level == 1 then
            local info = UIDropDownMenu_CreateInfo()
            info.notCheckable = true
            info.isNotRadio = true

            if ListContains(frame.supportedFilters, "character") then
                info.text = "Current Character Only"
                info.checked = frame.filters.characterOnly == true
                info.isNotRadio = false
                info.keepShownOnClick = true
                info.notCheckable = false
                info.func = function()
                    if frame.filters.characterOnly then
                        frame.filters.characterOnly = nil
                    else
                        frame.filters.characterOnly = true
                    end
                    UpdateClearButton()
                    if frame.onChanged then
                        frame.onChanged()
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end

            if ListContains(frame.supportedFilters, "class") then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Class"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "class"
                UIDropDownMenu_AddButton(info, level)
            end

            if ListContains(frame.supportedFilters, "spec") then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Specialization"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "spec"
                UIDropDownMenu_AddButton(info, level)
            end

            if ListContains(frame.supportedFilters, "herotalents") then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Hero Talents"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "herotalents"
                UIDropDownMenu_AddButton(info, level)
            end

            if ListContains(frame.supportedFilters, "role") then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Role"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "role"
                UIDropDownMenu_AddButton(info, level)
            end

            if ListContains(frame.supportedFilters, "race") then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Race"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "race"
                UIDropDownMenu_AddButton(info, level)
            end

            if ListContains(frame.supportedFilters, "covenant") then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Covenant"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "covenant"
                UIDropDownMenu_AddButton(info, level)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = "Clear Filters"
            info.notCheckable = true
            info.func = function()
                frame:ClearFilters()
            end
            UIDropDownMenu_AddButton(info, level)
        elseif level == 2 then
            if menuList == "class" then
                AddClassFilterMenu(level)
            elseif menuList == "spec" then
                AddSpecFilterMenu(level)
            elseif menuList == "herotalents" then
                AddHeroTalentFilterMenu(level)
            elseif menuList == "role" then
                for _, role in ipairs(GetRoleOptions()) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = role.label
                    info.checked = frame.filters.role == role.id
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.notCheckable = false
                    info.arg1 = role.id
                    info.func = function(_, roleID)
                        if frame.filters.role == roleID then
                            frame.filters.role = nil
                        else
                            frame.filters.role = roleID
                        end
                        UpdateClearButton()
                        if frame.onChanged then
                            frame.onChanged()
                        end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            elseif menuList == "race" then
                for _, race in ipairs(GetRaceOptions()) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = race.label
                    info.checked = frame.filters.race == race.id
                        or (frame.filters.race ~= nil and tostring(frame.filters.race) == tostring(race.id))
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.notCheckable = false
                    info.arg1 = race.id
                    info.func = function(_, raceID)
                        if frame.filters.race == raceID then
                            frame.filters.race = nil
                        else
                            frame.filters.race = raceID
                        end
                        UpdateClearButton()
                        if frame.onChanged then
                            frame.onChanged()
                        end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            elseif menuList == "covenant" then
                for _, covenant in ipairs(GetCovenantOptions()) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = covenant.label
                    info.checked = frame.filters.covenant == covenant.id
                        or (frame.filters.covenant ~= nil and tostring(frame.filters.covenant) == tostring(covenant.id))
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.notCheckable = false
                    info.arg1 = covenant.id
                    info.func = function(_, covenantID)
                        if frame.filters.covenant == covenantID then
                            frame.filters.covenant = nil
                        else
                            frame.filters.covenant = covenantID
                        end
                        UpdateClearButton()
                        if frame.onChanged then
                            frame.onChanged()
                        end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end

    local filterDropdown = CreateFrame("Frame", "LPLListFilterDropdown" .. frame.listKey, UIParent, "UIDropDownMenuTemplate")
    filterDropdown:Hide()
    frame.filterDropdown = filterDropdown

    UIDropDownMenu_Initialize(filterDropdown, InitializeFilterMenu, "MENU")
    filterButton:SetScript("OnClick", function(button)
        ToggleDropDownMenu(1, nil, filterDropdown, button, 0, 0)
    end)

    search.editBox:HookScript("OnTextChanged", UpdateClearButton)

    function frame:SetOnChanged(callback)
        self.onChanged = callback
    end

    return frame
end
