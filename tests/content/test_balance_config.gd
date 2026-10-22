## Tests that BalanceConfig's gate and power fields default to the bible's starting values and
## that data/balance/balance_config.tres holds the same values.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy, technical-architecture.md#data-model
extends GdUnitTestSuite

const DATA_PATH: String = "res://data/balance/balance_config.tres"
const EXPECTED: Dictionary[String, Variant] = {
	"lock_energy_base_mwh": 300.0,
	"lock_reference_distance_ly": 10000.0,
	"seal_multiplier_8": 1.0,
	"seal_multiplier_9": 25.0,
	"seal_multiplier_10": 400.0,
	"open_drain_mw_8": 20.0,
	"open_drain_mw_9": 200.0,
	"starting_plant_output_mw": 30.0,
	"starting_capacity_mwh": 400.0,
	"cost_fraction_no_gate": 0.10,
	"cost_fraction_blocked": 0.25,
	"cost_fraction_origin_rejected": 0.25,
	"dial_duration_ticks": 2,
	"max_open_ticks": 60,
}


func _check(balance: BalanceConfig, label: String) -> void:
	for field: String in EXPECTED:
		var value: Variant = balance.get(field)
		assert_that(value).override_failure_message("%s %s" % [label, field]).is_equal(
			EXPECTED[field]
		)
		assert_int(typeof(value)).override_failure_message("%s %s" % [label, field]).is_equal(
			typeof(EXPECTED[field])
		)


## A new BalanceConfig has the bible's starting values.
func test_defaults_are_bible_values() -> void:
	_check(BalanceConfig.new(), "default")


## The shipped balance file has the same values.
func test_data_file_matches() -> void:
	var balance := load(DATA_PATH) as BalanceConfig
	assert_that(balance).is_not_null()
	assert_that(balance.id).is_equal(BalanceConfig.BALANCE_ID)
	_check(balance, "data")
