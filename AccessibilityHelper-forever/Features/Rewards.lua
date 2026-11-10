--[[
  Accessibility Helper — reward lines
  Experience, reputation, currency, gold, loot, quest completion, and achievements.
  The words come from the game. They are not printed.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Rewards = AH.Rewards or {}

local factions = {}
local currencies = {}
local recent = {}
local live = false
local seedGen = 0
local lastXP
local lastXPLevel
local lastMoney

local STANDING_NAMES = {
    [1] = "Hated",
    [2] = "Hostile",
    [3] = "Unfriendly",
    [4] = "Neutral",
    [5] = "Friendly",
    [6] = "Honored",
    [7] = "Revered",
    [8] = "Exalted",
}

local function Num(v)
    if AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(v) then
        return v
    end
    if type(v) == "number" then
        return v
    end
    return nil
end

local function Text(v)
    if AH.Compat and AH.Compat.UsableString then
        return AH.Compat.UsableString(v)
    end
    if type(v) == "string" and v ~= "" then
        return v
    end
    return nil
end

local function Flag(v)
    if AH.Compat and AH.Compat.CanUseValue and not AH.Compat.CanUseValue(v) then
        return nil
    end
    if v == true or v == 1 then
        return true
    end
    return false
end

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function On(key)
    return DB()[key] == true
end

local function Say(msg)
    msg = Text(msg)
    if not msg then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_INFO, { noEcho = true })
    end
end

local function Claim(key)
    local now = 0
    if GetTime then
        local ok, t = pcall(GetTime)
        if ok and type(t) == "number" then
            now = t
        end
    end
    local seen = recent[key]
    if type(seen) == "number" and (now - seen) >= 0 and (now - seen) < 0.6 then
        return false
    end
    recent[key] = now
    return true
end

local function Digits(n)
    n = Num(n)
    if not n then
        return nil
    end
    if n < 0 then
        n = 0
    end
    return tostring(math.floor(n + 0.5))
end

local function StandingName(id)
    id = Num(id)
    if not id then
        return nil
    end
    local label = _G["FACTION_STANDING_LABEL" .. tostring(id)]
    label = Text(label)
    if label then
        return label
    end
    return STANDING_NAMES[id]
end

local function BarSpan(value, barMin, barMax)
    value = Num(value)
    barMin = Num(barMin)
    barMax = Num(barMax)
    if not value or not barMax then
        return nil, nil
    end
    local current = value
    local cap = barMax
    if barMin and barMax > barMin then
        current = value - barMin
        cap = barMax - barMin
    end
    if current < 0 then
        current = 0
    end
    if cap <= 0 then
        return nil, nil
    end
    return current, cap
end

local function ConsiderFaction(id, name, standing, value, barMin, barMax)
    name = Text(name)
    if not name then
        return
    end
    standing = Num(standing)
    value = Num(value)
    local key = Num(id)
    if key then
        key = "id:" .. tostring(key)
    else
        key = "name:" .. string.lower(name)
    end
    local prev = factions[key]
    factions[key] = { standing = standing, value = value }
    if not live or not prev then
        return
    end
    if standing and prev.standing and standing ~= prev.standing then
        local label = StandingName(standing)
        if label and On("progressRepStanding") then
            Say("You have reached " .. label .. " with " .. name .. ".")
        end
        return
    end
    if not On("progressRep") or not value or not prev.value or value <= prev.value then
        return
    end
    local gain = Digits(value - prev.value)
    if not gain then
        return
    end
    local line = "You gained " .. gain .. " Reputation with " .. name .. "."
    local current, cap = BarSpan(value, barMin, barMax)
    local currentText = Digits(current)
    local capText = Digits(cap)
    if currentText and capText then
        line = line .. " Your reputation in " .. name .. " is: " .. currentText .. " / " .. capText .. "."
    end
    Say(line)
end

local function ScanFactions()
    if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        local ok, count = pcall(C_Reputation.GetNumFactions)
        count = ok and Num(count) or nil
        if not count then
            return
        end
        local i
        for i = 1, count do
            local dataOk, data = pcall(C_Reputation.GetFactionDataByIndex, i)
            if dataOk and type(data) == "table" then
                local header = Flag(data.isHeader)
                local withRep = Flag(data.isHeaderWithRep)
                local standing = Num(data.reaction)
                if not standing then
                    standing = Num(data.standingID)
                end
                if header == false or withRep == true then
                    ConsiderFaction(data.factionID, data.name, standing, data.currentStanding, data.currentReactionThreshold, data.nextReactionThreshold)
                end
            end
        end
        return
    end
    if not GetNumFactions or not GetFactionInfo then
        return
    end
    local ok, count = pcall(GetNumFactions)
    count = ok and Num(count) or nil
    if not count then
        return
    end
    local i
    for i = 1, count do
        local lineOk, name, _, standingID, barMin, barMax, barValue, _, _, isHeader, _, _, _, _, factionID =
            pcall(GetFactionInfo, i)
        if lineOk and Flag(isHeader) ~= true then
            ConsiderFaction(factionID, name, standingID, barValue, barMin, barMax)
        end
    end
end

local function CurrencyInfo(id)
    id = Num(id)
    if not id then
        return nil, nil
    end
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        if ok and type(info) == "table" then
            return Text(info.name), Num(info.quantity)
        end
    end
    if GetCurrencyInfo then
        local ok, name, amount = pcall(GetCurrencyInfo, id)
        if ok then
            return Text(name), Num(amount)
        end
    end
    return nil, nil
end

local function SpeakCurrency(name, gain, total)
    name = Text(name)
    gain = Num(gain)
    total = Num(total)
    if not name or not gain or gain <= 0 then
        return
    end
    if not On("lootCurrencyEnabled") then
        return
    end
    if not Claim("cur:" .. string.lower(name)) then
        return
    end
    local gainText = Digits(gain)
    if not gainText then
        return
    end
    Say("You gained " .. gainText .. " " .. name .. ".")
    local totalText = Digits(total)
    if totalText then
        Say("You now have " .. totalText .. " " .. name .. ".")
    end
end

local function HandleCurrency(currencyType, quantity, quantityChange)
    local id = Num(currencyType)
    if not id then
        return
    end
    local qty = Num(quantity)
    local gain = Num(quantityChange)
    if gain and gain < 0 then
        gain = nil
    end
    local infoName, infoTotal = CurrencyInfo(id)
    if not qty then
        qty = infoTotal
    end
    if not live then
        if qty then
            currencies[id] = qty
        end
        return
    end
    local prev = currencies[id]
    if qty then
        currencies[id] = qty
    end
    if not gain and qty and prev and qty > prev then
        gain = qty - prev
    end
    if not gain or gain <= 0 then
        return
    end
    SpeakCurrency(infoName, gain, qty)
end

local function HandleCurrencyChat(message)
    if not On("lootCurrencyEnabled") then
        return
    end
    local body = Text(message)
    if not body then
        return
    end
    local lower = string.lower(body)
    if string.find(lower, "you ", 1, true) ~= 1 and not string.find(lower, "you receive", 1, true) then
        return
    end
    local amount, name = string.match(body, "(%d+)%s+([%a][%a%-']*)")
    amount = Num(tonumber(amount))
    name = Text(name)
    if not amount or amount <= 0 or not name then
        return
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function()
            SpeakCurrency(name, amount, nil)
        end)
    else
        SpeakCurrency(name, amount, nil)
    end
