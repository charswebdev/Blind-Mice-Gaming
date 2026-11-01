local _, BMGAM = ...

BMGAM.Vault = BMGAM.Vault or {}
local Vault = BMGAM.Vault
local Theme = BMGAM.Theme

local HEADER = 26
local SLOT_H = 86
local NOTE = 18
local READY = { Theme.RGB(90, 255, 120) }

local ACTIVITIES = {
    { id = "Raid", title = "Raids", pattern = "WEEKLY_REWARDS_THRESHOLD_RAID", unit = "bosses" },
    { id = "Activities", title = "Dungeons", pattern = "WEEKLY_REWARDS_THRESHOLD_DUNGEONS", unit = "dungeons" },
    { id = "World", title = "World", pattern = "WEEKLY_REWARDS_THRESHOLD_WORLD", unit = "activities" },
    { id = "RankedPvP", title = "PvP", pattern = "WEEKLY_REWARDS_THRESHOLD_PVP", unit = "matches" },
}

local function AsNumber(value)
    if type(issecretvalue) == "function" and issecretvalue(value) then
        if type(canaccessvalue) ~= "function" or not canaccessvalue(value) then
            return nil
        end
    end
    local ok, number = pcall(tonumber, value)
    if ok and type(number) == "number" then
        return number
    end
    return nil
end

