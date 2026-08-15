local addonName, LPL = ...

LPL.ActionBarShare = {}

local defs = LPL.ActionBarDefinitions
local codec = LPL.ActionBarCodec
local share = LPL.TalentShare

local function CopyActionTable(action)
    if type(action) ~= "table" or not action.type then
        return nil
    end
    return CopyTable(action)
end

local function CopyRestrictions(source)
    if LPL.SetRestrictions and LPL.SetRestrictions.CopyRestrictions then
        return LPL.SetRestrictions:CopyRestrictions(source or {})
    end
    return CopyTable(source or {})
end

local function CopySlotMap(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for slotID, action in pairs(source) do
        local numericSlot = tonumber(slotID)
        if numericSlot then
            local copied = CopyActionTable(action)
            if copied then
                copy[numericSlot] = copied
            end
        end
    end
    return copy
end

local function CopyFlagMap(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end
    for slotID, value in pairs(source) do
        local numericSlot = tonumber(slotID)
        if numericSlot and value then
            copy[numericSlot] = true
        end
    end
    return copy
end

local function VerifyImportSource(source)
    if type(source) ~= "table" then
        return false, "Invalid import data."
    end
    if type(source.actions) ~= "table" then
        return false, "Missing action bar actions."
    end
    if type(source.ignored) ~= "table" then
        return false, "Missing action bar ignored slots."
    end
    if source.petActions ~= nil and type(source.petActions) ~= "table" then
        return false, "Invalid pet action bar data."
    end
    if source.petIgnored ~= nil and type(source.petIgnored) ~= "table" then
        return false, "Invalid pet ignored slot data."
    end
    return true
end

function LPL.ActionBarShare:NormalizeImportTable(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end

    local importType = source.type
    if importType ~= "actionbars" and importType ~= "lplactionbars" then
        return nil, "Unrecognized action bar import type."
    end

    if (source.version or 1) ~= 1 then
        return nil, "Unsupported action bar export version."
    end

    local ok, err = VerifyImportSource(source)
    if not ok then
        return nil, err
    end

    local importData = {
        importKind = "actionbars",
        name = source.name,
        actions = CopySlotMap(source.actions),
        ignored = CopyFlagMap(source.ignored),
        petActions = CopySlotMap(source.petActions),
        petIgnored = CopyFlagMap(source.petIgnored),
        restrictions = CopyRestrictions(source.restrictions),
    }

    if codec and codec.SanitizeDraft then
        codec:SanitizeDraft(importData)
    end

    return importData
end

function LPL.ActionBarShare:BuildExportPayload(setData, overrideName)
    if type(setData) ~= "table" then
        return nil
    end

    local draft = {
        name = overrideName or setData.name,
        actions = CopyTable(setData.actions or {}),
        ignored = CopyTable(setData.ignored or {}),
        petActions = CopyTable(setData.petActions or {}),
        petIgnored = CopyTable(setData.petIgnored or {}),
    }

    if codec and codec.SanitizeDraft then
        codec:SanitizeDraft(draft)
    end

    local payload = {
        type = "actionbars",
        version = 1,
        name = LPL.ActionBarStore:NormalizeSetName(draft.name, "Action Bar Set"),
        actions = {},
        ignored = {},
        petActions = {},
        petIgnored = {},
    }

    for _, slot in ipairs(defs:GetManagedPlayerSlots()) do
        payload.ignored[slot] = draft.ignored[slot] or nil
        if draft.ignored[slot] then
            payload.actions[slot] = nil
        else
            local action = draft.actions[slot]
            payload.actions[slot] = action and CopyActionTable(action) or nil
        end
    end

    for slot = 1, defs.PET_SLOT_MAX do
        payload.petIgnored[slot] = draft.petIgnored[slot] or nil
        if draft.petIgnored[slot] then
            payload.petActions[slot] = nil
        else
            local action = draft.petActions[slot]
            payload.petActions[slot] = action and CopyActionTable(action) or nil
        end
    end

    return payload
end

function LPL.ActionBarShare:ExportSet(set)
    if not set then
        return nil, "Nothing to export."
    end
    local payload = self:BuildExportPayload(set)
    if not payload then
        return nil, "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.ActionBarShare:ExportDraft(draftSet, name)
    if not draftSet then
        return nil, "Nothing to export."
    end
    local payload = self:BuildExportPayload(draftSet, name)
    if not payload then
        return nil, "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.ActionBarShare:ParseImportString(text)
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
        return false, nil, err or "Unrecognized action bar share string."
    end

    return true, importData, ""
end

function LPL.ActionBarShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.ActionBarShare:ExtractFromLoadout(rawSource)
    if type(rawSource) ~= "table" then
        return nil
    end

    local segments = rawSource.actionbars
    if type(segments) ~= "table" or #segments == 0 then
        return nil
    end

    local segment = segments[1]
    if type(segment) ~= "table" then
        return nil
    end

    if segment.type ~= "actionbars" then
        segment = CopyTable(segment)
        segment.type = "actionbars"
    end

    return self:NormalizeImportTable(segment)
end

function LPL.ActionBarShare:ApplyLoadoutSegments(rawSource, setName, options)
    if not options or options.actionBars ~= true then
        return nil
    end

    local segments = type(rawSource) == "table" and rawSource.actionbars
    if type(segments) ~= "table" or #segments == 0 then
        return nil, "Loadout has no action bar data."
    end

    local imported = {}
    local lastErr
    local opts = CopyTable(options)
    for index, segment in ipairs(segments) do
        if type(segment) == "table" then
            if segment.type ~= "actionbars" then
                segment = CopyTable(segment)
                segment.type = "actionbars"
            end
            local importData, err = self:NormalizeImportTable(segment)
            if importData then
                local name = setName
                if #segments > 1 then
                    name = importData.name or (setName .. " " .. tostring(index))
                end
                if index > 1 then
                    opts.existingActionBarID = nil
                end
                local set = LPL.ActionBarStore:ApplyImport(importData, name, opts)
                if set then
                    imported[#imported + 1] = set
                else
                    lastErr = "Could not save imported action bar set."
                end
            else
                lastErr = err
            end
        end
    end

    if #imported == 0 then
        return nil, lastErr or "Loadout has no action bar data."
    end
    return imported[1], nil, imported
end

function LPL.ActionBarShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a share string to import."
    end

    options = options or { actionBars = true }
    return LPL.ActionBarStore:ApplyImport(importData, name, options)
end

function LPL.ActionBarShare:BuildImportPreview(importData, setName)
    if type(importData) ~= "table" or importData.importKind ~= "actionbars" then
        return nil
    end

    setName = LPL.ActionBarStore:NormalizeSetName(setName, importData.name or "Imported Action Bar Set")
    local existing = LPL.ActionBarStore:FindByName(setName)

    return {
        importKind = "actionbars",
        loadoutPath = setName,
        buildName = setName,
        existingActionBarID = existing and existing.id or nil,
        sections = {
            {
                id = "actionBars",
                label = "Action Bars",
                path = setName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Use existing Action Bars set "%s"', setName)
                    or string.format('Add Action Bars set "%s"', setName),
                defaultChecked = true,
            },
        },
        importData = importData,
    }
end

function LPL.ActionBarShare:BuildImportPreviewFromText(text, setName)
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err
    end
    return self:BuildImportPreview(importData, setName)
end
