--[[
  Accessibility Helper — new window
  Tooltip, Speech, and Status. This is the window /ah opens.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Window = AH.Window or {}
local Window = AH.Window

local ICON = "Interface\\AddOns\\AccessibilityHelper\\Media\\Icon"
local BG = { 0.086, 0.075, 0.059, 1 }
local TITLE_BG = { 0.133, 0.110, 0.086, 1 }
local NAV_BG = { 0.110, 0.094, 0.078, 1 }
local GOLD = { 0.941, 0.757, 0.294, 1 }
local EDGE = { 0.541, 0.416, 0.196, 1 }
local TEXT = { 0.957, 0.925, 0.875, 1 }
local BTN = { 0.165, 0.137, 0.110, 1 }

local PAGES = {
    { id = "tooltip", label = "Tooltip", tip = "Set the read key and choose which tooltip lines are spoken. The key speaks only the tooltip that is open. Press it again to stop." },
    { id = "speech", label = "Speech", tip = "Choose the voice, speed, and volume used for every spoken line, including tooltips and status." },
    { id = "status", label = "Status", tip = "Turn each status line on or off. Profession, level, follow, place, your condition, a new location, and red error text are spoken from the game when they change. They are not printed in chat." },
    { id = "arrows", label = "Arrows", tip = "Turn TomTom and Zygor arrow reading on or off. A keybind or a slash command reads the arrow that is showing." },
    { id = "rewards", label = "Rewards", tip = "Click Rewards to show or hide the section names. The arrow points down while those names are showing, and up while they are hidden. Experience, reputation, currency, loot, quests, and achievements are spoken here." },
    { id = "combat", label = "Combat", tip = "Click Combat to show or hide the section names. The arrow points down while those names are showing, and up while they are hidden. Read combat starts off." },
    { id = "chat", label = "Chat", tip = "Click Chat to show or hide the section names. The arrow points down while those names are showing, and up while they are hidden." },
    { id = "commands", label = "Commands", tip = "Lists the slash commands and the key bindings. Click a line to hear it. The read key speaks it too." },
}

local STATUS_ROWS = {
    { key = "progressSkill", label = "Profession and skill", tip = "Speaks when a profession or skill rank goes up, including after a craft. Mining 8 / 75. A new profession says Mining learned. A new recipe says Recipe learned, then the recipe name. A crafted item says the item name." },
    { key = "stateLevelUp", label = "Level up", tip = "Speaks your new level. Level 12. If that level also gave you a talent point, it adds one more line." },
    { key = "stateFollow", label = "Following", tip = "Speaks when you start or stop following someone, and includes their name. Following Charlotte. Stopped following Charlotte." },
    { key = "stateIndoors", label = "Indoor and outdoors", tip = "Speaks when you go inside or come back outside. Indoor. Outdoors." },
    { key = "stateSwim", label = "Swimming", tip = "Speaks when you start or stop swimming. Swimming. Stopped swimming." },
    { key = "stateFly", label = "Flying", tip = "Speaks when you start or stop flying. Flying. Stopped flying." },
    { key = "stateMount", label = "Mount", tip = "Speaks when you get on or off a mount. Mounted. Off mount." },
    { key = "stateAFK", label = "AFK", tip = "Speaks when you go away or come back. AFK on. AFK off." },
    { key = "locationSubzoneEnabled", label = "New location", tip = "Speaks every time you enter a different place. Goldshire. If that place has no smaller name, it speaks the area name. Login stays quiet for a moment. Off, a new place stays quiet." },
    { key = "uiErrorsEnabled", label = "Error messages", tip = "Speaks the red message in the middle of the screen. Out of range. Not enough mana. Spell is not ready yet stays quiet. The same message does not repeat for one second. Starts off." },
    { key = "stateDead", label = "Death", tip = "Speaks when you die. Your Dead. Starts off." },
    { key = "stateGhost", label = "Ghost", tip = "Speaks when you are a ghost. Ghost. Starts off." },
    { key = "stateResurrected", label = "Resurrect", tip = "Speaks when you return to life. Your Resurrected. Starts off." },
    { key = "stateTaxi", label = "Taxi", tip = "Speaks when a flight path takes off and when it ends. On Taxi. Taxi ended. Starts off." },
    { key = "stateResting", label = "Resting", tip = "Speaks when you enter or leave an area that grants rested experience. Entered rested area. Left rested area. Starts off." },
    { key = "stateBagFull", label = "Bags", tip = "Speaks when your bags are full. Your bags are full. It stays quiet when a space opens. Starts off." },
    { key = "stateDurability", label = "Durability", tip = "Speaks when your gear durability drops under 25 percent, and when it is fully repaired. Durability is low. Durability is Restored. Starts off." },
    { key = "stateMoney", label = "Money", tip = "Speaks money you gain or spend. You gained 6 silver. You spent 2 gold. Rewards gold is a separate switch. Starts off." },
    { key = "stateBreath", label = "Breath", tip = "Speaks when your breath drops under 35 percent, and when the breath bar goes away. Your breathing is low. Above water. Starts off." },
    { key = "stateFatigue", label = "Fatigue", tip = "Speaks when the fatigue bar appears, when it drops under 35 percent, and when it goes away. You are getting Fatigued. Your fatigue is low. Fatigue is cleared. Starts off." },
    { key = "stateStuck", label = "Stuck", tip = "Speaks when you are moving but your place does not change for about three seconds. Stuck. Starts off." },
    { key = "stateFalling", label = "Falling", tip = "Speaks after you have been falling for more than a second. Your falling. Starts off." },
    { key = "statePvP", label = "PvP", tip = "Speaks when you become flagged for PvP and when that flag drops. PVP on. PVP off. Starts off." },
    { key = "stateStealth", label = "Stealth", tip = "Speaks when you enter or leave stealth. Your in stealth. You are no longer stealthed. Starts off." },
    { key = "stateShapeshift", label = "Form", tip = "Speaks when you change form, and includes the form name. You have shifted into Bear Form. You shifted back. Starts off." },
    { key = "statePet", label = "Pet", tip = "Speaks the pet name when you summon, dismiss, heal, revive, tame, or lose that pet. Wolf summoned. Wolf is dismissed. Wolf was healed. Wolf Revived. Wolf dead. Wolf health is under 35%. Feed Wolf. Hogger is getting tamed. Hogger is tamed. Hogger can't be tamed. Hogger is not allowed to be tamed. Another pet is active. Spectral Gryphon cant be tamed needs Taming Rod to tame. Starts off." },
    { key = "stateGroup", label = "Group", tip = "Speaks when you join or leave a party or raid. Joined group. Left group. Starts off." },
}

local CHANNEL_ROWS = {
    { key = "chatGeneral", label = "General", tip = "Speaks the General channel for the zone you are in. Off, General stays quiet." },
    { key = "chatTrade", label = "Trade", tip = "Speaks the Trade channel. Off, Trade stays quiet." },
    { key = "chatLocalDefense", label = "Local defense", tip = "Speaks local defense messages for the zone you are in. Off, local defense stays quiet." },
    { key = "chatWorldDefense", label = "World defense", tip = "Speaks world defense announcements. Off, world defense stays quiet." },
    { key = "chatServices", label = "Services", tip = "Speaks the Services channel. Off, Services stays quiet." },
    { key = "chatLookingForGroup", label = "Looking for group", tip = "Speaks the Looking for group channel. Off, Looking for group stays quiet." },
    { key = "chatChannelOther", label = "Other channels", tip = "Speaks custom channels that are not General, Trade, Local defense, World defense, Services, or Looking for group. Off, those channels stay quiet." },
}

local LINE_ROWS = {
    { key = "chatReadEnabled", label = "Read chat", tip = "Turns chat reading on or off. On, each channel you turn on under Town and trade is spoken, and so are the other sections you turn on. Off, chat stays quiet." },
    { key = "chatSpeakMine", label = "What I send", tip = "Turns your own messages on or off for every channel that is enabled. On, lines you send are spoken, including whispers you send. Off, only other people are spoken." },
    { key = "chatPartSpeaker", label = "Speaker", tip = "Speaks who sent the line, using the name and the verb Blizzard prints. Off, the speaker is left out." },
    { key = "chatPartMessage", label = "Message", tip = "Speaks the words that were typed. Off, those words are left out and only the speaker is spoken." },
}

local CHAT_SECTIONS = {
    { id = "line", label = "Line", rows = LINE_ROWS },
    { id = "town", label = "Town and trade", rows = CHANNEL_ROWS },
    { id = "nearby", label = "Nearby talk", rows = {
        { key = "chatSay", label = "Say", tip = "Speaks say messages from people near you. Off, nearby say stays quiet." },
        { key = "chatYell", label = "Yell", tip = "Speaks yell messages from people near you. Off, yells stay quiet." },
        { key = "chatEmote", label = "Emote", tip = "Speaks emotes people perform near you. Off, those emotes stay quiet." },
        { key = "chatTextEmote", label = "Text emote", tip = "Speaks the emote sentence the game writes when someone uses an emote command. Off, text emotes stay quiet." },
        { key = "chatVoiceText", label = "Voice text", tip = "Speaks text that arrives from voice chat. Off, voice text stays quiet." },
    } },
    { id = "whisper", label = "Whispers", rows = {
        { key = "chatWhisper", label = "Whisper", tip = "Speaks whispers other players send you. Whispers you send follow the What I send switch. Off, incoming whispers stay quiet." },
        { key = "chatBNWhisper", label = "Blizzard whisper", tip = "Speaks whispers from Battle.net friends. Whispers you send those friends follow the What I send switch. Off, Battle.net whispers stay quiet." },
        { key = "chatAFK", label = "Away replies", tip = "Speaks the automatic reply when you whisper someone who is away. Off, away replies stay quiet." },
        { key = "chatDND", label = "Busy replies", tip = "Speaks the automatic reply when you whisper someone who is busy. Off, busy replies stay quiet." },
    } },
    { id = "groups", label = "Groups", rows = {
        { key = "chatParty", label = "Party", tip = "Speaks party chat. Off, party chat stays quiet." },
        { key = "chatPartyLeader", label = "Party leader", tip = "Speaks lines sent by the party leader. Off, party leader lines stay quiet." },
        { key = "chatInstance", label = "Instance", tip = "Speaks instance chat. Off, instance chat stays quiet." },
        { key = "chatInstanceLeader", label = "Instance leader", tip = "Speaks lines sent by the instance leader. Off, instance leader lines stay quiet." },
        { key = "chatRaid", label = "Raid", tip = "Speaks raid chat. Off, raid chat stays quiet." },
        { key = "chatRaidLeader", label = "Raid leader", tip = "Speaks lines sent by the raid leader. Off, raid leader lines stay quiet." },
        { key = "chatRaidWarning", label = "Raid warning", tip = "Speaks raid warnings. Off, raid warnings stay quiet." },
        { key = "chatGuild", label = "Guild", tip = "Speaks guild chat. Off, guild chat stays quiet." },
        { key = "chatOfficer", label = "Officer", tip = "Speaks officer chat. Off, officer chat stays quiet." },
        { key = "chatGuildAnnounce", label = "Guild achievement", tip = "Speaks when a guild member earns an achievement. Off, guild achievement lines stay quiet." },
        { key = "chatAchievement", label = "Achievement", tip = "Speaks when a nearby player earns an achievement. Off, those achievement lines stay quiet." },
        { key = "chatCommunities", label = "Communities", tip = "Speaks community channel chat. Off, community channels stay quiet." },
    } },
    { id = "creatures", label = "Creatures", rows = {
        { key = "chatMonsterSay", label = "Creature say", tip = "Speaks when a creature says something. Off, creature say stays quiet." },
        { key = "chatMonsterYell", label = "Creature yell", tip = "Speaks when a creature yells. Off, creature yells stay quiet." },
        { key = "chatMonsterEmote", label = "Creature emote", tip = "Speaks a creature emote. Off, creature emotes stay quiet." },
        { key = "chatMonsterWhisper", label = "Creature whisper", tip = "Speaks when a creature whispers to you. Off, creature whispers stay quiet." },
        { key = "chatBossEmote", label = "Boss emote", tip = "Speaks a boss emote during an encounter. Off, boss emotes stay quiet." },
        { key = "chatBossWhisper", label = "Boss whisper", tip = "Speaks when a boss whispers to you. Off, boss whispers stay quiet." },
        { key = "chatBossWarning", label = "Boss warning", tip = "Speaks encounter warnings. Off, boss warnings stay quiet." },
    } },
    { id = "bg", label = "Battlegrounds", rows = {
        { key = "chatBGNeutral", label = "Neutral", tip = "Speaks neutral battleground announcements. Off, those announcements stay quiet." },
        { key = "chatBGAlliance", label = "Alliance", tip = "Speaks Alliance battleground announcements. Off, Alliance announcements stay quiet." },
        { key = "chatBGHorde", label = "Horde", tip = "Speaks Horde battleground announcements. Off, Horde announcements stay quiet." },
    } },
    { id = "system", label = "System", rows = {
        { key = "chatSystem", label = "System", tip = "Speaks system messages from the game. Off, system messages stay quiet." },
        { key = "chatIgnored", label = "Ignored", tip = "Speaks when a player is ignoring you. Off, ignore notices stay quiet." },
        { key = "chatChannelNotice", label = "Channel notices", tip = "Speaks when you join or leave a channel, and when someone else joins or leaves. Off, channel notices stay quiet." },
        { key = "chatTargetIcons", label = "Target icons", tip = "Speaks when a raid target icon is placed. Off, target icon lines stay quiet." },
        { key = "chatBNAlert", label = "Friend alerts", tip = "Speaks when a friend comes online or updates a status. Off, friend alerts stay quiet." },
        { key = "chatPing", label = "Ping", tip = "Speaks when someone places a ping. Off, pings stay quiet." },
    } },
    { id = "progress", label = "Progress", rows = {
        { key = "chatAchievementProgress", label = "Achievement progress", tip = "Speaks when an achievement you have not finished moves forward. Achievement progress. Exploring Elwynn. 3 / 10. Read chat does not have to be on. Starts off." },
        { key = "chatQuestProgress", label = "Quest progress", tip = "Speaks when a quest objective moves forward. Quest progress. Cutting Teeth. Plainstriders slain, 2 / 8. Read chat does not have to be on. Starts off." },
        { key = "chatQuestAccepted", label = "Quest accepted", tip = "Speaks when you accept a quest. Quest accepted. Cutting Teeth. Read chat does not have to be on. Starts off." },
        { key = "chatQuestDetails", label = "Quest details", tip = "Speaks a quest offer, and a quest you select in the quest log. Cutting Teeth. Then the description, objectives, and rewards. Choose one. Linen Bag. Rough Stone. Read chat does not have to be on. Starts off." },
    } },
    { id = "npc", label = "NPC", rows = {
        { key = "chatNpcWindow", label = "NPC window", tip = "Speaks an NPC window when it opens. The NPC's name, then the greeting and choices, flight destinations, trainer skills, or merchant items and prices. A quest offer is read by Quest details. Read chat does not have to be on. Starts off." },
        { key = "chatItemSold", label = "Item sold", tip = "Speaks an item you sell to a merchant. Sold Linen Bag for 6 silver. Buying stays quiet. Read chat does not have to be on. Starts off." },
        { key = "chatRepair", label = "Repair", tip = "Speaks the cost when you repair your gear. You repaired your gear for 2 gold, 14 silver. A free repair stays quiet. Read chat does not have to be on. Starts off." },
    } },
    { id = "collections", label = "Collections", rows = {
        { key = "chatItemPickup", label = "Item pickup", tip = "Speaks an item you pick up. You picked up: Linen Cloth x4. This is separate from Rewards loot. If both are on, the item is spoken twice. Starts off." },
        { key = "chatTransmog", label = "Transmog", tip = "Speaks the first time an appearance is added. Transmog added: Red Linen Shirt. Starts off." },
        { key = "chatToy", label = "Toy", tip = "Speaks the first time a toy is added. Toy added: Picnic Basket. Starts off." },
        { key = "chatBattlePet", label = "Battle pet", tip = "Speaks the first time a battle pet is added. Battle pet added: Snowshoe Rabbit. Starts off." },
        { key = "chatCompanion", label = "Companion", tip = "Speaks the first time a companion is added. Companion added: Snowshoe Rabbit. Starts off." },
        { key = "chatMount", label = "Mount", tip = "Speaks the first time a mount is added. Mount added: Brown Horse. Starts off." },
        { key = "chatHeirloom", label = "Heirloom", tip = "Speaks the first time an heirloom is added. Heirloom added: Dignified Headmaster's Charge. Starts off." },
    } },
}

local COMBAT_SECTIONS = {
    { id = "fight", label = "Fight", rows = {
        { key = "combatReadEnabled", label = "Read combat", tip = "Turns combat reading on or off. On, the combat switches you enable are spoken. Off, combat stays quiet." },
        { key = "combatStarted", label = "Combat started and ended", tip = "Speaks when a fight starts and when it ends. Combat started. Combat ended." },
        { key = "combatEnemyTarget", label = "Enemy targeting you", tip = "Speaks when an enemy is targeting you, and includes their name. Hogger is targeting you." },
        { key = "combatYourTarget", label = "Your target", tip = "Speaks the name of the unit you target. Target. Hogger." },
    } },
    { id = "power", label = "Health and power", rows = {
        { key = "combatHealthLow", label = "Health under 35 percent", tip = "Speaks your health when it drops under 35 percent, and includes the percent. Health. 30 percent. It speaks again after your health rises to 35 percent or more and then drops under it again." },
        { key = "combatPowerLow", label = "Power under 35 percent", tip = "Speaks your main power when it drops under 35 percent. Mana, energy, rage, focus, and the same kind of bar. Mana. 30 percent." },
        { key = "combatSecondaryLow", label = "Secondary power low", tip = "Speaks when a secondary power is empty. Combo points, holy power, soul shards, and the same kind of points. Combo points low." },
        { key = "combatSecondaryFull", label = "Secondary power full", tip = "Speaks when a secondary power is full. Combo points full." },
    } },
    { id = "attacks", label = "Attacks", rows = {
        { key = "combatCastAtYou", label = "Cast at you", tip = "Speaks when an enemy is casting at you, and includes their name and the spell. Hogger casting Frostbolt." },
        { key = "combatInterrupt", label = "Interrupt", tip = "Speaks when that cast can be interrupted. Interrupt Frostbolt." },
        { key = "combatDispel", label = "Dispel", tip = "Speaks when a harmful effect on you can be dispelled, and includes the spell name. Dispel Curse of Agony." },
    } },
    { id = "control", label = "Control", rows = {
        { key = "combatStun", label = "Stunned", tip = "Speaks when you are stunned. Stunned." },
        { key = "combatRoot", label = "Rooted", tip = "Speaks when you are rooted. Rooted." },
        { key = "combatSilence", label = "Silenced", tip = "Speaks when you are silenced. Silenced." },
        { key = "combatPoisoned", label = "Poisoned", tip = "Speaks when a poison is on you. Poisoned." },
        { key = "combatPossessed", label = "Possessed", tip = "Speaks when you are possessed. Possessed." },
        { key = "combatPolymorph", label = "Polymorphed", tip = "Speaks when you are polymorphed. Polymorphed." },
        { key = "combatCrowd", label = "Crowd control", tip = "Speaks when a fear, sleep, cyclone, or another control in this group lands on you. Crowd control." },
        { key = "combatLossOther", label = "Loss of control", tip = "Speaks when the game reports a control that is not one of the other switches. Loss of control." },
    } },
    { id = "auras", label = "Auras", rows = {
        { key = "combatBuffGain", label = "Buff on you", tip = "Speaks when a helpful effect lands on you, and includes its name. Buff. Power Infusion." },
        { key = "combatDebuffGain", label = "Debuff on you", tip = "Speaks when a harmful effect lands on you, and includes its name. Debuff. Curse of Agony." },
    } },
}

local REWARD_SECTIONS = {
    { id = "experience", label = "Experience", rows = {
        { key = "progressXP", label = "Experience", tip = "Speaks experience you gain, then your new total. You gained 40 experience. Your experience is now: 1240 / 5800." },
    } },
    { id = "reputation", label = "Reputation", rows = {
        { key = "progressRep", label = "Reputation", tip = "Speaks reputation you gain while your standing stays the same. You gained 250 Reputation with Stormwind. Your reputation in Stormwind is: 839 / 3000." },
        { key = "progressRepStanding", label = "New standing", tip = "Speaks when your standing with a faction changes. You have reached Friendly with Stormwind." },
    } },
    { id = "currency", label = "Currency", rows = {
        { key = "lootCurrencyEnabled", label = "Currency", tip = "Speaks a currency you gain, then the new total. You gained 50 Honor. You now have 1250 Honor. Spending stays quiet." },
        { key = "rewardGold", label = "Gold", tip = "Speaks money you gain, then the new total. You gained 3 gold, 20 silver. You now have 12 gold, 4 silver. Spending stays quiet. Starts off." },
    } },
    { id = "items", label = "Items", rows = {
        { key = "lootItemsEnabled", label = "Loot", tip = "Speaks an item you loot. You looted: Peacebloom x2. The count is always spoken. It does not speak loot that belongs to someone else." },
    } },
    { id = "quests", label = "Quests", rows = {
        { key = "rewardQuestComplete", label = "Quest complete", tip = "Speaks when you turn a quest in. Quest complete. Cutting Teeth. Experience, reputation, items, and gold from that quest use their own lines. Starts off." },
    } },
    { id = "achievements", label = "Achievements", rows = {
        { key = "rewardAchievement", label = "Achievement earned", tip = "Speaks an achievement you earn, then your point total. Achievement earned. Exploring Elwynn. You now have 340 achievement points. Starts off." },
    } },
}

local frame
local pages = {}
local navButtons = {}
local chatSubs = {}
local combatSubs = {}
local rewardSubs = {}
local currentChat = "line"
local currentCombat = "fight"
local currentReward = "experience"
local toggles = {}
local addonRows = {}
local capturing = false
local captureCover = nil
local currentPage = "tooltip"
local chatTabsOpen = true
local combatTabsOpen = true
local rewardTabsOpen = true

local function Template()
    if BackdropTemplateMixin then
        return "BackdropTemplate"
    end
    return nil
end

local function Paint(f, bg, edge)
    if not f or not f.SetBackdrop then
        return
    end
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4] or 1)
    if edge then
        f:SetBackdropBorderColor(edge[1], edge[2], edge[3], edge[4] or 1)
    else
        f:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function SV()
    if AH.DB and AH.DB.Get then
        return AH.DB.Get()
    end
    return {}