local function SafeText(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    if type(issecretvalue) == "function" and issecretvalue(value) then
        if type(canaccessvalue) ~= "function" or not canaccessvalue(value) then
            return nil
        end
    end
    return value
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

local function ActivityId(name)
    local kinds = Enum and Enum.WeeklyRewardChestThresholdType
    if kinds and type(kinds[name]) == "number" then
        return kinds[name]
    end
    return nil
end

local function ActivityMeta(typeId)
    local index = 1
    while ACTIVITIES[index] do
        local row = ACTIVITIES[index]
        if ActivityId(row.id) == typeId or row.id == typeId then
            return row
        end
        index = index + 1
    end
    return nil
end

local function ItemLevelOf(link, itemID)
    if not C_Item or type(C_Item.GetDetailedItemLevelInfo) ~= "function" then
        return nil
    end
    if link then
        local levelOk, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
        local number = levelOk and AsNumber(level) or nil
        if number and number > 0 then
            return number
        end
    end
    if itemID then
        local levelOk, level = pcall(C_Item.GetDetailedItemLevelInfo, itemID)
        local number = levelOk and AsNumber(level) or nil
        if number and number > 0 then
            return number
        end
    end
    return nil
end

local function ExampleLink(rewardID)
    if not rewardID or not C_WeeklyRewards or type(C_WeeklyRewards.GetExampleRewardItemHyperlinks) ~= "function" then
        return nil
    end
    local ok, first = pcall(C_WeeklyRewards.GetExampleRewardItemHyperlinks, rewardID)
    if not ok or first == nil then
        return nil
    end
    if type(first) == "table" then
        return first[1]
    end
    return first
end

local function LevelFromLink(link)
    if link == nil or not C_Item or type(C_Item.GetDetailedItemLevelInfo) ~= "function" then
        return nil
    end
    local ok, level = pcall(C_Item.GetDetailedItemLevelInfo, link)
    if not ok then
        return nil
    end
    local number = AsNumber(level)
    if number and number > 0 then
        return number
    end
    if type(level) == "number" and level > 0 then
        return level
    end
    if C_TooltipInfo and type(C_TooltipInfo.GetHyperlink) == "function" then
        local tipOk, tip = pcall(C_TooltipInfo.GetHyperlink, link)
        local lines = tipOk and type(tip) == "table" and tip.lines or nil
        local lineIndex = 1
        while type(lines) == "table" and lines[lineIndex] do
            local line = lines[lineIndex]
            local text = type(line) == "table" and SafeText(line.leftText) or nil
            if text and string.find(string.lower(text), "item level", 1, true) then
                local found = tonumber(string.match(text, "(%d+)"))
                if found and found > 1 then
                    return found
                end
            end
            lineIndex = lineIndex + 1
        end
    end
    return nil
end

local pendingLevels = {}

local function RememberLevel(record, rewardID, level)
    local activities = record and record.vault and record.vault.activities
    local activityIndex = 1
    local changed = false
    while type(activities) == "table" and activities[activityIndex] do
        local slots = activities[activityIndex].slots
        local slotIndex = 1
        while type(slots) == "table" and slots[slotIndex] do
            if slots[slotIndex].rewardID == rewardID and (tonumber(slots[slotIndex].itemLevel) or 0) < 1 then
                slots[slotIndex].itemLevel = level
                changed = true
            end
            slotIndex = slotIndex + 1
        end
        activityIndex = activityIndex + 1
    end
    pendingLevels[rewardID] = nil
    if changed and BMGAM.Window and BMGAM.Window.tab == "vault" and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

local function WatchLink(record, rewardID, link)
    if pendingLevels[rewardID] or link == nil or not Item or type(Item.CreateFromItemLink) ~= "function" then
        return
    end
    local created, item = pcall(Item.CreateFromItemLink, Item, link)
    if not created or type(item) ~= "table" or type(item.ContinueOnLoad) ~= "function" then
        return
    end
    pendingLevels[rewardID] = true
    item:ContinueOnLoad(function()
        local level = LevelFromLink(link)
        if level and level > 0 then
            RememberLevel(record, rewardID, level)
        else
            pendingLevels[rewardID] = nil
        end
    end)
end

function Vault.PreviewItemLevel(rewardID)
    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        pcall(C_AddOns.LoadAddOn, "Blizzard_WeeklyRewards")
    end
    return LevelFromLink(ExampleLink(rewardID))
end

local function RewardItemLevel(activity, record)
    local rewardID = AsNumber(activity.id)
    local level = Vault.PreviewItemLevel(rewardID)
    if level and level > 0 then
        return level
    end
    local rewards = activity.rewards
    local itemType = Enum and Enum.CachedRewardType and Enum.CachedRewardType.Item or 1
    local index = 1
    while type(rewards) == "table" and rewards[index] do
        local reward = rewards[index]
        if type(reward) == "table" and AsNumber(reward.type) == itemType then
            local itemID = AsNumber(reward.id)
            local link = nil
            if reward.itemDBID and C_WeeklyRewards and type(C_WeeklyRewards.GetItemHyperlink) == "function" then
                local linkOk, value = pcall(C_WeeklyRewards.GetItemHyperlink, reward.itemDBID)
                if linkOk then
                    link = value
                end
            end
            level = LevelFromLink(link)
            if (not level or level < 1) and itemID then
                level = ItemLevelOf(nil, itemID)
            end
            if level and level > 0 then
                return level
            end
        end
        index = index + 1
    end
    WatchLink(record, rewardID, ExampleLink(rewardID))
    return nil
end

local function FillThreshold(pattern, threshold)
    if type(pattern) ~= "string" or pattern == "" then
        return nil
    end
    local ok, text = pcall(string.format, pattern, threshold)
    if ok and type(text) == "string" and text ~= "" and not string.find(text, "%", 1, true) then
        return text
    end
    local number = tostring(threshold)
    local replaced = string.gsub(pattern, "%%[0-9]*%$?d", number)
    replaced = string.gsub(replaced, "%%[0-9]*%$?s", number)
    if replaced ~= "" and not string.find(replaced, "%", 1, true) then
        return replaced
    end
    return nil
end

local function Requirement(meta, activity, progress, threshold)
    local pattern = nil
    if meta and meta.id == "Raid" then
        pattern = SafeText(activity.raidString)
    end
    if not pattern and meta and type(_G[meta.pattern]) == "string" then
        pattern = _G[meta.pattern]
    end
    local text = FillThreshold(pattern, threshold)
    if text then
        return text
    end
    local unit = meta and meta.unit or "activities"
    return tostring(progress) .. " of " .. tostring(threshold) .. " " .. unit
end

local function KeptLevel(record, activityId, slotIndex)
    local activities = record and record.vault and record.vault.activities
    local activityIndex = 1
    while type(activities) == "table" and activities[activityIndex] do
        local activity = activities[activityIndex]
        if type(activity) == "table" and activity.id == activityId and type(activity.slots) == "table" then
            local savedIndex = 1
            while activity.slots[savedIndex] do
                local saved = activity.slots[savedIndex]
                if type(saved) == "table" and (tonumber(saved.index) or savedIndex) == slotIndex then
                    local level = tonumber(saved.itemLevel) or 0
                    if level > 0 then
                        return level
                    end
                end
                savedIndex = savedIndex + 1
            end
        end
        activityIndex = activityIndex + 1
    end
    return nil
end

local function ReadSlots(meta, list, record)
    local slots = {}
    local index = 1
    while type(list) == "table" and list[index] do
        local activity = list[index]
        if type(activity) == "table" then
            local slot = AsNumber(activity.index) or index
            local progress = AsNumber(activity.progress) or 0
            local threshold = AsNumber(activity.threshold) or 0
            local tier = AsNumber(activity.level) or 0
            local rewardID = AsNumber(activity.id)
            local itemLevel = RewardItemLevel(activity, record) or 0
            if itemLevel < 1 then
                itemLevel = KeptLevel(record, meta.id, slot) or 0
            end
            local status = "locked"
            if threshold > 0 and progress >= threshold then
                status = "ready"
            end
            slots[#slots + 1] = {
                index = slot,
                status = status,
                tier = tier or "",
                rewardID = rewardID,
                itemLevel = itemLevel or 0,
                progress = progress,
                threshold = threshold,
                requirement = Requirement(meta, activity, progress, threshold),
            }
        end
        index = index + 1
    end
    table.sort(slots, function(a, b)
        return a.index < b.index
    end)
    return slots
end

local itemLevelTries = 0
local itemLevelWait = false

function Vault.Read()
    if not C_WeeklyRewards or type(C_WeeklyRewards.GetActivities) ~= "function" then
        return
    end
    if not UnitGUID or not BMGAM.DB or not BMGAM.DB.Get then
        return
    end
    local guid = UnitGUID("player")
    local record = guid and BMGAM.DB.Get(guid) or nil
    if not record then
        return
    end
    local activities = {}
    local order = 1
    while ACTIVITIES[order] do
        local meta = ACTIVITIES[order]
        local typeId = ActivityId(meta.id)
        local list = nil
        if typeId then
            local ok, value = pcall(C_WeeklyRewards.GetActivities, typeId)
            if ok and type(value) == "table" then
                list = value
            end
        end
        local slots = ReadSlots(meta, list, record)
        if slots[1] then
            activities[#activities + 1] = {
                id = meta.id,
                name = meta.title,
                slots = slots,
            }
        end
        order = order + 1
    end
    record.vault = {
        scanned = true,
        scannedAt = time(),
        activities = activities,
    }
    local missingLevel = false
    local activityIndex = 1
    while activities[activityIndex] and not missingLevel do
        local slots = activities[activityIndex].slots
        local slotIndex = 1
        while type(slots) == "table" and slots[slotIndex] do
            local info = slots[slotIndex]
            if (tonumber(info.itemLevel) or 0) < 1 then
                missingLevel = true
            end
            slotIndex = slotIndex + 1
        end
        activityIndex = activityIndex + 1
    end
    if missingLevel and itemLevelTries < 4 and not itemLevelWait and C_Timer and C_Timer.After then
        itemLevelTries = itemLevelTries + 1
        itemLevelWait = true
        C_Timer.After(0.6, function()
            itemLevelWait = false
            Vault.Read()
        end)
    else
        itemLevelTries = 0
    end
    if BMGAM.Window and BMGAM.Window.tab == "vault" and BMGAM.Window.Refresh then
        BMGAM.Window.Refresh()
    end
end

function Vault.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.offset = 0
    frame.headers = {}
    frame.slots = {}
    frame.notes = {}

    local function ScrollBy(delta)
        local height = frame:GetHeight()
        local maxOffset = (frame.contentHeight or 0) - height
        if maxOffset < 0 then
            maxOffset = 0
        end
        local nextOffset = frame.offset - (delta * 40)
        if nextOffset < 0 then
            nextOffset = 0
        end
        if nextOffset > maxOffset then
            nextOffset = maxOffset
        end
        frame.offset = nextOffset
        frame:Place()
    end

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        ScrollBy(delta)
    end)

    local function Acquire(pool, builder)
        local count = (pool.used or 0) + 1
        pool.used = count
        local row = pool[count]
        if not row then
            row = builder()
            pool[count] = row
        end
        row:Show()
        return row
    end

    local function HidePool(pool)
        local index = 1
        while pool[index] do
            pool[index]:Hide()
            index = index + 1
        end
        pool.used = 0
    end

    local function MakeHeader()
        local row = CreateFrame("Button", nil, frame)
        row:SetHeight(HEADER)
        row.chevron = row:CreateTexture(nil, "ARTWORK")
        row.chevron:SetSize(14, 14)
        row.chevron:SetPoint("LEFT", 4, 0)
        row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
        row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
        row.title = row:CreateFontString(nil, "OVERLAY")
        row.title:SetPoint("LEFT", row.chevron, "RIGHT", 6, 0)
        row.title:SetJustifyH("LEFT")
        Theme.Font(row.title, 15, Theme.GOLD, "OUTLINE")
        row:SetScript("OnClick", function(self)
            if frame.searching then
                return
            end
            local opened = frame.open[self.activityId]
            if opened == nil then
                opened = true
            end
            frame.open[self.activityId] = not opened
            frame:Refresh(frame.record, frame.queryText)
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            ScrollBy(delta)
        end)
        return row
    end

    local function MakeSlot()
        local row = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        row:SetHeight(SLOT_H)
        row.status = row:CreateFontString(nil, "OVERLAY")
        row.status:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -8)
        row.status:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -8)
        row.status:SetHeight(18)
        row.status:SetJustifyH("LEFT")
        row.status:SetJustifyV("TOP")
        row.status:SetWordWrap(false)
        row.tier = row:CreateFontString(nil, "OVERLAY")
        row.tier:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -28)
        row.tier:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -28)
        row.tier:SetHeight(18)
        row.tier:SetJustifyH("LEFT")
        row.tier:SetJustifyV("TOP")
        row.tier:SetWordWrap(false)
        row.need = row:CreateFontString(nil, "OVERLAY")
        row.need:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -48)
        row.need:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 6)
        row.need:SetJustifyH("LEFT")
        row.need:SetJustifyV("TOP")
        row.need:SetWordWrap(true)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            ScrollBy(delta)
        end)
        return row
    end

    local function MakeNote()
        local row = CreateFrame("Frame", nil, frame)
        row:SetHeight(NOTE)
        row.text = row:CreateFontString(nil, "OVERLAY")
        row.text:SetPoint("LEFT", 8, 0)
        Theme.Font(row.text, 13, Theme.DIM, "")
        return row
    end

    function frame:Place()
        local top = 4 + self.offset
        local index = 1
        while self.placed and self.placed[index] do
            local row = self.placed[index]
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", self, "TOPLEFT", row.placeX or 8, top - (row.placeY or 0))
            index = index + 1
        end
    end

    function frame:Refresh(record, queryText)
        self.record = record
        self.queryText = queryText or ""
        local query = Query(self.queryText)
        self.searching = query ~= ""
        HidePool(self.headers)
        HidePool(self.slots)
        HidePool(self.notes)
        self.placed = {}
        local width = self:GetWidth()
        if width < 200 then
            width = 640
        end
        local pack = record and record.vault
        if type(pack) ~= "table" or pack.scanned ~= true then
            local note = Acquire(self.notes, MakeNote)
            Theme.Font(note.text, 13, Theme.DIM, "")
            note.text:SetText("Not scanned yet")
            note.placeX = 8
            note.placeY = 4
            self.placed[1] = note
            self.contentHeight = 28
            self.offset = 0
            self:Place()
            return
        end
        local y = 4
        local drew = false
        local activities = pack.activities
        local activityIndex = 1
        while type(activities) == "table" and activities[activityIndex] do
            local activity = activities[activityIndex]
            local name = type(activity) == "table" and activity.name or nil
            if type(name) == "string" and name ~= "" and Hit(query, name) then
                drew = true
                local opened = self.open[activity.id]
                if opened == nil or self.searching then
                    opened = true
                end
                local header = Acquire(self.headers, MakeHeader)
                header.activityId = activity.id
                header:SetWidth(width - 16)
                Theme.Font(header.title, 15, Theme.GOLD, "OUTLINE")
                header.title:SetText(name)
                if opened then
                    header.chevron:SetRotation(0)
                else
                    header.chevron:SetRotation(math.pi)
                end
                header.placeX = 4
                header.placeY = y
                self.placed[#self.placed + 1] = header
                y = y + HEADER
                if opened and type(activity.slots) == "table" then
                    local count = #activity.slots
                    if count < 1 then
                        count = 1
                    end
                    local slotWidth = math.floor((width - 24 - ((count - 1) * 8)) / count)
                    if slotWidth < 120 then
                        slotWidth = 120
                    end
                    local slotIndex = 1
                    while activity.slots[slotIndex] do
                        local info = activity.slots[slotIndex]
                        local slot = Acquire(self.slots, MakeSlot)
                        local ready = info.status == "ready"
                        local color = ready and READY or Theme.CREAM
                        local border = ready and Theme.GOLD_BRIGHT or Theme.GOLD_DIM
                        Theme.Paint(slot, Theme.BG, border)
                        Theme.Font(slot.status, 13, color, "OUTLINE")
                        Theme.Font(slot.tier, 13, color, "OUTLINE")
                        Theme.Font(slot.need, 12, color, "OUTLINE")
                        local tierNumber = tonumber(info.tier) or 0
                        local itemLevel = tonumber(info.itemLevel) or 0
                        if itemLevel < 1 and info.rewardID and Vault.PreviewItemLevel then
                            itemLevel = Vault.PreviewItemLevel(info.rewardID) or 0
                            if itemLevel > 0 then
                                info.itemLevel = itemLevel
                            else
                                WatchLink(self.record, info.rewardID, ExampleLink(info.rewardID))
                            end
                        end
                        local progress = tonumber(info.progress) or 0
                        local threshold = tonumber(info.threshold) or 0
                        if itemLevel > 0 then
                            slot.tier:SetText("Item Level: " .. tostring(itemLevel))
                        else
                            slot.tier:SetText(" ")
                        end
                        if ready then
                            if tierNumber > 0 then
                                slot.status:SetText("Tier: " .. tostring(tierNumber))
                            else
                                slot.status:SetText("Tier:")
                            end
                        else
                            slot.status:SetText(tostring(progress) .. "/" .. tostring(threshold))
                        end
                        slot.need:SetText(info.requirement or "")
                        slot:SetWidth(slotWidth)
                        slot.placeX = 8 + ((slotIndex - 1) * (slotWidth + 8))
                        slot.placeY = y
                        self.placed[#self.placed + 1] = slot
                        slotIndex = slotIndex + 1
                    end
                    y = y + SLOT_H + 8
                end
            end
            activityIndex = activityIndex + 1
        end
        if not drew then
            local note = Acquire(self.notes, MakeNote)
            Theme.Font(note.text, 13, Theme.DIM, "")
            note.text:SetText("No vault activities")
            note.placeX = 8
            note.placeY = 4
            self.placed[1] = note
            y = 28
        end
        self.contentHeight = y
        local maxOffset = y - self:GetHeight()
        if maxOffset < 0 then
            maxOffset = 0
        end
        if self.offset > maxOffset then
            self.offset = maxOffset
        end
        self:Place()
    end

    return frame
end
