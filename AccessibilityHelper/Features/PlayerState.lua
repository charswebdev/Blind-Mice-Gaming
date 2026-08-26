--[[
  Accessibility Helper — player state announcements (Phase 7)
  Transition TTS for follow, mount, combat, death, stuck, and more.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.PlayerState = AH.PlayerState or {}
local PS = AH.PlayerState

local readyAt = 0
local last = {}
local stuck = {
    x = nil,
    y = nil,
    since = nil,
    announced = false,
}

local POLL = 0.75
local STUCK_SEC = 2.5
local STUCK_EPS = 0.5 -- yards-ish from UnitPosition; map units vary — also use GetUnitSpeed

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function On(key)
    local sv = DB()
    return sv[key] ~= false
end

local function Say(msg)
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_STATUS)
    else
        print("|cff66ccff[Helper]|r " .. tostring(msg))
    end
end

local VITAL_KEYS = {
    stateHealthLow = true,
    stateBreath = true,
    stateFatigue = true,
    stateDead = true,
    stateGhost = true,
    stateCombat = true,
    stateResurrected = true,
}

local function Announce(key, msg)
    if not On(key) then
        return
    end
    if VITAL_KEYS[key] and AH.Alerts and AH.Alerts.Announce then
        AH.Alerts.Announce("vital", msg, AH.Speech and AH.Speech.PRIORITY_STATUS, key)
        return
    end
    Say(msg)
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

local function CanUseNumber(v)
    if AH.Compat and AH.Compat.CanUseNumber then
        return AH.Compat.CanUseNumber(v)
    end
    return type(v) == "number"
end

-- Follow announces (Part 2 A+E / BlindAssist-style):
-- Shared 0.2s schedule: END waits; BEGIN cancels pending stop.
-- A: follow session + silent same-person resume (including short grace after confirmed stop).
-- E: compare raw AUTOFOLLOW_BEGIN arg (BlindAssist) and display name for identity.
local lastFollowName = nil
local lastFollowArg = nil -- raw BEGIN payload (unit token or name)
local followSessionActive = false
local followResumeUntil = 0
local followGraceGen = 0
local lastFollowAction = nil -- "BEGIN" | "END" | nil
local followSoundPending = false
local followSoundGen = 0
local FOLLOW_END_DELAY = 0.2
local FOLLOW_SESSION_GRACE = 2.5

local function FollowNow()
    return (GetTime and GetTime()) or 0
end

local function FollowInVehicle()
    if UnitInVehicle then
        local ok, v = pcall(UnitInVehicle, "player")
        if ok and v then return true end
    end
    if UnitUsingVehicle then
        local ok, v = pcall(UnitUsingVehicle, "player")
        if ok and v then return true end
    end
    return false
end

--- True if s looks like a UnitId token rather than a character name.
local function LooksLikeUnitToken(s)
    if type(s) ~= "string" or s == "" then
        return false
    end
    local lower = string.lower(s)
    if lower == "target" or lower == "focus" or lower == "player" or lower == "pet"
        or lower == "followtarget" or lower == "mouseover" or lower == "npc" or lower == "vehicle"
    then
        return true
    end
    if lower:match("^party%d+$") or lower:match("^raid%d+$") or lower:match("^nameplate%d+$")
        or lower:match("^arena%d+$") or lower:match("^boss%d+$")
    then
        return true
    end
    return false
end

local function NamesEqual(a, b)
    if type(a) ~= "string" or type(b) ~= "string" or a == "" or b == "" then
        return false
    end
    return string.lower(a) == string.lower(b)
end

--- Same follow target: BlindAssist raw arg match, or resolved display name match.
local function SameFollowTarget(arg, name)
    if type(arg) == "string" and arg ~= "" and NamesEqual(lastFollowArg, arg) then
        return true
    end
    if type(name) == "string" and name ~= "" and NamesEqual(lastFollowName, name) then
        return true
    end
    return false
end

--- Resolve a display name from AUTOFOLLOW_BEGIN arg (name or UnitId) or current follow target.
local function ResolveFollowName(arg)
    if type(arg) == "string" and arg ~= "" then
        if UnitExists and UnitExists(arg) and UnitName then
            local n = SafeCall(UnitName, arg)
            if type(n) == "string" and n ~= "" then
                return n
            end
        end
        if not LooksLikeUnitToken(arg) then
            return arg
        end
    end
    if UnitExists and UnitExists("followtarget") and UnitName then
        local n = SafeCall(UnitName, "followtarget")
        if type(n) == "string" and n ~= "" then
            return n
        end
    end
    if C_PlayerInfo and C_PlayerInfo.GetFollowTargetGUID and GetPlayerInfoByGUID then
        local ok, guid = pcall(C_PlayerInfo.GetFollowTargetGUID)
        if ok and type(guid) == "string" and guid ~= "" then
            local ok2, _, _, _, _, _, name = pcall(GetPlayerInfoByGUID, guid)
            if ok2 and type(name) == "string" and name ~= "" then
                return name
            end
        end
    end
    if type(lastFollowName) == "string" and lastFollowName ~= "" then
        return lastFollowName
    end
    return nil
end

local function RememberFollowIdentity(arg, name)
    if type(arg) == "string" and arg ~= "" then
        lastFollowArg = arg
    end
    if type(name) == "string" and name ~= "" then
        lastFollowName = name
    end
end

local function ClearFollowSoundSchedule()
    followSoundPending = false
    followSoundGen = followSoundGen + 1
end

--- Confirmed unfollow (END not cancelled by BEGIN within delay).
local function DoFollowStop(justStarted)
    followSoundPending = false
    if justStarted then
        return
    end
    local name = lastFollowName
    followSessionActive = false
    last.stateFollow = false
    lastFollowAction = nil
    -- Keep identity briefly so a quick auto-BEGIN for the same person stays silent.
    followGraceGen = followGraceGen + 1
    local myGrace = followGraceGen
    followResumeUntil = FollowNow() + FOLLOW_SESSION_GRACE
    if C_Timer and C_Timer.After then
        C_Timer.After(FOLLOW_SESSION_GRACE, function()
            if myGrace ~= followGraceGen then
                return
            end
            if followSessionActive then
                return
            end
            lastFollowArg = nil
            lastFollowName = nil
            followResumeUntil = 0
        end)
    end
    if not On("stateFollow") then
        return
    end
    if name then
        Say("Stopped following " .. name .. ".")
    else
        Say("Stopped following.")
    end
end

--- Start / resume follow. Same target after cancelled END or within session grace = silent.
local function DoFollowStart(followerArg, justStopped)
    followSoundPending = false
    local name = ResolveFollowName(followerArg)
    local same = SameFollowTarget(followerArg, name)
    local inGrace = FollowNow() < followResumeUntil

    if same and (justStopped or followSessionActive or inGrace) then
        RememberFollowIdentity(followerArg, name)
        followSessionActive = true
        last.stateFollow = true
        followResumeUntil = 0
        followGraceGen = followGraceGen + 1 -- cancel grace clear
        return
    end

    RememberFollowIdentity(followerArg, name)
    followSessionActive = true
    last.stateFollow = true
    followResumeUntil = 0
    followGraceGen = followGraceGen + 1
    if not On("stateFollow") then
        return
    end
    if lastFollowName then
        Say("Following " .. lastFollowName .. ".")
    else
        Say("Following.")
    end
end

local function OnAutoFollowBegin(followerArg)
    if FollowInVehicle() then
        return
    end
    local justStopped = followSoundPending
    ClearFollowSoundSchedule()
    local gen = followSoundGen
    followSoundPending = true
    lastFollowAction = "BEGIN"
    local function fire()
        if gen ~= followSoundGen then
            return
        end
        DoFollowStart(followerArg, justStopped)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, fire)
    else
        fire()
    end
