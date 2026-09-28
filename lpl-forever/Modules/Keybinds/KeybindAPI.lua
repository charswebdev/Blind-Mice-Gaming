local _, LPL = ...

LPL.KeybindAPI = LPL.KeybindAPI or {}
local API = LPL.KeybindAPI

local KEY = "keybinds"

local function IsSpacer(command)
    if type(command) ~= "string" or command == "" then
        return true
    end
    if command:sub(1, 6) == "HEADER" then
        return true
    end
    if command:sub(1, 7) == "PREFACE" then
        return true
    end
    return false
end

local function CopyBindings(bindings)
    local out = {}
    if type(bindings) ~= "table" then
        return out
    end
    for command, keys in pairs(bindings) do
        local name = LPL:PlainString(command)
        if name and not IsSpacer(name) and type(keys) == "table" then
            out[name] = {
                key1 = LPL:PlainString(keys.key1),
                key2 = LPL:PlainString(keys.key2),
            }
        end
    end
    return out
end

function API:Available()
    return GetBinding ~= nil and SetBinding ~= nil and SaveBindings ~= nil
end

function API:Capture()
    local bindings = {}
    local skipped = 0
    if not GetNumBindings or not GetBinding then
        return { bindings = bindings, scope = "account", skipped = 0 }
    end
    local count = GetNumBindings() or 0
    for index = 1, count do
        local command, _, key1, key2 = GetBinding(index)
        local secret = false
        if issecretvalue then
            if command ~= nil then
                local ok, value = pcall(issecretvalue, command)
                secret = ok and value
            end
            if not secret and key1 ~= nil then
                local ok, value = pcall(issecretvalue, key1)
                secret = ok and value
            end
            if not secret and key2 ~= nil then
                local ok, value = pcall(issecretvalue, key2)
                secret = ok and value
            end
        end
        if secret then
            skipped = skipped + 1
        else
            command = LPL:PlainString(command)
            if command and not IsSpacer(command) then
                bindings[command] = {
                    key1 = LPL:PlainString(key1),
                    key2 = LPL:PlainString(key2),
                }
            end
        end
    end
    local scope = "account"
    if GetCurrentBindingSet and GetCurrentBindingSet() == 2 then
        scope = "character"
    end
    return { bindings = bindings, scope = scope, skipped = skipped }
end

function API:Count(set)
    local count = 0
    if type(set) ~= "table" or type(set.bindings) ~= "table" then
        return 0
    end
    for _, keys in pairs(set.bindings) do
        if type(keys) == "table" and (LPL:PlainString(keys.key1) or LPL:PlainString(keys.key2)) then
            count = count + 1
        end
    end
    return count
end

function API:Summary(set)
    local count = self:Count(set)
    local scope = (set and set.scope == "character") and "Character" or "Account"
    local label = count == 1 and "1 key" or (tostring(count) .. " keys")
    return scope .. " · " .. label
end

local function SameKeys(a, b)
    local a1 = a and LPL:PlainString(a.key1) or nil
    local a2 = a and LPL:PlainString(a.key2) or nil
    local b1 = b and LPL:PlainString(b.key1) or nil
    local b2 = b and LPL:PlainString(b.key2) or nil
    return a1 == b1 and a2 == b2
end

function API:Matches(set, live)
    if type(set) ~= "table" then
        return false
    end
    live = live or self:Capture()
    local saved = CopyBindings(set.bindings)
    local current = CopyBindings(live.bindings)
    for command, keys in pairs(saved) do
        if not SameKeys(keys, current[command]) then
            return false
        end
    end
    for command, keys in pairs(current) do
        if not SameKeys(keys, saved[command]) then
            return false
        end
    end
    return true
end

function API:List()
    return LPL.SetStore:List(KEY)
end

function API:Get(id)
    return LPL.SetStore:Get(KEY, id)
end

function API:Save(draft, name)
    local record = {
        bindings = CopyBindings(draft and draft.bindings),
        scope = (draft and draft.scope == "character") and "character" or "account",
    }
    return LPL.SetStore:Save(KEY, record, name, LPL.SetStore:SuggestName(KEY, "Keys"))
end

function API:Update(id, draft, name)
    local record = {
        bindings = CopyBindings(draft and draft.bindings),
        scope = (draft and draft.scope == "character") and "character" or "account",
    }
    return LPL.SetStore:Update(KEY, id, record, name, "Keys")
end

function API:Delete(id)
    return LPL.SetStore:Delete(KEY, id)
end

function API:SuggestName()
    return LPL.SetStore:SuggestName(KEY, "Keys")
end

function API:DisplayName(command)
    command = LPL:PlainString(command) or "Binding"
    if GetBindingName then
        local ok, name = pcall(GetBindingName, command)
        local plain = ok and LPL:PlainString(name) or nil
        if plain then
            return plain
        end
    end
    local globalName = _G["BINDING_NAME_" .. command]
    return LPL:PlainString(globalName) or command
end

function API:FormatKey(key)
    key = LPL:PlainString(key)
    if not key or key == "" then
        return LPL:PlainString(NOT_BOUND) or "Not Bound"
    end
    if GetBindingText then
        local text = GetBindingText(key)
        local plain = LPL:PlainString(text)
        if plain then
            return plain
        end
    end
    return key
end

local function CategoryTitle(category)
    category = LPL:PlainString(category)
    if not category or category == "" then
        return "Other"
    end
    local title = LPL:PlainString(_G[category])
    if title and title ~= "" then
        return title
    end
    return category
end

