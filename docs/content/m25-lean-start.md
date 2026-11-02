# M2.5 Lean start: one level, quick building, minimal research

Design for the M2.5 cards. It revises `docs/content/m2-base.md` after the owner's M2 playtest
(2026-11-01): the start had too much, building took too long even at 10×, rooms did not say
what they do (the Archive above all), and energy was too fine-grained. Two changes are already
decided on their own cards: the reserved capacitor alcove goes (#158) and building is one
click, with no hold (#156).

Where this document and `m2-base.md` disagree, this one wins. Everything not mentioned here
(the FTL-style power rules, the energy layer, placement rules, cancelling and demolishing, the
look of the plan) stays as in `m2-base.md`. Choices beyond the owner's feedback are PO
proposals; all numbers are starting values for playtesting.

Units as in M2: money in $k, one tick is one in-game minute, power in MW, energy in MWh.
Real time: **1 game hour = 60 s at 1× and 6 s at 10×**; 1 game day = 24 min at 1×, 2.4 min
at 10×.

---

## 1. Starting base

A new game has **one level, Level 1**, holding the Ring. It is 36 × 20 cells, as before.

| Pre-built on Level 1 | Cells | Draw | Upkeep ($k/month) |
| --- | --- | --- | --- |
| Gate Room (the Ring) | 8 × 8 | 5 MW | 0 |
| Control Room | 5 × 3 | 0 MW | 40 |
| Power Plant (diesel, on) | 5 × 4 | +30 MW | 150 |
| Corridor spine, one row across the level | 36 × 1 | 0 | 0 |

Nothing else is pre-built: no Quarters, no Archive, no lift (there is only one level to
serve). Free space: 720 − 64 − 15 − 20 − 36 = **585 cells**, room for the first bank (3 × 2)
and a Research Lab (4 × 3) many times over, without any reserved site.

- **Starting funds: $6,000k** (was $12,000k). **Monthly allocation: $3,000k** (unchanged).
  **Starting upkeep: $190k a month.**
- **Starting power:** 5 MW used of 30 MW; 25 MW spare.
- **Buildable from the start:** Capacitor Bank, Research Lab, Corridor. Everything else is
  unlocked by research (section 3).

**The opening** stays "build a bank, charge it, dial SILL":

1. The game opens in the Gate Room. The gauge reads "No capacitors installed" and offers
   **Build capacitor bank**, which switches to the Base tab with the bank picked in the
   palette and its ghost following the cursor near the Gate Room.
2. One click on any valid site builds it: **$600k, 1 hour** (60 s at 1×, 6 s at 10×).
3. When it is built the spare **25 MW** charges it by default: SILL's 366.6 MWh takes
   366.6 / 25 = **14.7 hours** (full, 400 MWh, in 16 hours).

The first lock is possible about **15.7 game hours** after the start, against about 20.1 hours
in M2: the same in-game day, and quicker. If the player builds the Research Lab first and
switches it on, charging drops to 20 MW and the lock takes 18.3 hours of charging: still the
same day. After the opening, $5,400k is left: enough for the lab ($800k) and the first two
or three projects.

---

## 2. Levels

Only Level 1 exists at the start. Digging needs research: **Excavation survey** unlocks
Level 2, **Deep excavation** unlocks Levels 3 and 4 (section 3). The grid stays 36 × 20: it
fits the plan at 24 px per cell and gives enough room; nothing in the feedback asks to change
it.

| New level | Unlocked by | Cost ($k) | Time | 1× | 10× |
| --- | --- | --- | --- | --- | --- |
| Level 2 | Excavation survey | 1,500 | 3 days | 72 min | 7.2 min |
| Level 3 | Deep excavation | 2,500 | 4 days | 96 min | 9.6 min |
| Level 4 | Deep excavation | 3,500 | 5 days | 120 min | 12 min |

M2.5 stops at Level 4. As in M2: one dig at a time, it takes no construction slot, it costs
only money and time, and cancelling refunds 50%. New levels go **below** the deepest one, so
the Ring now sits on the top level, not the deepest; the bible line "the Ring sits on the
deepest original level" stays true, since Level 1 is the only original level.

**Reaching a new level.** A dug level arrives empty, with no lift. The player joins it with
Stairs (unlocked with Level 2) or a Lift (its own project). Placement rule 3 is relaxed for
these: stairs or a lift placed from a level above need to touch a corridor on that upper
level only; on the empty level below they become the anchor that corridors join.

---

## 3. Research, minimal

Building a **Research Lab** enables research. With no lab, or with the lab switched off, the
Research view shows the projects but **Start** is greyed: "Needs a Research Lab that is on."

**Projects.** One at a time. Each has a money cost, paid in full when started, and a time in
days. There are no staff, so speed is fixed: a project takes exactly its listed time while
the clock runs and a lab is on. If the lab is switched off or demolished, the project pauses
and keeps its progress. Cancelling refunds 50%. A second lab gives nothing in M2.5 (the
palette says "One lab is enough until staff arrive.").

**Later, with staff:** each lab gets scientist slots, and the listed time becomes the time
for a lab with a standard crew. More, or more skilled, scientists shorten it; an empty lab
works at a slow floor rate. Several labs then run several projects at once, one per lab.

**The M2.5 list** (7 projects):

| # | Project | Needs | Cost ($k) | Days | Unlocks |
| --- | --- | --- | --- | --- | --- |
| R1 | Excavation survey | – | 400 | 2 | Dig Level 2; Stairs |
| R2 | Lift shaft | R1 | 300 | 2 | Lift |
| R3 | Deep excavation | R2 | 800 | 4 | Dig Levels 3 and 4 |
| R4 | Second plant | – | 500 | 3 | Build more diesel Power Plants (+30 MW each) |
| R5 | Fuel contracts | R4 | 300 | 2 | Diesel plant upkeep $150k → $100k a month |
| R6 | Bank array | – | 600 | 3 | Up to 3 Capacitor Banks (was 1) |
| R7 | Field engineering | – | 500 | 3 | Workshop (sites build faster, section 4) |

All seven cost $3,400k and take 19 days back to back: about a month of play, roughly 46 min
of real time at 10×. Days at 10×: 2 days = 4.8 min, 3 days = 7.2 min, 4 days = 9.6 min.

**Not in the list, and why.** Quarters and the Infirmary have no effect without staff; they
**stay locked until staff arrive** (M3) and are not research unlocks yet. The Archive room is
cut (section 4). The workshop's prototype role waits for M4.

**Slots for later** (shown as locked rows at the bottom of the list, "Requires an alien
find", so the tree visibly has room; their names are hidden as "Unknown"):

| Later unlock | Comes from |
| --- | --- |
| Capacitor lattice (much larger banks; the ninth-seal charge) | Alien find (M4) |
| Anterite cell plant | Alien find (M4) |
| Containment and Quarantine | Alien find (M4) |
| Archive room (artefact store) | Alien find (M4) |
| Xenobiology and Linguistics labs | Alien find (M4) |
| Fission plant | Ordinary research, once staff exist (M3 or M4) |
| Quarters, Infirmary | Staff (M3) |

**Where it lives.** A **Research view** inside the Base tab (bible: Research lives inside the
Base). **R**, or a **Research** button at the right end of the power strip, swaps the
864 × 480 plan for the list; R again, Esc or (B) goes back to the plan.

```
+-------------------------------------------------------------+---------------+
| RESEARCH   Current: Excavation survey   1 d 6 h left  [=== ]| SELECTED      |
|-------------------------------------------------------------| Bank array    |
| > Excavation survey      $400k  2 d   Dig L2, Stairs  ACTIVE| $600k  3 days |
|   Lift shaft             $300k  2 d   Lift     needs R1     | Up to 3       |
|   Deep excavation        $800k  4 d   Dig L3-4 needs R2     | Capacitor     |
|   Second plant           $500k  3 d   Plant         [Start] | Banks.        |
|   Fuel contracts         $300k  2 d   Upkeep    needs R4    |               |
|   Bank array             $600k  3 d   3 banks       [Start] | [Start]       |
|   Field engineering      $500k  3 d   Workshop      [Start] |               |
|   Unknown                Requires an alien find      locked |               |
+-------------------------------------------------------------+---------------+
```

Rows are 48 px; eight fit in the 480 px area with the header, and the list scrolls beyond
that. Done projects move to the bottom, ticked. The SELECTED panel shows the project's line
and **Start** (or **Cancel**, refund shown). Starting while another project runs is refused:
"One project at a time." A finished project pauses the game like a finished building and
writes a Log line: "Research done: Bank array. Up to 3 Capacitor Banks."

**Gamepad.** Pressing the left stick (L3) toggles the Research view. The D-pad moves between
rows, A starts or cancels the focused project, B returns to the plan.

---

## 4. Room roles

Rooms offered in M2.5, with the lines for the palette and the SELECTED panel. "Now" replaces
the current `ROOM_*_DESC`; "Later" is shown under it in grey, as "Later: …".

| Room | Now (en) | Later (en) |
| --- | --- | --- |
| Gate Room | The Ring and its dial console. Always on. | Gains the Shutter, telemetry and new seals. |
| Control Room | Runs the Gate Room. Always on. | Commands defence; losing it ends the game. |
| Power Plant | Gives 30 MW while on. Upkeep is fuel. | Upgrades to fission and beyond. |
| Capacitor Bank | Stores 400 MWh for the Ring, charged from spare power. | Larger banks from alien designs. |
| Research Lab | Runs one research project at a time. | Scientists make research faster. |
| Workshop | While on, building sites finish 25% faster. | Builds prototypes and equipment. |
| Stairs | Joins one level to the next. | Squads move between levels. |
| Lift | Joins every level through the same 2 × 2 cells. | Moves squads faster than stairs. |
| Corridor | Connects rooms. One cell. | Blast doors make chokepoints. |

| Room | Agora (pt_BR) | Depois (pt_BR) |
| --- | --- | --- |
| Gate Room | O Anel e seu console de discagem. Sempre ligada. | Ganha o Obturador, telemetria e novos selos. |
| Control Room | Opera a Sala do Portal. Sempre ligada. | Comanda a defesa; perdê-la encerra o jogo. |
| Power Plant | Gera 30 MW enquanto ligada. A manutenção é combustível. | Evolui para fissão e além. |
| Capacitor Bank | Armazena 400 MWh para o Anel, carregado com a energia livre. | Bancos maiores a partir de projetos alienígenas. |
| Research Lab | Conduz um projeto de pesquisa por vez. | Cientistas aceleram a pesquisa. |
| Workshop | Ligada, as obras terminam 25% mais rápido. | Constrói protótipos e equipamentos. |
| Stairs | Liga um nível ao seguinte. | Esquadrões circulam entre os níveis. |
| Lift | Liga todos os níveis pelas mesmas células 2 × 2. | Leva esquadrões mais rápido que a escada. |
| Corridor | Liga as salas. Uma célula. | Portas blindadas criam pontos de estrangulamento. |

**Workshop (PO proposal).** Its one effect: while it is on, every construction site and dig
progresses 25% faster (a 4-hour site takes 3.2 hours). It costs 5 MW, so the player trades
charge rate for build speed: a small, real decision. A second workshop adds nothing.

**Research Lab** replaces the Physics Lab (4 × 3, $800k, 5 MW, $60k a month). It splits into
physics, xenobiology and linguistics labs once staff and alien finds arrive.

**Archive: cut from M2.5 (PO proposal accepted).** The Archive tab (F2) works without it, and
the only role found for it, "+10% research next to the lab", is a 3 × 3 room for a bonus the
player can't feel with one fixed-speed project. It returns in M4 as the artefact store. The
"Lab next to the Archive" adjacency bonus goes with it.

**Locked until staff:** Quarters and Infirmary are removed from the palette.

---

## 5. Build and dig times

| Room | Cells | Cost ($k) | Build time | 1× | 10× | Draw | Upkeep |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Capacitor Bank | 3 × 2 | 600 | 1 h | 60 s | 6 s | charge 0–30 | 10 |
| Corridor | 1 × 1 | 5 per cell | 10 min per cell | 10 s per cell | 1 s per cell | 0 | 0 |
| Stairs | 2 × 1, two levels | 100 | 2 h | 2 min | 12 s | 0 | 0 |
| Lift | 2 × 2, every level | 400 | 4 h | 4 min | 24 s | 0 | 10 |
| Workshop | 5 × 4 | 700 | 6 h | 6 min | 36 s | 5 | 50 |
| Research Lab | 4 × 3 | 800 | 8 h | 8 min | 48 s | 5 | 60 |
| Power Plant | 5 × 4 | 2,000 | 1 day | 24 min | 2.4 min | +30 | 150 (100 after R5) |
| Dig Level 2 / 3 / 4 | 36 × 20 | 1,500 / 2,500 / 3,500 | 3 / 4 / 5 days | 72 / 96 / 120 min | 7.2 / 9.6 / 12 min | 0 | 0 |

In M2 a plant took 10 days and a dig 20: the new times are 4 to 10 times shorter. Demolishing
still takes a quarter of the build time. Up to three sites at once, as before. The Workshop
bonus (section 4) shortens all of these by a fifth.

---

## 6. Energy granularity

The early base read as 2, 1, 1, 4 and 26 MW: too many small numbers.

- **Option A, 5 MW blocks (recommended).** Keep MW, but every draw, output and charge rate is
  a multiple of 5. The plant is 30 MW, shown as 6 segments, not 30. Gate Room 5, Control Room
  0 (folded into the Gate Room), Research Lab 5, Workshop 5, others 0. The bank's charge rate
  steps 0, 5, 10 … 30 with − and +. The starting base reads in whole blocks: 1 used, 5 spare.
- **Option B, abstract power units.** Drop MW from the base: plant 6 units, rooms 1 unit.
  Simpler still, but charging must then convert units to MWh per hour, which hides the link
  between the plant and the capacitors that the Gate Room shows in MWh.

**Recommendation: apply Option A now.** It is only data changes (draws and the meter's
segment size), the catalogue is being re-timed anyway, and every number in this document
already uses it. Finer tuning waits for playtest, as the owner said. Note on the open
wormhole: its 20 MWh/h drain is below the 25 MW default charge, so a wormhole held open from
the start never runs dry; at 20 MW (lab on) it holds level.

---

## 7. Saves

**Clean break, v12.** The starting base, the room catalogue and its ids (Physics Lab becomes
Research Lab, Archive, Quarters and Infirmary leave the palette), the alcove's removal and the
new research state all change what a save holds. Migrating v11 saves would mean rewriting
bases that no longer fit the rules, for testers who can start a new game in a minute. Any
older save is rejected with the existing message: "This save is from an earlier build and
can't be loaded in this one. Start a new game."

The save adds the research state: the active project id and its minutes done, and the set of
finished project ids.

---

## 8. Open questions for the owner

1. **Archive.** Cut the room from M2.5 and bring it back in M4 as the artefact store (PO
   proposal)? Or keep it locked with a small role?
2. **Energy blocks.** Apply 5 MW blocks now (PO recommendation), or keep M2's numbers until
   tuning?
3. **Workshop effect.** Is "sites build 25% faster while on" the right small role, or should
   the Workshop stay locked until prototypes like Quarters and the Infirmary?
4. **Lock estimator.** The bible says the console never states an address's cost until the
   lock estimator is researched. Should it join this list as an eighth project, or wait for
   M4's Gate branch? (PO proposal: wait; the M1.5 puzzles state their charges in the
   documents.)

**Decided here as PO proposals:** one level at start with Gate Room, Control Room and one
diesel plant; $6,000k start; seven projects; the Research Lab replaces the Physics Lab;
Quarters and Infirmary locked until staff; the Ring stays on Level 1 and digs go downward;
save v12.
