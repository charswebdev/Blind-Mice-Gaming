local _, G = ...

local PREFIX = {
    lush = true, lightfused = true, primal = true, voidbound = true,
    transplanted = true, camouflaged = true, rich = true, webbed = true,
    smoldering = true,
}

local HERBS = {
    "Silverleaf", "Peacebloom", "Earthroot", "Mageroyal", "Briarthorn", "Swiftthistle",
    "Bruiseweed", "Stranglekelp", "Grave Moss", "Wild Steelbloom", "Kingsblood", "Liferoot",
    "Fadeleaf", "Goldthorn", "Khadgar's Whisker", "Dragon's Teeth", "Firebloom", "Purple Lotus",
    "Arthas' Tears", "Sungrass", "Blindweed", "Ghost Mushroom", "Gromsblood", "Golden Sansam",
    "Dreamfoil", "Mountain Silversage", "Plaguebloom", "Icecap", "Black Lotus",
    "Bloodthistle", "Felweed", "Dreaming Glory", "Ragveil", "Flame Cap", "Terocone",
    "Ancient Lichen", "Netherbloom", "Nightmare Vine", "Mana Thistle",
    "Goldclover", "Fire Leaf", "Tiger Lily", "Talandra's Rose", "Adder's Tongue",
    "Lichbloom", "Icethorn", "Frost Lotus", "Deadnettle",
    "Cinderbloom", "Azshara's Veil", "Stormvine", "Heartblossom", "Whiptail", "Twilight Jasmine",
    "Green Tea Leaf", "Rain Poppy", "Silkweed", "Snow Lily", "Fool's Cap", "Golden Lotus",
    "Frostweed", "Fireweed", "Gorgrond Flytrap", "Starflower", "Nagrand Arrowbloom", "Talador Orchid",
    "Aethril", "Dreamleaf", "Foxflower", "Fjarnskaggl", "Starlight Rose", "Felwort", "Astral Glory",
    "Akunda's Bite", "Anchor Weed", "Riverbud", "Sea Stalk", "Siren's Pollen", "Star Moss",
    "Winter's Kiss", "Zin'anthid",
    "Death Blossom", "Marrowroot", "Rising Glory", "Vigil's Torch", "Widowbloom", "Nightshade",
    "Hochenblume", "Bubble Poppy", "Saxifrage", "Writhebark",
    "Mycobloom", "Luredrop", "Orbinid", "Blessing Blossom", "Arathor's Spear",
    "Tranquility Bloom", "Argentleaf", "Azeroot", "Mana Lily", "Sanguithorn", "Nocturnal Lotus",
}

local ORE = {
    "Copper Vein", "Tin Vein", "Silver Vein", "Iron Deposit", "Gold Vein", "Mithril Deposit",
    "Truesilver Deposit", "Dark Iron Deposit", "Small Thorium Vein", "Thorium Vein", "Rich Thorium Vein",
    "Fel Iron Deposit", "Adamantite Deposit", "Rich Adamantite Deposit", "Khorium Vein",
    "Cobalt Deposit", "Rich Cobalt Deposit", "Saronite Deposit", "Rich Saronite Deposit", "Titanium Vein",
    "Obsidium Deposit", "Rich Obsidium Deposit", "Elementium Vein", "Rich Elementium Vein", "Pyrite Deposit",
    "Ghost Iron Deposit", "Rich Ghost Iron Deposit", "Kyparite Deposit", "Trillium Vein",
    "Blackrock Deposit", "Rich Blackrock Deposit", "True Iron Deposit", "Rich True Iron Deposit",
    "Leystone Deposit", "Leystone Seam", "Rich Leystone Deposit", "Felslate Deposit", "Felslate Seam",
    "Rich Felslate Deposit", "Empyrium Deposit", "Empyrium Seam",
    "Monelite Deposit", "Monelite Seam", "Rich Monelite Deposit", "Storm Silver Deposit",
    "Storm Silver Seam", "Platinum Deposit", "Osmenite Deposit", "Osmenite Seam",
    "Laestrite Deposit", "Elethium Deposit", "Solenium Deposit", "Oxxein Deposit",
    "Phaedrum Deposit", "Sinvyr Deposit",
    "Serevite Deposit", "Draconium Deposit", "Rich Serevite Deposit", "Rich Draconium Deposit",
    "Bismuth", "Bismuth Seam", "Ironclaw", "Ironclaw Seam", "Aqirite", "Aqirite Seam",
    "Refulgent Copper", "Refulgent Copper Seam", "Umbral Tin", "Umbral Tin Seam",
    "Brilliant Silver", "Brilliant Silver Seam", "Dazzling Thorium",
}

