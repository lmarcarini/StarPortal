# Technical Architecture (Godot 4)

## Engine and targets

The game targets old integrated graphics, so every engine choice favours the Compatibility renderer and a mostly 2D presentation.

| Setting | Choice |
| --- | --- |
| Engine | Godot 4, latest stable 4.x at project start. The version is pinned in the repository and upgraded only between milestones |
| Language | GDScript with static typing everywhere. No C#, so exports need no .NET runtime |
| Renderer | Compatibility (OpenGL 3.3 / OpenGL ES 3.0) |
| Base resolution | 1920 × 1080; stretch mode canvas\_items, aspect expand; minimum window 1280 × 720 |
| Drone feed | A SubViewport rendering at 320 × 240, upscaled through a post shader |
| Video | Ogg Theora (.ogv) for the few pre-rendered cutscenes |
| Performance target | 60 fps on Intel UHD 620-class graphics; under 2 GB of RAM in use; install under 2 GB |
| Text | Every string goes through translation keys from day one; English and Brazilian Portuguese at launch |

## Architecture overview

The simulation is plain GDScript with no Nodes, and the presentation only reads it and sends commands; this one rule keeps the game testable, saveable and deterministic.

*Diagram (see the live design doc): architecture · 4 layers and the 4 channels between them*

Only two channels touch the simulation at runtime: commands in, events out. Content and save data meet it at load time.

| Layer | Contains | May depend on |
| --- | --- | --- |
| Content | Custom Resource definitions (`*Def`) and balance data, authored in the editor | Nothing |
| Simulation | `GameState`, systems, commands, glyph math. Classes extend `RefCounted` | Content |
| Services | Save, settings, audio, localisation | Simulation (read only) |
| Presentation | Scenes, views, UI, the drone feed, cutscenes | Everything above, through the EventBus and the command queue |

Rules:

- **The simulation never touches a Node,** scene or `get_tree()`. It can run headless in a test.
- **The UI never mutates state.** It builds a command and submits it.
- **The simulation reports through domain events** on the `EventBus`, such as `gate_locked`, `expedition_checked_in` and `month_closed`. Views subscribe and redraw.
- **Autoloads are few:** `SimClock`, `EventBus`, `Registry`, `SaveService`, `Settings`, `Audio`. Add InputService to that list. Nothing else is global.

## Simulation clock and commands

One fixed-step clock drives everything, so 10× speed is just more ticks per second and the same inputs always produce the same game.

- **`SimClock`** adds real time × speed to an accumulator and runs whole ticks; one tick is one in-game minute. Ticks per frame are capped so a slow frame never spirals.
- **Fixed tick order:** apply queued commands, then power, gate, expeditions, research, personnel, economy, factions, threats, story triggers. Finally, emit the tick's events.
- **Hooks:** systems implement `tick()`, and optionally `on_day()` and `on_month()`.
- **Commands** such as `DialCommand`, `BuildRoomCommand` and `AssignStaffCommand` validate against the state, then apply. While paused they apply at once. They serialise, so a command log can replay a session to reproduce a bug.
- **Randomness** comes only from seeded `RandomNumberGenerator` instances, one per system. Their seeds and states are saved.
- **Auto-pause:** the simulation emits `pause_requested(reason)`; `SimClock` honours it according to the player's settings.
- **Drone-feed time:** while the feed is live, `SimClock` switches to one tick per 6 real seconds.

## Data model

Definitions describe what can exist and never change at runtime; state records what does exist and is the only thing saved.

**Definitions** are custom Resource classes saved as `.tres` under `data/`. Each has a stable string `id`, and references between them use ids, never file paths.

| Definition | Describes |
| --- | --- |
| `GlyphDef`, `AnchorFieldDef`, `DomainDef` | The address system |
| `WorldDef` | A story world, or the rules for generating procedural ones |
| `ClueDef`, `DossierDef` | Hand-made documents and objects: their text, images, source, the world they describe and the address puzzle they hold (its answer, checked by the validator) |
| `ArtefactDef`, `TechDef` | The research pipeline and tech tree |
| `RoomDef`, `RoleDef`, `TraitDef` | Base and personnel |
| `FactionDef`, `RequestDef` | Politics |
| `EventDef`, `ArcDef` | Story |
| `TransitionDef` | Allowed state changes for worlds, artefacts, technologies and people |
| `BalanceConfig` | Every tunable number in this bible |

