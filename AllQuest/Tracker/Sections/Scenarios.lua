--[[
  AllQuest — scenario / dungeon / Mythic+ / delve tracker
  Lua 5.1 only. Nil-guard Retail APIs for Classic.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local NEMESIS_SPELL = {
    [1270179] = true,
    [1307638] = true,
}

local function Clock(sec)
    sec = math.floor(tonumber(sec) or 0)
    if sec < 0 then
        sec = 0
    end
    if SecondsToClock then
        local ok, text = pcall(SecondsToClock, sec)
        if ok and type(text) == "string" then
            return text
        end
    end
    local m = math.floor(sec / 60)
    local s = sec - m * 60
    if m >= 60 then
        local h = math.floor(m / 60)
        m = m - h * 60
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

local function SpellName(id)
    if type(id) ~= "number" then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        return AQ:SafeCall(C_Spell.GetSpellName, id)
    end
    if GetSpellInfo then
        return AQ:SafeCall(GetSpellInfo, id)
    end
    return nil
end

local function SpellIcon(id)
    if type(id) ~= "number" then
        return nil
    end
    if C_Spell and C_Spell.GetSpellTexture then
        return AQ:SafeCall(C_Spell.GetSpellTexture, id)
    end
    if GetSpellTexture then
        return AQ:SafeCall(GetSpellTexture, id)
    end
    return nil
end

local function SpellDesc(id)
    if type(id) ~= "number" then
        return nil
    end
    if C_Spell and C_Spell.GetSpellDescription then
        return AQ:SafeCall(C_Spell.GetSpellDescription, id)
    end
    return nil
end

local function IsShownState(state)
    if state == nil then
        return true
    end
    if Enum and Enum.WidgetShownState and Enum.WidgetShownState.Hidden then
        return state ~= Enum.WidgetShownState.Hidden
    end
    return state ~= 0
end

local function ChallengeType()
    if LE_SCENARIO_TYPE_CHALLENGE_MODE then
        return LE_SCENARIO_TYPE_CHALLENGE_MODE
    end
    if Enum and Enum.ScenarioType and Enum.ScenarioType.ChallengeMode then
        return Enum.ScenarioType.ChallengeMode
    end
    return 8
end

local function TimerTypeChallenge()
    if Enum and Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes.ChallengeMode then
        return Enum.WorldElapsedTimerTypes.ChallengeMode
    end
    return 1
end

local function TimerTypeProving()
    if Enum and Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes.ProvingGround then
        return Enum.WorldElapsedTimerTypes.ProvingGround
    end
    return 2
end

local function InstanceBits()
    if not GetInstanceInfo then
        return nil
    end
    local name, instanceType, difficultyID, difficultyName, maxPlayers = AQ:SafeCall(GetInstanceInfo)
    if type(difficultyName) ~= "string" or difficultyName == "" then
        if type(difficultyID) == "number" and GetDifficultyInfo then
            difficultyName = AQ:SafeCall(GetDifficultyInfo, difficultyID)
        end
    end
    return {
        name = name,
        instanceType = instanceType,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        maxPlayers = maxPlayers,
    }
end

local function AddRow(rows, spec)
    rows[#rows + 1] = spec
end

local function AddAffixRows(rows, affixes)
    if type(affixes) ~= "table" then
        return
    end
    local icons = {}
    for i = 1, #affixes do
        local affixID = affixes[i]
        if type(affixID) == "number" and C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
            local name, description, file = AQ:SafeCall(C_ChallengeMode.GetAffixInfo, affixID)
            if type(name) == "string" and name ~= "" then
                icons[#icons + 1] = { file = file, tooltip = name }
                AddRow(rows, {
                    kind = "quest",
                    title = name,
                    icon = file,
                    detail = description,
                    speech = "Affix " .. name,
                })
            end
        end
    end
    return icons
end

local function ClassifyDelveSpell(info)
    local id = info.spellID
    local name = info.text
    if type(name) ~= "string" or name == "" then
        name = SpellName(id) or "Modifier"
    end
    local tip = info.tooltip or SpellDesc(id) or ""
    local blob = string.lower(name .. " " .. tostring(tip))
    if NEMESIS_SPELL[id] or blob:find("nemesis", 1, true) then
        return "nemesis", name, tip
    end
    if blob:find("bountiful", 1, true) or blob:find("coffer", 1, true) then
        return "bountiful", name, tip
    end
    return "affix", name, tip
end

local function GetDelveWidget()
    if not (C_Scenario and C_Scenario.GetStepInfo and C_UIWidgetManager) then
        return nil
    end
    local ok, _, _, _, _, _, _, _, _, _, _, _, widgetSetID = pcall(C_Scenario.GetStepInfo)
    if not ok or type(widgetSetID) ~= "number" or widgetSetID == 0 then
        return nil
    end
    if not C_UIWidgetManager.GetAllWidgetsBySetID then
        return nil
    end
    local widgets = AQ:SafeCall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetID)
    if type(widgets) ~= "table" then
        return nil
    end
    local delveType = 29
    if Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
        delveType = Enum.UIWidgetVisualizationType.ScenarioHeaderDelves
    end
    local getter = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo
    if type(getter) ~= "function" then
        return nil
    end
    for i = 1, #widgets do
        local w = widgets[i]
        if type(w) == "table" and w.widgetType == delveType and w.widgetID then
            local info = AQ:SafeCall(getter, w.widgetID)
            if type(info) == "table" and IsShownState(info.shownState) then
                return info
            end
        end
    end
    return nil
end

local function ActiveDelveTier()
    if C_DelvesUI and C_DelvesUI.GetActiveDelveTier then
        local info = AQ:SafeCall(C_DelvesUI.GetActiveDelveTier)
        if type(info) == "table" and type(info.tier) == "number" then
            return info.tier
        end
        if type(info) == "number" then
            return info
        end
    end
    return nil
end

local function FindTimersOfType(wantType)
    if not GetWorldElapsedTimers or not GetWorldElapsedTime or wantType == nil then
        return nil
    end
    local ok, a, b, c, d, e, f, g = pcall(GetWorldElapsedTimers)
    if not ok then
        return nil
    end
    local ids = { a, b, c, d, e, f, g }
    for i = 1, #ids do
        local timerID = ids[i]
        if type(timerID) == "number" then
            local ok2, r1, r2, r3 = pcall(GetWorldElapsedTime, timerID)
            if ok2 then
                local elapsed, typ
                if type(r3) == "number" then
                    elapsed, typ = r2, r3
                else
                    elapsed, typ = r1, r2
                end
                if typ == wantType then
                    return timerID, tonumber(elapsed) or 0
                end
            end
        end
    end
    return nil
end

local function FindChallengeTimer()
    return FindTimersOfType(TimerTypeChallenge())
end

local function FindProvingTimer()
    return FindTimersOfType(TimerTypeProving())
end

local function AddCriteria(rows)
    if not (C_Scenario and C_Scenario.GetStepInfo) then
        return
    end
    local stepName, _, numCriteria = AQ:SafeCall(C_Scenario.GetStepInfo)
    if type(stepName) == "string" and stepName ~= "" then
        AddRow(rows, {
            kind = "quest",
            title = stepName,
            status = "ACTIVE",
            speech = stepName .. " ACTIVE",
        })
    end
    numCriteria = numCriteria or 0
    for i = 1, numCriteria do
        local criteriaString, completed, quantity, totalQuantity
        local isWeightedProgress, quantityString, objType
        if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
            local info = AQ:SafeCall(C_ScenarioInfo.GetCriteriaInfo, i)
            if type(info) == "table" then
                criteriaString = info.description
                completed = info.completed
                quantity = info.quantity
                totalQuantity = info.totalQuantity
                isWeightedProgress = info.isWeightedProgress and true or false
                quantityString = info.quantityString
                objType = info.criteriaType
            end
        elseif C_Scenario.GetCriteriaInfo then
            local a, b, c, d, e, _, _, h, _, _, _, _, m = AQ:SafeCall(C_Scenario.GetCriteriaInfo, i)
            criteriaString, objType, completed, quantity, totalQuantity = a, b, c, d, e
            quantityString = h
            isWeightedProgress = m and true or false
        end
        if not isWeightedProgress and type(totalQuantity) == "number" and totalQuantity >= 100 then
            isWeightedProgress = true
        end
        if type(criteriaString) == "string" then
            local extra = ""
            if quantity and totalQuantity then
                extra = string.format(" %s/%s", tostring(quantity), tostring(totalQuantity))
            end
            AddRow(rows, {
                kind = "objective",
                title = criteriaString,
                finished = completed and true or false,
                numFulfilled = quantity,
                numNeeded = totalQuantity,
                isWeightedProgress = isWeightedProgress,
                quantityString = quantityString,
                objType = objType,
                speech = criteriaString .. extra .. (completed and " complete" or ""),
            })
        end
    end
end

local function GetRows()
    local rows = {}
    local inScenario = C_Scenario and AQ:SafeCall(C_Scenario.IsInScenario)
    local inMplus = C_ChallengeMode and AQ:SafeCall(C_ChallengeMode.IsChallengeModeActive)
    if not inScenario and not inMplus then
        return rows
    end

    local name, currentStage, numStages, scenarioType
    if C_Scenario and C_Scenario.GetInfo then
        local ok, n, stage, stages, _, _, _, _, _, _, stype = pcall(C_Scenario.GetInfo)
        if ok then
            name, currentStage, numStages, scenarioType = n, stage, stages, stype
        end
    end
    local inst = InstanceBits()
    local delve = GetDelveWidget()
    local isChallenge = inMplus or (scenarioType and scenarioType == ChallengeType())
    local headerTitle = type(name) == "string" and name or (inst and inst.name) or "Scenario"
    local headerKind = "Scenario"

    if isChallenge and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local level, affixes, wasEnergized = AQ:SafeCall(C_ChallengeMode.GetActiveKeystoneInfo)
        level = tonumber(level) or 0
        headerKind = "Mythic+"
        if level > 0 then
            headerTitle = string.format("Mythic+ %d  %s", level, headerTitle)
        else
            headerTitle = "Mythic+  " .. headerTitle
        end
        AddRow(rows, {
            kind = "header",
            id = "scenario-name",
            title = headerTitle,
            speech = headerTitle,
            fontSize = 14,
        })
        if wasEnergized == false then
            AddRow(rows, {
                kind = "objective",
                title = "Keystone depleted at start",
                status = "FAILED",
                speech = "Keystone depleted at start",
            })
        end
        local mapID = C_ChallengeMode.GetActiveChallengeMapID and AQ:SafeCall(C_ChallengeMode.GetActiveChallengeMapID)
        local timeLimit
        if type(mapID) == "number" and C_ChallengeMode.GetMapUIInfo then
            local _, _, limit = AQ:SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
            timeLimit = tonumber(limit)
        end
        local timerID, elapsed = FindChallengeTimer()
        if timeLimit and timeLimit > 0 then
            AddRow(rows, {
                kind = "timer",
                title = "Time remaining",
                timerID = timerID,
                timeLimit = timeLimit,
                elapsed = elapsed or 0,
                countdown = true,
                speech = "Mythic plus timer",
            })
        end
        if C_ChallengeMode.GetDeathCount then
            local deaths, lost = AQ:SafeCall(C_ChallengeMode.GetDeathCount)
            deaths = tonumber(deaths) or 0
            lost = tonumber(lost) or 0
            if deaths > 0 then
                local extra = ""
                if lost > 0 then
                    extra = "  (-" .. Clock(lost) .. ")"
                end
                AddRow(rows, {
                    kind = "objective",
                    title = "Deaths  " .. tostring(deaths) .. extra,
                    speech = "Deaths " .. tostring(deaths),
                })
            end
        end
        local affixIcons = AddAffixRows(rows, affixes)
        if type(affixIcons) == "table" and #affixIcons > 0 then
            rows[1].icons = affixIcons
        end
        AddCriteria(rows)
        return rows
    end

    if delve then
        local tier = tonumber(delve.tierText and string.match(delve.tierText, "%d+"))
        if not tier then
            tier = ActiveDelveTier()
        end
        headerKind = "Delve"
        if type(delve.headerText) == "string" and delve.headerText ~= "" then
            headerTitle = delve.headerText
        end
        if tier then
            headerTitle = string.format("Tier %s  %s", tostring(tier), headerTitle)
        end
        AddRow(rows, {
            kind = "header",
            id = "scenario-name",
            title = headerTitle,
            speech = headerTitle,
            fontSize = 14,
        })
        if type(delve.currencies) == "table" then
            for i = 1, #delve.currencies do
                local cur = delve.currencies[i]
                if type(cur) == "table" then
                    local label = cur.leadingText or "Lives"
                    local amount = cur.text or ""
                    local title = AQ:Trim((label .. "  " .. amount))
                    AddRow(rows, {
                        kind = "quest",
                        title = title,
                        icon = cur.iconFileID,
                        detail = cur.tooltip,
                        speech = title,
                    })
                end
            end
        end
        if type(delve.rewardInfo) == "table" and IsShownState(delve.rewardInfo.shownState) then
            local earned = delve.rewardInfo.shownState == 1
                or (Enum and Enum.UIWidgetRewardShownState and delve.rewardInfo.shownState == Enum.UIWidgetRewardShownState.ShownEarned)
            AddRow(rows, {
                kind = "quest",
                title = earned and "Bountiful reward earned" or "Bountiful reward",
                status = earned and "DONE" or "ACTIVE",
                detail = earned and delve.rewardInfo.earnedTooltip or delve.rewardInfo.unearnedTooltip,
                speech = "Bountiful reward",
            })
        end
        if type(delve.spells) == "table" then
            for i = 1, #delve.spells do
                local sp = delve.spells[i]
                if type(sp) == "table" and type(sp.spellID) == "number" and IsShownState(sp.shownState) then
                    local kind, sname, tip = ClassifyDelveSpell(sp)
                    local prefix = ""
                    local lower = string.lower(sname or "")
                    if kind == "nemesis" and not lower:find("nemesis", 1, true) then
                        prefix = "Nemesis  "
                    elseif kind == "bountiful" and not lower:find("bountiful", 1, true) then
                        prefix = "Bountiful  "
                    end
                    AddRow(rows, {
                        kind = "quest",
                        title = prefix .. sname,
                        icon = SpellIcon(sp.spellID),
                        detail = (type(tip) == "string" and tip ~= "" and tip) or SpellDesc(sp.spellID),
                        speech = prefix .. sname,
                    })
                end
            end
        end
        AddCriteria(rows)
        return rows
    end

    local diffLabel = inst and inst.difficultyName
    if type(diffLabel) == "string" and diffLabel ~= "" and headerTitle then
        if inst.instanceType == "raid" then
            headerTitle = diffLabel .. " Raid  " .. headerTitle
        elseif inst.instanceType == "party" then
            headerTitle = diffLabel .. "  " .. headerTitle
        else
            headerTitle = diffLabel .. "  " .. headerTitle
        end
    end
    AddRow(rows, {
        kind = "header",
        id = "scenario-name",
        title = headerTitle,
        speech = headerKind .. " " .. headerTitle,
        fontSize = 14,
    })
    if currentStage and numStages then
        AddRow(rows, {
            kind = "objective",
            title = string.format("Stage %s of %s", tostring(currentStage), tostring(numStages)),
            numFulfilled = tonumber(currentStage),
            numNeeded = tonumber(numStages),
            speech = string.format("Stage %s of %s", tostring(currentStage), tostring(numStages)),
        })
    end

    local pgTimer, pgElapsed = FindProvingTimer()
    if pgTimer and C_Scenario and C_Scenario.GetProvingGroundsInfo then
        local diffID, currWave, maxWave, duration = AQ:SafeCall(C_Scenario.GetProvingGroundsInfo)
        duration = tonumber(duration)
        if duration and duration > 0 then
            AddRow(rows, {
                kind = "timer",
                title = string.format("Wave %s / %s", tostring(currWave or "?"), tostring(maxWave or "?")),
                timerID = pgTimer,
                timeLimit = duration,
                elapsed = pgElapsed or 0,
                countdown = true,
                speech = "Proving grounds timer",
            })
        end
    end

    AddCriteria(rows)
    return rows
end

AQ.Tracker.RegisterSection({
    id = "scenarios",
    title = "Scenario",
    order = 10,
    flavor = "retail",
    GetRows = GetRows,
})

local function RefreshIfInside()
    if not AQ.Tracker then
        return
    end
    local inScenario = C_Scenario and AQ:SafeCall(C_Scenario.IsInScenario)
    local inMplus = C_ChallengeMode and AQ:SafeCall(C_ChallengeMode.IsChallengeModeActive)
    if inScenario or inMplus then
        AQ.Tracker.Refresh()
    end
end

AQ.Events.Register("SCENARIO_UPDATE", RefreshIfInside)
AQ.Events.Register("SCENARIO_CRITERIA_UPDATE", RefreshIfInside)
AQ.Events.Register("SCENARIO_SPELL_UPDATE", RefreshIfInside)
AQ.Events.Register("CHALLENGE_MODE_START", function()
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end)
AQ.Events.Register("CHALLENGE_MODE_COMPLETED", function()
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end)
AQ.Events.Register("CHALLENGE_MODE_DEATH_COUNT_UPDATED", RefreshIfInside)
AQ.Events.Register("WORLD_STATE_TIMER_START", RefreshIfInside)
AQ.Events.Register("WORLD_STATE_TIMER_STOP", RefreshIfInside)
AQ.Events.Register("ACTIVE_DELVE_DATA_UPDATE", RefreshIfInside)
AQ.Events.Register("CURRENCY_DISPLAY_UPDATE", RefreshIfInside)
