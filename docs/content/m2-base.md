# M2 Base: rooms, energy layer, building and money

Design for the M2 base cards. It follows the owner decisions of 2026-10-31:

- **Look:** concept B, the lit diorama (warm sodium light, bare concrete, furniture visible),
  seen **straight from above**. No tilted camera on the management screen. Concepts A
  (instrument schematic) and C (drafting table) may appear locally, for example on instrument
  panels and documents. Mock-ups: the "Base Plan Concepts" canvas.
- **No conduits.** Power is managed on an **energy layer** over the plan, where each room is
  switched on or off.
- **Power and capacitors are separate** (later decision, same day): "Capacitor energy for the
  portal and the base can be managed separately. The capacitors are used for the portal and are
  charged, while the power is managed in a more simplified manner, like FTL: a fixed output you
  share between rooms. Digging costs only money and time and does not draw energy."

- Still valid: levels are dug whole; a level is 36 × 20 cells of 3 m (starting values, tuned by
  playtesting); five tabs, F1 to F5, with Research inside the Base.

This document wins over the bible and `presentation-and-systems.md` on the base until the bible
is updated. Choices beyond the owner decisions are PO proposals; all numbers are starting
values for playtesting.

Units: money in thousands of dollars ($k, stored as integers, per the code standards). One sim
tick is one in-game minute. Energy in MWh, power in MW.

---

## 1. Room catalogue for M2

Footprints are width × height in cells. "Rotates" means Q or E (or a gamepad shoulder button)
turns the footprint 90 degrees while placing.
Draw is what the room takes while **on**. Upkeep is charged at each month-end; an off room pays
half (section 3).

| Room | Cells | Rotates | Cost ($k) | Build time | Draw (MW) | Upkeep ($k/month) | In M2 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Gate Room | 8 × 8 | Fixed | – | Pre-built | 2 | 0 | The Ring and dial console; always on |
| Control Room | 5 × 3 | Fixed | – | Pre-built | 1 | 40 | Opens the Gate Room view (F1); always on |
| Power Plant (diesel) | 5 × 4 | Yes | 2,000 | 10 days | Gives +30 | 150 (fuel) | Output; tiers come later |
| Capacitor Bank | 3 × 2 | Yes | 600 | 6 hours | 0 to 30 (charging) | 10 | +400 MWh for the Ring |
| Quarters | 3 × 2 | Yes | 150 | 2 days | 0 | 10 | Six beds; placeholder until staff |
| Archive | 3 × 3 | Yes | 300 | 3 days | 1 | 20 | Holds the Archive (F2); see below |
| Physics Lab | 4 × 3 | Yes | 800 | 5 days | 4 | 60 | Placeholder until research |
| Workshop | 5 × 4 | Yes | 700 | 5 days | 5 | 50 | Placeholder until prototypes |
| Infirmary | 4 × 3 | Yes | 500 | 4 days | 2 | 40 | Placeholder until staff |
| Lift | 2 × 2, every level | No | 400 | 4 days | 0 | 10 | Joins all levels |
| Stairs | 2 × 1, two levels | Yes | 100 | 2 days | 0 | 0 | Joins one level to the next |
| Corridor | 1 × 1 per cell | – | 5 per cell | 1 hour per cell | 0 | 0 | Connects rooms |

**What each does in M2:**

- **Gate Room.** Fixed on Level 3 with the Ring. Its 2 MW is the dial rig and lights; dialing
  and the open wormhole take energy only from the capacitors (section 3).
- **Control Room.** Fixed against the Gate Room's window wall. In M2 it only anchors the Gate
  Room view; in M4 losing it is fatal (bible).
- **Power Plant.** Adds 30 MW of output while on. A second plant is allowed. Switching a plant
  off removes its output and halves its fuel upkeep. Tier upgrades (fission and later) are not
  in M2.
- **Capacitor Bank.** Each adds 400 MWh of storage for the Ring. It replaces the M1.5 "Install
  capacitor bank" action. A bank has no on/off switch; instead it has a **charge rate**: the MW
  of output allocated to charging it, 0 to 30 (section 3). Demolishing a bank loses its stored
  energy.
