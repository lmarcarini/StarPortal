## Tests for CommandQueue and SetFlagCommand: validation on submit and at flush, immediate
## application while paused, the command log, and replaying a logged session.
## Bible: technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const SEED: int = 4242

var _rejections: Array[String] = []


## Sets a flag, but only while the &"locked" flag is absent; lets a test change the state
## between submit and flush.
class GuardedCommand:
	extends Command

	func get_type() -> StringName:
		return &"guarded"

	func validate(state: GameState) -> CommandResult:
		if state.flags.has(&"locked"):
			return CommandResult.fail(&"locked")
		return CommandResult.ok()

	func apply(state: GameState) -> void:
		state.flags[&"guarded_applied"] = true

	func to_dict() -> Dictionary:
		return {"type": String(get_type())}


func before_test() -> void:
	_rejections.clear()


func after_test() -> void:
	CommandFactory.reset()


func _make_queue() -> CommandQueue:
	var queue := CommandQueue.new()
	queue.command_rejected.connect(_on_command_rejected)
	return queue


func _make_running_state() -> GameState:
	var state := GameState.new_game(SEED)
	state.clock.is_paused = false
	return state


func _on_command_rejected(type: StringName, code: StringName) -> void:
	_rejections.append("%s:%s" % [type, code])


# --- submit ---------------------------------------------------------------------------


## An invalid command returns the failed result, is not queued, applied or logged, and is
## reported through command_rejected.
func test_submit_invalid_command_is_rejected_and_not_queued() -> void:
	var queue := _make_queue()
	var state := _make_running_state()
	var result := queue.submit(SetFlagCommand.create(&"", true), state)
	assert_bool(result.is_ok).is_false()
	assert_that(result.error_code).is_equal(&"empty_key")
	assert_int(queue.pending_count()).is_equal(0)
	assert_array(queue.get_log()).is_empty()
	assert_array(_rejections).contains_exactly(["set_flag:empty_key"])


## An invalid command submitted while paused is not applied either.
func test_submit_invalid_command_while_paused_is_not_applied() -> void:
	var queue := _make_queue()
	var state := GameState.new_game(SEED)
	var result := queue.submit(SetFlagCommand.create(&"bad", 1.5), state)
	assert_that(result.error_code).is_equal(&"invalid_value")
	assert_bool(state.flags.has(&"bad")).is_false()
	assert_array(queue.get_log()).is_empty()
	assert_array(_rejections).contains_exactly(["set_flag:invalid_value"])


## A null command fails with &"no_command" and is reported.
func test_submit_null_command_is_rejected() -> void:
	var queue := _make_queue()
	var result := queue.submit(null, GameState.new_game(SEED))
	assert_bool(result.is_ok).is_false()
	assert_that(result.error_code).is_equal(&"no_command")
	assert_int(queue.pending_count()).is_equal(0)
	assert_array(_rejections).contains_exactly([":no_command"])


## While paused, a valid command applies at once and is logged with the current tick.
func test_submit_while_paused_applies_immediately_and_logs() -> void:
	var queue := _make_queue()
	var state := GameState.new_game(SEED)
	state.clock.tick = 77
	var result := queue.submit(SetFlagCommand.create(&"met_kessler", true), state)
	assert_bool(result.is_ok).is_true()
	assert_that(state.flags[&"met_kessler"]).is_equal(true)
	assert_int(queue.pending_count()).is_equal(0)
	var expected_command: Dictionary = {"type": "set_flag", "key": "met_kessler", "value": true}
	assert_array(queue.get_log()).is_equal([{"tick": 77, "command": expected_command}])


## While running, a valid command is queued, not applied and not logged yet.
func test_submit_while_running_queues_the_command() -> void:
	var queue := _make_queue()
	var state := _make_running_state()
	var result := queue.submit(SetFlagCommand.create(&"alarm", 2), state)
	assert_bool(result.is_ok).is_true()
	assert_int(queue.pending_count()).is_equal(1)
	assert_bool(state.flags.has(&"alarm")).is_false()
	assert_array(queue.get_log()).is_empty()
	assert_array(_rejections).is_empty()


