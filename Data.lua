-- VenStore: shared constants, merchant/currency data helpers and item classification.
local _, addon = ...

-- ============================================================================
-- LAYOUT CONSTANTS
-- ============================================================================
local C = {
    MIN_COLS = 3,
    MAX_COLS = 7,
    MIN_ROWS = 2,
    MAX_ROWS = 5,

    SLOT_SIZE = 50,
    COL_STRIDE = 122,
    ROW_STRIDE = 152,

    MIRROR_BAY_W = 280,   -- Standing mirror (only when the vendor sells cosmetics)
    MIRROR_H = 506,       -- Fixed height of the mirror stand, floor included (fits the default 3-row window)
    VENDOR_W = 216,       -- Vendor standing behind the sales counter (always shown)
    DISPLAY_W = 190,      -- Display plinth for 3D previews (only when the vendor sells displayable items)
    STAGE_GAP = 10,       -- Spacing between the stage and the bay/shelves to its left
    COUNTER_RATIO = 0.47, -- Counter height as a share of the stage height (hides the vendor's legs)
    STAGE_H = 420,        -- Fixed height of the vendor / plinth scenes (taller windows add wall above)
    STAGE_FOV = 0.5,      -- Nominal camera field of view (radians); each stage calibrates its lens at runtime
    VENDOR_FIT = 0.76,    -- Share of a PlayerModel frame's height the vendor's body fills (used when the
                          -- vendor isn't on a 3D stage)
    DEFAULT_COLS = 4,     -- First-run grid
    DEFAULT_ROWS = 3,
    LAYOUT_VERSION = 2,   -- Bump to discard saved grid sizes when the default layout changes

    SHELF_PAD_X = 78,     -- Horizontal chrome around the shelf grid
    PAD_Y = 160,          -- Vertical chrome (header beam + wallet bar + tags)
    PLANK_H = 38,         -- Backboard plank height (never stretches)

    HEADER_H = 56,
    FOOTER_H = 42,
}
C.MAX_SLOTS = C.MAX_COLS * C.MAX_ROWS
addon.C = C

-- Run a function, reporting (not swallowing) any error through the standard error handler.
function addon.SafeCall(func, ...)
    if select("#", ...) == 0 then
        return xpcall(func, geterrorhandler())
    end
    local args = { ... }
    local n = select("#", ...)
    return xpcall(function() return func(unpack(args, 1, n)) end, geterrorhandler())
end

-- ============================================================================
-- CLIENT
-- ============================================================================
-- The same files run on Retail and on WoW Forever (WOW_PROJECT_CAMELOT). Features are detected
-- by checking that the API exists, so this flag is only used for /venstore debug.
addon.IS_FOREVER = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

-- Register an event only if this client knows it (unknown event names raise an error).
function addon.RegisterEventSafe(frame, event)
    return (pcall(frame.RegisterEvent, frame, event))
end

-- Gold / silver / copper with coin icons.
function addon.CoinString(copper, size)
    copper = copper or 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper, size)
    elseif GetCoinTextureString then
        return GetCoinTextureString(copper, size)
    elseif GetMoneyString then
        return GetMoneyString(copper)
    end
    return tostring(copper)
end

-- ============================================================================
-- CURRENCY / COST HELPERS
-- ============================================================================
local scanTip = CreateFrame("GameTooltip", "VenStoreCurrencyScanTip", nil, "GameTooltipTemplate")
scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")

function addon.GetExtendedCostDetails(merchantIndex, costIndex)
    local itemTexture, itemValue, itemLink, currencyName = GetMerchantItemCostItem(merchantIndex, costIndex)
    local name = currencyName
    local count

    if itemLink then
        local currencyID = itemLink:match("currency:(%d+)")
        if currencyID and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local info = C_CurrencyInfo.GetCurrencyInfo(tonumber(currencyID))
            if info then
                name = name or info.name
                count = info.quantity
                if not itemTexture or itemTexture == 0 then itemTexture = info.iconFileID end
            end
        else
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            if itemID and C_Item then
                if C_Item.GetItemNameByID then name = name or C_Item.GetItemNameByID(itemID) end
                if C_Item.GetItemCount then count = C_Item.GetItemCount(itemID, true) end
                if (not itemTexture or itemTexture == 0) and C_Item.GetItemIconByID then
                    itemTexture = C_Item.GetItemIconByID(itemID)
                end
            end
        end
    end

    if (not name or name == "") and scanTip.SetMerchantCostItem then
        scanTip:ClearLines()
        scanTip:SetMerchantCostItem(merchantIndex, costIndex)
        local line1 = _G["VenStoreCurrencyScanTipTextLeft1"]
        local text = line1 and line1:GetText()
        if text and text ~= "" then name = text end
    end

    if not count and name and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyListSize then
        for i = 1, C_CurrencyInfo.GetCurrencyListSize() do
            local info = C_CurrencyInfo.GetCurrencyListInfo(i)
            if info and not info.isHeader and info.name == name then
                count = info.quantity
                if not itemTexture or itemTexture == 0 then itemTexture = info.iconFileID end
                break
            end
        end
    end

    return itemTexture, itemValue, name or "Token", count
end

-- name, texture, price, stackCount, numAvailable, isPurchasable, isUsable, hasExtendedCost
function addon.GetVendorItemData(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local info = C_MerchantFrame.GetItemInfo(index)
        if info then
            return info.name, info.texture, info.price, info.stackCount, info.numAvailable,
                info.isPurchasable, info.isUsable, info.hasExtendedCost
        end
    elseif GetMerchantItemInfo then
        return GetMerchantItemInfo(index)
    end
end

function addon.GetVendorItemCategory(index)
    local link = GetMerchantItemLink(index)
    if link and C_Item and C_Item.GetItemInfoInstant then
        local _, itemType = C_Item.GetItemInfoInstant(link)
        if itemType and itemType ~= "" then return itemType end
    end
    return "Other"
end

function addon.GetSlotCurrencyNames(index, price, extendedCost)
    local names = {}
    if price and price > 0 then names[#names + 1] = "Gold" end
    if extendedCost and GetMerchantItemCostInfo then
        for c = 1, (GetMerchantItemCostInfo(index) or 0) do
            local _, _, currName = addon.GetExtendedCostDetails(index, c)
            if currName and currName ~= "" then names[#names + 1] = currName end
        end
    end
    if #names == 0 then names[1] = "Free" end
    return names
end

function addon.FormatVendorPrice(index, price, extendedCost)
    local valueParts, nameParts = {}, {}
    if price and price > 0 then
        valueParts[#valueParts + 1] = addon.CoinString(price, 10)
        if not extendedCost then
            nameParts[#nameParts + 1] = price >= 10000 and "Gold" or (price >= 100 and "Silver" or "Copper")
        end
    end
    if extendedCost and GetMerchantItemCostInfo then
        for c = 1, (GetMerchantItemCostInfo(index) or 0) do
            local tex, val, currName = addon.GetExtendedCostDetails(index, c)
            if tex and val then
                valueParts[#valueParts + 1] = string.format("%d |T%s:12:12:0:0|t", val, tostring(tex))
            elseif val then
                valueParts[#valueParts + 1] = tostring(val)
            end
            if currName and currName ~= "" then nameParts[#nameParts + 1] = currName end
        end
    end
    local valueStr = #valueParts > 0 and table.concat(valueParts, "  ") or "Free"
    local nameStr = #nameParts > 0 and table.concat(nameParts, " + ") or ""
    return valueStr, nameStr
end

-- ============================================================================
-- ITEM CLASSIFICATION (cosmetic / transmog vs. other previewable items)
-- ============================================================================
-- Equip slots that carry a transmog appearance (necks, rings and trinkets do not).
local TRANSMOG_EQUIP_LOCS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_BODY = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
    INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_CLOAK = true, INVTYPE_TABARD = true,
    INVTYPE_WEAPON = true, INVTYPE_SHIELD = true, INVTYPE_2HWEAPON = true,
    INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true,
    INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true,
}

-- Returns the transmog set learned by an ensemble/arsenal item, if any.
function addon.GetItemTransmogSet(itemID)
    if itemID and C_Item and C_Item.GetItemLearnTransmogSet then
        local ok, setID = pcall(C_Item.GetItemLearnTransmogSet, itemID)
        if ok and setID and setID > 0 then return setID end
    end
end

function addon.IsCosmeticItem(link, name)
    if not link or not (C_Item and C_Item.GetItemInfoInstant) then return false end
    local itemID, _, _, equipLoc = C_Item.GetItemInfoInstant(link)
    if equipLoc and TRANSMOG_EQUIP_LOCS[equipLoc] then return true end
    if addon.GetItemTransmogSet(itemID) then return true end
    -- Fallback for ensembles whose set data is not cached yet (English clients).
    if name and (name:find("^Ensemble:") or name:find("^Arsenal:")) then return true end
    return false
end

-- What the display plinth can show for an item, or nil when it has no 3D model.
--   { kind = "mount", displayID }       { kind = "pet", displayID, creatureID }
--   { kind = "decor", asset, sceneID }
function addon.GetDisplayInfo(link)
    local itemID = link and tonumber(link:match("item:(%d+)"))
    if not itemID then return nil end

    if C_MountJournal and C_MountJournal.GetMountFromItem then
        local mountID = C_MountJournal.GetMountFromItem(itemID)
        local displayID = mountID and C_MountJournal.GetMountInfoExtraByID(mountID)
        if displayID and displayID > 0 then
            return { kind = "mount", displayID = displayID }
        end
    end

    if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        -- 4th return = creatureID, 12th = creatureDisplayID
        local _, _, _, creatureID, _, _, _, _, _, _, _, displayID = C_PetJournal.GetPetInfoByItemID(itemID)
        if (displayID and displayID > 0) or (creatureID and creatureID > 0) then
            return { kind = "pet", displayID = displayID, creatureID = creatureID }
        end
    end

    if C_HousingCatalog and C_HousingCatalog.GetCatalogEntryInfoByItem then
        local ok, info = pcall(C_HousingCatalog.GetCatalogEntryInfoByItem, itemID)
        if ok and type(info) == "table" and info.asset and info.asset ~= 0 then
            return { kind = "decor", asset = info.asset, sceneID = info.uiModelSceneID }
        end
    end

    -- Toys are deliberately not here: the game exposes no 3D model for them (the Toy Box only
    -- shows icons, and PlayerModel:SetItem only works for weapons / held items).
end

-- Midnight can hide unit identities ("secret values"); string operations on them error.
function addon.IsUnitSecret(unit)
    return C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret and C_Secrets.ShouldUnitIdentityBeSecret(unit) or false
end

-- The merchant's name, or nil when the game keeps it secret.
function addon.GetNPCName()
    if addon.IsUnitSecret("npc") then return nil end
    local name = UnitName("npc")
    if name == nil or (issecretvalue and issecretvalue(name)) then return nil end
    return name
end

function addon.VendorHasDisplayables()
    for idx = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(idx)
        if link and not addon.IsCosmeticItem(link, (addon.GetVendorItemData(idx))) and addon.GetDisplayInfo(link) then
            return true
        end
    end
    return false
end

function addon.VendorHasCosmetics()
    for idx = 1, GetMerchantNumItems() do
        local link = GetMerchantItemLink(idx)
        if link and addon.IsCosmeticItem(link, (addon.GetVendorItemData(idx))) then
            return true
        end
    end
    return false
end
