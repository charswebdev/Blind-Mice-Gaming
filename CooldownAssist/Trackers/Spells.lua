--[[
  Cooldown Assist — spell readiness tracking
  Watches a spell only after a successful cast. Spellbook map is for classification.
  Secret-safe: branch on NeverSecret booleans; only use duration when readable.
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Spells = CA.Spells or {}
local Spells = CA.Spells

local GCD_SPELL_ID = 61304
local POLL_SEC = 1.0
local RESCAN_SEC = 0.75
local RESCAN_SEC_COMBAT = 2.0
local PENDING_REFRESH_THROTTLE = 0.25
local FULL_REFRESH_THROTTLE = 2.5
local SETTINGS_REFRESH_THROTTLE = 1.25
local MAP_REBUILD_SEC = 8

-- [key] = entry
local tracked = {}
local pendingCount = 0
local pollTicker = nil
local rescanPending = false
local rescanHeavy = false
local barRescanPending = false
local lastPendingRefresh = 0
local lastFullRefresh = 0
local lastSettingsRefresh = 0
local lastMapRebuild = 0
local baseSpellCache = {}
local baseCdCache = {}
local dirtySlots = {}
local dirtySlotCount = 0
local slotFlushPending = false

local function CanUseNumber(v)
    if CA.Compat and CA.Compat.CanUseNumber then
        return CA.Compat.CanUseNumber(v)
    end
    return type(v) == "number"
end

--- NeverSecret booleans (isActive / isOnGCD / isEnabled) — never compare secrets bare.
local function SafeFlagTrue(v)
    if CA.Compat and CA.Compat.SafeFlagTrue then
        return CA.Compat.SafeFlagTrue(v)
    end
    local ok, result = pcall(function()
        return v == true
    end)
    return ok and result and true or false
end

local function SafeFlagFalse(v)
    if CA.Compat and CA.Compat.SafeFlagFalse then
        return CA.Compat.SafeFlagFalse(v)
    end
    local ok, result = pcall(function()
        return v == false
    end)
    return ok and result and true or false
end

local function MinCooldownSec()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    local v = sv.minCooldownSeconds
    if type(v) ~= "number" or v < 0 then
        return 5
    end
    return v
end

local function TrackerKey(spellID)
    return "spell:" .. tostring(spellID)
end

local function SafeCall(fn, ...)
    if CA.Compat and CA.Compat.SafeCall then
        return CA.Compat.SafeCall(fn, ...)
    end
    if not fn then
        return
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        return
    end
    return unpack(results, 2, #results)
end

local function SafeRegisterEvent(frame, event)
    if CA.Compat and CA.Compat.SafeRegisterEvent then
        return CA.Compat.SafeRegisterEvent(frame, event)
    end
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok and true or false
end

local function SafeRegisterUnitEvent(frame, event, ...)
    if CA.Compat and CA.Compat.SafeRegisterUnitEvent then
        return CA.Compat.SafeRegisterUnitEvent(frame, event, ...)
    end
    return SafeRegisterEvent(frame, event)
end

local function NormalizeSpellID(spellID)
    -- Secret spell IDs must not be compared or used as table keys.
    if not CanUseNumber(spellID) or spellID <= 0 then
        return nil
    end
    if spellID == GCD_SPELL_ID then
        return nil
    end
    local cached = baseSpellCache[spellID]
    if cached then
        return cached
    end
    local original = spellID
    if C_Spell and C_Spell.GetBaseSpell then
        local base = SafeCall(C_Spell.GetBaseSpell, spellID)
        if CanUseNumber(base) and base > 0 then
            spellID = base
        end
    end
    baseSpellCache[original] = spellID
    return spellID
end

local function GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local name = SafeCall(C_Spell.GetSpellName, spellID)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return "Spell " .. tostring(spellID)
end

local function GetSpellIcon(spellID)
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = SafeCall(C_Spell.GetSpellTexture, spellID)
        if tex then
            return tex
        end
    end
    if GetSpellTexture then
        local tex = SafeCall(GetSpellTexture, spellID)
        if tex then
            return tex
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetCooldownState(spellID)
    local cd
    if CA.Compat and CA.Compat.GetSpellCooldownState then
        cd = CA.Compat.GetSpellCooldownState(spellID)
    end
    -- Talent overrides (e.g. paladin Crusade replacing Avenging Wrath) store
    -- the live cooldown on the override ID, not always the base spell.
    if (not cd or not cd.isActive) and C_Spell and C_Spell.GetOverrideSpell then
        local ov = SafeCall(C_Spell.GetOverrideSpell, spellID)
        if CanUseNumber(ov) and ov > 0 and ov ~= spellID then
            local cdOv = CA.Compat and CA.Compat.GetSpellCooldownState and CA.Compat.GetSpellCooldownState(ov)
            if cdOv and cdOv.isActive then
                return cdOv
            end
        end
    end
    return cd
end

--- Static book cooldown in seconds (not secret). Used when live duration is hidden.
local function GetBaseCooldownSec(spellID)
    if type(spellID) ~= "number" then
        return nil
    end
    local cached = baseCdCache[spellID]
    if cached ~= nil then
        if cached == false then
            return nil
        end
        return cached
    end
    local cdMS
    if C_Spell and C_Spell.GetSpellBaseCooldown then
        cdMS = SafeCall(C_Spell.GetSpellBaseCooldown, spellID)
    elseif GetSpellBaseCooldown then
        cdMS = SafeCall(GetSpellBaseCooldown, spellID)
    end
    if CanUseNumber(cdMS) and cdMS > 0 then
        local sec = cdMS / 1000
        baseCdCache[spellID] = sec
        return sec
    end
    baseCdCache[spellID] = false
    return nil
end

local function GetCharges(spellID)
    if CA.Compat and CA.Compat.GetSpellChargesState then
        return CA.Compat.GetSpellChargesState(spellID)
    end
    return nil
end

local function IsEnabledKey(key)
    if CA.DB and CA.DB.IsTrackerEnabled then
        return CA.DB.IsTrackerEnabled(key)
    end
    return true
end

local function MajorCooldownSec()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    local v = sv.majorCooldownSeconds
    if type(v) ~= "number" or v < 5 then
        return 45
    end
    return v
end

local function IsPassive(spellID)
    if CA.Categories and CA.Categories.IsPassiveSpell then
        return CA.Categories.IsPassiveSpell(spellID)
    end
    if C_Spell and C_Spell.IsSpellPassive then
        local v = SafeCall(C_Spell.IsSpellPassive, spellID)
        return v and true or false
    end
    return false
end

local function CanAnnounceEntry(entry)
    if not entry or not IsEnabledKey(entry.key) then
        return false
    end
    local cat = entry.category or "ability"
    if CA.Categories and CA.Categories.IsEnabled then
        return CA.Categories.IsEnabled(cat)
    end
    return true
end

local function IsMajorEntry(entry)
    local maj = MajorCooldownSec()
    if type(entry.observedDuration) == "number" and entry.observedDuration >= maj then
        return true
    end
    return false
end

local function EnsurePoll()
    if pollTicker or pendingCount <= 0 then
        return
    end
    if not (C_Timer and C_Timer.NewTicker) then
        return
    end
    pollTicker = C_Timer.NewTicker(POLL_SEC, function()
        Spells.PollPending()
        if pendingCount <= 0 and pollTicker then
            pollTicker:Cancel()
            pollTicker = nil
        end
    end)
end

local function SetPending(entry, pending)
    if entry.pending == pending then
        return
    end
    entry.pending = pending
    if pending then
        pendingCount = pendingCount + 1
        EnsurePoll()
    else
        pendingCount = math.max(0, pendingCount - 1)
    end
end

local function ShouldTrackDuration(spellID, duration, isOnGCD)
    local minSec = MinCooldownSec()
    if type(duration) == "number" then
        if duration > 0 and duration < minSec then
            return false
        end
        -- Pure GCD pulse.
        if isOnGCD and duration <= 1.6 then
            return false
        end
        return duration >= minSec
    end
    -- Live duration is secret/unknown (Midnight combat). isOnGCD is untrusted
    -- except on that spell's SPELL_UPDATE_COOLDOWN, and GCD spells like
    -- Avenging Wrath report isOnGCD=true while a real 2-minute CD is also active.
    -- Use the spell's book cooldown so we still watch real CDs and skip fillers.
    local base = GetBaseCooldownSec(spellID)
    if type(base) == "number" then
        return base >= minSec
    end
    if isOnGCD then
        return false
    end
    return true
end

local function AnnounceOpts(entry)
    if CA.Announce and CA.Announce.OptsForEntry then
        return CA.Announce.OptsForEntry(entry)
    end
    return nil
end

local function OnBecameReady(entry)
    SetPending(entry, false)
    entry.wakeAt = nil
    local minSec = MinCooldownSec()
    local meaningful = (type(entry.observedDuration) == "number" and entry.observedDuration >= minSec)
        or entry.sawSecretCooldown == true
    entry.sawSecretCooldown = nil
    if not meaningful then
        return
    end
    if not CanAnnounceEntry(entry) then
        return
    end
    if CA.Announce and CA.Announce.Ready then
        CA.Announce.Ready(entry.name, AnnounceOpts(entry))
    end
end

local function ScheduleWake(entry, duration)
    if type(duration) ~= "number" or duration <= 0 then
        return
    end
    if not (C_Timer and C_Timer.After) then
        return
    end
    local wakeAt = (GetTime and GetTime() or 0) + duration + 0.05
    entry.wakeAt = wakeAt
    local key = entry.key
    local gen = (entry.wakeGen or 0) + 1
    entry.wakeGen = gen
    C_Timer.After(duration + 0.05, function()
        local e = tracked[key]
        if not e or e.wakeGen ~= gen then
            return
        end
        Spells.EvaluateSpell(e.spellID, true)
    end)
end

function Spells.EvaluateSpell(spellID, fromWake)
    spellID = NormalizeSpellID(spellID)
    if not spellID then
        return
    end
    local key = TrackerKey(spellID)
    local entry = tracked[key]
    if not entry then
        return
    end

    if not entry.name or entry.name == "" or (type(entry.name) == "string" and entry.name:find("^Spell ", 1, true)) then
        entry.name = GetSpellName(spellID)
    end
    local cd = GetCooldownState(spellID)
    if not cd then
        return
    end

    -- Charge gained announcements (only for known chargers, or while pending).
    local charges
    if entry.lastCharges ~= nil or entry.pending or fromWake then
        charges = GetCharges(spellID)
    end
    if charges and charges.max and charges.max > 1 then
        if type(entry.lastCharges) == "number" and type(charges.current) == "number" then
            if charges.current > entry.lastCharges and CanAnnounceEntry(entry) then
                if CA.Announce and CA.Announce.Charge then
                    CA.Announce.Charge(entry.name, AnnounceOpts(entry))
                end
            end
        end
        entry.lastCharges = charges.current
        -- Fully charged and was pending → ready line once.
        if entry.pending and charges.current >= charges.max and not cd.isActive then
            OnBecameReady(entry)
            return
        end
    end

    if cd.isActive then
        if ShouldTrackDuration(spellID, cd.duration, cd.isOnGCD) then
            if not entry.pending then
                SetPending(entry, true)
                if type(cd.duration) == "number" then
                    entry.observedDuration = cd.duration
                    ScheduleWake(entry, cd.duration)
                else
                    -- Active CD with secret duration — still announce when it clears.
                    entry.sawSecretCooldown = true
                    local base = GetBaseCooldownSec(spellID)
                    if type(entry.observedDuration) ~= "number" then
                        if type(base) == "number" and base >= MinCooldownSec() then
                            entry.observedDuration = base
                            ScheduleWake(entry, base)
                        else
                            entry.observedDuration = MinCooldownSec()
                        end
                    end
                end
            elseif fromWake and type(cd.duration) == "number" then
                ScheduleWake(entry, cd.duration)
            elseif entry.pending and type(cd.duration) ~= "number" then
                entry.sawSecretCooldown = true
                local base = GetBaseCooldownSec(spellID)
                if type(entry.observedDuration) ~= "number" then
                    if type(base) == "number" and base >= MinCooldownSec() then
                        entry.observedDuration = base
                    else
                        entry.observedDuration = MinCooldownSec()
                    end
                end
            end
        end
        return
    end

    -- Not active.
    if entry.pending then
        OnBecameReady(entry)
    end
end

--- After a successful cast: if live cooldown data was secret or GCD-masked,
--- still watch spells whose book cooldown is long enough (Avenging Wrath).
local function NoteCastStarted(spellID)
    spellID = NormalizeSpellID(spellID)
    if not spellID then
        return
    end
    local entry = tracked[TrackerKey(spellID)]
    if not entry or entry.pending or IsPassive(spellID) then
        return
    end
    local base = GetBaseCooldownSec(spellID)
    local minSec = MinCooldownSec()
    if type(base) ~= "number" or base < minSec then
        return
    end
    SetPending(entry, true)
    entry.sawSecretCooldown = true
    if type(entry.observedDuration) ~= "number" or entry.observedDuration < minSec then
        entry.observedDuration = base
    end
    ScheduleWake(entry, base)
end

function Spells.PollPending()
    for _, entry in pairs(tracked) do
        if entry.pending then
            Spells.EvaluateSpell(entry.spellID, false)
        end
    end
end

function Spells.RefreshAll()
    for _, entry in pairs(tracked) do
        if IsEnabledKey(entry.key) then
            Spells.EvaluateSpell(entry.spellID, false)
        end
    end
end

--- Cheap combat path: only re-check spells already waiting to become ready.
function Spells.RefreshPending()
    Spells.PollPending()
end

local function ThrottledRefreshPending()
    local now = (GetTime and GetTime()) or 0
    if (now - lastPendingRefresh) < PENDING_REFRESH_THROTTLE then
        return
    end
    lastPendingRefresh = now
    Spells.RefreshPending()
end

--- Re-evaluate all enabled tracked spells (slow safety net for secret event IDs).
local function ThrottledRefreshAll()
    local now = (GetTime and GetTime()) or 0
    if (now - lastFullRefresh) < FULL_REFRESH_THROTTLE then
        return
    end
    lastFullRefresh = now
    Spells.RefreshAll()
end

local function SettingsFrameShown()
    return CA.Settings and CA.Settings.IsShown and CA.Settings.IsShown()
end

local function MaybeRefreshTrackers()
    if not (SettingsFrameShown() and CA.Settings.RefreshTrackers) then
        return
    end
    local now = (GetTime and GetTime()) or 0
    if (now - lastSettingsRefresh) < SETTINGS_REFRESH_THROTTLE then
        return
    end
    lastSettingsRefresh = now
    CA.Settings.RefreshTrackers()
end

local function AddSpell(spellID, source, skillLineName, categoryOverride)
    spellID = NormalizeSpellID(spellID)
    if not spellID then
        return false
    end
    if IsPassive(spellID) then
        return false
    end
    local key = TrackerKey(spellID)
    local entry = tracked[key]
    local spellName = GetSpellName(spellID)

    -- Spellbook map decides combat vs utility; overrides are only soft hints.
    local category = "utility"
    if CA.Categories and CA.Categories.ClassifySpell then
        category = CA.Categories.ClassifySpell(spellID, source, skillLineName, spellName) or "utility"
    elseif categoryOverride then
        category = categoryOverride
    end

    local meta = CA.Categories and CA.Categories.LookupSpellBook and CA.Categories.LookupSpellBook(spellID)
    local lineKind = meta and meta.lineKind or nil
    local lineName = skillLineName or (meta and meta.lineName) or nil
    if type(source) == "string" and source:find("^pet:") then
        lineKind = "pet"
        lineName = lineName or "Pet"
        category = "utility"
    elseif (type(source) == "string" and source:find("^racial:"))
        or (CA.Categories and CA.Categories.IsRacialSkillLineName and CA.Categories.IsRacialSkillLineName(skillLineName))
        or (CA.Racials and CA.Racials.IsRacialSpellID and CA.Racials.IsRacialSpellID(spellID))
    then
        lineKind = "racial"
        lineName = "Racial"
        category = "utility"
    end

    if entry then
        entry.sources[source or "bar"] = true
        entry.name = spellName or entry.name
        entry.skillLineName = lineName or entry.skillLineName
        if lineKind == "pet" then
            entry.lineKind = "pet"
            entry.category = "utility"
        elseif lineKind == "racial" then
            entry.lineKind = "racial"
            entry.skillLineName = "Racial"
            entry.category = "utility"
        else
            -- Don't let a later bar/general source downgrade an existing racial/pet tag.
            if entry.lineKind ~= "racial" and entry.lineKind ~= "pet" then
                entry.lineKind = lineKind or entry.lineKind
                entry.category = category
            end
        end
        return false
    end
    local charges = GetCharges(spellID)
    local lastCharges = nil
    if charges and charges.max and charges.max > 1 then
        lastCharges = charges.current
    end
    tracked[key] = {
        key = key,
        spellID = spellID,
        name = spellName,
        icon = GetSpellIcon(spellID),
        category = category,
        skillLineName = lineName,
        lineKind = lineKind,
        pending = false,
        wakeAt = nil,
        wakeGen = 0,
        observedDuration = nil,
        lastCharges = lastCharges,
        sources = { [source or "bar"] = true },
    }
    return true
end

local function IncludeAllowsSpell(spellID, source)
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if type(source) == "string" and source:find("^pet:") then
        return sv.includePetAbilities ~= false
    end
    local spellName = GetSpellName(spellID)
    local cat = "utility"
    if CA.Categories and CA.Categories.ClassifySpell then
        cat = CA.Categories.ClassifySpell(spellID, source, nil, spellName) or "utility"
    end
    local meta = CA.Categories and CA.Categories.LookupSpellBook and CA.Categories.LookupSpellBook(spellID)
    local lineKind = meta and meta.lineKind or nil
    if lineKind == "pet" then
        return sv.includePetAbilities ~= false
    end
    if lineKind == "racial"
        or (CA.Racials and CA.Racials.IsRacialSpellID and CA.Racials.IsRacialSpellID(spellID))
    then
        return sv.includeSpellbookRacials ~= false
    end
    if cat == "general" or lineKind == "general" then
        if CA.Categories and CA.Categories.IsTeleportName and CA.Categories.IsTeleportName(spellName) then
            return sv.includeTeleportItems ~= false or sv.includeSpellbookGeneral ~= false
        end
        return sv.includeSpellbookGeneral ~= false
    end
    -- Class / spec combat CDs and other class utilities.
    return sv.includeSpellbookAbilities ~= false
end

local function SpellHasWatchableCooldown(spellID)
    local minSec = MinCooldownSec()
    local base = GetBaseCooldownSec(spellID)
    if type(base) == "number" and base >= minSec then
        return true
    end
    local cd = GetCooldownState(spellID)
    if not cd then
        return false
    end
    return ShouldTrackDuration(spellID, cd.duration, cd.isOnGCD)
end

--- Begin watching a spell only after a successful cast (not because it is on a bar).
function Spells.WatchFromCast(spellID, source)
    spellID = NormalizeSpellID(spellID)
    if not spellID or IsPassive(spellID) then
        return
    end
    source = source or "used"

    local function afterCast()
        local id = NormalizeSpellID(spellID)
        if not id or IsPassive(id) then
            return
        end
        local key = TrackerKey(id)
        local entry = tracked[key]
        if entry then
            Spells.EvaluateSpell(id, false)
            NoteCastStarted(id)
            return
        end
        if not SpellHasWatchableCooldown(id) then
            return
        end
        if not IncludeAllowsSpell(id, source) then
            return
        end
        AddSpell(id, source)
        if CA.DB and CA.DB.MarkUsed then
            CA.DB.MarkUsed(key)
        end
        Spells.EvaluateSpell(id, false)
        NoteCastStarted(id)
        MaybeRefreshTrackers()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, afterCast)
        C_Timer.After(1.8, function()
            local id = NormalizeSpellID(spellID)
            if not id then
                return
            end
            local entry = tracked[TrackerKey(id)]
            if entry and entry.pending then
                return
            end
            afterCast()
        end)
    else
        afterCast()
    end
end

function Spells.RestoreUsed()
    if not (CA.DB and CA.DB.GetUsedSet) then
        return 0
    end
    local set = CA.DB.GetUsedSet()
    local added = 0
    for key in pairs(set) do
        if type(key) == "string" then
            local id = key:match("^spell:(%d+)$")
            id = id and tonumber(id)
            if id then
                local source = "used"
                if not IncludeAllowsSpell(id, source) then
                    -- skip
                elseif AddSpell(id, source) then
                    added = added + 1
                end
            end
        end
    end
    return added
end

local function RemoveTrackedSpell(entry)
    if not entry or not entry.key then
        return
    end
    if entry.pending then
        SetPending(entry, false)
    end
    tracked[entry.key] = nil
end

local function PruneSpellsByIncludes()
    local drop = {}
    for _, entry in pairs(tracked) do
        local source = "used"
        if entry.lineKind == "pet" then
            source = "pet:cast"
        elseif type(entry.sources) == "table" then
            for src in pairs(entry.sources) do
                if type(src) == "string" and src:find("^pet:") then
                    source = "pet:cast"
                    break
                end
            end
        end
        if not IncludeAllowsSpell(entry.spellID, source) then
            drop[#drop + 1] = entry
        end
    end
    for i = 1, #drop do
        RemoveTrackedSpell(drop[i])
    end
end

local function AddFlyout(flyoutID, source, skillLineName, categoryOverride)
    if type(flyoutID) ~= "number" or not GetFlyoutInfo or not GetFlyoutSlotInfo then
        return 0
    end
    local _, _, numSlots = SafeCall(GetFlyoutInfo, flyoutID)
    if type(numSlots) ~= "number" then
        return 0
    end
    local added = 0
    for i = 1, numSlots do
        local spellID, _override, isKnown = SafeCall(GetFlyoutSlotInfo, flyoutID, i)
        if isKnown and type(spellID) == "number"
            and AddSpell(spellID, source .. ":flyout:" .. tostring(i), skillLineName, categoryOverride)
        then
            added = added + 1
        end
    end
    return added
end

local function SpellFromActionSlot(slot)
    if C_ActionBar and C_ActionBar.GetSpell then
        local sid = SafeCall(C_ActionBar.GetSpell, slot)
        if type(sid) == "number" and sid > 0 then
            return "spell", sid
        end
    end
    if not GetActionInfo then
        return nil
    end
    local actionType, id = SafeCall(GetActionInfo, slot)
    if actionType == "spell" and type(id) == "number" then
        return "spell", id
    end
    if actionType == "flyout" and type(id) == "number" then
        return "flyout", id
    end
    if actionType == "macro" and type(id) == "number" and GetMacroSpell then
        local sid = SafeCall(GetMacroSpell, id)
        if type(sid) == "number" and sid > 0 then
            return "spell", sid
        end
    end
    return nil
end

local function ScanOneBarSlot(slot)
    local added = 0
    local has = true
    if HasAction then
        has = SafeCall(HasAction, slot) and true or false
    end
    if has then
        local kind, id = SpellFromActionSlot(slot)
        if kind == "spell" then
            if AddSpell(id, "action:" .. tostring(slot)) then
                added = 1
            end
        elseif kind == "flyout" then
            added = AddFlyout(id, "action:" .. tostring(slot))
        end
    end
    return added
end

function Spells.ScanBars()
    local added = 0
    local maxSlot = 180
    for slot = 1, maxSlot do
        added = added + ScanOneBarSlot(slot)
    end

    if GetNumShapeshiftForms and GetShapeshiftFormInfo then
        local n = SafeCall(GetNumShapeshiftForms) or 0
        for i = 1, n do
            local _, _, _, spellID = SafeCall(GetShapeshiftFormInfo, i)
            if type(spellID) == "number" and spellID > 0 and AddSpell(spellID, "stance:" .. tostring(i)) then
                added = added + 1
            end
        end
    end

    return added
end

--- Controllable pet / minion abilities (pet action bar + pet spellbook).
function Spells.ScanPetAbilities()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if sv.includePetAbilities == false then
        return 0
    end

    local added = 0
    local hasPet = UnitExists and SafeCall(UnitExists, "pet")
    local numPetSpells = 0
    if C_SpellBook and C_SpellBook.HasPetSpells then
        numPetSpells = SafeCall(C_SpellBook.HasPetSpells) or 0
    elseif HasPetSpells then
        numPetSpells = SafeCall(HasPetSpells) or 0
    end
    if not hasPet and (type(numPetSpells) ~= "number" or numPetSpells <= 0) then
        return 0
    end

    -- Pet action bar (Attack / specials / modes the player can control).
    local petSlots = NUM_PET_ACTION_SLOTS or 10
    if GetPetActionInfo then
        for i = 1, petSlots do
            local _, _, _, _, _, _, spellID = SafeCall(GetPetActionInfo, i)
            if type(spellID) == "number" and spellID > 0 then
                if AddSpell(spellID, "pet:bar:" .. tostring(i), "Pet") then
                    added = added + 1
                end
            end
        end
    end

    -- Pet spellbook bank (hunter pet abilities, warlock minion spells, etc.).
    local petBank = 1
    if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet ~= nil then
        petBank = Enum.SpellBookSpellBank.Pet
    end
    if C_SpellBook and C_SpellBook.GetSpellBookItemInfo and type(numPetSpells) == "number" and numPetSpells > 0 then
        local spellType = 1
        if Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell ~= nil then
            spellType = Enum.SpellBookItemType.Spell
        end
        for i = 1, numPetSpells do
            local info = SafeCall(C_SpellBook.GetSpellBookItemInfo, i, petBank)
            if type(info) == "table" and not info.isPassive then
                if info.itemType == spellType or info.spellID or info.actionID then
                    local sid = info.spellID or info.actionID
                    if type(sid) == "number" and sid > 0 and AddSpell(sid, "pet:book:" .. tostring(i), "Pet") then
                        added = added + 1
                    end
                end
            end
        end
    elseif GetSpellBookItemInfo and type(numPetSpells) == "number" and numPetSpells > 0 then
        for i = 1, numPetSpells do
            local skillType, id = SafeCall(GetSpellBookItemInfo, i, "pet")
            if (skillType == "SPELL" or skillType == "PETACTION") and type(id) == "number" and id > 0 then
                if AddSpell(id, "pet:book:" .. tostring(i), "Pet") then
                    added = added + 1
                end
            end
        end
    end

    return added
end

local function SkillLineScanKind(skillLineInfo)
    if CA.Categories and CA.Categories.ClassifySkillLineInfo then
        local lineKind = CA.Categories.ClassifySkillLineInfo(skillLineInfo)
        if lineKind == "spec" or lineKind == "class" then
            return "ability"
        end
        if lineKind == "racial" then
            return "racial"
        end
        if lineKind == "general" or lineKind == "profession" or lineKind == "guild" then
            return "general"
        end
    end
    return "ability"
end

local function SpellBookItemSubName(slot, bank, info)
    if type(info) == "table" and type(info.subName) == "string" and info.subName ~= "" then
        return info.subName
    end
    if C_SpellBook and C_SpellBook.GetSpellBookItemName then
        local _, sub = SafeCall(C_SpellBook.GetSpellBookItemName, slot, bank)
        if type(sub) == "string" and sub ~= "" then
            return sub
        end
    end
    return nil
end

function Spells.ScanSpellbook()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    local wantAbilities = sv.includeSpellbookAbilities ~= false
    local wantRacials = sv.includeSpellbookRacials ~= false
    local wantGeneral = sv.includeSpellbookGeneral ~= false
    if not wantAbilities and not wantRacials and not wantGeneral then
        return 0
    end

    -- Classic / older clients: GetNumSpellTabs + GetSpellBookItemInfo.
    if not (CA.Compat and CA.Compat.HasModernSpellBook and CA.Compat.HasModernSpellBook()) then
        if not (GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo) then
            return 0
        end
        local added = 0
        local numTabs = SafeCall(GetNumSpellTabs) or 0
        for t = 1, numTabs do
            local name, _, offset, numSpells = SafeCall(GetSpellTabInfo, t)
            if type(offset) == "number" and type(numSpells) == "number" and numSpells > 0 then
                local skillName = name
                local entryKind = SkillLineScanKind({ name = skillName })
                local allow = (entryKind == "ability" and wantAbilities)
                    or (entryKind == "racial" and wantRacials)
                    or (entryKind == "general" and (wantGeneral or wantRacials))
                if allow then
                    for j = offset + 1, offset + numSpells do
                        local skillType, id = SafeCall(GetSpellBookItemInfo, j, BOOKTYPE_SPELL or "spell")
                        if skillType == "SPELL" and type(id) == "number" and id > 0 then
                            local categoryOverride = (entryKind == "racial" and "utility")
                                or (entryKind == "general" and "general")
                                or nil
                            if AddSpell(id, "book:" .. tostring(j), skillName, categoryOverride) then
                                added = added + 1
                            end
                        elseif skillType == "FLYOUT" and type(id) == "number" then
                            added = added + AddFlyout(id, "book:" .. tostring(j), skillName, nil)
                        end
                    end
                end
            end
        end
        return added
    end

    if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and C_SpellBook.GetSpellBookSkillLineInfo and C_SpellBook.GetSpellBookItemInfo) then
        return 0
    end

    local playerBank = 0
    if Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player ~= nil then
        playerBank = Enum.SpellBookSpellBank.Player
    end
    local spellType = 1
    if Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell ~= nil then
        spellType = Enum.SpellBookItemType.Spell
    end
    local flyoutType = 4
    if Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Flyout ~= nil then
        flyoutType = Enum.SpellBookItemType.Flyout
    end

    local added = 0
    local numLines = SafeCall(C_SpellBook.GetNumSpellBookSkillLines) or 0
    for i = 1, numLines do
        local skillLineInfo = SafeCall(C_SpellBook.GetSpellBookSkillLineInfo, i)
        if type(skillLineInfo) == "table" then
            local kind = SkillLineScanKind(skillLineInfo)
            -- Racial actives live inside the General tab on modern clients.
            local allow = (kind == "racial" and wantRacials)
                or (kind == "general" and (wantGeneral or wantRacials))
                or (kind == "ability" and wantAbilities)
            if allow then
                local offset = skillLineInfo.itemIndexOffset or 0
                local numSlots = skillLineInfo.numSpellBookItems or 0
                local lineName = skillLineInfo.name
                for j = offset + 1, offset + numSlots do
                    local info = SafeCall(C_SpellBook.GetSpellBookItemInfo, j, playerBank)
                    if type(info) == "table" and not info.isPassive and not info.isOffSpec then
                        local subName = SpellBookItemSubName(j, playerBank, info)
                        local sid = info.spellID or info.actionID
                        local isRacial = (kind == "racial")
                            or (CA.Categories and CA.Categories.IsRacialSubName and CA.Categories.IsRacialSubName(subName))
                            or (type(sid) == "number" and CA.Racials and CA.Racials.IsRacialSpellID and CA.Racials.IsRacialSpellID(sid))
                        local entryKind = isRacial and "racial" or kind
                        if entryKind == "racial" and not wantRacials then
                            -- skip
                        elseif entryKind == "general" and not wantGeneral then
                            -- skip (opened General tab only to harvest racials)
                        else
                            local sourcePrefix = entryKind .. ":" .. tostring(i)
                            local skillName = isRacial and "Racial" or lineName
                            local categoryOverride = "ability"
                            if entryKind == "racial" then
                                categoryOverride = "utility"
                            elseif entryKind == "general" then
                                categoryOverride = "general"
                            end
                            if info.itemType == spellType then
                                if type(sid) == "number" then
                                    local wasNew = AddSpell(sid, sourcePrefix .. ":" .. tostring(j), skillName, categoryOverride)
                                    if wasNew then
                                        added = added + 1
                                    end
                                    local entry = tracked[TrackerKey(sid)]
                                    if entry and isRacial then
                                        entry.lineKind = "racial"
                                        entry.skillLineName = "Racial"
                                        entry.category = "utility"
                                    end
                                end
                            elseif info.itemType == flyoutType and type(info.actionID) == "number" then
                                added = added + AddFlyout(info.actionID, sourcePrefix .. ":" .. tostring(j), skillName, categoryOverride)
                            end
                        end
                    end
                end
            end
        end
    end
    return added
end

local function PlayerKnowsTeleportSpell(spellID)
    if CA.Teleports and CA.Teleports.PlayerKnowsSpell then
        return CA.Teleports.PlayerKnowsSpell(spellID)
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        return SafeCall(C_SpellBook.IsSpellKnown, spellID) and true or false
    end
    return false
end

--- Probe curated teleport spell IDs the player actually knows.
function Spells.ScanTeleportSpells()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if sv.includeTeleportItems == false then
        return 0
    end
    local ids = CA.Teleports and CA.Teleports.SPELL_IDS
    if type(ids) ~= "table" then
        return 0
    end
    local added = 0
    for i = 1, #ids do
        local spellID = ids[i]
        if PlayerKnowsTeleportSpell(spellID) then
            if AddSpell(spellID, "teleport:" .. tostring(spellID), "Teleport", "general") then
                added = added + 1
            else
                local entry = tracked[TrackerKey(spellID)]
                if entry then
                    entry.category = "general"
                    entry.sources["teleport:" .. tostring(spellID)] = true
                end
            end
        end
    end
    return added
end

--- Probe curated racial spell IDs for the current race (General-tab racials).
function Spells.ScanRacialSpells()
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    if sv.includeSpellbookRacials == false then
        return 0
    end
    if not (CA.Racials and CA.Racials.GetKnownSpellIDs) then
        return 0
    end
    local ids = CA.Racials.GetKnownSpellIDs()
    local added = 0
    for i = 1, #ids do
        local spellID = ids[i]
        if AddSpell(spellID, "racial:known:" .. tostring(spellID), "Racial", "utility") then
            added = added + 1
        end
        local entry = tracked[TrackerKey(spellID)]
        if entry then
            entry.lineKind = "racial"
            entry.skillLineName = "Racial"
            entry.category = "utility"
            entry.sources["racial:known:" .. tostring(spellID)] = true
        end
    end
    return added
end

--- Rebuild spellbook metadata and restore spells/items this character has used.
--- Does not watch unused bar / spellbook / toy-box entries.
function Spells.ScanAll(opts)
    opts = opts or {}
    local now = (GetTime and GetTime()) or 0
    if CA.Categories and CA.Categories.RebuildSpellBookMap then
        CA.Categories.RebuildSpellBookMap()
        lastMapRebuild = now
        for _, entry in pairs(tracked) do
            entry.group = nil
        end
    end
    PruneSpellsByIncludes()
    local a = Spells.RestoreUsed()
    local c = 0
    if CA.Items and CA.Items.RestoreUsed then
        c = CA.Items.RestoreUsed() or 0
    elseif CA.Items and CA.Items.ScanAll then
        c = CA.Items.ScanAll(opts) or 0
    end
    return (a or 0) + (c or 0)
end

function Spells.ClearDiscovery()
    if pollTicker then
        pollTicker:Cancel()
        pollTicker = nil
    end
    wipe(tracked)
    wipe(baseSpellCache)
    wipe(baseCdCache)
    wipe(dirtySlots)
    dirtySlotCount = 0
    pendingCount = 0
    if CA.Items and CA.Items.ClearDiscovery then
        CA.Items.ClearDiscovery()
    end
    if CA.Buffs and CA.Buffs.Clear then
        CA.Buffs.Clear()
    end
end

function Spells.RebuildDiscovery()
    if CA.DB and CA.DB.ClearUsed then
        CA.DB.ClearUsed()
    end
    Spells.ClearDiscovery()
    local added = Spells.ScanAll({ heavy = true })
    Spells.RefreshPending()
    if CA.Items and CA.Items.RefreshPending then
        CA.Items.RefreshPending()
    end
    if CA.Buffs and CA.Buffs.Resync then
        CA.Buffs.Resync()
    end
    MaybeRefreshTrackers()
    return added
end

local function RunRescanNow()
    local inCombat = InCombatLockdown and InCombatLockdown()
    local doHeavy = rescanHeavy and not inCombat
    if rescanHeavy and inCombat then
        -- Keep heavy flag; PLAYER_REGEN_ENABLED will flush after combat.
    else
        rescanHeavy = false
    end
    rescanPending = false
    Spells.ScanAll({ heavy = doHeavy == true })
    Spells.RefreshPending()
    if CA.Items and CA.Items.RefreshPending then
        CA.Items.RefreshPending()
    end
    if CA.Buffs and CA.Buffs.Resync then
        CA.Buffs.Resync()
    end
    MaybeRefreshTrackers()
end

--- Debounced restore + spellbook map rebuild. heavy is ignored (no toy-box walk).
function Spells.RequestRescan(heavy)
    if heavy then
        rescanHeavy = true
    end
    if rescanPending then
        return
    end
    rescanPending = true
    local delay = RESCAN_SEC
    if InCombatLockdown and InCombatLockdown() then
        delay = RESCAN_SEC_COMBAT
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, RunRescanNow)
    else
        RunRescanNow()
    end
end

function Spells.GetTrackedList(filter)
    local sv = CA.DB and CA.DB.Get and CA.DB.Get() or {}
    filter = filter or sv.cooldownListFilter or "all"
    local list = {}
    for _, entry in pairs(tracked) do
        if not IsPassive(entry.spellID) then
        local name = entry.name or GetSpellName(entry.spellID)
        entry.name = name
        if not entry.icon then
            entry.icon = GetSpellIcon(entry.spellID)
        end
        local cat = entry.category or "ability"
        local major = IsMajorEntry(entry)
        if not entry.group then
            local sourceHint = nil
            if type(entry.sources) == "table" then
                for src in pairs(entry.sources) do
                    if type(src) == "string" and (
                        src:find("^pet:")
                        or src:find("^stance:")
                        or src:find("^racial:")
                        or src:find("^teleport:")
                        or src:find("^general:")
                    ) then
                        sourceHint = src
                        break
                    end
                end
            end
            if CA.Categories and CA.Categories.ClassifySpell then
                cat = CA.Categories.ClassifySpell(entry.spellID, sourceHint, entry.skillLineName, name) or cat
                entry.category = cat
            end
            local meta = CA.Categories and CA.Categories.LookupSpellBook and CA.Categories.LookupSpellBook(entry.spellID)
            entry.skillLineName = entry.skillLineName or (meta and meta.lineName) or nil
            entry.lineKind = entry.lineKind or (meta and meta.lineKind) or nil
            local rowTmp = {
                key = entry.key,
                spellID = entry.spellID,
                name = name,
                itemID = nil,
                category = cat,
                skillLineName = entry.skillLineName,
                lineKind = entry.lineKind,
                kind = (entry.lineKind == "pet" and "pet")
                    or (entry.lineKind == "racial" and "racial")
                    or (CA.Racials and CA.Racials.IsRacialSpellID and CA.Racials.IsRacialSpellID(entry.spellID) and "racial")
                    or (entry.sources and entry.sources["teleport:" .. tostring(entry.spellID)] and "teleport")
                    or nil,
                sources = entry.sources,
            }
            if CA.Categories and CA.Categories.ResolveGroup then
                entry.group = CA.Categories.ResolveGroup(rowTmp)
            else
                entry.group = "other"
            end
        end
        local row = {
            key = entry.key,
            spellID = entry.spellID,
            name = name,
            icon = entry.icon,
            enabled = IsEnabledKey(entry.key),
            pending = entry.pending and true or false,
            category = entry.category or cat,
            categoryLabel = (CA.Categories and CA.Categories.Label and CA.Categories.Label(entry.category or cat)) or cat,
            major = major,
            observedDuration = entry.observedDuration,
            skillLineName = entry.skillLineName,
            lineKind = entry.lineKind,
            kind = (entry.lineKind == "pet" and "pet")
                or (entry.lineKind == "racial" and "racial")
                or nil,
            sources = entry.sources,
            group = entry.group or "other",
            groupLabel = (CA.Categories and CA.Categories.GroupLabel and CA.Categories.GroupLabel(entry.group)) or "Other",
        }
        if row.group == "teleport"
            and CA.Teleports and CA.Teleports.PlayerHasAccess
            and not CA.Teleports.PlayerHasAccess(row)
        then
            -- skip
        elseif filter == "all" or filter == row.group then
            list[#list + 1] = row
        end
        end -- not passive
    end
    return list
end

--- Name to speak on buff fade, if this spell/aura is enabled for tracking.
function Spells.GetFadeAnnounceName(spellID, auraName)
    spellID = NormalizeSpellID(spellID)
    if spellID then
        local entry = tracked[TrackerKey(spellID)]
        if entry and not IsPassive(entry.spellID) and CanAnnounceEntry(entry) then
            return entry.name or GetSpellName(entry.spellID)
        end
    end
    if type(auraName) == "string" and auraName ~= "" then
        local lower = auraName:lower()
        for _, entry in pairs(tracked) do
            if not IsPassive(entry.spellID) and CanAnnounceEntry(entry) then
                local n = entry.name or GetSpellName(entry.spellID)
                if type(n) == "string" and n:lower() == lower then
                    return n
                end
            end
        end
    end
    return nil
end

function Spells.GetReadyNames()
    local names = {}
    local minSec = MinCooldownSec()
    for _, entry in pairs(tracked) do
        if not IsPassive(entry.spellID) and CanAnnounceEntry(entry) then
            local cd = GetCooldownState(entry.spellID)
            if cd and not cd.isActive then
                local charges = GetCharges(entry.spellID)
                local meaningful = (type(entry.observedDuration) == "number" and entry.observedDuration >= minSec)
                    or entry.sawSecretCooldown == true
                if not meaningful and charges and type(charges.max) == "number" and charges.max > 1 then
                    meaningful = true
                end
                -- Known major/tracked spells with no observed CD yet: still list if previously used.
                if not meaningful and type(entry.observedDuration) == "number" then
                    meaningful = entry.observedDuration >= minSec
                end
                if meaningful then
                    names[#names + 1] = entry.name or GetSpellName(entry.spellID)
                end
            end
        end
    end
    table.sort(names, function(a, b)
        return tostring(a):lower() < tostring(b):lower()
    end)
    return names
end

function Spells.FindByNameOrID(query)
    if type(query) ~= "string" or query == "" then
        return nil
    end
    local asNumber = tonumber(query)
    if asNumber then
        local key = TrackerKey(NormalizeSpellID(asNumber) or asNumber)
        return tracked[key]
    end
    local q = query:lower()
    local exact, partial
    for _, entry in pairs(tracked) do
        local name = (entry.name or ""):lower()
        if name == q then
            exact = entry
            break
        end
        if not partial and name:find(q, 1, true) then
            partial = entry
        end
    end
    return exact or partial
end

function Spells.SetEnabled(query, enabled)
    local entry = Spells.FindByNameOrID(query)
    if not entry then
        return nil, "notfound"
    end
    if CA.DB and CA.DB.SetTrackerEnabled then
        CA.DB.SetTrackerEnabled(entry.key, enabled and true or false)
    end
    return entry, "ok"
end

local eventFrame = CreateFrame("Frame")
SafeRegisterEvent(eventFrame, "PLAYER_LOGIN")
SafeRegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
SafeRegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
SafeRegisterEvent(eventFrame, "SPELLS_CHANGED")
SafeRegisterEvent(eventFrame, "ACTIONBAR_SLOT_CHANGED")
SafeRegisterEvent(eventFrame, "ACTIONBAR_PAGE_CHANGED")
SafeRegisterEvent(eventFrame, "UPDATE_BONUS_ACTIONBAR")
SafeRegisterEvent(eventFrame, "UPDATE_VEHICLE_ACTIONBAR")
SafeRegisterEvent(eventFrame, "UPDATE_OVERRIDE_ACTIONBAR")
SafeRegisterEvent(eventFrame, "PET_BAR_UPDATE")
SafeRegisterEvent(eventFrame, "UNIT_PET")
SafeRegisterEvent(eventFrame, "PET_BAR_UPDATE_COOLDOWN")
SafeRegisterEvent(eventFrame, "UPDATE_SHAPESHIFT_FORM")
SafeRegisterEvent(eventFrame, "UPDATE_SHAPESHIFT_FORMS")
SafeRegisterEvent(eventFrame, "PLAYER_SPECIALIZATION_CHANGED") -- retail; ignored on Classic
SafeRegisterEvent(eventFrame, "SPELL_UPDATE_COOLDOWN")
SafeRegisterEvent(eventFrame, "SPELL_UPDATE_CHARGES")
SafeRegisterUnitEvent(eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player", "pet")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_REGEN_ENABLED" then
        if rescanHeavy then
            Spells.RequestRescan(true)
        end
        -- Cooldown numbers often become readable after combat.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                Spells.RefreshAll()
            end)
        else
            Spells.RefreshAll()
        end
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        if unit == nil or unit == "player" then
            if C_Timer and C_Timer.After then
                C_Timer.After(0.75, function()
                    Spells.RequestRescan(false)
                end)
            else
                Spells.RequestRescan(false)
            end
        end
        return
    end

    if event == "UNIT_PET" then
        local unit = ...
        if unit == "player" then
            Spells.RequestRescan(false)
        end
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Spells.RequestRescan(true)
        return
    end

    if event == "SPELLS_CHANGED"
        or event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS"
    then
        -- Spellbook metadata only; do not add unused spells.
        Spells.RequestRescan(false)
        return
    end

    if event == "ACTIONBAR_SLOT_CHANGED"
        or event == "ACTIONBAR_PAGE_CHANGED"
        or event == "UPDATE_BONUS_ACTIONBAR" or event == "UPDATE_VEHICLE_ACTIONBAR"
        or event == "UPDATE_OVERRIDE_ACTIONBAR" or event == "PET_BAR_UPDATE"
    then
        -- Bars are "available to cast," not used. Do not start watching from bar contents.
        return
    end

    if event == "PET_BAR_UPDATE_COOLDOWN" then
        ThrottledRefreshPending()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unitTarget, _, spellID = ...
        if unitTarget == "player" or unitTarget == "pet" then
            local fromItem = false
            if unitTarget == "player" and CA.Items and CA.Items.OnPlayerCastSucceeded then
                local ok, handled = pcall(CA.Items.OnPlayerCastSucceeded, spellID)
                fromItem = ok and handled and true or false
            end
            if (not fromItem) and CanUseNumber(spellID) then
                local src = (unitTarget == "pet") and "pet:cast" or "used"
                pcall(Spells.WatchFromCast, spellID, src)
            end
        end
        return
    end

    if event == "SPELL_UPDATE_COOLDOWN" then
        local spellID, baseSpellID = ...
        -- Midnight often delivers secret spell IDs — never index/compare them raw.
        if CanUseNumber(spellID) then
            pcall(Spells.EvaluateSpell, spellID, false)
        end
        if CanUseNumber(baseSpellID) and (not CanUseNumber(spellID) or baseSpellID ~= spellID) then
            pcall(Spells.EvaluateSpell, baseSpellID, false)
        end
        -- Pending-only is cheap. Full scan is a slow safety net for secret IDs.
        ThrottledRefreshPending()
        ThrottledRefreshAll()
        return
    end

    if event == "SPELL_UPDATE_CHARGES" then
        local spellID = ...
        if CanUseNumber(spellID) then
            pcall(Spells.EvaluateSpell, spellID, false)
        end
        ThrottledRefreshPending()
        return
    end
end)
