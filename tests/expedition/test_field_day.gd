## Tests for ExpeditionFieldDay: each field day draws and rolls one event, posts its outcome,
## and its setbacks injure the roller (a medic softens a serious injury), waste the day or
## miss the check-in.
## Bible: docs/content/m3-beyond-the-ring.md section 4 (Risk model)
extends GdUnitTestSuite

const ExpeditionFixture := preload("res://tests/expedition/expedition_fixture.gd")


func _away() -> GameState:
	var game: GameState = ExpeditionFixture.state()
	var plan: ExpeditionState = game.expedition
	plan.set_plan(
		ExpeditionState.Objective.SURVEY,
		ExpeditionFixture.WORLD_ID,
		&"",
		ExpeditionFixture.team(game)
	)
	plan.mode = ExpeditionState.Mode.AWAY
	plan.departed_tick = 0
	return game


func _person(role: StringName) -> PersonState:
	var person := PersonState.new()
	person.role = role
	person.skill = 3
	return person


func test_each_day_posts_one_event_matching_its_result() -> void:
	var seen: Dictionary[String, int] = {}
	for seed: int in 200:
		var game: GameState = _away()
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var result: String = ExpeditionFieldDay.resolve(game, 0, rng)
		var events: Array[SimEvent] = game.events.drain()
		assert_int(events.size()).is_equal(1)
		assert_str(String(events[0].name)).is_equal(String(ExpeditionFieldDay.EVENT))
		var outcome: String = events[0].args[2]
		var event_id: StringName = events[0].args[1]
		assert_object(FieldEvents.find(event_id)).is_not_null()
		seen[outcome] = seen.get(outcome, 0) + 1
		var expected: String = ExpeditionState.DAY_OK
		if outcome == "wasted":
			expected = ExpeditionState.DAY_WASTED
		elif outcome == "missed":
			expected = ExpeditionState.DAY_MISSED
		assert_str(result).is_equal(expected)
		var hurt: int = (
			game.staff.people.filter(func(p: PersonState) -> bool: return p.is_injured()).size()
		)
		assert_int(hurt).is_equal(1 if outcome in ["light", "serious"] else 0)
	assert_bool(seen.has(ExpeditionFieldDay.FINDING)).is_true()
	assert_bool(seen.has("light")).is_true()
	assert_bool(seen.has("wasted")).is_true()


func test_setbacks_injure_the_roller() -> void:
	var roller: PersonState = _person(StartingStaff.SOLDIER)
	var members: Array[PersonState] = [roller]
	var light: String = ExpeditionFieldDay._apply_setback(
		FieldEventDef.Setback.LIGHT, roller, members
	)
	assert_str(light).is_equal("light")
	assert_int(roller.injury).is_equal(PersonState.Injury.LIGHT)
	ExpeditionFieldDay._apply_setback(FieldEventDef.Setback.SERIOUS, roller, members)
	assert_int(roller.injury).is_equal(PersonState.Injury.SERIOUS)
	var other: PersonState = _person(StartingStaff.SOLDIER)
	members = [other]
	var missed: String = ExpeditionFieldDay._apply_setback(
		FieldEventDef.Setback.MISSED, other, members
	)
	assert_str(missed).is_equal("missed")
	assert_bool(other.is_injured()).is_false()


func test_medic_turns_serious_into_light() -> void:
	var roller: PersonState = _person(StartingStaff.ENGINEER)
	var members: Array[PersonState] = [roller, _person(StartingStaff.MEDIC)]
	var outcome: String = ExpeditionFieldDay._apply_setback(
		FieldEventDef.Setback.SERIOUS, roller, members
	)
	assert_str(outcome).is_equal("light")
	assert_int(roller.injury).is_equal(PersonState.Injury.LIGHT)


func test_day_results_of_outcomes() -> void:
	assert_str(ExpeditionFieldDay._day_result("missed")).is_equal(ExpeditionState.DAY_MISSED)
	assert_str(ExpeditionFieldDay._day_result("wasted")).is_equal(ExpeditionState.DAY_WASTED)
	assert_str(ExpeditionFieldDay._day_result("serious")).is_equal(ExpeditionState.DAY_OK)
	assert_str(ExpeditionFieldDay._day_result("finding")).is_equal(ExpeditionState.DAY_OK)


## Through the real ExpeditionSystem: a Survey's two days each resolve one field event.
func test_system_resolves_one_event_per_field_day() -> void:
	var game: GameState = ExpeditionFixture.state()
	var simulation: Simulation = ExpeditionFixture.simulation(game, true)
	var names: Array[StringName] = []
	simulation.event_posted.connect(
		func(event_name: StringName, _args: Array) -> void: names.append(event_name)
	)
	assert_bool(simulation.submit(ExpeditionFixture.survey(game)).is_ok).is_true()
	ExpeditionFixture.ProbeFixture.open(simulation)
	assert_bool(simulation.submit(SendTeamCommand.new()).is_ok).is_true()
	ExpeditionFixture.advance(simulation, 2 * ExpeditionFixture.DAY + 1)
	var count: int = names.count(ExpeditionFieldDay.EVENT)
	assert_int(count).is_between(1, 2)
	if game.expedition.mode != ExpeditionState.Mode.MISSING:
		assert_int(count).is_equal(2)
