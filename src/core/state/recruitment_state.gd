class_name RecruitmentState
extends RefCounted
## Saved state of recruitment (docs/content/m27-daily-rhythm.md section 3): the rolling
## candidate list and the number of the next candidate id. People hired and still arriving
## live on the roster (StaffState, PersonState.arrives_tick), so they are saved there.
## Only HireCommand and RecruitmentSystem change it.
## Saved shape: {"candidates": [CandidateState...], "next_candidate_number"}.
## Bible: docs/content/m27-daily-rhythm.md section 3, m26-staff-and-money.md section 8,
## technical-architecture.md#data-model

## The candidates on offer, in list order.
var candidates: Array[CandidateState] = []
## Number used for the next candidate's id ("candidate_<n>"); never reused.
var next_candidate_number: int = 1


## Replaces the list with [param fresh], giving each candidate the next free id.
func replace_list(fresh: Array[CandidateState]) -> void:
	candidates.clear()
	for candidate: CandidateState in fresh:
		candidate.id = StringName("candidate_%d" % next_candidate_number)
		next_candidate_number += 1
		candidates.append(candidate)


## Adds [param candidate] at the end of the list with the next free id.
func add_candidate(candidate: CandidateState) -> void:
	candidate.id = StringName("candidate_%d" % next_candidate_number)
	next_candidate_number += 1
	candidates.append(candidate)


## Removes every candidate whose leave day is [param day] or earlier; returns how many left.
func remove_leaving(day: int) -> int:
	var before: int = candidates.size()
	candidates.assign(candidates.filter(func(c: CandidateState) -> bool: return c.leaves_day > day))
	return before - candidates.size()


## Removes the oldest candidate (earliest leave day; first in list order on a tie), if any.
func remove_oldest() -> void:
	if candidates.is_empty():
		return
	var oldest: int = 0
	for index: int in candidates.size():
		if candidates[index].leaves_day < candidates[oldest].leaves_day:
			oldest = index
	candidates.remove_at(oldest)


## Returns the candidate with id [param candidate_id], or null.
func find_candidate(candidate_id: StringName) -> CandidateState:
	for candidate: CandidateState in candidates:
		if candidate.id == candidate_id:
			return candidate
	return null


## Removes the candidate with id [param candidate_id], if any.
func remove_candidate(candidate_id: StringName) -> void:
	for index: int in candidates.size():
		if candidates[index].id == candidate_id:
			candidates.remove_at(index)
			return


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var list: Array = []
	for candidate: CandidateState in candidates:
		list.append(candidate.to_dict())
	return {"candidates": list, "next_candidate_number": next_candidate_number}


## Builds a RecruitmentState from saved [param data]; entries that are not objects are skipped.
## Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> RecruitmentState:
	var recruitment := RecruitmentState.new()
	var list: Variant = data.get("candidates")
	if list is Array:
		var entries: Array = list
		for entry: Variant in entries:
			if entry is Dictionary:
				var candidate_data: Dictionary = entry
				recruitment.candidates.append(CandidateState.from_dict(candidate_data))
	recruitment.next_candidate_number = maxi(
		1, RoomState.read_count(data.get("next_candidate_number"))
	)
	return recruitment


## Returns human-readable errors for saved [param data], empty when it is valid:
## "candidates" an array of valid candidates with distinct ids, and "next_candidate_number" a
## whole number of at least 1.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var number: Variant = data.get("next_candidate_number")
	if not (RoomState.is_count(number) and number >= 1):
		errors.append("'next_candidate_number' is not a whole number of at least 1")
	var list: Variant = data.get("candidates")
	if not list is Array:
		errors.append("'candidates' is missing or not an array")
		return errors
	var entries: Array = list
	var seen: Dictionary[String, bool] = {}
	for index: int in entries.size():
		if not entries[index] is Dictionary:
			errors.append("candidates %d is not an object" % index)
			continue
		var entry: Dictionary = entries[index]
		for error: String in CandidateState.validate_dict(entry):
			errors.append("candidates %d: %s" % [index, error])
		var candidate_id: String = str(entry.get("id", ""))
		if seen.has(candidate_id):
			errors.append("candidates %d: duplicate id '%s'" % [index, candidate_id])
		seen[candidate_id] = true
	return errors


## Errors of the candidates' role ids in valid saved [param data] against [param defs].
static func content_errors(data: Dictionary, defs: GameDefs) -> Array[String]:
	var roles: Dictionary[StringName, bool] = {}
	for role: RoleDef in defs.roles:
		roles[role.id] = true
	var errors: Array[String] = []
	var recruitment: RecruitmentState = from_dict(data)
	for index: int in recruitment.candidates.size():
		var role: StringName = recruitment.candidates[index].role
		if not roles.has(role):
			errors.append("recruitment: candidates %d has unknown role '%s'" % [index, role])
	return errors
