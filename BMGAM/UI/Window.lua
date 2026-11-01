local _, BMGAM = ...

BMGAM.Window = BMGAM.Window or {}
local Window = BMGAM.Window
local Theme = BMGAM.Theme

Window.queries = Window.queries or {}

local MEDIA = "Interface\\AddOns\\BMGAM\\Media\\"
local TABS = {
    { id = "overview", name = "Overview", icon = MEDIA .. "TabOverview.tga" },
    { id = "gear", name = "Gear", icon = MEDIA .. "TabGear.tga" },
    { id = "bags", name = "Bags", icon = MEDIA .. "TabBags.tga" },
    { id = "bank", name = "Bank", icon = MEDIA .. "TabBank.tga" },
    { id = "professions", name = "Professions", icon = MEDIA .. "TabProfessions.tga" },
    { id = "currency", name = "Currency", icon = MEDIA .. "TabCurrency.tga" },
    { id = "reputation", name = "Reputation", icon = MEDIA .. "TabReputation.tga" },
    { id = "mail", name = "Mail", icon = MEDIA .. "TabMail.tga" },
    { id = "auction", name = "Auction", icon = MEDIA .. "TabAuction.tga" },
    { id = "quests", name = "Quests", icon = MEDIA .. "TabQuests.tga" },
    { id = "achievements", name = "Achievements", icon = MEDIA .. "TabAchievements.tga" },
    { id = "collections", name = "Collections", icon = MEDIA .. "TabCollections.tga" },
    { id = "vault", name = "Vault", icon = MEDIA .. "TabVault.tga" },
}

local frame
local dialog

local function MoneyText(copper)
    copper = tonumber(copper) or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100
    return gold, silver, rest
end

local function Coin(parent, texture)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetTexture(texture)
    return icon
end

local function MakeCard(parent)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetHeight(92)
    Theme.Paint(card, Theme.BG, Theme.GOLD_DIM)
    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(22, 22)
    card.icon:SetPoint("TOPLEFT", 8, -8)
    card.name = card:CreateFontString(nil, "OVERLAY")
    card.name:SetPoint("LEFT", card.icon, "RIGHT", 6, 0)
    card.name:SetJustifyH("LEFT")
    Theme.Font(card.name, 14, Theme.GOLD, "OUTLINE")

    card.levelLabel = card:CreateFontString(nil, "OVERLAY")
    card.levelLabel:SetPoint("TOPLEFT", 8, -36)
    Theme.Font(card.levelLabel, 12, Theme.YELLOW, "OUTLINE")
    card.levelLabel:SetText("Level:")
    card.level = card:CreateFontString(nil, "OVERLAY")
    card.level:SetPoint("LEFT", card.levelLabel, "RIGHT", 4, 0)
    Theme.Font(card.level, 11, Theme.CREAM, "")

    card.raceLabel = card:CreateFontString(nil, "OVERLAY")
    card.raceLabel:SetPoint("LEFT", card.level, "RIGHT", 10, 0)
    Theme.Font(card.raceLabel, 12, Theme.YELLOW, "OUTLINE")
    card.raceLabel:SetText("Race:")
    card.race = card:CreateFontString(nil, "OVERLAY")
    card.race:SetPoint("LEFT", card.raceLabel, "RIGHT", 4, 0)
    card.race:SetJustifyH("LEFT")
    card.race:SetWordWrap(false)
    Theme.Font(card.race, 11, Theme.CREAM, "")

    card.ilvl = card:CreateFontString(nil, "OVERLAY")
    card.ilvl:SetPoint("TOPRIGHT", -8, -36)
    Theme.Font(card.ilvl, 11, Theme.CREAM, "")
    card.ilvlLabel = card:CreateFontString(nil, "OVERLAY")
    card.ilvlLabel:SetPoint("RIGHT", card.ilvl, "LEFT", -4, 0)
    Theme.Font(card.ilvlLabel, 12, Theme.YELLOW, "OUTLINE")
    card.ilvlLabel:SetText("Item Level:")
    card.race:SetPoint("RIGHT", card.ilvlLabel, "LEFT", -8, 0)

    card.serverLabel = card:CreateFontString(nil, "OVERLAY")
    card.serverLabel:SetPoint("TOPLEFT", 8, -54)
    Theme.Font(card.serverLabel, 12, Theme.YELLOW, "OUTLINE")
    card.serverLabel:SetText("Server:")
    card.server = card:CreateFontString(nil, "OVERLAY")
    card.server:SetPoint("LEFT", card.serverLabel, "RIGHT", 4, 0)
    Theme.Font(card.server, 11, Theme.CREAM, "")

    card.faction = card:CreateFontString(nil, "OVERLAY")
    card.faction:SetPoint("TOPRIGHT", -8, -54)
    Theme.Font(card.faction, 11, Theme.CREAM, "")
    card.factionLabel = card:CreateFontString(nil, "OVERLAY")
    card.factionLabel:SetPoint("RIGHT", card.faction, "LEFT", -4, 0)
    Theme.Font(card.factionLabel, 12, Theme.YELLOW, "OUTLINE")
    card.factionLabel:SetText("Faction:")

    card.moneyLabel = card:CreateFontString(nil, "OVERLAY")
    card.moneyLabel:SetPoint("TOPLEFT", 8, -72)
    Theme.Font(card.moneyLabel, 12, Theme.YELLOW, "OUTLINE")
    card.moneyLabel:SetText("Money:")
    card.goldIcon = Coin(card, "Interface\\MoneyFrame\\UI-GoldIcon")
    card.goldIcon:SetPoint("LEFT", card.moneyLabel, "RIGHT", 6, 0)
    card.gold = card:CreateFontString(nil, "OVERLAY")
    card.gold:SetPoint("LEFT", card.goldIcon, "RIGHT", 2, 0)
    Theme.Font(card.gold, 11, Theme.CREAM, "")
    card.silverIcon = Coin(card, "Interface\\MoneyFrame\\UI-SilverIcon")
    card.silverIcon:SetPoint("LEFT", card.gold, "RIGHT", 6, 0)
    card.silver = card:CreateFontString(nil, "OVERLAY")
    card.silver:SetPoint("LEFT", card.silverIcon, "RIGHT", 2, 0)
    Theme.Font(card.silver, 11, Theme.CREAM, "")
    card.copperIcon = Coin(card, "Interface\\MoneyFrame\\UI-CopperIcon")
    card.copperIcon:SetPoint("LEFT", card.silver, "RIGHT", 6, 0)
    card.copper = card:CreateFontString(nil, "OVERLAY")
    card.copper:SetPoint("LEFT", card.copperIcon, "RIGHT", 2, 0)
    Theme.Font(card.copper, 11, Theme.CREAM, "")
    return card
