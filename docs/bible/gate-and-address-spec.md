# Gate and Address Spec

## Glyphs and the hidden address math

Every address is real geometry: a player who maps the galaxy can derive addresses, but the campaign never requires it.

- **Anchors.** The home domain has 36 anchor points, each a star cluster at a fixed 3D position. Glyph *i* stands for anchor *i*. Each glyph's artwork is the cluster's shape as seen from Earth's region of space, which is a pictorial hint.
- **Worlds.** Every Ring-bearing world has a 3D position in the same space.
- **Address rule.** From a dialing Ring with origin glyph *o*, take the 35 anchors other than *o*. Sort them by distance from the destination world, nearest first. The first seven are seals 1 to 7; seal 8 is *o*.

```latex
\text{address}(w, o) = \big(\, a_1, a_2, \dots, a_7,\; o \,\big), \quad a_k = \text{the } k\text{-th nearest anchor to } w,\ a_k \neq o
```

Three consequences drive the puzzles:

1. **Neighbours look alike.** Worlds close together share most of their first seals, so "near world X" is a real clue.
2. **Addresses depend on where you dial from.** The player never handles this: the console always fills seal 8 with CAIRN's own mark, and every address the player finds arrives already written for CAIRN. The origin matters only in rare story moments, such as a team dialing home from another Ring.
3. **The space is enormous.** There are 35 × 34 × … × 29, about 3.4 × 10¹⁰, possible 8-seal sequences, and only a few hundred worlds have Rings. Random dialing essentially never locks.

The world generator enforces a minimum spacing so no two worlds share an address. Authored story worlds are placed in the same space, and a content tool checks their addresses stay unique.

## Eight, nine and ten seals

Each extra seal is a new layer of the same rule; the player learns the ninth in Arc 4 and makes the tenth in Arc 7.

| Seals | Structure | Reaches | Unlocked |
| --- | --- | --- | --- |
| 8 | 7 coordinates + origin | Any Ring in the home domain | Prologue |
| 9 | 7 coordinates + domain glyph + origin | A Ring in another domain | Arc 4, "Ninth Seal" |
| 10 | 7 coordinates + domain glyph + Keystone + origin | The one place the Anteri went | Arc 7, "Tenth Seal" |

- **Domain glyph.** Each foreign domain is named by one of the 36 glyphs and has its own 36 anchor positions. The seven coordinates are computed against that domain's anchors. The same glyph therefore means different things in different seal positions, which is why the ninth seal stays hidden so long.
- **Domains in the campaign:** home, Halvane Refuge (Arc 4), and Ossar Cradle (optional, late). Procedural domains are out of scope for launch.
- **Keystone.** A 37th glyph that is on no Ring. It is crafted from anterite in Arc 7 and mounted in a cradle built onto CAIRN's Ring. Only one valid 10-seal address exists.

## Dialing, outcomes and energy

A dial is a bet of stored energy: the capacitors must hold the full lock energy before seal one, and how much comes back depends on how far the dial got.

The player enters an address, the seals engage one by one over two in-game minutes, and the Ring reports one of four outcomes:

| Outcome | Meaning | Energy spent | What the player learns |
| --- | --- | --- | --- |
| No gate | No Ring at those coordinates | 10% of lock energy | The address is wrong |
| Blocked | A Ring exists but is buried, busy or shielded | 25% | A Ring is there: the coordinates are right |
| Lock | Wormhole open | 100%, then the open drain | Nothing yet; probe it |
| Hostile lock | Wormhole open, far side guarded | 100%, then the open drain | The far side may answer, or come through |

**Lock energy** grows with distance and with the number of seals:

```latex
E_{lock} = E_{base} \times \left(1 + \frac{d}{d_{ref}}\right) \times M_{seals}
```

| Tunable | Starting value |
| --- | --- |
| E\_base | 300 MWh |
| d\_ref | 10,000 light years |
| M\_seals | 1 for 8 seals, 25 for 9, 400 for 10 |
| Open drain | 20 MW (8 seals), 200 MW (9), set by the story for 10 |
| Starting plant | Diesel, 30 MW output |
| Starting storage | None. The first capacitor bank (400 MWh) is installed from the Gate Room, taking 6 in-game hours, before the first dial |

At these values an early dial needs most of a day's spare output to charge. An open wormhole can outrun the plant, which forces the player to shed rooms. Dialing nine seals before the Halvane tap means tapping the national grid, which causes a regional blackout and an Exposure spike. Incoming wormholes cost the dialing side, never CAIRN.

**Seal telemetry**, an early Gate technology, improves No gate results. It reports how many glyphs of the attempt appear in the nearest real address. This gives deduction a hot-or-cold signal without making brute force viable.

## Where addresses come from

Every story address comes from a hand-made puzzle: a document or object, usually read together with a second one, that gives the address once understood. The rest of the network opens up by exploring.

| Source | What the player holds | Example |
| --- | --- | --- |
| Field notes and carvings | A written note plus an image or object it describes | Prologue: a 1958 survey note and a rubbing of carvings near the Ring |
| Faction gifts | An object whose design encodes an address | A Halvane tapestry whose border is a star chart |
| Artefacts | Markings on something brought back through the Ring | A tablet whose rim repeats seven glyphs in the order of a ritual it describes |
| Dossiers | Government files about a world, sometimes with a fragment of its address | A Directorate file on a site glimpsed in 1961 |
| Captured records | Another power's own logs | A dial log taken from an Ossar device |
| Ring consoles | The far Ring's log of its recent dials | Scanned by the MOTH on any world reached |

