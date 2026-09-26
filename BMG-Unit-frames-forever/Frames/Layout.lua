--[[
  BMG Unit Frames — create and place all unit frames
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Frames = UF.Frames or {}
local Frames = UF.Frames

Frames.list = Frames.list or {}
Frames.byId = Frames.byId or {}
Frames.headers = Frames.headers or {}

local function Cfg(id)
    local frames = UF.DB.Get().frames
    return frames and frames[id] or {}
end

local function UnitSize(id)
    local cfg = Cfg(id)
    if UF.Factory and UF.Factory.Measure then
        local powerOn = cfg.showPower
        if powerOn == nil then
            powerOn = UF.DB.Get().showPower ~= false
        end
        local w, h = UF.Factory.Measure(cfg, { powerOn = powerOn })
        return w, h
    end
    return cfg.w or 220, cfg.h or 56
end

local function PlaceMover(mover, id)
    local cfg = Cfg(id)
    mover:ClearAllPoints()
    mover:SetPoint(cfg.point or "CENTER", UIParent, cfg.point or "CENTER", cfg.x or 0, cfg.y or 0)
    mover:SetScale(cfg.scale or 1)
end

local function Header(name, id, w, h)
    local tmpl = UF.Compat.BackdropTemplate()
    local f = CreateFrame("Frame", name, UIParent, tmpl)
    f:SetSize(w, h)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(false)
    PlaceMover(f, id)
    Frames.headers[id] = f
    return f
end

local function Add(frame)
    Frames.list[#Frames.list + 1] = frame
    Frames.byId[frame.id] = frame
    return frame
end

local function Make(opts)
    local frame = UF.Factory.Create(opts)
    return Add(frame)
end

function Frames.Create()
    if Frames.created then
        return
    end
    if UF.Compat.InCombat() then
        Frames.pendingCreate = true
        return
    end
    Frames.created = true

    local p = Cfg("player")
    Make({
        id = "player",
        unit = "player",
        name = "BMGUnitFrames_Player",
        label = "Player",
        w = p.w or 190,
        h = p.h or 48,
        watch = false,
    })
    PlaceMover(Frames.byId.player, "player")

    local pet = Cfg("pet")
    Make({
        id = "pet",
        unit = "pet",
        name = "BMGUnitFrames_Pet",
        label = "Pet",
        w = pet.w or 150,
        h = pet.h or 36,
    })
    PlaceMover(Frames.byId.pet, "pet")

    local t = Cfg("target")
    Make({
        id = "target",
        unit = "target",
        name = "BMGUnitFrames_Target",
        label = "Target",
        w = t.w or 190,
        h = t.h or 48,
    })
    PlaceMover(Frames.byId.target, "target")

    local tot = Cfg("tot")
    Make({
        id = "tot",
        unit = "targettarget",
        name = "BMGUnitFrames_ToT",
        label = "Target of target",
        w = tot.w or 150,
        h = tot.h or 36,
    })
    PlaceMover(Frames.byId.tot, "tot")

    if UF.Compat.hasFocus then
        local fcfg = Cfg("focus")
        Make({
            id = "focus",
            unit = "focus",
            name = "BMGUnitFrames_Focus",
            label = "Focus",
            w = fcfg.w or 190,
            h = fcfg.h or 48,
        })
        PlaceMover(Frames.byId.focus, "focus")
        Make({
            id = "focustarget",
            unit = "focustarget",
            name = "BMGUnitFrames_FocusTarget",
            label = "Focus target",
            saveId = "focus",
            w = tot.w or 150,
            h = tot.h or 36,
        })
        local ft = Frames.byId.focustarget
        ft:ClearAllPoints()
        ft:SetPoint("TOPLEFT", Frames.byId.focus, "BOTTOMLEFT", 0, -6)
        ft.mover = Frames.byId.focus
    end

    local partyCfg = Cfg("party")
    local pw, ph = partyCfg.w or 200, partyCfg.h or 52
    local partyH = Header("BMGUnitFrames_PartyHeader", "party", pw, (ph + 6) * 5)
    Make({
        id = "partyplayer",
        unit = "player",
        name = "BMGUnitFrames_PartyPlayer",
        label = "You",
        saveId = "party",
        parent = partyH,
        mover = partyH,
        w = pw,
        h = ph,
        watch = false,
    })
    for i = 1, 4 do
        local child = Make({
            id = "party" .. i,
            unit = "party" .. i,
            name = "BMGUnitFrames_Party" .. i,
            label = "Party member " .. i,
            saveId = "party",
            parent = partyH,
            mover = partyH,
            w = pw,
            h = ph,
        })
        child:SetSize(pw, ph)
    end
    Frames.RelayoutParty()

    local raidCfg = Cfg("raid")
    local rw, rh = raidCfg.w or 72, raidCfg.h or 28
    local raidH = Header("BMGUnitFrames_RaidHeader", "raid", (rw + 4) * 8, (rh + 2) * 5)
    for i = 1, 40 do
        Make({
            id = "raid" .. i,
            unit = "raid" .. i,
            name = "BMGUnitFrames_Raid" .. i,
            label = "Raid " .. i,
            saveId = "raid",
            parent = raidH,
            mover = raidH,
            w = rw,
            h = rh,
        })
    end
    Frames.RelayoutRaid()
    if RegisterStateDriver then
        pcall(RegisterStateDriver, raidH, "visibility", "[group:raid] show; hide")
    end

    if UF.Compat.hasArena then
        local acfg = Cfg("arena")
        local arenaH = Header("BMGUnitFrames_ArenaHeader", "arena", acfg.w or 160, (acfg.h or 36) * 5 + 16)
        for i = 1, 5 do
            Make({
                id = "arena" .. i,
                unit = "arena" .. i,
                name = "BMGUnitFrames_Arena" .. i,
                label = "Arena " .. i,
                saveId = "arena",
                parent = arenaH,
                mover = arenaH,
                w = acfg.w or 160,
                h = acfg.h or 36,
            })
        end
        Frames.RelayoutArena()
        Frames.UpdateArenaVisibility()
    end
end

function Frames.InArena()
    if IsActiveBattlefieldArena then
        local ok, active = pcall(IsActiveBattlefieldArena)
        if ok and active then
            return true
        end
    end
    if C_PvP and C_PvP.IsArena then
        local ok, active = pcall(C_PvP.IsArena)
        if ok and active then
            return true
        end
    end
    return UnitExists and UnitExists("arena1") == true
end

function Frames.InPartyGroup()
    if IsInRaid and IsInRaid() then
        return false
    end
    if IsInGroup and IsInGroup() then
        return true
    end
    if GetNumGroupMembers then
        return (GetNumGroupMembers() or 0) > 0
    end
    if GetNumPartyMembers then
        return (GetNumPartyMembers() or 0) > 0
    end
    return UnitExists and UnitExists("party1")
end

local function GrowthOf(id)
    local g = Cfg(id).growth
    if type(g) == "string" then
        g = string.upper(g)
        if g == "UP" or g == "LEFT" or g == "RIGHT" or g == "DOWN" then
            return g
        end
    end
    return "DOWN"
end

local function PlaceGrown(child, header, index, w, h, gap, growth)
    if not child then
        return
    end
    child:SetSize(w, h)
    child.cfgH = h
    child:ClearAllPoints()
    if growth == "UP" then
        child:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, index * (h + gap))
    elseif growth == "LEFT" then
        child:SetPoint("TOPRIGHT", header, "TOPRIGHT", -(index * (w + gap)), 0)
    elseif growth == "RIGHT" then
        child:SetPoint("TOPLEFT", header, "TOPLEFT", index * (w + gap), 0)
    else
        child:SetPoint("TOPLEFT", header, "TOPLEFT", 0, -(index * (h + gap)))
    end
end

local function HeaderSize(count, w, h, gap, growth)
    if growth == "LEFT" or growth == "RIGHT" then
        return ((w + gap) * count) - gap, h
    end
    return w, ((h + gap) * count) - gap
end

function Frames.RelayoutParty()
    local header = Frames.headers.party
    if not header or UF.Compat.InCombat() then
        return
    end
    local cfg = Cfg("party")
    local w, h = UnitSize("party")
    local growth = GrowthOf("party")
    local showYou = UF.DB.Get().showPlayerInParty ~= false
    local count = showYou and 5 or 4
    local gap = 6
    header:SetSize(HeaderSize(count, w, h, gap, growth))
    local idx = 0
    local you = Frames.byId.partyplayer
    if you then
        if showYou then
            PlaceGrown(you, header, 0, w, h, gap, growth)
            you:Show()
            idx = 1
        else
            you:Hide()
        end
    end
    for i = 1, 4 do
        PlaceGrown(Frames.byId["party" .. i], header, idx, w, h, gap, growth)
        idx = idx + 1
    end
end

function Frames.RelayoutRaid()
    local header = Frames.headers.raid
    if not header or UF.Compat.InCombat() then
        return
    end
    local cfg = Cfg("raid")
    local w, h = UnitSize("raid")
    local growth = GrowthOf("raid")
    local gapX, gapY = 4, 2
    local groups, rows = 8, 5
    if growth == "LEFT" or growth == "RIGHT" then
        header:SetSize((rows * (w + gapX)) - gapX, (groups * (h + gapY)) - gapY)
    else
        header:SetSize((groups * (w + gapX)) - gapX, (rows * (h + gapY)) - gapY)
    end
    for i = 1, 40 do
        local child = Frames.byId["raid" .. i]
        if child then
            child:SetSize(w, h)
            child.cfgH = h
            child:ClearAllPoints()
            local group = math.floor((i - 1) / 5)
            local row = (i - 1) % 5
            if growth == "UP" then
                child:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", group * (w + gapX), row * (h + gapY))
            elseif growth == "LEFT" then
                child:SetPoint("TOPRIGHT", header, "TOPRIGHT", -(row * (w + gapX)), -(group * (h + gapY)))
            elseif growth == "RIGHT" then
                child:SetPoint("TOPLEFT", header, "TOPLEFT", row * (w + gapX), -(group * (h + gapY)))
            else
                child:SetPoint("TOPLEFT", header, "TOPLEFT", group * (w + gapX), -(row * (h + gapY)))
            end
        end
    end
end

function Frames.RelayoutArena()
    local header = Frames.headers.arena
    if not header or UF.Compat.InCombat() then
        return
    end
    local cfg = Cfg("arena")
    local w, h = UnitSize("arena")
    local growth = GrowthOf("arena")
    local gap = 4
    header:SetSize(HeaderSize(5, w, h, gap, growth))
    for i = 1, 5 do
        PlaceGrown(Frames.byId["arena" .. i], header, i - 1, w, h, gap, growth)
    end
end

function Frames.UpdateArenaVisibility()
    local header = Frames.headers.arena
    if not header or (UF.Compat.InCombat and UF.Compat.InCombat()) then
        return
    end
    local cfg = Cfg("arena")
    if cfg.enabled ~= false and Frames.InArena() then
        header:Show()
        Frames.RelayoutArena()
    else
        header:Hide()
    end
end

function Frames.UpdatePartyVisibility()
    local header = Frames.headers.party
    if not header or (UF.Compat.InCombat and UF.Compat.InCombat()) then
        return
    end
    local cfg = Cfg("party")
    if cfg.enabled ~= false and Frames.InPartyGroup() then
        header:Show()
        Frames.RelayoutParty()
    else
        header:Hide()
    end
end

function Frames.Apply(profile)
    profile = profile or UF.DB.Get()
    if UF.Compat.InCombat() then
        Frames.pendingApply = true
        return
    end
    if not Frames.created then
        Frames.Create()
    end
    local locked = profile.locked ~= false
    local function enabled(id)
        local cfg = profile.frames and profile.frames[id]
        if type(cfg) == "table" and cfg.enabled == false then
            return false
        end
        return true
    end

    if Frames.byId.player then
        PlaceMover(Frames.byId.player, "player")
        Frames.byId.player:SetShown(enabled("player"))
    end
    if Frames.byId.pet then
        PlaceMover(Frames.byId.pet, "pet")
    end
    if Frames.byId.target then
        PlaceMover(Frames.byId.target, "target")
    end
    if Frames.byId.tot then
        PlaceMover(Frames.byId.tot, "tot")
    end
    if Frames.byId.focus then
        PlaceMover(Frames.byId.focus, "focus")
        Frames.byId.focus:SetShown(enabled("focus"))
    end
    if Frames.headers.party then
        PlaceMover(Frames.headers.party, "party")
        Frames.RelayoutParty()
        Frames.UpdatePartyVisibility()
    end
    if Frames.headers.raid then
        PlaceMover(Frames.headers.raid, "raid")
        Frames.RelayoutRaid()
        if enabled("raid") then
            if RegisterStateDriver then
                pcall(RegisterStateDriver, Frames.headers.raid, "visibility", "[group:raid] show; hide")
            end
        else
            if UnregisterStateDriver then
                pcall(UnregisterStateDriver, Frames.headers.raid, "visibility")
            end
            Frames.headers.raid:Hide()
        end
    end
    if Frames.headers.arena then
        PlaceMover(Frames.headers.arena, "arena")
        Frames.RelayoutArena()
        Frames.UpdateArenaVisibility()
    end

    local function SizeOf(id)
        return UnitSize(id)
    end
    for i = 1, #Frames.list do
        local frame = Frames.list[i]
        local w, h = SizeOf(frame.saveId or frame.id)
        if w and h and not UF.Compat.InCombat() then
            frame:SetSize(w, h)
            frame.cfgH = h
        end
        UF.Factory.SetLocked(frame, locked)
        if frame.RefreshStyle then
            frame:RefreshStyle()
        end
    end
    if UF.HideBlizzard and UF.HideBlizzard.Apply then
        UF.HideBlizzard.Apply()
    end
end

function Frames.Read(unit)
    unit = unit or "target"
    if unit == "" then
        unit = "target"
    end
    if UnitExists and not UnitExists(unit) then
        UF.Speech.Say("No " .. unit .. ".")
        return
    end
    local name = (UF.Compat and UF.Compat.UnitNameOf and UF.Compat.UnitNameOf(unit)) or unit
    local level = UnitLevel and UnitLevel(unit)
    if UF.Compat and UF.Compat.CanUseNumber and not UF.Compat.CanUseNumber(level) then
        level = nil
    end
    local class = UnitClass and UnitClass(unit)
    if UF.Compat and UF.Compat.UsableString then
        class = UF.Compat.UsableString(class)
    end
    local parts = { name }
    if type(level) == "number" and level > 0 then
        parts[#parts + 1] = "level " .. tostring(level)
    end
    if type(class) == "string" and class ~= "" then
        parts[#parts + 1] = class
    end
    if UnitIsDead and UnitIsDead(unit) then
        parts[#parts + 1] = "dead"
    elseif UnitIsGhost and UnitIsGhost(unit) then
        parts[#parts + 1] = "ghost"
    else
        local cur, maxh, pct, unknown, secret = UF.Factory.HealthInfo(unit)
        local can = UF.Compat and UF.Compat.CanUseNumber
        if can and can(cur) and can(maxh) and maxh > 0 then
            parts[#parts + 1] = "health " .. tostring(math.floor(cur + 0.5)) .. " of " .. tostring(math.floor(maxh + 0.5)) .. ", " .. tostring(math.floor((cur / maxh) * 100 + 0.5)) .. " percent"
        elseif can and can(pct) then
            local shown = pct
            if shown <= 1 then
                shown = shown * 100
            end
            parts[#parts + 1] = "health " .. tostring(math.floor(shown + 0.5)) .. " percent"
        elseif unknown or secret then
            parts[#parts + 1] = "health hidden"
        end
        if UF.Power and UF.Power.Primary then
            local primary = UF.Power.Primary(unit)
            if primary and can and can(primary.cur) and can(primary.max) and primary.max > 0 then
                parts[#parts + 1] = (primary.name or "power") .. " " .. tostring(math.floor(primary.cur + 0.5)) .. " of " .. tostring(math.floor(primary.max + 0.5))
            end
            local alt = UF.Power.Secondary(unit)
            if alt and can and can(alt.cur) and can(alt.max) and alt.max > 0 then
                parts[#parts + 1] = (alt.name or "second power") .. " " .. tostring(math.floor(alt.cur + 0.5)) .. " of " .. tostring(math.floor(alt.max + 0.5))
            end
        end
    end
    if UnitIsFriend and UnitIsFriend("player", unit) then
        parts[#parts + 1] = "friendly"
    elseif UnitCanAttack and UnitCanAttack("player", unit) then
        parts[#parts + 1] = "hostile"
    end
    UF.Speech.Say(table.concat(parts, ". ") .. ".")
end

local roster = CreateFrame("Frame")
roster:RegisterEvent("GROUP_ROSTER_UPDATE")
roster:RegisterEvent("PLAYER_ENTERING_WORLD")
pcall(roster.RegisterEvent, roster, "PLAYER_ENTERING_BATTLEGROUND")
pcall(roster.RegisterEvent, roster, "ARENA_OPPONENT_UPDATE")
roster:SetScript("OnEvent", function()
    if Frames.UpdatePartyVisibility then
        Frames.UpdatePartyVisibility()
    end
    if Frames.UpdateArenaVisibility then
        Frames.UpdateArenaVisibility()
    end
    for i = 1, #Frames.list do
        local frame = Frames.list[i]
        if frame and (frame.id == "partyplayer" or (frame.unit and string.sub(frame.unit, 1, 5) == "party")) then
            UF.Factory.Update(frame)
        end
    end
end)
