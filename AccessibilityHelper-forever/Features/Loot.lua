--[[
  Accessibility Helper — loot + currency announces
  Loot and currency speech moved to Features/Status.lua.
  This file stays loaded so older references to AH.Loot still resolve.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Loot = AH.Loot or {}
local Loot = AH.Loot

local lastLine = nil
local lastAt = 0
local DEDUPE_SEC = 0.35
local readyAt = 0

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function On(key)
    return DB()[key] ~= false
end

local function Say(msg)
    if type(msg) ~= "string" or msg == "" then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_INFO)
    else
        print("|cff66ccff[Helper]|r " .. msg)
    end
end

local function ForSpeech(text)
    if AH.ChatText and AH.ChatText.ForChatMessage then
        return AH.ChatText.ForChatMessage(text)
    end
    if AH.ChatText and AH.ChatText.ForSpeech then
        return AH.ChatText.ForSpeech(text)
    end
    return tostring(text or "")
end

local function Dedupe(key)
    local now = GetTime and GetTime() or 0
    if key == lastLine and (now - lastAt) < DEDUPE_SEC then
        return true
    end
    lastLine = key
    lastAt = now
    return false
end

local function SpeakExact(text, dedupeKey)
    local spoken = ForSpeech(text)
    if spoken == "" then
        return
    end
    if Dedupe(dedupeKey .. spoken) then
        return
    end
    Say(spoken)
end

local function HandleLoot(text)
    if not On("lootItemsEnabled") then
        return
    end
    SpeakExact(text, "loot:")
end

local function HandleCurrency(text)
    if not On("lootCurrencyEnabled") then
        return
    end
    SpeakExact(text, "cur:")
end

local function HandleHonor(text)
    if not On("lootCurrencyEnabled") then
        return
    end
    SpeakExact(text, "hon:")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_CURRENCY")
frame:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")

frame:SetScript("OnEvent", function()
end)
