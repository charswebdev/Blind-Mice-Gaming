--[[
  BMG Unit Frames — key bindings
  Same pattern as Accessibility Helper and AllQuest.
  Binding name= IDs must never change after users bind them.
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

_G.BINDING_HEADER_BMGUNITFRAMES = "BMG Unit Frames"
_G.BINDING_NAME_BMGUNITFRAMES_OPENSETTINGS = "Open settings"
_G.BINDING_NAME_BMGUNITFRAMES_TOGGLELOCK = "Lock or unlock frames"
_G.BINDING_NAME_BMGUNITFRAMES_READTARGET = "Read current target"

function BMGUnitFrames_OpenSettingsBinding()
    if UF.Config and UF.Config.Toggle then
        UF.Config.Toggle()
        return
    end
    print("|cff00ff00[BMG Unit Frames]|r Settings are not ready yet.")
end

function BMGUnitFrames_ToggleLockBinding()
    if not UF.DB or not UF.DB.Get then
        return
    end
    if UF.Compat and UF.Compat.InCombat and UF.Compat.InCombat() then
        if UF.Speech and UF.Speech.Say then
            UF.Speech.Say("Frames are locked in combat.")
        end
        return
    end
    local db = UF.DB.Get()
    db.locked = not db.locked
    if UF.ApplyProfile then
        UF.ApplyProfile(db)
    end
    local msg = db.locked and "Frames locked." or "Frames unlocked."
    if UF.Speech and UF.Speech.Say then
        UF.Speech.Say(msg)
    end
    print("|cff00ff00[BMG Unit Frames]|r " .. msg)
end

function BMGUnitFrames_ReadTargetBinding()
    if UF.Frames and UF.Frames.Read then
        UF.Frames.Read("target")
        return
    end
    print("|cff00ff00[BMG Unit Frames]|r Read is not ready yet.")
end

function BMGUnitFrames_OnAddonCompartmentClick()
    BMGUnitFrames_OpenSettingsBinding()
end
