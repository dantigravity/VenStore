-- VenStore: right wing of the shop.
--   * Brass cheval mirror (only when the vendor sells cosmetics): transmog try-on with one
--     button per pose, Undress and Reset to My Appearance.
--   * Display plinth (only when the vendor sells mounts, pets or housing decor): 3D previews
--     drawn at the same scale as the vendor, standing on the plinth.
--   * Live vendor behind a tall wooden sales counter (always shown; the cart lives in Cart.lua).
-- The mirror, vendor and plinth use measured 3D stages (see "STAGES" below), which is what keeps
-- items in proportion to the vendor.
local _, addon = ...
local C, Wood = addon.C, addon.Wood
local ShelfFrame = addon.ShelfFrame
local baseLevel = ShelfFrame:GetFrameLevel()

local Showroom = {}
addon.Showroom = Showroom
Showroom.displayExtra = 0

local DISC = Wood.DISC

local function GradientDisc(tex, ...)
    Wood.GradientFile(tex, DISC, ...)
end

local function Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

-- ============================================================================
-- PLAYERMODEL / DRESSUPMODEL HELPERS (mirror, and fallbacks)
-- ============================================================================
local function SetCam(model, scale)
    model.camScale = scale
    if model.SetCamDistanceScale then model:SetCamDistanceScale(scale) end
end

local function Zoom(model, steps)
    SetCam(model, Clamp((model.camScale or 1) - steps * 0.12, 0.45, 2.8))
end

local function Rotate(model, radians)
    model.rotation = (model.rotation or 0) + radians
    model:SetFacing(model.rotation)
end

-- Left-drag rotates, optional wheel zoom; a right-click without dragging calls onRightClick.
local function MakeInteractive(model, defaultFacing, opts)
    opts = opts or {}
    model:EnableMouse(true)
    model.rotation = defaultFacing
    model:HookScript("OnMouseDown", function(self, button)
        local x, y = GetCursorPosition()
        self.lastX, self.lastY, self.downX, self.downY = x, y, x, y
        self.isRotating = button == "LeftButton"
    end)
    model:HookScript("OnMouseUp", function(self, button)
        self.isRotating = false
        if button == "RightButton" and opts.onRightClick then
            local x, y = GetCursorPosition()
            if math.abs(x - (self.downX or x)) + math.abs(y - (self.downY or y)) < 4 then opts.onRightClick(self) end
        end
    end)
    model:HookScript("OnHide", function(self) self.isRotating = false end)
    model:HookScript("OnUpdate", function(self)
        if not self.isRotating then return end
        local x = GetCursorPosition()
        Rotate(self, (x - (self.lastX or x)) * 0.015)
        self.lastX = x
    end)
    if opts.zoom then
        model:EnableMouseWheel(true)
        model:SetScript("OnMouseWheel", function(self, delta) Zoom(self, delta) end)
    end
end

