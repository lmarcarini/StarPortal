## Tests for Simulation: fixed tick order, day and month hooks, signals, and isolation
## from autoloads and Nodes. Uses fake systems and a fake command.
## Bible: technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const DAY: int = TimeMath.TICKS_PER_DAY
const SIMULATION_PATH: String = "res://src/core/simulation.gd"
const FORBIDDEN_WORDS: Array[String] = [
	"EventBus",
	"SimClock",
	"Registry",
	"SaveService",
	"InputService",
	"Settings",
	"Node",
	"get_tree",
	"Engine.",
]

var _log: Array[String] = []


## Records each hook call into a shared log, tagged with the system id and clock tick.
class FakeSystem:
	extends SimSystem

	var _id: StringName
	var _log: Array[String]

	func _init(id: StringName, entries: Array[String]) -> void:
		_id = id
		_log = entries

	func get_id() -> StringName:
		return _id

	func tick(state: GameState) -> void:
		_log.append("%s.tick@%d" % [_id, state.clock.tick])

	func on_day(state: GameState) -> void:
		_log.append("%s.on_day@%d" % [_id, state.clock.tick])

	func on_month(state: GameState) -> void:
		_log.append("%s.on_month@%d" % [_id, state.clock.tick])


## Sets a flag when applied and records the application in the shared log.
class FakeCommand:
	extends Command

	var _log: Array[String]

	func _init(entries: Array[String]) -> void:
		_log = entries

	func get_type() -> StringName:
		return &"fake"

	func validate(_state: GameState) -> CommandResult:
		return CommandResult.ok()

	func apply(state: GameState) -> void:
		state.flags[&"fake_applied"] = true
		_log.append("command@%d" % state.clock.tick)

	func to_dict() -> Dictionary:
		return {"type": String(get_type())}


func before_test() -> void:
	_log = []


func _make_simulation(start_tick: int) -> Simulation:
	var state := GameState.new_game(1)
	state.clock.tick = start_tick
	var systems: Array[SimSystem] = [FakeSystem.new(&"a", _log), FakeSystem.new(&"b", _log)]
	var simulation := Simulation.new(state, systems)
	simulation.day_started.connect(_on_day_started)
	simulation.month_closed.connect(_on_month_closed)
	return simulation


func _on_day_started(day_index: int) -> void:
	_log.append("day_started(%d)" % day_index)


func _on_month_closed(year: int, month: int) -> void:
	_log.append("month_closed(%d,%d)" % [year, month])


func _on_command_rejected(type: StringName, code: StringName) -> void:
	_log.append("command_rejected(%s,%s)" % [type, code])


## An ordinary tick: commands, then systems in list order, then the clock advances.
func test_plain_tick_order() -> void:
	var simulation := _make_simulation(10)
	simulation.submit(FakeCommand.new(_log))
	simulation.advance_tick()
	assert_array(_log).contains_exactly(["command@10", "a.tick@10", "b.tick@10"])
	assert_int(simulation.state.clock.tick).is_equal(11)
	assert_bool(simulation.state.flags[&"fake_applied"]).is_true()


## A tick that starts a day runs on_day hooks after the clock advances, then signals.
func test_day_boundary_order() -> void:
	var simulation := _make_simulation(DAY - 1)
	simulation.submit(FakeCommand.new(_log))
	simulation.advance_tick()
	var expected: Array[String] = [
		"command@1439",
		"a.tick@1439",
		"b.tick@1439",
		"a.on_day@1440",
		"b.on_day@1440",
		"day_started(1)",
	]
	assert_array(_log).contains_exactly(expected)


## A tick that starts a month runs the day steps, then on_month hooks, then month_closed.
func test_month_boundary_order() -> void:
	var simulation := _make_simulation(31 * DAY - 1)
	simulation.advance_tick()
	var expected: Array[String] = [
		"a.tick@44639",
		"b.tick@44639",
		"a.on_day@44640",
		"b.on_day@44640",
		"day_started(31)",
		"a.on_month@44640",
		"b.on_month@44640",
		"month_closed(2026,1)",
	]
	assert_array(_log).contains_exactly(expected)


## day_started fires once per 1440 ticks with consecutive day indexes.
func test_day_started_fires_once_per_day() -> void:
	var simulation := Simulation.new(GameState.new_game(1))
	simulation.day_started.connect(_on_day_started)
	for i: int in 3 * DAY:
		simulation.advance_tick()
	assert_array(_log).contains_exactly(["day_started(1)", "day_started(2)", "day_started(3)"])


## month_closed reports each month that ended, across a year boundary and a leap February.
func test_month_closed_reports_ended_month() -> void:
	var state := GameState.new_game(1)
	state.clock.tick = (365 + 334) * DAY - 1  # 2027-11-30 23:59
	var simulation := Simulation.new(state)
	simulation.month_closed.connect(_on_month_closed)
	for i: int in (31 + 31 + 29) * DAY + 1:
		simulation.advance_tick()
	var expected: Array[String] = [
		"month_closed(2027,11)",
		"month_closed(2027,12)",
		"month_closed(2028,1)",
		"month_closed(2028,2)",
	]
	assert_array(_log).contains_exactly(expected)
	var march_first := {"year": 2028, "month": 3, "day": 1, "hour": 0, "minute": 0}
	assert_dict(TimeMath.date_of(state.clock.tick)).is_equal(march_first)


## A Simulation with no systems runs in isolation: no scene tree, no autoloads.
func test_runs_in_isolation_without_systems() -> void:
	var simulation := Simulation.new(GameState.new_game(7))
	for i: int in DAY:
		simulation.advance_tick()
	assert_int(simulation.state.clock.tick).is_equal(DAY)


## The Simulation source names no autoload, Node or scene-tree API.
func test_source_has_no_autoload_or_node_reference() -> void:
	var source: String = FileAccess.get_file_as_string(SIMULATION_PATH)
	assert_str(source).is_not_empty()
	for word: String in FORBIDDEN_WORDS:
		assert_bool(source.contains(word)).override_failure_message(word).is_false()


## Command rejections from the queue are forwarded by the Simulation.
func test_forwards_command_rejected() -> void:
	var simulation := Simulation.new(GameState.new_game(1))
	simulation.command_rejected.connect(_on_command_rejected)
	simulation.commands.command_rejected.emit(&"fake", &"ring_busy")
	assert_array(_log).contains_exactly(["command_rejected(fake,ring_busy)"])


## Commands submitted between ticks apply once, at the start of the next tick.
func test_submitted_command_applies_once() -> void:
	var simulation := _make_simulation(0)
	var result := simulation.submit(FakeCommand.new(_log))
	assert_bool(result.is_ok).is_true()
	simulation.advance_tick()
	simulation.advance_tick()
	assert_int(_log.count("command@0")).is_equal(1)
	assert_int(_log.count("command@1")).is_equal(0)