**`Registry`** loads every definition at start-up into dictionaries keyed by id and validates the references.

**Runtime state** is a tree of plain classes under `GameState`: clock, economy, power, base, personnel, gate, worlds, expeditions, research, factions, intel and flags. Each class implements `to_dict()` and `from_dict()`. Each class also implements a static validate\_dict() that returns a list of errors; save data is checked with it before from\_dict() runs, so a hand-edited or corrupt save fails cleanly instead of loading wrong values. A definition Resource is shared, so code never writes to one at runtime.

## Narrative and event scripting

Story is data, not code: events are conditions plus effects, and arcs change gameplay by switching feature flags that systems already check.

- **`EventDef`** = trigger conditions + a list of effects + optional presentation (a briefing, a radio call, a cutscene, a choice).
- **Conditions and effects** are small typed Resource classes, such as `FlagIs`, `StandingAtLeast`, `AddClue`, `ChangeStanding`, `StartArc` and `UnlockTech`. There is no evaluation of script strings, which keeps events safe, testable and checkable by tools.
- **`ArcDef`** lists phases, entry and exit conditions, and the feature flags it sets, such as `budget_frozen`, `ring_lockdown` or `exposure_is_public_opinion`. Systems read flags; they never check which arc is running. This is how arcs change the rules.
- **Flags** live in a typed key-value store in `GameState`.
- **Dialogue** uses a minimal in-house format: a choice is an `EventDef` with options. A dialogue add-on can be adopted later if writing volume demands it.

## Save system

Saves are versioned JSON written from `GameState.to_dict()`, never Resource files, because a `.tres` loaded from a user folder can run embedded scripts.

- **Location:** `user://saves/`, one file per slot, plus three rotating autosaves taken at the start of each in-game day and before risky events such as a 9-seal dial.
- **Contents:** save format version, game version, world seed, RNG states, the full state tree, and optionally the command log since the last autosave.
- **Migrations:** `SaveMigrator` holds one step function per format version (v1 to v2, v2 to v3, and so on). Old saves load forward step by step.
- **Ironman:** one slot, saved at each in-game day and on quit.
- **Round-trip test:** for every system, save then load must reproduce an identical state.

## Input, accessibility and localisation

No code reads a raw key, button or mouse event; everything goes through named input actions, which is what makes full remapping and gamepad play cheap from the start.

- **Input actions.** Every control is a named action in Godot's `InputMap`, such as `dial_confirm`, `time_toggle_pause` or `drone_thrust`. Gameplay and UI code check actions only.
- **Remapping.** An `InputService` loads default bindings, applies the player's overrides and saves them with `ConfigFile` under `user://`. It supports two bindings per action per device and detects conflicts.
- **Device switching.** `InputService` tracks the last device used and emits `input_device_changed`. Prompt icons and the gamepad cursor follow it.
- **Gamepad UI.** Every view sets a default focus and its focus neighbours; a UI test walks each view with focus navigation alone.
- **Accessibility settings** live in the `Settings` service and are read through it. The drone-feed shader exposes a uniform for each effect so each can be switched off; the flash limiter caps brightness change per frame.
- **Subtitles and captions** are data: each voice line and important sound has a caption key.
- **Localisation.** Strings live in CSV translation tables. Brazilian Portuguese runs about 25% longer than English, so every label is laid out to grow. A pseudo-locale with stretched text runs in tests to catch overflow.
- **Partial voice lines.** A voice clip can cover only the start of a line; the dialogue player plays the clip and shows the full text, so audio and text never need to match in length.

## Project layout and conventions

The folder tree mirrors the layers, so where a file lives says what it may depend on.

```
res://
  data/            definitions (.tres) and balance data
  src/
    core/          GameState, systems, commands, SimClock
    gate/          glyph math, address rule, world generator
    content/       Resource class scripts (*Def)
    services/      save, settings, audio, localisation
    ui/            views, widgets, theme
    scenes/        base cutaway, gate room, drone feed, cutscenes
  art/  audio/  video/  localization/
  tests/           unit and soak tests
  tools/           editor plugins and scripts: validator, galaxy preview
  addons/          third-party add-ons (gdUnit4 only, to start)
  docs/            lore canon, decision log, this bible exported
```