**Field-found addresses.** The \~300 procedural worlds have no puzzles. When the MOTH scans a far Ring's console, it copies two to four nearby addresses into the Address Book, already written for CAIRN. Story puzzles open new regions; consoles fill them in.

**Every clue is true.** Sources can lie about politics, motives or what waits on the far side, but never about an address.

## The opening puzzle

The first address is a tutorial in disguise; the second is the first real puzzle. Full text and solutions: docs/content/m15-puzzles.md (approved 2026-10-23).

- **SILL, the tutorial.** The Gallow Commission's Order No. 1 (1961) says to install the capacitor bank before any attempt, then lists the seven carvings of the sill stone in order; the eighth is the Ring's own mark, which the console sets. Pell's 1958 sketch shows the stone. The one thing to notice is that the order runs down the sketch's columns.
- **LINTEL, the opening puzzle.** Ellery's 1958 survey note and a rubbing of the buried lintel's carvings arrive on SILL's first lock. Neither alone gives the address; read together they do.
- Both worlds are dead, safe and quiet: SILL answers the Prologue's question, "can the Ring be dialed safely?" MILESTONE and STILLWATER follow as puzzles 3 and 4.

On every first lock the pole camera brings back the horizon record, which carries the next puzzle's pieces.

## The dial console

The dial console is where the player builds and dials an address; it replaces the Workbench and the Gate Room's address entry.

- **Palette and slots.** The 36 glyphs sit on a palette; the player drags a glyph to a slot, or clicks it then clicks the slot (gamepad: pick, then place). Seven slots take the address; seal 8 shows CAIRN's mark and cannot be changed.
- **Highlight.** A glyph already placed is highlighted on the palette. There are no other aids: no counters, no rule-outs, no candidate lists.
- **Charge.** The console shows only the stored charge, never what an address needs. If the bank holds too little, the Ring will not turn and the console says so, without numbers. Knowing the cost before dialing is a later upgrade (the lock estimator). The Dial button is a hold-to-confirm.
- **Address Book.** Every address the player has found or dialed, with its source document, the world's name once known, the last outcome and the player's own note. It can be searched by glyphs (pick some glyphs to see the addresses that contain them), by world or by source, and one click loads an address into the slots. Dialing an address that has already failed asks for confirmation.

## The dialing sequence and an open wormhole

Dialing is a short, skippable sequence; an open wormhole then gets its own clear screen.

1. **Sequence.** The Ring turns and the seals light one by one over two in-game minutes. Time is held while it plays (a `cutscene` hold), so nothing else happens. Skipping jumps to the result.
2. **Result.** No gate and Blocked show a short result card with what the player learns. A lock opens the wormhole screen.
3. **Wormhole screen.** It shows the destination, the time left of 60 minutes, the power drain and the actions available now: send a probe (sample canister, MOTH), later a team, or close. It stays on top of the Gate Room until the wormhole closes.
4. **One at a time.** The Ring holds one wormhole. While it is open, the console cannot dial and says why.

## Probing the unknown

A lock tells the player nothing about the far side; something must go through first, and what goes through decides what comes back.

| Probe | Cost | Gives |
| --- | --- | --- |
| Sample canister | Cheapest | Air, temperature, radiation. Returns only if the wormhole stays open |
| MOTH drone | Cheap | Piloted flight with a 20 in-game minute battery and the full scan set |
| Rover (mid-game) | Moderate | Hours on the ground, heavier sensors, can be recalled later |
| Nothing | Free | Close the wormhole and keep the address for later |

Flying the MOTH switches to a first-person drone feed: real-time low-poly 3D at 320 × 240 with a camcorder overlay. The player flies it or sets an autopilot scan. While the feed is live, the clock slows to one tick per 6 real seconds, so a full battery gives about 2 real minutes of flight. Scan targets include:

- **The far Ring's console:** copies its log of recent dials into the Address Book: two to four nearby addresses.
- **The sky:** a photograph for the Archive, which some story puzzles use.
- **Structures, life signs and inscriptions:** feed the World Report and the Codex.

A drone shot down is information too. Every probe ends with a **World Report**: atmosphere, temperature, radiation, life, structures and a threat estimate with a confidence level.

Procedural worlds build their feed scene from a biome kit and props chosen by the world's tags. Story worlds have authored scenes.

## Puzzle design rules

These rules keep every address puzzle fair, varied and readable; the content validator checks the ones a tool can check.

1. **Hand-made and varied.** Every story address has its own puzzle and presentation; no two puzzles in a row use the same trick.
2. **True.** Clues never lie about an address. Lies live in politics, motives and dossiers' claims about the far side.
3. **Read, don't calculate.** Solving means reading, matching and noticing. No progress needs the hidden address math.
4. **Self-contained.** Everything needed is in documents and objects the player holds. A puzzle may need two sources read together, and says where to look when a piece is missing.
5. **Last step by dialing.** A puzzle may leave two or three plausible addresses; dialing to settle it is a fair use of power.
6. **Brute force fails.** Random dialing is never viable (about 3.4 × 10¹⁰ sequences).
7. **Hints.** An analyst can be asked for a nudge; the difficulty setting decides how soon and how direct.
8. **Checked.** The validator confirms each authored puzzle's answer is its world's real address and that every authored address is unique.
