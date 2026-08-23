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

-- Tracker / journal / settings. Players can override these in Settings → Tracker.
Theme.TrackerDefaults = {
    bg = { 0.04, 0.04, 0.05, 0.94 },
    border = { 0.16, 0.16, 0.18, 1 },
    header = { 0.25, 0.88, 0.82, 1 },
    rule = { 0.85, 0.22, 0.78, 1 },
    section = { 0.25, 0.88, 0.82, 0.06 },
    subheader = { 0.42, 0.78, 0.80, 1 },
    title = { 1.00, 0.82, 0.20, 1 },
    tracked = { 1.00, 0.42, 0.72, 1 },
    objective = { 0.82, 0.82, 0.82, 1 },
    complete = { 0.15, 1.00, 0.22, 1 },
    collapse = { 0.20, 0.95, 0.28, 1 },
    failed = { 1, 0.15, 0.15, 1 },
    tag = { 0.62, 0.62, 0.62, 1 },
    hover = { 1, 0.82, 0, 0.08 },
    focus = { 1, 0.42, 0.72, 0.10 },
    btnHover = { 1, 1, 1, 1 },
}
Theme.Tracker = Theme.TrackerDefaults

function Theme.CopyColor(c)
    if type(c) ~= "table" then
        return { 1, 1, 1, 1 }
    end
    return { c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1 }
end

function Theme.GetTrackerColor(key)
    local db = AQ.DB and AQ.DB.Get and AQ.DB.Get() or {}
    local over = db.trackerColors and db.trackerColors[key]
    if type(over) == "table" and type(over[1]) == "number" then
        return Theme.CopyColor(over)
    end
    local base = Theme.TrackerDefaults[key] or Theme.Tracker[key]
    return Theme.CopyColor(base)
end

function Theme.SetTrackerColor(key, r, g, b, a)
    local db = AQ.DB and AQ.DB.Get and AQ.DB.Get()
    if not db or type(key) ~= "string" then
        return
    end
    db.trackerColors = db.trackerColors or {}
    db.trackerColors[key] = { r or 1, g or 1, b or 1, a or 1 }
end

function Theme.ResetTrackerColors()
    local db = AQ.DB and AQ.DB.Get and AQ.DB.Get()
    if db then
        db.trackerColors = {}
    end
end

function Theme.TrackerTheme()
    local t = {}
    for key in pairs(Theme.TrackerDefaults) do
        t[key] = Theme.GetTrackerColor(key)
    end
    return t
end

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

local function ObjectiveTypeIsBar(t)
    if t == "progressbar" or t == "progressBar" or t == "percentage" or t == "bar" then
        return true
    end
    local E = Enum and Enum.QuestObjectiveType
    if E and E.ProgressBar and t == E.ProgressBar then
        return true
    end
    return false
end

function Theme.IsPercentObjective(data)
    if type(data) ~= "table" then
        return false
    end
    if data.isWeightedProgress then
        return true
    end
    if ObjectiveTypeIsBar(data.objType or data.type) then
        return true
    end
    local qs = data.quantityString
    if type(qs) == "string" and qs:find("%%", 1, true) then
        return true
    end
    local title = data.title
    if type(title) == "string" and title:find("%d+%s*%%") then
        return true
    end
    return tonumber(data.numNeeded) == 100 and type(data.numFulfilled) == "number"
end

function Theme.ObjectivePercent(data)
    if type(data) ~= "table" then
        return 0
    end
    if data.finished or data.clickComplete then
        return 1
    end
    local fulfilled = tonumber(data.numFulfilled)
    local needed = tonumber(data.numNeeded)
    if data.isWeightedProgress and type(fulfilled) == "number" then
        if type(needed) == "number" and needed > 0 and fulfilled > 100 then
            if fulfilled / needed > 1 then
                return 1
            end
            if fulfilled / needed < 0 then
                return 0
            end
            return fulfilled / needed
        end
        local pct = fulfilled / 100
        if pct < 0 then
            return 0
        end
        if pct > 1 then
            return 1
        end
        return pct
    end
    if type(fulfilled) == "number" and type(needed) == "number" and needed > 0 then
        local pct = fulfilled / needed
        if pct < 0 then
            return 0
        end
        if pct > 1 then
            return 1
        end
        return pct
    end
    return 0
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
