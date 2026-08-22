local addonName, LPL = ...

LPL.EditModeCodec = {}

local function GetPresetLayoutCount()
    if Enum and Enum.EditModePresetLayoutsMeta and Enum.EditModePresetLayoutsMeta.NumValues then
        return Enum.EditModePresetLayoutsMeta.NumValues
    end
    -- Classic enum is often 0. Never use (Classic or 1)+1 — that collapses to 1 and
    -- points SetActiveLayout at a Blizzard preset, so HUD snaps back after reload.
    if Enum and Enum.EditModePresetLayouts then
        local maxIndex = -1
        for _, value in pairs(Enum.EditModePresetLayouts) do
            if type(value) == "number" and value > maxIndex then
                maxIndex = value
            end
        end
        if maxIndex >= 0 then
            return maxIndex + 1
        end
    end
    return 2
end

local function IsCharacterLayoutType(layoutType)
    if Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Character then
        return layoutType == Enum.EditModeLayoutType.Character
    end
    return layoutType == 2
end

function LPL.EditModeCodec:NormalizeLayoutString(text)
    if type(text) ~= "string" then
        return ""
    end
    text = text:match("^%s*(.-)%s*$") or ""
    return text
end

function LPL.EditModeCodec:SanitizeDraft(draft)
    if type(draft) ~= "table" then
        return draft
    end
    draft.layoutString = self:NormalizeLayoutString(draft.layoutString)
    if draft.editModeCharacterSpecific == nil then
        draft.editModeCharacterSpecific = true
    else
        draft.editModeCharacterSpecific = draft.editModeCharacterSpecific ~= false
    end
    return draft
end

function LPL.EditModeCodec:EnsureAPI()
    if not C_EditMode then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_EditMode")
        elseif LoadAddOn then
            pcall(LoadAddOn, "Blizzard_EditMode")
        end
    end
    return C_EditMode ~= nil
end

function LPL.EditModeCodec:IsAvailable()
    if not self:EnsureAPI() then
        return false, "Edit Mode API is unavailable."
    end
    if not C_EditMode.GetLayouts then
        return false, "Could not read Edit Mode layouts."
    end
    if not C_EditMode.ConvertLayoutInfoToString then
        return false, "Could not serialize Edit Mode layouts."
    end
    return true
end

function LPL.EditModeCodec:CanCaptureFromCharacter()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot update Edit Mode layouts in combat."
    end
    return self:IsAvailable()
end

function LPL.EditModeCodec:GetActiveLayoutInfo()
    local ok, err = self:IsAvailable()
    if not ok then
        return nil, err
    end

    if EditModeManagerFrame and EditModeManagerFrame.GetActiveLayoutInfo then
        local callOk, layout = pcall(EditModeManagerFrame.GetActiveLayoutInfo, EditModeManagerFrame)
        if callOk and type(layout) == "table" and type(layout.systems) == "table" then
            return layout
        end
    end

    local info = C_EditMode.GetLayouts()
    if type(info) ~= "table" or type(info.layouts) ~= "table" then
        return nil, "Could not read Edit Mode layouts."
    end

    local active = tonumber(info.activeLayout)
    if not active then
        return nil, "No active Edit Mode layout."
    end

    local presets = GetPresetLayoutCount()
    if active <= presets then
        return nil, "Active layout is a Blizzard preset. Select or create a custom layout first."
    end

    local layout = info.layouts[active - presets]
    if type(layout) ~= "table" or type(layout.systems) ~= "table" then
        return nil, "Could not find the active Edit Mode layout."
    end
    return layout
end

function LPL.EditModeCodec:GetCurrentLayoutString()
    local layout, err = self:GetActiveLayoutInfo()
    if not layout then
        return "", err
    end

    local callOk, layoutString = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
    if not callOk or type(layoutString) ~= "string" then
        return "", "Failed to convert Edit Mode layout to a string."
    end
    return self:NormalizeLayoutString(layoutString)
end

function LPL.EditModeCodec:CaptureFromCharacter(draft)
    draft = draft or {}
    local ok, err = self:CanCaptureFromCharacter()
    if not ok then
        return nil, err
    end

    local layout, layoutErr = self:GetActiveLayoutInfo()
    if not layout then
        return nil, layoutErr or "Could not read the active Edit Mode layout."
    end

    local callOk, layoutString = pcall(C_EditMode.ConvertLayoutInfoToString, layout)
    if not callOk or type(layoutString) ~= "string" then
        return nil, "Failed to convert Edit Mode layout to a string."
    end

    layoutString = self:NormalizeLayoutString(layoutString)
    if layoutString == "" then
        return nil, "Edit Mode returned an empty layout string."
    end

    draft.layoutString = layoutString
    draft.editModeCharacterSpecific = IsCharacterLayoutType(layout.layoutType)
    return self:SanitizeDraft(draft)
end

