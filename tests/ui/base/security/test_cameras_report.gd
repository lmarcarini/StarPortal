## Cameras and the after-action report (M4c-13): intruders show in a lit room's feed and not
## in a dark one; the report lists attacker, objective, result, damage, injuries and the
## Confidence change; incursion_ended writes a Log line.
## Bible: docs/content/m4c-incursions.md section 7
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = GameState.new_game(9, Registry.balance())
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	var unit := UnitDef.new()
	unit.id = &"unit_raider"
	unit.health = 8
	_state.unit_defs[unit.id] = unit
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = &"faction_ossar"
	def.group_units = [unit.id]
	def.group_counts = [2]
	def.objective = &"sabotage"
	_state.incursion_defs[def.id] = def


func _plant() -> RoomState:
	for room: RoomState in _state.base.rooms:
		if room.def_id == ObjectiveRules.POWER_PLANT_DEF:
			return room
	return null


func test_feeds_follow_sight() -> void:
	IncursionRules.start(_state, &"incursion_test")
	IncursionRules.breach(_state)
	var plant: RoomState = _plant()
	_state.incursion.groups[0].move_to(Vector3i(plant.origin.x, plant.origin.y, plant.level))
	var people: Array[FeedPerson] = FeedIntruders.in_room(_state, plant)
	assert_int(people.size()).is_equal(2)
	assert_str(String(people[0].kind())).is_equal("intruder")
	plant.damaged = true
	assert_array(FeedIntruders.in_room(_state, plant)).is_empty()


func test_report_lines_and_log() -> void:
	var report: Dictionary = {
		"def": "incursion_test",
		"objective": "sabotage",
		"outcome": "done",
		"damaged": [String(_plant().id)],
		"injured": ["soldier_a"],
		"confidence": -11,
	}
	var lines: Array[String] = AfterActionText.lines(report, _state)
	assert_str(lines[1]).is_equal("Objective: sabotage")
	assert_str(lines[2]).contains("did what they came for")
	assert_str("\n".join(lines)).contains("Injured: 1")
	assert_str(lines[lines.size() - 1]).is_equal("Confidence: -11")
	var entries: Array[LogEntry] = LogRules.entries_for(&"incursion_ended", [report], _state, 5)
	assert_str(String(entries[0].kind)).is_equal("incursion")
	assert_str(ArchiveLogRow.line_for(entries[0], _state)).contains("did what they came for")


func test_the_log_entry_survives_a_save() -> void:
	var report: Dictionary = {
		"def": "incursion_test", "outcome": "done", "damaged": ["room_3"], "lost": [1]
	}
	var entry: LogEntry = LogRules.entries_for(&"incursion_ended", [report], _state, 5)[0]
	var saved: Dictionary = JSON.parse_string(JSON.stringify(entry.to_dict()))
	assert_array(LogEntry.validate_dict(saved)).is_empty()
	assert_str("\n".join(AfterActionText.lines(entry.args, _state))).contains("Artefacts lost: 1")
