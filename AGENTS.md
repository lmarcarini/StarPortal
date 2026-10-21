# AGENTS.md

Read this first. It is the shared baseline for every implementer and reviewer agent.
The design bible in `docs/bible/` is the source of truth; this file only summarises it.

## 1. The project

FAR SIDE PROTOCOL is a real-time-with-pause base management and deduction game, built in
Godot 4 with statically typed GDScript. You direct Site CAIRN, a secret base built around an
alien ring that opens wormholes to other worlds, and every address must be deduced from clues.

Full pitch: [overview.md#pitch](docs/bible/overview.md#pitch). Locked decisions:
[overview.md#locked-decisions](docs/bible/overview.md#locked-decisions).

## 2. Architecture

Four layers. A layer may depend only on what its row allows.

| Layer | Contains | May depend on |
| --- | --- | --- |
| Content | Custom Resource definitions (`*Def`), balance data | Nothing |
| Simulation | `GameState`, systems, commands, glyph math (`RefCounted`) | Content |
| Services | Save, settings, audio, localisation | Simulation (read only) |
| Presentation | Scenes, views, UI, drone feed, cutscenes | Everything above, through the `EventBus` and the command queue |

Hard rules:

- **The simulation never touches a Node,** scene or `get_tree()`. It can run headless in a test.
- **The UI never mutates state.** It builds a command and submits it.

At runtime only two channels touch the simulation: commands in, events out (`EventBus`).
Details: [technical-architecture.md#architecture-overview](docs/bible/technical-architecture.md#architecture-overview).

## 3. Code standards checklist

Summary only. The full rules win on any doubt:
[technical-architecture.md#code-standards](docs/bible/technical-architecture.md#code-standards).

- [ ] **Everything typed:** members, parameters, return types (including `-> void`), typed
      arrays and dictionaries.
- [ ] **Guard clauses first:** validate and return early; happy path unindented at the bottom.
- [ ] **Functions ≤ 40 lines and ≤ 4 arguments** (targets: 20 lines, 3 arguments; beyond 4,
      pass a typed object).
- [ ] **Files ≤ 400 lines** (target 200); split by responsibility before that.
- [ ] **Pure static functions for rules** and calculations, in `class_name` utility scripts.
      No side effects, no autoloads.
- [ ] **Mutation only in `Command.apply()` and `SimSystem.tick()`.**
- [ ] **Composition over inheritance, one level deep:** an engine class or one abstract base.
      Never a chain.
- [ ] **References by id,** never object reference between entities.
- [ ] **Explicit state machines** for anything with modes; never a set of booleans.
- [ ] **Seeded randomness only:** each system's own `RandomNumberGenerator`; never global
      `randi()` / `randf()`.
- [ ] **Money as integers** (thousands of dollars).
- [ ] **`##` doc comments on public API:** every public class and function.

## 4. Tests and lint

- Tests: `TODO: M0-03`
- Lint and format: `TODO: M0-04`

## 5. Branches, commits and pull requests

- **One card per PR.** One card, one branch, one pull request.
- **Branch:** `card/<issue>-<slug>`, e.g. `card/7-command-queue`.
- **PR body:** says `Closes #<issue>`.
- **Commits:** each change covers one feature, includes its tests, and names the bible section
      it implements.
- **Merge:** squash merge, after review approval.
- **Scope:** only the files in the card's Touches list. Extra work found mid-card is reported,
  not done.

Process details: [roadmap.md#working-process](docs/bible/roadmap.md#working-process).

## 6. Missing context

If you need a file the card does not list, stop and report it to the product owner.
