-- VenStore: zone themes.
-- Every painted surface has a structural role (wall, post, shelf, counter...). A theme gives each
-- role a colour and, optionally, a material (a Blizzard world texture). Wood.lua paints surfaces
-- by role and repaints them in place when the theme changes. Themes are picked on MERCHANT_SHOW
-- from the player's map (walking up the parent maps, so one entry for Kul Tiras covers Boralus,
-- Drustvar and Stormsong), or forced with /venstore theme <name>.
local _, addon = ...

local Theme = {}
addon.Theme = Theme

-- Roles, and where each one is used:
--   wall        backboard planks behind the shelves
--   post        side posts and the dividers between bays
--   beam        header beam across the top
--   trim        beam moulding, wallet bar
--   bracket     the supports under each shelf (uses the trim colour and material unless a theme
--               gives it its own)
--   shelf       shelf fronts, the showroom floor front, cart shelf boards
--   deck        shelf tops and the showroom floor deck
--   counter     counter body (and its recessed cubby back)
--   counterTrim face frame around the cart cubby
--   counterTop  counter slab and lip
--   base        counter kick plate
--   plinth      display plinth column and top
Theme.ROLES = { "wall", "post", "beam", "trim", "bracket", "shelf", "deck", "counter", "counterTrim", "counterTop", "base", "plinth" }
-- A role a theme leaves out borrows another role's colour and material.
Theme.FALLBACK = { bracket = "trim" }

-- A theme has:
--   roles      colour of each role: the plank tint for wooden surfaces, and for surfaces with a
--              material the material's average colour (used for bevel edges and as the fallback)
--   materials  optional Blizzard world textures per role, by file ID (format in Wood.lua). Roles
--              without one stay wood. If the client lacks a file, that surface falls back to wood.
--   varnish    sheen on wooden boards (1 = the original lacquered look, 0 = raw timber)
-- The file IDs are city textures from the game's own files (dungeons/textures/...).
-- Stormwind's stone is pale in its texture files; the game lights it blue-grey.
local SW_STONE = { 0.74, 0.78, 0.86 }

