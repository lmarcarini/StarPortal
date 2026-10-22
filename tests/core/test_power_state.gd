## Tests for PowerState: starting values from the balance, exact float round trips and
## validate_dict() errors.
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


## The bible's starting plant and storage: 30 MW and 400 MWh.
func test_starting_with_default_balance() -> void:
	var data := PowerState.starting(BalanceConfig.new()).to_dict()
	assert_dict(data).is_equal({"stored_mwh": 0.0, "capacity_mwh": 400.0, "plant_output_mw": 30.0})


## Fractional values survive a full-precision JSON round trip bit for bit.
func test_fractional_values_round_trip_exactly() -> void:
	var power := PowerState.new()
	power.stored_mwh = 0.1 + 0.2
	power.capacity_mwh = 400.0 / 3.0
	power.plant_output_mw = 1.0 / 3.0
	var data := power.to_dict()
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data, "", true, true))
	assert_array(PowerState.validate_dict(parsed)).is_empty()
	var restored := PowerState.from_dict(parsed)
	assert_bool(restored.stored_mwh == 0.1 + 0.2).is_true()
	assert_bool(restored.capacity_mwh == 400.0 / 3.0).is_true()
	assert_bool(restored.plant_output_mw == 1.0 / 3.0).is_true()
	assert_dict(restored.to_dict()).is_equal(data)


## validate_dict rejects missing, non-numeric, negative and non-finite values, and more
## stored than the capacity.
func test_validate_errors() -> void:
	var good := {"stored_mwh": 10.0, "capacity_mwh": 400.0, "plant_output_mw": 30.0}
	assert_array(PowerState.validate_dict(good)).is_empty()
	for key: String in good:
		for bad: Variant in ["1", null, true, -0.001, INF, -INF, NAN]:
			var data := good.duplicate()
			data[key] = bad
			(
				assert_array(PowerState.validate_dict(data))
				. override_failure_message("%s = %s" % [key, str(bad)])
				. contains(["'%s' is not a finite number of at least 0" % key])
			)
		var missing := good.duplicate()
		missing.erase(key)
		assert_array(PowerState.validate_dict(missing)).contains(["missing '%s'" % key])
	var overfull := good.duplicate()
	overfull["stored_mwh"] = 400.5
	assert_array(PowerState.validate_dict(overfull)).is_equal(
		["'stored_mwh' is above 'capacity_mwh'"]
	)
	var full := good.duplicate()
	full["stored_mwh"] = 400.0
	assert_array(PowerState.validate_dict(full)).is_empty()