end

local function OnAutoFollowEnd()
    if FollowInVehicle() then
        return
    end
    if followSoundPending and lastFollowAction == "END" then
        return
    end
    local justStarted = followSoundPending
    ClearFollowSoundSchedule()
    local gen = followSoundGen
    followSoundPending = true
    lastFollowAction = "END"
    local nameSnapshot = lastFollowName
    local argSnapshot = lastFollowArg
    local function fire()
        if gen ~= followSoundGen then
            return
        end
        if not lastFollowName then
            lastFollowName = nameSnapshot
        end
        if not lastFollowArg then
            lastFollowArg = argSnapshot
        end
        DoFollowStop(justStarted)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(FOLLOW_END_DELAY, fire)
    else
        fire()
    end
end

local function ResetFollowState()
    ClearFollowSoundSchedule()
    lastFollowName = nil
    lastFollowArg = nil
    followSessionActive = false
    followResumeUntil = 0
    followGraceGen = followGraceGen + 1
    lastFollowAction = nil
    last.stateFollow = false
end

local function IsFlyingNow()
    local api = _G.IsFlying
    if api then
        local v = SafeCall(api)
        return v and true or false
    end
    return false
end

local function IsMountedNow()
    if IsMounted then
        return SafeCall(IsMounted) and true or false
    end
    return false
end

local function IsSwimmingNow()
    if IsSwimming then
        return SafeCall(IsSwimming) and true or false
    end
    return false
end

local function IsIndoorsNow()
    if IsIndoors then
        return SafeCall(IsIndoors) and true or false
    end
    return false
end

local function IsRestingNow()
    if IsResting then
        return SafeCall(IsResting) and true or false
    end
    return false
end

local function IsOnTaxiNow()
    if UnitOnTaxi then
        return SafeCall(UnitOnTaxi, "player") and true or false
    end
    return false
