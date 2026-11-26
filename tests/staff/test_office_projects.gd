## M7-05: the Office projects (O01-O14) and their effects. The HR tiers (O01-O06) only set
## flags until the recruitment cards read them.
## Bible: docs/content/research-and-progression.md section 10
extends GdUnitTestSuite

var _state: GameState


func before_test() -> void:
	_state = ResearchFixture.state()
	UnlockFixture.defence_plans(_state)


func _done(project: StringName) -> void:
	_state.research.revealed.append(project)
	ResearchSystem.finish(_state, _state.research_defs[project], &"")


func _shown() -> Array[StringName]:
	var found: Array[StringName] = []
	for def: ResearchDef in ResearchRules.visible_projects(_state, &"office"):
		found.append(def.id)
	return found


func test_office_opens_with_the_personnel_office() -> void:
	assert_array(_shown()).is_empty()
	var office: RoomState = _state.base.add_room(&"room_personnel_office", 1, Vector2i(24, 11))
	assert_object(office).is_not_null()
	assert_array(_shown()).contains(
		[&"headhunter_network_1", &"recruitment_drive_1", &"fast_track_1", &"shift_system"]
	)
	assert_array(_shown()).not_contains(
		[&"squad_doctrine", &"expedition_training", &"committee_liaison", &"black_funds"]
	)
	_state.base.add_room(&"room_security_post", 1, Vector2i(30, 8))
	_state.base.add_room(&"room_ready_room", 1, Vector2i(30, 12))
	assert_array(_shown()).contains([&"squad_doctrine", &"expedition_training"])


func test_hr_tiers_set_their_flags() -> void:
	_done(&"headhunter_network_1")
	_done(&"recruitment_drive_2")
	assert_bool(ResearchPerks.has(_state, &"hr_candidate_tier_2")).is_true()
	assert_bool(ResearchPerks.has(_state, &"hr_batch_7")).is_true()


func test_committee_liaison_emergency_funds_monthly() -> void:
	var ask := AskEmergencyFundsCommand.new()
	assert_bool(ask.validate(_state).is_ok).is_false()
	_done(&"committee_liaison")
	var funds: int = _state.budget.funds_k
	assert_bool(ConstructionFixture.run(_state, ask).is_ok).is_true()
	assert_int(_state.budget.funds_k).is_equal(funds + OfficePerks.FUNDS_K)
	assert_bool(ask.validate(_state).is_ok).is_false()
	_state.clock.tick += OfficePerks.FUNDS_EVERY_DAYS * TimeMath.TICKS_PER_DAY
	assert_bool(ask.validate(_state).is_ok).is_true()


func test_squad_doctrine_falls_back_when_losing() -> void:
	var post: RoomState = _state.base.add_room(&"room_security_post", 1, Vector2i(30, 8))
	var squad := SquadState.new()
	squad.post_room = post.id
	squad.order = SquadState.Order.MOVE
	for index: int in 2:
		var person := PersonState.new()
		person.id = StringName("s%d" % index)
		person.role = SquadRules.SOLDIER
		person.room_id = post.id
		_state.staff.people.append(person)
		_state.security.health[person.id] = 2
	assert_bool(OfficePerks.auto_fall_back(_state, squad)).is_false()
	_done(&"squad_doctrine")
	assert_bool(OfficePerks.auto_fall_back(_state, squad)).is_true()
	assert_int(squad.order).is_equal(SquadState.Order.FALL_BACK)


func test_rapid_response_expedition_training_survival_shift() -> void:
	var cells: int = OfficePerks.squad_cells_per_tick(_state)
	_done(&"rapid_response")
	assert_int(OfficePerks.squad_cells_per_tick(_state)).is_equal(cells * 2)
	assert_int(OfficePerks.team_size(_state)).is_equal(4)
	_done(&"expedition_training")
	assert_int(OfficePerks.team_size(_state)).is_equal(5)
	var plan := ExpeditionState.new()
	plan.objective = ExpeditionState.Objective.SURVEY
	plan.world_id = &"nowhere"
	assert_bool(ExpeditionRules.is_blind(_state, plan)).is_true()
	_done(&"survival_training")
	assert_bool(ExpeditionRules.is_blind(_state, plan)).is_false()
	_done(&"shift_system")
	assert_int(ModifierRules.total(_state, &"research_speed_pct")).is_equal(50)
