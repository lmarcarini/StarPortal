## Tests for StartingBase: the m2-base.md section 2 layout, every pre-built room fits and
## touches a corridor or lift, and no cell is reserved: the first
## Capacitor Bank finds a spot sharing a wall with the Gate Room.
## Bible: game-design.md#base-building-and-power, docs/content/m2-base.md (section 2)
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


## Levels 1 to 3 on the balance's grid, with exactly the rooms of section 2 on each.
func test_layout() -> void:
	var base := StartingBase.build(_balance)
	assert_int(base.level_count).is_equal(3)
	assert_that(base.grid_size).is_equal(Vector2i(36, 20))
	var expected: Array = [
		{&"room_power_plant": 1, &"room_quarters": 2, &"room_lift": 1},
		{&"room_archive": 1, &"room_lift": 1},
		{&"room_gate": 1, &"room_control": 1, &"room_lift": 1},
	]
	for level: int in range(1, 4):
		var wanted: Dictionary = expected[level - 1]
		var others: int = 0
		for room: RoomState in BaseRules.rooms_on_level(base, level):
			assert_bool(room.is_built() and room.powered_on).is_true()
			if room.def_id != &"room_corridor":
				others += 1
		for def_id: StringName in wanted:
			assert_int(_count(base, level, def_id)).is_equal(wanted[def_id])
		assert_int(others).is_equal(
			wanted.values().reduce(func(a: int, b: int) -> int: return a + b)
		)
		assert_int(_count(base, level, &"room_corridor")).is_greater(0)


## The lift shaft takes the same cells on every level.
func test_lift_shaft_lines_up() -> void:
	var base := StartingBase.build(_balance)
	for room: RoomState in base.rooms:
		if room.def_id == &"room_lift":
			assert_that(room.origin).is_equal(StartingBase.LIFT_ORIGIN)


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
	var probe := RoomState.create(&"probe", &"room_capacitor_bank", 3, spot)
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


## Starting draw with everything on is 4 MW of the plant's 30, and upkeep sums to $240k when
## the lift shaft is counted once.
func test_starting_power_and_upkeep() -> void:
	var base := StartingBase.build(_balance)
	var draw: float = 0.0
	var output: float = 0.0
	var upkeep: int = 0
	for room: RoomState in base.rooms:
		var def: RoomDef = _defs[room.def_id]
		draw += def.power_draw_mw
		output += def.power_output_mw
		if room.def_id != &"room_lift" or room.level == 1:
			upkeep += def.upkeep_k
	assert_float(draw).is_equal(4.0)
	assert_float(output).is_equal(30.0)
	assert_int(upkeep).is_equal(240)
