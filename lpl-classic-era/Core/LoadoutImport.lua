local addonName, LPL = ...

LPL.LoadoutImport = {}

local function FirstLoadoutSegment(rawSource, key)
    if type(rawSource) ~= "table" then
        return nil
    end
    local segments = rawSource[key]
    if type(segments) ~= "table" or #segments == 0 then
        return nil
    end
    return segments[1]
end

local function NormalizeImportName(importName, fallback)
    if LPL.TalentStore and LPL.TalentStore.NormalizeName then
        return LPL.TalentStore:NormalizeName(importName, fallback)
    end
    if LPL.LoadoutStore and LPL.LoadoutStore.NormalizeSetName then
        return LPL.LoadoutStore:NormalizeSetName(importName, fallback)
    end
    if type(importName) == "string" and importName ~= "" then
        return importName
    end
    return fallback or "Imported Loadout"
end

local function FindTalentByName(name)
    if not LPL.TalentStore or type(name) ~= "string" or name == "" then
        return nil
    end
    for _, build in ipairs(LPL.TalentStore:GetAll()) do
        if build.name == name then
            return build
        end
    end
    return nil
end

-- Match vault sets the way round-trip expects:
-- 1) embedded segment name from the export ("Side Bars")
-- 2) loadout import name ("test")
-- 3) set already linked on an existing loadout with that name
local function ResolveExistingSet(store, loadoutPath, segment, existingLoadout, pluralField)
    if not store then
        return nil, loadoutPath
    end

    local segmentName = type(segment) == "table" and type(segment.name) == "string" and segment.name ~= ""
        and segment.name
        or nil

    if segmentName and store.FindByName then
        local bySegment = store:FindByName(segmentName)
        if bySegment then
            return bySegment, bySegment.name or segmentName
        end
    end

    if type(loadoutPath) == "string" and loadoutPath ~= "" and store.FindByName then
        local byPath = store:FindByName(loadoutPath)
        if byPath then
            return byPath, byPath.name or loadoutPath
        end
    end

    if existingLoadout and pluralField and LPL.LoadoutStore and store.Get then
        local ids = LPL.LoadoutStore:GetSegmentIDs(existingLoadout, pluralField)
        local linked = ids[1] and store:Get(ids[1])
        if linked then
            return linked, linked.name or segmentName or loadoutPath
        end
    end

    return nil, segmentName or loadoutPath
end

local function SegmentCheckbox(label, displayName, exists)
    if exists then
        return string.format('Update %s "%s"', label, displayName)
    end
    return string.format('Add %s "%s"', label, displayName)
end

function LPL.LoadoutImport:IsLoadoutSource(rawSource)
    return type(rawSource) == "table" and rawSource.type == "loadout"
end

