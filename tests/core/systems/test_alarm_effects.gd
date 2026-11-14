## Alarm effects (M4c-09): research and building stop during an incursion while money runs;
## civilians in a room intruders enter can be hurt; a damaged plant gives nothing, a damaged
## room cannot be switched on and repair puts it back; the Committee reacts.
## Bible: docs/content/m4c-incursions.md section 5
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation


func before_test() -> void:
	_state = GameState.new_game(3, Registry.balance())
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	var unit := UnitDef.new()
	unit.id = &"unit_raider"
	unit.health = 8
	_state.unit_defs[unit.id] = unit
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = &"faction_ossar"
	def.group_units = [unit.id]
	def.group_counts = [2]
	_state.incursion_defs[def.id] = def


func _room(def_id: StringName) -> RoomState:
	for room: RoomState in _state.base.rooms:
		if room.def_id == def_id:
			return room
	return null


func test_building_stops_during_an_incursion() -> void:
	var site: RoomState = _state.base.add_room(&"room_quarters", 1, Vector2i(2, 12))
	site.build_ticks_left = 50
	IncursionRules.start(_state, &"incursion_test")
	_simulation.advance_tick()
	assert_int(site.build_ticks_left).is_equal(50)


func test_damaged_plant_gives_nothing_and_repair_restores_it() -> void:
	var plant: RoomState = _room(ObjectiveRules.POWER_PLANT_DEF)
	var supply_before: float = PowerRules.totals(_state)[0]
	plant.damaged = true
	assert_float(PowerRules.totals(_state)[0]).is_less(supply_before)
	var switch := SwitchRoomCommand.create(plant.id, true)
	plant.powered_on = false
	assert_str(String(switch.validate(_state).error_code)).is_equal("damaged")
	plant.powered_on = true
	var funds: int = _state.budget.funds_k
	var repair := RepairRoomCommand.create(plant.id)
	assert_bool(repair.validate(_state).is_ok).is_true()
	repair.apply(_state)
	var def: RoomDef = _state.room_defs[plant.def_id]
	assert_int(_state.budget.funds_k).is_equal(funds - RepairRules.cost_k(def))
	assert_str(String(repair.validate(_state).error_code)).is_equal("repairing")
	for index: int in RepairRules.ticks(def) + 1:
		_simulation.advance_tick()
	assert_bool(plant.damaged).is_false()
	assert_bool(plant.powered_on).is_true()


func test_civilians_in_an_entered_room_can_be_hurt_once_per_group() -> void:
	var control: RoomState = _room(ObjectiveRules.CONTROL_ROOM_DEF)
	for index: int in 40:
		var person := PersonState.new()
		person.id = StringName("clerk_%d" % index)
		person.role = &"role_analyst"
		person.room_id = control.id
		_state.staff.people.append(person)
	IncursionRules.start(_state, &"incursion_test")
	IncursionRules.breach(_state)
	_state.incursion.groups[0].move_to(Vector3i(control.origin.x, control.origin.y, control.level))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	CivilianRules.hit(_state, rng)
	var hurt_list: Array = _state.incursion.report.get("hurt", [])
	var hurt: int = hurt_list.size()
	assert_int(hurt).is_between(3, 20)
	CivilianRules.hit(_state, rng)
	var again: Array = _state.incursion.report.get("hurt", [])
	assert_int(again.size()).is_equal(hurt)


func test_the_committee_reacts() -> void:
	IncursionRules.start(_state, &"incursion_test")
	_state.incursion.report = {"damaged": ["room_3"]}
	IncursionRules.breach(_state)
	_state.incursion.report = {"damaged": ["room_3"]}
	_state.incursion.groups.clear()
	var before: int = _state.committee.confidence
	IntruderRules.finish(_state)
	assert_int(_state.committee.confidence).is_equal(before - 30)
	var causes: Array[ConfidenceCause] = _state.committee.causes
	assert_str(String(causes[causes.size() - 1].cause)).is_equal("incursion_damage")
