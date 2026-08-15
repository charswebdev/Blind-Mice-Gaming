local addon = Exploration

addon.ui = ExplorationFrame

local panel = addon.ui.Content
for _, key in ipairs({ "Segment", "Routes", "Settings" }) do
    addon.ui[key .. "Frame"] = panel[key .. "Frame"]
end

local T = addon.theme
local L = addon.uiLayout

local TABS = {
    { key = "Segment",  label = "Segment" },
    { key = "Routes",   label = "Routes" },
    { key = "Settings", label = "Settings" },
}

local function createTab(parent, index, page, tabW)
    local tab = CreateFrame("Button", nil, parent)
    tab:SetSize(tabW, L.tabH)
    tab:SetPoint("LEFT", parent, "LEFT", (index - 1) * (tabW + 2), 0)

    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAllPoints(tab)
    addon:ColorTexture(tab.bg, T.tabBg)

    tab.line = tab:CreateTexture(nil, "BORDER")
    tab.line:SetHeight(2)
    tab.line:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 2, 0)
    tab.line:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 0)
    addon:ColorTexture(tab.line, T.tabBorder)
    tab.line:Hide()

    tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tab.label:SetPoint("CENTER")
    tab.label:SetText(page.label)

    tab:SetScript("OnEnter", function(self)
        if not self.selected then addon:StyleFont(self.label, "active") end
    end)
    tab:SetScript("OnLeave", function(self)
        addon:StyleFont(self.label, self.selected and "accent" or "dim")
    end)
    tab:SetScript("OnClick", function()
        addon.ui:ShowTab(page.key)
    end)

    return tab
end

function addon.ui:SaveFramePosition()
    local point, _, relativePoint, x, y = self:GetPoint(1)
    if not point then return end
    addon.data.ui = addon.data.ui or {}
    addon.data.ui.point = point
    addon.data.ui.relativePoint = relativePoint
    addon.data.ui.x = x
    addon.data.ui.y = y
end

function addon.ui:ApplyFramePosition()
    local ui = addon.data.ui
    if ui and ui.point then
        self:ClearAllPoints()
        self:SetPoint(ui.point, UIParent, ui.relativePoint or ui.point, ui.x or 0, ui.y or 0)
    end
end

function addon.ui:UpdateLockButton()
    if not self.lockBtn then return end
    local locked = addon.data.settings.frameLocked
    if locked then
        self.lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
        self.lockBtn:SetPushedTexture("Interface\\Buttons\\LockButton-Locked-Down")
        self.lockBtn:SetHighlightTexture("Interface\\Buttons\\LockButton-Locked-Highlight")
    else
        self.lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
        self.lockBtn:SetPushedTexture("Interface\\Buttons\\LockButton-Unlocked-Down")
        self.lockBtn:SetHighlightTexture("Interface\\Buttons\\LockButton-Unlocked-Highlight")
    end
end

function addon.ui:SetFrameLocked(locked)
    addon.data.settings.frameLocked = locked
    self:SetMovable(not locked)
    if locked then
        self:SaveFramePosition()
    end
    self:UpdateLockButton()
end

function addon.ui:CreateLockButton()
    if self.lockBtn then return self.lockBtn end

    local anchor = self.CloseButton or self
    local lockBtn = CreateFrame("Button", nil, self)
    lockBtn:SetSize(16, 16)
    if self.CloseButton then
        lockBtn:SetPoint("RIGHT", self.CloseButton, "LEFT", -2, 0)
    else
        lockBtn:SetPoint("TOPRIGHT", self, "TOPRIGHT", -28, -8)
    end
    lockBtn:SetScript("OnClick", function()
        addon.ui:SetFrameLocked(not addon.data.settings.frameLocked)
    end)
    lockBtn:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_LEFT")
        if addon.data.settings.frameLocked then
            GameTooltip:SetText("Unlock to move window", 1, 1, 1)
        else
            GameTooltip:SetText("Lock window position", 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.lockBtn = lockBtn
    self:UpdateLockButton()
    return lockBtn
end

function addon.ui:Initialize()
    if self._built then
        return
    end
    self._built = true

    addon:ApplyTheme(addon.ui)
    addon:CreateTitleCompass(addon.ui)

    addon.ui:SetSize(L.width, L.height)
    addon.ui:ApplyFramePosition()
    addon.ui:CreateLockButton()
    addon.ui:SetFrameLocked(addon.data.settings.frameLocked == true)
    addon.ui:EnableMouse(true)
    addon.ui:RegisterForDrag("LeftButton")
    addon.ui:SetScript("OnDragStart", function(self)
        if not addon.data.settings.frameLocked then
            self:StartMoving()
        end
    end)
    addon.ui:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not addon.data.settings.frameLocked then
            addon.ui:SaveFramePosition()
        end
    end)
    addon.ui:SetScript("OnShow", function() addon.ui:Refresh() end)

    local tabW = math.floor((L.contentWidth - 4) / #TABS)
    addon.ui.tabs = {}
    for i, page in ipairs(TABS) do
        addon.ui.tabs[page.key] = createTab(addon.ui.TabBar, i, page, tabW)
    end

    for _, page in ipairs(TABS) do
        addon.ui[page.key .. "Frame"]:Initialize()
    end

    addon.ui:ShowTab("Segment")
    addon.ui:Refresh()
    print("|cff00ccffExploration:|r v" .. addon.VERSION .. " loaded.")
end

function addon.ui:ShowTab(name)
    for _, page in ipairs(TABS) do
        local tab = addon.ui.tabs[page.key]
        local on = page.key == name
        tab.selected = on
        if on then
            addon:ColorTexture(tab.bg, T.tabActive)
            tab.line:Show()
            addon:StyleFont(tab.label, "accent")
            addon.ui[page.key .. "Frame"]:Show()
        else
            addon:ColorTexture(tab.bg, T.tabBg)
            tab.line:Hide()
            addon:StyleFont(tab.label, "dim")
            addon.ui[page.key .. "Frame"]:Hide()
        end
    end
    local segment = addon.ui.SegmentFrame
    if segment and segment.headerBtns then
        if name == "Segment" and segment.LayoutHeaderButtons then
            segment:LayoutHeaderButtons()
        else
            segment.headerBtns:Hide()
        end
    end
end

function addon.ui:Refresh()
    addon.menu = addon.processRoutes(addon.data.routes)
    if addon.ui.SegmentFrame then
        if not addon.ui.SegmentFrame._built and addon.ui.SegmentFrame.Initialize then
            addon.ui.SegmentFrame:Initialize()
        end
        if addon.ui.SegmentFrame.Refresh then addon.ui.SegmentFrame:Refresh() end
    end
    if addon.ui.RoutesFrame then
        if not addon.ui.RoutesFrame._built and addon.ui.RoutesFrame.Initialize then
            addon.ui.RoutesFrame:Initialize()
        end
        if addon.ui.RoutesFrame.Refresh then addon.ui.RoutesFrame:Refresh() end
    end
    if addon.ui.SettingsFrame then
        if not addon.ui.SettingsFrame._built and addon.ui.SettingsFrame.Initialize then
            addon.ui.SettingsFrame:Initialize()
        end
        if addon.ui.SettingsFrame.Refresh then addon.ui.SettingsFrame:Refresh() end
    end
end

addon.ui.SelectTab = addon.ui.ShowTab
addon.ui.ShowPage = addon.ui.ShowTab
addon.ui.SelectPage = addon.ui.ShowTab