## A paused submit first flushes commands still pending, so submission order holds.
func test_submit_while_paused_applies_pending_commands_first() -> void:
	var queue := _make_queue()
	var state := _make_running_state()
	queue.submit(SetFlagCommand.create(&"order", "first"), state)
	state.clock.is_paused = true
	queue.submit(SetFlagCommand.create(&"order", "second"), state)
	assert_that(state.flags[&"order"]).is_equal("second")
	assert_int(queue.pending_count()).is_equal(0)
	assert_int(queue.get_log().size()).is_equal(2)


## A paused submit re-validates the new command after the pending ones apply: if one of
## them invalidated it, it is rejected, not applied and not logged, and the log replays.
func test_submit_while_paused_rejects_command_invalidated_by_pending_ones() -> void:
	var queue := _make_queue()
	var state := _make_running_state()
	queue.submit(SetFlagCommand.create(&"locked", true), state)
	state.clock.is_paused = true
	var result := queue.submit(GuardedCommand.new(), state)
	assert_bool(result.is_ok).is_false()
	assert_that(result.error_code).is_equal(&"locked")
	assert_bool(state.flags.has(&"guarded_applied")).is_false()
	assert_int(queue.pending_count()).is_equal(0)
	assert_int(queue.get_log().size()).is_equal(1)
	assert_array(_rejections).contains_exactly(["guarded:locked"])
	var replayed := _replay(queue.get_log(), state.clock.tick)
	assert_dict(replayed.to_dict()).is_equal(state.to_dict())


# --- flush ----------------------------------------------------------------------------


## Flush applies queued commands in submission order and logs each with the flush tick.
func test_flush_applies_in_order_and_logs_tick() -> void:
	var queue := _make_queue()
	var state := _make_running_state()
	queue.submit(SetFlagCommand.create(&"door", "open"), state)
	queue.submit(SetFlagCommand.create(&"door", "shut"), state)
	state.clock.tick = 12
	queue.flush(state)
	assert_that(state.flags[&"door"]).is_equal("shut")
	assert_int(queue.pending_count()).is_equal(0)
	var entries := queue.get_log()
	assert_int(entries.size()).is_equal(2)
	assert_int(entries[0]["tick"]).is_equal(12)
	assert_that(entries[0]["command"]["value"]).is_equal("open")
	assert_that(entries[1]["command"]["value"]).is_equal("shut")


## A command valid at submit but invalid at flush is dropped, reported and not logged.
func test_flush_revalidates_and_drops_commands_that_became_invalid() -> void:
	var queue := _make_queue()
	var state := _make_running_state()
	assert_bool(queue.submit(GuardedCommand.new(), state).is_ok).is_true()
	state.flags[&"locked"] = true
	queue.flush(state)
	assert_bool(state.flags.has(&"guarded_applied")).is_false()
	assert_int(queue.pending_count()).is_equal(0)
	assert_array(queue.get_log()).is_empty()
	assert_array(_rejections).contains_exactly(["guarded:locked"])


## An earlier command in the same flush can invalidate a later one.
func test_flush_revalidates_against_state_changed_by_earlier_commands() -> void:
	var queue := _make_queue()
	var state := _make_running_state()
	queue.submit(SetFlagCommand.create(&"locked", true), state)
	queue.submit(GuardedCommand.new(), state)
	queue.flush(state)
	assert_bool(state.flags.has(&"guarded_applied")).is_false()
	assert_int(queue.get_log().size()).is_equal(1)
	assert_that(queue.get_log()[0]["command"]["key"]).is_equal("locked")
	assert_array(_rejections).contains_exactly(["guarded:locked"])


## Through the Simulation, a queued command is logged with the tick it applied on and a
## flush rejection is forwarded.
func test_simulation_logs_apply_tick_and_forwards_flush_rejection() -> void:
	var simulation := Simulation.new(_make_running_state())
	simulation.command_rejected.connect(_on_command_rejected)
	simulation.state.clock.tick = 30
	simulation.submit(SetFlagCommand.create(&"locked", true))
	simulation.submit(GuardedCommand.new())
	simulation.advance_tick()
	assert_array(simulation.commands.get_log()).is_equal(
		[{"tick": 30, "command": {"type": "set_flag", "key": "locked", "value": true}}]
	)
	assert_array(_rejections).contains_exactly(["guarded:locked"])


# --- log ------------------------------------------------------------------------------


## get_log() returns a copy; changing it does not change the queue's log.
func test_get_log_returns_a_copy() -> void:
	var queue := _make_queue()
	queue.submit(SetFlagCommand.create(&"a", 1), GameState.new_game(SEED))
	var entries := queue.get_log()
	entries[0]["tick"] = 999
	entries.clear()
	assert_int(queue.get_log().size()).is_equal(1)
	assert_int(queue.get_log()[0]["tick"]).is_equal(0)


