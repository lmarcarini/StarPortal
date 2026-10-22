extends RefCounted
## Seeded stand-in player for the soak test. It sets random flags through SetFlagCommand
## about 20 times per in-game day, pauses and resumes the clock at random, and adds and
## releases named system holds through TimeControl (a dozen or so per month). It also works
## the Ring on every call with no command waiting: with the Ring idle and the queue empty it
## queues an address (mostly a random well-formed one whose seal 1 the bank can reach, a
## delivered target's true address sometimes); once the bank
## holds the front address's lock energy it dials it and unqueues it (an address the bank can
## never charge is just unqueued); and it closes any lock a few ticks after it opens. Every random
## draw comes from the run's own GameState stream &"soak_bot", so two runs from the same
## seed act identically, and a saved and reloaded state carries the stream on.
## Bible: technical-architecture.md#testing-and-tooling (Soak test)

## RandomState stream the bot draws from.
const STREAM_ID: StringName = &"soak_bot"
## Largest gap between two actions while running, in ticks. Gaps are uniform in
## 1..MAX_ACTION_GAP, a mean of 72 ticks: about 20 actions per 1440-tick day.
const MAX_ACTION_GAP: int = 143
## Chance that a running action pauses the clock instead of submitting a command.
const PAUSE_CHANCE: float = 0.1
## Chance, per paused action, that the bot resumes; otherwise it submits a command.
const RESUME_CHANCE: float = 0.4
## Chance that a running action adds a hold instead of submitting a command.
const HOLD_CHANCE: float = 0.02
## Chance, per paused (not held) action, that the bot adds a hold; checked after resume.
const PAUSED_HOLD_CHANCE: float = 0.05
## Chances, per held action, that the bot releases a hold, adds another one, or makes a
## player pause/resume request (which only sets the mode after the hold); otherwise it
## submits a command.
const RELEASE_CHANCE: float = 0.4
const EXTRA_HOLD_CHANCE: float = 0.1
const HELD_REQUEST_CHANCE: float = 0.15
## Hold reasons the bot uses.
const HOLD_REASONS: Array[StringName] = [&"soak_hold_a", &"soak_hold_b", &"soak_hold_c"]
## Number of distinct flag keys the bot writes: soak_flag_0 to soak_flag_<n - 1>.
const FLAG_KEY_COUNT: int = 16
## Largest magnitude of a random int flag value.
const MAX_INT_VALUE: int = 1000000
## Chance that a newly queued address is a delivered target's true address.
const TARGET_CHANCE: float = 0.2
## Ticks an open wormhole stays open before the bot closes it.
const CLOSE_AFTER_TICKS: int = 5

## Commands submitted so far, running and paused.
var commands_submitted: int = 0
## Commands submitted while the clock was paused (they apply at once).
var commands_while_paused: int = 0
## Times the bot paused the clock.
var pauses: int = 0
## Times the bot resumed the clock.
var resumes: int = 0
## Holds the bot added (duplicates, which are no-ops, not counted).
var holds_added: int = 0
## Holds the bot released.
var holds_released: int = 0
## Addresses the bot queued, of them true target addresses, and those it dropped unreachable.
var addresses_queued: int = 0
var targets_queued: int = 0
var addresses_dropped: int = 0
## Dials the bot started.
var dials: int = 0
## Wormholes the bot closed.
var closes: int = 0

var _next_action_tick: int = 0


## Acts once on [param simulation] before its next tick. While running, the bot waits for
## its next action tick, then submits a command, pauses or adds a hold. While paused or
## held, every call is an action: resume, release or add a hold, or submit a command that
## applies at once.
func act(simulation: Simulation) -> void:
	var clock: ClockState = simulation.state.clock
	var rng: RandomNumberGenerator = simulation.state.random.stream(STREAM_ID)
	if simulation.commands.pending_count() == 0:
		_work_ring(simulation, rng)
	if not clock.is_paused and clock.tick < _next_action_tick:
		return
	if clock.mode == ClockState.Mode.HELD:
		_act_held(simulation, rng)
		return
	if clock.is_paused:
		_act_paused(simulation, rng)
		return
	_next_action_tick = clock.tick + rng.randi_range(1, MAX_ACTION_GAP)
	var roll: float = rng.randf()
	if roll < PAUSE_CHANCE:
		clock.is_paused = true
		pauses += 1
		return
	if roll < PAUSE_CHANCE + HOLD_CHANCE:
		_add_random_hold(clock, rng)
		return
	_submit_random_flag(simulation, rng)


