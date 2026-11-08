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
    Wood.Paint(shelf, Wood.HONEY[1], Wood.HONEY[2], Wood.HONEY[3], row * 10 + 2, { streaks = 7, ends = true })
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
    Wood.Paint(deck, Wood.OAK[1], Wood.OAK[2], Wood.OAK[3], row * 10 + 1,
        { streaks = 6, flip = true, light = 1.35, dark = 0.62, bevel = false, sheen = false })
    Wood.EdgeShade(deck, deck, "TOP", 7, 0.80, "ARTWORK", 2)

    -- Shadow the shelf casts on the wall below it.
    local underShadow = shelf:CreateTexture(nil, "BACKGROUND", nil, -8)
    underShadow:SetPoint("TOPLEFT", shelf, "BOTTOMLEFT", 2, 1)
    underShadow:SetPoint("TOPRIGHT", shelf, "BOTTOMRIGHT", -2, 1)
    underShadow:SetHeight(26)
    Wood.Gradient(underShadow, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.70)

    -- Carved support brackets under each end.
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local bracket = CreateFrame("Frame", nil, shelf)
        bracket:SetSize(10, 20)
        bracket:SetPoint("TOP" .. side, shelf, "BOTTOM" .. side, side == "LEFT" and 6 or -6, 2)
        bracket:SetFrameLevel(baseLevel + 5)
        Wood.Paint(bracket, Wood.WALNUT[1] * 1.2, Wood.WALNUT[2] * 1.2, Wood.WALNUT[3] * 1.2, row * 10 + (side == "LEFT" and 5 or 6),
            { grain = "V", round = true, streaks = 2 })
        local tip = Wood.Disc(bracket, "ARTWORK", 2, Wood.Shade(Wood.WALNUT[1], Wood.WALNUT[2], Wood.WALNUT[3], 1.1))
        tip:SetSize(10, 6)
        tip:SetPoint("CENTER", bracket, "BOTTOM", 0, 0)
    end

    ShelfFrame.shelves[row] = shelf
end

-- Re-anchor shelves to the current wing width (the right edge moves when the mirror toggles).
function addon.LayoutShelves()
    local rightInset = addon.GetWingWidth() + 20
    for _, shelf in ipairs(ShelfFrame.shelves) do
        shelf:ClearAllPoints()
        shelf:SetPoint("TOPLEFT", ShelfFrame, "TOPLEFT", 24, shelf.y)
        shelf:SetPoint("TOPRIGHT", ShelfFrame, "TOPRIGHT", -rightInset, shelf.y)
    end
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
    local priceStr = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString and price)
        and C_CurrencyInfo.GetCoinTextureString(price, 10) or tostring(price or "")
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
    end
end

ShelfFrame:SetScript("OnReceiveDrag", function() addon.SellCursorItem() end)
ShelfFrame:HookScript("OnMouseUp", function() addon.SellCursorItem() end)

ShelfFrame:EnableMouseWheel(true)
ShelfFrame:SetScript("OnMouseWheel", function(_, delta) addon.ChangePage(-delta) end)
