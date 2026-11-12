class_name RequestIsCondition
extends ConditionDef
## True when the newest instance of the request is in state.
## Bible: docs/content/m4-core-systems.md section 1

## Request states; the values match RequestState in the simulation (M4-03), defined here so
## the content layer does not depend on the simulation.
enum RequestState { OFFERED = 0, ACTIVE = 1, FULFILLED = 2, FAILED = 3, DECLINED = 4, LAPSED = 5 }

## Request id.
@export var request: StringName = &""
## Expected state.
@export var state: RequestState = RequestState.OFFERED


## Returns &"COND_REQUEST_IS".
func reason_key() -> StringName:
	return &"COND_REQUEST_IS"


## Returns the request id.
func get_references() -> Array[StringName]:
	return [request]