end

local function IsInVehicleNow()
    if UnitInVehicle then
        return SafeCall(UnitInVehicle, "player") and true or false
    end
    if UnitUsingVehicle then
        return SafeCall(UnitUsingVehicle, "player") and true or false
    end
    return false
end

local function IsFallingNow()
    if IsFalling then
        return SafeCall(IsFalling) and true or false
    end
    return false
end

local function IsAFKNow()
    if UnitIsAFK then
        return SafeCall(UnitIsAFK, "player") and true or false
    end
    return false
end

local function IsPvPFlagged()
    if UnitIsPVP then
        return SafeCall(UnitIsPVP, "player") and true or false
    end
    return false
end

local function IsStealthedNow()
    if IsStealthed then
        return SafeCall(IsStealthed) and true or false
    end
    return false
end

local function HasPet()
    if UnitExists("pet") then
        return UnitExists("pet") and true or false
    end
    return false
end

local function InCombatNow()
    if UnitAffectingCombat then
        return SafeCall(UnitAffectingCombat, "player") and true or false
    end
    return false
end

local function DeathState()
    -- "alive" | "dead" | "ghost"
    if UnitIsGhost and SafeCall(UnitIsGhost, "player") then
        return "ghost"
    end
    if UnitIsDead and SafeCall(UnitIsDead, "player") then
        return "dead"
    end
    if UnitIsDeadOrGhost and SafeCall(UnitIsDeadOrGhost, "player") then
        return "dead"
    end
    return "alive"
end

local function ShapeshiftLabel()
    if not GetShapeshiftForm then
        return nil
    end
    local form = SafeCall(GetShapeshiftForm)
    if not form or form <= 0 or not GetShapeshiftFormInfo then
        return nil
    end
    local ok, a, b, c, d = pcall(GetShapeshiftFormInfo, form)
    if not ok then
        return nil
    end
    -- Classic: texture, name, isActive, isCastable [, spellID]
    -- Retail: texture, isActive, isCastable, spellID
    local name, spellID
    if type(b) == "string" then
        name = b
        spellID = d
    else
        spellID = c or d
    end
    if type(name) == "string" and name ~= "" then
        return name
    end
    if type(spellID) == "number" and spellID > 0 then
        if C_Spell and C_Spell.GetSpellName then
            local sn = SafeCall(C_Spell.GetSpellName, spellID)
            if type(sn) == "string" and sn ~= "" then
                return sn
            end
        end
        if GetSpellInfo then
            local sn = SafeCall(GetSpellInfo, spellID)
            if type(sn) == "string" and sn ~= "" then
                return sn
            end
        end
    end
    return "Form " .. tostring(form)
end

local function InInstanceNow()
    if IsInInstance then
        local inInst = SafeCall(IsInInstance)
        return inInst and true or false
    end
    return false
end

local function InGroupNow()
    if IsInGroup then
        return SafeCall(IsInGroup) and true or false
    end
    if GetNumGroupMembers then
        local n = SafeCall(GetNumGroupMembers) or 0
        return n > 0
    end
    return false
end

local function BreathLow()
    -- Mirror timer: GetMirrorTimerProgress("BREATH") — remaining ms, negative when active
    if GetMirrorTimerInfo then
        for i = 1, 3 do
            local ok2, tname, val, mx, sc, pa, lab = pcall(GetMirrorTimerInfo, i)
            if ok2 and tname == "BREATH" then
                if CanUseNumber(val) and CanUseNumber(mx) and mx > 0 then
                    local pct = val / mx
                    if CanUseNumber(pct) and sc and CanUseNumber(sc) and sc < 0 then
                        -- draining
                        return pct < 0.35
                    end
                end
            end
        end
    end
    return false
end

local function FatigueActive()
    if GetMirrorTimerInfo then
        for i = 1, 3 do
            local ok, tname = pcall(GetMirrorTimerInfo, i)
            if ok and tname == "EXHAUSTION" then
                return true
            end
            if ok and tname == "FATIGUE" then
                return true
            end
        end
    end
    return false
end

local function PlayerMoving()
    if GetUnitSpeed then
        local speed = SafeCall(GetUnitSpeed, "player")
        -- Midnight: speed may be a secret value — cannot compare while tainted.
        if CanUseNumber(speed) then
            return speed > 0
        end
        return false
    end
    return false
end

local function PlayerPos()
    if UnitPosition then
        local y, x = SafeCall(UnitPosition, "player")
        if CanUseNumber(x) and CanUseNumber(y) then
            return x, y
        end
    end
    return nil, nil
end

