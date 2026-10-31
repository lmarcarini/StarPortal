## Tests for EconomySystem: month-end allocation and upkeep, half for rooms off, none for
## rooms under construction, and budget_changed through a running Simulation.
## Bible: docs/content/m2-base.md section 5
extends GdUnitTestSuite


func _def(def_id: StringName, upkeep_k: int) -> RoomDef:
	var def := RoomDef.new()
	def.id = def_id
	def.upkeep_k = upkeep_k
	return def


func _defs() -> Array[RoomDef]:
	return [
		_def(&"room_gate", 0),
		_def(&"room_lab", 60),
		_def(&"room_plant", 150),
		_def(&"room_lift", 10),
	]


func _state() -> GameState:
	var state := GameState.new_game(1, BalanceConfig.new())
	state.base.rooms.clear()
	state.base.add_room(&"room_lab", 1, Vector2i(0, 0))
	state.base.add_room(&"room_plant", 1, Vector2i(10, 0))
	return state


func test_month_adds_allocation_and_subtracts_upkeep() -> void:
	var state := _state()
	EconomySystem.new(BalanceConfig.new(), _defs()).on_month(state)
	assert_int(state.budget.funds_k).is_equal(12000 + 3000 - 210)
	assert_array(state.events.drain()).is_not_empty()


func test_off_room_pays_half_and_unbuilt_pays_nothing() -> void:
	var state := _state()
	state.base.rooms[0].powered_on = false
	state.base.rooms[1].powered_on = false
	state.base.add_room(&"room_lab", 2, Vector2i(0, 0)).build_ticks_left = 5
	var by_id: Dictionary[StringName, RoomDef] = {}
	for def: RoomDef in _defs():
		by_id[def.id] = def
	assert_int(EconomySystem.monthly_upkeep_k(state.base, by_id)).is_equal(30 + 75)


func test_upkeep_can_push_balance_negative() -> void:
	var state := _state()
	state.budget.funds_k = -3000
	EconomySystem.new(BalanceConfig.new(), _defs()).on_month(state)
	assert_int(state.budget.funds_k).is_equal(-210)


func test_simulation_posts_budget_changed_at_month_start() -> void:
	var state := _state()
	var systems: Array[SimSystem] = [EconomySystem.new(BalanceConfig.new(), _defs())]
	var simulation := Simulation.new(state, systems)
	var seen: Array = []
	simulation.event_posted.connect(
		func(event_name: StringName, args: Array) -> void: seen.append([event_name, args])
	)
	state.clock.tick = 31 * TimeMath.TICKS_PER_DAY - 1
	simulation.advance_tick()
	assert_bool(TimeMath.is_month_start(state.clock.tick)).is_true()
	assert_array(seen).contains([[&"budget_changed", [14790]]])


func test_lift_shaft_pays_once() -> void:
	var state := _state()
	for level: int in [1, 2, 3]:
		state.base.add_room(&"room_lift", level, Vector2i(32, 14))
	var by_id: Dictionary[StringName, RoomDef] = {}
	for def: RoomDef in _defs():
		by_id[def.id] = def
	assert_int(EconomySystem.monthly_upkeep_k(state.base, by_id)).is_equal(210 + 10)


func test_starting_base_upkeep_is_240k() -> void:
	var defs: GameDefs = GameDefs.from_registry(Registry)
	var by_id: Dictionary[StringName, RoomDef] = {}
	for def: RoomDef in defs.rooms:
		by_id[def.id] = def
	var state := GameState.new_game(1, defs.balance)
	assert_int(EconomySystem.monthly_upkeep_k(state.base, by_id)).is_equal(240)
