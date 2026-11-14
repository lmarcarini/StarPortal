extends SceneTree
## Turns a user save slot into a shipped scenario (M4.6-03):
##   godot --headless -s tools/make_scenario.gd -- <slot> <scenario_id> "<title>" ["<description>"]
## Copies user://saves/<slot>.json to data/scenarios/<scenario_id>.json, writes
## data/scenarios/<scenario_id>.tres (a ScenarioDef placed after the others) and adds the title
## and description to localization/core.csv (English and pt_BR alike; translate later).
## Bible: docs/scenarios.md

const SCENARIOS_DIR: String = "res://data/scenarios"
const STRINGS: String = "res://localization/core.csv"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3:
		printerr('usage: -- <slot> <scenario_id> "<title>" ["<description>"]')
		quit(1)
		return
	var description: String = args[3] if args.size() > 3 else args[2]
	var error: String = make(StringName(args[0]), StringName(args[1]), args[2], description)
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	print("scenario %s written" % args[1])
	quit(0)


## Writes the scenario; returns "" or the problem.
static func make(slot: StringName, id: StringName, title: String, description: String) -> String:
	var source: String = "user://saves/%s.json" % slot
	if not FileAccess.file_exists(source):
		return "no save slot %s" % slot
	var save_path: String = "%s/%s.json" % [SCENARIOS_DIR, id]
	var copy_error: Error = DirAccess.copy_absolute(source, save_path)
	if copy_error != OK:
		return "cannot copy %s: %s" % [source, error_string(copy_error)]
	var key: String = "SCENARIO_%s" % String(id).trim_prefix("scenario_").to_upper()
	var def := ScenarioDef.new()
	def.id = id
	def.title_key = StringName(key + "_TITLE")
	def.description_key = StringName(key + "_LINE")
	def.save_path = save_path
	def.order = DirAccess.get_files_at(SCENARIOS_DIR).size()
	var saved: Error = ResourceSaver.save(def, "%s/%s.tres" % [SCENARIOS_DIR, id])
	if saved != OK:
		return "cannot write the def: %s" % error_string(saved)
	var file := FileAccess.open(STRINGS, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_csv_line(PackedStringArray([key + "_TITLE", title, title]))
	file.store_csv_line(PackedStringArray([key + "_LINE", description, description]))
	file.close()
	return ""
