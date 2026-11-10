local _, BMGAM = ...

BMGAM.Achievements = BMGAM.Achievements or {}
local Achievements = BMGAM.Achievements
local Theme = BMGAM.Theme

local HEADER = 26
local COLS = 18
local ROW = 20
local NOTE = 18

local MONTHS = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
}
local EARNED = { Theme.RGB(90, 255, 120) }

local function TipReady()
    if not GameTooltip or not GameTooltip.NumLines then
        return false
    end
    local ok, count = pcall(GameTooltip.NumLines, GameTooltip)
    if not ok or type(count) ~= "number" then
        return true
    end
    return count > 0
end

local function ShowAchievementTip(owner, achievementID)
    if type(achievementID) ~= "number" or not GameTooltip then
        return
    end
    local owned = pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_CURSOR_RIGHT", 16, 0)
    if not owned then
        pcall(GameTooltip.SetOwner, GameTooltip, owner, "ANCHOR_CURSOR")
    end
    local shown = false
    if type(GetAchievementLink) == "function" then
        local ok, link = pcall(GetAchievementLink, achievementID)
        if ok and link ~= nil then
            local linked = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
            if linked and TipReady() then
                shown = true
            end
        end
    end
    if not shown and GameTooltip.SetAchievementByID then
        local set = pcall(GameTooltip.SetAchievementByID, GameTooltip, achievementID)
        if set and TipReady() then
            shown = true
        end
    end
    if not shown and C_TooltipInfo and type(C_TooltipInfo.GetAchievementByID) == "function" then
        local ok, data = pcall(C_TooltipInfo.GetAchievementByID, achievementID)
        if ok and type(data) == "table" then
            if TooltipUtil and TooltipUtil.SurfaceArgs then
                pcall(TooltipUtil.SurfaceArgs, data)
            end
            if GameTooltip.ProcessInfo then
                shown = pcall(GameTooltip.ProcessInfo, GameTooltip, data)
            elseif GameTooltip.SetTooltipData then
                shown = pcall(GameTooltip.SetTooltipData, GameTooltip, data)
            end
        end
    end
    if not shown then
        GameTooltip:ClearLines()
        local title = ""
        if owner.name and owner.name.GetText then
            local textOk, text = pcall(owner.name.GetText, owner.name)
            if textOk and type(text) == "string" then
                title = text
            end
        end
        GameTooltip:SetText(title, Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
    end
    if TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, GameTooltip)
    end
    if not owner.earned then
        pcall(function()
            local progress = owner.progress
            if type(progress) ~= "string" or progress == "" then
                progress = "Not earned"
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("Status", progress, Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], Theme.CREAM[1], Theme.CREAM[2], Theme.CREAM[3])
            local needs = owner.needs
            if type(needs) == "table" and needs[1] then
                GameTooltip:AddLine("Requirements", Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
                local index = 1
                while needs[index] do
                    local need = needs[index]
                    local name = need.name or ""
                    if need.done then
                        GameTooltip:AddLine(name, Theme.DIM[1], Theme.DIM[2], Theme.DIM[3])
                    else
                        GameTooltip:AddLine(name, Theme.CREAM[1], Theme.CREAM[2], Theme.CREAM[3])
                    end
                    index = index + 1
                end
            end
        end)
    end
    pcall(GameTooltip.Show, GameTooltip)
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

local function DateText(row)
    if type(row) ~= "table" then
        return ""
    end
    local month = row.month
    local day = row.day
    local year = row.year
    if type(month) ~= "number" or type(day) ~= "number" or type(year) ~= "number" then
        return ""
    end
    local name = MONTHS[month]
    if not name then
        return ""
    end
    return name .. " " .. day .. ", " .. year
end

