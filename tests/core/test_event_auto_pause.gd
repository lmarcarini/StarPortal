## Tests system auto-pause through the event outbox: a system posting &"pause_requested"
## pauses a running SimClock once, through Simulation.pause_requested, and the event is not
## also emitted as event_posted. Uses its own clock instance; restores the EventBus binding.
## Bible: technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const SimClockScript = preload("res://src/core/sim_clock.gd")

var _clock: SimClockScript
var _simulation: Simulation
var _previous_bus_simulation: Simulation
var _pauses: Array[bool] = []
var _events: Array[StringName] = []


## Posts &"pause_requested" from tick() on one tick.
class AutoPauseSystem:
	extends SimSystem

	var _at_tick: int

	func _init(at_tick: int) -> void:
		_at_tick = at_tick

	func get_id() -> StringName:
		return &"auto_pause"

	func tick(state: GameState) -> void:
		if state.clock.tick == _at_tick:
			state.events.post(&"pause_requested", [&"incoming_wormhole"])


func before_test() -> void:
	_pauses.clear()
	_events.clear()
	_previous_bus_simulation = EventBus._simulation
	_clock = SimClockScript.new()
	_clock.set_process(false)
	add_child(_clock)
	var systems: Array[SimSystem] = [AutoPauseSystem.new(2)]
	_simulation = Simulation.new(GameState.new_game(1), systems)
	_simulation.event_posted.connect(_on_event_posted)
	EventBus.paused_changed.connect(_on_paused_changed)


func after_test() -> void:
	EventBus.paused_changed.disconnect(_on_paused_changed)
	_clock.stop()
	_clock.free()
	EventBus.bind_simulation(_previous_bus_simulation)


func _on_paused_changed(is_paused: bool) -> void:
	_pauses.append(is_paused)


func _on_event_posted(name: StringName, _args: Array) -> void:
	_events.append(name)


## The posting tick completes, the clock pauses once and no further tick runs.
func test_system_pause_event_pauses_running_clock_once() -> void:
	_simulation.state.clock.speed_index = 3
	_simulation.state.clock.is_paused = false
	_clock.start(_simulation)
	var ran: int = _clock.advance_by_seconds(1.0)
	assert_int(ran).is_equal(3)
	assert_int(_simulation.state.clock.tick).is_equal(3)
	assert_int(_clock.get_mode()).is_equal(ClockState.Mode.PAUSED)
	assert_array(_pauses).is_equal([true])
	assert_array(_events).is_empty()
	assert_int(_clock.advance_by_seconds(1.0)).is_equal(0)
	assert_array(_pauses).is_equal([true])
