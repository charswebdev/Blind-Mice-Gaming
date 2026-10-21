local addonName, LPL = ...

LPL.DB = {}

local DEFAULTS = {
    ui = {
        lastTab = "talents",
        scale = 1.0,
        showLevelSlider = false,
        shown = false,
        minimap = {
            shown = true,
            angle = 195,
        },
        frame = {
            point = "CENTER",
            relativePoint = "CENTER",
            x = 0,
            y = 0,
            width = 980,
            height = 680,
            locked = false,
        },
    },
    talents = {
        builds = {},
        nextBuildId = 0,
        view = {
            classID = nil,
            specID = nil,
            subTreeID = nil,
            level = 60,
        },
    },
    actionBars = {
        sets = {},
        nextSetId = 0,
        lastAppliedSetID = nil,
    },
    keybinds = {
        sets = {},
        nextSetId = 0,
        lastAppliedSetID = nil,
        lastAppliedScope = nil,
        lastAppliedAt = nil,
    },
    equipment = {
        sets = {},
        nextSetId = 0,
    },
    pvpTalents = {
        sets = {},
        nextSetId = 0,
    },
    cooldownManager = {
        sets = {},
        nextSetId = 0,
    },
    editMode = {
        sets = {},
        nextSetId = 0,
        -- Do not default lastApplied to {}. An empty table is truthy and hid
        -- "nothing saved" vs "saved layout" during login restore.
    },
    loadouts = {
        sets = {},
        nextSetId = 0,
    },
    macros = {
        sets = {},
        nextSetId = 0,
    },
    addonSets = {
        sets = {},
        nextSetId = 0,
        protected = {},
    },
    addonProfiles = {
        sets = {},
        nextSetId = 0,
    },
    conditions = {
        enabled = true,
        limitConditions = false,
        noSpecSwitch = false,
        rules = {},
        nextRuleId = 0,
    },
    listFilters = {
        talents = {},
        actionbars = {},
        keybinds = {},
        equipment = {},
        pvptalents = {},
        cooldownmanager = {},
        editmode = {},
        loadouts = {},
        conditions = {},
        macros = {},
        addonsets = {},
        addonprofiles = {},
    },
    listCollapsed = {
        talents = {},
        actionbars = {},
        keybinds = {},
        equipment = {},
        pvptalents = {},
        cooldownmanager = {},
        editmode = {},
        loadouts = {},
        conditions = {},
        macros = {},
        addonsets = {},
        addonprofiles = {},
    },
    persist = {
        editMode = {},
        keybinds = {},
        actionBars = {},
    },
    profiles = {},
    activeProfile = "Default",
}

LPL.DB.PROFILE_FLAVOR = "era"

LPL.DB.PROFILE_KEYS = {
    "talents",
    "actionBars",
    "keybinds",
    "equipment",
    "pvpTalents",
    "cooldownManager",
    "editMode",
    "loadouts",
    "macros",
    "addonSets",
    "addonProfiles",
    "conditions",
}

LPL.DB.PROFILE_COUNT_FIELD = {
    talents = "builds",
    actionBars = "sets",
    keybinds = "sets",
    equipment = "sets",
    pvpTalents = "sets",
    cooldownManager = "sets",
    editMode = "sets",
    loadouts = "sets",
    macros = "sets",
    addonSets = "sets",
    addonProfiles = "sets",
    conditions = "rules",
}

