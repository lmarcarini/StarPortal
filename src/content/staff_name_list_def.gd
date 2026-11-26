class_name StaffNameListDef
extends DefBase
## The given names and surnames staff names are drawn from (StaffNames.draw()). Every name reads
## the same in English and Brazilian Portuguese, so names are never translated. Read only at
## runtime; the game has one, with id [constant NAMES_ID].
## Bible: docs/content/m26-staff-and-money.md section 1

## The id of the game's name list.
const NAMES_ID: StringName = &"staff_names"

## Given names only women draw.
@export var female_names: Array[String] = []
## Given names only men draw.
@export var male_names: Array[String] = []
## Given names either sex draws (M8-01).
@export var unisex_names: Array[String] = []
## Surnames to draw from.
@export var surnames: Array[String] = []


## The given names a person of [param sex] ("female" or "male") draws from: their own list,
## then the unisex names.
func given_names_for(sex: String) -> Array[String]:
	var names: Array[String] = (
		female_names.duplicate() if sex == "female" else male_names.duplicate()
	)
	names.append_array(unisex_names)
	return names


## Errors: no given name for a sex, no surname, an empty name, or a given name in two lists.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if given_names_for("female").is_empty() or given_names_for("male").is_empty():
		errors.append("needs at least one given name for each sex")
	if surnames.is_empty():
		errors.append("needs at least one surname")
	var all: Array[String] = female_names + male_names + unisex_names
	if "" in all or "" in surnames:
		errors.append("has an empty name")
	var seen: Dictionary[String, bool] = {}
	for name: String in all:
		if seen.has(name):
			errors.append("given name '%s' is in more than one list" % name)
		seen[name] = true
	return errors
