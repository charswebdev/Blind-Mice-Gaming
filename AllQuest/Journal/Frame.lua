--[[
  AllQuest — questline journal window
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Journal = AQ.Journal or {}
local Journal = AQ.Journal

local frame

local function DB()
    return AQ.DB.Get()
end

local function Relayout()
    if not frame or not frame.Scroll then
        return
    end
    local top = -72
    if frame.SearchWrap and frame.SearchWrap:IsShown() then
        top = -108
    end
    frame.Scroll:ClearAllPoints()
    frame.Scroll:SetPoint("TOPLEFT", 12, top)
    frame.Scroll:SetPoint("BOTTOMRIGHT", -12, 40)
end

local function SetSearchOpen(open)
    if not frame or not frame.SearchWrap then
        return
    end
    if open then
        frame.SearchWrap:Show()
        if frame.SearchBox then
            frame.SearchBox:SetFocus()
        end
    else
        frame.SearchWrap:Hide()
        if frame.SearchBox then
            frame.SearchBox:ClearFocus()
            frame.SearchBox:SetText("")
        end
        if AQ.Journal.ListView and AQ.Journal.ListView.SetSearch then
            AQ.Journal.ListView.SetSearch("")
        end
    end
    Relayout()
end

local function UpdateGridIcon()
    if not frame or not frame.GridBtn then
        return
    end
    local grid = DB().journalGrid ~= false
    local icons = AQ.Media and AQ.Media.Icons
    if icons then
        if grid then
            frame.GridBtn.Icon:SetTexture(icons.Grid)
            frame.GridBtn.AQTip = "Switch to list view"
        else
            frame.GridBtn.Icon:SetTexture(icons.List)
            frame.GridBtn.AQTip = "Switch to grid view"
        end
    end
end

local function Ensure()
    if frame then
        return frame
    end
    frame = CreateFrame("Frame", "AllQuestJournalFrame", UIParent, "BackdropTemplate")
    frame:SetSize(DB().journalWidth or 760, DB().journalHeight or 560)
    frame:SetPoint(DB().journalPoint or "CENTER", UIParent, DB().journalPoint or "CENTER", DB().journalX or 0, DB().journalY or 0)
    frame:SetFrameStrata("HIGH")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, "AllQuestJournalFrame")
    AQ.Widgets.ApplyTrackerBackdrop(frame)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, _, x, y = self:GetPoint(1)
        DB().journalPoint = p
        DB().journalX = x
        DB().journalY = y
    end)

    local icons = AQ.Media and AQ.Media.Icons or {}

    local close = AQ.Widgets.MediaIconButton(frame, icons.Close, 28, "Close")
    close:SetPoint("TOPRIGHT", -10, -10)
    close:SetScript("OnClick", function()
        frame:Hide()
        AQ.Speech.Say("Journal closed")
    end)
    frame.Close = close

    local zone = AQ.Widgets.Dropdown(frame, { width = 168, height = 28, placeholder = "Zone" })
    zone:SetPoint("RIGHT", close, "LEFT", -8, 0)
    zone:SetCallback(function(value)
        if AQ.Journal.ListView and AQ.Journal.ListView.OnZonePicked then
            AQ.Journal.ListView.OnZonePicked(value)
        end
    end)
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(zone, function()
            local label = (zone.AQLabel and zone.AQLabel:GetText()) or "Zone"
            return "Zone. " .. label
        end)
    end
    frame.ZoneDrop = zone

    local here = AQ.Widgets.MediaIconButton(frame, icons.Here, 28, "Here. Jump to current zone")
    here:SetPoint("RIGHT", zone, "LEFT", -8, 0)
    here:SetScript("OnClick", function()
        if AQ.Journal.ListView then
            AQ.Journal.ListView.Here()
        end
    end)
    frame.Here = here

    local gridBtn = AQ.Widgets.MediaIconButton(frame, icons.Grid, 28, "Switch to list view")
    gridBtn:SetPoint("RIGHT", here, "LEFT", -6, 0)
    gridBtn:SetScript("OnClick", function()
        DB().journalGrid = not (DB().journalGrid ~= false)
        UpdateGridIcon()
        if AQ.Journal.ListView then
            AQ.Journal.ListView.Refresh()
        end
        if DB().journalGrid ~= false then
            AQ.Speech.Say("Grid view")
        else
            AQ.Speech.Say("List view")
        end
    end)
    frame.GridBtn = gridBtn

    local searchBtn = AQ.Widgets.MediaIconButton(frame, icons.Search, 28, "Search")
    searchBtn:SetPoint("RIGHT", gridBtn, "LEFT", -6, 0)
    searchBtn:SetScript("OnClick", function()
        local open = not (frame.SearchWrap and frame.SearchWrap:IsShown())
        SetSearchOpen(open)
        if open then
            AQ.Speech.Say("Search")
        else
            AQ.Speech.Say("Search closed")
            if AQ.Journal.ListView then
                AQ.Journal.ListView.Refresh()
            end
        end
    end)
    frame.SearchBtn = searchBtn

    local back = AQ.Widgets.MediaIconButton(frame, icons.Back, 28, "Back")
    back:SetPoint("RIGHT", searchBtn, "LEFT", -6, 0)
    back:SetScript("OnClick", function()
        if AQ.Journal.ListView then
            AQ.Journal.ListView.Back()
        end
    end)
    frame.Back = back

    local home = AQ.Widgets.MediaIconButton(frame, icons.Home, 28, "Home")
    home:SetPoint("RIGHT", back, "LEFT", -6, 0)
    home:SetScript("OnClick", function()
        if AQ.Journal.ListView then
            AQ.Journal.ListView.Home()
        end
    end)
    frame.Home = home

    local titleHit = CreateFrame("Frame", nil, frame)
    titleHit:SetPoint("TOPLEFT", 16, -8)
    titleHit:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 16, -40)
    titleHit:SetPoint("RIGHT", home, "LEFT", -10, 0)
    titleHit:EnableMouse(true)
    local logo = titleHit:CreateTexture(nil, "ARTWORK")
    logo:SetSize(24, 24)
    logo:SetPoint("LEFT", 0, 0)
    logo:SetTexture(AQ.Logo)
    frame.Logo = logo
    local title = AQ.Widgets.FontString(titleHit, 20, AQ.Theme.accent[1], AQ.Theme.accent[2], AQ.Theme.accent[3])
    title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    title:SetText("AllQuest Journal")
    frame.Title = title
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(titleHit, "AllQuest Journal")
    end

    local pathHit = CreateFrame("Frame", nil, frame)
    pathHit:SetPoint("TOPLEFT", 16, -42)
    pathHit:SetPoint("RIGHT", -16, 0)
    pathHit:SetHeight(22)
    pathHit:EnableMouse(true)
    local path = AQ.Widgets.FontString(pathHit, 14, AQ.Theme.hint[1], AQ.Theme.hint[2], AQ.Theme.hint[3])
    path:SetPoint("LEFT", 0, 0)
    path:SetPoint("RIGHT", 0, 0)
    frame.Path = path
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(pathHit, function()
            return (frame.Path and frame.Path:GetText()) or "Journal path"
        end)
    end

    local searchWrap = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    searchWrap:SetHeight(28)
    searchWrap:SetPoint("TOPLEFT", 12, -66)
    searchWrap:SetPoint("TOPRIGHT", -12, -66)
    AQ.Widgets.ApplyBackdrop(searchWrap, 2)
    searchWrap:Hide()
    frame.SearchWrap = searchWrap

    local searchBox = CreateFrame("EditBox", "AllQuestJournalSearch", searchWrap)
    searchBox:SetAutoFocus(false)
    searchBox:EnableMouse(true)
    searchBox:SetAllPoints()
    searchBox:SetTextInsets(8, 8, 0, 0)
    local fontOk = searchBox:SetFont(AQ.Theme.FontPath(), AQ.Theme.FontSize(14), "OUTLINE")
    if not fontOk then
        searchBox:SetFontObject(GameFontHighlight)
    end
    searchBox:SetTextColor(1, 1, 1, 1)
    searchBox:SetMaxLetters(80)
    searchBox:SetScript("OnTextChanged", function(self)
        if AQ.Journal.ListView and AQ.Journal.ListView.SetSearch then
            AQ.Journal.ListView.SetSearch(self:GetText() or "")
        end
    end)
    searchBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        SetSearchOpen(false)
        if AQ.Journal.ListView then
            AQ.Journal.ListView.Refresh()
        end
    end)
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(searchWrap, "Search box")
    end
    frame.SearchBox = searchBox

    local scroll = AQ.Widgets.Scroll(frame, "AllQuestJournalScroll")
    frame.Scroll = scroll
    Relayout()

    local hintHit = CreateFrame("Frame", nil, frame)
    hintHit:SetPoint("BOTTOMLEFT", 16, 8)
    hintHit:SetPoint("BOTTOMRIGHT", -16, 8)
    hintHit:SetHeight(20)
    hintHit:EnableMouse(true)
    local hint = AQ.Widgets.FontString(hintHit, 12, AQ.Theme.hint[1], AQ.Theme.hint[2], AQ.Theme.hint[3])
    hint:SetPoint("LEFT", 0, 0)
    hint:SetText("Arrows select  Enter open/track  Double-click quest details  Backspace back")
    frame.Hint = hint
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(hintHit, "Arrows select. Enter open or track. Double-click a quest for details and a waypoint. Backspace back.")
    end

    frame:SetScript("OnKeyDown", function(self, key)
        if self.SearchBox and self.SearchBox:HasFocus() then
            if self.SetPropagateKeyboardInput then
                self:SetPropagateKeyboardInput(true)
            end
            return
        end
        local handled = false
        if AQ.Journal.ListView then
            handled = AQ.Journal.ListView.OnKey(key) and true or false
        end
        if self.SetPropagateKeyboardInput then
            self:SetPropagateKeyboardInput(not handled)
        end
    end)
    if frame.SetPropagateKeyboardInput then
        frame:EnableKeyboard(true)
        frame:SetPropagateKeyboardInput(true)
    end

    frame.SetSearchOpen = SetSearchOpen
    frame.UpdateGridIcon = UpdateGridIcon
    UpdateGridIcon()
    return frame
