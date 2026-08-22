local addonName, LPL = ...

LPL.AddonProfileStore = {}

LPL.AddonProfileStore.MAX_NAME_LENGTH = 150
LPL.AddonProfileStore.SOFT_WARN_BYTES = 128 * 1024

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_ADDON_PROFILE"

local function GetAddonProfilesData()
    return LPL.DB:GetAddonProfiles()
end

function LPL.AddonProfileStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Addon Profile"
    if type(name) ~= "string" then
        return fallback
    end
    name = name:match("^%s*(.-)%s*$") or ""
    if name == "" then
        return fallback
    end
    if #name > self.MAX_NAME_LENGTH then
        name = name:sub(1, self.MAX_NAME_LENGTH)
    end
    return name
end

function LPL.AddonProfileStore:EnsureSetsTable()
    local data = GetAddonProfilesData()
    if type(data.sets) ~= "table" then
        data.sets = {}
    end
    if data.nextSetId == nil then
        data.nextSetId = 0
    end
    return data.sets
end

function LPL.AddonProfileStore:GenerateID()
    local data = GetAddonProfilesData()
    data.nextSetId = (data.nextSetId or 0) + 1
    return "addonprof_" .. data.nextSetId
end

function LPL.AddonProfileStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, "New Addon Profile")
    set.addonKey = tostring(set.addonKey or "custom")
    if set.addonKey == "" then
        set.addonKey = "custom"
    end
    if type(set.addonLabel) ~= "string" then
        set.addonLabel = ""
    end
    if type(set.profileString) ~= "string" then
        set.profileString = ""
    end
    if type(set.notes) ~= "string" then
        set.notes = ""
    end
    set.byteLength = #(set.profileString or "")
    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt
    set.schemaVersion = tonumber(set.schemaVersion) or 1
    return set
end

function LPL.AddonProfileStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        addonKey = "custom",
        addonLabel = "",
        profileString = "",
        notes = "",
    }
end

function LPL.AddonProfileStore:SuggestSetName()
    return "New Addon Profile"
end

function LPL.AddonProfileStore:Get(setID)
    if not setID then
        return nil
    end
    local sets = self:EnsureSetsTable()
    return self:NormalizeSetRecord(sets[tostring(setID)])
end

function LPL.AddonProfileStore:GetAll()
    local list = {}
    for _, set in pairs(self:EnsureSetsTable()) do
        local normalized = self:NormalizeSetRecord(set)
        if normalized then
            list[#list + 1] = normalized
        end
    end
    table.sort(list, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function LPL.AddonProfileStore:GetSummaryLine(set)
    if type(set) ~= "table" then
        return "Invalid profile"
    end
    local addonKey = tostring(set.addonKey or "custom")
    if addonKey == "" then
        addonKey = "custom"
    end
    local addonLabel = LPL.AddonCatalog:GetLabel(addonKey, set.addonLabel)
    local bytes = #(type(set.profileString) == "string" and set.profileString or "")
    if bytes >= 1024 then
        return string.format("%s · %.1f KB", addonLabel, bytes / 1024)
    end
    return string.format("%s · %d characters", addonLabel, bytes)
end

function LPL.AddonProfileStore:CommitSet(set)
    set = self:NormalizeSetRecord(set)
    if not set then
        return false
    end
    local sets = self:EnsureSetsTable()
    set.updatedAt = time()
    sets[set.id] = set
    return true
end

function LPL.AddonProfileStore:Delete(setID)
    if not setID then
        return false
    end
    local sets = self:EnsureSetsTable()
    setID = tostring(setID)
    if not sets[setID] then
        return false
    end
    sets[setID] = nil
    return true
end

function LPL.AddonProfileStore:ValidateForSave(draft)
    if type(draft) ~= "table" then
        return false, "Nothing to save."
    end
    local name = self:NormalizeSetName(draft.name, "")
    if name == "" then
        return false, "Enter a name before saving."
    end
    return true
end

function LPL.AddonProfileStore:SaveFromEditor(setID, name, draft, onSaved)
    draft = draft or {}
    draft.name = name
    local ok, err = self:ValidateForSave(draft)
    if not ok then
        print("|cffff6060LPL:|r " .. (err or "Could not save addon profile."))
        return false
    end

    name = self:NormalizeSetName(name, self:SuggestSetName())
    local profileString = type(draft.profileString) == "string" and draft.profileString or ""

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.addonKey = tostring(draft.addonKey or "custom")
        set.addonLabel = type(draft.addonLabel) == "string" and draft.addonLabel or ""
        set.profileString = profileString
        set.notes = type(draft.notes) == "string" and draft.notes or ""
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved addon profile \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        addonKey = tostring(draft.addonKey or "custom"),
        addonLabel = type(draft.addonLabel) == "string" and draft.addonLabel or "",
        profileString = profileString,
        notes = type(draft.notes) == "string" and draft.notes or "",
        createdAt = time(),
        updatedAt = time(),
        schemaVersion = 1,
    }
    if not self:CommitSet(set) then
        return false
    end
    if onSaved then
        onSaved(set.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Created addon profile \"%s\".", name))
    return true
end

function LPL.AddonProfileStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete addon profile \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.AddonProfileStore:Delete(data.setID) then
                    if data.onConfirm then
                        data.onConfirm()
                    end
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show(DELETE_DIALOG, set.name or "Unnamed Profile", nil, {
        setID = setID,
        onConfirm = onConfirm,
    })
end
