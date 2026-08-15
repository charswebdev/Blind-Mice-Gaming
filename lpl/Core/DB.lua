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
            level = 90,
        },
    },
    actionBars = {
        sets = {},
        nextSetId = 0,
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
    if _G.LPLDB == nil then
        _G.LPLDB = {}
    end
    LPLDB = _G.LPLDB
    MergeDefaults(LPLDB, DEFAULTS)
    self.data = LPLDB
    self.data.ui.shown = false
    if LPL.BuildStore and LPL.BuildStore.MigrateStorage then
        LPL.BuildStore:MigrateStorage()
    end
    if LPL.ActionBarStore and LPL.ActionBarStore.MigrateStorage then
        LPL.ActionBarStore:MigrateStorage()
    end
    if LPL.EquipmentStore and LPL.EquipmentStore.MigrateStorage then
        LPL.EquipmentStore:MigrateStorage()
    end
    if LPL.CooldownManagerStore and LPL.CooldownManagerStore.MigrateStorage then
        LPL.CooldownManagerStore:MigrateStorage()
    end
end

function LPL.DB:SyncFromGlobal()
    if _G.LPLDB then
        self.data = _G.LPLDB
    end
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

    local width = tonumber(frameState.width) or 900
    local height = tonumber(frameState.height) or 600
    local x = tonumber(frameState.x) or 0
    local y = tonumber(frameState.y) or 0
    local point = frameState.point or "CENTER"
    local relativePoint = frameState.relativePoint or "CENTER"

    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, relativePoint, x, y)
    frame:SetSize(math.max(720, width), math.max(480, height))
end
