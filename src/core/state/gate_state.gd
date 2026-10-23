class_name GateState
extends RefCounted
## Saved state of CAIRN's Ring: its mode, the dial in progress or the open wormhole, and the
## Dial Log. The fields of the current dial are set only in the modes
## that have one; validate_dict() rejects any other combination.
## Saved shape: {"mode": "idle" | "dialing" | "locked", "current_address": address or null,
## "dial_started_tick", "lock_energy_mwh": ExactFloat string, "connected_world_id",
## "lock_started_tick",
## "is_hostile", "dial_log": [DialLogEntry]}. Unset ticks are -1.
## Bible: technical-architecture.md#data-model, technical-architecture.md#state-machines,
## gate-and-address-spec.md#dialing-outcomes-and-energy, gate-and-address-spec.md#player-tools

## Ring modes. IDLE: no dial. DIALING: seals engaging. LOCKED: wormhole open.
enum RingMode { IDLE, DIALING, LOCKED }

## Saved names of the modes, indexed by RingMode value.
const _MODE_NAMES: Array[String] = ["idle", "dialing", "locked"]
## Value of a tick field that is not set.
const _NO_TICK: int = -1
## Ring fields that are set exactly in the listed modes; unset otherwise.
const _SET_WHILE: Dictionary[String, Array] = {
	"current_address": ["dialing", "locked"],
	"dial_started_tick": ["dialing", "locked"],
	"connected_world_id": ["locked"],
	"lock_started_tick": ["locked"],
}

## Type rule of each scalar field: [check Callable(Variant) -> bool, what it must be].
## A static var, not a const: a Callable is not a constant expression.
static var _field_rules: Dictionary[String, Array] = {
	"mode": [_is_mode_name, "one of %s" % str(_MODE_NAMES)],
	"current_address": [_is_address_or_null, "null or an object"],
	"dial_started_tick": [_is_tick_or_unset, "-1 or a whole number from 0 to 2^53"],
	"lock_energy_mwh": [ExactFloat.is_finite_non_negative, "an exact float, finite and at least 0"],
	"connected_world_id": [_is_string, "a string"],
	"lock_started_tick": [_is_tick_or_unset, "-1 or a whole number from 0 to 2^53"],
	"is_hostile": [_is_bool, "a bool"],
}

## Current mode of the Ring.
var mode: RingMode = RingMode.IDLE
## The address being dialed or connected; set while DIALING or LOCKED.
var current_address: GateAddress = null
## Tick the current dial started; set while DIALING or LOCKED.
var dial_started_tick: int = -1
## Lock energy of the current dial, in MWh.
var lock_energy_mwh: float = 0.0
## The world at the far side; set while LOCKED.
var connected_world_id: StringName = &""
## Tick the wormhole opened; set while LOCKED.
var lock_started_tick: int = -1
## While LOCKED: true when the lock was a hostile lock.
var is_hostile: bool = false
## Every dial attempt, oldest first.
var dial_log: Array[DialLogEntry] = []


## Returns JSON-safe data for saving. The mode is a lowercase name; a missing address is null.
func to_dict() -> Dictionary:
	var log_data: Array[Dictionary] = []
	for entry: DialLogEntry in dial_log:
		log_data.append(entry.to_dict())
	var address_data: Variant = current_address.to_dict() if current_address != null else null
	return {
		"mode": _MODE_NAMES[mode],
		"current_address": address_data,
		"dial_started_tick": dial_started_tick,
		"lock_energy_mwh": ExactFloat.encode(lock_energy_mwh),
		"connected_world_id": String(connected_world_id),
		"lock_started_tick": lock_started_tick,
		"is_hostile": is_hostile,
		"dial_log": log_data,
	}


## Builds a GateState from saved [param data]; JSON floats become ints where needed.
## Missing or unreadable values keep their defaults. Call validate_dict() first for
## untrusted data.
static func from_dict(data: Dictionary) -> GateState:
	var gate := GateState.new()
	var mode_index: int = _MODE_NAMES.find(str(data.get("mode", "")))
	gate.mode = maxi(mode_index, RingMode.IDLE) as RingMode
	var address_data: Variant = data.get("current_address")
	if address_data is Dictionary:
		var address_dict: Dictionary = address_data
		gate.current_address = GateAddress.from_dict(address_dict)
	gate.dial_started_tick = type_convert(data.get("dial_started_tick", _NO_TICK), TYPE_INT)
	var energy: Variant = data.get("lock_energy_mwh")
	if ExactFloat.is_encoded(energy):
		var energy_text: String = energy
		gate.lock_energy_mwh = ExactFloat.decode(energy_text)
	gate.connected_world_id = StringName(str(data.get("connected_world_id", "")))
	gate.lock_started_tick = type_convert(data.get("lock_started_tick", _NO_TICK), TYPE_INT)
	var hostile: Variant = data.get("is_hostile")
	if hostile is bool:
		gate.is_hostile = hostile
	for item: Dictionary in _dicts_in(data.get("dial_log")):
		gate.dial_log.append(DialLogEntry.from_dict(item))
	return gate


