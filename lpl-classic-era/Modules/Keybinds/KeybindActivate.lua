local addonName, LPL = ...

LPL.KeybindActivate = {}

local function Fail(message)
    print("|cffff6060LPL:|r " .. (message or "Could not apply keybinding profile."))
    return false, message
end

local function Success(message)
    if LPL.ActivateFeedback then
        LPL.ActivateFeedback:Play(message)
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

-- SetBinding's third argument is binding-set mode (1 = current, 2 = other set),
-- not C_KeyBindings action context. Always write the currently loaded set.
local function SetBindingOnCurrentSet(key, command)
    if type(key) ~= "string" or key == "" then
        return false
    end
    local ok, result = pcall(SetBinding, key, command)
    return ok and result ~= false
end

local function UnbindKey(key)
    if type(key) ~= "string" or key == "" then
        return
    end
    SetBindingOnCurrentSet(key, nil)
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
        for k = 1, #row.keys do
            UnbindKey(row.keys[k])
        end
        if GetBindingKey then
            for _ = 1, 16 do
                local leftover = GetBindingKey(row.command)
                if type(leftover) ~= "string" or leftover == "" then
                    break
                end
                UnbindKey(leftover)
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
            if keys.key1 then
                if SetBindingOnCurrentSet(keys.key1, command) then
                    assigned = assigned + 1
                else
                    failed = failed + 1
                end
            end
            if keys.key2 then
                if SetBindingOnCurrentSet(keys.key2, command) then
                    assigned = assigned + 1
                else
                    failed = failed + 1
                end
            end
        end
    end
    return assigned, failed
end

local function ApplySetData(setData, setName, options)
    options = options or {}
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
    local preferredSet, scope = BindingSetForScope(setData.scope)
    local scopeLabel = scope == LPL.KeybindStore.SCOPE_CHARACTER and "Character" or "Account"
    setName = setName or setData.name or "Keybinding Profile"

    if not LoadBindings then
        return Fail("Key binding API is not available.")
    end

    -- Classic Era loads whichever set GetCurrentBindingSet() points at on login.
    -- Write the profile into BOTH account and character sets so it cannot snap
    -- back to Blizzard defaults when character-specific bindings are enabled.
    local targets = {}
    local seen = {}
    local function pushTarget(setIndex)
        setIndex = tonumber(setIndex)
        if not setIndex or seen[setIndex] then
            return
        end
        seen[setIndex] = true
        targets[#targets + 1] = setIndex
    end
    pushTarget(preferredSet)
    if GetCurrentBindingSet then
        pushTarget(GetCurrentBindingSet())
    end
    pushTarget(1)
    pushTarget(2)

    local assigned, failed = 0, 0
    for i = 1, #targets do
        local bindingSet = targets[i]
        local loaded = pcall(LoadBindings, bindingSet)
        if loaded then
            local unbound, unbindErr = UnbindAllCommands()
            if not unbound then
                return Fail(unbindErr)
            end
            local a, f = ApplyProfileBindings(bindings)
            assigned = math.max(assigned, a or 0)
            failed = failed + (f or 0)
            local saved = pcall(SaveBindings, bindingSet)
            if not saved then
                return Fail("Bindings were applied but could not be saved. Try again out of combat.")
            end
        end
    end

    -- Leave the client on the profile's preferred set (or current).
    local leaveOn = preferredSet
    if GetCurrentBindingSet then
        leaveOn = GetCurrentBindingSet() or leaveOn
    end
    pcall(LoadBindings, leaveOn)

    if not options.skipRemember and setData.id and LPL.EditModePersist and LPL.EditModePersist.RememberKeybindSet then
        LPL.EditModePersist:RememberKeybindSet(setData.id, scope)
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
    if options.silent then
        print("|cff33cc33LPL:|r " .. message)
        return true
    end
    return Success(message)
end

function LPL.KeybindActivate:ApplySet(setID, options)
    if not setID then
        return Fail("No keybinding profile selected.")
    end
    local set = LPL.KeybindStore:Get(setID)
    if not set then
        return Fail("Keybinding profile not found.")
    end
    local copy = CopyTable(set)
    copy.id = set.id or setID
    return ApplySetData(copy, set.name, options)
end

function LPL.KeybindActivate:ApplyDraft(draftSet, name, options)
    if type(draftSet) ~= "table" then
        return Fail("Nothing to apply.")
    end
    local draft = CopyTable(draftSet)
    draft.name = name or draft.name
    if LPL.KeybindStore then
        draft.scope = LPL.KeybindStore:NormalizeScope(draft.scope)
        draft.bindings = LPL.KeybindStore:NormalizeBindings(draft.bindings)
    end
    return ApplySetData(draft, draft.name, options)
end

function LPL.KeybindActivate:Apply()
    return self:ApplySet()
end
