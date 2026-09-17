--[[
  BMG Unit Frames — status indicators
  Combat, rest, leader, raid marker, PvP, role, resurrect, ready, elite, happiness.
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
    resurrect = "CENTER",
    ready = "RIGHT",
    elite = "TOPRIGHT",
    happiness = "BOTTOMRIGHT",
    phase = "LEFT",
    oor = "BOTTOM",
    quest = "TOP",
}

local function Enabled(cfg, key)
    return cfg[key] ~= false
end

local function PosOf(frameCfg, key)
    local pos = frameCfg.indPos and frameCfg.indPos[key]
    return pos or DEFAULT_POS[key] or "CENTER"
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
            Place(combat, PosOf(full, "combat"), 14)
            combat:Show()
        elseif Enabled(cfg, "resting") and frame.unit == "player" and IsResting and IsResting() then
            combat:SetTexture("Interface\\CharacterFrame\\UI-StateIcon")
            combat:SetTexCoord(0.0, 0.50, 0.0, 0.421875)
            Place(combat, PosOf(full, "resting"), 14)
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
            Place(leader, PosOf(full, "leader"), 12)
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
            Place(mark, PosOf(full, "raidTarget"), 18)
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
            Place(pvp, PosOf(full, "pvp"), 16)
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
            Place(role, PosOf(full, "role"), 12)
            role:Show()
        else
            role:Hide()
        end
    end

    local rez = box.resurrect
    if rez then
        if Enabled(cfg, "resurrect") and exists and UnitHasIncomingResurrection and UnitHasIncomingResurrection(unit) then
            rez:SetTexture("Interface\\RaidFrame\\Raid-Icon-Rez")
            Place(rez, PosOf(full, "resurrect"), 16)
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
            Place(ready, PosOf(full, "ready"), 16)
            ready:Show()
        else
            ready:Hide()
        end
    end

    local elite = box.elite
    if elite then
        local classif = exists and UnitClassification and UnitClassification(unit)
        if Enabled(cfg, "elite") and (classif == "worldboss" or classif == "rareelite" or classif == "elite" or classif == "rare") then
            elite:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
            Place(elite, PosOf(full, "elite"), 20)
            elite:Show()
        else
            elite:Hide()
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
            Place(happy, PosOf(full, "happiness"), 16)
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
            Place(phase, PosOf(full, "phase"), 16)
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
            Place(oor, PosOf(full, "oor"), 14)
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
            Place(quest, PosOf(full, "quest"), 16)
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
    Tex(box, "resurrect")
    Tex(box, "ready")
    Tex(box, "elite")
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
