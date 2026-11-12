-- VenStore: shopping cart on the sales counter.
-- Drag items from the shop shelves (or Alt-Click them) onto the two shelves in the front of the
-- counter: four items at most, each with a quantity (mouse wheel, or Shift-click for a quantity
-- picker; Shift-click a shelf item to add a chosen amount). Click the quill on the counter top to sign
-- the bill of sale: the quill floats up, signs the slip, and everything is bought.
local _, addon = ...
local Wood, Showroom = addon.Wood, addon.Showroom
local parts = Showroom.counter
local body, props, counterFrame = parts.body, parts.props, parts.frame
local DISC = Wood.DISC

local Cart = { items = {}, token = 0 }
addon.Cart = Cart

local MAX_ITEMS = 4      -- two shelves, two items each
local MAX_QTY = 999      -- per item, also limited by the stock and by your gold (purchases are
                         -- sent one batch / one stack at a time)
local BUY_SPACING = 0.2  -- seconds between purchase requests
local ICON = 34
local QUILL_TEX = "Interface\\AddOns\\VenStore\\textures\\quill"

local function Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function Sound(key) if SOUNDKIT and SOUNDKIT[key] then PlaySound(SOUNDKIT[key]) end end
local function Err(msg) UIErrorsFrame:AddMessage(msg, 1, 0.25, 0.15) end

-- ============================================================================
-- CART SHELVES (front of the counter)
-- ============================================================================
-- An open cubby in the counter front: oak face frame, dark recessed back wall, two shelf boards.
local cubby = CreateFrame("Frame", nil, body)
cubby:SetPoint("TOPLEFT", body, "TOPLEFT", 7, -28)
cubby:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -7, 6)
cubby:SetFrameLevel(body:GetFrameLevel() + 1)
Wood.Paint(cubby, "counterTrim", 150, { grain = "V" })

local recess = CreateFrame("Frame", nil, cubby)
recess:SetPoint("TOPLEFT", 5, -5)
recess:SetPoint("BOTTOMRIGHT", -5, 5)
recess:SetFrameLevel(cubby:GetFrameLevel() + 1)
Wood.Paint(recess, "counter", 151,
    { tone = 0.55, grain = "V", sheen = false, bevel = false })
local recessDark = recess:CreateTexture(nil, "BORDER", nil, 0)
recessDark:SetAllPoints()
Wood.Gradient(recessDark, "VERTICAL", 0, 0, 0, 0.15, 0, 0, 0, 0.55) -- the counter top shades the back wall
Wood.EdgeShade(recess, recess, "TOP", 14, 0.85, "BORDER", 1)
Wood.EdgeShade(recess, recess, "LEFT", 7, 0.6, "BORDER", 1)
Wood.EdgeShade(recess, recess, "RIGHT", 7, 0.6, "BORDER", 1)
-- face frame lip: light on the top/left inner edge of the opening, dark below
local lipLight = Wood.Solid(cubby, "ARTWORK", 2, 0.05, 0.02, 0.01, 0.85)
lipLight:SetPoint("TOPLEFT", recess, "TOPLEFT", -1, 1); lipLight:SetPoint("TOPRIGHT", recess, "TOPRIGHT", 1, 1); lipLight:SetHeight(1)
local lipLow = Wood.Solid(cubby, "ARTWORK", 2, 0.85, 0.62, 0.36, 0.45)
lipLow:SetPoint("BOTTOMLEFT", recess, "BOTTOMLEFT", -1, -1); lipLow:SetPoint("BOTTOMRIGHT", recess, "BOTTOMRIGHT", 1, -1); lipLow:SetHeight(1)

-- Shelf boards: tier 1 halfway up, tier 2 on the bottom of the opening.
local BOARD_H = 6
local boards = {}
for tier = 1, 2 do
    local board = CreateFrame("Frame", nil, recess)
    board:SetHeight(BOARD_H)
    board:SetFrameLevel(recess:GetFrameLevel() + 2)
    Wood.Paint(board, "shelf", 152 + tier, { round = true, ends = true, flip = true })
    local under = Wood.Solid(recess, "ARTWORK", 0, 0, 0, 0, 1)
    under:SetPoint("TOPLEFT", board, "BOTTOMLEFT"); under:SetPoint("TOPRIGHT", board, "BOTTOMRIGHT"); under:SetHeight(9)
    Wood.Gradient(under, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.65)
    boards[tier] = board
