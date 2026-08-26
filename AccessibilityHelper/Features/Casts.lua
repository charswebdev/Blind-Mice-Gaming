--[[
  Accessibility Helper — cast / duration bars and interrupt-ready alerts
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Casts = AH.Casts or {}
local Casts = AH.Casts

local lastCastKey = {}
local lastInterruptKey = {}

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

local function CanUseValue(v)
    if AH.Compat and AH.Compat.CanUseValue then
        return AH.Compat.CanUseValue(v)
    end
    if AH.Compat and AH.Compat.IsSecretValue then
        return not AH.Compat.IsSecretValue(v)
    end
    return true
end

local function ForSpeech(text)
    if type(text) ~= "string" or not CanUseValue(text) then
        return ""
    end
    if AH.ChatText and AH.ChatText.ForSpeech then
        return AH.ChatText.ForSpeech(text)
    end
    return text
end

local function SafeCall(fn, ...)
    if not fn then
        return nil
    end
    local ok, a, b, c, d, e, f, g, h, i = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e, f, g, h, i
end

local function UnitLabel(unit)
    if unit == "player" then
        return nil
    end
    if unit == "target" then
        return "Target"
    end
    if unit == "focus" then
        return "Focus"
    end
    local bossIndex = unit and unit:match("^boss(%d+)$")
    if bossIndex then
        return "Boss " .. bossIndex
    end
    return "Enemy"
end

local function FormatSeconds(sec)
    if not CanUseNumber(sec) or sec <= 0 then
        return nil
    end
    sec = math.floor(sec + 0.5)
    if sec < 1 then
        sec = 1
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

local function ReadCast(unit)
    if not unit or not UnitExists or not SafeCall(UnitExists, unit) then
        return nil
    end

    local function fromInfo(fn, channel)
        if not fn then
            return nil
        end
        local name, text, texture, startMS, endMS, isTradeSkill, castID, notInterruptible, spellId = SafeCall(fn, unit)
        -- Midnight: nameplate casts return secret strings/numbers. type() is safe;
        -- comparing, concatenating, or using them as table keys is not.
        if type(name) ~= "string" then
            return nil
        end
        local usableName = ""
        if CanUseValue(name) then
            if name == "" then
                return nil
            end
            usableName = name
        end
        local remaining
        if CanUseNumber(endMS) then
            remaining = (endMS / 1000) - ((GetTime and GetTime()) or 0)
        end
        local interruptible
        if CanUseValue(notInterruptible) then
            interruptible = notInterruptible == false
        end
        local trade = false
        if CanUseValue(isTradeSkill) then
            trade = isTradeSkill and true or false
        end
        local id
        if CanUseValue(castID) then
            id = tostring(castID)
        elseif CanUseNumber(spellId) then
            id = tostring(spellId)
        elseif usableName ~= "" then
            id = usableName
        else
            id = "secret"
        end
        local spoken = ForSpeech(usableName)
        if spoken == "" then
            spoken = "a spell"
        end
        return {
            name = spoken,
            remaining = remaining,
            channel = channel,
            trade = trade,
            castID = id,
            interruptible = interruptible,
        }
    end

    return fromInfo(UnitCastingInfo, false) or fromInfo(UnitChannelInfo, true)
end

local function Hostile(unit)
    if unit == "player" then
        return false
    end
    if UnitCanAttack then
        local ok, attack = pcall(UnitCanAttack, "player", unit)
        if ok and attack then
            return true
        end
    end
    if UnitIsEnemy then
        local ok, enemy = pcall(UnitIsEnemy, "player", unit)
        if ok and enemy then
            return true
        end
    end
    return false
end

local function PlayerSilenced()
    if C_LossOfControl and C_LossOfControl.GetActiveLossOfControlDataCount then
        local count = SafeCall(C_LossOfControl.GetActiveLossOfControlDataCount) or 0
        for i = 1, count do
            local data = SafeCall(C_LossOfControl.GetActiveLossOfControlData, i)
            if type(data) == "table" then
                local locType = data.locType and string.upper(tostring(data.locType)) or ""
                if locType == "SILENCE" or locType == "PACIFY" or locType == "STUN" or locType == "STUN_MECHANIC" then
                    return true
                end
            end
        end
    end
    return false
end

local function AnnounceDuration(unit, info)
    if not On("castsEnabled") then
        return
    end
    if unit == "player" and not On("castsPlayerEnabled") then
        return
    end
    if unit ~= "player" and not On("castsEnemyEnabled") then
        return
    end
    if info.trade then
        return
    end
    if info.name == "" then
        return
    end

    local key = tostring(unit) .. ":" .. tostring(info.castID)
    if lastCastKey[unit] == key then
        return
    end
    lastCastKey[unit] = key

    local verb = info.channel and "channeling" or "casting"
    local parts = {}
    local who = UnitLabel(unit)
    if who then
        parts[#parts + 1] = who .. " " .. verb .. " " .. info.name
    else
        parts[#parts + 1] = (info.channel and "Channeling " or "Casting ") .. info.name
    end
    local rem = FormatSeconds(info.remaining)
    if rem then
        parts[#parts + 1] = rem
    end
    if unit ~= "player" then
        if info.interruptible == true then
            parts[#parts + 1] = "can interrupt"
        elseif info.interruptible == false then
            parts[#parts + 1] = "cannot interrupt"
        end
    end

    if AH.Alerts and AH.Alerts.Announce then
        local itemKey = (unit == "player") and "castsPlayerEnabled" or "castsEnemyEnabled"
        AH.Alerts.Announce("duration", table.concat(parts, ". ") .. ".", AH.Speech and AH.Speech.PRIORITY_CRITICAL, itemKey)
    elseif AH.Speech and AH.Speech.Say then
        AH.Speech.Say(table.concat(parts, ". ") .. ".", AH.Speech.PRIORITY_CRITICAL)
    end
end

local function AnnounceInterrupt(unit, info)
    if not On("interruptAlertEnabled") then
        return
    end
    if unit == "player" or not info.interruptible or not Hostile(unit) then
        return
    end
    if PlayerSilenced() then
        return
    end
    local key = tostring(unit) .. ":" .. tostring(info.castID)
    if lastInterruptKey[key] then
        return
    end
    lastInterruptKey[key] = true

    if AH.Alerts and AH.Alerts.Announce then
        AH.Alerts.Announce("interrupt", "Interrupt ready.", AH.Speech and AH.Speech.PRIORITY_CRITICAL, "interruptAlertEnabled")
    elseif AH.Sounds and AH.Sounds.PlaySelected then
        AH.Sounds.PlaySelected()
    end
end

local function HandleUnit(unit)
    if type(unit) ~= "string" or unit == "" then
        return
    end
    local info = ReadCast(unit)
    if not info then
        lastCastKey[unit] = nil
        return
    end
    AnnounceDuration(unit, info)
    AnnounceInterrupt(unit, info)
end

local function ClearUnit(unit)
    lastCastKey[unit] = nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_INTERRUPTIBLE")
pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
pcall(frame.RegisterEvent, frame, "PLAYER_FOCUS_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        lastCastKey = {}
        lastInterruptKey = {}
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        lastCastKey.target = nil
        HandleUnit("target")
        return
    end
    if event == "PLAYER_FOCUS_CHANGED" then
        lastCastKey.focus = nil
        HandleUnit("focus")
        return
    end
    if event == "UNIT_SPELLCAST_STOP"
        or event == "UNIT_SPELLCAST_CHANNEL_STOP"
        or event == "UNIT_SPELLCAST_INTERRUPTED"
        or event == "UNIT_SPELLCAST_FAILED"
    then
        ClearUnit(unit)
        return
    end
    if event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        lastCastKey[unit or ""] = nil
        HandleUnit(unit)
        return
    end
    if event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        HandleUnit(unit)
        return
    end
    HandleUnit(unit)
end)
