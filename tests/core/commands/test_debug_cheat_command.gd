## DebugCheatCommand: every action through the queue, a "(cheat)" Log line, refused when
## cheats are off, and a save after cheating loads.
## Bible: docs/bible/technical-architecture.md#testing-and-tooling (M4.6-04)
extends GdUnitTestSuite

var _simulation: Simulation = null
var _state: GameState = null


func before_test() -> void:
	DebugCheatCommand.force_enabled = 1
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_state = GameState.new_game(3, defs.balance)
	_simulation = GameSetup.build_new(_state, defs).value


func after_test() -> void:
	DebugCheatCommand.force_enabled = -1


func _cheat(action: StringName, id: StringName = &"", value: int = 0) -> CommandResult:
	var result: CommandResult = _simulation.submit(DebugCheatCommand.create(action, id, value))
	_simulation.advance_tick()
	return result


func test_funds_and_confidence() -> void:
	var before: int = _state.budget.funds_k
	assert_bool(_cheat(&"funds", &"", 500).is_ok).is_true()
	assert_int(_state.budget.funds_k).is_greater_equal(before + 400)
	_cheat(&"confidence", &"", 80)
	assert_int(_state.committee.confidence).is_equal(80)


func test_charge_fills_the_capacitors() -> void:
	_state.power.stored_mwh = 0.0
	_cheat(&"charge")
	assert_float(_state.power.stored_mwh).is_greater_equal(PowerRules.capacity_mwh(_state) - 1.0)


func test_finish_research_and_unlock_all() -> void:
	_state.research.active = &"excavation_survey"
	_cheat(&"finish_research")
	assert_bool(_state.research.is_done(&"excavation_survey")).is_true()
	_cheat(&"unlock_all_research")
	for id: StringName in _state.research_defs:
		assert_bool(_state.research.is_done(id)).override_failure_message(String(id)).is_true()


func test_finish_sites() -> void:
	var room: RoomState = _state.base.add_room(&"room_quarters", 1, Vector2i(30, 2))
	room.build_ticks_left = 500
	_cheat(&"finish_sites")
	assert_bool(room.is_built()).is_true()


func test_add_staff_heal_and_grant() -> void:
	var count: int = _state.staff.people.size()
	_cheat(&"add_staff", &"role_scientist", 4)
	assert_int(_state.staff.people.size()).is_equal(count + 1)
	var person: PersonState = _state.staff.people.back()
	assert_int(person.skill).is_equal(4)
	assert_bool(person.is_on_base(_state.clock.tick)).is_true()
	person.injury = PersonState.Injury.SERIOUS
	_cheat(&"heal_all")
	assert_int(person.injury).is_equal(PersonState.Injury.NONE)
	var artefact: StringName = _state.artefact_defs.keys()[0]
	var items: int = _state.artefacts.items.size()
	_cheat(&"grant_artefact", artefact)
	assert_int(_state.artefacts.items.size()).is_equal(items + 1)


func test_standing() -> void:
	var faction: StringName = _state.faction_defs.keys()[0]
	_cheat(&"standing", faction, 25)
	assert_int(FactionRules.standing(_state, faction)).is_equal(25)


func test_writes_a_cheat_log_line() -> void:
	_cheat(&"funds", &"", 10)
	var entry: LogEntry = _state.operations_log.entries.back()
	assert_str(ArchiveLogRow.line_for(entry, _state)).starts_with("(cheat) funds")


func test_refused_when_off_and_bad_input() -> void:
	DebugCheatCommand.force_enabled = 0
	assert_str(String(_cheat(&"funds", &"", 10).error_code)).is_equal("cheats_off")
	DebugCheatCommand.force_enabled = 1
	assert_str(String(_cheat(&"nope").error_code)).is_equal("bad_action")
	assert_str(String(_cheat(&"grant_artefact", &"nope").error_code)).is_equal("unknown_id")


func test_round_trips_and_a_save_after_cheating_loads() -> void:
	var command := DebugCheatCommand.create(&"funds", &"", 5)
	var back: Result = DebugCheatCommand.from_dict(command.to_dict())
	assert_bool(back.is_ok).is_true()
	_cheat(&"add_staff", &"role_engineer", 2)
	_cheat(&"unlock_all_research")
	var real_dir: String = SaveService.saves_dir
	SaveService.saves_dir = "user://test_cheat_%d" % Time.get_ticks_usec()
	assert_bool(SaveService.save_game(_state, &"after_cheat").is_ok).is_true()
	var loaded: Result = SaveService.load_game(&"after_cheat", GameDefs.from_registry(Registry))
	assert_bool(loaded.is_ok).override_failure_message(str(loaded.detail)).is_true()
	SaveService.delete_slot(&"after_cheat")
	DirAccess.remove_absolute(SaveService.saves_dir)
	SaveService.saves_dir = real_dir


func test_panel_toggles_and_submits() -> void:
	var panel: CheatPanel = auto_free(CheatPanel.new())
	add_child(panel)
	assert_bool(panel.visible).is_false()
	var event := InputEventAction.new()
	event.action = &"debug_toggle_cheats"
	event.pressed = true
	panel._unhandled_input(event)
	assert_bool(panel.visible).is_true()
