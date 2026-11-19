local ADDON, G = ...

local frame
local rows = {}
local selected = "herbs"
local kindPage, voicePage, settingsPage, profilePage
local filling
local SaveLook

local function Font(parent, layer, template)
    local text = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
    return text
end

local function GoldButton(parent, label, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 110, 22)
    button:SetText(label)
    return button
end

local function IsChecked(box)
    local value = box:GetChecked()
    return value == true or value == 1
end

local function Check(parent, label)
    local box = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    box:SetSize(26, 26)
    local text = Font(box, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 0)
    text:SetText(label)
    box.label = text
    return box
end

local sliderCount = 0

local function Slider(parent, label, minValue, maxValue)
    sliderCount = sliderCount + 1
    local column = CreateFrame("Frame", nil, parent)
    column:SetSize(156, 78)
    local slider = CreateFrame("Slider", "BMGSparkleGuideSlider" .. sliderCount, column, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    slider:SetWidth(140)
    slider:SetPoint("TOP", 0, -16)
    local named = _G["BMGSparkleGuideSlider" .. sliderCount .. "Text"]
    if named then
        named:SetText("")
        named:Hide()
    end
    local oldLow = slider.Low or _G["BMGSparkleGuideSlider" .. sliderCount .. "Low"]
    local oldHigh = slider.High or _G["BMGSparkleGuideSlider" .. sliderCount .. "High"]
    if oldLow then
        oldLow:SetText("")
        oldLow:Hide()
    end
    if oldHigh then
        oldHigh:SetText("")
        oldHigh:Hide()
    end
    local text = Font(column, "OVERLAY", "GameFontNormal")
    text:SetPoint("BOTTOM", slider, "TOP", 0, 2)
    text:SetText(label)
    slider.caption = text
    slider.captionText = label
    local low = Font(column, "OVERLAY", "GameFontHighlightSmall")
    low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -1)
    low:SetText(tostring(minValue))
    local high = Font(column, "OVERLAY", "GameFontHighlightSmall")
    high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -1)
    high:SetText(tostring(maxValue))
    local box = CreateFrame("EditBox", nil, column, "InputBoxTemplate")
    box:SetSize(56, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(5)
    box:SetFontObject(GameFontHighlightSmall)
    box:SetJustifyH("CENTER")
    box:SetPoint("TOP", slider, "BOTTOM", 0, -16)
    slider.box = box
    slider.column = column
    slider.minValue = minValue
    slider.maxValue = maxValue
    return slider
end

local function HookSlider(slider, field)
    local function commit(box)
        local number = tonumber(box:GetText())
        if not number then
            box:SetText(tostring(math.floor(slider:GetValue() + 0.5)))
            return
        end
        number = math.floor(number + 0.5)
        if number < slider.minValue then
            number = slider.minValue
        end
        if number > slider.maxValue then
            number = slider.maxValue
        end
        box:SetText(tostring(number))
        slider:SetValue(number)
    end
    slider:SetScript("OnValueChanged", function(self, value)
        local number = math.floor(value + 0.5)
        if self.box and not self.box:HasFocus() then
            self.box:SetText(tostring(number))
        end
        SaveLook(field, number)
    end)
    slider.box:SetScript("OnEnterPressed", function(self)
        commit(self)
        self:ClearFocus()
    end)
    slider.box:SetScript("OnEditFocusLost", function(self)
        commit(self)
    end)
    slider.box:SetScript("OnEscapePressed", function(self)
        self:SetText(tostring(math.floor(slider:GetValue() + 0.5)))
        self:ClearFocus()
    end)
end

local function PaintSwatch(button, color, on)
    button:SetBackdropColor(color.r1, color.g1, color.b1, 1)
    if on then
        button:SetBackdropBorderColor(1, 0.82, 0, 1)
    else
        button:SetBackdropBorderColor(0.35, 0.3, 0.18, 1)
    end
end

local function SetBox(slider, number)
    if slider.box and not slider.box:HasFocus() then
        slider.box:SetText(tostring(number))
    end
end

local function SyncSteps()
    local was = filling
    filling = true
    local pages = { kindPage, voicePage }
    for _, page in ipairs(pages) do
        if page and page.steps then
            for step, box in pairs(page.steps) do
                box:SetChecked(G.db.steps[step] == true)
            end
        end
    end
    filling = was
end

local PREVIEW_FOV = 0.6
local PREVIEW_PITCH = 0.35

local function MovePreviewPlate(scene)
    local plate = scene.plate
    if not plate then
        return
    end
    local height = scene:GetHeight()
    if not height or height < 40 then
        height = 300
    end
    local tall = scene.tall or 1
    local distance = (scene.distance or 4) * (scene.zoom or 1.5)
    local focal = height / 2 / math.tan(PREVIEW_FOV / 2)
    local up = tall / 2
    local depth = distance - up * math.sin(PREVIEW_PITCH)
    if depth < 0.2 then
        depth = 0.2
    end
    local pixels = up * math.cos(PREVIEW_PITCH) * focal / depth
    if pixels < 20 then
        pixels = 20
    end
    if pixels > height * 0.28 then
        pixels = height * 0.28
    end
    plate:ClearAllPoints()
    plate:SetPoint("BOTTOM", scene, "CENTER", 0, pixels)
end

local function PlacePreviewCamera(scene)
    local distance = (scene.distance or 4) * (scene.zoom or 1.5)
    local ok, fx, fy, fz = pcall(scene.GetCameraForward, scene)
    if not ok or G.Secret(fx) or not fx then
        pcall(scene.SetCameraPosition, scene, 0, -distance, distance * 0.4)
    else
        pcall(scene.SetCameraPosition, scene, -fx * distance, -fy * distance, -fz * distance)
    end
    MovePreviewPlate(scene)
end

local function FramePreview(scene, actor)
    if actor.IsLoaded then
        local ready, loaded = pcall(actor.IsLoaded, actor)
        if ready and not loaded then
            return false
        end
    end
    local ok, x1, y1, z1, x2, y2, z2 = pcall(actor.GetActiveBoundingBox, actor)
    if not ok then
        return false
    end
    x1, y1, z1 = G.PlainNumber(x1), G.PlainNumber(y1), G.PlainNumber(z1)
    x2, y2, z2 = G.PlainNumber(x2), G.PlainNumber(y2), G.PlainNumber(z2)
    if not x1 or not y1 or not z1 or not x2 or not y2 or not z2 then
        return false
    end
    local tall = z2 - z1
    local across = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    if tall < 0.08 and across < 0.08 then
        return false
    end
    local span = math.max(tall, across, 0.35)
    scene.tall = tall
    scene.distance = span / math.tan(PREVIEW_FOV / 2) * 1.65
    PlacePreviewCamera(scene)
    return true
end

local function SetModel(kind)
    local scene = kindPage and kindPage.preview and kindPage.preview.scene
    local actor = scene and scene.actor
    if not scene or not actor then
        return
    end
    local info = G.KindInfo(kind)
    if not info.model or info.model == 0 then
        scene:Hide()
        if scene.plate then
            scene.plate:ClearAllPoints()
            scene.plate:SetPoint("BOTTOM", scene.plate:GetParent(), "CENTER", 0, 28)
        end
        return
    end
    scene:Show()
    if scene.file ~= info.model then
        scene.file = info.model
        scene.framed = false
        local ok = pcall(actor.SetModelByFileID, actor, info.model)
        if not ok then
            scene:Hide()
            return
        end
        pcall(actor.SetUseCenterForOrigin, actor, true, true, true)
        pcall(actor.SetYaw, actor, scene.yaw or 0)
    end
end

local function PreviewLook(look, clip)
    local size = look.size or 100
    local height = clip and clip:GetHeight() or 0
    if height < 40 then
        height = 260
    end
    local fit = (height * 1.05) / (4.5 * size)
    if fit > 1.2 then
        fit = 1.2
    end
    if fit < 0.85 then
        fit = 0.85
    end
    return {
        style = look.style,
        color = look.color,
        size = math.floor(size * fit + 0.5),
        height = math.floor((look.height or -24) * fit + 0.5),
        brightness = look.brightness or 100,
        count = look.count or 8,
    }
end

local function ShowPreview(kind)
    local preview = kindPage.preview
    local scene = preview.scene
    local spot = preview.clip or scene
    local host = G.PreviewHost(spot)
    local look = G.db.look[kind]
    local shown = PreviewLook(look, spot)
    local plate = preview.plate or spot
    G.PlaceOnPlate(host, shown, plate, shown.height)
    host:SetFrameLevel((scene and scene:GetFrameLevel() or spot:GetFrameLevel()) + 20)
    SetModel(kind)
    kindPage.sample:SetText(G.KindInfo(kind).label)
    if kindPage.styles then
        for _, tile in ipairs(kindPage.styles) do
            G.ApplySpark(tile.host, {
                style = tile.styleKey,
                color = look.color,
                size = 46,
                height = 0,
                brightness = look.brightness or 100,
                count = look.count or 8,
            }, tile.clip, "BOTTOM", "BOTTOM", 0, 4)
            if tile.styleKey == look.style then
                tile:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                tile:SetBackdropBorderColor(0.28, 0.24, 0.14, 1)
            end
        end
    end
end

local function ShowTrack(kind)
    if not kindPage.trackBoxes then
        return
    end
    local count = 0
    for _, box in ipairs(kindPage.trackBoxes) do
        if box.kind == kind then
            box:Show()
            local saved = G.db.track[kind]
            local on = not saved or saved[box.nodeKey] ~= false
            box:SetChecked(on)
            count = count + 1
        else
            box:Hide()
        end
    end
    local rows = math.ceil(count / 2)
    kindPage.trackChild:SetHeight(math.max(rows * 26, 26))
    local named = count > 0
    kindPage.trackLabel:SetShown(named)
    kindPage.scroll:SetShown(named)
    kindPage.trackAll:SetShown(named)
    kindPage.trackNone:SetShown(named)
    if named then
        kindPage.trackNote:Hide()
    else
        kindPage.trackNote:Show()
        local notes = {
            quests = "This page tracks every quest object while the box above is on.",
            bobber = "This page tracks your fishing bobber while the box above is on.",
            loot = "This page tracks every corpse that still has loot while the box above is on.",
            skinning = "This page tracks every corpse you can skin while the box above is on.",
            others = "This page tracks every other object you can use while the box above is on.",
        }
        kindPage.trackNote:SetText(notes[kind] or "This page tracks this whole group while the box above is on.")
    end
end

local function RefreshKind()
    local look = G.db.look[selected]
    filling = true
    kindPage.enabled:SetChecked(G.db.enabled[selected] == true)
    kindPage.enabled.label:SetText(G.KindInfo(selected).blurb)
    kindPage.title:SetText(G.KindInfo(selected).label)
    for _, button in ipairs(kindPage.colors) do
        PaintSwatch(button, G.ColorByKey(button.colorKey), button.colorKey == look.color)
    end
    kindPage.size:SetValue(look.size or 100)
    kindPage.height:SetValue(look.height or -24)
    kindPage.count:SetValue(look.count or 8)
    kindPage.bright:SetValue(look.brightness or 100)
    SetBox(kindPage.size, look.size or 100)
    SetBox(kindPage.height, look.height or -24)
    SetBox(kindPage.count, look.count or 8)
    SetBox(kindPage.bright, look.brightness or 100)
    ShowTrack(selected)
    filling = false
    SyncSteps()
    ShowPreview(selected)
    if G.Refresh then
        G.Refresh()
    end
end

function SaveLook(field, value)
    if filling then
        return
    end
    G.db.look[selected][field] = value
    RefreshKind()
end

local function Select(key)
    selected = key
    for _, row in ipairs(rows) do
        if row.key == key then
            row.highlight:Show()
            row.label:SetTextColor(1, 0.82, 0)
        else
            row.highlight:Hide()
            row.label:SetTextColor(1, 0.9, 0.7)
        end
    end
    kindPage:Hide()
    voicePage:Hide()
    settingsPage:Hide()
    profilePage:Hide()
    if key == "voice" then
        voicePage:Show()
    elseif key == "settings" then
        settingsPage:Show()
    elseif key == "profile" then
        profilePage:Show()
    else
        kindPage:Show()
        RefreshKind()
    end
end

local function BuildPreview(parent)
    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    preview:SetSize(360, 260)
    preview:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    preview:SetBackdropColor(0.05, 0.04, 0.03, 1)
    local clip = CreateFrame("Frame", nil, preview)
    clip:SetPoint("TOPLEFT", 6, -6)
    clip:SetPoint("BOTTOMRIGHT", -6, 6)
    clip:SetClipsChildren(true)
    local background = clip:CreateTexture(nil, "BACKGROUND")
    background:SetTexture("Interface\\PetBattles\\MountJournal-BG")
    background:SetTexCoord(0.01, 0.78, 0.01, 0.99)
    background:SetAllPoints()
    background:SetDesaturated(true)
    background:SetVertexColor(0.45, 0.36, 0.2)
    preview.clip = clip
    local plate = CreateFrame("Frame", nil, clip)
    plate:SetSize(2, 2)
    plate:SetPoint("BOTTOM", clip, "CENTER", 0, 28)
    preview.plate = plate
    local scene = CreateFrame("ModelScene", nil, clip)
    scene:SetAllPoints()
    scene.zoom = 1.5
    scene.plate = plate
    scene.yaw = 0.4
    scene.distance = 4
    local actor
    local ready = pcall(function()
        scene:SetCameraFieldOfView(PREVIEW_FOV)
        scene:SetCameraOrientationByYawPitchRoll(math.pi, PREVIEW_PITCH, 0)
        actor = scene:CreateActor()
        actor:SetUseCenterForOrigin(true, true, true)
        if scene.SetLightVisible then
            scene:SetLightVisible(true)
        end
    end)
    if ready and actor then
        scene.actor = actor
        scene:EnableMouse(true)
        scene:EnableMouseWheel(true)
        scene:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" then
                self.dragging = true
                self.dragX = select(1, GetCursorPosition())
            end
        end)
        scene:SetScript("OnMouseUp", function(self)
            self.dragging = nil
        end)
        scene:SetScript("OnMouseWheel", function(self, delta)
            self.zoom = math.max(0.45, math.min(2.4, (self.zoom or 1.5) - delta * 0.12))
            PlacePreviewCamera(self)
        end)
        scene:SetScript("OnUpdate", function(self)
            if self.dragging and self.actor then
                local x = select(1, GetCursorPosition())
                self.yaw = (self.yaw or 0) + (x - (self.dragX or x)) * 0.01
                self.dragX = x
                pcall(self.actor.SetYaw, self.actor, self.yaw)
            end
            if not self.framed and self.actor and FramePreview(self, self.actor) then
                self.framed = true
            end
        end)
        PlacePreviewCamera(scene)
    else
        scene:Hide()
    end
    preview.scene = scene
    local caption = CreateFrame("Frame", nil, preview)
    caption:SetPoint("BOTTOMLEFT", 8, 6)
    caption:SetPoint("BOTTOMRIGHT", -8, 6)
    caption:SetHeight(22)
    caption:SetFrameLevel(preview:GetFrameLevel() + 40)
    local sample = Font(caption, "OVERLAY", "GameFontNormalLarge")
    sample:SetPoint("BOTTOM", 0, 0)
    return preview, sample