end

local function OnFlag(key)
    return SV()[key] ~= false
end

local function Speak(text)
    if type(text) ~= "string" or text == "" then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(text, AH.Speech.PRIORITY_NAV or 3, { noEcho = true })
    end
end

local function SetFlag(key, on, label)
    SV()[key] = on and true or false
    Speak(label .. ". " .. (on and "On." or "Off."))
end

local function Held(fn)
    if type(fn) ~= "function" then
        return false
    end
    if AH.Compat and AH.Compat.SafeBool then
        return AH.Compat.SafeBool(fn)
    end
    local ok, value = pcall(fn)
    return ok and value == true
end

local function PrettyKey(key)
    if type(key) ~= "string" or key == "" then
        return "Not bound"
    end
    key = string.gsub(key, "ALT%-", "Alt-")
    key = string.gsub(key, "CTRL%-", "Ctrl-")
    key = string.gsub(key, "SHIFT%-", "Shift-")
    key = string.gsub(key, "BUTTON1", "Left mouse")
    key = string.gsub(key, "BUTTON2", "Right mouse")
    key = string.gsub(key, "BUTTON3", "Middle mouse")
    key = string.gsub(key, "BUTTON4", "Mouse 4")
    key = string.gsub(key, "BUTTON5", "Mouse 5")
    key = string.gsub(key, "MOUSEWHEELUP", "Wheel up")
    key = string.gsub(key, "MOUSEWHEELDOWN", "Wheel down")
    return key