Theme.list = {
    workshop = {
        name = "Workshop",
        varnish = 1,
        roles = {
            wall = { 0.30, 0.18, 0.09 },
            post = { 0.40, 0.25, 0.13 },        -- oak
            beam = { 0.52, 0.33, 0.17 },        -- honey
            trim = { 0.27, 0.16, 0.08 },        -- walnut
            shelf = { 0.52, 0.33, 0.17 },
            deck = { 0.40, 0.25, 0.13 },
            counter = { 0.27, 0.16, 0.08 },
            counterTrim = { 0.40, 0.25, 0.13 },
            counterTop = { 0.52, 0.33, 0.17 },
            base = { 0.17, 0.10, 0.05 },        -- ebony
            plinth = { 0.52, 0.33, 0.17 },
        },
    },
    -- Big blue-grey blocks of the city walls, and the honey timber of Stormwind's shop interiors:
    -- diamond-inlaid trim, carved supports, plank shelves and counters.
    stormwind = {
        name = "Stormwind",
        varnish = 0.8,
        roles = {
            wall = { 0.49, 0.50, 0.52 },
            post = { 0.55, 0.41, 0.23 },
            beam = { 0.40, 0.28, 0.17 },
            trim = { 0.56, 0.42, 0.24 },
            bracket = { 0.57, 0.51, 0.37 },
            shelf = { 0.56, 0.42, 0.24 },
            deck = { 0.76, 0.61, 0.40 },
            counter = { 0.68, 0.52, 0.33 },
            counterTrim = { 0.76, 0.61, 0.40 },
            counterTop = { 0.76, 0.61, 0.40 },
            base = { 0.44, 0.45, 0.46 },
            plinth = { 0.62, 0.63, 0.64 },
        },
        materials = {
            wall = { file = 130067, size = 288, tint = SW_STONE },                -- mm_strmwnd_wall_05
            post = { file = 129400, band = { 0.45, 0.62 }, axis = "v" },          -- mm_strmwnd_supports_01: inlay
            beam = { file = 129395, band = { 0.00, 0.23 } },                      -- mm_strmwnd_int_trim_01: beams
            trim = { file = 129395, band = { 0.40, 0.56 } },                      -- int_trim_01: diamond inlay
            bracket = { file = 129400, rect = { 0.00, 0.31, 0.00, 0.50 } },       -- supports_01: carved swirl
            shelf = { file = 129395, band = { 0.40, 0.56 } },
            deck = { file = 127441, band = { 0.50, 1.00 } },                      -- mm_strmwnd_int_furniture_01
            counter = { file = 127979, size = 160 },                              -- mm_strmwnd_int_floor_01: boards
            counterTrim = { file = 127441, size = 128 },
            counterTop = { file = 127441, band = { 0.50, 1.00 } },
            base = { file = 465095, size = 96, tint = SW_STONE },                 -- stormwind_stone_drk
            plinth = { file = 457670, size = 128, tint = SW_STONE },              -- stormwind_stone
        },
    },
    -- Darnassus: living wood. Purple leaf-carved planks, honey timber with scalloped trims,
    -- carved swirl posts, mossy stone and tree-ring floors (the night elf druid buildings).
    nightelf = {
        name = "Darnassus",
        varnish = 0.5,
        roles = {
            wall = { 0.25, 0.14, 0.18 },
            post = { 0.26, 0.19, 0.12 },
            beam = { 0.37, 0.27, 0.17 },
            trim = { 0.38, 0.27, 0.17 },
            shelf = { 0.21, 0.11, 0.10 },
            deck = { 0.20, 0.15, 0.09 },
            counter = { 0.34, 0.28, 0.20 },
            counterTrim = { 0.33, 0.23, 0.15 },
            counterTop = { 0.23, 0.14, 0.11 },
            base = { 0.18, 0.29, 0.22 },
            plinth = { 0.24, 0.18, 0.12 },
        },
        materials = {
            wall = { file = 1140753, size = 256, boost = 0.35 },                   -- 7ne_druid_ceiling01: leaf planks
            post = { file = 1139145, band = { 0.25, 0.75 }, axis = "v", boost = 0.3 }, -- 7ne_druid_column01
            beam = { file = 1139144, band = { 0.00, 0.38 }, boost = 0.2 },         -- 7ne_druid_trims01: scallops
            trim = { file = 1139144, band = { 0.40, 0.60 }, boost = 0.2 },
            shelf = { file = 1140754, band = { 0.28, 0.52 }, boost = 0.4 },        -- 7ne_druid_woodtrims01
            deck = { file = 1239340, size = 128, boost = 0.4 },                    -- 7ne_druid_woodfloor02: mossy
            counter = { file = 1239333, rect = { 0.00, 1.00, 0.10, 1.00 }, boost = 0.2 }, -- 7ne_druid_wall01
            counterTrim = { file = 1139144, size = 128, boost = 0.2 },
            counterTop = { file = 1140754, band = { 0.05, 0.25 }, boost = 0.4 },
            base = { file = 1139146, size = 96, boost = 0.3 },                     -- 7ne_druid_rockbase01: moss
            plinth = { file = 1139145, size = 96, boost = 0.3 },
        },
    },
    -- Nailed plank walls, carved timber, teal-painted metal and grey harbour stone.
    kultiras = {
        name = "Kul Tiras",
        varnish = 0.5,
        roles = {
            wall = { 0.52, 0.41, 0.30 },
            post = { 0.37, 0.28, 0.22 },
            beam = { 0.36, 0.27, 0.20 },
            trim = { 0.26, 0.42, 0.37 },
            shelf = { 0.39, 0.31, 0.24 },
            deck = { 0.34, 0.28, 0.22 },
            counter = { 0.52, 0.41, 0.30 },
            counterTrim = { 0.24, 0.38, 0.34 },
            counterTop = { 0.43, 0.43, 0.35 },
            base = { 0.40, 0.38, 0.31 },
            plinth = { 0.43, 0.43, 0.35 },
        },
        materials = {
            wall = { file = 1627052, size = 192, boost = 0.2 },                       -- 8hu_kultiras_wallwood01
            post = { file = 1627063, band = { 0.30, 0.55 }, axis = "v", boost = 0.5 }, -- woodcolumn01
            beam = { file = 1660655, band = { 0.00, 0.24 }, boost = 0.5 },            -- walltrim02: carved band
            trim = { file = 1627069, band = { 0.15, 0.38 }, boost = 0.6, sheen = 0.6 }, -- metaltrim02: teal
            shelf = { file = 1627059, band = { 0.53, 0.72 }, boost = 0.5 },           -- woodtrim01
            deck = { file = 1627055, size = 128, boost = 0.5 },                       -- woodtrim02
            counter = { file = 1627052, size = 128, boost = 0.2 },
            counterTrim = { file = 1627067, size = 128, boost = 0.6, sheen = 0.6 },   -- metaltrim01
            counterTop = { file = 1627057, size = 128, boost = 0.3 },                 -- stonetrim01
            base = { file = 1627056, size = 96, boost = 0.2 },                        -- stairs01
            plinth = { file = 1627057, size = 96, boost = 0.3 },
        },
    },
    -- Cream stucco, carved stone with gold filigree, gold columns, marble and red lacquer.
    silvermoon = {
        name = "Silvermoon",
        varnish = 1.6,
        roles = {
            wall = { 0.79, 0.74, 0.66 },
            post = { 0.90, 0.53, 0.05 },
            beam = { 0.54, 0.52, 0.48 },
            trim = { 0.55, 0.34, 0.11 },
            shelf = { 0.57, 0.41, 0.25 },
            deck = { 0.68, 0.63, 0.55 },
            counter = { 0.33, 0.23, 0.20 },
            counterTrim = { 0.63, 0.37, 0.06 },
            counterTop = { 0.72, 0.66, 0.57 },
            base = { 0.47, 0.18, 0.08 },
            plinth = { 0.68, 0.63, 0.55 },
        },
        materials = {
            wall = { file = 128795, size = 256 },                           -- bldelf_basewall: stucco
            post = { file = 128843, band = { 0.01, 0.13 }, sheen = 1.5 },    -- trimsdark02: gold strip
            beam = { file = 1084503, band = { 0.00, 0.25 } },               -- newtrims_02: carved stone
            trim = { file = 128843, band = { 0.27, 0.48 }, sheen = 1.5 },    -- trimsdark02: gold filigree
            shelf = { file = 1084503, band = { 0.27, 0.48 }, sheen = 1 },    -- newtrims_02: gilded band
            deck = { file = 128853, size = 128 },                           -- wdbldelf_floor3: marble
            counter = { file = 128849, size = 128 },                        -- wd_bloodelf_drkwall_01
            counterTrim = { file = 128859, size = 128, sheen = 1.5 },        -- wdbldelfgt_goldblock
            counterTop = { file = 128856, size = 128, sheen = 1 },           -- wdbldelfgt_flor1
            base = { file = 128834, size = 64 },                            -- pillardark_01: red lacquer
            plinth = { file = 128853, size = 96 },
        },
    },
    -- Rough-cut timber, spiked iron and riveted stone.
    orgrimmar = {
        name = "Orgrimmar",
        varnish = 0.15,
        roles = {
            wall = { 0.36, 0.27, 0.20 },
            post = { 0.42, 0.36, 0.32 },
            beam = { 0.36, 0.31, 0.27 },
            trim = { 0.39, 0.32, 0.29 },
            shelf = { 0.34, 0.26, 0.19 },
            deck = { 0.36, 0.27, 0.20 },
            counter = { 0.34, 0.32, 0.34 },
            counterTrim = { 0.36, 0.29, 0.27 },
            counterTop = { 0.43, 0.32, 0.24 },
            base = { 0.34, 0.24, 0.17 },
            plinth = { 0.43, 0.32, 0.24 },
        },
        materials = {
            wall = { file = 852899, size = 192, boost = 0.7 },                        -- fv_or_wood_base
            post = { file = 875897, band = { 0.26, 0.40 }, axis = "v", boost = 0.7 }, -- fv_or_metal_wall: spikes
            beam = { file = 850414, band = { 0.25, 0.62 }, boost = 0.7 },             -- fv_or_metal_base: panel
            trim = { file = 850414, band = { 0.65, 0.76 }, boost = 0.7 },             -- fv_or_metal_base: strap
            shelf = { file = 852899, band = { 0.00, 0.25 }, boost = 0.7 },
            deck = { file = 852899, size = 128, boost = 0.7 },
            counter = { file = 852898, size = 128, boost = 0.7 },                     -- fv_or_wall: riveted stone
            counterTrim = { file = 850414, size = 128, boost = 0.7 },
            counterTop = { file = 850412, size = 128, boost = 0.7 },                  -- fv_or_floor_slabs
            base = { file = 850410, size = 96, boost = 0.7 },                         -- fv_or_floor_rocks
            plinth = { file = 850412, size = 96, boost = 0.7 },
        },
    },
}
Theme.DEFAULT = "workshop"
Theme.current = Theme.list[Theme.DEFAULT]
Theme.currentKey = Theme.DEFAULT

