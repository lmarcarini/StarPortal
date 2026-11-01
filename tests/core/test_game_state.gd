## Tests for GameState, ClockState and RandomState serialisation, including a JSON round
## trip that turns ints into floats.
## Bible: technical-architecture.md#data-model
extends GdUnitTestSuite


func _sample_state() -> GameState:
	var state := GameState.new_game(123456789)
	state.clock.tick = 44641
	state.clock.speed_index = 3
	state.clock.is_paused = false
	state.flags[&"met_director"] = true
	state.flags[&"briefings_heard"] = 7
	state.flags[&"last_world"] = "P3X-118"
	return state


func _json_round_trip(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data))
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return {}
	return parsed


func _is_json_safe(value: Variant) -> bool:
	if value is Dictionary:
		var dict: Dictionary = value
		for key: Variant in dict:
			if not key is String or not _is_json_safe(dict[key]):
				return false
		return true
	if value is Array:
		var list: Array = value
		return list.all(_is_json_safe)
	return value == null or value is bool or value is int or value is float or value is String


## new_game() stores the seed and starts a paused clock at tick 0 with no flags.
func test_new_game_defaults() -> void:
	var state := GameState.new_game(42)
	assert_int(state.random.base_seed).is_equal(42)
	assert_int(state.clock.tick).is_equal(0)
	assert_int(state.clock.speed_index).is_equal(1)
	assert_bool(state.clock.is_paused).is_true()
	assert_dict(state.flags).is_empty()


## to_dict() returns only JSON-safe types: String keys, no StringName or objects.
func test_to_dict_is_json_safe() -> void:
	var data := _sample_state().to_dict()
	assert_bool(_is_json_safe(data)).is_true()


## from_dict(to_dict()) reproduces an equal dictionary.
func test_round_trip_reproduces_equal_dictionary() -> void:
	var data := _sample_state().to_dict()
	assert_dict(GameState.from_dict(data).to_dict()).is_equal(data)


## The round trip still matches after JSON.stringify -> JSON.parse_string.
func test_json_round_trip_reproduces_equal_dictionary() -> void:
	var data := _sample_state().to_dict()
	var restored := GameState.from_dict(_json_round_trip(data))
	assert_dict(restored.to_dict()).is_equal(data)


## After a JSON round trip the restored fields have their original types.
func test_json_round_trip_restores_types() -> void:
	var restored := GameState.from_dict(_json_round_trip(_sample_state().to_dict()))
	assert_int(typeof(restored.clock.tick)).is_equal(TYPE_INT)
	assert_int(restored.clock.tick).is_equal(44641)
	assert_int(restored.random.base_seed).is_equal(123456789)
	assert_bool(restored.flags.has(&"met_director")).is_true()
	assert_int(typeof(restored.flags.keys()[0])).is_equal(TYPE_STRING_NAME)
	assert_int(typeof(restored.flags[&"briefings_heard"])).is_equal(TYPE_INT)
	assert_that(restored.flags[&"last_world"]).is_equal("P3X-118")


## Missing sections fall back to defaults instead of failing.
func test_from_dict_with_empty_data_uses_defaults() -> void:
	var state := GameState.from_dict({})
	assert_int(state.clock.tick).is_equal(0)
	assert_bool(state.clock.is_paused).is_true()
	assert_int(state.random.base_seed).is_equal(0)
	assert_dict(state.flags).is_empty()


## ClockState and RandomState round-trip on their own.
func test_sub_states_round_trip() -> void:
	var clock := ClockState.new()
	clock.tick = 99
	clock.speed_index = 2
	clock.is_paused = false
	var clock_data := clock.to_dict()
	var restored_clock := ClockState.from_dict(_json_round_trip(clock_data))
	assert_dict(restored_clock.to_dict()).is_equal(clock_data)
	var random := RandomState.new()
	random.base_seed = 77
	var random_data := random.to_dict()
	var restored_random := RandomState.from_dict(_json_round_trip(random_data))
	assert_dict(restored_random.to_dict()).is_equal(random_data)


