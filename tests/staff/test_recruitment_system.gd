## Tests for RecruitmentSystem and RecruitmentRules: the rolling list (an arrival every 3 days,
## leave days fixed at arrival + 12), the skill odds, arrivals with their Log line, and the save
## of the list and of people still arriving.
## Bible: docs/content/m27-daily-rhythm.md section 3, m26-staff-and-money.md sections 2 and 8
extends GdUnitTestSuite

var _defs: GameDefs
var _game: GameState
var _system: RecruitmentSystem


func before_test() -> void:
	_defs = GameDefs.from_registry(Registry)
	_game = ConstructionFixture.state()
	_system = RecruitmentSystem.new(_defs.balance, _defs.roles, _defs.staff_names)


func _names(game: GameState) -> Array[String]:
	var names: Array[String] = []
	for candidate: CandidateState in game.recruitment.candidates:
		names.append("%s|%s|%d" % [candidate.name, candidate.role, candidate.skill])
	return names


## Runs the settlements of days 1 to [param last_day] on [param game], checking at each that
## leave days never move and the list keeps a scientist and an engineer.
func _run_days(game: GameState, last_day: int) -> void:
	var seen: Dictionary[StringName, int] = {}
	for day: int in range(1, last_day + 1):
		game.clock.tick = day * TimeMath.TICKS_PER_DAY
		_system.on_day(game)
		var roles: Array[StringName] = []
		for candidate: CandidateState in game.recruitment.candidates:
			roles.append(candidate.role)
			assert_int(candidate.leaves_day).is_greater(day)
			assert_int(seen.get(candidate.id, candidate.leaves_day)).is_equal(candidate.leaves_day)
			seen[candidate.id] = candidate.leaves_day
		assert_array(roles).contains([&"role_scientist", &"role_engineer"])


func test_first_list_leaves_on_days_3_6_9_12() -> void:
	var leaves: Array[int] = []
	for candidate: CandidateState in _game.recruitment.candidates:
		leaves.append(candidate.leaves_day)
	assert_array(leaves).is_equal([3, 6, 9, 12])
	assert_str(_game.recruitment.candidates[0].name).is_equal("Dr Ines Moreau")


func test_thirty_days_roll_the_list() -> void:
	_game.clock.tick = 2 * TimeMath.TICKS_PER_DAY
	_system.on_day(_game)
	assert_array(_game.events.drain()).is_empty()
	_run_days(_game, 30)
	var list: Array[CandidateState] = _game.recruitment.candidates
	assert_int(list.size()).is_equal(4)
	var leaves: Array[int] = []
	for candidate: CandidateState in list:
		leaves.append(candidate.leaves_day)
	assert_array(leaves).is_equal([33, 36, 39, 42])
	assert_str(list[3].id).is_equal(&"candidate_14")
	for candidate: CandidateState in list:
		assert_int(candidate.salary_k).is_equal(15 + 5 * candidate.skill)
		var days: int = _defs.balance.hire_arrival_days[candidate.role]
		assert_int(candidate.arrival_ticks).is_equal(days * 1440)


func test_arrival_replaces_the_oldest_and_posts_no_log() -> void:
	_game.clock.tick = 3 * TimeMath.TICKS_PER_DAY
	_system.on_day(_game)
	var list: Array[CandidateState] = _game.recruitment.candidates
	assert_int(list.size()).is_equal(4)
	assert_object(_game.recruitment.find_candidate(&"candidate_1")).is_null()
	assert_str(list[3].id).is_equal(&"candidate_5")
	assert_int(list[3].leaves_day).is_equal(15)
	var events: Array[SimEvent] = _game.events.drain()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].name).is_equal(&"candidates_changed")
	assert_array(LogRules.entries_for(&"candidates_changed", [], _game, 0)).is_empty()


func test_full_list_replaces_the_oldest() -> void:
	_game.recruitment.candidates[0].leaves_day = 20
	_game.clock.tick = 3 * TimeMath.TICKS_PER_DAY
	_system.on_day(_game)
	var names: Array[String] = []
	for candidate: CandidateState in _game.recruitment.candidates:
		names.append(candidate.name)
	assert_int(names.size()).is_equal(4)
	assert_bool(names.has("Dr Kenji Arai")).is_false()
	assert_bool(names.has("Dr Ines Moreau")).is_true()


func test_hiring_leaves_a_gap_until_the_next_arrival() -> void:
	ConstructionFixture.run(_game, HireCommand.create(&"candidate_2"))
	_game.recruitment.candidates[0].leaves_day = 3
	_game.clock.tick = 3 * TimeMath.TICKS_PER_DAY
	_system.on_day(_game)
	assert_int(_game.recruitment.candidates.size()).is_equal(3)
	var leaves: Array[int] = []
	for candidate: CandidateState in _game.recruitment.candidates:
		leaves.append(candidate.leaves_day)
	assert_array(leaves).is_equal([9, 12, 15])


