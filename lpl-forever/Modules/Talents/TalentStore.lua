local _, LPL = ...

LPL.TalentStore = LPL.TalentStore or {}
local Store = LPL.TalentStore

local function Root()
    local db = LPL.DB:Bind(false)
    if type(db.talents) ~= "table" then
        db.talents = { nextId = 1, builds = {} }
    end
    if type(db.talents.builds) ~= "table" then
        db.talents.builds = {}
    end
    if type(db.talents.nextId) ~= "number" or db.talents.nextId < 1 then
        db.talents.nextId = 1
    end
    return db.talents
end

function Store:List()
    return Root().builds
end

function Store:Get(id)
    id = tonumber(id)
    if not id then
        return nil
    end
    local builds = self:List()
    for i = 1, #builds do
        if tonumber(builds[i].id) == id then
            return builds[i]
        end
    end
    return nil
end

function Store:Save(build, name)
    if type(build) ~= "table" then
        return nil, "Nothing to save."
    end
    local talents = Root()
    local cleanName = name
    if type(cleanName) ~= "string" or cleanName == "" then
        cleanName = "Build " .. tostring(talents.nextId)
    end
    if issecretvalue and issecretvalue(cleanName) then
        cleanName = "Build " .. tostring(talents.nextId)
    end
    build.name = cleanName
    build.id = talents.nextId
    talents.nextId = talents.nextId + 1
    talents.builds[#talents.builds + 1] = build
    return build
end

function Store:Update(id, build, name)
    local existing = self:Get(id)
    if not existing or type(build) ~= "table" then
        return self:Save(build, name)
    end
    if type(name) == "string" and name ~= "" and not (issecretvalue and issecretvalue(name)) then
        existing.name = name
    end
    existing.tabs = build.tabs
    existing.totalPoints = build.totalPoints
    existing.classFile = build.classFile
    existing.classID = build.classID
    return existing
end

function Store:Delete(id)
    id = tonumber(id)
    if not id then
        return false
    end
    local builds = self:List()
    for i = 1, #builds do
        if tonumber(builds[i].id) == id then
            table.remove(builds, i)
            return true
        end
    end
    return false
end
