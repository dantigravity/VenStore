-- VenStore: merchant services on the header beam - Buyback, Sell All Junk, Repair, Guild Repair.
-- (Selling from the bags works as in the default UI: right-click an item in your bags, or drop it
-- on the shop.)
local _, addon = ...
local Wood = addon.Wood
local ShelfFrame = addon.ShelfFrame

local Services = {}
addon.Services = Services

local SIZE, GAP = 24, 6

local function Coins(copper)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(copper or 0)
    end
    return tostring(copper or 0)
end

local function SetUsable(b, usable)
    b:SetEnabled(usable)
    if b.art then b.art:SetDesaturated(not usable) end
    b:SetAlpha(usable and 1 or 0.55)
end

local bar = CreateFrame("Frame", nil, addon.topBeam)
bar:SetSize(SIZE, SIZE)
bar:SetPoint("RIGHT", addon.topBeam, "RIGHT", -36, -4)
bar:SetFrameLevel(addon.topBeam:GetFrameLevel() + 6)

-- ---------------------------------------------------------------- buttons (right to left)
local buyback = Wood.IconButton(bar, SIZE, "INV_Misc_Note_02", BUYBACK or "Buyback",
    "Show the items you sold this session. Click one to buy it back. Click this button again to return to the shop.")
local junk = Wood.IconButton(bar, SIZE, "INV_Misc_Coin_02", "Sell All Junk",
    "Sell every poor-quality (grey) item in your bags. You can buy them back.")
local repair = Wood.IconButton(bar, SIZE, "Trade_BlackSmithing", REPAIR_ALL_ITEMS or "Repair All Items", nil)
local guildRepair = Wood.IconButton(bar, SIZE, "Achievement_GuildPerk_CashFlow", "Guild Repair", nil)

local order = { buyback, junk, repair, guildRepair } -- laid out right to left; hidden ones close up

local function Layout()
    local prev
    for _, b in ipairs(order) do
        b:ClearAllPoints()
        if b:IsShown() then
            if prev then b:SetPoint("RIGHT", prev, "LEFT", -GAP, 0) else b:SetPoint("RIGHT", bar, "RIGHT", 0, 0) end
            prev = b
        end
    end
end

-- Buyback view toggle.
function Services:SetBuyback(on)
    ShelfFrame.buyback = on and true or false
    buyback:SetSelected(ShelfFrame.buyback)
    ShelfFrame.page = 1
    if ShelfFrame:IsShown() then addon.Update() end
end
buyback:SetScript("OnClick", function() Services:SetBuyback(not ShelfFrame.buyback) end)
buyback:HookScript("OnEnter", function()
    GameTooltip:AddLine(string.format("Items to buy back: %d", GetNumBuybackItems() or 0), 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

-- Sell all junk.
local function JunkCount()
    if C_MerchantFrame and C_MerchantFrame.GetNumJunkItems then return C_MerchantFrame.GetNumJunkItems() end
end
junk:SetScript("OnClick", function()
    if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems then C_MerchantFrame.SellAllJunkItems() end
end)
junk:HookScript("OnEnter", function()
    local n = JunkCount()
    if n then GameTooltip:AddLine(string.format("Junk items in your bags: %d", n), 0.8, 0.8, 0.8) end
    GameTooltip:Show()
end)

-- Repair (left-click: everything; right-click: pick single items with the repair cursor).
repair:RegisterForClicks("LeftButtonUp", "RightButtonUp")
repair:SetMotionScriptsWhileDisabled(true)
repair:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        if InRepairMode() then HideRepairCursor() else ShowRepairCursor() end
        return
    end
    RepairAllItems(false)
    if SOUNDKIT and SOUNDKIT.ITEM_REPAIR then PlaySound(SOUNDKIT.ITEM_REPAIR) end
end)
repair:HookScript("OnEnter", function()
    local cost, needed = GetRepairAllCost()
    if needed and cost and cost > 0 then
        GameTooltip:AddDoubleLine(REPAIR_COST or "Repair cost:", Coins(cost), 1, 0.82, 0, 1, 1, 1)
    else
        GameTooltip:AddLine("Nothing needs repairing.", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Right-click: repair one item at a time", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)

-- Guild repair (paid from the guild bank).
guildRepair:SetScript("OnClick", function()
    RepairAllItems(true)
    if SOUNDKIT and SOUNDKIT.ITEM_REPAIR then PlaySound(SOUNDKIT.ITEM_REPAIR) end
end)
guildRepair:HookScript("OnEnter", function()
    local cost = GetRepairAllCost() or 0
    GameTooltip:AddDoubleLine(REPAIR_COST or "Repair cost:", Coins(cost), 1, 0.82, 0, 1, 1, 1)
    local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()
    if limit and limit >= 0 then
        GameTooltip:AddDoubleLine("Guild allowance left:", Coins(limit), 1, 0.82, 0, 1, 1, 1)
    end
    GameTooltip:Show()
end)

for _, b in ipairs(order) do b:SetMotionScriptsWhileDisabled(true) end

-- ---------------------------------------------------------------- state
function Services:Update()
    buyback:SetSelected(ShelfFrame.buyback)
    SetUsable(buyback, ShelfFrame.buyback or (GetNumBuybackItems() or 0) > 0)

    local canJunk = C_MerchantFrame and C_MerchantFrame.SellAllJunkItems
    junk:SetShown(canJunk and true or false)
    if canJunk then
        local n = JunkCount()
        local enabled = not (C_MerchantFrame.IsSellAllJunkEnabled and not C_MerchantFrame.IsSellAllJunkEnabled())
        SetUsable(junk, enabled and (n == nil or n > 0))
    end

    local canRepair = CanMerchantRepair and CanMerchantRepair()
    repair:SetShown(canRepair and true or false)
    local cost, needed = 0, false
    if canRepair then
        cost, needed = GetRepairAllCost()
        cost = cost or 0
        SetUsable(repair, true) -- right-click (single items) works even when nothing is damaged
        repair.art:SetDesaturated(not (needed and cost > 0 and GetMoney() >= cost))
    end
    local canGuild = canRepair and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair()
    guildRepair:SetShown(canGuild and true or false)
    if canGuild then
        local limit = GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney() or 0
        SetUsable(guildRepair, needed and cost > 0 and (limit < 0 or limit >= cost))
    end
    Layout()
end

function Services:OnMerchantClosed()
    ShelfFrame.buyback = false
    if InRepairMode and InRepairMode() then HideRepairCursor() end
end

local events = CreateFrame("Frame")
for _, e in ipairs({ "UPDATE_INVENTORY_DURABILITY", "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "GUILDBANK_UPDATE_WITHDRAWMONEY" }) do
    pcall(events.RegisterEvent, events, e)
end
events:SetScript("OnEvent", function()
    if ShelfFrame:IsShown() then Services:Update() end
end)

Layout()
