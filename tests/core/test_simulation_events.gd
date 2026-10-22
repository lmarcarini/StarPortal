## Tests for Simulation event emission: outbox events come out last in each tick and from a
## paused submit(), in posting order, once each; emission never nests; pause_requested
## events route to the pause_requested signal.
## Bible: technical-architecture.md#simulation-clock-and-commands,
## technical-architecture.md#architecture-overview
extends GdUnitTestSuite

const DAY: int = TimeMath.TICKS_PER_DAY

var _log: Array[String] = []


## Posts an event named after its id and hook from tick() and on_day().
class PostingSystem:
	extends SimSystem

	var _id: StringName

	func _init(id: StringName) -> void:
		_id = id

	func get_id() -> StringName:
		return _id

	func tick(state: GameState) -> void:
		state.events.post(StringName("%s_tick" % _id), [state.clock.tick])

	func on_day(state: GameState) -> void:
		state.events.post(StringName("%s_day" % _id), [state.clock.tick])


## Posts each of [code]events[/code] (no args) from tick(), on the tick it is armed for.
class PostOnceSystem:
	extends SimSystem

	var _at_tick: int
	var _events: Array[StringName]
	var _args: Array

	func _init(at_tick: int, events: Array[StringName], args: Array = []) -> void:
		_at_tick = at_tick
		_events = events
		_args = args

	func get_id() -> StringName:
		return &"post_once"

	func tick(state: GameState) -> void:
		if state.clock.tick != _at_tick:
			return
		for event: StringName in _events:
			state.events.post(event, _args)


## Posts one event, by default &"command_event" with the tick, when applied.
class PostingCommand:
	extends Command

	var _event: StringName

	func _init(event: StringName = &"command_event") -> void:
		_event = event

	func get_type() -> StringName:
		return &"posting"

	func validate(_state: GameState) -> CommandResult:
		return CommandResult.ok()

	func apply(state: GameState) -> void:
		state.events.post(_event, [state.clock.tick])

	func to_dict() -> Dictionary:
		return {"type": String(get_type())}


func before_test() -> void:
	_log = []


func _make_simulation(systems: Array[SimSystem] = [], is_paused: bool = false) -> Simulation:
	var simulation := Simulation.new(GameState.new_game(1), systems)
	simulation.state.clock.is_paused = is_paused
	simulation.day_started.connect(_on_day_started)
	simulation.month_closed.connect(_on_month_closed)
	simulation.event_posted.connect(_on_event_posted)
	simulation.pause_requested.connect(_on_pause_requested)
	return simulation


func _on_day_started(day_index: int) -> void:
	_log.append("day_started(%d)" % day_index)


func _on_month_closed(year: int, month: int) -> void:
	_log.append("month_closed(%d,%d)" % [year, month])


func _on_event_posted(name: StringName, args: Array) -> void:
	_log.append("event(%s,%s)" % [name, args])


func _on_pause_requested(reason: StringName) -> void:
	_log.append("pause_requested(%s)" % reason)


## Events posted from tick() and on_day() come out last, after day_started, in posting
## order, exactly once each.
func test_events_emitted_last_in_order_once() -> void:
	var systems: Array[SimSystem] = [PostingSystem.new(&"a"), PostingSystem.new(&"b")]
	var simulation := _make_simulation(systems)
	simulation.state.clock.tick = DAY - 1
	simulation.advance_tick()
	var expected: Array[String] = [
		"day_started(1)",
		"event(a_tick,[1439])",
		"event(b_tick,[1439])",
		"event(a_day,[1440])",
		"event(b_day,[1440])",
	]
	assert_array(_log).contains_exactly(expected)
	assert_int(simulation.state.events.size()).is_equal(0)
	simulation.advance_tick()
	assert_array(_log.slice(5)).contains_exactly(["event(a_tick,[1440])", "event(b_tick,[1440])"])


