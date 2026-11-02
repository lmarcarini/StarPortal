class_name StaffNameListDef
extends DefBase
## The given names and surnames staff names are drawn from (StaffNames.draw()). Every name reads
## the same in English and Brazilian Portuguese, so names are never translated. Read only at
## runtime; the game has one, with id [constant NAMES_ID].
## Bible: docs/content/m26-staff-and-money.md section 1

## The id of the game's name list.
const NAMES_ID: StringName = &"staff_names"

## Given names to draw from.
@export var given_names: Array[String] = []
## Surnames to draw from.
@export var surnames: Array[String] = []


## Errors: an empty list or an empty name.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if given_names.is_empty() or surnames.is_empty():
		errors.append("needs at least one given name and one surname")
	if "" in given_names or "" in surnames:
		errors.append("has an empty name")
	return errors
