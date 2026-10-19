local _, ns = ...

local ProfilesTab = {}
ns.ProfilesTab = ProfilesTab

ProfilesTab.CARD_MIN_HEIGHT = 70
ProfilesTab.CARD_GAP = 6
ProfilesTab.ACTION_HEIGHT = 22

function ProfilesTab:PopupEditBox(dialog)
    if dialog.GetEditBox then
        return dialog:GetEditBox()
    end
    return dialog.editBox
end

function ProfilesTab:Addon()
    return WowGPS or (self.mainFrame and self.mainFrame.addon)
end

function ProfilesTab:Notify()
    if ns.SavedTab and ns.SavedTab.NotifyProfileChange then
        ns.SavedTab:NotifyProfileChange()
    else
        self:RefreshList()
    end
end

function ProfilesTab:EnsurePopups()
    if self._popupsReady then
        return
    end
    self._popupsReady = true

    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")

    local function pressAccept(edit)
        local dialog = edit:GetParent()
        if dialog and not dialog.button1 then
            dialog = dialog:GetParent()
        end
        if dialog and dialog.button1 then
            dialog.button1:Click()
        end
    end

    StaticPopupDialogs["WOWGPS_NEW_LOCATION_PROFILE"] = {
        text = L["PROFILE_NEW_PROMPT"],
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 40,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(dialog)
            local edit = ProfilesTab:PopupEditBox(dialog)
            if edit then
                edit:SetText("")
                edit:SetFocus()
            end
        end,
        OnAccept = function(dialog)
            local edit = ProfilesTab:PopupEditBox(dialog)
            local name = edit and edit:GetText() or ""
            local ok, result = ns.Database:CreateLocationProfile(name)
            local addon = ProfilesTab:Addon()
            if ok then
                if addon then
                    addon:Print(string.format(L["PROFILE_CREATED"], result))
                end
                ProfilesTab:Notify()
            elseif addon then
                if result == "exists" then
                    addon:Print(string.format(L["PROFILE_EXISTS"], ns.Database:NormalizeProfileName(name) or name))
                else
                    addon:Print(L["PROFILE_BAD_NAME"])
                end
            end
        end,
        EditBoxOnEnterPressed = pressAccept,
    }

    StaticPopupDialogs["WOWGPS_RENAME_LOCATION_PROFILE"] = {
        text = L["PROFILE_RENAME_PROMPT"],
        button1 = ACCEPT,
        button2 = CANCEL,
        hasEditBox = true,
        maxLetters = 40,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(dialog)
            local edit = ProfilesTab:PopupEditBox(dialog)
            local current = dialog.data or ProfilesTab._renameName or ""
            if edit then
                edit:SetText(current)
                edit:HighlightText()
                edit:SetFocus()
            end
        end,
        OnAccept = function(dialog, data)
            local oldName = data or dialog.data or ProfilesTab._renameName
            local edit = ProfilesTab:PopupEditBox(dialog)
            local newName = edit and edit:GetText() or ""
            local ok, result = ns.Database:RenameLocationProfile(oldName, newName)
            local addon = ProfilesTab:Addon()
            if ok then
                if addon and result ~= oldName then
                    addon:Print(string.format(L["PROFILE_RENAMED"], result))
                end
                ProfilesTab:Notify()
            elseif addon then
                if result == "exists" then
                    addon:Print(string.format(L["PROFILE_EXISTS"], ns.Database:NormalizeProfileName(newName) or newName))
                elseif result == "bad_name" then
                    addon:Print(L["PROFILE_BAD_NAME"])
                else
                    addon:Print(L["PROFILE_MISSING"])
                end
            end
        end,
        EditBoxOnEnterPressed = pressAccept,
    }

    StaticPopupDialogs["WOWGPS_DELETE_LOCATION_PROFILE"] = {
        text = L["PROFILE_DELETE_PROMPT"],
        button1 = YES,
        button2 = NO,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(_, data)
            local ok, nextName = ns.Database:DeleteLocationProfile(data)
            local addon = ProfilesTab:Addon()
            if ok then
                if addon then
                    addon:Print(string.format(L["PROFILE_DELETED"], nextName or ""))
                end
                ProfilesTab:Notify()
            elseif addon then
                addon:Print(L["PROFILE_LAST"])
            end
        end,
    }
end

function ProfilesTab:PromptCreate()
    self:EnsurePopups()
    StaticPopup_Show("WOWGPS_NEW_LOCATION_PROFILE")
end

