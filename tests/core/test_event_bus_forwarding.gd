## Tests for EventBus forwarding of outbox events: a declared signal is re-emitted with its
## arguments; an undeclared name or a wrong argument count asserts and is not emitted.
## Uses a test-only bus subclass instance, never the autoload.
## Bible: technical-architecture.md#architecture-overview
extends GdUnitTestSuite

var _bus: TestBus
var _simulation: Simulation
var _received: Array = []


## The real bus plus one test-only domain signal.
class TestBus:
	extends "res://src/core/event_bus.gd"

	## Test-only domain event with two arguments.
	@warning_ignore("unused_signal")
	signal test_pinged(world: StringName, count: int)


func before_test() -> void:
	_received = []
	_bus = TestBus.new()
	add_child(_bus)
	_simulation = Simulation.new(GameState.new_game(1))
	_bus.bind_simulation(_simulation)
	_bus.test_pinged.connect(_on_test_pinged)


func after_test() -> void:
	_bus.bind_simulation(null)
	_bus.free()


func _on_test_pinged(world: StringName, count: int) -> void:
	_received.append([world, count])


## A declared signal is re-emitted with the event's arguments, once per event, in order.
func test_reemits_declared_signal_with_args() -> void:
	_simulation.state.events.post(&"test_pinged", [&"p3x", 1])
	_simulation.state.events.post(&"test_pinged", [&"abydos", 2])
	_simulation.advance_tick()
	assert_array(_received).is_equal([[&"p3x", 1], [&"abydos", 2]])


## The argument count is looked up once per name and cached.
func test_caches_declared_arg_count() -> void:
	_simulation.event_posted.emit(&"test_pinged", [&"p3x", 1])
	_simulation.event_posted.emit(&"test_pinged", [&"p3x", 2])
	assert_dict(_bus._arg_counts).is_equal({&"test_pinged": 2})
	assert_int(_received.size()).is_equal(2)


## Existing domain signals declared on the bus forward too.
func test_reemits_existing_bus_signal() -> void:
	var days: Array[int] = []
	var on_day := func(day_index: int) -> void: days.append(day_index)
	_bus.day_started.connect(on_day)
	_simulation.event_posted.emit(&"day_started", [7])
	assert_array(days).is_equal([7])


## An undeclared event name asserts and emits nothing.
func test_undeclared_name_asserts_and_does_not_emit() -> void:
	await (
		assert_error(func() -> void: _simulation.event_posted.emit(&"no_such_event", [1]))
		. is_runtime_error(
			"Assertion failed: EventBus: no signal declared for posted event 'no_such_event'"
		)
	)
	assert_int(_bus._arg_counts[&"no_such_event"]).is_equal(-1)


## A signal inherited from Node is not a domain event.
func test_node_signal_counts_as_undeclared() -> void:
	await (
		assert_error(func() -> void: _simulation.event_posted.emit(&"ready", []))
		. is_runtime_error(
			"Assertion failed: EventBus: no signal declared for posted event 'ready'"
		)
	)


## A wrong argument count asserts and emits nothing.
func test_wrong_arg_count_asserts_and_does_not_emit() -> void:
	await (
		assert_error(func() -> void: _simulation.event_posted.emit(&"test_pinged", [&"p3x"]))
		. is_runtime_error(
			"Assertion failed: EventBus: event 'test_pinged' posted with 1 args, its signal declares 2"
		)
	)
	assert_array(_received).is_empty()


## Unbinding disconnects event forwarding.
func test_unbinding_disconnects_event_posted() -> void:
	assert_bool(_simulation.event_posted.is_connected(_bus._on_event_posted)).is_true()
	_bus.bind_simulation(null)
	assert_bool(_simulation.event_posted.is_connected(_bus._on_event_posted)).is_false()
	_simulation.state.events.post(&"test_pinged", [&"p3x", 1])
	_simulation.advance_tick()
	assert_array(_received).is_empty()


## Binding another simulation moves event forwarding to it.
func test_rebinding_moves_event_forwarding() -> void:
	var other := Simulation.new(GameState.new_game(2))
	_bus.bind_simulation(other)
	_simulation.event_posted.emit(&"test_pinged", [&"old", 1])
	other.event_posted.emit(&"test_pinged", [&"new", 2])
	assert_array(_received).is_equal([[&"new", 2]])
