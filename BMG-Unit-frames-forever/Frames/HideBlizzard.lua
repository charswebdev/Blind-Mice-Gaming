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
local sink

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
    "CompactArenaFrame",
    "ArenaEnemyMatchFramesContainer",
    "ArenaEnemyFrames",
    "ArenaEnemyPrepFrames",
}

local function Sink()
    if not sink then
        sink = CreateFrame("Frame", "BMGUnitFrames_BlizzardSink", UIParent)
        sink:Hide()
        sink:SetAlpha(0)
    end
    return sink
end

local function FrameByName(name)
    local f = _G[name]
    if type(f) == "table" and f.Hide then
        return f
    end
    return nil
end

local function HideOne(frame)
    if not frame or type(frame.Hide) ~= "function" then
        return
    end
    pcall(function()
        if frame.UnregisterAllEvents then
            frame:UnregisterAllEvents()
        end
        if UF.Compat and UF.Compat.IsRetail and UF.Compat.IsRetail() and frame.SetParent then
            frame:SetParent(Sink())
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

local function HideChildren(parent, prefix, count)
    if type(parent) ~= "table" then
        return
    end
    for i = 1, count or 5 do
        HideOne(parent[prefix .. i])
    end
end

function Hide.Apply()
    if UF.Compat and UF.Compat.InCombat and UF.Compat.InCombat() then
        return
    end
    for i = 1, #NAMES do
        HideOne(FrameByName(NAMES[i]))
    end
    for i = 1, 5 do
        HideOne(FrameByName("PartyMemberFrame" .. i))
        HideOne(FrameByName("PartyMemberFrame" .. i .. "PetFrame"))
        HideOne(FrameByName("CompactPartyFrameMember" .. i))
        HideOne(FrameByName("ArenaEnemyFrame" .. i))
        HideOne(FrameByName("ArenaEnemyMatchFrame" .. i))
        HideOne(FrameByName("CompactArenaFrameMember" .. i))
        HideOne(FrameByName("Boss" .. i .. "TargetFrame"))
    end
    HideChildren(_G.PartyFrame, "MemberFrame", 5)
    HideChildren(_G.CompactArenaFrame, "member", 5)
    if CompactRaidFrameManager_SetSetting then
        pcall(CompactRaidFrameManager_SetSetting, "IsShown", "0")
    end
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(watcher.RegisterEvent, watcher, "EDIT_MODE_LAYOUTS_UPDATED")
pcall(watcher.RegisterEvent, watcher, "PLAYER_FOCUS_CHANGED")
pcall(watcher.RegisterEvent, watcher, "PLAYER_ENTERING_BATTLEGROUND")
watcher:SetScript("OnEvent", function()
    Hide.Apply()
end)
