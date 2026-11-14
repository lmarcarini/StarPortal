class_name TimeControl
extends RefCounted
## Pure rules of the time-control state machine over a ClockState: player pause, resume
## and toggle requests, and named system holds. Mutates only the ClockState passed in;
## never touches autoloads or Nodes. Writes [member ClockState.mode], never
## [member ClockState.is_paused].
## [br][br]
## Holds stack: time stays HELD until the last reason is released, then returns to
## [member ClockState.mode_after_hold]. While HELD, pause/resume requests change only what
## the mode becomes when the hold ends, so a hold never undoes the player's pause.
## [br][br]
## In debug builds every mode change is printed (from, to, and the hold reason when a hold
## caused it). That print is the only side effect, and release builds skip it.
## Bible: technical-architecture.md#code-standards (State machines),
## game-design.md#time-real-time-with-pause

## Allowed transitions: each Mode maps to the Modes it may change to.
const ALLOWED: Dictionary = {
	ClockState.Mode.RUNNING: [ClockState.Mode.PAUSED, ClockState.Mode.HELD],
	ClockState.Mode.PAUSED: [ClockState.Mode.RUNNING, ClockState.Mode.HELD],
	ClockState.Mode.HELD: [ClockState.Mode.RUNNING, ClockState.Mode.PAUSED],
}

## Slow reasons the player may override with Faster (event-time.md section 2); the others
## (conversation, incursion) need the player's eyes.
const OVERRIDABLE: Array[StringName] = [&"dialling", &"gate_ops", &"awaiting_answer"]
## Every slow reason.
const SLOW_REASONS: Array[StringName] = [
	&"dialling", &"gate_ops", &"conversation", &"awaiting_answer", &"incursion"
]


## True when the table allows changing from [param from] to [param to]. Staying in the
## same mode is not a transition.
static func can_transition(from: ClockState.Mode, to: ClockState.Mode) -> bool:
	var targets: Array = ALLOWED.get(from, [])
	return targets.has(to)


## Player or auto pause. RUNNING becomes PAUSED; while HELD, the clock will be PAUSED when
## the hold ends. Returns true if anything changed.
static func request_pause(clock: ClockState) -> bool:
	return _request(clock, ClockState.Mode.PAUSED)


## Player resume. PAUSED becomes RUNNING; while HELD, the clock will be RUNNING when the
## hold ends. Returns true if anything changed.
static func request_resume(clock: ClockState) -> bool:
	return _request(clock, ClockState.Mode.RUNNING)


## Player pause/resume toggle: resumes a paused clock, pauses a running one, and while HELD
## flips what the mode becomes when the hold ends. Returns true if anything changed.
static func request_toggle(clock: ClockState) -> bool:
	var effective: ClockState.Mode = clock.mode
	if clock.mode == ClockState.Mode.HELD:
		effective = clock.mode_after_hold
	if effective == ClockState.Mode.RUNNING:
		return request_pause(clock)
	return request_resume(clock)


## Adds hold [param reason]. The first hold moves the clock to HELD and remembers the mode
## to return to. Adding a reason already held, or an empty reason, is a no-op returning
## false.
static func add_hold(clock: ClockState, reason: StringName) -> bool:
	if reason.is_empty() or clock.holds.has(reason):
		return false
	clock.holds.append(reason)
	if clock.mode != ClockState.Mode.HELD:
		clock.mode_after_hold = clock.mode
		_transition(clock, ClockState.Mode.HELD, reason)
	return true


## Releases hold [param reason]. Releasing the last hold returns the clock to
## [member ClockState.mode_after_hold]. Releasing a reason that is not held is a no-op
## returning false.
static func release_hold(clock: ClockState, reason: StringName) -> bool:
	if not clock.holds.has(reason):
		return false
	clock.holds.erase(reason)
	if clock.holds.is_empty() and clock.mode == ClockState.Mode.HELD:
		_transition(clock, clock.mode_after_hold, reason)
	return true


