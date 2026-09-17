--[[
  BMG Unit Frames — status indicators
  Combat, rest, leader, raid marker, PvP, main tank/assist, group role
  (tank / healer / DPS), resurrect, ready, elite, rare, rare elite,
  happiness, phase, range, quest.
  Lua 5.1 only.
]]

BMGUF = BMGUF or {}
local UF = BMGUF

UF.Indicators = UF.Indicators or {}
local Ind = UF.Indicators

local RAID_MARK = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local function FrameCfg(frame)
    local p = UF.DB.Get()
    local cfg = p.frames and p.frames[frame.saveId or frame.id] or {}
    cfg.indicators = cfg.indicators or {}
    cfg.indPos = cfg.indPos or {}
    cfg.indSize = cfg.indSize or {}
    return cfg
end

local function Tex(parent, name)
    if parent[name] then
        return parent[name]
    end
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetSize(14, 14)
    parent[name] = t
    return t
end

local DEFAULT_POS = {
    combat = "TOPLEFT",
    resting = "TOPLEFT",
    leader = "TOPLEFT",
    raidTarget = "CENTER",
    pvp = "TOPRIGHT",
    role = "BOTTOMLEFT",
    groupRole = "LEFT",
    resurrect = "CENTER",
    ready = "RIGHT",
    elite = "TOPRIGHT",
    happiness = "BOTTOMRIGHT",
    phase = "LEFT",
    oor = "BOTTOM",
    quest = "TOP",
    rare = "RIGHT",
    rareelite = "TOP",
}

local DEFAULT_SIZE = {
    combat = 14,
    resting = 14,
    leader = 12,
    raidTarget = 18,
    pvp = 16,
    role = 12,
    groupRole = 16,
    resurrect = 16,
    ready = 16,
    elite = 20,
    rare = 18,
    rareelite = 20,
    happiness = 16,
    phase = 16,
    oor = 14,
    quest = 16,
}

local function Enabled(cfg, key)
    return cfg[key] ~= false
end

local function PosOf(frameCfg, key)
    local pos = frameCfg.indPos and frameCfg.indPos[key]
    return pos or DEFAULT_POS[key] or "CENTER"
end

local function SizeOf(frameCfg, key)
    local n = frameCfg.indSize and tonumber(frameCfg.indSize[key])
    if n then
        if n < 8 then
            n = 8
        end
        if n > 40 then
            n = 40
        end
        return n
    end
    return DEFAULT_SIZE[key] or 14
end

local function SetAtlasOrTexture(tex, atlas, path)
    if atlas and tex.SetAtlas then
        local ok = pcall(tex.SetAtlas, tex, atlas, true)
        if ok then
            return
        end
    end
    if path then
        tex:SetTexture(path)
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

