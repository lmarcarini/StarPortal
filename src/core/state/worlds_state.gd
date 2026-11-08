class_name WorldsState
extends RefCounted
## Saved progress over the galaxy: the seed and generator version the galaxy is regenerated
## from, the status of every world the player has learned something about, the far consoles
## read, the worlds whose horizon record the pole camera has taken, and the pole camera on its
## way through the open wormhole.
## Saved shape: {"galaxy_seed": decimal string, "generator_version", "statuses":
## {world id: status name}, "consoles_read": {world id: true}, "horizon_records":
## {world id: true}, "reports": {world id: WorldReport data}, "targets": TargetStates data,
## "pole_camera_world_id": world id
## or "", "pole_camera_ticks_left"}. The seed
## is a string because it can exceed 2^53. The pole camera is out exactly when both its fields
## are set (a world id and at least 1 tick left); otherwise "" and 0.
## Bible: technical-architecture.md#data-model, technical-architecture.md#save-system,
## gate-and-address-spec.md#where-addresses-come-from (Ring consoles),
## game-design.md#base-building-and-power (the pole camera, horizon record),
## docs/content/m3-beyond-the-ring.md section 3 (world states) and section 9 (saves)

## How far the base has come with a world, in order; a world's status never goes down
## (raise it through WorldProgress). UNKNOWN is never stored. LOCKED: first lock. PROBED: first
## finished or lost MOTH run. SURVEYED: a team's Survey returned. CONTACTED: the first
## conversation with its people ended.
enum WorldStatus { UNKNOWN, LOCKED, PROBED, SURVEYED, CONTACTED }

## Saved names of the statuses, indexed by WorldStatus value.
const STATUS_NAMES: Array[String] = ["unknown", "locked", "probed", "surveyed", "contacted"]

## Seed of the galaxy: RandomState.derive_seed(base seed, &"galaxy").
var galaxy_seed: int = 0
## WorldGenerator.GENERATOR_VERSION the galaxy was generated with.
var generator_version: int = 0
## Status of every world that is not UNKNOWN, by world id.
var statuses: Dictionary[StringName, WorldStatus] = {}
## Worlds whose far Ring's console the player has read, by world id; always true.
var consoles_read: Dictionary[StringName, bool] = {}
## Worlds whose horizon record the pole camera has taken, by world id; always true.
var horizon_records: Dictionary[StringName, bool] = {}
## What the base knows of each world's report facts, by world id; a world with no entry knows
## nothing (every fact at NONE). Read it through report_of().
var reports: Dictionary[StringName, WorldReport] = {}
## Targets marked recoverable or recovered (saved here, never on the shared WorldTarget).
var targets: TargetStates = TargetStates.new()
## The world the pole camera is extending into, or &"" while it is in.
var pole_camera_world_id: StringName = &""
## Ticks until the extending pole camera takes the horizon record; 0 while it is in.
var pole_camera_ticks_left: int = 0


## Returns the status of [param world_id]; UNKNOWN when none is stored.
func status_of(world_id: StringName) -> WorldStatus:
	return statuses.get(world_id, WorldStatus.UNKNOWN)


## True when [param world_id] has reached at least [param status].
func has_reached(world_id: StringName, status: WorldStatus) -> bool:
	return status_of(world_id) >= status


## Returns the report of [param world_id]; an empty one (not stored) when nothing is known.
func report_of(world_id: StringName) -> WorldReport:
	var report: WorldReport = reports.get(world_id)
	return report if report != null else WorldReport.new()


## True when the console of [param world_id] has been read.
func is_console_read(world_id: StringName) -> bool:
	return consoles_read.has(world_id)


## True when the horizon record of [param world_id] has been taken.
func is_horizon_record_taken(world_id: StringName) -> bool:
	return horizon_records.has(world_id)


## True while the pole camera is extending through the wormhole.
func is_pole_camera_out() -> bool:
	return not pole_camera_world_id.is_empty()


## Pulls the pole camera back in, with nothing taken.
func retract_pole_camera() -> void:
	pole_camera_world_id = &""
	pole_camera_ticks_left = 0