end

local function PaintCard(card, record, selected)
    Theme.ClassIcon(card.icon, record.classFile)
    card.name:SetText(record.name or "")
    card.level:SetText(tostring(record.level or ""))
    card.race:SetText(record.raceName or "")
    card.ilvl:SetText(tostring(record.itemLevel or 0))
    local quality = Theme.QualityColor(record.itemLevelQuality)
    card.ilvl:SetTextColor(quality[1], quality[2], quality[3])
    card.server:SetText(record.realm or "")
    card.faction:SetText(record.side or "")
    local side = Theme.SideColor(record.side)
    card.faction:SetTextColor(side[1], side[2], side[3])
    local gold, silver, copper = MoneyText(record.moneyCopper)
    card.gold:SetText(tostring(gold))
    card.silver:SetText(tostring(silver))
    card.copper:SetText(tostring(copper))
    if selected then
        Theme.Paint(card, Theme.BG, Theme.GOLD_BRIGHT)
    else
        Theme.Paint(card, Theme.BG, Theme.GOLD_DIM)
    end
end

local function HideDialog()
    if dialog then
        dialog:Hide()
    end
end

local SORT_CHOICES = {
    { id = "class", label = "Class" },
    { id = "faction", label = "Faction" },
    { id = "itemLevel", label = "Item Level" },
    { id = "gold", label = "Gold" },
    { id = "level", label = "Level" },
    { id = "race", label = "Race" },
    { id = "realm", label = "Realm" },
}

local ORDER_CHOICES = {
    { id = "ascending", label = "Ascending" },
    { id = "descending", label = "Descending" },
}

local openMenu

local function CloseSortMenu()
    if openMenu then
        openMenu:Hide()
        openMenu = nil
    end
    if frame and frame.sortCatcher then
        frame.sortCatcher:Hide()
    end
end

local function ChoiceLabel(choices, id)
    local index = 1
    while choices[index] do
        if choices[index].id == id then
            return choices[index].label
        end
        index = index + 1
    end
    return choices[1].label
end

local function PaintSortMenu(menu, currentId)
    local index = 1
    while menu.rows[index] do
        local row = menu.rows[index]
        if row.choiceId == currentId then
            row.label:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
        else
            row.label:SetTextColor(Theme.CREAM[1], Theme.CREAM[2], Theme.CREAM[3])
        end
        index = index + 1
    end
