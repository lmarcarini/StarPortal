## Intruders after the breach (M4c-07): they walk the shortest open path to the objective,
## wait at a sealed door, work it while uncontested, then leave through the Ring; theft carries
## an artefact that is lost on leaving and recovered when the carriers fall; the end posts a
## report.
## Bible: docs/content/m4c-incursions.md sections 3 and 5
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation
var _ended: Array = []


func before_test() -> void:
	_state = GameState.new_game(7, Registry.balance())
	UnlockFixture.defence_plans(_state)
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	_simulation.event_posted.connect(_on_event)
	var unit := UnitDef.new()
	unit.id = &"unit_raider"
	unit.health = 8
	_state.unit_defs[unit.id] = unit
	_ended.clear()


func _on_event(event_name: StringName, args: Array) -> void:
	if event_name == &"incursion_ended":
		_ended.append(args[0])


func _start(objective: StringName, count: int = 2) -> void:
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = &"faction_ossar"
	def.group_units = [&"unit_raider"]
	def.group_counts = [count]
	def.objective = objective
	def.warning_ticks = 1
	_state.incursion_defs[def.id] = def
	IncursionRules.start(_state, def.id)
	_ticks(1)


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func _room(def_id: StringName) -> RoomState:
	for room: RoomState in _state.base.rooms:
		if room.def_id == def_id:
			return room
	return null


func test_sabotage_damages_the_plant_then_they_leave() -> void:
	_start(&"sabotage")
	var plant: RoomState = _room(ObjectiveRules.POWER_PLANT_DEF)
	assert_str(String(_state.incursion.groups[0].target_room)).is_equal(String(plant.id))
	_ticks(200)
	assert_bool(plant.damaged).is_true()
	assert_bool(_state.incursion.is_active()).is_false()
	assert_int(_ended.size()).is_equal(1)
	var report: Dictionary = _ended[0]
	assert_str(str(report["outcome"])).is_equal("done")
	assert_array(report["damaged"]).contains([String(plant.id)])


func test_a_squad_in_the_room_stops_the_work() -> void:
	_state.unit_defs[&"unit_raider"].health = 100000
	_state.unit_defs[&"unit_raider"].attack = 0.0
	_start(&"sabotage")
	var plant: RoomState = _room(ObjectiveRules.POWER_PLANT_DEF)
	var post: RoomState = _post()
	var soldier := PersonState.new()
	soldier.id = &"soldier_a"
	soldier.name = "A"
	soldier.role = SquadRules.SOLDIER
	soldier.room_id = post.id
	_state.staff.people.append(soldier)
	_ticks(1)
	var squad: SquadState = _state.security.squad_of(post.id)
	squad.pos = Vector3i(plant.origin.x, plant.origin.y, plant.level)
	_ticks(200)
	assert_bool(plant.damaged).is_false()
	assert_int(_state.incursion.groups[0].work_ticks).is_equal(0)


func _post() -> RoomState:
	for x: int in range(2, _state.base.grid_size.x - 2):
		var at := Vector2i(x, StartingBase.SPINE_ROW + 1)
		var command := PlaceRoomCommand.create(SquadRules.POST_DEF, 1, at)
		if command.validate(_state).is_ok:
			command.apply(_state)
			var room: RoomState = _state.base.rooms[_state.base.rooms.size() - 1]
			room.build_ticks_left = 0
			return room
	return null


func test_they_wait_at_a_sealed_door() -> void:
	var plant: RoomState = _room(ObjectiveRules.POWER_PLANT_DEF)
	var from: Vector3i = IncursionRules.gate_cell(_state)
	var to := Vector3i(plant.origin.x, plant.origin.y, plant.level)
	var path: PackedVector3Array = BasePaths.find(_state.base, from, to, _state.room_defs)
	var door := DoorState.new()
	for point: Vector3 in path:
		var cell := Vector3i(int(point.x), int(point.y), int(point.z))
		if DoorRules.can_build(_state, cell.z, Vector2i(cell.x, cell.y)).is_ok:
			door.cell = Vector2i(cell.x, cell.y)
			door.level = cell.z
			break
	door.mode = DoorState.Mode.SEALED
	_state.base.doors.append(door)
	_start(&"sabotage")
	_ticks(12)
	var at: Vector3i = _state.incursion.groups[0].pos()
	(
		assert_int(BasePaths.walking_distance(_state.base, at, door.pos(), _state.room_defs, true))
		. is_equal(1)
	)
	assert_bool(plant.damaged).is_false()


func test_theft_is_lost_on_leaving_and_recovered_when_they_fall() -> void:
	var record := ArtefactRecord.new()
	record.uid = 1
	record.artefact = &"artefact_x"
	_state.artefacts.items.append(record)
	_start(&"theft")
	_ticks(5)
	assert_int(record.room_uid).is_equal(ArtefactRecord.CARRIED)
	for unit: UnitState in _state.incursion.groups[0].units:
		unit.health = 0
	_ticks(1)
	assert_int(record.room_uid).is_equal(ArtefactRecord.IN_HOLDING)
	assert_str(str(_ended[0]["outcome"])).is_equal("stopped")
	_start(&"theft")
	_ticks(200)
	assert_object(ArtefactRules.find(_state, 1)).is_null()
	assert_array(_ended[1]["lost"]).has_size(1)
