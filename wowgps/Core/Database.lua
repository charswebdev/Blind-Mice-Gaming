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
        locationProfiles = {},
        activeLocationProfile = "Default",
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

function Database:NormalizeProfileName(name)
    name = tostring(name or ""):gsub("[\r\n:]", " ")
    name = name:match("^%s*(.-)%s*$") or ""
    if #name > 40 then
        name = name:sub(1, 40):match("^%s*(.-)%s*$") or ""
    end
    if name == "" then
        return nil
    end
    return name
end

function Database:EnsureLocationProfiles()
    local global = self.addon.db.global
    if type(global.locationProfiles) ~= "table" then
        global.locationProfiles = {}
    end

    if not global.locationProfilesMigrated then
        local account = global.personalAccount
        local characters = global.personalCharacter
        if type(account) ~= "table" then
            account = {}
        end
        if type(characters) ~= "table" then
            characters = {}
        end
        if not global.locationProfiles["Default"] then
            global.locationProfiles["Default"] = {
                account = account,
                characters = characters,
            }
        end
        global.locationProfilesMigrated = true
    end

    local name = global.activeLocationProfile
    if type(name) ~= "string" or name == "" or not global.locationProfiles[name] then
        if global.locationProfiles["Default"] then
            name = "Default"
        else
            name = next(global.locationProfiles)
        end
        if not name then
            name = "Default"
            global.locationProfiles[name] = { account = {}, characters = {} }
        end
        global.activeLocationProfile = name
    end

    local profile = global.locationProfiles[name]
    if type(profile.account) ~= "table" then
        profile.account = {}
    end
    if type(profile.characters) ~= "table" then
        profile.characters = {}
    end
    return name, profile
end

function Database:GetActiveLocationProfile()
    return self:EnsureLocationProfiles()
end

function Database:GetLocationProfile(name)
    local activeName, activeProfile = self:EnsureLocationProfiles()
    if name == nil or name == "" or name == activeName then
        return activeName, activeProfile
    end
    local profile = self.addon.db.global.locationProfiles[name]
    if type(profile) ~= "table" then
        return nil
    end
    if type(profile.account) ~= "table" then
        profile.account = {}
    end
    if type(profile.characters) ~= "table" then
        profile.characters = {}
    end
    return name, profile
end

function Database:CountLocationProfilePlaces(name)
    local _, profile = self:GetLocationProfile(name)
    if not profile then
        return 0
    end
    local count = 0
    for _ in pairs(profile.account) do
        count = count + 1
    end
    for _, store in pairs(profile.characters) do
        if type(store) == "table" then
            for _ in pairs(store) do
                count = count + 1
            end
        end
    end
    return count
end

function Database:RenameLocationProfile(oldName, newName)
    self:EnsureLocationProfiles()
    local profiles = self.addon.db.global.locationProfiles
    if not profiles[oldName] then
        return false, "missing"
    end
    newName = self:NormalizeProfileName(newName)
    if not newName then
        return false, "bad_name"
    end
    if newName == oldName then
        return true, newName
    end
    if profiles[newName] then
        return false, "exists"
    end
    profiles[newName] = profiles[oldName]
    profiles[oldName] = nil
    if self.addon.db.global.activeLocationProfile == oldName then
        self.addon.db.global.activeLocationProfile = newName
    end
    return true, newName
end

function Database:ListLocationProfiles()
    self:EnsureLocationProfiles()
    local names = {}
    for profileName in pairs(self.addon.db.global.locationProfiles) do
        names[#names + 1] = profileName
    end
    table.sort(names, function(a, b)
        return a:lower() < b:lower()
    end)
    return names
end

function Database:SetActiveLocationProfile(name)
    self:EnsureLocationProfiles()
    name = self:NormalizeProfileName(name) or name
    if not self.addon.db.global.locationProfiles[name] then
        return false, "missing"
    end
    self.addon.db.global.activeLocationProfile = name
    return true, name
end

function Database:CreateLocationProfile(name)
    self:EnsureLocationProfiles()
    name = self:NormalizeProfileName(name)
    if not name then
        return false, "bad_name"
    end
    local profiles = self.addon.db.global.locationProfiles
    if profiles[name] then
        return false, "exists"
    end
    profiles[name] = { account = {}, characters = {} }
    self.addon.db.global.activeLocationProfile = name
    return true, name
end

function Database:DeleteLocationProfile(name)
    self:EnsureLocationProfiles()
    local profiles = self.addon.db.global.locationProfiles
    if not profiles[name] then
        return false, "missing"
    end
    local count = 0
    for _ in pairs(profiles) do
        count = count + 1
    end
    if count <= 1 then
        return false, "last"
    end
    profiles[name] = nil
    if self.addon.db.global.activeLocationProfile == name then
        local fallback = profiles["Default"] and "Default" or next(profiles)
        self.addon.db.global.activeLocationProfile = fallback
    end
    return true, self.addon.db.global.activeLocationProfile
end

function Database:ReplaceLocationProfile(name, account, characters)
    self:EnsureLocationProfiles()
    name = self:NormalizeProfileName(name)
    if not name then
        return false, "bad_name"
    end
    local profiles = self.addon.db.global.locationProfiles
    local replaced = profiles[name] ~= nil
    profiles[name] = {
        account = type(account) == "table" and account or {},
        characters = type(characters) == "table" and characters or {},
    }
    self.addon.db.global.activeLocationProfile = name
    return true, name, replaced
end

function Database:GetPersonalStore(scope)
    local _, profile = self:EnsureLocationProfiles()
    if scope == "character" then
        local key = self:GetCharacterKey()
        profile.characters[key] = profile.characters[key] or {}
        return profile.characters[key]
    end
    return profile.account
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
    -- Previous default was 340x360; bump saved cramped windows to the new size.
    if width <= 340 and height <= 360 then
        width = c.WIDTH
        height = c.HEIGHT
    end
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
