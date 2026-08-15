--[[
  Accessibility Helper — target distance (Phase 5)
  Best estimate: exact yards only when same world instance.
  UnitDistanceSquared is NOT trusted alone (false yards across continents).
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Distance = AH.Distance or {}
local Distance = AH.Distance

local function Say(msg)
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_NAV)
    else
        print("|cff66ccff[Helper]|r " .. tostring(msg))
    end
end

local function Enabled()
    local sv = AH.DB and AH.DB.Get and AH.DB.Get()
    return not sv or sv.distanceEnabled ~= false
end

local function RoundYards(n)
    return math.floor(n + 0.5)
end

--- UnitPosition instance IDs must match or distance is meaningless.
-- Returns: same (bool|nil), yards (number|nil), reason (string|nil)
-- same == true  → yards is trustworthy
-- same == false → different area / instance
-- same == nil   → could not determine via UnitPosition
local function SameInstanceDistance(unit)
    if not UnitPosition then
        return nil, nil, nil
    end
    local ok1, y1, x1, _, inst1 = pcall(UnitPosition, "player")
    local ok2, y2, x2, _, inst2 = pcall(UnitPosition, unit)
    if not ok1 or not ok2 then
        return nil, nil, nil
    end
    -- UnitPosition only works for player / party / raid.
    if x1 == nil or y1 == nil or inst1 == nil then
        return nil, nil, nil
    end
    if x2 == nil or y2 == nil or inst2 == nil then
        -- Group member with no position usually means other instance / restricted.
        if UnitInParty and (UnitInParty(unit) or (UnitInRaid and UnitInRaid(unit))) then
            return false, nil, "different_area"
        end
        return nil, nil, nil
    end
    if inst1 ~= inst2 then
        return false, nil, "different_area"
    end
    if AH.Compat and AH.Compat.CanUseNumber then
        if not (AH.Compat.CanUseNumber(x1) and AH.Compat.CanUseNumber(y1)
            and AH.Compat.CanUseNumber(x2) and AH.Compat.CanUseNumber(y2)) then
            return nil, nil, nil
        end
    end
    local dist = ((x2 - x1) ^ 2 + (y2 - y1) ^ 2) ^ 0.5
    if AH.Compat and AH.Compat.CanUseNumber and not AH.Compat.CanUseNumber(dist) then
        return nil, nil, nil
    end
    return true, dist, nil
end

local function IsPhasedAway(unit)
    if UnitPhaseReason then
        local ok, reason = pcall(UnitPhaseReason, unit)
        if ok and reason then
            return true
        end
    end
    if UnitInPhase then
        local ok, inPhase = pcall(UnitInPhase, unit)
        if ok and inPhase == false then
            return true
        end
    end
    return false
end

--- LibRangeCheck-3.0 if another addon already loaded it.
local function TryLibRange(unit)
    if not LibStub then
        return nil, nil
    end
    local ok, rc = pcall(LibStub, "LibRangeCheck-3.0", true)
    if not ok or not rc or not rc.GetRange then
        return nil, nil
    end
    local ok2, minR, maxR = pcall(function()
        return rc:GetRange(unit)
    end)
    if not ok2 then
        return nil, nil
    end
    return minR, maxR
end

--- Coarse bands via CheckInteractDistance (nearby visible targets only).
local function TryInteractBand(unit)
    if not CheckInteractDistance then
        return nil, nil
    end
    local function inRange(idx)
        local ok, r = pcall(CheckInteractDistance, unit, idx)
        return ok and r and true or false
    end

    if inRange(3) then
        return 0, 8
    end
    if inRange(2) then
        return 0, 11
    end
    if inRange(4) or inRange(1) then
        return 8, 28
    end
    return 28, nil -- over 28, but only if unit is visible/local
end

local function FormatEstimate(exact, minR, maxR)
    if exact then
        return string.format("%d yards", RoundYards(exact))
    end
    if minR ~= nil and maxR ~= nil then
        if minR <= 0 then
            return string.format("within %d yards", RoundYards(maxR))
        end
        return string.format("between %d and %d yards", RoundYards(minR), RoundYards(maxR))
    end
    if minR ~= nil and maxR == nil then
        return string.format("over %d yards", RoundYards(minR))
    end
    return nil
end

--- Range phrase only (no name). Returns nil if unknown.
function Distance.DescribeTargetRange(unit)
    unit = unit or "target"
    if not UnitExists or not UnitExists(unit) then
        return nil
    end

    local same, yards, reason = SameInstanceDistance(unit)
    if same == false or reason == "different_area" then
        return "different area"
    end
    if IsPhasedAway(unit) then
        return "different phase"
    end
    if same == true and type(yards) == "number" then
        return FormatEstimate(yards, nil, nil)
    end

    local visible = true
    if UnitIsVisible then
        local ok, v = pcall(UnitIsVisible, unit)
        if ok then
            visible = v and true or false
        end
    end
    if not visible then
        return "different area"
    end

    local minR, maxR = TryLibRange(unit)
    if minR ~= nil then
        return FormatEstimate(nil, minR, maxR)
    end
    minR, maxR = TryInteractBand(unit)
    if minR ~= nil then
        return FormatEstimate(nil, minR, maxR)
    end
    return nil
end

function Distance.AnnounceTarget()
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if not Enabled() then
        Say("Target distance reading is disabled.")
        return
    end
    if not UnitExists("target") then
        Say("No target.")
        return
    end

    local name = UnitName("target")
    local prefix = ""
    if type(name) == "string" and name ~= "" then
        prefix = name .. ". "
    end

    local range = Distance.DescribeTargetRange("target")
    if not range then
        Say(prefix .. "Target range unknown.")
        return
    end
    if range == "different area" then
        Say(prefix .. "Target is in a different area.")
        return
    end
    if range == "different phase" then
        Say(prefix .. "Target is in a different phase.")
        return
    end
    Say(prefix .. "Target is " .. range .. ".")
end