end

local function MakeSortDropdown(parent, choices, width, readId, writeId)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 22)
    Theme.Paint(button, Theme.PANEL, Theme.GOLD_DIM)
    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetPoint("LEFT", 6, 0)
    button.text:SetPoint("RIGHT", -16, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetWordWrap(false)
    Theme.Font(button.text, 11, Theme.CREAM, "")
    button.arrow = button:CreateTexture(nil, "OVERLAY")
    button.arrow:SetSize(12, 12)
    button.arrow:SetPoint("RIGHT", -2, 0)
    button.arrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    button.arrow:SetRotation(0)
    button.arrow:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])

    local menu = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(40)
    menu:SetWidth(width)
    Theme.Paint(menu, Theme.PANEL, Theme.GOLD)
    menu:Hide()
    menu.rows = {}
    local index = 1
    local menuY = 4
    while choices[index] do
        local choice = choices[index]
        local row = CreateFrame("Button", nil, menu)
        row:SetHeight(20)
        row:SetPoint("TOPLEFT", 4, -menuY)
        row:SetPoint("TOPRIGHT", -4, -menuY)
        row.label = row:CreateFontString(nil, "OVERLAY")
        row.label:SetPoint("LEFT", 4, 0)
        row.label:SetPoint("RIGHT", -4, 0)
        row.label:SetJustifyH("LEFT")
        Theme.Font(row.label, 11, Theme.CREAM, "")
        row.label:SetText(choice.label)
        row.choiceId = choice.id
        row:SetScript("OnEnter", function(self)
            self.label:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
        end)
        row:SetScript("OnLeave", function(self)
            if readId() == self.choiceId then
                self.label:SetTextColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
            else
                self.label:SetTextColor(Theme.CREAM[1], Theme.CREAM[2], Theme.CREAM[3])
            end
        end)
        row:SetScript("OnClick", function(self)
            writeId(self.choiceId)
            CloseSortMenu()
            Window.Refresh()
        end)
        menu.rows[index] = row
        menuY = menuY + 20
        index = index + 1
    end
    menu:SetHeight(menuY + 4)
    button.menu = menu
    button.choices = choices
    button.readId = readId
    function button:RefreshLabel()
        self.text:SetText(ChoiceLabel(self.choices, self.readId()))
    end
    button:SetScript("OnClick", function(self)
        if openMenu == self.menu and self.menu:IsShown() then
            CloseSortMenu()
            return
        end
        CloseSortMenu()
        PaintSortMenu(self.menu, self.readId())
        self.menu:ClearAllPoints()
        self.menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        self.menu:Show()
        frame.sortCatcher:Show()
        openMenu = self.menu
    end)
    button:RefreshLabel()
    return button
end

local function ShowDialog(record)
    if not dialog or not record then
        return
    end
    dialog.record = record
    CloseSortMenu()
    local name = record.name or "this character"
    dialog.title:SetText("Forget " .. name .. "?")
    dialog.body:SetText("Remove " .. name .. " from this roster?")
    dialog:Show()
end

local function ForgetRecord(record)
    if not record or not record.guid then
        return
    end
    local guid = record.guid
    BMGAM.DB.Delete(guid)
    if Window.selected == guid then
        local player = UnitGUID("player")
        if player and player ~= guid and BMGAM.DB.Get(player) then
            Window.selected = player
        else
            local list = BMGAM.DB.List()
            Window.selected = list[1] and list[1].guid or nil
        end
    end
    Window.tab = "overview"
    HideDialog()
    Window.Refresh()
end

