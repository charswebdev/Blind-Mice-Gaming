--[[
  Cooldown Assist — high-contrast tabbed settings
  Tabs: General | Cooldowns | Profiles
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Settings = CA.Settings or {}
local Settings = CA.Settings

local FRAME_NAME = "CooldownAssistSettingsFrame"
local ICON_PATH = "Interface\\AddOns\\CooldownAssist\\Media\\Icon.tga"
local ICON_PATH_FALLBACK = "Interface\\AddOns\\CooldownAssist\\Media\\Icon"

local COL_BG = { 0, 0, 0, 1 }
local COL_BORDER = { 1, 1, 1, 1 }
local COL_TITLE = { 1, 1, 1, 1 }
local COL_SECTION = { 1, 0.92, 0.4, 1 }
local COL_LABEL = { 1, 1, 1, 1 }
local COL_HINT = { 0.75, 0.75, 0.75, 1 }
local COL_TAB = { 0.12, 0.12, 0.12, 1 }
local COL_TAB_ON = { 0.28, 0.28, 0.08, 1 }
local COL_ROW = { 0.08, 0.08, 0.08, 1 }
local COL_BTN = { 0.06, 0.06, 0.06, 1 }
local COL_BTN_HOVER = { 0.22, 0.22, 0.1, 1 }
local COL_BTN_ACTIVE = { 0.32, 0.28, 0.08, 1 }
local COL_BTN_BORDER = { 1, 1, 1, 1 }
local COL_BTN_BORDER_HOT = { 1, 0.92, 0.4, 1 }
local COL_DANGER = { 0.35, 0.08, 0.08, 1 }
local COL_DANGER_HOVER = { 0.5, 0.12, 0.12, 1 }

local TABS = {
    { id = "general", label = "General" },
    { id = "cooldowns", label = "Cooldowns" },
    { id = "profiles", label = "Profiles" },
}

local frame
local built = false
local selectedTab = 1
local checkboxes = {}
local steppers = {}
local tabButtons = {}
local panels = {}
local trackerScroll
local trackerChild
local trackerRows = {}
local trackerCountFS
local profileScroll
local profileChild
local profileRows = {}
local profileNameBox
local profileStatusFS
local selectedProfileId
local filterButtons = {}

local function FontString(parent, size, r, g, b, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local ok = fs:SetFont("Fonts\\FRIZQT__.TTF", size or 14, flags or "OUTLINE")
    if not ok then
        fs:SetFontObject(GameFontHighlight)
    end
    fs:SetTextColor(r or 1, g or 1, b or 1, 1)
    fs:SetJustifyH("LEFT")
    return fs
end

local function ApplyBlackBackdrop(f)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        })
        f:SetBackdropColor(COL_BG[1], COL_BG[2], COL_BG[3], COL_BG[4])
        f:SetBackdropBorderColor(COL_BORDER[1], COL_BORDER[2], COL_BORDER[3], COL_BORDER[4])
        return
    end
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(0, 0, 0, 1)
end

local function PaintSolid(f, r, g, b, a, borderR, borderG, borderB)
    a = a or 1
    if not f._caPainted then
        if f.SetBackdrop then
            f:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
        else
            local t = f:CreateTexture(nil, "BACKGROUND")
            t:SetAllPoints()
            f._caTex = t
        end
        f._caPainted = true
    end
    if f.SetBackdropColor then
        f:SetBackdropColor(r, g, b, a)
        f:SetBackdropBorderColor(borderR or 0.35, borderG or 0.35, borderB or 0.35, 1)
    elseif f._caTex then
        f._caTex:SetColorTexture(r, g, b, a)
    end
end

local function StyleThemeButton(btn, opts)
    opts = opts or {}
    local danger = opts.danger and true or false
    local fontSize = opts.fontSize or 13
    btn._caDanger = danger
    btn._caSelected = false

    PaintSolid(
        btn,
        COL_BTN[1], COL_BTN[2], COL_BTN[3], 1,
        COL_BTN_BORDER[1], COL_BTN_BORDER[2], COL_BTN_BORDER[3]
    )

    local fs = btn:GetFontString()
    if not fs then
        fs = btn:CreateFontString(nil, "OVERLAY")
        btn:SetFontString(fs)
    end
    local ok = fs:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "OUTLINE")
    if not ok then
        fs:SetFontObject(GameFontHighlight)
    end
    fs:SetTextColor(COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], 1)
    fs:SetShadowOffset(0, 0)
    fs:SetJustifyH("CENTER")
    fs:SetPoint("CENTER")

    local function ApplyNormal()
        if btn._caSelected then
            PaintSolid(
                btn,
                COL_BTN_ACTIVE[1], COL_BTN_ACTIVE[2], COL_BTN_ACTIVE[3], 1,
                COL_BTN_BORDER_HOT[1], COL_BTN_BORDER_HOT[2], COL_BTN_BORDER_HOT[3]
            )
            fs:SetTextColor(COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], 1)
            return
        end
        if danger then
            PaintSolid(
                btn,
                COL_DANGER[1], COL_DANGER[2], COL_DANGER[3], 1,
                1, 0.45, 0.45
            )
        else
            PaintSolid(
                btn,
                COL_BTN[1], COL_BTN[2], COL_BTN[3], 1,
                COL_BTN_BORDER[1], COL_BTN_BORDER[2], COL_BTN_BORDER[3]
            )
        end
        fs:SetTextColor(COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], 1)
    end

    local function ApplyHover()
        if danger then
            PaintSolid(
                btn,
                COL_DANGER_HOVER[1], COL_DANGER_HOVER[2], COL_DANGER_HOVER[3], 1,
                1, 0.7, 0.7
            )
            fs:SetTextColor(1, 0.85, 0.85, 1)
        else
            PaintSolid(
                btn,
                COL_BTN_HOVER[1], COL_BTN_HOVER[2], COL_BTN_HOVER[3], 1,
                COL_BTN_BORDER_HOT[1], COL_BTN_BORDER_HOT[2], COL_BTN_BORDER_HOT[3]
            )
            fs:SetTextColor(COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], 1)
        end
    end

    btn._caApplyNormal = ApplyNormal
    btn:SetScript("OnEnter", function()
        ApplyHover()
    end)
    btn:SetScript("OnLeave", function()
        ApplyNormal()
    end)
    btn:SetScript("OnMouseDown", function()
        PaintSolid(
            btn,
            COL_BTN_ACTIVE[1], COL_BTN_ACTIVE[2], COL_BTN_ACTIVE[3], 1,
            COL_BTN_BORDER_HOT[1], COL_BTN_BORDER_HOT[2], COL_BTN_BORDER_HOT[3]
        )
    end)
    btn:SetScript("OnMouseUp", function()
        if btn:IsMouseOver() then
            ApplyHover()
        else
            ApplyNormal()
        end
    end)
    ApplyNormal()
