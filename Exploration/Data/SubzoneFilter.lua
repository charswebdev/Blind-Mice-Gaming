-- Subzones excluded from DB2 exploration routing (stubs, scenarios, instanced interiors, city districts, legacy past-layer zone maps).
ExplorationSubzoneFilter = ExplorationSubzoneFilter or {}

local Filter = ExplorationSubzoneFilter

-- Exploration tiles listed on a zone map but routed elsewhere (duplicate DB2 stubs).
local EXCLUDED_ON_MAP = {
    [1] = {
        [374] = true, -- Bladefist Bay — not Explore Durotar; no Discover toast (Horde Cata audit)
        [375] = true, -- Deadeye Shore — not Explore Durotar; no Discover toast (Horde Cata audit)
        [2979] = true, -- Tor'kren Farm — not Explore Durotar; no Discover toast (Horde Cata audit)
        [5691] = true, -- Darkspear Shore — not Explore Durotar; Entering-only / no Discover (Horde Cata audit)
        [8746] = true, -- Zalazane's Fall — researched: no independent exploration XP
        [8748] = true, -- Darkspear Shore (retail remap) — not Explore Durotar; no Discover
        [8750] = true, -- Bloodtalon Shore — researched: no independent exploration XP
        [4863] = true, -- Bloodtalon Shore — not Explore Durotar (Echo Isles criterion); no Discover toast (user)
        -- Darkspear Hold (4866) restored — Discover XP at ~56.1, 85.3 (user)
        [4867] = true, -- Spitescale Cove — not Explore Durotar; pin sat in water off mainland (user)
    },
    [10] = {
        [720] = true, -- Fray Island — not on Explore Northern Barrens
        [1702] = true, -- Honor's Stand — not on Explore Northern Barrens; coords sat on Ashenvale seam; Explore uses Southern Barrens 4843
    },
    [7] = {
        [4878] = true, -- The Thornsnarl — not Explore Mulgore; no Discover toast (user)
        [4836] = true, -- Stonetalon Pass — not Explore Mulgore; no Discover toast at pin (user)
        [220] = true, -- Red Cloud Mesa — Explore criterion but no Discover toast/XP at pin (user)
    },
    [17] = {
        [5076] = true, -- Nethergarde Supply Camps — retail discovery toast is The Forge Grounds (7028)
        [7026] = true, -- Okril'lon Hold — Iron Horde rename of Dreadmaul Hold (1437); same footprint
    },
    [15] = {
        [1897] = true, -- The Maker's Terrace — no Discover toast/XP at pin (user)
    },
    [18] = {
        [796] = true, -- Scarlet Monastery — dungeon; Explore uses Scarlet Monastery Entrance
        [1497] = true, -- Undercity — courtyard is Ruins of Lordaeron; no separate Explore pin
    },
    [21] = {
        [172] = true, -- Fenris Isle — Explore pin never clears reliably (Keep shares tile)
        [235] = true, -- Fenris Keep — secondary Discover toast / pin mismatch with Fenris Isle
        [233] = true, -- Ambermill — no Discover toast at pin (user); Explore criterion only
    },
    [23] = {
        [4544] = true, -- Death's Breach — researched: no independent exploration XP
        [7638] = true, -- Sanctum of Light — researched: no independent exploration XP
    },
    [27] = {
        [807] = true, -- North Gate Pass — Explore Dun Morogh uses Outpost; Pass credit is Loch Modan 838
        [1537] = true, -- Ironforge — removed (city hub; pin never clears)
        [801] = true, -- Chill Breeze Valley — removed
    },
    [32] = {
        [1958] = true, -- Tanner Camp — pre-Cata Explore criterion; no fog (pin sat on Sea of Cinders)
        [1443] = true, -- The Slag Pit — not Explore Searing Gorge; pin sat on Pyrox Flats
        [1445] = true, -- Blackrock Mountain — no Discover toast/XP (user); same as Burning Steppes entrance
    },
    [36] = {
        [2421] = true, -- Draco'dar — removed in Cata; Explore uses Whelping Downs
        [5651] = true, -- Flamestar Post — fog pin; standing there enters Blackrock Mountain, no Flamestar toast
        [254] = true, -- Blackrock Mountain — Explore criterion but no Discover toast/XP at pin (user)
    },
    [47] = {
    },
    [48] = {
        [805] = true, -- South Gate Pass — Dun Morogh-side tile; no independent XP (nested under Outpost)
        [839] = true, -- South Gate Pass (Loch Modan) — no independent XP; discovery is South Gate Outpost
    },
    [49] = {
        [999] = true, -- Stonewatch Tower — no Discover toast/XP at pin (user)
    },
    [50] = {
        [128] = true, -- Ziata'jai Ruins — not Explore Northern Stranglethorn; no fog; pin sat in Lake Nazferiti
        [5318] = true, -- The Sundering — NoDiscover; border crack, not Explore Cape/Northern STV
    },
    [51] = {
    },
    [62] = {
        [4708] = true, -- Earthshatter Cavern — researched: no independent exploration XP
        [4675] = true, -- Withering Thicket — Explore Darkshore but no Discover toast (user); pin never clears
        [456] = true, -- Cliffspring River — not Explore Darkshore; no Discover toast (user)
        [4662] = true, -- Shatterspear War Camp — Explore Darkshore but no Discover toast (user)
    },
    [63] = {
        [435] = true, -- Demon Fall Canyon — not Explore Ashenvale; no Discover toast (Horde Cata audit)
        [2358] = true, -- Forest Song — not Explore Ashenvale; no Discover toast (Horde Cata audit)
        [2360] = true, -- Silverwing Outpost — secondary fog; not Explore Ashenvale
        [2797] = true, -- Blackfathom Deeps — not Explore Ashenvale
        [2897] = true, -- Zoram'gar Outpost — not Explore Ashenvale; no Discover toast (Horde Cata audit)
        [3177] = true, -- Warsong Labor Camp — not Explore Ashenvale; no Discover toast (Horde Cata audit)
    },
    [64] = {
        [439] = true, -- The Shimmering Flats — pre-Cata name; not on Explore; no fog
        [480] = true, -- Camp E'thok — not on Explore Thousand Needles; no fog
        [481] = true, -- Splithoof Crag — not on Explore Thousand Needles; no fog
        [483] = true, -- The Screeching Canyon — not on Explore Thousand Needles; no fog; Entering without Discovered
        [2237] = true, -- Whitereach Post — not on Explore Thousand Needles; no fog
        [2303] = true, -- Windbreak Canyon — not on Explore Thousand Needles; no fog
        [5046] = true, -- Mirage Abyss — not on Explore Thousand Needles; no fog
    },
    [65] = {
        [406] = true, -- Stonetalon Mountains — researched: no independent exploration XP
        [1277] = true, -- The Talondeep Path — secondary on Windshear Crag fog; not Explore Stonetalon
        [3157] = true, -- Boulderslide Cavern — not Explore Stonetalon (Ravine is); no Discover toast (Horde Cata audit)
        [5118] = true, -- Windshear Valley — no Discover toast/XP (user)
    },
    [66] = {
        [609] = true, -- Kolkar Village — not Explore Desolace; no fog; pin sat in Magram Territory
        [2657] = true, -- Valley of Bones — not Explore Desolace; no Discover toast (Horde Cata audit)
    },
    [69] = {
        [1112] = true, -- Jademir Lake — not Explore Feralas; no Discover toast (Horde Cata audit)
        [1120] = true, -- Sardor Isle — not Explore Feralas; no Discover toast (Horde Cata audit)
        [1121] = true, -- Isle of Dread — not Explore Feralas; no Discover toast (Horde Cata audit)
        [2520] = true, -- Woodpaw Den — not Explore Feralas; no Discover toast (Horde Cata audit)
        [5002] = true, -- Camp Ataya — not Explore Feralas; no Discover toast (Horde Cata audit)
        [5009] = true, -- Shadebough — not Explore Feralas; no Discover toast (Horde Cata audit)
        [5024] = true, -- Dreamer's Rest — not Explore Feralas; no Discover toast (Horde Cata audit)
    },
    [70] = {
        [499] = true, -- Darkmist Cavern — not Explore Dustwallow (Darkmist Ruins is Feralas); no Discover (Horde Cata audit)
    },
    [76] = {
        [1227] = true, -- Bay of Storms — not Explore Azshara; no fog
        [1235] = true, -- Shadowsong Shrine — not Explore Azshara; no fog
        [1236] = true, -- Haldarr Encampment — not Explore Azshara; no fog
        [1233] = true, -- Forlorn Ridge — not Explore Azshara; pin sat on Gallywix Pleasure Palace
        [3140] = true, -- Scalebeard's Cave — researched: no independent exploration XP
    },
    [77] = {
        [1769] = true, -- Timbermaw Hold — secondary on Felpaw Village fog; not Explore Felwood
        [1997] = true, -- Bloodvenom Post — not Explore Felwood (Falls is); no Discover toast (Horde Cata audit)
    },
    [78] = {
        [537] = true, -- Fire Plume Ridge — no Discover toast/XP (user)
        [541] = true, -- Marshal's Refuge — pre-Cata hub; Explore Un'Goro uses Marshal's Stand; no Discover (Horde Cata audit)
    },
    [81] = {
        [2738] = true, -- Southwind Village — Explore Silithus pre-Wound only (Zidormi past); Wound remap 9474 not explorable
        [2739] = true, -- Twilight Base Camp — not Explore Silithus
        [2740] = true, -- The Crystal Vale — Explore Silithus pre-Wound only (Zidormi past); Wound remap 9472 not explorable
        [2741] = true, -- The Scarab Dais — secondary on The Scarab Wall fog
        [2742] = true, -- Hive'Ashi — Explore Silithus pre-Wound only (Zidormi past); Wound remap 9476 not explorable
        [2743] = true, -- Hive'Zora — Explore Silithus pre-Wound only (Zidormi past); Wound remap 9478 not explorable
        [2744] = true, -- Hive'Regal — Explore Silithus pre-Wound only (Zidormi past); Wound remap 9477 not explorable
        [3098] = true, -- Twilight Post — not Explore Silithus
        [3099] = true, -- Twilight Outpost — not Explore Silithus
        [3425] = true, -- Cenarion Hold — destroyed by Sword; Explore Silithus pre-Wound only (Zidormi past)
        [3426] = true, -- Staghelm Point — not Explore Silithus
        [3427] = true, -- Bronzebeard Encampment — shared fog with Hive'Regal; not Explore Silithus
        [3428] = true, -- Ahn'Qiraj — not Explore Silithus
        [3446] = true, -- Twilight's Run — not Explore Silithus
        [3447] = true, -- Ortell's Hideout — not Explore Silithus
        [3454] = true, -- Ruins of Ahn'Qiraj — not Explore Silithus
        [9472] = true, -- The Crystal Vale (Wound) — not explorable
        [9474] = true, -- Southwind Village (Wound) — not explorable
        [9476] = true, -- Hive'Ashi (Wound) — not explorable
        [9477] = true, -- Hive'Regal (Wound) — not explorable
        [9478] = true, -- Hive'Zora (Wound) — not explorable
    },
    [102] = {
    },
    [100] = {
        [3801] = true, -- Mag'har Grounds — underfoot Mag'har Post; no independent Discover toast/XP (user)
    },
    [104] = {
        [3965] = true, -- Netherwing Mines — not Explore Shadowmoon; Entering/cave; pin sat on Netherwing Ledge (user)
    },
    [107] = {
        [3621] = true, -- Lake Sunspring — no Discover toast/XP (user); secondary on Sunspring Post
        [3760] = true, -- The Barrier Hills — Explore is Terokkar 3696; Nagrand pocket is shared secondary
    },
    [108] = {
        [3760] = true, -- The Barrier Hills (Nagrand-side shared fog); Explore Terokkar uses 3696
    },
    [114] = {
        [4026] = true, -- The Transitus Stair — researched: no independent exploration XP
        [4038] = true, -- Magnamoth Caverns — researched: no independent exploration XP
        [4133] = true, -- Charred Rise — researched: no independent exploration XP
    },
    [116] = {
    },
    [117] = {
        [495] = true, -- Howling Fjord — researched: no independent exploration XP
        [3985] = true, -- Falls of Ymiron — researched: no independent exploration XP
        [3987] = true, -- The Isle of Spears — researched: no independent exploration XP
    },
    [118] = {
        [210] = true, -- Icecrown — researched: no independent exploration XP
        [4862] = true, -- The Frozen Halls — researched: no independent exploration XP
    },
    [119] = {
        [3711] = true, -- Sholazar Basin — researched: no independent exploration XP
    },
    [120] = {
        [4448] = true, -- Path of the Titans — researched: no independent exploration XP
    },
    [121] = {
        [66] = true, -- Zul'Drak — researched: no independent exploration XP
        [4481] = true, -- Jintha'kalar Passage — researched: no independent exploration XP
    },
    [127] = {
        [2817] = true, -- Crystalsong Forest — researched: no independent exploration XP
    },
    [198] = {
        [4994] = true, -- The Forge of Supplication — not Explore Hyjal; no Discover toast (Horde Cata audit)
        [5038] = true, -- Nordrassil — no Discover toast/XP (user)
        [5337] = true, -- Sanctum of the Prophets — researched: no independent exploration XP
    },
    [199] = {
        [5385] = true, -- The Great Divide — not on Explore Southern Barrens; shares fog with The Overgrowth
        [1717] = true, -- Razorfen Kraul — Explore SB uses Entrance overlay 3009 (no Discover toast); outdoor 1717 never toasts at pin
        [5518] = true, -- Razorfen Kraul Entrance — Explore SB overlay 3009; Flags_1 has no Discover toast
    },
    [204] = {
        [4975] = true, -- Tenebrous Cavern — not Explore Vashj'ir; no Discover toast (Horde Cata audit)
        [4976] = true, -- Darkbreak Cove — not Explore Vashj'ir; no Discover toast (Horde Cata audit)
        [5145] = true, -- Abyssal Depths — researched: no independent exploration XP
    },
    [205] = {
        [4966] = true, -- Biel'aran Ridge — Entering-only; no Discover toast at pin (user); Explore lists Beth'mora (unreachable)
        [5006] = true, -- Damplight Cavern — not Explore Vashj'ir; no Discover toast (Horde Cata audit)
        [5089] = true, -- Quel'Dormir Gardens — not Explore Vashj'ir; no Discover toast (Horde Cata audit)
    },
    [201] = {
        [5030] = true, -- Shallow's End — not Explore Vashj'ir; Entering-only / parent Kelp'thar at pin
        [5057] = true, -- Smuggler's Scar — secondary on Shallow's End fog (overlay 2999); not Explore Vashj'ir
        [5058] = true, -- Deepmist Grotto — not Explore Vashj'ir; no Discover toast (Horde Cata audit)
    },
    [207] = {
        [5291] = true, -- Jagged Wastes — not Explore Deepholm; Discover secondary; pin stuck underfoot (user)
        [5292] = true, -- Scoured Reach — not Explore Deepholm; pin sat on Halcyon Egress Discover
        [5293] = true, -- Crumbling Depths — not Explore Deepholm; no Discover toast (Horde Cata audit)
        [5299] = true, -- Lorthuna's Gate — not Explore Deepholm; Discover secondary (user)
        [5303] = true, -- Temple of Earth — portal hub; Discover usually fires on Deepholm entry; pin sat under feet at chapter start
        [5328] = true, -- Upper Silvermarsh — secondary on Deathwing's Fall (5358) fog; Explore uses Deathwing's Fall; pin sat on Deathwing's Fall
        [5329] = true, -- Lower Silvermarsh — secondary on Deathwing's Fall (5358) fog; Explore uses Deathwing's Fall
        [5335] = true, -- Quartzite Basin — not Explore Deepholm; Discover secondary (user)
        [5355] = true, -- Abyssion's Lair — secondary on Twilight Overlook (5354) fog; Explore uses Twilight Overlook; pin sat on Twilight Throne
        [5410] = true, -- Silverlight Cavern — researched: no independent exploration XP
        [5418] = true, -- The Blood Trail — not Explore Deepholm; Discover secondary (user)
    },
    [210] = {
        [5318] = true, -- The Sundering — NoDiscover; pin sits on Cape near Gurubashi Arena
    },
    [217] = {
        [5433] = true, -- The Greymane Wall — researched: no independent exploration XP
        [5441] = true, -- Emberstone Village — researched: no independent exploration XP
        [5444] = true, -- Rutsak's Guard — researched: no independent exploration XP
        [5445] = true, -- Glory — researched: no independent exploration XP
        [5712] = true, -- The Blackwald — researched: no independent exploration XP
        [5713] = true, -- Hayward Fishery — researched: no independent exploration XP
    },
    [371] = {
        [5896] = true, -- The Orchid Pond - NOT USED — researched: no independent exploration XP
        [6516] = true, -- Paw'don Village — not Explore Jade Forest; Discover toast 0 XP / pin stuck (user)
    },
    [388] = {
        [6550] = true, -- Fields of Niuzao Pond — pond variant of Fields of Niuzao (6220)
    },
    [390] = {
        [6074] = true, -- Guo-Lai Halls — secondary on Ruins of Guo-Lai fog (overlay 3323); Discover is Ruins
        [6149] = true, -- Ancestral Rise — secondary on Ruins of Guo-Lai fog (overlay 3323); Flags_1=0 / Entering only
    },
    [418] = {
        [6058] = true, -- Shattered Convoy — secondary on The Forbidden Jungle (6019) fog; Explore uses Forbidden Jungle; pin sat in jungle
        [6158] = true, -- Sandy Shallows — fog sits inside The Deepwild (6004); Explore uses Deepwild; pin sat in Deepwild
        [6370] = true, -- Turtle Beach — secondary on Krasarang Cove fog (overlay 3335/3557); Explore uses Krasarang Cove
        [6572] = true, -- Snicklefritz Mine — researched: no independent exploration XP
    },
    [422] = {
        [6293] = true, -- Lake of Stars — secondary on Kypari Zar (6300) fog; Explore uses Kypari Zar; pin sat on coast
        [6404] = true, -- Muckscale Shallows — secondary on The Briny Muck (6391) fog; Explore uses The Briny Muck; pin sat in Briny Muck
    },
    [433] = {
        [6006] = true, -- The Veiled Stair — researched: no independent exploration XP
    },
    [525] = {
        [6868] = true, -- Hall of the Great Hunt — researched: no independent exploration XP
        [6875] = true, -- Bladespire Throne — top floor inside Citadel (6864); Explore uses Citadel; subzone text stays Citadel at the pin
        [6907] = true, -- Mor'dul Tower — ATT-listed but no Discover toast/XP (user)
        [6983] = true, -- Iron Siegeworks — no Discover toast/XP (user)
        [7493] = true, -- Iron Siegeworks (duplicate AreaTable) — no Discover toast/XP (user)
        [7054] = true, -- Blade's Edge Mountain — not Explore Frostfire; rubble landmark / no Discover XP (user)
        [7327] = true, -- Frostwall Mine — researched: no independent exploration XP
        [7765] = true, -- Southwind Shore — no discovery XP (user)
    },
    [534] = {
        [6723] = true, -- Tanaan Jungle — researched: no independent exploration XP
        [7718] = true, -- Scuttler's Coast — secondary on Fang'rila fog (overlay 3756); pin sat in Fang'rila
    },
    [535] = {
        [6979] = true, -- Tomb of Souls — nested under Court of Souls / Auchindoun; Explore uses Court of Souls; pin sat on Shattrath
        [6959] = true, -- Aruuna Crystal Mine — cave under Aruuna; no fog; Entering without Discover XP
        [7115] = true, -- Zangarra — pin never clears Discover toast (user); Assassin's Cove sits on same ridge
        [7200] = true, -- Auchindoun — no exploration XP (user)
        [7418] = true, -- Shattrath Port Authority — secondary on Shattrath City fog (overlay 3679)
        [7421] = true, -- Shattrath Commons — secondary on Shattrath City fog
        [7455] = true, -- Shattrath Residential District — secondary on Shattrath City fog
    },
    [539] = {
        [6787] = true, -- Grommar — researched: no independent exploration XP
        [6866] = true, -- Twilight Glade — Rangari camp inside Nightmarsh; Explore uses Nightmarsh; subzone text stays Nightmarsh
        [6922] = true, -- Moonflower Valley — not Explore Shadowmoon Valley
        [7078] = true, -- Lunarfall — researched: no independent exploration XP
        [7167] = true, -- Elodor Dig — mine under Elodor; no fog; not Explore Shadowmoon Valley; pin sat on Elodor
        [6809] = true, -- Watcher's Den — no fog; not Explore Shadowmoon Valley; pin sat in The Cursed Woods
        [7426] = true, -- The Crescent Hearth — nested in Draakorium fog; no fog tile; not Explore Shadowmoon Valley
        [7324] = true, -- Lunarfall Excavation — researched: no independent exploration XP
        [7706] = true, -- Lunarfall Shipyard — researched: no independent exploration XP
        [7258] = true, -- The Evanescent Sea — offshore / fatigue waters (Shadowmoon); same hazard as Spires 7445
        [7250] = true, -- Umbrafen Point — no Discover toast/XP (user)
    },
    [542] = {
        [6722] = true, -- Spires of Arak — researched: no independent exploration XP
        [7034] = true, -- Dreadtalon Peak — secondary on Ravenskar (7035) fog; Explore uses Ravenskar; pin never gets its own discovery
        [7392] = true, -- Pillars of Fate — fog lives on Shadowmoon (539); Spires pin sat on The Writhing Mire
        [7445] = true, -- The Evanescent Sea — Discover only mid-ocean / fatigue waters; pin kills (user)
        [7513] = true, -- Ravager Den — cave/unreachable clear; user can't find (removed)
    },
    [543] = {
        [6878] = true, -- Tailthrasher Basin — secondary on Bastion Rise fog (overlay 3609)
        [6914] = true, -- Deeproot — secondary on Bastion Rise fog (overlay 3609)
        [6915] = true, -- The Fertile Ground — secondary on Beastwatch fog (overlay 3610)
        [6935] = true, -- Razorbloom — secondary on Beastwatch fog (overlay 3610)
        [6889] = true, -- Brimstone Springs — secondary on Gronn Canyon fog (overlay 3615); AreaTable disc=false
        [6900] = true, -- Sulfur Basin — secondary on Gronn Canyon fog (overlay 3615); AreaTable disc=false
        [7394] = true, -- Steamburst Cauldron — secondary on Grimrail Depot fog (overlay 3614); AreaTable disc=false
        [7298] = true, -- Overlook Ruins — secondary on Tangleheart fog (overlay 3623); AreaTable disc=false
        [7500] = true, -- Orunai Delta — border stub; coords dump into Barrier Sea; Explore Gorgrond has no Delta
        [7320] = true, -- Everbloom Wilds — no Discover toast/XP (user)
    },
    [550] = {
        [7071] = true, -- Snarlpaw Ledge — secondary on Throne of the Elements fog (overlay 3626)
        [7074] = true, -- Telaar — Explore criterion but Entering at fog center with no Discover toast (already revealed)
        [7052] = true, -- Sabermaw — secondary on Ring of Trials fog (overlay 3636)
        [7059] = true, -- Wor'var — secondary on Hallvalor fog (overlay 3627)
        [7060] = true, -- Hemet's Happy Hunting Grounds — secondary on Hallvalor fog; Discover toast sat on Hallvalor pin
        [7094] = true, -- Stonecrag Gorge — secondary on Ring of Trials fog
        [7095] = true, -- Wrecked Caravan — secondary on Mar'gok's Overwatch fog (overlay 3632); Discover sat on Mar'gok
        [7139] = true, -- Elemental Plateau — secondary on Throne of the Elements fog (overlay 3626)
        [7271] = true, -- Worgskin's Camp — secondary on Ring of Trials fog; pin sat on Trials
        [7188] = true, -- Gra'ah — secondary on Oshu'gun (7150) fog; Explore uses Oshu'gun; pin sat on crystal
        [7204] = true, -- Sanctum of the Naaru — researched: no independent exploration XP
        [7367] = true, -- Highmaul — raid exterior/interior title; Explore Nagrand uses Highmaul Harbor
        [7375] = true, -- Gorian Proving Grounds — secondary on Ring of Blood (7376) fog; Explore uses Ring of Blood; subzone text stays Proving Grounds
        [7386] = true, -- Spiteleaf Thicket — secondary on Throne of the Elements fog (overlay 3626)
        [7406] = true, -- The Cliffs of Highmaul — surrounding cliffs; Explore Nagrand uses Highmaul Harbor
        [7408] = true, -- Windroc Bay — not Explore Nagrand; pin sat in Spirit Woods with no Discover XP (user)
    },
    [630] = {
        [7334] = true, -- Azsuna — researched: no independent exploration XP
        [7339] = true, -- Zarkhenar Temple — map label inside Ley-Ruins; not Explore Azsuna; pin sat on Ley-Ruins (user)
        [7355] = true, -- Crumbled Palace — Court of Farondis hub; not Explore Azsuna (user)
        [7947] = true, -- Axetail Grotto — researched: no independent exploration XP
        [8396] = true, -- World Boss Cave — researched: no independent exploration XP
    },
    [634] = {
        [7541] = true, -- Stormheim — researched: no independent exploration XP
        [7920] = true, -- Warden Tower — generic stub; real towers are Whisperwind's Citadel / Blackhawk's Bulwark
    },
    [641] = {
        [7558] = true, -- Val'sharah — researched: no independent exploration XP
        [7642] = true, -- Bradensbrook — removed (user); Explore Val'sharah uses Bradenbrook fog ~42.3, 58.6
        [7682] = true, -- Saberfang Cavern — researched: no independent exploration XP
        [8320] = true, -- Darkfollow's Spire — Warden Tower / not Explore Val'sharah; pin sat on Darkheart Thicket (user)
    },
    [650] = {
        [7503] = true, -- Highmountain — researched: no independent exploration XP
        [8152] = true, -- Hunter Order Hall — researched: no independent exploration XP
    },
    [680] = {
        [7637] = true, -- Suramar — researched: no independent exploration XP
        [7988] = true, -- Oculeth's Test Chamber — researched: no independent exploration XP
        [7990] = true, -- Arcano Caverns — researched: no independent exploration XP
        [8010] = true, -- Jandvik Caverns — researched: no independent exploration XP
        [8150] = true, -- Court of Stars — researched: no independent exploration XP
        [8215] = true, -- The Arcway — researched: no independent exploration XP
        [8352] = true, -- Su'esh's Lair — researched: no independent exploration XP
        [8355] = true, -- The Aetherium — researched: no independent exploration XP
        [8382] = true, -- The Waning Crescent — researched: no independent exploration XP
        [8385] = true, -- Evermoon Bazaar — researched: no independent exploration XP
        [8431] = true, -- Sanctum of Order — researched: no independent exploration XP
        [8434] = true, -- Starcaller Retreat — researched: no independent exploration XP
        [8441] = true, -- Moonbeam Causeway — researched: no independent exploration XP
        [8461] = true, -- Sanctum of Enlightenment — researched: no independent exploration XP
        [8471] = true, -- Sanctum of Order — researched: no independent exploration XP
        [8487] = true, -- Evermoon Terrace — researched: no independent exploration XP
    },
    [862] = {
        [8499] = true, -- Zuldazar — researched: no independent exploration XP
        [8500] = true, -- Nazmir — researched: no independent exploration XP
        [8690] = true, -- Zul'Nazman — not Explore Nazmir; shared fog
        [8691] = true, -- The Fallen Outpost — secondary on Rivermarsh fog
        [8693] = true, -- The Shattered River — secondary on Rivermarsh fog
        [8725] = true, -- Terrace of War — researched: no independent exploration XP
        [8922] = true, -- Koramar — not Explore Nazmir; shared fog
        [8932] = true, -- Upper Frogmarsh — not Explore Nazmir; shared fog
        [8945] = true, -- Naz'agal — not Explore Nazmir; shared fog
        [8947] = true, -- The Sundered Span — not Explore Nazmir; shared fog
        [9008] = true, -- The Dreadmire — not Explore Nazmir; shared fog
        [9039] = true, -- Blood Bog — not Explore Nazmir; shared fog
        [9041] = true, -- Natha'vor — not Explore Nazmir; shared fog
        [9047] = true, -- Shoaljai Tar Pits — not Explore Nazmir; shared fog
        [9048] = true, -- Krag'wa's Shore — not Explore Nazmir; shared fog
        [9049] = true, -- Antul'Mita Plateau — secondary on Primal Wetlands fog
        [9179] = true, -- Sethrak Front — not Explore Nazmir; shared fog
        [9229] = true, -- Burial Mound — not Explore Nazmir; shared fog
        [9435] = true, -- Blood Coast — not Explore Nazmir; shared fog
        [9539] = true, -- Sunken Path — not Explore Nazmir; shared fog
        [9543] = true, -- The Mugambala — secondary on Xibala fog; pin sat on Warport Rastari
        [9577] = true, -- Gloomwater Span — not Explore Nazmir; shared fog
        [9795] = true, -- Mangrove Shore — not Explore Nazmir; shared fog
        [9797] = true, -- Bilgewater Bonanza — secondary on Xibala fog; not Explore Zuldazar
        [9935] = true, -- Terrace of Crafters — researched: no independent exploration XP
        [9976] = true, -- Lifestone Cavern — researched: no independent exploration XP
    },
    [863] = {
        [8500] = true, -- Nazmir — researched: no independent exploration XP
        [9976] = true, -- Lifestone Cavern — researched: no independent exploration XP
        [9321] = true, -- Necropolis Catacombs — interior / no outdoor Discover toast; pin sat on The Dreadmire (user)
    },
    [864] = {
        [8855] = true, -- Abandoned Burrows — not Explore Vol'dun; shared fog
        [8856] = true, -- The Prickly Grove — not Explore Vol'dun; shared fog
        [8859] = true, -- Court of Zak'rajan — not Explore Vol'dun; shared fog
        [8862] = true, -- The Blistering Wastes — not Explore Vol'dun; shared fog
        [8863] = true, -- Valley of Sorrows — not Explore Vol'dun; shared fog
        [8866] = true, -- Deadwood Cove — not Explore Vol'dun; shared fog
        [8868] = true, -- Thundering Terrace — not Explore Vol'dun; shared fog
        [8871] = true, -- Bouldered Bluffs — not Explore Vol'dun; shared fog
        [8877] = true, -- Dead Man's Pass — not Explore Vol'dun; shared fog
        [8930] = true, -- Terrace of the Fang — not Explore Vol'dun; shared fog
        [8944] = true, -- Fangcaller Cavern — researched: no independent exploration XP
        [8959] = true, -- Crackling Ridge — not Explore Vol'dun; shared fog
        [8963] = true, -- Redrock Mesa — not Explore Vol'dun; no fog
        [9133] = true, -- Zul'Ahjin — not Explore Vol'dun; shared fog
        [9225] = true, -- Arid Basin — secondary on Temple of Akunda fog; not Explore Vol'dun
        [9266] = true, -- Verdant Plateau — not Explore Vol'dun; shared fog
        [9303] = true, -- The Alchemist's Lair — researched: no independent exploration XP
        [9312] = true, -- Temple Incursion — not Explore Vol'dun; shared fog
        [9537] = true, -- The Four Stingers — not Explore Vol'dun; shared fog
        [9542] = true, -- Scalefang Outpost — not Explore Vol'dun; shared fog
        [9555] = true, -- Redrock Lowlands — not Explore Vol'dun; no fog
        [9563] = true, -- Sandfury Hideout — not Explore Vol'dun; shared fog
        [9584] = true, -- Abandoned Passage — researched: no independent exploration XP
        [9585] = true, -- Fetid Crypt — researched: no independent exploration XP
        [9613] = true, -- Shrouded Shore — not Explore Vol'dun; shared fog
        [9646] = true, -- Eastern Dunes — not Explore Vol'dun; shared fog
        [9654] = true, -- Redsilt Wash — not Explore Vol'dun; shared fog
        [9656] = true, -- Bonepicker Summit — not Explore Vol'dun; shared fog
        [9768] = true, -- Vulture's Nest — not Explore Vol'dun; shared fog
    },
    [895] = {
        [8716] = true, -- Proudmoore Keep — Discover on Boralus 1161; pin never clears reliably on Tiragarde
        [11398] = true, -- TravisTestTerrain — researched: no independent exploration XP
        [11417] = true, -- MattTestTerrain — researched: no independent exploration XP
    },
    [896] = {
        [8721] = true, -- Drustvar — researched: no independent exploration XP
        [9177] = true, -- Rimestone's Lair — researched: no independent exploration XP
    },
    [942] = {
        [9042] = true, -- Stormsong Valley — researched: no independent exploration XP
        [9693] = true, -- Seekers' Vista — Tortollan camp; no separate discovery trigger
        [9770] = true, -- Ai'twen's Cave — researched: no independent exploration XP
    },
    [1161] = {
        [8716] = true, -- Proudmoore Keep — user-removed; Discover/clear unreliable across 895↔1161
        [10017] = true, -- Sanctum of the Sages — researched: no independent exploration XP
    },
    [1462] = {
        [10290] = true, -- Mechagon — researched: no independent exploration XP
        [10418] = true, -- Rustbolt — Mechagon grants no exploration XP
        [10419] = true, -- Overspark Expedition Camp — Mechagon grants no exploration XP
        [10420] = true, -- Prospectus Bay — Mechagon grants no exploration XP
        [10428] = true, -- The Outflow — Mechagon grants no exploration XP
        [10435] = true, -- The Heaps — Mechagon grants no exploration XP
        [10436] = true, -- Scrapbone Den — Mechagon grants no exploration XP
        [10437] = true, -- Bondo's Yard — Mechagon grants no exploration XP
        [10438] = true, -- The Fleeting Forest — Mechagon grants no exploration XP
        [10439] = true, -- Junkwatt Depot — Mechagon grants no exploration XP
        [10467] = true, -- Western Spray — Mechagon grants no exploration XP
        [10468] = true, -- Toothy Shallows — Mechagon grants no exploration XP
        [10470] = true, -- Broken Point — Mechagon grants no exploration XP
        [10567] = true, -- Crashcog Circuit — Mechagon grants no exploration XP
        [10574] = true, -- Sparkweaver Point — Mechagon grants no exploration XP
    },
    [1525] = {
        [11459] = true, -- MattTestTerrain2 — researched: no independent exploration XP
    [11474] = true,  -- Chamber of First Reflection (Bastion interior; no explore fog)
    [12815] = true,  -- First Chamber of Kalliope (interior; no explore fog)
    [12816] = true,  -- Second Chamber of Kalliope (interior; no explore fog)
    [12817] = true,  -- Third Chamber of Kalliope (interior; no explore fog)
    [11438] = true,  -- The Scorched Crypt (interior; no explore fog)
    [12782] = true,  -- Absolution Crypt (interior; no explore fog)
    },
    [1527] = {
        -- Ramkahen / Mar'at are Explore Uldum criteria (4865); keep pins (hub Discover can still fire early).
        [10839] = true, -- Ramkahen (Threats of Azeroth / Assaults phase) — same hub as 5466; prefer Manual Explore pin
        [5500] = true, -- Ramkahen Legion Outpost — Discover secondary (Manual pin)
        [5582] = true, -- The Threshold — same Explore overlay 2943 as Tombs of the Precursors
        [5583] = true, -- The Vortex Pinnacle — sky dungeon entrance; huge fog tile / no reliable separate clear
        [5586] = true, -- Vir'naal River — Discover secondary (Manual pin)
        [5613] = true, -- The Steps of Fate — secondary on Tombs of the Precursors (overlay 2943)
        [5665] = true, -- Sunwatcher's Ridge — Discover secondary (Manual pin)
        [5671] = true, -- Ruins of Khintaset — Discover secondary (Manual pin)
        [5684] = true, -- Throne of the Four Winds — sky raid entrance; not an Explore Uldum criterion
        [5688] = true, -- Mount Akher — Discover secondary (Manual pin)
        [5696] = true, -- Surveyors' Outpost — shared fog with Trail of Devastation
        [5701] = true, -- Halls of Origination Entrance — secondary on Tombs of the Precursors (overlay 2943); pin sat on Halls
        [5702] = true, -- The Vortex Pinnacle Entrance — sky dungeon; no separate discovery clear
        [5717] = true, -- Vir'naal River Delta — Discover secondary (Manual pin)
        [10844] = true, -- The Pit of Scales (retail) — spot inside Vir'naal River Delta
        [10845] = true, -- Sunstone Terrace
        [10846] = true, -- Gate of Hamatep
        [10851] = true, -- Ankhaten Harbor
        [5602] = true, -- Schnottz's Landing — Cataclysm-past only (Zidormi); present Uldum pin sits on Ankhaten Harbor sand
        [10857] = true, -- Seal of the Sun King
        [10858] = true, -- Sahket Wastes
        [10865] = true, -- Oasis of Vir'sar
        [10867] = true, -- Sullah's Sideshow
        [10868] = true, -- Maker's Ascent
        [10870] = true, -- Pilgrim's Precipice
        [10873] = true, -- Arsad Trade Post
        [10874] = true, -- Keset Pass
        [10877] = true, -- Tomb of the Sun King
        [10878] = true, -- Vir'naal Oasis
        [10879] = true, -- Vir'naal Lake
        [10881] = true, -- Bluff of the South Wind
        [10882] = true, -- Halls of Origination
        [12872] = true, -- Digestion Chamber — researched: no independent exploration XP
        [13176] = true, -- The Vortex Pinnacle (retail) — sky dungeon entrance
        [13177] = true, -- Throne of the Four Winds (retail) — sky raid entrance
    },
    [1533] = {
        [10534] = true, -- Bastion — researched: no independent exploration XP
    },
    [2022] = {
        [13644] = true, -- The Waking Shores — researched: no independent exploration XP
        [13714] = true, -- Flayscale Camp — secondary on Overflowing Rapids fog (overlay 4803); Explore uses Overflowing Rapids; fog-center pin with no Discover
    },
    [2023] = {
        [13645] = true, -- Ohn'ahran Plains — zone root; other DF zone roots filtered; Discover on zone entry not at pin
        [13770] = true, -- Field of Ferocity — not Explore Ohn'ahran Plains
        [13804] = true, -- Thunderspine Thicket — secondary on Broadhoof/Mallakh fog (overlay 4785); Explore uses Broadhoof Outpost
        [14447] = true, -- Deadsnare Caverns — no fog; not Explore Ohn'ahran Plains; Entering at cave mouth without Discover XP
        [13748] = true, -- Reedwhistle Bay — secondary on Rusza'thar fog (overlay 4792); Explore uses Rusza'thar Reach; Entering Clearwater/Steppe pockets without Discover
        [13763] = true, -- Cloverwood Hollow — Discover flag but no fog tile; ATT pin sits under Roaring Dragonsprings/Mallakh; not on Explore; no Discover toast at Loc
        [13762] = true, -- Sylvan Glade — Discover flag but no fog tile; pin under Maruukai/Mallakh; not on Explore
        [14105] = true, -- The Storm Scar — secondary on Emerald Gardens Explore fog (overlay 4787); Explore uses Emerald Gardens
        [14018] = true, -- Leafy Repose — Discover flag but no fog tile; not on Explore; Entering-only at Loc
        [13918] = true, -- Primordial Vale — Discover flag but no fog tile; not on Explore; lake/Deadsnare pocket without Discover toast
    },
    [2024] = {
        [13646] = true, -- The Azure Span — researched: no independent exploration XP
        -- Discover flag set, but Loc sits in Iskaara (Entering Iskaara @ ~13,49); no Whaler's Discover toast at 0 yd.
        [13886] = true, -- Whaler's Nook
        -- Inn of Camp Antonidas; Discover flag but no fog; Loc toasts Camp Antonidas (player verified).
        [14430] = true, -- Mage's Rest
    },
    [2025] = {
        [13647] = true, -- Thaldraszus — researched: no independent exploration XP
        [13799] = true, -- Chittering Caverns — not Explore Thaldraszus; pin sat in open air near Steelcliff
        [13800] = true, -- Fetid Encampment — not Explore Thaldraszus; Extra pin never clears
        [13881] = true, -- Wild Cliffs — not Explore Thaldraszus; pin never clears
    },
    [2133] = {
        [14022] = true, -- Zaralek Cavern — zone root
        [14711] = true, -- The Throughway — no Discover bit; Explore fog-unveil only
        [14713] = true, -- Glitterspore Lake — no Discover bit; shared fog secondary
        [14683] = true, -- Shimmering Towers — no Discover bit; secondary on Throughway fog
        [14520] = true, -- Loamm — no Discover bit; Explore fog-unveil only
        [14644] = true, -- Deephollow Lake — no Discover bit
        [14669] = true, -- The Crystal Fields — no Discover bit
        [14704] = true, -- Molten Overflow — no Discover bit
        [14646] = true, -- Nal ks'kol — no Discover bit
        [14647] = true, -- Sundered Flame Camp — no Discover bit
        [14664] = true, -- Buried Vault — no Discover bit
        [14696] = true, -- Glimmerogg — no Discover bit
        [14740] = true, -- Warder's Teeth — no Discover bit
        [14714] = true, -- Cascades Column — no Discover bit
        [14660] = true, -- Viridian Throne — no Discover bit
        [14712] = true, -- Igira's Watch — no Discover bit
        [14653] = true, -- Zaqali Caldera — no Discover bit
        [14649] = true, -- Sulfur Wastes — no Discover bit
        [14715] = true, -- Elders' Gift — no Discover bit
        [14651] = true, -- Acidbite Ravine — no Discover bit
        [14652] = true, -- Battlefield Ruins — no Discover bit
        [14682] = true, -- Brimstone Garrison — no Discover bit
        [14655] = true, -- Obsidian Rest — no Discover bit
        [14648] = true, -- Aberrus Approach — no Discover bit
    },
    [2200] = {
        [14529] = true, -- Emerald Dream — zone root / Explore fog-unveil only (no Discover toasts on routed pins)
    },
    [2151] = {
        [14433] = true, -- The Forbidden Reach — zone root; no independent exploration XP
        [14597] = true, -- The War Creche — micro-dungeon interior; Flags_1 has no Discover; fog shares Old Weyrn tile; exterior pin hits Frosted Spine
        [14587] = true, -- Froststone Vault — micro-dungeon; Flags_1 has no Discover; fog shares Lost Atheneum tile; exterior pin hits Froststone Peak
        [14586] = true, -- Caldera of the Menders — Explore overlay credit only (no Discover toast); exclusive fog NW of Reach
        [14656] = true, -- Morqut Village — Explore overlay credit only (no Discover toast)
        [14592] = true, -- Stormsunder Mountain — glyph peak only; not Explore Forbidden Reach (uses Crater)
    },
    [2215] = {
        [14838] = true, -- Hallowfall — researched: no independent exploration XP
    },
    [2395] = {
        [15968] = true, -- Eversong Woods — zone root
        [16173] = true, -- Sunstrider Isle — removed (pin never clears)
    },
    [2437] = {
        [15947] = true, -- Zul'Aman — zone root; no independent exploration XP
    },
    [2405] = {
        [15458] = true, -- Voidstorm — researched: no independent exploration XP
        [15958] = true, -- Masters' Perch — skyriding glyph / not Explore Voidstorm; near Gnawing Reach
    },
    [2413] = {
        [15355] = true, -- Harandar — researched: no independent exploration XP
        -- Non-firing sub-areas: share a fog tile with a real discovery (secondary)
        -- or have no fog geometry, so they never grant their own exploration XP.
        [15920] = true, -- The Cradle — no fog geometry
        [15921] = true, -- The Den — zone hub; no separate discovery trigger
        [15922] = true, -- Amirdrassil Roots — secondary on Har'athir tile
        [15923] = true, -- Nordrassil Roots — secondary on Har'athir tile
        [15926] = true, -- Fungal Cleft — secondary on Blooming Lattice tile
        [15927] = true, -- Teldrassil Roots — secondary on Har'mara tile
        [15929] = true, -- Shrine of Ages — secondary on Har'mara tile
        [15934] = true, -- The Tangleknot — secondary on The Blinding Bloom tile
        [15937] = true, -- Blossoming Terrace — secondary on Vale of Mists tile
        [16344] = true, -- Vale of Secrets — secondary on Den of Echoes tile
        [16346] = true, -- Veilroot Clearing — secondary on Gloom Mire tile
        [16504] = true, -- Glade of Walking Memories — no fog geometry
        [16530] = true, -- Stillroot Basin — no fog geometry
    },
    [2424] = {
        [16215] = true, -- Isle of Quel'Danas — researched: no independent exploration XP
        [16807] = true, -- Sun's Reach Harbor — no verified trigger (pins hit Dawnstar/Silver Landing)
        [16816] = true, -- Silver Landing — visit-only / never Discover-clears; stacked on Parhelion Plaza
    },
}

