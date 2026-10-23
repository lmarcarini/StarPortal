# Roadmap

## Milestones

The Ring is built first, because if finding and dialing an address is not fun, nothing else matters. Everything after that is built around it.

| Milestone | Builds | Done when |
| --- | --- | --- |
| M0 Foundations | Project setup, layers, `SimClock`, `EventBus`, `Registry`, save skeleton, input actions and remapping, CI | An empty game ticks, saves, loads and passes tests headless |
| M0.5 Hardening | Time controls as an explicit state machine (Running, Paused, Held), save and state robustness, CI hardening, housekeeping from M0 reviews | System holds never override the player's pause; old saves migrate to the new format; CI and soak stay green |
| M1 The Ring | Address rule, world generator, Workbench, Analysis Board, dialing, outcomes, energy | A tester deduces three addresses from clues alone, using placeholder art |
| M1.5 The Ring, revised | After the M1 playtest: the dial console with drag-and-drop and the Address Book, the skippable dialing sequence and the wormhole screen, hand-made documents and the opening puzzle, Ring-console addresses; the constraint tools, candidate counter, clue generator and false clues are removed | A first-time player solves the opening puzzle from the note and the rubbing alone, dials it, and knows what to do with the open wormhole |
| M2 The Base | Base cutaway, rooms, power and priorities, staff, budget, time controls | A 30-day run balances power and money with real trade-offs |
| M3 Beyond the Ring | Probes, drone feed, World Reports, expeditions, check-ins | A full dial, probe, expedition and return loop works |
| M4 Consequences | Research, artefacts, tech tree, factions, requests, incursions, failure states | Every failure state can be triggered and every transformation completed |
| M5 Vertical slice | Prologue and Arc 1, full gamepad play, core accessibility options, Claude-generated Blender art for a few rooms | A new player finishes Arc 1 and wants to continue |
| M6 Middle arcs | Arcs 2 to 4, Continuity, the Ossar, nine seals | Each arc's rule change and setback works |
| M7 Late arcs | Arcs 5 to 7, the Murmur, the Keystone, endings | The campaign can be finished, with every ending reachable |
| M8 Release | Balance, final art, audio, Brazilian Portuguese, full accessibility pass, performance, sandbox mode, Steam build if the game earns it | Meets the performance targets and passes a full playthrough |

## Working process

Milestones set the order of work; cards are how a milestone gets built. Each agent sees as little as possible: one card, one shared baseline file, and the files the card names.

### Roles

| Role | Does | Reads | Never |
| --- | --- | --- | --- |
| Owner | Approves milestone plans, decides design, playtests each milestone, settles escalated cards | Anything | — |
| Product owner agent | Breaks a milestone into cards, sets dependencies, releases cards to Ready, keeps work-in-progress limits, turns findings into new cards, routes questions to the owner | The bible, the board, the decision log | Writes code or changes the bible |
| Implementer agent | Builds one card on its own branch and opens a pull request | The card, `AGENTS.md`, the files the card lists | Works outside the card's scope |
| Reviewer agent | Checks the pull request against the card's acceptance criteria and the code standards | The card, `AGENTS.md`, the diff | Sees the implementer's reasoning or writes the fix itself |
| CI | Runs tests, `gdformat`, `gdlint` and the content validator | The repository | — |

### Milestone cycle

1. **Plan.** The product owner agent turns the milestone into cards: the bible sections it implements, the card list, dependencies and open questions. The owner approves the plan.
2. **Build.** Cards move across the board, one implementer per card, reviewed card by card.
3. **Review.** When the last card merges, Claude delivers a playable build, a test report and a list of deviations from the bible. The owner plays it and comments.
4. **Decide.** Design changes go into this bible first, then into new cards. Decisions are recorded in `docs/decision-log.md`.

The owner's calls are final on feel, story and scope. Agents flag risks and propose options, but never change a locked decision.

### The board

The board is a GitHub Project over GitHub Issues. Each card is an issue; dependencies use GitHub's "blocked by" links; each pull request closes its card.

| Column | Meaning | Who moves cards in |
| --- | --- | --- |
| Backlog | Written, waiting on dependencies | Product owner |
| Ready | Every blocking card is Done | Product owner |
| In progress | An implementer owns it | Implementer |
| In review | CI is green and a pull request is open | Implementer |
| Changes requested | The reviewer asked for changes | Reviewer |
| Done | Approved, merged, dependents checked | Product owner |
| Needs owner | Blocked on a decision, or failed review three times | Anyone |

*Diagram (see the live design doc): card lifecycle · 5 forward steps, 2 side exits*

### Rules

- **Ready means unblocked.** A card enters Ready only when every card it depends on is merged.
- **One card, one branch, one pull request.** Branches are named `card/<issue>-<slug>`; the pull request says `Closes #<issue>`.
- **Machines before people.** Review starts only after CI passes.
- **Three rounds.** After a third request for changes, the card moves to Needs owner instead of a fourth round.
- **Squash merge** after approval. The product owner then marks the card Done and releases any newly unblocked cards.
- **No scope creep.** Extra work found mid-card is reported to the product owner, who writes a new card.
- **A card that needs more context is a broken card.** If an implementer must read files the card doesn't list, the card goes back to the product owner to be fixed.
- **Contracts first.** Shared interfaces (classes, signals, data definitions) get their own cards and merge before the features that use them.
- **No file collisions.** Cards whose Touches lists overlap never run at the same time. At most three cards are in progress at once.
- **Card size.** Small or medium only; anything larger is split.