## Returns human-readable errors for saved [param data], empty when it is valid. Types:
## "mode" a mode name; "current_address" null or a valid address; both ticks -1 or a whole
## number from 0 to 2^53; "lock_energy_mwh" an ExactFloat string of a finite number of at
## least 0;
## "connected_world_id" a string; "is_hostile" a bool; "dial_log" an array of valid DialLogEntry objects. Then the Ring fields must
## fit the mode: IDLE has no address, ticks, world or hostility; DIALING has an address and
## a dial tick but no world, lock tick or hostility; LOCKED has all of them, and the lock
## tick is not before the dial tick.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors := _field_errors(data)
	errors.append_array(_list_errors(data, "dial_log", DialLogEntry.validate_dict))
	if not errors.is_empty():
		return errors
	return _mode_errors(data)


## Type errors of every field except the Dial Log.
static func _field_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _field_rules:
		if not data.has(key):
			errors.append("missing '%s'" % key)
			continue
		var rule: Array = _field_rules[key]
		var check: Callable = rule[0]
		var message: String = rule[1]
		if not check.call(data[key]):
			errors.append("'%s' is not %s" % [key, message])
	var address_data: Variant = data.get("current_address")
	if address_data is Dictionary:
		var address_dict: Dictionary = address_data
		for error: String in GateAddress.validate_dict(address_dict):
			errors.append("current_address: " + error)
	return errors


## Errors for the array at [param key]: each item must be an object that passes
## [param item_check], a Callable(Dictionary) -> Array[String].
static func _list_errors(data: Dictionary, key: String, item_check: Callable) -> Array[String]:
	if not data.has(key):
		return ["missing '%s'" % key]
	if not data[key] is Array:
		return ["'%s' is not an array" % key]
	var errors: Array[String] = []
	var list: Array = data[key]
	for index: int in list.size():
		if not list[index] is Dictionary:
			errors.append("%s %d is not an object" % [key, index])
			continue
		var item_errors: Array[String] = item_check.call(list[index])
		for error: String in item_errors:
			errors.append("%s %d: %s" % [key, index, error])
	return errors


## Errors where the Ring fields of type-checked [param data] do not fit its mode.
static func _mode_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var mode_name: String = data["mode"]
	for key: String in _SET_WHILE:
		var modes: Array = _SET_WHILE[key]
		var should_be_set: bool = modes.has(mode_name)
		var is_set: bool = _is_set(data[key])
		if should_be_set and not is_set:
			errors.append("'%s' is not set while \"%s\"" % [key, mode_name])
		elif is_set and not should_be_set:
			errors.append("'%s' is set while \"%s\"" % [key, mode_name])
	if data["is_hostile"] == true and mode_name != "locked":
		errors.append("'is_hostile' is true while \"%s\"" % mode_name)
	if errors.is_empty() and mode_name == "locked":
		var dial_tick: float = data["dial_started_tick"]
		var lock_tick: float = data["lock_started_tick"]
		if lock_tick < dial_tick:
			errors.append("'lock_started_tick' is before 'dial_started_tick'")
	return errors


## True when a Ring field holds a value: not null, not an unset tick, not an empty id.
static func _is_set(value: Variant) -> bool:
	if value == null:
		return false
	if value is String:
		return not str(value).is_empty()
	if value is int or value is float:
		var number: float = value
		return number != float(_NO_TICK)
	return true


static func _is_mode_name(value: Variant) -> bool:
	return value is String and _MODE_NAMES.has(value)


static func _is_address_or_null(value: Variant) -> bool:
	return value == null or value is Dictionary


## True for -1, or an int or whole float from 0 to 2^53.
static func _is_tick_or_unset(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= float(_NO_TICK)


static func _is_string(value: Variant) -> bool:
	return value is String


static func _is_bool(value: Variant) -> bool:
	return value is bool


## Returns the Dictionaries in [param value] when it is an Array; other items are skipped.
static func _dicts_in(value: Variant) -> Array[Dictionary]:
	var dicts: Array[Dictionary] = []
	if not value is Array:
		return dicts
	var list: Array = value
	for item: Variant in list:
		if item is Dictionary:
			dicts.append(item)
	return dicts
