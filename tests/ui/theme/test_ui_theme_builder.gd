## The theme builder: fonts, variations, scale and that no style uses the Ring blue.
## Bible: docs/content/interface-pass.md section 2
extends GdUnitTestSuite


func test_build_sets_fonts_and_body_size_of_at_least_16_at_full_scale() -> void:
	var theme: Theme = UiThemeBuilder.build(1.0)
	assert_object(theme.default_font).is_not_null()
	assert_int(theme.default_font_size).is_greater_equal(16)
	assert_object(theme.get_font(&"font", &"DataLabel")).is_equal(UiThemeBuilder.data_font())


func test_every_variation_exists() -> void:
	var theme: Theme = UiThemeBuilder.build(1.0)
	var expected: Dictionary[StringName, StringName] = {
		&"PanelBezel": &"PanelContainer",
		&"HeaderStrip": &"Label",
		&"KeyButton": &"Button",
		&"KeyButtonSelected": &"Button",
		&"DataLabel": &"Label",
		&"StencilLabel": &"Label",
	}
	for variation: StringName in expected:
		assert_str(theme.get_type_variation_base(variation)).is_equal(expected[variation])


func test_scale_grows_sizes_and_is_clamped() -> void:
	var small: Theme = UiThemeBuilder.build(0.8)
	var large: Theme = UiThemeBuilder.build(1.5)
	assert_int(large.default_font_size).is_greater(small.default_font_size)
	assert_int(UiThemeBuilder.build(3.0).default_font_size).is_equal(large.default_font_size)
	assert_int(UiThemeBuilder.build(0.1).default_font_size).is_equal(small.default_font_size)


func test_pressed_key_sits_down_and_selected_glows_orange() -> void:
	var theme: Theme = UiThemeBuilder.build(1.0)
	var normal := theme.get_stylebox(&"normal", &"KeyButton") as StyleBoxFlat
	var pressed := theme.get_stylebox(&"pressed", &"KeyButton") as StyleBoxFlat
	assert_int(normal.border_width_bottom).is_greater(pressed.border_width_bottom)
	assert_int(pressed.border_width_top).is_greater(normal.border_width_top)
	var lit := theme.get_stylebox(&"normal", &"KeyButtonSelected") as StyleBoxFlat
	assert_object(lit.border_color).is_equal(UiPalette.SELECT)
	assert_int(lit.shadow_size).is_greater(0)


func test_no_style_or_colour_uses_the_ring_blue() -> void:
	var theme: Theme = UiThemeBuilder.build(1.0)
	for type: StringName in theme.get_type_list():
		for name: StringName in theme.get_color_list(type):
			assert_bool(theme.get_color(name, type).is_equal_approx(UiPalette.RING)).is_false()
		for name: StringName in theme.get_stylebox_list(type):
			var box := theme.get_stylebox(name, type) as StyleBoxFlat
			if box == null:
				continue
			assert_bool(box.bg_color.is_equal_approx(UiPalette.RING)).is_false()
			assert_bool(box.border_color.is_equal_approx(UiPalette.RING)).is_false()
