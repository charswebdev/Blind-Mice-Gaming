local addonName, LPL = ...

-- Classic Era talent share: TalentStore tabs/ranks (not Retail C_Traits nodes).
-- Replaces EraStubs TalentShare methods while keeping ShareCodec encode/decode.

LPL.TalentShare = LPL.TalentShare or {}

local function Trim(text)
    if type(text) ~= "string" then
        return ""
    end
    return text:match("^%s*(.-)%s*$") or text
end

local function CopyRestrictions(source)
    if LPL.SetRestrictions and LPL.SetRestrictions.CopyRestrictions then
        return LPL.SetRestrictions:CopyRestrictions(source or {})
    end
    return CopyTable(source or {})
end

local function CopyTabs(tabs)
    if type(tabs) ~= "table" then
        return {}
    end
    local out = {}
    for key, tab in pairs(tabs) do
        if type(tab) == "table" then
            local ranks = {}
            if type(tab.ranks) == "table" then
                for talentIndex, rank in pairs(tab.ranks) do
                    local idx = tonumber(talentIndex) or talentIndex
                    local value = tonumber(rank) or 0
                    if value > 0 then
                        ranks[tostring(idx)] = value
                    end
                end
            end
            out[tostring(key)] = {
                tabID = tonumber(tab.tabID),
                name = tab.name,
                points = tonumber(tab.points) or 0,
                ranks = ranks,
            }
        end
    end
    return out
end

local function NormalizeName(name, fallback)
    if LPL.TalentStore and LPL.TalentStore.NormalizeName then
        return LPL.TalentStore:NormalizeName(name, fallback)
    end
    if type(name) == "string" and name ~= "" then
        return name
    end
    return fallback or "Imported"
end

function LPL.TalentShare:BuildLoadoutTalentSegment(build)
    if type(build) ~= "table" then
        return nil
    end
    return {
        type = "eratents",
        version = 1,
        name = build.name,
        classID = tonumber(build.classID),
        level = tonumber(build.level) or 60,
        talentGroup = tonumber(build.talentGroup) or 1,
        tabs = CopyTabs(build.tabs),
        totalPoints = tonumber(build.totalPoints) or 0,
        restrictions = CopyRestrictions(build.restrictions),
    }
end

function LPL.TalentShare:BuildExportPayload(build, overrideName)
    if type(build) ~= "table" then
        return nil, "Nothing to export."
    end
    local payload = self:BuildLoadoutTalentSegment(build)
    if not payload then
        return nil, "Nothing to export."
    end
    payload.name = NormalizeName(overrideName or build.name, "Talent Build")
    return payload
end

function LPL.TalentShare:ExportBuild(build)
    local payload, err = self:BuildExportPayload(build)
    if not payload then
        return nil, err
    end
    return self:EncodeShareTable(payload)
end

function LPL.TalentShare:ExportSet(build)
    return self:ExportBuild(build)
end

function LPL.TalentShare:ExportDraft(draft, name)
    if type(draft) ~= "table" then
        return nil, "Nothing to export."
    end
    local payload, err = self:BuildExportPayload(draft, name)
    if not payload then
        return nil, err
    end
    return self:EncodeShareTable(payload)
end

local function NormalizeEraTalentTable(source)
    if type(source) ~= "table" then
        return nil, "Invalid import data."
    end
    local importType = source.type
    if importType ~= "eratents" and importType ~= "dftalents" and importType ~= "talents" then
        return nil, "Unrecognized talent import type."
    end
    if type(source.tabs) ~= "table" then
        -- Retail dftalents use nodes — not usable on Era.
        if type(source.nodes) == "table" then
            return nil, "Retail talent strings cannot be imported into Classic Era."
        end
        return nil, "Missing talent tab data."
    end
    return {
        type = "eratents",
        version = 1,
        name = source.name,
        classID = tonumber(source.classID),
        level = tonumber(source.level) or 60,
        talentGroup = tonumber(source.talentGroup) or 1,
        tabs = CopyTabs(source.tabs),
        totalPoints = tonumber(source.totalPoints) or 0,
        restrictions = CopyRestrictions(source.restrictions),
    }
end

function LPL.TalentShare:GetRawImportSource(text)
    text = Trim(text)
    if text == "" then
        return nil
    end
    local ok, source = self:DecodeShareString(text)
    if ok and type(source) == "table" then
        return source
    end
    return nil
end