## clear_log() empties the log but keeps pending commands.
func test_clear_log_keeps_pending_commands() -> void:
	var queue := _make_queue()
	var state := GameState.new_game(SEED)
	queue.submit(SetFlagCommand.create(&"a", 1), state)
	state.clock.is_paused = false
	queue.submit(SetFlagCommand.create(&"b", 2), state)
	queue.clear_log()
	assert_array(queue.get_log()).is_empty()
	assert_int(queue.pending_count()).is_equal(1)


# --- replay ---------------------------------------------------------------------------


## A scripted session's log, round-tripped through JSON and replayed on a fresh state with
## the same seed, reproduces the final state exactly.
func test_replaying_the_log_reproduces_the_session() -> void:
	var simulation := Simulation.new(GameState.new_game(SEED))
	simulation.submit(SetFlagCommand.create(&"intro_seen", true))
	simulation.submit(SetFlagCommand.create(&"", true))
	simulation.state.clock.is_paused = false
	simulation.submit(SetFlagCommand.create(&"dial_attempts", 1))
	simulation.advance_tick()
	simulation.advance_tick()
	simulation.submit(SetFlagCommand.create(&"dial_attempts", 2))
	simulation.submit(SetFlagCommand.create(&"bad", [1]))
	simulation.submit(SetFlagCommand.create(&"last_world", "P3X-118"))
	for i: int in 5:
		simulation.advance_tick()
	simulation.state.clock.is_paused = true
	simulation.submit(SetFlagCommand.create(&"intro_seen", false))
	simulation.advance_tick()

	var saved_log: Array = JSON.parse_string(JSON.stringify(simulation.commands.get_log()))
	assert_int(simulation.commands.get_log().size()).is_equal(5)
	var replayed := _replay(saved_log, simulation.state.clock.tick)
	assert_dict(replayed.to_dict()).is_equal(simulation.state.to_dict())


## Replays [param entries] on a fresh paused game with the session seed, advancing ticks to
## each entry's tick, then to [param end_tick].
func _replay(entries: Array, end_tick: int) -> GameState:
	var simulation := Simulation.new(GameState.new_game(SEED))
	for entry: Dictionary in entries:
		var tick: float = entry["tick"]
		var data: Dictionary = entry["command"]
		_advance_to(simulation, int(tick))
		var built := CommandFactory.from_dict(data)
		assert_bool(built.is_ok).is_true()
		var command: Command = built.value
		assert_bool(simulation.submit(command).is_ok).is_true()
	_advance_to(simulation, end_tick)
	return simulation.state


func _advance_to(simulation: Simulation, tick: int) -> void:
	while simulation.state.clock.tick < tick:
		simulation.advance_tick()


# --- SetFlagCommand -------------------------------------------------------------------


## SetFlagCommand accepts bool, int and String values.
func test_set_flag_validate_accepts_bool_int_and_string() -> void:
	var state := GameState.new_game(SEED)
	for value: Variant in [true, false, 0, -3, "", "P3X-118"]:
		assert_bool(SetFlagCommand.create(&"flag", value).validate(state).is_ok).is_true()


## SetFlagCommand rejects an empty key.
func test_set_flag_validate_rejects_empty_key() -> void:
	var result := SetFlagCommand.create(&"", true).validate(GameState.new_game(SEED))
	assert_bool(result.is_ok).is_false()
	assert_that(result.error_code).is_equal(&"empty_key")


## SetFlagCommand rejects values that are not bool, int or String.
func test_set_flag_validate_rejects_other_value_types() -> void:
	var state := GameState.new_game(SEED)
	for value: Variant in [null, 1.5, 2.0, &"name", [1], {"a": 1}, Vector2.ZERO]:
		var result := SetFlagCommand.create(&"flag", value).validate(state)
		assert_bool(result.is_ok).override_failure_message(str(value)).is_false()
		assert_that(result.error_code).is_equal(&"invalid_value")


## SetFlagCommand.apply() sets the flag.
func test_set_flag_apply_sets_the_flag() -> void:
	var state := GameState.new_game(SEED)
	SetFlagCommand.create(&"chapter", 3).apply(state)
	assert_that(state.flags[&"chapter"]).is_equal(3)
