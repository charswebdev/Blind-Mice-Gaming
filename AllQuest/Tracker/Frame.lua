--[[
  AllQuest — custom objective tracker (not a Blizzard skin)
  Section plugins supply rows. Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Tracker = AQ.Tracker or {}
local Tracker = AQ.Tracker

local sections = {}
local sectionOrder = {}
local frame
local rows = {}
local focused = 1
local builtRows = {}
local refreshPending = false
local sizing = false
local liveW, liveH
local hoverSpeechKey
local UpdateChrome
local MIN_TRACKER_W = 220
local MIN_TRACKER_H = 90
local MAX_TRACKER_W = 720
local MAX_TRACKER_H = 1000
local PLUS = "|TInterface\\Buttons\\UI-PlusButton-Up:12:12:0:0|t "
local MINUS = "|TInterface\\Buttons\\UI-MinusButton-Up:12:12:0:0|t "

local function TrackerTheme()
    return AQ.Theme.Tracker
end

local function StripHeaderPrefix(title)
    title = title or ""
    title = title:gsub("^|T.-|t%s*", "")
    title = title:gsub("^%[%+%] ", ""):gsub("^%[%-%] ", "")
    title = title:gsub("^%+  ", ""):gsub("^%-  ", "")
    if title:sub(1, 4) == "▸ " or title:sub(1, 4) == "▾ " then
        title = title:sub(5)
    end
    return title
end

local function DB()
    return AQ.DB.Get()
end

local function Char()
    return AQ.DB.Char()
end

function Tracker.RegisterSection(spec)
    if type(spec) ~= "table" or type(spec.id) ~= "string" then
        return
    end
    if not sections[spec.id] then
        sectionOrder[#sectionOrder + 1] = spec.id
    end
    spec.order = spec.order or 50
    sections[spec.id] = spec
    table.sort(sectionOrder, function(a, b)
        return (sections[a].order or 50) < (sections[b].order or 50)
    end)
end

function Tracker.IsSectionEnabled(id)
    local spec = sections[id]
    if not spec then
        return false
    end
    local db = DB()
    if db.modules and db.modules[id] == false then
        return false
    end
    if spec.requiresPlugin and AQ.Plugins and not AQ.Plugins.IsEnabled(spec.requiresPlugin) then
        return false
    end
    if type(spec.requiresAnyPlugin) == "table" then
        local any = false
        for i = 1, #spec.requiresAnyPlugin do
            if AQ.Plugins and AQ.Plugins.IsEnabled(spec.requiresAnyPlugin[i]) then
                any = true
                break
            end
        end
        if not any then
            return false
        end
    end
    if spec.requiresAddon and not AQ:AddonLoaded(spec.requiresAddon) then
        return false
    end
    return true
end

function Tracker.GetDefaultModuleOrder()
    local ids = {}
    for id in pairs(sections) do
        ids[#ids + 1] = id
    end
    table.sort(ids, function(a, b)
        local oa = sections[a] and sections[a].order or 50
        local ob = sections[b] and sections[b].order or 50
        if oa == ob then
            return a < b
        end
        return oa < ob
    end)
    return ids
end

function Tracker.GetModuleOrder()
    local saved = DB().modulesOrder
    local default = Tracker.GetDefaultModuleOrder()
    if type(saved) ~= "table" or #saved == 0 then
        return default
    end
    local seen = {}
    local out = {}
    for i = 1, #saved do
        local id = saved[i]
        if type(id) == "string" and sections[id] and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    for i = 1, #default do
        local id = default[i]
        if not seen[id] then
            out[#out + 1] = id
        end
    end
    return out
end

function Tracker.MoveModule(id, direction)
    if type(id) ~= "string" then
        return false
    end
    local order = Tracker.GetModuleOrder()
    local idx
    for i = 1, #order do
        if order[i] == id then
            idx = i
            break
        end
    end
    if not idx then
        return false
    end
    local other = idx + ((direction == "up") and -1 or 1)
    if other < 1 or other > #order then
        return false
    end
    order[idx], order[other] = order[other], order[idx]
    DB().modulesOrder = order
    return true
end

function Tracker.ResetModuleOrder()
    DB().modulesOrder = {}
end

function Tracker.GetModuleList()
    local out = {}
    local order = Tracker.GetModuleOrder()
    for i = 1, #order do
        local spec = sections[order[i]]
        if spec then
            out[#out + 1] = spec
        end
    end
    return out
end

local suppressed = {}

function Tracker.Suppress(kind, id)
    if type(kind) ~= "string" or type(id) ~= "number" then
        return
    end
    suppressed[kind .. ":" .. tostring(id)] = true
end

function Tracker.IsSuppressed(kind, id)
    if type(kind) ~= "string" or type(id) ~= "number" then
        return false
    end
    return suppressed[kind .. ":" .. tostring(id)] and true or false
end

function Tracker.ClearSuppress(kind, id)
    if type(kind) ~= "string" or type(id) ~= "number" then
        return
    end
    suppressed[kind .. ":" .. tostring(id)] = nil
end

local function HeaderCollapsed(id)
    local t = Char().collapsedHeaders or {}
    return t[id] and true or false
end

local function SetHeaderCollapsed(id, on)
    local t = Char().collapsedHeaders
    if type(t) ~= "table" then
        t = {}
        Char().collapsedHeaders = t
    end
    t[id] = on and true or nil
end

local function RestoreRowBg(row)
    if not row or not row.Bg then
        return
    end
    if row._showBg and row._bg then
        local c = row._bg
        row.Bg:SetColorTexture(c[1], c[2], c[3], c[4] or 0.14)
        row.Bg:Show()
    else
        row.Bg:Hide()
    end
end

local function HoverSpeechText(data)
    if not data then
        return ""
    end
    if data.kind == "quest" then
        local title = StripHeaderPrefix(data.title or "")
        local st = data.status
        if st == "DONE" or st == "FAILED" then
            return title .. ". " .. st
        end
        return title
    end
    if data.kind == "objective" then
        local title = data.title or ""
        title = title:gsub("^%s+", "")
        title = title:gsub("^%- ", "")
        return title
    end
    if data.kind == "header" then
        return StripHeaderPrefix(data.title or "")
    end
    return StripHeaderPrefix(data.title or data.speech or "")
end

local function SpeakHoveredRow(data)
    if not data then
        return
    end
    if DB().speechEnabled == false then
        return
    end
    local key = tostring(data.kind or "") .. ":" .. tostring(data.questID or data.id or "") .. ":" .. tostring(data.title or "")
    if key == hoverSpeechKey then
        return
    end
    hoverSpeechKey = key
    local text = HoverSpeechText(data)
    if text == "" then
        return
    end
    if AQ.Speech and AQ.Speech.Replace then
        AQ.Speech.Replace(text)
    else
        AQ.Speech.Say(text)
    end
end

local function MakeRow(i)
    local row = CreateFrame("Button", nil, frame.Scroll.Child)
    row:SetHeight(16)
    row:EnableMouse(true)
    row.Bg = row:CreateTexture(nil, "BACKGROUND")
    row.Bg:SetAllPoints()
    row.Bg:Hide()
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(14, 14)
    row.Icon:Hide()
    row.Text = AQ.Widgets.TrackerFontString(row, 12)
    row.Text:SetJustifyV("MIDDLE")
    row.Text:SetWordWrap(false)
    if row.Text.SetMaxLines then
        row.Text:SetMaxLines(1)
    end
    local th = TrackerTheme()
    row.Status = AQ.Widgets.TrackerFontString(row, 11, th.complete[1], th.complete[2], th.complete[3])
    row.Status:SetJustifyH("RIGHT")
    row.Status:SetJustifyV("MIDDLE")
    row.Status:SetWordWrap(false)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, mouse)
        Tracker.Focus(self.index)
        local data = self.data
        if not data then
            return
        end
        if mouse == "RightButton" then
            if IsShiftKeyDown and IsShiftKeyDown() and data.questID
                and AQ.Plugins and AQ.Plugins.IsEnabled("TomTom")
                and AQ.TomTom and AQ.TomTom.WaypointForQuest then
                AQ.TomTom.WaypointForQuest(data.questID, data.title)
                return
            end
            if AQ.Menu and AQ.Menu.Show and AQ.Menu.Show(self, data) then
                return
            end
            if data.questID and AQ.Journal and AQ.Journal.OpenQuest then
                AQ.Journal.OpenQuest(data.questID)
            end
            return
        end
        if data.kind == "header" then
            SetHeaderCollapsed(data.id, not HeaderCollapsed(data.id))
            Tracker.Refresh()
            return
        end
        if AQ.AutoQuest and AQ.AutoQuest.TryHandleTrackerClick and AQ.AutoQuest.TryHandleTrackerClick(data) then
            return
        end
        if data.speciesId then
            if ToggleCollectionsJournal then
                pcall(ToggleCollectionsJournal, COLLECTIONS_JOURNAL_TAB_INDEX_PETS or 2)
            end
            if PetJournal_SelectSpecies and PetJournal then
                pcall(PetJournal_SelectSpecies, PetJournal, data.speciesId)
            end
            return
        end
        if data.rareTarget then
            if (not InCombatLockdown or not InCombatLockdown()) and TargetUnit then
                pcall(TargetUnit, data.rareTarget)
            end
            if data.rareMapID and data.rareX and data.rareY
                and AQ.TomTom and AQ.TomTom.AddPoint
                and AQ.Plugins and AQ.Plugins.IsEnabled("TomTom") then
                AQ.TomTom.AddPoint(data.rareMapID, data.rareX, data.rareY, data.title)
            end
            return
        end
        if data.questID then
            AQ.Compat.SuperTrackQuest(data.questID)
        end
    end)
    row:SetScript("OnEnter", function(self)
        local h = TrackerTheme().hover
        if self.Bg then
            self.Bg:SetColorTexture(h[1], h[2], h[3], h[4] or 0.1)
            self.Bg:Show()
        end
        if self.data then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            local tip = StripHeaderPrefix(self.data.title or "")
            GameTooltip:AddLine(tip, 1, 0.82, 0)
            if self.data.detail then
                GameTooltip:AddLine(self.data.detail, 1, 1, 1, true)
            end
            if self.data.clickComplete or self.data.popupType == "COMPLETE" or (self.data.autoComplete and self.data.status == "DONE") then
                GameTooltip:AddLine("Left-click: complete quest.", 0.1, 1, 0.1, true)
            elseif self.data.popupType == "OFFER" then
                GameTooltip:AddLine("Left-click: accept quest.", 1, 0.82, 0, true)
            else
                GameTooltip:AddLine("Left-click: super-track. Right-click: more options.", 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
            SpeakHoveredRow(self.data)
        end
    end)
    row:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        RestoreRowBg(self)
        hoverSpeechKey = nil
    end)
    rows[i] = row
    return row
end

local function GetRow(i)
    return rows[i] or MakeRow(i)
end

local function HideExtraIcons(row)
    if not row or not row.ExtraIcons then
        return
    end
    for i = 1, #row.ExtraIcons do
        row.ExtraIcons[i]:Hide()
    end
end

local function ApplyIconTex(tex, icon, atlas)
    if not tex then
        return false
    end
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetVertexColor(1, 1, 1, 1)
    if type(atlas) == "string" and atlas ~= "" and tex.SetAtlas then
        local ok = pcall(tex.SetAtlas, tex, atlas, true)
        if ok then
            return true
        end
    end
    if type(icon) == "number" or (type(icon) == "string" and icon ~= "") then
        tex:SetTexture(icon)
        return true
    end
    return false
end

local function ClockText(sec)
    sec = math.floor(tonumber(sec) or 0)
    if sec < 0 then
        sec = 0
    end
    if SecondsToClock then
        local ok, text = pcall(SecondsToClock, sec)
        if ok and type(text) == "string" then
            return text
        end
    end
    local m = math.floor(sec / 60)
    local s = sec - m * 60
    return string.format("%d:%02d", m, s)
end

local function ReadElapsed(timerID)
    if type(timerID) ~= "number" or not GetWorldElapsedTime then
        return nil
    end
    local a, b, c = AQ:SafeCall(GetWorldElapsedTime, timerID)
    if type(c) == "number" then
        return tonumber(b)
    end
    return tonumber(a) or tonumber(b)
end

local function EnsureBar(row)
    if row.Bar then
        return row.Bar
    end
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetHeight(5)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.12, 0.7)
    bar.AQBg = bg
    row.Bar = bar
    return bar
end

local function UpdateTimerRow(row)
    local data = row.data
    if not data or data.kind ~= "timer" then
        return
    end
    local elapsed = data.elapsed or 0
    local live = ReadElapsed(data.timerID)
    if live then
        elapsed = live
        data.elapsed = live
    end
    local limit = tonumber(data.timeLimit) or 0
    local remaining = elapsed
    local pct = 0
    if data.countdown and limit > 0 then
        remaining = math.max(0, limit - elapsed)
        pct = remaining / limit
    elseif limit > 0 then
        pct = math.min(1, elapsed / limit)
    end
    local clock = ClockText(remaining)
    row.Status:SetText(clock)
    row.Status:Show()
    local th = TrackerTheme()
    if data.countdown and remaining <= 0 then
        local a = th.failed
        row.Status:SetTextColor(a[1], a[2], a[3], 1)
        row.Text:SetTextColor(a[1], a[2], a[3], 1)
    else
        local a = th.header
        row.Status:SetTextColor(a[1], a[2], a[3], 1)
    end
    if row.Bar then
        row.Bar:SetMinMaxValues(0, 1)
        row.Bar:SetValue(pct)
        if data.countdown and remaining <= 0 then
            local a = th.failed
            row.Bar:SetStatusBarColor(a[1], a[2], a[3], 0.9)
        else
            local a = th.header
            row.Bar:SetStatusBarColor(a[1], a[2], a[3], 0.9)
        end
        row.Bar:Show()
    end
end

local function TimerOnUpdate(self, elapsed)
    self._aqTimer = (self._aqTimer or 0) + elapsed
    if self._aqTimer < 0.2 then
        return
    end
    self._aqTimer = 0
    UpdateTimerRow(self)
end

local function CollectRows()
    local out = {}
    local order = Tracker.GetModuleOrder and Tracker.GetModuleOrder() or sectionOrder
    for s = 1, #order do
        local spec = sections[order[s]]
        if spec and type(spec.GetRows) == "function" then
                if not Tracker.IsSectionEnabled(spec.id) then
                    -- skipped
                else
                local ok, list = pcall(spec.GetRows)
                if ok and type(list) == "table" and #list > 0 then
                    local sectionId = spec.id
                    local collapsed = HeaderCollapsed("section:" .. sectionId)
                    out[#out + 1] = {
                        kind = "header",
                        id = "section:" .. sectionId,
                        title = (collapsed and PLUS or MINUS) .. (spec.title or spec.id),
                        speech = (spec.title or spec.id) .. (collapsed and " collapsed" or " expanded"),
                        fontSize = 13,
                    }
                    if not collapsed then
                        local skipBody = false
                        for i = 1, #list do
                            local row = list[i]
                            if row.kind == "header" then
                                local hid = row.id
                                skipBody = hid and HeaderCollapsed(hid) or false
                                local title = StripHeaderPrefix(row.title)
                                row.title = (skipBody and PLUS or MINUS) .. title
                                row.speech = row.speech or ((row.title or "Header") .. (skipBody and " collapsed" or " expanded"))
                                out[#out + 1] = row
                            elseif not skipBody then
                                out[#out + 1] = row
                            end
                        end
                    end
                end
                end
        end
    end
    return out
end

local function Layout()
    builtRows = CollectRows()
    local width = DB().trackerWidth or 320
    local showItems = AQ.DB.Get().trackerShowItemButtons ~= false
    local itemList = {}
    local extraLink
    local seenItem = {}
    if showItems then
        for i = 1, #builtRows do
            local d = builtRows[i]
            if d.kind == "quest" and d.itemLink and d.questID and not seenItem[d.questID] then
                seenItem[d.questID] = true
                local idx = #itemList + 1
                d.itemIndex = idx
                itemList[idx] = {
                    questID = d.questID,
                    link = d.itemLink,
                    logIndex = d.logIndex,
                    charges = d.itemCharges,
                    texture = d.itemTexture,
                    index = idx,
                }
                extraLink = extraLink or d.itemLink
            end
        end
    end
    local y = 0
    local count = 0
    for i = 1, #builtRows do
        local data = builtRows[i]
        local row = GetRow(i)
        row:Show()
        row.index = i
        row.data = data
        local indent = 2
        if data.kind == "header" then
            indent = 2
        elseif data.kind == "quest" or data.kind == "timer" then
            indent = 16
        elseif data.kind == "objective" then
            indent = 28
        end
        local h = 16
        if data.kind == "objective" then
            h = 14
        elseif data.kind == "header" then
            h = 18
        elseif data.kind == "timer" then
            h = 26
        end
        if data.kind == "header" and i > 1 then
            y = y + 6
        end
        row:SetHeight(h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("RIGHT", frame.Scroll.Child, "RIGHT", 0, 0)

        local st = data.status
        local th = TrackerTheme()
        local showBg = false
        local col = th.focus
        if i == focused then
            showBg = true
            col = th.focus
        end
        row._showBg = showBg
        row._bg = col
        RestoreRowBg(row)
        if row.Bar then
            row.Bar:Hide()
        end
        if row.Rule then
            row.Rule:Hide()
        end
        HideExtraIcons(row)
        row:SetScript("OnUpdate", nil)

        local iconW = 0
        if row.Icon then
            row.Icon:Hide()
            row.Icon:SetTexCoord(0, 1, 0, 1)
            row.Icon:SetVertexColor(1, 1, 1, 1)
            local shown = ApplyIconTex(row.Icon, data.icon, data.atlas)
            if not shown and data.kind == "quest" then
                local spec = AQ.Compat.GetQuestIconSpec and AQ.Compat.GetQuestIconSpec(data)
                if spec then
                    shown = ApplyIconTex(row.Icon, spec.file, spec.atlas)
                end
            end
            if shown then
                row.Icon:ClearAllPoints()
                row.Icon:SetSize(14, 14)
                row.Icon:SetPoint("LEFT", 4 + indent, 0)
                row.Icon:Show()
                iconW = 18
            end
        end

        local extraW = 0
        if type(data.icons) == "table" and #data.icons > 0 then
            row.ExtraIcons = row.ExtraIcons or {}
            local x = 0
            for n = 1, #data.icons do
                local spec = data.icons[n]
                local tex = row.ExtraIcons[n]
                if not tex then
                    tex = row:CreateTexture(nil, "ARTWORK")
                    tex:SetSize(14, 14)
                    row.ExtraIcons[n] = tex
                end
                if type(spec) == "table" and ApplyIconTex(tex, spec.file or spec.icon, spec.atlas) then
                    tex:ClearAllPoints()
                    tex:SetPoint("RIGHT", -2 - x, 0)
                    tex:Show()
                    x = x + 16
                    extraW = extraW + 16
                else
                    tex:Hide()
                end
            end
        end

        local title = data.title or ""
        if data.kind == "quest" and data.level then
            title = string.format("[%d] %s", data.level, title)
        end
        if data.kind == "objective" then
            title = title:gsub("^%s+", ""):gsub(" %(complete%)$", "")
            if not data.clickComplete then
                title = "-  " .. title
            end
        end
        row.Text:SetText(title)
        local fs = data.fontSize or (data.kind == "objective" and 11 or 12)
        if data.kind == "header" then
            fs = data.fontSize or 13
        end
        AQ.Widgets.SetTrackerFont(row.Text, fs)
        row.Text:SetWordWrap(false)
        if row.Text.SetMaxLines then
            row.Text:SetMaxLines(1)
        end

        local hasItem = data.itemIndex and showItems
        local itemW = hasItem and 16 or 0
        local statusLabel = nil
        local statusCol = th.complete
        if data.kind == "timer" then
            statusLabel = "0:00"
            statusCol = th.header
        elseif st == "DONE" then
            statusLabel = "Complete"
            statusCol = th.complete
        elseif st == "FAILED" then
            statusLabel = "Failed"
            statusCol = th.failed
        elseif st == "READY" then
            statusLabel = "Ready"
            statusCol = th.header
        elseif st == "LOCKED" then
            statusLabel = "Locked"
            statusCol = th.tag
        end
        local statusW = statusLabel and 64 or 0
        if data.kind == "timer" then
            statusW = 56
        end
        row.Status:ClearAllPoints()
        row.Text:ClearAllPoints()
        local textY = (data.kind == "timer") and 4 or 0
        row.Text:SetPoint("LEFT", 4 + indent + iconW, textY)
        row.Text:SetPoint("RIGHT", -(6 + statusW + itemW + extraW), textY)
        if statusLabel then
            row.Status:SetText(statusLabel)
            row.Status:SetWidth(statusW)
            row.Status:SetPoint("RIGHT", -2 - itemW - extraW, textY)
            row.Status:SetTextColor(statusCol[1], statusCol[2], statusCol[3], 1)
            AQ.Widgets.SetTrackerFont(row.Status, 11)
            row.Status:SetWordWrap(false)
            if row.Status.SetMaxLines then
                row.Status:SetMaxLines(1)
            end
            row.Status:Show()
        else
            row.Status:SetText("")
            row.Status:Hide()
        end
        if data.kind == "header" then
            local a = th.header
            row.Text:SetTextColor(a[1], a[2], a[3], 1)
        elseif data.kind == "timer" then
            local a = th.header
            row.Text:SetTextColor(a[1], a[2], a[3], 1)
        elseif data.kind == "quest" and st == "DONE" then
            local a = th.complete
            row.Text:SetTextColor(a[1], a[2], a[3], 1)
        elseif data.kind == "quest" and st == "FAILED" then
            local a = th.failed
            row.Text:SetTextColor(a[1], a[2], a[3], 1)
        elseif data.kind == "quest" and AQ.DB.Get().trackerDifficultyColors ~= false and type(data.level) == "number" then
            local a = AQ.Theme.QuestDifficultyColor(data.level)
            row.Text:SetTextColor(a[1], a[2], a[3], a[4] or 1)
        elseif data.kind == "quest" and i == focused then
            local a = th.header
            row.Text:SetTextColor(a[1], a[2], a[3], 1)
        elseif data.kind == "objective" and (data.finished or data.clickComplete) then
            local a = th.complete
            if AQ.DB.Get().trackerObjectiveProgressColors ~= false and AQ.Theme.ObjectiveProgressColor then
                a = AQ.Theme.ObjectiveProgressColor(data)
            end
            row.Text:SetTextColor(a[1], a[2], a[3], a[4] or 1)
        elseif data.kind == "objective" then
            local a = th.objective
            if AQ.DB.Get().trackerObjectiveProgressColors ~= false and AQ.Theme.ObjectiveProgressColor then
                a = AQ.Theme.ObjectiveProgressColor(data)
            end
            row.Text:SetTextColor(a[1], a[2], a[3], a[4] or 1)
        else
            local a = th.title
            row.Text:SetTextColor(a[1], a[2], a[3], 1)
        end
        if data.kind == "timer" then
            local bar = EnsureBar(row)
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", 4 + indent + iconW, 3)
            bar:SetPoint("BOTTOMRIGHT", -6 - extraW, 3)
            UpdateTimerRow(row)
            row:SetScript("OnUpdate", TimerOnUpdate)
        end
        if hasItem then
            if not row.ItemTag then
                row.ItemTag = AQ.Widgets.TrackerFontString(row, 11, 1, 0.82, 0)
                row.ItemTag:SetJustifyH("RIGHT")
            end
            row.ItemTag:ClearAllPoints()
            row.ItemTag:SetPoint("RIGHT", -2, 0)
            row.ItemTag:SetText(tostring(data.itemIndex))
            row.ItemTag:Show()
        elseif row.ItemTag then
            row.ItemTag:Hide()
        end
        y = y + h
        count = i
    end
    for i = count + 1, #rows do
        rows[i]:Hide()
        rows[i].data = nil
        rows[i]:SetScript("OnUpdate", nil)
        HideExtraIcons(rows[i])
        if rows[i].Bar then
            rows[i].Bar:Hide()
        end
        if rows[i].ItemTag then
            rows[i].ItemTag:Hide()
        end
    end
    if not sizing then
        frame:SetWidth(width)
    end
    frame.Scroll.Child:SetSize((frame:GetWidth() or width) - 16, math.max(y, 1))
    local maxH = DB().trackerMaxHeight or 520
    local headerH = 28
    local collapsed = Char().trackerCollapsed or DB().trackerCollapsed
    if not sizing then
        if collapsed then
            frame:SetHeight(headerH)
            frame.Scroll:Hide()
        else
            frame.Scroll:Show()
            local manualH = DB().trackerHeight
            if type(manualH) == "number" then
                if manualH < MIN_TRACKER_H then
                    manualH = MIN_TRACKER_H
                elseif manualH > MAX_TRACKER_H then
                    manualH = MAX_TRACKER_H
                end
                frame:SetHeight(manualH)
            else
                frame:SetHeight(math.min(maxH, math.max(MIN_TRACKER_H, headerH + y + 8)))
            end
        end
    end
    local empty = #builtRows == 0
    if empty and DB().trackerHideEmpty then
        frame:Hide()
    elseif DB().trackerEnabled ~= false then
        frame:Show()
    end
    if AQ.Items and AQ.Items.UpdateColumn then
        local closest = extraLink
        if AQ.Items.PeekExtra then
            closest = AQ.Items.PeekExtra() or extraLink
        end
        AQ.Items.UpdateColumn(itemList, closest)
    end
    UpdateChrome()
end

local function Tip(btn, text)
    btn.AQTip = text
    local enter = btn:GetScript("OnEnter")
    local leave = btn:GetScript("OnLeave")
    btn:SetScript("OnEnter", function(self)
        if enter then
            enter(self)
        end
        local tip = self.AQTip
        if tip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:AddLine(tip, 1, 0.82, 0, true)
            GameTooltip:Show()
            if AQ.Speech and AQ.Speech.Replace then
                AQ.Speech.Replace(tip)
            elseif AQ.Speech then
                AQ.Speech.Say(tip)
            end
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if leave then
            leave(self)
        end
        GameTooltip:Hide()
    end)
end

UpdateChrome = function()
    if not frame then
        return
    end
    local locked = DB().trackerLocked and true or false
    frame:SetMovable(not locked)
    if frame.SetResizable then
        frame:SetResizable(not locked)
    end
    if frame.ResizeGrip then
        if locked or Char().trackerCollapsed or DB().trackerCollapsed then
            frame.ResizeGrip:Hide()
        else
            frame.ResizeGrip:Show()
        end
    end
    if frame.Lock and frame.Lock.Icon then
        if locked then
            frame.Lock.Icon:SetTexture("Interface\\Buttons\\LockButton-Locked-Up")
        else
            frame.Lock.Icon:SetTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
        end
        frame.Lock.AQTip = locked and "Unlock tracker to move and resize" or "Lock tracker position and size"
        local a = TrackerTheme().header
        frame.Lock.Icon:SetVertexColor(a[1], a[2], a[3], 1)
    end
    local collapsed = Char().trackerCollapsed or DB().trackerCollapsed
    if frame.Collapse and frame.Collapse.Label then
        frame.Collapse.Label:SetText(collapsed and "+" or "-")
        frame.Collapse.AQTip = collapsed and "Expand tracker" or "Minimize tracker"
        local a = TrackerTheme().header
        frame.Collapse.Label:SetTextColor(a[1], a[2], a[3], 1)
    end
    if frame.Journal then
        local jf = _G["AllQuestJournalFrame"]
        local open = jf and jf:IsShown()
        frame.Journal.AQTip = open and "Close questline journal" or "Open questline journal"
    end
end

local function ClampSize(w, h)
    if w < MIN_TRACKER_W then
        w = MIN_TRACKER_W
    elseif w > MAX_TRACKER_W then
        w = MAX_TRACKER_W
    end
    if h < MIN_TRACKER_H then
        h = MIN_TRACKER_H
    elseif h > MAX_TRACKER_H then
        h = MAX_TRACKER_H
    end
    return w, h
end

local function SaveSize()
    if not frame then
        return
    end
    local w = liveW or frame:GetWidth() or DB().trackerWidth or 320
    local h = liveH or frame:GetHeight() or DB().trackerMaxHeight or 520
    w = math.floor(w + 0.5)
    h = math.floor(h + 0.5)
    w, h = ClampSize(w, h)
    DB().trackerWidth = w
    DB().trackerMaxHeight = h
    DB().trackerHeight = h
end

local function SavePoint()
    if not frame then
        return
    end
    local p, _, rel, x, y = frame:GetPoint(1)
    if not p then
        return
    end
    DB().trackerPoint = p
    DB().trackerRelativePoint = rel or p
    DB().trackerX = x
    DB().trackerY = y
end

local function ParentXY(frameX, frameY)
    local fs = frame:GetEffectiveScale() or 1
    local us = (UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()) or 1
    if us == 0 then
        us = 1
    end
    return frameX * fs / us, frameY * fs / us
end

local function SizeTick()
    if not sizing or not frame then
        return
    end
    local scale = frame:GetEffectiveScale() or 1
    if scale == 0 then
        scale = 1
    end
    local mx, my = GetCursorPosition()
    mx = mx / scale
    my = my / scale
    local left = frame:GetLeft()
    local top = frame:GetTop()
    if not left or not top then
        return
    end
    local w, h = ClampSize(mx - left, top - my)
    frame:SetWidth(w)
    frame:SetHeight(h)
    liveW, liveH = w, h
    if frame.Scroll and frame.Scroll.Child then
        frame.Scroll.Child:SetWidth(math.max(1, w - 16))
    end
end

local function DragStart(self)
    if DB().trackerLocked or sizing then
        return
    end
    frame:StartMoving()
end

local function DragStop(self)
    if sizing then
        return
    end
    frame:StopMovingOrSizing()
    SavePoint()
    if AQ.Items and AQ.Items.AnchorColumn then
        AQ.Items.AnchorColumn(frame)
    end
end

local function SizeStart()
    if DB().trackerLocked or sizing then
        return
    end
    if frame.StopMovingOrSizing then
        frame:StopMovingOrSizing()
    end
    local left = frame:GetLeft()
    local top = frame:GetTop()
    if not left or not top then
        return
    end
    local x, y = ParentXY(left, top)
    frame:SetClampedToScreen(false)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    sizing = true
    liveW = frame:GetWidth()
    liveH = frame:GetHeight()
end

local function SizeStop()
    if not sizing then
        return
    end
    sizing = false
    SaveSize()
    frame:SetClampedToScreen(true)
    SavePoint()
    liveW, liveH = nil, nil
    if AQ.Items and AQ.Items.AnchorColumn then
        AQ.Items.AnchorColumn(frame)
    end
    Tracker.Refresh()
end

local function Ensure()
    if frame then
        return frame
    end
    frame = CreateFrame("Frame", "AllQuestTrackerFrame", UIParent, "BackdropTemplate")
    frame:SetSize(DB().trackerWidth or 320, 200)
    frame:SetClampedToScreen(true)
    frame:SetMovable(not DB().trackerLocked)
    if frame.SetResizable then
        frame:SetResizable(not DB().trackerLocked)
    end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_TRACKER_W, MIN_TRACKER_H, MAX_TRACKER_W, MAX_TRACKER_H)
    else
        if frame.SetMinResize then
            frame:SetMinResize(MIN_TRACKER_W, MIN_TRACKER_H)
        end
        if frame.SetMaxResize then
            frame:SetMaxResize(MAX_TRACKER_W, MAX_TRACKER_H)
        end
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", DragStart)
    frame:SetScript("OnDragStop", DragStop)
    frame:SetScript("OnSizeChanged", function(self)
        if sizing then
            liveW = self:GetWidth() or liveW
            liveH = self:GetHeight() or liveH
        end
    end)
    AQ.Widgets.ApplyTrackerBackdrop(frame)
    local db = DB()
    frame:SetPoint(
        db.trackerPoint or "TOPRIGHT",
        UIParent,
        db.trackerRelativePoint or db.trackerPoint or "TOPRIGHT",
        db.trackerX or -180,
        db.trackerY or -220
    )
    frame:SetScale(db.trackerScale or 1)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 8, -6)
    header:SetPoint("TOPRIGHT", -8, -6)
    header:SetHeight(20)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", DragStart)
    header:SetScript("OnDragStop", DragStop)
    frame.Header = header

    local rule = header:CreateTexture(nil, "ARTWORK")
    local rc = TrackerTheme().rule
    rule:SetColorTexture(rc[1], rc[2], rc[3], rc[4] or 0.4)
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", 0, -2)
    rule:SetPoint("BOTTOMRIGHT", 0, -2)
    frame.HeaderRule = rule

    local close = AQ.Widgets.TrackerButton(header, "x", 16, 18)
    close:SetPoint("RIGHT", 0, 0)
    close:SetScript("OnClick", function()
        DB().trackerEnabled = false
        Tracker.Refresh()
        AQ.Speech.Say("Tracker closed")
    end)
    Tip(close, "Close tracker")
    frame.Close = close

    local collapse = AQ.Widgets.TrackerButton(header, "-", 16, 18)
    collapse:SetPoint("RIGHT", close, "LEFT", -2, 0)
    collapse:SetScript("OnClick", function()
        Char().trackerCollapsed = not Char().trackerCollapsed
        Tracker.Refresh()
        AQ.Speech.Say(Char().trackerCollapsed and "Tracker minimized" or "Tracker expanded")
    end)
    Tip(collapse, "Minimize tracker")
    frame.Collapse = collapse

    local lock = AQ.Widgets.TrackerIconButton(header, "Interface\\Buttons\\LockButton-Unlocked-Up", 18, 18)
    lock:SetPoint("RIGHT", collapse, "LEFT", -2, 0)
    lock:SetScript("OnClick", function()
        DB().trackerLocked = not DB().trackerLocked
        UpdateChrome()
        AQ.Speech.Say(DB().trackerLocked and "Tracker locked" or "Tracker unlocked. Drag the corner to resize.")
    end)
    Tip(lock, "Lock tracker position and size")
    frame.Lock = lock

    local journal = AQ.Widgets.TrackerIconButton(header, "Interface\\QuestFrame\\UI-QuestLog-BookIcon", 18, 18, true)
    journal:SetPoint("RIGHT", lock, "LEFT", -2, 0)
    journal:SetScript("OnClick", function()
        if AQ.Journal then
            AQ.Journal.Toggle()
        end
        UpdateChrome()
    end)
    Tip(journal, "Open questline journal")
    frame.Journal = journal

    local settings = AQ.Widgets.TrackerIconButton(header, "Interface\\WorldMap\\Gear_64Grey", 18, 18, true)
    settings:SetPoint("RIGHT", journal, "LEFT", -2, 0)
    settings:SetScript("OnClick", function()
        if AQ.Settings and AQ.Settings.Toggle then
            AQ.Settings.Toggle()
        end
        AQ.Speech.Say("Settings")
    end)
    Tip(settings, "Open settings")
    frame.SettingsBtn = settings

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetSize(22, 22)
    logo:SetPoint("LEFT", 0, 0)
    logo:SetTexture(AQ.Logo)
    frame.Logo = logo

    local th = TrackerTheme()
    local title = AQ.Widgets.TrackerFontString(header, 13, th.header[1], th.header[2], th.header[3])
    title:SetPoint("LEFT", logo, "RIGHT", 4, 0)
    title:SetPoint("RIGHT", settings, "LEFT", -6, 0)
    title:SetWordWrap(false)
    title:SetText("AllQuest")
    frame.Title = title
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(header, "AllQuest tracker")
    end

    local scroll = AQ.Widgets.Scroll(frame, "AllQuestTrackerScroll")
    AQ.Widgets.HideScrollBar(scroll)
    scroll:SetPoint("TOPLEFT", 10, -30)
    scroll:SetPoint("BOTTOMRIGHT", -10, 8)
    frame.Scroll = scroll

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(20, 20)
    grip:SetPoint("BOTTOMRIGHT", -1, 1)
    grip:SetFrameLevel(frame:GetFrameLevel() + 6)
    grip:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
    local gtex = grip:CreateTexture(nil, "ARTWORK")
    gtex:SetAllPoints()
    gtex:SetTexture("Interface\\ChatFrame\\UI-ChatFrame-ResizeGrip")
    grip.Texture = gtex
    grip:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then
            return
        end
        SizeStart()
        self:SetScript("OnUpdate", function(btn)
            if not IsMouseButtonDown or not IsMouseButtonDown("LeftButton") then
                btn:SetScript("OnUpdate", nil)
                SizeStop()
                return
            end
            SizeTick()
        end)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        SizeStop()
    end)
    grip:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        if sizing then
            SizeStop()
        end
    end)
    Tip(grip, "Drag to resize tracker")
    frame.ResizeGrip = grip

    UpdateChrome()
    return frame
end

function Tracker.GetFrame()
    return frame
end

function Tracker.Focus(index)
    if type(index) ~= "number" then
        return
    end
    if index < 1 then
        index = 1
    end
    if index > #builtRows then
        index = #builtRows
    end
    focused = index
    local data = builtRows[focused]
    AQ.Events.Fire("AQ_FOCUS_CHANGED", "tracker", data)
    Layout()
end

function Tracker.ReadFocus()
    local data = builtRows[focused]
    if data then
        AQ.Speech.Say(data.speech or data.title or "Empty tracker row", true)
    else
        AQ.Speech.Say("Tracker is empty", true)
    end
end

function Tracker.MoveFocus(delta)
    Tracker.Focus(focused + delta)
end

local instanceState = nil

function Tracker.Refresh()
    if refreshPending then
        return
    end
    refreshPending = true
    local function go()
        refreshPending = false
        if sizing then
            return
        end
        Ensure()
        if DB().trackerEnabled == false then
            frame:Hide()
            if AQ.Items and AQ.Items.UpdateColumn then
                AQ.Items.UpdateColumn(nil, nil)
            end
            return
        end
        local inInst = AQ.Compat.IsInInstance()
        if DB().trackerCollapseInInstance then
            if inInst then
                if instanceState ~= true then
                    if instanceState == false then
                        Char()._preInstanceCollapsed = Char().trackerCollapsed
                    end
                    Char().trackerCollapsed = true
                end
                instanceState = true
            else
                if instanceState == true then
                    Char().trackerCollapsed = Char()._preInstanceCollapsed and true or false
                    Char()._preInstanceCollapsed = nil
                end
                instanceState = false
            end
        else
            instanceState = inInst and true or false
        end
        Layout()
        if AQ.HideBlizzard then
            AQ.HideBlizzard.Apply()
        end
        AQ.Events.Fire("AQ_TRACKER_REFRESH")
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, go)
    else
        go()
    end
end

function Tracker.Toggle()
    local on = DB().trackerEnabled ~= false
    DB().trackerEnabled = not on
    Tracker.Refresh()
    AQ.Speech.Say(DB().trackerEnabled and "Tracker shown" or "Tracker hidden")
end

function Tracker.Init()
    Ensure()
    Tracker.Refresh()
end

AQ.Events.Register("QUEST_AUTOCOMPLETE", function()
    Tracker.Refresh()
end)
AQ.Events.Register("QUEST_LOG_UPDATE", function()
    Tracker.Refresh()
end)
AQ.Events.Register("QUEST_WATCH_UPDATE", function()
    Tracker.Refresh()
end)
AQ.Events.Register("QUEST_WATCH_LIST_CHANGED", function()
    Tracker.Refresh()
end)
AQ.Events.Register("PLAYER_ENTERING_WORLD", function()
    Tracker.Refresh()
end)
AQ.Events.Register("ZONE_CHANGED", function()
    Tracker.Refresh()
end)
AQ.Events.Register("ZONE_CHANGED_NEW_AREA", function()
    Tracker.Refresh()
end)
AQ.Events.Register("PET_JOURNAL_LIST_UPDATE", function()
    Tracker.Refresh()
end)
AQ.Events.Register("QUEST_ACCEPTED", function(_, arg1, arg2)
    local questID = AQ.Compat.QuestIDFromAccepted(arg1, arg2)
    if questID and AQ.Tracker.ClearSuppress then
        AQ.Tracker.ClearSuppress("quest", questID)
    end
    if AQ.DB.Get().trackerAutoWatch then
        if questID then
            AQ.Compat.AddQuestWatch(questID)
        end
    end
    Tracker.Refresh()
end)
AQ.Events.Register("QUEST_REMOVED", function()
    Tracker.Refresh()
end)
AQ.Events.Register("QUEST_TURNED_IN", function()
    Tracker.Refresh()
end)
AQ.Events.Register("UNIT_QUEST_LOG_CHANGED", function()
    Tracker.Refresh()
end)
