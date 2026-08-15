--[[
  Cooldown Assist — slash command help
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Help = CA.Help or {}
local Help = CA.Help

CA.VERSION = CA.VERSION or "1.1.0"

local LINES = {
    "|cff00ff00Cooldown Assist commands|r",
    "  |cff00ff00/ca|r or |cff00ff00/cooldownassist|r — open settings",
    "  |cff00ff00/ca cooldowns|r — open Cooldowns tab (icons + names)",
    "  |cff00ff00/ca profiles|r — open Profiles tab (save / load tracking sets)",
    "  |cff00ff00/ca rename <name>|r — rename the active profile",
    "  |cff00ff00/ca c|r — read currently ready tracked cooldowns",
    "  |cff00ff00/ca list|r — list discovered tracked spells",
    "  |cff00ff00/ca on <name|id>|r — enable tracking for a spell",
    "  |cff00ff00/ca off <name|id>|r — disable tracking for a spell",
    "  |cff00ff00/ca scan|r — rescan bars + spellbook + items",
    "  |cff00ff00/ca rebuild|r — clear and rebuild discovered cooldowns",
    "  |cff00ff00/ca test|r or |cff00ff00/cas|r — test text to speech",
    "  |cff00ff00/ca stop|r — stop speaking",
    "  |cff00ff00/ca clear|r — clear queued TTS announcements",
    "  |cff00ff00/ca about|r — version and short summary",
    "  |cff00ff00/ca help|r — print this command list",
}

function Help.PrintCommands()
    for i = 1, #LINES do
        print(LINES[i])
    end
end

function Help.PrintAbout()
    local ver = CA.VERSION or "1.1.0"
    local iface = "?"
    if CA.Compat and CA.Compat.GetInterfaceVersion then
        iface = tostring(CA.Compat.GetInterfaceVersion())
    elseif GetBuildInfo then
        iface = tostring(select(4, GetBuildInfo()) or "?")
    end
    print("|cff00ff00Cooldown Assist|r v" .. ver .. " · Blind Mice Gaming")
    print("  Speaks when tracked cooldowns become ready, charges gain, and matched buffs fade.")
    print("  Combat CDs under 45s: in combat (default). Longer CDs also announce between pulls. General / Teleport / Toys: anytime.")
    print("  Ignores cooldowns under 5 seconds. Interface: " .. iface)
    print("  Settings: |cff00ff00/ca|r · Ready check: |cff00ff00/ca c|r · Help: |cff00ff00/ca help|r")
end
