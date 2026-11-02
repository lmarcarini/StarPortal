# Presentation and Systems

How the hybrid presentation works screen by screen, the base plan, the Archive as the
player's database, where documents come from, and the contact system. M2 and M3 cards are
written from it.

Bible: [overview.md#locked-decisions](../bible/overview.md#locked-decisions),
[game-design.md](../bible/game-design.md) (views table, Base building and power, Factions,
requests and politics), [art-and-audio.md](../bible/art-and-audio.md) (pipeline),
[gate-and-address-spec.md](../bible/gate-and-address-spec.md) (dial console, open wormhole,
probing), [lore-and-arcs.md#lore-delivery](../bible/lore-and-arcs.md#lore-delivery).
Status: approved by the owner 2026-10-26, with the decisions in section 7.

Several bible sections still describe the old design; section 8 lists the changes needed.

**Inspirations.**

| Game | We take | We leave |
| --- | --- | --- |
| FTL | One plan for the whole base, rectangular rooms, power pips per room, crew as small figures, doors you seal, crises paused and ordered in the same view | Ship combat, runs, oxygen and fire simulation, per-crew melee |
| Blue Prince | Cross-reading, a notebook the player keeps, the "I noticed that" moment | Room drafting, daily resets |
| Inscryption | Objects in a scene as the interface: you click the phone, not a menu | Meta-narrative tricks, cards |
| Papers, Please | Restricted palettes, stamps, a desk with things on it, blunt type | Inspection as the main loop |

**Hybrid (decided 2026-10-26).** *Places* are pre-rendered shots you click things in: the Gate
Room through the glass, and the drone feed. *Instruments* are government equipment: the base
plan, the Archive, Expeditions and Command. Every action has exactly one home.

ASCII sketches are 80 characters wide for 1280 px (16 px a character); rows are not to scale.
Real sizes are given in the text.

---

## 1. Screen map

| Screen | Key | What it is for | Reached from |
| --- | --- | --- | --- |
| Gate Room | F1 | The Ring, the dial console, the radio, the document tray, incoming wormholes | Top bar, any wormhole alert |
| Archive | F2 | Documents, Worlds, Codex, Log | Top bar, the document tray, any link |
| Base | F3 | Build, dig, lay conduits, power, staff, research labs, incursions | Top bar, any base alert |
| Expeditions | F4 | Plan teams, follow the field timeline, read check-ins | Top bar, Ring "Send team" |
| Command | F5 | Budget, Committee, factions, requests, news | Top bar, the radio, request alerts |
| Drone feed | none | Fly the MOTH and later probes | Ring "Send MOTH"; Expeditions for rovers |

Q and E (gamepad shoulders) cycle the five tabs; F1 to F5 jump (F1 Gate Room, F2 Archive,
F3 Base). The drone feed is a mode, not a tab (layout below), and **Recall**
returns to where the player was. Conversations (section 6) open as a
panel over the current screen.

**Always visible: the top bar** (1280 × 40 px), on every screen; during the drone feed it
collapses to a thin strip (below):

```
+------------------------------------------------------------------------------+
|14 Mar 1997 09:42 [||][>][>>][>>>]  $41.2M  PWR 22/30MW 310MWh  !2  > T-1 ok  |
+------------------------------------------------------------------------------+
```

Date, time and speed; budget; power as demand over output plus stored energy (red, with a
shape, when short); the alert stack (`!2`), each alert linking to its screen; and the newest Log
line, which opens Archive, Log. While a wormhole is open, a blue strip replaces the Log line
(**STILLWATER open 42:10, 20 MW**) and returns to the Gate Room when clicked.

**The clock on a lock.** When a lock opens a wormhole, the clock drops to 1× if it was running
faster; a paused clock stays paused. Other events keep their auto-pause rules.

**Layouts.** The Gate Room, Base and Archive are sketched in their sections. The other three:

*Expeditions.* Team and loadout on the left, the field timeline in the middle (transit, events,
check-ins, the dial-home window), the latest check-in report on the right. A field decision
auto-pauses and appears as a card over the timeline.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+------------------+--------------------------------------+--------------------+
| T-1  STILLWATER  | 0h     6h     12h     18h     24h    | CHECK-IN 2  12h    |
| Ldr  Maj. Okafor | |=transit=|--o------o-------o---|    | "Village by the    |
| Sci  Dr. Reyes   |            check-in  now     dial    | water. Twenty      |
| Sol  Sgt. Brandt |                                      | adults. They       |
| Spc  Lt. Hale    | [!] Field decision: villagers wave   | speak something    |
| Loadout: survey  |     the team over. Go / Hold / Leave | like English."     |
| Posture: cautious|                                      | [Open in Archive]  |
+------------------+--------------------------------------+--------------------+
| [Plan new expedition]   T-2 in base   T-3 recruiting                         |
+------------------------------------------------------------------------------+
```

*Command.* A cork board in the Papers, Please palette: budget ledger, the three Committee seats,
faction standings, requests as pinned cards, a news column. There is no dossier request:
dossiers arrive as the player meets new things (section 5).

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+------------------------+----------------------------+------------------------+
| BUDGET  Mar 1997       | REQUESTS (M4)              | FACTIONS               |
| Allocation  +$12.0M    | [Arm a Kindred village]    | Directorate  +35 ===   |
| Salaries     -$6.1M    |  Kindred  due 18 Mar       | Committee    +20 ==    |
| Upkeep       -$2.4M    |  +20 Kindred  -15 Ossar    | Kindred      +10 =     |
| Month end    +$3.5M    | [Hand over energy weapon]  | Ossar        -5  -     |
+------------------------+----------------------------+------------------------+
| COMMITTEE review 1 Apr | [Accept] [Decline]         | NEWS                   |
| Adeyemi  Vosk  Marquez |                            | Grid outage in north   |
| Confidence 54  Exp 12  |                            |                        |
+------------------------+----------------------------+------------------------+
```

*Drone feed (M3).* The 320 × 240 feed is upscaled 3× to 960 × 720 and fills the full height in
the centre; the 160 px bars either side hold the scan list and the controls. The top bar
collapses to a thin strip (about 20 px) drawn over the top of the feed with the clock, speed and
battery only; alerts that need the player auto-pause as usual. The MOTH's **Ring** scan reads
deeper than the Ring action: the far console's older log and its panel inscriptions.

```
+---------+----------------------------------------------------------+---------+
| SCANS   |  14 Mar 09:42  [||][>]          BATTERY 13 min           |         |
|         | -------------------------------------------------------- |         |
| [x] Ring| REC 00:07:41                        SIG ||||.            |         |
| [ ] Sky |                                                          |         |
| [ ] Life|        (low-poly world, scanlines)                       | [AUTO-  |
| [ ] Insc|                                                          | PILOT]  |
|         |           [ SCAN: inscription ]                          |         |
|         |                                                          | [RECALL]|
+---------+----------------------------------------------------------+---------+
```

---

## 2. Gate Room

The Gate Room screen is the view from the Control Room, through its armoured window, down onto
the Gate Room floor. It is one fixed pre-rendered shot with state variants (idle, dialing, open,
incoming, alarm, Shutter closed). The Control Room desk fills the lower third of the frame.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+------------------------------------------------------------------------------+
| window frame                                                                 |
|   .------------------------------------------------------------------.       |
|   |           ___________                                    [POLE   |       |
|   |          /  RING     \        blast door                  CAMERA]|       |
|   |         |   (o)       |       [ramp]-----                        |       |
|   |          \___________/                     [CAPACITOR GAUGE]     |       |
|   '------------------------------------------------------------------'       |
|                                                                              |
| [PHONE /  ]   [===== CONSOLE DESK: dial console =====]   [DOCUMENT  ]        |
| [ RADIO   ]   [ 8 seals, 36-glyph palette, Hold dial ]   [  TRAY (3)]        |
| [log strip]   [ ADDRESS BOOK binder ]  [DIAL LOG clipboard]                  |
+------------------------------------------------------------------------------+
```

**In the shot.** The Ring, the ramp, the blast door, the pole camera rig, the capacitor gauge,
from Arc 1 the Shutter, and technicians as small figures.

**Clickable.**

| Object | Click gives |
| --- | --- |
| The Ring | Its state; when open, its actions (below) |
| Console desk | The M1.5 dial console, in place on the desk |
| Address Book (binder) | The Address Book; **Load** fills the console |
| Dial Log (clipboard) | Every dial and outcome, linked to World records |
| Phone / radio | Waiting and outgoing calls (section 6); a lamp lights when someone is on the line |
| Document tray | Newly produced documents, with a count; opens the newest in the Archive (all are already filed) |
| Capacitor gauge | Stored charge; install or upgrade a bank, as in M1.5 |
| Pole camera | Push it through an open horizon (once per lock; risky on hostile locks) |
| Log strip (teleprinter) | The last five Log lines |

**The open portal, without a modal.** A lock lights the Ring blue and the clock drops to 1×.
Clicking the Ring (or A with it focused) opens a small action list anchored beside it. The rest
of the screen stays live: console, radio and tray all work. The list closes on a click elsewhere.
**Read far console** is a Ring action from now on (as in the M1.5 build); in M3 the MOTH adds a
deeper scan of the same console.

```
   .---------------------------.
   | STILLWATER   41:55 left   |
   | drain 20 MW, store 210MWh |
   |---------------------------|
   | Push pole camera   (5 min)|
   | Read far console          |
   | Send canister      (M3)   |
   | Send MOTH          (M3)   |
   | Send team          (M3)   |
   | Hail                      |
   | Close wormhole   [hold]   |
   '---------------------------'
```

Unavailable actions stay listed, greyed, with the reason. **Hail** appears when the World
record shows signs of people (section 6).

**Incoming wormholes.** Klaxon, red light, the floor clears, the seals light in an order the
player did not choose, and the game auto-pauses. A 5-minute countdown sits over the Ring, which
offers:
**Close the Shutter** (from Arc 1), **Check identification** (once codes exist), **Let it
open**, and before the Shutter exists, **Post security on the ramp** and **Clear the level**.
If someone is calling through it, the radio lamp lights and **Answer** starts a conversation.
An incoming wormhole's blue is framed in red, so it never looks like the player's own lock.

---

## 3. Base plan

> **Superseded in part (owner, 2026-10-31):** the plan is seen **straight top-down** in the
> lit-diorama look (concept B), not at a three-quarter angle, and there are **no conduits**:
> power is an energy layer where each room is switched on or off. The paragraphs on the angle,
> wall faces, conduits, priorities and cut conduits below no longer apply. Rooms, numbers,
> building, digging and the energy layer for M2: [m2-base.md](m2-base.md). The rest of this
> section (grid, room sizes, whole-level digging, staff dots, incursions) stays.

One plan per level, seen from a slight three-quarter angle with ceilings removed: the camera
looks down about 60 degrees from horizontal, so the south wall of each room shows as a thin
strip of wall face and furniture and figures read as objects, while the cell grid stays square
enough to place rooms. It turns to a flat blueprint while building or digging. It replaces the
side-on cutaway. In the sketch, `"""` marks a visible wall face and `~` a power conduit.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+-----+----------------------------------------------------------+-------------+
| S   | LEVEL 3 (original)          [Power][Conduits][Staff]     | ROOM        |
| 1   |  +-------+  +----+----+   +---------------+              | Physics lab |
| 2   |  |PLANT  |  |LAB |LAB |   |   GATE ROOM   |              | 3/4 staff   |
| >3< |  | ###   |~~|phys|ling|~~~|     (Ring)    |              | 4 MW  P2    |
| +   |  +"""""""+  +""""+""""+   |               |              | conduit: ok |
|     |   ~   .  .     ||        +"""""""[]""""""+              | Research:   |
| LIFT|  +---+ +-----+  ||  +-----+  +----------+                | Seal tele-  |
|     |  |CAP|~|CTRL |==++==|ARCH |~~| QUARTERS |                | metry 61%   |
|     |  +"""+ +"""""+      +"""""+  +""""""""""+                |             |
+-----+----------------------------------------------------------+-------------+
| BUILD: Lab Analysis Archive Workshop .. | CONDUIT | DIG LEVEL   | 12 days     |
+------------------------------------------------------------------------------+
```

**Grid.** Starting values, tuned by playtesting. A cell is a 3 m square, 24 px at 1280 × 720,
with zoom; a level is 36 × 20 cells
(864 × 480 px). Rooms are rectangles of cells joined by one-cell corridors; rooms sharing two or
more cells of wall are neighbours for adjacency bonuses.

| Room | Cells (w × h, starting values) | Notes |
| --- | --- | --- |
| Gate Room | 8 × 8 | Fixed on Level 3, the deepest original level |
| Control Room | 5 × 3 | Fixed, against the Gate Room's window wall |
| Capacitor Bank | 3 × 2 | Anywhere on the plan (M2.5: no reserved alcove) |
| Power Plant | 5 × 4 | Tiers upgrade in place, same footprint |
| Lab (physics, xenobiology, linguistics, engineering) | 4 × 3 | |
| Analysis Centre | 4 × 3 | |
| Archive | 3 × 3 | Neighbouring labs research faster (bible) |
| Workshop | 5 × 4 | |
| Barracks | 4 × 3 | |
| Armoury | 2 × 2 | |
| Infirmary | 4 × 3 | |
| Quarters | 3 × 2 | Six beds |
| Mess | 4 × 4 | |
| Containment | 3 × 3 | |
| Quarantine | 4 × 3 | |
| Hangar (late) | 8 × 6 | Surface only |
| Lift shaft, stairs | 2 × 2, 2 × 1 | |

**Levels and lifts.** The surface and Levels 1 to 3 exist at the start; the left column
switches level. A new level is dug whole, below the deepest (bible): **Dig level** in the
build bar shows the cost and days, engineers dig it as one site, and it arrives as an empty
36 × 20 grid. There is no cell-by-cell excavation. A lift shaft
takes the same cells on every level it serves and moves squads fast; stairs are cheaper and
slower, so lift placement matters in an incursion.

**Building flow.**

1. Pick a room from the build bar; cost, draw, staff slots and build time show.
2. A ghost footprint snaps to cells: green when valid, red with the reason ("Must touch a
   corridor"). R rotates it.
3. **Hold to confirm** pays the money and reserves materials; missing materials are ordered and
   the site waits.
4. A hatched site shows days left. Engineers in its crew slots build it; none, and it stops.
5. Finished, the room needs staff and power. Demolishing refunds half; rooms are never moved.

**Power on the plan: conduits.** Power reaches a room only along conduits the player lays.
**Conduit** in the build bar drags a run of conduit along corridor cells (cheap, built in hours
by engineers); a room is connected when a conduit touches one of its cells and runs unbroken back
to a Power Plant or Capacitor Bank. A conduit passes between levels only through a lift shaft or
stairs. The **Conduits** overlay draws every run and marks a cut segment red; the room panel
says "conduit: ok" or "no conduit". Within the connected network, priority still decides who is
shed in a shortfall: each room shows draw pips and a priority (P1 to P9); the **Power** overlay
marks rooms powered (solid) or shed (striped, slashed bolt), and the side panel lists rooms by
priority, reordered by dragging, striping in advance the rooms the next shortfall would shed. An
open wormhole's drain sits above P1. The Gate Room's own feed from the first capacitor alcove is
fixed and cannot be cut, so the player can always close the Ring.

**Staff as dots.** Every person is an 8 px dot, coloured and shaped by role (scientist circle,
engineer square, soldier triangle, medic cross, analyst diamond), walking the corridors. Rooms
show staff slots as small squares. Drag a dot onto a room to assign; click it for their card.

**Incursions in the same plan.** The game auto-pauses and the plan goes alarm-lit. Enemies are
red diamonds from the Gate Room, seen only where staff can see them; elsewhere a fading marker
shows the last sighting. Click a blast door (on a corridor cell) to seal it. Squads are numbered
tags: drag one to a cell or level; **Fall back** sends it to the nearest sealed door. The Control
Room and Power Plant carry a shield icon: enemies path to objectives (bible). Enemies on a
conduit cell can cut it: everything beyond the cut loses power until an engineer repairs the
segment, so a second, separate conduit run to vital rooms is worth its cost.

**Research** lives on the plan: clicking a lab shows its project; key T opens the tech tree.

---

## 4. The Archive as a database

The Archive is a terminal: CRT green on off-white, Plex Mono. Four sections share one search
bar and one link system.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+------------------------------------------------------------------------------+
| [DOCUMENTS 3] [WORLDS] [CODEX 1] [LOG]     SEARCH: [stillwater_______] [x]   |
+---------------------------+--------------------------------------------------+
| > Field Note 31      NEW  | STILLWATER                   status: PROBED      |
|   Horizon record: STILL.  | Address: [35][10][24][19][29][8][15][2] [Load]   |
|   The two nights          | First lock 12 Mar 1997, 2 visits                 |
|   --------------------    | Threat: LOW (confidence: poor)                   |
| WORLDS                    | Reports: Horizon record 12 Mar, MOTH 14 Mar      |
| > STILLWATER    PROBED    | Photos:  [frame1] [frame2] [sky]                 |
|   MILESTONE     LOCKED    | Factions: Kindred? (footprints)                  |
| CODEX                     | Linked: Field Note 31, The two nights            |
|   The horizon record      | Notes: [ "bare feet by the water" ______ ]       |
+---------------------------+--------------------------------------------------+
```

**Search** covers every section at once, plus the glyph filter. It never matches words the
player cannot yet read (section 6).
**Cross-links:** any name with a record of its own (world, faction, person, Codex term, glyph)
is a link, with a back stack (Escape, gamepad B). Every record lists what links to it.

**Documents.** Title, kind (note, letter, image, dossier, report, transcript, record, memo),
source, producing system and time, links, pages and images, translation state. Filters: kind,
source, world, unread. The M1.5 reader stays (zoom, **Read with…**). Reading a document, not
receiving it, unlocks its Codex facts.

**Worlds.** One record per address held: name, address (**Load**), status (the bible's world
states), visits, reports, photos, threat with confidence, factions seen, linked documents, the
player's notes. Before a lock: "world unknown" and its source. The Address Book is a view of
Worlds (owner decision 7): the binder on the console desk lists the same records, plus addresses
held but not yet placed, and **Load** works from either. Addresses live in one store.

**Codex.** Entries of 150 words or fewer (bible): title, category, body, sources. Reading a
document carrying a fact unlocks or extends its entry. When sources disagree the entry is
**contested** and shows each version side by side, linked to its source; the game never says
which is true.

**Log** (shipped in M1.6; M2 adds the filters and links). Every notable event, one timed line
each (dials, documents, staff, construction,
research, standing, requests, check-ins), filtered by Gate, Base, People, Politics, Contact. Each
line links to its subject.

---

## 5. Where documents come from

Every document comes from a system. Most come from something the player did (a push, a scan,
a request, an assignment). The honest exceptions arrive without a player action but still from a
system: the opening pair (Order No. 1 and Pell's sketch, in the tray at the start), dossiers
on first encounters, the Committee's calendar, faction letters at standing changes, and
Infirmary reports. Each
document's data names its producing system, and the validator rejects one that has none.

| System | Documents it produces | When |
| --- | --- | --- |
| Pole camera (Gate Room) | Horizon record (frames, air, temperature, radiation); on a world's first push, the story documents keyed to that world | One push per lock, 5 in-game minutes, at an open wormhole; on hostile locks the camera may be lost (below) |
| Far Ring console | Address Book entries; on story worlds, sometimes a console log fragment | **Read far console** from the Ring, once per world; the MOTH's deeper scan in M3 |
| Probes (M3) | World Report, photos (including sky photos), inscription captures | Scans in flight; the report when the run ends |
| Expeditions (M3) | Check-in reports, field notes, recovered documents, oral histories | At check-ins and on return |
| Contact (M3) | Transcripts, built from the lines reached and choices made | When a conversation ends |
| Analysts | Memos: a hint, a cross-reference, a source grade (Arc 2) | When an analyst assigned to a document finishes |
| Research labs | Technology reports, artefact notes, translation updates | When a project or artefact state completes |
| Directorate and Committee | Dossiers; review minutes; budget letters | A dossier when the player first meets something the Directorate has a file on (a faction, a person, an artefact type, a world named in the 1961 file), arriving with the record that met it; the rest on the calendar. Dossiers are never requested |
| Factions | Letters, gifts, treaty texts | Standing changes (M3); requests and thresholds (M4) |
| Continuity | True and doctored dossiers, pieces of the 1961 file | Requests, black-fund deals, caught lies (Arc 2) |
| Captured records | Ossar dial logs, Dravian intelligence | Incursions, expeditions, trade |
| Infirmary | Staff dream reports (the Murmur, Arc 6) | When a person's state changes |

So M1.5's "on a lock" becomes "on the first pole-camera push": looking spends open time.

**Pole camera risk (PO proposal, needs playtest).** A lock is hostile when the World record's
threat is HIGH or an enemy faction holds the world. On a hostile lock, the push has a 1 in 4
chance (seeded) that something notices the camera: it is dragged through and lost. The horizon
record keeps the frames taken before the loss and ends "(feed lost)", and the far side's
threat confidence rises one step. A replacement rig costs $0.2M and 3 days, and no push is
possible until it is installed. On other locks the push carries no risk.

---

## 6. Contact system (M3)

**Format, as data.** A conversation is a `ConversationDef`, extending the bible's rule that
story is conditions plus effects (an `EventDef` with options is not enough once lines branch).

| Part | Holds |
| --- | --- |
| `ConversationDef` | id, faction, channels it may run on, the language spoken, a start node, its nodes |
| Line node | speaker id, text key, optional voice clip (opening words only, per the voice decision), minutes it takes, next node |
| Choice node | a list of choices. Each choice: text key, conditions, effects, next node |
| Check node | a skill check on the team member present (linguistics, leadership); pass and fail nodes |
| End node | effects applied on ending |

Conditions and effects are typed Resources, as events use. In M3 the conditions are `FlagIs`,
`WordKnown` and `StandingAtLeast`; the effects are `ChangeStanding`, `SetFlag`, `AddDocument`,
`AddAddress` and `UnlockCodexEntry`. A choice whose conditions fail is hidden, or greyed with its
reason if marked "show locked".

**M3 scope.** M3 builds contact on a minimal faction standing: one number per faction, −100 to
+100, which conversations read and change. Nothing else uses it in M3: no thresholds, no
requests, no ripples, no diplomacy. Those stay in M4, which adds `OfferRequest` and the
threshold effects to the same format. Section 8 lists the roadmap change.

**Timing (owner decision 10; may change later).** The clock is not held: a conversation runs
live at 1×, forced down from any faster speed when the panel opens, and the player can still
pause. Open time and stored energy drain while the player reads and chooses. A line's minutes
are how long it takes to say: the next line appears once they have passed in game time. The
60-minute window and the energy drain still apply: when either runs out, the far side is cut
off mid-conversation, the wormhole closes and the transcript ends "(signal lost)". The panel
covers the right third of the screen
and is not modal: tabs, the Archive (to look words up) and **Close wormhole**, which ends the
conversation, stay usable; other commands apply at once, as when paused.

**Where it happens.**

- **Open wormhole:** **Hail** on the Ring, or a call through an incoming wormhole.
- **Radio:** Earth parties (Committee, Directorate, Continuity, Halcyon) call by phone in plain
  English; factions with a relay or outpost by radio. Waiting calls light the lamp.
- **Expedition:** a contact moment auto-pauses. With the wormhole open, the player speaks
  through the team leader; otherwise the leader follows the planned posture (friendly,
  cautious, firm) and the transcript comes at the next check-in.

**Partial translation.** Each alien language is a lexicon; every word has a glyph-script form,
a gloss and reveal conditions. An unknown word is drawn in script, in the faction's accent
colour; hovering shows "Unknown word (Kindred). Heard 3 times" with links to every occurrence.
The player can pencil in a guess, which the game never checks; guesses are kept (owner
decision 11) and shown in pencil wherever the word appears until it is revealed.

- **Translation level** per language, 0 to 5, rises with linguistics lab work, translation
  research (Life and language branch) and transcripts collected. Some words reveal only from a
  specific source: a Halvane primer, a Kindred volunteer, an inscription.
- **Transcripts** are built, not authored: the game records the nodes reached and choices
  made, and renders that path with the current lexicon every time it is read.
- **Re-reading.** When a word is revealed, every transcript holding it is marked "newly
  readable" and a Log line names the word; re-reading highlights it. An old transcript can turn out to hold a clue, even part of an address.
- **Choices** are in English (the team's linguist speaks), but one that repeats an alien word
  shows it in script: the player may answer what they do not understand.
- **Localisation.** A line's text key holds tokens such as `{w:buried_ring}` in both the
  English and pt-BR strings, placed where each grammar needs it. The renderer swaps it for the
  word's glyph-script (the same in every locale) or its gloss, which has its own key
  (`WORD_BURIED_RING`) per table. Glosses are bare words; articles stay in the line. The
  validator checks every locale holds the same tokens.
- **Starting levels.** The Kindred speak a drifted Earth language mixed with words taken from
  the Ossar, so most of their speech is readable at the start and the Ossar words are not. The
  Ossar and Halvane start at 0. The Murmur is never fully translated.

**Standing and requests.** In M3, effects move standing and conditions read it. From M4 a
conversation can also offer a request, which shows its deadline, reward and visible ripples and
goes to Command if accepted. Every conversation ends as a Log line and a transcript.

**Worked example: a first hail with the Kindred.** Arc 1. The player has locked a world where
the MOTH saw cultivated fields, and clicks **Hail**. Unknown words are shown as `[▚▞▟]`.

```
conv_kindred_first_hail   faction: kindred   channels: wormhole   language: kindred
n1  line   speaker: hearth_keeper   minutes: 2
    "You came through the old ring. Are you people of the [▚▞▟ buried-ring]?"
n2  line   speaker: hearth_keeper   minutes: 1
    "The [▙▚▞ keepers] come at the [▞▟▙ dark-moon]. Close your door before then."
c1  choice
    a "We come in peace. Who are the [▙▚▞]?"   effects: ChangeStanding(kindred, +5)  -> n3
    b "Yes. We are people of the [▚▞▟]."   conditions: WordKnown(buried_ring)
      effects: ChangeStanding(kindred, +10), SetFlag(kindred_kin)  -> n4
    c "Close the wormhole."   effects: ChangeStanding(kindred, -5), SetFlag(kindred_snubbed) -> end
n3  line   "Those who took us. If you stand against them, bring iron."
    effects: SetFlag(kindred_asked_for_iron)   (M4 adds OfferRequest(arm_the_village))  -> end
n4  line   "Then you are kin. The [▞▟▙] is four nights from this one. Do not be here."  -> end
(the transcript is recorded automatically when the conversation ends)
```

At the start (Kindred level 1) the player sees: *"You came through the old ring. Are you people
of the ▚▞▟?"* and *"The ▙▚▞ come at the ▞▟▙. Close your door before then."*
Choice b is hidden: the player cannot claim to be what they cannot read. Choice a gives
standing and sets a flag; from M4 it also offers the bible's request "Arm a Kindred village
against an Ossar patrol".

Weeks later the linguistics lab reaches Kindred level 2 and reveals ▚▞▟ as "the Buried Ring".
The transcript is marked newly readable. Re-read, it says the Kindred remember Earth's Ring and
its burial, which makes the Codex entry on Earth's Ring contested: the Directorate's file says
the Ring was never used before 1961; the Kindred say their ancestors were taken through it.
On the next hail choice b appears; claiming kinship raises standing more, and the answer
gives the patrol's timing, "four nights from this one", which the player will need for the
request.

---

## 7. Owner decisions (2026-10-26)

1. **Base look:** a slight three-quarter angle, not straight top-down (section 3).
   *Superseded 2026-10-31: straight top-down, lit diorama (see [m2-base.md](m2-base.md)).*
2. **Power routing:** conduits the player lays; incursions can cut them (section 3).
   *Superseded 2026-10-31: no conduits; an energy layer switches rooms on and off.*
3. **Excavation:** new levels are dug whole (section 3).
4. **Grid numbers:** 3 m cells, 36 × 20 per level and section 3's room sizes are starting
   values, tuned by playtesting.
5. **Tabs and keys:** five tabs, F1 to F5, with Research inside the Base: agreed.
6. **Archive milestones:** Worlds and the Log's filters and links in M2 (the Log itself shipped
   in M1.6); Codex and transcripts in M3.
7. **One store for addresses:** the Address Book is a view of the Archive's Worlds.
8. **Pole camera:** one 5-minute push per lock, with a risk on hostile locks. The concrete risk
   (camera lost, section 5) is a PO proposal.
9. **Dossiers:** created as the player encounters new things; no requesting dossiers from
   Command for now. The request mechanic is removed.
10. **Conversation clock:** conversations run live at 1× for now; the 60-minute window and
    energy drain still apply (section 6). May change later.
11. **Guesses:** keep the player's pencilled guesses over unknown words.
12. **Names:** "hearth-keeper" and "the Buried Ring" approved. From now on the PO decides
    names; the owner may revise them later.

---

## 8. Proposed bible changes

Needed before M2 and M3 cards are written; none is made here.

1. **overview.md, Locked decisions, Presentation:** "Hybrid: pre-rendered places (the Gate
   Room through the Control Room glass) and instrument screens (three-quarter base plan, Archive,
   Expeditions, Command); real-time low-poly drone feed; Papers, Please-inspired look." This
   removes "Not document-based". Add FTL, Blue Prince and Inscryption to the Pitch's
   inspirations.
2. **game-design.md, Core loop:** the views table becomes five tabs plus the drone feed
   (section 1); Analysis becomes the Archive; Research moves into the Base. The "typical in-game
   day" paragraph changes: a dossier arrives when the player first meets something the
   Directorate has a file on, not on a timer; there is no dossier request.
3. **game-design.md, Time:** add "A lock drops the clock to 1× if it was faster. A conversation
   runs live at 1×."
4. **game-design.md, Base building and power:** the side-on cutaway and "eight room slots"
   become section 3 (three-quarter plan, 3 m grid); priority-only power becomes conduits the
   player lays, which incursions can cut; levels are dug whole; the automatic first-lock camera
   becomes the pole camera as a player action, one push per lock, which can be lost on hostile
   locks.
5. **game-design.md, Threats:** incursions play out in the base plan and can cut conduits.
6. **game-design.md, Factions:** add a Contact subsection (section 6); dossiers come from
   first encounters, never on request.
7. **gate-and-address-spec.md:** the wormhole screen (dialing sequence, step 3) becomes the
   Ring's action list, no modal; the horizon record comes from a 5-minute pole-camera push
   (opening puzzle, probing table); the far console is read from the Ring, and the MOTH's
   console scan (Probing, Field-found addresses) becomes a deeper scan in M3; the Address Book
   becomes a view of Worlds.
8. **art-and-audio.md, Pre-rendered pipeline:** the side camera becomes a three-quarter camera
   (about 60 degrees down) for
   the base plus one authored Gate Room shot; staff are dots on the plan, full sprites only in
   the Gate Room and cutscenes.
9. **technical-architecture.md:** Data model adds `ConversationDef`, `LanguageDef`, `WordDef`,
    `CodexEntryDef` and a producing-system field on `ClueDef` and `DossierDef`; Narrative replaces
    "a choice is an `EventDef` with options" with `ConversationDef` and adds the conditions and
    effects of section 6 (`WordKnown`, `SetFlag`, `AddAddress`, `UnlockCodexEntry`); Localisation
    adds word tokens and gloss keys; the layout's "base cutaway" becomes "base plan"; the
    Content Validator rejects documents no system produces and token mismatches between locales.
10. **roadmap.md, Milestones:** M2 "Base cutaway" becomes "Base plan (three-quarter)". M3 adds the
    contact system, partial translation, transcripts and a minimal faction standing (one number
    per faction, −100 to +100, with no thresholds or requests). M4 keeps factions' thresholds,
    requests, ripples and diplomacy, and adds `OfferRequest` to conversations. The Archive
    database splits: Worlds and Log filters in M2, Codex and transcripts in M3.
11. **lore-and-arcs.md, Lore delivery:** add transcripts to the Record layer, and the names
    "hearth-keeper" and "the Buried Ring".
12. **docs/content/m15-puzzles.md** (approved content, not bible): "Delivery in M1.5" changes to
    "on the first pole-camera push"; needs a new card.
