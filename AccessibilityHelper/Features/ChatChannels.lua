--[[
  Accessibility Helper — optional chat-channel TTS
  All channels default off. Master gate chatReadEnabled also default off.
  Labels follow Blizzard / common chat filter UIs.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.ChatChannels = AH.ChatChannels or {}
local Chat = AH.ChatChannels

--[[
  kind:
    spoken — message + author via Blizzard CHAT_*_GET (as printed)
    exact  — message body only (already the printed line)
    channel — zone/custom; optional channelMatch / zoneChannelID
    system — message body; money lines deferred to Player State when Money is on
]]
Chat.CHANNELS = {
    -- Player (chatType → CHAT_<TYPE>_GET)
    { key = "chatSay", label = "Say", event = "CHAT_MSG_SAY", kind = "spoken", chatType = "SAY", section = "Player",
        example = "Bob says: Hello there." },
    { key = "chatYell", label = "Yell", event = "CHAT_MSG_YELL", kind = "spoken", chatType = "YELL", section = "Player",
        example = "Bob yells: Help!" },
    { key = "chatEmote", label = "Emote", event = "CHAT_MSG_EMOTE", kind = "exact", section = "Player",
        example = "Bob waves at you." },
    { key = "chatTextEmote", label = "Text emote", event = "CHAT_MSG_TEXT_EMOTE", kind = "exact", section = "Player",
        example = "You wave at Bob." },
    { key = "chatWhisper", label = "Whisper", event = "CHAT_MSG_WHISPER", kind = "spoken", chatType = "WHISPER", section = "Player",
        example = "Bob whispers: Want to group?" },
    { key = "chatWhisperOut", label = "Whisper (outgoing)", event = "CHAT_MSG_WHISPER_INFORM", kind = "spoken", chatType = "WHISPER_INFORM", section = "Player",
        example = "To Bob: Sure." },
    { key = "chatBNWhisper", label = "Blizzard Whispers", event = "CHAT_MSG_BN_WHISPER", kind = "spoken", chatType = "BN_WHISPER", section = "Player",
        example = "Friend whispers: Are you on?" },
    { key = "chatBNWhisperOut", label = "Blizzard Whispers (outgoing)", event = "CHAT_MSG_BN_WHISPER_INFORM", kind = "spoken", chatType = "BN_WHISPER_INFORM", section = "Player",
        example = "To Friend: Yes." },
    { key = "chatParty", label = "Party", event = "CHAT_MSG_PARTY", kind = "spoken", chatType = "PARTY", section = "Player",
        example = "Bob says: Ready?" },
    { key = "chatPartyLeader", label = "Party Leader", event = "CHAT_MSG_PARTY_LEADER", kind = "spoken", chatType = "PARTY_LEADER", section = "Player",
        example = "Bob says: Stack on me." },
    { key = "chatRaid", label = "Raid", event = "CHAT_MSG_RAID", kind = "spoken", chatType = "RAID", section = "Player",
        example = "Bob says: Bloodlust now." },
    { key = "chatRaidLeader", label = "Raid Leader", event = "CHAT_MSG_RAID_LEADER", kind = "spoken", chatType = "RAID_LEADER", section = "Player",
        example = "Bob says: Kill adds." },
    { key = "chatRaidWarning", label = "Raid Warning", event = "CHAT_MSG_RAID_WARNING", kind = "spoken", chatType = "RAID_WARNING", section = "Player",
        example = "Bob says: Spread out!" },
    { key = "chatInstance", label = "Instance", event = "CHAT_MSG_INSTANCE_CHAT", kind = "spoken", chatType = "INSTANCE_CHAT", section = "Player",
        example = "Bob says: First boss." },
    { key = "chatInstanceLeader", label = "Instance Leader", event = "CHAT_MSG_INSTANCE_CHAT_LEADER", kind = "spoken", chatType = "INSTANCE_CHAT_LEADER", section = "Player",
        example = "Bob says: Interrupt." },
    { key = "chatGuild", label = "Guild", event = "CHAT_MSG_GUILD", kind = "spoken", chatType = "GUILD", section = "Player",
        example = "Bob says: Anyone for M+" },
    { key = "chatOfficer", label = "Officer", event = "CHAT_MSG_OFFICER", kind = "spoken", chatType = "OFFICER", section = "Player",
        example = "Bob says: Promote Sue." },
    { key = "chatGuildAnnounce", label = "Guild Announce", event = "CHAT_MSG_GUILD_ACHIEVEMENT", kind = "exact", section = "Player",
        example = "Bob has earned the achievement Keystone Hero." },
    { key = "chatGuildAnnounce", label = "Guild Announce (item)", event = "CHAT_MSG_GUILD_ITEM_LOOTED", kind = "exact", section = "Player", hideInSettings = true,
        example = "Bob has looted Thunderfury." },
    { key = "chatAchievement", label = "Achievement Announce", event = "CHAT_MSG_ACHIEVEMENT", kind = "exact", section = "Player",
        example = "Bob has earned the achievement Exploring Kalimdor." },
    { key = "chatCommunities", label = "Communities", event = "CHAT_MSG_COMMUNITIES_CHANNEL", kind = "channel", chatType = "CHANNEL", section = "Player",
        example = "[My Community] Bob: Raid tonight." },
    { key = "chatAFK", label = "AFK replies", event = "CHAT_MSG_AFK", kind = "spoken", chatType = "AFK", section = "Player",
        example = "Bob is Away from Keyboard: Away from keyboard." },
    { key = "chatDND", label = "DND replies", event = "CHAT_MSG_DND", kind = "spoken", chatType = "DND", section = "Player",
        example = "Bob does not wish to be disturbed: Do not disturb." },
    { key = "chatVoiceText", label = "Voice chat text", event = "CHAT_MSG_VOICE_TEXT", kind = "spoken", chatType = "VOICE_TEXT", section = "Player",
        example = "Bob says: On my way." },

    -- Social (zone / defense channels)
    { key = "chatGeneral", label = "General", event = "CHAT_MSG_CHANNEL", kind = "channel", chatType = "CHANNEL", section = "Social",
        channelMatch = "general", zoneChannelID = 1, example = "[General] Bob: Where is the flight path?" },
    { key = "chatTrade", label = "Trade", event = "CHAT_MSG_CHANNEL", kind = "channel", chatType = "CHANNEL", section = "Social",
        channelMatch = "trade", zoneChannelID = 2, example = "[Trade] Bob: WTS herbs." },
    { key = "chatLocalDefense", label = "LocalDefense", event = "CHAT_MSG_CHANNEL", kind = "channel", chatType = "CHANNEL", section = "Social",
        channelMatch = "localdefense", zoneChannelID = 22, example = "[LocalDefense] Bob: Inc west gate." },
    { key = "chatWorldDefense", label = "WorldDefense", event = "CHAT_MSG_CHANNEL", kind = "channel", chatType = "CHANNEL", section = "Social",
        channelMatch = "worlddefense", zoneChannelID = 23, example = "[WorldDefense] Stormwind is under attack!" },
    { key = "chatServices", label = "Services", event = "CHAT_MSG_CHANNEL", kind = "channel", chatType = "CHANNEL", section = "Social",
        channelMatch = "services", zoneChannelID = 42, example = "[Services] Bob: LFW enchanting." },
    { key = "chatChannelOther", label = "Other custom channels", event = "CHAT_MSG_CHANNEL", kind = "channel", chatType = "CHANNEL", section = "Social",
        channelOther = true, example = "[LookingForGroup] Bob: Need tank." },

    -- Creature / boss
    { key = "chatMonsterSay", label = "Creature Say", event = "CHAT_MSG_MONSTER_SAY", kind = "spoken", chatType = "MONSTER_SAY", section = "Creature",
        example = "Guard says: Halt!" },
    { key = "chatMonsterYell", label = "Creature Yell", event = "CHAT_MSG_MONSTER_YELL", kind = "spoken", chatType = "MONSTER_YELL", section = "Creature",
        example = "Boss yells: Face me!" },
    { key = "chatMonsterEmote", label = "Creature Emote", event = "CHAT_MSG_MONSTER_EMOTE", kind = "exact", section = "Creature",
        example = "The wolf snarls at you." },
    { key = "chatMonsterWhisper", label = "Creature Whisper", event = "CHAT_MSG_MONSTER_WHISPER", kind = "spoken", chatType = "MONSTER_WHISPER", section = "Creature",
        example = "Spirit whispers: Follow me." },
    { key = "chatBossEmote", label = "Boss Emote", event = "CHAT_MSG_RAID_BOSS_EMOTE", kind = "exact", section = "Creature",
        example = "The boss begins to cast Inferno." },
    { key = "chatBossWhisper", label = "Boss Whisper", event = "CHAT_MSG_RAID_BOSS_WHISPER", kind = "spoken", chatType = "RAID_BOSS_WHISPER", section = "Creature",
        example = "Boss whispers: You are next." },
    { key = "chatBossWarning", label = "Boss Warning", event = "CHAT_MSG_ENCOUNTER_EVENT", kind = "exact", section = "Creature",
        example = "Move out of the fire." },

    -- Combat chat with no other AH owner (Loot / Progress / Money stay on their tabs)
    { key = "chatTradeskills", label = "Tradeskills", event = "CHAT_MSG_TRADESKILLS", kind = "exact", section = "Combat",
        selfOnly = true, example = "You create Linen Cloth." },
    { key = "chatOpening", label = "Opening", event = "CHAT_MSG_OPENING", kind = "exact", section = "Combat",
        selfOnly = true, example = "You perform Herb Gathering on Silverleaf." },
    { key = "chatPetInfo", label = "Pet Info", event = "CHAT_MSG_PET_INFO", kind = "exact", section = "Combat",
        example = "Your pet is happy." },
    { key = "chatMiscInfo", label = "Misc Info", event = "CHAT_MSG_COMBAT_MISC_INFO", kind = "exact", section = "Combat",
        example = "You gain 10 Combo Points." },

    -- PvP
    { key = "chatBGNeutral", label = "Battleground Neutral", event = "CHAT_MSG_BG_SYSTEM_NEUTRAL", kind = "exact", section = "PvP",
        example = "The battle has begun!" },
    { key = "chatBGAlliance", label = "Battleground Alliance", event = "CHAT_MSG_BG_SYSTEM_ALLIANCE", kind = "exact", section = "PvP",
        example = "Alliance wins!" },
    { key = "chatBGHorde", label = "Battleground Horde", event = "CHAT_MSG_BG_SYSTEM_HORDE", kind = "exact", section = "PvP",
        example = "Horde wins!" },

    -- Other
    { key = "chatSystem", label = "System Messages", event = "CHAT_MSG_SYSTEM", kind = "system", section = "Other",
        example = "You have been invited to a group." },
    { key = "chatIgnored", label = "Ignored", event = "CHAT_MSG_IGNORED", kind = "exact", section = "Other",
        example = "Bob is ignoring you." },
    { key = "chatChannelNotice", label = "Channel (join / leave / notices)", event = "CHAT_MSG_CHANNEL_NOTICE", kind = "exact", section = "Other",
        example = "Joined channel: General." },
    { key = "chatChannelNotice", label = "Channel join", event = "CHAT_MSG_CHANNEL_JOIN", kind = "exact", section = "Other", hideInSettings = true,
        example = "Bob joined channel." },
    { key = "chatChannelNotice", label = "Channel leave", event = "CHAT_MSG_CHANNEL_LEAVE", kind = "exact", section = "Other", hideInSettings = true,
        example = "Bob left channel." },
    { key = "chatChannelNotice", label = "Channel notice user", event = "CHAT_MSG_CHANNEL_NOTICE_USER", kind = "exact", section = "Other", hideInSettings = true,
        example = "Bob owns this channel." },
    { key = "chatTargetIcons", label = "Target Icons", event = "CHAT_MSG_TARGETICONS", kind = "exact", section = "Other",
        example = "Bob places Skull on Target." },
    { key = "chatBNAlert", label = "Blizzard Services Alerts", event = "CHAT_MSG_BN_INLINE_TOAST_ALERT", kind = "exact", section = "Other",
        example = "Friend comes online." },
    { key = "chatBNAlert", label = "Blizzard Services Alerts (broadcast)", event = "CHAT_MSG_BN_INLINE_TOAST_BROADCAST", kind = "exact", section = "Other", hideInSettings = true,
        example = "Friend status update." },
    { key = "chatBNAlert", label = "Blizzard Services Alerts (broadcast inform)", event = "CHAT_MSG_BN_INLINE_TOAST_BROADCAST_INFORM", kind = "exact", section = "Other", hideInSettings = true,
        example = "Your status was updated." },
    { key = "chatPetBattleCombat", label = "Pet Battle Combat", event = "CHAT_MSG_PET_BATTLE_COMBAT_LOG", kind = "exact", section = "Other",
        example = "Your pet hits for 120." },
    { key = "chatPetBattleInfo", label = "Pet Battle Info", event = "CHAT_MSG_PET_BATTLE_INFO", kind = "exact", section = "Other",
        example = "A wild pet has appeared." },
    { key = "chatPing", label = "Ping", event = "CHAT_MSG_PING", kind = "exact", section = "Other",
        example = "Bob pinged Assist on the target." },
}

-- event → list of rows (zone channels share CHAT_MSG_CHANNEL)
local byEvent = {}
for i = 1, #Chat.CHANNELS do
    local row = Chat.CHANNELS[i]
    local list = byEvent[row.event]
    if not list then
        list = {}
        byEvent[row.event] = list
    end
    list[#list + 1] = row
end

local lastLine, lastAt = nil, 0
local DEDUPE_SEC = 0.4
local readyAt = 0

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function MasterOn()
    return DB().chatReadEnabled == true
end

local function ChannelOn(key)
    return DB()[key] == true
end

local function ForSpeech(text)
    if AH.ChatText and AH.ChatText.ForSpeech then
        return AH.ChatText.ForSpeech(text)
    end
    if type(text) ~= "string" then
        return ""
    end
    return text
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

local function Dedupe(key)
    if AH.ChatText and AH.ChatText.WasRecentlySpoken then
        return AH.ChatText.WasRecentlySpoken(key, DEDUPE_SEC)
    end
    local now = GetTime and GetTime() or 0
    if key == lastLine and (now - lastAt) < DEDUPE_SEC then
        return true
    end
    lastLine = key
    lastAt = now
    return false
end

local function StripAuthor(author)
    author = ForSpeech(author or "")
    if author == "" then
        return ""
    end
    return author:match("^([^%-]+)") or author
end

local function PlayerBareName()
    if UnitName then
        local ok, name = pcall(UnitName, "player")
        if ok and type(name) == "string" and name ~= "" then
            return name:match("^([^%-]+)") or name
        end
    end
    return ""
end

local function PlayerGUID()
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, "player")
        if ok and type(guid) == "string" and guid ~= "" then
            return guid
        end
    end
    return nil
end

--- Pattern from a Blizzard "%s" format string (item links / names as wildcards).
local function FormatToMatchPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then
        return nil
    end
    local pat = fmt:gsub("%%s", "\001"):gsub("%%d", "\002")
    pat = pat:gsub("([%^%$%(%)%.%[%]%*%+%-%?%%])", "%%%1")
    pat = pat:gsub("\001", ".-"):gsub("\002", "%%d+")
    return "^" .. pat
end

local function MessageMatchesGlobal(fmt, message)
    local pat = FormatToMatchPattern(fmt)
    if not pat or type(message) ~= "string" then
        return false
    end
    return message:find(pat) ~= nil
end

local OTHER_CHAT_GLOBALS = {
    "TRADESKILL_LOG_THIRDPERSON",
    "OPEN_LOCK_OTHER",
}
local SELF_CHAT_GLOBALS = {
    "TRADESKILL_LOG_FIRSTPERSON",
    "OPEN_LOCK_SELF",
}

--- True if this tradeskill / opening line is the active player's own action.
local function IsSelfChatLine(author, guid, message)
    local myGuid = PlayerGUID()
    -- Only trust player GUIDs. Opening events may pass the node/object GUID instead.
    if type(guid) == "string" and guid:find("^Player%-") and myGuid then
        return guid == myGuid
    end

    local who = StripAuthor(author)
    local me = PlayerBareName()
    if who ~= "" and me ~= "" then
        return string.lower(who) == string.lower(me)
    end

    -- Nearby players' gathering/opening uses third-person Blizzard strings.
    for i = 1, #OTHER_CHAT_GLOBALS do
        if MessageMatchesGlobal(_G[OTHER_CHAT_GLOBALS[i]], message) then
            return false
        end
    end
    for i = 1, #SELF_CHAT_GLOBALS do
        if MessageMatchesGlobal(_G[SELF_CHAT_GLOBALS[i]], message) then
            return true
        end
    end

    local body = ForSpeech(message or "")
    local bodyLower = body:lower()
    if bodyLower:match("^you%s") then
        return true
    end
    -- "Name performs Herb Gathering on Node" / "Name-Realm performs ..."
    local leading = body:match("^([^%s]+)%s+[Pp]erforms%s")
    if leading then
        if me == "" then
            return false
        end
        local bare = leading:match("^([^%-]+)") or leading
        return string.lower(bare) == string.lower(me)
    end
    return false
end

local function NormalizeChannelToken(s)
    s = ForSpeech(s or ""):lower()
    s = s:gsub("^%d+%.%s*", "")
    s = s:gsub("%s*%-.*$", "") -- "Trade - City" → "trade"
    s = s:gsub("%s+", "")
    return s
end

local function ChannelMatches(row, channelName, channelBaseName, zoneChannelID)
    if row.channelOther then
        for i = 1, #Chat.CHANNELS do
            local other = Chat.CHANNELS[i]
            if other.channelMatch and not other.channelOther then
                if ChannelMatches(other, channelName, channelBaseName, zoneChannelID) then
                    return false
                end
            end
        end
        return true
    end
    -- Prefer static zone channel ID (Services=42 needs this; Trade/General must not prefix-match).
    if row.zoneChannelID and type(zoneChannelID) == "number" and zoneChannelID == row.zoneChannelID then
        return true
    end
    if not row.channelMatch then
        return true
    end
    local needle = row.channelMatch:lower():gsub("%s+", "")
    local base = NormalizeChannelToken(channelBaseName)
    local full = NormalizeChannelToken(channelName)
    -- Exact token only (no prefix / substring) so Trade ≠ Trade (Services).
    if base == needle or full == needle then
        return true
    end
    if needle == "services" then
        local spaced = ForSpeech(channelBaseName or channelName or ""):lower()
        if spaced:find("services", 1, true) then
            return true
        end
    end
    if needle == "localdefense" then
        local spaced = ForSpeech(channelBaseName or channelName or ""):lower()
        if spaced:find("local%s*defense", 1) then
            return true
        end
    end
    if needle == "worlddefense" then
        local spaced = ForSpeech(channelBaseName or channelName or ""):lower()
        if spaced:find("world%s*defense", 1) then
            return true
        end
    end
    return false
end

local function ChannelBracketName(channelName, channelBaseName)
    local name = ForSpeech(channelBaseName or channelName or "")
    if name == "" then
        return "Channel"
    end
    name = name:gsub("^%d+%.%s*", "")
    return name
end

--- Fill Blizzard chat templates that still contain %s (achievements, emotes, notices, etc.).
local function FormatChatBody(text, author, target)
    if AH.ChatText and AH.ChatText.ForChatMessage then
        return AH.ChatText.ForChatMessage(text, author, target)
    end
    return ForSpeech(text)
end

--- Build the same wording Blizzard prints (CHAT_*_GET + message).
local function FormatSpoken(row, message, author, channelName, channelBaseName, target)
    local who = StripAuthor(author)
    local kind = row.kind

    -- exact / system / emotes / achievements / notices: fill %s then speak.
    if kind == "exact" or kind == "system" then
        local body = FormatChatBody(message, author, target)
        if body == "" then
            return nil
        end
        return body
    end

    -- If a normal chat line still has format tokens, fill them first.
    local body
    if type(message) == "string" and AH.ChatText and AH.ChatText.HasFormatTokens and AH.ChatText.HasFormatTokens(message) then
        body = FormatChatBody(message, author, target)
    else
        body = ForSpeech(message)
    end
    if body == "" then
        return nil
    end

    if kind == "channel" then
        local chan = ChannelBracketName(channelName, channelBaseName)
        local getter = _G.CHAT_CHANNEL_GET
        if type(getter) == "string" and who ~= "" then
            local ok, prefix = pcall(string.format, getter, who)
            if ok and type(prefix) == "string" then
                return ForSpeech(string.format("[%s] %s%s", chan, prefix, body))
            end
        end
        if who ~= "" then
            return string.format("[%s] %s: %s", chan, who, body)
        end
        return string.format("[%s] %s", chan, body)
    end

    -- spoken: use Blizzard chat get string when present
    local chatType = row.chatType
    if chatType and who ~= "" then
        local getter = _G["CHAT_" .. chatType .. "_GET"]
        if type(getter) == "string" then
            local ok, prefix = pcall(string.format, getter, who)
            if ok and type(prefix) == "string" then
                return ForSpeech(prefix .. body)
            end
        end
    end

    if who ~= "" then
        return string.format("%s: %s", who, body)
    end
    return body
end

local function LooksLikeMoneyChat(text)
    local lower = string.lower(text or "")
    if not (lower:find("gold", 1, true) or lower:find("silver", 1, true) or lower:find("copper", 1, true)) then
        return false
    end
    return lower:find("loot", 1, true)
        or lower:find("gain", 1, true)
        or lower:find("gained", 1, true)
        or lower:find("refund", 1, true)
        or lower:find("share", 1, true)
        or lower:find("received", 1, true)
        or lower:find("deposit", 1, true)
        or lower:find("paid", 1, true)
        or lower:find("spend", 1, true)
        or lower:find("spent", 1, true)
end

local function TryRow(row, event, message, author, channelName, channelBaseName, zoneChannelID, target, guid)
    if not ChannelOn(row.key) then
        return
    end
    if row.kind == "channel" and (row.channelMatch or row.channelOther) then
        if not ChannelMatches(row, channelName, channelBaseName, zoneChannelID) then
            return
        end
    end
    if row.selfOnly and not IsSelfChatLine(author, guid, message) then
        return
    end
    -- Money lines belong to Player State → Money when that toggle is on.
    if row.key == "chatSystem" and DB().stateMoney ~= false and LooksLikeMoneyChat(ForSpeech(message)) then
        return
    end

    local line = FormatSpoken(row, message, author, channelName, channelBaseName, target)
    if not line then
        return
    end
    if Dedupe(line) then
        return
    end
    Say(line)
end

local function Handle(event, ...)
    if not MasterOn() then
        return
    end
    local rows = byEvent[event]
    if not rows then
        return
    end

    local message, author, _, channelName, playerName2, _, zoneChannelID, _, channelBaseName, _, _, guid = ...
    if type(message) ~= "string" or message == "" then
        return
    end

    for i = 1, #rows do
        TryRow(rows[i], event, message, author, channelName, channelBaseName, zoneChannelID, playerName2, guid)
    end
end

--- Settings rows with section headers for the Chat tab.
-- Zone / Social channels are listed first so General, Trade, etc. are easy to find.
function Chat.SettingsRows()
    local sectionOrder = { "Social", "Player", "Creature", "Combat", "PvP", "Other" }
    local sectionLabels = {
        Social = "Zone channels",
        Player = "Player",
        Creature = "Creature",
        Combat = "Combat",
        PvP = "PvP",
        Other = "Other",
    }
    local bySection = {}
    local seen = {}
    for i = 1, #Chat.CHANNELS do
        local row = Chat.CHANNELS[i]
        if not row.hideInSettings and not seen[row.key] then
            seen[row.key] = true
            local sec = row.section or "Other"
            if not bySection[sec] then
                bySection[sec] = {}
            end
            bySection[sec][#bySection[sec] + 1] = row
        end
    end
    local out = {}
    for s = 1, #sectionOrder do
        local sec = sectionOrder[s]
        local list = bySection[sec]
        if list and #list > 0 then
            out[#out + 1] = { type = "header", label = sectionLabels[sec] or sec }
            if sec == "Social" then
                out[#out + 1] = {
                    type = "hint",
                    label = "General, Trade, Services, LocalDefense, WorldDefense, and other custom channels.",
                }
            end
            for i = 1, #list do
                local row = list[i]
                out[#out + 1] = { type = "check", key = row.key, label = row.label, example = row.example }
            end
        end
    end
    return out
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local registered = {}
for i = 1, #Chat.CHANNELS do
    local ev = Chat.CHANNELS[i].event
    if not registered[ev] then
        registered[ev] = true
        pcall(frame.RegisterEvent, frame, ev)
    end
end

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        readyAt = (GetTime and GetTime() or 0) + 1.5
        return
    end
    local now = GetTime and GetTime() or 0
    if now < readyAt then
        return
    end
    Handle(event, ...)
end)
