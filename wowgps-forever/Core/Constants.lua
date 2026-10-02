local _, GPS = ...

GPS.VERSION = "1.1.2"

_G.BINDING_HEADER_WOWGPS = "WOWGPS"
_G.BINDING_NAME_TOGGLE_WOWGPS = "Toggle WowGPS"
GPS.TITLE = "WowGPS"
GPS.ICON = "Interface\\AddOns\\wowgps-forever\\Media\\WowGPS.png"
GPS.SAVED = "WowGPSForeverDB"

GPS.WINDOW = {
    WIDTH = 400,
    HEIGHT = 440,
    MIN_WIDTH = 360,
    MIN_HEIGHT = 380,
    MAX_WIDTH = 720,
    MAX_HEIGHT = 800,
}

GPS.LATER = {
    destinations = "Destinations are not in this version yet.",
    save = "Saving a personal location is not in this version yet.",
    import = "Import is not in this version yet.",
    position = "Your position is not in this version yet.",
}
