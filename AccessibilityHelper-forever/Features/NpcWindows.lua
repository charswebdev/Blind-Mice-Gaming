--[[
  Accessibility Helper — NPC windows, merchant sales, repair, and quest text.
  These lines are not chat messages. Read chat does not have to be on.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

local recent = {}
local live = false
local seedGen = 0
local bagTotals = {}
local moneySnap = nil
local sellWait = false
local saleHold = nil
local repairPending = false
local repairBefore = nil
local repairHooked = false
local logShown = false
local logSelection = nil

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
    if type(seen) == "number" and (now - seen) >= 0 and (now - seen) < 0.8 then
        return false
    end
    recent[key] = now
    return true
end

local function Clean(v)
    local text = Text(v)
    if not text then
        return nil
    end
    text = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "|H.-|h", "")
    text = string.gsub(text, "|h", "")
    text = string.gsub(text, "\n", " ")
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return Text(text)
end

local function MoneyPhrase(copper)
    copper = Num(copper)
    if not copper or copper <= 0 then
        return nil
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
    if cu > 0 then
        table.insert(parts, tostring(cu) .. " copper")
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, ", ")
end

local function Shown(frame)
    return frame and frame.IsShown and frame:IsShown()
end

local function NpcName()
    if UnitName then
        local ok, name = pcall(UnitName, "npc")
        if ok then
            return Clean(name)
        end
    end
    return nil
end

