local _, G = ...

local STAR = "Interface\\Cooldown\\star4"
local SOFT = "Interface\\Cooldown\\starburst"
local BEAM = "Interface\\Buttons\\WHITE8X8"
local MAX = 12

local function HideAll(host)
    for i = 1, MAX do
        host.tex[i]:Hide()
    end
end

local function Paint(texture, path, blend)
    if texture.path ~= path then
        texture:SetTexture(path)
        texture.path = path
    end
    texture:SetBlendMode(blend or "ADD")
end

local function Place(texture, host, x, y, w, h, r, g, b, a)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", host, "CENTER", x, y)
    texture:SetSize(w, h)
    texture:SetVertexColor(r, g, b, 1)
    texture:SetAlpha(a > 1 and 1 or a)
    texture:Show()
end

local function Bright(host)
    return (host.look and host.look.brightness or 100) / 100
end

local function Count(host, cap)
    local n = host.look and host.look.count or 8
    if n < 3 then
        n = 3
    end
    if n > cap then
        n = cap
    end
    return n
end

local function Column(texture)
    if texture.column then
        return
    end
    texture.column = true
    texture.path = "column"
    texture:SetBlendMode("ADD")
    texture:SetTexture(SOFT)
    texture:SetTexCoord(0, 1, 0.5, 1)
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("BonusChest-CircleGlow")
    local file = info and info.file
    local left = info and info.leftTexCoord
    local right = info and info.rightTexCoord
    local top = info and info.topTexCoord
    local bottom = info and info.bottomTexCoord
    if file and not G.Secret(file) and not G.Secret(left) and not G.Secret(right) and not G.Secret(top) and not G.Secret(bottom) and type(left) == "number" and type(right) == "number" and type(top) == "number" and type(bottom) == "number" then
        texture:SetTexture(file)
        texture:SetTexCoord(left, right, bottom, (top + bottom) / 2)
    end
end

local function SoftTexture(texture, mark)
    if texture.soft == mark then
        return
    end
    texture.soft = mark
    texture.column = nil
    texture.path = SOFT
    texture:SetTexture(SOFT)
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetBlendMode("ADD")
end

local function GroundGlow(texture)
    SoftTexture(texture, "glow")
end

local function GroundRing(texture)
    SoftTexture(texture, "ring")
end

local function Area(host)
    local size = host:GetWidth()
    if not size or size < 20 then
        size = 100
    end
    return size
end

local function DrawBeam(host)
    HideAll(host)
    local color = G.ColorByKey(host.look.color)
    local a = Bright(host)
    local t = host.t
    local breath = 0.85 + 0.15 * math.sin(t * 2.2)
    local S = Area(host)
    local tall = 4.5 * S
    local base = -0.3 * S
    Column(host.tex[1])
    Place(host.tex[1], host, 0, base + tall / 2, 0.9 * S, tall, color.r1, color.g1, color.b1, 0.55 * a * breath)
    Column(host.tex[2])
    Place(host.tex[2], host, 0, base + tall / 2, 0.32 * S, tall, color.r2, color.g2, color.b2, 0.85 * a * breath)
    GroundGlow(host.tex[3])
    Place(host.tex[3], host, 0, base, 1.7 * S, 0.5 * S, color.r1, color.g1, color.b1, 0.5 * a)
    local ring = (t % 2.2) / 1.3
    if ring < 1 then
        local wide = S * (0.5 + 1.3 * ring)
        GroundRing(host.tex[4])
        Place(host.tex[4], host, 0, base, wide, wide * 0.32, color.r2, color.g2, color.b2, (1 - ring) * 0.7 * a)
    end
    local mote = math.max(16, 0.16 * S)
    for i = 5, 10 do
        local u = (t * 0.28 + (i - 5) * 0.16) % 1
        local x = math.sin(t * 1.4 + i) * (0.22 * S)
        local y = base + 8 + u * (tall - 24)
        local fade = math.sin(u * math.pi)
        Place(host.tex[i], host, x, y, mote, mote, color.r2, color.g2, color.b2, fade * 0.85 * a)
        Paint(host.tex[i], STAR, "ADD")
    end
end

local function Seeds(host)
    if host.seeds then
        return host.seeds
    end
    host.seeds = {}
    for i = 1, MAX do
        host.seeds[i] = { x = math.random() * 70 - 35, y = math.random() * 36 - 18, phase = math.random() * 6.28 }
    end
    return host.seeds
end

local function DrawTwinkle(host)
    HideAll(host)
    local color = G.ColorByKey(host.look.color)
    local a = Bright(host)
    local seeds = Seeds(host)
    local n = Count(host, 9)
    for i = 1, n do
        local seed = seeds[i]
        local wave = 0.5 + 0.5 * math.sin(host.t * 2.4 + seed.phase)
        local y = seed.y + (host.t * 8 + i * 4) % 28
        Place(host.tex[i], host, seed.x, y, 8 + wave * 10, 8 + wave * 10, color.r1, color.g1, color.b1, wave * a)
        Paint(host.tex[i], STAR, "ADD")
    end
