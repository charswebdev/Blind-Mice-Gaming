local _, LPL = ...

LPL.AddonSetAPI = LPL.AddonSetAPI or {}
local API = LPL.AddonSetAPI

local KEY = "addonsets"

local function AddonCount()
    if C_AddOns and C_AddOns.GetNumAddOns then
        local ok, count = pcall(C_AddOns.GetNumAddOns)
        return ok and (LPL:PlainNumber(count) or 0) or 0
    end
    if GetNumAddOns then
        local ok, count = pcall(GetNumAddOns)
        return ok and (LPL:PlainNumber(count) or 0) or 0
    end
    return 0
end

local function AddonInfo(index)
    local name, title, security
    if C_AddOns and C_AddOns.GetAddOnInfo then
        local ok, a, b, _, _, _, s = pcall(C_AddOns.GetAddOnInfo, index)
        if ok then
            name, title, security = a, b, s
        end
    elseif GetAddOnInfo then
        local ok, a, b, _, _, _, s = pcall(GetAddOnInfo, index)
        if ok then
            name, title, security = a, b, s
        end
    end
    local plainName = LPL:PlainString(name)
    if not plainName then
        return nil
    end
    return {
        name = plainName,
        title = (type(title) == "string" and title) or plainName,
        protected = security == "SECURE" or plainName == "lpl-forever" or plainName:match("^Blizzard_") ~= nil,
    }
end

local function IsEnabled(name)
    local function Read(caller, a, b)
        if not caller then
            return nil
        end
        local ok, state = pcall(caller, a, b)
        if not ok then
            return nil
        end
        return LPL:PlainNumber(state)
    end
    local state
    if C_AddOns and C_AddOns.GetAddOnEnableState then
        state = Read(C_AddOns.GetAddOnEnableState, name)
        if state == nil then
            local character = UnitName and UnitName("player") or nil
            state = Read(C_AddOns.GetAddOnEnableState, name, character) or Read(C_AddOns.GetAddOnEnableState, character, name)
        end
    end
    if state == nil and GetAddOnEnableState then
        local character = UnitName and UnitName("player") or nil
        state = Read(GetAddOnEnableState, character, name) or Read(GetAddOnEnableState, name)
    end
    if state == nil then
        return false
    end
    local enabledValue = Enum and Enum.AddOnEnableState and LPL:PlainNumber(Enum.AddOnEnableState.Enabled)
    if enabledValue then
        return state == enabledValue
    end
    return state > 0
end

local CATEGORY_RANK = {
    ["Action Bars"] = 1,
    ["Auction & Economy"] = 2,
    ["Bags & Inventory"] = 3,
    ["Chat"] = 4,
    ["Class"] = 5,
    ["Combat"] = 6,
    ["Companions"] = 7,
    ["Development Tools"] = 8,
    ["Guild"] = 9,
    ["Map"] = 10,
    ["Minigames"] = 11,
    ["Miscellaneous"] = 12,
    ["Plugins"] = 13,
    ["Professions"] = 14,
    ["PvP"] = 15,
    ["Quests & Achievements"] = 16,
    ["Raid"] = 17,
    ["Roleplay"] = 18,
    ["Unit Frames"] = 19,
}

local function Metadata(name, key)
    local function Read(fn)
        if not fn then
            return nil
        end
        local ok, value = pcall(fn, name, key)
        if not ok then
            return nil
        end
        return LPL:PlainString(value)
    end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local value = Read(C_AddOns.GetAddOnMetadata)
        if value then
            return value
        end
    end
    if GetAddOnMetadata then
        return Read(GetAddOnMetadata)
    end
    return nil
end

