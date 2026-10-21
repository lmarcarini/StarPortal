extends Node
## Input service, registered as the [code]InputService[/code] autoload (after
## [code]Settings[/code]). Registers every action of [InputActions] in [InputMap] at start-up,
## holds [constant BINDINGS_PER_DEVICE] binding slots per action and device kind, lets the
## player rebind them, and stores them in [code]Settings[/code] section [code]input[/code]
## (one key per action; an empty Dictionary there means the built-in defaults).
## It also tracks which device kind the player last used, for prompts and focus.
## Gameplay and UI read actions only, never raw keys.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## game-design.md#difficulty-and-accessibility

## Emitted once each time the player switches between keyboard/mouse and gamepad.
signal input_device_changed(kind: DeviceKind)
## Emitted after the bindings of [param action] change.
signal bindings_changed(action: StringName)

## The two families of bindings every action has.
enum DeviceKind { KEYBOARD_MOUSE, GAMEPAD }

## Binding slots per action and device kind.
const BINDINGS_PER_DEVICE: int = 2
## Settings section that stores the bindings.
const SETTINGS_SECTION: StringName = &"input"
## Joypad axis movement below this strength does not count as using the gamepad.
const MOTION_THRESHOLD: float = 0.2

const SettingsScript := preload("res://src/services/settings.gd")

## The device kind the player used last.
var current_device: DeviceKind = DeviceKind.KEYBOARD_MOUSE
## Where bindings are stored. Null means the [code]Settings[/code] autoload; tests set
## their own instance before the node enters the tree.
var settings: SettingsScript = null

## Current bindings as {action: [keyboard slots, gamepad slots]}, indexed by [enum DeviceKind];
## each slots entry is an Array[InputEvent] of BINDINGS_PER_DEVICE, null for an empty slot.
var _bindings: Dictionary[StringName, Array] = {}


func _ready() -> void:
	if settings == null:
		settings = Settings
	for action: StringName in InputActions.ACTIONS:
		_bindings[action] = _stored_or_default_layout(action)
		_apply_to_input_map(action)


func _input(event: InputEvent) -> void:
	if not _is_meaningful(event):
		return
	var kind: DeviceKind = _device_of(event)
	if kind == current_device:
		return
	current_device = kind
	input_device_changed.emit(kind)


## Returns copies of the [constant BINDINGS_PER_DEVICE] bindings of [param action] for
## [param kind], with null for an empty slot. An unknown action asserts in debug and returns
## empty slots.
func get_bindings(action: StringName, kind: DeviceKind) -> Array[InputEvent]:
	var copies: Array[InputEvent] = []
	copies.resize(BINDINGS_PER_DEVICE)
	if not _bindings.has(action):
		assert(false, "InputService: unknown action %s" % action)
		return copies
	var slots: Array[InputEvent] = _bindings[action][kind]
	for slot: int in BINDINGS_PER_DEVICE:
		if slots[slot] != null:
			copies[slot] = slots[slot].duplicate() as InputEvent
	return copies


## Binds [param event] to [param slot] of [param action] for [param kind], applies it to
## [InputMap] and stores it. On success the value is the bound event (matching every device).
## Fails with [code]&"unknown_action"[/code], [code]&"invalid_slot"[/code],
## [code]&"invalid_event"[/code] (not bindable, see [InputEventCodec]),
## [code]&"wrong_device"[/code] (the event belongs to the other device kind) or
## [code]&"binding_conflict"[/code] (another binding of [param kind] already uses the event;
## [member Result.detail] is that action's name). Fails with [code]&"save_failed"[/code] if
## the settings file cannot be written; the binding still applies for this session.
func rebind(action: StringName, kind: DeviceKind, slot: int, event: InputEvent) -> Result:
	var refused: Result = _check_rebind(action, kind, slot, event)
	if refused != null:
		return refused
	var encoded: Dictionary = InputEventCodec.encode(event)
	var slots: Array[InputEvent] = _bindings[action][kind]
	if slots[slot] == null or InputEventCodec.encode(slots[slot]) != encoded:
		var conflict: StringName = find_conflict(event, kind)
		if conflict != &"":
			return Result.fail(&"binding_conflict", String(conflict))
		slots[slot] = InputEventCodec.decode(encoded)
		var saved: Result = _commit(action)
		if not saved.is_ok:
			return saved
	return Result.ok(slots[slot].duplicate())


