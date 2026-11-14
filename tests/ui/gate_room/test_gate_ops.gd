## The gate operations panel (M4.7-04): a lock brings the Gate Room to the front and operates
## the gate (slow); Stand by, Esc or leaving the tab stands by with the wormhole open; the
## portal operates again; a conversation or the setting off means no switch, only an alert.
## Bible: docs/content/event-time.md section 3
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _setting: bool = true


func before_test() -> void:
	_setting = Settings.get_bool(GateFocus.SETTING_SECTION, GateFocus.SETTING_KEY)
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 6
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	SimClock.set_speed_index(3)


func after_test() -> void:
	Settings.set_value(GateFocus.SETTING_SECTION, GateFocus.SETTING_KEY, _setting)
	if is_instance_valid(_shell):
		_shell.free()


func _state() -> GameState:
	return SimClock.simulation.state


func _lock() -> void:
	var state: GameState = _state()
	state.gate.mode = GateState.RingMode.LOCKED
	state.gate.lock_started_tick = state.clock.tick
	EventBus.dial_resolved.emit(DialOutcome.Kind.LOCK as int, "")


func _screen() -> WormholeScreen:
	var view: GateRoomView = _shell.view_switcher.get_view(ViewSwitcher.GATE_ROOM)
	return view.get_overlays().get_wormhole_screen()


func _effective() -> int:
	return TimeControl.effective_speed_index(_state().clock)


func _has_alert(kind: StringName) -> bool:
	for entry: AlertEntry in AlertRules.current(_state()):
		if entry.kind == kind:
			return true
	return false


func test_a_lock_switches_and_operates_and_stand_by_gives_speed_back() -> void:
	_lock()
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("gate_room")
	assert_bool(_state().gate.operating).is_true()
	assert_int(_effective()).is_equal(1)
	_screen().open()
	assert_bool(_screen().are_actions_shown()).is_true()
	_screen().get_actions().get_stand_by_button().pressed.emit()
	assert_bool(_state().gate.operating).is_false()
	assert_int(_effective()).is_equal(3)
	assert_int(_state().gate.mode).is_equal(GateState.RingMode.LOCKED)
	assert_bool(_has_alert(&"wormhole_open")).is_true()
	_screen().toggle_actions()
	assert_bool(_state().gate.operating).is_true()
	_shell.view_switcher.show_view(ViewSwitcher.BASE)
	assert_bool(_state().gate.operating).is_false()
	assert_int(_effective()).is_equal(3)


func test_no_switch_during_a_conversation() -> void:
	_state().conversations.active = ActiveConversation.new()
	_lock()
	_state().conversations.active = null
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("base")
	assert_bool(_state().gate.operating).is_false()
	assert_bool(_has_alert(&"wormhole_open")).is_true()


func test_no_switch_with_the_setting_off() -> void:
	Settings.set_value(GateFocus.SETTING_SECTION, GateFocus.SETTING_KEY, false)
	_lock()
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("base")
	assert_int(_effective()).is_equal(3)


func test_the_panel_fits_pt_br() -> void:
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("pt_BR")
	_lock()
	_screen().open()
	await get_tree().process_frame
	var button: Button = _screen().get_actions().get_stand_by_button()
	assert_bool(button.is_visible_in_tree()).is_true()
	assert_float(button.get_global_rect().end.x).is_less_equal(_shell.get_viewport_rect().size.x)
	TranslationServer.set_locale(locale)
