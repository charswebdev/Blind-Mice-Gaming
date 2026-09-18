local addonName, LPL = ...

LPL.TalentSandbox = {}

local SandboxMeta = {}
SandboxMeta.__index = SandboxMeta

local function NormalizeNodeID(nodeID)
    if type(nodeID) == "number" then
        return nodeID
    end
    if type(nodeID) == "string" then
        return tonumber(nodeID)
    end
    return nil
end

local function NormalizeNodeValue(value)
    if type(value) == "number" then
        if value > 0 then
            return value, nil
        end
        return nil, nil
    end
    if type(value) == "table" then
        local rank = value.rank or value.ranks or value[1]
        local entryID = value.entryID or value.entryId
        rank = tonumber(rank)
        entryID = entryID and tonumber(entryID) or nil
        if rank and rank > 0 then
            return rank, entryID
        end
    end
    return nil, nil
end

function LPL.TalentSandbox:New()
    local sandbox = setmetatable({
        nodes = {},
        entries = {},
    }, SandboxMeta)
    return sandbox
end

function SandboxMeta:Clear()
    wipe(self.nodes)
    wipe(self.entries)
end

function SandboxMeta:IsEmpty()
    return not next(self.nodes)
end

function SandboxMeta:GetNodeRank(nodeID)
    nodeID = NormalizeNodeID(nodeID)
    if not nodeID then
        return 0
    end
    return self.nodes[nodeID] or 0
end

function SandboxMeta:GetNodeEntryID(nodeID)
    nodeID = NormalizeNodeID(nodeID)
    if not nodeID then
        return nil
    end
    return self.entries[nodeID]
end

function SandboxMeta:SetNodeRank(nodeID, rank, entryID)
    nodeID = NormalizeNodeID(nodeID)
    if not nodeID then
        return
    end

    rank = tonumber(rank) or 0
    if rank > 0 then
        self.nodes[nodeID] = rank
        if entryID then
            self.entries[nodeID] = tonumber(entryID) or entryID
        end
    else
        self.nodes[nodeID] = nil
        self.entries[nodeID] = nil
    end
end

function SandboxMeta:GetSelections()
    local nodes = {}
    local entries = {}
    for nodeID, rank in pairs(self.nodes) do
        nodes[nodeID] = rank
        if self.entries[nodeID] then
            entries[nodeID] = self.entries[nodeID]
        end
    end
    return nodes, entries
end

function SandboxMeta:LoadFromBuild(build)
    self:Clear()
    if not build or type(build.nodes) ~= "table" then
        return
    end

    for rawNodeID, value in pairs(build.nodes) do
        local nodeID = NormalizeNodeID(rawNodeID)
        local rank, entryID = NormalizeNodeValue(value)
        if nodeID and rank then
            self.nodes[nodeID] = rank
            if entryID then
                self.entries[nodeID] = entryID
            elseif type(value) == "table" and value.entryID then
                self.entries[nodeID] = NormalizeNodeID(value.entryID) or value.entryID
            end
        end
    end

    if type(build.entries) == "table" then
        for rawNodeID, entryID in pairs(build.entries) do
            local nodeID = NormalizeNodeID(rawNodeID)
            if nodeID and self.nodes[nodeID] then
                self.entries[nodeID] = tonumber(entryID) or entryID
            end
        end
    end
end

function SandboxMeta:ExportToBuildNodes()
    local nodes = {}
    for nodeID, rank in pairs(self.nodes) do
        local key = tostring(nodeID)
        local entryID = self.entries[nodeID]
        if entryID then
            nodes[key] = {
                rank = rank,
                entryID = entryID,
            }
        else
            nodes[key] = rank
        end
    end
    return nodes
end

function SandboxMeta:SetSelection(nodeID, entryID)
    if entryID then
        self:SetNodeRank(nodeID, 1, entryID)
    else
        self:SetNodeRank(nodeID, 0)
    end
end

function SandboxMeta:ClearNode(nodeID)
    self:SetNodeRank(nodeID, 0)
end

function SandboxMeta:CountPurchasedRanks()
    local total = 0
    for _, rank in pairs(self.nodes) do
        total = total + rank
    end
    return total
end

function SandboxMeta:GetSpentSummary(classID, specID, subTreeID, level)
    return LPL.TalentTree:GetPointSummary(classID, specID, subTreeID, level, self)
end

function SandboxMeta:CountPurchasedNodes()
    local count = 0
    for _ in pairs(self.nodes) do
        count = count + 1
    end
    return count
end
