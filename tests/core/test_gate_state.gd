## Tests for GateState and DialLogEntry: dict format, JSON round trips, and validate_dict()
## errors for wrong types, unknown names, bad energy, malformed addresses and Ring fields
## that do not fit the mode.
## Bible: technical-architecture.md#data-model, technical-architecture.md#state-machines,
## gate-and-address-spec.md#player-tools (Dial Log)
extends GdUnitTestSuite


func _address(first: int) -> GateAddress:
	var coordinates: Array[int] = []
	for offset: int in GateAddress.COORDINATE_COUNT:
		coordinates.append(first + offset)
	return GateAddress.create(coordinates, 35)


func _entry(outcome: DialOutcome.Kind, world_id: StringName) -> DialLogEntry:
	var entry := DialLogEntry.new()
	entry.tick = 120
	entry.address = _address(3)
	entry.outcome = outcome
	entry.energy_spent_mwh = 0.1 + 0.2
	entry.world_id = world_id
	return entry


## A LOCKED Ring with a three-entry log.
func _locked_gate() -> GateState:
	var gate := GateState.new()
	gate.mode = GateState.RingMode.LOCKED
	gate.current_address = _address(10)
	gate.dial_started_tick = 200
	gate.lock_energy_mwh = 1.0 / 3.0
	gate.connected_world_id = &"p3x_118"
	gate.lock_started_tick = 202
	gate.is_hostile = true
	gate.dial_log.append(_entry(DialOutcome.Kind.NO_GATE, &""))
	gate.dial_log.append(_entry(DialOutcome.Kind.BLOCKED, &"abydos"))
	gate.dial_log.append(_entry(DialOutcome.Kind.HOSTILE_LOCK, &"p3x_118"))
	return gate


func _json_round_trip(data: Dictionary) -> Dictionary:
	var parsed: Variant = JSON.parse_string(JSON.stringify(data, "", true, true))
	assert_bool(parsed is Dictionary).is_true()
	if not parsed is Dictionary:
		return {}
	return parsed


## Asserts that [param data] with [param key] set to [param value] (or erased, for null
## with [param erase]) fails with an error containing [param expected].
func _assert_gate_error(key: String, value: Variant, expected: String, erase := false) -> void:
	var data := _json_round_trip(_locked_gate().to_dict())
	if erase:
		data.erase(key)
	else:
		data[key] = value
	var errors := GateState.validate_dict(data)
	var label := "%s = %s: %s" % [key, str(value), str(errors)]
	assert_str("\n".join(errors)).override_failure_message(label).contains(expected)


## A new GateState is IDLE with nothing set, and its dict has the contract's shape.
func test_defaults_and_dict_shape() -> void:
	var data := GateState.new().to_dict()
	(
		assert_dict(data)
		. is_equal(
			{
				"mode": "idle",
				"current_address": null,
				"dial_started_tick": -1,
				"lock_energy_mwh": "0000000000000000",
				"connected_world_id": "",
				"lock_started_tick": -1,
				"is_hostile": false,
				"dial_log": [],
				"incoming": {},
			}
		)
	)
	assert_array(GateState.validate_dict(data)).is_empty()


## Modes are saved as "idle", "dialing" and "locked".
func test_mode_names() -> void:
	var gate := GateState.new()
	var names: Array[String] = []
	for mode: GateState.RingMode in [
		GateState.RingMode.IDLE, GateState.RingMode.DIALING, GateState.RingMode.LOCKED
	]:
		gate.mode = mode
		names.append(str(gate.to_dict()["mode"]))
	assert_array(names).is_equal(["idle", "dialing", "locked"])


## A LOCKED Ring with its log survives a full-precision JSON round trip exactly.
func test_locked_gate_json_round_trip() -> void:
	var data := _locked_gate().to_dict()
	assert_array(GateState.validate_dict(data)).is_empty()
	var parsed := _json_round_trip(data)
	assert_array(GateState.validate_dict(parsed)).is_empty()
	var restored := GateState.from_dict(parsed)
	assert_dict(restored.to_dict()).is_equal(data)
	assert_int(restored.mode).is_equal(GateState.RingMode.LOCKED)
	assert_bool(restored.current_address.equals(_address(10))).is_true()
	assert_int(typeof(restored.dial_started_tick)).is_equal(TYPE_INT)
	assert_bool(restored.lock_energy_mwh == 1.0 / 3.0).is_true()
	assert_int(restored.dial_log[2].outcome).is_equal(DialOutcome.Kind.HOSTILE_LOCK)
	assert_str(restored.dial_log[1].world_id).is_equal(&"abydos")
	assert_bool(restored.dial_log[0].energy_spent_mwh == 0.1 + 0.2).is_true()