local function CheckStuck(now)
    if not On("stateStuck") then
        stuck.announced = false
        stuck.since = nil
        return
    end
    -- Only while trying to move on foot (not flying/falling/swimming/taxi/vehicle/dead).
    if IsFlyingNow() or IsFallingNow() or IsSwimmingNow() or IsOnTaxiNow() or IsInVehicleNow() then
        stuck.since = nil
        stuck.announced = false
        return
    end
    if DeathState() ~= "alive" then
        stuck.since = nil
        stuck.announced = false
        return
    end
    if not PlayerMoving() then
        stuck.since = nil
        stuck.announced = false
        return
    end
    local x, y = PlayerPos()
    if not x or not y then
        return
    end
    if stuck.x and stuck.y then
        local dx = x - stuck.x
        local dy = y - stuck.y
        local dist2 = dx * dx + dy * dy
        if dist2 < (STUCK_EPS * STUCK_EPS) then
            if not stuck.since then
                stuck.since = now
            elseif (now - stuck.since) >= STUCK_SEC and not stuck.announced then
                stuck.announced = true
                Announce("stateStuck", "Stuck.")
            end
        else
            stuck.since = now
            stuck.announced = false
        end
    else
        stuck.since = now
        stuck.announced = false
    end
    stuck.x, stuck.y = x, y
end

local function DiffBool(key, cur, onMsg, offMsg)
    local prev = last[key]
    last[key] = cur
    if prev == nil then
        return
    end
    if prev == cur then
        return
    end
    if cur then
        Announce(key, onMsg)
    else
        Announce(key, offMsg)
    end
end

local HEALTH_LOW_PCT = 35

--- Returns true/false/nil (nil = unknown; health is secret and cannot be evaluated).
local function HealthBelowThreshold()
    if UnitIsDeadOrGhost then
        local dead = SafeCall(UnitIsDeadOrGhost, "player")
        if dead then
            return false
        end
    end

    -- Prefer percent API when present (0–1 range on modern clients).
    if UnitHealthPercent then
        local ok, pct = pcall(UnitHealthPercent, "player")
        if ok and CanUseNumber(pct) then
            if pct <= 1 then
                return pct < (HEALTH_LOW_PCT / 100)
            end
            return pct < HEALTH_LOW_PCT
        end
    end

    if not UnitHealth or not UnitHealthMax then
        return nil
    end
    local cur = SafeCall(UnitHealth, "player")
    local maxH = SafeCall(UnitHealthMax, "player")
    if not CanUseNumber(cur) or not CanUseNumber(maxH) or maxH <= 0 then
        return nil
    end
    local ok, below = pcall(function()
        return ((cur / maxH) * 100) < HEALTH_LOW_PCT
    end)
    if not ok then
        return nil
    end
    return below and true or false
end

local function SpeakHealthLow()
    if not On("stateHealthLow") then
        return
    end
    if AH.Alerts and AH.Alerts.Announce then
        AH.Alerts.Announce("vital", "Health below 35%", AH.Speech and AH.Speech.PRIORITY_CRITICAL, "stateHealthLow")
    elseif AH.Speech and AH.Speech.Say then
        AH.Speech.Say("Health below 35%", AH.Speech.PRIORITY_CRITICAL)
    else
        Say("Health below 35%")
    end
end

local function CheckLowHealth(seedOnly)
    local ok, low = pcall(HealthBelowThreshold)
    if not ok then
        low = nil
    end
    -- Unknown while secret: leave prior state alone (LowHealthFrame hook covers combat).
    if low == nil then
        return
    end
    if seedOnly then
        last.stateHealthLow = low
        return
    end
    local prev = last.stateHealthLow
    last.stateHealthLow = low
    if prev == nil or prev == low or not low then
        return
    end
    SpeakHealthLow()
end

local lowHealthFrameHooked = false

local function HookBlizzardLowHealthFrame()
    if lowHealthFrameHooked then
        return
    end
    local f = _G.LowHealthFrame
    if not f then
        return
    end
    lowHealthFrameHooked = true
    if f.HookScript then
        f:HookScript("OnShow", function()
            if not On("stateHealthLow") then
                return
            end
            if last.stateHealthLow == true then
                return
            end
            last.stateHealthLow = true
            SpeakHealthLow()
        end)
        f:HookScript("OnHide", function()
            last.stateHealthLow = false
        end)
    end
end

-- Talent unspent tracking (needed before Snapshot).
local lastUnspentClass, lastUnspentSpec, lastUnspentHero = 0, 0, 0
local levelUpTalentPending = false

local function ReadUnspentTalentPoints()
    local classPts, specPts, heroPts = 0, 0, 0
    if C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints then
        local ok, _, numClass, numSpec = pcall(C_ClassTalents.HasUnspentTalentPoints)
        if ok then
            classPts = tonumber(numClass) or 0
            specPts = tonumber(numSpec) or 0
        end
    end
    if C_ClassTalents and C_ClassTalents.HasUnspentHeroTalentPoints then
        local ok, _, numHero = pcall(C_ClassTalents.HasUnspentHeroTalentPoints)
        if ok then
            heroPts = tonumber(numHero) or 0
        end
    elseif GetNumUnspentTalents then
        local n = SafeCall(GetNumUnspentTalents)
        if type(n) == "number" and n > 0 and classPts == 0 and specPts == 0 then
            classPts = n
        end
    end
    return classPts, specPts, heroPts