end
local function PlaceBoards()
    local h = recess:GetHeight() or 0
    boards[1]:ClearAllPoints()
    boards[1]:SetPoint("BOTTOMLEFT", recess, "BOTTOMLEFT", 0, math.floor(h / 2))
    boards[1]:SetPoint("BOTTOMRIGHT", recess, "BOTTOMRIGHT", 0, math.floor(h / 2))
    boards[2]:ClearAllPoints()
    boards[2]:SetPoint("BOTTOMLEFT", recess, "BOTTOMLEFT", 0, 0)
    boards[2]:SetPoint("BOTTOMRIGHT", recess, "BOTTOMRIGHT", 0, 0)
end
recess:HookScript("OnSizeChanged", PlaceBoards)
PlaceBoards()

local emptyHint = recess:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
emptyHint:SetPoint("BOTTOM", boards[1], "TOP", 0, 10)
emptyHint:SetText("Drag items here")
emptyHint:SetTextColor(0.85, 0.70, 0.48, 0.7)

-- ---------------------------------------------------------------- cart slots
local slots = {}

local function SlotTooltip(self)
    local e = Cart.items[self.id]
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if e then
        GameTooltip:SetMerchantItem(e.index)
        local _, _, _, stack = addon.GetVendorItemData(e.index)
        GameTooltip:AddLine(" ")
        local each = (stack and stack > 1) and string.format(" (%d per purchase)", stack) or ""
        GameTooltip:AddLine(string.format("On the counter: %d%s", e.qty, each), 1, 0.82, 0)
        GameTooltip:AddLine("Mouse wheel: change the quantity (hold Shift: by 10)", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Shift-click: choose a quantity", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click: take it off the counter", 0.7, 0.7, 0.7)
    else
        GameTooltip:SetText("Cart shelf", 1, 1, 1)
        GameTooltip:AddLine("Drag an item from the shelves here (or Alt-Click it) to add it to your cart. "
            .. "Then click the quill to sign for everything.", 1, 0.82, 0, true)
    end
    GameTooltip:Show()
end

local function MakeDropTarget(f)
    f:EnableMouse(true)
    f:SetScript("OnReceiveDrag", function() Cart:TakeFromCursor() end)
    f:HookScript("OnMouseUp", function() Cart:TakeFromCursor() end)
end
MakeDropTarget(cubby)
MakeDropTarget(recess)

