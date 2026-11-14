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

**Owner decisions on this document (2026-11-13):** keep the bible palette, though the first
mock-up read as bland next to the owner's (section 2 answers that); the tab order is
approved; the Command cork board and the plan's lit shading may go as long as function is
kept; show a gate thumbnail in the top bar while a wormhole is open; **staff walk**, so the
base feels alive and nobody teleports on a camera feed.

---

## 1. Two registers

**Instrument (2D).** Every management screen. Flat panels, thin rules, stencilled labels,
numbers in monospace. No pre-rendered room art, no perspective. It is code-drawn, as the
Base plan and the Ring are today, so it costs no art time and scales cleanly from 80% to
150%.

**Camera (3D).** Two places only: the Gate Room's view of the Ring, and the security camera
feed. Both use one new pipeline: a low-poly scene in a small SubViewport (320 × 240),
upscaled with a scanline and grain shader, a fixed camera, no free look. The low resolution
is the style and also the budget: sets are built in code from boxes and cylinders in flat
colours, with one or two lights and no real-time shadows, so no modelled art is needed.

This is the project's first 3D. The MOTH is a 2D scan screen today (M3 owner decision), so
nothing exists to reuse; the SubViewport and shader built here are the ones the bible's 3D
drone feed would use later.

The contrast is deliberate. The player manages through instruments and *looks* through
cameras, so anything shown in 3D feels like the real place.

## 2. Look

The art bible's direction holds: government equipment, restricted palettes, and **the Ring's
blue is the only saturated blue in the game**. The owner's mock-up uses blue for the whole
interface; this design keeps its structure (top bar, left status, large tab buttons) but
not its colour. The owner accepted the palette but found the first flat mock-up bland, so
the richness comes from material and light instead of hue:

- **Hardware, not flat boxes.** Panels have a bezel and a stencilled header strip; buttons
  are raised keys that sit down when pressed; switches and lamps look like parts.
- **Light.** Lit things glow: status lamps, the selected tab, CRT text and the camera
  feed bloom slightly on the dark ground. Unlit things stay matte.
- **Texture.** A light grain and a faint vignette over the whole screen; scanlines on CRT
  panels and feeds only.
- **Large icon tabs,** as in the owner's mock-up: an icon over a label, the current one lit
  in orange.
- **Motion.** People walking on the plan, a slow sweep on the gate chip while dialling,
  lamps that blink on alerts. Small, constant signs that the base is running.

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
| Gate chip | IDLE, DIALLING, OPEN with world and time left, INCOMING; while a wormhole is open, a small live thumbnail of the Ring (96 × 54) | Gate Room |
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
base, then the records. Order and keys are owner-approved.

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
site, damaged), a stencilled name, a room-type icon, and thin furniture marks. The
lit-diorama shading goes; a room that is on has a soft inner glow instead, and the camera
inset shows what the room looks like.

**Staff tokens.** Each person on base is a small token (role by shape and letter: S
scientist, E engineer, A analyst, later G guard). Unassigned people stand in the corridor
outside Quarters and are also listed in a tray at the bottom of the plan.

**Staff walk (owner decision).** Tokens move along corridors and through doors, never
through walls, and the camera feeds show the same people in the same places.

- *Reassignment:* the person walks from the old room to the new one. The
  assignment itself still takes effect at once in the simulation, as now; the walk is
  presentation. A real walk across the base is about one in-game minute, which is one
  second at 1× and nothing at 10×, so a simulated walk could not be seen anyway. The token
  walks at a readable screen speed that rises with the clock speed, and snaps to its place
  if the player changes tab or level.
- *Life:* at work, people shift between a few spots in their room (desk, console, bench).
  Now and then one walks to another room and back. At night most tokens go to Quarters and
  a few stay on shift. All of it is presentation only, has no effect on output and uses its
  own random stream, so saves and tests are untouched.
- *Arrivals and leavers* walk in from, and out to, the lift.
- *Paused:* everyone stops.

M4c will need real positions for intruders and squads (which room, and how long a move
takes). That is simulated, room by room; the walking between rooms uses the same paths.

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
- **Command:** the cork board is retired for the instrument look (owner: fine if function
  is kept); Finances, Factions and Requests become sub-tabs on the left, with every figure
  and action the tab has now.

## 8. Controls

Q/E and the shoulder buttons cycle tabs; F1 to F7 jump. Sub-tabs cycle with Z/C and the
triggers **(proposal)**. Esc or (B) backs out one step: expanded camera, then placement or
drag, then selection. Existing rebinding and focus rules hold; every drag has a
select-then-place equivalent.

## 9. Out of scope

Incursion rules, squads, doors and room damage (M4c). New game systems of any kind. Final
art for the 3D sets beyond the kit. Main menu, settings and save screens. Mobile or
touch layouts.

## 10. Owner decisions

Settled on 2026-11-13: bible palette with more material and light; tab order and keys;
cork board and lit plan shading retired; gate thumbnail while a wormhole is open; staff
walk.

Also confirmed by the owner (2026-11-14): the walk is presentation only (assignments take
effect at once), and the day and night movement of staff is presentation only.

## 11. Cards

Milestone "M4.5 Interface pass". This document is M4.5-01.

| Card | Title | Depends on |
| --- | --- | --- |
| M4.5-02 | Theme: palette, fonts, bezelled panels, key buttons, lamps, grain | none |
| M4.5-03 | Top bar: funds change, power, gate chip, alert button | 02 |
| M4.5-04 | Alert list and alert kinds | 03 |
| M4.5-05 | Tab bar: seven icon tabs, attention dots, new order and keys | 02 |
| M4.5-06 | Three-column layout: Research and Personnel | 05 |
| M4.5-07 | Command as an instrument tab with sub-tabs | 05 |
| M4.5-08 | Base plan: schematic painter | 02 |
| M4.5-09 | Staff tokens and the unassigned tray | 08 |
| M4.5-10 | Corridor paths and walking tokens | 09 |
| M4.5-11 | Ambient life on the plan | 10 |
| M4.5-12 | Allocation by placing and the Staff sub-tab | 09 |
| M4.5-13 | Camera feed kit: 3D feed widget, shader, three room sets | 02 |
| M4.5-14 | Camera inset and expand on the Base tab | 10, 13 |
| M4.5-15 | Gate Room: 3D Ring view | 13 |
| M4.5-16 | Gate thumbnail in the top bar | 03, 15 |
| M4.5-17 | Flow test, pseudo-localisation pass, playtest guide | all |
