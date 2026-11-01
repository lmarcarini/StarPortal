class_name PowerState
extends RefCounted
## Saved state of the Ring's capacitors: the energy they hold and each Capacitor Bank's charge
## rate. Supply, allocation and capacity are not saved: PowerRules derives them from the rooms.
## Saved shape: {"stored_mwh": ExactFloat string (16 hex digits of the IEEE-754 pattern, so it
## loads back bit for bit), "charge_rates": {bank room id: whole MW}}.
## Bible: docs/content/m2-base.md section 3, technical-architecture.md#data-model

## Energy held in the capacitors, in MWh; never above PowerRules.capacity_mwh().
var stored_mwh: float = 0.0
## Charge rate of each Capacitor Bank that has been completed, in whole MW, by room id.
## PowerSystem adds a bank when it is completed and drops it when it is gone.
var charge_rates: Dictionary[StringName, int] = {}


## Returns the campaign's starting power: nothing stored, no bank.
static func starting(_balance: BalanceConfig) -> PowerState:
	return PowerState.new()


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var rates: Dictionary = {}
	for room_id: StringName in charge_rates:
		rates[String(room_id)] = charge_rates[room_id]
	return {"stored_mwh": ExactFloat.encode(stored_mwh), "charge_rates": rates}


## Builds a PowerState from saved [param data], e.g. after a JSON round trip (whole floats
## become ints). Missing or unreadable values are 0 or skipped. Call validate_dict() first for
## untrusted data.
static func from_dict(data: Dictionary) -> PowerState:
	var power := PowerState.new()
	var stored: Variant = data.get("stored_mwh")
	if ExactFloat.is_encoded(stored):
		power.stored_mwh = ExactFloat.decode(str(stored))
	var rates: Variant = data.get("charge_rates")
	if rates is Dictionary:
		var rate_data: Dictionary = rates
		for key: Variant in rate_data:
			if RoomState.is_count(rate_data[key]):
				power.charge_rates[StringName(str(key))] = RoomState.read_count(rate_data[key])
	return power


## Returns human-readable errors for saved [param data], empty when it is valid: "stored_mwh"
## an ExactFloat string of a finite number of at least 0, and "charge_rates" an object whose
## values are whole numbers of at least 0. Capacity is checked against the rooms by GameState.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("stored_mwh"):
		errors.append("missing 'stored_mwh'")
	elif not ExactFloat.is_finite_non_negative(data["stored_mwh"]):
		errors.append("'stored_mwh' is not an exact float, finite and at least 0")
	var rates: Variant = data.get("charge_rates")
	if not rates is Dictionary:
		errors.append("'charge_rates' is not an object")
		return errors
	var rate_data: Dictionary = rates
	for key: Variant in rate_data:
		if not RoomState.is_count(rate_data[key]):
			errors.append("'charge_rates.%s' is not a whole number of at least 0" % str(key))
	return errors
