## Tests for lift segments (LiftShafts) and the relaxed stairs and lift placement: a dug level
## extends a built lift as a paid $100k, 1-hour site that takes no building slot and can be
## cancelled; short of funds it is refused and built from the palette at the segment price;
## stairs placed from the level above reach an empty new level, where corridors join them.
## Bible: docs/content/m25-lean-start.md section 2
extends GdUnitTestSuite

var _game: GameState
var _system: ConstructionSystem


func before_test() -> void:
	_game = ConstructionFixture.grown()
	_system = ConstructionSystem.new()


## Digs Level 4 and ticks until it is dug; returns the events posted meanwhile.
func _dig_level_4() -> Array[StringName]:
	assert_bool(ConstructionFixture.run(_game, DigLevelCommand.new()).is_ok).is_true()
	_game.events.drain()
	while _game.base.digging_level() != 0:
		_system.tick(_game)
	return ConstructionFixture.event_names(_game)


func _lifts_on(level: int) -> Array[RoomState]:
	var found: Array[RoomState] = []
	for room: RoomState in BaseRules.rooms_on_level(_game.base, level):
		if room.def_id == StartingBase.LIFT_DEF:
			found.append(room)
	return found


func test_dug_level_starts_a_paid_segment() -> void:
	var funds: int = _game.budget.funds_k
	var events: Array[StringName] = _dig_level_4()
	assert_array(events).is_equal([&"room_build_started", &"budget_changed", &"level_dug"])
	assert_int(_game.budget.funds_k).is_equal(funds - 3500 - 100)
	var segment: RoomState = _lifts_on(4)[0]
	assert_that(segment.origin).is_equal(ConstructionFixture.GROWN_LIFT)
	assert_int(segment.build_ticks_left).is_equal(60)
	assert_bool(LiftShafts.is_segment(_game.base, segment)).is_true()
	ConstructionFixture.advance(_game, _system, 60)
	assert_bool(segment.is_built()).is_true()


func test_segment_takes_no_building_slot() -> void:
	for column: int in [5, 9, 13]:
		ConstructionFixture.run(
			_game, PlaceRoomCommand.create(&"room_quarters", 3, Vector2i(column, 16))
		)
		_game.base.rooms[-1].build_ticks_left = 100000
	_dig_level_4()
	var segment: RoomState = _lifts_on(4)[0]
	assert_int(ConstructionSystem.site_queue(_game.base).size()).is_equal(3)
	assert_array(ConstructionSystem.segment_sites(_game.base)).is_equal([segment.site_key()])
	ConstructionFixture.advance(_game, _system, 60)
	assert_bool(segment.is_built()).is_true()


func test_segment_cancels_with_three_quarters_of_its_price() -> void:
	_dig_level_4()
	var funds: int = _game.budget.funds_k
	var segment: RoomState = _lifts_on(4)[0]
	assert_bool(ConstructionFixture.run(_game, CancelBuildCommand.create(segment.id)).is_ok)
	assert_int(_game.budget.funds_k).is_equal(funds + 75)
	assert_array(_lifts_on(4)).is_empty()
	assert_int(_lifts_on(3).size()).is_equal(1)


func test_short_of_funds_is_refused_then_built_from_the_palette() -> void:
	_game.budget.funds_k = 3500 + 50
	var events: Array[StringName] = _dig_level_4()
	assert_array(events).is_equal([&"lift_segment_refused", &"level_dug"])
	assert_array(_lifts_on(4)).is_empty()
	assert_int(_game.budget.funds_k).is_equal(50)
	var place := PlaceRoomCommand.create(&"room_lift", 4, ConstructionFixture.GROWN_LIFT)
	assert_str(place.validate(_game).error_code).is_equal("insufficient_funds")
	_game.budget.funds_k = 1000
	assert_bool(ConstructionFixture.run(_game, place).is_ok).is_true()
	assert_int(_game.budget.funds_k).is_equal(900)
	var segment: RoomState = _lifts_on(4)[0]
	assert_int(segment.build_ticks_left).is_equal(60)
	assert_int(_lifts_on(3).size()).is_equal(1)
	var again := PlaceRoomCommand.create(&"room_lift", 1, ConstructionFixture.GROWN_LIFT)
	assert_str(again.validate(_game).error_code).is_equal("overlap")


## A shaft still building when the dig ends takes the new level into its own site, free.
func test_building_shaft_joins_the_new_level_free() -> void:
	for lift: RoomState in _lifts_on(1) + _lifts_on(2) + _lifts_on(3):
		lift.build_ticks_left = 100000
		lift.site = _lifts_on(1)[0].id
	var funds: int = _game.budget.funds_k
	_dig_level_4()
	assert_int(_game.budget.funds_k).is_equal(funds - 3500)
	var copy: RoomState = _lifts_on(4)[0]
	assert_str(String(copy.site)).is_equal(String(_lifts_on(1)[0].id))
	assert_bool(LiftShafts.is_segment(_game.base, copy)).is_false()


## Stairs from Level 3 need a corridor on Level 3 only; on the empty Level 4 a corridor joins
## them, and a room joins that corridor.
func test_stairs_from_above_anchor_the_empty_level() -> void:
	_dig_level_4()
	var stairs := PlaceRoomCommand.create(&"room_stairs", 3, Vector2i(10, 16))
	assert_bool(ConstructionFixture.run(_game, stairs).is_ok).is_true()
	var corridor: Array[Vector2i] = [Vector2i(10, 17), Vector2i(11, 17), Vector2i(12, 17)]
	assert_bool(ConstructionFixture.run(_game, PaintCorridorCommand.create(4, corridor)).is_ok)
	var lab := PlaceRoomCommand.create(&"room_research_lab", 4, Vector2i(13, 16))
	assert_bool(ConstructionFixture.run(_game, lab).is_ok).is_true()


## Stairs from Level 3 touching nothing on Level 3 are refused.
func test_stairs_still_need_a_connector_above() -> void:
	_dig_level_4()
	var stairs := PlaceRoomCommand.create(&"room_stairs", 3, Vector2i(10, 2))
	assert_str(stairs.validate(_game).error_code).is_equal("not_connected")


## A lift placed after the digs takes its cells on every dug level, at the full price.
func test_lift_after_the_dig_takes_every_level() -> void:
	_dig_level_4()
	var funds: int = _game.budget.funds_k
	var lift: PlaceRoomCommand = null
	for y: int in _game.base.grid_size.y:
		for x: int in _game.base.grid_size.x:
			var probe := PlaceRoomCommand.create(&"room_lift", 3, Vector2i(x, y))
			if lift == null and probe.validate(_game).is_ok:
				lift = probe
	assert_object(lift).is_not_null()
	assert_bool(ConstructionFixture.run(_game, lift).is_ok).is_true()
	assert_int(_game.budget.funds_k).is_equal(funds - 400)
	var shaft: Array[RoomState] = BaseRules.site_rooms(_game.base, _game.base.rooms[-1].site_key())
	assert_int(shaft.size()).is_equal(4)
