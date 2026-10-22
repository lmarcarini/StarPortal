## Tests for SaveService with the gate, power and worlds sections: an exact round trip with
## fractional energy, full-precision digits in the file, and hand-edited Ring data failing
## cleanly. Each test uses its own instance pointed at a unique temporary user:// folder.
## Bible: technical-architecture.md#save-system (round-trip test),
## technical-architecture.md#data-model
extends GdUnitTestSuite

const SaveServiceScript := preload("res://src/services/save_service.gd")

var _service: SaveServiceScript


func before_test() -> void:
	_service = SaveServiceScript.new()
	_service.saves_dir = "user://test_saves_gate_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]


func after_test() -> void:
	var dir := DirAccess.open(_service.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(_service.saves_dir.path_join(file_name))
		DirAccess.remove_absolute(_service.saves_dir)
	_service.free()


func _address(origin: int) -> GateAddress:
	var coordinates: Array[int] = [11, 2, 23, 4, 15, 6, 27]
	return GateAddress.create(coordinates, origin)


func _log_entry(kind: DialOutcome.Kind, energy: float, world_id: StringName) -> DialLogEntry:
	var entry := DialLogEntry.new()
	entry.tick = 300 + kind
	entry.address = _address(30)
	entry.outcome = kind
	entry.energy_spent_mwh = energy
	entry.world_id = world_id
	return entry


## A LOCKED Ring with a queue of two, a log of three, fractional energy and two world
## statuses, at clock tick 1000.
func _sample_state() -> GameState:
	var state := GameState.new_game(9007199254740993, BalanceConfig.new())
	state.clock.tick = 1000
	state.gate.mode = GateState.RingMode.LOCKED
	state.gate.current_address = _address(30)
	state.gate.dial_started_tick = 990
	state.gate.lock_started_tick = 992
	state.gate.lock_energy_mwh = 1.0 / 3.0
	state.gate.connected_world_id = &"abydos"
	state.gate.is_hostile = true
	state.gate.dial_queue.append(_address(31))
	state.gate.dial_queue.append(_address(32))
	state.gate.dial_log.append(_log_entry(DialOutcome.Kind.NO_GATE, 0.1 + 0.2, &""))
	state.gate.dial_log.append(_log_entry(DialOutcome.Kind.BLOCKED, 75.0 / 7.0, &"chulak"))
	state.gate.dial_log.append(_log_entry(DialOutcome.Kind.HOSTILE_LOCK, 1.0 / 3.0, &"abydos"))
	state.power.stored_mwh = 0.1 + 0.2
	state.worlds.statuses[&"abydos"] = WorldsState.WorldStatus.LOCKED
	state.worlds.statuses[&"chulak"] = WorldsState.WorldStatus.LOCKED
	return state


## Save then load reproduces the state's to_dict() exactly, floats bit for bit.
func test_round_trip_is_identical() -> void:
	var state := _sample_state()
	var original := state.to_dict()
	assert_bool(_service.save_game(state, &"gate_round_trip").is_ok).is_true()
	var result: Result = _service.load_game(&"gate_round_trip")
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var loaded: GameState = result.value
	assert_dict(loaded.to_dict()).is_equal(original)
	assert_bool(loaded.power.stored_mwh == 0.1 + 0.2).is_true()
	assert_bool(loaded.gate.lock_energy_mwh == 1.0 / 3.0).is_true()
	assert_bool(loaded.gate.dial_log[1].energy_spent_mwh == 75.0 / 7.0).is_true()
	assert_int(loaded.worlds.galaxy_seed).is_equal(state.worlds.galaxy_seed)


## The file holds every significant digit of the floats, not the 15-digit default.
func test_file_has_full_precision_digits() -> void:
	_service.save_game(_sample_state(), &"digits")
	var text := FileAccess.get_file_as_string(_service.slot_path(&"digits"))
	assert_str(text).contains("0.30000000000000004")
	assert_str(text).contains("0.3333333333333333")
	assert_str(text).contains(str(_sample_state().worlds.galaxy_seed))


## Hand-edited Ring, power and worlds data fails with &"invalid_state".
func test_hand_edited_sections_are_invalid_state() -> void:
	_service.save_game(_sample_state(), &"edited")
	var good: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_service.slot_path(&"edited"))
	)
	var cases: Array[Array] = [
		["gate", "mode", "warping", "gate: 'mode'"],
		["gate", "connected_world_id", "", "gate: 'connected_world_id' is not set"],
		["gate", "lock_started_tick", 1001, "later than the clock tick"],
		["power", "stored_mwh", -1.0, "power: 'stored_mwh'"],
		["worlds", "galaxy_seed", 5, "worlds: 'galaxy_seed'"],
	]
	for case: Array in cases:
		var data := good.duplicate(true)
		data["state"][case[0]][case[1]] = case[2]
		var file := FileAccess.open(_service.slot_path(&"edited"), FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		var result: Result = _service.load_game(&"edited")
		assert_str(result.error_code).override_failure_message(str(case)).is_equal(&"invalid_state")
		assert_str(result.detail).override_failure_message(str(case)).contains(str(case[3]))
