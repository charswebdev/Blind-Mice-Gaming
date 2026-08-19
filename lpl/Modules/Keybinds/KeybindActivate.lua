local addonName, LPL = ...

LPL.KeybindActivate = {}

local function Fail(message)
    print("|cffff6060LPL:|r " .. (message or "Could not apply keybinding profile."))
    return false, message
end

local function Success(message)
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play()
    end
    print("|cff33cc33LPL:|r " .. message)
    return true
end

local function IsSpacerOrPreface(command)
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

local function BindingSetForScope(scope)
    scope = LPL.KeybindStore:NormalizeScope(scope)
    if Enum and Enum.BindingSet then
        if scope == LPL.KeybindStore.SCOPE_CHARACTER then
            return Enum.BindingSet.Character or 2, scope
        end
        return Enum.BindingSet.Account or 1, scope
    end
    if scope == LPL.KeybindStore.SCOPE_CHARACTER then
        return 2, scope
    end
    return 1, scope
end

local function BindingContextForCommand(command)
    if type(command) ~= "string" or command == "" then
        return nil
    end
    if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
        local ok, context = pcall(C_KeyBindings.GetBindingContextForAction, command)
        if ok then
            return context
        end
    end
    return nil
end

local function TrySetBinding(key, command, context)
    if type(key) ~= "string" or key == "" then
        return false
    end
    if context ~= nil then
        local ok, result = pcall(SetBinding, key, command, context)
        if ok and result ~= false then
            return true
        end
    end
    local ok, result = pcall(SetBinding, key, command)
    return ok and result ~= false
end

local function UnbindKey(key, context)
    if type(key) ~= "string" or key == "" then
        return
    end
    TrySetBinding(key, nil, context)
    TrySetBinding(key, nil, nil)
end

local function CollectBindingKeys(index)
    local results = { pcall(GetBinding, index) }
    if not results[1] then
        return nil, {}
    end
    local command = results[2]
    local keys = {}
    for i = 4, #results do
        if type(results[i]) == "string" and results[i] ~= "" then
            keys[#keys + 1] = results[i]
        end
    end
    return command, keys
end

local function UnbindAllCommands()
    if not GetNumBindings or not SetBinding then
        return false, "Key binding API is not available."
    end
    local snapshot = {}
    local count = GetNumBindings() or 0
    for index = 1, count do
        local command, keys = CollectBindingKeys(index)
        if not IsSpacerOrPreface(command) then
            snapshot[#snapshot + 1] = {
                command = command,
                keys = keys,
            }
        end
    end
    for i = 1, #snapshot do
        local row = snapshot[i]
        local context = BindingContextForCommand(row.command)
        for k = 1, #row.keys do
            UnbindKey(row.keys[k], context)
        end
        if GetBindingKey then
            for _ = 1, 16 do
                local leftover = GetBindingKey(row.command)
                if type(leftover) ~= "string" or leftover == "" then
                    break
                end
                UnbindKey(leftover, context)
            end
        end
    end
    return true
end

local function ApplyProfileBindings(bindings)
    local assigned = 0
    local failed = 0
    for command, keys in pairs(bindings) do
        if type(command) == "string" and command ~= "" and type(keys) == "table" then
            local context = BindingContextForCommand(command)
            if keys.key1 then
                if TrySetBinding(keys.key1, command, context) then
                    assigned = assigned + 1
                else
                    failed = failed + 1
                end
            end
            if keys.key2 then
                if TrySetBinding(keys.key2, command, context) then
                    assigned = assigned + 1
                else
                    failed = failed + 1
                end
            end
        end
    end
    return assigned, failed
end

local function ApplySetData(setData, setName)
    if type(setData) ~= "table" then
        return Fail("Invalid keybinding profile.")
    end

    if InCombatLockdown and InCombatLockdown() then
        return Fail("Cannot activate keybinding profiles in combat.")
    end

    if not SetBinding or not SaveBindings then
        return Fail("Key binding API is not available.")
    end

    local bindings = LPL.KeybindStore:NormalizeBindings(setData.bindings)
    local bindingSet, scope = BindingSetForScope(setData.scope)
    local scopeLabel = scope == LPL.KeybindStore.SCOPE_CHARACTER and "Character" or "Account"
    setName = setName or setData.name or "Keybinding Profile"

    if GetCurrentBindingSet and LoadBindings and GetCurrentBindingSet() ~= bindingSet then
        local ok = pcall(LoadBindings, bindingSet)
        if not ok then
            return Fail("Could not switch to " .. scopeLabel .. " key bindings.")
        end
    end

    local unbound, unbindErr = UnbindAllCommands()
    if not unbound then
        return Fail(unbindErr)
    end

    local assigned, failed = ApplyProfileBindings(bindings)
    local saved = pcall(SaveBindings, bindingSet)
    if not saved then
        return Fail("Bindings were applied but could not be saved. Try again out of combat.")
    end

    local message = string.format(
        'Activated "%s" (%s · %d key%s).',
        setName,
        scopeLabel,
        assigned,
        assigned == 1 and "" or "s"
    )
    if failed > 0 then
        message = message .. string.format(" %d key%s could not be bound.", failed, failed == 1 and "" or "s")
    end
    return Success(message)
end

function LPL.KeybindActivate:ApplySet(setID)
    if not setID then
        return Fail("No keybinding profile selected.")
    end
    local set = LPL.KeybindStore:Get(setID)
    if not set then
        return Fail("Keybinding profile not found.")
    end
    return ApplySetData(CopyTable(set), set.name)
end

function LPL.KeybindActivate:ApplyDraft(draftSet, name)
    if type(draftSet) ~= "table" then
        return Fail("Nothing to apply.")
    end
    local draft = CopyTable(draftSet)
    draft.name = name or draft.name
    if LPL.KeybindStore then
        draft.scope = LPL.KeybindStore:NormalizeScope(draft.scope)
        draft.bindings = LPL.KeybindStore:NormalizeBindings(draft.bindings)
    end
    return ApplySetData(draft, draft.name)
end

function LPL.KeybindActivate:Apply()
    return self:ApplySet()
end