## Events come out after month_closed too.
func test_events_emitted_after_month_closed() -> void:
	var events: Array[StringName] = [&"late"]
	var systems: Array[SimSystem] = [PostOnceSystem.new(31 * DAY - 1, events)]
	var simulation := _make_simulation(systems)
	simulation.state.clock.tick = 31 * DAY - 1
	simulation.advance_tick()
	assert_array(_log).contains_exactly(
		["day_started(31)", "month_closed(2026,1)", "event(late,[])"]
	)


## A command applied at once while paused has its events emitted from submit().
func test_paused_command_events_emitted_from_submit() -> void:
	var simulation := _make_simulation([], true)
	simulation.submit(PostingCommand.new())
	assert_array(_log).contains_exactly(["event(command_event,[0])"])
	assert_int(simulation.state.events.size()).is_equal(0)


## A command queued while running has its events emitted with its tick, not at submit.
func test_running_command_events_emitted_with_tick() -> void:
	var simulation := _make_simulation()
	simulation.submit(PostingCommand.new())
	assert_array(_log).is_empty()
	simulation.advance_tick()
	assert_array(_log).contains_exactly(["event(command_event,[0])"])


## A running-clock submit leaves waiting events alone: they come out with the tick.
func test_running_submit_does_not_drain() -> void:
	var simulation := _make_simulation()
	simulation.state.events.post(&"waiting", [])
	simulation.submit(PostingCommand.new())
	assert_array(_log).is_empty()
	assert_int(simulation.state.events.size()).is_equal(1)
	simulation.advance_tick()
	assert_array(_log).contains_exactly(["event(waiting,[])", "event(command_event,[0])"])


## A handler that submits while paused does not nest a drain: the outer emission emits the
## nested command's event after the rest, in posting order, each once.
func test_nested_paused_submit_keeps_posting_order() -> void:
	var simulation := _make_simulation([], true)
	var submit_on_a := func(name: StringName, _args: Array) -> void:
		if name == &"a":
			simulation.submit(PostingCommand.new(&"nested"))
	simulation.event_posted.connect(submit_on_a)
	simulation.state.events.post(&"a", [])
	simulation.state.events.post(&"b", [])
	simulation.submit(PostingCommand.new(&"c"))
	var expected: Array[String] = [
		"event(a,[])", "event(b,[])", "event(c,[0])", "event(nested,[0])"
	]
	assert_array(_log).contains_exactly(expected)
	assert_int(simulation.state.events.size()).is_equal(0)


## Inside a tick, a handler that pauses the clock and submits does not nest a drain: the
## nested command's event comes out in the same tick, after the tick's own events.
func test_nested_submit_during_tick_keeps_posting_order() -> void:
	var events: Array[StringName] = [&"a", &"b"]
	var simulation := _make_simulation([PostOnceSystem.new(0, events)])
	var pause_and_submit_on_a := func(name: StringName, _args: Array) -> void:
		if name == &"a":
			simulation.state.clock.is_paused = true
			simulation.submit(PostingCommand.new(&"nested"))
	simulation.event_posted.connect(pause_and_submit_on_a)
	simulation.advance_tick()
	assert_array(_log).contains_exactly(["event(a,[])", "event(b,[])", "event(nested,[1])"])
	simulation.advance_tick()
	assert_int(_log.size()).is_equal(3)


## A pause_requested event is emitted as the pause_requested signal, not event_posted.
func test_pause_event_emits_pause_requested_only() -> void:
	var events: Array[StringName] = [&"pause_requested"]
	var simulation := _make_simulation([PostOnceSystem.new(0, events, [&"wormhole"])])
	simulation.advance_tick()
	simulation.advance_tick()
	assert_array(_log).contains_exactly(["pause_requested(wormhole)"])


## A pause_requested event without exactly one reason asserts and is dropped.
func test_pause_event_with_bad_args_asserts() -> void:
	var simulation := _make_simulation()
	simulation.state.events.post(&"pause_requested", [])
	await (
		assert_error(func() -> void: simulation.advance_tick())
		. is_runtime_error(
			"Assertion failed: Simulation: pause_requested needs args [reason], got []"
		)
	)
	assert_array(_log).is_empty()
