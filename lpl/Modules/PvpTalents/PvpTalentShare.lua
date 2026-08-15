local addonName, LPL = ...

LPL.PvpTalentShare = {}

local share = LPL.TalentShare

local function CopyRestrictions(source)
    if LPL.SetRestrictions and LPL.SetRestrictions.CopyRestrictions then
        return LPL.SetRestrictions:CopyRestrictions(source or {})
    end
    return CopyTable(source or {})
end

function LPL.PvpTalentShare:NormalizeImportTable(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end
    if source.type ~= "pvptalents" then
        return nil, "Unrecognized PvP talent import type."
    end
    if (source.version or 1) ~= 1 then
        return nil, "Unsupported PvP talent export version."
    end
    local specID = tonumber(source.specID)
    if not specID or not GetSpecializationInfoByID(specID) then
        return nil, "Invalid specialization in PvP talent import."
    end
    if type(source.talents) ~= "table" then
        return nil, "Missing PvP talents."
    end
    return {
        importKind = "pvptalents",
        name = source.name,
        specID = specID,
        talents = CopyTable(source.talents),
        restrictions = CopyRestrictions(source.restrictions),
    }
end

function LPL.PvpTalentShare:ParseImportString(text)
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
        return false, nil, err or "Unrecognized PvP talent share string."
    end
    return true, importData, ""
end

function LPL.PvpTalentShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.PvpTalentShare:ExtractFromLoadout(rawSource)
    if type(rawSource) ~= "table" then
        return nil
    end
    local segments = rawSource.pvptalents
    if type(segments) ~= "table" or #segments == 0 then
        return nil
    end
    local segment = segments[1]
    if type(segment) ~= "table" then
        return nil
    end
    if segment.type ~= "pvptalents" then
        segment = CopyTable(segment)
        segment.type = "pvptalents"
    end
    return self:NormalizeImportTable(segment)
end

function LPL.PvpTalentShare:ApplyLoadoutSegments(rawSource, setName, options)
    if not options or options.pvpTalents ~= true then
        return nil
    end
    local segments = type(rawSource) == "table" and rawSource.pvptalents
    if type(segments) ~= "table" or #segments == 0 then
        return nil, "Loadout has no PvP talent data."
    end

    local imported = {}
    local lastErr
    local opts = CopyTable(options)
    for index, segment in ipairs(segments) do
        if type(segment) == "table" then
            if segment.type ~= "pvptalents" then
                segment = CopyTable(segment)
                segment.type = "pvptalents"
            end
            local importData, err = self:NormalizeImportTable(segment)
            if importData then
                local name = setName
                if #segments > 1 then
                    name = importData.name or (setName .. " " .. tostring(index))
                end
                if index > 1 then
                    opts.existingPvpTalentID = nil
                end
                local set = LPL.PvpTalentStore:ApplyImport(importData, name, opts)
                if set then
                    imported[#imported + 1] = set
                else
                    lastErr = "Could not save imported PvP set."
                end
            else
                lastErr = err
            end
        end
    end

    if #imported == 0 then
        return nil, lastErr or "Loadout has no PvP talent data."
    end
    return imported[1], nil, imported
end

function LPL.PvpTalentShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a share string to import."
    end
    options = options or { pvpTalents = true }
    return LPL.PvpTalentStore:ApplyImport(importData, name, options)
end

function LPL.PvpTalentShare:BuildImportPreview(importData, setName)
    if type(importData) ~= "table" or importData.importKind ~= "pvptalents" then
        return nil
    end
    setName = LPL.PvpTalentStore:NormalizeSetName(setName, importData.name or "Imported PvP Set")
    local existing = LPL.PvpTalentStore:FindByName(setName)
    return {
        importKind = "pvptalents",
        loadoutPath = setName,
        buildName = setName,
        existingPvpTalentID = existing and existing.id or nil,
        sections = {
            {
                id = "pvpTalents",
                label = "PvP Talents",
                path = setName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Use existing PvP set "%s"', setName)
                    or string.format('Add PvP set "%s"', setName),
                defaultChecked = true,
            },
        },
        importData = importData,
    }
end

function LPL.PvpTalentShare:BuildImportPreviewFromText(text, setName)
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err
    end
    return self:BuildImportPreview(importData, setName)
end

local function ResolveExportSpecID(set)
    if not set then
        return nil
    end
    local specID = tonumber(set.specID)
    if specID and GetSpecializationInfoByID(specID) then
        return specID
    end
    if LPL.PvpTalentStore and LPL.PvpTalentStore.GetEffectiveSpecID then
        specID = LPL.PvpTalentStore:GetEffectiveSpecID(set)
        if specID and GetSpecializationInfoByID(specID) then
            return specID
        end
    end
    local currentSpecIndex = GetSpecialization and GetSpecialization()
    if currentSpecIndex then
        specID = select(1, GetSpecializationInfo(currentSpecIndex))
        if specID and GetSpecializationInfoByID(specID) then
            return specID
        end
    end
    return nil
end

function LPL.PvpTalentShare:BuildExportPayload(set, name)
    if type(set) ~= "table" then
        return nil, "Nothing to export."
    end
    local specID = ResolveExportSpecID(set)
    if not specID then
        return nil, "Could not resolve a specialization for this PvP set."
    end
    local talents = {}
    if type(set.talents) == "table" then
        for slot = 1, (LPL.PvpTalentStore and LPL.PvpTalentStore.SLOT_COUNT) or 3 do
            local talentID = tonumber(set.talents[slot])
            if talentID and talentID > 0 then
                talents[slot] = talentID
            end
        end
    end
    return {
        type = "pvptalents",
        version = 1,
        name = LPL.PvpTalentStore:NormalizeSetName(name or set.name, "Exported PvP Set"),
        specID = specID,
        talents = talents,
        restrictions = CopyRestrictions(set.restrictions),
    }
end

function LPL.PvpTalentShare:ExportSet(set)
    if not set then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(set)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.PvpTalentShare:ExportDraft(draftSet, name)
    if not draftSet then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(draftSet, name)
    if not payload then
        return nil, err or "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end
