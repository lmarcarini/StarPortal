# Interface reference

**This is the target the interface must match.** It answers the owner's review of
2026-11-16: the direction was right but the implementation was sloppy, and the agents had
no exact reference to check against. From now on every UI card is checked against this
document and its images, and a screen that is visibly off is rejected.

The layout follows the owner's own industrial mock-up (top bar, event cards left,
destinations right, one bottom bar with the station keys, destination monitor, DIAL key,
gauge and Shutter), made exact.

## Files

| File | What |
| --- | --- |
| `docs/reference/ref_gate_idle.png` | Gate station, gate idle, a destination selected |
| `docs/reference/ref_gate_open.png` | Gate station, wormhole open, send rail, mission sheet open |
| `docs/reference/ref_other_station.png` | The frame on any other station (Base shown); the station's own content is a placeholder |
| `docs/reference/overlay_*.png` | The same layouts as labelled rectangles with coordinates |
| `docs/reference/layout.json` | Every rectangle, machine-readable (the single source) |
| `tools/reference/render_ref.py` | The script that draws all of the above (`python3 tools/reference/render_ref.py . docs/reference`) |

The images use the Gate hall plate as a stand-in for the 3D scene that will replace it
(section 7). Everything over the scene is what must be matched.

## 1. Canvas and scaling

- Designed at **1920 × 1080**. All numbers below are at that size.
- The whole interface scales uniformly with the window height (Godot `canvas_items`
  stretch, aspect `expand`). Wider windows add space between the left column, the scene
  and the right column; nothing stretches.
- The scene (3D view or plate) is **full bleed**: it fills the whole window behind every
  bar and panel. No black bands, no letterboxing, no scene inset inside a frame.

## 2. Regions

| Region | x | y | w | h |
| --- | --- | --- | --- | --- |
| `top_bar` | 0 | 0 | 1920 | 76 |
| `top_site` | 8 | 8 | 392 | 60 |
| `top_clock` | 408 | 8 | 304 | 60 |
| `top_resources` | 720 | 8 | 760 | 60 |
| `top_call` | 1488 | 8 | 212 | 60 |
| `top_speed` | 1708 | 8 | 204 | 60 |
| `wire` | 16 | 92 | 368 | 600 |
| `team_card` | 16 | 716 | 368 | 148 |
| `right_panel` | 1536 | 92 | 368 | 772 |
| `send_rail` | 1004 | 764 | 520 | 100 |
| `mission_sheet` | 1184 | 400 | 336 | 352 |
| `bottom_bar` | 0 | 880 | 1920 | 200 |
| `station_keys` | 16 | 896 | 624 | 168 |
| `dest_crt` | 656 | 896 | 400 | 168 |
| `dial_block` | 1072 | 896 | 432 | 168 |
| `seal_lamps` | 1088 | 900 | 400 | 36 |
| `main_key` | 1088 | 948 | 400 | 104 |
| `charge_gauge` | 1520 | 896 | 240 | 168 |
| `shutter` | 1776 | 896 | 128 | 168 |
| `station_console` | 656 | 896 | 848 | 168 |
| `gate_monitor` | 1520 | 896 | 384 | 168 |
| `station_area` | 400 | 92 | 1120 | 772 |

Tolerance: ±4 px on every edge. `station_area` is where a non-Gate station draws its
own content until its phase rebuilds it.

## 3. Look

**Palette (only these):**

| Role | Colour |
| --- | --- |
| Steel, top / bottom of the gradient | `#2E2F29` → `#1E1F1B` |
| Steel bevel line (1 px at the top) | `#626356` |
| Edges and outlines (2 px) | `#0D0E0D` |
| Text | `#E9E4D0` |
| Dim text | `#9C9A88` |
| Amber (selection, lit keys, lamps) | `#E8A33D`, highlight `#FFD98F` |
| CRT green | `#7FD68A` on `#0A160E` |
| Red (alarm, falling values) | `#E5533D` |
| Hazard yellow | `#E8B224` |
| Paper (cards and sheets) | `#E9E4D0` → `#DAD4BE`, ink `#1A1A16` |
| Ring blue (open gate only) | `#3FA9F5` |

