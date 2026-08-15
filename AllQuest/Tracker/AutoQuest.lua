--[[
  AllQuest — auto accept / turn-in at quest NPCs (Kaliel / QuickQuest style)
  Hold Shift to skip. Multiple item rewards are never chosen automatically.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.AutoQuest = AQ.AutoQuest or {}
local AutoQuest = AQ.AutoQuest

local completeSeen = {}
local completePrimed = false
local gossipRetry = false

local function DB()
    return AQ.DB.Get()
end

local function After(delay, fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(delay, fn)
    else
        fn()
    end
end

local function ShiftSkip()
    return IsShiftKeyDown and IsShiftKeyDown()
end

local function AcceptOn()
    return DB().autoQuestAccept ~= false
end

local function TurnInOn()
    return DB().autoQuestTurnIn ~= false
end

local function NotifyOn()
    return DB().autoQuestNotify ~= false
end

local function FrameTitle()
    local t = AQ:SafeCall(GetTitleText)
    if type(t) == "string" and t ~= "" then
        return t
    end
    return "Quest"
end

local function PlayNotifySound(kind)
    if kind == "complete" then
        return
    end
    local kit
    if SOUNDKIT then
        if kind == "accept" then
            kit = SOUNDKIT.IG_QUEST_LIST_OPEN or SOUNDKIT.QUEST_ADDED
        elseif kind == "complete" then
            kit = SOUNDKIT.IG_QUEST_LIST_COMPLETE
        elseif kind == "turnin" then
            kit = SOUNDKIT.IG_QUEST_LIST_COMPLETE
        end
    end
    if kit and PlaySound then
        pcall(PlaySound, kit, "Master")
        return
    end
    if PlaySoundFile then
        return
    end
end

function AutoQuest.Notify(kind, title)
    if not NotifyOn() then
        return
    end
    title = AQ:StripMarkup(title or "Quest")
    local msg
    if kind == "accept" then
        msg = "Quest accepted: " .. title
    elseif kind == "complete" then
        msg = "Quest complete: " .. title
    elseif kind == "turnin" then
        msg = "Quest turned in: " .. title
    elseif kind == "reward" then
        msg = "Choose a quest reward for " .. title
    else
        msg = title
    end
    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(msg, 1, 0.82, 0, 1)
    end
    PlayNotifySound(kind)
    if AQ.Speech and AQ.Speech.Say then
        AQ.Speech.Say(msg)
    end
end

function AutoQuest.ClickToCompleteText()
    local s = _G.QUEST_WATCH_CLICK_TO_COMPLETE
    if type(s) == "string" and s ~= "" then
        return s
    end
    return "Click to complete"
end

function AutoQuest.QuestCompleteText()
    local s = _G.QUEST_WATCH_QUEST_COMPLETE
    if type(s) == "string" and s ~= "" then
        return s
    end
    return "Quest complete"
end

function AutoQuest.AddClickToComplete(rows, questID, logIndex, isComplete, force)
    if not questID then
        return false
    end
    if not force then
        if not isComplete or not AQ.Compat.IsQuestAutoComplete(questID, logIndex) then
            return false
        end
    end
    rows[#rows + 1] = {
        kind = "objective",
        title = AutoQuest.QuestCompleteText(),
        finished = true,
        questID = questID,
        speech = "Quest complete",
    }
    rows[#rows + 1] = {
        kind = "objective",
        title = AutoQuest.ClickToCompleteText(),
        finished = true,
        clickComplete = true,
        autoComplete = true,
        questID = questID,
        speech = "Click to complete",
        detail = "Left-click to complete this quest from the tracker.",
    }
    return true
end

function AutoQuest.TryHandleTrackerClick(data)
    if type(data) ~= "table" or not data.questID then
        return false
    end
    if data.popupType == "OFFER" then
        local ok = AQ.Compat.ShowQuestOffer(data.questID)
        if ok then
            AQ.Speech.Say("Accepting " .. (data.title or "quest"))
        end
        return ok
    end
    local canComplete = data.clickComplete or data.popupType == "COMPLETE"
        or (data.kind == "quest" and data.status == "DONE" and data.autoComplete)
    if not canComplete then
        return false
    end
    local ok = AQ.Compat.CompleteQuestFromTracker(data.questID)
    if ok then
        AQ.Speech.Say("Completing " .. (data.title or "quest"))
    end
    return ok
end

local function Ignored(entry)
    return type(entry) == "table" and entry.isIgnored and true or false
end

local function TryGossip()
    if ShiftSkip() then
        return
    end
    if TurnInOn() then
        local active = AQ.Compat.GetGossipActiveQuests()
        for i = 1, #active do
            local q = active[i]
            if q and q.isComplete and not Ignored(q) then
                AQ.Compat.SelectGossipActiveQuest(q, i)
                return
            end
        end
    end
    if AcceptOn() and not AQ.Compat.QuestLogIsFull() then
        local avail = AQ.Compat.GetGossipAvailableQuests()
        for i = 1, #avail do
            local q = avail[i]
            if q and not Ignored(q) then
                AQ.Compat.SelectGossipAvailableQuest(q, i)
                return
            end
        end
    end
end

local function TryGreeting()
    if ShiftSkip() then
        return
    end
    if TurnInOn() and GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
        local n = AQ:SafeCall(GetNumActiveQuests) or 0
        for i = 1, n do
            local _, isComplete = AQ:SafeCall(GetActiveTitle, i)
            if isComplete then
                AQ:SafeCall(SelectActiveQuest, i)
                return
            end
        end
    end
    if AcceptOn() and not AQ.Compat.QuestLogIsFull() and GetNumAvailableQuests and SelectAvailableQuest then
        local n = AQ:SafeCall(GetNumAvailableQuests) or 0
        if n > 0 then
            AQ:SafeCall(SelectAvailableQuest, 1)
        end
    end
end

local function OnDetail()
    if not AcceptOn() or ShiftSkip() then
        return
    end
    if AQ.Compat.QuestLogIsFull() then
        return
    end
    if QuestGetAutoAccept and AQ:SafeCall(QuestGetAutoAccept) then
        if AcknowledgeAutoAcceptQuest then
            AQ:SafeCall(AcknowledgeAutoAcceptQuest)
        end
        if CloseQuest then
            AQ:SafeCall(CloseQuest)
        end
        return
    end
    if AcceptQuest then
        AQ:SafeCall(AcceptQuest)
    end
end

local function OnProgress()
    if not TurnInOn() or ShiftSkip() then
        return
    end
    if IsQuestCompletable and AQ:SafeCall(IsQuestCompletable) then
        if CompleteQuest then
            AQ:SafeCall(CompleteQuest)
        end
    end
end

local function OnComplete()
    if not TurnInOn() or ShiftSkip() then
        return
    end
    local n = 0
    if GetNumQuestChoices then
        n = AQ:SafeCall(GetNumQuestChoices) or 0
    end
    if n > 1 then
        AutoQuest.Notify("reward", FrameTitle())
        return
    end
    if GetQuestReward then
        if n >= 1 then
            AQ:SafeCall(GetQuestReward, 1)
        else
            AQ:SafeCall(GetQuestReward)
        end
    end
end

local function ScanNewlyComplete()
    local current = {}
    AQ.Compat.ForEachQuestLog(function(info)
        if info.questID and info.isComplete and not info.isHeader then
            current[info.questID] = info.title or "Quest"
        end
    end)
    if completePrimed then
        for id, title in pairs(current) do
            if not completeSeen[id] then
                if AQ.Sounds and AQ.Sounds.PlayQuestComplete then
                    AQ.Sounds.PlayQuestComplete()
                end
                if NotifyOn() then
                    AutoQuest.Notify("complete", title)
                end
            end
        end
    end
    completeSeen = current
    completePrimed = true
end

AQ.Events.Register("GOSSIP_SHOW", function()
    if ShiftSkip() or (not AcceptOn() and not TurnInOn()) then
        return
    end
    gossipRetry = false
    TryGossip()
    local avail = AQ.Compat.GetGossipAvailableQuests()
    local active = AQ.Compat.GetGossipActiveQuests()
    if #avail == 0 and #active == 0 and not gossipRetry then
        gossipRetry = true
        After(0.05, TryGossip)
    end
end)

AQ.Events.Register("QUEST_GREETING", function()
    TryGreeting()
end)

AQ.Events.Register("QUEST_DETAIL", function()
    OnDetail()
end)

AQ.Events.Register("QUEST_PROGRESS", function()
    OnProgress()
end)

AQ.Events.Register("QUEST_COMPLETE", function()
    OnComplete()
end)

AQ.Events.Register("QUEST_ACCEPTED", function(_, arg1, arg2)
    if not NotifyOn() then
        return
    end
    local questID = AQ.Compat.QuestIDFromAccepted(arg1, arg2)
    local title = FrameTitle()
    if questID and AQ.Compat.GetQuestTitle then
        local t = AQ.Compat.GetQuestTitle(questID)
        if type(t) == "string" and t ~= "" then
            title = t
        end
    end
    AutoQuest.Notify("accept", title)
end)

AQ.Events.Register("QUEST_TURNED_IN", function(_, questID)
    if not NotifyOn() then
        return
    end
    local title = FrameTitle()
    if type(questID) == "number" and AQ.Compat.GetQuestTitle then
        local t = AQ.Compat.GetQuestTitle(questID)
        if type(t) == "string" and t ~= "" then
            title = t
        end
    end
    if completeSeen[questID] then
        completeSeen[questID] = nil
    end
    AutoQuest.Notify("turnin", title)
end)

AQ.Events.Register("QUEST_LOG_UPDATE", function()
    ScanNewlyComplete()
end)

AQ.Events.Register("PLAYER_LOGIN", function()
    completePrimed = false
    After(1, ScanNewlyComplete)
end)
