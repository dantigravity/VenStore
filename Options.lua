-- VenStore: settings. The same controls appear in two places: a panel that drops down from the gear
-- on the header beam (so changes show on the open shop straight away), and the game's own
-- Settings > AddOns list.
local _, addon = ...
local Wood = addon.Wood
local ShelfFrame = addon.ShelfFrame

local Options = {}
addon.Options = Options

local THEME_ORDER = { "workshop", "stormwind", "nightelf", "kultiras", "silvermoon", "orgrimmar" }
local PLACES = {
    { key = nil,       label = "Auto" },
    { key = "indoor",  label = "Indoors" },
    { key = "outdoor", label = "Town" },
    { key = "wild",    label = "Wilds" },
}

local function DB() return addon.db or {} end

local builds = {} -- every built set of controls, refreshed together

function Options.RefreshAll()
    for _, refresh in ipairs(builds) do refresh() end
end

local function Changed()
    addon.SafeCall(addon.Ambience.Refresh)
    Options.RefreshAll()
end

-- ============================================================================
-- CONTROLS (plain widgets with stock textures, so they look the same on every client)
-- ============================================================================
local function Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    return fs
end

local function Choice(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    function b:SetSelected(on)
        if on then self:LockHighlight() else self:UnlockHighlight() end
        local fs = self:GetFontString()
        if fs then
            if on then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(0.85, 0.85, 0.85) end
        end
    end
    return b
end

local function Slider(parent, width, lo, hi, step, onChange)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(width, 16)
    s:SetHitRectInsets(0, 0, -6, -6)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(lo, hi)
    s:SetValueStep(step)
    if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        if self:IsEnabled() then self:SetValue(self:GetValue() + delta * step) end
    end)
    s:SetScript("OnValueChanged", function(self, value)
        if self.quiet then return end
        value = math.floor(value / step + 0.5) * step
        onChange(value)
    end)
    function s:SetQuietly(v)
        self.quiet = true
        self:SetValue(v)
        self.quiet = false
    end
    function s:SetActive(on)
        self:SetEnabled(on)
        self:SetAlpha(on and 1 or 0.45)
    end
    return s
end

-- ============================================================================
-- THE CONTROLS, built into `parent` from the top-left (x, y). Returns the height used.
-- ============================================================================
local CHOICE_W, CHOICE_GAP = 88, 4

