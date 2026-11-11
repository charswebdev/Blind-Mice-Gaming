--[[
  Accessibility Helper — short status lines
  Speaks skill, level, follow, place, and the other status lines.
  The words come from the game state. They are not printed.
  Add the next status line in this file.
  Lua 5.1 only. No goto, no continue, no //.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Status = AH.Status or {}
local Status = AH.Status

local skills = {}
local recent = {}
local live = false
local seedGen = 0

local function Num(v)
    if AH.Compat and AH.Compat.CanUseNumber then
        if AH.Compat.CanUseNumber(v) then
            return v
        end
        return nil
    end
    if type(v) == "number" then
        return v
    end
    return nil
end

local function Text(v)
    if AH.Compat and AH.Compat.UsableString then
        return AH.Compat.UsableString(v)
    end
    if type(v) == "string" and v ~= "" then
        return v
    end
    return nil
end

local function Flag(v)
    if AH.Compat and AH.Compat.CanUseValue and not AH.Compat.CanUseValue(v) then
        return nil
    end
    if v == true or v == 1 then
        return true
    end
    return false
end

local function DB()
    return AH.DB and AH.DB.Get and AH.DB.Get() or {}
end

local function On(key)
    return DB()[key] ~= false
end

local function Say(msg)
    msg = Text(msg)
    if not msg then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(msg, AH.Speech.PRIORITY_INFO, { noEcho = true })
    end
end

local function Claim(key)
    local now = GetTime and GetTime() or 0
    local seen = recent[key]
    if type(seen) == "number" and (now - seen) < 0.5 then
        return false
    end
    recent[key] = now
    return true
end

local function SpeakGain(name, qty, toggle)
    if not On(toggle) then
        return
    end
    name = Text(name)
    if not name then
        return
    end
    if not Claim("item:" .. string.lower(name)) then
        return
    end
    qty = Num(qty)
    if qty and qty > 1 then
        Say(string.format("%s, %d.", name, qty))
    else
        Say(name .. ".")
    end
end

local function AddSkill(name, rank, maxRank)
    name = Text(name)
    rank = Num(rank)
    if not name or not rank then
        return
    end
    maxRank = Num(maxRank)
    local key = string.lower(name)
    local prev = skills[key]
    skills[key] = { rank = rank, max = maxRank }
    if not live or not On("progressSkill") or not prev then
        if live and On("progressSkill") and not prev then
            Say(name .. " learned.")
        end
        return
    end
    if rank <= prev.rank then
        return
    end
    if maxRank and prev.max and maxRank ~= prev.max then
        Say(string.format("%s %d of %d.", name, rank, maxRank))
    else
        Say(string.format("%s %d.", name, rank))
    end
end

local function ScanProfessions()
    if not GetProfessions or not GetProfessionInfo then
        return
    end
    local ok, a, b, c, d, e = pcall(GetProfessions)
    if not ok then
        return
    end
    local ids = { a, b, c, d, e }
    local i
    for i = 1, 5 do
        local idx = Num(ids[i])
        if idx then
            local infoOk, name, _, rank, maxRank = pcall(GetProfessionInfo, idx)
            if infoOk then
                AddSkill(name, rank, maxRank)
            end
        end
    end
end

local function ScanSkillLines()
    if not GetNumSkillLines or not GetSkillLineInfo then
        return
    end
    local ok, count = pcall(GetNumSkillLines)
    count = ok and Num(count) or nil
    if not count or count < 1 then
        return
    end
    local i
    for i = 1, count do
        local lineOk, name, header, _, rank, _, modifier, maxRank = pcall(GetSkillLineInfo, i)
        local isHeader = Flag(header)
        if lineOk and isHeader == false then
            local shown = Num(rank)
            local extra = Num(modifier)
            if shown and extra then
                shown = shown + extra
            end
            AddSkill(name, shown, maxRank)
        end
    end
end

local function ScanSkills()
    ScanProfessions()
    ScanSkillLines()
end

local function Plain(message)
    return Text(message)
end

local function BracketName(message)
    local body = Plain(message)
    if not body then
        return nil
    end
    return Text(string.match(body, "%[(.-)%]"))
end

local function TrailingCount(message)
    local body = Plain(message)
    if not body then
        return nil
    end
    return Num(tonumber(string.match(body, "[xX]%s*(%d+)")))
end

local function HandleLootChat(message)
    local body = Plain(message)
    if not body then
        return
    end
    local lower = string.lower(body)
    local name = BracketName(body)
    local qty = TrailingCount(body)
    if string.find(lower, "you create", 1, true) or string.find(lower, "you have created", 1, true) then
        SpeakGain(name, qty, "progressSkill")
    end
end

local function ItemNameByID(itemID)
    itemID = Num(itemID)
    if not itemID then
        return nil
    end
    if C_Item and C_Item.GetItemNameByID then
        local ok, name = pcall(C_Item.GetItemNameByID, itemID)
        if ok then
            local text = Text(name)
            if text then
                return text
            end
        end
    end
    if GetItemInfo then
        local ok, name = pcall(GetItemInfo, itemID)
        if ok then
            return Text(name)
        end
    end
    return nil
end

local function HandleCraftResult(first)
    if type(first) == "table" then
        local qty = Num(first.quantity)
        if not qty then
            qty = Num(first.numCrafted)
        end
        local link = Text(first.hyperlink)
        local fromLink = nil
        if link then
            fromLink = Text(string.match(link, "%[(.-)%]"))
        end
        if fromLink then
            SpeakGain(fromLink, qty, "progressSkill")
            return
        end
        local itemID = Num(first.itemID)
        if not itemID then
            itemID = Num(first.itemId)
        end
        SpeakGain(ItemNameByID(itemID), qty, "progressSkill")
        return
    end
    SpeakGain(ItemNameByID(first), nil, "progressSkill")
end

local function HandleRecipe(recipeID)
    if not live or not On("progressSkill") then
        return
    end
    local name
    if C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo then
        local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipeID)
        if ok and type(info) == "table" then
            name = Text(info.name)
        end
    end
    if not name and C_Spell and C_Spell.GetSpellName then
        local ok, spellName = pcall(C_Spell.GetSpellName, recipeID)
        if ok then
            name = Text(spellName)
        end
    end
    if not name and GetSpellInfo then
        local ok, spellName = pcall(GetSpellInfo, recipeID)
        if ok then
            name = Text(spellName)
        end
    end
    if name then
        Say("Recipe learned: " .. name .. ".")
    else
        Say("Recipe learned.")
    end
end

local function HandleLevelUp(level, _, _, numNewTalents)
    if not On("stateLevelUp") then
        return
    end
    level = Num(tonumber(level))
    if not level and UnitLevel then
        local ok, value = pcall(UnitLevel, "player")
        if ok then
            level = Num(value)
        end
    end
    if not level then
        return
    end
    Say(string.format("Level %d.", level))
    numNewTalents = Num(tonumber(numNewTalents))
    if numNewTalents and numNewTalents > 0 then
        if numNewTalents == 1 then
            Say("New talent point available.")
        else
            Say(string.format("%d new talent points available.", numNewTalents))
        end
    end
end

local place = {}
local followName = nil
local following = false
local followGen = 0

local function CallFlag(fn, ...)
    if not fn then
        return nil
    end
    local ok, value = pcall(fn, ...)
    if not ok then
        return nil
    end
    return Flag(value)
end

local function PlaceChanged(key, now, onLine, offLine, toggle)
    if now == nil then
        return
    end
    local prev = place[key]
    place[key] = now
    if not live or prev == nil or prev == now or not On(toggle) then
        return
    end
    if now then
        Say(onLine)
    else
        Say(offLine)
    end
end

local lastMoney = nil
local bagsFull = nil
local durabilityLow = nil
local lastPetName = nil
local lastPetHealAt = nil
local lastPetHealSpell = nil
local stuck = { x = nil, y = nil, since = nil, said = false }
local fall = { since = nil, said = false }

local function MoneyWords(copper)
    copper = Num(copper)
    if not copper then
        return nil
    end
    if copper < 0 then
        copper = -copper
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper - (gold * 10000)) / 100)
    local cu = copper - (gold * 10000) - (silver * 100)
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = tostring(gold) .. " gold"
    end
    if silver > 0 then
        parts[#parts + 1] = tostring(silver) .. " silver"
    end
    if cu > 0 or #parts == 0 then
        parts[#parts + 1] = tostring(cu) .. " copper"
    end
    return table.concat(parts, ", ")
end

local function DeathState()
    if CallFlag(UnitIsGhost, "player") then
        return "ghost"
    end
    if CallFlag(UnitIsDead, "player") then
        return "dead"
    end
    if CallFlag(UnitIsDeadOrGhost, "player") then
        return "dead"
    end
    return "alive"
end

local function FormName()
    if not GetShapeshiftForm or not GetShapeshiftFormInfo then
        return false
    end
    local ok, form = pcall(GetShapeshiftForm)
    form = ok and Num(form) or nil
    if not form or form <= 0 then
        return false
    end
    local infoOk, a, b, c, d = pcall(GetShapeshiftFormInfo, form)
    if not infoOk then
        return false
    end
    local name = Text(b)
    local spellID = Num(d)
    if not name then
        spellID = Num(c)
    end
    if name then
        return name
    end
    if spellID and spellID > 0 then
        if C_Spell and C_Spell.GetSpellName then
            local spellOk, spellName = pcall(C_Spell.GetSpellName, spellID)
            spellName = spellOk and Text(spellName) or nil
            if spellName then
                return spellName
            end
        end
        if GetSpellInfo then
            local spellOk, spellName = pcall(GetSpellInfo, spellID)
            spellName = spellOk and Text(spellName) or nil
            if spellName then
                return spellName
            end
        end
    end
    return "Form " .. tostring(form)
end

local function InGroupNow()
    local grouped = CallFlag(IsInGroup)
    if grouped ~= nil and IsInGroup then
        return grouped
    end
    local count = nil
    if GetNumGroupMembers then
        local ok, value = pcall(GetNumGroupMembers)
        count = ok and Num(value) or nil
    end
    if count == nil and GetNumRaidMembers and GetNumPartyMembers then
        local raidOk, raid = pcall(GetNumRaidMembers)
        local partyOk, party = pcall(GetNumPartyMembers)
        local raidCount = raidOk and Num(raid) or 0
        local partyCount = partyOk and Num(party) or 0
        count = raidCount + partyCount
    end
    if count == nil then
        return nil
    end
    return count > 0
end

local function Now()
    if not GetTime then
        return 0
    end
    local ok, t = pcall(GetTime)
    return ok and Num(t) or 0
end

local function MirrorTimer(kind)
    local found = { present = false, low = false }
    if not GetMirrorTimerInfo then
        return found
    end
    local i
    for i = 1, 3 do
        local ok, timerName, value, maximum, scale = pcall(GetMirrorTimerInfo, i)
        if ok then
            local name = Text(timerName)
            if name == kind then
                found.present = true
                value = Num(value)
                maximum = Num(maximum)
                scale = Num(scale)
                if value and maximum and maximum > 0 and scale and scale < 0 and (value / maximum) < 0.35 then
                    found.low = true
                end
                return found
            end
        end
    end
    return found
end

local function FatigueTimer()
    local exhaustion = MirrorTimer("EXHAUSTION")
    if exhaustion.present then
        return exhaustion
    end
    return MirrorTimer("FATIGUE")
end

local function PetLabel()
    if not UnitName then
        return lastPetName
    end
    local ok, name = pcall(UnitName, "pet")
    name = ok and Text(name) or nil
    if name then
        lastPetName = name
    end
    return name or lastPetName
end

local function NoteBar(key, present, low, onKey, appearLine, lowLine, clearLine)
    local prevPresent = place[key .. "Present"]
    local prevLow = place[key .. "Low"]
    if prevPresent == nil then
        place[key .. "Present"] = present
        place[key .. "Low"] = low
        return
    end
    place[key .. "Present"] = present
    place[key .. "Low"] = low
    if not live or not On(onKey) then
        return
    end
    if appearLine and present and not prevPresent then
        Say(appearLine)
    end
    if lowLine and present and low and not prevLow then
        Say(lowLine)
    end
    if clearLine and prevPresent and not present then
        Say(clearLine)
    end
end

local function PlayerMapXY()
    if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then
        return nil, nil
    end
    local mapOk, mapID = pcall(C_Map.GetBestMapForUnit, "player")
    mapID = mapOk and Num(mapID) or nil
    if not mapID then
        return nil, nil
    end
    local posOk, pos = pcall(C_Map.GetPlayerMapPosition, mapID, "player")
    if not posOk or not pos or not pos.GetXY then
        return nil, nil
    end
    local xyOk, x, y = pcall(pos.GetXY, pos)
    if not xyOk then
        return nil, nil
    end
    return Num(x), Num(y)
end

local function CheckStuck()
    if not On("stateStuck") then
        stuck.since = nil
        stuck.said = false
        return
    end
    if CallFlag(_G.IsFlying) or CallFlag(_G.IsFalling) or CallFlag(_G.IsSwimming) or CallFlag(UnitOnTaxi, "player") then
        stuck.since = nil
        stuck.said = false
        return
    end
    if DeathState() ~= "alive" then
        stuck.since = nil
        stuck.said = false
        return
    end
    local moving = false
    if GetUnitSpeed then
        local ok, speed = pcall(GetUnitSpeed, "player")
        speed = ok and Num(speed) or nil
        moving = speed ~= nil and speed > 0
    end
    if not moving then
        stuck.since = nil
        stuck.said = false
        return
    end
    local x, y = PlayerMapXY()
    if not x or not y then
        return
    end
    local now = 0
    if GetTime then
        local ok, t = pcall(GetTime)
        now = ok and Num(t) or 0
    end
    if stuck.x and stuck.y then
        local dx = x - stuck.x
        local dy = y - stuck.y
        if (dx * dx) + (dy * dy) < 0.00000004 then
            if not stuck.since then
                stuck.since = now
            elseif not stuck.said and (now - stuck.since) >= 3 then
                stuck.said = true
                if live then
                    Say("Stuck.")
                end
            end
        else
            stuck.since = now
            stuck.said = false
        end
    else
        stuck.since = now
        stuck.said = false
    end
    stuck.x = x
    stuck.y = y
end

local function PollYou()
    local flying = CallFlag(_G.IsFlying)
    local swimming = CallFlag(_G.IsSwimming)
    local indoors = CallFlag(_G.IsIndoors)
    local mounted = CallFlag(_G.IsMounted)
    local afk = CallFlag(UnitIsAFK, "player")
    PlaceChanged("fly", flying, "Flying.", "Stopped flying.", "stateFly")
    PlaceChanged("swim", swimming, "Swimming.", "Stopped swimming.", "stateSwim")
    PlaceChanged("indoors", indoors, "Indoor.", "Outdoors.", "stateIndoors")
    PlaceChanged("mount", mounted, "Mounted.", "Off mount.", "stateMount")
    PlaceChanged("afk", afk, "AFK on.", "AFK off.", "stateAFK")
    PlaceChanged("rest", CallFlag(IsResting), "Entered rested area.", "Left rested area.", "stateResting")
    PlaceChanged("taxi", CallFlag(UnitOnTaxi, "player"), "On Taxi.", "Taxi ended.", "stateTaxi")
    PlaceChanged("pvp", CallFlag(UnitIsPVP, "player"), "PVP on.", "PVP off.", "statePvP")
    PlaceChanged("stealth", CallFlag(IsStealthed), "Your in stealth.", "You are no longer stealthed.", "stateStealth")
    PlaceChanged("group", InGroupNow(), "Joined group.", "Left group.", "stateGroup")

    local breath = MirrorTimer("BREATH")
    NoteBar("breath", breath.present, breath.low, "stateBreath", nil, "Your breathing is low.", "Above water.")
    local tired = FatigueTimer()
    NoteBar("fatigue", tired.present, tired.low, "stateFatigue", "You are getting Fatigued.", "Your fatigue is low.", "Fatigue is cleared.")

    local falling = CallFlag(_G.IsFalling)
    if falling == true then
        if not fall.since then
            fall.since = Now()
            fall.said = false
        elseif not fall.said and live and On("stateFalling") and (Now() - fall.since) >= 1 then
            fall.said = true
            Say("Your falling.")
        end
    elseif falling == false then
        fall.since = nil
        fall.said = false
    end

    local death = DeathState()
    local prevDeath = place.death
    place.death = death
    if live and prevDeath ~= nil and prevDeath ~= death then
        if death == "dead" and On("stateDead") then
            Say("Your Dead.")
        elseif death == "ghost" and On("stateGhost") then
            Say("Ghost.")
        elseif death == "alive" and On("stateResurrected") then
            Say("Your Resurrected.")
        end
    end

    local form = FormName()
    local prevForm = place.form
    place.form = form
    if live and prevForm ~= nil and prevForm ~= form and On("stateShapeshift") then
        if form and form ~= false then
            Say("You have shifted into " .. form .. ".")
        else
            Say("You shifted back.")
        end
    end

    local petName = PetLabel()
    local petExists = CallFlag(UnitExists, "pet")
    local petState = nil
    if petExists == nil then
        petState = nil
    elseif not petExists then
        petState = "none"
    elseif CallFlag(UnitIsDead, "pet") then
        petState = "dead"
    else
        petState = "alive"
    end
    if petState ~= nil then
        local prevPet = place.pet
        place.pet = petState
        local spoken = petName or "Pet"
        if live and prevPet ~= nil and prevPet ~= petState and On("statePet") then
            if prevPet == "none" and petState == "alive" then
                Say(spoken .. " summoned.")
            elseif petState == "none" then
                Say(spoken .. " is dismissed.")
            elseif prevPet == "dead" and petState == "alive" then
                Say(spoken .. " Revived.")
            elseif prevPet == "alive" and petState == "dead" then
                Say(spoken .. " dead.")
            end
        end
        if petState == "none" then
            place.petFeed = nil
            place.petLow = nil
        elseif petState == "alive" then
            local happy = nil
            if GetPetHappiness then
                local happyOk, happyValue = pcall(GetPetHappiness)
                happy = happyOk and Num(happyValue) or nil
            end
            if happy ~= nil and happy > 0 then
                local needsFeed = happy < 3
                if place.petFeed == nil or not live then
                    place.petFeed = needsFeed
                elseif needsFeed and not place.petFeed then
                    place.petFeed = true
                    if On("statePet") then
                        Say("Feed " .. spoken .. ".")
                    end
                elseif not needsFeed then
                    place.petFeed = false
                end
            end
            local health = nil
            local healthMax = nil
            if UnitHealth and UnitHealthMax then
                local healthOk, healthValue = pcall(UnitHealth, "pet")
                local maxOk, maxValue = pcall(UnitHealthMax, "pet")
                health = healthOk and Num(healthValue) or nil
                healthMax = maxOk and Num(maxValue) or nil
            end
            local healthLow = nil
            if health ~= nil and healthMax ~= nil then
                local ratioOk, ratio = pcall(function()
                    if healthMax > 0 then
                        return (health / healthMax) < 0.35
                    end
                    return nil
                end)
                if ratioOk then
                    healthLow = ratio
                end
            end
            if healthLow ~= nil then
                if place.petLow == nil or not live then
                    place.petLow = healthLow
                elseif healthLow and not place.petLow then
                    place.petLow = true
                    if On("statePet") then
                        Say(spoken .. " health is under 35%.")
                    end
                elseif not healthLow then
                    place.petLow = false
                end
            end
        end
    end

    local freeSlots = nil
    local bag
    for bag = 0, 4 do
        local count = nil
        if C_Container and C_Container.GetContainerNumFreeSlots then
            local ok, value = pcall(C_Container.GetContainerNumFreeSlots, bag)
            count = ok and Num(value) or nil
        elseif GetContainerNumFreeSlots then
            local ok, value = pcall(GetContainerNumFreeSlots, bag)
            count = ok and Num(value) or nil
        end
        if count then
            freeSlots = (freeSlots or 0) + count
        end
    end
    if freeSlots ~= nil then
        local full = freeSlots == 0
        local prevFull = bagsFull
        bagsFull = full
        if live and prevFull == false and full and On("stateBagFull") then
            Say("Your bags are full.")
        end
    end

    if GetInventoryItemDurability then
        local current, maximum = 0, 0
        local slot
        for slot = 1, 18 do
            local ok, durability, cap = pcall(GetInventoryItemDurability, slot)
            durability = ok and Num(durability) or nil
            cap = ok and Num(cap) or nil
            if durability and cap and cap > 0 then
                current = current + durability
                maximum = maximum + cap
            end
        end
        if maximum > 0 then
            local low = (current / maximum) < 0.25
            local full = current >= maximum
            if durabilityLow == nil or not live then
                durabilityLow = low
            elseif low and not durabilityLow then
                durabilityLow = true
                if On("stateDurability") then
                    Say("Durability is low.")
                end
            elseif full and durabilityLow then
                durabilityLow = false
                if On("stateDurability") then
                    Say("Durability is Restored.")
                end
            end
        end
    end

    if GetMoney then
        local ok, money = pcall(GetMoney)
        money = ok and Num(money) or nil
        if money then
            local prevMoney = lastMoney
            lastMoney = money
            if live and prevMoney ~= nil and prevMoney ~= money and On("stateMoney") then
                local words = MoneyWords(money - prevMoney)
                if words then
                    if money > prevMoney then
                        Say("You gained " .. words .. ".")
                    else
                        Say("You spent " .. words .. ".")
                    end
                end
            end
        end
    end

    CheckStuck()
end

local function PollPlace()
    PollYou()
end

local function LooksLikeUnit(token)
    token = Text(token)
    if not token then
        return false
    end
    local lower = string.lower(token)
    if lower == "target" or lower == "focus" or lower == "player" or lower == "pet"
        or lower == "followtarget" or lower == "mouseover" or lower == "npc" or lower == "vehicle"
    then
        return true
    end
    if string.match(lower, "^party%d+$") or string.match(lower, "^raid%d+$") or string.match(lower, "^nameplate%d+$") then
        return true
    end
    return false
end

local function NameOf(token)
    token = Text(token)
    if not token or not UnitExists or not UnitName then
        return nil
    end
    local ok, exists = pcall(UnitExists, token)
    if not ok or not Flag(exists) then
        return nil
    end
    local nameOk, name = pcall(UnitName, token)
    if nameOk then
        return Text(name)
    end
    return nil
end

local function ResolveFollowName(arg)
    local fromArg = NameOf(arg)
    if fromArg then
        return fromArg
    end
    arg = Text(arg)
    if arg and not LooksLikeUnit(arg) then
        return arg
    end
    local followed = NameOf("followtarget")
    if followed then
        return followed
    end
    return followName
end

local function InVehicle()
    if UnitInVehicle then
        local riding = CallFlag(UnitInVehicle, "player")
        if riding then
            return true
        end
    end
    return false
end

local function BeginFollow(arg)
    if InVehicle() then
        return
    end
    followGen = followGen + 1
    local name = ResolveFollowName(arg)
    if following and name and followName and string.lower(name) == string.lower(followName) then
        followName = name
        return
    end
    if name then
        followName = name
    end
    following = true
    if not live or not On("stateFollow") then
        return
    end
    if followName then
        Say("Following " .. followName .. ".")
    else
        Say("Following.")
    end
end

local function EndFollow()
    if InVehicle() then
        return
    end
    followGen = followGen + 1
    local gen = followGen
    local name = followName
    local function finish()
        if gen ~= followGen then
            return
        end
        following = false
        followName = nil
        if not live or not On("stateFollow") then
            return
        end
        if name then
            Say("Stopped following " .. name .. ".")
        else
            Say("Stopped following.")
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.2, finish)
    else
        finish()
    end
end

local tame = { name = nil, sentAt = 0, channeling = false, reason = nil }
local tameGen = 0
local lastErrorText = nil
local lastErrorAt = 0

local function IsTameSpell(name)
    name = Text(name)
    if not name then
        return false
    end
    return string.find(string.lower(name), "tame beast", 1, true) ~= nil
end

local function SpellNameFromID(spellID)
    if not spellID or spellID <= 0 then
        return nil
    end
    local spellName = nil
    if C_Spell and C_Spell.GetSpellName then
        local spellOk, spellValue = pcall(C_Spell.GetSpellName, spellID)
        spellName = spellOk and Text(spellValue) or nil
    end
    if not spellName and GetSpellInfo then
        local spellOk, spellValue = pcall(GetSpellInfo, spellID)
        spellName = spellOk and Text(spellValue) or nil
    end
    return spellName
end

local function SpellNameFromArgs(...)
    local argCount = select("#", ...)
    local argIndex
    for argIndex = 1, argCount do
        local spellName = SpellNameFromID(Num(select(argIndex, ...)))
        if spellName then
            return spellName
        end
    end
    for argIndex = 2, argCount do
        local argName = Text(select(argIndex, ...))
        if argName then
            local lower = string.lower(argName)
            if string.find(lower, "tame beast", 1, true) or string.find(lower, "mend", 1, true) then
                return argName
            end
        end
    end
    return nil
end

local function EventIsTame(...)
    if IsTameSpell(SpellNameFromArgs(...)) then
        return true
    end
    if UnitChannelInfo then
        local ok, value = pcall(UnitChannelInfo, "player")
        if IsTameSpell(ok and Text(value) or nil) then
            return true
        end
    end
    if UnitCastingInfo then
        local ok, value = pcall(UnitCastingInfo, "player")
        if IsTameSpell(ok and Text(value) or nil) then
            return true
        end
    end
    return false
end

local function CleanError(msg)
    msg = Text(msg)
    if not msg then
        return nil
    end
    if AH.ChatText and AH.ChatText.ForChatMessage then
        local ok, cleaned = pcall(AH.ChatText.ForChatMessage, msg)
        cleaned = ok and Text(cleaned) or nil
        if cleaned then
            return cleaned
        end
    end
    msg = string.gsub(msg, "|H.-|h(.-)|h", "%1")
    msg = string.gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
    msg = string.gsub(msg, "|r", "")
    msg = string.gsub(msg, "%s+", " ")
    return msg
end

local function ItemFromError(msg)
    msg = CleanError(msg)
    if not msg then
        return nil
    end
    local item = string.match(msg, "%[(.-)%]")
    if item and item ~= "" then
        return item
    end
    local needed = string.match(msg, "[Nn]eeds? ([^%.%!]+)")
    if not needed then
        needed = string.match(msg, "[Rr]equires? ([^%.%!]+)")
    end
    if not needed then
        return nil
    end
    needed = string.gsub(needed, "^%s+", "")
    needed = string.gsub(needed, "%s+$", "")
    needed = string.gsub(needed, "%s+[Tt]o tame.*$", "")
    needed = string.gsub(needed, "%s+[Tt]his .*$", "")
    if needed == "" or string.len(needed) > 60 then
        return nil
    end
    return needed
end

local function TameTargetFromArgs(...)
    if UnitName then
        local ok, name = pcall(UnitName, "target")
        name = ok and Text(name) or nil
        if name then
            return name
        end
    end
    local argCount = select("#", ...)
    local argIndex
    for argIndex = 1, argCount do
        local text = Text(select(argIndex, ...))
        if text and text ~= "player" and not IsTameSpell(text) and not string.find(text, "Cast-", 1, true) and not string.match(text, "^%d+$") then
            return text
        end
    end
    return tame.name
end

local function RecentTame()
    if tame.sentAt == 0 then
        return false
    end
    return (Now() - tame.sentAt) < 3
end

local function RecentError()
    if type(lastErrorText) ~= "string" or lastErrorText == "" then
        return nil
    end
    local now = Now()
    if type(now) ~= "number" or type(lastErrorAt) ~= "number" then
        return nil
    end
    if (now - lastErrorAt) > 2 then
        return nil
    end
    return lastErrorText
end

local function PetIsOut()
    if not UnitExists or not AH.Compat or not AH.Compat.SafeBool then
        return false
    end
    return AH.Compat.SafeBool(UnitExists, "pet")
end

local function ActivePetReason(reason)
    local lower = reason and string.lower(reason) or ""
    if string.find(lower, "already", 1, true) and (string.find(lower, "pet", 1, true) or string.find(lower, "summon", 1, true)) then
        return true
    end
    if string.find(lower, "dismiss", 1, true) and string.find(lower, "pet", 1, true) then
        return true
    end
    return false
end

local function SayCantTame()
    if not live or not On("statePet") then
        return
    end
    if not tame.reason then
        tame.reason = RecentError()
    end
    local name = tame.name or "Target"
    local item = ItemFromError(tame.reason)
    local reason = CleanError(tame.reason)
    local lower = reason and string.lower(reason) or ""
    Say(name .. " can't be tamed.")
    if item then
        Say(name .. " cant be tamed needs " .. item .. " to tame.")
    elseif string.find(lower, "level", 1, true) then
        Say(name .. " is too high a level to tame.")
    elseif ActivePetReason(reason) or PetIsOut() then
        Say("Another pet is active.")
    else
        Say(name .. " is not allowed to be tamed.")
    end
    tame.channeling = false
    tame.sentAt = 0
    tame.reason = nil
end

local function ScheduleCantTame()
    tameGen = tameGen + 1
    local gen = tameGen
    local function finish()
        if gen ~= tameGen then
            return
        end
        if tame.channeling then
            return
        end
        SayCantTame()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.25, finish)
    else
        finish()
    end