end

local function MoneyPhrase(copper)
    copper = Num(copper)
    if not copper then
        return nil
    end
    if copper < 0 then
        copper = 0
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper - (gold * 10000)) / 100)
    local cu = copper - (gold * 10000) - (silver * 100)
    local parts = {}
    if gold > 0 then
        table.insert(parts, tostring(gold) .. " gold")
    end
    if silver > 0 then
        table.insert(parts, tostring(silver) .. " silver")
    end
    if cu > 0 or #parts == 0 then
        table.insert(parts, tostring(cu) .. " copper")
    end
    return table.concat(parts, ", ")
end

local function HandleMoney()
    if not GetMoney then
        return
    end
    local ok, money = pcall(GetMoney)
    money = ok and Num(money) or nil
    if not money then
        return
    end
    local prev = lastMoney
    lastMoney = money
    if not live or not prev or not On("rewardGold") or money <= prev then
        return
    end
    local gainWords = MoneyPhrase(money - prev)
    local totalWords = MoneyPhrase(money)
    if gainWords then
        Say("You gained " .. gainWords .. ".")
    end
    if totalWords then
        Say("You now have " .. totalWords .. ".")
    end
end

local function SpeakLoot(name, qty)
    if not On("lootItemsEnabled") then
        return
    end
    name = Text(name)
    if not name then
        return
    end
    if not Claim("loot:" .. string.lower(name)) then
        return
    end
    qty = Num(qty)
    if not qty or qty < 1 then
        qty = 1
    end
    local count = Digits(qty)
    if not count then
        count = "1"
    end
    Say("You looted: " .. name .. " x" .. count .. ".")
end

local function HandleLootWindow()
    if not GetNumLootItems or not GetLootSlotInfo then
        return
    end
    local ok, count = pcall(GetNumLootItems)
    count = ok and Num(count) or nil
    if not count or count < 1 then
        return
    end
    local i
    for i = 1, count do
        local slotOk, _, name, qty, currencyID = pcall(GetLootSlotInfo, i)
        if slotOk and not Num(currencyID) then
            SpeakLoot(name, qty)
            if AH.ChatProgress and AH.ChatProgress.SpeakPickup then
                AH.ChatProgress.SpeakPickup(name, qty)
            end
        end
    end
end

local function HandleLootChat(message)
    local body = Text(message)
    if not body then
        return
    end
    local lower = string.lower(body)
    if not string.find(lower, "you receive", 1, true) and not string.find(lower, "you loot", 1, true) then
        return
    end
    local name = Text(string.match(body, "%[(.-)%]"))
    local qty = Num(tonumber(string.match(body, "[xX]%s*(%d+)")))
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, function()
            SpeakLoot(name, qty)
            if AH.ChatProgress and AH.ChatProgress.SpeakPickup then
                AH.ChatProgress.SpeakPickup(name, qty)
            end
        end)
    else
        SpeakLoot(name, qty)
        if AH.ChatProgress and AH.ChatProgress.SpeakPickup then
            AH.ChatProgress.SpeakPickup(name, qty)
        end
    end
