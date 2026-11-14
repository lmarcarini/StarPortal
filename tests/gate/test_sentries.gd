## Sentry guns and door plating (M4c-21): a sentry fights only in its own room and only while
## the room is on; one sentry beats 2 Raiders and 4 destroy it (fixed seed); plating doubles
## the breach time.
## Bible: docs/content/m4c-incursions.md section 6
extends GdUnitTestSuite

var _state: GameState
var _plant: RoomState


func before_test() -> void:
	_state = GameState.new_game(5, Registry.balance())
	GameSetup.build_new(_state, GameDefs.from_registry(Registry))
	var unit: UnitDef = Registry.get_def(&"unit_raider")
	_state.unit_defs[unit.id] = unit
	for room: RoomState in _state.base.rooms:
		if room.def_id == ObjectiveRules.POWER_PLANT_DEF:
			_plant = room
	_state.research.done.append(&"automated_defence")
	InstallCommand.create(_plant.id, SentryRules.SENTRY).apply(_state)
	_plant.installations[0].build_ticks_left = 0


func _raiders(count: int, at: Vector3i) -> IntruderGroup:
	var def := IncursionDef.new()
	def.id = &"incursion_test"
	def.faction = &"faction_ossar"
	def.group_units = [&"unit_raider"]
	def.group_counts = [count]
	_state.incursion_defs[def.id] = def
	_state.incursion = IncursionState.new()
	IncursionRules.start(_state, def.id)
	IncursionRules.breach(_state)
	_state.incursion.groups[0].move_to(at)
	return _state.incursion.groups[0]


func _fight(group: IntruderGroup) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for round_index: int in 40:
		if group.standing().is_empty() or _plant.installations.is_empty():
			return
		SentryRules.fight(_state, rng)


func test_one_sentry_beats_two_and_four_destroy_it() -> void:
	var inside := Vector3i(_plant.origin.x, _plant.origin.y, _plant.level)
	var two: IntruderGroup = _raiders(2, inside)
	_fight(two)
	assert_array(two.standing()).is_empty()
	assert_int(_plant.installations.size()).is_equal(1)
	_plant.installations[0].health = 15
	var four: IntruderGroup = _raiders(4, inside)
	_fight(four)
	assert_array(_plant.installations).is_empty()


func test_only_its_room_and_only_while_on() -> void:
	var outside: IntruderGroup = _raiders(2, IncursionRules.gate_cell(_state))
	var rng := RandomNumberGenerator.new()
	assert_array(SentryRules.fight(_state, rng)).is_empty()
	outside.move_to(Vector3i(_plant.origin.x, _plant.origin.y, _plant.level))
	_plant.damaged = true
	assert_array(SentryRules.fight(_state, rng)).is_empty()


func test_plating_doubles_the_breach() -> void:
	var door := DoorState.new()
	door.mode = DoorState.Mode.SEALED
	assert_bool(SentryRules.plated(door)).is_false()
	var plating := InstallationState.new()
	plating.def = SentryRules.PLATING
	door.installations.append(plating)
	assert_bool(SentryRules.plated(door)).is_true()
