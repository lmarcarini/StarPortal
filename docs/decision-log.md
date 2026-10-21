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
