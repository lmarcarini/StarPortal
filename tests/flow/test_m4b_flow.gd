## The M4b loop through commands on the real content (M4-36): a request reward brings the Loom
## into holding; build a Vault and house it, and its research speed modifier counts; study it
## and its follow-up shows; queue three projects; the Effigy, which no Vault takes, sets off its
## hazard in holding (seeded) until it is housed in Containment.
## Bible: docs/content/m4-core-systems.md sections 5 to 7
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_state = GameState.new_game(7, defs.balance)
	UnlockFixture.defence_plans(_state)
	_simulation = GameSetup.build_new(_state, defs).value
	_state.clock.mode = ClockState.Mode.RUNNING
	_state.budget.funds_k += 20000
	# The Vault needs Secure storage (owner change 2026-11-14); its research is not this test.
	UnlockFixture.apply_project(_state.unlocks, &"artefact_vault")


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func _submit(command: Command) -> void:
	var result: CommandResult = _simulation.submit(command)
	(
		assert_bool(result.is_ok)
		. override_failure_message("%s refused: %s" % [command.get_type(), result.error_code])
		. is_true()
	)
	_ticks(1)


## Places [param def_id] next to the Gate Room and waits until it stands; returns its uid.
func _build(def_id: StringName) -> int:
	var gate: RoomState = BaseSpots.gate_room(_state.base)
	var target: Rect2i = BaseRules.footprint(gate, _state.room_defs[gate.def_id])
	var spot: Vector2i = BaseSpots.nearest_spot(
		_state.base, _state.room_defs, def_id, gate.level, target
	)
	_submit(PlaceRoomCommand.create(def_id, gate.level, spot))
	var room: RoomState = PowerFixture.first_room(_state, def_id)
	for guard: int in 60 * TimeMath.TICKS_PER_DAY:
		if room.is_built():
			break
		_ticks(1)
	assert_bool(room.is_built()).is_true()
	return ArtefactRules.room_uid_of(room.id)


## Runs the hazard roll for [param days] days; returns how many hazards went off.
func _hazard_days(days: int) -> int:
	var system := ArtefactSystem.new()
	var hits: int = 0
	for day: int in days:
		system.on_day(_state)
		for event: SimEvent in _state.events.drain():
			hits += int(event.name == &"artefact_hazard")
	return hits


func _uid_of(artefact: StringName) -> int:
	for record: ArtefactRecord in _state.artefacts.items:
		if record.artefact == artefact:
			return record.uid
	return -1


func test_m4b_loop() -> void:
	# A request reward: the Loom arrives in holding.
	var request: RequestDef = Registry.get_def(&"request_kindred_research")
	StoryRules.apply_all(_state, request.reward, request.id)
	var loom: int = _uid_of(&"kindred_loom")
	assert_array(ArtefactRules.holding(_state)).contains([loom])
	assert_int(ModifierRules.total(_state, &"research_speed_pct")).is_equal(0)
	# Build a Vault, house it; its modifier counts.
	var vault: int = _build(&"room_artefact_vault")
	_submit(HouseArtefactCommand.new(loom, vault))
	assert_int(ArtefactRules.find(_state, loom).room_uid).is_equal(vault)
	assert_int(ModifierRules.total(_state, &"research_speed_pct")).is_equal(15)
	# Study it in a Research Lab; the follow-up shows.
	_build(&"room_research_lab")
	_submit(
		SwitchRoomCommand.create(PowerFixture.first_room(_state, &"room_research_lab").id, true)
	)
	var pedagogy: ResearchDef = _state.research_defs[&"loom_translator"]
	assert_bool(ResearchRules.visible(_state, pedagogy)).is_false()
	ResearchFixture.finish(_state, &"study_kindred_loom")
	assert_int(ArtefactRules.find(_state, loom).state).is_equal(
		ArtefactRecord.ArtefactState.STUDIED
	)
	_state.research.done.append(&"xenolinguistics")
	assert_bool(ResearchRules.visible(_state, pedagogy)).is_true()
	# Queue three visible projects behind the running one.
	ResearchFixture.workshop(_state)
	_submit(StartResearchCommand.create(&"excavation_survey"))
	var lab_id: StringName = PowerFixture.first_room(_state, &"room_research_lab").id
	var queued: Array[StringName] = []
	for def: ResearchDef in ResearchRules.visible_projects(_state):
		if queued.size() < 3 and ResearchRules.queue_error(_state, def.id, lab_id).is_empty():
			_submit(QueueResearchCommand.new(def.id, lab_id))
			queued.append(def.id)
	var bench: ResearchBench = _state.research.bench_of(lab_id)
	var held: Array[StringName] = bench.queue.duplicate()
	if bench.is_running():
		held.push_front(bench.active)
	assert_array(held).is_equal(queued)
	assert_int(queued.size()).is_greater_equal(2)
	# The Effigy: a Vault refuses it, and in holding its hazard goes off.
	StoryRulesItems.give_artefact(_state, &"ossar_effigy")
	var effigy: int = _uid_of(&"ossar_effigy")
	assert_str(String(ArtefactRules.house_error(_state, effigy, vault))).is_equal("wrong_class")
	_state.events.drain()
	assert_int(_hazard_days(30)).is_greater(0)
	# Containment (unlocked as later_containment would) stops it.
	_state.unlocks.rooms.append(&"room_containment")
	var containment: int = _build(&"room_containment")
	_submit(HouseArtefactCommand.new(effigy, containment))
	_state.events.drain()
	assert_int(_hazard_days(30)).is_equal(0)
	assert_int(ModifierRules.total(_state, &"dial_cost_pct")).is_less_equal(0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