How the code itself is written is set out in Code standards, below. Each change covers one feature, includes its tests, and names the bible section it implements.

## Code standards

The house style is functional at the core and stateful only at the edges: small typed functions, guard clauses, composition, and explicit state machines wherever something has modes.

### Translating React and TypeScript habits

Most React habits carry over; a few change shape in Godot.

| React / TypeScript | Godot equivalent here |
| --- | --- |
| Component | Scene with a thin script |
| Props | `@export` variables, or a typed `setup()` call before the node enters the tree |
| Store (Redux, Zustand) | `GameState` |
| Action | Command (`DialCommand`) |
| Reducer | A system's `tick()` or a command's `apply()` |
| Selector | A static pure function that reads state |
| Context | Autoload, used sparingly |
| Event emitter, callbacks | Signals |
| `useEffect` cleanup | Disconnecting in `_exit_tree()` |
| Interface | Abstract base class (`@abstract` where the pinned version supports it), kept to one level |
| Exceptions, `try/catch` | None in GDScript: results are returned, programmer errors are asserted |
| `null` checks | Guard clauses; `is_instance_valid()` for Nodes that may have been freed |

### Typing and names

- **Everything typed:** members, parameters, return types (including `-> void`), typed arrays (`Array[CrewMember]`) and typed dictionaries (`Dictionary[StringName, int]`).
- **Inference with `:=`** is fine for locals when the right-hand side makes the type obvious.
- **Warnings as errors:** untyped declarations and the unsafe-access warnings (property access, method access, cast, call argument).
- **Functions are verbs:** `compute_lock_energy_mwh`, `assign_to_room`. Booleans start with `is_`, `has_` or `can_`.
- **Units go in names** wherever a number has one: `energy_mwh`, `power_mw`, `duration_ticks`, `budget_k`.
- **Signals in the past tense:** `gate_locked`, `crew_injured`.
- **Private members** start with an underscore. Constants are `UPPER_SNAKE`. Enums are `PascalCase` with `UPPER_SNAKE` values.
- **No abbreviations** except `id`, `ui` and `rng`.
- **`StringName` literals** (`&"ring_busy"`) for ids and error codes, not plain strings.

### Functions and files

| Rule | Target | Hard limit |
| --- | --- | --- |
| Function length | 20 lines | 40 lines |
| Function arguments | 3 | 4; beyond that, pass a typed object |
| Nesting depth | 2 levels | 3 levels |
| File length | 200 lines | 400 lines; split by responsibility before that |
| Line length | 100 characters | 100 characters |

One class per file, one job per function. A function either answers a question or changes something, never both.

### Errors and guard clauses

GDScript has no exceptions, so the code separates two kinds of failure.

- **Programmer errors** (a bug: an impossible state, a broken invariant) use `assert()`. Asserts run in debug builds and tests and are stripped from release builds.
- **Expected failures** (not enough charge, the Ring is busy, a missing save file) return a typed result. Commands return a `CommandResult`; other fallible operations return a `Result` with `ok`, `value` and `error`.
- **Guard clauses first.** Validate and return early; the happy path runs unindented at the bottom.
- **Data from outside** (save files, definitions, settings) is validated where it enters, so inner code can trust it.

```gdscript
class_name DialCommand
extends Command
## Dials an address from the dial console. Validates, then applies.

var address: GateAddress

func validate(state: GameState) -> CommandResult:
	if address == null:
		return CommandResult.fail(&"no_address")
	if state.gate.ring_state != RingState.IDLE:
		return CommandResult.fail(&"ring_busy")
	var needed_mwh := EnergyMath.lock_energy_mwh(address, state.balance)
	if state.power.stored_mwh < needed_mwh:
		return CommandResult.fail(&"insufficient_charge")
	return CommandResult.ok()
```

### Functional core, stateful shell

- **Rules and calculations are pure static functions** in `class_name` utility scripts such as `GlyphMath`, `EnergyMath` and `EconomyMath`. Same inputs, same output, no side effects, no access to autoloads. These hold most of the logic and most of the tests.
- **Mutation happens in exactly two places:** a command's `apply()` and a system's `tick()`. Like a reducer, each reads the state, calls pure functions, then writes the result back.
- **No copying for immutability.** GDScript has no cheap immutable structures, so state is mutated in place, but only in those two places.
- **Lambdas and `map`, `filter`, `reduce`** are welcome in UI and tools. Inside the per-tick loop, prefer plain loops, which allocate less.

