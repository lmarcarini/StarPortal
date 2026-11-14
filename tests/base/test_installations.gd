## Installations (M4c-18): researched, then built like a small site; refunds as rooms; their
## modifiers count only while active; demolishing the room drops them; nothing builds during
## an incursion; saves round-trip and old saves load with none.
## Bible: docs/content/m4c-incursions.md section 6
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation
var _def: InstallationDef


func before_test() -> void:
	_state = GameState.new_game(4, Registry.balance())
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	_def = InstallationDef.new()
	_def.id = &"installation_test"
	_def.name_key = &"X"
	_def.hosts = [&"room_power_plant"]
	_def.requires_research = &"research_test"
	_def.cost_k = 100
	_def.build_ticks = 20
	var modifier := ModifierEffect.new()
	modifier.key = &"test_bonus"
	modifier.amount = 7
	_def.effects = [modifier]
	_state.installation_defs[_def.id] = _def


func _plant() -> RoomState:
	for room: RoomState in _state.base.rooms:
		if room.def_id == &"room_power_plant":
			return room
	return null


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func test_research_then_build_then_modifier_while_active() -> void:
	var plant: RoomState = _plant()
	var command := InstallCommand.create(plant.id, _def.id)
	assert_str(String(command.validate(_state).error_code)).is_equal("not_researched")
	_state.research.done.append(&"research_test")
	(
		assert_str(
			String(
				InstallCommand.create(_state.base.rooms[0].id, _def.id).validate(_state).error_code
			)
		)
		. is_equal("wrong_host")
	)
	var funds: int = _state.budget.funds_k
	assert_bool(_simulation.submit(command).is_ok).is_true()
	_ticks(1)
	assert_int(_state.budget.funds_k).is_equal(funds - 100)
	assert_str(String(command.validate(_state).error_code)).is_equal("host_full")
	assert_int(ModifierRules.total(_state, &"test_bonus")).is_equal(0)
	_ticks(25)
	assert_bool(plant.installations[0].is_built()).is_true()
	assert_int(ModifierRules.total(_state, &"test_bonus")).is_equal(7)
	plant.damaged = true
	assert_int(ModifierRules.total(_state, &"test_bonus")).is_equal(0)
	plant.damaged = false
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	assert_int(GameState.from_dict(data).base.find_room(plant.id).installations.size()).is_equal(1)
	var before: int = _state.budget.funds_k
	(
		assert_bool(_simulation.submit(RemoveInstallationCommand.create(plant.id, _def.id)).is_ok)
		. is_true()
	)
	_ticks(1)
	assert_int(_state.budget.funds_k).is_equal(before + 50)
	assert_int(ModifierRules.total(_state, &"test_bonus")).is_equal(0)


func test_cancel_refunds_75_and_nothing_builds_during_an_incursion() -> void:
	_state.research.done.append(&"research_test")
	var plant: RoomState = _plant()
	InstallCommand.create(plant.id, _def.id).apply(_state)
	_state.incursion.phase = IncursionState.Phase.BREACH
	_state.incursion.def_id = &"x"
	var left: int = plant.installations[0].build_ticks_left
	ConstructionSystem.new().tick(_state)
	assert_int(plant.installations[0].build_ticks_left).is_equal(left)
	_state.incursion.phase = IncursionState.Phase.NONE
	var before: int = _state.budget.funds_k
	RemoveInstallationCommand.create(plant.id, _def.id).apply(_state)
	assert_int(_state.budget.funds_k).is_equal(before + 75)


func test_old_rooms_load_with_none() -> void:
	var data: Dictionary = _plant().to_dict()
	data.erase("installations")
	assert_array(RoomState.validate_dict(data)).is_empty()
	assert_array(RoomState.from_dict(data).installations).is_empty()
