class_name DefBase
extends Resource
## Base class of every content definition: a read-only Resource saved as `.tres` under `data/`,
## identified by a stable string id. Definitions point at each other by id, never by path.
## A definition is shared by everything that loads it, so code never writes to one at runtime.
## Bible: technical-architecture.md#data-model

## Stable, unique id of this definition, e.g. &"room_lab". Never empty.
@export var id: StringName


## Returns the ids of the other definitions this one points to; empty by default.
## The Registry reports every returned id that no loaded definition has.
func get_references() -> Array[StringName]:
	return []
