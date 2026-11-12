class_name WorldStatusAtLeastCondition
extends ConditionDef
## True when the world's progress status has reached status.
## Bible: docs/content/m4-core-systems.md section 1

## World progress statuses, in order; the values match WorldsState.WorldStatus.
enum WorldStatus { UNKNOWN = 0, LOCKED = 1, PROBED = 2, SURVEYED = 3, CONTACTED = 4 }

## World id.
@export var world: StringName = &""
## Minimum progress status.
@export var status: WorldStatus = WorldStatus.LOCKED


## Returns &"COND_WORLD_STATUS_AT_LEAST".
func reason_key() -> StringName:
	return &"COND_WORLD_STATUS_AT_LEAST"


## Returns the world id.
func get_references() -> Array[StringName]:
	return [world]
