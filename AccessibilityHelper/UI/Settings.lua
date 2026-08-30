--[[
  Accessibility Helper — settings
  AllQuest-style two-pane layout: category tree on the left, one spacious
  row per option on the right. Hover shows a GameTooltip and speaks the hint.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Settings = AH.Settings or {}
local Settings = AH.Settings

local FRAME_NAME = "AccessibilityHelperSettingsFrame"
local ICON_PATH = "Interface\\AddOns\\AccessibilityHelper\\Media\\Icon.png"

local COL_BG = { 0.02, 0.02, 0.02, 1 }
local COL_BORDER = { 0.85, 0.85, 0.85, 1 }
local COL_GOLD = { 1, 0.92, 0.4, 1 }
local COL_LABEL = { 1, 1, 1, 1 }
local COL_HINT = { 0.72, 0.72, 0.72, 1 }
local COL_MUTED = { 0.55, 0.55, 0.55, 1 }
local COL_HOVER = { 1, 0.92, 0.4, 0.08 }
local COL_ROW = { 0.07, 0.07, 0.07, 1 }
local COL_BTN = { 0.08, 0.08, 0.08, 1 }
local COL_BTN_HOVER = { 0.22, 0.22, 0.1, 1 }
local COL_RULE = { 1, 0.92, 0.4, 0.28 }

local ROW_H = 64
local NAV_PARENT_H = 26
local NAV_CHILD_H = 34
local NAV_GAP = 2

local frame
local built = false
local selectedId = "commands"
local lastHoverText
local lastHoverAt = 0

local COMMAND_ROWS = {
    { "/ah, /ahelp", "Open this settings window." },
    { "/ahcmds", "Print the command list to chat." },
    { "/ahs", "Speak a test line with the current voice and speed." },
    { "/ahstop", "Stop speech immediately." },
    { "/ahclear, /ahflush", "Clear queued announcements without stopping the current line." },
    { "/ahrepeat, /ahr", "Repeat the last spoken line." },
    { "/ahreadtip, /ahtip", "Read the tooltip under the mouse, including Titan Panel." },
    { "/ahread", "Read whatever is under the mouse: labels, tooltips, buttons, or units." },
    { "/ahtt, /aharrow, /ahtomtom", "Read the TomTom arrow." },
    { "/ahz, /ahzygor", "Read the Zygor arrow." },
    { "/aha", "Toggle TomTom / Zygor facing announcements." },
    { "/ahtarget, /ahrt", "Read the current target." },
    { "/ahtf", "Toggle target facing announcements." },
    { "/ahdist, /ahdistance", "Read the distance to your target." },
    { "/ahquest, /ahqo", "Read tracked quest objectives." },
    { "/ahqw", "Read the open NPC quest or the selected log quest." },
}

-- Left-hand category tree. header = group label only. parent = indented page.
-- Names describe what the page does, for screen-reader / TTS navigation.
local NAV = {
    { id = "commands", label = "Commands", hint = "Slash commands and keybinds." },
    { id = "general_app", label = "App", hint = "Master switch, chat echo, and the minimap button." },
    { id = "general_tts", label = "Speech", hint = "Volume, speed, and voice for addon speech." },
    { id = "chat", label = "Chat", header = true, hint = "Which chat channels to read. Profession crafting and gathering lines are under Crafting, not Combat." },
    { id = "chat_master", label = "Turn reading on", parent = "chat", hint = "Master switch. Turn this on before enabling channels." },
    { id = "chat_zone", label = "Town and trade", parent = "chat", hint = "General, Trade, Services, and other zone channels." },
    { id = "chat_nearby", label = "Nearby talk", parent = "chat", hint = "Say, yell, emotes, and voice-chat text." },
    { id = "chat_groups", label = "Groups", parent = "chat", hint = "Party, raid, instance, guild, and communities." },
    { id = "chat_whispers", label = "Whispers", parent = "chat", hint = "Whispers, Battle.net whispers, AFK, and DND." },
    { id = "chat_creature", label = "Creatures", parent = "chat", hint = "NPC, boss, and encounter lines." },
    { id = "chat_crafting", label = "Crafting", parent = "chat", hint = "Profession crafting and gathering chat lines. Not a combat setting." },
    { id = "chat_pets", label = "Pets", parent = "chat", hint = "Hunter pet info and pet battles." },
    { id = "chat_pvp", label = "Battlegrounds", parent = "chat", hint = "Battleground system messages." },
    { id = "chat_other", label = "System", parent = "chat", hint = "System messages, pings, and other leftover chat." },
    { id = "chat_addons", label = "Addons", parent = "chat", hint = "Lines printed by supported addons." },
    { id = "reading", label = "Reading", header = true, hint = "Tooltips, text under the mouse, arrows, distance, location, and red error text." },
    { id = "reading_tooltips", label = "Tooltips", parent = "reading", hint = "Read game tooltips with /ahtip or the tooltip keybind." },
    { id = "reading_undermouse", label = "UI text", parent = "reading", hint = "Keybind or hover: reads labels, tooltips, buttons, and units under the cursor. Also announces mount, loot, open, and collect cursors." },
    { id = "reading_waypoints", label = "Arrows", parent = "reading", hint = "TomTom, Zygor, and facing clocks." },
    { id = "reading_distance", label = "Distance", parent = "reading", hint = "Target distance reading." },
    { id = "reading_location", label = "Location", parent = "reading", hint = "Subzone change announcements." },
    { id = "reading_uierrors", label = "Errors", parent = "reading", hint = "Red error messages at the top of the screen." },
    { id = "player", label = "You", header = true, hint = "Announces about your character. These pages are on or off. Choose TTS or sound under Sounds." },
    { id = "player_movement", label = "Movement", parent = "player", hint = "Follow, mount, swim, taxi, and similar movement states." },
    { id = "player_vitals", label = "Health and death", parent = "player", hint = "Turn combat, death, health, breath, and fatigue announces on or off. Sound settings are under Sounds → Health and death." },
    { id = "player_world", label = "World", parent = "player", hint = "Resting, instances, bags, durability, and money." },
    { id = "player_identity", label = "Status", parent = "player", hint = "AFK, PvP, stealth, form, pet, and group." },
    { id = "player_social", label = "People", parent = "player", hint = "Level-up, quests, target, and Battle.net friends." },
    { id = "rewards", label = "Rewards", header = true, hint = "Quests, loot, profession skill, experience, and reputation." },
    { id = "rewards_quests", label = "Quests", parent = "rewards", hint = "Quest objectives, windows, and progress." },
    { id = "rewards_loot", label = "Loot", parent = "rewards", hint = "Looted items, currencies, and honor." },
    { id = "rewards_progress", label = "Skills and reputation", parent = "rewards", hint = "Profession skill, experience, and reputation." },
    { id = "combat", label = "Combat", header = true, hint = "Fighting alerts only: casts, interrupt, loss of control, debuffs, and buffs. These pages are on or off. Choose TTS or sound under Sounds." },
    { id = "combat_duration", label = "Casts", parent = "combat", hint = "Turn cast and channel bar announces on or off. Sound settings are under Sounds → Casts." },
    { id = "combat_interrupt", label = "Interrupt", parent = "combat", hint = "Turn the interrupt-ready cue on or off. Sound settings are under Sounds → Interrupt." },
    { id = "combat_loc", label = "Loss of control", parent = "combat", hint = "Turn stun, root, silence, and similar announces on or off. Sound settings are under Sounds → Loss of control." },
    { id = "combat_debuffs", label = "Debuffs", parent = "combat", hint = "Turn poison, disease, curse, and magic announces on or off. Sound settings are under Sounds → Debuffs." },
    { id = "combat_buffs", label = "Buffs", parent = "combat", hint = "Turn combat buff apply, fade, and stack announces on or off. Sound settings are under Sounds → Buffs." },
    { id = "sounds", label = "Sounds", header = true, hint = "How alerts play: TTS, a sound, or both. Turn each alert on under You or Combat first." },
    { id = "sounds_default", label = "Default sound", parent = "sounds", hint = "Fallback sound for alerts that still say Use default sound." },
    { id = "sounds_vitals", label = "Health and death", parent = "sounds", hint = "TTS or sound for combat, death, health, breath, and fatigue. Turn those announces on under You → Health and death." },
    { id = "sounds_casts", label = "Casts", parent = "sounds", hint = "TTS or sound for cast and channel bars. Turn those announces on under Combat → Casts." },
    { id = "sounds_interrupt", label = "Interrupt", parent = "sounds", hint = "TTS or sound when you can interrupt an enemy. Turn that cue on under Combat → Interrupt." },
    { id = "sounds_loc", label = "Loss of control", parent = "sounds", hint = "TTS or sound for stun, root, silence, and similar. Turn those announces on under Combat → Loss of control." },
    { id = "sounds_debuffs", label = "Debuffs", parent = "sounds", hint = "TTS or sound for poison, disease, curse, and magic. Turn those announces on under Combat → Debuffs." },
    { id = "sounds_buffs", label = "Buffs", parent = "sounds", hint = "TTS or sound when combat buffs apply, fade, or stack. Turn those announces on under Combat → Buffs." },
}

local CHAT_SECTION = {
    chat_zone = "Town and trade",
    chat_nearby = "Nearby talk",
    chat_groups = "Groups",
    chat_whispers = "Whispers",
    chat_creature = "Creatures",
    chat_crafting = "Crafting",
    chat_pets = "Pets",
    chat_pvp = "Battlegrounds",
    chat_other = "System",
    chat_addons = "Addons",
}

local function FontString(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local ok = fs:SetFont("Fonts\\FRIZQT__.TTF", size or 14, "OUTLINE")
    if not ok then
        fs:SetFontObject(GameFontHighlight)
    end
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    fs:SetJustifyH("LEFT")
    return fs
end

local function Template()
    return BackdropTemplateMixin and "BackdropTemplate" or nil
end

local function ApplyBackdrop(f)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        f:SetBackdropColor(COL_BG[1], COL_BG[2], COL_BG[3], COL_BG[4])
        f:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], COL_BORDER[4])
        return
    end
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(COL_BG[1], COL_BG[2], COL_BG[3], 1)
end

local function Paint(f, r, g, b, a, br, bg, bb)
    a = a or 1
    if not f._ahPainted then
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
        else
            local tex = f:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints()
            f._ahTex = tex
        end
        f._ahPainted = true
    end
    if f.SetBackdropColor then
        f:SetBackdropColor(r, g, b, a)
        f:SetBackdropBorderColor(br or 0.4, bg or 0.4, bb or 0.4, 1)
    elseif f._ahTex then
        f._ahTex:SetColorTexture(r, g, b, a)
    end
end

local function HideTooltip()
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function ShowTip(owner, title, desc)
    if not GameTooltip or not owner then
        return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(title or "", COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
    if type(desc) == "string" and desc ~= "" then
        GameTooltip:AddLine(desc, 0.9, 0.9, 0.9, true)
    end
    GameTooltip:Show()
end

local function SpeakNow(text)
    if type(text) == "function" then
        text = text()
    end
    if type(text) ~= "string" or text == "" then
        return
    end
    local now = GetTime and GetTime() or 0
    if text == lastHoverText and (now - lastHoverAt) < 0.35 then
        return
    end
    lastHoverText = text
    lastHoverAt = now
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(text, AH.Speech.PRIORITY_LOW)
    end
end

-- Spoken when the mouse enters a settings row. Only if Reading → UI text is As I hover.
local function HoverSpeak(text)
    local mode = AH.DB and AH.DB.GetUnderMouseMode and AH.DB.GetUnderMouseMode()
    if mode ~= "hover" then
        return
    end
    SpeakNow(text)
end

local function BindHover(widget, title, desc, speakFn)
    widget:EnableMouse(true)
    widget:SetScript("OnEnter", function(self)
        if self.Hover then
            self.Hover:Show()
        end
        ShowTip(self, title, desc)
        HoverSpeak(speakFn or ((title or "") .. ". " .. (desc or "")))
    end)
    widget:SetScript("OnLeave", function(self)
        if self.Hover then
            self.Hover:Hide()
        end
        HideTooltip()
    end)
end

local function AddHoverWash(row)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(COL_HOVER[1], COL_HOVER[2], COL_HOVER[3], COL_HOVER[4])
    bg:Hide()
    row.Hover = bg
end

local function IsOptInKey(dbKey)
    return dbKey == "chatEcho"
        or dbKey == "chatReadEnabled"
        or dbKey == "questObjectiveProgressEnabled"
        or (type(dbKey) == "string" and dbKey:match("^chat") and dbKey ~= "chatEcho")
end

local function KeyOn(dbKey)
    local sv = AH.DB.Get()
    if IsOptInKey(dbKey) then
        return sv[dbKey] == true
    end
    return sv[dbKey] ~= false
end

local function SetKey(dbKey, on)
    local sv = AH.DB.Get()
    sv[dbKey] = on and true or false
    if dbKey == "minimapButtonEnabled" and AH.MinimapButton and AH.MinimapButton.Refresh then
        AH.MinimapButton.Refresh()
    end
end

local function Truncate(text, maxLen)
    maxLen = maxLen or 28
    if type(text) ~= "string" then
        return ""
    end
    if #text > maxLen then
        return text:sub(1, maxLen - 1) .. "…"
    end
    return text
end

local function StyleButton(btn, fontSize)
    Paint(btn, COL_BTN[1], COL_BTN[2], COL_BTN[3], 1, 1, 1, 1)
    local fs = btn:GetFontString()
    if not fs then
        fs = btn:CreateFontString(nil, "OVERLAY")
        btn:SetFontString(fs)
    end
    local ok = fs:SetFont("Fonts\\FRIZQT__.TTF", fontSize or 13, "OUTLINE")
    if not ok then
        fs:SetFontObject(GameFontHighlight)
    end
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetShadowOffset(0, 0)
    fs:SetJustifyH("CENTER")
    fs:SetPoint("CENTER")
    btn:SetScript("OnEnter", function(self)
        Paint(self, COL_BTN_HOVER[1], COL_BTN_HOVER[2], COL_BTN_HOVER[3], 1, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
        fs:SetTextColor(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 1)
        if self._ahTipTitle then
            ShowTip(self, self._ahTipTitle, self._ahTipDesc)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        Paint(self, COL_BTN[1], COL_BTN[2], COL_BTN[3], 1, 1, 1, 1)
        fs:SetTextColor(1, 1, 1, 1)
        HideTooltip()
    end)
end

local function DarkButton(parent, text, w, h)
    local btn = CreateFrame("Button", nil, parent, Template())
    btn:SetSize(w or 28, h or 28)
    btn:RegisterForClicks("LeftButtonUp")
    btn:EnableMouse(true)
    StyleButton(btn)
    btn:SetText(text or "")
    return btn
end

local function SpeakerButton(parent, anchor, onClick, title, desc)
    local btn = CreateFrame("Button", nil, parent, Template())
    btn:SetSize(32, 32)
    btn:SetPoint("LEFT", anchor, "RIGHT", 8, 0)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    Paint(btn, COL_BTN[1], COL_BTN[2], COL_BTN[3], 1, 1, 1, 1)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Common\\VoiceChat-Speaker")
    btn:SetScript("OnClick", function()
        local skipSpeak
        if onClick then
            skipSpeak = onClick()
        end
        if not skipSpeak then
            SpeakNow(title or "Preview")
        end
    end)
    btn:SetScript("OnEnter", function(self)
        Paint(self, COL_BTN_HOVER[1], COL_BTN_HOVER[2], COL_BTN_HOVER[3], 1, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
        ShowTip(self, title or "Preview", desc or "Play a sample of this setting.")
        HoverSpeak((title or "Preview") .. ". " .. (desc or "Play a sample of this setting."))
    end)
    btn:SetScript("OnLeave", function(self)
        Paint(self, COL_BTN[1], COL_BTN[2], COL_BTN[3], 1, 1, 1, 1)
        HideTooltip()
    end)
    return btn
end

local choiceMenu

local function HideChoiceMenu()
    if choiceMenu then
        choiceMenu:Hide()
    end
end

local function ShowChoiceMenu(owner, choices, onPick)
    if choiceMenu and choiceMenu:IsShown() and choiceMenu._owner == owner then
        HideChoiceMenu()
        return
    end
    if not choiceMenu then
        choiceMenu = CreateFrame("Frame", "AccessibilityHelperChoiceMenu", UIParent, Template())
        choiceMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        choiceMenu:SetClampedToScreen(true)
        choiceMenu:EnableMouse(true)
        ApplyBackdrop(choiceMenu)
        choiceMenu:SetScript("OnHide", function()
            choiceMenu._owner = nil
        end)
    end
    if choiceMenu.rows then
        for i = 1, #choiceMenu.rows do
            choiceMenu.rows[i]:Hide()
            choiceMenu.rows[i]:SetParent(nil)
        end
    end
    choiceMenu.rows = {}

    local rowH = 30
    local width = 340
    local maxVis = 16
    local useScroll = #choices > maxVis
    choiceMenu:SetSize(width, 10 + math.min(#choices, maxVis) * rowH)
    choiceMenu:ClearAllPoints()
    choiceMenu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 8, -4)
    choiceMenu:SetParent(UIParent)
    choiceMenu._owner = owner
    choiceMenu:EnableMouseWheel(true)
    choiceMenu:SetScript("OnMouseWheel", function(_, delta)
        if not choiceMenu._scroll then
            return
        end
        local cur = choiceMenu._scroll:GetVerticalScroll() or 0
        local max = choiceMenu._scroll:GetVerticalScrollRange() or 0
        local next = cur - (delta * 36)
        if next < 0 then
            next = 0
        elseif next > max then
            next = max
        end
        choiceMenu._scroll:SetVerticalScroll(next)
    end)

    local listParent = choiceMenu
    local scroll
    choiceMenu._scroll = nil
    if useScroll then
        scroll = CreateFrame("ScrollFrame", nil, choiceMenu, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 6, -6)
        scroll:SetPoint("BOTTOMRIGHT", -28, 6)
        scroll:EnableMouseWheel(true)
        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(width - 36, #choices * rowH)
        scroll:SetScrollChild(child)
        listParent = child
        choiceMenu._scroll = scroll
    end

    for i = 1, #choices do
        local choice = choices[i]
        local row = CreateFrame("Button", nil, listParent, Template())
        row:SetSize(useScroll and (width - 36) or (width - 12), rowH - 2)
        row:SetPoint("TOPLEFT", listParent, "TOPLEFT", useScroll and 0 or 6, -((i - 1) * rowH) - (useScroll and 0 or 6))
        Paint(row, 0.06, 0.06, 0.06, 1, 0.45, 0.45, 0.45)
        local fs = FontString(row, 13, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3])
        fs:SetPoint("LEFT", 10, 0)
        fs:SetWidth(width - 28)
        fs:SetText(choice.name)
        row:SetScript("OnEnter", function(self)
            Paint(self, COL_BTN_HOVER[1], COL_BTN_HOVER[2], COL_BTN_HOVER[3], 1, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
            fs:SetTextColor(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 1)
            ShowTip(self, choice.name, choice.hint)
            HoverSpeak(choice.name .. (choice.hint and (". " .. choice.hint) or ""))
        end)
        row:SetScript("OnLeave", function(self)
            Paint(self, 0.06, 0.06, 0.06, 1, 0.45, 0.45, 0.45)
            fs:SetTextColor(1, 1, 1, 1)
            HideTooltip()
        end)
        row:SetScript("OnClick", function()
            HideChoiceMenu()
            if onPick then
                onPick(choice)
            end
        end)
        choiceMenu.rows[#choiceMenu.rows + 1] = row
    end
    choiceMenu:Show()
end

local function CollectChatOptions(sectionHeader)
    local rows = AH.ChatChannels and AH.ChatChannels.SettingsRows and AH.ChatChannels.SettingsRows() or {}
    local addonRows = AH.AddonChat and AH.AddonChat.SettingsRows and AH.AddonChat.SettingsRows() or {}
    for i = 1, #addonRows do
        rows[#rows + 1] = addonRows[i]
    end
    local out = {}
    local take = false
    for i = 1, #rows do
        local row = rows[i]
        if row.type == "header" then
            take = (row.label == sectionHeader)
        elseif take and row.type == "check" then
            out[#out + 1] = row
        end
    end
    return out
end

local function MakeRowShell(parent, title, hint)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    AddHoverWash(row)
    BindHover(row, title, hint)

    local name = FontString(row, 15, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3])
    name:SetPoint("TOPLEFT", 18, -12)
    name:SetPoint("RIGHT", -240, 0)
    name:SetText(title)
    row.TitleFS = name

    local hintFS = FontString(row, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3])
    hintFS:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    hintFS:SetPoint("RIGHT", -240, 0)
    hintFS:SetWordWrap(true)
    if hintFS.SetMaxLines then
        hintFS:SetMaxLines(2)
    end
    hintFS:SetText(hint or "")
    row.HintFS = hintFS
    return row
end

local function MakeCheckRow(parent, title, dbKey, hint, rows)
    hint = hint or "Turns this option on or off."
    local row = MakeRowShell(parent, title, hint)
    local box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    box:SetSize(32, 32)
    box:SetPoint("RIGHT", -20, 0)

    local function Refresh()
        box:SetChecked(KeyOn(dbKey))
    end

    box:SetScript("OnClick", function(self)
        SetKey(dbKey, self:GetChecked() and true or false)
        Refresh()
        local state = KeyOn(dbKey) and "on" or "off"
        SpeakNow(title .. " " .. state .. ".")
    end)
    box:SetScript("OnEnter", function(self)
        ShowTip(self, title, hint)
        HoverSpeak(title .. ". " .. (KeyOn(dbKey) and "on" or "off") .. ". " .. hint)
    end)
    box:SetScript("OnLeave", HideTooltip)

    BindHover(row, title, hint, function()
        return title .. ". " .. (KeyOn(dbKey) and "on" or "off") .. ". " .. hint
    end)
    row:SetScript("OnClick", function()
        SetKey(dbKey, not KeyOn(dbKey))
        Refresh()
        SpeakNow(title .. " " .. (KeyOn(dbKey) and "on" or "off") .. ".")
    end)
    row.Refresh = Refresh
    Refresh()
    rows[#rows + 1] = row
    return row
end

local function MakeStepperRow(parent, title, dbKey, minV, maxV, step, formatFn, hint, previewFn, rows)
    hint = hint or "Adjust this value."
    local row = MakeRowShell(parent, title, hint)
    row.HintFS:SetPoint("RIGHT", -280, 0)
    row.TitleFS:SetPoint("RIGHT", -280, 0)

    local plus = DarkButton(row, "+", 32, 32)
    plus:SetPoint("RIGHT", -20, 0)
    plus._ahTipTitle = "Increase " .. title
    plus._ahTipDesc = hint

    local valueFS = FontString(row, 16, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
    valueFS:SetWidth(72)
    valueFS:SetJustifyH("CENTER")
    valueFS:SetPoint("RIGHT", plus, "LEFT", -8, 0)

    local minus = DarkButton(row, "-", 32, 32)
    minus:SetPoint("RIGHT", valueFS, "LEFT", -8, 0)
    minus._ahTipTitle = "Decrease " .. title
    minus._ahTipDesc = hint

    if previewFn then
        plus:SetPoint("RIGHT", -60, 0)
        SpeakerButton(row, plus, previewFn, "Preview " .. title, "Play a sample at this setting.")
    end

    local function current()
        local sv = AH.DB.Get()
        local v = sv[dbKey]
        if type(v) ~= "number" then
            v = minV
        end
        return v
    end

    local function Refresh()
        valueFS:SetText(formatFn and formatFn(current()) or tostring(current()))
    end

    local function Nudge(dir)
        local v = current() + (dir * step)
        if v < minV then
            v = minV
        end
        if v > maxV then
            v = maxV
        end
        AH.DB.Get()[dbKey] = v
        Refresh()
        if previewFn and dbKey == "addonTtsRate" then
            previewFn()
        else
            SpeakNow(title .. " " .. (formatFn and formatFn(v) or tostring(v)) .. ".")
        end
    end

    minus:SetScript("OnClick", function()
        Nudge(-1)
    end)
    plus:SetScript("OnClick", function()
        Nudge(1)
    end)
    row.Refresh = Refresh
    Refresh()
    rows[#rows + 1] = row
    return row
end

local function MakeChoiceRow(parent, title, hint, getChoices, currentName, onPick, previewFn, rows)
    hint = hint or "Choose an option."
    local row = MakeRowShell(parent, title, hint)
    row.HintFS:SetPoint("RIGHT", previewFn and -300 or -260, 0)
    row.TitleFS:SetPoint("RIGHT", previewFn and -300 or -260, 0)

    local drop = DarkButton(row, Truncate(currentName() or ""), 220, 32)
    drop:SetPoint("RIGHT", previewFn and -60 or -20, 0)
    drop._ahTipTitle = title
    drop._ahTipDesc = hint

    local function Refresh()
        drop:SetText(Truncate(currentName() or ""))
    end

    drop:SetScript("OnClick", function(self)
        ShowChoiceMenu(self, getChoices() or {}, function(choice)
            onPick(choice)
            Refresh()
        end)
    end)
    if previewFn then
        SpeakerButton(row, drop, previewFn, "Preview " .. title, "Play a sample of the current choice.")
    end
    row.Refresh = Refresh
    Refresh()
    rows[#rows + 1] = row
    return row
end

local function MakeAlertItemRow(parent, title, enableKey, category, hint, rows, soundOnly)
    hint = hint or "Choose how this alert is delivered, and which sound to play."
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(96)
    AddHoverWash(row)
    BindHover(row, title, hint, function()
        local mode = AH.Alerts and AH.Alerts.GetItemMode and AH.Alerts.GetItemMode(enableKey, category) or "tts"
        local modeName = AH.Alerts and AH.Alerts.ModeName and AH.Alerts.ModeName(mode) or mode
        local soundId = ""
        if AH.Alerts and AH.Alerts.HasCustomSound and AH.Alerts.HasCustomSound(enableKey) then
            soundId = AH.Alerts.GetItemSound(enableKey)
        end
        local soundName = AH.Sounds and AH.Sounds.ChoiceName and AH.Sounds.ChoiceName(soundId) or "Use default sound"
        if soundOnly then
            return title .. ". " .. modeName .. ". " .. soundName .. ". " .. hint
        end
        return title .. ". " .. (KeyOn(enableKey) and "on" or "off") .. ". " .. modeName .. ". " .. soundName .. ". " .. hint
    end)

    local box
    if not soundOnly then
        box = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        box:SetSize(32, 32)
        box:SetPoint("TOPLEFT", 14, -8)
    end

    local name = FontString(row, 15, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3])
    if box then
        name:SetPoint("LEFT", box, "RIGHT", 8, 0)
    else
        name:SetPoint("TOPLEFT", 18, -12)
    end
    name:SetPoint("RIGHT", -20, 0)
    name:SetText(title)

    local hintFS = FontString(row, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3])
    hintFS:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
    hintFS:SetPoint("RIGHT", -20, 0)
    hintFS:SetWordWrap(true)
    if hintFS.SetMaxLines then
        hintFS:SetMaxLines(2)
    end
    hintFS:SetText(hint)

    local speaker = SpeakerButton(row, row, function()
        if AH.Alerts and AH.Alerts.Preview then
            AH.Alerts.Preview(category, enableKey, title)
        end
        return true
    end, "Preview alert", "Hear this alert as it would play in game: TTS only, sound only, or both.")
    speaker:ClearAllPoints()
    speaker:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -16, 8)

    local soundDrop = DarkButton(row, "Use default sound", 170, 28)
    soundDrop:SetPoint("RIGHT", speaker, "LEFT", -8, 0)
    soundDrop._ahTipTitle = "Sound"
    soundDrop._ahTipDesc = "Every installed pack is listed. The default pack does not hide the others."

    local packDrop = DarkButton(row, "All packs", 130, 28)
    packDrop:SetPoint("RIGHT", soundDrop, "LEFT", -8, 0)
    packDrop._ahTipTitle = "Sound pack"
    packDrop._ahTipDesc = "Browse all packs, or one pack. This is not limited to the default Blizzard pack."

    local modeDrop = DarkButton(row, "TTS only", 120, 28)
    modeDrop:SetPoint("RIGHT", packDrop, "LEFT", -8, 0)
    modeDrop._ahTipTitle = "Alert type"
    modeDrop._ahTipDesc = "TTS only, sound only, or both for this item."

    row._browseSource = "all"

    local function BrowseLabel()
        local id = row._browseSource or "all"
        if id == "all" then
            return "All packs"
        end
        return (AH.Sounds and AH.Sounds.SourceName and AH.Sounds.SourceName(id)) or id
    end

    local function Refresh()
        if box then
            box:SetChecked(KeyOn(enableKey))
        end
        local mode = AH.Alerts and AH.Alerts.GetItemMode and AH.Alerts.GetItemMode(enableKey, category) or "tts"
        modeDrop:SetText(Truncate(AH.Alerts and AH.Alerts.ModeName and AH.Alerts.ModeName(mode) or mode, 14))
        packDrop:SetText(Truncate(BrowseLabel(), 16))
        local soundId = ""
        if AH.Alerts and AH.Alerts.HasCustomSound and AH.Alerts.HasCustomSound(enableKey) then
            soundId = AH.Alerts.GetItemSound(enableKey)
        end
        soundDrop:SetText(Truncate((AH.Sounds and AH.Sounds.ChoiceName and AH.Sounds.ChoiceName(soundId)) or "Use default sound", 20))
    end

    if box then
        box:SetScript("OnClick", function(self)
            SetKey(enableKey, self:GetChecked() and true or false)
            Refresh()
            SpeakNow(title .. " " .. (KeyOn(enableKey) and "on" or "off") .. ".")
        end)
        box:SetScript("OnEnter", function(self)
            ShowTip(self, title, hint)
            HoverSpeak(title .. ". " .. (KeyOn(enableKey) and "on" or "off") .. ". " .. hint)
        end)
        box:SetScript("OnLeave", HideTooltip)

        row:SetScript("OnClick", function()
            SetKey(enableKey, not KeyOn(enableKey))
            Refresh()
            SpeakNow(title .. " " .. (KeyOn(enableKey) and "on" or "off") .. ".")
        end)
    end

    modeDrop:SetScript("OnClick", function(self)
        ShowChoiceMenu(self, (AH.Alerts and AH.Alerts.ModeChoices and AH.Alerts.ModeChoices()) or {}, function(choice)
            if AH.Alerts and AH.Alerts.SetItemMode then
                AH.Alerts.SetItemMode(enableKey, choice.id)
            end
            Refresh()
            if AH.Alerts and AH.Alerts.Preview then
                AH.Alerts.Preview(category, enableKey, title)
            end
        end)
    end)

    packDrop:SetScript("OnClick", function(self)
        ShowChoiceMenu(self, (AH.Sounds and AH.Sounds.GetBrowseSources and AH.Sounds.GetBrowseSources()) or {}, function(choice)
            row._browseSource = choice.id or "all"
            Refresh()
            SpeakNow("Sound pack " .. choice.name .. ".")
        end)
    end)

    soundDrop:SetScript("OnClick", function(self)
        local source = row._browseSource or "all"
        ShowChoiceMenu(self, (AH.Sounds and AH.Sounds.GetChoiceList and AH.Sounds.GetChoiceList(source)) or {}, function(choice)
            if AH.Alerts and AH.Alerts.SetItemSound then
                AH.Alerts.SetItemSound(enableKey, choice.id)
            end
            Refresh()
            if AH.Alerts and AH.Alerts.PlaySound then
                AH.Alerts.PlaySound(enableKey)
            end
            SpeakNow(title .. " sound " .. choice.name .. ".")
        end)
    end)

    row.Refresh = Refresh
    Refresh()
    rows[#rows + 1] = row
    return row
end

local function MakeSection(parent, text, hint)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetHeight(36)
    AddHoverWash(wrap)
    BindHover(wrap, text, hint or ("Settings in the " .. text .. " group."))

    local fs = FontString(wrap, 16, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
    fs:SetPoint("LEFT", 18, 2)
    fs:SetText(text)

    local rule = wrap:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(COL_RULE[1], COL_RULE[2], COL_RULE[3], COL_RULE[4])
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 18, 4)
    rule:SetPoint("BOTTOMRIGHT", -18, 4)
    return wrap
end

local function MakeNote(parent, text)
    local wrap = CreateFrame("Frame", nil, parent)
    wrap:SetHeight(52)
    AddHoverWash(wrap)
    BindHover(wrap, "Note", text)
    local fs = FontString(wrap, 13, COL_HINT[1], COL_HINT[2], COL_HINT[3])
    fs:SetPoint("TOPLEFT", 18, -8)
    fs:SetPoint("TOPRIGHT", -18, -8)
    fs:SetWordWrap(true)
    if fs.SetMaxLines then
        fs:SetMaxLines(3)
    end
    fs:SetText(text)
    return wrap
end

local function MakeCommandRow(parent, cmd, desc)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(56)
    AddHoverWash(row)
    BindHover(row, cmd, desc)
    local name = FontString(row, 14, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
    name:SetPoint("TOPLEFT", 18, -10)
    name:SetText(cmd)
    local hintFS = FontString(row, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3])
    hintFS:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    hintFS:SetPoint("RIGHT", -18, 0)
    hintFS:SetText(desc)
    return row
end

local function VoiceChoices()
    local choices = { { voiceID = -1, name = "System default", hint = "Use the voice selected in WoW accessibility settings." } }
    local voices = (AH.Compat and AH.Compat.ListTtsVoices and AH.Compat.ListTtsVoices()) or {}
    for i = 1, #voices do
        choices[#choices + 1] = voices[i]
    end
    return choices
end

local function CurrentVoiceName()
    local saved = AH.DB and AH.DB.GetSavedTtsVoiceID and AH.DB.GetSavedTtsVoiceID()
    if saved == nil then
        local sysName = "System default"
        if AH.Compat and AH.Compat.GetSystemTtsVoiceID and AH.Compat.GetTtsVoiceName then
            local voiceName = AH.Compat.GetTtsVoiceName(AH.Compat.GetSystemTtsVoiceID())
            if voiceName and voiceName ~= "" then
                sysName = "Default: " .. tostring(voiceName)
            end
        end
        return sysName
    end
    if AH.Compat and AH.Compat.GetTtsVoiceName then
        return AH.Compat.GetTtsVoiceName(saved)
    end
    return "Voice " .. tostring(saved)
end

local function PreviewVoice()
    if not (AH.Speech and AH.Speech.PreviewSample) then
        return
    end
    local voiceID = AH.Compat and AH.Compat.GetTtsVoiceID and AH.Compat.GetTtsVoiceID() or 0
    local name = (AH.Compat and AH.Compat.GetTtsVoiceName and AH.Compat.GetTtsVoiceName(voiceID)) or "selected"
    local rate = AH.DB and AH.DB.GetTtsRate and AH.DB.GetTtsRate() or 0
    AH.Speech.PreviewSample("This is the " .. name .. " voice.", rate, voiceID)
end

local function PreviewRate()
    if not (AH.Speech and AH.Speech.PreviewSample) then
        return
    end
    local rate = AH.DB and AH.DB.GetTtsRate and AH.DB.GetTtsRate() or 0
    AH.Speech.PreviewSample("This is Accessibility Helper speaking at speed " .. tostring(rate) .. ".", rate, nil)
end

local SelectNav

local function RefreshRows()
    if not frame or not frame.rows then
        return
    end
    for i = 1, #frame.rows do
        if frame.rows[i].Refresh then
            frame.rows[i]:Refresh()
        end
    end
end

local function CurrentSoundID()
    return AH.DB and AH.DB.GetSoundPackID and AH.DB.GetSoundPackID() or "raidWarning"
end

local function CurrentSoundSource()
    if AH.Sounds and AH.Sounds.SourceOf then
        return AH.Sounds.SourceOf(CurrentSoundID())
    end
    return "blizzard"
end

local function CurrentSoundSourceName()
    if AH.Sounds and AH.Sounds.SourceOf then
        local _, name = AH.Sounds.SourceOf(CurrentSoundID())
        if name and name ~= "" then
            return name
        end
    end
    if AH.Sounds and AH.Sounds.SourceName then
        return AH.Sounds.SourceName(CurrentSoundSource())
    end
    return "Blizzard"
end

local function BuildPage(id, parent, rows)
    local y = -8
    local first = true

    local function Place(row)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
        y = y - ((row.GetHeight and row:GetHeight() or ROW_H) + 8)
    end

    local function Section(text, hint)
        if not first then
            y = y - 10
        end
        first = false
        Place(MakeSection(parent, text, hint))
    end

    local function Note(text)
        Place(MakeNote(parent, text))
    end

    local function Check(title, key, hint)
        Place(MakeCheckRow(parent, title, key, hint, rows))
    end

    local function AlertItem(title, key, category, hint, soundOnly)
        Place(MakeAlertItemRow(parent, title, key, category, hint, rows, soundOnly))
    end

    local function Step(title, key, minV, maxV, step, fmt, hint, previewFn)
        Place(MakeStepperRow(parent, title, key, minV, maxV, step, fmt, hint, previewFn, rows))
    end

    local function Choice(title, hint, getChoices, currentName, onPick, previewFn)
        Place(MakeChoiceRow(parent, title, hint, getChoices, currentName, onPick, previewFn, rows))
    end

    local function AlertType(dbKey, extra)
        Choice(
            "Alert type",
            extra or "How this group announces: TTS only, sound only, or both.",
            AlertChoices,
            function()
                return AlertName(dbKey)
            end,
            function(choice)
                SetAlert(dbKey, choice)
            end
        )
    end

    local function ChatChecks(sectionHeader)
        local opts = CollectChatOptions(sectionHeader)
        for i = 1, #opts do
            local row = opts[i]
            local hint = row.example and ("Example: " .. row.example) or "Read this chat channel when the master switch is on."
            Check(row.label, row.key, hint)
        end
    end

    if id == "commands" then
        Section("Slash commands", "Type these in chat. Key bindings are also listed in the game Key Bindings menu.")
        for i = 1, #COMMAND_ROWS do
            Place(MakeCommandRow(parent, COMMAND_ROWS[i][1], COMMAND_ROWS[i][2]))
        end
        Section("Key bindings", "Bind Accessibility Helper actions in the default WoW key bindings UI.")
        Note("Escape → Options → Key Bindings → Accessibility Helper. Bindings cover tooltip, under mouse, arrows, target, distance, quests, stop, and repeat.")

    elseif id == "general_app" then
        Section("App", "Master switch and window helpers.")
        Check("Master enable", "masterEnable", "Turns every Accessibility Helper announcement off or on.")
        Check("Echo spoken lines to chat", "chatEcho", "Also prints each spoken line in your chat frame. Useful when checking wording.")
        Check("Show minimap button", "minimapButtonEnabled", "Shows the Accessibility Helper icon around the minimap. Left-click opens settings. Drag to move it.")

    elseif id == "general_tts" then
        Section("Text to speech", "Voice used for addon announcements.")
        Step("TTS volume", "addonTtsVolume", 0, 100, 5, function(v)
            return tostring(v) .. "%"
        end, "Loudness of Accessibility Helper speech. This is separate from game master volume.")
        Step("TTS voice speed", "addonTtsRate", 0, 10, 1, function(v)
            return tostring(v) .. " / 10"
        end, "0 is the default slowest speed. Each step from 1 to 10 is faster. The speaker previews this speed.", PreviewRate)
        Choice(
            "TTS voice",
            "Voice used for all addon speech. System default follows WoW accessibility settings.",
            VoiceChoices,
            CurrentVoiceName,
            function(choice)
                AH.DB.Get().addonTtsVoiceID = choice.voiceID
                SpeakNow("TTS voice " .. choice.name .. ".")
            end,
            PreviewVoice
        )

    elseif id == "sounds_default" then
        Section("Default alert sound", "Used when an alert still says Use default sound.")
        Note("Turn announces on under You and Combat. Come here to choose TTS, sound, or both, and which sound plays.")
        if not (AH.Sounds and AH.Sounds.HasSharedMedia and AH.Sounds.HasSharedMedia()) then
            Note("Install LibSharedMedia and a sound pack addon (for example SharedMedia) to add more packs here.")
        end
        Choice(
            "Sound pack",
            "Installed pack to browse for the default sound. Blizzard is always available.",
            function()
                return (AH.Sounds and AH.Sounds.GetSources and AH.Sounds.GetSources()) or { { id = "blizzard", name = "Blizzard" } }
            end,
            CurrentSoundSourceName,
            function(choice)
                local sounds = (AH.Sounds and AH.Sounds.GetSounds and AH.Sounds.GetSounds(choice.id)) or {}
                local current = CurrentSoundID()
                local keep = false
                for i = 1, #sounds do
                    if sounds[i].id == current then
                        keep = true
                        break
                    end
                end
                if not keep and sounds[1] then
                    AH.DB.Get().soundPack = sounds[1].id
                end
                if AH.Sounds and AH.Sounds.PlaySelected then
                    AH.Sounds.PlaySelected()
                end
                SpeakNow("Sound pack " .. choice.name .. ".")
                RefreshRows()
            end
        )
        Choice(
            "Sound",
            "The default sound. Each alert under Sounds can pick a different one.",
            function()
                if AH.Sounds and AH.Sounds.GetSounds then
                    return AH.Sounds.GetSounds(CurrentSoundSource())
                end
                return {}
            end,
            function()
                if AH.Sounds and AH.Sounds.SoundName then
                    return AH.Sounds.SoundName(CurrentSoundID())
                end
                return "Raid Warning"
            end,
            function(choice)
                AH.DB.Get().soundPack = choice.id
                if AH.Sounds and AH.Sounds.Play then
                    AH.Sounds.Play(choice.id)
                end
                SpeakNow("Sound " .. choice.name .. ".")
            end,
            function()
                if AH.Sounds and AH.Sounds.PlaySelected then
                    AH.Sounds.PlaySelected()
                end
            end
        )

    elseif id == "sounds_vitals" then
        Section("Health and death", "How these alerts are delivered. Turn them on under You → Health and death.")
        AlertItem("In combat / out of combat", "stateCombat", "vital", "Announces when you enter or leave combat.", true)
        AlertItem("Dead", "stateDead", "vital", "Announces when you die.", true)
        AlertItem("Ghost", "stateGhost", "vital", "Announces when you release and become a ghost.", true)
        AlertItem("Resurrected", "stateResurrected", "vital", "Announces when you are resurrected.", true)
        AlertItem("Health below 35%", "stateHealthLow", "vital", "Announces when health drops under 35%.", true)
        AlertItem("Breath", "stateBreath", "vital", "Announces low breath while underwater and when you surface.", true)
        AlertItem("Fatigue", "stateFatigue", "vital", "Announces fatigue while swimming too far from shore.", true)

    elseif id == "sounds_casts" then
        Section("Casts", "How cast bars are delivered. Turn them on under Combat → Casts.")
        AlertItem("Player casts", "castsPlayerEnabled", "duration", "Your own casts and channels.", true)
        AlertItem("Target, focus, and boss casts", "castsEnemyEnabled", "duration", "Hostile target, focus, boss, and arena only. Nearby or friendly players are not announced as enemies.", true)

    elseif id == "sounds_interrupt" then
        Section("Interrupt", "How the interrupt cue is delivered. Turn it on under Combat → Interrupt.")
        AlertItem("Enemy cast can be interrupted", "interruptAlertEnabled", "interrupt", "Hostile target, focus, or boss. Skips if you are silenced or stunned.", true)

    elseif id == "sounds_loc" then
        Section("Loss of control", "How each type is delivered. Turn types on under Combat → Loss of control.")
        AlertItem("Stun", "combatLocStun", "loc", "Stun alerts.", true)
        AlertItem("Root", "combatLocRoot", "loc", "Root alerts.", true)
        AlertItem("Silence", "combatLocSilence", "loc", "Silence alerts.", true)
        AlertItem("Fear", "combatLocFear", "loc", "Fear alerts.", true)
        AlertItem("Horror", "combatLocHorror", "loc", "Horror alerts.", true)
        AlertItem("Disorient", "combatLocDisorient", "loc", "Disorient alerts.", true)
        AlertItem("Cyclone", "combatLocCyclone", "loc", "Cyclone alerts.", true)
        AlertItem("Incapacitate", "combatLocIncap", "loc", "Incapacitate alerts.", true)
        AlertItem("Charm / possess", "combatLocCharm", "loc", "Charm and possess alerts.", true)
        AlertItem("Pacify", "combatLocPacify", "loc", "Pacify alerts.", true)
        AlertItem("Disarm", "combatLocDisarm", "loc", "Disarm alerts.", true)
        AlertItem("Banish", "combatLocBanish", "loc", "Banish alerts.", true)
        AlertItem("Interrupt / lockout", "combatLocLockout", "loc", "School lockout alerts.", true)
        AlertItem("Other loss of control", "combatLocOther", "loc", "Other Blizzard loss-of-control types.", true)

    elseif id == "sounds_debuffs" then
        Section("Debuffs", "How each type is delivered. Turn types on under Combat → Debuffs.")
        AlertItem("Poison", "combatAuraPoison", "debuff", "Poison debuff alerts.", true)
        AlertItem("Disease", "combatAuraDisease", "debuff", "Disease debuff alerts.", true)
        AlertItem("Curse", "combatAuraCurse", "debuff", "Curse debuff alerts.", true)
        AlertItem("Magic", "combatAuraMagic", "debuff", "Magic debuff alerts.", true)

    elseif id == "sounds_buffs" then
        Section("Buffs", "How each event is delivered. Turn events on under Combat → Buffs.")
        AlertItem("Buff applied", "combatBuffsApply", "buff", "Example: Power Infusion. 20 seconds.", true)
        AlertItem("Buff faded", "combatBuffsFade", "buff", "Example: Power Infusion faded.", true)
        AlertItem("Stack counts", "combatBuffsStacks", "buff", "When stacks change.", true)

    elseif id == "chat_master" then
        Section("Turn chat reading on", "Chat reading stays off until you turn this on.")
        Note("Loot and currencies are under Rewards. Money lines are under You → World. Red errors are under Reading → Errors. Tradeskill chat is under Chat → Crafting, not Combat.")
        Check("Read chat channels", "chatReadEnabled", "Master switch for chat TTS. Individual channels still need to be turned on in the other Chat pages.")

    elseif CHAT_SECTION[id] then
        Section(CHAT_SECTION[id], "Each channel has its own switch. Chat → Turn reading on must also be on.")
        ChatChecks(CHAT_SECTION[id])

    elseif id == "reading_tooltips" then
        Section("Tooltips", "Reads the tooltip under the mouse.")
        Check("Enable tooltip reading", "tooltipsEnabled", "Allows /ahtip and the tooltip keybind to speak the hovered tooltip.")
        Check("Include comparison tooltips", "tooltipCompare", "Also reads the side-by-side comparison tooltip when it is shown.")
        Check("Read Titan Panel tooltips", "tooltipTitanEnabled", "Covers TitanPanelTooltip, LibQTip, and LDB plugin tips with the same command and keybind.")

    elseif id == "reading_undermouse" then
        Section("UI text", "Whatever is under the cursor: labels, tooltips, action buttons, and units.")
        Choice(
            "When to read",
            "Keybind only: press the key or type /ahread. As I hover: speaks in game whenever the mouse is over something readable. Off: never. Settings stay silent on hover unless this is As I hover.",
            function()
                return {
                    { id = "keybind", name = "Keybind only" },
                    { id = "hover", name = "As I hover" },
                    { id = "off", name = "Off" },
                }
            end,
            function()
                local m = AH.DB and AH.DB.GetUnderMouseMode and AH.DB.GetUnderMouseMode() or "keybind"
                if m == "hover" then
                    return "As I hover"
                end
                if m == "off" then
                    return "Off"
                end
                return "Keybind only"
            end,
            function(choice)
                if AH.DB and AH.DB.SetUnderMouseMode then
                    AH.DB.SetUnderMouseMode(choice.id)
                end
                SpeakNow("When to read " .. choice.name .. ".")
                RefreshRows()
            end
        )
        Note("Keybind only is the default. Bind it: Escape → Options → Key Bindings → Accessibility Helper → Read text under mouse. Or type /ahread. As I hover also reads in-game tooltips, buttons, and units under the cursor. /ahtip still reads the tooltip on its own keybind.")
        Check("Announce interaction under the cursor", "cursorAnnounceEnabled", "On by default. Speaks name, title, then action only when the cursor icon changes, for example Toby Hill Weapons Master Repair. Independent of When to read.")

    elseif id == "reading_waypoints" then
        Section("Waypoints and facing", "Arrow addons and clock-style facing.")
        Check("Enable TomTom arrow reading", "tomtomReadEnabled", "Lets /ahtt and the TomTom keybind read the current arrow.")
        Check("Enable Zygor arrow reading", "zygorReadEnabled", "Lets /ahz and the Zygor keybind read the current arrow.")
        Check("Arrow facing clock", "facingArrowEnabled", "Speaks clock facing for the waypoint arrow while out of combat. Silent at 12 o'clock. Toggle with /aha.")
        Check("Target facing clock", "facingTargetEnabled", "Speaks clock facing for your target, including in combat. Toggle with /ahtf. Full target: /ahtarget.")

    elseif id == "reading_distance" then
        Section("Distance", "How far your target is.")
        Check("Enable target distance reading", "distanceEnabled", "Lets /ahdist and the distance keybind speak yards to your target.")

    elseif id == "reading_location" then
        Section("Location", "Where you are in the world.")
        Check("Announce subzone changes", "locationSubzoneEnabled", "Speaks when you enter a new subzone. Area discoveries still come from chat System Messages if that channel is on.")

    elseif id == "reading_uierrors" then
        Section("UI Errors", "The red text that appears at the top of the screen.")
        Check("Read red UI error messages", "uiErrorsEnabled", "Speaks messages such as out of range or not enough mana.")
        Step("UI error cooldown", "uiErrorCooldownSec", 0, 5, 0.25, function(v)
            return string.format("%.2f sec", v)
        end, "Minimum time between the same UI error so repeats are not spoken over and over.")

    elseif id == "player_movement" then
        Section("Movement", "How you are traveling.")
        Check("Following someone", "stateFollow", "Announces when you start or stop following, including the name when available.")
        Check("Flying", "stateFly", "Announces when you start or stop flying.")
        Check("Mounted", "stateMount", "Announces when you mount or dismount.")
        Check("Swimming", "stateSwim", "Announces when you start or stop swimming.")
        Check("Indoors / outdoors", "stateIndoors", "Announces when you move indoors or outdoors.")
        Check("Falling", "stateFalling", "Announces when you start falling and when you land.")
        Check("Taxi", "stateTaxi", "Announces flight path taxi start and stop.")
        Check("Vehicle", "stateVehicle", "Announces entering or leaving a vehicle.")

    elseif id == "player_vitals" then
        Section("Health and death", "Turn these announces on or off. Choose TTS or sound under Sounds → Health and death.")
        Check("In combat / out of combat", "stateCombat", "Announces when you enter or leave combat.")
        Check("Dead", "stateDead", "Announces when you die.")
        Check("Ghost", "stateGhost", "Announces when you release and become a ghost.")
        Check("Resurrected", "stateResurrected", "Announces when you are resurrected.")
        Check("Health below 35%", "stateHealthLow", "Announces when health drops under 35%. Uses Blizzard’s low-health flash when health is hidden in combat.")
        Check("Breath", "stateBreath", "Announces low breath while underwater and when you surface.")
        Check("Fatigue", "stateFatigue", "Announces fatigue while swimming too far from shore.")

    elseif id == "player_world" then
        Section("World", "Bags, instances, and other world state.")
        Check("Stuck", "stateStuck", "Automatic stuck warning when the client reports you are stuck.")
        Check("Resting", "stateResting", "Announces when you start or stop resting.")
        Check("Instance entered / left", "stateInstance", "Announces entering or leaving an instance.")
        Check("Queue updates", "stateQueue", "Announces dungeon, raid, and similar queue updates.")
        Check("Bags full", "stateBagFull", "Announces when your bags cannot hold more items.")
        Check("Durability low", "stateDurability", "Announces when equipped durability is low.")
        Check("Money chat", "stateMoney", "Reads loot and money gain lines. Example: You loot 2 Gold, 15 Silver.")

    elseif id == "player_identity" then
        Section("Status", "Who you are and who you are with.")
        Check("AFK", "stateAFK", "Announces when you go AFK or return.")
        Check("PvP flag", "statePvP", "Announces when you become PvP flagged or lose the flag.")
        Check("Stealth", "stateStealth", "Announces entering or leaving stealth.")
        Check("Shapeshift / form", "stateShapeshift", "Announces stance, form, and shapeshift changes.")
        Check("Pet summoned / dismissed", "statePet", "Announces when your pet appears or is dismissed.")
        Check("Group joined / left", "stateGroup", "Announces joining or leaving a party or raid.")

    elseif id == "player_social" then
        Section("People", "Level, quests, targeting, and friends.")
        Check("Level up", "stateLevelUp", "Congratulates you, then announces class, specialization, or hero talent points when they are gained.")
        Check("Quest accepted / complete / turn-in", "stateQuest", "Announces those quest status changes.")
        Check("Target acquired / cleared", "stateTarget", "Announces when you gain or clear a target.")
        Check("Target of target off you", "stateTargetOfTarget", "When a hostile target is looking at someone else, speaks that name. Speaks On you when they come back. Meant for tanks watching aggro.")
        Check("Battle.net friends", "stateBNFriends", "Announces Battle.net friends coming online or going offline.")

    elseif id == "rewards_quests" then
        Section("Quests", "Reading quest text and objective progress.")
        Check("Enable quest objectives reading", "questObjectivesEnabled", "Lets /ahquest read the objectives of your tracked quests.")
        Check("Enable quest window reading", "questWindowEnabled", "Lets /ahqw read one NPC dialog quest or one selected log quest — not the full log.")
        Check("Announce when objectives progress", "questObjectiveProgressEnabled", "Speaks only the objective that changed. Off by default because it can be noisy.")

    elseif id == "rewards_loot" then
        Section("Loot", "Items and currencies you receive.")
        Check("Announce looted items", "lootItemsEnabled", "Example: You receive loot: [Sword]. Also reads party loot lines as printed.")
        Check("Announce currencies and honor", "lootCurrencyEnabled", "Example: You receive currency: 50 Honor. Also includes quest currency rewards.")

    elseif id == "rewards_progress" then
        Section("Skills and reputation", "Profession skill, experience, and reputation.")
        Check("Profession / skill increases", "progressSkill", "Example: Your skill in Mining has increased to 75.")
        Check("Experience gains", "progressXP", "Example: You gain 1,240 experience. Also covers exploration XP when chat has no XP line.")
        Check("Reputation point gains", "progressRep", "Example: Reputation with Stormwind increased by 250.")
        Check("Reputation standing changes", "progressRepStanding", "Example: You are now Friendly with Stormwind.")

    elseif id == "combat_duration" then
        Section("Casts", "Turn these on or off. Choose TTS or sound under Sounds → Casts.")
        Check("Read cast and channel bars", "castsEnabled", "Master switch for this page. Player and enemy casts still need to be on.")
        Check("Player casts", "castsPlayerEnabled", "Your own casts and channels. Example: Casting Frostbolt. 2 seconds.")
        Check("Target, focus, and boss casts", "castsEnemyEnabled", "Hostile target, focus, boss, and arena cast bars only. Nearby or friendly players are not announced as enemies. Example: Target casting Frostbolt. 2 seconds. Can interrupt.")

    elseif id == "combat_interrupt" then
        Section("Interrupt", "Turn this on or off. Choose TTS or sound under Sounds → Interrupt.")
        Check("Alert when an enemy cast can be interrupted", "interruptAlertEnabled", "Fires once for a hostile target, focus, or boss cast. Skips if you are silenced or stunned.")

    elseif id == "combat_loc" then
        Section("Loss of control", "Turn types on or off. Choose TTS or sound under Sounds → Loss of control.")
        Check("Enable loss of control announces", "combatLocEnabled", "Master switch for this page. Individual types still need to be on.")
        Check("Include spell names", "combatAnnounceSpellNames", "Adds the spell name when Blizzard reports it. Remaining time is also read from the duration bar when available.")
        Check("Stun", "combatLocStun", "Announce stuns.")
        Check("Root", "combatLocRoot", "Announce roots.")
        Check("Silence", "combatLocSilence", "Announce silences.")
        Check("Fear", "combatLocFear", "Announce fears.")
        Check("Horror", "combatLocHorror", "Announce horrors.")
        Check("Disorient", "combatLocDisorient", "Announce disorients.")
        Check("Cyclone", "combatLocCyclone", "Announce cyclone.")
        Check("Incapacitate", "combatLocIncap", "Announce incapacitates.")
        Check("Charm / possess", "combatLocCharm", "Announce charm and possess.")
        Check("Pacify", "combatLocPacify", "Announce pacify.")
        Check("Disarm", "combatLocDisarm", "Announce disarm.")
        Check("Banish", "combatLocBanish", "Announce banish.")
        Check("Interrupt / lockout", "combatLocLockout", "Announce school lockouts after an interrupt.")
        Check("Other loss of control", "combatLocOther", "Announce other Blizzard loss-of-control types not listed above.")

    elseif id == "combat_debuffs" then
        Section("Debuffs", "Turn types on or off. Choose TTS or sound under Sounds → Debuffs.")
        Check("Enable debuff type announces", "combatAurasEnabled", "Master switch for poison, disease, curse, and magic.")
        Check("Poison", "combatAuraPoison", "Announce poison debuffs.")
        Check("Disease", "combatAuraDisease", "Announce disease debuffs.")
        Check("Curse", "combatAuraCurse", "Announce curse debuffs.")
        Check("Magic", "combatAuraMagic", "Announce magic debuffs.")

    elseif id == "combat_buffs" then
        Section("Buffs", "Turn events on or off. Choose TTS or sound under Sounds → Buffs.")
        Note("In combat only. Speaks buffs applied by you and by others.")
        Check("Enable combat buff announces", "combatBuffsEnabled", "Master switch for this page.")
        Check("Include remaining duration", "combatBuffsDuration", "Adds remaining time to apply and stack alerts. Skipped for permanent buffs.")
        Check("Buff applied", "combatBuffsApply", "Example: Power Infusion. 20 seconds.")
        Check("Buff faded", "combatBuffsFade", "Example: Power Infusion faded.")
        Check("Stack counts", "combatBuffsStacks", "Announces when stacks change. Example: Mark of the Wild. 3 stacks. 15 seconds.")
    end

    parent:SetHeight(math.max(480, math.abs(y) + 24))
end

local function RebuildPage()
    if not frame or not frame.scroll then
        return
    end
    HideChoiceMenu()
    HideTooltip()
    if frame.content then
        frame.content:Hide()
        frame.content:SetParent(nil)
        frame.content = nil
    end
    frame.rows = {}
    local content = CreateFrame("Frame", nil, frame.scroll)
    content:SetWidth(620)
    frame.content = content
    frame.scroll:SetScrollChild(content)
    BuildPage(selectedId, content, frame.rows)
    frame.scroll:SetVerticalScroll(0)
    if frame.scroll.UpdateScrollChildRect then
        frame.scroll:UpdateScrollChildRect()
    end
end

local function PaintNav()
    if not frame or not frame.navButtons then
        return
    end
    for i = 1, #frame.navButtons do
        local btn = frame.navButtons[i]
        local on = btn.navId == selectedId
        if btn.Bar then
            btn.Bar:SetShown(on)
        end
        if btn.Label then
            if on then
                btn.Label:SetTextColor(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 1)
            else
                btn.Label:SetTextColor(COL_HINT[1], COL_HINT[2], COL_HINT[3], 1)
            end
        end
    end
end

SelectNav = function(id, silent)
    selectedId = id
    PaintNav()
    RebuildPage()
    if not silent then
        local label = id
        local hint = ""
        for i = 1, #NAV do
            if NAV[i].id == id then
                label = NAV[i].label
                hint = NAV[i].hint or ""
                break
            end
        end
        SpeakNow(label .. ". " .. hint)
    end
end

local function BuildNav(navChild)
    frame.navButtons = {}
    local y = -4
    for i = 1, #NAV do
        local info = NAV[i]
        if info.header then
            local header = CreateFrame("Frame", nil, navChild)
            header:SetHeight(NAV_PARENT_H)
            header:SetPoint("TOPLEFT", 8, y)
            header:SetPoint("RIGHT", -8, 0)
            header:EnableMouse(true)
            AddHoverWash(header)
            BindHover(header, info.label, info.hint or ("Settings in the " .. info.label .. " group."))
            local fs = FontString(header, 12, COL_MUTED[1], COL_MUTED[2], COL_MUTED[3])
            fs:SetPoint("LEFT", 4, 0)
            fs:SetText(string.upper(info.label))
            y = y - (NAV_PARENT_H + 2)
        else
            local btn = CreateFrame("Button", nil, navChild)
            btn:SetHeight(NAV_CHILD_H)
            btn:SetPoint("TOPLEFT", info.parent and 18 or 6, y)
            btn:SetPoint("RIGHT", -8, 0)
            AddHoverWash(btn)
            local bar = btn:CreateTexture(nil, "ARTWORK")
            bar:SetWidth(3)
            bar:SetPoint("TOPLEFT", 0, -6)
            bar:SetPoint("BOTTOMLEFT", 0, 6)
            bar:SetColorTexture(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 1)
            bar:Hide()
            btn.Bar = bar
            local fs = FontString(btn, 14, COL_HINT[1], COL_HINT[2], COL_HINT[3])
            fs:SetPoint("LEFT", 14, 0)
            fs:SetPoint("RIGHT", -8, 0)
            fs:SetText(info.label)
            btn.Label = fs
            btn.navId = info.id
            btn:SetScript("OnClick", function()
                SelectNav(info.id)
            end)
            btn:SetScript("OnEnter", function(self)
                if self.Hover then
                    self.Hover:Show()
                end
                ShowTip(self, info.label, info.hint)
                HoverSpeak(info.label .. ". " .. (info.hint or ""))
            end)
            btn:SetScript("OnLeave", function(self)
                if self.Hover then
                    self.Hover:Hide()
                end
                HideTooltip()
            end)
            frame.navButtons[#frame.navButtons + 1] = btn
            y = y - (NAV_CHILD_H + NAV_GAP)
        end
    end
    navChild:SetHeight(math.max(400, math.abs(y) + 16))
end

local function BuildFrame()
    if built and frame then
        return frame
    end

    frame = CreateFrame("Frame", FRAME_NAME, UIParent, Template())
    frame:SetSize(960, 720)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    ApplyBackdrop(frame)
    tinsert(UISpecialFrames, FRAME_NAME)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 20, -16)
    header:SetPoint("TOPRIGHT", -20, -16)
    header:SetHeight(36)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(28, 28)
    logo:SetPoint("LEFT", 0, 0)
    logo:SetTexture(ICON_PATH)

    local title = FontString(header, 20, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetText("Accessibility Helper")

    local subtitle = FontString(header, 13, COL_HINT[1], COL_HINT[2], COL_HINT[3])
    subtitle:SetPoint("LEFT", title, "RIGHT", 12, 0)
    subtitle:SetText("Settings")

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", 6, 2)
    close:SetScript("OnClick", function()
        frame:Hide()
        SpeakNow("Settings closed.")
    end)
    close:SetScript("OnEnter", function(self)
        ShowTip(self, "Close", "Close Accessibility Helper settings. Escape also works.")
        HoverSpeak("Close settings.")
    end)
    close:SetScript("OnLeave", HideTooltip)

    BindHover(header, "Accessibility Helper Settings", "Left list is grouped by topic. You and Combat turn alerts on. Sounds chooses TTS or a sound for those alerts. Chat includes crafting. Hover any row for a longer hint.")

    local rule = header:CreateTexture(nil, "ARTWORK")
    rule:SetColorTexture(COL_RULE[1], COL_RULE[2], COL_RULE[3], COL_RULE[4])
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, 0)
    rule:SetPoint("BOTTOMRIGHT", 0, 0)

    local navScroll = CreateFrame("ScrollFrame", FRAME_NAME .. "NavScroll", frame, "UIPanelScrollFrameTemplate")
    navScroll:SetPoint("TOPLEFT", 16, -64)
    navScroll:SetPoint("BOTTOMLEFT", 16, 40)
    navScroll:SetWidth(200)
    local navChild = CreateFrame("Frame", nil, navScroll)
    navChild:SetWidth(180)
    navScroll:SetScrollChild(navChild)
    frame.navScroll = navScroll
    BuildNav(navChild)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetColorTexture(COL_RULE[1], COL_RULE[2], COL_RULE[3], 0.35)
    divider:SetPoint("TOPLEFT", navScroll, "TOPRIGHT", 18, 0)
    divider:SetPoint("BOTTOMLEFT", navScroll, "BOTTOMRIGHT", 18, 0)

    local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "Scroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", divider, "TOPRIGHT", 16, 0)
    scroll:SetPoint("BOTTOMRIGHT", -36, 40)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll() or 0
        local max = self:GetVerticalScrollRange() or 0
        local next = cur - (delta * 48)
        if next < 0 then
            next = 0
        elseif next > max then
            next = max
        end
        self:SetVerticalScroll(next)
    end)
    frame.scroll = scroll

    local footer = FontString(frame, 12, COL_MUTED[1], COL_MUTED[2], COL_MUTED[3])
    footer:SetPoint("BOTTOMLEFT", 20, 14)
    footer:SetText("/ah  ·  Esc to close  ·  Hover a row for details")

    local version = FontString(frame, 12, COL_MUTED[1], COL_MUTED[2], COL_MUTED[3])
    version:SetPoint("BOTTOMRIGHT", -20, 14)
    version:SetJustifyH("RIGHT")
    local ver = "3.6.4"
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        ver = C_AddOns.GetAddOnMetadata("AccessibilityHelper", "Version") or ver
    elseif GetAddOnMetadata then
        ver = GetAddOnMetadata("AccessibilityHelper", "Version") or ver
    end
    version:SetText("v" .. tostring(ver) .. "  ·  Blind Mice Gaming")

    frame.rows = {}
    frame:SetScript("OnShow", function(self)
        for i = 1, #(self.rows or {}) do
            if self.rows[i].Refresh then
                self.rows[i]:Refresh()
            end
        end
        SelectNav(selectedId or "commands", true)
    end)
    frame:HookScript("OnHide", function()
        HideChoiceMenu()
        HideTooltip()
    end)

    built = true
    SelectNav("commands", true)
    return frame
end

function Settings.Toggle()
    local f = BuildFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        SpeakNow("Accessibility Helper settings.")
    end
end

function Settings.Open()
    local f = BuildFrame()
    if not f:IsShown() then
        f:Show()
        SpeakNow("Accessibility Helper settings.")
    end
end

function Settings.GetFrame()
    return frame
end

function Settings.Close()
    if frame and frame:IsShown() then
        frame:Hide()
    end
end

function Settings.RefreshCheckboxes()
    if not frame or not frame.rows then
        return
    end
    for i = 1, #frame.rows do
        if frame.rows[i].Refresh then
            frame.rows[i]:Refresh()
        end
    end
end