end

local function BuildKind(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    page.title = Font(page, "OVERLAY", "GameFontNormalLarge")
    page.title:SetPoint("TOPLEFT", 8, -8)
    page.enabled = Check(page, "Sparkles on herbs")
    page.enabled:SetPoint("TOPLEFT", page.title, "BOTTOMLEFT", -4, -6)
    page.enabled:SetScript("OnClick", function(self)
        if filling then
            return
        end
        G.db.enabled[selected] = IsChecked(self)
        G.ApplyInteract()
        G.Refresh()
    end)
    page.announce = Font(page, "OVERLAY", "GameFontNormal")
    page.announce:SetPoint("TOPLEFT", page.enabled, "BOTTOMLEFT", 4, -6)
    page.announce:SetText("Announce at")
    page.steps = {}
    local stepList = {
        { key = "20", label = "20 yards" },
        { key = "15", label = "15 yards" },
        { key = "10", label = "10 yards" },
        { key = "5", label = "5 yards" },
        { key = "at", label = "At" },
    }
    for index, step in ipairs(stepList) do
        local box = Check(page, step.label)
        box:SetPoint("TOPLEFT", page.announce, "BOTTOMLEFT", (index - 1) * 124, -2)
        box.step = step.key
        box:SetScript("OnClick", function(self)
            if filling then
                return
            end
            G.db.steps[self.step] = IsChecked(self)
            SyncSteps()
        end)
        page.steps[step.key] = box
    end
    page.preview, page.sample = BuildPreview(page)
    page.preview:SetPoint("TOPLEFT", page.announce, "BOTTOMLEFT", 0, -36)
    page.styles = {}
    for index, style in ipairs(G.STYLES) do
        local tile = CreateFrame("Button", nil, page, "BackdropTemplate")
        tile:SetSize(122, 78)
        tile:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        tile:SetBackdropColor(0.04, 0.03, 0.02, 1)
        tile:SetBackdropBorderColor(0.28, 0.24, 0.14, 1)
        if index == 1 then
            tile:SetPoint("TOPLEFT", page.preview, "BOTTOMLEFT", 0, -8)
        else
            tile:SetPoint("LEFT", page.styles[index - 1], "RIGHT", 6, 0)
        end
        local clip = CreateFrame("Frame", nil, tile)
        clip:SetPoint("TOPLEFT", 3, -3)
        clip:SetPoint("BOTTOMRIGHT", -3, 16)
        clip:SetClipsChildren(true)
        tile.clip = clip
        tile.host = G.SampleHost(clip)
        tile.styleKey = style.key
        tile.label = Font(tile, "OVERLAY", "GameFontHighlightSmall")
        tile.label:SetPoint("BOTTOM", 0, 3)
        tile.label:SetText(style.label)
        tile:SetScript("OnClick", function(self)
            SaveLook("style", self.styleKey)
        end)
        page.styles[index] = tile
    end
    page.colors = {}
    for index, color in ipairs(G.COLORS) do
        local button = CreateFrame("Button", nil, page, "BackdropTemplate")
        button:SetSize(28, 28)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 2,
        })
        local caption = Font(button, "OVERLAY", "GameFontHighlightSmall")
        caption:SetPoint("LEFT", button, "RIGHT", 4, 0)
        caption:SetText(color.label)
        local column = (index - 1) % 4
        local row = math.floor((index - 1) / 4)
        button:SetPoint("TOPLEFT", page.styles[1], "BOTTOMLEFT", column * 160, -16 - row * 32)
        button.colorKey = color.key
        button:SetScript("OnClick", function(self)
            SaveLook("color", self.colorKey)
        end)
        page.colors[index] = button
    end
    page.size = Slider(page, "Size", 60, 240)
    page.height = Slider(page, "Height", -80, 40)
    page.count = Slider(page, "Count", 3, 12)
    page.bright = Slider(page, "Brightness", 20, 100)
    page.size.column:SetPoint("TOPLEFT", page.styles[1], "BOTTOMLEFT", 0, -156)
    page.height.column:SetPoint("LEFT", page.size.column, "RIGHT", 10, 0)
    page.count.column:SetPoint("LEFT", page.height.column, "RIGHT", 10, 0)
    page.bright.column:SetPoint("LEFT", page.count.column, "RIGHT", 10, 0)
    HookSlider(page.size, "size")
    HookSlider(page.height, "height")
    HookSlider(page.count, "count")
    HookSlider(page.bright, "brightness")
    page.trackLabel = Font(page, "OVERLAY", "GameFontNormal")
    page.trackLabel:SetPoint("TOPLEFT", page.size.column, "BOTTOMLEFT", 0, -8)
    page.trackLabel:SetText("Track these")
    page.trackAll = GoldButton(page, "Track all", 110)
    page.trackAll:SetPoint("LEFT", page.trackLabel, "RIGHT", 16, 0)
    page.trackNone = GoldButton(page, "Track none", 110)
    page.trackNone:SetPoint("LEFT", page.trackAll, "RIGHT", 8, 0)
    page.scroll = CreateFrame("ScrollFrame", "BMGSparkleGuideTrackScroll", page, "UIPanelScrollFrameTemplate")
    page.scroll:SetPoint("TOPLEFT", page.trackLabel, "BOTTOMLEFT", 0, -8)
    page.scroll:SetPoint("BOTTOMRIGHT", -24, 12)
    page.scroll:SetClipsChildren(true)
    page.trackChild = CreateFrame("Frame", nil, page.scroll)
    page.trackChild:SetSize(580, 26)
    page.scroll:SetScrollChild(page.trackChild)
    page.trackBoxes = {}
    for _, info in ipairs(G.KINDS) do
        local items = G.TRACK[info.key]
        if items then
            for index, item in ipairs(items) do
                local box = Check(page.trackChild, item.name)
                local column = (index - 1) % 2
                local row = math.floor((index - 1) / 2)
                box:SetPoint("TOPLEFT", 4 + column * 280, -row * 26)
                box.kind = info.key
                box.nodeKey = item.key
                box:SetScript("OnClick", function(self)
                    if filling then
                        return
                    end
                    G.db.track[self.kind][self.nodeKey] = IsChecked(self)
                    if G.Refresh then
                        G.Refresh()
                    end
                end)
                box:Hide()
                page.trackBoxes[#page.trackBoxes + 1] = box
            end
        end
    end
    local function SetKind(kind, allowed)
        if type(G.db.track[kind]) ~= "table" then
            G.db.track[kind] = {}
        end
        filling = true
        for _, box in ipairs(page.trackBoxes) do
            if box.kind == kind then
                G.db.track[kind][box.nodeKey] = allowed
            end
        end
        ShowTrack(kind)
        filling = false
        if G.Refresh then
            G.Refresh()
        end
    end
    page.trackAll:SetScript("OnClick", function()
        SetKind(selected, true)
    end)
    page.trackNone:SetScript("OnClick", function()
        SetKind(selected, false)
    end)
    page.trackNote = Font(page, "OVERLAY", "GameFontHighlight")
    page.trackNote:SetPoint("TOPLEFT", page.size.column, "BOTTOMLEFT", 0, -8)
    page.trackNote:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    page.trackNote:SetJustifyH("LEFT")
    page.trackNote:Hide()
    page:Hide()
    return page
end

local function BuildVoice(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local title = Font(page, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText("Announce at")
    local speak = Check(page, "Speak the node")
    speak:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -8)
    speak:SetScript("OnClick", function(self)
        G.db.voice = IsChecked(self)
    end)
    page.speak = speak
    local heading = Font(page, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", speak, "BOTTOMLEFT", 4, -10)
    heading:SetText("Announce at")
    page.steps = {}
    local stepList = {
        { key = "20", label = "20 yards" },
        { key = "15", label = "15 yards" },
        { key = "10", label = "10 yards" },
        { key = "5", label = "5 yards" },
        { key = "at", label = "At" },
    }
    for index, step in ipairs(stepList) do
        local box = Check(page, step.label)
        box:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", (index - 1) * 124, -4)
        box.step = step.key
        box:SetScript("OnClick", function(self)
            if filling then
                return
            end
            G.db.steps[self.step] = IsChecked(self)
            SyncSteps()
        end)
        page.steps[step.key] = box
    end
    local play = GoldButton(page, "Play sample", 140)
    play:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -48)
    play:SetScript("OnClick", function()
        G.PlaySample()
    end)
    local note = Font(page, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", play, "BOTTOMLEFT", 0, -16)
    note:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Check the distances you want to hear. You hear the name, then that distance, when the step changes. Close up, you hear At, then the name. The same boxes are on each sparkle page. A node without its own recording says Herb, Ore, Treasure, Quest object, Loot, Skin, or Fishing bobber. When the game hides the exact yards, farther than a short step says 20 yards, and the short step says 10 yards. You hear At when you are within a few yards, or when you open the loot.")
    page:Hide()
    return page
end

local function BuildSettings(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local title = Font(page, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText("Sparkle settings")
    local combat = Check(page, "Hide in combat")
    combat:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -8)
    combat:SetScript("OnClick", function(self)
        G.db.hideCombat = IsChecked(self)
        G.Refresh()
    end)
    local instance = Check(page, "Hide in dungeons")
    instance:SetPoint("TOPLEFT", combat, "BOTTOMLEFT", 0, -4)
    instance:SetScript("OnClick", function(self)
        G.db.hideInstance = IsChecked(self)
        G.Refresh()
    end)
    local map = Check(page, "Minimap button")
    map:SetPoint("TOPLEFT", instance, "BOTTOMLEFT", 0, -4)
    map:SetScript("OnClick", function(self)
        G.db.minimap = IsChecked(self)
        if G.MinimapButton then
            if G.db.minimap then
                G.MinimapButton:Show()
            else
                G.MinimapButton:Hide()
            end
        end
    end)
    page.combat, page.instance, page.map = combat, instance, map
    local note = Font(page, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", map, "BOTTOMLEFT", 4, -16)
    note:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText("While any sparkle is on, Interact Key is turned on and set to notice objects all around you, out to 30 yards. Turning every sparkle off puts those settings back. Logging out puts them back too. The guide speaks and sparkles the one object the game is pointing at.")
    page:Hide()
    return page
end

local function BuildProfile(parent)
    local page = CreateFrame("Frame", nil, parent)
    page:SetAllPoints()
    local title = Font(page, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText("Import and export")
    local note = Font(page, "OVERLAY", "GameFontHighlight")
    note:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    note:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Export puts a code for your sparkle, voice, and track settings in the box. Click the box, select the code, and copy it to save or share. Paste a code into the box, then press Import.")
    local border = CreateFrame("Frame", nil, page, "BackdropTemplate")
    border:SetPoint("TOPLEFT", note, "BOTTOMLEFT", 0, -12)
    border:SetSize(580, 240)
    border:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    border:SetBackdropColor(0.05, 0.04, 0.03, 1)
    local scroll = CreateFrame("ScrollFrame", "BMGSparkleGuideProfileScroll", border, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    scroll:SetClipsChildren(true)
    local edit = CreateFrame("EditBox", "BMGSparkleGuideProfileBox", scroll)
    edit:SetMultiLine(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(520)
    edit:SetAutoFocus(false)
    edit:SetTextInsets(4, 4, 4, 4)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    edit:SetScript("OnTextChanged", function(self)
        self:SetHeight(math.max(210, (self:GetNumLines() or 1) * 16 + 12))
    end)
    edit:SetHeight(210)
    scroll:SetScrollChild(edit)
    local export = GoldButton(page, "Export", 120)
    export:SetPoint("TOPLEFT", border, "BOTTOMLEFT", 0, -12)
    export:SetScript("OnClick", function()
        edit:SetText(G.ExportProfile())
        edit:SetFocus()
        edit:HighlightText()
        page.status:SetText("The code is in the box. Select it and copy it.")
    end)
    local import = GoldButton(page, "Import", 120)
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)
    import:SetScript("OnClick", function()
        if not G.ImportProfile(edit:GetText()) then
            page.status:SetText("That code is not a Sparkle Guide profile.")
            return
        end
        page.status:SetText("Settings loaded.")
        if G.MinimapButton then
            if G.db.minimap then
                G.MinimapButton:Show()
            else
                G.MinimapButton:Hide()
            end
        end
        if G.ApplyInteract then
            G.ApplyInteract()
        end
        if G.Refresh then
            G.Refresh()
        end
    end)
    page.status = Font(page, "OVERLAY", "GameFontNormal")
    page.status:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -8)
    page.status:SetPoint("RIGHT", page, "RIGHT", -16, 0)
    page.status:SetJustifyH("LEFT")
    page.status:SetText("")
    page:Hide()
    return page
end

local function PlaceMinimap(button)
    local angle = math.rad(G.db.minimapAngle or 220)
    local radius = (Minimap:GetWidth() / 2) + 5
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function BuildMinimap()
    local button = CreateFrame("Button", "BMGSparkleGuideMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetNormalTexture("Interface\\AddOns\\BMGSparkleGuide-forever\\icon")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnClick", function()
        if frame:IsShown() then
            frame:Hide()
        else
            frame:Show()
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("BMG Sparkle Guide")
        GameTooltip:AddLine("Open the sparkle window.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(self)
        self.dragging = true
    end)
    button:SetScript("OnDragStop", function(self)
        self.dragging = nil
    end)
    button:SetScript("OnUpdate", function(self)
        if not self.dragging then
            return
        end
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        G.db.minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
        PlaceMinimap(self)
    end)
    PlaceMinimap(button)
    if not G.db.minimap then
        button:Hide()
    end
    G.MinimapButton = button
end

function G.ToggleWindow()
    if not frame then
        return
    end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

local function BuildWindow()
    frame = CreateFrame("Frame", "BMGSparkleGuideFrame", UIParent, "BackdropTemplate")
    frame:SetSize(980, 900)
    frame:SetPoint("CENTER")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetClipsChildren(true)
    frame:SetFrameStrata("HIGH")
    frame:Hide()
    tinsert(UISpecialFrames, "BMGSparkleGuideFrame")

    local title = Font(frame, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("BMG Sparkle Guide")
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\AddOns\\BMGSparkleGuide-forever\\icon")
    icon:SetSize(36, 36)
    icon:SetPoint("TOPLEFT", 18, -12)
    local drag = CreateFrame("Button", nil, frame)
    drag:SetPoint("TOPLEFT", 12, -8)
    drag:SetPoint("TOPRIGHT", -40, -8)
    drag:SetHeight(28)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    drag:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local list = CreateFrame("Frame", nil, frame)
    list:SetPoint("TOPLEFT", 20, -56)
    list:SetSize(180, 480)
    local entries = {}
    for _, info in ipairs(G.KINDS) do
        entries[#entries + 1] = { key = info.key, label = info.label }
    end
    entries[#entries + 1] = { key = "voice", label = "Announce at" }
    entries[#entries + 1] = { key = "settings", label = "Sparkle settings" }
    entries[#entries + 1] = { key = "profile", label = "Import and export" }
    for index, entry in ipairs(entries) do
        local row = CreateFrame("Button", nil, list)
        row:SetSize(170, 26)
        row:SetPoint("TOPLEFT", 0, -((index - 1) * 28))
        row.key = entry.key
        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        row.highlight:SetColorTexture(0.55, 0.42, 0.12, 0.45)
        row.highlight:Hide()
        row.label = Font(row, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", 8, 0)
        row.label:SetText(entry.label)
        row:SetScript("OnClick", function(self)
            Select(self.key)
        end)
        rows[#rows + 1] = row
    end

    local body = CreateFrame("Frame", nil, frame)
    body:SetPoint("TOPLEFT", list, "TOPRIGHT", 12, 0)
    body:SetPoint("BOTTOMRIGHT", -20, 20)
    kindPage = BuildKind(body)
    voicePage = BuildVoice(body)
    settingsPage = BuildSettings(body)
    profilePage = BuildProfile(body)
    Select("herbs")

    frame:SetScript("OnShow", function()
        voicePage.speak:SetChecked(G.db.voice == true)
        SyncSteps()
        settingsPage.combat:SetChecked(G.db.hideCombat == true)
        settingsPage.instance:SetChecked(G.db.hideInstance == true)
        settingsPage.map:SetChecked(G.db.minimap == true)
        if selected ~= "voice" and selected ~= "settings" and selected ~= "profile" then
            RefreshKind()
        end
    end)
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_LOGOUT")
boot:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then
            return
        end
        G.LoadDB()
    elseif event == "PLAYER_LOGIN" then
        G.StartDetect()
        BuildWindow()
        BuildMinimap()
        print("|cffd4af37BMG Sparkle Guide|r " .. G.VERSION .. " for WoW Forever. Type /sg to open the window.")
    elseif event == "PLAYER_LOGOUT" then
        if G.RestoreInteract then
            G.RestoreInteract()
        end
    end
end)

SLASH_BMGSPARKLEGUIDE1 = "/sg"
SLASH_BMGSPARKLEGUIDE2 = "/sparkleguide"
SlashCmdList.BMGSPARKLEGUIDE = function()
    G.ToggleWindow()
end
