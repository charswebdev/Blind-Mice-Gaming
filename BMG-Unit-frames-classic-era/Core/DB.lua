--[[
  BMG Unit Frames — profiles and automatic save
  Lua 5.1 only.

  WoW writes the flavor SavedVariables table on logout and /reload.
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
        healthColor = "blizzard",
        healthBarH = (id == "raid") and 18 or ((id == "pet" or id == "tot") and 26 or 36),
        powerBarH = (id == "raid") and 8 or ((id == "pet" or id == "tot") and 12 or 14),
        nameBar = "top",
        nameBarH = (id == "raid") and 12 or ((id == "pet" or id == "tot") and 14 or 16),
        nameBarW = 0,
        healthBarW = 0,
        powerBarW = 0,
        altBarW = 0,
        nameBarAlign = "LEFT",
        healthBarAlign = "LEFT",
        powerBarAlign = "LEFT",
        altBarAlign = "LEFT",
        nameBg = "dark",
        nameText = "white",
        barStyle = "blizzard",
        showLevel = true,
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
            groupRole = id ~= "pet",
            resurrect = true,
            ready = true,
            elite = (id == "target" or id == "focus" or id == "tot"),
            rare = (id == "target" or id == "focus" or id == "tot"),
            rareelite = (id == "target" or id == "focus" or id == "tot"),
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
            groupRole = "LEFT",
            resurrect = "CENTER",
            ready = "RIGHT",
            elite = "TOPRIGHT",
            rare = "RIGHT",
            rareelite = "TOP",
            happiness = "BOTTOMRIGHT",
            phase = "LEFT",
            oor = "BOTTOM",
            quest = "TOP",
        },
        indSize = {
            combat = 14,
            resting = 14,
            leader = 12,
            raidTarget = 18,
            pvp = 16,
            role = 12,
            groupRole = 16,
            resurrect = 16,
            ready = 16,
            elite = 20,
            rare = 18,
            rareelite = 20,
            happiness = 16,
            phase = 16,
            oor = 14,
            quest = 16,
        },
        textPos = {
            name = "LEFT",
            level = "RIGHT",
            health = "LEFT",
            healthPct = "RIGHT",
            power = "LEFT",
            powerPct = "RIGHT",
            alt = "LEFT",
            altPct = "RIGHT",
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
        portrait = (UF.Flavor and UF.Flavor.defaultPortrait) or "2d",
        healthColor = "blizzard",
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
            player = DB.DefaultFrame("player", { enabled = true, point = "BOTTOMLEFT", x = 20, y = 20, scale = 1, w = 250, h = 74 }),
            pet = DB.DefaultFrame("pet", { enabled = true, point = "BOTTOMLEFT", x = 20, y = 0, scale = 1, w = 200, h = 60 }),
            target = DB.DefaultFrame("target", { enabled = true, point = "BOTTOMRIGHT", x = -20, y = 20, scale = 1, w = 250, h = 74 }),
            tot = DB.DefaultFrame("tot", { enabled = true, point = "BOTTOMRIGHT", x = -20, y = 0, scale = 1, w = 200, h = 60 }),
            focus = DB.DefaultFrame("focus", { enabled = true, point = "TOPLEFT", x = 20, y = -80, scale = 1, w = 250, h = 74 }),
            party = DB.DefaultFrame("party", { enabled = true, point = "LEFT", x = 20, y = 80, scale = 1, w = 250, h = 74, growth = "DOWN" }),
            raid = DB.DefaultFrame("raid", { enabled = true, point = "LEFT", x = 20, y = 200, scale = 1, w = 110, h = 46, growth = "DOWN" }),
            arena = DB.DefaultFrame("arena", { enabled = true, point = "RIGHT", x = -20, y = 80, scale = 1, w = 250, h = 74, growth = "DOWN" }),
        },
    }
end

