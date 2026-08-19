local addonName, LPL = ...

LPL.KeybindStore = {}

LPL.KeybindStore.MAX_NAME_LENGTH = 150
LPL.KeybindStore.SCOPE_ACCOUNT = "account"
LPL.KeybindStore.SCOPE_CHARACTER = "character"

local DELETE_DIALOG = "LPL_CONFIRM_DELETE_KEYBIND_PROFILE"
local DELETE_MULTI_DIALOG = "LPL_CONFIRM_DELETE_KEYBIND_PROFILES"

local function GetKeybindsData()
    return LPL.DB:GetKeybinds()
end

function LPL.KeybindStore:NormalizeSetName(name, fallback)
    fallback = fallback or "New Profile"
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

function LPL.KeybindStore:NormalizeScope(scope)
    if scope == self.SCOPE_CHARACTER then
        return self.SCOPE_CHARACTER
    end
    return self.SCOPE_ACCOUNT
end

function LPL.KeybindStore:NormalizeBindings(bindings)
    local map = {}
    if type(bindings) ~= "table" then
        return map
    end
    for command, keys in pairs(bindings) do
        if type(command) == "string" and command ~= "" then
            local key1, key2
            if type(keys) == "table" then
                key1 = keys.key1 or keys[1]
                key2 = keys.key2 or keys[2]
            elseif type(keys) == "string" then
                key1 = keys
            end
            if type(key1) ~= "string" or key1 == "" then
                key1 = nil
            end
            if type(key2) ~= "string" or key2 == "" then
                key2 = nil
            end
            map[command] = {
                key1 = key1,
                key2 = key2,
            }
        end
    end
    return map
end

function LPL.KeybindStore:CountAssignedBindings(bindings)
    bindings = self:NormalizeBindings(bindings)
    local count = 0
    for _, keys in pairs(bindings) do
        if (keys.key1 and keys.key1 ~= "") or (keys.key2 and keys.key2 ~= "") then
            count = count + 1
        end
    end
    return count
end

function LPL.KeybindStore:EnsureSetsTable()
    local data = GetKeybindsData()
    if type(data.sets) ~= "table" then
        data.sets = {}
    end
    if data.nextSetId == nil then
        data.nextSetId = 0
    end
    return data.sets
end

function LPL.KeybindStore:GenerateID()
    local data = GetKeybindsData()
    data.nextSetId = (data.nextSetId or 0) + 1
    return "keybind_" .. data.nextSetId
end

function LPL.KeybindStore:SuggestSetName()
    local base = "New Profile"
    if not self:FindByName(base) then
        return base
    end
    for n = 2, 99 do
        local candidate = base .. " " .. n
        if not self:FindByName(candidate) then
            return candidate
        end
    end
    return base .. " " .. tostring(time())
end

function LPL.KeybindStore:CaptureLiveBindings()
    if LPL.KeybindCodec and LPL.KeybindCodec.CaptureLiveBindings then
        return self:NormalizeBindings(LPL.KeybindCodec:CaptureLiveBindings())
    end
    return {}
end

function LPL.KeybindStore:GetLiveScope()
    if LPL.KeybindCodec and LPL.KeybindCodec.GetLiveScope then
        return self:NormalizeScope(LPL.KeybindCodec:GetLiveScope())
    end
    return self.SCOPE_ACCOUNT
end

function LPL.KeybindStore:NormalizeSetRecord(set)
    if type(set) ~= "table" then
        return nil
    end
    set.id = tostring(set.id or "")
    if set.id == "" then
        return nil
    end
    set.name = self:NormalizeSetName(set.name, "New Profile")
    set.scope = self:NormalizeScope(set.scope)
    set.bindings = self:NormalizeBindings(set.bindings)
    set.createdAt = tonumber(set.createdAt) or time()
    set.updatedAt = tonumber(set.updatedAt) or set.createdAt
    return set
end

function LPL.KeybindStore:CreateDraftSet(name)
    return {
        name = self:NormalizeSetName(name, self:SuggestSetName()),
        scope = self:GetLiveScope(),
        bindings = self:CaptureLiveBindings(),
    }
end

function LPL.KeybindStore:Get(setID)
    if not setID then
        return nil
    end
    local sets = self:EnsureSetsTable()
    return self:NormalizeSetRecord(sets[tostring(setID)])
end

function LPL.KeybindStore:GetAll()
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

function LPL.KeybindStore:FindByName(name)
    name = type(name) == "string" and name:lower():match("^%s*(.-)%s*$") or ""
    if name == "" then
        return nil
    end
    for _, set in ipairs(self:GetAll()) do
        if (set.name or ""):lower() == name then
            return set
        end
    end
    return nil
end

function LPL.KeybindStore:GetSummaryLine(set)
    if type(set) ~= "table" then
        return "Invalid profile"
    end
    local scopeLabel = set.scope == self.SCOPE_CHARACTER and "Character" or "Account"
    local count = self:CountAssignedBindings(set.bindings)
    return string.format("%s · %d bind%s", scopeLabel, count, count == 1 and "" or "s")