local EXCLUDED_IDS = {
    [13307] = true,  -- Chamber of Inner Calm — interior chamber; no explore fog

    -- Inaccessible / city district / dungeon / ocean / zone stub (no freestanding discovery pin)
    [9766] = true, -- The Golden Flagon (StormsongHubInn) — inn interior in Brennadam; no separate exploration XP
    [9763] = true, -- The Rusty Blade — inn interior at Warfang Hold; no separate exploration XP
    [4056] = true, -- Utgarde Catacombs — inaccessible/instanced interior; no outdoor discovery trigger
    [9635] = true, -- Rockskip Woodlands — Tiragarde/Drustvar border woods; no separate discovery trigger (reads bordering subzones)
    [9263] = true, -- Rockskip Falls — no separate discovery trigger at the mapped falls
    [9165] = true, -- Elderstone Mine — Fletcher's Hollow mine; interior/no separate discovery trigger
    [9636] = true, -- Northwood Home — house within Arom's Stand; no separate discovery trigger (reads Arom's Stand)
    [8568] = true, -- Boralus — overarching capital zone; use its discoverable districts instead
    [8717] = true, -- Boralus Harbor — overarching harbor area; no separate discovery trigger
    [10018] = true, -- Tradewinds Counting House — bank interior; no separate discovery trigger
    [9802] = true, -- Harbormaster's Office — Boralus building interior; no separate discovery trigger
    [9731] = true, -- The Swine's Larder — Fallhaven inn interior; no separate discovery trigger
    [9659] = true, -- The Drust Bar — Anyport tavern interior; no separate discovery trigger
    [9647] = true, -- Falcon's Roost — within Falconhurst; no separate discovery trigger (reads Falconhurst)
    [9693] = true, -- Seekers' Vista — Tortollan camp; no separate discovery trigger
    [9769] = true, -- Monastery Archives — Boralus interior
    [6682] = true, -- Tanaan Jungle — zone stub title
    [7436] = true, -- The South Sea — ocean / fatigue

    -- Auto-pruned: no outdoor discovery XP / UNUSED / instance stub
    [2] = true, -- Longshore (NoDiscoverNoFog)
    [56] = true, -- Heroes' Vigil (NoDiscoverNoFog)
    [59] = true, -- Northshire Vineyards (NoDiscoverNoFog)
    [77] = true, -- Anvilmar (NoDiscoverNoFog)
    [92] = true, -- Mirror Lake (NoDiscoverNoFog)
    [106] = true, -- The Stockpile (NoDiscoverNoFog)
    [155] = true, -- Night Web's Hollow (NoDiscoverNoFog)
    [158] = true, -- Agamand Family Crypt (NoDiscoverNoFog)
    [168] = true, -- The North Coast (NoDiscoverNoFog)
    [169] = true, -- Whispering Shore (NoDiscoverNoFog)
    [173] = true, -- Faol's Rest (NoDiscoverNoFog)
    [238] = true, -- Malden's Orchard (NoDiscoverNoFog)
    [240] = true, -- The Dead Field (removed; Forsaken Rear Guard)
    [251] = true, -- Flame Crest (NoDiscoverNoFog)
    [359] = true, -- Bael Modan [UNUSED] (UNUSED,UNUSED,NoDiscoverNoFog)
    [378] = true, -- Camp Taurajo [UNUSED] (UNUSED,UNUSED,NoDiscoverNoFog)
    [385] = true, -- Northwatch Hold [UNUSED] (UNUSED,UNUSED,NoDiscoverNoFog)
    [390] = true, -- Field of Giants [UNUSED] (UNUSED,UNUSED,NoDiscoverNoFog)
    [411] = true, -- Bathran's Haunt (NoDiscoverNoFog)
    [412] = true, -- The Ruins of Ordil'Aran (NoDiscoverNoFog)
    [895] = true, -- Bleak Hills Mine (MISSING_AREA)
    [1316] = true, -- Razorfen Downs [UNUSED] (UNUSED,UNUSED)
    [1577] = true, -- Cape of Stranglethorn (NoDiscoverNoFog)
    [1581] = true, -- The Deadmines (InstanceStub)
    [1697] = true, -- Raptor Grounds [UNUSED] (UNUSED,UNUSED,NoDiscoverNoFog)
    [1701] = true, -- Blackthorn Ridge [UNUSED] (UNUSED,UNUSED,NoDiscoverNoFog)
    [2117] = true, -- Shadow Grave (NoDiscoverNoFog)
    [2118] = true, -- Brill Town Hall (NoDiscoverNoFog)
    [2119] = true, -- Gallows' End Tavern (NoDiscoverNoFog)
    [2399] = true, -- The Great Sea (NoDiscoverNoFog)
    [2560] = true, -- Ariden's Camp (NoDiscoverNoFog)
    [2625] = true, -- Eastwall Gate (NoDiscoverNoFog)
    [3097] = true, -- The Swarming Pillar (NoDiscoverNoFog)
    [4760] = true, -- The Sea Reaver's Run (NoDiscoverNoFog)
    [5637] = true, -- Lion's Pride Inn (NoDiscoverNoFog)
    [5808] = true, -- Sulfuron Keep Courtyard (NoDiscoverNoFog)
    [5809] = true, -- Sulfuron Keep (NoDiscoverNoFog)
    [5810] = true, -- Anvil of Conflagration (NoDiscoverNoFog)
    [5811] = true, -- The Molten Fields (NoDiscoverNoFog)
    [5812] = true, -- Mortal's Demise (NoDiscoverNoFog)
    [5813] = true, -- Sulfuron Span (NoDiscoverNoFog)
    [5814] = true, -- Shatterstone (NoDiscoverNoFog)
    [5815] = true, -- Flamebreach (NoDiscoverNoFog)
    [5816] = true, -- The Ridge of Ancient Flame (NoDiscoverNoFog)
    [5817] = true, -- Rhyolith Plateau (NoDiscoverNoFog)
    [5818] = true, -- Firelands (NoDiscoverNoFog)
    [6608] = true, -- Heyman's Hubris (NoDiscoverNoFog)
    [6680] = true, -- Battlefront Provisions (NoDiscoverNoFog)
    [6683] = true, -- Misty Shores (NoDiscoverNoFog)
    [6770] = true, -- Blackguard's Forgotten Cove (NoDiscoverNoFog)
    [6773] = true, -- Old Pi'jiu (NoDiscoverNoFog)
    [6822] = true, -- Ruby Lake (NoDiscoverNoFog)
    [6823] = true, -- Ordon Sanctuary (NoDiscoverNoFog)
    [6824] = true, -- Croaking Hollow (NoDiscoverNoFog)
    [6825] = true, -- Firewalker Ruins (NoDiscoverNoFog)
    [6830] = true, -- The Celestial Court (NoDiscoverNoFog)
    [6831] = true, -- Mossgreen Lake (NoDiscoverNoFog)
    [6832] = true, -- The Timeless Shore (NoDiscoverNoFog)
    [6835] = true, -- The Misty Strand (NoDiscoverNoFog)
    [6839] = true, -- Mysterious Den (NoDiscoverNoFog)
    [6840] = true, -- Whispershade Hollow (NoDiscoverNoFog)
    [6842] = true, -- Firewalkers' Path (NoDiscoverNoFog)
    [6843] = true, -- Shrine of the Black Flame (NoDiscoverNoFog)
    [6844] = true, -- The Blazing Way (NoDiscoverNoFog)
    [6899] = true, -- Affliction Ridge (NoDiscoverNoFog)
    [6911] = true, -- Pit of the Devourer (NoDiscoverNoFog)
    [6917] = true, -- Liadrin's Watch (NoDiscoverNoFog)
    [6929] = true, -- Frostboar Drifts (NoDiscoverNoFog)
    [6934] = true, -- Rooter's Pass (NoDiscoverNoFog)
    [6937] = true, -- Sharptusk Lake (NoDiscoverNoFog)
    [6997] = true, -- Ango'rosh Ruins (NoDiscoverNoFog)
    [7000] = true, -- Seat of Depravity (NoDiscoverNoFog)
    [7016] = true, -- Spires of Arak (NoDiscoverNoFog)
    [7025] = true, -- Tanaan Jungle (NoDiscoverNoFog)
    [7062] = true, -- The Burning Glacier (NoDiscoverNoFog)
    [7141] = true, -- Arch of Sha'tar (NoDiscoverNoFog)
    [7154] = true, -- Drywind Gorge (NoDiscoverNoFog)
    [7155] = true, -- Valley of Destruction (NoDiscoverNoFog)
    [7191] = true, -- Talador (NoDiscoverNoFog)
    [7222] = true, -- Admiral Taylor's Farm (NoDiscoverNoFog)
    [7236] = true, -- Tor'goroth's Tooth (NoDiscoverNoFog)
    [7237] = true, -- Bloodmaul Landing (NoDiscoverNoFog)
    [7255] = true, -- Zangar Sea (NoDiscoverNoFog)
    [7257] = true, -- Glacier Bay (NoDiscoverNoFog)
    [7265] = true, -- Tanaan Channel (NoDiscoverNoFog)
    [7299] = true, -- Ruins of the First Bastion (NoDiscoverNoFog)
    [7322] = true, -- Crushfang's End (NoDiscoverNoFog)
    [7417] = true, -- Sha'tari Anchorage (NoDiscoverNoFog)
    [7419] = true, -- Beacon of Sha'tar (NoDiscoverNoFog)
    [7420] = true, -- Shattrath City (NoDiscoverNoFog)
    [7422] = true, -- Sha'tari Market District (NoDiscoverNoFog)
    [7447] = true, -- Colossal Depths (NoDiscoverNoFog)
    [7453] = true, -- Sha'tar Way Station (NoDiscoverNoFog)
    [7480] = true, -- Shattrath Overlook (NoDiscoverNoFog)
    [7520] = true, -- Iron Docks (NoDiscoverNoFog)
    [7594] = true, -- The Underbelly (NoDiscoverNoFog)
    [7971] = true, -- Karazhan Catacombs (NoDiscoverNoFog)
    [14859] = true, -- Fields of Reverie (NoDiscoverNoFog)
    [14862] = true, -- Barrows of Reverie (NoDiscoverNoFog)
    [14864] = true, -- Scorching Chasm (NoDiscoverNoFog)
    [14912] = true, -- Wellspring Overlook (NoDiscoverNoFog)
    [14914] = true, -- Wildfire Canyon (NoDiscoverNoFog)
    [14959] = true, -- Lucid Reef (NoDiscoverNoFog)
    [14960] = true, -- Central Encampment (NoDiscoverNoFog)
    [14961] = true, -- Shiversnap Grove (NoDiscoverNoFog)
    [14973] = true, -- Springrain River (NoDiscoverNoFog)
    [15013] = true, -- Sor'theril Barrow Den (NoDiscoverNoFog)
    [15014] = true, -- Sprigling Gloam (NoDiscoverNoFog)
    [15017] = true, -- Rootwoven Strand (NoDiscoverNoFog)
    [15517] = true, -- The Royal Apothecary (NoDiscoverNoFog)
    -- Auto-pruned NotExplorable / AreaBit==0 (no discovery XP)
    [14147] = true, -- Pinewood Post (NotExplorable,AreaBit=0)
    [14437] = true, -- Training Grounds (Dragonflight; NotExplorable,AreaBit=0)
    [14487] = true, -- Ancient Outlook (NotExplorable,AreaBit=0)
    [14054] = true, -- The Nokhud Approach (NotExplorable,AreaBit=0)
    [14065] = true, -- Melting Knoll (NotExplorable,AreaBit=0)
    [14089] = true, -- Vakthros (NotExplorable,AreaBit=0)
    [14094] = true, -- Wanderer's Steppe (NotExplorable,AreaBit=0)
    [14097] = true, -- Sundapple Copse (NotExplorable,AreaBit=0)
    [14103] = true, -- Lost Ruins (NotExplorable,AreaBit=0)
    [14107] = true, -- Conservatory Outpost (NotExplorable,AreaBit=0)
    [14350] = true, -- Life-Binder Observatory (NotExplorable,AreaBit=0)
    [14355] = true, -- The Watering Hole (NotExplorable,AreaBit=0)
    [14356] = true, -- The Mallakh (NotExplorable,AreaBit=0)
    [14455] = true, -- Forge of Arcanum (NotExplorable,AreaBit=0)
    [14462] = true, -- Thunderspine Ridge (NotExplorable,AreaBit=0)
    [14948] = true, -- Pillar-nest Xesh (NotExplorable,AreaBit=0)
    [14988] = true, -- Swirling Mists (NotExplorable,AreaBit=0)
    [15330] = true, -- Old Sacrificial Pit (NotExplorable,AreaBit=0)
    [16002] = true, -- Khiyed Ruins (NotExplorable,AreaBit=0)
    [16082] = true, -- Murder Row (NotExplorable,AreaBit=0)
    [16083] = true, -- Walk of Elders (NotExplorable,AreaBit=0)
    [16084] = true, -- The Royal Exchange (NotExplorable,AreaBit=0)
    [16085] = true, -- Court of Blood (NotExplorable,AreaBit=0)
    [16086] = true, -- Court of the Sun (NotExplorable,AreaBit=0)
    [16088] = true, -- Falconwing Square (NotExplorable,AreaBit=0)
    [16089] = true, -- Dawning Lane (NotExplorable,AreaBit=0)
    [16094] = true, -- Augurs' Terrace (NotExplorable,AreaBit=0)
    [16095] = true, -- Lithiel's Landing (NotExplorable,AreaBit=0)
    [16096] = true, -- Thalassian University (NotExplorable,AreaBit=0)
    [16097] = true, -- Gardens of Remembrance (NotExplorable,AreaBit=0)
    [16098] = true, -- Sunwing Rookery (NotExplorable,AreaBit=0)
    [16099] = true, -- Silvermoon Harbor (NotExplorable,AreaBit=0)
    [16100] = true, -- The Shining Span (NotExplorable,AreaBit=0)
    [16233] = true, -- Shatter Gorge (NotExplorable,AreaBit=0)
    [16235] = true, -- Duskglow Gloriette (NotExplorable,AreaBit=0)
    [16357] = true, -- Sunfury Spire (NotExplorable,AreaBit=0)
    [16526] = true, -- The Sunwell (NotExplorable,AreaBit=0)
    [16570] = true, -- The Shepherd's Gate (NotExplorable,AreaBit=0)
    [16618] = true, -- Hall of Blood (NotExplorable,AreaBit=0)
    [16633] = true, -- The Illicit Rain (NotExplorable,AreaBit=0)
    [16634] = true, -- Astalor's Sanctum (NotExplorable,AreaBit=0)
    [16644] = true, -- Silvermoon City Inn (NotExplorable,AreaBit=0)
    [16645] = true, -- Wayfarer's Rest (NotExplorable,AreaBit=0)
    [16754] = true, -- Court of the Phoenix (NotExplorable,AreaBit=0)
    [16815] = true, -- Greengill Coast (NotExplorable,AreaBit=0)
    [11414] = true, -- Exile Overlook (Nazjatar)
    [11436] = true, -- [Vignette Space 1]
    [11437] = true, -- [Vignette Space 2]
    [13312] = true, -- Maldrxxus Covenant Finale Scenario
    [5336] = true,  -- Remains of the Fleet (TH intro; phased out)
    [5105] = true,  -- Pincer X2 (Vashj'ir quest-only sub)
    [8828] = true,  -- Overgrown Camp (warfront duplicate)
    [8832] = true,  -- Teegan's Expedition (warfront duplicate)
    [10331] = true, -- Lower Cataracts (Nazjatar intro; phased during Send the Fleet chain)
    [4401] = true,  -- Saragosa's Landing (quest sky platform only)
    [4427] = true,  -- Argent Vanguard (Storm Peaks DB2 dup; use 4501 on Icecrown)
    [13819] = true, -- DefunctThaldraszusarea (cut stub)
    [14159] = true, -- Creektooth Den (duplicate of 13852)
    [14620] = true, -- Blue Dragon Choice (quest zone-picker UI)
    [13854] = true, -- Primalist POI (developer stub)
    [13855] = true, -- Primalist POI 2 (developer stub)
    [14087] = true, -- Ashscale HallsS (scenario variant of 14086)
    [7353] = true,  -- Kraklaa's Hatchery (cut content)
    [7336] = true,  -- Smuggler's Bay (cut content)
    [8720] = true,  -- Tomb of Sargeras (raid)
    [7937] = true,  -- Lonehoof Watch (cut content)
    [9021] = true,  -- Maw of N'Zoth (cut placeholder)
    -- Harandar: AreaTable NotExplorable / AreaBit==0 (no discovery XP)
    [15921] = true, -- The Den — zone hub; no separate discovery trigger
    [16401] = true, -- Ahl'ua Wetland
    [16345] = true, -- Shrouded Grove
    [16347] = true, -- Verdant Sepulcher
    [16506] = true, -- Dreth'amar Cavern
    [16543] = true, -- Floaret Grotto
    [16400] = true, -- Glimmering Cataract
    [16750] = true, -- Har'alnor Den
    [16583] = true, -- Nai'theren Grotto
    [16584] = true, -- Nihil
    [16528] = true, -- The Shadow Cleft
    -- Voidstorm: NotExplorable / non-XP / PvP-forward hubs (not outdoor discovery XP)
    [15965] = true, -- The Bladeburrows — skyriding glyph; not Explore Voidstorm
    [15958] = true, -- Masters' Perch — skyriding glyph; not Explore Voidstorm
    [15966] = true, -- Den of Predaxas — treasure cave; not Explore Voidstorm
    [16534] = true, -- Lair of Predaxas — quest/micro dungeon; not Explore Voidstorm
    [16649] = true, -- Masters' Perch parent (NotExplorable)
    [16216] = true, -- Bastion of Might (Horde forward)
    [16223] = true, -- Bastion of Valor (Alliance forward)
    [16491] = true, -- Bastion of Might BG
    [16492] = true, -- Bastion of Valor BG
    [7950] = true,  -- Mysthoof Watch (cut content)
    [7839] = true,  -- PH Ocean (dev stub)
    [7625] = true,  -- The Black Rose (scenario ship)
    [8367] = true,  -- The King's Fang (scenario ship)
    [8035] = true,  -- Thorim's Rise (cut content)
    [7631] = true,  -- Honeyglow Glade (cut content)
    [7671] = true,  -- Magula's Den (unused planned name)
    [8325] = true,  -- Wildwood Road (cut content)
    [6089] = true,  -- Yeti Mountain Basecamp (cut content)
    [6140] = true,  -- Mogu Ruins Bural Pit (TEMP)
    [6316] = true,  -- Ik'vess (cut content)
    [6317] = true,  -- Klik'vess (cut content)
    [6318] = true,  -- Set'vess (beta duplicate)
    [6332] = true,  -- The Overlook Inn (cut content)
    [6431] = true,  -- Seaspittle Cove (cut content)
    [6490] = true,  -- Nightingale Lounge (cut content)
    [6541] = true,  -- Applebloom Tavern (cut content)
    [6577] = true,  -- The Thunderspire (cut content)
    [6396] = true,  -- Gate of the Setting Sun (dungeon)
    [6414] = true,  -- Grove of Falling Blossoms (dungeon)
    [6478] = true,  -- South Seas (Dread Wastes)
    [6479] = true,  -- South Seas (Townlong)
    [6480] = true,  -- South Seas (Kun-Lai)
    [6481] = true,  -- South Seas (Jade Forest)
    [6548] = true,  -- Venomous Ledge (duplicate of 6418)
    [6595] = true,  -- The Skyfire (scenario ship)
    [6709] = true,  -- Salabria (scenario ship)
    [6710] = true,  -- The Starchaser (scenario ship)
    [6711] = true,  -- Spellsails (scenario ship)
    [6713] = true,  -- Rhonin's Beard (scenario ship)
    [6821] = true,  -- South Seas (Timeless Isle)
    [6846] = true,  -- Time-Lost Waters (open ocean)
    -- Warlords of Draenor — stubs, ocean, garrison phased, dungeons, duplicates
    [6810] = true,  -- Giant's Fall (cut content)
    [8675] = true,  -- Umbral Halls (dungeon/scenario interior)
    [7794] = true,  -- Vol'mar Hold (garrison phased)
    [7300] = true,  -- Barrier Sea (open sea)
    [6883] = true,  -- Blackrock Pipeworks (cut content)
    [6897] = true,  -- Blackrock Shipyard (cut content)
    [6961] = true,  -- Canyon Pass (cut content)
    [7489] = true,  -- Cragplume Cauldron (duplicate of 6885)
    [6896] = true,  -- Elemental Hollow (cut content)
    [7166] = true,  -- Highpass Logging Camp (garrison phased)
    [7283] = true,  -- Highpass Sparring Ring (garrison phased)
    [7259] = true,  -- Iron Sea (open sea)
    [7282] = true,  -- Lowlands Lumber Yard (garrison phased)
    [7178] = true,  -- Rexxar's Refuge (cut content)
    [7281] = true,  -- Savage Fight Club (garrison phased)
    [6942] = true,  -- Spineling Crevice (cut content)
    [6940] = true,  -- The Binding Trench (cut content)
    [6952] = true,  -- The Sulfic Refuge (cut content)
    [7393] = true,  -- Verdantis Pass (cut content)
    [6865] = true,  -- zzOld Explosion Town (dev stub)
    [6890] = true,  -- zzOld Gorgrond Garrison Area (dev stub)
    [7184] = true,  -- zzOld Imperial Road (dev stub)
    [7170] = true,  -- zzOld Sundered Pass (dev stub)
    [6898] = true,  -- zzOld Tankworks (dev stub)
    [7146] = true,  -- Bones of Sethe (cut content)
    [7616] = true,  -- The Forgotten Roost (cut content)
    [7628] = true,  -- The Desolation of Gorefiend (Auchindoun interior)
    [7138] = true,  -- Trak's Rise (cut content)
    [7287] = true,  -- Wrynn Artillery Tower (garrison phased)
    [7057] = true,  -- Gol'gor (cut content)
    [7066] = true,  -- Nagrand Corral (garrison phased)
    [7293] = true,  -- Rangari Corral (garrison phased)
    [7463] = true,  -- The Coliseum (Highmaul raid interior)
    [7369] = true,  -- The Shattered Tower (cut content)
    [7468] = true,  -- The Underbelly (Highmaul raid interior)
    -- The War Within — dungeons, raids, duplicates, phased interiors
    [14771] = true,  -- Dornogal capital — Discover on portal/Entering; stuck 0 yd Explore pin
    [15450] = true,  -- Keeper's Breath — secondary on Thunderhead Peak Explore fog; no toast at pin
    [14779] = true,  -- Golgrin's Reach — secondary on Wanderer's Landing Explore fog; no toast at pin
    [14822] = true,  -- Pillarstone Spire — elevator Loc is Shadowvein Point; no Discover toast at pin
    [15170] = true,  -- Shadowvein Mine — Loc is The Warrens Discover; no Mine toast at pin
    [14805] = true,  -- Brunwin's Terrace — secondary on Gundargaz fog; pin Loc was Lost Mines (Entering-only)
    [14801] = true,  -- Nibelgaz Mine — secondary on Earthenworks Explore fog; Loc reported Shadowvein Mine (Entering-only)
    [15097] = true,  -- Sina's Yearning — secondary on Light's Blooming fog; pin Loc was Stillstone Pond
    [14902] = true,  -- The Whispering Chasm — shares Ruptured Lake Explore fog; pin Loc was lake Discover
    [14758] = true,  -- Arathi's End — not on Explore Azj-Kahet; Entering-only at pin (no Discover toast)
    [15552] = true,  -- The Undersea (duplicate of 14944)
    [15470] = true,  -- Laboratory of the Grand Splicer (The Underkeep delve)
    [14792] = true,  -- Nerub-ar Palace (raid)
    [14818] = true,  -- Darkflame Cleft Exterior (dungeon)
    [15533] = true,  -- The Hoardroom (Gallywix campaign interior)
    [15783] = true,  -- The Moneymaker (quest scenario vehicle)
    -- Battle for Azeroth — Mechagon interiors / micro-zones (no discovery XP; not in Explore Mechagon)
    [10991] = true,  -- Bloody Grotto (PvP fight club cave)
    [10496] = true,  -- Crumbling Cavern
    [10511] = true,  -- Tinted Cave
    [10536] = true,  -- Rustrock Cavern
    [10538] = true,  -- Crystalized Cavern
    [10539] = true,  -- The Burned Cave
    [10543] = true,  -- Engineer's Respite
    [10465] = true,  -- Grunters Hideout
    [10533] = true,  -- Hungry Rest
    [10510] = true,  -- Moch'k's Hole
    [10589] = true,  -- Scavenger's Alcove
    [10566] = true,  -- Scrapbone's Hollow
    [10531] = true,  -- Sourback Hideout
    [10580] = true,  -- Echo's Hovel
    [10564] = true,  -- The Greasy Eel
    -- Battle for Azeroth — Dazar'alor city districts (ATT only; not in Explore Zuldazar)
    [8666] = true,  -- Grand Bazaar
    [9172] = true,  -- Terrace of the Chosen
    [9543] = true,  -- The Mugambala — secondary on Xibala fog; pin sat on Warport Rastari
    [9797] = true,  -- Bilgewater Bonanza — secondary on Xibala fog
    [8871] = true, -- Bouldered Bluffs — not Explore Vol'dun; shared fog
    [8930] = true, -- Terrace of the Fang — not Explore Vol'dun; shared fog
    [9613] = true, -- Shrouded Shore — not Explore Vol'dun; shared fog
    [8855] = true, -- Abandoned Burrows — not Explore Vol'dun; shared fog
    [9656] = true, -- Bonepicker Summit — not Explore Vol'dun; shared fog
    [8856] = true, -- The Prickly Grove — not Explore Vol'dun; shared fog
    [9768] = true, -- Vulture's Nest — not Explore Vol'dun; shared fog
    [8868] = true, -- Thundering Terrace — not Explore Vol'dun; shared fog
    [9654] = true, -- Redsilt Wash — not Explore Vol'dun; shared fog
    [8959] = true, -- Crackling Ridge — not Explore Vol'dun; shared fog
    [8859] = true, -- Court of Zak'rajan — not Explore Vol'dun; shared fog
    [9312] = true, -- Temple Incursion — not Explore Vol'dun; shared fog
    [8877] = true, -- Dead Man's Pass — not Explore Vol'dun; shared fog
    [9537] = true, -- The Four Stingers — not Explore Vol'dun; shared fog
    [9563] = true, -- Sandfury Hideout — not Explore Vol'dun; shared fog
    [9646] = true, -- Eastern Dunes — not Explore Vol'dun; shared fog
    [8862] = true, -- The Blistering Wastes — not Explore Vol'dun; shared fog
    [9266] = true, -- Verdant Plateau — not Explore Vol'dun; shared fog
    [8863] = true, -- Valley of Sorrows — not Explore Vol'dun; shared fog
    [9133] = true, -- Zul'Ahjin — not Explore Vol'dun; shared fog
    [9225] = true, -- Arid Basin — secondary on Temple of Akunda fog; not Explore Vol'dun
    [8866] = true, -- Deadwood Cove — not Explore Vol'dun; shared fog
    [9542] = true, -- Scalefang Outpost — not Explore Vol'dun; shared fog
    [8934] = true, -- Rootway — secondary on Savagelands fog; not Explore Zuldazar
    [9049] = true, -- Antul'Mita Plateau — secondary on Primal Wetlands fog
    [8690] = true, -- Zul'Nazman — not Explore Nazmir; shared fog
    [8922] = true, -- Koramar — not Explore Nazmir; shared fog
    [9229] = true, -- Burial Mound — not Explore Nazmir; shared fog
    [9047] = true, -- Shoaljai Tar Pits — not Explore Nazmir; shared fog
    [9577] = true, -- Gloomwater Span — not Explore Nazmir; shared fog
    [9008] = true, -- The Dreadmire — not Explore Nazmir; shared fog
    [9179] = true, -- Sethrak Front — not Explore Nazmir; shared fog
    [9041] = true, -- Natha'vor — not Explore Nazmir; shared fog
    [9039] = true, -- Blood Bog — not Explore Nazmir; shared fog
    [9435] = true, -- Blood Coast — not Explore Nazmir; shared fog
    [9795] = true, -- Mangrove Shore — not Explore Nazmir; shared fog
    [8947] = true, -- The Sundered Span — not Explore Nazmir; shared fog
    [8945] = true, -- Naz'agal — not Explore Nazmir; shared fog
    [8932] = true, -- Upper Frogmarsh — not Explore Nazmir; shared fog
    [9048] = true, -- Krag'wa's Shore — not Explore Nazmir; shared fog
    [9539] = true, -- Sunken Path — not Explore Nazmir; shared fog
    [8693] = true, -- The Shattered River — secondary on Rivermarsh fog
    [8691] = true, -- The Fallen Outpost — secondary on Rivermarsh fog
    -- Removed: Shadowlands no-fly / Maw hub districts (legacy filter IDs retained)
    [13677] = true,  -- The Path of Understanding
    -- No discovery XP
    [172] = true,  -- Fenris Isle — Explore pin never clears reliably (Keep shares tile)
    [235] = true,  -- Fenris Keep — secondary on Fenris Isle; Discover/pin mismatch
    [342] = true,  -- Camp Boff (removed from Explore Badlands / no fog tile)
    [1877] = true, -- Valley of Fangs (destroyed in Cata; footprint is Bloodwatcher Point)
    [2057] = true,  -- Scholomance (instance; outdoor discovery is Caer Darrow)
    [2620] = true,  -- Thondroril River (WPL, Flags_1=0; discovery is EPL 2619)
    [2519] = true,  -- Woodpaw Hills — secondary on Darkmist Ruins (5036) Explore fog
    [2938] = true,  -- Sleeping Gorge — secondary on Deadman's Crossing fog (overlay 941); not Explore Deadwind Pass
    [3732] = true,  -- Kirin'Var Village — Explore fog covered by Town Square / Wizard Row / Chapel Yard Discover pins; parent pin stuck at wrong map coords
    [3973] = true,  -- Blackwind Landing — Flags_1=0 (Entering only); exclusive Explore fog but no Discover toast; pin never clears
    [3703] = true,  -- Shattrath City — Flags_1=0 (Entering only); city hub / Terrace of Light; pin never clears
    [3957] = true,  -- Sha'tari Outpost — planned/unused subzone; shared fog with Base Camp; pin sat off cliff edge
    [3657] = true,  -- Portal Clearing — secondary on Marshlight Lake Explore fog (area 3656)
    [3669] = true,  -- The Stadium — secondary on Hellfire Citadel Explore fog (area 3545)
    [3670] = true,  -- The Overlook — secondary on Hellfire Citadel Explore fog (area 3545)
    [3672] = true,  -- Mag'hari Procession — secondary on Sunspring Post Explore fog (area 3622)
    [3700] = true,  -- The Ring of Blood — secondary on Laughing Skull Ruins Explore fog (area 3616)
    [3718] = true,  -- Swamprat Post — secondary on The Dead Mire Explore fog (area 3648)
    [3788] = true,  -- The Low Path — secondary on Burning Blade Ruins Explore fog (area 3610)
    [3807] = true,  -- Reaver's Fall — secondary on The Legion Front Explore fog (area 3804)
    [3808] = true,  -- Cenarion Post — secondary on Ruins of Sha'naar Explore fog (area 3551)
    [3815] = true,  -- Expedition Point — secondary on Zeth'Gor Explore fog (area 3582)
    [3816] = true,  -- Zeppelin Crash — secondary on The Warp Fields Explore fog (area 3796)
    [3839] = true,  -- Abandoned Armory — secondary on Southwind Cleft Explore fog (area 3629)
    [3895] = true,  -- Cenarion Watchpost — secondary on Quagg Ridge Explore fog (area 3646)
    [3964] = true,  -- Skyguard Outpost — secondary on Vortex Summit Explore fog (area 3832)
    [3965] = true,  -- Netherwing Mines — not Explore Shadowmoon; Entering/cave; pin sat on Netherwing Ledge (user)
    [4581] = true,  -- Flamewatch Tower (Entering only; no Discover XP)
    [4584] = true,  -- The Cauldron of Flames (Entering only; no Discover XP)
    [4586] = true,  -- Windy Bluffs (Entering only; pin sat on fortress; no Discover XP)
    [4482] = true,  -- Arriga Footbridge (Entering only; no Discover XP)
    [4486] = true,  -- The Frozen Mine (Entering only; no Discover XP / no explore fog)
    [4534] = true,  -- Wildervar Mine (Entering only; no explore fog; stacked on Fort Wildervar)
    [4252] = true,  -- The Broken Bluffs (HF; Entering only; no explore fog / no Discover XP)
    [4476] = true,  -- Abandoned Camp (Entering only; no explore fog / not findable)
    -- [4635] Drak'Tharon Keep (Zul'Drak): kept — Flags_1 explore; fog at keep
    [4705] = true,  -- Raynewood Tower — pocket on Raynewood Retreat Explore fog (overlay 752)
    [1237] = true,  -- Valormok — secondary on Orgrimmar Rear Gate Explore fog (overlay 2438)
    [2160] = true,  -- Windshear Mine — no Explore overlay; Discover pin sits on Windshear Crag fog (overlay 925)
    [2537] = true,  -- Grimtotem Post — secondary on Greatwood Vale Explore fog (overlay 2558)
    [4693] = true,  -- Splintertree Mine — no Explore overlay; Discover pin sits on Splintertree Post fog (overlay 754)
    [4861] = true,  -- The Regrowth — secondary on The Flamewake Explore fog (overlay 2499)
    [4935] = true,  -- Mirkfallon Post — pocket inside Mirkfallon Lake Discover fog
    [445] = true,  -- Cliffspring Falls — not Explore Darkshore; no fog overlay; pin clustered on Cliffspring River
    [454] = true,  -- Wildbend River — Explore Darkshore overlay 2457 but Flags_1=0 (no Discover toast); pin sat on Grove of the Ancients
    [4661] = true,  -- Cliffspring Hollow — not Explore Darkshore; no fog overlay; pin sat on Cliffspring River Discover
    [1225] = true,  -- Ursolan — not Explore Azshara; no fog overlay; pin sat on Darkshore seam
    [4698] = true,  -- Moontouched Den (Darkshore) — not Explore Darkshore; no fog overlay; pin sat on Felwood seam
    [5014] = true,  -- The Inferno — not Explore Hyjal; pin sat on The Throne of Flame (overlay 2501)
    [5019] = true,  -- Sanctuary of Malorne — secondary on The Flamewake Explore fog (overlay 2499)
    [6062] = true,  -- Kun-Lai Pass — not Explore Kun-Lai Summit; pin sat on Inkgill/Binan
    -- Isle of Thunder (map 504) — quest-gated portal; not freestanding exploration
    [6576] = true, -- Diremoor
    [6578] = true, -- Court of Bones
    [6579] = true, -- Za'Tual
    [6580] = true, -- Ihgaluk Crag
    [6581] = true, -- Zeb'tula
    [6582] = true, -- Shaol'mara
    [6583] = true, -- Violet Rise
    [6584] = true, -- Dawnseeker Promontory
    [6585] = true, -- The Emperor's Gate
    [6586] = true, -- The Beast Pens
    [6587] = true, -- Conqueror's Terrace
    [6588] = true, -- Bloodied Crossing
    [6590] = true, -- The Thunder Forges
    [6591] = true, -- Stormsea Landing
    [6592] = true, -- The Swollen Vault
    [6593] = true, -- The Foot of Lei Shen
    [6608] = true, -- Heyman's Hubris
    [6672] = true, -- Bleak Hollow
    [6676] = true, -- Bay of Echoes
    [6680] = true, -- Battlefront Provisions
    [6703] = true, -- Whispering Inlet
    [6708] = true, -- The Crimson Treader
    [6712] = true, -- The Seabolt
    [6724] = true, -- Backbreaker Bay
    [6725] = true, -- Greymist Firth
    [6726] = true, -- Wildvine Marsh
    [6727] = true, -- Shadewood Thicket
    [6729] = true, -- Isle of Thunder
    [12873] = true, -- Seat of Ramkahen — spot inside Ramkahen town; no fog / not on Explore Uldum
    [5701] = true, -- Halls of Origination Entrance — secondary on Tombs of the Precursors fog (overlay 2943)
    [5613] = true, -- The Steps of Fate — secondary on Tombs of the Precursors fog (overlay 2943)
    [5582] = true, -- The Threshold — same Explore overlay 2943 as Tombs of the Precursors
    [10844] = true, -- The Pit of Scales (retail) — spot inside Vir'naal River Delta
    [5583] = true, -- The Vortex Pinnacle — sky dungeon entrance; huge fog / no reliable separate clear
    [5702] = true, -- The Vortex Pinnacle Entrance — sky dungeon
    [13176] = true, -- The Vortex Pinnacle (retail) — sky dungeon entrance
    [5684] = true, -- Throne of the Four Winds — sky raid entrance; not an Explore Uldum criterion
    [13177] = true, -- Throne of the Four Winds (retail) — sky raid entrance
    [5638] = true, -- Throne of the Four Winds raid instance
    [8660] = true, -- Throne of the Four Winds instance variant
    -- Uldum Finale audit: not on Explore Uldum / no reliable discovery clear
    [10879] = true, -- Vir'naal Lake
    [10878] = true, -- Vir'naal Oasis
    [5696] = true, -- Surveyors' Outpost — shared fog with Trail of Devastation
    [5717] = true, -- Vir'naal River Delta
    [5688] = true, -- Mount Akher
    [5665] = true, -- Sunwatcher's Ridge
    [5586] = true, -- Vir'naal River
    [5500] = true, -- Ramkahen Legion Outpost
    [5671] = true, -- Ruins of Khintaset
    [10865] = true, -- Oasis of Vir'sar
    [10868] = true, -- Maker's Ascent
    [10858] = true, -- Sahket Wastes
    [10870] = true, -- Pilgrim's Precipice
    [10851] = true, -- Ankhaten Harbor
    [5602] = true, -- Schnottz's Landing — Cataclysm-past only (Zidormi); skip on present Uldum
    [10873] = true, -- Arsad Trade Post
    [10881] = true, -- Bluff of the South Wind
    [10846] = true, -- Gate of Hamatep
    [10882] = true, -- Halls of Origination
    [10874] = true, -- Keset Pass
    [10857] = true, -- Seal of the Sun King
    [10867] = true, -- Sullah's Sideshow
    [10845] = true, -- Sunstone Terrace
    [10877] = true, -- Tomb of the Sun King
    [483] = true, -- The Screeching Canyon — not on Explore Thousand Needles; no fog
    [480] = true, -- Camp E'thok — not on Explore Thousand Needles; no fog
    [481] = true, -- Splithoof Crag — not on Explore Thousand Needles; no fog
    [439] = true, -- The Shimmering Flats — pre-Cata; not on Explore; no fog
    [2237] = true, -- Whitereach Post — not on Explore Thousand Needles; no fog
    [2303] = true, -- Windbreak Canyon — not on Explore Thousand Needles; no fog
    [5046] = true, -- Mirage Abyss — not on Explore Thousand Needles; no fog
    [1717] = true, -- Razorfen Kraul — Explore SB criterion is Entrance fog (3009) with no Discover toast; pin never clears
    [5518] = true, -- Razorfen Kraul Entrance — Explore SB overlay 3009; no Discover toast
    [1702] = true, -- Honor's Stand (Northern Barrens) — not Explore NB; seam-misplaced; use Southern Barrens 4843
    [720] = true, -- Fray Island — not on Explore Northern Barrens
    [7026] = true,  -- Okril'lon Hold (Iron Horde rename of Dreadmaul Hold; no separate toast)
    [8003] = true,  -- Temple of A Thousand Lights (duplicate of 7693)
    [6453] = true,  -- Echo Isles (parent zone; Explore fog shared with Zalazane/Training overlay 248)
    [368] = true,  -- Echo Isles (legacy AreaID; same parent fog as 6453)
    [2738] = true, -- Southwind Village — Explore Silithus pre-Wound only (Zidormi past)
    [2740] = true, -- The Crystal Vale — Explore Silithus pre-Wound only (Zidormi past)
    [2742] = true, -- Hive'Ashi — Explore Silithus pre-Wound only (Zidormi past)
    [2743] = true, -- Hive'Zora — Explore Silithus pre-Wound only (Zidormi past)
    [2744] = true, -- Hive'Regal — Explore Silithus pre-Wound only (Zidormi past)
    [3425] = true, -- Cenarion Hold — Explore Silithus pre-Wound only (Zidormi past)
    [9472] = true, -- The Crystal Vale (Wound) — not explorable
    [9474] = true, -- Southwind Village (Wound) — not explorable
    [9476] = true, -- Hive'Ashi (Wound) — not explorable
    [9477] = true, -- Hive'Regal (Wound) — not explorable
    [9478] = true, -- Hive'Zora (Wound) — not explorable
    [3446] = true, -- Twilight's Run — not Explore Silithus
    [3426] = true, -- Staghelm Point — not Explore Silithus
    [3098] = true, -- Twilight Post — not Explore Silithus
    [2739] = true, -- Twilight Base Camp — not Explore Silithus
    [3447] = true, -- Ortell's Hideout — not Explore Silithus
    [3099] = true, -- Twilight Outpost — not Explore Silithus
    [3428] = true, -- Ahn'Qiraj — not Explore Silithus
    [2741] = true, -- The Scarab Dais — secondary on The Scarab Wall fog
    [3454] = true, -- Ruins of Ahn'Qiraj — not Explore Silithus
    [3427] = true, -- Bronzebeard Encampment — shared fog with Hive'Regal; not Explore Silithus
    -- Bay of Kings (9717) kept — BFA Horde exploration start
    -- Northfold Manor (313) + Circle of West Binding (334) — Explore Arathi criteria
    [9735] = true,  -- Ar'gorok — BFA warfront rename of Northfold; not Explore Arathi
    [9736] = true,  -- Hatchet Ridge — BFA warfront rename of Circle of West Binding
    [5121] = true,  -- Galen's Fall (removed in BFA; footprint is Thoradin's Wall)
    [10293] = true,  -- Ruins of Mathystra (Warfronts/variant) — retail Discover/Explore is 443
    [10296] = true,  -- Cliffspring Falls (Warfronts/variant) — retail 445 filtered
    [10306] = true,  -- Cliffspring River (Warfronts/variant) — retail area 456 filtered (pin sat on Maw)
    [10310] = true,  -- Lor'danel (Warfronts/variant) — retail Discover/Explore is 4659
    [10312] = true,  -- Cliffspring Hollow (Warfronts/variant) — retail 4661 filtered
    [10315] = true,  -- The Eye of the Vortex (Warfronts/variant) — retail Discover/Explore is 4695
    [10321] = true,  -- Shatterspear Pass (Warfronts/variant) — retail Discover is 4702
    [14433] = true,  -- The Forbidden Reach — zone root; no independent exploration XP
    [14592] = true,  -- Stormsunder Mountain — glyph peak only; not Explore Forbidden Reach
    [13885] = true,  -- Tuskarr Ice Elemental Cave — Discover but no outdoor fog (interior cave)
    [14047] = true,  -- Shattered Vaults — Discover but no outdoor fog (interior vault)
    [13803] = true,  -- Gelikyr Overlook — no Discover / no outdoor fog
    [13800] = true,  -- Fetid Encampment — not Explore Thaldraszus; Extra pin never clears
    [13799] = true,  -- Chittering Caverns — not Explore Thaldraszus; pin sat in open air
    [13881] = true,  -- Wild Cliffs — not Explore Thaldraszus; pin never clears
    [13878] = true,  -- Aqueduct Basin — no Discover / no outdoor fog
    [13875] = true,  -- Shadow Ledge — no Discover / no outdoor fog
    [13877] = true,  -- Steelcliff Rampart — no Discover / no outdoor fog
    [13827] = true,  -- Pleasant Hill — no Discover / no outdoor fog
    [13644] = true,  -- The Waking Shores — zone root; no independent exploration XP
    [13645] = true,  -- Ohn'ahran Plains — zone root; no independent exploration XP
    [13646] = true,  -- The Azure Span — zone root; no independent exploration XP
    [13647] = true,  -- Thaldraszus — zone root; no independent exploration XP
}

