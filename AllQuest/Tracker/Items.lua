--[[
  AllQuest — combat-safe quest item buttons (SecureActionButtonTemplate)
  Buttons sit in a column outside the tracker (Kaliel-style), not inside rows.
  Attributes and anchors are never changed in combat.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Items = AQ.Items or {}
local Items = AQ.Items

local SIZE = 26
local EXTRA_SIZE = 36
local GAP = 3
local OUTER = 4

local column
local extra
local extraPending
local byQuest = {}
local pendingList
local pendingAnchor

local function InCombat()
    return AQ.Compat.InCombat()
end

local function ItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    local id = link:match("item:(%d+)")
    return tonumber(id)
end

local function EnsureColumn(tracker)
    if column then
        if tracker and column:GetParent() ~= tracker then
            if not InCombat() then
                column:SetParent(tracker)
            end
        end
        return column
    end
    if not tracker then
        return nil
    end
    column = CreateFrame("Frame", "AllQuestItemColumn", tracker)
    column:SetSize(EXTRA_SIZE, EXTRA_SIZE)
    column:SetPoint("TOPLEFT", tracker, "TOPRIGHT", OUTER, 0)
    column:Hide()
    return column
end

local function SkinButton(btn)
    if not btn then
        return
    end
    if not AQ.MasqueGroup or not AQ.Plugins or not AQ.Plugins.IsEnabled("Masque") then
        return
    end
    if btn.AQMasqued then
        return
    end
    pcall(function()
        AQ.MasqueGroup:AddButton(btn, { Icon = btn.Icon })
        btn.AQMasqued = true
    end)
end

local function UnskinButton(btn)
    if not btn or not btn.AQMasqued then
        return
    end
    if AQ.MasqueGroup and AQ.MasqueGroup.RemoveButton then
        pcall(AQ.MasqueGroup.RemoveButton, AQ.MasqueGroup, btn)
    end
    btn.AQMasqued = nil
end

local function MakeButton(name, parent, size)
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(size or SIZE, size or SIZE)

    local icon = btn:CreateTexture(nil, "BORDER")
    icon:SetAllPoints()
    btn.Icon = icon

    btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    local normal = btn:GetNormalTexture()
    if normal then
        normal:ClearAllPoints()
        normal:SetPoint("CENTER")
        local glow = (size or SIZE) + 18
        normal:SetSize(glow, glow)
    end
    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    local count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", icon, 1, 1)
    count:SetJustifyH("RIGHT")
    btn.Count = count

    local num = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    num:SetPoint("TOPLEFT", icon, 1, -1)
    num:SetTextColor(1, 0.82, 0, 1)
    btn.IndexText = num

    local cd
    local ok, created = pcall(CreateFrame, "Cooldown", nil, btn, "CooldownFrameTemplate")
    if ok then
        cd = created
    else
        cd = CreateFrame("Frame", nil, btn)
    end
    cd:SetAllPoints()
    if cd.SetDrawEdge then
        cd:SetDrawEdge(false)
    end
    btn.Cooldown = cd

    if btn.RegisterForClicks then
        pcall(btn.RegisterForClicks, btn, "AnyUp", "AnyDown")
    end

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        if self.logIndex and GameTooltip.SetQuestLogSpecialItem then
            pcall(GameTooltip.SetQuestLogSpecialItem, GameTooltip, self.logIndex)
        elseif type(self.link) == "string" then
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.link)
        elseif self.isExtra then
            GameTooltip:AddLine("Closest quest item", 1, 0.92, 0.4)
        end
        GameTooltip:Show()
        local spoken
        if self.isExtra then
            spoken = "Closest quest item"
        else
            local name
            if type(self.link) == "string" then
                name = self.link:match("%[(.-)%]")
            end
            if type(name) == "string" and name ~= "" then
                spoken = "Quest item " .. name
            elseif self.IndexText and self.IndexText:GetText() ~= "" then
                spoken = "Quest item " .. self.IndexText:GetText()
            else
                spoken = "Quest item"
            end
        end
        if AQ.Speech and AQ.Speech.Replace then
            AQ.Speech.Replace(spoken)
        elseif AQ.Speech then
            AQ.Speech.Say(spoken)
        end
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    SkinButton(btn)
    return btn
end

local function SetCharges(btn, charges)
    if not btn.Count then
        return
    end
    if type(charges) == "number" and charges > 1 then
        btn.Count:SetText(tostring(charges))
        btn.Count:Show()
    else
        btn.Count:SetText("")
        btn.Count:Hide()
    end
end

local function SetCooldown(btn, link)
    if not btn.Cooldown then
        return
    end
    local id = ItemIDFromLink(link)
    if not id then
        return
    end
    local start, duration, enable
    if C_Container and C_Container.GetItemCooldown then
        start, duration, enable = AQ:SafeCall(C_Container.GetItemCooldown, id)
    elseif GetItemCooldown then
        start, duration, enable = AQ:SafeCall(GetItemCooldown, id)
    end
    if start and duration and duration > 0 and CooldownFrame_Set then
        pcall(CooldownFrame_Set, btn.Cooldown, start, duration, enable or 1)
    elseif btn.Cooldown.SetCooldown and start and duration then
        pcall(btn.Cooldown.SetCooldown, btn.Cooldown, start, duration)
    end
end

local function ApplyItem(btn, spec)
    if not btn then
        return
    end
    if type(spec) ~= "table" or type(spec.link) ~= "string" or spec.link == "" then
        if not InCombat() then
            btn:SetAttribute("type", nil)
            btn:SetAttribute("item", nil)
            btn:Hide()
        end
        return
    end
    if not InCombat() then
        btn:SetAttribute("type", "item")
        btn:SetAttribute("item", spec.link)
        if spec.logIndex then
            btn:SetAttribute("questLogIndex", spec.logIndex)
        end
        if spec.questID then
            btn:SetAttribute("questID", spec.questID)
        end
        btn:Show()
    end
    btn.link = spec.link
    btn.logIndex = spec.logIndex
    btn.questID = spec.questID
    local tex = spec.texture
    local id = ItemIDFromLink(spec.link)
    if not tex and id and GetItemIcon then
        tex = GetItemIcon(id)
    end
    if not tex and C_Item and C_Item.GetItemIconByID and id then
        tex = C_Item.GetItemIconByID(id)
    end
    if btn.Icon then
        btn.Icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    SetCharges(btn, spec.charges)
    SetCooldown(btn, spec.link)
    if btn.IndexText then
        if spec.index then
            btn.IndexText:SetText(tostring(spec.index))
        else
            btn.IndexText:SetText("")
        end
    end
end

local function AcquireQuestButton(questID)
    local btn = byQuest[questID]
    if btn then
        return btn
    end
    if InCombat() then
        return nil
    end
    local parent = EnsureColumn(AQ.Tracker and AQ.Tracker.GetFrame and AQ.Tracker.GetFrame())
    if not parent then
        return nil
    end
    btn = MakeButton("AllQuestItemButton" .. tostring(questID), parent, SIZE)
    byQuest[questID] = btn
    return btn
end

local function HideUnused(keep)
    if InCombat() then
        return
    end
    for questID, btn in pairs(byQuest) do
        if not keep[questID] then
            btn:SetAttribute("type", nil)
            btn:SetAttribute("item", nil)
            btn:Hide()
            btn:ClearAllPoints()
        end
    end
end

function Items.AnchorColumn(tracker)
    tracker = tracker or (AQ.Tracker and AQ.Tracker.GetFrame and AQ.Tracker.GetFrame())
    if not tracker then
        return
    end
    local col = EnsureColumn(tracker)
    if not col then
        return
    end
    if InCombat() then
        pendingAnchor = true
        return
    end
    col:ClearAllPoints()
    local right = tracker:GetRight()
    local uiRight = UIParent and UIParent:GetRight()
    if right and uiRight and (uiRight - right) < (EXTRA_SIZE + OUTER + 8) then
        col:SetPoint("TOPRIGHT", tracker, "TOPLEFT", -OUTER, 0)
    else
        col:SetPoint("TOPLEFT", tracker, "TOPRIGHT", OUTER, 0)
    end
end

function Items.UpdateColumn(list, extraLink)
    local tracker = AQ.Tracker and AQ.Tracker.GetFrame and AQ.Tracker.GetFrame()
    if not tracker then
        return
    end
    if InCombat() then
        pendingList = { list = list, extraLink = extraLink }
        return
    end
    pendingList = nil
    local col = EnsureColumn(tracker)
    if not col then
        return
    end

    local showItems = AQ.DB.Get().trackerShowItemButtons ~= false
    local showExtra = AQ.DB.Get().trackerShowClosestItem ~= false
    local collapsed = tracker.Scroll and not tracker.Scroll:IsShown()
    local hidden = not tracker:IsShown()

    if hidden or collapsed or ((not showItems or not list or #list == 0) and (not showExtra or type(extraLink) ~= "string")) then
        if extra then
            ApplyItem(extra, nil)
            ClearOverrideBindings(extra)
        end
        HideUnused({})
        col:Hide()
        return
    end

    Items.AnchorColumn(tracker)
    col:Show()

    local y = 0
    if showExtra and type(extraLink) == "string" then
        if not extra then
            extra = MakeButton("AllQuestExtraItemButton", col, EXTRA_SIZE)
            extra.isExtra = true
        end
        extra:ClearAllPoints()
        extra:SetPoint("TOP", col, "TOP", 0, 0)
        ApplyItem(extra, { link = extraLink, index = nil })
        ClearOverrideBindings(extra)
        local key = GetBindingKey and GetBindingKey("EXTRAACTIONBUTTON1")
        if key then
            SetOverrideBindingClick(extra, false, key, extra:GetName())
        end
        y = EXTRA_SIZE + GAP
    elseif extra then
        ApplyItem(extra, nil)
        ClearOverrideBindings(extra)
    end

    local keep = {}
    if showItems and type(list) == "table" then
        for i = 1, #list do
            local spec = list[i]
            if type(spec) == "table" and spec.questID and spec.link then
                keep[spec.questID] = true
                local btn = AcquireQuestButton(spec.questID)
                if btn then
                    spec.index = spec.index or i
                    ApplyItem(btn, spec)
                    btn:ClearAllPoints()
                    btn:SetPoint("TOP", col, "TOP", 0, -y)
                    y = y + SIZE + GAP
                end
            end
        end
    end
    HideUnused(keep)
    col:SetSize(EXTRA_SIZE, math.max(y - GAP, EXTRA_SIZE))
end

function Items.ReleaseAll()
    -- Kept for callers; column layout owns buttons now.
    if InCombat() then
        return
    end
    HideUnused({})
end

function Items.Acquire(parent)
    return Items.EnsureExtra(parent)
end

function Items.SetItem(btn, link)
    ApplyItem(btn, type(link) == "string" and { link = link } or nil)
end

function Items.EnsureExtra(parent)
    EnsureColumn(parent)
    if extra then
        return extra
    end
    extra = MakeButton("AllQuestExtraItemButton", column or parent, EXTRA_SIZE)
    extra.isExtra = true
    extra:Hide()
    return extra
end

function Items.SetExtraItem(link)
    extraPending = link
end

function Items.PeekExtra()
    return extraPending
end

function Items.FlushPending()
    if InCombat() then
        return
    end
    if pendingList then
        Items.UpdateColumn(pendingList.list, pendingList.extraLink)
        pendingList = nil
    end
    if pendingAnchor then
        pendingAnchor = nil
        Items.AnchorColumn()
    end
end

function Items.SkinWithMasque()
    SkinButton(extra)
    for _, btn in pairs(byQuest) do
        SkinButton(btn)
    end
    if AQ.MasqueGroup and AQ.MasqueGroup.ReSkin then
        pcall(AQ.MasqueGroup.ReSkin, AQ.MasqueGroup)
    end
end

function Items.UnskinMasque()
    UnskinButton(extra)
    for _, btn in pairs(byQuest) do
        UnskinButton(btn)
    end
end

AQ.Events.Register("PLAYER_REGEN_ENABLED", function()
    Items.FlushPending()
end)
