## Tests for RescueForecast and ChargeAtMaximumCommand: the rescue charge is the lock energy
## plus 15 minutes of drain; from an empty bank 5 MW is too slow for the 72-hour window and
## 10 MW is on time; Charge at maximum raises every bank as far as the supply allows and
## lowers nothing; not enough even at maximum is reported.
## Bible: docs/content/m3-beyond-the-ring.md sections 1 (Lock energy) and 4
extends GdUnitTestSuite

const Fixture := preload("res://tests/expedition/expedition_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")
## The lock energy of the bible's example (366.6 MWh) and the rescue charge (371.6 MWh).
const LOCK_MWH: float = 366.6
const RESCUE_MWH: float = 371.6

var _state: GameState
var _bank: StringName


func before_test() -> void:
	_state = Fixture.state()
	_state.expedition.set_plan(
		ExpeditionState.Objective.SURVEY, Fixture.WORLD_ID, &"", Fixture.team(_state)
	)
	_state.expedition.mode = ExpeditionState.Mode.MISSING
	_state.expedition.departed_tick = 0
	_state.expedition.missed_tick = _state.clock.tick
	_state.expedition.day_results.append(ExpeditionState.DAY_MISSED)
	var galaxy: GalaxyCatalogue = _state.galaxy
	var address: GateAddress = galaxy.address_of(Fixture.WORLD_ID, galaxy.home().origin_glyph)
	var factor: float = (
		GateQueries.lock_energy_mwh(_state, address) / _state.balance.lock_energy_base_mwh
	)
	_state.balance.lock_energy_base_mwh = LOCK_MWH / factor
	_state.power.stored_mwh = 0.0
	_bank = _state.power.charge_rates.keys()[0]


func test_needed_is_lock_energy_plus_fifteen_minutes_of_drain() -> void:
	assert_float(RescueForecast.needed_mwh(_state)).is_equal_approx(RESCUE_MWH, 0.001)
	assert_int(RescueForecast.window_ticks_left(_state)).is_equal(3 * TimeMath.TICKS_PER_DAY)


func test_ten_megawatts_is_the_minimum_from_an_empty_bank() -> void:
	_state.power.charge_rates[_bank] = 5
	assert_str(String(RescueForecast.status(_state))).is_equal(String(RescueForecast.TOO_SLOW))
	_state.power.charge_rates[_bank] = 10
	assert_str(String(RescueForecast.status(_state))).is_equal(String(RescueForecast.ON_TIME))
	var ticks: int = RescueForecast.ticks_until_ready(_state, 10.0)
	assert_int(ticks).is_equal(
		PowerMath.ticks_until_mwh(0.0, RescueForecast.needed_mwh(_state), 10.0)
	)


func test_charge_at_maximum_raises_banks_and_lowers_nothing() -> void:
	_state.power.charge_rates[_bank] = 5
	var spare: float = PowerRules.spare_mw(_state)
	var rates: Dictionary[StringName, int] = RescueForecast.max_rates(_state)
	var expected: int = 5 + RescueForecast.raise_mw(25, floori(spare))
	assert_int(rates[_bank]).is_equal(expected)
	var command := ChargeAtMaximumCommand.new()
	assert_bool(command.validate(_state).is_ok).is_true()
	command.apply(_state)
	assert_int(_state.power.charge_rates[_bank]).is_equal(expected)
	assert_bool(PowerRules.spare_mw(_state) >= 0.0).is_true()
	assert_str(String(command.validate(Fixture.state()).error_code)).is_equal(
		String(ChargeAtMaximumCommand.NO_RESCUE)
	)


func test_charge_at_maximum_moves_in_five_megawatt_blocks() -> void:
	assert_int(RescueForecast.raise_mw(30, 27)).is_equal(25)
	assert_int(RescueForecast.raise_mw(25, 100)).is_equal(25)
	assert_int(RescueForecast.raise_mw(30, 4)).is_equal(0)
	assert_int(RescueForecast.raise_mw(12, 40)).is_equal(10)
	assert_int(RescueForecast.max_rates(_state)[_bank] % 5).is_equal(0)


func test_not_enough_even_at_maximum() -> void:
	_state.power.charge_rates[_bank] = 0
	_state.expedition.missed_tick = _state.clock.tick - 3 * TimeMath.TICKS_PER_DAY + 60
	assert_str(String(RescueForecast.status(_state))).is_equal(String(RescueForecast.NOT_ENOUGH))
