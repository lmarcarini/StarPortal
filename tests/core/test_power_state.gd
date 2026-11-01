## Tests for PowerState: a new game's empty capacitors, exact float round trips of the stored
## energy, charge rates round trips and validate_dict() errors.
## Bible: docs/content/m2-base.md section 3, technical-architecture.md#data-model
extends GdUnitTestSuite


## A new game stores nothing and has no bank.
func test_starting_with_default_balance() -> void:
	var data := PowerState.starting(BalanceConfig.new()).to_dict()
	assert_dict(data).is_equal({"stored_mwh": "0000000000000000", "charge_rates": {}})


## Charge rates survive a JSON round trip as ints keyed by room id.
func test_charge_rates_round_trip() -> void:
	var power := PowerState.new()
	power.charge_rates[&"room_7"] = 26
	power.charge_rates[&"room_9"] = 0
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(power.to_dict()))
	assert_array(PowerState.validate_dict(parsed)).is_empty()
	var restored := PowerState.from_dict(parsed)
	assert_int(restored.charge_rates[&"room_7"]).is_equal(26)
	assert_int(restored.charge_rates[&"room_9"]).is_equal(0)
	assert_dict(restored.to_dict()).is_equal(power.to_dict())


## Fractional stored energy survives a JSON round trip bit for bit, and so does -0.0's sign.
func test_fractional_values_round_trip_exactly() -> void:
	var power := PowerState.new()
	power.stored_mwh = 0.1 + 0.2
	var data := power.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data, "", true, true))
	var restored := PowerState.from_dict(parsed)
	assert_bool(restored.stored_mwh == 0.1 + 0.2).is_true()
	power.stored_mwh = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0x80]).decode_double(0)
	var zero_data: Dictionary = JSON.parse_string(JSON.stringify(power.to_dict()))
	var zero := PowerState.from_dict(zero_data)
	var zero_bytes := PackedFloat64Array([zero.stored_mwh]).to_byte_array()
	assert_int(zero_bytes[7]).is_equal(0x80)


## validate_dict rejects a bad or missing stored energy and bad charge rates.
func test_validate_errors() -> void:
	var good := {"stored_mwh": ExactFloat.encode(10.0), "charge_rates": {"room_1": 30}}
	assert_array(PowerState.validate_dict(good)).is_empty()
	var bad_values: Array = ["1", null, true, 10.0, "4079000000000OOO"]
	for bad_float: float in [-0.001, INF, NAN]:
		bad_values.append(ExactFloat.encode(bad_float))
	for bad: Variant in bad_values:
		var data := good.duplicate()
		data["stored_mwh"] = bad
		assert_array(PowerState.validate_dict(data)).override_failure_message(str(bad)).is_equal(
			["'stored_mwh' is not an exact float, finite and at least 0"]
		)
	var missing := good.duplicate()
	missing.erase("stored_mwh")
	assert_array(PowerState.validate_dict(missing)).is_equal(["missing 'stored_mwh'"])
	for bad_rate: Variant in [-1, 1.5, "3", null]:
		var data := good.duplicate()
		data["charge_rates"] = {"room_1": bad_rate}
		assert_array(PowerState.validate_dict(data)).is_equal(
			["'charge_rates.room_1' is not a whole number of at least 0"]
		)
	var no_rates := good.duplicate()
	no_rates["charge_rates"] = []
	assert_array(PowerState.validate_dict(no_rates)).is_equal(["'charge_rates' is not an object"])
