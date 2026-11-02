class_name RoleDef
extends DefBase
## Definition of a staff role (docs/content/m26-staff-and-money.md section 1): scientist,
## engineer or analyst in M2.6. A person's role is fixed for life; a room's staff slots take
## one role (RoomDef.staff_role). Read only at runtime.
## Bible: docs/content/m26-staff-and-money.md sections 1 and 3, technical-architecture.md#data-model

## Translation key of the role's name ("Scientist").
@export var name_key: StringName = &""
## Translation key of a count of several people of the role ("{count} scientists").
@export var count_key: StringName = &""
## Translation key of one person of the role ("1 scientist").
@export var count_one_key: StringName = &""
## Titles a drawn name may carry, e.g. ["Dr"]; an empty title means none. Not translated: the
## names are pt_BR-neutral and so are the titles.
@export var titles: Array[String] = [""]


## Errors: a missing name or count key, or no title to draw from.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	for key: StringName in [name_key, count_key, count_one_key]:
		if key.is_empty():
			errors.append("has an empty translation key")
	if titles.is_empty():
		errors.append('has no titles (use [""] for none)')
	return errors
