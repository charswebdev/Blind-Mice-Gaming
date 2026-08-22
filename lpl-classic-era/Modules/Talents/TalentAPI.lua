local addonName, LPL = ...

LPL.TalentAPI = {}

LPL.TalentAPI.POINT_BUDGET = 51
LPL.TalentAPI.MAX_TIER = 6
LPL.TalentAPI.MAX_COLUMN = 3
LPL.TalentAPI.MIN_PLAN_LEVEL = 10
LPL.TalentAPI.MAX_PLAN_LEVEL = 60 -- Classic Era max level

function LPL.TalentAPI:GetMaxLevel()
    return self.MAX_PLAN_LEVEL
end

function LPL.TalentAPI:GetMinPlanLevel()
    return self.MIN_PLAN_LEVEL
end

function LPL.TalentAPI:GetMaxPointsForLevel(level)
    level = tonumber(level) or self:GetMaxLevel()
    local points = level - 9
    if points < 0 then
        points = 0
    end
    if points > self.POINT_BUDGET then
        points = self.POINT_BUDGET
    end
    return points
end

--- Planner level for a draft (defaults to max level so any class can plan a full 51-point build).
function LPL.TalentAPI:GetDraftLevel(draft)
    local level = draft and tonumber(draft.level)
    if not level then
        return self:GetMaxLevel()
    end
    if level < self:GetMinPlanLevel() then
        return self:GetMinPlanLevel()
    end
    if level > self:GetMaxLevel() then
        return self:GetMaxLevel()
    end
    return level
end

function LPL.TalentAPI:GetDraftPointBudget(draft)
    return self:GetMaxPointsForLevel(self:GetDraftLevel(draft))
end

function LPL.TalentAPI:SetDraftLevel(draft, level)
    if type(draft) ~= "table" then
        return
    end
    level = tonumber(level) or self:GetMaxLevel()
    if level < self:GetMinPlanLevel() then
        level = self:GetMinPlanLevel()
    end
    if level > self:GetMaxLevel() then
        level = self:GetMaxLevel()
    end
    draft.level = level
end

local function SafeGetTalentInfo(tabIndex, talentIndex, talentGroup)
    if talentGroup ~= nil and type(GetTalentInfo) == "function" then
        local ok, a, b, c, d, e, f, g, h, i, j = pcall(GetTalentInfo, tabIndex, talentIndex, false, false, talentGroup)
        if ok then
            return a, b, c, d, e, f, g, h, i, j
        end
    end
    return GetTalentInfo(tabIndex, talentIndex)
end

local function SafeGetTalentTabInfo(tabIndex, talentGroup)
    if talentGroup ~= nil and type(GetTalentTabInfo) == "function" then
        local ok, a, b, c, d, e = pcall(GetTalentTabInfo, tabIndex, false, false, talentGroup)
        if ok then
            return a, b, c, d, e
        end
    end
    return GetTalentTabInfo(tabIndex)
end

function LPL.TalentAPI:GetActiveTalentGroup()
    if type(GetActiveTalentGroup) == "function" then
        return GetActiveTalentGroup() or 1
    end
    return 1
end

function LPL.TalentAPI:GetNumTalentGroups()
    if type(GetNumTalentGroups) == "function" then
        return GetNumTalentGroups(false, false) or 1
    end
    return 1
end

function LPL.TalentAPI:GetUnspentPoints(talentGroup)
    if type(GetUnspentTalentPoints) == "function" then
        if talentGroup ~= nil then
            local ok, points = pcall(GetUnspentTalentPoints, false, false, talentGroup)
            if ok and type(points) == "number" then
                return points
            end
        end
        return GetUnspentTalentPoints() or 0
    end
    return 0
end

function LPL.TalentAPI:GetPlayerClassID()
    local _, _, classID = UnitClass("player")
    return tonumber(classID)
end

function LPL.TalentAPI:GetNumTabs()
    return GetNumTalentTabs() or 0
end

