local _, LPL = ...

LPL.LoadoutAPI = LPL.LoadoutAPI or {}
local API = LPL.LoadoutAPI

local KEY = "loadouts"

local SEGMENTS = {
    { key = "talents", label = "Talents" },
    { key = "actionbars", label = "Action Bars" },
    { key = "keybinds", label = "Keybinding Profiles" },
    { key = "equipment", label = "Equipment" },
    { key = "editmode", label = "Edit Mode" },
}

local function CopyIdList(value)
    local out = {}
    local seen = {}
    local function Push(entry)
        local id = LPL:PlainNumber(entry)
        if id and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    if type(value) == "table" then
        for i = 1, #value do
            Push(value[i])
        end
    else
        Push(value)
    end
    return out
end

local function CopyLinks(links)
    local out = {}
    if type(links) ~= "table" then
        return out
    end
    for i = 1, #SEGMENTS do
        local ids = CopyIdList(links[SEGMENTS[i].key])
        if #ids > 0 then
            out[SEGMENTS[i].key] = ids
        end
    end
    return out
end

local function Records(key)
    if key == "talents" and LPL.TalentStore then
        return LPL.TalentStore:List()
    end
    if key == "actionbars" and LPL.ActionBarAPI then
        return LPL.ActionBarAPI:List()
    end
    if key == "keybinds" and LPL.KeybindAPI then
        return LPL.KeybindAPI:List()
    end
    if key == "equipment" and LPL.EquipmentAPI then
        return LPL.EquipmentAPI:List()
    end
    if key == "editmode" and LPL.EditModeAPI then
        return LPL.EditModeAPI:List()
    end
    return {}
end

local function FindRecord(key, id)
    id = LPL:PlainNumber(id)
    if not id then
        return nil
    end
    if key == "talents" and LPL.TalentStore then
        return LPL.TalentStore:Get(id)
    end
    if key == "actionbars" and LPL.ActionBarAPI then
        return LPL.ActionBarAPI:Get(id)
    end
    if key == "keybinds" and LPL.KeybindAPI then
        return LPL.KeybindAPI:Get(id)
    end
    if key == "equipment" and LPL.EquipmentAPI then
        return LPL.EquipmentAPI:Get(id)
    end
    if key == "editmode" and LPL.EditModeAPI then
        return LPL.EditModeAPI:Get(id)
    end
    return nil
end

local function SegmentMatches(key, id)
    local record = FindRecord(key, id)
    if not record then
        return false
    end
    if key == "talents" then
        return LPL.TalentAPI and LPL.TalentAPI:MatchesLive(record) or false
    end
    if key == "actionbars" then
        return LPL.ActionBarAPI and LPL.ActionBarAPI:Matches(record) or false
    end
    if key == "keybinds" then
        return LPL.KeybindAPI and LPL.KeybindAPI:Matches(record) or false
    end
    if key == "equipment" then
        return LPL.EquipmentAPI and LPL.EquipmentAPI:Matches(record) or false
    end
    if key == "editmode" then
        return LPL.EditModeAPI and LPL.EditModeAPI:Matches(record) or false
    end
    return false
end

function API:Available()
    return true
end

function API:Segments()
    return SEGMENTS
end

function API:List()
    return LPL.SetStore:List(KEY)
end

function API:Get(id)
    return LPL.SetStore:Get(KEY, id)
end

function API:SuggestName()
    return LPL.SetStore:SuggestName(KEY, "Loadout")
end

function API:Empty()
    return {
        name = self:SuggestName(),
        links = {},
    }
end

function API:LinkIDs(set, key)
    local links = set and set.links
    if type(links) ~= "table" then
        return {}
    end
    return CopyIdList(links[key])
end

function API:LinkName(key, id)
    if not LPL:PlainNumber(id) then
        return "None"
    end
    local record = FindRecord(key, id)
    return (record and LPL:PlainString(record.name)) or "Missing set"
end

function API:LinkSummary(key, id)
    if not LPL:PlainNumber(id) then
        return "Not attached"
    end
    local record = FindRecord(key, id)
    if not record then
        return "Missing set"
    end
    if key == "talents" then
        local classID = LPL:PlainNumber(record.classID)
        local className
        if classID and GetClassInfo then
            local ok, name = pcall(GetClassInfo, classID)
            className = ok and LPL:PlainString(name) or nil
        end
        local points = LPL.TalentAPI and LPL.TalentAPI:Summary(record) or ""
        if className and points ~= "" then
            return className .. " · " .. points
        end
        return points ~= "" and points or (className or "Talent build")
    end
    if key == "actionbars" and LPL.ActionBarAPI then
        return LPL.ActionBarAPI:Summary(record)
    end
    if key == "keybinds" and LPL.KeybindAPI then
        return LPL.KeybindAPI:Summary(record)
    end
    if key == "equipment" and LPL.EquipmentAPI then
        return LPL.EquipmentAPI:Summary(record)
    end
    if key == "editmode" and LPL.EditModeAPI then
        return LPL.EditModeAPI:Summary(record)
    end
    return "Attached"
end

