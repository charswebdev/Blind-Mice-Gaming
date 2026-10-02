local _, GPS = ...

GPS.DB = GPS.DB or {}
local DB = GPS.DB

local bound = false

local function TableOrNil(value)
    if type(value) == "table" then
        return value
    end
    return nil
end

local function HasMarker(db)
    return type(db) == "table" and db.marker == "wowgps-forever"
end

-- Forever injects SavedVariables into the addon environment. Never replace that table.
local function Resolve()
    local env = TableOrNil(WowGPSForeverDB)
    local global = TableOrNil(_G[GPS.SAVED])
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
    WowGPSForeverDB = db
    _G[GPS.SAVED] = db

    db.marker = "wowgps-forever"
    if type(db.loads) ~= "number" or (issecretvalue and issecretvalue(db.loads)) then
        db.loads = 0
    end
    if type(db.window) ~= "table" then
        db.window = {}
    end
    if type(db.activeTab) ~= "string" or (issecretvalue and issecretvalue(db.activeTab)) then
        db.activeTab = "search"
    end
    if type(db.personalAccount) ~= "table" then
        db.personalAccount = {}
    end
    if type(db.personalCharacter) ~= "table" then
        db.personalCharacter = {}
    end
    if countLoad and not bound then
        db.loads = db.loads + 1
        bound = true
    end
    self.data = db
    return db
end

function DB:Data()
    return self.data or Resolve()
end

function DB:GetActiveTab()
    local db = self:Data()
    local tab = db and GPS:PlainString(db.activeTab)
    if tab == "search" or tab == "route" or tab == "saved" or tab == "add" then
        return tab
    end
    return "search"
end

function DB:SetActiveTab(tab)
    local db = self:Data()
    if not db then
        return
    end
    if tab ~= "search" and tab ~= "route" and tab ~= "saved" and tab ~= "add" then
        tab = "search"
    end
    db.activeTab = tab
end

function DB:SaveWindow(frame)
    local db = self:Data()
    if not db or not frame then
        return
    end
    local point, _, relPoint, x, y = frame:GetPoint(1)
    point = GPS:PlainString(point)
    relPoint = GPS:PlainString(relPoint)
    x = GPS:PlainNumber(x)
    y = GPS:PlainNumber(y)
    local width = GPS:PlainNumber(frame:GetWidth())
    local height = GPS:PlainNumber(frame:GetHeight())
    if not point or not relPoint or not x or not y or not width or not height then
        return
    end
    local window = db.window
    if type(window) ~= "table" then
        window = {}
        db.window = window
    end
    window.point = point
    window.relPoint = relPoint
    window.x = x
    window.y = y
    window.width = width
    window.height = height
end

function DB:CharacterKey()
    local name = GPS:PlainString(UnitName("player"))
    local realm = GPS:PlainString(GetRealmName())
    if not name or not realm then
        return nil
    end
    return realm .. "-" .. name
end

function DB:CharacterStore()
    local db = self:Data()
    if not db or type(db.personalCharacter) ~= "table" then
        return nil
    end
    local key = self:CharacterKey()
    if not key then
        return nil
    end
    if type(db.personalCharacter[key]) ~= "table" then
        db.personalCharacter[key] = {}
    end
    return db.personalCharacter[key]
end

function DB:EachPlace(visitor)
    local db = self:Data()
    if not db then
        return
    end
    local account = db.personalAccount
    if type(account) == "table" then
        for i = 1, #account do
            if type(account[i]) == "table" then
                visitor(account[i], "account")
            end
        end
    end
    local mine = self:CharacterStore()
    if type(mine) == "table" then
        for i = 1, #mine do
            if type(mine[i]) == "table" then
                visitor(mine[i], "character")
            end
        end
    end
end

function DB:RemovePlace(id, scope)
    local db = self:Data()
    if not db or not id then
        return false
    end
    local list
    if scope == "character" then
        list = self:CharacterStore()
    else
        list = db.personalAccount
    end
    if type(list) ~= "table" then
        return false
    end
    for i = #list, 1, -1 do
        local rec = list[i]
        if type(rec) == "table" and GPS:PlainString(rec.id) == id then
            table.remove(list, i)
            return true
        end
    end
    return false
end

function DB:RestoreWindow(frame)
    local db = self:Data()
    local c = GPS.WINDOW
    local window = db and db.window
    local width = c.WIDTH
    local height = c.HEIGHT
    local point, relPoint, x, y = "CENTER", "CENTER", 0, 0
    if type(window) == "table" then
        width = GPS:PlainNumber(window.width) or width
        height = GPS:PlainNumber(window.height) or height
        point = GPS:PlainString(window.point) or point
        relPoint = GPS:PlainString(window.relPoint) or relPoint
        x = GPS:PlainNumber(window.x) or x
        y = GPS:PlainNumber(window.y) or y
    end
    if width < c.MIN_WIDTH then
        width = c.WIDTH
    end
    if height < c.MIN_HEIGHT then
        height = c.HEIGHT
    end
    frame:SetSize(width, height)
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relPoint, x, y)
end
