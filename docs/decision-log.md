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

## 2026-10-29 — M1.6: the Gate Room is a hybrid view

- **Date:** 2026-10-29 (recorded with M1.6; decided when M1.6 was planned)
- **Decision:** The Gate Room shows the Ring large, as if through the control-room glass, with the dial console below it and panels beside it; an open wormhole's actions come from clicking the portal, never from a modal.
- **Reason:** Playtests of M1.5 found the Gate Room read as a form, not a control room. The Ring is the game's centrepiece and must stay in sight while the player acts on it.
- **Bible section:** [overview.md#locked-decisions](bible/overview.md#locked-decisions) (Presentation), [gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole](bible/gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole)

## 2026-10-29 — M1.6: a lock drops the clock to 1×

- **Date:** 2026-10-29 (recorded with M1.6)
- **Decision:** When a dial resolves into a lock or hostile lock, a clock faster than 1× drops to 1×. 0.5×, pause and holds are left alone, and the player may speed up again.
- **Reason:** At 10× an open wormhole could burn out before the player noticed it. Dropping to 1× gives every lock the player's attention without pausing the game.
- **Bible section:** [game-design.md#time-real-time-with-pause](bible/game-design.md#time-real-time-with-pause)

## 2026-10-29 — M1.6: the pole camera is a player action

- **Date:** 2026-10-29 (recorded with M1.6)
- **Decision:** A lock alone delivers nothing. The player extends the pole camera from the portal's actions; it takes a little sim time and brings back the horizon record and the documents tied to that world, once per world.
- **Reason:** It turns each lock into a beat the player chooses, and makes the documents a reward for acting rather than a side effect of dialing.
- **Bible section:** [game-design.md#base-building-and-power](bible/game-design.md#base-building-and-power) (the pole camera, horizon record)

## 2026-10-29 — M1.6: names are delegated to the product owner

- **Date:** 2026-10-29 (recorded with M1.6)
- **Decision:** The owner delegates in-game names (worlds, documents, UI labels) to the product owner, within the bible's rule of original names; the owner can still overrule any name in review.
- **Reason:** Naming was holding cards up. The product owner sees every card and can keep names consistent.
- **Bible section:** [overview.md#locked-decisions](bible/overview.md#locked-decisions) (Intellectual property)