end

local function DrawGlints(host)
    HideAll(host)
    local color = G.ColorByKey(host.look.color)
    local a = Bright(host)
    local seeds = Seeds(host)
    local n = Count(host, 8)
    for i = 1, n do
        local seed = seeds[i]
        local u = (host.t * 1.6 + seed.phase) % 1
        local flash = 0
        if u < 0.18 then
            flash = u / 0.18
        end
        Place(host.tex[i], host, seed.x, seed.y, 16, 16, color.r2, color.g2, color.b2, flash * a)
        Paint(host.tex[i], STAR, "ADD")
    end
end

local function DrawPollen(host)
    HideAll(host)
    local color = G.ColorByKey(host.look.color)
    local a = Bright(host)
    local n = Count(host, 10)
    for i = 1, n do
        local u = (host.t * 0.22 + i / n) % 1
        local x = math.sin(host.t * 1.3 + i) * 24
        local y = -16 + u * 70
        local fade = math.sin(u * math.pi)
        Place(host.tex[i], host, x, y, 8, 8, color.r1, color.g1, color.b1, fade * 0.8 * a)
        Paint(host.tex[i], SOFT, "ADD")
    end
end

local function DrawCrown(host)
    HideAll(host)
    local color = G.ColorByKey(host.look.color)
    local a = Bright(host)
    local n = Count(host, 10)
    for i = 1, n do
        local angle = host.t * 0.9 + (i - 1) * (6.28318 / n)
        local x = math.cos(angle) * 28
        local y = 18 + math.sin(angle) * 10
        local useCore = i % 2 == 0
        local r, g, b = color.r1, color.g1, color.b1
        if useCore then
            r, g, b = color.r2, color.g2, color.b2
        end
        Place(host.tex[i], host, x, y, 14, 14, r, g, b, 0.95 * a)
        Paint(host.tex[i], STAR, "ADD")
    end
end

local DRAWS = {
    lightbeam = DrawBeam,
    twinkle = DrawTwinkle,
    glints = DrawGlints,
    pollen = DrawPollen,
    starcrown = DrawCrown,
}

local function NewHost(parent)
    local host = CreateFrame("Frame", nil, parent)
    host:SetSize(40, 40)
    host.tex = {}
    for i = 1, MAX do
        local texture = host:CreateTexture(nil, "OVERLAY")
        texture:SetTexture(STAR)
        texture:SetBlendMode("ADD")
        texture:Hide()
        host.tex[i] = texture
    end
    host.t = 0
    host:SetScript("OnUpdate", function(self, elapsed)
        self.t = self.t + elapsed
        if self.onWorld and self.project then
            local ok, sx, sy = pcall(self.project, self.worldY, self.worldX, self.worldZ)
            if ok and not G.Secret(sx) and not G.Secret(sy) and type(sx) == "number" and type(sy) == "number" then
                if self:GetParent() ~= UIParent then
                    self:SetParent(UIParent)
                end
                self:ClearAllPoints()
                self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
            end
        end
        if self.draw then
            self.draw(self)
        end
    end)
    host:Hide()
    return host
end

function G.WorldHost()
    if not G.worldHost then
        G.worldHost = NewHost(nil)
        G.worldHost.followPlate = true
    end
    return G.worldHost
end

function G.SampleHost(parent)
    local host = NewHost(parent)
    host:SetFrameStrata("HIGH")
    return host
end

function G.PreviewHost(parent)
    if not G.previewHost then
        G.previewHost = NewHost(parent)
    elseif parent and G.previewHost:GetParent() ~= parent then
        G.previewHost:SetParent(parent)
    end
    return G.previewHost
end

local function ScreenScale(plate)
    local scale = 1
    if plate.GetEffectiveScale and UIParent.GetEffectiveScale then
        local okP, pScale = pcall(plate.GetEffectiveScale, plate)
        local okU, uScale = pcall(UIParent.GetEffectiveScale, UIParent)
        if okP and okU and type(pScale) == "number" and type(uScale) == "number" and uScale ~= 0 and not G.Secret(pScale) and not G.Secret(uScale) then
            scale = pScale / uScale
        end
    end
    return scale
end

