## Tests for staff and the base: the first lab and Workshop take the waiting crew, demolition
## unassigns with a Log line, Quarters needed for beds stay up, and salaries at month-end
## (docs/content/m26-staff-and-money.md sections 3, 4 and 7).
## Bible: docs/content/m26-staff-and-money.md sections 3, 4 and 7
extends GdUnitTestSuite

const LAB: StringName = &"room_research_lab"
const WORKSHOP: StringName = &"room_workshop"


func _build(game: GameState, def_id: StringName, origin: Vector2i) -> RoomState:
	ConstructionFixture.run(game, PlaceRoomCommand.create(def_id, 2, origin))
	var room: RoomState = game.base.rooms[-1]
	ConstructionFixture.advance(game, ConstructionSystem.new(), room.build_ticks_left)
	return room


func _scientists_in(game: GameState, room: RoomState) -> Array[String]:
	var names: Array[String] = []
	for person: PersonState in StaffRules.assigned(game, room):
		names.append(person.name)
	return names


## The first lab takes both scientists ("Research Lab staffed: 2 scientists."); a second lab
## takes no one.
func test_first_lab_takes_the_scientists_once() -> void:
	var game: GameState = ConstructionFixture.grown()
	var lab: RoomState = _build(game, LAB, Vector2i(20, 16))
	assert_array(_scientists_in(game, lab)).is_equal(["Dr Ana Ferreira", "Dr Tom Okafor"])
	assert_array(game.staff.auto_assign).is_equal([WORKSHOP])
	var staffed: Array[SimEvent] = game.events.drain().filter(
		func(event: SimEvent) -> bool: return event.name == &"staff_changed"
	)
	assert_array(staffed[0].args).is_equal([&"auto_assigned", LAB, 2])
	var entries: Array[LogEntry] = LogRules.entries_for(&"staff_changed", staffed[0].args, game, 7)
	assert_str(ArchiveLogRow.line_for(entries[0], game)).is_equal(
		"Research Lab staffed: 2 scientists."
	)
	ConstructionFixture.run(game, UnassignStaffCommand.create(&"person_1"))
	var second: RoomState = _build(game, LAB, Vector2i(20, 12))
	assert_array(StaffRules.assigned(game, second)).is_empty()


## The first Workshop takes both engineers.
func test_first_workshop_takes_the_engineers() -> void:
	var game: GameState = ConstructionFixture.grown()
	var workshop: RoomState = _build(game, WORKSHOP, Vector2i(20, 16))
	assert_int(StaffRules.assigned(game, workshop).size()).is_equal(2)
	assert_array(game.staff.auto_assign).is_equal([LAB])


## Demolishing a room unassigns its people at once, with a Log line.
func test_demolition_unassigns_with_a_log_line() -> void:
	var game: GameState = ConstructionFixture.grown()
	var lab: RoomState = _build(game, LAB, Vector2i(20, 16))
	game.events.drain()
	assert_bool(ConstructionFixture.run(game, DemolishRoomCommand.create(lab.id)).is_ok).is_true()
	assert_array(StaffRules.assigned(game, lab)).is_empty()
	var staffed: Array[SimEvent] = game.events.drain().filter(
		func(event: SimEvent) -> bool: return event.name == &"staff_changed"
	)
	assert_array(staffed[0].args).is_equal([&"released", LAB, 2])
	var entries: Array[LogEntry] = LogRules.entries_for(&"staff_changed", staffed[0].args, game, 7)
	assert_str(ArchiveLogRow.line_for(entries[0], game)).is_equal(
		"Staff unassigned from Research Lab: 2."
	)


## Player moves are not logged.
func test_player_moves_are_not_logged() -> void:
	var game: GameState = ConstructionFixture.state()
	assert_array(LogRules.entries_for(&"staff_changed", [&"assigned", LAB, 1], game, 1)).is_empty()


## Quarters whose beds the roster needs cannot come down ("Dismiss someone first.").
func test_quarters_needed_for_beds_stay_up() -> void:
	var game: GameState = ConstructionFixture.grown()
	var quarters: RoomState = PowerFixture.first_room(game, &"room_quarters")
	for index: int in 2:
		game.staff.add_person(PersonState.new())
	var refused: CommandResult = DemolishRoomCommand.create(quarters.id).validate(game)
	assert_str(refused.error_code).is_equal(&"beds_needed")
	game.staff.remove_person(&"person_6")
	assert_bool(DemolishRoomCommand.create(quarters.id).validate(game).is_ok).is_true()


## The daily settlement charges room upkeep and the $145k of salaries per 30 days, with the
## carry (m27-daily-rhythm.md section 1).
func test_settlement_pays_salaries() -> void:
	var game: GameState = ConstructionFixture.state()
	var defs: Array[RoomDef] = []
	defs.assign(game.room_defs.values())
	var funds: int = game.budget.funds_k
	var upkeep: int = EconomySystem.upkeep_k(game.base, game.room_defs, game.unlocks)
	game.clock.tick = TimeMath.TICKS_PER_DAY
	EconomySystem.new(game.balance, defs).on_day(game)
	assert_int(game.budget.funds_k).is_equal(funds + 100 - (upkeep + 145) / 30)
	assert_int(game.committee.cost_carry).is_equal((upkeep + 145) % 30)
	assert_int(upkeep + 145).is_equal(335)
