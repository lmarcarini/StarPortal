class_name PersonState
extends RefCounted
## Saved state of one person on the roster (docs/content/m26-staff-and-money.md section 1): a
## name, a role fixed for life, a skill from 1 to 5, a salary per 30 days, the room they work in
## (or none) and the tick they arrive on base. Points at its RoleDef and room by id.
## Saved shape: {"id", "name", "role", "skill", "salary_k", "room_id", "arrives_tick"}.
## Bible: docs/content/m26-staff-and-money.md sections 1 and 3, technical-architecture.md#data-model

## Lowest skill.
const MIN_SKILL: int = 1
## Highest skill.
const MAX_SKILL: int = 5
## Saved keys, in to_dict() order.
const _KEYS: Array[String] = ["id", "name", "role", "skill", "salary_k", "room_id", "arrives_tick"]

## Unique id on the roster, e.g. &"person_1"; never reused.
var id: StringName = &""
## Display name with any title ("Dr Ana Ferreira"); never translated.
var name: String = ""
## Id of the person's RoleDef, e.g. &"role_scientist".
var role: StringName = &""
## Skill in the role, [constant MIN_SKILL] to [constant MAX_SKILL].
var skill: int = MIN_SKILL
## Salary per 30 days in $k, fixed at hiring (StaffRules.salary_for_skill()).
var salary_k: int = 0
## Id of the room the person works in, or &"" when Unassigned.
var room_id: StringName = &""
## Tick the person arrives on base; at or before the clock's tick they are on base.
var arrives_tick: int = 0


## True when the person has a room.
func is_assigned() -> bool:
	return not room_id.is_empty()


## True when the person is on base at tick [param now] (not still arriving).
func is_on_base(now: int) -> bool:
	return arrives_tick <= now


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"name": name,
		"role": String(role),
		"skill": skill,
		"salary_k": salary_k,
		"room_id": String(room_id),
		"arrives_tick": arrives_tick,
	}


## Builds a PersonState from saved [param data] (whole floats become ints). Missing or
## unreadable values keep their defaults. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> PersonState:
	var person := PersonState.new()
	person.id = StringName(str(data.get("id", "")))
	person.name = str(data.get("name", ""))
	person.role = StringName(str(data.get("role", "")))
	person.skill = clampi(RoomState.read_count(data.get("skill")), MIN_SKILL, MAX_SKILL)
	person.salary_k = RoomState.read_count(data.get("salary_k"))
	person.room_id = StringName(str(data.get("room_id", "")))
	person.arrives_tick = RoomState.read_count(data.get("arrives_tick"))
	return person


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present; "id", "name" and "role" non-empty strings; "room_id" a string; "skill" a whole
## number from [constant MIN_SKILL] to [constant MAX_SKILL]; "salary_k" and "arrives_tick"
## whole numbers of at least 0. Role and room ids are checked against the content and the base
## by StaffSaveChecks.
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
	if not data["room_id"] is String:
		errors.append("'room_id' is not a string")
	var skill_ok: bool = RoomState.is_count(data["skill"])
	if not (skill_ok and data["skill"] >= MIN_SKILL and data["skill"] <= MAX_SKILL):
		errors.append("'skill' is not a whole number from %d to %d" % [MIN_SKILL, MAX_SKILL])
	for key: String in ["salary_k", "arrives_tick"]:
		if not RoomState.is_count(data[key]):
			errors.append("'%s' is not a whole number of at least 0" % key)
	return errors