-- ============================================================================
-- FRAMING MATHS (pure functions)
-- ============================================================================
-- Scenes are SW x SH, bottom-aligned and centred on the visible region W x H. By default they
-- are square (S = max(W, H)); the mirror's scene is exactly its glass so the engine clips the
-- reflection at the glass edge. The engine's field of view spans the scene DIAGONAL; each stage
-- also calibrates its lens at runtime (Stage:Calibrate), so any residual error is measured away.
-- Camera: on +X looking back at the origin (yaw = pi), no pitch. A point at depth d is drawn
-- (y / d) * F px from the scene centre on both axes. Models are re-origined to their footprint
-- centre, so the camera's Y offset is ~0.
--
--   box  = { minX, maxX, minY, maxY, minZ, maxZ } in game units (actor space, before yaw)
--   o.seat   px above the region bottom where the base centre stands
--   o.p      wanted pixels per game unit (shared scale); nil = fill the region height
--   o.minPx  never draw the model shorter than this (tiny items stay visible)
--   o.zoom   user zoom (1 = proportional size; never enlarges past the frame edge)
--   o.yaw    actor yaw
--   o.anyAngle  fit a cylinder that encloses the model at EVERY yaw, so turning it never changes
--               its size (thin sides don't "zoom in"); yaw is then irrelevant to the framing
--   o.heightOnly  fit the height only; wide parts (wings, weapons) may run past the sides, where
--               an exact-size scene clips them (the mirror). With anyAngle, the perspective checks
--               use the body's thickness, so the wingspan doesn't shrink the figure.
--   o.sceneW, o.sceneH  scene size (default: square S x S)
--   o.fill   share of the frame the model may fill (default FILL)
-- Returns p (px/unit), camera distance, camera Y, camera Z, wanted width, field of view, the
-- unzoomed proportional scale, and the largest scale that still fits the frame (the zoom limit).
local FILL = 0.92
local CYLINDER_SIDES = 16

-- Focal length in UI px for a scene, before the per-stage calibration factor.
function Showroom.FocalLength(sceneW, sceneH)
    return math.sqrt(sceneW * sceneW + sceneH * sceneH) / (2 * math.tan(C.STAGE_FOV / 2))
end

-- The model's footprint as seen by the camera: (depth toward camera, sideways) pairs.
-- core: use the body's thickness (the box's narrow side) as the cylinder, ignoring wingspan and
-- weapon reach, which an exact-size scene simply clips (the mirror).
local function FootprintPoints(box, yaw, anyAngle, core)
    local pts = {}
    if anyAngle then
        local r = 0
        if core then
            r = math.min(math.max(-box.minX, box.maxX), math.max(-box.minY, box.maxY))
        else
            for _, x in ipairs({ box.minX, box.maxX }) do
                for _, y in ipairs({ box.minY, box.maxY }) do r = math.max(r, math.sqrt(x * x + y * y)) end
            end
        end
        r = r / math.cos(math.pi / CYLINDER_SIDES) -- polygon drawn around (not inside) the circle
        for i = 0, CYLINDER_SIDES - 1 do
            local a = i * 2 * math.pi / CYLINDER_SIDES
            pts[#pts + 1] = { r * math.cos(a), r * math.sin(a) }
        end
    else
        local c, s = math.cos(yaw), math.sin(yaw)
        for _, x in ipairs({ box.minX, box.maxX }) do
            for _, y in ipairs({ box.minY, box.maxY }) do pts[#pts + 1] = { x * c - y * s, x * s + y * c } end
        end
    end
    return pts
end

function Showroom.ComputeFraming(box, W, H, o)
    local zoom, seat, fill = o.zoom or 1, o.seat or 0, o.fill or FILL
    local S = math.max(W, H)
    local SW, SH = o.sceneW or S, o.sceneH or S
    local h = math.max(0.05, box.maxZ - box.minZ)
    local pts = FootprintPoints(box, o.yaw or 0, o.anyAngle, o.heightOnly)

    local lo, hi = math.huge, -math.huge
    for _, pt in ipairs(pts) do
        if pt[2] < lo then lo = pt[2] end
        if pt[2] > hi then hi = pt[2] end
    end
    local projW = math.max(0.05, hi - lo)
    local camY = (lo + hi) / 2

    local usableH = H - seat - 4
    local fitH = usableH * fill / h
    local maxP = o.heightOnly and fitH or math.min(fitH, W * fill / projW) -- the frame edge
    local natural = o.p and math.max(o.p, (o.minPx or 0) / h) or fitH
    natural = math.min(natural, fitH)
    local wantW = projW * natural / fill
    -- Zoom scales the proportional size, but never past what fits inside the frame.
    local p = math.min(natural * zoom, maxP)

    -- Fixed, moderate lens (C.STAGE_FOV): the scale comes from the camera distance alone, because
    -- extreme fields of view distort the framing in tall scenes.
    local F = Showroom.FocalLength(SW, SH) * (o.lens or 1) -- o.lens: runtime calibration factor
    local dist, camZ
    local floorPx, topPx, halfWPx = -(SH / 2) + 1, H - SH / 2 - 4, W * fill / 2
    for pass = 1, 8 do
        dist = F / p
        camZ = box.minZ + (SH / 2 - seat) / p                 -- base centre on the seat line
        -- The nearest base point may sit lower than the centre (perspective); keep it in the frame.
        local lowest, lowDepth = math.huge, dist
        for _, pt in ipairs(pts) do
            local depth = dist - pt[1]
            if depth > 0.1 then
                local sy = (box.minZ - camZ) / depth * F
                if sy < lowest then lowest, lowDepth = sy, depth end
            end
        end
        if lowest < floorPx then camZ = camZ - (floorPx - lowest) * lowDepth / F end
        -- How far past the sides / top does any point reach?
        local over = 1
        for _, pt in ipairs(pts) do
            local depth = dist - pt[1]
            if depth <= 0.1 then
                over = math.max(over, 1.5)
            else
                if not o.heightOnly then
                    over = math.max(over, math.abs((pt[2] - camY) / depth * F) / halfWPx)
                end
                local sy = (box.maxZ - camZ) / depth * F
                if sy > 0 then over = math.max(over, sy / topPx) end
            end
        end
        if over <= 1.001 or pass == 8 then break end
        p = p / over
    end
    return p, dist, camY, camZ, wantW, C.STAGE_FOV, natural, maxP
end

-- Long models start at a three-quarter angle (long side ~35 degrees from the camera).
function Showroom.DefaultYaw(box, fallback)
    local lenX, lenY = box.maxX - box.minX, box.maxY - box.minY
    if lenX > 1.8 * lenY then return 0.6 end
    if lenY > 1.8 * lenX then return math.pi / 2 - 0.6 end
    return fallback
end

-- ============================================================================
-- STAGES: a ModelScene + one actor, measured with GetActiveBoundingBox.
-- NoCameraControl scene, camera on +X looking back (yaw = pi), ModelSceneActorTemplate actor.
-- GetActiveBoundingBox returns nil until the model has streamed in, so it is polled.
-- ============================================================================
local Stage = {}
Stage.__index = Stage

local function CreateStage(region, opts)
    local ok, scene = pcall(CreateFrame, "ModelScene", nil, region, "NoCameraControlModelSceneMixinTemplate")
    if not ok or not scene then return nil end
    local okActor, actor = pcall(scene.CreateActor, scene, nil, "ModelSceneActorTemplate")
    if not okActor or not actor then scene:Hide(); return nil end

    local st = setmetatable({ scene = scene, actor = actor, region = region, token = 0,
        yaw = opts.yaw or 0, defaultYaw = opts.yaw or 0, zoom = 1, lens = Showroom.lensFactor }, Stage)
    for k, v in pairs(opts) do st[k] = v end

    scene:SetPoint("BOTTOM", region, "BOTTOM", 0, 0)
    scene:SetFrameLevel(region:GetFrameLevel() + 1)
    -- The region handles input; a square scene may overhang other bays. The scene template has
    -- its own OnMouseWheel (enabled separately from EnableMouse) that does nothing without a
    -- camera controller and would swallow the wheel, so it is removed.
    scene:EnableMouse(false)
    scene:SetScript("OnMouseWheel", nil)
    scene:EnableMouseWheel(false)
    scene:SetCameraOrientationByYawPitchRoll(math.pi, 0, 0)
    scene:SetLightDiffuseColor(0.85, 0.80, 0.72)
    scene:SetLightAmbientColor(0.60, 0.58, 0.55)
    scene:SetLightPosition(1, 0, 1)
    scene:SetLightDirection(-1, 0, -1)
    scene:Hide()

    if actor.SetAnimationBlendOperation and Enum and Enum.ModelBlendOperation then
        actor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None) -- no morphing between models
    end
    if actor.SetUseCenterForOrigin then actor:SetUseCenterForOrigin(true, true, false) end
    actor:SetOnModelLoadedCallback(function()
        if st.onLoaded then st.onLoaded(st) end
        st:ReadBox(st.token, 0)
    end)

    -- Square scenes by default; `exact` scenes match the region (the engine clips at its edges).
    local function Fit()
        local sw, sh = st:SceneSize()
        if not sw then return end
        local ow, oh = scene:GetWidth() or 0, scene:GetHeight() or 0
        scene:SetSize(sw, sh)
        -- A new aspect ratio may need a new lens measurement.
        if st.exact and (math.abs(ow - sw) > 0.5 or math.abs(oh - sh) > 0.5) then st.calibrated = false end
    end
    region:HookScript("OnSizeChanged", function()
        Fit()
        if st.onResize then st.onResize(st) end
        st:Frame()
    end)
    Fit()

    -- Input on the visible region: drag turns, optional wheel zoom, right-click hook.
    region:EnableMouse(true)
    region:HookScript("OnMouseDown", function(_, button)
        if not scene:IsShown() then return end
        st.lastX = GetCursorPosition()
        st.rotating = button == "LeftButton"
    end)
    region:HookScript("OnMouseUp", function(_, button)
        if st.rotating then st:Frame() end -- refit to the new angle
        st.rotating = false
        if button == "RightButton" and st.onRightClick and scene:IsShown() then st.onRightClick(st) end
    end)
    region:HookScript("OnUpdate", function()
        if not st.rotating then return end
        local x = GetCursorPosition()
        st.yaw = st.yaw + (x - (st.lastX or x)) * 0.015
        st.lastX = x
        actor:SetYaw(st.yaw)
    end)
    if st.wheelZoom then
        region:EnableMouseWheel(true)
        region:SetScript("OnMouseWheel", function(_, delta)
            if not scene:IsShown() then return end
            st:WheelZoom(delta)
        end)
    end
    return st
end

function Stage:SceneSize()
    local w, h = self.region:GetWidth(), self.region:GetHeight()
    if not w or not h or w <= 0 or h <= 0 then return nil end
    if self.exact then return w, h end
    local s = math.max(w, h)
    return s, s
end

-- Wheel zoom. Above the proportional size, the steps are spread so the frame edge is about six
-- clicks away whatever the item's size (a tiny candle can come right up to the frame). Below it,
-- gentle 15% steps zoom out. Stage:Frame stops the zoom at the frame edge.
local ZOOM_IN_CLICKS, MIN_ZOOM = 6, 0.4
function Stage:WheelZoom(delta)
    local maxZoom = math.max(1, self.maxZoom or 1)
    local z = self.zoom
    if z > 1.001 or (z >= 0.999 and delta > 0) then
        z = z * math.max(1.15, maxZoom ^ (1 / ZOOM_IN_CLICKS)) ^ delta
        if z < 1 then z = 1 end -- coming back down: stop at the proportional size first
    else
        z = z * 1.15 ^ delta
        if z > 1 then z = 1 end
    end
    self.zoom = Clamp(z, self.minZoom or MIN_ZOOM, maxZoom)
    self:Frame()
end

-- Load a model: setter(actor) points the actor at it. The scene stays invisible until the box
-- has been read and the camera placed.
function Stage:Load(setter)
    self.token = self.token + 1
    self.box = nil
    self.yaw, self.zoom = self.defaultYaw, self.defaultZoom or 1
    self.calibrateTries = 0
    self.scene:SetAlpha(0)
    self.scene:Show()
    setter(self.actor)
    self:ReadBox(self.token, 0) -- cached models may not fire the load callback again
end

function Stage:ReadBox(token, tries)
    if token ~= self.token then return end
    local minX, minY, minZ, maxX, maxY, maxZ = self.actor:GetActiveBoundingBox()
    if not minX then
        if tries < 20 then C_Timer.After(0.1, function() self:ReadBox(token, tries + 1) end) end
        return
    end
    -- The actor is re-origined to its footprint centre, so measure the footprint from there.
    local hx, hy = (maxX - minX) / 2, (maxY - minY) / 2
    local firstRead = self.box == nil
    self.box = { minX = -hx, maxX = hx, minY = -hy, maxY = hy, minZ = minZ, maxZ = maxZ }
    self.dims = { maxX - minX, maxY - minY, maxZ - minZ }
    if firstRead and self.autoYaw then self.yaw = Showroom.DefaultYaw(self.box, self.yaw) end
    if self.onBox then self.onBox(self) end
    self:Frame()
end

-- Lens calibration. Rather than trust the projection formula, each stage asks the engine once:
-- project the point the camera aims at and a point 1 game unit above it, and compare the
-- on-screen distance with the intended scale. Project3DPointTo2D answers in its own units from
-- the scene's bottom-left; the aim point lands on the scene centre, which gives the unit
-- conversion. Each stage keeps its own factor (scenes differ in shape) and stays invisible until
-- it has measured, so the first frame is never the wrong size.
Showroom.lensFactor = 1 -- starting guess for stages that haven't measured yet (last measurement)

local CALIBRATE_TRIES = 3

function Stage:Calibrate(token)
    if self.calibrated or token ~= self.token or not self.lastCam then return end
    local scene = self.scene
    local function Done()
        self.calibrated = true
        scene:SetAlpha(1)
    end
    local function Retry()
        self.calibrateTries = (self.calibrateTries or 0) + 1
        if self.calibrateTries >= CALIBRATE_TRIES then return Done() end -- keep the estimate
        C_Timer.After(0.05, function() self:Calibrate(token) end)
    end
    if not scene.Project3DPointTo2D then return Done() end
    local dist, camY, camZ = unpack(self.lastCam)
    local sw, sh = scene:GetWidth() or 0, scene:GetHeight() or 0
    local ok0, x0, y0 = pcall(scene.Project3DPointTo2D, scene, 0, camY, camZ)
    local ok1, _, y1 = pcall(scene.Project3DPointTo2D, scene, 0, camY, camZ + 1)
    if not (ok0 and ok1 and type(x0) == "number" and type(y0) == "number" and type(y1) == "number")
        or sw <= 0 or sh <= 0 then return Retry() end
    local k = x0 / (sw / 2)                                  -- engine units per UI pixel
    if k <= 0 or math.abs(y0 / (sh / 2) - k) > 0.05 * k then return Retry() end -- unexpected origin
    local actual = (y1 - y0) / k                             -- UI px per game unit at the aim point
    local intended = Showroom.FocalLength(sw, sh) * self.lens / dist
    local ratio = actual / intended
    if ratio < 0.3 or ratio > 4 then return Retry() end
    self.calibrateTries = 0
    -- The engine's true focal scale is ratio x ours, so the camera must sit ratio x further back.
    self.lens = self.lens * ratio
    Showroom.lensFactor = self.lens
    Done()
    if math.abs(ratio - 1) > 0.001 then self:Frame() end
end

-- Everything ComputeFraming needs for this stage right now.
function Stage:FramingOptions()
    local sw, sh = self:SceneSize()
    return {
        seat = self.seat, yaw = self.yaw, zoom = self.zoom, lens = self.lens, fill = self.fill,
        p = self.scaleFn and self.scaleFn(self), minPx = self.minPx, anyAngle = self.anyAngle,
        heightOnly = self.heightOnly, sceneW = sw, sceneH = sh,
    }
end

function Stage:Frame()
    if not (self.box and self.scene:IsShown()) then return end
    local W, H = self.region:GetWidth(), self.region:GetHeight()
    if not W or not H or W <= 0 or H <= 0 then return end
    local p, dist, camY, camZ, wantW, fov, natural, maxP = Showroom.ComputeFraming(self.box, W, H, self:FramingOptions())
    self.p, self.wantW = p, wantW
    self.maxZoom = (natural and natural > 0) and math.max(1, maxP / natural) or 1
    -- Zoom stops at the frame edge: don't let extra wheel clicks pile up past that point.
    if self.zoom > 1 and natural and natural > 0 and natural * self.zoom > p * 1.001 then
        self.zoom = math.max(1, p / natural)
    end
    self.scene:SetCameraFieldOfView(fov)
    self.scene:SetCameraPosition(dist, camY, camZ)
    self.actor:SetYaw(self.yaw)
    self.lastCam = { dist, camY, camZ }
    if self.onFramed then self.onFramed(self) end
    if self.calibrated then
        self.scene:SetAlpha(1)
    else
        local token = self.token
        C_Timer.After(0, function() self:Calibrate(token) end) -- after the camera is applied
    end
end

function Stage:Clear()
    self.token = self.token + 1
    self.box, self.dims, self.p = nil, nil, nil
    self.scene:Hide()
    self.actor:ClearModel()
end

-- ============================================================================
-- SHARED SCENERY
-- ============================================================================
local function MakeDivider(parent, xOffset, seed)
    local post = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    post:SetWidth(14)
    post:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, 2)
    post:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", xOffset, -2)
    post:SetFrameLevel(baseLevel + 9)
    Wood.Paint(post, "post", seed, { grain = "V", round = true })
    post:SetBackdrop({ edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border", edgeSize = 8 })
    post:SetBackdropBorderColor(0.55, 0.38, 0.20, 1)
    local shadow = parent:CreateTexture(nil, "BACKGROUND")
    shadow:SetPoint("TOPLEFT", post, "TOPRIGHT")
    shadow:SetPoint("BOTTOMLEFT", post, "BOTTOMRIGHT")
    shadow:SetWidth(16)
    Wood.Gradient(shadow, "HORIZONTAL", 0, 0, 0, 0.55, 0, 0, 0, 0)
    return post
end

-- Shop floor: a lit front edge plus a darker deck receding into the wall.
local function MakeFloor(parent, seed)
    local front = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    front:SetHeight(18)
    front:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 4, 4)
    front:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)
    front:SetFrameLevel(parent:GetFrameLevel() + 6)
    Wood.Paint(front, "shelf", seed, { round = true, ends = true })
    front:SetBackdrop({ edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border", edgeSize = 10 })
    front:SetBackdropBorderColor(0.55, 0.38, 0.20, 1)

    local deck = CreateFrame("Frame", nil, parent)
    deck:SetPoint("BOTTOMLEFT", front, "TOPLEFT", 2, -2)
    deck:SetPoint("BOTTOMRIGHT", front, "TOPRIGHT", -2, -2)
    deck:SetHeight(28)
    deck:SetFrameLevel(parent:GetFrameLevel() + 1)
    Wood.Paint(deck, "deck", seed + 1,
        { tone = 0.9, light = 1.25, dark = 0.55, bevel = false, flip = true })
    local seam = Wood.Solid(deck, "ARTWORK", 2, 0.05, 0.02, 0.01, 0.7)
    seam:SetPoint("LEFT", deck, "LEFT", 0, 2); seam:SetPoint("RIGHT", deck, "RIGHT", 0, 2); seam:SetHeight(1)
    Wood.EdgeShade(deck, deck, "TOP", 12, 0.75, "ARTWORK", 3)
    return front, deck
end

-- ============================================================================
-- MIRROR BAY
-- ============================================================================
local mirrorBay = CreateFrame("Frame", nil, ShelfFrame)
mirrorBay:SetWidth(C.MIRROR_BAY_W)
mirrorBay:SetFrameLevel(baseLevel + 4)

MakeDivider(mirrorBay, -12, 71)
local mirrorFloor = MakeFloor(mirrorBay, 53)

-- Height reserved for the floor strip under each scene (front edge + insets).
local FLOOR_RESERVE = 26

-- The mirror stand is a constant size, standing on the floor; taller windows add wall above it.
local mirrorStand = CreateFrame("Frame", nil, mirrorBay)
mirrorStand:SetPoint("BOTTOMLEFT", mirrorBay, "BOTTOMLEFT", 0, 0)
mirrorStand:SetPoint("BOTTOMRIGHT", mirrorBay, "BOTTOMRIGHT", 0, 0)
mirrorStand:SetHeight(C.MIRROR_H)
mirrorBay:HookScript("OnSizeChanged", function(_, _, h)
    if h and h > 0 then mirrorStand:SetHeight(math.min(h, C.MIRROR_H)) end
end)

-- The mirror stand is cast brass so it stands out against the wooden shop.
local function MakeMirrorPost(point, x)
    local post = CreateFrame("Frame", nil, mirrorBay)
    post:SetWidth(10)
    post:SetPoint("TOP" .. point, mirrorStand, "TOP" .. point, x, -24)
    post:SetPoint("BOTTOM" .. point, mirrorFloor, "TOP" .. point, x - (point == "LEFT" and 4 or -4), 8)
    post:SetFrameLevel(mirrorBay:GetFrameLevel() + 3)
    Wood.BrassPaint(post, { cylinder = "V" })
    -- Turned collars near the top and bottom, and a ball finial.
    for _, at in ipairs({ { "TOP", -6 }, { "BOTTOM", 4 } }) do
        local collar = CreateFrame("Frame", nil, post)
        collar:SetSize(16, 6)
        collar:SetPoint(at[1], post, at[1], 0, at[2])
        collar:SetFrameLevel(post:GetFrameLevel() + 1)
        Wood.BrassPaint(collar, { cylinder = "H" })
    end
    local finialFrame = CreateFrame("Frame", nil, post)
    finialFrame:SetAllPoints()
    finialFrame:SetFrameLevel(post:GetFrameLevel() + 2)
    Wood.BrassRosette(finialFrame, 14):SetPoint("BOTTOM", post, "TOP", 0, -3)
    return post
end
MakeMirrorPost("LEFT", 10)
MakeMirrorPost("RIGHT", -10)

-- Pose / undress / reset buttons on a brass header board ABOVE the mirror (two rows of icons),
-- so the glass can reach down to the floor and the reflection stands at the vendor's level.
local ICON, ICON_GAP, ROW_GAP = 22, 3, 5
local HEADER_PAD = 6
local mirrorHeader = CreateFrame("Frame", nil, mirrorBay)
mirrorHeader:SetPoint("TOPLEFT", mirrorStand, "TOPLEFT", 18, -22)
mirrorHeader:SetPoint("TOPRIGHT", mirrorStand, "TOPRIGHT", -18, -22)
mirrorHeader:SetHeight(ICON * 2 + ROW_GAP + HEADER_PAD * 2)
mirrorHeader:SetFrameLevel(mirrorBay:GetFrameLevel() + 6)
Wood.BrassPaint(mirrorHeader)
-- A dark recessed panel behind the icons, so their brass rims read against the brass board.
local headerInset = mirrorHeader:CreateTexture(nil, "BORDER", nil, 0)
headerInset:SetPoint("TOPLEFT", 4, -3)
headerInset:SetPoint("BOTTOMRIGHT", -4, 3)
Wood.Gradient(headerInset, "VERTICAL", 0.10, 0.07, 0.05, 1, 0.05, 0.035, 0.025, 1)
Wood.EdgeShade(mirrorHeader, headerInset, "TOP", 5, 0.8, "BORDER", 1)
Wood.EdgeShade(mirrorHeader, headerInset, "LEFT", 3, 0.6, "BORDER", 1)
local headerShadow = mirrorBay:CreateTexture(nil, "ARTWORK")
headerShadow:SetPoint("TOPLEFT", mirrorHeader, "TOPLEFT", 5, -5)
headerShadow:SetPoint("BOTTOMRIGHT", mirrorHeader, "BOTTOMRIGHT", 5, -5)
headerShadow:SetColorTexture(0, 0, 0, 0.45)

local mirrorControls = CreateFrame("Frame", nil, mirrorBay)
mirrorControls:SetPoint("TOPLEFT", mirrorHeader, "TOPLEFT", 10, -HEADER_PAD)
mirrorControls:SetPoint("TOPRIGHT", mirrorHeader, "TOPRIGHT", -10, -HEADER_PAD)
mirrorControls:SetHeight(ICON * 2 + ROW_GAP)
mirrorControls:SetFrameLevel(mirrorBay:GetFrameLevel() + 8)

-- Crown piece with a brass finial on top of the header board.
local crown = CreateFrame("Frame", nil, mirrorHeader)
crown:SetSize(96, 12)
crown:SetPoint("BOTTOM", mirrorHeader, "TOP", 0, -2)
crown:SetFrameLevel(mirrorHeader:GetFrameLevel() + 1)
Wood.BrassPaint(crown, { cylinder = "H" })
Wood.BrassRosette(crown, 16, "ARTWORK", 3):SetPoint("CENTER", crown, "TOP", 0, 2)

-- Rectangular cheval mirror: moulded cast-brass frame on two bun feet, rosettes on the corners,
-- silvered glass. A rectangle lets the 3D framing use the glass edge as its exact limit. The feet
-- stand on the floor deck just behind its front edge, so the glass starts barely above the floor
-- the vendor stands on.
local MIRROR_FRAME_W, MIRROR_FOOT_H = 10, 5
local mirrorFrame = CreateFrame("Frame", nil, mirrorBay)
mirrorFrame:SetPoint("TOPLEFT", mirrorHeader, "BOTTOMLEFT", 4, -4)
mirrorFrame:SetPoint("BOTTOMRIGHT", mirrorFloor, "TOPRIGHT", -18, MIRROR_FOOT_H)
mirrorFrame:SetFrameLevel(mirrorBay:GetFrameLevel() + 7) -- above the floor's front edge (+6)
Wood.BrassPaint(mirrorFrame, { moulding = MIRROR_FRAME_W, fill = false })

for _, side in ipairs({ "LEFT", "RIGHT" }) do
    local foot = Wood.Disc(mirrorBay, "ARTWORK", 2, 0, 0, 0, 1)
    foot:SetSize(16, MIRROR_FOOT_H * 2 + 2)
    foot:SetPoint("CENTER", mirrorFrame, "BOTTOM" .. side, side == "LEFT" and 14 or -14, -MIRROR_FOOT_H + 1)
    GradientDisc(foot, "VERTICAL", 0.30, 0.20, 0.06, 1, 1, 0.88, 0.55, 1)
    local footShadow = Wood.Disc(mirrorBay, "ARTWORK", 1, 0, 0, 0, 0.6)
    footShadow:SetSize(24, 6)
    footShadow:SetPoint("CENTER", foot, "BOTTOM", 2, 1)
end

local frameShadow = mirrorBay:CreateTexture(nil, "ARTWORK")
frameShadow:SetPoint("TOPLEFT", mirrorFrame, "TOPLEFT", 5, -5)
frameShadow:SetPoint("BOTTOMRIGHT", mirrorFrame, "BOTTOMRIGHT", 5, -5)
frameShadow:SetColorTexture(0, 0, 0, 0.45)

local mirrorGlass = CreateFrame("Frame", nil, mirrorFrame)
mirrorGlass:SetPoint("TOPLEFT", mirrorFrame, "TOPLEFT", MIRROR_FRAME_W, -MIRROR_FRAME_W)
mirrorGlass:SetPoint("BOTTOMRIGHT", mirrorFrame, "BOTTOMRIGHT", -MIRROR_FRAME_W, MIRROR_FRAME_W)
mirrorGlass:SetFrameLevel(mirrorFrame:GetFrameLevel() + 2)

-- Trim above the moulding: a dark seam where the glass meets the frame, and a cast rosette over
-- each mitred corner.
local frameTrim = CreateFrame("Frame", nil, mirrorFrame)
frameTrim:SetAllPoints()
frameTrim:SetFrameLevel(mirrorFrame:GetFrameLevel() + 1)
local seam = frameTrim:CreateTexture(nil, "ARTWORK", nil, 0)
seam:SetPoint("TOPLEFT", mirrorGlass, "TOPLEFT", -1.5, 1.5)
seam:SetPoint("BOTTOMRIGHT", mirrorGlass, "BOTTOMRIGHT", 1.5, -1.5)
seam:SetColorTexture(0.10, 0.06, 0.02, 1)
for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    Wood.BrassRosette(frameTrim, 13):SetPoint("CENTER", mirrorFrame, corner,
        corner:find("LEFT") and 5 or -5, corner:find("TOP") and -5 or 5)
end

local glassMask = mirrorGlass:CreateMaskTexture()
glassMask:SetAllPoints(mirrorGlass)
glassMask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

local glassBase = mirrorGlass:CreateTexture(nil, "BACKGROUND", nil, 1)
glassBase:SetAllPoints()
Wood.Gradient(glassBase, "VERTICAL", 0.10, 0.14, 0.18, 0.97, 0.42, 0.50, 0.56, 0.97)
local glassTint = mirrorGlass:CreateTexture(nil, "BACKGROUND", nil, 2)
glassTint:SetAllPoints()
glassTint:SetTexture("Interface\\Glues\\Models\\UI_MainMenu\\swordgradient2")
glassTint:SetVertexColor(0.55, 0.72, 0.88, 0.45)

local function GlassStreak(w, h, x, y, a)
    local t = mirrorGlass:CreateTexture(nil, "ARTWORK", nil, 1)
    t:SetSize(w, h)
    t:SetPoint("CENTER", mirrorGlass, "CENTER", x, y)
    t:SetColorTexture(0.88, 0.96, 1, a)
    if t.SetRotation then t:SetRotation(math.rad(38)) end
    t:AddMaskTexture(glassMask)
    return t
end
local glassLayers = { glassBase, glassTint, GlassStreak(320, 26, -10, 30, 0.18), GlassStreak(320, 9, 14, -12, 0.12) }

local mirrorActiveBg = mirrorGlass:CreateTexture(nil, "BACKGROUND", nil, 3)
mirrorActiveBg:SetAllPoints()
Wood.Gradient(mirrorActiveBg, "VERTICAL", 0.05, 0.06, 0.09, 0.96, 0.16, 0.19, 0.25, 0.96)
mirrorActiveBg:Hide()

-- The reflection region is the whole glass. Its 3D scene is exactly this size, so the engine
-- clips anything that reaches past the glass (wings, weapon swings, spell glows): it disappears
-- behind the frame instead of spilling over it.
local mirrorView = CreateFrame("Frame", nil, mirrorGlass)
mirrorView:SetAllPoints(mirrorGlass)
mirrorView:SetFrameLevel(mirrorGlass:GetFrameLevel() + 1)

-- Depth: the glass sits recessed inside the frame. The shading is drawn OVER the reflection
-- (an overlay above the 3D scene), so the character looks like it is behind the glass.
local glassOverlay = CreateFrame("Frame", nil, mirrorGlass)
glassOverlay:SetAllPoints(mirrorGlass)
glassOverlay:SetFrameLevel(mirrorView:GetFrameLevel() + 4)
for _, side in ipairs({ "TOP", "LEFT" }) do Wood.EdgeShade(glassOverlay, mirrorGlass, side, 8, 0.55, "ARTWORK", 2) end
for _, side in ipairs({ "BOTTOM", "RIGHT" }) do Wood.EdgeShade(glassOverlay, mirrorGlass, side, 4, 0.30, "ARTWORK", 2) end

-- ---------------------------------------------------------------- mirror backend
-- Preferred: the player on a measured stage, scaled so head to feet fills the glass height
-- whatever the pose or angle; the wheel only zooms back out from there. Fallback (no ModelScene):
-- a DressUpModel whose zoom is capped at its full-body view.
local mirrorActive = false -- the glass is showing the player
local mirrorLoaded = false -- the player model has been loaded since the last reset
local tried = {}           -- items tried on since the model was loaded (re-applied after a reload)
local SetMirrorGlass

local mirrorStage = CreateStage(mirrorView, {
    exact = true, heightOnly = true, anyAngle = true, fill = 0.88, seat = 3, yaw = 0,
    wheelZoom = true, minZoom = 0.5,
    onRightClick = function() SetMirrorGlass(true) end,
})

local MIRROR_CAM = 1.3
local mirrorModel
if not mirrorStage then
    mirrorModel = CreateFrame("DressUpModel", nil, mirrorView)
    mirrorModel:SetAllPoints(mirrorView)
    mirrorModel:Hide()
    MakeInteractive(mirrorModel, 0, { onRightClick = function() SetMirrorGlass(true) end })
    mirrorModel:EnableMouseWheel(true)
    mirrorModel:SetScript("OnMouseWheel", function(self, delta)
        -- camera scale 1 = full-body fit; never closer than that
        SetCam(self, Clamp((self.camScale or MIRROR_CAM) - delta * 0.12, 1, 2.8))
    end)
end

local function ActorCall(method, ...)
    if mirrorStage then
        local actor = mirrorStage.actor
        if actor[method] then return pcall(actor[method], actor, ...) end
    elseif mirrorModel and mirrorModel[method] then
        return pcall(mirrorModel[method], mirrorModel, ...)
    end
end

SetMirrorGlass = function(showGlass)
    for _, t in ipairs(glassLayers) do t:SetShown(showGlass) end
    mirrorActiveBg:SetShown(not showGlass)
    mirrorActive = not showGlass
    if mirrorStage then
        if showGlass then
            mirrorStage.scene:Hide()
        elseif mirrorStage.box then
            mirrorStage.scene:Show()
            mirrorStage:Frame()
        end
    elseif mirrorModel then
        mirrorModel:SetShown(not showGlass)
    end
end

-- ---------------------------------------------------------------- poses (one button each)
local POSES = {
    { name = "Stand", anim = 0, icon = "Achievement_Character_Human_Male", desc = "Idle standing pose." },
    { name = "Walk", anim = 4, icon = "INV_Boots_Cloth_01", desc = "Walk in place." },
    { name = "Run", anim = 5, icon = "Ability_Rogue_Sprint", desc = "Run in place." },
    { name = "Combat Ready", anim = 26, icon = "Ability_Warrior_DefensiveStance", desc = "Weapons drawn, ready to fight." },
    { name = "Attack", anim = 17, icon = "INV_Sword_04", desc = "Weapon swing." },
    { name = "Spell Ready", anim = 51, icon = "Spell_Holy_MagicalSentry", desc = "Readying a spell." },
    { name = "Wave", anim = 67, icon = "Achievement_Reputation_01", desc = "Wave hello." },
    { name = "Bow", anim = 66, icon = "Achievement_GuildPerk_EverybodysFriend", desc = "A polite bow." },
    { name = "Cheer", anim = 68, icon = "Ability_Warrior_BattleShout", desc = "Cheer." },
    { name = "Salute", anim = 113, icon = "Ability_Warrior_RallyingCry", desc = "Salute." },
    { name = "Flex", anim = 82, icon = "Spell_Nature_Strength", desc = "Show off those muscles." },
    { name = "Dance", anim = 69, icon = "Spell_Misc_EmotionHappy", desc = "Dance." },
    { name = "Kneel", anim = 75, icon = "Spell_Holy_PrayerOfHealing", desc = "Kneel." },
}
local poseIndex = 1
local poseButtons = {}

local function ApplyPose()
    for i, b in ipairs(poseButtons) do b:SetSelected(i == poseIndex) end
    if mirrorActive then ActorCall("SetAnimation", POSES[poseIndex].anim) end
end

local function ApplyTryOns()
    for _, item in ipairs(tried) do ActorCall("TryOn", item) end
end

if mirrorStage then
    -- A (re)loaded player model starts in their own gear: put the tried-on items back on.
    mirrorStage.onLoaded = function()
        ApplyTryOns()
        ApplyPose()
    end
end

-- Load the player as they look in game right now (gear + transmog), standing, facing forward.
local function LoadMirrorPlayer()
    wipe(tried)
    mirrorLoaded = true
    if mirrorStage then
        mirrorStage:Load(function(actor)
            -- unit, sheatheWeapons, autoDress, hideWeapons, useNativeForm (as the DressUpFrame does)
            if not pcall(actor.SetModelByUnit, actor, "player", false, true, false, true) then
                actor:SetModelByUnit("player")
            end
        end)
    else
        mirrorModel:SetUnit("player")
        mirrorModel.rotation = 0
        mirrorModel:SetFacing(0)
        SetCam(mirrorModel, MIRROR_CAM)
    end
end

-- Show the player in the mirror (used by every control before anything was tried on).
local function EnsureMirrorPlayer()
    if not mirrorActive then SetMirrorGlass(false) end
    if not mirrorLoaded then LoadMirrorPlayer() end
end

local function ResetMirror()
    SetMirrorGlass(false)
    poseIndex = 1
    LoadMirrorPlayer()
    ApplyPose()
end

local function SelectPose(i)
    EnsureMirrorPlayer()
    poseIndex = i
    ApplyPose()
end

local PER_ROW = 8
for i, pose in ipairs(POSES) do
    local b = Wood.IconButton(mirrorControls, ICON, pose.icon, pose.name, pose.desc)
    local row, col = math.floor((i - 1) / PER_ROW), (i - 1) % PER_ROW
    b:SetPoint("TOPLEFT", mirrorControls, "TOPLEFT", col * (ICON + ICON_GAP), -row * (ICON + ROW_GAP))
    b:SetScript("OnClick", function() SelectPose(i) end)
    poseButtons[i] = b
end
local resetBtn = Wood.IconButton(mirrorControls, ICON, "Spell_Holy_Restoration", "Reset to My Appearance",
    "Show your character exactly as it looks in game right now, standing and facing forward.")
resetBtn:SetPoint("BOTTOMRIGHT", mirrorControls, "BOTTOMRIGHT", 0, 0)
resetBtn:SetScript("OnClick", ResetMirror)
local undressBtn = Wood.IconButton(mirrorControls, ICON, "INV_Shirt_White_01", "Undress",
    "Take everything off, then keep trying items on.")
undressBtn:SetPoint("RIGHT", resetBtn, "LEFT", -ICON_GAP, 0)
undressBtn:SetScript("OnClick", function()
    EnsureMirrorPlayer()
    wipe(tried)
    ActorCall("Undress")
    ApplyPose()
end)

-- Try an item (or a whole ensemble) on in the mirror.
local function TryOnMirror(link)
    EnsureMirrorPlayer()
    local itemID = tonumber(link:match("item:(%d+)"))
    local setID = addon.GetItemTransmogSet(itemID)
    local sources = setID and C_TransmogSets and C_TransmogSets.GetAllSourceIDs and C_TransmogSets.GetAllSourceIDs(setID)
    local items = (sources and #sources > 0) and sources or { link }
    for _, item in ipairs(items) do
        tried[#tried + 1] = item
        ActorCall("TryOn", item) -- if the model is still loading, onLoaded applies it again
    end
    ApplyPose()
end

-- ============================================================================
-- VENDOR STAGE
-- ============================================================================
local stageBay = CreateFrame("Frame", nil, ShelfFrame)
stageBay:SetPoint("TOPRIGHT", ShelfFrame, "TOPRIGHT", -22, -C.HEADER_H)
stageBay:SetPoint("BOTTOMRIGHT", ShelfFrame, "BOTTOMRIGHT", -22, C.FOOTER_H)
stageBay:SetFrameLevel(baseLevel + 4)

MakeDivider(stageBay, -10, 72)
local stageFloor = MakeFloor(stageBay, 61)

-- Vendor and plinth are a constant height above the floor (C.STAGE_H); a taller window only
-- adds wall above them.
local function StageHeight(bayH)
    return math.max(60, math.min(C.STAGE_H, (bayH or 0) - FLOOR_RESERVE))
end

-- ---------------------------------------------------------------- vendor zone (right)
local vendorZone = CreateFrame("Frame", nil, stageBay)
vendorZone:SetPoint("BOTTOMRIGHT", stageFloor, "TOPRIGHT", 4, 0)
vendorZone:SetSize(C.VENDOR_W, C.STAGE_H)
vendorZone:SetFrameLevel(stageBay:GetFrameLevel() + 2)

local vendorGlow = vendorZone:CreateTexture(nil, "BACKGROUND", nil, 2)
vendorGlow:SetAllPoints()
vendorGlow:SetBlendMode("ADD")
Wood.Gradient(vendorGlow, "VERTICAL", 1, 0.62, 0.28, 0.10, 1, 0.62, 0.28, 0)

local VENDOR_YAW = -0.35
local displayStage

-- The vendor is drawn by a PlayerModel: an NPC unit loaded into a ModelScene actor renders as a
-- white silhouette. A hidden actor only measures the vendor's height, so the plinth can draw
-- items in proportion to the vendor.
local vendorModel = CreateFrame("PlayerModel", nil, vendorZone)
vendorModel:SetPoint("TOPLEFT", vendorZone, "TOPLEFT", 0, 0)
vendorModel:SetPoint("BOTTOMRIGHT", vendorZone, "BOTTOMRIGHT", -4, 0)
vendorModel:SetFrameLevel(vendorZone:GetFrameLevel() + 2)
MakeInteractive(vendorModel, VENDOR_YAW) -- drag to turn; no zoom

-- Preferred path: when the PlayerModel reports the vendor's creature display ID, the vendor moves
-- onto a calibrated stage via SetModelByCreatureDisplayID (that path textures properly, unlike
-- SetModelByUnit), giving the plinth an exact shared scale. `/venstore vendor` switches back to
-- the PlayerModel if it ever looks wrong.
local vendorStage = CreateStage(vendorZone, {
    seat = 2, yaw = VENDOR_YAW,
    scaleFn = function(st) return st.lockedP end,
    onResize = function(st) st.lockedP = nil end,
    onFramed = function(st)
        if not st.lockedP then
            st.lockedP = st.p
            if Showroom.OnVendorMeasured then Showroom.OnVendorMeasured() end
        end
    end,
})

local function TryVendorStage()
    if not vendorStage or not vendorModel.GetDisplayInfo then return end
    if addon.db and addon.db.classicVendor then return end
    local ok, id = pcall(vendorModel.GetDisplayInfo, vendorModel)
    if not ok or type(id) ~= "number" or (issecretvalue and issecretvalue(id)) or id <= 0 then return end
    if vendorStage.displayID == id and vendorStage.scene:IsShown() then return end
    vendorStage.displayID = id
    vendorStage.lockedP = nil
    vendorStage:Load(function(actor) actor:SetModelByCreatureDisplayID(id) end)
    vendorModel:Hide()
end
vendorModel:HookScript("OnModelLoaded", TryVendorStage)

local vendorHeight          -- game units; nil until measured
local measureScene, measureActor
local measureToken = 0

local function MeasureVendor(unit)
    vendorHeight = nil
    measureToken = measureToken + 1
    if addon.IsUnitSecret(unit) then return end
    if measureScene == nil then
        measureScene = false
        local ok, scene = pcall(CreateFrame, "ModelScene")
        if ok and scene then
            scene:SetSize(1, 1)
            local okActor, actor = pcall(scene.CreateActor, scene, nil, "ModelSceneActorTemplate")
            if okActor and actor then measureScene, measureActor = scene, actor end
        end
    end
    if not measureScene then return end
    local token = measureToken
    local function Read(tries)
        if token ~= measureToken or vendorHeight then return end
        local _, _, minZ, _, _, maxZ = measureActor:GetActiveBoundingBox()
        if minZ and maxZ and maxZ > minZ then
            vendorHeight = maxZ - minZ
            measureActor:ClearModel()
            if Showroom.OnVendorMeasured then Showroom.OnVendorMeasured() end
        elseif tries < 30 then
            C_Timer.After(0.1, function() Read(tries + 1) end)
        end
    end
    measureActor:SetOnModelLoadedCallback(function() Read(0) end)
    measureActor:SetModelByUnit(unit)
    Read(0)
end

-- ---------------------------------------------------------------- sales counter
local SLAB_H, LIP_H, KICK_H = 13, 8, 10
local COUNTER_W = C.VENDOR_W - 14

local counter = CreateFrame("Frame", nil, vendorZone)
counter:SetPoint("BOTTOMLEFT", vendorZone, "BOTTOMLEFT", 8, 0)
counter:SetWidth(COUNTER_W)
counter:SetHeight(140)
counter:SetFrameLevel(vendorZone:GetFrameLevel() + 8)
vendorZone:HookScript("OnSizeChanged", function(_, _, h)
    counter:SetHeight(Clamp(math.floor((h or 0) * C.COUNTER_RATIO), 110, 240))
end)

local counterFloorShadow = Wood.Disc(counter, "BACKGROUND", 0, 0, 0, 0, 0.6)
counterFloorShadow:SetPoint("TOPLEFT", counter, "BOTTOMLEFT", -8, 8)
counterFloorShadow:SetPoint("BOTTOMRIGHT", counter, "BOTTOMRIGHT", 8, -4)

local body = CreateFrame("Frame", nil, counter)
body:SetPoint("TOPLEFT", counter, "TOPLEFT", 0, -(SLAB_H + LIP_H))
body:SetPoint("BOTTOMRIGHT", counter, "BOTTOMRIGHT", 0, KICK_H)
body:SetFrameLevel(counter:GetFrameLevel() + 1)
Wood.Paint(body, "counter", 140, { tone = 1.15, grain = "V", bevel = false })
Wood.EdgeShade(body, body, "TOP", 12, 0.80, "ARTWORK", 0)
Wood.EdgeShade(body, body, "LEFT", 6, 0.45, "ARTWORK", 0)
Wood.EdgeShade(body, body, "RIGHT", 8, 0.55, "ARTWORK", 0)

-- The front of the counter holds the cart shelves (Cart.lua builds them inside `body`).

local kick = CreateFrame("Frame", nil, counter)
kick:SetPoint("BOTTOMLEFT", counter, "BOTTOMLEFT", 3, 0)
kick:SetPoint("BOTTOMRIGHT", counter, "BOTTOMRIGHT", -3, 0)
kick:SetHeight(KICK_H)
kick:SetFrameLevel(counter:GetFrameLevel() + 1)
Wood.Paint(kick, "base", 141, { sheen = false })
Wood.EdgeShade(kick, kick, "TOP", 5, 0.7, "ARTWORK", 2)

local slab = CreateFrame("Frame", nil, counter)
slab:SetPoint("TOPLEFT", counter, "TOPLEFT", -5, 0)
slab:SetPoint("TOPRIGHT", counter, "TOPRIGHT", 5, 0)
slab:SetHeight(SLAB_H)
slab:SetFrameLevel(counter:GetFrameLevel() + 3)
local slabTop = slab:CreateTexture(nil, "BACKGROUND", nil, 1)
slabTop:SetAllPoints()
Wood.ApplyGrain(slabTop, "counterTop", 142)(COUNTER_W + 10, SLAB_H * 3)
Wood.Perspective(slabTop, 8)
local slabLight = slab:CreateTexture(nil, "BACKGROUND", nil, 2)
slabLight:SetAllPoints()
Wood.Gradient(slabLight, "VERTICAL", 1, 0.85, 0.6, 0.0, 0, 0, 0, 0.45)
Wood.Perspective(slabLight, 8)
local slabSheen = slab:CreateTexture(nil, "BACKGROUND", nil, 3)
slabSheen:SetPoint("BOTTOMLEFT", 12, 1)
slabSheen:SetPoint("BOTTOMRIGHT", -12, 1)
slabSheen:SetHeight(5)
slabSheen:SetBlendMode("ADD")
Wood.Gradient(slabSheen, "VERTICAL", 1, 0.85, 0.6, 0.16, 1, 0.85, 0.6, 0)

local lip = CreateFrame("Frame", nil, counter)
lip:SetPoint("TOPLEFT", slab, "BOTTOMLEFT", 0, 0)
lip:SetPoint("TOPRIGHT", slab, "BOTTOMRIGHT", 0, 0)
lip:SetHeight(LIP_H)
lip:SetFrameLevel(counter:GetFrameLevel() + 4)
Wood.Paint(lip, "counterTop", 143, { tone = 1.1, round = true, ends = true })

local counterSign = Wood.Nameplate(body, COUNTER_W - 14, 15, "GameFontNormalSmall")
counterSign:SetPoint("TOP", body, "TOP", 0, -8)
counterSign:SetFrameLevel(body:GetFrameLevel() + 3)

local props = CreateFrame("Frame", nil, counter)
props:SetAllPoints(slab)
props:SetFrameLevel(counter:GetFrameLevel() + 6)

-- Shared with Cart.lua (cart shelves in the counter front, quill and inkwell on the top).
Showroom.counter = { frame = counter, body = body, slab = slab, props = props, width = COUNTER_W }

for stack = 1, 2 do
    local x = 10 + (stack - 1) * 14
    local height = stack == 1 and 5 or 3
    local shadow = Wood.Disc(props, "ARTWORK", 0, 0, 0, 0, 0.5)
    shadow:SetSize(18, 6)
    shadow:SetPoint("CENTER", props, "BOTTOMLEFT", x + 1, 5)
    for c = 1, height do
        local edge = Wood.Disc(props, "ARTWORK", 1, 0.45, 0.30, 0.06, 1)
        edge:SetSize(14, 6)
        edge:SetPoint("CENTER", props, "BOTTOMLEFT", x, 6 + (c - 1) * 2)
        local face = Wood.Disc(props, "ARTWORK", 2, 0, 0, 0, 1)
        face:SetSize(13, 5)
        face:SetPoint("CENTER", edge, "CENTER", 0, 1)
        GradientDisc(face, "HORIZONTAL", 0.82, 0.62, 0.18, 1, 1, 0.90, 0.48, 1)
        if c == height then
            local glint = Wood.Disc(props, "ARTWORK", 3, 1, 1, 0.85, 0.75)
            glint:SetSize(4, 1.5)
            glint:SetPoint("CENTER", face, "CENTER", 2, 1)
        end
    end
end

local ledgerShadow = Wood.Disc(props, "ARTWORK", 0, 0, 0, 0, 0.5)
ledgerShadow:SetSize(38, 8)
ledgerShadow:SetPoint("CENTER", props, "BOTTOMRIGHT", -24, 4)
local ledgerPages = Wood.Solid(props, "ARTWORK", 1, 0.93, 0.88, 0.74, 1)
ledgerPages:SetSize(28, 3)
ledgerPages:SetPoint("BOTTOMRIGHT", props, "BOTTOMRIGHT", -11, 4)
local ledgerCover = props:CreateTexture(nil, "ARTWORK", nil, 2)
ledgerCover:SetSize(32, 6)
ledgerCover:SetPoint("BOTTOM", ledgerPages, "TOP", -1, 0)
Wood.Gradient(ledgerCover, "VERTICAL", 0.42, 0.08, 0.06, 1, 0.24, 0.04, 0.03, 1)
Wood.Perspective(ledgerCover, 3)
local ledgerBack = Wood.Solid(props, "ARTWORK", 1, 0.30, 0.05, 0.04, 1)
ledgerBack:SetSize(30, 1)
ledgerBack:SetPoint("TOP", ledgerPages, "BOTTOM")
local ledgerStrap = Wood.Solid(props, "ARTWORK", 3, 0.95, 0.78, 0.35, 1)
ledgerStrap:SetSize(2, 9)
ledgerStrap:SetPoint("BOTTOM", ledgerBack, "BOTTOM", 6, 0)

-- ---------------------------------------------------------------- display zone (left)
local displayZone = CreateFrame("Frame", nil, stageBay)
displayZone:SetPoint("BOTTOMLEFT", stageFloor, "TOPLEFT", -4, 0)
displayZone:SetSize(C.DISPLAY_W, C.STAGE_H)
displayZone:SetFrameLevel(stageBay:GetFrameLevel() + 6)

stageBay:HookScript("OnSizeChanged", function(_, _, h)
    if not h or h <= 0 then return end
    local sh = StageHeight(h)
    vendorZone:SetHeight(sh)
    displayZone:SetHeight(sh)
end)

local spotlight = displayZone:CreateTexture(nil, "BACKGROUND", nil, 1)
spotlight:SetPoint("TOPLEFT", 14, 0)
spotlight:SetPoint("BOTTOMRIGHT", -8, 0)
spotlight:SetBlendMode("ADD")
Wood.Gradient(spotlight, "VERTICAL", 1, 0.80, 0.50, 0.03, 1, 0.80, 0.50, 0.13)

-- The plinth stretches with the display bay, so a wide item gets a wide plinth.
local PLINTH_H, PLINTH_BOTTOM = 30, 8
local plinth = CreateFrame("Frame", nil, displayZone)
plinth:SetPoint("BOTTOMLEFT", displayZone, "BOTTOMLEFT", 22, PLINTH_BOTTOM)
plinth:SetPoint("BOTTOMRIGHT", displayZone, "BOTTOMRIGHT", -14, PLINTH_BOTTOM)
plinth:SetHeight(PLINTH_H)
plinth:SetFrameLevel(displayZone:GetFrameLevel() + 1)

local plinthShadow = Wood.Disc(plinth, "BACKGROUND", 0, 0, 0, 0, 0.6)
plinthShadow:SetPoint("TOPLEFT", plinth, "BOTTOMLEFT", -13, 8)
plinthShadow:SetPoint("BOTTOMRIGHT", plinth, "BOTTOMRIGHT", 15, -8)
local plinthFoot = Wood.Disc(plinth, "BACKGROUND", 1, 0, 0, 0, 1)
plinthFoot:SetPoint("TOPLEFT", plinth, "BOTTOMLEFT", -6, 9)
plinthFoot:SetPoint("BOTTOMRIGHT", plinth, "BOTTOMRIGHT", 6, -5)
Wood.Tint("plinth", 1, function(r, g, b) -- dark foot ring, about 0.27x to 0.65x the plinth wood
    GradientDisc(plinthFoot, "VERTICAL", r * 0.27, g * 0.25, b * 0.24, 1, r * 0.65, g * 0.64, b * 0.59, 1)
end)

local column = plinth:CreateTexture(nil, "BACKGROUND", nil, 2)
column:SetPoint("BOTTOMLEFT", plinth, "BOTTOMLEFT", 0, 2)
column:SetPoint("TOPRIGHT", plinth, "TOPRIGHT", 0, -6)
local columnMap = Wood.ApplyGrain(column, "plinth", 160, true)
local colL = plinth:CreateTexture(nil, "BACKGROUND", nil, 3)
colL:SetPoint("BOTTOMLEFT", plinth, "BOTTOMLEFT", 0, 2)
colL:SetPoint("TOPRIGHT", plinth, "TOP", -8, -6)
Wood.Gradient(colL, "HORIZONTAL", 0, 0, 0, 0.65, 0, 0, 0, 0)
local colR = plinth:CreateTexture(nil, "BACKGROUND", nil, 3)
colR:SetPoint("BOTTOMLEFT", plinth, "BOTTOM", -8, 2)
colR:SetPoint("TOPRIGHT", plinth, "TOPRIGHT", 0, -6)
Wood.Gradient(colR, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.75)

local plinthRim = Wood.Disc(plinth, "ARTWORK", 0, 0, 0, 0, 1)
plinthRim:SetPoint("TOPLEFT", plinth, "TOPLEFT", -3, 3)
plinthRim:SetPoint("BOTTOMRIGHT", plinth, "TOPRIGHT", 3, -15)
Wood.Tint("plinth", 1, function(r, g, b) -- rim around the top, about 0.42x to 0.92x the plinth wood
    GradientDisc(plinthRim, "VERTICAL", r * 0.42, g * 0.39, b * 0.35, 1, r * 0.92, g * 0.94, b * 0.88, 1)
end)
local plinthTop = plinth:CreateTexture(nil, "ARTWORK", nil, 1)
plinthTop:SetPoint("TOPLEFT", plinth, "TOPLEFT", 0, 1)
plinthTop:SetPoint("BOTTOMRIGHT", plinth, "TOPRIGHT", 0, -12)
local plinthMask = plinth:CreateMaskTexture()
plinthMask:SetAllPoints(plinthTop)
plinthMask:SetTexture(DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
plinthTop:AddMaskTexture(plinthMask)
local plinthTopMap = Wood.ApplyGrain(plinthTop, "plinth", 161, false, 1.2, plinthMask)
local plinthPool = Wood.Disc(plinth, "ARTWORK", 2, 1, 0.85, 0.55, 0.30)
plinthPool:SetPoint("TOPLEFT", plinthTop, "TOPLEFT", 16, -2.5)
plinthPool:SetPoint("BOTTOMRIGHT", plinthTop, "BOTTOMRIGHT", -16, 2.5)
plinthPool:SetBlendMode("ADD")
plinth:HookScript("OnSizeChanged", function(_, w)
    columnMap(w, PLINTH_H - 8)
    plinthTopMap(w, 40)
end)

local plinthPlate = Wood.Nameplate(plinth, 80, 12, "GameFontNormalSmall")
plinthPlate:ClearAllPoints()
plinthPlate:SetPoint("BOTTOMLEFT", plinth, "BOTTOMLEFT", 7, 5)
plinthPlate:SetPoint("BOTTOMRIGHT", plinth, "BOTTOMRIGHT", -7, 5)
plinthPlate:SetFrameLevel(plinth:GetFrameLevel() + 2)
do
    local font, _, flags = plinthPlate.text:GetFont()
    if font then plinthPlate.text:SetFont(font, 9, flags) end
end
plinthPlate:EnableMouse(true)
plinthPlate:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(self.text:GetText() or "", 1, 1, 1)
    local dims = displayStage and displayStage.dims
    if dims then
        GameTooltip:AddLine(string.format("Size: %.2f x %.2f x %.2f (depth x width x height, game units)",
            dims[1], dims[2], dims[3]), 0.9, 0.8, 0.6, true)
    end
    GameTooltip:Show()
end)
plinthPlate:SetScript("OnLeave", function() GameTooltip:Hide() end)
plinthPlate:Hide()

-- The 3D region covers the whole bay down to the floor (so nothing is clipped at the plinth);
-- models are seated just above the plinth's top surface.
local PLINTH_SEAT = PLINTH_BOTTOM + PLINTH_H - 1 -- just above the top surface's centre line: items rest ON it
local displayArea = CreateFrame("Frame", nil, displayZone)
displayArea:SetPoint("TOPLEFT", displayZone, "TOPLEFT", 0, -6)
displayArea:SetPoint("BOTTOMRIGHT", displayZone, "BOTTOMRIGHT", 0, 0)
displayArea:SetFrameLevel(stageBay:GetFrameLevel() + 12)

local displayHint = displayArea:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
displayHint:SetPoint("LEFT", displayArea, "LEFT", 12, 20)
displayHint:SetPoint("RIGHT", displayArea, "RIGHT", -12, 20)
displayHint:SetTextColor(0.85, 0.70, 0.48, 0.65)
displayHint:SetJustifyH("CENTER")

local MIN_ITEM_PX = 22      -- tiny items are never drawn shorter than this
local MAX_EXTRA_W = 160     -- the bay may widen this much for long items
local FALLBACK_VENDOR_H = 2.1

-- Shared scale (px per game unit): the vendor's body fills about VENDOR_FIT of its frame, so
-- dividing by the measured vendor height gives the scale items must use to look in proportion.
-- Before the measurement arrives (or if it can't be taken), assume a typical humanoid.
local function SharedScale()
    if vendorStage and vendorStage.scene:IsShown() and vendorStage.lockedP then
        return vendorStage.lockedP -- exact: the vendor is on a calibrated stage
    end
    local h = vendorModel:GetHeight() or 0
    if h <= 0 then return nil end
    return h * C.VENDOR_FIT / (vendorHeight or FALLBACK_VENDOR_H)
end

displayStage = CreateStage(displayArea, {
    seat = PLINTH_SEAT, yaw = 0.6, autoYaw = true, wheelZoom = true, minPx = MIN_ITEM_PX, anyAngle = true,
    scaleFn = SharedScale,
    onBox = function() Showroom.FitBayToModel() end,
    onRightClick = function() Showroom:ClearDisplay() end,
})

-- Widen the bay (and the window) when a long model would otherwise have to shrink.
function Showroom.FitBayToModel()
    if not (displayStage and displayStage.box) then return end
    local W, H = displayArea:GetWidth(), displayArea:GetHeight()
    if not H or H <= 0 then return end
    local _, _, _, _, wantW = Showroom.ComputeFraming(displayStage.box, W, H,
        { seat = PLINTH_SEAT, yaw = displayStage.yaw, p = SharedScale(), minPx = MIN_ITEM_PX, anyAngle = true })
    local extra = math.min(MAX_EXTRA_W, math.max(0, math.ceil(wantW - C.DISPLAY_W)))
    Showroom:SetDisplayExtra(extra)
end

-- The vendor's height arrived after an item was already on the plinth: re-scale the item.
function Showroom.OnVendorMeasured()
    if displayStage and displayStage.box then
        Showroom.FitBayToModel()
        displayStage:Frame()
    end
end

-- /venstore debug: prints the sizing numbers (window, vendor scale, each stage's lens and scale).
function Showroom.DebugDump()
    local function size(f) return string.format("%.0fx%.0f", f:GetWidth() or 0, f:GetHeight() or 0) end
    print(string.format("|cffffd100VenStore debug|r  client %s (interface %s)", addon.IS_FOREVER and "WoW Forever" or "Retail",
        tostring(select(4, GetBuildInfo()))))
    print(string.format("  window %s scale %.2f | vendor frame %s | plinth region %s",
        size(ShelfFrame), ShelfFrame:GetScale() or 1, size(vendorModel), size(displayArea)))
    local onStage = vendorStage and vendorStage.scene:IsShown()
    print(string.format("  vendor drawn by %s (display ID %s) | height %s -> shared scale %.1f px/unit",
        onStage and "calibrated 3D stage" or "PlayerModel", tostring(vendorStage and vendorStage.displayID),
        vendorHeight and string.format("%.2f", vendorHeight) or "not measured", SharedScale() or 0))
    for _, entry in ipairs({ { "vendor", vendorStage }, { "plinth", displayStage }, { "mirror", mirrorStage } }) do
        local st = entry[2]
        if st then
            print(string.format("  %s lens %.3f (%s), scene %s, %s", entry[1], st.lens or 0,
                st.calibrated and "measured" or "not measured yet", size(st.scene),
                st.box and string.format("%.1f px/unit, zoom %.2f of max %.2f", st.p or 0, st.zoom, st.maxZoom or 1) or "empty"))
        end
    end
    if displayStage and displayStage.box then
        local b = displayStage.box
        local p, dist, camY, camZ, wantW, fov = Showroom.ComputeFraming(b, displayArea:GetWidth(), displayArea:GetHeight(),
            displayStage:FramingOptions())
        print(string.format("  item box x %.2f..%.2f y %.2f..%.2f z %.2f..%.2f yaw %.2f zoom %.2f",
            b.minX, b.maxX, b.minY, b.maxY, b.minZ, b.maxZ, displayStage.yaw, displayStage.zoom))
        print(string.format("  camera dist %.2f y %.2f z %.2f fov %.2f -> %.1f px/unit, wants %.0f px wide; scene %s",
            dist, camY, camZ, fov, p, wantW, size(displayStage.scene)))
        local scene = displayStage.scene
        if scene.Project3DPointTo2D then
            local ok, bx, by = pcall(scene.Project3DPointTo2D, scene, 0, 0, b.minZ)
            local ok2, tx, ty = pcall(scene.Project3DPointTo2D, scene, 0, 0, b.maxZ)
            if ok and ok2 then
                print(string.format("  engine projects base -> %s, %s  top -> %s, %s  (scene bottom %.1f, top %.1f)",
                    tostring(bx), tostring(by), tostring(tx), tostring(ty), scene:GetBottom() or 0, scene:GetTop() or 0))
            end
        end
    else
        print("  (Ctrl-Click a mount, pet or decor item first to include the plinth numbers)")
    end
end

-- Fallback when ModelScenes are unavailable: mounts / pets on a PlayerModel.
local displayModel = CreateFrame("PlayerModel", nil, displayArea)
displayModel:SetPoint("TOPLEFT", displayArea, "TOPLEFT", 0, 0)
displayModel:SetPoint("BOTTOMRIGHT", displayArea, "BOTTOMRIGHT", 0, PLINTH_SEAT)
displayModel:SetFrameLevel(displayArea:GetFrameLevel() + 2)
displayModel:Hide()

local displayClear = Wood.BrassButton(displayArea, 16, "x", "Clear the display")
displayClear:SetPoint("TOPLEFT", displayArea, "TOPLEFT", 4, -2)
displayClear:SetFrameLevel(displayArea:GetFrameLevel() + 20)
displayClear:Hide()

-- ============================================================================
-- DISPLAY ROUTING
-- ============================================================================
local gestureToken = 0

local function PlayVendorAnim(anim)
    if vendorStage and vendorStage.scene:IsShown() then
        pcall(vendorStage.actor.SetAnimation, vendorStage.actor, anim)
    elseif vendorModel:IsShown() then
        pcall(vendorModel.SetAnimation, vendorModel, anim)
    end
end

local function VendorPresentGesture()
    gestureToken = gestureToken + 1
    local token = gestureToken
    PlayVendorAnim(60) -- talk / present
    C_Timer.After(2.5, function()
        if token == gestureToken then PlayVendorAnim(0) end
    end)
end

local function SetDisplayHint(text)
    displayHint:SetText(text)
    displayHint:SetShown(text ~= nil)
end

function Showroom:ClearDisplay()
    if displayStage then displayStage:Clear() end
    displayModel:Hide()
    displayClear:Hide()
    plinthPlate:Hide()
    SetDisplayHint("Ctrl-Click an item\nto display it here")
    self:SetDisplayExtra(0)
end
displayClear:SetScript("OnClick", function() Showroom:ClearDisplay() end)
MakeInteractive(displayModel, 0.35, { zoom = true, onRightClick = function() Showroom:ClearDisplay() end })

local function ShowCreatureOnPlayerModel(info)
    displayModel:Show()
    displayModel:ClearModel()
    displayModel.rotation = 0.35
    if info.displayID and info.displayID > 0 then
        displayModel:SetDisplayInfo(info.displayID)
    else
        displayModel:SetCreature(info.creatureID)
    end
    SetCam(displayModel, info.kind == "mount" and 1.45 or 1.1)
    displayModel:SetFacing(0.35)
end

local function ShowOnDisplay(info, name)
    Showroom:ClearDisplay()
    SetDisplayHint(nil)
    plinthPlate.text:SetText(name or "")
    plinthPlate:Show()
    displayClear:Show()
    VendorPresentGesture()

    local hasDisplayID = info.displayID and info.displayID > 0
    if displayStage and (info.kind == "decor" or hasDisplayID) then
        displayStage:Load(function(actor)
            if info.kind == "decor" then
                actor:SetModelByFileID(info.asset)
            else
                actor:SetModelByCreatureDisplayID(info.displayID)
            end
        end)
    elseif info.kind ~= "decor" then
        ShowCreatureOnPlayerModel(info)
    else
        SetDisplayHint("No 3D model\nfor this item")
    end
end

function Showroom:Preview(merchantIndex)
    local link = GetMerchantItemLink(merchantIndex)
    if not link then return end
    local name = addon.GetVendorItemData(merchantIndex)
    if ShelfFrame.showMirror and addon.IsCosmeticItem(link, name) then
        TryOnMirror(link)
        return
    end
    local info = addon.GetDisplayInfo(link)
    if not info then
        UIErrorsFrame:AddMessage("VenStore: this item has no 3D preview.", 1, 0.82, 0)
        return
    end
    if not ShelfFrame.showDisplay then
        self:SetDisplayShown(true)
        addon.ApplyGrid()
    end
    ShowOnDisplay(info, name)
end

-- ============================================================================
-- LAYOUT / STATE
-- ============================================================================
function Showroom:Layout()
    local stageW = addon.GetStageWidth()
    stageBay:SetWidth(stageW)
    displayZone:SetWidth(C.DISPLAY_W + (self.displayExtra or 0))
    displayZone:SetShown(ShelfFrame.showDisplay)
    mirrorBay:ClearAllPoints()
    mirrorBay:SetPoint("TOPRIGHT", ShelfFrame, "TOPRIGHT", -(stageW + C.STAGE_GAP + 20), -C.HEADER_H)
    mirrorBay:SetPoint("BOTTOMRIGHT", ShelfFrame, "BOTTOMRIGHT", -(stageW + C.STAGE_GAP + 20), C.FOOTER_H)
    mirrorBay:SetShown(ShelfFrame.showMirror)
end

function Showroom:SetMirrorShown(show)
    ShelfFrame.showMirror = show and true or false
    self:Layout()
end

-- Extra width for the display bay while a long model is shown (0 = normal size).
function Showroom:SetDisplayExtra(extra)
    extra = extra or 0
    if extra == (self.displayExtra or 0) then return end
    self.displayExtra = extra
    self:Layout()
    addon.ApplyGrid()
end

function Showroom:SetDisplayShown(show)
    ShelfFrame.showDisplay = show and true or false
    if not ShelfFrame.showDisplay then self:ClearDisplay() end
    self:Layout()
end

local function ShowVendor()
    local unit = UnitExists("npc") and "npc" or (UnitExists("target") and "target") or nil
    if vendorStage then
        vendorStage:Clear()
        vendorStage.displayID = nil
    end
    vendorModel:Show()
    vendorModel:ClearModel()
    if unit then
        vendorModel:SetUnit(unit)
        MeasureVendor(unit)
        TryVendorStage() -- may already know the display ID; otherwise OnModelLoaded retries
    end
    vendorModel.rotation = VENDOR_YAW
    vendorModel:SetFacing(VENDOR_YAW)
end

-- /venstore vendor: toggle between the calibrated 3D vendor and the plain PlayerModel.
function Showroom:ToggleClassicVendor()
    if not addon.db then return end
    addon.db.classicVendor = not addon.db.classicVendor
    if ShelfFrame:IsShown() then ShowVendor() end
    return addon.db.classicVendor
end

function Showroom:Reset()
    self:ClearDisplay()
    counterSign.text:SetText(addon.GetNPCName() or "Merchant")
    ShowVendor()

    mirrorLoaded = false
    wipe(tried)
    if mirrorStage then mirrorStage:Clear() end
    poseIndex = 1
    for i, b in ipairs(poseButtons) do b:SetSelected(i == 1) end
    SetMirrorGlass(true)
end

function Showroom:OnMerchantClosed()
    gestureToken = gestureToken + 1
    measureToken = measureToken + 1
    if measureActor then measureActor:ClearModel() end
    if vendorStage then vendorStage:Clear(); vendorStage.displayID = nil end
    if displayStage then displayStage:Clear() end
    if mirrorStage then mirrorStage:Clear() end
    mirrorLoaded = false
end

Showroom._CreateStage = CreateStage -- test hook
Showroom:Layout()
