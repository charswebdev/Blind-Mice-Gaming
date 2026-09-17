--[[
  BMG Unit Frames — profiles and automatic save
  Lua 5.1 only.

  WoW writes BMGUnitFramesDB on logout and /reload.
  Every change mutates the active profile in memory; no extra Save click is required.
  Named profiles and export codes are optional backups / sharing.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.DB = UF.DB or {}
local DB = UF.DB

local function CopyTable(src)
    if type(src) ~= "table" then
        return src
    end
    local out = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            out[k] = CopyTable(v)
        else
            out[k] = v
        end
    end
    return out
end

local function Merge(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then
        return dst
    end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            Merge(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

local function AuraBlock(enabled, size, maxn, anchor)
    return {
        enabled = enabled and true or false,
        size = size or 18,
        max = maxn or 8,
        perRow = maxn or 8,
        growth = "RIGHT",
        anchor = anchor or "BOTTOMLEFT",
        filter = "all",
        timers = true,
        stacks = true,
    }
end

function DB.DefaultUnitExtras(id)
    local showBuffs = (id == "player" or id == "target" or id == "focus" or id == "arena")
    local showDebuffs = (id ~= "tot" and id ~= "pet")
    local icon = (id == "raid") and 14 or 18
    local count = (id == "raid") and 3 or ((id == "party") and 4 or 8)
    return {
        healthText = "both",
        powerText = "both",
        showPower = true,
        showAltPower = true,
        auras = {
            buffs = AuraBlock(showBuffs, icon, count, "BOTTOMLEFT"),
            debuffs = AuraBlock(showDebuffs, icon, count, "TOPRIGHT"),
        },
        indicators = {
            combat = true,
            resting = id == "player",
            leader = true,
            raidTarget = true,
            pvp = id ~= "raid",
            role = true,
            resurrect = true,
            ready = true,
            elite = (id == "target" or id == "focus" or id == "tot"),
            happiness = id == "pet",
            phase = true,
            oor = true,
            quest = (id == "target" or id == "focus" or id == "tot" or id == "party" or id == "raid"),
        },
        indPos = {
            combat = "TOPLEFT",
            resting = "TOPLEFT",
            leader = "TOPLEFT",
            raidTarget = "CENTER",
            pvp = "TOPRIGHT",
            role = "BOTTOMLEFT",
            resurrect = "CENTER",
            ready = "RIGHT",
            elite = "TOPRIGHT",
            happiness = "BOTTOMRIGHT",
            phase = "LEFT",
            oor = "BOTTOM",
            quest = "TOP",
        },
        textPos = {
            name = "TOPLEFT",
            health = "CENTER",
            power = "CENTER",
        },
        extra = {
            healPredict = true,
            absorb = true,
            healAbsorb = true,
            mouseover = true,
            aggro = true,
            castBar = (id == "player" or id == "target" or id == "focus"),
            rangeFade = (id == "party" or id == "raid" or id == "arena"),
            cast = {
                attach = "BELOW",
                w = 0,
                h = 12,
                point = "CENTER",
                x = 0,
                y = 0,
            },
        },
    }
end

function DB.DefaultFrame(id, base)
    local frame = base or {}
    Merge(frame, DB.DefaultUnitExtras(id))
    return frame
end

function DB.DefaultProfile()
    return {
        style = "modern",
        classColors = "classic",
        portrait = "portrait",
        showPower = true,
        showAltPower = true,
        healthText = "both",
        powerText = "both",
        showPlayerInParty = true,
        layoutVersion = 1,
        locked = true,
        speech = {
            enabled = true,
            healthLow = true,
            targetChange = false,
        },
        window = {
            point = "CENTER",
            x = 0,
            y = 0,
        },
        frames = {
            player = DB.DefaultFrame("player", { enabled = true, point = "BOTTOMLEFT", x = 20, y = 20, scale = 1, w = 200, h = 60 }),
            pet = DB.DefaultFrame("pet", { enabled = true, point = "BOTTOMLEFT", x = 20, y = 0, scale = 1, w = 160, h = 48 }),
            target = DB.DefaultFrame("target", { enabled = true, point = "BOTTOMRIGHT", x = -20, y = 20, scale = 1, w = 200, h = 60 }),
            tot = DB.DefaultFrame("tot", { enabled = true, point = "BOTTOMRIGHT", x = -20, y = 0, scale = 1, w = 160, h = 48 }),
            focus = DB.DefaultFrame("focus", { enabled = true, point = "TOPLEFT", x = 20, y = -80, scale = 1, w = 200, h = 60 }),
            party = DB.DefaultFrame("party", { enabled = true, point = "LEFT", x = 20, y = 80, scale = 1, w = 200, h = 60, growth = "DOWN" }),
            raid = DB.DefaultFrame("raid", { enabled = true, point = "LEFT", x = 20, y = 200, scale = 1, w = 90, h = 36, growth = "DOWN" }),
            arena = DB.DefaultFrame("arena", { enabled = true, point = "RIGHT", x = -20, y = 80, scale = 1, w = 200, h = 60, growth = "DOWN" }),
        },
    }
end

function DB.Exportable(profile)
    profile = profile or DB.Get()
    return {
        v = 1,
        addon = "BMG-Unit-frames",
        name = DB.CurrentName(),
        style = profile.style,
        classColors = profile.classColors,
        portrait = profile.portrait,
        showPower = profile.showPower ~= false,
        showAltPower = profile.showAltPower ~= false,
        healthText = profile.healthText,
        powerText = profile.powerText,
        showPlayerInParty = profile.showPlayerInParty == true,
        locked = profile.locked == true,
        speech = CopyTable(profile.speech or {}),
        frames = CopyTable(profile.frames or {}),
    }
end

function DB.Root()
    if type(BMGUnitFramesDB) ~= "table" then
        BMGUnitFramesDB = {}
    end
    return BMGUnitFramesDB
end

function DB.Init()
    local root = DB.Root()
    if type(root.version) ~= "number" then
        root.version = 1
    end
    if type(root.profiles) ~= "table" then
        root.profiles = {}
    end
    if type(root.profileKeys) ~= "table" then
        root.profileKeys = {}
    end
    if type(root.profiles.Default) ~= "table" then
        root.profiles.Default = DB.DefaultProfile()
    else
        Merge(root.profiles.Default, DB.DefaultProfile())
    end
    local key = UF.Compat and UF.Compat.CharacterKey and UF.Compat.CharacterKey() or "Unknown - Realm"
    if type(root.profileKeys[key]) ~= "string" or not root.profiles[root.profileKeys[key]] then
        root.profileKeys[key] = "Default"
    end
    for name, profile in pairs(root.profiles) do
        if type(profile) == "table" then
            Merge(profile, DB.DefaultProfile())
            if (profile.layoutVersion or 1) < 3 then
                profile.showPlayerInParty = true
                profile.layoutVersion = 3
            end
            if (profile.layoutVersion or 1) < 4 then
                profile.healthText = "both"
                profile.powerText = "both"
                profile.showPower = true
                profile.showAltPower = true
                local taller = {
                    player = { 52, 60 },
                    target = { 52, 60 },
                    focus = { 52, 60 },
                    party = { 52, 60 },
                    arena = { 52, 60 },
                    pet = { 40, 48 },
                    tot = { 40, 48 },
                    raid = { 28, 36 },
                }
                for id, pair in pairs(taller) do
                    local cfg = profile.frames and profile.frames[id]
                    if type(cfg) == "table" and cfg.h == pair[1] then
                        cfg.h = pair[2]
                    end
                end
                profile.layoutVersion = 4
            end
        end
    end
    return DB.Get()
end

function DB.CurrentName()
    local root = DB.Root()
    local key = UF.Compat and UF.Compat.CharacterKey and UF.Compat.CharacterKey() or "Unknown - Realm"
    local name = root.profileKeys and root.profileKeys[key]
    if type(name) == "string" and root.profiles and root.profiles[name] then
        return name
    end
    return "Default"
end

function DB.Get()
    local root = DB.Root()
    local name = DB.CurrentName()
    if type(root.profiles) ~= "table" then
        root.profiles = {}
    end
    if type(root.profiles[name]) ~= "table" then
        root.profiles[name] = DB.DefaultProfile()
    end
    return root.profiles[name]
end

function DB.ListProfiles()
    local names = {}
    local root = DB.Root()
    if type(root.profiles) ~= "table" then
        return names
    end
    for name in pairs(root.profiles) do
        if type(name) == "string" then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    return names
end

function DB.ApplySnap(points)
    if type(points) ~= "table" then
        return false
    end
    local profile = DB.Get()
    for id, pos in pairs(points) do
        if type(pos) == "table" and type(profile.frames[id]) == "table" then
            profile.frames[id].point = pos.point or "BOTTOMLEFT"
            profile.frames[id].x = pos.x or 0
            profile.frames[id].y = pos.y or 0
        end
    end
    if points.party and profile.frames.party then
        profile.frames.party.point = points.party.point
        profile.frames.party.x = points.party.x
        profile.frames.party.y = points.party.y
    end
    return true
end

function DB.CaptureAndMaybeSnap(force)
    local points = UF.Compat and UF.Compat.CaptureBlizzard and UF.Compat.CaptureBlizzard() or {}
    local profile = DB.Get()
    if force or (profile.layoutVersion or 1) < 2 then
        DB.ApplySnap(points)
        if (profile.layoutVersion or 1) < 2 then
            profile.layoutVersion = 2
        end
        return true
    end
    return false
end

function DB.Switch(name)
    if type(name) ~= "string" or name == "" then
        return false, "Name missing."
    end
    local root = DB.Root()
    if type(root.profiles[name]) ~= "table" then
        return false, "No profile named " .. name .. "."
    end
    local key = UF.Compat and UF.Compat.CharacterKey and UF.Compat.CharacterKey() or "Unknown - Realm"
    root.profileKeys[key] = name
    if UF.ApplyProfile then
        UF.ApplyProfile(root.profiles[name])
    end
    return true, "Loaded profile " .. name .. "."
end

function DB.SaveAs(name)
    if type(name) ~= "string" then
        return false, "Name missing."
    end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return false, "Name missing."
    end
    if #name > 32 then
        name = name:sub(1, 32)
    end
    local root = DB.Root()
    root.profiles[name] = CopyTable(DB.Get())
    local key = UF.Compat and UF.Compat.CharacterKey and UF.Compat.CharacterKey() or "Unknown - Realm"
    root.profileKeys[key] = name
    return true, "Saved profile " .. name .. "."
end

function DB.Delete(name)
    if name == "Default" then
        return false, "The Default profile cannot be deleted."
    end
    local root = DB.Root()
    if type(root.profiles[name]) ~= "table" then
        return false, "No profile named " .. name .. "."
    end
    root.profiles[name] = nil
    if DB.CurrentName() == name then
        DB.Switch("Default")
    end
    return true, "Deleted profile " .. name .. "."
end

function DB.ApplyExportTable(data, name)
    if type(data) ~= "table" then
        return false, "That code is empty."
    end
    if data.v and data.v ~= 1 then
        return false, "This code is from a newer addon version."
    end
    local profile = DB.DefaultProfile()
    if data.style == "classic" or data.style == "modern" then
        profile.style = data.style
    end
    if data.classColors == "classic" or data.classColors == "modern" then
        profile.classColors = data.classColors
    end
    if data.portrait == "portrait" or data.portrait == "class" or data.portrait == "off" then
        profile.portrait = data.portrait
    end
    if type(data.showPower) == "boolean" then
        profile.showPower = data.showPower
    end
    if type(data.showAltPower) == "boolean" then
        profile.showAltPower = data.showAltPower
    end
    if data.healthText == "percent" or data.healthText == "current" or data.healthText == "both" or data.healthText == "none" then
        profile.healthText = data.healthText
    end
    if data.powerText == "percent" or data.powerText == "current" or data.powerText == "both" or data.powerText == "none" then
        profile.powerText = data.powerText
    end
    if type(data.showPlayerInParty) == "boolean" then
        profile.showPlayerInParty = data.showPlayerInParty
    end
    if type(data.locked) == "boolean" then
        profile.locked = data.locked
    end
    if type(data.speech) == "table" then
        Merge(profile.speech, data.speech)
        if type(data.speech.enabled) == "boolean" then
            profile.speech.enabled = data.speech.enabled
        end
        if type(data.speech.healthLow) == "boolean" then
            profile.speech.healthLow = data.speech.healthLow
        end
        if type(data.speech.targetChange) == "boolean" then
            profile.speech.targetChange = data.speech.targetChange
        end
    end
    if type(data.frames) == "table" then
        for id, frame in pairs(data.frames) do
            if type(id) == "string" and type(frame) == "table" and type(profile.frames[id]) == "table" then
                Merge(profile.frames[id], frame)
                for key, value in pairs(frame) do
                    if profile.frames[id][key] ~= nil then
                        profile.frames[id][key] = value
                    end
                end
            end
        end
    end
    name = name or data.name
    if type(name) ~= "string" or name == "" then
        name = "Imported"
    end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if #name > 32 then
        name = name:sub(1, 32)
    end
    local root = DB.Root()
    root.profiles[name] = profile
    local key = UF.Compat and UF.Compat.CharacterKey and UF.Compat.CharacterKey() or "Unknown - Realm"
    root.profileKeys[key] = name
    if UF.ApplyProfile then
        UF.ApplyProfile(profile)
    end
    return true, "Imported profile " .. name .. "."
end
