class_name SquadState
extends RefCounted
## One squad (M4c): the soldiers of a Security Post. Its order, the cell it heads for and
## where it is now. Saved shape: {"post_room", "order", "target", "pos"}.
## Bible: docs/content/m4c-incursions.md sections 2, 3 and 9

## HOLD: stays; MOVE: walks to target then holds; FALL_BACK: walks to its post.
enum Order { HOLD, MOVE, FALL_BACK }

## Saved names of the orders, indexed by Order value.
const ORDER_NAMES: Array[String] = ["hold", "move", "fall_back"]
## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["post_room", "order", "target", "pos"]

## Room id of its Security Post.
var post_room: StringName = &""
## Current order.
var order: Order = Order.HOLD
## Where a MOVE goes.
var target: Vector3i = Vector3i.ZERO
## Where it is.
var pos: Vector3i = Vector3i.ZERO


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"post_room": String(post_room),
		"order": StateNames.write(ORDER_NAMES, order),
		"target": UnitState.write_pos(target),
		"pos": UnitState.write_pos(pos),
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> SquadState:
	var squad := SquadState.new()
	squad.post_room = SaveFields.read_id(data.get("post_room"))
	squad.order = StateNames.read(ORDER_NAMES, data.get("order")) as Order
	squad.target = UnitState.read_pos(data.get("target"))
	squad.pos = UnitState.read_pos(data.get("pos"))
	return squad


## Errors of saved [param data].
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not SaveFields.is_id(data["post_room"]):
		errors.append("'post_room' is not a non-empty string")
	if not StateNames.is_name(ORDER_NAMES, data["order"]):
		errors.append("'order' is not one of %s" % str(ORDER_NAMES))
	for key: String in ["target", "pos"]:
		if not UnitState.is_pos(data[key]):
			errors.append("'%s' is not [x, y, level]" % key)
	return errors
