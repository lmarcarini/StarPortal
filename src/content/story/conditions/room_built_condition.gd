class_name RoomBuiltCondition
extends ConditionDef
## True when the base has a built room of [member room] (not being demolished).
## Bible: docs/content/research-and-progression.md section 10 ("Shows when")

## RoomDef id.
@export var room: StringName = &""


## Returns &"COND_ROOM_BUILT".
func reason_key() -> StringName:
	return &"COND_ROOM_BUILT"


## Returns the room def id.
func get_references() -> Array[StringName]:
	return [room]
