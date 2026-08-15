local addonName, LPL = ...

LPL.RestrictionsMenu = {}

local function ToggleRestrictionBucket(restrictions, key, id)
    restrictions = restrictions or {}
    restrictions[key] = restrictions[key] or {}
    if restrictions[key][id] then
        restrictions[key][id] = nil
        if not next(restrictions[key]) then
            restrictions[key] = nil
        end
    else
        restrictions[key][id] = true
    end
    return restrictions
end

local function GetClassOptions()
    return LPL.SetRestrictions:GetClassFilterOptions()
end

local function GetSpecOptions()
    return LPL.SetRestrictions:GetSpecFilterOptions()
end

local function GetCovenantOptions()
    return LPL.SetRestrictions:GetCovenantFilterOptions()
end

local function GetRaceOptions()
    return LPL.SetRestrictions:GetRaceFilterOptions()
end

local function AddMenuTitle(text, level)
    local info = UIDropDownMenu_CreateInfo()
    info.text = text
    info.isTitle = true
    info.notCheckable = true
    UIDropDownMenu_AddButton(info, level)
end

local function AddHeroTalentRestrictionMenu(record, onChanged, level)
    if not LPL.TalentTree or not LPL.TalentTree.GetClasses then
        return
    end

    local hasEntries = false
    for _, class in ipairs(LPL.TalentTree:GetClasses()) do
        local className = class.name or class.file
        local classHasHeroes = false

        for _, spec in ipairs(LPL.TalentTree:GetSpecsForClass(class.id)) do
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
                    info.checked = record.restrictions.herotalents and record.restrictions.herotalents[hero.id]
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.arg1 = hero.id
                    info.func = function(_, heroID)
                        ToggleRestrictionBucket(record.restrictions, "herotalents", heroID)
                        if onChanged then
                            onChanged(record)
                        end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        end
    end

    if not hasEntries then
        AddMenuTitle("No hero talents available", level)
    end
end

function LPL.RestrictionsMenu:Attach(button, getRecord, onChanged, supportedTypes)
    supportedTypes = supportedTypes or CopyTable(LPL.SetRestrictions.ALL_RESTRICTION_TYPES)

    local supported = {}
    for _, restrictionType in ipairs(supportedTypes) do
        supported[restrictionType] = true
    end

    local function Initialize(_, level, menuList)
        local record = getRecord and getRecord()
        if not record then
            record = { restrictions = {} }
        end
        record.restrictions = LPL.SetRestrictions:NormalizeRestrictions(record.restrictions or {})

        if level == 1 then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Restrictions limit where a set can be activated."
            info.isTitle = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)

            if supported.character then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Current Character Only"
                info.checked = type(record.restrictions.character) == "string"
                    and record.restrictions.character == LPL.Character:GetSlug()
                info.isNotRadio = false
                info.keepShownOnClick = true
                info.func = function()
                    local slug = LPL.Character:GetSlug()
                    if record.restrictions.character == slug then
                        record.restrictions.character = nil
                    elseif slug then
                        record.restrictions.character = slug
                    end
                    if onChanged then
                        onChanged(record)
                    end
                end
                UIDropDownMenu_AddButton(info, level)
            end

            if supported.class and LPL.TalentTree then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Class"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "class"
                UIDropDownMenu_AddButton(info, level)
            end

            if supported.spec and LPL.TalentTree then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Specialization"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "spec"
                UIDropDownMenu_AddButton(info, level)
            end

            if supported.herotalents and LPL.TalentTree then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Hero Talents"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "herotalents"
                UIDropDownMenu_AddButton(info, level)
            end

            if supported.race then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Race"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "race"
                UIDropDownMenu_AddButton(info, level)
            end

            if supported.covenant then
                info = UIDropDownMenu_CreateInfo()
                info.text = "Covenant"
                info.notCheckable = true
                info.hasArrow = true
                info.menuList = "covenant"
                UIDropDownMenu_AddButton(info, level)
            end

            info = UIDropDownMenu_CreateInfo()
            info.text = "Clear Restrictions"
            info.notCheckable = true
            info.func = function()
                record.restrictions = {}
                if onChanged then
                    onChanged(record)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        elseif level == 2 then
            menuList = menuList or UIDROPDOWNMENU_MENU_VALUE

            if menuList == "spec" then
                for _, spec in ipairs(GetSpecOptions()) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = spec.label
                    info.checked = record.restrictions.spec and record.restrictions.spec[spec.id]
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.arg1 = spec.id
                    info.func = function(_, specID)
                        ToggleRestrictionBucket(record.restrictions, "spec", specID)
                        if onChanged then
                            onChanged(record)
                        end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            elseif menuList == "class" then
                for _, class in ipairs(GetClassOptions()) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = class.label
                    info.checked = record.restrictions.class and record.restrictions.class[class.id]
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.arg1 = class.id
                    info.func = function(_, classFile)
                        ToggleRestrictionBucket(record.restrictions, "class", classFile)
                        if onChanged then
                            onChanged(record)
                        end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            elseif menuList == "race" then
                for _, race in ipairs(GetRaceOptions()) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = race.label
                    info.checked = record.restrictions.race and record.restrictions.race[race.id]
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.arg1 = race.id
                    info.func = function(_, raceID)
                        ToggleRestrictionBucket(record.restrictions, "race", raceID)
                        if onChanged then
                            onChanged(record)
                        end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            elseif menuList == "covenant" then
                for _, covenant in ipairs(GetCovenantOptions()) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = covenant.label
                    info.checked = record.restrictions.covenant and record.restrictions.covenant[covenant.id]
                    info.isNotRadio = true
                    info.keepShownOnClick = true
                    info.arg1 = covenant.id
                    info.func = function(_, covenantID)
                        ToggleRestrictionBucket(record.restrictions, "covenant", covenantID)
                        if onChanged then
                            onChanged(record)
                        end
                    end
                    UIDropDownMenu_AddButton(info, level)
                end
            elseif menuList == "herotalents" then
                AddHeroTalentRestrictionMenu(record, onChanged, level)
            end
        end
    end

    local dropdown = CreateFrame("Frame", "LPLRestrictionsDropdown" .. tostring(button), UIParent, "UIDropDownMenuTemplate")
    dropdown:Hide()

    UIDropDownMenu_Initialize(dropdown, Initialize, "MENU")
    button:SetScript("OnClick", function(self)
        ToggleDropDownMenu(1, nil, dropdown, self, 0, 0)
    end)
end
