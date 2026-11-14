## Tests for InputService, InputActions and the settings section that stores bindings.
## Each test runs its own InputService and Settings instances on a temporary user:// file,
## and the InputMap actions are restored after every test.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## game-design.md#difficulty-and-accessibility
extends GdUnitTestSuite

const InputServiceScript := preload("res://src/services/input_service.gd")
const SettingsScript := preload("res://src/services/settings.gd")
const TEST_PATH: String = "user://test_input_service.cfg"
const KEYBOARD := InputServiceScript.DeviceKind.KEYBOARD_MOUSE
const GAMEPAD := InputServiceScript.DeviceKind.GAMEPAD

## InputMap events of every action before the test; an absent action maps to null.
var _saved_input_map: Dictionary[StringName, Variant] = {}
## Every input_device_changed emission of the service under test.
var _device_changes: Array[int] = []
## Every bindings_changed emission of the service under test.
var _changed_actions: Array[StringName] = []


func before_test() -> void:
	_remove_test_file()
	_device_changes.clear()
	_changed_actions.clear()
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


## Every action is registered in InputMap at start-up with its defaults, and none is declared
## in project.godot.
func test_actions_registered_at_start_up_not_in_project_settings() -> void:
	for action: StringName in InputActions.ACTIONS:
		InputMap.erase_action(action)
	_make_service()
	for action: StringName in InputActions.ACTIONS:
		assert_bool(InputMap.has_action(action)).is_true()
		assert_bool(ProjectSettings.has_setting("input/%s" % action)).is_false()
	assert_bool(InputMap.event_is_action(_key(KEY_SPACE), &"time_toggle_pause")).is_true()
	assert_bool(InputMap.event_is_action(_button(JOY_BUTTON_START), &"time_toggle_pause")).is_true()
	assert_bool(InputMap.event_is_action(_key(KEY_F8), &"quick_save")).is_true()


## Keys are bound by physical keycode: the key in the Space position triggers the action
## whatever character the layout gives it, and the Space character elsewhere does not.
func test_keys_bound_by_physical_keycode() -> void:
	var service: InputServiceScript = _make_service()
	var bound: InputEventKey = service.get_bindings(&"time_toggle_pause", KEYBOARD)[0]
	assert_int(bound.keycode).is_equal(KEY_NONE)
	assert_int(bound.physical_keycode).is_equal(KEY_SPACE)

	var same_position := InputEventKey.new()
	same_position.physical_keycode = KEY_SPACE
	same_position.keycode = KEY_Q
	assert_bool(InputMap.event_is_action(same_position, &"time_toggle_pause")).is_true()
	var other_position := InputEventKey.new()
	other_position.physical_keycode = KEY_Q
	other_position.keycode = KEY_SPACE
	assert_bool(InputMap.event_is_action(other_position, &"time_toggle_pause")).is_false()


## get_bindings always gives BINDINGS_PER_DEVICE slots, null when empty, as copies.
func test_get_bindings_gives_fixed_slots() -> void:
	var service: InputServiceScript = _make_service()
	var slots: Array[InputEvent] = service.get_bindings(&"quick_save", GAMEPAD)
	assert_int(slots.size()).is_equal(InputServiceScript.BINDINGS_PER_DEVICE)
	assert_object(slots[0]).is_null()
	assert_object(slots[1]).is_null()

	var keys: Array[InputEvent] = service.get_bindings(&"quick_save", KEYBOARD)
	(keys[0] as InputEventKey).physical_keycode = KEY_Z
	_assert_keys(service, &"quick_save", [KEY_F8])


## rebind applies to InputMap, persists, emits bindings_changed and returns the event.
func test_rebind_applies_and_persists() -> void:
	var service: InputServiceScript = _make_service()
	var result: Result = service.rebind(&"quick_save", KEYBOARD, 1, _key(KEY_K))
	assert_bool(result.is_ok).is_true()
	var bound: InputEventKey = result.value
	assert_int(bound.physical_keycode).is_equal(KEY_K)
	_assert_keys(service, &"quick_save", [KEY_F8, KEY_K])
	assert_bool(InputMap.event_is_action(_key(KEY_K), &"quick_save")).is_true()
	assert_array(_changed_actions).is_equal([&"quick_save"])

	var config := ConfigFile.new()
	assert_int(config.load(TEST_PATH)).is_equal(OK)
	var stored: Dictionary = config.get_value("input", "quick_save")
	assert_array(stored[InputActions.KEYBOARD]).is_equal(
		[{"kind": "key", "physical_keycode": KEY_F8}, {"kind": "key", "physical_keycode": KEY_K}]
	)


## A conflicting event on the same device kind is refused and names the other action.
func test_rebind_refuses_conflict_and_names_other_action() -> void:
	var service: InputServiceScript = _make_service()
	var result: Result = service.rebind(&"time_faster", KEYBOARD, 0, _key(KEY_SPACE))
	assert_bool(result.is_ok).is_false()
	assert_str(result.error_code).is_equal(&"binding_conflict")
	assert_str(result.detail).is_equal("time_toggle_pause")
	_assert_keys(service, &"time_faster", [KEY_EQUAL, KEY_KP_ADD])
	assert_array(_changed_actions).is_empty()

	var pad: Result = service.rebind(&"quick_save", GAMEPAD, 0, _button(JOY_BUTTON_BACK))
	assert_str(pad.error_code).is_equal(&"binding_conflict")
	assert_str(pad.detail).is_equal("base_energy_layer")


