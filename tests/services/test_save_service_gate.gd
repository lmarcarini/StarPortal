## Tests for SaveService with the gate, power and worlds sections: exact round trips of
## fractional and random energy, ExactFloat strings in the file, and hand-edited data
## failing cleanly. Each test uses its own instance pointed at a unique temporary user:// folder.
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


## A LOCKED Ring with a log of three, fractional energy and two world
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
	state.gate.dial_log.append(_log_entry(DialOutcome.Kind.NO_GATE, 0.1 + 0.2, &""))
	state.gate.dial_log.append(_log_entry(DialOutcome.Kind.BLOCKED, 75.0 / 7.0, &"chulak"))
	state.gate.dial_log.append(_log_entry(DialOutcome.Kind.HOSTILE_LOCK, 1.0 / 3.0, &"abydos"))
	state.power.banks_installed = 1
	state.power.capacity_mwh = 400.0
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


## The reviewer's case: 1.0 / 300.0 (which Godot's JSON parser cannot read back from its
## shortest decimal text) in every float field saves and loads bit for bit.
func test_one_three_hundredth_in_every_float_field() -> void:
	var value := 1.0 / 300.0
	var state := _sample_state()
	state.power.stored_mwh = value
	state.power.capacity_mwh = value
	state.power.plant_output_mw = value
	state.gate.lock_energy_mwh = value
	for entry: DialLogEntry in state.gate.dial_log:
		entry.energy_spent_mwh = value
	var loaded := _save_and_load(state, &"one_300th")
	assert_dict(loaded.to_dict()).is_equal(state.to_dict())
	var floats: Array[float] = [
		loaded.power.stored_mwh,
		loaded.power.capacity_mwh,
		loaded.power.plant_output_mw,
		loaded.gate.lock_energy_mwh,
	]
	for entry: DialLogEntry in loaded.gate.dial_log:
		floats.append(entry.energy_spent_mwh)
	for loaded_value: float in floats:
		assert_bool(_bits(loaded_value) == _bits(value)).is_true()


## 1,000 seeded random energies (half random bit patterns, half decimal-looking values
## across magnitudes) in one Dial Log save and load bit for bit.
func test_random_energies_round_trip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var state := _sample_state()
	var values: Array[float] = []
	while values.size() < 1000:
		var value := _random_energy(rng, values.size() % 2 == 0)
		if not is_finite(value):
			continue
		values.append(value)
		state.gate.dial_log.append(_log_entry(DialOutcome.Kind.NO_GATE, value, &""))
	var loaded := _save_and_load(state, &"random_energies")
	assert_dict(loaded.to_dict()).is_equal(state.to_dict())
	for index: int in values.size():
		var entry: DialLogEntry = loaded.gate.dial_log[index + 3]
		var label := "%d: %s" % [index, ExactFloat.encode(values[index])]
		var same := _bits(entry.energy_spent_mwh) == _bits(values[index])
		assert_bool(same).override_failure_message(label).is_true()


## The file stores floats as ExactFloat strings, not decimal numbers.
func test_file_has_exact_float_strings() -> void:
	_service.save_game(_sample_state(), &"digits")
	var text := FileAccess.get_file_as_string(_service.slot_path(&"digits"))
	assert_str(text).contains('"3fd5555555555555"')
	assert_str(text).contains('"%s"' % ExactFloat.encode(0.1 + 0.2))
	assert_str(text).not_contains("0.30000000000000004")
	assert_str(text).contains(str(_sample_state().worlds.galaxy_seed))


func _save_and_load(state: GameState, slot: StringName) -> GameState:
	assert_bool(_service.save_game(state, slot).is_ok).is_true()
	var result: Result = _service.load_game(slot)
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	return result.value


## The raw bytes of [param value], independent of ExactFloat.
func _bits(value: float) -> PackedByteArray:
	return PackedFloat64Array([value]).to_byte_array()


## A non-negative random float: a random bit pattern with the sign cleared when
## [param from_bits], else a uniform value scaled by a power of ten from 1e-12 to 1e15.
## May be infinite or NaN when [param from_bits]; the caller skips those.
func _random_energy(rng: RandomNumberGenerator, from_bits: bool) -> float:
	if not from_bits:
		return rng.randf() * pow(10.0, rng.randi_range(-12, 15))
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_u32(0, rng.randi())
	bytes.encode_u32(4, rng.randi() & 0x7fffffff)
	return bytes.decode_double(0)


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
		["power", "stored_mwh", ExactFloat.encode(-1.0), "power: 'stored_mwh'"],
		["power", "stored_mwh", 0.5, "power: 'stored_mwh'"],
		["gate", "lock_energy_mwh", ExactFloat.encode(NAN), "gate: 'lock_energy_mwh'"],
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
