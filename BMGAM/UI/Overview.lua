local _, BMGAM = ...

BMGAM.Overview = BMGAM.Overview or {}
local Overview = BMGAM.Overview
local Theme = BMGAM.Theme

local STATS = {
    { key = "strength", label = "Strength", percent = false },
    { key = "stamina", label = "Stamina", percent = false },
    { key = "armor", label = "Armor", percent = false },
    { key = "crit", label = "Critical Strike", percent = true },
    { key = "haste", label = "Haste", percent = true },
    { key = "mastery", label = "Mastery", percent = true },
    { key = "versatility", label = "Versatility", percent = true },
}

local JOURNEYS = {
    { key = "delver", title = "Delver's Journey", progress = "Delver's Progress" },
    { key = "prey", title = "Prey", progress = "Prey Progress" },
    { key = "traveler", title = "Traveler's Journey", progress = "Traveler's Journey Progress" },
}

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

local function Acquire(frame, kind, builder)
    local pool = frame.pools[kind]
    local count = frame.used[kind] + 1
    frame.used[kind] = count
    local row = pool[count]
    if not row then
        row = builder(frame.child)
        pool[count] = row
    end
    row:ClearAllPoints()
    row:Show()
    return row
end

local function HidePool(frame)
    for kind, pool in pairs(frame.pools) do
        local index = 1
        while pool[index] do
            pool[index]:Hide()
            index = index + 1
        end
        frame.used[kind] = 0
    end
end