- **Quarters, Physics Lab, Workshop, Infirmary.** Quarters draw nothing (lights only). No effect
  until staff, research and prototypes arrive; the panel says so ("Labs open when research
  does."). They give building choices and power demand.
- **Archive.** The Archive tab (F2) works without it, so no room can break the documents; the
  room holds the adjacency bonus and, later, artefacts.
- **Lift and Stairs.** A lift takes the same 2 × 2 cells on every level;
  stairs join one level to the one below. In M2 they only satisfy the connection rule
  (section 4); speed matters later for squads.
- **Corridor.** One-cell paths; the placement rule needs them.

**Adjacency.** Two rooms are neighbours when they share two or more cells of wall. Only one
bonus in M2, shown but inert until research: **Lab next to the Archive: +10% research speed**.

---

## 2. Starting base

A new game has **Levels 1 to 3**, all underground; there is no surface level for now. The Ring
is on Level 3, the deepest. Every level is 36 × 20 cells. One lift shaft runs from Level 1 to
Level 3, with a corridor spine on each level.

| Level | Pre-built |
| --- | --- |
| Level 1 | Power Plant (diesel, on), two Quarters, corridor, lift |
| Level 2 | Archive, corridor, lift |
| Level 3 | Gate Room with the Ring, Control Room, corridor, lift, and the **capacitor alcove**: a marked 3 × 2 site beside the Gate Room |

Starting draw with everything on: Gate 2 + Control 1 + Archive 1 + Quarters 0 + Lift 0 =
**4 MW** against 30 MW of supply, leaving 26 MW spare. Nothing needs switching off.

**Starting money:** $12,000k. **Monthly allocation:** $3,000k (section 5). Starting upkeep is
$240k per month.

**The opening.** The M1.5 opening (install the first bank, 6 hours) becomes building the first
Capacitor Bank room, and stays one short action that teaches base building:

1. The game opens in the Gate Room. The Capacitors gauge reads "No capacitors installed" and
   offers one button, **Build capacitor bank**, which switches to the Base tab (F3) on
   Level 3, with the alcove highlighted and its ghost footprint already placed and green.
2. **Hold to build** ($600k, 6 hours). The alcove becomes a construction site with hours left.
3. The player resumes the clock. After 6 in-game hours the bank is built and, by default, the
   spare 26 MW is allocated to charging it: 366.6 / 26 = about **14.1 hours** to the 366.6 MWh
   of a lock (400 / 26 = 15.4 hours to full).

The alcove is an ordinary site; the first bank may go anywhere valid, and more banks anywhere
(no conduits). The Gate Room button shows only while no bank exists or is being built.
Future: the button moves onto the base screen, with a tutorial leading there.

---

## 3. Energy layer rules

Power (MW) and capacitor energy (MWh) are separate. Power works like FTL: a fixed supply shared
out between rooms. The capacitors are the Ring's store and are charged from that supply.

**Power.**

```
supply    = sum of outputs of plants that are on and built
allocated = sum of draws of rooms that are on and built
          + sum of the charge rates of all Capacitor Banks
spare     = supply - allocated      (never below zero)
```

- A room is either **powered** (takes its full draw) or **off**. There is nothing in between.
- **Switching on is refused** if it would make allocated exceed supply: "Needs 4 MW; 2 MW
  spare." The same applies to raising a bank's charge rate.
- The Gate Room and Control Room are **always on**. Capacitor Banks, Lifts, Stairs and
  Corridors have no on/off switch (a bank has its charge rate instead).
- Every other room can be switched off, including a Power Plant, except the **last running
  plant**: its switch is locked ("The base's last running plant."). Switching a plant off is
  refused if the remaining supply could not cover what is allocated; the player first switches
  rooms off or lowers charge rates.
- There is no shortfall, no brownout and no auto-pause: allocation can never exceed supply.
- Building sites and digging draw no power.

**Capacitors.**

- Each Capacitor Bank stores up to **400 MWh** and has a **charge rate**: the MW of supply
  allocated to charging it, from 0 to 30 MW. A bank gains its charge rate in MWh per in-game
  hour (per tick, rate / 60 MWh) until full; a full bank keeps its allocation but gains nothing.
- **Default.** When a bank is completed, the spare supply (up to 30 MW) is allocated to it.
  The player changes the rate on the energy layer or the selected-room panel.
- The banks' stored energy is pooled for the Ring.

**The Ring uses only the capacitors.**

- **A lock** takes its cost from the capacitors in one go, as in M1.6. Dialing a wrong address
  still costs part of the charge.
- **An open wormhole** drains the capacitors at **20 MWh per in-game hour**. When they are empty
  the wormhole closes: "Capacitors empty. The wormhole has closed."
- The Ring never draws on the plant's output, and the base's rooms never draw on the
  capacitors.

**Content rule (validator):** the always-on rooms' total draw must be no higher than the
starting supply. Today it is Gate 2 + Control 1 = 3 MW against 30 MW.

**An off room** draws nothing, has no effect (no adjacency bonus, no beds or research later)
and pays **half upkeep**. It goes dark on the plan: the diorama lights inside it go out. Its
staff, later, idle. Switching on or off is instant and free.

**The meter.** An FTL-style power bar, always shown in the Base tab's top strip and in the
energy layer: one segment per MW of supply, filled in blocks for each powered room (labelled
when wide enough) and one block for charging; spare segments are empty. Beside it the
capacitors read `Capacitors 214/400 MWh, full in 7 h`.

---

## 4. Building and digging

**Placement rules.** A room's ghost footprint is green when all hold, red with the first
broken rule as its reason:

1. Inside the level's 36 × 20 grid. ("Outside the level.")
2. No overlap with a room, corridor, site, or the lift shaft. ("Overlaps the Archive.")
3. At least one cell of its edge touches a corridor, lift or stairs cell. ("Must touch a
   corridor.") Corridors must touch a room, corridor, lift or stairs.
4. Enough money for the full cost. ("Needs $800k; you have $650k.")
5. A lift needs its 2 × 2 cells free on every level; the ghost shows the blocking level.

There is no power rule (no conduits) and no rule that a level is reachable from the Gate Room:
the lift is pre-built and corridors join to it.

**Construction.** One click (or A) on a valid ghost pays the full cost and places a hatched site showing time
left. Time passes only while the clock runs. Up to **three sites** build at once; a fourth waits
in a queue shown on the site ("Queued: 2nd"). Sites and digging draw no power. In M2 first half, sites
build at the listed time on their own; when engineers arrive, a site needs them, and the listed
time is for a full crew. Corridors are drag-placed as a run; the run is one site.

**Cancelling and demolishing.**

- **Cancel a site:** refunds 75% of its cost at any point, instantly.
- **Demolish a room:** refunds 50% and takes a quarter of its build time, during which the room
  is off. Rooms are never moved.
- Not allowed: the Gate Room, the Control Room, the last Power Plant, the starting lift, and
  any corridor, lift or stairs whose removal would leave a room touching nothing. The reason
  shows on the button.

**Digging a level.** **Dig level** in the palette shows cost and days. The new level goes below
the deepest and arrives as an empty 36 × 20 grid; the pre-built lift extends into it for free.

| New level | Cost ($k) | Days |
| --- | --- | --- |
| Level 4 | 3,000 | 20 |
| Level 5 | 4,500 | 30 |

M2 allows **two** extra levels (five underground in all). One dig at a time; it does not use a
construction slot. Digging costs only money and time; it draws no power and never pauses.
Cancelling a dig refunds 50%. The Ring stays on Level 3; levels below it are for growth (and,
later, containment far from the Ring).

---

## 5. Money (minimal for M2)

- **Starting budget:** $12,000k.
- **Monthly allocation:** a fixed $3,000k, paid at 00:00 on the first of each in-game month.
- **Upkeep:** each room's monthly upkeep (half when off) is charged at the same moment, as one
  Log line: "Month-end: allocation +$3,000k, upkeep −$240k."
- **Spending:** building, digging. Refunds come back at once.
- **Below zero:** building and digging are blocked ("Not enough money"); upkeep can push the
  balance negative, and the top bar shows it in red. No other consequence in M2.

About $2,760k a month is free for building: a lab and a workshop, or one plant.

**Deferred:** Committee Confidence and the allocation scaled by it; salaries (with staff);
materials and delivery delays (the build cost is all money for now); licences, Halcyon
contracts and black funds; the grid tap; bankruptcy after three negative month-ends; research
costs.

---

## 6. Base plan screen

The Base tab (F3). A 1280 × 720 layout, straight top-down, in the lit-diorama look: concrete
floors, furniture and lights visible inside each room, warm sodium light from the ceiling
fittings, corridors darker. A cell is 24 px, so a level is 864 × 480 px at 1× zoom.

```
+------------------------------------------------------------------------------------+ 0
| top bar: date, clock controls, money $11,400k, Save/Load                     40 px |
| tabs: F1 Gate Room | F2 Archive | F3 Base | F4 ... | F5 ...                   28 px |
| power [GG|C|A|CHARGE 26 MW ........|      ] 30 MW    Capacitors 214/400 MWh    [P] |
+------+-------------------------------------------------------------+---------------+ 96
| L1   |  LEVEL 3                                                    | SELECTED      |
| L2   |  +--------+      +================+                        | Physics Lab   |
| >L3< |  | PLANT? |      |                |   [Q][Q]               | Draw 4 MW  ON |
| L4 ~ |  +--------+      |   GATE ROOM    |                        | Upkeep $60k   |
| (dig)|  ...........##...|    (Ring)      |   +------+             | Next to       |
|      |  :LAB  : |CAP|  |                |   |ARCH  |             | Archive +10%  |
|      |  :site : +---+  +=======[]========+   +------+             | "Labs open    |
|      |  :2d   :  |CONTROL  |....corridor..........|LIFT|           |  when research|
|      |  ........ +---------+                     +----+           |  does."       |
|      |             864 x 480 plan, zoom/pan                         | [Demolish]    |
+------+-------------------------------------------------------------+---------------+ 576
| BUILD  Plant  Capacitor  Quarters  Archive  Lab  Workshop  Infirmary  Lift  Stairs |
|        Corridor  |  DIG LEVEL 4  $3,000k 20 d      ghost: Q/E rotate, click to build |
+------------------------------------------------------------------------------------+ 676
| message: "Capacitor bank built. Charging at 26 MW."                       44 px   |
+------------------------------------------------------------------------------------+ 720
```

- **Level column** (64 px, left): the levels, the current one marked; a level being
  dug shows its days left.
- **Plan** (864 × 480): rooms with their lights on or off; sites hatched in blueprint style
  (concept C locally) with time left; selection outlined.
- **Selected-room panel** (right, 352 px; 64 + 864 + 352 = 1,280): name, draw and on/off
  switch (for a bank: stored MWh and a charge-rate slider, 0 to 30 MW), upkeep, adjacency, status line, Demolish (hold). For a site: time left, Cancel (hold).
- **Build palette** (bottom): each room shows cost, draw and build time on hover or focus.
- **Building is one click** (or A, or Enter) on a valid ghost, with no hold; the ghost stays out
  to place another until Esc, B or a right click. Cancel (hold) and Demolish (hold) keep their hold.
- **Energy layer** (P, or the button at the end of the meter): the plan dims the scenery and
  draws on each room a switch and its MW (`ON 4`, `OFF`); always-on rooms show a lock instead
  of a switch; plants show `+30`; banks show their charge rate (`CHG 26`) with − and + steps.
  Clicking a room toggles it; a refused switch-on shows the MW it needs. The power bar grows
  to label every block. The instrument-panel styling of concept A is used for the switches and
  meter.
- **Messages** (bottom strip): the latest event, also in the Log.

**Keys.** Q and E switch tabs (F1 Gate Room, F2 Archive, F3 Base), except while placing a
room, when they rotate it. P toggles the energy layer. Esc on the plan cancels placing; with
nothing to cancel it moves focus to the build palette. The debug overlay is on F12 only.

**Gamepad.** The shoulder buttons switch tabs, except while placing a room, when they rotate
it; the triggers keep time speed. The D-pad moves a cell cursor, the left stick pans, the right
stick zooms; Y and X change level; A selects the room under the cursor (toggles it on the
energy layer; on a bank, left and right on the D-pad change its charge rate); the view button toggles the energy layer; the menu button focuses the build
palette, where A picks a room, the ghost follows the cursor, A builds and B cancels. On the
plan with nothing to cancel, B focuses the build palette.

---

## 7. Saves: clean break

Owner decision: M2 does not migrate M1.6 saves. The save format moves to v11 and any older
save is rejected on load with a clear message: "This save is from an earlier build and can't
be loaded in this one. Start a new game." Nothing from an old save is carried over.

---

## 8. Owner decisions (2026-10-31)

1. **Opening.** "Build capacitor bank" in the Gate Room stays as one of the first actions, to
   teach base building (section 2). Future: it moves onto the base screen, with a tutorial
   leading the player there.
2. **No power micromanagement.** The starting rooms are tuned to draw 4 MW with everything on,
   so nothing needs switching off; the spare 26 MW charges the first bank by default, so the
   first lock is ready about 14.1 hours after the bank is built.
3. **Power and capacitors separate.** Power is a fixed FTL-style supply shared between rooms
   and charging; a room is on or off and switching on is refused past supply, so there is no
   brownout. The capacitors serve only the Ring. Digging draws no power (section 3).
4. **Saves.** Clean break: no M1.6 migration (section 7).
5. **Underground only.** No surface level for now; the base is Levels 1 to 3 with the Ring on
   Level 3, and plants and quarters are built underground.
