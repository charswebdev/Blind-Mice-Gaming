--[[
  Accessibility Helper — loss of control, harmful debuff types, combat buffs
  Buffs (in combat only): apply / fade / stacks / duration. Option B — all helpful.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Combat = AH.Combat or {}
local Combat = AH.Combat

local lastLoc = {} -- [locType] = last announce time
local lastDebuffCounts = {
    Magic = 0,
    Curse = 0,
    Disease = 0,
    Poison = 0,
}
-- [key] = { name, stacks, duration, expiration }
local knownBuffs = {}
local readyAt = 0
local LOC_COOLDOWN = 0.5
local AURA_DEBOUNCE = 0.25
local auraScanGen = 0

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function On(key)
    return DB()[key] ~= false
end

local function CanUseNumber(v)
    if AH.Compat and AH.Compat.CanUseNumber then
        return AH.Compat.CanUseNumber(v)
    end
    return type(v) == "number"
end

local function ForSpeech(text)
    if AH.ChatText and AH.ChatText.ForSpeech then
        return AH.ChatText.ForSpeech(text)
    end
    if type(text) ~= "string" then
        return ""
    end
    return text
end

local function SayCritical(msg, itemKey)
    if AH.Alerts and AH.Alerts.Announce then
        AH.Alerts.Announce("loc", msg, AH.Speech and AH.Speech.PRIORITY_CRITICAL, itemKey)
    elseif AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_CRITICAL)
    else
        print("|cff66ccff[Helper]|r " .. tostring(msg))
    end
end

local function SayBuff(msg, itemKey)
    if AH.Alerts and AH.Alerts.Announce then
        AH.Alerts.Announce("buff", msg, AH.Speech and AH.Speech.PRIORITY_STATUS, itemKey)
    elseif AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_STATUS)
    else
        print("|cff66ccff[Helper]|r " .. tostring(msg))
    end
end

local function SayDebuff(msg, itemKey)
    if AH.Alerts and AH.Alerts.Announce then
        AH.Alerts.Announce("debuff", msg, AH.Speech and AH.Speech.PRIORITY_CRITICAL, itemKey)
    else
        SayCritical(msg, itemKey)
    end
end

-- Back-compat alias used by LoC / debuffs.
local function Say(msg, itemKey)
    SayCritical(msg, itemKey)
end

local function SafeCall(fn, ...)
    if not fn then
        return nil
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d
end

local function InCombat()
    if UnitAffectingCombat then
        local ok, v = pcall(UnitAffectingCombat, "player")
        if ok and v then
            return true
        end
    end
    return false
end

-- Map Blizzard locType strings to DB keys / speech labels.
local LOC_MAP = {
    STUN = { key = "combatLocStun", label = "Stunned" },
    STUN_MECHANIC = { key = "combatLocStun", label = "Stunned" },
    ROOT = { key = "combatLocRoot", label = "Rooted" },
    SILENCE = { key = "combatLocSilence", label = "Silenced" },
    FEAR = { key = "combatLocFear", label = "Feared" },
    HORROR = { key = "combatLocHorror", label = "Horror" },
    DISORIENT = { key = "combatLocDisorient", label = "Disoriented" },
    CONFUSE = { key = "combatLocDisorient", label = "Disoriented" },
    CYCLONE = { key = "combatLocCyclone", label = "Cycloned" },
    INCAPACITATE = { key = "combatLocIncap", label = "Incapacitated" },
    CHARM = { key = "combatLocCharm", label = "Charmed" },
    POSSESS = { key = "combatLocCharm", label = "Possessed" },
    PACIFY = { key = "combatLocPacify", label = "Pacified" },
    DISARM = { key = "combatLocDisarm", label = "Disarmed" },
    SCHOOL_INTERRUPT = { key = "combatLocLockout", label = "Interrupted" },
    INTERRUPT = { key = "combatLocLockout", label = "Interrupted" },
    BANISH = { key = "combatLocBanish", label = "Banished" },
    SNOOZE = { key = "combatLocIncap", label = "Asleep" },
    SLEEP = { key = "combatLocIncap", label = "Asleep" },
    POLYMORPH = { key = "combatLocIncap", label = "Polymorphed" },
    SHACKLE_UNDEAD = { key = "combatLocIncap", label = "Shackled" },
}

local FormatDurationSeconds

local function NormalizeLocType(locType)
    if type(locType) ~= "string" then
        return nil
    end
    return string.upper(locType)
end

