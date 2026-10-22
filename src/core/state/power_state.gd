class_name PowerState
extends RefCounted
## Saved state of the base's power: the capacitor bank's charge and size and the plant's
## output. An M1 placeholder; M2 replaces it with rooms.
## Saved shape: {"stored_mwh", "capacity_mwh", "plant_output_mw"}, each an ExactFloat string
## (16 hex digits of the IEEE-754 pattern), so values load back bit for bit.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy (starting plant and storage),
## technical-architecture.md#data-model

## Energy held in the capacitors, in MWh; never above [member capacity_mwh].
var stored_mwh: float = 0.0
## Capacitor storage, in MWh.
var capacity_mwh: float = 0.0
## Plant output, in MW.
var plant_output_mw: float = 0.0


## Returns the campaign's starting power: capacity and plant output from [param balance],
## nothing stored yet.
static func starting(balance: BalanceConfig) -> PowerState:
	var power := PowerState.new()
	power.capacity_mwh = balance.starting_capacity_mwh
	power.plant_output_mw = balance.starting_plant_output_mw
	return power


## Returns JSON-safe data for saving; every value is ExactFloat.encode()d.
func to_dict() -> Dictionary:
	return {
		"stored_mwh": ExactFloat.encode(stored_mwh),
		"capacity_mwh": ExactFloat.encode(capacity_mwh),
		"plant_output_mw": ExactFloat.encode(plant_output_mw),
	}


## Builds a PowerState from saved [param data]. Missing or unencoded values are 0.0. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> PowerState:
	var power := PowerState.new()
	power.stored_mwh = _read_float(data.get("stored_mwh"))
	power.capacity_mwh = _read_float(data.get("capacity_mwh"))
	power.plant_output_mw = _read_float(data.get("plant_output_mw"))
	return power


## Returns human-readable errors for saved [param data], empty when it is valid: every value
## an ExactFloat string of a finite number of at least 0, and "stored_mwh" not above
## "capacity_mwh".
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["stored_mwh", "capacity_mwh", "plant_output_mw"]:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif not ExactFloat.is_finite_non_negative(data[key]):
			errors.append("'%s' is not an exact float, finite and at least 0" % key)
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
