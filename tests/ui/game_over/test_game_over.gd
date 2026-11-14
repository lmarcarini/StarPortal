## The game over screen (M4c-15): shows the cause, date and figures on game_failed, blocks
## clicks behind it, loads the newest save, opens the slot list, and shows at once for a
## loaded game that had already failed; the pause menu's Failure states toggle.
## Bible: docs/content/m4c-incursions.md section 8
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _saves: String = ""
var _setting: bool = true


func before_test() -> void:
	TranslationServer.set_locale("en")
	_setting = Settings.get_bool(&"gameplay", &"failure_states")
	_saves = SaveService.saves_dir
	SaveService.saves_dir = "user://test_game_over_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(SaveService.saves_dir)
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 12
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	Settings.set_value(&"gameplay", &"failure_states", _setting)
	if is_instance_valid(_shell):
		_shell.free()
	var dir: DirAccess = DirAccess.open(SaveService.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(SaveService.saves_dir.path_join(file_name))
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = _saves


func _screen() -> GameOverScreen:
	return _shell.find_child("GameOverScreen", true, false) as GameOverScreen


func test_shows_the_end_and_loads_the_last_save() -> void:
	_shell.save_slot(&"before_the_end")
	var state: GameState = SimClock.simulation.state
	FailureRules.fail(state, FailureRules.OVERRUN)
	SimClock.simulation.advance_tick()
	await _runner.await_input_processed()
	var screen: GameOverScreen = _screen()
	assert_bool(screen.visible).is_true()
	assert_str(screen.title.text).is_equal("OVERRUN")
	assert_str(screen.figures.text).contains("Days survived: 1")
	assert_int(screen.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_str(String(GameOverScreen.newest_slot())).is_equal("before_the_end")
	screen.load_button.pressed.emit()
	assert_bool(screen.slots.visible).is_true()
	screen.last_button.pressed.emit()
	await _runner.await_input_processed()
	assert_bool(SimClock.simulation.state.outcome.has_failed()).is_false()
	assert_bool(_screen().visible).is_false()


func test_a_loaded_failed_game_shows_at_once() -> void:
	FailureRules.fail(SimClock.simulation.state, FailureRules.OVERRUN)
	_shell.save_slot(&"lost")
	await _runner.await_input_processed()
	_shell.load_slot(&"lost")
	await _runner.await_input_processed()
	assert_bool(_screen().visible).is_true()


func test_the_pause_menu_toggle_sets_the_setting() -> void:
	var menu: PauseMenu = _shell.pause_menu
	menu.failure_toggle.toggled.emit(false)
	assert_bool(Settings.get_bool(&"gameplay", &"failure_states")).is_false()
	assert_bool(SimClock.simulation.state.outcome.enabled).is_false()
