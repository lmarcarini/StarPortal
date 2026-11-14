class_name UnitDef
extends DefBase
## A kind of intruder (M4c): its health, its attack per tick and how many ticks it takes to
## breach a sealed blast door. Soldiers are people, not UnitDefs.
## Bible: docs/content/m4c-incursions.md sections 2 and 9

## Name (translation key).
@export var name_key: StringName = &""
## Health; down at 0.
@export var health: int = 8
## Attack per tick, before the seeded roll.
@export var attack: float = 2.0
## Ticks to breach a sealed blast door.
@export var door_breach_ticks: int = 15


## No name, health below 1, a negative attack or breach ticks below 1.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if name_key.is_empty():
		errors.append("needs name_key")
	if health < 1 or attack < 0.0 or door_breach_ticks < 1:
		errors.append("needs health >= 1, attack >= 0 and door_breach_ticks >= 1")
	return errors
