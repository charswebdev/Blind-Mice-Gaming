--[[
  Cooldown Assist — tracking profiles (account-wide)
  Stores which cooldowns are disabled/enabled.
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Profiles = CA.Profiles or {}
local Profiles = CA.Profiles

local function SV()
    local db = CA.DB and CA.DB.Get and CA.DB.Get() or nil
    if not db then
        return nil
    end
    if type(db.profiles) ~= "table" then
        db.profiles = {}
    end
    if type(db.nextProfileId) ~= "number" then
        db.nextProfileId = 1
    end
    return db
end

local function CopyDisabled(src)
    local t = {}
    if type(src) ~= "table" then
        return t
    end
    for k, v in pairs(src) do
        if v == true and type(k) == "string" then
            t[k] = true
        end
    end
    return t
end

local function CountDisabled(map)
    local n = 0
    if type(map) ~= "table" then
        return 0
    end
    for _, v in pairs(map) do
        if v == true then
            n = n + 1
        end
    end
    return n
end

local function UniqueName(base)
    base = type(base) == "string" and base:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if base == "" then
        base = "Profile"
    end
    local db = SV()
    if not db then
        return base
    end
    local names = {}
    for _, p in pairs(db.profiles) do
        if type(p) == "table" and type(p.name) == "string" then
            names[p.name:lower()] = true
        end
    end
    if not names[base:lower()] then
        return base
    end
    local i = 2
    while names[(base .. " " .. i):lower()] do
        i = i + 1
    end
    return base .. " " .. i
end

function Profiles.List()
    local db = SV()
    local list = {}
    if not db then
        return list
    end
    for id, p in pairs(db.profiles) do
        if type(p) == "table" then
            list[#list + 1] = {
                id = id,
                name = p.name or ("Profile " .. tostring(id)),
                disabledCount = CountDisabled(p.disabledTrackers),
                isActive = db.activeProfileId == id,
            }
        end
    end
    table.sort(list, function(a, b)
        return tostring(a.name):lower() < tostring(b.name):lower()
    end)
    return list
end

function Profiles.Get(id)
    local db = SV()
    if not db or id == nil then
        return nil
    end
    local p = db.profiles[id]
    if type(p) ~= "table" then
        return nil
    end
    return p
end

function Profiles.GetActiveId()
    local db = SV()
    return db and db.activeProfileId or nil
end

function Profiles.Create(name, fromCurrent)
    local db = SV()
    if not db then
        return nil, "nodb"
    end
    local id = db.nextProfileId or 1
    db.nextProfileId = id + 1
    local profileName = UniqueName(name or "New Profile")
    local disabled
    if fromCurrent then
        disabled = CopyDisabled(db.disabledTrackers)
    else
        disabled = {}
    end
    db.profiles[id] = {
        name = profileName,
        disabledTrackers = disabled,
    }
    db.activeProfileId = id
    return id, profileName
end

function Profiles.SaveCurrent(id)
    local db = SV()
    if not db then
        return false, "nodb"
    end
    id = id or db.activeProfileId
    local p = id and db.profiles[id]
    if type(p) ~= "table" then
        return false, "missing"
    end
    p.disabledTrackers = CopyDisabled(db.disabledTrackers)
    db.activeProfileId = id
    return true, p.name
end

function Profiles.Load(id)
    local db = SV()
    if not db then
        return false, "nodb"
    end
    local p = db.profiles[id]
    if type(p) ~= "table" then
        return false, "missing"
    end
    db.disabledTrackers = CopyDisabled(p.disabledTrackers)
    db.activeProfileId = id
    if CA.Settings and CA.Settings.RefreshTrackers then
        CA.Settings.RefreshTrackers()
    end
    return true, p.name
end

function Profiles.Rename(id, newName)
    local db = SV()
    if not db then
        return false, "nodb"
    end
    local p = db.profiles[id]
    if type(p) ~= "table" then
        return false, "missing"
    end
    newName = type(newName) == "string" and newName:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if newName == "" then
        return false, "empty"
    end
    -- Allow keeping same name; otherwise ensure unique among others.
    local lower = newName:lower()
    for otherId, other in pairs(db.profiles) do
        if otherId ~= id and type(other) == "table" and type(other.name) == "string" and other.name:lower() == lower then
            newName = UniqueName(newName)
            break
        end
    end
    p.name = newName
    return true, p.name
end

function Profiles.Copy(id, newName)
    local db = SV()
    if not db then
        return nil, "nodb"
    end
    local src = db.profiles[id]
    if type(src) ~= "table" then
        return nil, "missing"
    end
    local newId = db.nextProfileId or 1
    db.nextProfileId = newId + 1
    local copyName = UniqueName(newName or ((src.name or "Profile") .. " Copy"))
    db.profiles[newId] = {
        name = copyName,
        disabledTrackers = CopyDisabled(src.disabledTrackers),
    }
    return newId, copyName
end

function Profiles.Delete(id)
    local db = SV()
    if not db then
        return false, "nodb"
    end
    if type(db.profiles[id]) ~= "table" then
        return false, "missing"
    end
    local name = db.profiles[id].name
    db.profiles[id] = nil
    if db.activeProfileId == id then
        db.activeProfileId = nil
        -- Prefer another profile if any remain.
        for otherId in pairs(db.profiles) do
            db.activeProfileId = otherId
            break
        end
    end
    return true, name
end
