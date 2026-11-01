local _, BMGAM = ...

BMGAM.Professions = BMGAM.Professions or {}
local Professions = BMGAM.Professions
local Theme = BMGAM.Theme

local GROUP = 26
local HEADER = 34
local EXPANSION = 24
local ROW = 30

local QUALITY_COLOR = {
    [0] = { 157 / 255, 157 / 255, 157 / 255 },
    [1] = { 1, 1, 1 },
    [2] = { 30 / 255, 1, 0 },
    [3] = { 0, 112 / 255, 221 / 255 },
    [4] = { 163 / 255, 53 / 255, 238 / 255 },
    [5] = { 1, 128 / 255, 0 },
    [6] = { 230 / 255, 204 / 255, 128 / 255 },
    [7] = { 0, 204 / 255, 1 },
    [8] = { 0, 204 / 255, 1 },
}

local SLOT_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 2,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
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

local function NameClose(a, b)
    if type(a) ~= "string" or type(b) ~= "string" or a == "" or b == "" then
        return false
    end
    if a == b then
        return true
    end
    local left = string.lower(a)
    local right = string.lower(b)
    if string.find(left, right, 1, true) or string.find(right, left, 1, true) then
        return true
    end
    return false
end

local function SameProfession(row, other)
    if type(row) ~= "table" or type(other) ~= "table" then
        return false
    end
    if row.skillLine and (row.skillLine == other.skillLine or row.skillLine == other.altLine) then
        return true
    end
    if row.altLine and (row.altLine == other.skillLine or row.altLine == other.altLine) then
        return true
    end
    if NameClose(row.name, other.name) then
        return true
    end
    return false
end

local function Learned(recipe)
    return type(recipe) == "table" and recipe.learned ~= false
end

local function HasRecipe(prof, recipeID)
    if type(prof) ~= "table" or not recipeID then
        return false
    end
    local expansions = prof.expansions
    if type(expansions) == "table" then
        local expansionIndex = 1
        while expansions[expansionIndex] do
            local recipes = expansions[expansionIndex].recipes
            local recipeIndex = 1
            while type(recipes) == "table" and recipes[recipeIndex] do
                local recipe = recipes[recipeIndex]
                if recipe.id == recipeID and Learned(recipe) then
                    return true
                end
                recipeIndex = recipeIndex + 1
            end
            expansionIndex = expansionIndex + 1
        end
    end
    local recipes = prof.recipes
    local recipeIndex = 1
    while type(recipes) == "table" and recipes[recipeIndex] do
        if recipes[recipeIndex].id == recipeID and Learned(recipes[recipeIndex]) then
            return true
        end
        recipeIndex = recipeIndex + 1
    end
    return false
end

local function JoinNames(names)
    local text = ""
    local index = 1
    while names[index] do
        if text ~= "" then
            text = text .. ", "
        end
        text = text .. names[index]
        index = index + 1
    end
    return text
end

local function SameCharacter(record, viewed)
    if record == viewed then
        return true
    end
    if type(record) ~= "table" or type(viewed) ~= "table" then
        return false
    end
    local left = record.guid
    local right = viewed.guid
    if type(left) == "string" and type(right) == "string" and left == right then
        return true
    end
    return false
end

local function Knowers(prof, recipeID, viewed)
    local names = {}
    local seen = {}
    local list = BMGAM.DB.List()
    local index = 1
    while list[index] do
        local record = list[index]
        if not SameCharacter(record, viewed) and type(record.professions) == "table" then
            local professionIndex = 1
            while record.professions[professionIndex] do
                local other = record.professions[professionIndex]
                if SameProfession(prof, other) and HasRecipe(other, recipeID) then
                    local who = record.name
                    if type(who) == "string" and who ~= "" and not seen[who] then
                        seen[who] = true
                        names[#names + 1] = who
                    end
                end
                professionIndex = professionIndex + 1
            end
        end
        index = index + 1
    end
    return JoinNames(names)
end

local function SkillText(skill, maxSkill)
    if type(skill) == "number" and type(maxSkill) == "number" then
        return skill .. " / " .. maxSkill
    end
    return ""
end

local function QualityRGB(quality, link)
    if type(link) == "string" then
        local hex = link:match("|cff(%x%x%x%x%x%x)")
        if hex then
            local red = tonumber(hex:sub(1, 2), 16)
            local green = tonumber(hex:sub(3, 4), 16)
            local blue = tonumber(hex:sub(5, 6), 16)
            if red and green and blue then
                return red / 255, green / 255, blue / 255
            end
        end
        local marked = link:match("|cnIQ(%d+)")
        if marked then
            quality = tonumber(marked)
        end
    end
    if type(quality) == "number" and QUALITY_COLOR[quality] then
        local color = QUALITY_COLOR[quality]
        return color[1], color[2], color[3]
    end
    return 1, 1, 1
end

local function PaintQuality(frame, r, g, b)
    if not frame.SetBackdrop then
        return
    end
    frame:SetBackdrop(SLOT_BACKDROP)
    frame:SetBackdropColor(Theme.PANEL[1], Theme.PANEL[2], Theme.PANEL[3], 1)
    frame:SetBackdropBorderColor(r, g, b, 1)
end

local function ShowRecipeTip(owner, recipe)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    if recipe and recipe.id and GameTooltip.SetRecipeResultItem then
        local ok = pcall(GameTooltip.SetRecipeResultItem, GameTooltip, recipe.id)
        if ok then
            GameTooltip:Show()
            return
        end
    end
    if recipe and type(recipe.link) == "string" and recipe.link ~= "" then
        local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, recipe.link)
        if ok then
            GameTooltip:Show()
            return
        end
    end
    GameTooltip:Hide()