function API:EditorLines(set)
    local lines = {}
    local saved = type(set) == "table" and type(set.bindings) == "table" and set.bindings or {}
    if not GetNumBindings or not GetBinding then
        return lines
    end
    local count = GetNumBindings() or 0
    local lastCategory = nil
    local header = nil
    for index = 1, count do
        local ok, command, category = pcall(GetBinding, index)
        if ok then
            local secret = false
            if issecretvalue and command ~= nil then
                local secretOk, value = pcall(issecretvalue, command)
                secret = secretOk and value
            end
            command = (not secret) and LPL:PlainString(command) or nil
            if command and not IsSpacer(command) then
                local categoryId = LPL:PlainString(category)
                if not categoryId or categoryId == "" then
                    categoryId = "Other"
                end
                local title = CategoryTitle(category)
                if categoryId ~= lastCategory then
                    header = {
                        kind = "header",
                        id = categoryId,
                        left = title,
                        count = 0,
                    }
                    lines[#lines + 1] = header
                    lastCategory = categoryId
                end
                if header then
                    header.count = header.count + 1
                end
                local stored = saved[command]
                local raw1 = type(stored) == "table" and LPL:PlainString(stored.key1) or nil
                local raw2 = type(stored) == "table" and LPL:PlainString(stored.key2) or nil
                lines[#lines + 1] = {
                    kind = "command",
                    command = command,
                    left = self:DisplayName(command),
                    key1 = self:FormatKey(raw1),
                    key2 = self:FormatKey(raw2),
                    bound1 = raw1 ~= nil,
                    bound2 = raw2 ~= nil,
                }
            end
        end
    end
    return lines
end

function API:AssignKey(set, command, slot, newKey)
    command = LPL:PlainString(command)
    if not set or not command then
        return
    end
    set.bindings = set.bindings or {}
    newKey = LPL:PlainString(newKey)
    if newKey == "" then
        newKey = nil
    end
    if newKey then
        for _, keys in pairs(set.bindings) do
            if type(keys) == "table" then
                if LPL:PlainString(keys.key1) == newKey then
                    keys.key1 = nil
                end
                if LPL:PlainString(keys.key2) == newKey then
                    keys.key2 = nil
                end
            end
        end
    end
    local keys = set.bindings[command]
    if type(keys) ~= "table" then
        keys = {}
        set.bindings[command] = keys
    end
    if slot == 2 then
        keys.key2 = newKey
    else
        keys.key1 = newKey
    end
end

function API:ClearKey(set, command, slot)
    command = LPL:PlainString(command)
    if not set or not command then
        return
    end
    set.bindings = set.bindings or {}
    local keys = set.bindings[command]
    if type(keys) ~= "table" then
        keys = {}
        set.bindings[command] = keys
    end
    if slot == 2 then
        keys.key2 = nil
    else
        keys.key1 = nil
    end
end

function API:ClearCommand(set, command)
    command = LPL:PlainString(command)
    if not set or type(set.bindings) ~= "table" or not command then
        return
    end
    set.bindings[command] = { key1 = nil, key2 = nil }
end

local function SetKey(key, command)
    if not key or not SetBinding then
        return false
    end
    local ok, result = pcall(SetBinding, key, command)
    return ok and result ~= false
end

local function ApplyToSet(bindingSet, bindings)
    if LoadBindings then
        local loaded = pcall(LoadBindings, bindingSet)
        if not loaded then
            return 0, 0
        end
    end
    if not GetNumBindings or not GetBinding then
        return 0, 0
    end
    local snapshot = {}
    local count = GetNumBindings() or 0
    for index = 1, count do
        local command, _, key1, key2 = GetBinding(index)
        command = LPL:PlainString(command)
        if command and not IsSpacer(command) then
            snapshot[#snapshot + 1] = {
                command = command,
                key1 = LPL:PlainString(key1),
                key2 = LPL:PlainString(key2),
            }
        end
    end
    for i = 1, #snapshot do
        local row = snapshot[i]
        if row.key1 then
            SetKey(row.key1, nil)
        end
        if row.key2 then
            SetKey(row.key2, nil)
        end
    end
    local assigned, failed = 0, 0
    for command, keys in pairs(bindings) do
        if keys.key1 then
            if SetKey(keys.key1, command) then
                assigned = assigned + 1
            else
                failed = failed + 1
            end
        end
        if keys.key2 then
            if SetKey(keys.key2, command) then
                assigned = assigned + 1
            else
                failed = failed + 1
            end
        end
    end
    if SaveBindings then
        local saved = pcall(SaveBindings, bindingSet)
        if not saved then
            return assigned, failed + 1
        end
    end
    return assigned, failed
end

function API:Apply(set)
    if not self:Available() then
        return false, "Key bindings are not available on this client."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat, then apply key bindings."
    end
    if type(set) ~= "table" then
        return false, "Select a saved keybinding profile first."
    end
    local bindings = CopyBindings(set.bindings)
    local current = GetCurrentBindingSet and GetCurrentBindingSet() or 1
    local assigned, failed = 0, 0
    for _, bindingSet in ipairs({ 1, 2 }) do
        local a, f = ApplyToSet(bindingSet, bindings)
        assigned = math.max(assigned, a or 0)
        failed = failed + (f or 0)
    end
    if LoadBindings then
        pcall(LoadBindings, current)
    end
    if failed > 0 then
        return false, "Applied " .. assigned .. " keys. " .. failed .. " could not be bound."
    end
    if assigned == 0 then
        return true, "This profile has no keys. Your bindings were cleared."
    end
    return true, "Applied " .. assigned .. " keys."
end