local function Later(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
    else
        fn()
    end
end

local function OneObjective(line)
    line = Text(line)
    if not line then
        return nil
    end
    line = string.gsub(line, "|c%x%x%x%x%x%x%x%x", "")
    line = string.gsub(line, "|r", "")
    line = string.gsub(line, "%s+", " ")
    line = Clean(line)
    if not line then
        return nil
    end
    local label, cur, need = string.match(line, "^(.-)%s*:%s*(%d+)%s*/%s*(%d+)%s*$")
    if not cur then
        cur, need, label = string.match(line, "^(%d+)%s*/%s*(%d+)%s+(.+)$")
    end
    local curN = Num(tonumber(cur))
    local needN = Num(tonumber(need))
    label = Clean(label)
    if label and curN and needN then
        return label .. ", " .. tostring(curN) .. " / " .. tostring(needN)
    end
    return line
end

local function ObjectiveList(blob)
    local pieces = {}
    blob = Text(blob)
    if not blob then
        return pieces
    end
    local line
    for line in string.gmatch(blob, "[^\n]+") do
        local piece = OneObjective(line)
        if piece then
            table.insert(pieces, piece)
        end
    end
    if #pieces == 0 then
        local piece = OneObjective(blob)
        if piece then
            table.insert(pieces, piece)
        end
    end
    return pieces
end

local function SpeakQuest(title, description, objectives, rewards, choices)
    title = Clean(title)
    if not title then
        return
    end
    if not Claim("qread:" .. string.lower(title)) then
        return
    end
    Say(title .. ".")
    description = Clean(description)
    if description and string.lower(description) ~= string.lower(title) then
        Say(description)
    end
    if type(objectives) == "table" and #objectives > 0 then
        Say("Objectives. " .. table.concat(objectives, ". ") .. ".")
    end
    if type(rewards) == "table" and #rewards > 0 then
        Say("Rewards. " .. table.concat(rewards, ". ") .. ".")
    end
    if type(choices) == "table" and #choices > 0 then
        Say("Choose one. " .. table.concat(choices, ". ") .. ".")
    end
end

local function FirstMoney(fn)
    if not fn then
        return nil
    end
    local ok, value = pcall(fn)
    value = ok and Num(value) or nil
    if value and value > 0 then
        return value
    end
    return nil
end

local function AddCountName(list, name, count)
    name = Clean(name)
    if not name then
        return
    end
    count = Num(count)
    if count and count > 1 then
        table.insert(list, name .. " x" .. tostring(count))
    else
        table.insert(list, name)
    end
end

local function ItemFromCall(fn, a, b)
    if not fn then
        return nil, nil
    end
    local ok, name, _, count = pcall(fn, a, b)
    if not ok then
        return nil, nil
    end
    return Clean(name), Num(count)
end

local function FillOfferRewards(rewards, choices)
    local money = FirstMoney(GetRewardMoney)
    local phrase = MoneyPhrase(money)
    if phrase then
        table.insert(rewards, phrase)
    end
    local xp = FirstMoney(GetRewardXP)
    if xp then
        table.insert(rewards, tostring(xp) .. " experience")
    end
    local n = 0
    if GetNumQuestRewards then
        local ok, count = pcall(GetNumQuestRewards)
        n = ok and Num(count) or 0
    end
    local i
    for i = 1, n do
        local name, count = ItemFromCall(GetQuestItemInfo, "reward", i)
        AddCountName(rewards, name, count)
    end
    n = 0
    if GetNumQuestChoices then
        local ok, count = pcall(GetNumQuestChoices)
        n = ok and Num(count) or 0
    end
    for i = 1, n do
        local name, count = ItemFromCall(GetQuestItemInfo, "choice", i)
        AddCountName(choices, name, count)
    end
end

local function FillLogRewards(rewards, choices)
    local money = FirstMoney(GetQuestLogRewardMoney)
    local phrase = MoneyPhrase(money)
    if phrase then
        table.insert(rewards, phrase)
    end
    local xp = FirstMoney(GetQuestLogRewardXP)
    if not xp then
        xp = FirstMoney(GetRewardXP)
    end
    if xp then
        table.insert(rewards, tostring(xp) .. " experience")
    end
    local n = 0
    if GetNumQuestLogRewards then
        local ok, count = pcall(GetNumQuestLogRewards)
        n = ok and Num(count) or 0
    end
    local i
    for i = 1, n do
        local name, count = ItemFromCall(GetQuestLogRewardInfo, i)
        AddCountName(rewards, name, count)
    end
    n = 0
    if GetNumQuestLogChoices then
        local ok, count = pcall(GetNumQuestLogChoices)
        n = ok and Num(count) or 0
    end
    for i = 1, n do
        local name, count = ItemFromCall(GetQuestLogChoiceInfo, i)
        AddCountName(choices, name, count)
    end
end

local function ReadOffer()
    if not live or not On("chatQuestDetails") then
        return
    end
    if QuestFrame and not Shown(QuestFrame) then
        return
    end
    local title
    if GetTitleText then
        local ok, value = pcall(GetTitleText)
        if ok then
            title = Clean(value)
        end
    end
    local description
    if GetProgressText then
        local ok, value = pcall(GetProgressText)
        if ok then
            description = Clean(value)
        end
    end
    if not description and GetQuestText then
        local ok, value = pcall(GetQuestText)
        if ok then
            description = Clean(value)
        end
    end
    local objectives = {}
    if GetObjectiveText then
        local ok, value = pcall(GetObjectiveText)
        if ok then
            objectives = ObjectiveList(value)
        end
    end
    local rewards = {}
    local choices = {}
    FillOfferRewards(rewards, choices)
    SpeakQuest(title, description, objectives, rewards, choices)
end

local function LogTitle()
    if not GetQuestLogTitle or not GetQuestLogSelection then
        return nil, nil
    end
    local selOk, index = pcall(GetQuestLogSelection)
    index = selOk and Num(index) or nil
    if not index or index < 1 then
        return nil, nil
    end
    local ok, title, _, _, isHeader = pcall(GetQuestLogTitle, index)
    if not ok or Flag(isHeader) == true then
        return nil, index
    end
    return Clean(title), index
end

local function ReadLog()
    if not live or not On("chatQuestDetails") then
        return
    end
    local title, index = LogTitle()
    if not title then
        return
    end
    local description
    local objectiveBlob
    if GetQuestLogQuestText then
        local ok, desc, obj = pcall(GetQuestLogQuestText)
        if ok then
            description = Clean(desc)
            objectiveBlob = obj
        end
    end
    local objectives = {}
    if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        local ok, n = pcall(GetNumQuestLeaderBoards, index)
        n = ok and Num(n) or nil
        if n and n > 0 then
            local i
            for i = 1, n do
                local boardOk, text = pcall(GetQuestLogLeaderBoard, i, index)
                if boardOk then
                    local piece = OneObjective(text)
                    if piece then
                        table.insert(objectives, piece)
                    end
                end
            end
        end
    end
    if #objectives == 0 then
        objectives = ObjectiveList(objectiveBlob)
    end
    local rewards = {}
    local choices = {}
    FillLogRewards(rewards, choices)
    SpeakQuest(title, description, objectives, rewards, choices)
end

local function LogIsShown()
    if Shown(QuestLogFrame) or Shown(QuestMapFrame) then
        return true
    end
    return false
end

local function PollLog()
    if not LogIsShown() then
        logShown = false
        logSelection = nil
        return
    end
    local _, index = LogTitle()
    if not logShown or index ~= logSelection then
        logShown = true
        logSelection = index
        ReadLog()
    end
end

local function TitleForAccepted(a, b)
    local id = Num(b)
    local index = Num(a)
    local count
    if GetNumQuestLogEntries then
        local ok, n = pcall(GetNumQuestLogEntries)
        count = ok and Num(n) or nil
    end
    if (not count) and C_QuestLog and C_QuestLog.GetNumQuestLogEntries then
        local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
        count = ok and Num(n) or nil
    end
    if index and count and index >= 1 and index <= count and GetQuestLogTitle then
        local ok, title, _, _, isHeader = pcall(GetQuestLogTitle, index)
        if ok and Flag(isHeader) ~= true then
            title = Clean(title)
            if title then
                return title
            end
        end
    end
    if not id then
        id = Num(a)
    end
    if id and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local ok, title = pcall(C_QuestLog.GetTitleForQuestID, id)
        title = ok and Clean(title) or nil
        if title then
            return title
        end
    end
    if id and AH.QuestTitles then
        return Clean(AH.QuestTitles[id])
    end
    return nil
end

local function HandleAccepted(a, b)
    Later(0.2, function()
        if not live or not On("chatQuestAccepted") then
            return
        end
        local title = TitleForAccepted(a, b)
        if title then
            if not Claim("qaccept:" .. string.lower(title)) then
                return
            end
            Say("Quest accepted. " .. title .. ".")
        else
            if not Claim("qaccept:unknown") then
                return
            end
            Say("Quest accepted.")
        end
    end)
end

local function SayNameFirst(lines)
    local name = NpcName()
    if name then
        Say(name .. ".")
    end
    local i
    for i = 1, #lines do
        Say(lines[i])
    end
end

local function ReadGossip()
    if not live or not On("chatNpcWindow") then
        return
    end
    if GossipFrame and not Shown(GossipFrame) then
        return
    end
    local lines = {}
    local greeting
    if C_GossipInfo and C_GossipInfo.GetText then
        local ok, text = pcall(C_GossipInfo.GetText)
        if ok then
            greeting = Clean(text)
        end
    end
    if not greeting and GetGossipText then
        local ok, text = pcall(GetGossipText)
        if ok then
            greeting = Clean(text)
        end
    end
    if greeting then
        table.insert(lines, greeting)
    end
    if C_GossipInfo and C_GossipInfo.GetOptions then
        local ok, options = pcall(C_GossipInfo.GetOptions)
        if ok and type(options) == "table" then
            local i
            for i = 1, #options do
                local row = options[i]
                local name
                if type(row) == "table" then
                    name = Clean(row.name)
                    if not name then
                        name = Clean(row.title)
                    end
                else
                    name = Clean(row)
                end
                if name then
                    table.insert(lines, name .. ".")
                end
            end
        end
    elseif GetGossipOptions then
        local ok, packed = pcall(function()
            return { GetGossipOptions() }
        end)
        if ok and type(packed) == "table" then
            local i = 1
            while packed[i] do
                local name = Clean(packed[i])
                if name then
                    table.insert(lines, name .. ".")
                end
                i = i + 2
            end
        end
    end
    if not Claim("npc:gossip") then
        return
    end
    SayNameFirst(lines)
end

local function ReadTaxi()
    if not live or not On("chatNpcWindow") then
        return
    end
    if not NumTaxiNodes or not TaxiNodeName then
        return
    end
    if TaxiFrame and not Shown(TaxiFrame) then
        return
    end
    local ok, count = pcall(NumTaxiNodes)
    count = ok and Num(count) or nil
    if not count or count < 1 then
        return
    end
    local lines = {}
    local i
    for i = 1, count do
        local nameOk, name = pcall(TaxiNodeName, i)
        name = nameOk and Clean(name) or nil
        if name then
            local current = false
            if TaxiNodeGetType then
                local typeOk, kind = pcall(TaxiNodeGetType, i)
                if typeOk then
                    local label = Text(kind)
                    local number = Num(kind)
                    if label == "CURRENT" or number == 0 then
                        current = true
                    end
                end
            end
            if not current then
                table.insert(lines, name .. ".")
            end
        end
    end
    if not Claim("npc:taxi") then
        return
    end
    SayNameFirst(lines)
end

local function ReadTrainer()
    if not live or not On("chatNpcWindow") then
        return
    end
    if not GetNumTrainerServices or not GetTrainerServiceInfo then
        return
    end
    if (ClassTrainerFrame or TrainerFrame) and not Shown(ClassTrainerFrame) and not Shown(TrainerFrame) then
        return
    end
    local ok, count = pcall(GetNumTrainerServices)
    count = ok and Num(count) or nil
    if not count or count < 1 then
        return
    end
    local lines = {}
    local i
    for i = 1, count do
        local infoOk, name, _, category = pcall(GetTrainerServiceInfo, i)
        name = infoOk and Clean(name) or nil
        category = infoOk and Text(category) or nil
        local header = false
        if category and string.lower(category) == "header" then
            header = true
        end
        if name and not header then
            local cost
            if GetTrainerServiceCost then
                local costOk, money = pcall(GetTrainerServiceCost, i)
                cost = costOk and MoneyPhrase(money) or nil
            end
            if cost then
                table.insert(lines, name .. ". " .. cost .. ".")
            else
                table.insert(lines, name .. ".")
            end
        end
    end
    if not Claim("npc:trainer") then
        return
    end
    SayNameFirst(lines)
end

local function ReadMerchant()
    if not live or not On("chatNpcWindow") then
        return
    end
    if not GetMerchantNumItems or not GetMerchantItemInfo then
        return
    end
    if MerchantFrame and not Shown(MerchantFrame) then
        return
    end
    local ok, count = pcall(GetMerchantNumItems)
    count = ok and Num(count) or nil
    if not count or count < 1 then
        return
    end
    local lines = {}
    local i
    for i = 1, count do
        local infoOk, name, _, price = pcall(GetMerchantItemInfo, i)
        name = infoOk and Clean(name) or nil
        price = infoOk and MoneyPhrase(price) or nil
        if name then
            if price then
                table.insert(lines, name .. ". " .. price .. ".")
            else
                table.insert(lines, name .. ".")
            end
        end
    end
    if not Claim("npc:merchant") then
        return
    end
    SayNameFirst(lines)
end

local function ContainerSlots(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
        return ok and Num(n) or 0
    end
    if GetContainerNumSlots then
        local ok, n = pcall(GetContainerNumSlots, bag)
        return ok and Num(n) or 0
    end
    return 0
end

local function SlotNameCount(bag, slot)
    if C_Container and C_Container.GetContainerItemInfo then
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" then
            local name = Clean(info.itemName)
            if not name then
                local link = Text(info.hyperlink)
                if link then
                    name = Clean(string.match(link, "%[(.-)%]"))
                end
            end
            return name, Num(info.stackCount) or 0
        end
    end
    if GetContainerItemInfo then
        local ok, _, count, _, _, _, _, link = pcall(GetContainerItemInfo, bag, slot)
        if ok then
            local name
            link = Text(link)
            if link then
                name = Clean(string.match(link, "%[(.-)%]"))
            end
            return name, Num(count) or 0
        end
    end
    return nil, 0
end

local function ReadTotals()
    local totals = {}
    local bag
    for bag = 0, 4 do
        local n = ContainerSlots(bag)
        if n and n > 0 then
            local slot
            for slot = 1, n do
                local name, count = SlotNameCount(bag, slot)
                if name then
                    local prev = totals[name] or 0
                    totals[name] = prev + count
                end
            end
        end
    end
    return totals
end

local function CurrentMoney()
    if not GetMoney then
        return nil
    end
    local ok, money = pcall(GetMoney)
    return ok and Num(money) or nil
end

local function SnapshotSale()
    bagTotals = ReadTotals()
    moneySnap = CurrentMoney()
end

local function CheckSold()
    if not Shown(MerchantFrame) then
        bagTotals = {}
        moneySnap = nil
        return
    end
    local nowMoney = CurrentMoney()
    local prevMoney = moneySnap
    local gain
    if nowMoney and prevMoney and nowMoney > prevMoney then
        gain = nowMoney - prevMoney
    end
    local lost = {}
    local nowTotals = ReadTotals()
    local name, count
    for name, count in pairs(bagTotals) do
        local nowCount = nowTotals[name] or 0
        if count > nowCount then
            table.insert(lost, name)
        end
    end
    local waiting = #lost > 0 and not (gain and gain > 0)
    if waiting then
        local nowT = nil
        if GetTime then
            local timeOk, t = pcall(GetTime)
            if timeOk and type(t) == "number" then
                nowT = t
            end
        end
        if not saleHold then
            saleHold = nowT
        end
        if saleHold and nowT and (nowT - saleHold) >= 0 and (nowT - saleHold) < 1.5 then
            return
        end
    end
    saleHold = nil
    if live and On("chatItemSold") and gain and gain > 0 and #lost > 0 then
        local price
        if #lost == 1 then
            price = MoneyPhrase(gain)
        end
        local i
        for i = 1, #lost do
            if price then
                Say("Sold " .. lost[i] .. " for " .. price .. ".")
            else
                Say("Sold " .. lost[i] .. ".")
            end
        end
    end
    bagTotals = nowTotals
    moneySnap = nowMoney
end

local function ScheduleSold()
    if not Shown(MerchantFrame) then
        return
    end
    if sellWait then
        return
    end
    sellWait = true
    Later(0.2, function()
        sellWait = false
        CheckSold()
    end)
end

local function NoteRepair()
    repairPending = true
    repairBefore = CurrentMoney()
end

local function CheckRepair(now)
    if not repairPending then
        return
    end
    now = Num(now)
    local before = repairBefore
    if not before or not now or now == before then
        return
    end
    repairPending = false
    repairBefore = nil
    if not live or not On("chatRepair") or now > before then
        return
    end
    local phrase = MoneyPhrase(before - now)
    if not phrase then
        return
    end
    if not Claim("repair") then
        return
    end
    Say("You repaired your gear for " .. phrase .. ".")
end

local function HookRepair()
    if repairHooked then
        return
    end
    repairHooked = true
    if hooksecurefunc and RepairAllItems then
        pcall(hooksecurefunc, "RepairAllItems", NoteRepair)
    end
end

local function HookRepairButton()
    local button = MerchantRepairAllButton
    if button and button.HookScript and not button._ahRepair then
        button._ahRepair = true
        button:HookScript("OnClick", NoteRepair)
    end
end

local function Seed()
    live = false
    seedGen = seedGen + 1
    local gen = seedGen
    local function finish()
        if gen ~= seedGen then
            return
        end
        live = true
        if Shown(MerchantFrame) then
            SnapshotSale()
        end
    end
    Later(2, finish)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
local function TryEvent(name)
    pcall(frame.RegisterEvent, frame, name)
end
TryEvent("QUEST_DETAIL")
TryEvent("QUEST_PROGRESS")
TryEvent("QUEST_COMPLETE")
TryEvent("QUEST_ACCEPTED")
TryEvent("QUEST_LOG_UPDATE")
TryEvent("GOSSIP_SHOW")
TryEvent("TAXIMAP_OPENED")
TryEvent("TRAINER_SHOW")
TryEvent("MERCHANT_SHOW")
TryEvent("MERCHANT_CLOSED")
TryEvent("BAG_UPDATE")
TryEvent("BAG_UPDATE_DELAYED")
TryEvent("PLAYER_MONEY")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Seed()
        HookRepair()
        return
    end
    if event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        Later(0.15, ReadOffer)
        return
    end
    if event == "QUEST_ACCEPTED" then
        HandleAccepted(...)
        return
    end
    if event == "QUEST_LOG_UPDATE" then
        PollLog()
        return
    end
    if event == "GOSSIP_SHOW" then
        Later(0.15, ReadGossip)
        return
    end
    if event == "TAXIMAP_OPENED" then
        Later(0.15, ReadTaxi)
        return
    end
    if event == "TRAINER_SHOW" then
        Later(0.15, ReadTrainer)
        return
    end
    if event == "MERCHANT_SHOW" then
        SnapshotSale()
        HookRepairButton()
        Later(0.15, ReadMerchant)
        return
    end
    if event == "MERCHANT_CLOSED" then
        bagTotals = {}
        moneySnap = nil
        saleHold = nil
        repairPending = false
        return
    end
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        ScheduleSold()
        return
    end
    if event == "PLAYER_MONEY" then
        local now = CurrentMoney()
        CheckRepair(now)
        ScheduleSold()
    end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    self._log = (self._log or 0) + (elapsed or 0)
    if self._log < 0.3 then
        return
    end
    self._log = 0
    if On("chatQuestDetails") then
        PollLog()
    end
end)

HookRepair()
