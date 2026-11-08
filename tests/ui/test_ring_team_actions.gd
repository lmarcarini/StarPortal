## Tests for the Gate Room's canister and team Ring actions and the close warning: Throw the
## sample canister ($10k, shown while the wormhole is open, then its return time), Send team
## (only on the ready plan's world, greyed with the reason), Signal T-1 (only in a rescue window
## open to the team's world), the warning before closing with the MOTH or the canister out,
## mouse and gamepad presses, and redrawing while paused.
## Bible: docs/content/m3-beyond-the-ring.md sections 2, 4 and 7
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const ExpeditionFixture := preload("res://tests/expedition/expedition_fixture.gd")
const RescueFixture := preload("res://tests/expedition/rescue_fixture.gd")
const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = RescueFixture.simulation(ExpeditionFixture.state(), 0)
	SimClock.start(_simulation)
	SimClock.pause()
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)
	await get_tree().process_frame


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _state() -> GameState:
	return _simulation.state


func _actions() -> WormholeActions:
	return _view.get_overlays().get_wormhole_screen().get_actions()


func _team() -> RingTeamActions:
	return _actions().get_team_actions()


## Opens the wormhole to the fixture world, shows the actions and waits a frame.
func _open() -> void:
	ProbeFixture.open(_simulation)
	_view.get_overlays().get_wormhole_screen().open()
	Fixture.open_actions(_view)
	await get_tree().process_frame


## Presses [param button] as the gamepad does: focus it, then A presses the focused button.
func _pad_press(button: Button) -> void:
	button.grab_focus()
	var focused: Control = get_viewport().gui_get_focus_owner()
	assert_object(focused).is_same(button)
	(focused as BaseButton).pressed.emit()
	await get_tree().process_frame


func _hold_close() -> void:
	var close: HoldButton = _actions().get_close_button()
	close.begin_hold()
	close.advance(HoldButton.HOLD_SECONDS)
	close.cancel_hold()


func test_canister_is_thrown_for_10k_and_shows_its_return_while_paused() -> void:
	await _open()
	var button: Button = _team().get_canister_button()
	assert_bool(button.disabled).is_false()
	assert_str(_team().get_notes()[0]).is_equal("Soil and water tested for biohazard in 10 min.")
	assert_bool(_actions().get_focusables().has(button)).is_true()
	var funds: int = _state().budget.funds_k
	await _pad_press(button)
	assert_int(_state().budget.funds_k).is_equal(funds - MothRules.CANISTER_COST_K)
	assert_bool(_state().probes.is_canister_out()).is_true()
	assert_bool(button.disabled).is_true()
	assert_str(_team().get_notes()[0]).is_equal("The canister is out: reeled back in 10 min.")


func test_canister_says_when_money_is_short() -> void:
	_state().budget.funds_k = MothRules.CANISTER_COST_K - 1
	await _open()
	assert_bool(_team().get_canister_button().disabled).is_true()
	assert_str(_team().get_notes()[0]).is_equal("Not enough money for a canister.")


func test_send_team_shows_only_with_a_ready_plan_on_that_world_and_sends_by_mouse() -> void:
	await _open()
	assert_bool(_team().get_team_button().visible).is_false()
	_simulation.submit(ExpeditionFixture.survey(_state()))
	_actions().render(_state())
	var button: Button = _team().get_team_button()
	assert_bool(button.visible).is_true()
	assert_bool(button.disabled).is_false()
	assert_str(_team().get_notes()[1]).starts_with("T-1 to ").ends_with("Survey, 2 days.")
	button.pressed.emit()
	assert_int(_state().expedition.mode).is_equal(ExpeditionState.Mode.AWAY)
	assert_bool(button.visible).is_false()


func test_send_team_is_greyed_with_the_reason_when_open_time_is_short() -> void:
	_simulation.submit(ExpeditionFixture.survey(_state()))
	await _open()
	var limit: int = GateQueries.open_ticks_left(_state())
	ExpeditionFixture.advance(_simulation, limit - ExpeditionRules.MARGIN_TICKS + 1)
	_actions().render(_state())
	assert_bool(_team().get_team_button().disabled).is_true()
	assert_bool(_actions().get_focusables().has(_team().get_team_button())).is_false()
	assert_str(_team().get_notes()[1]).is_equal(
		"Not enough open time to send a team (10 minutes needed)."
	)


func test_signal_shows_in_the_rescue_window_and_says_when_the_team_arrives() -> void:
	RescueFixture.send_and_miss(_simulation)
	assert_int(_state().expedition.mode).is_equal(ExpeditionState.Mode.MISSING)
	await _open()
	var button: Button = _team().get_signal_button()
	assert_bool(button.visible).is_true()
	assert_str(_team().get_notes()[2]).starts_with("T-1 reaches the Ring 15 min")
	await _pad_press(button)
	assert_int(_state().expedition.signal_tick).is_equal(_state().clock.tick)
	assert_bool(button.disabled).is_true()
	assert_str(_team().get_notes()[2]).is_equal("Signal sent: T-1 reaches the Ring in 15 min.")


func test_signal_is_hidden_outside_a_rescue() -> void:
	await _open()
	assert_bool(_team().get_signal_button().visible).is_false()


func test_closing_with_the_canister_out_warns_first() -> void:
	await _open()
	_team().get_canister_button().pressed.emit()
	_hold_close()
	assert_int(_state().gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_str(_actions().get_close_warning()).is_equal(
		"Closing now loses the canister and its result. Hold again to close."
	)
	assert_str(_actions().get_close_button().text).is_equal("GATE_WORMHOLE_CLOSE_ANYWAY")
	_hold_close()
	assert_int(_state().gate.mode).is_not_equal(GateState.RingMode.LOCKED)


func test_closing_with_the_moth_out_names_the_moth() -> void:
	await _open()
	_simulation.submit(LaunchMothCommand.new())
	_simulation.submit(LaunchCanisterCommand.new())
	_hold_close()
	assert_str(_actions().get_close_warning()).contains("the MOTH, and the canister")
	assert_int(_state().gate.mode).is_equal(GateState.RingMode.LOCKED)


func test_closing_with_nothing_out_closes_at_once() -> void:
	await _open()
	_hold_close()
	assert_str(_actions().get_close_warning()).is_empty()
	assert_int(_state().gate.mode).is_not_equal(GateState.RingMode.LOCKED)


func test_warning_drops_once_the_canister_is_back() -> void:
	await _open()
	_team().get_canister_button().pressed.emit()
	_hold_close()
	ExpeditionFixture.advance(_simulation, MothRules.CANISTER_TICKS + 1)
	_actions().render(_state())
	assert_str(_actions().get_close_warning()).is_empty()
	assert_str(_actions().get_close_button().text).is_equal("GATE_WORMHOLE_CLOSE")