function Achievements.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { header = {}, columns = {}, achievement = {}, note = {} }
    frame.used = { header = 0, columns = 0, achievement = 0, note = 0 }
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
        row.title:SetText("Category")
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
            button.page.open[id] = not button.page.open[id]
            button.page:Refresh(button.page.record, button.page.queryText)
        end)
        return row
    end

    local function MakeColumns(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(COLS)
        row.points = row:CreateFontString(nil, "OVERLAY")
        row.points:SetWidth(48)
        row.points:SetJustifyH("RIGHT")
        row.points:SetWordWrap(false)
        Theme.Font(row.points, 12, Theme.WHITE, "OUTLINE")
        row.points:SetText("Points")
        row.date = row:CreateFontString(nil, "OVERLAY")
        row.date:SetWidth(110)
        row.date:SetJustifyH("RIGHT")
        row.date:SetWordWrap(false)
        Theme.Font(row.date, 12, Theme.WHITE, "OUTLINE")
        row.date:SetText("Date")
        row.who = row:CreateFontString(nil, "OVERLAY")
        row.who:SetWidth(140)
        row.who:SetJustifyH("RIGHT")
        row.who:SetWordWrap(false)
        Theme.Font(row.who, 12, Theme.WHITE, "OUTLINE")
        row.who:SetText("Who")
        row.who:SetPoint("RIGHT", -8, 0)
        row.date:SetPoint("RIGHT", row.who, "LEFT", -8, 0)
        row.points:SetPoint("RIGHT", row.date, "LEFT", -8, 0)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        return row
    end

    local function MakeAchievement(owner)
        local row = CreateFrame("Frame", nil, owner)
        row:SetHeight(ROW)
        row.chevron = row:CreateTexture(nil, "ARTWORK")
        row.chevron:SetSize(12, 12)
        row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
        row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
        row.chevron:Hide()
        row.name = row:CreateFontString(nil, "OVERLAY")
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        Theme.Font(row.name, 13, Theme.CREAM, "")
        row.name:SetText("Achievement")
        row.points = row:CreateFontString(nil, "OVERLAY")
        row.points:SetWidth(48)
        row.points:SetJustifyH("RIGHT")
        row.points:SetWordWrap(false)
        Theme.Font(row.points, 13, Theme.CREAM, "")
        row.points:SetText("")
        row.status = row:CreateFontString(nil, "OVERLAY")
        row.status:SetWidth(88)
        row.status:SetJustifyH("RIGHT")
        row.status:SetWordWrap(false)
        Theme.Font(row.status, 13, Theme.CREAM, "")
        row.status:SetText("")
        row.status:SetPoint("RIGHT", row.points, "LEFT", -8, 0)
        row.status:Hide()
        row.date = row:CreateFontString(nil, "OVERLAY")
        row.date:SetWidth(110)
        row.date:SetJustifyH("RIGHT")
        row.date:SetWordWrap(false)
        Theme.Font(row.date, 13, Theme.CREAM, "")
        row.date:SetText("")
        row.who = row:CreateFontString(nil, "OVERLAY")
        row.who:SetWidth(140)
        row.who:SetJustifyH("RIGHT")
        row.who:SetWordWrap(false)
        Theme.Font(row.who, 13, Theme.CREAM, "")
        row.who:SetText("")
        row.who:SetPoint("RIGHT", -8, 0)
        row.date:SetPoint("RIGHT", row.who, "LEFT", -8, 0)
        row.points:SetPoint("RIGHT", row.date, "LEFT", -8, 0)
        row.name:SetPoint("LEFT", 4, 0)
        row.name:SetPoint("RIGHT", row.points, "LEFT", -8, 0)
        row.hit = CreateFrame("Button", nil, row)
        row.hit:SetPoint("TOPLEFT", row.name, "TOPLEFT", -2, 4)
        row.hit:SetPoint("BOTTOMRIGHT", row.name, "BOTTOMRIGHT", 2, -4)
        row.hit:RegisterForClicks("LeftButtonUp")
        row.hit:EnableMouseWheel(true)
        row.hit:SetScript("OnMouseWheel", function(self, delta)
            Wheel(self:GetParent(), delta)
        end)
        row.hit:SetScript("OnEnter", function(self)
            local parent = self:GetParent()
            ShowAchievementTip(parent, parent.achievementID)
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
        row.hit:SetScript("OnClick", function(self)
            local parent = self:GetParent()
            if not parent.canOpen or not parent.openId or not parent.page then
                return
            end
            if parent.page.searching then
                return
            end
            parent.page.open[parent.openId] = not parent.page.open[parent.openId]
            parent.page:Refresh(parent.page.record, parent.page.queryText)
        end)
        row:EnableMouse(true)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        row:SetScript("OnMouseUp", function(self, button)
            if button ~= "LeftButton" or not self.canOpen or not self.openId or not self.page then
                return
            end
            if self.page.searching then
                return
            end
            self.page.open[self.openId] = not self.page.open[self.openId]
            self.page:Refresh(self.page.record, self.page.queryText)
        end)
        row:SetScript("OnEnter", function(self)
            ShowAchievementTip(self, self.achievementID)
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
        local kinds = { "header", "columns", "achievement", "note" }
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
        frame.used.achievement = 0
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
        Theme.Font(row.points, 12, Theme.WHITE, "OUTLINE")
        row.points:SetText("Points")
        Theme.Font(row.date, 12, Theme.WHITE, "OUTLINE")
        row.date:SetText("Date")
        Theme.Font(row.who, 12, Theme.WHITE, "OUTLINE")
        row.who:SetText("Who")
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", entry.x, top)
    end

    local function PaintAchievement(entry, top)
        local row = Acquire("achievement", MakeAchievement)
        row:SetWidth(entry.width)
        local color = Theme.WHITE
        local flags = ""
        if entry.objective then
            color = Theme.WHITE
            flags = ""
        elseif entry.earned then
            color = EARNED
            flags = "OUTLINE"
        else
            color = Theme.YELLOW
            flags = "OUTLINE"
        end
        Theme.Font(row.name, 13, color, flags)
        row.name:SetText(entry.name or "")
        row.name:ClearAllPoints()
        row.chevron:ClearAllPoints()
        row.who:ClearAllPoints()
        row.date:ClearAllPoints()
        row.points:ClearAllPoints()
        row.status:ClearAllPoints()
        local indent = entry.indent or 4
        local progress = entry.progress or ""
        if entry.objective then
            row.chevron:Hide()
            row.name:SetWordWrap(true)
            row.name:SetJustifyV("TOP")
            row.name:SetWidth(entry.textWidth or 200)
            row.name:SetPoint("TOPLEFT", indent, -2)
            row.points:Hide()
            local anchor = row
            local relative = "TOPRIGHT"
            local yOff = -2
            row.who:SetWidth(140)
            row.date:SetWidth(110)
            row.status:SetWidth(88)
            if entry.who and entry.who ~= "" then
                row.who:SetPoint("TOPRIGHT", anchor, relative, -8, yOff)
                row.who:Show()
                anchor = row.who
                relative = "TOPLEFT"
                yOff = 0
            else
                row.who:Hide()
            end
            if entry.dateText and entry.dateText ~= "" then
                row.date:SetPoint("TOPRIGHT", anchor, relative, -8, yOff)
                row.date:Show()
                anchor = row.date
                relative = "TOPLEFT"
                yOff = 0
            else
                row.date:Hide()
            end
            if type(progress) == "string" and progress ~= "" then
                Theme.Font(row.status, 13, Theme.WHITE, "")
                row.status:SetText(progress)
                row.status:SetPoint("TOPRIGHT", anchor, relative, -8, yOff)
                row.status:Show()
            else
                row.status:SetText("")
                row.status:Hide()
            end
            row:SetHeight(entry.h or ROW)
        else
            row.name:SetWordWrap(false)
            row.name:SetJustifyV("MIDDLE")
            row.points:Show()
            row.points:SetWidth(48)
            row.who:SetWidth(140)
            row.date:SetWidth(110)
            row.status:SetWidth(88)
            row.who:Show()
            row.date:Show()
            row.who:SetPoint("RIGHT", -8, 0)
            row.date:SetPoint("RIGHT", row.who, "LEFT", -8, 0)
            row.points:SetPoint("RIGHT", row.date, "LEFT", -8, 0)
            row.status:SetPoint("RIGHT", row.points, "LEFT", -8, 0)
            if entry.canOpen then
                row.chevron:SetPoint("LEFT", indent, 0)
                row.chevron:Show()
                if entry.opened then
                    row.chevron:SetRotation(0)
                else
                    row.chevron:SetRotation(math.pi)
                end
                row.name:SetPoint("LEFT", row.chevron, "RIGHT", 4, 0)
            else
                row.chevron:Hide()
                row.name:SetPoint("LEFT", indent, 0)
            end
            local nameLeft = indent
            if entry.canOpen then
                nameLeft = indent + 16
            end
            local nameRoom = 8 + 48 + 8 + 110 + 8 + 140 + 8
            if type(progress) == "string" and progress ~= "" then
                Theme.Font(row.status, 13, Theme.WHITE, "")
                row.status:SetText(progress)
                row.status:Show()
                nameRoom = nameRoom + 88 + 8
            else
                row.status:SetText("")
                row.status:Hide()
            end
            row.name:SetWidth(math.max(40, (entry.width or 400) - nameLeft - nameRoom))
            row:SetHeight(ROW)
        end
        local points = ""
        if type(entry.points) == "number" then
            points = tostring(entry.points)
        end
        Theme.Font(row.points, 13, color, flags)
        row.points:SetText(points)
        local side = entry.objective and Theme.WHITE or Theme.CREAM
        Theme.Font(row.date, 13, side, "")
        row.date:SetText(entry.dateText or "")
        Theme.Font(row.who, 13, side, "")
        row.who:SetText(entry.who or "")
        row.achievementID = entry.achievementID
        row.earned = entry.earned == true
        row.progress = entry.progress
        row.needs = entry.needs
        row.canOpen = entry.canOpen == true
        row.openId = entry.openId
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
                elseif entry.kind == "achievement" then
                    PaintAchievement(entry, top)
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

    local function Add(layout, entry, y)
        entry.y = y
        layout[#layout + 1] = entry
        return y + (entry.h or ROW) + (entry.gap or 2)
    end

    local function SortCategories(list)
        table.sort(list, function(a, b)
            local left = a.order or 5000
            local right = b.order or 5000
            if left == right then
                return (a.name or "") < (b.name or "")
            end
            return left < right
        end)
    end

    local function Build(pack)
        local byId = {}
        local children = {}
        local rows = {}
        local categories = pack.categories
        local index = 1
        while type(categories) == "table" and categories[index] do
            local cat = categories[index]
            if type(cat) == "table" and type(cat.id) == "number" then
                byId[cat.id] = cat
            end
            index = index + 1
        end
        index = 1
        while type(categories) == "table" and categories[index] do
            local cat = categories[index]
            if type(cat) == "table" and type(cat.id) == "number" then
                local parent = cat.parent
                if type(parent) ~= "number" or not byId[parent] then
                    parent = -1
                end
                local bucket = children[parent]
                if not bucket then
                    bucket = {}
                    children[parent] = bucket
                end
                bucket[#bucket + 1] = cat
            end
            index = index + 1
        end
        local parentId = next(children)
        while parentId do
            SortCategories(children[parentId])
            parentId = next(children, parentId)
        end
        local stored = pack.rows
        local byId = {}
        index = 1
        while type(stored) == "table" and stored[index] do
            local row = stored[index]
            if type(row) == "table" and type(row.id) == "number" then
                byId[row.id] = row
            end
            if type(row) == "table" and type(row.category) == "number" then
                local bucket = rows[row.category]
                if not bucket then
                    bucket = {}
                    rows[row.category] = bucket
                end
                bucket[#bucket + 1] = row
            end
            index = index + 1
        end
        return children, rows, byId
    end

    local function HasRows(cat, children, rows, memo)
        local cached = memo[cat.id]
        if cached ~= nil then
            return cached
        end
        local list = rows[cat.id]
        if list and list[1] then
            memo[cat.id] = true
            return true
        end
        local kids = children[cat.id]
        local index = 1
        while kids and kids[index] do
            if HasRows(kids[index], children, rows, memo) then
                memo[cat.id] = true
                return true
            end
            index = index + 1
        end
        memo[cat.id] = false
        return false
    end

    local function SubtreeHit(cat, query, children, rows, memo)
        local cached = memo[cat.id]
        if cached ~= nil then
            return cached
        end
        if Hit(query, cat.name) then
            memo[cat.id] = true
            return true
        end
        local list = rows[cat.id]
        local index = 1
        while list and list[index] do
            if Hit(query, list[index].name) or Hit(query, list[index].detail) then
                memo[cat.id] = true
                return true
            end
            index = index + 1
        end
        local kids = children[cat.id]
        index = 1
        while kids and kids[index] do
            if SubtreeHit(kids[index], query, children, rows, memo) then
                memo[cat.id] = true
                return true
            end
            index = index + 1
        end
        memo[cat.id] = false
        return false
    end

    local function RowHit(query, row)
        if Hit(query, row.name) or Hit(query, row.detail) then
            return true
        end
        local needs = row.needs
        local index = 1
        while type(needs) == "table" and needs[index] do
            if Hit(query, needs[index].name) then
                return true
            end
            index = index + 1
        end
        return false
    end

    local function LastStep(steps)
        local last = steps[1]
        local index = 2
        while steps[index] do
            last = steps[index]
            index = index + 1
        end
        return last
    end

    local function FocusStep(steps)
        local index = 1
        while steps[index] do
            if not steps[index].earned then
                return steps[index]
            end
            index = index + 1
        end
        return LastStep(steps)
    end

    local function StepLabel(row)
        if type(row.detail) == "string" and row.detail ~= "" then
            return row.detail
        end
        if type(row.needs) == "table" and row.needs[1] and row.needs[1].name then
            return row.needs[1].name
        end
        return row.name or ""
    end

    local function NeedWhen(need, byId)
        if not need.done or type(need.achievement) ~= "number" or type(byId) ~= "table" then
            return "", ""
        end
        local other = byId[need.achievement]
        if type(other) ~= "table" or not other.earned then
            return "", ""
        end
        local who = other.who
        if not who or who == "" then
            who = "Account Wide"
        end
        return DateText(other), who
    end

    local function ColumnReserve(dateText, who, left)
        local right = 8
        if type(who) == "string" and who ~= "" then
            right = right + 140 + 8
        end
        if type(dateText) == "string" and dateText ~= "" then
            right = right + 110 + 8
        end
        if type(left) == "string" and left ~= "" then
            right = right + 88 + 8
        end
        return right
    end

    local function ObjectiveHeight(text, textWidth)
        local measure = frame.measure
        if not measure then
            measure = frame:CreateFontString(nil, "OVERLAY")
            Theme.Font(measure, 13, Theme.WHITE, "")
            measure:SetJustifyH("LEFT")
            measure:SetJustifyV("TOP")
            measure:SetAlpha(0)
            frame.measure = measure
        end
        local width = textWidth
        if width < 80 then
            width = 80
        end
        measure:Show()
        measure:SetWordWrap(false)
        measure:SetWidth(4000)
        measure:SetText(text or "")
        local wideOk, wide = pcall(measure.GetStringWidth, measure)
        local px = wideOk and type(wide) == "number" and wide or width
        if px < 1 then
            px = width
        end
        local lines = math.ceil(px / width)
        if lines < 1 then
            lines = 1
        end
        measure:SetWordWrap(true)
        measure:SetWidth(width)
        local height = lines * 16
        local ok, measured = pcall(measure.GetStringHeight, measure)
        if ok and type(measured) == "number" and measured > height then
            height = measured
        end
        measure:Hide()
        local rowH = math.ceil(height + 6)
        if rowH < ROW then
            rowH = ROW
        end
        return rowH
    end

    local function AddObjective(layout, y, width, indent, text, dateText, who, left, achievementID)
        local textWidth = width - indent - ColumnReserve(dateText, who, left)
        if textWidth < 80 then
            textWidth = 80
        end
        return Add(layout, {
            kind = "achievement",
            objective = true,
            x = 4,
            indent = indent,
            h = ObjectiveHeight(text or "", textWidth),
            width = width,
            textWidth = textWidth,
            gap = 1,
            name = text or "",
            dateText = dateText or "",
            who = who or "",
            progress = left or "",
            achievementID = achievementID,
        }, y)
    end

    local function AddNeeds(layout, y, width, indent, needs, byId)
        local index = 1
        while type(needs) == "table" and needs[index] do
            local need = needs[index]
            local when, who = "", ""
            local left = ""
            if need.done then
                when, who = NeedWhen(need, byId)
            else
                left = need.left or ""
            end
            y = AddObjective(layout, y, width, indent, need.name, when, who, left, need.achievement)
            index = index + 1
        end
        return y
    end

    local function GroupRows(list, showAll, query)
        local order = {}
        local grouped = {}
        local index = 1
        while list and list[index] do
            local row = list[index]
            if showAll or RowHit(query, row) then
                local key = row.series
                if type(key) == "number" then
                    local bucket = grouped[key]
                    if not bucket then
                        bucket = { steps = {} }
                        grouped[key] = bucket
                        order[#order + 1] = bucket
                    end
                    bucket.steps[#bucket.steps + 1] = row
                else
                    order[#order + 1] = { single = row }
                end
            end
            index = index + 1
        end
        index = 1
        while order[index] do
            local bucket = order[index]
            if bucket.steps then
                table.sort(bucket.steps, function(a, b)
                    return (a.step or 0) < (b.step or 0)
                end)
            end
            index = index + 1
        end
        return order
    end

    local function RenderCategory(layout, cat, depth, y, width, query, children, rows, memo, filled, byId)
        if not HasRows(cat, children, rows, filled) then
            return y
        end
        if query ~= "" and not SubtreeHit(cat, query, children, rows, memo) then
            return y
        end
        local opened = query ~= "" or frame.open[cat.id] == true
        local x = 4 + (depth * 14)
        y = Add(layout, {
            kind = "header",
            id = cat.id,
            title = cat.name or "",
            opened = opened,
            x = x,
            fontSize = depth == 0 and 15 or 14,
            h = HEADER,
            width = math.max(80, width - x),
            gap = 2,
        }, y)
        if not opened then
            return y
        end
        local showAll = query == "" or Hit(query, cat.name)
        local list = rows[cat.id]
        local groups = GroupRows(list, showAll, query)
        if groups[1] then
            y = Add(layout, {
                kind = "columns",
                x = 4,
                h = COLS,
                width = width,
                gap = 2,
            }, y)
            local groupIndex = 1
            while groups[groupIndex] do
                local group = groups[groupIndex]
                local steps = group.steps
                local row = group.single or FocusStep(steps)
                local chain = steps and steps[2] ~= nil
                local last = chain and LastStep(steps) or row
                local earned = row.earned == true
                if chain then
                    earned = last.earned == true
                end
                local canOpen = chain or (type(row.needs) == "table" and row.needs[1] ~= nil)
                local openId = chain and ("s" .. tostring(steps[1].series or steps[1].id)) or ("a" .. tostring(row.id))
                local opened = canOpen and (query ~= "" or frame.open[openId] == true)
                local progress = ""
                local dateText = ""
                local who = ""
                if earned then
                    dateText = DateText(chain and last or row)
                    who = (chain and last or row).who
                    if not who or who == "" then
                        who = "Account Wide"
                    end
                else
                    progress = (chain and FocusStep(steps) or row).progress or ""
                end
                y = Add(layout, {
                    kind = "achievement",
                    x = 4,
                    indent = x + 22,
                    h = ROW,
                    width = width,
                    gap = 1,
                    name = (chain and steps[1].name) or row.name,
                    achievementID = (chain and (earned and last.id or row.id)) or row.id,
                    points = (chain and (earned and last.points or row.points)) or row.points,
                    earned = earned,
                    progress = progress,
                    needs = row.needs,
                    dateText = dateText,
                    who = earned and who or "",
                    canOpen = canOpen,
                    opened = opened,
                    openId = openId,
                }, y)
                if opened and chain then
                    local stepIndex = 1
                    while steps[stepIndex] do
                        local step = steps[stepIndex]
                        local stepWho = ""
                        local stepDate = ""
                        local stepLeft = ""
                        if step.earned then
                            stepDate = DateText(step)
                            stepWho = step.who
                            if not stepWho or stepWho == "" then
                                stepWho = "Account Wide"
                            end
                        else
                            stepLeft = step.progress or ""
                            if stepLeft == "" and type(step.needs) == "table" and step.needs[1] and not step.needs[1].done then
                                stepLeft = step.needs[1].left or ""
                            end
                        end
                        y = AddObjective(layout, y, width, x + 48, StepLabel(step), stepDate, stepWho, stepLeft, step.id)
                        if not step.earned and type(step.needs) == "table" and step.needs[2] then
                            y = AddNeeds(layout, y, width, x + 66, step.needs, byId)
                        end
                        stepIndex = stepIndex + 1
                    end
                elseif opened then
                    y = AddNeeds(layout, y, width, x + 48, row.needs, byId)
                end
                groupIndex = groupIndex + 1
            end
        end
        local kids = children[cat.id]
        local index = 1
        while kids and kids[index] do
            y = RenderCategory(layout, kids[index], depth + 1, y, width, query, children, rows, memo, filled, byId)
            index = index + 1
        end
        return y
    end

    function frame:Refresh(record, queryText)
        if self.record ~= record or self.queryText ~= (queryText or "") then
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
        if record and BMGAM.Store and BMGAM.Store.Achievements then
            pack = BMGAM.Store.Achievements(record)
        elseif record then
            pack = record.achievements
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
        local children, rows, byId = Build(pack)
        local roots = children[-1]
        local filled = {}
        local memo = {}
        local index = 1
        local drew = false
        while roots and roots[index] do
            local before = y
            y = RenderCategory(layout, roots[index], 0, y, rowWidth, query, children, rows, memo, filled, byId)
            if y > before then
                drew = true
            end
            index = index + 1
        end
        if not drew then
            y = Add(layout, {
                kind = "note",
                x = 8,
                h = NOTE,
                width = rowWidth,
                gap = 2,
                text = "No achievements",
            }, y)
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
