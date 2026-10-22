## Tests that the intel and Workbench events reach the EventBus: clue_received,
## clue_note_changed and workbench_changed are declared there and re-emitted once each when
## posted through the outbox, including by commands submitted while paused. Uses a fresh bus
## instance, never the autoload.
## Bible: technical-architecture.md#architecture-overview, gate-and-address-spec.md#player-tools
extends GdUnitTestSuite

const Fixture := preload("res://tests/core/intel_fixture.gd")
const EventBusScript := preload("res://src/core/event_bus.gd")

var _bus: EventBusScript
var _simulation: Simulation
var _received: Array[Array] = []


func before_test() -> void:
	_received.clear()
	_bus = EventBusScript.new()
	add_child(_bus)
	_simulation = Simulation.new(Fixture.state())
	_bus.bind_simulation(_simulation)
	_bus.clue_received.connect(func(id: StringName) -> void: _received.append([&"received", id]))
	_bus.clue_note_changed.connect(func(id: StringName) -> void: _received.append([&"note", id]))
	_bus.workbench_changed.connect(func() -> void: _received.append([&"workbench"]))


func after_test() -> void:
	_bus.bind_simulation(null)
	_bus.free()
	CommandFactory.reset()


## The three signals are declared with one, one and no arguments, and none is reserved.
func test_signals_are_declared() -> void:
	var expected: Dictionary[String, int] = {
		"clue_received": 1, "clue_note_changed": 1, "workbench_changed": 0
	}
	for info: Dictionary in _bus.get_signal_list():
		var name: String = info["name"]
		if expected.has(name):
			var args: Array = info["args"]
			assert_int(args.size()).override_failure_message(name).is_equal(expected[name])
			expected.erase(name)
	assert_dict(expected).is_empty()
	for name: StringName in [&"clue_received", &"clue_note_changed", &"workbench_changed"]:
		assert_bool(EventBusScript.RESERVED_EVENT_NAMES.has(name)).is_false()


## A posted clue_received event is re-emitted with the clue id.
func test_clue_received_is_reemitted() -> void:
	_simulation.state.events.post(&"clue_received", [Fixture.SKY_CHART_ID])
	_simulation.advance_tick()
	assert_array(_received).is_equal([[&"received", Fixture.SKY_CHART_ID]])


## Both commands, submitted while paused, apply and emit their signal once each, in order.
func test_commands_emit_once_each() -> void:
	var note := ClueNote.new()
	note.is_suspect = true
	var annotate := AnnotateClueCommand.create(Fixture.SKY_CHART_ID, note)
	assert_bool(_simulation.submit(annotate).is_ok).is_true()
	var empty: Array[AddressConstraint] = []
	assert_bool(_simulation.submit(SetWorkbenchCommand.create(5, empty)).is_ok).is_true()
	assert_array(_received).is_equal([[&"note", Fixture.SKY_CHART_ID], [&"workbench"]])
	assert_int(_simulation.state.workbench.origin_glyph).is_equal(5)
	assert_bool(_simulation.state.intel.note_for(Fixture.SKY_CHART_ID).is_suspect).is_true()


## A rejected command changes nothing and emits no intel event.
func test_rejected_command_emits_nothing() -> void:
	var before := _simulation.state.to_dict()
	var result := _simulation.submit(AnnotateClueCommand.create(&"clue_9999", ClueNote.new()))
	assert_str(result.error_code).is_equal(&"unknown_clue")
	assert_array(_received).is_empty()
	assert_dict(_simulation.state.to_dict()).is_equal(before)
