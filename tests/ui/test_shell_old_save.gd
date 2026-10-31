## Tests the M2 clean break from the player's side: quick loading a save from an older build
## (the real v9 file in tests/services/fixtures) keeps the running game and shows the
## translated "older build" message. Saves go to a temporary user:// folder.
## Bible: technical-architecture.md#save-system
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const OLD_SAVE: String = "res://tests/services/fixtures/save_v9.json"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _real_saves_dir: String = ""
var _real_locale: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	_real_locale = TranslationServer.get_locale()
	SaveService.saves_dir = (
		"user://test_shell_old_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	)
	TranslationServer.set_locale("en")
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 12345
	_runner = scene_runner(_shell)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_shell):
		_shell.free()
	var dir: DirAccess = DirAccess.open(SaveService.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(SaveService.saves_dir.path_join(file_name))
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = _real_saves_dir
	TranslationServer.set_locale(_real_locale)


## An older save fails to load with &"old_format_version"; the game carries on and the toast
## says so in the player's language.
func test_quick_loading_an_old_save_keeps_the_game() -> void:
	DirAccess.make_dir_recursive_absolute(SaveService.saves_dir)
	var file := FileAccess.open(SaveService.slot_path(ShellScript.QUICK_SLOT), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(OLD_SAVE))
	file.close()
	assert_str(SaveService.load_game(ShellScript.QUICK_SLOT).error_code).is_equal(
		&"old_format_version"
	)
	var running: Simulation = SimClock.simulation
	_runner.simulate_action_pressed("quick_load")
	await _runner.await_input_processed()
	assert_object(SimClock.simulation).is_same(running)
	var text: String = _shell.get_toast_text()
	assert_str(text).is_equal(tr("UI_LOAD_OLD_SAVE"))
	assert_str(text).is_equal(
		"This save is from an older build and can't be loaded. Start a new game."
	)
	TranslationServer.set_locale("pt_BR")
	assert_str(tr("UI_LOAD_OLD_SAVE")).starts_with("Este salvamento")