## Conflicts are checked within one device kind only.
func test_find_conflict_is_per_device_kind() -> void:
	var service: InputServiceScript = _make_service()
	assert_str(service.find_conflict(_key(KEY_SPACE), KEYBOARD)).is_equal(&"time_toggle_pause")
	assert_str(service.find_conflict(_key(KEY_SPACE), GAMEPAD)).is_equal(&"")
	assert_str(service.find_conflict(_key(KEY_J), KEYBOARD)).is_equal(&"")
	assert_str(service.find_conflict(_button(JOY_BUTTON_BACK), GAMEPAD)).is_equal(
		&"base_energy_layer"
	)


## Rebinding a slot to the event it already holds succeeds without a change.
func test_rebind_same_event_is_a_no_op() -> void:
	var service: InputServiceScript = _make_service()
	var result: Result = service.rebind(&"time_toggle_pause", KEYBOARD, 0, _key(KEY_SPACE))
	assert_bool(result.is_ok).is_true()
	assert_array(_changed_actions).is_empty()


func test_rebind_refuses_invalid_requests() -> void:
	var service: InputServiceScript = _make_service()
	var cases: Array[Array] = [
		[&"fly", KEYBOARD, 0, _key(KEY_K), &"unknown_action"],
		[&"quick_save", KEYBOARD, 2, _key(KEY_K), &"invalid_slot"],
		[&"quick_save", KEYBOARD, -1, _key(KEY_K), &"invalid_slot"],
		[&"quick_save", KEYBOARD, 0, InputEventMouseMotion.new(), &"invalid_event"],
		[&"quick_save", KEYBOARD, 0, _button(JOY_BUTTON_X), &"wrong_device"],
		[&"quick_save", GAMEPAD, 0, _key(KEY_K), &"wrong_device"],
	]
	for case: Array in cases:
		var action: StringName = case[0]
		var kind: InputServiceScript.DeviceKind = case[1]
		var slot: int = case[2]
		var event: InputEvent = case[3]
		var result: Result = service.rebind(action, kind, slot, event)
		assert_str(result.error_code).override_failure_message(str(case)).is_equal(case[4])
	assert_array(_changed_actions).is_empty()


## clear_binding empties a slot, removes it from InputMap and persists.
func test_clear_binding() -> void:
	var service: InputServiceScript = _make_service()
	service.clear_binding(&"time_faster", KEYBOARD, 0)
	var slots: Array[InputEvent] = service.get_bindings(&"time_faster", KEYBOARD)
	assert_object(slots[0]).is_null()
	assert_int((slots[1] as InputEventKey).physical_keycode).is_equal(KEY_KP_ADD)
	assert_bool(InputMap.event_is_action(_key(KEY_EQUAL), &"time_faster")).is_false()
	assert_array(_changed_actions).is_equal([&"time_faster"])
	assert_object(_make_service().get_bindings(&"time_faster", KEYBOARD)[0]).is_null()


## reset_to_defaults restores every default, clears the stored section and signals changes.
func test_reset_to_defaults() -> void:
	var service: InputServiceScript = _make_service()
	service.rebind(&"quick_load", KEYBOARD, 0, _key(KEY_L))
	service.clear_binding(&"time_toggle_pause", GAMEPAD, 0)
	_changed_actions.clear()
	service.reset_to_defaults()
	_assert_keys(service, &"quick_load", [KEY_F9])
	_assert_pad(service, &"time_toggle_pause", [JOY_BUTTON_START])
	assert_bool(InputMap.event_is_action(_key(KEY_L), &"quick_load")).is_false()
	assert_array(_changed_actions).contains_exactly_in_any_order(
		[&"quick_load", &"time_toggle_pause"]
	)
	var config := ConfigFile.new()
	assert_int(config.load(TEST_PATH)).is_equal(OK)
	assert_dict(config.get_value("input", "quick_load")).is_empty()


## Bindings survive a restart: encode -> Settings -> decode gives equal events.
func test_bindings_survive_restart() -> void:
	var service: InputServiceScript = _make_service()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	var shifted: InputEventKey = _key(KEY_S)
	shifted.shift_pressed = true
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -0.8
	assert_bool(service.rebind(&"quick_save", KEYBOARD, 0, shifted).is_ok).is_true()
	assert_bool(service.rebind(&"quick_save", KEYBOARD, 1, mouse).is_ok).is_true()
	assert_bool(service.rebind(&"quick_save", GAMEPAD, 1, stick).is_ok).is_true()

	var restarted: InputServiceScript = _make_service()  # new instances reading TEST_PATH
	for kind: InputServiceScript.DeviceKind in [KEYBOARD, GAMEPAD]:
		assert_array(_encoded(restarted.get_bindings(&"quick_save", kind))).is_equal(
			_encoded(service.get_bindings(&"quick_save", kind))
		)
	assert_bool(InputMap.event_is_action(stick, &"quick_save")).is_true()
	assert_bool(InputMap.event_is_action(mouse, &"quick_save")).is_true()


