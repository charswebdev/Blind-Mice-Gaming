local addonName, LPL = ...

LPL.AddonSetEditor = {}

local ROW_HEIGHT = 26
local CHILD_INDENT = 22
local LOCK_SIZE = 16
local ADDON_ICON_SIZE = 18
local SCROLL_BOTTOM_PAD = 12

local function NormalizeSearch(text)
    if type(text) ~= "string" then
        return ""
    end
    return (text:lower():match("^%s*(.-)%s*$")) or ""
end

local function ApplyProtectLockTextures(button, locked, alwaysProtected)
    if not button or not button.icon then
        return
    end
    local stem = locked and "locked_64" or "unlock_64"
    if not LPL:SetIconTexture(button.icon, stem) then
        button.icon:SetTexture(locked and LPL.Icons.ADDON_LOCKED or LPL.Icons.ADDON_UNLOCKED)
    end
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.icon:SetVertexColor(1, 1, 1, 1)
    button:SetAlpha(alwaysProtected and 0.55 or 1)
end

-- Returns true when an icon was applied. No icon = hide (no question-mark placeholder).
local function ApplyAddonIconTexture(texture, info)
    if not texture then
        return false
    end

    local iconTexture = info and info.iconTexture
    local iconAtlas = info and info.iconAtlas

    texture:SetSize(ADDON_ICON_SIZE, ADDON_ICON_SIZE)
    texture:SetVertexColor(1, 1, 1, 1)

    if iconTexture then
        local fileID = tonumber(iconTexture)
        if fileID then
            texture:SetTexture(fileID)
        else
            texture:SetTexture(iconTexture:gsub("/", "\\"))
        end
        -- Keep full square; cropping made many addon icons look squished.
        texture:SetTexCoord(0, 1, 0, 1)
        return true
    end

    if iconAtlas and texture.SetAtlas then
        -- false = keep our square size instead of atlas native aspect.
        texture:SetAtlas(iconAtlas, false)
        texture:SetSize(ADDON_ICON_SIZE, ADDON_ICON_SIZE)
        texture:SetTexCoord(0, 1, 0, 1)
        return true
    end

    texture:SetTexture(nil)
    return false
end