## validate_dict accepts int and float flags up to 2^53 in absolute value and rejects
## larger ones, whether they arrive as ints or as whole floats.
func test_validate_rejects_flags_beyond_two_pow_53() -> void:
	var limit: int = JsonLimits.MAX_EXACT_INT
	var base := _sample_state().to_dict()
	for value: Variant in [limit, -limit, float(limit), -float(limit)]:
		var data := base.duplicate(true)
		data["flags"]["edge"] = value
		var errors := GameState.validate_dict(data)
		assert_array(errors).override_failure_message(str(value)).is_empty()
	for value: Variant in [limit + 1, -limit - 1, float(limit) + 2.0, 1e300]:
		var data := base.duplicate(true)
		data["flags"]["edge"] = value
		var errors := GameState.validate_dict(data)
		assert_array(errors).override_failure_message(str(value)).contains(
			["flag 'edge' is not a bool, String or whole number"]
		)


## A state with a LOCKED Ring, a log of three, fractional energy and two
## world statuses, at clock tick 500.
func _gate_power_worlds_state() -> GameState:
	var state := GameState.new_game(987654321, BalanceConfig.new())
	state.clock.tick = 500
	var coordinates: Array[int] = [1, 2, 3, 4, 5, 6, 7]
	var address := GateAddress.create(coordinates, 30)
	state.gate.mode = GateState.RingMode.LOCKED
	state.gate.current_address = address
	state.gate.dial_started_tick = 400
	state.gate.lock_started_tick = 402
	state.gate.lock_energy_mwh = 1.0 / 3.0
	state.gate.connected_world_id = &"abydos"
	for kind: DialOutcome.Kind in [
		DialOutcome.Kind.NO_GATE, DialOutcome.Kind.ORIGIN_REJECTED, DialOutcome.Kind.LOCK
	]:
		var entry := DialLogEntry.new()
		entry.tick = 100 + kind
		entry.address = address
		entry.outcome = kind
		entry.energy_spent_mwh = 0.1 + 0.2
		entry.world_id = &"" if kind == DialOutcome.Kind.NO_GATE else &"abydos"
		state.gate.dial_log.append(entry)
	state.power.charge_rates[&"room_1"] = 26
	state.power.stored_mwh = 0.1 + 0.2
	state.worlds.statuses[&"abydos"] = WorldsState.WorldStatus.LOCKED
	state.worlds.statuses[&"chulak"] = WorldsState.WorldStatus.LOCKED
	return state


## new_game() derives the galaxy seed from the base seed, sets the generator version and,
## without a balance, leaves power at zero; the Ring starts idle with nothing queued.
func test_new_game_gate_power_worlds_defaults() -> void:
	var state := GameState.new_game(42)
	assert_int(state.worlds.galaxy_seed).is_equal(RandomState.derive_seed(42, &"galaxy"))
	assert_int(state.worlds.generator_version).is_equal(WorldGenerator.GENERATOR_VERSION)
	assert_dict(state.worlds.statuses).is_empty()
	assert_dict(state.power.to_dict()).is_equal(PowerState.new().to_dict())
	assert_dict(state.gate.to_dict()).is_equal(GateState.new().to_dict())
	assert_array(GameState.validate_dict(state.to_dict())).is_empty()


## new_game() with a balance starts power from it.
func test_new_game_with_balance_starts_power() -> void:
	var balance := BalanceConfig.new()
	var state := GameState.new_game(42, balance)
	assert_dict(state.power.to_dict()).is_equal(PowerState.starting(balance).to_dict())


## The sections are saved under their names; the event outbox is not.
func test_to_dict_sections() -> void:
	var data := _gate_power_worlds_state().to_dict()
	assert_array(data.keys()).contains_exactly_in_any_order(
		[
			"clock",
			"random",
			"flags",
			"gate",
			"power",
			"budget",
			"base",
			"worlds",
			"archive",
			"address_book",
			"operations_log"
		]
	)
	assert_bool(_is_json_safe(data)).is_true()


## The full state survives a full-precision JSON round trip with an equal dictionary.
func test_gate_power_worlds_json_round_trip() -> void:
	var data := _gate_power_worlds_state().to_dict()
	assert_array(GameState.validate_dict(data)).is_empty()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data, "", true, true))
	assert_array(GameState.validate_dict(parsed)).is_empty()
	assert_dict(GameState.from_dict(parsed).to_dict()).is_equal(data)