function API:MenuItems(key)
    local items = { { id = nil, name = "None" } }
    local records = Records(key)
    if key ~= "talents" then
        local named = {}
        for i = 1, #records do
            local id = LPL:PlainNumber(records[i].id)
            if id then
                named[#named + 1] = {
                    id = id,
                    name = LPL:PlainString(records[i].name) or "Set",
                }
            end
        end
        table.sort(named, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
        for i = 1, #named do
            items[#items + 1] = named[i]
        end
        return items
    end

    local groups = {}
    local order = {}
    for i = 1, #records do
        local id = LPL:PlainNumber(records[i].id)
        if id then
            local classID = LPL:PlainNumber(records[i].classID)
            local className = "Other"
            if classID and GetClassInfo then
                local ok, name = pcall(GetClassInfo, classID)
                className = (ok and LPL:PlainString(name)) or className
            end
            local group = groups[className]
            if not group then
                group = {}
                groups[className] = group
                order[#order + 1] = className
            end
            group[#group + 1] = {
                id = id,
                name = LPL:PlainString(records[i].name) or "Build",
            }
        end
    end
    table.sort(order, function(a, b)
        return a:lower() < b:lower()
    end)
    for i = 1, #order do
        local className = order[i]
        items[#items + 1] = { header = true, name = className }
        local group = groups[className]
        table.sort(group, function(a, b)
            return a.name:lower() < b.name:lower()
        end)
        for n = 1, #group do
            items[#items + 1] = group[n]
        end
    end
    return items
end

function API:Summary(set)
    local links = CopyLinks(set and set.links)
    local count = 0
    for i = 1, #SEGMENTS do
        local ids = links[SEGMENTS[i].key]
        if ids then
            count = count + #ids
        end
    end
    if count == 0 then
        return "No pieces selected"
    end
    if count == 1 then
        return "1 piece"
    end
    return tostring(count) .. " pieces"
end

function API:Capture()
    local links = {}
    for i = 1, #SEGMENTS do
        local key = SEGMENTS[i].key
        local records = Records(key)
        for n = 1, #records do
            local id = LPL:PlainNumber(records[n].id)
            if id and SegmentMatches(key, id) then
                links[key] = { id }
                break
            end
        end
    end
    return { links = links }
end

function API:Matches(set, live)
    local links = CopyLinks(set and set.links)
    local any = false
    for i = 1, #SEGMENTS do
        local ids = links[SEGMENTS[i].key]
        local id = ids and ids[1]
        if id then
            any = true
            if not SegmentMatches(SEGMENTS[i].key, id) then
                return false
            end
        end
    end
    return any
end

local function RecordFrom(draft)
    return {
        links = CopyLinks(draft and draft.links),
    }
end

function API:Save(draft, name)
    return LPL.SetStore:Save(KEY, RecordFrom(draft), name, self:SuggestName())
end

function API:Update(id, draft, name)
    return LPL.SetStore:Update(KEY, id, RecordFrom(draft), name, "Loadout")
end

function API:Delete(id)
    return LPL.SetStore:Delete(KEY, id)
end

local function ApplySegment(key, id)
    if key == "talents" then
        local build = FindRecord(key, id)
        if not build or not LPL.TalentAPI then
            return false, "that talent build is missing"
        end
        return LPL.TalentAPI:Apply(build)
    end
    if key == "actionbars" then
        local set = FindRecord(key, id)
        if not set or not LPL.ActionBarAPI then
            return false, "that action bar set is missing"
        end
        return LPL.ActionBarAPI:Apply(set)
    end
    if key == "keybinds" then
        local set = FindRecord(key, id)
        if not set or not LPL.KeybindAPI then
            return false, "that keybinding profile is missing"
        end
        return LPL.KeybindAPI:Apply(set)
    end
    if key == "equipment" then
        local set = FindRecord(key, id)
        if not set or not LPL.EquipmentAPI then
            return false, "that equipment set is missing"
        end
        return LPL.EquipmentAPI:Apply(set)
    end
    if key == "editmode" then
        local set = FindRecord(key, id)
        if not set or not LPL.EditModeAPI then
            return false, "that Edit Mode layout is missing"
        end
        return LPL.EditModeAPI:Apply(set)
    end
    return false, "unknown piece"
end

function API:Apply(set)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat, then apply this loadout."
    end
    local links = CopyLinks(set and set.links)
    local any = false
    for i = 1, #SEGMENTS do
        if links[SEGMENTS[i].key] then
            any = true
            break
        end
    end
    if not any then
        return true, "This loadout has no pieces selected."
    end

    local applied = {}
    local notes = {}
    local problems = {}
    for i = 1, #SEGMENTS do
        local segment = SEGMENTS[i]
        local ids = links[segment.key]
        local id = ids and ids[1]
        if id then
            local ok, message = ApplySegment(segment.key, id)
            if ok then
                applied[#applied + 1] = segment.label
                if #ids > 1 then
                    notes[#notes + 1] = segment.label .. " used the first of " .. tostring(#ids)
                end
            else
                problems[#problems + 1] = segment.label .. ": " .. (message or "could not apply")
            end
        end
    end

    local text = ""
    if #applied > 0 then
        text = "Applied " .. table.concat(applied, ", ") .. "."
    end
    if #notes > 0 then
        text = text .. " " .. table.concat(notes, ". ") .. "."
    end
    if #problems > 0 then
        if text ~= "" then
            text = text .. " "
        end
        text = text .. table.concat(problems, " ")
        return false, text
    end
    return true, text
end