function Options.Build(parent, x, y)
    local top = y
    local function Heading(text)
        local h = Label(parent, text, "GameFontNormal")
        h:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        y = y - 20
        return h
    end
    local function Note(text)
        local n = Label(parent, text, "GameFontDisableSmall")
        n:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        n:SetWidth(3 * CHOICE_W + 2 * CHOICE_GAP)
        y = y - 16
        return n
    end
    local function Row(buttons)
        for i, b in ipairs(buttons) do
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + col * (CHOICE_W + CHOICE_GAP), y - row * 26)
        end
        y = y - math.ceil(#buttons / 3) * 26 - 2
    end

    -- Theme -------------------------------------------------------------------
    Heading("Shop theme")
    local themeButtons = {}
    local autoTheme = Choice(parent, "Auto", CHOICE_W, function()
        DB().theme = nil
        addon.Theme.Refresh()
        Changed()
    end)
    themeButtons[1] = autoTheme
    for _, key in ipairs(THEME_ORDER) do
        local b = Choice(parent, addon.Theme.list[key].name, CHOICE_W, function()
            DB().theme = key
            addon.Theme.Refresh()
            Changed()
        end)
        b.key = key
        themeButtons[#themeButtons + 1] = b
    end
    Row(themeButtons)
    local themeNote = Note("")
    y = y - 8

    -- A setting with two choices side by side on its own row (On / Off, Realm / Set...).
    local TOGGLE_W = 62
    local function Toggle(text, tooltip, aText, bText, onPick)
        local label = Label(parent, text, "GameFontHighlight")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 5)
        local a = Choice(parent, aText, TOGGLE_W, function() onPick(true) end)
        local b = Choice(parent, bText, TOGGLE_W, function() onPick(false) end)
        b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 3 * CHOICE_W + 2 * CHOICE_GAP - TOGGLE_W, y)
        a:SetPoint("RIGHT", b, "LEFT", -CHOICE_GAP, 0)
        for _, btn in ipairs({ a, b }) do
            btn:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(text, 1, 1, 1)
                GameTooltip:AddLine(tooltip, 1, 0.82, 0, true)
                GameTooltip:Show()
            end)
            btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        end
        y = y - 26
        local t = {}
        function t.Set(first, enabled)
            a:SetSelected(first); b:SetSelected(not first)
            a:SetEnabled(enabled ~= false); b:SetEnabled(enabled ~= false)
            if enabled == false then label:SetTextColor(0.5, 0.5, 0.5) else label:SetTextColor(1, 1, 1) end
        end
        return t
    end

    -- Lighting ----------------------------------------------------------------
    Heading("Lighting")
    local ambienceToggle = Toggle("Time-of-day lighting",
        "The light follows the time of day. Outdoors the shop becomes a market stall: in town it keeps its walls, and out in the wilds the region's own trees and shrubs stand behind it.",
        "On", "Off", function(on)
            DB().ambience = (not on) and "off" or nil
            Changed()
        end)
    local breezeToggle = Toggle("Breeze outdoors",
        "A soft wind plays while the shop is a market stall (on the game's ambience volume).",
        "On", "Off", function(on)
            DB().breeze = (not on) and false or nil
            Changed()
        end)
    y = y - 4

    local placeLabel = Label(parent, "Setting")
    placeLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    y = y - 14
    local placeButtons = {}
    for i, p in ipairs(PLACES) do
        local b = Choice(parent, p.label, CHOICE_W, function()
            DB().place = p.key
            Changed()
        end)
        b.key = p.key
        placeButtons[i] = b
    end
    Row(placeButtons)
    local placeNote = Note("")
    y = y - 4

    local timeToggle = Toggle("Time of day", "Realm follows the realm's clock. Set lets you pick an hour with the slider.",
        "Realm", "Set", function(realm)
            if realm then DB().hour = nil else DB().hour = DB().hour or addon.Ambience.Hour() end
            Changed()
        end)
    y = y - 4
    local hourSlider = Slider(parent, 3 * CHOICE_W + 2 * CHOICE_GAP - 60, 0, 23.5, 0.5, function(v)
        DB().hour = v
        Changed()
    end)
    hourSlider:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 4, y)
    local hourText = Label(parent, "", "GameFontHighlight")
    hourText:SetPoint("LEFT", hourSlider, "RIGHT", 10, 0)
    y = y - 30

    local reset = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    reset:SetSize(2 * CHOICE_W + CHOICE_GAP, 22)
    reset:SetText("Reset window size")
    reset:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    reset:SetScript("OnClick", function() addon.ResetWindow() end)
    y = y - 26

    local function Refresh()
        local db = DB()
        local forced = db.theme and addon.Theme.list[db.theme] and db.theme
        for _, b in ipairs(themeButtons) do b:SetSelected(b.key == forced) end
        local zoneKey = addon.Theme.Context().zoneKey or addon.Theme.DEFAULT
        themeNote:SetText("Auto follows the map region. Here: " .. addon.Theme.list[zoneKey].name .. ".")

        local on = addon.Ambience.Enabled()
        ambienceToggle.Set(on)
        breezeToggle.Set(db.breeze ~= false, on)
        for _, b in ipairs(placeButtons) do
            b:SetSelected(b.key == db.place)
            b:SetEnabled(on)
        end
        local here = addon.Ambience.AutoPlace()
        placeNote:SetText("Auto: indoors, in a town, or out in the wilds. Here: " .. (here == "indoor" and "indoors" or here == "town" and "town" or "wilds") .. ".")
        timeToggle.Set(db.hour == nil, on)
        hourSlider:SetQuietly(addon.Ambience.Hour())
        hourSlider:SetActive(on and db.hour ~= nil)
        hourText:SetText(addon.Ambience.FormatHour(addon.Ambience.Hour()))
    end
    builds[#builds + 1] = Refresh
    Refresh()
    return top - y, Refresh
end

-- ============================================================================
-- GEAR AND DROP-DOWN PANEL ON THE SHOP
-- ============================================================================
local topBeam = addon.topBeam
local gear = Wood.IconButton(topBeam, 24, "INV_Misc_Gear_01", "Settings",
    "Theme, lighting and vendor options. Right-click to open them in the game's AddOns settings.")
gear:SetPoint("RIGHT", topBeam, "RIGHT", -36, -4)
gear:SetFrameLevel(topBeam:GetFrameLevel() + 6)
gear:RegisterForClicks("LeftButtonUp", "RightButtonUp")
Options.gear = gear

-- The merchant buttons move left of the gear, with a little space between.
local bar = addon.Services and addon.Services.bar
if bar then
    bar:ClearAllPoints()
    bar:SetPoint("RIGHT", gear, "LEFT", -14, 0)
end

local PANEL_W = 3 * CHOICE_W + 2 * CHOICE_GAP + 36
local panel = CreateFrame("Frame", nil, ShelfFrame, "BackdropTemplate")
panel:SetFrameLevel(ShelfFrame:GetFrameLevel() + 60) -- above the lighting layer
panel:EnableMouse(true)
panel:EnableMouseWheel(true)
panel:SetScript("OnMouseWheel", function() end) -- don't page the shelves behind it
panel:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 24,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
})
panel:SetBackdropColor(0.09, 0.06, 0.03, 0.97)
panel:SetBackdropBorderColor(0.80, 0.66, 0.48, 1)
panel:Hide()
Options.panel = panel

