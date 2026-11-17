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
    texture:SetVertexColor(r, g, b, a)
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
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("BonusChest-CircleGlow")
    local file = info and info.file
    if file and not G.Secret(file) and not G.Secret(info.leftTexCoord) then
        texture:SetTexture(file)
        local mid = (info.topTexCoord + info.bottomTexCoord) / 2
        texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.bottomTexCoord, mid)
    else
        texture:SetAtlas("BonusChest-CircleGlow")
    end
    texture:SetBlendMode("ADD")
    texture.column = true
    texture.path = "column"
end

local function GroundGlow(texture)
    if texture.glow then
        return
    end
    texture:SetAtlas("BonusChest-CircleGlow")
    texture:SetBlendMode("ADD")
    texture.glow = true
    texture.path = "glow"
end

local function GroundRing(texture)
    if texture.ring then
        return
    end
    if not texture:SetAtlas("PowerSwirlAnimation-YellowRing") then
        texture:SetAtlas("BonusChest-CircleGlow")
    end
    texture:SetDesaturated(true)
    texture:SetBlendMode("ADD")
    texture.ring = true
    texture.path = "ring"
end

local function DrawBeam(host)
    HideAll(host)
    local color = G.ColorByKey(host.look.color)
    local a = Bright(host)
    local t = host.t
    local breath = 0.85 + 0.15 * math.sin(t * 2.2)
    local tall = 240
    local base = -6
    Column(host.tex[1])
    Place(host.tex[1], host, 0, base + tall / 2, 78, tall, color.r1, color.g1, color.b1, 0.55 * a * breath)
    Column(host.tex[2])
    Place(host.tex[2], host, 0, base + tall / 2, 26, tall, color.r2, color.g2, color.b2, 0.8 * a * breath)
    GroundGlow(host.tex[3])
    Place(host.tex[3], host, 0, base, 96, 34, color.r1, color.g1, color.b1, 0.5 * a)
    local ring = (t % 2.2) / 1.3
    if ring < 1 then
        local wide = 36 + 90 * ring
        GroundRing(host.tex[4])
        Place(host.tex[4], host, 0, base, wide, wide * 0.32, color.r2, color.g2, color.b2, (1 - ring) * 0.7 * a)
    end
    for i = 5, 10 do
        local u = (t * 0.28 + (i - 5) * 0.16) % 1
        local x = math.sin(t * 1.4 + i) * 18
        local y = base + 8 + u * (tall - 24)
        local fade = math.sin(u * math.pi)
        Place(host.tex[i], host, x, y, 11, 11, color.r2, color.g2, color.b2, fade * 0.85 * a)
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
        if self.draw then
            self.draw(self)
        end
    end)
    host:Hide()
    return host
end

function G.WorldHost()
    if not G.worldHost then
        G.worldHost = NewHost(UIParent)
        G.worldHost:SetFrameStrata("MEDIUM")
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
        G.previewHost:SetFrameStrata("HIGH")
    elseif parent and G.previewHost:GetParent() ~= parent then
        G.previewHost:SetParent(parent)
        G.previewHost:SetFrameStrata("HIGH")
    end
    return G.previewHost
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
    if host.followPlate and anchor and host:GetParent() ~= anchor then
        host:SetParent(anchor)
        host:SetFrameStrata("MEDIUM")
    end
    host:ClearAllPoints()
    host:SetPoint(point or "CENTER", anchor or host:GetParent(), relPoint or "CENTER", x or 0, y or 0)
    host:Show()
end

function G.HideSpark(host)
    if not host then
        return
    end
    host.draw = nil
    host:Hide()
    if host.followPlate and host:GetParent() ~= UIParent then
        host:SetParent(UIParent)
    end
end
