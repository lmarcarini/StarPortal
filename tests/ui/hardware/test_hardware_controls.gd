## Tests for the hardware kit: keys fire (and hold to confirm), icon key states differ and
## disable, lamps, gauge, lever, hover cards on focus, and touch targets at 80%.
## Bible: docs/content/interface-rethink.md sections 2 and 7
extends GdUnitTestSuite

var _root: Control = null


func before_test() -> void:
	_root = Control.new()
	_root.theme = UiThemeBuilder.build(0.8)
	_root.size = Vector2(1280, 720)
	add_child(_root)


func after_test() -> void:
	_root.free()


func test_big_key_fires_on_press() -> void:
	var key: BigKey = BigKey.new()
	_root.add_child(key)
	var fired: Array[int] = [0]
	key.activated.connect(func() -> void: fired[0] += 1)
	key.pressed.emit()
	assert_int(fired[0]).is_equal(1)


func test_big_key_hold_to_confirm() -> void:
	var key: BigKey = BigKey.new()
	key.hold_to_confirm = true
	_root.add_child(key)
	var fired: Array[int] = [0]
	key.activated.connect(func() -> void: fired[0] += 1)
	key.pressed.emit()
	key.button_down.emit()
	key.advance(0.3)
	assert_float(key.get_hold_progress()).is_greater(0.0)
	assert_int(fired[0]).is_equal(0)
	key.advance(0.4)
	assert_int(fired[0]).is_equal(1)


func test_icon_key_states() -> void:
	var key: IconKey = IconKey.new()
	_root.add_child(key)
	key.set_state(IconKey.KeyState.UNAVAILABLE)
	assert_bool(key.disabled).is_true()
	key.set_state(IconKey.KeyState.ACTIVE)
	assert_bool(key.disabled).is_false()
	assert_int(key.get_state()).is_equal(IconKey.KeyState.ACTIVE)


func test_every_icon_draws() -> void:
	var key: IconKey = IconKey.new()
	_root.add_child(key)
	for id: StringName in HardwareIcons.IDS:
		assert_bool(HardwareIcons.draw(key, id, Rect2(0, 0, 32, 32), Color.WHITE)).is_true()
	assert_bool(HardwareIcons.draw(key, &"nope", Rect2(0, 0, 32, 32), Color.WHITE)).is_false()


func test_touch_targets_at_80_percent() -> void:
	var controls: Array[Control] = [BigKey.new(), IconKey.new(), Lever.new()]
	for c: Control in controls:
		_root.add_child(c)
		assert_float(c.get_combined_minimum_size().x).is_greater_equal(44.0)
		assert_float(c.get_combined_minimum_size().y).is_greater_equal(44.0)
		assert_int(c.focus_mode).is_equal(Control.FOCUS_ALL)


func test_hover_card_on_focus() -> void:
	var key: IconKey = IconKey.new()
	_root.add_child(key)
	key.set_help("HW_ICON_TEAM")
	var card: HoverCard = key.find_child("HoverCard", false, false) as HoverCard
	assert_bool(card.visible).is_false()
	key.grab_focus()
	assert_bool(card.visible).is_true()
	key.release_focus()
	assert_bool(card.visible).is_false()


func test_lamp_and_lever_and_gauge() -> void:
	var lamp: IndicatorLamp = IndicatorLamp.new()
	lamp.set_lit(true, Color.RED)
	assert_bool(lamp.is_lit()).is_true()
	lamp.free()
	var lever: Lever = Lever.new()
	_root.add_child(lever)
	lever.button_pressed = true
	assert_bool(lever.is_down()).is_true()
	var gauge: AnalogGauge = AnalogGauge.new()
	gauge.min_value = 0.0
	gauge.max_value = 100.0
	assert_float(gauge.angle_of(-5.0)).is_equal(gauge.angle_of(0.0))
	assert_float(gauge.angle_of(100.0)).is_greater(gauge.angle_of(50.0))
	gauge.free()


func test_gallery_builds() -> void:
	var gallery: Control = (
		(load("res://src/ui/hardware/hardware_gallery.tscn") as PackedScene).instantiate()
	)
	_root.add_child(gallery)
	assert_object(gallery.find_child("Icons", true, false)).is_not_null()
