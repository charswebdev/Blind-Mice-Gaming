local _, LPL = ...

LPL.EditModeAPI = LPL.EditModeAPI or {}
local API = LPL.EditModeAPI

local KEY = "editmode"

local function EnsureAPI()
    if not C_EditMode then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_EditMode")
        elseif LoadAddOn then
            pcall(LoadAddOn, "Blizzard_EditMode")
        end
    end
    return C_EditMode ~= nil
end

local function PresetCount()
    if Enum and Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues then
        local count = LPL:PlainNumber(Enum.EditModePresetLayoutsMeta.NumValues)
        if count and count >= 0 then
            return count
        end
    end
    if Enum and Enum.EditModePresetLayouts then
        local maxIndex = -1
        for _, value in pairs(Enum.EditModePresetLayouts) do
            local number = LPL:PlainNumber(value)
            if number and number > maxIndex then
                maxIndex = number
            end
        end
        if maxIndex >= 0 then
            return maxIndex + 1
        end
    end
    return 2
end

local function LayoutTypeCharacter(layoutType)
    local character = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character
    local plainType = LPL:PlainNumber(layoutType)
    local plainCharacter = LPL:PlainNumber(character)
    if plainCharacter then
        return plainType == plainCharacter
    end
    return plainType == 2
end

local function DesiredType(characterSpecific)
    if characterSpecific ~= false then
        if Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character then
            return Enum.EditModeLayoutType.Character
        end
        return 2
    end
    if Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account then
        return Enum.EditModeLayoutType.Account
    end
    return 1
end

local function IsPreset(layout)
    if type(layout) ~= "table" then
        return false
    end
    local preset = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset
    local plainType = LPL:PlainNumber(layout.layoutType)
    local plainPreset = LPL:PlainNumber(preset)
    if plainPreset then
        return plainType == plainPreset
    end
    return plainType == 0
end

local function LayoutName(layout)
    if type(layout) ~= "table" then
        return nil
    end
    return LPL:PlainString(layout.layoutName)
end

local function SameName(layout, name)
    local left = LayoutName(layout)
    local right = LPL:PlainString(name)
    return left and right and left == right
end

local function CountOfType(layouts, layoutType)
    local count = 0
    if type(layouts) ~= "table" then
        return 0
    end
    for _, layout in ipairs(layouts) do
        if type(layout) == "table" and layout.layoutType == layoutType then
            count = count + 1
        end
    end
    return count
end

local function MaxPerType()
    local value = Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType
    return LPL:PlainNumber(value) or 5
end

local function CleanLayoutName(name)
    name = LPL:PlainString(name) or "LPL Layout"
    if C_EditMode and C_EditMode.IsValidLayoutName then
        local ok, valid = pcall(C_EditMode.IsValidLayoutName, name)
        if ok and valid then
            return name
        end
    end
    local cleaned = name:gsub("[^%w%s%-%_]", ""):match("^%s*(.-)%s*$") or ""
    if cleaned == "" then
        cleaned = "LPL Layout"
    end
    if #cleaned > 40 then
        cleaned = cleaned:sub(1, 40)
    end
    return cleaned
end

local function ReadActiveLayout()
    if not EnsureAPI() or not C_EditMode.GetLayouts or not C_EditMode.ConvertLayoutInfoToString then
        return nil, "Edit Mode is not available on this client."
    end
    if InCombatLockdown and InCombatLockdown() then
        return nil, "Leave combat, then update the Edit Mode layout."
    end

    local infoOk, info = pcall(C_EditMode.GetLayouts)
    if not infoOk or type(info) ~= "table" or type(info.layouts) ~= "table" then
        return nil, "Could not read Edit Mode layouts."
    end

    local active = LPL:PlainNumber(info.activeLayout)
    if not active then
        return nil, "No active Edit Mode layout."
    end

    local presets = PresetCount()
    if active <= presets then
        return nil, "The active layout is a Blizzard preset. Open Edit Mode and choose a custom layout first."
    end

    local layout = info.layouts[active - presets]
    if type(layout) ~= "table" then
        return nil, "Could not find the active Edit Mode layout."
    end

    local callOk, layoutString = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
    local plain = callOk and LPL:PlainString(layoutString) or nil
    if not plain then
        return nil, "Edit Mode did not return a layout this addon can save."
    end
    return {
        layoutString = plain,
        characterSpecific = LayoutTypeCharacter(layout.layoutType),
    }
end

function API:Available()
    return EnsureAPI() and C_EditMode.GetLayouts ~= nil and C_EditMode.ConvertLayoutInfoToString ~= nil
end

function API:List()
    return LPL.SetStore:List(KEY)
end

function API:Get(id)
    return LPL.SetStore:Get(KEY, id)
end

function API:SuggestName()
    return LPL.SetStore:SuggestName(KEY, "Layout")
end

function API:Empty()
    return {
        name = self:SuggestName(),
        layoutString = "",
        characterSpecific = true,
    }
end