-- Colour of `role` in `theme`, falling back to the role it borrows from, then the workshop palette.
function Theme.Colour(theme, role)
    local alt = Theme.FALLBACK[role]
    local roles, base = theme and theme.roles, Theme.list[Theme.DEFAULT].roles
    return (roles and (roles[role] or (alt and roles[alt]))) or base[role] or (alt and base[alt])
        or { 0.4, 0.25, 0.13 }
end

-- Material of `role` in `theme` (nil = wood).
function Theme.Material(theme, role)
    local mats = theme and theme.materials
    if not mats then return nil end
    local alt = Theme.FALLBACK[role]
    return mats[role] or (alt and mats[alt]) or nil
end

-- ============================================================================
-- ZONE DETECTION
-- ============================================================================
-- uiMapIDs. Each one also covers every map inside it (zones, sub-zones); /venstore theme prints
-- the chain for where you are. Each capital's theme also covers the zones of its home region.
local MAP_THEMES = {
    -- Stormwind and the kingdom around it
    [84] = "stormwind",   -- Stormwind City
    [37] = "stormwind",   -- Elwynn Forest
    [52] = "stormwind",   -- Westfall
    [49] = "stormwind",   -- Redridge Mountains
    [47] = "stormwind",   -- Duskwood
    -- Orgrimmar and Durotar
    [85] = "orgrimmar",   -- Orgrimmar
    [1] = "orgrimmar",    -- Durotar
    [10] = "orgrimmar",   -- Northern Barrens
    -- Silvermoon and Quel'Thalas
    [110] = "silvermoon", -- Silvermoon City (pre-Midnight map)
    [94] = "silvermoon",  -- Eversong Woods (pre-Midnight map)
    [95] = "silvermoon",  -- Ghostlands
    [122] = "silvermoon", -- Isle of Quel'Danas
    -- Kul Tiras: the whole continent (Boralus, Tiragarde Sound, Drustvar, Stormsong Valley)
    [876] = "kultiras",
    [1161] = "kultiras",  -- Boralus
    -- Night elf lands: Teldrassil, the Kalimdor forests and Val'sharah
    [57] = "nightelf",    -- Teldrassil
    [89] = "nightelf",    -- Darnassus
    [62] = "nightelf",    -- Darkshore
    [63] = "nightelf",    -- Ashenvale
    [80] = "nightelf",    -- Moonglade
    [198] = "nightelf",   -- Mount Hyjal
    [641] = "nightelf",   -- Val'sharah
}
-- English map names, as a fallback for maps whose IDs aren't listed (the Midnight Silvermoon and
-- Eversong, or the old-world maps on clients that number them differently). Only matches on
-- English clients.
local NAME_THEMES = {
    ["Stormwind City"] = "stormwind",
    ["Elwynn Forest"] = "stormwind",
    ["Westfall"] = "stormwind",
    ["Redridge Mountains"] = "stormwind",
    ["Duskwood"] = "stormwind",
    ["Orgrimmar"] = "orgrimmar",
    ["Durotar"] = "orgrimmar",
    ["Northern Barrens"] = "orgrimmar",
    ["Silvermoon City"] = "silvermoon",
    ["Eversong Woods"] = "silvermoon",
    ["Ghostlands"] = "silvermoon",
    ["Isle of Quel'Danas"] = "silvermoon",
    ["Kul Tiras"] = "kultiras",
    ["Boralus"] = "kultiras",
    ["Boralus Harbor"] = "kultiras",
    ["Tiragarde Sound"] = "kultiras",
    ["Drustvar"] = "kultiras",
    ["Stormsong Valley"] = "kultiras",
    ["Teldrassil"] = "nightelf",
    ["Darnassus"] = "nightelf",
    ["Darkshore"] = "nightelf",
    ["Ashenvale"] = "nightelf",
    ["Moonglade"] = "nightelf",
    ["Mount Hyjal"] = "nightelf",
    ["Val'sharah"] = "nightelf",
    ["Amirdrassil"] = "nightelf",
    ["Bel'ameth"] = "nightelf",
}

