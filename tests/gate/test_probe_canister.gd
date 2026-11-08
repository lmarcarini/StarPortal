## Tests for the sample canister: $10k each, reeled back 10 ticks after it is thrown with the
## world's Biohazard at fair; closing the wormhole first loses it and its result; refusals.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Sample canister)
extends GdUnitTestSuite

const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = ProbeFixture.state()
	_simulation = ProbeFixture.simulation(_state)


func _biohazard() -> WorldReport.Confidence:
	return _state.worlds.report_of(ProbeFixture.WORLD_ID).confidence_of(WorldReport.Fact.BIOHAZARD)


## Thrown on an open wormhole, it costs $10k and fills Biohazard after exactly ten ticks
## (minutes), never before; another canister can go out afterwards.
func test_reeled_back_after_ten_minutes() -> void:
	ProbeFixture.open(_simulation)
	var funds: int = _state.budget.funds_k
	assert_bool(_simulation.submit(LaunchCanisterCommand.new()).is_ok).is_true()
	assert_int(funds - _state.budget.funds_k).is_equal(10)
	var ticks: int = 0
	while _biohazard() == WorldReport.Confidence.NONE and ticks < 100:
		_simulation.advance_tick()
		ticks += 1
	assert_int(ticks).is_equal(10)
	assert_int(_biohazard()).is_equal(WorldReport.Confidence.FAIR)
	var entry: WorldReport.Entry = _state.worlds.report_of(ProbeFixture.WORLD_ID).entry_of(
		WorldReport.Fact.BIOHAZARD
	)
	assert_str(String(entry.source)).is_equal("canister")
	assert_bool(_state.probes.is_canister_out()).is_false()
	assert_bool(LaunchCanisterCommand.new().validate(_state).is_ok).is_true()


## Closing the wormhole with the canister out loses it and its result.
func test_lost_when_the_wormhole_closes() -> void:
	ProbeFixture.open(_simulation)
	_simulation.submit(LaunchCanisterCommand.new())
	ProbeFixture.advance(_simulation, 5)
	_simulation.submit(CloseWormholeCommand.new())
	ProbeFixture.advance(_simulation, 20)
	assert_bool(_state.probes.is_canister_out()).is_false()
	assert_int(_biohazard()).is_equal(WorldReport.Confidence.NONE)


## Refused with no wormhole, while one is out, and without $10k.
func test_refusals() -> void:
	assert_str(LaunchCanisterCommand.new().validate(_state).error_code).is_equal(&"no_wormhole")
	ProbeFixture.open(_simulation)
	_simulation.submit(LaunchCanisterCommand.new())
	assert_str(LaunchCanisterCommand.new().validate(_state).error_code).is_equal(&"canister_busy")
	_state.probes.clear_canister()
	_state.budget.funds_k = 9
	assert_str(LaunchCanisterCommand.new().validate(_state).error_code).is_equal(
		&"insufficient_funds"
	)
