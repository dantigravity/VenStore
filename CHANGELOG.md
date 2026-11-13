# Changelog

## 1.3.1

### Changed
- The 3D wilderness keeps its size when you resize the window. It is drawn as it looks with the shop two shelves high, anchored to the floor and to the vendor, so a bigger window shows more of the landscape instead of enlarging it. The horizon stays at the vendor's eye level at any size.

## 1.3.0

### Added
- **Settings menu.** Click the gear on the header beam, or type `/venstore`, to open it. It opens to the right of the shop, can be dragged anywhere, and remembers where you put it. It holds:
  - the shop theme (Auto or any theme)
  - time-of-day lighting and the outdoor breeze (On / Off)
  - the setting (Auto, Indoors, Town or Wilds) and the time of day (follow the realm clock, or set an hour)
  - a button that resets the window size
- **Darnassus theme** for Teldrassil, Darnassus, Darkshore, Ashenvale, Moonglade, Mount Hyjal, Val'sharah, Amirdrassil and Bel'ameth: the living wood of Darnassus, built from the game's own druid textures.
- **Time of day.** The shop's lighting follows the realm clock from dawn to night. Each theme has a window in its own style behind the vendor, showing the sky outside, and square windows glow at night.
- **Indoors and outdoors.** The shop works out where you are:
  - Indoors, it is the shop as before.
  - In a town, the walls stay and the light is the open-air light.
  - Out in the wilds, the shop becomes a market stall: a canvas awning, square corner posts with knee braces, and the region's own landscape behind it.
- **3D wilderness.** The landscape behind the stall is built from the zone's real tree, bush and fence models, standing on ground that runs back to the horizon at the vendor's eye level:
  - Elwynn, for Stormwind, the Workshop and Kul Tiras
  - Ashenvale, for Darnassus
  - Eversong, for Silvermoon
  - the Barrens, for Orgrimmar
  
  A fence runs right behind the vendor. On clients without these models, the landscape is drawn as painted scenery instead.
- **Lights and sound.** Wall torches light up at dusk. Outdoors, a lantern on the counter flickers in the wind, and an optional breeze plays.
- **Choose a quantity.** Shift-click an item on the shelves, or an item in the cart, to type how many you want. Shift + mouse wheel on a cart item changes the amount by 10. The cart now takes up to 999 of an item (limited by the vendor's stock and your gold), and the bag-space check counts stacks.
- `/venstore forest` lists what the 3D wilderness loaded and where it put it (for bug reports). `/venstore ambience` previews a setting or hour, or turns the lighting off.

### Changed
- The vendor is about 1.4× larger and stands lower behind the counter, so they look like they stand on the floor.
- Stormwind uses larger, greyer stone blocks, and its shelves now rest on carved corbels like the city's own furniture.
- The coins and ledger on the counter are redrawn: stacked gold coins with milled edges and a leather ledger with brass corners and a ribbon.
- The quill's highlight shows only while you hover over it, not during the signing animation.

### Removed
- The plain vendor model option is no longer in the menu. `/venstore vendor` still switches it.

## 1.2.0

### Added
- Zone themes, on by default. When you open a vendor in one of these regions, the shop is rebuilt from its capital's own materials, using the game's own textures:
  - Stormwind (Stormwind City, Elwynn Forest, Westfall, Redridge Mountains, Duskwood): stone-block walls and a stone counter, with dark timber posts and shelves.
  - Orgrimmar (Orgrimmar, Durotar, Northern Barrens): rough-cut timber, spiked iron and riveted stone.
  - Silvermoon (Silvermoon City, Eversong Woods, Ghostlands, Isle of Quel'Danas): cream stucco walls, carved stone and gold filigree, gold columns, marble and red lacquer.
  - Kul Tiras (Boralus, Tiragarde Sound, Drustvar, Stormsong Valley): nailed plank walls, carved timber, teal-painted metal and harbour stone.
  
  Everywhere else keeps the original workshop look. If your client lacks a texture, that surface stays wood.
- `/venstore theme` shows the current theme, the map you're on, whether you're indoors and how many theme textures your client can load. `/venstore theme <name>` forces a theme; `/venstore theme auto` goes back to following the zone.

## 1.1.0

### Added
- WoW Forever support. The same folder now loads on both games (`## Interface: 120105, 120107, 16001`). Features the client doesn't have are left out instead of causing errors: for example, the plinth won't appear without mount, pet or housing data, and the spec filter is skipped without specializations.

### Fixed
- The TOC listed `12107` instead of `120107` for the 12.1.7 test realm.
- Gold amounts fall back to the older coin-text function on clients without `C_CurrencyInfo.GetCoinTextureString`.
- Events the client doesn't know about no longer stop the addon from loading.

## 1.0.0

First release. VenStore replaces the merchant window with a 3D wooden shop.

### Shop
- Items stand on wooden shelves with parchment price cards that list every currency.
- Resize the grid by dragging the corner grip (3×2 up to 7×5). Your size is saved, and the window scales itself down if it would run off the screen.
- Filter items by currency, item type and class/spec.
- Page through items with the mouse wheel, the Prev / Next buttons or the brass page studs.
- The wallet bar shows how much of each currency this vendor takes you have.

### Try-on mirror
- A cast-brass cheval mirror appears when the vendor sells transmog items (armor, weapons, ensembles and arsenals). Ctrl-Click an item to try it on.
- Your character fills the glass from head to feet at every angle. Wings, weapons and spell effects that reach past the glass are hidden behind the frame.
- One button per pose (Stand, Walk, Run, Combat Ready, Attack, Spell Ready, Wave, Bow, Cheer, Salute, Flex, Dance, Kneel), plus Undress and Reset to My Appearance.
- Drag to turn your character; the mouse wheel zooms out and back to the full-body view.

### Display plinth
- Mounts, battle pets and housing decor appear in 3D on a plinth beside the vendor when you Ctrl-Click them. The plinth only appears when the vendor sells something it can show.
- Items are measured and drawn in proportion to the vendor, standing on the plinth. They keep the same size as you turn them, and the bay widens for long items.
- The mouse wheel zooms in up to the edge of the frame (small items get there in about six clicks).

### Sales counter and cart
- The vendor stands behind a wooden sales counter with a brass nameplate.
- The counter's two shelves are your cart. Drag up to four items onto them, or Alt-Click them. The mouse wheel changes how many of each, and right-click takes one off.
- Click the quill to sign the bill of sale. VenStore first checks your gold, currencies and bag space. Then the quill floats up and signs, and everything is bought.

### Merchant services
- Buyback, Sell All Junk, Repair All (right-click to repair one item at a time) and Guild Repair buttons on the header beam.
- Drop an item from your bags on the shop to sell it. Right-clicking items in your bags still sells them, as in the default UI.

### Commands
- `/venstore reset` restores the default size and position.
- `/venstore vendor` switches the vendor between the 3D stage and the plain model view.
- `/venstore debug` prints sizing information for bug reports.
