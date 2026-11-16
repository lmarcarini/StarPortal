## Tests for the Gate station's console: a selected destination and DIAL dials (two
## actions), the key becomes CLOSE on a lock and closes, refusals become the key's hover
## reason, CLOSE asks to be held only while a MOTH or canister is out, Enter on the station
## presses the key, and with no bank the gauge gives way to BUILD BANK.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Console)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null


func before_test() -> void:
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.theme = UiThemeBuilder.build(1.0)
	add_child(_holder)
	_view = VIEW.instantiate() as GateStationView
	_holder.add_child(_view)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	_holder.free()


func _console() -> GateConsole:
	return _view.get_console()


func _select(kind: int) -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, kind)
	_console().select_destination(GateDestination.of(address, "P3X"))


func _run_dial() -> void:
	for i: int in _simulation.state.balance.dial_duration_ticks:
		_simulation.advance_tick()


func test_select_and_dial() -> void:
	_select(DialOutcome.Kind.LOCK)
	assert_str(_console().get_monitor().get_name_text()).is_equal("P3X")
	_console().get_main_key().pressed.emit()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)


func test_close_after_lock() -> void:
	_select(DialOutcome.Kind.LOCK)
	_console().press_main_key()
	_run_dial()
	_console()._process(0.0)
	assert_str(_console().get_main_key().text).is_equal("HW_KEY_CLOSE")
	assert_bool(_console().get_main_key().hold_to_confirm).is_false()
	_console().press_main_key()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)


func test_close_confirms_with_canister_out() -> void:
	_select(DialOutcome.Kind.LOCK)
	_console().press_main_key()
	_run_dial()
	_simulation.state.probes.canister_ticks_left = 5
	_console()._process(0.0)
	assert_bool(_console().get_main_key().hold_to_confirm).is_true()


func test_no_destination_reason() -> void:
	_console().press_main_key()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_str(_console().get_key_reason()).is_equal("STATION_REASON_NO_DESTINATION")


func test_refusal_is_hover_reason() -> void:
	_select(DialOutcome.Kind.LOCK)
	_simulation.state.power.stored_mwh = 0.001
	_console().press_main_key()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_str(_console().get_key_reason()).is_equal("GATE_DIAL_REJECT_CHARGE")


func test_enter_on_station_presses_key() -> void:
	_select(DialOutcome.Kind.LOCK)
	_holder.get_viewport().gui_release_focus()
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = true
	_view._unhandled_input(event)
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)


func test_main_key_rules() -> void:
	var state: GameState = _simulation.state
	assert_int(MainKeyRules.mode_of(state, null)).is_equal(MainKeyRules.Mode.OFF)
	var address: GateAddress = Fixture.address_for(state, DialOutcome.Kind.LOCK)
	assert_int(MainKeyRules.mode_of(state, address)).is_equal(MainKeyRules.Mode.DIAL)
	assert_str(String(MainKeyRules.refusal_key(&"whatever"))).is_equal("GATE_REASON_REJECTED")
