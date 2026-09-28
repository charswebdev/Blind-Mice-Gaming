local _, LPL = ...

LPL.SetStore = LPL.SetStore or {}
local Store = LPL.SetStore

local function Bucket(key)
    local db = LPL.DB:Bind(false)
    local bucket = db[key]
    if type(bucket) ~= "table" then
        bucket = {}
        db[key] = bucket
    end
    if type(bucket.sets) ~= "table" then
        bucket.sets = {}
    end
    if type(bucket.nextId) ~= "number" or bucket.nextId < 1 then
        bucket.nextId = 1
    end
    return bucket
end

local function CleanName(name, fallback)
    local plain = LPL:PlainString(name)
    if not plain then
        return fallback
    end
    plain = plain:match("^%s*(.-)%s*$") or ""
    if plain == "" then
        return fallback
    end
    if #plain > 80 then
        plain = plain:sub(1, 80)
    end
    return plain
end

function Store:List(key)
    return Bucket(key).sets
end

function Store:Get(key, id)
    id = tonumber(id)
    if not id then
        return nil
    end
    local sets = self:List(key)
    for i = 1, #sets do
        if tonumber(sets[i].id) == id then
            return sets[i]
        end
    end
    return nil
end

function Store:SuggestName(key, prefix)
    prefix = prefix or "Set"
    local sets = self:List(key)
    local function taken(candidate)
        for i = 1, #sets do
            if sets[i].name == candidate then
                return true
            end
        end
        return false
    end
    if not taken(prefix) then
        return prefix
    end
    for n = 2, 99 do
        local candidate = prefix .. " " .. n
        if not taken(candidate) then
            return candidate
        end
    end
    return prefix
end

function Store:Save(key, record, name, fallback)
    if type(record) ~= "table" then
        return nil
    end
    local bucket = Bucket(key)
    record.name = CleanName(name or record.name, fallback or Store:SuggestName(key, "Set"))
    record.id = bucket.nextId
    bucket.nextId = bucket.nextId + 1
    bucket.sets[#bucket.sets + 1] = record
    return record
end

function Store:Update(key, id, record, name, fallback)
    local existing = self:Get(key, id)
    if not existing or type(record) ~= "table" then
        return self:Save(key, record, name, fallback)
    end
    existing.name = CleanName(name or record.name, existing.name or fallback or "Set")
    existing.slots = record.slots
    existing.bindings = record.bindings
    existing.scope = record.scope
    existing.petSlots = record.petSlots
    existing.ignored = record.ignored
    return existing
end

function Store:Delete(key, id)
    id = tonumber(id)
    if not id then
        return false
    end
    local sets = self:List(key)
    for i = 1, #sets do
        if tonumber(sets[i].id) == id then
            table.remove(sets, i)
            return true
        end
    end
    return false
end
