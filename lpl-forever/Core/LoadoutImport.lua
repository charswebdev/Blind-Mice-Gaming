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

function LPL.LoadoutImport:IsLoadoutSource(rawSource)
    return type(rawSource) == "table" and rawSource.type == "loadout"
end

function LPL.LoadoutImport:BuildImportPreview(rawSource, importName)
    if not self:IsLoadoutSource(rawSource) then
        return nil, "Not a loadout import string."
    end

    importName = LPL.BuildStore:NormalizeBuildName(importName, rawSource.name or "Imported Loadout")
    local loadoutPath = LPL.BuildStore:FormatLoadoutPath({ name = rawSource.name, specID = rawSource.specID }, importName)

    local talentText = LPL.TalentShare:EncodeShareTable(rawSource)
    local parseOk, talentData = LPL.TalentShare:ParseImportString(talentText or "")
    if not parseOk then
        talentData = nil
    end

    local sections = {}
    local existingBuild = LPL.BuildStore:FindByLoadoutPath(loadoutPath)

    if talentData then
        sections[#sections + 1] = {
            id = "talents",
            label = "Talents",
            path = loadoutPath,
            available = true,
            exists = existingBuild ~= nil,
            checkboxLabel = existingBuild
                and string.format('Use existing Talents set "%s"', loadoutPath)
                or string.format('Add Talents set "%s"', loadoutPath),
            defaultChecked = true,
        }

        if talentData.subTreeID or FirstLoadoutSegment(rawSource, "herotalents") then
            sections[#sections + 1] = {
                id = "hero",
                label = "Hero Talents",
                path = loadoutPath,
                available = true,
                exists = existingBuild ~= nil and existingBuild.subTreeID == talentData.subTreeID,
                checkboxLabel = existingBuild
                    and string.format('Use existing Hero Talents set "%s"', loadoutPath)
                    or string.format('Add Hero Talents set "%s"', loadoutPath),
                defaultChecked = true,
            }
        end
    end

    if FirstLoadoutSegment(rawSource, "actionbars") then
        local existingActionBar = LPL.ActionBarStore and LPL.ActionBarStore:FindByName(loadoutPath)
        sections[#sections + 1] = {
            id = "actionBars",
            label = "Action Bars",
            path = loadoutPath,
            available = true,
            exists = existingActionBar ~= nil,
            checkboxLabel = existingActionBar
                and string.format('Use existing Action Bars set "%s"', loadoutPath)
                or string.format('Add Action Bars set "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    if FirstLoadoutSegment(rawSource, "keybinds") then
        local existingKeybind = LPL.KeybindStore and LPL.KeybindStore:FindByName(loadoutPath)
        sections[#sections + 1] = {
            id = "keybinds",
            label = "Keybinding Profiles",
            path = loadoutPath,
            available = true,
            exists = existingKeybind ~= nil,
            checkboxLabel = existingKeybind
                and string.format('Use existing keybinding profile "%s"', loadoutPath)
                or string.format('Add keybinding profile "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    if FirstLoadoutSegment(rawSource, "equipment") then
        local existingEquipment = LPL.EquipmentStore and LPL.EquipmentStore:FindByName(loadoutPath)
        sections[#sections + 1] = {
            id = "equipment",
            label = "Equipment",
            path = loadoutPath,
            available = true,
            exists = existingEquipment ~= nil,
            checkboxLabel = existingEquipment
                and string.format('Use existing equipment set "%s"', loadoutPath)
                or string.format('Add equipment set "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    if FirstLoadoutSegment(rawSource, "pvptalents") then
        local existingPvp = LPL.PvpTalentStore and LPL.PvpTalentStore:FindByName(loadoutPath)
        sections[#sections + 1] = {
            id = "pvpTalents",
            label = "PvP Talents",
            path = loadoutPath,
            available = true,
            exists = existingPvp ~= nil,
            checkboxLabel = existingPvp
                and string.format('Use existing PvP set "%s"', loadoutPath)
                or string.format('Add PvP set "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    if FirstLoadoutSegment(rawSource, "cooldownmanager") then
        local existingCdm = LPL.CooldownManagerStore and LPL.CooldownManagerStore:FindByName(loadoutPath)
        sections[#sections + 1] = {
            id = "cooldownManager",
            label = "Cooldown Manager",
            path = loadoutPath,
            available = true,
            exists = existingCdm ~= nil,
            checkboxLabel = existingCdm
                and string.format('Use existing Cooldown Manager set "%s"', loadoutPath)
                or string.format('Add Cooldown Manager set "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    if FirstLoadoutSegment(rawSource, "editmode") then
        local existingEditMode = LPL.EditModeStore and LPL.EditModeStore:FindByName(loadoutPath)
        sections[#sections + 1] = {
            id = "editMode",
            label = "Edit Mode",
            path = loadoutPath,
            available = true,
            exists = existingEditMode ~= nil,
            checkboxLabel = existingEditMode
                and string.format('Use existing Edit Mode layout "%s"', loadoutPath)
                or string.format('Add Edit Mode layout "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    if FirstLoadoutSegment(rawSource, "addonsets") then
        local existingAddonSet = LPL.AddonSetStore and LPL.AddonSetStore:FindByName(loadoutPath)
        sections[#sections + 1] = {
            id = "addonSets",
            label = "Addon Sets",
            path = loadoutPath,
            available = true,
            exists = existingAddonSet ~= nil,
            checkboxLabel = existingAddonSet
                and string.format('Use existing Addon Set "%s"', loadoutPath)
                or string.format('Add Addon Set "%s"', loadoutPath),
            defaultChecked = true,
        }
    end

    if #sections == 0 then
        return nil, "Loadout has no importable data."
    end

    local existingActionBar = LPL.ActionBarStore and LPL.ActionBarStore:FindByName(loadoutPath)
    local existingKeybind = LPL.KeybindStore and LPL.KeybindStore:FindByName(loadoutPath)
    local existingEquipment = LPL.EquipmentStore and LPL.EquipmentStore:FindByName(loadoutPath)
    local existingPvp = LPL.PvpTalentStore and LPL.PvpTalentStore:FindByName(loadoutPath)
    local existingCdm = LPL.CooldownManagerStore and LPL.CooldownManagerStore:FindByName(loadoutPath)
    local existingEditMode = LPL.EditModeStore and LPL.EditModeStore:FindByName(loadoutPath)
    local existingAddonSet = LPL.AddonSetStore and LPL.AddonSetStore:FindByName(loadoutPath)
    local existingLoadout = LPL.LoadoutStore and LPL.LoadoutStore:FindByName(loadoutPath)

    return {
        importKind = "loadout",
        loadoutPath = loadoutPath,
        buildName = importName,
        existingBuildID = existingBuild and existingBuild.id or nil,
        existingActionBarID = existingActionBar and existingActionBar.id or nil,
        existingKeybindID = existingKeybind and existingKeybind.id or nil,
        existingEquipmentID = existingEquipment and existingEquipment.id or nil,
        existingPvpTalentID = existingPvp and existingPvp.id or nil,
        existingCooldownManagerID = existingCdm and existingCdm.id or nil,
        existingEditModeID = existingEditMode and existingEditMode.id or nil,
        existingAddonSetID = existingAddonSet and existingAddonSet.id or nil,
        existingLoadoutID = existingLoadout and existingLoadout.id or nil,
        sections = sections,
        importData = talentData,
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