function ProfilesTab:PromptRename(name)
    if not name then
        return
    end
    self._renameName = name
    self:EnsurePopups()
    StaticPopup_Show("WOWGPS_RENAME_LOCATION_PROFILE", name, nil, name)
end

function ProfilesTab:PromptDelete(name)
    self:EnsurePopups()
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local names = ns.Database:ListLocationProfiles()
    if #names <= 1 then
        local addon = self:Addon()
        if addon then
            addon:Print(L["PROFILE_LAST"])
        end
        return
    end
    StaticPopup_Show("WOWGPS_DELETE_LOCATION_PROFILE", name, nil, name)
end

function ProfilesTab:LoadProfile(name)
    local ok, result = ns.Database:SetActiveLocationProfile(name)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local addon = self:Addon()
    if ok then
        if addon then
            addon:Print(string.format(L["PROFILE_SWITCHED"], result))
        end
        self:Notify()
    elseif addon then
        addon:Print(L["PROFILE_MISSING"])
    end
end

function ProfilesTab:ExportProfile(name)
    local text, exportedName, count = ns.CustomLocations:ExportProfile(name)
    if not text then
        local addon = self:Addon()
        if addon then
            addon:Print(LibStub("AceLocale-3.0"):GetLocale("WowGPS")["PROFILE_MISSING"])
        end
        return
    end
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    ns.ExportDialog:ShowBlock(text, L["PROFILE_EXPORT_PROMPT"])
    if (tonumber(count) or 0) == 0 then
        local addon = self:Addon()
        if addon then
            addon:Print(string.format(L["PROFILE_EXPORT_EMPTY"], exportedName or name or ""))
        end
    end
end

function ProfilesTab:GetListWidth()
    if self.scroll then
        return math.max(200, (self.scroll:GetWidth() or 280) - 4)
    end
    return 280
end