end

local function Chord(key)
    if type(key) ~= "string" or key == "" then
        return nil
    end
    while true do
        if string.sub(key, 1, 4) == "ALT-" then
            key = string.sub(key, 5)
        elseif string.sub(key, 1, 5) == "CTRL-" then
            key = string.sub(key, 6)
        elseif string.sub(key, 1, 6) == "SHIFT-" then
            key = string.sub(key, 7)
        else
            break
        end
    end
    if key == "" or key == "ESCAPE" or key == "UNKNOWN" or key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
        return nil
    end
    local prefix = ""
    if Held(IsAltKeyDown) then
        prefix = prefix .. "ALT-"
    end
    if Held(IsControlKeyDown) then
        prefix = prefix .. "CTRL-"
    end
    if Held(IsShiftKeyDown) then
        prefix = prefix .. "SHIFT-"
    end
    return prefix .. key
end

local function KeyLabel()
    if capturing then
        return "Press a key"
    end
    if not GetBindingKey then
        return "Not bound"
    end
    local key = GetBindingKey("ACCESSIBILITYHELPER_READTOOLTIP")
    if type(key) ~= "string" or key == "" then
        return "Not bound"
    end
    return PrettyKey(key)
end

local function StyleButton(button, selected)
    Paint(button, selected and { 0.227, 0.180, 0.094, 1 } or BTN, selected and GOLD or EDGE)
    local font = button:GetFontString()
    if font then
        font:SetTextColor(selected and GOLD[1] or TEXT[1], selected and GOLD[2] or TEXT[2], selected and GOLD[3] or TEXT[3])
    end
end

local function StyleSub(button, selected)
    if selected then
        Paint(button, { 0.227, 0.180, 0.094, 1 }, GOLD)
    else
        Paint(button, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
    end
    local font = button:GetFontString()
    if font then
        font:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    end
end

local function HideTip()
    if GameTooltip and GameTooltip.Hide then
        GameTooltip:Hide()
    end
end

local function TipSentence(title, body)
    local titleText = title or ""
    local bodyText = body or ""
    if titleText ~= "" and bodyText ~= "" then
        return titleText .. ". " .. bodyText
    end
    if titleText ~= "" then
        return titleText
    end
    return bodyText
end

local function AttachTip(widget, title, body)
    if not widget or type(body) ~= "string" or body == "" then
        return
    end
    if widget.EnableMouse then
        widget:EnableMouse(true)
    end
    local spoken = TipSentence(title, body)
    widget._ahTipText = spoken
    if AH.Tooltips and AH.Tooltips.WatchTip then
        AH.Tooltips.WatchTip(widget, spoken)
    end
    widget:SetScript("OnEnter", function(self)
        if GameTooltip and GameTooltip.SetOwner then
            if GameTooltip.SetFrameStrata then
                GameTooltip:SetFrameStrata("TOOLTIP")
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:SetText(title or "", GOLD[1], GOLD[2], GOLD[3])
            GameTooltip:AddLine(body, TEXT[1], TEXT[2], TEXT[3], true)
            GameTooltip:Show()
        end
        if AH.Tooltips and AH.Tooltips.SetHoverText then
            AH.Tooltips.SetHoverText(self, spoken)
        end
    end)
    widget:SetScript("OnLeave", function(self)
        HideTip()
        if AH.Tooltips and AH.Tooltips.ClearHoverText then
            AH.Tooltips.ClearHoverText(self)
        end
    end)
end

local function MakeButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent, Template())
    button:SetSize(width, height)
    button:SetText(text)
    local font = button:GetFontString()
    if font then
        font:SetFontObject(GameFontHighlight)
    end
    StyleButton(button, false)
    return button
