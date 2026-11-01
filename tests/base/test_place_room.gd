## Tests for PlaceRoomCommand and PaintCorridorCommand: the placement rules, costs, lifts,
## stairs and corridor runs.
## Bible: docs/content/m2-base.md sections 1 and 4
extends GdUnitTestSuite


func _code(game: GameState, command: Command) -> StringName:
	return command.validate(game).error_code


func test_places_a_lab_against_the_spine_and_pays() -> void:
	var game := ConstructionFixture.state()
	var result := ConstructionFixture.run(
		game, PlaceRoomCommand.create(&"room_physics_lab", 2, Vector2i(20, 16))
	)
	assert_bool(result.is_ok).is_true()
	var room: RoomState = game.base.rooms[-1]
	assert_int(room.build_ticks_left).is_equal(game.room_defs[&"room_physics_lab"].build_ticks)
	assert_int(game.budget.funds_k).is_equal(12000 - 800)
	assert_array(ConstructionFixture.event_names(game)).is_equal(
		[&"room_build_started", &"budget_changed"]
	)


func test_rejections_follow_the_rules() -> void:
	var game := ConstructionFixture.state()
	var lab := &"room_physics_lab"
	assert_str(_code(game, PlaceRoomCommand.create(&"nope", 2, Vector2i(20, 16)))).is_equal(
		"unknown_room"
	)
	assert_str(_code(game, PlaceRoomCommand.create(&"room_gate", 2, Vector2i(20, 16)))).is_equal(
		"not_buildable"
	)
	assert_str(_code(game, PlaceRoomCommand.create(lab, 2, Vector2i(34, 18)))).is_equal(
		"outside_level"
	)
	assert_str(_code(game, PlaceRoomCommand.create(lab, 2, Vector2i(12, 12)))).is_equal("overlap")
	assert_str(_code(game, PlaceRoomCommand.create(lab, 2, Vector2i(20, 2)))).is_equal(
		"not_connected"
	)
	assert_str(_code(game, PlaceRoomCommand.create(lab, 4, Vector2i(20, 16)))).is_equal(
		"no_such_level"
	)
	game.budget.funds_k = 799
	assert_str(_code(game, PlaceRoomCommand.create(lab, 2, Vector2i(20, 16)))).is_equal(
		"insufficient_funds"
	)


func test_turned_room_swaps_its_footprint() -> void:
	var game := ConstructionFixture.state()
	ConstructionFixture.run(
		game, PlaceRoomCommand.create(&"room_physics_lab", 2, Vector2i(20, 16), true)
	)
	var lab: RoomState = game.base.rooms[-1]
	var area: Rect2i = BaseRules.footprint(lab, game.room_defs[lab.def_id])
	assert_that(area.size).is_equal(Vector2i(3, 4))
	(
		assert_str(_code(game, PlaceRoomCommand.create(&"room_lift", 2, Vector2i(2, 14), true)))
		. is_equal("not_rotatable")
	)


func test_lift_takes_every_dug_level_for_one_cost() -> void:
	var game := ConstructionFixture.state()
	assert_bool(
		(
			ConstructionFixture
			. run(game, PlaceRoomCommand.create(&"room_lift", 1, Vector2i(2, 14)))
			. is_ok
		)
	)
	var shaft: Array[RoomState] = BaseRules.site_rooms(game.base, game.base.rooms[-1].site_key())
	assert_int(shaft.size()).is_equal(3)
	for room: RoomState in shaft:
		assert_that(room.origin).is_equal(Vector2i(2, 14))
	assert_int(game.budget.funds_k).is_equal(12000 - 400)


func test_lift_blocked_on_one_level_names_it() -> void:
	var game := ConstructionFixture.state()
	var result := PlaceRoomCommand.create(&"room_lift", 1, Vector2i(6, 13)).validate(game)
	assert_str(result.error_code).is_equal("overlap")
	assert_str(result.detail).is_equal("level 1")


func test_stairs_join_two_levels() -> void:
	var game := ConstructionFixture.state()
	assert_bool(
		(
			ConstructionFixture
			. run(game, PlaceRoomCommand.create(&"room_stairs", 1, Vector2i(2, 15)))
			. is_ok
		)
	)
	var stairs: Array[RoomState] = BaseRules.site_rooms(game.base, game.base.rooms[-1].site_key())
	assert_int(stairs.size()).is_equal(2)
	assert_int(stairs[1].level).is_equal(2)
	assert_str(_code(game, PlaceRoomCommand.create(&"room_stairs", 3, Vector2i(2, 16)))).is_equal(
		"no_such_level"
	)


func test_corridor_run_is_one_site_paid_per_cell() -> void:
	var game := ConstructionFixture.state()
	var run: Array[Vector2i] = [Vector2i(10, 16), Vector2i(10, 17), Vector2i(11, 17)]
	assert_bool(ConstructionFixture.run(game, PaintCorridorCommand.create(2, run)).is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(12000 - 15)
	var cells: Array[RoomState] = BaseRules.site_rooms(game.base, game.base.rooms[-3].id)
	assert_int(cells.size()).is_equal(3)
	assert_int(cells[2].build_ticks_left).is_equal(180)


func test_corridor_run_rejections() -> void:
	var game := ConstructionFixture.state()
	var broken: Array[Vector2i] = [Vector2i(10, 16), Vector2i(12, 16)]
	var loose: Array[Vector2i] = [Vector2i(10, 3)]
	var onto: Array[Vector2i] = [Vector2i(10, 15)]
	var empty: Array[Vector2i] = []
	assert_str(_code(game, PaintCorridorCommand.create(2, broken))).is_equal("invalid_run")
	assert_str(_code(game, PaintCorridorCommand.create(2, empty))).is_equal("invalid_run")
	assert_str(_code(game, PaintCorridorCommand.create(2, loose))).is_equal("not_connected")
	assert_str(_code(game, PaintCorridorCommand.create(2, onto))).is_equal("overlap")
