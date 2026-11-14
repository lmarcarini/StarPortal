# Interface pass

Design for the interface pass that comes before M4c (incursions). It answers the owner's
brief of 2026-11-13: rethink the interface in looks and in function, decide what is always
visible and what belongs on each tab, keep the management screens low fidelity and
functional, and render the Ring and the security cameras in 3D for immersion ("nothing too
fancy").

It replaces section 1 (screen map) of `presentation-and-systems.md` and the layout parts of
its section 3. Game rules do not change. Choices beyond the owner's decisions are PO
proposals and are marked **(proposal)**; the open ones are collected in section 10.

**Owner decisions this builds on (2026-11-13):**

- Two registers: flat 2D for management, 3D only for the Gate Room and security cameras.
- The Base stays a top-down plan. The isometric base of the owner's mock-up is rejected.
- No morale system.
- The camera feed is a small inset on the Base tab that can be expanded.
- Defence is commanded through squads, and incursions come only through the gate (M4c).
- Placing people directly on the plan is wanted as another way to allocate personnel.

---

## 1. Two registers

**Instrument (2D).** Every management screen. Flat panels, thin rules, stencilled labels,
numbers in monospace. No pre-rendered room art, no perspective. It is code-drawn, as the
Base plan and the Ring are today, so it costs no art time and scales cleanly from 80% to
150%.

**Camera (3D).** Two places only: the Gate Room's view of the Ring, and the security camera
feed. Both use the pipeline the MOTH feed already has: a low-poly scene in a small
SubViewport (320 × 240), upscaled with scanlines and grain, a fixed camera, no free look.
The low resolution is the style and also the budget: untextured or flat-colour meshes, one
or two lights, no shadows beyond a baked blob.

The contrast is deliberate. The player manages through instruments and *looks* through
cameras, so anything shown in 3D feels like the real place.

## 2. Look

The art bible's direction holds: government equipment, restricted palettes, and **the Ring's
blue is the only saturated blue in the game**. The owner's mock-up uses blue for the whole
interface; this design keeps its structure (top bar, left status, right gate panel, large
tab buttons) but not its colour. **(proposal: the owner may prefer the blue.)**

| Role | Colour | Used for |
| --- | --- | --- |
| Ground | Near-black grey-green `#14181A` | Screen background |
| Panel | `#1D2326`, rule `#39444A` | Panels, borders |
| Text | Off-white `#E2E0D4`, dim `#9CA3A0` | Values, labels |
| Selection | Sodium orange `#E8A33D` | Current tab, selected room, focus |
| Good | CRT green `#7FD68A` | On, powered, gains |
| Warning | Amber, with a triangle | Needs attention soon |
| Alarm | Klaxon red `#E5533D`, with a filled square | Breach, failure |
| Ring | Event-horizon blue `#3FA9F5` | Gate chip when open, Ring view, nothing else |

Fonts as in the bible: Barlow Condensed for labels and headings, IBM Plex Mono for numbers
and data. Every status has a shape as well as a colour.

**Alarm state.** During a breach the ground darkens, panel rules turn red and the top bar
shows a red strip. Nothing else moves, so the player's muscle memory still works.

## 3. Always visible: the top bar

One bar, 56 px at 1080p, on every screen. Left to right:

```
+----------------------------------------------------------------------------------------+
| 14 MAR 1997 09:42 [||][>][>>]1x | $4,120k +38/d | CONF 61 ^ | PWR 25/30 MW  CAP 310 MWh |
|                                 | GATE: IDLE     | (call lamp)  ! 2 alerts  v          |
+----------------------------------------------------------------------------------------+
```

| Item | Shows | Click goes to |
| --- | --- | --- |
| Clock | Date, time, pause and speed | (controls) |
| Funds | Balance and today's net change | Command |
| Confidence | Value and trend arrow | Command |
| Power | Switched on over supply; stored energy | Base, Energy |
| Gate chip | IDLE, DIALLING, OPEN with world and time left, INCOMING | Gate Room |
| Call lamp | Lit while a phone call waits (as now) | Answers the call |
| Alerts | Count; opens a list, newest first | The alert's screen |

Rules for what earns a place: a number the player steers by every minute (time, money,
power), or a state that can change while they are on another tab (gate, calls, alerts).
Everything else lives on its tab.

**Removed from the bar:** the newest Log line (the alert list replaces it; the Log stays in
the Archive). **Not added:** morale and a security meter (no such systems), staff count
(Personnel shows it; "unassigned staff" and "beds full" become alerts).

**Alerts** absorb the things the player would otherwise have to check tabs for: lab idle,
research finished, staff unassigned, candidate waiting, request due, artefact hazard, site
finished, team check-in. Each has a kind icon and links to its screen. **(proposal)**

## 4. Tabs

Seven tabs in a row under the top bar, in the order of the loop: act at the gate, run the
base, then the records. **(proposal: order and keys.)**

| Key | Tab | Register | Holds | Sub-tabs |
| --- | --- | --- | --- | --- |
| F1 | Gate Room | Camera + instrument | Ring view, dial console, address book drawer, portal actions, incoming wormholes, holding | none |
| F2 | Base | Instrument + camera inset | The plan, building, power, staff on the plan, cameras | Build, Energy, Staff, Security (M4c) |
| F3 | Research | Instrument | Tree, queue, studies | Categories, as now |
| F4 | Personnel | Instrument | Roster, candidates, squads (M4c) | Roster, Recruit, Squads (M4c) |
| F5 | Expeditions | Instrument | Teams, field timeline, check-ins | none |
| F6 | Archive | Instrument | Documents, Worlds, Artefacts, Log | as now |
| F7 | Command | Instrument | Funds, Confidence, Factions, Requests | Finances, Factions, Requests |

What moves: Archive goes from F2 to F6 so that Base sits next to the Gate Room; nothing
changes content. The mock-up's Diplomacy, Intelligence and Missions map to Command
(Factions, Requests), Archive and Expeditions. A tab that is not yet available (Research
before the first lab) stays hidden, as now.

Tab buttons carry an icon and a label, and a dot when something inside needs attention (the
Personnel dot generalised).

**One layout for every instrument tab** so the eye learns it once:

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
| tabs                                                                         |
+------------+---------------------------------------------+-------------------+
| sub-tabs   |                                             | SELECTED          |
| and lists  |                 the board                   | detail and        |
| (240 px)   |           (plan, tree, timeline)            | actions (360 px)  |
+------------+---------------------------------------------+-------------------+
```

Left chooses, centre shows, right acts on the selection.

## 5. Base tab

```
+------------+---------------------------------------------+-------------------+
| BUILD      | L1  L2  L3            [Energy] [Staff]      | CAM 03 RESEARCH   |
| ENERGY     |  +------+  +----+  +-----------+            | +---------------+ |
| STAFF      |  |PLANT |  |LAB |  | GATE ROOM |            | | (3D feed)     | |
| SECURITY   |  |  on  |  |o o |  |   ( )     |            | +------[expand]-+ |
|------------|  +------+  +----+  +-----------+            | Research Lab     |
| palette or |     |        |          |                   | On  5 MW         |
| list for   |  ===+========+==========+===                | Staff 2/4        |
| the sub-tab|  +------+  +--------+                       | (o) Dr Ferreira  |
|            |  |CTRL o|  |QUARTERS|                       | (o) Dr Okoye     |
|            |  +------+  +--------+                       | [+] empty slot   |
+------------+---------------------------------------------+-------------------+
```

**The plan** stays top-down and becomes more schematic: flat room fills by state (on, off,
site, damaged), a stencilled name, a room-type icon, and thin furniture marks only at high
zoom. The lit-diorama shading goes; the camera inset now does that job.

**Staff tokens.** Each person on base is a small token inside their room (role by shape and
letter: S scientist, E engineer, A analyst, later G guard). Tokens sit in fixed spots and
do not walk; a reassignment moves the token at once. Unassigned people sit in a tray at the
bottom of the plan.

**Allocation by placing.** Drag a token to a room with a free slot of its role to assign;
drag to the tray to unassign; rooms that can take the token highlight while dragging. With
a gamepad or keys: select a token, press Assign, pick a highlighted room. It submits the
same assign and unassign commands as the slot buttons and the Personnel tab, which stay.
The **Staff** sub-tab lists everyone on the left (drag from the list too) and tints rooms
by how full their slots are.

**Camera inset.** At the top of the SELECTED panel when a room is selected: its camera feed
at 320 × 240, labelled with a camera number and the room name. **Expand** grows it over the
board (the left and right columns stay); Esc or (B) shrinks it. Each room type has one small
3D set built from a shared kit (walls, floor, door, a few props) and one fixed camera.
People in the room appear as simple figures matching the tokens; a room that is off shows a
dark feed, a site shows scaffolding, a room with no camera shows "NO SIGNAL".
**(proposal: the first pass ships three sets, Gate Room, Control Room and a generic room,
and adds the rest as content cards.)**

**Security sub-tab (M4c, reserved here).** Door states, squads and a camera wall. This pass
only leaves its place in the layout.

## 6. Gate Room tab

The Ring view becomes a 3D camera on the gate room: the Ring on its ramp, seals that light
in sequence, the event horizon as a simple animated surface. It keeps the current hybrid
layout and every rule (Ring at least half the view height, click the portal for actions,
address book drawer on the right, status strip). The dial console, address strip and
capacitor gauge stay 2D instruments around it.

The mock-up's right-hand gate panel on every screen is not adopted: the gate chip gives the
state, and one click or F1 gives the view. **(proposal: if the owner wants the gate visible
everywhere, the chip can show a 96 px live thumbnail while a wormhole is open.)**

## 7. The other tabs

- **Research:** unchanged in function; adopts the three-column layout (categories and queue
  left, tree centre, project detail right).
- **Personnel:** Roster and Recruit sub-tabs; the row detail moves to the right column.
  "Show on plan" jumps to the person's token on the Base tab.
- **Expeditions:** already left / centre / right; restyled only.
- **Archive:** restyled only. Documents keep their paper look inside the reader.
- **Command:** the cork board is retired for the instrument look; Finances, Factions and
  Requests become sub-tabs on the left.

## 8. Controls

Q/E and the shoulder buttons cycle tabs; F1 to F7 jump. Sub-tabs cycle with Z/C and the
triggers **(proposal)**. Esc or (B) backs out one step: expanded camera, then placement or
drag, then selection. Existing rebinding and focus rules hold; every drag has a
select-then-place equivalent.

## 9. Out of scope

Incursion rules, squads, doors and room damage (M4c). New game systems of any kind. Final
art for the 3D sets beyond the kit. Main menu, settings and save screens. Mobile or
touch layouts.

## 10. Owner decisions needed

1. **Colour:** bible palette (grey-green, orange selection, blue only for the Ring), or the
   mock-up's blue interface?
2. **Tab order and keys** as in section 4 (Archive moves to F6)?
3. **Command:** retire the cork board look?
4. **Plan:** drop the lit-diorama shading for the schematic look?
5. **Gate thumbnail** in the top bar while a wormhole is open: yes or no?
6. **Staff tokens** jump between rooms (proposed) or walk along corridors?

## 11. Suggested cards

| # | Card | Type |
| --- | --- | --- |
| 1 | Theme: palette, fonts, panel and button styles as one Godot Theme | feature |
| 2 | Top bar: funds change, power, gate chip, alert list | feature |
| 3 | Alert kinds and links for idle lab, unassigned staff, due requests and the rest | feature |
| 4 | Tab bar: seven tabs, icons, attention dots, new order and keys | feature |
| 5 | Three-column layout applied to Research, Personnel, Command | feature |
| 6 | Base plan: schematic painter | feature |
| 7 | Staff tokens and the unassigned tray | feature |
| 8 | Allocation by placing (mouse, keys, gamepad) and the Staff sub-tab | feature |
| 9 | Camera kit: low-res 3D feed widget, three room sets | feature |
| 10 | Camera inset and expand on the Base tab | feature |
| 11 | Gate Room: 3D Ring view | feature |
| 12 | Flow test, pseudo-localisation pass, playtest guide | test |
