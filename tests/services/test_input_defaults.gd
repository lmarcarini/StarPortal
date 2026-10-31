## Tests for the default bindings of InputActions and the settings section that stores them.
## Each test runs its own InputService and Settings instances on a temporary user:// file,
## and the InputMap actions are restored after every test.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## game-design.md#difficulty-and-accessibility
extends GdUnitTestSuite

const InputServiceScript := preload("res://src/services/input_service.gd")
const SettingsScript := preload("res://src/services/settings.gd")
const TEST_PATH: String = "user://test_input_defaults.cfg"
const KEYBOARD := InputServiceScript.DeviceKind.KEYBOARD_MOUSE
const GAMEPAD := InputServiceScript.DeviceKind.GAMEPAD

## InputMap events of every action before the test; an absent action maps to null.
var _saved_input_map: Dictionary[StringName, Variant] = {}


func before_test() -> void:
	_remove_test_file()
	_saved_input_map.clear()
	for action: StringName in InputActions.ACTIONS:
		_saved_input_map[action] = null
		if InputMap.has_action(action):
			_saved_input_map[action] = InputMap.action_get_events(action)


func after_test() -> void:
	_remove_test_file()
	for action: StringName in _saved_input_map:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		var events: Variant = _saved_input_map[action]
		if events == null:
			continue
		InputMap.add_action(action)
		var saved: Array[InputEvent] = events
		for event: InputEvent in saved:
			InputMap.action_add_event(action, event)


## InputActions.DEFAULTS and the settings section both cover exactly the action list.
func test_defaults_and_settings_section_cover_every_action() -> void:
	assert_array(InputActions.DEFAULTS.keys()).contains_exactly_in_any_order(InputActions.ACTIONS)
	var section: Dictionary = SettingsDefaults.VALUES[&"input"]
	assert_array(section.keys()).contains_exactly_in_any_order(InputActions.ACTIONS)
	for action: StringName in InputActions.ACTIONS:
		assert_dict(section[action]).is_empty()


## The default table: M0's, with the time speed on the triggers (card #52 amendment), one
## gamepad button for the overlay (no chords), and the view actions on Q/E/F1/F2 and the
## shoulders.
func test_default_bindings() -> void:
	var service: InputServiceScript = _make_service()
	_assert_keys(service, &"time_toggle_pause", [KEY_SPACE])
	_assert_keys(service, &"time_faster", [KEY_EQUAL, KEY_KP_ADD])
	_assert_keys(service, &"time_slower", [KEY_MINUS, KEY_KP_SUBTRACT])
	_assert_keys(service, &"quick_save", [KEY_F5])
	_assert_keys(service, &"quick_load", [KEY_F9])
	_assert_keys(service, &"debug_toggle_overlay", [KEY_F12])
	_assert_keys(service, &"view_next", [KEY_E])
	_assert_keys(service, &"view_previous", [KEY_Q])
	_assert_keys(service, &"view_gate_room", [KEY_F1])
	_assert_keys(service, &"view_archive", [KEY_F2])
	_assert_keys(service, &"view_base", [KEY_F3])
	_assert_keys(service, &"base_level_up", [KEY_PAGEUP])
	_assert_keys(service, &"base_level_down", [KEY_PAGEDOWN])
	_assert_pad(service, &"time_toggle_pause", [JOY_BUTTON_START])
	_assert_trigger(service, &"time_faster", JOY_AXIS_TRIGGER_RIGHT)
	_assert_trigger(service, &"time_slower", JOY_AXIS_TRIGGER_LEFT)
	_assert_pad(service, &"quick_save", [])
	_assert_pad(service, &"quick_load", [])
	_assert_pad(service, &"debug_toggle_overlay", [JOY_BUTTON_BACK])
	_assert_pad(service, &"view_next", [JOY_BUTTON_RIGHT_SHOULDER])
	_assert_pad(service, &"view_previous", [JOY_BUTTON_LEFT_SHOULDER])
	_assert_pad(service, &"view_gate_room", [])
	_assert_pad(service, &"view_archive", [])
	_assert_pad(service, &"view_base", [])
	_assert_pad(service, &"base_level_up", [JOY_BUTTON_Y])
	_assert_pad(service, &"base_level_down", [JOY_BUTTON_X])


