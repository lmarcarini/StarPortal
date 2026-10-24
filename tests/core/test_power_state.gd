## Tests for PowerState: starting values from the balance, exact float round trips, the
## capacitor bank counts and validate_dict() errors.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy (starting plant and storage),
## technical-architecture.md#data-model
extends GdUnitTestSuite


## starting() takes capacity and output from the balance and stores nothing.
func test_starting_uses_balance() -> void:
	var balance := BalanceConfig.new()
	balance.starting_capacity_mwh = 512.5
	balance.starting_plant_output_mw = 42.25
	var power := PowerState.starting(balance)
	assert_float(power.capacity_mwh).is_equal(512.5)
	assert_float(power.plant_output_mw).is_equal(42.25)
	assert_float(power.stored_mwh).is_equal(0.0)


## A new game: the 30 MW plant and no capacitors, no bank installed and no install running.
func test_starting_with_default_balance() -> void:
	var data := PowerState.starting(BalanceConfig.new()).to_dict()
	(
		assert_dict(data)
		. is_equal(
			{
				"stored_mwh": "0000000000000000",
				"capacity_mwh": "0000000000000000",
				"plant_output_mw": "403e000000000000",
				"banks_installed": 0,
				"install_ticks_left": 0,
			}
		)
	)


## The bank count and the install's ticks left survive a JSON round trip as ints.
func test_counts_round_trip() -> void:
	var power := PowerState.new()
	power.banks_installed = 1
	power.install_ticks_left = 200
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(power.to_dict()))
	assert_array(PowerState.validate_dict(parsed)).is_empty()
	var restored := PowerState.from_dict(parsed)
	assert_int(restored.banks_installed).is_equal(1)
	assert_int(restored.install_ticks_left).is_equal(200)
	assert_dict(restored.to_dict()).is_equal(power.to_dict())


## validate_dict rejects a missing, fractional, negative, too large or non-numeric count.
func test_validate_count_errors() -> void:
	var good := PowerState.new().to_dict()
	for key: String in ["banks_installed", "install_ticks_left"]:
		for bad: Variant in [-1, 1.5, "3", null, true, 1e300, INF]:
			var data := good.duplicate()
			data[key] = bad
			(
				assert_array(PowerState.validate_dict(data))
				. override_failure_message("%s = %s" % [key, str(bad)])
				. is_equal(["'%s' is not a whole number of at least 0" % key])
			)
		var missing := good.duplicate()
		missing.erase(key)
		assert_array(PowerState.validate_dict(missing)).is_equal(["missing '%s'" % key])
		var whole_float := good.duplicate()
		whole_float[key] = 7.0
		assert_array(PowerState.validate_dict(whole_float)).is_empty()


## Fractional values, including one Godot's JSON parser cannot read back from decimal
## (1.0 / 300.0), survive a JSON round trip bit for bit, and so does the sign of -0.0.
func test_fractional_values_round_trip_exactly() -> void:
	var power := PowerState.new()
	power.stored_mwh = 0.1 + 0.2
	power.capacity_mwh = 400.0 / 3.0
	power.plant_output_mw = 1.0 / 300.0
	var data := power.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data, "", true, true))
	assert_array(PowerState.validate_dict(parsed)).is_empty()
	var restored := PowerState.from_dict(parsed)
	assert_bool(restored.stored_mwh == 0.1 + 0.2).is_true()
	assert_bool(restored.capacity_mwh == 400.0 / 3.0).is_true()
	assert_bool(restored.plant_output_mw == 1.0 / 300.0).is_true()
	power.stored_mwh = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0x80]).decode_double(0)
	var zero_data: Dictionary = JSON.parse_string(JSON.stringify(power.to_dict()))
	var zero := PowerState.from_dict(zero_data)
	var zero_bytes := PackedFloat64Array([zero.stored_mwh]).to_byte_array()
	assert_int(zero_bytes[7]).is_equal(0x80)
	assert_dict(restored.to_dict()).is_equal(data)


## validate_dict rejects missing, non-numeric, negative and non-finite values, and more
## stored than the capacity.
func test_validate_errors() -> void:
	var good := {
		"stored_mwh": ExactFloat.encode(10.0),
		"capacity_mwh": ExactFloat.encode(400.0),
		"plant_output_mw": ExactFloat.encode(30.0),
		"banks_installed": 1,
		"install_ticks_left": 0,
	}
	assert_array(PowerState.validate_dict(good)).is_empty()
	for key: String in ["stored_mwh", "capacity_mwh", "plant_output_mw"]:
		var bad_values: Array = ["1", null, true, 10.0, "4079000000000000 ", "4079000000000OOO"]
		for bad_float: float in [-0.001, -1e-300, INF, -INF, NAN]:
			bad_values.append(ExactFloat.encode(bad_float))
		for bad: Variant in bad_values:
			var data := good.duplicate()
			data[key] = bad
			(
				assert_array(PowerState.validate_dict(data))
				. override_failure_message("%s = %s" % [key, str(bad)])
				. contains(["'%s' is not an exact float, finite and at least 0" % key])
			)
		var missing := good.duplicate()
		missing.erase(key)
		assert_array(PowerState.validate_dict(missing)).contains(["missing '%s'" % key])
	var overfull := good.duplicate()
	overfull["stored_mwh"] = ExactFloat.encode(400.00000000000006)
	assert_array(PowerState.validate_dict(overfull)).is_equal(
		["'stored_mwh' is above 'capacity_mwh'"]
	)
	var full := good.duplicate()
	full["stored_mwh"] = ExactFloat.encode(400.0)
	assert_array(PowerState.validate_dict(full)).is_empty()