end

local function MakeToggle(parent, key, label, tip)
    local row = CreateFrame("Frame", nil, parent, Template())
    row:SetHeight(36)
    Paint(row, { 0.12, 0.10, 0.08, 1 }, EDGE)
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", 10, 0)
    name:SetText(label)
    name:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local button = MakeButton(row, "On", 64, 26)
    button:SetPoint("RIGHT", -6, 0)
    button._key = key
    button._label = label
    button:SetScript("OnClick", function(self)
        local nextOn = not OnFlag(self._key)
        SetFlag(self._key, nextOn, self._label)
        for i = 1, #toggles do
            local other = toggles[i]
            if other._key == self._key then
                other:SetText(nextOn and "On" or "Off")
                other._selected = nextOn
                StyleButton(other, nextOn)
            end
        end
    end)
    AttachTip(row, label, tip)
    AttachTip(button, label, tip)
    toggles[#toggles + 1] = button
    row.button = button
    return row
end

local function RefreshToggles()
    for i = 1, #toggles do
        local button = toggles[i]
        local on = OnFlag(button._key)
        button:SetText(on and "On" or "Off")
        button._selected = on
        StyleButton(button, on)
    end
end

local function AddonCount()
    if C_AddOns and C_AddOns.GetNumAddOns then
        local ok, n = pcall(C_AddOns.GetNumAddOns)
        if ok and type(n) == "number" then
            return n
        end
    end
    if GetNumAddOns then
        return GetNumAddOns() or 0
    end
    return 0
end

local function AddonInfo(index)
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local ok, name, title = pcall(C_AddOns.GetAddOnInfo, index)
        if ok then
            return name, title
        end
    end
    if GetAddOnInfo then
        return GetAddOnInfo(index)
    end
    return nil
end

local function AddonLoaded(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, name)
        return ok and loaded and true or false
    end
    if IsAddOnLoaded then
        return IsAddOnLoaded(name) and true or false
    end
    return false
end

local function LoadedAddons()
    local list = {}
    local seen = {}
    local count = AddonCount()
    for i = 1, count do
        local name, title = AddonInfo(i)
        if type(name) == "string" and name ~= "AccessibilityHelper" and string.sub(name, 1, 9) ~= "Blizzard_" then
            if AddonLoaded(name) and not seen[name] then
                seen[name] = true
                local shown = title
                if type(shown) ~= "string" or shown == "" then
                    shown = name
                end
                shown = string.gsub(shown, "|c%x%x%x%x%x%x%x%x", "")
                shown = string.gsub(shown, "|r", "")
                list[#list + 1] = { name = name, title = shown }
            end
        end
    end
    table.sort(list, function(a, b)
        return string.lower(a.title) < string.lower(b.title)
    end)
    return list
end

local function AddonOn(name)
    local map = SV().tooltipAddons
    if type(map) ~= "table" then
        return true
    end
    return map[name] ~= false
end

local function SetAddon(name, title, on)
    local sv = SV()
    if type(sv.tooltipAddons) ~= "table" then
        sv.tooltipAddons = {}
    end
    sv.tooltipAddons[name] = on and true or false
    Speak(title .. ". " .. (on and "On." or "Off."))
end

local function EnsureAddonRow(index, parent)
    local row = addonRows[index]
    if row then
        return row
    end
    row = CreateFrame("Frame", nil, parent, Template())
    row:SetHeight(32)
    Paint(row, { 0.12, 0.10, 0.08, 1 }, EDGE)
    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", 8, 0)
    name:SetPoint("RIGHT", -78, 0)
    name:SetJustifyH("LEFT")
    name:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    row.name = name
    local button = MakeButton(row, "On", 64, 24)
    button:SetPoint("RIGHT", -4, 0)
    button:SetScript("OnClick", function(self)
        local nextOn = not AddonOn(self._addon)
        SetAddon(self._addon, self._title, nextOn)
        self:SetText(nextOn and "On" or "Off")
        self._selected = nextOn
        StyleButton(self, nextOn)
    end)
    row.button = button
    addonRows[index] = row
    return row
end

local function ShowPage(id, quiet)
    currentPage = id
    if AH.Tooltips and AH.Tooltips.ForgetWindowTip then
        AH.Tooltips.ForgetWindowTip()
    end
    for i = 1, #PAGES do
        local pageId = PAGES[i].id
        if pages[pageId] then
            if pageId == id then
                pages[pageId]:Show()
            else
                pages[pageId]:Hide()
            end
        end
        local button = navButtons[pageId]
        if button then
            button._selected = pageId == id
            StyleButton(button, pageId == id)
        end
    end
    if quiet then
        return
    end
    if id == "commands" and pages.commands and pages.commands.Refresh then
        pages.commands.Refresh()
    end
    for i = 1, #PAGES do
        if PAGES[i].id == id then
            Speak(PAGES[i].label .. ".")
            return
        end
    end
end

local function RefreshSpeech()
    if not pages.speech then
        return
    end
    local rate = AH.DB and AH.DB.GetTtsRate and AH.DB.GetTtsRate() or 0
    local volume = AH.DB and AH.DB.GetTtsVolume and AH.DB.GetTtsVolume() or 100
    pages.speech.rateValue:SetText(tostring(rate))
    pages.speech.volumeValue:SetText(tostring(volume))
    local voice = "System default"
    if AH.DB and AH.DB.GetSavedTtsVoiceID and AH.Compat and AH.Compat.GetTtsVoiceName then
        local id = AH.DB.GetSavedTtsVoiceID()
        if type(id) == "number" then
            voice = AH.Compat.GetTtsVoiceName(id)
        end
    end
    pages.speech.voiceButton:SetText(voice)
end

local function RefreshAddons()
    local page = pages.tooltip
    if not page then
        return
    end
    local list = LoadedAddons()
    local y = 0
    for i = 1, #list do
        local row = EnsureAddonRow(i, page.addonChild)
        local item = list[i]
        row.name:SetText(item.title)
        row.button._addon = item.name
        row.button._title = item.title
        local on = AddonOn(item.name)
        row.button:SetText(on and "On" or "Off")
        row.button._selected = on
        StyleButton(row.button, on)
        local addonTip = "On, the read key speaks tooltips from " .. item.title .. ". Off, tooltips from that addon are skipped."
        AttachTip(row, item.title, addonTip)
        AttachTip(row.button, item.title, addonTip)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)
        row:Show()
        y = y + 36
    end
    for i = #list + 1, #addonRows do
        addonRows[i]:Hide()
    end
    page.addonChild:SetHeight(math.max(36, y))
    if page.addonEmpty then
        if #list == 0 then
            page.addonEmpty:Show()
        else
            page.addonEmpty:Hide()
        end
    end
    page.keyButton:SetText(KeyLabel())
end

local function Refresh()
    RefreshToggles()
    RefreshSpeech()
    RefreshAddons()
end

local function BindReadKey(key)
    if type(key) ~= "string" or key == "" then
        return
    end
    if key == "ESCAPE" or key == "UNKNOWN" or key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
        return
    end
    if not SetBinding then
        return
    end
    local old1, old2 = nil, nil
    if GetBindingKey then
        old1, old2 = GetBindingKey("ACCESSIBILITYHELPER_READTOOLTIP")
    end
    if old1 then
        SetBinding(old1)
    end
    if old2 then
        SetBinding(old2)
    end
    SetBinding(key, "ACCESSIBILITYHELPER_READTOOLTIP")
    if SaveBindings and GetCurrentBindingSet then
        local set = GetCurrentBindingSet()
        if type(set) == "number" then
            SaveBindings(set)
        end
    end
    capturing = false
    if captureCover then
        captureCover:Hide()
    end
    if frame and frame.EnableKeyboard then
        frame:EnableKeyboard(false)
    end
    Speak("Read key. " .. PrettyKey(key) .. ".")
    RefreshAddons()
end

local function Build()
    if frame then
        return frame
    end
    frame = CreateFrame("Frame", "AccessibilityHelperWindow", UIParent, Template())
    frame:SetSize(680, 640)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    Paint(frame, BG, GOLD)
    table.insert(UISpecialFrames, "AccessibilityHelperWindow")

    local title = CreateFrame("Frame", nil, frame, Template())
    title:SetPoint("TOPLEFT", 1, -1)
    title:SetPoint("TOPRIGHT", -1, -1)
    title:SetHeight(44)
    Paint(title, TITLE_BG, nil)
    title:EnableMouse(true)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    title:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    local icon = title:CreateTexture(nil, "ARTWORK")
    icon:SetSize(28, 28)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture(ICON)

    local heading = title:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    heading:SetText("Accessibility Helper")
    heading:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local close = MakeButton(title, "X", 28, 28)
    close:SetPoint("RIGHT", -8, 0)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)
    AttachTip(close, "Close", "Closes this window. Escape closes it too. Your switches stay as you left them.")

    local nav = CreateFrame("Frame", nil, frame, Template())
    nav:SetPoint("TOPLEFT", 1, -46)
    nav:SetPoint("BOTTOMLEFT", 1, 28)
    nav:SetWidth(176)
    Paint(nav, NAV_BG, nil)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 8, -8)
    content:SetPoint("BOTTOMRIGHT", -10, 36)

    for i = 1, #PAGES do
        local info = PAGES[i]
        local button = MakeButton(nav, info.label, 154, 32)
        button:SetPoint("TOPLEFT", 10, -10 - (i - 1) * 38)
        button._page = info.id
        button:SetScript("OnClick", function(self)
            ShowPage(self._page)
        end)
        AttachTip(button, info.label, info.tip)
        navButtons[info.id] = button
        if info.id == "chat" or info.id == "combat" or info.id == "rewards" then
            local arrow = button:CreateTexture(nil, "OVERLAY")
            arrow:SetSize(14, 14)
            arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
            arrow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3])
            local font = button:GetFontString()
            if font then
                arrow:SetPoint("RIGHT", font, "LEFT", -4, 0)
            else
                arrow:SetPoint("LEFT", 8, 0)
            end
            button.arrow = arrow
        end
    end

    local tooltip = CreateFrame("Frame", nil, content)
    tooltip:SetAllPoints(content)
    pages.tooltip = tooltip
    local tipTitle = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    tipTitle:SetPoint("TOPLEFT", 0, 0)
    tipTitle:SetText("Tooltip reader")
    tipTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local tipNote = tooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tipNote:SetPoint("TOPLEFT", tipTitle, "BOTTOMLEFT", 0, -6)
    tipNote:SetPoint("RIGHT", -4, 0)
    tipNote:SetJustifyH("LEFT")
    tipNote:SetText("The read key speaks every line on the tooltip that is open. Press that key again to stop.")
    tipNote:SetTextColor(TEXT[1], TEXT[2], TEXT[3])

    local keyRow = CreateFrame("Frame", nil, tooltip, Template())
    keyRow:SetPoint("TOPLEFT", tipNote, "BOTTOMLEFT", 0, -10)
    keyRow:SetPoint("RIGHT", -4, 0)
    keyRow:SetHeight(36)
    Paint(keyRow, { 0.12, 0.10, 0.08, 1 }, EDGE)
    local keyLabel = keyRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    keyLabel:SetPoint("LEFT", 10, 0)
    keyLabel:SetText("Read key")
    keyLabel:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local keyButton = MakeButton(keyRow, "Not bound", 220, 26)
    keyButton:SetPoint("RIGHT", -6, 0)
    keyButton:SetScript("OnClick", function()
        capturing = true
        if frame.EnableKeyboard then
            frame:EnableKeyboard(true)
        end
        if not captureCover then
            captureCover = CreateFrame("Frame", nil, frame)
            captureCover:SetAllPoints(frame)
            captureCover:SetFrameStrata("DIALOG")
            captureCover:EnableMouse(true)
            captureCover:EnableMouseWheel(true)
            captureCover:SetScript("OnMouseDown", function(_, button)
                if not capturing then
                    return
                end
                local mouseKey = nil
                if button == "LeftButton" then
                    mouseKey = "BUTTON1"
                elseif button == "RightButton" then
                    mouseKey = "BUTTON2"
                elseif button == "MiddleButton" then
                    mouseKey = "BUTTON3"
                elseif button == "Button4" then
                    mouseKey = "BUTTON4"
                elseif button == "Button5" then
                    mouseKey = "BUTTON5"
                end
                local chord = mouseKey and Chord(mouseKey) or nil
                if chord then
                    BindReadKey(chord)
                end
            end)
            captureCover:SetScript("OnMouseWheel", function(_, delta)
                if not capturing or type(delta) ~= "number" then
                    return
                end
                local wheel = nil
                if delta > 0 then
                    wheel = "MOUSEWHEELUP"
                elseif delta < 0 then
                    wheel = "MOUSEWHEELDOWN"
                end
                local chord = wheel and Chord(wheel) or nil
                if chord then
                    BindReadKey(chord)
                end
            end)
        end
        captureCover:SetFrameLevel((frame:GetFrameLevel() or 1) + 30)
        captureCover:Show()
        keyButton:SetText("Press a key")
        Speak("Press a key or mouse button. Alt, Control, and Shift can be held.")
    end)
    local keyTip = "Click, then press the key or mouse button you want. Hold Alt, Control, or Shift to add it. That key reads every line of the tooltip that is open. Press the same key again while it is speaking to stop. Moving the mouse does not start a read."
    AttachTip(keyRow, "Read key", keyTip)
    AttachTip(keyButton, "Read key", keyTip)
    tooltip.keyButton = keyButton

    local read = MakeToggle(tooltip, "tooltipsEnabled", "Read tooltips", "Turns the read key on or off. On, the key speaks the open tooltip. Off, the key says that tooltip reading is disabled.")
    read:SetPoint("TOPLEFT", keyRow, "BOTTOMLEFT", 0, -8)
    read:SetPoint("RIGHT", -4, 0)
    local sections = MakeToggle(tooltip, "tooltipAddonSections", "Addon sections", "On, the read includes extra lines other addons add to a tooltip. Off, those extra sections are left out and the game's own lines are spoken.")
    sections:SetPoint("TOPLEFT", read, "BOTTOMLEFT", 0, -6)
    sections:SetPoint("RIGHT", -4, 0)
    local compare = MakeToggle(tooltip, "tooltipCompare", "Compare window", "On, if a compare window is open beside the item, the read key speaks that window after the main tooltip. Off, the compare window is skipped.")
    compare:SetPoint("TOPLEFT", sections, "BOTTOMLEFT", 0, -6)
    compare:SetPoint("RIGHT", -4, 0)

    local listTitle = tooltip:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listTitle:SetPoint("TOPLEFT", compare, "BOTTOMLEFT", 0, -10)
    listTitle:SetText("Active addons")
    listTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local scroll = CreateFrame("ScrollFrame", nil, tooltip)
    scroll:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -4, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(460)
    child:SetHeight(36)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local nextScroll = self:GetVerticalScroll() - (delta * 36)
        if nextScroll < 0 then
            nextScroll = 0
        end
        local maxScroll = self:GetVerticalScrollRange() or 0
        if nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
    end)
    tooltip.addonChild = child
    local empty = tooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    empty:SetPoint("TOPLEFT", listTitle, "BOTTOMLEFT", 0, -8)
    empty:SetText("No other addons are loaded.")
    empty:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    empty:Hide()
    tooltip.addonEmpty = empty

    local speech = CreateFrame("Frame", nil, content)
    speech:SetAllPoints(content)
    speech:Hide()
    pages.speech = speech
    local speechTitle = speech:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    speechTitle:SetPoint("TOPLEFT", 0, 0)
    speechTitle:SetText("Speech")
    speechTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local speechNote = speech:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    speechNote:SetPoint("TOPLEFT", speechTitle, "BOTTOMLEFT", 0, -6)
    speechNote:SetPoint("RIGHT", -4, 0)
    speechNote:SetJustifyH("LEFT")
    speechNote:SetText("Voice, rate, and volume apply to every page, including the tooltip reader.")
    speechNote:SetTextColor(TEXT[1], TEXT[2], TEXT[3])

    local voiceRow = CreateFrame("Frame", nil, speech, Template())
    voiceRow:SetPoint("TOPLEFT", speechNote, "BOTTOMLEFT", 0, -12)
    voiceRow:SetPoint("RIGHT", -4, 0)
    voiceRow:SetHeight(36)
    Paint(voiceRow, { 0.12, 0.10, 0.08, 1 }, EDGE)
    local voiceLabel = voiceRow:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    voiceLabel:SetPoint("LEFT", 10, 0)
    voiceLabel:SetText("Voice")
    voiceLabel:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local voiceButton = MakeButton(voiceRow, "System default", 220, 26)
    voiceButton:SetPoint("RIGHT", -6, 0)
    voiceButton:SetScript("OnClick", function()
        local voices = AH.Compat and AH.Compat.ListTtsVoices and AH.Compat.ListTtsVoices() or {}
        local sv = SV()
        local current = sv.addonTtsVoiceID
        local pick = -1
        if type(current) ~= "number" or current < 0 then
            if voices[1] then
                pick = voices[1].voiceID
            end
        else
            local found = false
            for i = 1, #voices do
                if voices[i].voiceID == current then
                    found = true
                    if voices[i + 1] then
                        pick = voices[i + 1].voiceID
                    end
                    break
                end
            end
            if not found and voices[1] then
                pick = voices[1].voiceID
            end
        end
        sv.addonTtsVoiceID = pick
        RefreshSpeech()
        Speak("Voice. " .. voiceButton:GetText() .. ".")
    end)
    local voiceTip = "Click to move to the next installed voice. System default uses the voice from WoW's own accessibility settings. The choice is used for every spoken line."
    AttachTip(voiceRow, "Voice", voiceTip)
    AttachTip(voiceButton, "Voice", voiceTip)
    speech.voiceButton = voiceButton

    local function Stepper(anchor, caption, getter, setter, minValue, maxValue)
        local row = CreateFrame("Frame", nil, speech, Template())
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
        row:SetPoint("RIGHT", -4, 0)
        row:SetHeight(36)
        Paint(row, { 0.12, 0.10, 0.08, 1 }, EDGE)
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("LEFT", 10, 0)
        label:SetText(caption)
        label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
        local value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("RIGHT", -150, 0)
        value:SetText("0")
        value:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        local minus = MakeButton(row, "-", 36, 26)
        minus:SetPoint("RIGHT", -78, 0)
        local plus = MakeButton(row, "+", 36, 26)
        plus:SetPoint("RIGHT", -6, 0)
        local function apply(delta)
            local nextValue = getter() + delta
            if nextValue < minValue then
                nextValue = minValue
            end
            if nextValue > maxValue then
                nextValue = maxValue
            end
            setter(nextValue)
            value:SetText(tostring(nextValue))
            Speak(caption .. ". " .. tostring(nextValue) .. ".")
        end
        minus:SetScript("OnClick", function()
            apply(-1)
        end)
        plus:SetScript("OnClick", function()
            apply(1)
        end)
        local stepTip
        if caption == "Rate" then
            stepTip = "How fast speech is spoken. 0 is the slowest and 10 is the fastest. This speed is used for every spoken line."
        else
            stepTip = "How loud Accessibility Helper speaks. 0 is silent and 100 is full volume."
        end
        AttachTip(row, caption, stepTip)
        AttachTip(minus, caption, "Lowers " .. string.lower(caption) .. ". " .. stepTip)
        AttachTip(plus, caption, "Raises " .. string.lower(caption) .. ". " .. stepTip)
        return row, value
    end

    local rateRow, rateValue = Stepper(voiceRow, "Rate", function()
        return AH.DB and AH.DB.GetTtsRate and AH.DB.GetTtsRate() or 0
    end, function(value)
        SV().addonTtsRate = value
    end, 0, 10)
    speech.rateValue = rateValue
    local volumeRow, volumeValue = Stepper(rateRow, "Volume", function()
        return AH.DB and AH.DB.GetTtsVolume and AH.DB.GetTtsVolume() or 100
    end, function(value)
        SV().addonTtsVolume = value
    end, 0, 100)
    speech.volumeValue = volumeValue

    local test = MakeButton(speech, "Test speech", 160, 32)
    test:SetPoint("TOPLEFT", volumeRow, "BOTTOMLEFT", 0, -12)
    test:SetScript("OnClick", function()
        if AH.Speech and AH.Speech.SpeakTest then
            AH.Speech.SpeakTest()
        end
    end)
    AttachTip(test, "Test speech", "Speaks a short test line in the voice, rate, and volume you have selected.")

    local chat = CreateFrame("Frame", nil, content)
    chat:SetAllPoints(content)
    chat:Hide()
    pages.chat = chat
    local chatTitle = chat:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    chatTitle:SetPoint("TOPLEFT", 0, 0)
    chatTitle:SetText("Line")
    chatTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local chatScroll = CreateFrame("ScrollFrame", nil, chat)
    chatScroll:SetPoint("TOPLEFT", chatTitle, "BOTTOMLEFT", 0, -8)
    chatScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local chatHolders = {}
    for s = 1, #CHAT_SECTIONS do
        local sec = CHAT_SECTIONS[s]
        local holder = CreateFrame("Frame", nil, chatScroll)
        holder:SetWidth(460)
        local y = 0
        for r = 1, #sec.rows do
            local info = sec.rows[r]
            local row = MakeToggle(holder, info.key, info.label, info.tip)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", 0, 0)
            y = y + 44
        end
        holder:SetHeight(y)
        holder:Hide()
        chatHolders[sec.id] = holder
    end
    local function ShowChatSection(id, quiet)
        currentChat = id
        local label = "Line"
        for s = 1, #CHAT_SECTIONS do
            local sec = CHAT_SECTIONS[s]
            local on = sec.id == id
            if on then
                label = sec.label
            end
            local sub = chatSubs[sec.id]
            if sub then
                StyleSub(sub, on)
            end
        end
        local holder = chatHolders[id] or chatHolders.line
        for s = 1, #CHAT_SECTIONS do
            local other = chatHolders[CHAT_SECTIONS[s].id]
            if other and other ~= holder then
                other:Hide()
            end
        end
        if AH.Tooltips and AH.Tooltips.ForgetWindowTip then
            AH.Tooltips.ForgetWindowTip()
        end
        chatScroll:SetScrollChild(holder)
        holder:Show()
        local width = chatScroll:GetWidth()
        if type(width) ~= "number" or width < 40 then
            width = 460
        end
        holder:SetWidth(width)
        chatScroll:SetVerticalScroll(0)
        chatTitle:SetText(label)
        if not quiet then
            Speak(label .. ".")
        end
    end
    chatScroll:EnableMouseWheel(true)
    chatScroll:SetScript("OnMouseWheel", function(self, delta)
        local child = self:GetScrollChild()
        if not child then
            return
        end
        local maxScroll = child:GetHeight() - self:GetHeight()
        if maxScroll < 0 then
            maxScroll = 0
        end
        local nextScroll = self:GetVerticalScroll() - (delta * 36)
        if nextScroll < 0 then
            nextScroll = 0
        end
        if nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
    end)
    local LayoutNav
    local function SetSectionArrow(button, open)
        if button and button.arrow and button.arrow.SetRotation then
            if open then
                button.arrow:SetRotation(0)
            else
                button.arrow:SetRotation(math.pi)
            end
        end
    end
    local function ApplyChatTabs()
        SetSectionArrow(navButtons.chat, chatTabsOpen)
        if LayoutNav then
            LayoutNav()
        end
    end
    if navButtons.chat then
        navButtons.chat:SetScript("OnClick", function()
            chatTabsOpen = not chatTabsOpen
            ApplyChatTabs()
            ShowPage("chat", true)
            if chatTabsOpen then
                Speak("Chat expanded.")
            else
                Speak("Chat collapsed.")
            end
        end)
    end

    local previousSub = nil
    for s = 1, #CHAT_SECTIONS do
        local sec = CHAT_SECTIONS[s]
        local sub = CreateFrame("Button", nil, nav, Template())
        sub:SetSize(140, 22)
        local fs = sub:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 6, 0)
        fs:SetPoint("RIGHT", -2, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetText(sec.label)
        fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        sub:SetFontString(fs)
        sub._section = sec.id
        if previousSub then
            sub:SetPoint("TOPLEFT", previousSub, "BOTTOMLEFT", 0, -2)
        else
            sub:SetPoint("TOPLEFT", navButtons.chat, "BOTTOMLEFT", 18, -4)
        end
        StyleSub(sub, sec.id == "line")
        sub:SetScript("OnClick", function(self)
            ShowPage("chat", true)
            ShowChatSection(self._section)
        end)
        AttachTip(sub, sec.label, "Opens the " .. sec.label .. " switches.")
        chatSubs[sec.id] = sub
        previousSub = sub
    end
    ShowChatSection("line", true)
    ApplyChatTabs()

    local combat = CreateFrame("Frame", nil, content)
    combat:SetAllPoints(content)
    combat:Hide()
    pages.combat = combat
    local combatTitle = combat:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    combatTitle:SetPoint("TOPLEFT", 0, 0)
    combatTitle:SetText("Fight")
    combatTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local combatScroll = CreateFrame("ScrollFrame", nil, combat)
    combatScroll:SetPoint("TOPLEFT", combatTitle, "BOTTOMLEFT", 0, -8)
    combatScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local combatHolders = {}
    for s = 1, #COMBAT_SECTIONS do
        local sec = COMBAT_SECTIONS[s]
        local holder = CreateFrame("Frame", nil, combatScroll)
        holder:SetWidth(460)
        local y = 0
        for r = 1, #sec.rows do
            local info = sec.rows[r]
            local row = MakeToggle(holder, info.key, info.label, info.tip)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", 0, 0)
            y = y + 44
        end
        holder:SetHeight(y)
        holder:Hide()
        combatHolders[sec.id] = holder
    end
    local function ShowCombatSection(id, quiet)
        currentCombat = id
        local label = "Fight"
        for s = 1, #COMBAT_SECTIONS do
            local sec = COMBAT_SECTIONS[s]
            local on = sec.id == id
            if on then
                label = sec.label
            end
            local sub = combatSubs[sec.id]
            if sub then
                StyleSub(sub, on)
            end
        end
        local holder = combatHolders[id] or combatHolders.fight
        for s = 1, #COMBAT_SECTIONS do
            local other = combatHolders[COMBAT_SECTIONS[s].id]
            if other and other ~= holder then
                other:Hide()
            end
        end
        if AH.Tooltips and AH.Tooltips.ForgetWindowTip then
            AH.Tooltips.ForgetWindowTip()
        end
        combatScroll:SetScrollChild(holder)
        holder:Show()
        local width = combatScroll:GetWidth()
        if type(width) ~= "number" or width < 40 then
            width = 460
        end
        holder:SetWidth(width)
        combatScroll:SetVerticalScroll(0)
        combatTitle:SetText(label)
        if not quiet then
            Speak(label .. ".")
        end
    end
    combatScroll:EnableMouseWheel(true)
    combatScroll:SetScript("OnMouseWheel", function(self, delta)
        local child = self:GetScrollChild()
        if not child then
            return
        end
        local maxScroll = child:GetHeight() - self:GetHeight()
        if maxScroll < 0 then
            maxScroll = 0
        end
        local nextScroll = self:GetVerticalScroll() - (delta * 36)
        if nextScroll < 0 then
            nextScroll = 0
        end
        if nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
    end)
    local function ApplyCombatTabs()
        SetSectionArrow(navButtons.combat, combatTabsOpen)
        if LayoutNav then
            LayoutNav()
        end
    end
    if navButtons.combat then
        navButtons.combat:SetScript("OnClick", function()
            combatTabsOpen = not combatTabsOpen
            ApplyCombatTabs()
            ShowPage("combat", true)
            if combatTabsOpen then
                Speak("Combat expanded.")
            else
                Speak("Combat collapsed.")
            end
        end)
    end
    local previousCombat = nil
    for s = 1, #COMBAT_SECTIONS do
        local sec = COMBAT_SECTIONS[s]
        local sub = CreateFrame("Button", nil, nav, Template())
        sub:SetSize(140, 22)
        local fs = sub:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 6, 0)
        fs:SetPoint("RIGHT", -2, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetText(sec.label)
        fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        sub:SetFontString(fs)
        sub._section = sec.id
        if previousCombat then
            sub:SetPoint("TOPLEFT", previousCombat, "BOTTOMLEFT", 0, -2)
        else
            sub:SetPoint("TOPLEFT", navButtons.combat, "BOTTOMLEFT", 18, -4)
        end
        StyleSub(sub, sec.id == "fight")
        sub:SetScript("OnClick", function(self)
            ShowPage("combat", true)
            ShowCombatSection(self._section)
        end)
        AttachTip(sub, sec.label, "Opens the " .. sec.label .. " switches.")
        combatSubs[sec.id] = sub
        previousCombat = sub
    end
    ShowCombatSection("fight", true)

    local rewards = CreateFrame("Frame", nil, content)
    rewards:SetAllPoints(content)
    rewards:Hide()
    pages.rewards = rewards
    local rewardsTitle = rewards:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rewardsTitle:SetPoint("TOPLEFT", 0, 0)
    rewardsTitle:SetText("Experience")
    rewardsTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local rewardsScroll = CreateFrame("ScrollFrame", nil, rewards)
    rewardsScroll:SetPoint("TOPLEFT", rewardsTitle, "BOTTOMLEFT", 0, -8)
    rewardsScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local rewardHolders = {}
    for s = 1, #REWARD_SECTIONS do
        local sec = REWARD_SECTIONS[s]
        local holder = CreateFrame("Frame", nil, rewardsScroll)
        holder:SetWidth(460)
        local y = 0
        for r = 1, #sec.rows do
            local info = sec.rows[r]
            local row = MakeToggle(holder, info.key, info.label, info.tip)
            row:SetPoint("TOPLEFT", 0, -y)
            row:SetPoint("RIGHT", 0, 0)
            y = y + 44
        end
        holder:SetHeight(y)
        holder:Hide()
        rewardHolders[sec.id] = holder
    end
    local function ShowRewardSection(id, quiet)
        currentReward = id
        local label = "Experience"
        for s = 1, #REWARD_SECTIONS do
            local sec = REWARD_SECTIONS[s]
            local on = sec.id == id
            if on then
                label = sec.label
            end
            local sub = rewardSubs[sec.id]
            if sub then
                StyleSub(sub, on)
            end
        end
        local holder = rewardHolders[id] or rewardHolders.experience
        for s = 1, #REWARD_SECTIONS do
            local other = rewardHolders[REWARD_SECTIONS[s].id]
            if other and other ~= holder then
                other:Hide()
            end
        end
        if AH.Tooltips and AH.Tooltips.ForgetWindowTip then
            AH.Tooltips.ForgetWindowTip()
        end
        rewardsScroll:SetScrollChild(holder)
        holder:Show()
        local width = rewardsScroll:GetWidth()
        if type(width) ~= "number" or width < 40 then
            width = 460
        end
        holder:SetWidth(width)
        rewardsScroll:SetVerticalScroll(0)
        rewardsTitle:SetText(label)
        if not quiet then
            Speak(label .. ".")
        end
    end
    rewardsScroll:EnableMouseWheel(true)
    rewardsScroll:SetScript("OnMouseWheel", function(self, delta)
        local child = self:GetScrollChild()
        if not child then
            return
        end
        local maxScroll = child:GetHeight() - self:GetHeight()
        if maxScroll < 0 then
            maxScroll = 0
        end
        local nextScroll = self:GetVerticalScroll() - (delta * 36)
        if nextScroll < 0 then
            nextScroll = 0
        end
        if nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
    end)
    local function ApplyRewardTabs()
        SetSectionArrow(navButtons.rewards, rewardTabsOpen)
        if LayoutNav then
            LayoutNav()
        end
    end
    if navButtons.rewards then
        navButtons.rewards:SetScript("OnClick", function()
            rewardTabsOpen = not rewardTabsOpen
            ApplyRewardTabs()
            ShowPage("rewards", true)
            if rewardTabsOpen then
                Speak("Rewards expanded.")
            else
                Speak("Rewards collapsed.")
            end
        end)
    end
    local previousReward = nil
    for s = 1, #REWARD_SECTIONS do
        local sec = REWARD_SECTIONS[s]
        local sub = CreateFrame("Button", nil, nav, Template())
        sub:SetSize(140, 22)
        local fs = sub:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", 6, 0)
        fs:SetPoint("RIGHT", -2, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        fs:SetText(sec.label)
        fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        sub:SetFontString(fs)
        sub._section = sec.id
        if previousReward then
            sub:SetPoint("TOPLEFT", previousReward, "BOTTOMLEFT", 0, -2)
        else
            sub:SetPoint("TOPLEFT", navButtons.rewards, "BOTTOMLEFT", 18, -4)
        end
        StyleSub(sub, sec.id == "experience")
        sub:SetScript("OnClick", function(self)
            ShowPage("rewards", true)
            ShowRewardSection(self._section)
        end)
        AttachTip(sub, sec.label, "Opens the " .. sec.label .. " switches.")
        rewardSubs[sec.id] = sub
        previousReward = sub
    end
    ShowRewardSection("experience", true)

    LayoutNav = function()
        local y = -10
        for i = 1, #PAGES do
            local page = PAGES[i]
            local button = navButtons[page.id]
            if button then
                button:ClearAllPoints()
                button:SetPoint("TOPLEFT", nav, "TOPLEFT", 10, y)
                y = y - 38
            end
            local sections, subs, open
            if page.id == "chat" then
                sections = CHAT_SECTIONS
                subs = chatSubs
                open = chatTabsOpen
            elseif page.id == "combat" then
                sections = COMBAT_SECTIONS
                subs = combatSubs
                open = combatTabsOpen
            elseif page.id == "rewards" then
                sections = REWARD_SECTIONS
                subs = rewardSubs
                open = rewardTabsOpen
            end
            if sections and subs then
                for s = 1, #sections do
                    local sub = subs[sections[s].id]
                    if sub then
                        if open then
                            sub:ClearAllPoints()
                            sub:SetPoint("TOPLEFT", nav, "TOPLEFT", 28, y)
                            sub:Show()
                            y = y - 24
                        else
                            sub:Hide()
                        end
                    end
                end
            end
        end
    end
    ApplyCombatTabs()
    ApplyRewardTabs()

    local arrows = CreateFrame("Frame", nil, content)
    arrows:SetAllPoints(content)
    arrows:Hide()
    pages.arrows = arrows
    local arrowsTitle = arrows:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    arrowsTitle:SetPoint("TOPLEFT", 0, 0)
    arrowsTitle:SetText("Arrows")
    arrowsTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local arrowsNote = arrows:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    arrowsNote:SetPoint("TOPLEFT", arrowsTitle, "BOTTOMLEFT", 0, -6)
    arrowsNote:SetPoint("RIGHT", -4, 0)
    arrowsNote:SetJustifyH("LEFT")
    arrowsNote:SetText("These commands read the arrow that is showing. They are not printed.")
    arrowsNote:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local arrowRows = {
        { key = "tomtomReadEnabled", label = "TomTom arrow", tip = "On, /ahtt, /aharrow, /ahtomtom, and the TomTom keybind speak the waypoint name, the distance, and the time to arrive. Off, those commands say that TomTom reading is disabled." },
        { key = "zygorReadEnabled", label = "Zygor arrow", tip = "On, /ahz, /ahzygor, and the Zygor keybind speak the waypoint name and the distance. Off, those commands say that Zygor reading is disabled." },
    }
    local previousArrow = nil
    for i = 1, #arrowRows do
        local row = MakeToggle(arrows, arrowRows[i].key, arrowRows[i].label, arrowRows[i].tip)
        if previousArrow then
            row:SetPoint("TOPLEFT", previousArrow, "BOTTOMLEFT", 0, -8)
        else
            row:SetPoint("TOPLEFT", arrowsNote, "BOTTOMLEFT", 0, -8)
        end
        row:SetPoint("RIGHT", 0, 0)
        previousArrow = row
    end

    local status = CreateFrame("Frame", nil, content)
    status:SetAllPoints(content)
    status:Hide()
    pages.status = status
    local statusTitle = status:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    statusTitle:SetPoint("TOPLEFT", 0, 0)
    statusTitle:SetText("Status")
    statusTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local statusNote = status:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    statusNote:SetPoint("TOPLEFT", statusTitle, "BOTTOMLEFT", 0, -6)
    statusNote:SetPoint("RIGHT", -4, 0)
    statusNote:SetJustifyH("LEFT")
    statusNote:SetText("These lines are spoken from the game. They are not printed.")
    statusNote:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local scroll = CreateFrame("ScrollFrame", nil, status)
    scroll:SetPoint("TOPLEFT", statusNote, "BOTTOMLEFT", 0, -8)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local list = CreateFrame("Frame", nil, scroll)
    list:SetHeight(#STATUS_ROWS * 44)
    scroll:SetScrollChild(list)
    local function LayoutStatus()
        local width = scroll:GetWidth()
        if not width or width < 40 then
            width = 460
        end
        list:SetWidth(width)
        local maxScroll = list:GetHeight() - scroll:GetHeight()
        if maxScroll < 0 then
            maxScroll = 0
        end
        if scroll:GetVerticalScroll() > maxScroll then
            scroll:SetVerticalScroll(maxScroll)
        end
    end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        LayoutStatus()
        local maxScroll = list:GetHeight() - self:GetHeight()
        if maxScroll < 0 then
            maxScroll = 0
        end
        local nextScroll = self:GetVerticalScroll() - (delta * 36)
        if nextScroll < 0 then
            nextScroll = 0
        end
        if nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
    end)
    scroll:SetScript("OnSizeChanged", LayoutStatus)
    local previous = nil
    for i = 1, #STATUS_ROWS do
        local row = MakeToggle(list, STATUS_ROWS[i].key, STATUS_ROWS[i].label, STATUS_ROWS[i].tip)
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -8)
        else
            row:SetPoint("TOPLEFT", 0, 0)
        end
        row:SetPoint("RIGHT", 0, 0)
        previous = row
    end

    local commands = CreateFrame("Frame", nil, content)
    commands:SetAllPoints(content)
    commands:Hide()
    pages.commands = commands
    local commandsTitle = commands:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    commandsTitle:SetPoint("TOPLEFT", 0, 0)
    commandsTitle:SetText("Commands")
    commandsTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local commandsNote = commands:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    commandsNote:SetPoint("TOPLEFT", commandsTitle, "BOTTOMLEFT", 0, -6)
    commandsNote:SetPoint("RIGHT", -4, 0)
    commandsNote:SetJustifyH("LEFT")
    commandsNote:SetText("Click a line to hear it. The read key speaks it too.")
    commandsNote:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local commandScroll = CreateFrame("ScrollFrame", nil, commands)
    commandScroll:SetPoint("TOPLEFT", commandsNote, "BOTTOMLEFT", 0, -8)
    commandScroll:SetPoint("BOTTOMRIGHT", 0, 0)
    local commandList = CreateFrame("Frame", nil, commandScroll)
    commandScroll:SetScrollChild(commandList)
    local commandLines = {
        { heading = "Slash commands" },
        { label = "/ah", tip = "Opens this window. /ahelp does the same. /ah commands opens this page." },
        { label = "/ahs", tip = "Speaks a test line." },
        { label = "/ahtt", tip = "Reads the TomTom arrow. /aharrow and /ahtomtom do the same." },
        { label = "/ahz", tip = "Reads the Zygor arrow. /ahzygor does the same." },
        { label = "/ahstop", tip = "Stops the speech that is playing." },
        { label = "/ahrepeat", tip = "Repeats the last spoken line. /ahr does the same." },
        { label = "/ahclear", tip = "Clears the speech that is waiting." },
        { heading = "Key bindings" },
        { label = "Read hovered tooltip", bind = "ACCESSIBILITYHELPER_READTOOLTIP", tip = "Speaks the tooltip under the mouse. Press again to stop." },
        { label = "Read text under mouse", bind = "ACCESSIBILITYHELPER_READUNDERMOUSE", tip = "The key exists. Text under the mouse is not read on this version yet." },
        { label = "Read TomTom arrow", bind = "CLICK AccessibilityHelperTomTomReadBindProxy:LeftButton", tip = "Reads the TomTom arrow that is showing." },
        { label = "Read Zygor arrow", bind = "CLICK AccessibilityHelperZygorReadBindProxy:LeftButton", tip = "Reads the Zygor arrow that is showing." },
        { label = "Open this window", bind = "ACCESSIBILITYHELPER_OPENSETTINGS", tip = "Opens or closes this window." },
        { label = "Read target distance", bind = "ACCESSIBILITYHELPER_TARGETDISTANCE", tip = "The key exists. Target distance is not read on this version yet." },
        { label = "Read target", bind = "ACCESSIBILITYHELPER_READTARGET", tip = "The key exists. The target reader is not on this version yet." },
        { label = "Stop speaking", bind = "ACCESSIBILITYHELPER_STOPSPEAK", tip = "Stops the speech that is playing." },
        { label = "Repeat last line", bind = "ACCESSIBILITYHELPER_REPEATLAST", tip = "Repeats the last spoken line." },
        { label = "Read quest objectives", bind = "ACCESSIBILITYHELPER_READQUESTOBJECTIVES", tip = "The key exists. This key is not reading objectives on this version yet. Quest details on the Chat page reads an open quest." },
        { label = "Read quest window", bind = "ACCESSIBILITYHELPER_READQUESTWINDOW", tip = "The key exists. This key is not reading the quest window on this version yet. Quest details on the Chat page reads an open quest." },
    }
    commandList:SetHeight(#commandLines * 40)
    local commandKeys = {}
    local function BoundKey(bind)
        if not GetBindingKey then
            return "Not bound"
        end
        local key = GetBindingKey(bind)
        if type(key) ~= "string" or key == "" then
            return "Not bound"
        end
        return PrettyKey(key)
    end
    local function LayoutCommands()
        local width = commandScroll:GetWidth()
        if not width or width < 40 then
            width = 460
        end
        commandList:SetWidth(width)
        local maxScroll = commandList:GetHeight() - commandScroll:GetHeight()
        if maxScroll < 0 then
            maxScroll = 0
        end
        if commandScroll:GetVerticalScroll() > maxScroll then
            commandScroll:SetVerticalScroll(maxScroll)
        end
    end
    commandScroll:EnableMouseWheel(true)
    commandScroll:SetScript("OnMouseWheel", function(self, delta)
        LayoutCommands()
        local maxScroll = commandList:GetHeight() - self:GetHeight()
        if maxScroll < 0 then
            maxScroll = 0
        end
        local nextScroll = self:GetVerticalScroll() - (delta * 36)
        if nextScroll < 0 then
            nextScroll = 0
        end
        if nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
    end)
    commandScroll:SetScript("OnSizeChanged", LayoutCommands)
    local previousCommand = nil
    local lineIndex
    for lineIndex = 1, #commandLines do
        local info = commandLines[lineIndex]
        local row = CreateFrame("Frame", nil, commandList, Template())
        row:SetHeight(36)
        if info.heading then
            local heading = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            heading:SetPoint("LEFT", 4, 0)
            heading:SetText(info.heading)
            heading:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        else
            Paint(row, { 0.12, 0.10, 0.08, 1 }, EDGE)
            local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            name:SetPoint("LEFT", 10, 0)
            name:SetText(info.label)
            name:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
            if info.bind then
                local keyName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                keyName:SetPoint("RIGHT", -10, 0)
                keyName:SetWidth(190)
                keyName:SetJustifyH("RIGHT")
                keyName:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
                commandKeys[#commandKeys + 1] = { text = keyName, bind = info.bind, tip = info.tip, label = info.label }
                AttachTip(row, info.label, info.tip)
            else
                AttachTip(row, info.label, info.tip)
            end
            row:SetScript("OnMouseDown", function()
                local line = info.tip
                if info.bind then
                    line = info.label .. ". " .. BoundKey(info.bind) .. ". " .. info.tip
                end
                Speak(line)
            end)
        end
        if previousCommand then
            row:SetPoint("TOPLEFT", previousCommand, "BOTTOMLEFT", 0, -4)
        else
            row:SetPoint("TOPLEFT", 0, 0)
        end
        row:SetPoint("RIGHT", 0, 0)
        previousCommand = row
    end
    function commands.Refresh()
        local i
        for i = 1, #commandKeys do
            local entry = commandKeys[i]
            entry.text:SetText(BoundKey(entry.bind))
        end
        LayoutCommands()
    end

    local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    footer:SetPoint("BOTTOMLEFT", 12, 8)
    footer:SetText("v3.7.7")
    footer:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            capturing = false
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(false)
            end
            self:Hide()
            return
        end
        if not capturing then
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(true)
            end
            return
        end
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(false)
        end
        local chord = Chord(key)
        if chord then
            BindReadKey(chord)
        end
    end)
    frame:SetScript("OnShow", function()
        Refresh()
        ShowPage(currentPage or "tooltip")
    end)
    frame:SetScript("OnHide", function(self)
        capturing = false
        if captureCover then
            captureCover:Hide()
        end
        if self.EnableKeyboard then
            self:EnableKeyboard(false)
        end
        HideTip()
    end)

    return frame
end

function Window.Toggle()
    local f = Build()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

function Window.Open()
    local f = Build()
    if not f:IsShown() then
        f:Show()
    end
end

function Window.ShowCommands()
    local f = Build()
    currentPage = "commands"
    if f:IsShown() then
        ShowPage("commands")
    else
        f:Show()
    end
end

function Window.Close()
    if frame and frame:IsShown() then
        frame:Hide()
    end
end

AH.Settings = AH.Settings or {}
function AH.Settings.Toggle()
    Window.Toggle()
end
function AH.Settings.Open()
    Window.Open()
end
function AH.Settings.Close()
    Window.Close()
end