end

local function BeginTame()
    if tame.channeling then
        return
    end
    tame.channeling = true
    tameGen = tameGen + 1
    if live and On("statePet") then
        Say((tame.name or "Target") .. " is getting tamed.")
    end
end

local function ScheduleTamed()
    tameGen = tameGen + 1
    local gen = tameGen
    local fallback = tame.name
    local function finish()
        if gen ~= tameGen then
            return
        end
        tame.channeling = false
        tame.sentAt = 0
        tame.reason = nil
        if not live or not On("statePet") then
            return
        end
        Say((PetLabel() or fallback or "Pet") .. " is tamed.")
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0.4, finish)
    else
        finish()
    end
end

local function Seed()
    live = false
    seedGen = seedGen + 1
    local gen = seedGen
    PollPlace()
    ScanSkills()
    if C_Timer and C_Timer.After then
        C_Timer.After(2, function()
            if gen == seedGen then
                PollPlace()
                ScanSkills()
                live = true
            end
        end)
    else
        live = true
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("NEW_RECIPE_LEARNED")
frame:RegisterEvent("AUTOFOLLOW_BEGIN")
frame:RegisterEvent("AUTOFOLLOW_END")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterEvent("PLAYER_FLAGS_CHANGED")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("CHAT_MSG_TRADESKILLS")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("BAG_UPDATE")
frame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")
frame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
frame:RegisterEvent("UPDATE_STEALTH")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("PET_BAR_UPDATE")
frame:RegisterEvent("MIRROR_TIMER_START")
frame:RegisterEvent("MIRROR_TIMER_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:RegisterEvent("UNIT_SPELLCAST_SENT")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UI_ERROR_MESSAGE")
if frame.RegisterEvent then
    pcall(frame.RegisterEvent, frame, "TRADE_SKILL_ITEM_CRAFTED_RESULT")
