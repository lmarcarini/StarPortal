class_name CandidateState
extends RefCounted
## Saved state of one candidate on the monthly list (docs/content/m26-staff-and-money.md
## section 2): who they are, what they would cost and how long they take to arrive. Hiring
## turns a candidate into a PersonState; the fee is 30 days' salary.
## Saved shape: {"id", "name", "role", "skill", "salary_k", "arrival_ticks"}.
## Bible: docs/content/m26-staff-and-money.md section 2, technical-architecture.md#data-model

## Saved keys, in to_dict() order.
const _KEYS: Array[String] = ["id", "name", "role", "skill", "salary_k", "arrival_ticks"]

## Unique id among candidates, e.g. &"candidate_3"; never reused.
var id: StringName = &""
## Display name with any title ("Dr Ines Moreau"); never translated.
var name: String = ""
## Id of the candidate's RoleDef; the role names the pipeline (scientist: Academia).
var role: StringName = &""
## Skill in the role, PersonState.MIN_SKILL to PersonState.MAX_SKILL.
var skill: int = PersonState.MIN_SKILL
## Salary per 30 days in $k once hired; also the hiring fee.
var salary_k: int = 0
## Ticks from hiring to arrival on base (the pipeline's delay).
var arrival_ticks: int = 0


## Returns a candidate with the given values and an empty id (RecruitmentState.add_candidate()
## sets it).
static func create(
	display_name: String, role_id: StringName, skill_level: int, salary: int
) -> CandidateState:
	var candidate := CandidateState.new()
	candidate.name = display_name
	candidate.role = role_id
	candidate.skill = skill_level
	candidate.salary_k = salary
	return candidate


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": name,
		"role": String(role),
		"skill": skill,
		"salary_k": salary_k,
		"arrival_ticks": arrival_ticks,
	}


## Builds a CandidateState from saved [param data] (whole floats become ints). Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> CandidateState:
	var candidate := CandidateState.new()
	candidate.id = StringName(str(data.get("id", "")))
	candidate.name = str(data.get("name", ""))
	candidate.role = StringName(str(data.get("role", "")))
	candidate.skill = clampi(
		RoomState.read_count(data.get("skill")), PersonState.MIN_SKILL, PersonState.MAX_SKILL
	)
	candidate.salary_k = RoomState.read_count(data.get("salary_k"))
	candidate.arrival_ticks = RoomState.read_count(data.get("arrival_ticks"))
	return candidate


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present; "id", "name" and "role" non-empty strings; "skill" a whole number in the skill
## range; "salary_k" a whole number of at least 0 and "arrival_ticks" one of at least 1.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _KEYS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	if not errors.is_empty():
		return errors
	for key: String in ["id", "name", "role"]:
		if not (data[key] is String and not str(data[key]).is_empty()):
			errors.append("'%s' is not a non-empty string" % key)
	var skill_ok: bool = RoomState.is_count(data["skill"])
	if not (
		skill_ok
		and data["skill"] >= PersonState.MIN_SKILL
		and data["skill"] <= PersonState.MAX_SKILL
	):
		errors.append("'skill' is not a whole number from 1 to 5")
	if not RoomState.is_count(data["salary_k"]):
		errors.append("'salary_k' is not a whole number of at least 0")
	if not (RoomState.is_count(data["arrival_ticks"]) and data["arrival_ticks"] >= 1):
		errors.append("'arrival_ticks' is not a whole number of at least 1")
	return errors
