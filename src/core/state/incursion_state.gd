class_name IncursionState
extends RefCounted
## The incursion under way, if any (M4c), and when each faction last sent one.
## Saved shape: {"phase", "def_id", "countdown", "groups": [IntruderGroup], "last_day": {},
## "report": {}}.
## Bible: docs/content/m4c-incursions.md sections 1 and 9

## NONE: nothing under way; WARNING: the countdown; BREACH: intruders on base; RETREAT:
## they head back to the Ring.
enum Phase { NONE, WARNING, BREACH, RETREAT }

## Saved names of the phases, indexed by Phase value.
const PHASE_NAMES: Array[String] = ["none", "warning", "breach", "retreat"]
## Saved keys, in to_dict() order.
const KEYS: Array[String] = ["phase", "def_id", "countdown", "groups", "last_day"]

## Current phase.
var phase: Phase = Phase.NONE
## The IncursionDef under way, or &"".
var def_id: StringName = &""
## Ticks left in the warning.
var countdown: int = 0
## The groups on base.
var groups: Array[IntruderGroup] = []
## Day index of each faction's last incursion.
var last_day: Dictionary[StringName, int] = {}
## What happened so far, for the after-action report (JSON-safe): "damaged" room ids,
## "stolen" and "recovered" artefact uids, "injured" person ids, "done" when the
## objective was carried out. Optional when loading.
var report: Dictionary = {}


## True while an incursion is under way.
func is_active() -> bool:
	return phase != Phase.NONE


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var group_data: Array = []
	for group: IntruderGroup in groups:
		group_data.append(group.to_dict())
	return {
		"phase": StateNames.write(PHASE_NAMES, phase),
		"def_id": String(def_id),
		"countdown": countdown,
		"groups": group_data,
		"last_day": SaveFields.write_int_map(last_day),
		"report": report.duplicate(true),
	}


## Builds one from valid saved [param data].
static func from_dict(data: Dictionary) -> IncursionState:
	var state := IncursionState.new()
	state.phase = StateNames.read(PHASE_NAMES, data.get("phase")) as Phase
	state.def_id = StringName(str(data.get("def_id", "")))
	state.countdown = SaveFields.read_int(data.get("countdown"))
	for item: Dictionary in SaveFields.dicts_in(data.get("groups")):
		state.groups.append(IntruderGroup.from_dict(item))
	state.last_day = SaveFields.read_int_map(data.get("last_day"))
	state.report = SaveFields.dict_or_empty(data.get("report")).duplicate(true)
	return state


## Errors of saved [param data]; a phase other than none needs a def id.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = SaveFields.missing(data, KEYS)
	if not errors.is_empty():
		return errors
	if not StateNames.is_name(PHASE_NAMES, data["phase"]):
		errors.append("'phase' is not one of %s" % str(PHASE_NAMES))
	elif data["phase"] != "none" and not SaveFields.is_id(data["def_id"]):
		errors.append("'def_id' is empty while an incursion is under way")
	if not data["def_id"] is String:
		errors.append("'def_id' is not a String")
	if not (SaveFields.is_int(data["countdown"]) and data["countdown"] >= 0):
		errors.append("'countdown' is not a whole number of at least 0")
	errors.append_array(
		SaveFields.record_list_errors(data["groups"], "groups", IntruderGroup.validate_dict)
	)
	errors.append_array(SaveFields.int_map_errors(data["last_day"], "last_day", false))
	if data.has("report") and not data["report"] is Dictionary:
		errors.append("'report' is not an object")
	return errors
