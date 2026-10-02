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

function Places:Add(record)
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
    local scope = record.scope == "character" and "character" or "account"
    local list
    if scope == "character" then
        list = GPS.DB:CharacterStore()
        if not list then
            return nil, "character"
        end
    else
        local db = GPS.DB:Data()
        list = db and db.personalAccount
    end
    if type(list) ~= "table" then
        return nil, "store"
    end
    local saved = {
        id = tostring(time()) .. "-" .. tostring(math.random(1000, 9999)),
        name = name,
        note = GPS:PlainString(record.note) or "",
        mapId = mapId,
        x = x,
        y = y,
        zone = GPS:PlainString(record.zone) or "",
        tag = GPS:PlainString(record.tag),
    }
    list[#list + 1] = saved
    saved.scope = scope
    saved.custom = true
    return saved
end

function Places:Delete(id, scope)
    return GPS.DB:RemovePlace(id, scope)
end