-- uiMapIDs not on default retail layer (Zidormi / Chromie past phase, or superseded geography).
local EXCLUDED_LEGACY_ZONE_MAPS = {
    [57] = true,  -- Teldrassil (pre-BFA burn)
    [89] = true,  -- Darnassus (pre-BFA burn)
    [94] = true,  -- Eversong Woods (BC)
    [95] = true,  -- Ghostlands (BC)
    [110] = true, -- Silvermoon City (BC)
    [122] = true, -- Isle of Quel'Danas (BC)
    [504] = true, -- Isle of Thunder (quest-gated portal; ocean path / not freestanding)
    [830] = true, -- Krokuun (Argus; removed from Legion pack)
    [882] = true, -- Eredath (Argus; removed from Legion pack)
    [885] = true, -- Antoran Wastes (Argus; removed from Legion pack)
}

local STUB_MARKERS = {
    "(PH)",
    "[PH]",
    "[DNT]",
    "(cin)",
    "[Unused]",
    "[UNUSED]",
    "UNUSED",
}

local SCENARIO_PATTERNS = {
    "scenario",
    "vignette",
    "finale",
}

local INTERIOR_PATTERNS = {
    "Cave",
    "Cavern",
    "Grotto",
    "Depths",
    "Tunnel",
    "Underground",
    "Interior",
    "Catacomb",
    "Crypt",
    "Sewer",
    "Passage",
    "Chamber",
    "Vaults",
    "Entrance",
    "Lair",
    "Breach",
    -- Outdoor achievement mines (Nethergarde Mines, Jasperlode Mine, etc.) grant XP;
    -- only exclude clearly instanced mine interiors.
    "Mine Interior",
    "Mineshaft",
}

