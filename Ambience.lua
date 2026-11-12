-- VenStore: time of day, and where the shop stands.
-- Indoors, a window from the region's own architecture hangs on the wall behind the vendor
-- (Stormwind's leaded glass in its stone, a round night elf window in carved wood...). The glass is
-- bright by day, warm at sunrise and sunset and dark at night, and daylight spills down the wall
-- from it; the lanterns take over at night. Outdoors, the shop becomes a market stall with a
-- striped awning and sun or moonlight. In a town (a resting area) the stall keeps the shop's
-- walls; out in the wilds the region's own trees and shrubs stand behind it instead.
local _, addon = ...
local Wood = addon.Wood
local ShelfFrame = addon.ShelfFrame
local backboard = addon.backboard
local vendorZone = addon.Showroom.vendorZone
local baseLevel = ShelfFrame:GetFrameLevel()

local Ambience = {}
addon.Ambience = Ambience

local DISC = Wood.DISC

local function Lerp(a, b, t) return a + (b - a) * t end
local function LerpRGB(a, b, t) return { Lerp(a[1], b[1], t), Lerp(a[2], b[2], t), Lerp(a[3], b[3], t) } end
local function Clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end

-- ============================================================================
-- STYLES (per theme)
-- ============================================================================
--   window   the window on the wall behind the vendor, from the game's own window art. Either:
--            a framed window
--              w, h       glass size
--              border     frame width
--              frame      material for the frame, sill and bars (format in Wood.lua)
--              glass      material for the glass; its alpha (where the game has a glow mask)
--                         lights the panes
--              lights     panes side by side, each showing the whole glass picture (default 1)
--              mullion, transom   add a centre bar / a cross bar in the frame material
--              lintel     a wider block with a keystone over the window
--            or a picture window (the picture includes its own frame)
--              picture    { file, rect }; w, h (or size); round = cut to a circle
--              glow       { file } the game's glow ("emissive") picture for it, if there is one
--   awning   the two stripe colours of the outdoor valance
local SW_STONE = { 0.80, 0.84, 0.92 }
local STYLES = {
    workshop = {
        window = {
            w = 100, h = 132, border = 11,
            frame = { file = 127979, size = 96, tint = { 0.60, 0.44, 0.30 } },     -- plank boards, stained
            glass = { file = 130143, rect = { 0.00, 0.31, 0.00, 0.50 } },          -- mm_strmwnd_hwindows_01
        },
        awning = { { 0.86, 0.80, 0.66 }, { 0.62, 0.16, 0.12 } },
    },
    stormwind = {
        window = {
            w = 104, h = 136, border = 12, lintel = true, -- the glass has its own glazing bars
            frame = { file = 457670, size = 96, tint = SW_STONE },                   -- stormwind_stone
            glass = { file = 130146, rect = { 0.00, 0.50, 0.50, 1.00 } },           -- mm_strmwnd_windows_02
        },
        awning = { { 0.16, 0.27, 0.55 }, { 0.84, 0.68, 0.30 } },
    },
    nightelf = {
        window = {                                                                   -- carved wooden ring
            round = true, size = 132,
            picture = { file = 1140752, rect = { 0.08, 0.92, 0.08, 0.92 } },        -- 7ne_druid_window01
        },
        awning = { { 0.38, 0.22, 0.48 }, { 0.72, 0.62, 0.40 } },
    },
    kultiras = {
        window = {                                                                   -- arched, wood-framed
            w = 92, h = 182,
            picture = { file = 1627061, rect = { 0.09, 0.47, 0.03, 0.78 } },        -- 8hu_kultiras_window02
            glow = { file = 1627062 },                                               -- ..._emissive
        },
        awning = { { 0.13, 0.40, 0.42 }, { 0.86, 0.82, 0.70 } },
    },
    silvermoon = {
        window = {
            w = 96, h = 150, border = 10, lights = 2, lintel = true,
            frame = { file = 128859, size = 96 },                                    -- wdbldelfgt_goldblock
            glass = { file = 128799, rect = { 0.00, 0.48, 0.00, 1.00 } },           -- bldelf_window: red and gold
        },
        awning = { { 0.58, 0.08, 0.10 }, { 0.86, 0.66, 0.24 } },
    },
    orgrimmar = {
        window = {                                                                   -- iron-framed
            w = 124, h = 124,
            picture = { file = 130185, rect = { 0.52, 0.98, 0.02, 0.48 } },         -- jlo_worc_window02
        },
        awning = { { 0.56, 0.40, 0.24 }, { 0.42, 0.16, 0.10 } },
    },
}
local function StyleFor(key) return STYLES[key] or STYLES.workshop end

-- ============================================================================
-- SKY (by realm hour)
-- ============================================================================
-- h: hour; top / bottom: sky colours; day: 0 night to 1 full day; warm: sunrise / sunset glow.
local SKY = {
    { h = 0,    top = { 0.02, 0.03, 0.08 }, bottom = { 0.05, 0.07, 0.16 }, day = 0,    warm = 0 },
    { h = 5,    top = { 0.02, 0.03, 0.08 }, bottom = { 0.05, 0.07, 0.16 }, day = 0,    warm = 0 },
    { h = 6.25, top = { 0.16, 0.18, 0.38 }, bottom = { 0.85, 0.50, 0.38 }, day = 0.35, warm = 1 },
    { h = 7.5,  top = { 0.26, 0.48, 0.82 }, bottom = { 0.70, 0.82, 0.92 }, day = 1,    warm = 0.2 },
    { h = 12,   top = { 0.20, 0.45, 0.85 }, bottom = { 0.62, 0.80, 0.96 }, day = 1,    warm = 0 },
    { h = 17.5, top = { 0.24, 0.46, 0.80 }, bottom = { 0.70, 0.80, 0.90 }, day = 1,    warm = 0.2 },
    { h = 19.5, top = { 0.22, 0.20, 0.45 }, bottom = { 0.98, 0.52, 0.24 }, day = 0.45, warm = 1 },
    { h = 21,   top = { 0.05, 0.06, 0.16 }, bottom = { 0.18, 0.14, 0.30 }, day = 0.08, warm = 0.3 },
    { h = 24,   top = { 0.02, 0.03, 0.08 }, bottom = { 0.05, 0.07, 0.16 }, day = 0,    warm = 0 },
}

function Ambience.Sky(hour)
    hour = hour % 24
    for i = 1, #SKY - 1 do
        local a, b = SKY[i], SKY[i + 1]
        if hour >= a.h and hour <= b.h then
            local t = (b.h > a.h) and (hour - a.h) / (b.h - a.h) or 0
            return {
                top = LerpRGB(a.top, b.top, t), bottom = LerpRGB(a.bottom, b.bottom, t),
                day = Lerp(a.day, b.day, t), warm = Lerp(a.warm, b.warm, t),
            }
        end
    end
    return { top = SKY[1].top, bottom = SKY[1].bottom, day = 0, warm = 0 }
end

-- ============================================================================
-- INDOOR WINDOW
-- ============================================================================
-- A window material, drawn opaque (world textures keep gloss or glow masks in their alpha).
local function Material(tex, mat, w, h, o1, o2)
    tex:SetTexture(mat.file, "REPEAT", "REPEAT")
    Wood.MapMaterial(tex, mat, w, h, false, o1 or 0.13, o2 or 0.37)
    tex:SetBlendMode("DISABLE")
    local t = mat.tint
    tex:SetVertexColor(t and t[1] or 1, t and t[2] or 1, t and t[3] or 1)
end

-- A block of the frame material with light from above: a bright top edge, a dark lower edge.
local function Block(parent, layer, sub, mat, w, h, seed)
    local tex = parent:CreateTexture(nil, layer, nil, sub)
    tex:SetSize(w, h)
    Material(tex, mat, w, h, 0.11 * seed, 0.29 * seed)
    local hi = parent:CreateTexture(nil, layer, nil, sub + 1)
    hi:SetPoint("TOPLEFT", tex, "TOPLEFT"); hi:SetPoint("TOPRIGHT", tex, "TOPRIGHT")
    hi:SetHeight(math.min(3, h / 3))
    Wood.Gradient(hi, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.30)
    local lo = parent:CreateTexture(nil, layer, nil, sub + 1)
    lo:SetPoint("BOTTOMLEFT", tex, "BOTTOMLEFT"); lo:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT")
    lo:SetHeight(math.min(4, h / 3))
    Wood.Gradient(lo, "VERTICAL", 0, 0, 0, 0.50, 0, 0, 0, 0)
    return tex
end

-- A picture window: the game's picture of a whole window, frame included. Round ones are cut to a
-- circle. The glass glows by day: from the game's glow picture where it has one, otherwise a soft
-- light in the middle.
local function BuildPictureWindow(s)
    local p = s.picture
    if not Wood.CanLoad(p.file) then return nil end
    if s.round and not backboard.CreateMaskTexture then return nil end
    local W, H = s.w or s.size, s.h or s.size
    local win = CreateFrame("Frame", nil, backboard)
    win:SetSize(W, H)
    win:SetFrameLevel(backboard:GetFrameLevel() + 2)
    win:Hide()

    local drop
    if s.round then
        drop = Wood.Disc(win, "BACKGROUND", 0, 0, 0, 0, 0.55)
    else
        drop = win:CreateTexture(nil, "BACKGROUND", nil, 0)
        drop:SetColorTexture(0, 0, 0, 0.45)
    end
    drop:SetPoint("TOPLEFT", 3, -5); drop:SetPoint("BOTTOMRIGHT", 7, -9)

    local r = p.rect
    local pic = win:CreateTexture(nil, "BORDER", nil, 0)
    pic:SetAllPoints()
    pic:SetTexture(p.file)
    pic:SetTexCoord(r[1], r[2], r[3], r[4])
    local mask
    if s.round then
        mask = win:CreateMaskTexture()
        mask:SetTexture(Wood.DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(pic)
        pic:AddMaskTexture(mask)        -- masked, so it keeps alpha blending
    else
        pic:SetBlendMode("DISABLE")     -- opaque (alpha may be a gloss mask)
        Wood.EdgeShade(win, pic, "TOP", 4, 0.35, "BORDER", 2, 1, 1, 1)
        Wood.EdgeShade(win, pic, "BOTTOM", 5, 0.45, "BORDER", 2)
    end

    local glow
    if s.glow and Wood.CanLoad(s.glow.file) then
        glow = win:CreateTexture(nil, "BORDER", nil, 1)
        glow:SetAllPoints(pic)
        glow:SetTexture(s.glow.file)
        glow:SetTexCoord(r[1], r[2], r[3], r[4])
        glow:SetBlendMode("ADD")
        if mask then glow:AddMaskTexture(mask) end
    elseif s.round then
        -- Round glass in the middle of a carved ring: a soft light from the centre.
        glow = win:CreateTexture(nil, "BORDER", nil, 1)
        glow:SetTexture(Wood.CanLoad(1100044) and 1100044 or Wood.DISC) -- genericglow_alpha_128
        glow:SetPoint("CENTER")
        glow:SetSize(W * 0.6, H * 0.6)
        glow:SetBlendMode("ADD")
    else
        -- No glow picture: an additive copy of the window itself, so the bright glass lights up
        -- most and the frame keeps its shape.
        glow = win:CreateTexture(nil, "BORDER", nil, 1)
        glow:SetAllPoints(pic)
        glow:SetTexture(p.file)
        glow:SetTexCoord(r[1], r[2], r[3], r[4])
        glow:SetBlendMode("ADD")
    end
    local glowScale = (s.glow and 0.9) or (s.round and 0.45) or 0.35

    local light = CreateFrame("Frame", nil, backboard)
    light:SetAllPoints(win)
    light:SetFrameLevel(backboard:GetFrameLevel() + 2)
    local shaft = light:CreateTexture(nil, "ARTWORK", nil, 3)
    shaft:SetPoint("TOP", win, "BOTTOM", 0, 4)
    shaft:SetSize(W * 0.8, 200)
    shaft:SetBlendMode("ADD")

    local w = { frame = win, light = light }
    function w.Apply(_, sk)
        local day, warm = sk.day, sk.warm
        local c = LerpRGB({ 0.50, 0.52, 0.66 }, { 1, 1, 1 }, day)
        pic:SetVertexColor(c[1], c[2], c[3])
        local g = LerpRGB(sk.bottom, { 1, 0.62, 0.30 }, warm * 0.6)
        glow:SetVertexColor(g[1], g[2], g[3], 0.05 + glowScale * day)
        local a = 0.02 + 0.10 * day
        Wood.Gradient(shaft, "VERTICAL", g[1], g[2], g[3], 0, g[1], g[2], g[3], a)
    end
    return w
end

local function BuildWindow(key)
    local s = StyleFor(key).window
    if s and s.picture then return BuildPictureWindow(s) end
    if not (s and Wood.CanLoad(s.frame.file) and Wood.CanLoad(s.glass.file)) then return nil end
    local W, H, B = s.w, s.h, s.border or 10
    local OW, OH = W + 2 * B, H + 2 * B

    local win = CreateFrame("Frame", nil, backboard)
    win:SetSize(OW, OH)
    win:SetFrameLevel(backboard:GetFrameLevel() + 2)
    win:Hide()

    -- Shadow on the wall, then the frame.
    local drop = win:CreateTexture(nil, "BACKGROUND", nil, 0)
    drop:SetPoint("TOPLEFT", 4, -5); drop:SetPoint("BOTTOMRIGHT", 7, -9)
    drop:SetColorTexture(0, 0, 0, 0.45)
    local frame = Block(win, "BACKGROUND", 1, s.frame, OW, OH, 1)
    frame:SetPoint("CENTER")
    Wood.EdgeShade(win, frame, "RIGHT", 4, 0.35, "BACKGROUND", 3)

    -- Glass, one picture per light, set back into the frame.
    local lights = s.lights or 1
    local GAP = 8
    local lw = (W - (lights - 1) * GAP) / lights
    local panes = {}
    for i = 1, lights do
        local base = win:CreateTexture(nil, "BORDER", nil, 0)
        base:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", B + (i - 1) * (lw + GAP), B)
        base:SetSize(lw, H)
        Material(base, s.glass, lw, H)
        -- The glass's alpha is where the game makes it glow: light comes through the panes only.
        local glow = win:CreateTexture(nil, "BORDER", nil, 1)
        glow:SetAllPoints(base)
        glow:SetTexture(s.glass.file, "REPEAT", "REPEAT")
        Wood.MapMaterial(glow, s.glass, lw, H, false, 0.13, 0.37)
        glow:SetBlendMode("ADD")
        local haze = win:CreateTexture(nil, "BORDER", nil, 2)
        haze:SetAllPoints(base)
        haze:SetBlendMode("ADD")
        -- The frame's shadow inside the opening.
        Wood.EdgeShade(win, base, "TOP", 9, 0.60, "BORDER", 3)
        Wood.EdgeShade(win, base, "LEFT", 5, 0.45, "BORDER", 3)
        panes[i] = { base = base, glow = glow, haze = haze }
    end

    -- Stone bars across the glass.
    local BAR = 6
    if s.mullion then
        local bar = Block(win, "ARTWORK", 0, s.frame, BAR, H, 2)
        bar:SetPoint("BOTTOM", win, "BOTTOM", 0, B)
    end
    if s.transom then
        local bar = Block(win, "ARTWORK", 2, s.frame, W, BAR, 3)
        bar:SetPoint("BOTTOM", win, "BOTTOM", 0, B + math.floor(H * 0.62))
    end

    -- Sill, and a lintel above.
    local sill = Block(win, "ARTWORK", 4, s.frame, OW + 14, 10, 4)
    sill:SetPoint("TOP", win, "BOTTOM", 0, 6)
    local sillShadow = win:CreateTexture(nil, "BACKGROUND", nil, 0)
    sillShadow:SetPoint("TOPLEFT", sill, "BOTTOMLEFT", 3, 0)
    sillShadow:SetPoint("TOPRIGHT", sill, "BOTTOMRIGHT", 3, 0)
    sillShadow:SetHeight(12)
    Wood.Gradient(sillShadow, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.55)
    if s.lintel then
        local lintel = Block(win, "ARTWORK", 4, s.frame, OW + 10, 16, 5)
        lintel:SetPoint("BOTTOM", win, "TOP", 0, -6)
        local keystone = Block(win, "ARTWORK", 6, s.frame, 20, 22, 6)
        keystone:SetPoint("BOTTOM", lintel, "BOTTOM", 0, -2)
    end

    -- Daylight falling down the wall from the window.
    local light = CreateFrame("Frame", nil, backboard)
    light:SetAllPoints(win)
    light:SetFrameLevel(backboard:GetFrameLevel() + 2)
    local shaft = light:CreateTexture(nil, "ARTWORK", nil, 3)
    shaft:SetPoint("TOP", sill, "BOTTOM", 0, 0)
    shaft:SetSize(W + 30, 200)
    shaft:SetBlendMode("ADD")

    local w = { frame = win, light = light }

    function w.Apply(_, sk)
        local day, warm = sk.day, sk.warm
        -- The glass: deep blue at night, its own colours by day, warmer at sunrise and sunset.
        local c = LerpRGB({ 0.26, 0.30, 0.46 }, { 1, 1, 1 }, day)
        local cr, cg, cb = c[1], c[2] * (1 - 0.10 * warm), c[3] * (1 - 0.28 * warm)
        local g = LerpRGB(sk.bottom, { 1, 0.62, 0.30 }, warm * 0.6)
        local glowA = 0.08 + 0.55 * day
        for _, p in ipairs(panes) do
            p.base:SetVertexColor(cr, cg, cb)
            p.glow:SetVertexColor(g[1], g[2], g[3], glowA)
            p.haze:SetColorTexture(g[1], g[2], g[3], 0.02 + 0.10 * day)
        end
        local a = 0.02 + 0.12 * day
        Wood.Gradient(shaft, "VERTICAL", g[1], g[2], g[3], 0, g[1], g[2], g[3], a)
    end

    return w
end

local windows = {}   -- key -> window, or false for themes without one
local currentWindow

-- Behind the vendor's head and shoulders, below the header beam.
local function PlaceWindow(w)
    local f = w.frame
    f:ClearAllPoints()
    local bt, vt = backboard:GetTop(), vendorZone:GetTop()
    local gap = (bt and vt) and (bt - vt) or 0
    local above = math.max(-60, math.min(40, gap - 30))
    f:SetPoint("TOP", vendorZone, "TOP", 0, above)
end

local function HideWindows()
    for _, w in pairs(windows) do
        if w then w.frame:Hide(); w.light:Hide() end
    end
    currentWindow = nil
end

-- The theme's window (nil when it has none).
local function ShowWindow(key)
    HideWindows()
    if windows[key] == nil then windows[key] = BuildWindow(key) or false end
    local w = windows[key] or nil
    if w then
        w.frame:Show(); w.light:Show()
        currentWindow = w
        PlaceWindow(w)
    end
    return w
end

vendorZone:HookScript("OnSizeChanged", function() if currentWindow then PlaceWindow(currentWindow) end end)
backboard:HookScript("OnSizeChanged", function() if currentWindow then PlaceWindow(currentWindow) end end)

-- ============================================================================
-- OUTDOOR STALL: a canvas awning on a rail under the header beam, and square timber posts
-- ============================================================================
-- The awning is stitched canvas panels in two muted stripe colours, each shaded like sagging cloth,
-- with a scalloped hem, hanging from a wooden rail. The corner posts get an inner side face in
-- perspective and a knee brace up to the awning, so the stall reads as a built frame.
local topBeam = addon.topBeam
local valance = CreateFrame("Frame", nil, ShelfFrame)
valance:SetPoint("TOPLEFT", topBeam, "BOTTOMLEFT", 4, 1)
valance:SetPoint("TOPRIGHT", topBeam, "BOTTOMRIGHT", -4, 1)
valance:SetHeight(30)
valance:SetFrameLevel(topBeam:GetFrameLevel() + 2) -- over the beam's moulding
valance:Hide()

local RAIL_H, PANEL_H, SCALLOP_H, SEG_W = 7, 13, 11, 30
local segments = {}
local awningColours = STYLES.workshop.awning
local CANVAS = { 0.58, 0.54, 0.47 } -- weathered canvas the stripe dyes are mixed toward

-- Shadow the awning casts on the wall and shelves below it.
local valanceShadow = valance:CreateTexture(nil, "BACKGROUND", nil, 0)
valanceShadow:SetPoint("TOPLEFT", valance, "TOPLEFT", 0, -(RAIL_H + PANEL_H))
valanceShadow:SetPoint("TOPRIGHT", valance, "TOPRIGHT", 0, -(RAIL_H + PANEL_H))
valanceShadow:SetHeight(46)
Wood.Gradient(valanceShadow, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.42)

-- The rail the canvas hangs from.
local rail = CreateFrame("Frame", nil, valance)
rail:SetPoint("TOPLEFT", valance, "TOPLEFT", -2, 0)
rail:SetPoint("TOPRIGHT", valance, "TOPRIGHT", 2, 0)
rail:SetHeight(RAIL_H)
rail:SetFrameLevel(valance:GetFrameLevel() + 2)
Wood.Paint(rail, "beam", 77, { round = true, sheen = false, tone = 0.9 })

local function Dye(c, k)
    local m = 0.30 -- how far the sun has faded the dye toward plain canvas
    return (c[1] * (1 - m) + CANVAS[1] * m) * k, (c[2] * (1 - m) + CANVAS[2] * m) * k,
        (c[3] * (1 - m) + CANVAS[3] * m) * k
end

local function PaintSegments()
    for i, seg in ipairs(segments) do
        local c = awningColours[(i % 2) + 1]
        local r, g, b = Dye(c, 1)
        -- Each panel sags: lit in the middle, falling into shade at the seams.
        Wood.Gradient(seg.left, "HORIZONTAL", r * 0.72, g * 0.72, b * 0.72, 1, r, g, b, 1)
        Wood.Gradient(seg.right, "HORIZONTAL", r, g, b, 1, r * 0.72, g * 0.72, b * 0.72, 1)
        seg.scallop:SetVertexColor(r * 0.92, g * 0.92, b * 0.92, 1)
        seg.hem:SetVertexColor(r * 0.45, g * 0.45, b * 0.45, 1)
    end
end

local function LayoutValance(width)
    width = width or valance:GetWidth()
    if not width or width <= 0 then return end
    local n = math.max(4, math.floor(width / SEG_W + 0.5))
    local segW = width / n
    for i = 1, math.max(n, #segments) do
        local seg = segments[i]
        if i <= n and not seg then
            seg = {}
            seg.left = valance:CreateTexture(nil, "ARTWORK", nil, 1)
            seg.right = valance:CreateTexture(nil, "ARTWORK", nil, 1)
            seg.hem = valance:CreateTexture(nil, "ARTWORK", nil, 0)
            seg.hem:SetTexture(DISC)
            seg.scallop = valance:CreateTexture(nil, "ARTWORK", nil, 0)
            seg.scallop:SetTexture(DISC)
            seg.seam = valance:CreateTexture(nil, "ARTWORK", nil, 2)
            segments[i] = seg
        end
        if seg then
            local on = i <= n
            for _, t in ipairs({ seg.left, seg.right, seg.scallop, seg.hem, seg.seam }) do t:SetShown(on) end
            if on then
                local x = (i - 1) * segW
                seg.left:ClearAllPoints()
                seg.left:SetPoint("TOPLEFT", valance, "TOPLEFT", x, -RAIL_H + 1)
                seg.left:SetSize(segW / 2 + 0.5, PANEL_H)
                seg.right:ClearAllPoints()
                seg.right:SetPoint("TOPLEFT", valance, "TOPLEFT", x + segW / 2, -RAIL_H + 1)
                seg.right:SetSize(segW / 2 + 0.5, PANEL_H)
                -- A shallow scallop for the hem, with a darker hem line peeking under it.
                seg.scallop:ClearAllPoints()
                seg.scallop:SetSize(segW + 0.5, SCALLOP_H)
                seg.scallop:SetPoint("CENTER", valance, "TOPLEFT", x + segW / 2, -(RAIL_H + PANEL_H) + 1)
                seg.hem:ClearAllPoints()
                seg.hem:SetSize(segW - 2, SCALLOP_H)
                seg.hem:SetPoint("CENTER", seg.scallop, "CENTER", 0, -1.5)
                -- Stitched seam between panels.
                seg.seam:ClearAllPoints()
                seg.seam:SetPoint("TOPLEFT", valance, "TOPLEFT", x, -RAIL_H + 1)
                seg.seam:SetSize(1, PANEL_H + 2)
                seg.seam:SetColorTexture(0, 0, 0, i == 1 and 0 or 0.35)
            end
        end
    end
    PaintSegments()
end
valance:HookScript("OnSizeChanged", function(_, w) LayoutValance(w) end)

-- The rail's shadow on the canvas.
local railShadow = valance:CreateTexture(nil, "ARTWORK", nil, 3)
railShadow:SetPoint("TOPLEFT", valance, "TOPLEFT", 0, -RAIL_H + 1)
railShadow:SetPoint("TOPRIGHT", valance, "TOPRIGHT", 0, -RAIL_H + 1)
railShadow:SetHeight(5)
Wood.Gradient(railShadow, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.5)

-- Corner posts in depth: the inner side face of each square post, receding (its far edge shorter),
-- and a knee brace from the post up to the awning rail.
local postDepth = {}
local SIDE_W, BRACE_LEN = 7, 64
for i, post in ipairs(addon.cornerPosts or {}) do
    local left = i == 1
    local f = CreateFrame("Frame", nil, ShelfFrame)
    f:SetFrameLevel(post:GetFrameLevel())
    f:SetPoint("TOP", post, "TOP", 0, -48)
    f:SetPoint("BOTTOM", post, "BOTTOM", 0, 30)
    f:SetWidth(SIDE_W)
    if left then f:SetPoint("LEFT", post, "RIGHT", 0, 0) else f:SetPoint("RIGHT", post, "LEFT", 0, 0) end
    local side = f:CreateTexture(nil, "ARTWORK", nil, 0)
    side:SetAllPoints()
    local map = Wood.ApplyGrain(side, "post", 20 + i, true, 0.55)
    f:HookScript("OnSizeChanged", function(_, w, h) map(w, h) end)
    local shade = f:CreateTexture(nil, "ARTWORK", nil, 1)
    shade:SetAllPoints()
    if left then
        Wood.Gradient(shade, "HORIZONTAL", 0, 0, 0, 0.15, 0, 0, 0, 0.55)
    else
        Wood.Gradient(shade, "HORIZONTAL", 0, 0, 0, 0.55, 0, 0, 0, 0.15)
    end
    -- Perspective: the edge away from the viewer is shorter top and bottom.
    for _, t in ipairs({ side, shade }) do
        if t.SetVertexOffset then
            if left then
                t:SetVertexOffset(UPPER_RIGHT_VERTEX or 3, 0, -3)
                t:SetVertexOffset(LOWER_RIGHT_VERTEX or 4, 0, 3)
            else
                t:SetVertexOffset(UPPER_LEFT_VERTEX or 1, 0, -3)
                t:SetVertexOffset(LOWER_LEFT_VERTEX or 2, 0, 3)
            end
        end
    end
    postDepth[#postDepth + 1] = f

    -- Knee brace, rising from the post to the rail at 45 degrees.
    local brace = CreateFrame("Frame", nil, ShelfFrame)
    brace:SetFrameLevel(post:GetFrameLevel())
    brace:SetSize(BRACE_LEN, 7)
    local dx = BRACE_LEN * 0.35
    brace:SetPoint("CENTER", valance, left and "BOTTOMLEFT" or "BOTTOMRIGHT", left and (dx + 4) or -(dx + 4), -dx + 4)
    local wood = brace:CreateTexture(nil, "ARTWORK", nil, 0)
    wood:SetAllPoints()
    Wood.ApplyGrain(wood, "post", 30 + i, false, 0.8)(BRACE_LEN, 7)
    local edge = brace:CreateTexture(nil, "ARTWORK", nil, 1)
    edge:SetPoint("BOTTOMLEFT"); edge:SetPoint("BOTTOMRIGHT"); edge:SetHeight(2)
    edge:SetColorTexture(0, 0, 0, 0.45)
    local braceShadow = brace:CreateTexture(nil, "BACKGROUND", nil, 0)
    braceShadow:SetPoint("TOPLEFT", 2, -4); braceShadow:SetPoint("BOTTOMRIGHT", 4, -6)
    braceShadow:SetColorTexture(0, 0, 0, 0.30)
    if wood.SetRotation then
        local angle = left and math.pi / 4 or -math.pi / 4
        for _, t in ipairs({ wood, edge, braceShadow }) do t:SetRotation(angle) end
        postDepth[#postDepth + 1] = brace
    end
    brace:Hide()
end
for _, f in ipairs(postDepth) do f:Hide() end
-- Only the stall has the square posts and braces; the shop indoors keeps its flat corner posts.
valance:HookScript("OnShow", function() for _, f in ipairs(postDepth) do f:Show() end end)
valance:HookScript("OnHide", function() for _, f in ipairs(postDepth) do f:Hide() end end)

-- ============================================================================
-- WILDERNESS: outdoors away from towns, the stall stands in front of the region's own trees and
-- shrubs instead of the shop's back wall.
-- ============================================================================
-- Layers, far to near. Each repeats one picture across the wall: a crop of a foliage texture
-- (its alpha cuts out the leaves), about w x h px and `step` px apart, its bottom `y` px above
-- the floor (+/- jy). `tone` darkens it; `haze` mixes in the sky colour so far layers recede.
-- `crown` = { file, crop, w, h, tone } puts a picture centred on top of each card (a tree's crown on
-- its trunk). `tint` colours the whole scene.
local ELWYNN = { -- oaks, firs and shrubs
    { file = 189703, crop = { 0.15, 1, 0, 1 }, w = 120, h = 150, step = 70, y = 170, jy = 25, tone = 0.85, haze = 0.55 },
    { file = 189702, crop = { 0.20, 1, 0, 1 }, w = 110, h = 130, step = 80, y = 150, jy = 25, tone = 0.85, haze = 0.45 },
    { file = 189934, crop = { 0.30, 0.70, 0, 1 }, w = 34, h = 380, step = 290, y = 0, tone = 0.55,
      crown = { file = 189937, crop = { 0, 1, 0, 1 }, w = 280, h = 230, tone = 0.85 } },
    { file = 189703, crop = { 0.15, 1, 0, 1 }, w = 200, h = 230, step = 150, y = 230, jy = 40, tone = 0.85, haze = 0.15 },
    { file = 189937, crop = { 0, 1, 0, 1 }, w = 280, h = 220, step = 170, y = 340, jy = 30, tone = 0.75 },
    { file = 189702, crop = { 0.20, 1, 0, 1 }, w = 230, h = 210, step = 190, y = 380, jy = 30, tone = 0.7 },
    { file = 189937, crop = { 0, 1, 0, 1 }, w = 210, h = 170, step = 160, y = -20, jy = 10, tone = 0.85 },
    { file = 189704, crop = { 0.20, 1, 0, 1 }, w = 150, h = 140, step = 110, y = -10, jy = 10, tone = 0.9 },
}
-- `ground` is the land the far layers stand on (hazed into the sky at `horizon` px).
local WILDS = {
    workshop = { tint = { 1, 1, 1 }, layers = ELWYNN, forest = "elwynn",                      -- a temperate forest anywhere else
                 ground = { 0.28, 0.36, 0.16 }, horizon = 200 },
    stormwind = { tint = { 1, 1, 1 }, layers = ELWYNN, forest = "elwynn",                     -- Elwynn Forest
                  ground = { 0.28, 0.36, 0.16 }, horizon = 200 },
    kultiras = { tint = { 1.05, 0.86, 0.64 }, layers = ELWYNN, forest = "elwynn",            -- autumn woods of Tiragarde and Drustvar
                 ground = { 0.34, 0.32, 0.16 }, horizon = 200 },
    nightelf = { -- Ashenvale and the night elf forests
        tint = { 0.82, 0.95, 1.0 }, forest = "ashenvale", ground = { 0.14, 0.24, 0.20 }, horizon = 210,
        layers = {
            { file = 201231, crop = { 0, 1, 0, 1 }, w = 130, h = 150, step = 80, y = 175, jy = 25, tone = 0.75, haze = 0.55 },
            { file = 201225, crop = { 0.20, 0.60, 0, 1 }, w = 44, h = 400, step = 260, y = 0, tone = 0.5,
              crown = { file = 201206, crop = { 0, 1, 0, 1 }, w = 280, h = 230, tone = 0.75 } },
            { file = 201206, crop = { 0, 1, 0, 1 }, w = 240, h = 200, step = 160, y = 240, jy = 40, tone = 0.8, haze = 0.15 },
            { file = 201219, crop = { 0, 1, 0, 1 }, w = 230, h = 210, step = 290, y = 140, jy = 40, tone = 0.7 },
            { file = 201231, crop = { 0, 1, 0, 1 }, w = 270, h = 210, step = 170, y = 340, jy = 30, tone = 0.65 },
            { file = 201206, crop = { 0, 1, 0, 1 }, w = 250, h = 200, step = 190, y = 370, jy = 30, tone = 0.6 },
            { file = 201231, crop = { 0, 1, 0, 1 }, w = 190, h = 130, step = 120, y = -25, jy = 10, tone = 0.7 },
        },
    },
    silvermoon = { -- Eversong Woods: golden trees on white trunks
        tint = { 1.0, 0.97, 0.9 }, forest = "eversong", ground = { 0.42, 0.44, 0.18 }, horizon = 190,
        layers = {
            { w = 140, h = 180, step = 105, y = 150, jy = 25, tone = 0.85, haze = 0.5, skip = 0.15,
              pick = { { file = 203927, crop = { 0, 0.5, 0, 1 } }, { file = 203924, crop = { 0, 0.8, 0, 1 }, s = 0.8 },
                       { file = 203927, crop = { 0, 0.5, 0, 1 }, s = 0.7 } } },
            { file = 203916, crop = { 0.80, 1, 0, 1 }, w = 30, h = 380, step = 300, y = 0, tone = 0.8,
              crown = { file = 203916, crop = { 0, 0.75, 0, 0.45 }, w = 280, h = 190, tone = 0.95 } },
            { file = 203927, crop = { 0, 0.5, 0, 1 }, w = 230, h = 300, step = 280, y = -10, jy = 15, tone = 0.95, haze = 0.1, skip = 0.2 },
            { file = 203916, crop = { 0, 0.75, 0, 0.45 }, w = 260, h = 180, step = 190, y = 380, jy = 35, tone = 0.75 },
            { w = 170, h = 150, step = 135, y = -20, jy = 15, tone = 0.85, skip = 0.2,
              pick = { { file = 203924, crop = { 0, 0.8, 0, 1 } }, { file = 203925, crop = { 0.33, 1, 0, 1 }, s = 0.9 },
                       { file = 203924, crop = { 0, 0.8, 0, 1 }, s = 0.7 }, { file = 203927, crop = { 0, 0.5, 0, 1 }, s = 1.1 } } },
        },
    },
    orgrimmar = { -- Durotar and the Barrens: acacias, dry scrub and cactus on red earth
        tint = { 1.0, 0.92, 0.80 }, forest = "barrens", ground = { 0.50, 0.30, 0.17 }, horizon = 180,
        layers = {
            { w = 150, h = 70, step = 140, y = 165, jy = 15, tone = 0.8, haze = 0.6, skip = 0.25,
              pick = { { file = 304799, crop = { 0.15, 1, 0, 0.48 } }, { file = 304799, crop = { 0.15, 1, 0.5, 1 }, s = 0.8 },
                       { file = 201360, crop = { 0, 1, 0, 0.5 }, s = 0.9 } } },
            { w = 120, h = 90, step = 95, y = 115, jy = 18, tone = 0.8, haze = 0.5, skip = 0.3,
              pick = { { file = 201773, crop = { 0, 1, 0, 1 } }, { file = 201360, crop = { 0, 1, 0.5, 1 }, s = 0.8 },
                       { file = 201773, crop = { 0, 1, 0, 1 }, s = 0.6 } } },
            { file = 201393, crop = { 0.40, 0.60, 0, 1 }, w = 24, h = 300, step = 360, y = 0, tone = 0.6,
              crown = { file = 304799, crop = { 0.15, 1, 0, 0.48 }, w = 320, h = 140, tone = 0.85 } },
            { w = 160, h = 150, step = 130, y = -15, jy = 15, tone = 0.85, skip = 0.25,
              pick = { { file = 201773, crop = { 0, 1, 0, 1 } }, { file = 201772, crop = { 0, 0.72, 0, 0.55 }, s = 0.75 },
                       { file = 201773, crop = { 0, 1, 0, 1 }, s = 0.7 }, { file = 201360, crop = { 0, 1, 0.5, 1 }, s = 0.9 } } },
        },
    },
}
-- Draw layer and sublevel per scene layer, so nearer layers always draw on top.
local DEPTH = {
    { "BORDER", -6 }, { "BORDER", 0 }, { "BORDER", 6 }, { "ARTWORK", -6 },
    { "ARTWORK", 0 }, { "ARTWORK", 6 }, { "OVERLAY", -6 }, { "OVERLAY", 0 },
}

local wild = CreateFrame("Frame", nil, backboard)
wild:SetAllPoints()
wild:SetFrameLevel(backboard:GetFrameLevel() + 2)
wild:Hide()
local wildSky = wild:CreateTexture(nil, "BACKGROUND", nil, -8)
wildSky:SetAllPoints()
local wildGround = wild:CreateTexture(nil, "BACKGROUND", nil, -7)
wildGround:SetPoint("BOTTOMLEFT"); wildGround:SetPoint("BOTTOMRIGHT")
-- Foliage is alpha-tested in the world (hard leaf edges). Retail does the same here; WoW Forever
-- draws alpha-tested textures solid, so there (or wherever the mode isn't taken) cards blend.
local CUTOUT = "ALPHAKEY"
do
    local probe = wild:CreateTexture()
    probe:SetBlendMode("ALPHAKEY")
    if addon.IS_FOREVER or (probe.GetBlendMode and probe:GetBlendMode() ~= "ALPHAKEY") then CUTOUT = "BLEND" end
    probe:Hide()
end
local cards, wildScene = {}, nil
local forestOn = false -- the 3D forest is showing (the picture cards are hidden)
local forest, forestHorizon -- the 3D forest showing, and its measured horizon (see WILDERNESS IN 3D)
local forestCam = 3         -- camera height in use (raised so no model comes too close)
local MIN_FOREST_DEPTH = 90 -- models nearer than this to the forest camera hide the vendor in game
local PlaceForestHook -- set once the 3D forest code below is defined
local laidW, laidH, laidScene -- what the cards are laid out for

local function SceneLoadable(scene)
    for _, L in ipairs(scene.layers) do
        if L.file and not Wood.CanLoad(L.file) then return false end
        if L.crown and not Wood.CanLoad(L.crown.file) then return false end
        for _, p in ipairs(L.pick or {}) do
            if not Wood.CanLoad(p.file) then return false end
        end
    end
    return true
end

-- One card: picture `spec` (file, crop) at x, y (bottom-left), w x h, in draw slot `depth`.
local used = 0
local function Card(spec, depth, sub, x, y, w, h, flip, colours)
    used = used + 1
    local t = cards[used]
    if not t then
        t = wild:CreateTexture()
        cards[used] = t
    end
    t:SetDrawLayer(depth[1], depth[2] + sub)
    t:SetTexture(spec.file)
    t:SetBlendMode(CUTOUT)
    local c = spec.crop
    if flip then t:SetTexCoord(c[2], c[1], c[3], c[4]) else t:SetTexCoord(c[1], c[2], c[3], c[4]) end
    t:ClearAllPoints()
    t:SetPoint("BOTTOMLEFT", wild, "BOTTOMLEFT", x, y)
    t:SetSize(w, h)
    t.layer = colours or spec
    t:Show()
end

-- Lay the scene's cards out across the wall (the same every time for the same size).
local function LayoutWild()
    local scene = wildScene
    if forestOn then return end
    local W, H = backboard:GetWidth(), backboard:GetHeight()
    if not scene or not W or W <= 0 then return end
    laidW, laidH, laidScene = W, H, scene
    used = 0
    for li, L in ipairs(scene.layers) do
        local seed = li * 7919 + 17
        local function Rand()
            seed = (seed * 16807) % 2147483647
            return seed / 2147483647
        end
        local depth = DEPTH[math.min(li, #DEPTH)]
        local x = -Rand() * L.step
        while x < W do
            local cw, ch = L.w * (0.85 + Rand() * 0.3), L.h * (0.85 + Rand() * 0.3)
            local y = L.y + (Rand() - 0.5) * 2 * (L.jy or 0)
            local flip = Rand() < 0.5
            -- A layer may mix several pictures (`pick`, each with an optional size `s`) and leave
            -- gaps (`skip` = share of spots left empty), so it doesn't repeat in a row.
            local spec = L
            if L.pick then
                spec = L.pick[1 + math.floor(Rand() * #L.pick) % #L.pick]
                cw, ch = cw * (spec.s or 1), ch * (spec.s or 1)
            end
            if not (L.skip and Rand() < L.skip) then
                Card(spec, depth, 0, x, y, cw, ch, flip, L)
                local cr = L.crown
                if cr then
                    local kw, kh = cr.w * (0.9 + Rand() * 0.2), cr.h * (0.9 + Rand() * 0.2)
                    Card(cr, depth, 1, x + cw / 2 - kw / 2, y + ch - kh * 0.35, kw, kh, Rand() < 0.5)
                end
            end
            x = x + L.step * (0.8 + Rand() * 0.4)
        end
    end
    for i = used + 1, #cards do cards[i]:Hide() end
end
backboard:HookScript("OnSizeChanged", function(_, _, h)
    if not wild:IsShown() then return end
    if forestOn then
        if PlaceForestHook then PlaceForestHook() end
        if h then wildGround:SetHeight(h * (forestHorizon or (forest and forest.horizon) or 0.5)) end
    else
        LayoutWild()
    end
end)

-- Colours for the time of day: the sky behind, and each layer hazed toward the horizon colour.
local function PaintWild(sk)
    local scene = wildScene
    if not scene then return end
    local top, bot, tint = sk.top, sk.bottom, scene.tint
    Wood.Gradient(wildSky, "VERTICAL", bot[1], bot[2], bot[3], 1, top[1], top[2], top[3], 1)
    local gr = scene.ground or { 0.3, 0.3, 0.2 }
    local light = 0.35 + 0.65 * sk.day
    wildGround:SetHeight(forestOn and (wild:GetHeight() or 500) * (forestHorizon or (forest and forest.horizon) or 0.5) or scene.horizon or 190)
    Wood.Gradient(wildGround, "VERTICAL",
        gr[1] * light * tint[1], gr[2] * light * tint[2], gr[3] * light * tint[3], 1,
        (gr[1] * light * 0.4 + bot[1] * 0.6), (gr[2] * light * 0.4 + bot[2] * 0.6), (gr[3] * light * 0.4 + bot[3] * 0.6), 1)
    for _, t in ipairs(cards) do
        local L = t.layer
        if L and t:IsShown() then
            local k, hz = L.tone or 1, L.haze or 0
            t:SetVertexColor(
                (k * (1 - hz) + bot[1] * hz) * tint[1],
                (k * (1 - hz) + bot[2] * hz) * tint[2],
                (k * (1 - hz) + bot[3] * hz) * tint[3], 1)
        end
    end
end

-- ============================================================================
-- WILDERNESS IN 3D: the region's own tree and bush models, drawn by the engine
-- ============================================================================
-- A model scene the size of the back wall, its camera level at a standing eye height: the horizon
-- (`horizon`, share of the wall height from the bottom) runs about through the vendor's eyes, as it
-- does when you stand on the same ground. Rows are laid out in screen terms: `base` is where a
-- tree's foot stands (share of the wall height from the bottom, below the horizon) and `size` how
-- tall it looks (share of the wall height). The distance follows from the base (lower = nearer) and
-- the model is scaled to look that tall there, so every tree stands on the same ground.
-- The nearest trees stand just above the counter top so their trunks show behind the vendor (trees
-- whose feet were hidden behind the counter looked like crowns lying on the ground). Only
-- whole-tree models: Elwynn's big oaks are a trunk plus a separate canopy model.
-- The scene is scaled so every model is at least MIN_FOREST_DEPTH from the camera: the 3D views
-- share one depth buffer, so a near tree would hide the vendor. Huge scales and distances get
-- culled, so the far rows stay within ~800 units. The models keep their own animation (leaves sway
-- in the wind); far rows are partly see-through, like haze.
local FORESTS = {
    elwynn = {
        camH = 3, fov = 0.95, horizon = 0.75, ground = { file = 187126, tile = 3 }, -- elwynngrassbase
        rows = {
            { files = { 189932, 189923, 189924, 189925 }, count = 16, base = { 0.62, 0.66 }, size = { 0.24, 0.32 }, alpha = 0.6 },
            { files = { 189932, 189923, 189924, 189925 }, count = 9, base = { 0.49, 0.57 }, size = { 0.40, 0.52 }, alpha = 0.85 },
            { files = { 189932, 189932, 189923 }, count = 5, base = { 0.43, 0.47 }, size = { 0.62, 0.80 } },
            { files = { 189795 }, count = 22, base = { 0.10, 0.10 }, size = { 0.46, 0.46 }, fence = true, camBase = -0.02 }, -- elwynnwoodfence01
            { files = { 189692, 189693, 189694, 189695, 189696, 189697, 189698 }, count = 12, base = { 0.26, 0.38 }, size = { 0.08, 0.13 } },
            { files = { 189692, 189693, 189694, 189695, 189696, 189697, 189698 }, count = 16, base = { 0.03, 0.12 }, size = { 0.16, 0.26 } },
        },
    },
    ashenvale = {
        camH = 3, fov = 0.95, horizon = 0.75, ground = { file = 186836, tile = 3 }, -- ashenvalemossbase
        rows = {
            { files = { 201223, 201224, 201226, 201228, 201230 }, count = 11, base = { 0.62, 0.66 }, size = { 0.22, 0.30 }, alpha = 0.6 },
            { files = { 201223, 201224, 201226, 201228, 201230 }, count = 5, base = { 0.49, 0.57 }, size = { 0.36, 0.48 }, alpha = 0.85 },
            { files = { 201223, 201224, 201226, 201228, 201230 }, count = 4, base = { 0.43, 0.47 }, size = { 0.56, 0.70 } },
            { files = { 1379080 }, tex = 1379088, fallback = 189795, fallbackSize = { 0.46, 0.46 }, count = 22, base = { 0.10, 0.10 }, size = { 0.42, 0.42 }, fence = true, camBase = -0.05 }, -- 7ne_druid_fence01 (else elwynnwoodfence01)
            { files = { 189692, 189693, 189694, 189695, 189696, 189697, 189698 }, count = 10, base = { 0.03, 0.12 }, size = { 0.10, 0.16 } },
        },
    },
    eversong = {
        camH = 3, fov = 0.95, horizon = 0.75, ground = { file = 187276, tile = 3 }, -- eversonggrass02
        rows = {
            { files = { 203950, 203951, 203952, 203953, 203954, 203955, 203956 }, count = 15, base = { 0.62, 0.66 }, size = { 0.22, 0.30 }, alpha = 0.6 },
            { files = { 203950, 203951, 203952, 203953, 203954, 203955, 203956 }, count = 8, base = { 0.49, 0.57 }, size = { 0.38, 0.50 }, alpha = 0.85 },
            { files = { 203950, 203951, 203952, 203953, 203954, 203955, 203956 }, count = 5, base = { 0.43, 0.47 }, size = { 0.58, 0.76 } },
            { files = { 191771 }, count = 22, base = { 0.10, 0.10 }, size = { 0.58, 0.58 }, fence = true, camBase = -0.02 }, -- be_fence_eversong01
            { files = { 203942, 203943, 203944, 203945, 203946, 203947, 203948, 203949 }, count = 9, base = { 0.26, 0.38 }, size = { 0.24, 0.32 } },
            { files = { 203942, 203943, 203944, 203945, 203946, 203947, 203948, 203949 }, count = 11, base = { 0.03, 0.12 }, size = { 0.30, 0.40 } },
        },
    },
    barrens = {
        camH = 3, fov = 0.95, horizon = 0.75, ground = { file = 187017, tile = 3 }, -- durotardirt
        rows = {
            { files = { 201774, 201775, 201776, 201777, 201778, 201779, 201780, 201781 }, count = 8, base = { 0.64, 0.67 }, size = { 0.12, 0.22 }, alpha = 0.55 },
            { files = { 201394, 201396, 201398, 201399, 201400, 201402, 201403 }, count = 9, base = { 0.52, 0.60 }, size = { 0.24, 0.34 }, alpha = 0.8 },
            { files = { 201394, 201396, 201398, 201399, 201400, 201402, 201403 }, count = 4, base = { 0.43, 0.47 }, size = { 0.45, 0.60 } },
            { files = { 850522 }, tex = 850499, fallback = 199209, fallbackSize = { 0.48, 0.48 }, count = 22, base = { 0.10, 0.10 }, size = { 0.52, 0.52 }, fence = true, camBase = -0.02 }, -- 6oc_orcclans_fence01 (else orcfence)
            { files = { 201768, 201769, 201770, 201771 }, count = 12, base = { 0.26, 0.40 }, size = { 0.07, 0.12 } },
            { files = { 201768, 201769, 201770, 201771, 201766 }, count = 14, base = { 0.03, 0.12 }, size = { 0.12, 0.20 } },
        },
    },
}

local forestScene, forestKey
local forestActors = {}
local forestF -- measured px per (unit / depth): screen px = F * size / depth
local pitchSign = -1 -- which way the engine tilts for a positive pitch (set from in-game testing)
local forestRight = 1 -- +1 when the scene's +Y runs to the right on screen (measured)

-- Engine scale for this scene: project a point straight ahead and one unit to its side.
local function MeasureForestF()
    local sc = forestScene
    if not (sc and sc.Project3DPointTo2D) then return nil end
    local sw = sc:GetWidth() or 0
    local cam = forestCam
    local ok0, x0 = pcall(sc.Project3DPointTo2D, sc, -50, 0, cam)
    local ok1, x1 = pcall(sc.Project3DPointTo2D, sc, -50, 1, cam)
    if not (ok0 and ok1 and type(x0) == "number" and type(x1) == "number") or sw <= 0 or x0 <= 0 then return nil end
    local k = x0 / (sw / 2) -- engine units per UI px (the point straight ahead lands mid-screen)
    local px = math.abs(x1 - x0) / k
    forestRight = (x1 >= x0) and 1 or -1
    if px <= 0 then return nil end
    return px * 50
end

local function EstimateForestF(W, H, fov)
    return math.sqrt(W * W + H * H) / (2 * math.tan(fov / 2)) * (addon.Showroom.lensFactor or 1)
end

local function ForestScene()
    if forestScene == nil then
        forestScene = false
        local ok, sc = pcall(CreateFrame, "ModelScene", nil, wild, "NoCameraControlModelSceneMixinTemplate")
        if ok and sc then
            sc:SetAllPoints(wild)
            sc:SetFrameLevel(wild:GetFrameLevel() + 1)
            sc:EnableMouse(false)
            sc:SetScript("OnMouseWheel", nil)
            sc:EnableMouseWheel(false)
            sc:SetCameraOrientationByYawPitchRoll(math.pi, 0, 0)
            -- A tiny near clip puts every tree at the far end of the shared depth buffer, behind the
            -- vendor, mirror and plinth models (depth is relative to each camera's near clip).
            if sc.SetCameraNearClip then pcall(sc.SetCameraNearClip, sc, 0.01) end
            if sc.SetCameraFarClip then pcall(sc.SetCameraFarClip, sc, 5000) end
            forestScene = sc
        end
    end
    return forestScene or nil
end

-- Out in the wilds the stall's floor (under the counter, plinth and mirror) becomes the same ground,
-- so the vendor stands on the land rather than on a wooden stage above it. The deck fades out at
-- its back edge into the ground behind.
local floorOverlays
local function FloorGround(show, file, tilePx, r, g, b)
    local floors = addon.Showroom.floors
    if not floors then return end
    if not floorOverlays then
        if not show then return end
        floorOverlays = {}
        for _, f in ipairs(floors) do
            for _, part in ipairs({ f.front, f.deck }) do
                local o = CreateFrame("Frame", nil, part:GetParent())
                o:SetAllPoints(part)
                o:SetFrameLevel(part:GetFrameLevel())
                o.tex = o:CreateTexture(nil, "ARTWORK")
                o.tex:SetAllPoints()
                o.part, o.isDeck = part, part == f.deck
                o:Hide()
                floorOverlays[#floorOverlays + 1] = o
            end
        end
    end
    for _, o in ipairs(floorOverlays) do
        o.part:SetAlpha(show and 0 or 1)
        o:SetShown(show)
        if show then
            local w, h = o.part:GetWidth() or 100, o.part:GetHeight() or 20
            o.tex:SetTexture(file, "REPEAT", "REPEAT")
            o.tex:SetTexCoord(0, w / tilePx, 0, h / (tilePx * (o.isDeck and 0.45 or 0.8)))
            if o.isDeck then
                o.tex:SetGradient("VERTICAL", CreateColor(r, g, b, 1), CreateColor(r * 0.8, g * 0.8, b * 0.8, 0))
            else
                o.tex:SetGradient("VERTICAL", CreateColor(r * 0.85, g * 0.85, b * 0.85, 1), CreateColor(r, g, b, 1))
            end
        end
    end
end

-- The ground: the zone's own terrain texture laid flat to the horizon in perspective, as thin
-- strips (each mapped for its own distance and width), so the grass is big by the stall and
-- shrinks toward the horizon, with the same maths that stands the trees on it. A haze gradient
-- fades the far ground into the sky.
local groundTilePx = 64 -- on-screen size of one ground tile at the floor line (set by LayGround)
local GROUND_STRIPS = 40
local groundStrips = {}
local groundHaze = wild:CreateTexture(nil, "BACKGROUND", nil, -5)
groundHaze:SetPoint("LEFT"); groundHaze:SetPoint("RIGHT")
groundHaze:Hide()

local function HideGround()
    for _, t in ipairs(groundStrips) do t:Hide() end
    groundHaze:Hide()
    FloorGround(false)
end

local function LayGround()
    local g = forest and forest.ground
    if not (g and forestOn and Wood.CanLoad(g.file)) then HideGround(); return end
    local W, H = wild:GetWidth(), wild:GetHeight()
    if not W or W <= 0 or not H or H <= 0 then return end
    local F = forestF or EstimateForestF(W, H, forest.fov)
    local hzPx = (forestHorizon or forest.horizon or 0.5) * H
    local T = (g.tile or 8) * forestCam / 1.7   -- tile size in scene units (eye height ~1.7 yards)
    groundTilePx = math.max(8, T * hzPx / forestCam) -- the nearest tile, where the ground meets the floor
    local prevY = 0
    for i = 1, GROUND_STRIPS do
        -- Strips get thinner toward the horizon, where the ground compresses.
        local y1 = math.min(hzPx - 0.75, hzPx * (1 - (1 - i / GROUND_STRIPS) ^ 2.6))
        local y0 = prevY
        prevY = y1
        local t = groundStrips[i]
        if not t then
            t = wild:CreateTexture(nil, "BACKGROUND", nil, -6)
            groundStrips[i] = t
        end
        if y1 - y0 < 0.25 then
            t:Hide()
        else
            local d0 = forestCam * F / (hzPx - y0)   -- distance of the strip's near edge
            local d1 = forestCam * F / (hzPx - y1)   -- and of its far edge
            local halfW = (W / 2) * ((d0 + d1) / 2) / F
            t:SetTexture(g.file, "REPEAT", "REPEAT")
            t:SetTexCoord(-halfW / T, halfW / T, d1 / T, d0 / T)
            t:ClearAllPoints()
            t:SetPoint("BOTTOMLEFT", wild, "BOTTOMLEFT", 0, y0)
            t:SetPoint("BOTTOMRIGHT", wild, "BOTTOMRIGHT", 0, y0)
            t:SetHeight(y1 - y0)
            t:Show()
        end
    end
    groundHaze:ClearAllPoints()
    groundHaze:SetPoint("BOTTOMLEFT", wild, "BOTTOMLEFT", 0, hzPx * 0.35)
    groundHaze:SetPoint("BOTTOMRIGHT", wild, "BOTTOMRIGHT", 0, hzPx * 0.35)
    groundHaze:SetHeight(hzPx * 0.65 + 1)
    groundHaze:Show()
end

-- Light on the ground for the time of day, and the haze in the horizon's colour.
local function PaintGround(sk, tint)
    tint = tint or { 1, 1, 1 }
    local k = 0.40 + 0.60 * sk.day
    for _, t in ipairs(groundStrips) do t:SetVertexColor(k * tint[1], k * tint[2], k * tint[3], 1) end
    local g = forest and forest.ground
    if forestOn and g and Wood.CanLoad(g.file) then
        FloorGround(true, g.file, groundTilePx, k * tint[1], k * tint[2], k * tint[3])
    end
    local b = sk.bottom
    Wood.Gradient(groundHaze, "VERTICAL", b[1], b[2], b[3], 0, b[1], b[2], b[3], 0.85)
end

-- Place every model of the current forest (after each has been measured).
local function PlaceForest()
    local sc = forestScene
    if not (sc and forest) then return end
    local W, H = wild:GetWidth(), wild:GetHeight()
    if not W or W <= 0 then return end
    local F = forestF or EstimateForestF(W, H, forest.fov)
    for _, a in ipairs(forestActors) do
        if a.boxH and a.boxH > 0 then
            local hz = forestHorizon or forest.horizon or 0.5
            if hz - a.base < 0.02 then
                a.actor:Hide() -- a foot at the horizon would be infinitely far away
                a.placed = false
            else
                local depth = forestCam * F / ((hz - a.base) * H) -- its foot lands at a.base
                local height = a.size * H * depth / F                 -- it looks a.size tall
                local hw = (W / 2) / F * depth * 1.15                 -- half the view's width there, plus a margin
                local scale = height / a.boxH
                a.actor:SetScale(scale)
                a.placed, a.depth, a.scale = true, depth, scale
                if a.fence then
                    -- Fence sections end to end in a straight line, each turned to run sideways.
                    -- An actor's position is in its own scaled frame (the engine multiplies it by the
                    -- scale; see HousingDecorGuide), so the distance is handed over divided by the scale,
                    -- and the spacing is just the section's own length. Feet on the ground: -minZ.
                    local along = math.max(a.boxX or 0, a.boxY or 0, 0.01)
                    a.actor:SetYaw((a.boxX or 0) > (a.boxY or 0) and math.pi / 2 or 0)
                    -- A joint between two sections (where a post stands) falls in the gap left of the vendor,
                    -- so the rails behind the vendor meet a post instead of floating loose.
                    local joint = 0
                    local vz = addon.Showroom and addon.Showroom.vendorZone
                    local vx, wx = vz and vz:GetCenter(), wild:GetCenter()
                    if vx and wx then
                        joint = (vx - wx + (vz:GetWidth() or 0) * -0.42) * depth / F * forestRight / scale
                    end
                    a.actor:SetPosition(-depth / scale, joint + (a.index - a.count / 2 - 0.5) * along * 0.97, -(a.boxZ0 or 0))
                else
                    a.actor:SetPosition(-depth, (a.slot * 2 - 1) * hw, 0)
                end
                a.actor:Show()
            end
        end
    end
    LayGround()
end

local function LightForest(sk, tint)
    local sc = forestScene
    if not sc then return end
    tint = tint or { 1, 1, 1 }
    PaintGround(sk, tint)
    local d, w = sk.day, sk.warm
    local amb = LerpRGB({ 0.42, 0.46, 0.60 }, { 0.62, 0.62, 0.60 }, d)
    local dif = LerpRGB({ 0.30, 0.34, 0.52 }, { 0.95, 0.90, 0.80 }, d)
    dif = LerpRGB(dif, { 1.0, 0.62, 0.35 }, w * 0.6)
    sc:SetLightAmbientColor(amb[1] * tint[1], amb[2] * tint[2], amb[3] * tint[3])
    sc:SetLightDiffuseColor(dif[1] * tint[1], dif[2] * tint[2], dif[3] * tint[3])
    sc:SetLightDirection(-0.6, 0.4, -0.7)
end

-- Load the forest's models (once per forest); they are placed as their sizes arrive.
local function BuildForest(key)
    local sc = ForestScene()
    local spec = FORESTS[key]
    if not (sc and spec) or spec.failed then return false end
    sc:Show()
    if forestKey == key then PlaceForest(); return true end
    forestKey, forest, forestF = key, spec, nil
    for _, a in ipairs(forestActors) do a.actor:ClearModel(); a.actor:Hide() end
    local n, seed = 0, 4242
    local function Rand()
        seed = (seed * 16807) % 2147483647
        return seed / 2147483647
    end
    local W, H = wild:GetWidth() or 1000, wild:GetHeight() or 500
    sc:SetCameraFieldOfView(spec.fov)
    local F0 = EstimateForestF(W, H, spec.fov)
    -- Scale the whole scene up (same picture) until its nearest model is MIN_FOREST_DEPTH away:
    -- the 3D views share a depth buffer, and a model close to its camera hides the vendor.
    local minBase = 1
    for _, row in ipairs(spec.rows) do minBase = math.min(minBase, row.camBase or row.base[1]) end -- camBase: keeps the camera where the trees were tuned
    forestCam = math.max(spec.camH, MIN_FOREST_DEPTH * ((spec.horizon or 0.5) - minBase) * H / F0)
    sc:SetCameraPosition(0, 0, forestCam)
    local pitch = math.atan((0.5 - (spec.horizon or 0.5)) * H / F0)
    sc:SetCameraOrientationByYawPitchRoll(math.pi, pitchSign * pitch, 0)
    forestHorizon = nil
    for ri, row in ipairs(spec.rows) do
        -- A model can load while its textures are missing (Forever lacks the later ones and draws
        -- them as a checkerboard), so check the texture first and use the older model then.
        -- (On Forever the missing texture may still report as loadable, so it always takes the older one.)
        local old = row.fallback and row.tex and (addon.IS_FOREVER or not Wood.CanLoad(row.tex)) and true
        for i = 1, row.count do
            n = n + 1
            local a = forestActors[n]
            if not a then
                local ok, actor = pcall(sc.CreateActor, sc, nil, "ModelSceneActorTemplate")
                if not ok or not actor then return n > 1 end
                if actor.SetUseCenterForOrigin then actor:SetUseCenterForOrigin(true, true, false) end
                a = { actor = actor }
                forestActors[n] = a
                actor:SetOnModelLoadedCallback(function()
                    local tries = 0
                    local function Read()
                        local minX, minY, minZ, maxX, maxY, maxZ = actor:GetActiveBoundingBox()
                        if minZ and maxZ and maxZ > minZ then
                            a.boxH = maxZ - minZ
                            a.boxZ0 = minZ
                            a.boxX, a.boxY = (maxX or 0) - (minX or 0), (maxY or 0) - (minY or 0)
                            PlaceForest()
                        elseif tries < 30 then
                            tries = tries + 1
                            C_Timer.After(0.1, Read)
                        end
                    end
                    Read()
                end)
            end
            a.boxH = nil
            a.base = row.base[1] + Rand() * (row.base[2] - row.base[1])
            local size = old and row.fallbackSize or row.size
            a.size = size[1] + Rand() * (size[2] - size[1])
            a.slot = (i - 0.5 + (Rand() - 0.5) * 0.8) / row.count -- evenly spread, jittered
            a.fence, a.index, a.count = row.fence, i, row.count
            a.row, a.placed = ri, false
            a.actor:Hide()
            local turn = Rand() * math.pi * 2
            a.actor:SetYaw(row.fence and 0 or turn) -- fences load straight, so their length can be measured
            if a.actor.SetAlpha then a.actor:SetAlpha(row.alpha or 1) end
            local file = row.files[1 + math.floor(Rand() * #row.files) % #row.files]
            a.actor:SetModelByFileID(old and row.fallback or file)
            if row.fallback and not old then
                -- A client without this model (Forever lacks some later ones): use the older one.
                local token = a
                C_Timer.After(2.5, function()
                    if forestKey == key and a.row == ri and not a.boxH and token == a then
                        a.actor:SetModelByFileID(row.fallback)
                    end
                end)
            end
        end
    end
    for i = n + 1, #forestActors do forestActors[i].actor:ClearModel(); forestActors[i].actor:Hide() end
    -- If no model loads (a client without these files), use the picture cards instead.
    C_Timer.After(3, function()
        if forestKey ~= key then return end
        for _, a in ipairs(forestActors) do if a.boxH then return end end
        spec.failed, forestKey = true, nil
        addon.SafeCall(Ambience.Refresh)
    end)
    -- Measure the engine's projection once the camera is applied, then re-place to match it.
    C_Timer.After(0, function()
        local F = MeasureForestF()
        if F then
            forestF = F
            -- Re-aim the tilt with the measured lens, so the horizon lands where the ground is drawn
            -- (the first aim used an estimate). The tilt direction is fixed from in-game testing.
            local hz = spec.horizon or 0.5
            sc:SetCameraOrientationByYawPitchRoll(math.pi, pitchSign * math.atan((0.5 - hz) * H / F), 0)
        end
        forestHorizon = spec.horizon or 0.5
        PlaceForest()
        if forestOn then wildGround:SetHeight((forestHorizon or spec.horizon or 0.5) * (wild:GetHeight() or 500)) end
    end)
    return true
end

PlaceForestHook = PlaceForest

-- /venstore forest: what the 3D wilderness has loaded and where it put it (for tuning and reports).
function Ambience.ForestReport()
    local out = "|cffffd100VenStore:|r "
    if not (forest and forestOn) then
        print(out .. "no 3D wilderness is showing (open a vendor with the place set to Wilds).")
        return
    end
    local W, H = wild:GetWidth() or 0, wild:GetHeight() or 0
    local F = forestF or EstimateForestF(W, H, forest.fov)
    print(out .. string.format("forest %s: wall %.0f x %.0f px, lens %s%.0f, horizon %.2f, camera height %.1f",
        tostring(forestKey), W, H, forestF and "" or "~", F, forestHorizon or forest.horizon or 0.5, forestCam))
    for ri, row in ipairs(forest.rows) do
        local total, loaded, placed, sample = 0, 0, 0, nil
        for _, a in ipairs(forestActors) do
            if a.row == ri and a.actor then
                total = total + 1
                if a.boxH then loaded = loaded + 1 end
                if a.placed then placed = placed + 1; sample = sample or a end
            end
        end
        local line = string.format("  row %d%s: %d models, %d loaded, %d placed", ri, row.fence and " (fence)" or "",
            total, loaded, placed)
        if sample then
            local px = sample.boxH * sample.scale * F / sample.depth
            line = line .. string.format(", e.g. %.0f units away, %.0f px tall", sample.depth, px)
            if row.fence then
                local along = math.max(sample.boxX or 0, sample.boxY or 0)
                line = line .. string.format("; box %.1f x %.1f x %.1f, section %.0f px long, turned %s",
                    sample.boxX or 0, sample.boxY or 0, sample.boxH, along * sample.scale * F / sample.depth,
                    (sample.boxX or 0) > (sample.boxY or 0) and "90 degrees" or "0")
            end
        end
        print(line)
    end
end

local function HideForest()
    if forestScene then forestScene:Hide() end
    HideGround()
end

-- Shows the region's wilderness; false when the theme has none (or the client lacks its files).
local function ShowWild(key, sk)
    local scene = WILDS[key]
    if not scene then wild:Hide(); return false end
    -- In 3D where the region has a forest of models; the picture cards otherwise.
    if scene.forest and BuildForest(scene.forest) then
        forestOn, wildScene, laidScene = true, scene, nil
        for _, t in ipairs(cards) do t:Hide() end
        wild:Show()
        PaintWild(sk)
        wildGround:SetHeight((forestHorizon or (FORESTS[scene.forest] or {}).horizon or 0.5) * (wild:GetHeight() or 500)) -- ground up to the horizon
        LightForest(sk, scene.tint)
        return true
    end
    forestOn = false
    HideForest()
    if not SceneLoadable(scene) then wild:Hide(); return false end
    wildScene = scene
    if laidScene ~= scene or laidW ~= backboard:GetWidth() or laidH ~= backboard:GetHeight() then LayoutWild() end
    wild:Show()
    PaintWild(sk)
    return true
end

-- ============================================================================
-- FIRE: wall torches indoors and a candle on the counter outdoors, lit from dusk to dawn
-- ============================================================================
-- Flames are the game's own soft glow (stretched into a flame and a bright core) with its fire
-- wisp animation licking off the top. They flicker, and outdoors they lean in the wind.
local GLOW_FILE = 1100044   -- genericglow_alpha_128: soft round glow
local WISP_FILE = 1100045   -- t_vfx_fire_anim_stylized_desat_02: 2 x 2 frames of fire wisps
local function GlowTexture(tex)
    if Wood.CanLoad(GLOW_FILE) then tex:SetTexture(GLOW_FILE) else tex:SetTexture(DISC) end
    tex:SetBlendMode("ADD")
end

local flames = {}

-- A flame standing on `base` (a frame; the flame's foot is its top centre), `size` px tall.
local function Flame(parent, base, size, seed)
    local f = { seed = seed, size = size, base = base, wind = 0 }
    f.halo = parent:CreateTexture(nil, "BACKGROUND", nil, 7)
    GlowTexture(f.halo)
    f.halo:SetSize(size * 5, size * 5)
    f.halo:SetPoint("CENTER", base, "TOP", 0, size * 0.45)
    f.outer = parent:CreateTexture(nil, "OVERLAY", nil, 5)
    GlowTexture(f.outer)
    f.core = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    GlowTexture(f.core)
    if Wood.CanLoad(WISP_FILE) then
        f.wisp = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        f.wisp:SetTexture(WISP_FILE)
        f.wisp:SetBlendMode("ADD")
        f.wisp:SetVertexColor(1, 0.55, 0.18, 0.9)
    end
    flames[#flames + 1] = f
    return f
end

local function SetFlameLit(f, lit)
    f.lit = lit
    f.halo:SetShown(lit); f.outer:SetShown(lit); f.core:SetShown(lit)
    if f.wisp then f.wisp:SetShown(lit) end
    if f.pool then f.pool:SetShown(lit) end
end

-- One frame of flicker. `t` = time, `wind` = how hard the breeze pushes (0 indoors).
local function UpdateFlame(f, t, wind)
    if f.sheltered then wind = wind * 0.35 end -- behind glass: it flickers but hardly leans
    local s, k = f.size, f.seed
    local n = 0.82 + 0.10 * math.sin(t * 11 + k) + 0.06 * math.sin(t * 23.7 + k * 2)
        + (math.random() - 0.5) * (0.06 + 0.10 * wind)
    local lean = wind * (0.55 * math.sin(t * 1.7 + k) + 0.30 * math.sin(t * 4.3 + k * 3)
        + (math.random() - 0.5) * 0.25)
    local dx = lean * s * 0.35
    f.outer:ClearAllPoints()
    f.outer:SetSize(s * 0.55, s * n)
    f.outer:SetPoint("BOTTOM", f.base, "TOP", dx * 0.6, -s * 0.12)
    f.outer:SetVertexColor(1, 0.50, 0.14, 0.85 * n)
    f.core:ClearAllPoints()
    f.core:SetSize(s * 0.28, s * 0.55 * n)
    f.core:SetPoint("BOTTOM", f.base, "TOP", dx * 0.3, -s * 0.05)
    f.core:SetVertexColor(1, 0.93, 0.70, 0.95)
    f.halo:SetVertexColor(1, 0.62, 0.28, (f.haloAlpha or 0.30) * (0.80 + 0.25 * n))
    if f.pool then f.pool:SetVertexColor(1, 0.66, 0.32, 0.40 * (0.80 + 0.25 * n)) end
    if f.wisp then
        local frame = math.floor(t * 9 + k) % 4
        local u, v = (frame % 2) * 0.5, math.floor(frame / 2) * 0.5
        f.wisp:SetTexCoord(u, u + 0.5, v, v + 0.5)
        f.wisp:ClearAllPoints()
        f.wisp:SetSize(s * 0.9, s * 0.9)
        f.wisp:SetPoint("BOTTOM", f.base, "TOP", dx, s * 0.25 * n)
    end
end

-- Wall torches either side of the window: an iron plate and cup on a wooden handle.
local function Torch(seed)
    local holder = CreateFrame("Frame", nil, backboard)
    holder:SetSize(14, 44)
    holder:SetFrameLevel(backboard:GetFrameLevel() + 3)
    local plate = holder:CreateTexture(nil, "ARTWORK", nil, 0)
    plate:SetSize(10, 22)
    plate:SetPoint("BOTTOM", holder, "BOTTOM", 0, 4)
    Wood.Gradient(plate, "HORIZONTAL", 0.10, 0.09, 0.08, 1, 0.24, 0.22, 0.20, 1)
    local handle = CreateFrame("Frame", nil, holder)
    handle:SetSize(6, 32)
    handle:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)
    handle:SetFrameLevel(holder:GetFrameLevel() + 1)
    Wood.Paint(handle, "post", seed, { grain = "V", round = true, woodOnly = true, tone = 0.8 })
    local cup = CreateFrame("Frame", nil, holder)
    cup:SetSize(14, 8)
    cup:SetPoint("TOP", holder, "TOP", 0, 0)
    cup:SetFrameLevel(holder:GetFrameLevel() + 2)
    local iron = cup:CreateTexture(nil, "ARTWORK", nil, 0)
    iron:SetAllPoints()
    Wood.Gradient(iron, "VERTICAL", 0.08, 0.07, 0.06, 1, 0.30, 0.28, 0.25, 1)
    Wood.Perspective(iron, -2)
    local char = Wood.Disc(cup, "ARTWORK", 1, 0.05, 0.04, 0.03, 1)
    char:SetSize(10, 4)
    char:SetPoint("TOP", cup, "TOP", 0, 1)
    local shadow = holder:CreateTexture(nil, "BACKGROUND", nil, 0)
    shadow:SetSize(16, 40)
    shadow:SetPoint("BOTTOM", holder, "BOTTOM", 3, -4)
    shadow:SetColorTexture(0, 0, 0, 0.30)
    local flame = Flame(holder, cup, 30, seed)
    flame.haloAlpha = 0.34
    return { frame = holder, flame = flame }
end
local torches = { Torch(5), Torch(9) }

local function PlaceTorches()
    local win = currentWindow and currentWindow.frame
    for i, t in ipairs(torches) do
        t.frame:ClearAllPoints()
        local side = i == 1 and -1 or 1
        if win then
            t.frame:SetPoint(side < 0 and "RIGHT" or "LEFT", win, side < 0 and "LEFT" or "RIGHT", side * 16, -8)
        else
            t.frame:SetPoint("TOP", vendorZone, "TOP", side * 84, -40)
        end
    end
end

-- The lantern on the sales counter (outdoors): a candle in a glass chimney on a brass base, under
-- an iron cap with a ring handle. It throws a wide warm light and a pool of light on the counter.
local candle
do
    local props = addon.Showroom.counter and addon.Showroom.counter.props
    if props then
        local holder = CreateFrame("Frame", nil, props)
        holder:SetSize(24, 46)
        holder:SetPoint("BOTTOMLEFT", props, "BOTTOMLEFT", 102, 1)
        holder:SetFrameLevel(props:GetFrameLevel() + 2)
        -- Light pooled on the counter top.
        local pool = props:CreateTexture(nil, "ARTWORK", nil, -1)
        GlowTexture(pool)
        pool:SetSize(150, 22)
        pool:SetPoint("CENTER", holder, "BOTTOM", 0, 3)
        local shadow = Wood.Disc(holder, "BACKGROUND", 0, 0, 0, 0, 0.5)
        shadow:SetSize(28, 7)
        shadow:SetPoint("BOTTOM", holder, "BOTTOM", 3, -2)
        local base = Wood.Disc(holder, "ARTWORK", 0, 1, 1, 1, 1)
        base:SetSize(22, 7)
        base:SetPoint("BOTTOM", holder, "BOTTOM", 0, 0)
        Wood.Brass(base, 0.9, DISC)
        local foot = holder:CreateTexture(nil, "ARTWORK", nil, 1)
        foot:SetSize(18, 5)
        foot:SetPoint("BOTTOM", holder, "BOTTOM", 0, 3)
        Wood.Brass(foot, 0.8)
        -- Glass chimney (behind the flame, so the flame glows through it).
        local glass = holder:CreateTexture(nil, "ARTWORK", nil, 2)
        glass:SetSize(16, 28)
        glass:SetPoint("BOTTOM", holder, "BOTTOM", 0, 8)
        Wood.Gradient(glass, "HORIZONTAL", 0.75, 0.85, 0.90, 0.10, 1, 1, 1, 0.22)
        local glint = holder:CreateTexture(nil, "ARTWORK", nil, 3)
        glint:SetSize(2, 22)
        glint:SetPoint("BOTTOMLEFT", glass, "BOTTOMLEFT", 3, 3)
        glint:SetColorTexture(1, 1, 1, 0.35)
        local wax = holder:CreateTexture(nil, "ARTWORK", nil, 3)
        wax:SetSize(6, 8)
        wax:SetPoint("BOTTOM", glass, "BOTTOM", 0, 0)
        Wood.Gradient(wax, "HORIZONTAL", 0.78, 0.72, 0.58, 1, 0.98, 0.94, 0.82, 1)
        local top = CreateFrame("Frame", nil, holder)
        top:SetSize(2, 3)
        top:SetPoint("BOTTOM", wax, "TOP", 0, -1)
        local wick = top:CreateTexture(nil, "ARTWORK")
        wick:SetAllPoints()
        wick:SetColorTexture(0.08, 0.06, 0.05, 1)
        local flame = Flame(holder, top, 17, 3)
        flame.haloAlpha = 0.48
        flame.halo:SetSize(17 * 8, 17 * 8)
        flame.sheltered = true
        flame.pool = pool
        -- Iron cage, cap and ring, over the flame.
        local cage = CreateFrame("Frame", nil, holder)
        cage:SetAllPoints()
        cage:SetFrameLevel(holder:GetFrameLevel() + 2)
        for _, side in ipairs({ -1, 1 }) do
            local bar = cage:CreateTexture(nil, "ARTWORK")
            bar:SetSize(2, 29)
            bar:SetPoint("BOTTOM", holder, "BOTTOM", side * 8, 7)
            Wood.Gradient(bar, "HORIZONTAL", 0.10, 0.09, 0.08, 1, 0.32, 0.30, 0.27, 1)
        end
        local cap = cage:CreateTexture(nil, "ARTWORK", nil, 1)
        cap:SetSize(20, 6)
        cap:SetPoint("BOTTOM", glass, "TOP", 0, -1)
        Wood.Gradient(cap, "VERTICAL", 0.08, 0.07, 0.06, 1, 0.34, 0.31, 0.28, 1)
        Wood.Perspective(cap, 4)
        local ring = Wood.Disc(cage, "ARTWORK", 2, 0.22, 0.20, 0.18, 1)
        ring:SetSize(9, 7)
        ring:SetPoint("BOTTOM", cap, "TOP", 0, -1)
        candle = { frame = holder, flame = flame }
    end
end

-- Flicker while any flame is lit and the shop is open.
local fireWind = 0
local fireDriver = CreateFrame("Frame", nil, ShelfFrame)
fireDriver:Hide()
local fireAcc = 0
fireDriver:SetScript("OnUpdate", function(_, elapsed)
    fireAcc = fireAcc + elapsed
    if fireAcc < 0.05 then return end
    fireAcc = 0
    local t = GetTime()
    for _, f in ipairs(flames) do
        if f.lit and f.halo:IsVisible() then UpdateFlame(f, t, f.windy and fireWind or 0) end
    end
end)

-- Lit from dusk to dawn: torches indoors, the candle outdoors.
local function ApplyFire(place, sk, enabled)
    local lit = enabled and sk.day < 0.6
    local indoors = place == "indoor"
    for _, t in ipairs(torches) do
        t.frame:SetShown(enabled and indoors)
        SetFlameLit(t.flame, lit and indoors)
    end
    if indoors and enabled then PlaceTorches() end
    if candle then
        candle.frame:SetShown(enabled and not indoors)
        candle.flame.windy = true
        SetFlameLit(candle.flame, lit and not indoors)
    end
    fireWind = place == "wild" and 1.3 or 0.8
    local any = false
    for _, f in ipairs(flames) do if f.lit then any = true end end
    fireDriver:SetShown(any)
    if any then
        local t = GetTime()
        for _, f in ipairs(flames) do if f.lit then UpdateFlame(f, t, f.windy and fireWind or 0) end end
    end
end

-- ============================================================================
-- BREEZE: a soft wind loop outdoors (the game's own light-wind weather sound)
-- ============================================================================
local BREEZE = {
    default = { file = 538985, length = 30 },   -- sound/ambience/weather/snowlight.ogg
    orgrimmar = { file = 538988, length = 60 }, -- sandstormlight.ogg: dry wind over the Barrens
}
local breeze = { handles = {} }

local function StopBreeze()
    if breeze.timer then breeze.timer:Cancel(); breeze.timer = nil end
    for _, h in ipairs(breeze.handles) do if StopSound then StopSound(h, 1500) end end
    breeze.handles = {}
    breeze.sound = nil
end

local function StartBreeze(key)
    local s = BREEZE[key] or BREEZE.default
    if breeze.sound == s then return end
    StopBreeze()
    if not (PlaySoundFile and C_Timer and C_Timer.NewTimer) then return end
    breeze.sound = s
    local function Play()
        local ok, willPlay, handle = pcall(PlaySoundFile, s.file, "Ambience")
        if ok and willPlay and handle then
            local old = breeze.handles[#breeze.handles]
            breeze.handles = { handle }
            -- Overlap the end of the last loop and fade it out, so the wind never stops.
            if old and StopSound then StopSound(old, 1500) end
        end
        breeze.timer = C_Timer.NewTimer(s.length - 1.2, Play)
    end
    Play()
end
ShelfFrame:HookScript("OnHide", StopBreeze)

-- ============================================================================
-- LIGHT: one multiply layer over the whole cabinet, so everything in the room dims together
-- ============================================================================
local dim = CreateFrame("Frame", nil, ShelfFrame)
dim:SetPoint("TOPLEFT", ShelfFrame, "TOPLEFT", 6, -6)
dim:SetPoint("BOTTOMRIGHT", ShelfFrame, "BOTTOMRIGHT", -6, 6)
dim:SetFrameLevel(baseLevel + 40)
dim:EnableMouse(false)
local dimTex = dim:CreateTexture(nil, "OVERLAY", nil, 7)
dimTex:SetAllPoints()
dimTex:SetColorTexture(1, 1, 1, 1)
dimTex:SetBlendMode("MOD")
dim:Hide()

-- Open-air fill: cool sky light over the stall by day.
local fill = addon.backboardLight and addon.backboardLight:CreateTexture(nil, "ARTWORK", nil, 3)
if fill then
    fill:SetAllPoints()
    fill:SetBlendMode("ADD")
end

local function SetLanterns(strength)
    local lg = addon.lanternGlow
    if lg then Wood.Gradient(lg, "VERTICAL", 1, 0.62, 0.25, 0, 1, 0.62, 0.25, 0.07 * strength) end
    local vg = addon.Showroom.vendorGlow
    if vg then Wood.Gradient(vg, "VERTICAL", 1, 0.62, 0.28, 0.10 * strength, 1, 0.62, 0.28, 0) end
end

-- Multiply colour of the room.
local function RoomLight(sk, indoors)
    local night = indoors and { 0.80, 0.74, 0.70 } or { 0.60, 0.65, 0.84 }
    local c = LerpRGB(night, { 1, 1, 1 }, sk.day)
    local warm = sk.warm * (indoors and 0.5 or 1)
    return c[1], c[2] * (1 - 0.08 * warm), c[3] * (1 - 0.20 * warm)
end

-- ============================================================================
-- STATE
-- ============================================================================
-- Saved settings (the settings menu, or /venstore ambience):
--   db.ambience  "off" turns the lighting off
--   db.place     "indoor", "outdoor" (a town stall) or "wild"; nil follows the game
--   db.hour      a fixed hour (0 to 24); nil follows realm time
local function DB() return addon.db or {} end

function Ambience.Enabled()
    return DB().ambience ~= "off"
end

function Ambience.Hour()
    if DB().hour then return DB().hour end
    local h, m = 12, 0
    if GetGameTime then h, m = GetGameTime() end
    return (h or 12) + (m or 0) / 60
end

-- Where the game says you are: "indoor", "town" (outdoors in a city or village: resting) or "wild".
function Ambience.AutoPlace()
    if not IsIndoors or IsIndoors() then return "indoor" end
    if IsResting and IsResting() then return "town" end
    return "wild"
end

local SETTING = { indoor = "indoor", outdoor = "town", wild = "wild" }
function Ambience.Place()
    return SETTING[DB().place] or Ambience.AutoPlace()
end

function Ambience.Indoors()
    return Ambience.Place() == "indoor"
end

local function ApplyOff()
    FloorGround(false)
    HideWindows()
    valance:Hide()
    wild:Hide()
    ApplyFire("indoor", Ambience.Sky(12), false)
    StopBreeze()
    if addon.Showroom.spotlight then addon.Showroom.spotlight:Show() end
    if addon.Showroom.vendorGlow then addon.Showroom.vendorGlow:Show() end
    dim:Hide()
    if fill then fill:Hide() end
    SetLanterns(1)
end

function Ambience.Refresh()
    if not Ambience.Enabled() then ApplyOff(); return end
    local hour = Ambience.Hour()
    local place = Ambience.Place()
    local indoors = place == "indoor"
    local key = addon.Theme.currentKey or "workshop"
    local sk = Ambience.Sky(hour)

    local wilderness = false
    if indoors then
        valance:Hide()
        wild:Hide()
        local w = ShowWindow(key)
        if w then w.Apply(hour, sk) end
        SetLanterns(0.5 + 1.0 * (1 - sk.day))
        if fill then fill:Hide() end
    else
        HideWindows()
        awningColours = StyleFor(key).awning
        valance:Show()
        LayoutValance()
        -- Out in the wilds the region's trees stand behind the stall; in town, the shop's walls.
        wilderness = place == "wild" and ShowWild(key, sk)
        if not wilderness then wild:Hide() end
        local night = 1 - sk.day
        SetLanterns(1.4 * Clamp01(night * 1.3 - 0.15))
        if fill then
            local b = sk.bottom
            fill:SetColorTexture(b[1], b[2], b[3], 0.07 * sk.day)
            fill:Show()
        end
    end
    Ambience.state = { hour = hour, place = place, indoors = indoors, wilderness = wilderness, key = key, sky = sk }
    if not (wilderness and forestOn) then FloorGround(false) end

    -- Torches indoors, the candle outdoors; the plinth spotlight and the vendor's lamp glow are
    -- indoor lights. The breeze blows outdoors.
    ApplyFire(place, sk, true)
    if addon.Showroom.spotlight then addon.Showroom.spotlight:SetShown(indoors) end
    if addon.Showroom.vendorGlow then addon.Showroom.vendorGlow:SetShown(indoors) end
    if not indoors and DB().breeze ~= false and ShelfFrame:IsShown() then StartBreeze(key) else StopBreeze() end

    local r, g, b = RoomLight(sk, indoors)
    dimTex:SetColorTexture(r, g, b, 1)
    dim:SetShown(r < 0.995 or g < 0.995 or b < 0.995)
end

-- The sky moves while the shop is open.
local ticker
ShelfFrame:HookScript("OnShow", function()
    -- Positions are only known once the window is laid out on screen.
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if currentWindow then PlaceWindow(currentWindow) end
            if wild:IsShown() then LayoutWild(); if Ambience.state then PaintWild(Ambience.state.sky) end end
            local st = Ambience.state
            if st and not st.indoors and Ambience.Enabled() and DB().breeze ~= false and ShelfFrame:IsShown() then
                StartBreeze(st.key)
            end
            if st and st.indoors then PlaceTorches() end
        end)
    end
    if ticker or not C_Timer or not C_Timer.NewTicker then return end
    ticker = C_Timer.NewTicker(30, function() addon.SafeCall(Ambience.Refresh) end)
end)
ShelfFrame:HookScript("OnHide", function()
    if ticker then ticker:Cancel(); ticker = nil end
end)

-- ============================================================================
-- /venstore ambience [indoor | town | wild | <hour> | auto | on | off]
-- ============================================================================
function Ambience.FormatHour(h)
    return string.format("%02d:%02d", math.floor(h) % 24, math.floor((h % 1) * 60 + 0.5) % 60)
end

local PLACE_NAMES = { indoor = "indoors", town = "outdoors in town", wild = "out in the wilds" }
Ambience.PLACE_NAMES = PLACE_NAMES

function Ambience.Slash(arg)
    local out = "|cffffd100VenStore:|r "
    arg = arg and strtrim(arg):lower() or ""
    if arg == "indoor" or arg == "indoors" then
        DB().place = "indoor"
    elseif arg == "town" or arg == "outdoor" or arg == "outdoors" then
        DB().place = "outdoor"
    elseif arg == "wild" or arg == "wilds" or arg == "wilderness" then
        DB().place = "wild"
    elseif arg == "auto" then
        DB().place, DB().hour = nil, nil
    elseif arg == "off" then
        DB().ambience = "off"
    elseif arg == "on" then
        DB().ambience = nil
    elseif arg ~= "" then
        local h, m = arg:match("^(%d+):?(%d*)$")
        h = tonumber(h)
        if not h or h > 24 then
            print(out .. "usage: /venstore ambience [indoor | town | wild | <hour, e.g. 21 or 6:30> | auto | on | off]")
            return
        end
        DB().hour = math.min(24, h + (tonumber(m) or 0) / 60) % 24
    end
    Ambience.Refresh()
    if not Ambience.Enabled() then
        print(out .. "ambience off (the plain workshop lighting). /venstore ambience on to turn it back on.")
        return
    end
    local st = Ambience.state
    local where = PLACE_NAMES[st.place] or st.place
    if st.place == "wild" and not st.wilderness then where = where .. " (no wilderness for this theme yet: town look)" end
    print(out .. string.format("%s, %s%s, %s%s (day %.0f%%).",
        addon.Theme.current.name, where, DB().place and " (set)" or "",
        Ambience.FormatHour(st.hour), DB().hour and " (set)" or " realm time",
        st.sky.day * 100))
    if DB().place or DB().hour then
        print("  /venstore ambience auto (or the settings menu) goes back to your real place and time.")
    end
end