local function Dependencies(name)
    local deps = {}
    local function Take(packed)
        if not packed[1] then
            return
        end
        for i = 2, #packed do
            local dep = LPL:PlainString(packed[i])
            if dep and dep ~= name then
                deps[#deps + 1] = dep
            end
        end
    end
    if C_AddOns and C_AddOns.GetAddOnDependencies then
        Take({ pcall(C_AddOns.GetAddOnDependencies, name) })
    end
    if #deps == 0 and GetAddOnDependencies then
        Take({ pcall(GetAddOnDependencies, name) })
    end
    return deps
end

local function Installed()
    local out = {}
    local byName = {}
    local count = AddonCount()
    for i = 1, count do
        local info = AddonInfo(i)
        if info then
            info.enabled = IsEnabled(info.name)
            info.category = Metadata(info.name, "Category") or "Other"
            info.group = Metadata(info.name, "Group")
            info.deps = Dependencies(info.name)
            out[#out + 1] = info
            byName[info.name] = info
        end
    end
    for i = 1, #out do
        local info = out[i]
        local parent
        if info.group and byName[info.group] and info.group ~= info.name then
            parent = info.group
        elseif info.deps and #info.deps == 1 and byName[info.deps[1]] then
            parent = info.deps[1]
        end
        if parent and byName[parent] and byName[parent].group == info.name then
            parent = nil
        end
        info.parent = parent
    end
    return out, byName
end

local function CategoryRank(name)
    if name == "Other" then
        return 10000
    end
    return CATEGORY_RANK[name] or 5000
end

local function TitleSort(info)
    local title = info and LPL:PlainString(info.title) or nil
    if title then
        title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        return title:lower()
    end
    return (info and info.name or ""):lower()
end

local function DisplayEntries(collapsed)
    local installed, byName = Installed()
    local children = {}
    local rootsByCategory = {}
    for i = 1, #installed do
        local info = installed[i]
        if info.parent and byName[info.parent] then
            local kids = children[info.parent]
            if not kids then
                kids = {}
                children[info.parent] = kids
            end
            kids[#kids + 1] = info
        else
            local category = info.category or "Other"
            local roots = rootsByCategory[category]
            if not roots then
                roots = {}
                rootsByCategory[category] = roots
            end
            roots[#roots + 1] = info
        end
    end
    for _, kids in pairs(children) do
        table.sort(kids, function(a, b)
            return TitleSort(a) < TitleSort(b)
        end)
    end
    local categories = {}
    for category in pairs(rootsByCategory) do
        categories[#categories + 1] = category
    end
    table.sort(categories, function(a, b)
        local ra, rb = CategoryRank(a), CategoryRank(b)
        if ra ~= rb then
            return ra < rb
        end
        return a:lower() < b:lower()
    end)
    local entries = {}
    local function Push(info, depth)
        entries[#entries + 1] = {
            kind = "addon",
            depth = depth or 0,
            info = info,
        }
        local kids = children[info.name]
        if kids then
            for n = 1, #kids do
                Push(kids[n], (depth or 0) + 1)
            end
        end
    end
    for i = 1, #categories do
        local category = categories[i]
        local roots = rootsByCategory[category]
        table.sort(roots, function(a, b)
            return TitleSort(a) < TitleSort(b)
        end)
        entries[#entries + 1] = {
            kind = "header",
            category = category,
            collapsed = collapsed and collapsed[category] == true,
        }
        if not (collapsed and collapsed[category]) then
            for n = 1, #roots do
                Push(roots[n], 0)
            end
        end
    end
    return entries
end

local function CopyNames(list)
    local out = {}
    local seen = {}
    if type(list) ~= "table" then
        return out
    end
    for i = 1, #list do
        local name = LPL:PlainString(list[i])
        if name and not seen[name] then
            seen[name] = true
            out[#out + 1] = name
        end
    end
    table.sort(out)
    return out
end

local function HasName(list, name)
    for i = 1, #list do
        if list[i] == name then
            return true
        end
    end
    return false
end

function API:Available()
    return AddonCount() > 0 or (C_AddOns and C_AddOns.GetNumAddOns ~= nil) or GetNumAddOns ~= nil
end

function API:List()
    return LPL.SetStore:List(KEY)
end

function API:Get(id)
    return LPL.SetStore:Get(KEY, id)
end

function API:SuggestName()
    return LPL.SetStore:SuggestName(KEY, "Addons")
end

function API:Empty()
    return {
        name = self:SuggestName(),
        addons = {},
    }
end

function API:Summary(set)
    local count = #(CopyNames(set and set.addons))
    if count == 1 then
        return "1 addon"
    end
    return tostring(count) .. " addons"
end

function API:Capture()
    local names = {}
    local installed = Installed()
    for i = 1, #installed do
        if installed[i].enabled and not installed[i].protected then
            names[#names + 1] = installed[i].name
        end
    end
    return { addons = names }
end

function API:ApplyCapture(draft, live)
    draft.addons = CopyNames(live and live.addons)
end

function API:Matches(set, live)
    live = live or self:Capture()
    local saved = CopyNames(set and set.addons)
    local current = CopyNames(live and live.addons)
    if #saved ~= #current then
        return false
    end
    for i = 1, #saved do
        if saved[i] ~= current[i] then
            return false
        end
    end
    return true
end

local function RecordFrom(draft)
    return { addons = CopyNames(draft and draft.addons) }
end

function API:Save(draft, name)
    return LPL.SetStore:Save(KEY, RecordFrom(draft), name, self:SuggestName())
end

function API:Update(id, draft, name)
    return LPL.SetStore:Update(KEY, id, RecordFrom(draft), name, "Addons")
end

function API:Delete(id)
    return LPL.SetStore:Delete(KEY, id)
end

local function SetEnabled(name, enabled)
    if enabled then
        if C_AddOns and C_AddOns.EnableAddOn then
            if pcall(C_AddOns.EnableAddOn, name) then
                return
            end
        end
        if EnableAddOn then
            pcall(EnableAddOn, name)
        end
        return
    end
    if C_AddOns and C_AddOns.DisableAddOn then
        if pcall(C_AddOns.DisableAddOn, name) then
            return
        end
    end
    if DisableAddOn then
        pcall(DisableAddOn, name)
    end
end

function API:Apply(set)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Leave combat, then apply this addon set."
    end
    local wanted = {}
    local names = CopyNames(set and set.addons)
    for i = 1, #names do
        wanted[names[i]] = true
    end
    local installed = Installed()
    local enabled, disabled = 0, 0
    for i = 1, #installed do
        local info = installed[i]
        if info.protected then
            -- Blizzard addons and this addon stay as they are.
        elseif wanted[info.name] then
            SetEnabled(info.name, true)
            enabled = enabled + 1
        else
            SetEnabled(info.name, false)
            disabled = disabled + 1
        end
    end
    if C_AddOns and C_AddOns.SaveAddOns then
        pcall(C_AddOns.SaveAddOns)
    elseif SaveAddOns then
        pcall(SaveAddOns)
    end
    if not StaticPopupDialogs["LPL_FOREVER_RELOAD"] then
        StaticPopupDialogs["LPL_FOREVER_RELOAD"] = {
            text = "Addon set applied. Reload the UI to finish?",
            button1 = "Reload",
            button2 = "Later",
            OnAccept = function()
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    if StaticPopup_Show then
        pcall(StaticPopup_Show, "LPL_FOREVER_RELOAD")
    end
    return true, "Enabled " .. enabled .. " addons and turned " .. disabled .. " off. Reload to finish."
end

function API:DrawEditor(page, draftSet, refresh)
    local panel = page.addonSetPanel
    if not panel then
        panel = CreateFrame("Frame", nil, page.editorChild)
        panel:SetPoint("TOPLEFT", 8, -8)
        panel.rows = {}
        page.addonSetPanel = panel
    end
    page.addonCollapsed = page.addonCollapsed or {}
    draftSet.addons = CopyNames(draftSet.addons)
    local entries = DisplayEntries(page.addonCollapsed)
    local width = math.max(520, (page.editorScroll:GetWidth() or 640) - 24)
    for i = 1, #entries do
        local row = panel.rows[i]
        if not row then
            row = CreateFrame("Button", nil, panel, "BackdropTemplate")
            row:SetHeight(26)
            row.expand = row:CreateTexture(nil, "ARTWORK")
            row.expand:SetSize(14, 14)
            row.expand:SetPoint("LEFT", 8, 0)
            row.box = row:CreateTexture(nil, "ARTWORK")
            row.box:SetSize(14, 14)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.label:SetPoint("RIGHT", -8, 0)
            row.label:SetJustifyH("LEFT")
            panel.rows[i] = row
        end
        local entry = entries[i]
        row:SetWidth(width)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -((i - 1) * 28))
        row:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        if entry.kind == "header" then
            row:SetBackdropColor(0.14, 0.14, 0.16, 1)
            row:SetBackdropBorderColor(0.25, 0.27, 0.32, 1)
            row.expand:SetTexture(entry.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
            row.expand:Show()
            row.box:Hide()
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", 28, 0)
            row.label:SetPoint("RIGHT", -8, 0)
            row.label:SetText(entry.category)
            row.label:SetTextColor(1, 0.92, 0.40)
            local category = entry.category
            row:SetScript("OnClick", function()
                if page.addonCollapsed[category] then
                    page.addonCollapsed[category] = nil
                else
                    page.addonCollapsed[category] = true
                end
                refresh()
            end)
        else
            local info = entry.info
            local indent = (entry.depth or 0) * 18
            local on = HasName(draftSet.addons, info.name)
            row:SetBackdropColor(0, 0, 0, 1)
            row:SetBackdropBorderColor(0.25, 0.27, 0.32, 1)
            row.expand:Hide()
            row.box:Show()
            row.box:ClearAllPoints()
            row.box:SetPoint("LEFT", 8 + indent, 0)
            row.box:SetColorTexture(on and 1 or 0.2, on and 0.92 or 0.2, on and 0.40 or 0.2, 1)
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row.box, "RIGHT", 8, 0)
            row.label:SetPoint("RIGHT", -8, 0)
            if type(info.title) == "string" then
                row.label:SetText(info.title)
            else
                row.label:SetText(info.name)
            end
            if info.protected then
                row.label:SetTextColor(0.55, 0.55, 0.55)
                row:SetScript("OnClick", function() end)
            else
                row.label:SetTextColor(0.95, 0.95, 0.97)
                local addonName = info.name
                row:SetScript("OnClick", function()
                    local list = CopyNames(draftSet.addons)
                    local nextList = {}
                    local removed = false
                    for n = 1, #list do
                        if list[n] == addonName then
                            removed = true
                        else
                            nextList[#nextList + 1] = list[n]
                        end
                    end
                    if not removed then
                        nextList[#nextList + 1] = addonName
                    end
                    draftSet.addons = nextList
                    refresh()
                end)
            end
        end
        row:Show()
    end
    for i = #entries + 1, #panel.rows do
        panel.rows[i]:Hide()
    end
    local height = math.max(40, #entries * 28)
    panel:SetSize(width, height)
    panel:Show()
    page.editorChild:SetWidth(width + 16)
    page.editorChild:SetHeight(height + 16)
end