**Materials:**
- **Steel plate:** vertical gradient, light noise, 6 px radius, 2 px dark edge, 1 px bevel
  line at the top, a bolt in each corner on plates larger than 40 × 30, and a soft drop
  shadow (offset 4, blur 7, 65% black).
- **Key:** raised plate with a 4 px dark base under it, so it reads as a physical key.
  States: steel (normal), amber (primary or current), lit (amber outline on dark: toggled
  on), off (flat, dim: unavailable), hazard (yellow-black stripes around a dark face:
  CLOSE and GO).
- **Lamp:** dark bezel, amber or green lens with a highlight; lit lamps glow.
- **CRT:** green on near-black, scanlines every 3 px, soft glow, thick rounded bezel.
- **Paper:** off-white with grain and a hard drop shadow; a coloured strip on the left
  edge for cards.

**Type:**

| Use | Font | Size | Tracking |
| --- | --- | --- | --- |
| Titles on plates and cards | Barlow Condensed SemiBold, upper case | 22–28 | +2 |
| Key labels | Barlow Condensed SemiBold, upper case | 18–26 (DIAL 50, CLOSE 46, GO 36) | +2 |
| Secondary lines | Barlow Condensed Medium | 15–17 | +1 |
| Numbers | IBM Plex Mono Bold | 18–24 | 0 |
| Deltas and units | IBM Plex Mono Regular | 16 | 0 |

Nothing on screen smaller than 15 px. No sentence anywhere except hover cards,
documents and conversations.

**Icons:** line icons, 3 px stroke, drawn at 24–56 px; the set in the reference is the
minimum.

## 4. The frame (every station)

**Top bar** (`top_bar`): a dark band with five steel plates.
- `top_site`: the Ring icon, SITE CAIRN (28), a second line (15, dim).
- `top_clock`: clock icon, the date (26), the time below in amber mono (18), the slow lamp
  at the right end (green when normal, amber with its reason on hover when slowed).
- `top_resources`: four cells of 240, 180, 160 and 180 px separated by 2 px dark rules: an
  icon, the value in mono 24, and the delta or unit in mono 16 (green rising, red falling,
  dim for units). Funds, power used/supply, charge, Confidence. Hover gives the
  breakdown; click goes to the owning station.
- `top_call`: a lamp and the phone icon; the caller in amber when a call waits, dim NO
  CALL otherwise. Click answers.
- `top_speed`: four 44 px keys: pause, play, fast (the current speed is amber), settings.

**The wire** (`wire`): cards 368 × 96, 10 px apart, at most five, then a `+N` key that
opens the full log. Each card: dark steel, a 6 px coloured strip on the left (amber
attention, green good news, red danger), a 34 px icon in the strip colour, a title (22) and
one line (17, dim), and up to two 46 × 52 action keys on the right (amber for the primary
action). New cards slide in from the left.

**Bottom bar** (`bottom_bar`): full width, 200 px, steel with a hazard-patterned lip on top.
- `station_keys`: four keys 148 × 168, 10 px apart: a 56 px icon over a 26 px label. The
  current station is amber; a red lamp in the top right corner when something there needs
  the player.
- Gate station: `dest_crt`, `dial_block` (with `seal_lamps` and `main_key`),
  `charge_gauge`, `shutter`.
