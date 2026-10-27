## Tests for the Ring view in the Gate Room's hybrid layout: the dialing sequence lights its
## seals one by one, a lock opens a shimmering event horizon that stays open until the
## wormhole closes (on order, at the time limit or when the power runs out) and then goes
## dark, a loaded game shows the Ring as it was, reduced flashing softens the opening burst,
## and the wormhole screen never covers the Ring.
## Bible: gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## overview.md#locked-decisions (Presentation: hybrid), game-design.md#difficulty-and-accessibility
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const SETTINGS_PATH: String = "user://test_ring_view_settings.cfg"

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_settings_path: String = ""


func before_test() -> void:
	_real_settings_path = Settings.file_path
	Settings.file_path = SETTINGS_PATH
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	Settings.set_value(&"accessibility", &"reduced_flashing", false)
	Settings.file_path = _real_settings_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))


func _ring() -> RingView:
	return _view.get_ring_view()


func _sequence() -> DialSequence:
	return _view.get_overlays().get_sequence()


func _start_dial(kind: int) -> void:
	Fixture.select(_view, Fixture.address_for(_simulation.state, kind))
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)


func _lock() -> void:
	_start_dial(DialOutcome.Kind.LOCK)
	_sequence().skip()


func test_the_ring_is_dark_before_any_dial() -> void:
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.DARK)
	assert_int(_ring().get_lit()).is_equal(0)


func test_the_sequence_lights_the_rings_seals_one_by_one() -> void:
	_start_dial(DialOutcome.Kind.NO_GATE)
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.DIALING)
	var lit: Array[int] = [_ring().get_lit()]
	for step: int in GateAddress.SEAL_COUNT - 1:
		_sequence().advance(DialSequence.SEAL_SECONDS)
		lit.append(_ring().get_lit())
	assert_array(lit).is_equal([0, 1, 2, 3, 4, 5, 6, 7])
	assert_bool(_sequence().is_open()).is_true()
	_sequence().advance(DialSequence.SEAL_SECONDS)
	assert_bool(_sequence().is_open()).is_false()
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.DARK)
	assert_int(_ring().get_lit()).is_equal(0)


func test_a_lock_opens_the_horizon_with_a_burst_and_a_moving_shimmer() -> void:
	_lock()
	var horizon: EventHorizon = _ring().get_event_horizon()
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.OPEN)
	assert_int(_ring().get_lit()).is_equal(GateAddress.SEAL_COUNT)
	assert_float(horizon.level).is_equal(1.0)
	assert_float(horizon.burst).is_equal(RingView.BURST_PEAK)
	assert_bool(_ring().is_processing()).is_true()
	var before: float = horizon.phase
	_ring().advance(RingView.BURST_SECONDS)
	assert_float(horizon.burst).is_equal_approx(0.0, 0.0001)
	assert_float(horizon.phase).is_not_equal(before)
	SimClock.step_ticks(30)
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.OPEN)


## However the wormhole closes, the horizon fades and the Ring goes dark with its seals out.
@warning_ignore("unused_parameter")
func test_the_horizon_goes_dark_when_the_wormhole_closes(
	how: String,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		["order"],
		["time"],
		["power"],
	]
) -> void:
	_lock()
	match how:
		"order":
			Fixture.close_wormhole(_view)
		"time":
			SimClock.step_ticks(_simulation.state.balance.max_open_ticks)
		"power":
			_simulation.state.power.plant_output_mw = 0.0
			_simulation.state.power.stored_mwh = 0.0
			SimClock.step_ticks(1)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.CLOSING)
	_ring().advance(RingView.CLOSE_SECONDS)
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.DARK)
	assert_int(_ring().get_lit()).is_equal(0)
	assert_float(_ring().get_event_horizon().level).is_equal(0.0)
	assert_bool(_ring().is_processing()).is_false()


func test_a_game_loaded_with_a_wormhole_open_shows_it_open_without_a_burst() -> void:
	var loaded: Simulation = Fixture.simulation()
	loaded.submit(DialCommand.create(Fixture.address_for(loaded.state, DialOutcome.Kind.LOCK)))
	SimClock.start(loaded)
	SimClock.step_ticks(2)
	_view.setup(loaded)
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.OPEN)
	assert_int(_ring().get_lit()).is_equal(GateAddress.SEAL_COUNT)
	assert_float(_ring().get_event_horizon().burst).is_equal(0.0)
	_view.setup(_simulation)
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.DARK)


func test_a_game_loaded_mid_dial_replays_on_the_ring() -> void:
	var loaded: Simulation = Fixture.simulation()
	var address: GateAddress = Fixture.address_for(loaded.state, DialOutcome.Kind.LOCK)
	loaded.submit(DialCommand.create(address))
	TimeControl.add_hold(loaded.state.clock, DialSequence.HOLD_REASON)
	SimClock.start(loaded)
	_view.setup(loaded)
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.DIALING)
	_sequence().advance(DialSequence.SEAL_SECONDS * 3.0)
	assert_int(_ring().get_lit()).is_equal(3)
	_sequence().skip()
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.OPEN)


func test_reduced_flashing_softens_the_opening_burst() -> void:
	Settings.set_value(&"accessibility", &"reduced_flashing", true)
	_lock()
	var horizon: EventHorizon = _ring().get_event_horizon()
	assert_float(horizon.burst).is_equal(RingView.SOFT_BURST_PEAK)
	assert_float(RingView.SOFT_BURST_PEAK).is_less(RingView.BURST_PEAK)
	_ring().advance(RingView.BURST_SECONDS)
	assert_float(horizon.burst).is_greater(0.0)
	_ring().advance(RingView.SOFT_BURST_SECONDS)
	assert_float(horizon.burst).is_equal(0.0)


## Ruling: the wormhole screen opens beside the Ring, never over it.
func test_the_wormhole_screen_leaves_the_ring_in_sight() -> void:
	_lock()
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: WormholeScreen = _view.get_overlays().get_wormhole_screen()
	assert_bool(screen.is_showing_open()).is_true()
	var ring: Rect2 = _ring().get_global_rect()
	assert_bool(screen.get_global_rect().intersects(ring)).is_false()
	var panel: Control = screen.get_node("Column") as Control
	assert_float(panel.get_combined_minimum_size().y).is_less_equal(screen.size.y)


## Switching away while the horizon fades ends the fade at once.
func test_leaving_the_gate_room_mid_fade_settles_dark() -> void:
	_lock()
	_simulation.submit(CloseWormholeCommand.new())
	SimClock.step_ticks(1)
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.CLOSING)
	_view.hide()
	assert_int(_ring().get_horizon_state()).is_equal(RingView.Horizon.DARK)