function G.FollowPlate(host)
    local plate = host.anchor
    if not plate then
        return
    end
    local scale = ScreenScale(plate)
    local x, y
    local ok, cx, cy = pcall(plate.GetCenter, plate)
    if ok and not G.Secret(cx) and not G.Secret(cy) and type(cx) == "number" and type(cy) == "number" then
        x, y = cx * scale, cy * scale
    else
        local okR, left, bottom, width = pcall(plate.GetRect, plate)
        if okR and not G.Secret(left) and not G.Secret(bottom) and type(left) == "number" and type(bottom) == "number" then
            local wide = 0
            if not G.Secret(width) and type(width) == "number" then
                wide = width
            end
            x, y = (left + wide / 2) * scale, bottom * scale
        end
    end
    if not x or not y then
        return
    end
    if host:GetParent() ~= UIParent then
        host:SetParent(UIParent)
    end
    host:SetFrameStrata("TOOLTIP")
    host:ClearAllPoints()
    host:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y + (host.anchorY or 0))
    host.placed = true
    host:Show()
end

function G.ApplySpark(host, look, anchor, point, relPoint, x, y)
    if not host or not look then
        return
    end
    local style = DRAWS[look.style] or DrawBeam
    if host.draw ~= style then
        host.seeds = nil
    end
    host.look = look
    host.draw = style
    host:SetScale((look.size or 100) / 100)
    if host.followPlate then
        host.anchor = anchor
        host.anchorY = y or 0
        if host:GetParent() ~= UIParent then
            host:SetParent(UIParent)
        end
        host:SetFrameStrata("TOOLTIP")
        if host.SetIgnoreParentAlpha then
            host:SetIgnoreParentAlpha(true)
        end
        host.placed = nil
        if anchor then
            G.FollowPlate(host)
        end
        if host.placed then
            host:Show()
        end
    else
        host:ClearAllPoints()
        host:SetPoint(point or "CENTER", anchor or host:GetParent(), relPoint or "CENTER", x or 0, y or 0)
        host:Show()
    end
end

local function BeamScale()
    local zoom = 15
    if GetCameraZoom then
        local ok, value = pcall(GetCameraZoom)
        local n = ok and G.PlainNumber(value)
        if n and n > 0 then
            zoom = n
        end
    end
    local scale = 25 / (zoom + 10) * 1.35
    if scale < 1.15 then
        scale = 1.15
    end
    if scale > 2.2 then
        scale = 2.2
    end
    return scale
end

function G.PlaceOnWorld(host, look, y, x, z, project)
    if not host or not look or not project then
        return
    end
    if G.Secret(y) or G.Secret(x) or not y or not x then
        return
    end
    local style = DRAWS[look.style] or DrawBeam
    if host.draw ~= style then
        host.seeds = nil
    end
    host.look = look
    host.draw = style
    host:SetScale(1)
    local size = look.size or 100
    if size < 20 then
        size = 100
    end
    size = math.floor(size * BeamScale() + 0.5)
    host:SetSize(size, size)
    host.project = project
    host.onWorld = true
    host.worldY, host.worldX, host.worldZ = y, x, z
    host.anchor = nil
    if host:GetParent() ~= UIParent then
        host:SetParent(UIParent)
    end
    host:SetFrameStrata("TOOLTIP")
    local ok, sx, sy = pcall(project, y, x, z)
    if ok and not G.Secret(sx) and not G.Secret(sy) and type(sx) == "number" and type(sy) == "number" then
        host:ClearAllPoints()
        host:SetPoint("CENTER", UIParent, "BOTTOMLEFT", sx, sy)
    end
    host:Show()
end

function G.PlaceOnPlate(host, look, plate, y)
    if not host or not look or not plate then
        return
    end
    local style = DRAWS[look.style] or DrawBeam
    if host.draw ~= style then
        host.seeds = nil
    end
    host.look = look
    host.draw = style
    host.project = nil
    host.onWorld = nil
    host.worldY, host.worldX, host.worldZ = nil, nil, nil
    host:SetScale(1)
    local size = look.size or 100
    if size < 20 then
        size = 100
    end
    if host.followPlate then
        size = math.floor(size * BeamScale() + 0.5)
    end
    host:SetSize(size, size)
    host.anchor = nil
    if host.SetIgnoreParentAlpha then
        host:SetIgnoreParentAlpha(true)
    end
    if host:GetParent() ~= plate then
        host:SetParent(plate)
    end
    host:ClearAllPoints()
    -- The beam's ground is drawn below the middle. Lift so that ground sits on the chosen height.
    host:SetPoint("CENTER", plate, "BOTTOM", 0, (y or -24) + math.floor(size * 0.3 + 0.5))
    host:Show()
end

function G.HideSpark(host)
    if not host then
        return
    end
    host.draw = nil
    host.anchor = nil
    host.project = nil
    host.onWorld = nil
    host.worldY, host.worldX, host.worldZ = nil, nil, nil
    host:Hide()
    host:ClearAllPoints()
    if host.followPlate and host:GetParent() ~= UIParent then
        host:SetParent(UIParent)
    end
end