local INSTANCE_PATTERNS = {
    "Hall of Blades",
    "Hall of Cantrips",
    "Hall of Chains",
    "Hall of Elixirs",
    "Hall of Ichor",
    "Hall of Sorcery",
    "Hall of Tomes",
    "Hall of Horrors",
    "Hall of the Defamed",
    "Hall of the Exalted",
    "Hall of the Grand Imperion",
    "Hall of the Great Hunt",
    "Prime Arcanum",
    "Molten Forge",
    "Spire of War",
    "Etheric Vault",
    "Flesh Stitchery",
    "Alluvium Hollow",
    "Thread House",
    "Toxxulanar",
    "Sightless Hold",
    "Vault of Souls",
    "The Reagentry",
    "The Sorcerous Steps",
    "The Forgotten Forge",
    "Reliquary of",
    "The Rift",
    "Gromit Hollow",
    "Locrian Esper",
    "Underweald",
    "Defiled Altar",
    "Chamber of Wisdom",
    "Chamber of Knowledge",
    "Chamber of Shaping",
    "Chamber of the Sigil",
}

local CITY_PATTERNS = {
    "Commons",
    "Promenade",
    "Aetherium",
    "Hall of the",
    "Hall of Samples",
    "Bazaar",
    "Refectory",
    "Sanctum of",
    "Sanctum Depths",
    "Moonbeam Causeway",
    "Waning Crescent",
    "Suramar City",
    "Evermoon",
    "Starcaller Retreat",
    "Shal'Aran",
}

