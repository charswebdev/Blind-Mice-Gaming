--[[
  AllQuest — in-game data recorder + Retail C_QuestLine dump
  /aqdebug help
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Debug = AQ.Debug or {}
local Debug = AQ.Debug

AllQuestCharDB = AllQuestCharDB
local function Rec()
    local c = AQ.DB.Char()
    c.debugLog = c.debugLog or {}
    return c.debugLog
end

function Debug.Record()
    local log = Rec()
    local mapID, x, y = AQ.Compat.GetPlayerMapPosition()
    local entry = {
        time = date and date("%Y-%m-%d %H:%M") or tostring(time and time() or 0),
        mapID = mapID,
        x = x,
        y = y,
        zone = GetZoneText and GetZoneText() or "",
        sub = GetSubZoneText and GetSubZoneText() or "",
        quests = {},
    }
    AQ.Compat.ForEachQuestLog(function(info)
        if not info.isHeader then
            entry.quests[#entry.quests + 1] = {
                id = info.questID,
                title = info.title,
                complete = info.isComplete,
            }
        end
    end)
    log[#log + 1] = entry
    AQ:Print("Recorded " .. tostring(#entry.quests) .. " log quests at map " .. tostring(mapID) .. ". Saved in character DB (AllQuestCharDB.debugLog).")
    AQ.Speech.Say("Debug record saved")
end

function Debug.DumpQuestLines()
    if not C_QuestLine then
        AQ:Print("C_QuestLine is not on this client.")
        return
    end
    local mapID = AQ.Compat.GetPlayerMapPosition()
    if type(mapID) ~= "number" then
        AQ:Print("No map ID.")
        return
    end
    if C_QuestLine.RequestQuestLinesForMap then
        pcall(C_QuestLine.RequestQuestLinesForMap, mapID)
    end
    local lines
    if C_QuestLine.GetAvailableQuestLines then
        lines = AQ:SafeCall(C_QuestLine.GetAvailableQuestLines, mapID)
    end
    if type(lines) ~= "table" then
        AQ:Print("No quest lines returned for map " .. tostring(mapID))
        return
    end
    local dump = Rec()
    dump.questLines = dump.questLines or {}
    dump.questLines[mapID] = lines
    -- Also store extractor-ready records.
    dump.extractor = dump.extractor or {}
    local recs = {}
    for i = 1, #lines do
        local L = lines[i]
        if type(L) == "table" and type(L.questID) == "number" then
            recs[#recs + 1] = {
                id = L.questID,
                name = L.questName or L.questLineName,
                zone = tostring(mapID),
                questLineID = L.questLineID,
                next = {},
                prev = {},
            }
        end
    end
    dump.extractor[mapID] = recs
    local getLineQuests = (C_QuestLine and C_QuestLine.GetQuestLineQuests)
        or (C_QuestLineUI and C_QuestLineUI.GetQuestLineQuests)
    if getLineQuests then
        local byLine = {}
        for i = 1, #recs do
            local lineID = recs[i].questLineID
            if type(lineID) == "number" and not byLine[lineID] then
                local qids = AQ:SafeCall(getLineQuests, lineID)
                byLine[lineID] = qids
                if type(qids) == "table" then
                    for n = 1, #qids - 1 do
                        for r = 1, #recs do
                            if recs[r].id == qids[n] then
                                recs[r].next = { qids[n + 1] }
                            end
                        end
                    end
                end
            end
        end
    end
    AQ:Print("Dumped " .. tostring(#lines) .. " C_QuestLine entries for map " .. tostring(mapID) .. ". Copy AllQuestCharDB.debugLog.extractor into tools JSON.")
    for i = 1, math.min(#lines, 8) do
        local L = lines[i]
        if type(L) == "table" then
            AQ:Print(string.format("  line %s quest %s %s", tostring(L.questLineID), tostring(L.questID), tostring(L.questLineName or L.questName)))
        end
    end
end

function Debug.PrintHelp()
    AQ:Print("/aqdebug record — save current zone + quest log (for overlay work)")
    AQ:Print("/aqdebug questlines — dump Retail C_QuestLine for this map")
    AQ:Print("/aqdebug clear — wipe saved debug log")
    AQ:Print("Extractor: AllQuest/tools/extract_chains.py")
end

SLASH_AQDEBUG1 = "/aqdebug"
SlashCmdList["AQDEBUG"] = function(msg)
    msg = AQ:Trim(msg or ""):lower()
    if msg == "record" then
        Debug.Record()
    elseif msg == "questlines" or msg == "lines" then
        Debug.DumpQuestLines()
    elseif msg == "clear" then
        AQ.DB.Char().debugLog = {}
        AQ:Print("Debug log cleared.")
    else
        Debug.PrintHelp()
    end
end
