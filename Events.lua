-- VenStore: saved settings, merchant events and the slash command.
local addonName, addon = ...
local C = addon.C
local ShelfFrame = addon.ShelfFrame
local Showroom = addon.Showroom
local SafeCall = addon.SafeCall

local merchantOpen = false
local savedMerchantScale

-- Keep Blizzard's MerchantFrame open (the merchant session depends on it) but invisible and
-- shrunk to nothing, so none of its buttons can be clicked by accident behind our window.
local function SuppressBlizzardMerchant(suppress)
    if suppress then
        savedMerchantScale = savedMerchantScale or MerchantFrame:GetScale()
        MerchantFrame:SetAlpha(0)
        MerchantFrame:EnableMouse(false)
        MerchantFrame:SetScale(0.01)
    else
        MerchantFrame:SetAlpha(1)
        MerchantFrame:EnableMouse(true)
        if savedMerchantScale then
            MerchantFrame:SetScale(savedMerchantScale)
            savedMerchantScale = nil
        end
    end
end

-- Closing our window (X button or Escape) ends the merchant session.
ShelfFrame:SetScript("OnHide", function()
    if merchantOpen then CloseMerchant() end
end)

local function ChooseGrid()
    local db = addon.db
    if db and db.cols and db.rows then
        return db.cols, db.rows
    end
    if not ShelfFrame.autoSized then
        ShelfFrame.autoSized = true
        return C.DEFAULT_COLS, C.DEFAULT_ROWS
    end
    return ShelfFrame.cols, ShelfFrame.rows
end

local function OnMerchantShow()
    merchantOpen = true
    SuppressBlizzardMerchant(true)

    SafeCall(addon.Theme.Refresh) -- zone theme (repaints only when it changes)
    ShelfFrame.page = 1
    ShelfFrame.buyback = false
    addon.ResetFilters()
    Showroom:SetMirrorShown(addon.VendorHasCosmetics())
    Showroom:SetDisplayShown(addon.VendorHasDisplayables())
    addon.ApplyGrid(ChooseGrid())

    SafeCall(Showroom.Reset, Showroom)
    SafeCall(addon.Cart.Reset, addon.Cart)
    SafeCall(addon.Update)
    ShelfFrame:Show()
end

local function OnMerchantUpdate()
    if not ShelfFrame:IsShown() then return end
    -- Item data can arrive after MERCHANT_SHOW; bring the mirror / plinth in if they are needed late.
    local changed = false
    if not ShelfFrame.showMirror and addon.VendorHasCosmetics() then
        Showroom:SetMirrorShown(true)
        changed = true
    end
    if not ShelfFrame.showDisplay and addon.VendorHasDisplayables() then
        Showroom:SetDisplayShown(true)
        changed = true
    end
    if changed then addon.ApplyGrid() end
    SafeCall(addon.Update)
    SafeCall(addon.Cart.Refresh, addon.Cart)
end

local function OnMerchantClosed()
    merchantOpen = false
    Showroom:OnMerchantClosed()
    addon.Cart:OnMerchantClosed()
    addon.Services:OnMerchantClosed()
    ShelfFrame:Hide()
    SuppressBlizzardMerchant(false)
end

local eventFrame = CreateFrame("Frame")
for _, event in ipairs({ "ADDON_LOADED", "MERCHANT_SHOW", "MERCHANT_UPDATE", "MERCHANT_CLOSED",
    "PLAYER_MONEY", "CURRENCY_DISPLAY_UPDATE", "BAG_UPDATE_DELAYED", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
    addon.RegisterEventSafe(eventFrame, event)
end

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == addonName then
            VenStoreDB = VenStoreDB or {}
            addon.db = VenStoreDB
            -- Saved grid sizes are discarded when C.LAYOUT_VERSION changes.
            if (VenStoreDB.layoutVersion or 1) < C.LAYOUT_VERSION then
                VenStoreDB.cols, VenStoreDB.rows = nil, nil
                VenStoreDB.layoutVersion = C.LAYOUT_VERSION
            end
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "MERCHANT_SHOW" then
        OnMerchantShow()
    elseif event == "MERCHANT_UPDATE" then
        OnMerchantUpdate()
    elseif event == "MERCHANT_CLOSED" then
        OnMerchantClosed()
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        addon.FitToScreen()
    elseif ShelfFrame:IsShown() then -- money / currency / bag changes
        SafeCall(addon.UpdateWallet)
    end
end)

-- ============================================================================
-- /venstore reset  - restore default size and position
-- ============================================================================
SLASH_VENSTORE1 = "/venstore"
SlashCmdList.VENSTORE = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "reset" then
        if addon.db then addon.db.cols, addon.db.rows = nil, nil end
        ShelfFrame.autoSized = false
        ShelfFrame:ClearAllPoints()
        ShelfFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
        addon.ApplyGrid(C.DEFAULT_COLS, C.DEFAULT_ROWS)
        if ShelfFrame:IsShown() then SafeCall(addon.Update) end
        print("|cffffd100VenStore:|r window size and position reset.")
    elseif msg == "theme" or msg:match("^theme ") then
        addon.Theme.Slash(msg:sub(7))
    elseif msg == "debug" then
        addon.Showroom.DebugDump()
    elseif msg == "vendor" then
        local classic = addon.Showroom:ToggleClassicVendor()
        print("|cffffd100VenStore:|r vendor drawn by " .. (classic and "the plain model frame." or "the 3D stage (when available)."))
    else
        print("|cffffd100VenStore|r commands:")
        print("  /venstore reset - restore the default window size and position")
        print("  /venstore debug - print the 3D sizing numbers (for bug reports)")
        print("  /venstore vendor - switch the vendor between the 3D stage and the plain model frame")
        print("  /venstore theme [name | auto] - show the zone theme and map, or force a theme")
    end
end
