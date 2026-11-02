## Tests for AssignStaffCommand and UnassignStaffCommand: moves, every refusal and the
## staff_changed event (docs/content/m26-staff-and-money.md sections 3 and 6).
## Bible: docs/content/m26-staff-and-money.md sections 3 and 6
extends GdUnitTestSuite

const ANA: StringName = &"person_1"
const LENA: StringName = &"person_3"
const MIRA: StringName = &"person_5"

var _game: GameState
var _lab: RoomState


func before_test() -> void:
	_game = ConstructionFixture.state()
	_lab = _game.base.add_room(&"room_research_lab", 1, Vector2i(0, 11))
	_game.events.drain()


func _code(command: Command) -> StringName:
	return ConstructionFixture.run(_game, command).error_code


func test_assign_puts_a_person_in_a_room_and_posts() -> void:
	assert_str(_code(AssignStaffCommand.create(ANA, _lab.id))).is_empty()
	assert_str(_game.staff.find_person(ANA).room_id).is_equal(_lab.id)
	var events: Array[SimEvent] = _game.events.drain()
	assert_int(events.size()).is_equal(1)
	assert_str(events[0].name).is_equal(&"staff_changed")
	assert_array(events[0].args).is_equal([&"assigned", &"room_research_lab", 1])


func test_unassign_makes_a_person_unassigned() -> void:
	assert_str(_code(UnassignStaffCommand.create(MIRA))).is_empty()
	assert_bool(_game.staff.find_person(MIRA).is_assigned()).is_false()
	var events: Array[SimEvent] = _game.events.drain()
	assert_array(events[0].args).is_equal([&"unassigned", &"room_control", 1])
	assert_str(_code(UnassignStaffCommand.create(MIRA))).is_empty()
	assert_array(_game.events.drain()).is_empty()


func test_unknown_ids_are_refused() -> void:
	assert_str(_code(AssignStaffCommand.create(&"person_99", _lab.id))).is_equal(&"unknown_person")
	assert_str(_code(AssignStaffCommand.create(ANA, &"room_999"))).is_equal(&"unknown_room")
	assert_str(_code(UnassignStaffCommand.create(&"person_99"))).is_equal(&"unknown_person")


func test_wrong_role_is_refused() -> void:
	assert_str(_code(AssignStaffCommand.create(LENA, _lab.id))).is_equal(&"wrong_role")
	var plant: RoomState = PowerFixture.first_room(_game, &"room_power_plant")
	assert_str(_code(AssignStaffCommand.create(LENA, plant.id))).is_equal(&"wrong_role")


func test_full_room_is_refused() -> void:
	var control: RoomState = PowerFixture.first_room(_game, &"room_control")
	for index: int in 2:
		var analyst := PersonState.new()
		analyst.role = &"role_analyst"
		_game.staff.add_person(analyst)
	assert_str(_code(AssignStaffCommand.create(&"person_6", control.id))).is_empty()
	assert_str(_code(AssignStaffCommand.create(&"person_7", control.id))).is_equal(&"room_full")
	# Assigning someone to the room they are in is not a refusal.
	assert_str(_code(AssignStaffCommand.create(MIRA, control.id))).is_empty()


func test_person_not_on_base_is_refused() -> void:
	var arriving := PersonState.new()
	arriving.role = &"role_scientist"
	arriving.arrives_tick = _game.clock.tick + 60
	_game.staff.add_person(arriving)
	assert_str(_code(AssignStaffCommand.create(arriving.id, _lab.id))).is_equal(&"not_on_base")
	_game.clock.tick += 60
	assert_str(_code(AssignStaffCommand.create(arriving.id, _lab.id))).is_empty()


func test_site_or_room_coming_down_is_refused() -> void:
	_lab.build_ticks_left = 5
	assert_str(_code(AssignStaffCommand.create(ANA, _lab.id))).is_equal(&"not_built")
	_lab.build_ticks_left = 0
	_lab.demolish_ticks_left = 5
	assert_str(_code(AssignStaffCommand.create(ANA, _lab.id))).is_equal(&"not_built")


## Moving staff never changes the power cache's revision.
func test_staff_moves_keep_the_power_revision() -> void:
	var revision: int = RoomState.revision
	ConstructionFixture.run(_game, AssignStaffCommand.create(ANA, _lab.id))
	ConstructionFixture.run(_game, UnassignStaffCommand.create(ANA))
	assert_int(RoomState.revision).is_equal(revision)


func test_malformed_data_is_refused() -> void:
	var assign: Result = AssignStaffCommand.from_dict({"person_id": 3, "room_id": "room_2"})
	assert_str(assign.error_code).is_equal(&"malformed_command")
	var unassign: Result = UnassignStaffCommand.from_dict({})
	assert_str(unassign.error_code).is_equal(&"malformed_command")
