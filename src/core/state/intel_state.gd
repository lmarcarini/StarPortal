class_name IntelState
extends RefCounted
## Saved intelligence: every clue received, in arrival order, the player's notes on them,
## the counters that number new clues and dossiers, and the dossiers waiting to arrive.
## Saved shape: {"clues": [ClueRecord], "notes": {clue id: ClueNote}, "next_clue_number",
## "next_dossier_number", "scheduled_dossiers": {target world id: arrival tick}}.
## Bible: gate-and-address-spec.md#clue-types-and-reliability,
## gate-and-address-spec.md#player-tools, technical-architecture.md#data-model

## Every clue received, in arrival order.
var clues: Array[ClueRecord] = []
## The player's notes, only for clues that have one.
var notes: Dictionary[StringName, ClueNote] = {}
## Number of the next clue id to hand out; starts at 1.
var next_clue_number: int = 1
## Number of the next dossier id to hand out; starts at 1.
var next_dossier_number: int = 1
## Dossiers on their way: target world id -> tick they arrive.
var scheduled_dossiers: Dictionary[StringName, int] = {}


## Returns the clue with id [param id], or null when there is none.
func get_clue(id: StringName) -> ClueRecord:
	for record: ClueRecord in clues:
		if record.id == id:
			return record
	return null


## Returns the player's note on clue [param id], or a fresh default note when it has none.
func note_for(id: StringName) -> ClueNote:
	if notes.has(id):
		return notes[id]
	return ClueNote.new()


## Appends [param record] as the newest clue. For systems: assigns no id or number; the
## id must not be taken already (asserts).
func add_clue(record: ClueRecord) -> void:
	assert(record != null, "IntelState.add_clue() needs a record")
	assert(get_clue(record.id) == null, "IntelState.add_clue(): '%s' already exists" % record.id)
	clues.append(record)


## Returns the ids of every clue, as Strings, for link_errors().
func known_clue_ids() -> Dictionary[String, bool]:
	var known_ids: Dictionary[String, bool] = {}
	for record: ClueRecord in clues:
		known_ids[String(record.id)] = true
	return known_ids


## Returns errors for the links of the note on clue [param clue_id]: each must name a clue in
## [param known_ids] other than [param clue_id]. Used by validate_dict() and by commands.
static func link_errors(
	clue_id: String, links: Array, known_ids: Dictionary[String, bool]
) -> Array[String]:
	var errors: Array[String] = []
	for link: Variant in links:
		var link_id := str(link)
		if link_id == clue_id:
			errors.append("note '%s' links to itself" % clue_id)
		elif not known_ids.has(link_id):
			errors.append("note '%s' links to unknown clue '%s'" % [clue_id, link_id])
	return errors


## Returns JSON-safe data for saving; ids become Strings.
func to_dict() -> Dictionary:
	var clue_data: Array[Dictionary] = []
	for record: ClueRecord in clues:
		clue_data.append(record.to_dict())
	var note_data: Dictionary = {}
	for clue_id: StringName in notes:
		note_data[String(clue_id)] = notes[clue_id].to_dict()
	var schedule_data: Dictionary = {}
	for world_id: StringName in scheduled_dossiers:
		schedule_data[String(world_id)] = scheduled_dossiers[world_id]
	return {
		"clues": clue_data,
		"notes": note_data,
		"next_clue_number": next_clue_number,
		"next_dossier_number": next_dossier_number,
		"scheduled_dossiers": schedule_data,
	}