end

local function SetThemeButtonSelected(btn, selected)
    if not btn then
        return
    end
    btn._caSelected = selected and true or false
    if btn._caApplyNormal then
        btn._caApplyNormal()
    end
end

--- High-contrast themed button (replaces Blizzard UIPanelButtonTemplate).
local function MakeThemeButton(parent, text, width, height, onClick, opts)
    local template = BackdropTemplateMixin and "BackdropTemplate" or nil
    local btn = CreateFrame("Button", nil, parent, template)
    btn:SetSize(width or 90, height or 26)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
    StyleThemeButton(btn, opts)
    btn:SetText(text or "")
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function MakeCheckbox(parent, labelText, dbKey, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 16, y)
    cb:SetSize(28, 28)

    local label = FontString(parent, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
    label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    label:SetWidth(360)
    label:SetText(labelText)

    local function Refresh()
        local sv = CA.DB.Get()
        if dbKey == "chatEcho" then
            cb:SetChecked(sv[dbKey] == true)
        else
            cb:SetChecked(sv[dbKey] ~= false)
        end
    end

    cb:SetScript("OnClick", function(self)
        local sv = CA.DB.Get()
        sv[dbKey] = self:GetChecked() and true or false
        if dbKey == "minimapButtonEnabled" and CA.MinimapButton and CA.MinimapButton.Refresh then
            CA.MinimapButton.Refresh()
        end
        if (dbKey == "includeSpellbookAbilities"
            or dbKey == "includeSpellbookRacials"
            or dbKey == "includeSpellbookGeneral"
            or dbKey == "includePetAbilities"
            or dbKey == "includeHearthstone"
            or dbKey == "includeTeleportItems"
            or dbKey == "includeToys"
            or dbKey == "toysFavoritesOnly"
            or dbKey == "includeTrinkets"
            or dbKey == "includeOnUseGear"
            or dbKey == "includeCombatPotions"
            or dbKey == "includeHealthstones")
            and CA.Spells and CA.Spells.RequestRescan
        then
            -- Gear/consumable toggles only need a light rescan; toy toggles request heavy.
            local heavy = (dbKey == "includeToys" or dbKey == "toysFavoritesOnly" or dbKey == "includeTeleportItems")
            CA.Spells.RequestRescan(heavy)
        end
        if (dbKey == "announceBuffFaded" or dbKey == "trackCategoryBuff")
            and CA.Buffs and CA.Buffs.Resync
        then
            CA.Buffs.Resync()
        end
        if CA.Speech and CA.Speech.Say then
            local state = sv[dbKey] and "on" or "off"
            CA.Speech.Say(labelText .. " " .. state .. ".", CA.Speech.PRIORITY_LOW)
        end
    end)

    cb.Refresh = Refresh
    Refresh()
    checkboxes[#checkboxes + 1] = cb
    return y - 32
end

local function MakeStepper(parent, labelText, dbKey, y, minV, maxV, step, formatFn)
    local label = FontString(parent, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
    label:SetPoint("TOPLEFT", 16, y)
    label:SetWidth(200)

    local valueFS = FontString(parent, 14, COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], "OUTLINE")
    valueFS:SetPoint("LEFT", label, "RIGHT", 8, 0)
    valueFS:SetWidth(60)

    local function Read()
        local sv = CA.DB.Get()
        local v = sv[dbKey]
        if type(v) ~= "number" then
            v = minV
        end
        if v < minV then v = minV end
        if v > maxV then v = maxV end
        return v
    end

    local function Write(v)
        local sv = CA.DB.Get()
        sv[dbKey] = v
        if formatFn then
            valueFS:SetText(formatFn(v))
        else
            valueFS:SetText(tostring(v))
        end
    end

    local minus = MakeThemeButton(parent, "-", 28, 24, function()
        local v = Read() - step
        if v < minV then v = minV end
        Write(v)
    end)
    minus:SetPoint("LEFT", valueFS, "RIGHT", 8, 0)

    local plus = MakeThemeButton(parent, "+", 28, 24, function()
        local v = Read() + step
        if v > maxV then v = maxV end
        Write(v)
    end)
    plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)

    local function Refresh()
        Write(Read())
    end

    Refresh()
    steppers[#steppers + 1] = { Refresh = Refresh }
    return y - 36
end

local function MakeSection(parent, text, y)
    local fs = FontString(parent, 15, COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], "OUTLINE")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetText(text)
    return y - 28
end

local function MakeHint(parent, text, y)
    local fs = FontString(parent, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    fs:SetPoint("TOPLEFT", 16, y)
    fs:SetWidth(380)
    if fs.SetJustifyV then
        fs:SetJustifyV("TOP")
    end
    if fs.SetWordWrap then
        fs:SetWordWrap(true)
    end
    fs:SetText(text)

    local lineH = 16
    local h = lineH
    if fs.GetStringHeight then
        local measured = fs:GetStringHeight()
        if type(measured) == "number" and measured > lineH then
            h = measured
        elseif type(text) == "string" and #text > 50 then
            -- Hidden parents can report a single-line height before wrap is known.
            h = math.ceil(#text / 50) * lineH
        end
    elseif type(text) == "string" then
        h = math.max(1, math.ceil(#text / 50)) * lineH
    end
    return y - (h + 12)
end

local function ClearTrackerRows()
    for i = 1, #trackerRows do
        trackerRows[i]:Hide()
        trackerRows[i]:SetParent(nil)
    end
    wipe(trackerRows)
end

local function TooltipAddBlank()
    if GameTooltip_AddBlankLineToTooltip then
        GameTooltip_AddBlankLineToTooltip(GameTooltip)
    else
        GameTooltip:AddLine(" ")
    end
end

local function TooltipAddNormal(text)
    if not text then
        return
    end
    if GameTooltip_AddNormalLine then
        GameTooltip_AddNormalLine(GameTooltip, text, true)
    else
        GameTooltip:AddLine(text, 1, 0.82, 0, true) -- Blizzard gold
    end
end

local function TooltipAddDisabled(text)
    if not text then
        return
    end
    if GameTooltip_AddDisabledLine then
        GameTooltip_AddDisabledLine(GameTooltip, text, true)
    else
        GameTooltip:AddLine(text, 0.5, 0.5, 0.5, true)
    end
end

local function TooltipAddInstruction(text)
    if not text then
        return
    end
    if GameTooltip_AddInstructionLine then
        GameTooltip_AddInstructionLine(GameTooltip, text, true)
    else
        GameTooltip:AddLine(text, 0.2, 0.8, 0.2, true) -- Blizzard green instruction
    end
end

local function SafeReadableString(v)
    if type(v) ~= "string" or v == "" then
        return nil
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        if ok and secret then
            return nil
        end
    end
    return v
end

local function SafeSpellDescription(spellID)
    if type(spellID) ~= "number" then
        return nil
    end
    if C_Spell and C_Spell.GetSpellDescription then
        local ok, desc = pcall(C_Spell.GetSpellDescription, spellID)
        if ok then
            return SafeReadableString(desc)
        end
    end
    if GetSpellDescription then
        local ok, desc = pcall(GetSpellDescription, spellID)
        if ok then
            return SafeReadableString(desc)
        end
    end
    return nil
end

--- Plain text for Accessibility Helper when Blizzard tooltip lines are secret.
local function BuildTrackerSpeakText(entry, itemID, spellID, isItem)
    local parts = {}
    local name = SafeReadableString(entry.name) or "Unknown"
    parts[#parts + 1] = name

    if isItem and type(itemID) == "number" then
        parts[#parts + 1] = "Item"
    elseif type(spellID) == "number" then
        local desc = SafeSpellDescription(spellID)
        if desc then
            parts[#parts + 1] = desc
        else
            parts[#parts + 1] = "Spell"
        end
    end

    local group = entry.groupLabel or entry.categoryLabel
    if group then
        parts[#parts + 1] = tostring(group)
    end
    if entry.enabled == false then
        parts[#parts + 1] = "Tracking disabled"
    else
        parts[#parts + 1] = "Tracking enabled"
    end
    if entry.pending then
        parts[#parts + 1] = "On cooldown"
    end
    if isItem and type(itemID) == "number" then
        parts[#parts + 1] = "Item ID " .. tostring(itemID)
    elseif type(spellID) == "number" then
        parts[#parts + 1] = "Spell ID " .. tostring(spellID)
    end
    return table.concat(parts, ". ")
end

local function SetAHSpeakText(text)
    if GameTooltip then
        GameTooltip.AccessibilityHelperSpeakText = text
    end
end

local function ClearAHSpeakText()
    if GameTooltip then
        GameTooltip.AccessibilityHelperSpeakText = nil
    end
end

--- Blizzard GameTooltip anchored to the bottom-right of the row icon.
local function ShowTrackerTooltip(iconOwner, entry)
    if not GameTooltip or not entry or not iconOwner then
        return
    end
    -- ANCHOR_BOTTOMRIGHT: tooltip top-left sits on the icon's bottom-right.
    GameTooltip:SetOwner(iconOwner, "ANCHOR_BOTTOMRIGHT", 4, -2)

    local itemID = entry.itemID
    local spellID = entry.spellID
    local kind = entry.kind
    local key = tostring(entry.key or "")
    local isItem = type(itemID) == "number"
        or key:find("^toy:")
        or key:find("^hearth:")
        or key:find("^item:")
        or key:find("^trinket:")
        or key:find("^gear:")
        or key:find("^consumable:")
        or (key:find("^teleport:") and kind ~= nil and kind ~= "spell")
    if isItem and type(itemID) ~= "number" and type(spellID) == "number" then
        itemID = spellID
    end

    local shown = false
    if isItem and type(itemID) == "number" then
        if (kind == "toy" or key:find("^toy:")) and GameTooltip.SetToyByItemID then
            local ok = pcall(GameTooltip.SetToyByItemID, GameTooltip, itemID)
            shown = ok and true or false
        end
        if not shown and GameTooltip.SetItemByID then
            local ok = pcall(GameTooltip.SetItemByID, GameTooltip, itemID)
            shown = ok and true or false
        elseif not shown and GameTooltip.SetHyperlink then
            local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "item:" .. tostring(itemID))
            shown = ok and true or false
        end
    elseif type(spellID) == "number" then
        if GameTooltip.SetSpellByID then
            local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
            shown = ok and true or false
        elseif GameTooltip.SetHyperlink then
            local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. tostring(spellID))
            shown = ok and true or false
        end
    end

    if not shown then
        GameTooltip:SetText(entry.name or "Unknown", 1, 0.82, 0, 1, true)
    end

    TooltipAddBlank()
    local group = entry.groupLabel or entry.categoryLabel
    if group then
        TooltipAddDisabled(tostring(group))
    end
    if entry.enabled == false then
        TooltipAddDisabled("Tracking disabled")
    else
        TooltipAddInstruction("Tracking enabled")
    end
    if entry.pending then
        TooltipAddNormal("On cooldown")
    end

    -- Always publish plain text for Accessibility Helper tooltip keybind.
    SetAHSpeakText(BuildTrackerSpeakText(entry, itemID, spellID, isItem))
    GameTooltip:Show()
end

local function HideTrackerTooltip()
    -- Delay clearing AH speak text so the Read Tooltip keybind can still
    -- pick it up if key-down hides the tip before the binding runs.
    if C_Timer and C_Timer.After then
        local snapshot = GameTooltip and GameTooltip.AccessibilityHelperSpeakText
        C_Timer.After(0.35, function()
            if GameTooltip and GameTooltip.AccessibilityHelperSpeakText == snapshot then
                ClearAHSpeakText()
            end
        end)
    else
        ClearAHSpeakText()
    end
    if GameTooltip then
        GameTooltip:Hide()
    end
end

local function AddTrackerRow(entry, y, rowH)
    local row = CreateFrame("Frame", nil, trackerChild, "BackdropTemplate")
    row:SetSize(430, rowH - 2)
    row:SetPoint("TOPLEFT", 4, y)
    PaintSolid(row, COL_ROW[1], COL_ROW[2], COL_ROW[3], 1)

    -- Frame owner so the Blizzard tooltip can anchor to the icon corner.
    local iconFrame = CreateFrame("Frame", nil, row)
    iconFrame:SetSize(32, 32)
    iconFrame:SetPoint("LEFT", 6, 0)
    iconFrame:EnableMouse(false)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    if entry.icon then
        icon:SetTexture(entry.icon)
    else
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    if icon.SetTexCoord then
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    end

    local nameFS = FontString(row, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
    nameFS:SetPoint("LEFT", iconFrame, "RIGHT", 10, 4)
    nameFS:SetWidth(280)
    local title = entry.name or ("Spell " .. tostring(entry.spellID))
    if entry.major then
        title = title .. " *"
    end
    nameFS:SetText(title)

    local idFS = FontString(row, 11, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    idFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -1)
    local bits = {
        entry.groupLabel or entry.categoryLabel or "Combat",
        "ID " .. tostring(entry.itemID or entry.spellID or "?"),
    }
    if entry.pending then
        bits[#bits + 1] = "cooling"
    end
    idFS:SetText(table.concat(bits, "  ·  "))

    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetSize(28, 28)
    cb:SetPoint("RIGHT", -8, 0)
    cb:SetChecked(entry.enabled ~= false)
    cb:SetScript("OnClick", function(self)
        local on = self:GetChecked() and true or false
        if CA.DB and CA.DB.SetTrackerEnabled then
            CA.DB.SetTrackerEnabled(entry.key, on)
        end
        if CA.Speech and CA.Speech.Say then
            CA.Speech.Say((entry.name or "Spell") .. " tracking " .. (on and "on" or "off") .. ".", CA.Speech.PRIORITY_LOW)
        end
    end)

    local function OnRowEnter()
        PaintSolid(row, 0.16, 0.16, 0.1, 1)
        ShowTrackerTooltip(iconFrame, entry)
    end
    local function OnRowLeave()
        if row:IsMouseOver() or cb:IsMouseOver() then
            return
        end
        PaintSolid(row, COL_ROW[1], COL_ROW[2], COL_ROW[3], 1)
        HideTrackerTooltip()
    end

    row:EnableMouse(true)
    row:SetScript("OnEnter", OnRowEnter)
    row:SetScript("OnLeave", OnRowLeave)
    cb:SetScript("OnEnter", OnRowEnter)
    cb:SetScript("OnLeave", OnRowLeave)

    trackerRows[#trackerRows + 1] = row
    return y - rowH
end

local GROUP_PRIORITY = {
    teleport = 70,
    items = 65,
    toys = 60,
    racial = 50,
    pet = 45,
    combat = 40,
    general = 30,
    utility = 20,
    other = 10,
}

local function EntryDedupeSpellID(entry)
    if type(entry.spellID) == "number" and entry.spellID > 0 and not entry.itemID then
        return entry.spellID
    end
    local itemID = entry.itemID
    if type(itemID) ~= "number" then
        return nil
    end
    if C_Item and C_Item.GetItemSpell then
        local ok, a, b = pcall(C_Item.GetItemSpell, itemID)
        if ok then
            if type(a) == "number" then
                return a
            end
            if type(b) == "number" then
                return b
            end
        end
    end
    if GetItemSpell then
        local ok, spellName, spellID = pcall(GetItemSpell, itemID)
        if ok and type(spellID) == "number" then
            return spellID
        end
        if ok and type(spellName) == "number" then
            return spellName
        end
    end
    return nil
end

--- One row per spell/item identity; keep the higher-priority tab group.
local function DeduplicateTrackerList(list)
    local bestBySpell = {}
    local bestByItem = {}
    local bestByName = {}
    local order = {}

    local function unindex(entry)
        if type(entry) ~= "table" then
            return
        end
        local spellID = EntryDedupeSpellID(entry)
        if spellID and bestBySpell[spellID] == entry then
            bestBySpell[spellID] = nil
        end
        if type(entry.itemID) == "number" and bestByItem[entry.itemID] == entry then
            bestByItem[entry.itemID] = nil
        end
        local nameKey = type(entry.name) == "string" and entry.name:lower() or nil
        if nameKey and bestByName[nameKey] == entry then
            bestByName[nameKey] = nil
        end
    end

    local function index(entry)
        local spellID = EntryDedupeSpellID(entry)
        if spellID then
            bestBySpell[spellID] = entry
        end
        if type(entry.itemID) == "number" then
            bestByItem[entry.itemID] = entry
        end
        local nameKey = type(entry.name) == "string" and entry.name:lower() or nil
        if nameKey then
            bestByName[nameKey] = entry
        end
    end

    local function consider(entry)
        if type(entry) ~= "table" then
            return
        end
        local pri = GROUP_PRIORITY[entry.group] or 0
        local spellID = EntryDedupeSpellID(entry)
        local itemID = entry.itemID
        local nameKey = type(entry.name) == "string" and entry.name:lower() or nil

        local prev = (spellID and bestBySpell[spellID])
            or (type(itemID) == "number" and bestByItem[itemID])
            or (nameKey and bestByName[nameKey])
        if prev then
            local prevPri = GROUP_PRIORITY[prev.group] or 0
            if pri <= prevPri then
                return
            end
            unindex(prev)
            for i = 1, #order do
                if order[i] == prev then
                    order[i] = entry
                    break
                end
            end
        else
            order[#order + 1] = entry
        end
        index(entry)
    end

    for i = 1, #list do
        consider(list[i])
    end
    return order
end

function Settings.RefreshTrackers()
    if not trackerChild or not trackerScroll then
        return
    end
    ClearTrackerRows()
    local list = (CA.Spells and CA.Spells.GetTrackedList and CA.Spells.GetTrackedList()) or {}
    if CA.Items and CA.Items.GetTrackedList then
        local items = CA.Items.GetTrackedList() or {}
        for i = 1, #items do
            list[#list + 1] = items[i]
        end
    end
    list = DeduplicateTrackerList(list)

    local buckets
    if CA.Categories and CA.Categories.GroupEntries then
        buckets = CA.Categories.GroupEntries(list)
    else
        buckets = { other = list }
    end

    local sv = CA.DB.Get()
    local filter = sv.cooldownListFilter or "all"
    if trackerCountFS then
        if filter == "all" then
            trackerCountFS:SetText(string.format("Showing %d  ·  All groups", #list))
        else
            trackerCountFS:SetText(string.format("Showing %d  ·  %s only", #list, filter))
        end
    end

    local y = -4
    local rowH = 40
    local headerH = 26
    local order = (CA.Categories and CA.Categories.GROUP_ORDER) or { { id = "other", label = "Other" } }
    for gi = 1, #order do
        local group = order[gi]
        local bucket = buckets[group.id]
        if bucket and #bucket > 0 then
            -- Section headers only on All; single-group filters are already scoped.
            if filter == "all" then
                local header = CreateFrame("Frame", nil, trackerChild)
                header:SetSize(430, headerH)
                header:SetPoint("TOPLEFT", 4, y)
                local bg = header:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0.18, 0.16, 0.05, 1)
                local title = FontString(header, 14, COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], "OUTLINE")
                title:SetPoint("LEFT", 8, 0)
                title:SetText(string.format("%s  (%d)", group.label, #bucket))
                trackerRows[#trackerRows + 1] = header
                y = y - headerH - 2
            end

            for i = 1, #bucket do
                y = AddTrackerRow(bucket[i], y, rowH)
            end
            y = y - 6
        end
    end

    local height = math.max(40, (-y) + 16)
    trackerChild:SetHeight(height)
    if trackerScroll.UpdateScrollChildRect then
        trackerScroll:UpdateScrollChildRect()
    end
end

local function SelectTab(index)
    selectedTab = index
    for i = 1, #TABS do
        local btn = tabButtons[i]
        local panel = panels[TABS[i].id]
        if btn then
            if i == index then
                PaintSolid(btn, COL_TAB_ON[1], COL_TAB_ON[2], COL_TAB_ON[3], 1)
                if btn.label then
                    btn.label:SetTextColor(COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], 1)
                end
            else
                PaintSolid(btn, COL_TAB[1], COL_TAB[2], COL_TAB[3], 1)
                if btn.label then
                    btn.label:SetTextColor(COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], 1)
                end
            end
        end
        if panel then
            if i == index then
                panel:Show()
            else
                panel:Hide()
            end
        end
    end
    if TABS[index] and TABS[index].id == "cooldowns" then
        Settings.RefreshTrackers()
    elseif TABS[index] and TABS[index].id == "profiles" then
        Settings.RefreshProfiles()
    end
end

local function SayLow(msg)
    if CA.Speech and CA.Speech.Say then
        CA.Speech.Say(msg, CA.Speech.PRIORITY_LOW)
    end
    print("|cff66ccff[Cooldown Assist]|r " .. tostring(msg))
end

local function ClearProfileRows()
    for i = 1, #profileRows do
        profileRows[i]:Hide()
        profileRows[i]:SetParent(nil)
    end
    wipe(profileRows)
end

function Settings.RefreshProfiles()
    if not profileChild or not profileScroll then
        return
    end
    ClearProfileRows()
    local list = (CA.Profiles and CA.Profiles.List and CA.Profiles.List()) or {}
    if selectedProfileId == nil and #list > 0 then
        selectedProfileId = list[1].id
    end
    local stillExists = false
    for i = 1, #list do
        if list[i].id == selectedProfileId then
            stillExists = true
            break
        end
    end
    if not stillExists then
        selectedProfileId = list[1] and list[1].id or nil
    end

    if profileStatusFS then
        if #list == 0 then
            profileStatusFS:SetText("No saved profiles yet. Create one to store tracked cooldowns.")
        else
            local active = CA.Profiles.GetActiveId and CA.Profiles.GetActiveId()
            local activeName = "-"
            for i = 1, #list do
                if list[i].id == active then
                    activeName = list[i].name
                    break
                end
            end
            profileStatusFS:SetText(string.format("Profiles: %d  ·  Active: %s", #list, activeName))
        end
    end

    if profileNameBox then
        local p = selectedProfileId and CA.Profiles.Get and CA.Profiles.Get(selectedProfileId)
        if p and type(p.name) == "string" then
            profileNameBox:SetText(p.name)
        elseif #list == 0 then
            profileNameBox:SetText("New Profile")
        end
    end

    local y = -4
    local rowH = 36
    for i = 1, #list do
        local entry = list[i]
        local row = CreateFrame("Button", nil, profileChild, "BackdropTemplate")
        row:SetSize(430, rowH - 2)
        row:SetPoint("TOPLEFT", 4, y)
        local selected = entry.id == selectedProfileId
        PaintSolid(row, selected and COL_TAB_ON[1] or COL_ROW[1], selected and COL_TAB_ON[2] or COL_ROW[2], selected and COL_TAB_ON[3] or COL_ROW[3], 1)

        local nameFS = FontString(row, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
        nameFS:SetPoint("LEFT", 10, 4)
        nameFS:SetWidth(300)
        local suffix = entry.isActive and "  [Active]" or ""
        nameFS:SetText((entry.name or "?") .. suffix)
        if entry.isActive then
            nameFS:SetTextColor(COL_SECTION[1], COL_SECTION[2], COL_SECTION[3], 1)
        end

        local meta = FontString(row, 11, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
        meta:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -1)
        meta:SetText(string.format("%d disabled · click to select", entry.disabledCount or 0))

        row:SetScript("OnClick", function()
            selectedProfileId = entry.id
            Settings.RefreshProfiles()
        end)
        row:SetScript("OnEnter", function(self)
            PaintSolid(row, 0.22, 0.22, 0.1, 1)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:SetText(entry.name or "Profile", 1, 1, 1, 1, true)
                if entry.isActive then
                    GameTooltip:AddLine("Active profile", COL_SECTION[1], COL_SECTION[2], COL_SECTION[3])
                end
                GameTooltip:AddLine(string.format("%d trackers disabled", entry.disabledCount or 0), 0.75, 0.75, 0.75)
                GameTooltip:AddLine("Click to select this profile.", 0.55, 0.9, 0.55)
                local speak = (entry.name or "Profile")
                if entry.isActive then
                    speak = speak .. ". Active profile"
                end
                speak = speak .. ". " .. tostring(entry.disabledCount or 0) .. " trackers disabled. Click to select this profile."
                SetAHSpeakText(speak)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function()
            local on = entry.id == selectedProfileId
            PaintSolid(row, on and COL_TAB_ON[1] or COL_ROW[1], on and COL_TAB_ON[2] or COL_ROW[2], on and COL_TAB_ON[3] or COL_ROW[3], 1)
            HideTrackerTooltip()
        end)

        profileRows[#profileRows + 1] = row
        y = y - rowH
    end

    local height = math.max(40, (#list * rowH) + 8)
    profileChild:SetHeight(height)
    if profileScroll.UpdateScrollChildRect then
        profileScroll:UpdateScrollChildRect()
    end
end

local function RefreshAll()
    for i = 1, #checkboxes do
        if checkboxes[i].Refresh then
            checkboxes[i]:Refresh()
        end
    end
    for i = 1, #steppers do
        if steppers[i].Refresh then
            steppers[i].Refresh()
        end
    end
    if TABS[selectedTab] and TABS[selectedTab].id == "cooldowns" then
        RefreshFilterButtonStates()
        Settings.RefreshTrackers()
    elseif TABS[selectedTab] and TABS[selectedTab].id == "profiles" then
        Settings.RefreshProfiles()
    end
end

local function BuildGeneralPanel(parent)
    local scroll = CreateFrame("ScrollFrame", FRAME_NAME .. "GeneralScroll", parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -28, 4)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(410)
    child:SetHeight(1200)
    scroll:SetScrollChild(child)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local step = 36
        local cur = self:GetVerticalScroll() or 0
        local max = self:GetVerticalScrollRange() or 0
        local nextY = cur - (delta * step)
        if nextY < 0 then
            nextY = 0
        elseif nextY > max then
            nextY = max
        end
        self:SetVerticalScroll(nextY)
    end)

    local y = -12
    y = MakeSection(child, "General", y)
    y = MakeCheckbox(child, "Master enable (all TTS)", "masterEnable", y)
    y = MakeCheckbox(child, "Announce combat cooldowns only in combat", "announceInCombatOnly", y)
    y = MakeCheckbox(child, "Announce when a cooldown becomes ready", "announceReady", y)
    y = MakeCheckbox(child, "Announce charge gained", "announceCharges", y)
    y = MakeCheckbox(child, "Announce buff faded", "announceBuffFaded", y)
    y = MakeCheckbox(child, "Echo announcements to chat", "chatEcho", y)
    y = MakeCheckbox(child, "Show minimap button", "minimapButtonEnabled", y)
    y = MakeHint(child, "Combat CDs under 45s announce in combat. Longer CDs such as Avenging Wrath also announce when they ready between pulls. Teleports, hearth, and toys announce anytime.", y)

    y = y - 4
    y = MakeSection(child, "Spellbook & General", y)
    y = MakeCheckbox(child, "Include spellbook abilities", "includeSpellbookAbilities", y)
    y = MakeCheckbox(child, "Include spellbook racials", "includeSpellbookRacials", y)
    y = MakeCheckbox(child, "Include spellbook general (teleports, warband bank, etc.)", "includeSpellbookGeneral", y)
    y = MakeCheckbox(child, "Include pet / minion abilities", "includePetAbilities", y)
    y = MakeCheckbox(child, "Include hearthstone item", "includeHearthstone", y)
    y = MakeCheckbox(child, "Include teleport items and spells", "includeTeleportItems", y)
    y = MakeCheckbox(child, "Include toys", "includeToys", y)
    y = MakeCheckbox(child, "Toys: favorites only", "toysFavoritesOnly", y)
    y = MakeHint(child, "Toys tab lists owned toys that are not already under Teleport (or other tabs). Favorites-only shrinks that list.", y)

    y = y - 4
    y = MakeSection(child, "Equipped items & consumables", y)
    y = MakeCheckbox(child, "Include equipped trinkets", "includeTrinkets", y)
    y = MakeCheckbox(child, "Include other on-use gear", "includeOnUseGear", y)
    y = MakeCheckbox(child, "Include bag consumables", "includeCombatPotions", y)
    y = MakeCheckbox(child, "Include healthstones", "includeHealthstones", y)
    y = MakeHint(child, "Items tab: equipped on-use gear plus potions, flasks/phials, elixirs, food, bandages, and healthstones in bags (5s+ CDs).", y)

    y = y - 4
    y = MakeSection(child, "Categories", y)
    y = MakeCheckbox(child, "Track abilities", "trackCategoryAbility", y)
    y = MakeCheckbox(child, "Track utilities (racials, pet, stance, misc)", "trackCategoryUtility", y)
    y = MakeCheckbox(child, "Track general (hearthstone, teleports, toys, bank)", "trackCategoryGeneral", y)
    y = MakeCheckbox(child, "Track equipped items (trinkets / on-use gear)", "trackCategoryItem", y)
    y = MakeCheckbox(child, "Track buff fades (matched to enabled cooldowns)", "trackCategoryBuff", y)
    y = MakeHint(child, "Uncheck a category to silence that group without losing per-spell toggles. Buff fades follow enabled tracked spells/items.", y)

    y = y - 8
    y = MakeSection(child, "Text to Speech", y)
    y = MakeStepper(child, "TTS volume", "ttsVolume", y, 0, 100, 5, function(v)
        return tostring(v)
    end)
    y = MakeStepper(child, "TTS voice speed", "ttsRate", y, 0, 10, 1, function(v)
        return tostring(v)
    end)

    local voiceLabel = FontString(child, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
    voiceLabel:SetPoint("TOPLEFT", 16, y)
    voiceLabel:SetWidth(380)

    local function RefreshVoiceLabel()
        local name = "System default"
        if CA.Compat and CA.Compat.GetTtsVoiceID and CA.Compat.GetTtsVoiceName then
            name = CA.Compat.GetTtsVoiceName(CA.Compat.GetTtsVoiceID())
        end
        voiceLabel:SetText("TTS voice: " .. name)
    end
    RefreshVoiceLabel()
    steppers[#steppers + 1] = { Refresh = RefreshVoiceLabel }
    y = y - 32

    local testBtn = MakeThemeButton(child, "Test TTS", 120, 28, function()
        if CA.Speech and CA.Speech.SpeakTest then
            CA.Speech.SpeakTest()
        end
    end)
    testBtn:SetPoint("TOPLEFT", 16, y)

    local cycleBtn = MakeThemeButton(child, "Next voice", 120, 28, function()
        local voices = (CA.Compat and CA.Compat.ListTtsVoices and CA.Compat.ListTtsVoices()) or {}
        if #voices == 0 then
            return
        end
        local sv = CA.DB.Get()
        local current = CA.DB.GetSavedTtsVoiceID()
        local idx = 1
        for i = 1, #voices do
            if voices[i].voiceID == current then
                idx = i + 1
                break
            end
        end
        if idx > #voices then
            idx = 1
        end
        sv.ttsVoiceID = voices[idx].voiceID
        RefreshVoiceLabel()
        if CA.Speech and CA.Speech.PreviewSample then
            CA.Speech.PreviewSample("Cooldown Assist voice " .. voices[idx].name .. ".", CA.DB.GetTtsRate(), voices[idx].voiceID)
        end
    end)
    cycleBtn:SetPoint("LEFT", testBtn, "RIGHT", 8, 0)

    y = y - 40
    y = MakeSection(child, "About", y)
    local about = FontString(child, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    about:SetPoint("TOPLEFT", 16, y)
    about:SetWidth(380)
    about:SetJustifyH("LEFT")
    if about.SetWordWrap then
        about:SetWordWrap(true)
    end
    about:SetText("Cooldown Assist v" .. tostring(CA.VERSION or "1.1.0") .. " · Blind Mice Gaming\nAnnounces ready / charge / buff fade for tracked cooldowns. Retail + Classic.")
    local aboutH = 36
    if about.GetStringHeight then
        local measured = about:GetStringHeight()
        if type(measured) == "number" and measured > 16 then
            aboutH = measured + 8
        end
    end
    y = y - aboutH
    y = MakeSection(child, "Commands", y)
    local cmds = FontString(child, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    cmds:SetPoint("TOPLEFT", 16, y)
    cmds:SetWidth(380)
    cmds:SetText("/ca c · /ca list · /ca about · /ca profiles · /ca on|off <name> · /ca help")
    y = y - 28

    child:SetHeight(math.max(40, (-y) + 16))
end

local function RefreshFilterButtonStates()
    local sv = CA.DB.Get()
    local filter = sv.cooldownListFilter or "all"
    for i = 1, #filterButtons do
        local btn = filterButtons[i]
        SetThemeButtonSelected(btn, btn._caFilterId == filter)
    end
end

local function SetCooldownFilter(filter)
    local sv = CA.DB.Get()
    sv.cooldownListFilter = filter
    RefreshFilterButtonStates()
    Settings.RefreshTrackers()
    if CA.Speech and CA.Speech.Say then
        CA.Speech.Say("Showing " .. tostring(filter) .. ".", CA.Speech.PRIORITY_LOW)
    end
end

local function BuildCooldownsPanel(parent)
    wipe(filterButtons)
    local y = -12
    y = MakeSection(parent, "Trackable Cooldowns", y)
    trackerCountFS = FontString(parent, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    trackerCountFS:SetPoint("TOPLEFT", 16, y)
    trackerCountFS:SetWidth(300)
    trackerCountFS:SetText("Player cooldowns: 0")

    local scanBtn = MakeThemeButton(parent, "Rescan", 100, 26, function()
        local added = 0
        if CA.Spells and CA.Spells.RebuildDiscovery then
            added = CA.Spells.RebuildDiscovery() or 0
        elseif CA.Spells and CA.Spells.ScanAll then
            added = CA.Spells.ScanAll({ heavy = true }) or 0
        end
        Settings.RefreshTrackers()
        if CA.Speech and CA.Speech.Say then
            CA.Speech.Say("Discovery scan complete. " .. tostring(added) .. " tracked.", CA.Speech.PRIORITY_LOW)
        end
    end)
    scanBtn:SetPoint("TOPRIGHT", -16, -12)

    y = y - 26
    local filterLabel = FontString(parent, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    filterLabel:SetPoint("TOPLEFT", 16, y)
    filterLabel:SetText("Filter:")
    y = y - 20

    local filters = {
        { id = "all", label = "All", w = 44 },
        { id = "combat", label = "Combat", w = 60 },
        { id = "items", label = "Items", w = 52 },
        { id = "pet", label = "Pet", w = 44 },
        { id = "teleport", label = "Teleport", w = 70 },
        { id = "toys", label = "Toys", w = 48 },
        { id = "racial", label = "Racial", w = 56 },
        { id = "general", label = "General", w = 60 },
    }
    -- Two rows so the row stays inside the content panel (~430px usable).
    local rowWidth = 0
    local maxRowWidth = 330
    local prev
    for i = 1, #filters do
        local f = filters[i]
        local need = f.w + ((rowWidth > 0) and 4 or 0)
        if rowWidth > 0 and (rowWidth + need) > maxRowWidth then
            y = y - 28
            rowWidth = 0
            prev = nil
        end
        local btn = MakeThemeButton(parent, f.label, f.w, 24, function()
            SetCooldownFilter(f.id)
        end, { fontSize = 12 })
        btn._caFilterId = f.id
        if not prev then
            btn:SetPoint("TOPLEFT", 16, y)
            rowWidth = f.w
        else
            btn:SetPoint("LEFT", prev, "RIGHT", 4, 0)
            rowWidth = rowWidth + 4 + f.w
        end
        filterButtons[#filterButtons + 1] = btn
        prev = btn
    end
    RefreshFilterButtonStates()
    y = y - 28

    local hint = FontString(parent, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    hint:SetPoint("TOPLEFT", 16, y)
    hint:SetWidth(400)
    hint:SetText("Only All shows every group. Other filters are exclusive. Hover for tooltips.")
    y = y - 24

    trackerScroll = CreateFrame("ScrollFrame", FRAME_NAME .. "TrackerScroll", parent, "UIPanelScrollFrameTemplate")
    trackerScroll:SetPoint("TOPLEFT", 12, y)
    trackerScroll:SetPoint("BOTTOMRIGHT", -32, 12)
    ApplyBlackBackdrop(trackerScroll)

    trackerChild = CreateFrame("Frame", nil, trackerScroll)
    trackerChild:SetWidth(440)
    trackerChild:SetHeight(40)
    trackerScroll:SetScrollChild(trackerChild)
end

local function MakeProfileButton(parent, text, width, onClick, opts)
    return MakeThemeButton(parent, text, width or 90, 28, onClick, opts)
end

local function BuildProfilesPanel(parent)
    local y = -12
    y = MakeSection(parent, "Saved Profiles", y)
    profileStatusFS = FontString(parent, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    profileStatusFS:SetPoint("TOPLEFT", 16, y)
    profileStatusFS:SetWidth(420)
    profileStatusFS:SetText("No saved profiles yet.")
    y = y - 24

    local nameLabel = FontString(parent, 13, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
    nameLabel:SetPoint("TOPLEFT", 16, y)
    nameLabel:SetText("Profile name")
    y = y - 22

    profileNameBox = CreateFrame("EditBox", FRAME_NAME .. "ProfileName", parent, "InputBoxTemplate")
    profileNameBox:SetSize(220, 24)
    profileNameBox:SetPoint("TOPLEFT", 20, y)
    profileNameBox:SetAutoFocus(false)
    profileNameBox:SetMaxLetters(40)
    profileNameBox:SetText("New Profile")

    local function DoRename()
        if not selectedProfileId then
            SayLow("Select a profile first.")
            return
        end
        local nameText = profileNameBox and profileNameBox:GetText() or ""
        local ok, name = CA.Profiles.Rename(selectedProfileId, nameText)
        if ok then
            SayLow("Renamed profile to " .. tostring(name) .. ".")
            Settings.RefreshProfiles()
        else
            SayLow("Could not rename profile. Enter a name first.")
        end
    end

    local renameBtn = MakeProfileButton(parent, "Rename", 90, DoRename)
    renameBtn:SetPoint("LEFT", profileNameBox, "RIGHT", 10, 0)

    profileNameBox:SetScript("OnEnterPressed", function(self)
        DoRename()
        self:ClearFocus()
    end)
    profileNameBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    y = y - 36

    local btnY = y
    local newBtn = MakeProfileButton(parent, "New", 80, function()
        local name = profileNameBox and profileNameBox:GetText() or "New Profile"
        local id, createdName = CA.Profiles.Create(name, true)
        if id then
            selectedProfileId = id
            SayLow("Created profile " .. tostring(createdName) .. ".")
            Settings.RefreshProfiles()
            Settings.RefreshTrackers()
        end
    end)
    newBtn:SetPoint("TOPLEFT", 16, btnY)

    local saveBtn = MakeProfileButton(parent, "Save", 80, function()
        if not selectedProfileId then
            SayLow("Select or create a profile first.")
            return
        end
        local ok, name = CA.Profiles.SaveCurrent(selectedProfileId)
        if ok then
            SayLow("Saved tracking to profile " .. tostring(name) .. ".")
            Settings.RefreshProfiles()
        else
            SayLow("Could not save profile.")
        end
    end)
    saveBtn:SetPoint("LEFT", newBtn, "RIGHT", 6, 0)

    local loadBtn = MakeProfileButton(parent, "Load", 80, function()
        if not selectedProfileId then
            SayLow("Select a profile first.")
            return
        end
        local ok, name = CA.Profiles.Load(selectedProfileId)
        if ok then
            SayLow("Loaded profile " .. tostring(name) .. ".")
            Settings.RefreshProfiles()
            Settings.RefreshTrackers()
        else
            SayLow("Could not load profile.")
        end
    end)
    loadBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)

    local copyBtn = MakeProfileButton(parent, "Copy", 80, function()
        if not selectedProfileId then
            SayLow("Select a profile first.")
            return
        end
        local nameText = profileNameBox and profileNameBox:GetText() or ""
        local id, copyName = CA.Profiles.Copy(selectedProfileId, nameText ~= "" and (nameText .. " Copy") or nil)
        if id then
            selectedProfileId = id
            SayLow("Copied profile " .. tostring(copyName) .. ".")
            Settings.RefreshProfiles()
        else
            SayLow("Could not copy profile.")
        end
    end)
    copyBtn:SetPoint("LEFT", loadBtn, "RIGHT", 6, 0)

    local deleteBtn = MakeProfileButton(parent, "Delete", 80, function()
        if not selectedProfileId then
            SayLow("Select a profile first.")
            return
        end
        local ok, name = CA.Profiles.Delete(selectedProfileId)
        if ok then
            selectedProfileId = CA.Profiles.GetActiveId and CA.Profiles.GetActiveId() or nil
            SayLow("Deleted profile " .. tostring(name or "") .. ".")
            Settings.RefreshProfiles()
        else
            SayLow("Could not delete profile.")
        end
    end, { danger = true })
    deleteBtn:SetPoint("TOPLEFT", 16, btnY - 32)

    y = btnY - 70
    local listHint = FontString(parent, 12, COL_HINT[1], COL_HINT[2], COL_HINT[3], "OUTLINE")
    listHint:SetPoint("TOPLEFT", 16, y)
    listHint:SetWidth(420)
    listHint:SetText("Select a profile, edit the name, press Rename (or Enter). Then Load / Save / Copy / Delete.")
    y = y - 22

    profileScroll = CreateFrame("ScrollFrame", FRAME_NAME .. "ProfileScroll", parent, "UIPanelScrollFrameTemplate")
    profileScroll:SetPoint("TOPLEFT", 12, y)
    profileScroll:SetPoint("BOTTOMRIGHT", -32, 12)
    ApplyBlackBackdrop(profileScroll)

    profileChild = CreateFrame("Frame", nil, profileScroll)
    profileChild:SetWidth(440)
    profileChild:SetHeight(40)
    profileScroll:SetScrollChild(profileChild)
end

local function Build()
    -- Rebuild if an older frame without Profiles tab exists.
    if built and frame and frame._caUI == 21 then
        return frame
    end
    if frame then
        frame:Hide()
        frame:SetParent(nil)
        frame = nil
    end
    wipe(checkboxes)
    wipe(steppers)
    wipe(tabButtons)
    wipe(panels)
    wipe(trackerRows)
    wipe(profileRows)
    trackerScroll = nil
    trackerChild = nil
    trackerCountFS = nil
    profileScroll = nil
    profileChild = nil
    profileNameBox = nil
    profileStatusFS = nil

    frame = CreateFrame("Frame", FRAME_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(640, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    frame._caHasTabs = true
    frame._caHasProfiles = true
    frame._caUI = 21
    ApplyBlackBackdrop(frame)
    local alreadySpecial = false
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == FRAME_NAME then
            alreadySpecial = true
            break
        end
    end
    if not alreadySpecial then
        tinsert(UISpecialFrames, FRAME_NAME)
    end

    local function ApplyIconTexture(tex)
        tex:SetTexture(ICON_PATH)
        if not tex:GetTexture() then
            tex:SetTexture(ICON_PATH_FALLBACK)
        end
        if tex.SetTexCoord then
            tex:SetTexCoord(0, 1, 0, 1)
        end
    end

    local headerIcon = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    headerIcon:SetSize(56, 56)
    headerIcon:SetPoint("TOP", frame, "TOP", 0, -10)
    ApplyIconTexture(headerIcon)

    local title = FontString(frame, 18, COL_TITLE[1], COL_TITLE[2], COL_TITLE[3], "OUTLINE")
    title:SetPoint("TOPLEFT", 14, -18)
    title:SetText("Cooldown Assist")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)
    close:SetFrameLevel(frame:GetFrameLevel() + 5)

    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 12, -72)
    tabBar:SetSize(140, 460)

    local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", 160, -72)
    content:SetPoint("BOTTOMRIGHT", -14, 14)
    ApplyBlackBackdrop(content)

    for i = 1, #TABS do
        local tab = TABS[i]
        local btn = CreateFrame("Button", nil, tabBar, "BackdropTemplate")
        btn:SetSize(140, 36)
        btn:SetPoint("TOPLEFT", 0, -((i - 1) * 40))
        PaintSolid(btn, COL_TAB[1], COL_TAB[2], COL_TAB[3], 1)
        local label = FontString(btn, 14, COL_LABEL[1], COL_LABEL[2], COL_LABEL[3], "OUTLINE")
        label:SetPoint("LEFT", 12, 0)
        label:SetText(tab.label)
        btn.label = label
        btn:SetScript("OnClick", function()
            SelectTab(i)
            if CA.Speech and CA.Speech.Say then
                CA.Speech.Say(tab.label .. " tab.", CA.Speech.PRIORITY_LOW)
            end
        end)
        tabButtons[i] = btn

        local panel = CreateFrame("Frame", nil, content)
        panel:SetAllPoints()
        panel:Hide()
        panels[tab.id] = panel
    end

    BuildGeneralPanel(panels.general)
    BuildCooldownsPanel(panels.cooldowns)
    BuildProfilesPanel(panels.profiles)

    frame:SetScript("OnShow", function()
        SelectTab(selectedTab)
        RefreshAll()
    end)

    built = true
    SelectTab(1)
    return frame
end

function Settings.IsShown()
    return frame and frame:IsShown() and true or false
end

function Settings.Toggle()
    local f = Build()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

function Settings.Open()
    local f = Build()
    f:Show()
end

function Settings.Close()
    if frame then
        frame:Hide()
    end
end

function Settings.OpenCooldownsTab()
    local f = Build()
    SelectTab(2)
    f:Show()
end

function Settings.OpenProfilesTab()
    local f = Build()
    SelectTab(3)
    f:Show()
end