local panelTitle = Label(panel, "Shop settings", "GameFontNormalLarge")
panelTitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
local panelClose = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
panelClose:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -2, -2)

local used = Options.Build(panel, 18, -44)
panel:SetSize(PANEL_W, used + 60)

-- Drag the panel by its background to move it. It remembers the spot, relative to the shop, so it
-- moves with the shop.
local function PlacePanel()
    panel:ClearAllPoints()
    local pos = addon.db and addon.db.settingsPos
    if pos then
        panel:SetPoint("TOPLEFT", ShelfFrame, "TOPLEFT", pos[1], pos[2])
    else
        panel:SetPoint("TOPLEFT", ShelfFrame, "TOPRIGHT", 4, 0) -- beside the shop, on its right
    end
end
Options.PlacePanel = PlacePanel
PlacePanel()
panel:SetMovable(true)
panel:SetClampedToScreen(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local l, t = self:GetLeft(), self:GetTop()
    local sl, st = ShelfFrame:GetLeft(), ShelfFrame:GetTop()
    if l and t and sl and st then
        if addon.db then addon.db.settingsPos = { l - sl, t - st } end
    end
    PlacePanel()
end)

panel:SetScript("OnShow", function() PlacePanel(); Options.RefreshAll(); gear:SetSelected(true) end)
panel:SetScript("OnHide", function() gear:SetSelected(false) end)
ShelfFrame:HookScript("OnHide", function() panel:Hide() end)

gear:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        panel:Hide()
        Options.OpenGameSettings()
    else
        panel:SetShown(not panel:IsShown())
    end
end)

-- ============================================================================
-- GAME SETTINGS > ADDONS
-- ============================================================================
local canvas = CreateFrame("Frame")
canvas.name = "VenStore"
local canvasTitle = Label(canvas, "VenStore", "GameFontNormalLarge")
canvasTitle:SetPoint("TOPLEFT", canvas, "TOPLEFT", 16, -16)
local canvasSub = Label(canvas, "Changes show on the shop the next time you open a vendor, or straight away from the gear on the shop's header beam.")
canvasSub:SetPoint("TOPLEFT", canvasTitle, "BOTTOMLEFT", 0, -6)
canvasSub:SetWidth(520)
Options.Build(canvas, 20, -64)
canvas:SetScript("OnShow", Options.RefreshAll)

if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, canvas, "VenStore")
    if ok and category then
        Settings.RegisterAddOnCategory(category)
        Options.category = category
    end
elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(canvas)
end

function Options.OpenGameSettings()
    if Options.category and Settings and Settings.OpenToCategory then
        local id = Options.category.GetID and Options.category:GetID() or Options.category.ID
        Settings.OpenToCategory(id)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(canvas)
        InterfaceOptionsFrame_OpenToCategory(canvas) -- the first call can land on the wrong page
    end
end