### The shared baseline

`AGENTS.md` at the repository root is the context every agent gets. It stays under two pages: the architecture rules, the code standards checklist, how to run tests and lint, and the branch and pull request conventions. The bible is exported to `docs/bible/` as Markdown, one file per tab, so cards can link to exact sections. The product owner agent regenerates both whenever the bible changes.

### Card template

```markdown
## Goal
One sentence: what exists when this card is done.

## Bible
- docs/bible/technical-architecture.md#simulation-clock-and-commands

## Depends on
#12, #14

## Touches
- src/core/sim_clock.gd (new)
- tests/core/test_sim_clock.gd (new)

## Interfaces
Provides: the exact class names, signatures and signals other cards will use.
Uses: the existing interfaces this card calls.

## Acceptance criteria
- [ ] Each one is testable and checked by a test or by CI.

## Out of scope
What a reasonable implementer might be tempted to add, and must not.

## Notes for the reviewer
What to look at closely.
```

Every card carries three labels: its milestone (`M0` to `M8`), its type (`contract`, `feature`, `tooling`, `content`, `test`) and its size (`S` or `M`).

## M0 cards

M0 Foundations breaks into 15 cards. After the contracts card (M0-05) merges, four cards can run in parallel, so the critical path is six cards long.

| Card | Goal | Type, size | Depends on |
| --- | --- | --- | --- |
| M0-01 Project scaffold | Godot project with the pinned version, Compatibility renderer, folder layout, display settings, type warnings as errors, `.gitignore` and `.gitattributes` | tooling, S | — |
| M0-02 Baseline and bible export | `AGENTS.md`, the bible exported to `docs/bible/`, an empty `docs/decision-log.md` | tooling, S | — |
| M0-03 Test harness | gdUnit4 installed, one sample test, a headless test command | tooling, S | M0-01 |
| M0-04 CI pipeline | GitHub Actions: headless import, `gdformat --check`, `gdlint`, tests on every push and pull request | tooling, S | M0-03 |
| M0-05 Core contracts | Abstract `Command`, `CommandResult`, `Result`, `SimSystem` (`tick`, `on_day`, `on_month`); `GameState` skeleton with `to_dict`/`from_dict`; `EventBus` autoload with its first signals; Simulation, TimeMath and empty stubs for every other autoload | contract, M | M0-03 |
| M0-06 SimClock | Fixed-step accumulator, speeds 0.5× to 10×, pause, tick cap per frame, day and month hooks, `pause_requested` handling, drone-feed slow mode | feature, M | M0-05 |
| M0-07 Command queue | Queue that validates then applies, applies at once while paused, serialises a replayable command log | feature, M | M0-05 |
| M0-08 Seeded randomness | One `RandomNumberGenerator` per system, seeds and states saved and restored | feature, S | M0-05 |
| M0-09 Registry and definitions | `DefBase` Resource with `id`; `Registry` loads `data/`, rejects duplicate ids and broken references; empty `BalanceConfig` | feature, M | M0-05 |
| M0-10 Save service | JSON save and load of `GameState`, format version, `SaveMigrator` skeleton, three rotating autosaves, round-trip test | feature, M | M0-05, M0-08 |
| M0-11 Settings service | `ConfigFile` settings under `user://`, typed accessors, defaults, change signal | feature, S | M0-05 |
| M0-12 InputService | Named `InputMap` actions, two bindings per action per device, remapping saved through Settings, conflict detection, `input_device_changed` | feature, M | M0-11 |
| M0-13 Localisation scaffold | CSV tables for English and Brazilian Portuguese, a stretched pseudo-locale, a test that fails on hard-coded UI text | tooling, S | M0-05 |
| M0-14 Shell scene and debug overlay | Main scene showing date and time; speed controls on input actions; save and load buttons; overlay with speed, tick time and a state inspector | feature, M | M0-06, M0-07, M0-10, M0-12, M0-13 |
| M0-15 Soak test | Headless bot runs 365 in-game days, saves and reloads each month, checks for errors and identical state | test, S | M0-04, M0-06, M0-07, M0-10 |

M0 is done when M0-14 and M0-15 are merged and the milestone check passes: an empty game ticks, saves, loads and passes every test headless. M0 closed on 2026-10-21 with all 15 cards merged; the owner playtested it, and review follow-ups became the M0.5 Hardening milestone.

## Decisions and open questions

The owner settled most open questions on 2026-10-21; each decision is now a row in the Overview's locked decisions table.

- [x] **Title:** ANNULUS is dropped; another game already uses it. TENTH SEAL was dropped as too mythical. The title is FAR SIDE PROTOCOL.
- [x] **Setting:** an unnamed Western government. Other governments are factions: the Dravian Federation and the Meridian Accord.
- [x] **Languages:** English and Brazilian Portuguese at launch.
- [x] **Voice:** key lines fully voiced over radio; other lines voice only their opening words.
- [x] **Art:** grey-box placeholders, then Claude-generated Blender art. A commissioned artist only if the game proves promising.
- [x] **Content volume:** about 40 authored and 300 procedural worlds, revisited at M5.
- [x] **Distribution:** Steam, considered only once the game proves good enough.
- [x] **Difficulty:** three presets plus sliders, with accessibility options and full remappable keyboard, mouse and gamepad play.
- [ ] **Title check:** a quick web search found no game called Far Side Protocol. A full trademark and Steam search is still due before any public page.
- [x] **Foreign powers:** the Dravian Federation and the Meridian Accord, two powers, as designed.
