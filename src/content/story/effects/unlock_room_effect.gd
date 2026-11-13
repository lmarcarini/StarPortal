class_name UnlockRoomEffect
extends EffectDef
## Research unlock: the room def id that may be built. Applied through UnlockRules.
## Bible: docs/content/m4-core-systems.md section 7 (1), docs/content/m25-lean-start.md section 3

## UnlockRules effect id.
const UNLOCK: StringName = &"unlock_room"

## The room def id that may be built.
@export var room: StringName = &""


## [UnlockRules effect id, value].
func unlock_pair() -> Array:
	return [UNLOCK, room]


## The room.
func get_references() -> Array[StringName]:
	return [room]
