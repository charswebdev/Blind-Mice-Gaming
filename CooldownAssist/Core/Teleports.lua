--[[
  Cooldown Assist — known teleport spell / item IDs + access checks
  Teleport tab only lists spells/items the player knows, owns, and can use
  on their current class.
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Teleports = CA.Teleports or {}
local Teleports = CA.Teleports

-- Class / racial / mage / housing teleports (only added if player knows them).
Teleports.SPELL_IDS = {
    556, 18960, 3561, 3562, 3563, 3565, 3566, 3567,
    32271, 32272, 33690, 49358, 49359, 50977, 53140,
    88342, 88344, 120145, 126892, 132621, 132627,
    176242, 176244, 193753, 193759, 204587, 224869,
    255661, 265225, 281403, 281404, 312372, 344587,
    368229, 395277, 446540, 1233637,
    1299517, -- Lightveil Recall Beacon
}

-- Teleport toys / engineering / rings / scrolls (only added if owned + usable).
Teleports.ITEM_IDS = {
    -- Hearth / classic transporters
    6948, 18984, 18986, 21711, 28585, 30542, 30544, 32757,
    35230, 37118, 37863, 44314, 44315, 46874, 48933, 50287,
    52251, 54452, 58487, 63206, 63207, 63352, 63353, 63378,
    63379, 64457, 64488, 65274, 65360, 68808, 68809, 87215,
    87548, 93672, 95050, 95051, 95567, 95568, 103678, 110560,
    112059,
    -- Kirin Tor rings / cloaks
    40585, 40586, 44934, 44935, 45688, 45689, 45690, 45691,
    48954, 48955, 48956, 48957, 51557, 51558, 51559, 51560,
    139599,
    -- Legion / BfA / later toys & gear
    118662, 118663, 118907, 118908, 128353, 128502, 128503,
    129276, 132524, 136849, 139590, 140192, 140324, 140493,
    141013, 141014, 141015, 141016, 141017, 142298, 142469,
    142542, 144391, 144392, 151652, 153004, 156632, 162973,
    163045, 165669, 165670, 165802, 166559, 166560, 166746,
    166747, 167075, 168807, 168808, 168907, 169064, 172179,
    172924, 180290, 180817, 182773, 183716, 184353, 188952,
    190196, 190237, 193588, 198156, 200630, 202046, 206195,
    212337, 221966, 243056, 248485, 253629,
    -- Midnight Lightveil Recall Beacon (toy + quest variants)
    276371, 276372, 276373,
}

-- Class-restricted teleport toys (account toy box shows them on every character).
-- Values are UnitClass file tokens: DRUID, MAGE, etc.
Teleports.CLASS_RESTRICTED_ITEMS = {
    [136849] = "DRUID", -- Nature's Beacon
}

-- Items that may vanish from the toy box UI outside their zone; treat quest completion as owned.
Teleports.QUEST_OWNED_ITEMS = {
    [276371] = { 97071, 97072 }, -- Lightveil Recall Beacon (Val / Naigtal welcome)
    [276372] = { 97071, 97072 },
    [276373] = { 97071, 97072 },
}

-- Housing / homestead teleports often fail IsSpellKnown; allow IsSpellUsable only for these.
Teleports.USABLE_ONLY_SPELL_IDS = {
    1233637,
    1299517, -- Lightveil Recall Beacon (toy spell; may be zone-gated)
}

local spellSet = {}
local itemSet = {}
local usableOnlySet = {}
for i = 1, #Teleports.SPELL_IDS do
    spellSet[Teleports.SPELL_IDS[i]] = true
end
for i = 1, #Teleports.ITEM_IDS do
    itemSet[Teleports.ITEM_IDS[i]] = true
end
for i = 1, #Teleports.USABLE_ONLY_SPELL_IDS do
    usableOnlySet[Teleports.USABLE_ONLY_SPELL_IDS[i]] = true
end

local function SafeCall(fn, ...)
    if CA.Compat and CA.Compat.SafeCall then
        return CA.Compat.SafeCall(fn, ...)
    end
    if not fn then
        return
    end
    local results = { pcall(fn, ...) }
    if not results[1] then
        return
    end
    return unpack(results, 2, #results)
end

function Teleports.IsTeleportSpellID(spellID)
    return type(spellID) == "number" and spellSet[spellID] == true
end

function Teleports.IsTeleportItemID(itemID)
    return type(itemID) == "number" and itemSet[itemID] == true
end

local function PlayerClassFile()
    if not UnitClass then
        return nil
    end
    local _, classFile = UnitClass("player")
    return classFile
end

local function PlayerClassDisplayName()
    if not UnitClass then
        return nil
    end
    local className = UnitClass("player")
    return className
end

local classAllowCache = {}

--- Fast path for bulk toy scans: curated map only (no tooltip parsing).
function Teleports.ItemAllowedForPlayerClassFast(itemID)
    if type(itemID) ~= "number" then
        return false
    end
    local required = Teleports.CLASS_RESTRICTED_ITEMS[itemID]
    if required then
        return PlayerClassFile() == required
    end
    return true
end

--- True if this item's Classes: restriction allows the current character.
function Teleports.ItemAllowedForPlayerClass(itemID)
    if type(itemID) ~= "number" then
        return false
    end

    local cached = classAllowCache[itemID]
    if cached ~= nil then
        return cached
    end

    local required = Teleports.CLASS_RESTRICTED_ITEMS[itemID]
    if required then
        local ok = PlayerClassFile() == required
        classAllowCache[itemID] = ok
        return ok
    end

    -- Tooltip parse is expensive; only use when not already decided by curated map.
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local data = SafeCall(C_TooltipInfo.GetItemByID, itemID)
        if type(data) == "table" and type(data.lines) == "table" then
            local className = PlayerClassDisplayName()
            local classFile = PlayerClassFile()
            local localized = className
            if classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] then
                localized = LOCALIZED_CLASS_NAMES_MALE[classFile]
            end
            for i = 1, #data.lines do
                local line = data.lines[i]
                local text = type(line) == "table" and (line.leftText or line.text) or nil
                if type(text) == "string" then
                    local classes = text:match("^[Cc]lasses:%s*(.+)$")
                    if classes then
                        local lower = classes:lower()
                        local ok = false
                        if localized and lower:find(tostring(localized):lower(), 1, true) then
                            ok = true
                        elseif className and lower:find(tostring(className):lower(), 1, true) then
                            ok = true
                        end
                        classAllowCache[itemID] = ok
                        return ok
                    end
                end
            end
        end
    end

    classAllowCache[itemID] = true
    return true
end

--- True if the player has learned / can cast this teleport spell.
function Teleports.PlayerKnowsSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return false
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        if SafeCall(C_SpellBook.IsSpellKnown, spellID) then
            return true
        end
    end
    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
        if SafeCall(C_SpellBook.IsSpellKnownOrInSpellBook, spellID) then
            return true
        end
    end
    if IsPlayerSpell and SafeCall(IsPlayerSpell, spellID) then
        return true
    end
    if IsSpellKnown and SafeCall(IsSpellKnown, spellID) then
        return true
    end
    if usableOnlySet[spellID] and C_Spell and C_Spell.IsSpellUsable then
        if SafeCall(C_Spell.IsSpellUsable, spellID) then
            return true
        end
    end
    return false
end

local function IsToyItem(itemID)
    if type(itemID) ~= "number" then
        return false
    end
    if C_ToyBox and C_ToyBox.GetToyInfo then
        local id = SafeCall(C_ToyBox.GetToyInfo, itemID)
        if type(id) == "number" and id > 0 then
            return true
        end
    end
    if PlayerHasToy and itemSet[itemID] then
        if SafeCall(PlayerHasToy, itemID) then
            return true
        end
    end
    return false
end

local function QuestOwnsItem(itemID)
    local quests = Teleports.QUEST_OWNED_ITEMS[itemID]
    if type(quests) ~= "table" then
        return false
    end
    local isDone = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    if not isDone then
        return false
    end
    for i = 1, #quests do
        if SafeCall(isDone, quests[i]) then
            return true
        end
    end
    return false
end

--- True if the player owns this teleport item/toy (bags, equipped, or toy box).
function Teleports.PlayerOwnsItem(itemID)
    if type(itemID) ~= "number" or itemID <= 0 then
        return false
    end

    if PlayerHasToy and SafeCall(PlayerHasToy, itemID) then
        return true
    end

    -- Lightveil (and similar) can disappear from the toy box outside Val/Naigtal.
    if QuestOwnsItem(itemID) then
        return true
    end

    if C_Container and C_Container.PlayerHasHearthstone then
        local hs = SafeCall(C_Container.PlayerHasHearthstone)
        if hs == itemID then
            return true
        end
    end

    if GetInventoryItemID then
        for slot = 1, 19 do
            local id = SafeCall(GetInventoryItemID, "player", slot)
            if id == itemID then
                return true
            end
        end
    end

    if IsToyItem(itemID) and not (PlayerHasToy and SafeCall(PlayerHasToy, itemID)) and not QuestOwnsItem(itemID) then
        return false
    end

    if C_Item and C_Item.GetItemCount then
        local count = SafeCall(C_Item.GetItemCount, itemID, true, false, true)
        if type(count) == "number" and count > 0 then
            return true
        end
    end
    if GetItemCount then
        local count = SafeCall(GetItemCount, itemID, true)
        if type(count) == "number" and count > 0 then
            return true
        end
    end
    return false
end

--- Owned + allowed for this class (class toys are account-wide in the toy box).
function Teleports.PlayerCanUseItem(itemID)
    if not Teleports.PlayerOwnsItem(itemID) then
        return false
    end
    if not Teleports.ItemAllowedForPlayerClass(itemID) then
        return false
    end
    return true
end

--- Row/entry access gate for the Teleport tab.
function Teleports.PlayerHasAccess(info)
    info = info or {}
    local key = tostring(info.key or "")

    if key:find("^spell:") then
        return Teleports.PlayerKnowsSpell(info.spellID)
    end

    if key:find("^toy:")
        or key:find("^hearth:")
        or key:find("^item:")
        or key:find("^teleport:")
        or type(info.itemID) == "number"
    then
        local itemID = info.itemID
        if type(itemID) ~= "number" then
            itemID = info.spellID
        end
        return Teleports.PlayerCanUseItem(itemID)
    end

    if type(info.spellID) == "number" then
        return Teleports.PlayerKnowsSpell(info.spellID)
    end
    return false
end
