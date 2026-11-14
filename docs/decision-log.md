# Decision log

Every design or technical decision the owner settles is recorded here, newest last.
Change the bible first, then add an entry.

Each entry has four fields:

- **Date:** when the decision was made (YYYY-MM-DD).
- **Decision:** what was decided, in one or two sentences.
- **Reason:** why, including any alternatives that were rejected.
- **Bible section:** the section that records it, as a link into `docs/bible/`.

## 2026-10-21 — Title: Far Side Protocol

- **Date:** 2026-10-21
- **Decision:** The game is titled FAR SIDE PROTOCOL. It replaces the earlier working titles
  ANNULUS and TENTH SEAL.
- **Reason:** ANNULUS was dropped because another game already uses it; TENTH SEAL was dropped
  as too mythical. A full trademark and Steam search is still due before any public page.
- **Bible section:** [overview.md#locked-decisions](bible/overview.md#locked-decisions)

## 2026-10-21 — Godot `.uid` files are committed

- **Date:** 2026-10-21
- **Decision:** The `.uid` files Godot generates beside scripts and other resources are committed
  to the repository, never ignored.
- **Reason:** Godot 4.4 and later reference scripts and resources by UID. Leaving the `.uid`
  files out makes each machine generate its own, which breaks references on every other machine
  and in CI.
- **Bible section:** [technical-architecture.md#project-layout-and-conventions](bible/technical-architecture.md#project-layout-and-conventions)

## 2026-10-21 — Missing settings file is silent; a corrupt one warns

- **Date:** 2026-10-21
- **Decision:** On first run, a missing settings file is silent: the `Settings` service logs
  no warning. A settings file that exists but is corrupt still logs a warning.
- **Reason:** Fresh installs and CI boots must be warning-free, so real problems stand out. A
  missing file is the normal first-run case; a corrupt one is a real fault worth reporting.
- **Bible section:** [technical-architecture.md#errors-and-guard-clauses](bible/technical-architecture.md#errors-and-guard-clauses)

## 2026-10-21 — Every state class validates its saved data

- **Date:** 2026-10-21
- **Decision:** Every runtime state class has a static `validate_dict()` that returns a list of
  errors, and save data is validated with it before `from_dict()` runs.
- **Reason:** Data from outside is validated where it enters, so inner code can trust it. A
  hand-edited or corrupt save then fails cleanly with an error instead of loading wrong values.
- **Bible section:** [technical-architecture.md#data-model](bible/technical-architecture.md#data-model)

## 2026-10-21 — Gamepad A/B bound to accept and cancel by `InputService`

- **Date:** 2026-10-21
- **Decision:** The gamepad A and B buttons are bound to `ui_accept` and `ui_cancel` by
  `InputService` in code, not in `project.godot`.
- **Reason:** Godot's built-in `ui_accept` has no gamepad binding, so menus could not be
  confirmed with a pad. The bindings stay in code, with `InputService`'s other default
  bindings, rather than in `project.godot`.
- **Bible section:** [technical-architecture.md#input-accessibility-and-localisation](bible/technical-architecture.md#input-accessibility-and-localisation)

## 2026-10-21 — CI must be green before review

- **Date:** 2026-10-21
- **Decision:** A pull request is reviewed only once CI is green on its head commit.
- **Reason:** Once CI existed, a pull request that had already been approved failed lint.
  Machines check first, so reviewers spend their time on what machines cannot check.
- **Bible section:** [roadmap.md#rules](bible/roadmap.md#rules)

## 2026-10-21 — Time controls become an explicit state machine

- **Date:** 2026-10-21
- **Decision:** The time controls become an explicit state machine with the states Running,
  Paused and Held, built in milestone M0.5 Hardening.
- **Reason:** Future system holds (cutscenes, forced decisions) must never undo the player's own
  pause, which a set of booleans cannot guarantee. The bible's code standards already require
  an explicit state machine for anything with modes, the time controls included.
- **Bible section:** [technical-architecture.md#state-machines](bible/technical-architecture.md#state-machines)

## 2026-10-22 — Translation tables are one CSV per area

- **Date:** 2026-10-22
- **Decision:** Translation tables are one CSV per area, not one shared file. Each file starts with a real title key.
- **Reason:** Parallel cards edited one CSV and collided, so each area gets its own table. Godot does not
  import a header-only CSV and boot prints errors, so each table starts with one real title
  key.
- **Bible section:** [technical-architecture.md#input-accessibility-and-localisation](bible/technical-architecture.md#input-accessibility-and-localisation)

## 2026-10-22 — Domain events go through a state outbox

- **Date:** 2026-10-22
- **Decision:** Systems put domain events in an outbox kept in the state, and the tick emits them last, one at a time and never nested. Some event names are reserved for the engine.
- **Reason:** Systems and commands cannot touch Nodes, so they need a way to report events. Emitting last
  in the tick matches the bible's fixed tick order. No nesting and reserved names came from
  review: nested emission reordered events, and systems could have faked clock or save
  signals.
- **Bible section:** [technical-architecture.md#simulation-clock-and-commands](bible/technical-architecture.md#simulation-clock-and-commands)

## 2026-10-22 — Floats in saves are exact hex strings

- **Date:** 2026-10-22
- **Decision:** Floats in save files are stored as exact IEEE-754 hex strings instead of JSON numbers.
- **Reason:** Review found that Godot 4.7.2's JSON parser drops digits (1/300 did not round-trip, and -0.0
  lost its sign). Exact hex bits make saves reload bit for bit, so a reloaded game does not
  drift.
- **Bible section:** [technical-architecture.md#save-system](bible/technical-architecture.md#save-system)

## 2026-10-22 — The galaxy is derived, not saved

- **Date:** 2026-10-22
- **Decision:** The galaxy is derived from a seed and a generator version, and is not written into saves.
- **Reason:** Regenerating from the seed keeps saves small and avoids saving the positions of 300 worlds.
  A generator version guards against changes to the generator.
- **Bible section:** [technical-architecture.md#save-system](bible/technical-architecture.md#save-system)

## 2026-10-22 — Gamepad shoulders switch views; triggers change speed

- **Date:** 2026-10-22
- **Decision:** On the gamepad, the shoulder buttons switch views and the triggers change the time speed.
- **Reason:** The shoulders were already bound to time speed, and tabs on the shoulders is the common
  convention, so the shoulders switch views. The triggers then needed edge detection, so each
  pull makes one step.
- **Bible section:** [technical-architecture.md#input-accessibility-and-localisation](bible/technical-architecture.md#input-accessibility-and-localisation)

## 2026-10-22 — Lock energy uses the distance to seal 1's anchor

- **Date:** 2026-10-22
- **Decision:** Lock energy is computed from the distance to the anchor of seal 1.
- **Reason:** The player must know the charge before dialing a guess, and seal 1's anchor exists for any
  address.
- **Bible section:** [gate-and-address-spec.md#dialing-outcomes-and-energy](bible/gate-and-address-spec.md#dialing-outcomes-and-energy)

## 2026-10-22 — M1 starting reach is a single anchor region

- **Date:** 2026-10-22
- **Decision:** The M1 start is a single anchor region, paid for by the 400 MWh starting bank. This is kept for now and revisited when M2 adds capacitor banks.
- **Reason:** The opening scenario found that only anchor 35 is within 400 MWh of CAIRN. The owner kept
  the bible's 400 MWh; M2's banks widen the reach.
- **Bible section:** [gate-and-address-spec.md#dialing-outcomes-and-energy](bible/gate-and-address-spec.md#dialing-outcomes-and-energy)

## 2026-10-23 — Addresses come from hand-made puzzles

- **Date:** 2026-10-23
- **Decision:** After the M1 playtest, every story address comes from a hand-made puzzle. The constraint tools, candidate counter, clue generator and false clues are removed. Procedural worlds are found through addresses on far Ring consoles.
- **Reason:** The owner playtested M1 and wanted less deduction and more discovery, with a unique hand-
  made source for each address, citing Inscryption and Blue Prince. He disliked false clues
  and the constraint helpers.
- **Bible section:** [gate-and-address-spec.md#where-addresses-come-from](bible/gate-and-address-spec.md#where-addresses-come-from)

## 2026-10-23 — The origin glyph is hidden

- **Date:** 2026-10-23
- **Decision:** The origin glyph is hidden from the player: the console fills seal 8 with CAIRN's mark and it cannot be changed.
- **Reason:** The owner did not understand the origin glyph's purpose in the playtest.
- **Bible section:** [gate-and-address-spec.md#glyphs-and-the-hidden-address-math](bible/gate-and-address-spec.md#glyphs-and-the-hidden-address-math)

## 2026-10-23 — The Workbench becomes the dial console

- **Date:** 2026-10-23
- **Decision:** The Workbench becomes the dial console, and the Address Book replaces the dial queue.
- **Reason:** The owner found dragging glyphs the best input and the dropdown entry painful, and wanted
  the Workbench to become the dial itself.
- **Bible section:** [gate-and-address-spec.md#the-dial-console](bible/gate-and-address-spec.md#the-dial-console)

## 2026-10-23 — Dialing is skippable; an open wormhole has its own screen

- **Date:** 2026-10-23
- **Decision:** Dialing is a skippable sequence under a time hold, an open wormhole has its own screen, and the Ring holds one wormhole at a time.
- **Reason:** In the playtest it was not clear what happened after a lock, or whether a drone could be
  sent. The owner asked for a skippable sequence and easier interaction with an open wormhole.
- **Bible section:** [gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole](bible/gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole)

## 2026-10-23 — Design cards for progression, lore and puzzle writing

- **Date:** 2026-10-23
- **Decision:** Progression, lore and puzzle writing get their own `design` cards. The owner approves their output before content cards build on it.
- **Reason:** The owner expects progression, lore and puzzles to need their own cards, apart from code.
- **Bible section:** [roadmap.md#working-process](bible/roadmap.md#working-process)

## 2026-10-24 — Galaxy generator version stays 1 until the first public build

- **Date:** 2026-10-24
- **Decision:** `WorldGenerator.GENERATOR_VERSION` stays 1 until the first public build; pre-release saves are not guaranteed galaxy-stable across content changes.
- **Reason:** Content changes (new authored worlds, anchor edits) change the galaxy a seed gives. Bumping the version for every one before release would only lock testers out of saves nobody has promised to keep; testers start a new game on each build instead.
- **Bible section:** [technical-architecture.md#save-system](bible/technical-architecture.md#save-system)

## 2026-10-26 — M1.6: the Gate Room is a hybrid view

- **Date:** 2026-10-26
- **Decision:** The Gate Room shows the Ring large, as if through the control-room glass, with the dial console below it and panels beside it; an open wormhole's actions come from clicking the portal, never from a modal.
- **Reason:** Playtests of M1.5 found the Gate Room read as a form, not a control room. The Ring is the game's centrepiece and must stay in sight while the player acts on it.
- **Bible section:** [overview.md#locked-decisions](bible/overview.md#locked-decisions) (Presentation), [gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole](bible/gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole)

## 2026-10-26 — M1.6: a lock drops the clock to 1×

- **Date:** 2026-10-26
- **Decision:** When a dial resolves into a lock or hostile lock, a clock faster than 1× drops to 1×. 0.5×, pause and holds are left alone, and the player may speed up again.
- **Reason:** At 10× an open wormhole could burn out before the player noticed it. Dropping to 1× gives every lock the player's attention without pausing the game.
- **Bible section:** [game-design.md#time-real-time-with-pause](bible/game-design.md#time-real-time-with-pause)

## 2026-10-26 — M1.6: the pole camera is a player action

- **Date:** 2026-10-26
- **Decision:** A lock alone delivers nothing. The player extends the pole camera from the portal's actions; it takes a little sim time and brings back the horizon record and the documents tied to that world, once per world.
- **Reason:** It turns each lock into a beat the player chooses, and makes the documents a reward for acting rather than a side effect of dialing.
- **Bible section:** [game-design.md#base-building-and-power](bible/game-design.md#base-building-and-power) (the pole camera, horizon record)

## 2026-10-26 — M1.6: names are delegated to the product owner

- **Date:** 2026-10-26
- **Decision:** The owner delegates in-game names (worlds, documents, UI labels) to the product owner, within the bible's rule of original names; the owner can still overrule any name in review.
- **Reason:** Naming was holding cards up. The product owner sees every card and can keep names consistent.
- **Bible section:** [overview.md#locked-decisions](bible/overview.md#locked-decisions) (Intellectual property)

## 2026-10-31 — M2: FTL-style power; capacitors only for the Ring

- **Date:** 2026-10-31
- **Decision:** Base power is a fixed plant output shared among rooms, each switched on or off; switching on past the supply is refused, so there is no brownout. The capacitors are a separate store used only by the Ring and charged from the supply at a charge rate. Digging and building cost only money and time and draw no power.
- **Reason:** The owner wants power managed simply, like FTL, and kept apart from the portal's energy, so the base needs no micromanagement.
- **Bible section:** [game-design.md#base-building-and-power](bible/game-design.md#base-building-and-power); details in [content/m2-base.md](content/m2-base.md) section 3

## 2026-10-31 — M2: the base plan is a top-down lit diorama, without conduits

- **Date:** 2026-10-31
- **Decision:** The Base tab uses concept B, the lit diorama, seen straight from above. Concepts A (instrument schematic) and C (drafting table) may be used locally, such as on instrument panels, the energy layer and building sites. There are no conduits: power is managed on an energy layer over the plan.
- **Reason:** The owner chose B from the "Base Plan Concepts" mock-ups; conduits added work without adding decisions.
- **Bible section:** [overview.md#locked-decisions](bible/overview.md#locked-decisions) (Presentation); details in [content/m2-base.md](content/m2-base.md) section 6

## 2026-10-31 — M2: underground only, and a clean save break

- **Date:** 2026-10-31
- **Decision:** The base is underground only, Levels 1 to 3 at the start with the Ring on Level 3; there is no surface level for now. M2 does not migrate earlier saves: the save format moves to v11 and any older save is rejected with a message to start a new game.
- **Reason:** A surface level adds nothing to M2's play; migrating M1.6 saves into the new base would cost more than testers starting a new game.
- **Bible section:** [technical-architecture.md#save-system](bible/technical-architecture.md#save-system); details in [content/m2-base.md](content/m2-base.md) sections 2 and 7

## 2026-11-01 — M2: charging continues while a wormhole is open

- **Date:** 2026-11-01
- **Decision:** The banks keep charging at their rates while a wormhole is open; the open wormhole's 20 MWh/h drain is taken from the net flow. At the starting 26 MW the charge out-runs the drain; a wormhole closes on empty capacitors only when the total charge rate is below 20 MW. To be tuned in playtest.
- **Reason:** It keeps the power and Ring rules simple and independent. Whether it makes open wormholes too cheap is a playtest question.
- **Bible section:** [gate-and-address-spec.md#dialing-outcomes-and-energy](bible/gate-and-address-spec.md#dialing-outcomes-and-energy); details in [content/m2-base.md](content/m2-base.md) section 3

## 2026-11-01 — Soak time budget raised to 90 s

- **Date:** 2026-11-01
- **Decision:** The soak test's wall-clock budget is 90 s, a ceiling for slow or shared machines; a normal run takes about 55 s. Making the per-tick power checks faster is a follow-up card.
- **Reason:** At 60 s the soak failed now and then (exit 100) when it shared the CPU with another Godot run, with no fault in the game.
- **Bible section:** [technical-architecture.md#testing-and-tooling](bible/technical-architecture.md#testing-and-tooling)

## 2026-11-01 — M2.5: lean start, research unlocks, 5 MW blocks

- **Date:** 2026-11-01
- **Decision:** A new game starts with one level (the Ring's) holding only the Gate Room, Control Room and one diesel plant, and $6,000k. A Research Lab (replacing the Physics Lab) runs seven projects that unlock digging, stairs and lifts, more plants, cheaper fuel, up to three banks and the Workshop. The Archive room is cut until M4 (artefact store); Quarters and Infirmary stay locked until staff. Build times are 6 to 24 times shorter. Power is counted in whole 5 MW blocks. A room that finishes building switches on by lowering charge rates first and never switches another room off. The Workshop makes sites and digs finish 25% faster while on. The lock estimator waits for M4. Saves move to v12 (clean break).
- **Reason:** M2 playtest: the start offered too much at once, building felt slow even at 10x, room roles were unclear, and power numbers were too fine-grained.
- **Bible section:** [game-design.md#base-building-and-power](bible/game-design.md#base-building-and-power); details in [content/m25-lean-start.md](content/m25-lean-start.md)

## 2026-11-02 — M2.5: Research is its own tab (F4)

- **Date:** 2026-11-02
- **Decision:** Research is a fourth tab, **Research** (F4), after Gate Room, Archive and Base. It is hidden until a Research Lab has finished building and then stays for the rest of the game, even with the lab off or demolished (Start is then greyed: "Needs a Research Lab that is on."). It replaces the planned view swapped into the Base tab with R, L3 or a power-strip button.
- **Reason:** Owner change: research is a place of its own, not a mode of the base plan, and a full-width list reads better than a panel squeezed beside the plan.
- **Bible section:** [game-design.md#research-artefacts-and-transformations](bible/game-design.md#research-artefacts-and-transformations); details in [content/m25-lean-start.md](content/m25-lean-start.md) section 3

## 2026-11-02 — M2.5: refunds are a share of what was paid

- **Date:** 2026-11-02
- **Decision:** Every room remembers what was paid for it (`paid_k` in the save, 0 when missing). Cancelling a site (75%) and demolishing a room (50%) refund a share of that amount, not of the catalogue price.
- **Reason:** M2.5 makes prices vary: a lift segment costs $100k, not the $400k lift, and a lift placed on a shaft from the palette is charged the segment price. Refunding from the catalogue price would pay back more than was spent.
- **Bible section:** [game-design.md#base-building-and-power](bible/game-design.md#base-building-and-power); details in [content/m25-lean-start.md](content/m25-lean-start.md) section 2

## 2026-11-02 — M2.5: lift segments belong to their shaft

- **Date:** 2026-11-02
- **Decision:** A lift segment (the $100k, 1-hour extension started when a dig finishes under a built lift) is its own construction site while it builds: it takes no building slot and can be cancelled alone. Once built it joins its shaft, which is then selected, demolished and refunded as one room on all its levels. Demolishing a shaft also removes its segments still building, at the cancel rate.
- **Reason:** A shaft with a separate finished segment could be demolished in pieces, leaving a lift that joins nothing; one shaft, one room keeps the plan and the refunds simple.
- **Bible section:** [game-design.md#base-building-and-power](bible/game-design.md#base-building-and-power); details in [content/m25-lean-start.md](content/m25-lean-start.md) section 2

## 2026-11-02 — M2.6: staff and money

- **Date:** 2026-11-02
- **Decision:** Staff arrive in M2.6: scientists, engineers and analysts, each with a name, role, skill 1 to 5 and salary ($15k + $5k × skill a month); medics and soldiers wait for M3. A new game starts with five staff and a fixed list of four candidates; a new list is drawn each month (hiring fee one month's salary, arrival 3 to 7 days). Beds cap headcount: 6 at start, +4 per Quarters, which is buildable from the start. Unstaffed rooms work at a floor rate. Research stays one project at a time, with scientists in every lab pooled (speed max(25%, total skill ÷ 6), at most 200%). Plants need no staff and always give their full 30 MW (PO ruling on the owner's "decide on the easier"); engineers affect building and digging only, through the Workshop. Any loss of plant output lowers charging first, newest bank first, before rooms are switched off. Committee Confidence (0 to 100, starting at 50) sets the next allocation, $3,000k × (0.5 + Confidence ÷ 100). Bankruptcy and Confidence 0 only warn for now. The month-end report is a Log entry and a non-blocking message; it does not pause. Personnel is its own tab, F5, available from the start; Command moves to F6. Saves move to v13 (clean break).
- **Reason:** Second half of the roadmap's M2, kept lean in line with the owner's M2 feedback: nothing locks up for lack of staff, and every Confidence change is shown in the month-end report.
- **Bible section:** [game-design.md#personnel-military-and-expeditions](bible/game-design.md#personnel-military-and-expeditions), [game-design.md#resources-and-economy](bible/game-design.md#resources-and-economy); details in [content/m26-staff-and-money.md](content/m26-staff-and-money.md)

## 2026-11-07 — M2.7: everything daily, Command tab

- **Date:** 2026-11-07
- **Decision:** No monthly cycle remains. The allocation is paid daily, $(50 + Confidence)k a day; salaries and upkeep are charged daily (monthly cost ÷ 30, remainder carried); the hiring fee is 30 days' pay. Confidence is kept in tenths and changes at once on each event; it drifts 0.1 a day toward 50 while solvent and loses 0.2 a day in the red, with no idle penalty. The quarterly grant becomes the Committee commendation: $1,000k when Confidence reaches 70 (tested before drift), re-armed below 60. A red warning shows after 7 days in the red. One new candidate arrives every 3 days, list of 4. The month-end report and all monthly code are removed; a Command tab (F6, available from the start) shows funds, daily income and costs, Confidence and its causes at all times, and "Conf." and the funds readout open it. Saves move to v14 (clean break).
- **Reason:** Owner M2.6 playtest feedback: a month is too long even at 10x, and the month-end report was useless; the information should be on a tab available at all times. The owner kept the commendation at 70 and candidates every 3 days.
- **Bible section:** [game-design.md#resources-and-economy](bible/game-design.md#resources-and-economy); details in [content/m27-daily-rhythm.md](content/m27-daily-rhythm.md)

## 2026-11-07 — M3: Beyond the Ring

- **Date:** 2026-11-07
- **Decision:** M3 completes the core loop: dial, probe (sample canister and MOTH drone), read the World Report, plan, send a team of four, check-ins every 24 h, return or rescue, and first contact. The MOTH is a 2D scan screen in M3; the real-time 3D camera feed is a later milestone. A missed check-in pauses the game and opens a 3-day rescue window: dial the world and Signal the team. A rescue is not certain: each member rolls to have survived, by the world's true threat, conditions, injuries and days waited; the deceased leave the roster (Confidence −3 each), and a team with no survivors, or a window that runs out, is lost (−10). Soldiers and medics join the roles; the Directorate lends two soldiers at the unlock. The Infirmary is built from the Base palette when Expeditions unlock. Expeditions is F7. Saves move to v15 (clean break).
- **Reason:** Roadmap M3, shaped for the owner's planned iteration on core mechanics after this milestone. Owner decisions 2026-11-07: 3D feed later; rescue as proposed, but its success depends on what is on the world and some of the team may not survive; Infirmary from the Base tab.
- **Bible section:** [game-design.md#personnel-military-and-expeditions](bible/game-design.md#personnel-military-and-expeditions); details in [content/m3-beyond-the-ring.md](content/m3-beyond-the-ring.md)


## 2026-11-08 — Soak time budget raised to 150 s

- **Date:** 2026-11-08
- **Decision:** The soak test's time ceiling (`BUDGET_MSEC` in tests/soak/test_soak_year.gd) rises from 90 s to 150 s. A normal run now takes about 80 s (88 s wall time with startup) after the M3 probe and expedition systems, and more M3 systems are coming.
- **Reason:** PO ruling on PR #240 (card #229): the old ceiling left about 1 s of headroom. The budget is a ceiling for slow or shared machines, not a target.
- **Bible section:** [technical-architecture.md](bible/technical-architecture.md) (tests); process only.

- **Date:** 2026-11-11
- **Decision:** New phase order from M4: core systems (M4a Factions and contact, M4b Artefacts and technology), then M5 Refinement, M6 Interface, M7 Graphics, M8 Content, M9 Release. Content in M4 is only what is needed to test by hand; pt_BR strings for test content copy the English with an `[EN]` prefix. M3b (puzzle 5, MOORING, K1 to K3) is parked for M8. The open follow-up issues are consolidated in #249.
- **Reason:** Owner, 2026-11-11: earlier milestones mixed content with core functionality.
- **Bible section:** [roadmap.md#milestones](bible/roadmap.md#milestones), [m4-core-systems.md](content/m4-core-systems.md)


## 2026-11-12 — M4 core systems design approved

- **Date:** 2026-11-12
- **Decision:** The M4 core-systems design (factions, conversations, requests, artefacts, modifiers, scalable tech tree, phase order) is approved. Incursions and failure states become a short M4c after M4b. A hostile incoming wormhole sends nothing through in M4. Gate Room holding never goes over capacity: an artefact arriving while holding is full waits at the gate and the player retrieves it when there is room; no Confidence cost.
- **Reason:** Owner review of PR #251 (card #250), section 10 answers.
- **Bible section:** [content/m4-core-systems.md](content/m4-core-systems.md)


## 2026-11-14 — Interface pass: tab order and keys

- **Date:** 2026-11-14
- **Decision:** The seven tabs follow the loop: Gate Room F1, Base F2, Research F3, Personnel F4, Expeditions F5, Archive F6, Command F7. Q/E and the shoulders still cycle and wrap. A player's saved rebinding is kept; only the defaults move. Each tab has a code-drawn icon, lit orange on the current tab, and a dot while something inside needs the player (`GameView.needs_attention()`).
- **Reason:** Owner approval of the interface pass (PR #325, card #324).
- **Bible section:** [content/interface-pass.md](content/interface-pass.md) section 4

## 2026-11-14 — CI runs less often

- **Date:** 2026-11-14
- **Decision:** CI runs only on non-draft pull requests and skips those that change only docs or Markdown; pushes to `main` no longer run it again. The soak moves from every push to `main` to a nightly run (skipped when `main` has no new commits in the last 24 hours) plus a manual trigger.
- **Reason:** Owner request: GitHub Actions minutes were running out before the monthly reset.
- **Bible section:** [technical-architecture.md](technical-architecture.md#testing-and-tooling)


## 2026-11-14 — Advanced rooms are researched before they are offered

- **Date:** 2026-11-14
- **Decision:** The build palette offers only rooms research has unlocked (amended the same day: this covers every room, not only the advanced ones). A greyed room is one that is unlocked but can't be built right now, such as the Capacitor Bank at its cap, and its line says why. The Artefact Vault is no longer unlocked from the start: a new Construction project, Secure storage ($400k, 2 days), unlocks it. Containment keeps its own project.
- **Reason:** Owner request: keep the early palette to what the player can plan for.
- **Bible section:** [content/m4-core-systems.md](content/m4-core-systems.md) sections 5 and 7
