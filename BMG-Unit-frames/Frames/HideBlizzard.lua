--[[
  BMG Unit Frames — hide default unit frames
  Out of combat only. Re-hides if Edit Mode shows them again.
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.HideBlizzard = UF.HideBlizzard or {}
local Hide = UF.HideBlizzard

local hooked = {}

local NAMES = {
    "PlayerFrame",
    "PetFrame",
    "TargetFrame",
    "TargetFrameToT",
    "FocusFrame",
    "FocusFrameToT",
    "CompactPartyFrame",
    "CompactRaidFrameContainer",
    "CompactRaidFrameManager",
    "PartyFrame",
    "BossTargetFrameContainer",
}

local function FrameByName(name)
    local f = _G[name]
    if type(f) == "table" and f.Hide then
        return f
    end
    return nil
end

local function HideOne(frame)
    if not frame then
        return
    end
    pcall(function()
        if frame.UnregisterAllEvents then
            frame:UnregisterAllEvents()
        end
        frame:Hide()
    end)
    if not hooked[frame] and frame.HookScript then
        hooked[frame] = true
        frame:HookScript("OnShow", function(self)
            if UF.Compat and UF.Compat.InCombat and UF.Compat.InCombat() then
                return
            end
            self:Hide()
        end)
    end
end

function Hide.Apply()
    if UF.Compat and UF.Compat.InCombat and UF.Compat.InCombat() then
        return
    end
    for i = 1, #NAMES do
        HideOne(FrameByName(NAMES[i]))
    end
    for i = 1, 4 do
        HideOne(FrameByName("PartyMemberFrame" .. i))
        HideOne(FrameByName("PartyMemberFrame" .. i .. "PetFrame"))
    end
    if CompactRaidFrameManager_SetSetting then
        pcall(CompactRaidFrameManager_SetSetting, "IsShown", "0")
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(watcher.RegisterEvent, watcher, "EDIT_MODE_LAYOUTS_UPDATED")
watcher:SetScript("OnEvent", function()
    Hide.Apply()
end)
