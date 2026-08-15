local addonName, LPL = ...

LPL.Modules = {
    registry = {},
    activeID = nil,
    contentHost = nil,
}

function LPL.Modules:Register(module)
    assert(module.id, "Module requires an id")
    assert(module.create, "Module requires a create function")
    self.registry[module.id] = module
end

function LPL.Modules:GetSorted()
    local sorted = {}
    for _, module in pairs(self.registry) do
        sorted[#sorted + 1] = module
    end
    table.sort(sorted, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
    return sorted
end

function LPL.Modules:Get(moduleID)
    return self.registry[moduleID]
end

function LPL.Modules:SetContentHost(host)
    self.contentHost = host
end

local FALLBACK_TAB = "talents"

function LPL.Modules:Activate(moduleID)
    local module = self.registry[moduleID]
    if not module and moduleID == "notes" then
        moduleID = FALLBACK_TAB
        module = self.registry[moduleID]
    end
    if not module then
        moduleID = FALLBACK_TAB
        module = self.registry[moduleID]
    end
    if not module or not self.contentHost then
        return
    end

    if self.activeID and self.activeID ~= moduleID then
        local previous = self.registry[self.activeID]
        if previous and previous.OnHide then
            previous:OnHide()
        end
        if previous and previous.instance then
            previous.instance:Hide()
        end
    end

    if not module.instance then
        module.instance = module.create(self.contentHost)
        if module.instance then
            module.instance:SetAllPoints(self.contentHost)
        end
    end

    if module.instance then
        module.instance:Show()
    end

    if module.OnShow then
        if type(module.OnShow) == "function" then
            module.OnShow(module)
        end
    end

    if moduleID == "builds" and LPL.ImportExport and LPL.ImportExport.ApplyRequestedView then
        LPL.ImportExport:ApplyRequestedView()
    end

    self.activeID = moduleID
    LPL.DB:GetUI().lastTab = moduleID

    if LPL.Sidebar then
        LPL.Sidebar:RefreshActiveTab()
    end
end

function LPL.Modules:GetActiveID()
    return self.activeID
end