function DB.Exportable(profile)
    profile = profile or DB.Get()
    return {
        v = 1,
        addon = (UF.Flavor and UF.Flavor.product) or "BMG-Unit-frames",
        name = DB.CurrentName(),
        style = profile.style,
        classColors = profile.classColors,
        portrait = profile.portrait,
        healthColor = profile.healthColor,
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

function DB.SavedName()
    return (UF.Flavor and UF.Flavor.saved) or "BMGUnitFramesDB"
end

function DB.Root()
    local name = DB.SavedName()
    if type(_G[name]) ~= "table" then
        _G[name] = {}
    end
    return _G[name]
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
            if (profile.layoutVersion or 1) < 5 then
                profile.healthColor = profile.healthColor or "blizzard"
                if profile.portrait == "portrait" then
                    profile.portrait = (UF.Flavor and UF.Flavor.defaultPortrait) or "2d"
                end
                if profile.portrait == "off" then
                    profile.portrait = "hidden"
                end
                local grow = {
                    player = { 60, 76 },
                    target = { 60, 76 },
                    focus = { 60, 76 },
                    party = { 60, 76 },
                    arena = { 60, 76 },
                    pet = { 48, 56 },
                    tot = { 48, 56 },
                    raid = { 36, 40 },
                }
                for id, pair in pairs(grow) do
                    local cfg = profile.frames and profile.frames[id]
                    if type(cfg) == "table" then
                        if cfg.portrait == "portrait" then
                            cfg.portrait = profile.portrait
                        end
                        if cfg.portrait == "off" then
                            cfg.portrait = "hidden"
                        end
                        if cfg.healthColor == nil then
                            cfg.healthColor = "blizzard"
                        end
                        if cfg.h == pair[1] then
                            cfg.h = pair[2]
                        end
                    end
                end
                profile.layoutVersion = 5
            end
            if (profile.layoutVersion or 1) < 6 then
                local bars = {
                    player = { 24, 18, 88 },
                    target = { 24, 18, 88 },
                    focus = { 24, 18, 88 },
                    party = { 24, 18, 88 },
                    arena = { 24, 18, 88 },
                    pet = { 20, 14, 72 },
                    tot = { 20, 14, 72 },
                    raid = { 14, 10, 48 },
                }
                for id, pack in pairs(bars) do
                    local cfg = profile.frames and profile.frames[id]
                    if type(cfg) == "table" then
                        if type(cfg.healthBarH) ~= "number" then
                            cfg.healthBarH = pack[1]
                        end
                        if type(cfg.powerBarH) ~= "number" then
                            cfg.powerBarH = pack[2]
                        end
                        if (cfg.h or 0) < pack[3] then
                            cfg.h = pack[3]
                        end
                    end
                end
                profile.layoutVersion = 6
            end
            if (profile.layoutVersion or 1) < 7 then
                for _, cfg in pairs(profile.frames or {}) do
                    if type(cfg) == "table" then
                        local pad, gap = 3, 1
                        local powerOn = cfg.showPower
                        if powerOn == nil then
                            powerOn = profile.showPower ~= false
                        end
                        local powerH = 0
                        if powerOn then
                            powerH = tonumber(cfg.powerBarH) or 14
                        end
                        local reserved = pad + (powerH > 0 and (powerH + gap) or 0) + pad
                        local frameH = tonumber(cfg.h) or 56
                        local healthH = frameH - reserved
                        if healthH < 12 then
                            healthH = 12
                            frameH = reserved + healthH
                        end
                        cfg.h = frameH
                        cfg.healthBarH = healthH
                    end
                end
                profile.layoutVersion = 7
            end
            if (profile.layoutVersion or 1) < 8 then
                for id, cfg in pairs(profile.frames or {}) do
                    if type(cfg) == "table" then
                        if cfg.nameBar == nil then
                            cfg.nameBar = "top"
                        end
                        if type(cfg.nameBarH) ~= "number" then
                            cfg.nameBarH = (id == "raid") and 12 or 16
                        end
                        if cfg.nameBg == nil then
                            cfg.nameBg = "dark"
                        end
                        if cfg.nameText == nil then
                            cfg.nameText = "white"
                        end
                        if cfg.nameBar == "top" or cfg.nameBar == "bottom" then
                            cfg.h = (tonumber(cfg.h) or 56) + cfg.nameBarH + 1
                        end
                    end
                end
                profile.layoutVersion = 8
            end
            if (profile.layoutVersion or 1) < 9 then
                for _, cfg in pairs(profile.frames or {}) do
                    if type(cfg) == "table" then
                        if cfg.showLevel == nil then
                            cfg.showLevel = true
                        end
                        if type(cfg.nameBarW) ~= "number" then
                            cfg.nameBarW = 0
                        end
                        if type(cfg.healthBarW) ~= "number" then
                            cfg.healthBarW = 0
                        end
                        if type(cfg.powerBarW) ~= "number" then
                            cfg.powerBarW = 0
                        end
                        if type(cfg.altBarW) ~= "number" then
                            cfg.altBarW = 0
                        end
                        cfg.nameBarAlign = cfg.nameBarAlign or "LEFT"
                        cfg.healthBarAlign = cfg.healthBarAlign or "LEFT"
                        cfg.powerBarAlign = cfg.powerBarAlign or "LEFT"
                        cfg.altBarAlign = cfg.altBarAlign or "LEFT"
                        cfg.textPos = cfg.textPos or {}
                        if cfg.textPos.level == nil then
                            cfg.textPos.level = "RIGHT"
                        end
                        if cfg.textPos.healthPct == nil then
                            cfg.textPos.healthPct = "RIGHT"
                            if cfg.textPos.health == "CENTER" then
                                cfg.textPos.health = "LEFT"
                            end
                        end
                        if cfg.textPos.powerPct == nil then
                            cfg.textPos.powerPct = "RIGHT"
                            if cfg.textPos.power == "CENTER" then
                                cfg.textPos.power = "LEFT"
                            end
                        end
                        if cfg.textPos.alt == nil then
                            cfg.textPos.alt = "LEFT"
                        end
                        if cfg.textPos.altPct == nil then
                            cfg.textPos.altPct = "RIGHT"
                        end
                    end
                end
                profile.layoutVersion = 9
            end
            if (profile.layoutVersion or 1) < 10 then
                local sizes = {
                    combat = 14,
                    resting = 14,
                    leader = 12,
                    raidTarget = 18,
                    pvp = 16,
                    role = 12,
                    resurrect = 16,
                    ready = 16,
                    elite = 20,
                    rare = 18,
                    happiness = 16,
                    phase = 16,
                    oor = 14,
                    quest = 16,
                }
                for id, cfg in pairs(profile.frames or {}) do
                    if type(cfg) == "table" then
                        cfg.indicators = cfg.indicators or {}
                        if cfg.indicators.rare == nil then
                            cfg.indicators.rare = (id == "target" or id == "focus" or id == "tot")
                        end
                        cfg.indPos = cfg.indPos or {}
                        if cfg.indPos.rare == nil then
                            cfg.indPos.rare = "RIGHT"
                        end
                        cfg.indSize = cfg.indSize or {}
                        for key, def in pairs(sizes) do
                            if type(cfg.indSize[key]) ~= "number" then
                                cfg.indSize[key] = def
                            end
                        end
                    end
                end
                profile.layoutVersion = 10
            end
            if (profile.layoutVersion or 1) < 11 then
                for id, cfg in pairs(profile.frames or {}) do
                    if type(cfg) == "table" then
                        cfg.indicators = cfg.indicators or {}
                        if cfg.indicators.rareelite == nil then
                            cfg.indicators.rareelite = (id == "target" or id == "focus" or id == "tot")
                        end
                        cfg.indPos = cfg.indPos or {}
                        if cfg.indPos.rareelite == nil then
                            cfg.indPos.rareelite = "TOP"
                        end
                        cfg.indSize = cfg.indSize or {}
                        if type(cfg.indSize.rareelite) ~= "number" then
                            cfg.indSize.rareelite = 20
                        end
                    end
                end
                profile.layoutVersion = 11
            end
            if (profile.layoutVersion or 1) < 12 then
                for _, cfg in pairs(profile.frames or {}) do
                    if type(cfg) == "table" and cfg.barStyle == nil then
                        cfg.barStyle = "blizzard"
                    end
                end
                profile.layoutVersion = 12
            end
            if (profile.layoutVersion or 1) < 13 then
                for id, cfg in pairs(profile.frames or {}) do
                    if type(cfg) == "table" then
                        cfg.indicators = cfg.indicators or {}
                        if cfg.indicators.groupRole == nil then
                            cfg.indicators.groupRole = id ~= "pet"
                        end
                        cfg.indPos = cfg.indPos or {}
                        if cfg.indPos.groupRole == nil then
                            cfg.indPos.groupRole = "LEFT"
                        end
                        cfg.indSize = cfg.indSize or {}
                        if type(cfg.indSize.groupRole) ~= "number" then
                            cfg.indSize.groupRole = 16
                        end
                    end
                end
                profile.layoutVersion = 13
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
    local retailFirst = UF.Compat and UF.Compat.IsRetail and UF.Compat.IsRetail() and profile.retailSnap ~= true
    if force or (profile.layoutVersion or 1) < 2 or retailFirst then
        DB.ApplySnap(points)
        if (profile.layoutVersion or 1) < 2 then
            profile.layoutVersion = 2
        end
        if retailFirst then
            profile.retailSnap = true
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
    if data.portrait == "3d" or data.portrait == "2d" or data.portrait == "class" or data.portrait == "hidden"
        or data.portrait == "portrait" or data.portrait == "off" then
        profile.portrait = data.portrait
        if profile.portrait == "portrait" then
            profile.portrait = "2d"
        end
        if profile.portrait == "off" then
            profile.portrait = "hidden"
        end
    end
    if data.healthColor == "blizzard" or data.healthColor == "class" then
        profile.healthColor = data.healthColor
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