## Closes a lock open CLOSE_AFTER_TICKS, or, with the Ring idle, queues, drops or dials.
func _work_ring(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var state: GameState = simulation.state
	var gate: GateState = state.gate
	if gate.mode == GateState.RingMode.LOCKED:
		if state.clock.tick - gate.lock_started_tick >= CLOSE_AFTER_TICKS:
			simulation.submit(CloseWormholeCommand.new())
			closes += 1
		return
	if gate.mode != GateState.RingMode.IDLE:
		return
	if gate.dial_queue.is_empty():
		_queue_address(simulation, rng)
		return
	var front: GateAddress = gate.dial_queue[0]
	var ready_in: int = GateQueries.ticks_until_ready(state, front)
	if ready_in < 0:
		simulation.submit(UnqueueAddressCommand.create(front))
		addresses_dropped += 1
	elif ready_in == 0:
		simulation.submit(DialCommand.create(front))
		simulation.submit(UnqueueAddressCommand.create(front))
		dials += 1


func _queue_address(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var state: GameState = simulation.state
	var origin: int = state.galaxy.home().origin_glyph
	var targets: Array[StringName] = _delivered_targets(state.intel)
	var address: GateAddress = null
	if not targets.is_empty() and rng.randf() < TARGET_CHANCE:
		var target: StringName = targets[rng.randi_range(0, targets.size() - 1)]
		address = state.galaxy.address_of(target, origin)
		targets_queued += 1
	else:
		address = random_address(rng, origin, _reachable_first_glyphs(state))
	simulation.submit(QueueAddressCommand.create(address))
	addresses_queued += 1


## Distinct target worlds of the clues delivered so far, in arrival order. The bot cheats on
## purpose: it plays the soak, not the puzzle.
static func _delivered_targets(intel: IntelState) -> Array[StringName]:
	var targets: Array[StringName] = []
	for clue: ClueRecord in intel.clues:
		if not targets.has(clue.target_world_id):
			targets.append(clue.target_world_id)
	return targets


## Glyphs other than the home origin whose anchor, as seal 1, needs no more lock energy than
## the bank can hold. Lock energy depends on seal 1 only.
static func _reachable_first_glyphs(state: GameState) -> Array[int]:
	var origin: int = state.galaxy.home().origin_glyph
	var others: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != origin:
			others.append(glyph)
	var reachable: Array[int] = []
	for glyph: int in others:
		var coordinates: Array[int] = [glyph]
		for other: int in others:
			if other != glyph and coordinates.size() < GateAddress.COORDINATE_COUNT:
				coordinates.append(other)
		var probe := GateAddress.create(coordinates, origin)
		if GateQueries.lock_energy_mwh(state, probe) <= state.power.capacity_mwh:
			reachable.append(glyph)
	return reachable


## A random well-formed address: seven distinct glyphs other than [param origin], then it.
## Seal 1 is drawn from [param first_glyphs] when that is not empty.
static func random_address(
	rng: RandomNumberGenerator, origin: int, first_glyphs: Array[int]
) -> GateAddress:
	var glyphs: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != origin:
			glyphs.append(glyph)
	var coordinates: Array[int] = []
	if not first_glyphs.is_empty():
		var first: int = first_glyphs[rng.randi_range(0, first_glyphs.size() - 1)]
		coordinates.append(first)
		glyphs.erase(first)
	while coordinates.size() < GateAddress.COORDINATE_COUNT:
		coordinates.append(glyphs.pop_at(rng.randi_range(0, glyphs.size() - 1)))
	return GateAddress.create(coordinates, origin)


func _act_paused(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var roll: float = rng.randf()
	if roll < RESUME_CHANCE:
		simulation.state.clock.is_paused = false
		resumes += 1
		return
	if roll < RESUME_CHANCE + PAUSED_HOLD_CHANCE:
		_add_random_hold(simulation.state.clock, rng)
		return
	_submit_random_flag(simulation, rng)
	commands_while_paused += 1


func _act_held(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var clock: ClockState = simulation.state.clock
	var roll: float = rng.randf()
	if roll < RELEASE_CHANCE:
		var reason: StringName = clock.holds[rng.randi_range(0, clock.holds.size() - 1)]
		if TimeControl.release_hold(clock, reason):
			holds_released += 1
		return
	if roll < RELEASE_CHANCE + EXTRA_HOLD_CHANCE:
		_add_random_hold(clock, rng)
		return
	if roll < RELEASE_CHANCE + EXTRA_HOLD_CHANCE + HELD_REQUEST_CHANCE:
		clock.is_paused = rng.randf() < 0.5
		return
	_submit_random_flag(simulation, rng)
	commands_while_paused += 1


func _add_random_hold(clock: ClockState, rng: RandomNumberGenerator) -> void:
	var reason: StringName = HOLD_REASONS[rng.randi_range(0, HOLD_REASONS.size() - 1)]
	if TimeControl.add_hold(clock, reason):
		holds_added += 1


func _submit_random_flag(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	var key := StringName("soak_flag_%d" % rng.randi_range(0, FLAG_KEY_COUNT - 1))
	simulation.submit(SetFlagCommand.create(key, _random_value(rng)))
	commands_submitted += 1


## Returns a random bool, int or String flag value.
func _random_value(rng: RandomNumberGenerator) -> Variant:
	match rng.randi_range(0, 2):
		0:
			return rng.randf() < 0.5
		1:
			return rng.randi_range(-MAX_INT_VALUE, MAX_INT_VALUE)
		_:
			return "value_%d" % rng.randi()
