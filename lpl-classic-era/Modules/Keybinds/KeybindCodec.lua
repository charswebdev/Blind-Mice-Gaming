local addonName, LPL = ...

LPL.KeybindCodec = {}

local function TrimKey(value)
    if type(value) ~= "string" then
        return nil
    end
    value = value:match("^%s*(.-)%s*$") or ""
    if value == "" then
        return nil
    end
    return value
end

-- Retail Settings groups by GetBinding's category, not HEADER_ rows.
-- HEADER_* / PREFACE_* are spacers and labels inside a category.
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

-- Same lookup Blizzard uses in SettingsKeybindingSection (GetBindingCategoryName).
local function GetBindingCategoryName(cat)
    if type(cat) ~= "string" or cat == "" then
        return "Other"
    end
    local ok, loc = pcall(function()
        return _G[cat]
    end)
    if ok and type(loc) == "string" and loc ~= "" then
        return loc
    end
    return cat
end

-- Bindings.xml with header="FOO" but no category= comes back as nil from GetBinding.
-- Blizzard dumps those in Other; if BINDING_HEADER_FOO exists, file them there instead.
local function InferCategoryFromCommand(command)
    if type(command) ~= "string" or command == "" then
        return nil
    end
    local prefix = command:match("^([A-Z][A-Z0-9]*)_")
    if not prefix then
        return nil
    end
    local headerKey = "BINDING_HEADER_" .. prefix
    local title = GetBindingCategoryName(headerKey)
    if title ~= headerKey then
        return headerKey
    end
    return nil
end

local function LocalizedCommand(command)
    if type(command) ~= "string" or command == "" then
        return "Unknown"
    end
    if GetBindingName then
        local ok, name = pcall(GetBindingName, command)
        if ok and type(name) == "string" and name ~= "" then
            return name
        end
    end
    local name = _G["BINDING_NAME_" .. command]
    if type(name) == "string" and name ~= "" then
        return name
    end
    return command
end

function LPL.KeybindCodec:GetLiveScope()
    if GetCurrentBindingSet and GetCurrentBindingSet() == 2 then
        return "character"
    end
    return "account"
end

function LPL.KeybindCodec:GetBindingCount()
    if not GetNumBindings then
        return 0
    end
    return GetNumBindings() or 0
end

function LPL.KeybindCodec:CaptureLiveBindings()
    local bindings = {}
    local count = self:GetBindingCount()
    if count < 1 or not GetBinding then
        return bindings
    end

    for index = 1, count do
        local command, _, key1, key2 = GetBinding(index)
        if not IsSpacerOrPreface(command) then
            bindings[command] = {
                key1 = TrimKey(key1),
                key2 = TrimKey(key2),
            }
        end
    end

    return bindings
end

-- Same grouping as Blizzard Settings: category is the expander, HEADER_ is a spacer.
function LPL.KeybindCodec:GetCatalog()
    local sections = {}
    local byCategory = {}
    local count = self:GetBindingCount()
    if count < 1 or not GetBinding then
        return sections
    end

    local otherKey = "BINDING_HEADER_OTHER"

    for index = 1, count do
        local command, category, key1, key2 = GetBinding(index)
        if not IsSpacerOrPreface(command) then
            local catKey = (type(category) == "string" and category ~= "") and category or nil
            if not catKey then
                catKey = InferCategoryFromCommand(command) or otherKey
            end
            local section = byCategory[catKey]
            if not section then
                section = {
                    header = catKey,
                    title = GetBindingCategoryName(catKey),
                    commands = {},
                }
                byCategory[catKey] = section
                sections[#sections + 1] = section
            end
            section.commands[#section.commands + 1] = {
                command = command,
                category = category,
                name = LocalizedCommand(command),
                key1 = TrimKey(key1),
                key2 = TrimKey(key2),
            }
        end
    end

    return sections
end

function LPL.KeybindCodec:GetCommandDisplayName(command)
    return LocalizedCommand(command)
end

function LPL.KeybindCodec:FormatKey(key)
    key = TrimKey(key)
    if not key then
        return NOT_BOUND or "Not Bound"
    end
    if GetBindingText then
        local text = GetBindingText(key)
        if type(text) == "string" and text ~= "" then
            return text
        end
    end
    return key
end

function LPL.KeybindCodec:AssignDraftKey(bindings, command, slot, newKey)
    if type(command) ~= "string" or command == "" then
        return bindings
    end
    bindings = type(bindings) == "table" and bindings or {}
    local keyField = slot == 2 and "key2" or "key1"
    newKey = TrimKey(newKey)

    if newKey then
        for _, keys in pairs(bindings) do
            if type(keys) == "table" then
                if keys.key1 == newKey then
                    keys.key1 = nil
                end
                if keys.key2 == newKey then
                    keys.key2 = nil
                end
            end
        end
    end

    local keys = bindings[command]
    if type(keys) ~= "table" then
        keys = {}
        bindings[command] = keys
    end
    keys[keyField] = newKey
    return bindings
end
