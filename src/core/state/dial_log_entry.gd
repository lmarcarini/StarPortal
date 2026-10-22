class_name DialLogEntry
extends RefCounted
## One dial attempt in the Dial Log: when it ended, the address, the outcome and the energy
## it cost. The log keeps the true world id even when the player is not told it; views
## decide what to show.
## Saved shape: {"tick", "address": {"seals"}, "outcome": DialOutcome key, "energy_spent_mwh",
## "world_id"}.
## Bible: gate-and-address-spec.md#player-tools (Dial Log),
## technical-architecture.md#data-model

## Tick the dial resolved.
var tick: int
## The address dialed.
var address: GateAddress
## What the Ring reported.
var outcome: DialOutcome.Kind
## Energy the attempt spent, in MWh.
var energy_spent_mwh: float
## The world reached or blocked; empty for no gate.
var world_id: StringName = &""


## Returns JSON-safe data for saving. The outcome is its DialOutcome key, e.g. "no_gate".
func to_dict() -> Dictionary:
	var address_data: Variant = address.to_dict() if address != null else null
	return {
		"tick": tick,
		"address": address_data,
		"outcome": String(DialOutcome.to_key(outcome)),
		"energy_spent_mwh": energy_spent_mwh,
		"world_id": String(world_id),
	}


## Builds an entry from saved [param data]; JSON floats become ints where needed. Missing or
## unreadable values fall back to defaults (an unknown outcome reads as NO_GATE). Call
## validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> DialLogEntry:
	var entry := DialLogEntry.new()
	entry.tick = type_convert(data.get("tick", 0), TYPE_INT)
	var address_data: Variant = data.get("address")
	if address_data is Dictionary:
		var address_dict: Dictionary = address_data
		entry.address = GateAddress.from_dict(address_dict)
	var kind: int = DialOutcome.from_key(StringName(str(data.get("outcome", ""))))
	entry.outcome = maxi(kind, DialOutcome.Kind.NO_GATE) as DialOutcome.Kind
	entry.energy_spent_mwh = type_convert(data.get("energy_spent_mwh", 0.0), TYPE_FLOAT)
	entry.world_id = StringName(str(data.get("world_id", "")))
	return entry


## Returns human-readable errors for saved [param data], empty when it is valid: "tick" a
## whole number from 0 to 2^53; "address" a valid GateAddress object; "outcome" a
## DialOutcome key; "energy_spent_mwh" a finite number of at least 0; "world_id" a string,
## empty for "no_gate" and not empty for "blocked", "lock" and "hostile_lock".
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("tick"):
		errors.append("missing 'tick'")
	elif not _is_tick(data["tick"]):
		errors.append("'tick' is not a whole number from 0 to 2^53")
	if not data.has("address"):
		errors.append("missing 'address'")
	elif not data["address"] is Dictionary:
		errors.append("'address' is not an object")
	else:
		var address_data: Dictionary = data["address"]
		for error: String in GateAddress.validate_dict(address_data):
			errors.append("address: " + error)
	if not data.has("energy_spent_mwh"):
		errors.append("missing 'energy_spent_mwh'")
	elif not _is_energy(data["energy_spent_mwh"]):
		errors.append("'energy_spent_mwh' is not a finite number of at least 0")
	errors.append_array(_validate_outcome_and_world(data))
	return errors


## Errors for "outcome" and "world_id", including their agreement.
static func _validate_outcome_and_world(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var kind: int = -1
	if not data.has("outcome"):
		errors.append("missing 'outcome'")
	elif data["outcome"] is String:
		kind = DialOutcome.from_key(StringName(str(data["outcome"])))
	if data.has("outcome") and kind < 0:
		errors.append("'outcome' is not a dial outcome key")
	if not data.has("world_id"):
		errors.append("missing 'world_id'")
		return errors
	if not data["world_id"] is String:
		errors.append("'world_id' is not a string")
		return errors
	var has_world: bool = not str(data["world_id"]).is_empty()
	if kind == DialOutcome.Kind.NO_GATE and has_world:
		errors.append("'world_id' is not empty for a \"no_gate\" outcome")
	var needs_world: bool = (
		kind == DialOutcome.Kind.BLOCKED
		or kind == DialOutcome.Kind.LOCK
		or kind == DialOutcome.Kind.HOSTILE_LOCK
	)
	if needs_world and not has_world:
		errors.append("'world_id' is empty for a \"%s\" outcome" % data["outcome"])
	return errors


## True for an int, or a whole float, from 0 to 2^53.
static func _is_tick(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0


## True for a finite int or float of at least 0.
static func _is_energy(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = value
	return is_finite(number) and number >= 0.0
