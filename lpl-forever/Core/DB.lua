local _, LPL = ...

LPL.DB = LPL.DB or {}
local DB = LPL.DB

local SAVED = "LPLForeverDB"
local bound = false

local function TableOrNil(value)
    if type(value) == "table" then
        return value
    end
    return nil
end

local function HasMarker(db)
    return type(db) == "table" and type(db.phase1) == "table" and db.phase1.marker == "lpl-forever"
end

-- Forever injects SavedVariables into the addon environment. _G alone can miss it.
-- Never replace that table. Mutate it in place.
local function Resolve()
    local env = TableOrNil(LPLForeverDB)
    local global = TableOrNil(_G[SAVED])
    if env and global and env ~= global then
        if HasMarker(global) and not HasMarker(env) then
            return global
        end
        return env
    end
    return env or global
end

function DB:Bind(countLoad)
    local db = Resolve()
    if not db then
        db = {}
    end
    LPLForeverDB = db
    _G[SAVED] = db

    if type(db.phase1) ~= "table" then
        db.phase1 = {}
    end
    local phase = db.phase1
    phase.marker = "lpl-forever"
    if type(phase.loads) ~= "number" then
        phase.loads = 0
    end
    if countLoad and not bound then
        phase.loads = phase.loads + 1
        bound = true
    end
    self.data = db
    return db
end

function DB:Loads()
    local db = self.data or Resolve()
    if type(db) == "table" and type(db.phase1) == "table" and type(db.phase1.loads) == "number" then
        return db.phase1.loads
    end
    return 0
end