local function DeepCopy(source)
    if type(source) ~= "table" then
        return source
    end
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = DeepCopy(value)
    end
    return copy
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = DeepCopy(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

function LPL.DB:Initialize()
    -- WoW injects ## SavedVariables into the addon environment as LPLClassicEraDB.
    -- Prefer that table so we never replace loaded WTF data with an empty _G stub.
    if type(LPLClassicEraDB) ~= "table" then
        if type(_G.LPLClassicEraDB) == "table" then
            LPLClassicEraDB = _G.LPLClassicEraDB
        else
            LPLClassicEraDB = {}
        end
    end
    _G.LPLClassicEraDB = LPLClassicEraDB
    MergeDefaults(LPLClassicEraDB, DEFAULTS)
    self.data = LPLClassicEraDB
    self.data.ui.shown = false
    self:EnsureProfiles()
    if LPL.BuildStore and LPL.BuildStore.MigrateStorage then
        LPL.BuildStore:MigrateStorage()
    end
    if LPL.ActionBarStore and LPL.ActionBarStore.MigrateStorage then
        LPL.ActionBarStore:MigrateStorage()
    end
    if LPL.EquipmentStore and LPL.EquipmentStore.MigrateStorage then
        LPL.EquipmentStore:MigrateStorage()
    end
    if LPL.EditModeStore and LPL.EditModeStore.MigrateStorage then
        LPL.EditModeStore:MigrateStorage()
    end
    if LPL.CooldownManagerStore and LPL.CooldownManagerStore.MigrateStorage then
        LPL.CooldownManagerStore:MigrateStorage()
    end
end

function LPL.DB:SyncFromGlobal()
    if type(LPLClassicEraDB) == "table" then
        self.data = LPLClassicEraDB
        _G.LPLClassicEraDB = LPLClassicEraDB
    elseif type(_G.LPLClassicEraDB) == "table" then
        LPLClassicEraDB = _G.LPLClassicEraDB
        self.data = LPLClassicEraDB
    end
    if self.data then
        self:EnsureProfiles()
    end
end

function LPL.DB:NormalizeProfileName(name)
    name = tostring(name or ""):gsub("[\r\n]", " ")
    name = name:match("^%s*(.-)%s*$") or ""
    if #name > 40 then
        name = name:sub(1, 40):match("^%s*(.-)%s*$") or ""
    end
    if name == "" then
        return nil
    end
    return name
end

function LPL.DB:BlankProfile()
    local profile = {}
    for _, key in ipairs(self.PROFILE_KEYS) do
        profile[key] = DeepCopy(DEFAULTS[key])
    end
    return profile
end

function LPL.DB:EnsureProfiles()
    if self._ensuringProfiles or not self.data then
        return
    end
    self._ensuringProfiles = true
    local data = self.data
    if type(data.profiles) ~= "table" then
        data.profiles = {}
    end
    if not data.profilesMigrated then
        local profile = {}
        for _, key in ipairs(self.PROFILE_KEYS) do
            if type(data[key]) == "table" then
                profile[key] = data[key]
            else
                profile[key] = DeepCopy(DEFAULTS[key])
            end
        end
        if type(data.profiles.Default) ~= "table" then
            data.profiles.Default = profile
        end
        data.activeProfile = "Default"
        data.profilesMigrated = true
    end
    local name = data.activeProfile
    if type(name) ~= "string" or name == "" or type(data.profiles[name]) ~= "table" then
        if type(data.profiles.Default) == "table" then
            name = "Default"
        else
            name = next(data.profiles)
        end
        if not name then
            name = "Default"
            data.profiles[name] = self:BlankProfile()
        end
        data.activeProfile = name
    end
    local profile = data.profiles[name]
    for _, key in ipairs(self.PROFILE_KEYS) do
        if type(profile[key]) ~= "table" then
            profile[key] = DeepCopy(DEFAULTS[key])
        else
            MergeDefaults(profile[key], DEFAULTS[key])
        end
        data[key] = profile[key]
    end
    self._ensuringProfiles = false
end

function LPL.DB:GetActiveProfileName()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    return self.data.activeProfile or "Default"
end

function LPL.DB:ListProfiles()
    self:GetActiveProfileName()
    local names = {}
    for profileName in pairs(self.data.profiles or {}) do
        names[#names + 1] = profileName
    end
    table.sort(names, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)
    return names
end

function LPL.DB:CountProfilePlaces(name)
    self:GetActiveProfileName()
    local profile = self.data.profiles[name]
    if type(profile) ~= "table" then
        return 0
    end
    local count = 0
    for _, key in ipairs(self.PROFILE_KEYS) do
        local section = profile[key]
        local field = self.PROFILE_COUNT_FIELD[key]
        local bucket = type(section) == "table" and section[field] or nil
        if type(bucket) == "table" then
            for _ in pairs(bucket) do
                count = count + 1
            end
        end
    end
    return count
end

function LPL.DB:LoadProfile(name)
    self:GetActiveProfileName()
    name = self:NormalizeProfileName(name) or name
    if type(self.data.profiles[name]) ~= "table" then
        return false, "missing"
    end
    self.data.activeProfile = name
    self:EnsureProfiles()
    return true, name
end

function LPL.DB:CreateProfile(name)
    self:GetActiveProfileName()
    name = self:NormalizeProfileName(name)
    if not name then
        return false, "bad_name"
    end
    if self.data.profiles[name] then
        return false, "exists"
    end
    self.data.profiles[name] = self:BlankProfile()
    self.data.activeProfile = name
    self:EnsureProfiles()
    return true, name
end

function LPL.DB:RenameProfile(oldName, newName)
    self:GetActiveProfileName()
    if type(self.data.profiles[oldName]) ~= "table" then
        return false, "missing"
    end
    newName = self:NormalizeProfileName(newName)
    if not newName then
        return false, "bad_name"
    end
    if newName == oldName then
        return true, newName
    end
    if self.data.profiles[newName] then
        return false, "exists"
    end
    self.data.profiles[newName] = self.data.profiles[oldName]
    self.data.profiles[oldName] = nil
    if self.data.activeProfile == oldName then
        self.data.activeProfile = newName
    end
    self:EnsureProfiles()
    return true, newName
end

function LPL.DB:DeleteProfile(name)
    self:GetActiveProfileName()
    if type(self.data.profiles[name]) ~= "table" then
        return false, "missing"
    end
    local count = 0
    for _ in pairs(self.data.profiles) do
        count = count + 1
    end
    if count <= 1 then
        return false, "last"
    end
    self.data.profiles[name] = nil
    if self.data.activeProfile == name then
        local fallback = self.data.profiles.Default and "Default" or next(self.data.profiles)
        self.data.activeProfile = fallback
    end
    self:EnsureProfiles()
    return true, self.data.activeProfile
end

function LPL.DB:CopyProfileSections(profile)
    local sections = {}
    if type(profile) ~= "table" then
        return sections
    end
    for _, key in ipairs(self.PROFILE_KEYS) do
        if type(profile[key]) == "table" then
            sections[key] = DeepCopy(profile[key])
        end
    end
    return sections
end

function LPL.DB:InstallProfile(name, sections)
    self:GetActiveProfileName()
    name = self:NormalizeProfileName(name)
    if not name then
        return false, "bad_name"
    end
    local profile = self:BlankProfile()
    if type(sections) == "table" then
        for _, key in ipairs(self.PROFILE_KEYS) do
            if type(sections[key]) == "table" then
                profile[key] = DeepCopy(sections[key])
                MergeDefaults(profile[key], DEFAULTS[key])
            end
        end
    end
    self.data.profiles[name] = profile
    self.data.activeProfile = name
    self:EnsureProfiles()
    return true, name
end

function LPL.DB:GetUI()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    local ui = self.data.ui
    if type(ui.minimap) ~= "table" then
        ui.minimap = DeepCopy(DEFAULTS.ui.minimap)
    else
        MergeDefaults(ui.minimap, DEFAULTS.ui.minimap)
    end
    if type(ui.frame) ~= "table" then
        ui.frame = DeepCopy(DEFAULTS.ui.frame)
    else
        MergeDefaults(ui.frame, DEFAULTS.ui.frame)
    end
    return ui
end

function LPL.DB:GetTalents()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.talents) ~= "table" then
        self.data.talents = DeepCopy(DEFAULTS.talents)
    else
        MergeDefaults(self.data.talents, DEFAULTS.talents)
    end
    return self.data.talents
end

function LPL.DB:GetActionBars()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.actionBars) ~= "table" then
        self.data.actionBars = DeepCopy(DEFAULTS.actionBars)
    else
        MergeDefaults(self.data.actionBars, DEFAULTS.actionBars)
    end
    return self.data.actionBars