## No two default bindings of one device kind are the same event, so the defaults pass the
## conflict check that rebinding uses.
func test_default_bindings_do_not_conflict() -> void:
	var service: InputServiceScript = _make_service()
	for kind: InputServiceScript.DeviceKind in [KEYBOARD, GAMEPAD]:
		for action: StringName in InputActions.ACTIONS:
			for event: InputEvent in service.get_bindings(action, kind):
				if event == null:
					continue
				var holder: StringName = service.find_conflict(event, kind)
				var message: String = "%s shares %s with %s" % [action, event.as_text(), holder]
				assert_str(String(holder)).override_failure_message(message).is_equal(action)


## A trigger binding fires its action once pulled past the deadzone, not at rest.
func test_trigger_binding_needs_a_pull_past_the_deadzone() -> void:
	_make_service()
	var resting := InputEventJoypadMotion.new()
	resting.axis = JOY_AXIS_TRIGGER_RIGHT
	resting.axis_value = 0.1
	var pulled: InputEventJoypadMotion = resting.duplicate() as InputEventJoypadMotion
	pulled.axis_value = 0.6
	assert_bool(resting.is_action_pressed(&"time_faster")).is_false()
	assert_bool(pulled.is_action_pressed(&"time_faster")).is_true()
	assert_bool(pulled.is_action_pressed(&"time_slower")).is_false()


## Asserts the only gamepad binding of [param action] is [param axis] pulled forward.
func _assert_trigger(service: InputServiceScript, action: StringName, axis: JoyAxis) -> void:
	var expected: Dictionary = {"kind": "joypad_motion", "axis": axis, "direction": 1}
	(
		assert_array(_encoded(service.get_bindings(action, GAMEPAD)))
		. override_failure_message(String(action))
		. is_equal([expected, {}])
	)


## Key and button presses are new presses; echoes, releases and other actions are not.
func test_is_new_press_for_keys_and_buttons() -> void:
	_make_service()
	var key: InputEventKey = _key(KEY_E)
	assert_bool(InputActions.is_new_press(key, &"view_next")).is_true()
	assert_bool(InputActions.is_new_press(key, &"view_previous")).is_false()
	var echo: InputEventKey = key.duplicate() as InputEventKey
	echo.echo = true
	assert_bool(InputActions.is_new_press(echo, &"view_next")).is_false()
	var release: InputEventKey = key.duplicate() as InputEventKey
	release.pressed = false
	assert_bool(InputActions.is_new_press(release, &"view_next")).is_false()
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	shoulder.pressed = true
	assert_bool(InputActions.is_new_press(shoulder, &"view_previous")).is_true()
	var action := InputEventAction.new()
	action.action = &"view_archive"
	action.pressed = true
	assert_bool(InputActions.is_new_press(action, &"view_archive")).is_true()


## Returns an InputService on a fresh Settings instance at TEST_PATH, added to the tree.
func _make_service() -> InputServiceScript:
	var settings: SettingsScript = auto_free(SettingsScript.new())
	settings.file_path = TEST_PATH
	settings.reload()
	var service: InputServiceScript = auto_free(InputServiceScript.new())
	service.settings = settings
	add_child(service)
	return service


## Asserts the non-empty keyboard slots of [param action] hold these physical keycodes.
func _assert_keys(service: InputServiceScript, action: StringName, keys: Array) -> void:
	var found: Array = []
	for event: InputEvent in service.get_bindings(action, KEYBOARD):
		if event != null:
			found.append((event as InputEventKey).physical_keycode)
	assert_array(found).override_failure_message("%s: %s" % [action, found]).is_equal(keys)


## Asserts the non-empty gamepad slots of [param action] hold these joypad buttons.
func _assert_pad(service: InputServiceScript, action: StringName, buttons: Array) -> void:
	var found: Array = []
	for event: InputEvent in service.get_bindings(action, GAMEPAD):
		if event != null:
			found.append((event as InputEventJoypadButton).button_index)
	assert_array(found).override_failure_message("%s: %s" % [action, found]).is_equal(buttons)


static func _encoded(events: Array[InputEvent]) -> Array[Dictionary]:
	var encoded: Array[Dictionary] = []
	for event: InputEvent in events:
		encoded.append({} if event == null else InputEventCodec.encode(event))
	return encoded


static func _key(physical_keycode: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode
	key.pressed = true
	return key


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