end

local function MakeGroup(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(GROUP)
    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetPoint("LEFT", 0, 0)
    row.title:SetJustifyH("LEFT")
    Theme.Font(row.title, 15, Theme.GOLD, "OUTLINE")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeHeader(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(HEADER)
    row.chevron = row:CreateTexture(nil, "ARTWORK")
    row.chevron:SetSize(14, 14)
    row.chevron:SetPoint("LEFT", 0, 0)
    row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
    row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
    row.iconPlate = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconPlate:SetSize(28, 28)
    row.iconPlate:SetPoint("LEFT", row.chevron, "RIGHT", 6, 0)
    Theme.Paint(row.iconPlate, Theme.PANEL, Theme.GOLD_DIM)
    row.icon = row.iconPlate:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    row.skill = row:CreateFontString(nil, "OVERLAY")
    row.skill:SetPoint("RIGHT", -4, 0)
    row.skill:SetJustifyH("RIGHT")
    Theme.Font(row.skill, 13, Theme.CREAM, "")
    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetPoint("LEFT", row.iconPlate, "RIGHT", 8, 0)
    row.title:SetPoint("RIGHT", row.skill, "LEFT", -8, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    Theme.Font(row.title, 14, Theme.GOLD, "OUTLINE")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeExpansion(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(EXPANSION)
    row.chevron = row:CreateTexture(nil, "ARTWORK")
    row.chevron:SetSize(12, 12)
    row.chevron:SetPoint("LEFT", 0, 0)
    row.chevron:SetTexture("Interface\\Buttons\\UI-SortArrow")
    row.chevron:SetVertexColor(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3])
    row.skill = row:CreateFontString(nil, "OVERLAY")
    row.skill:SetPoint("RIGHT", -4, 0)
    row.skill:SetJustifyH("RIGHT")
    Theme.Font(row.skill, 13, Theme.CREAM, "")
    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetPoint("LEFT", row.chevron, "RIGHT", 6, 0)
    row.title:SetPoint("RIGHT", row.skill, "LEFT", -8, 0)
    row.title:SetJustifyH("LEFT")
    row.title:SetWordWrap(false)
    Theme.Font(row.title, 13, Theme.GOLD, "OUTLINE")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeRecipe(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW)
    row.iconPlate = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.iconPlate:SetSize(26, 26)
    row.iconPlate:SetPoint("LEFT", 0, 0)
    row.icon = row.iconPlate:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    row.who = row:CreateFontString(nil, "OVERLAY")
    row.who:SetPoint("RIGHT", -2, 0)
    row.who:SetWidth(220)
    row.who:SetJustifyH("RIGHT")
    row.who:SetWordWrap(false)
    Theme.Font(row.who, 13, Theme.CREAM, "")
    row.missing = row:CreateFontString(nil, "OVERLAY")
    row.missing:SetWidth(70)
    row.missing:SetJustifyH("LEFT")
    row.missing:SetWordWrap(false)
    Theme.Font(row.missing, 13, Theme.GOLD, "")
    row.missing:SetText("Missing")
    row.name = row:CreateFontString(nil, "OVERLAY")
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    Theme.Font(row.name, 13, Theme.CREAM, "")
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeNote(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetPoint("LEFT", 0, 0)
    Theme.Font(row.text, 13, Theme.DIM, "")
    row.text:SetText("Not scanned yet")
    row:EnableMouseWheel(true)
    row:SetScript("OnMouseWheel", function(self, delta)
        if self.page and self.page.ScrollBy then
            self.page:ScrollBy(delta)
        end
    end)
    return row
end

local function MakeLine(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(1)
    row.texture = row:CreateTexture(nil, "ARTWORK")
    row.texture:SetAllPoints(row)
    row.texture:SetColorTexture(Theme.LINE[1], Theme.LINE[2], Theme.LINE[3], 0.85)
    return row
end

local function Acquire(frame, kind, builder)
    local pool = frame.pools[kind]
    local count = frame.used[kind] + 1
    frame.used[kind] = count
    local row = pool[count]
    if not row then
        row = builder(frame)
        row.page = frame
        pool[count] = row
    end
    row.placed = true
    row:Show()
    return row
end

local function HidePool(frame)
    local kinds = { "group", "header", "expansion", "recipe", "note", "line" }
    local kindIndex = 1
    while kinds[kindIndex] do
        local pool = frame.pools[kinds[kindIndex]]
        local index = 1
        while pool[index] do
            pool[index].placed = false
            pool[index]:Hide()
            index = index + 1
        end
        kindIndex = kindIndex + 1
    end
    frame.used.group = 0
    frame.used.header = 0
    frame.used.expansion = 0
    frame.used.recipe = 0
    frame.used.note = 0
    frame.used.line = 0
end

local function IsOpen(frame, id)
    if frame.open[id] == nil then
        return true
    end
    return frame.open[id]
end

local function PaintRecipe(row, recipe, missing, who)
    local red, green, blue = QualityRGB(recipe.quality, recipe.link)
    PaintQuality(row.iconPlate, red, green, blue)
    if type(recipe.icon) == "number" or type(recipe.icon) == "string" then
        row.icon:SetTexture(recipe.icon)
    else
        row.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    end
    row.icon:SetVertexColor(1, 1, 1)
    Theme.Font(row.name, 13, missing and Theme.GOLD or Theme.CREAM, "")
    row.name:SetText(recipe.name or "")
    Theme.Font(row.who, 13, Theme.CREAM, "")
    row.name:ClearAllPoints()
    row.missing:ClearAllPoints()
    row.who:ClearAllPoints()
    row.name:SetPoint("LEFT", row.iconPlate, "RIGHT", 8, 0)
    local reserve = 24
    if missing then
        reserve = 100
        if who and who ~= "" then
            reserve = 320
        end
    end
    local room = row:GetWidth() - reserve
    if room < 80 then
        room = 80
    end
    local textWidth = row.name:GetStringWidth()
    if not textWidth or textWidth < 1 then
        textWidth = room
    elseif textWidth > room then
        textWidth = room
    end
    row.name:SetWidth(textWidth + 2)
    if missing then
        row.missing:Show()
        row.missing:SetText("Missing")
        row.missing:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
        if who and who ~= "" then
            row.who:Show()
            row.who:SetJustifyH("LEFT")
            row.who:SetPoint("LEFT", row.missing, "RIGHT", 8, 0)
            row.who:SetWidth(220)
            row.who:SetText(who)
        else
            row.who:Hide()
            row.who:SetText("")
        end
    else
        row.missing:Hide()
        row.who:Hide()
        row.who:SetText("")
    end
    row.recipe = recipe
    row:SetScript("OnEnter", function(self)
        ShowRecipeTip(self, self.recipe)
    end)
end

local function Chevron(texture, opened)
    if opened then
        texture:SetRotation(0)
    else
        texture:SetRotation(math.pi)
    end
end

function Professions.Create(parent)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetAllPoints(parent)
    frame.open = {}
    frame.pools = { group = {}, header = {}, expansion = {}, recipe = {}, note = {}, line = {} }
    frame.used = { group = 0, header = 0, expansion = 0, recipe = 0, note = 0, line = 0 }
    frame.offset = 0

    local bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(8)
    bar:SetPoint("TOPRIGHT", -2, -4)
    bar:SetPoint("BOTTOMRIGHT", -2, 4)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(Theme.GOLD[1], Theme.GOLD[2], Theme.GOLD[3], 0.95)
    thumb:SetSize(8, 28)
    bar:SetThumbTexture(thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValue(0)
    frame.bar = bar

    function frame:ViewSize()
        local width = 0
        local height = 0
        local okW, w = pcall(self.GetWidth, self)
        local okH, h = pcall(self.GetHeight, self)
        if okW and type(w) == "number" and w >= 80 then
            width = w
        end
        if okH and type(h) == "number" and h >= 80 then
            height = h
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

    function frame:Place()
        local _, height = self:ViewSize()
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
        end
        if (self.offset or 0) < 0 then
            self.offset = 0
        end
        local offset = self.offset or 0
        local kinds = { "group", "header", "expansion", "recipe", "note", "line" }
        local kindIndex = 1
        while kinds[kindIndex] do
            local pool = self.pools[kinds[kindIndex]]
            local index = 1
            while pool[index] do
                local widget = pool[index]
                if widget.placed then
                    local top = -(widget.placeY or 0) + offset
                    if top < 8 and top > -(height + 4) then
                        widget:Show()
                        widget:ClearAllPoints()
                        widget:SetPoint("TOPLEFT", self, "TOPLEFT", widget.placeX or 0, top)
                    else
                        widget:Hide()
                    end
                end
                index = index + 1
            end
            kindIndex = kindIndex + 1
        end
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
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        self:ScrollBy(delta)
    end)

    function frame:Refresh(record, queryText)
        self.record = record
        self.query = Query(queryText)
        if record and UnitGUID and record.guid == UnitGUID("player") and type(record.professions) ~= "table" then
            if BMGAM.Scan and BMGAM.Scan.ReadProfessionList then
                pcall(BMGAM.Scan.ReadProfessionList)
            end
        end
        HidePool(self)
        local width = self:ViewSize()
        local y = 0
        local professions = record and record.professions
        local groups = {
            { title = "Primary Professions", primary = true },
            { title = "Secondary Professions", primary = false },
        }
        local groupIndex = 1
        while groups[groupIndex] do
            local group = groups[groupIndex]
            local shownGroup = false
            local index = 1
            while type(professions) == "table" and professions[index] do
                local prof = professions[index]
                local isPrimary = prof.primary ~= false
                if isPrimary == group.primary then
                    local professionHit = self.query == "" or Hit(self.query, prof.name)
                    local expansions = prof.expansions
                    local expansionCount = 0
                    if type(expansions) == "table" then
                        while expansions[expansionCount + 1] do
                            expansionCount = expansionCount + 1
                        end
                    end
                    local visibleExpansions = {}
                    local expansionIndex = 1
                    while expansionIndex <= expansionCount do
                        local expansion = expansions[expansionIndex]
                        local expansionHit = professionHit or Hit(self.query, expansion.name)
                        local recipes = {}
                        local recipeIndex = 1
                        local stored = expansion.recipes
                        while expansion.scanned and type(stored) == "table" and stored[recipeIndex] do
                            local recipe = stored[recipeIndex]
                            if expansionHit or Hit(self.query, recipe.name) then
                                recipes[#recipes + 1] = recipe
                            end
                            recipeIndex = recipeIndex + 1
                        end
                        local showExpansion = expansionHit or recipes[1]
                        if self.query ~= "" and not expansion.scanned and not expansionHit and not professionHit then
                            showExpansion = false
                        end
                        if showExpansion then
                            visibleExpansions[#visibleExpansions + 1] = { expansion = expansion, recipes = recipes, hit = expansionHit }
                        end
                        expansionIndex = expansionIndex + 1
                    end
                    local showProfession = professionHit or visibleExpansions[1]
                    if self.query ~= "" and not visibleExpansions[1] and not professionHit then
                        showProfession = false
                    end
                    if showProfession then
                        if not shownGroup then
                            local label = Acquire(self, "group", MakeGroup)
                            label.placeX = 0
                            label.placeY = y
                            label.placeH = GROUP
                            label:SetWidth(math.max(80, width - 20))
                            Theme.Font(label.title, 15, Theme.GOLD, "OUTLINE")
                            label.title:SetText(group.title)
                            y = y + GROUP + 4
                            shownGroup = true
                        end
                        local header = Acquire(self, "header", MakeHeader)
                        header.placeX = 8
                        header.placeY = y
                        header.placeH = HEADER
                        header:SetWidth(math.max(80, width - 28))
                        Theme.Font(header.title, 14, Theme.GOLD, "OUTLINE")
                        header.title:SetText(prof.name or "Profession")
                        Theme.Font(header.skill, 13, Theme.CREAM, "")
                        if not visibleExpansions[1] then
                            header.skill:SetText(SkillText(prof.skill, prof.maxSkill))
                        else
                            header.skill:SetText("")
                        end
                        if type(prof.icon) == "number" or type(prof.icon) == "string" then
                            header.icon:SetTexture(prof.icon)
                        else
                            header.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                        end
                        header.icon:SetVertexColor(1, 1, 1)
                        local professionId = "prof" .. tostring(prof.skillLine or prof.name or index)
                        local professionOpen = self.query ~= "" or IsOpen(self, professionId)
                        Chevron(header.chevron, professionOpen)
                        header.sectionId = professionId
                        header:SetScript("OnClick", function(button)
                            if self.query ~= "" then
                                return
                            end
                            self.open[button.sectionId] = not IsOpen(self, button.sectionId)
                            self:Refresh(self.record, self.query)
                        end)
                        y = y + HEADER + 2
                        if professionOpen and not visibleExpansions[1] then
                            local note = Acquire(self, "note", MakeNote)
                            note.text:SetText("Not scanned yet")
                            Theme.Font(note.text, 13, Theme.DIM, "")
                            note:SetWidth(math.max(80, width - 80))
                            note.placeX = 64
                            note.placeY = y
                            note.placeH = 18
                            y = y + 22
                        elseif professionOpen then
                            local shownIndex = 1
                            while visibleExpansions[shownIndex] do
                                local entry = visibleExpansions[shownIndex]
                                local expansion = entry.expansion
                                local block = Acquire(self, "expansion", MakeExpansion)
                                block.placeX = 36
                                block.placeY = y
                                block.placeH = EXPANSION
                                block:SetWidth(math.max(80, width - 56))
                                Theme.Font(block.title, 13, Theme.GOLD, "OUTLINE")
                                block.title:SetText(expansion.name or "Expansion")
                                Theme.Font(block.skill, 13, Theme.CREAM, "")
                                block.skill:SetText(SkillText(expansion.skill, expansion.maxSkill))
                                local expansionId = professionId .. "-" .. tostring(expansion.skillLine or expansion.name or shownIndex)
                                local expansionOpen = self.query ~= "" or IsOpen(self, expansionId)
                                Chevron(block.chevron, expansionOpen)
                                block.sectionId = expansionId
                                block:SetScript("OnClick", function(button)
                                    if self.query ~= "" then
                                        return
                                    end
                                    self.open[button.sectionId] = not IsOpen(self, button.sectionId)
                                    self:Refresh(self.record, self.query)
                                end)
                                y = y + EXPANSION + 2
                                if expansionOpen and not expansion.scanned then
                                    local note = Acquire(self, "note", MakeNote)
                                    note.text:SetText("Not scanned yet")
                                    Theme.Font(note.text, 13, Theme.DIM, "")
                                    note:SetWidth(math.max(80, width - 100))
                                    note.placeX = 72
                                    note.placeY = y
                                    note.placeH = 18
                                    y = y + 22
                                elseif expansionOpen then
                                    local recipeIndex = 1
                                    local rowWidth = math.max(120, width - 110)
                                    while entry.recipes[recipeIndex] do
                                        local recipe = entry.recipes[recipeIndex]
                                        local line = Acquire(self, "recipe", MakeRecipe)
                                        line:SetWidth(rowWidth)
                                        line.placeX = 72
                                        line.placeY = y
                                        line.placeH = ROW
                                        local missing = recipe.learned == false
                                        local who = ""
                                        if missing then
                                            who = Knowers(prof, recipe.id, record)
                                        end
                                        PaintRecipe(line, recipe, missing, who)
                                        y = y + ROW
                                        recipeIndex = recipeIndex + 1
                                    end
                                    y = y + 4
                                end
                                shownIndex = shownIndex + 1
                            end
                        end
                        local rule = Acquire(self, "line", MakeLine)
                        rule.placeX = 8
                        rule.placeY = y
                        rule.placeH = 1
                        rule:SetWidth(math.max(80, width - 28))
                        y = y + 8
                    end
                end
                index = index + 1
            end
            groupIndex = groupIndex + 1
        end
        self.contentHeight = y
        if y == 0 and (type(professions) ~= "table" or not professions[1]) then
            local note = Acquire(self, "note", MakeNote)
            note.text:SetText("Not scanned yet")
            Theme.Font(note.text, 13, Theme.DIM, "")
            note:SetWidth(math.max(80, width - 40))
            note.placeX = 8
            note.placeY = 8
            note.placeH = 18
            self.contentHeight = 32
        end
        local maxOffset = self:MaxOffset()
        if (self.offset or 0) > maxOffset then
            self.offset = maxOffset
        end
        self:Place()
    end

    frame:Refresh(nil, "")
    return frame
end
