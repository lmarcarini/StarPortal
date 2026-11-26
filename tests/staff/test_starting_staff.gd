## Tests for the starting crew, beds, salaries and seeded names
## (docs/content/m26-staff-and-money.md sections 1, 3 and 7).
## Bible: docs/content/m26-staff-and-money.md sections 1, 3, 4 and 7
extends GdUnitTestSuite


## Five people with the section 7 names, roles, skills and salaries, $145k per 30 days; the
## analyst in the Control Room, everyone else Unassigned and on base.
func test_new_game_has_the_section_7_crew() -> void:
	var game: GameState = ConstructionFixture.state()
	var rows: Array = []
	for person: PersonState in game.staff.people:
		rows.append([person.name, person.role, person.skill, person.salary_k])
	(
		assert_array(rows)
		. is_equal(
			[
				["Dr Ana Ferreira", &"role_scientist", 3, 30],
				["Dr Tom Okafor", &"role_scientist", 3, 30],
				["Sgt Lena Brandt", &"role_engineer", 3, 30],
				["Cpl Raul Mendes", &"role_engineer", 2, 25],
				["Mira Kovacs", &"role_analyst", 3, 30],
			]
		)
	)
	assert_int(StaffRules.salaries_k(game)).is_equal(145)
	var control: RoomState = PowerFixture.first_room(game, &"room_control")
	assert_array(StaffRules.assigned(game, control)).is_equal([game.staff.people[4]])
	for index: int in 4:
		assert_bool(game.staff.people[index].is_assigned()).is_false()
	for person: PersonState in game.staff.people:
		assert_bool(person.is_on_base(game.clock.tick)).is_true()
	assert_array(game.staff.auto_assign).is_equal([&"room_research_lab", &"room_workshop"])


## The crew does not depend on the seed: every new game opens the same way.
func test_crew_is_the_same_for_every_seed() -> void:
	var one: GameState = GameState.new_game(1, BalanceConfig.new())
	var two: GameState = GameState.new_game(987654, BalanceConfig.new())
	assert_dict(one.staff.to_dict()).is_equal(two.staff.to_dict())


## Salary is 15 + 5 × skill: $20k at 1, $30k at 3, $40k at 5.
func test_salary_for_skill() -> void:
	var balance := BalanceConfig.new()
	assert_int(StaffRules.salary_for_skill(balance, 1)).is_equal(20)
	assert_int(StaffRules.salary_for_skill(balance, 3)).is_equal(30)
	assert_int(StaffRules.salary_for_skill(balance, 5)).is_equal(40)


## The base starts with 6 beds, 5 used; a Quarters adds 4 once built, none while building.
func test_beds_cap_headcount() -> void:
	var game: GameState = ConstructionFixture.state()
	assert_int(StaffRules.beds(game)).is_equal(6)
	assert_int(StaffRules.headcount(game)).is_equal(5)
	assert_int(StaffRules.beds_free(game)).is_equal(1)
	var quarters: RoomState = game.base.add_room(&"room_quarters", 1, Vector2i(0, 11))
	quarters.build_ticks_left = 10
	assert_int(StaffRules.beds_free(game)).is_equal(1)
	quarters.build_ticks_left = 0
	assert_int(StaffRules.beds_free(game)).is_equal(5)


## A person still arriving holds a bed and is paid.
func test_arriving_people_count_for_beds_and_salaries() -> void:
	var game: GameState = ConstructionFixture.state()
	var person := PersonState.new()
	person.role = &"role_scientist"
	person.skill = 4
	person.salary_k = 35
	person.arrives_tick = 100
	game.staff.add_person(person)
	assert_int(StaffRules.beds_free(game)).is_equal(0)
	assert_int(StaffRules.salaries_k(game)).is_equal(180)
	assert_bool(person.is_on_base(game.clock.tick)).is_false()


## Plants have no staff slots (owner, 2026-11-02); labs 4, Workshops 2, the Control Room 2.
func test_slots_per_room_type() -> void:
	var game: GameState = ConstructionFixture.state()
	var expected: Dictionary = {
		&"room_research_lab": 4,
		&"room_workshop": 2,
		&"room_control": 2,
		&"room_power_plant": 0,
		&"room_quarters": 0,
		&"room_gate": 0,
	}
	for def_id: StringName in expected:
		var room := RoomState.create(&"x", def_id, 1, Vector2i.ZERO)
		assert_int(StaffRules.slots(game, room)).override_failure_message(def_id).is_equal(
			expected[def_id]
		)


## The same seed draws the same names; the title comes from the role.
func test_names_are_seeded() -> void:
	var names: StaffNameListDef = load("res://data/staff/staff_names.tres")
	var role: RoleDef = load("res://data/staff/role_scientist.tres")
	var drawn: Array[String] = []
	for attempt: int in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		drawn.append(StaffNames.draw(rng, names, role, "female"))
	assert_str(drawn[0]).is_equal(drawn[1])
	assert_str(drawn[0]).starts_with("Dr ")
	var analyst: RoleDef = load("res://data/staff/role_analyst.tres")
	var rng := RandomNumberGenerator.new()
	assert_int(StaffNames.draw(rng, names, analyst, "male").split(" ").size()).is_equal(2)