local function AnnounceLoC()
    if not On("combatLocEnabled") then
        return
    end
    if not (C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount) then
        return
    end
    local count = SafeCall(C_LossOfControl.GetActiveLossOfControlDataCount) or 0
    local now = GetTime and GetTime() or 0
    for i = 1, count do
        local data = SafeCall(C_LossOfControl.GetActiveLossOfControlData, i)
        if type(data) == "table" then
            local locType = NormalizeLocType(data.locType)
            local map = locType and LOC_MAP[locType]
            local key = map and map.key or "combatLocOther"
            local label = map and map.label or (data.displayText or locType or "Loss of control")
            if On(key) then
                local lastAt = lastLoc[locType or label] or 0
                if (now - lastAt) >= LOC_COOLDOWN then
                    lastLoc[locType or label] = now
                    local rem = data.timeRemaining or data.duration
                    local remText = FormatDurationSeconds(rem)
                    local line
                    if On("combatAnnounceSpellNames") and type(data.displayText) == "string" and data.displayText ~= "" then
                        line = label .. ": " .. data.displayText
                    else
                        line = label
                    end
                    if remText then
                        line = line .. ". " .. remText
                    end
                    Say(line .. ".", key)
                end
            end
        end
    end
end

local DEBUFF_KEYS = {
    Magic = "combatAuraMagic",
    Curse = "combatAuraCurse",
    Disease = "combatAuraDisease",
    Poison = "combatAuraPoison",
}

local function CountHarmfulDebuffs()
    local counts = { Magic = 0, Curse = 0, Disease = 0, Poison = 0 }
    local function add(dispelType)
        if dispelType and counts[dispelType] ~= nil then
            counts[dispelType] = counts[dispelType] + 1
        end
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local i = 1
        while i <= 40 do
            local data = SafeCall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HARMFUL")
            if not data then
                break
            end
            add(data.dispelName or data.dispelType)
            i = i + 1
        end
        return counts
    end

    local fn = UnitDebuff or UnitAura
    if fn then
        for i = 1, 40 do
            local name, _, _, dispelType
            if UnitDebuff then
                name, _, _, dispelType = SafeCall(UnitDebuff, "player", i)
            else
                local a1, a2, a3, a4, a5 = SafeCall(UnitAura, "player", i, "HARMFUL")
                name = a1
                dispelType = a5 or a4
            end
            if not name then
                break
            end
            add(dispelType)
        end
    end
    return counts
end

local function AnnounceDebuffChanges()
    if not On("combatAurasEnabled") then
        return
    end
    local counts = CountHarmfulDebuffs()
    for dtype, key in pairs(DEBUFF_KEYS) do
        local cur = counts[dtype] or 0
        local prev = lastDebuffCounts[dtype] or 0
        if cur > prev and On(key) then
            if cur == 1 then
                SayDebuff(dtype .. " debuff.", key)
            else
                SayDebuff(string.format("%s debuffs: %d.", dtype, cur), key)
            end
        end
        lastDebuffCounts[dtype] = cur
    end
end

--------------------------------------------------------------------------
-- Combat buffs (Option B): all HELPFUL on player while in combat
--------------------------------------------------------------------------

local function BuffStacks(data)
    local n = data.applications or data.charges or 1
    if not CanUseNumber(n) or n < 1 then
        return 1
    end
    return math.floor(n)
end

local function EntryFromAuraData(data)
    if type(data) ~= "table" then
        return nil
    end
    local name = ForSpeech(data.name or "")
    if name == "" then
        return nil
    end
    local duration = data.duration
    local expiration = data.expirationTime
    if duration ~= nil and not CanUseNumber(duration) then
        duration = nil
    end
    if expiration ~= nil and not CanUseNumber(expiration) then
        expiration = nil
    end
    return {
        name = name,
        stacks = BuffStacks(data),
        duration = duration,
        expiration = expiration,
    }
end

local function SnapshotHelpfulBuffs()
    local snap = {}

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local i = 1
        while i <= 40 do
            local data = SafeCall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not data then
                break
            end
            local entry = EntryFromAuraData(data)
            if entry then
                local key
                if data.auraInstanceID ~= nil then
                    key = "a" .. tostring(data.auraInstanceID)
                else
                    key = "n" .. entry.name .. ":" .. tostring(data.spellId or i)
                end
                snap[key] = entry
            end
            i = i + 1
        end
        return snap
    end

    local fn = UnitBuff or UnitAura
    if fn then
        for i = 1, 40 do
            local ok, name, icon, count, debuffType, duration, expirationTime, _, _, _, spellId
            if UnitBuff then
                ok, name, icon, count, debuffType, duration, expirationTime, _, _, _, spellId =
                    pcall(UnitBuff, "player", i)
            else
                ok, name, icon, count, debuffType, duration, expirationTime, _, _, _, spellId =
                    pcall(UnitAura, "player", i, "HELPFUL")
            end
            if not ok or not name then
                break
            end
            local data = {
                name = name,
                applications = count,
                duration = duration,
                expirationTime = expirationTime,
                spellId = spellId,
            }
            local entry = EntryFromAuraData(data)
            if entry then
                snap["n" .. entry.name .. ":" .. tostring(spellId or i)] = entry
            end
        end
    end
    return snap
end