local TREASURE = {
    "Treasure Chest", "Battered Chest", "Solid Chest", "Bound Chest",
    "Waterlogged Chest", "Mossy Chest", "Tattered Chest",
}

local OTHERS = {
    { name = "Mailbox", key = "mailbox", words = { "mailbox" } },
    { name = "Seat", key = "seat", words = { "chair", "bench", "stool", "throne", "pew", "couch", "seat" } },
    { name = "Anvil", key = "anvil", words = { "anvil" } },
    { name = "Forge", key = "forge", words = { "forge" } },
    { name = "Campfire", key = "campfire", words = { "campfire", "bonfire" } },
    { name = "Cooking fire", key = "cooking_fire", words = { "cooking fire", "cooking stove", "stove", "oven", "grill", "cauldron" } },
    { name = "Alchemy table", key = "alchemy_table", words = { "alchemy table", "alchemy lab" } },
    { name = "Enchanting table", key = "enchanting_table", words = { "enchanting table" } },
    { name = "Workbench", key = "workbench", words = { "workbench", "work bench" } },
    { name = "Loom", key = "loom", words = { "loom" } },
    { name = "Portal", key = "portal", words = { "portal" } },
    { name = "Waygate", key = "waygate", words = { "waygate" } },
    { name = "Teleporter", key = "teleporter", words = { "teleporter" } },
    { name = "Meeting stone", key = "meeting_stone", words = { "meeting stone" } },
    { name = "Summoning stone", key = "summoning_stone", words = { "summoning stone" } },
    { name = "Mole machine", key = "mole_machine", words = { "mole machine" } },
    { name = "Elevator", key = "elevator", words = { "elevator", "lift" } },
    { name = "Boat", key = "boat", words = { "boat", "ship", "zeppelin", "airship" } },
    { name = "Door", key = "door", words = { "door", "gate", "portcullis" } },
    { name = "Guild vault", key = "guild_vault", words = { "guild vault", "guild bank" } },
    { name = "Great Vault", key = "great_vault", words = { "great vault" } },
    { name = "Mission table", key = "mission_table", words = { "mission table", "command table", "war table", "scouting map" } },
    { name = "Transmogrifier", key = "transmogrifier", words = { "transmogrifier" } },
    { name = "Book", key = "book", words = { "book", "tome", "scroll", "journal" } },
    { name = "Bulletin board", key = "bulletin_board", words = { "bulletin board", "wanted poster", "notice board" } },
    { name = "Lever", key = "lever", words = { "lever", "switch", "valve" } },
    { name = "Fishing pool", key = "fishing_pool", words = { "school" } },
    { name = "Crate", key = "crate", words = { "crate" } },
    { name = "Barrel", key = "barrel", words = { "barrel" } },
    { name = "Basket", key = "basket", words = { "basket" } },
}

