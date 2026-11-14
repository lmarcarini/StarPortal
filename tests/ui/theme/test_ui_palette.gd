## Palette values match the interface pass, text contrast is readable and the Ring blue is
## reserved for the Ring.
## Bible: docs/content/interface-pass.md section 2
extends GdUnitTestSuite


func test_palette_matches_the_design_table() -> void:
	assert_str(UiPalette.GROUND.to_html(false)).is_equal("14181a")
	assert_str(UiPalette.PANEL.to_html(false)).is_equal("1d2326")
	assert_str(UiPalette.RULE.to_html(false)).is_equal("39444a")
	assert_str(UiPalette.TEXT.to_html(false)).is_equal("e2e0d4")
	assert_str(UiPalette.TEXT_DIM.to_html(false)).is_equal("9ca3a0")
	assert_str(UiPalette.SELECT.to_html(false)).is_equal("e8a33d")
	assert_str(UiPalette.GOOD.to_html(false)).is_equal("7fd68a")
	assert_str(UiPalette.ALARM.to_html(false)).is_equal("e5533d")
	assert_str(UiPalette.RING.to_html(false)).is_equal("3fa9f5")


func test_text_contrast_is_at_least_4_5_on_panel_and_ground() -> void:
	for text: Color in [UiPalette.TEXT, UiPalette.TEXT_DIM]:
		for ground: Color in [UiPalette.PANEL, UiPalette.GROUND, UiPalette.HEADER]:
			assert_float(UiPalette.contrast(text, ground)).is_greater_equal(4.5)


func test_contrast_of_black_on_white_is_21() -> void:
	assert_float(UiPalette.contrast(Color.BLACK, Color.WHITE)).is_equal_approx(21.0, 0.01)
