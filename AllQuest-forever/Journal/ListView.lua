--[[
  AllQuest — journal browser (cover gallery + chain list)
  Keyboard + TTS first. Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Journal = AQ.Journal or {}
local ListView = {}
AQ.Journal.ListView = ListView

local stack = {} -- { {kind, id, name} }
local items = {}
local focused = 1
local rowFrames = {}
local cardFrames = {}
local searchQuery = ""

local function Frame()
    return AQ.Journal.GetFrame()
end

local function DB()
    return AQ.DB.Get()
end

local function RestrictionLabel(chain)
    local r = chain.restrictions
    if type(r) ~= "table" then
        return ""
    end
    local parts = {}
    if type(r.faction) == "string" and r.faction ~= "" then
        parts[#parts + 1] = r.faction
    end
    if type(r.class) == "string" and r.class ~= "" then
        parts[#parts + 1] = r.class
    elseif type(r.classes) == "table" and #r.classes > 0 then
        parts[#parts + 1] = table.concat(r.classes, "/")
    end
    if #parts == 0 then
        return ""
    end
    return " " .. table.concat(parts, " ")
end

local function Current()
    return stack[#stack]
end

local function PathText()
    local parts = { "Home" }
    for i = 1, #stack do
        parts[#parts + 1] = stack[i].name or "?"
    end
    return table.concat(parts, " > ")
end

local function ClearSearch()
    searchQuery = ""
    local f = Frame()
    if f and f.SetSearchOpen then
        f.SetSearchOpen(false)
    end
end

local function CountLabel(n, singular, plural)
    n = n or 0
    if n == 1 then
        return "1 " .. singular
    end
    return tostring(n) .. " " .. plural
end

local function CoverForItem(data)
    local catId
    if data.kind == "category" then
        catId = data.id
    end
    local expId = data.expansionId
    if not expId and data.kind == "expansion" then
        expId = data.id
    end
    if AQ.CoverTexture then
        return AQ.CoverTexture(expId, catId)
    end
    return AQ.Logo
end

local function NameMatch(hay, needle)
    if type(hay) ~= "string" or type(needle) ~= "string" or needle == "" then
        return false
    end
    return hay:lower():find(needle, 1, true) and true or false
end

local function BuildSearchItems()
    local q = searchQuery
    local expansions = AQ.Data:GetExpansions()
    for ei = 1, #expansions do
        local e = expansions[ei]
        local eName = e.name or ("Expansion " .. tostring(e.id))
        if NameMatch(eName, q) then
            local cats = AQ.Data:GetCategories(e.id)
            items[#items + 1] = {
                kind = "expansion",
                id = e.id,
                expansionId = e.id,
                title = eName,
                detail = CountLabel(#cats, "zone", "zones"),
                speech = eName .. ". " .. CountLabel(#cats, "zone", "zones") .. ".",
            }
        end
        local cats = AQ.Data:GetCategories(e.id)
        for ci = 1, #cats do
            local c = cats[ci]
            local cName = c.name or ("Zone " .. tostring(c.id))
            if NameMatch(cName, q) then
                local chains = AQ.Data:GetChains(c.id)
                items[#items + 1] = {
                    kind = "category",
                    id = c.id,
                    expansionId = e.id,
                    expansionName = eName,
                    title = cName,
                    detail = eName .. " · " .. CountLabel(#chains, "questline", "questlines"),
                    speech = cName .. ". " .. eName .. ". " .. CountLabel(#chains, "questline", "questlines") .. ".",
                }
            end
            local chains = AQ.Data:GetChains(c.id)
            for hi = 1, #chains do
                local ch = chains[hi]
                local chName = (ch.name or ("Questline " .. tostring(ch.id))) .. RestrictionLabel(ch)
                if NameMatch(chName, q) then
                    local st = AQ.Data:GetChainStatus(ch.id)
                    items[#items + 1] = {
                        kind = "chain",
                        id = ch.id,
                        expansionId = e.id,
                        expansionName = eName,
                        categoryId = c.id,
                        categoryName = cName,
                        title = chName,
                        status = st,
                        detail = eName .. " > " .. cName,
                        speech = chName .. " " .. st .. ". " .. eName .. ". " .. cName,
                    }
                end
            end
        end
    end
end

local function LeaveHiddenWorldQuestView()
    while true do
        local cur = Current()
        if not cur then
            return
        end
        local name
        if cur.kind == "category" then
            local cat = AQ.Data:GetCategory(cur.id)
            name = cat and cat.name
        elseif cur.kind == "chain" then
            local chain = AQ.Data:GetChain(cur.id)
            name = chain and chain.name
        else
            return
        end
        if not AQ.Data.IsWorldQuestBucket or not AQ.Data.IsWorldQuestBucket(name) then
            return
        end
        if AQ.Data.ShowWorldQuestBuckets and AQ.Data.ShowWorldQuestBuckets() then
            return
        end
        stack[#stack] = nil
    end
end

local function BuildItems()
    items = {}
    LeaveHiddenWorldQuestView()
    if searchQuery ~= "" then
        BuildSearchItems()
        if #items == 0 then
            items[1] = {
                kind = "empty",
                title = "No matches for " .. searchQuery,
                speech = "No matches for " .. searchQuery,
            }
        end
        return
    end
    local cur = Current()
    if not cur then
        local expansions = AQ.Data:GetExpansions()
        for i = 1, #expansions do
            local e = expansions[i]
            local cats = AQ.Data:GetCategories(e.id)
            items[#items + 1] = {
                kind = "expansion",
                id = e.id,
                expansionId = e.id,
                title = e.name or ("Expansion " .. tostring(e.id)),
                status = nil,
                detail = CountLabel(#cats, "zone", "zones"),
                speech = (e.name or "Expansion") .. ". " .. CountLabel(#cats, "zone", "zones") .. ".",
            }
        end
        if #items == 0 then
            items[1] = {
                kind = "empty",
                title = "No questline data loaded. Enable AllQuest_Data plugins.",
                speech = "No questline data loaded",
            }
        end
        return
    end
    if cur.kind == "expansion" then
        local cats = AQ.Data:GetCategories(cur.id)
        for i = 1, #cats do
            local c = cats[i]
            local chains = AQ.Data:GetChains(c.id)
            items[#items + 1] = {
                kind = "category",
                id = c.id,
                expansionId = cur.id,
                expansionName = cur.name,
                title = c.name or ("Zone " .. tostring(c.id)),
                detail = CountLabel(#chains, "questline", "questlines"),
                speech = (c.name or "Zone") .. ". " .. CountLabel(#chains, "questline", "questlines") .. ".",
            }
        end
    elseif cur.kind == "category" then
        local chains = AQ.Data:GetChains(cur.id)
        local total = #chains
        for i = 1, total do
            local ch = chains[i]
            local st = AQ.Data:GetChainStatus(ch.id)
            local name = (ch.name or ("Questline " .. tostring(ch.id))) .. RestrictionLabel(ch)
            items[#items + 1] = {
                kind = "chain",
                id = ch.id,
                title = name,
                status = st,
                index = i,
                total = total,
                detail = st,
                speech = "Questline " .. tostring(i) .. " of " .. tostring(total) .. ". " .. name .. ". " .. st,
            }
        end
    elseif cur.kind == "chain" then
        local chain = AQ.Data:GetChain(cur.id)
        if chain then
            local nodes = chain.nodes or {}
            for i = 1, #nodes do
                local node = nodes[i]
                local title = node.name
                local st = AQ.Data:GetNodeStatus(node)
                if node.type == "quest" and node.questID then
                    title = title or AQ.Compat.GetQuestTitle(node.questID)
                    if not title then
                        AQ.Compat.RequestQuestData(node.questID)
                        title = "Quest " .. tostring(node.questID)
                    end
                end
                title = title or (node.type or "step") .. " " .. tostring(node.id or i)
                local nextIds = {}
                if type(node.next) == "table" then
                    for n = 1, #node.next do
                        nextIds[#nextIds + 1] = node.next[n]
                    end
                end
                items[#items + 1] = {
                    kind = "node",
                    id = node.id or i,
                    questID = node.questID,
                    title = title,
                    status = st,
                    nextIds = nextIds,
                    x = node.x,
                    y = node.y,
                    speech = title .. " " .. st,
                }
            end
        end
    end
    if #items == 0 then
        items[1] = {
            kind = "empty",
            title = "Nothing in this folder.",
            speech = "Nothing in this folder",
        }
    end
end

local function UseGrid()
    if searchQuery ~= "" then
        return false
    end
    if DB().journalGrid == false then
        return false
    end
    local cur = Current()
    if not cur then
        return true
    end
    if cur.kind == "expansion" or cur.kind == "category" then
        return true
    end
    return false
end

local function IsChainView()
    if searchQuery ~= "" then
        return false
    end
    local cur = Current()
    return cur and cur.kind == "chain" and true or false
end

local function HidePool(pool)
    for i = 1, #pool do
        pool[i]:Hide()
    end
end

local function GetRow(i, parent)
    local row = rowFrames[i]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(28)
    AQ.Widgets.ApplyBackdrop(row, 1)
    row.Text = AQ.Widgets.FontString(row, 15)
    row.Text:SetPoint("LEFT", 8, 0)
    row.Text:SetPoint("RIGHT", -90, 0)
    row.Status = AQ.Widgets.FontString(row, 13)
    row.Status:SetPoint("RIGHT", -8, 0)
    row.Status:SetJustifyH("RIGHT")
    row:SetScript("OnClick", function(self)
        ListView.Focus(self.index)
        if self.data and self.data.kind == "node" then
            return
        end
        ListView.Activate()
    end)
    row:SetScript("OnDoubleClick", function(self)
        ListView.Focus(self.index)
        if self.data and self.data.kind == "node" then
            ListView.ShowQuestDetail()
        else
            ListView.Activate()
        end
    end)
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(row, function(self)
            local d = self.data
            if not d then
                return ""
            end
            if d.speech and d.speech ~= "" then
                return d.speech
            end
            local text = d.title or ""
            if d.status then
                text = text .. ". " .. d.status
            elseif d.detail then
                text = text .. ". " .. d.detail
            end
            return text
        end)
    end
    rowFrames[i] = row
    return row
end

local function CaptionHeight()
    return AQ.Theme.FontSize(13) * 2 + AQ.Theme.FontSize(11) + 16
end

local function GetCard(i, parent)
    local card = cardFrames[i]
    if card then
        return card
    end
    card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    AQ.Widgets.ApplyBackdrop(card, 2)
    local caption = CreateFrame("Frame", nil, card)
    caption:SetPoint("BOTTOMLEFT", 2, 2)
    caption:SetPoint("BOTTOMRIGHT", -2, 2)
    caption:SetHeight(CaptionHeight())
    local capFill = caption:CreateTexture(nil, "BACKGROUND")
    capFill:SetAllPoints()
    capFill:SetColorTexture(0, 0, 0, 1)
    card.Caption = caption
    local art = card:CreateTexture(nil, "ARTWORK")
    art:SetPoint("TOPLEFT", 2, -2)
    art:SetPoint("TOPRIGHT", -2, -2)
    art:SetPoint("BOTTOMLEFT", caption, "TOPLEFT", 0, 0)
    art:SetPoint("BOTTOMRIGHT", caption, "TOPRIGHT", 0, 0)
    -- 1024x512 covers are 2:1; crop to 16:9 for the tile.
    art:SetTexCoord(0.056, 0.944, 0, 1)
    card.Art = art
    card.Title = AQ.Widgets.FontString(caption, 13, AQ.Theme.accent[1], AQ.Theme.accent[2], AQ.Theme.accent[3])
    card.Title:SetPoint("TOPLEFT", 6, -4)
    card.Title:SetPoint("TOPRIGHT", -6, -4)
    card.Title:SetHeight(AQ.Theme.FontSize(13) * 2 + 2)
    card.Title:SetJustifyH("CENTER")
    if card.Title.SetJustifyV then
        card.Title:SetJustifyV("TOP")
    end
    card.Title:SetWordWrap(true)
    if card.Title.SetMaxLines then
        pcall(card.Title.SetMaxLines, card.Title, 2)
    end
    card.Detail = AQ.Widgets.FontString(caption, 11, AQ.Theme.hint[1], AQ.Theme.hint[2], AQ.Theme.hint[3])
    card.Detail:SetPoint("BOTTOMLEFT", 6, 4)
    card.Detail:SetPoint("BOTTOMRIGHT", -6, 4)
    card.Detail:SetJustifyH("CENTER")
    card.Detail:SetWordWrap(false)
    if card.Detail.SetMaxLines then
        pcall(card.Detail.SetMaxLines, card.Detail, 1)
    end
    card.Number = AQ.Widgets.FontString(card, 42, AQ.Theme.accent[1], AQ.Theme.accent[2], AQ.Theme.accent[3])
    card.Number:SetPoint("TOPLEFT", art, "TOPLEFT", 4, -4)
    card.Number:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", -4, 4)
    card.Number:SetJustifyH("CENTER")
    if card.Number.SetJustifyV then
        card.Number:SetJustifyV("MIDDLE")
    end
    card.Number:Hide()
    card:SetScript("OnClick", function(self)
        ListView.Focus(self.index)
        ListView.Activate()
    end)
    card:SetScript("OnDoubleClick", function(self)
        ListView.Focus(self.index)
        if self.data and self.data.kind == "node" then
            ListView.ShowQuestDetail()
        else
            ListView.Activate()
        end
    end)
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(card, function(self)
            local d = self.data
            if not d then
                return ""
            end
            return d.speech or d.title or ""
        end)
    end
    local prevEnter = card:GetScript("OnEnter")
    local prevLeave = card:GetScript("OnLeave")
    card:SetScript("OnEnter", function(self, ...)
        if prevEnter then
            prevEnter(self, ...)
        end
        local d = self.data
        if d and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(d.title or "")
            if d.detail then
                GameTooltip:AddLine(d.detail, 0.85, 0.85, 0.85, true)
            end
            GameTooltip:Show()
        end
    end)
    card:SetScript("OnLeave", function(self, ...)
        if prevLeave then
            prevLeave(self, ...)
        end
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
    cardFrames[i] = card
    return card
end

local function UpdateZoneDropdown()
    local f = Frame()
    if not f or not f.ZoneDrop then
        return
    end
    local dropItems = {}
    local selected
    local cur = Current()
    local expId
    if cur then
        if cur.kind == "expansion" then
            expId = cur.id
        elseif stack[1] and stack[1].kind == "expansion" then
            expId = stack[1].id
        end
    end
    if expId then
        local cats = AQ.Data:GetCategories(expId)
        for i = 1, #cats do
            local c = cats[i]
            dropItems[#dropItems + 1] = {
                text = c.name or ("Zone " .. tostring(c.id)),
                value = "c:" .. tostring(c.id),
            }
        end
        if cur and cur.kind == "category" then
            selected = "c:" .. tostring(cur.id)
        end
    else
        local expansions = AQ.Data:GetExpansions()
        for i = 1, #expansions do
            local e = expansions[i]
            dropItems[#dropItems + 1] = {
                text = e.name or ("Expansion " .. tostring(e.id)),
                value = "e:" .. tostring(e.id),
            }
        end
    end
    if #dropItems == 0 then
        dropItems[1] = { text = "No zones", value = "", disabled = true }
    end
    f.ZoneDrop:SetItems(dropItems)
    f.ZoneDrop:SetValue(selected)
    if not selected then
        f.ZoneDrop.AQLabel:SetText("Zone")
    end
end

function ListView.Refresh()
    local f = Frame()
    if not f then
        return
    end
    BuildItems()
    if focused > #items then
        focused = #items
    end
    if focused < 1 then
        focused = 1
    end
    f.Path:SetText(PathText())
    UpdateZoneDropdown()
    local child = f.Scroll.Child
    local width = f:GetWidth() - 40
    if IsChainView() and AQ.Journal.GraphView then
        HidePool(rowFrames)
        HidePool(cardFrames)
        AQ.Journal.GraphView.Refresh(items, focused)
        return
    end
    if AQ.Journal.GraphView then
        AQ.Journal.GraphView.Hide()
    end
    local grid = UseGrid()
    if grid then
        HidePool(rowFrames)
        local cols = 3
        if width < 500 then
            cols = 1
        elseif width < 700 then
            cols = 2
        end
        local gap = 10
        local captionH = CaptionHeight()
        local tileW = math.floor((width - gap * (cols - 1)) / cols)
        local artH = math.floor(tileW * 9 / 16)
        if artH > 150 then
            artH = 150
            tileW = math.floor(artH * 16 / 9)
        end
        local tileH = artH + captionH
        local totalW = cols * tileW + (cols - 1) * gap
        local x0 = math.floor((width - totalW) / 2)
        if x0 < 0 then
            x0 = 0
        end
        local y = 0
        for i = 1, #items do
            local data = items[i]
            local card = GetCard(i, child)
            card:Show()
            card.index = i
            card.data = data
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local x = x0 + col * (tileW + gap)
            y = row * (tileH + gap)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", x, -y)
            card:SetSize(tileW, tileH)
            if card.Caption then
                card.Caption:SetHeight(captionH)
            end
            if data.kind == "chain" and data.index then
                card.Art:SetTexture(nil)
                card.Art:SetColorTexture(0.04, 0.04, 0.04, 1)
                card.Art:SetTexCoord(0, 1, 0, 1)
                if card.Number then
                    card.Number:Show()
                    card.Number:SetText(tostring(data.index))
                    local nSize = math.max(28, math.min(56, math.floor(artH * 0.42)))
                    AQ.Widgets.SetFont(card.Number, nSize, AQ.Theme.accent[1], AQ.Theme.accent[2], AQ.Theme.accent[3])
                end
            else
                if card.Number then
                    card.Number:Hide()
                end
                card.Art:SetColorTexture(0, 0, 0, 0)
                card.Art:SetTexture(CoverForItem(data))
                card.Art:SetTexCoord(0.056, 0.944, 0, 1)
            end
            card.Title:SetText(data.title or "")
            AQ.Widgets.SetFont(card.Title, 13)
            if card.Detail then
                card.Detail:Show()
                card.Detail:SetText(data.detail or "")
                AQ.Widgets.SetFont(card.Detail, 11)
                if data.status then
                    local c = AQ.Theme.StatusColor(data.status)
                    card.Detail:SetTextColor(c[1], c[2], c[3], 1)
                else
                    local h = AQ.Theme.hint
                    card.Detail:SetTextColor(h[1], h[2], h[3], 1)
                end
            end
            local gold = AQ.Theme.Tracker.header
            local border = AQ.Theme.Tracker.border
            if card.SetBackdropBorderColor then
                if i == focused then
                    card:SetBackdropBorderColor(gold[1], gold[2], gold[3], 1)
                else
                    card:SetBackdropBorderColor(border[1], border[2], border[3], 1)
                end
            end
        end
        for i = #items + 1, #cardFrames do
            cardFrames[i]:Hide()
        end
        local rows = math.ceil(#items / cols)
        child:SetSize(width, math.max(rows * (tileH + gap), 1))
        return
    end
    HidePool(cardFrames)
    local y = 0
    for i = 1, #items do
        local data = items[i]
        local row = GetRow(i, child)
        row:Show()
        row.index = i
        row.data = data
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetWidth(width)
        local col = (i == focused) and AQ.Theme.rowBgFocus or ((i % 2 == 0) and AQ.Theme.rowBgAlt or AQ.Theme.rowBg)
        if row.SetBackdropColor then
            row:SetBackdropColor(col[1], col[2], col[3], col[4] or 0.55)
        end
        row.Text:SetText(data.title or "")
        AQ.Widgets.SetFont(row.Text, 15)
        AQ.Widgets.SetFont(row.Status, 13)
        if data.status then
            row.Status:SetText(data.status)
            local c = AQ.Theme.StatusColor(data.status)
            row.Status:SetTextColor(c[1], c[2], c[3], 1)
        else
            row.Status:SetText(data.detail or "")
            local h = AQ.Theme.hint
            row.Status:SetTextColor(h[1], h[2], h[3], 1)
        end
        y = y + 30
    end
    for i = #items + 1, #rowFrames do
        rowFrames[i]:Hide()
    end
    child:SetSize(width, math.max(y, 1))
end

function ListView.Focus(index)
    if index < 1 then
        index = 1
    end
    if index > #items then
        index = #items
    end
    focused = index
    local data = items[focused]
    if data and AQ.DB.Get().speechOnSelect ~= false then
        AQ.Speech.Say(data.speech or data.title or "")
    end
    ListView.Refresh()
end

function ListView.ReadFocus()
    local data = items[focused]
    if data then
        AQ.Speech.Say(data.speech or data.title or "Empty", true)
    else
        AQ.Speech.Say("Journal is empty", true)
    end
end

function ListView.OpenExpansion(id)
    local exp = AQ.Data:GetExpansion(id)
    if not exp then
        return
    end
    ClearSearch()
    stack = { { kind = "expansion", id = id, name = exp.name } }
    focused = 1
    ListView.Refresh()
    AQ.Speech.Say(exp.name or "Expansion")
end

function ListView.OpenCategory(id, silent)
    local cat = AQ.Data:GetCategory(id)
    if not cat then
        return
    end
    ClearSearch()
    local exp = AQ.Data:GetExpansion(cat.expansion)
    stack = {}
    if exp then
        stack[#stack + 1] = { kind = "expansion", id = exp.id, name = exp.name }
    end
    stack[#stack + 1] = { kind = "category", id = cat.id, name = cat.name }
    focused = 1
    ListView.Refresh()
    if not silent then
        AQ.Speech.Say(cat.name or "Zone")
    end
end

function ListView.Activate()
    local data = items[focused]
    if not data then
        return
    end
    if data.kind == "expansion" then
        ListView.OpenExpansion(data.id)
        return
    end
    if data.kind == "category" then
        ListView.OpenCategory(data.id)
        return
    end
    if data.kind == "chain" then
        ClearSearch()
        if data.expansionId and data.categoryId then
            local exp = AQ.Data:GetExpansion(data.expansionId)
            local cat = AQ.Data:GetCategory(data.categoryId)
            stack = {}
            if exp then
                stack[#stack + 1] = { kind = "expansion", id = exp.id, name = exp.name }
            end
            if cat then
                stack[#stack + 1] = { kind = "category", id = cat.id, name = cat.name }
            end
        end
        stack[#stack + 1] = { kind = "chain", id = data.id, name = data.title }
        focused = 1
        ListView.Refresh()
        AQ.Speech.Say(data.title)
        return
    end
    if data.kind == "node" and data.questID then
        AQ.Compat.SuperTrackQuest(data.questID)
        if AQ.Compat.IsQuestActive(data.questID) then
            AQ.Compat.AddQuestWatch(data.questID)
        end
        AQ.Speech.Say("Tracking " .. (data.title or "quest"))
        if AQ.Tracker then
            AQ.Tracker.Refresh()
        end
    end
end

function ListView.Back()
    if AQ.Journal.QuestDetail and AQ.Journal.QuestDetail.IsShown() then
        AQ.Journal.QuestDetail.Hide()
        AQ.Speech.Say("Details closed")
        return
    end
    if #stack == 0 then
        AQ.Speech.Say("Already at home")
        return
    end
    ClearSearch()
    stack[#stack] = nil
    focused = 1
    ListView.Refresh()
    AQ.Speech.Say(PathText())
end

function ListView.Home()
    if AQ.Journal.QuestDetail and AQ.Journal.QuestDetail.IsShown() then
        AQ.Journal.QuestDetail.Hide()
    end
    ClearSearch()
    stack = {}
    focused = 1
    ListView.Refresh()
    AQ.Speech.Say("Journal home")
end

function ListView.SetSearch(text)
    searchQuery = AQ:Trim(text or ""):lower()
    focused = 1
    ListView.Refresh()
end

function ListView.OnZonePicked(value)
    if type(value) ~= "string" or value == "" then
        return
    end
    local kind, id = string.match(value, "^(%a+):(%d+)$")
    id = tonumber(id)
    if kind == "e" and id then
        ListView.OpenExpansion(id)
    elseif kind == "c" and id then
        ListView.OpenCategory(id)
    end
end

local function BestCategoryForNames(names)
    if type(names) ~= "table" or #names == 0 then
        return nil
    end
    local best
    local bestScore
    local expansions = AQ.Data:GetExpansions()
    for ni = 1, #names do
        local mapName = names[ni]:lower()
        for ei = 1, #expansions do
            local cats = AQ.Data:GetCategories(expansions[ei].id)
            for ci = 1, #cats do
                local cat = cats[ci]
                local cname = (cat.name or ""):lower()
                if cname ~= "" and not (AQ.Data.IsUnlistedBucket and AQ.Data.IsUnlistedBucket(cname)) then
                    local score
                    if cname == mapName then
                        score = 400
                    elseif cname:sub(1, #mapName) == mapName then
                        score = 300
                    elseif cname:find(mapName, 1, true) then
                        score = 200
                    elseif #cname >= 5 and mapName:find(cname, 1, true) then
                        score = 100
                    end
                    if score then
                        score = score - (ni * 10) - math.min(#cname, 80)
                        if not bestScore or score > bestScore then
                            bestScore = score
                            best = cat
                        end
                    end
                end
            end
        end
        if best and bestScore and bestScore >= 190 then
            break
        end
    end
    return best
end

local function MapNamesForQuest(questID)
    local names = {}
    local mapID = AQ.Compat.GetQuestUiMapID and AQ.Compat.GetQuestUiMapID(questID)
    if type(mapID) ~= "number" and AQ.QuestSources and AQ.QuestSources.ResolveLocation then
        mapID = select(1, AQ.QuestSources.ResolveLocation(questID))
    end
    if type(mapID) ~= "number" and AQ.Compat.GetQuestPickupLocation then
        mapID = select(1, AQ.Compat.GetQuestPickupLocation(questID))
    end
    if AQ.Compat.GetMapNameChainFrom then
        names = AQ.Compat.GetMapNameChainFrom(mapID)
    elseif type(mapID) == "number" then
        local name = AQ.Compat.GetMapName(mapID)
        if name then
            names[1] = name
        end
    end
    return names
end

function ListView.Here()
    local names = AQ.Compat.GetMapNameChain and AQ.Compat.GetMapNameChain() or {}
    if type(names) ~= "table" or #names == 0 then
        AQ.Speech.Say("Current zone unknown")
        return
    end
    local best = BestCategoryForNames(names)
    if best then
        ListView.OpenCategory(best.id)
        return
    end
    for ni = 1, #names do
        local mapName = names[ni]:lower()
        local expansions = AQ.Data:GetExpansions()
        for ei = 1, #expansions do
            local eName = (expansions[ei].name or ""):lower()
            if eName ~= "" and (eName == mapName or eName:find(mapName, 1, true) or mapName:find(eName, 1, true)) then
                ListView.OpenExpansion(expansions[ei].id)
                return
            end
        end
    end
    AQ.Speech.Say("No journal zone for " .. names[1])
end

local function GridColumns()
    local f = Frame()
    if not f then
        return 1
    end
    local width = f:GetWidth() - 40
    if width < 500 then
        return 1
    end
    if width < 700 then
        return 2
    end
    return 3
end

function ListView.ShowQuestDetail()
    local data = items[focused]
    if not data or not data.questID then
        AQ.Speech.Say("No quest selected")
        return
    end
    if AQ.Journal.QuestDetail then
        AQ.Journal.QuestDetail.Show(data.questID, data.title)
    end
end

function ListView.OnKey(key)
    if AQ.Journal.QuestDetail and AQ.Journal.QuestDetail.IsShown() then
        if key == "ESCAPE" or key == "BACKSPACE" then
            AQ.Journal.QuestDetail.Hide()
            AQ.Speech.Say("Details closed")
            return true
        end
        if key == "ENTER" or key == "SPACE" then
            ListView.Activate()
            return true
        end
    end
    if IsChainView() and AQ.Journal.GraphView then
        if key == "UP" or key == "DOWN" or key == "LEFT" or key == "RIGHT"
            or key == "W" or key == "A" or key == "S" or key == "D" then
            return AQ.Journal.GraphView.OnKey(key, items, focused)
        end
    end
    if key == "UP" or key == "W" then
        if UseGrid() then
            ListView.Focus(focused - GridColumns())
        else
            ListView.Focus(focused - 1)
        end
        return true
    end
    if key == "DOWN" or key == "S" then
        if UseGrid() then
            ListView.Focus(focused + GridColumns())
        else
            ListView.Focus(focused + 1)
        end
        return true
    end
    if key == "LEFT" or key == "A" then
        ListView.Focus(focused - 1)
        return true
    end
    if key == "RIGHT" or key == "D" then
        ListView.Focus(focused + 1)
        return true
    end
    if key == "ENTER" or key == "SPACE" then
        ListView.Activate()
        return true
    end
    if key == "BACKSPACE" then
        if #stack > 0 then
            ListView.Back()
        end
        return true
    end
    if key == "ESCAPE" then
        if #stack > 0 then
            ListView.Back()
            return true
        end
        return false
    end
    return false
end

function ListView.OpenQuest(questID)
    if type(questID) ~= "number" then
        return
    end
    ClearSearch()
    local chain, nodeIndex = AQ.Data:FindFirstChainForQuest(questID)
    local dump = chain and AQ.Data.IsUnlistedBucket and AQ.Data.IsUnlistedBucket(chain.name)
    if chain and not dump then
        local cat = AQ.Data:GetCategory(chain.category)
        local exp = cat and AQ.Data:GetExpansion(cat.expansion or chain.expansion)
        stack = {}
        if exp then
            stack[#stack + 1] = { kind = "expansion", id = exp.id, name = exp.name }
        end
        if cat then
            stack[#stack + 1] = { kind = "category", id = cat.id, name = cat.name }
        end
        stack[#stack + 1] = { kind = "chain", id = chain.id, name = chain.name }
        focused = nodeIndex or 1
        ListView.Refresh()
    else
        local zone = BestCategoryForNames(MapNamesForQuest(questID))
        if zone then
            ListView.OpenCategory(zone.id, true)
        else
            stack = {}
            focused = 1
            ListView.Refresh()
        end
    end
    if AQ.Journal.QuestDetail then
        local title = AQ.Compat.GetQuestTitle and AQ.Compat.GetQuestTitle(questID)
        AQ.Journal.QuestDetail.Show(questID, title)
        return
    end
    if not chain then
        AQ.Speech.Say("No questline data for this quest")
    end
end

AQ.Events.Register("QUEST_DATA_LOAD_RESULT", function(_, questID, success)
    if success == false or type(questID) ~= "number" then
        return
    end
    local name = AQ.Compat.GetQuestTitle(questID)
    if not name then
        return
    end
    local dirty = false
    for i = 1, #items do
        local d = items[i]
        if d and d.questID == questID and d.title ~= name then
            d.title = name
            d.speech = name .. " " .. (d.status or "")
            dirty = true
        end
    end
    if not dirty then
        return
    end
    local f = Frame()
    if not f or not f:IsShown() then
        return
    end
    if IsChainView() and AQ.Journal.GraphView and AQ.Journal.GraphView.UpdateTitles then
        AQ.Journal.GraphView.UpdateTitles(items)
        return
    end
    for i = 1, #rowFrames do
        local row = rowFrames[i]
        local d = row and row.data
        if row and row:IsShown() and d and d.questID == questID then
            row.Text:SetText(name)
        end
    end
end)
