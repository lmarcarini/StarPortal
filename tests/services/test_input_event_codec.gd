## Tests for InputEventCodec: InputEvent <-> Dictionary for stored bindings.
## Bible: technical-architecture.md#input-accessibility-and-localisation
extends GdUnitTestSuite


## A key encodes by physical keycode only, so it keeps its position on any layout.
func test_key_round_trip_uses_physical_keycode() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_Q
	key.physical_keycode = KEY_A
	key.pressed = true
	var data: Dictionary = InputEventCodec.encode(key)
	assert_dict(data).is_equal({"kind": "key", "physical_keycode": KEY_A})

	var decoded: InputEventKey = InputEventCodec.decode(data)
	assert_int(decoded.physical_keycode).is_equal(KEY_A)
	assert_int(decoded.keycode).is_equal(KEY_NONE)
	assert_int(decoded.device).is_equal(InputEventCodec.ALL_DEVICES)


## Held modifiers are kept.
func test_key_with_modifiers_round_trip() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_S
	key.shift_pressed = true
	key.alt_pressed = true
	var data: Dictionary = InputEventCodec.encode(key)
	assert_int(data["modifiers"]).is_equal(KEY_MASK_SHIFT | KEY_MASK_ALT)

	var decoded: InputEventKey = InputEventCodec.decode(data)
	assert_bool(decoded.shift_pressed).is_true()
	assert_bool(decoded.alt_pressed).is_true()
	assert_bool(decoded.ctrl_pressed).is_false()
	assert_dict(InputEventCodec.encode(decoded)).is_equal(data)


## A key event without a physical keycode cannot be bound.
func test_key_without_physical_keycode_is_not_encodable() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	assert_dict(InputEventCodec.encode(key)).is_empty()


func test_mouse_button_round_trip() -> void:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_XBUTTON1
	button.pressed = true
	var data: Dictionary = InputEventCodec.encode(button)
	assert_dict(data).is_equal({"kind": "mouse_button", "button_index": MOUSE_BUTTON_XBUTTON1})

	var decoded: InputEventMouseButton = InputEventCodec.decode(data)
	assert_int(decoded.button_index).is_equal(MOUSE_BUTTON_XBUTTON1)
	assert_dict(InputEventCodec.encode(decoded)).is_equal(data)


func test_joypad_button_round_trip() -> void:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_RIGHT_SHOULDER
	button.device = 3
	var data: Dictionary = InputEventCodec.encode(button)
	assert_dict(data).is_equal({"kind": "joypad_button", "button_index": JOY_BUTTON_RIGHT_SHOULDER})

	var decoded: InputEventJoypadButton = InputEventCodec.decode(data)
	assert_int(decoded.button_index).is_equal(JOY_BUTTON_RIGHT_SHOULDER)
	assert_int(decoded.device).is_equal(InputEventCodec.ALL_DEVICES)


## An axis keeps its direction and loses its strength.
func test_joypad_axis_round_trip_keeps_direction() -> void:
	for value: float in [0.6, -0.3]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_Y
		motion.axis_value = value
		var data: Dictionary = InputEventCodec.encode(motion)
		var direction: int = 1 if value > 0.0 else -1
		assert_dict(data).is_equal(
			{"kind": "joypad_motion", "axis": JOY_AXIS_LEFT_Y, "direction": direction}
		)
		var decoded: InputEventJoypadMotion = InputEventCodec.decode(data)
		assert_int(decoded.axis).is_equal(JOY_AXIS_LEFT_Y)
		assert_float(decoded.axis_value).is_equal(float(direction))


## An axis at rest has no direction, so it cannot be bound.
func test_joypad_axis_at_rest_is_not_encodable() -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_RIGHT_X
	motion.axis_value = 0.0
	assert_dict(InputEventCodec.encode(motion)).is_empty()


func test_unsupported_events_encode_empty() -> void:
	assert_dict(InputEventCodec.encode(InputEventMouseMotion.new())).is_empty()
	assert_dict(InputEventCodec.encode(InputEventAction.new())).is_empty()
	assert_dict(InputEventCodec.encode(null)).is_empty()


## Malformed data decodes to null instead of a wrong event.
func test_decode_rejects_invalid_data() -> void:
	var invalid: Array[Dictionary] = [
		{},
		{"kind": 7},
		{"kind": "gesture"},
		{"kind": "key"},
		{"kind": "key", "physical_keycode": "space"},
		{"kind": "key", "physical_keycode": 0},
		{"kind": "key", "physical_keycode": 32.0},
		{"kind": "key", "physical_keycode": KEY_SPACE, "modifiers": 1},
		{"kind": "mouse_button", "button_index": 0},
		{"kind": "mouse_button", "button_index": 99},
		{"kind": "joypad_button", "button_index": -1},
		{"kind": "joypad_button", "button_index": JOY_BUTTON_MAX},
		{"kind": "joypad_motion", "axis": JOY_AXIS_LEFT_X},
		{"kind": "joypad_motion", "axis": JOY_AXIS_LEFT_X, "direction": 0},
		{"kind": "joypad_motion", "axis": JOY_AXIS_MAX, "direction": 1},
	]
	for data: Dictionary in invalid:
		assert_object(InputEventCodec.decode(data)).override_failure_message(str(data)).is_null()


## encode -> ConfigFile text -> decode gives an equal event for every supported kind.
func test_round_trip_through_config_file() -> void:
	var events: Array[InputEvent] = _sample_events()
	var config := ConfigFile.new()
	for index: int in events.size():
		config.set_value("input", str(index), InputEventCodec.encode(events[index]))
	var reread := ConfigFile.new()
	assert_int(reread.parse(config.encode_to_text())).is_equal(OK)
	for index: int in events.size():
		var stored: Dictionary = reread.get_value("input", str(index))
		var decoded: InputEvent = InputEventCodec.decode(stored)
		assert_object(decoded).is_not_null()
		assert_dict(InputEventCodec.encode(decoded)).is_equal(InputEventCodec.encode(events[index]))
		assert_bool(decoded.is_match(events[index])).is_true()


## One bindable event of each supported kind.
func _sample_events() -> Array[InputEvent]:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F5
	key.ctrl_pressed = true
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_TRIGGER_RIGHT
	motion.axis_value = 1.0
	return [key, mouse, button, motion]
