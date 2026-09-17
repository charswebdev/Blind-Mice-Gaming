--[[
  BMG Unit Frames — per-unit settings with General / Auras / Indicators / More
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Config = UF.Config or {}
local Config = UF.Config

local FRAME_NAME = "BMGUnitFramesConfig"

local UNITS = {
    { id = "player", label = "Player" },
    { id = "pet", label = "Pet" },
    { id = "target", label = "Target" },
    { id = "tot", label = "Target of target" },
    { id = "focus", label = "Focus" },
    { id = "party", label = "Party" },
    { id = "raid", label = "Raid" },
    { id = "arena", label = "Arena" },
}

local TEXT_OPTS = {
    { id = "both", label = "Number and percent" },
    { id = "percent", label = "Percent" },
    { id = "current", label = "Number" },
    { id = "none", label = "Hidden" },
}

local ON_OFF = {
    { id = "on", label = "On" },
    { id = "off", label = "Off" },
}

local FILTER_OPTS = {
    { id = "all", label = "All" },
    { id = "mine", label = "Mine only" },
    { id = "dispellable", label = "Dispellable" },
}

local ANCHOR_OPTS = {
    { id = "BOTTOMLEFT", label = "Below left" },
    { id = "BOTTOMRIGHT", label = "Below right" },
    { id = "TOPLEFT", label = "Above left" },
    { id = "TOPRIGHT", label = "Above right" },
    { id = "CENTER", label = "Center" },
}

local GROWTH_OPTS = {
    { id = "RIGHT", label = "Right" },
    { id = "LEFT", label = "Left" },
    { id = "DOWN", label = "Down" },
    { id = "UP", label = "Up" },
}

local frame
local selected = "player"
local currentTab = "general"

local function Speak(text)
    if UF.Speech and UF.Speech.Say then
        UF.Speech.Say(text)
    end
end

local function CloseMenus()
    if UF.Widgets and UF.Widgets.CloseDropdowns then
        UF.Widgets.CloseDropdowns()
    end
end

local function Profile()
    return UF.DB.Get()
end

local function UnitCfg()
    local p = Profile()
    p.frames = p.frames or {}
    if type(p.frames[selected]) ~= "table" then
        p.frames[selected] = UF.DB.DefaultFrame and UF.DB.DefaultFrame(selected, {}) or {}
    end
    if UF.DB.DefaultUnitExtras then
        local extras = UF.DB.DefaultUnitExtras(selected)
        local Merge
        Merge = function(dst, src)
            if type(dst) ~= "table" or type(src) ~= "table" then
                return dst
            end
            for k, v in pairs(src) do
                if type(v) == "table" then
                    if type(dst[k]) ~= "table" then
                        dst[k] = {}
                    end
                    Merge(dst[k], v)
                elseif dst[k] == nil then
                    dst[k] = v
                end
            end
            return dst
        end
        Merge(p.frames[selected], extras)
    end
    return p.frames[selected]
end

local function AuraKind(kind)
    local cfg = UnitCfg()
    cfg.auras = cfg.auras or {}
    if type(cfg.auras[kind]) ~= "table" then
        cfg.auras[kind] = {}
    end
    return cfg.auras[kind]
end

local function HasGrowth(id)
    return id == "party" or id == "raid" or id == "arena"
end

local function RelayoutSelected()
    if not UF.Frames then
        return
    end
    if selected == "party" and UF.Frames.RelayoutParty then
        UF.Frames.RelayoutParty()
    elseif selected == "raid" and UF.Frames.RelayoutRaid then
        UF.Frames.RelayoutRaid()
    elseif selected == "arena" and UF.Frames.RelayoutArena then
        UF.Frames.RelayoutArena()
    end
end

local function ShowTab(id)
    currentTab = id
    if not frame or not frame.pages then
        return
    end
    for name, page in pairs(frame.pages) do
        if page.SetShown then
            page:SetShown(name == id)
        end
    end
    if frame.scroll and frame.pages[id] then
        frame.scroll:SetScrollChild(frame.pages[id])
        frame.pages[id]:SetWidth(500)
        frame.scroll:SetVerticalScroll(0)
    end
end

local function Refresh()
    if not frame then
        return
    end
    local p = Profile()
    local cfg = UnitCfg()
    if frame.profileBox then
        frame.profileBox:SetText(UF.DB.CurrentName())
    end
    if frame.lockBtn then
        frame.lockBtn:SetLabel(p.locked and "Unlock frames" or "Lock frames")
    end
    if frame.unitLabel then
        local name = selected
        for i = 1, #UNITS do
            if UNITS[i].id == selected then
                name = UNITS[i].label
                break
            end
        end
        frame.unitLabel:SetText(name)
    end
    if frame.navButtons then
        for i = 1, #frame.navButtons do
            local btn = frame.navButtons[i]
            if btn.navId == selected then
                btn.Label:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
            else
                btn.Label:SetTextColor(0.78, 0.78, 0.78, 1)
            end
        end
    end
    if frame.enableDrop then
        frame.enableDrop:SetValue(cfg.enabled == false and "hidden" or "shown")
    end
    if frame.portraitDrop then
        frame.portraitDrop:SetValue(cfg.portrait or p.portrait or "portrait")
    end
    if frame.healthDrop then
        frame.healthDrop:SetValue(cfg.healthText or p.healthText or "both")
    end
    if frame.powerTextDrop then
        frame.powerTextDrop:SetValue(cfg.powerText or p.powerText or "both")
    end
    if frame.powerDrop then
        local on = cfg.showPower
        if on == nil then
            on = p.showPower ~= false
        end
        frame.powerDrop:SetValue(on and "on" or "off")
    end
    if frame.altPowerDrop then
        local on = cfg.showAltPower
        if on == nil then
            on = p.showAltPower ~= false
        end
        frame.altPowerDrop:SetValue(on and "on" or "off")
    end
    if frame.widthRow then
        frame.widthRow:SetValueText(tostring(cfg.w or 200))
    end
    if frame.heightRow then
        frame.heightRow:SetValueText(tostring(cfg.h or 52))
    end
    if frame.scaleRow then
        frame.scaleRow:SetValueText(string.format("%.2f", cfg.scale or 1))
    end
    if frame.youDrop then
        frame.youDrop:SetValue(p.showPlayerInParty == false and "off" or "on")
        if selected == "party" then
            frame.youDrop:Show()
        else
            frame.youDrop:Hide()
        end
    end
    if frame.growthDrop then
        frame.growthDrop:SetValue(string.upper(tostring(cfg.growth or "DOWN")))
        if HasGrowth(selected) then
            frame.growthDrop:Show()
        else
            frame.growthDrop:Hide()
        end
    end

    local function FillAura(prefix, kind)
        local a = AuraKind(kind)
        if frame[prefix .. "Enable"] then
            frame[prefix .. "Enable"]:SetValue(a.enabled and "on" or "off")
        end
        if frame[prefix .. "Filter"] then
            frame[prefix .. "Filter"]:SetValue(a.filter or "all")
        end
        if frame[prefix .. "Anchor"] then
            frame[prefix .. "Anchor"]:SetValue(a.anchor or "BOTTOMLEFT")
        end
        if frame[prefix .. "Growth"] then
            frame[prefix .. "Growth"]:SetValue(string.upper(a.growth or "RIGHT"))
        end
        if frame[prefix .. "Timers"] then
            frame[prefix .. "Timers"]:SetValue(a.timers == false and "off" or "on")
        end
        if frame[prefix .. "Size"] then
            frame[prefix .. "Size"]:SetValueText(tostring(a.size or 18))
        end
        if frame[prefix .. "Max"] then
            frame[prefix .. "Max"]:SetValueText(tostring(a.max or 8))
        end
    end
    FillAura("buff", "buffs")
    FillAura("debuff", "debuffs")

    local ind = cfg.indicators or {}
    local function Ind(name, key)
        if frame[name] then
            frame[name]:SetValue(ind[key] == false and "off" or "on")
        end
    end
    Ind("indCombat", "combat")
    Ind("indRest", "resting")
    Ind("indLeader", "leader")
    Ind("indMark", "raidTarget")
    Ind("indPvp", "pvp")
    Ind("indRole", "role")
    Ind("indRez", "resurrect")
    Ind("indReady", "ready")
    Ind("indElite", "elite")
    Ind("indHappy", "happiness")
    Ind("indPhase", "phase")
    Ind("indOor", "oor")
    Ind("indQuest", "quest")
    local indPos = cfg.indPos or {}
    local function IndP(name, key)
        if frame[name] then
            frame[name]:SetValue(string.upper(tostring(indPos[key] or "CENTER")))
        end
    end
    IndP("indCombatPos", "combat")
    IndP("indRestPos", "resting")
    IndP("indLeaderPos", "leader")
    IndP("indMarkPos", "raidTarget")
    IndP("indPvpPos", "pvp")
    IndP("indRolePos", "role")
    IndP("indRezPos", "resurrect")
    IndP("indReadyPos", "ready")
    IndP("indElitePos", "elite")
    IndP("indHappyPos", "happiness")
    IndP("indPhasePos", "phase")
    IndP("indOorPos", "oor")
    IndP("indQuestPos", "quest")
    local tpos = cfg.textPos or {}
    if frame.namePosDrop then
        frame.namePosDrop:SetValue(tpos.name or "TOPLEFT")
    end
    if frame.healthPosDrop then
        frame.healthPosDrop:SetValue(tpos.health or "CENTER")
    end
    if frame.powerPosDrop then
        frame.powerPosDrop:SetValue(tpos.power or "CENTER")
    end

    local extra = cfg.extra or {}
    if frame.healDrop then
        frame.healDrop:SetValue(extra.healPredict == false and "off" or "on")
    end
    if frame.absorbDrop then
        frame.absorbDrop:SetValue(extra.absorb == false and "off" or "on")
    end
    if frame.healAbsorbDrop then
        frame.healAbsorbDrop:SetValue(extra.healAbsorb == false and "off" or "on")
    end
    if frame.mouseDrop then
        frame.mouseDrop:SetValue(extra.mouseover == false and "off" or "on")
    end
    if frame.aggroDrop then
        frame.aggroDrop:SetValue(extra.aggro == false and "off" or "on")
    end
    if frame.castDrop then
        frame.castDrop:SetValue(extra.castBar == false and "off" or "on")
    end
    if frame.castAttachDrop then
        local c = extra.cast or {}
        frame.castAttachDrop:SetValue(c.attach or "BELOW")
    end
    if frame.castWRow then
        local c = extra.cast or {}
        frame.castWRow:SetValueText(tostring((c.w and c.w > 0) and c.w or "Match"))
    end
    if frame.castHRow then
        local c = extra.cast or {}
        frame.castHRow:SetValueText(tostring(c.h or 12))
    end
    if frame.rangeDrop then
        frame.rangeDrop:SetValue(extra.rangeFade == false and "off" or "on")
    end
    if frame.styleDrop then
        frame.styleDrop:SetValue(p.style == "classic" and "classic" or "modern")
    end
    if frame.colorDrop then
        frame.colorDrop:SetValue(p.classColors == "modern" and "modern" or "classic")
    end
end

local function ApplyNow()
    if UF.ApplyProfile then
        UF.ApplyProfile(Profile())
    end
    RelayoutSelected()
    Refresh()
end

local function Nudge(key, delta, minV, maxV, step)
    if UF.Compat.InCombat() then
        Speak("Frames are locked in combat.")
        return
    end
    CloseMenus()
    local cfg = UnitCfg()
    local v = cfg[key]
    if type(v) ~= "number" then
        v = (key == "scale" and 1) or (key == "h" and 52) or 200
    end
    v = v + (delta * step)
    if v < minV then
        v = minV
    end
    if v > maxV then
        v = maxV
    end
    if key ~= "scale" then
        v = math.floor(v + 0.5)
    end
    cfg[key] = v
    ApplyNow()
    Speak((key == "w" and "Width " or key == "h" and "Height " or "Scale ") .. (key == "scale" and string.format("%.2f", v) or tostring(v)) .. ".")
end

local function NudgeAura(kind, key, delta, minV, maxV, step)
    CloseMenus()
    local a = AuraKind(kind)
    local v = tonumber(a[key]) or minV
    v = v + delta * step
    if v < minV then
        v = minV
    end
    if v > maxV then
        v = maxV
    end
    a[key] = math.floor(v + 0.5)
    if key == "max" then
        a.perRow = a[key]
    end
    ApplyNow()
    Speak((key == "size" and "Icon size " or "Count ") .. tostring(a[key]) .. ".")
end

local function SaveWindowPos()
    if not frame then
        return
    end
    local p = Profile()
    local point, _, _, x, y = frame:GetPoint(1)
    p.window.point = point or "CENTER"
    p.window.x = x or 0
    p.window.y = y or 0
end

local function FillExport()
    CloseMenus()
    local code = UF.Share.Export()
    frame.code:SetText(code)
    frame.code:SetFocus()
    frame.code:HighlightText()
    local copied = UF.Compat.CopyToClipboard(code)
    Speak(copied and "Export code copied to the clipboard." or "Export code ready. Press control C to copy.")
end

local function DoImport()
    CloseMenus()
    local ok, msg = UF.Share.Import(frame.code:GetText(), frame.profileBox:GetText())
    Speak(msg)
    print((ok and "|cff00ff00" or "|cffff6600") .. "[BMG Unit Frames]|r " .. msg)
    Refresh()
end

local function SelectUnit(id)
    CloseMenus()
    selected = id
    Refresh()
    local label = id
    for i = 1, #UNITS do
        if UNITS[i].id == id then
            label = UNITS[i].label
            break
        end
    end
    Speak(label .. " settings. " .. currentTab .. ".")
end

local function Drop(parent, title, width, titleWidth, options, tip, hint)
    local row = UF.Widgets.Dropdown(parent, title, width, titleWidth)
    row:SetOptions(options)
    row._tip = tip
    row._hint = hint
    row._speakOpen = title
    row._speak = title .. " dropdown."
    return row
end

local function BuildPage(parent, name)
    local page = CreateFrame("Frame", nil, parent)
    page:SetWidth(500)
    page:SetHeight(920)
    page:Hide()
    frame.pages[name] = page
    return page
end

local function Stack()
    local y = 0
    return function(widget, h)
        widget:SetPoint("TOPLEFT", 0, y)
        y = y - (h + 8)
        return y
    end
end

local function Build()
    if frame then
        return frame
    end

    local tmpl = UF.Compat.BackdropTemplate()
    frame = CreateFrame("Frame", FRAME_NAME, UIParent, tmpl)
    frame:SetSize(760, 640)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:Hide()
    UF.Widgets.Paint(frame, 0.07, 0.07, 0.08, 1, 0.72, 0.66, 0.38)
    tinsert(UISpecialFrames, FRAME_NAME)
    frame.pages = {}

    local p = Profile()
    frame:SetPoint(p.window.point or "CENTER", UIParent, p.window.point or "CENTER", p.window.x or 0, p.window.y or 0)
    frame:SetScript("OnDragStart", function(self)
        CloseMenus()
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveWindowPos()
    end)
    frame:SetScript("OnHide", CloseMenus)

    local logo = frame:CreateTexture(nil, "ARTWORK")
    logo:SetSize(26, 26)
    logo:SetPoint("TOPLEFT", 16, -14)
    logo:SetTexture("Interface\\AddOns\\BMG-Unit-frames\\Media\\Icon.png")

    local title = UF.Widgets.Label(frame, 18, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    title:SetPoint("LEFT", logo, "RIGHT", 10, 0)
    title:SetText("BMG Unit Frames")

    local sub = UF.Widgets.Label(frame, 12, 0.62, 0.62, 0.64)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    sub:SetText("Choose a unit, then a category.")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function()
        CloseMenus()
        frame:Hide()
        Speak("Unit frame settings closed.")
    end)

    local foot = CreateFrame("Frame", nil, frame, tmpl)
    foot:SetPoint("BOTTOMLEFT", 16, 12)
    foot:SetPoint("BOTTOMRIGHT", -16, 12)
    foot:SetHeight(104)
    UF.Widgets.Paint(foot, 0.05, 0.05, 0.06, 1, 0.28, 0.28, 0.30)

    local nav = CreateFrame("Frame", nil, frame, tmpl)
    nav:SetPoint("TOPLEFT", 16, -58)
    nav:SetPoint("BOTTOMLEFT", foot, "TOPLEFT", 0, 12)
    nav:SetWidth(168)
    UF.Widgets.Paint(nav, 0.05, 0.05, 0.06, 1, 0.28, 0.28, 0.30)
    frame.navButtons = {}
    for i = 1, #UNITS do
        local info = UNITS[i]
        local btn = CreateFrame("Button", nil, nav)
        btn:SetHeight(30)
        btn:SetPoint("TOPLEFT", 8, -10 - ((i - 1) * 32))
        btn:SetPoint("RIGHT", -8, 0)
        local fs = UF.Widgets.Label(btn, 13, 0.78, 0.78, 0.78)
        fs:SetPoint("LEFT", 8, 0)
        fs:SetText(info.label)
        btn.Label = fs
        btn.navId = info.id
        btn:SetScript("OnClick", function()
            SelectUnit(info.id)
        end)
        btn:SetScript("OnEnter", function()
            fs:SetTextColor(UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3], 1)
            Speak(info.label)
        end)
        btn:SetScript("OnLeave", function()
            if selected ~= info.id then
                fs:SetTextColor(0.78, 0.78, 0.78, 1)
            end
        end)
        frame.navButtons[#frame.navButtons + 1] = btn
    end

    local pane = CreateFrame("Frame", nil, frame)
    pane:SetPoint("TOPLEFT", nav, "TOPRIGHT", 16, 0)
    pane:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT", 0, 12)

    frame.unitLabel = UF.Widgets.Label(pane, 16, UF.Theme.accent[1], UF.Theme.accent[2], UF.Theme.accent[3])
    frame.unitLabel:SetPoint("TOPLEFT", 0, 0)
    frame.unitLabel:SetText("Player")

    local tabs = UF.Widgets.Tabs(pane, {
        { id = "general", label = "General" },
        { id = "auras", label = "Auras" },
        { id = "indicators", label = "Indicators" },
        { id = "more", label = "More" },
    }, 500, function(id, label)
        CloseMenus()
        ShowTab(id)
        Speak(label .. ".")
    end)
    tabs:SetPoint("TOPLEFT", 0, -26)

    local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "Scroll", pane)
    scroll:SetPoint("TOPLEFT", 0, -62)
    scroll:SetPoint("BOTTOMRIGHT", 0, 0)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local maxs = self:GetVerticalScrollRange() or 0
        local nexts = cur - (delta * 36)
        if nexts < 0 then
            nexts = 0
        end
        if nexts > maxs then
            nexts = maxs
        end
        self:SetVerticalScroll(nexts)
    end)
    frame.scroll = scroll

    local general = BuildPage(scroll, "general")
    local g = Stack()
    local head = UF.Widgets.Header(general, "Frame")
    g(head, 16)
    frame.enableDrop = Drop(general, "This frame", 500, 140, {
        { id = "shown", label = "Shown" },
        { id = "hidden", label = "Hidden" },
    }, "This frame", "Show or hide this unit.")
    frame.enableDrop:SetOnChange(function(id, text)
        UnitCfg().enabled = id ~= "hidden"
        ApplyNow()
        Speak(text .. ".")
    end)
    g(frame.enableDrop, 32)
    frame.widthRow = UF.Widgets.Stepper(general, "Width", 500)
    frame.widthRow.minus:SetScript("OnClick", function()
        Nudge("w", -1, 60, 400, 5)
    end)
    frame.widthRow.plus:SetScript("OnClick", function()
        Nudge("w", 1, 60, 400, 5)
    end)
    g(frame.widthRow, 32)
    frame.heightRow = UF.Widgets.Stepper(general, "Height", 500)
    frame.heightRow.minus:SetScript("OnClick", function()
        Nudge("h", -1, 20, 140, 2)
    end)
    frame.heightRow.plus:SetScript("OnClick", function()
        Nudge("h", 1, 20, 140, 2)
    end)
    g(frame.heightRow, 32)
    frame.scaleRow = UF.Widgets.Stepper(general, "Scale", 500)
    frame.scaleRow.minus:SetScript("OnClick", function()
        Nudge("scale", -1, 0.6, 2, 0.05)
    end)
    frame.scaleRow.plus:SetScript("OnClick", function()
        Nudge("scale", 1, 0.6, 2, 0.05)
    end)
    g(frame.scaleRow, 32)
    frame.portraitDrop = Drop(general, "Portrait", 500, 140, {
        { id = "portrait", label = "Portrait" },
        { id = "class", label = "Class icon" },
        { id = "off", label = "Hidden" },
    }, "Portrait", "3D portrait, class icon, or hidden.")
    frame.portraitDrop:SetOnChange(function(id, text)
        UnitCfg().portrait = id
        ApplyNow()
        Speak("Portrait " .. text .. ".")
    end)
    g(frame.portraitDrop, 32)
    frame.namePosDrop = Drop(general, "Name position", 500, 160, UF.Pos.OPTIONS, "Name position", "Where the unit name sits on the frame.")
    frame.namePosDrop:SetOnChange(function(id, text)
        UnitCfg().textPos = UnitCfg().textPos or {}
        UnitCfg().textPos.name = id
        ApplyNow()
        Speak("Name " .. text .. ".")
    end)
    g(frame.namePosDrop, 32)
    local bars = UF.Widgets.Header(general, "Health and power")
    g(bars, 16)
    frame.healthDrop = Drop(general, "Health text", 500, 140, TEXT_OPTS, "Health text", "Number, percent, or both on the health bar.")
    frame.healthDrop:SetOnChange(function(id, text)
        UnitCfg().healthText = id
        ApplyNow()
        Speak("Health " .. text .. ".")
    end)
    g(frame.healthDrop, 32)
    frame.healthPosDrop = Drop(general, "Health position", 500, 160, UF.Pos.OPTIONS, "Health position", "Where health numbers sit on the bar.")
    frame.healthPosDrop:SetOnChange(function(id, text)
        UnitCfg().textPos = UnitCfg().textPos or {}
        UnitCfg().textPos.health = id
        ApplyNow()
        Speak("Health text " .. text .. ".")
    end)
    g(frame.healthPosDrop, 32)
    frame.powerTextDrop = Drop(general, "Power text", 500, 140, TEXT_OPTS, "Power text", "Number, percent, or both on the power bars.")
    frame.powerTextDrop:SetOnChange(function(id, text)
        UnitCfg().powerText = id
        ApplyNow()
        Speak("Power text " .. text .. ".")
    end)
    g(frame.powerTextDrop, 32)
    frame.powerPosDrop = Drop(general, "Power position", 500, 160, UF.Pos.OPTIONS, "Power position", "Where power numbers sit on the bar.")
    frame.powerPosDrop:SetOnChange(function(id, text)
        UnitCfg().textPos = UnitCfg().textPos or {}
        UnitCfg().textPos.power = id
        ApplyNow()
        Speak("Power text " .. text .. ".")
    end)
    g(frame.powerPosDrop, 32)
    frame.powerDrop = Drop(general, "Power bar", 500, 140, ON_OFF, "Power bar", "Mana, rage, energy, or focus.")
    frame.powerDrop:SetOnChange(function(id, text)
        UnitCfg().showPower = id == "on"
        ApplyNow()
        Speak("Power bar " .. text .. ".")
    end)
    g(frame.powerDrop, 32)
    frame.altPowerDrop = Drop(general, "Second power", 500, 140, ON_OFF, "Second power", "Holy Power, combo points, and other class resources.")
    frame.altPowerDrop:SetOnChange(function(id, text)
        UnitCfg().showAltPower = id == "on"
        ApplyNow()
        Speak("Second power " .. text .. ".")
    end)
    g(frame.altPowerDrop, 32)
    frame.youDrop = Drop(general, "Party includes you", 500, 180, ON_OFF, "Show you in party", "Adds your character as the first party bar.")
    frame.youDrop:SetOnChange(function(id, text)
        Profile().showPlayerInParty = id == "on"
        ApplyNow()
        Speak("Party includes you " .. text .. ".")
    end)
    g(frame.youDrop, 32)
    frame.growthDrop = Drop(general, "Growth", 500, 140, {
        { id = "DOWN", label = "Down" },
        { id = "UP", label = "Up" },
        { id = "LEFT", label = "Left" },
        { id = "RIGHT", label = "Right" },
    }, "Growth", "How party, raid, or arena bars stack.")
    frame.growthDrop:SetOnChange(function(id, text)
        if UF.Compat.InCombat() then
            Speak("Frames are locked in combat.")
            Refresh()
            return
        end
        UnitCfg().growth = id
        ApplyNow()
        Speak("Growth " .. text .. ".")
    end)
    g(frame.growthDrop, 32)

    local auras = BuildPage(scroll, "auras")
    local function AuraSection(page, place, prefix, kind, title)
        local h = UF.Widgets.Header(page, title)
        place(h, 16)
        frame[prefix .. "Enable"] = Drop(page, "Show", 500, 140, ON_OFF, title, "Show these icons on this unit.")
        frame[prefix .. "Enable"]:SetOnChange(function(id, text)
            AuraKind(kind).enabled = id == "on"
            ApplyNow()
            Speak(title .. " " .. text .. ".")
        end)
        place(frame[prefix .. "Enable"], 32)
        frame[prefix .. "Filter"] = Drop(page, "Filter", 500, 140, FILTER_OPTS, "Filter", "All auras, only yours, or only what you can dispel.")
        frame[prefix .. "Filter"]:SetOnChange(function(id, text)
            AuraKind(kind).filter = id
            ApplyNow()
            Speak("Filter " .. text .. ".")
        end)
        place(frame[prefix .. "Filter"], 32)
        frame[prefix .. "Anchor"] = Drop(page, "Position", 500, 140, ANCHOR_OPTS, "Position", "Where the icons sit on the frame.")
        frame[prefix .. "Anchor"]:SetOnChange(function(id, text)
            AuraKind(kind).anchor = id
            ApplyNow()
            Speak("Position " .. text .. ".")
        end)
        place(frame[prefix .. "Anchor"], 32)
        frame[prefix .. "Growth"] = Drop(page, "Grow", 500, 140, GROWTH_OPTS, "Grow", "Which way extra icons wrap.")
        frame[prefix .. "Growth"]:SetOnChange(function(id, text)
            AuraKind(kind).growth = id
            ApplyNow()
            Speak("Grow " .. text .. ".")
        end)
        place(frame[prefix .. "Growth"], 32)
        frame[prefix .. "Timers"] = Drop(page, "Timers", 500, 140, ON_OFF, "Timers", "Show remaining time on the icon.")
        frame[prefix .. "Timers"]:SetOnChange(function(id, text)
            AuraKind(kind).timers = id == "on"
            ApplyNow()
            Speak("Timers " .. text .. ".")
        end)
        place(frame[prefix .. "Timers"], 32)
        frame[prefix .. "Size"] = UF.Widgets.Stepper(page, "Icon size", 500)
        frame[prefix .. "Size"].minus:SetScript("OnClick", function()
            NudgeAura(kind, "size", -1, 10, 36, 2)
        end)
        frame[prefix .. "Size"].plus:SetScript("OnClick", function()
            NudgeAura(kind, "size", 1, 10, 36, 2)
        end)
        place(frame[prefix .. "Size"], 32)
        frame[prefix .. "Max"] = UF.Widgets.Stepper(page, "How many", 500)
        frame[prefix .. "Max"].minus:SetScript("OnClick", function()
            NudgeAura(kind, "max", -1, 1, 16, 1)
        end)
        frame[prefix .. "Max"].plus:SetScript("OnClick", function()
            NudgeAura(kind, "max", 1, 1, 16, 1)
        end)
        place(frame[prefix .. "Max"], 32)
    end
    local ap = Stack()
    AuraSection(auras, ap, "buff", "buffs", "Buffs")
    AuraSection(auras, ap, "debuff", "debuffs", "Debuffs")

    local indicators = BuildPage(scroll, "indicators")
    local ip = Stack()
    local ih = UF.Widgets.Header(indicators, "Status icons")
    ip(ih, 16)
    local function IndDrop(key, field, label, hint)
        frame[key] = Drop(indicators, label, 248, 110, ON_OFF, label, hint)
        frame[key]:SetOnChange(function(id, text)
            local cfg = UnitCfg()
            cfg.indicators = cfg.indicators or {}
            cfg.indicators[field] = id == "on"
            ApplyNow()
            Speak(label .. " " .. text .. ".")
        end)
        frame[key .. "Pos"] = Drop(indicators, "Position", 248, 90, UF.Pos.OPTIONS, label .. " position", "Where this icon sits on the frame.")
        frame[key .. "Pos"]:SetOnChange(function(id, text)
            local cfg = UnitCfg()
            cfg.indPos = cfg.indPos or {}
            cfg.indPos[field] = id
            ApplyNow()
            Speak(label .. " " .. text .. ".")
        end)
        local row = CreateFrame("Frame", nil, indicators)
        row:SetSize(500, 32)
        ip(row, 32)
        frame[key]:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        frame[key .. "Pos"]:SetPoint("TOPLEFT", row, "TOPLEFT", 252, 0)
    end
    IndDrop("indCombat", "combat", "Combat", "Sword icon while the unit is in combat.")
    IndDrop("indRest", "resting", "Resting", "Rest icon on you in an inn or city.")
    IndDrop("indLeader", "leader", "Leader", "Crown when the unit is party or raid leader.")
    IndDrop("indMark", "raidTarget", "Raid marker", "Skull, cross, and other target marks.")
    IndDrop("indPvp", "pvp", "PvP", "Faction flag when PvP is on.")
    IndDrop("indRole", "role", "Main tank or assist", "Tank and assist assignment icons.")
    IndDrop("indRez", "resurrect", "Resurrect", "Shows when a resurrect is incoming.")
    IndDrop("indReady", "ready", "Ready check", "Ready, not ready, or waiting.")
    IndDrop("indElite", "elite", "Elite", "Marks elite, rare, and boss units.")
    IndDrop("indHappy", "happiness", "Pet happiness", "Hunter pet mood on Classic.")
    IndDrop("indPhase", "phase", "Phased", "Shows when the unit is in another phase or timeline.")
    IndDrop("indOor", "oor", "Out of range", "Red mark when the unit is too far to interact.")
    IndDrop("indQuest", "quest", "Quest", "Marks quest bosses and units named in your quest log.")

    local more = BuildPage(scroll, "more")
    local mp = Stack()
    local mh = UF.Widgets.Header(more, "This unit")
    mp(mh, 16)
    frame.healDrop = Drop(more, "Incoming heals", 500, 180, ON_OFF, "Incoming heals", "Green overlay for heals already incoming.")
    frame.healDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.healPredict = id == "on"
        ApplyNow()
        Speak("Incoming heals " .. text .. ".")
    end)
    mp(frame.healDrop, 32)
    frame.absorbDrop = Drop(more, "Absorb shield", 500, 180, ON_OFF, "Absorb shield", "Gold overlay for shields. Later clients only.")
    frame.absorbDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.absorb = id == "on"
        ApplyNow()
        Speak("Absorb shield " .. text .. ".")
    end)
    mp(frame.absorbDrop, 32)
    frame.healAbsorbDrop = Drop(more, "Heal absorb", 500, 180, ON_OFF, "Heal absorb", "Purple overlay when heals are absorbed. Later clients only.")
    frame.healAbsorbDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.healAbsorb = id == "on"
        ApplyNow()
        Speak("Heal absorb " .. text .. ".")
    end)
    mp(frame.healAbsorbDrop, 32)
    frame.mouseDrop = Drop(more, "Mouseover highlight", 500, 180, ON_OFF, "Mouseover highlight", "Gold border when you hover this frame.")
    frame.mouseDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.mouseover = id == "on"
        ApplyNow()
        Speak("Mouseover highlight " .. text .. ".")
    end)
    mp(frame.mouseDrop, 32)
    frame.aggroDrop = Drop(more, "Aggro highlight", 500, 180, ON_OFF, "Aggro highlight", "Red border when the unit has threat.")
    frame.aggroDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.aggro = id == "on"
        ApplyNow()
        Speak("Aggro highlight " .. text .. ".")
    end)
    mp(frame.aggroDrop, 32)
    local ch = UF.Widgets.Header(more, "Cast bar")
    mp(ch, 16)
    frame.castDrop = Drop(more, "Cast bar", 500, 180, ON_OFF, "Cast bar", "Show the cast bar for this unit.")
    frame.castDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.castBar = id == "on"
        ApplyNow()
        Speak("Cast bar " .. text .. ".")
    end)
    mp(frame.castDrop, 32)
    frame.castAttachDrop = Drop(more, "Cast position", 500, 160, UF.Pos.CAST_ATTACH, "Cast position", "Below, above, inside, or free so you can drag it.")
    frame.castAttachDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.cast = UnitCfg().extra.cast or {}
        UnitCfg().extra.cast.attach = id
        ApplyNow()
        Speak("Cast bar " .. text .. ".")
    end)
    mp(frame.castAttachDrop, 32)
    frame.castWRow = UF.Widgets.Stepper(more, "Cast width", 500)
    frame.castWRow.minus:SetScript("OnClick", function()
        local c = UnitCfg().extra
        c = c or {}
        UnitCfg().extra = c
        c.cast = c.cast or {}
        local v = c.cast.w or 0
        if v <= 0 then
            v = 200
        end
        v = v - 10
        if v < 80 then
            v = 80
        end
        c.cast.w = v
        ApplyNow()
        Speak("Cast width " .. tostring(v) .. ".")
    end)
    frame.castWRow.plus:SetScript("OnClick", function()
        local c = UnitCfg().extra or {}
        UnitCfg().extra = c
        c.cast = c.cast or {}
        local v = c.cast.w or 0
        if v <= 0 then
            v = 200
        end
        v = v + 10
        if v > 400 then
            v = 400
        end
        c.cast.w = v
        ApplyNow()
        Speak("Cast width " .. tostring(v) .. ".")
    end)
    mp(frame.castWRow, 32)
    frame.castHRow = UF.Widgets.Stepper(more, "Cast height", 500)
    frame.castHRow.minus:SetScript("OnClick", function()
        local c = UnitCfg().extra or {}
        UnitCfg().extra = c
        c.cast = c.cast or {}
        local v = (c.cast.h or 12) - 1
        if v < 8 then
            v = 8
        end
        c.cast.h = v
        ApplyNow()
        Speak("Cast height " .. tostring(v) .. ".")
    end)
    frame.castHRow.plus:SetScript("OnClick", function()
        local c = UnitCfg().extra or {}
        UnitCfg().extra = c
        c.cast = c.cast or {}
        local v = (c.cast.h or 12) + 1
        if v > 40 then
            v = 40
        end
        c.cast.h = v
        ApplyNow()
        Speak("Cast height " .. tostring(v) .. ".")
    end)
    mp(frame.castHRow, 32)
    frame.rangeDrop = Drop(more, "Range fade", 500, 180, ON_OFF, "Range fade", "Fade the frame when the unit is out of range.")
    frame.rangeDrop:SetOnChange(function(id, text)
        UnitCfg().extra = UnitCfg().extra or {}
        UnitCfg().extra.rangeFade = id == "on"
        ApplyNow()
        Speak("Range fade " .. text .. ".")
    end)
    mp(frame.rangeDrop, 32)
    local look = UF.Widgets.Header(more, "All frames")
    mp(look, 16)
    frame.styleDrop = Drop(more, "Style", 500, 140, {
        { id = "modern", label = "Modern" },
        { id = "classic", label = "Classic Blizzard" },
    }, "Style", "Classic green health, or class-colored bars.")
    frame.styleDrop:SetOnChange(function(id, text)
        Profile().style = id
        ApplyNow()
        Speak("Style " .. text .. ".")
    end)
    mp(frame.styleDrop, 32)
    frame.colorDrop = Drop(more, "Colors", 500, 140, {
        { id = "classic", label = "Classic Blizzard" },
        { id = "modern", label = "Modern" },
    }, "Class colors", "Classic client colors, or modern blue Shamans.")
    frame.colorDrop:SetOnChange(function(id, text)
        Profile().classColors = id
        ApplyNow()
        Speak("Class colors " .. text .. ".")
    end)
    mp(frame.colorDrop, 32)

    ShowTab("general")

    frame.lockBtn = UF.Widgets.Button(foot, "Unlock frames", 248, 28)
    frame.lockBtn:SetPoint("TOPLEFT", 10, -10)
    frame.lockBtn:SetScript("OnClick", function()
        CloseMenus()
        if UF.Compat.InCombat() then
            Speak("Frames are locked in combat.")
            return
        end
        local db = Profile()
        db.locked = not db.locked
        ApplyNow()
        Speak(db.locked and "Frames locked." or "Frames unlocked.")
    end)
    frame.snapBtn = UF.Widgets.Button(foot, "Use current positions", 248, 28)
    frame.snapBtn:SetPoint("TOPLEFT", 266, -10)
    frame.snapBtn:SetScript("OnClick", function()
        CloseMenus()
        if UF.Compat.InCombat() then
            Speak("Frames are locked in combat.")
            return
        end
        UF.DB.CaptureAndMaybeSnap(true)
        ApplyNow()
        Speak("Frames moved to your current UI positions.")
    end)
    frame.profileBox = CreateFrame("EditBox", FRAME_NAME .. "Profile", foot, "InputBoxTemplate")
    frame.profileBox:SetSize(140, 24)
    frame.profileBox:SetPoint("TOPLEFT", 16, -46)
    frame.profileBox:SetAutoFocus(false)
    frame.profileBox:SetMaxLetters(32)
    local saveBtn = UF.Widgets.Button(foot, "Save", 72, 26)
    saveBtn:SetPoint("LEFT", frame.profileBox, "RIGHT", 8, 0)
    saveBtn:SetScript("OnClick", function()
        CloseMenus()
        local ok, msg = UF.DB.SaveAs(frame.profileBox:GetText())
        Speak(msg)
        Refresh()
    end)
    local loadBtn = UF.Widgets.Button(foot, "Load", 72, 26)
    loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)
    loadBtn:SetScript("OnClick", function()
        CloseMenus()
        local ok, msg = UF.DB.Switch(frame.profileBox:GetText())
        Speak(msg)
        Refresh()
    end)
    local exportBtn = UF.Widgets.Button(foot, "Export", 72, 26)
    exportBtn:SetPoint("LEFT", loadBtn, "RIGHT", 6, 0)
    exportBtn:SetScript("OnClick", FillExport)
    frame.code = CreateFrame("EditBox", FRAME_NAME .. "Code", foot)
    frame.code:SetPoint("BOTTOMLEFT", 12, 22)
    frame.code:SetPoint("BOTTOMRIGHT", -12, 22)
    frame.code:SetHeight(20)
    frame.code:SetAutoFocus(false)
    frame.code:SetFontObject(ChatFontNormal)
    frame.code:SetTextColor(0.95, 0.90, 0.70, 1)
    frame.code:SetScript("OnEnterPressed", DoImport)
    frame.code:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    local help = UF.Widgets.Label(foot, 11, 0.55, 0.55, 0.58)
    help:SetPoint("BOTTOMLEFT", 12, 6)
    help:SetText("/bmguf    Key Bindings: BMG Unit Frames    Esc closes")

    frame:SetScript("OnShow", Refresh)
    Refresh()
    return frame
end

function Config.Toggle()
    local f = Build()
    if f:IsShown() then
        CloseMenus()
        f:Hide()
        Speak("Unit frame settings closed.")
    else
        f:Show()
        Speak("BMG Unit Frames. Player. General.")
    end
end

function Config.Open()
    local f = Build()
    if not f:IsShown() then
        f:Show()
        Speak("BMG Unit Frames settings.")
    end
end

function Config.ShowExport()
    Config.Open()
    FillExport()
end

function Config.Refresh()
    Refresh()
end
