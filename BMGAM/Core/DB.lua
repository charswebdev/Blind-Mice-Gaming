local _, BMGAM = ...

BMGAM.DB = BMGAM.DB or {}
local DB = BMGAM.DB

local MIN_SCALE = 860 / 1120
local MAX_SCALE = 1.25

function DB.Init()
    if type(bmgam_SavedVariables) ~= "table" then
        bmgam_SavedVariables = {}
    end
    local saved = bmgam_SavedVariables
    if type(saved.account) ~= "table" then
        saved.account = {}
    end
    local account = saved.account
    if account.minimap == nil then
        account.minimap = true
    end
    if type(account.scale) ~= "number" then
        account.scale = 1
    end
    if account.scale < MIN_SCALE then
        account.scale = MIN_SCALE
    end
    if account.scale > MAX_SCALE then
        account.scale = MAX_SCALE
    end
    if type(account.minimapAngle) ~= "number" then
        account.minimapAngle = 220
    end
    if account.sortBy ~= "class" and account.sortBy ~= "faction" and account.sortBy ~= "itemLevel" and account.sortBy ~= "gold" and account.sortBy ~= "level" and account.sortBy ~= "race" and account.sortBy ~= "realm" then
        account.sortBy = "class"
    end
    if account.sortOrder ~= "ascending" and account.sortOrder ~= "descending" then
        account.sortOrder = "ascending"
    end
    if type(saved.characters) ~= "table" then
        saved.characters = {}
    end
    if BMGAM.Store and BMGAM.Store.Migrate then
        BMGAM.Store.Migrate()
    end
end

function DB.Account()
    DB.Init()
    return bmgam_SavedVariables.account
end

function DB.Get(guid)
    if not guid then
        return nil
    end
    DB.Init()
    return bmgam_SavedVariables.characters[guid]
end

function DB.Ensure(guid)
    DB.Init()
    local characters = bmgam_SavedVariables.characters
    local record = characters[guid]
    if not record then
        record = { guid = guid }
        characters[guid] = record
    end
    return record
end

function DB.Delete(guid)
    if not guid then
        return
    end
    DB.Init()
    bmgam_SavedVariables.characters[guid] = nil
    if BMGAM.Store and BMGAM.Store.Forget then
        BMGAM.Store.Forget(guid)
    end
end

function DB.List()
    DB.Init()
    local list = {}
    for guid, record in pairs(bmgam_SavedVariables.characters) do
        if type(record) == "table" then
            record.guid = record.guid or guid
            list[#list + 1] = record
        end
    end
    local account = bmgam_SavedVariables.account
    local sortBy = account.sortBy
    local descending = account.sortOrder == "descending"
    local function TextKey(record, field)
        local value = record[field]
        if type(value) ~= "string" then
            return ""
        end
        return string.lower(value)
    end
    local function NumberKey(record, field)
        return tonumber(record[field]) or 0
    end
    local function Primary(record)
        if sortBy == "itemLevel" then
            return NumberKey(record, "itemLevel")
        end
        if sortBy == "gold" then
            return NumberKey(record, "moneyCopper")
        end
        if sortBy == "level" then
            return NumberKey(record, "level")
        end
        if sortBy == "faction" then
            return TextKey(record, "side")
        end
        if sortBy == "race" then
            return TextKey(record, "raceName")
        end
        if sortBy == "realm" then
            return TextKey(record, "realm")
        end
        return TextKey(record, "className")
    end
    table.sort(list, function(a, b)
        local aKey = Primary(a)
        local bKey = Primary(b)
        if aKey ~= bKey then
            if descending then
                return aKey > bKey
            end
            return aKey < bKey
        end
        local aName = TextKey(a, "name")
        local bName = TextKey(b, "name")
        if aName ~= bName then
            return aName < bName
        end
        return TextKey(a, "realm") < TextKey(b, "realm")
    end)
    return list
end

function DB.ClampScale(scale)
    scale = tonumber(scale) or 1
    if scale < MIN_SCALE then
        return MIN_SCALE
    end
    if scale > MAX_SCALE then
        return MAX_SCALE
    end
    return scale
end

function DB.SavePoint(frame)
    if not frame then
        return
    end
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    if not point then
        return
    end
    local account = DB.Account()
    account.point = point
    account.relativePoint = relativePoint or point
    account.x = x or 0
    account.y = y or 0
    account.scale = DB.ClampScale(frame:GetScale())
end

function DB.RestorePoint(frame)
    local account = DB.Account()
    frame:ClearAllPoints()
    frame:SetScale(DB.ClampScale(account.scale))
    if account.point then
        frame:SetPoint(account.point, UIParent, account.relativePoint or account.point, account.x or 0, account.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end
