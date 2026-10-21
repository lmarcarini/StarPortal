## Smoke tests proving the gdUnit4 harness runs headless and sees the project settings.
## Bible: technical-architecture.md#testing-and-tooling
extends GdUnitTestSuite

const MAIN_SCENE_SETTING: String = "application/run/main_scene"
const EXPECTED_MAIN_SCENE: String = "res://src/scenes/shell/shell.tscn"


## The harness evaluates a trivial assertion.
func test_one_plus_one_equals_two() -> void:
	var sum: int = 1 + 1
	assert_int(sum).is_equal(3)


## The project boots into the shell scene.
func test_main_scene_is_shell() -> void:
	var main_scene: String = ProjectSettings.get_setting(MAIN_SCENE_SETTING)
	assert_str(main_scene).is_equal(EXPECTED_MAIN_SCENE)
