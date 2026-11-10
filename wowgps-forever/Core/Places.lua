local _, GPS = ...

GPS.Places = GPS.Places or {}
local Places = GPS.Places

function Places:List()
    local out = {}
    GPS.DB:EachPlace(function(rec, scope)
        local name = GPS:PlainString(rec.name)
        local id = GPS:PlainString(rec.id)
        local mapId = GPS:PlainNumber(rec.mapId)
        local x = GPS:PlainNumber(rec.x)
        local y = GPS:PlainNumber(rec.y)
        if not name or not id or not mapId or not x or not y then
            return
        end
        out[#out + 1] = {
            id = id,
            name = name,
            note = GPS:PlainString(rec.note) or "",
            mapId = mapId,
            x = x,
            y = y,
            zone = GPS:PlainString(rec.zone) or "",
            tag = GPS:PlainString(rec.tag),
            scope = scope,
            custom = true,
        }
    end)
    return out
end

function Places:Store(scope)
    if scope == "character" then
        return GPS.DB:CharacterStore()
    end
    local db = GPS.DB:Data()
    return db and db.personalAccount
end

function Places:Normalize(record)
    local name = GPS:PlainString(record and record.name)
    local mapId = GPS:PlainNumber(record and record.mapId)
    local x = GPS:PlainNumber(record and record.x)
    local y = GPS:PlainNumber(record and record.y)
    if not name or not mapId or not x or not y then
        return nil, "invalid"
    end
    if x < 0 or x > 1 or y < 0 or y > 1 then
        return nil, "coords"
    end
    return {
        name = name,
        note = GPS:PlainString(record.note) or "",
        mapId = mapId,
        x = x,
        y = y,
        zone = GPS:PlainString(record.zone) or "",
        tag = GPS:PlainString(record.tag),
        scope = record.scope == "character" and "character" or "account",
    }
end

function Places:FindRaw(id, scope)
    local list = self:Store(scope == "character" and "character" or "account")
    if type(list) ~= "table" then
        return nil
    end
    local wanted = GPS:PlainString(id)
    if not wanted then
        return nil
    end
    for i = 1, #list do
        local rec = list[i]
        if type(rec) == "table" and GPS:PlainString(rec.id) == wanted then
            return rec, list, i
        end
    end
end

function Places:Add(record)
    local saved, err = self:Normalize(record)
    if not saved then
        return nil, err
    end
    local list = self:Store(saved.scope)
    if saved.scope == "character" and not list then
        return nil, "character"
    end
    if type(list) ~= "table" then
        return nil, "store"
    end
    saved.id = tostring(time()) .. "-" .. tostring(math.random(1000, 9999))
    saved.custom = true
    list[#list + 1] = saved
    return saved
end

function Places:Update(id, originalScope, record)
    local saved, err = self:Normalize(record)
    if not saved then
        return nil, err
    end
    local fromScope = originalScope == "character" and "character" or "account"
    local rec, list = self:FindRaw(id, fromScope)
    if not rec or type(list) ~= "table" then
        return nil, "missing"
    end
    local dest
    if saved.scope ~= fromScope then
        dest = self:Store(saved.scope)
        if saved.scope == "character" and not dest then
            return nil, "character"
        end
        if type(dest) ~= "table" then
            return nil, "store"
        end
    end
    rec.name = saved.name
    rec.note = saved.note
    rec.mapId = saved.mapId
    rec.x = saved.x
    rec.y = saved.y
    rec.zone = saved.zone
    rec.tag = saved.tag
    rec.scope = saved.scope
    rec.custom = true
    if dest then
        for i = #list, 1, -1 do
            if list[i] == rec then
                table.remove(list, i)
                break
            end
        end
        dest[#dest + 1] = rec
    end
    return rec
end

function Places:Delete(id, scope)
    return GPS.DB:RemovePlace(id, scope)
end
