class_name MothRun
extends RefCounted
## Saved state of the MOTH out through the wormhole: the world, the battery left, the scan
## running (if any) and the scans finished on this run. A drone that is not out has no run.
## Saved shape: {"world_id", "battery_left", "scan": scan name or "", "target_id",
## "scan_ticks_left", "done": [scan keys]}.
## Bible: docs/content/m3-beyond-the-ring.md section 2 (MOTH)

## The world the drone is on.
var world_id: StringName = &""
## Battery minutes left.
var battery_left: int = MothRules.BATTERY_MINUTES
## The scan running, or -1 while the drone waits for an order.
var scan: int = -1
## The target of a running Close look; &"" otherwise.
var target_id: StringName = &""
## Ticks until the running scan finishes; 0 while none runs.
var scan_ticks_left: int = 0
## Keys of the scans finished on this run (scan_key()), in order.
var done: Array[String] = []


## Returns a fresh run on [param world] with a full battery.
static func create(world: StringName) -> MothRun:
	var run := MothRun.new()
	run.world_id = world
	return run


## The key a finished [param scan_value] of [param target] is kept under: the scan name, and
## for a Close look ":" and the target id.
static func scan_key(scan_value: MothRules.Scan, target: StringName = &"") -> String:
	var key: String = MothRules.SCAN_NAMES[scan_value]
	if scan_value == MothRules.Scan.CLOSE_LOOK:
		key += ":" + String(target)
	return key


## True while a scan runs.
func is_scanning() -> bool:
	return scan >= 0


## True when [param scan_value] of [param target] finished on this run.
func has_done(scan_value: MothRules.Scan, target: StringName = &"") -> bool:
	return done.has(scan_key(scan_value, target))


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {
		"world_id": String(world_id),
		"battery_left": battery_left,
		"scan": MothRules.SCAN_NAMES[scan] if is_scanning() else "",
		"target_id": String(target_id),
		"scan_ticks_left": scan_ticks_left,
		"done": done.duplicate(),
	}


## Builds a run from saved [param data]. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> MothRun:
	var run := MothRun.new()
	run.world_id = StringName(str(data.get("world_id", "")))
	run.battery_left = type_convert(data.get("battery_left", 0), TYPE_INT)
	run.scan = MothRules.SCAN_NAMES.find(str(data.get("scan", "")))
	run.target_id = StringName(str(data.get("target_id", "")))
	run.scan_ticks_left = type_convert(data.get("scan_ticks_left", 0), TYPE_INT)
	var done_data: Variant = data.get("done", [])
	if done_data is Array:
		for key: Variant in done_data:
			run.done.append(str(key))
	return run


## Errors for saved [param data], empty when valid: a non-empty "world_id", "battery_left"
## from 0 to a full battery, "scan" a scan name or "", "target_id" a string, "scan_ticks_left"
## from 1 to the scan's minutes while a scan runs and 0 otherwise, "done" an array of strings.
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.get("world_id") is String or str(data.get("world_id")).is_empty():
		errors.append("moth 'world_id' is not a non-empty string")
	if not _is_between(data.get("battery_left"), 0, MothRules.max_battery_minutes()):
		errors.append("moth 'battery_left' is not a whole number of battery minutes")
	var scan_data: Variant = data.get("scan")
	var scan_index: int = MothRules.SCAN_NAMES.find(str(scan_data))
	if not scan_data is String or (scan_index < 0 and str(scan_data) != ""):
		errors.append("moth 'scan' is not a scan name or \"\"")
	elif scan_index < 0 and not _is_between(data.get("scan_ticks_left"), 0, 0):
		errors.append("moth 'scan_ticks_left' is set with no scan running")
	elif (
		scan_index >= 0
		and not _is_between(data.get("scan_ticks_left"), 1, MothRules.SCAN_MINUTES[scan_index])
	):
		errors.append("moth 'scan_ticks_left' is not within the running scan's minutes")
	if not data.get("target_id") is String:
		errors.append("moth 'target_id' is not a string")
	if not _is_string_array(data.get("done")):
		errors.append("moth 'done' is not an array of strings")
	return errors


static func _is_string_array(value: Variant) -> bool:
	if not value is Array:
		return false
	var array: Array = value
	return array.all(func(key: Variant) -> bool: return key is String)


static func _is_between(value: Variant, low: int, high: int) -> bool:
	if not JsonLimits.is_exact_int(value):
		return false
	var number: float = value
	return number >= low and number <= high