## A DialLogEntry stores its outcome as the DialOutcome key and its world id as a string.
func test_dial_log_entry_dict_shape() -> void:
	var data := _entry(DialOutcome.Kind.ORIGIN_REJECTED, &"chulak").to_dict()
	(
		assert_dict(data)
		. is_equal(
			{
				"tick": 120,
				"address": {"seals": [3, 4, 5, 6, 7, 8, 9, 35]},
				"outcome": "origin_rejected",
				"energy_spent_mwh": ExactFloat.encode(0.1 + 0.2),
				"world_id": "chulak",
			}
		)
	)
	assert_array(DialLogEntry.validate_dict(data)).is_empty()
	assert_dict(DialLogEntry.from_dict(_json_round_trip(data)).to_dict()).is_equal(data)


## DialLogEntry.validate_dict rejects wrong types, unknown outcomes, bad energy, malformed
## addresses and world ids that do not fit the outcome.
func test_dial_log_entry_validate_errors() -> void:
	var good := _entry(DialOutcome.Kind.LOCK, &"abydos").to_dict()
	var cases: Array[Array] = [
		["tick", -1, "tick"],
		["tick", 1.5, "tick"],
		["tick", "5", "tick"],
		["address", "3-4-5", "'address' is not an object"],
		["address", {"seals": [1, 1, 2, 3, 4, 5, 6, 7]}, "address: seal 2 repeats"],
		["outcome", "warp", "outcome"],
		["outcome", 3, "outcome"],
		["energy_spent_mwh", ExactFloat.encode(-0.5), "energy_spent_mwh"],
		["energy_spent_mwh", ExactFloat.encode(INF), "energy_spent_mwh"],
		["energy_spent_mwh", ExactFloat.encode(NAN), "energy_spent_mwh"],
		["energy_spent_mwh", 0.5, "energy_spent_mwh"],
		["energy_spent_mwh", "1", "energy_spent_mwh"],
		["world_id", 7, "world_id"],
		["world_id", "", "'world_id' is empty"],
	]
	for case: Array in cases:
		var data := good.duplicate(true)
		data[case[0]] = case[1]
		var errors := "\n".join(DialLogEntry.validate_dict(data))
		assert_str(errors).override_failure_message(str(case)).contains(str(case[2]))
	var no_gate := _entry(DialOutcome.Kind.NO_GATE, &"abydos").to_dict()
	assert_array(DialLogEntry.validate_dict(no_gate)).contains(
		["'world_id' is not empty for a \"no_gate\" outcome"]
	)
	for key: String in good:
		var missing := good.duplicate(true)
		missing.erase(key)
		assert_array(DialLogEntry.validate_dict(missing)).contains(["missing '%s'" % key])


## GateState.validate_dict rejects wrong types, unknown modes, bad energy and malformed
## addresses in the current dial and the log.
func test_gate_validate_type_errors() -> void:
	_assert_gate_error("mode", "charging", "'mode' is not one of")
	_assert_gate_error("mode", 2, "'mode' is not one of")
	_assert_gate_error("current_address", "1-2-3", "'current_address' is not null or an object")
	_assert_gate_error("current_address", {"seals": [1, 2]}, "current_address: 'seals' has 2")
	_assert_gate_error("dial_started_tick", -2, "dial_started_tick")
	_assert_gate_error("lock_started_tick", 2.5, "lock_started_tick")
	_assert_gate_error("lock_energy_mwh", ExactFloat.encode(-1.0), "lock_energy_mwh")
	_assert_gate_error("lock_energy_mwh", ExactFloat.encode(INF), "lock_energy_mwh")
	_assert_gate_error("lock_energy_mwh", 2.5, "lock_energy_mwh")
	_assert_gate_error("connected_world_id", 4, "connected_world_id")
	_assert_gate_error("is_hostile", 1, "'is_hostile' is not a bool")
	_assert_gate_error("dial_log", [{"tick": 1}], "dial_log 0: missing 'outcome'")
	_assert_gate_error("dial_log", 3, "'dial_log' is not an array")
	for key: String in GateState.new().to_dict():
		_assert_gate_error(key, null, "missing '%s'" % key, true)


