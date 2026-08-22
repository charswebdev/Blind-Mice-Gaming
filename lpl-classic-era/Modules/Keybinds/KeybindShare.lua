local addonName, LPL = ...

LPL.KeybindShare = {}

function LPL.KeybindShare:NormalizeImportTable(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end
    if source.type ~= "keybinds" then
        return nil, "Unrecognized keybinding profile import type."
    end
    if (source.version or 1) ~= 1 then
        return nil, "Unsupported keybinding profile export version."
    end
    if type(source.bindings) ~= "table" then
        return nil, "Missing keybinding profile data."
    end

    local store = LPL.KeybindStore
    return {
        importKind = "keybinds",
        name = source.name,
        scope = store and store:NormalizeScope(source.scope) or source.scope,
        bindings = store and store:NormalizeBindings(source.bindings) or source.bindings,
    }
end

function LPL.KeybindShare:BuildExportPayload(setData, overrideName)
    if type(setData) ~= "table" then
        return nil
    end
    if not LPL.KeybindStore then
        return nil
    end

    return {
        type = "keybinds",
        version = 1,
        name = LPL.KeybindStore:NormalizeSetName(overrideName or setData.name, "Keybinding Profile"),
        scope = LPL.KeybindStore:NormalizeScope(setData.scope),
        bindings = LPL.KeybindStore:NormalizeBindings(setData.bindings),
    }
end

function LPL.KeybindShare:ExportSet(set)
    if not set then
        return nil, "Nothing to export."
    end
    local payload = self:BuildExportPayload(set)
    if not payload then
        return nil, "Nothing to export."
    end
    if not LPL.TalentShare or not LPL.TalentShare.EncodeShareTable then
        return nil, "Share encoder is not available."
    end
    return LPL.TalentShare:EncodeShareTable(payload)
end

function LPL.KeybindShare:ExportDraft(draftSet, name)
    if not draftSet then
        return nil, "Nothing to export."
    end
    local payload = self:BuildExportPayload(draftSet, name)
    if not payload then
        return nil, "Nothing to export."
    end
    if not LPL.TalentShare or not LPL.TalentShare.EncodeShareTable then
        return nil, "Share encoder is not available."
    end
    return LPL.TalentShare:EncodeShareTable(payload)
end

function LPL.KeybindShare:ParseImportString(text)
    if type(text) ~= "string" or text:match("^%s*$") then
        return true, nil, ""
    end
    if not LPL.TalentShare or not LPL.TalentShare.DecodeShareString then
        return false, nil, "Share decoder is not available."
    end

    local ok, source = LPL.TalentShare:DecodeShareString(text)
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
        return false, nil, err or "Unrecognized keybinding profile share string."
    end
    return true, importData, ""
end

function LPL.KeybindShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.KeybindShare:ExtractFromLoadout(rawSource)
    if type(rawSource) ~= "table" then
        return nil
    end
    local segments = rawSource.keybinds
    if type(segments) ~= "table" or #segments == 0 then
        return nil
    end
    local segment = segments[1]
    if type(segment) ~= "table" then
        return nil
    end
    if segment.type ~= "keybinds" then
        segment = CopyTable(segment)
        segment.type = "keybinds"
    end
    return self:NormalizeImportTable(segment)
end

function LPL.KeybindShare:ApplyLoadoutSegments(rawSource, setName, options)
    if not options or options.keybinds ~= true then
        return nil
    end
    local segments = type(rawSource) == "table" and rawSource.keybinds
    if type(segments) ~= "table" or #segments == 0 then
        return nil, "Loadout has no keybinding profile data."
    end

    local imported = {}
    local lastErr
    local opts = CopyTable(options)
    for index, segment in ipairs(segments) do
        if type(segment) == "table" then
            if segment.type ~= "keybinds" then
                segment = CopyTable(segment)
                segment.type = "keybinds"
            end
            local importData, err = self:NormalizeImportTable(segment)
            if importData then
                if index > 1 then
                    opts.existingKeybindID = nil
                end

                local segmentName = importData.name
                local existing = opts.existingKeybindID and LPL.KeybindStore:Get(opts.existingKeybindID)
                if not existing and type(segmentName) == "string" and segmentName ~= "" then
                    existing = LPL.KeybindStore:FindByName(segmentName)
                end
                if not existing and type(setName) == "string" and setName ~= "" then
                    existing = LPL.KeybindStore:FindByName(setName)
                end
                if existing then
                    opts.existingKeybindID = existing.id
                end

                local name = existing and existing.name
                    or ((#segments > 1 and segmentName) and segmentName)
                    or setName
                    or segmentName

                local set = LPL.KeybindStore:ApplyImport(importData, name, opts)
                if set then
                    imported[#imported + 1] = set
                else
                    lastErr = "Could not save imported keybinding profile."
                end
            else
                lastErr = err
            end
        end
    end

    if #imported == 0 then
        return nil, lastErr or "Loadout has no keybinding profile data."
    end
    return imported[1], nil, imported
end

function LPL.KeybindShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a share string to import."
    end
    options = options or { keybinds = true }
    return LPL.KeybindStore:ApplyImport(importData, name, options)
end

function LPL.KeybindShare:BuildImportPreview(importData, setName)
    if type(importData) ~= "table" or importData.importKind ~= "keybinds" then
        return nil
    end
    setName = LPL.KeybindStore:NormalizeSetName(setName, importData.name or "Imported Keybinding Profile")
    local existing = LPL.KeybindStore:FindByName(setName)
    return {
        importKind = "keybinds",
        loadoutPath = setName,
        buildName = setName,
        existingKeybindID = existing and existing.id or nil,
        sections = {
            {
                id = "keybinds",
                label = "Keybinding Profiles",
                path = setName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Use existing keybinding profile "%s"', setName)
                    or string.format('Add keybinding profile "%s"', setName),
                defaultChecked = true,
            },
        },
        importData = importData,
    }
end

function LPL.KeybindShare:BuildImportPreviewFromText(text, setName)
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err
    end
    return self:BuildImportPreview(importData, setName)
end
