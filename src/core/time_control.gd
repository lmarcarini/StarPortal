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
## Bible: technical-architecture.md#code-standards (State machines),
## game-design.md#time-real-time-with-pause

## Allowed transitions: each Mode maps to the Modes it may change to.
const ALLOWED: Dictionary = {
	ClockState.Mode.RUNNING: [ClockState.Mode.PAUSED, ClockState.Mode.HELD],
	ClockState.Mode.PAUSED: [ClockState.Mode.RUNNING, ClockState.Mode.HELD],
	ClockState.Mode.HELD: [ClockState.Mode.RUNNING, ClockState.Mode.PAUSED],
}


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
		_transition(clock, ClockState.Mode.HELD)
	return true


## Releases hold [param reason]. Releasing the last hold returns the clock to
## [member ClockState.mode_after_hold]. Releasing a reason that is not held is a no-op
## returning false.
static func release_hold(clock: ClockState, reason: StringName) -> bool:
	if not clock.holds.has(reason):
		return false
	clock.holds.erase(reason)
	if clock.holds.is_empty() and clock.mode == ClockState.Mode.HELD:
		_transition(clock, clock.mode_after_hold)
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
## builds and is refused (returns false) in release builds.
static func _transition(clock: ClockState, to: ClockState.Mode) -> bool:
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
	clock.mode = to
	return true
