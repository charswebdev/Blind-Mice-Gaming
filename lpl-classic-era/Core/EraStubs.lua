local addonName, LPL = ...

-- Minimal stubs so Era loadouts/import load without Retail PvP / CDM engines.
-- Edit Mode is live on Classic Era (HUD Edit / C_EditMode) — do not stub it.
-- Talent share is provided by Modules/Talents/EraTalentShare.lua (loads later).
-- BN encode/decode for vault shares is provided by Core/ShareCodec.lua.

local function NotSupported()
    return nil, "Not available in Light Paws Loadouts - Classic Era"
end

local shareStub = {
    GetRawImportSource = function()
        return nil
    end,
    ValidateImportString = function()
        return false
    end,
    ParseImportString = NotSupported,
    BuildImportPreviewFromText = function()
        return nil
    end,
    ImportString = NotSupported,
    ApplyLoadoutSegments = NotSupported,
    BuildExportPayload = NotSupported,
    ExportSet = NotSupported,
    ExportDraft = NotSupported,
}

-- Placeholder until EraTalentShare.lua replaces this table's methods.
LPL.TalentShare = shareStub
LPL.PvpTalentShare = shareStub
LPL.CooldownManagerShare = shareStub

-- Bridge Retail BuildStore call sites onto Era TalentStore.
LPL.BuildStore = {
    MAX_NAME_LENGTH = 150,
    GetAll = function()
        return LPL.TalentStore and LPL.TalentStore:GetAll() or {}
    end,
    Get = function(_, buildID)
        return LPL.TalentStore and LPL.TalentStore:Get(buildID) or nil
    end,
    GetSummaryLine = function(_, build)
        return LPL.TalentStore and LPL.TalentStore:GetSummaryLine(build) or ""
    end,
    GetClassColor = function(_, classID)
        if LPL.TalentStore and LPL.TalentStore.GetClassColor then
            return LPL.TalentStore:GetClassColor(classID)
        end
        return 0.78, 0.61, 0.43
    end,
    NormalizeBuildName = function(_, name, fallback)
        if LPL.TalentStore and LPL.TalentStore.NormalizeName then
            return LPL.TalentStore:NormalizeName(name, fallback)
        end
        if type(name) == "string" and name ~= "" then
            return name
        end
        return fallback or "Imported"
    end,
    FormatLoadoutPath = function(_, data, overrideName)
        if type(overrideName) == "string" and overrideName ~= "" then
            return overrideName
        end
        if type(data) == "table" and type(data.name) == "string" and data.name ~= "" then
            return data.name
        end
        return "Imported Loadout"
    end,
    FindByLoadoutPath = function(_, path)
        if not LPL.TalentStore or type(path) ~= "string" or path == "" then
            return nil
        end
        for _, build in ipairs(LPL.TalentStore:GetAll()) do
            if build.name == path then
                return build
            end
        end
        return nil
    end,
    ResolveName = function(_, id, list, fallback)
        id = tonumber(id)
        if type(list) == "table" then
            for _, entry in ipairs(list) do
                if type(entry) == "table" and tonumber(entry.id or entry.classID or entry.specID) == id then
                    return entry.name or entry.className or fallback or tostring(id)
                end
            end
        end
        return fallback or "Other"
    end,
    NormalizeNodesForStorage = function(_, nodes)
        return nodes or {}
    end,
    NormalizeEntriesForStorage = function(_, entries)
        return entries
    end,
    ApplyImport = function(_, importData, name, options)
        if LPL.TalentShare and LPL.TalentShare.ApplyImportData then
            return LPL.TalentShare:ApplyImportData(importData, name, options)
        end
        return NotSupported()
    end,
    MigrateStorage = function() end,
}

local emptyStore = {
    NormalizeSetName = function(_, name, fallback)
        return name or fallback
    end,
    GetAll = function()
        return {}
    end,
    Get = function()
        return nil
    end,
    FindByName = function()
        return nil
    end,
    GetSummaryLine = function()
        return ""
    end,
    GetEffectiveClassID = function()
        return nil
    end,
    GetEffectiveSpecID = function()
        return nil
    end,
    MigrateStorage = function() end,
}

LPL.PvpTalentStore = emptyStore
LPL.CooldownManagerStore = emptyStore
