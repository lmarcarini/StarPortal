## M7-04: the Engineering (E01-E24) and Science (S01-S13) projects as data, what shows at the
## start and what reveals the rest, and each project's effect.
## Bible: docs/content/research-and-progression.md section 10
extends GdUnitTestSuite

const ProbeFixture := preload("res://tests/gate/probe_fixture.gd")

var _state: GameState


func before_test() -> void:
	TranslationServer.set_locale("en")
	_state = ResearchFixture.state()


func _shown() -> Array[StringName]:
	var found: Array[StringName] = []
	for def: ResearchDef in ResearchRules.visible_projects(_state):
		found.append(def.id)
	return found


func _done(project: StringName) -> void:
	_state.research.revealed.append(project)
	ResearchSystem.finish(_state, _state.research_defs[project], &"")


func test_the_start_shows_e01_to_e04_and_s01_then_s02_after_a_lock() -> void:
	var start: Array[StringName] = [
		&"excavation_survey",
		&"plan_personnel_office",
		&"survey_drones",
		&"bank_array",
		&"gate_calibration",
	]
	for project: StringName in start:
		assert_array(_shown()).contains([project])
	for def: ResearchDef in ResearchRules.visible_projects(_state):
		if def.discipline in [&"engineering", &"science"] and def.order < 29:
			assert_array(start).override_failure_message(String(def.id)).contains([def.id])
	ProgressCounters.count(_state, &"dial_resolved", [DialOutcome.Kind.LOCK])
	assert_array(_shown()).contains([&"horizon_photography"])


func test_reveal_conditions() -> void:
	var cases: Array = [
		[&"canister_launched", &"sample_canister"],
		[&"team_sent", &"plan_ready_room"],
		[&"incursion_warning", &"origin_tracing"],
	]
	_done(&"gate_calibration")
	for case: Array in cases:
		var event: StringName = case[0]
		var project: StringName = case[1]
		assert_array(_shown()).not_contains([project])
		ProgressCounters.count(_state, event, [])
		assert_array(_shown()).contains([project])
	assert_array(_shown()).not_contains([&"xenolinguistics"])
	ProgressCounters.count(_state, &"conversation_started", [&"c", &"phone"])
	assert_array(_shown()).not_contains([&"xenolinguistics"])
	ProgressCounters.count(_state, &"conversation_started", [&"c", &"wormhole"])
	assert_array(_shown()).contains([&"xenolinguistics"])


func test_held_things_reveal_plans() -> void:
	assert_array(_shown()).not_contains([&"xenoarchaeology", &"artefact_vault", &"exobiology"])
	StoryRulesItems.give_artefact(_state, &"kindred_loom")
	assert_array(_shown()).contains([&"xenoarchaeology", &"artefact_vault"])
	_state.galaxy = ProbeFixture.galaxy()
	for world: WorldRecord in _state.galaxy.all_worlds():
		if SpecimenRules.add(_state, world.id) >= 0:
			break
	assert_array(_shown()).contains([&"exobiology"])


func test_ten_locks_reveal_iris_studies_and_story_never_shows() -> void:
	for lock: int in 9:
		ProgressCounters.bump(_state, ProgressCounters.LOCKS)
	assert_array(_shown()).not_contains([&"iris_studies"])
	ProgressCounters.bump(_state, ProgressCounters.LOCKS)
	assert_array(_shown()).contains([&"iris_studies"])
	_done(&"field_camp")
	_done(&"wormhole_stabiliser")
	assert_array(_shown()).not_contains([&"outpost_kit", &"long_range_dialing"])


func test_plans_and_boosts() -> void:
	_done(&"plan_personnel_office")
	assert_bool(_state.unlocks.has_room(&"room_personnel_office")).is_true()
	_done(&"plan_security_post")
	assert_bool(_state.unlocks.has_room(&"room_security_post")).is_true()
	_done(&"prefab_modules")
	assert_int(ModifierRules.total(_state, &"build_speed_pct")).is_equal(100)
	var minutes: int = GateQueries.max_open_ticks(_state)
	_done(&"wormhole_stabiliser")
	assert_int(GateQueries.max_open_ticks(_state)).is_equal(minutes * 2)
	var battery: int = MothRules.battery_minutes(_state)
	_done(&"moth_mk2")
	assert_int(MothRules.battery_minutes(_state)).is_equal(battery * 2)
	assert_bool(_state.flags.get(SpecimenRules.SAMPLER_FLAG, false)).is_true()


