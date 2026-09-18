local addonName, LPL = ...

LPL.AddonCatalog = {}

--[[
  Detection policy (verified against addon sources + Wago/WeakAuras notes):
  - Prefer distinctive clipboard prefixes only.
  - Grid2 wraps exports as [=== <name> profile ===] + hex body.
  - MDT uses a lone "!" + LibDeflate EncodeForPrint (Nnoggie Transmission.lua).
    Named headers (!WA:, !PLATER:, !CELL:, !TMW, !E1!) are excluded first.
  - Opaque blobs (VuhDo base64, OmniCD/Details LibDeflate-print, BigWigs tokens,
    Healium with no share strings) stay Custom or dropdown-only without detect.
]]

local function IsLibDeflatePrintBlob(str)
    return type(str) == "string" and str:match("^[%w%(%)]+$") ~= nil
end

local function IsNamedBangHeader(str)
    if type(str) ~= "string" or not str:find("^!") then
        return false
    end
    return str:match("^!WA:%d+!") ~= nil
        or str:match("^![Pp][Ll][Aa][Tt][Ee][Rr]:%d+!") ~= nil
        or str:match("^![Cc][Ee][Ll][Ll]:%d+:") ~= nil
        or str:match("^![Tt][Mm][Ww]%d+!") ~= nil
        or str:match("^![Ee]%d+!") ~= nil
end

-- Known addons for Addons Manager. detect() returns true when paste matches.
LPL.AddonCatalog.ENTRIES = {
    {
        key = "weakauras",
        label = "WeakAuras",
        instructions = "Open WeakAuras (/wa) → New → Import → paste the string.",
        detect = function(str)
            return type(str) == "string" and str:match("^!WA:%d+!") ~= nil
        end,
    },
    {
        key = "elvui",
        label = "ElvUI",
        instructions = "Open ElvUI config → Profiles → Import → paste the string.",
        detect = function(str)
            return type(str) == "string" and str:match("^![Ee]%d+!") ~= nil
        end,
    },
    {
        key = "plater",
        label = "Plater",
        instructions = "Open Plater → Profiles / Import → paste the string.",
        detect = function(str)
            return type(str) == "string" and str:match("^![Pp][Ll][Aa][Tt][Ee][Rr]:%d+!") ~= nil
        end,
    },
    {
        key = "cell",
        label = "Cell",
        instructions = "Open Cell → About / Import → paste the string.",
        detect = function(str)
            return type(str) == "string" and str:match("^![Cc][Ee][Ll][Ll]:%d+:") ~= nil
        end,
    },
    {
        key = "tellmewhen",
        label = "TellMeWhen",
        instructions = "Open TellMeWhen options → Import → paste the string.",
        detect = function(str)
            return type(str) == "string" and str:match("^![Tt][Mm][Ww]%d+!") ~= nil
        end,
    },
    {
        key = "grid2",
        label = "Grid2",
        instructions = "Open Grid2 (/grid2) → General → Profiles → Import & Export → paste the string.",
        detect = function(str)
            -- Wago/Grid2: [=== <name> profile ===] then hex body
            return type(str) == "string" and str:match("%[=== .- profile ===%]") ~= nil
        end,
    },
    {
        key = "mdt",
        label = "Mythic Dungeon Tools",
        instructions = "Open MDT (/mdt) → Import → paste the route string.",
        detect = function(str)
            if type(str) ~= "string" or #str < 40 then
                return false
            end
            if not str:find("^!") or IsNamedBangHeader(str) then
                return false
            end
            -- Lone "!" + EncodeForPrint alphabet (MDT Transmission.lua)
            return IsLibDeflatePrintBlob(str:sub(2))
        end,
    },
    {
        key = "details",
        label = "Details!",
        instructions = "Open Details! options → Profiles → Import → paste the string.",
        detect = function(str)
            if type(str) ~= "string" or #str < 280 then
                return false
            end
            if str:find("^!") then
                return false
            end
            -- Raw EncodeForPrint (no header). May also match some OmniCD strings.
            return IsLibDeflatePrintBlob(str) and str:find("%(") ~= nil and str:find("%)") ~= nil
        end,
    },
    -- Dropdown labels only — no reliable unique clipboard prefix.
    {
        key = "vuhdo",
        label = "VuhDo",
        instructions = "Open VuhDo (/vd opt) → Tools → Profiles → Import → paste the string.",
        detect = function()
            return false
        end,
    },
    {
        key = "omnicd",
        label = "OmniCD",
        instructions = "Open OmniCD (/oc) → Profiles → Import → paste the string.",
        detect = function()
            return false
        end,
    },
    {
        key = "bigwigs",
        label = "BigWigs",
        instructions = "Open BigWigs (/bw) → Options → Profiles → Import → paste the string.",
        detect = function()
            return false
        end,
    },
    {
        key = "platynator",
        label = "Platynator",
        instructions = "Open Platynator (/platynator) → General → Import → paste the string.",
        detect = function()
            return false
        end,
    },
    {
        key = "suf",
        label = "Shadowed Unit Frames",
        instructions = "Open SUF (/suf) → Layout Manager → Import → paste the string.",
        detect = function()
            return false
        end,
    },
    {
        key = "custom",
        label = "Custom",
        instructions = "Paste this string into the target addon’s import UI.",
        detect = function()
            return false
        end,
    },
}

function LPL.AddonCatalog:GetDropdownItems()
    local items = {}
    for _, entry in ipairs(self.ENTRIES) do
        items[#items + 1] = { id = entry.key, name = entry.label }
    end
    return items
end

function LPL.AddonCatalog:Get(key)
    for _, entry in ipairs(self.ENTRIES) do
        if entry.key == key then
            return entry
        end
    end
    return nil
end

function LPL.AddonCatalog:GetLabel(key, customLabel)
    if key == "custom" and type(customLabel) == "string" and customLabel ~= "" then
        return customLabel
    end
    local entry = self:Get(key)
    return entry and entry.label or (customLabel or "Custom")
end

function LPL.AddonCatalog:GetInstructions(key)
    local entry = self:Get(key) or self:Get("custom")
    return entry and entry.instructions or ""
end

function LPL.AddonCatalog:Detect(str)
    if type(str) ~= "string" or str == "" then
        return "custom"
    end
    local trimmed = str:match("^%s*(.-)%s*$") or str
    local bestKey, bestPri
    for index, entry in ipairs(self.ENTRIES) do
        if entry.key ~= "custom" and entry.detect and entry.detect(trimmed) then
            local pri = 1000 - index
            if not bestPri or pri > bestPri then
                bestKey, bestPri = entry.key, pri
            end
        end
    end
    return bestKey or "custom"
end
