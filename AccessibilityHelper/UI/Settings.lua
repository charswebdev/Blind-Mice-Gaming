--[[
  Accessibility Helper — high-contrast tabbed settings UI
  Left tab list; one section per tab; Commands as a clean table.
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Settings = AH.Settings or {}
local Settings = AH.Settings

local FRAME_NAME = "AccessibilityHelperSettingsFrame"
local COL_BG = { 0, 0, 0, 1 }
local COL_BORDER = { 1, 1, 1, 1 }
local COL_TITLE = { 1, 1, 1, 1 }
local COL_SECTION = { 1, 0.92, 0.4, 1 }
local COL_LABEL = { 1, 1, 1, 1 }
local COL_HINT = { 0.75, 0.75, 0.75, 1 }
local COL_TAB = { 0.15, 0.15, 0.15, 1 }
local COL_TAB_ON = { 0.28, 0.28, 0.1, 1 }
local COL_ROW = { 0.08, 0.08, 0.08, 1 }

local frame
local built = false
local selectedTab = 1

local COMMAND_ROWS = {
    { "/ah, /ahelp", "Open settings" },
    { "/ahcmds", "Print command list to chat" },
    { "/ahs", "Test text to speech" },
    { "/ahstop", "Stop speaking" },
    { "/ahclear, /ahflush", "Clear queued TTS announcements" },
    { "/ahrepeat, /ahr", "Repeat last speech" },
    { "/ahreadtip, /ahtip", "Read hovered tooltip (including Titan Panel)" },
    { "/ahtt, /aharrow, /ahtomtom", "Read TomTom arrow" },
    { "/ahz, /ahzygor", "Read Zygor arrow" },
    { "/aha", "Toggle arrow facing announcements" },
    { "/ahtarget, /ahrt", "Read current target" },
    { "/ahtf", "Toggle target facing announcements" },
    { "/ahdist, /ahdistance", "Read target distance" },
    { "/ahquest, /ahqo", "Read quest objectives" },
    { "/ahqw", "Read open NPC quest or selected log quest" },
}

local TABS = {
    { id = "commands", label = "Commands" },
    { id = "general", label = "General" },
    { id = "chat", label = "Chat" },
    { id = "tooltips", label = "Tooltips" },
    { id = "waypoints", label = "Waypoints" },
    { id = "distance", label = "Distance" },
    { id = "location", label = "Location" },
    { id = "uierrors", label = "UI Errors" },
    { id = "player", label = "Player State" },
    { id = "quests", label = "Quests" },
    { id = "loot", label = "Loot" },
    { id = "progress", label = "Progress" },
    { id = "combatloc", label = "Combat LoC" },
    { id = "combatdebuff", label = "Debuffs" },
    { id = "combatbuffs", label = "Buffs" },
}

local function FontString(parent, size, r, g, b, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local ok = fs:SetFont("Fonts\\FRIZQT__.TTF", size or 14, flags or "OUTLINE")
    if not ok then
        fs:SetFontObject(GameFontHighlight)
    end
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    fs:SetJustifyH("LEFT")
    return fs
end

local function ApplyBlackBackdrop(f)
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
    t:SetColorTexture(0, 0, 0, 1)
end

local function PaintSolid(f, r, g, b, a)
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
            local t = f:CreateTexture(nil, "BACKGROUND")
            t:SetAllPoints()
            f._ahTex = t
        end
        f._ahPainted = true
    end
    if f.SetBackdropColor then
        f:SetBackdropColor(r, g, b, a)
        f:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    elseif f._ahTex then
        f._ahTex:SetColorTexture(r, g, b, a)
    end
end

local function MakeCheckbox(parent, labelText, dbKey, y, checkboxes)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 12, y)
    cb:SetSize(28, 28)

    local label = FontString(parent, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetWidth(420)
    label:SetText(labelText)

    local function Refresh()
        local sv = AH.DB.Get()
        -- Opt-in keys default off (false); others default on unless explicitly false.
        if dbKey == "chatEcho"
            or dbKey == "chatReadEnabled"
            or dbKey == "questObjectiveProgressEnabled"
            or (type(dbKey) == "string" and dbKey:match("^chat") and dbKey ~= "chatEcho")
        then
            cb:SetChecked(sv[dbKey] == true)
        else
            cb:SetChecked(sv[dbKey] ~= false)
        end
    end

    cb:SetScript("OnClick", function(self)
        local sv = AH.DB.Get()
        sv[dbKey] = self:GetChecked() and true or false
        if dbKey == "minimapButtonEnabled" and AH.MinimapButton and AH.MinimapButton.Refresh then
            AH.MinimapButton.Refresh()
        end
        if AH.Speech and AH.Speech.Say then
            local state = sv[dbKey] and "on" or "off"
            AH.Speech.Say(labelText .. " " .. state .. ".", AH.Speech.PRIORITY_LOW)
        end
    end)

    cb.Refresh = Refresh
    Refresh()
    checkboxes[#checkboxes + 1] = cb
    return y - 32
end

local function MakeHint(parent, text, y)
    -- Leave a little air under the previous control so hints never sit on top of buttons.
    y = y - 4
    local fs = FontString(parent, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetWidth(430)
    fs:SetJustifyV("TOP")
    if fs.SetWordWrap then
        fs:SetWordWrap(true)
    end
    if fs.SetNonSpaceWrap then
        fs:SetNonSpaceWrap(true)
    end
    fs:SetText(text)
    local h = 14
    if fs.GetStringHeight then
        h = fs:GetStringHeight() or 14
    end
    if h < 14 then
        h = 14
    end
    return y - h - 12
end

--- Dark background + bright text (matches settings high-contrast look).
local function StyleDarkButton(btn)
    PaintSolid(btn, 0.06, 0.06, 0.06, 1)
    if btn.SetBackdropBorderColor then
        btn:SetBackdropBorderColor(1, 1, 1, 1)
    end
    local fs = btn:GetFontString()
    if not fs then
        fs = btn:CreateFontString(nil, "OVERLAY")
        local ok = fs:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        if not ok then
            fs:SetFontObject(GameFontHighlight)
        end
        btn:SetFontString(fs)
    else
        local ok = fs:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        if not ok then
            fs:SetFontObject(GameFontHighlight)
        end
    end
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetShadowOffset(0, 0)
    btn:SetScript("OnEnter", function(self)
        PaintSolid(self, 0.22, 0.22, 0.1, 1)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 0.92, 0.4, 1)
        end
        local t = self:GetFontString()
        if t then
            t:SetTextColor(1, 0.92, 0.4, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        PaintSolid(self, 0.06, 0.06, 0.06, 1)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 1, 1, 1)
        end
        local t = self:GetFontString()
        if t then
            t:SetTextColor(1, 1, 1, 1)
        end
    end)
end

local function MakeDarkButton(parent, text, w, h)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local btn = CreateFrame("Button", nil, parent, template)
    btn:SetSize(w or 28, h or 22)
    btn:RegisterForClicks("LeftButtonUp")
    btn:EnableMouse(true)
    StyleDarkButton(btn)
    btn:SetText(text or "")
    return btn
end

local function MakeSpeakerButton(parent, anchor, onClick, tooltipText)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local btn = CreateFrame("Button", nil, parent, template)
    btn:SetSize(28, 28)
    btn:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    PaintSolid(btn, 0.06, 0.06, 0.06, 1)
    if btn.SetBackdropBorderColor then
        btn:SetBackdropBorderColor(1, 1, 1, 1)
    end

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Common\\VoiceChat-Speaker")
    btn._ahIcon = icon

    btn:SetScript("OnClick", function()
        if onClick then
            onClick()
        end
    end)
    btn:SetScript("OnEnter", function(self)
        PaintSolid(self, 0.22, 0.22, 0.1, 1)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 0.92, 0.4, 1)
        end
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText or "Preview", 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        PaintSolid(self, 0.06, 0.06, 0.06, 1)
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(1, 1, 1, 1)
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    return btn
end

local function MakeStepper(parent, labelText, dbKey, y, minV, maxV, step, formatFn, steppers, previewFn)
    local label = FontString(parent, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
    label:SetPoint("TOPLEFT", 16, y)
    label:SetWidth(168)
    label:SetWordWrap(false)
    label:SetText(labelText)

    local rightPad = previewFn and -100 or -64
    local valueFs = FontString(parent, 14, COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], "OUTLINE")
    valueFs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", rightPad, y)
    valueFs:SetJustifyH("CENTER")
    valueFs:SetWidth(56)

    local function current()
        local sv = AH.DB.Get()
        local v = sv[dbKey]
        if type(v) ~= "number" then
            v = minV
        end
        if v < minV then v = minV end
        if v > maxV then v = maxV end
        return v
    end

    local function refresh()
        local v = current()
        if formatFn then
            valueFs:SetText(formatFn(v))
        else
            valueFs:SetText(tostring(v))
        end
    end

    local minus = MakeDarkButton(parent, "-", 28, 24)
    minus:SetPoint("RIGHT", valueFs, "LEFT", -6, 0)
    minus:SetScript("OnClick", function()
        AccessibilityHelperDB = AccessibilityHelperDB or {}
        local v = current() - step
        if v < minV then v = minV end
        AccessibilityHelperDB[dbKey] = v
        refresh()
        if AH.Speech and AH.Speech.PreviewSample and dbKey == "addonTtsRate" then
            AH.Speech.PreviewSample(
                "Speed " .. (formatFn and formatFn(v) or tostring(v)) .. ".",
                v,
                nil
            )
        elseif AH.Speech and AH.Speech.Say then
            AH.Speech.Say(labelText .. " " .. (formatFn and formatFn(v) or tostring(v)) .. ".", AH.Speech.PRIORITY_LOW)
        end
    end)

    local plus = MakeDarkButton(parent, "+", 28, 24)
    plus:SetPoint("LEFT", valueFs, "RIGHT", 6, 0)
    plus:SetScript("OnClick", function()
        AccessibilityHelperDB = AccessibilityHelperDB or {}
        local v = current() + step
        if v > maxV then v = maxV end
        AccessibilityHelperDB[dbKey] = v
        refresh()
        if AH.Speech and AH.Speech.PreviewSample and dbKey == "addonTtsRate" then
            AH.Speech.PreviewSample(
                "Speed " .. (formatFn and formatFn(v) or tostring(v)) .. ".",
                v,
                nil
            )
        elseif AH.Speech and AH.Speech.Say then
            AH.Speech.Say(labelText .. " " .. (formatFn and formatFn(v) or tostring(v)) .. ".", AH.Speech.PRIORITY_LOW)
        end
    end)

    if previewFn then
        MakeSpeakerButton(parent, plus, previewFn, "Preview at this setting")
    end

    refresh()
    steppers[#steppers + 1] = { Refresh = refresh }
    return y - 36
end

--- Voice dropdown + speaker preview. Uses a custom high-contrast menu (not Blizzard UIDropDown).
local voiceMenuFrame

local function HideVoiceMenu()
    if voiceMenuFrame then
        voiceMenuFrame:Hide()
    end
end

local function MakeVoiceDropdown(parent, y, steppers)
    local label = FontString(parent, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
    label:SetPoint("TOPLEFT", 16, y)
    label:SetWidth(120)
    label:SetWordWrap(false)
    label:SetText("TTS voice")

    local drop = MakeDarkButton(parent, "System default", 200, 26)
    drop:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -72, y + 2)

    local function CurrentLabel()
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

    local function refresh()
        local text = CurrentLabel()
        if #text > 26 then
            text = text:sub(1, 24) .. "…"
        end
        drop:SetText(text)
        local fs = drop:GetFontString()
        if fs then
            fs:SetTextColor(1, 1, 1, 1)
        end
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

    MakeSpeakerButton(parent, drop, PreviewVoice, "Preview this voice")

    drop:SetScript("OnClick", function(self)
        if voiceMenuFrame and voiceMenuFrame:IsShown() and voiceMenuFrame._owner == self then
            HideVoiceMenu()
            return
        end

        if not voiceMenuFrame then
            voiceMenuFrame = CreateFrame("Frame", "AccessibilityHelperVoiceMenu", UIParent)
            voiceMenuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            voiceMenuFrame:SetClampedToScreen(true)
            ApplyBlackBackdrop(voiceMenuFrame)
            voiceMenuFrame:EnableMouse(true)
            voiceMenuFrame:SetScript("OnHide", function()
                voiceMenuFrame._owner = nil
            end)
        end

        -- Clear old rows
        if voiceMenuFrame.rows then
            for i = 1, #voiceMenuFrame.rows do
                voiceMenuFrame.rows[i]:Hide()
                voiceMenuFrame.rows[i]:SetParent(nil)
            end
        end
        voiceMenuFrame.rows = {}

        local choices = {
            { voiceID = -1, name = "System default" },
        }
        local voices = (AH.Compat and AH.Compat.ListTtsVoices and AH.Compat.ListTtsVoices()) or {}
        for i = 1, #voices do
            choices[#choices + 1] = voices[i]
        end

        local rowH = 26
        local maxRows = math.min(#choices, 12)
        local width = 280
        voiceMenuFrame:SetSize(width, 8 + maxRows * rowH)
        voiceMenuFrame:ClearAllPoints()
        voiceMenuFrame:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 34, -2)
        voiceMenuFrame:SetParent(UIParent)
        voiceMenuFrame._owner = self

        local scroll
        local listParent = voiceMenuFrame
        if #choices > 12 then
            scroll = CreateFrame("ScrollFrame", nil, voiceMenuFrame, "UIPanelScrollFrameTemplate")
            scroll:SetPoint("TOPLEFT", 4, -4)
            scroll:SetPoint("BOTTOMRIGHT", -26, 4)
            local child = CreateFrame("Frame", nil, scroll)
            child:SetSize(width - 30, #choices * rowH)
            scroll:SetScrollChild(child)
            listParent = child
            voiceMenuFrame:SetSize(width, 8 + 12 * rowH)
        end

        for i = 1, #choices do
            local choice = choices[i]
            local rowTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil
            local row = CreateFrame("Button", nil, listParent, rowTemplate)
            row:SetSize((scroll and (width - 30)) or (width - 8), rowH)
            row:SetPoint("TOPLEFT", listParent, "TOPLEFT", scroll and 0 or 4, -((i - 1) * rowH) - (scroll and 0 or 4))
            PaintSolid(row, 0.06, 0.06, 0.06, 1)
            if row.SetBackdropBorderColor then
                row:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
            end

            local fs = FontString(row, 13, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
            fs:SetPoint("LEFT", 8, 0)
            fs:SetWidth(width - 24)
            fs:SetText(choice.name)

            row:SetScript("OnEnter", function(r)
                PaintSolid(r, 0.22, 0.22, 0.1, 1)
                if r.SetBackdropBorderColor then
                    r:SetBackdropBorderColor(1, 0.92, 0.4, 1)
                end
                fs:SetTextColor(1, 0.92, 0.4, 1)
            end)
            row:SetScript("OnLeave", function(r)
                PaintSolid(r, 0.06, 0.06, 0.06, 1)
                if r.SetBackdropBorderColor then
                    r:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
                end
                fs:SetTextColor(1, 1, 1, 1)
            end)
            row:SetScript("OnClick", function()
                local sv = AH.DB.Get()
                sv.addonTtsVoiceID = choice.voiceID
                refresh()
                HideVoiceMenu()
                if AH.Speech and AH.Speech.Say then
                    AH.Speech.Say("TTS voice " .. choice.name .. ".", AH.Speech.PRIORITY_LOW)
                end
            end)

            voiceMenuFrame.rows[#voiceMenuFrame.rows + 1] = row
        end

        voiceMenuFrame:Show()
    end)

    -- Close menu when parent hides
    parent:HookScript("OnHide", HideVoiceMenu)

    refresh()
    steppers[#steppers + 1] = { Refresh = refresh }
    return y - 40
end

local function MakePanelHeader(parent, text, y)
    local fs = FontString(parent, 16, COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], "OUTLINE")
    fs:SetPoint("TOPLEFT", 12, y)
    fs:SetText(text)
    return y - 28
end

local function BuildCommandsTable(parent, y)
    local header = CreateFrame("Frame", nil, parent)
    header:SetPoint("TOPLEFT", 12, y)
    header:SetSize(450, 24)
    PaintSolid(header, 0.2, 0.2, 0.12, 1)

    local hCmd = FontString(header, 13, COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], "OUTLINE")
    hCmd:SetPoint("LEFT", 8, 0)
    hCmd:SetText("Command")

    local hDesc = FontString(header, 13, COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], "OUTLINE")
    hDesc:SetPoint("LEFT", 180, 0)
    hDesc:SetText("Description")

    y = y - 28

    for i = 1, #COMMAND_ROWS do
        local row = COMMAND_ROWS[i]
        local rowFrame = CreateFrame("Frame", nil, parent)
        rowFrame:SetPoint("TOPLEFT", 12, y)
        rowFrame:SetSize(450, 26)
        if (i % 2) == 0 then
            PaintSolid(rowFrame, COL_ROW[1], COL_ROW[2], COL_ROW[3], 1)
        end

        local cmd = FontString(rowFrame, 13, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
        cmd:SetPoint("LEFT", 8, 0)
        cmd:SetWidth(168)
        cmd:SetText(row[1])

        local desc = FontString(rowFrame, 13, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
        desc:SetPoint("LEFT", 180, 0)
        desc:SetWidth(260)
        desc:SetText(row[2])

        y = y - 26
    end

    y = y - 8
    y = MakeHint(parent, "Key Bindings → Accessibility Helper for all keybinds.", y)
    return y
end

local function FillPanel(id, content, checkboxes, steppers)
    local y = -8
    if id == "commands" then
        y = MakePanelHeader(content, "Commands", y)
        y = BuildCommandsTable(content, y)
    elseif id == "general" then
        y = MakePanelHeader(content, "General", y)
        y = MakeCheckbox(content, "Master enable (all TTS)", "masterEnable", y, checkboxes)
        y = MakeCheckbox(content, "Echo spoken lines to chat", "chatEcho", y, checkboxes)
        y = MakeCheckbox(content, "Show minimap button", "minimapButtonEnabled", y, checkboxes)
        y = MakeHint(content, "Left-click opens settings. Drag to reposition.", y)
        y = MakeStepper(content, "TTS volume", "addonTtsVolume", y, 0, 100, 5, function(v)
            return tostring(v) .. "%"
        end, steppers)
        y = MakeStepper(content, "TTS voice speed", "addonTtsRate", y, 0, 10, 1, function(v)
            return tostring(v) .. " / 10"
        end, steppers, function()
            if not (AH.Speech and AH.Speech.PreviewSample) then
                return
            end
            local rate = AH.DB and AH.DB.GetTtsRate and AH.DB.GetTtsRate() or 0
            AH.Speech.PreviewSample(
                "This is Accessibility Helper speaking at speed " .. tostring(rate) .. ".",
                rate,
                nil
            )
        end)
        y = MakeHint(content, "0 = default (slowest). 1–10 each step faster. Speaker previews this speed.", y)
        y = MakeVoiceDropdown(content, y, steppers)
        y = MakeHint(content, "Voice used for all addon speech. Speaker previews this voice.", y)
    elseif id == "chat" then
        y = MakePanelHeader(content, "Chat Channels", y)
        y = MakeHint(content, "All off by default. Turn on Read chat, then enable channels below.", y)
        y = MakeCheckbox(content, "Read chat channels (master)", "chatReadEnabled", y, checkboxes)
        y = MakeHint(content, "Item loot, currency, honor → Loot tab. XP, skills, reputation → Progress. Money → Player State.", y)
        local rows = AH.ChatChannels and AH.ChatChannels.SettingsRows and AH.ChatChannels.SettingsRows() or {}
        local addonRows = AH.AddonChat and AH.AddonChat.SettingsRows and AH.AddonChat.SettingsRows() or {}
        for i = 1, #addonRows do
            rows[#rows + 1] = addonRows[i]
        end
        for i = 1, #rows do
            local row = rows[i]
            if row.type == "header" then
                y = y - 6
                y = MakePanelHeader(content, row.label, y)
            elseif row.type == "hint" then
                y = MakeHint(content, row.label, y)
            else
                y = MakeCheckbox(content, row.label, row.key, y, checkboxes)
                if row.example then
                    y = MakeHint(content, "Ex: " .. row.example, y)
                end
            end
        end
        y = MakeHint(content, "Speaks lines as printed in chat. Red errors stay under UI Errors.", y)
    elseif id == "tooltips" then
        y = MakePanelHeader(content, "Tooltips", y)
        y = MakeCheckbox(content, "Enable tooltip reading", "tooltipsEnabled", y, checkboxes)
        y = MakeCheckbox(content, "Include comparison tooltips", "tooltipCompare", y, checkboxes)
        y = MakeCheckbox(content, "Read Titan Panel tooltips", "tooltipTitanEnabled", y, checkboxes)
        y = MakeHint(content, "Same Read hovered tooltip command and keybind. Covers TitanPanelTooltip, LibQTip, and LDB plugin tips.", y)
    elseif id == "waypoints" then
        y = MakePanelHeader(content, "Waypoints", y)
        y = MakeCheckbox(content, "Enable TomTom arrow reading", "tomtomReadEnabled", y, checkboxes)
        y = MakeCheckbox(content, "Enable Zygor arrow reading", "zygorReadEnabled", y, checkboxes)
        y = MakeCheckbox(content, "Arrow facing clock (out of combat)", "facingArrowEnabled", y, checkboxes)
        y = MakeHint(content, "Toggle with /aha. Silent at 12 o'clock. Off in combat.", y)
        y = MakeCheckbox(content, "Target facing clock (always in combat)", "facingTargetEnabled", y, checkboxes)
        y = MakeHint(content, "Toggle with /ahtf. Full target: /ahtarget.", y)
    elseif id == "distance" then
        y = MakePanelHeader(content, "Distance", y)
        y = MakeCheckbox(content, "Enable target distance reading", "distanceEnabled", y, checkboxes)
    elseif id == "location" then
        y = MakePanelHeader(content, "Location", y)
        y = MakeCheckbox(content, "Announce subzone changes", "locationSubzoneEnabled", y, checkboxes)
        y = MakeHint(content, "Area discoveries are read from chat (System Messages) when that channel is on.", y)
    elseif id == "uierrors" then
        y = MakePanelHeader(content, "UI Errors", y)
        y = MakeCheckbox(content, "Read red UI error messages", "uiErrorsEnabled", y, checkboxes)
        y = MakeStepper(content, "UI error cooldown (sec)", "uiErrorCooldownSec", y, 0, 5, 0.25, function(v)
            return string.format("%.2f", v)
        end, steppers)
    elseif id == "player" then
        y = MakePanelHeader(content, "Player State", y)
        y = MakeCheckbox(content, "Following someone (with name)", "stateFollow", y, checkboxes)
        y = MakeCheckbox(content, "Flying / stop flying", "stateFly", y, checkboxes)
        y = MakeCheckbox(content, "Mounted / dismounted", "stateMount", y, checkboxes)
        y = MakeCheckbox(content, "Swimming / stop swimming", "stateSwim", y, checkboxes)
        y = MakeCheckbox(content, "Indoors / outdoors", "stateIndoors", y, checkboxes)
        y = MakeCheckbox(content, "In combat / out of combat", "stateCombat", y, checkboxes)
        y = MakeCheckbox(content, "Dead", "stateDead", y, checkboxes)
        y = MakeCheckbox(content, "Ghost", "stateGhost", y, checkboxes)
        y = MakeCheckbox(content, "Resurrected", "stateResurrected", y, checkboxes)
        y = MakeCheckbox(content, "Stuck (automatic)", "stateStuck", y, checkboxes)
        y = MakeCheckbox(content, "Resting", "stateResting", y, checkboxes)
        y = MakeCheckbox(content, "Taxi", "stateTaxi", y, checkboxes)
        y = MakeCheckbox(content, "Vehicle", "stateVehicle", y, checkboxes)
        y = MakeCheckbox(content, "Falling / landed", "stateFalling", y, checkboxes)
        y = MakeCheckbox(content, "Fatigue", "stateFatigue", y, checkboxes)
        y = MakeCheckbox(content, "Breath low / surfaced", "stateBreath", y, checkboxes)
        y = MakeCheckbox(content, "Health below 35%", "stateHealthLow", y, checkboxes)
        y = MakeHint(content, "Announces when health drops under 35%. Uses Blizzard low-health flash when health is secret in combat.", y)
        y = MakeCheckbox(content, "AFK", "stateAFK", y, checkboxes)
        y = MakeCheckbox(content, "PvP flag", "statePvP", y, checkboxes)
        y = MakeCheckbox(content, "Stealth", "stateStealth", y, checkboxes)
        y = MakeCheckbox(content, "Shapeshift / form", "stateShapeshift", y, checkboxes)
        y = MakeCheckbox(content, "Pet summoned / dismissed", "statePet", y, checkboxes)
        y = MakeCheckbox(content, "Group joined / left", "stateGroup", y, checkboxes)
        y = MakeCheckbox(content, "Instance entered / left", "stateInstance", y, checkboxes)
        y = MakeCheckbox(content, "Queue updates", "stateQueue", y, checkboxes)
        y = MakeCheckbox(content, "Level up", "stateLevelUp", y, checkboxes)
        y = MakeHint(content, "Congratulates, then announces class / specialization / hero talent points when gained.", y)
        y = MakeCheckbox(content, "Quest accepted / complete / turn-in", "stateQuest", y, checkboxes)
        y = MakeCheckbox(content, "Bags full", "stateBagFull", y, checkboxes)
        y = MakeCheckbox(content, "Durability low", "stateDurability", y, checkboxes)
        y = MakeCheckbox(content, "Money chat (loot / gain lines)", "stateMoney", y, checkboxes)
        y = MakeHint(content, "Ex: You loot 2 Gold, 15 Silver. Also money-like system lines.", y)
        y = MakeCheckbox(content, "Target acquired / cleared", "stateTarget", y, checkboxes)
        y = MakeCheckbox(content, "Battle.net friends online / offline", "stateBNFriends", y, checkboxes)
        y = MakeHint(content, "Ex: Battle Net Friend [BN] - Bob has come Online!", y)
    elseif id == "quests" then
        y = MakePanelHeader(content, "Quests", y)
        y = MakeCheckbox(content, "Enable quest objectives reading", "questObjectivesEnabled", y, checkboxes)
        y = MakeCheckbox(content, "Enable quest window reading", "questWindowEnabled", y, checkboxes)
        y = MakeHint(content, "Auto-reads one quest from an NPC/object dialog, or one selected log quest — not the full log.", y)
        y = MakeCheckbox(content, "Announce when objectives progress", "questObjectiveProgressEnabled", y, checkboxes)
        y = MakeHint(content, "Only the quest objective that changed is spoken (not all quests).", y)
        y = MakeHint(content, "/ahquest or /ahqo — objectives. /ahqw — quest window.", y)
    elseif id == "loot" then
        y = MakePanelHeader(content, "Loot", y)
        y = MakeCheckbox(content, "Announce looted items", "lootItemsEnabled", y, checkboxes)
        y = MakeHint(content, "Ex: You receive loot: [Sword]. Also party loot lines as printed.", y)
        y = MakeCheckbox(content, "Announce currencies and honor", "lootCurrencyEnabled", y, checkboxes)
        y = MakeHint(content, "Ex: You receive currency: 50 Honor. Also quest currency rewards.", y)
    elseif id == "progress" then
        y = MakePanelHeader(content, "Progress", y)
        y = MakeCheckbox(content, "Profession / skill increases", "progressSkill", y, checkboxes)
        y = MakeHint(content, "Ex: Your skill in Mining has increased to 75.", y)
        y = MakeCheckbox(content, "Experience gains", "progressXP", y, checkboxes)
        y = MakeHint(content, "Ex: You gain 1,240 experience. Also exploration XP when chat has no XP line.", y)
        y = MakeCheckbox(content, "Reputation point gains", "progressRep", y, checkboxes)
        y = MakeHint(content, "Ex: Reputation with Stormwind increased by 250.", y)
        y = MakeCheckbox(content, "Reputation standing changes", "progressRepStanding", y, checkboxes)
        y = MakeHint(content, "Ex: You are now Friendly with Stormwind.", y)
    elseif id == "combatloc" then
        y = MakePanelHeader(content, "Combat — Loss of Control", y)
        y = MakeCheckbox(content, "Enable loss of control announces", "combatLocEnabled", y, checkboxes)
        y = MakeCheckbox(content, "Include spell names", "combatAnnounceSpellNames", y, checkboxes)
        y = MakeCheckbox(content, "Stun", "combatLocStun", y, checkboxes)
        y = MakeCheckbox(content, "Root", "combatLocRoot", y, checkboxes)
        y = MakeCheckbox(content, "Silence", "combatLocSilence", y, checkboxes)
        y = MakeCheckbox(content, "Fear", "combatLocFear", y, checkboxes)
        y = MakeCheckbox(content, "Horror", "combatLocHorror", y, checkboxes)
        y = MakeCheckbox(content, "Disorient", "combatLocDisorient", y, checkboxes)
        y = MakeCheckbox(content, "Cyclone", "combatLocCyclone", y, checkboxes)
        y = MakeCheckbox(content, "Incapacitate", "combatLocIncap", y, checkboxes)
        y = MakeCheckbox(content, "Charm / possess", "combatLocCharm", y, checkboxes)
        y = MakeCheckbox(content, "Pacify", "combatLocPacify", y, checkboxes)
        y = MakeCheckbox(content, "Disarm", "combatLocDisarm", y, checkboxes)
        y = MakeCheckbox(content, "Banish", "combatLocBanish", y, checkboxes)
        y = MakeCheckbox(content, "Interrupt / lockout", "combatLocLockout", y, checkboxes)
        y = MakeCheckbox(content, "Other loss of control", "combatLocOther", y, checkboxes)
    elseif id == "combatdebuff" then
        y = MakePanelHeader(content, "Combat — Debuff Types", y)
        y = MakeCheckbox(content, "Enable debuff type announces", "combatAurasEnabled", y, checkboxes)
        y = MakeCheckbox(content, "Poison", "combatAuraPoison", y, checkboxes)
        y = MakeCheckbox(content, "Disease", "combatAuraDisease", y, checkboxes)
        y = MakeCheckbox(content, "Curse", "combatAuraCurse", y, checkboxes)
        y = MakeCheckbox(content, "Magic", "combatAuraMagic", y, checkboxes)
    elseif id == "combatbuffs" then
        y = MakePanelHeader(content, "Combat — Buffs", y)
        y = MakeHint(content, "In combat only. Speaks all buffs on you (yours and others).", y)
        y = MakeCheckbox(content, "Enable combat buff announces", "combatBuffsEnabled", y, checkboxes)
        y = MakeCheckbox(content, "Announce when a buff is applied", "combatBuffsApply", y, checkboxes)
        y = MakeHint(content, "Ex: Power Infusion. 20 seconds.", y)
        y = MakeCheckbox(content, "Announce when a buff fades", "combatBuffsFade", y, checkboxes)
        y = MakeHint(content, "Ex: Power Infusion faded.", y)
        y = MakeCheckbox(content, "Include stack counts", "combatBuffsStacks", y, checkboxes)
        y = MakeHint(content, "Ex: Mark of the Wild. 3 stacks. 15 seconds.", y)
        y = MakeCheckbox(content, "Include remaining duration", "combatBuffsDuration", y, checkboxes)
        y = MakeHint(content, "Skipped for permanent buffs. Pure refreshes (same stacks) stay quiet.", y)
    end
    content:SetHeight(math.max(400, math.abs(y) + 24))
    -- Tall tabs (Chat) need an updated scroll range or lower sections never appear.
    if frame and frame.scroll and frame.scroll.UpdateScrollChildRect then
        frame.scroll:UpdateScrollChildRect()
    end
end

local function SelectTab(index, silent)
    HideVoiceMenu()
    if not frame or not frame.tabs then
        return
    end
    selectedTab = index
    for i = 1, #frame.tabs do
        local tab = frame.tabs[i]
        local on = (i == index)
        tab.selected = on
        if on then
            PaintSolid(tab, COL_TAB_ON[1], COL_TAB_ON[2], COL_TAB_ON[3], 1)
        else
            PaintSolid(tab, COL_TAB[1], COL_TAB[2], COL_TAB[3], 1)
        end
        if tab.labelFs then
            if on then
                tab.labelFs:SetTextColor(COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], 1)
            else
                tab.labelFs:SetTextColor(COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], 1)
            end
        end
        if frame.panels[i] then
            if on then
                frame.panels[i]:Show()
            else
                frame.panels[i]:Hide()
            end
        end
    end
    if frame.scroll then
        frame.scroll:SetVerticalScroll(0)
        if frame.panels[index] then
            frame.scroll:SetScrollChild(frame.panels[index])
            if frame.scroll.UpdateScrollChildRect then
                frame.scroll:UpdateScrollChildRect()
            end
        end
    end
    if not silent then
        local name = TABS[index] and TABS[index].label or "Settings"
        if AH.Speech and AH.Speech.Say then
            AH.Speech.Say(name .. " tab.", AH.Speech.PRIORITY_LOW)
        end
    end
end

local function BuildFrame()
    if built and frame then
        return frame
    end

    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, template)
    frame:SetSize(680, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    ApplyBlackBackdrop(frame)
    tinsert(UISpecialFrames, FRAME_NAME)

    local title = FontString(frame, 20, COL_TITLE[1], COL_TITLE[2], COL_TITLE[3], "OUTLINE")
    title:SetPoint("TOP", 0, -12)
    title:SetJustifyH("CENTER")
    title:SetText("Accessibility Helper")

    local subtitle = FontString(frame, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetJustifyH("CENTER")
    subtitle:SetText("Settings")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 10, -48)
    tabBar:SetPoint("BOTTOMLEFT", 10, 36)
    tabBar:SetWidth(150)
    PaintSolid(tabBar, 0.05, 0.05, 0.05, 1)

    local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "Scroll", frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", tabBar, "TOPRIGHT", 8, 0)
    scroll:SetPoint("BOTTOMRIGHT", -34, 36)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll() or 0
        local max = self:GetVerticalScrollRange() or 0
        local next = cur - (delta * 40)
        if next < 0 then
            next = 0
        elseif next > max then
            next = max
        end
        self:SetVerticalScroll(next)
    end)
    frame.scroll = scroll

    local checkboxes = {}
    local steppers = {}
    frame.tabs = {}
    frame.panels = {}

    local tabHeight = 30
    for i = 1, #TABS do
        local info = TABS[i]
        local tab = CreateFrame("Button", nil, tabBar)
        tab:SetSize(146, tabHeight)
        tab:SetPoint("TOPLEFT", 2, -2 - (i - 1) * (tabHeight + 2))
        PaintSolid(tab, COL_TAB[1], COL_TAB[2], COL_TAB[3], 1)

        local labelFs = FontString(tab, 13, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
        labelFs:SetPoint("LEFT", 8, 0)
        labelFs:SetText(info.label)
        tab.labelFs = labelFs

        tab:SetScript("OnClick", function()
            SelectTab(i)
        end)

        local panel = CreateFrame("Frame", nil, scroll)
        panel:SetSize(470, 400)
        panel:Hide()
        FillPanel(info.id, panel, checkboxes, steppers)

        frame.tabs[i] = tab
        frame.panels[i] = panel
    end

    local footer = FontString(frame, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    footer:SetPoint("BOTTOM", 0, 12)
    footer:SetJustifyH("CENTER")
    footer:SetText("/ah  ·  Esc to close  ·  Tabs on the left")

    frame.checkboxes = checkboxes
    frame.steppers = steppers
    frame:SetScript("OnShow", function(self)
        for i = 1, #self.checkboxes do
            if self.checkboxes[i].Refresh then
                self.checkboxes[i]:Refresh()
            end
        end
        if self.steppers then
            for i = 1, #self.steppers do
                if self.steppers[i].Refresh then
                    self.steppers[i].Refresh()
                end
            end
        end
        SelectTab(selectedTab or 1, true)
    end)
    frame:HookScript("OnHide", HideVoiceMenu)

    built = true
    SelectTab(1, true)
    return frame
end

function Settings.Toggle()
    local f = BuildFrame()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
        if AH.Speech and AH.Speech.Say then
            AH.Speech.Say("Accessibility Helper settings.", AH.Speech.PRIORITY_LOW)
        end
    end
end

function Settings.Open()
    local f = BuildFrame()
    if not f:IsShown() then
        f:Show()
        if AH.Speech and AH.Speech.Say then
            AH.Speech.Say("Accessibility Helper settings.", AH.Speech.PRIORITY_LOW)
        end
    end
end

function Settings.Close()
    if frame and frame:IsShown() then
        frame:Hide()
    end
end

function Settings.RefreshCheckboxes()
    if not frame or not frame.checkboxes then
        return
    end
    for i = 1, #frame.checkboxes do
        if frame.checkboxes[i].Refresh then
            frame.checkboxes[i]:Refresh()
        end
    end
end
