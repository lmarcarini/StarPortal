## Tests for PowerMath: the open drain, net flow, one-tick clamping and ticks_until_mwh()
## against a tick-by-tick simulation.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#base-building-and-power
extends GdUnitTestSuite

const TOLERANCE: float = 1e-9


## Steps the bank tick by tick until it holds [param target]; the truth ticks_until_mwh()
## must match. Returns -1 after [param limit] ticks.
func _simulate(stored: float, target: float, net: float, limit: int) -> int:
	if stored >= target:
		return 0
	for tick: int in range(1, limit + 1):
		stored = PowerMath.step_stored_mwh(stored, target, net)
		if stored >= target:
			return tick
	return -1


func _gate(mode: GateState.RingMode) -> GateState:
	var gate := GateState.new()
	gate.mode = mode
	return gate


## The drain is the 8-seal drain only while the Ring is LOCKED.
func test_drain_only_while_locked() -> void:
	var balance := BalanceConfig.new()
	assert_float(PowerMath.drain_mw(_gate(GateState.RingMode.LOCKED), balance)).is_equal(20.0)
	assert_float(PowerMath.drain_mw(_gate(GateState.RingMode.IDLE), balance)).is_equal(0.0)
	assert_float(PowerMath.drain_mw(_gate(GateState.RingMode.DIALING), balance)).is_equal(0.0)


## The drain follows the balance.
func test_drain_uses_balance() -> void:
	var balance := BalanceConfig.new()
	balance.open_drain_mw_8 = 12.5
	assert_float(PowerMath.drain_mw(_gate(GateState.RingMode.LOCKED), balance)).is_equal(12.5)


## Net flow is output minus drain, negative when the drain wins.
func test_net_flow() -> void:
	assert_float(PowerMath.net_flow_mw(30.0, 20.0)).is_equal(10.0)
	assert_float(PowerMath.net_flow_mw(5.0, 20.0)).is_equal(-15.0)
	assert_float(PowerMath.net_flow_mw(30.0, 0.0)).is_equal(30.0)


## One tick is one minute: net / 60 MWh.
func test_step_converts_mw_to_mwh_per_tick() -> void:
	assert_float(PowerMath.step_stored_mwh(100.0, 400.0, 30.0)).is_equal(100.5)
	assert_float(PowerMath.step_stored_mwh(100.0, 400.0, -30.0)).is_equal(99.5)


## Storage never goes above capacity or below zero.
func test_step_clamps_to_zero_and_capacity() -> void:
	assert_float(PowerMath.step_stored_mwh(399.9, 400.0, 30.0)).is_equal(400.0)
	assert_float(PowerMath.step_stored_mwh(0.1, 400.0, -30.0)).is_equal(0.0)
	assert_float(PowerMath.step_stored_mwh(400.0, 400.0, 30.0)).is_equal(400.0)


## Zero capacity and zero output give 0, never NaN or infinity.
func test_step_with_zero_capacity_and_zero_output() -> void:
	assert_float(PowerMath.step_stored_mwh(0.0, 0.0, 30.0)).is_equal(0.0)
	assert_float(PowerMath.step_stored_mwh(0.0, 400.0, 0.0)).is_equal(0.0)
	assert_float(PowerMath.step_stored_mwh(0.0, 0.0, 0.0)).is_equal(0.0)


## Huge finite inputs stay finite and inside 0..capacity.
func test_step_stays_finite_for_huge_inputs() -> void:
	var huge: float = 1.0e308
	for net: float in [huge, -huge, 0.0]:
		var result: float = PowerMath.step_stored_mwh(huge, huge, net)
		assert_bool(is_finite(result)).is_true()
		assert_bool(result >= 0.0 and result <= huge).is_true()


## An already-reached target takes no ticks, whatever the flow.
func test_ticks_until_already_reached() -> void:
	assert_int(PowerMath.ticks_until_mwh(300.0, 300.0, 30.0)).is_equal(0)
	assert_int(PowerMath.ticks_until_mwh(350.0, 300.0, 30.0)).is_equal(0)
	assert_int(PowerMath.ticks_until_mwh(350.0, 300.0, -5.0)).is_equal(0)


## No gain means never.
func test_ticks_until_never_when_net_not_positive() -> void:
	assert_int(PowerMath.ticks_until_mwh(0.0, 300.0, 0.0)).is_equal(-1)
	assert_int(PowerMath.ticks_until_mwh(0.0, 300.0, -10.0)).is_equal(-1)


