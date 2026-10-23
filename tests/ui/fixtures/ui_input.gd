extends RefCounted
## Test helpers that drive controls through real GUI input: mouse clicks (left and right) and
## drags pushed into the control's viewport (in its own coordinates, since the headless window's
## screen transform is not the identity), keys on the keyboard, and gamepad buttons. Each waits
## two process frames so the GUI and any deferred work settle.
## Bible: game-design.md#difficulty-and-accessibility,
## technical-architecture.md#input-accessibility-and-localisation

## Steps a drag takes between its two points.
const DRAG_STEPS: int = 6


## Clicks the left mouse button at the centre of [param control].
static func click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	_mouse_motion(control, at, Vector2.ZERO, 0)
	for pressed: bool in [true, false]:
		_mouse_button(control, at, pressed)
	await settle(control)


## Clicks the right mouse button at the centre of [param control].
static func right_click(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	_mouse_motion(control, at, Vector2.ZERO, 0)
	for pressed: bool in [true, false]:
		_mouse_button(control, at, pressed, MOUSE_BUTTON_RIGHT)
	await settle(control)


## Presses on [param from], moves to [param to] with the left button held, and releases there.
static func drag(from: Control, to: Control) -> void:
	var start: Vector2 = from.get_global_rect().get_center()
	var end: Vector2 = to.get_global_rect().get_center()
	_mouse_motion(from, start, Vector2.ZERO, 0)
	_mouse_button(from, start, true)
	await settle(from)
	var previous: Vector2 = start
	for step: int in range(1, DRAG_STEPS + 1):
		var at: Vector2 = start.lerp(end, float(step) / DRAG_STEPS)
		_mouse_motion(from, at, at - previous, MOUSE_BUTTON_MASK_LEFT)
		previous = at
		await settle(from)
	_mouse_button(from, end, false)
	await settle(from)


## Focuses [param control] and presses and releases [param keycode].
static func key(control: Control, keycode: Key) -> void:
	control.grab_focus()
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await settle(control)


## Focuses [param control] and presses and releases gamepad [param button].
static func pad(control: Control, button: JoyButton) -> void:
	control.grab_focus()
	for pressed: bool in [true, false]:
		var event: InputEventJoypadButton = InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
	await settle(control)


## Waits two process frames. [param _node] may have left the tree by then (a row the input
## removed), so the main loop is used.
static func settle(_node: Node) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame


static func _mouse_button(
	control: Control, at: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT
) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (1 << (button - 1)) if pressed else 0
	event.position = at
	event.global_position = at
	control.get_viewport().push_input(event, true)


static func _mouse_motion(control: Control, at: Vector2, relative: Vector2, mask: int) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = mask
	event.relative = relative
	event.position = at
	event.global_position = at
	control.get_viewport().push_input(event, true)
