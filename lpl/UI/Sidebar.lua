local addonName, LPL = ...

LPL.Sidebar = {
    tabs = {},
    bottomTabs = {},
}

local TAB_SIZE = 48
local TAB_GAP = 4
local TAB_STEP = TAB_SIZE + TAB_GAP
local TOP_PAD = 10
local BOTTOM_PAD = 10
local DIVIDER_GAP = 10

local TAB_DEFINITIONS = {
    {
        id = "loadouts",
        label = "Loadouts",
        description = "Combine talents, action bars, equipment, and more into full loadouts.",
        iconStem = "builds_64",
        order = 10,
        bottom = false,
    },
    {
        id = "talents",
        label = "Talents",
        description = "Plan and manage talent loadouts for any class.",
        iconStem = "talents_64",
        order = 20,
        bottom = false,
    },
    {
        id = "pvp",
        label = "PVP Talents",
        description = "Plan and save PvP talent layouts.",
        iconStem = "pvp_64",
        order = 30,
        bottom = false,
    },
    {
        id = "actionbars",
        label = "Action Bars",
        description = "Save, edit, and activate action bar layouts.",
        iconStem = "actionbars_64",
        order = 40,
        bottom = false,
    },
    {
        id = "keybinds",
        label = "Keybinding Profiles",
        description = "Save and activate account-wide or character keybinding profiles.",
        iconStem = "keybinds_64",
        order = 45,
        bottom = false,
    },
    {
        id = "equipment",
        label = "Equipment",
        description = "Manage gear sets and tie them to your loadouts.",
        iconStem = "equipment_64",
        order = 50,
        bottom = false,
    },
    {
        id = "cooldownmanager",
        label = "Cooldown Manager",
        description = "Save and activate Blizzard Cooldown Manager layout strings.",
        iconStem = "cooldown_64",
        order = 52,
        bottom = false,
    },
    {
        id = "editmode",
        label = "Edit Mode",
        description = "Save and activate Blizzard Edit Mode layout strings.",
        iconStem = "editmode_64",
        order = 55,
        bottom = false,
    },
    {
        id = "conditions",
        label = "Conditions",
        description = "Automatically switch loadouts based on zone, combat, and more.",
        iconStem = "conditions_64",
        order = 57,
        bottom = false,
    },
    {
        id = "macros",
        label = "Macro Manager",
        description = "Store macro name, icon, and body for sharing and reuse.",
        iconStem = "macros_64",
        order = 58,
        bottom = false,
    },
    {
        id = "addonsets",
        label = "Addon Sets",
        description = "Save and apply lists of enabled addons for Account or Character.",
        iconStem = "addonsets_64",
        order = 59,
        bottom = false,
    },
    {
        id = "addonsmanager",
        label = "Addons Manager",
        description = "Store other addons' profile strings for easy copy and paste.",
        iconStem = "addons_64",
        order = 60,
        bottom = false,
    },
    {
        id = "builds",
        label = "Import / Export",
        description = "Import and export LPL loadouts, builds, macros, and addon profiles.",
        iconStem = "import_64",
        order = 90,
        bottom = true,
    },
    {
        id = "settings",
        label = "Settings",
        description = "Configure LPL appearance and behavior.",
        iconStem = "settings_64",
        order = 100,
        bottom = true,
    },
}

local function OnTabClick(tabData)
    if tabData.id == "builds" and LPL.ImportExport and LPL.ImportExport.OpenImport then
        LPL.ImportExport:OpenImport()
    else
        LPL.Modules:Activate(tabData.id)
    end
end

local function CollectTabs(bottom)
    local list = {}
    for _, tabData in ipairs(TAB_DEFINITIONS) do
        if tabData.bottom == bottom then
            list[#list + 1] = tabData
        end
    end
    table.sort(list, function(a, b)
        return (a.order or 0) < (b.order or 0)
    end)
    return list
end

function LPL.Sidebar:Layout()
    local sidebar = self.frame
    if not sidebar then
        return
    end

    local topDefs = self._topDefs
    local bottomDefs = self._bottomDefs
    if not topDefs or not bottomDefs then
        return
    end

    local height = sidebar:GetHeight() or 0
    local bottomCount = #bottomDefs
    local topCount = #topDefs

    -- Bottom stack: Settings at the very bottom, Import above it.
    local bottomY = BOTTOM_PAD
    for i = bottomCount, 1, -1 do
        local tabData = bottomDefs[i]
        local tab = self.bottomTabs[tabData.id]
        if tab then
            tab:ClearAllPoints()
            tab:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, bottomY)
            bottomY = bottomY + TAB_STEP
        end
    end

    local bottomReserve = BOTTOM_PAD
    if bottomCount > 0 then
        bottomReserve = BOTTOM_PAD + (bottomCount * TAB_SIZE) + ((bottomCount - 1) * TAB_GAP) + DIVIDER_GAP
    end

    if self.divider then
        self.divider:ClearAllPoints()
        self.divider:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 8, bottomReserve)
        self.divider:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -8, bottomReserve)
        if bottomCount > 0 then
            self.divider:Show()
        else
            self.divider:Hide()
        end
    end

    local available = math.max(TAB_SIZE, height - TOP_PAD - bottomReserve - 4)
    local step = TAB_STEP
    if topCount > 1 then
        local needed = ((topCount - 1) * TAB_STEP) + TAB_SIZE
        if needed > available then
            step = math.max(36, math.floor((available - TAB_SIZE) / (topCount - 1)))
        end
    end

    local topY = -TOP_PAD
    for _, tabData in ipairs(topDefs) do
        local tab = self.tabs[tabData.id]
        if tab then
            tab:ClearAllPoints()
            tab:SetPoint("TOP", sidebar, "TOP", 0, topY)
            topY = topY - step
        end
    end
end

function LPL.Sidebar:Create(parent)
    local sidebar = CreateFrame("Frame", "LPLSidebar", parent, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -36)
    sidebar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(64)
    LPL.Theme:ApplyBackdrop(sidebar, "panel", "bgSidebar", "border")

    local divider = sidebar:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetColorTexture(LPL.Theme:GetColor("border"))
    self.divider = divider

    self._topDefs = CollectTabs(false)
    self._bottomDefs = CollectTabs(true)

    for _, tabData in ipairs(self._topDefs) do
        local tab = LPL:CreateSidebarTab("LPLSidebarTab" .. tabData.id, sidebar, tabData)
        tab:SetScript("OnClick", function()
            OnTabClick(tabData)
        end)
        self.tabs[tabData.id] = tab
    end

    for _, tabData in ipairs(self._bottomDefs) do
        local tab = LPL:CreateSidebarTab("LPLSidebarTab" .. tabData.id, sidebar, tabData)
        tab:SetScript("OnClick", function()
            OnTabClick(tabData)
        end)
        self.bottomTabs[tabData.id] = tab
    end

    sidebar:SetScript("OnSizeChanged", function()
        LPL.Sidebar:Layout()
    end)

    parent.sidebar = sidebar
    self.frame = sidebar
    self:Layout()
    return sidebar
end

function LPL.Sidebar:RefreshActiveTab()
    local activeID = LPL.Modules:GetActiveID()
    for id, tab in pairs(self.tabs) do
        tab:SetActive(id == activeID)
    end
    for id, tab in pairs(self.bottomTabs) do
        tab:SetActive(id == activeID)
    end
end
