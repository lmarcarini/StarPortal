class_name SaveMigrator
extends RefCounted
## Brings saved data forward to the current save format, one version at a time.
## Each step is a function Dictionary -> Dictionary that turns data at version N into data
## at version N + 1. Steps are pure: no side effects, no autoloads.
## Bible: technical-architecture.md#save-system

## The save format version the game writes and loads.
const TARGET_VERSION: int = 10

## v3 defaults as ExactFloat strings, frozen here: 0.0, 400.0 and 30.0.
const _EXACT_ZERO: String = "0000000000000000"
const _EXACT_400: String = "4079000000000000"
const _EXACT_30: String = "403e000000000000"


## Returns the built-in steps, keyed by the version they migrate from. Version 1 is the
## first format. (A function, not a constant: a Callable is not a constant expression.)
static func built_in_steps() -> Dictionary[int, Callable]:
	var built_in: Dictionary[int, Callable] = {
		1: _v1_to_v2,
		2: _v2_to_v3,
		3: _v3_to_v4,
		4: _v4_to_v5,
		5: _v5_to_v6,
		6: _v6_to_v7,
		7: _v7_to_v8,
		8: _v8_to_v9,
		9: _v9_to_v10,
	}
	return built_in


## Returns [param data] migrated to [constant TARGET_VERSION] with the built-in steps.
## Fails with &"bad_format_version", &"newer_format_version", &"missing_migration_step"
## or &"migration_failed". The input dictionary is never modified.
static func migrate(data: Dictionary) -> Result:
	return migrate_with_steps(data, built_in_steps(), TARGET_VERSION)


## Returns [param data] migrated to [param target] by running [param steps] in version
## order. [param steps] maps a from-version to a Callable(Dictionary) -> Dictionary.
## After each step "format_version" is set to the step's to-version.
static func migrate_with_steps(
	data: Dictionary, steps: Dictionary[int, Callable], target: int
) -> Result:
	var version_result := read_version(data)
	if not version_result.is_ok:
		return version_result
	var version: int = version_result.value
	if version > target:
		return Result.fail(
			&"newer_format_version", "save is v%d, this game reads up to v%d" % [version, target]
		)
	var current: Dictionary = data.duplicate(true)
	while version < target:
		if not steps.has(version):
			return Result.fail(&"missing_migration_step", "no step from v%d" % version)
		var migrated: Variant = steps[version].call(current)
		if not migrated is Dictionary:
			return Result.fail(&"migration_failed", "step from v%d returned no data" % version)
		current = migrated
		version += 1
		current["format_version"] = version
	return Result.ok(current)


## Returns the whole-number "format_version" of [param data] as an int, or fails with
## &"bad_format_version" when it is missing, not a number, fractional, negative or above
## [constant JsonLimits.MAX_EXACT_INT] (2^53, so the float-to-int conversion never
## overflows).
static func read_version(data: Dictionary) -> Result:
	var raw: Variant = data.get("format_version")
	if not (raw is int or raw is float):
		return Result.fail(&"bad_format_version", "format_version is missing or not a number")
	var as_float: float = raw
	var limit: float = float(JsonLimits.MAX_EXACT_INT)
	if not (as_float == floorf(as_float) and as_float >= 0.0 and as_float <= limit):
		return Result.fail(&"bad_format_version", "format_version %s is invalid" % str(raw))
	var version: int = raw
	return Result.ok(version)