function API:Summary(set)
    local layout = LPL:PlainString(set and set.layoutString)
    if not layout then
        return "No layout captured"
    end
    if set and set.characterSpecific == false then
        return "Account layout"
    end
    return "Character layout"
end

function API:Capture()
    local layout, err = ReadActiveLayout()
    if not layout then
        return { layoutString = "", characterSpecific = true, error = err }
    end
    return layout
end

function API:Matches(set, live)
    local saved = LPL:PlainString(set and set.layoutString)
    if not saved then
        return false
    end
    live = live or self:Capture()
    local current = LPL:PlainString(live and live.layoutString)
    return current ~= nil and current == saved
end

local function RecordFrom(draft)
    return {
        layoutString = LPL:PlainString(draft and draft.layoutString) or "",
        characterSpecific = not (draft and draft.characterSpecific == false),
    }
end

function API:Save(draft, name)
    return LPL.SetStore:Save(KEY, RecordFrom(draft), name, self:SuggestName())
end

function API:Update(id, draft, name)
    return LPL.SetStore:Update(KEY, id, RecordFrom(draft), name, "Layout")
end

function API:Delete(id)
    return LPL.SetStore:Delete(KEY, id)
end

local function Remember(layoutString, name)
    local db = LPL.DB:Bind(false)
    if type(db.editmode) ~= "table" then
        return
    end
    db.editmode.lastApplied = layoutString
    db.editmode.lastAppliedName = name
end

function API:Apply(set)
    if not self:Available() then
        return false, "Edit Mode is not available on this client."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat, then apply this layout."
    end
    if not C_EditMode.SaveLayouts or not C_EditMode.SetActiveLayout or not C_EditMode.ConvertStringToLayoutInfo then
        return false, "This client cannot apply an Edit Mode layout."
    end

    local layoutString = LPL:PlainString(set and set.layoutString)
    if not layoutString then
        return false, "This layout is empty. Update from current character, then apply."
    end

    local parseOk, parsed = pcall(C_EditMode.ConvertStringToLayoutInfo, layoutString)
    if not parseOk or type(parsed) ~= "table" then
        return false, "This saved layout could not be read."
    end

    local layoutName = CleanLayoutName(set and set.name)
    local layoutType = DesiredType(set and set.characterSpecific)

    local infoOk, layouts = pcall(C_EditMode.GetLayouts)
    if not infoOk or type(layouts) ~= "table" or type(layouts.layouts) ~= "table" then
        return false, "Could not read Edit Mode layouts."
    end

    local removed = false
    for index = #layouts.layouts, 1, -1 do
        local layout = layouts.layouts[index]
        if layout and not IsPreset(layout) and SameName(layout, layoutName) then
            table.remove(layouts.layouts, index)
            removed = true
        end
    end
    if removed then
        local deleted = pcall(C_EditMode.SaveLayouts, layouts)
        if not deleted then
            return false, "Could not replace the existing Edit Mode layout."
        end
        infoOk, layouts = pcall(C_EditMode.GetLayouts)
        if not infoOk or type(layouts) ~= "table" or type(layouts.layouts) ~= "table" then
            return false, "Could not read Edit Mode layouts after replace."
        end
    end

    if CountOfType(layouts.layouts, layoutType) >= MaxPerType() then
        return false, "Edit Mode already has the maximum number of layouts of this type."
    end

    local newLayout = CopyTable(parsed)
    newLayout.layoutName = layoutName
    newLayout.layoutType = layoutType
    if EditModeManagerFrame and EditModeManagerFrame.ReconcileWithModern then
        pcall(EditModeManagerFrame.ReconcileWithModern, EditModeManagerFrame, newLayout)
    end

    table.insert(layouts.layouts, newLayout)
    local presets = PresetCount()
    local activeIndex = presets + #layouts.layouts
    layouts.activeLayout = activeIndex

    local saved = pcall(C_EditMode.SaveLayouts, layouts)
    if not saved then
        return false, "The game did not save this Edit Mode layout."
    end

    if C_EditMode.OnLayoutAdded then
        pcall(C_EditMode.OnLayoutAdded, activeIndex, true, true)
    end
    pcall(C_EditMode.SetActiveLayout, activeIndex)

    local verifyOk, verify = pcall(C_EditMode.GetLayouts)
    if verifyOk and type(verify) == "table" and type(verify.layouts) == "table" then
        for index, layout in ipairs(verify.layouts) do
            if SameName(layout, layoutName) then
                activeIndex = presets + index
                break
            end
        end
        verify.activeLayout = activeIndex
        pcall(C_EditMode.SaveLayouts, verify)
        pcall(C_EditMode.SetActiveLayout, activeIndex)
    end

    if EditModeManagerFrame and EditModeManagerFrame.UpdateLayoutInfo then
        local freshOk, fresh = pcall(C_EditMode.GetLayouts)
        if freshOk and type(fresh) == "table" then
            pcall(EditModeManagerFrame.UpdateLayoutInfo, EditModeManagerFrame, fresh)
        end
    end

    Remember(layoutString, layoutName)
    return true, "Applied this layout to Edit Mode."
end
