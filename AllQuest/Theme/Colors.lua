--[[
  AllQuest — high-contrast theme tokens
  Black background, white border, gold accent. Status is never color-only.
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ.Theme = AQ.Theme or {}
local Theme = AQ.Theme

Theme.bg = { 0, 0, 0, 1 }
Theme.border = { 1, 1, 1, 1 }
Theme.text = { 1, 1, 1, 1 }
Theme.accent = { 1, 0.92, 0.4, 1 }
Theme.header = { 1, 0.92, 0.4, 1 }
Theme.hint = { 0.85, 0.85, 0.85, 1 }
Theme.rowBg = { 0.08, 0.08, 0.08, 0.55 }
Theme.rowBgAlt = { 0.14, 0.14, 0.14, 0.55 }
Theme.rowBgFocus = { 0.28, 0.28, 0.1, 0.55 }
Theme.tab = { 0.15, 0.15, 0.15, 0.55 }
Theme.tabOn = { 0.28, 0.28, 0.1, 0.55 }

-- Status colors are paired with STATUS words in UI.
Theme.done = { 0.7, 0.9, 1, 1 }
Theme.active = { 1, 0.92, 0.4, 1 }
Theme.ready = { 1, 1, 1, 1 }
Theme.locked = { 0.8, 0.8, 0.8, 1 }
Theme.failed = { 1, 0.5, 0.5, 1 }
Theme.objectiveOpen = { 1, 1, 1, 1 }
Theme.objectiveDone = { 0.62, 0.68, 0.72, 1 }
Theme.progressCount = { 0.784, 0.784, 0, 1 }
Theme.diffImpossible = { 1, 0.1, 0.1, 1 }
Theme.diffVeryHard = { 1, 0.5, 0.25, 1 }
Theme.diffHard = { 1, 0.82, 0, 1 }
Theme.diffStandard = { 1, 1, 0, 1 }
Theme.diffEasy = { 0.25, 0.75, 0.25, 1 }
Theme.diffTrivial = { 0.5, 0.5, 0.5, 1 }
Theme.questDone = { 0.72, 0.84, 0.94, 1 }
Theme.headerBg = { 0.14, 0.13, 0.06, 0.55 }
Theme.rowDoneBg = { 0.05, 0.09, 0.12, 0.55 }
Theme.barActive = { 1, 0.92, 0.4, 1 }
Theme.barDone = { 0.55, 0.8, 0.95, 1 }
Theme.barFailed = { 1, 0.45, 0.45, 1 }
Theme.barHeader = { 1, 0.92, 0.4, 1 }
Theme.barIdle = { 0.22, 0.22, 0.22, 0.7 }
Theme.rule = { 0.45, 0.4, 0.12, 1 }

-- Tracker / journal / settings panels. Solid black, not glass.
Theme.Tracker = {
    bg = { 0, 0, 0, 1 },
    border = { 0.22, 0.22, 0.22, 1 },
    header = { 1, 0.82, 0, 1 },
    title = { 0.95, 0.95, 0.95, 1 },
    objective = { 0.78, 0.78, 0.78, 1 },
    complete = { 0.1, 1, 0.1, 1 },
    failed = { 1, 0.15, 0.15, 1 },
    tag = { 0.62, 0.62, 0.62, 1 },
    rule = { 1, 0.82, 0, 0.4 },
    hover = { 1, 0.82, 0, 0.1 },
    focus = { 1, 0.82, 0, 0.14 },
    btnHover = { 1, 1, 1, 1 },
}

Theme.STATUS = {
    DONE = "DONE",
    ACTIVE = "ACTIVE",
    READY = "READY",
    LOCKED = "LOCKED",
    FAILED = "FAILED",
}

function Theme.StatusBarColor(status)
    if status == "DONE" then
        return Theme.barDone
    end
    if status == "ACTIVE" then
        return Theme.barActive
    end
    if status == "FAILED" then
        return Theme.barFailed
    end
    return Theme.barIdle
end

function Theme.StatusColor(status)
    if status == "DONE" then
        return Theme.done
    end
    if status == "ACTIVE" then
        return Theme.active
    end
    if status == "FAILED" then
        return Theme.failed
    end
    if status == "LOCKED" then
        return Theme.locked
    end
    return Theme.ready
end

function Theme.ParseSlashCounts(text)
    if type(text) ~= "string" then
        return nil
    end
    local a, b = string.match(text, "(%d+)%s*/%s*(%d+)")
    if not a then
        return nil
    end
    return tonumber(a), tonumber(b)
end

-- Questie GetRGBForObjective, redToGreen. Colors the whole objective line.
function Theme.ObjectiveProgressColor(data)
    local collected, needed
    if type(data) == "table" then
        collected = data.numFulfilled
        needed = data.numNeeded
        if type(collected) ~= "number" or type(needed) ~= "number" or needed <= 0 then
            collected, needed = Theme.ParseSlashCounts(data.title)
        end
        if (data.finished or data.clickComplete) and type(needed) == "number" and needed > 0 then
            collected = needed
        elseif data.finished or data.clickComplete then
            collected = 1
            needed = 1
        end
    end
    if type(collected) ~= "number" or type(needed) ~= "number" or needed <= 0 then
        return { 0.8, 0.8, 0.8, 1 }
    end
    local float = collected / needed
    if float < 0 then
        float = 0
    elseif float > 1 then
        float = 1
    end
    if float < 0.5 then
        return { 1, float / 0.5, 0, 1 }
    end
    if float == 0.5 then
        return { 1, 1, 0, 1 }
    end
    return { 1 - float / 2, 1, 0, 1 }
end

function Theme.QuestDifficultyColor(level)
    if type(level) ~= "number" then
        return Theme.Tracker and Theme.Tracker.title or Theme.text
    end
    if type(GetQuestDifficultyColor) == "function" then
        local ok, c = pcall(GetQuestDifficultyColor, level)
        if ok and type(c) == "table" and type(c.r) == "number" then
            return { c.r, c.g, c.b, 1 }
        end
    end
    local player = UnitLevel and UnitLevel("player") or 1
    local diff = level - (player or 1)
    local greenRange = 8
    if type(GetQuestGreenRange) == "function" then
        local ok, n = pcall(GetQuestGreenRange)
        if ok and type(n) == "number" then
            greenRange = n
        end
    end
    if diff >= 5 then
        return Theme.diffImpossible
    end
    if diff >= 3 then
        return Theme.diffVeryHard
    end
    if diff >= -2 then
        return Theme.diffStandard
    end
    if diff >= -greenRange then
        return Theme.diffEasy
    end
    return Theme.diffTrivial
end

function Theme.FontPath()
    return "Fonts\\FRIZQT__.TTF"
end

function Theme.FontSize(base)
    local db = AQ.DB and AQ.DB.Get and AQ.DB.Get() or {}
    local scale = db.fontScale or 1
    if scale < 0.8 then
        scale = 0.8
    end
    if scale > 2 then
        scale = 2
    end
    return math.floor((base or 14) * scale + 0.5)
end
