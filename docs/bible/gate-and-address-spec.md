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
2. **Addresses depend on where you dial from.** An address recorded at another Ring ends in that Ring's origin glyph. If CAIRN's origin glyph was among that address's seven nearest anchors, the coordinates shift too. Converting these is a puzzle type.
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

The player enters an address, the seals engage one by one over two in-game minutes, and the Ring reports one of five outcomes:

| Outcome | Meaning | Energy spent | What the player learns |
| --- | --- | --- | --- |
| No gate | No Ring at those coordinates | 10% of lock energy | The address is wrong |
| Blocked | A Ring exists but is buried, busy or shielded | 25% | A Ring is there: the coordinates are right |
| Origin rejected | The last seal is not this Ring's origin glyph | 25% | Fix the origin; a recorded address needs converting |
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
| Starting storage | One capacitor bank, 400 MWh |

At these values an early dial needs most of a day's spare output to charge. An open wormhole can outrun the plant, which forces the player to shed rooms. Dialing nine seals before the Halvane tap means tapping the national grid, which causes a regional blackout and an Exposure spike. Incoming wormholes cost the dialing side, never CAIRN.

**Seal telemetry**, an early Gate technology, improves No gate results. It reports how many glyphs of the attempt appear in the nearest real address. This gives deduction a hot-or-cold signal without making brute force viable.

## Clue types and reliability

A clue is a set of constraints on an address, wrapped in a source that may be lying; the player's job is to translate the first and judge the second.

| Type | What it constrains | Example | Typical source |
| --- | --- | --- | --- |
| Fragment | Specific glyphs at specific seals | "Seal 2 was the Heron, seal 5 the Anvil" | Dossiers, ruins |
| Pictorial | A glyph described by its picture | "A bird standing on one leg" | Expedition sketches, Kindred songs |
| Sky chart | The set of seven anchors, unordered | A night-sky photo from the target world | MOTH imagery, Halvane gifts |
| Ordinal | Which anchors are nearer | "The Anvil burns closer than the Heron" | Anteri inscriptions |
| Neighbour | Shares most early seals with a known world | "A sister world to Veyl" | Kindred trade records |
| Foreign record | A full address dialed from another Ring | An entry in a captured dial log | Ossar devices, far Rings |
| Cipher | Any of the above, encrypted | An intercepted Ossar order | Signals intelligence |
| Ring memory | CAIRN's own past dials, partly corrupted | The 1961 dial | Ring memory technology |
| Planted | False constraints | A Continuity dossier with one altered seal | Continuity, Ossar disinformation |

A sky chart alone leaves 5,040 orderings; adding ordinal clues narrows it to a handful. Combining types is the heart of the puzzle.

**Reliability.** Every clue has a source, and each of its constraints is secretly true or false. The UI shows an analyst's grade from A to E, which is itself an estimate and can be wrong. Players catch lies three ways:

- **Contradiction.** Applied constraints that leave zero candidates mean something is false.
- **Analyst review.** Costs analyst time and sharpens the grade.
- **Field check.** An expedition confirms or disproves a claim directly.

## Player tools

The tools do the bookkeeping and never the reading: the player turns every clue into constraints by hand, and the tools count what is left.

- **Analysis Board.** A corkboard of clue cards. Each card shows the key excerpt, any image, the source and its grade. The full text lives in the Archive for players who want it. Cards can be linked, tagged by world, and marked as suspect.
- **Address Workbench.** Eight slots, nine and ten once unlocked. The player drags glyphs into slots, rules glyphs out, groups them as an unordered set, or adds an order relation. A counter shows how many addresses still fit, such as "5,040 possible". When one remains, or the player picks one, it goes to the dialing queue.
- **Star Atlas.** A map of identified anchors and known worlds. Sky charts can be plotted on it. The late technology Cartographer lets the player compute an address from a position, turning the hidden math into a tool.
- **Dial Log.** Every attempt, its outcome and its cost. It warns before repeating a failed address.

## Probing the unknown

A lock tells the player nothing about the far side; something must go through first, and what goes through decides what comes back.

| Probe | Cost | Gives |
| --- | --- | --- |
| Sample canister | Cheapest | Air, temperature, radiation. Returns only if the wormhole stays open |
| MOTH drone | Cheap | Piloted flight with a 20 in-game minute battery and the full scan set |
| Rover (mid-game) | Moderate | Hours on the ground, heavier sensors, can be recalled later |
| Nothing | Free | Close the wormhole and keep the address for later |

Flying the MOTH switches to a first-person drone feed: real-time low-poly 3D at 320 × 240 with a camcorder overlay. The player flies it or sets an autopilot scan. While the feed is live, the clock slows to one tick per 6 real seconds, so a full battery gives about 2 real minutes of flight. Scan targets include:

- **The far Ring's console:** reveals that world's origin glyph, which is needed to read its records.
- **The sky:** generates a sky chart clue for neighbouring worlds.
- **Structures, life signs and inscriptions:** feed the World Report and the Codex.

A drone shot down is information too. Every probe ends with a **World Report**: atmosphere, temperature, radiation, life, structures and a threat estimate with a confidence level.

Procedural worlds build their feed scene from a biome kit and props chosen by the world's tags. Story worlds have authored scenes.

## Puzzle tuning rules

These rules are checked by a content tool, so every story address stays fair even when a source lies.

1. **Two paths.** Every story address can be solved from in-game clues by at least two independent routes, so one lie never blocks progress.
2. **Last step by dialing.** Once all true clues for a story address are applied, at most three candidates remain. Dialing to settle the last step is a fair use of power.
3. **Lies are catchable.** Every planted clue contradicts at least one true clue reachable in the same arc.
4. **Math is optional.** No campaign progress requires understanding the hidden address rule.
5. **Brute force fails.** Random dialing must never be a viable strategy at any stage.
6. **Procedural clue sets** are generated with a target difficulty, measured as 1 to 20 candidates left after the true clues.
7. **Difficulty settings** change clue redundancy, analyst hints and the energy cost of failed dials. They never change the address rule.
