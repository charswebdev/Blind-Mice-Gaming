local addonName, LPL = ...

LPL.LoadoutShare = {}

local share = LPL.TalentShare

local function CopyRestrictions(source)
    if LPL.SetRestrictions and LPL.SetRestrictions.CopyRestrictions then
        return LPL.SetRestrictions:CopyRestrictions(source or {})
    end
    return CopyTable(source or {})
end

local function StripType(payload)
    if type(payload) ~= "table" then
        return nil
    end
    return CopyTable(payload)
end

function LPL.LoadoutShare:CountSegmentsInPayload(payload)
    if type(payload) ~= "table" then
        return 0
    end
    local count = 0
    if type(payload.dftalents) == "table" and #payload.dftalents > 0 then
        count = count + 1
    end
    if type(payload.actionbars) == "table" and #payload.actionbars > 0 then
        count = count + 1
    end
    if type(payload.keybinds) == "table" and #payload.keybinds > 0 then
        count = count + 1
    end
    if type(payload.equipment) == "table" and #payload.equipment > 0 then
        count = count + 1
    end
    if type(payload.editmode) == "table" and #payload.editmode > 0 then
        count = count + 1
    end
    if type(payload.addonsets) == "table" and #payload.addonsets > 0 then
        count = count + 1
    end
    return count
end

local function AppendSegment(list, segment)
    if type(segment) ~= "table" then
        return list
    end
    list = list or {}
    list[#list + 1] = segment
    return list
end

function LPL.LoadoutShare:BuildExportPayload(set, name)
    if type(set) ~= "table" then
        return nil, "Nothing to export."
    end

    local exportName = LPL.LoadoutStore:NormalizeSetName(name or set.name, "Exported Loadout")
    local payload = {
        type = "loadout",
        version = 2,
        name = exportName,
        restrictions = CopyRestrictions(set.restrictions),
        flavor = "classic_era",
    }

    local talentIDs = LPL.LoadoutStore:GetSegmentIDs(set, "talentBuildIDs")
    for _, buildID in ipairs(talentIDs) do
        local build = LPL.TalentStore and LPL.TalentStore:Get(buildID)
        if build then
            if not payload.classID then
                payload.classID = build.classID
            end
            payload.dftalents = AppendSegment(
                payload.dftalents,
                LPL.TalentShare:BuildLoadoutTalentSegment(build)
            )
        end
    end

    if LPL.ActionBarShare and LPL.ActionBarStore then
        for _, setID in ipairs(LPL.LoadoutStore:GetSegmentIDs(set, "actionBarSetIDs")) do
            local actionBar = LPL.ActionBarStore:Get(setID)
            if actionBar then
                payload.actionbars = AppendSegment(payload.actionbars, StripType(LPL.ActionBarShare:BuildExportPayload(actionBar)))
            end
        end
    end

    if LPL.KeybindShare and LPL.KeybindStore then
        for _, setID in ipairs(LPL.LoadoutStore:GetSegmentIDs(set, "keybindSetIDs")) do
            local keybindSet = LPL.KeybindStore:Get(setID)
            if keybindSet then
                payload.keybinds = AppendSegment(
                    payload.keybinds,
                    StripType(LPL.KeybindShare:BuildExportPayload(keybindSet))
                )
            end
        end
    end

    if LPL.EquipmentShare and LPL.EquipmentStore then
        for _, setID in ipairs(LPL.LoadoutStore:GetSegmentIDs(set, "equipmentSetIDs")) do
            local equipment = LPL.EquipmentStore:Get(setID)
            if equipment then
                payload.equipment = AppendSegment(payload.equipment, StripType(LPL.EquipmentShare:BuildExportPayload(equipment)))
            end
        end
    end

    if LPL.EditModeShare and LPL.EditModeStore then
        for _, setID in ipairs(LPL.LoadoutStore:GetSegmentIDs(set, "editModeSetIDs")) do
            local editMode = LPL.EditModeStore:Get(setID)
            if editMode then
                payload.editmode = AppendSegment(
                    payload.editmode,
                    StripType(select(1, LPL.EditModeShare:BuildExportPayload(editMode)))
                )
            end
        end
    end

    if LPL.AddonSetShare and LPL.AddonSetStore then
        for _, setID in ipairs(LPL.LoadoutStore:GetSegmentIDs(set, "addonSetIDs")) do
            local addonSet = LPL.AddonSetStore:Get(setID)
            if addonSet then
                payload.addonsets = AppendSegment(
                    payload.addonsets,
                    StripType(select(1, LPL.AddonSetShare:BuildExportPayload(addonSet)))
                )
            end
        end
    end

    if self:CountSegmentsInPayload(payload) == 0 then
        return nil, "Attach at least one segment before exporting."
    end

    if not payload.classID then
        payload.classID = LPL.LoadoutStore:GetEffectiveClassID(set)
    end

    -- Classic Era has no Retail specID requirement; keep optional for importer compat.
    if not payload.specID then
        payload.specID = LPL.LoadoutStore:GetEffectiveSpecID(set)
    end

    return payload
end

function LPL.LoadoutShare:ExportSet(set)
    if not set then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(set)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.LoadoutShare:ExportDraft(draftSet, name)
    if not draftSet then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(draftSet, name)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.LoadoutShare:BuildImportPreview(importData, setName)
    if type(importData) ~= "table" then
        return nil
    end
    setName = LPL.LoadoutStore:NormalizeSetName(setName, importData.name or "Imported Loadout")
    local existing = LPL.LoadoutStore:FindByName(setName)
    return {
        importKind = "loadoutset",
        loadoutPath = setName,
        buildName = setName,
        existingLoadoutID = existing and existing.id or nil,
        sections = {
            {
                id = "loadout",
                label = "Loadout",
                path = setName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Update loadout "%s"', setName)
                    or string.format('Add loadout "%s"', setName),
                defaultChecked = true,
            },
        },
        importData = importData,
    }
end