function LPL.AddonSetEditor:Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.draft = nil
    frame.searchText = ""
    frame.showSelectedOnly = false
    frame.rows = {}
    frame.filtered = {}
    frame.collapsedCategories = {}

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -16)
    title:SetText("Addon Set")
    title:SetTextColor(LPL.Theme:GetColor("textBright"))

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    status:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    status:SetJustifyH("LEFT")
    status:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    frame.statusLabel = status

    local scopeLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scopeLabel:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -14)
    scopeLabel:SetText("Scope")
    scopeLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))

    local accountButton = LPL:CreateButton(nil, frame)
    accountButton:SetSize(110, 28)
    accountButton:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", 0, -8)
    accountButton:SetText("Account")
    accountButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Account scope", 1, 1, 1)
        GameTooltip:AddLine("Enable/disable addons for all characters on this account.", 0.75, 0.78, 0.85, true)
        GameTooltip:Show()
    end)
    accountButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local characterButton = LPL:CreateButton(nil, frame)
    characterButton:SetSize(110, 28)
    characterButton:SetPoint("LEFT", accountButton, "RIGHT", 8, 0)
    characterButton:SetText("Character")
    characterButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Character scope", 1, 1, 1)
        GameTooltip:AddLine("Enable/disable addons only for this character.", 0.75, 0.78, 0.85, true)
        GameTooltip:Show()
    end)
    characterButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLabel:SetPoint("LEFT", characterButton, "RIGHT", 16, 0)
    searchLabel:SetText("Search")
    searchLabel:SetTextColor(LPL.Theme:GetColor("textLabel"))

    local searchBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    searchBox:SetAutoFocus(false)
    searchBox:SetSize(180, 24)
    searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local selectedOnly = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    selectedOnly:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)
    selectedOnly:SetSize(24, 24)
    local selectedOnlyLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    selectedOnlyLabel:SetPoint("LEFT", selectedOnly, "RIGHT", 2, 0)
    selectedOnlyLabel:SetText("Selected only")
    selectedOnlyLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))

    local selectAllButton = LPL:CreateButton(nil, frame)
    selectAllButton:SetSize(110, 24)
    selectAllButton:SetPoint("TOPLEFT", accountButton, "BOTTOMLEFT", 0, -10)
    selectAllButton:SetText("Select All")
    selectAllButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Select All", 1, 1, 1)
        GameTooltip:AddLine("Check every addon currently visible in the list (respects search and filters).", 0.75, 0.78, 0.85, true)
        GameTooltip:Show()
    end)
    selectAllButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local clearShownButton = LPL:CreateButton(nil, frame)
    clearShownButton:SetSize(110, 24)
    clearShownButton:SetPoint("LEFT", selectAllButton, "RIGHT", 8, 0)
    clearShownButton:SetText("Unselect All")
    clearShownButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Unselect All", 1, 1, 1)
        GameTooltip:AddLine("Uncheck every addon currently visible in the list. Hidden addons stay as they are.", 0.75, 0.78, 0.85, true)
        GameTooltip:Show()
    end)
    clearShownButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local includeButton = LPL:CreateButton(nil, frame)
    includeButton:SetSize(130, 24)
    includeButton:SetPoint("LEFT", clearShownButton, "RIGHT", 8, 0)
    includeButton:SetText("Include Sets")

    local includeMenu = CreateFrame("Frame", "LPLAddonSetIncludeMenu", frame, "UIDropDownMenuTemplate")
    includeMenu:Hide()

    local listHost = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listHost:SetPoint("TOPLEFT", selectAllButton, "BOTTOMLEFT", 0, -10)
    listHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 16)
    LPL.Theme:ApplyBackdrop(listHost, "panel", "bgPrimary", "border")
    if listHost.SetBackdropColor then
        listHost:SetBackdropColor(0, 0, 0, 1)
    end

    local scroll = CreateFrame("ScrollFrame", nil, listHost, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", listHost, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", listHost, "BOTTOMRIGHT", -28, 8)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    content:EnableMouse(true)
    scroll:SetScrollChild(content)

    local emptyListLabel = listHost:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    emptyListLabel:SetPoint("CENTER", listHost, "CENTER", -10, 0)
    emptyListLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
    emptyListLabel:SetText("No addons match your search or filters.")
    emptyListLabel:Hide()

    frame.accountButton = accountButton
    frame.characterButton = characterButton
    frame.searchBox = searchBox
    frame.selectedOnly = selectedOnly
    frame.includeButton = includeButton
    frame.includeMenu = includeMenu
    frame.excludeSetID = nil
    frame.scroll = scroll
    frame.content = content
    frame.listHost = listHost
    frame.emptyListLabel = emptyListLabel

    local function RefreshScopeButtons()
        local scope = frame.draft and frame.draft.scope or LPL.AddonSetStore.SCOPE_ACCOUNT
        if scope == LPL.AddonSetStore.SCOPE_CHARACTER then
            LPL.Theme:ApplyBackdrop(characterButton, "button", "tabActive", "borderActive")
            LPL.Theme:ClearBackdrop(accountButton)
        else
            LPL.Theme:ApplyBackdrop(accountButton, "button", "tabActive", "borderActive")
            LPL.Theme:ClearBackdrop(characterButton)
        end
    end

    local function RefreshIncludeButton()
        if not frame.draft then
            includeButton:SetText("Include Sets")
            includeButton:Disable()
            return
        end
        local count = type(frame.draft.includes) == "table" and #frame.draft.includes or 0
        if count > 0 then
            includeButton:SetText(string.format("Include Sets (%d)", count))
        else
            includeButton:SetText("Include Sets")
        end
        local options = LPL.AddonSetStore:GetIncludableSets(frame.excludeSetID)
        if #options == 0 then
            includeButton:Disable()
        else
            includeButton:Enable()
        end
    end

    local function RefreshStatus()
        if not frame.draft then
            frame.statusLabel:SetText("No draft.")
            frame.statusLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
            return
        end
        frame.statusLabel:SetText(LPL.AddonSetStore:GetEditorStatusLine(frame.draft))
        if LPL.AddonSetStore:CountMissingAddons(frame.draft.addons) > 0 then
            frame.statusLabel:SetTextColor(1, 0.55, 0.35)
        else
            frame.statusLabel:SetTextColor(LPL.Theme:GetColor("textSecondary"))
        end
        RefreshIncludeButton()
    end

    local function MembershipMap()
        return LPL.AddonSetStore:BuildMembershipMap(frame.draft and frame.draft.addons)
    end

    local function RebuildFiltered()
        wipe(frame.filtered)
        if not frame.draft then
            return
        end
        local entries = LPL.AddonSetStore:BuildDisplayEntries({
            query = NormalizeSearch(frame.searchText),
            selectedOnly = frame.showSelectedOnly,
            selectedMap = MembershipMap(),
            collapsed = frame.collapsedCategories,
            draftAddons = frame.draft.addons,
        })
        for _, entry in ipairs(entries) do
            frame.filtered[#frame.filtered + 1] = entry
        end
    end

    local function EnsureRows(count)
        while #frame.rows < count do
            local index = #frame.rows + 1
            local row = CreateFrame("Button", nil, content, "BackdropTemplate")
            row:SetHeight(ROW_HEIGHT)
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
            row:SetWidth(100)
            row:RegisterForClicks("LeftButtonUp")
            row:EnableMouseWheel(true)
            row:SetScript("OnMouseWheel", function(_, delta)
                local handler = scroll:GetScript("OnMouseWheel")
                if handler then
                    handler(scroll, delta)
                end
            end)

            local headerBar = row:CreateTexture(nil, "BACKGROUND")
            headerBar:SetHeight(ROW_HEIGHT - 4)
            headerBar:SetPoint("LEFT", row, "LEFT", 0, 0)
            headerBar:SetPoint("RIGHT", row, "RIGHT", 0, 0)
            headerBar:SetColorTexture(0.85, 0.7, 0.2, 0.18)
            headerBar:Hide()
            row.headerBar = headerBar

            local expand = row:CreateTexture(nil, "ARTWORK")
            expand:SetSize(12, 12)
            expand:SetPoint("LEFT", row, "LEFT", 6, 0)
            expand:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
            row.expandIcon = expand

            local headerLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            headerLabel:SetPoint("LEFT", expand, "RIGHT", 6, 0)
            headerLabel:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            headerLabel:SetJustifyH("LEFT")
            headerLabel:SetTextColor(1, 0.82, 0)
            row.headerLabel = headerLabel

            local lock = CreateFrame("Button", nil, row)
            lock:SetSize(LOCK_SIZE, LOCK_SIZE)
            lock:SetPoint("LEFT", row, "LEFT", 4, 0)
            lock:RegisterForClicks("LeftButtonUp")
            local lockIcon = lock:CreateTexture(nil, "ARTWORK")
            lockIcon:SetAllPoints(lock)
            lock.icon = lockIcon
            local lockHighlight = lock:CreateTexture(nil, "HIGHLIGHT")
            lockHighlight:SetAllPoints(lock)
            lockHighlight:SetColorTexture(1, 1, 1, 0.18)
            row.lock = lock

            local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
            check:SetSize(24, 24)
            check:SetPoint("LEFT", lock, "RIGHT", 4, 0)
            row.check = check

            local addonIcon = row:CreateTexture(nil, "ARTWORK")
            addonIcon:SetSize(ADDON_ICON_SIZE, ADDON_ICON_SIZE)
            addonIcon:SetPoint("LEFT", check, "RIGHT", 4, 0)
            addonIcon:Hide()
            row.addonIcon = addonIcon

            local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("LEFT", addonIcon, "RIGHT", 6, 0)
            label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            label:SetJustifyH("LEFT")
            label:SetWordWrap(false)
            row.label = label

            local live = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            live:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            live:SetJustifyH("RIGHT")
            row.liveLabel = live

            check:SetScript("OnClick", function(self)
                if not frame.draft or not row.addonName then
                    return
                end
                frame.draft.addons = LPL.AddonSetStore:SetMembership(frame.draft.addons, row.addonName, self:GetChecked())
                RefreshStatus()
                if frame.showSelectedOnly then
                    frame:RebuildList()
                end
            end)

            lock:SetScript("OnClick", function(self)
                if not row.addonName or row.missing then
                    return
                end
                if LPL.AddonSetStore:IsAlwaysProtected(row.addonName) then
                    return
                end
                local nextState = not LPL.AddonSetStore:IsProtected(row.addonName)
                LPL.AddonSetStore:SetProtected(row.addonName, nextState)
                ApplyProtectLockTextures(self, nextState, false)
            end)

            lock:SetScript("OnEnter", function(self)
                if not row.addonName then
                    return
                end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                if LPL.AddonSetStore:IsAlwaysProtected(row.addonName) then
                    GameTooltip:SetText("Always protected", 1, 1, 1)
                    GameTooltip:AddLine("Light Paws Loadouts - Classic Era cannot be disabled by Addon Sets.", 0.75, 0.78, 0.85, true)
                elseif LPL.AddonSetStore:IsProtected(row.addonName) then
                    GameTooltip:SetText("Protected", 1, 1, 1)
                    GameTooltip:AddLine("Click to unlock. Protected addons stay enabled when a set replaces addons.", 0.75, 0.78, 0.85, true)
                else
                    GameTooltip:SetText("Unlocked", 1, 1, 1)
                    GameTooltip:AddLine("Click to lock. Locked addons are not disabled when a set replaces addons.", 0.75, 0.78, 0.85, true)
                end
                GameTooltip:Show()
            end)
            lock:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            row:SetScript("OnClick", function()
                if row.entryKind == "header" and row.categoryKey then
                    frame.collapsedCategories[row.categoryKey] = not frame.collapsedCategories[row.categoryKey]
                    frame:RebuildList()
                    return
                end
                if row.entryKind == "addon" and row.check:IsShown() then
                    row.check:Click()
                end
            end)

            row:SetScript("OnEnter", function(self)
                if self.entryKind == "header" then
                    return
                end
                LPL.Theme:ApplyBackdrop(self, "button", "bgButtonHover", "classListBorder")
                if self.addonName then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(self.addonTitle or self.addonName, 1, 1, 1)
                    GameTooltip:AddLine(self.addonName, 0.75, 0.78, 0.85)
                    if self.missing then
                        GameTooltip:AddLine("Not installed on this client.", 1, 0.4, 0.4)
                    elseif LPL.AddonSetStore:IsProtected(self.addonName) then
                        GameTooltip:AddLine("Protected from disable on Activate.", 1, 0.82, 0)
                    end
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(self)
                if self.ClearBackdrop then
                    self:ClearBackdrop()
                end
                GameTooltip:Hide()
            end)

            frame.rows[index] = row
        end
    end

    local function GetMaxVerticalScroll()
        local viewHeight = scroll:GetHeight() or 0
        local contentHeight = content:GetHeight() or 0
        return math.max(0, contentHeight - viewHeight)
    end

    local function ClampScroll()
        local maxScroll = GetMaxVerticalScroll()
        local current = scroll:GetVerticalScroll() or 0
        if current > maxScroll then
            scroll:SetVerticalScroll(maxScroll)
        elseif current < 0 then
            scroll:SetVerticalScroll(0)
        end
    end

    local function LayoutRows()
        local width = math.max((scroll:GetWidth() or 0) - 4, 100)
        content:SetWidth(width)
        local count = #frame.filtered
        EnsureRows(math.max(count, 1))
        local selectedMap = MembershipMap()
        local scope = frame.draft and frame.draft.scope

        if count == 0 then
            emptyListLabel:Show()
            scroll:Hide()
        else
            emptyListLabel:Hide()
            scroll:Show()
        end

        for index, row in ipairs(frame.rows) do
            local entry = frame.filtered[index]
            if entry then
                row:Show()
                row:SetWidth(width)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
                row.entryKind = entry.kind

                if entry.kind == "header" then
                    row.addonName = nil
                    row.addonTitle = nil
                    row.missing = false
                    row.categoryKey = entry.categoryKey
                    row.headerBar:Show()
                    row.expandIcon:Show()
                    row.headerLabel:Show()
                    if entry.collapsed then
                        row.expandIcon:SetTexture("Interface\\Buttons\\UI-PlusButton-UP")
                    else
                        row.expandIcon:SetTexture("Interface\\Buttons\\UI-MinusButton-UP")
                    end
                    row.headerLabel:SetText(entry.category or "Other")
                    row.lock:Hide()
                    row.check:Hide()
                    row.addonIcon:Hide()
                    row.label:Hide()
                    row.liveLabel:Hide()
                else
                    local info = entry.info or {}
                    local depth = tonumber(entry.depth) or 0
                    local indent = depth * CHILD_INDENT
                    row.categoryKey = nil
                    row.headerBar:Hide()
                    row.expandIcon:Hide()
                    row.headerLabel:Hide()
                    row.lock:Show()
                    row.check:Show()
                    row.label:Show()
                    row.liveLabel:Show()

                    row.addonName = info.name
                    row.addonTitle = info.title
                    row.missing = info.missing == true

                    row.lock:ClearAllPoints()
                    row.lock:SetPoint("LEFT", row, "LEFT", 4 + indent, 0)
                    row.check:ClearAllPoints()
                    row.check:SetPoint("LEFT", row.lock, "RIGHT", 4, 0)

                    local alwaysProtected = LPL.AddonSetStore:IsAlwaysProtected(info.name)
                    local protected = LPL.AddonSetStore:IsProtected(info.name)
                    ApplyProtectLockTextures(row.lock, protected, alwaysProtected)
                    if row.missing then
                        row.lock:Hide()
                        row.check:ClearAllPoints()
                        row.check:SetPoint("LEFT", row, "LEFT", 4 + indent + LOCK_SIZE + 4, 0)
                    end

                    row.addonIcon:ClearAllPoints()
                    row.addonIcon:SetPoint("LEFT", row.check, "RIGHT", 4, 0)
                    local hasIcon = ApplyAddonIconTexture(row.addonIcon, info)
                    if hasIcon then
                        row.addonIcon:Show()
                        if info.missing then
                            row.addonIcon:SetVertexColor(1, 0.55, 0.55, 0.85)
                        end
                    else
                        row.addonIcon:Hide()
                    end

                    row.label:SetText(info.title or info.name)
                    if info.missing then
                        row.label:SetTextColor(1, 0.45, 0.45)
                        row.liveLabel:SetText("missing")
                        row.liveLabel:SetTextColor(1, 0.45, 0.45)
                    else
                        if depth > 0 then
                            row.label:SetTextColor(0.78, 0.8, 0.85)
                        else
                            row.label:SetTextColor(LPL.Theme:GetColor("textBright"))
                        end
                        local enabled = LPL.AddonSetStore:IsAddonEnabledLive(info.name, scope)
                        row.liveLabel:SetText(enabled and "on" or "off")
                        if enabled then
                            row.liveLabel:SetTextColor(0.45, 0.9, 0.5)
                        else
                            row.liveLabel:SetTextColor(LPL.Theme:GetColor("textMuted"))
                        end
                    end
                    row.check:SetChecked(selectedMap[info.name] == true)
                    row.label:ClearAllPoints()
                    if hasIcon then
                        row.label:SetPoint("LEFT", row.addonIcon, "RIGHT", 6, 0)
                    else
                        row.label:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
                    end
                    row.label:SetPoint("RIGHT", row.liveLabel, "LEFT", -8, 0)
                end
            else
                row:Hide()
                row.addonName = nil
                row.entryKind = nil
                -- Park unused rows so they don't inflate scroll bounds.
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
                row:SetWidth(1)
            end
        end

        local contentHeight = math.max(count * ROW_HEIGHT + SCROLL_BOTTOM_PAD, 1)
        content:SetHeight(contentHeight)
        if scroll.UpdateScrollChildRect then
            scroll:UpdateScrollChildRect()
        end
        ClampScroll()
    end

    function frame:RebuildList()
        RebuildFiltered()
        LayoutRows()
        RefreshStatus()
    end

    local function SetScope(scope)
        if not frame.draft then
            return
        end
        frame.draft.scope = scope
        RefreshScopeButtons()
        frame:RebuildList()
    end

    accountButton:SetScript("OnClick", function()
        SetScope(LPL.AddonSetStore.SCOPE_ACCOUNT)
    end)
    characterButton:SetScript("OnClick", function()
        SetScope(LPL.AddonSetStore.SCOPE_CHARACTER)
    end)

    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then
            return
        end
        frame.searchText = self:GetText() or ""
        frame:RebuildList()
    end)

    selectedOnly:SetScript("OnClick", function(self)
        frame.showSelectedOnly = self:GetChecked() == true
        frame:RebuildList()
    end)

    selectAllButton:SetScript("OnClick", function()
        if not frame.draft then
            return
        end
        local map = MembershipMap()
        for _, entry in ipairs(frame.filtered) do
            if entry.kind == "addon" and entry.info and entry.info.name then
                map[entry.info.name] = true
            end
        end
        local list = {}
        for name in pairs(map) do
            list[#list + 1] = name
        end
        frame.draft.addons = LPL.AddonSetStore:NormalizeAddonList(list)
        frame:RebuildList()
    end)

    clearShownButton:SetScript("OnClick", function()
        if not frame.draft then
            return
        end
        local map = MembershipMap()
        for _, entry in ipairs(frame.filtered) do
            if entry.kind == "addon" and entry.info and entry.info.name then
                map[entry.info.name] = nil
            end
        end
        local list = {}
        for name in pairs(map) do
            list[#list + 1] = name
        end
        frame.draft.addons = LPL.AddonSetStore:NormalizeAddonList(list)
        frame:RebuildList()
    end)

    UIDropDownMenu_Initialize(includeMenu, function(_, level)
        if not frame.draft then
            return
        end
        level = level or 1
        if level ~= 1 then
            return
        end

        local info = UIDropDownMenu_CreateInfo()
        info.text = "Enabled with this set"
        info.isTitle = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        local options = LPL.AddonSetStore:GetIncludableSets(frame.excludeSetID)
        if #options == 0 then
            info = UIDropDownMenu_CreateInfo()
            info.text = "No other sets to include"
            info.disabled = true
            info.notCheckable = true
            UIDropDownMenu_AddButton(info, level)
            return
        end

        local includeMap = LPL.AddonSetStore:BuildIncludeMap(frame.draft.includes)
        for _, set in ipairs(options) do
            info = UIDropDownMenu_CreateInfo()
            info.text = set.name or set.id
            info.isNotRadio = true
            info.keepShownOnClick = true
            info.checked = includeMap[set.id] == true
            info.arg1 = set.id
            info.func = function(_, setID)
                if not frame.draft or not setID then
                    return
                end
                local includeMap = LPL.AddonSetStore:BuildIncludeMap(frame.draft.includes)
                local enabled = not includeMap[tostring(setID)]
                frame.draft.includes = LPL.AddonSetStore:SetInclude(frame.draft.includes, setID, enabled)
                RefreshStatus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    includeButton:SetScript("OnClick", function()
        if not frame.draft then
            return
        end
        ToggleDropDownMenu(1, nil, includeMenu, includeButton, 0, 0)
    end)
    includeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Include Sets", 1, 1, 1)
        GameTooltip:AddLine("Like BetterAddonList: tick other sets to enable with this one on Activate/Enable.", 0.75, 0.78, 0.85, true)
        GameTooltip:Show()
    end)
    includeButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    scroll:SetScript("OnMouseWheel", function(self, delta)
        local step = ROW_HEIGHT * 3
        local nextScroll = (self:GetVerticalScroll() or 0) - (delta * step)
        local maxScroll = GetMaxVerticalScroll()
        if nextScroll < 0 then
            nextScroll = 0
        elseif nextScroll > maxScroll then
            nextScroll = maxScroll
        end
        self:SetVerticalScroll(nextScroll)
    end)

    content:EnableMouseWheel(true)
    content:SetScript("OnMouseWheel", function(_, delta)
        local handler = scroll:GetScript("OnMouseWheel")
        if handler then
            handler(scroll, delta)
        end
    end)

    scroll:HookScript("OnSizeChanged", function()
        LayoutRows()
    end)

    function frame:UpdateFromLive()
        if not self.draft then
            return
        end
        self.draft.addons = LPL.AddonSetStore:CaptureLiveEnabledAddons(self.draft.scope)
        self:RebuildList()
        print(string.format(
            "|cff33cc33LPL:|r Updated set from currently enabled %s addons (%d).",
            self.draft.scope == LPL.AddonSetStore.SCOPE_CHARACTER and "character" or "account",
            #self.draft.addons
        ))
    end

    function frame:Refresh()
        if not self.draft then
            return
        end
        self.draft.scope = LPL.AddonSetStore:NormalizeScope(self.draft.scope)
        self.draft.addons = LPL.AddonSetStore:NormalizeAddonList(self.draft.addons)
        RefreshScopeButtons()
        self:RebuildList()
    end

    function frame:SetDraft(draft, excludeSetID)
        self.draft = draft
        if self.draft then
            self.draft.includes = LPL.AddonSetStore:NormalizeIncludeList(self.draft.includes, excludeSetID)
        end
        self.excludeSetID = excludeSetID and tostring(excludeSetID) or nil
        self.searchText = ""
        self.showSelectedOnly = false
        self.searchBox:SetText("")
        self.selectedOnly:SetChecked(false)
        self:Refresh()
    end

    function frame:GetDraft()
        if self.draft then
            self.draft.addons = LPL.AddonSetStore:NormalizeAddonList(self.draft.addons)
            self.draft.scope = LPL.AddonSetStore:NormalizeScope(self.draft.scope)
            self.draft.includes = LPL.AddonSetStore:NormalizeIncludeList(self.draft.includes, self.excludeSetID)
        end
        return self.draft
    end

    return frame
end

function LPL.AddonSetEditor:Destroy(editor)
    if not editor then
        return
    end
    editor:Hide()
    editor:SetParent(nil)
end
