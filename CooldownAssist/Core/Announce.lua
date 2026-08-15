--[[
  Cooldown Assist — announcement gate + phrasing (Phase 1)
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Announce = CA.Announce or {}
local Announce = CA.Announce

local function SV()
    return CA.DB and CA.DB.Get and CA.DB.Get() or {}
end

function Announce.InCombat()
    if not UnitAffectingCombat then
        return false
    end
    local ok, v = pcall(UnitAffectingCombat, "player")
    return ok and v and true or false
end

--- Groups that make sense outside combat (skyriding, hearth, teleports, toys).
local OUT_OF_COMBAT_GROUPS = {
    general = true,
    teleport = true,
    toys = true,
}

--- Auto readiness/charge/fade lines respect combat-only setting.
--- opts.outOfCombatOk / opts.group: allow announce while not in combat.
function Announce.CanAutoAnnounce(opts)
    if CA.DB and CA.DB.IsMasterEnabled and not CA.DB.IsMasterEnabled() then
        return false
    end
    local sv = SV()
    if sv.announceInCombatOnly == false then
        return true
    end
    opts = opts or {}
    if opts.outOfCombatOk == true then
        return true
    end
    local group = opts.group
    if type(group) == "string" and OUT_OF_COMBAT_GROUPS[group] then
        return true
    end
    -- Long combat CDs (Avenging Wrath ~2 min) usually finish between pulls.
    local major = 45
    if type(opts.majorSeconds) == "number" and opts.majorSeconds >= 5 then
        major = opts.majorSeconds
    elseif CA.DB and CA.DB.Get then
        local v = CA.DB.Get().majorCooldownSeconds
        if type(v) == "number" and v >= 5 then
            major = v
        end
    end
    if type(opts.observedDuration) == "number" and opts.observedDuration >= major then
        return true
    end
    return Announce.InCombat()
end

function Announce.Say(text, priority)
    if type(text) ~= "string" or text == "" then
        return
    end
    priority = priority or (CA.Speech and CA.Speech.PRIORITY_STATUS) or 2
    if CA.Speech and CA.Speech.Say then
        CA.Speech.Say(text, priority)
    else
        print("|cff66ccff[Cooldown Assist]|r " .. text)
    end
end

function Announce.Ready(name, opts)
    local sv = SV()
    if sv.announceReady == false then
        return
    end
    if not Announce.CanAutoAnnounce(opts) then
        return
    end
    if type(name) ~= "string" or name == "" then
        name = "Ability"
    end
    Announce.Say(name .. " ready.", CA.Speech and CA.Speech.PRIORITY_STATUS)
end

function Announce.Charge(name, opts)
    local sv = SV()
    if sv.announceCharges == false then
        return
    end
    if not Announce.CanAutoAnnounce(opts) then
        return
    end
    if type(name) ~= "string" or name == "" then
        name = "Ability"
    end
    Announce.Say(name .. " charge ready.", CA.Speech and CA.Speech.PRIORITY_STATUS)
end

function Announce.Faded(name, opts)
    local sv = SV()
    if sv.announceBuffFaded == false then
        return
    end
    if not Announce.CanAutoAnnounce(opts) then
        return
    end
    if type(name) ~= "string" or name == "" then
        name = "Buff"
    end
    Announce.Say(name .. " faded.", CA.Speech and CA.Speech.PRIORITY_STATUS)
end

--- Build announce opts for a tracker entry (spell or item row).
function Announce.OptsForEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end
    local group
    if CA.Categories and CA.Categories.ResolveGroup then
        group = CA.Categories.ResolveGroup(entry)
    end
    local outOfCombatOk = false
    if type(group) == "string" and OUT_OF_COMBAT_GROUPS[group] then
        outOfCombatOk = true
    end
    if entry.category == "general" then
        outOfCombatOk = true
    end
    if CA.Categories and CA.Categories.IsNonCombatUtilityName
        and CA.Categories.IsNonCombatUtilityName(entry.name)
    then
        outOfCombatOk = true
    end
    return {
        group = group,
        outOfCombatOk = outOfCombatOk,
        observedDuration = entry.observedDuration,
    }
end
