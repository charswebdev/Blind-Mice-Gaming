local addonName, LPL = ...

LPL.CooldownManagerShare = {}

local share = LPL.TalentShare

local function CopyRestrictions(source)
    if LPL.SetRestrictions and LPL.SetRestrictions.CopyRestrictions then
        return LPL.SetRestrictions:CopyRestrictions(source or {})
    end
    return CopyTable(source or {})
end

function LPL.CooldownManagerShare:NormalizeImportTable(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end
    if source.type ~= "cooldownmanager" then
        return nil, "Unrecognized Cooldown Manager import type."
    end
    if (source.version or 1) ~= 1 then
        return nil, "Unsupported Cooldown Manager export version."
    end
    if type(source.layoutString) ~= "string" or source.layoutString == "" then
        return nil, "Missing Cooldown Manager layout string."
    end
    return {
        importKind = "cooldownmanager",
        name = source.name,
        layoutString = source.layoutString,
        restrictions = CopyRestrictions(source.restrictions),
    }
end

function LPL.CooldownManagerShare:ParseImportString(text)
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
        return false, nil, err or "Unrecognized Cooldown Manager share string."
    end
    return true, importData, ""
end

function LPL.CooldownManagerShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.CooldownManagerShare:ExtractFromLoadout(rawSource)
    if type(rawSource) ~= "table" then
        return nil
    end
    local segments = rawSource.cooldownmanager
    if type(segments) ~= "table" or #segments == 0 then
        return nil
    end
    local segment = segments[1]
    if type(segment) ~= "table" then
        return nil
    end
    if segment.type ~= "cooldownmanager" then
        segment = CopyTable(segment)
        segment.type = "cooldownmanager"
    end
    return self:NormalizeImportTable(segment)
end

function LPL.CooldownManagerShare:ApplyLoadoutSegments(rawSource, setName, options)
    if not options or options.cooldownManager ~= true then
        return nil
    end
    local segments = type(rawSource) == "table" and rawSource.cooldownmanager
    if type(segments) ~= "table" or #segments == 0 then
        return nil, "Loadout has no Cooldown Manager data."
    end

    local imported = {}
    local lastErr
    local opts = CopyTable(options)
    for index, segment in ipairs(segments) do
        if type(segment) == "table" then
            if segment.type ~= "cooldownmanager" then
                segment = CopyTable(segment)
                segment.type = "cooldownmanager"
            end
            local importData, err = self:NormalizeImportTable(segment)
            if importData then
                local name = setName
                if #segments > 1 then
                    name = importData.name or (setName .. " " .. tostring(index))
                end
                if index > 1 then
                    opts.existingCooldownManagerID = nil
                end
                local set = LPL.CooldownManagerStore:ApplyImport(importData, name, opts)
                if set then
                    imported[#imported + 1] = set
                else
                    lastErr = "Could not save imported Cooldown Manager set."
                end
            else
                lastErr = err
            end
        end
    end

    if #imported == 0 then
        return nil, lastErr or "Loadout has no Cooldown Manager data."
    end
    return imported[1], nil, imported
end

function LPL.CooldownManagerShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a share string to import."
    end
    options = options or { cooldownManager = true }
    return LPL.CooldownManagerStore:ApplyImport(importData, name, options)
end

function LPL.CooldownManagerShare:BuildImportPreview(importData, setName)
    if type(importData) ~= "table" or importData.importKind ~= "cooldownmanager" then
        return nil
    end
    setName = LPL.CooldownManagerStore:NormalizeSetName(setName, importData.name or "Imported Cooldown Manager Set")
    local existing = LPL.CooldownManagerStore:FindByName(setName)
    return {
        importKind = "cooldownmanager",
        loadoutPath = setName,
        buildName = setName,
        existingCooldownManagerID = existing and existing.id or nil,
        sections = {
            {
                id = "cooldownManager",
                label = "Cooldown Manager",
                path = setName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Use existing Cooldown Manager set "%s"', setName)
                    or string.format('Add Cooldown Manager set "%s"', setName),
                defaultChecked = true,
            },
        },
        importData = importData,
    }
end

function LPL.CooldownManagerShare:BuildImportPreviewFromText(text, setName)
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err
    end
    return self:BuildImportPreview(importData, setName)
end

function LPL.CooldownManagerShare:BuildExportPayload(set, name)
    if type(set) ~= "table" then
        return nil, "Nothing to export."
    end
    local layoutString = set.layoutString
    if type(layoutString) ~= "string" or layoutString == "" then
        return nil, "This set has no Cooldown Manager layout string."
    end
    return {
        type = "cooldownmanager",
        version = 1,
        name = LPL.CooldownManagerStore:NormalizeSetName(name or set.name, "Exported Cooldown Manager Set"),
        layoutString = layoutString,
        restrictions = CopyRestrictions(set.restrictions),
    }
end

function LPL.CooldownManagerShare:ExportSet(set)
    if not set then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(set)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.CooldownManagerShare:ExportDraft(draftSet, name)
    if not draftSet then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(draftSet, name)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end
