local _, LPL = ...

LPL.MacroAPI = LPL.MacroAPI or {}
local API = LPL.MacroAPI

local KEY = "macros"
local MAX_BODY = 255
local MAX_NAME = 16
local DEFAULT_ICON = 134400

local function Trim(text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then
        return ""
    end
    text = text:match("^%s*(.-)%s*$") or ""
    if #text > MAX_BODY then
        text = text:sub(1, MAX_BODY)
    end
    return text
end

local function MacroName(name)
    name = LPL:PlainString(name) or "Macro"
    if #name > MAX_NAME then
        name = name:sub(1, MAX_NAME)
    end
    if name == "" then
        name = "Macro"
    end
    return name
end

local function AccountMax()
    return LPL:PlainNumber(MAX_ACCOUNT_MACROS) or 120
end

local function CharacterMax()
    return LPL:PlainNumber(MAX_CHARACTER_MACROS) or 18
end

local function LiveMacros()
    local out = {}
    if not GetNumMacros or not GetMacroInfo then
        return out
    end
    local ok, numAccount, numCharacter = pcall(GetNumMacros)
    numAccount = ok and (LPL:PlainNumber(numAccount) or 0) or 0
    numCharacter = ok and (LPL:PlainNumber(numCharacter) or 0) or 0
    local function Add(index, scope)
        local infoOk, name, icon, body = pcall(GetMacroInfo, index)
        if not infoOk then
            return
        end
        local plainName = LPL:PlainString(name)
        local plainBody = Trim(body)
        if plainName then
            out[#out + 1] = {
                index = index,
                scope = scope,
                name = plainName,
                icon = LPL:PlainNumber(icon) or DEFAULT_ICON,
                body = plainBody,
            }
        end
    end
    for i = 1, numAccount do
        Add(i, "account")
    end
    local charStart = AccountMax() + 1
    for i = charStart, charStart + numCharacter - 1 do
        Add(i, "character")
    end
    return out
end

function API:Available()
    return GetNumMacros ~= nil and CreateMacro ~= nil and EditMacro ~= nil
end

function API:List()
    return LPL.SetStore:List(KEY)
end

function API:Get(id)
    return LPL.SetStore:Get(KEY, id)
end

function API:SuggestName()
    return LPL.SetStore:SuggestName(KEY, "Macro")
end

function API:Empty()
    return {
        name = self:SuggestName(),
        body = "",
        icon = DEFAULT_ICON,
        macroScope = "account",
    }
end

function API:Summary(set)
    local scope = (set and set.macroScope == "character") and "Character" or "Account"
    local body = Trim(set and set.body)
    if body == "" then
        return scope .. " · empty"
    end
    return scope .. " · " .. tostring(#body) .. " characters"
end

function API:Capture()
    local macros = LiveMacros()
    if #macros == 0 then
        return { error = "No macros on this character could be read." }
    end
    return macros[1]
end

function API:ApplyCapture(draft, live)
    if type(live) ~= "table" or not live.name then
        return
    end
    draft.name = live.name
    draft.body = Trim(live.body)
    draft.icon = LPL:PlainNumber(live.icon) or DEFAULT_ICON
    draft.macroScope = live.scope == "character" and "character" or "account"
end

function API:Matches()
    return false
end

function API:SyncDraft(page, draftSet)
    if page and page.macroBox and draftSet then
        draftSet.body = Trim(page.macroBox:GetText())
    end
end

local function RecordFrom(draft)
    return {
        body = Trim(draft and draft.body),
        icon = LPL:PlainNumber(draft and draft.icon) or DEFAULT_ICON,
        macroScope = (draft and draft.macroScope == "character") and "character" or "account",
    }
end

function API:Save(draft, name)
    local record = RecordFrom(draft)
    return LPL.SetStore:Save(KEY, record, MacroName(name), self:SuggestName())
end

function API:Update(id, draft, name)
    return LPL.SetStore:Update(KEY, id, RecordFrom(draft), MacroName(name), "Macro")
end

function API:Delete(id)
    return LPL.SetStore:Delete(KEY, id)
end

local function FindLive(name, scope)
    local macros = LiveMacros()
    for i = 1, #macros do
        if macros[i].name == name and macros[i].scope == scope then
            return macros[i].index
        end
    end
    return nil
end

function API:Apply(set)
    if not self:Available() then
        return false, "Macros are not available on this client."
    end
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat, then apply this macro."
    end
    local name = MacroName(set and set.name)
    local body = Trim(set and set.body)
    local icon = LPL:PlainNumber(set and set.icon) or DEFAULT_ICON
    local perCharacter = set and set.macroScope == "character"
    local scope = perCharacter and "character" or "account"
    local index = FindLive(name, scope)
    if index then
        local ok = pcall(EditMacro, index, name, icon, body)
        if not ok then
            return false, "The game did not update that macro."
        end
        return true, "Updated macro \"" .. name .. "\"."
    end
    local okCount, numAccount, numCharacter = pcall(GetNumMacros)
    numAccount = okCount and (LPL:PlainNumber(numAccount) or 0) or 0
    numCharacter = okCount and (LPL:PlainNumber(numCharacter) or 0) or 0
    if perCharacter and numCharacter >= CharacterMax() then
        return false, "The character macro list is full."
    end
    if not perCharacter and numAccount >= AccountMax() then
        return false, "The account macro list is full."
    end
    local created, newIndex = pcall(CreateMacro, name, icon, body, perCharacter)
    if not created or not newIndex then
        return false, "The game did not create that macro."
    end
    return true, "Created macro \"" .. name .. "\"."
end

function API:DrawEditor(page, draftSet, refresh)
    local panel = page.macroPanel
    if not panel then
        panel = CreateFrame("Frame", nil, page.editorChild)
        panel:SetPoint("TOPLEFT", 8, -8)
        panel.account = CreateFrame("Button", nil, panel, "BackdropTemplate")
        panel.account:SetSize(110, 24)
        panel.account:SetPoint("TOPLEFT", 0, 0)
        panel.account.text = panel.account:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        panel.account.text:SetPoint("CENTER")
        panel.account.text:SetText("Account")
        panel.character = CreateFrame("Button", nil, panel, "BackdropTemplate")
        panel.character:SetSize(110, 24)
        panel.character:SetPoint("LEFT", panel.account, "RIGHT", 8, 0)
        panel.character.text = panel.character:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        panel.character.text:SetPoint("CENTER")
        panel.character.text:SetText("Character")
        panel.load = CreateFrame("Button", nil, panel, "BackdropTemplate")
        panel.load:SetSize(160, 24)
        panel.load:SetPoint("LEFT", panel.character, "RIGHT", 8, 0)
        panel.load.text = panel.load:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        panel.load.text:SetPoint("CENTER")
        panel.load.text:SetText("Load from macros")
        panel.icon = panel:CreateTexture(nil, "ARTWORK")
        panel.icon:SetSize(48, 48)
        panel.icon:SetPoint("TOPLEFT", panel.account, "BOTTOMLEFT", 0, -12)
        local box = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetMaxLetters(MAX_BODY)
        box:SetFontObject("GameFontHighlight")
        box:SetTextInsets(8, 8, 8, 8)
        box:EnableMouse(true)
        box:EnableKeyboard(true)
        box:SetPoint("TOPLEFT", panel.icon, "BOTTOMLEFT", 0, -12)
        box:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        panel.box = box
        page.macroBox = box
        panel.counter = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.counter:SetPoint("LEFT", panel.icon, "RIGHT", 12, 0)
        page.macroPanel = panel
    end
    local function PaintButton(button, selected)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        if selected then
            button:SetBackdropColor(0.28, 0.05, 0.09, 1)
            button:SetBackdropBorderColor(1, 0.92, 0.40, 1)
        else
            button:SetBackdropColor(0.18, 0.18, 0.22, 1)
            button:SetBackdropBorderColor(0.96, 0.55, 0.73, 1)
        end
    end
    local character = draftSet.macroScope == "character"
    PaintButton(panel.account, not character)
    PaintButton(panel.character, character)
    PaintButton(panel.load, false)
    panel.account:SetScript("OnClick", function()
        draftSet.macroScope = "account"
        refresh()
    end)
    panel.character:SetScript("OnClick", function()
        draftSet.macroScope = "character"
        refresh()
    end)
    panel.load:SetScript("OnClick", function()
        local macros = LiveMacros()
        if #macros == 0 then
            return
        end
        local menu = page.macroMenu
        if not menu then
            menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            menu:SetFrameStrata("FULLSCREEN_DIALOG")
            menu:SetClampedToScreen(true)
            menu.buttons = {}
            menu:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                tile = false,
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
            menu:SetBackdropColor(0.08, 0.08, 0.10, 1)
            menu:SetBackdropBorderColor(1, 0.92, 0.40, 1)
            page.macroMenu = menu
        end
        local y = 6
        for i = 1, #macros do
            local button = menu.buttons[i]
            if not button then
                button = CreateFrame("Button", nil, menu)
                button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                button.label:SetPoint("LEFT", 8, 0)
                button.label:SetPoint("RIGHT", -8, 0)
                button.label:SetJustifyH("LEFT")
                menu.buttons[i] = button
            end
            local macro = macros[i]
            button:SetSize(260, 22)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 6, -y)
            button.label:SetText(macro.name .. " (" .. macro.scope .. ")")
            button:SetScript("OnClick", function()
                menu:Hide()
                API:ApplyCapture(draftSet, macro)
                if page.nameBox then
                    page.nameBox:SetText(draftSet.name or "")
                end
                refresh()
            end)
            button:Show()
            y = y + 24
        end
        for i = #macros + 1, #menu.buttons do
            menu.buttons[i]:Hide()
        end
        menu:SetSize(272, y + 6)
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", panel.load, "BOTTOMLEFT", 0, -2)
        menu:Show()
    end)
    panel.icon:SetTexture(LPL:PlainNumber(draftSet.icon) or DEFAULT_ICON)
    local width = math.max(520, (page.editorScroll:GetWidth() or 640) - 24)
    local height = math.max(280, (page.editorScroll:GetHeight() or 360) - 8)
    panel:SetSize(width, height)
    panel.box:SetSize(width, math.max(180, height - 110))
    panel.box:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    panel.box:SetBackdropColor(0.08, 0.08, 0.10, 1)
    panel.box:SetBackdropBorderColor(1, 0.92, 0.40, 1)
    panel.box:SetScript("OnTextChanged", function(self)
        if panel.suppress or not draftSet then
            return
        end
        draftSet.body = Trim(self:GetText())
        if panel.counter then
            panel.counter:SetText(tostring(#(draftSet.body or "")) .. " / " .. tostring(MAX_BODY))
        end
    end)
    local body = Trim(draftSet.body)
    panel.suppress = true
    if panel.box:GetText() ~= body then
        panel.box:SetText(body)
    end
    panel.suppress = false
    panel.counter:SetText(tostring(#body) .. " / " .. tostring(MAX_BODY))
    panel:Show()
    page.editorChild:SetWidth(width + 16)
    page.editorChild:SetHeight(height + 16)
end
