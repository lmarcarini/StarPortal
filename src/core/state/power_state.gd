class_name PowerState
extends RefCounted
## Saved state of the base's power: the capacitors' charge and size, the plant's output, the
## capacitor banks installed and the install running. An M1 placeholder; M2 replaces it with
## rooms.
## Saved shape: {"stored_mwh", "capacity_mwh", "plant_output_mw"}, each an ExactFloat string
## (16 hex digits of the IEEE-754 pattern), so values load back bit for bit, and
## {"banks_installed", "install_ticks_left"}, whole numbers.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy (starting plant and storage),
## gate-and-address-spec.md#the-dial-console, technical-architecture.md#data-model

## Saved keys holding ExactFloat strings.
const _FLOAT_KEYS: Array[String] = ["stored_mwh", "capacity_mwh", "plant_output_mw"]
## Saved keys holding whole numbers of at least 0.
const _COUNT_KEYS: Array[String] = ["banks_installed", "install_ticks_left"]

## Energy held in the capacitors, in MWh; never above [member capacity_mwh].
var stored_mwh: float = 0.0
## Capacitor storage, in MWh.
var capacity_mwh: float = 0.0
## Plant output, in MW.
var plant_output_mw: float = 0.0
## Capacitor banks installed so far.
var banks_installed: int = 0
## Ticks until the capacitor bank being installed is ready; 0 when no install is running.
var install_ticks_left: int = 0


## Returns the campaign's starting power: capacity and plant output from [param balance],
## nothing stored yet, no bank installed and no install running.
static func starting(balance: BalanceConfig) -> PowerState:
	var power := PowerState.new()
	power.capacity_mwh = balance.starting_capacity_mwh
	power.plant_output_mw = balance.starting_plant_output_mw
	return power


## Returns JSON-safe data for saving; every float is ExactFloat.encode()d.
func to_dict() -> Dictionary:
	return {
		"stored_mwh": ExactFloat.encode(stored_mwh),
		"capacity_mwh": ExactFloat.encode(capacity_mwh),
		"plant_output_mw": ExactFloat.encode(plant_output_mw),
		"banks_installed": banks_installed,
		"install_ticks_left": install_ticks_left,
	}


## Builds a PowerState from saved [param data], e.g. after a JSON round trip (whole floats
## become ints). Missing or unreadable values are 0. Call validate_dict() first for untrusted
## data.
static func from_dict(data: Dictionary) -> PowerState:
	var power := PowerState.new()
	power.stored_mwh = _read_float(data.get("stored_mwh"))
	power.capacity_mwh = _read_float(data.get("capacity_mwh"))
	power.plant_output_mw = _read_float(data.get("plant_output_mw"))
	power.banks_installed = _read_count(data.get("banks_installed"))
	power.install_ticks_left = _read_count(data.get("install_ticks_left"))
	return power


## Returns human-readable errors for saved [param data], empty when it is valid: every float
## an ExactFloat string of a finite number of at least 0, "stored_mwh" not above
## "capacity_mwh", and "banks_installed" and "install_ticks_left" whole numbers from 0 to
## [constant JsonLimits.MAX_EXACT_INT].
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _FLOAT_KEYS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif not ExactFloat.is_finite_non_negative(data[key]):
			errors.append("'%s' is not an exact float, finite and at least 0" % key)
	for key: String in _COUNT_KEYS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif not _is_count(data[key]):
			errors.append("'%s' is not a whole number of at least 0" % key)
	if not errors.is_empty():
		return errors
	if _read_float(data["stored_mwh"]) > _read_float(data["capacity_mwh"]):
		errors.append("'stored_mwh' is above 'capacity_mwh'")
	return errors


## The float encoded in [param value], or 0.0 when it is not an ExactFloat string.
static func _read_float(value: Variant) -> float:
	if not ExactFloat.is_encoded(value):
		return 0.0
	var text: String = value
	return ExactFloat.decode(text)


## The whole number in [param value], or 0 when it is not a count.
static func _read_count(value: Variant) -> int:
	if not _is_count(value):
		return 0
	return type_convert(value, TYPE_INT)


## True for an int, or a whole float, from 0 to [constant JsonLimits.MAX_EXACT_INT].
static func _is_count(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0
