--[[
  Accessibility Helper — announce mount / loot / open / collect cursors
  Default on. Independent of UI text hover vs keybind.
  Lua 5.1 only.

  The engine sets WorldFrame cursors in C++; Lua SetCursor does not fire there
  and there is no GetCursorMode. Detect from mouseover / softinteract, world
  tooltip APIs, and GameTooltip lines.
]]

AccessibilityHelper = AccessibilityHelper or {}
local AH = AccessibilityHelper

AH.Cursor = AH.Cursor or {}
local Cursor = AH.Cursor

local lastPhrase = nil
local lastRaw = nil
local enumPhrase = nil
local pointing = false

local function Now()
    return (GetTime and GetTime()) or 0
end

local function Enabled()
    if AH.DB and AH.DB.IsMasterEnabled and not AH.DB.IsMasterEnabled() then
        return false
    end
    if not (AH.DB and AH.DB.Get) then
        return true
    end
    return AH.DB.Get().cursorAnnounceEnabled ~= false
end

local function CanUseValue(v)
    if AH.Compat and AH.Compat.CanUseValue then
        return AH.Compat.CanUseValue(v)
    end
    if AH.Compat and AH.Compat.IsSecretValue then
        return not AH.Compat.IsSecretValue(v)
    end
    return true
end

local function UsableString(v)
    if type(v) ~= "string" or not CanUseValue(v) then
        return ""
    end
    return v
end

local function SafeUnitExists(unit)
    return unit and UnitExists and UnitExists(unit)
end

local function MouseUnit()
    if SafeUnitExists("mouseover") then
        return "mouseover"
    end
    if SafeUnitExists("softinteract") then
        return "softinteract"
    end
    return nil
end

local function PhraseFromToken(raw)
    if raw == nil then
        return nil
    end
    local s
    if type(raw) == "number" then
        if not CanUseValue(raw) then
            return nil
        end
        if enumPhrase and enumPhrase[raw] then
            return enumPhrase[raw]
        end
        s = tostring(raw)
    elseif type(raw) == "string" then
        s = UsableString(raw)
        if s == "" then
            return nil
        end
    else
        return nil
    end
    s = s:lower()
    s = s:gsub("\\", "/")
    s = s:gsub("interface/cursors/", "")
    s = s:gsub("interface/cursor/", "")
    s = s:gsub("%.blp", "")
    s = s:gsub("%.png", "")
    s = s:gsub("_", "")
    s = s:gsub("%-", "")
    s = s:gsub("cursor", "")
    s = s:gsub("%s+", "")

    local unable = s:find("unable", 1, true) or s:find("error", 1, true)
    local function wrap(okPhrase)
        if unable then
            return "Cannot " .. okPhrase:lower()
        end
        return okPhrase
    end

    if s:find("vehicle", 1, true) or s:find("mount", 1, true) or s:find("ride", 1, true) or s:find("taxi", 1, true) then
        return wrap("Mount")
    end
    if s:find("loot", 1, true) then
        return wrap("Loot")
    end
    if s:find("mine", 1, true) or s:find("gather", 1, true) or s:find("herb", 1, true) or s:find("skin", 1, true) then
        return wrap("Collect")
    end
    if s:find("repair", 1, true) then
        return wrap("Repair")
    end
    if s:find("trainer", 1, true) then
        return wrap("Trainer")
    end
    if s:find("buy", 1, true) then
        return wrap("Vendor")
    end
    if s:find("innkeeper", 1, true) then
        return wrap("Innkeeper")
    end
    if s:find("stable", 1, true) then
        return wrap("Stable")
    end
    if s:find("speak", 1, true) then
        return wrap("Speak")
    end
    if s:find("interact", 1, true) or s:find("holdinghand", 1, true) or s:find("grabbinghand", 1, true) or s:find("openhand", 1, true) then
        return wrap("Use")
    end
    if s:find("questturnin", 1, true) then
        return wrap("Turn in")
    end
    if s:find("quest", 1, true) then
        return wrap("Quest")
    end
    if s:find("open", 1, true) or s:find("lock", 1, true) or s:find("mail", 1, true) then
        return wrap("Open")
    end
    return nil
