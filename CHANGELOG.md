# Changelog

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
