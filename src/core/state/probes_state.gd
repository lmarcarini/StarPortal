class_name ProbesState
extends RefCounted
## Saved state of the probes: the sample canister out through the wormhole, the MOTH run, the
## rack and its reorders, the probe photos taken and the worlds whose console the MOTH read
## deeper (the Ring scan).
## Saved shape: {"canister_world_id": world id or "", "canister_ticks_left", "moth": MothRun
## data or null, "rack", "reorders": [arrival ticks], "photos": [{"world_id", "kind": "sky" or
## "close_look", "target_id", "tick"}], "ring_scanned": {world id: true}}.
## The canister is out exactly when both its fields are set.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (Probes) and section 9 (saves)

## The world the canister was thrown into, or &"" while none is out.
var canister_world_id: StringName = &""
## Ticks until the canister is reeled back; 0 while none is out.
var canister_ticks_left: int = 0
## The MOTH out, or null.
var moth: MothRun = null
## MOTHs in the rack, ready to launch.
var rack: int = 0
## Arrival ticks of the replacements on order, earliest first.
var reorders: Array[int] = []
## Photo documents the probes took, oldest first: {"world_id", "kind", "target_id", "tick"}.
var photos: Array[Dictionary] = []
## Worlds whose console the MOTH Ring scan read; always true.
var ring_scanned: Dictionary[StringName, bool] = {}


## True while the canister is out.
func is_canister_out() -> bool:
	return not canister_world_id.is_empty()


## True while a MOTH is out.
func is_moth_out() -> bool:
	return moth != null


## Pulls the canister back with nothing taken (or after its result is recorded).
func clear_canister() -> void:
	canister_world_id = &""
	canister_ticks_left = 0


## Records a photo document of [param kind] ("sky" or "close_look") on [param world_id], of
## [param target_id] for a Close look, taken at [param tick].
func add_photo(world_id: StringName, kind: String, target_id: StringName, tick: int) -> void:
	photos.append(
		{"world_id": String(world_id), "kind": kind, "target_id": String(target_id), "tick": tick}
	)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	var ring_data: Dictionary = {}
	for world_id: StringName in ring_scanned:
		ring_data[String(world_id)] = true
	return {
		"canister_world_id": String(canister_world_id),
		"canister_ticks_left": canister_ticks_left,
		"moth": moth.to_dict() if moth != null else null,
		"rack": rack,
		"reorders": reorders.duplicate(),
		"photos": photos.duplicate(true),
		"ring_scanned": ring_data,
	}


## Builds the probes from saved [param data]. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> ProbesState:
	var probes := ProbesState.new()
	probes.canister_world_id = StringName(str(data.get("canister_world_id", "")))
	probes.canister_ticks_left = type_convert(data.get("canister_ticks_left", 0), TYPE_INT)
	var moth_data: Variant = data.get("moth")
	if moth_data is Dictionary:
		var moth_dict: Dictionary = moth_data
		probes.moth = MothRun.from_dict(moth_dict)
	probes.rack = type_convert(data.get("rack", MothRules.RACK_SIZE), TYPE_INT)
	for tick: Variant in _array_or_empty(data.get("reorders")):
		probes.reorders.append(type_convert(tick, TYPE_INT))
	for photo: Variant in _array_or_empty(data.get("photos")):
		if photo is Dictionary:
			var photo_dict: Dictionary = photo
			probes.photos.append(_photo_from(photo_dict))
	var ring_data: Variant = data.get("ring_scanned", {})
	if ring_data is Dictionary:
		var ring_dict: Dictionary = ring_data
		for world_id: Variant in ring_dict:
			probes.ring_scanned[StringName(str(world_id))] = true
	return probes


## Errors for saved [param data], empty when valid (ProbesSaveChecks).
static func validate_dict(data: Dictionary) -> Array[String]:
	return ProbesSaveChecks.errors(data)


static func _photo_from(data: Dictionary) -> Dictionary:
	return {
		"world_id": str(data.get("world_id", "")),
		"kind": str(data.get("kind", "")),
		"target_id": str(data.get("target_id", "")),
		"tick": type_convert(data.get("tick", 0), TYPE_INT),
	}


static func _array_or_empty(value: Variant) -> Array:
	if value is Array:
		var array: Array = value
		return array
	return []