## Empties [param slot] of [param action] for [param kind], then applies and stores the
## change. An unknown action or slot asserts in debug and does nothing.
func clear_binding(action: StringName, kind: DeviceKind, slot: int) -> void:
	if not _bindings.has(action) or slot < 0 or slot >= BINDINGS_PER_DEVICE:
		assert(false, "InputService: no slot %d for action %s" % [slot, action])
		return
	var slots: Array[InputEvent] = _bindings[action][kind]
	if slots[slot] == null:
		return
	slots[slot] = null
	_commit(action)


## Restores every action's built-in default bindings, applies them, clears the stored
## bindings and emits [signal bindings_changed] for each action that changed.
func reset_to_defaults() -> void:
	var changed: Array[StringName] = []
	for action: StringName in InputActions.ACTIONS:
		var defaults: Array = _default_layout(action)
		if _encode_layout(defaults) != _encode_layout(_bindings[action]):
			changed.append(action)
		_bindings[action] = defaults
		_apply_to_input_map(action)
	settings.reset_section(SETTINGS_SECTION)
	for action: StringName in changed:
		bindings_changed.emit(action)


## Returns the first action with a [param kind] binding equal to [param event], or
## [code]&""[/code] when there is none (or the event cannot be bound).
func find_conflict(event: InputEvent, kind: DeviceKind) -> StringName:
	var encoded: Dictionary = InputEventCodec.encode(event)
	if encoded.is_empty():
		return &""
	for action: StringName in InputActions.ACTIONS:
		var slots: Array[InputEvent] = _bindings[action][kind]
		for bound: InputEvent in slots:
			if bound != null and InputEventCodec.encode(bound) == encoded:
				return action
	return &""


## Returns why [param event] cannot go into [param slot] of [param action] for [param kind]
## (conflicts aside), or null when it can.
func _check_rebind(action: StringName, kind: DeviceKind, slot: int, event: InputEvent) -> Result:
	if not _bindings.has(action):
		return Result.fail(&"unknown_action", String(action))
	if slot < 0 or slot >= BINDINGS_PER_DEVICE:
		return Result.fail(&"invalid_slot", "%s slot %d" % [action, slot])
	if InputEventCodec.encode(event).is_empty():
		return Result.fail(&"invalid_event", "%s cannot be bound" % event)
	if _device_of(event) != kind:
		var expected: String = DeviceKind.keys()[kind]
		return Result.fail(&"wrong_device", "%s is not a %s event" % [event, expected])
	return null


## Applies the bindings of [param action] to [InputMap], stores them and emits
## [signal bindings_changed]. Returns the result of storing.
func _commit(action: StringName) -> Result:
	_apply_to_input_map(action)
	var encoded: Dictionary = _encode_layout(_bindings[action])
	if encoded == _encode_layout(_default_layout(action)):
		encoded = {}
	var saved: Result = settings.set_value(SETTINGS_SECTION, action, encoded)
	bindings_changed.emit(action)
	return saved


