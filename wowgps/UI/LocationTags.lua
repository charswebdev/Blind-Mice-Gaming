local _, ns = ...

local LocationTags = {}
ns.LocationTags = LocationTags

local INVALID_TAGS = {
    custom = true,
    account = true,
    character = true,
}

-- Removed from the shared Type dropdown; strip on save/display.
local REMOVED_TAGS = {
    meet = true,
    roast = true,
    ["meet and roast"] = true,
}

-- Map Add/Search type options onto official catalog destination types.
local TAG_TO_DEST_TYPE = {
    ["NPC"] = "npc",
    ["Dungeon entrance"] = "dungeon",
    ["Raid entrance"] = "raid",
    ["Delve entrance"] = "delve",
    ["Cave entrance"] = "cave",
}

function LocationTags:GetLocaleKey(tag)
    return "TAG_" .. tag:upper():gsub(" ", "_")
end

function LocationTags:GetLabel(tag)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    return L[self:GetLocaleKey(tag)] or tag
end

function LocationTags:IsAllowedTag(tag)
    if not tag or tag == "" then
        return false
    end
    local lower = tag:lower()
    if INVALID_TAGS[lower] or REMOVED_TAGS[lower] then
        return false
    end
    return true
end

function LocationTags:FilterValid(tags)
    local result = {}
    for _, tag in ipairs(tags or {}) do
        if self:IsAllowedTag(tag) then
            result[#result + 1] = tag
        end
    end
    return result
end

--- Shared Type dropdown options used by Add, Search, and any other filter.
--- includeAll: prepend "All" for filter dropdowns (Search).
function LocationTags:GetTypeOptions(includeAll)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local options = {}
    if includeAll then
        options[#options + 1] = { key = "all", label = L["FILTER_ALL"] }
    end
    for _, tag in ipairs(ns.Constants.TAGS) do
        options[#options + 1] = {
            key = tag,
            label = self:GetLabel(tag),
        }
    end
    return options
end

function LocationTags:GetTypeLabel(key)
    if not key or key == "all" then
        return nil
    end
    return self:GetLabel(key)
end

function LocationTags:EntryHasTag(entry, tag)
    if not entry or not tag or tag == "all" then
        return true
    end
    for _, t in ipairs(entry.tags or {}) do
        if t == tag then
            return true
        end
    end
    return false
end

--- Whether a search/catalog entry matches the shared Type filter key.
function LocationTags:EntryMatchesType(entry, typeKey)
    if not typeKey or typeKey == "all" then
        return true
    end
    if not entry then
        return false
    end

    if entry.custom or entry.tags then
        if self:EntryHasTag(entry, typeKey) then
            return true
        end
        -- Customs without the selected tag should not match via dest type.
        if entry.custom then
            return false
        end
    end

    local destType = TAG_TO_DEST_TYPE[typeKey]
    if destType and entry.type == destType then
        return true
    end

    return false
end

function LocationTags:FormatList(tags)
    tags = self:FilterValid(tags)
    if #tags == 0 then
        return nil
    end
    local labels = {}
    for _, tag in ipairs(tags) do
        labels[#labels + 1] = self:GetLabel(tag)
    end
    return table.concat(labels, ", ")
end

function LocationTags:FormatBracket(tags)
    local text = self:FormatList(tags)
    if not text then
        return nil
    end
    return string.format("[%s]", text)
end

function LocationTags:SetSelectedFromRecord(selectedTags, record)
    wipe(selectedTags)
    for _, tag in ipairs(ns.CustomLocations:GetTags(record)) do
        selectedTags[tag] = true
    end
end

function LocationTags:CollectSelected(selectedTags)
    local tags = {}
    for _, tag in ipairs(ns.Constants.TAGS) do
        if selectedTags[tag] then
            tags[#tags + 1] = tag
        end
    end
    return tags
end
