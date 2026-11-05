## The two 30-day examples of section 7, as month-end tests over a real game: CAIRN locks SILL
## through the Ring (GateSystem marks it LOCKED), the rooms of each column are added to the
## base, the column's real research projects are finished in the research state and A's two
## hires join the roster. The clock then runs through the real Simulation to the 1 February
## month-end (EconomySystem computes the upkeep), and the balance, Confidence and next
## allocation must be the doc's. Playing the whole month (hiring, staff speeds) is the M2.6
## flow test's job (#193).
## Bible: docs/content/m26-staff-and-money.md sections 4 and 7
extends GdUnitTestSuite

const M15Player := preload("res://tests/gate/m15_player.gd")
const SEED: int = 20260101
## Tick of 1 February 00:00, the first month-end.
const FEB_1: int = 31 * 1440

var _defs: GameDefs


func before() -> void:
	_defs = GameDefs.from_registry(Registry)


## A new game with one Capacitor Bank built and SILL locked through the Ring.
func _player_with_sill_locked() -> M15Player:
	var built: Result = GameSetup.build_new(GameState.new_game(SEED, _defs.balance), _defs)
	var simulation: Simulation = built.value
	var player: M15Player = M15Player.new(simulation)
	assert_int(player.build_bank()).is_greater(0)
	var sill: GateAddress = player.address(M15Player.PUZZLES[0]["glyphs"])
	assert_bool(player.wait_for_charge(sill)).is_true()
	assert_int(player.dial(sill).outcome).is_equal(DialOutcome.Kind.LOCK)
	var world: StringName = M15Player.PUZZLES[0]["world"]
	assert_int(player.state().worlds.status_of(world)).is_equal(WorldsState.WorldStatus.LOCKED)
	return player


func _add_rooms(state: GameState, def_ids: Array[StringName]) -> void:
	var column: int = 0
	for def_id: StringName in def_ids:
		state.base.add_room(def_id, 3, Vector2i(column, 0))
		column += 8


func _finish(state: GameState, project_ids: Array[StringName]) -> void:
	for project_id: StringName in project_ids:
		assert_object(state.research_defs.get(project_id)).is_not_null()
		state.research.done.append(project_id)


func _hire_scientist(state: GameState, full_name: String) -> void:
	var person := PersonState.new()
	person.id = StringName("person_%d" % state.staff.next_person_number)
	person.name = full_name
	person.role = &"role_scientist"
	person.skill = 3
	person.salary_k = StaffRules.salary_for_skill(state.balance, 3)
	state.staff.add_person(person)


## A's 30 MW (section 7): Gate 5, Lab 5 and the one bank charging at 20 MW.
func _power_lab_with_bank_at_20_mw(player: M15Player) -> void:
	var state: GameState = player.state()
	for room: RoomState in state.base.rooms:
		if room.def_id == &"room_capacitor_bank":
			assert_bool(player.simulation.submit(SetChargeRateCommand.create(room.id, 20)).is_ok)
		elif room.def_id == &"room_research_lab":
			assert_bool(player.simulation.submit(SwitchRoomCommand.create(room.id, true)).is_ok)


## Runs to the minute before the month-end, sets the balance the column has left after its
## spending, then runs the month-end tick.
func _month_end(player: M15Player, balance_before_k: int) -> MonthReport:
	while player.state().clock.tick < FEB_1 - 1:
		player.step()
	player.state().budget.funds_k = balance_before_k
	player.step()
	assert_int(player.state().clock.tick).is_equal(FEB_1)
	return player.state().committee.latest_report()


func test_example_a_research_rush() -> void:
	var player: M15Player = _player_with_sill_locked()
	var state: GameState = player.state()
	_add_rooms(state, [&"room_research_lab", &"room_quarters"])
	_finish(state, [&"excavation_survey", &"second_plant", &"bank_array", &"field_engineering"])
	_power_lab_with_bank_at_20_mw(player)
	_hire_scientist(state, "Dr Claire Moreau")
	_hire_scientist(state, "Dr Ken Arai")
	var report := _month_end(player, 2390)
	assert_int(report.upkeep_k).is_equal(270)
	assert_int(report.people).is_equal(7)
	assert_int(report.salaries_k).is_equal(205)
	assert_int(report.funds_after_k).is_equal(4915)
	assert_int(state.budget.funds_k).is_equal(4915)
	assert_array(report.locked_worlds).is_equal([&"world_sill"])
	assert_int(report.amount_of(&"locked")).is_equal(5)
	assert_int(report.amount_of(&"research")).is_equal(12)
	assert_int(report.amount_of(&"reports")).is_equal(1)
	assert_int(report.amount_of(&"within_budget")).is_equal(2)
	assert_int(report.amount_of(&"cap")).is_equal(-5)
	assert_int(state.committee.confidence).is_equal(65)
	assert_int(report.next_allocation_k).is_equal(3450)
	assert_array(player.rejections).is_empty()


func test_example_b_power() -> void:
	var player: M15Player = _player_with_sill_locked()
	var state: GameState = player.state()
	_add_rooms(state, [&"room_research_lab", &"room_power_plant", &"room_capacitor_bank"])
	_finish(state, [&"second_plant", &"bank_array"])
	var report := _month_end(player, 900)
	assert_int(report.upkeep_k).is_equal(420)
	assert_int(report.people).is_equal(5)
	assert_int(report.salaries_k).is_equal(145)
	assert_int(report.funds_after_k).is_equal(3335)
	assert_int(report.amount_of(&"research")).is_equal(6)
	assert_int(report.amount_of(&"cap")).is_equal(0)
	assert_int(state.committee.confidence).is_equal(64)
	assert_int(report.next_allocation_k).is_equal(3420)
	assert_array(player.rejections).is_empty()