local function CreateSlot(id)
    local b = CreateFrame("Button", nil, recess)
    b.id = id
    b:SetSize(ICON, ICON)
    b:SetFrameLevel(recess:GetFrameLevel() + 4)
    local tier, col = math.floor((id - 1) / 2) + 1, (id - 1) % 2
    b:SetPoint("BOTTOM", boards[tier], "TOP", (col == 0 and -1 or 1) * 40, 0)

    local shadow = Wood.Disc(b, "BACKGROUND", 0, 0, 0, 0, 0.65)
    shadow:SetSize(ICON + 12, 7)
    shadow:SetPoint("CENTER", b, "BOTTOM", 2, 1)
    b.shadow = shadow

    -- Empty: a faint brass outline; it glows while an item from the shop is on the cursor.
    b.outline = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = Wood.Solid(b, "BACKGROUND", 1, 0.95, 0.78, 0.40, 0.22)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
        end
        b.outline[#b.outline + 1] = t
    end
    b.glow = Wood.Disc(b, "BACKGROUND", 2, 1, 0.82, 0.40, 0.55)
    b.glow:SetPoint("TOPLEFT", -8, 8); b.glow:SetPoint("BOTTOMRIGHT", 8, -8)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()

    b.back = b:CreateTexture(nil, "ARTWORK", nil, 0)
    b.back:SetAllPoints()
    b.back:SetColorTexture(0.04, 0.03, 0.02, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.border = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = Wood.Solid(b, "ARTWORK", 2, 1, 1, 1, 1)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1.5)
        else
            t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1.5)
        end
        b.border[#b.border + 1] = t
    end
    b.gloss = b:CreateTexture(nil, "ARTWORK", nil, 3)
    b.gloss:SetPoint("TOPLEFT", 2, -2); b.gloss:SetPoint("TOPRIGHT", -2, -2); b.gloss:SetHeight(ICON * 0.45)
    b.gloss:SetBlendMode("ADD")
    Wood.Gradient(b.gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.16)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)

    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 0.9, 0.6, 0.18)
    hl:SetBlendMode("ADD")

    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnReceiveDrag", function() Cart:TakeFromCursor() end)
    b:SetScript("OnClick", function(self, button)
        if Cart:TakeFromCursor() then return end
        if button == "RightButton" then
            Cart:Remove(self.id)
        elseif IsShiftKeyDown() and Cart.items[self.id] then
            Cart:PickQuantity(self, Cart.items[self.id].index)
        end
    end)
    b:EnableMouseWheel(true)
    b:SetScript("OnMouseWheel", function(self, delta) Cart:ChangeQty(self.id, delta * (IsShiftKeyDown() and 10 or 1)) end)
    b:SetScript("OnEnter", SlotTooltip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end

-- ============================================================================
-- QUANTITY PICKER (Shift-click a shelf item or a cart slot)
-- ============================================================================
local picker = CreateFrame("Frame", nil, addon.ShelfFrame, "BackdropTemplate")
picker:SetSize(196, 96)
picker:SetFrameStrata("DIALOG")
picker:EnableMouse(true)
picker:SetBackdrop({
    bgFile = "Interface\Buttons\WHITE8X8",
    edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
    edgeSize = 20,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
})
picker:SetBackdropColor(0.09, 0.06, 0.03, 0.97)
picker:SetBackdropBorderColor(0.80, 0.66, 0.48, 1)
picker:Hide()
addon.ShelfFrame:HookScript("OnHide", function() picker:Hide() end)

local pickerTitle = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
pickerTitle:SetPoint("TOP", picker, "TOP", 0, -12)
pickerTitle:SetWidth(176)
pickerTitle:SetWordWrap(false)

local pickerBox = CreateFrame("EditBox", nil, picker, "InputBoxTemplate")
pickerBox:SetSize(52, 20)
pickerBox:SetPoint("TOP", picker, "TOP", 0, -32)
pickerBox:SetAutoFocus(false)
pickerBox:SetNumeric(true)
pickerBox:SetMaxLetters(4)
pickerBox:SetJustifyH("CENTER")

local function PickerButton(text, w)
    local b = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    return b
end
local minus, plus = PickerButton("-", 26), PickerButton("+", 26)
minus:SetPoint("RIGHT", pickerBox, "LEFT", -10, 0)
plus:SetPoint("LEFT", pickerBox, "RIGHT", 4, 0)
local maxBtn = PickerButton("Max", 40)
maxBtn:SetPoint("LEFT", plus, "RIGHT", 2, 0)
local okBtn, cancelBtn = PickerButton(OKAY or "Okay", 76), PickerButton(CANCEL or "Cancel", 76)
okBtn:SetPoint("BOTTOMRIGHT", picker, "BOTTOM", -2, 10)
cancelBtn:SetPoint("BOTTOMLEFT", picker, "BOTTOM", 2, 10)

local function PickerValue()
    return Clamp(tonumber(pickerBox:GetText()) or 1, 1, picker.max or 1)
end
local function SetPickerValue(v)
    pickerBox:SetText(tostring(Clamp(math.floor(v), 1, picker.max or 1)))
end
local function Step(delta)
    local step = IsShiftKeyDown() and 10 or 1
    SetPickerValue(PickerValue() + delta * step)
end
minus:SetScript("OnClick", function() Step(-1) end)
plus:SetScript("OnClick", function() Step(1) end)
maxBtn:SetScript("OnClick", function() SetPickerValue(picker.max or 1) end)
picker:EnableMouseWheel(true)
picker:SetScript("OnMouseWheel", function(_, delta) Step(delta) end)
local function Accept()
    local q = PickerValue()
    picker:Hide()
    if picker.onAccept then picker.onAccept(q) end
end
okBtn:SetScript("OnClick", Accept)
cancelBtn:SetScript("OnClick", function() picker:Hide() end)
pickerBox:SetScript("OnEnterPressed", Accept)
pickerBox:SetScript("OnEscapePressed", function() picker:Hide() end)

-- Ask how many (1..max) of the item, starting at `current`, next to `anchor`.
local function OpenPicker(anchor, name, current, max, onAccept)
    picker.max, picker.onAccept = math.max(1, max), onAccept
    pickerTitle:SetText(name or "How many?")
    SetPickerValue(current or 1)
    picker:ClearAllPoints()
    picker:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    picker:Show()
    pickerBox:SetFocus()
    pickerBox:HighlightText()
end

for i = 1, MAX_ITEMS do slots[i] = CreateSlot(i) end

-- Highlight where an item can go while one from the shop is on the cursor.
local function CursorMerchantIndex()
    local kind, index = GetCursorInfo()
    if kind == "merchant" then return index end
end

local function UpdateDropGlow()
    local index = CursorMerchantIndex()
    local full = #Cart.items >= MAX_ITEMS
    for i, b in ipairs(slots) do
        local e = Cart.items[i]
        local show = index ~= nil and not Cart.busy and ((not e and not full) or (e and e.index == index))
        b.glow:SetShown(show)
    end
end
addon.RegisterEventSafe(cubby, "CURSOR_CHANGED")
cubby:SetScript("OnEvent", UpdateDropGlow)

-- ============================================================================
-- BILL OF SALE, INKWELL AND QUILL (counter top)
-- ============================================================================
-- Positions are measured from the counter top's bottom-left corner (the `props` frame).
local SLIP_L, SLIP_W, SLIP_Y = 36, 46, 6.5
local INK_X = parts.width + 10 - 58 -- the counter top overhangs the counter by 5 px a side
local QW, QH = 11, 44

-- The bill of sale: a parchment slip lying on the counter (shown while there's something to buy).
local slip = CreateFrame("Button", nil, props)
slip:SetSize(SLIP_W, 9)
slip:SetPoint("BOTTOMLEFT", props, "BOTTOMLEFT", SLIP_L, 2)
slip:SetFrameLevel(props:GetFrameLevel() + 1)
local slipShadow = Wood.Disc(slip, "BACKGROUND", 0, 0, 0, 0, 0.45)
slipShadow:SetPoint("TOPLEFT", -3, -2); slipShadow:SetPoint("BOTTOMRIGHT", 4, -3)
local paper = slip:CreateTexture(nil, "ARTWORK", nil, 0)
paper:SetAllPoints()
Wood.Gradient(paper, "VERTICAL", 0.86, 0.79, 0.62, 1, 0.97, 0.92, 0.78, 1)
Wood.Perspective(paper, 4)
for row = 1, 2 do -- printed lines of the bill (too small to read, which is how bills look across a counter)
    local line = Wood.Solid(slip, "ARTWORK", 1, 0.35, 0.25, 0.15, 0.45)
    line:SetSize(SLIP_W * (row == 1 and 0.55 or 0.40), 1)
    line:SetPoint("TOPLEFT", slip, "TOPLEFT", 6 + row, -2 - (row - 1) * 2)
end
local sigLine = Wood.Solid(slip, "ARTWORK", 1, 0.30, 0.22, 0.14, 0.5)
sigLine:SetSize(SLIP_W - 10, 1)
sigLine:SetPoint("BOTTOMLEFT", slip, "BOTTOMLEFT", 5, 2)

-- The signature, revealed dot by dot as the quill moves.
local SIG_DOTS = 56
local sigDots = {}
local function SignaturePoint(s) -- s = 0..1 along the signature; returns props-local x, y
    local x = SLIP_L + 4 + s * (SLIP_W - 9)
    local y = SLIP_Y + 1.7 * math.sin(s * 2 * math.pi * 3.3) * (0.6 + 0.4 * math.sin(s * 2 * math.pi * 1.1))
        + 0.7 * math.sin(s * 2 * math.pi * 7.5)
    return x, y
end
for i = 1, SIG_DOTS do
    local d = Wood.Solid(slip, "OVERLAY", 2, 0.10, 0.06, 0.14, 0.95) -- on the slip, above the paper
    d:SetSize(1.6, 1.4)
    local x, y = SignaturePoint((i - 1) / (SIG_DOTS - 1))
    d:SetPoint("CENTER", props, "BOTTOMLEFT", x, y)
    d:Hide()
    sigDots[i] = d
end
local function ShowSignature(upTo)
    for i, d in ipairs(sigDots) do d:SetShown((i - 1) / (SIG_DOTS - 1) <= upTo) end
end

-- Inkwell: dark glass pot with a brass collar. Drawn above the quill so the nib sits inside it.
local inkFrame = CreateFrame("Frame", nil, counterFrame)
inkFrame:SetAllPoints(props)
inkFrame:SetFrameLevel(props:GetFrameLevel() + 3)
local inkShadow = Wood.Disc(inkFrame, "ARTWORK", 0, 0, 0, 0, 0.55)
inkShadow:SetSize(20, 6)
inkShadow:SetPoint("CENTER", props, "BOTTOMLEFT", INK_X + 2, 3)
local inkPot = Wood.Disc(inkFrame, "ARTWORK", 1, 0, 0, 0, 1)
inkPot:SetSize(14, 12)
inkPot:SetPoint("CENTER", props, "BOTTOMLEFT", INK_X, 8)
Wood.GradientFile(inkPot, DISC, "HORIZONTAL", 0.05, 0.07, 0.12, 1, 0.22, 0.28, 0.40, 1)
local inkGlint = Wood.Disc(inkFrame, "ARTWORK", 2, 0.75, 0.85, 1, 0.55)
inkGlint:SetSize(3, 5)
inkGlint:SetPoint("CENTER", inkPot, "CENTER", -3, 1)
local inkCollar = inkFrame:CreateTexture(nil, "ARTWORK", nil, 3)
inkCollar:SetSize(8, 3)
inkCollar:SetPoint("BOTTOM", inkPot, "TOP", 0, -2)
Wood.Brass(inkCollar)
local INK_MOUTH_Y = 13

-- The quill (generated texture, tools/QuillGen.cs).
local quillFrame = CreateFrame("Frame", nil, counterFrame)
quillFrame:SetAllPoints(props)
quillFrame:SetFrameLevel(props:GetFrameLevel() + 2)
local quillShadow = Wood.Disc(quillFrame, "ARTWORK", 0, 0, 0, 0, 0.4)
local quillGlow = Wood.Disc(quillFrame, "ARTWORK", 1, 1, 0.85, 0.45, 0.35)
quillGlow:SetBlendMode("ADD")
quillGlow:Hide()
local quill = quillFrame:CreateTexture(nil, "ARTWORK", nil, 2)
quill:SetTexture(QUILL_TEX)
quill:SetSize(QW, QH)

-- Place the quill by its nib (props-local x, y) and lean (radians, + = top to the left).
local function PoseQuill(nx, ny, angle)
    -- The texture rotates about its centre; the nib is half the quill's length below the centre.
    local cx = nx - math.sin(angle) * QH / 2
    local cy = ny + math.cos(angle) * QH / 2
    quill:ClearAllPoints()
    quill:SetPoint("CENTER", props, "BOTTOMLEFT", cx, cy)
    if quill.SetRotation then quill:SetRotation(angle) end
    quillGlow:ClearAllPoints()
    quillGlow:SetPoint("CENTER", props, "BOTTOMLEFT", cx, cy)
    quillGlow:SetSize(QW + 18, QH + 10)
    -- Shadow on the counter top: smaller and fainter the higher the quill floats.
    local lift = math.max(0, ny - INK_MOUTH_Y)
    quillShadow:ClearAllPoints()
    quillShadow:SetPoint("CENTER", props, "BOTTOMLEFT", nx + 3 + lift * 0.1, 4)
    quillShadow:SetSize(Clamp(16 - lift * 0.15, 6, 16), 4)
    quillShadow:SetAlpha(Clamp(0.45 - lift / 90, 0.08, 0.45))
end

local REST = { INK_X, 8, -0.30 }
PoseQuill(REST[1], REST[2], REST[3])

-- ---------------------------------------------------------------- signing animation
local function Smooth(t) t = Clamp(t, 0, 1); return t * t * (3 - 2 * t) end
local function Lerp(a, b, t) return a + (b - a) * t end
local function Move(p, q, t, arc)
    local e = Smooth(t)
    return Lerp(p[1], q[1], e), Lerp(p[2], q[2], e) + (arc or 0) * math.sin(math.pi * Clamp(t, 0, 1)), Lerp(p[3], q[3], e)
end

local UP = { INK_X, 40, -0.55 }
local OVER = { SLIP_L + 4, 24, -0.65 }
local START = { SignaturePoint(0) }
START[3] = -0.65
local FINISH = { SLIP_L + SLIP_W - 2, SLIP_Y + 16, -0.45 }

-- Timeline (seconds): lift, travel, dip, sign, flourish (purchase), return, settle.
local T_LIFT, T_TRAVEL, T_DIP, T_SIGN, T_FLOURISH, T_RETURN, T_SETTLE = 0.35, 0.75, 0.90, 2.00, 2.15, 2.65, 2.95

local anim -- { t, mode = "sign" | "shake", onSigned, fired }
local animDriver = CreateFrame("Frame", nil, quillFrame)

local function StopAnim()
    anim = nil
    animDriver:SetScript("OnUpdate", nil)
    quillGlow:Hide()
    PoseQuill(REST[1], REST[2], REST[3])
end

local function StepAnim(_, elapsed)
    if not anim then return StopAnim() end
    anim.t = anim.t + elapsed
    local t = anim.t
    if anim.mode == "shake" then -- "can't sign that": a short shake in the inkwell
        if t >= 0.45 then return StopAnim() end
        PoseQuill(REST[1], REST[2] + 2, REST[3] + 0.16 * math.sin(t * 45) * (1 - t / 0.45))
        return
    end
    local x, y, a
    if t < T_LIFT then
        x, y, a = Move(REST, UP, t / T_LIFT)
    elseif t < T_TRAVEL then
        x, y, a = Move(UP, OVER, (t - T_LIFT) / (T_TRAVEL - T_LIFT), 10)
    elseif t < T_DIP then
        x, y, a = Move(OVER, START, (t - T_TRAVEL) / (T_DIP - T_TRAVEL))
    elseif t < T_SIGN then
        local s = (t - T_DIP) / (T_SIGN - T_DIP)
        x, y = SignaturePoint(s)
        a = -0.65 + 0.07 * math.sin(s * math.pi * 9)
        ShowSignature(s)
    elseif t < T_FLOURISH then
        ShowSignature(1)
        local fx, fy = SignaturePoint(1)
        x, y, a = Move({ fx, fy, -0.65 }, FINISH, (t - T_SIGN) / (T_FLOURISH - T_SIGN))
    elseif t < T_RETURN then
        x, y, a = Move(FINISH, UP, (t - T_FLOURISH) / (T_RETURN - T_FLOURISH), 8)
    elseif t < T_SETTLE then
        x, y, a = Move(UP, REST, (t - T_RETURN) / (T_SETTLE - T_RETURN))
    else
        local done = anim.onDone
        StopAnim()
        if done then done() end
        return
    end
    if t >= T_SIGN and not anim.fired then
        anim.fired = true
        if anim.onSigned then anim.onSigned() end
    end
    PoseQuill(x, y, a)
end

local function PlayAnim(mode, onSigned, onDone)
    anim = { t = 0, mode = mode, onSigned = onSigned, onDone = onDone }
    quillGlow:Hide() -- the glow is only a hover cue; the quill signs without it
    animDriver:SetScript("OnUpdate", StepAnim)
end

-- ---------------------------------------------------------------- quill button
local function SignTooltip(owner)
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    GameTooltip:SetText("Sign the Bill of Sale", 1, 1, 1)
    if #Cart.items == 0 then
        GameTooltip:AddLine("Your cart is empty. Drag items from the shelves onto the counter shelves first.", 1, 0.82, 0, true)
        GameTooltip:Show()
        return
    end
    for _, e in ipairs(Cart.items) do
        local name = addon.GetVendorItemData(e.index) or "?"
        GameTooltip:AddLine(string.format("%d x %s", e.qty, name), 0.9, 0.9, 0.9)
    end
    local copper, tokens = Cart:Totals()
    GameTooltip:AddLine(" ")
    if copper > 0 then
        local short = GetMoney() < copper and 0.25 or 1 -- red when you can't afford it
        GameTooltip:AddDoubleLine("Total", addon.CoinString(copper), 1, 0.82, 0, 1, short, short)
    end
    for _, tk in ipairs(tokens) do
        local short = (tk.have and tk.have < tk.need) and 0.25 or 1
        GameTooltip:AddDoubleLine(copper > 0 and " " or "Total",
            string.format("%d |T%s:12:12:0:0|t %s", tk.need, tostring(tk.tex or ""), tk.name), 1, 0.82, 0, 1, short, short)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Click to sign and buy everything on the counter.", 0.2, 1, 0.2, true)
    GameTooltip:Show()
end

local quillButton = CreateFrame("Button", nil, counterFrame)
quillButton:SetSize(26, 50)
quillButton:SetPoint("BOTTOM", props, "BOTTOMLEFT", INK_X + 4, 2)
quillButton:SetFrameLevel(props:GetFrameLevel() + 5)
quillButton:SetScript("OnClick", function() Cart:Sign() end)
quillButton:SetScript("OnEnter", function(self)
    if not anim then quillGlow:Show() end
    SignTooltip(self)
end)
quillButton:SetScript("OnLeave", function()
    if not anim then quillGlow:Hide() end
    GameTooltip:Hide()
end)
slip:SetScript("OnClick", function() Cart:Sign() end)
slip:SetScript("OnEnter", SignTooltip)
slip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- ============================================================================
-- CART LOGIC
-- ============================================================================
local function MaxQty(index)
    local _, _, price, _, numAvailable = addon.GetVendorItemData(index)
    local max = MAX_QTY
    if numAvailable and numAvailable >= 0 then max = math.min(max, numAvailable) end
    -- Gold items: no more than you can pay for (currency costs are checked when you sign).
    if price and price > 0 and GetMoney then max = math.min(max, math.floor(GetMoney() / price)) end
    return math.max(0, max)
end

function Cart:Refresh()
    for i, b in ipairs(slots) do
        local e = self.items[i]
        local filled = e ~= nil
        for _, t in ipairs(b.outline) do t:SetShown(not filled) end
        b.back:SetShown(filled); b.icon:SetShown(filled); b.gloss:SetShown(filled); b.shadow:SetShown(filled)
        for _, t in ipairs(b.border) do t:SetShown(filled) end
        if filled then
            local _, texture, _, stack = addon.GetVendorItemData(e.index)
            b.icon:SetTexture(texture)
            local q = C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(e.link)
            local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
            for _, t in ipairs(b.border) do
                if c then t:SetColorTexture(c.r, c.g, c.b, 1) else t:SetColorTexture(0.6, 0.5, 0.3, 1) end
            end
            local total = e.qty * math.max(1, stack or 1)
            b.count:SetText(total > 1 and total or "")
        else
            b.count:SetText("")
        end
        if GameTooltip:IsOwned(b) then SlotTooltip(b) end
    end
    emptyHint:SetShown(#self.items == 0)
    slip:SetShown(#self.items > 0 or self.signing == true)
    if not self.signing then ShowSignature(-1) end
    UpdateDropGlow()
end

function Cart:TakeFromCursor()
    local index = CursorMerchantIndex()
    if not index then return false end
    ClearCursor()
    self:Add(index)
    return true
end

function Cart:Add(index)
    if self.busy then Err("Wait for the sale to finish.") return end
    local link = GetMerchantItemLink(index)
    if not link then return end
    local _, _, _, _, _, isPurchasable = addon.GetVendorItemData(index)
    if isPurchasable == false then Err("You can't buy that item.") return end
    for i, e in ipairs(self.items) do
        if e.index == index then return self:ChangeQty(i, 1) end
    end
    if #self.items >= MAX_ITEMS then
        Err("The counter shelves are full (4 items). Right-click one to take it off.")
        return
    end
    if MaxQty(index) < 1 then Err("That item is sold out.") return end
    self.items[#self.items + 1] = { index = index, link = link, qty = 1 }
    Sound("IG_ABILITY_ICON_DROP")
    self:Refresh()
end

function Cart:Remove(i)
    if self.busy or not self.items[i] then return end
    table.remove(self.items, i)
    Sound("IG_ABILITY_ICON_PICKUP")
    self:Refresh()
end

function Cart:ChangeQty(i, delta)
    local e = self.items[i]
    if self.busy or not e then return end
    local q = Clamp(e.qty + delta, 1, math.max(1, MaxQty(e.index)))
    if q == e.qty and delta > 0 then Err("You can't add more of that item.") end
    e.qty = q
    self:Refresh()
end

-- Shift-click: choose how many of the item (on the counter already, or to put there).
function Cart:PickQuantity(anchor, index)
    if self.busy then Err("Wait for the sale to finish.") return end
    local max = MaxQty(index)
    if max < 1 then Err("You can't buy any more of that item.") return end
    local current
    for _, e in ipairs(self.items) do if e.index == index then current = e.qty end end
    local name = addon.GetVendorItemData(index)
    OpenPicker(anchor, name, current or 1, max, function(q)
        for _, e in ipairs(self.items) do
            if e.index == index then e.qty = Clamp(q, 1, math.max(1, MaxQty(index))); self:Refresh(); return end
        end
        local before = #self.items
        self:Add(index)
        local e = self.items[#self.items]
        if #self.items > before and e and e.index == index then
            e.qty = Clamp(q, 1, math.max(1, MaxQty(index)))
            self:Refresh()
        end
    end)
end

-- Totals: copper, plus a list of { name, tex, need, have } for currencies / token items.
function Cart:Totals()
    local copper, tokens, byName = 0, {}, {}
    for _, e in ipairs(self.items) do
        local _, _, price, _, _, _, _, extended = addon.GetVendorItemData(e.index)
        copper = copper + (price or 0) * e.qty
        if extended and GetMerchantItemCostInfo then
            for c = 1, (GetMerchantItemCostInfo(e.index) or 0) do
                local tex, val, name, have = addon.GetExtendedCostDetails(e.index, c)
                if val then
                    local tk = byName[name]
                    if not tk then
                        tk = { name = name, tex = tex, need = 0, have = have }
                        byName[name] = tk
                        tokens[#tokens + 1] = tk
                    end
                    tk.need = tk.need + val * e.qty
                end
            end
        end
    end
    return copper, tokens
end

local function FreeBagSlots()
    if not (C_Container and C_Container.GetContainerNumFreeSlots) then return math.huge end
    local free = 0
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        local n, family = C_Container.GetContainerNumFreeSlots(bag)
        if n and (family == nil or family == 0) then free = free + n end
    end
    return free
end

-- The merchant's list can change while buying (sold-out items vanish): find an item by link.
local function FindIndex(link, hint)
    if hint and GetMerchantItemLink(hint) == link then return hint end
    for i = 1, GetMerchantNumItems() do
        if GetMerchantItemLink(i) == link then return i end
    end
end

-- Everything that must hold before signing; returns nil, reason when it doesn't.
function Cart:Check()
    for i = #self.items, 1, -1 do
        local e = self.items[i]
        local index = FindIndex(e.link, e.index)
        if not index then
            table.remove(self.items, i)
            self:Refresh()
            return nil, "An item in your cart is no longer for sale; it was taken off the counter."
        end
        e.index = index
    end
    local copper, tokens = self:Totals()
    if copper > GetMoney() then
        return nil, "You don't have enough gold for everything on the counter."
    end
    for _, tk in ipairs(tokens) do
        if tk.have and tk.have < tk.need then
            return nil, string.format("You need %d %s (you have %d).", tk.need, tk.name, tk.have)
        end
    end
    local needed = 0
    for _, e in ipairs(self.items) do
        local _, _, _, stack = addon.GetVendorItemData(e.index)
        local count = e.qty * math.max(1, stack or 1)
        local per = (C_Item and C_Item.GetItemMaxStackSizeByID and C_Item.GetItemMaxStackSizeByID(e.link))
            or select(8, (C_Item and C_Item.GetItemInfo or GetItemInfo)(e.link)) or 1
        needed = needed + math.ceil(count / math.max(1, per))
    end
    if FreeBagSlots() < needed then
        return nil, string.format("You need %d free bag slots for everything on the counter.", needed)
    end
    return true
end

-- Send the purchases, one request per batch (or per stack for items bought by the piece).
function Cart:Buy()
    local calls = {}
    for _, e in ipairs(self.items) do
        local _, _, _, stack = addon.GetVendorItemData(e.index)
        local maxStack = GetMerchantItemMaxStack and GetMerchantItemMaxStack(e.index) or 1
        if (stack or 1) <= 1 and maxStack > 1 then
            local left = e.qty
            while left > 0 do
                local n = math.min(left, maxStack)
                calls[#calls + 1] = { link = e.link, index = e.index, n = n }
                left = left - n
            end
        else
            for _ = 1, e.qty do calls[#calls + 1] = { link = e.link, index = e.index } end
        end
    end
    wipe(self.items)
    self.buying = #calls > 0
    self:Refresh()

    local token = self.token
    for k, call in ipairs(calls) do
        C_Timer.After((k - 1) * BUY_SPACING, function()
            if token ~= self.token then return end
            local index = FindIndex(call.link, call.index)
            if index then
                if call.n then BuyMerchantItem(index, call.n) else BuyMerchantItem(index) end
            end
            if k == #calls then
                self.buying = false
                self.busy = self.signing or false
            end
        end)
    end
    Sound("LOOT_WINDOW_COIN_SOUND") -- ka-ching
end

function Cart:Sign()
    if self.busy then return end
    if #self.items == 0 then
        Err("Drag items onto the counter shelves first.")
        PlayAnim("shake")
        return
    end
    local ok, why = self:Check()
    if not ok then
        Err(why)
        PlayAnim("shake")
        return
    end
    self.busy, self.signing = true, true
    GameTooltip:Hide()
    Sound("IG_QUEST_LOG_OPEN")
    local token = self.token
    PlayAnim("sign",
        function() if token == self.token then self:Buy() end end,
        function()
            if token ~= self.token then return end
            self.signing = false
            self.busy = self.buying or false
            self:Refresh()
        end)
end

function Cart:Reset()
    self.token = self.token + 1
    wipe(self.items)
    self.busy, self.signing, self.buying = false, false, false
    StopAnim()
    self:Refresh()
end

Cart.OnMerchantClosed = Cart.Reset
Cart._StepAnim = function(dt) StepAnim(nil, dt) end -- test hook

Cart:Refresh()
