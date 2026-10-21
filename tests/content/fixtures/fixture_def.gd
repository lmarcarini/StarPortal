extends DefBase
## Test-only definition that points at other definitions by id. Used by the Registry fixtures.

## Ids of the definitions this one points to.
@export var references: Array[StringName] = []


## Returns [member references].
func get_references() -> Array[StringName]:
	return references
