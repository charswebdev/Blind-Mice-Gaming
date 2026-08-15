local addonName, LPL = ...

LPL.EquipmentShare = {}

local codec = LPL.EquipmentCodec
local share = LPL.TalentShare

local INVSLOT_FIRST = INVSLOT_FIRST_EQUIPPED or 1
local INVSLOT_LAST = INVSLOT_LAST_EQUIPPED or 19

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

local function CopySlotEntryForExport(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if entry.cleared then
        return { cleared = true }
    end

    local normalized = codec and codec.NormalizeSlotEntry and codec:NormalizeSlotEntry(entry)
    if not normalized or normalized.cleared then
        return normalized
    end

    local exported = {
        itemID = normalized.itemID,
    }

    if type(normalized.link) == "string" and normalized.link ~= "" then
        exported.link = normalized.link
    end
    if type(normalized.name) == "string" and normalized.name ~= "" then
        exported.name = normalized.name
    end
    if normalized.icon then
        exported.icon = normalized.icon
    end

    return exported
end

local function CopyRestrictions(source)
    if LPL.SetRestrictions and LPL.SetRestrictions.CopyRestrictions then
        return LPL.SetRestrictions:CopyRestrictions(source or {})
    end
    return CopyTable(source or {})
end

function LPL.EquipmentShare:BuildExportPayload(setData, overrideName)
    if type(setData) ~= "table" then
        return nil
    end

    local draft = {
        name = overrideName or setData.name,
        slots = CopyTable(setData.slots or {}),
        ignored = CopyTable(setData.ignored or {}),
        restrictions = CopyRestrictions(setData.restrictions),
    }

    if codec and codec.SanitizeDraft then
        codec:SanitizeDraft(draft)
    end

    local payload = {
        type = "equipment",
        version = 1,
        name = LPL.EquipmentStore:NormalizeSetName(draft.name, "Equipment Set"),
        slots = {},
        ignored = {},
        restrictions = CopyRestrictions(draft.restrictions),
    }

    for slotID = INVSLOT_FIRST, INVSLOT_LAST do
        if draft.ignored and draft.ignored[slotID] then
            payload.ignored[slotID] = true
            payload.slots[slotID] = nil
        else
            payload.ignored[slotID] = nil
            local entry = draft.slots and draft.slots[slotID]
            payload.slots[slotID] = entry and CopySlotEntryForExport(entry) or nil
        end
    end

    return payload
end

function LPL.EquipmentShare:ExportSet(set)
    if not set then
        return nil, "Nothing to export."
    end
    local payload = self:BuildExportPayload(set)
    if not payload then
        return nil, "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

function LPL.EquipmentShare:ExportDraft(draftSet, name)
    if not draftSet then
        return nil, "Nothing to export."
    end
    local payload = self:BuildExportPayload(draftSet, name)
    if not payload then
        return nil, "Nothing to export."
    end
    return share:EncodeShareTable(payload)
end

local function CopySlotEntryForImport(entry)
    if type(entry) ~= "table" then
        return nil
    end

    if entry.cleared then
        return { cleared = true }
    end

    if codec and codec.NormalizeSlotEntry then
        return codec:NormalizeSlotEntry(entry)
    end

    local itemID = tonumber(entry.itemID)
    if not itemID or itemID < 1 then
        return nil
    end

    return {
        itemID = itemID,
        link = entry.link,
        name = entry.name,
        icon = entry.icon,
    }
end

local function CopySlotMap(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for slotID = INVSLOT_FIRST, INVSLOT_LAST do
        local entry = source[slotID]
        if entry then
            local copied = CopySlotEntryForImport(entry)
            if copied then
                copy[slotID] = copied
            end
        end
    end

    return copy
end

local function BuildSlotsFromLegacyData(dataTable)
    local slots = {}
    if type(dataTable) ~= "table" then
        return slots
    end

    for slotID = INVSLOT_FIRST, INVSLOT_LAST do
        local value = dataTable[slotID]
        if value == false then
            slots[slotID] = { cleared = true }
        elseif type(value) == "string" and value ~= "" then
            local itemID = tonumber(value:match("item:(%d+)"))
            if itemID then
                local entry = { itemID = itemID }
                local link = value:match("^(item:[^|]+)")
                if link then
                    entry.link = link
                end
                if codec and codec.NormalizeSlotEntry then
                    entry = codec:NormalizeSlotEntry(entry)
                end
                if entry then
                    slots[slotID] = entry
                end
            end
        end
    end

    return slots
end

local function VerifyImportSource(source)
    if type(source) ~= "table" then
        return false, "Invalid import data."
    end
    local hasSlots = type(source.slots) == "table"
    local hasData = type(source.data) == "table"
    if not hasSlots and not hasData then
        return false, "Missing equipment slots."
    end
    if type(source.ignored) ~= "table" then
        source.ignored = {}
    end
    if source.restrictions ~= nil and type(source.restrictions) ~= "table" then
        return false, "Invalid equipment restrictions."
    end
    return true
end

function LPL.EquipmentShare:NormalizeImportTable(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end

    local importType = source.type
    if importType ~= "equipment" and importType ~= "lplequipment" then
        return nil, "Unrecognized equipment import type."
    end

    if (source.version or 1) ~= 1 then
        return nil, "Unsupported equipment export version."
    end

    local ok, err = VerifyImportSource(source)
    if not ok then
        return nil, err
    end

    local slots = type(source.slots) == "table" and CopySlotMap(source.slots) or BuildSlotsFromLegacyData(source.data)

    local importData = {
        importKind = "equipment",
        name = source.name,
        slots = slots,
        ignored = CopyFlagMap(source.ignored),
        restrictions = CopyRestrictions(source.restrictions),
    }

    if codec and codec.SanitizeDraft then
        codec:SanitizeDraft(importData)
    end

    return importData
end

function LPL.EquipmentShare:ParseImportString(text)
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
        return false, nil, err or "Unrecognized equipment share string."
    end

    return true, importData, ""
end

function LPL.EquipmentShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.EquipmentShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a share string to import."
    end

    options = options or { equipment = true }
    return LPL.EquipmentStore:ApplyImport(importData, name, options)
end

function LPL.EquipmentShare:ExtractFromLoadout(rawSource)
    if type(rawSource) ~= "table" then
        return nil
    end
    local segments = rawSource.equipment
    if type(segments) ~= "table" or #segments == 0 then
        return nil
    end
    local segment = segments[1]
    if type(segment) ~= "table" then
        return nil
    end
    if segment.type ~= "equipment" then
        segment = CopyTable(segment)
        segment.type = "equipment"
    end
    return self:NormalizeImportTable(segment)
end

function LPL.EquipmentShare:ApplyLoadoutSegments(rawSource, setName, options)
    if not options or options.equipment ~= true then
        return nil
    end
    local segments = type(rawSource) == "table" and rawSource.equipment
    if type(segments) ~= "table" or #segments == 0 then
        return nil, "Loadout has no equipment data."
    end

    local imported = {}
    local lastErr
    local opts = CopyTable(options)
    for index, segment in ipairs(segments) do
        if type(segment) == "table" then
            if segment.type ~= "equipment" then
                segment = CopyTable(segment)
                segment.type = "equipment"
            end
            local importData, err = self:NormalizeImportTable(segment)
            if importData then
                local name = setName
                if #segments > 1 then
                    name = importData.name or (setName .. " " .. tostring(index))
                end
                if index > 1 then
                    opts.existingEquipmentID = nil
                end
                local set = LPL.EquipmentStore:ApplyImport(importData, name, opts)
                if set then
                    imported[#imported + 1] = set
                else
                    lastErr = "Could not save imported equipment set."
                end
            else
                lastErr = err
            end
        end
    end

    if #imported == 0 then
        return nil, lastErr or "Loadout has no equipment data."
    end
    return imported[1], nil, imported
end

function LPL.EquipmentShare:BuildImportPreview(importData, setName)
    if type(importData) ~= "table" or importData.importKind ~= "equipment" then
        return nil
    end

    setName = LPL.EquipmentStore:NormalizeSetName(setName, importData.name or "Imported Equipment Set")
    local existing = LPL.EquipmentStore:FindByName(setName)

    return {
        importKind = "equipment",
        loadoutPath = setName,
        buildName = setName,
        existingEquipmentID = existing and existing.id or nil,
        sections = {
            {
                id = "equipment",
                label = "Equipment",
                path = setName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Use existing equipment set "%s"', setName)
                    or string.format('Add equipment set "%s"', setName),
                defaultChecked = true,
            },
        },
        importData = importData,
    }
end

function LPL.EquipmentShare:BuildImportPreviewFromText(text, setName)
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err
    end
    return self:BuildImportPreview(importData, setName)
end
