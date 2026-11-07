## Tests for StartingBase: the m25-lean-start.md section 1 layout, every pre-built room fits
## and touches a corridor, and no cell is reserved: the first
## Capacitor Bank finds a spot sharing a wall with the Gate Room.
## Bible: game-design.md#base-building-and-power, docs/content/m25-lean-start.md section 1
extends GdUnitTestSuite

const CONNECTORS: Array[StringName] = [&"room_corridor", &"room_lift", &"room_stairs"]

var _defs: Dictionary = {}
var _balance: BalanceConfig = null


func before_test() -> void:
	_defs = {}
	for def: DefBase in Registry.get_all_of(RoomDef):
		_defs[def.id] = def
	_balance = Registry.get_def(BalanceConfig.BALANCE_ID) as BalanceConfig


func _count(base: BaseState, level: int, def_id: StringName) -> int:
	var found: int = 0
	for room: RoomState in BaseRules.rooms_on_level(base, level):
		if room.def_id == def_id:
			found += 1
	return found


func _area(room: RoomState) -> Rect2i:
	var def: RoomDef = _defs[room.def_id]
	return BaseRules.footprint(room, def)


## One level on the balance's grid, with exactly the rooms of m25-lean-start.md section 1:
## Gate Room, Control Room, Power Plant and a 36-cell corridor spine, all built and on, and
## 585 free cells.
func test_layout() -> void:
	var base := StartingBase.build(_balance)
	assert_int(base.level_count).is_equal(1)
	assert_that(base.grid_size).is_equal(Vector2i(36, 20))
	var wanted: Dictionary = {
		&"room_gate": 1, &"room_control": 1, &"room_power_plant": 1, &"room_corridor": 36
	}
	assert_int(base.rooms.size()).is_equal(39)
	for def_id: StringName in wanted:
		assert_int(_count(base, 1, def_id)).is_equal(wanted[def_id])
	var used: int = 0
	for room: RoomState in base.rooms:
		assert_bool(room.is_built() and room.powered_on).is_true()
		used += _area(room).get_area()
	assert_int(36 * 20 - used).is_equal(585)


## Every room's def exists, every room fits, and every non-connector room touches a corridor
## or lift; every corridor touches a room, corridor or lift.
func test_rooms_fit_and_connect() -> void:
	var base := StartingBase.build(_balance)
	for room: RoomState in base.rooms:
		assert_bool(_defs.has(room.def_id)).override_failure_message(String(room.def_id)).is_true()
		(
			assert_bool(BaseRules.fits(base, _defs, room))
			. override_failure_message(String(room.id))
			. is_true()
		)
		var touches: bool = false
		for other: RoomState in BaseRules.neighbours(base, _defs, room):
			if other.def_id in CONNECTORS or room.def_id in CONNECTORS:
				touches = true
		assert_bool(touches).override_failure_message(String(room.id)).is_true()


## Nothing is reserved: the first bank's spot (BaseSpots.bank_spot) is on the Gate level, fits,
## shares a wall with the Gate Room and touches a corridor.
func test_first_bank_spot_beside_the_gate_room() -> void:
	var base := StartingBase.build(_balance)
	var spot: Vector2i = BaseSpots.bank_spot(base, _defs)
	assert_vector(Vector2(spot)).is_not_equal(Vector2(BaseSpots.NO_SPOT))
	var probe := RoomState.create(&"probe", &"room_capacitor_bank", 1, spot)
	assert_bool(BaseRules.fits(base, _defs, probe)).is_true()
	var next_to: Array[StringName] = []
	for other: RoomState in BaseRules.neighbours(base, _defs, probe):
		next_to.append(other.def_id)
	assert_array(next_to).contains([&"room_gate", &"room_corridor"])


## A new game's state holds the starting base, and without a balance it uses the defaults.
func test_new_game_has_it() -> void:
	var state := GameState.new_game(7, _balance)
	assert_dict(state.base.to_dict()).is_equal(StartingBase.build(_balance).to_dict())
	var bare := GameState.new_game(7)
	assert_dict(bare.base.to_dict()).is_equal(StartingBase.build(_balance).to_dict())


## Starting draw with everything on is 5 MW of the plant's 30 (25 MW spare), and upkeep is
## $190k per 30 days (section 1).
func test_starting_power_and_upkeep() -> void:
	var state := GameState.new_game(7, _balance)
	state.balance = _balance
	for def_id: StringName in _defs:
		state.room_defs[def_id] = _defs[def_id]
	assert_float(PowerRules.supply_mw(state)).is_equal(30.0)
	assert_float(PowerRules.spare_mw(state)).is_equal(25.0)
	assert_int(EconomySystem.upkeep_k(state.base, state.room_defs, state.unlocks)).is_equal(190)
	assert_int(state.budget.funds_k).is_equal(6000)


## The power cache built over the starting base agrees with a fresh sum (rooms come from
## add_room(), so RoomState.revision moved).
func test_power_cache_matches_fresh_sum() -> void:
	var state := GameState.new_game(7, _balance)
	for def_id: StringName in _defs:
		state.room_defs[def_id] = _defs[def_id]
	var cached: PackedFloat64Array = PowerRules.totals(state)
	var fresh := GameState.new_game(7, _balance)
	fresh.room_defs = state.room_defs
	assert_array(Array(PowerRules.totals(fresh))).is_equal(Array(cached))
	state.base = StartingBase.build(_balance)
	assert_array(Array(PowerRules.totals(state))).is_equal(Array(cached))
