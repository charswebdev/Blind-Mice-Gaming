local _, ns = ...

local Database = {}
ns.Database = Database

local defaults = {
    profile = {
        phaseMode = "auto",
        routeOnMapPinClick = "shift",
        worldMapRouteMode = false,
        chatPinRouteMode = false,
        defaultCustomScope = "account",
        window = {
            point = "CENTER",
            relPoint = "CENTER",
            x = 0,
            y = 0,
            width = ns.Constants.WINDOW.WIDTH,
            height = ns.Constants.WINDOW.HEIGHT,
        },
        frameOpen = false,
        activeTab = "search",
        activeRoute = nil,
    },
    global = {
        personalAccount = {},
        personalCharacter = {},
    },
}

function Database:Init(addon)
    self.addon = addon
    addon.db = LibStub("AceDB-3.0"):New("WowGPSDB", defaults, true)
end

function Database:GetProfile()
    return self.addon.db.profile
end

function Database:GetFrameOpen()
    return self:GetProfile().frameOpen == true
end

function Database:SetFrameOpen(open)
    self:GetProfile().frameOpen = open and true or false
end

function Database:GetActiveTab()
    return self:GetProfile().activeTab or "search"
end

function Database:SetActiveTab(tab)
    self:GetProfile().activeTab = tab or "search"
end

function Database:GetPersonalStore(scope)
    if scope == "character" then
        local key = self:GetCharacterKey()
        self.addon.db.global.personalCharacter[key] = self.addon.db.global.personalCharacter[key] or {}
        return self.addon.db.global.personalCharacter[key]
    end
    return self.addon.db.global.personalAccount
end

function Database:GetCharacterKey()
    local name = UnitName("player")
    local realm = GetRealmName()
    return realm .. "." .. name
end

function Database:SaveWindow(frame)
    local point, _, relPoint, x, y = frame:GetPoint(1)
    local profile = self:GetProfile()
    profile.window.point = point
    profile.window.relPoint = relPoint
    profile.window.x = x
    profile.window.y = y
    profile.window.width = frame:GetWidth()
    profile.window.height = frame:GetHeight()
end

function Database:RestoreWindow(frame)
    local c = ns.Constants.WINDOW
    local w = self:GetProfile().window
    local width = tonumber(w.width) or c.WIDTH
    local height = tonumber(w.height) or c.HEIGHT
    width = math.max(c.MIN_WIDTH, math.min(c.MAX_WIDTH, width))
    height = math.max(c.MIN_HEIGHT, math.min(c.MAX_HEIGHT, height))
    frame:SetSize(width, height)
    frame:ClearAllPoints()
    frame:SetPoint(w.point or "CENTER", UIParent, w.relPoint or "CENTER", w.x or 0, w.y or 0)
end

function Database:PersistAllState()
    if ns.MainFrame then
        ns.MainFrame:SyncFrameState()
    end
    if ns.RouteTracker then
        ns.RouteTracker:PersistSession()
    end
    if ns.MainFrame then
        ns.MainFrame:SaveSession()
    end
end
