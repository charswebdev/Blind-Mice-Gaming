local _, BMGAM = ...

BMGAM.Quests = BMGAM.Quests or {}
local Quests = BMGAM.Quests
local Theme = BMGAM.Theme

local HEADER = 26
local COLS = 18
local ROW = 20
local NOTE = 18

local function ShowQuestTip(owner, questID)
    if type(questID) ~= "number" or not GameTooltip then
        return
    end
    if C_QuestLog and type(C_QuestLog.RequestLoadQuestByID) == "function" then
        pcall(C_QuestLog.RequestLoadQuestByID, questID)
    end
    local owned = pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_CURSOR_RIGHT", 16, 0)
    if not owned then
        pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_CURSOR")
    end
    local ready = true
    if type(HaveQuestData) == "function" then
        local ok, have = pcall(HaveQuestData, questID)
        if ok then
            local flagOk, flag = pcall(function()
                return have == true
            end)
            ready = flagOk and flag
        else
            ready = false
        end
    end
    local shown = false
    if ready then
        local link = "quest:" .. questID
        if type(GetQuestLink) == "function" then
            local ok, text = pcall(GetQuestLink, questID)
            if ok and text ~= nil then
                link = text
            end
        end
        shown = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    end
    if not shown then
        GameTooltip:ClearLines()
        local name = ""
        if owner.name and owner.name.GetText then
            local ok, text = pcall(owner.name.GetText, owner.name)
            if ok and type(text) == "string" then
                name = text
            end
        end
        GameTooltip:SetText(name, 1, 0.82, 0.29)
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, GameTooltip)
    end
    pcall(GameTooltip.Show, GameTooltip)
end

function Quests.OnQuestData(questID)
    if type(questID) ~= "number" or not GameTooltip or not GameTooltip.IsShown then
        return
    end
    local shownOk, shown = pcall(GameTooltip.IsShown, GameTooltip)
    if not shownOk or not shown or not GameTooltip.GetOwner then
        return
    end
    local ownerOk, owner = pcall(GameTooltip.GetOwner, GameTooltip)
    if not ownerOk or not owner or owner.questID ~= questID then
        return
    end
    local overOk, over = pcall(owner.IsMouseOver, owner)
    if overOk and over then
        ShowQuestTip(owner, questID)
    end
end

local function Query(text)
    if not text or text == "" then
        return ""
    end
    return string.lower(text)
end

local function Hit(query, text)
    if query == "" then
        return true
    end
    if not text or text == "" then
        return false
    end
    return string.find(string.lower(text), query, 1, true) ~= nil
end