func test_missing_role_is_filled_first() -> void:
	_game.recruitment.remove_candidate(&"candidate_3")
	_game.recruitment.remove_candidate(&"candidate_4")
	_game.clock.tick = 3 * TimeMath.TICKS_PER_DAY
	_system.on_day(_game)
	assert_str(_game.recruitment.candidates.back().role).is_equal(&"role_engineer")


func test_the_draw_is_deterministic_across_save_and_load() -> void:
	_run_days(_game, 10)
	var data: Dictionary = JSON.parse_string(JSON.stringify(_game.to_dict()))
	var loaded: GameState = GameState.from_dict(data)
	assert_array(_names(loaded)).is_equal(_names(_game))
	_game.clock.tick = 10 * TimeMath.TICKS_PER_DAY
	loaded.clock.tick = _game.clock.tick
	for day: int in range(11, 31):
		_game.clock.tick = day * TimeMath.TICKS_PER_DAY
		loaded.clock.tick = _game.clock.tick
		_system.on_day(_game)
		_system.on_day(loaded)
	assert_dict(loaded.recruitment.to_dict()).is_equal(_game.recruitment.to_dict())
	var other: GameState = GameState.new_game(2, _defs.balance)
	_run_days(other, 30)
	assert_array(_names(other)).is_not_equal(_names(_game))


func test_skill_odds_follow_the_weights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for index: int in 10000:
		counts[RecruitmentRules.draw_skill(rng, _defs.balance.candidate_skill_weights) - 1] += 1
	var expected: Array[int] = [1000, 3500, 3500, 1500, 500]
	for index: int in 5:
		assert_int(counts[index]).is_between(expected[index] - 250, expected[index] + 250)


func test_arrival_posts_once_and_logs_a_line() -> void:
	_game.clock.tick = 10
	ConstructionFixture.run(_game, HireCommand.create(&"candidate_3"))
	_game.events.drain()
	var person: PersonState = _game.staff.people.back()
	_game.clock.tick = person.arrives_tick - 2
	_system.tick(_game)
	assert_array(_game.events.drain()).is_empty()
	_game.clock.tick += 1
	_system.tick(_game)
	var events: Array[SimEvent] = _game.events.drain()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].name).is_equal(&"staff_arrived")
	_game.clock.tick += 1
	assert_bool(person.is_on_base(_game.clock.tick)).is_true()
	var entries: Array[LogEntry] = LogRules.entries_for(
		&"staff_arrived", events[0].args, _game, _game.clock.tick
	)
	assert_int(entries.size()).is_equal(1)
	assert_str(ArchiveLogRow.staff_line(entries[0].args)).is_equal(
		"Sgt Dan Kowalski (Engineer, skill 3) has arrived."
	)
	_system.tick(_game)
	assert_array(_game.events.drain()).is_empty()


func test_save_keeps_the_list_and_people_arriving() -> void:
	ConstructionFixture.run(_game, HireCommand.create(&"candidate_1"))
	var data: Dictionary = JSON.parse_string(JSON.stringify(_game.to_dict()))
	assert_array(GameState.validate_dict(data, _defs)).is_empty()
	var back: GameState = GameState.from_dict(data)
	assert_dict(back.recruitment.to_dict()).is_equal(_game.recruitment.to_dict())
	var hired: PersonState = back.staff.people.back()
	assert_int(hired.arrives_tick).is_equal(5 * 1440)


func test_bad_recruitment_data_is_rejected() -> void:
	var data: Dictionary = JSON.parse_string(JSON.stringify(_game.to_dict()))
	data["recruitment"]["candidates"][0]["role"] = "role_pilot"
	assert_array(GameState.validate_dict(data, _defs)).is_not_empty()
	data = JSON.parse_string(JSON.stringify(_game.to_dict()))
	data["recruitment"]["candidates"][1]["id"] = "candidate_1"
	assert_array(GameState.validate_dict(data)).is_not_empty()
	data = JSON.parse_string(JSON.stringify(_game.to_dict()))
	data["recruitment"]["candidates"][0]["arrival_ticks"] = 0
	assert_array(GameState.validate_dict(data)).is_not_empty()
	data = JSON.parse_string(JSON.stringify(_game.to_dict()))
	data["recruitment"]["candidates"][0]["leaves_day"] = -1
	assert_array(GameState.validate_dict(data)).is_not_empty()
	data = JSON.parse_string(JSON.stringify(_game.to_dict()))
	var first: Dictionary = data["recruitment"]["candidates"][0]
	first.erase("leaves_day")
	assert_array(GameState.validate_dict(data)).is_empty()
	data = JSON.parse_string(JSON.stringify(_game.to_dict()))
	data.erase("recruitment")
	assert_array(GameState.validate_dict(data)).is_not_empty()
