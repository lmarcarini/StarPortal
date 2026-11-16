## Tests for the shell's expedition alerts: a team check-in shows as a message that never
## pauses, and the top bar's alert stack sits in the focus order, hidden without a rescue.
## Bible: docs/content/m3-beyond-the-ring.md sections 4 and 7
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 12345
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	TranslationServer.set_locale(_real_locale)


func test_a_check_in_shows_as_a_message_and_the_alert_stack_is_in_the_top_bar() -> void:
	var home: StringName = SimClock.simulation.state.galaxy.home().id
	EventBus.team_checked_in.emit(home, 1, 0, "injury")
	assert_str(_shell.get_toast_text()).starts_with("T-1 checked in from ")
	assert_str(_shell.get_toast_text()).ends_with(": one light injury.")
	assert_bool(SimClock.simulation.state.clock.is_paused).is_true()
	var entry: Button = _shell.get_alert_stack().get_rescue_button()
	assert_bool(entry.visible).is_false()
	assert_bool(_shell.get_focus_order().has(entry)).is_false()
	assert_bool(_shell.get_rescue_alert().visible).is_false()


func test_a_rescue_alert_takes_focus_and_the_gamepad_reaches_its_stack_entry() -> void:
	var state: GameState = SimClock.simulation.state
	state.expedition.world_id = state.galaxy.home().id
	state.expedition.missed_tick = state.clock.tick
	state.expedition.mode = ExpeditionState.Mode.MISSING
	var alert: RescueAlert = _shell.get_rescue_alert()
	alert.open()
	await _runner.await_input_processed()
	assert_bool(alert.visible).is_true()
	assert_bool(alert.is_ancestor_of(_shell.get_viewport().gui_get_focus_owner())).is_true()
	alert.get_close_button().pressed.emit()
	var entry: Button = _shell.get_alert_stack().get_rescue_button()
	assert_bool(entry.visible).is_true()
	var faster: Button = _shell.frame.clock_plate.fast_key
	faster.grab_focus()
	faster.find_valid_focus_neighbor(SIDE_RIGHT).grab_focus()
	assert_object(_shell.get_viewport().gui_get_focus_owner()).is_same(entry)
	entry.pressed.emit()
	assert_bool(alert.visible).is_true()
	alert.get_gate_button().pressed.emit()
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("gate_room")
	state.expedition.mode = ExpeditionState.Mode.IDLE
