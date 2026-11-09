local _, LPL = ...

LPL.AddonProfileAPI = LPL.AddonProfileAPI or {}
local API = LPL.AddonProfileAPI

local KEY = "addonprofiles"

local function IsPrintBlob(text)
    return type(text) == "string" and text:match("^[%w%(%)]+$") ~= nil
end

local function IsNamedHeader(text)
    if type(text) ~= "string" or not text:find("^!") then
        return false
    end
    return text:match("^!WA:%d+!") ~= nil
        or text:match("^![Pp][Ll][Aa][Tt][Ee][Rr]:%d+!") ~= nil
        or text:match("^![Cc][Ee][Ll][Ll]:%d+:") ~= nil
        or text:match("^![Tt][Mm][Ww]%d+!") ~= nil
        or text:match("^![Ee]%d+!") ~= nil
end

local ENTRIES = {
    { key = "weakauras", label = "WeakAuras", instructions = "Open WeakAuras (/wa), choose Import, and paste this string.", detect = function(text) return text:match("^!WA:%d+!") ~= nil end },
    { key = "elvui", label = "ElvUI", instructions = "Open ElvUI config, Profiles, Import, and paste this string.", detect = function(text) return text:match("^![Ee]%d+!") ~= nil end },
    { key = "plater", label = "Plater", instructions = "Open Plater, Import, and paste this string.", detect = function(text) return text:match("^![Pp][Ll][Aa][Tt][Ee][Rr]:%d+!") ~= nil end },
    { key = "cell", label = "Cell", instructions = "Open Cell, Import, and paste this string.", detect = function(text) return text:match("^![Cc][Ee][Ll][Ll]:%d+:") ~= nil end },
    { key = "tellmewhen", label = "TellMeWhen", instructions = "Open TellMeWhen options, Import, and paste this string.", detect = function(text) return text:match("^![Tt][Mm][Ww]%d+!") ~= nil end },
    { key = "grid2", label = "Grid2", instructions = "Open Grid2 (/grid2), Profiles, Import, and paste this string.", detect = function(text) return text:match("%[=== .- profile ===%]") ~= nil end },
    { key = "mdt", label = "Mythic Dungeon Tools", instructions = "Open MDT (/mdt), Import, and paste the route string.", detect = function(text) return #text >= 40 and text:find("^!") and not IsNamedHeader(text) and IsPrintBlob(text:sub(2)) end },
    { key = "details", label = "Details!", instructions = "Open Details options, Profiles, Import, and paste this string.", detect = function(text) return #text >= 280 and not text:find("^!") and IsPrintBlob(text) and text:find("%(") and text:find("%)") end },
    { key = "vuhdo", label = "VuhDo", instructions = "Open VuhDo (/vd opt), Tools, Profiles, Import, and paste this string." },
    { key = "omnicd", label = "OmniCD", instructions = "Open OmniCD (/oc), Profiles, Import, and paste this string." },
    { key = "bigwigs", label = "BigWigs", instructions = "Open BigWigs (/bw), Options, Profiles, Import, and paste this string." },
    { key = "platynator", label = "Platynator", instructions = "Open Platynator (/platynator), General, Import, and paste this string." },
    { key = "suf", label = "Shadowed Unit Frames", instructions = "Open SUF (/suf), Layout Manager, Import, and paste this string." },
    { key = "custom", label = "Custom", instructions = "Paste this string into the addon that created it." },
}

local function Entry(key)
    for i = 1, #ENTRIES do
        if ENTRIES[i].key == key then
            return ENTRIES[i]
        end
    end
    return ENTRIES[#ENTRIES]
end

local function Detect(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end
    for i = 1, #ENTRIES do
        local detect = ENTRIES[i].detect
        if detect and detect(text) then
            return ENTRIES[i].key
        end
    end
    return nil
end

local function DisplayLabel(set)
    local entry = Entry(set and set.addonKey)
    if entry.key == "custom" then
        local custom = LPL:PlainString(set and set.addonLabel)
        if custom then
            return custom
        end
    end
    return entry.label
end

local function PasteText(value)
    if type(value) ~= "string" or (issecretvalue and issecretvalue(value)) then
        return ""
    end
    return value
end

function API:Available()
    return true
end

function API:List()
    return LPL.SetStore:List(KEY)
end

function API:Get(id)
    return LPL.SetStore:Get(KEY, id)
end

function API:SuggestName()
    return LPL.SetStore:SuggestName(KEY, "Profile")
end

function API:Empty()
    return {
        name = self:SuggestName(),
        addonKey = "custom",
        addonLabel = "",
        paste = "",
    }
end

function API:Summary(set)
    local label = DisplayLabel(set)
    local paste = PasteText(set and set.paste)
    if paste == "" then
        return label .. " · empty"
    end
    return label .. " · " .. tostring(#paste) .. " characters"
end

function API:Capture()
    return { error = "Paste the string into the box. This profile is not read from your character." }
end

function API:Matches()
    return false
end

function API:SyncDraft(page, draftSet)
    if not draftSet then
        return
    end
    if page and page.profileBox then
        draftSet.paste = PasteText(page.profileBox:GetText())
    end
    if page and page.profileCustomBox and draftSet.addonKey == "custom" then
        draftSet.addonLabel = LPL:PlainString(page.profileCustomBox:GetText()) or ""
    end
end

local function RecordFrom(draft)
    local key = LPL:PlainString(draft and draft.addonKey) or "custom"
    if not Entry(key) then
        key = "custom"
    end
    local label = ""
    if key == "custom" then
        label = LPL:PlainString(draft and draft.addonLabel) or ""
    end
    return {
        addonKey = key,
        addonLabel = label,
        paste = PasteText(draft and draft.paste),
    }
end

function API:Save(draft, name)
    return LPL.SetStore:Save(KEY, RecordFrom(draft), name, self:SuggestName())
end

function API:Update(id, draft, name)
    return LPL.SetStore:Update(KEY, id, RecordFrom(draft), name, "Profile")
end

function API:Delete(id)
    return LPL.SetStore:Delete(KEY, id)
end

function API:Apply(set)
    local entry = Entry(set and set.addonKey)
    local paste = PasteText(set and set.paste)
    if paste == "" then
        return false, "Paste a string into the box first."
    end
    return true, entry.instructions
end

local function EnsureProfileMenu(page)
    if page.profileMenu then
        return page.profileMenu
    end
    local catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("FULLSCREEN_DIALOG")
    catcher:EnableMouse(true)
    catcher:SetFrameLevel(1)
    catcher:Hide()
    local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(30)
    menu:SetClampedToScreen(true)
    menu:EnableMouse(true)
    menu:Hide()
    menu.buttons = {}
    menu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    menu:SetBackdropColor(0.08, 0.08, 0.10, 1)
    menu:SetBackdropBorderColor(0.25, 0.27, 0.32, 1)
    menu:SetScript("OnShow", function()
        catcher:Show()
    end)
    menu:SetScript("OnHide", function()
        catcher:Hide()
    end)
    catcher:SetScript("OnClick", function()
        menu:Hide()
    end)
    page.profileMenu = menu
    return menu
end

local function OpenAddonMenu(page, anchor, draftSet, refresh)
    local menu = EnsureProfileMenu(page)
    local selected = LPL:PlainString(draftSet.addonKey) or "custom"
    local width = math.max(240, anchor:GetWidth() or 240)
    local y = 6
    for i = 1, #ENTRIES do
        local item = ENTRIES[i]
        local button = menu.buttons[i]
        if not button then
            button = CreateFrame("Button", nil, menu, "BackdropTemplate")
            button:SetHeight(22)
            button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            button.label:SetPoint("LEFT", 8, 0)
            button.label:SetPoint("RIGHT", -8, 0)
            button.label:SetJustifyH("LEFT")
            menu.buttons[i] = button
        end
        button:SetSize(width - 12, 22)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 6, -y)
        button.label:SetText(item.label)
        local picked = item.key == selected
        button.label:SetTextColor(picked and 1 or 0.95, picked and 0.92 or 0.95, picked and 0.40 or 0.97)
        local key = item.key
        button:SetScript("OnClick", function()
            draftSet.addonKey = key
            if key ~= "custom" then
                draftSet.addonLabel = ""
            end
            menu:Hide()
            refresh()
        end)
        button:Show()
        y = y + 24
    end
    for i = #ENTRIES + 1, #menu.buttons do
        menu.buttons[i]:Hide()
    end
    menu:SetSize(width, y + 4)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu:Show()
end

function API:DrawEditor(page, draftSet, refresh)
    local panel = page.profilePanel
    if not panel then
        panel = CreateFrame("Frame", nil, page.editorChild)
        panel:SetPoint("TOPLEFT", 8, -8)
        panel.kind = CreateFrame("Button", nil, panel, "BackdropTemplate")
        panel.kind:SetHeight(28)
        panel.kind:SetPoint("TOPLEFT", 0, 0)
        panel.kind.label = panel.kind:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        panel.kind.label:SetPoint("LEFT", 8, 0)
        panel.kind.label:SetPoint("RIGHT", -8, 0)
        panel.kind.label:SetJustifyH("LEFT")
        panel.customTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        panel.customTitle:SetText("Name")
        panel.customTitle:SetTextColor(0.7, 0.7, 0.7)
        panel.customBox = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
        panel.customBox:SetHeight(28)
        panel.customBox:SetAutoFocus(false)
        panel.customBox:SetFontObject("GameFontHighlight")
        panel.customBox:SetTextInsets(8, 8, 0, 0)
        panel.customBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        panel.customBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
        end)
        page.profileCustomBox = panel.customBox
        panel.instructions = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        panel.instructions:SetPoint("TOPLEFT", panel.kind, "BOTTOMLEFT", 0, -8)
        panel.instructions:SetJustifyH("LEFT")
        panel.instructions:SetHeight(32)
        panel.instructions:SetTextColor(0.7, 0.7, 0.7)
        local box = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetMaxLetters(0)
        box:SetFontObject("GameFontHighlight")
        box:SetTextInsets(8, 8, 8, 8)
        box:EnableMouse(true)
        box:EnableKeyboard(true)
        box:SetPoint("TOPLEFT", panel.instructions, "BOTTOMLEFT", 0, -8)
        box:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
        box:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)
        panel.box = box
        page.profileBox = box
        page.profilePanel = panel
    end
    if page.profileMenu then
        page.profileMenu:Hide()
    end
    local entry = Entry(draftSet.addonKey)
    local width = math.max(520, (page.editorScroll:GetWidth() or 640) - 24)
    local height = math.max(300, (page.editorScroll:GetHeight() or 360) - 8)
    panel:SetSize(width, height)
    panel.kind:SetWidth(260)
    panel.kind:SetFrameLevel((panel:GetFrameLevel() or 1) + 5)
    panel.kind:EnableMouse(true)
    panel.kind:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    panel.kind:SetBackdropColor(0, 0, 0, 1)
    panel.kind:SetBackdropBorderColor(1, 0.92, 0.40, 1)
    panel.kind.label:SetText("Addon: " .. entry.label)
    panel.instructions:SetPoint("RIGHT", panel, "RIGHT", 0, 0)
    panel.instructions:SetText(entry.instructions)
    panel.kind:SetScript("OnClick", function()
        OpenAddonMenu(page, panel.kind, draftSet, refresh)
    end)
    local custom = entry.key == "custom"
    panel.customTitle:ClearAllPoints()
    panel.customTitle:SetPoint("LEFT", panel.kind, "RIGHT", 16, 0)
    panel.customTitle:SetShown(custom)
    panel.customBox:ClearAllPoints()
    panel.customBox:SetPoint("LEFT", panel.customTitle, "RIGHT", 8, 0)
    panel.customBox:SetSize(180, 28)
    panel.customBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    panel.customBox:SetBackdropColor(0.08, 0.08, 0.10, 1)
    panel.customBox:SetBackdropBorderColor(1, 0.92, 0.40, 1)
    panel.customBox:SetShown(custom)
    panel.customBox:SetScript("OnTextChanged", function(self)
        if panel.suppress or not draftSet then
            return
        end
        draftSet.addonLabel = LPL:PlainString(self:GetText()) or ""
    end)
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
        draftSet.paste = PasteText(self:GetText())
        local detected = Detect(draftSet.paste)
        if detected and detected ~= draftSet.addonKey then
            draftSet.addonKey = detected
            if detected ~= "custom" then
                draftSet.addonLabel = ""
            end
            local found = Entry(detected)
            panel.kind.label:SetText("Addon: " .. found.label)
            panel.instructions:SetText(found.instructions)
            panel.customTitle:SetShown(false)
            panel.customBox:SetShown(false)
        end
    end)
    local paste = PasteText(draftSet.paste)
    local customName = LPL:PlainString(draftSet.addonLabel) or ""
    panel.suppress = true
    if panel.box:GetText() ~= paste then
        panel.box:SetText(paste)
    end
    if panel.customBox:GetText() ~= customName then
        panel.customBox:SetText(customName)
    end
    panel.suppress = false
    if paste == "" and not custom then
        panel.box:SetFocus()
    end
    panel:Show()
    page.editorChild:SetWidth(width + 16)
    page.editorChild:SetHeight(height + 16)
end