end

local function SeedUnspentTalents()
    lastUnspentClass, lastUnspentSpec, lastUnspentHero = ReadUnspentTalentPoints()
end

local function SnapshotDiscrete(seedOnly)
    HookBlizzardLowHealthFrame()
    local now = GetTime and GetTime() or 0
    if now < readyAt then
        seedOnly = true
    end

    local mounted = IsMountedNow()
    local combat = InCombatNow()
    local death = DeathState()
    local resting = IsRestingNow()
    local taxi = IsOnTaxiNow()
    local vehicle = IsInVehicleNow()
    local afk = IsAFKNow()
    local pvp = IsPvPFlagged()
    local stealth = IsStealthedNow()
    local pet = HasPet()
    local group = InGroupNow()
    local instance = InInstanceNow()
    local form = ShapeshiftLabel()

    if seedOnly then
        last.stateMount = mounted
        last.stateCombat = combat
        last.stateDeath = death
        last.stateResting = resting
        last.stateTaxi = taxi
        last.stateVehicle = vehicle
        last.stateAFK = afk
        last.statePvP = pvp
        last.stateStealth = stealth
        last.statePet = pet
        last.stateGroup = group
        last.stateInstance = instance
        last.stateForm = form
        CheckLowHealth(true)
        if not levelUpTalentPending then
            SeedUnspentTalents()
        end
        return
    end

    DiffBool("stateMount", mounted, "Mounted.", "Dismounted.")
    DiffBool("stateCombat", combat, "In combat.", "Out of combat.")
    DiffBool("stateResting", resting, "Resting.", "Left rest area.")
    DiffBool("stateTaxi", taxi, "On taxi.", "Taxi ended.")
    DiffBool("stateVehicle", vehicle, "Entered vehicle.", "Left vehicle.")
    DiffBool("stateAFK", afk, "AFK on.", "AFK off.")
    DiffBool("statePvP", pvp, "PvP flagged.", "PvP unflagged.")
    DiffBool("stateStealth", stealth, "Stealth entered.", "Stealth left.")
    DiffBool("statePet", pet, "Pet summoned.", "Pet dismissed.")
    DiffBool("stateGroup", group, "Joined group.", "Left group.")
    DiffBool("stateInstance", instance, "Entered instance.", "Left instance.")
    CheckLowHealth(false)
    if not levelUpTalentPending then
        SeedUnspentTalents()
    end

    do
        local prev = last.stateDeath
        last.stateDeath = death
        if prev ~= nil and prev ~= death then
            if death == "dead" then
                Announce("stateDead", "Dead.")
            elseif death == "ghost" then
                Announce("stateGhost", "Ghost.")
            elseif death == "alive" and (prev == "dead" or prev == "ghost") then
                Announce("stateResurrected", "Resurrected.")
            end
        end
    end

    do
        local prev = last.stateForm
        last.stateForm = form
        if prev ~= nil and prev ~= form then
            if form then
                Announce("stateShapeshift", "Form: " .. form .. ".")
            else
                Announce("stateShapeshift", "Form cleared.")
            end
        end
    end
end

--- Light poll: movement / environment only (no dedicated reliable events).
local function PollEnvironment(seedOnly)
    local now = GetTime and GetTime() or 0
    if now < readyAt then
        seedOnly = true
    end

    local flying = IsFlyingNow()
    local swimming = IsSwimmingNow()
    local indoors = IsIndoorsNow()
    local falling = IsFallingNow()
    local breathLow = BreathLow()
    local fatigue = FatigueActive()

    if seedOnly then
        last.stateFly = flying
        last.stateSwim = swimming
        last.stateIndoors = indoors
        last.stateFalling = falling
        last.stateBreath = breathLow
        last.stateFatigue = fatigue
        return
    end

    DiffBool("stateFly", flying, "Flying.", "Stopped flying.")
    DiffBool("stateSwim", swimming, "Swimming.", "Stopped swimming.")
    DiffBool("stateIndoors", indoors, "Indoors.", "Outdoors.")
    DiffBool("stateFalling", falling, "Falling.", "Landed.")
    DiffBool("stateBreath", breathLow, "Breath low.", "Surfaced.")
    DiffBool("stateFatigue", fatigue, "Fatigue.", "Fatigue cleared.")
    CheckStuck(now)
end

--- Full seed on login / reload (discrete + environment).
local function Snapshot(seedOnly)
    SnapshotDiscrete(seedOnly)
    PollEnvironment(seedOnly)