local function Add(kind, names)
    G.TRACK[kind] = {}
    G.TRACK_KEY[kind] = {}
    for _, item in ipairs(names) do
        local name = item
        local key
        local words
        if type(item) == "table" then
            name = item.name
            key = item.key
            words = item.words
        end
        key = key or G.SoundKey(name)
        if key and not G.TRACK_KEY[kind][key] then
            G.TRACK_KEY[kind][key] = true
            G.TRACK[kind][#G.TRACK[kind] + 1] = { name = name, key = key, words = words }
        end
    end
end

G.TRACK = {}
G.TRACK_KEY = {}
local BOBBER = {
    { name = "Fishing bobber", key = "fishing_bobber", words = { "bobber" } },
}

local LOOT = {
    { name = "Corpse", key = "loot", words = { "corpse", "loot" } },
}

local SKIN = {
    { name = "Skin", key = "skin", words = { "skin" } },
}

local FLIGHT = {
    { name = "Flight path", key = "flight_path", words = {
        "flight master", "flightmaster", "gryphon master", "wind rider master",
        "bat handler", "hippogryph master", "dragonhawk master", "wyvern master",
        "pterrodax master",
    } },
}

Add("herbs", HERBS)
Add("ore", ORE)
Add("treasure", TREASURE)
Add("others", OTHERS)
Add("bobber", BOBBER)
Add("loot", LOOT)
Add("skinning", SKIN)
Add("flight", FLIGHT)

G.TRACK_OFF = {
    others = { mailbox = true, seat = true },
}

local function HasToken(text, word)
    if word:find(" ", 1, true) then
        return text:find(word, 1, true) ~= nil
    end
    return text:find("%f[%a]" .. word .. "%f[%A]") ~= nil
end

function G.ApplyTrackDefaults()
    if not G.db or type(G.db.track) ~= "table" then
        return
    end
    for kind, keys in pairs(G.TRACK_OFF) do
        if type(G.db.track[kind]) ~= "table" then
            G.db.track[kind] = {}
        end
        for key, off in pairs(keys) do
            if off and G.db.track[kind][key] == nil then
                G.db.track[kind][key] = false
            end
        end
    end
end

function G.ListedKey(kind, name)
    local keys = G.TRACK_KEY[kind]
    if not keys then
        return nil
    end
    local plain = G.PlainString(name)
    if plain then
        local text = plain:lower()
        local bestKey, bestLen
        local items = G.TRACK[kind]
        if items then
            for _, item in ipairs(items) do
                if item.words then
                    for _, word in ipairs(item.words) do
                        if HasToken(text, word) and (not bestLen or #word > bestLen) then
                            bestKey = item.key
                            bestLen = #word
                        end
                    end
                end
            end
        end
        if bestKey then
            return bestKey
        end
    end
    local key = G.SoundKey(name)
    if not key then
        return nil
    end
    if keys[key] then
        return key
    end
    local trimmed = key
    for _ = 1, 3 do
        local prefix, rest = trimmed:match("^([a-z0-9]+)_(.+)$")
        if prefix and PREFIX[prefix] and rest then
            trimmed = rest
            if keys[trimmed] then
                return trimmed
            end
        else
            break
        end
    end
    local shorter = trimmed:gsub("_seam$", ""):gsub("_deposit$", ""):gsub("_vein$", "")
    if keys[shorter] then
        return shorter
    end
    local best, bestLen
    for trackKey in pairs(keys) do
        local found = key == trackKey or trimmed == trackKey
            or key:find("_" .. trackKey, 1, true) or key:find(trackKey .. "_", 1, true)
            or trimmed:find("_" .. trackKey, 1, true) or trimmed:find(trackKey .. "_", 1, true)
        if found and (not bestLen or #trackKey > bestLen) then
            best = trackKey
            bestLen = #trackKey
        end
    end
    return best
end

function G.TrackLabel(kind, name)
    local key = G.ListedKey(kind, name)
    local items = key and G.TRACK[kind]
    if not items then
        return nil
    end
    for _, item in ipairs(items) do
        if item.key == key then
            return item.name
        end
    end
    return nil
end

function G.NodeAllowed(kind, name)
    if not G.TRACK_KEY[kind] then
        return true
    end
    local key = G.ListedKey(kind, name)
    if not key then
        return true
    end
    local saved = G.db.track and G.db.track[kind]
    if not saved or saved[key] == nil then
        return true
    end
    return saved[key] == true
end

function G.OtherGroup(name, iconText)
    local key = G.ListedKey("others", name)
    if not key then
        local text = G.PlainString(iconText)
        if text and HasToken(text:lower(), "mail") then
            key = "mailbox"
        end
    end
    if not key or not G.TRACK.others then
        return nil
    end
    for _, item in ipairs(G.TRACK.others) do
        if item.key == key then
            return item.name
        end
    end
    return nil
end