## A gain too small to finish within MAX_TICKS, or to overflow, is never.
func test_ticks_until_never_when_too_slow() -> void:
	assert_int(PowerMath.ticks_until_mwh(0.0, 400.0, 1.0e-300)).is_equal(-1)
	assert_int(PowerMath.ticks_until_mwh(-1.0e308, 1.0e308, 1.0e-300)).is_equal(-1)


## The bible's 30 MW plant fills 300 MWh in 600 ticks.
func test_ticks_until_known_values() -> void:
	assert_int(PowerMath.ticks_until_mwh(0.0, 300.0, 30.0)).is_equal(600)
	assert_int(PowerMath.ticks_until_mwh(0.0, 400.0, 30.0)).is_equal(800)
	assert_int(PowerMath.ticks_until_mwh(0.0, 0.25, 30.0)).is_equal(1)


## 1/6 MWh added 1800 times falls a hair short of 300, so stepping needs 1801 ticks even
## though 300 / (1/6) is exactly 1800. ticks_until_mwh() must say what stepping says.
func test_ticks_until_follows_stepping_where_the_closed_form_is_one_off() -> void:
	assert_int(_simulate(0.0, 300.0, 10.0, 10_000)).is_equal(1801)
	assert_int(PowerMath.ticks_until_mwh(0.0, 300.0, 10.0)).is_equal(1801)


## Targets a hair above a whole number of ticks need one more tick.
func test_ticks_until_rounds_up() -> void:
	assert_int(PowerMath.ticks_until_mwh(0.0, 0.5000001, 30.0)).is_equal(2)
	assert_int(PowerMath.ticks_until_mwh(0.0, 0.4999999, 30.0)).is_equal(1)


## Round numbers whose per-tick gain is not exact in binary (1/3, 1/6, 1/10 MWh) still
## agree with stepping.
func test_ticks_until_matches_stepping_on_inexact_gains() -> void:
	var cases: Array[Array] = [
		[0.0, 300.0, 20.0],
		[0.0, 400.0, 10.0],
		[0.0, 300.0, 6.0],
		[0.0, 1.0, 6.0],
		[0.1, 0.4, 18.0],
		[12.7, 300.0, 7.0],
		[0.0, 3.3, 66.0],
	]
	for item: Array in cases:
		var stored: float = item[0]
		var target: float = item[1]
		var net: float = item[2]
		var expected: int = _simulate(stored, target, net, 1_000_000)
		assert_int(PowerMath.ticks_until_mwh(stored, target, net)).is_equal(expected)


## Seeded random cases, with fractional values, match stepping.
func test_ticks_until_matches_stepping_on_seeded_cases() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4949
	for index: int in 200:
		var stored: float = snappedf(rng.randf_range(0.0, 400.0), 0.01)
		var target: float = stored + snappedf(rng.randf_range(0.0, 400.0), 0.01)
		var net: float = snappedf(rng.randf_range(0.5, 60.0), 0.1)
		var expected: int = _simulate(stored, target, net, 1_000_000)
		var actual: int = PowerMath.ticks_until_mwh(stored, target, net)
		(
			assert_int(actual)
			. override_failure_message(
				"case %d: stored %s target %s net %s" % [index, stored, target, net]
			)
			. is_equal(expected)
		)


## Unrounded random floats, where the closed form is rarely near a tick boundary, match too.
func test_ticks_until_matches_stepping_on_raw_floats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for index: int in 100:
		var stored: float = rng.randf_range(0.0, 400.0)
		var target: float = stored + rng.randf_range(0.0, 400.0)
		var net: float = rng.randf_range(0.5, 60.0)
		var expected: int = _simulate(stored, target, net, 1_000_000)
		(
			assert_int(PowerMath.ticks_until_mwh(stored, target, net))
			. override_failure_message("case %d" % index)
			. is_equal(expected)
		)


## The answer is the first tick that reaches the target: one tick fewer falls short.
func test_ticks_until_is_the_first_reaching_tick() -> void:
	var ticks: int = PowerMath.ticks_until_mwh(0.0, 300.0, 20.0)
	var stored: float = 0.0
	for tick: int in range(ticks - 1):
		stored = PowerMath.step_stored_mwh(stored, 300.0, 20.0)
	assert_bool(stored < 300.0).is_true()
	assert_bool(PowerMath.step_stored_mwh(stored, 300.0, 20.0) >= 300.0).is_true()