end

-- Event-driven extras
-- Level-up: speak Blizzard congratulations, then talent point kinds
-- (class / specialization / hero). Retail often leaves numNewTalents at 0.

local function FormatTalentPointLine(kind, count)
    if type(count) ~= "number" or count <= 0 then
        return nil
    end
    if count == 1 then
        return string.format("%s talent point available.", kind)
    end
    return string.format("%d %s talent points available.", count, string.lower(kind))
end

local function BuildTalentGainLines(prevClass, prevSpec, prevHero, numNewTalents, numNewPvpSlots)
    local classPts, specPts, heroPts = ReadUnspentTalentPoints()
    local dClass = classPts - (tonumber(prevClass) or 0)
    local dSpec = specPts - (tonumber(prevSpec) or 0)
    local dHero = heroPts - (tonumber(prevHero) or 0)
    -- Clamp: spending points mid-level-up shouldn't invent negative gains.
    if dClass < 0 then dClass = 0 end
    if dSpec < 0 then dSpec = 0 end
    if dHero < 0 then dHero = 0 end

    local lines = {}
    local classLine = FormatTalentPointLine("Class", dClass)
    if classLine then
        lines[#lines + 1] = classLine
    end
    local specLine = FormatTalentPointLine("Specialization", dSpec)
    if specLine then
        lines[#lines + 1] = specLine
    end
    local heroLine = FormatTalentPointLine("Hero", dHero)
    if heroLine then
        lines[#lines + 1] = heroLine
    end

    local pvpSlots = tonumber(numNewPvpSlots) or 0
    if pvpSlots > 0 then
        if pvpSlots == 1 then
            lines[#lines + 1] = "PvP talent slot available."
        else
            lines[#lines + 1] = string.format("%d PvP talent slots available.", pvpSlots)
        end
    end

    -- Fallback when APIs do not expose tree deltas but the event says talents were gained.
    if #lines == 0 then
        local n = tonumber(numNewTalents) or 0
        if n > 0 then
            local talent = ""
            if AH.ChatText and AH.ChatText.ForSpeech and type(_G.LEVEL_UP_TALENTPOINT_LINK) == "string" then
                talent = AH.ChatText.ForSpeech(_G.LEVEL_UP_TALENTPOINT_LINK)
            end
            if talent == "" and type(_G.LEVEL_UP_TALENT_MAIN) == "string" then
                talent = AH.ChatText and AH.ChatText.ForSpeech and AH.ChatText.ForSpeech(_G.LEVEL_UP_TALENT_MAIN)
                    or _G.LEVEL_UP_TALENT_MAIN
            end
            if talent == "" then
                if n == 1 then
                    talent = "New talent point available."
                else
                    talent = string.format("%d new talent points available.", n)
                end
            end
            lines[#lines + 1] = talent
        end
    end

    lastUnspentClass, lastUnspentSpec, lastUnspentHero = classPts, specPts, heroPts
    return lines, (dClass + dSpec + dHero)
end

local function SpeakTalentGains(prevClass, prevSpec, prevHero, numNewTalents, numNewPvpSlots, attempt)
    if not On("stateLevelUp") then
        levelUpTalentPending = false
        return
    end
    local lines, _gained = BuildTalentGainLines(prevClass, prevSpec, prevHero, numNewTalents, numNewPvpSlots)
    if #lines == 0 and (attempt or 1) < 3 then
        -- Talent currency sometimes updates a moment after PLAYER_LEVEL_UP.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.4, function()
                SpeakTalentGains(prevClass, prevSpec, prevHero, numNewTalents, numNewPvpSlots, (attempt or 1) + 1)
            end)
        end
        return
    end
    levelUpTalentPending = false
    for i = 1, #lines do
        Announce("stateLevelUp", lines[i])
    end
end

local function OnLevelUp(level, healthDelta, powerDelta, numNewTalents, numNewPvpTalentSlots)
    if not On("stateLevelUp") then
        return
    end
    level = tonumber(level)
    if not level and UnitLevel then
        local ok, lvl = pcall(UnitLevel, "player")
        if ok then
            level = tonumber(lvl)
        end
    end
    numNewTalents = tonumber(numNewTalents) or 0
    numNewPvpTalentSlots = tonumber(numNewPvpTalentSlots) or 0

    local prevClass, prevSpec, prevHero = lastUnspentClass, lastUnspentSpec, lastUnspentHero

    local congrats = ""
    if AH.ChatText and AH.ChatText.Format and level then
        congrats = AH.ChatText.Format("LEVEL_UP", level, level)
    end
    if congrats == "" and level then
        congrats = string.format("Congratulations, you have reached Level %d!", level)
    elseif congrats == "" then
        congrats = "Congratulations, you have leveled up!"
    end
    Announce("stateLevelUp", congrats)

    levelUpTalentPending = true
    local function runTalentCheck()
        SpeakTalentGains(prevClass, prevSpec, prevHero, numNewTalents, numNewPvpTalentSlots, 1)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.35, runTalentCheck)
    else
        runTalentCheck()
    end
end

local function OnQuest(event, ...)
    if event == "QUEST_ACCEPTED" then
        local a1, a2 = ...
        local title = nil
        local questID = a2 or a1
        if type(questID) == "number" and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            local ok, t = pcall(C_QuestLog.GetTitleForQuestID, questID)
            if ok and type(t) == "string" and t ~= "" then
                title = t
            end
        end
        if type(a1) == "string" and a1 ~= "" then
            title = a1
        end
        local spoken = ""
        if title and AH.ChatText and AH.ChatText.Format then
            spoken = AH.ChatText.Format("ERR_QUEST_ACCEPTED_S", title)
        end
        if spoken == "" and title then
            spoken = "Quest accepted: " .. title
        elseif spoken == "" then
            spoken = "Quest accepted."
        end
        Announce("stateQuest", spoken)
    elseif event == "QUEST_TURNED_IN" then
        local questID = ...
        local title = nil
        if type(questID) == "number" and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            local ok, t = pcall(C_QuestLog.GetTitleForQuestID, questID)
            if ok and type(t) == "string" and t ~= "" then
                title = t
            end
        end
        local spoken = ""
        if title and AH.ChatText and AH.ChatText.Format then
            spoken = AH.ChatText.Format("ERR_QUEST_COMPLETE_S", title)
        end
        if spoken == "" and type(_G.QUEST_WATCH_POPUP_QUEST_COMPLETE) == "string" and AH.ChatText then
            spoken = AH.ChatText.ForSpeech(_G.QUEST_WATCH_POPUP_QUEST_COMPLETE)
        end
        if spoken == "" then
            spoken = "Quest Complete!"
        end
        Announce("stateQuest", spoken)
    elseif event == "QUEST_COMPLETE" then
        local spoken = ""
        if type(_G.QUEST_COMPLETE) == "string" and AH.ChatText then
            spoken = AH.ChatText.ForSpeech(_G.QUEST_COMPLETE)
        end
        if spoken == "" then
            spoken = "Quest completed"
        end
        Announce("stateQuest", spoken)
    end
end

local lastMoney = nil
local bagsWereFull = false
local durabilityWarned = false
local lastMoneyChat = nil
local lastMoneyChatAt = 0

local function LooksLikeMoneyChat(text)
    local lower = string.lower(text)
    if not (lower:find("gold", 1, true) or lower:find("silver", 1, true) or lower:find("copper", 1, true)) then
        return false
    end
    return lower:find("loot", 1, true)
        or lower:find("gain", 1, true)
        or lower:find("gained", 1, true)
        or lower:find("refund", 1, true)
        or lower:find("share", 1, true)
        or lower:find("received", 1, true)
        or lower:find("deposit", 1, true)
        or lower:find("paid", 1, true)
        or lower:find("spend", 1, true)
        or lower:find("spent", 1, true)
end

local function OnMoneyChat(text)
    if not On("stateMoney") then
        return
    end
    local spoken
    if AH.ChatText and AH.ChatText.ForChatMessage then
        spoken = AH.ChatText.ForChatMessage(text)
    else
        spoken = (AH.ChatText and AH.ChatText.ForSpeech and AH.ChatText.ForSpeech(text)) or tostring(text or "")
    end
    if spoken == "" then
        return
    end
    local now = GetTime and GetTime() or 0
    if spoken == lastMoneyChat and (now - lastMoneyChatAt) < 0.4 then
        return
    end
    lastMoneyChat = spoken
    lastMoneyChatAt = now
    Say(spoken)
end

local function OnMoney()
    -- Keep GetMoney cache in sync; speech comes from chat lines only.
    if not GetMoney then
        return
    end
    local cur = SafeCall(GetMoney)
    if type(cur) == "number" then
        lastMoney = cur
    end
end

local function OnTarget()
    if UnitExists("target") then
        local name = UnitName("target")
        if type(name) == "string" and name ~= "" then
            Announce("stateTarget", "Target acquired: " .. name .. ".")
        else
            Announce("stateTarget", "Target acquired.")
        end
    else
        Announce("stateTarget", "Target cleared.")
    end
end

local function OnBagFull()
    if not On("stateBagFull") then
        return
    end
    local freeSlots = 0
    local found = false
    if C_Container and C_Container.GetContainerNumFreeSlots then
        for bag = 0, 4 do
            local n = SafeCall(C_Container.GetContainerNumFreeSlots, bag)
            if type(n) == "number" then
                freeSlots = freeSlots + n
                found = true
            end
        end
    elseif GetContainerNumFreeSlots then
        for bag = 0, 4 do
            local n = SafeCall(GetContainerNumFreeSlots, bag)
            if type(n) == "number" then
                freeSlots = freeSlots + n
                found = true
            end
        end
    end
    if not found then
        return
    end
    local full = freeSlots == 0
    if full and not bagsWereFull then
        local spoken = ""
        if AH.ChatText and AH.ChatText.ForSpeech then
            if type(_G.ERR_INV_FULL) == "string" then
                spoken = AH.ChatText.ForSpeech(_G.ERR_INV_FULL)
            elseif type(_G.ERR_BAG_FULL) == "string" then
                spoken = AH.ChatText.ForSpeech(_G.ERR_BAG_FULL)
            end
        end
        if spoken == "" then
            spoken = "Inventory is full."
        end
        Say(spoken)
    end
    bagsWereFull = full
end

local function OnDurability()
    if not On("stateDurability") then
        return
    end
    local cur, max = 0, 0
    for slot = 1, 19 do
        local c, m = SafeCall(GetInventoryItemDurability, slot)
        if type(c) == "number" and type(m) == "number" and m > 0 then
            cur = cur + c
            max = max + m
        end
    end
    if max > 0 then
        local pct = cur / max
        if pct < 0.25 then
            if not durabilityWarned then
                durabilityWarned = true
                Say("Durability low.")
            end
        else
            durabilityWarned = false
        end
    end
end

local function OnQueue()
    Announce("stateQueue", "Group finder queue updated.")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_TURNED_IN")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("CHAT_MSG_MONEY")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
frame:RegisterEvent("LFG_QUEUE_STATUS_UPDATE")
frame:RegisterEvent("LFG_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("PET_BAR_UPDATE")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
frame:RegisterEvent("MIRROR_TIMER_START")
frame:RegisterEvent("MIRROR_TIMER_STOP")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("AUTOFOLLOW_BEGIN")
frame:RegisterEvent("AUTOFOLLOW_END")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterEvent("UPDATE_STEALTH")
pcall(frame.RegisterEvent, frame, "UNIT_ENTERED_VEHICLE")
pcall(frame.RegisterEvent, frame, "UNIT_EXITED_VEHICLE")

frame.elapsed = 0
frame:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < POLL then
        return
    end
    self.elapsed = 0
    -- Light poll only (swim / fly / fall / indoors / breath / fatigue / stuck).
    PollEnvironment(false)
end)

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        readyAt = (GetTime and GetTime() or 0) + 3
        stuck.x, stuck.y, stuck.since, stuck.announced = nil, nil, nil, false
        bagsWereFull = false
        durabilityWarned = false
        ResetFollowState()
        if GetMoney then
            lastMoney = SafeCall(GetMoney)
        end
        SeedUnspentTalents()
        HookBlizzardLowHealthFrame()
        Snapshot(true)
        return
    end
    if event == "AUTOFOLLOW_BEGIN" then
        OnAutoFollowBegin((...))
        return
    end
    if event == "AUTOFOLLOW_END" then
        OnAutoFollowEnd()
        return
    end
    if event == "PLAYER_LEVEL_UP" then
        OnLevelUp(...)
        return
    end
    if event == "QUEST_ACCEPTED" or event == "QUEST_TURNED_IN" or event == "QUEST_COMPLETE" then
        OnQuest(event, ...)
        return
    end
    if event == "PLAYER_MONEY" then
        OnMoney()
        return
    end
    if event == "CHAT_MSG_MONEY" then
        OnMoneyChat((...))
        return
    end
    if event == "CHAT_MSG_SYSTEM" then
        local text = ...
        local spoken
        if AH.ChatText and AH.ChatText.ForChatMessage then
            spoken = AH.ChatText.ForChatMessage(text)
        else
            spoken = (AH.ChatText and AH.ChatText.ForSpeech and AH.ChatText.ForSpeech(text)) or tostring(text or "")
        end
        if LooksLikeMoneyChat(spoken) then
            OnMoneyChat(text)
        end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        OnTarget()
        return
    end
    if event == "BAG_UPDATE" then
        OnBagFull()
        return
    end
    if event == "UPDATE_INVENTORY_DURABILITY" then
        OnDurability()
        return
    end
    if event == "LFG_QUEUE_STATUS_UPDATE" or event == "LFG_UPDATE" then
        OnQueue()
        return
    end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        local unit = ...
        if unit == "player" then
            CheckLowHealth(false)
        end
        return
    end
    if event == "MIRROR_TIMER_START" or event == "MIRROR_TIMER_STOP" then
        PollEnvironment(false)
        return
    end
    if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        local unit = ...
        if unit ~= nil and unit ~= "player" then
            return
        end
    end
    -- Discrete state transitions: event-driven (not the light environment poll).
    SnapshotDiscrete(false)
end)
