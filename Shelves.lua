-- VenStore: the shelf grid, item slots / price tags and the main refresh.
local _, addon = ...
local C, Wood = addon.C, addon.Wood
local ShelfFrame = addon.ShelfFrame
local baseLevel = ShelfFrame:GetFrameLevel()

addon.filters = { currency = "ALL", type = "ALL" }
local filteredItemIndices = {}

-- ============================================================================
-- SHELVES
-- ============================================================================
ShelfFrame.shelves = {}

local SHELF_TOP_Y = 126 -- distance from the window top to the first shelf's front face

for row = 1, C.MAX_ROWS do
    local shelf = CreateFrame("Frame", nil, ShelfFrame)
    shelf:SetHeight(18)
    shelf:SetFrameLevel(baseLevel + 6)
    shelf.y = -SHELF_TOP_Y - (row - 1) * C.ROW_STRIDE

    -- Front face of the board.
    Wood.Paint(shelf, "shelf", row * 10 + 2, { streaks = 7, ends = true })
    local border = CreateFrame("Frame", nil, shelf, "BackdropTemplate")
    border:SetAllPoints(shelf)
    border:SetFrameLevel(shelf:GetFrameLevel() + 1)
    border:SetBackdrop({ edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border", edgeSize = 10 })
    border:SetBackdropBorderColor(0.55, 0.38, 0.20, 1)

    -- Top surface the items stand on: lit at the front edge, falling into shadow at the back wall.
    local deck = CreateFrame("Frame", nil, shelf)
    deck:SetPoint("BOTTOMLEFT", shelf, "TOPLEFT", 2, -2)
    deck:SetPoint("BOTTOMRIGHT", shelf, "TOPRIGHT", -2, -2)
    deck:SetHeight(15)
    deck:SetFrameLevel(baseLevel + 5)
    Wood.Paint(deck, "deck", row * 10 + 1,
        { streaks = 6, flip = true, light = 1.35, dark = 0.62, bevel = false, sheen = false })
    Wood.EdgeShade(deck, deck, "TOP", 7, 0.80, "ARTWORK", 2)

    -- Shadow the shelf casts on the wall below it.
    local underShadow = shelf:CreateTexture(nil, "BACKGROUND", nil, -8)
    underShadow:SetPoint("TOPLEFT", shelf, "BOTTOMLEFT", 2, 1)
    underShadow:SetPoint("TOPRIGHT", shelf, "BOTTOMRIGHT", -2, 1)
    underShadow:SetHeight(26)
    Wood.Gradient(underShadow, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.70)

    -- Support brackets under each end: turned posts with a round tip, or carved corbels when the
    -- theme gives brackets their own material.
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local bracket = CreateFrame("Frame", nil, shelf)
        bracket:SetSize(10, 20)
        bracket:SetPoint("TOP" .. side, shelf, "BOTTOM" .. side, side == "LEFT" and 6 or -6, 2)
        bracket:SetFrameLevel(baseLevel + 5)
        Wood.Paint(bracket, "bracket", row * 10 + (side == "LEFT" and 5 or 6),
            { tone = 1.2, grain = "V", round = true, streaks = 2 })
        local tip = Wood.Disc(bracket, "ARTWORK", 2, 1, 1, 1, 1)
        tip:SetSize(10, 6)
        tip:SetPoint("CENTER", bracket, "BOTTOM", 0, 0)
        Wood.Tint("bracket", 1.1, function(r, g, b, theme)
            tip:SetVertexColor(r, g, b, 1)
            local carved = theme and theme.materials and theme.materials.bracket
            carved = carved and Wood.CanLoad(carved.file)
            bracket:SetSize(carved and 16 or 10, carved and 26 or 20)
            tip:SetShown(not carved)
        end)
    end

    ShelfFrame.shelves[row] = shelf
end

-- ============================================================================
-- BLIND CORD
-- Hangs at the right end of the shelves only while the vendor has more items than the shelves
-- hold. Pulling it (click, or drag it down) brings up the next shelf-load, like raising a blind;
-- right-click lowers it again. A parchment tally tied to the cord shows which items are in view.
-- ============================================================================
local CORD_IN = 9        -- cord distance from the shelves' right end (clear of the price cards)
local KNOB_BELOW = 62    -- knob top below the lowest visible shelf (under its price cards)
local cord = CreateFrame("Button", nil, ShelfFrame)
cord:SetWidth(14)
cord:SetFrameLevel(baseLevel + 12) -- over the shelves, under the header beam and the wallet bar
cord:Hide()

local knob = CreateFrame("Frame", nil, cord)
knob:SetSize(10, 17)

-- Hemp rope from under the beam's moulding down to the knob: twisted strands (textures/rope.tga,
-- made by tools/RopeGen.cs) over a plain rounded cord, which shows alone if the file is missing.
local ROPE_W, ROPE_TILE = 4, 16 -- on-screen width, and the height of one twist of the texture
local rope = cord:CreateTexture(nil, "ARTWORK", nil, 0)
rope:SetWidth(ROPE_W - 1)
rope:SetPoint("TOP", cord, "TOP", 0, 0)
rope:SetPoint("BOTTOM", knob, "TOP", 0, -2)
Wood.Gradient(rope, "HORIZONTAL", 0.86, 0.74, 0.52, 1, 0.40, 0.30, 0.17, 1)
local twist = cord:CreateTexture(nil, "ARTWORK", nil, 1)
twist:SetWidth(ROPE_W)
twist:SetPoint("TOP", rope, "TOP")
twist:SetPoint("BOTTOM", rope, "BOTTOM")
twist:SetTexture("Interface\\AddOns\\VenStore\\textures\\rope", "CLAMP", "REPEAT")
local ropeShadow = cord:CreateTexture(nil, "BORDER", nil, 0)
ropeShadow:SetWidth(3)
ropeShadow:SetPoint("TOPLEFT", rope, "TOPRIGHT", 0, -3)
ropeShadow:SetPoint("BOTTOMLEFT", rope, "BOTTOMRIGHT", 0, -3)
ropeShadow:SetColorTexture(0, 0, 0, 0.35)

-- Turned wooden pull: a rounded bulb under a small collar, in the theme's bracket wood.
local knobShadow = Wood.Disc(knob, "BACKGROUND", 0, 0, 0, 0, 0.55)
knobShadow:SetPoint("TOPLEFT", 1, -3); knobShadow:SetPoint("BOTTOMRIGHT", 3, -2)
local bulb = knob:CreateTexture(nil, "ARTWORK", nil, 0)
bulb:SetPoint("TOPLEFT", 0, -3); bulb:SetPoint("BOTTOMRIGHT", 0, 0)
local collar = knob:CreateTexture(nil, "ARTWORK", nil, 1)
collar:SetSize(6, 4)
collar:SetPoint("TOP", knob, "TOP", 0, 0)
local glint = Wood.Disc(knob, "ARTWORK", 2, 1, 0.92, 0.75, 0.30)
glint:SetSize(3, 6)
glint:SetPoint("CENTER", knob, "CENTER", -2, 1)
glint:SetBlendMode("ADD")
local knobHover = Wood.Disc(knob, "OVERLAY", 0, 1, 0.85, 0.45, 0.45)
knobHover:SetPoint("TOPLEFT", -4, 2); knobHover:SetPoint("BOTTOMRIGHT", 4, -4)
knobHover:SetBlendMode("ADD")
knobHover:Hide()
Wood.Tint("bracket", 1.2, function(r, g, b)
    Wood.GradientFile(bulb, Wood.DISC, "VERTICAL", r * 0.45, g * 0.45, b * 0.45, 1,
        math.min(1, r * 1.25), math.min(1, g * 1.25), math.min(1, b * 1.25), 1)
    collar:SetColorTexture(r * 0.6, g * 0.6, b * 0.6, 1)
end)

-- Tally card tied on beside the knob ("4-6 of 34").
local tally = CreateFrame("Frame", nil, knob)
tally:SetHeight(15)
tally:SetPoint("RIGHT", knob, "LEFT", -4, -1)
local tallyShadow = tally:CreateTexture(nil, "BACKGROUND", nil, 0)
tallyShadow:SetPoint("TOPLEFT", 2, -2); tallyShadow:SetPoint("BOTTOMRIGHT", 3, -3)
tallyShadow:SetColorTexture(0, 0, 0, 0.5)
local tallyEdge = tally:CreateTexture(nil, "BORDER", nil, 0)
tallyEdge:SetAllPoints()
tallyEdge:SetColorTexture(0.45, 0.32, 0.18, 1)
local tallyPaper = tally:CreateTexture(nil, "BORDER", nil, 1)
tallyPaper:SetPoint("TOPLEFT", 1, -1); tallyPaper:SetPoint("BOTTOMRIGHT", -1, 1)
Wood.Gradient(tallyPaper, "VERTICAL", 0.86, 0.80, 0.66, 1, 0.98, 0.95, 0.86, 1)
local tallyString = tally:CreateTexture(nil, "BACKGROUND", nil, 1)
tallyString:SetSize(6, 1)
tallyString:SetPoint("LEFT", tally, "RIGHT", -1, 2)
tallyString:SetColorTexture(0.62, 0.50, 0.32, 1)
local tallyText = tally:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
local tallyFont, _, tallyFlags = tallyText:GetFont()
if tallyFont then tallyText:SetFont(tallyFont, 9, tallyFlags) end
tallyText:SetPoint("CENTER", 0, 0)
tallyText:SetTextColor(0.10, 0.05, 0.02, 1)
tallyText:SetShadowColor(1, 0.98, 0.92, 1)
tallyText:SetShadowOffset(1, -1)

-- `pull` is how far the cord has been drawn down (px). The whole rope slides with the knob: the
-- twist pattern is fixed to the knob end, so it runs down out from under the beam as it's pulled.
local pull, held, holdY, tug = 0, false, 0, nil
local MAX_PULL = 16
local TUG_DOWN, TUG_HOLD, TUG_UP = 0.09, 0.06, 0.32 -- seconds: draw down, pause, let back up
local function PlaceKnob()
    knob:SetPoint("TOP", cord, "BOTTOM", 0, 17 - pull)
    local len = math.max(1, (cord:GetHeight() or 0) - 15 + pull)
    twist:SetTexCoord(0, 1, -len / ROPE_TILE, 0)
end
cord:SetScript("OnSizeChanged", PlaceKnob)
local function CursorY()
    local _, y = GetCursorPosition()
    return y / (cord:GetEffectiveScale() or 1)
end
-- A hand's pull: draw the cord down to `depth` quickly, pause, then let it run smoothly back up
-- (no bounce: a weighted cord settles, it doesn't spring).
local function Tug(depth)
    tug = { t = 0, from = pull, depth = math.max(pull, depth) }
end
cord:SetScript("OnUpdate", function(self, elapsed)
    if held then
        pull = math.max(2, math.min(MAX_PULL, holdY - CursorY()))
    elseif tug then
        tug.t = tug.t + math.min(elapsed, 0.05)
        local t = tug.t
        if t < TUG_DOWN then
            pull = tug.from + (tug.depth - tug.from) * math.sin(t / TUG_DOWN * math.pi / 2)
        elseif t < TUG_DOWN + TUG_HOLD then
            pull = tug.depth
        elseif t < TUG_DOWN + TUG_HOLD + TUG_UP then
            local k = (t - TUG_DOWN - TUG_HOLD) / TUG_UP
            pull = tug.depth * (1 - k * k * (3 - 2 * k))
        else
            pull, tug = 0, nil
        end
    else
        return -- at rest
    end
    PlaceKnob()
end)

-- A tug when the page changes (from the cord, the mouse wheel or the pager): a full pull for the
-- next shelf-load, a shorter one for the previous.
function addon.TugCord(delta)
    if cord:IsShown() and not held then
        Tug((delta or 1) > 0 and 12 or 6)
    end
end

local function TurnPage(delta)
    local total = ShelfFrame.totalPages or 1
    if total <= 1 then return end
    ShelfFrame.page = ((ShelfFrame.page or 1) - 1 + delta) % total + 1 -- wraps round at either end
    addon.Update()
end

local function OnPress(_, button)
    if button ~= "LeftButton" then return end
    held, holdY = true, CursorY()
end
local function OnRelease(_, button)
    if button ~= "LeftButton" and button ~= "RightButton" then return end
    held = false
    Tug(button == "LeftButton" and 12 or 6) -- after a drag, lets the cord back up from where it is
    TurnPage(button == "RightButton" and -1 or 1)
end
local function OnHover()
    knobHover:Show()
    local first, last, total = cord.first or 0, cord.last or 0, cord.total or 0
    GameTooltip:SetOwner(cord, "ANCHOR_RIGHT")
    GameTooltip:SetText(string.format("Items %d-%d of %d", first, last, total), 1, 1, 1)
    GameTooltip:AddLine(last < total and "Pull the cord for the next shelf-load." or "Pull the cord to start again from the first item.", 1, 0.82, 0, true)
    GameTooltip:AddLine("Right-click: previous shelf-load. The mouse wheel over the shop works too.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end
local function OnUnhover()
    knobHover:Hide()
    GameTooltip:Hide()
end
-- The rope strip and the tally card both work the cord.
tally:EnableMouse(true)
for _, f in ipairs({ cord, tally }) do
    f:SetScript("OnMouseDown", OnPress)
    f:SetScript("OnMouseUp", OnRelease)
    f:SetScript("OnEnter", OnHover)
    f:SetScript("OnLeave", OnUnhover)
end

-- When the shop opens with a cord, give it a small bob so it's noticed.
local bobPending = false
ShelfFrame:HookScript("OnShow", function() bobPending = true end)

-- first/last/total: the items in view and how many the (filtered) vendor list holds.
function addon.UpdateCord(rows, first, last, total)
    local more = total > (last - first + 1)
    cord:SetShown(more)
    if not more then return end
    cord.first, cord.last, cord.total = first, last, total
    cord:ClearAllPoints()
    cord:SetPoint("TOP", ShelfFrame, "TOPRIGHT", -(addon.GetWingWidth() + 20 + CORD_IN), -(C.HEADER_H - 2))
    cord:SetPoint("BOTTOM", ShelfFrame.shelves[rows], "BOTTOMRIGHT", -CORD_IN, -(KNOB_BELOW + 17))
    PlaceKnob()
    tallyText:SetText(first == last and string.format("%d of %d", first, total)
        or string.format("%d-%d of %d", first, last, total))
    tally:SetWidth(math.ceil(tallyText:GetStringWidth()) + 10)
    if bobPending then
        bobPending = false
        Tug(5)
    end
end

-- Re-anchor shelves to the current wing width (the right edge moves when the mirror toggles).
function addon.LayoutShelves()
    local rightInset = addon.GetWingWidth() + 20
    local drop = addon.shelfDrop or 0 -- lowered under the outdoor stall's awning (Ambience.lua)
    for _, shelf in ipairs(ShelfFrame.shelves) do
        shelf:ClearAllPoints()
        shelf:SetPoint("TOPLEFT", ShelfFrame, "TOPLEFT", 24, shelf.y - drop)
        shelf:SetPoint("TOPRIGHT", ShelfFrame, "TOPRIGHT", -rightInset, shelf.y - drop)
    end
    cord:SetPoint("TOP", ShelfFrame, "TOPRIGHT", -(rightInset + CORD_IN), -(C.HEADER_H - 2))
end
addon.LayoutShelves()

-- ============================================================================
-- ITEM SLOTS
-- ============================================================================
ShelfFrame.itemButtons = {}

-- Selling: an item from the bags dropped on a slot or the shop sells it, as in the default UI.
function addon.SellCursorItem()
    if GetCursorInfo() ~= "item" then return false end
    PickupMerchantItem(1) -- with an item on the cursor this sells it (whatever the index)
    return true
end

local function OnSlotEnter(self)
    if not (self.merchantIndex or self.buybackIndex) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if self.buybackIndex then
        GameTooltip:SetBuybackItem(self.buybackIndex)
    else
        GameTooltip:SetMerchantItem(self.merchantIndex)
    end
    GameTooltip:Show()
    CursorUpdate(self)
end

local function OnSlotLeave()
    GameTooltip:Hide()
    ResetCursor()
end

local function OnSlotClick(self, button)
    if addon.SellCursorItem() then return end
    if self.buybackIndex then
        if IsModifiedClick() then
            HandleModifiedItemClick(GetBuybackItemLink(self.buybackIndex))
        else
            BuybackItem(self.buybackIndex)
        end
        return
    end
    local index = self.merchantIndex
    if not index then return end
    if IsControlKeyDown() then
        addon.Showroom:Preview(index)
    elseif IsAltKeyDown() then
        addon.Cart:Add(index)
    elseif IsShiftKeyDown() and not (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow()) then
        addon.Cart:PickQuantity(self, index) -- choose how many to put on the counter
    elseif IsModifiedClick() then
        HandleModifiedItemClick(GetMerchantItemLink(index))
    elseif button == "RightButton" then
        BuyMerchantItem(index, 1)
    else
        PickupMerchantItem(index)
    end
end

local function CreateSlot(i)
    local S = C.SLOT_SIZE
    local btn = CreateFrame("Button", "VenStoreSlot" .. i, ShelfFrame, "BackdropTemplate")
    btn:SetSize(S, S)

    -- Soft contact shadow + quality-coloured glow reflected on the varnished shelf.
    btn.contactShadow = Wood.Disc(btn, "BACKGROUND", -3, 0, 0, 0, 0.65)
    btn.contactShadow:SetSize(S + 16, 10)
    btn.contactShadow:SetPoint("CENTER", btn, "BOTTOM", 2, 1)
    btn.reflection = Wood.Disc(btn, "BACKGROUND", -2, 1, 0.85, 0.6, 0.15)
    btn.reflection:SetSize(S + 4, 7)
    btn.reflection:SetPoint("TOP", btn, "BOTTOM", 0, 1)
    btn.reflection:SetBlendMode("ADD")

    btn.backPlate = btn:CreateTexture(nil, "BACKGROUND", nil, 0)
    btn.backPlate:SetPoint("TOPLEFT", 2, -2)
    btn.backPlate:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.backPlate:SetColorTexture(0.04, 0.03, 0.02, 1)

    btn.icon = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    btn.icon:SetPoint("TOPLEFT", 2, -2)
    btn.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Glassy gloss so icons read as physical display tiles.
    local gloss = btn:CreateTexture(nil, "ARTWORK", nil, 2)
    gloss:SetPoint("TOPLEFT", 3, -3)
    gloss:SetPoint("TOPRIGHT", -3, -3)
    gloss:SetHeight(S * 0.45)
    Wood.Gradient(gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.16)

    btn:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    btn.count:SetPoint("BOTTOMRIGHT", -3, 3)

    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    -- Parchment price card hanging from the shelf edge by a brass tack.
    local tag = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    tag:SetSize(116, 58)
    tag:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    tag:SetBackdropColor(1, 1, 1, 1)
    tag:SetBackdropBorderColor(0.52, 0.39, 0.24, 1)

    local tagShadow = tag:CreateTexture(nil, "BACKGROUND", nil, -1)
    tagShadow:SetPoint("TOPLEFT", 3, -3)
    tagShadow:SetPoint("BOTTOMRIGHT", 5, -5)
    tagShadow:SetColorTexture(0, 0, 0, 0.55)

    local paper = tag:CreateTexture(nil, "BORDER", nil, 0)
    paper:SetPoint("TOPLEFT", 2, -2)
    paper:SetPoint("BOTTOMRIGHT", -2, 2)
    Wood.Gradient(paper, "VERTICAL", 0.86, 0.80, 0.66, 1, 0.98, 0.95, 0.86, 1)

    local tuck = tag:CreateTexture(nil, "ARTWORK", nil, 2)
    tuck:SetPoint("TOPLEFT", 2, -2)
    tuck:SetPoint("TOPRIGHT", -2, -2)
    tuck:SetHeight(7)
    Wood.Gradient(tuck, "VERTICAL", 0.15, 0.08, 0.02, 0, 0.15, 0.08, 0.02, 0.40)

    local tack = Wood.Disc(tag, "OVERLAY", 3, 0, 0, 0, 1)
    tack:SetSize(6, 6)
    tack:SetPoint("CENTER", tag, "TOP", 0, -3)
    Wood.Brass(tack, 1, Wood.DISC)

    btn.nameText = tag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.nameText:SetPoint("TOP", tag, "TOP", 0, -8)
    btn.nameText:SetWidth(104)
    btn.nameText:SetWordWrap(false)
    btn.nameText:SetJustifyH("CENTER")
    btn.nameText:SetTextColor(0.10, 0.05, 0.02, 1)
    btn.nameText:SetShadowColor(1, 0.98, 0.92, 1)
    btn.nameText:SetShadowOffset(1, -1)

    local divider = tag:CreateTexture(nil, "OVERLAY", nil, 2)
    divider:SetSize(96, 1)
    divider:SetPoint("TOP", btn.nameText, "BOTTOM", 0, -3)
    divider:SetColorTexture(0.42, 0.28, 0.15, 0.65)

    btn.priceText = tag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.priceText:SetPoint("TOP", divider, "BOTTOM", 0, -3)
    btn.priceText:SetWidth(104)
    btn.priceText:SetWordWrap(false)
    btn.priceText:SetJustifyH("CENTER")
    btn.priceText:SetTextColor(0.06, 0.03, 0.01, 1)
    btn.priceText:SetShadowColor(1, 0.98, 0.92, 1)
    btn.priceText:SetShadowOffset(1, -1)

    btn.currencyNameText = tag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    local fontPath, _, fontFlags = btn.currencyNameText:GetFont()
    if fontPath then btn.currencyNameText:SetFont(fontPath, 9, fontFlags) end
    btn.currencyNameText:SetPoint("TOP", btn.priceText, "BOTTOM", 0, -2)
    btn.currencyNameText:SetWidth(104)
    btn.currencyNameText:SetWordWrap(false)
    btn.currencyNameText:SetJustifyH("CENTER")
    btn.currencyNameText:SetTextColor(0.28, 0.16, 0.06, 1)
    btn.currencyNameText:SetShadowColor(1, 0.98, 0.92, 0.9)
    btn.currencyNameText:SetShadowOffset(1, -1)

    btn.priceTag = tag

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnEnter", OnSlotEnter)
    btn:SetScript("OnLeave", OnSlotLeave)
    btn:SetScript("OnClick", OnSlotClick)
    -- Drag an item off the shelf: onto your bags to buy it now, or onto the counter shelves (cart).
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        if self.merchantIndex then PickupMerchantItem(self.merchantIndex) end
    end)
    btn:SetScript("OnReceiveDrag", function() addon.SellCursorItem() end)
    return btn
end

for i = 1, C.MAX_SLOTS do
    ShelfFrame.itemButtons[i] = CreateSlot(i)
end

local function HideSlot(btn)
    btn.merchantIndex, btn.buybackIndex = nil, nil
    btn:Hide()
    btn.priceTag:Hide()
end

local function PaintSlot(btn, name, texture, quantity, isUsable, link, priceStr, currencyStr)
    btn.icon:SetTexture(texture)
    btn.count:SetText((quantity and quantity > 1) and quantity or "")
    if isUsable == false then
        btn.icon:SetVertexColor(0.9, 0.25, 0.25)
    else
        btn.icon:SetVertexColor(1, 1, 1)
    end
    btn.nameText:SetText(name or "Unknown")

    local quality = link and C_Item and C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(link)
    local color = quality and ITEM_QUALITY_COLORS[quality]
    if color then
        btn:SetBackdropBorderColor(color.r, color.g, color.b, 1)
        btn.reflection:SetVertexColor(color.r, color.g, color.b, 0.35)
    else
        btn:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        btn.reflection:SetVertexColor(1, 0.85, 0.6, 0.15)
    end

    btn.priceText:SetText(priceStr)
    btn.currencyNameText:SetText(currencyStr)

    btn:Show()
    btn.priceTag:Show()
end

local function FillSlot(btn, merchantIndex)
    local name, texture, price, quantity, _, _, isUsable, extendedCost = addon.GetVendorItemData(merchantIndex)
    btn.merchantIndex, btn.buybackIndex = merchantIndex, nil
    local priceStr, currencyStr = addon.FormatVendorPrice(merchantIndex, price, extendedCost)
    PaintSlot(btn, name, texture, quantity, isUsable, GetMerchantItemLink(merchantIndex), priceStr, currencyStr)
end

-- Buyback view: the items sold to merchants this session.
local function FillBuybackSlot(btn, buybackIndex)
    local name, texture, price, quantity, _, isUsable = GetBuybackItemInfo(buybackIndex)
    btn.merchantIndex, btn.buybackIndex = nil, buybackIndex
    local priceStr = addon.CoinString(price, 10)
    PaintSlot(btn, name, texture, quantity, isUsable, GetBuybackItemLink(buybackIndex), priceStr, "Buy back")
end

-- ============================================================================
-- FILTERING + REFRESH
-- ============================================================================
local function RebuildFilteredItemsList()
    wipe(filteredItemIndices)
    local currencyFilter, typeFilter = addon.filters.currency, addon.filters.type
    for idx = 1, GetMerchantNumItems() do
        local matches = true
        if currencyFilter ~= "ALL" then
            local _, _, price, _, _, _, _, extendedCost = addon.GetVendorItemData(idx)
            matches = false
            for _, cName in ipairs(addon.GetSlotCurrencyNames(idx, price, extendedCost)) do
                if cName == currencyFilter then matches = true; break end
            end
        end
        if matches and typeFilter ~= "ALL" then
            matches = addon.GetVendorItemCategory(idx) == typeFilter
        end
        if matches then filteredItemIndices[#filteredItemIndices + 1] = idx end
    end
end

function addon.Update()
    local rawName = addon.GetNPCName() or "Merchant"
    local shopName = (rawName:match("^([^%s,]+)") or rawName) .. "'s Shop"
    addon.titleText:SetText(ShelfFrame.buyback and (shopName .. " - " .. (BUYBACK or "Buyback")) or shopName)

    if addon.UpdateSpecDropdownLabel then addon.UpdateSpecDropdownLabel() end
    if ShelfFrame.buyback then
        wipe(filteredItemIndices)
        for i = 1, GetNumBuybackItems() do filteredItemIndices[i] = i end
    else
        RebuildFilteredItemsList()
    end

    local cols, rows = addon.GetGridDims()
    local perPage = cols * rows
    local totalPages = math.max(1, math.ceil(#filteredItemIndices / perPage))
    ShelfFrame.page = math.max(1, math.min(ShelfFrame.page or 1, totalPages))
    ShelfFrame.totalPages = totalPages
    addon.UpdatePager(ShelfFrame.page, totalPages)

    for r = 1, C.MAX_ROWS do
        ShelfFrame.shelves[r]:SetShown(r <= rows)
    end

    local level = ShelfFrame:GetFrameLevel()
    local firstIndex = (ShelfFrame.page - 1) * perPage
    local startX = -((cols - 1) * C.COL_STRIDE) / 2

    local total = #filteredItemIndices
    addon.UpdateCord(rows, math.min(firstIndex + 1, total), math.min(firstIndex + perPage, total), total)
    -- A new shelf-load comes into view from the bottom shelf up, like a blind being raised.
    local key = (ShelfFrame.buyback and "b" or "m") .. ShelfFrame.page
    if ShelfFrame.shownKey and ShelfFrame.shownKey ~= key and ShelfFrame:IsVisible() then
        addon.RevealRows(cols, rows)
    end
    ShelfFrame.shownKey = key

    for i = 1, C.MAX_SLOTS do
        local btn = ShelfFrame.itemButtons[i]
        local merchantIndex = i <= perPage and filteredItemIndices[firstIndex + i]
        if merchantIndex then
            local shelf = ShelfFrame.shelves[math.ceil(i / cols)]
            local xOffset = startX + ((i - 1) % cols) * C.COL_STRIDE

            btn:SetFrameLevel(level + 15)
            btn:ClearAllPoints()
            btn:SetPoint("BOTTOM", shelf, "TOP", xOffset, 3)
            btn.priceTag:SetFrameLevel(level + 16)
            btn.priceTag:ClearAllPoints()
            btn.priceTag:SetPoint("TOP", shelf, "BOTTOM", xOffset, 1)
            if ShelfFrame.buyback then FillBuybackSlot(btn, merchantIndex) else FillSlot(btn, merchantIndex) end
        else
            HideSlot(btn)
        end
    end

    addon.UpdateWallet()
    if addon.Services then addon.Services:Update() end
end

function addon.ChangePage(delta)
    local target = (ShelfFrame.page or 1) + delta
    if target >= 1 and target <= (ShelfFrame.totalPages or 1) then
        ShelfFrame.page = target
        addon.Update()
        addon.TugCord(delta)
    end
end

-- Fade the slots in row by row, lowest shelf first.
local REVEAL_STAGGER, REVEAL_TIME = 0.05, 0.16
local reveal = CreateFrame("Frame", nil, ShelfFrame)
reveal.t, reveal.cols, reveal.rows = 0, 1, 1
reveal:Hide()
reveal:SetScript("OnUpdate", function(self, elapsed)
    self.t = self.t + elapsed
    local done = true
    for i = 1, C.MAX_SLOTS do
        local btn = ShelfFrame.itemButtons[i]
        local fromBottom = self.rows - math.ceil(i / self.cols)
        local a = (self.t - fromBottom * REVEAL_STAGGER) / REVEAL_TIME
        if a < 1 then done = false end
        btn:SetAlpha(math.max(0, math.min(1, a)))
    end
    if done then self:Hide() end
end)
function addon.RevealRows(cols, rows)
    reveal.t, reveal.cols, reveal.rows = 0, cols, rows
    for i = 1, C.MAX_SLOTS do ShelfFrame.itemButtons[i]:SetAlpha(0) end
    reveal:Show()
end
-- Never leave slots faded if the shop closes mid-reveal.
reveal:SetScript("OnHide", function()
    for i = 1, C.MAX_SLOTS do ShelfFrame.itemButtons[i]:SetAlpha(1) end
end)

ShelfFrame:SetScript("OnReceiveDrag", function() addon.SellCursorItem() end)
ShelfFrame:HookScript("OnMouseUp", function() addon.SellCursorItem() end)

ShelfFrame:EnableMouseWheel(true)
ShelfFrame:SetScript("OnMouseWheel", function(_, delta) addon.ChangePage(-delta) end)
