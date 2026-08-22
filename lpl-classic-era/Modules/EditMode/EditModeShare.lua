local addonName, LPL = ...

LPL.EditModeShare = {}

local share = LPL.TalentShare

local function CopyRestrictions(source)
    if LPL.SetRestrictions and LPL.SetRestrictions.CopyRestrictions then
        return LPL.SetRestrictions:CopyRestrictions(source or {})
    end
    return CopyTable(source or {})
end

function LPL.EditModeShare:NormalizeImportTable(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end
    if source.type ~= "editmode" then
        return nil, "Unrecognized Edit Mode import type."
    end
    local version = source.version or 1
    if version ~= 1 and version ~= 2 then
        return nil, "Unsupported Edit Mode export version."
    end
    if type(source.layoutString) ~= "string" or source.layoutString == "" then
        return nil, "Missing Edit Mode layout string."
    end
    return {
        importKind = "editmode",
        name = source.name,
        layoutString = source.layoutString,
        editModeCharacterSpecific = source.editModeCharacterSpecific ~= false,
        restrictions = CopyRestrictions(source.restrictions),
    }
end

function LPL.EditModeShare:ParseImportString(text)
    if type(text) ~= "string" or text:match("^%s*$") then
        return true, nil, ""
    end
    local ok, source = share:DecodeShareString(text)
    if not ok then
        return false, nil, source or "Invalid share string."
    end
    if type(source) ~= "table" then
        return false, nil, "Invalid share string."
    end
    if source.type == "loadout" then
        return false, nil, "Use the Import / Export tab to import full loadouts."
    end
    local importData, err = self:NormalizeImportTable(source)
    if not importData then
        return false, nil, err or "Unrecognized Edit Mode share string."
    end
    return true, importData, ""
end

function LPL.EditModeShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.EditModeShare:ExtractFromLoadout(rawSource)
    if type(rawSource) ~= "table" then
        return nil
    end
    local segments = rawSource.editmode
    if type(segments) ~= "table" or #segments == 0 then
        return nil
    end
    local segment = segments[1]
    if type(segment) ~= "table" then
        return nil
    end
    if segment.type ~= "editmode" then
        segment = CopyTable(segment)
        segment.type = "editmode"
    end
    return self:NormalizeImportTable(segment)
end

function LPL.EditModeShare:ApplyLoadoutSegments(rawSource, setName, options)
    if not options or options.editMode ~= true then
        return nil
    end
    local segments = type(rawSource) == "table" and rawSource.editmode
    if type(segments) ~= "table" or #segments == 0 then
        return nil, "Loadout has no Edit Mode data."
    end

    local imported = {}
    local lastErr
    local opts = CopyTable(options)
    for index, segment in ipairs(segments) do
        if type(segment) == "table" then
            if segment.type ~= "editmode" then
                segment = CopyTable(segment)
                segment.type = "editmode"
            end
            local importData, err = self:NormalizeImportTable(segment)
            if importData then
                if index > 1 then
                    opts.existingEditModeID = nil
                end

                local segmentName = importData.name
                local existing = opts.existingEditModeID and LPL.EditModeStore:Get(opts.existingEditModeID)
                if not existing and type(segmentName) == "string" and segmentName ~= "" then
                    existing = LPL.EditModeStore:FindByName(segmentName)
                end
                if not existing and type(setName) == "string" and setName ~= "" then
                    existing = LPL.EditModeStore:FindByName(setName)
                end
                if existing then
                    opts.existingEditModeID = existing.id
                end

                local name = existing and existing.name
                    or ((#segments > 1 and segmentName) and segmentName)
                    or setName
                    or segmentName

                local set = LPL.EditModeStore:ApplyImport(importData, name, opts)
                if set then
                    imported[#imported + 1] = set
                else
                    lastErr = "Could not save imported Edit Mode layout."
                end
            else
                lastErr = err
            end
        end
    end

    if #imported == 0 then
        return nil, lastErr or "Loadout has no Edit Mode data."
    end
    return imported[1], nil, imported
end

function LPL.EditModeShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a share string to import."
    end
    options = options or { editMode = true }
    return LPL.EditModeStore:ApplyImport(importData, name, options)
end

function LPL.EditModeShare:BuildImportPreview(importData, setName)
    if type(importData) ~= "table" or importData.importKind ~= "editmode" then
        return nil
    end
    setName = LPL.EditModeStore:NormalizeSetName(setName, importData.name or "Imported Edit Mode Layout")
    local existing = LPL.EditModeStore:FindByName(setName)
    return {
        importKind = "editmode",
        loadoutPath = setName,
        buildName = setName,
        existingEditModeID = existing and existing.id or nil,
        sections = {
            {
                id = "editMode",
                label = "Edit Mode",
                path = setName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Use existing Edit Mode layout "%s"', setName)
                    or string.format('Add Edit Mode layout "%s"', setName),
                defaultChecked = true,
            },
        },
        importData = importData,
    }
end

function LPL.EditModeShare:BuildImportPreviewFromText(text, setName)
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err
    end
    return self:BuildImportPreview(importData, setName)
end

function LPL.EditModeShare:BuildExportPayload(set, name)
    if type(set) ~= "table" then
        return nil, "Nothing to export."
    end
    local layoutString = set.layoutString
    if type(layoutString) ~= "string" or layoutString == "" then
        return nil, "This layout has no Edit Mode layout string."
    end
    return {
        type = "editmode",
        version = 2,
        name = LPL.EditModeStore:NormalizeSetName(name or set.name, "Exported Edit Mode Layout"),
        layoutString = layoutString,
        editModeCharacterSpecific = set.editModeCharacterSpecific ~= false,
        restrictions = CopyRestrictions(set.restrictions),
    }
end

function LPL.EditModeShare:ExportSet(set)
    if not set then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(set)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.EditModeShare:ExportDraft(draftSet, name)
    if not draftSet then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(draftSet, name)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end
