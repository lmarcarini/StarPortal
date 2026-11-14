## Events slow the clock only while they last and never write the speed (M4.7-03).
## Bible: docs/content/event-time.md section 2
extends GdUnitTestSuite

var _state: GameState = null


func before_test() -> void:
	_state = GameState.new_game(3, Registry.balance())
	GameSetup.build_new(_state, GameDefs.from_registry(Registry))
	_state.clock.speed_index = 4


func _effective() -> int:
	return TimeControl.effective_speed_index(_state.clock)


func _phone() -> PendingContact:
	var contact := PendingContact.new()
	contact.faction = &"kindred"
	contact.channel = &"phone"
	return contact


func test_a_waiting_call_slows_until_it_goes() -> void:
	_state.factions.pending.append(_phone())
	SlowRules.sync(_state)
	assert_int(_effective()).is_equal(1)
	_state.factions.pending.clear()
	SlowRules.sync(_state)
	assert_int(_effective()).is_equal(4)
	assert_int(_state.clock.speed_index).is_equal(4)


func test_an_overridden_call_stays_fast_and_forgets_when_it_ends() -> void:
	_state.factions.pending.append(_phone())
	SlowRules.sync(_state)
	TimeControl.override(_state.clock)
	SlowRules.sync(_state)
	assert_int(_effective()).is_equal(4)
	_state.factions.pending.clear()
	SlowRules.sync(_state)
	assert_array(_state.clock.overridden).is_empty()


func test_the_rescue_waits_for_a_signal() -> void:
	_state.expedition.mode = ExpeditionState.Mode.MISSING
	SlowRules.sync(_state)
	assert_int(_effective()).is_equal(1)
	_state.expedition.signal_tick = 10
	SlowRules.sync(_state)
	assert_int(_effective()).is_equal(4)


## Only the player's speed commands (SimClock and ClockState loading) write speed_index. The
## gate's lock drop is removed by M4.7-04 (#399), which takes gate_system.gd off this list.
func test_nothing_else_writes_the_speed() -> void:
	var allowed: Array[String] = [
		"res://src/core/systems/gate_system.gd",
		"res://src/core/sim_clock.gd",
		"res://src/core/state/clock_state.gd"
	]
	var offenders: Array[String] = []
	_scan("res://src", allowed, offenders)
	assert_array(offenders).is_empty()


func _scan(path: String, allowed: Array[String], offenders: Array[String]) -> void:
	for dir_name: String in DirAccess.get_directories_at(path):
		_scan(path.path_join(dir_name), allowed, offenders)
	var pattern := RegEx.create_from_string("speed_index\\s*=[^=]")
	for file_name: String in DirAccess.get_files_at(path):
		var file_path: String = path.path_join(file_name)
		if not file_name.ends_with(".gd") or allowed.has(file_path):
			continue
		if pattern.search(FileAccess.get_file_as_string(file_path)) != null:
			offenders.append(file_path)
