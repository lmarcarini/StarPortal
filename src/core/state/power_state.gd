class_name PowerState
extends RefCounted
## Saved state of the base's power: the capacitor bank's charge and size and the plant's
## output. An M1 placeholder; M2 replaces it with rooms.
## Saved shape: {"stored_mwh", "capacity_mwh", "plant_output_mw"}, all floats.
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


## Returns JSON-safe data for saving. Floats are written as they are; SaveService writes
## them at full precision.
func to_dict() -> Dictionary:
	return {
		"stored_mwh": stored_mwh,
		"capacity_mwh": capacity_mwh,
		"plant_output_mw": plant_output_mw,
	}


## Builds a PowerState from saved [param data]. Missing values are 0.0. Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> PowerState:
	var power := PowerState.new()
	power.stored_mwh = type_convert(data.get("stored_mwh", 0.0), TYPE_FLOAT)
	power.capacity_mwh = type_convert(data.get("capacity_mwh", 0.0), TYPE_FLOAT)
	power.plant_output_mw = type_convert(data.get("plant_output_mw", 0.0), TYPE_FLOAT)
	return power


## Returns human-readable errors for saved [param data], empty when it is valid: every value
## a finite number of at least 0, and "stored_mwh" not above "capacity_mwh".
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["stored_mwh", "capacity_mwh", "plant_output_mw"]:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif not _is_energy(data[key]):
			errors.append("'%s' is not a finite number of at least 0" % key)
	if not errors.is_empty():
		return errors
	var stored: float = data["stored_mwh"]
	var capacity: float = data["capacity_mwh"]
	if stored > capacity:
		errors.append("'stored_mwh' is above 'capacity_mwh'")
	return errors


## True for a finite int or float of at least 0.
static func _is_energy(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = value
	return is_finite(number) and number >= 0.0