- Other stations: `station_console` (that station's own controls) and `gate_monitor`.

## 5. Gate station

- **Scene:** full bleed. The Ring is centred horizontally, its centre at about y 448, inner
  radius about 168, outer about 213 (at the plate's scale). The eight seal lamps sit on the
  eight clamps.
- `right_panel` DESTINATIONS: header (Ring icon, title 24); the selected destination large
  (picture 328 × 180 with an amber frame, or blue while that wormhole is open; name 34;
  one dim line; status icons right); the rest as a two-column grid of cards 164 × 132
  (picture, name 20, dots for status); `+ NEW ADDRESS` key at the foot, 64 high.
- `team_card`: paper card: team, mission and world (24); member faces 52 × 52; a ring
  clock for time left; the due date.
- `dest_crt`: the destination's picture in green, its name (38), status icons, the seven
  address glyphs.
- `dial_block`: eight lamps in a row (lit with the seals), and the main key: DIAL (amber)
  idle, CLOSE (hazard) open, ANSWER (amber) for an incoming wormhole.
- `charge_gauge`: a cream analogue dial, red zone at the low end, the needle, MWh, the
  value below in mono 20 and the drain in red while open.
- `shutter`: a lever in a slot, label below.
- `send_rail` (open only): five keys 96 × 100, 10 px apart, on the floor right of the
  ramp: CAMERA, CANISTER, MOTH, TEAM, HAIL. Badges are paper discs at the top right corner.
  Used keys are off; the key whose sheet is open is lit.
- `mission_sheet`: paper, above the rail and clear of the Ring: title, three mission keys
  96 × 78, member faces 68 × 68, days, and the GO hazard key 160 × 68.

## 6. How a UI card is accepted

1. Run the reference scenario (`scenario_gate_station`) at 1920 × 1080 and capture the
   screen in the same state as the reference image.
2. Put the capture **beside** the reference image and **under** the overlay image, both in
   the PR description.
3. Check every region against section 2 (±4 px) and the look against section 3.
4. **UI cards are not merged by the implementing agent.** The PR is marked ready and the PO
   reviews the screenshots; a visibly off screen is sent back with the differences listed.

## 7. The scene becomes 3D

The owner decided on 2026-11-16 that the stations are rendered as real-time 3D scenes
(nothing fancy, playable on a modern integrated graphics card) instead of 2D plates. The
frame above does not change; only what is behind it does. The plate stays as the stand-in
until the 3D Gate hall exists, and the reference images keep using it.

## 8. Base station (owner decision 2026-11-17: the lit plan table, option B)

The owner preferred the 3D cut-away (option A) but put it in the backlog: the interface
comes first, so the Base is a lit 2D plan table for now.

**Images:** `docs/reference/ref_base_build.png`, `ref_base_power.png`, `ref_base_staff.png`,
`overlay_base.png`. Regions are in `layout.json` (`base_*`, `room_panel`,
`base_plan_grid`). Drawn by `tools/reference/base_ref.py` with the shared kit
`tools/reference/refkit.py`.

- **Background:** the station area is a steel table surface; the frame is the same as on
  every station.
- `base_table`: a steel plate; inside it `base_glass`, dark glass with a faint grid.
- `base_plan_grid`: the level's cells, 80 px each at 1080p (origin and size in
  layout.json). The plan zooms and pans when a level is larger than the glass.
- **Rooms:** tiles inset 4 px from their cells: fill by state (on: dark green with a soft
  glow and a green rim; off: dark grey; site: dark ochre with a progress bar and what is
  being built), a 24 px type icon and the name (18) top left, a green lamp top right when
  on. Staff slots along the bottom: filled discs with the role letter, empty rings for
  free slots. The selected room has a 4 px amber outline. The Gate Room shows the Ring.
- **Corridors:** darker strips inset 8 px.
- `base_levels`: keys L1 to L4, 56 × 52, 8 px apart; current amber, dug steel, undug off.
- `base_dig`: **DIG** key right under the level keys (owner request), 56 × 88, a down
  arrow; the next level and its cost on a dim line under it. Pressing it starts digging
  the next level (the same command as today's Dig card).
- `room_panel`: the selected room (replaces the Gate's destinations panel): title with
  icon, what it is doing with a progress bar, a POWER key showing state and MW, staff
  faces (filled) and empty slots (+), installed items and + INSTALL, DEMOLISH at the foot.
- **Console** (`station_console`): four mode keys on the left (`base_console_modes`):
  BUILD, POWER, STAFF, SECURITY; the current one lit. The tray (`base_console_tray`)
  depends on the mode:
  - BUILD: room cards 106 wide (icon, name, price in amber, size). Pick one and a green
    ghost follows the cursor on the plan; click to place; right click or Esc cancels.
  - POWER: supply, use and charging on one line; one breaker per powered room (lever up
    amber = on). Rooms on the plan turn amber or grey and show their MW.
  - STAFF: everyone on base as face tiles (name, role letter, room); drag a tile onto a
    room's empty slot (a dashed amber line follows), or onto the tray to unassign.
  - SECURITY: squads and doors, same tile style (no reference image yet; follow BUILD's
    layout).
