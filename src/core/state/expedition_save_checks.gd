class_name ExpeditionSaveChecks
extends RefCounted
## Validation of saved ExpeditionState data. Pure static.
## Bible: docs/content/m3-beyond-the-ring.md section 9 (saves)


## Errors for saved expedition [param data], empty when valid: a known mode and objective;
## while idle nothing else set; while planned or away an objective, a world, a target exactly
## for a Recover and a team of four distinct person ids in the four slots; "departed_tick" a
## tick exactly while away, else -1; "day_results" fewer than the objective's days and only
## while away; "documents" objects with a world id, a kind, a target id and a tick.
static func errors(data: Dictionary) -> Array[String]:
	var mode: int = ExpeditionState.MODE_NAMES.find(data.get("mode"))
	var objective: int = ExpeditionState.OBJECTIVE_NAMES.find(data.get("objective"))
	if not data.get("mode") is String or mode < 0:
		return ["'mode' is not one of %s" % str(ExpeditionState.MODE_NAMES)]
	if not data.get("objective") is String or objective < 0:
		return ["'objective' is not one of %s" % str(ExpeditionState.OBJECTIVE_NAMES)]
	var found: Array[String] = []
	for key: String in ["world_id", "target_id"]:
		if not data.get(key) is String:
			found.append("'%s' is not a string" % key)
	if not data.get("team") is Dictionary:
		found.append("'team' is not an object")
	if not data.get("day_results") is Array:
		found.append("'day_results' is not an array")
	if not (JsonLimits.is_exact_int(data.get("departed_tick")) and data["departed_tick"] >= -1):
		found.append("'departed_tick' is not -1 or a tick")
	if not found.is_empty():
		return found
	found.append_array(_document_errors(data.get("documents")))
	if mode == ExpeditionState.Mode.IDLE:
		found.append_array(_idle_errors(data, objective))
	else:
		found.append_array(_plan_errors(data, objective))
		found.append_array(_trip_errors(data, mode, objective))
	return found


## A document entry rebuilt from saved [param data].
static func document_from(data: Dictionary) -> Dictionary:
	return {
		"world_id": str(data.get("world_id", "")),
		"kind": str(data.get("kind", "")),
		"target_id": str(data.get("target_id", "")),
		"tick": type_convert(data.get("tick", 0), TYPE_INT),
	}


static func _idle_errors(data: Dictionary, objective: int) -> Array[String]:
	var team: Dictionary = data["team"]
	var results: Array = data["day_results"]
	var is_clear: bool = (
		objective == ExpeditionState.Objective.NONE
		and str(data["world_id"]).is_empty()
		and str(data["target_id"]).is_empty()
		and team.is_empty()
		and results.is_empty()
		and _is_unset(data["departed_tick"])
	)
	return [] if is_clear else ["an idle expedition has a plan or a trip set"]


static func _plan_errors(data: Dictionary, objective: int) -> Array[String]:
	var found: Array[String] = []
	if objective == ExpeditionState.Objective.NONE:
		found.append("a plan has no objective")
	if str(data["world_id"]).is_empty():
		found.append("a plan has no world")
	var needs_target: bool = objective == ExpeditionState.Objective.RECOVER
	if str(data["target_id"]).is_empty() == needs_target:
		found.append("a plan has a target exactly when it is a Recover")
	var team: Dictionary = data["team"]
	var ids: Array[String] = []
	for slot: String in ExpeditionState.SLOTS:
		var person: Variant = team.get(slot)
		if person is String and not str(person).is_empty() and not ids.has(str(person)):
			ids.append(str(person))
	if team.size() != ExpeditionState.SLOTS.size() or ids.size() != team.size():
		found.append("'team' is not four distinct person ids in %s" % str(ExpeditionState.SLOTS))
	return found


static func _trip_errors(data: Dictionary, mode: int, objective: int) -> Array[String]:
	var results: Array = data["day_results"]
	var is_away: bool = mode == ExpeditionState.Mode.AWAY
	var found: Array[String] = []
	if is_away == _is_unset(data["departed_tick"]):
		found.append("'departed_tick' is set exactly while away")
	if not results.all(func(result: Variant) -> bool: return result is String):
		return found + ["'day_results' is not an array of results"]
	if not results.all(func(result: String) -> bool: return result in ExpeditionState.DAY_RESULTS):
		found.append("'day_results' is not an array of %s" % str(ExpeditionState.DAY_RESULTS))
	var limit: int = ExpeditionState.OBJECTIVE_DAYS[objective] if is_away else 1
	if results.size() >= limit:
		found.append("'day_results' has more field days than the trip")
	return found


static func _document_errors(documents: Variant) -> Array[String]:
	if not documents is Array:
		return ["'documents' is not an array"]
	var found: Array[String] = []
	var list: Array = documents
	for index: int in list.size():
		if not list[index] is Dictionary:
			found.append("document %d is not an object" % index)
			continue
		var entry: Dictionary = list[index]
		var is_valid: bool = (
			entry.get("world_id") is String
			and not str(entry["world_id"]).is_empty()
			and ExpeditionState.DOCUMENT_KINDS.has(entry.get("kind"))
			and entry.get("target_id") is String
			and JsonLimits.is_exact_int(entry.get("tick"))
			and entry["tick"] >= 0
		)
		if not is_valid:
			found.append("document %d is not a world id, kind, target id and tick" % index)
	return found


static func _is_unset(tick: Variant) -> bool:
	var number: float = tick
	return is_equal_approx(number, -1.0)