function Window.Ensure()
    if frame then
        if frame.page and not frame.gear and BMGAM.Gear and BMGAM.Gear.Create then
            local created, gear = pcall(BMGAM.Gear.Create, frame.page)
            if created and gear then
                frame.gear = gear
                frame.gear:Hide()
            end
        end
        if frame.page and not frame.bags and BMGAM.Bags and BMGAM.Bags.Create then
            local created, bags = pcall(BMGAM.Bags.Create, frame.page)
            if created and bags then
                frame.bags = bags
                frame.bags:Hide()
            end
        end
        if frame.page and not frame.bank and BMGAM.Bank and BMGAM.Bank.Create then
            local created, bank = pcall(BMGAM.Bank.Create, frame.page)
            if created and bank then
                frame.bank = bank
                frame.bank:Hide()
            end
        end
        if frame.page and not frame.professions and BMGAM.Professions and BMGAM.Professions.Create then
            local created, professions = pcall(BMGAM.Professions.Create, frame.page)
            if created and professions then
                frame.professions = professions
                frame.professions:Hide()
            end
        end
        if frame.page and not frame.currency and BMGAM.Currency and BMGAM.Currency.Create then
            local created, currency = pcall(BMGAM.Currency.Create, frame.page)
            if created and currency then
                frame.currency = currency
                frame.currency:Hide()
            end
        end
        if frame.page and not frame.reputation and BMGAM.Reputation and BMGAM.Reputation.Create then
            local created, reputation = pcall(BMGAM.Reputation.Create, frame.page)
            if created and reputation then
                frame.reputation = reputation
                frame.reputation:Hide()
            end
        end
        if frame.page and not frame.mail and BMGAM.Mail and BMGAM.Mail.Create then
            local created, mail = pcall(BMGAM.Mail.Create, frame.page)
            if created and mail then
                frame.mail = mail
                frame.mail:Hide()
            end
        end
        if frame.page and not frame.auction and BMGAM.Auction and BMGAM.Auction.Create then
            local created, auction = pcall(BMGAM.Auction.Create, frame.page)
            if created and auction then
                frame.auction = auction
                frame.auction:Hide()
            end
        end
        if frame.page and not frame.blank then
            frame.blank = CreateFrame("Frame", nil, frame.page)
            frame.blank:SetAllPoints(frame.page)
            frame.blank:Hide()
        end
        return frame
    end

    frame = CreateFrame("Frame", "BMGAMFrame", UIParent, "BackdropTemplate")
    frame:SetSize(Theme.WIDTH, Theme.HEIGHT)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableKeyboard(true)
    frame:SetResizable(false)
    Theme.Paint(frame, Theme.PANEL, Theme.GOLD)
    BMGAM.DB.RestorePoint(frame)
    frame:Hide()

    frame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" and dialog and dialog:IsShown() then
            HideDialog()
            self:SetPropagateKeyboardInput(false)
            return
        end
        if key == "ESCAPE" and openMenu and openMenu:IsShown() then
            CloseSortMenu()
            self:SetPropagateKeyboardInput(false)
            return
        end
        self:SetPropagateKeyboardInput(true)
    end)

    frame:SetScript("OnHide", CloseSortMenu)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", 14, -10)
    Theme.Font(title, 16, Theme.GOLD, "OUTLINE")
    title:SetText("BMG Alt Manager")

    local drag = CreateFrame("Button", nil, frame)
    drag:SetPoint("TOPLEFT", 0, 0)
    drag:SetPoint("TOPRIGHT", -80, 0)
    drag:SetHeight(32)
    drag:RegisterForDrag("LeftButton")
    drag:EnableMouseWheel(true)
    drag:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        BMGAM.DB.SavePoint(frame)
    end)
    drag:SetScript("OnMouseWheel", function(_, delta)
        local scale = BMGAM.DB.ClampScale((frame:GetScale() or 1) + (delta * 0.05))
        frame:SetScale(scale)
        BMGAM.DB.Account().scale = scale
        BMGAM.DB.SavePoint(frame)
    end)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", -8, -4)
    close:SetNormalTexture(MEDIA .. "Close.tga")
    close:SetScript("OnClick", function()
        HideDialog()
        frame:Hide()
        BMGAM.DB.SavePoint(frame)
    end)

    local settings = CreateFrame("Button", nil, frame)
    settings:SetSize(32, 32)
    settings:SetPoint("RIGHT", close, "LEFT", -4, 0)
    settings:SetNormalTexture(MEDIA .. "Settings.tga")
    settings:SetScript("OnClick", function()
        if frame.settings then
            Window.tab = "settings"
            Window.Refresh()
        end
    end)
    settings:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Settings", 1, 0.82, 0.29)
        GameTooltip:Show()
    end)
    settings:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local sortBar = CreateFrame("Frame", nil, frame)
    sortBar:SetPoint("TOPLEFT", 10, -40)
    sortBar:SetSize(400, 26)
    sortBar:SetFrameStrata("DIALOG")
    sortBar:SetFrameLevel(30)
    local sortLabel = sortBar:CreateFontString(nil, "OVERLAY")
    sortLabel:SetPoint("LEFT", 0, 0)
    Theme.Font(sortLabel, 11, Theme.YELLOW, "OUTLINE")
    sortLabel:SetText("Sort By:")
    local sortButton = MakeSortDropdown(sortBar, SORT_CHOICES, 118, function()
        return BMGAM.DB.Account().sortBy
    end, function(id)
        BMGAM.DB.Account().sortBy = id
    end)
    sortButton:SetPoint("LEFT", sortLabel, "RIGHT", 4, 0)
    local orderLabel = sortBar:CreateFontString(nil, "OVERLAY")
    orderLabel:SetPoint("LEFT", sortButton, "RIGHT", 10, 0)
    Theme.Font(orderLabel, 11, Theme.YELLOW, "OUTLINE")
    orderLabel:SetText("Order:")
    local orderButton = MakeSortDropdown(sortBar, ORDER_CHOICES, 108, function()
        return BMGAM.DB.Account().sortOrder
    end, function(id)
        BMGAM.DB.Account().sortOrder = id
    end)
    orderButton:SetPoint("LEFT", orderLabel, "RIGHT", 4, 0)
    frame.sortByButton = sortButton
    frame.orderButton = orderButton
    local sortCatcher = CreateFrame("Button", nil, frame)
    sortCatcher:SetAllPoints(frame)
    sortCatcher:SetFrameStrata("DIALOG")
    sortCatcher:SetFrameLevel(20)
    sortCatcher:Hide()
    sortCatcher:SetScript("OnClick", CloseSortMenu)
    frame.sortCatcher = sortCatcher

    local roster = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    roster:SetPoint("TOPLEFT", 10, -70)
    roster:SetPoint("BOTTOMLEFT", 10, 10)
    roster:SetWidth(400)
    Theme.Paint(roster, Theme.BG, Theme.GOLD_DIM)
    local rosterScroll = CreateFrame("ScrollFrame", nil, roster)
    rosterScroll:SetPoint("TOPLEFT", 6, -6)
    rosterScroll:SetPoint("BOTTOMRIGHT", -16, 6)
    local rosterChild = CreateFrame("Frame", nil, rosterScroll)
    rosterChild:SetSize(290, 40)
    rosterScroll:SetScrollChild(rosterChild)
    Theme.AttachScroll(rosterScroll)
    frame.rosterScroll = rosterScroll
    frame.rosterChild = rosterChild
    frame.cards = {}

    local right = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    right:SetPoint("TOPLEFT", roster, "TOPRIGHT", 8, 0)
    right:SetPoint("BOTTOMRIGHT", -10, 10)
    Theme.Paint(right, Theme.BG, Theme.GOLD_DIM)

    local portrait = right:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(52, 52)
    portrait:SetPoint("TOPLEFT", 10, -8)
    frame.portrait = portrait

    local name = right:CreateFontString(nil, "OVERLAY")
    name:SetPoint("LEFT", portrait, "RIGHT", 8, 10)
    name:SetJustifyH("LEFT")
    Theme.Font(name, 18, Theme.GOLD, "OUTLINE")
    frame.characterName = name

    local logged = right:CreateFontString(nil, "OVERLAY")
    logged:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
    Theme.Font(logged, 12, Theme.CREAM, "")
    logged:SetText("Logged in now")
    frame.logged = logged

    local trash = CreateFrame("Button", nil, right)
    trash:SetSize(28, 28)
    trash:SetPoint("TOPRIGHT", -10, -12)
    trash:SetNormalTexture(MEDIA .. "Trash.tga")
    trash:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Forget this character", 1, 0.82, 0.29)
        GameTooltip:Show()
    end)
    trash:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    trash:SetScript("OnClick", function()
        local record = Window.selected and BMGAM.DB.Get(Window.selected)
        ShowDialog(record)
    end)
    frame.trash = trash

    frame.tabs = {}
    local tabIndex = 1
    while TABS[tabIndex] do
        local info = TABS[tabIndex]
        local tab = CreateFrame("Button", nil, right, "BackdropTemplate")
        tab:SetSize(46, 52)
        tab:SetPoint("TOPLEFT", right, "TOPLEFT", 8 + ((tabIndex - 1) * 50), -68)
        Theme.Paint(tab, Theme.PANEL, Theme.GOLD_DIM)
        local icon = tab:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", 4, -4)
        icon:SetPoint("BOTTOMRIGHT", -4, 4)
        icon:SetTexture(info.icon)
        tab.icon = icon
        tab.info = info
        tab:SetScript("OnClick", function(self)
            Window.tab = self.info.id
            Window.Refresh()
        end)
        tab:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.info.name, 1, 0.82, 0.29)
            GameTooltip:Show()
        end)
        tab:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        frame.tabs[tabIndex] = tab
        tabIndex = tabIndex + 1
    end

    local search = CreateFrame("EditBox", nil, right, "BackdropTemplate")
    search:SetHeight(24)
    search:SetPoint("TOPLEFT", 8, -126)
    search:SetPoint("TOPRIGHT", -8, -126)
    search:SetAutoFocus(false)
    search:SetFont(GameFontNormal:GetFont(), 12, "")
    search:SetTextInsets(22, 6, 0, 0)
    search:SetTextColor(Theme.CREAM[1], Theme.CREAM[2], Theme.CREAM[3])
    Theme.Paint(search, Theme.PANEL, Theme.GOLD_DIM)
    local glass = search:CreateTexture(nil, "OVERLAY")
    glass:SetSize(12, 12)
    glass:SetPoint("LEFT", 6, 0)
    glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    local placeholder = search:CreateFontString(nil, "OVERLAY")
    placeholder:SetPoint("LEFT", 22, 0)
    Theme.Font(placeholder, 12, Theme.DIM, "")
    placeholder:SetText("Search")
    search.placeholder = placeholder
    search:SetScript("OnTextChanged", function(self)
        if self:GetText() == "" then
            self.placeholder:Show()
        else
            self.placeholder:Hide()
        end
        if self.quiet then
            return
        end
        Window.queries[Window.tab or "overview"] = self:GetText()
        Window.Refresh()
    end)
    search:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    search:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    frame.search = search

    local page = CreateFrame("Frame", nil, right)
    page:SetPoint("TOPLEFT", 8, -156)
    page:SetPoint("BOTTOMRIGHT", -8, 8)
    frame.page = page
    frame.overview = BMGAM.Overview.Create(page)
    frame.gear = BMGAM.Gear.Create(page)
    frame.gear:Hide()
    frame.bags = BMGAM.Bags.Create(page)
    frame.bags:Hide()
    frame.bank = BMGAM.Bank.Create(page)
    frame.bank:Hide()
    if BMGAM.Professions and BMGAM.Professions.Create then
        local created, professions = pcall(BMGAM.Professions.Create, page)
        if created and professions then
            frame.professions = professions
            frame.professions:Hide()
        end
    end
    if BMGAM.Currency and BMGAM.Currency.Create then
        local created, currency = pcall(BMGAM.Currency.Create, page)
        if created and currency then
            frame.currency = currency
            frame.currency:Hide()
        end
    end
    if BMGAM.Reputation and BMGAM.Reputation.Create then
        local created, reputation = pcall(BMGAM.Reputation.Create, page)
        if created and reputation then
            frame.reputation = reputation
            frame.reputation:Hide()
        end
    end
    if BMGAM.Mail and BMGAM.Mail.Create then
        local created, mail = pcall(BMGAM.Mail.Create, page)
        if created and mail then
            frame.mail = mail
            frame.mail:Hide()
        end
    end
    if BMGAM.Auction and BMGAM.Auction.Create then
        local created, auction = pcall(BMGAM.Auction.Create, page)
        if created and auction then
            frame.auction = auction
            frame.auction:Hide()
        end
    end
    frame.blank = CreateFrame("Frame", nil, page)
    frame.blank:SetAllPoints(page)
    frame.blank:Hide()

    dialog = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    dialog:SetSize(420, 150)
    dialog:SetPoint("CENTER", frame, "CENTER", 0, 0)
    if BMGAM.Quests and BMGAM.Quests.Create then
        local created, quests = pcall(BMGAM.Quests.Create, page)
        if created and quests then
            frame.quests = quests
            frame.quests:Hide()
        end
    end
    if BMGAM.Achievements and BMGAM.Achievements.Create then
        local created, achievements = pcall(BMGAM.Achievements.Create, page)
        if created and achievements then
            frame.achievements = achievements
            frame.achievements:Hide()
        end
    end
    if BMGAM.Collections and BMGAM.Collections.Create then
        local created, collections = pcall(BMGAM.Collections.Create, page)
        if created and collections then
            frame.collections = collections
            frame.collections:Hide()
        end
    end
    if BMGAM.Vault and BMGAM.Vault.Create then
        local created, vault = pcall(BMGAM.Vault.Create, page)
        if created and vault then
            frame.vault = vault
            frame.vault:Hide()
        end
    end
    if BMGAM.Settings and BMGAM.Settings.Create then
        local created, settingsPage = pcall(BMGAM.Settings.Create, page)
        if created and settingsPage then
            frame.settings = settingsPage
            frame.settings:Hide()
        end
    end
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(80)
    Theme.Paint(dialog, Theme.PANEL, Theme.GOLD)
    dialog.title = dialog:CreateFontString(nil, "OVERLAY")
    dialog.title:SetPoint("TOP", 0, -16)
    Theme.Font(dialog.title, 16, Theme.GOLD, "OUTLINE")
    dialog.body = dialog:CreateFontString(nil, "OVERLAY")
    dialog.body:SetPoint("TOP", dialog.title, "BOTTOM", 0, -10)
    Theme.Font(dialog.body, 13, Theme.CREAM, "")
    dialog.note = dialog:CreateFontString(nil, "OVERLAY")
    dialog.note:SetPoint("TOP", dialog.body, "BOTTOM", 0, -6)
    Theme.Font(dialog.note, 12, Theme.CREAM, "")
    dialog.note:SetText("The character in the game is not deleted.")
    local forget = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    forget:SetSize(110, 26)
    forget:SetPoint("BOTTOMLEFT", 70, 16)
    Theme.Paint(forget, Theme.BG, Theme.GOLD)
    forget.label = forget:CreateFontString(nil, "OVERLAY")
    forget.label:SetPoint("CENTER")
    Theme.Font(forget.label, 13, Theme.GOLD, "OUTLINE")
    forget.label:SetText("Forget")
    forget:SetScript("OnClick", function()
        ForgetRecord(dialog.record)
    end)
    local cancel = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    cancel:SetSize(110, 26)
    cancel:SetPoint("BOTTOMRIGHT", -70, 16)
    Theme.Paint(cancel, Theme.BG, Theme.GOLD_DIM)
    cancel.label = cancel:CreateFontString(nil, "OVERLAY")
    cancel.label:SetPoint("CENTER")
    Theme.Font(cancel.label, 13, Theme.CREAM, "")
    cancel.label:SetText("Cancel")
    cancel:SetScript("OnClick", HideDialog)
    dialog:Hide()

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function(self)
        self.dragging = true
        self:SetScript("OnUpdate", function()
            local scale = frame:GetEffectiveScale()
            local x = GetCursorPosition() / scale
            local left = frame:GetLeft() or 0
            local width = x - left
            if width < 200 then
                width = 200
            end
            local nextScale = BMGAM.DB.ClampScale((frame:GetScale() or 1) * (width / frame:GetWidth()))
            frame:SetScale(nextScale)
        end)
    end)
    grip:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
        BMGAM.DB.Account().scale = frame:GetScale()
        BMGAM.DB.SavePoint(frame)
    end)

    Window.tab = "overview"
    return frame
