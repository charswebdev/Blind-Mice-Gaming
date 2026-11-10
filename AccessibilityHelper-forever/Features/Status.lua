--[[
  Accessibility Helper — short status lines
  Speaks skill, level, follow, and place.
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
    if AH.Compat and AH.Compat.CanUseNumber and AH.Compat.CanUseNumber(v) then
        return v
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

local function PollPlace()
    local flying = CallFlag(_G.IsFlying)
    local swimming = CallFlag(_G.IsSwimming)
    local indoors = CallFlag(_G.IsIndoors)
    local mounted = CallFlag(_G.IsMounted)
    local afk = nil
    if UnitIsAFK then
        afk = CallFlag(UnitIsAFK, "player")
    end
    PlaceChanged("fly", flying, "Flying.", "Stopped flying.", "stateFly")
    PlaceChanged("swim", swimming, "Swimming.", "Stopped swimming.", "stateSwim")
    PlaceChanged("indoors", indoors, "Indoor.", "Outdoors.", "stateIndoors")
    PlaceChanged("mount", mounted, "Mounted.", "Off mount.", "stateMount")
    PlaceChanged("afk", afk, "AFK on.", "AFK off.", "stateAFK")
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
if frame.RegisterEvent then
    pcall(frame.RegisterEvent, frame, "TRADE_SKILL_ITEM_CRAFTED_RESULT")
end

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
    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_FLAGS_CHANGED" then
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
    if event == "TRADE_SKILL_ITEM_CRAFTED_RESULT" then
        HandleCraftResult(...)
    end
end)
