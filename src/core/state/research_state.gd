class_name ResearchState
extends RefCounted
## Saved state of research (docs/content/m25-lean-start.md section 3): the project running,
## if any, how far it has got, and the projects done. Only StartResearchCommand,
## CancelResearchCommand and ResearchSystem change it.
## Saved shape: {"active": project id or "", "ticks_done": whole number, "done": [project id...]}.
## Bible: docs/content/m25-lean-start.md section 3, technical-architecture.md#data-model

## Saved keys, in to_dict() order.
const _KEYS: Array[String] = ["active", "ticks_done", "done"]

## The project running (paid for), or &"" when none.
var active: StringName = &""
## Ticks of progress on the active project; kept while the lab is off. 0 when none runs.
var ticks_done: int = 0
## Projects finished, in the order they finished; no duplicates.
var done: Array[StringName] = []


## True when a project is running.
func is_running() -> bool:
	return not active.is_empty()


## True when [param project_id] is finished.
func is_done(project_id: StringName) -> bool:
	return project_id in done


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var done_data: Array = []
	for project_id: StringName in done:
		done_data.append(String(project_id))
	return {"active": String(active), "ticks_done": ticks_done, "done": done_data}


## Builds a ResearchState from saved [param data] (whole floats become ints). Unreadable
## entries are skipped. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> ResearchState:
	var research := ResearchState.new()
	var active_data: Variant = data.get("active")
	if active_data is String:
		research.active = StringName(str(active_data))
	research.ticks_done = RoomState.read_count(data.get("ticks_done"))
	var done_data: Variant = data.get("done")
	if done_data is Array:
		var entries: Array = done_data
		for entry: Variant in entries:
			var project_id := StringName(str(entry))
			if entry is String and not project_id.is_empty() and not project_id in research.done:
				research.done.append(project_id)
	return research


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present; "active" a string, not one of "done"; "ticks_done" a whole number of at least 0,
## and 0 when "active" is empty; "done" an array of distinct non-empty strings.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _KEYS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	if not errors.is_empty():
		return errors
	if not data["active"] is String:
		errors.append("'active' is not a string")
	if not RoomState.is_count(data["ticks_done"]):
		errors.append("'ticks_done' is not a whole number of at least 0")
	elif data["active"] is String and str(data["active"]).is_empty() and data["ticks_done"] != 0:
		errors.append("'ticks_done' is not 0 with no active project")
	errors.append_array(_done_errors(data["done"], data["active"]))
	return errors


static func _done_errors(value: Variant, active_value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'done' is not an array")
		return errors
	var entries: Array = value
	var seen: Dictionary[String, bool] = {}
	for index: int in entries.size():
		var entry: Variant = entries[index]
		if not (entry is String and not str(entry).is_empty()):
			errors.append("done %d is not a non-empty string" % index)
		elif seen.has(entry):
			errors.append("done %d: duplicate '%s'" % [index, entry])
		else:
			seen[entry] = true
	if active_value is String and seen.has(active_value):
		errors.append("'active' is already done")
	return errors