function ProfilesTab:CreateCard(index)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme
    local card = CreateFrame("Frame", nil, self.listContent, "BackdropTemplate")
    card:SetSize(280, self.CARD_MIN_HEIGHT)
    theme:StyleCard(card)

    card.title = card:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    card.title:SetPoint("TOPLEFT", 10, -8)
    card.title:SetPoint("TOPRIGHT", -10, -8)
    card.title:SetJustifyH("LEFT")
    card.title:SetWordWrap(false)

    card.detail = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.detail:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -2)
    card.detail:SetPoint("RIGHT", card.title, "RIGHT", 0, 0)
    card.detail:SetJustifyH("LEFT")
    card.detail:SetWordWrap(false)

    card.actionBar = CreateFrame("Frame", nil, card)
    card.actionBar:SetPoint("BOTTOMLEFT", 6, 6)
    card.actionBar:SetPoint("BOTTOMRIGHT", -6, 6)
    card.actionBar:SetHeight(self.ACTION_HEIGHT)

    local function makeAction(label, variant, width)
        local btn = CreateFrame("Button", nil, card.actionBar, "BackdropTemplate")
        btn:SetSize(width, self.ACTION_HEIGHT)
        btn:SetText(label)
        btn:RegisterForClicks("LeftButtonUp")
        btn:EnableMouse(true)
        btn:SetFrameLevel(card:GetFrameLevel() + 4)
        theme:StyleSmallButton(btn, variant)
        return btn
    end

    card.load = makeAction(L["PROFILE_LOAD"], "success", 64)
    card.rename = makeAction(L["PROFILE_RENAME"], nil, 62)
    card.export = makeAction(L["EXPORT"], nil, 58)
    card.delete = makeAction(L["PROFILE_DELETE"], "danger", 58)

    local function layout()
        local btns = { card.load, card.rename, card.export, card.delete }
        local wants = { 64, 62, 58, 58 }
        local gap = 4
        local barW = math.max(80, (card:GetWidth() or 280) - 12)
        local total = 0
        for i = 1, #wants do
            total = total + wants[i] + (i > 1 and gap or 0)
        end
        local scale = 1
        if total > barW then
            scale = (barW - gap * (#btns - 1)) / (total - gap * (#btns - 1))
        end
        local x = 0
        for i, btn in ipairs(btns) do
            local w = math.max(44, math.floor(wants[i] * scale))
            btn:SetWidth(w)
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOMLEFT", card.actionBar, "BOTTOMLEFT", x, 0)
            x = x + w + gap
        end
    end
    card.LayoutActions = layout

    card.load:SetScript("OnClick", function(self)
        if self.profileName and self.profileName ~= ns.Database:GetActiveLocationProfile() then
            ProfilesTab:LoadProfile(self.profileName)
        end
    end)
    card.rename:SetScript("OnClick", function(self)
        ProfilesTab:PromptRename(self.profileName)
    end)
    card.export:SetScript("OnClick", function(self)
        ProfilesTab:ExportProfile(self.profileName)
    end)
    card.delete:SetScript("OnClick", function(self)
        ProfilesTab:PromptDelete(self.profileName)
    end)

    self.listRows[index] = card
    return card
end

function ProfilesTab:StyleCard(card, name, loaded, count)
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme
    card.profileName = name
    card.title:SetText(name or "")
    theme:SetTextColor(card.title, theme.colors.text)
    if loaded then
        card.detail:SetText(string.format("%s · %s", L["PROFILE_LOADED"], string.format(L["PROFILE_COUNT"], count)))
        theme:SetTextColor(card.detail, theme.colors.accent)
        card.load:SetText(L["PROFILE_LOADED"])
    else
        card.detail:SetText(string.format(L["PROFILE_COUNT"], count))
        theme:SetTextColor(card.detail, theme.colors.textMuted)
        card.load:SetText(L["PROFILE_LOAD"])
    end
    card.load.profileName = name
    card.rename.profileName = name
    card.export.profileName = name
    card.delete.profileName = name
    if card.LayoutActions then
        card:LayoutActions()
    end
end

function ProfilesTab:Build(parent, mainFrame)
    self.parent = parent
    self.mainFrame = mainFrame
    local L = LibStub("AceLocale-3.0"):GetLocale("WowGPS")
    local theme = ns.Theme

    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 12, -10)
    header:SetText(L["PROFILES_HEADER"])
    theme:SetReadableFont(header, 14)
    theme:SetTextColor(header, theme.colors.text)
    self.header = header

    self.hint = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
    self.hint:SetPoint("TOPRIGHT", -12, 0)
    self.hint:SetJustifyH("LEFT")
    self.hint:SetWordWrap(true)
    self.hint:SetHeight(28)
    self.hint:SetText(L["PROFILES_HINT"])
    theme:SetTextColor(self.hint, theme.colors.textMuted)

    local actionRow = CreateFrame("Frame", nil, parent)
    actionRow:SetPoint("BOTTOMLEFT", 12, 10)
    actionRow:SetPoint("BOTTOMRIGHT", -12, 10)
    actionRow:SetHeight(26)

    local function makeBarButton(label, width)
        local btn = CreateFrame("Button", nil, actionRow, "BackdropTemplate")
        btn:SetSize(width, 26)
        btn:SetText(label)
        btn:RegisterForClicks("LeftButtonUp")
        btn:EnableMouse(true)
        theme:StyleButton(btn)
        return btn
    end

    local createBtn = makeBarButton(L["PROFILE_NEW"], 88)
    local importBtn = makeBarButton(L["IMPORT"], 88)
    createBtn:SetPoint("LEFT", actionRow, "LEFT", 0, 0)
    importBtn:SetPoint("LEFT", createBtn, "RIGHT", 8, 0)
    createBtn:SetScript("OnClick", function()
        ProfilesTab:PromptCreate()
    end)
    importBtn:SetScript("OnClick", function()
        ns.ImportDialog:Show()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", self.hint, "BOTTOMLEFT", -4, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 44)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    self.scroll = scroll
    self.listContent = content
    self.listRows = {}

    ns.ExportDialog:Init()
    ns.ImportDialog:Init()
    self:EnsurePopups()
    self:RefreshList()
end

function ProfilesTab:RefreshList()
    if not self.listContent then
        return
    end

    for _, row in ipairs(self.listRows) do
        row:Hide()
    end

    local names = ns.Database:ListLocationProfiles()
    local active = ns.Database:GetActiveLocationProfile()
    local listWidth = self:GetListWidth()
    local y = -2

    for index, name in ipairs(names) do
        local card = self.listRows[index] or self:CreateCard(index)
        local count = ns.Database:CountLocationProfilePlaces(name)
        card:SetWidth(listWidth)
        self:StyleCard(card, name, name == active, count)
        card:SetPoint("TOPLEFT", 0, y)
        card:Show()
        y = y - card:GetHeight() - self.CARD_GAP
    end

    self.listContent:SetSize(listWidth, math.max(1, -y))
end

function ProfilesTab:OnParentResize()
    if self.listContent then
        self:RefreshList()
    end
end

function ProfilesTab:Show()
    self.parent:Show()
    self:RefreshList()
end

function ProfilesTab:Hide()
    self.parent:Hide()
end