end

function LPL.DB:GetKeybinds()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.keybinds) ~= "table" then
        self.data.keybinds = DeepCopy(DEFAULTS.keybinds)
    else
        MergeDefaults(self.data.keybinds, DEFAULTS.keybinds)
    end
    return self.data.keybinds
end

function LPL.DB:GetEquipment()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.equipment) ~= "table" then
        self.data.equipment = DeepCopy(DEFAULTS.equipment)
    else
        MergeDefaults(self.data.equipment, DEFAULTS.equipment)
    end
    return self.data.equipment
end

function LPL.DB:GetPvpTalents()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.pvpTalents) ~= "table" then
        self.data.pvpTalents = DeepCopy(DEFAULTS.pvpTalents)
    else
        MergeDefaults(self.data.pvpTalents, DEFAULTS.pvpTalents)
    end
    return self.data.pvpTalents
end

function LPL.DB:GetCooldownManager()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.cooldownManager) ~= "table" then
        self.data.cooldownManager = DeepCopy(DEFAULTS.cooldownManager)
    else
        MergeDefaults(self.data.cooldownManager, DEFAULTS.cooldownManager)
    end
    return self.data.cooldownManager
end

function LPL.DB:GetEditMode()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.editMode) ~= "table" then
        self.data.editMode = DeepCopy(DEFAULTS.editMode)
    else
        MergeDefaults(self.data.editMode, DEFAULTS.editMode)
    end
    return self.data.editMode
