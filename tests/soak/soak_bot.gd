extends RefCounted
## Seeded stand-in player for the soak test. It sets random flags through SetFlagCommand
## about 20 times per in-game day and pauses and resumes the clock at random. Every random
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
## Number of distinct flag keys the bot writes: soak_flag_0 to soak_flag_<n - 1>.
const FLAG_KEY_COUNT: int = 16
## Largest magnitude of a random int flag value.
const MAX_INT_VALUE: int = 1000000

## Commands submitted so far, running and paused.
var commands_submitted: int = 0
## Commands submitted while the clock was paused (they apply at once).
var commands_while_paused: int = 0
## Times the bot paused the clock.
var pauses: int = 0
## Times the bot resumed the clock.
var resumes: int = 0

var _next_action_tick: int = 0


## Acts once on [param simulation] before its next tick. While running, the bot waits for
## its next action tick, then submits a command or pauses. While paused, every call is an
## action: resume, or submit a command that applies at once.
func act(simulation: Simulation) -> void:
	var clock: ClockState = simulation.state.clock
	if not clock.is_paused and clock.tick < _next_action_tick:
		return
	var rng: RandomNumberGenerator = simulation.state.random.stream(STREAM_ID)
	if clock.is_paused:
		_act_paused(simulation, rng)
		return
	_next_action_tick = clock.tick + rng.randi_range(1, MAX_ACTION_GAP)
	if rng.randf() < PAUSE_CHANCE:
		clock.is_paused = true
		pauses += 1
		return
	_submit_random_flag(simulation, rng)


func _act_paused(simulation: Simulation, rng: RandomNumberGenerator) -> void:
	if rng.randf() < RESUME_CHANCE:
		simulation.state.clock.is_paused = false
		resumes += 1
		return
	_submit_random_flag(simulation, rng)
	commands_while_paused += 1


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
