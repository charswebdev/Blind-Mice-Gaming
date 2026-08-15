--[[
  AllQuest — questline flowchart (chain view)
  Opaque black nodes, gold text, status words, connector lines.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Journal = AQ.Journal or {}
local GraphView = {}
AQ.Journal.GraphView = GraphView

local NODE_W = 220
local NODE_H = 40
local VGAP = 36
local HGAP = 16
local LINE_H = 3
local nodeW = NODE_W

local nodeFrames = {}
local linePool = {}
local lineUsed = 0
local layout = {} -- index in items -> {x,y,id}

local function Frame()
    return AQ.Journal.GetFrame()
end

local function AcquireLine(parent)
    lineUsed = lineUsed + 1
    local line = linePool[lineUsed]
    if not line then
        line = parent:CreateTexture(nil, "BACKGROUND")
        linePool[lineUsed] = line
    end
    line:SetParent(parent)
    line:Show()
    return line
end

local function HideUnusedLines()
    for i = lineUsed + 1, #linePool do
        linePool[i]:Hide()
    end
end

local function DrawSeg(parent, x, y, w, h, r, g, b)
    local t = AcquireLine(parent)
    t:ClearAllPoints()
    t:SetColorTexture(r, g, b, 1)
    t:SetSize(math.max(w, LINE_H), math.max(h, LINE_H))
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
end

local function LineColor(status)
    if status == "DONE" then
        local c = AQ.Theme.Tracker.complete
        return c[1], c[2], c[3]
    end
    if status == "ACTIVE" then
        local c = AQ.Theme.accent
        return c[1], c[2], c[3]
    end
    local c = AQ.Theme.hint
    return c[1], c[2], c[3]
end

local function GetNode(i, parent)
    local btn = nodeFrames[i]
    if btn then
        return btn
    end
    btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(NODE_W, NODE_H)
    AQ.Widgets.ApplyBackdrop(btn, 1)
    btn.Text = AQ.Widgets.FontString(btn, 14, AQ.Theme.accent[1], AQ.Theme.accent[2], AQ.Theme.accent[3])
    btn.Text:SetPoint("LEFT", 10, 0)
    btn.Text:SetPoint("RIGHT", -72, 0)
    btn.Text:SetJustifyH("LEFT")
    btn.Text:SetWordWrap(false)
    if btn.Text.SetMaxLines then
        pcall(btn.Text.SetMaxLines, btn.Text, 1)
    end
    btn.Status = AQ.Widgets.FontString(btn, 12)
    btn.Status:SetPoint("RIGHT", -10, 0)
    btn.Status:SetJustifyH("RIGHT")
    btn.Check = btn:CreateTexture(nil, "OVERLAY")
    btn.Check:SetSize(16, 16)
    btn.Check:SetPoint("RIGHT", btn.Status, "LEFT", -4, 0)
    btn.Check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if not AQ.Journal.ListView then
            return
        end
        AQ.Journal.ListView.Focus(self.index)
        if button == "RightButton" then
            AQ.Journal.ListView.Activate()
            return
        end
        local now = GetTime and GetTime() or 0
        if self.AQClickAt and (now - self.AQClickAt) < 0.45 then
            self.AQClickAt = nil
            AQ.Journal.ListView.ShowQuestDetail()
            return
        end
        self.AQClickAt = now
    end)
    if AQ.Speech and AQ.Speech.AttachHover then
        AQ.Speech.AttachHover(btn, function(self)
            local d = self.data
            if not d then
                return ""
            end
            return d.speech or d.title or ""
        end)
    end
    nodeFrames[i] = btn
    return btn
end

local function HasColumnHints(items)
    for i = 1, #items do
        if items[i].kind == "node" and items[i].x ~= nil then
            return true
        end
    end
    return false
end

-- Column/row placement used by campaign flowcharts: spine at x=0, side quests
-- share a row (x steps of 2). Same rules as a typical quest journal graph.
local function BuildColumnLayout(items)
    layout = {}
    local previousX, previousY, embedX, embedY = nil, 0, nil, 0
    local minX, maxX, maxY = 0, 0, 0
    local byId = {}
    local children = {}
    for i = 1, #items do
        local d = items[i]
        if d.kind == "node" then
            byId[d.id] = i
            children[d.id] = {}
            local x, y = d.x, d.y
            if x == nil then
                if y == nil then
                    if previousX == nil then
                        x, y = 0, 0
                    else
                        x = embedX + 2
                        y = embedY
                        if x > 6 then
                            x = x - 8
                            y = y + 1
                        end
                    end
                else
                    x = previousX
                end
            elseif y == nil then
                if previousX ~= nil and x <= previousX then
                    y = previousY + 1
                else
                    y = embedY
                end
            end
            embedX, embedY = x, y
            previousX, previousY = x, y
            if x < minX then
                minX = x
            end
            if x > maxX then
                maxX = x
            end
            if y > maxY then
                maxY = y
            end
            local step = (nodeW + HGAP) / 2
            layout[i] = {
                x = (x - minX) * step,
                y = y * (NODE_H + VGAP),
                id = d.id,
                layer = y,
                col = x,
            }
        end
    end
    -- minX may have been discovered after earlier nodes were placed.
    local step = (nodeW + HGAP) / 2
    for i = 1, #items do
        local pos = layout[i]
        local d = items[i]
        if pos and d and d.kind == "node" then
            local gx = pos.col
            pos.x = (gx - minX) * step
        end
    end
    for i = 1, #items do
        local d = items[i]
        if d.kind == "node" and type(d.nextIds) == "table" then
            for n = 1, #d.nextIds do
                local nid = d.nextIds[n]
                if byId[nid] then
                    children[d.id][#children[d.id] + 1] = nid
                end
            end
        end
    end
    local maxW = (maxX - minX) * step + nodeW
    local height = (maxY + 1) * (NODE_H + VGAP)
    return maxW, math.max(height, NODE_H), byId, children
end

local function BuildLayout(items)
    if HasColumnHints(items) then
        return BuildColumnLayout(items)
    end
    layout = {}
    local byId = {}
    local indeg = {}
    local children = {}
    for i = 1, #items do
        local d = items[i]
        if d.kind == "node" then
            local id = d.id
            byId[id] = i
            indeg[id] = indeg[id] or 0
            children[id] = children[id] or {}
        end
    end
    for i = 1, #items do
        local d = items[i]
        if d.kind == "node" then
            local nxt = d.nextIds
            if type(nxt) == "table" then
                for n = 1, #nxt do
                    local nid = nxt[n]
                    if byId[nid] then
                        indeg[nid] = (indeg[nid] or 0) + 1
                        children[d.id][#children[d.id] + 1] = nid
                    end
                end
            end
        end
    end
    local layers = {}
    local placed = {}
    local ready = {}
    for i = 1, #items do
        local d = items[i]
        if d.kind == "node" and (indeg[d.id] or 0) == 0 then
            ready[#ready + 1] = d.id
        end
    end
    table.sort(ready, function(a, b)
        return a < b
    end)
    while #ready > 0 do
        local layer = {}
        local nextReady = {}
        for r = 1, #ready do
            local id = ready[r]
            if not placed[id] then
                placed[id] = true
                layer[#layer + 1] = id
                local kids = children[id]
                for k = 1, #kids do
                    local cid = kids[k]
                    indeg[cid] = (indeg[cid] or 0) - 1
                    if indeg[cid] == 0 and not placed[cid] then
                        nextReady[#nextReady + 1] = cid
                    end
                end
            end
        end
        if #layer > 0 then
            table.sort(layer, function(a, b)
                return a < b
            end)
            layers[#layers + 1] = layer
        end
        table.sort(nextReady, function(a, b)
            return a < b
        end)
        ready = nextReady
    end
    for i = 1, #items do
        local d = items[i]
        if d.kind == "node" and not placed[d.id] then
            layers[#layers + 1] = { d.id }
            placed[d.id] = true
        end
    end
    local maxCols = 1
    for L = 1, #layers do
        if #layers[L] > maxCols then
            maxCols = #layers[L]
        end
    end
    local maxW = maxCols * nodeW + (maxCols - 1) * HGAP
    for L = 1, #layers do
        local row = layers[L]
        local count = #row
        local rowW = count * nodeW + (count - 1) * HGAP
        local x0 = math.floor((maxW - rowW) / 2)
        for c = 1, count do
            local id = row[c]
            local idx = byId[id]
            layout[idx] = {
                x = x0 + (c - 1) * (nodeW + HGAP),
                y = (L - 1) * (NODE_H + VGAP),
                id = id,
                layer = L,
                col = c,
            }
        end
    end
    local height = #layers * (NODE_H + VGAP)
    return maxW, math.max(height, NODE_H), byId, children, layers
end

function GraphView.Hide()
    for i = 1, #nodeFrames do
        nodeFrames[i]:Hide()
    end
    lineUsed = 0
    HideUnusedLines()
end

function GraphView.Refresh(items, focused)
    local f = Frame()
    if not f then
        return
    end
    local child = f.Scroll.Child
    local width = f:GetWidth() - 40
    nodeW = math.floor((width - HGAP * 2) / 3)
    if nodeW > 240 then
        nodeW = 240
    end
    if nodeW < 168 then
        nodeW = 168
    end
    lineUsed = 0
    local maxW, height, byId = BuildLayout(items)
    local xOff = math.max(0, math.floor((width - maxW) / 2))
    for i = 1, #items do
        local pos = layout[i]
        local data = items[i]
        if pos and data then
            local btn = GetNode(i, child)
            btn:Show()
            btn.index = i
            btn.data = data
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", child, "TOPLEFT", xOff + pos.x, -pos.y)
            btn:SetSize(nodeW, NODE_H)
            btn.Text:SetText(data.title or "")
            AQ.Widgets.SetFont(btn.Text, 14, AQ.Theme.accent[1], AQ.Theme.accent[2], AQ.Theme.accent[3])
            btn.Text:SetJustifyH("LEFT")
            btn.Text:SetWordWrap(false)
            local st = data.status or ""
            btn.Status:SetText(st)
            local sc = AQ.Theme.StatusColor(st)
            btn.Status:SetTextColor(sc[1], sc[2], sc[3], 1)
            AQ.Widgets.SetFont(btn.Status, 12)
            if st == "DONE" then
                btn.Check:Show()
            else
                btn.Check:Hide()
            end
            local gold = AQ.Theme.Tracker.header
            local border = AQ.Theme.Tracker.border
            if btn.SetBackdropBorderColor then
                if i == focused then
                    btn:SetBackdropBorderColor(gold[1], gold[2], gold[3], 1)
                else
                    btn:SetBackdropBorderColor(border[1], border[2], border[3], 1)
                end
            end
        elseif nodeFrames[i] then
            nodeFrames[i]:Hide()
        end
    end
    for i = #items + 1, #nodeFrames do
        nodeFrames[i]:Hide()
    end
    for i = 1, #items do
        local pos = layout[i]
        local data = items[i]
        if pos and data and type(data.nextIds) == "table" then
            local r, g, b = LineColor(data.status)
            local x1 = xOff + pos.x + nodeW / 2
            local y1 = pos.y + NODE_H
            for n = 1, #data.nextIds do
                local nid = data.nextIds[n]
                local ci = byId[nid]
                local dest = ci and layout[ci]
                if dest then
                    local x2 = xOff + dest.x + nodeW / 2
                    local y2 = dest.y
                    local midY = math.floor((y1 + y2) / 2)
                    DrawSeg(child, x1 - LINE_H / 2, y1, LINE_H, math.max(midY - y1, LINE_H), r, g, b)
                    local left = math.min(x1, x2)
                    DrawSeg(child, left, midY - LINE_H / 2, math.max(math.abs(x2 - x1), LINE_H), LINE_H, r, g, b)
                    DrawSeg(child, x2 - LINE_H / 2, midY, LINE_H, math.max(y2 - midY, LINE_H), r, g, b)
                end
            end
        end
    end
    HideUnusedLines()
    child:SetSize(math.max(width, maxW + 8), math.max(height, 1))
end

function GraphView.UpdateTitles(items)
    for i = 1, #items do
        local btn = nodeFrames[i]
        local data = items[i]
        if btn and btn:IsShown() and data then
            btn.data = data
            btn.Text:SetText(data.title or "")
        end
    end
end

function GraphView.OnKey(key, items, focused)
    if not focused or not layout[focused] then
        return false
    end
    local cur = layout[focused]
    local best
    local bestScore
    local function Consider(idx, score)
        if not idx or not layout[idx] then
            return
        end
        if not bestScore or score < bestScore then
            bestScore = score
            best = idx
        end
    end
    if key == "UP" or key == "W" then
        for i = 1, #items do
            local p = layout[i]
            if p and p.layer == cur.layer - 1 then
                Consider(i, math.abs(p.x - cur.x))
            end
        end
    elseif key == "DOWN" or key == "S" then
        local data = items[focused]
        if data and type(data.nextIds) == "table" and data.nextIds[1] then
            for i = 1, #items do
                if items[i].id == data.nextIds[1] then
                    best = i
                    break
                end
            end
        end
        if not best then
            for i = 1, #items do
                local p = layout[i]
                if p and p.layer == cur.layer + 1 then
                    Consider(i, math.abs(p.x - cur.x))
                end
            end
        end
    elseif key == "LEFT" or key == "A" then
        for i = 1, #items do
            local p = layout[i]
            if p and p.layer == cur.layer and p.x < cur.x then
                Consider(i, cur.x - p.x)
            end
        end
    elseif key == "RIGHT" or key == "D" then
        for i = 1, #items do
            local p = layout[i]
            if p and p.layer == cur.layer and p.x > cur.x then
                Consider(i, p.x - cur.x)
            end
        end
    else
        return false
    end
    if best and AQ.Journal.ListView then
        AQ.Journal.ListView.Focus(best)
        return true
    end
    return true
end
