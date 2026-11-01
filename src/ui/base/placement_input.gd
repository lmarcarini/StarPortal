class_name PlacementInput
extends RefCounted
## Input of the [PlacementGhost] while a room is being placed. Keys and buttons: Q, E
## (view_previous, view_next) or the shoulders turn it (the shoulders switch tabs otherwise); Enter
## or (A) held builds; Esc or (B) clears a corridor run, then leaves placing. Mouse: the ghost
## follows the pointer; the left button held builds a room; for a corridor, a press off the run
## starts a new run and a drag paints it, a press on the run held builds it. Wheel and right drag
## reach the plan.
## Bible: docs/content/m2-base.md section 6 (Gamepad)

const _ROTATE_ACTIONS: Array[StringName] = [&"view_next", &"view_previous"]


## Handles a key, button or action [param event] for [param ghost]; true when used.
static func handle_key(ghost: PlacementGhost, event: InputEvent) -> bool:
	if _is_rotate(event):
		ghost.rotate_ghost()
		return true
	if event.is_action_pressed(&"ui_accept", true, true):
		if not event.is_echo():
			ghost.begin_hold()
		return true
	if event.is_action_released(&"ui_accept", true):
		ghost.cancel_hold()
		return true
	if event.is_action_pressed(&"ui_cancel", false, true):
		if ghost.is_corridor() and ghost.run.size() > 1:
			ghost.run = [ghost.origin]
			ghost.recheck()
		else:
			ghost.stop(true)
		return true
	return false


## Handles a mouse [param event] over [param plan] for [param ghost]; true when used.
static func handle_mouse(ghost: PlacementGhost, plan: BasePlan, event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		if plan.is_dragging():
			return false
		var cell: Vector2i = plan.cell_at((event as InputEventMouseMotion).position)
		if ghost.is_corridor() and not ghost.is_painting() and ghost.run.size() > 1:
			return false
		if cell != ghost.origin:
			ghost.cancel_hold()
			ghost.follow(cell)
		return false
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT:
		return false
	var at: Vector2i = plan.cell_at(button.position)
	if not button.pressed:
		ghost.set_painting(false, at)
		ghost.cancel_hold()
		return true
	plan.grab_focus()
	if ghost.is_corridor() and not (at in ghost.run and ghost.run.size() > 1):
		ghost.set_painting(true, at)
		return true
	if not ghost.is_corridor():
		ghost.follow(at)
	ghost.begin_hold()
	return true


static func _is_rotate(event: InputEvent) -> bool:
	for action: StringName in _ROTATE_ACTIONS:
		if InputMap.has_action(action) and InputActions.is_new_press(event, action):
			return true
	return false