-- Lazy-built: uiMapID -> { [explorationID] = true } for subzones that grant discovery XP (ATT allowlist).
local attXpByMap

local function buildAttXpByMap()
    local out = {}
    if not ExplorationATTByMap then
        return out
    end

    local globalAtt = {}
    for _, ids in pairs(ExplorationATTByMap) do
        for i = 1, #ids do
            globalAtt[ids[i]] = true
        end
    end

    local mapIds = {}
    for mid in pairs(ExplorationATTByMap) do
        mapIds[mid] = true
    end
    if ExplorationDB2Coords then
        for _, entry in pairs(ExplorationDB2Coords) do
            if entry.map then
                mapIds[entry.map] = true
            end
        end
    end

    for mapId in pairs(mapIds) do
        local allowed = {}
        if ExplorationDB2Coords then
            for eid in pairs(globalAtt) do
                local db2 = ExplorationDB2Coords[eid]
                if db2 and db2.map == mapId then
                    allowed[eid] = true
                end
            end
        end
        local bucket = ExplorationATTByMap[mapId]
        if bucket then
            for i = 1, #bucket do
                local eid = bucket[i]
                if globalAtt[eid] then
                    allowed[eid] = true
                end
            end
        end
        if next(allowed) then
            out[mapId] = allowed
        end
    end
    return out
