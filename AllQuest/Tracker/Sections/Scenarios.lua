--[[
  AllQuest — scenario / dungeon / Mythic+ / delve tracker
  Lua 5.1 only. Nil-guard Retail APIs for Classic.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

local NEMESIS_SPELL = {
    [1270179] = true,
    [1307638] = true,
    [1239535] = true,
    [472952] = true,
}

-- Fill/upgrade auras on the Strongbox itself — not Nemesis Influence (1270179).
local STRONGBOX_AURA_SPELLS = {
    1239535,
    472952,
}

local DELVE_SPELL_WIDGETS = {
    7526,
    7591,
    7592,
    7624,
    7761,
    7764,
    7861,
}

local function Clock(sec)
    sec = math.floor(tonumber(sec) or 0)
    if sec < 0 then
        sec = 0
    end
    if SecondsToClock then
        local ok, text = pcall(SecondsToClock, sec)
        if ok and type(text) == "string" then
            return text
        end
    end
    local m = math.floor(sec / 60)
    local s = sec - m * 60
    if m >= 60 then
        local h = math.floor(m / 60)
        m = m - h * 60
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%d:%02d", m, s)
end

local function SpellName(id)
    if type(id) ~= "number" then
        return nil
    end
    if C_Spell and C_Spell.GetSpellName then
        return AQ:SafeCall(C_Spell.GetSpellName, id)
    end
    if GetSpellInfo then
        return AQ:SafeCall(GetSpellInfo, id)
    end
    return nil
end

local function SpellIcon(id)
    if type(id) ~= "number" then
        return nil
    end
    if C_Spell and C_Spell.GetSpellTexture then
        return AQ:SafeCall(C_Spell.GetSpellTexture, id)
    end
    if GetSpellTexture then
        return AQ:SafeCall(GetSpellTexture, id)
    end
    return nil
end

local function SpellDesc(id)
    if type(id) ~= "number" then
        return nil
    end
    if C_Spell and C_Spell.GetSpellDescription then
        return AQ:SafeCall(C_Spell.GetSpellDescription, id)
    end
    return nil
end

local function IsShownState(state)
    if state == nil then
        return true
    end
    if Enum and Enum.WidgetShownState and Enum.WidgetShownState.Hidden then
        return state ~= Enum.WidgetShownState.Hidden
    end
    return state ~= 0
end

local function ChallengeType()
    if LE_SCENARIO_TYPE_CHALLENGE_MODE then
        return LE_SCENARIO_TYPE_CHALLENGE_MODE
    end
    if Enum and Enum.ScenarioType and Enum.ScenarioType.ChallengeMode then
        return Enum.ScenarioType.ChallengeMode
    end
    return 8
end

local function TimerTypeChallenge()
    if Enum and Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes.ChallengeMode then
        return Enum.WorldElapsedTimerTypes.ChallengeMode
    end
    return 1
end

local function TimerTypeProving()
    if Enum and Enum.WorldElapsedTimerTypes and Enum.WorldElapsedTimerTypes.ProvingGround then
        return Enum.WorldElapsedTimerTypes.ProvingGround
    end
    return 2
end

local function InstanceBits()
    if not GetInstanceInfo then
        return nil
    end
    local name, instanceType, difficultyID, difficultyName, maxPlayers = AQ:SafeCall(GetInstanceInfo)
    if type(difficultyName) ~= "string" or difficultyName == "" then
        if type(difficultyID) == "number" and GetDifficultyInfo then
            difficultyName = AQ:SafeCall(GetDifficultyInfo, difficultyID)
        end
    end
    return {
        name = name,
        instanceType = instanceType,
        difficultyID = difficultyID,
        difficultyName = difficultyName,
        maxPlayers = maxPlayers,
    }
end

local function AddRow(rows, spec)
    rows[#rows + 1] = spec
end

local function AddAffixRows(rows, affixes)
    if type(affixes) ~= "table" then
        return
    end
    local icons = {}
    for i = 1, #affixes do
        local affixID = affixes[i]
        if type(affixID) == "number" and C_ChallengeMode and C_ChallengeMode.GetAffixInfo then
            local name, description, file = AQ:SafeCall(C_ChallengeMode.GetAffixInfo, affixID)
            if type(name) == "string" and name ~= "" then
                icons[#icons + 1] = { file = file, tooltip = name }
                AddRow(rows, {
                    kind = "quest",
                    title = name,
                    icon = file,
                    detail = description,
                    speech = "Affix " .. name,
                })
            end
        end
    end
    return icons
end

local function ClassifyDelveSpell(info)
    local id = tonumber(info and info.spellID)
    local name = info and info.text
    if type(name) ~= "string" or name == "" then
        name = SpellName(id) or "Modifier"
    end
    local tip = (info and info.tooltip) or SpellDesc(id) or ""
    local blob = ""
    local ok, lower = pcall(string.lower, tostring(name or "") .. " " .. tostring(tip or ""))
    if ok and type(lower) == "string" then
        blob = lower
    end
    if (id and NEMESIS_SPELL[id]) or blob:find("nemesis", 1, true) then
        return "nemesis", name, tip
    end
    if blob:find("bountiful", 1, true) or blob:find("coffer", 1, true) then
        return "bountiful", name, tip
    end
    return "affix", name, tip
end

-- Everything Delves: Strongbox has no in-delve widget (picker only). One
-- vignette ID per remaining pack; each season appends a new ID. Banner is
-- player auras + interact casts; vignette names can be Midnight secrets.
local NEMESIS_PACK_VIGNETTES = {
    7531,
    7869,
}
local PACK_NAME_WORDS = {
    "ula'tek",
    "ulatek",
    "ula tek",
    "ula'tek's chosen",
    "pactsworn",
    "nullaeus",
    "nemesis pack",
    "nemesis packs",
    "azta'rec",
    "aztarec",
}
local BANNER_INTERACT_SPELLS = {
    [1269411] = true,
    [1269412] = true,
    [1269416] = true,
}
local BANNER_BUFF_SPELLS = {
    [1271918] = true,
    [1271945] = true,
    [1272609] = true,
    [1272666] = true,
    [1272756] = true,
    [1272769] = true,
    [1272809] = true,
    [1272810] = true,
    [1272813] = true,
    [1272814] = true,
    [1273058] = true,
    [1273066] = true,
}
local EXTRA_CRITERIA_WORDS = {
    "nemesis pack",
    "nemesis packs",
    "strong box",
    "strongbox",
    "bonus loot",
    "sanctified banner",
    "abundant spoils",
}

local nemesisRun = {
    key = nil,
    remaining = 0,
    seen = {},
    seenCount = 0,
    killedBase = 0,
    killedFromDespawn = 0,
    haveSeenPack = false,
    bannerState = nil,
}

local function SafeText(value)
    if value == nil then
        return ""
    end
    local ok, text = pcall(tostring, value)
    if ok and type(text) == "string" then
        return text
    end
    return ""
end

local function SafeLower(value)
    local text = SafeText(value)
    if text == "" then
        return ""
    end
    local ok, lower = pcall(string.lower, text)
    if ok and type(lower) == "string" then
        return lower
    end
    return ""
end

local function BlobHas(blob, words)
    if type(blob) ~= "string" or blob == "" or type(words) ~= "table" then
        return false
    end
    for i = 1, #words do
        if blob:find(words[i], 1, true) then
            return true
        end
    end
    return false
end

local function LooksLikeNemesis(...)
    local blob = ""
    local n = select("#", ...)
    for i = 1, n do
        blob = blob .. " " .. SafeLower(select(i, ...))
    end
    return blob:find("nemesis", 1, true) and true or false
end

local function SkipExtraCriteria(text)
    return BlobHas(SafeLower(text), EXTRA_CRITERIA_WORDS)
end

local function IsSecret(value)
    if not issecretvalue then
        return false
    end
    local ok, secret = pcall(issecretvalue, value)
    return ok == true and secret == true
end

local function SafeEq(a, b)
    local ok, same = pcall(function()
        return a == b
    end)
    return ok == true and same == true
end

--- Plain table key, or nil. Never index with a secret (Midnight throws).
local function SafeKey(value)
    if IsSecret(value) then
        local ok, text = pcall(tostring, value)
        if ok == true and type(text) == "string" and text ~= "" and not IsSecret(text) then
            return text
        end
        return nil
    end
    if value == nil then
        return nil
    end
    local ok, text = pcall(tostring, value)
    if ok ~= true or type(text) ~= "string" or text == "" then
        return nil
    end
    return text
end

local function RunKey()
    if GetRealZoneText then
        local ok, zone = pcall(GetRealZoneText)
        local text = ok and SafeText(zone) or ""
        if text ~= "" then
            return text
        end
    end
    local inst = InstanceBits()
    return SafeText(inst and inst.name)
end

local function ResetNemesisRun(key)
    nemesisRun.key = key
    nemesisRun.remaining = 0
    nemesisRun.seen = {}
    nemesisRun.seenCount = 0
    nemesisRun.killedBase = 0
    nemesisRun.killedFromDespawn = 0
    nemesisRun.haveSeenPack = false
    nemesisRun.boxSeen = false
    nemesisRun.boxEarned = false
    nemesisRun.bannerState = nil
end

local function EnsureNemesisRun()
    local key = RunKey()
    if key ~= "" and nemesisRun.key ~= key then
        ResetNemesisRun(key)
    elseif not nemesisRun.seen then
        ResetNemesisRun(key)
    end
end

local function IsNemesisPackVignette(vignetteID)
    for i = 1, #NEMESIS_PACK_VIGNETTES do
        if SafeEq(vignetteID, NEMESIS_PACK_VIGNETTES[i]) then
            return true
        end
    end
    return false
end

local function PlayerHasSpellAura(idSet)
    local byId = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(byId) ~= "function" or type(idSet) ~= "table" then
        return false
    end
    for sid in pairs(idSet) do
        local ok, aura = pcall(byId, sid)
        if ok and aura then
            return true
        end
    end
    return false
end

local function VignetteNameLower(name)
    if type(name) ~= "string" then
        return ""
    end
    local ok, lower = pcall(string.lower, name)
    if ok and type(lower) == "string" then
        return lower
    end
    return ""
end

local function InfoLooksLikePack(info)
    if type(info) ~= "table" then
        return false
    end
    if IsNemesisPackVignette(info.vignetteID) then
        return true
    end
    local blob = VignetteNameLower(info.name) .. " " .. VignetteNameLower(info.atlasName)
    return BlobHas(blob, PACK_NAME_WORDS)
end

local function NoteBannerName(ln)
    if ln == "" then
        return
    end
    if ln:find("grand sanctified", 1, true) then
        nemesisRun.bannerState = "grand"
    elseif ln:find("sanctified spoils", 1, true) then
        if nemesisRun.bannerState ~= "grand" then
            nemesisRun.bannerState = "clicked"
        end
    elseif ln:find("sanctified banner", 1, true) then
        if not nemesisRun.bannerState then
            nemesisRun.bannerState = "announced"
        end
    end
end

local function RememberPackKey(info, vigGuid)
    local key = SafeKey(info and info.objectGUID) or SafeKey(vigGuid)
    if not key or nemesisRun.seen[key] then
        return
    end
    nemesisRun.seen[key] = true
    nemesisRun.seenCount = nemesisRun.seenCount + 1
end

local function CollectVignetteGuids()
    local out = {}
    if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then
        return out
    end
    local ok, packed = pcall(function()
        return { C_VignetteInfo.GetVignettes() }
    end)
    if not ok or type(packed) ~= "table" or #packed == 0 then
        return out
    end
    if type(packed[1]) == "table" and packed[2] == nil then
        for k, v in pairs(packed[1]) do
            if type(v) == "string" then
                out[#out + 1] = v
            elseif type(k) == "string" then
                out[#out + 1] = k
            end
        end
        return out
    end
    for i = 1, #packed do
        if type(packed[i]) == "string" then
            out[#out + 1] = packed[i]
        end
    end
    return out
end

local function ScanDelveVignettes()
    EnsureNemesisRun()
    local vigs = CollectVignetteGuids()
    local packCount = 0
    local boxSeen = false
    for i = 1, #vigs do
        local vigGuid = vigs[i]
        pcall(function()
            local ok2, info = pcall(C_VignetteInfo.GetVignetteInfo, vigGuid)
            if ok2 and type(info) == "table" then
                local ln = VignetteNameLower(info.name) .. " " .. VignetteNameLower(info.atlasName)
                if InfoLooksLikePack(info) then
                    packCount = packCount + 1
                    RememberPackKey(info, vigGuid)
                end
                if ln:find("strongbox", 1, true) or ln:find("strong box", 1, true) then
                    boxSeen = true
                    if ln:find("earned", 1, true) or ln:find("unlocked", 1, true) then
                        nemesisRun.boxEarned = true
                    end
                end
                NoteBannerName(VignetteNameLower(info.name))
            end
        end)
    end
    local prev = tonumber(nemesisRun.remaining) or 0
    if nemesisRun.haveSeenPack and packCount < prev then
        nemesisRun.killedFromDespawn = (nemesisRun.killedFromDespawn or 0) + (prev - packCount)
    end
    if packCount > 0 then
        nemesisRun.haveSeenPack = true
    end
    if boxSeen then
        nemesisRun.boxSeen = true
    elseif nemesisRun.boxSeen then
        nemesisRun.boxEarned = true
    end
    nemesisRun.remaining = packCount
end

-- Tooltip/stackDisplay is remaining/total (forum: 2/3 after one of three packs).
local function ParseRemainingSlash(text)
    if type(text) ~= "string" or text == "" or IsSecret(text) then
        return nil
    end
    local ok, blob = pcall(string.lower, text)
    if not ok or type(blob) ~= "string" then
        return nil
    end
    local a, b = string.match(text, "(%d+)%s*/%s*(%d+)")
    a, b = tonumber(a), tonumber(b)
    if a and b and b > 0 and a <= b then
        return a, b
    end
    local n = tonumber(string.match(text, "(%d+)"))
    if n and (blob:find("remaining", 1, true) or blob:find("affected", 1, true) or blob:find("left", 1, true)) then
        return n, nil
    end
    return nil
end

local function SafeStack(v)
    if v == nil or IsSecret(v) then
        return nil
    end
    return tonumber(v)
end

local function ReadSpellProgress(sp)
    if type(sp) ~= "table" then
        return nil
    end
    local earned = sp.showAsEarned == true
    local rem, tot = ParseRemainingSlash(sp.tooltip)
    if not rem then
        rem, tot = ParseRemainingSlash(SpellDesc(tonumber(sp.spellID)))
    end
    if not rem then
        rem = SafeStack(sp.stackDisplay)
    end
    return rem, tot, earned
end

local function ReadStrongboxAuras()
    local byId = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if type(byId) ~= "function" then
        return nil, false
    end
    for i = 1, #STRONGBOX_AURA_SPELLS do
        local ok, aura = pcall(byId, STRONGBOX_AURA_SPELLS[i])
        if ok == true and type(aura) == "table" then
            local stacks = SafeStack(aura.applications)
            return stacks or 0, true
        end
    end
    return nil, false
end

local function ReadSpellDisplayWidget(widgetID)
    local getter = C_UIWidgetManager and C_UIWidgetManager.GetSpellDisplayVisualizationInfo
    if type(getter) ~= "function" or type(widgetID) ~= "number" then
        return nil
    end
    local ok, viz = pcall(getter, widgetID)
    if ok ~= true or type(viz) ~= "table" or type(viz.spellInfo) ~= "table" then
        return nil
    end
    return viz.spellInfo
end

local function CollectNemesisSpells(delve, hint)
    local list = {}
    local function add(sp)
        if type(sp) ~= "table" then
            return
        end
        local kind = ClassifyDelveSpell(sp)
        if kind == "nemesis" or LooksLikeNemesis(sp.text, sp.tooltip, SpellName(tonumber(sp.spellID))) then
            list[#list + 1] = sp
        end
    end
    add(hint)
    if type(delve) == "table" and type(delve.spells) == "table" then
        for i = 1, #delve.spells do
            add(delve.spells[i])
        end
    end
    for i = 1, #DELVE_SPELL_WIDGETS do
        add(ReadSpellDisplayWidget(DELVE_SPELL_WIDGETS[i]))
    end
    local setID
    if C_Scenario and C_Scenario.GetStepInfo then
        local okStep, _, _, _, _, _, _, _, _, _, _, _, widgetSetID = pcall(C_Scenario.GetStepInfo)
        if okStep and type(widgetSetID) == "number" then
            setID = widgetSetID
        end
    end
    if type(setID) == "number" and setID > 0 and C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID then
        local widgets = AQ:SafeCall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
        if type(widgets) == "table" then
            for i = 1, #widgets do
                local w = widgets[i]
                if type(w) == "table" and type(w.widgetID) == "number" then
                    add(ReadSpellDisplayWidget(w.widgetID))
                end
            end
        end
    end
    return list
end

local function BannerIsDone()
    if nemesisRun.bannerState == "grand" or nemesisRun.bannerState == "clicked" or nemesisRun.bannerState == "buffed" then
        return true
    end
    if PlayerHasSpellAura(BANNER_BUFF_SPELLS) or PlayerHasSpellAura(BANNER_INTERACT_SPELLS) then
        nemesisRun.bannerState = "buffed"
        return true
    end
    return false
end

local function ExpectedNemesisPacks(tier)
    tier = tonumber(tier) or 0
    if tier < 4 then
        return 0
    end
    if tier < 6 then
        return 1
    end
    if tier < 8 then
        return 2
    end
    if tier < 10 then
        return 3
    end
    return 4
end

local function NoteBonusMessage(msg)
    local blob = SafeLower(msg)
    if blob == "" then
        return
    end
    if blob:find("sanctified banner", 1, true) then
        EnsureNemesisRun()
        if not nemesisRun.bannerState then
            nemesisRun.bannerState = "announced"
        end
    elseif blob:find("sanctified spoils", 1, true) or blob:find("grand sanctified", 1, true) then
        EnsureNemesisRun()
        nemesisRun.bannerState = blob:find("grand", 1, true) and "grand" or "clicked"
    elseif blob:find("strongbox", 1, true) or blob:find("nemesis", 1, true) then
        if blob:find("upgrad", 1, true) or blob:find("improv", 1, true) then
            EnsureNemesisRun()
            nemesisRun.killedFromDespawn = (nemesisRun.killedFromDespawn or 0) + 1
            nemesisRun.haveSeenPack = true
        end
    end
end

local function AddDelveExtraRow(rows, title, have, need, finished, speech)
    local text = title
    if not finished and have and need then
        text = string.format("%d/%d %s", have, need, title == "Nemesis Strong Box" and "Nemesis Packs defeated" or title)
    end
    AddRow(rows, {
        kind = "objective",
        title = text,
        finished = finished and true or false,
        numFulfilled = have,
        numNeeded = need,
        goldBullet = not finished,
        speech = (speech or title) .. (finished and " complete" or ""),
    })
end

local function AddNemesisExtras(rows, delve, sp, tip, tier)
    EnsureNemesisRun()
    ScanDelveVignettes()
    local expect = ExpectedNemesisPacks(tier)
    if expect <= 0 then
        expect = 4
    end
    local widgetRemaining, total, boxEarned
    total = expect
    local spells = CollectNemesisSpells(delve, sp)
    for i = 1, #spells do
        local rem, tot, earned = ReadSpellProgress(spells[i])
        if earned then
            boxEarned = true
        end
        if rem and (tot or rem > 0 or earned) then
            widgetRemaining = rem
            if tot and tot > 0 then
                total = tot
            end
        end
    end
    if type(tip) == "string" and widgetRemaining == nil then
        local rem, tot = ParseRemainingSlash(tip)
        if rem then
            widgetRemaining = rem
            if tot and tot > 0 then
                total = tot
            end
        end
    end
    local auraStacks = ReadStrongboxAuras()
    local remaining = widgetRemaining
    if remaining == nil then
        remaining = tonumber(nemesisRun.remaining) or 0
    end
    local fromWidget = 0
    if widgetRemaining ~= nil then
        fromWidget = total - widgetRemaining
        if fromWidget < 0 then
            fromWidget = 0
        end
    end
    local fromGuids = (nemesisRun.killedBase or 0) + math.max(0, (nemesisRun.seenCount or 0) - (tonumber(nemesisRun.remaining) or 0))
    local fromDespawn = tonumber(nemesisRun.killedFromDespawn) or 0
    local killed = fromWidget
    if fromGuids > killed then
        killed = fromGuids
    end
    if fromDespawn > killed then
        killed = fromDespawn
    end
    if type(auraStacks) == "number" and auraStacks > killed then
        killed = auraStacks
    end
    if boxEarned or nemesisRun.boxEarned then
        if killed < total then
            killed = total
        end
    end
    if killed + remaining > total and remaining > 0 then
        total = killed + remaining
    end
    if killed > total then
        killed = total
    end
    local packDone = (boxEarned or nemesisRun.boxEarned or (killed >= total and (nemesisRun.haveSeenPack or widgetRemaining ~= nil or killed > 0))) and true or false
    AddDelveExtraRow(rows, "Nemesis Strong Box", killed, total, packDone, "Nemesis Strong Box")
    local bonusDone = BannerIsDone()
    AddDelveExtraRow(rows, "Bonus loot", bonusDone and 1 or 0, 1, bonusDone, "Bonus loot")
end

local function InsertRowsAfter(rows, afterIndex, extras)
    if type(rows) ~= "table" or type(extras) ~= "table" or #extras == 0 then
        return
    end
    local at = tonumber(afterIndex)
    if not at or at < 0 then
        at = #rows
    end
    for i = 1, #extras do
        table.insert(rows, at + i, extras[i])
    end
end

local function AttachNemesisExtras(rows, delve, sp, tip, tier, afterIndex)
    local extras = {}
    local ok = pcall(AddNemesisExtras, extras, delve, sp, tip, tier)
    if not ok or #extras == 0 then
        extras = {}
        local need = ExpectedNemesisPacks(tier)
        if need <= 0 then
            need = 4
        end
        AddDelveExtraRow(extras, "Nemesis Strong Box", 0, need, false, "Nemesis Strong Box")
        AddDelveExtraRow(extras, "Bonus loot", 0, 1, false, "Bonus loot")
    end
    InsertRowsAfter(rows, afterIndex, extras)
end

local function ShortProgressLabel(text, fallback)
    if type(text) ~= "string" then
        return fallback
    end
    text = AQ:Trim(text)
    if text == "" then
        return fallback
    end
    if #text <= 28 then
        return text
    end
    return fallback
end

local function GetDelveWidget()
    if not (C_Scenario and C_Scenario.GetStepInfo and C_UIWidgetManager) then
        return nil
    end
    local ok, _, _, _, _, _, _, _, _, _, _, _, widgetSetID = pcall(C_Scenario.GetStepInfo)
    if not ok or type(widgetSetID) ~= "number" or widgetSetID == 0 then
        return nil
    end
    if not C_UIWidgetManager.GetAllWidgetsBySetID then
        return nil
    end
    local widgets = AQ:SafeCall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetID)
    if type(widgets) ~= "table" then
        return nil
    end
    local delveType = 29
    if Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
        delveType = Enum.UIWidgetVisualizationType.ScenarioHeaderDelves
    end
    local getter = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo
    if type(getter) ~= "function" then
        return nil
    end
    for i = 1, #widgets do
        local w = widgets[i]
        if type(w) == "table" and w.widgetType == delveType and w.widgetID then
            local info = AQ:SafeCall(getter, w.widgetID)
            if type(info) == "table" and IsShownState(info.shownState) then
                return info
            end
        end
    end
    return nil
end

local function ActiveDelveTier()
    if C_DelvesUI and C_DelvesUI.GetActiveDelveTier then
        local info = AQ:SafeCall(C_DelvesUI.GetActiveDelveTier)
        if type(info) == "table" and type(info.tier) == "number" then
            return info.tier
        end
        if type(info) == "number" then
            return info
        end
    end
    return nil
end

local function FindTimersOfType(wantType)
    if not GetWorldElapsedTimers or not GetWorldElapsedTime or wantType == nil then
        return nil
    end
    local ok, a, b, c, d, e, f, g = pcall(GetWorldElapsedTimers)
    if not ok then
        return nil
    end
    local ids = { a, b, c, d, e, f, g }
    for i = 1, #ids do
        local timerID = ids[i]
        if type(timerID) == "number" then
            local ok2, r1, r2, r3 = pcall(GetWorldElapsedTime, timerID)
            if ok2 then
                local elapsed, typ
                if type(r3) == "number" then
                    elapsed, typ = r2, r3
                else
                    elapsed, typ = r1, r2
                end
                if typ == wantType then
                    return timerID, tonumber(elapsed) or 0
                end
            end
        end
    end
    return nil
end

local function FindChallengeTimer()
    return FindTimersOfType(TimerTypeChallenge())
end

local function FindProvingTimer()
    return FindTimersOfType(TimerTypeProving())
end

local function SafeNum(v)
    if AQ.Compat and AQ.Compat.CanUseNumber and not AQ.Compat.CanUseNumber(v) then
        return nil
    end
    return tonumber(v)
end

local function CriteriaCounts(quantity, totalQuantity, quantityString)
    local have = SafeNum(quantity)
    local need = SafeNum(totalQuantity)
    if type(quantityString) == "string" and quantityString ~= "" then
        local a, b = string.match(quantityString, "(%d+)%s*/%s*(%d+)")
        if a and b then
            have, need = tonumber(a), tonumber(b)
        else
            local n = tonumber(string.match(quantityString, "%d+"))
            if n and not quantityString:find("%%", 1, true) then
                have = n
            end
        end
    end
    return have, need
end

local function FlagOn(v)
    return v == true or v == 1
end

local function ReadStepInfo()
    if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
        local info = AQ:SafeCall(C_ScenarioInfo.GetScenarioStepInfo)
        if type(info) == "table" then
            return {
                name = info.title or info.stepName or info.name,
                description = info.description,
                numCriteria = info.numCriteria or 0,
                weightedProgress = FlagOn(info.weightedProgress),
                widgetSetID = info.widgetSetID,
            }
        end
    end
    if not (C_Scenario and C_Scenario.GetStepInfo) then
        return nil
    end
    local name, desc, numCriteria, _, _, _, _, _, _, weightedProgress, _, widgetSetID = AQ:SafeCall(C_Scenario.GetStepInfo)
    return {
        name = name,
        description = desc,
        numCriteria = numCriteria or 0,
        weightedProgress = FlagOn(weightedProgress),
        widgetSetID = widgetSetID,
    }
end

local function ReadCriteria(i)
    local criteriaString, completed, quantity, totalQuantity
    local isWeightedProgress, isFormatted, quantityString, objType
    if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
        local info = AQ:SafeCall(C_ScenarioInfo.GetCriteriaInfo, i)
        if type(info) == "table" then
            criteriaString = info.description
            completed = info.completed
            quantity = info.quantity
            totalQuantity = info.totalQuantity
            isWeightedProgress = FlagOn(info.isWeightedProgress)
            isFormatted = FlagOn(info.isFormatted)
            quantityString = info.quantityString
            objType = info.criteriaType
        end
    elseif C_Scenario and C_Scenario.GetCriteriaInfo then
        local a, b, c, d, e, _, _, h, _, _, _, _, m = AQ:SafeCall(C_Scenario.GetCriteriaInfo, i)
        criteriaString, objType, completed, quantity, totalQuantity = a, b, c, d, e
        quantityString = h
        isWeightedProgress = FlagOn(m)
    end
    if not isWeightedProgress and type(quantityString) == "string" and quantityString:find("%%", 1, true) then
        isWeightedProgress = true
    end
    local have, need = CriteriaCounts(quantity, totalQuantity, quantityString)
    return {
        text = criteriaString,
        completed = completed and true or false,
        have = have,
        need = need,
        isWeightedProgress = isWeightedProgress,
        isFormatted = isFormatted,
        quantityString = quantityString,
        objType = objType,
    }
end

local function AddProgressRow(rows, spec)
    local extra = ""
    if spec.have and spec.need then
        extra = string.format(" %d/%d", spec.have, spec.need)
    end
    AddRow(rows, {
        kind = "progress",
        title = spec.title,
        finished = spec.completed and true or false,
        numFulfilled = spec.have,
        numNeeded = spec.need,
        isWeightedProgress = true,
        quantityString = spec.quantityString,
        objType = spec.objType,
        speech = (spec.title or "Progress") .. extra .. (spec.completed and " complete" or ""),
    })
end

local function AddCriteria(rows)
    local step = ReadStepInfo()
    if not step then
        return
    end
    local numCriteria = step.numCriteria or 0
    -- Kaliel: step-level weightedProgress is a bar for the stage, using criteria 1.
    if step.weightedProgress then
        local c = (numCriteria > 0) and ReadCriteria(1) or {}
        local inMplus = C_ChallengeMode and AQ:SafeCall(C_ChallengeMode.IsChallengeModeActive)
        local label = ShortProgressLabel(c.text, nil)
        if not label then
            label = ShortProgressLabel(step.description, inMplus and "Enemy Forces" or "Progress")
        end
        AddProgressRow(rows, {
            title = label,
            completed = c.completed,
            have = c.have,
            need = c.need,
            quantityString = c.quantityString,
            objType = c.objType,
        })
        for i = 2, numCriteria do
            local extra = ReadCriteria(i)
            if not extra.isWeightedProgress and type(extra.text) == "string" and extra.text ~= "" and not SkipExtraCriteria(extra.text) then
                local title = extra.text
                if not extra.isFormatted and extra.have and extra.need and not title:find("%d+%s*/%s*%d+") then
                    title = string.format("%d/%d %s", extra.have, extra.need, extra.text)
                end
                AddRow(rows, {
                    kind = "objective",
                    title = title,
                    finished = extra.completed,
                    numFulfilled = extra.have,
                    numNeeded = extra.need,
                    quantityString = extra.quantityString,
                    objType = extra.objType,
                    goldBullet = true,
                    speech = extra.text,
                })
            end
        end
        return
    end
    local progress
    for i = 1, numCriteria do
        local c = ReadCriteria(i)
        if c.isWeightedProgress then
            local label = c.text
            if type(label) ~= "string" or label == "" then
                local inMplus = C_ChallengeMode and AQ:SafeCall(C_ChallengeMode.IsChallengeModeActive)
                label = inMplus and "Enemy Forces" or "Progress"
            end
            progress = {
                title = label,
                completed = c.completed,
                have = c.have,
                need = c.need,
                quantityString = c.quantityString,
                objType = c.objType,
            }
        elseif type(c.text) == "string" and c.text ~= "" and not SkipExtraCriteria(c.text) then
            local title = c.text
            if not c.isFormatted and c.have and c.need then
                if not title:find("%d+%s*/%s*%d+") then
                    title = string.format("%d/%d %s", c.have, c.need, c.text)
                end
            elseif AQ.Theme.EnsureObjectiveCounts then
                title = AQ.Theme.EnsureObjectiveCounts(title, {
                    numFulfilled = c.have,
                    numNeeded = c.need,
                    quantityString = c.quantityString,
                })
            end
            local extra = ""
            if c.have and c.need then
                extra = string.format(" %d/%d", c.have, c.need)
            end
            AddRow(rows, {
                kind = "objective",
                title = title,
                finished = c.completed,
                numFulfilled = c.have,
                numNeeded = c.need,
                quantityString = c.quantityString,
                objType = c.objType,
                goldBullet = true,
                speech = c.text .. extra .. (c.completed and " complete" or ""),
            })
        end
    end
    if type(step.name) == "string" and step.name ~= "" and #rows == 0 and not progress then
        AddRow(rows, {
            kind = "objective",
            title = step.name,
            goldBullet = true,
            speech = step.name,
        })
    end
    if progress then
        AddProgressRow(rows, progress)
    end
end

local function AddInstanceHeader(rows, spec)
    AddRow(rows, {
        kind = "instance",
        id = spec.id or "scenario-name",
        title = spec.title,
        badge = spec.badge,
        lives = spec.lives,
        livesIcon = spec.livesIcon,
        instanceType = spec.instanceType,
        speech = spec.speech or spec.title,
        fontSize = 14,
    })
end

local function DelveLives(delve)
    if type(delve) ~= "table" or type(delve.currencies) ~= "table" then
        return nil
    end
    for i = 1, #delve.currencies do
        local cur = delve.currencies[i]
        if type(cur) == "table" then
            local blob = string.lower(tostring(cur.leadingText or "") .. " " .. tostring(cur.tooltip or ""))
            local amount = tonumber(string.match(tostring(cur.text or ""), "%d+"))
            local isLives = blob:find("life", 1, true) or blob:find("lives", 1, true)
            if not isLives and i == 1 and amount and (type(cur.leadingText) ~= "string" or cur.leadingText == "") then
                isLives = true
            end
            if amount and isLives then
                return amount, cur.iconFileID, i
            end
        end
    end
    return nil
end

local function GetRows()
    local rows = {}
    local inScenario = C_Scenario and AQ:SafeCall(C_Scenario.IsInScenario)
    local inMplus = C_ChallengeMode and AQ:SafeCall(C_ChallengeMode.IsChallengeModeActive)
    if not inScenario and not inMplus then
        return rows
    end

    local name, currentStage, numStages, scenarioType
    if C_Scenario and C_Scenario.GetInfo then
        local ok, n, stage, stages, _, _, _, _, _, _, stype = pcall(C_Scenario.GetInfo)
        if ok then
            name, currentStage, numStages, scenarioType = n, stage, stages, stype
        end
    end
    local inst = InstanceBits()
    local delve = GetDelveWidget()
    local isChallenge = inMplus or (scenarioType and scenarioType == ChallengeType())
    local headerTitle = type(name) == "string" and name or (inst and inst.name) or "Scenario"
    local headerKind = "Scenario"

    if isChallenge and C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local level, affixes, wasEnergized = AQ:SafeCall(C_ChallengeMode.GetActiveKeystoneInfo)
        level = tonumber(level) or 0
        headerKind = "Mythic+"
        AddInstanceHeader(rows, {
            title = headerTitle,
            badge = level > 0 and level or "M+",
            instanceType = "mythicplus",
            speech = level > 0 and string.format("Mythic plus %d %s", level, headerTitle) or ("Mythic plus " .. headerTitle),
        })
        if wasEnergized == false then
            AddRow(rows, {
                kind = "objective",
                title = "Keystone depleted at start",
                status = "FAILED",
                speech = "Keystone depleted at start",
            })
        end
        local mapID = C_ChallengeMode.GetActiveChallengeMapID and AQ:SafeCall(C_ChallengeMode.GetActiveChallengeMapID)
        local timeLimit
        if type(mapID) == "number" and C_ChallengeMode.GetMapUIInfo then
            local _, _, limit = AQ:SafeCall(C_ChallengeMode.GetMapUIInfo, mapID)
            timeLimit = tonumber(limit)
        end
        local timerID, elapsed = FindChallengeTimer()
        if timeLimit and timeLimit > 0 then
            AddRow(rows, {
                kind = "timer",
                title = "Time remaining",
                timerID = timerID,
                timeLimit = timeLimit,
                elapsed = elapsed or 0,
                countdown = true,
                speech = "Mythic plus timer",
            })
        end
        if C_ChallengeMode.GetDeathCount then
            local deaths, lost = AQ:SafeCall(C_ChallengeMode.GetDeathCount)
            deaths = tonumber(deaths) or 0
            lost = tonumber(lost) or 0
            if deaths > 0 then
                local extra = ""
                if lost > 0 then
                    extra = "  (-" .. Clock(lost) .. ")"
                end
                AddRow(rows, {
                    kind = "objective",
                    title = "Deaths  " .. tostring(deaths) .. extra,
                    speech = "Deaths " .. tostring(deaths),
                })
            end
        end
        local affixIcons = AddAffixRows(rows, affixes)
        if type(affixIcons) == "table" and #affixIcons > 0 then
            rows[1].icons = affixIcons
        end
        AddCriteria(rows)
        return rows
    end

    if delve then
        local tier = tonumber(delve.tierText and string.match(delve.tierText, "%d+"))
        if not tier then
            tier = ActiveDelveTier()
        end
        headerKind = "Delve"
        if type(delve.headerText) == "string" and delve.headerText ~= "" then
            headerTitle = delve.headerText
        end
        local lives, livesIcon, livesIndex = DelveLives(delve)
        AddInstanceHeader(rows, {
            title = headerTitle,
            badge = tier,
            lives = lives,
            livesIcon = livesIcon,
            instanceType = "delve",
            speech = (tier and ("Tier " .. tostring(tier) .. " ") or "") .. headerTitle,
        })
        local nemesisAt
        local nemesisSp
        local nemesisTip
        if type(delve.currencies) == "table" then
            for i = 1, #delve.currencies do
                local cur = delve.currencies[i]
                if type(cur) == "table" and i ~= livesIndex then
                    local blob = SafeLower(cur.leadingText) .. " " .. SafeLower(cur.tooltip)
                    if blob:find("life", 1, true) or blob:find("lives", 1, true) then
                        -- lives sit on the instance header
                    else
                        local label = cur.leadingText or "Currency"
                        local amount = cur.text or ""
                        local title = AQ:Trim((label .. "  " .. amount))
                        AddRow(rows, {
                            kind = "quest",
                            title = title,
                            icon = cur.iconFileID,
                            detail = cur.tooltip,
                            speech = title,
                        })
                        if LooksLikeNemesis(title, cur.tooltip, cur.leadingText) then
                            nemesisAt = #rows
                            nemesisTip = cur.tooltip
                        end
                    end
                end
            end
        end
        if type(delve.rewardInfo) == "table" and IsShownState(delve.rewardInfo.shownState) then
            local earned = delve.rewardInfo.shownState == 1
                or (Enum and Enum.UIWidgetRewardShownState and delve.rewardInfo.shownState == Enum.UIWidgetRewardShownState.ShownEarned)
            AddRow(rows, {
                kind = "quest",
                title = earned and "Bountiful reward earned" or "Bountiful reward",
                status = earned and "DONE" or "ACTIVE",
                detail = earned and delve.rewardInfo.earnedTooltip or delve.rewardInfo.unearnedTooltip,
                speech = "Bountiful reward",
            })
        end
        if type(delve.spells) == "table" then
            for i = 1, #delve.spells do
                local sp = delve.spells[i]
                local spellID = type(sp) == "table" and tonumber(sp.spellID) or nil
                local hasText = type(sp) == "table" and type(sp.text) == "string" and sp.text ~= ""
                if type(sp) == "table" and IsShownState(sp.shownState) and (spellID or hasText) then
                    if spellID then
                        sp.spellID = spellID
                    end
                    local kind, sname, tip = ClassifyDelveSpell(sp)
                    local prefix = ""
                    local lower = SafeLower(sname)
                    if kind == "nemesis" and not lower:find("nemesis", 1, true) then
                        prefix = "Nemesis  "
                    elseif kind == "bountiful" and not lower:find("bountiful", 1, true) then
                        prefix = "Bountiful  "
                    end
                    AddRow(rows, {
                        kind = "quest",
                        title = prefix .. sname,
                        icon = SpellIcon(spellID or sp.spellID),
                        detail = (type(tip) == "string" and tip ~= "" and tip) or SpellDesc(spellID or sp.spellID),
                        speech = prefix .. sname,
                    })
                    if kind == "nemesis" or LooksLikeNemesis(prefix .. sname, tip) then
                        nemesisAt = #rows
                        nemesisSp = sp
                        nemesisTip = tip
                    end
                end
            end
        end
        if not nemesisAt then
            for i = 1, #rows do
                local row = rows[i]
                if type(row) == "table" and LooksLikeNemesis(row.title, row.detail, row.speech) then
                    nemesisAt = i
                end
            end
        end
        if not nemesisAt and LooksLikeNemesis(headerTitle, delve.headerText, delve.tooltip) then
            nemesisAt = #rows
        end
        if not nemesisAt and (tonumber(tier) or 0) >= 4 then
            nemesisAt = #rows
        end
        if nemesisAt then
            AttachNemesisExtras(rows, delve, nemesisSp, nemesisTip, tier, nemesisAt)
        end
        AddCriteria(rows)
        return rows
    end

    local diffLabel = inst and inst.difficultyName
    local instanceType = "scenario"
    if inst and inst.instanceType == "raid" then
        headerKind = "Raid"
        instanceType = "raid"
    elseif inst and inst.instanceType == "party" then
        headerKind = "Dungeon"
        instanceType = "dungeon"
    end
    AddInstanceHeader(rows, {
        title = headerTitle,
        badge = (type(diffLabel) == "string" and diffLabel ~= "" and diffLabel) or nil,
        instanceType = instanceType,
        speech = headerKind .. " " .. headerTitle,
    })
    if currentStage and numStages and tonumber(numStages) and tonumber(numStages) > 1 then
        AddRow(rows, {
            kind = "objective",
            title = string.format("Stage %s of %s", tostring(currentStage), tostring(numStages)),
            numFulfilled = tonumber(currentStage),
            numNeeded = tonumber(numStages),
            goldBullet = true,
            speech = string.format("Stage %s of %s", tostring(currentStage), tostring(numStages)),
        })
    end

    local pgTimer, pgElapsed = FindProvingTimer()
    if pgTimer and C_Scenario and C_Scenario.GetProvingGroundsInfo then
        local diffID, currWave, maxWave, duration = AQ:SafeCall(C_Scenario.GetProvingGroundsInfo)
        duration = tonumber(duration)
        if duration and duration > 0 then
            AddRow(rows, {
                kind = "timer",
                title = string.format("Wave %s / %s", tostring(currWave or "?"), tostring(maxWave or "?")),
                timerID = pgTimer,
                timeLimit = duration,
                elapsed = pgElapsed or 0,
                countdown = true,
                speech = "Proving grounds timer",
            })
        end
    end

    AddCriteria(rows)
    return rows
end

AQ.Tracker.RegisterSection({
    id = "scenarios",
    title = "Instance",
    order = 10,
    flavor = "retail",
    GetRows = GetRows,
})

local function RefreshIfInside()
    if not AQ.Tracker then
        return
    end
    local inScenario = C_Scenario and AQ:SafeCall(C_Scenario.IsInScenario)
    local inMplus = C_ChallengeMode and AQ:SafeCall(C_ChallengeMode.IsChallengeModeActive)
    if inScenario or inMplus then
        AQ.Tracker.Refresh()
    end
end

AQ.Events.Register("SCENARIO_UPDATE", RefreshIfInside)
AQ.Events.Register("SCENARIO_CRITERIA_UPDATE", RefreshIfInside)
AQ.Events.Register("SCENARIO_SPELL_UPDATE", RefreshIfInside)
AQ.Events.Register("CHALLENGE_MODE_START", function()
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end)
AQ.Events.Register("CHALLENGE_MODE_COMPLETED", function()
    if AQ.Tracker then
        AQ.Tracker.Refresh()
    end
end)
AQ.Events.Register("CHALLENGE_MODE_DEATH_COUNT_UPDATED", RefreshIfInside)
AQ.Events.Register("WORLD_STATE_TIMER_START", RefreshIfInside)
AQ.Events.Register("WORLD_STATE_TIMER_STOP", RefreshIfInside)
AQ.Events.Register("ACTIVE_DELVE_DATA_UPDATE", RefreshIfInside)
AQ.Events.Register("CURRENCY_DISPLAY_UPDATE", RefreshIfInside)
AQ.Events.Register("UPDATE_UI_WIDGET", RefreshIfInside)
AQ.Events.Register("VIGNETTE_MINIMAP_UPDATED", RefreshIfInside)
AQ.Events.Register("VIGNETTES_UPDATED", RefreshIfInside)
AQ.Events.Register("UNIT_AURA", function(_, unit)
    if unit == "player" then
        RefreshIfInside()
    end
end)
AQ.Events.Register("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
    if unit == "player" and BANNER_INTERACT_SPELLS[tonumber(spellID) or 0] then
        EnsureNemesisRun()
        nemesisRun.bannerState = "clicked"
        RefreshIfInside()
    end
end)
local function NoteBonusThenRefresh(msg)
    NoteBonusMessage(msg)
    RefreshIfInside()
end
AQ.Events.Register("CHAT_MSG_RAID_BOSS_EMOTE", function(_, msg)
    NoteBonusThenRefresh(msg)
end)
AQ.Events.Register("CHAT_MSG_RAID_BOSS_WHISPER", function(_, msg)
    NoteBonusThenRefresh(msg)
end)
AQ.Events.Register("UI_INFO_MESSAGE", function(_, _, msg)
    NoteBonusThenRefresh(msg)
end)
AQ.Events.Register("CHAT_MSG_SYSTEM", function(_, msg)
    NoteBonusThenRefresh(msg)
end)
