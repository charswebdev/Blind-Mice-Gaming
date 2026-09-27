--[[
  Accessibility Helper — quest window + objectives TTS
  On-demand reads of the open quest/gossip quest UI and quest-log objectives.
  Classic + retail APIs. Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Quests = AH.Quests or {}
local Quests = AH.Quests

local lastObjectiveKey = nil
local lastObjectiveAt = 0

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
        AH.Speech.Say(msg, AH.Speech.PRIORITY_NAV)
    else
        print("|cff66ccff[Helper]|r " .. msg)
    end
end

local function ForSpeech(s)
    if AH.ChatText and AH.ChatText.ForSpeech then
        return AH.ChatText.ForSpeech(s)
    end
    if type(s) ~= "string" then
        return ""
    end
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function SafeCall(fn, ...)
    if not fn then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if not ok then
        return nil
    end
    return a, b, c, d, e
end

local function FsText(fs)
    if not fs or not fs.GetText then
        return ""
    end
    local t = SafeCall(fs.GetText, fs)
    return ForSpeech(t or "")
end

local function FrameShown(name)
    local f = _G[name]
    if not f or not f.IsShown then
        return false
    end
    local ok, shown = pcall(f.IsShown, f)
    return ok and shown and true or false
end

--- Quest ID currently selected in the quest log (retail).
local function GetSelectedQuestID()
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local id = SafeCall(C_QuestLog.GetSelectedQuest)
        if type(id) == "number" and id > 0 then
            return id
        end
    end
    if GetQuestLogSelection and GetQuestLogTitle then
        local idx = SafeCall(GetQuestLogSelection)
        if type(idx) == "number" and idx > 0 then
            local title, _, _, _, _, _, _, questID = SafeCall(GetQuestLogTitle, idx)
            if type(questID) == "number" and questID > 0 then
                return questID
            end
            -- Older classic: questID may be absent; use index-based APIs instead.
            return nil, idx
        end
    end
    return nil
end

local function GetQuestTitle(questID, logIndex)
    if questID and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        local t = SafeCall(C_QuestLog.GetTitleForQuestID, questID)
        if type(t) == "string" and t ~= "" then
            return ForSpeech(t)
        end
    end
    if logIndex and GetQuestLogTitle then
        local t = SafeCall(GetQuestLogTitle, logIndex)
        if type(t) == "string" and t ~= "" then
            return ForSpeech(t)
        end
    end
    return nil
end

local function ObjectivesFromQuestID(questID)
    local out = {}
    if not questID or not (C_QuestLog and C_QuestLog.GetQuestObjectives) then
        return out
    end
    local objectives = SafeCall(C_QuestLog.GetQuestObjectives, questID)
    if type(objectives) ~= "table" then
        return out
    end
    for i = 1, #objectives do
        local o = objectives[i]
        if type(o) == "table" and type(o.text) == "string" and o.text ~= "" then
            local text = ForSpeech(o.text)
            if o.finished then
                text = text .. " (complete)"
            end
            out[#out + 1] = { text = text, finished = o.finished and true or false }
        end
    end
    return out
end

local function ObjectivesFromLogIndex(logIndex)
    local out = {}
    if not logIndex then
        return out
    end
    if SelectQuestLogEntry then
        SafeCall(SelectQuestLogEntry, logIndex)
    end
    local n = SafeCall(GetNumQuestLeaderBoards, logIndex) or SafeCall(GetNumQuestLeaderBoards) or 0
    for i = 1, n do
        local text, otype, finished = SafeCall(GetQuestLogLeaderBoard, i, logIndex)
        if not text then
            text, otype, finished = SafeCall(GetQuestLogLeaderBoard, i)
        end
        if type(text) == "string" and text ~= "" and otype ~= "spell" then
            text = ForSpeech(text)
            if finished then
                text = text .. " (complete)"
            end
            out[#out + 1] = { text = text, finished = finished and true or false }
        end
    end
    return out
end

local function IterateQuestLog(callback)
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local num = SafeCall(C_QuestLog.GetNumQuestLogEntries) or 0
        for i = 1, num do
            local info = SafeCall(C_QuestLog.GetInfo, i)
            if type(info) == "table" and not info.isHeader and info.questID then
                callback(info.questID, i, info.title, info.isComplete, info.isOnMap, info.isHidden)
            end
        end
        return
    end
    if GetNumQuestLogEntries and GetQuestLogTitle then
        local num = SafeCall(GetNumQuestLogEntries) or 0
        for i = 1, num do
            local title, _, _, isHeader, _, isComplete, _, questID = SafeCall(GetQuestLogTitle, i)
            if not isHeader and title then
                callback(questID, i, title, isComplete == 1 or isComplete == true, nil, nil)
            end
        end
    end
end

local function IsQuestWatched(questID, logIndex)
    if questID and C_QuestLog and C_QuestLog.GetQuestWatchType then
        local w = SafeCall(C_QuestLog.GetQuestWatchType, questID)
        if w ~= nil then
            return true
        end
    end
    if IsQuestWatched and logIndex then
        return SafeCall(IsQuestWatched, logIndex) and true or false
    end
    if questID and C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID then
        local sid = SafeCall(C_SuperTrack.GetSuperTrackedQuestID)
        if sid == questID then
            return true
        end
    end
    return false
end

--- Speak incomplete objectives for watched/supertracked quests (else all active).
function Quests.ReadObjectives(opts)
    opts = opts or {}
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if not On("questObjectivesEnabled") then
        Say("Quest objective reading is disabled.")
        return
    end

    local onlyIncomplete = opts.onlyIncomplete ~= false
    local preferWatched = opts.preferWatched ~= false
    local blocks = {}
    local watchedBlocks = {}

    IterateQuestLog(function(questID, logIndex, title, isComplete)
        if isComplete then
            return
        end
        local objectives
        if questID then
            objectives = ObjectivesFromQuestID(questID)
        end
        if (not objectives or #objectives == 0) and logIndex then
            objectives = ObjectivesFromLogIndex(logIndex)
        end
        if not objectives or #objectives == 0 then
            return
        end

        local lines = {}
        for i = 1, #objectives do
            local o = objectives[i]
            if not onlyIncomplete or not o.finished then
                lines[#lines + 1] = o.text
            end
        end
        if #lines == 0 then
            return
        end

        local qtitle = GetQuestTitle(questID, logIndex) or ForSpeech(title or "Quest")
        local block = qtitle .. ". " .. table.concat(lines, ". ")
        blocks[#blocks + 1] = block
        if preferWatched and IsQuestWatched(questID, logIndex) then
            watchedBlocks[#watchedBlocks + 1] = block
        end
    end)

    local use = watchedBlocks
    if #use == 0 then
        use = blocks
    end

    if #use == 0 then
        Say("No quest objectives found.")
        return
    end

    Say(table.concat(use, ". ") .. ".")
end

local function IsGreetingOrGossipOnly()
    -- List of available quests — not a single quest detail panel.
    if FrameShown("QuestFrameGreetingPanel") then
        if FrameShown("QuestFrameDetailPanel")
            or FrameShown("QuestFrameProgressPanel")
            or FrameShown("QuestFrameRewardPanel")
        then
            return false
        end
        return true
    end
    if FrameShown("GossipFrame") and not FrameShown("QuestFrame") then
        return true
    end
    return false
end

local function IsNpcQuestGiverDialog()
    if not FrameShown("QuestFrame") then
        return false
    end
    if IsGreetingOrGossipOnly() then
        return false
    end
    -- Detail / progress / complete for one quest from NPC or object.
    if FrameShown("QuestFrameDetailPanel")
        or FrameShown("QuestFrameProgressPanel")
        or FrameShown("QuestFrameRewardPanel")
    then
        return true
    end
    -- Fallback: QuestFrame up with a title (some clients omit panel names).
    local title = ForSpeech(SafeCall(GetTitleText) or "")
    return title ~= ""
end

local function IsSingleQuestLogDetailOpen()
    if FrameShown("QuestLogPopupDetailFrame") then
        return true
    end
    -- Retail quest map side details for one selected quest.
    local details = _G.QuestMapFrame and _G.QuestMapFrame.DetailsFrame
    if details and details.IsShown then
        local ok, shown = pcall(details.IsShown, details)
        if ok and shown then
            return true
        end
    end
    -- Classic / older quest log frame with a selected entry.
    if FrameShown("QuestLogFrame") or FrameShown("QuestLogDetailFrame") then
        local questID, logIndex = GetSelectedQuestID()
        if questID or (type(logIndex) == "number" and logIndex > 0) then
            return true
        end
        if GetQuestLogSelection then
            local idx = SafeCall(GetQuestLogSelection)
            if type(idx) == "number" and idx > 0 then
                return true
            end
        end
    end
    return false
end

--- Text for the NPC/object quest dialog currently showing one quest.
local function CollectQuestFrameText()
    local parts = {}
    if IsGreetingOrGossipOnly() then
        return parts
    end

    local title = ForSpeech(SafeCall(GetTitleText) or "")
    if title == "" then
        title = FsText(_G.QuestInfoTitleHeader) or FsText(_G.QuestTitleText)
    end
    if title ~= "" then
        parts[#parts + 1] = title
    end

    local desc = ForSpeech(SafeCall(GetQuestText) or "")
    if desc == "" then
        desc = FsText(_G.QuestInfoDescriptionText) or FsText(_G.QuestDescription)
    end
    if desc ~= "" then
        parts[#parts + 1] = desc
    end

    local objectives = ForSpeech(SafeCall(GetObjectiveText) or "")
    if objectives == "" then
        objectives = FsText(_G.QuestInfoObjectivesText)
    end
    if objectives ~= "" then
        parts[#parts + 1] = "Objectives. " .. objectives
    end

    local progress = ForSpeech(SafeCall(GetProgressText) or "")
    if progress ~= "" then
        parts[#parts + 1] = progress
    end

    local reward = ForSpeech(SafeCall(GetRewardText) or "")
    if reward == "" then
        reward = FsText(_G.QuestInfoRewardText)
    end
    if reward ~= "" then
        parts[#parts + 1] = "Rewards. " .. reward
    end

    -- Progress panel leaderboards for this questgiver quest only (no log index = current dialog).
    if GetNumQuestLeaderBoards and GetQuestLogLeaderBoard and FrameShown("QuestFrameProgressPanel") then
        local n = SafeCall(GetNumQuestLeaderBoards) or 0
        -- Guard: absurd counts mean we accidentally hit the full log — abort boards.
        if type(n) == "number" and n > 0 and n <= 20 then
            local boards = {}
            for i = 1, n do
                local text, otype, finished = SafeCall(GetQuestLogLeaderBoard, i)
                if type(text) == "string" and text ~= "" and otype ~= "spell" then
                    text = ForSpeech(text)
                    if finished then
                        text = text .. " (complete)"
                    end
                    boards[#boards + 1] = text
                end
            end
            if #boards > 0 and objectives == "" then
                parts[#parts + 1] = "Objectives. " .. table.concat(boards, ". ")
            end
        end
    end

    return parts
end

--- Text for one selected quest in the quest log / map details (never the full log).
local function CollectQuestLogSelectionText()
    local parts = {}
    local questID, logIndex = GetSelectedQuestID()
    if not questID and not logIndex then
        if GetQuestLogSelection then
            logIndex = SafeCall(GetQuestLogSelection)
            if type(logIndex) ~= "number" or logIndex < 1 then
                logIndex = nil
            end
        end
    end
    if not questID and not logIndex then
        return parts
    end

    -- Headers are not a specific quest.
    if logIndex and C_QuestLog and C_QuestLog.GetInfo then
        local info = SafeCall(C_QuestLog.GetInfo, logIndex)
        if type(info) == "table" and info.isHeader then
            return parts
        end
    end

    local title = GetQuestTitle(questID, logIndex)
    if not title or title == "" then
        title = FsText(_G.QuestInfoTitleHeader)
    end
    if title and title ~= "" then
        parts[#parts + 1] = title
    end

    if GetQuestLogQuestText then
        if logIndex and SelectQuestLogEntry then
            SafeCall(SelectQuestLogEntry, logIndex)
        end
        local desc, obj = SafeCall(GetQuestLogQuestText)
        desc = ForSpeech(desc or "")
        obj = ForSpeech(obj or "")
        if desc ~= "" then
            parts[#parts + 1] = desc
        end
        if obj ~= "" then
            parts[#parts + 1] = "Objectives. " .. obj
        end
    end

    local objectives = {}
    if questID then
        objectives = ObjectivesFromQuestID(questID)
    end
    if #objectives == 0 and logIndex then
        objectives = ObjectivesFromLogIndex(logIndex)
    end
    if #objectives > 0 then
        local lines = {}
        for i = 1, #objectives do
            lines[#lines + 1] = objectives[i].text
        end
        local already = false
        for i = 1, #parts do
            if parts[i]:find("Objectives", 1, true) then
                already = true
                break
            end
        end
        if not already then
            parts[#parts + 1] = "Objectives. " .. table.concat(lines, ". ")
        end
    end

    return parts
end

local lastWindowSpeak = nil
local lastWindowAt = 0

local function SpeakQuestWindowParts(parts, force)
    if not On("questWindowEnabled") then
        return false
    end
    if type(parts) ~= "table" or #parts == 0 then
        return false
    end
    local text = table.concat(parts, ". ") .. "."
    local now = GetTime and GetTime() or 0
    if not force and text == lastWindowSpeak and (now - lastWindowAt) < 2.0 then
        return false
    end
    lastWindowSpeak = text
    lastWindowAt = now
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    Say(text)
    return true
end

--- Read the single open quest (NPC/object dialog or one selected log quest).
function Quests.ReadWindow()
    if AH.Speech and AH.Speech.ClearNavQueue then
        AH.Speech.ClearNavQueue()
    end
    if not On("questWindowEnabled") then
        Say("Quest window reading is disabled.")
        return
    end

    if IsGreetingOrGossipOnly() then
        Say("Choose a quest from the list.")
        return
    end

    local parts = {}
    if IsNpcQuestGiverDialog() then
        parts = CollectQuestFrameText()
    elseif IsSingleQuestLogDetailOpen() then
        parts = CollectQuestLogSelectionText()
    elseif FrameShown("QuestFrame") then
        parts = CollectQuestFrameText()
    else
        -- Keybind with log open to a selected quest.
        parts = CollectQuestLogSelectionText()
    end

    if #parts == 0 then
        Say("No quest window text found. Open a quest from an NPC or object, or select one quest in your log.")
        return
    end

    SpeakQuestWindowParts(parts, true)
end

--- Auto-read NPC/object DETAIL and PROGRESS only.
-- QUEST_COMPLETE is Player State (stateQuest). Log/map browse uses /ahqw.
function Quests.AutoReadWindow()
    if not On("questWindowEnabled") then
        return
    end
    if IsGreetingOrGossipOnly() then
        return
    end
    -- Skip reward/complete panel — Player State speaks accept/complete/turn-in.
    if FrameShown("QuestFrameRewardPanel") then
        return
    end
    if not IsNpcQuestGiverDialog() then
        return
    end
    if not (FrameShown("QuestFrameDetailPanel") or FrameShown("QuestFrameProgressPanel")) then
        return
    end
    SpeakQuestWindowParts(CollectQuestFrameText(), false)
end

--- Optional: announce when an incomplete objective text changes.
-- objectiveSnap = last *spoken* snapshot. Coalesce rapid updates; never discard mid-burst.
local objectiveSnap = {}
local pendingSnap = nil
local pendingKey = nil
local coalesceGen = 0
local COALESCE_SEC = 0.75

local function BuildObjectiveSnapshot()
    local snap = {}
    IterateQuestLog(function(questID, logIndex, title, isComplete)
        if isComplete then
            return
        end
        local objectives = questID and ObjectivesFromQuestID(questID) or {}
        if #objectives == 0 and logIndex then
            objectives = ObjectivesFromLogIndex(logIndex)
        end
        local lines = {}
        for i = 1, #objectives do
            -- Track finished too so "complete" transitions announce once.
            lines[#lines + 1] = objectives[i].text
        end
        if #lines > 0 then
            local key = tostring(questID or ("i" .. tostring(logIndex)))
            snap[key] = {
                title = ForSpeech(title or GetQuestTitle(questID, logIndex) or "Quest"),
                lines = lines,
                questID = questID,
                logIndex = logIndex,
            }
        end
    end)
    return snap
end

local function SnapshotObjectiveKey()
    local snap = BuildObjectiveSnapshot()
    local bits = {}
    for key, entry in pairs(snap) do
        bits[#bits + 1] = key .. "=" .. table.concat(entry.lines, ";")
    end
    table.sort(bits)
    return table.concat(bits, "|"), snap
end

local function BuildProgressAnnouncements(prevSnap, newSnap)
    local announcements = {}
    for qkey, entry in pairs(newSnap) do
        local prev = prevSnap[qkey]
        if prev then
            local changed = {}
            local prevLines = prev.lines or {}
            for i = 1, #entry.lines do
                local cur = entry.lines[i]
                local old = prevLines[i]
                if cur and cur ~= old then
                    changed[#changed + 1] = cur
                end
            end
            if #changed == 0 then
                local prevSet = {}
                for i = 1, #prevLines do
                    prevSet[prevLines[i]] = true
                end
                for i = 1, #entry.lines do
                    if not prevSet[entry.lines[i]] then
                        changed[#changed + 1] = entry.lines[i]
                    end
                end
            end
            if #changed > 0 then
                local title = entry.title or "Quest"
                announcements[#announcements + 1] = title .. ". " .. table.concat(changed, ". ")
            end
        end
    end
    return announcements
end

local function FlushPendingObjectiveProgress(myGen)
    if myGen ~= coalesceGen then
        return
    end
    if not pendingSnap then
        return
    end
    local announcements = BuildProgressAnnouncements(objectiveSnap, pendingSnap)
    lastObjectiveKey = pendingKey
    objectiveSnap = pendingSnap
    pendingSnap = nil
    pendingKey = nil
    lastObjectiveAt = GetTime and GetTime() or 0
    if #announcements == 0 then
        return
    end
    Say(table.concat(announcements, ". ") .. ".")
end

--- Speak only objectives that changed for the quest(s) that updated.
function Quests.CheckObjectiveProgress()
    if not On("questObjectiveProgressEnabled") then
        return
    end
    local key, snap = SnapshotObjectiveKey()
    if lastObjectiveKey == nil then
        lastObjectiveKey = key
        objectiveSnap = snap
        return
    end
    if key == lastObjectiveKey and not pendingSnap then
        return
    end

    -- Coalesce: keep latest snap; speak once after quiet period (never discard).
    pendingKey = key
    pendingSnap = snap
    coalesceGen = coalesceGen + 1
    local myGen = coalesceGen
    if C_Timer and C_Timer.After then
        C_Timer.After(COALESCE_SEC, function()
            FlushPendingObjectiveProgress(myGen)
        end)
    else
        FlushPendingObjectiveProgress(myGen)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
frame:RegisterEvent("QUEST_WATCH_UPDATE")
frame:RegisterEvent("QUEST_ACCEPTED")
-- NPC / object quest dialog only (not QUEST_COMPLETE — Player State covers that).
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("QUEST_GREETING")

local function ScheduleAutoRead()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.15, function()
            Quests.AutoReadWindow()
        end)
    else
        Quests.AutoReadWindow()
    end
end

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        lastObjectiveKey = nil
        lastObjectiveAt = 0
        objectiveSnap = {}
        pendingSnap = nil
        pendingKey = nil
        coalesceGen = coalesceGen + 1
        lastWindowSpeak = nil
        lastWindowAt = 0
        local function seed()
            local key, snap = SnapshotObjectiveKey()
            lastObjectiveKey = key
            objectiveSnap = snap
        end
        if C_Timer and C_Timer.After then
            C_Timer.After(3, seed)
        else
            seed()
        end
        return
    end
    if event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" then
        -- NPC/object dialog only. Log/map browse uses /ahqw. Complete is Player State.
        ScheduleAutoRead()
        return
    end
    if event == "QUEST_GREETING" or event == "QUEST_FINISHED" then
        return
    end
    if event == "QUEST_WATCH_UPDATE" then
        local key, snap = SnapshotObjectiveKey()
        lastObjectiveKey = key
        objectiveSnap = snap
        pendingSnap = nil
        return
    end
    if event == "QUEST_ACCEPTED" then
        local key, snap = SnapshotObjectiveKey()
        lastObjectiveKey = key
        objectiveSnap = snap
        pendingSnap = nil
        return
    end
    if event == "UNIT_QUEST_LOG_CHANGED" then
        local unit = ...
        if unit and unit ~= "player" then
            return
        end
    end
    Quests.CheckObjectiveProgress()
end)