end

local function ReadXP()
    if not UnitXP then
        return nil, nil, nil
    end
    local ok, xp = pcall(UnitXP, "player")
    if not ok then
        return nil, nil, nil
    end
    xp = Num(xp)
    local maxXP
    if UnitXPMax then
        local maxOk, cap = pcall(UnitXPMax, "player")
        if maxOk then
            maxXP = Num(cap)
        end
    end
    local level
    if UnitLevel then
        local levelOk, value = pcall(UnitLevel, "player")
        if levelOk then
            level = Num(value)
        end
    end
    return xp, maxXP, level
end

local function HandleXP()
    local xp, maxXP, level = ReadXP()
    if not xp then
        return
    end
    local prevXP = lastXP
    local prevLevel = lastXPLevel
    lastXP, lastXPLevel = xp, level
    if not live or not On("progressXP") or not prevXP then
        return
    end
    if prevLevel and level and level > prevLevel then
        return
    end
    if xp <= prevXP then
        return
    end
    local gained = Digits(xp - prevXP)
    if not gained then
        return
    end
    if not Claim("xp:" .. gained) then
        return
    end
    Say("You gained " .. gained .. " experience.")
    local nowText = Digits(xp)
    local capText = Digits(maxXP)
    if nowText and capText then
        Say("Your experience is now: " .. nowText .. " / " .. capText .. ".")
    end
end

local function QuestTitle(questID)
    questID = Num(questID)
    if not questID then
        return nil
    end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, questID)
        title = ok and Text(title) or nil
        if title then
            return title
        end
    end
    if AH.QuestTitles then
        return Text(AH.QuestTitles[questID])
    end
    return nil
end

local function HandleQuestTurnIn(questID)
    if not live or not On("rewardQuestComplete") then
        return
    end
    local title = QuestTitle(questID)
    if title then
        Say("Quest complete. " .. title .. ".")
    else
        Say("Quest complete.")
    end
end

local function AchievementPoints()
    if not GetTotalAchievementPoints then
        return nil
    end
    local ok, points = pcall(GetTotalAchievementPoints)
    if not ok then
        return nil
    end
    return Num(points)
end

local function HandleAchievement(achievementID, alreadyEarned)
    if not live or not On("rewardAchievement") then
        return
    end
    if Flag(alreadyEarned) == true then
        return
    end
    achievementID = Num(achievementID)
    if not achievementID or not GetAchievementInfo then
        return
    end
    local ok, _, name = pcall(GetAchievementInfo, achievementID)
    name = ok and Text(name) or nil
    if not name then
        return
    end
    if not Claim("ach:" .. string.lower(name)) then
        return
    end
    Say("Achievement earned. " .. name .. ".")
    local points = Digits(AchievementPoints())
    if points then
        Say("You now have " .. points .. " achievement points.")
    end
end

local function Seed()
    live = false
    seedGen = seedGen + 1
    local gen = seedGen
    lastXP, _, lastXPLevel = ReadXP()
    if GetMoney then
        local ok, money = pcall(GetMoney)
        if ok then
            lastMoney = Num(money)
        end
    end
    ScanFactions()
    local function finish()
        if gen ~= seedGen then
            return
        end
        lastXP, _, lastXPLevel = ReadXP()
        if GetMoney then
            local ok, money = pcall(GetMoney)
            if ok then
                lastMoney = Num(money)
            end
        end
        ScanFactions()
        live = true
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(2, finish)
    else
        finish()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("UPDATE_FACTION")
frame:RegisterEvent("LOOT_READY")
frame:RegisterEvent("CHAT_MSG_LOOT")
local function TryEvent(name)
    pcall(frame.RegisterEvent, frame, name)
end
TryEvent("PLAYER_MONEY")
TryEvent("CURRENCY_DISPLAY_UPDATE")
TryEvent("CHAT_MSG_CURRENCY")
TryEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
TryEvent("QUEST_TURNED_IN")
TryEvent("ACHIEVEMENT_EARNED")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Seed()
        return
    end
    if event == "PLAYER_XP_UPDATE" then
        HandleXP()
        return
    end
    if event == "UPDATE_FACTION" then
        ScanFactions()
        return
    end
    if event == "PLAYER_MONEY" then
        HandleMoney()
        return
    end
    if event == "CURRENCY_DISPLAY_UPDATE" then
        HandleCurrency(...)
        return
    end
    if event == "CHAT_MSG_CURRENCY" or event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        HandleCurrencyChat(...)
        return
    end
    if event == "LOOT_READY" then
        HandleLootWindow()
        return
    end
    if event == "CHAT_MSG_LOOT" then
        HandleLootChat(...)
        return
    end
    if event == "QUEST_TURNED_IN" then
        HandleQuestTurnIn(...)
        return
    end
    if event == "ACHIEVEMENT_EARNED" then
        HandleAchievement(...)
    end
end)