function Quests.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { header = {}, columns = {}, quest = {}, note = {} }
    frame.used = { header = 0, columns = 0, quest = 0, note = 0 }
    frame.offset = 0
    frame.layout = {}
    frame.searching = false

    local bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", -2, -4)
    bar:SetPoint("BOTTOMRIGHT", -2, 4)
    bar:SetFrameLevel(40)
    bar:EnableMouse(true)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.16, 0.13, 0.08, 0.95)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.95)
    thumb:SetSize(12, 36)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    frame.bar = bar

    local function Wheel(self, delta)
        local page = self.page or self
        if page and page.ScrollBy then
            page:ScrollBy(delta)
        end
    end

    local function MakeHeader(owner)
        local row = CreateFrame("Button", nil, owner)
        row:SetHeight(HEADER)
        row.chevron = row:CreateTexture(nil, "ARTWORK")
        row.chevron:SetSize(14, 14)
        row.chevron:SetPoint("LEFT", 0, 0)
        row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
        row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
        row.title = row:CreateFontString(nil, "OVERLAY")
        row.title:SetPoint("LEFT", row.chevron, "RIGHT", 6, 0)
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(false)
        Theme.Font(row.title, 15, Theme.GOLD, "OUTLINE")
        row.title:SetText("Current")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        row:SetScript("OnClick", function(button)
            if button.page and button.page.searching then
                return
            end
            local id = button.sectionId
            if not id or not button.page then
                return
            end
            button.page.open[id] = button.page.open[id] == false
            button.page:Refresh(button.page.record, button.page.queryText)
        end)
        return row
    end

    local function MakeNote(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(NOTE)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetJustifyH("LEFT")
        Theme.Font(row.text, 13, Theme.DIM, "")
        row.text:SetText("Not scanned yet")
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        return row
    end

    local function MakeColumns(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(COLS)
        row.quest = row:CreateFontString(nil, "OVERLAY")
        row.quest:SetPoint("LEFT", 4, 0)
        row.quest:SetJustifyH("LEFT")
        Theme.Font(row.quest, 12, Theme.WHITE, "OUTLINE")
        row.quest:SetText("Quest")
        row.level = row:CreateFontString(nil, "OVERLAY")
        row.level:SetPoint("RIGHT", -8, 0)
        row.level:SetJustifyH("RIGHT")
        row.level:SetWordWrap(false)
        Theme.Font(row.level, 12, Theme.WHITE, "OUTLINE")
        row.level:SetText("Level")
        row.date = row:CreateFontString(nil, "OVERLAY")
        row.date:SetPoint("RIGHT", -8, 0)
        row.date:SetJustifyH("RIGHT")
        row.date:SetWordWrap(false)
        Theme.Font(row.date, 12, Theme.WHITE, "OUTLINE")
        row.date:SetText("Date")
        row.date:Hide()
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        return row
    end

    local function MakeQuest(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(ROW)
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        Theme.Font(row.name, 13, Theme.CREAM, "")
        row.name:SetText("")
        row.level = row:CreateFontString(nil, "OVERLAY")
        row.level:SetPoint("RIGHT", -8, 0)
        row.level:SetJustifyH("RIGHT")
        row.level:SetWordWrap(false)
        Theme.Font(row.level, 13, Theme.CREAM, "")
        row.level:SetText("")
        row.date = row:CreateFontString(nil, "OVERLAY")
        row.date:SetPoint("RIGHT", -8, 0)
        row.date:SetJustifyH("RIGHT")
        row.date:SetWordWrap(false)
        Theme.Font(row.date, 13, Theme.CREAM, "")
        row.date:SetText("")
        row.date:Hide()
        row.hit = CreateFrame("Button", nil, row)
        row.hit:SetPoint("TOPLEFT", row.name, "TOPLEFT", -2, 4)
        row.hit:SetPoint("BOTTOMRIGHT", row.name, "BOTTOMRIGHT", 2, -4)
        row.hit:EnableMouseWheel(true)
        row.hit:SetScript("OnMouseWheel", function(self, delta)
            Wheel(self:GetParent(), delta)
        end)
        row.hit:SetScript("OnEnter", function(self)
            local parent = self:GetParent()
            ShowQuestTip(parent, parent.questID)
        end)
        row.hit:SetScript("OnLeave", function(self)
            local parent = self:GetParent()
            if parent:IsMouseOver() then
                return
            end
            if GameTooltip and GameTooltip:GetOwner() == parent then
                GameTooltip:Hide()
            end
        end)
        row:EnableMouse(true)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        row:SetScript("OnEnter", function(self)
            ShowQuestTip(self, self.questID)
        end)
        row:SetScript("OnLeave", function(self)
            if self:IsMouseOver() then
                return
            end
            if GameTooltip and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end)
        row:SetScript("OnHide", function(self)
            if GameTooltip and GameTooltip:GetOwner() == self then
                GameTooltip:Hide()
            end
        end)
        return row
    end

    local function Acquire(kind, builder)
        local pool = frame.pools[kind]
        local count = frame.used[kind] + 1
        frame.used[kind] = count
        local row = pool[count]
        if not row then
            row = builder(frame)
            row.page = frame
            pool[count] = row
        end
        row:Show()
        return row
    end

    local function HidePool()
        local kinds = { "header", "columns", "quest", "note" }
        local kindIndex = 1
        while kinds[kindIndex] do
            local pool = frame.pools[kinds[kindIndex]]
            local index = 1
            while pool[index] do
                pool[index]:Hide()
                index = index + 1
            end
            kindIndex = kindIndex + 1
        end
        frame.used.header = 0
        frame.used.columns = 0
        frame.used.quest = 0
        frame.used.note = 0
    end

    function frame:ViewSize()
        local width = 0
        local height = 0
        local okW, w = pcall(self.GetWidth, self)
        local okH, h = pcall(self.GetHeight, self)
        if okW then
            local converted, measuredW = pcall(tonumber, w)
            if converted and type(measuredW) == "number" and measuredW >= 80 then
                width = measuredW
            end
        end
        if okH then
            local converted, measuredH = pcall(tonumber, h)
            if converted and type(measuredH) == "number" and measuredH >= 80 then
                height = measuredH
            end
        end
        if width < 80 then
            width = 640
        end
        if height < 80 then
            height = 400
        end
        return width, height
    end

    function frame:MaxOffset()
        local _, height = self:ViewSize()
        local maxOffset = (self.contentHeight or 0) - height + 8
        if maxOffset < 0 then
            maxOffset = 0
        end
        return maxOffset
    end

    local function PaintHeader(entry, top)
        local row = Acquire("header", MakeHeader)
        row.sectionId = entry.id
        row:SetHeight(entry.h or HEADER)
        row:SetWidth(entry.width)
        Theme.Font(row.title, entry.fontSize or 15, Theme.GOLD, "OUTLINE")
        row.title:SetText(entry.title or "")
        if entry.opened then
            row.chevron:SetRotation(0)
        else
            row.chevron:SetRotation(math.pi)
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    local function PaintColumns(entry, top)
        local row = Acquire("columns", MakeColumns)
        row:SetWidth(entry.width)
        Theme.Font(row.quest, 12, Theme.WHITE, "OUTLINE")
        row.quest:SetText("Quest")
        Theme.Font(row.level, 12, Theme.WHITE, "OUTLINE")
        row.level:SetText("Level")
        row.level:ClearAllPoints()
        row.date:ClearAllPoints()
        if entry.showDate then
            row.level:SetPoint("RIGHT", -124, 0)
            row.date:SetPoint("RIGHT", -8, 0)
            Theme.Font(row.date, 12, Theme.WHITE, "OUTLINE")
            row.date:SetText("Date")
            row.date:Show()
        else
            row.level:SetPoint("RIGHT", -8, 0)
            row.date:Hide()
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    local function PaintQuest(entry, top)
        local row = Acquire("quest", MakeQuest)
        row:SetWidth(entry.width)
        local levelStop = entry.showDate and 230 or 64
        Theme.Font(row.name, 13, Theme.CREAM, "")
        row.name:SetText(entry.name or "")
        row.name:SetWidth(math.max(40, entry.width - levelStop))
        local number = nil
        if type(entry.level) == "number" and entry.level > 0 then
            number = tostring(entry.level)
        end
        local level = number or ""
        if number and entry.activity and entry.activity ~= "" then
            level = number .. " " .. entry.activity
        elseif entry.activity and entry.activity ~= "" then
            level = entry.activity
        end
        Theme.Font(row.level, 13, Theme.CREAM, "")
        row.level:SetText(level)
        row.level:ClearAllPoints()
        row.date:ClearAllPoints()
        if entry.showDate then
            row.level:SetPoint("RIGHT", -124, 0)
            local when = entry.completedAt
            local dateText = ""
            if type(when) == "number" and when > 0 then
                dateText = date("%b %d, %Y", when)
            end
            Theme.Font(row.date, 13, Theme.CREAM, "")
            row.date:SetText(dateText)
            row.date:SetPoint("RIGHT", -8, 0)
            row.date:Show()
        else
            row.level:SetPoint("RIGHT", -8, 0)
            row.date:Hide()
        end
        row.questID = entry.questID
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    local function PaintNote(entry, top)
        local row = Acquire("note", MakeNote)
        row:SetWidth(entry.width)
        Theme.Font(row.text, 13, Theme.DIM, "")
        row.text:SetText(entry.text or "")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    function frame:Place()
        local _, height = self:ViewSize()
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
        end
        if (self.offset or 0) < 0 then
            self.offset = 0
        end
        HidePool()
        local offset = self.offset or 0
        local layout = self.layout
        local index = 1
        while layout and layout[index] do
            local entry = layout[index]
            local top = -(entry.y or 0) + offset
            if top < 8 and top > -(height + (entry.h or 4)) then
                if entry.kind == "header" then
                    PaintHeader(entry, top)
                elseif entry.kind == "columns" then
                    PaintColumns(entry, top)
                elseif entry.kind == "quest" then
                    PaintQuest(entry, top)
                else
                    PaintNote(entry, top)
                end
            end
            index = index + 1
        end
        self.bar:SetFrameLevel((self:GetFrameLevel() or 1) + 40)
        self.barGuard = true
        self.bar:SetMinMaxValues(0, maxOffset)
        self.bar:SetValue(self.offset or 0)
        self.barGuard = false
        if maxOffset <= 1 then
            self.bar:Hide()
        else
            self.bar:Show()
        end
    end

    function frame:ScrollBy(delta)
        local offset = (self.offset or 0) - (delta * 48)
        if offset < 0 then
            offset = 0
        end
        local maxOffset = self:MaxOffset()
        if offset > maxOffset then
            offset = maxOffset
        end
        self.offset = offset
        self:Place()
    end

    bar:SetScript("OnValueChanged", function(_, value)
        if frame.barGuard then
            return
        end
        local offset = value or 0
        if offset < 0 then
            offset = 0
        end
        frame.offset = offset
        frame:Place()
    end)
    pcall(frame.SetClipsChildren, frame, true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        self:ScrollBy(delta)
    end)

    local function IsOpen(id)
        return frame.open[id] ~= false
    end

    local function Add(layout, entry, y)
        entry.y = y
        layout[#layout + 1] = entry
        return y + (entry.h or ROW) + (entry.gap or 2)
    end

    local function Group(list, query)
        local order = {}
        local zones = {}
        local loose = {}
        local had = false
        local index = 1
        while type(list) == "table" and list[index] do
            had = true
            local entry = list[index]
            if Hit(query, entry.name) then
                local zone = entry.zone
                if type(zone) == "string" and zone ~= "" then
                    local bucket = zones[zone]
                    if not bucket then
                        bucket = {}
                        zones[zone] = bucket
                        order[#order + 1] = zone
                    end
                    bucket[#bucket + 1] = entry
                else
                    loose[#loose + 1] = entry
                end
            end
            index = index + 1
        end
        return order, zones, loose, had
    end

    local function ByName(left, right)
        return (left.name or "") < (right.name or "")
    end

    local function AddRows(layout, rows, y, x, width, dated)
        local index = 1
        while rows[index] do
            local quest = rows[index]
            y = Add(layout, {
                kind = "quest",
                x = x,
                h = ROW,
                width = width,
                gap = 2,
                name = quest.name,
                questID = quest.questID,
                level = quest.level,
                activity = quest.activity,
                completedAt = quest.completedAt,
                showDate = dated and true or false,
            }, y)
            index = index + 1
        end
        return y
    end

    local function Child(node, name)
        local found = node.kids[name]
        if not found then
            found = { quests = {}, order = {}, kids = {} }
            node.kids[name] = found
            node.order[#node.order + 1] = name
        end
        return found
    end

    local function Tree(rows)
        local root = { quests = {}, order = {}, kids = {} }
        local index = 1
        while rows[index] do
            local entry = rows[index]
            local node = root
            if type(entry.world) == "string" and entry.world ~= "" then
                node = Child(node, entry.world)
            end
            if type(entry.content) == "string" and entry.content ~= "" and entry.content ~= entry.world then
                node = Child(node, entry.content)
            end
            if type(entry.zone) == "string" and entry.zone ~= "" and entry.zone ~= entry.content and entry.zone ~= entry.world then
                node = Child(node, entry.zone)
            end
            node.quests[#node.quests + 1] = entry
            index = index + 1
        end
        return root
    end

    local function RenderNode(layout, node, y, depth, idPrefix, rowWidth, dated)
        table.sort(node.order)
        table.sort(node.quests, ByName)
        local nameIndex = 1
        while node.order[nameIndex] do
            local name = node.order[nameIndex]
            local child = node.kids[name]
            local id = idPrefix .. "\n" .. name
            local x = 8 + (depth * 16)
            local opened = frame.searching or IsOpen(id)
            y = Add(layout, {
                kind = "header",
                x = x,
                h = 22,
                width = math.max(80, rowWidth - (x - 8)),
                gap = 2,
                id = id,
                title = name,
                fontSize = depth <= 2 and 14 or 13,
                opened = opened,
            }, y)
            if opened then
                y = RenderNode(layout, child, y, depth + 1, id, rowWidth, dated)
            end
            nameIndex = nameIndex + 1
        end
        if node.quests[1] then
            local x = 8 + ((depth + 1) * 16)
            y = AddRows(layout, node.quests, y, x, math.max(80, rowWidth - (x - 8)), dated)
        end
        return y
    end

    function frame:Refresh(record, queryText)
        if self.record ~= record then
            self.offset = 0
        end
        self.record = record
        self.queryText = queryText or ""
        local query = Query(self.queryText)
        self.searching = query ~= ""
        local width = self:ViewSize()
        local rowWidth = math.max(200, width - 36)
        local layout = {}
        local y = 4
        local pack = nil
        if record and BMGAM.Store and BMGAM.Store.Quests then
            pack = BMGAM.Store.Quests(record, false)
        elseif record then
            pack = record.quests
        end
        local scanned = type(pack) == "table" and pack.scanned == true
        if not scanned then
            y = Add(layout, {
                kind = "note",
                x = 8,
                h = NOTE,
                width = rowWidth,
                gap = 2,
                text = "Not scanned yet",
            }, y)
            self.layout = layout
            self.contentHeight = y
            self:Place()
            return
        end
        local sections = {
            {
                id = "current",
                title = "Current Quest",
                list = pack.current,
                empty = "No quests",
                ready = true,
            },
            {
                id = "completed",
                title = "Completed Quest",
                list = pack.completed,
                empty = "No completed quests",
                ready = pack.completedReady == true,
            },
        }
        local sectionIndex = 1
        while sections[sectionIndex] do
            local section = sections[sectionIndex]
            local order, zones, loose, had = Group(section.list, query)
            local any = order[1] or loose[1]
            local skip = query ~= "" and had and not any
            if not skip then
                local opened = query ~= "" or IsOpen(section.id)
                y = Add(layout, {
                    kind = "header",
                    x = 8,
                    h = HEADER,
                    width = rowWidth,
                    gap = 4,
                    id = section.id,
                    title = section.title,
                    fontSize = 15,
                    opened = opened,
                }, y)
                if opened then
                    local dated = section.id == "completed"
                    local characterRows = {}
                    local warbandRows = {}
                    local hadCharacter = false
                    local hadWarband = false
                    local list = section.list
                    local splitWarband = section.id == "completed"
                    local rowIndex = 1
                    while type(list) == "table" and list[rowIndex] do
                        local entry = list[rowIndex]
                        local entryName = entry.name
                        local hidden = entryName == "Tracking Quest" or (type(entryName) == "string" and (string.sub(entryName, 1, 5) == "[DNT]" or string.match(entryName, "^Level %d+$")))
                        local warband = splitWarband and entry.account
                        if not hidden then
                            if warband then
                                hadWarband = true
                                if Hit(query, entry.name) then
                                    warbandRows[#warbandRows + 1] = entry
                                end
                            else
                                hadCharacter = true
                                if Hit(query, entry.name) then
                                    characterRows[#characterRows + 1] = entry
                                end
                            end
                        end
                        rowIndex = rowIndex + 1
                    end
                    local buckets = {
                        { id = section.id .. "\ncharacter", title = "Character", rows = characterRows, had = hadCharacter },
                    }
                    if splitWarband then
                        buckets[2] = { id = section.id .. "\nwarband", title = "Warband", rows = warbandRows, had = hadWarband }
                    end
                    local bucketIndex = 1
                    while buckets[bucketIndex] do
                        local bucket = buckets[bucketIndex]
                        local bucketAny = bucket.rows[1]
                        local bucketSkip = query ~= "" and bucket.had and not bucketAny
                        if not bucketSkip then
                            local bucketOpen = query ~= "" or IsOpen(bucket.id)
                            y = Add(layout, {
                                kind = "header",
                                x = 24,
                                h = 22,
                                width = math.max(80, rowWidth - 16),
                                gap = 2,
                                id = bucket.id,
                                title = bucket.title,
                                fontSize = 14,
                                opened = bucketOpen,
                            }, y)
                            if bucketOpen then
                                if not bucketAny then
                                    if section.ready then
                                        y = Add(layout, {
                                            kind = "note",
                                            x = 40,
                                            h = NOTE,
                                            width = math.max(80, rowWidth - 32),
                                            gap = 2,
                                            text = "No quests",
                                        }, y)
                                    end
                                else
                                    y = RenderNode(layout, Tree(bucket.rows), y, 2, bucket.id, rowWidth, dated)
                                end
                            end
                        end
                        bucketIndex = bucketIndex + 1
                    end
                end
                y = y + 6
            end
            sectionIndex = sectionIndex + 1
        end
        self.layout = layout
        self.contentHeight = y
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
        end
        self:Place()
    end

    frame:SetScript("OnSizeChanged", function(self)
        if self.sizing then
            return
        end
        self.sizing = true
        self:Refresh(self.record, self.queryText)
        self.sizing = false
    end)

    frame:Refresh(nil, "")
    return frame
end
