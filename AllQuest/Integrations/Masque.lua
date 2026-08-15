--[[
  AllQuest — optional Masque skinning for quest item buttons
  Lua 5.1 only.
]]

AllQuest = AllQuest or {}
local AQ = AllQuest

AQ:RegisterPlugin({
    id = "Masque",
    kind = "integration",
    optionalAddon = "Masque",
    onEnable = function()
        local MSQ = LibStub and LibStub("Masque", true)
        if not MSQ then
            return
        end
        local group = MSQ:Group("AllQuest", "Quest Items")
        AQ.MasqueGroup = group
        if AQ.Items and AQ.Items.SkinWithMasque then
            AQ.Items.SkinWithMasque()
        end
        AQ:Print("Masque: AllQuest / Quest Items group is active.")
    end,
    onDisable = function()
        if AQ.Items and AQ.Items.UnskinMasque then
            AQ.Items.UnskinMasque()
        end
        AQ.MasqueGroup = nil
    end,
})
