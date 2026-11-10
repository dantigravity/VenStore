-- VenStore: main cabinet window, backboard, header beam, wallet bar, pager and grid sizing.
local _, addon = ...
local C, Wood = addon.C, addon.Wood

local ShelfFrame = CreateFrame("Frame", "VenStoreShelfFrame", UIParent, "BackdropTemplate")
addon.ShelfFrame = ShelfFrame

ShelfFrame.page = 1
ShelfFrame.showMirror = true
ShelfFrame.showDisplay = true
ShelfFrame.cols, ShelfFrame.rows = 4, 2

-- ============================================================================
-- GRID SIZING (width depends on which right-hand bays are visible)
-- ============================================================================
-- Width of the vendor stage frame: vendor + counter, plus the display plinth when it is used.
function addon.GetStageWidth()
    if not ShelfFrame.showDisplay then return C.VENDOR_W end
    local extra = addon.Showroom and addon.Showroom.displayExtra or 0
    return C.VENDOR_W + C.DISPLAY_W + extra
end

function addon.GetWingWidth()
    return (ShelfFrame.showMirror and C.MIRROR_BAY_W or 0) + addon.GetStageWidth() + C.STAGE_GAP
end

function addon.SizeForGrid(cols, rows)
    return cols * C.COL_STRIDE + C.SHELF_PAD_X + addon.GetWingWidth(), rows * C.ROW_STRIDE + C.PAD_Y
end

local function ClampGrid(cols, rows)
    return math.max(C.MIN_COLS, math.min(C.MAX_COLS, cols)), math.max(C.MIN_ROWS, math.min(C.MAX_ROWS, rows))
end

-- Columns/rows that currently fit (used live while dragging the resize grip).
function addon.GetGridDims()
    local w, h = ShelfFrame:GetSize()
    local padX = C.SHELF_PAD_X + addon.GetWingWidth()
    return ClampGrid(math.floor((w - padX + 20) / C.COL_STRIDE), math.floor((h - C.PAD_Y + 25) / C.ROW_STRIDE))
end

-- Snap the window to an exact grid and refresh resize bounds for the current wing width.
function addon.ApplyGrid(cols, rows)
    cols, rows = ClampGrid(cols or ShelfFrame.cols, rows or ShelfFrame.rows)
    ShelfFrame.cols, ShelfFrame.rows = cols, rows
    if ShelfFrame.SetResizeBounds then
        local minW, minH = addon.SizeForGrid(C.MIN_COLS, C.MIN_ROWS)
        local maxW, maxH = addon.SizeForGrid(C.MAX_COLS, C.MAX_ROWS)
        ShelfFrame:SetResizeBounds(minW, minH, maxW, maxH)
    end
    ShelfFrame:SetSize(addon.SizeForGrid(cols, rows))
    if addon.LayoutShelves then addon.LayoutShelves() end
    addon.FitToScreen()
end

-- Shrink the whole window (never enlarge it) when it would run off the screen.
local SCREEN_MARGIN_X, SCREEN_MARGIN_Y = 40, 60
function addon.FitToScreen()
    local w, h = ShelfFrame:GetSize()
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    if not w or w <= 0 or not sw or sw <= 0 then return end
    local scale = math.min(1, (sw - SCREEN_MARGIN_X) / w, (sh - SCREEN_MARGIN_Y) / h)
    if math.abs((ShelfFrame:GetScale() or 1) - scale) > 0.001 then
        ShelfFrame:SetScale(scale)
    end
end

-- ============================================================================
-- CABINET WINDOW
-- ============================================================================
ShelfFrame:SetSize(addon.SizeForGrid(ShelfFrame.cols, ShelfFrame.rows))
ShelfFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
ShelfFrame:SetFrameStrata("HIGH")
ShelfFrame:SetFrameLevel(10)
ShelfFrame:SetMovable(true)
ShelfFrame:SetResizable(true)
ShelfFrame:SetClampedToScreen(true)
ShelfFrame:EnableMouse(true)
ShelfFrame:RegisterForDrag("LeftButton")
ShelfFrame:SetScript("OnDragStart", ShelfFrame.StartMoving)
ShelfFrame:SetScript("OnDragStop", ShelfFrame.StopMovingOrSizing)
ShelfFrame:Hide()
tinsert(UISpecialFrames, "VenStoreShelfFrame") -- Escape closes the shop

ShelfFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
ShelfFrame:SetBackdropColor(0.10, 0.06, 0.03, 1)
ShelfFrame:SetBackdropBorderColor(0.80, 0.66, 0.48, 1)

local baseLevel = ShelfFrame:GetFrameLevel()

-- Backboard: one continuous wall of fixed-height planks behind every bay so nothing scales unevenly.
local backboard = CreateFrame("Frame", nil, ShelfFrame)
backboard:SetPoint("TOPLEFT", ShelfFrame, "TOPLEFT", 16, -C.HEADER_H)
backboard:SetPoint("BOTTOMRIGHT", ShelfFrame, "BOTTOMRIGHT", -16, C.FOOTER_H)
backboard:SetFrameLevel(baseLevel + 1)
Wood.PlankWall(backboard, 24, "wall", 10)
addon.backboard = backboard

-- Ambient occlusion and lantern light over the whole back wall.
local backboardLight = CreateFrame("Frame", nil, backboard)
backboardLight:SetAllPoints()
backboardLight:SetFrameLevel(backboard:GetFrameLevel() + 2) -- above the planks, below shelves/bays
Wood.EdgeShade(backboardLight, backboardLight, "TOP", 46, 0.70, "ARTWORK", 1)
Wood.EdgeShade(backboardLight, backboardLight, "BOTTOM", 30, 0.55, "ARTWORK", 1)
Wood.EdgeShade(backboardLight, backboardLight, "LEFT", 34, 0.60, "ARTWORK", 1)
Wood.EdgeShade(backboardLight, backboardLight, "RIGHT", 34, 0.60, "ARTWORK", 1)
local lanternGlow = backboardLight:CreateTexture(nil, "ARTWORK", nil, 2)
lanternGlow:SetPoint("TOPLEFT", 0, -10)
lanternGlow:SetPoint("TOPRIGHT", 0, -10)
lanternGlow:SetHeight(220)
lanternGlow:SetBlendMode("ADD")
Wood.Gradient(lanternGlow, "VERTICAL", 1, 0.62, 0.25, 0, 1, 0.62, 0.25, 0.07)

-- Heavy side posts.
local function MakePost(point, x, seed)
    local post = CreateFrame("Frame", nil, ShelfFrame)
    post:SetPoint("TOP" .. point, ShelfFrame, "TOP" .. point, x, -8)
    post:SetPoint("BOTTOM" .. point, ShelfFrame, "BOTTOM" .. point, x, 8)
    post:SetWidth(16)
    post:SetFrameLevel(baseLevel + 8)
    Wood.Paint(post, "post", seed, { grain = "V", round = true })
    return post
end
MakePost("LEFT", 8, 11)
MakePost("RIGHT", -8, 12)

-- ============================================================================
-- HEADER BEAM, TITLE, CLOSE
-- ============================================================================
local topBeam = CreateFrame("Frame", nil, ShelfFrame, "BackdropTemplate")
topBeam:SetPoint("TOPLEFT", ShelfFrame, "TOPLEFT", 10, -8)
topBeam:SetPoint("TOPRIGHT", ShelfFrame, "TOPRIGHT", -10, -8)
topBeam:SetHeight(48)
topBeam:SetFrameLevel(baseLevel + 14)
Wood.Paint(topBeam, "beam", 99, { tone = 0.85, streaks = 14, knots = true, ends = true })
addon.topBeam = topBeam

-- Carved moulding along the bottom of the beam + its shadow on the backboard.
local moulding = CreateFrame("Frame", nil, topBeam)
moulding:SetPoint("TOPLEFT", topBeam, "BOTTOMLEFT", 6, 6)
moulding:SetPoint("TOPRIGHT", topBeam, "BOTTOMRIGHT", -6, 6)
moulding:SetHeight(8)
moulding:SetFrameLevel(topBeam:GetFrameLevel() + 1)
Wood.Paint(moulding, "trim", 98, { streaks = 3, round = true, sheen = false })
local beamShadow = ShelfFrame:CreateTexture(nil, "ARTWORK")
beamShadow:SetPoint("TOPLEFT", moulding, "BOTTOMLEFT")
beamShadow:SetPoint("TOPRIGHT", moulding, "BOTTOMRIGHT")
beamShadow:SetHeight(18)
Wood.Gradient(beamShadow, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0.65)