### Composition over inheritance

- **Scenes are composed from small child nodes,** such as a room built from `PowerConsumer`, `StaffSlots` and `DamageState` children. Each child does one thing.
- **Simulation objects compose plain objects** held in typed fields.
- **Inheritance is one level deep:** an engine class (`Node2D`, `RefCounted`, `Resource`) or one abstract base (`Command`, `SimSystem`, `Effect`). Never a chain.
- **Entities refer to each other by id,** not object reference. `RefCounted` objects that point at each other in a cycle are never freed, and ids also serialise cleanly.

### State machines

Anything with modes gets an explicit state machine, never a set of booleans such as `is_dialing and not is_locked`.

- **Simulation machines** are an enum, a table of allowed transitions, and one `transition_to()` function that guards, switches and emits. The Ring, expeditions, incursions and the time controls all use this pattern.
- **Content machines** (worlds, artefacts, technologies, people) are data: `TransitionDef` lists in `data/`, so new states need no code.
- **Presentation machines** may use nodes or `AnimationTree`, but they only mirror simulation state; they never decide it.
- **Every transition is logged** in debug builds, and illegal transitions fail an assert.

```gdscript
class_name RingMachine
extends RefCounted

signal state_changed(from: RingState, to: RingState)

const _ALLOWED: Dictionary = {
	RingState.IDLE: [RingState.CHARGING, RingState.INCOMING],
	RingState.CHARGING: [RingState.DIALING, RingState.IDLE],
	RingState.DIALING: [RingState.LOCKED, RingState.IDLE],
	RingState.LOCKED: [RingState.IDLE],
	RingState.INCOMING: [RingState.SHUTTERED, RingState.LOCKED],
	RingState.SHUTTERED: [RingState.IDLE],
}

var state: RingState = RingState.IDLE

func can_transition_to(next: RingState) -> bool:
	var allowed: Array = _ALLOWED.get(state, [])
	return next in allowed

func transition_to(next: RingState) -> void:
	assert(can_transition_to(next), "Illegal Ring transition")
	if not can_transition_to(next):
		return
	var previous := state
	state = next
	state_changed.emit(previous, next)
```

### Signals and scenes

- **Call down, signal up.** A parent calls methods on its children; children emit signals; siblings talk through their parent or the EventBus.
- **Connect in code** with method references, not lambdas, so connections are easy to find and disconnect. Disconnect from autoload signals in `_exit_tree()`.
- **Node references** use `%UniqueName` or `@export`, assigned to typed `@onready` variables. No long `get_node()` paths.
- **No polling.** Views redraw on events, not in `_process()`. Only `SimClock` advances the simulation.

### Determinism and numbers

- **Randomness** only from the system's own seeded `RandomNumberGenerator`; never the global `randi()` or `randf()`.
- **No wall-clock time** in the simulation; only ticks.
- **Money is an integer** in thousands of dollars, and counts are integers. Floats are for energy, distances and rates.

### Documentation and tooling

- **`##` doc comments** on every public class and function; the editor shows them as help. Comments explain why, not what.
- **gdtoolkit** (`gdformat` and `gdlint`) runs in CI and enforces formatting, line length, file length and argument count.
- **Review checklist:** typed, guarded, small, pure where possible, tested, and named after what it does.

## Testing and tooling

The simulation is tested headless on every change, and the puzzle content is checked by tools, because a broken address is a broken game.

- **Unit tests (gdUnit4):** the address rule, address uniqueness, origin conversion, the energy formula, power shortfalls, month-end economy, every command, and save round-trips.
- **Soak test:** a scripted bot plays 365 in-game days headless. It must finish with no errors, no NaN values and every resource within bounds.
- **Continuous integration:** Godot runs headless on GitHub Actions for tests and the content validator on every push.
- **Content Validator:** missing ids, broken references, duplicate addresses, and authored puzzles whose answer is not their world's real address.
- **Galaxy Preview:** an editor plugin that plots anchors and worlds in 3D.
- **Address tool:** prints any world's address and the addresses its Ring console would reveal, for writing and testing puzzles. Never shipped.
- **Debug overlay:** speed, tick time, a state inspector and cheat commands, stripped from release builds.
