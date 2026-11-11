--[[
  Accessibility Helper — red UI error messages
  Speaks the message in the middle of the screen.
  "Spell is not ready yet" stays quiet.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.UIErrors = AH.UIErrors or {}
local UIErrors = AH.UIErrors

local lastMsg = nil
local lastAt = 0

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function Enabled()
    return DB().uiErrorsEnabled == true
end

local function Now()
    if not GetTime then
        return 0
    end
    local ok, t = pcall(GetTime)
    if ok ~= true then
        return 0
    end
    if AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(t) then
        return t
    end
    if type(t) == "number" then
        return t
    end
    return 0
end

local function Plain(v)
    if AH.Compat and AH.Compat.UsableString then
        return AH.Compat.UsableString(v)
    end
    if type(v) == "string" and v ~= "" then
        return v
    end
    return nil
end

local function Same(a, b)
    if AH.Compat and AH.Compat.CanUseValue then
        if not AH.Compat.CanUseValue(a) or not AH.Compat.CanUseValue(b) then
            return false
        end
    end
    if a == nil or b == nil then
        return false
    end
    return a == b
end

local function CooldownSec()
    local v = DB().uiErrorCooldownSec
    if type(v) ~= "number" then
        return 1
    end
    if v < 0 then
        return 0
    end
    return v
end

local function ForSpeech(text)
    text = Plain(text)
    if not text then
        return ""
    end
    if AH.ChatText and AH.ChatText.ForChatMessage then
        return Plain(AH.ChatText.ForChatMessage(text)) or ""
    end
    if AH.ChatText and AH.ChatText.ForSpeech then
        return Plain(AH.ChatText.ForSpeech(text)) or ""
    end
    text = text:gsub("|T.-|t", " ")
    text = text:gsub("|A.-|a", " ")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("%s+", " ")
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Say(msg)
    msg = Plain(msg)
    if not msg then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_CRITICAL, { noEcho = true })
    end
end

local function NumberCode(globalName)
    local v = _G[globalName]
    if AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(v) then
        return v
    end
    if type(v) == "number" then
        return v
    end
    return nil
end

local function IsNotReady(messageType, text)
    local spellCd = NumberCode("LE_GAME_ERR_SPELL_COOLDOWN")
    local abilityCd = NumberCode("LE_GAME_ERR_ABILITY_COOLDOWN")
    if Same(messageType, spellCd) or Same(messageType, abilityCd) then
        return true
    end
    local spellText = ForSpeech(_G.ERR_SPELL_COOLDOWN)
    local abilityText = ForSpeech(_G.ERR_ABILITY_COOLDOWN)
    if spellText ~= "" and text == spellText then
        return true
    end
    if abilityText ~= "" and text == abilityText then
        return true
    end
    local lower = string.lower(text)
    if lower == "spell is not ready yet." or lower == "ability is not ready yet." then
        return true
    end
    if lower:find("spell is not ready", 1, true) or lower:find("ability is not ready", 1, true) then
        return true
    end
    return false
end

function UIErrors.Announce(message, messageType)
    if not Enabled() then
        return
    end
    local text = ForSpeech(message)
    if text == "" then
        return
    end
    if IsNotReady(messageType, text) then
        return
    end
    local now = Now()
    if text == lastMsg and (now - lastAt) < CooldownSec() then
        return
    end
    lastMsg = text
    lastAt = now
    Say(text)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("UI_ERROR_MESSAGE")
frame:SetScript("OnEvent", function(self, event, ...)
    local a1, a2 = ...
    local messageType, message
    if Plain(a2) then
        messageType = a1
        message = a2
    elseif Plain(a1) then
        message = a1
    else
        return
    end
    UIErrors.Announce(message, messageType)
end)
