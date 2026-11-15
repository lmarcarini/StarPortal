## Tests for the operations log written by the Simulation through LogRules: a scripted session
## (install, a failed dial, a lock, the horizon record and its documents, the console, the
## close) writes the right entries in order; the log survives save and load.
## Bible: game-design.md#core-loop (Archive: the operations log)
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const SaveServiceScript := preload("res://src/services/save_service.gd")
const SEED: int = 20261026
## SILL's address with seal 7 changed: dialed before SILL, whatever it reaches.
const MISS_GLYPHS: Array[int] = [35, 24, 29, 10, 19, 22, 3]

var _player: M15Player


func before_test() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var built: Result = GameSetup.build_new(GameState.new_game(SEED, defs.balance), defs)
	var simulation: Simulation = built.value
	_player = M15Player.new(simulation)


## The Log without the staff lines (the soldiers lent on the first lock, M4c-22).
func _log() -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in _player.state().operations_log.entries:
		if entry.kind != &"staff":
			found.append(entry)
	return found


func _kinds(from: int) -> Array[StringName]:
	var kinds: Array[StringName] = []
	for entry: LogEntry in _log().slice(from):
		kinds.append(entry.kind)
	return kinds


## Plays SILL from a new game; returns the outcome of the dial before SILL.
func _play_sill() -> DialLogEntry:
	_player.step()
	assert_int(_player.build_bank()).is_greater(0)
	var miss: GateAddress = _player.address(MISS_GLYPHS)
	assert_bool(_player.wait_for_charge(miss)).is_true()
	var missed: DialLogEntry = _player.dial(miss)
	var sill: GateAddress = _player.address(M15Player.PUZZLES[0]["glyphs"])
	assert_bool(_player.wait_for_charge(sill)).is_true()
	assert_int(_player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	assert_array(_player.extend_pole_camera()).has_size(3)
	assert_array(_player.read_console()).is_not_empty()
	assert_bool(_player.close_wormhole()).is_true()
	return missed


## The session writes start documents, install, dial, dial + lock, horizon, documents, console
## and close, in that order, with the right details and non-decreasing ticks.
func test_scripted_session_writes_entries_in_order() -> void:
	var missed: DialLogEntry = _play_sill()
	var expected: Array[StringName] = [&"document", &"document", &"power", &"dial", &"dial"]
	expected.append_array([&"lock", &"horizon", &"document", &"document", &"document"])
	expected.append_array([&"console", &"close"])
	assert_array(_kinds(0)).is_equal(expected)
	var entries: Array[LogEntry] = _log()
	assert_str(entries[0].args["document_id"]).is_equal("doc_sill_order")
	assert_int(entries[2].args["banks"]).is_equal(1)
	assert_str(entries[3].args["address"]).is_equal(missed.address.key())
	assert_str(entries[3].args["outcome"]).is_equal(String(DialOutcome.to_key(missed.outcome)))
	if not DialOutcome.is_lock(missed.outcome):
		assert_str(String(entries[3].world_id)).is_empty()
	assert_str(entries[4].args["outcome"]).is_equal("lock")
	for index: int in range(4, 12):
		if entries[index].kind != &"document":
			assert_str(String(entries[index].world_id)).is_equal("world_sill")
	assert_bool(entries[5].args["hostile"]).is_false()
	assert_str(entries[11].args["reason"]).is_equal("player")
	for index: int in range(1, entries.size()):
		assert_int(entries[index].tick).is_greater_equal(entries[index - 1].tick)
	var newest: LogEntry = entries.back()
	assert_int(newest.tick).is_equal(_player.state().clock.tick)


## A timed-out wormhole logs a close with reason "timeout"; ignored events write nothing.
func test_timeout_close_and_ignored_events() -> void:
	var state: GameState = _player.state()
	assert_array(LogRules.entries_for(&"address_book_changed", [], state, 0)).is_empty()
	assert_array(LogRules.entries_for(&"dial_started", ["1-2"], state, 0)).is_empty()
	var close: Array[LogEntry] = LogRules.entries_for(&"wormhole_closed", [&"timeout"], state, 5)
	assert_str(close[0].args["reason"]).is_equal("timeout")
	assert_int(close[0].tick).is_equal(5)


## The log survives a save and load through the SaveService.
func test_log_survives_save_and_load() -> void:
	_play_sill()
	var service: SaveServiceScript = SaveServiceScript.new()
	var dir := "user://test_log_rules_%d_%d" % [Time.get_ticks_usec(), get_instance_id()]
	service.saves_dir = dir
	assert_bool(service.save_game(_player.state(), &"log").is_ok).is_true()
	var loaded: Result = service.load_game(&"log")
	service.delete_slot(&"log")
	DirAccess.remove_absolute(dir)
	service.free()
	assert_bool(loaded.is_ok).is_true()
	var state: GameState = loaded.value
	var expected: Dictionary = _player.state().operations_log.to_dict()
	assert_dict(state.operations_log.to_dict()).is_equal(expected)