function LPL.EditModeCodec:ParseLayoutString(layoutString)
    layoutString = self:NormalizeLayoutString(layoutString)
    if layoutString == "" then
        return nil, "Missing Edit Mode layout string."
    end
    if not self:EnsureAPI() or not C_EditMode.ConvertStringToLayoutInfo then
        return nil, "Edit Mode API is unavailable."
    end

    local callOk, layoutInfo = pcall(C_EditMode.ConvertStringToLayoutInfo, layoutString)
    if not callOk or type(layoutInfo) ~= "table" then
        return nil, "Invalid Edit Mode layout string."
    end
    return layoutInfo
end

function LPL.EditModeCodec:LooksLikeLayoutString(text)
    text = self:NormalizeLayoutString(text)
    if text == "" then
        return false
    end
    if self:EnsureAPI() and C_EditMode.ConvertStringToLayoutInfo then
        local layoutInfo = self:ParseLayoutString(text)
        if layoutInfo then
            return true
        end
    end
    return #text >= 8
end

local function GetDesiredLayoutType(characterSpecific)
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

local function ResolveLayoutName(name)
    name = LPL.EditModeStore and LPL.EditModeStore:NormalizeSetName(name, "LPL Layout") or tostring(name or "LPL Layout")
    if C_EditMode and C_EditMode.IsValidLayoutName and C_EditMode.IsValidLayoutName(name) then
        return name
    end

    local cleaned = name:gsub("[^%w%s%-%_]", ""):match("^%s*(.-)%s*$") or ""
    if cleaned ~= "" and C_EditMode and C_EditMode.IsValidLayoutName and C_EditMode.IsValidLayoutName(cleaned) then
        return cleaned
    end
    if C_EditMode and C_EditMode.IsValidLayoutName and C_EditMode.IsValidLayoutName("LPL Layout") then
        return "LPL Layout"
    end
    return cleaned ~= "" and cleaned or "LPL"
end

local function CountLayoutsOfType(layouts, layoutType)
    local count = 0
    for _, layout in ipairs(layouts or {}) do
        if layout and layout.layoutType == layoutType then
            count = count + 1
        end
    end
    return count
end

local function GetMaxLayoutsPerType()
    if Constants and Constants.EditModeConsts and Constants.EditModeConsts.EditModeMaxLayoutsPerType then
        return Constants.EditModeConsts.EditModeMaxLayoutsPerType
    end
    return 5
end

function LPL.EditModeCodec:CanApplyToCharacter()
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot apply Edit Mode layouts in combat."
    end
    local ok, err = self:IsAvailable()
    if not ok then
        return false, err
    end
    if not C_EditMode.SaveLayouts or not C_EditMode.SetActiveLayout then
        return false, "Could not apply Edit Mode layout data."
    end
    if not C_EditMode.ConvertStringToLayoutInfo then
        return false, "Could not parse Edit Mode layout string."
    end
    return true
end

local function IsPresetLayout(layout)
    if not layout then
        return false
    end
    if Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Preset then
        return layout.layoutType == Enum.EditModeLayoutType.Preset
    end
    return layout.layoutType == 0
end

-- Edit Mode is only safe to write after account settings exist (EDIT_MODE_LAYOUTS_UPDATED).
local function EnsureEditModeReady()
    if not LPL.EditModeCodec:EnsureAPI() then
        return nil, "Edit Mode API is unavailable."
    end

    -- Classic Era may never populate accountSettings until HUD Edit is opened.
    -- C_EditMode.GetLayouts / SaveLayouts / SetActiveLayout still work without it.
    if not EditModeManagerFrame then
        if C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_EditMode")
        elseif LoadAddOn then
            pcall(LoadAddOn, "Blizzard_EditMode")
        end
    end

    if EditModeManagerFrame then
        if not EditModeManagerFrame.accountSettings then
            local info = C_EditMode.GetLayouts()
            if type(info) == "table" and EditModeManagerFrame.UpdateLayoutInfo then
                pcall(EditModeManagerFrame.UpdateLayoutInfo, EditModeManagerFrame, info)
            end
            if EditModeManagerFrame.InitializeAccountSettings then
                pcall(EditModeManagerFrame.InitializeAccountSettings, EditModeManagerFrame)
            end
        end
        return EditModeManagerFrame
    end

    if C_EditMode and C_EditMode.GetLayouts and C_EditMode.SaveLayouts and C_EditMode.SetActiveLayout then
        return true
    end

    return nil, "Edit Mode layouts are still loading. Try Activate again in a moment."
end

local function ReconcileLayout(layout)
    if EditModeManagerFrame and EditModeManagerFrame.ReconcileWithModern then
        pcall(EditModeManagerFrame.ReconcileWithModern, EditModeManagerFrame, layout)
    end
end

