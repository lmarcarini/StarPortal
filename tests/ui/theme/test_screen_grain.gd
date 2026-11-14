## The grain overlay never takes input and follows the display/screen_grain setting.
## Bible: docs/content/interface-pass.md section 2
extends GdUnitTestSuite


func test_overlay_ignores_input_and_draws_above_screens() -> void:
	var grain: ScreenGrain = auto_free(ScreenGrain.new())
	assert_int(grain.overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(grain.overlay.focus_mode).is_equal(Control.FOCUS_NONE)
	assert_int(grain.layer).is_greater(1)


func test_setting_turns_the_overlay_off_and_on() -> void:
	var grain: ScreenGrain = auto_free(ScreenGrain.new())
	add_child(grain)
	assert_bool(grain.visible).is_equal(Settings.get_bool(&"display", &"screen_grain"))
	# The autoload's file is never written by tests: feed the change signal directly.
	grain._on_setting_changed(&"display", &"screen_grain", false)
	assert_bool(grain.visible).is_false()
	grain._on_setting_changed(&"audio", &"screen_grain", true)
	assert_bool(grain.visible).is_false()
	grain._on_setting_changed(&"display", &"screen_grain", true)
	assert_bool(grain.visible).is_true()
