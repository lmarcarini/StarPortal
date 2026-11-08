## Tests for EventOutbox and SimEvent: posting order, drain, events posted while draining,
## and the outbox staying transient in GameState.
## Bible: technical-architecture.md#architecture-overview
extends GdUnitTestSuite


func _names(events: Array[SimEvent]) -> Array[StringName]:
	var names: Array[StringName] = []
	for event: SimEvent in events:
		names.append(event.name)
	return names


## Drain returns events in posting order, with their arguments, and empties the outbox.
func test_drain_keeps_order_and_empties() -> void:
	var outbox := EventOutbox.new()
	outbox.post(&"a", [1, &"x"])
	outbox.post(&"b")
	outbox.post(&"c", [3])
	assert_int(outbox.size()).is_equal(3)
	var events: Array[SimEvent] = outbox.drain()
	assert_array(_names(events)).is_equal([&"a", &"b", &"c"])
	assert_array(events[0].args).is_equal([1, &"x"])
	assert_array(events[1].args).is_empty()
	assert_array(events[2].args).is_equal([3])
	assert_int(outbox.size()).is_equal(0)
	assert_array(outbox.drain()).is_empty()


## Events posted while drained events are being handled wait for the next drain.
func test_post_while_draining_waits_for_next_drain() -> void:
	var outbox := EventOutbox.new()
	outbox.post(&"first")
	outbox.post(&"second")
	var handled: Array[StringName] = []
	for event: SimEvent in outbox.drain():
		handled.append(event.name)
		outbox.post(StringName("after_" + String(event.name)))
	assert_array(handled).is_equal([&"first", &"second"])
	assert_array(_names(outbox.drain())).is_equal([&"after_first", &"after_second"])
	assert_int(outbox.size()).is_equal(0)


## The outbox keeps its own copy of the arguments.
func test_post_copies_args() -> void:
	var outbox := EventOutbox.new()
	var args: Array = [1]
	outbox.post(&"a", args)
	args.append(2)
	assert_array(outbox.drain()[0].args).is_equal([1])


## SimEvent defaults to an empty name and no arguments.
func test_sim_event_defaults() -> void:
	var event := SimEvent.new()
	assert_str(String(event.name)).is_empty()
	assert_array(event.args).is_empty()


## A new game starts with an empty outbox.
func test_new_game_has_empty_outbox() -> void:
	var state := GameState.new_game(1)
	assert_object(state.events).is_not_null()
	assert_int(state.events.size()).is_equal(0)


## Waiting events are not saved, and loading gives an empty outbox.
func test_outbox_is_transient() -> void:
	var state := GameState.new_game(5)
	var before: Dictionary = state.to_dict()
	state.events.post(&"gate_locked", [&"p3x"])
	var data: Dictionary = state.to_dict()
	assert_dict(data).is_equal(before)
	(
		assert_array(data.keys())
		. contains_exactly_in_any_order(
			[
				"clock",
				"random",
				"flags",
				"gate",
				"power",
				"budget",
				"base",
				"worlds",
				"archive",
				"address_book",
				"operations_log",
				"unlocks",
				"research",
				"staff",
				"committee",
				"recruitment",
				"probes",
				"expedition",
			]
		)
	)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data))
	var loaded := GameState.from_dict(parsed)
	assert_object(loaded.events).is_not_null()
	assert_int(loaded.events.size()).is_equal(0)
	assert_int(state.events.size()).is_equal(1)