end

function LPL.KeybindStore:GetSummaryWarning()
    return false
end

function LPL.KeybindStore:CommitSet(set)
    set = self:NormalizeSetRecord(set)
    if not set then
        return false
    end
    local sets = self:EnsureSetsTable()
    set.updatedAt = time()
    sets[set.id] = set
    return true
end

function LPL.KeybindStore:Delete(setID)
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

function LPL.KeybindStore:ValidateForSave(draft)
    if type(draft) ~= "table" then
        return false, "Nothing to save."
    end
    local name = self:NormalizeSetName(draft.name, "")
    if name == "" then
        return false, "Enter a profile name before saving."
    end
    return true
end

function LPL.KeybindStore:SaveFromEditor(setID, name, draft, onSaved)
    draft = draft or {}
    draft.name = name
    local ok, err = self:ValidateForSave(draft)
    if not ok then
        print("|cffff6060LPL:|r " .. (err or "Could not save keybinding profile."))
        return false
    end

    name = self:NormalizeSetName(name, self:SuggestSetName())
    local scope = self:NormalizeScope(draft.scope)
    local bindings = self:NormalizeBindings(draft.bindings)

    if setID then
        local set = self:Get(setID)
        if not set then
            return false
        end
        set.name = name
        set.scope = scope
        set.bindings = bindings
        if not self:CommitSet(set) then
            return false
        end
        if onSaved then
            onSaved(setID, false)
        end
        print(string.format("|cff33cc33LPL:|r Saved keybinding profile \"%s\".", name))
        return true
    end

    local set = {
        id = self:GenerateID(),
        name = name,
        scope = scope,
        bindings = bindings,
        createdAt = time(),
        updatedAt = time(),
    }
    if not self:CommitSet(set) then
        return false
    end
    if onSaved then
        onSaved(set.id, true)
    end
    print(string.format("|cff33cc33LPL:|r Created keybinding profile \"%s\".", name))
    return true
end

function LPL.KeybindStore:CreateFromImport(importData, name)
    if type(importData) ~= "table" then
        return nil
    end
    local now = time()
    local set = {
        id = self:GenerateID(),
        name = self:NormalizeSetName(name, importData.name or "Imported Profile"),
        scope = self:NormalizeScope(importData.scope),
        bindings = self:NormalizeBindings(importData.bindings),
        createdAt = now,
        updatedAt = now,
    }
    if not self:CommitSet(set) then
        return nil
    end
    return set
end

function LPL.KeybindStore:ApplyImport(importData, setName, options)
    if type(importData) ~= "table" or type(options) ~= "table" or options.keybinds ~= true then
        return nil
    end

    setName = self:NormalizeSetName(setName, importData.name or "Imported Profile")
    local existing = options.existingKeybindID and self:Get(options.existingKeybindID)
        or self:FindByName(setName)

    if existing then
        existing.name = setName
        existing.scope = self:NormalizeScope(importData.scope or existing.scope)
        existing.bindings = self:NormalizeBindings(importData.bindings)
        existing.updatedAt = time()
        if not self:CommitSet(existing) then
            return nil
        end
        return existing
    end

    return self:CreateFromImport(importData, setName)
end

function LPL.KeybindStore:ConfirmDelete(setID, onConfirm)
    local set = self:Get(setID)
    if not set then
        return
    end

    if not StaticPopupDialogs[DELETE_DIALOG] then
        StaticPopupDialogs[DELETE_DIALOG] = {
            text = "Delete keybinding profile \"%s\"? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if data and data.setID and LPL.KeybindStore:Delete(data.setID) then
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

    StaticPopup_Show(DELETE_DIALOG, set.name or "Profile", nil, {
        setID = tostring(setID),
        onConfirm = onConfirm,
    })
end

function LPL.KeybindStore:ConfirmDeleteMany(setIDs, onConfirm)
    if type(setIDs) ~= "table" or #setIDs == 0 then
        return
    end
    if #setIDs == 1 then
        self:ConfirmDelete(setIDs[1], onConfirm)
        return
    end

    if not StaticPopupDialogs[DELETE_MULTI_DIALOG] then
        StaticPopupDialogs[DELETE_MULTI_DIALOG] = {
            text = "Delete %s selected keybinding profiles? This cannot be undone.",
            button1 = DELETE,
            button2 = CANCEL,
            OnAccept = function(self)
                local data = self.data
                if not data or type(data.setIDs) ~= "table" then
                    return
                end
                for _, setID in ipairs(data.setIDs) do
                    LPL.KeybindStore:Delete(setID)
                end
                if data.onConfirm then
                    data.onConfirm()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    StaticPopup_Show(DELETE_MULTI_DIALOG, tostring(#setIDs), nil, {
        setIDs = setIDs,
        onConfirm = onConfirm,
    })
end
