## Smoke tests proving the gdUnit4 harness runs headless and sees the project settings.
## Bible: technical-architecture.md#testing-and-tooling
extends GdUnitTestSuite

const MAIN_SCENE_SETTING: String = "application/run/main_scene"
const EXPECTED_MAIN_SCENE: String = "res://src/scenes/main_menu/main_menu.tscn"


## The harness evaluates a trivial assertion.
func test_one_plus_one_equals_two() -> void:
	var sum: int = 1 + 1
	assert_int(sum).is_equal(2)


## The project boots into the main menu (M4.6-01).
func test_main_scene_is_the_menu() -> void:
	var main_scene: String = ProjectSettings.get_setting(MAIN_SCENE_SETTING)
	assert_str(main_scene).is_equal(EXPECTED_MAIN_SCENE)