function LPL.LoadoutImport:BuildImportPreview(rawSource, importName)
    if not self:IsLoadoutSource(rawSource) then
        return nil, "Not a loadout import string."
    end

    importName = NormalizeImportName(importName, rawSource.name or "Imported Loadout")
    local loadoutPath = importName
    local existingLoadout = LPL.LoadoutStore and LPL.LoadoutStore:FindByName(loadoutPath) or nil

    local sections = {}
    local talentSegment = FirstLoadoutSegment(rawSource, "dftalents")
    local talentName = (talentSegment and talentSegment.name) or loadoutPath
    local existingBuild = FindTalentByName(talentName) or FindTalentByName(loadoutPath)
    if not existingBuild and existingLoadout and LPL.TalentStore then
        local ids = LPL.LoadoutStore:GetSegmentIDs(existingLoadout, "talentBuildIDs")
        existingBuild = ids[1] and LPL.TalentStore:Get(ids[1]) or nil
        if existingBuild then
            talentName = existingBuild.name or talentName
        end
    end

    if talentSegment then
        local displayName = (existingBuild and existingBuild.name) or talentName
        sections[#sections + 1] = {
            id = "talents",
            label = "Talents",
            path = displayName,
            available = true,
            exists = existingBuild ~= nil,
            checkboxLabel = SegmentCheckbox("Talents set", displayName, existingBuild ~= nil),
            defaultChecked = true,
        }
    end

    local actionSegment = FirstLoadoutSegment(rawSource, "actionbars")
    local existingActionBar, actionDisplay
    if actionSegment then
        existingActionBar, actionDisplay = ResolveExistingSet(
            LPL.ActionBarStore, loadoutPath, actionSegment, existingLoadout, "actionBarSetIDs"
        )
        sections[#sections + 1] = {
            id = "actionBars",
            label = "Action Bars",
            path = actionDisplay,
            available = true,
            exists = existingActionBar ~= nil,
            checkboxLabel = SegmentCheckbox("Action Bars set", actionDisplay, existingActionBar ~= nil),
            defaultChecked = true,
        }
    end

    local keybindSegment = FirstLoadoutSegment(rawSource, "keybinds")
    local existingKeybind, keybindDisplay
    if keybindSegment then
        existingKeybind, keybindDisplay = ResolveExistingSet(
            LPL.KeybindStore, loadoutPath, keybindSegment, existingLoadout, "keybindSetIDs"
        )
        sections[#sections + 1] = {
            id = "keybinds",
            label = "Keybinding Profiles",
            path = keybindDisplay,
            available = true,
            exists = existingKeybind ~= nil,
            checkboxLabel = SegmentCheckbox("keybinding profile", keybindDisplay, existingKeybind ~= nil),
            defaultChecked = true,
        }
    end

    local equipmentSegment = FirstLoadoutSegment(rawSource, "equipment")
    local existingEquipment, equipmentDisplay
    if equipmentSegment then
        existingEquipment, equipmentDisplay = ResolveExistingSet(
            LPL.EquipmentStore, loadoutPath, equipmentSegment, existingLoadout, "equipmentSetIDs"
        )
        sections[#sections + 1] = {
            id = "equipment",
            label = "Equipment",
            path = equipmentDisplay,
            available = true,
            exists = existingEquipment ~= nil,
            checkboxLabel = SegmentCheckbox("equipment set", equipmentDisplay, existingEquipment ~= nil),
            defaultChecked = true,
        }
    end

    local editModeSegment = FirstLoadoutSegment(rawSource, "editmode")
    local existingEditMode, editModeDisplay
    if editModeSegment then
        existingEditMode, editModeDisplay = ResolveExistingSet(
            LPL.EditModeStore, loadoutPath, editModeSegment, existingLoadout, "editModeSetIDs"
        )
        sections[#sections + 1] = {
            id = "editMode",
            label = "Edit Mode",
            path = editModeDisplay,
            available = true,
            exists = existingEditMode ~= nil,
            checkboxLabel = SegmentCheckbox("Edit Mode layout", editModeDisplay, existingEditMode ~= nil),
            defaultChecked = true,
        }
    end

    local addonSegment = FirstLoadoutSegment(rawSource, "addonsets")
    local existingAddonSet, addonDisplay
    if addonSegment then
        existingAddonSet, addonDisplay = ResolveExistingSet(
            LPL.AddonSetStore, loadoutPath, addonSegment, existingLoadout, "addonSetIDs"
        )
        sections[#sections + 1] = {
            id = "addonSets",
            label = "Addon Sets",
            path = addonDisplay,
            available = true,
            exists = existingAddonSet ~= nil,
            checkboxLabel = SegmentCheckbox("Addon Set", addonDisplay, existingAddonSet ~= nil),
            defaultChecked = true,
        }
    end

    if #sections == 0 then
        return nil, "Loadout has no importable Classic Era data."
    end

    return {
        importKind = "loadout",
        loadoutPath = loadoutPath,
        buildName = importName,
        existingBuildID = existingBuild and existingBuild.id or nil,
        existingActionBarID = existingActionBar and existingActionBar.id or nil,
        existingKeybindID = existingKeybind and existingKeybind.id or nil,
        existingEquipmentID = existingEquipment and existingEquipment.id or nil,
        existingEditModeID = existingEditMode and existingEditMode.id or nil,
        existingAddonSetID = existingAddonSet and existingAddonSet.id or nil,
        existingLoadoutID = existingLoadout and existingLoadout.id or nil,
        sections = sections,
        importData = talentSegment,
        rawSource = rawSource,
    }
end

function LPL.LoadoutImport:BuildImportPreviewFromText(text, importName)
    local rawSource = LPL.TalentShare:GetRawImportSource(text)
    if not rawSource then
        return nil, "Invalid share string."
    end
    return self:BuildImportPreview(rawSource, importName)
end
