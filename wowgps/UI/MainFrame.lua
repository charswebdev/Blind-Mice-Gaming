local _, ns = ...

local MainFrame = {}
ns.MainFrame = MainFrame

function MainFrame:GetAddonIcon()
    local addonName = self.addon and self.addon.name or "wowgps"
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, "IconTexture")
    end
    return GetAddOnMetadata(addonName, "IconTexture")
end

function MainFrame:Init(addon)
    self.addon = addon
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme
    local c = ns.Constants.WINDOW

    local f = CreateFrame("Frame", "WowGPSMainFrame", UIParent, "BackdropTemplate")
    f:SetSize(c.WIDTH, c.HEIGHT)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        ns.Database:SaveWindow(frame)
    end)
    if f.SetResizable then
        f:SetResizable(true)
    end
    if f.SetResizeBounds then
        f:SetResizeBounds(c.MIN_WIDTH, c.MIN_HEIGHT, c.MAX_WIDTH, c.MAX_HEIGHT)
    elseif f.SetMaxResize then
        f:SetMaxResize(c.MAX_WIDTH, c.MAX_HEIGHT)
        f:SetMinResize(c.MIN_WIDTH, c.MIN_HEIGHT)
    end
    if f.SetResizeAlgorithm then
        f:SetResizeAlgorithm("Rect")
    end
    theme:ApplyBackdrop(f)
    f:SetFrameStrata("MEDIUM")
    f:SetFrameLevel(10)
    ns.Database:RestoreWindow(f)
    f:Hide()
    self.frame = f

    local resize = CreateFrame("Button", nil, f)
    resize:SetSize(16, 16)
    resize:SetPoint("BOTTOMRIGHT", -1, 1)
    resize:SetFrameLevel(f:GetFrameLevel() + 30)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function()
        f:StartSizing("BOTTOMRIGHT")
    end)
    resize:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        ns.Database:SaveWindow(f)
        MainFrame:OnResize()
    end)
    self.resizeGrip = resize

    f:SetScript("OnSizeChanged", function()
        MainFrame:OnResize()
    end)

    f.iconFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.iconFrame:SetSize(30, 30)
    f.iconFrame:SetPoint("TOPLEFT", 10, -7)
    f.iconFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f.iconFrame:SetBackdropColor(0.06, 0.06, 0.08, 1)
    f.iconFrame:SetBackdropBorderColor(
        theme.colors.border[1],
        theme.colors.border[2],
        theme.colors.border[3],
        0.85
    )

    f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(26, 26)
    f.icon:SetPoint("CENTER", f.iconFrame, "CENTER", 0, 0)
    f.icon:SetTexture(self:GetAddonIcon() or "Interface\\AddOns\\wowgps\\Media\\WowGPS.png")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 14, -10)
    f.title:SetText(L["ADDON_NAME"])
    theme:SetReadableFont(f.title, 16)
    theme:SetTextColor(f.title, theme.colors.accent)

    f.titleRule = f:CreateTexture(nil, "ARTWORK")
    f.titleRule:SetHeight(1)
    f.titleRule:SetPoint("TOPLEFT", 12, -28)
    f.titleRule:SetPoint("TOPRIGHT", -12, -28)
    f.titleRule:SetColorTexture(0.25, 0.25, 0.30, 0.55)

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", -2, -2)
    f.close:SetScript("OnClick", function()
        MainFrame:Close()
    end)

    local tabBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    tabBar:SetPoint("TOPLEFT", 8, -34)
    tabBar:SetPoint("TOPRIGHT", -8, -34)
    tabBar:SetHeight(30)
    theme:StyleTabBar(tabBar)
    self.tabBar = tabBar

    self.tabs = {}
    self.tabOrder = { "search", "route", "saved", "add" }
    local tabNames = self.tabOrder
    local tabLabels = { L["TAB_SEARCH"], L["TAB_ROUTE"], L["TAB_SAVED"], L["TAB_ADD"] }
    local tabCount = #tabNames
    local tabGap = 2
    local tabWidth = (c.WIDTH - 16 - tabGap * (tabCount - 1)) / tabCount
    local prevTab

    for i, key in ipairs(tabNames) do
        local tab = CreateFrame("Button", "WowGPSMainFrameTab" .. i, tabBar, "BackdropTemplate")
        tab:SetID(i)
        tab:SetSize(tabWidth, 26)
        tab.key = key
        tab.label = tabLabels[i]
        tab:SetFrameLevel(tabBar:GetFrameLevel() + 2)
        theme:InitTab(tab, tabLabels[i])

        if i == 1 then
            tab:SetPoint("LEFT", tabBar, "LEFT", 2, 0)
        else
            tab:SetPoint("LEFT", prevTab, "RIGHT", tabGap, 0)
        end

        tab:SetScript("OnClick", function(btn)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
            MainFrame:SelectTab(btn.key, false, btn.key == "search")
        end)

        self.tabs[key] = tab
        prevTab = tab
    end

    self.panels = {}
    for _, key in ipairs(tabNames) do
        local panel = CreateFrame("Frame", nil, f, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 8, -68)
        panel:SetPoint("BOTTOMRIGHT", -8, 8)
        panel:SetFrameLevel(f:GetFrameLevel() + 2)
        theme:ApplyBackdrop(panel)
        panel:SetBackdropColor(theme.colors.panel[1], theme.colors.panel[2], theme.colors.panel[3], 1)
        panel:Hide()
        self.panels[key] = panel
    end

    ns.SearchTab:Build(self.panels.search, self)
    ns.RouteTab:Build(self.panels.route, self)
    ns.SavedTab:Build(self.panels.saved, self)
    ns.AddTab:Build(self.panels.add, self)

    self:LayoutTabs()
    self:SelectTab("search", true, false)
