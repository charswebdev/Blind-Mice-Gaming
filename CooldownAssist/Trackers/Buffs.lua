--[[
  Cooldown Assist — player buff / aura fade tracking (Phase 5)
  Watches UNIT_AURA for helpful auras that match enabled tracked spells/items.
  Secret-safe for Midnight: only use readable fields; cache names on apply.
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Buffs = CA.Buffs or {}
local Buffs = CA.Buffs

-- [auraInstanceID] = { name = string, spellID = number|nil, key = string }
local active = {}
local lastFadeAt = {} -- [announceKey] = GetTime()
local FADE_DEBOUNCE = 1.25

local function SV()
    return CA.DB and CA.DB.Get and CA.DB.Get() or {}
end

local function MinDurationSec()
    local v = SV().minCooldownSeconds
    if type(v) ~= "number" or v < 0 then
        return 5
    end
    return v
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

local function CanUseNumber(v)
    if CA.Compat and CA.Compat.CanUseNumber then
        return CA.Compat.CanUseNumber(v)
    end
    return type(v) == "number"
end

local function CanUseString(v)
    if type(v) ~= "string" or v == "" then
        return false
    end
    if CA.Compat and CA.Compat.IsSecretValue and CA.Compat.IsSecretValue(v) then
        if canaccessvalue then
            local ok, access = pcall(canaccessvalue, v)
            return ok and access and true or false
        end
        return false
    end
    return true
end

local function SafeBool(v)
    if v == true then
        return true
    end
    if v == false then
        return false
    end
    if CA.Compat and CA.Compat.IsSecretValue and CA.Compat.IsSecretValue(v) then
        return nil
    end
    return nil
end

local function BuffsEnabled()
    local sv = SV()
    if sv.announceBuffFaded == false then
        return false
    end
    if sv.trackCategoryBuff == false then
        return false
    end
    if CA.DB and CA.DB.IsMasterEnabled and not CA.DB.IsMasterEnabled() then
        return false
    end
    return true
end

local function ResolveAnnounceName(spellID, auraName)
    if CA.Spells and CA.Spells.GetFadeAnnounceName then
        local name = CA.Spells.GetFadeAnnounceName(spellID, auraName)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    if CA.Items and CA.Items.GetFadeAnnounceName then
        local name = CA.Items.GetFadeAnnounceName(spellID, auraName)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
    return nil
end

local function ShouldWatchDuration(duration)
    -- Permanent / passive auras report 0.
    if type(duration) == "number" and CanUseNumber(duration) then
        if duration <= 0 then
            return false
        end
        return duration >= MinDurationSec()
    end
    -- Duration secret/unknown: allow watch when matched to a tracked entry.
    return true
end

local function RememberAura(aura)
    if type(aura) ~= "table" then
        return
    end
    local isHelpful = SafeBool(aura.isHelpful)
    if isHelpful == false then
        return
    end
    -- If helpful flag is unreadable, still try when we can match a tracked name/id.

    local instanceID = aura.auraInstanceID
    if not CanUseNumber(instanceID) then
        return
    end

    local spellID = aura.spellId
    if not CanUseNumber(spellID) then
        spellID = nil
    end

    local auraName = aura.name
    if not CanUseString(auraName) then
        auraName = nil
        if type(spellID) == "number" and C_Spell and C_Spell.GetSpellName then
            local n = SafeCall(C_Spell.GetSpellName, spellID)
            if CanUseString(n) then
                auraName = n
            end
        end
    end

    local duration = aura.duration
    if not CanUseNumber(duration) then
        duration = nil
    end
    if not ShouldWatchDuration(duration) then
        return
    end

    local announceName = ResolveAnnounceName(spellID, auraName)
    if not announceName then
        return
    end

    active[instanceID] = {
        name = announceName,
        spellID = spellID,
        key = tostring(spellID or announceName:lower()),
    }
end

local function ForgetAllSilent()
    wipe(active)
end

local function AnnounceFade(entry)
    if not entry or not BuffsEnabled() then
        return
    end
    local key = entry.key or entry.name
    local now = (GetTime and GetTime()) or 0
    local prev = lastFadeAt[key]
    if type(prev) == "number" and (now - prev) < FADE_DEBOUNCE then
        return
    end
    lastFadeAt[key] = now
    if CA.Announce and CA.Announce.Faded then
        local opts = nil
        if CA.Announce.OptsForEntry then
            opts = CA.Announce.OptsForEntry({
                name = entry.name,
                spellID = entry.spellID,
                key = (type(entry.spellID) == "number" and ("spell:" .. tostring(entry.spellID))) or nil,
            })
        end
        CA.Announce.Faded(entry.name, opts)
    end
end

local function OnRemoved(instanceID)
    if not CanUseNumber(instanceID) then
        return
    end
    local entry = active[instanceID]
    if not entry then
        return
    end
    active[instanceID] = nil
    AnnounceFade(entry)
end

local function RebuildFromUnitAuras()
    ForgetAllSilent()
    if not BuffsEnabled() then
        return
    end
    -- Retail / Midnight structured aura API.
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 80 do
            local aura = SafeCall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if type(aura) ~= "table" then
                break
            end
            RememberAura(aura)
        end
        return
    end
    -- Classic / older: UnitAura.
    if UnitAura then
        for i = 1, 40 do
            local name, _, _, _, duration, _, _, _, _, spellId = SafeCall(UnitAura, "player", i, "HELPFUL")
            if type(name) ~= "string" then
                break
            end
            RememberAura({
                name = name,
                duration = duration,
                spellId = spellId,
                isHelpful = true,
                auraInstanceID = i,
            })
        end
    end
end

function Buffs.Clear()
    ForgetAllSilent()
    wipe(lastFadeAt)
end

function Buffs.Resync()
    RebuildFromUnitAuras()
end

local eventFrame = CreateFrame("Frame")
if CA.Compat and CA.Compat.SafeRegisterUnitEvent then
    CA.Compat.SafeRegisterUnitEvent(eventFrame, "UNIT_AURA", "player")
else
    pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_AURA")
end
if CA.Compat and CA.Compat.SafeRegisterEvent then
    CA.Compat.SafeRegisterEvent(eventFrame, "PLAYER_ENTERING_WORLD")
    CA.Compat.SafeRegisterEvent(eventFrame, "PLAYER_REGEN_ENABLED")
else
    pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_ENTERING_WORLD")
    pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_REGEN_ENABLED")
end

eventFrame:SetScript("OnEvent", function(_, event, unit, updateInfo)
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then
        -- After combat, secrets often clear — rebuild watch list silently.
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, RebuildFromUnitAuras)
        else
            RebuildFromUnitAuras()
        end
        return
    end

    if event ~= "UNIT_AURA" or unit ~= "player" then
        return
    end
    if not BuffsEnabled() then
        return
    end

    if type(updateInfo) ~= "table" then
        RebuildFromUnitAuras()
        return
    end

    -- Secret-safe: never branch directly on possibly-secret booleans/tables.
    local okFull, isFull = pcall(function()
        return updateInfo.isFullUpdate == true
    end)
    if okFull and isFull then
        RebuildFromUnitAuras()
        return
    end

    pcall(function()
        local added = updateInfo.addedAuras
        if type(added) == "table" then
            for i = 1, #added do
                RememberAura(added[i])
            end
        end
    end)

    pcall(function()
        local removed = updateInfo.removedAuraInstanceIDs
        if type(removed) == "table" then
            for i = 1, #removed do
                OnRemoved(removed[i])
            end
        end
    end)
end)
