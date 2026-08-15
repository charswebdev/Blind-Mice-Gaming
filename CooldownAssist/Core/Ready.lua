--[[
  Cooldown Assist — /ca c ready query (works out of combat)
  Lua 5.1 only.
]]

CooldownAssist = CooldownAssist or {}
local CA = CooldownAssist

CA.Ready = CA.Ready or {}
local Ready = CA.Ready

local function Say(text)
    if CA.Speech and CA.Speech.Say then
        CA.Speech.Say(text, CA.Speech.PRIORITY_INFO)
    else
        print("|cff66ccff[Cooldown Assist]|r " .. tostring(text))
    end
end

--- Speak currently ready tracked spells (ignores combat-only gate).
function Ready.Announce()
    if CA.DB and CA.DB.IsMasterEnabled and not CA.DB.IsMasterEnabled() then
        Say("Cooldown Assist is disabled.")
        return
    end
    if not (CA.Spells and CA.Spells.GetReadyNames) then
        Say("Spell tracker not ready.")
        return
    end

    local names = CA.Spells.GetReadyNames() or {}
    if CA.Items and CA.Items.GetReadyNames then
        local itemNames = CA.Items.GetReadyNames() or {}
        for i = 1, #itemNames do
            names[#names + 1] = itemNames[i]
        end
        table.sort(names, function(a, b)
            return tostring(a):lower() < tostring(b):lower()
        end)
    end
    if type(names) ~= "table" or #names == 0 then
        Say("No tracked cooldowns are ready.")
        return
    end

    if #names == 1 then
        Say(names[1] .. " ready.")
        return
    end

    -- Keep speech manageable.
    local maxSpeak = 12
    local parts = {}
    local n = math.min(#names, maxSpeak)
    for i = 1, n do
        parts[#parts + 1] = names[i]
    end
    local text = table.concat(parts, ", ") .. " ready."
    if #names > maxSpeak then
        text = text .. " And " .. tostring(#names - maxSpeak) .. " more."
    end
    Say(text)

    if CA.DB and CA.DB.IsChatEchoEnabled and CA.DB.IsChatEchoEnabled() then
        print("|cff66ccff[Cooldown Assist]|r Ready (" .. tostring(#names) .. "): " .. table.concat(names, ", "))
    end
end