end

function MainFrame:LayoutTabs()
    if not self.tabBar or not self.tabs then
        return
    end

    local tabCount = #self.tabOrder
    local tabGap = 2
    local barWidth = self.tabBar:GetWidth()
    if not barWidth or barWidth < 40 then
        barWidth = (self.frame and self.frame:GetWidth() or ns.Constants.WINDOW.WIDTH) - 16
    end
    local tabWidth = math.max(52, (barWidth - 4 - tabGap * (tabCount - 1)) / tabCount)
    for _, key in ipairs(self.tabOrder) do
        local tab = self.tabs[key]
        if tab then
            tab:SetWidth(tabWidth)
        end
    end
end

function MainFrame:OnResize()
    if not self.frame or not self.tabs then
        return
    end
    if self._resizing then
        return
    end
    self._resizing = true
    self:LayoutTabs()
    if ns.SearchTab and ns.SearchTab.OnParentResize then
        ns.SearchTab:OnParentResize()
    end
    if ns.SavedTab and ns.SavedTab.OnParentResize then
        ns.SavedTab:OnParentResize()
    end
    if ns.RouteTab and ns.RouteTab.OnParentResize then
        ns.RouteTab:OnParentResize()
    end
    if ns.AddTab and ns.AddTab.OnParentResize then
        ns.AddTab:OnParentResize()
    end
    self._resizing = false
end

function MainFrame:SaveSession()
    if not self.frame or not ns.Database then
        return
    end
    ns.Database:SetActiveTab(self.activeTab or "search")
end

function MainFrame:SyncFrameState()
    if not self.frame or not ns.Database then
        return
    end
    if self._wantFrameOpen then
        ns.Database:SetFrameOpen(true)
    end
end

function MainFrame:MarkFrameOpen()
    if not ns.Database then
        return
    end
    self._wantFrameOpen = true
    ns.Database:SetFrameOpen(true)
end

function MainFrame:MarkFrameClosed()
    if not ns.Database then
        return
    end
    self._wantFrameOpen = false
    ns.Database:SetFrameOpen(false)
    self:SaveSession()
end

function MainFrame:ApplyRestoredVisibility()
    if not self.frame or not ns.Database then
        return
    end

    if self._wantFrameOpen == nil then
        self._wantFrameOpen = ns.Database:GetFrameOpen()
    end

    if self._wantFrameOpen then
        self:MarkFrameOpen()
        self.frame:Show()
    else
        self.frame:Hide()
    end
end

function MainFrame:RestoreSession()
    if not self.frame then
        return
    end

    local hasRoute = ns.RouteTracker.route ~= nil
    self._wantFrameOpen = ns.Database:GetFrameOpen()
    local tab = hasRoute and "route" or ns.Database:GetActiveTab()

    self:SelectTab(tab, true, false)

    -- OnEnable can run before the world is ready; an immediate Show() is often undone.
    C_Timer.After(0, function()
        MainFrame:ApplyRestoredVisibility()
    end)

    self:SaveSession()
end

function MainFrame:SelectTab(key, skipSessionSave, focusSearch)
    local theme = ns.Theme

    for _, name in ipairs(self.tabOrder) do
        local tab = self.tabs[name]
        theme:StyleTab(tab, name == key, tab.label)
    end

    for name, panel in pairs(self.panels) do
        if name == key then
            if name == "search" then ns.SearchTab:Show(focusSearch)
            elseif name == "route" then ns.RouteTab:Show()
            elseif name == "saved" then ns.SavedTab:Show()
            elseif name == "add" then ns.AddTab:Show()
            end
        else
            panel:Hide()
        end
    end
    self.activeTab = key
    if not skipSessionSave then
        self:SaveSession()
    end
end

function MainFrame:ShowRouteTab()
    self:Show()
    self:SelectTab("route")
end

function MainFrame:ShowSearchTab()
    self:Show()
    self:SelectTab("search", false, false)
end

function MainFrame:EditSavedLocation(record)
    if not record or not record.id then
        return
    end
    local full = ns.CustomLocations:GetRecord(record.id, record.scope)
    if not full then
        return
    end
    full.scope = record.scope
    self:Show()
    self:SelectTab("add")
    ns.AddTab:LoadRecord(full)
end

function MainFrame:RefreshRouteTab()
    ns.RouteTab:Refresh()
end

function MainFrame:Toggle()
    if self.frame:IsShown() then
        self:Close()
    else
        self:Show()
    end
end

function MainFrame:Show()
    self:MarkFrameOpen()
    self.frame:Show()
end

function MainFrame:Close()
    self:MarkFrameClosed()
    self.frame:Hide()
end
