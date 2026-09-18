local addonName, LPL = ...

LPL.AddonSetShare = {}

local share = LPL.TalentShare
local TYPE_ID = "addonsets"
local VERSION = 1

local function IncludeNamesFromSet(set)
    local names = {}
    if type(set) ~= "table" or type(set.includes) ~= "table" then
        return names
    end
    for _, includeID in ipairs(set.includes) do
        local linked = LPL.AddonSetStore:Get(includeID)
        if linked and type(linked.name) == "string" and linked.name ~= "" then
            names[#names + 1] = linked.name
        end
    end
    table.sort(names)
    return names
end

local function IncludeIDsFromNames(names)
    local ids = {}
    local seen = {}
    if type(names) ~= "table" then
        return ids
    end
    for _, name in ipairs(names) do
        if type(name) == "string" and name ~= "" then
            local linked = LPL.AddonSetStore:FindByName(name)
            if linked and linked.id and not seen[linked.id] then
                seen[linked.id] = true
                ids[#ids + 1] = linked.id
            end
        end
    end
    return LPL.AddonSetStore:NormalizeIncludeList(ids)
end

function LPL.AddonSetShare:NormalizeImportTable(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end
    if source.type ~= TYPE_ID and source.type ~= "addonset" then
        return nil, "Unrecognized Addon Set import type."
    end
    if (source.version or 1) ~= VERSION then
        return nil, "Unsupported Addon Set export version."
    end
    return {
        importKind = TYPE_ID,
        name = source.name,
        scope = LPL.AddonSetStore:NormalizeScope(source.scope),
        addons = LPL.AddonSetStore:NormalizeAddonList(source.addons),
        includeNames = LPL.AddonSetStore:NormalizeAddonList(source.includes),
    }
end

function LPL.AddonSetShare:ParseImportString(text)
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
        return false, nil, err or "Unrecognized Addon Set share string."
    end
    return true, importData, ""
end

function LPL.AddonSetShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.AddonSetShare:ExtractFromLoadout(rawSource)
    if type(rawSource) ~= "table" then
        return nil
    end
    local segments = rawSource.addonsets
    if type(segments) ~= "table" or #segments == 0 then
        return nil
    end
    local segment = segments[1]
    if type(segment) ~= "table" then
        return nil
    end
    if segment.type ~= TYPE_ID and segment.type ~= "addonset" then
        segment = CopyTable(segment)
        segment.type = TYPE_ID
    end
    return self:NormalizeImportTable(segment)
end

function LPL.AddonSetShare:ApplyLoadoutSegments(rawSource, setName, options)
    if not options or options.addonSets ~= true then
        return nil
    end
    local segments = type(rawSource) == "table" and rawSource.addonsets
    if type(segments) ~= "table" or #segments == 0 then
        return nil, "Loadout has no Addon Set data."
    end

    local imported = {}
    local lastErr
    local opts = CopyTable(options)
    for index, segment in ipairs(segments) do
        if type(segment) == "table" then
            if segment.type ~= TYPE_ID and segment.type ~= "addonset" then
                segment = CopyTable(segment)
                segment.type = TYPE_ID
            end
            local importData, err = self:NormalizeImportTable(segment)
            if importData then
                local name = setName
                if #segments > 1 then
                    name = importData.name or (setName .. " " .. tostring(index))
                end
                if index > 1 then
                    opts.existingAddonSetID = nil
                end
                local set = LPL.AddonSetStore:ApplyImport(importData, name, opts)
                if set then
                    imported[#imported + 1] = {
                        set = set,
                        includeNames = importData.includeNames,
                    }
                else
                    lastErr = "Could not save imported Addon Set."
                end
            else
                lastErr = err
            end
        end
    end

    if #imported == 0 then
        return nil, lastErr or "Loadout has no Addon Set data."
    end

    -- Second pass: resolve Include Sets after every segment exists (order-independent).
    local sets = {}
    for _, entry in ipairs(imported) do
        local includeIDs = IncludeIDsFromNames(entry.includeNames)
        entry.set.includes = LPL.AddonSetStore:NormalizeIncludeList(includeIDs, entry.set.id)
        LPL.AddonSetStore:CommitSet(entry.set)
        sets[#sets + 1] = entry.set
    end

    return sets[1], nil, sets
end

function LPL.AddonSetShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a share string to import."
    end
    options = options or { addonSets = true }
    return LPL.AddonSetStore:ApplyImport(importData, name, options)
end

function LPL.AddonSetShare:BuildImportPreview(importData, setName)
    if type(importData) ~= "table" or importData.importKind ~= TYPE_ID then
        return nil
    end
    setName = LPL.AddonSetStore:NormalizeSetName(setName, importData.name or "Imported Addon Set")
    local existing = LPL.AddonSetStore:FindByName(setName)
    local addonCount = type(importData.addons) == "table" and #importData.addons or 0
    local includeCount = type(importData.includeNames) == "table" and #importData.includeNames or 0
    local detail = string.format("%d addon%s", addonCount, addonCount == 1 and "" or "s")
    if includeCount > 0 then
        detail = detail .. string.format(", %d linked set%s", includeCount, includeCount == 1 and "" or "s")
    end
    return {
        importKind = TYPE_ID,
        loadoutPath = setName,
        buildName = setName,
        existingAddonSetID = existing and existing.id or nil,
        sections = {
            {
                id = "addonSets",
                label = "Addon Sets",
                path = setName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Update existing Addon Set "%s" (%s)', setName, detail)
                    or string.format('Add Addon Set "%s" (%s)', setName, detail),
                defaultChecked = true,
            },
        },
        importData = importData,
    }
end

function LPL.AddonSetShare:BuildImportPreviewFromText(text, setName)
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err
    end
    return self:BuildImportPreview(importData, setName)
end

function LPL.AddonSetShare:BuildExportPayload(set, name)
    if type(set) ~= "table" then
        return nil, "Nothing to export."
    end
    return {
        type = TYPE_ID,
        version = VERSION,
        name = LPL.AddonSetStore:NormalizeSetName(name or set.name, "Exported Addon Set"),
        scope = LPL.AddonSetStore:NormalizeScope(set.scope),
        addons = LPL.AddonSetStore:NormalizeAddonList(set.addons),
        includes = IncludeNamesFromSet(set),
    }
end

function LPL.AddonSetShare:ExportSet(set)
    if not set then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(set)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.AddonSetShare:ExportDraft(draftSet, name)
    if not draftSet then
        return nil, "Nothing to export."
    end
    -- Draft includes are IDs when editing a saved set; names when freshly typed.
    local includes = draftSet.includes
    local payloadIncludes = {}
    if type(includes) == "table" then
        for _, value in ipairs(includes) do
            if type(value) == "string" and value ~= "" then
                local linked = LPL.AddonSetStore:Get(value)
                if linked then
                    payloadIncludes[#payloadIncludes + 1] = linked.name
                elseif not value:find("^addonset_", 1) then
                    payloadIncludes[#payloadIncludes + 1] = value
                end
            end
        end
    end
    local payload = {
        type = TYPE_ID,
        version = VERSION,
        name = LPL.AddonSetStore:NormalizeSetName(name or draftSet.name, "Exported Addon Set"),
        scope = LPL.AddonSetStore:NormalizeScope(draftSet.scope),
        addons = LPL.AddonSetStore:NormalizeAddonList(draftSet.addons),
        includes = LPL.AddonSetStore:NormalizeAddonList(payloadIncludes),
    }
    return share:EncodeShareTable(payload)
end

LPL.AddonSetShare.IncludeIDsFromNames = IncludeIDsFromNames