end

local function SelectCard(guid)
    return function()
        Window.selected = guid
        Window.tab = "overview"
        HideDialog()
        Window.Refresh()
    end
end

function Window.Refresh()
    if not frame or not frame:IsShown() then
        return
    end
    local window = frame
    local list = BMGAM.DB.List()
    if window.sortByButton then
        window.sortByButton:RefreshLabel()
    end
    if window.orderButton then
        window.orderButton:RefreshLabel()
    end
    local index = 1
    local y = 0
    while list[index] do
        local record = list[index]
        local card = window.cards[index]
        if not card then
            card = MakeCard(window.rosterChild)
            window.cards[index] = card
        end
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", window.rosterChild, "TOPLEFT", 0, -y)
        card:SetPoint("TOPRIGHT", window.rosterChild, "TOPRIGHT", 0, -y)
        card:Show()
        PaintCard(card, record, record.guid == Window.selected)
        card:SetScript("OnClick", SelectCard(record.guid))
        y = y + 100
        index = index + 1
    end
    while window.cards[index] do
        window.cards[index]:Hide()
        index = index + 1
    end
    window.rosterChild:SetHeight(math.max(8, y))
    window.rosterScroll.UpdateScroll()

    local record = Window.selected and BMGAM.DB.Get(Window.selected)
    if record then
        Theme.RacePortrait(window.portrait, record.raceFile, record.sex)
        window.characterName:SetText(record.name or "")
        window.trash:Show()
        local player = UnitGUID("player")
        if player and player == record.guid then
            window.logged:Show()
        else
            window.logged:Hide()
        end
    else
        window.portrait:SetTexture(nil)
        window.characterName:SetText("")
        window.logged:Hide()
        window.trash:Hide()
    end

    local tabIndex = 1
    while window.tabs[tabIndex] do
        local tab = window.tabs[tabIndex]
        if tab.info.id == Window.tab then
            Theme.Paint(tab, Theme.BG, Theme.GOLD_BRIGHT)
        else
            Theme.Paint(tab, Theme.PANEL, Theme.GOLD_DIM)
        end
        tabIndex = tabIndex + 1
    end

    local query = Window.queries[Window.tab or "overview"] or ""
    if window.search:GetText() ~= query then
        window.search.quiet = true
        window.search:SetText(query)
        window.search.quiet = false
    end
    if query == "" then
        window.search.placeholder:Show()
    else
        window.search.placeholder:Hide()
    end

    if window.settings and Window.tab ~= "settings" then
        window.settings:Hide()
    end

    if Window.tab == "overview" then
        window.search:Show()
        window.overview:Show()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Hide()
        end
        window.overview:Refresh(record, window.search:GetText())
    elseif Window.tab == "gear" and window.gear then
        window.search:Hide()
        window.overview:Hide()
        window.gear:Show()
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Hide()
        end
        window.gear:Refresh(record)
    elseif Window.tab == "bags" and window.bags then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        window.bags:Show()
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Hide()
        end
        window.bags:Refresh(record, window.search:GetText())
    elseif Window.tab == "bank" and window.bank then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        window.bank:Show()
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Hide()
        end
        window.bank:Refresh(record, window.search:GetText())
    elseif Window.tab == "professions" and window.professions then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        window.professions:Show()
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Hide()
        end
        window.professions:Refresh(record, window.search:GetText())
    elseif Window.tab == "currency" and window.currency then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        window.currency:Show()
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Hide()
        end
        window.currency:Refresh(record, window.search:GetText())
    elseif Window.tab == "reputation" and window.reputation then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        window.reputation:Show()
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Hide()
        end
        window.reputation:Refresh(record, window.search:GetText())
    elseif Window.tab == "mail" and window.mail then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        window.mail:Show()
        if window.blank then
            window.blank:Hide()
        end
        window.mail:Refresh(record, window.search:GetText())
    elseif Window.tab == "auction" and window.auction then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        window.auction:Show()
        if window.blank then
            window.blank:Hide()
        end
        window.auction:Refresh(record, window.search:GetText())
    elseif Window.tab == "quests" and window.quests then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        window.quests:Show()
        if window.blank then
            window.blank:Hide()
        end
        window.quests:Refresh(record, window.search:GetText())
    elseif Window.tab == "achievements" and window.achievements then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        window.achievements:Show()
        if window.blank then
            window.blank:Hide()
        end
        window.achievements:Refresh(record, window.search:GetText())
    elseif Window.tab == "collections" and window.collections then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        window.collections:Show()
        if window.blank then
            window.blank:Hide()
        end
        window.collections:Refresh(record, window.search:GetText())
    elseif Window.tab == "vault" and window.vault then
        window.search:Show()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        window.vault:Show()
        if window.blank then
            window.blank:Hide()
        end
        window.vault:Refresh(record, window.search:GetText())
    elseif Window.tab == "settings" and window.settings then
        window.search:Hide()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Hide()
        end
        window.settings:Show()
        window.settings:Refresh()
    else
        window.search:Hide()
        window.overview:Hide()
        if window.gear then
            window.gear:Hide()
        end
        if window.bags then
            window.bags:Hide()
        end
        if window.bank then
            window.bank:Hide()
        end
        if window.professions then
            window.professions:Hide()
        end
        if window.currency then
            window.currency:Hide()
        end
        if window.reputation then
            window.reputation:Hide()
        end
        if window.mail then
            window.mail:Hide()
        end
        if window.auction then
            window.auction:Hide()
        end
        if window.quests then
            window.quests:Hide()
        end
        if window.achievements then
            window.achievements:Hide()
        end
        if window.collections then
            window.collections:Hide()
        end
        if window.vault then
            window.vault:Hide()
        end
        if window.blank then
            window.blank:Show()
        end
    end
end

function Window.Open()
    Window.Ensure()
    local player = UnitGUID("player")
    if player and BMGAM.DB.Get(player) then
        Window.selected = player
    elseif not Window.selected or not BMGAM.DB.Get(Window.selected) then
        local list = BMGAM.DB.List()
        Window.selected = list[1] and list[1].guid or nil
    end
    Window.tab = "overview"
    HideDialog()
    frame:Show()
    Window.Refresh()
end

function Window.Toggle()
    Window.Ensure()
    if frame:IsShown() then
        HideDialog()
        frame:Hide()
        BMGAM.DB.SavePoint(frame)
    else
        Window.Open()
    end
end
