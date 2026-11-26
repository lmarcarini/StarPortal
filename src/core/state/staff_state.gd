class_name StaffState
extends RefCounted
## Saved state of the base's people (docs/content/m26-staff-and-money.md sections 1, 3 and 7):
## the roster, the next person number and the room types still waiting to auto-staff their
## first room. Only commands and SimSystem.tick() change it, through StaffRules' callers:
## AssignStaffCommand, UnassignStaffCommand, DemolishRoomCommand and StaffAutoAssign.
## M3 adds the ticks lent-soldier replacements are due (m3-beyond-the-ring.md section 4).
## Saved shape: {"people": [PersonState...], "next_person_number", "auto_assign": [def id...],
## "lent_due": [tick...]}.
## Bible: docs/content/m26-staff-and-money.md sections 1, 3, 7 and 8,
## technical-architecture.md#data-model

## Saved keys, in to_dict() order.
const _KEYS: Array[String] = ["people", "next_person_number", "auto_assign", "lent_due"]

## Everyone on the roster, on base or arriving, in the order they joined.
var people: Array[PersonState] = []
## Number used for the next person's id ("person_<n>"); never reused.
var next_person_number: int = 1
## Room def ids whose first finished room takes the Unassigned people of its role
## (section 7: the first Research Lab and the first Workshop). A def leaves the list when its
## first room finishes.
var auto_assign: Array[StringName] = []
## Ticks on which the Directorate lends a replacement soldier, one entry per lost lent soldier,
## in the order they were lost (ExpeditionUnlock.lose_person()).
var lent_due: Array[int] = []


## Adds [param person] with the next free id and returns it. A person with no appearance
## record gets one seeded from the new id and the role (AppearanceRules.roll_seeded(), M8-01).
func add_person(person: PersonState) -> PersonState:
	person.id = StringName("person_%d" % next_person_number)
	next_person_number += 1
	if person.appearance.is_empty():
		person.appearance = AppearanceRules.roll_seeded(
			String(person.id), AppearanceRules.field_for_role(person.role)
		)
	people.append(person)
	return person


## Removes the person with id [param person_id], if any (used by dismissal, card M2.6-06).
func remove_person(person_id: StringName) -> void:
	for index: int in people.size():
		if people[index].id == person_id:
			people.remove_at(index)
			return


## Returns the person with id [param person_id], or null.
func find_person(person_id: StringName) -> PersonState:
	for person: PersonState in people:
		if person.id == person_id:
			return person
	return null


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var people_data: Array = []
	for person: PersonState in people:
		people_data.append(person.to_dict())
	var auto_data: Array = []
	for def_id: StringName in auto_assign:
		auto_data.append(String(def_id))
	return {
		"people": people_data,
		"next_person_number": next_person_number,
		"auto_assign": auto_data,
		"lent_due": lent_due.duplicate(),
	}


## Builds a StaffState from saved [param data]; entries that are not objects or strings are
## skipped. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> StaffState:
	var staff := StaffState.new()
	for entry: Variant in _array_or_empty(data.get("people")):
		if entry is Dictionary:
			var person_data: Dictionary = entry
			staff.people.append(PersonState.from_dict(person_data))
	staff.next_person_number = maxi(1, RoomState.read_count(data.get("next_person_number")))
	for entry: Variant in _array_or_empty(data.get("auto_assign")):
		if entry is String and not StringName(str(entry)) in staff.auto_assign:
			staff.auto_assign.append(StringName(str(entry)))
	for entry: Variant in _array_or_empty(data.get("lent_due")):
		if RoomState.is_count(entry):
			staff.lent_due.append(RoomState.read_count(entry))
	return staff


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present; "people" an array of valid people with unique ids, each "person_<n>" below
## "next_person_number" (a whole number of at least 1); "auto_assign" an array of distinct
## non-empty strings; "lent_due" an array of whole numbers of at least 0. Ids against the
## content and the base: StaffSaveChecks.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _KEYS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	if not errors.is_empty():
		return errors
	var number_ok: bool = RoomState.is_count(data["next_person_number"])
	if not (number_ok and data["next_person_number"] >= 1):
		errors.append("'next_person_number' is not a whole number of at least 1")
	errors.append_array(_people_errors(data["people"]))
	errors.append_array(_auto_errors(data["auto_assign"]))
	var due: Array = _array_or_empty(data["lent_due"])
	if not data["lent_due"] is Array or not due.all(RoomState.is_count):
		errors.append("'lent_due' is not an array of whole numbers of at least 0")
	if errors.is_empty():
		errors.append_array(_id_errors(from_dict(data)))
	return errors


static func _people_errors(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'people' is not an array")
		return errors
	var entries: Array = value
	for index: int in entries.size():
		if not entries[index] is Dictionary:
			errors.append("people %d is not an object" % index)
			continue
		var person_data: Dictionary = entries[index]
		for error: String in PersonState.validate_dict(person_data):
			errors.append("people %d: %s" % [index, error])
	return errors


static func _auto_errors(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'auto_assign' is not an array")
		return errors
	var entries: Array = value
	var seen: Dictionary[String, bool] = {}
	for index: int in entries.size():
		var entry: Variant = entries[index]
		if not (entry is String and not str(entry).is_empty()) or seen.has(str(entry)):
			errors.append("auto_assign %d is not a distinct non-empty string" % index)
		seen[str(entry)] = true
	return errors


## Errors for duplicate person ids and ids not below next_person_number.
static func _id_errors(staff: StaffState) -> Array[String]:
	var errors: Array[String] = []
	var seen: Dictionary[StringName, bool] = {}
	for index: int in staff.people.size():
		var person_id: StringName = staff.people[index].id
		if seen.has(person_id):
			errors.append("people %d: duplicate id '%s'" % [index, person_id])
		seen[person_id] = true
		if _person_number(person_id) >= staff.next_person_number:
			errors.append(
				"people %d: id '%s' is not below 'next_person_number'" % [index, person_id]
			)
	return errors


## The n of a "person_<n>" id, or 0 for any other id.
static func _person_number(person_id: StringName) -> int:
	var text: String = String(person_id)
	if not text.begins_with("person_") or not text.substr(7).is_valid_int():
		return 0
	return maxi(0, text.substr(7).to_int())


static func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return value
	return []