end

local function grantsDiscoveryXP(explorationID, uiMapID)
    if not explorationID or not uiMapID or not ExplorationATTByMap then
        return nil
    end
    if not attXpByMap then
        attXpByMap = buildAttXpByMap()
    end
    local allowed = attXpByMap[uiMapID]
    if not allowed then
        return nil
    end
    if allowed[explorationID] then
        return true
    end
    return false
end

local function contains(haystack, needle)
    return haystack:find(needle, 1, true) ~= nil
end

local function containsWord(haystack, word)
    local pattern = "%f[%w]" .. word:lower() .. "%f[%W]"
    return haystack:lower():find(pattern) ~= nil
end

local function isStubName(name, lower)
    for i = 1, #STUB_MARKERS do
        if contains(lower, STUB_MARKERS[i]:lower()) then
            return true
        end
    end
    -- Prefix / embedded stubs: "UNUSEDThe Marris Stead", "Foo UNUSED", etc.
    if contains(lower, "unused") then
        return true
    end
    if lower:match("^not used") or contains(lower, "not used") then
        return true
    end
    if lower == "test" or name:match("TestTerrain") then
        return true
    end
    if name:match("^TEST") then
        return true
    end
    if lower:match("^<unnamed poi") then
        return true
    end
    return false
end


-- Gate 1: hard denials (stuck / Entering-only / no toast / shared fog).
-- ATT Discover-XP may override soft EXCLUDED_* but never these.
local EXCLUDED_HARD_IDS = {
    [2] = true,
    [56] = true,
    [59] = true,
    [66] = true,
    [77] = true,
    [92] = true,
    [106] = true,
    [128] = true,
    [155] = true,
    [158] = true,
    [168] = true,
    [169] = true,
    [172] = true,
    [173] = true,
    [210] = true,
    [220] = true,
    [233] = true, -- Ambermill — no Discover toast at pin (user)
    [235] = true,
    [238] = true,
    [251] = true,
    [254] = true, -- Blackrock Mountain (Burning Steppes) — no Discover toast/XP (user)
    [342] = true,
    [359] = true,
    [378] = true,
    [385] = true,
    [390] = true,
    [406] = true,
    [411] = true,
    [412] = true,
    [439] = true,
    [445] = true,
    [454] = true,
    [480] = true,
    [481] = true,
    [483] = true,
    [495] = true,
    [609] = true,
    [999] = true, -- Stonewatch Tower — no Discover toast/XP at pin (user)
    [1225] = true,
    [1227] = true,
    [1233] = true,
    [1235] = true,
    [1236] = true,
    [1237] = true,
    [1277] = true,
    [1443] = true,
    [1445] = true, -- Blackrock Mountain (Searing Gorge) — no Discover toast/XP (user)
    [1537] = true,
    [1577] = true,
    [1697] = true,
    [1701] = true,
    [1702] = true,
    [1717] = true,
    [1769] = true,
    [1897] = true, -- The Maker's Terrace — no Discover toast/XP at pin (user)
    [1958] = true,
    [2117] = true,
    [2118] = true,
    [2119] = true,
    [2237] = true,
    [2303] = true,
    [2399] = true,
    [2519] = true,
    [2537] = true,
    [2560] = true,
    [2620] = true,
    [2625] = true,
    [2741] = true,
    [2817] = true,
    [2938] = true,
    [3097] = true,
    [3140] = true,
    [3427] = true,
    [3657] = true,
    [3669] = true,
    [3670] = true,
    [3672] = true,
    [3700] = true,
    [3703] = true,
    [3711] = true,
    [3718] = true,
    [3732] = true,
    [3760] = true,
    [3788] = true,
    [3807] = true,
    [3808] = true,
    [3815] = true,
    [3816] = true,
    [3839] = true,
    [3895] = true,
    [3957] = true,
    [3964] = true,
    [3965] = true,
    [3973] = true,
    [3985] = true,
    [3987] = true,
    [4026] = true,
    [4038] = true,
    [4056] = true,
    [4133] = true,
    [4252] = true,
    [4448] = true,
    [4476] = true,
    [4481] = true,
    [4482] = true,
    [4486] = true,
    [4534] = true,
    [4544] = true,
    [4581] = true,
    [4584] = true,
    [4586] = true,
    [4661] = true,
    [4675] = true,
    [4698] = true,
    [4708] = true,
    [4760] = true,
    [4861] = true,
    [4862] = true,
    [4867] = true,
    [4878] = true,
    [4836] = true,
    [4966] = true,
    [5014] = true,
    [5019] = true,
    [5030] = true,
    [5046] = true,
    [5057] = true,
    [5145] = true,
    [5291] = true,
    [5292] = true,
    [5303] = true,
    [5318] = true,
    [5328] = true,
    [5329] = true,
    [5337] = true,
    [5355] = true,
    [5410] = true,
    [5433] = true,
    [5441] = true,
    [5444] = true,
    [5445] = true,
    [5518] = true,
    [5613] = true,
    [5637] = true,
    [5691] = true,
    [5696] = true,
    [5701] = true,
    [5712] = true,
    [5713] = true,
    [5808] = true,
    [5809] = true,
    [5810] = true,
    [5811] = true,
    [5812] = true,
    [5813] = true,
    [5814] = true,
    [5815] = true,
    [5816] = true,
    [5817] = true,
    [5818] = true,
    [5896] = true,
    [6006] = true,
    [6058] = true,
    [6062] = true,
    [6074] = true,
    [6149] = true,
    [6158] = true,
    [6293] = true,
    [6370] = true,
    [6404] = true,
    [6516] = true,
    [6572] = true,
    [6608] = true,
    [6680] = true,
    [6683] = true,
    [6722] = true,
    [6723] = true,
    [6770] = true,
    [6773] = true,
    [6787] = true,
    [6809] = true,
    [6822] = true,
    [6823] = true,
    [6824] = true,
    [6825] = true,
    [6830] = true,
    [6831] = true,
    [6832] = true,
    [6835] = true,
    [6839] = true,
    [6840] = true,
    [6842] = true,
    [6843] = true,
    [6844] = true,
    [6868] = true,
    [6878] = true,
    [6889] = true,
    [6899] = true,
    [6900] = true,
    [6907] = true,
    [7250] = true, -- Umbrafen Point — no Discover toast/XP (user)
    [7320] = true, -- Everbloom Wilds — no Discover toast/XP (user)
    [6983] = true, -- Iron Siegeworks — no Discover toast/XP (user)
    [7493] = true, -- Iron Siegeworks (duplicate) — no Discover toast/XP (user)
    [5038] = true, -- Nordrassil — no Discover toast/XP (user)
    [5118] = true, -- Windshear Valley — no Discover toast/XP (user)
    [537] = true, -- Fire Plume Ridge — no Discover toast/XP (user)
    [3801] = true, -- Mag'har Grounds — no Discover toast/XP (user)
    [3621] = true, -- Lake Sunspring — no Discover toast/XP (user)
    [6911] = true,
    [6914] = true,
    [6915] = true,
    [6917] = true,
    [6929] = true,
    [6934] = true,
    [6935] = true,
    [6937] = true,
    [6959] = true,
    [6979] = true,
    [6997] = true,
    [7000] = true,
    [7016] = true,
    [7025] = true,
    [7034] = true,
    [7052] = true,
    [7059] = true,
    [7060] = true,
    [7062] = true,
    [7071] = true,
    [7074] = true,
    [7078] = true,
    [7094] = true,
    [7095] = true,
    [7115] = true,
    [7139] = true,
    [7141] = true,
    [7154] = true,
    [7155] = true,
    [7167] = true,
    [7188] = true,
    [7191] = true,
    [7204] = true,
    [7222] = true,
    [7236] = true,
    [7237] = true,
    [7255] = true,
    [7257] = true,
    [7265] = true,
    [7271] = true,
    [7298] = true,
    [7299] = true,
    [7322] = true,
    [7324] = true,
    [7327] = true,
    [7334] = true,
    [7339] = true,
    [7367] = true,
    [7375] = true,
    [7386] = true,
    [7392] = true,
    [7394] = true,
    [7408] = true,
    [7417] = true,
    [7418] = true,
    [7419] = true,
    [7420] = true,
    [7421] = true,
    [7422] = true,
    [7426] = true,
    [7447] = true,
    [7453] = true,
    [7455] = true,
    [7463] = true,
    [7468] = true,
    [7480] = true,
    [7503] = true,
    [7520] = true,
    [7541] = true,
    [7558] = true,
    [7594] = true,
    [7628] = true,
    [7637] = true,
    [7638] = true,
    [7682] = true,
    [7706] = true,
    [7718] = true,
    [7765] = true,
    [7947] = true,
    [7971] = true,
    [7988] = true,
    [7990] = true,
    [8010] = true,
    [8150] = true,
    [8152] = true,
    [8215] = true,
    [8352] = true,
    [8355] = true,
    [8382] = true,
    [8385] = true,
    [8396] = true,
    [8431] = true,
    [8434] = true,
    [8441] = true,
    [8461] = true,
    [8471] = true,
    [8487] = true,
    [8499] = true,
    [8500] = true,
    [8675] = true,
    [8690] = true,
    [8691] = true,
    [8693] = true,
    [8716] = true,
    [8721] = true,
    [8725] = true,
    [8746] = true,
    [8750] = true,
    [8855] = true,
    [8856] = true,
    [8859] = true,
    [8862] = true,
    [8863] = true,
    [8866] = true,
    [8868] = true,
    [8871] = true,
    [8877] = true,
    [8922] = true,
    [8930] = true,
    [8932] = true,
    [8934] = true,
    [8944] = true,
    [8945] = true,
    [8947] = true,
    [8959] = true,
    [8963] = true,
    [9008] = true,
    [9039] = true,
    [9041] = true,
    [9042] = true,
    [9047] = true,
    [9048] = true,
    [9049] = true,
    [9133] = true,
    [9165] = true,
    [9177] = true,
    [9179] = true,
    [9225] = true,
    [9229] = true,
    [9266] = true,
    [9303] = true,
    [9312] = true,
    [9321] = true,
    [9435] = true,
    [9537] = true,
    [9539] = true,
    [9542] = true,
    [9543] = true,
    [9555] = true,
    [9563] = true,
    [9577] = true,
    [9584] = true,
    [9585] = true,
    [9613] = true,
    [9646] = true,
    [9654] = true,
    [9656] = true,
    [9659] = true,
    [9731] = true,
    [9763] = true,
    [9766] = true,
    [9768] = true,
    [9769] = true,
    [9770] = true,
    [9795] = true,
    [9797] = true,
    [9802] = true,
    [9935] = true,
    [9976] = true,
    [10017] = true,
    [10018] = true,
    [10290] = true,
    [10306] = true,
    [10534] = true,
    [11398] = true,
    [11417] = true,
    [11438] = true,
    [11459] = true,
    [11474] = true,
    [12782] = true,
    [12815] = true,
    [12816] = true,
    [12817] = true,
    [12872] = true,
    [12873] = true,
    [13307] = true,
    [13644] = true,
    [13646] = true,
    [13647] = true,
    [13714] = true,
    [13748] = true,
    [13762] = true,
    [13763] = true,
    [13799] = true,
    [13800] = true,
    [13804] = true,
    [13881] = true,
    [13885] = true,
    [13918] = true,
    [14018] = true,
    [14047] = true,
    [14054] = true,
    [14065] = true,
    [14089] = true,
    [14094] = true,
    [14097] = true,
    [14103] = true,
    [14105] = true,
    [14107] = true,
    [14147] = true,
    [14350] = true,
    [14355] = true,
    [14356] = true,
    [14437] = true,
    [14447] = true,
    [14455] = true,
    [14462] = true,
    [14487] = true,
    [14587] = true,
    [14592] = true,
    [14597] = true,
    [14683] = true,
    [14713] = true,
    [14758] = true,
    [14771] = true,
    [14779] = true,
    [14801] = true,
    [14805] = true,
    [14838] = true,
    [14859] = true,
    [14862] = true,
    [14864] = true,
    [14912] = true,
    [14914] = true,
    [14948] = true,
    [14959] = true,
    [14960] = true,
    [14961] = true,
    [14973] = true,
    [14988] = true,
    [15013] = true,
    [15014] = true,
    [15017] = true,
    [15097] = true,
    [15330] = true,
    [15355] = true,
    [15450] = true,
    [15458] = true,
    [15517] = true,
    [15533] = true,
    [15920] = true,
    [15922] = true,
    [15923] = true,
    [15926] = true,
    [15927] = true,
    [15929] = true,
    [15934] = true,
    [15937] = true,
    [15958] = true,
    [15965] = true,
    [15966] = true,
    [16002] = true,
    [16082] = true,
    [16083] = true,
    [16084] = true,
    [16085] = true,
    [16086] = true,
    [16088] = true,
    [16089] = true,
    [16094] = true,
    [16095] = true,
    [16096] = true,
    [16097] = true,
    [16098] = true,
    [16099] = true,
    [16100] = true,
    [16173] = true,
    [16215] = true,
    [16233] = true,
    [16235] = true,
    [16344] = true,
    [16346] = true,
    [16357] = true,
    [16504] = true,
    [16526] = true,
    [16530] = true,
    [16570] = true,
    [16618] = true,
    [16633] = true,
    [16634] = true,
    [16644] = true,
    [16645] = true,
    [16649] = true,
    [16754] = true,
    [16815] = true,
    [16816] = true,
}

