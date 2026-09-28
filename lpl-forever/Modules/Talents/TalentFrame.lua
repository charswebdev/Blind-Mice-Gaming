local _, LPL = ...

LPL.Talents = LPL.Talents or {}
local UI = LPL.Talents

local FRAME_W = 980
local FRAME_H = 860
local TITLE_H = 36
local SIDEBAR_W = 64
local TAB = 48
local TAB_GAP = 4
local LIST_BAR_H = 44
local TREE_BAR_H = 84

local BG = { 0.00, 0.00, 0.00, 1 }
local SIDEBAR_BG = { 0.10, 0.10, 0.12, 1 }
local TITLE_BG = { 0.08, 0.08, 0.10, 1 }
local BORDER = { 0.25, 0.27, 0.32, 1 }
local ACCENT = { 0.35, 0.65, 1.00, 1 }
local TEXT = { 0.95, 0.95, 0.97, 1 }
local GOLD = { 1.00, 0.92, 0.40, 1 }
local SELECTED = { 0.28, 0.05, 0.09, 1 }

local TABS = {
    { id = "loadouts", label = "Loadouts", stem = "builds_64", bottom = false },
    { id = "talents", label = "Talents", stem = "talents_64", bottom = false },
    { id = "pvp", label = "PVP Talents", stem = "pvp_64", bottom = false },
    { id = "actionbars", label = "Action Bars", stem = "actionbars_64", bottom = false },
    { id = "keybinds", label = "Keybinding Profiles", stem = "keybinds_64", bottom = false },
    { id = "equipment", label = "Equipment", stem = "equipment_64", bottom = false },
    { id = "editmode", label = "Edit Mode", stem = "editmode_64", bottom = false },
    { id = "macros", label = "Macro Manager", stem = "macros_64", bottom = false },
    { id = "addonsets", label = "Addon Sets", stem = "addonsets_64", bottom = false },
    { id = "addonsmanager", label = "Addons Manager", stem = "addons_64", bottom = false },
    { id = "builds", label = "Import / Export", stem = "import_64", bottom = true },
    { id = "settings", label = "Settings", stem = "settings_64", bottom = true },
}

local frame
local mode = "list"
local selectedId
local draft
local viewTab = 1
local listButtons = {}
local nodeButtons = {}
local linePool = {}

local function Speak(text)
    print("|cff00ff00[Light Paws Loadouts]|r " .. tostring(text))
end

local function ShowNotice(text, warn)
    Speak(text)
    if frame and frame.notice then
        frame.notice:SetText(text or "")
        if warn then
            frame.notice:SetTextColor(1, 0.35, 0.35)
        else
            frame.notice:SetTextColor(1, 0.82, 0)
        end
        frame.notice:Show()
    end
    if frame and frame.detail then
        frame.detail:SetText(text or "")
    end
    if not warn or not StaticPopup_Show then
        return
    end
    if not StaticPopupDialogs["LPL_FOREVER_APPLY"] then
        StaticPopupDialogs["LPL_FOREVER_APPLY"] = {
            text = "%s",
            button1 = OKAY or "Okay",
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    pcall(StaticPopup_Show, "LPL_FOREVER_APPLY", text)
end

local function Paint(target, bg, border)
    if not target.SetBackdrop then
        return
    end
    target:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    target:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    if border then
        target:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
    end
end

local function CopyBuild(build)
    local tabs = {}
    if type(build) == "table" and type(build.tabs) == "table" then
        for key, tab in pairs(build.tabs) do
            local ranks = {}
            if type(tab) == "table" and type(tab.ranks) == "table" then
                for index, rank in pairs(tab.ranks) do
                    local rankNumber = tonumber(rank)
                    if rankNumber and rankNumber > 0 then
                        ranks[tostring(index)] = rankNumber
                    end
                end
            end
            tabs[tostring(key)] = {
                name = type(tab) == "table" and tab.name or nil,
                points = type(tab) == "table" and (tonumber(tab.points) or 0) or 0,
                ranks = ranks,
            }
        end
    end
    return {
        id = build and build.id,
        name = build and build.name,
        classFile = build and build.classFile,
        classID = build and build.classID,
        tabs = tabs,
        totalPoints = build and build.totalPoints or 0,
    }
end

local function EmptyDraft()
    local captured = LPL.TalentAPI:Capture()
    local tabCount = LPL.TalentAPI:TabCount()
    captured.tabs = {}
    captured.totalPoints = 0
    for tabIndex = 1, tabCount do
        local info = LPL.TalentAPI:TabInfo(tabIndex)
        captured.tabs[tostring(tabIndex)] = {
            name = info.name,
            points = 0,
            ranks = {},
        }
    end
    return captured
end

local function SaveFramePosition()
    if not frame then
        return
    end
    local db = LPL.DB:Bind(false)
    db.ui = type(db.ui) == "table" and db.ui or {}
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    db.ui.frame = db.ui.frame or {}
    db.ui.frame.point = point
    db.ui.frame.relativePoint = relativePoint
    db.ui.frame.x = x
    db.ui.frame.y = y
    db.ui.frame.locked = frame.locked == true
end

local BUTTON_BG = { 0.18, 0.18, 0.22, 1 }
local BUTTON_HOVER = { 0.24, 0.24, 0.30, 1 }
local BUTTON_PRESSED = { 0.14, 0.14, 0.18, 1 }
local BUTTON_BORDER = { 0.96, 0.55, 0.73, 1 }

local function BarButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 24)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(label)
    text:SetTextColor(1, 1, 1)
    button.label = text
    local function PaintState(state)
        local bg = BUTTON_BG
        if state == "hover" then
            bg = BUTTON_HOVER
        elseif state == "pressed" then
            bg = BUTTON_PRESSED
        end
        Paint(button, bg, BUTTON_BORDER)
    end
    PaintState("normal")
    button:SetScript("OnEnter", function()
        PaintState("hover")
    end)
    button:SetScript("OnLeave", function()
        PaintState("normal")
    end)
    button:SetScript("OnMouseDown", function()
        PaintState("pressed")
    end)
    button:SetScript("OnMouseUp", function()
        PaintState("hover")
    end)
    function button:SetText(value)
        text:SetText(value)
    end
    return button
end