local function RefreshEditModeManager()
    if EditModeManagerFrame and EditModeManagerFrame.UpdateLayoutInfo then
        local info = C_EditMode.GetLayouts()
        if type(info) == "table" then
            pcall(EditModeManagerFrame.UpdateLayoutInfo, EditModeManagerFrame, info)
        end
    elseif EditModeManagerFrame and EditModeManagerFrame.UpdateSystems then
        pcall(EditModeManagerFrame.UpdateSystems, EditModeManagerFrame)
    end
    if UIParent_ManageFramePositions then
        pcall(UIParent_ManageFramePositions)
    end
end

function LPL.EditModeCodec:ApplyLayoutString(layoutString, options)
    layoutString = self:NormalizeLayoutString(layoutString)
    if layoutString == "" then
        return false, "This layout has no Edit Mode layout string."
    end

    local ok, err = self:CanApplyToCharacter()
    if not ok then
        return false, err
    end

    local _, readyErr = EnsureEditModeReady()
    if readyErr then
        return false, readyErr
    end

    options = options or {}
    local parsed, parseErr = self:ParseLayoutString(layoutString)
    if not parsed then
        return false, parseErr or "Invalid Edit Mode layout string."
    end

    local layoutName = ResolveLayoutName(options.name or parsed.layoutName or "LPL Layout")
    if C_EditMode.IsValidLayoutName and not C_EditMode.IsValidLayoutName(layoutName) then
        return false, "Edit Mode rejected that layout name."
    end

    local layoutType = GetDesiredLayoutType(options.editModeCharacterSpecific)

    -- GetLayouts() returns customs only. SaveLayouts expects that same shape;
    -- activeLayout is a merged index (presets + custom index). Proven GlitchedUI path.
    local editModeLayouts = C_EditMode.GetLayouts()
    if type(editModeLayouts) ~= "table" or type(editModeLayouts.layouts) ~= "table" then
        return false, "Could not read Edit Mode layouts."
    end

    -- Remove any existing custom with this name, then re-add so systems always replace.
    local removed = false
    for index = #editModeLayouts.layouts, 1, -1 do
        local layout = editModeLayouts.layouts[index]
        if layout and not IsPresetLayout(layout) and layout.layoutName == layoutName then
            table.remove(editModeLayouts.layouts, index)
            removed = true
        end
    end
    if removed then
        local deleted = pcall(C_EditMode.SaveLayouts, editModeLayouts)
        if not deleted then
            return false, "Failed to replace existing Edit Mode layout."
        end
        editModeLayouts = C_EditMode.GetLayouts()
        if type(editModeLayouts) ~= "table" or type(editModeLayouts.layouts) ~= "table" then
            return false, "Could not read Edit Mode layouts after replace."
        end
    end

    if CountLayoutsOfType(editModeLayouts.layouts, layoutType) >= GetMaxLayoutsPerType() then
        return false, "Edit Mode is at the maximum number of layouts for this type."
    end

    local newLayout = CopyTable(parsed)
    newLayout.layoutName = layoutName
    newLayout.layoutType = layoutType
    ReconcileLayout(newLayout)

    table.insert(editModeLayouts.layouts, newLayout)
    local presets = GetPresetLayoutCount()
    local activeIndex = presets + #editModeLayouts.layouts
    editModeLayouts.activeLayout = activeIndex

    local saved = pcall(C_EditMode.SaveLayouts, editModeLayouts)
    if not saved then
        return false, "Failed to save Edit Mode layout."
    end

    -- OnLayoutAdded is required for the client/server active layout to stick.
    if C_EditMode.OnLayoutAdded then
        pcall(C_EditMode.OnLayoutAdded, activeIndex, true, true)
    end
    pcall(C_EditMode.SetActiveLayout, activeIndex)

    -- Re-save after SetActiveLayout so the chosen index survives logout/reload.
    local verify = C_EditMode.GetLayouts()
    if type(verify) == "table" and type(verify.layouts) == "table" then
        local confirmed = nil
        for index, layout in ipairs(verify.layouts) do
            if layout and layout.layoutName == layoutName then
                confirmed = presets + index
                break
            end
        end
        if confirmed then
            activeIndex = confirmed
        end
        verify.activeLayout = activeIndex
        pcall(C_EditMode.SaveLayouts, verify)
        pcall(C_EditMode.SetActiveLayout, activeIndex)
    end

    if EventRegistry and EventRegistry.TriggerEvent then
        pcall(EventRegistry.TriggerEvent, EventRegistry, "EditMode.SavedLayouts")
    end

    -- Do NOT Show/Hide EditModeManagerFrame: OnHide -> ExitEditMode -> RevertAllChanges.
    RefreshEditModeManager()

    if LPL.EditModePersist and LPL.EditModePersist.RememberApplied then
        LPL.EditModePersist:RememberApplied(layoutString, {
            name = layoutName,
            editModeCharacterSpecific = options.editModeCharacterSpecific,
            setID = options.setID,
        })
    end

    return true
end
