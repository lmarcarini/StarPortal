class_name ResearchBench
extends RefCounted
## Saved state of one research building (docs/content/research-and-progression.md section 3):
## the project it runs, how far it has got and its own queue. Kept by room id in
## ResearchState.benches.
## Saved shape: {"active": project id or "", "ticks_done": whole number, "queue": [ids]}.
## Bible: docs/content/research-and-progression.md section 3

## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["active", "ticks_done", "queue"]

## The project running (paid for), or &"" when none.
var active: StringName = &""
## Ticks of progress on the active project; 0 when none runs.
var ticks_done: int = 0
## Projects waiting to start here after the active one, in order; no duplicates.
var queue: Array[StringName] = []


## True when a project is running here.
func is_running() -> bool:
	return not active.is_empty()


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"active": String(active), "ticks_done": ticks_done, "queue": SaveFields.write_ids(queue)
	}


## Builds a bench from saved [param data]; unreadable entries are skipped.
static func from_dict(data: Dictionary) -> ResearchBench:
	var bench := ResearchBench.new()
	bench.active = SaveFields.read_id(data.get("active"))
	bench.ticks_done = SaveFields.read_int(data.get("ticks_done"))
	bench.queue = SaveFields.read_ids(data.get("queue"))
	return bench


## Errors of saved [param data], empty when valid.
static func validate_dict(data: Dictionary, label: String) -> Array[String]:
	var errors: Array[String] = []
	for problem: String in SaveFields.missing(data, KEYS):
		errors.append("%s: %s" % [label, problem])
	if not errors.is_empty():
		return errors
	if not data["active"] is String:
		errors.append("%s: 'active' is not a string" % label)
	if not RoomState.is_count(data["ticks_done"]):
		errors.append("%s: 'ticks_done' is not a whole number of at least 0" % label)
	errors.append_array(SaveFields.id_list_errors(data["queue"], label + " queue"))
	return errors