## validate_dict requires the new sections, prefixes their errors, and rejects Ring ticks
## later than the clock tick.
func test_validate_gate_power_worlds() -> void:
	var good := _gate_power_worlds_state().to_dict()
	for key: String in ["gate", "power", "worlds"]:
		var missing := good.duplicate(true)
		missing.erase(key)
		assert_array(GameState.validate_dict(missing)).is_equal(["missing '%s'" % key])
		var wrong := good.duplicate(true)
		wrong[key] = []
		assert_array(GameState.validate_dict(wrong)).is_equal(["'%s' is not an object" % key])
	var bad_power := good.duplicate(true)
	bad_power["power"]["stored_mwh"] = ExactFloat.encode(-1.0)
	assert_array(GameState.validate_dict(bad_power)).is_equal(
		["power: 'stored_mwh' is not an exact float, finite and at least 0"]
	)
	for key: String in ["dial_started_tick", "lock_started_tick"]:
		var late := good.duplicate(true)
		late["gate"][key] = 501
		late["gate"]["lock_started_tick"] = 501
		assert_array(GameState.validate_dict(late)).contains(
			["gate: '%s' is later than the clock tick" % key]
		)
	var at_clock := good.duplicate(true)
	at_clock["gate"]["lock_started_tick"] = 500
	assert_array(GameState.validate_dict(at_clock)).is_empty()


## validate_dict rejects a Dial Log entry whose tick is later than the clock tick.
func test_validate_rejects_dial_log_tick_after_clock() -> void:
	var data := _gate_power_worlds_state().to_dict()
	data["gate"]["dial_log"][1]["tick"] = 501
	assert_array(GameState.validate_dict(data)).is_equal(
		["gate: dial_log 1 'tick' is later than the clock tick"]
	)
	data["gate"]["dial_log"][1]["tick"] = 500
	assert_array(GameState.validate_dict(data)).is_empty()


## A v4-style state with "intel" and "workbench" still validates, and from_dict() drops them.
func test_old_intel_and_workbench_sections_are_ignored() -> void:
	var data := _gate_power_worlds_state().to_dict()
	var old := data.duplicate(true)
	old["intel"] = {"clues": []}
	old["workbench"] = {"origin_glyph": -1, "constraints": []}
	assert_array(GameState.validate_dict(old)).is_empty()
	assert_dict(GameState.from_dict(old).to_dict()).is_equal(data)


## Archive and Address Book ticks may not be later than the clock, and both sections are
## required and checked with their own validate_dict().
func test_validate_archive_and_address_book() -> void:
	var state := GameState.new_game(3)
	state.clock.tick = 100
	state.archive.add(&"doc_note", 100)
	var entry := AddressEntry.create("3-17-0-22-9-14-30-5", AddressEntry.Source.DIALED, &"")
	entry.last_outcome = DialOutcome.Kind.NO_GATE
	entry.last_dialed_tick = 100
	state.address_book.entries.append(entry)
	var good := state.to_dict()
	assert_array(GameState.validate_dict(good)).is_empty()
	assert_dict(GameState.from_dict(good).to_dict()).is_equal(good)
	for key: String in ["archive", "address_book"]:
		var missing := good.duplicate(true)
		missing.erase(key)
		assert_array(GameState.validate_dict(missing)).is_equal(["missing '%s'" % key])
	var late := good.duplicate(true)
	late["archive"]["received_tick"]["doc_note"] = 101
	late["address_book"]["entries"][0]["last_dialed_tick"] = 101
	(
		assert_array(GameState.validate_dict(late))
		. is_equal(
			[
				"archive: received_tick of 'doc_note' is later than the clock tick",
				"address_book: entries 0 'last_dialed_tick' is later than the clock tick",
			]
		)
	)
	var bad := good.duplicate(true)
	bad["archive"]["read"]["doc_other"] = true
	assert_str(GameState.validate_dict(bad)[0]).starts_with("archive: read names 'doc_other'")
