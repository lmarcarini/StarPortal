class_name TokenDrag
extends RefCounted
## A mouse drag of a staff token: pressed on a token, it becomes a drag once the pointer moves
## a few pixels; until then the press is a plain click. Tracks where the ghost token is.
## Bible: docs/content/interface-pass.md section 5 (Allocation by placing)

## Pixels the pointer must move before a press becomes a drag.
const THRESHOLD: float = 6.0

## The person pressed or dragged, or &"".
var person_id: StringName = &""
## Where the pointer is, in the plan control's coordinates.
var at: Vector2 = Vector2.ZERO

var _from: Vector2 = Vector2.ZERO
var _dragging: bool = false


## A press on [param person]'s token at [param point].
func press(person: StringName, point: Vector2) -> void:
	person_id = person
	_from = point
	at = point
	_dragging = false


## The pointer moved to [param point]; returns true when this starts the drag.
func move(point: Vector2) -> bool:
	if person_id == &"":
		return false
	at = point
	if not _dragging and point.distance_to(_from) >= THRESHOLD:
		_dragging = true
		return true
	return false


## True once the press has become a drag.
func is_dragging() -> bool:
	return _dragging


## Ends the press or drag.
func release() -> void:
	person_id = &""
	_dragging = false
