class_name ScenarioDef
extends DefBase
## A shipped starting state (M4.6-03): a save file under data/scenarios that the main menu can
## start from, paused, with a title and a one-line description. Loading goes through the same
## checks and migrations as any save; saving afterwards writes a normal user slot.
## Bible: docs/scenarios.md

## Menu title and description (translation keys).
@export var title_key: StringName = &""
@export var description_key: StringName = &""
## The save file, res://data/scenarios/<id>.json.
@export var save_path: String = ""
## Place in the menu, lowest first.
@export var order: int = 0


## A missing or unreadable save file, or missing keys.
func get_content_errors(_defs: Dictionary[StringName, DefBase]) -> Array[String]:
	var errors: Array[String] = []
	if title_key.is_empty() or description_key.is_empty():
		errors.append("scenario %s: needs title_key and description_key" % id)
	if not FileAccess.file_exists(save_path):
		errors.append("scenario %s: save file %s not found" % [id, save_path])
		return errors
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary:
		errors.append("scenario %s: %s is not a save" % [id, save_path])
		return errors
	var data: Dictionary = parsed
	if not SaveMigrator.migrate(data).is_ok:
		errors.append("scenario %s: %s does not migrate" % [id, save_path])
	return errors
