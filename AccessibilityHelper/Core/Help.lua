--[[
  Accessibility Helper — slash / keybind help
  Lua 5.1 only.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Help = AH.Help or {}
local Help = AH.Help

local LINES = {
    "|cff00ff00Accessibility Helper|r — commands and keybinds",
    "  |cff00ff00/ah|r or |cff00ff00/ahelp|r — open settings",
    "  |cff00ff00/ahcmds|r — print this command list",
    "  |cff00ff00/ahs|r — test text to speech",
    "  |cff00ff00/ahstop|r — stop speaking",
    "  |cff00ff00/ahclear|r or |cff00ff00/ahflush|r — clear queued TTS announcements",
    "  |cff00ff00/ahrepeat|r or |cff00ff00/ahr|r — repeat last speech",
    "  |cff00ff00/ahreadtip|r or |cff00ff00/ahtip|r — read hovered tooltip (including Titan Panel)",
    "  |cff00ff00/ahread|r — read whatever is under the mouse (labels, tooltips, buttons, units)",
    "  |cff00ff00/ahtt|r, |cff00ff00/aharrow|r, |cff00ff00/ahtomtom|r — read TomTom arrow",
    "  |cff00ff00/ahz|r or |cff00ff00/ahzygor|r — read Zygor arrow",
    "  |cff00ff00/aha|r — toggle arrow facing announcements",
    "  |cff00ff00/ahtarget|r or |cff00ff00/ahrt|r — read current target",
    "  |cff00ff00/ahtf|r — toggle target facing announcements",
    "  |cff00ff00/ahdist|r or |cff00ff00/ahdistance|r — read target distance",
    "  |cff00ff00/ahquest|r, |cff00ff00/ahqo|r — read quest objectives",
    "  |cff00ff00/ahqw|r — read open NPC quest or one selected log quest",
    "Settings: category list on the left, one option per row on the right. Hover a row for a tooltip; the hint is also spoken.",
    "Cursor: Reading → UI text speaks name, title, and action, for example Toby Hill Weapons Master Repair.",
    "You and Combat turn alerts on. Sounds chooses TTS, a sound, or both for each alert. Sounds → Default sound is used when an alert still says Use default sound.",
    "Chat → Crafting is profession and gathering chat. Combat is fighting alerts only.",
    "Key Bindings → Accessibility Helper:",
    "  Tooltip · Under mouse · TomTom · Zygor · Settings · Distance · Read target · Stop · Repeat · Quest objectives · Quest window",
    "Tip: |cff00ff00/dump select(4, GetBuildInfo())|r — verify Interface version for this client.",
}

function Help.PrintCommands()
    for i = 1, #LINES do
        print(LINES[i])
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say("Command list printed to chat.", AH.Speech.PRIORITY_LOW)
    end
end

function Help.GetLines()
    return LINES
end