local PREVIEW = {
    combat = { path = "Interface\\CharacterFrame\\UI-StateIcon", coord = { 0.50, 1.0, 0.0, 0.49 } },
    resting = { path = "Interface\\CharacterFrame\\UI-StateIcon", coord = { 0.0, 0.50, 0.0, 0.421875 } },
    leader = { path = "Interface\\GroupFrame\\UI-Group-LeaderIcon" },
    raidTarget = { path = RAID_MARK, raid = 8 },
    pvp = { path = "Interface\\TargetingFrame\\UI-PVP-Alliance" },
    role = { path = "Interface\\GroupFrame\\UI-Group-MainTankIcon" },
    groupRole = { path = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", coord = { 0, 19 / 64, 22 / 64, 41 / 64 } },
    resurrect = { path = "Interface\\RaidFrame\\Raid-Icon-Rez" },
    ready = { path = "Interface\\RaidFrame\\ReadyCheck-Ready" },
    elite = { atlas = "nameplates-icon-elite-gold", path = "Interface\\TargetingFrame\\UI-TargetingFrame-Elite" },
    rare = { atlas = "nameplates-icon-elite-silver", path = "Interface\\TargetingFrame\\UI-TargetingFrame-Rare" },
    rareelite = { atlas = "nameplates-icon-elite-silver", path = "Interface\\TargetingFrame\\UI-TargetingFrame-RareElite" },
    happiness = { path = "Interface\\PetPaperDollFrame\\UI-PetHappiness", coord = { 0, 0.1875, 0, 0.359375 } },
    phase = { path = "Interface\\TargetingFrame\\UI-PhasingIcon", coord = { 0.15625, 0.84375, 0.15625, 0.84375 } },
    oor = { path = "Interface\\Common\\Indicator-Red" },
    quest = { path = "Interface\\GossipFrame\\AvailableQuestIcon" },
}

function Ind.PaintPreview(tex, field)
    if not tex then
        return
    end
    local spec = PREVIEW[field]
    if not spec then
        return
    end
    if spec.atlas then
        SetAtlasOrTexture(tex, spec.atlas, spec.path)
        return
    end
    if spec.raid and SetRaidTargetIconTexture then
        tex:SetTexture(spec.path)
        SetRaidTargetIconTexture(tex, spec.raid)
        return
    end
    if spec.path then
        tex:SetTexture(spec.path)
        if spec.coord then
            tex:SetTexCoord(spec.coord[1], spec.coord[2], spec.coord[3], spec.coord[4])
        else
            tex:SetTexCoord(0, 1, 0, 1)
        end
    end
end

-- Official GetTexCoordsForRoleSmallCircle slices on UI-LFG-ICON-PORTRAITROLES:
-- tank shield, healer cross, DPS swords.
local ROLE_COORD = {
    TANK = { 0, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}

local function RoleCoords(role)
    if role == "DAMAGE" or role == "DPS" then
        role = "DAMAGER"
    end
    if GetTexCoordsForRoleSmallCircle then
        local ok, a, b, c, d = pcall(GetTexCoordsForRoleSmallCircle, role)
        if ok and type(a) == "number" and type(d) == "number" then
            return a, b, c, d
        end
    end
    local pack = ROLE_COORD[role] or ROLE_COORD.DAMAGER
    return pack[1], pack[2], pack[3], pack[4]
end

local function PaintGroupRole(tex, role)
    if not tex or not role then
        return
    end
    tex:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
    tex:SetTexCoord(RoleCoords(role))
end

local function Place(tex, pos, size)
    if UF.Pos and UF.Pos.Apply then
        UF.Pos.Apply(tex, tex:GetParent(), pos, size or 14)
        return
    end
    tex:ClearAllPoints()
    tex:SetSize(size or 14, size or 14)
    tex:SetPoint(pos or "CENTER", tex:GetParent(), pos or "CENTER", 0, 0)
end

function Ind.Update(frame)
    if not frame or not frame.unit or not frame._ind then
        return
    end
    local unit = frame.unit
    local full = FrameCfg(frame)
    local cfg = full.indicators
    local box = frame._ind
    local exists = not (UnitExists and not UnitExists(unit))

    local combat = box.combat
    if combat then
        if Enabled(cfg, "combat") and exists and UnitAffectingCombat and UnitAffectingCombat(unit) then
            combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
            combat:SetTexCoord(0.50, 1.0, 0.0, 0.49)
            Place(combat, PosOf(full, "combat"), SizeOf(full, "combat"))
            combat:Show()
        elseif Enabled(cfg, "resting") and frame.unit == "player" and IsResting and IsResting() then
            combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
            combat:SetTexCoord(0.0, 0.50, 0.0, 0.421875)
            Place(combat, PosOf(full, "resting"), SizeOf(full, "resting"))
            combat:Show()
        else
            combat:Hide()
        end
    end

    local leader = box.leader
    if leader then
        local show = false
        if Enabled(cfg, "leader") and exists then
            if UnitIsGroupLeader and UnitIsGroupLeader(unit) then
                leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
                show = true
            elseif UnitIsGroupAssistant and UnitIsGroupAssistant(unit) then
                leader:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
                show = true
            end
        end
        if show then
            Place(leader, PosOf(full, "leader"), SizeOf(full, "leader"))
            leader:Show()
        else
            leader:Hide()
        end
    end

    local mark = box.raidTarget
    if mark then
        local idx = exists and GetRaidTargetIndex and GetRaidTargetIndex(unit)
        if Enabled(cfg, "raidTarget") and idx then
            mark:SetTexture(RAID_MARK)
            SetRaidTargetIconTexture(mark, idx)
            Place(mark, PosOf(full, "raidTarget"), SizeOf(full, "raidTarget"))
            mark:Show()
        else
            mark:Hide()
        end
    end

    local pvp = box.pvp
    if pvp then
        local show = false
        if Enabled(cfg, "pvp") and exists then
            if UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(unit) then
                pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-FFA")
                show = true
            elseif UnitIsPVP and UnitIsPVP(unit) then
                local fac = UnitFactionGroup and UnitFactionGroup(unit)
                if fac and fac ~= "Neutral" then
                    pvp:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. fac)
                    show = true
                end
            end
        end
        if show then
            Place(pvp, PosOf(full, "pvp"), SizeOf(full, "pvp"))
            pvp:Show()
        else
            pvp:Hide()
        end
    end

    local role = box.role
    if role then
        local show = false
        if Enabled(cfg, "role") and exists then
            if GetPartyAssignment and GetPartyAssignment("MAINTANK", unit) then
                role:SetTexture("Interface\\GroupFrame\\UI-Group-MainTankIcon")
                show = true
            elseif GetPartyAssignment and GetPartyAssignment("MAINASSIST", unit) then
                role:SetTexture("Interface\\GroupFrame\\UI-Group-MainAssistIcon")
                show = true
            end
        end
        if show then
            Place(role, PosOf(full, "role"), SizeOf(full, "role"))
            role:Show()
        else
            role:Hide()
        end
    end

    local groupRole = box.groupRole
    if groupRole then
        local assigned = exists and UF.Compat.GroupRole and UF.Compat.GroupRole(unit)
        if Enabled(cfg, "groupRole") and assigned then
            PaintGroupRole(groupRole, assigned)
            Place(groupRole, PosOf(full, "groupRole"), SizeOf(full, "groupRole"))
            groupRole:Show()
        else
            groupRole:Hide()
        end
    end

    local rez = box.resurrect
    if rez then
        if Enabled(cfg, "resurrect") and exists and UnitHasIncomingResurrection and UnitHasIncomingResurrection(unit) then
            rez:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
            Place(rez, PosOf(full, "resurrect"), SizeOf(full, "resurrect"))
            rez:Show()
        else
            rez:Hide()
        end
    end

    local ready = box.ready
    if ready then
        local status = exists and GetReadyCheckStatus and GetReadyCheckStatus(unit)
        if Enabled(cfg, "ready") and status then
            if status == "ready" then
                ready:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
            elseif status == "notready" then
                ready:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
            else
                ready:SetTexture("Interface\\RaidFrame\\ReadyCheck-Waiting")
            end
            Place(ready, PosOf(full, "ready"), SizeOf(full, "ready"))
            ready:Show()
        else
            ready:Hide()
        end
    end

    local classif = exists and UnitClassification and UnitClassification(unit)
    local elite = box.elite
    if elite then
        if Enabled(cfg, "elite") and (classif == "worldboss" or classif == "elite") then
            SetAtlasOrTexture(elite, "nameplates-icon-elite-gold", "Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
            Place(elite, PosOf(full, "elite"), SizeOf(full, "elite"))
            elite:Show()
        else
            elite:Hide()
        end
    end

    local rare = box.rare
    if rare then
        if Enabled(cfg, "rare") and classif == "rare" then
            SetAtlasOrTexture(rare, "nameplates-icon-elite-silver", "Interface\\TargetingFrame\\UI-TargetingFrame-Rare")
            Place(rare, PosOf(full, "rare"), SizeOf(full, "rare"))
            rare:Show()
        else
            rare:Hide()
        end
    end

    local rareelite = box.rareelite
    if rareelite then
        if Enabled(cfg, "rareelite") and classif == "rareelite" then
            SetAtlasOrTexture(rareelite, "nameplates-icon-elite-silver", "Interface\\TargetingFrame\\UI-TargetingFrame-RareElite")
            Place(rareelite, PosOf(full, "rareelite"), SizeOf(full, "rareelite"))
            rareelite:Show()
        else
            rareelite:Hide()
        end
    end

    local happy = box.happiness
    if happy then
        local show = false
        if Enabled(cfg, "happiness") and frame.unit == "pet" and GetPetHappiness then
            local h = GetPetHappiness()
            if h then
                happy:SetTexture("Interface\\PetPaperDollFrame\\UI-PetHappiness")
                if h == 1 then
                    happy:SetTexCoord(0.375, 0.5625, 0, 0.359375)
                elseif h == 2 then
                    happy:SetTexCoord(0.1875, 0.375, 0, 0.359375)
                else
                    happy:SetTexCoord(0, 0.1875, 0, 0.359375)
                end
                show = true
            end
        end
        if show then
            Place(happy, PosOf(full, "happiness"), SizeOf(full, "happiness"))
            happy:Show()
        else
            happy:Hide()
        end
    end

    local phase = box.phase
    if phase then
        if Enabled(cfg, "phase") and exists and UF.Compat.IsPhased and UF.Compat.IsPhased(unit) then
            phase:SetTexture("Interface\\TargetingFrame\\UI-PhasingIcon")
            phase:SetTexCoord(0.15625, 0.84375, 0.15625, 0.84375)
            Place(phase, PosOf(full, "phase"), SizeOf(full, "phase"))
            phase:Show()
        else
            phase:Hide()
        end
    end

    local oor = box.oor
    if oor then
        local inRange = exists and UF.Compat.InRange and UF.Compat.InRange(unit)
        if Enabled(cfg, "oor") and exists and inRange == false then
            oor:SetTexture("Interface\\Common\\Indicator-Red")
            oor:SetTexCoord(0, 1, 0, 1)
            Place(oor, PosOf(full, "oor"), SizeOf(full, "oor"))
            oor:Show()
        else
            oor:Hide()
        end
    end

    local quest = box.quest
    if quest then
        if Enabled(cfg, "quest") and exists and UF.Compat.IsQuestUnit and UF.Compat.IsQuestUnit(unit) then
            quest:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
            quest:SetTexCoord(0, 1, 0, 1)
            Place(quest, PosOf(full, "quest"), SizeOf(full, "quest"))
            quest:Show()
        else
            quest:Hide()
        end
    end
end

function Ind.Apply(frame)
    Ind.Update(frame)
end

function Ind.Attach(frame)
    if not frame or frame._ind then
        return
    end
    local box = CreateFrame("Frame", nil, frame)
    box:SetAllPoints()
    box:SetFrameLevel((frame:GetFrameLevel() or 1) + 4)
    frame._ind = box
    Tex(box, "combat")
    Tex(box, "leader")
    Tex(box, "raidTarget")
    Tex(box, "pvp")
    Tex(box, "role")
    Tex(box, "groupRole")
    Tex(box, "resurrect")
    Tex(box, "ready")
    Tex(box, "elite")
    Tex(box, "rare")
    Tex(box, "rareelite")
    Tex(box, "happiness")
    Tex(box, "phase")
    Tex(box, "oor")
    Tex(box, "quest")
    local events = {
        "PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_UPDATE_RESTING",
        "PARTY_LEADER_CHANGED",
        "RAID_TARGET_UPDATE",
        "UNIT_FACTION",
        "READY_CHECK",
        "READY_CHECK_CONFIRM",
        "READY_CHECK_FINISHED",
        "INCOMING_RESURRECT_CHANGED",
        "UNIT_HAPPINESS",
        "UNIT_CLASSIFICATION_CHANGED",
        "UNIT_PHASE",
        "UNIT_FLAGS",
        "UNIT_CONNECTION",
        "QUEST_LOG_UPDATE",
        "PLAYER_ROLES_ASSIGNED",
        "ROLE_CHANGED_INFORM",
        "PLAYER_SPECIALIZATION_CHANGED",
        "GROUP_ROSTER_UPDATE",
    }
    for i = 1, #events do
        pcall(frame.RegisterEvent, frame, events[i])
    end
    local prev = frame:GetScript("OnEvent")
    frame:SetScript("OnEvent", function(self, event, ...)
        if prev then
            prev(self, event, ...)
        end
        Ind.Update(self)
    end)
    local old = frame:GetScript("OnUpdate")
    frame:SetScript("OnUpdate", function(self, elapsed)
        if old then
            old(self, elapsed)
        end
        self._indTick = (self._indTick or 0) + elapsed
        if self._indTick >= 0.4 then
            self._indTick = 0
            Ind.Update(self)
        end
    end)
    Ind.Update(frame)
end
