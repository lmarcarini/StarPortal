## The main menu and GameStart: nothing ticks behind the menu, Continue only with a save and
## it opens the newest, a failed load stays on the menu with its reason, and the shell starts
## from what GameStart holds.
## Bible: docs/bible/technical-architecture.md#architecture-overview
extends GdUnitTestSuite

const MENU_SCENE: String = "res://src/scenes/main_menu/main_menu.tscn"
const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"

var _real_saves_dir: String = ""


func before_test() -> void:
	_real_saves_dir = SaveService.saves_dir
	SaveService.saves_dir = "user://test_menu_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(SaveService.saves_dir)
	GameStart.reset()


func after_test() -> void:
	GameStart.reset()
	var dir: DirAccess = DirAccess.open(SaveService.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(SaveService.saves_dir.path_join(file_name))
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = _real_saves_dir


func _menu() -> MainMenu:
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	menu.changes_scene = false
	add_child(menu)
	return menu


func test_nothing_ticks_and_continue_hides_without_saves() -> void:
	var menu: MainMenu = _menu()
	await get_tree().process_frame
	assert_object(SimClock.simulation).is_null()
	assert_bool(menu.continue_button.visible).is_false()
	assert_object(menu.first_button()).is_same(menu.new_button)
	assert_bool(menu.new_button.has_focus()).is_true()
	menu.free()


func test_new_game_sets_a_new_start() -> void:
	var menu: MainMenu = _menu()
	menu.new_button.pressed.emit()
	assert_bool(GameStart.is_new()).is_true()
	assert_int(GameStart.mode).is_equal(GameStart.Mode.NEW)
	menu.free()


func test_continue_opens_the_newest_save() -> void:
	var state := GameState.new_game(5, Registry.balance())
	var built: Result = GameSetup.build_new(state, GameDefs.from_registry(Registry))
	assert_bool(built.is_ok).is_true()
	assert_bool(SaveService.save_game(state, &"older").is_ok).is_true()
	assert_bool(SaveService.autosave(state).is_ok).is_true()
	var menu: MainMenu = _menu()
	assert_bool(menu.continue_button.visible).is_true()
	menu.continue_button.pressed.emit()
	assert_int(GameStart.mode).is_equal(GameStart.Mode.SLOT)
	var newest: StringName = SaveService.list_slots()[0]["slot"]
	assert_str(String(GameStart.slot)).is_equal(String(newest))
	assert_object(GameStart.loaded).is_not_null()
	menu.free()


func test_a_failed_load_stays_with_its_reason() -> void:
	var file := FileAccess.open(SaveService.saves_dir.path_join("broken.json"), FileAccess.WRITE)
	file.store_string("{not json")
	file.close()
	var menu: MainMenu = _menu()
	assert_bool(menu.open_slot(&"broken")).is_false()
	assert_bool(menu.message.visible).is_true()
	assert_bool(GameStart.is_new()).is_true()
	menu.free()


func test_take_state_uses_the_loaded_state_once() -> void:
	var state := GameState.new_game(9, Registry.balance())
	GameStart.start_slot(&"slot_a", state)
	assert_bool(GameStart.is_new()).is_false()
	assert_object(GameStart.take_state(1, Registry.balance())).is_same(state)
	assert_bool(GameStart.is_new()).is_true()
	GameStart.start_new(77)
	assert_int(GameStart.take_state(1, Registry.balance()).random.base_seed).is_equal(77)


func test_the_shell_starts_from_a_loaded_slot() -> void:
	var state := GameState.new_game(5, Registry.balance())
	GameSetup.build_new(state, GameDefs.from_registry(Registry))
	state.budget.funds_k = 1234
	GameStart.start_slot(&"slot_b", state)
	var shell := (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	var runner: GdUnitSceneRunner = scene_runner(shell)
	await runner.await_input_processed()
	assert_int(SimClock.simulation.state.budget.funds_k).is_equal(1234)
	assert_bool(SimClock.simulation.state.clock.is_paused).is_true()
	shell.free()


func test_menu_fits_pt_br_at_1280() -> void:
	var locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("pt_BR")
	var menu: MainMenu = _menu()
	menu.size = Vector2(1280, 720)
	await get_tree().process_frame
	assert_float(menu.get_combined_minimum_size().x).is_less_equal(1280.0)
	assert_float(menu.get_combined_minimum_size().y).is_less_equal(720.0)
	TranslationServer.set_locale(locale)
	menu.free()