end
local bodyPoll = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    if type(elapsed) ~= "number" then
        return
    end
    bodyPoll = bodyPoll + elapsed
    if bodyPoll < 0.4 then
        return
    end
    bodyPoll = 0
    PollPlace()
end)

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Seed()
        return
    end
    if event == "SKILL_LINES_CHANGED" then
        ScanSkills()
        return
    end
    if event == "NEW_RECIPE_LEARNED" then
        HandleRecipe(...)
        return
    end
    if event == "AUTOFOLLOW_BEGIN" then
        BeginFollow(...)
        return
    end
    if event == "AUTOFOLLOW_END" then
        EndFollow()
        return
    end
    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_FLAGS_CHANGED"
        or event == "PLAYER_DEAD" or event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST"
        or event == "PLAYER_UPDATE_RESTING" or event == "PLAYER_MONEY" or event == "BAG_UPDATE"
        or event == "UPDATE_INVENTORY_DURABILITY" or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UPDATE_STEALTH" or event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET"
        or event == "PET_BAR_UPDATE" or event == "MIRROR_TIMER_START" or event == "MIRROR_TIMER_STOP"
    then
        PollPlace()
        return
    end
    if event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_TRADESKILLS" then
        HandleLootChat(...)
        return
    end
    if event == "PLAYER_LEVEL_UP" then
        HandleLevelUp(...)
        return
    end
    if event == "UI_ERROR_MESSAGE" then
        local argCount = select("#", ...)
        local argIndex
        local text = nil
        for argIndex = 1, argCount do
            local piece = Text(select(argIndex, ...))
            if piece then
                text = piece
            end
        end
        if text then
            lastErrorText = text
            lastErrorAt = Now()
            if RecentTame() then
                tame.reason = text
            end
        end
        return
    end
    if event == "UNIT_SPELLCAST_SENT" then
        local unit = Text(select(1, ...))
        if unit ~= "player" or not EventIsTame(...) then
            return
        end
        tame.name = TameTargetFromArgs(...)
        tame.sentAt = Now()
        tame.channeling = false
        tame.reason = RecentError()
        return
    end
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        local unit = Text(select(1, ...))
        if unit ~= "player" or not EventIsTame(...) then
            return
        end
        if not tame.name then
            tame.name = TameTargetFromArgs(...)
        end
        BeginTame()
        return
    end
    if event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit = Text(select(1, ...))
        if unit ~= "player" then
            return
        end
        local spellName = SpellNameFromArgs(...)
        if spellName and not IsTameSpell(spellName) then
            return
        end
        if not spellName and not RecentTame() and not (PetIsOut() and ActivePetReason(CleanError(RecentError()))) then
            return
        end
        if not tame.name then
            tame.name = TameTargetFromArgs(...)
        end
        if not tame.reason then
            tame.reason = RecentError()
        end
        if tame.channeling then
            tame.channeling = false
            tame.sentAt = 0
            tameGen = tameGen + 1
            return
        end
        ScheduleCantTame()
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not live or not On("statePet") then
            return
        end
        local unit = Text(select(1, ...))
        if unit ~= "player" then
            return
        end
        local spellName = SpellNameFromArgs(...)
        if not spellName then
            return
        end
        if IsTameSpell(spellName) then
            ScheduleTamed()
            return
        end
        local lowerName = string.lower(spellName)
        if not string.find(lowerName, "mend", 1, true) or string.find(lowerName, "revive", 1, true) then
            return
        end
        local now = Now()
        if lastPetHealSpell == spellName and lastPetHealAt and (now - lastPetHealAt) < 12 then
            return
        end
        lastPetHealSpell = spellName
        lastPetHealAt = now
        Say((PetLabel() or "Pet") .. " was healed.")
        return
    end
    if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        HandleCraftResult(...)
    end
end)