function LPL.TalentShare:ParseImportString(text)
    text = Trim(text)
    if text == "" then
        return true, nil, ""
    end
    local ok, source = self:DecodeShareString(text)
    if not ok then
        return false, nil, source or "Could not decode share string."
    end
    if type(source) ~= "table" then
        return false, nil, "Unrecognized share string."
    end
    if source.type == "loadout" then
        local segments = source.dftalents
        if type(segments) == "table" and type(segments[1]) == "table" then
            local normalized, err = NormalizeEraTalentTable(segments[1])
            if not normalized then
                return false, nil, err
            end
            return true, normalized, ""
        end
        return true, nil, ""
    end
    local normalized, err = NormalizeEraTalentTable(source)
    if not normalized then
        return false, nil, err
    end
    return true, normalized, ""
end

function LPL.TalentShare:ValidateImportString(text)
    local ok, _, err = self:ParseImportString(text)
    if ok then
        return true, err or ""
    end
    return false, err or "Invalid share string."
end

function LPL.TalentShare:ApplyImportData(importData, name, options)
    options = options or {}
    if type(importData) ~= "table" then
        return nil, "Nothing to import."
    end
    if not LPL.TalentStore then
        return nil, "Talent store is unavailable."
    end

    local normalized, err = NormalizeEraTalentTable(importData)
    if not normalized then
        return nil, err
    end

    local buildName = NormalizeName(name or normalized.name, "Imported Build")
    local existingID = options.existingBuildID
    local build
    if existingID then
        build = LPL.TalentStore:Get(existingID)
    end
    if not build and options.replaceByName then
        for _, candidate in ipairs(LPL.TalentStore:GetAll()) do
            if candidate.name == buildName then
                build = candidate
                break
            end
        end
    end

    if not build then
        build = LPL.TalentStore:CreateDraft(buildName)
        build.id = LPL.TalentStore:GenerateID()
    end

    build.name = buildName
    build.classID = normalized.classID or build.classID
    build.level = normalized.level
    build.talentGroup = normalized.talentGroup
    build.tabs = normalized.tabs
    build.totalPoints = normalized.totalPoints
    if next(normalized.restrictions or {}) then
        build.restrictions = normalized.restrictions
    end
    if LPL.TalentAPI and LPL.TalentAPI.RecalcDraftPoints then
        build.totalPoints = LPL.TalentAPI:RecalcDraftPoints(build)
    end

    return LPL.TalentStore:CommitBuild(build)
end

function LPL.TalentShare:ImportString(text, name, options)
    local ok, importData, err = self:ParseImportString(text)
    if not ok then
        return nil, err or "Invalid share string."
    end
    if not importData then
        return nil, "Paste a Classic Era talent share string to import."
    end
    local build, applyErr = self:ApplyImportData(importData, name, options)
    if not build then
        return nil, applyErr or "Could not save imported build."
    end
    return build
end

function LPL.TalentShare:BuildImportPreviewFromText(text, buildName)
    local rawSource = self:GetRawImportSource(text)
    if not rawSource then
        return nil, "Invalid share string."
    end
    if rawSource.type == "loadout" and LPL.LoadoutImport then
        return LPL.LoadoutImport:BuildImportPreview(rawSource, buildName)
    end
    local ok, importData, err = self:ParseImportString(text)
    if not ok or not importData then
        return nil, err or "Invalid share string."
    end
    buildName = NormalizeName(buildName, importData.name or "Imported Build")
    local existing
    for _, candidate in ipairs(LPL.TalentStore:GetAll()) do
        if candidate.name == buildName then
            existing = candidate
            break
        end
    end
    return {
        importKind = "talents",
        buildName = buildName,
        loadoutPath = buildName,
        existingBuildID = existing and existing.id or nil,
        sections = {
            {
                id = "talents",
                label = "Talents",
                path = buildName,
                available = true,
                exists = existing ~= nil,
                checkboxLabel = existing
                    and string.format('Update talent build "%s"', buildName)
                    or string.format('Add talent build "%s"', buildName),
                defaultChecked = true,
            },
        },
        importData = importData,
        rawSource = rawSource,
    }
end

function LPL.TalentShare:ApplyLoadoutSegments()
    return nil, "Use ImportExport for Classic Era loadout import."
end

-- Preserve ShareCodec hooks if this file loads after ShareCodec.
if LPL.ShareCodec then
    if not LPL.TalentShare.EncodeShareTable then
        LPL.TalentShare.EncodeShareTable = function(_, payload)
            return LPL.ShareCodec:EncodeShareTable(payload)
        end
    end
    if not LPL.TalentShare.DecodeShareString then
        LPL.TalentShare.DecodeShareString = function(_, text)
            return LPL.ShareCodec:DecodeShareString(text)
        end
    end
end
