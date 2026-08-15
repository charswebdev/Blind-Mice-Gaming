--[[
  Accessibility Helper — read chat messages printed by specific addons
  Hooks ChatFrame AddMessage; matches known addon prefixes / labels.
  Gated by chatReadEnabled + per-addon toggles (all default off).
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.AddonChat = AH.AddonChat or {}
local AddonChat = AH.AddonChat

--[[
  patterns: lowercase needles matched against stripped chat text.
  folders: required — at least one listed addon must be loaded to match.
]]
AddonChat.SOURCES = {
    {
        key = "chatAddonZygor",
        label = "Zygor",
        example = "Zygor Guides: Turn in the quest.",
        patterns = { "zygor guides", "zygorguidesviewer", "zygor:", "zygor " },
        folders = { "ZygorGuidesViewer", "ZygorGuidesViewerClassic", "ZygorTalentAdvisor" },
    },
    {
        key = "chatAddonMountSpy",
        label = "MountSpy",
        example = "MountSpy: Bob is on Invincible.",
        patterns = { "mountspy", "mount spy" },
        folders = { "MountSpy" },
    },
    {
        key = "chatAddonQuestCompletist",
        label = "QuestCompletist",
        example = "QuestCompletist: Quest completed.",
        patterns = { "questcompletist", "quest completist" },
        folders = { "QuestCompletist", "QuestCompletistClassic" },
    },
    {
        key = "chatAddonRareScanner",
        label = "Rare Scanner",
        example = "RareScanner: Rare found nearby.",
        patterns = { "rarescanner", "rare scanner" },
        folders = { "RareScanner" },
    },
    {
        key = "chatAddonSilverDragon",
        label = "SilverDragon",
        example = "SilverDragon: Rare seen: ...",
        patterns = { "silverdragon", "silver dragon", "rare seen:" },
        folders = { "SilverDragon" },
    },
    {
        key = "chatAddonLoremaster",
        label = "HandyNotes: Loremaster (Fork)",
        example = "Loremaster: Quest area discovered.",
        patterns = { "loremaster", "handynotes_loremaster", "handynotes: loremaster", "hn%-loremaster" },
        folders = {
            "HandyNotes_Loremaster",
            "HandyNotes_LoremasterFork",
            "HandyNotes_Loremaster_Fork",
        },
    },
    {
        key = "chatAddonZugzug",
        label = "Zugzug",
        example = "Zugzug: Ready check reminder.",
        patterns = { "zugzug", "zug zug" },
        folders = { "Zugzug", "ZugZug" },
    },
}

local lastLine, lastAt = nil, 0
local DEDUPE_SEC = 0.45
local readyAt = 0
local hooked = {}

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function MasterOn()
    return DB().chatReadEnabled == true
end

local function SourceOn(key)
    return DB()[key] == true
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

local function AddonLoaded(name)
    if not name then
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

local function AnyFolderLoaded(folders)
    if type(folders) ~= "table" or #folders == 0 then
        return false
    end
    for i = 1, #folders do
        if AddonLoaded(folders[i]) then
            return true
        end
    end
    return false
end

local function MatchSource(src, lower)
    if type(lower) ~= "string" or lower == "" then
        return false
    end
    local patterns = src.patterns
    if type(patterns) ~= "table" then
        return false
    end
    -- Require the addon to be loaded so ambiguous prefixes do not false-trigger.
    if not AnyFolderLoaded(src.folders) then
        return false
    end
    for i = 1, #patterns do
        local p = patterns[i]
        if type(p) == "string" and p ~= "" and lower:find(p, 1, true) then
            return true
        end
    end
    return false
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

local function HandleAddonMessage(text)
    if not MasterOn() then
        return
    end
    local now = GetTime and GetTime() or 0
    if now < readyAt then
        return
    end
    if type(text) ~= "string" or text == "" then
        return
    end
    -- Skip our own echo / branding lines.
    if text:find("%[Helper%]", 1, true) or text:find("Accessibility Helper", 1, true) then
        return
    end

    local spoken = ForSpeech(text)
    if spoken == "" then
        return
    end
    local lower = spoken:lower()

    for i = 1, #AddonChat.SOURCES do
        local src = AddonChat.SOURCES[i]
        if SourceOn(src.key) and MatchSource(src, lower) then
            -- Shared with ChatChannels so the same line is not spoken twice.
            if Dedupe(spoken) then
                return
            end
            Say(spoken)
            return
        end
    end
end

local function HookChatFrame(frame)
    if not frame or hooked[frame] then
        return
    end
    if type(frame.AddMessage) ~= "function" then
        return
    end
    hooked[frame] = true
    hooksecurefunc(frame, "AddMessage", function(self, msg)
        -- Only the primary chat frame to avoid speaking the same line twice.
        if self ~= DEFAULT_CHAT_FRAME and (not ChatFrame1 or self ~= ChatFrame1) then
            return
        end
        if DEFAULT_CHAT_FRAME and ChatFrame1 and DEFAULT_CHAT_FRAME ~= ChatFrame1 then
            if self ~= ChatFrame1 then
                return
            end
        end
        HandleAddonMessage(msg)
    end)
end

local function HookAll()
    HookChatFrame(DEFAULT_CHAT_FRAME)
    HookChatFrame(ChatFrame1)
    if NUM_CHAT_WINDOWS and type(NUM_CHAT_WINDOWS) == "number" then
        -- Intentionally only primary frame; other windows would duplicate.
    end
end

function AddonChat.SettingsRows()
    local out = {
        { type = "header", label = "Addons" },
        {
            type = "hint",
            label = "Reads chat lines these addons print. Requires Read chat channels (master).",
        },
    }
    for i = 1, #AddonChat.SOURCES do
        local src = AddonChat.SOURCES[i]
        out[#out + 1] = {
            type = "check",
            key = src.key,
            label = src.label,
            example = src.example,
        }
    end
    return out
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    readyAt = (GetTime and GetTime() or 0) + 2
    HookAll()
end)
