local _, GPS = ...

GPS.Main = GPS.Main or {}
local Main = GPS.Main

local TAB_ORDER = { "search", "route", "saved", "add" }
local TAB_LABELS = {
    search = "Search",
    route = "Route",
    saved = "Saved",
    add = "Add",
}

function Main:LayoutTabs()
    if not self.tabBar or not self.tabs then
        return
    end
    local tabGap = 2
    local barWidth = GPS:PlainNumber(self.tabBar:GetWidth())
    if not barWidth or barWidth < 40 then
        local frameWidth = self.frame and GPS:PlainNumber(self.frame:GetWidth())
        barWidth = (frameWidth or GPS.WINDOW.WIDTH) - 16
    end
    local tabWidth = math.max(52, (barWidth - 4 - tabGap * (#TAB_ORDER - 1)) / #TAB_ORDER)
    for i = 1, #TAB_ORDER do
        local tab = self.tabs[TAB_ORDER[i]]
        if tab then
            tab:SetWidth(tabWidth)
        end
    end
end

function Main:SelectTab(key, focusSearch)
    local theme = GPS.Theme
    if not self.tabs or not self.panels then
        return
    end
    if not self.tabs[key] then
        key = "search"
    end
    for i = 1, #TAB_ORDER do
        local name = TAB_ORDER[i]
        theme:StyleTab(self.tabs[name], name == key, TAB_LABELS[name])
        if name == key then
            self.panels[name]:Show()
        else
            self.panels[name]:Hide()
        end
    end
    self.activeTab = key
    GPS.DB:SetActiveTab(key)
    if key == "search" and GPS.Search and GPS.Search.Refresh then
        GPS.Search:Refresh()
    elseif key == "saved" and GPS.Saved and GPS.Saved.Refresh then
        GPS.Saved:Refresh()
    end
    if focusSearch and key == "search" and GPS.Search.Focus then
        GPS.Search:Focus()
    end
end

function Main:PlayTabSound()
    if SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON and PlaySound then
        pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

function Main:Init()
    if self.frame then
        return
    end
    local theme = GPS.Theme
    local c = GPS.WINDOW

    local frame = CreateFrame("Frame", "WowGPSForeverMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(c.WIDTH, c.HEIGHT)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(moved)
        moved:StopMovingOrSizing()
        GPS.DB:SaveWindow(moved)
    end)
    if frame.SetResizable then
        frame:SetResizable(true)
    end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(c.MIN_WIDTH, c.MIN_HEIGHT, c.MAX_WIDTH, c.MAX_HEIGHT)
    elseif frame.SetMaxResize then
        frame:SetMaxResize(c.MAX_WIDTH, c.MAX_HEIGHT)
        frame:SetMinResize(c.MIN_WIDTH, c.MIN_HEIGHT)
    end
    theme:ApplyBackdrop(frame)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(10)
    GPS.DB:RestoreWindow(frame)
    frame:Hide()
    self.frame = frame

    local resize = CreateFrame("Button", nil, frame)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT", -1, 1)
    resize:SetFrameLevel(frame:GetFrameLevel() + 30)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        GPS.DB:SaveWindow(frame)
        Main:LayoutTabs()
    end)

    frame:SetScript("OnSizeChanged", function()
        pcall(function()
            Main:LayoutTabs()
        end)
    end)

    frame.iconFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.iconFrame:SetSize(30, 30)
    frame.iconFrame:SetPoint("TOPLEFT", 10, -7)
    frame.iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.iconFrame:SetBackdropColor(0.06, 0.06, 0.08, 1)
    frame.iconFrame:SetBackdropBorderColor(theme.colors.border[1], theme.colors.border[2], theme.colors.border[3], 0.85)

    frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(26, 26)
    frame.icon:SetPoint("CENTER")
    frame.icon:SetTexture(GPS.ICON)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 14, -10)
    frame.title:SetText(GPS.TITLE)
    theme:SetReadableFont(frame.title, 16)
    theme:SetTextColor(frame.title, theme.colors.accent)

    frame.titleRule = frame:CreateTexture(nil, "ARTWORK")
    frame.titleRule:SetHeight(1)
    frame.titleRule:SetPoint("TOPLEFT", 12, -28)
    frame.titleRule:SetPoint("TOPRIGHT", -12, -28)
    frame.titleRule:SetColorTexture(0.25, 0.25, 0.30, 0.55)

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -2, -2)
    frame.close:SetScript("OnClick", function()
        Main:Hide()
    end)

    local tabBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    tabBar:SetPoint("TOPLEFT", 8, -34)
    tabBar:SetPoint("TOPRIGHT", -8, -34)
    tabBar:SetHeight(30)
    theme:StyleTabBar(tabBar)
    self.tabBar = tabBar

    self.tabs = {}
    self.panels = {}
    local tabGap = 2
    local tabWidth = (c.WIDTH - 16 - tabGap * (#TAB_ORDER - 1)) / #TAB_ORDER
    local prev
    for i = 1, #TAB_ORDER do
        local key = TAB_ORDER[i]
        local tab = CreateFrame("Button", "WowGPSForeverMainFrameTab" .. i, tabBar, "BackdropTemplate")
        tab:SetSize(tabWidth, 26)
        tab:SetFrameLevel(tabBar:GetFrameLevel() + 2)
        theme:InitTab(tab, TAB_LABELS[key])
        if i == 1 then
            tab:SetPoint("LEFT", tabBar, "LEFT", 2, 0)
        else
            tab:SetPoint("LEFT", prev, "RIGHT", tabGap, 0)
        end
        tab:SetScript("OnClick", function()
            Main:PlayTabSound()
            Main:SelectTab(key, key == "search")
        end)
        self.tabs[key] = tab
        prev = tab

        local panel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 8, -68)
        panel:SetPoint("BOTTOMRIGHT", -8, 8)
        panel:SetFrameLevel(frame:GetFrameLevel() + 2)
        theme:ApplyBackdrop(panel)
        panel:SetBackdropColor(theme.colors.panel[1], theme.colors.panel[2], theme.colors.panel[3], 1)
        panel:Hide()
        self.panels[key] = panel
    end

    GPS.Search:Build(self.panels.search)
    GPS.Route:Build(self.panels.route)
    GPS.Saved:Build(self.panels.saved)
    GPS.Add:Build(self.panels.add)
    self:LayoutTabs()
    self:SelectTab(GPS.DB:GetActiveTab(), false)
    frame:Hide()
end

function Main:Show()
    if not self.frame then
        self:Init()
    end
    self.frame:Show()
    if GPS.Here then
        GPS.Here:Start()
    end
end

function Main:Hide()
    if GPS.Here then
        GPS.Here:Stop()
    end
    if self.frame then
        self.frame:Hide()
    end
end

function Main:Toggle()
    if self.frame and self.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end
