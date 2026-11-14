## The shell applies the interface theme and puts the grain overlay above everything.
## Bible: docs/content/interface-pass.md section 2
extends GdUnitTestSuite

const ShellScript := preload("res://src/scenes/shell/shell.gd")
const SHELL_SCENE: String = "res://src/scenes/shell/shell.tscn"


func test_shell_has_the_theme_and_the_overlay() -> void:
	var shell := (load(SHELL_SCENE) as PackedScene).instantiate() as ShellScript
	shell.new_game_seed = 7
	var runner: GdUnitSceneRunner = scene_runner(shell)
	await runner.await_input_processed()
	assert_object(shell.theme).is_not_null()
	assert_object(shell.theme.get_font(&"font", &"DataLabel")).is_equal(UiThemeBuilder.data_font())
	assert_object(shell.screen_grain.get_parent()).is_equal(shell)
	assert_int(shell.screen_grain.overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	shell.free()