local EXCLUDED_HARD_ON_MAP = {
    [1] = {
        [4867] = true,
        [5691] = true,
        [8746] = true,
        [8750] = true,
    },
    [7] = {
        [4878] = true, -- The Thornsnarl — no Discover toast (user)
        [4836] = true, -- Stonetalon Pass — no Discover toast at pin (user)
        [220] = true, -- Red Cloud Mesa — no Discover toast/XP at pin (user)
    },
    [15] = {
        [1897] = true, -- The Maker's Terrace — no Discover toast/XP at pin (user)
    },
    [21] = {
        [172] = true,
        [233] = true, -- Ambermill — no Discover toast at pin (user)
    },
    [23] = {
        [4544] = true,
        [7638] = true,
    },
    [27] = {
        [1537] = true,
    },
    [32] = {
        [1443] = true,
        [1445] = true, -- Blackrock Mountain — no Discover toast/XP (user)
        [1958] = true,
    },
    [36] = {
        [254] = true, -- Blackrock Mountain — no Discover toast/XP (user)
    },
    [49] = {
        [999] = true, -- Stonewatch Tower — no Discover toast/XP at pin (user)
    },
    [50] = {
        [128] = true,
        [5318] = true,
    },
    [62] = {
        [4675] = true,
        [4708] = true,
    },
    [64] = {
        [439] = true,
        [480] = true,
        [481] = true,
        [483] = true,
        [2237] = true,
        [2303] = true,
        [5046] = true,
    },
    [65] = {
        [406] = true,
        [1277] = true,
        [5118] = true, -- Windshear Valley — no Discover toast/XP (user)
    },
    [66] = {
        [609] = true,
    },
    [76] = {
        [1227] = true,
        [1233] = true,
        [1235] = true,
        [1236] = true,
        [3140] = true,
    },
    [77] = {
        [1769] = true,
    },
    [81] = {
        [2741] = true,
        [3427] = true,
    },
    [104] = {
        [3965] = true,
    },
    [108] = {
        [3760] = true,
    },
    [114] = {
        [4026] = true,
        [4038] = true,
        [4133] = true,
    },
    [117] = {
        [495] = true,
        [3985] = true,
        [3987] = true,
    },
    [118] = {
        [210] = true,
        [4862] = true,
    },
    [119] = {
        [3711] = true,
    },
    [120] = {
        [4448] = true,
    },
    [121] = {
        [66] = true,
        [4481] = true,
    },
    [127] = {
        [2817] = true,
    },
    [198] = {
        [5038] = true, -- Nordrassil — no Discover toast/XP (user)
        [5337] = true,
    },
    [199] = {
        [5518] = true,
    },
    [201] = {
        [5030] = true,
        [5057] = true,
    },
    [204] = {
        [5145] = true,
    },
    [205] = {
        [4966] = true,
    },
    [207] = {
        [5291] = true,
        [5292] = true,
        [5303] = true,
        [5328] = true,
        [5329] = true,
        [5355] = true,
        [5410] = true,
    },
    [210] = {
        [5318] = true,
    },
    [217] = {
        [5433] = true,
        [5441] = true,
        [5444] = true,
        [5445] = true,
        [5712] = true,
        [5713] = true,
    },
    [371] = {
        [5896] = true,
        [6516] = true,
    },
    [390] = {
        [6074] = true,
        [6149] = true,
    },
    [418] = {
        [6058] = true,
        [6158] = true,
        [6370] = true,
        [6572] = true,
    },
    [422] = {
        [6293] = true,
        [6404] = true,
    },
    [433] = {
        [6006] = true,
    },
    [525] = {
        [6868] = true,
        [6907] = true, -- Mor'dul Tower — no Discover toast/XP (user)
        [6983] = true, -- Iron Siegeworks — no Discover toast/XP (user)
        [7327] = true,
        [7493] = true, -- Iron Siegeworks (duplicate) — no Discover toast/XP (user)
        [7765] = true,
    },
    [534] = {
        [6723] = true,
        [7718] = true,
    },
    [535] = {
        [6959] = true,
        [6979] = true,
        [7115] = true,
        [7418] = true,
        [7421] = true,
        [7455] = true,
    },
    [539] = {
        [6787] = true,
        [6809] = true,
        [7078] = true,
        [7167] = true,
        [7250] = true, -- Umbrafen Point — no Discover toast/XP (user)
        [7324] = true,
        [7426] = true,
        [7706] = true,
    },
    [542] = {
        [6722] = true,
        [7034] = true,
        [7392] = true,
    },
    [543] = {
        [6878] = true,
        [6889] = true,
        [6900] = true,
        [6914] = true,
        [6915] = true,
        [6935] = true,
        [7298] = true,
        [7320] = true, -- Everbloom Wilds — no Discover toast/XP (user)
        [7394] = true,
    },
    [550] = {
        [7052] = true,
        [7059] = true,
        [7060] = true,
        [7071] = true,
        [7074] = true,
        [7094] = true,
        [7095] = true,
        [7139] = true,
        [7188] = true,
        [7204] = true,
        [7271] = true,
        [7367] = true,
        [7375] = true,
        [7386] = true,
        [7408] = true,
    },
    [630] = {
        [7334] = true,
        [7339] = true,
        [7947] = true,
        [8396] = true,
    },
    [634] = {
        [7541] = true,
    },
    [641] = {
        [7558] = true,
        [7682] = true,
        [8320] = true, -- Darkfollow's Spire — Warden Tower; not Explore Val'sharah
    },
    [650] = {
        [7503] = true,
        [8152] = true,
    },
    [680] = {
        [7637] = true,
        [7988] = true,
        [7990] = true,
        [8010] = true,
        [8150] = true,
        [8215] = true,
        [8352] = true,
        [8355] = true,
        [8382] = true,
        [8385] = true,
        [8431] = true,
        [8434] = true,
        [8441] = true,
        [8461] = true,
        [8471] = true,
        [8487] = true,
    },
    [862] = {
        [8499] = true,
        [8500] = true,
        [8690] = true,
        [8691] = true,
        [8693] = true,
        [8725] = true,
        [8922] = true,
        [8932] = true,
        [8945] = true,
        [8947] = true,
        [9008] = true,
        [9039] = true,
        [9041] = true,
        [9047] = true,
        [9048] = true,
        [9049] = true,
        [9179] = true,
        [9229] = true,
        [9435] = true,
        [9539] = true,
        [9543] = true,
        [9577] = true,
        [9795] = true,
        [9797] = true,
        [9935] = true,
        [9976] = true,
    },
    [863] = {
        [8500] = true,
        [9321] = true,
        [9976] = true,
    },
    [864] = {
        [8855] = true,
        [8856] = true,
        [8859] = true,
        [8862] = true,
        [8863] = true,
        [8866] = true,
        [8868] = true,
        [8871] = true,
        [8877] = true,
        [8930] = true,
        [8944] = true,
        [8959] = true,
        [8963] = true,
        [9133] = true,
        [9225] = true,
        [9266] = true,
        [9303] = true,
        [9312] = true,
        [9537] = true,
        [9542] = true,
        [9555] = true,
        [9563] = true,
        [9584] = true,
        [9585] = true,
        [9613] = true,
        [9646] = true,
        [9654] = true,
        [9656] = true,
        [9768] = true,
    },
    [895] = {
        [8716] = true,
        [11398] = true,
        [11417] = true,
    },
    [896] = {
        [8721] = true,
        [9177] = true,
    },
    [942] = {
        [9042] = true,
        [9770] = true,
    },
    [1161] = {
        [10017] = true,
    },
    [1462] = {
        [10290] = true,
    },
    [1525] = {
        [11438] = true,
        [11459] = true,
        [11474] = true,
        [12782] = true,
        [12815] = true,
        [12816] = true,
        [12817] = true,
    },
    [1527] = {
        [5613] = true,
        [5696] = true,
        [5701] = true,
        [12872] = true,
    },
    [1533] = {
        [10534] = true,
    },
    [2022] = {
        [13644] = true,
        [13714] = true,
    },
    [2023] = {
        [13748] = true,
        [13762] = true,
        [13763] = true,
        [13804] = true,
        [13918] = true,
        [14018] = true,
        [14105] = true,
        [14447] = true,
    },
    [2024] = {
        [13646] = true,
    },
    [2025] = {
        [13647] = true,
        [13799] = true,
        [13800] = true,
        [13881] = true,
    },
    [2133] = {
        [14683] = true,
        [14713] = true,
    },
    [2151] = {
        [14587] = true,
        [14592] = true,
        [14597] = true,
    },
    [2215] = {
        [14838] = true,
    },
    [2395] = {
        [16173] = true,
    },
    [2405] = {
        [15458] = true,
        [15958] = true,
    },
    [2413] = {
        [15355] = true,
        [15920] = true,
        [15922] = true,
        [15923] = true,
        [15926] = true,
        [15927] = true,
        [15929] = true,
        [15934] = true,
        [15937] = true,
        [16344] = true,
        [16346] = true,
        [16504] = true,
        [16530] = true,
    },
    [2424] = {
        [16215] = true,
        [16816] = true,
    },
}