## Builds an IntelState from saved [param data]; JSON floats become ints. Unreadable values
## keep their defaults and unreadable entries are skipped. Call validate_dict() first for
## untrusted data.
static func from_dict(data: Dictionary) -> IntelState:
	var intel := IntelState.new()
	for item: Variant in _array_or_empty(data.get("clues")):
		if item is Dictionary:
			var record_data: Dictionary = item
			intel.clues.append(ClueRecord.from_dict(record_data))
	var note_data: Dictionary = _dict_or_empty(data.get("notes"))
	for clue_id: Variant in note_data:
		if note_data[clue_id] is Dictionary:
			var one_note: Dictionary = note_data[clue_id]
			intel.notes[StringName(str(clue_id))] = ClueNote.from_dict(one_note)
	intel.next_clue_number = type_convert(data.get("next_clue_number", 1), TYPE_INT)
	intel.next_dossier_number = type_convert(data.get("next_dossier_number", 1), TYPE_INT)
	var schedule_data: Dictionary = _dict_or_empty(data.get("scheduled_dossiers"))
	for world_id: Variant in schedule_data:
		var tick: Variant = schedule_data[world_id]
		if tick is int or tick is float:
			intel.scheduled_dossiers[StringName(str(world_id))] = type_convert(tick, TYPE_INT)
	return intel


## Returns human-readable errors for saved [param data], empty when it is valid: "clues" an
## array of objects passing ClueRecord.validate_dict() with distinct ids; "notes" an object
## keyed by ids of those clues whose values pass ClueNote.validate_dict() and link only to
## other known clues; both counters whole numbers from 1 to 2^53; "scheduled_dossiers" an
## object mapping non-empty world ids to whole-number ticks from 0 to 2^53.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var known_ids: Dictionary[String, bool] = {}
	errors.append_array(_clue_errors(data.get("clues"), known_ids))
	errors.append_array(_note_errors(data.get("notes"), known_ids))
	for key: String in ["next_clue_number", "next_dossier_number"]:
		if not _is_whole_from(data.get(key), 1):
			errors.append("'%s' is not a whole number from 1 to 2^53" % key)
	errors.append_array(_schedule_errors(data.get("scheduled_dossiers")))
	return errors


## Errors of the clue list; fills [param known_ids] with the ids of the valid clues.
static func _clue_errors(value: Variant, known_ids: Dictionary[String, bool]) -> Array[String]:
	if not value is Array:
		return ["'clues' is not an array"]
	var list: Array = value
	var errors: Array[String] = []
	for index: int in list.size():
		if not list[index] is Dictionary:
			errors.append("clue %d is not an object" % index)
			continue
		var record_data: Dictionary = list[index]
		var record_errors := ClueRecord.validate_dict(record_data)
		for error: String in record_errors:
			errors.append("clue %d: %s" % [index, error])
		var clue_id := str(record_data.get("id", ""))
		if known_ids.has(clue_id):
			errors.append("clue %d repeats id '%s'" % [index, clue_id])
		elif record_errors.is_empty():
			known_ids[clue_id] = true
	return errors


static func _note_errors(value: Variant, known_ids: Dictionary[String, bool]) -> Array[String]:
	if not value is Dictionary:
		return ["'notes' is not an object"]
	var note_data: Dictionary = value
	var errors: Array[String] = []
	for key: Variant in note_data:
		var clue_id := str(key)
		if not known_ids.has(clue_id):
			errors.append("note for unknown clue '%s'" % clue_id)
			continue
		if not note_data[key] is Dictionary:
			errors.append("note '%s' is not an object" % clue_id)
			continue
		var one_note: Dictionary = note_data[key]
		var note_errors := ClueNote.validate_dict(one_note)
		for error: String in note_errors:
			errors.append("note '%s': %s" % [clue_id, error])
		if note_errors.is_empty():
			var links: Array = one_note["links"]
			errors.append_array(link_errors(clue_id, links, known_ids))
	return errors


static func _schedule_errors(value: Variant) -> Array[String]:
	if not value is Dictionary:
		return ["'scheduled_dossiers' is not an object"]
	var schedule_data: Dictionary = value
	var errors: Array[String] = []
	for world_id: Variant in schedule_data:
		if str(world_id).is_empty():
			errors.append("a scheduled dossier has an empty world id")
		elif not _is_whole_from(schedule_data[world_id], 0):
			errors.append("dossier for '%s' is not at a tick from 0 to 2^53" % world_id)
	return errors


## True for an int, or a whole float, from [param low] to 2^53.
static func _is_whole_from(value: Variant, low: int) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= float(low)


static func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func _dict_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}
