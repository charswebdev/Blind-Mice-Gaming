--[[
  AllQuest — journal quest details + pickup waypoint
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Journal = AQ.Journal or {}
local Detail = {}
AQ.Journal.QuestDetail = Detail

local frame
local currentID
local pendingID

local function Ensure()
    if frame then
        return frame
    end
    local parent = AQ.Journal.GetFrame and AQ.Journal.GetFrame() or UIParent
    frame = CreateFrame("Frame", "AllQuestQuestDetail", parent, "BackdropTemplate")
    frame:SetSize(440, 420)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:Hide()
    AQ.Widgets.ApplyTrackerBackdrop(frame)

    local title = AQ.Widgets.FontString(frame, 18, AQ.Theme.accent[1], AQ.Theme.accent[2], AQ.Theme.accent[3])
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetPoint("TOPRIGHT", -48, -14)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(true)
    if title.SetMaxLines then
        pcall(title.SetMaxLines, title, 2)
    end
    frame.Title = title

    local close = AQ.Widgets.Button(frame, "X", 28, 28)
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function()
        Detail.Hide()
    end)
    frame.Close = close

    local status = AQ.Widgets.FontString(frame, 14)
    status:SetPoint("TOPLEFT", 16, -58)
    frame.Status = status

    local meta = AQ.Widgets.FontString(frame, 13, AQ.Theme.hint[1], AQ.Theme.hint[2], AQ.Theme.hint[3])
    meta:SetPoint("TOPLEFT", 16, -80)
    meta:SetPoint("TOPRIGHT", -16, -80)
    meta:SetJustifyH("LEFT")
    meta:SetWordWrap(true)
    frame.Meta = meta

    local body = AQ.Widgets.FontString(frame, 13)
    body:SetPoint("TOPLEFT", 16, -120)
    body:SetPoint("TOPRIGHT", -16, -120)
    body:SetJustifyH("LEFT")
    body:SetWordWrap(true)
    if body.SetJustifyV then
        body:SetJustifyV("TOP")
    end
    frame.Body = body

    local track = AQ.Widgets.Button(frame, "Track", 120, 28)
    track:SetPoint("BOTTOMLEFT", 16, 16)
    track:SetScript("OnClick", function()
        if currentID then
            AQ.Compat.SuperTrackQuest(currentID)
            if AQ.Compat.IsQuestActive(currentID) then
                AQ.Compat.AddQuestWatch(currentID)
            end
            if AQ.Tracker then
                AQ.Tracker.Refresh()
            end
            AQ.Speech.Say("Tracking " .. (frame.Title:GetText() or "quest"))
        end
    end)
    frame.Track = track

    local way = AQ.Widgets.Button(frame, "Waypoint", 120, 28)
    way:SetPoint("LEFT", track, "RIGHT", 10, 0)
    way:SetScript("OnClick", function()
        if currentID then
            Detail.SetWaypoint()
        end
    end)
    frame.Way = way

    local hide = AQ.Widgets.Button(frame, "Close", 120, 28)
    hide:SetPoint("BOTTOMRIGHT", -16, 16)
    hide:SetScript("OnClick", function()
        Detail.Hide()
    end)

    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(frame, function()
            return (frame.Title and frame.Title:GetText() or "Quest details")
        end)
    end
    return frame
end

local function Fill()
    if not frame or not currentID then
        return
    end
    local title = AQ.Compat.GetQuestTitle(currentID) or ("Quest " .. tostring(currentID))
    frame.Title:SetText(title)
    local status = "READY"
    if AQ.Compat.IsQuestFlaggedCompleted(currentID) then
        status = "DONE"
    elseif AQ.Compat.IsQuestActive(currentID) then
        status = "ACTIVE"
    end
    frame.Status:SetText(status)
    local sc = AQ.Theme.StatusColor(status)
    frame.Status:SetTextColor(sc[1], sc[2], sc[3], 1)

    local mapID, x, y, src = nil, nil, nil, nil
    if AQ.QuestSources then
        mapID, x, y, src = AQ.QuestSources.ResolveLocation(currentID)
    else
        mapID, x, y, src = AQ.Compat.GetQuestPickupLocation(currentID)
    end
    local mapName = AQ.Compat.GetMapName(mapID)
    local meta = "Quest " .. tostring(currentID)
    if mapName then
        meta = meta .. " · " .. mapName
    end
    if x and y then
        meta = meta .. string.format(" · %.1f, %.1f", x * 100, y * 100)
    end
    if src then
        meta = meta .. " · " .. src
    end
    local url = AQ.Compat.WowheadURL("quest", currentID)
    if url then
        meta = meta .. "\n" .. url
    end
    frame.Meta:SetText(meta)

    local parts = {}
    local desc = AQ.Compat.GetQuestDescription(currentID)
    if desc and desc ~= "" then
        parts[#parts + 1] = desc
    end
    local objectives = AQ.Compat.GetQuestObjectives(currentID)
    if type(objectives) == "table" and #objectives > 0 then
        parts[#parts + 1] = "Objectives"
        for i = 1, #objectives do
            local o = objectives[i]
            local text = type(o) == "table" and (o.text or o) or tostring(o)
            if text and text ~= "" then
                parts[#parts + 1] = "- " .. text
            end
        end
    end
    if #parts == 0 then
        parts[1] = "Double-click set a waypoint to pick this quest up when a map point is known. Track adds it to the tracker if you already have it."
    end
    frame.Body:SetText(table.concat(parts, "\n"))
    frame.Body:SetHeight(220)
end

function Detail.SetWaypoint()
    if not currentID then
        return
    end
    local title = frame and frame.Title and frame.Title:GetText() or "Quest"
    local placed, mapID = false, nil
    if AQ.QuestSources then
        placed, mapID = AQ.QuestSources.SetWaypoint(currentID, title)
    end
    if placed then
        AQ.Speech.Say("Waypoint set for " .. title)
    elseif type(mapID) == "number" then
        local name = AQ.Compat.GetMapName(mapID) or "the quest map"
        AQ.Speech.Say("Opened map for " .. title .. " in " .. name)
    else
        AQ.Speech.Say("No map point found. Super-tracking " .. title)
        AQ.Compat.SuperTrackQuest(currentID)
        AQ.Compat.ShowQuestOnMap(currentID)
    end
    Fill()
end

function Detail.Show(questID, title)
    if type(questID) ~= "number" then
        return
    end
    Ensure()
    currentID = questID
    pendingID = questID
    AQ.Compat.RequestQuestData(questID)
    Fill()
    if title then
        frame.Title:SetText(title)
    end
    frame:Show()
    Detail.SetWaypoint()
    local speak = (frame.Title:GetText() or "Quest") .. ". " .. (frame.Status:GetText() or "") .. ". " .. (frame.Meta:GetText() or "")
    AQ.Speech.Say(speak)
end

function Detail.Hide()
    currentID = nil
    pendingID = nil
    if frame then
        frame:Hide()
    end
end

function Detail.IsShown()
    return frame and frame:IsShown() and true or false
end

AQ.Events.Register("QUEST_DATA_LOAD_RESULT", function(_, questID, success)
    if pendingID and questID == pendingID and success then
        Fill()
    end
end)
