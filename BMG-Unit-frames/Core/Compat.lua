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

function Compat.BackdropTemplate()
    if BackdropTemplateMixin then
        return "BackdropTemplate"
    end
    return nil
end

function Compat.HasFocusToken()
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
    local name = (UnitName and UnitName("player")) or "Unknown"
    local realm = (GetRealmName and GetRealmName()) or "Realm"
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
    tot = { "TargetFrameToT" },
    focus = { "FocusFrame" },
    party = { "PartyMemberFrame1", "CompactPartyFrame", "PartyFrame" },
    raid = { "CompactRaidFrameContainer", "CompactRaidFrameManager" },
    arena = { "ArenaEnemyFrames", "ArenaEnemyFrame1" },
}

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
    for i = 1, 4 do
        local pos = Compat.AbsPoint(_G["PartyMemberFrame" .. i])
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
        if ok and type(n) == "number" then
            return n
        end
    end
    return 0
end

function Compat.HealAbsorbs(unit)
    if UnitGetTotalHealAbsorbs then
        local ok, n = pcall(UnitGetTotalHealAbsorbs, unit)
        if ok and type(n) == "number" then
            return n
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
        if ok and type(n) == "number" then
            return n
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

local function RefreshQuestNames()
    local now = GetTime and GetTime() or 0
    if now - questNamesAt < 1.5 then
        return
    end
    questNamesAt = now
    for k in pairs(questNames) do
        questNames[k] = nil
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
                if type(text) == "string" then
                    local obj = text:match("^(.+):")
                    if obj then
                        obj = obj:gsub("%s+$", "")
                        if obj ~= "" then
                            questNames[obj] = true
                        end
                    end
                end
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
    local name = UnitName and UnitName(unit)
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
    return Compat
end