local function GlowButton(parent, label, width, height)
    local pad = 8
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width + pad * 2, height + pad * 2)

    local halo = container:CreateTexture(nil, "BACKGROUND")
    halo:SetPoint("TOPLEFT", 0, 0)
    halo:SetPoint("BOTTOMRIGHT", 0, 0)
    halo:SetColorTexture(0.30, 0.90, 0.40, 0.28)

    local ring = CreateFrame("Frame", nil, container, "BackdropTemplate")
    ring:SetPoint("TOPLEFT", 3, -3)
    ring:SetPoint("BOTTOMRIGHT", -3, 3)
    ring:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 2,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    ring:SetBackdropColor(0, 0, 0, 0)
    ring:SetBackdropBorderColor(0.50, 1.00, 0.55, 0.90)

    local button = CreateFrame("Button", nil, container, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetPoint("CENTER")
    button:SetFrameLevel(container:GetFrameLevel() + 2)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    button:SetBackdropColor(0.58, 0.10, 0.16, 1)
    button:SetBackdropBorderColor(0.72, 0.18, 0.26, 1)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("CENTER")
    text:SetText(label)
    text:SetTextColor(1, 0.92, 0.40)

    local function PaintGlow(hover, pressed)
        if pressed then
            button:SetBackdropColor(0.42, 0.08, 0.12, 1)
            halo:SetColorTexture(0.35, 0.95, 0.45, 0.40)
        elseif hover then
            button:SetBackdropColor(0.68, 0.14, 0.22, 1)
            halo:SetColorTexture(0.35, 0.95, 0.45, 0.40)
        else
            button:SetBackdropColor(0.58, 0.10, 0.16, 1)
            halo:SetColorTexture(0.30, 0.90, 0.40, 0.28)
        end
    end
    button:SetScript("OnEnter", function()
        PaintGlow(true, false)
    end)
    button:SetScript("OnLeave", function()
        PaintGlow(false, false)
    end)
    button:SetScript("OnMouseDown", function()
        PaintGlow(true, true)
    end)
    button:SetScript("OnMouseUp", function()
        PaintGlow(true, false)
    end)

    function container:SetClick(handler)
        button:SetScript("OnClick", handler)
    end

    return container
end

local function TryAtlas(texture, atlas)
    if not texture or not atlas or not texture.SetAtlas then
        return false
    end
    if C_Texture and C_Texture.GetAtlasInfo and not C_Texture.GetAtlasInfo(atlas) then
        return false
    end
    return pcall(texture.SetAtlas, texture, atlas, false)
end

local function GridStep(values)
    local seen, list = {}, {}
    for i = 1, #values do
        local value = math.floor((tonumber(values[i]) or 0) + 0.5)
        if not seen[value] then
            seen[value] = true
            list[#list + 1] = value
        end
    end
    table.sort(list)
    if #list < 2 then
        return 1, list[1] or 0, list[1] or 0
    end
    local deltas = {}
    for i = 2, #list do
        local delta = list[i] - list[i - 1]
        if delta > 0 then
            deltas[#deltas + 1] = delta
        end
    end
    table.sort(deltas)
    local step = deltas[math.max(1, math.ceil(#deltas * 0.5))] or 1
    if step < 1 then
        step = 1
    end
    return step, list[1], list[#list]
end

local function SplitClusters(talents, stepX)
    local columns, seen = {}, {}
    for i = 1, #talents do
        local x = math.floor((talents[i].posX or 0) + 0.5)
        if not seen[x] then
            seen[x] = true
            columns[#columns + 1] = x
        end
    end
    table.sort(columns)
    local splits = {}
    local gap = math.max((stepX or 1) * 1.9, 1)
    for i = 2, #columns do
        if columns[i] - columns[i - 1] >= gap then
            splits[#splits + 1] = (columns[i - 1] + columns[i]) / 2
        end
    end
    if #splits < 1 then
        return { talents }
    end
    local groups = {}
    for i = 1, #splits + 1 do
        groups[i] = {}
    end
    for i = 1, #talents do
        local x = talents[i].posX or 0
        local index = 1
        for s = 1, #splits do
            if x > splits[s] then
                index = s + 1
            end
        end
        groups[index][#groups[index] + 1] = talents[i]
    end
    return groups
end

local NODE_ART = {
    square = {
        normal = "talents-node-square-yellow",
        disabled = "talents-node-square-gray",
        selectable = "talents-node-square-green",
        glow = "talents-node-square-greenglow",
        shadow = "talents-node-square-shadow",
    },
    circle = {
        normal = "talents-node-circle-yellow",
        disabled = "talents-node-circle-gray",
        selectable = "talents-node-circle-green",
        glow = "talents-node-circle-greenglow",
        shadow = "talents-node-circle-shadow",
        mask = "talents-node-circle-mask",
    },
    choice = {
        normal = "talents-node-choice-yellow",
        disabled = "talents-node-choice-gray",
        selectable = "talents-node-choice-green",
        glow = "talents-node-choice-greenglow",
        shadow = "talents-node-choice-shadow",
        mask = "talents-node-choice-mask",
    },
}

local function SetTabActive(id)
    if not frame or not frame.tabs then
        return
    end
    for i = 1, #frame.tabs do
        local tab = frame.tabs[i]
        local active = tab.moduleID == id
        tab.accent:SetShown(active)
        if active and tab.SetBackdrop then
            Paint(tab, { 0.16, 0.18, 0.24, 1 }, BORDER)
        elseif tab.SetBackdrop then
            tab:SetBackdrop(nil)
        end
    end
end

local function ShowPage(page)
    frame.listPage:SetShown(page == "list")
    frame.editorPage:SetShown(page == "editor")
    frame.importPage:SetShown(page == "import")
    frame.laterPage:SetShown(page == "later")
    if LPL.Sections then
        LPL.Sections:SetShown(page == "section")
    end
end

local CLASS_LABEL = {
    WARRIOR = "Warrior",
    PALADIN = "Paladin",
    HUNTER = "Hunter",
    ROGUE = "Rogue",
    PRIEST = "Priest",
    SHAMAN = "Shaman",
    MAGE = "Mage",
    WARLOCK = "Warlock",
    DRUID = "Druid",
}

local CLASS_COLOR = {
    WARRIOR = { 0.78, 0.61, 0.43 },
    PALADIN = { 0.96, 0.55, 0.73 },
    HUNTER = { 0.67, 0.83, 0.45 },
    ROGUE = { 1.00, 0.96, 0.41 },
    PRIEST = { 1.00, 1.00, 1.00 },
    SHAMAN = { 0.00, 0.44, 0.87 },
    MAGE = { 0.41, 0.80, 0.94 },
    WARLOCK = { 0.58, 0.51, 0.79 },
    DRUID = { 1.00, 0.49, 0.04 },
}

local function ClassLabel(file)
    if CLASS_LABEL[file] then
        return CLASS_LABEL[file]
    end
    if type(file) == "string" and file ~= "" then
        return file:sub(1, 1):upper() .. file:sub(2):lower()
    end
    return "Other"
end

local function GroupCollapsed()
    local db = LPL.DB:Bind(false)
    db.ui = db.ui or {}
    if type(db.ui.talentGroups) ~= "table" then
        db.ui.talentGroups = {}
    end
    return db.ui.talentGroups
end

local function AcquireListRow(index)
    local button = listButtons[index]
    if button then
        return button
    end
    button = CreateFrame("Button", nil, frame.listChild, "BackdropTemplate")
    button:RegisterForClicks("LeftButtonUp")
    button.expand = button:CreateTexture(nil, "ARTWORK")
    button.expand:SetSize(12, 12)
    button.badge = button:CreateTexture(nil, "OVERLAY")
    button.badge:SetSize(8, 8)
    button.badge:SetColorTexture(0.40, 1.00, 0.50, 1)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetJustifyH("LEFT")
    button.subtitle = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.subtitle:SetJustifyH("LEFT")
    button.subtitle:SetTextColor(0.78, 0.81, 0.88)
    listButtons[index] = button
    return button
end

local function RefreshList()
    local builds = LPL.TalentStore:List()
    local query = ""
    if frame.searchBox then
        query = (frame.searchBox:GetText() or ""):lower()
    end
    local groups, order = {}, {}
    for i = 1, #builds do
        local build = builds[i]
        local name = (build.name or ""):lower()
        if query == "" or name:find(query, 1, true) then
            local key = build.classFile
            if type(key) ~= "string" or key == "" then
                key = "OTHER"
            end
            if not groups[key] then
                groups[key] = {}
                order[#order + 1] = key
            end
            groups[key][#groups[key] + 1] = build
        end
    end
    table.sort(order)

    for i = 1, #listButtons do
        listButtons[i]:Hide()
    end
    if frame.emptyButton then
        frame.emptyButton:SetShown(#builds == 0)
    end
    if frame.noMatch then
        frame.noMatch:SetShown(#builds > 0 and #order == 0)
    end

    local collapsed = GroupCollapsed()
    local width = 640
    if frame.listScroll then
        width = math.max(240, (frame.listScroll:GetWidth() or 640) - 16)
    end
    local y = 4
    local rowIndex = 0
    for g = 1, #order do
        local key = order[g]
        local items = groups[key]
        rowIndex = rowIndex + 1
        local header = AcquireListRow(rowIndex)
        local isCollapsed = collapsed[key] == true
        header:SetSize(width, 24)
        Paint(header, { 0.00, 0.00, 0.00, 1 }, { 0.00, 0.00, 0.00, 1 })
        header.badge:Hide()
        header.subtitle:Hide()
        header.expand:Show()
        header.expand:SetTexture(isCollapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
        header.expand:ClearAllPoints()
        header.expand:SetPoint("LEFT", 8, 0)
        header.label:ClearAllPoints()
        header.label:SetPoint("LEFT", header.expand, "RIGHT", 6, 0)
        header.label:SetPoint("RIGHT", header, "RIGHT", -8, 0)
        local color = CLASS_COLOR[key] or GOLD
        header.label:SetText(ClassLabel(key) .. "   " .. tostring(#items))
        header.label:SetTextColor(color[1], color[2], color[3])
        header:SetPoint("TOPLEFT", 4, -y)
        header:SetScript("OnClick", function()
            collapsed[key] = not isCollapsed
            RefreshList()
        end)
        header:SetScript("OnDoubleClick", nil)
        header:Show()
        y = y + 28

        if not isCollapsed then
            for i = 1, #items do
                local build = items[i]
                rowIndex = rowIndex + 1
                local button = AcquireListRow(rowIndex)
                local selected = selectedId and tonumber(build.id) == tonumber(selectedId)
                local active = LPL.TalentAPI:MatchesLive(build)
                local border = BORDER
                local bg = { 0.18, 0.18, 0.22, 1 }
                if selected then
                    bg = SELECTED
                    border = { 0.48, 0.11, 0.16, 1 }
                elseif active then
                    border = { 0.50, 1.00, 0.55, 1 }
                end
                local rowIndent = 28
                button:SetSize(width - rowIndent, 40)
                Paint(button, bg, border)
                button.expand:Hide()
                button.badge:SetShown(active)
                button.badge:ClearAllPoints()
                button.badge:SetPoint("LEFT", 8, 6)
                button.label:ClearAllPoints()
                button.label:SetPoint("TOPLEFT", active and 22 or 12, -6)
                button.label:SetPoint("RIGHT", button, "RIGHT", -8, 0)
                button.label:SetText(build.name or "Build")
                button.label:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
                button.subtitle:Show()
                button.subtitle:ClearAllPoints()
                button.subtitle:SetPoint("TOPLEFT", button.label, "BOTTOMLEFT", 0, -2)
                button.subtitle:SetPoint("RIGHT", button, "RIGHT", -8, 0)
                button.subtitle:SetText(LPL.TalentAPI:Summary(build))
                button:SetPoint("TOPLEFT", 4 + rowIndent, -y)
                button:SetScript("OnClick", function()
                    selectedId = build.id
                    RefreshList()
                end)
                button:SetScript("OnDoubleClick", function()
                    selectedId = build.id
                    UI:EditSelected()
                end)
                button:Show()
                y = y + 44
            end
        end
    end
    frame.listChild:SetWidth(width + 8)
    frame.listChild:SetHeight(math.max(y, 40))
end

local function AcquireNode(index)
    local button = nodeButtons[index]
    if button then
        return button
    end
    local parent = frame.treeChild or frame.editorTrees
    button = CreateFrame("Button", nil, parent)
    button:SetSize(40, 40)
    button.shadow = button:CreateTexture(nil, "BACKGROUND")
    button.shadow:SetPoint("CENTER")
    button.glow = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    button.glow:SetPoint("CENTER")
    button.glow:SetBlendMode("ADD")
    button.glow:Hide()
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetPoint("TOPLEFT", 6, -6)
    button.icon:SetPoint("BOTTOMRIGHT", -6, 6)
    if button.CreateMaskTexture then
        local ok, mask = pcall(button.CreateMaskTexture, button)
        if ok then
            button.iconMask = mask
        end
    end
    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetPoint("CENTER")
    button.rankBg = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.rankBg:SetColorTexture(0, 0, 0, 0.75)
    button.rankBg:SetSize(32, 13)
    button.rankBg:SetPoint("BOTTOM", button, "BOTTOM", 0, -4)
    button.rank = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.rank:SetPoint("CENTER", button.rankBg, "CENTER", 0, 0)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.talentName or "Talent", 1, 1, 1)
        if self.rankText then
            GameTooltip:AddLine(self.rankText, 1, 0.82, 0, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    nodeButtons[index] = button
    return button
end

local barPool = {}

local function AcquireBar(index)
    local bar = barPool[index]
    if bar then
        return bar
    end
    local parent = frame.treeChild or frame.editorTrees
    bar = parent:CreateTexture(nil, "BORDER")
    bar:SetColorTexture(0.82, 0.82, 0.82, 1)
    barPool[index] = bar
    return bar
end

local function HideBars()
    for i = 1, #barPool do
        barPool[i]:Hide()
    end
end

local NODE = 42
local STEP = 54
local TREE_GAP = 36

local function TreeColumnPad(talents)
    local seen = {}
    local columns = {}
    for i = 1, #talents do
        local col = talents[i].column or 1
        if not seen[col] then
            seen[col] = talents[i].posX or 0
            columns[#columns + 1] = { col = col, x = seen[col] }
        end
    end
    table.sort(columns, function(a, b)
        return a.col < b.col
    end)
    local deltas = {}
    for i = 2, #columns do
        local delta = columns[i].x - columns[i - 1].x
        if delta > 0 then
            deltas[#deltas + 1] = delta
        end
    end
    table.sort(deltas)
    local step = deltas[math.max(1, math.ceil(#deltas * 0.5))] or 1
    local pad = {}
    local extra = 0
    if columns[1] then
        pad[columns[1].col] = 0
    end
    for i = 2, #columns do
        if columns[i].x - columns[i - 1].x >= step * 1.75 then
            extra = extra + 1
        end
        pad[columns[i].col] = extra
    end
    return pad
end

local function PlaceholderName(name)
    if name == nil then
        return true
    end
    if issecretvalue and issecretvalue(name) then
        return false
    end
    if type(name) ~= "string" or name == "" or name == "Talents" then
        return true
    end
    return name:match("^Tree %d+$") ~= nil
end

local function CommonTabName(nodes)
    local counts, order = {}, {}
    local className = LPL.TalentAPI:ClassName()
    for i = 1, #nodes do
        local text = nodes[i].tabName
        if type(text) == "string" and text ~= "" and text ~= className then
            if not counts[text] then
                order[#order + 1] = text
                counts[text] = 0
            end
            counts[text] = counts[text] + 1
        end
    end
    local best, bestCount
    for i = 1, #order do
        local text = order[i]
        if not bestCount or counts[text] > bestCount then
            best, bestCount = text, counts[text]
        end
    end
    if best and bestCount >= 2 then
        return best
    end
    return nil
end

local function HeaderForNodes(nodes)
    local headers = LPL.TalentAPI:TreeHeaders()
    if type(headers) ~= "table" or not nodes then
        return nil
    end
    local minX, maxX
    for i = 1, #nodes do
        local x = nodes[i].posX or 0
        if not minX or x < minX then
            minX = x
        end
        if not maxX or x > maxX then
            maxX = x
        end
    end
    if not minX then
        return nil
    end
    local className = LPL.TalentAPI:ClassName()
    local bestName, bestY
    for i = 1, #headers do
        local x = headers[i].posX or 0
        local headerName = headers[i].name
        if x >= minX and x <= maxX and type(headerName) == "string" and headerName ~= "" and headerName ~= className then
            local y = headers[i].posY or 0
            if not bestY or y < bestY then
                bestName, bestY = headerName, y
            end
        end
    end
    return bestName
end

local function ClusterName(nodes, fallback)
    for i = 1, #nodes do
        local raw = nodes[i].rawSubTreeID
        if raw ~= nil and C_Traits and C_Traits.GetSubTreeInfo then
            local ok, info = pcall(C_Traits.GetSubTreeInfo, raw)
            if ok and type(info) == "table" then
                local treeName = info.name
                if (issecretvalue and issecretvalue(treeName)) or (type(treeName) == "string" and treeName ~= "") then
                    return treeName
                end
            end
        end
        if nodes[i].treeName ~= nil then
            return nodes[i].treeName
        end
    end
    local counts = {}
    for i = 1, #nodes do
        local id = nodes[i].subTreeID
        if type(id) == "number" and id > 0 then
            counts[id] = (counts[id] or 0) + 1
        end
    end
    local bestId, bestCount
    for id, count in pairs(counts) do
        if not bestCount or count > bestCount then
            bestId, bestCount = id, count
        end
    end
    if bestId and C_Traits and C_Traits.GetSubTreeInfo then
        local ok, info = pcall(C_Traits.GetSubTreeInfo, bestId)
        if ok and type(info) == "table" then
            local treeName = info.name
            if (issecretvalue and issecretvalue(treeName)) or (type(treeName) == "string" and treeName ~= "") then
                return treeName
            end
        end
    end
    return fallback
end

local function AxisIndex(nodes, key)
    local seen, list = {}, {}
    for i = 1, #nodes do
        local value = math.floor((nodes[i][key] or 0) + 0.5)
        if not seen[value] then
            seen[value] = true
            list[#list + 1] = value
        end
    end
    table.sort(list)
    local index = {}
    for i = 1, #list do
        index[list[i]] = i - 1
    end
    return index, math.max(#list - 1, 0)
end

local function PlaceNodes()
    for i = 1, #nodeButtons do
        nodeButtons[i]:Hide()
    end
    for i = 1, #linePool do
        linePool[i]:Hide()
    end
    if frame.groupLabels then
        for i = 1, #frame.groupLabels do
            frame.groupLabels[i]:Hide()
        end
    end
    if frame.dividers then
        for i = 1, #frame.dividers do
            frame.dividers[i]:Hide()
        end
    end
    HideBars()
    if frame.tabRow then
        frame.tabRow:Hide()
    end
    if not draft or not LPL.TalentAPI:Available() then
        return
    end
    local parent = frame.treeChild or frame.editorTrees
    if not parent then
        return
    end
    local viewW, viewH = 860, 560
    if frame.treeScroll and parent == frame.treeChild then
        if frame.treeScroll:GetWidth() > 50 then
            viewW = frame.treeScroll:GetWidth()
        end
        if frame.treeScroll:GetHeight() > 50 then
            viewH = frame.treeScroll:GetHeight()
        end
        parent:SetSize(viewW, viewH)
        if frame.treeScroll.SetVerticalScroll then
            frame.treeScroll:SetVerticalScroll(0)
        end
        if frame.treeScroll.SetHorizontalScroll then
            frame.treeScroll:SetHorizontalScroll(0)
        end
    end

    local panels = {}
    local specNames = LPL.TalentAPI:SpecializationNames()
    local tabCount = LPL.TalentAPI:TabCount()
    if tabCount > 1 then
        for tabIndex = 1, tabCount do
            local info = LPL.TalentAPI:TabInfo(tabIndex)
            local name = specNames[tabIndex]
            if not name then
                name = info.name
            end
            if PlaceholderName(name) then
                name = specNames[tabIndex] or info.name or ("Tree " .. tostring(tabIndex))
            end
            panels[#panels + 1] = {
                apiTab = tabIndex,
                name = name,
                nodes = LPL.TalentAPI:Talents(tabIndex),
            }
        end
    else
        local nodes = LPL.TalentAPI:Talents(1)
        local rawX = {}
        for i = 1, #nodes do
            rawX[i] = nodes[i].posX or 0
        end
        local stepX = GridStep(rawX)
        local groups = SplitClusters(nodes, stepX)
        for i = 1, #groups do
            panels[#panels + 1] = {
                apiTab = 1,
                name = specNames[i] or CommonTabName(groups[i]) or HeaderForNodes(groups[i]) or ClusterName(groups[i], "Tree " .. tostring(i)),
                nodes = groups[i],
            }
        end
    end
    if #panels < 1 then
        return
    end

    local budget = LPL.TalentAPI:PointBudget()
    local spent = tonumber(draft.totalPoints) or 0
    local panelW = viewW / #panels
    local headerH = 28
    frame.treeHeaders = frame.treeHeaders or {}
    frame.dividers = frame.dividers or {}
    local centers = {}
    local entries = {}
    local used = 0
    local layouts = {}
    local maxSpanX, maxSpanY = 0, 0
    for g = 1, #panels do
        local xIndex, spanX = AxisIndex(panels[g].nodes, "posX")
        local yIndex, spanY = AxisIndex(panels[g].nodes, "posY")
        layouts[g] = { xIndex = xIndex, yIndex = yIndex, spanX = spanX, spanY = spanY }
        if spanX > maxSpanX then
            maxSpanX = spanX
        end
        if spanY > maxSpanY then
            maxSpanY = spanY
        end
    end
    local cell = math.min((panelW - 28) / math.max(maxSpanX + 1, 1), (viewH - headerH - 16) / math.max(maxSpanY + 1, 1))
    if cell > 40 then
        cell = 40
    end
    if cell < 30 then
        cell = 30
    end
    local nodeSize = cell - 8

    for g = 1, #panels do
        local panel = panels[g]
        local nodes = panel.nodes
        local layout = layouts[g]
        local xIndex, spanX = layout.xIndex, layout.spanX
        local yIndex, spanY = layout.yIndex, layout.spanY
        local gridW = spanX * cell + nodeSize
        local originX = (g - 1) * panelW + (panelW - gridW) / 2
        local originY = headerH + 8

        local header = frame.treeHeaders[g]
        if not header then
            header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
            frame.treeHeaders[g] = header
        end
        local points = 0
        for i = 1, #nodes do
            points = points + LPL.TalentAPI:DraftRank(draft, panel.apiTab, nodes[i].talentIndex)
        end
        local headerName = panel.name or "Talents"
        if not header.points then
            header.points = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.points:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        end
        if issecretvalue and issecretvalue(headerName) then
            header:SetText(headerName)
            header.points:SetText(tostring(points))
            header.points:ClearAllPoints()
            header.points:SetPoint("LEFT", header, "RIGHT", 8, 0)
            header.points:Show()
        else
            header.points:Hide()
            header:SetText(tostring(headerName) .. "   " .. tostring(points))
        end
        header:ClearAllPoints()
        header:SetPoint("TOP", parent, "TOPLEFT", (g - 1) * panelW + panelW / 2, -6)
        header:Show()

        if g > 1 then
            local divider = frame.dividers[g - 1]
            if not divider then
                divider = parent:CreateTexture(nil, "BACKGROUND")
                divider:SetColorTexture(0.35, 0.32, 0.22, 0.55)
                frame.dividers[g - 1] = divider
            end
            divider:ClearAllPoints()
            divider:SetPoint("TOP", parent, "TOPLEFT", (g - 1) * panelW, -4)
            divider:SetPoint("BOTTOM", parent, "BOTTOMLEFT", (g - 1) * panelW, 4)
            divider:SetWidth(1)
            divider:Show()
        end

        local rowsBefore = {}
        for n = 1, #nodes do
            local talent = nodes[n]
            local col = xIndex[math.floor((talent.posX or 0) + 0.5)] or 0
            local row = yIndex[math.floor((talent.posY or 0) + 0.5)] or 0
            used = used + 1
            local button = nodeButtons[used]
            if not button or button.rankBg or not button.borderReady then
                button = CreateFrame("Button", nil, parent, "BackdropTemplate")
                button:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 2,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 },
                })
                button.borderReady = true
                button.icon = button:CreateTexture(nil, "ARTWORK")
                button.icon:SetPoint("TOPLEFT", 3, -3)
                button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
                button.shade = button:CreateTexture(nil, "OVERLAY")
                button.shade:SetPoint("TOPLEFT", 3, -3)
                button.shade:SetPoint("BOTTOMRIGHT", -3, 3)
                button.shade:SetColorTexture(0, 0, 0, 0.45)
                button.rank = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                button.rank:SetPoint("BOTTOMRIGHT", -2, 3)
                nodeButtons[used] = button
            end
            button:SetParent(parent)
            button:SetSize(nodeSize, nodeSize)
            button:SetFrameLevel((parent:GetFrameLevel() or 1) + 4)
            button.layoutX = originX + col * cell
            button.layoutY = originY + row * cell
            button.layoutSize = nodeSize
            button.layoutCol = col
            button.layoutRow = row
            button.layoutPanel = g
            local rank = LPL.TalentAPI:DraftRank(draft, panel.apiTab, talent.talentIndex)
            local before = rowsBefore[row]
            if before == nil then
                before = 0
                for i = 1, #nodes do
                    local otherRow = yIndex[math.floor((nodes[i].posY or 0) + 0.5)] or 0
                    if otherRow < row then
                        before = before + LPL.TalentAPI:DraftRank(draft, panel.apiTab, nodes[i].talentIndex)
                    end
                end
                rowsBefore[row] = before
            end
            local canAdd = rank < (talent.maxRank or 1) and spent < budget and before >= (row * 5)
            if talent.icon then
                button.icon:SetTexture(talent.icon)
                button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            local locked = rank <= 0 and not canAdd
            button.icon:SetDesaturated(locked)
            button.shade:SetShown(locked)
            button:SetBackdropColor(0.04, 0.04, 0.04, 1)
            if canAdd then
                button:SetBackdropBorderColor(0.15, 1.00, 0.20, 1)
            elseif rank > 0 then
                button:SetBackdropBorderColor(0.95, 0.78, 0.28, 1)
            else
                button:SetBackdropBorderColor(0.32, 0.32, 0.32, 1)
            end
            button.rank:SetText(tostring(rank) .. "/" .. tostring(talent.maxRank))
            if rank <= 0 then
                button.rank:SetTextColor(0.75, 0.75, 0.75)
            elseif rank >= (talent.maxRank or 1) then
                button.rank:SetTextColor(1, 0.82, 0)
            else
                button.rank:SetTextColor(0.2, 1, 0.2)
            end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", parent, "TOPLEFT", originX + col * cell, -(originY + row * cell))
            local tabNumber = panel.apiTab
            local talentNumber = talent.talentIndex
            local talentName = talent.name
            button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            button:SetScript("OnClick", function(_, mouseButton)
                if mouseButton == "RightButton" then
                    UI:ChangeRank(tabNumber, talentNumber, -1, talentName)
                else
                    UI:ChangeRank(tabNumber, talentNumber, 1, talentName)
                end
            end)
            button:SetScript("OnEnter", function()
                LPL.TalentAPI:ShowTooltip(button, talent, rank)
            end)
            button:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            button:Show()
            centers[talent.talentIndex] = button
            entries[#entries + 1] = {
                talent = talent,
                button = button,
                col = col,
                row = row,
                panel = g,
            }
        end
    end

    for i = #panels + 1, #frame.treeHeaders do
        frame.treeHeaders[i]:Hide()
        if frame.treeHeaders[i].points then
            frame.treeHeaders[i].points:Hide()
        end
    end

    local linked = {}
    local pointedAt = {}
    local function MarkLink(a, b)
        if not a or not b or a == b then
            return
        end
        local key = a < b and (tostring(a) .. ":" .. tostring(b)) or (tostring(b) .. ":" .. tostring(a))
        if linked[key] then
            return
        end
        linked[key] = true
    end

    for n = 1, #entries do
        local talent = entries[n].talent
        local edges = talent.edges
        if type(edges) == "table" then
            for e = 1, #edges do
                local target = edges[e].target
                if centers[talent.talentIndex] and centers[target] then
                    MarkLink(talent.talentIndex, target)
                    pointedAt[target] = true
                end
            end
        end
    end

    for n = 1, #entries do
        local entry = entries[n]
        local id = entry.talent.talentIndex
        if not pointedAt[id] then
            local best, bestScore
            for i = 1, #entries do
                local other = entries[i]
                if other.panel == entry.panel and other.row < entry.row then
                    local score = (entry.row - other.row) * 100 + math.abs(other.col - entry.col)
                    if not best or score < bestScore then
                        best = other
                        bestScore = score
                    end
                end
            end
            if best then
                MarkLink(id, best.talent.talentIndex)
            end
        end
    end

    local barCount = 0
    local function Segment(x1, y1, x2, y2)
        local dx = x2 - x1
        local dy = y2 - y1
        if math.abs(dx) < 1 and math.abs(dy) < 1 then
            return
        end
        barCount = barCount + 1
        local bar = AcquireBar(barCount)
        if not bar then
            return
        end
        bar:ClearAllPoints()
        if math.abs(dx) >= math.abs(dy) then
            local left = math.min(x1, x2)
            local width = math.abs(dx)
            if width < 2 then
                width = 2
            end
            bar:SetSize(width, 3)
            bar:SetPoint("LEFT", parent, "TOPLEFT", left, -y1)
        else
            local top = math.min(y1, y2)
            local height = math.abs(dy)
            if height < 2 then
                height = 2
            end
            bar:SetSize(3, height)
            bar:SetPoint("TOP", parent, "TOPLEFT", x1, -top)
        end
        bar:Show()
    end

    local function LinkButtons(a, b)
        if not a or not b or not a.layoutSize or not b.layoutSize then
            return
        end
        local ax = a.layoutX + a.layoutSize / 2
        local aBottom = a.layoutY + a.layoutSize
        local aTop = a.layoutY
        local bx = b.layoutX + b.layoutSize / 2
        local bTop = b.layoutY
        local bBottom = b.layoutY + b.layoutSize
        if a.layoutY > b.layoutY then
            ax, aBottom, aTop, bx, bTop, bBottom = bx, bBottom, b.layoutY, ax, aTop, aBottom
        end
        if math.abs(ax - bx) < 4 then
            Segment(ax, aBottom, bx, bTop)
            return
        end
        local mid = aBottom + math.max(8, (bTop - aBottom) * 0.45)
        if mid > bTop - 4 then
            mid = (aBottom + bTop) / 2
        end
        Segment(ax, aBottom, ax, mid)
        Segment(ax, mid, bx, mid)
        Segment(bx, mid, bx, bTop)
    end

    for key in pairs(linked) do
        local left, right = key:match("^(%d+):(%d+)$")
        local a = tonumber(left)
        local b = tonumber(right)
        if a and b then
            LinkButtons(centers[a], centers[b])
        end
    end
    for i = barCount + 1, #barPool do
        barPool[i]:Hide()
    end
end

function UI:ChangeRank(tabIndex, talentIndex, delta, talentName)
    if not draft then
        return
    end
    if not LPL.TalentAPI:SameClass(draft) then
        Speak("This build is for a different class.")
        return
    end
    local ok, reason
    if delta > 0 then
        ok, reason = LPL.TalentAPI:CanAdd(draft, tabIndex, talentIndex)
        if ok then
            local rank = LPL.TalentAPI:DraftRank(draft, tabIndex, talentIndex)
            LPL.TalentAPI:SetDraftRank(draft, tabIndex, talentIndex, rank + 1)
        end
    else
        ok, reason = LPL.TalentAPI:CanRemove(draft, tabIndex, talentIndex)
        if ok then
            local rank = LPL.TalentAPI:DraftRank(draft, tabIndex, talentIndex)
            LPL.TalentAPI:SetDraftRank(draft, tabIndex, talentIndex, rank - 1)
        end
    end
    if not ok then
        Speak(reason or "That rank cannot change.")
        frame.detail:SetText(reason or "")
        return
    end
    local rank = LPL.TalentAPI:DraftRank(draft, tabIndex, talentIndex)
    local planned = tonumber(draft.totalPoints) or 0
    local line = (talentName or "Talent") .. "  " .. tostring(rank)
    frame.detail:SetText(line .. ". Build " .. tostring(planned) .. " / 51. Apply spends the points you have.")
    Speak(line)
    PlaceNodes()
end

local function ShowList()
    mode = "list"
    draft = nil
    SetTabActive("talents")
    ShowPage("list")
    RefreshList()
end

local function ShowEditor(build, isNew)
    mode = "editor"
    draft = build
    viewTab = 1
    SetTabActive("talents")
    ShowPage("editor")
    frame.nameBox:SetText((build and build.name) or "Leveling")
    frame.detail:SetText("Plan up to 51 points. Apply spends the unspent points you have. Left click adds a rank. Right click removes one.")
    PlaceNodes()
    if isNew then
        Speak("New talent build.")
    end
end

function UI:OpenSection(id, label)
    if id == "actionbars" or id == "keybinds" or id == "equipment" or id == "editmode" or id == "loadouts" then
        SetTabActive(id)
        ShowPage("section")
        if LPL.Sections then
            LPL.Sections:Open(id)
        end
        return
    end
    if id == "talents" then
        ShowList()
        return
    end
    if id == "builds" then
        SetTabActive("builds")
        ShowPage("import")
        local build = selectedId and LPL.TalentStore:Get(selectedId)
        if build and not frame.shareBox:HasFocus() then
            frame.shareBox:SetText(LPL.TalentAPI:Encode(build))
        end
        Speak("Import and export.")
        return
    end
    SetTabActive(id)
    ShowPage("later")
    frame.laterLabel:SetText((label or "This section") .. " is not in this version yet.")
    Speak((label or "This section") .. " is not in this version yet.")
end

function UI:NewBuild()
    if not LPL.TalentAPI:Available() then
        Speak("Talents are not available on this client.")
        return
    end
    selectedId = nil
    local build = EmptyDraft()
    build.name = "Leveling"
    ShowEditor(build, true)
end

function UI:EditSelected()
    local build = LPL.TalentStore:Get(selectedId)
    if not build then
        Speak("Select a saved build first.")
        return
    end
    ShowEditor(CopyBuild(build), false)
end

function UI:SaveDraft()
    if not draft then
        return
    end
    local name = frame.nameBox:GetText()
    local saved
    if draft.id then
        saved = LPL.TalentStore:Update(draft.id, draft, name)
    else
        saved = LPL.TalentStore:Save(draft, name)
    end
    selectedId = saved and saved.id
    Speak("Saved " .. ((saved and saved.name) or "build") .. ", " .. LPL.TalentAPI:Summary(saved))
    ShowList()
end

function UI:ApplyCurrent()
    local build = draft or LPL.TalentStore:Get(selectedId)
    if not build then
        ShowNotice("Select a saved build first.", true)
        return
    end
    local ran, ok, message = pcall(LPL.TalentAPI.Apply, LPL.TalentAPI, build)
    if not ran then
        ShowNotice("Apply could not finish. " .. tostring(ok), true)
        return false
    end
    local name = (type(build.name) == "string" and build.name ~= "" and build.name) or "This build"
    local line = name .. ": " .. (message or "Apply finished.")
    local warn = ok ~= true
        or (type(message) == "string" and (message:find("No unspent", 1, true) or message:find("Reset", 1, true) or message:find("needs more", 1, true)))
    ShowNotice(line, warn)
    if mode == "editor" then
        PlaceNodes()
    end
    return ok
end

function UI:LoadFromCharacter()
    if not draft then
        return
    end
    local live = LPL.TalentAPI:Capture()
    draft.tabs = live.tabs
    draft.totalPoints = live.totalPoints
    draft.classFile = live.classFile
    draft.classID = live.classID
    Speak("Updated this build from your character.")
    PlaceNodes()
end

function UI:ResetDraft()
    if not draft then
        return
    end
    local empty = EmptyDraft()
    draft.tabs = empty.tabs
    draft.totalPoints = 0
    Speak("Talent points cleared in this build.")
    PlaceNodes()
end

function UI:DeleteSelected()
    if not selectedId then
        Speak("Select a saved build first.")
        return
    end
    LPL.TalentStore:Delete(selectedId)
    selectedId = nil
    Speak("Build deleted.")
    ShowList()
end

function UI:ImportCode()
    local text = frame.shareBox:GetText()
    local build, err = LPL.TalentAPI:Decode(text)
    if not build then
        Speak(err or "Could not read that code.")
        return
    end
    local saved = LPL.TalentStore:Save(build, frame.importName:GetText())
    selectedId = saved and saved.id
    Speak("Imported " .. ((saved and saved.name) or "build"))
    ShowList()
end

local function CreateSidebar(parent)
    local sidebar = CreateFrame("Frame", "LPLSidebar", parent, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -TITLE_H)
    sidebar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(SIDEBAR_W)
    Paint(sidebar, SIDEBAR_BG, BORDER)

    local tabs = {}
    local topCount = 0
    local bottomCount = 0
    for i = 1, #TABS do
        if TABS[i].bottom then
            bottomCount = bottomCount + 1
        else
            topCount = topCount + 1
        end
    end

    local topIndex = 0
    local bottomFromBottom = 10
    for i = #TABS, 1, -1 do
        local data = TABS[i]
        if data.bottom then
            local tab = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
            tab:SetSize(TAB, TAB)
            tab:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, bottomFromBottom)
            bottomFromBottom = bottomFromBottom + TAB + TAB_GAP
            tab.moduleID = data.id
            tab.accent = tab:CreateTexture(nil, "BACKGROUND")
            tab.accent:SetWidth(3)
            tab.accent:SetPoint("TOPLEFT", 0, 0)
            tab.accent:SetPoint("BOTTOMLEFT", 0, 0)
            tab.accent:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], ACCENT[4])
            tab.accent:Hide()
            local icon = tab:CreateTexture(nil, "ARTWORK")
            icon:SetSize(32, 32)
            icon:SetPoint("CENTER")
            LPL:SetIconTexture(icon, data.stem)
            local label = data.label
            local id = data.id
            tab:SetScript("OnClick", function()
                UI:OpenSection(id, label)
            end)
            tab:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, 1, 1, 1)
                GameTooltip:Show()
            end)
            tab:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            tabs[#tabs + 1] = tab
        end
    end

    for i = 1, #TABS do
        local data = TABS[i]
        if not data.bottom then
            local tab = CreateFrame("Button", nil, sidebar, "BackdropTemplate")
            tab:SetSize(TAB, TAB)
            tab:SetPoint("TOP", sidebar, "TOP", 0, -10 - (topIndex * (TAB + TAB_GAP)))
            topIndex = topIndex + 1
            tab.moduleID = data.id
            tab.accent = tab:CreateTexture(nil, "BACKGROUND")
            tab.accent:SetWidth(3)
            tab.accent:SetPoint("TOPLEFT", 0, 0)
            tab.accent:SetPoint("BOTTOMLEFT", 0, 0)
            tab.accent:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], ACCENT[4])
            tab.accent:Hide()
            local icon = tab:CreateTexture(nil, "ARTWORK")
            icon:SetSize(32, 32)
            icon:SetPoint("CENTER")
            LPL:SetIconTexture(icon, data.stem)
            local label = data.label
            local id = data.id
            tab:SetScript("OnClick", function()
                UI:OpenSection(id, label)
            end)
            tab:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, 1, 1, 1)
                GameTooltip:Show()
            end)
            tab:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            tabs[#tabs + 1] = tab
        end
    end
    parent.tabs = tabs
end

local function CreateContent(parent)
    local host = CreateFrame("Frame", "LPLContentHost", parent, "BackdropTemplate")
    host:SetPoint("TOPLEFT", parent, "TOPLEFT", SIDEBAR_W, -TITLE_H)
    host:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    Paint(host, BG, BORDER)

    local listPage = CreateFrame("Frame", nil, host)
    listPage:SetAllPoints(host)
    frame.listPage = listPage

    local heading = listPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    heading:SetPoint("TOPLEFT", 16, -12)
    heading:SetText("Saved Talent Builds")
    heading:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local hint = listPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    hint:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -4)
    hint:SetText("Green dot = the build on this character. Click a class header to collapse it. Double-click a build to edit.")
    hint:SetTextColor(TEXT[1], TEXT[2], TEXT[3])

    local search = CreateFrame("EditBox", nil, listPage, "BackdropTemplate")
    search:SetSize(220, 24)
    search:SetPoint("TOPLEFT", 16, -56)
    search:SetAutoFocus(false)
    search:SetFontObject("GameFontHighlight")
    search:SetTextInsets(8, 8, 0, 0)
    Paint(search, { 0.08, 0.08, 0.10, 1 }, BORDER)
    local searchHint = search:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    searchHint:SetPoint("LEFT", 8, 0)
    searchHint:SetText("Search...")
    search:SetScript("OnTextChanged", function(self)
        searchHint:SetShown(self:GetText() == "")
        RefreshList()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    frame.searchBox = search

    local listScroll = CreateFrame("ScrollFrame", nil, listPage, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 8, -88)
    listScroll:SetPoint("BOTTOMRIGHT", -28, LIST_BAR_H + 44)
    frame.listScroll = listScroll
    local listChild = CreateFrame("Frame", nil, listScroll)
    listChild:SetSize(680, 40)
    listScroll:SetScrollChild(listChild)
    frame.listChild = listChild

    local emptyButton = GlowButton(listPage, "New Build", 160, 36)
    emptyButton:SetPoint("CENTER", listScroll, "CENTER", 0, 0)
    emptyButton:SetFrameLevel(listScroll:GetFrameLevel() + 5)
    emptyButton:SetClick(function()
        UI:NewBuild()
    end)
    frame.emptyButton = emptyButton

    local noMatch = listPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    noMatch:SetPoint("CENTER", listScroll, "CENTER", 0, 0)
    noMatch:SetText("No builds match your search.")
    noMatch:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    noMatch:Hide()
    frame.noMatch = noMatch

    local notice = listPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    notice:SetPoint("BOTTOMLEFT", listPage, "BOTTOMLEFT", 12, LIST_BAR_H + 6)
    notice:SetPoint("BOTTOMRIGHT", listPage, "BOTTOMRIGHT", -12, LIST_BAR_H + 6)
    notice:SetHeight(36)
    notice:SetJustifyH("LEFT")
    notice:SetJustifyV("MIDDLE")
    notice:SetTextColor(1, 0.82, 0)
    notice:SetText("")
    frame.notice = notice

    local listBar = CreateFrame("Frame", nil, listPage, "BackdropTemplate")
    listBar:SetPoint("BOTTOMLEFT", listPage, "BOTTOMLEFT", 0, 0)
    listBar:SetPoint("BOTTOMRIGHT", listPage, "BOTTOMRIGHT", 0, 0)
    listBar:SetHeight(LIST_BAR_H)
    Paint(listBar, TITLE_BG, BORDER)

    local newButton = GlowButton(listBar, "New Build", 110, 22)
    newButton:SetPoint("LEFT", 6, 0)
    newButton:SetClick(function()
        UI:NewBuild()
    end)
    local editButton = BarButton(listBar, "Edit", 80)
    editButton:SetPoint("RIGHT", -12, 0)
    editButton:SetScript("OnClick", function()
        UI:EditSelected()
    end)
    local applyButton = BarButton(listBar, "Apply", 80)
    applyButton:SetPoint("RIGHT", editButton, "LEFT", -8, 0)
    applyButton:SetScript("OnClick", function()
        UI:ApplyCurrent()
    end)
    local deleteButton = BarButton(listBar, "Delete", 80)
    deleteButton:SetPoint("RIGHT", applyButton, "LEFT", -8, 0)
    deleteButton:SetScript("OnClick", function()
        UI:DeleteSelected()
    end)

    local editorPage = CreateFrame("Frame", nil, host)
    editorPage:SetAllPoints(host)
    editorPage:Hide()
    frame.editorPage = editorPage

    local detail = editorPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detail:SetPoint("TOPLEFT", 16, -10)
    detail:SetPoint("RIGHT", editorPage, "RIGHT", -16, 0)
    detail:SetJustifyH("LEFT")
    detail:SetHeight(32)
    detail:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    frame.detail = detail

    local tabRow = CreateFrame("Frame", nil, editorPage)
    tabRow:SetPoint("TOPLEFT", 12, -42)
    tabRow:SetPoint("TOPRIGHT", -12, -42)
    tabRow:SetHeight(30)
    frame.treeTabs = {}
    for tabIndex = 1, 3 do
        local tab = CreateFrame("Button", nil, tabRow, "BackdropTemplate")
        tab:SetSize(210, 28)
        tab:SetPoint("LEFT", tabRow, "LEFT", (tabIndex - 1) * 218, 0)
        tab.label = tab:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tab.label:SetPoint("CENTER")
        local index = tabIndex
        tab:SetScript("OnClick", function()
            viewTab = index
            if frame.treeScroll then
                frame.treeScroll:SetVerticalScroll(0)
            end
            PlaceNodes()
            Speak(tab.label:GetText() or "Tree")
        end)
        frame.treeTabs[tabIndex] = tab
    end

    frame.tabRow = tabRow
    tabRow:Hide()

    local editorTrees = CreateFrame("Frame", nil, editorPage)
    editorTrees:SetPoint("TOPLEFT", 0, -40)
    editorTrees:SetPoint("BOTTOMRIGHT", 0, TREE_BAR_H)
    frame.editorTrees = editorTrees
    frame.treeHeaders = {}

    local treeScroll = CreateFrame("ScrollFrame", nil, editorTrees, "UIPanelScrollFrameTemplate")
    treeScroll:SetPoint("TOPLEFT", 4, 0)
    treeScroll:SetPoint("BOTTOMRIGHT", -22, 0)
    local treeChild = CreateFrame("Frame", nil, treeScroll)
    treeChild:SetSize(400, 400)
    treeScroll:SetScrollChild(treeChild)
    frame.treeScroll = treeScroll
    frame.treeChild = treeChild
    treeScroll:SetScript("OnSizeChanged", function(self)
        if mode == "editor" and self:GetWidth() > 100 and not self.placing then
            self.placing = true
            PlaceNodes()
            self.placing = false
        end
    end)

    local treeBar = CreateFrame("Frame", nil, editorPage, "BackdropTemplate")
    treeBar:SetPoint("BOTTOMLEFT", editorPage, "BOTTOMLEFT", 0, 0)
    treeBar:SetPoint("BOTTOMRIGHT", editorPage, "BOTTOMRIGHT", 0, 0)
    treeBar:SetHeight(TREE_BAR_H)
    Paint(treeBar, TITLE_BG, BORDER)

    local nameLabel = treeBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    nameLabel:SetPoint("TOPLEFT", 12, -10)
    nameLabel:SetText("Build name")
    nameLabel:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local nameBox = CreateFrame("EditBox", nil, treeBar, "InputBoxTemplate")
    nameBox:SetSize(280, 24)
    nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
    nameBox:SetAutoFocus(false)
    frame.nameBox = nameBox

    local backButton = BarButton(treeBar, "Back", 70)
    backButton:SetPoint("BOTTOMLEFT", 12, 8)
    backButton:SetScript("OnClick", function()
        ShowList()
    end)
    local saveButton = BarButton(treeBar, "Save", 70)
    saveButton:SetPoint("LEFT", backButton, "RIGHT", 8, 0)
    saveButton:SetScript("OnClick", function()
        UI:SaveDraft()
    end)
    local loadButton = BarButton(treeBar, "Update from current character", 230)
    loadButton:SetPoint("LEFT", saveButton, "RIGHT", 8, 0)
    loadButton:SetScript("OnClick", function()
        UI:LoadFromCharacter()
    end)
    local resetButton = BarButton(treeBar, "Reset", 70)
    resetButton:SetPoint("LEFT", loadButton, "RIGHT", 8, 0)
    resetButton:SetScript("OnClick", function()
        UI:ResetDraft()
    end)
    local editorApply = BarButton(treeBar, "Apply", 80)
    editorApply:SetPoint("BOTTOMRIGHT", -12, 8)
    editorApply:SetScript("OnClick", function()
        UI:ApplyCurrent()
    end)

    local importPage = CreateFrame("Frame", nil, host)
    importPage:SetAllPoints(host)
    importPage:Hide()
    frame.importPage = importPage
    local importTitle = importPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    importTitle:SetPoint("TOPLEFT", 16, -16)
    importTitle:SetText("Import / Export")
    importTitle:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    local importHint = importPage:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    importHint:SetPoint("TOPLEFT", importTitle, "BOTTOMLEFT", 0, -8)
    importHint:SetText("The code is for the selected talent build. Highlight it and press control C. Paste a code, then Import.")
    importHint:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    local importName = CreateFrame("EditBox", nil, importPage, "InputBoxTemplate")
    importName:SetSize(220, 24)
    importName:SetPoint("TOPLEFT", 20, -80)
    importName:SetAutoFocus(false)
    importName:SetText("Imported")
    frame.importName = importName
    local shareBox = CreateFrame("EditBox", nil, importPage, "InputBoxTemplate")
    shareBox:SetPoint("TOPLEFT", 20, -120)
    shareBox:SetPoint("RIGHT", importPage, "RIGHT", -24, 0)
    shareBox:SetHeight(24)
    shareBox:SetAutoFocus(false)
    shareBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    frame.shareBox = shareBox
    local importButton = BarButton(importPage, "Import", 100)
    importButton:SetPoint("TOPLEFT", shareBox, "BOTTOMLEFT", 0, -12)
    importButton:SetScript("OnClick", function()
        UI:ImportCode()
    end)

    local laterPage = CreateFrame("Frame", nil, host)
    laterPage:SetAllPoints(host)
    laterPage:Hide()
    frame.laterPage = laterPage
    local laterLabel = laterPage:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    laterLabel:SetPoint("CENTER")
    laterLabel:SetTextColor(TEXT[1], TEXT[2], TEXT[3])
    frame.laterLabel = laterLabel

    if LPL.Sections then
        LPL.Sections:Attach(host)
    end
end

local function Ensure()
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", "LPLMainFrame", UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_W, FRAME_H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(720, 640, 1400, 1100)
    end
    Paint(frame, BG, BORDER)

    local db = LPL.DB:Bind(false)
    if type(db.ui) == "table" and type(db.ui.frame) == "table" and db.ui.frame.point then
        frame:ClearAllPoints()
        frame:SetPoint(db.ui.frame.point, UIParent, db.ui.frame.relativePoint or db.ui.frame.point, db.ui.frame.x or 0, db.ui.frame.y or 0)
        frame.locked = db.ui.frame.locked == true
    end

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(TITLE_H)
    Paint(titleBar, TITLE_BG, BORDER)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if not frame.locked then
            frame:StartMoving()
        end
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveFramePosition()
    end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("LEFT", 14, 0)
    titleText:SetText("Light Paws Loadouts - WoW Forever")
    titleText:SetTextColor(TEXT[1], TEXT[2], TEXT[3])

    local portrait = titleBar:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(32, 32)
    portrait:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    portrait:SetTexture(LPL.Icons.ADDON_64)
    portrait:SetTexCoord(0.06, 0.94, 0.06, 0.94)

    local closeButton = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -4, -4)
    closeButton:SetScript("OnClick", function()
        frame:Hide()
    end)

    local lockBtn = CreateFrame("Button", nil, titleBar)
    lockBtn:SetSize(16, 16)
    lockBtn:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    local function UpdateLock()
        if frame.locked then
            lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Locked-Up")
        else
            lockBtn:SetNormalTexture("Interface\\Buttons\\LockButton-Unlocked-Up")
        end
    end
    lockBtn:SetScript("OnClick", function()
        frame.locked = not frame.locked
        frame:SetMovable(not frame.locked)
        UpdateLock()
        SaveFramePosition()
        Speak(frame.locked and "Window locked." or "Window unlocked.")
    end)
    UpdateLock()

    local resizer = CreateFrame("Button", nil, frame)
    resizer:SetSize(16, 16)
    resizer:SetPoint("BOTTOMRIGHT", -2, 2)
    resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizer:SetScript("OnMouseDown", function()
        if not frame.locked then
            frame:StartSizing("BOTTOMRIGHT")
        end
    end)
    resizer:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SaveFramePosition()
    end)

    CreateSidebar(frame)
    CreateContent(frame)

    table.insert(UISpecialFrames, 1, "LPLMainFrame")
    frame:SetScript("OnShow", function()
        if not LPL.TalentAPI:Available() then
            frame.laterLabel:SetText("Talents are not available on this client.")
            SetTabActive("talents")
            ShowPage("later")
            Speak("Talents are not available on this client.")
            return
        end
        ShowList()
    end)
    return frame
end

function UI:Toggle()
    LPL.DB:Bind(false)
    local window = Ensure()
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end

function UI:OnWorld()
    if frame and frame:IsShown() and mode == "list" then
        RefreshList()
    end
    if LPL.Sections then
        LPL.Sections:OnWorld()
    end
end
