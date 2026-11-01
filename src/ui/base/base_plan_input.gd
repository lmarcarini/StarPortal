class_name BasePlanInput
extends RefCounted
## Mouse, keyboard and gamepad handling of the [BasePlan]: wheel and right stick zoom, a
## right or middle drag and the left stick pan, a left click or [code]ui_accept[/code] selects,
## the [code]ui_*[/code] directions (arrows, D-pad) move the cell cursor.
## Bible: docs/content/m2-base.md section 6 (Gamepad)

const _DEADZONE: float = 0.3
const _PAN_SPEED: float = 600.0
const _ZOOM_SPEED: float = 1.5
const _DIRECTIONS: Dictionary = {
	&"ui_left": Vector2i.LEFT,
	&"ui_right": Vector2i.RIGHT,
	&"ui_up": Vector2i.UP,
	&"ui_down": Vector2i.DOWN,
}


## Handles [param event] for [param plan]; returns true when it was used.
static func handle(plan: BasePlan, event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _mouse_button(plan, event as InputEventMouseButton)
	if event is InputEventMouseMotion and plan.is_dragging():
		plan.view.pan((event as InputEventMouseMotion).relative)
		plan.queue_redraw()
		return true
	if event.is_action_pressed(&"ui_accept"):
		plan.select_at_cursor()
		return true
	for action: StringName in _DIRECTIONS:
		if event.is_action_pressed(action, true):
			var step: Vector2i = _DIRECTIONS[action]
			plan.move_cursor(step)
			return true
	return false


## Pans with the left stick and zooms with the right stick of any pad, scaled by
## [param delta] seconds. Only while [param plan] has focus.
static func apply_sticks(plan: BasePlan, delta: float) -> void:
	if not plan.has_focus() or Input.get_connected_joypads().is_empty():
		return
	var device: int = Input.get_connected_joypads()[0]
	var pan := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
	)
	var zoom: float = -Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	if pan.length() > _DEADZONE:
		plan.view.pan(-pan * _PAN_SPEED * delta)
		plan.queue_redraw()
	if absf(zoom) > _DEADZONE:
		plan.view.zoom_centred(pow(_ZOOM_SPEED, zoom * delta * 4.0))
		plan.queue_redraw()


static func _mouse_button(plan: BasePlan, event: InputEventMouseButton) -> bool:
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				var up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
				plan.view.zoom_by(ZoomPan.STEP if up else 1.0 / ZoomPan.STEP, event.position)
				plan.queue_redraw()
			return true
		MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			plan.set_dragging(event.pressed)
			return true
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				plan.grab_focus()
				plan.cursor = plan.cell_at(event.position)
				plan.move_cursor(Vector2i.ZERO)
				plan.select_at_cursor()
			return true
	return false