FormatDurationSeconds = function(sec)
    if not CanUseNumber(sec) or sec <= 0 then
        return nil
    end
    sec = math.floor(sec + 0.5)
    if sec < 1 then
        sec = 1
    end
    if sec >= 3600 then
        local h = math.floor(sec / 3600)
        local m = math.floor((sec % 3600) / 60)
        if m > 0 then
            return string.format("%d hours %d minutes", h, m)
        end
        if h == 1 then
            return "1 hour"
        end
        return string.format("%d hours", h)
    end
    if sec >= 60 then
        local m = math.floor(sec / 60)
        local s = sec % 60
        if s == 0 then
            if m == 1 then
                return "1 minute"
            end
            return string.format("%d minutes", m)
        end
        if m == 1 then
            return string.format("1 minute %d seconds", s)
        end
        return string.format("%d minutes %d seconds", m, s)
    end
    if sec == 1 then
        return "1 second"
    end
    return string.format("%d seconds", sec)
end

local function RemainingPhrase(entry)
    if not On("combatBuffsDuration") or type(entry) ~= "table" then
        return nil
    end
    local dur = entry.duration
    if not CanUseNumber(dur) or dur <= 0 then
        return nil -- permanent / unknown
    end
    local now = GetTime and GetTime() or 0
    local rem
    if CanUseNumber(entry.expiration) then
        rem = entry.expiration - now
    else
        rem = dur
    end
    return FormatDurationSeconds(rem)
end

local function FormatBuffApplyOrUpdate(entry)
    local parts = { entry.name }
    if On("combatBuffsStacks") and entry.stacks and entry.stacks > 1 then
        parts[#parts + 1] = string.format("%d stacks", entry.stacks)
    end
    local rem = RemainingPhrase(entry)
    if rem then
        parts[#parts + 1] = rem
    end
    return table.concat(parts, ". ") .. "."
end

local function FormatBuffFade(entry)
    return entry.name .. " faded."
end

local function SeedBuffs()
    knownBuffs = SnapshotHelpfulBuffs()
end

local function AnnounceBuffChanges()
    if not On("combatBuffsEnabled") then
        knownBuffs = SnapshotHelpfulBuffs()
        return
    end
    if not InCombat() then
        knownBuffs = SnapshotHelpfulBuffs()
        return
    end

    local snap = SnapshotHelpfulBuffs()
    local applyLines = {}
    local stackLines = {}
    local fadeLines = {}

    -- New or updated (stack change). Pure duration refreshes stay quiet.
    for key, entry in pairs(snap) do
        local prev = knownBuffs[key]
        if not prev then
            if On("combatBuffsApply") then
                applyLines[#applyLines + 1] = FormatBuffApplyOrUpdate(entry)
            end
        elseif entry.stacks ~= prev.stacks then
            if On("combatBuffsStacks") then
                stackLines[#stackLines + 1] = FormatBuffApplyOrUpdate(entry)
            elseif On("combatBuffsApply") then
                applyLines[#applyLines + 1] = FormatBuffApplyOrUpdate(entry)
            end
        end
    end

    -- Faded
    if On("combatBuffsFade") then
        for key, prev in pairs(knownBuffs) do
            if not snap[key] then
                fadeLines[#fadeLines + 1] = FormatBuffFade(prev)
            end
        end
    end

    knownBuffs = snap

    if #applyLines > 0 then
        SayBuff(table.concat(applyLines, " "), "combatBuffsApply")
    end
    if #stackLines > 0 then
        SayBuff(table.concat(stackLines, " "), "combatBuffsStacks")
    end
    if #fadeLines > 0 then
        SayBuff(table.concat(fadeLines, " "), "combatBuffsFade")
    end
end

local function ProcessAuraScan()
    AnnounceDebuffChanges()
    AnnounceBuffChanges()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("LOSS_OF_CONTROL_ADDED")
frame:RegisterEvent("LOSS_OF_CONTROL_UPDATE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

frame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        readyAt = (GetTime and GetTime() or 0) + 2
        lastDebuffCounts = CountHarmfulDebuffs()
        SeedBuffs()
        return
    end
    local now = GetTime and GetTime() or 0
    if now < readyAt then
        return
    end

    if event == "LOSS_OF_CONTROL_ADDED" or event == "LOSS_OF_CONTROL_UPDATE" then
        AnnounceLoC()
        return
    end
    if event == "UNIT_AURA" then
        if unit == "player" or unit == nil then
            -- Debounce aura storms so LOC / other CRITICAL TTS stay timely.
            auraScanGen = auraScanGen + 1
            local myGen = auraScanGen
            if C_Timer and C_Timer.After then
                C_Timer.After(AURA_DEBOUNCE, function()
                    if myGen ~= auraScanGen then
                        return
                    end
                    ProcessAuraScan()
                end)
            else
                ProcessAuraScan()
            end
        end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        -- Seed at combat start without announcing existing auras / buffs.
        auraScanGen = auraScanGen + 1
        lastDebuffCounts = CountHarmfulDebuffs()
        SeedBuffs()
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        -- Leave combat quietly — do not dump every buff as faded.
        auraScanGen = auraScanGen + 1
        SeedBuffs()
    end
end)