local topBeamBorder = CreateFrame("Frame", nil, topBeam, "BackdropTemplate")
topBeamBorder:SetAllPoints()
topBeamBorder:SetBackdrop({ edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border", edgeSize = 10 })
topBeamBorder:SetBackdropBorderColor(0.55, 0.38, 0.20, 1)

local titleBg = topBeamBorder:CreateTexture(nil, "OVERLAY")
titleBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
titleBg:SetSize(340, 64)
titleBg:SetPoint("TOP", ShelfFrame, "TOP", 0, 14)

local titleText = topBeamBorder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOP", titleBg, "TOP", 0, -14)
titleText:SetText("Merchant's Shop")
addon.titleText = titleText

local closeBtn = CreateFrame("Button", nil, topBeamBorder, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", ShelfFrame, "TOPRIGHT", -4, -4)
closeBtn:SetScript("OnClick", function() CloseMerchant() end)

-- ============================================================================
-- WALLET BAR + PAGER
-- ============================================================================
local walletBar = CreateFrame("Frame", nil, ShelfFrame, "BackdropTemplate")
walletBar:SetHeight(30)
walletBar:SetPoint("BOTTOMLEFT", ShelfFrame, "BOTTOMLEFT", 18, 12)
walletBar:SetPoint("BOTTOMRIGHT", ShelfFrame, "BOTTOMRIGHT", -32, 12)
walletBar:SetFrameLevel(baseLevel + 14)
Wood.Paint(walletBar, "trim", 88, { streaks = 8, ends = true })
addon.walletBar = walletBar

local walletTopShadow = ShelfFrame:CreateTexture(nil, "ARTWORK")
walletTopShadow:SetPoint("BOTTOMLEFT", walletBar, "TOPLEFT")
walletTopShadow:SetPoint("BOTTOMRIGHT", walletBar, "TOPRIGHT")
walletTopShadow:SetHeight(10)
Wood.Gradient(walletTopShadow, "VERTICAL", 0, 0, 0, 0.55, 0, 0, 0, 0)

local walletBorder = CreateFrame("Frame", nil, walletBar, "BackdropTemplate")
walletBorder:SetAllPoints()
walletBorder:SetBackdrop({ edgeFile = "Interface\\FriendsFrame\\UI-Toast-Border", edgeSize = 10 })
walletBorder:SetBackdropBorderColor(0.55, 0.38, 0.20, 1)

local walletText = walletBorder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
walletText:SetPoint("LEFT", walletBar, "LEFT", 10, 0)
walletText:SetJustifyH("LEFT")

local nextBtn = CreateFrame("Button", nil, walletBorder, "UIPanelButtonTemplate")
nextBtn:SetSize(58, 20)
nextBtn:SetPoint("RIGHT", walletBar, "RIGHT", -6, 0)
nextBtn:SetText(NEXT or "Next")

local pageText = walletBorder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pageText:SetPoint("RIGHT", nextBtn, "LEFT", -8, 0)

local prevBtn = CreateFrame("Button", nil, walletBorder, "UIPanelButtonTemplate")
prevBtn:SetSize(58, 20)
prevBtn:SetPoint("RIGHT", pageText, "LEFT", -8, 0)
prevBtn:SetText(PREV or "Prev")

prevBtn:SetScript("OnClick", function() addon.ChangePage(-1) end)
nextBtn:SetScript("OnClick", function() addon.ChangePage(1) end)

-- Page studs: one brass stud per page between Prev and Next; the current page glows.
local MAX_PIPS = 12
local PIP_SIZE, PIP_GAP = 13, 4
local pips = {}
local pipRow = CreateFrame("Frame", nil, walletBorder)
pipRow:SetHeight(PIP_SIZE)
pipRow:SetPoint("RIGHT", nextBtn, "LEFT", -8, 0)
for i = 1, MAX_PIPS do
    local pip = Wood.BrassButton(pipRow, PIP_SIZE, "", function()
        return string.format("Page %d of %d\n|cffaaaaaaClick to jump, or scroll the mouse wheel over the shop|r", i, ShelfFrame.totalPages or 1)
    end)
    pip:SetPoint("LEFT", pipRow, "LEFT", (i - 1) * (PIP_SIZE + PIP_GAP), 0)
    pip.glow = Wood.Disc(pip, "OVERLAY", 0, 1, 0.85, 0.35, 0.9)
    pip.glow:SetPoint("TOPLEFT", -4, 4); pip.glow:SetPoint("BOTTOMRIGHT", 4, -4)
    pip.glow:SetBlendMode("ADD")
    pip:SetScript("OnClick", function()
        if ShelfFrame.page ~= i then
            ShelfFrame.page = i
            addon.Update()
        end
    end)
    pips[i] = pip
end

function addon.UpdatePager(page, totalPages)
    if totalPages <= 1 then
        pageText:Hide(); prevBtn:Hide(); nextBtn:Hide(); pipRow:Hide()
        return
    end
    prevBtn:SetEnabled(page > 1)
    nextBtn:SetEnabled(page < totalPages)
    prevBtn:Show(); nextBtn:Show()

    if totalPages <= MAX_PIPS then
        pageText:Hide()
        pipRow:Show()
        pipRow:SetWidth(totalPages * (PIP_SIZE + PIP_GAP) - PIP_GAP)
        for i, pip in ipairs(pips) do
            pip:SetShown(i <= totalPages)
            local current = i == page
            pip.glow:SetShown(current)
            pip:SetAlpha(current and 1 or 0.6)
        end
        prevBtn:SetPoint("RIGHT", pipRow, "LEFT", -8, 0)
    else
        pipRow:Hide()
        pageText:SetText(string.format("%d / %d", page, totalPages))
        pageText:Show()
        prevBtn:SetPoint("RIGHT", pageText, "LEFT", -8, 0)
    end
end

function addon.UpdateWallet()
    local usesGold = false
    local seen, currencies = {}, {}

    for index = 1, GetMerchantNumItems() do
        local _, _, price, _, _, _, _, extendedCost = addon.GetVendorItemData(index)
        if price and price > 0 then usesGold = true end
        if extendedCost and GetMerchantItemCostInfo then
            for c = 1, (GetMerchantItemCostInfo(index) or 0) do
                local tex, _, currName, playerCount = addon.GetExtendedCostDetails(index, c)
                local key = currName or tostring(tex)
                if key and not seen[key] then
                    seen[key] = true
                    currencies[#currencies + 1] = { name = currName or "Currency", texture = tex, count = playerCount }
                end
            end
        end
    end

    local parts = {}
    if usesGold or ShelfFrame.buyback or #currencies == 0 then
        parts[#parts + 1] = addon.CoinString(GetMoney() or 0, 11)
    end
    for _, curr in ipairs(currencies) do
        local iconStr = curr.texture and string.format("|T%s:13:13:0:0|t ", tostring(curr.texture)) or ""
        local countStr = curr.count and BreakUpLargeNumbers(curr.count) or "?"
        parts[#parts + 1] = string.format("%s|cffffd100%s:|r |cffffffff%s|r", iconStr, curr.name, countStr)
    end
    walletText:SetText(table.concat(parts, "    "))
end

-- ============================================================================
-- RESIZE GRIP (re-renders only when the column/row count actually changes)
-- ============================================================================
local resizeGrip = CreateFrame("Button", nil, ShelfFrame)
resizeGrip:SetSize(20, 20)
resizeGrip:SetPoint("BOTTOMRIGHT", ShelfFrame, "BOTTOMRIGHT", -5, 5)
resizeGrip:SetFrameLevel(walletBar:GetFrameLevel() + 5)
resizeGrip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeGrip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeGrip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

resizeGrip:SetScript("OnMouseDown", function(self, button)
    if button ~= "LeftButton" then return end
    ShelfFrame:StartSizing("BOTTOMRIGHT")
    local lastCols, lastRows = addon.GetGridDims()
    self:SetScript("OnUpdate", function()
        local cols, rows = addon.GetGridDims()
        if cols ~= lastCols or rows ~= lastRows then
            lastCols, lastRows = cols, rows
            ShelfFrame.cols, ShelfFrame.rows = cols, rows
            addon.Update()
        end
    end)
end)

resizeGrip:SetScript("OnMouseUp", function(self)
    ShelfFrame:StopMovingOrSizing()
    self:SetScript("OnUpdate", nil)
    local w, h = ShelfFrame:GetSize()
    local padX = C.SHELF_PAD_X + addon.GetWingWidth()
    local cols = math.floor((w - padX + C.COL_STRIDE * 0.5) / C.COL_STRIDE)
    local rows = math.floor((h - C.PAD_Y + C.ROW_STRIDE * 0.5) / C.ROW_STRIDE)
    addon.ApplyGrid(cols, rows)
    if addon.db then
        addon.db.cols, addon.db.rows = ShelfFrame.cols, ShelfFrame.rows
    end
    addon.Update()
end)