## Returns JSON-safe data for saving: the seed as a decimal string, statuses as lowercase
## names keyed by world id strings.
func to_dict() -> Dictionary:
	var status_data: Dictionary = {}
	for world_id: StringName in statuses:
		status_data[String(world_id)] = STATUS_NAMES[statuses[world_id]]
	return {
		"galaxy_seed": str(galaxy_seed),
		"generator_version": generator_version,
		"statuses": status_data,
		"consoles_read": _id_set_to_dict(consoles_read),
		"horizon_records": _id_set_to_dict(horizon_records),
		"reports": _reports_to_dict(),
		"targets": targets.to_dict(),
		"pole_camera_world_id": String(pole_camera_world_id),
		"pole_camera_ticks_left": pole_camera_ticks_left,
	}


## Builds a WorldsState from saved [param data]. The seed string is parsed exactly; a plain
## number is still accepted. Statuses that are unknown or unreadable are dropped. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> WorldsState:
	var worlds := WorldsState.new()
	worlds.galaxy_seed = _to_int64(data.get("galaxy_seed", 0))
	worlds.generator_version = type_convert(data.get("generator_version", 0), TYPE_INT)
	worlds.consoles_read = _id_set_from(data.get("consoles_read"))
	worlds.horizon_records = _id_set_from(data.get("horizon_records"))
	worlds.reports = _reports_from(data.get("reports"))
	var target_data: Variant = data.get("targets", {})
	if target_data is Dictionary:
		var target_dict: Dictionary = target_data
		worlds.targets = TargetStates.from_dict(target_dict)
	worlds.pole_camera_world_id = StringName(str(data.get("pole_camera_world_id", "")))
	worlds.pole_camera_ticks_left = type_convert(data.get("pole_camera_ticks_left", 0), TYPE_INT)
	var status_data: Variant = data.get("statuses", {})
	if not status_data is Dictionary:
		return worlds
	var status_dict: Dictionary = status_data
	for world_id: Variant in status_dict:
		var status := STATUS_NAMES.find(str(status_dict[world_id]))
		if status > WorldStatus.UNKNOWN:
			worlds.statuses[StringName(str(world_id))] = status as WorldStatus
	return worlds


## Returns human-readable errors for saved [param data], empty when it is valid:
## "galaxy_seed" a 64-bit integer written as a canonical decimal string; "generator_version"
## a whole number from 0 to 2^53; "statuses" an object mapping non-empty world ids to a
## status name other than "unknown"; "reports" an object mapping non-empty world ids to valid
## WorldReport data; "targets" valid TargetStates data; "consoles_read" and
## "horizon_records" objects mapping non-empty world ids to true; "pole_camera_world_id" a
## string and "pole_camera_ticks_left" a
## whole number from 0 to 2^53, both set or both unset ("" and 0).
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("galaxy_seed"):
		errors.append("missing 'galaxy_seed'")
	elif not _is_int64_string(data["galaxy_seed"]):
		errors.append("'galaxy_seed' is not a 64-bit integer string")
	if not data.has("generator_version"):
		errors.append("missing 'generator_version'")
	elif not _is_count(data["generator_version"]):
		errors.append("'generator_version' is not a whole number from 0 to 2^53")
	if not data.has("statuses"):
		errors.append("missing 'statuses'")
	elif not data["statuses"] is Dictionary:
		errors.append("'statuses' is not an object")
	else:
		var status_dict: Dictionary = data["statuses"]
		errors.append_array(_validate_statuses(status_dict))
	errors.append_array(_validate_id_set(data, "consoles_read"))
	errors.append_array(_validate_id_set(data, "horizon_records"))
	errors.append_array(_validate_reports(data))
	if not data.has("targets"):
		errors.append("missing 'targets'")
	elif not data["targets"] is Dictionary:
		errors.append("'targets' is not an object")
	else:
		var target_data: Dictionary = data["targets"]
		errors.append_array(TargetStates.validate_dict(target_data))
	errors.append_array(_validate_pole_camera(data))
	return errors


## Errors for "reports" of [param data].
static func _validate_reports(data: Dictionary) -> Array[String]:
	if not data.has("reports"):
		return ["missing 'reports'"]
	if not data["reports"] is Dictionary:
		return ["'reports' is not an object"]
	var errors: Array[String] = []
	var report_dict: Dictionary = data["reports"]
	for world_id: Variant in report_dict:
		if str(world_id).is_empty():
			errors.append("'reports' has an empty world id")
		elif not report_dict[world_id] is Dictionary:
			errors.append("report of '%s' is not an object" % world_id)
		else:
			var report_data: Dictionary = report_dict[world_id]
			errors.append_array(WorldReport.validate_dict(str(world_id), report_data))
	return errors