end

function LPL.DB:GetLoadouts()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.loadouts) ~= "table" then
        self.data.loadouts = DeepCopy(DEFAULTS.loadouts)
    else
        MergeDefaults(self.data.loadouts, DEFAULTS.loadouts)
    end
    return self.data.loadouts
end

function LPL.DB:GetConditions()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.conditions) ~= "table" then
        self.data.conditions = DeepCopy(DEFAULTS.conditions)
    else
        MergeDefaults(self.data.conditions, DEFAULTS.conditions)
    end
    return self.data.conditions
end

function LPL.DB:GetMacros()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.macros) ~= "table" then
        self.data.macros = DeepCopy(DEFAULTS.macros)
    else
        MergeDefaults(self.data.macros, DEFAULTS.macros)
    end
    return self.data.macros
end

function LPL.DB:GetAddonSets()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.addonSets) ~= "table" then
        self.data.addonSets = DeepCopy(DEFAULTS.addonSets)
    else
        MergeDefaults(self.data.addonSets, DEFAULTS.addonSets)
    end
    if type(self.data.addonSets.protected) ~= "table" then
        self.data.addonSets.protected = {}
    end
    return self.data.addonSets
end

function LPL.DB:GetAddonProfiles()
    self:SyncFromGlobal()
    if not self.data then
        self:Initialize()
    end
    if type(self.data.addonProfiles) ~= "table" then
        self.data.addonProfiles = DeepCopy(DEFAULTS.addonProfiles)
    else
        MergeDefaults(self.data.addonProfiles, DEFAULTS.addonProfiles)
    end
    return self.data.addonProfiles
end

function LPL.DB:GetTalentView()
    local talents = self:GetTalents()
    if type(talents.view) ~= "table" then
        talents.view = DeepCopy(DEFAULTS.talents.view)
    end
    return talents.view
end

function LPL.DB:IsFrameLocked()
    return self:GetUI().frame.locked == true
end

function LPL.DB:SetFrameLocked(locked)
    self:GetUI().frame.locked = locked == true
end

function LPL.DB:SaveFrameState(frame)
    local ui = self:GetUI()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    ui.frame.point = point or "CENTER"
    ui.frame.relativePoint = relativePoint or "CENTER"
    ui.frame.x = x or 0
    ui.frame.y = y or 0
    ui.frame.width = frame:GetWidth()
    ui.frame.height = frame:GetHeight()
end

function LPL.DB:RestoreFrameState(frame)
    local frameState = self:GetUI().frame
    if type(frameState) ~= "table" then
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetSize(900, 600)
        return
    end

    local needed = 760
    if LPL.Sidebar and LPL.Sidebar.RequiredFrameHeight then
        needed = LPL.Sidebar:RequiredFrameHeight()
    end
    local screenCap = needed
    if type(GetScreenHeight) == "function" then
        screenCap = math.max(560, GetScreenHeight() - 40)
    end
    local fitHeight = math.min(needed, screenCap)

    local width = tonumber(frameState.width) or 900
    local height = tonumber(frameState.height) or fitHeight
    local x = tonumber(frameState.x) or 0
    local y = tonumber(frameState.y) or 0
    local point = frameState.point or "CENTER"
    local relativePoint = frameState.relativePoint or "CENTER"

    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    frame:SetSize(math.max(720, width), math.max(fitHeight, math.min(height, screenCap)))
end
