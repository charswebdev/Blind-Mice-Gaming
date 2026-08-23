--[[
  AllQuest — settings (tracker dark-glass theme)
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Settings = AQ.Settings or {}
local Settings = AQ.Settings

local FRAME_NAME = "AllQuestSettingsFrame"
local frame
local selectedTab = 1

local ROW_H = 30
local TAB_H = 32
local TAB_GAP = 6

local TABS = {
    { id = "commands", label = "Commands" },
    { id = "general", label = "General" },
    { id = "speech", label = "Speech" },
    { id = "tracker", label = "Tracker" },
    { id = "modules", label = "Modules" },
    { id = "plugins", label = "Plugins" },
    { id = "journal", label = "Journal" },
    { id = "profiles", label = "Profiles" },
}

local COMMAND_ROWS = {
    { "/aq", "Open settings" },
    { "/aqtrack", "Toggle the quest tracker" },
    { "/aqline", "Toggle the questline journal" },
    { "/aqread", "Read the focused tracker or journal row" },
    { "/aqhelp", "Print command list" },
    { "/aqstop", "Stop text to speech" },
    { "/aqtomtom", "TomTom waypoint for the super-tracked quest" },
    { "/aqbtw", "Open the super-tracked quest in BtWQuests" },
    { "/aqdebug", "Data recorder (see /aqdebug help)" },
}

local function DB()
    return AQ.DB.Get()
end

local function T()
    if AQ.Theme.TrackerTheme then
        return AQ.Theme.TrackerTheme()
    end
    return AQ.Theme.Tracker
end

local function ShowColorPicker(r, g, b, onChange)
    r = r or 1
    g = g or 1
    b = b or 1
    local function apply()
        local nr, ng, nb
        if ColorPickerFrame and ColorPickerFrame.GetColorRGB then
            nr, ng, nb = ColorPickerFrame:GetColorRGB()
        end
        if type(nr) == "number" then
            onChange(nr, ng, nb)
        end
    end
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            hasOpacity = false,
            swatchFunc = apply,
            cancelFunc = function()
                onChange(r, g, b)
            end,
        })
        return
    end
    if not ColorPickerFrame then
        return
    end
    ColorPickerFrame.func = apply
    ColorPickerFrame.swatchFunc = apply
    ColorPickerFrame.cancelFunc = function()
        onChange(r, g, b)
    end
    if ColorPickerFrame.SetColorRGB then
        ColorPickerFrame:SetColorRGB(r, g, b)
    end
    ColorPickerFrame:Show()
end

local function Rebuild()
    if frame and frame.AQRebuild then
        frame.AQRebuild()
    end
end

local function RefreshUI()
    if AQ.Tracker and AQ.Tracker.Refresh then
        AQ.Tracker.Refresh()
    end
    if AQ.Journal and AQ.Journal.Refresh then
        AQ.Journal.Refresh()
    end
    if AQ.MinimapButton then
        AQ.MinimapButton.Update()
    end
    if AQ.HideBlizzard then
        AQ.HideBlizzard.Apply()
    end
end

local function HoverSpeak(frame, getter)
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(frame, getter)
    end
end

local pendingPlugin
local pendingPack