## Returns the reports with at least one known fact as JSON-safe data.
func _reports_to_dict() -> Dictionary:
	var data: Dictionary = {}
	for world_id: StringName in reports:
		var report_data: Dictionary = reports[world_id].to_dict()
		if not report_data.is_empty():
			data[String(world_id)] = report_data
	return data


## Returns the reports in [param value] when it is a Dictionary; unreadable ones are dropped.
static func _reports_from(value: Variant) -> Dictionary[StringName, WorldReport]:
	var result: Dictionary[StringName, WorldReport] = {}
	if not value is Dictionary:
		return result
	var report_dict: Dictionary = value
	for world_id: Variant in report_dict:
		if report_dict[world_id] is Dictionary:
			var report_data: Dictionary = report_dict[world_id]
			result[StringName(str(world_id))] = WorldReport.from_dict(report_data)
	return result


## Errors for the set of world ids at [param key] of [param data]: an object mapping non-empty
## world ids to true.
static func _validate_id_set(data: Dictionary, key: String) -> Array[String]:
	if not data.has(key):
		return ["missing '%s'" % key]
	if not data[key] is Dictionary:
		return ["'%s' is not an object" % key]
	var errors: Array[String] = []
	var id_dict: Dictionary = data[key]
	for world_id: Variant in id_dict:
		if str(world_id).is_empty():
			errors.append("'%s' has an empty world id" % key)
		elif not _is_true(id_dict[world_id]):
			errors.append("%s of '%s' is not true" % [key, world_id])
	return errors


## Errors for the pole camera fields of [param data].
static func _validate_pole_camera(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["pole_camera_world_id", "pole_camera_ticks_left"]:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	if not errors.is_empty():
		return errors
	var world_id: Variant = data["pole_camera_world_id"]
	var ticks_left: Variant = data["pole_camera_ticks_left"]
	if not world_id is String:
		errors.append("'pole_camera_world_id' is not a string")
	if not _is_count(ticks_left):
		errors.append("'pole_camera_ticks_left' is not a whole number from 0 to 2^53")
	if not errors.is_empty():
		return errors
	var is_out: bool = not str(world_id).is_empty()
	var ticks: float = ticks_left
	if is_out != (ticks > 0.0):
		errors.append("'pole_camera_world_id' and 'pole_camera_ticks_left' are not both set")
	return errors


## Errors for each entry of [param status_dict].
static func _validate_statuses(status_dict: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for world_id: Variant in status_dict:
		var status: Variant = status_dict[world_id]
		if str(world_id).is_empty():
			errors.append("a status has an empty world id")
		elif not status is String or STATUS_NAMES.find(status) <= WorldStatus.UNKNOWN:
			errors.append("status of '%s' is not one of %s" % [world_id, STATUS_NAMES.slice(1)])
	return errors


## Returns the ids of [param ids] as a JSON-safe {world id: true} object.
static func _id_set_to_dict(ids: Dictionary[StringName, bool]) -> Dictionary:
	var data: Dictionary = {}
	for world_id: StringName in ids:
		data[String(world_id)] = true
	return data


## Returns the ids mapped to true in [param value] when it is a Dictionary; others are dropped.
static func _id_set_from(value: Variant) -> Dictionary[StringName, bool]:
	var ids: Dictionary[StringName, bool] = {}
	if not value is Dictionary:
		return ids
	var id_dict: Dictionary = value
	for world_id: Variant in id_dict:
		if _is_true(id_dict[world_id]):
			ids[StringName(str(world_id))] = true
	return ids


## True only for the bool true.
static func _is_true(value: Variant) -> bool:
	return value is bool and value


## True when [param value] is a String that round-trips exactly through a 64-bit int, so
## out-of-range numbers, signs like "+1", leading zeros and spaces are rejected. Same rule
## as RandomState's seed strings.
static func _is_int64_string(value: Variant) -> bool:
	if not value is String:
		return false
	var text: String = value
	return text.is_valid_int() and str(text.to_int()) == text


## True for an int, or a whole float, from 0 to 2^53.
static func _is_count(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0


static func _to_int64(value: Variant) -> int:
	if value is String:
		var text: String = value
		return text.to_int()
	return type_convert(value, TYPE_INT)