## Applies a player request for [param wanted] (RUNNING or PAUSED).
static func _request(clock: ClockState, wanted: ClockState.Mode) -> bool:
	if clock.mode == ClockState.Mode.HELD:
		if clock.mode_after_hold == wanted:
			return false
		clock.mode_after_hold = wanted
		return true
	if clock.mode == wanted:
		return false
	return _transition(clock, wanted)


## Changes [param clock] to [param to]. An illegal transition fails an assert in debug
## builds and is refused (returns false) in release builds. [param reason] is the hold that
## caused the change, empty for a player request; it is used only for the debug log.
static func _transition(clock: ClockState, to: ClockState.Mode, reason: StringName = &"") -> bool:
	var allowed: bool = can_transition(clock.mode, to)
	assert(
		allowed,
		(
			"TimeControl: illegal transition %s -> %s"
			% [ClockState.Mode.find_key(clock.mode), ClockState.Mode.find_key(to)]
		)
	)
	if not allowed:
		return false
	var from: ClockState.Mode = clock.mode
	clock.mode = to
	if OS.is_debug_build():
		_log_transition(from, to, reason)
	return true


## Prints one mode change; called only in debug builds. Plain print output, never a warning.
static func _log_transition(from: ClockState.Mode, to: ClockState.Mode, reason: StringName) -> void:
	var line := (
		"TimeControl: %s -> %s" % [ClockState.Mode.find_key(from), ClockState.Mode.find_key(to)]
	)
	if not reason.is_empty():
		var action: String = "added" if to == ClockState.Mode.HELD else "released"
		line += " (hold %s %s)" % [reason, action]
	print(line)


## The slow key of [param reason] from [param source]: "reason" or "reason/source".
static func slow_key(reason: StringName, source: StringName = &"") -> StringName:
	return reason if source.is_empty() else StringName("%s/%s" % [reason, source])


## The reason part of a slow [param key].
static func reason_of(key: StringName) -> StringName:
	return StringName(String(key).get_slice("/", 0))


## Adds the slow [param reason] from [param source]. A key already active, or overridden
## while its event goes on, adds nothing. Returns true when it changed the clock.
static func add_slow(clock: ClockState, reason: StringName, source: StringName = &"") -> bool:
	var key: StringName = slow_key(reason, source)
	if clock.slows.has(key) or clock.overridden.has(key):
		return false
	clock.slows.append(key)
	return true


## Releases the slow [param reason] from [param source] (its event ended), and forgets an
## override of it. Releasing one not held is a no-op. Returns true when slows changed.
static func release_slow(clock: ClockState, reason: StringName, source: StringName = &"") -> bool:
	var key: StringName = slow_key(reason, source)
	clock.overridden.erase(key)
	if not clock.slows.has(key):
		return false
	clock.slows.erase(key)
	return true


## True while any slow reason is active.
static func is_slowed(clock: ClockState) -> bool:
	return not clock.slows.is_empty()


## The speed the clock runs at: the cruise speed, or [param slow_index] while slowed when
## that is slower.
static func effective_speed_index(
	clock: ClockState, slow_index: int = ClockState.NORMAL_SPEED_INDEX
) -> int:
	if clock.slows.is_empty():
		return clock.speed_index
	return mini(clock.speed_index, slow_index)


## True when an active slow can be overridden ([param overridable] reasons).
static func can_override(clock: ClockState, overridable: Array[StringName] = OVERRIDABLE) -> bool:
	for key: StringName in clock.slows:
		if overridable.has(reason_of(key)):
			return true
	return false


## Releases every active [param overridable] slow and remembers it as overridden until its
## event ends. Returns true when anything changed.
static func override(clock: ClockState, overridable: Array[StringName] = OVERRIDABLE) -> bool:
	var changed: bool = false
	for key: StringName in clock.slows.duplicate():
		if overridable.has(reason_of(key)):
			clock.slows.erase(key)
			if not clock.overridden.has(key):
				clock.overridden.append(key)
			changed = true
	return changed