## Registers [param action] in [InputMap] if needed and replaces its events with the
## current bindings.
func _apply_to_input_map(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for slots: Array[InputEvent] in _bindings[action]:
		for bound: InputEvent in slots:
			if bound != null:
				InputMap.action_add_event(action, bound)


## Returns the stored layout of [param action], or its defaults when nothing is stored or
## the stored data is invalid (with a warning).
func _stored_or_default_layout(action: StringName) -> Array:
	var stored: Dictionary = settings.get_value(SETTINGS_SECTION, action)
	if stored.is_empty():
		return _default_layout(action)
	var layout: Array = _decode_layout(stored)
	if layout.is_empty():
		push_warning("InputService: stored bindings of %s are invalid; using defaults." % action)
		return _default_layout(action)
	return layout


## Returns the built-in default layout of [param action].
static func _default_layout(action: StringName) -> Array:
	var defaults: Dictionary = InputActions.DEFAULTS[action]
	var layout: Array = _decode_layout(defaults)
	assert(not layout.is_empty(), "InputService: invalid defaults for %s" % action)
	return layout


## Decodes {KEYBOARD: [...], GAMEPAD: [...]} into [keyboard slots, gamepad slots], or returns
## an empty Array if any part is invalid.
static func _decode_layout(data: Dictionary) -> Array:
	var layout: Array = []
	for kind: DeviceKind in [DeviceKind.KEYBOARD_MOUSE, DeviceKind.GAMEPAD]:
		var slots: Array[InputEvent] = _decode_slots(data.get(_layout_key(kind)), kind)
		if slots.is_empty():
			return []
		layout.append(slots)
	return layout


## Decodes an Array of encoded events (an empty Dictionary for an empty slot) into
## [constant BINDINGS_PER_DEVICE] slots, or returns an empty Array if [param raw] is not
## such an Array or holds an invalid event or one of the other device kind.
static func _decode_slots(raw: Variant, kind: DeviceKind) -> Array[InputEvent]:
	var slots: Array[InputEvent] = []
	if typeof(raw) != TYPE_ARRAY:
		return slots
	var entries: Array = raw
	if entries.size() > BINDINGS_PER_DEVICE:
		return slots
	for entry: Variant in entries:
		var event: InputEvent = _decode_slot(entry)
		if event == null and not _is_empty_slot(entry):
			slots.clear()
			return slots
		if event != null and _device_of(event) != kind:
			slots.clear()
			return slots
		slots.append(event)
	slots.resize(BINDINGS_PER_DEVICE)
	return slots


## Decodes one stored slot; null for an empty or invalid one.
static func _decode_slot(entry: Variant) -> InputEvent:
	if typeof(entry) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = entry
	return InputEventCodec.decode(data)


## True if [param entry] is the stored form of an empty slot: an empty Dictionary.
static func _is_empty_slot(entry: Variant) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = entry
	return data.is_empty()


## Encodes [param layout] as {KEYBOARD: [...], GAMEPAD: [...]}, an empty Dictionary per
## empty slot.
static func _encode_layout(layout: Array) -> Dictionary:
	var data: Dictionary = {}
	for kind: DeviceKind in [DeviceKind.KEYBOARD_MOUSE, DeviceKind.GAMEPAD]:
		var encoded: Array[Dictionary] = []
		var slots: Array[InputEvent] = layout[kind]
		for bound: InputEvent in slots:
			encoded.append({} if bound == null else InputEventCodec.encode(bound))
		data[_layout_key(kind)] = encoded
	return data


## Returns the key of [param kind]'s bindings in stored and default layouts.
static func _layout_key(kind: DeviceKind) -> StringName:
	return InputActions.GAMEPAD if kind == DeviceKind.GAMEPAD else InputActions.KEYBOARD


## Returns the device kind [param event] comes from.
static func _device_of(event: InputEvent) -> DeviceKind:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return DeviceKind.GAMEPAD
	return DeviceKind.KEYBOARD_MOUSE


## True if [param event] shows the player is using its device: a press (not an echo or a
## release), mouse movement, or a joypad axis pushed to at least [constant MOTION_THRESHOLD].
static func _is_meaningful(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.is_pressed() and not event.is_echo()
	if event is InputEventMouseButton or event is InputEventJoypadButton:
		return event.is_pressed()
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).relative != Vector2.ZERO
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= MOTION_THRESHOLD
	return false