function Filter:IsExcluded(name, explorationID, uiMapID)
    -- Gate 1 exclusion policy:
    -- 1) Legacy burned zone maps + stub/UNUSED names: always exclude
    -- 2) EXCLUDED_HARD_* (stuck / Entering-only / no toast / shared fog): always exclude
    -- 3) ATT Discover-XP allowlist: KEEP — overrides soft EXCLUDED_ON_MAP / EXCLUDED_IDS
    --    and name patterns (fixes "not Explore"-only over-filters like Darkspear Hold)
    -- 4) Soft EXCLUDED_ON_MAP / EXCLUDED_IDS: exclude when not ATT Discover-XP
    -- 5) Scenario / interior / instance / city name patterns
    -- Process: never put a proven toasting Discover-XP secondary in EXCLUDED_* without
    -- a hard-denial justification in the comment (stuck / Entering-only / no toast / etc.).

    if uiMapID and EXCLUDED_LEGACY_ZONE_MAPS[uiMapID] then
        return true
    end

    -- Eversong Sanctums / Maisara Deeps / Zul'Aman Depths / Sorrow Hill Crypt
    -- match name filters but grant discovery XP.
    if explorationID == 16051 or explorationID == 16058 or explorationID == 16199 or explorationID == 16348 or explorationID == 5427 then
        return false
    end

    -- Stub / UNUSED names before the XP short-circuit — AreaTable can still
    -- list retired tiles that should never become route pins.
    if name and name ~= "" then
        local lower = name:lower()
        if isStubName(name, lower) then
            return true
        end
    end

    if explorationID and EXCLUDED_HARD_IDS[explorationID] then
        return true
    end
    if uiMapID and EXCLUDED_HARD_ON_MAP[uiMapID] and explorationID and EXCLUDED_HARD_ON_MAP[uiMapID][explorationID] then
        return true
    end

    if explorationID and uiMapID and grantsDiscoveryXP(explorationID, uiMapID) == true then
        return false
    end

    if uiMapID and EXCLUDED_ON_MAP[uiMapID] and explorationID and EXCLUDED_ON_MAP[uiMapID][explorationID] then
        return true
    end
    if explorationID and EXCLUDED_IDS[explorationID] then
        return true
    end

    if explorationID and uiMapID and grantsDiscoveryXP(explorationID, uiMapID) == false then
        return true
    end
    if not name or name == "" then
        return false
    end

    local lower = name:lower()

    for i = 1, #SCENARIO_PATTERNS do
        if contains(lower, SCENARIO_PATTERNS[i]) then
            return true
        end
    end

    for i = 1, #INTERIOR_PATTERNS do
        if containsWord(lower, INTERIOR_PATTERNS[i]) then
            return true
        end
    end

    for i = 1, #INSTANCE_PATTERNS do
        if contains(lower, INSTANCE_PATTERNS[i]:lower()) then
            return true
        end
    end

    for i = 1, #CITY_PATTERNS do
        if contains(lower, CITY_PATTERNS[i]:lower()) then
            return true
        end
    end

    return false
end