end

local function BuildEnumMap()
    enumPhrase = {}
    local enums = {}
    if Enum then
        enums[#enums + 1] = Enum.Cursormode
        enums[#enums + 1] = Enum.CursorMode
    end
    for e = 1, #enums do
        local group = enums[e]
        if type(group) == "table" then
            for name, id in pairs(group) do
                if type(name) == "string" and type(id) == "number" then
                    local phrase = PhraseFromToken(name)
                    if phrase then
                        enumPhrase[id] = phrase
                    end
                end
            end
        end
    end
end

local function PollCursorMode()
    local namespaces = { C_Cursor, C_Mouse }
    local names = {
        "GetCursorMode",
        "GetCursormode",
        "GetCursorByMode",
        "GetWorldCursorMode",
    }
    for i = 1, #namespaces do
        local ns = namespaces[i]
        if type(ns) == "table" then
            for n = 1, #names do
                local fn = ns[names[n]]
                if type(fn) == "function" then
                    local ok, v = pcall(fn)
                    if ok and v ~= nil then
                        return v
                    end
                end
            end
        end
    end
    if type(GetCursorMode) == "function" then
        local ok, v = pcall(GetCursorMode)
        if ok and v ~= nil then
            return v
        end
    end
    return nil
end

local function PickupType()
    if type(GetCursorInfo) ~= "function" then
        return nil
    end
    local ok, infoType = pcall(GetCursorInfo)
    infoType = ok and UsableString(infoType) or ""
    if infoType ~= "" then
        return infoType:lower()
    end
    return nil
end

local function UICursorIsMount(cursorType)
    if cursorType == nil or not CanUseValue(cursorType) then
        return false
    end
    if Enum and Enum.UICursorType and Enum.UICursorType.Mount ~= nil then
        return cursorType == Enum.UICursorType.Mount
    end
    return cursorType == 17
end

local function LooksLikeMountText(blob)
    blob = UsableString(blob)
    if blob == "" then
        return false
    end
    if blob:find("to ride", 1, true) or blob:find("to mount", 1, true) or blob:find("click to mount", 1, true) or blob:find("click to ride", 1, true) then
        return true
    end
    if blob:find("can ride", 1, true) or blob:find("hop on", 1, true) or blob:find("passenger seat", 1, true) then
        return true
    end
    if blob:find("vehicle", 1, true) or blob:find("taxi", 1, true) or blob:find("flight path", 1, true) then
        return true
    end
    if blob:find("gryphon", 1, true) or blob:find("wyvern", 1, true) or blob:find("hippogryph", 1, true) then
        return true
    end
    if blob:find("%f[%a]bat%f[%A]") then
        return true
    end
    if blob:find("wind rider", 1, true) or blob:find("windrider", 1, true) or blob:find("dragonhawk", 1, true) then
        return true
    end
    if blob:find("nether ray", 1, true) or blob:find("flying machine", 1, true) or blob:find("gyrocopter", 1, true) then
        return true
    end
    if blob:find("demolisher", 1, true) or blob:find("siege engine", 1, true) or blob:find("siege tower", 1, true) then
        return true
    end
    if blob:find("%f[%a]kodo%f[%A]") or blob:find("%f[%a]ram%f[%A]") then
        return true
    end
    return false
end

local function IsMountableUnit(unit)
    if not unit then
        return false
    end
    -- Passengers sitting on a vendor mount are IN a vehicle; they are not a mount cursor.
    if UnitHasVehicleUI then
        local ok, veh = pcall(UnitHasVehicleUI, unit)
        if ok and veh then
            return true
        end
    end
    if UnitVehicleSeatCount then
        local ok, n = pcall(UnitVehicleSeatCount, unit)
        if ok and type(n) == "number" and n > 0 then
            return true
        end
    end
    local guid = UnitGUID and UnitGUID(unit)
    guid = UsableString(guid)
    if guid ~= "" and guid:sub(1, 8) == "Vehicle-" then
        return true
    end
    if UnitIsPlayer and UnitIsPlayer(unit) then
        return false
    end
    if UnitCanAttack and UnitCanAttack("player", unit) then
        return false
    end
    local name = UnitName and UnitName(unit)
    if LooksLikeMountText(UsableString(name):lower()) then
        return true
    end
    return false
end

local function EnumType(name, fallback)
    if Enum and Enum.TooltipDataType and type(Enum.TooltipDataType[name]) == "number" then
        return Enum.TooltipDataType[name]
    end
    return fallback
end

local function GetWorldCursorData()
    if not (C_TooltipInfo and C_TooltipInfo.GetWorldCursor) then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetWorldCursor)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local function AppendLine(parts, text)
    text = UsableString(text)
    if text ~= "" then
        parts[#parts + 1] = text
    end
end

local function TooltipLinesFromData(data)
    local parts = {}
    if type(data) ~= "table" or type(data.lines) ~= "table" then
        return parts
    end
    for i = 1, #data.lines do
        local line = data.lines[i]
        if type(line) == "table" then
            AppendLine(parts, line.leftText)
            AppendLine(parts, line.rightText)
        end
    end
    return parts
end

local function TooltipLinesFromFrame(tip)
    local parts = {}
    if not tip then
        return parts
    end
    local n = 0
    if tip.NumLines then
        local ok, count = pcall(function()
            return tip:NumLines()
        end)
        if ok and type(count) == "number" then
            n = count
        end
    end
    if n < 1 then
        n = 12
    end
    local name = tip.GetName and tip:GetName()
    for i = 1, n do
        local fs = tip["TextLeft" .. i]
        if not fs and type(name) == "string" then
            fs = _G[name .. "TextLeft" .. i]
        end
        if fs and fs.GetText then
            local ok, t = pcall(function()
                return fs:GetText()
            end)
            if ok then
                AppendLine(parts, t)
            end
        end
        local rs = tip["TextRight" .. i]
        if not rs and type(name) == "string" then
            rs = _G[name .. "TextRight" .. i]
        end
        if rs and rs.GetText then
            local ok, t = pcall(function()
                return rs:GetText()
            end)
            if ok then
                AppendLine(parts, t)
            end
        end
    end
    return parts
end

local function JoinLower(parts)
    if not parts or #parts == 0 then
        return ""
    end
    local usable = {}
    for i = 1, #parts do
        local s = UsableString(parts[i])
        if s ~= "" then
            usable[#usable + 1] = s
        end
    end
    if #usable == 0 then
        return ""
    end
    local ok, blob = pcall(function()
        return table.concat(usable, " "):lower()
    end)
    if ok and type(blob) == "string" then
        return blob
    end
    return ""
end

local function BlobHasGlobal(blob, key)
    blob = UsableString(blob)
    local s = UsableString(_G[key])
    if blob == "" or s == "" then
        return false
    end
    return blob:find(s:lower(), 1, true) and true or false
end

local function GetUnitTooltipData(unit)
    if not unit or not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return nil
    end
    local ok, data = pcall(C_TooltipInfo.GetUnit, unit)
    if ok and type(data) == "table" then
        return data
    end
    return nil
end

local function StripText(s)
    s = UsableString(s)
    if s == "" then
        return ""
    end
    if AH.ChatText and AH.ChatText.ForSpeech then
        s = AH.ChatText.ForSpeech(s)
    else
        s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
        s = s:gsub("|r", "")
        s = s:gsub("|T.-|t", " ")
        s = s:gsub("|A.-|a", " ")
        s = s:gsub("|H.-|h(.-)|h", "%1")
        s = s:gsub("|n", " ")
        s = s:gsub("%s+", " ")
    end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function TitleFromLine(s)
    s = UsableString(s)
    if s == "" then
        return nil
    end
    local inner = s:match("^<(.-)>$")
    if not inner then
        inner = s:match("<(.-)>")
    end
    if type(inner) ~= "string" then
        return nil
    end
    inner = StripText(inner)
    if inner == "" then
        return nil
    end
    return inner
end

local function CollectLines(unit, data)
    local parts = TooltipLinesFromData(data)
    if unit then
        local extra = TooltipLinesFromData(GetUnitTooltipData(unit))
        for i = 1, #extra do
            parts[#parts + 1] = extra[i]
        end
    end
    if (unit or data) and GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
        local extra = TooltipLinesFromFrame(GameTooltip)
        for i = 1, #extra do
            parts[#parts + 1] = extra[i]
        end
    end
    local lines = {}
    local seen = {}
    for i = 1, #parts do
        local t = StripText(parts[i])
        if t ~= "" and CanUseValue(t) then
            local key = t:lower()
            if not seen[key] then
                seen[key] = true
                lines[#lines + 1] = t
            end
        end
    end
    return lines
end

local function Identity(unit, data)
    local unitName
    if unit and UnitName then
        local n = UsableString(UnitName(unit))
        if n ~= "" then
            unitName = StripText(n)
        end
    end
    local title
    local tipName
    local lines = CollectLines(unit, data)
    for i = 1, #lines do
        local t = lines[i]
        local asTitle = TitleFromLine(t)
        if asTitle then
            if not title then
                title = asTitle
            end
        else
            local lower = t:lower()
            if not tipName and not lower:find("^level ") and not lower:find("^requires ") then
                tipName = t
            end
        end
    end
    local name = unitName
    -- Vendor NPCs sit on the mammoth/yak: mouseover is often the vehicle.
    if tipName and unitName and tipName:lower() ~= unitName:lower() and IsMountableUnit(unit) then
        name = tipName
    elseif not name then
        name = tipName
    end
    if name == "" then
        name = nil
    end
    if title == "" then
        title = nil
    end
    return name, title
end

local function BuildSpeak(name, title, action)
    name = UsableString(name)
    title = UsableString(title)
    action = UsableString(action)
    local parts = {}
    if name ~= "" then
        parts[#parts + 1] = name
    end
    if title ~= "" then
        if name == "" or title:lower() ~= name:lower() then
            parts[#parts + 1] = title
        end
    end
    if action ~= "" then
        local skip = false
        if title ~= "" and title:lower() == action:lower() then
            skip = true
        end
        if not skip then
            parts[#parts + 1] = action
        end
    end
    if #parts == 0 then
        return nil
    end
    return table.concat(parts, " ")
end

local function WorldBlob(unit, data)
    return JoinLower(CollectLines(unit, data))
end

-- Infer interaction from tooltip / NPC title. Most specific first.
-- Does not announce Speak on every friendly NPC.
local function ClassifyBlob(blob)
    blob = UsableString(blob)
    if blob == "" then
        return nil
    end

    if blob:find("herbalism", 1, true) or blob:find("mining", 1, true) or blob:find("skinning", 1, true) or blob:find("skinnable", 1, true) then
        return "Collect"
    end
    if BlobHasGlobal(blob, "UNIT_SKINNABLE_HERB") or BlobHasGlobal(blob, "UNIT_SKINNABLE_ROCK") or BlobHasGlobal(blob, "UNIT_SKINNABLE_LEATHER") or BlobHasGlobal(blob, "UNIT_SKINNABLE_BOLTS") then
        return "Collect"
    end
    if blob:find("vein", 1, true) or blob:find("deposit", 1, true) or blob:find(" lode", 1, true) then
        return "Collect"
    end
    if blob:find("to loot", 1, true) or blob:find("lootable", 1, true) then
        return "Loot"
    end

    local repair = blob:find("repair", 1, true)
        or blob:find("tinker", 1, true)
        or blob:find("traveling trader", 1, true)
    local vendor = blob:find("vendor", 1, true)
        or blob:find("merchant", 1, true)
        or blob:find("supplies", 1, true)
        or blob:find("reagents", 1, true)
        or blob:find("trade goods", 1, true)
        or blob:find("food & drink", 1, true)
        or blob:find("food and drink", 1, true)
        or blob:find("shopkeeper", 1, true)
        or blob:find("quartermaster", 1, true)
        or blob:find("provisioner", 1, true)
        or blob:find("tinker", 1, true)
        or blob:find("%f[%a]trader%f[%A]")
    if blob:find("gnimo", 1, true) or blob:find("hakmud of argus", 1, true) then
        repair = true
        vendor = true
    end
    if blob:find("drix blackwrench", 1, true) or blob:find("cousin slowhands", 1, true) then
        repair = true
    end
    if blob:find("mojodishu", 1, true) or blob:find("cousin gootfur", 1, true) then
        vendor = true
    end
    if repair and vendor then
        return "Repair Vendor"
    end
    if repair then
        return "Repair"
    end
    if vendor then
        return "Vendor"
    end
    if blob:find("trainer", 1, true) then
        return "Trainer"
    end
    if blob:find("flight master", 1, true) or blob:find("gryphon master", 1, true) or blob:find("hippogryph master", 1, true) or blob:find("wyvern master", 1, true) then
        return "Flight master"
    end
    if blob:find("wind rider master", 1, true) or blob:find("bat handler", 1, true) or blob:find("dragonhawk master", 1, true) then
        return "Flight master"
    end
    if blob:find("innkeeper", 1, true) then
        return "Innkeeper"
    end
    if blob:find("stable master", 1, true) or blob:find("stablemaster", 1, true) then
        return "Stable"
    end
    if blob:find("banker", 1, true) or blob:find("auctioneer", 1, true) then
        return "Banker"
    end
    if blob:find("battlemaster", 1, true) or blob:find("battle master", 1, true) then
        return "Battlemaster"
    end

    if LooksLikeMountText(blob) then
        return "Mount"
    end

    if blob:find("mailbox", 1, true) or blob:find("locked", 1, true) or blob:find("to open", 1, true) or blob:find("right click to open", 1, true) or blob:find("right-click to open", 1, true) then
        return "Open"
    end
    if blob:find("chest", 1, true) or blob:find("coffer", 1, true) or blob:find("lockbox", 1, true) or blob:find("strongbox", 1, true) or blob:find("footlocker", 1, true) then
        return "Open"
    end
    if blob:find("cache", 1, true) or blob:find("crate", 1, true) or blob:find("trunk", 1, true) then
        return "Open"
    end
    if blob:find("to use", 1, true) or blob:find("click to use", 1, true) or blob:find("to activate", 1, true) then
        return "Use"
    end
    return nil
end

local function UnitIsLootableDead(unit)
    if UnitIsGhost and UnitIsGhost(unit) then
        return false
    end
    if UnitIsDead and UnitIsDead(unit) then
        return true
    end
    if UnitIsCorpse and UnitIsCorpse(unit) then
        return true
    end
    return false
end

local function PhraseFromUnit(unit)
    local data = GetWorldCursorData()
    local blob = WorldBlob(unit, data)
    local action
    if UnitIsLootableDead(unit) then
        local skinnable = blob:find("skinnable", 1, true) or blob:find("skinning", 1, true)
        if CanLootUnit then
            local ok, can = pcall(CanLootUnit, unit)
            if ok and can then
                action = "Loot"
            elseif ok and can == false then
                if skinnable then
                    action = "Collect"
                end
            else
                action = skinnable and "Collect" or "Loot"
            end
        else
            action = skinnable and "Collect" or "Loot"
        end
    else
        action = ClassifyBlob(blob)
        if not action and IsMountableUnit(unit) then
            local _, title = Identity(unit, data)
            if not title then
                action = "Mount"
            end
        end
    end
    if not action then
        return nil
    end
    local name, title = Identity(unit, data)
    return BuildSpeak(name, title, action)
end

local function HasWorldLoot(unit)
    if not unit or not (C_TooltipInfo and C_TooltipInfo.GetWorldLootObject) then
        return false
    end
    local ok, data = pcall(C_TooltipInfo.GetWorldLootObject, unit)
    return ok and type(data) == "table"
end

local function OpenMerchantAction()
    if not (MerchantFrame and MerchantFrame.IsShown and MerchantFrame:IsShown()) then
        return nil, nil
    end
    local npc
    if UnitName then
        local ok, n = pcall(UnitName, "npc")
        if ok and type(n) == "string" and n ~= "" then
            npc = StripText(n)
        end
    end
    if not npc then
        return nil, nil
    end
    local repair = false
    if CanMerchantRepair then
        local ok, can = pcall(CanMerchantRepair)
        repair = ok and can and true or false
    end
    return npc, repair and "Repair Vendor" or "Vendor"
end

local function PhraseFromWorld()
    if SpellIsTargeting and SpellIsTargeting() then
        return nil
    end

    local unit = MouseUnit()
    local data = GetWorldCursorData()
    local name, title = Identity(unit, data)
    local merchantName, merchantAction = OpenMerchantAction()
    if merchantName and name and merchantName:lower() == name:lower() then
        return BuildSpeak(name, title, merchantAction)
    end
    if unit and HasWorldLoot(unit) then
        return BuildSpeak(name, title, "Loot")
    end
    if unit then
        local fromUnit = PhraseFromUnit(unit)
        if fromUnit then
            return fromUnit
        end
    end

    local blob = WorldBlob(unit, data)
    local action = ClassifyBlob(blob)
    if not action and merchantAction and merchantName then
        if (name and name:lower() == merchantName:lower()) or (blob:find(merchantName:lower(), 1, true)) then
            action = merchantAction
        end
    end
    if not action and data and data.type ~= nil then
        local corpse = EnumType("Corpse", 3)
        if data.type == corpse then
            action = "Loot"
        end
    end
    if not action then
        return nil
    end
    return BuildSpeak(name, title, action)
end

local lastKey = nil
local pendingKey = nil
local pendingUntil = 0
local leaveUntil = 0

local function ClearState()
    lastPhrase = nil
    lastKey = nil
    pendingKey = nil
    pendingUntil = 0
    leaveUntil = 0
    pointing = false
end

local function HoverKey()
    local unit = MouseUnit()
    local data = GetWorldCursorData()
    local name = Identity(unit, data)
    name = UsableString(name)
    if name ~= "" then
        return "n:" .. name:lower()
    end
    if unit then
        if UnitGUID then
            local guid = UsableString(UnitGUID(unit))
            if guid ~= "" then
                return "u:" .. guid
            end
        end
        return "unit"
    end
    if data then
        if data.type ~= nil then
            return "wtype:" .. tostring(data.type)
        end
        return "world"
    end
    return nil
end

local function Speak(phrase)
    if type(phrase) ~= "string" or phrase == "" then
        return
    end
    if not Enabled() then
        return
    end
    if AH.Speech and AH.Speech.Say then
        AH.Speech.Say(phrase .. ".", AH.Speech.PRIORITY_NAV)
    end
end

local function Announce(key, phrase)
    if type(phrase) ~= "string" or phrase == "" or type(key) ~= "string" then
        return
    end
    if key == lastKey and phrase == lastPhrase then
        return
    end
    -- Same target, tooltip filled in more words: keep quiet.
    if key == lastKey then
        lastPhrase = phrase
        return
    end
    lastKey = key
    lastPhrase = phrase
    pendingKey = nil
    pendingUntil = 0
    leaveUntil = 0
    pointing = true
    Speak(phrase)
end

local function BeginLeave()
    if pointing then
        if leaveUntil == 0 then
            leaveUntil = Now() + 0.16
        elseif Now() >= leaveUntil then
            ClearState()
        end
    else
        pendingKey = nil
        pendingUntil = 0
    end
end

local function Scan()
    if not Enabled() then
        ClearState()
        lastRaw = nil
        return
    end

    local held = PickupType()
    if held == "mount" then
        leaveUntil = 0
        Announce("held:mount", "Mount")
        return
    end
    if held then
        if lastKey and lastKey:sub(1, 5) == "held:" then
            ClearState()
        end
        return
    end

    local key = HoverKey()
    if not key then
        BeginLeave()
        return
    end
    leaveUntil = 0

    -- Still on the same announced target: do not rebuild tooltips every tick.
    if key == lastKey then
        pendingKey = nil
        return
    end

    local phrase = PhraseFromWorld()
    if not phrase then
        local tokenPhrase = PhraseFromToken(PollCursorMode()) or PhraseFromToken(lastRaw)
        if tokenPhrase then
            phrase = tokenPhrase
        end
    end

    if key ~= pendingKey then
        pendingKey = key
        pendingUntil = Now() + 0.18
        return
    end
    if Now() < pendingUntil then
        return
    end

    if not phrase then
        -- Waited: this hover has no interact cursor we announce.
        pendingKey = nil
        if pointing then
            ClearState()
        end
        return
    end
    Announce(key, phrase)
end

BuildEnumMap()

if type(hooksecurefunc) == "function" and type(SetCursor) == "function" then
    hooksecurefunc("SetCursor", function(cursor)
        lastRaw = cursor
        Scan()
    end)
end

if type(hooksecurefunc) == "function" and type(SetCursorByMode) == "function" then
    hooksecurefunc("SetCursorByMode", function(mode)
        lastRaw = mode
        Scan()
    end)
end

if type(hooksecurefunc) == "function" and type(ResetCursor) == "function" then
    hooksecurefunc("ResetCursor", function()
        lastRaw = nil
    end)
end

local events = CreateFrame("Frame")
local EVENT_NAMES = {
    "PLAYER_LOGIN",
    "CURSOR_UPDATE",
    "CURSOR_CHANGED",
    "UPDATE_MOUSEOVER_UNIT",
    "PLAYER_SOFT_INTERACT_CHANGED",
    "MOUNT_CURSOR_CLEAR",
}
for i = 1, #EVENT_NAMES do
    pcall(function()
        events:RegisterEvent(EVENT_NAMES[i])
    end)
end
events:SetScript("OnEvent", function(_, event, isDefault, newCursorType)
    if event == "PLAYER_LOGIN" then
        BuildEnumMap()
        return
    end
    if event == "CURSOR_CHANGED" then
        if UICursorIsMount(newCursorType) then
            lastRaw = "MOUNT_CURSOR"
        elseif isDefault then
            lastRaw = nil
        end
        Scan()
        return
    end
    if event == "MOUNT_CURSOR_CLEAR" then
        lastRaw = nil
        if lastKey == "held:mount" then
            ClearState()
        end
        return
    end
    Scan()
end)

local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(self, elapsed)
    -- Keep polling while a hover is settling, spoken, or leaving so the next
    -- NPC/object can speak. Idle otherwise.
    if not pointing and pendingKey == nil and leaveUntil == 0 then
        self._ahAccum = 0
        return
    end
    self._ahAccum = (self._ahAccum or 0) + (elapsed or 0)
    if self._ahAccum < 0.1 then
        return
    end
    self._ahAccum = 0
    Scan()
end)
