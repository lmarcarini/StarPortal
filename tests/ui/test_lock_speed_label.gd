## The dial and the gate operations panel slow the clock through slow reasons and never change
## the cruise speed the top bar shows (M4.7-04).
## Bible: game-design.md#time-real-time-with-pause,
## gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const TIME_BAR_SCENE: String = "res://src/ui/time_bar/time_bar.tscn"

var _state: GameState = null
var _bar: TimeBar = null
var _real_locale: String = ""
## Every speed index EventBus.speed_changed carried.
var _speeds: Array[int] = []


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_state = DialFixture.state(null, false)
	SimClock.start(DialFixture.simulation(_state))
	_bar = (load(TIME_BAR_SCENE) as PackedScene).instantiate() as TimeBar
	add_child(_bar)
	_speeds.clear()
	EventBus.speed_changed.connect(_on_speed_changed)


func after_test() -> void:
	EventBus.speed_changed.disconnect(_on_speed_changed)
	SimClock.stop()
	if is_instance_valid(_bar):
		_bar.free()
	TranslationServer.set_locale(_real_locale)


func _on_speed_changed(speed_index: int) -> void:
	_speeds.append(speed_index)


func _speed_text() -> String:
	return (_bar.find_child("SpeedLabel", true, false) as Label).text


func _effective() -> int:
	return TimeControl.effective_speed_index(_state.clock)


## The dial is slow (dialling), the lock gives cruise back until the gate is operated, and
## Stand by gives it back again; the player's cruise speed never changes.
func test_dial_slows_and_lock_returns_to_cruise() -> void:
	SimClock.set_speed_index(3)
	assert_str(_speed_text()).is_equal("10×")
	var address: GateAddress = DialFixture.address_of(_state.galaxy, DialFixture.OPEN_ID)
	assert_bool(SimClock.simulation.submit(DialCommand.create(address)).is_ok).is_true()
	SimClock.step_ticks(1)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.DIALING)
	assert_int(_effective()).is_equal(1)
	SimClock.step_ticks(_state.balance.dial_duration_ticks)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(_effective()).is_equal(3)
	assert_bool(SimClock.simulation.submit(OperateGateCommand.new()).is_ok).is_true()
	SimClock.step_ticks(1)
	assert_int(_effective()).is_equal(1)
	assert_bool(SimClock.simulation.submit(StandByCommand.new()).is_ok).is_true()
	SimClock.step_ticks(1)
	assert_int(_effective()).is_equal(3)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_int(_state.clock.speed_index).is_equal(3)
	assert_str(_speed_text()).is_equal("10×")


func test_a_tick_that_keeps_the_speed_emits_nothing() -> void:
	SimClock.set_speed_index(2)
	SimClock.step_ticks(3)
	assert_array(_speeds).is_equal([2])
	assert_str(_speed_text()).is_equal("3×")