func test_blast_doors_need_their_plan() -> void:
	var refused: CommandResult = DoorRules.can_build(_state, 1, Vector2i(0, 10))
	assert_str(String(refused.error_code)).is_equal("needs_research")
	assert_array(ResearchPerks.plans(_state)).not_contains([ResearchPerks.DOOR_ID])
	_done(&"blast_doors")
	assert_array(ResearchPerks.plans(_state)).contains([ResearchPerks.DOOR_ID])
	var after: CommandResult = DoorRules.can_build(_state, 1, Vector2i(0, 10))
	assert_str(String(after.error_code)).is_not_equal("needs_research")


func test_shutter_mk2_stops_a_wave_for_free() -> void:
	_state.gate.shutter = GateState.Shutter.CLOSED
	_state.power.stored_mwh = 0.0
	assert_bool(ShutterRules.stops_wave(_state, null)).is_false()
	_done(&"shutter_mk2")
	assert_bool(ShutterRules.stops_wave(_state, null)).is_true()
	assert_float(_state.power.stored_mwh).is_equal(0.0)


func test_field_camp_doubles_a_stay_and_is_refused_before() -> void:
	var command := SendTeamCommand.new(true)
	assert_str(String(command.validate(_state).error_code)).is_equal("needs_research")
	_state.expedition.objective = 1
	var days: int = _state.expedition.days()
	_state.expedition.long_stay = true
	assert_int(_state.expedition.days()).is_equal(days * 2)
	var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
	var rebuilt: SendTeamCommand = CommandFactory.from_dict(data).value
	assert_bool(rebuilt.long_stay).is_true()


func test_moth_relay_hails_through_any_wormhole() -> void:
	_state.gate.mode = GateState.RingMode.LOCKED
	_state.gate.connected_world_id = &"elsewhere"
	_state.expedition.world_id = &"team_world"
	_state.expedition.mode = ExpeditionState.Mode.AWAY
	assert_bool(TeamContactRules.can_hail_team(_state)).is_false()
	_done(&"moth_mk3")
	assert_bool(TeamContactRules.can_hail_team(_state)).is_true()


func test_atmospheric_sampling_records_hazards() -> void:
	_done(&"atmospheric_sampling")
	WorldProgress.record_hazards(_state, &"world_sill")
	var report: WorldReport = _state.worlds.reports.get(&"world_sill")
	assert_object(report).is_not_null()


func test_glyph_frequency_marks_the_clipped_glyphs() -> void:
	var doc := DocumentDef.new()
	doc.answer_glyphs = PackedInt32Array([9, 3, 5, 1, 7, 2, 4])
	assert_array(Array(GlyphFrequency.marked(_state, doc))).is_empty()
	_done(&"glyph_frequency")
	assert_array(Array(GlyphFrequency.marked(_state, doc))).is_equal([1, 2, 3, 4, 5, 7, 9])


func test_origin_tracing_names_the_caller_and_the_objective() -> void:
	for faction: FactionDef in GameDefs.from_registry(Registry).factions:
		_state.faction_defs[faction.id] = faction
	_state.gate.incoming_faction = &"faction_kindred"
	assert_str(OriginText.incoming(_state)).is_empty()
	_done(&"origin_tracing")
	assert_str(OriginText.incoming(_state)).is_equal(" · THE KINDRED")


func test_envoys_give_a_daily_favour() -> void:
	_state.faction_defs[&"faction_kindred"] = Registry.get_def(&"faction_kindred") as FactionDef
	FactionRules.meet(_state, &"faction_kindred")
	_state.factions.standing[&"faction_kindred"] = 10
	var before: int = FactionRules.standing(_state, &"faction_kindred")
	_state.flags[&"envoys_kindred"] = true
	FactionSystem.new().on_day(_state)
	assert_int(FactionRules.standing(_state, &"faction_kindred")).is_equal(before + 1)


func test_gate_calibration_marks_the_need() -> void:
	var gauge := ChargeGauge.new()
	add_child(gauge)
	gauge.show_state(_state, 50.0)
	assert_float(gauge.get_need_share()).is_equal(-1.0)
	_done(&"gate_calibration")
	gauge.show_state(_state, 50.0)
	assert_float(gauge.get_need_share()).is_greater_equal(0.0)
	gauge.free()


func test_xenolinguistics_glosses_alien_text() -> void:
	var rubbing: DocumentDef = Registry.get_def(&"doc_lintel_rubbing") as DocumentDef
	assert_str(DocumentText.gloss(rubbing, _state)).is_empty()
	_done(&"xenolinguistics")
	assert_str(DocumentText.gloss(rubbing, _state)).contains("Partial translation")
	var note: DocumentDef = Registry.get_def(&"doc_lintel_note") as DocumentDef
	assert_str(DocumentText.gloss(note, _state)).is_empty()
