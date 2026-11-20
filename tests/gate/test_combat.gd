## Combat and door breaching (M4c-08): reach, simultaneous damage spread front first, soldiers
## downed with a serious injury, breached doors destroyed, determinism, and the balance check
## that 4 skill-3 soldiers holding a room usually beat 4 Raiders.
## Bible: docs/content/m4c-incursions.md sections 2 and 4
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation
var _post: RoomState


func _setup(seed_value: int) -> void:
	_state = GameState.new_game(seed_value, Registry.balance())
	UnlockFixture.defence_plans(_state)
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	_post = null
	for x: int in range(2, _state.base.grid_size.x - 2):
		var command := PlaceRoomCommand.create(
			SquadRules.POST_DEF, 1, Vector2i(x, StartingBase.SPINE_ROW + 1)
		)
		if command.validate(_state).is_ok:
			command.apply(_state)
			_post = _state.base.rooms[_state.base.rooms.size() - 1]
			_post.build_ticks_left = 0
			break


func _soldiers(count: int) -> void:
	for index: int in count:
		var person := PersonState.new()
		person.id = StringName("soldier_%d" % index)
		person.name = "S%d" % index
		person.role = SquadRules.SOLDIER
		person.skill = 3
		person.room_id = _post.id
		_state.staff.people.append(person)
	_simulation.advance_tick()


func _raiders(count: int) -> IntruderGroup:
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = &"faction_ossar"
	def.group_units = [&"unit_raider"]
	def.group_counts = [count]
	def.objective = &"assault"
	_state.incursion_defs[def.id] = def
	IncursionRules.start(_state, def.id)
	IncursionRules.breach(_state)
	var group: IntruderGroup = _state.incursion.groups[0]
	group.move_to(SquadRules.home_of(_post))
	return group


func test_spread_and_reach() -> void:
	assert_array(CombatRules.spread([5, 5, 5], 7)).is_equal([0, 3, 5])
	_setup(1)
	var home: Vector3i = SquadRules.home_of(_post)
	(
		assert_bool(
			CombatRules.in_reach(home, home + Vector3i(1, 1, 0), _state.base, _state.room_defs)
		)
		. is_true()
	)
	var far := Vector3i(0, StartingBase.SPINE_ROW, 1)
	assert_bool(CombatRules.in_reach(home, far, _state.base, _state.room_defs)).is_false()
	var spine_a := Vector3i(2, StartingBase.SPINE_ROW, 1)
	(
		assert_bool(
			CombatRules.in_reach(
				spine_a, spine_a + Vector3i(3, 0, 0), _state.base, _state.room_defs
			)
		)
		. is_true()
	)
	(
		assert_bool(
			CombatRules.in_reach(
				spine_a, spine_a + Vector3i(4, 0, 0), _state.base, _state.room_defs
			)
		)
		. is_false()
	)


func _fight_to_the_end(seed_value: int) -> Array[int]:
	_setup(seed_value)
	_soldiers(4)
	var group: IntruderGroup = _raiders(4)
	var rng: RandomNumberGenerator = _state.random.stream(IncursionSystem.STREAM)
	for round_index: int in 60:
		if group.standing().is_empty() or SquadRules.members(_state, _post.id).is_empty():
			break
		BattleRules.fight(_state, rng)
	var result: Array[int] = [group.standing().size(), SquadRules.members(_state, _post.id).size()]
	return result


func test_a_fight_replays_the_same_and_soldiers_go_down_injured() -> void:
	var first: Array[int] = _fight_to_the_end(9)
	var second: Array[int] = _fight_to_the_end(9)
	assert_array(second).is_equal(first)
	var injured: int = 0
	for person: PersonState in _state.staff.people:
		if person.role == SquadRules.SOLDIER and person.injury == PersonState.Injury.SERIOUS:
			injured += 1
	assert_int(injured).is_equal(4 - first[1])


func test_four_soldiers_holding_beat_four_raiders_usually() -> void:
	_setup(100)
	_soldiers(4)
	var group: IntruderGroup = _raiders(4)
	var wins: int = 0
	for seed_value: int in 200:
		for person: PersonState in _state.staff.people:
			person.injury = PersonState.Injury.NONE
		_state.security.health.clear()
		for unit: UnitState in group.units:
			unit.health = 8
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		for round_index: int in 60:
			if group.standing().is_empty() or SquadRules.members(_state, _post.id).is_empty():
				break
			BattleRules.fight(_state, rng)
		if group.standing().is_empty():
			wins += 1
	assert_int(wins).is_greater(100)


func test_a_sealed_door_is_breached_and_destroyed() -> void:
	_setup(2)
	var plant_cell := Vector3i(-1, -1, -1)
	for room: RoomState in _state.base.rooms:
		if room.def_id == ObjectiveRules.POWER_PLANT_DEF:
			plant_cell = Vector3i(room.origin.x, room.origin.y, room.level)
	var group: IntruderGroup = _raiders(2)
	var from: Vector3i = group.pos()
	var path: PackedVector3Array = BasePaths.find(_state.base, from, plant_cell, _state.room_defs)
	var door := DoorState.new()
	for point: Vector3 in path:
		var cell := Vector2i(int(point.x), int(point.y))
		if DoorRules.can_build(_state, int(point.z), cell).is_ok:
			door.cell = cell
			door.level = int(point.z)
			break
	door.mode = DoorState.Mode.SEALED
	_state.base.doors.append(door)
	var ticks: int = 0
	while _state.base.doors.has(door) and ticks < 200:
		IntruderRules.walk_toward(_state, group, plant_cell)
		ticks += 1
	assert_bool(_state.base.doors.has(door)).is_false()
	assert_int(door.breach_ticks).is_equal(15)
