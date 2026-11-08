-- VenStore: currency / item type / class-spec filter dropdowns on the header beam.
local _, addon = ...
local ShelfFrame = addon.ShelfFrame
local topBeam = addon.topBeam
local filters = addon.filters

local function Refresh()
    ShelfFrame.page = 1
    addon.Update()
end

local currencyDropdown = CreateFrame("Frame", "VenStoreCurrencyFilterDD", topBeam, "UIDropDownMenuTemplate")
currencyDropdown:SetPoint("LEFT", topBeam, "LEFT", -4, -4)
UIDropDownMenu_SetWidth(currencyDropdown, 125)

local typeDropdown = CreateFrame("Frame", "VenStoreTypeFilterDD", topBeam, "UIDropDownMenuTemplate")
typeDropdown:SetPoint("LEFT", currencyDropdown, "RIGHT", -18, 0)
UIDropDownMenu_SetWidth(typeDropdown, 125)

local specDropdown = CreateFrame("Frame", "VenStoreSpecFilterDD", topBeam, "UIDropDownMenuTemplate")
specDropdown:SetPoint("LEFT", typeDropdown, "RIGHT", -18, 0)
UIDropDownMenu_SetWidth(specDropdown, 135)
UIDropDownMenu_SetText(specDropdown, "Class/Spec")

function addon.ResetFilters()
    filters.currency = "ALL"
    filters.type = "ALL"
    UIDropDownMenu_SetText(currencyDropdown, "Currency: All")
    UIDropDownMenu_SetText(typeDropdown, "Type: All")
end
addon.ResetFilters()

local function AddOption(level, text, checked, onSelect, icon)
    local info = UIDropDownMenu_CreateInfo()
    info.text = text
    info.icon = icon
    info.checked = checked
    info.func = onSelect
    UIDropDownMenu_AddButton(info, level)
end

UIDropDownMenu_Initialize(currencyDropdown, function(_, level)
    AddOption(level, "All Currencies", filters.currency == "ALL", function()
        filters.currency = "ALL"
        UIDropDownMenu_SetText(currencyDropdown, "Currency: All")
        Refresh()
    end)

    local seen = {}
    for idx = 1, GetMerchantNumItems() do
        local _, _, price, _, _, _, _, extendedCost = addon.GetVendorItemData(idx)
        for _, cName in ipairs(addon.GetSlotCurrencyNames(idx, price, extendedCost)) do
            if not seen[cName] then
                seen[cName] = true
                AddOption(level, cName, filters.currency == cName, function()
                    filters.currency = cName
                    UIDropDownMenu_SetText(currencyDropdown, cName)
                    Refresh()
                end)
            end
        end
    end
end)

UIDropDownMenu_Initialize(typeDropdown, function(_, level)
    AddOption(level, "All Item Types", filters.type == "ALL", function()
        filters.type = "ALL"
        UIDropDownMenu_SetText(typeDropdown, "Type: All")
        Refresh()
    end)

    local seen = {}
    for idx = 1, GetMerchantNumItems() do
        local cat = addon.GetVendorItemCategory(idx)
        if not seen[cat] then
            seen[cat] = true
            AddOption(level, cat, filters.type == cat, function()
                filters.type = cat
                UIDropDownMenu_SetText(typeDropdown, cat)
                Refresh()
            end)
        end
    end
end)

function addon.UpdateSpecDropdownLabel()
    if not GetMerchantFilter then return end
    local current = GetMerchantFilter()
    local className = UnitClass("player") or "Class"
    local label = className
    if current == LE_LOOT_FILTER_ALL then
        label = ALL_CLASSES or "All Classes"
    elseif current == LE_LOOT_FILTER_BOE then
        label = ITEM_BIND_ON_EQUIP or "Bind on Equip"
    elseif GetSpecializationInfo and LE_LOOT_FILTER_SPEC1 and current >= LE_LOOT_FILTER_SPEC1 then
        local _, specName = GetSpecializationInfo(current - LE_LOOT_FILTER_SPEC1 + 1)
        label = specName or className
    end
    UIDropDownMenu_SetText(specDropdown, label)
end

UIDropDownMenu_Initialize(specDropdown, function(_, level)
    if not GetMerchantFilter or not SetMerchantFilter then return end
    local current = GetMerchantFilter()

    local function Select(filterValue)
        return function()
            SetMerchantFilter(filterValue)
            addon.UpdateSpecDropdownLabel()
            Refresh()
        end
    end

    AddOption(level, ALL_CLASSES or "All Classes", current == LE_LOOT_FILTER_ALL, Select(LE_LOOT_FILTER_ALL))
    AddOption(level, UnitClass("player") or "Class", current == LE_LOOT_FILTER_CLASS, Select(LE_LOOT_FILTER_CLASS))

    local sex = UnitSex("player")
    for s = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
        local _, specName, _, icon = GetSpecializationInfo(s, nil, nil, nil, sex)
        if specName then
            local filterValue = LE_LOOT_FILTER_SPEC1 + s - 1
            AddOption(level, "  " .. specName, current == filterValue, Select(filterValue), icon)
        end
    end
end)
