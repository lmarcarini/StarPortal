class_name ProbesSaveChecks
extends RefCounted
## Validation of saved ProbesState data. Pure static.
## Bible: docs/content/m3-beyond-the-ring.md section 9 (saves)

## Photo kinds a save may hold.
const PHOTO_KINDS: Array[String] = ["sky", "close_look"]


## Errors for saved probes [param data], empty when valid: the canister's two fields both set
## (a world id and 1 to CANISTER_TICKS ticks) or both unset; "moth" null or valid MothRun data;
## "rack" from 0 to RACK_SIZE and, with the drone out and the reorders, exactly RACK_SIZE
## drones; "reorders" whole ticks; "photos" objects with a world id, a kind, a target
## id string and a tick; "ring_scanned" an object of world ids mapped to true.
static func errors(data: Dictionary) -> Array[String]:
	var found: Array[String] = []
	found.append_array(_canister_errors(data))
	var moth_data: Variant = data.get("moth")
	if moth_data is Dictionary:
		var moth_dict: Dictionary = moth_data
		found.append_array(MothRun.validate_dict(moth_dict))
	elif moth_data != null:
		found.append("'moth' is not an object or null")
	found.append_array(_rack_errors(data, moth_data is Dictionary))
	found.append_array(_photo_errors(data.get("photos")))
	var ring_data: Variant = data.get("ring_scanned")
	if not ring_data is Dictionary:
		found.append("'ring_scanned' is not an object")
	else:
		var ring_dict: Dictionary = ring_data
		for world_id: Variant in ring_dict:
			if (
				str(world_id).is_empty()
				or not (ring_dict[world_id] is bool and ring_dict[world_id])
			):
				found.append(
					"'ring_scanned' entry '%s' is not a world id mapped to true" % world_id
				)
	return found


static func _canister_errors(data: Dictionary) -> Array[String]:
	var world: Variant = data.get("canister_world_id")
	var ticks: Variant = data.get("canister_ticks_left")
	if not world is String:
		return ["'canister_world_id' is not a string"]
	if not _is_count_up_to(ticks, MothRules.CANISTER_TICKS):
		return ["'canister_ticks_left' is not a whole number of canister ticks"]
	var tick_count: float = ticks
	if str(world).is_empty() != is_zero_approx(tick_count):
		return ["'canister_world_id' and 'canister_ticks_left' are not both set"]
	return []


static func _rack_errors(data: Dictionary, is_moth_out: bool) -> Array[String]:
	var found: Array[String] = []
	var rack: Variant = data.get("rack")
	var reorders: Variant = data.get("reorders")
	if not _is_count_up_to(rack, MothRules.RACK_SIZE):
		found.append("'rack' is not a whole number from 0 to %d" % MothRules.RACK_SIZE)
	if not reorders is Array:
		return found + ["'reorders' is not an array of ticks"]
	var reorder_list: Array = reorders
	if not reorder_list.all(func(tick: Variant) -> bool: return _is_count(tick)):
		found.append("'reorders' is not an array of ticks")
	if not found.is_empty():
		return found
	var rack_count: int = type_convert(rack, TYPE_INT)
	var total: int = rack_count + reorder_list.size() + (1 if is_moth_out else 0)
	if total != MothRules.RACK_SIZE:
		found.append("not exactly %d MOTHs in the rack, out and on order" % MothRules.RACK_SIZE)
	return found


static func _photo_errors(photos: Variant) -> Array[String]:
	if not photos is Array:
		return ["'photos' is not an array"]
	var found: Array[String] = []
	var photo_list: Array = photos
	for index: int in photo_list.size():
		var photo: Variant = photo_list[index]
		if not photo is Dictionary:
			found.append("photo %d is not an object" % index)
			continue
		var entry: Dictionary = photo
		var is_valid: bool = (
			entry.get("world_id") is String
			and not str(entry["world_id"]).is_empty()
			and PHOTO_KINDS.has(entry.get("kind"))
			and entry.get("target_id") is String
			and _is_count(entry.get("tick"))
		)
		if not is_valid:
			found.append("photo %d is not a world id, kind, target id and tick" % index)
	return found


static func _is_count_up_to(value: Variant, high: int) -> bool:
	if not _is_count(value):
		return false
	var number: float = value
	return number <= high


static func _is_count(value: Variant) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= 0.0
