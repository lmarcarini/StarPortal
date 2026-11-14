## Shipped scenarios: every one loads through the save checks and migrations, the menu lists
## them in order and starts one paused, and saving from one writes a user slot only.
## Bible: docs/scenarios.md (M4.6-03)
extends GdUnitTestSuite

const MENU_SCENE: String = "res://src/scenes/main_menu/main_menu.tscn"


func after_test() -> void:
	GameStart.reset()


func test_every_shipped_scenario_loads() -> void:
	var scenarios: Array[ScenarioDef] = Registry.scenarios()
	assert_array(scenarios).is_not_empty()
	for scenario: ScenarioDef in scenarios:
		var result: Result = SaveService.load_file(
			scenario.save_path, GameDefs.from_registry(Registry)
		)
		(
			assert_bool(result.is_ok)
			. override_failure_message("%s: %s" % [scenario.id, result.detail])
			. is_true()
		)
		var defs: Dictionary[StringName, DefBase] = {}
		assert_array(scenario.get_content_errors(defs)).is_empty()


func test_listed_in_order() -> void:
	var scenarios: Array[ScenarioDef] = Registry.scenarios()
	for index: int in range(1, scenarios.size()):
		assert_int(scenarios[index].order).is_greater_equal(scenarios[index - 1].order)


func test_menu_shows_scenarios_and_starts_one() -> void:
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	menu.changes_scene = false
	add_child(menu)
	assert_bool(menu.scenarios_button.visible).is_true()
	menu.scenarios_button.pressed.emit()
	assert_int(menu.scenarios.rows().size()).is_equal(Registry.scenarios().size())
	menu.scenarios.rows()[0].pressed.emit()
	assert_int(GameStart.mode).is_equal(GameStart.Mode.SCENARIO)
	assert_object(GameStart.loaded).is_not_null()
	menu.free()


func test_saving_from_a_scenario_writes_a_user_slot() -> void:
	var scenario: ScenarioDef = Registry.scenarios()[0]
	var before: String = FileAccess.get_file_as_string(scenario.save_path)
	var loaded: Result = SaveService.load_file(scenario.save_path, GameDefs.from_registry(Registry))
	var state: GameState = loaded.value
	var real: String = SaveService.saves_dir
	SaveService.saves_dir = "user://test_scenario_%d" % Time.get_ticks_usec()
	assert_bool(SaveService.save_game(state, &"from_scenario").is_ok).is_true()
	assert_bool(SaveService.slot_path(&"from_scenario").begins_with("user://")).is_true()
	SaveService.delete_slot(&"from_scenario")
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = real
	assert_str(FileAccess.get_file_as_string(scenario.save_path)).is_equal(before)
	var missing := ScenarioDef.new()
	missing.id = &"x"
	missing.title_key = &"A"
	missing.description_key = &"B"
	missing.save_path = "res://data/scenarios/none.json"
	assert_array(missing.get_content_errors({})).is_not_empty()
