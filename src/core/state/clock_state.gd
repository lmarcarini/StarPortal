class_name ClockState
extends RefCounted
## Saved state of the simulation clock: the current tick, speed and time-control mode.
## The mode is an explicit state machine (RUNNING, PAUSED, HELD) whose rules live in
## TimeControl; holds are named system reasons that keep time stopped without touching the
## player's own pause.
## Bible: technical-architecture.md#data-model, technical-architecture.md#code-standards,
## game-design.md#time-real-time-with-pause

## Time-control modes. RUNNING advances ticks; PAUSED is the player's (or an auto) pause;
## HELD is a system hold that lasts until its last reason is released.
enum Mode { RUNNING, PAUSED, HELD }

## Number of clock speeds; must equal SimClock.SPEEDS.size().
const SPEED_COUNT: int = 4
## Saved names of the modes, indexed by Mode value.
const _MODE_NAMES: Array[String] = ["running", "paused", "held"]

## Ticks elapsed since the campaign start; one tick is one in-game minute.
var tick: int = 0
## Index into SimClock.SPEEDS.
var speed_index: int = 1
## Current time-control mode. Change it only through TimeControl.
var mode: Mode = Mode.PAUSED
## Active hold reasons, in the order they were added; non-empty exactly while HELD.
var holds: Array[StringName] = []
## Mode to return to when the last hold is released: RUNNING or PAUSED. Meaningful while
## HELD; player pause/resume requests during a hold change this instead of the mode.
var mode_after_hold: Mode = Mode.PAUSED
## True while time does not advance (mode is not RUNNING). Setting it is a player pause
## (true) or resume (false) request through TimeControl; it never clears a hold.
var is_paused: bool:
	get:
		return mode != Mode.RUNNING
	set(value):
		if value:
			TimeControl.request_pause(self)
		else:
			TimeControl.request_resume(self)


## Returns JSON-safe data for saving. Modes are lowercase strings; holds are strings.
func to_dict() -> Dictionary:
	var hold_names: Array[String] = []
	for reason: StringName in holds:
		hold_names.append(String(reason))
	return {
		"tick": tick,
		"speed_index": speed_index,
		"mode": _MODE_NAMES[mode],
		"holds": hold_names,
		"mode_after_hold": _MODE_NAMES[mode_after_hold],
	}


## Builds a ClockState from saved [param data]. Missing or unreadable keys keep their
## defaults; JSON floats are cast back to ints. Call validate_dict() first for untrusted data.
static func from_dict(data: Dictionary) -> ClockState:
	var clock := ClockState.new()
	clock.tick = type_convert(data.get("tick", clock.tick), TYPE_INT)
	var speed_index_data: Variant = data.get("speed_index", clock.speed_index)
	clock.speed_index = type_convert(speed_index_data, TYPE_INT)
	clock.mode = _read_mode(data.get("mode"), clock.mode)
	clock.mode_after_hold = _read_mode(data.get("mode_after_hold"), clock.mode_after_hold)
	var hold_data: Variant = data.get("holds", [])
	if hold_data is Array:
		var hold_list: Array = hold_data
		for reason: Variant in hold_list:
			clock.holds.append(StringName(str(reason)))
	return clock


## Returns human-readable errors for saved [param data], empty when it is valid: "tick" and
## "speed_index" must be whole numbers from 0 to 2^53 (JSON numbers are doubles), with
## speed_index below SPEED_COUNT; "mode" one of "running", "paused" or "held";
## "mode_after_hold" "running" or "paused"; "holds" an array of unique non-empty strings,
## non-empty exactly when the mode is "held".
static func validate_dict(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for key: String in ["tick", "speed_index"]:
		if not data.has(key):
			errors.append("missing '%s'" % key)
		elif not _is_count(data[key]):
			errors.append("'%s' is not a whole number from 0 to 2^53" % key)
	if _is_count(data.get("speed_index")):
		var speed_index_value: float = data["speed_index"]
		if speed_index_value >= SPEED_COUNT:
			errors.append("'speed_index' is not below %d" % SPEED_COUNT)
	errors.append_array(_validate_modes(data))
	errors.append_array(_validate_holds(data))
	return errors


## Errors for "mode" and "mode_after_hold".
static func _validate_modes(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("mode"):
		errors.append("missing 'mode'")
	elif not _is_mode_name(data["mode"]):
		errors.append("'mode' is not one of %s" % str(_MODE_NAMES))
	if not data.has("mode_after_hold"):
		errors.append("missing 'mode_after_hold'")
	elif not _is_mode_name(data["mode_after_hold"]) or data["mode_after_hold"] == "held":
		errors.append('\'mode_after_hold\' is not "running" or "paused"')
	return errors


## Errors for "holds", including its agreement with "mode".
static func _validate_holds(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not data.has("holds"):
		return ["missing 'holds'"]
	if not data["holds"] is Array:
		return ["'holds' is not an array"]
	var hold_list: Array = data["holds"]
	for index: int in hold_list.size():
		var reason: Variant = hold_list[index]
		if not reason is String or str(reason).is_empty():
			errors.append("hold %d is not a non-empty string" % index)
		elif hold_list.find(reason) != index:
			errors.append("hold '%s' is listed twice" % reason)
	var is_held: bool = data.get("mode") is String and data["mode"] == "held"
	if is_held and hold_list.is_empty():
		errors.append("'mode' is \"held\" but 'holds' is empty")
	elif _is_mode_name(data.get("mode")) and not is_held and not hold_list.is_empty():
		errors.append("'holds' is not empty but 'mode' is not \"held\"")
	return errors


## Returns the Mode saved as [param value], or [param fallback] when it is not a mode name.
static func _read_mode(value: Variant, fallback: Mode) -> Mode:
	if not _is_mode_name(value):
		return fallback
	return _MODE_NAMES.find(value) as Mode


## True for a String that names a mode.
static func _is_mode_name(value: Variant) -> bool:
	return value is String and _MODE_NAMES.has(value)


## True for an int, or a whole float, from 0 to 2^53. The value is compared as a float
## against the float of [constant JsonLimits.MAX_EXACT_INT], which is exact.
static func _is_count(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = value
	var limit: float = float(JsonLimits.MAX_EXACT_INT)
	return number == floorf(number) and number >= 0.0 and number <= limit