local function ReloadForPlugin(id, on)
    pendingPlugin = { id = id, on = on }
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["ALLQUEST_PLUGIN_RELOAD"] = {
        text = "Reload the UI so this plugin change is saved and takes effect?",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function()
            local p = pendingPlugin
            pendingPlugin = nil
            if p then
                if AQ.Plugins and AQ.Plugins.SetEnabled then
                    AQ.Plugins.SetEnabled(p.id, p.on)
                else
                    local db = DB()
                    db.plugins = db.plugins or {}
                    db.plugins[p.id] = p.on and true or false
                end
            end
            ReloadUI()
        end,
        OnCancel = function()
            pendingPlugin = nil
            Rebuild()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    if StaticPopup_Show then
        pcall(StaticPopup_Show, "ALLQUEST_PLUGIN_RELOAD")
    else
        StaticPopupDialogs["ALLQUEST_PLUGIN_RELOAD"].OnAccept()
    end
end

local function ReloadForPack(addon, on)
    pendingPack = { addon = addon, on = on }
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["ALLQUEST_DATAPACK_RELOAD"] = {
        text = "Reload the UI so this expansion data change is saved and takes effect?",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function()
            local p = pendingPack
            pendingPack = nil
            if p and AQ.Data and AQ.Data.SetPackEnabled then
                AQ.Data.SetPackEnabled(p.addon, p.on)
            end
            ReloadUI()
        end,
        OnCancel = function()
            pendingPack = nil
            Rebuild()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    if StaticPopup_Show then
        pcall(StaticPopup_Show, "ALLQUEST_DATAPACK_RELOAD")
    else
        StaticPopupDialogs["ALLQUEST_DATAPACK_RELOAD"].OnAccept()
    end
end

local function PopupEditBox(popup)
    if not popup then
        return nil
    end
    return popup.EditBox or popup.editBox or (popup.GetName and _G[popup:GetName() .. "EditBox"])
end

local pendingNameCb
local pendingNameSeed
local pendingDeleteProfile
local shareFrame

local function ActionButton(parent, text, width)
    local btn = AQ.Widgets.TrackerButton(parent, text, width or 72, 26, 12)
    local fill = btn:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(1, 0.92, 0.4, 0.18)
    btn.AQFill = fill
    HoverSpeak(btn, text)
    return btn
end

local function SetActionEnabled(btn, enabled)
    if enabled then
        btn:EnableMouse(true)
        if btn.Label then
            local a = T().header
            btn.Label:SetTextColor(a[1], a[2], a[3], 1)
        end
        if btn.AQFill then
            btn.AQFill:SetColorTexture(1, 0.92, 0.4, 0.18)
        end
    else
        btn:EnableMouse(false)
        if btn.Label then
            btn.Label:SetTextColor(0.4, 0.4, 0.4, 1)
        end
        if btn.AQFill then
            btn.AQFill:SetColorTexture(0.2, 0.2, 0.2, 0.2)
        end
    end
end

local function AskProfileName(title, seed, callback)
    pendingNameCb = callback
    pendingNameSeed = seed or ""
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["ALLQUEST_PROFILE_NAME"] = {
        text = title or "Profile name:",
        button1 = OKAY or "OK",
        button2 = CANCEL or "Cancel",
        hasEditBox = 1,
        maxLetters = 40,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
        OnShow = function(self)
            local box = PopupEditBox(self)
            if box then
                box:SetText(pendingNameSeed or "")
                box:HighlightText()
                box:SetFocus()
            end
        end,
        OnAccept = function(self)
            local box = PopupEditBox(self)
            local typed = box and box.GetText and box:GetText() or ""
            local cb = pendingNameCb
            pendingNameCb = nil
            if type(cb) == "function" then
                cb(typed)
            end
        end,
        OnCancel = function()
            pendingNameCb = nil
        end,
        EditBoxOnEnterPressed = function(self)
            local parent = self:GetParent()
            StaticPopupDialogs["ALLQUEST_PROFILE_NAME"].OnAccept(parent)
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            self:GetParent():Hide()
        end,
    }
    if StaticPopup_Show then
        pcall(StaticPopup_Show, "ALLQUEST_PROFILE_NAME")
    end
end

local function ConfirmReload(message, fn)
    StaticPopupDialogs = StaticPopupDialogs or {}
    StaticPopupDialogs["ALLQUEST_PROFILE_RELOAD"] = {
        text = message or "Reload the UI to apply this profile?",
        button1 = YES or "Yes",
        button2 = NO or "No",
        OnAccept = function()
            if type(fn) == "function" then
                fn()
            end
            ReloadUI()
        end,
        OnCancel = function()
            Rebuild()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
    if StaticPopup_Show then
        pcall(StaticPopup_Show, "ALLQUEST_PROFILE_RELOAD")
    else
        fn()
        ReloadUI()
    end
end

local function EnsureShareFrame()
    if shareFrame then
        return shareFrame
    end
    local f = CreateFrame("Frame", "AllQuestProfileShareFrame", UIParent, "BackdropTemplate")
    f:SetSize(520, 380)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    f:Hide()
    tinsert(UISpecialFrames, "AllQuestProfileShareFrame")
    AQ.Widgets.ApplyTrackerBackdrop(f)

    local a = T().header
    local titleHit = CreateFrame("Frame", nil, f)
    titleHit:SetPoint("TOPLEFT", 16, -8)
    titleHit:SetPoint("TOPRIGHT", -40, -8)
    titleHit:SetHeight(24)
    titleHit:EnableMouse(true)
    local title = AQ.Widgets.TrackerFontString(titleHit, 16, a[1], a[2], a[3])
    title:SetPoint("LEFT", 0, 0)
    title:SetPoint("RIGHT", 0, 0)
    f.Title = title
    HoverSpeak(titleHit, function()
        return (f.Title and f.Title:GetText()) or "Profile"
    end)

    local close = AQ.Widgets.TrackerButton(f, "x", 20, 22)
    close:SetPoint("TOPRIGHT", -12, -12)
    close:SetScript("OnClick", function()
        f:Hide()
    end)
    HoverSpeak(close, "Close")

    local o = T().objective
    local noteHit = CreateFrame("Frame", nil, f)
    noteHit:SetPoint("TOPLEFT", 16, -36)
    noteHit:SetPoint("TOPRIGHT", -16, -36)
    noteHit:SetHeight(28)
    noteHit:EnableMouse(true)
    local note = AQ.Widgets.TrackerFontString(noteHit, 12, o[1], o[2], o[3])
    note:SetPoint("TOPLEFT", 0, 0)
    note:SetPoint("TOPRIGHT", 0, 0)
    note:SetWordWrap(true)
    f.Note = note
    HoverSpeak(noteHit, function()
        return (f.Note and f.Note:GetText()) or ""
    end)

    local scroll
    local okScroll, created = pcall(CreateFrame, "ScrollFrame", "AllQuestProfileShareScroll", f, "UIPanelScrollFrameTemplate")
    if okScroll then
        scroll = created
    else
        scroll = CreateFrame("ScrollFrame", "AllQuestProfileShareScroll", f)
    end
    scroll:SetPoint("TOPLEFT", 16, -72)
    scroll:SetPoint("BOTTOMRIGHT", -36, 56)
    local edit = CreateFrame("EditBox", "AllQuestProfileShareEdit", scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    if edit.SetMaxLetters then
        edit:SetMaxLetters(0)
    end
    local path = AQ.Theme and AQ.Theme.FontPath and AQ.Theme.FontPath()
    if path then
        edit:SetFont(path, 12, "")
    else
        edit:SetFontObject(ChatFontNormal)
    end
    edit:SetTextColor(1, 1, 1, 1)
    edit:SetWidth(450)
    edit:SetHeight(2000)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)
    scroll:SetScrollChild(edit)
    f.Edit = edit
    f.Scroll = scroll

    local action = ActionButton(f, "Copy", 90)
    action:SetPoint("BOTTOMLEFT", 16, 16)
    f.Action = action
    local cancel = ActionButton(f, "Close", 90)
    cancel:SetPoint("LEFT", action, "RIGHT", 8, 0)
    cancel:SetScript("OnClick", function()
        f:Hide()
    end)
    shareFrame = f
    return f
end

local function ShowExport(name)
    local text = AQ.DB.ExportProfile and AQ.DB.ExportProfile(name)
    if type(text) ~= "string" then
        AQ:Print("Could not export that profile.")
        return
    end
    local f = EnsureShareFrame()
    f.Title:SetText("Export profile")
    f.Note:SetText("Copy this string. Another player can Import it in AllQuest settings.")
    f.Edit:SetText(text)
    f.Edit:HighlightText()
    f.Edit:SetFocus()
    f.Action.Label:SetText("Copy")
    f.Action:SetScript("OnClick", function()
        if CopyToClipboard then
            pcall(CopyToClipboard, f.Edit:GetText() or text)
        end
        f.Edit:HighlightText()
        AQ:Print("Profile string copied.")
        if AQ.Speech then
            AQ.Speech.Say("Profile copied")
        end
    end)
    f:Show()
    if CopyToClipboard then
        pcall(CopyToClipboard, text)
    end
end

local function ShowImport()
    local f = EnsureShareFrame()
    f.Title:SetText("Import profile")
    f.Note:SetText("Paste an AllQuest profile string, then click Import.")
    f.Edit:SetText("")
    f.Edit:SetFocus()
    f.Action.Label:SetText("Import")
    f.Action:SetScript("OnClick", function()
        local raw = f.Edit:GetText() or ""
        local ok, result = AQ.DB.ImportProfile(raw)
        if not ok then
            AQ:Print(result or "Import failed.")
            if AQ.Speech then
                AQ.Speech.Say("Import failed")
            end
            return
        end
        f:Hide()
        AQ:Print("Imported profile " .. tostring(result) .. ".")
        if AQ.Speech then
            AQ.Speech.Say("Profile imported")
        end
        Rebuild()
    end)
    f:Show()
end

local function Gold()
    local a = T().header
    return a[1], a[2], a[3]
end

local function TitleCol()
    local a = T().title
    return a[1], a[2], a[3]
end

local function ObjCol()
    local a = T().objective
    return a[1], a[2], a[3]
end

local function AddRule(parent, y)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    local rc = T().rule
    rule:SetColorTexture(rc[1], rc[2], rc[3], rc[4] or 0.35)
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 16, y)
    rule:SetPoint("TOPRIGHT", -16, y)
    return y - 14
end

local function HoverRow(row)
    local bg = row:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:Hide()
    row.Hover = bg
    row:SetScript("OnEnter", function(self)
        local h = T().hover
        self.Hover:SetColorTexture(h[1], h[2], h[3], h[4] or 0.1)
        self.Hover:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.Hover:Hide()
    end)
end

local function MakeCheck(parent, label, key, getter, setter, disabled, hint)
    local hasHint = type(hint) == "string" and hint ~= ""
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(hasHint and 52 or ROW_H)
    HoverRow(row)

    local box = row:CreateTexture(nil, "ARTWORK")
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 16, hasHint and 6 or 0)
    box:SetColorTexture(0.08, 0.08, 0.08, 0.55)
    row.Box = box

    local edge = row:CreateTexture(nil, "BORDER")
    edge:SetSize(18, 18)
    edge:SetPoint("CENTER", box, "CENTER", 0, 0)
    edge:SetColorTexture(0.38, 0.38, 0.38, 1)
    row.Edge = edge
    box:SetDrawLayer("ARTWORK", 1)

    local mark = row:CreateTexture(nil, "OVERLAY")
    mark:SetSize(10, 10)
    mark:SetPoint("CENTER", box, "CENTER", 0, 0)
    local gr, gg, gb = Gold()
    mark:SetColorTexture(gr, gg, gb, 1)
    row.Mark = mark

    local fs = AQ.Widgets.TrackerFontString(row, 13, TitleCol())
    fs:SetPoint("LEFT", 44, hasHint and 8 or 0)
    fs:SetPoint("RIGHT", -16, 0)
    fs:SetText(label)
    row.Label = fs

    if hasHint then
        local hintFS = AQ.Widgets.TrackerFontString(row, 11, ObjCol())
        hintFS:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
        hintFS:SetPoint("RIGHT", -16, 0)
        hintFS:SetWordWrap(true)
        if hintFS.SetMaxLines then
            hintFS:SetMaxLines(2)
        end
        hintFS:SetText(hint)
        row.Hint = hintFS
        if disabled then
            hintFS:SetTextColor(0.45, 0.45, 0.45, 1)
        end
    end

    if disabled then
        row.Label:SetTextColor(0.5, 0.5, 0.5, 1)
        row.Edge:SetColorTexture(0.28, 0.28, 0.28, 1)
        row.Box:SetColorTexture(0.05, 0.05, 0.05, 0.4)
        row.Mark:SetColorTexture(0.45, 0.45, 0.45, 1)
    end

    local function On()
        if getter then
            return getter() and true or false
        end
        return DB()[key] and true or false
    end

    local function Sync()
        local on = On()
        row.Mark:SetShown(on)
        if disabled then
            row.Label:SetTextColor(0.5, 0.5, 0.5, 1)
        else
            row.Label:SetTextColor(TitleCol())
        end
    end

    if not disabled then
        row:SetScript("OnClick", function()
            local nextv = not On()
            if setter then
                setter(nextv)
            else
                DB()[key] = nextv
            end
            Sync()
            RefreshUI()
        end)
    end
    HoverSpeak(row, function()
        local state = On() and "on" or "off"
        if disabled then
            state = "unavailable"
        end
        local text = label .. ". " .. state
        if hasHint then
            text = text .. ". " .. hint
        end
        return text
    end)
    row.Sync = Sync
    Sync()
    return row
end

local function Clamp(v, lo, hi)
    if v < lo then
        return lo
    end
    if v > hi then
        return hi
    end
    return v
end

local function MakeStepper(parent, label, getter, setter, minV, maxV, step, fmt)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(48)

    local name = AQ.Widgets.TrackerFontString(row, 13, TitleCol())
    name:SetPoint("LEFT", 16, 0)
    name:SetText(label)

    local function StyleStep(btn)
        local fill = btn:CreateTexture(nil, "BACKGROUND")
        fill:SetAllPoints()
        fill:SetColorTexture(1, 0.92, 0.4, 0.22)
        btn.AQFill = fill
        if btn.SetHitRectInsets then
            btn:SetHitRectInsets(-4, -4, -4, -4)
        end
    end

    local plus = AQ.Widgets.TrackerButton(row, "+", 40, 40, 22)
    plus:SetPoint("RIGHT", -16, 0)
    StyleStep(plus)
    local valueFS = AQ.Widgets.TrackerFontString(row, 18, Gold())
    valueFS:SetWidth(72)
    valueFS:SetJustifyH("CENTER")
    valueFS:SetPoint("RIGHT", plus, "LEFT", -10, 0)
    local minus = AQ.Widgets.TrackerButton(row, "-", 40, 40, 22)
    minus:SetPoint("RIGHT", valueFS, "LEFT", -10, 0)
    StyleStep(minus)

    local function Sync()
        valueFS:SetText(string.format(fmt or "%s", getter()))
    end
    minus:SetScript("OnClick", function()
        setter(Clamp(getter() - step, minV, maxV))
        Sync()
        RefreshUI()
    end)
    plus:SetScript("OnClick", function()
        setter(Clamp(getter() + step, minV, maxV))
        Sync()
        RefreshUI()
    end)
    HoverSpeak(row, function()
        return label .. ". " .. string.format(fmt or "%s", getter())
    end)
    HoverSpeak(minus, function()
        return "Decrease " .. label .. ". " .. string.format(fmt or "%s", getter())
    end)
    HoverSpeak(plus, function()
        return "Increase " .. label .. ". " .. string.format(fmt or "%s", getter())
    end)
    Sync()
    return row
end

local function BuildTabContent(parent, tabID)
    if AQ.Widgets and AQ.Widgets.CloseDropdown then
        AQ.Widgets.CloseDropdown()
    end
    if parent.Inner then
        parent.Inner:Hide()
        parent.Inner:SetParent(nil)
    end
    local inner = CreateFrame("Frame", nil, parent)
    inner:SetPoint("TOPLEFT")
    inner:SetPoint("TOPRIGHT")
    parent.Inner = inner

    local y = -12
    local function Place(row)
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("RIGHT", inner, "RIGHT", 0, 0)
        y = y - ((row.GetHeight and row:GetHeight() or ROW_H) + 6)
    end
    local function Section(text)
        y = y - 18
        local wrap = CreateFrame("Frame", nil, inner)
        wrap:SetHeight(22)
        wrap:EnableMouse(true)
        local fs = AQ.Widgets.TrackerFontString(wrap, 14, Gold())
        fs:SetPoint("TOPLEFT", 16, 0)
        fs:SetPoint("RIGHT", -16, 0)
        fs:SetText(text)
        HoverSpeak(wrap, text .. " heading")
        Place(wrap)
        y = AddRule(inner, y)
    end
    local function Note(text, height)
        local wrap = CreateFrame("Frame", nil, inner)
        wrap:SetHeight(height or 56)
        wrap:EnableMouse(true)
        local fs = AQ.Widgets.TrackerFontString(wrap, 12, ObjCol())
        fs:SetPoint("TOPLEFT", 16, 0)
        fs:SetPoint("TOPRIGHT", -16, 0)
        fs:SetWordWrap(true)
        if fs.SetMaxLines then
            fs:SetMaxLines(8)
        end
        fs:SetText(text)
        HoverSpeak(wrap, text)
        Place(wrap)
    end
    local function RowCheck(label, key, getter, setter, disabled, hint)
        Place(MakeCheck(inner, label, key, getter, setter, disabled, hint))
    end
    local function RowStepper(label, getter, setter, minV, maxV, step, fmt)
        Place(MakeStepper(inner, label, getter, setter, minV, maxV, step, fmt))
    end
    local function FilterGet(key)
        return function()
            local f = DB().filters or {}
            return f[key] and true or false
        end
    end
    local function FilterSet(key)
        return function(v)
            DB().filters = DB().filters or {}
            DB().filters[key] = v and true or false
        end
    end

    if tabID == "commands" then
        Section("Slash commands")
        for i = 1, #COMMAND_ROWS do
            local row = CreateFrame("Frame", nil, inner)
            row:SetHeight(ROW_H)
            local cmd = AQ.Widgets.TrackerFontString(row, 13, Gold())
            cmd:SetPoint("LEFT", 16, 0)
            cmd:SetWidth(130)
            cmd:SetText(COMMAND_ROWS[i][1])
            local desc = AQ.Widgets.TrackerFontString(row, 13, TitleCol())
            desc:SetPoint("LEFT", 154, 0)
            desc:SetPoint("RIGHT", -16, 0)
            desc:SetText(COMMAND_ROWS[i][2])
            row:EnableMouse(true)
            HoverSpeak(row, COMMAND_ROWS[i][1] .. ". " .. COMMAND_ROWS[i][2])
            Place(row)
        end
        y = y - 16
        Note("Left-click a quest, pet, or rare to set a TomTom arrow. Right-click a tracker row for Super Track, quest log, map, share, abandon, Wowhead, TomTom, and BtWQuests.", 72)
    elseif tabID == "general" then
        Section("Display")
        RowCheck("Show minimap button", "minimapButtonEnabled")
        RowCheck("Hide Blizzard objective tracker", "hideBlizzardTracker")
        RowStepper("UI font scale", function()
            return DB().fontScale or 1
        end, function(v)
            DB().fontScale = v
        end, 0.8, 2.0, 0.1, "%.1f")
        y = y - 16
        Note("AllQuest is a custom tracker. It does not skin Blizzard frames.", 48)
    elseif tabID == "tracker" then
        Section("Window")
        RowCheck("Enable tracker", "trackerEnabled")
        RowCheck("Lock tracker position and size", "trackerLocked")
        RowCheck("Hide tracker when empty", "trackerHideEmpty")
        RowCheck("Collapse tracker in instances", "trackerCollapseInInstance")
        Section("Quests")
        RowCheck("Auto-watch accepted quests", "trackerAutoWatch")
        RowCheck("Auto-accept quests from NPCs", "autoQuestAccept")
        RowCheck("Auto-turn-in quests at NPCs", "autoQuestTurnIn")
        RowCheck("Show accept / complete / turn-in messages", "autoQuestNotify")
        RowCheck("Show completed objectives", "trackerShowCompletedObjectives")
        Section("Colors")
        Note("Section titles use a colored underline and a + / - on the right. Quest titles stay gold unless you color them by difficulty. The super-tracked quest is pink. AllQuest icons stay on the left. Click a swatch to pick a color.", 72)
        RowCheck(
            "Color objectives by progress",
            "trackerObjectiveProgressColors",
            nil,
            nil,
            nil,
            "The whole line goes red to yellow to green as the count fills, like Questie."
        )
        RowCheck(
            "Color quest names by difficulty",
            "trackerDifficultyColors",
            nil,
            nil,
            nil,
            "Grey, green, yellow, orange, and red like the quest log. Tracked quests stay the tracked color."
        )
        do
            local COLOR_ROWS = {
                { key = "header", label = "Section titles" },
                { key = "rule", label = "Section underline" },
                { key = "title", label = "Quest titles" },
                { key = "tracked", label = "Tracked quest" },
                { key = "objective", label = "Objectives" },
                { key = "complete", label = "Completed" },
                { key = "collapse", label = "Collapse + / -" },
                { key = "bg", label = "Background" },
            }
            local function ColorRow(spec)
                local row = CreateFrame("Button", nil, inner)
                row:SetHeight(ROW_H)
                HoverRow(row)
                local swatch = row:CreateTexture(nil, "ARTWORK")
                swatch:SetSize(18, 18)
                swatch:SetPoint("LEFT", 16, 0)
                local c = AQ.Theme.GetTrackerColor and AQ.Theme.GetTrackerColor(spec.key) or { 1, 1, 1, 1 }
                swatch:SetColorTexture(c[1], c[2], c[3], 1)
                local edge = row:CreateTexture(nil, "BORDER")
                edge:SetPoint("TOPLEFT", swatch, -1, 1)
                edge:SetPoint("BOTTOMRIGHT", swatch, 1, -1)
                edge:SetColorTexture(1, 1, 1, 0.35)
                local fs = AQ.Widgets.TrackerFontString(row, 13, TitleCol())
                fs:SetPoint("LEFT", swatch, "RIGHT", 10, 0)
                fs:SetPoint("RIGHT", -16, 0)
                fs:SetText(spec.label)
                row:SetScript("OnClick", function()
                    local cur = AQ.Theme.GetTrackerColor(spec.key)
                    ShowColorPicker(cur[1], cur[2], cur[3], function(nr, ng, nb)
                        AQ.Theme.SetTrackerColor(spec.key, nr, ng, nb, cur[4] or 1)
                        swatch:SetColorTexture(nr, ng, nb, 1)
                        RefreshUI()
                    end)
                end)
                HoverSpeak(row, spec.label .. " color")
                Place(row)
            end
            for i = 1, #COLOR_ROWS do
                ColorRow(COLOR_ROWS[i])
            end
            local resetRow = CreateFrame("Frame", nil, inner)
            resetRow:SetHeight(34)
            local reset = ActionButton(resetRow, "Reset colors", 140)
            reset:SetPoint("LEFT", 16, 0)
            reset:SetScript("OnClick", function()
                if AQ.Theme.ResetTrackerColors then
                    AQ.Theme.ResetTrackerColors()
                end
                RefreshUI()
                Rebuild()
            end)
            HoverSpeak(reset, "Reset tracker colors")
            Place(resetRow)
        end
        Section("Sounds")
        RowCheck(
            "Play a sound when a quest is complete",
            "soundQuest",
            nil,
            nil,
            nil,
            "Uses the complete voices listed under Media."
        )
        do
            local soundItems = {}
            local sounds = AQ.Sounds and AQ.Sounds.List and AQ.Sounds.List() or {}
            for i = 1, #sounds do
                soundItems[i] = { text = sounds[i].id, value = sounds[i].id }
            end
            local soundWrap = CreateFrame("Frame", nil, inner)
            soundWrap:SetHeight(22)
            soundWrap:EnableMouse(true)
            local soundLabel = AQ.Widgets.TrackerFontString(soundWrap, 13, Gold())
            soundLabel:SetPoint("LEFT", 16, 0)
            soundLabel:SetText("Complete sound")
            HoverSpeak(soundWrap, "Complete sound heading")
            Place(soundWrap)

            local soundRow = CreateFrame("Frame", nil, inner)
            soundRow:SetHeight(34)
            local play = ActionButton(soundRow, "Play", 56)
            play:SetPoint("RIGHT", -16, 0)
            local soundDrop = AQ.Widgets.Dropdown(soundRow, { width = 240, height = 32, placeholder = "Complete sound" })
            soundDrop:SetPoint("LEFT", 16, 0)
            soundDrop:SetPoint("RIGHT", play, "LEFT", -8, 0)
            soundDrop:SetItems(soundItems)
            soundDrop:SetValue(DB().soundQuestComplete or "Default")
            soundDrop:SetCallback(function(value)
                DB().soundQuestComplete = value
                if AQ.Sounds and AQ.Sounds.Play then
                    AQ.Sounds.Play(value, DB().soundChannel or "Master")
                end
            end)
            play:SetScript("OnClick", function()
                if AQ.Sounds and AQ.Sounds.Play then
                    AQ.Sounds.Play(DB().soundQuestComplete or "Default", DB().soundChannel or "Master")
                end
            end)
            HoverSpeak(soundDrop, function()
                return "Complete sound. " .. tostring(DB().soundQuestComplete or "Default")
            end)
            Place(soundRow)

            local chanItems = {}
            local chans = AQ.Sounds and AQ.Sounds.Channels and AQ.Sounds.Channels() or {}
            for i = 1, #chans do
                chanItems[i] = { text = chans[i].label, value = chans[i].id }
            end
            local chanWrap = CreateFrame("Frame", nil, inner)
            chanWrap:SetHeight(22)
            chanWrap:EnableMouse(true)
            local chanLabel = AQ.Widgets.TrackerFontString(chanWrap, 13, Gold())
            chanLabel:SetPoint("LEFT", 16, 0)
            chanLabel:SetText("Sound channel")
            HoverSpeak(chanWrap, "Sound channel heading")
            Place(chanWrap)

            local chanRow = CreateFrame("Frame", nil, inner)
            chanRow:SetHeight(34)
            local chanDrop = AQ.Widgets.Dropdown(chanRow, { width = 240, height = 32, placeholder = "Sound channel" })
            chanDrop:SetPoint("LEFT", 16, 0)
            chanDrop:SetItems(chanItems)
            chanDrop:SetValue(DB().soundChannel or "Master")
            chanDrop:SetCallback(function(value)
                DB().soundChannel = value
            end)
            HoverSpeak(chanDrop, function()
                return "Sound channel. " .. tostring(DB().soundChannel or "Master")
            end)
            Place(chanRow)
        end
        Section("Items")
        RowCheck("Show quest item buttons", "trackerShowItemButtons")
        RowCheck("Show closest-quest extra item button", "trackerShowClosestItem")
        Section("Filters")
        RowCheck("Hide completed quests", "hideComplete", FilterGet("hideComplete"), FilterSet("hideComplete"))
        RowCheck("Hide daily quests", "hideDaily", FilterGet("hideDaily"), FilterSet("hideDaily"))
        RowCheck("Hide weekly quests", "hideWeekly", FilterGet("hideWeekly"), FilterSet("hideWeekly"))
        y = y - 16
        Note("Unlock the tracker to drag it, or drag the bottom-right corner to resize. Hold Shift at an NPC to skip auto-accept and auto-turn-in.", 72)
    elseif tabID == "modules" then
        Section("Tracker blocks")
        Note("Each checkbox is a block in the AllQuest tracker. Uncheck a block to hide it. Empty blocks hide themselves. Use Up and Down to change the order they appear. Other addons are turned on in the Plugins tab.", 96)

        local MODULE_HELP = {
            popups = {
                title = "Accept & turn-in",
                desc = "Quests waiting at an NPC. Left-click the tracker row to accept or complete.",
            },
            scenarios = {
                title = "Instance",
                desc = "Delve, dungeon, raid, scenario, and Mythic+ block while you are inside. Title, tier or difficulty, lives, gold-bullet objectives, and a progress bar.",
            },
            campaigns = {
                title = "Campaigns",
                desc = "Campaign chapters and the quests that belong to them.",
            },
            quests = {
                title = "Quests",
                desc = "Watched quests, grouped by zone.",
            },
            worldquests = {
                title = "World Quests",
                desc = "World quests and bonus objectives on your current map.",
            },
            achievements = {
                title = "Achievements",
                desc = "Achievements you chose to track in the Achievement journal.",
            },
            recipes = {
                title = "Professions",
                desc = "Crafting recipes you marked to track.",
            },
            activities = {
                title = "Activities",
                desc = "Tracked activities such as delves and other content goals.",
            },
            collectibles = {
                title = "Collectibles",
                desc = "Tracked collectible items and appearances.",
            },
            rares = {
                title = "Rares",
                desc = "Nearby rares from the map. Left-click sets a TomTom arrow. RareScanner and SilverDragon add extra finds if those plugins are on.",
            },
            pets = {
                title = "Pets",
                desc = "Battle pets in this zone. Left-click sets a TomTom arrow. PetTracker or Battle Pet Completionist add extra zone lists if those plugins are on.",
            },
            questcompletist = {
                title = "QuestCompletist",
                desc = "Incomplete quests in this zone from QuestCompletist. Needs that plugin.",
            },
        }

        local function PluginAddonLoaded(pluginId)
            local pspec = AQ.Plugins and AQ.Plugins.Get and AQ.Plugins.Get(pluginId)
            local name = pspec and pspec.optionalAddon or pluginId
            return AQ:AddonLoaded(name) and true or false, name
        end

        local function ModuleLocked(spec)
            if spec.requiresAddon and not AQ:AddonLoaded(spec.requiresAddon) then
                return true
            end
            if spec.requiresPlugin then
                local loaded = PluginAddonLoaded(spec.requiresPlugin)
                if not loaded then
                    return true
                end
            end
            if type(spec.requiresAnyPlugin) == "table" then
                local any = false
                for i = 1, #spec.requiresAnyPlugin do
                    if PluginAddonLoaded(spec.requiresAnyPlugin[i]) then
                        any = true
                        break
                    end
                end
                if not any then
                    return true
                end
            end
            return false
        end

        local function SetOrderBtn(btn, enabled)
            if enabled then
                btn:EnableMouse(true)
                if btn.Label then
                    local a = T().header
                    btn.Label:SetTextColor(a[1], a[2], a[3], 1)
                end
                if btn.AQFill then
                    btn.AQFill:SetColorTexture(1, 0.92, 0.4, 0.18)
                end
            else
                btn:EnableMouse(false)
                if btn.Label then
                    btn.Label:SetTextColor(0.4, 0.4, 0.4, 1)
                end
                if btn.AQFill then
                    btn.AQFill:SetColorTexture(0.2, 0.2, 0.2, 0.2)
                end
            end
        end

        local function OrderBtn(parent, text)
            local btn = AQ.Widgets.TrackerButton(parent, text, 46, 28, 12)
            local fill = btn:CreateTexture(nil, "BACKGROUND")
            fill:SetAllPoints()
            fill:SetColorTexture(1, 0.92, 0.4, 0.18)
            btn.AQFill = fill
            HoverSpeak(btn, text)
            return btn
        end

        local function AddModule(spec, index, total)
            local id = spec.id
            local help = MODULE_HELP[id] or {}
            local label = help.title or spec.title or id
            local hint = help.desc or "Show this block in the tracker."
            local locked = ModuleLocked(spec)
            if locked then
                hint = hint .. "  (addon not installed)"
            end

            local wrap = CreateFrame("Frame", nil, inner)
            wrap:SetHeight(52)

            local down = OrderBtn(wrap, "Down")
            down:SetPoint("RIGHT", -16, 0)
            local up = OrderBtn(wrap, "Up")
            up:SetPoint("RIGHT", down, "LEFT", -6, 0)
            SetOrderBtn(up, index > 1)
            SetOrderBtn(down, index < total)
            up:SetScript("OnClick", function()
                if AQ.Tracker and AQ.Tracker.MoveModule then
                    AQ.Tracker.MoveModule(id, "up")
                end
                RefreshUI()
                Rebuild()
            end)
            down:SetScript("OnClick", function()
                if AQ.Tracker and AQ.Tracker.MoveModule then
                    AQ.Tracker.MoveModule(id, "down")
                end
                RefreshUI()
                Rebuild()
            end)

            local check = MakeCheck(wrap, label, "modules:" .. id, function()
                if locked then
                    return false
                end
                local m = DB().modules or {}
                return m[id] ~= false
            end, function(v)
                if locked then
                    return
                end
                DB().modules = DB().modules or {}
                DB().modules[id] = v and true or false
            end, locked, hint)
            check:SetPoint("TOPLEFT")
            check:SetPoint("BOTTOMLEFT")
            check:SetPoint("RIGHT", up, "LEFT", -8, 0)
            Place(wrap)
        end

        local list = AQ.Tracker and AQ.Tracker.GetModuleList and AQ.Tracker.GetModuleList() or {}
        for i = 1, #list do
            AddModule(list[i], i, #list)
        end

        local resetRow = CreateFrame("Frame", nil, inner)
        resetRow:SetHeight(36)
        local reset = OrderBtn(resetRow, "Reset order")
        reset:SetWidth(120)
        reset:SetPoint("LEFT", 16, 0)
        reset:SetScript("OnClick", function()
            if AQ.Tracker and AQ.Tracker.ResetModuleOrder then
                AQ.Tracker.ResetModuleOrder()
            end
            RefreshUI()
            Rebuild()
        end)
        Place(resetRow)
        y = y - 8
        Note("Plugin blocks stay greyed out until that addon is installed and loaded. You can still move them in the list.", 56)
    elseif tabID == "plugins" then
        Section("Optional plugins")
        Note("Install an addon to enable its plugin. Missing addons stay greyed out. Turning a plugin on or off reloads the UI.", 56)
        local list = AQ.Plugins and AQ.Plugins.List and AQ.Plugins.List() or {}
        for i = 1, #list do
            local spec = list[i]
            if spec.id ~= "Conflicts" then
                local id = spec.id
                local display = spec.label or id
                local label = display
                local available = true
                if spec.optionalAddon then
                    available = AQ:AddonLoaded(spec.optionalAddon) and true or false
                    if available then
                        label = display .. "  (loaded)"
                    elseif AQ.Compat and AQ.Compat.DoesAddOnExist and AQ.Compat.DoesAddOnExist(spec.optionalAddon) then
                        label = display .. "  (not loaded)"
                    else
                        label = display .. "  (not installed)"
                    end
                end
                RowCheck(label, "plugins:" .. id, function()
                    if not available then
                        return false
                    end
                    if pendingPlugin and pendingPlugin.id == id then
                        return pendingPlugin.on and true or false
                    end
                    local p = DB().plugins or {}
                    return p[id] ~= false
                end, function(v)
                    if not available then
                        return
                    end
                    ReloadForPlugin(id, v)
                end, not available)
            end
        end
    elseif tabID == "journal" then
        Section("Questline journal")
        Note("Open with /aqline or the book icon on the tracker. Toolbar icons: Home, Back, Search, Grid/List, Here (jump to your zone), Zone dropdown, Close. Hover an icon or cover to hear its name. Keyboard: Up/Down select, Enter open, Backspace back. Escape backs up a folder, or closes at Home. Questlines stay a list. Status is spoken as DONE, ACTIVE, READY, LOCKED, or FAILED.", 140)
        Section("Expansion data")
        Note("Load questline packs the same way BtWQuests Auto Load works. Turning a pack on or off reloads the UI so the data can populate. Packs that are missing, disabled, or not for this client stay greyed out.", 72)
        local packs = AQ.Data and AQ.Data.ListPacks and AQ.Data.ListPacks() or {}
        for i = 1, #packs do
            local pack = packs[i]
            local addon = pack.addon
            local label = pack.name or addon
            local available = pack.canToggle and true or false
            if pack.loaded then
                label = label .. "  (loaded)"
            elseif not pack.installed then
                label = label .. "  (not installed)"
            elseif not pack.allowed then
                label = label .. "  (not for this client)"
            elseif not pack.enabledInList then
                label = label .. "  (disabled)"
            else
                label = label .. "  (not loaded)"
            end
            RowCheck(label, "datapack:" .. addon, function()
                if not available then
                    return false
                end
                if pendingPack and pendingPack.addon == addon then
                    return pendingPack.on and true or false
                end
                if AQ.Data and AQ.Data.IsPackEnabled then
                    return AQ.Data.IsPackEnabled(addon)
                end
                return false
            end, function(v)
                if not available then
                    return
                end
                ReloadForPack(addon, v)
            end, not available)
        end
    elseif tabID == "speech" then
        Section("Speech")
        RowCheck("Enable AllQuest speech", "speechEnabled")
        RowCheck("Speak tracker quests on hover", "speechOnSelect")
        RowCheck("Speak quest progress updates", "speechOnQuestProgress")
        RowStepper("Speech rate", function()
            return DB().ttsRate or 0
        end, function(v)
            DB().ttsRate = v
        end, -10, 10, 1, "%d")
        RowStepper("Speech volume", function()
            return DB().ttsVolume or 100
        end, function(v)
            DB().ttsVolume = v
        end, 0, 100, 10, "%d")
        y = y - 16
        Note("The tracker reads only the quest under the mouse, not the whole list. The journal still speaks the selected row. If Accessibility Helper is loaded, AllQuest uses its speech queue. Otherwise AllQuest uses Blizzard Text to Speech.", 72)
    elseif tabID == "profiles" then
        Section("Profiles")
        local current = AQ.DB.GetActiveName and AQ.DB.GetActiveName() or "Default"
        Note("A profile stores your AllQuest settings. Each character can use a different profile. Switching profiles reloads the UI.", 72)

        local names = AQ.DB.ListProfiles and AQ.DB.ListProfiles() or { current }
        local profileItems = {}
        for i = 1, #names do
            local name = names[i]
            local text = name
            if name == current then
                text = name .. "  (in use)"
            end
            profileItems[i] = { text = text, value = name }
        end

        local pickWrap = CreateFrame("Frame", nil, inner)
        pickWrap:SetHeight(22)
        pickWrap:EnableMouse(true)
        local pickLabel = AQ.Widgets.TrackerFontString(pickWrap, 13, Gold())
        pickLabel:SetPoint("LEFT", 16, 0)
        pickLabel:SetText("Active profile")
        HoverSpeak(pickWrap, "Active profile heading")
        Place(pickWrap)

        local dropRow = CreateFrame("Frame", nil, inner)
        dropRow:SetHeight(34)
        local profileDrop = AQ.Widgets.Dropdown(dropRow, { width = 280, height = 32, placeholder = "Select profile" })
        profileDrop:SetPoint("LEFT", 16, 0)
        profileDrop:SetItems(profileItems)
        profileDrop:SetValue(current)
        HoverSpeak(profileDrop, function()
            return "Active profile dropdown. " .. tostring(current)
        end)
        profileDrop:SetCallback(function(name)
            if name == current then
                return
            end
            ConfirmReload("Reload the UI to switch to profile \"" .. tostring(name) .. "\"?", function()
                AQ.DB.UseProfile(name)
            end)
        end)
        Place(dropRow)
        y = y - 4

        local actions = CreateFrame("Frame", nil, inner)
        actions:SetHeight(36)
        local createBtn = ActionButton(actions, "Create Profile", 130)
        createBtn:SetPoint("LEFT", 16, 0)
        createBtn:SetScript("OnClick", function()
            AskProfileName("Name for the new profile:", "", function(typed)
                local ok, result = AQ.DB.CreateProfile(typed)
                if not ok then
                    AQ:Print(result or "Could not create profile.")
                    if AQ.Speech then
                        AQ.Speech.Say("Could not create profile")
                    end
                    return
                end
                AQ:Print("Created profile " .. tostring(result) .. ".")
                if AQ.Speech then
                    AQ.Speech.Say("Profile created")
                end
                RefreshUI()
                Rebuild()
            end)
        end)
        local importBtn = ActionButton(actions, "Import Profile", 130)
        importBtn:SetPoint("LEFT", createBtn, "RIGHT", 8, 0)
        importBtn:SetScript("OnClick", function()
            ShowImport()
        end)
        Place(actions)

        Section("Saved profiles")
        for i = 1, #names do
            local name = names[i]
            local inUse = name == current
            local wrap = CreateFrame("Frame", nil, inner)
            wrap:SetHeight(40)
            wrap:EnableMouse(true)
            HoverRow(wrap)
            HoverSpeak(wrap, function()
                if inUse then
                    return name .. ". in use"
                end
                return name
            end)

            local label = AQ.Widgets.TrackerFontString(wrap, 13, inUse and Gold() or TitleCol())
            label:SetPoint("LEFT", 16, 0)
            label:SetPoint("RIGHT", -150, 0)
            if inUse then
                label:SetText(name .. "  (in use)")
            else
                label:SetText(name)
            end

            local actDrop = AQ.Widgets.Dropdown(wrap, { width = 128, height = 30, fixedLabel = "Actions" })
            actDrop:SetPoint("RIGHT", -16, 0)
            HoverSpeak(actDrop, "Actions menu for " .. name)
            local actItems = {
                { text = "Use this profile", value = "use", disabled = inUse },
                { text = "Rename", value = "rename" },
                { text = "Export", value = "export" },
                { text = "Delete", value = "delete", disabled = #names <= 1 },
            }
            actDrop:SetItems(actItems)
            actDrop:SetCallback(function(action)
                if action == "use" then
                    if inUse then
                        return
                    end
                    ConfirmReload("Reload the UI to switch to profile \"" .. name .. "\"?", function()
                        AQ.DB.UseProfile(name)
                    end)
                elseif action == "rename" then
                    AskProfileName("New name for this profile:", name, function(typed)
                        local ok, result = AQ.DB.RenameProfile(name, typed)
                        if not ok then
                            AQ:Print(result or "Could not rename profile.")
                            return
                        end
                        AQ:Print("Renamed profile to " .. tostring(result) .. ".")
                        if AQ.Speech then
                            AQ.Speech.Say("Profile renamed")
                        end
                        Rebuild()
                    end)
                elseif action == "export" then
                    ShowExport(name)
                elseif action == "delete" then
                    if #names <= 1 then
                        return
                    end
                    pendingDeleteProfile = name
                    StaticPopupDialogs = StaticPopupDialogs or {}
                    StaticPopupDialogs["ALLQUEST_PROFILE_DELETE"] = {
                        text = "Delete profile \"" .. name .. "\"? This cannot be undone.",
                        button1 = YES or "Yes",
                        button2 = NO or "No",
                        OnAccept = function()
                            local target = pendingDeleteProfile
                            pendingDeleteProfile = nil
                            if not target then
                                return
                            end
                            local wasActive = AQ.DB.GetActiveName and AQ.DB.GetActiveName() == target
                            local ok, err = AQ.DB.DeleteProfile(target)
                            if not ok then
                                AQ:Print(err or "Could not delete profile.")
                                return
                            end
                            if wasActive then
                                ReloadUI()
                                return
                            end
                            AQ:Print("Deleted profile " .. target .. ".")
                            if AQ.Speech then
                                AQ.Speech.Say("Profile deleted")
                            end
                            Rebuild()
                        end,
                        OnCancel = function()
                            pendingDeleteProfile = nil
                        end,
                        timeout = 0,
                        whileDead = 1,
                        hideOnEscape = 1,
                        preferredIndex = 3,
                    }
                    if StaticPopup_Show then
                        pcall(StaticPopup_Show, "ALLQUEST_PROFILE_DELETE")
                    end
                end
            end)
            Place(wrap)
        end
        y = y - 8
        Note("Create copies the profile you are using. Import never overwrites an existing name.", 48)
    end

    inner:SetHeight(math.max(20 - y, 80))
    if parent.UpdateScroll then
        parent.UpdateScroll()
    end
end

local function Ensure()
    if frame then
        return frame
    end
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(640, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:Hide()
    tinsert(UISpecialFrames, FRAME_NAME)
    frame:SetScript("OnHide", function()
        if AQ.Widgets and AQ.Widgets.CloseDropdown then
            AQ.Widgets.CloseDropdown()
        end
    end)
    AQ.Widgets.ApplyTrackerBackdrop(frame)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 16, -14)
    header:SetPoint("TOPRIGHT", -16, -14)
    header:SetHeight(26)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    frame.Header = header

    local close = AQ.Widgets.TrackerButton(header, "x", 20, 22)
    close:SetPoint("RIGHT", 0, 0)
    close:SetScript("OnClick", function()
        frame:Hide()
        if AQ.Speech then
            AQ.Speech.Say("Settings closed")
        end
    end)
    HoverSpeak(close, "Close settings")
    frame.Close = close

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(22, 22)
    logo:SetPoint("LEFT", 0, 0)
    logo:SetTexture(AQ.Logo)
    frame.Logo = logo

    local title = AQ.Widgets.TrackerFontString(header, 16, Gold())
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetPoint("RIGHT", close, "LEFT", -10, 0)
    title:SetText("AllQuest Settings")
    frame.Title = title
    HoverSpeak(header, "AllQuest Settings")

    local rule = header:CreateTexture(nil, "ARTWORK")
    local rc = T().rule
    rule:SetColorTexture(rc[1], rc[2], rc[3], rc[4] or 0.4)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, -6)
    rule:SetPoint("BOTTOMRIGHT", 0, -6)

    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 16, -52)
    tabBar:SetPoint("BOTTOMLEFT", 16, 16)
    tabBar:SetWidth(136)
    frame.TabBar = tabBar

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetColorTexture(rc[1], rc[2], rc[3], 0.25)
    divider:SetPoint("TOPLEFT", tabBar, "TOPRIGHT", 10, 0)
    divider:SetPoint("BOTTOMLEFT", tabBar, "BOTTOMRIGHT", 10, 0)

    local scroll = AQ.Widgets.Scroll(frame, "AllQuestSettingsScroll")
    AQ.Widgets.HideScrollBar(scroll)
    scroll:SetPoint("TOPLEFT", tabBar, "TOPRIGHT", 22, 0)
    scroll:SetPoint("BOTTOMRIGHT", -16, 16)
    frame.Scroll = scroll

    local content = scroll.Child
    content:SetWidth(450)
    frame.Content = content
    function content.UpdateScroll()
        local h = content.Inner and content.Inner:GetHeight() or 80
        content:SetHeight(math.max(h, 80))
        scroll:SetVerticalScroll(0)
    end

    local tabButtons = {}
    local function Select(i)
        selectedTab = i
        for n = 1, #tabButtons do
            local b = tabButtons[n]
            local on = n == i
            if b.Bar then
                b.Bar:SetShown(on)
            end
            if b.Label then
                if on then
                    b.Label:SetTextColor(Gold())
                else
                    b.Label:SetTextColor(ObjCol())
                end
            end
        end
        BuildTabContent(content, TABS[i].id)
    end

    for i = 1, #TABS do
        local b = CreateFrame("Button", nil, tabBar)
        b:SetHeight(TAB_H)
        b:SetPoint("TOPLEFT", 0, -((i - 1) * (TAB_H + TAB_GAP)))
        b:SetPoint("RIGHT", 0, 0)
        HoverRow(b)
        local bar = b:CreateTexture(nil, "ARTWORK")
        bar:SetWidth(2)
        bar:SetPoint("TOPLEFT", 0, -6)
        bar:SetPoint("BOTTOMLEFT", 0, 6)
        local gr, gg, gb = Gold()
        bar:SetColorTexture(gr, gg, gb, 1)
        bar:Hide()
        b.Bar = bar
        local label = AQ.Widgets.TrackerFontString(b, 13, ObjCol())
        label:SetPoint("LEFT", 14, 0)
        label:SetPoint("RIGHT", -8, 0)
        label:SetText(TABS[i].label)
        b.Label = label
        b:SetScript("OnClick", function()
            Select(i)
        end)
        HoverSpeak(b, TABS[i].label .. " tab")
        tabButtons[i] = b
    end

    frame.AQRebuild = function()
        Select(selectedTab)
    end
    Select(1)
    return frame
end

function Settings.Toggle()
    local f = Ensure()
    if f:IsShown() then
        f:Hide()
    else
        Rebuild()
        f:Show()
        AQ.Speech.Say("AllQuest settings")
    end
end

function Settings.Open()
    local f = Ensure()
    Rebuild()
    f:Show()
end

function AllQuest_OnAddonCompartmentClick()
    if AQ.Settings and AQ.Settings.Toggle then
        AQ.Settings.Toggle()
    end
end
