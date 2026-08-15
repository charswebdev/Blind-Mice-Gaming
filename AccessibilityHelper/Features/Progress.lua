--[[
  Accessibility Helper — profession / XP / reputation
  Speaks Blizzard chat lines exactly when present; XP also tracked via
  PLAYER_XP_UPDATE so exploration and other silent gains still announce.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Progress = AH.Progress or {}
local Progress = AH.Progress

local skillCache = {} -- [lowerName] = rank (quiet cache only)
local factionStanding = {} -- [factionID or name] = standingID
local readyAt = 0

local lastXP = nil
local lastXPLevel = nil
local lastXPSpeakAt = 0
local lastXPAmount = nil
local XP_DEDUPE_SEC = 1.5

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

local function SpeakChat(text)
    local spoken = ForSpeech(text)
    if spoken ~= "" then
        Say(spoken)
    end
end

local function ParseXPAmount(text)
    if type(text) ~= "string" then
        return nil
    end
    local spoken = ForSpeech(text)
    -- "85 experience gained" / "You gain 1,240 experience" / "Experience gained: 85."
    local n = spoken:match("([%d,]+)%s+[Ee]xperience")
        or spoken:match("[Ee]xperience[^%d]*([%d,]+)")
        or spoken:match("[Gg]ain[s]?%s+([%d,]+)%s+[Ee]xp")
    if not n then
        return nil
    end
    return tonumber((n:gsub(",", "")))
end

--- Mark that XP was already spoken (e.g. discovery UI line that includes XP).
function Progress.NoteRecentXP(amount)
    if type(amount) == "number" and amount > 0 then
        lastXPAmount = amount
        lastXPSpeakAt = GetTime and GetTime() or 0
    end
end

function Progress.NoteRecentXPFromText(text)
    Progress.NoteRecentXP(ParseXPAmount(text))
end

local function CacheSkillFromText(text)
    local spoken = ForSpeech(text)
    local skill, newRank = spoken:match("[Yy]our skill in (.+) has increased to (%d+)")
    if skill and newRank then
        skillCache[string.lower(skill)] = tonumber(newRank)
    end
end

local function HandleSkillText(text)
    if not On("progressSkill") then
        return
    end
    CacheSkillFromText(text)
    SpeakChat(text)
end

local function HandleXPText(text)
    if not On("progressXP") then
        return
    end
    local spoken = ForSpeech(text)
    if spoken == "" then
        return
    end
    Progress.NoteRecentXPFromText(spoken)
    Say(spoken)
end

local function FormatXPGain(amount)
    if type(amount) ~= "number" or amount <= 0 then
        return nil
    end
    if AH.ChatText and AH.ChatText.Format then
        local s = AH.ChatText.Format("ERR_QUEST_REWARD_EXP_I", amount)
        if s ~= "" then
            return s
        end
    end
    local fmt = _G.ERR_QUEST_REWARD_EXP_I
    if type(fmt) == "string" then
        local ok, text = pcall(string.format, fmt, amount)
        if ok and type(text) == "string" then
            return ForSpeech(text)
        end
    end
    return string.format("You gain %d experience.", amount)
end

local function ReadPlayerXP()
    if not UnitXP then
        return nil, nil
    end
    local xp = SafeCall(UnitXP, "player")
    local level = UnitLevel and SafeCall(UnitLevel, "player") or nil
    if type(xp) ~= "number" then
        return nil, nil
    end
    return xp, level
end

local function SeedXP()
    lastXP, lastXPLevel = ReadPlayerXP()
end

--- Fallback when Blizzard does not print CHAT_MSG_COMBAT_XP_GAIN (common for exploration).
local function HandleXPUpdate()
    if not On("progressXP") then
        SeedXP()
        return
    end
    local xp, level = ReadPlayerXP()
    if type(xp) ~= "number" then
        return
    end
    local prevXP, prevLevel = lastXP, lastXPLevel
    lastXP, lastXPLevel = xp, level

    if prevXP == nil then
        return
    end
    -- Level-up XP bar reset is handled by level-up announces; skip negative/zero.
    if type(prevLevel) == "number" and type(level) == "number" and level > prevLevel then
        return
    end
    local gained = xp - prevXP
    if gained <= 0 then
        return
    end

    local now = GetTime and GetTime() or 0
    if lastXPAmount == gained and (now - lastXPSpeakAt) < XP_DEDUPE_SEC then
        return
    end

    local line = FormatXPGain(gained)
    if not line then
        return
    end
    Progress.NoteRecentXP(gained)
    Say(line)
end

local STANDING_NAMES = {
    [0] = "Unknown",
    [1] = "Hated",
    [2] = "Hostile",
    [3] = "Unfriendly",
    [4] = "Neutral",
    [5] = "Friendly",
    [6] = "Honored",
    [7] = "Revered",
    [8] = "Exalted",
}

local function StandingName(id)
    if type(id) ~= "number" then
        return "Unknown"
    end
    local key = "FACTION_STANDING_LABEL" .. tostring(id)
    local label = _G[key]
    if type(label) == "string" and label ~= "" then
        return label
    end
    return STANDING_NAMES[id] or ("Standing " .. tostring(id))
end

local function HandleRepText(text)
    if not On("progressRep") then
        return
    end
    SpeakChat(text)
end

local function ScanFactionStandings(announce)
    if not On("progressRepStanding") and announce then
        return
    end

    local function consider(id, name, standingID)
        if not standingID then
            return
        end
        local key = id or name
        if not key then
            return
        end
        local prev = factionStanding[key]
        factionStanding[key] = standingID
        if announce and prev ~= nil and prev ~= standingID and On("progressRepStanding") then
            local fname = name or ("Faction " .. tostring(id))
            local standing = StandingName(standingID)
            local spoken = ""
            if AH.ChatText and AH.ChatText.Format then
                spoken = AH.ChatText.Format("FACTION_STANDING_CHANGED", standing, fname)
            end
            if spoken == "" then
                spoken = string.format("You are now %s with %s.", standing, fname)
            end
            Say(spoken)
        end
    end

    if C_Reputation and C_Reputation.GetNumFactions and C_Reputation.GetFactionDataByIndex then
        local n = SafeCall(C_Reputation.GetNumFactions) or 0
        for i = 1, n do
            local data = SafeCall(C_Reputation.GetFactionDataByIndex, i)
            if type(data) == "table" then
                consider(data.factionID, data.name, data.reaction or data.standingID)
            end
        end
        return
    end

    if GetNumFactions and GetFactionInfo then
        local n = SafeCall(GetNumFactions) or 0
        for i = 1, n do
            local name, _, standingID, _, _, _, _, _, isHeader, _, _, _, _, factionID = SafeCall(GetFactionInfo, i)
            if not isHeader then
                consider(factionID, name, standingID)
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHAT_MSG_SKILL")
frame:RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN")
frame:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
frame:RegisterEvent("UPDATE_FACTION")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("PLAYER_LEVEL_UP")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        readyAt = (GetTime and GetTime() or 0) + 3
        ScanFactionStandings(false)
        SeedXP()
        return
    end

    -- XP / skill / rep chat must never be gated by the login seed window.
    if event == "CHAT_MSG_SKILL" then
        HandleSkillText((...))
        return
    elseif event == "CHAT_MSG_COMBAT_XP_GAIN" then
        HandleXPText((...))
        SeedXP()
        return
    elseif event == "PLAYER_XP_UPDATE" then
        HandleXPUpdate()
        return
    elseif event == "PLAYER_LEVEL_UP" then
        SeedXP()
        return
    end

    local now = GetTime and GetTime() or 0
    if now < readyAt then
        if event == "UPDATE_FACTION" then
            ScanFactionStandings(false)
        end
        return
    end

    if event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        HandleRepText((...))
        ScanFactionStandings(true)
    elseif event == "UPDATE_FACTION" then
        ScanFactionStandings(true)
    elseif event == "SKILL_LINES_CHANGED" then
        if GetProfessions and GetProfessionInfo then
            local profs = { SafeCall(GetProfessions) }
            for i = 1, #profs do
                local idx = profs[i]
                if type(idx) == "number" then
                    local name, _, rank = SafeCall(GetProfessionInfo, idx)
                    if type(name) == "string" and type(rank) == "number" then
                        skillCache[string.lower(name)] = rank
                    end
                end
            end
        end
    end
end)
