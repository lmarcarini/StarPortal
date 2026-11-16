## The tab bar of the interface pass: seven tabs in the loop's order, default keys F1 to F7
## in that order, icons drawn in code, the selected style and the attention dot.
## Bible: docs/content/interface-pass.md section 4
extends GdUnitTestSuite

const SWITCHER_SCENE: String = "res://src/ui/views/view_switcher.tscn"
const ORDER: Array[StringName] = [
	&"gate_room", &"base", &"research", &"personnel", &"archive", &"command"
]
const KEYS: Dictionary[StringName, Key] = {
	&"view_gate_room": KEY_F1,
	&"view_base": KEY_F2,
	&"view_research": KEY_F3,
	&"view_office": KEY_F4,
}


func test_six_tabs_in_the_new_order() -> void:
	var switcher: ViewSwitcher = auto_free(
		(load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
	)
	add_child(switcher)
	assert_array(switcher.get_view_ids()).is_equal(ORDER)
	assert_int(switcher.get_tab_bar().tab_count).is_equal(6)
	for index: int in ORDER.size():
		assert_object(switcher.get_tab_bar().get_tab_icon(index)).is_not_null()


func test_default_keys_follow_the_order() -> void:
	for action: StringName in KEYS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		var keys: Array[Key] = []
		for event: InputEvent in events:
			var key := event as InputEventKey
			if key != null:
				keys.append(key.physical_keycode)
		assert_array(keys).contains([KEYS[action]])


func test_every_icon_draws_something_at_80_percent() -> void:
	for view_id: StringName in ORDER:
		var icon: ImageTexture = TabIcon.texture(view_id, 0.8, Color.WHITE)
		assert_object(icon).is_not_null()
		var image: Image = icon.get_image()
		var lit: int = 0
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					lit += 1
		var area: int = image.get_width() * image.get_height()
		assert_int(lit).is_greater(area / 12)
		assert_int(lit).is_less(area * 2 / 3)


func test_icons_differ_from_each_other() -> void:
	var seen: Array[PackedByteArray] = []
	for view_id: StringName in ORDER:
		var data: PackedByteArray = (
			TabIcon.texture(view_id, 1.0, Color.WHITE).get_image().get_data()
		)
		assert_bool(seen.has(data)).is_false()
		seen.append(data)


func test_unknown_view_has_no_icon() -> void:
	assert_object(TabIcon.texture(&"nowhere", 1.0, Color.WHITE)).is_null()


func test_selected_tab_is_lit_orange() -> void:
	var theme: Theme = UiThemeBuilder.build(1.0)
	var lit := theme.get_stylebox(&"tab_selected", &"TabBar") as StyleBoxFlat
	assert_object(lit.border_color).is_equal(UiPalette.SELECT)
	assert_object(theme.get_color(&"font_selected_color", &"TabBar")).is_equal(UiPalette.SELECT)


func test_dot_shows_while_a_view_needs_attention() -> void:
	var switcher: ViewSwitcher = auto_free(
		(load(SWITCHER_SCENE) as PackedScene).instantiate() as ViewSwitcher
	)
	add_child(switcher)
	var command: GameView = switcher.get_view(&"command")
	assert_bool(command.needs_attention()).is_false()
	var index: int = ORDER.find(&"command")
	assert_str(switcher.get_tab_bar().get_tab_title(index)).not_contains("•")
