--[[
  BMG Unit Frames — client detection
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Compat = UF.Compat or {}
local Compat = UF.Compat

function Compat.GetInterfaceVersion()
    return select(4, GetBuildInfo()) or 0
end

function Compat.IsRetail()
    if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        return true
    end
    return Compat.GetInterfaceVersion() >= 100000
end

function Compat.IsMidnight()
    return Compat.GetInterfaceVersion() >= 120000
end

--- True if value is a Midnight secret. Never `if v` / compare a secret.
function Compat.IsSecretValue(v)
    if not issecretvalue then
        return false
    end
    local ok, secret = pcall(issecretvalue, v)
    return ok == true and secret == true
end

function Compat.CanUseValue(v)
    if not Compat.IsSecretValue(v) then
        return true
    end
    if canaccessvalue then
        local ok, access = pcall(canaccessvalue, v)
        if ok ~= true or Compat.IsSecretValue(access) then
            return false
        end
        return access == true
    end
    return false
end

function Compat.CanUseNumber(v)
    if Compat.IsSecretValue(v) then
        return false
    end
    local ok, typ = pcall(type, v)
    return ok == true and typ == "number" and Compat.CanUseValue(v)
end

function Compat.IsUsablePositive(v)
    return Compat.CanUseNumber(v) and v > 0
end

function Compat.UsableString(v)
    if Compat.IsSecretValue(v) then
        return nil
    end
    if type(v) ~= "string" or v == "" then
        return nil
    end
    return v
end

--- Usable number, or fallback. Second return is true only for a Midnight secret.
function Compat.SafeNumber(v, fallback)
    if Compat.IsSecretValue(v) then
        return fallback or 0, true
    end
    if Compat.CanUseNumber(v) then
        return v, false
    end
    return fallback or 0, false
end

local function CallUnit(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, v = pcall(fn, ...)
    if ok then
        return v
    end
    return nil
end

local function RoleToken(v)
    if v == "TANK" or v == "HEALER" or v == "DAMAGER" then
        return v
    end
    if v == "DAMAGE" or v == "DPS" then
        return "DAMAGER"
    end
    if type(v) == "number" then
        local tank, healer, damage = 0, 1, 2
        if Enum and Enum.LFGRole then
            tank = Enum.LFGRole.Tank or tank
            healer = Enum.LFGRole.Healer or healer
            damage = Enum.LFGRole.Damage or damage
        end
        if v == tank then
            return "TANK"
        end
        if v == healer then
            return "HEALER"
        end
        if v == damage then
            return "DAMAGER"
        end
    end
    return nil
end

--- Assigned group role: TANK, HEALER, DAMAGER, or nil. Era/TBC usually nil.
function Compat.GroupRole(unit)
    if type(unit) ~= "string" or unit == "" then
        return nil
    end
    local role = RoleToken(CallUnit(UnitGroupRolesAssigned, unit))
    if role then
        return role
    end
    if unit ~= "player" then
        return nil
    end
    if GetSpecialization and GetSpecializationRole then
        local spec = CallUnit(GetSpecialization)
        role = RoleToken(CallUnit(GetSpecializationRole, spec))
        if role then
            return role
        end
    end
    if GetTalentGroupRole then
        local group = 1
        if GetActiveTalentGroup then
            group = CallUnit(GetActiveTalentGroup) or 1
        end
        return RoleToken(CallUnit(GetTalentGroupRole, group))
    end
    return nil
end

function Compat.HealthPercent(unit)
    if type(UnitHealthPercent) ~= "function" then
        return nil
    end
    if CurveConstants and CurveConstants.ZeroToOne then
        local v = CallUnit(UnitHealthPercent, unit, true, CurveConstants.ZeroToOne)
        if v ~= nil then
            return v
        end
    end
    return CallUnit(UnitHealthPercent, unit, true)
end

function Compat.HealthPercentText(unit)
    if type(UnitHealthPercent) ~= "function" then
        return nil
    end
    if CurveConstants and CurveConstants.ScaleTo100 then
        local v = CallUnit(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
        if v ~= nil then
            return v
        end
    end
    return Compat.HealthPercent(unit)
end

function Compat.PowerPercent(unit, powerType)
    if type(UnitPowerPercent) ~= "function" then
        return nil
    end
    if CurveConstants and CurveConstants.ZeroToOne then
        local v
        if powerType ~= nil then
            v = CallUnit(UnitPowerPercent, unit, powerType, false, CurveConstants.ZeroToOne)
        else
            v = CallUnit(UnitPowerPercent, unit, nil, false, CurveConstants.ZeroToOne)
        end
        if v ~= nil then
            return v
        end
    end
    if powerType ~= nil then
        return CallUnit(UnitPowerPercent, unit, powerType)
    end
    return CallUnit(UnitPowerPercent, unit)
end

function Compat.PowerPercentText(unit, powerType)
    if type(UnitPowerPercent) ~= "function" then
        return nil
    end
    if CurveConstants and CurveConstants.ScaleTo100 then
        local v
        if powerType ~= nil then
            v = CallUnit(UnitPowerPercent, unit, powerType, false, CurveConstants.ScaleTo100)
        else
            v = CallUnit(UnitPowerPercent, unit, nil, false, CurveConstants.ScaleTo100)
        end
        if v ~= nil then
            return v
        end
    end
    return Compat.PowerPercent(unit, powerType)
end

function Compat.ApplyBar(bar, cur, maxh, pct)
    if not bar then
        return
    end
    if Compat.CanUseNumber(maxh) and maxh > 0 and (cur ~= nil) then
        bar:SetMinMaxValues(0, maxh)
        pcall(bar.SetValue, bar, cur)
        return
    end
    if pct ~= nil then
        bar:SetMinMaxValues(0, 1)
        pcall(bar.SetValue, bar, pct)
        return
    end
    if cur ~= nil and maxh ~= nil then
        pcall(bar.SetMinMaxValues, bar, 0, maxh)
        pcall(bar.SetValue, bar, cur)
        return
    end
    if Compat.CanUseNumber(maxh) and maxh > 0 then
        bar:SetMinMaxValues(0, maxh)
        if cur ~= nil then
            pcall(bar.SetValue, bar, cur)
        end
    end
end

function Compat.ApplyPercentText(fs, value, suffix)
    if not fs then
        return false
    end
    if value == nil then
        return false
    end
    suffix = suffix or "%%"
    if fs.SetFormattedText then
        if pcall(fs.SetFormattedText, fs, "%d" .. suffix, value) then
            return true
        end
        if pcall(fs.SetFormattedText, fs, "%.0f" .. suffix, value) then
            return true
        end
    end
    if Compat.CanUseNumber(value) then
        fs:SetText(string.format("%d%%", math.floor(value + 0.5)))
        return true
    end
    return false
end

function Compat.UnitNameOf(unit)
    if type(unit) ~= "string" or not UnitName then
        return unit or "Unknown"
    end
    local ok, name = pcall(UnitName, unit)
    if not ok then
        return unit
    end
    return Compat.UsableString(name) or unit
end

--- cur, max, pct (may be secret), unknown, secret
--- Do not arithmetic/format secret returns. Pass them to StatusBar:SetValue / SetFormattedText.
function Compat.Health(unit)
    local cur = CallUnit(UnitHealth, unit)
    local maxh = CallUnit(UnitHealthMax, unit)
    local pct = Compat.HealthPercent(unit)
    local secret = Compat.IsSecretValue(cur) or Compat.IsSecretValue(maxh) or Compat.IsSecretValue(pct)
    local unknown = false
    if not secret and Compat.CanUseNumber(cur) and Compat.CanUseNumber(maxh) and maxh > 0 then
        pct = cur / maxh
        if UnitCanAttack and UnitIsFriend then
            local hostile = UnitCanAttack("player", unit) and not UnitIsFriend("player", unit)
            if hostile and maxh <= 100 then
                unknown = true
            end
        end
    end
    return cur, maxh, pct, unknown, secret
end

function Compat.BackdropTemplate()
    if BackdropTemplateMixin then
        return "BackdropTemplate"
    end
    return nil
end

function Compat.HasFocusToken()
    if Compat.IsRetail() then
        return true
    end
    if type(UnitExists) ~= "function" then
        return false
    end
    local ok, exists = pcall(UnitExists, "focus")
    if ok == true and exists == true then
        return true
    end
    -- TBC+ still has the token even when no focus is set.
    if WOW_PROJECT_ID and WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        return false
    end
    if LE_EXPANSION_LEVEL_CURRENT and LE_EXPANSION_CLASSIC and LE_EXPANSION_LEVEL_CURRENT > LE_EXPANSION_CLASSIC then
        return true
    end
    return false
end

function Compat.HasArenaTokens()
    if Compat.IsRetail() then
        return true
    end
    if WOW_PROJECT_ID and WOW_PROJECT_CLASSIC and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
        return false
    end
    if type(IsActiveBattlefieldArena) == "function" or type(IsInArena) == "function" then
        return true
    end
    if LE_EXPANSION_LEVEL_CURRENT and LE_EXPANSION_BURNING_CRUSADE
        and LE_EXPANSION_LEVEL_CURRENT >= LE_EXPANSION_BURNING_CRUSADE then
        return true
    end
    return false
end

function Compat.InCombat()
    if type(InCombatLockdown) == "function" then
        local ok, locked = pcall(InCombatLockdown)
        if ok == true then
            return locked == true
        end
    end
    return UnitAffectingCombat and UnitAffectingCombat("player") == true
end

function Compat.CharacterKey()
    local name = Compat.UnitNameOf("player")
    local realm = "Realm"
    if GetRealmName then
        local ok, v = pcall(GetRealmName)
        if ok then
            realm = Compat.UsableString(v) or "Realm"
        end
    end
    return tostring(name) .. " - " .. tostring(realm)
end

function Compat.CopyToClipboard(text)
    if type(text) ~= "string" or text == "" then
        return false
    end
    if type(CopyToClipboard) == "function" then
        local ok = pcall(CopyToClipboard, text)
        if ok then
            return true
        end
    end
    return false
end

local BLIZZ_MAP = {
    player = { "PlayerFrame" },
    pet = { "PetFrame" },
    target = { "TargetFrame" },
    tot = { "TargetFrameToT", "TargetFrameToTFrame" },
    focus = { "FocusFrame" },
    party = { "PartyMemberFrame1", "CompactPartyFrameMember1", "CompactPartyFrame", "PartyFrame" },
    raid = { "CompactRaidFrameContainer", "CompactRaidFrameManager" },
    arena = { "CompactArenaFrameMember1", "CompactArenaFrame", "ArenaEnemyMatchFrame1", "ArenaEnemyMatchFramesContainer", "ArenaEnemyFrames", "ArenaEnemyFrame1" },
}

local function Child(parent, key)
    if type(parent) ~= "table" then
        return nil
    end
    local f = parent[key]
    if type(f) == "table" and f.GetLeft then
        return f
    end
    return nil
end

function Compat.AbsPoint(frame)
    if not frame or not frame.GetLeft then
        return nil
    end
    local left, bottom = frame:GetLeft(), frame:GetBottom()
    if type(left) == "number" and type(bottom) == "number" then
        local scale = 1
        if frame.GetEffectiveScale and UIParent and UIParent.GetEffectiveScale then
            local us = UIParent:GetEffectiveScale()
            if type(us) == "number" and us > 0 then
                scale = (frame:GetEffectiveScale() or 1) / us
            end
        end
        return { point = "BOTTOMLEFT", x = left * scale, y = bottom * scale }
    end
    if frame.GetPoint then
        local point, _, _, x, y = frame:GetPoint(1)
        if point then
            return { point = point, x = x or 0, y = y or 0 }
        end
    end
    return nil
end

function Compat.CaptureBlizzard()
    local out = {}
    for id, names in pairs(BLIZZ_MAP) do
        for i = 1, #names do
            local frame = _G[names[i]]
            local pos = Compat.AbsPoint(frame)
            if pos then
                out[id] = pos
                break
            end
        end
    end
    local partyFrame = _G.PartyFrame
    if partyFrame and not out.party then
        local member = Child(partyFrame, "MemberFrame1") or Child(partyFrame, "memberFrame1")
        out.party = Compat.AbsPoint(member) or Compat.AbsPoint(partyFrame)
    end
    local tot = _G.TargetFrame
    if tot and not out.tot then
        out.tot = Compat.AbsPoint(Child(tot, "totFrame") or Child(tot, "ToT"))
    end
    local focus = _G.FocusFrame
    if focus and not out.focus then
        out.focus = Compat.AbsPoint(focus)
    end
    for i = 1, 5 do
        local pos = Compat.AbsPoint(_G["PartyMemberFrame" .. i])
            or Compat.AbsPoint(_G["CompactPartyFrameMember" .. i])
            or Compat.AbsPoint(partyFrame and (partyFrame["MemberFrame" .. i] or partyFrame["memberFrame" .. i]))
        if pos then
            out["party" .. i] = pos
        end
    end
    return out
end

function Compat.Aura(unit, index, filter)
    filter = filter or "HELPFUL"
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local data = C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
        if not data then
            return nil
        end
        return data.name, data.icon, data.applications or data.charges or 0, data.dispelName, data.duration, data.expirationTime, data.sourceUnit, data.isStealable, nil, data.spellId
    end
    if UnitAura then
        local ok, a, b, c, d, e, f, g, h, i, j = pcall(UnitAura, unit, index, filter)
        if ok and a then
            return a, b, c, d, e, f, g, h, i, j
        end
    end
    if filter == "HARMFUL" and UnitDebuff then
        local ok, a, b, c, d, e, f, g, h, i, j = pcall(UnitDebuff, unit, index)
        if ok then
            return a, b, c, d, e, f, g, h, i, j
        end
    elseif UnitBuff then
        local ok, a, b, c, d, e, f, g, h, i, j = pcall(UnitBuff, unit, index)
        if ok then
            return a, b, c, d, e, f, g, h, i, j
        end
    end
    return nil
end

function Compat.Absorbs(unit)
    if UnitGetTotalAbsorbs then
        local ok, n = pcall(UnitGetTotalAbsorbs, unit)
        if ok then
            local value = Compat.SafeNumber(n, 0)
            return value
        end
    end
    return 0
end

function Compat.HealAbsorbs(unit)
    if UnitGetTotalHealAbsorbs then
        local ok, n = pcall(UnitGetTotalHealAbsorbs, unit)
        if ok then
            local value = Compat.SafeNumber(n, 0)
            return value
        end
    end
    return 0
end

function Compat.Threat(unit)
    if not unit or not UnitThreatSituation then
        return 0
    end
    local ok, n = pcall(UnitThreatSituation, unit)
    if ok and type(n) == "number" then
        return n
    end
    return 0
end

function Compat.IncomingHeals(unit)
    if UnitGetIncomingHeals then
        local ok, n = pcall(UnitGetIncomingHeals, unit)
        if ok then
            local value = Compat.SafeNumber(n, 0)
            return value
        end
    end
    return 0
end

function Compat.CastInfo(unit)
    local fn = UnitCastingInfo or (unit == "player" and CastingInfo)
    if fn then
        local ok, name, _, texture, startTime, endTime, _, _, notInterruptible = pcall(fn, unit)
        if ok and name then
            return name, texture, startTime, endTime, notInterruptible, false
        end
    end
    fn = UnitChannelInfo or (unit == "player" and ChannelInfo)
    if fn then
        local ok, name, _, texture, startTime, endTime, _, notInterruptible = pcall(fn, unit)
        if ok and name then
            return name, texture, startTime, endTime, notInterruptible, true
        end
    end
    return nil
end

function Compat.IsPhased(unit)
    if not unit or (UnitIsUnit and UnitIsUnit(unit, "player")) then
        return false
    end
    if UnitIsConnected and not UnitIsConnected(unit) then
        return false
    end
    if UnitPhaseReason then
        local ok, reason = pcall(UnitPhaseReason, unit)
        if ok and reason then
            return true
        end
        if ok then
            return false
        end
    end
    if UnitInPhase then
        local ok, same = pcall(UnitInPhase, unit)
        if ok then
            return same ~= true
        end
    end
    if UnitIsSamePhase then
        local ok, same = pcall(UnitIsSamePhase, unit)
        if ok then
            return same ~= true
        end
    end
    return false
end

local questNames = {}
local questNamesAt = 0

local function RememberQuestText(text)
    text = Compat.UsableString(text)
    if not text then
        return
    end
    local obj = text:match("^(.+):")
    if obj then
        obj = obj:gsub("%s+$", "")
        if obj ~= "" then
            questNames[obj] = true
        end
    end
end

local function RefreshQuestNames()
    local now = GetTime and GetTime() or 0
    if now - questNamesAt < 1.5 then
        return
    end
    questNamesAt = now
    for k in pairs(questNames) do
        questNames[k] = nil
    end
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local n = C_QuestLog.GetNumQuestLogEntries() or 0
        for i = 1, n do
            local info = C_QuestLog.GetInfo and C_QuestLog.GetInfo(i)
            local qid = info and info.questID
            if qid and C_QuestLog.GetQuestObjectives then
                local ok, objs = pcall(C_QuestLog.GetQuestObjectives, qid)
                if ok and type(objs) == "table" then
                    for j = 1, #objs do
                        if objs[j] then
                            RememberQuestText(objs[j].text)
                        end
                    end
                end
            end
        end
        return
    end
    if not GetNumQuestLogEntries then
        return
    end
    local n = GetNumQuestLogEntries() or 0
    for i = 1, n do
        local count = GetNumQuestLeaderBoards and GetNumQuestLeaderBoards(i)
        if type(count) == "number" then
            for j = 1, count do
                local text = GetQuestLogLeaderBoard and GetQuestLogLeaderBoard(j, i)
                RememberQuestText(text)
            end
        end
    end
end

function Compat.IsQuestUnit(unit)
    if not unit or (UnitIsPlayer and UnitIsPlayer(unit)) then
        return false
    end
    if UnitIsQuestBoss then
        local ok, v = pcall(UnitIsQuestBoss, unit)
        if ok and v then
            return true
        end
    end
    if C_QuestLog and C_QuestLog.UnitIsQuestBoss then
        local ok, v = pcall(C_QuestLog.UnitIsQuestBoss, unit)
        if ok and v then
            return true
        end
    end
    RefreshQuestNames()
    local name = Compat.UnitNameOf(unit)
    return type(name) == "string" and questNames[name] == true
end

function Compat.InRange(unit)
    if UnitIsUnit and UnitIsUnit(unit, "player") then
        return true
    end
    if UnitInRange then
        local ok, inRange, checked = pcall(UnitInRange, unit)
        if ok and checked then
            return inRange and true or false
        end
    end
    if CheckInteractDistance then
        local ok, near = pcall(CheckInteractDistance, unit, 4)
        if ok then
            return near and true or false
        end
    end
    return true
end

function Compat.Detect()
    Compat.hasFocus = Compat.HasFocusToken()
    Compat.hasArena = Compat.HasArenaTokens()
    Compat.interface = Compat.GetInterfaceVersion()
    Compat.isRetail = Compat.IsRetail()
    Compat.isMidnight = Compat.IsMidnight()
    return Compat
end