## A dict for [param mode] with the Ring fields of a dial (address and dial tick) and,
## optionally, of a lock.
func _ring(mode: String, dialed: bool, locked: bool) -> Dictionary:
	var data := GateState.new().to_dict()
	data["mode"] = mode
	if dialed:
		data["current_address"] = _address(1).to_dict()
		data["dial_started_tick"] = 10
	if locked:
		data["connected_world_id"] = "abydos"
		data["lock_started_tick"] = 12
	return data


## The Ring fields must fit the mode: IDLE has none, DIALING has an address and a dial tick
## only, LOCKED has all of them with the lock tick not before the dial tick.
func test_gate_validate_ring_consistency() -> void:
	assert_array(GateState.validate_dict(_ring("idle", false, false))).is_empty()
	assert_array(GateState.validate_dict(_ring("dialing", true, false))).is_empty()
	assert_array(GateState.validate_dict(_ring("locked", true, true))).is_empty()
	var idle_with_address := _ring("idle", false, false)
	idle_with_address["current_address"] = _address(1).to_dict()
	assert_array(GateState.validate_dict(idle_with_address)).is_equal(
		["'current_address' is set while \"idle\""]
	)
	assert_array(GateState.validate_dict(_ring("idle", true, false))).contains(
		["'dial_started_tick' is set while \"idle\""]
	)
	var dialing_without_address := _ring("dialing", true, false)
	dialing_without_address["current_address"] = null
	assert_array(GateState.validate_dict(dialing_without_address)).is_equal(
		["'current_address' is not set while \"dialing\""]
	)
	assert_array(GateState.validate_dict(_ring("dialing", true, true))).contains(
		[
			"'connected_world_id' is set while \"dialing\"",
			"'lock_started_tick' is set while \"dialing\""
		]
	)
	var locked_without_world := _ring("locked", true, true)
	locked_without_world["connected_world_id"] = ""
	assert_array(GateState.validate_dict(locked_without_world)).is_equal(
		["'connected_world_id' is not set while \"locked\""]
	)
	var locked_without_tick := _ring("locked", true, true)
	locked_without_tick["lock_started_tick"] = -1
	assert_array(GateState.validate_dict(locked_without_tick)).is_equal(
		["'lock_started_tick' is not set while \"locked\""]
	)


## Hostility belongs to a lock, and a lock cannot open before its dial started.
func test_gate_validate_hostile_and_tick_order() -> void:
	var hostile_dialing := _ring("dialing", true, false)
	hostile_dialing["is_hostile"] = true
	assert_array(GateState.validate_dict(hostile_dialing)).is_equal(
		["'is_hostile' is true while \"dialing\""]
	)
	var early_lock := _ring("locked", true, true)
	early_lock["lock_started_tick"] = 9
	assert_array(GateState.validate_dict(early_lock)).is_equal(
		["'lock_started_tick' is before 'dial_started_tick'"]
	)


## from_dict() keeps the defaults for unreadable values instead of failing: a non-bool
## "is_hostile" and an unencoded energy.
func test_from_dict_tolerates_unreadable_values() -> void:
	for hostile: Variant in ["true", 1, null]:
		var data := _locked_gate().to_dict()
		data["is_hostile"] = hostile
		data["lock_energy_mwh"] = 12.5
		var gate := GateState.from_dict(data)
		assert_bool(gate.is_hostile).override_failure_message(str(hostile)).is_false()
		assert_float(gate.lock_energy_mwh).is_equal(0.0)
	var entry_data := _entry(DialOutcome.Kind.LOCK, &"abydos").to_dict()
	entry_data["energy_spent_mwh"] = "3FD5555555555555"
	assert_float(DialLogEntry.from_dict(entry_data).energy_spent_mwh).is_equal(0.0)