local function MakeHeader(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(28)
    row.chevron = row:CreateTexture(nil, "ARTWORK")
    row.chevron:SetSize(14, 14)
    row.chevron:SetPoint("LEFT", 0, 0)
    row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
    row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetPoint("LEFT", row.chevron, "RIGHT", 6, 0)
    row.title:SetJustifyH("LEFT")
    Theme.Font(row.title, 14, Theme.GOLD, "OUTLINE")
    row.line = row:CreateTexture(nil, "ARTWORK")
    row.line:SetHeight(1)
    row.line:SetPoint("TOPLEFT", 0, -22)
    row.line:SetPoint("TOPRIGHT", 0, -22)
    row.line:SetColorTexture(Theme.LINE[1], Theme.LINE[2], Theme.LINE[3], 1)
    return row
end

local function MakePair(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row.left = row:CreateFontString(nil, "OVERLAY")
    row.left:SetPoint("LEFT", 20, 0)
    row.left:SetJustifyH("LEFT")
    row.right = row:CreateFontString(nil, "OVERLAY")
    row.right:SetPoint("RIGHT", -4, 0)
    row.right:SetJustifyH("RIGHT")
    return row
end

local function MakeSingle(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetPoint("LEFT", 20, 0)
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    return row
end

local function MakeProgress(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row.label = row:CreateFontString(nil, "OVERLAY")
    row.label:SetPoint("LEFT", 20, 0)
    Theme.Font(row.label, 12, Theme.YELLOW, "OUTLINE")
    row.value = row:CreateFontString(nil, "OVERLAY")
    row.value:SetPoint("LEFT", row.label, "RIGHT", 8, 0)
    Theme.Font(row.value, 12, Theme.WHITE, "OUTLINE")
    row.rankWord = row:CreateFontString(nil, "OVERLAY")
    row.rankWord:SetPoint("LEFT", row.value, "RIGHT", 10, 0)
    Theme.Font(row.rankWord, 12, Theme.YELLOW, "OUTLINE")
    row.rank = row:CreateFontString(nil, "OVERLAY")
    row.rank:SetPoint("LEFT", row.rankWord, "RIGHT", 6, 0)
    Theme.Font(row.rank, 12, Theme.WHITE, "OUTLINE")
    return row
end

local function MakeTalent(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(24)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 20, 0)
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", -4, 0)
    row.name:SetJustifyH("LEFT")
    Theme.Font(row.name, 13, Theme.YELLOW, "OUTLINE")
    row:SetScript("OnEnter", function(self)
        if self.talent then
            ShowTalentTip(self, self.talent)
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return row
end

local function ShowTalentTip(owner, talent)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local rank = talent.rank or 1
    local shown = false
    if talent.entryID and GameTooltip.SetTraitEntry then
        shown = pcall(GameTooltip.SetTraitEntry, GameTooltip, talent.entryID, rank)
    end
    if not shown and talent.entryID and GameTooltip.AppendInfo then
        GameTooltip:ClearLines()
        GameTooltip:SetText(talent.name or "", Theme.YELLOW[1], Theme.YELLOW[2], Theme.YELLOW[3])
        shown = pcall(GameTooltip.AppendInfo, GameTooltip, "GetTraitEntry", talent.entryID, rank)
    end
    if not shown then
        GameTooltip:ClearLines()
        GameTooltip:AddLine(talent.name or "", Theme.YELLOW[1], Theme.YELLOW[2], Theme.YELLOW[3])
    end
    GameTooltip:Show()
end

function Overview.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", -16, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(100, 40)
    scroll:SetScrollChild(child)
    Theme.AttachScroll(scroll)
    frame.scroll = scroll
    frame.child = child
    frame.open = {}
    frame.pools = { header = {}, pair = {}, single = {}, progress = {}, talent = {} }
    frame.used = { header = 0, pair = 0, single = 0, progress = 0, talent = 0 }
    frame.Refresh = Overview.Refresh
    return frame
end

local function IsOpen(frame, id)
    if frame.open[id] == nil then
        return true
    end
    return frame.open[id]
end

local function PlaceHeader(frame, y, width, id, title, query, childHit)
    local show = (query == "") or Hit(query, title) or childHit
    if not show then
        return y, false, nil
    end
    local row = Acquire(frame, "header", MakeHeader)
    row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -y)
    row:SetWidth(width)
    row.title:SetText(title)
    local opened = IsOpen(frame, id)
    if opened then
        row.chevron:SetRotation(0)
    else
        row.chevron:SetRotation(math.pi)
    end
    row:SetScript("OnClick", function()
        frame.open[id] = not IsOpen(frame, id)
        frame:Refresh(frame.record, frame.query)
    end)
    return y + 30, opened, row
end

function Overview.Refresh(frame, record, queryText)
    if not frame then
        return
    end
    frame.record = record
    frame.query = queryText or ""
    local query = Query(frame.query)
    HidePool(frame)
    local width = frame.scroll:GetWidth()
    if not width or width < 80 then
        width = 400
    end
    frame.child:SetWidth(width)
    if not record then
        frame.child:SetHeight(8)
        frame.scroll.UpdateScroll()
        return
    end

    local y = 4
    local function Pair(leftLabel, leftValue, leftHit)
        if not leftHit then
            return
        end
        local row = Acquire(frame, "pair", MakePair)
        row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -y)
        row:SetWidth(width)
        Theme.Font(row.left, 13, Theme.YELLOW, "OUTLINE")
        Theme.Font(row.right, 13, Theme.WHITE, "OUTLINE")
        row.left:SetText(leftLabel)
        row.right:SetText(leftValue or "")
        y = y + 20
    end

    if Hit(query, "Class") or Hit(query, record.className) then
        Pair("Class", record.className or "", true)
    end
    if record.heroName and (Hit(query, "Hero") or Hit(query, record.heroName)) then
        Pair("Hero", record.heroName, true)
    end
    if record.specName and (Hit(query, "Specialization") or Hit(query, record.specName)) then
        Pair("Specialization", record.specName, true)
    end
    if y > 4 then
        y = y + 6
    end

    local stats = record.stats or {}
    local statHits = {}
    local anyStat = false
    local index = 1
    while STATS[index] do
        local stat = STATS[index]
        local number = stats[stat.key] or 0
        local shown = stat.percent and (tostring(number) .. "%") or BMGAM.Scan.Comma(number)
        local matched = Hit(query, stat.label) or Hit(query, shown)
        statHits[index] = matched
        if matched then
            anyStat = true
        end
        index = index + 1
    end
    local statsOpen, statsHeader
    y, statsOpen, statsHeader = PlaceHeader(frame, y, width, "stats", "Stats", query, anyStat)
    if statsOpen then
        index = 1
        while STATS[index] do
            if statHits[index] then
                local stat = STATS[index]
                local number = stats[stat.key] or 0
                local shown = stat.percent and (tostring(number) .. "%") or BMGAM.Scan.Comma(number)
                local row = Acquire(frame, "pair", MakePair)
                row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -y)
                row:SetWidth(width)
                Theme.Font(row.left, 12, Theme.YELLOW, "OUTLINE")
                Theme.Font(row.right, 12, Theme.WHITE, "OUTLINE")
                row.left:SetText(stat.label)
                row.right:SetText(shown)
                y = y + 18
            end
            index = index + 1
        end
        y = y + 6
    end

    local guildName = record.guildName
    local guildText = (guildName and guildName ~= "") and guildName or "Not in Guild"
    local guildHit = Hit(query, "Guild") or Hit(query, guildText)
    local columnWidth = math.floor(width / 2) - 8
    local columnX = columnWidth + 16
    local guildOpen, guildHeader
    y, guildOpen, guildHeader = PlaceHeader(frame, y, width, "guild", "Guild", query, guildHit)
    if guildOpen and guildHit and guildHeader then
        local row = Acquire(frame, "single", MakeSingle)
        row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -y)
        row:SetWidth(width)
        Theme.Font(row.text, 13, Theme.WHITE, "OUTLINE")
        row.text:SetText(guildText)
        y = y + 22
    end
    if record.hearthstone and record.hearthstone ~= "" then
        local matched = Hit(query, "Hearthstone Location") or Hit(query, record.hearthstone)
        local rowY, opened, header = PlaceHeader(frame, y, width, "hearth", "Hearthstone Location", query, matched)
        if opened and matched and header then
            local row = Acquire(frame, "single", MakeSingle)
            row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -rowY)
            row:SetWidth(width)
            Theme.Font(row.text, 13, Theme.WHITE, "OUTLINE")
            row.text:SetJustifyH("LEFT")
            row.text:SetText(record.hearthstone)
            y = rowY + 22
        elseif header then
            y = rowY
        end
    end

    local function JourneyBlock(spec, columnX, columnWidth, startY)
        local data = record.journeys and record.journeys[spec.key]
        if not data then
            return startY
        end
        local progressText = BMGAM.Scan.Comma(data.current) .. " / " .. BMGAM.Scan.Comma(data.maximum)
        local rankText = tostring(data.rank or 0)
        local matched = Hit(query, spec.title) or Hit(query, spec.progress) or Hit(query, progressText) or Hit(query, rankText) or Hit(query, "Rank")
        local rowY, opened, header = PlaceHeader(frame, startY, columnWidth, spec.key, spec.title, query, matched)
        if header then
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", frame.child, "TOPLEFT", columnX, -startY)
            header:SetWidth(columnWidth)
        end
        if not header then
            return startY
        end
        if not opened or not matched then
            return startY + 30
        end
        local row = Acquire(frame, "progress", MakeProgress)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", columnX, -rowY)
        row:SetWidth(columnWidth)
        row.label:SetText(spec.progress)
        row.value:SetText(progressText)
        row.rankWord:SetText("Rank")
        row.rank:SetText(rankText)
        return rowY + 24
    end

    local leftY = y
    local rightY = y
    leftY = JourneyBlock(JOURNEYS[1], 0, columnWidth, leftY)
    rightY = JourneyBlock(JOURNEYS[2], columnX, columnWidth, rightY)
    y = math.max(leftY, rightY)
    leftY = y
    rightY = y
    leftY = JourneyBlock(JOURNEYS[3], 0, columnWidth, leftY)
    y = math.max(leftY, rightY) + 6

    local groups = {
        { id = "class", title = "Talents", tree = "class", requireRows = false },
        { id = "hero", title = "Hero talent", tree = "hero", requireRows = true },
        { id = "spec", title = "Specialization talent", tree = "spec", requireRows = false },
    }
    local talents = record.talents or {}
    local groupIndex = 1
    while groups[groupIndex] do
        local group = groups[groupIndex]
        local rows = {}
        local talentIndex = 1
        while talents[talentIndex] do
            local talent = talents[talentIndex]
            if talent.tree == group.tree then
                rows[#rows + 1] = talent
            end
            talentIndex = talentIndex + 1
        end
        local showGroup = (not group.requireRows) or (#rows > 0) or (group.tree == "hero" and record.heroName)
        if group.tree == "hero" and #rows == 0 and not record.heroName then
            showGroup = false
        end
        if showGroup then
            local anyRow = false
            local rowHit = {}
            local rowIndex = 1
            while rows[rowIndex] do
                rowHit[rowIndex] = Hit(query, rows[rowIndex].name)
                if rowHit[rowIndex] then
                    anyRow = true
                end
                rowIndex = rowIndex + 1
            end
            local opened
            y, opened = PlaceHeader(frame, y, width, group.id, group.title, query, anyRow or Hit(query, group.title))
            if opened then
                rowIndex = 1
                while rows[rowIndex] do
                    if rowHit[rowIndex] then
                        local talent = rows[rowIndex]
                        local row = Acquire(frame, "talent", MakeTalent)
                        row:SetPoint("TOPLEFT", frame.child, "TOPLEFT", 0, -y)
                        row:SetWidth(width)
                        row.name:SetText(talent.name or "")
                        if BMGAM.Scan.ApplyTalentIcon(row.icon, talent.entryID) then
                            row.icon:Show()
                        else
                            row.icon:SetTexture(nil)
                            row.icon:Hide()
                        end
                        row.talent = talent
                        row:SetScript("OnEnter", function(self)
                            ShowTalentTip(self, self.talent)
                        end)
                        y = y + 26
                    end
                    rowIndex = rowIndex + 1
                end
                y = y + 4
            end
        end
        groupIndex = groupIndex + 1
    end

    frame.child:SetHeight(math.max(8, y + 8))
    frame.scroll.UpdateScroll()
end
