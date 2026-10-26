# Presentation and Systems

How the hybrid presentation works screen by screen, the top-down base, the Archive as the
player's database, where documents come from, and the contact system. M2 and M3 cards are
written from it.

Bible: [overview.md#locked-decisions](../bible/overview.md#locked-decisions),
[game-design.md](../bible/game-design.md) (views table, Base building and power, Factions,
requests and politics), [art-and-audio.md](../bible/art-and-audio.md) (pipeline),
[gate-and-address-spec.md](../bible/gate-and-address-spec.md) (dial console, open wormhole,
probing), [lore-and-arcs.md#lore-delivery](../bible/lore-and-arcs.md#lore-delivery).
Status: draft for the owner's approval.

It follows the owner's 2026-10-26 direction. Several bible sections still describe the old
design; section 8 lists every change this document needs.

**Inspirations.**

| Game | We take | We leave |
| --- | --- | --- |
| FTL | One plan for the whole base, rectangular rooms, power pips per room, crew as small figures, doors you seal, crises paused and ordered in the same view | Ship combat, runs, oxygen and fire simulation, per-crew melee |
| Blue Prince | Cross-reading, a notebook the player keeps, the "I noticed that" moment | Room drafting, daily resets |
| Inscryption | Objects in a scene as the interface: you click the phone, not a menu | Meta-narrative tricks, cards |
| Papers, Please | Restricted palettes, stamps, a desk with things on it, blunt type | Inspection as the main loop |

**What "hybrid" means here.** Two kinds of screen share one clock. *Places* are pre-rendered
shots you look at and click things in: the Gate Room through the glass, and the drone feed.
*Instruments* are government equipment: the base plan, the Archive terminal, the Expeditions
board and Command. Places carry the mood and the Ring; instruments carry management. Every
action has exactly one home, and the top bar links to it.

ASCII sketches are drawn at 1280 × 720 on an 80 × 24 character grid: one character is 16 px
wide, one row 30 px tall.

---

## 1. Screen map

| Screen | Key | What it is for | Reached from |
| --- | --- | --- | --- |
| Gate Room | F1 | The Ring, the dial console, the radio, the document tray, incoming wormholes | Top bar, any wormhole alert |
| Base | F2 | Build, power, staff, research labs, incursions | Top bar, any base alert |
| Archive | F3 | Documents, Worlds, Codex, Log | Top bar, the document tray, any link |
| Expeditions | F4 | Plan teams, follow the field timeline, read check-ins | Top bar, Ring "Send team" |
| Command | F5 | Budget, Committee, factions, requests, news | Top bar, the radio, request alerts |
| Drone feed | none | Fly the MOTH and later probes | Ring "Send MOTH"; Expeditions for rovers |

Q and E (gamepad shoulders) cycle the five tabs; F1 to F5 jump (the current build's F2
Archive moves to F3 in M2). The drone feed is a mode, not a tab: it takes the screen below the
top bar, and **Recall** returns to where the player was. Conversations (section 6) open as a
panel over the current screen.

**Always visible: the top bar** (1280 × 40 px), on every screen including the drone feed:

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
+------------------+----------------------------------------+------------------+
| T-1  STILLWATER  |  0h      6h      12h      18h     24h  | CHECK-IN 2  12h  |
| Ldr  Maj. Okafor |  |=transit=|--o-------o--------o---|  | "Village by the  |
| Sci  Dr. Reyes   |            ^check-in  ^now     dial  |  water. Twenty   |
| Sol  Sgt. Brandt |                                       |  adults. They    |
| Spc  Lt. Hale    |  [!] Field decision: villagers wave   |  speak something |
| Loadout: survey  |      the team over. Go / Hold / Leave |  like English."  |
| Posture: cautious|                                       | [Open in Archive]|
+------------------+---------------------------------------+------------------+
| [Plan new expedition]   T-2 in base   T-3 recruiting                         |
+------------------------------------------------------------------------------+
```

*Command.* A cork board in the Papers, Please palette: budget ledger, the three Committee seats,
faction standings, requests as pinned cards, a news column. **Request dossier** lives here.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+-----------------------+-----------------------------+------------------------+
| BUDGET  Mar 1997      | REQUESTS                    | FACTIONS               |
| Allocation  +$12.0M   | [Arm a Kindred village]     | Directorate  +35 ===   |
| Salaries     -$6.1M   |  Kindred  due 18 Mar        | Committee    +20 ==    |
| Upkeep       -$2.4M   |  +20 Kindred  -15 Ossar     | Kindred      +10 =     |
| Month end    +$3.5M   | [Hand over energy weapon]   | Ossar        -5  -     |
|-----------------------|  Committee  due 2 Apr       |------------------------|
| COMMITTEE  review 1 Apr| [Accept] [Decline]         | NEWS                   |
| Adeyemi  Vosk  Marquez|                             | Grid outage in north...|
| Confidence 54  Exp 12 | [Request dossier...]        |                        |
+-----------------------+-----------------------------+------------------------+
```

*Drone feed.* The 320 × 240 feed upscaled to 960 × 720 in the centre, black bars either side
holding the scan list and the probe's state. Only the top bar sits over it.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+-----------+------------------------------------------------------+-----------+
| SCANS     | REC 00:07:41                          SIG ||||.      | BATTERY   |
| [x] Ring  |                                                      |  ####..   |
| [ ] Sky   |              (low-poly world, scanlines)             |  13 min   |
| [ ] Life  |                                                      |           |
| [ ] Insc. |                    [ SCAN: inscription ]             | [AUTOPILOT|
|           |                                                      | [RECALL]  |
+-----------+------------------------------------------------------+-----------+
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
|  window frame                                                                |
|   .------------------------------------------------------------------.      |
|   |           ___________                                    [POLE   |      |
|   |          /  RING     \        blast door                  CAMERA]|      |
|   |         |   (o)       |       [ramp]-----                        |      |
|   |          \___________/                     [CAPACITOR GAUGE]     |      |
|   '------------------------------------------------------------------'      |
|                                                                              |
|  [PHONE /  ]   [====== CONSOLE DESK: dial console ======]   [DOCUMENT  ]     |
|  [ RADIO   ]   [  8 seals, 36-glyph palette, Hold to dial ] [  TRAY (3)]     |
|  [log strip]   [ ADDRESS BOOK binder ]   [DIAL LOG clipboard]                |
+------------------------------------------------------------------------------+
```

**In the shot.** The Ring on its base, the ramp, the blast door to the rest of the level, the
pole camera rig folded beside the Ring, the capacitor gauge on the far wall, and from Arc 1 the
Shutter. Technicians walk the floor as small figures; they leave it during an incoming wormhole.

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
| Pole camera | Push it through an open horizon |
| Log strip (teleprinter) | The last five Log lines |

**The open portal, without a modal.** A lock lights the Ring blue and the clock drops to 1×.
Clicking the Ring (or A with it focused) opens a small action list anchored beside it. The rest
of the screen stays live: console, radio and tray all work. The list closes on a click elsewhere.

```
   .---------------------------.
   | STILLWATER   41:55 left   |
   | drain 20 MW, store 210MWh |
   |---------------------------|
   | Push pole camera   (3 min)|
   | Read far console          |
   | Send canister             |
   | Send MOTH                 |
   | Send team          (M3)   |
   | Hail                      |
   | Close wormhole   [hold]   |
   '---------------------------'
```

Unavailable actions stay listed, greyed, with the reason. **Hail** appears when the World
record shows signs of people (section 6).

**Incoming wormholes.** The klaxon sounds, the room goes red, the technicians clear the floor
and the Ring spins with its seals lighting in an order the player did not choose. The game
auto-pauses. A countdown sits over the Ring (5 in-game minutes). Clicking the Ring offers:
**Close the Shutter** (from Arc 1), **Check identification** (once codes exist), **Let it
open**, and before the Shutter exists, **Post security on the ramp** and **Clear the level**.
If someone is calling through it, the radio lamp lights and **Answer** starts a conversation.
An incoming wormhole's blue is framed in red, so it never looks like the player's own lock.

---

## 3. Top-down base

The base is one plan per level, seen straight down with ceilings removed, drawn as a blueprint
when building and as rendered rooms otherwise. It replaces the side-on cutaway.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+-----+------------------------------------------------------------+-----------+
| S   |  LEVEL 3 (original)                         [Power][Staff] | ROOM      |
| 1   |  +-------+  +----+----+   +---------------+                | Physics   |
| 2   |  |PLANT  |  |LAB |LAB |   |   GATE ROOM   |                | lab       |
|>3<  |  | ###   |==|phys|ling|===|     (Ring)    |                | 3/4 staff |
| +   |  +-------+  +----+----+   |               |                | 4 MW  P2  |
|     |   ||  .  .      ||        +-------[]------+                | Research: |
| LIFT|  +---+ +-----+  ||  +-----+  +----------+                  | Seal tele-|
|     |  |CAP| |CTRL |==++==|ARCH |  | QUARTERS |                  | metry 61% |
|     |  +---+ +-----+      +-----+  +----------+                  |           |
+-----+------------------------------------------------------------+-----------+
| BUILD: Lab  Analysis  Archive  Workshop  Barracks  Quarters ...  | 12 days   |
+------------------------------------------------------------------------------+
```

**Grid.** A cell is a 3 m square, drawn at 24 px at 1280 × 720 (36 px at 1080p), with zoom.
A level is 36 × 20 cells. Rooms are rectangles of whole cells, connected by corridors one cell
wide. Two rooms are neighbours, for adjacency bonuses, when they share at least two cells of
wall.

| Room | Cells (w × h) | Notes |
| --- | --- | --- |
| Gate Room | 8 × 8 | Fixed on Level 3, the deepest original level |
| Control Room | 5 × 3 | Fixed, against the Gate Room's window wall |
| Capacitor Bank | 3 × 2 | The first bank is a fixed alcove off the Gate Room; later banks anywhere |
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
| Lift shaft | 2 × 2 | Same cells on every level it serves |
| Stairs | 2 × 1 | Joins two adjacent levels |

**Levels and lifts.** The surface (the salt works) and Levels 1 to 3 exist at the start; the
column on the left switches level, one at a time. A new level is dug below the deepest for
money, materials and days (bible) and arrives as an empty grid. A lift shaft occupies the same
cells on every level it serves and is the fast way to move squads and equipment; stairs are
cheaper and slower. Travel between levels takes real time, so lift placement matters in an
incursion.

**Building flow.**

1. Pick a room from the build bar; cost, draw, staff slots and build time show.
2. A ghost footprint snaps to cells: green when valid, red with the reason ("Must touch a
   corridor"). R rotates it.
3. **Hold to confirm** pays the money and reserves materials; missing materials are ordered and
   the site waits.
4. A hatched site shows days left. Engineers in its crew slots build it; none, and it stops.
5. Finished, the room needs staff and power. Demolishing refunds half; rooms are never moved.

**Power on the plan.** Power is one base-wide supply; as in FTL, the player lays no cables
and decides priority instead. Each room shows its draw as pips and a priority number (P1 to
P9). The **Power** overlay shows each room as powered (solid), shed (striped, slashed bolt) or
unbuilt (grey). The side panel lists rooms by priority; dragging a row reorders it, and rooms the
next shortfall would shed are striped in advance. An open wormhole's drain sits above P1,
because it is drawn first.

**Staff as dots.** Every person is an 8 px dot, coloured and shaped by role (scientist circle,
engineer square, soldier triangle, medic cross, analyst diamond). Dots walk the corridors on
their shifts. Rooms show staff slots as small squares along one wall. Dragging a dot onto a room
assigns that person; clicking one opens their card. The **Staff** overlay labels dots by name.

**Incursions in the same plan.** No separate screen. The game auto-pauses and the plan goes
alarm-lit. Enemies are red diamonds entering from the Gate Room, visible only where staff or
soldiers can see them; elsewhere a fading marker shows the last sighting. Blast doors sit on
corridor cells; clicking one seals or opens it, with a progress ring. Squads are numbered tags
over their soldiers' dots: drag a tag to a cell or level to move them; **Fall back** sends them
to the nearest sealed door. The Control Room and Power Plant carry a shield icon, because enemies
path to objectives, not to soldiers (bible).

**Research** lives on the plan: clicking a lab shows its project; key R opens the tech tree.

---

## 4. The Archive as a database

The Archive is a terminal: CRT green on off-white, Plex Mono. Four sections share one search
bar and one link system.

```
+------------------------------------------------------------------------------+
| top bar                                                                      |
+------------------------------------------------------------------------------+
| [DOCUMENTS 3] [WORLDS] [CODEX 1] [LOG]      SEARCH: [stillwater________] [x] |
+---------------------------+--------------------------------------------------+
| > Field Note 31      NEW  |  STILLWATER                    status: PROBED   |
|   Horizon record: STILL.  |  Address: [35][10][24][19][29][8][15][2]  [Load] |
|   The two nights          |  First lock 12 Mar 1997, 2 visits               |
|   ---------------------   |  Threat: LOW (confidence: poor)                  |
| WORLDS                    |  Reports: Horizon record 12 Mar | MOTH 14 Mar    |
| > STILLWATER    PROBED    |  Photos:  [frame1] [frame2] [sky]                |
|   MILESTONE     LOCKED    |  Factions: Kindred? (footprints)                 |
| CODEX                     |  Linked: Field Note 31, The two nights           |
|   The horizon record      |  Notes: [ "bare feet by the water" ________ ]   |
+---------------------------+--------------------------------------------------+
```

**Search** covers titles, text, names, notes and Codex at once, grouped by section, plus the
Address Book's glyph filter. It never matches words the player cannot yet read (section 6).
**Cross-links:** any name with a record of its own (world, faction, person, Codex term, glyph)
is a link, with a back stack (Escape, gamepad B). Every record lists what links to it.

**Documents.** Each has a title, kind (note, letter, image, dossier, report, transcript,
record, memo), source, the system that produced it and when, linked worlds and Codex terms,
pages and images, and a translation state if it holds alien words. Filters: kind, source, world,
unread. The M1.5 reader stays (zoom, **Read with…**). Only *reading* a document, not receiving
it, unlocks its Codex facts.

**Worlds.** One record per address the player holds: name, address (**Load** fills the
console), status (the bible's world states), first lock and visits, reports (horizon records,
World Reports, expedition reports), photos, threat with its confidence, factions seen, linked
documents, and the player's notes. Before a lock it shows "world unknown" and its source. The
Address Book becomes a view of this, so addresses live in one store.

**Codex.** Entries of 150 words or fewer (bible): title, category (Ring, worlds, factions,
people, history, technology, language), body, source list. An entry unlocks when the player
reads a document carrying one of its facts; later sources add paragraphs. When sources disagree
the entry is **contested** and shows each version side by side, labelled and linked to its
source. The game never says which is true. Glossary tooltips open the matching entry.

**Log.** Every notable event, one timed line each (dials, documents, staff, construction,
research, standing, requests, check-ins), filtered by Gate, Base, People, Politics, Contact. Each
line links to its subject.

---

## 5. Where documents come from

After the opening, every document is the output of a system the player ran. The opening is the
one exception: Order No. 1 and Pell's sketch are in the tray at the start. Each document's data
names its producing system, and the content validator rejects a document no system produces.

| System | Documents it produces | When |
| --- | --- | --- |
| Pole camera (Gate Room) | Horizon record (frames, air, temperature, radiation); on a world's first push, the story documents keyed to that world | A push at an open wormhole, 3 in-game minutes, one record per lock |
| Far Ring console | Address Book entries; on story worlds, sometimes a console log fragment | **Read far console**, once per world |
| Probes (M3) | World Report, photos (including sky photos), inscription captures | Scans in flight; the report when the run ends |
| Expeditions (M3) | Check-in reports, field notes, recovered documents, oral histories | At check-ins and on return |
| Contact (M3) | Transcripts, re-rendered as translation improves | When a conversation ends |
| Analysts | Memos: a hint, a cross-reference, a source grade (Arc 2) | When an analyst assigned to a document finishes |
| Research labs | Technology reports, artefact notes, translation updates | When a project or artefact state completes |
| Directorate and Committee | Dossiers; review minutes; budget letters | Dossiers when requested from Command (days) or as rewards; the rest on the calendar |
| Factions | Letters, gifts, treaty texts | Requests and standing thresholds |
| Continuity | True and doctored dossiers, pieces of the 1961 file | Requests, black-fund deals, caught lies (Arc 2) |
| Captured records | Ossar dial logs, Dravian intelligence | Incursions, expeditions, trade |
| Infirmary | Staff dream reports (the Murmur, Arc 6) | When a person's state changes |

So M1.5's "documents arrive on a lock" becomes "on the first pole-camera push": a player who
closes at once gets nothing, because looking spends open time. And there is no timed drip: idle,
the tray gets only the Committee's calendar items.

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

Conditions and effects are the typed Resources events already use (`StandingAtLeast`,
`FlagIs`, `ChangeStanding`, `AddClue`), plus `WordKnown`, `OfferRequest` and `AddDocument`. A
choice whose conditions fail is hidden, or greyed with its reason if marked "show locked". The
clock is held during a conversation; its lines' minutes are charged when it ends, so a long
parley at an open wormhole still costs open time and drain.

**Where it happens.**

- **Open wormhole:** **Hail** on the Ring, or a call through an incoming wormhole.
- **Radio:** Earth parties (Committee, Directorate, Continuity, Halcyon) call by phone in plain
  English; factions with a relay or outpost by radio. Waiting calls light the lamp.
- **Expedition:** a contact moment auto-pauses. If the wormhole is open or a check-in is due,
  the player speaks through the team leader; otherwise the leader follows the posture set in
  planning (friendly, cautious, firm) and the transcript arrives at the next check-in.

**Partial translation.** Each alien language is a lexicon; every word has a glyph-script form,
a gloss and reveal conditions. Lines are written with word tokens. An unknown word is drawn in
its language's script, in the faction's accent colour, dotted underline; hovering shows "Unknown
word (Kindred). Heard 3 times" and links to every other occurrence. The player can pencil in a
guess, which the game never checks.

- **Translation level** per language, 0 to 5, rises with linguistics lab work, translation
  research (Life and language branch) and transcripts collected. Some words reveal only from a
  specific source: a Halvane primer, a Kindred volunteer, an inscription.
- **Re-reading.** Transcripts are documents. When a word is revealed, every transcript holding
  it is marked "newly readable" and a Log line names the word; re-reading highlights it. An old
  transcript can turn out to hold a clue, even part of an address.
- **Choices** are in English (the team's linguist speaks), but one that repeats an alien word
  shows it in script: the player may answer what they do not understand.
- **Starting levels.** The Kindred speak a drifted Earth language mixed with words taken from
  the Ossar, so most of their speech is readable at the start and the Ossar words are not. The
  Ossar and Halvane start at 0. The Murmur is never fully translated.

**Standing and requests.** Effects move standing; standing thresholds open and close nodes. A
request offered in conversation shows its deadline, reward and visible ripples, and goes to
Command if accepted; refusing is a choice with its own, usually small, effect. Every
conversation ends as a Log line and a transcript.

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
      effects: ChangeStanding(kindred, +10), AddClue(patrol_date)  -> n4
    c "Close the wormhole."   effects: ChangeStanding(kindred, -5), SetFlag(kindred_snubbed) -> end
n3  line   "Those who took us. If you stand against them, bring iron."
    effects: OfferRequest(arm_the_village)  -> end
n4  line   "Then you are kin. The [▞▟▙] is four nights from this one. Do not be here."  -> end
end effects: AddDocument(transcript_kindred_first_hail)
```

At the start (Kindred level 1) the player sees: *"You came through the old ring. Are you people
of the ▚▞▟?"* and *"The ▙▚▞ come at the ▞▟▙. Close your door before then."*
Choice b is hidden: the player cannot claim to be what they cannot read. Choice a gives
standing and the bible's request "Arm a Kindred village against an Ossar patrol".

Weeks later the linguistics lab reaches Kindred level 2 and reveals ▚▞▟ as "the Buried Ring".
The transcript is marked newly readable. Re-read, it says the Kindred remember Earth's Ring and
its burial, which makes the Codex entry on Earth's Ring contested: the Directorate's file says
the Ring was never used before 1961; the Kindred say their ancestors were taken through it.
On the next hail choice b appears; claiming kinship raises standing more, and the answer
gives the patrol's timing, "four nights from this one", which the player needs to plan the
request.

---

## 7. Open questions for the owner

1. **Hybrid, as defined here** (places plus instruments): right, or should more screens be
   places, such as Command as an office with a desk?
2. **Gate Room camera:** from the Control Room through the glass, or on the Gate Room floor
   with the console as a separate close-up?
3. **Base look:** straight top-down (clearest on a grid) or a slight three-quarter angle?
4. **Power routing:** no cables, priority only. Or conduits the player lays, which an incursion
   can cut?
5. **Excavation:** whole levels (bible), or blocks of cells so the player shapes each level?
6. **Grid numbers:** 3 m cells, 36 × 20 per level, section 3's room sizes, as starting tunables?
7. **Tabs and keys.** Five tabs (Gate Room, Base, Archive, Expeditions, Command), F1 to F5, with
   Research inside the Base. The bible lists six views including Research and Analysis. Agree?
8. **Archive in which milestone?** Worlds and Log could land in M2 (they need nothing from M3);
   Codex and transcripts in M3 with contact. Or all in one card set?
9. **One store for addresses.** The Address Book becomes a view of Worlds plus unplaced
   addresses. Agree?
10. **Pole camera limits.** One record per lock, 3 in-game minutes, and story documents only on
    a world's first push. Should a push cost energy too, or risk something on hostile locks?
11. **Dossiers on request.** Dossiers come when the player asks the Directorate from Command.
    Should asking cost Confidence, time only, or depend on standing with the Directorate?
12. **Conversation clock.** Conversations hold time and charge their minutes at the end. Or
    should they run live at 1×, with the drain ticking while you read?
13. **Guesses.** Players can pencil guesses over unknown words; the game never checks them.
    Keep, or leave note-taking to the Archive's notes?
14. **Names in the example.** "Hearth-keeper" as a Kindred title and "the Buried Ring" as their
    name for Earth's Ring are new. Approve, or rename?

---

## 8. Proposed bible changes

Each is a change this document needs before M2 and M3 cards are written. None is made here.

1. **overview.md, Locked decisions, Presentation:** "Hybrid: pre-rendered places (the Gate
   Room through the Control Room glass) and instrument screens (top-down base plan, Archive,
   Expeditions, Command); real-time low-poly drone feed; Papers, Please-inspired look." Add FTL,
   Blue Prince and Inscryption to the Pitch's inspirations.
2. **game-design.md, Core loop, views table:** five tabs plus the drone feed (section 1);
   Analysis becomes the Archive; Research moves into the Base.
3. **game-design.md, Time:** add "A lock drops the clock to 1× if it was faster."
4. **game-design.md, Base building and power:** the side-on cutaway and "eight room slots"
   become section 3; the automatic first-lock camera becomes the pole camera as a player action.
5. **game-design.md, Threats:** incursions play out in the base plan.
6. **game-design.md, Factions:** add a Contact subsection (section 6); dossiers come on request.
7. **gate-and-address-spec.md:** the wormhole screen (dialing sequence, step 3) becomes the
   Ring's action list, no modal; the horizon record comes from a pole-camera push (opening
   puzzle, probing table); the Address Book becomes a view of Worlds (if question 9 is approved).
8. **art-and-audio.md, Pre-rendered pipeline:** the side camera becomes a top-down camera for
   the base plus one authored Gate Room shot; staff are dots on the plan, full sprites only in
   the Gate Room and cutscenes.
9. **technical-architecture.md:** Data model adds `ConversationDef`, `LanguageDef`, `WordDef`,
    `CodexEntryDef` and a producing-system field on `ClueDef` and `DossierDef`; Narrative replaces
    "a choice is an `EventDef` with options" with `ConversationDef`; the layout's "base cutaway"
    becomes "base plan"; the Content Validator rejects documents no system produces.
10. **roadmap.md, Milestones:** M2 "Base cutaway" becomes "Base plan (top-down)"; M3 adds the
    contact system, partial translation and transcripts; the Archive database is placed per
    question 8.
11. **lore-and-arcs.md, Lore delivery:** add transcripts to the Record layer.
12. **docs/content/m15-puzzles.md** (approved content, not bible): "Delivery in M1.5" changes to
    "on the first pole-camera push"; needs a new card.
