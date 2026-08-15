local addon = Exploration

local taxiFrame = nil

local function normalizeTaxiName(name)
    name = tostring(name or ""):lower()
    name = name:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return name
end

local function taxiBaseName(name)
    local base = name:match("^([^,]+)") or name
    return base:gsub("%s+$", "")
end

--- Score how well a taxi node name matches the desired destination (0 = none).
local function matchScore(nodeName, dest)
    local n = normalizeTaxiName(nodeName)
    local d = normalizeTaxiName(dest)
    if n == "" or d == "" then return 0 end
    if n == d then return 4 end

    local nBase = taxiBaseName(n)
    local dBase = taxiBaseName(d)
    if nBase == dBase then return 4 end
    if nBase:sub(1, #dBase) == dBase or dBase:sub(1, #nBase) == nBase then return 3 end
    if n:find(d, 1, true) or d:find(nBase, 1, true) then return 2 end
    if nBase:find(dBase, 1, true) or dBase:find(nBase, 1, true) then return 1 end
    return 0
end

function addon:GetActiveTaxiDest()
    if not addon.active or not addon.waypoint.index or not addon.segment.route then
        return nil
    end
    local wp = addon.segment.route[addon.waypoint.index]
    local data = wp and wp.data
    if not data or data.discovered then return nil end

    if type(data.taxiDest) == "string" and data.taxiDest ~= "" then
        return data.taxiDest
    end

    local trigger = data.trigger
    if trigger then
        if type(trigger.taxiDest) == "string" and trigger.taxiDest ~= "" then
            return trigger.taxiDest
        end
        if trigger.type == "taxi" and type(trigger.dest) == "string" and trigger.dest ~= "" then
            return trigger.dest
        end
    end

    if data.action and type(data.action.taxiDest) == "string" and data.action.taxiDest ~= "" then
        return data.action.taxiDest
    end
    if data.actions then
        for _, act in ipairs(data.actions) do
            if act and type(act.taxiDest) == "string" and act.taxiDest ~= "" then
                return act.taxiDest
            end
        end
    end

    return nil
end

function addon:IsAutoTaxiEnabled()
    local settings = addon.data and addon.data.settings
    if not settings then return true end
    if settings.autoTaxi == nil then return true end
    return settings.autoTaxi and true or false
end

local function findBestTaxiNode(dest)
    if not dest or not NumTaxiNodes then return nil, nil end

    local bestIndex, bestName, bestScore, bestHops = nil, nil, 0, nil
    local num = NumTaxiNodes() or 0
    for i = 1, num do
        local nodeType = TaxiNodeGetType and TaxiNodeGetType(i)
        if nodeType == "REACHABLE" then
            local nodeName = TaxiNodeName and TaxiNodeName(i)
            local score = matchScore(nodeName, dest)
            if score > 0 then
                local hops = (GetNumRoutes and GetNumRoutes(i)) or 99
                if score > bestScore
                    or (score == bestScore and hops < (bestHops or 99))
                    or (score == bestScore and hops == bestHops and (not bestIndex or i < bestIndex))
                then
                    bestIndex, bestName, bestScore, bestHops = i, nodeName, score, hops
                end
            end
        end
    end
    return bestIndex, bestName
end

local function tryTakeActiveTaxi()
    if not addon.active or not addon:IsAutoTaxiEnabled() then return end
    if UnitOnTaxi and UnitOnTaxi("player") then return end

    local dest = addon:GetActiveTaxiDest()
    if not dest then return end

    local index, nodeName = findBestTaxiNode(dest)
    if not index then return end

    local ok = pcall(TakeTaxiNode, index)
    if ok then
        print("|cff00ccffExploration:|r Taking flight to |cff3dff7e" .. (nodeName or dest) .. "|r.")
    end
end

local function OnTaxiEvent(_, event)
    if event ~= "TAXIMAP_OPENED" then return end
    -- Nodes are not always ready on the same frame the map opens.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, tryTakeActiveTaxi)
        C_Timer.After(0.15, tryTakeActiveTaxi)
    else
        tryTakeActiveTaxi()
    end
end

function addon:RegisterTaxiEvents()
    if taxiFrame then return end
    taxiFrame = CreateFrame("Frame")
    taxiFrame:RegisterEvent("TAXIMAP_OPENED")
    taxiFrame:SetScript("OnEvent", OnTaxiEvent)
end
