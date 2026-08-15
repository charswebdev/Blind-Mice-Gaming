local addon = Exploration

local L = addon.uiLayout
local frame = addon.ui.RoutesFrame
local MEGA = "Exploration Mega-Journey"

function frame:Initialize()
    if frame._built then return end
    frame._built = true

    frame.context = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.context:SetPoint("TOPLEFT", frame, "TOPLEFT", L.pad, -4)
    frame.context:SetText("Mega-Journey segments")
    addon:StyleFont(frame.context, "accent")

    addon:HRule(frame, -L.contextH, L.pad)

    frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetFrameLevel(frame:GetFrameLevel() + 2)
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", L.pad, -(L.contextH + 4))
    frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -L.pad - 16, L.pad)
    frame.content = CreateFrame("Frame", nil, frame.scroll)
    frame.scroll:SetScrollChild(frame.content)
    frame.rows = {}
    frame:Refresh()
end

function frame:Refresh()
    if not frame._built then
        frame:Initialize()
    end
    if not frame.rows or not frame.content then
        return
    end
    local root = addon.menu[MEGA]
    local leaves = root and addon:GetAllLeaves(root) or {}
    for i, leaf in ipairs(leaves) do
        frame:UpdateRow(i, leaf)
    end
    if #leaves < #frame.rows then
        for i = #leaves + 1, #frame.rows do frame.rows[i]:Hide() end
    end
    frame.content:SetSize(L.contentWidth, math.max(1, #leaves) * 26)
end

function frame:UpdateRow(index, leaf)
    if not frame.rows then
        frame.rows = {}
    end
    if not frame.content then
        return
    end
    if #frame.rows < index then
        local row = addon:CreateRow(frame.content, L.contentWidth, 24)
        row:SetPoint("TOPLEFT", frame.content, "TOPLEFT", 0, -(index - 1) * 26)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
        row.count = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.count:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row:EnableMouse(false)
        frame.rows[index] = row
    end
    local section = leaf.path[#leaf.path]
    local route = addon.data.routes[section]
    local count = route and route.route and #route.route or 0
    frame.rows[index].label:SetText(addon:LocalizedString(route and route.display or section))
    addon:StyleFont(frame.rows[index].label, "text")
    frame.rows[index].count:SetText(count .. " stops")
    addon:StyleFont(frame.rows[index].count, "dim")
    frame.rows[index]:Show()
end
