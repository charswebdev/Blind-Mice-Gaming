--[[
  Accessibility Helper — clock facing (targets + TomTom/Zygor arrows)
  Target: always auto in combat; out of combat if facingTargetEnabled (default on).
  Arrows: never in combat; out of combat if facingArrowEnabled (default on). /aha toggles arrows.
  Silent at 12 o'clock. Read Target bind speaks full report.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Facing = AH.Facing or {}
local Facing = AH.Facing

local PI = math.pi
local TWO_PI = PI * 2
local POLL = 0.4
local COOLDOWN = 1.2

local lastTomTomHour, lastZygorHour, lastTargetHour
local lastTomTomAt, lastZygorAt, lastTargetAt = 0, 0, 0

-- Cached relative angles captured from TomTom / Zygor (radians, 0 = ahead).
local tomTomRel, tomTomRelAt, tomTomUid
local zygorRel, zygorRelAt
local tomTomHooksDone = false
local zygorHooksDone = false

-- Assigned after Tick helpers; toggles / events call this upvalue.
local SyncFacingTicker

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function ArrowEnabled()
    return DB().facingArrowEnabled ~= false
end

local function TargetFacingEnabled()
    return DB().facingTargetEnabled ~= false
end

local function Say(msg)
    if type(msg) ~= "string" or msg == "" then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_NAV)
    else
        print("|cff66ccff[Helper]|r " .. msg)
    end
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

function Facing.NormalizeAngle(a)
    if type(a) ~= "number" then
        return nil
    end
    while a > PI do
        a = a - TWO_PI
    end
    while a < -PI do
        a = a + TWO_PI
    end
    return a
end

function Facing.RelativeToClock(relative)
    relative = Facing.NormalizeAngle(relative)
    if relative == nil then
        return nil
    end
    local deg = relative * 180 / PI
    local clockwise = -deg
    if clockwise < 0 then
        clockwise = clockwise + 360
    end
    local hour = math.floor((clockwise + 15) / 30) % 12
    if hour == 0 then
        hour = 12
    end
    return hour
end

function Facing.IsAhead(hour)
    return hour == 12
end

function Facing.FormatClock(hour)
    if type(hour) ~= "number" then
        return nil
    end
    return string.format("%d o'clock", hour)
end

function Facing.RelativeFromWorldAngle(worldAngle)
    if type(worldAngle) ~= "number" or not GetPlayerFacing then
        return nil
    end
    if AH.Compat and AH.Compat.CanUseNumber and not AH.Compat.CanUseNumber(worldAngle) then
        return nil
    end
    local facing = GetPlayerFacing()
    if type(facing) ~= "number" then
        return nil
    end
    if AH.Compat and AH.Compat.CanUseNumber and not AH.Compat.CanUseNumber(facing) then
        return nil
    end
    return Facing.NormalizeAngle(worldAngle - facing)
end

--- Relative angle to unit via UnitPosition (party/raid/player) when available.
function Facing.RelativeToUnit(unit)
    unit = unit or "target"
    if not UnitExists or not UnitExists(unit) or not UnitPosition then
        return nil
    end
    local ok1, y1, x1, _, inst1 = pcall(UnitPosition, "player")
    local ok2, y2, x2, _, inst2 = pcall(UnitPosition, unit)
    if not ok1 or not ok2 or not x1 or not y1 or not x2 or not y2 then
        return nil
    end
    local CanUse = AH.Compat and AH.Compat.CanUseNumber
    if CanUse then
        if not (CanUse(x1) and CanUse(y1) and CanUse(x2) and CanUse(y2)) then
            return nil
        end
    end
    if inst1 ~= nil and inst2 ~= nil and inst1 ~= inst2 then
        return nil
    end
    -- UnitPosition: y, x. Match TomTom/HBD: atan2(-(x2-x1), y2-y1).
    local worldAngle = math.atan2(-(x2 - x1), y2 - y1)
    return Facing.RelativeFromWorldAngle(worldAngle)
end

--- Fallback: nameplate screen position (0 = toward top of screen ≈ ahead in 3rd person).
-- Nameplates are often restricted (can't measure); never call GetCenter unprotected.
function Facing.RelativeToUnitNameplate(unit)
    unit = unit or "target"
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        return nil
    end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then
        return nil
    end
    if plate.IsForbidden and plate:IsForbidden() then
        return nil
    end
    if not plate.GetCenter then
        return nil
    end
    -- Restricted nameplates error on GetCenter; must pcall.
    local okPos, x, y = pcall(plate.GetCenter, plate)
    if not okPos or type(x) ~= "number" or type(y) ~= "number" then
        return nil
    end
    if not GetScreenWidth or not GetScreenHeight then
        return nil
    end
    local dx = x - (GetScreenWidth() / 2)
    local dy = y - (GetScreenHeight() / 2)
    if dx == 0 and dy == 0 then
        return 0
    end
    -- atan2(dx, dy): 0 = up (ahead); positive dx = right → clock 3 → relative negative.
    local ang = math.atan2(dx, dy)
    return Facing.NormalizeAngle(-ang)
end

function Facing.GetTargetRelative()
    return Facing.RelativeToUnit("target") or Facing.RelativeToUnitNameplate("target")
end

function Facing.GetTargetClock()
    local rel = Facing.GetTargetRelative()
    if not rel then
        return nil
    end
    return Facing.RelativeToClock(rel)
end

local function AddonLoaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(name) and true or false
    end
    return false
end

local function GetHBD()
    if LibStub then
        local ok, lib = pcall(LibStub, "HereBeDragons-2.0", true)
        if ok and lib then
            return lib
        end
    end
    return nil
end

local function EnsureArrowHooks()
    if TomTom and not tomTomHooksDone and type(TomTom.SetCrazyArrow) == "function" then
        tomTomHooksDone = true
        hooksecurefunc(TomTom, "SetCrazyArrow", function(_, uid)
            tomTomUid = uid
        end)
        -- Crazy arrow OnUpdate calls this every frame with the private active_point.
        if type(TomTom.GetDirectionToWaypoint) == "function" then
            hooksecurefunc(TomTom, "GetDirectionToWaypoint", function(_, uid)
                if uid then
                    tomTomUid = uid
                end
            end)
        end
        if type(TomTom.ClearCrazyArrowPoint) == "function" then
            hooksecurefunc(TomTom, "ClearCrazyArrowPoint", function()
                if TomTom.IsCrazyArrowEmpty and TomTom:IsCrazyArrowEmpty() then
                    tomTomUid = nil
                    tomTomRel = nil
                end
            end)
        end
        local handler = TomTom.CrazyArrowThemeHandler
        if handler and type(handler.NavigationArrow_OnUpdate) == "function" then
            -- Angle here is already relative (world - player facing).
            hooksecurefunc(handler, "NavigationArrow_OnUpdate", function(_, _elapsed, angle)
                if type(angle) == "number" then
                    tomTomRel = angle
                    tomTomRelAt = GetTime and GetTime() or 0
                end
            end)
        end
    end

    if zygorHooksDone then
        return
    end
    local Z = ZGV or ZygorGuidesViewer
    local Pointer = Z and Z.Pointer
    if not Pointer then
        return
    end

    local function HookShowTraveling(af)
        if not af or af._ahFacingHooked or type(af.ShowTraveling) ~= "function" then
            return
        end
        af._ahFacingHooked = true
        hooksecurefunc(af, "ShowTraveling", function(_, _elapsed, angle)
            if type(angle) == "number" then
                -- Zygor keeps angle in [0, 2pi]; convert to signed relative.
                local a = angle
                if a > PI then
                    a = a - TWO_PI
                end
                zygorRel = a
                zygorRelAt = GetTime and GetTime() or 0
            end
        end)
    end

    if Pointer.ArrowFrame then
        HookShowTraveling(Pointer.ArrowFrame)
        if Pointer.ArrowFrame._ahFacingHooked then
            zygorHooksDone = true
        end
    end
    if Pointer.ArrowFrameCtrl and not Pointer.ArrowFrameCtrl._ahFacingPoll then
        Pointer.ArrowFrameCtrl._ahFacingPoll = true
        Pointer.ArrowFrameCtrl:HookScript("OnUpdate", function()
            if Pointer.ArrowFrame and not Pointer.ArrowFrame._ahFacingHooked then
                HookShowTraveling(Pointer.ArrowFrame)
                if Pointer.ArrowFrame._ahFacingHooked then
                    zygorHooksDone = true
                end
            end
        end)
    end
end

local function TomTomRelative()
    EnsureArrowHooks()
    local now = GetTime and GetTime() or 0

    -- Freshest: relative angle TomTom already computed for drawing.
    if type(tomTomRel) == "number" and tomTomRelAt and (now - tomTomRelAt) < 1.5 then
        return Facing.NormalizeAngle(tomTomRel)
    end

    if not TomTom then
        return nil
    end
    if TomTom.IsCrazyArrowEmpty and TomTom:IsCrazyArrowEmpty() then
        tomTomUid = nil
        tomTomRel = nil
        return nil
    end

    -- Compute from active waypoint uid (captured via SetCrazyArrow / GetDirection hooks).
    if tomTomUid and type(TomTom.GetDirectionToWaypoint) == "function" then
        local ok, angle = pcall(TomTom.GetDirectionToWaypoint, TomTom, tomTomUid)
        if ok and type(angle) == "number" then
            return Facing.RelativeFromWorldAngle(angle)
        end
    end

    -- Fallback: closest waypoint (may differ from crazy-arrow target).
    if type(TomTom.GetClosestWaypoint) == "function" and type(TomTom.GetDirectionToWaypoint) == "function" then
        local ok, uid = pcall(TomTom.GetClosestWaypoint, TomTom)
        if ok and uid then
            local ok2, angle = pcall(TomTom.GetDirectionToWaypoint, TomTom, uid)
            if ok2 and type(angle) == "number" then
                tomTomUid = uid
                return Facing.RelativeFromWorldAngle(angle)
            end
        end
    end

    return nil
end

local function ZygorRelative()
    EnsureArrowHooks()
    local now = GetTime and GetTime() or 0
    if type(zygorRel) == "number" and zygorRelAt and (now - zygorRelAt) < 1.5 then
        return Facing.NormalizeAngle(zygorRel)
    end

    local Z = ZGV or ZygorGuidesViewer
    if not Z or not Z.Pointer then
        return nil
    end
    local arrow = Z.Pointer.ArrowFrame
    if not arrow then
        return nil
    end
    local shown = false
    pcall(function()
        shown = arrow:IsShown() and true or false
    end)
    if not shown then
        return nil
    end

    local way = arrow.waypoint or Z.Pointer.DestinationWaypoint
    if type(way) == "table" then
        local HBD = GetHBD()
        local x, y, m = way.x, way.y, way.m or way.map or way.uiMapID
        if HBD and x and y and m and HBD.GetPlayerWorldPosition and HBD.GetWorldCoordinatesFromZone and HBD.GetWorldVector then
            local px, py, instance = HBD:GetPlayerWorldPosition()
            local tx, ty, tInst = HBD:GetWorldCoordinatesFromZone(x, y, m)
            if px and py and tx and ty and instance and (not tInst or tInst == instance) then
                local angle = HBD:GetWorldVector(instance, px, py, tx, ty)
                if type(angle) == "number" then
                    return Facing.RelativeFromWorldAngle(angle)
                end
            end
        end
        if type(way.angle) == "number" then
            return Facing.RelativeFromWorldAngle(way.angle)
        end
    end

    if arrow.arrow and type(arrow.arrow.angle) == "number" then
        local a = arrow.arrow.angle
        if a > PI then
            a = a - TWO_PI
        end
        return Facing.NormalizeAngle(a)
    end

    return nil
end
local function AnnounceClockChange(label, hour, getPrev, setPrev)
    if not hour then
        return
    end
    if Facing.IsAhead(hour) then
        setPrev(12, GetTime and GetTime() or 0)
        return
    end
    local prev, prevAt = getPrev()
    if prev == hour then
        return
    end
    local now = GetTime and GetTime() or 0
    if (now - (prevAt or 0)) < COOLDOWN and prev ~= nil and prev ~= 12 then
        return
    end
    setPrev(hour, now)
    if AH.Speech and AH.Speech.TrimNavQueue then
        AH.Speech.TrimNavQueue()
    end
    if label and label ~= "" then
        Say(string.format("%s. Facing %s.", label, Facing.FormatClock(hour)))
    else
        Say(string.format("Facing %s.", Facing.FormatClock(hour)))
    end
end

local function MaybeArrow(label, relative, kind)
    local hour = Facing.RelativeToClock(relative)
    if not hour then
        return
    end
    if Facing.IsAhead(hour) then
        if kind == "tomtom" then
            lastTomTomHour = 12
        else
            lastZygorHour = 12
        end
        return
    end
    local prev = (kind == "tomtom") and lastTomTomHour or lastZygorHour
    if prev == hour then
        return
    end
    local now = GetTime and GetTime() or 0
    local prevAt = (kind == "tomtom") and lastTomTomAt or lastZygorAt
    if (now - prevAt) < COOLDOWN and prev ~= nil and prev ~= 12 then
        return
    end
    if kind == "tomtom" then
        lastTomTomHour = hour
        lastTomTomAt = now
    else
        lastZygorHour = hour
        lastZygorAt = now
    end
    if AH.Speech and AH.Speech.TrimNavQueue then
        AH.Speech.TrimNavQueue()
    end
    Say(string.format("%s %s.", label, Facing.FormatClock(hour)))
end

local function TargetReactionLabel()
    if not UnitExists("target") then
        return nil
    end
    if UnitIsUnit and UnitIsUnit("target", "player") then
        return "You"
    end
    if UnitIsDead or UnitIsGhost then
        local dead = (UnitIsDead and UnitIsDead("target")) or (UnitIsGhost and UnitIsGhost("target"))
        if dead then
            return "Dead"
        end
    end
    if UnitCanAttack and UnitCanAttack("player", "target") then
        return "Hostile"
    end
    if UnitIsFriend and UnitIsFriend("player", "target") then
        return "Friendly"
    end
    return "Neutral"
end

local function TargetHealthPhrase()
    if UnitHealthPercent then
        local ok, pct = pcall(UnitHealthPercent, "target")
        if ok and AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(pct) then
            local n = pct
            if n <= 1 then
                n = n * 100
            end
            return string.format("%d percent health", math.floor(n + 0.5))
        end
    end
    if not (UnitHealth and UnitHealthMax) then
        return nil
    end
    local ok1, cur = pcall(UnitHealth, "target")
    local ok2, maxH = pcall(UnitHealthMax, "target")
    if not ok1 or not ok2 then
        return nil
    end
    if AH.Compat and AH.Compat.CanUseNumber then
        if not AH.Compat.CanUseNumber(cur) or not AH.Compat.CanUseNumber(maxH) then
            return nil
        end
    elseif type(cur) ~= "number" or type(maxH) ~= "number" then
        return nil
    end
    if maxH <= 0 then
        return nil
    end
    local ok, pct = pcall(function()
        return math.floor((cur / maxH) * 100 + 0.5)
    end)
    if not ok or type(pct) ~= "number" then
        return nil
    end
    return string.format("%d percent health", pct)
end

local function TargetCastPhrase()
    local name
    if UnitCastingInfo then
        local ok, n = pcall(UnitCastingInfo, "target")
        if ok and type(n) == "string" and n ~= "" then
            name = n
        end
    end
    if not name and UnitChannelInfo then
        local ok, n = pcall(UnitChannelInfo, "target")
        if ok and type(n) == "string" and n ~= "" then
            name = n
        end
    end
    if name then
        return "Casting " .. name
    end
    return nil
end

local function TargetDistancePhrase()
    if AH.Distance and AH.Distance.DescribeTargetRange then
        return AH.Distance.DescribeTargetRange("target")
    end
    return nil
end

--- Full on-demand target report (bind / /ahtarget).
function Facing.ReadTarget()
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if not UnitExists or not UnitExists("target") then
        Say("No target.")
        return
    end

    local parts = {}
    local name = UnitName and UnitName("target")
    if type(name) == "string" and name ~= "" then
        parts[#parts + 1] = name
    else
        parts[#parts + 1] = "Target"
    end

    local reaction = TargetReactionLabel()
    if reaction and reaction ~= "You" then
        parts[#parts + 1] = reaction
    end

    local hp = TargetHealthPhrase()
    if hp then
        parts[#parts + 1] = hp
    end

    local cast = TargetCastPhrase()
    if cast then
        parts[#parts + 1] = cast
    end

    local hour = Facing.GetTargetClock()
    if hour then
        parts[#parts + 1] = "Facing " .. Facing.FormatClock(hour)
    end

    local dist = TargetDistancePhrase()
    if dist then
        parts[#parts + 1] = dist
    end

    Say(table.concat(parts, ". ") .. ".")
end

function Facing.ToggleArrowAnnounce()
    local sv = DB()
    local on = sv.facingArrowEnabled ~= false
    sv.facingArrowEnabled = not on
    local enabled = sv.facingArrowEnabled and true or false
    lastTomTomHour = nil
    lastZygorHour = nil
    local msg = enabled and "Arrow facing announcements on." or "Arrow facing announcements off."
    if enabled then
        EnsureArrowHooks()
        if InCombat() then
            msg = msg .. " Paused in combat."
        else
            local tt = TomTomRelative()
            local zg = (not tt) and ZygorRelative() or nil
            local rel = tt or zg
            local hour = rel and Facing.RelativeToClock(rel)
            if hour then
                if Facing.IsAhead(hour) then
                    msg = msg .. " Arrow ahead, silent at 12."
                    if tt then
                        lastTomTomHour = 12
                    else
                        lastZygorHour = 12
                    end
                else
                    local label = tt and "TomTom" or "Zygor"
                    msg = msg .. " " .. label .. " " .. Facing.FormatClock(hour) .. "."
                    if tt then
                        lastTomTomHour = hour
                        lastTomTomAt = GetTime and GetTime() or 0
                    else
                        lastZygorHour = hour
                        lastZygorAt = GetTime and GetTime() or 0
                    end
                end
            else
                msg = msg .. " No active arrow yet."
            end
        end
    end
    Say(msg)
    print("|cff66ccff[Helper]|r " .. msg)
    if AH.Settings and AH.Settings.RefreshCheckboxes then
        AH.Settings.RefreshCheckboxes()
    end
    SyncFacingTicker()
    return enabled
end

function Facing.ToggleTargetAnnounce()
    local sv = DB()
    local on = sv.facingTargetEnabled ~= false
    sv.facingTargetEnabled = not on
    local enabled = sv.facingTargetEnabled and true or false
    lastTargetHour = nil
    local msg
    if enabled then
        msg = "Target facing on. Always in combat, and out of combat when enabled."
    else
        msg = "Target facing out of combat off. Still announces in combat."
    end
    Say(msg)
    print("|cff66ccff[Helper]|r " .. msg)
    if AH.Settings and AH.Settings.RefreshCheckboxes then
        AH.Settings.RefreshCheckboxes()
    end
    SyncFacingTicker()
    return enabled
end

local function TickTarget()
    -- Locked: always auto in combat; out of combat only if toggle on.
    local combat = InCombat()
    if not combat and not TargetFacingEnabled() then
        lastTargetHour = nil
        return
    end
    if not UnitExists or not UnitExists("target") then
        lastTargetHour = nil
        return
    end

    local hour = Facing.GetTargetClock()
    if not hour then
        return
    end

    AnnounceClockChange(
        (UnitName and UnitName("target")) or "Target",
        hour,
        function()
            return lastTargetHour, lastTargetAt
        end,
        function(h, t)
            lastTargetHour = h
            lastTargetAt = t
        end
    )
end

local function TickArrows()
    if not ArrowEnabled() then
        return
    end
    if InCombat() then
        return
    end

    if AddonLoaded("TomTom") or TomTom then
        local rel = TomTomRelative()
        if rel then
            MaybeArrow("TomTom", rel, "tomtom")
        else
            lastTomTomHour = nil
        end
    end

    if AddonLoaded("ZygorGuidesViewer") or ZGV or ZygorGuidesViewer then
        local rel = ZygorRelative()
        if rel then
            MaybeArrow("Zygor", rel, "zygor")
        else
            lastZygorHour = nil
        end
    end
end

local function Tick()
    TickTarget()
    TickArrows()
end

local frame -- forward declare for SyncFacingTicker

local function FacingNeedsTick()
    if ArrowEnabled() and not InCombat() then
        return true
    end
    if UnitExists and UnitExists("target") then
        if InCombat() then
            return true
        end
        if TargetFacingEnabled() then
            return true
        end
    end
    return false
end

local facingOnUpdate

SyncFacingTicker = function()
    if not frame then
        return
    end
    if FacingNeedsTick() then
        if frame:GetScript("OnUpdate") ~= facingOnUpdate then
            frame.elapsed = 0
            frame:SetScript("OnUpdate", facingOnUpdate)
        end
    else
        if frame:GetScript("OnUpdate") then
            frame:SetScript("OnUpdate", nil)
            frame.elapsed = 0
        end
    end
end

facingOnUpdate = function(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < POLL then
        return
    end
    self.elapsed = 0
    Tick()
    if not FacingNeedsTick() then
        SyncFacingTicker()
    end
end

frame = CreateFrame("Frame")
frame.elapsed = 0
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "TomTom" then
            tomTomHooksDone = false
            EnsureArrowHooks()
        elseif arg1 == "ZygorGuidesViewer" then
            zygorHooksDone = false
            EnsureArrowHooks()
        end
        SyncFacingTicker()
        return
    end
    if event == "PLAYER_LOGIN" then
        EnsureArrowHooks()
        SyncFacingTicker()
        return
    end
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_REGEN_DISABLED" then
        lastTargetHour = nil
        SyncFacingTicker()
    end
end)
