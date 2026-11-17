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

local function Add(kind, names)
    G.TRACK[kind] = {}
    G.TRACK_KEY[kind] = {}
    for _, name in ipairs(names) do
        local key = G.SoundKey(name)
        if key and not G.TRACK_KEY[kind][key] then
            G.TRACK_KEY[kind][key] = true
            G.TRACK[kind][#G.TRACK[kind] + 1] = { name = name, key = key }
        end
    end
end

G.TRACK = {}
G.TRACK_KEY = {}
Add("herbs", HERBS)
Add("ore", ORE)
Add("treasure", TREASURE)

function G.ListedKey(kind, name)
    local keys = G.TRACK_KEY[kind]
    if not keys then
        return nil
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
