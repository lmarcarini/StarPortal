## The pause menu: Esc opens it only when nothing else takes Esc, it holds the clock and
## Resume restores it (a paused game stays paused), save and load through it, confirms, and
## quick save still works.
## Bible: docs/bible/technical-architecture.md#save-and-load (M4.6-02)
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _shell: ShellScript = null
var _runner: GdUnitSceneRunner = null
var _saves: String = ""


func before_test() -> void:
	_saves = SaveService.saves_dir
	SaveService.saves_dir = "user://test_pause_%d" % Time.get_ticks_usec()
	_shell = (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	_shell.new_game_seed = 21
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
	SaveService.saves_dir = _saves


func test_esc_opens_holds_and_resume_restores_the_speed() -> void:
	SimClock.resume()
	assert_bool(SimClock.is_running()).is_true()
	await _runner.simulate_action_pressed(&"pause_menu")
	var menu: PauseMenu = _shell.pause_menu
	assert_bool(menu.is_open()).is_true()
	assert_bool(SimClock.is_running()).is_false()
	menu.resume_button.pressed.emit()
	assert_bool(menu.is_open()).is_false()
	assert_bool(SimClock.is_running()).is_true()


func test_a_paused_game_stays_paused() -> void:
	SimClock.pause()
	_shell.pause_menu.open()
	_shell.pause_menu.close()
	assert_bool(SimClock.is_running()).is_false()


func test_esc_backs_out_of_a_list_before_closing() -> void:
	var menu: PauseMenu = _shell.pause_menu
	menu.open()
	menu.save_button.pressed.emit()
	assert_bool(menu.slots.visible).is_true()
	menu.back()
	assert_bool(menu.slots.visible).is_false()
	assert_bool(menu.is_open()).is_true()
	menu.back()
	assert_bool(menu.is_open()).is_false()


func test_save_and_load_through_the_menu_with_confirms() -> void:
	var menu: PauseMenu = _shell.pause_menu
	menu.open()
	menu.save_button.pressed.emit()
	menu.slots.name_field.text = "my_game"
	menu.slots.save_new()
	assert_bool(FileAccess.file_exists(SaveService.slot_path(&"my_game"))).is_true()
	menu.save_button.pressed.emit()
	menu.slots.choose(&"my_game")
	assert_str(menu.slots.note.text).is_not_empty()
	SimClock.step_ticks(30)
	SimClock.simulation.state.budget.funds_k = 1
	menu.load_button.pressed.emit()
	menu.slots.choose(&"my_game")
	assert_bool(menu.question.visible).is_true()
	menu.yes_button.pressed.emit()
	assert_int(SimClock.simulation.state.budget.funds_k).is_not_equal(1)


func test_bad_names_and_broken_slots() -> void:
	var menu: PauseMenu = _shell.pause_menu
	menu.open()
	menu.save_button.pressed.emit()
	menu.slots.name_field.text = "bad name!"
	menu.slots.save_new()
	assert_bool(FileAccess.file_exists(SaveService.slot_path(&"bad name!"))).is_false()
	DirAccess.make_dir_recursive_absolute(SaveService.saves_dir)
	var file := FileAccess.open(SaveService.slot_path(&"broken"), FileAccess.WRITE)
	file.store_string("{oops")
	file.close()
	menu.slots.show_mode(SlotList.Mode.LOAD)
	var row: Button = menu.slots.rows()[0]
	assert_bool(row.disabled).is_true()
	assert_str(row.text).contains("broken")


func test_main_menu_and_quit_ask_first_and_quick_save_works() -> void:
	var menu: PauseMenu = _shell.pause_menu
	menu.open()
	menu.menu_button.pressed.emit()
	assert_bool(menu.question.visible).is_true()
	menu.back()
	menu.close()
	_shell.quick_save()
	assert_bool(FileAccess.file_exists(SaveService.slot_path(ShellScript.QUICK_SLOT))).is_true()
