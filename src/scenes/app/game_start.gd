class_name GameStart
extends RefCounted
## How the next game starts, set by the main menu before it changes to the shell: a new game
## (with a seed, or -1 for the clock), a save slot or a scenario. The menu loads a slot or a
## scenario itself, so a failure is shown on the menu; the shell then takes the loaded state.
## The default (NEW, seed -1, nothing loaded) is what tests that instance the shell get.
## Bible: docs/bible/technical-architecture.md#architecture-overview

## Start modes.
enum Mode { NEW, SLOT, SCENARIO }

## How the next game starts.
static var mode: Mode = Mode.NEW
## New game seed; -1 picks one from the clock.
static var seed: int = -1
## The slot loaded (SLOT).
static var slot: StringName = &""
## The scenario chosen (SCENARIO).
static var scenario_id: StringName = &""
## The state the menu already loaded for SLOT or SCENARIO; null for NEW.
static var loaded: GameState = null
## Why the last start failed in the shell (the menu shows it, then clears it); &"" when none.
## Not cleared by [method reset].
static var failure: StringName = &""


## Sets up a new game with [param new_seed] (-1 for the clock).
static func start_new(new_seed: int = -1) -> void:
	reset()
	seed = new_seed
	mode = Mode.NEW


## Sets up starting from [param state], loaded from [param from_slot].
static func start_slot(from_slot: StringName, state: GameState) -> void:
	reset()
	mode = Mode.SLOT
	slot = from_slot
	loaded = state


## Sets up starting from scenario [param id], whose state is [param state].
static func start_scenario(id: StringName, state: GameState) -> void:
	reset()
	mode = Mode.SCENARIO
	scenario_id = id
	loaded = state


## True when the next start builds a new game (not a loaded state).
static func is_new() -> bool:
	return loaded == null


## The state to start with: the loaded one (then forgotten, so the next start is NEW again),
## or a new game with the set seed, else [param fallback_seed]; [param balance] for new games.
## Null when a slot or scenario start has no loaded state (the shell then goes back to the menu).
static func take_state(fallback_seed: int, balance: BalanceConfig) -> GameState:
	if mode != Mode.NEW and loaded == null:
		reset()
		return null
	if loaded != null:
		var state: GameState = loaded
		reset()
		return state
	var use_seed: int = seed if seed >= 0 else fallback_seed
	reset()
	return GameState.new_game(use_seed, balance)


## Back to the default: NEW, seed -1, nothing loaded.
static func reset() -> void:
	mode = Mode.NEW
	seed = -1
	slot = &""
	scenario_id = &""
	loaded = null