function LPL.TalentAPI:GetTabInfo(tabIndex, talentGroup)
    local a, b, c, d, e = SafeGetTalentTabInfo(tabIndex, talentGroup)

    -- Classic Era / modern clients may return tabID first (e.g. 361), then name.
    local name, icon, pointsSpent, background
    if type(a) == "number" and type(b) == "string" then
        name, icon, pointsSpent, background = b, c, d, e
    else
        name, icon, pointsSpent, background = a, b, c, d
    end

    -- Prefer Wago catalog labels when live name is missing or numeric.
    local classID = self:GetPlayerClassID()
    local catalogTab = self:GetCatalogTabByIndex(classID, tabIndex)
    if catalogTab then
        if type(name) ~= "string" or name == "" or tonumber(name) then
            name = catalogTab.name
        end
        if (not icon or icon == "") and catalogTab.icon then
            icon = catalogTab.icon
        end
    end

    return {
        index = tabIndex,
        tabID = catalogTab and catalogTab.id or nil,
        name = name or ("Tree " .. tostring(tabIndex)),
        icon = icon,
        pointsSpent = tonumber(pointsSpent) or 0,
        background = background,
    }
end

function LPL.TalentAPI:GetClassList()
    local list = {}
    local catalog = LPL.EraTalentCatalog
    if not catalog or type(catalog.classTabs) ~= "table" then
        return list
    end
    for classID in pairs(catalog.classTabs) do
        local id = tonumber(classID)
        if id then
            local name
            if GetClassInfo then
                name = GetClassInfo(id)
            end
            list[#list + 1] = {
                id = id,
                name = name or ("Class " .. id),
            }
        end
    end
    table.sort(list, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function LPL.TalentAPI:GetCatalogTabByIndex(classID, tabIndex)
    classID = tonumber(classID)
    tabIndex = tonumber(tabIndex)
    local catalog = LPL.EraTalentCatalog
    if not catalog or not classID or not tabIndex then
        return nil
    end
    local tabs = catalog:GetTabsForClass(classID)
    return tabs and tabs[tabIndex] or nil
end

function LPL.TalentAPI:GetCatalogTabs(classID)
    local catalog = LPL.EraTalentCatalog
    if not catalog then
        return {}
    end
    return catalog:GetTabsForClass(classID) or {}
end

function LPL.TalentAPI:GetCatalogTalents(tabID)
    local catalog = LPL.EraTalentCatalog
    if not catalog then
        return {}
    end
    return catalog:GetTalentsForTab(tabID) or {}
end

function LPL.TalentAPI:GetTalentSpellIcon(talent)
    if type(talent) ~= "table" then
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    if talent.icon and talent.icon ~= "" then
        return talent.icon
    end
    local spellID = talent.ranks and talent.ranks[1]
    if spellID and spellID > 0 then
        if C_Spell and C_Spell.GetSpellTexture then
            local tex = C_Spell.GetSpellTexture(spellID)
            if tex then
                return tex
            end
        end
        if GetSpellTexture then
            local tex = GetSpellTexture(spellID)
            if tex then
                return tex
            end
        end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function LPL.TalentAPI:GetTalentSpellName(talent)
    if type(talent) ~= "table" then
        return "Talent"
    end
    if talent.name and talent.name ~= "" then
        return talent.name
    end
    local spellID = talent.ranks and talent.ranks[1]
    if spellID and spellID > 0 then
        if C_Spell and C_Spell.GetSpellName then
            local name = C_Spell.GetSpellName(spellID)
            if name and name ~= "" then
                return name
            end
        end
        if GetSpellInfo then
            local name = GetSpellInfo(spellID)
            if name and name ~= "" then
                return name
            end
        end
    end
    return "Talent"
end

function LPL.TalentAPI:GetTalentInfo(tabIndex, talentIndex, talentGroup)
    local name, icon, tier, column, rank, maxRank, isExceptional, available =
        SafeGetTalentInfo(tabIndex, talentIndex, talentGroup)

    if not name then
        return nil
    end

    return {
        tabIndex = tabIndex,
        talentIndex = talentIndex,
        name = name,
        icon = icon,
        tier = tonumber(tier) or 0,
        column = tonumber(column) or 0,
        rank = tonumber(rank) or 0,
        maxRank = tonumber(maxRank) or 0,
        isExceptional = isExceptional and true or false,
        available = available and true or false,
    }
end

function LPL.TalentAPI:GetNumTalents(tabIndex)
    return GetNumTalents(tabIndex) or 0
end

function LPL.TalentAPI:IterateTabTalents(tabIndex, talentGroup)
    local list = {}
    local count = self:GetNumTalents(tabIndex)
    for talentIndex = 1, count do
        local info = self:GetTalentInfo(tabIndex, talentIndex, talentGroup)
        if info then
            list[#list + 1] = info
        end
    end
    return list
end

function LPL.TalentAPI:CaptureLiveBuild(talentGroup)
    talentGroup = talentGroup or self:GetActiveTalentGroup()
    local classID = self:GetPlayerClassID()
    local tabs = {}
    local totalPoints = 0
    local tabCount = self:GetNumTabs()

    for tabIndex = 1, tabCount do
        local tabInfo = self:GetTabInfo(tabIndex, talentGroup)
        local ranks = {}
        for _, talent in ipairs(self:IterateTabTalents(tabIndex, talentGroup)) do
            if talent.rank > 0 then
                ranks[tostring(talent.talentIndex)] = talent.rank
            end
            totalPoints = totalPoints + talent.rank
        end
        tabs[tostring(tabIndex)] = {
            name = tabInfo.name,
            points = tabInfo.pointsSpent,
            ranks = ranks,
        }
    end

    return {
        classID = classID,
        talentGroup = talentGroup,
        tabs = tabs,
        totalPoints = totalPoints,
        unspent = self:GetUnspentPoints(talentGroup),
    }
end

function LPL.TalentAPI:SummarizeBuild(build)
    if type(build) ~= "table" or type(build.tabs) ~= "table" then
        return "0/0/0"
    end
    local parts = {}
    for tabIndex = 1, 3 do
        local tab = build.tabs[tostring(tabIndex)] or build.tabs[tabIndex]
        local points = 0
        if type(tab) == "table" then
            points = tonumber(tab.points)
            if not points and type(tab.ranks) == "table" then
                points = 0
                for _, rank in pairs(tab.ranks) do
                    points = points + (tonumber(rank) or 0)
                end
            end
        end
        parts[#parts + 1] = tostring(points or 0)
    end
    return table.concat(parts, "/")
end

function LPL.TalentAPI:GetDraftRank(draft, tabIndex, talentIndex)
    if type(draft) ~= "table" or type(draft.tabs) ~= "table" then
        return 0
    end
    local tab = draft.tabs[tostring(tabIndex)] or draft.tabs[tabIndex]
    if type(tab) ~= "table" or type(tab.ranks) ~= "table" then
        return 0
    end
    return tonumber(tab.ranks[tostring(talentIndex)] or tab.ranks[talentIndex]) or 0
end

function LPL.TalentAPI:SetDraftRank(draft, tabIndex, talentIndex, rank)
    draft.tabs = draft.tabs or {}
    local key = tostring(tabIndex)
    draft.tabs[key] = draft.tabs[key] or { ranks = {}, points = 0, name = nil }
    draft.tabs[key].ranks = draft.tabs[key].ranks or {}
    rank = tonumber(rank) or 0
    if rank <= 0 then
        draft.tabs[key].ranks[tostring(talentIndex)] = nil
    else
        draft.tabs[key].ranks[tostring(talentIndex)] = rank
    end

    local points = 0
    for _, r in pairs(draft.tabs[key].ranks) do
        points = points + (tonumber(r) or 0)
    end
    draft.tabs[key].points = points

    local total = 0
    for tab = 1, 3 do
        local t = draft.tabs[tostring(tab)]
        if t then
            total = total + (tonumber(t.points) or 0)
        end
    end
    draft.totalPoints = total
end

function LPL.TalentAPI:RecalcDraftPoints(draft)
    if type(draft) ~= "table" then
        return 0
    end
    draft.tabs = draft.tabs or {}
    local total = 0
    for tabIndex = 1, 3 do
        local tab = draft.tabs[tostring(tabIndex)]
        if type(tab) == "table" then
            local points = 0
            if type(tab.ranks) == "table" then
                for _, rank in pairs(tab.ranks) do
                    points = points + (tonumber(rank) or 0)
                end
            end
            tab.points = points
            total = total + points
        end
    end
    draft.totalPoints = total
    return total
end

function LPL.TalentAPI:IteratePlannerTalents(classID, tabIndex)
    classID = tonumber(classID) or self:GetPlayerClassID()
    local catalogTab = self:GetCatalogTabByIndex(classID, tabIndex)
    if not catalogTab then
        return self:IterateTabTalents(tabIndex)
    end

    local list = {}
    local catalogTalents = self:GetCatalogTalents(catalogTab.id)
    local liveTalents = {}
    if classID == self:GetPlayerClassID() then
        liveTalents = self:IterateTabTalents(tabIndex)
    end

    local maxCatTier, maxLiveTier = 0, 0
    for _, cat in ipairs(catalogTalents) do
        if (cat.tier or 0) > maxCatTier then
            maxCatTier = cat.tier
        end
    end
    for _, live in ipairs(liveTalents) do
        if (live.tier or 0) > maxLiveTier then
            maxLiveTier = live.tier
        end
    end
    -- Live Classic APIs are often 1-based; Wago catalog tiers/columns are 0-based.
    local tierOffset = (maxLiveTier == maxCatTier + 1) and 1 or 0
    local colOffset = 0
    local maxCatCol, maxLiveCol = 0, 0
    for _, cat in ipairs(catalogTalents) do
        if (cat.column or 0) > maxCatCol then
            maxCatCol = cat.column
        end
    end
    for _, live in ipairs(liveTalents) do
        if (live.column or 0) > maxLiveCol then
            maxLiveCol = live.column
        end
    end
    if maxLiveCol == maxCatCol + 1 then
        colOffset = 1
    end

    local liveByPos = {}
    for _, live in ipairs(liveTalents) do
        local key = ((live.tier or 0) - tierOffset) .. ":" .. ((live.column or 0) - colOffset)
        liveByPos[key] = live
    end

    for index, cat in ipairs(catalogTalents) do
        local live = liveByPos[(cat.tier or 0) .. ":" .. (cat.column or 0)]
        local maxRank = #(cat.ranks or {})
        if maxRank <= 0 then
            maxRank = live and live.maxRank or 1
        end
        list[#list + 1] = {
            tabIndex = tabIndex,
            talentIndex = live and live.talentIndex or index,
            talentID = cat.id,
            name = (live and live.name) or self:GetTalentSpellName(cat),
            icon = (live and live.icon) or self:GetTalentSpellIcon(cat),
            tier = cat.tier or 0,
            column = cat.column or 0,
            rank = live and live.rank or 0,
            maxRank = maxRank,
            ranks = cat.ranks or {},
            prereqs = cat.prereqs or {},
            isExceptional = live and live.isExceptional or false,
            available = live and live.available or false,
        }
    end
    return list
end

function LPL.TalentAPI:GetSpellDescriptionText(spellID)
    spellID = tonumber(spellID)
    if not spellID or spellID < 1 then
        return nil
    end
    if C_Spell and C_Spell.GetSpellDescription then
        local text = C_Spell.GetSpellDescription(spellID)
        if type(text) == "string" and text ~= "" then
            return text
        end
    end
    if GetSpellDescription then
        local text = GetSpellDescription(spellID)
        if type(text) == "string" and text ~= "" then
            return text
        end
    end
    return nil
end

function LPL.TalentAPI:GetRankSpellID(talent, rank)
    if type(talent) ~= "table" then
        return nil
    end
    local ranks = talent.ranks
    if type(ranks) ~= "table" or #ranks == 0 then
        return nil
    end
    rank = tonumber(rank) or 0
    if rank < 1 then
        rank = 1
    end
    if rank > #ranks then
        rank = #ranks
    end
    return tonumber(ranks[rank])
end

--- Retail-style planner tooltip: spell body + Rank X/Y + Next rank + click hints.
function LPL.TalentAPI:ShowTalentTooltip(owner, talent, draftRank, options)
    if not owner or type(talent) ~= "table" then
        return
    end
    options = options or {}

    local maxRank = tonumber(talent.maxRank) or (talent.ranks and #talent.ranks) or 1
    local rank = tonumber(draftRank) or 0
    if rank < 0 then
        rank = 0
    end
    if rank > maxRank then
        rank = maxRank
    end

    local spellID = self:GetRankSpellID(talent, rank > 0 and rank or 1)
    local name = talent.name or self:GetTalentSpellName(talent) or "Talent"
    local currentDesc = spellID and self:GetSpellDescriptionText(spellID)
    local lines = {}

    if maxRank > 1 then
        local rankText
        if TALENT_BUTTON_TOOLTIP_RANK_FORMAT then
            rankText = string.format(TALENT_BUTTON_TOOLTIP_RANK_FORMAT, rank, maxRank)
        else
            rankText = string.format("%s %d/%d", RANK or "Rank", rank, maxRank)
        end
        lines[#lines + 1] = { text = rankText, color = "gold" }
    end

    if rank > 0 and rank < maxRank then
        local nextSpellID = self:GetRankSpellID(talent, rank + 1)
        local nextDesc = nextSpellID and self:GetSpellDescriptionText(nextSpellID)
        lines[#lines + 1] = { text = " " }
        lines[#lines + 1] = {
            text = TALENT_BUTTON_TOOLTIP_NEXT_RANK or "Next rank:",
            color = "gold",
        }
        if nextDesc then
            lines[#lines + 1] = { text = nextDesc, color = "normal", wrap = true }
        end
    end

    if options.requirementText then
        lines[#lines + 1] = { text = " " }
        lines[#lines + 1] = { text = options.requirementText, color = "red", wrap = true }
    end

    if not options.readOnly then
        lines[#lines + 1] = { text = " " }
        lines[#lines + 1] = { text = "Left-click to learn", color = "green" }
        lines[#lines + 1] = { text = "Right-click to unlearn", color = "red" }
    end

    -- Prefer full spell tooltip via spellID (Retail-like body), then append rank / next / hints.
    -- Do not pass GetSpellLink on Classic Era — it often returns a bare name, which breaks SetHyperlink.
    if spellID and LPL.ShowGameTooltip then
        LPL:ShowGameTooltip(owner, {
            spellID = spellID,
            anchor = "ANCHOR_RIGHT",
            lines = lines,
        })

        -- If the client spell tooltip was empty, rebuild with name + description.
        local lineCount = GameTooltip.NumLines and GameTooltip:NumLines() or 0
        if lineCount <= 1 and (name or currentDesc) then
            local fallback = {
                { text = name, color = "title" },
            }
            if currentDesc then
                fallback[#fallback + 1] = { text = currentDesc, color = "normal", wrap = true }
            end
            for _, line in ipairs(lines) do
                fallback[#fallback + 1] = line
            end
            LPL:ShowGameTooltipLines(owner, fallback, { anchor = "ANCHOR_RIGHT" })
        end
        return
    end

    local fallback = {
        { text = name, color = "title" },
    }
    if currentDesc then
        fallback[#fallback + 1] = { text = currentDesc, color = "normal", wrap = true }
    end
    for _, line in ipairs(lines) do
        fallback[#fallback + 1] = line
    end
    if LPL.ShowGameTooltipLines then
        LPL:ShowGameTooltipLines(owner, fallback, { anchor = "ANCHOR_RIGHT" })
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
        GameTooltip:SetText(name)
        if currentDesc then
            GameTooltip:AddLine(currentDesc, 1, 0.82, 0, true)
        end
        GameTooltip:AddLine(string.format("Rank %d/%d", rank, maxRank), 1, 0.82, 0)
        GameTooltip:Show()
    end
end

function LPL.TalentAPI:PointsInTabBeforeTier(draft, tabIndex, tier)
    local points = 0
    local classID = draft and draft.classID or self:GetPlayerClassID()
    for _, talent in ipairs(self:IteratePlannerTalents(classID, tabIndex)) do
        if talent.tier < tier then
            points = points + self:GetDraftRank(draft, tabIndex, talent.talentIndex)
        end
    end
    return points
end

function LPL.TalentAPI:PrereqsMet(draft, tabIndex, talent)
    if type(talent) ~= "table" or type(talent.prereqs) ~= "table" then
        return true
    end
    local classID = draft and draft.classID or self:GetPlayerClassID()
    local byID = {}
    for _, peer in ipairs(self:IteratePlannerTalents(classID, tabIndex)) do
        byID[peer.talentID] = peer
    end
    for _, req in ipairs(talent.prereqs) do
        local peer = byID[req.talentID]
        if not peer then
            return false
        end
        local need = (tonumber(req.rank) or 0) + 1
        if self:GetDraftRank(draft, tabIndex, peer.talentIndex) < need then
            return false
        end
    end
    return true
end

function LPL.TalentAPI:EnsureDraftClass(draft, classID)
    if type(draft) ~= "table" then
        return
    end
    classID = tonumber(classID) or self:GetPlayerClassID()
    if not draft.level then
        self:SetDraftLevel(draft, self:GetMaxLevel())
    end
    if tonumber(draft.classID) == classID and type(draft.tabs) == "table" and next(draft.tabs) then
        return
    end

    draft.classID = classID
    draft.tabs = {}
    local tabs = self:GetCatalogTabs(classID)
    for tabIndex, tab in ipairs(tabs) do
        draft.tabs[tostring(tabIndex)] = {
            name = tab.name,
            tabID = tab.id,
            points = 0,
            ranks = {},
        }
    end
    draft.totalPoints = 0
end

function LPL.TalentAPI:CanIncreaseDraftRank(draft, tabIndex, talentIndex)
    local classID = draft and draft.classID or self:GetPlayerClassID()
    local info
    for _, talent in ipairs(self:IteratePlannerTalents(classID, tabIndex)) do
        if talent.talentIndex == talentIndex then
            info = talent
            break
        end
    end
    if not info then
        return false, "Unknown talent."
    end

    local current = self:GetDraftRank(draft, tabIndex, talentIndex)
    if current >= info.maxRank then
        return false, "Already at max rank."
    end

    local budget = self:GetDraftPointBudget(draft)
    local spent = self:RecalcDraftPoints(draft)
    if spent >= budget then
        return false, "No talent points left."
    end

    local required = info.tier * 5
    local before = self:PointsInTabBeforeTier(draft, tabIndex, info.tier)
    if before < required then
        return false, string.format("Need %d points in this tree first.", required)
    end

    if not self:PrereqsMet(draft, tabIndex, info) then
        return false, "Prerequisite talent required."
    end

    return true
end

function LPL.TalentAPI:IncreaseDraftRank(draft, tabIndex, talentIndex)
    local ok, err = self:CanIncreaseDraftRank(draft, tabIndex, talentIndex)
    if not ok then
        return false, err
    end
    local current = self:GetDraftRank(draft, tabIndex, talentIndex)
    self:SetDraftRank(draft, tabIndex, talentIndex, current + 1)
    return true
end

function LPL.TalentAPI:DecreaseDraftRank(draft, tabIndex, talentIndex)
    local current = self:GetDraftRank(draft, tabIndex, talentIndex)
    if current <= 0 then
        return false, "No ranks to remove."
    end
    self:SetDraftRank(draft, tabIndex, talentIndex, current - 1)

    local classID = draft and draft.classID or self:GetPlayerClassID()
    local changed = true
    while changed do
        changed = false
        for _, talent in ipairs(self:IteratePlannerTalents(classID, tabIndex)) do
            local rank = self:GetDraftRank(draft, tabIndex, talent.talentIndex)
            if rank > 0 then
                local required = talent.tier * 5
                local before = self:PointsInTabBeforeTier(draft, tabIndex, talent.tier)
                if before < required or not self:PrereqsMet(draft, tabIndex, talent) then
                    self:SetDraftRank(draft, tabIndex, talent.talentIndex, 0)
                    changed = true
                end
            end
        end
    end

    self:RecalcDraftPoints(draft)
    return true
end

function LPL.TalentAPI:LearnTalent(tabIndex, talentIndex)
    if InCombatLockdown and InCombatLockdown() then
        return false, "Cannot change talents in combat."
    end
    if type(LearnTalent) ~= "function" then
        return false, "LearnTalent is not available."
    end
    LearnTalent(tabIndex, talentIndex)
    return true
end

-- Compatibility aliases
LPL.TalentAPI.GetMaxPointsForLevel = LPL.TalentAPI.GetMaxPointsForLevel or LPL.TalentAPI.GetMaxPointsForLevel

-- Aliases used by TalentTreeView / module UI
LPL.TalentAPI.GetMaxPointsForLevel = LPL.TalentAPI.GetMaxPointsForLevel
