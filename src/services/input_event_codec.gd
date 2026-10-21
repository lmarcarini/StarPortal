class_name InputEventCodec
extends RefCounted
## Converts a bindable [InputEvent] to a plain [Dictionary] and back, so bindings can be
## stored in [code]Settings[/code]. Supported events: keys (by physical keycode, with
## modifiers), mouse buttons, joypad buttons and joypad axes with a direction. Anything else
## encodes to an empty Dictionary and decodes to null.
## Bible: technical-architecture.md#input-accessibility-and-localisation

## Value of [code]"kind"[/code] for a key, bound by its physical position.
const KIND_KEY: String = "key"
## Value of [code]"kind"[/code] for a mouse button.
const KIND_MOUSE_BUTTON: String = "mouse_button"
## Value of [code]"kind"[/code] for a joypad button.
const KIND_JOYPAD_BUTTON: String = "joypad_button"
## Value of [code]"kind"[/code] for a joypad axis pushed in one direction.
const KIND_JOYPAD_MOTION: String = "joypad_motion"
## Device id of every decoded event: the binding matches every connected device.
const ALL_DEVICES: int = -1
## Modifier bits a stored key or mouse button may carry.
const MODIFIER_BITS: int = (
	KEY_MASK_SHIFT | KEY_MASK_ALT | KEY_MASK_CTRL | KEY_MASK_META | KEY_MASK_CMD_OR_CTRL
)
## Returned by [method _read_int] when a field is missing, not an int or out of range.
const _INVALID: int = -1


## Returns [param event] as a Dictionary such as
## [code]{"kind": "key", "physical_keycode": 32}[/code], or an empty Dictionary when the
## event cannot be bound (unsupported type, a key without a physical keycode, an axis at rest).
## Only what identifies the binding is kept: never the pressed state, device or axis strength.
static func encode(event: InputEvent) -> Dictionary:
	var data: Dictionary = {}
	if event is InputEventKey:
		data = _encode_key(event as InputEventKey)
	elif event is InputEventMouseButton:
		data = _encode_mouse_button(event as InputEventMouseButton)
	elif event is InputEventJoypadButton:
		var button: InputEventJoypadButton = event
		data = {"kind": KIND_JOYPAD_BUTTON, "button_index": int(button.button_index)}
	elif event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		var direction: int = int(signf(motion.axis_value))
		data = {"kind": KIND_JOYPAD_MOTION, "axis": int(motion.axis), "direction": direction}
	if decode(data) == null:
		return {}
	return data


## Returns the event described by [param data] (as made by [method encode]), matching every
## device, or null when [param data] is not a valid encoded event.
static func decode(data: Dictionary) -> InputEvent:
	var kind: Variant = data.get("kind")
	if typeof(kind) != TYPE_STRING and typeof(kind) != TYPE_STRING_NAME:
		return null
	var kind_name: String = kind
	var event: InputEvent = null
	match kind_name:
		KIND_KEY:
			event = _decode_key(data)
		KIND_MOUSE_BUTTON:
			event = _decode_mouse_button(data)
		KIND_JOYPAD_BUTTON:
			event = _decode_joypad_button(data)
		KIND_JOYPAD_MOTION:
			event = _decode_joypad_motion(data)
	if event != null:
		event.device = ALL_DEVICES
	return event


## Encodes a key by physical keycode; modifiers only when any is held.
static func _encode_key(key: InputEventKey) -> Dictionary:
	var data: Dictionary = {"kind": KIND_KEY, "physical_keycode": int(key.physical_keycode)}
	_add_modifiers(data, key)
	return data


## Encodes a mouse button; modifiers only when any is held.
static func _encode_mouse_button(button: InputEventMouseButton) -> Dictionary:
	var data: Dictionary = {"kind": KIND_MOUSE_BUTTON, "button_index": int(button.button_index)}
	_add_modifiers(data, button)
	return data


## Adds [code]"modifiers"[/code] to [param data] when [param event] holds any modifier.
static func _add_modifiers(data: Dictionary, event: InputEventWithModifiers) -> void:
	var mask: int = event.get_modifiers_mask()
	if mask != 0:
		data["modifiers"] = mask


static func _decode_key(data: Dictionary) -> InputEvent:
	var physical_keycode: int = _read_int(data, "physical_keycode", 1, KEY_CODE_MASK)
	var modifiers: int = _read_modifiers(data)
	if physical_keycode == _INVALID or modifiers == _INVALID:
		return null
	var key := InputEventKey.new()
	key.physical_keycode = physical_keycode as Key
	_apply_modifiers(key, modifiers)
	key.pressed = true
	return key


static func _decode_mouse_button(data: Dictionary) -> InputEvent:
	var index: int = _read_int(data, "button_index", MOUSE_BUTTON_LEFT, MOUSE_BUTTON_XBUTTON2)
	var modifiers: int = _read_modifiers(data)
	if index == _INVALID or modifiers == _INVALID:
		return null
	var button := InputEventMouseButton.new()
	button.button_index = index as MouseButton
	_apply_modifiers(button, modifiers)
	button.pressed = true
	return button


static func _decode_joypad_button(data: Dictionary) -> InputEvent:
	var index: int = _read_int(data, "button_index", 0, JOY_BUTTON_MAX - 1)
	if index == _INVALID:
		return null
	var button := InputEventJoypadButton.new()
	button.button_index = index as JoyButton
	button.pressed = true
	return button


static func _decode_joypad_motion(data: Dictionary) -> InputEvent:
	var axis: int = _read_int(data, "axis", 0, JOY_AXIS_MAX - 1)
	var direction: Variant = data.get("direction")
	if axis == _INVALID or typeof(direction) != TYPE_INT:
		return null
	var pointing: int = direction
	if pointing != 1 and pointing != -1:
		return null
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis as JoyAxis
	motion.axis_value = float(pointing)
	return motion


## Returns the optional modifier mask of [param data]: 0 when absent, [constant _INVALID]
## when it is not an int or has bits outside [constant MODIFIER_BITS].
static func _read_modifiers(data: Dictionary) -> int:
	if not data.has("modifiers"):
		return 0
	var mask: int = _read_int(data, "modifiers", 0, MODIFIER_BITS)
	if mask == _INVALID or mask & ~MODIFIER_BITS != 0:
		return _INVALID
	return mask


## Sets the modifier flags of [param event] from [param mask].
static func _apply_modifiers(event: InputEventWithModifiers, mask: int) -> void:
	event.command_or_control_autoremap = mask & KEY_MASK_CMD_OR_CTRL != 0
	event.shift_pressed = mask & KEY_MASK_SHIFT != 0
	event.alt_pressed = mask & KEY_MASK_ALT != 0
	if not event.command_or_control_autoremap:
		event.ctrl_pressed = mask & KEY_MASK_CTRL != 0
		event.meta_pressed = mask & KEY_MASK_META != 0


## Returns the int field [param field] of [param data] if it lies in
## [[param minimum], [param maximum]], else [constant _INVALID].
static func _read_int(data: Dictionary, field: String, minimum: int, maximum: int) -> int:
	var value: Variant = data.get(field)
	if typeof(value) != TYPE_INT:
		return _INVALID
	var number: int = value
	if number < minimum or number > maximum:
		return _INVALID
	return number