end

function Journal.GetFrame()
    return Ensure()
end

function Journal.Refresh()
    Ensure()
    UpdateGridIcon()
    Relayout()
    if AQ.Journal.ListView then
        AQ.Journal.ListView.Refresh()
    end
    AQ.Events.Fire("AQ_JOURNAL_REFRESH")
end

function Journal.Show()
    Ensure()
    frame:Show()
    Journal.Refresh()
    AQ.Speech.Say("Questline journal")
end

function Journal.Hide()
    if AQ.Journal.QuestDetail then
        AQ.Journal.QuestDetail.Hide()
    end
    if frame then
        frame:Hide()
    end
end

function Journal.Toggle()
    Ensure()
    if frame:IsShown() then
        Journal.Hide()
        AQ.Speech.Say("Journal closed")
    else
        Journal.Show()
    end
end

function Journal.OpenQuest(questID)
    Ensure()
    frame:Show()
    if AQ.Journal.ListView then
        AQ.Journal.ListView.OpenQuest(questID)
    end
end

function Journal.ReadFocus()
    if AQ.Journal.ListView then
        AQ.Journal.ListView.ReadFocus()
    end
end

AQ.Events.Register("AQ_DATA_CHANGED", function()
    if frame and frame:IsShown() then
        Journal.Refresh()
    end
end)
