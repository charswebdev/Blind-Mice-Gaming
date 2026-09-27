--[[
  Accessibility Helper — red UI error messages (Phase 6.2)
  Reads top-middle UIErrorsFrame messages (UI_ERROR_MESSAGE).
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.UIErrors = AH.UIErrors or {}
local UIErrors = AH.UIErrors

local lastMsg = nil
local lastAt = 0

local function Enabled()
    local sv = AH.DB and AH.DB.Get and AH.DB.Get()
    return not sv or sv.uiErrorsEnabled ~= false
end

local function CooldownSec()
    local sv = AH.DB and AH.DB.Get and AH.DB.Get()
    local v = sv and sv.uiErrorCooldownSec
    if type(v) ~= "number" then
        return 1.0
    end
    if v < 0 then
        return 0
    end
    return v
end

local function Strip(s)
    if AH.ChatText and AH.ChatText.ForChatMessage then
        return AH.ChatText.ForChatMessage(s)
    end
    if AH.ChatText and AH.ChatText.ForSpeech then
        return AH.ChatText.ForSpeech(s)
    end
    if type(s) ~= "string" then
        return ""
    end
    s = s:gsub("|T.-|t", " ")
    s = s:gsub("|A.-|a", " ")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1")
    s = s:gsub("%s+", " ")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Say(msg)
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_CRITICAL)
    else
        print("|cff66ccff[Helper]|r " .. tostring(msg))
    end
end

local function IsIgnoredNotReady(messageType, text)
    -- Prefer messageType when available (locale-safe).
    local spellCd = _G.LE_GAME_ERR_SPELL_COOLDOWN
        or (Enum and Enum.LE_GAME_ERR_SPELL_COOLDOWN)
        or (Enum and Enum.UIErrorMessages and Enum.UIErrorMessages.ERR_SPELL_COOLDOWN)
    local abilityCd = _G.LE_GAME_ERR_ABILITY_COOLDOWN
        or (Enum and Enum.LE_GAME_ERR_ABILITY_COOLDOWN)
    if messageType ~= nil then
        if spellCd ~= nil and messageType == spellCd then
            return true
        end
        if abilityCd ~= nil and messageType == abilityCd then
            return true
        end
    end

    -- Locale string globals.
    if _G.ERR_SPELL_COOLDOWN and text == Strip(_G.ERR_SPELL_COOLDOWN) then
        return true
    end
    if _G.ERR_ABILITY_COOLDOWN and text == Strip(_G.ERR_ABILITY_COOLDOWN) then
        return true
    end

    -- English fallback patterns.
    local lower = string.lower(text)
    if lower == "spell is not ready yet."
        or lower == "ability is not ready yet."
        or lower:find("spell is not ready", 1, true)
        or lower:find("ability is not ready", 1, true)
    then
        return true
    end
    return false
end

function UIErrors.Announce(message, messageType)
    if not Enabled() then
        return
    end
    local text = Strip(message)
    if text == "" then
        return
    end
    if IsIgnoredNotReady(messageType, text) then
        return
    end

    local now = GetTime and GetTime() or 0
    local cd = CooldownSec()
    if text == lastMsg and (now - lastAt) < cd then
        return
    end
    lastMsg = text
    lastAt = now
    Say(text)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(self, event, ...)
    -- Retail: messageType, message
    -- Some clients: message only / arg order differs — accept either.
    local a1, a2 = ...
    local messageType, message
    if type(a2) == "string" then
        messageType = a1
        message = a2
    elseif type(a1) == "string" then
        message = a1
    else
        return
    end
    UIErrors.Announce(message, messageType)
end)
