## Tests for HireCommand and DismissCommand: the first list, fees, beds, money, arrival delays
## and dismissal (docs/content/m26-staff-and-money.md sections 2 and 7).
## Bible: docs/content/m26-staff-and-money.md sections 2 and 7
extends GdUnitTestSuite

const MOREAU: StringName = &"candidate_1"
const KOWALSKI: StringName = &"candidate_3"
const MIRA: StringName = &"person_5"

var _game: GameState


func before_test() -> void:
	_game = ConstructionFixture.state()
	_game.events.drain()


func _code(command: Command) -> StringName:
	return ConstructionFixture.run(_game, command).error_code


func test_new_game_has_the_fixed_first_list() -> void:
	var names: Array[String] = []
	for candidate: CandidateState in _game.recruitment.candidates:
		names.append(candidate.name)
		assert_int(candidate.skill).is_equal(3)
		assert_int(candidate.salary_k).is_equal(30)
	assert_array(names).is_equal(
		["Dr Ines Moreau", "Dr Kenji Arai", "Sgt Dan Kowalski", "Cpl Sara Lind"]
	)
	assert_str(_game.recruitment.candidates[0].role).is_equal(&"role_scientist")
	assert_str(_game.recruitment.candidates[2].role).is_equal(&"role_engineer")
	assert_int(_game.recruitment.candidates[0].arrival_ticks).is_equal(5 * 1440)
	assert_int(_game.recruitment.candidates[2].arrival_ticks).is_equal(3 * 1440)
	assert_str(_game.recruitment.candidates[0].id).is_equal(MOREAU)


func test_hire_charges_the_fee_and_reserves_a_bed() -> void:
	_game.clock.tick = 100
	var funds: int = _game.budget.funds_k
	assert_int(StaffRules.beds_free(_game)).is_equal(1)
	assert_str(_code(HireCommand.create(MOREAU))).is_empty()
	assert_int(_game.budget.funds_k).is_equal(funds - 30)
	assert_int(StaffRules.beds_free(_game)).is_equal(0)
	var person: PersonState = _game.staff.people.back()
	assert_str(person.name).is_equal("Dr Ines Moreau")
	assert_int(person.arrives_tick).is_equal(100 + 5 * 1440)
	assert_int(person.salary_k).is_equal(30)
	assert_bool(person.is_assigned()).is_false()
	assert_bool(person.is_on_base(100)).is_false()
	assert_object(_game.recruitment.find_candidate(MOREAU)).is_null()
	assert_array(ConstructionFixture.event_names(_game)).is_equal(
		[&"budget_changed", &"candidates_changed", &"staff_changed"]
	)


func test_hire_is_refused_without_a_free_bed() -> void:
	assert_str(_code(HireCommand.create(MOREAU))).is_empty()
	assert_str(_code(HireCommand.create(KOWALSKI))).is_equal(RecruitmentRules.NO_FREE_BED)
	assert_object(_game.recruitment.find_candidate(KOWALSKI)).is_not_null()


func test_hire_is_refused_with_too_little_money() -> void:
	_game.budget.funds_k = 29
	assert_str(_code(HireCommand.create(MOREAU))).is_equal(BudgetState.INSUFFICIENT_FUNDS)
	assert_int(_game.staff.people.size()).is_equal(5)


func test_hire_is_refused_for_an_unknown_candidate() -> void:
	assert_str(_code(HireCommand.create(&"candidate_99"))).is_equal(
		RecruitmentRules.UNKNOWN_CANDIDATE
	)


func test_dismiss_frees_the_bed_and_unassigns_without_refund() -> void:
	var funds: int = _game.budget.funds_k
	assert_str(_code(HireCommand.create(MOREAU))).is_empty()
	_game.events.drain()
	assert_str(_code(DismissCommand.create(MIRA))).is_empty()
	assert_object(_game.staff.find_person(MIRA)).is_null()
	assert_int(StaffRules.beds_free(_game)).is_equal(1)
	assert_int(_game.budget.funds_k).is_equal(funds - 30)
	var events: Array[SimEvent] = _game.events.drain()
	assert_array(events[0].args).is_equal([&"dismissed", &"room_control", 1])


func test_dismiss_cancels_a_person_still_arriving() -> void:
	assert_str(_code(HireCommand.create(MOREAU))).is_empty()
	var arriving: PersonState = _game.staff.people.back()
	assert_str(_code(DismissCommand.create(arriving.id))).is_empty()
	assert_int(_game.staff.people.size()).is_equal(5)
	assert_int(StaffRules.beds_free(_game)).is_equal(1)


func test_dismiss_is_refused_for_an_unknown_person() -> void:
	assert_str(_code(DismissCommand.create(&"person_99"))).is_equal(RecruitmentRules.UNKNOWN_PERSON)


func test_commands_round_trip_through_the_factory() -> void:
	for command: Command in [HireCommand.create(MOREAU), DismissCommand.create(MIRA)]:
		var rebuilt: Result = CommandFactory.from_dict(command.to_dict())
		assert_bool(rebuilt.is_ok).is_true()
		var back: Command = rebuilt.value
		assert_dict(back.to_dict()).is_equal(command.to_dict())
	assert_bool(CommandFactory.from_dict({"type": "hire"}).is_ok).is_false()
	assert_bool(CommandFactory.from_dict({"type": "dismiss", "person_id": 3}).is_ok).is_false()