-- The player's map and its parents, most specific first: { { id = , name = }, ... }.
function Theme.MapChain()
    local chain = {}
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return chain end
    local id = C_Map.GetBestMapForUnit("player")
    local guard = 0
    while id and id > 0 and guard < 12 do
        local info = C_Map.GetMapInfo(id)
        chain[#chain + 1] = { id = id, name = info and info.name or "?" }
        id = info and info.parentMapID
        guard = guard + 1
    end
    return chain
end

-- Where the player is standing. You are within interaction range of the vendor, so this is the
-- vendor's place too. `indoors` follows Blizzard's mount rules, not how a place looks.
function Theme.Context()
    local chain = Theme.MapChain()
    local key, matchedBy
    for _, m in ipairs(chain) do
        if MAP_THEMES[m.id] then key, matchedBy = MAP_THEMES[m.id], m; break end
        if NAME_THEMES[m.name] then key, matchedBy = NAME_THEMES[m.name], m; break end
    end
    return {
        chain = chain,
        zoneKey = key,
        matchedBy = matchedBy,
        indoors = IsIndoors and IsIndoors() or false,
        outdoors = IsOutdoors and IsOutdoors() or false,
        resting = IsResting and IsResting() or false,
    }
end

-- Theme to use now: the saved override, else the zone's theme, else the workshop.
function Theme.Resolve()
    local forced = addon.db and addon.db.theme
    if forced and Theme.list[forced] then return forced, true end
    return Theme.Context().zoneKey or Theme.DEFAULT, false
end

function Theme.Set(key)
    local theme = Theme.list[key] or Theme.list[Theme.DEFAULT]
    if not Theme.list[key] then key = Theme.DEFAULT end
    if key == Theme.currentKey then return false end
    Theme.current, Theme.currentKey = theme, key
    if addon.Wood and addon.Wood.ApplyTheme then addon.Wood.ApplyTheme(theme) end
    if addon.Ambience and addon.ShelfFrame:IsShown() then addon.SafeCall(addon.Ambience.Refresh) end
    return true
end

-- Called on MERCHANT_SHOW.
function Theme.Refresh()
    return Theme.Set((Theme.Resolve()))
end

-- ============================================================================
-- /venstore theme [name | auto]
-- ============================================================================
local function Keys()
    local keys = {}
    for k in pairs(Theme.list) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

function Theme.Slash(arg)
    local out = "|cffffd100VenStore:|r "
    arg = arg and strtrim(arg):lower() or ""
    if arg == "darnassus" then arg = "nightelf" end -- the theme is shown as Darnassus; its key stays nightelf
    if arg == "auto" then
        if addon.db then addon.db.theme = nil end
        Theme.Refresh()
        print(out .. "theme follows the zone again (now " .. Theme.current.name .. ").")
        return
    elseif arg ~= "" then
        if not Theme.list[arg] then
            print(out .. "unknown theme '" .. arg .. "'. Themes: " .. table.concat(Keys(), ", ") .. ", auto")
            return
        end
        if addon.db then addon.db.theme = arg end
        Theme.Set(arg)
        print(out .. "theme forced to " .. Theme.current.name .. " (/venstore theme auto to undo).")
        return
    end

    Theme.Refresh() -- re-check the zone so the report matches where you are now
    local ctx = Theme.Context()
    local _, forced = Theme.Resolve()
    print(out .. "theme " .. Theme.current.name .. (forced and " (forced)" or ""))
    local parts = {}
    for _, m in ipairs(ctx.chain) do parts[#parts + 1] = m.name .. " (" .. m.id .. ")" end
    print("  map: " .. (#parts > 0 and table.concat(parts, " > ") or "unknown"))
    if ctx.matchedBy then
        print("  zone theme: " .. ctx.zoneKey .. ", matched on " .. ctx.matchedBy.name .. " (" .. ctx.matchedBy.id .. ")")
    else
        print("  zone theme: none (workshop)")
    end
    print("  IsIndoors " .. tostring(ctx.indoors) .. ", IsOutdoors " .. tostring(ctx.outdoors)
        .. ", IsResting " .. tostring(ctx.resting))
    print("  textures: " .. Theme.MaterialReport())
    print("  themes: " .. table.concat(Keys(), ", ") .. ", auto")
end

-- How many of each theme's material textures this client can load ("silvermoon 11/11, ...").
-- Missing ones fall back to wood.
function Theme.MaterialReport()
    local Wood = addon.Wood
    local parts, missing = {}, {}
    for _, key in ipairs(Keys()) do
        local mats = Theme.list[key].materials
        if mats then
            local ok, n = 0, 0
            for _, role in ipairs(Theme.ROLES) do
                local m = mats[role]
                if m then
                    n = n + 1
                    if Wood.CanLoad(m.file) then ok = ok + 1 else missing[#missing + 1] = key .. "." .. role .. "=" .. m.file end
                end
            end
            parts[#parts + 1] = key .. " " .. ok .. "/" .. n
        end
    end
    local s = table.concat(parts, ", ")
    if #missing > 0 then s = s .. " (missing: " .. table.concat(missing, ", ") .. ")" end
    return s
end
