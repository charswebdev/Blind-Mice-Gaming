local addonName, LPL = ...

LPL.KeybindActive = {}

local function KeysMatch(stored, live)
    stored = stored or {}
    live = live or {}
    return (stored.key1 or nil) == (live.key1 or nil)
        and (stored.key2 or nil) == (live.key2 or nil)
end

function LPL.KeybindActive:IsActive(set)
    if type(set) ~= "table" then
        return false
    end

    if not LPL.KeybindStore or not LPL.KeybindCodec then
        return false
    end

    local storedScope = LPL.KeybindStore:NormalizeScope(set.scope)
    local liveScope = LPL.KeybindStore:NormalizeScope(LPL.KeybindCodec:GetLiveScope())
    if storedScope ~= liveScope then
        return false
    end

    local stored = LPL.KeybindStore:NormalizeBindings(set.bindings)
    local live = LPL.KeybindStore:NormalizeBindings(LPL.KeybindCodec:CaptureLiveBindings())

    local hasAssigned = false
    local seen = {}

    for command, keys in pairs(stored) do
        seen[command] = true
        if (keys.key1 and keys.key1 ~= "") or (keys.key2 and keys.key2 ~= "") then
            hasAssigned = true
        end
        if not KeysMatch(keys, live[command]) then
            return false
        end
    end

    for command, keys in pairs(live) do
        if not seen[command] then
            if (keys.key1 and keys.key1 ~= "") or (keys.key2 and keys.key2 ~= "") then
                return false
            end
        end
    end

    return hasAssigned
end
