## The alert list in the top bar: count and worst severity on the button, choosing opens the
## screen, dismissing event-style alerts, and opening never pauses.
## Bible: docs/content/interface-pass.md section 3 (Alerts)
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
	_shell.new_game_seed = 9
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	TranslationServer.set_locale(_real_locale)


func _list() -> AlertList:
	return _shell.top_bar.alert_list


func test_button_shows_count_and_choosing_opens_the_screen() -> void:
	var state: GameState = SimClock.simulation.state
	state.budget.funds_k = -50
	_list().refresh()
	var count: int = _list().entries().size()
	assert_int(count).is_greater(0)
	assert_str(_shell.top_bar.alerts_button.text).ends_with(str(count))
	_shell.top_bar.alerts_button.pressed.emit()
	assert_bool(_list().visible).is_true()
	assert_bool(SimClock.simulation.state.clock.is_paused).is_true()
	var red: AlertEntry = null
	for entry: AlertEntry in _list().entries():
		if entry.kind == &"funds_red":
			red = entry
	assert_object(red).is_not_null()
	_list().alert_chosen.emit(red)
	await _runner.simulate_frames(2)
	assert_str(String(_shell.view_switcher.current_view_id())).is_equal("command")


func test_opening_the_list_keeps_a_running_clock_running() -> void:
	SimClock.resume()
	_shell.top_bar.toggle_alerts()
	assert_bool(SimClock.simulation.state.clock.is_paused).is_false()
	assert_object(_list().first_row()).is_not_null()


func test_site_finished_can_be_dismissed() -> void:
	var state: GameState = SimClock.simulation.state
	var room: RoomState = state.base.rooms[0]
	EventBus.room_built.emit(room.id)
	var site: AlertEntry = null
	for entry: AlertEntry in _list().entries():
		if entry.kind == &"site_finished":
			site = entry
	assert_object(site).is_not_null()
	_list().dismiss(site)
	for entry: AlertEntry in _list().entries():
		assert_str(String(entry.kind)).is_not_equal("site_finished")
