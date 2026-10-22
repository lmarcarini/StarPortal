## Tests for EnergyMath: lock energy from seal 1's anchor with the default balance, and the
## share of it each dial outcome spends.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy
extends GdUnitTestSuite

const HOME := Vector3i(1000, -2000, 500)
const COORDINATES: Array[int] = [2, 0, 1, 3, 4, 5, 6]
const ORIGIN: int = 7

var _balance: BalanceConfig
var _anchors: Array[Vector3i] = []
var _address: GateAddress


func before_test() -> void:
	_balance = BalanceConfig.new()
	_anchors.clear()
	for index: int in GateAddress.GLYPH_COUNT:
		_anchors.append(HOME + Vector3i(index * 20_000, 0, 0))
	_address = GateAddress.create(COORDINATES, ORIGIN)


## Seal 1's anchor at the home Ring (d = 0) needs E_base: 300 MWh.
func test_lock_energy_at_zero_distance() -> void:
	_anchors[2] = HOME
	var energy: float = EnergyMath.lock_energy_mwh(_address, HOME, _anchors, _balance)
	assert_float(energy).is_equal(300.0)


## Seal 1's anchor 10,000 ly from home (d = d_ref) doubles it: 600 MWh, in any direction.
func test_lock_energy_at_reference_distance() -> void:
	for offset: Vector3i in [Vector3i(10_000, 0, 0), Vector3i(0, -6000, 8000)]:
		_anchors[2] = HOME + offset
		var energy: float = EnergyMath.lock_energy_mwh(_address, HOME, _anchors, _balance)
		assert_float(energy).is_equal_approx(600.0, 1e-9)


## Only seal 1's anchor matters: moving the other seals' anchors leaves the energy unchanged.
func test_lock_energy_uses_seal_one_only() -> void:
	_anchors[2] = HOME + Vector3i(0, 5000, 0)
	var before: float = EnergyMath.lock_energy_mwh(_address, HOME, _anchors, _balance)
	for index: int in GateAddress.GLYPH_COUNT:
		if index != 2:
			_anchors[index] = HOME
	var after: float = EnergyMath.lock_energy_mwh(_address, HOME, _anchors, _balance)
	assert_float(before).is_equal_approx(450.0, 1e-9)
	assert_float(after).is_equal(before)


## The 8-seal multiplier scales the lock energy; the 9 and 10 multipliers do not apply.
func test_lock_energy_uses_eight_seal_multiplier() -> void:
	_anchors[2] = HOME
	_balance.seal_multiplier_8 = 3.0
	_balance.seal_multiplier_9 = 1000.0
	_balance.seal_multiplier_10 = 1000.0
	var energy: float = EnergyMath.lock_energy_mwh(_address, HOME, _anchors, _balance)
	assert_float(energy).is_equal(900.0)


## No gate spends 10%, Blocked and Origin rejected 25%, both locks 100%.
func test_dial_cost_per_outcome() -> void:
	var expected: Dictionary[DialOutcome.Kind, float] = {
		DialOutcome.Kind.NO_GATE: 100.0,
		DialOutcome.Kind.BLOCKED: 250.0,
		DialOutcome.Kind.ORIGIN_REJECTED: 250.0,
		DialOutcome.Kind.LOCK: 1000.0,
		DialOutcome.Kind.HOSTILE_LOCK: 1000.0,
	}
	for kind: DialOutcome.Kind in expected:
		var cost: float = EnergyMath.dial_cost_mwh(1000.0, kind, _balance)
		assert_float(cost).override_failure_message(str(kind)).is_equal_approx(expected[kind], 1e-9)