## v1 -> v2: the clock's "is_paused" bool becomes the time-control "mode" ("paused" or
## "running") with no "holds" and "mode_after_hold" "paused". Data whose clock is missing
## or whose "is_paused" is not a bool is left as is, for validation to reject.
static func _v1_to_v2(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	var clock: Variant = state_data.get("clock")
	if not clock is Dictionary:
		return data
	var clock_data: Dictionary = clock
	var paused: Variant = clock_data.get("is_paused")
	if not paused is bool:
		return data
	clock_data["mode"] = "paused" if paused else "running"
	clock_data["holds"] = []
	clock_data["mode_after_hold"] = "paused"
	clock_data.erase("is_paused")
	return data


## v2 -> v3: adds the "gate", "power" and "worlds" sections with the v3 defaults, written
## here as literals so later changes to the game's defaults never change this step:
## the Ring idle with an empty queue and Dial Log; power at capacity 400 MWh, plant output
## 30 MW, nothing stored (the bible's starting plant and storage), floats written as
## ExactFloat strings (IEEE-754 bit patterns in hex); the galaxy seed derived
## from the save's base seed with RandomState.derive_seed(base, &"galaxy"), as a decimal
## string; generator version 1. The base seed is read like RandomState.from_dict() reads
## it. Data with no state object is left as is, for validation to reject.
static func _v2_to_v3(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	state_data["gate"] = {
		"mode": "idle",
		"current_address": null,
		"dial_started_tick": -1,
		"lock_energy_mwh": _EXACT_ZERO,
		"connected_world_id": "",
		"lock_started_tick": -1,
		"is_hostile": false,
		"dial_queue": [],
		"dial_log": [],
	}
	state_data["power"] = {
		"stored_mwh": _EXACT_ZERO,
		"capacity_mwh": _EXACT_400,
		"plant_output_mw": _EXACT_30,
	}
	var galaxy_seed := RandomState.derive_seed(_v2_base_seed(state_data), &"galaxy")
	state_data["worlds"] = {"galaxy_seed": str(galaxy_seed), "generator_version": 1, "statuses": {}}
	return data


## The base seed of a v2 [param state_data]: "random"."base_seed", a decimal string (a
## plain number is still accepted), or 0 when missing.
static func _v2_base_seed(state_data: Dictionary) -> int:
	var random: Variant = state_data.get("random")
	if not random is Dictionary:
		return 0
	var random_data: Dictionary = random
	var base_seed: Variant = random_data.get("base_seed", 0)
	if base_seed is String:
		var text: String = base_seed
		return text.to_int()
	return type_convert(base_seed, TYPE_INT)


## v3 -> v4: adds the "intel" and "workbench" sections with the v4 defaults, written here
## as literals so later changes to the game's defaults never change this step: no clues,
## notes or scheduled dossiers, both counters at 1, and an empty Workbench draft using the
## home Ring's origin (-1). Data with no state object is left as is, for validation to
## reject.
static func _v3_to_v4(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	state_data["intel"] = {
		"clues": [],
		"notes": {},
		"next_clue_number": 1,
		"next_dossier_number": 1,
		"scheduled_dossiers": {},
	}
	state_data["workbench"] = {"origin_glyph": -1, "constraints": []}
	return data


## v4 -> v5: drops what the M1 deduction tools saved, rejected after the M1 playtest: the
## "intel" section (clues, notes, scheduled dossiers), the "workbench" draft and the Ring's
## "dial_queue". Every other section is kept as it is. Data with no state object is left as
## is, for validation to reject; a "gate" that is not an object is left for validation too.
static func _v4_to_v5(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	state_data.erase("intel")
	state_data.erase("workbench")
	var gate: Variant = state_data.get("gate")
	if gate is Dictionary:
		var gate_data: Dictionary = gate
		gate_data.erase("dial_queue")
	return data


## v5 -> v6: adds the empty "archive" (no documents received or read) and "address_book" (no
## entries) sections, written here as literals so later changes to the game's defaults never
## change this step. The Address Book is not filled from the Dial Log: a v5 save predates it.
## Every other section is kept as it is. Data with no state object is left as is, for
## validation to reject.
static func _v5_to_v6(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	state_data["archive"] = {"received": [], "read": {}, "received_tick": {}}
	state_data["address_book"] = {"entries": []}
	return data


## v6 -> v7: adds the capacitor bank fields to "power": "banks_installed" is 1 when the v6
## capacity is above 0 (every v6 game started with its bank installed) and 0 otherwise, and
## "install_ticks_left" is 0 (no install running). Charge, capacity and plant output are kept
## as they are. Data with no state object or no power object is left as is, for validation to
## reject; an unreadable capacity counts as 0 and validation rejects it.
static func _v6_to_v7(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	var power: Variant = state_data.get("power")
	if not power is Dictionary:
		return data
	var power_data: Dictionary = power
	var capacity: Variant = power_data.get("capacity_mwh")
	var has_bank: bool = false
	if ExactFloat.is_encoded(capacity):
		var capacity_text: String = capacity
		has_bank = ExactFloat.decode(capacity_text) > 0.0
	power_data["banks_installed"] = 1 if has_bank else 0
	power_data["install_ticks_left"] = 0
	return data


## v7 -> v8: adds "consoles_read" to "worlds", empty (no far Ring's console read yet), written
## here as a literal so later changes to the game's defaults never change this step. Every
## other value is kept. Data with no state object or no worlds object is left as is, for
## validation to reject.
static func _v7_to_v8(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	var worlds: Variant = state_data.get("worlds")
	if not worlds is Dictionary:
		return data
	var worlds_data: Dictionary = worlds
	worlds_data["consoles_read"] = {}
	return data


## v8 -> v9: adds the pole camera to "worlds": "horizon_records" holds every world whose v8
## status is "locked" (a v8 game delivered a world's documents on its first lock, so they never
## come twice), and the camera is in ("pole_camera_world_id" "", "pole_camera_ticks_left" 0),
## written here as literals so later changes to the game's defaults never change this step.
## Every other value is kept. Data with no state object or no worlds object is left as is, for
## validation to reject; a "statuses" that is not an object gives no records and is left for
## validation too.
static func _v8_to_v9(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	var worlds: Variant = state_data.get("worlds")
	if not worlds is Dictionary:
		return data
	var worlds_data: Dictionary = worlds
	var records: Dictionary = {}
	var statuses: Variant = worlds_data.get("statuses")
	if statuses is Dictionary:
		var status_dict: Dictionary = statuses
		for world_id: Variant in status_dict:
			if str(status_dict[world_id]) == "locked":
				records[str(world_id)] = true
	worlds_data["horizon_records"] = records
	worlds_data["pole_camera_world_id"] = ""
	worlds_data["pole_camera_ticks_left"] = 0
	return data


## v9 -> v10: adds the "operations_log" section, empty (a v9 game kept no log), written here as a
## literal so later changes to the game's defaults never change this step. Every other section is
## kept. Data with no state object is left as is, for validation to reject.
static func _v9_to_v10(data: Dictionary) -> Dictionary:
	var state: Variant = data.get("state")
	if not state is Dictionary:
		return data
	var state_data: Dictionary = state
	state_data["operations_log"] = {"entries": []}
	return data
