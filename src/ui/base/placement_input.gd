class_name PlacementInput
extends RefCounted
## Input of the [PlacementGhost] while a room is being placed. Keys and buttons: Q, E
## (view_previous, view_next) or the shoulders turn it (the shoulders switch tabs otherwise); Enter
## or (A) builds at once; Esc or (B) clears a corridor run, then leaves placing. Mouse: the ghost
## follows the pointer; a left click builds a room; for a corridor, a press off the run starts a
## new run, a drag paints it and the release builds it, and a click on a run builds it. A right
## click (no drag) leaves placing. Wheel and right drag reach the plan.
## Bible: docs/content/m2-base.md section 6 (Gamepad)

const _ROTATE_ACTIONS: Array[StringName] = [&"view_next", &"view_previous"]
## Pixels a right press may move and still count as a click, not a pan.
const _CLICK_SLOP: float = 6.0

## Where the right button went down, or [constant Vector2.INF] when it is up.
static var _right_from: Vector2 = Vector2.INF


## Handles a key, button or action [param event] for [param ghost]; true when used.
static func handle_key(ghost: PlacementGhost, event: InputEvent) -> bool:
	if _is_rotate(event):
		ghost.rotate_ghost()
		return true
	if event.is_action_pressed(&"ui_accept", true, true):
		if not event.is_echo():
			ghost.confirm()
		return true
	if event.is_action_released(&"ui_accept", true):
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
			ghost.follow(cell)
		return false
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null:
		return false
	if button.button_index == MOUSE_BUTTON_RIGHT:
		_right_click(ghost, button)
		return false
	if button.button_index != MOUSE_BUTTON_LEFT:
		return false
	var at: Vector2i = plan.cell_at(button.position)
	if not button.pressed:
		if ghost.is_painting():
			ghost.set_painting(false, at)
			ghost.confirm()
		return true
	plan.grab_focus()
	if ghost.is_corridor() and not (at in ghost.run and ghost.run.size() > 1):
		ghost.set_painting(true, at)
		return true
	if not ghost.is_corridor():
		ghost.follow(at)
	ghost.confirm()
	return true


## A right press and release in about the same place leaves placing; a drag only pans.
static func _right_click(ghost: PlacementGhost, button: InputEventMouseButton) -> void:
	if button.pressed:
		_right_from = button.position
		return
	var moved: float = _right_from.distance_to(button.position)
	_right_from = Vector2.INF
	if moved <= _CLICK_SLOP:
		ghost.stop(true)


static func _is_rotate(event: InputEvent) -> bool:
	for action: StringName in _ROTATE_ACTIONS:
		if InputMap.has_action(action) and InputActions.is_new_press(event, action):
			return true
	return false
