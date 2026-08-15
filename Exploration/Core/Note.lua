local addon = Exploration

addon.note_active = false

local function ensureNoteDefaults()
    addon.data.note = addon.data.note or {}
    local note = addon.data.note
    if note.visible == nil then note.visible = true end
    note.anchor = note.anchor or "TOP"
    note.relative = note.relative or "TOP"
    note.x = note.x or 0
    note.y = note.y or -140
end

function addon:InitializeNoteFrame()
    ensureNoteDefaults()
    if addon.ui.NoteFrame then return addon.ui.NoteFrame end

    local frame = CreateFrame("Frame", "ExplorationNoteFrame", UIParent, "BackdropTemplate")
    frame:SetSize(220, 36)
    frame:SetPoint(
        addon.data.note.anchor,
        UIParent,
        addon.data.note.relative,
        addon.data.note.x,
        addon.data.note.y
    )
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local anchor, _, relative, x, y = self:GetPoint(1)
        addon.data.note.anchor = anchor
        addon.data.note.relative = relative
        addon.data.note.x = x
        addon.data.note.y = y
    end)

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.06, 0.06, 0.08, 0.92)
    frame:SetBackdropBorderColor(0.38, 0.32, 0.18, 0.85)

    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.label:SetPoint("CENTER", frame, "CENTER", 0, 0)
    frame.label:SetSpacing(4)
    frame.label:SetWidth(200)
    frame.label:SetWordWrap(true)

    frame:Hide()
    addon.ui.NoteFrame = frame
    return frame
end

function addon:RefreshNote()
    local noteFrame = addon.ui and addon.ui.NoteFrame
    if not noteFrame then return end
    local show = addon.active and addon.data.note.visible and addon.note_active
    noteFrame:SetShown(show)
end

function addon:UpdateNote(text)
    local noteFrame = addon.ui and addon.ui.NoteFrame
    if not noteFrame then return end

    text = text and text:gsub("\\n", "\n") or ""
    noteFrame.label:SetText(text)

    local w = math.min(320, math.max(120, noteFrame.label:GetStringWidth() + 24))
    local h = math.max(28, noteFrame.label:GetStringHeight() + 16)
    noteFrame:SetSize(w, h)

    addon:RefreshNote()
end

function addon:CollectWaypointActions(data)
    if not data then return nil end
    if data.actions then
        local out = {}
        for _, act in ipairs(data.actions) do
            if act and (act.macro or act.housingTeleport) then
                out[#out + 1] = act
            end
        end
        if #out > 0 then return out end
    end
    if data.action and (data.action.macro or data.action.housingTeleport) then
        return { data.action }
    end
    return nil
end

local function ensureNoteActionButton(noteFrame)
    if noteFrame.actionButton then
        return noteFrame.actionButton
    end
    -- Same themed secure button as the footer Use Charm / Exit Bench controls.
    local btn = addon:CreateSecureActionButton(noteFrame, 88, 22, "Exit Bench")
    btn:SetPoint("BOTTOM", noteFrame, "TOP", 0, 4)
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetFrameStrata(noteFrame:GetFrameStrata())
    btn:SetFrameLevel((noteFrame:GetFrameLevel() or 0) + 10)
    noteFrame.actionButton = btn
    return btn
end

local function configureNoteActionButton(btn, act)
    if not btn or not act then return end
    local label = act.label or "Use"
    btn:SetText(label)
    btn:SetWidth(math.min(180, math.max(72, btn:GetTextWidth() + 16)))
    if act.housingTeleport then
        local ready = addon.ConfigureHousingTeleportButton and addon:ConfigureHousingTeleportButton(btn)
        if not ready and addon.ConfigureHousingTeleportButton then
            btn:SetScript("PreClick", function()
                addon:ConfigureHousingTeleportButton(btn)
            end)
        else
            btn:SetScript("PreClick", nil)
        end
    else
        if addon.ClearHousingTeleportButton then
            addon:ClearHousingTeleportButton(btn)
        end
        btn:SetScript("PreClick", nil)
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", act.macro)
    end
    btn:Enable()
    btn:Show()
end

function addon:UpdateNoteAction(actions)
    if actions and actions.macro then
        actions = { actions }
    end
    actions = actions or {}

    -- Footer action bar (same slot / style as Use Lucky Tortollan Charm).
    local seg = addon.ui and addon.ui.SegmentFrame
    if seg and seg.UpdateFooterAction then
        seg:UpdateFooterAction(actions)
        if seg.LayoutFooterButtons then
            seg:LayoutFooterButtons()
        end
    elseif addon.SyncActionKeybindButtons then
        -- Segment UI not built yet — still sync keybind secure buttons.
        addon:SyncActionKeybindButtons(actions)
    end

    -- Floating note action (Dystinct placement: above the note), Exploration button style.
    local noteFrame = addon.ui and addon.ui.NoteFrame
    if not noteFrame then return end
    local act = actions[1]
    local showOnNote = act and addon.active and addon.note_active and addon.data.note and addon.data.note.visible
    if showOnNote then
        local btn = ensureNoteActionButton(noteFrame)
        configureNoteActionButton(btn, act)
    elseif noteFrame.actionButton then
        noteFrame.actionButton:Hide()
        noteFrame.actionButton:SetAttribute("type", nil)
        noteFrame.actionButton:SetAttribute("macrotext", nil)
    end
end

function addon:UpdateWaypointNote()
    addon:InitializeNoteFrame()

    if not addon.active or not addon.waypoint.index or not addon.segment.route then
        addon.note_active = false
        addon:UpdateNote(nil)
        addon:UpdateNoteAction(nil)
        if addon.ui.NoteFrame then addon.ui.NoteFrame:Hide() end
        return
    end

    local wp = addon.segment.route[addon.waypoint.index]
    local data = wp and wp.data
    if not data then
        addon.note_active = false
        addon:UpdateNoteAction(nil)
        if addon.ui.NoteFrame then addon.ui.NoteFrame:Hide() end
        return
    end

    local note = data.note
    local actions = addon:CollectWaypointActions(data)
    if actions and addon.RequestOwnedHouses then
        for _, act in ipairs(actions) do
            if act.housingTeleport then
                addon:RequestOwnedHouses()
                break
            end
        end
    end
    addon.note_active = note and note ~= ""

    if addon.note_active then
        addon:UpdateNote(note)
    elseif addon.ui.NoteFrame then
        addon.ui.NoteFrame:Hide()
    end

    addon:UpdateNoteAction(actions)
end