## Invalid stored data falls back to the defaults of that action only.
func test_invalid_stored_bindings_fall_back_for_that_action_only() -> void:
	var config := ConfigFile.new()
	var pad_y: Dictionary = {"kind": "joypad_button", "button_index": JOY_BUTTON_Y}
	config.set_value("input", "time_faster", {"keyboard": [{"kind": "key"}], "gamepad": []})
	config.set_value("input", "time_slower", {"keyboard": [{}, {}], "gamepad": [pad_y]})
	config.set_value("input", "quick_load", {"keyboard": [pad_y], "gamepad": []})
	config.set_value(
		"input",
		"quick_save",
		{"keyboard": [{"kind": "key", "physical_keycode": KEY_K}, {}], "gamepad": [{}, {}]}
	)
	assert_int(config.save(TEST_PATH)).is_equal(OK)

	var service: InputServiceScript = _make_service()
	_assert_keys(service, &"time_faster", [KEY_EQUAL, KEY_KP_ADD])
	_assert_keys(service, &"time_slower", [])
	_assert_pad(service, &"time_slower", [JOY_BUTTON_Y])
	_assert_keys(service, &"quick_load", [KEY_F9])
	_assert_keys(service, &"quick_save", [KEY_K])
	_assert_keys(service, &"time_toggle_pause", [KEY_SPACE])


## The first meaningful input from the other device kind switches current_device and signals
## once; stick movement under 0.2, releases and echoes are ignored.
func test_device_switching() -> void:
	var service: InputServiceScript = _make_service()
	assert_int(service.current_device).is_equal(KEYBOARD)
	service._input(_motion(0.19))
	service._input(_motion(-0.1))
	var released: InputEventJoypadButton = _button(JOY_BUTTON_A)
	released.pressed = false
	service._input(released)
	assert_int(service.current_device).is_equal(KEYBOARD)
	assert_array(_device_changes).is_empty()

	service._input(_motion(-0.2))
	service._input(_button(JOY_BUTTON_A))
	service._input(_motion(0.9))
	assert_int(service.current_device).is_equal(GAMEPAD)
	assert_array(_device_changes).is_equal([GAMEPAD])

	var echo: InputEventKey = _key(KEY_K)
	echo.echo = true
	service._input(echo)
	assert_array(_device_changes).is_equal([GAMEPAD])
	service._input(_key(KEY_K))
	service._input(_key(KEY_J))
	assert_int(service.current_device).is_equal(KEYBOARD)
	assert_array(_device_changes).is_equal([GAMEPAD, KEYBOARD])


## Mouse buttons and movement count as the keyboard/mouse device.
func test_mouse_switches_back_to_keyboard_mouse() -> void:
	var service: InputServiceScript = _make_service()
	service._input(_button(JOY_BUTTON_B))
	service._input(InputEventMouseMotion.new())
	assert_int(service.current_device).is_equal(GAMEPAD)
	var moved := InputEventMouseMotion.new()
	moved.relative = Vector2(3.0, 0.0)
	service._input(moved)
	assert_int(service.current_device).is_equal(KEYBOARD)
	assert_array(_device_changes).is_equal([GAMEPAD, KEYBOARD])


## Gameplay and UI code never read raw keys: no KEY_ constant or is_key_pressed in src/
## outside the input services.
func test_no_raw_key_reads_outside_input_services() -> void:
	var pattern := RegEx.create_from_string("\\bKEY_[A-Z0-9_]+|is_key_pressed")
	var offenders: Array[String] = []
	for path: String in _scripts_under("res://src"):
		if path.begins_with("res://src/services/input_"):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			if pattern.search(lines[index]) != null:
				offenders.append("%s:%d" % [path, index + 1])
	assert_array(offenders).is_empty()


## Returns an InputService on a fresh Settings instance at TEST_PATH, added to the tree.
func _make_service() -> InputServiceScript:
	var settings: SettingsScript = auto_free(SettingsScript.new())
	settings.file_path = TEST_PATH
	settings.reload()
	var service: InputServiceScript = auto_free(InputServiceScript.new())
	service.settings = settings
	service.input_device_changed.connect(func(kind: int) -> void: _device_changes.append(kind))
	service.bindings_changed.connect(
		func(action: StringName) -> void: _changed_actions.append(action)
	)
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


static func _button(index: JoyButton) -> InputEventJoypadButton:
	var button := InputEventJoypadButton.new()
	button.button_index = index
	button.pressed = true
	return button


static func _motion(value: float) -> InputEventJoypadMotion:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = value
	return motion


## Every .gd file under [param directory], recursively.
static func _scripts_under(directory: String) -> Array[String]:
	var found: Array[String] = []
	for file: String in DirAccess.get_files_at(directory):
		if file.get_extension() == "gd":
			found.append(directory.path_join(file))
	for child: String in DirAccess.get_directories_at(directory):
		found.append_array(_scripts_under(directory.path_join(child)))
	return found


func _remove_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
