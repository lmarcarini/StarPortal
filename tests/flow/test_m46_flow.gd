## The M4.6 flow end to end: menu, new game, cheat funds, save to a named slot from the pause
## menu, back to the main menu, Continue, load the shipped scenario, and quit asks first.
## Bible: docs/bible/roadmap.md#working-process
extends GdUnitTestSuite

const MENU_SCENE: String = "res://src/scenes/main_menu/main_menu.tscn"
const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"
const SLOT: StringName = &"flow_slot"

var _saves: String = ""
var _went_to_menu: bool = false


func before_test() -> void:
	_saves = SaveService.saves_dir
	SaveService.saves_dir = "user://test_m46_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(SaveService.saves_dir)
	DebugCheatCommand.force_enabled = 1
	GameStart.reset()


func after_test() -> void:
	DebugCheatCommand.force_enabled = -1
	GameStart.reset()
	SimClock.stop()
	var dir: DirAccess = DirAccess.open(SaveService.saves_dir)
	if dir != null:
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(SaveService.saves_dir.path_join(file_name))
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = _saves


func _menu() -> MainMenu:
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	menu.changes_scene = false
	add_child(menu)
	return menu


func _shell() -> ShellScript:
	var shell := (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	var runner: GdUnitSceneRunner = scene_runner(shell)
	await runner.await_input_processed()
	return shell


func _on_menu_requested() -> void:
	_went_to_menu = true


func _cheat_panel(shell: Node) -> CheatPanel:
	return shell.find_child("CheatPanel", true, false) as CheatPanel


func test_menu_to_scenario_flow() -> void:
	# Menu → New game.
	var menu: MainMenu = _menu()
	menu.new_button.pressed.emit()
	assert_bool(GameStart.is_new()).is_true()
	menu.free()
	var shell: ShellScript = await _shell()
	# Cheat funds.
	var before: int = SimClock.simulation.state.budget.funds_k
	assert_bool(_cheat_panel(shell).cheat(&"funds", 1000).is_ok).is_true()
	SimClock.step_ticks(1)
	var funds: int = SimClock.simulation.state.budget.funds_k
	assert_int(funds).is_equal(before + 1000)
	# Save to a named slot from the pause menu.
	var pause: PauseMenu = shell.pause_menu
	pause.open()
	pause.save_button.pressed.emit()
	pause.slots.name_field.text = String(SLOT)
	pause.slots.save_new()
	assert_bool(FileAccess.file_exists(SaveService.slot_path(SLOT))).is_true()
	# Main menu, confirmed (the scene change itself is replaced by a flag).
	pause.menu_requested.disconnect(Callable(shell, &"return_to_menu"))
	pause.menu_requested.connect(_on_menu_requested)
	pause.menu_button.pressed.emit()
	pause.yes_button.pressed.emit()
	assert_bool(_went_to_menu).is_true()
	shell.free()
	SimClock.stop()
	# Continue opens the saved game with the cheated funds.
	menu = _menu()
	assert_bool(menu.continue_button.visible).is_true()
	menu.continue_button.pressed.emit()
	assert_int(GameStart.mode).is_equal(GameStart.Mode.SLOT)
	menu.free()
	shell = await _shell()
	assert_int(SimClock.simulation.state.budget.funds_k).is_equal(funds)
	shell.free()
	SimClock.stop()
	# Load the example scenario.
	menu = _menu()
	var scenarios: Array[ScenarioDef] = Registry.scenarios()
	assert_bool(scenarios.is_empty()).is_false()
	assert_bool(menu.open_scenario(scenarios[0])).is_true()
	assert_int(GameStart.mode).is_equal(GameStart.Mode.SCENARIO)
	menu.free()
	shell = await _shell()
	assert_object(SimClock.simulation).is_not_null()
	assert_bool(SimClock.is_running()).is_false()
	# Quit asks first.
	shell.pause_menu.open()
	shell.pause_menu.quit_button.pressed.emit()
	assert_bool(shell.pause_menu.question.visible).is_true()
	shell.free()
