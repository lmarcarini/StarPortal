class_name ResearchState
extends RefCounted
## Saved state of research (docs/content/research-and-progression.md sections 2-3): one
## bench per research building (its project, progress and queue), the projects done, the
## projects revealed so far (each revealed once, with a "new research" event) and those the
## player has opened in the Lab (no NEW lamp). Only research commands and ResearchSystem
## change it.
## Saved shape: {"done": [ids], "revealed": [ids], "opened": [ids],
## "benches": {room id: ResearchBench}}.
## Bible: docs/content/research-and-progression.md sections 2-3,
## technical-architecture.md#data-model

## Saved keys, in to_dict() order.
const _KEYS: Array[String] = ["done", "revealed", "opened", "benches"]

## Projects finished, in the order they finished; no duplicates.
var done: Array[StringName] = []
## Projects revealed so far, in the order they appeared; no duplicates.
var revealed: Array[StringName] = []
## Revealed projects the player has opened in the Lab; no duplicates.
var opened: Array[StringName] = []
## Bench of each research building that has run or queued something, by room id.
var benches: Dictionary[StringName, ResearchBench] = {}


## True when any bench runs a project.
func is_running() -> bool:
	for bench: ResearchBench in benches.values():
		if bench.is_running():
			return true
	return false


## True when [param project_id] is finished.
func is_done(project_id: StringName) -> bool:
	return project_id in done


## The bench of [param room_id], or null when it has none yet.
func bench_of(room_id: StringName) -> ResearchBench:
	return benches.get(room_id)


## The bench of [param room_id], made when missing.
func ensure_bench(room_id: StringName) -> ResearchBench:
	if not benches.has(room_id):
		benches[room_id] = ResearchBench.new()
	return benches[room_id]


## The room whose bench runs [param project_id], or &"".
func room_running(project_id: StringName) -> StringName:
	for room_id: StringName in benches:
		if benches[room_id].active == project_id:
			return room_id
	return &""


## The room whose queue holds [param project_id], or &"".
func room_queuing(project_id: StringName) -> StringName:
	for room_id: StringName in benches:
		if benches[room_id].queue.has(project_id):
			return room_id
	return &""


## Every project running, in bench order.
func running() -> Array[StringName]:
	var found: Array[StringName] = []
	for bench: ResearchBench in benches.values():
		if bench.is_running():
			found.append(bench.active)
	return found


## True when [param project_id] is revealed and not yet opened in the Lab.
func is_new(project_id: StringName) -> bool:
	return revealed.has(project_id) and not opened.has(project_id)


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var bench_data: Dictionary = {}
	for room_id: StringName in benches:
		bench_data[String(room_id)] = benches[room_id].to_dict()
	return {
		"done": SaveFields.write_ids(done),
		"revealed": SaveFields.write_ids(revealed),
		"opened": SaveFields.write_ids(opened),
		"benches": bench_data,
	}


## Builds a ResearchState from saved [param data]. Unreadable entries are skipped. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> ResearchState:
	var research := ResearchState.new()
	research.done = SaveFields.read_ids(data.get("done"))
	research.revealed = SaveFields.read_ids(data.get("revealed"))
	research.opened = SaveFields.read_ids(data.get("opened"))
	var bench_data: Dictionary = SaveFields.dict_or_empty(data.get("benches"))
	for key: Variant in bench_data:
		var entry: Dictionary = SaveFields.dict_or_empty(bench_data[key])
		if key is String and not str(key).is_empty():
			research.benches[StringName(str(key))] = ResearchBench.from_dict(entry)
	return research


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present; "done", "revealed" and "opened" arrays of distinct non-empty strings; "benches" a
## dictionary of valid benches.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, _KEYS)
	if not errors.is_empty():
		return errors
	for key: String in ["done", "revealed", "opened"]:
		errors.append_array(SaveFields.id_list_errors(data[key], key))
	if not data["benches"] is Dictionary:
		errors.append("'benches' is not a dictionary")
		return errors
	var bench_data: Dictionary = data["benches"]
	for key: Variant in bench_data:
		if not (key is String and bench_data[key] is Dictionary):
			errors.append("bench '%s' is not a dictionary" % str(key))
			continue
		var entry: Dictionary = bench_data[key]
		errors.append_array(ResearchBench.validate_dict(entry, "bench " + str(key)))
	return errors
