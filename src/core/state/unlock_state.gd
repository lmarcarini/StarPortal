class_name UnlockState
extends RefCounted
## Saved state of what research has opened up (docs/content/m25-lean-start.md sections 1-3):
## the room defs the player may build, the deepest level that may be dug, how many Capacitor
## Banks the base may hold and upkeep overrides by room def. Only UnlockRules.apply() changes
## it after a new game; UnlockRules.can_build_room() and can_dig() read it.
## Saved shape: {"rooms": [def id...], "dig_depth": whole number, "bank_cap": whole number,
## "upkeep_overrides": {def id: whole $k}}.
## Bible: docs/content/m25-lean-start.md sections 1-3 and 7, technical-architecture.md#data-model

## Saved keys, in to_dict() order.
const _KEYS: Array[String] = ["rooms", "dig_depth", "bank_cap", "upkeep_overrides"]

## Room def ids the player may build, in the order they were unlocked; no duplicates.
var rooms: Array[StringName] = []
## Deepest level number that may exist: a dig is allowed while the base has fewer levels.
## Starts at BalanceConfig.starting_levels (no dig).
var dig_depth: int = 1
## Most Capacitor Banks (built, building or a site) the base may hold.
var bank_cap: int = 1
## Upkeep per 30 days in $k that replaces a RoomDef's upkeep_k, by room def id (Fuel contracts).
var upkeep_overrides: Dictionary[StringName, int] = {}


## Returns a new game's unlocks for [param balance]: its starting room unlocks, digging down
## to its starting levels only (no dig) and its starting bank cap; no upkeep override.
static func starting(balance: BalanceConfig) -> UnlockState:
	var unlocks := UnlockState.new()
	for def_id: StringName in balance.starting_room_unlocks:
		if not def_id in unlocks.rooms:
			unlocks.rooms.append(def_id)
	unlocks.dig_depth = balance.starting_levels
	unlocks.bank_cap = balance.max_capacitor_banks
	return unlocks


## True when the player may build [param def_id].
func has_room(def_id: StringName) -> bool:
	return def_id in rooms


## Returns JSON-safe data for saving.
func to_dict() -> Dictionary:
	var room_data: Array = []
	for def_id: StringName in rooms:
		room_data.append(String(def_id))
	var overrides: Dictionary = {}
	for def_id: StringName in upkeep_overrides:
		overrides[String(def_id)] = upkeep_overrides[def_id]
	return {
		"rooms": room_data,
		"dig_depth": dig_depth,
		"bank_cap": bank_cap,
		"upkeep_overrides": overrides,
	}


## Builds an UnlockState from saved [param data] (whole floats become ints). Unreadable
## entries are skipped. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> UnlockState:
	var unlocks := UnlockState.new()
	var room_data: Variant = data.get("rooms")
	if room_data is Array:
		var entries: Array = room_data
		for entry: Variant in entries:
			var def_id := StringName(str(entry))
			if entry is String and not def_id in unlocks.rooms:
				unlocks.rooms.append(def_id)
	unlocks.dig_depth = maxi(1, RoomState.read_count(data.get("dig_depth")))
	unlocks.bank_cap = RoomState.read_count(data.get("bank_cap"))
	var overrides: Variant = data.get("upkeep_overrides")
	if overrides is Dictionary:
		var override_data: Dictionary = overrides
		for key: Variant in override_data:
			if RoomState.is_count(override_data[key]):
				unlocks.upkeep_overrides[StringName(str(key))] = RoomState.read_count(
					override_data[key]
				)
	return unlocks


## Returns human-readable errors for saved [param data], empty when it is valid: every key
## present; "rooms" an array of distinct non-empty strings; "dig_depth" a whole number of at
## least 1; "bank_cap" a whole number of at least 0; "upkeep_overrides" an object whose values
## are whole numbers of at least 0.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in _KEYS:
		if not data.has(key):
			errors.append("missing '%s'" % key)
	if not errors.is_empty():
		return errors
	errors.append_array(_room_errors(data["rooms"]))
	if not (RoomState.is_count(data["dig_depth"]) and data["dig_depth"] >= 1):
		errors.append("'dig_depth' is not a whole number of at least 1")
	if not RoomState.is_count(data["bank_cap"]):
		errors.append("'bank_cap' is not a whole number of at least 0")
	if not data["upkeep_overrides"] is Dictionary:
		errors.append("'upkeep_overrides' is not an object")
		return errors
	var overrides: Dictionary = data["upkeep_overrides"]
	for key: Variant in overrides:
		if not RoomState.is_count(overrides[key]):
			errors.append("'upkeep_overrides.%s' is not a whole number of at least 0" % str(key))
	return errors


static func _room_errors(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Array:
		errors.append("'rooms' is not an array")
		return errors
	var entries: Array = value
	var seen: Dictionary[String, bool] = {}
	for index: int in entries.size():
		var entry: Variant = entries[index]
		if not (entry is String and not str(entry).is_empty()):
			errors.append("rooms %d is not a non-empty string" % index)
		elif seen.has(entry):
			errors.append("rooms %d: duplicate '%s'" % [index, entry])
		else:
			seen[entry] = true
	return errors
