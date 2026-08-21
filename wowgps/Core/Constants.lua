local _, ns = ...

ns.Constants = {
    WINDOW = {
        WIDTH = 400,
        HEIGHT = 440,
        MIN_WIDTH = 360,
        MIN_HEIGHT = 380,
        MAX_WIDTH = 720,
        MAX_HEIGHT = 800,
    },

    STEP_COMPLETE_YARDS = 25,

    DEST_TYPES = {
        ZONE = "zone",
        NPC = "npc",
        DUNGEON = "dungeon",
        RAID = "raid",
        DELVE = "delve",
        CAVE = "cave",
        COORD = "coord",
        CUSTOM = "custom",
    },

    TAGS = {
        "Farm",
        "Quest",
        "Rare",
        "Delve entrance",
        "Dungeon entrance",
        "Raid entrance",
        "Scenario entrance",
        "Cave entrance",
        "Covenant Sanctum",
        "NPC",
        "Elite",
        "Hunter pet",
        "Battle Pet",
        "Transmog",
        "Toys",
        "Mount",
        "Glyphs",
        "Treasures",
        "Ritual Sites",
        "Decor",
        "Trainers",
        "Services",
        "Travel point",
        "Vendor",
        "Other",
    },

    TAG_SEPARATOR = ";",

    PHASE_MODES = {
        AUTO = "auto",
        RETAIL = "retail",
        CHROMIE = "chromie",
    },

    MAP_PIN_CLICK = {
        OFF = "off",
        SHIFT = "shift",
        ALWAYS = "always",
    },
}
