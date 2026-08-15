--[[
  Accessibility Helper — Battle.net friend online / offline announces
  Speaks: Battle Net Friend <BN icon> - <username> has come Online/Offline!
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.BNFriends = AH.BNFriends or {}
local BNFriends = AH.BNFriends

local readyAt = 0
local lastLine = nil
local lastAt = 0
local DEDUPE_SEC = 1.0
local BN_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-Battlenet:14:14:0:-1|t"

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function Enabled()
    return DB().stateBNFriends ~= false
end

local function Say(msg)
    if type(msg) ~= "string" or msg == "" then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_STATUS)
    else
        print("|cff66ccff[Helper]|r " .. msg)
    end
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

local function SafeCall(fn, ...)
    if not fn then
        return nil
    end
    local ok, a, b, c, d = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d
end

--- Prefer BattleTag nickname; fall back to account display name.
local function FriendUsername(friendId)
    if type(friendId) ~= "number" then
        return nil
    end

    if C_BattleNet and C_BattleNet.GetAccountInfoByID then
        local info = SafeCall(C_BattleNet.GetAccountInfoByID, friendId)
        if type(info) == "table" then
            local tag = info.battleTag
            if type(tag) == "string" and tag ~= "" then
                return tag:match("^([^#]+)") or tag
            end
            local accountName = info.accountName
            if type(accountName) == "string" and accountName ~= "" then
                if AH.ChatText and AH.ChatText.ForSpeech then
                    accountName = AH.ChatText.ForSpeech(accountName)
                end
                if accountName ~= "" then
                    return accountName
                end
            end
        end
    end

    -- Legacy fallback
    if BNGetFriendInfoByID then
        local _, accountName, battleTag = SafeCall(BNGetFriendInfoByID, friendId)
        if type(battleTag) == "string" and battleTag ~= "" then
            return battleTag:match("^([^#]+)") or battleTag
        end
        if type(accountName) == "string" and accountName ~= "" then
            if AH.ChatText and AH.ChatText.ForSpeech then
                accountName = AH.ChatText.ForSpeech(accountName)
            end
            if accountName ~= "" then
                return accountName
            end
        end
    end

    return nil
end

local function Announce(friendId, online)
    if not Enabled() then
        return
    end
    local now = GetTime and GetTime() or 0
    if now < readyAt then
        return
    end

    local name = FriendUsername(friendId) or "Unknown"
    local state = online and "Online" or "Offline"
    local line = string.format("Battle Net Friend %s - %s has come %s!", BN_ICON, name, state)
    local key = tostring(friendId) .. ":" .. state .. ":" .. name
    if Dedupe(key) then
        return
    end
    Say(line)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
frame:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        -- Skip the flood of online events while the friend list settles after login.
        readyAt = (GetTime and GetTime() or 0) + 5
        return
    end
    if event == "BN_FRIEND_ACCOUNT_ONLINE" then
        local friendId = ...
        Announce(friendId, true)
        return
    end
    if event == "BN_FRIEND_ACCOUNT_OFFLINE" then
        local friendId = ...
        Announce(friendId, false)
        return
    end
end)
