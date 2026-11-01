## Tests for ConstructionSystem with CancelBuildCommand and DemolishRoomCommand: build times,
## the three-site queue, refunds, demolition, the rules on what can come down, and saving
## mid-build.
## Bible: docs/content/m2-base.md section 4
extends GdUnitTestSuite

const LAB: StringName = &"room_physics_lab"


func _place_lab(game: GameState) -> RoomState:
	ConstructionFixture.run(game, PlaceRoomCommand.create(LAB, 2, Vector2i(20, 16)))
	game.events.drain()
	return game.base.rooms[-1]


func test_room_is_built_after_its_time_and_posts_once() -> void:
	var game := ConstructionFixture.state()
	var lab := _place_lab(game)
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, game.room_defs[LAB].build_ticks - 1)
	assert_bool(lab.is_built()).is_false()
	assert_array(ConstructionFixture.event_names(game)).is_empty()
	ConstructionFixture.advance(game, system, 1)
	assert_bool(lab.is_built()).is_true()
	ConstructionFixture.advance(game, system, 10)
	assert_array(ConstructionFixture.event_names(game)).is_equal([&"room_built"])


func test_fourth_site_waits_in_the_queue() -> void:
	var game := ConstructionFixture.state()
	for column: int in [5, 9, 13, 17]:
		ConstructionFixture.run(
			game, PlaceRoomCommand.create(&"room_quarters", 2, Vector2i(column, 16))
		)
	var queue := ConstructionSystem.site_queue(game.base)
	assert_int(queue.size()).is_equal(4)
	ConstructionSystem.new().tick(game)
	var fourth: RoomState = game.base.find_room(queue[3])
	assert_int(fourth.build_ticks_left).is_equal(game.room_defs[&"room_quarters"].build_ticks)
	assert_int(game.base.find_room(queue[0]).build_ticks_left).is_equal(fourth.build_ticks_left - 1)


func test_corridor_run_finishes_cell_by_cell() -> void:
	var game := ConstructionFixture.state()
	var run: Array[Vector2i] = [Vector2i(10, 16), Vector2i(10, 17)]
	ConstructionFixture.run(game, PaintCorridorCommand.create(2, run))
	game.events.drain()
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, 60)
	assert_bool(game.base.rooms[-2].is_built()).is_true()
	assert_bool(game.base.rooms[-1].is_built()).is_false()
	ConstructionFixture.advance(game, system, 60)
	assert_array(ConstructionFixture.event_names(game)).is_equal([&"room_built"])


func test_cancel_refunds_three_quarters() -> void:
	var game := ConstructionFixture.state()
	var lab := _place_lab(game)
	ConstructionSystem.new().tick(game)
	assert_bool(ConstructionFixture.run(game, CancelBuildCommand.create(lab.id)).is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(12000 - 800 + 600)
	assert_object(game.base.find_room(lab.id)).is_null()
	var again := CancelBuildCommand.create(game.base.rooms[0].id).validate(game)
	assert_str(again.error_code).is_equal("not_a_site")


func test_demolish_refunds_half_and_takes_a_quarter_of_the_time() -> void:
	var game := ConstructionFixture.state()
	var lab := _place_lab(game)
	var system := ConstructionSystem.new()
	var ticks: int = game.room_defs[LAB].build_ticks
	ConstructionFixture.advance(game, system, ticks)
	game.events.drain()
	assert_bool(ConstructionFixture.run(game, DemolishRoomCommand.create(lab.id)).is_ok).is_true()
	assert_int(game.budget.funds_k).is_equal(12000 - 800 + 400)
	assert_bool(lab.powered_on).is_false()
	assert_str(DemolishRoomCommand.create(lab.id).validate(game).error_code).is_equal(
		"already_demolishing"
	)
	ConstructionFixture.advance(game, system, ticks / 4 - 1)
	assert_object(game.base.find_room(lab.id)).is_not_null()
	ConstructionFixture.advance(game, system, 1)
	assert_object(game.base.find_room(lab.id)).is_null()
	assert_array(ConstructionFixture.event_names(game)).is_equal(
		[&"budget_changed", &"room_demolished"]
	)


func test_cannot_demolish_protected_rooms() -> void:
	var game := ConstructionFixture.state()
	var codes: Dictionary[StringName, StringName] = {}
	for room: RoomState in game.base.rooms:
		var code: StringName = DemolishRoomCommand.create(room.id).validate(game).error_code
		codes[room.def_id] = code
	assert_str(codes[&"room_gate"]).is_equal("fixed_room")
	assert_str(codes[&"room_control"]).is_equal("fixed_room")
	assert_str(codes[&"room_power_plant"]).is_equal("last_plant")
	assert_str(codes[&"room_lift"]).is_equal("starting_lift")
	var lab := _place_lab(game)
	assert_str(DemolishRoomCommand.create(lab.id).validate(game).error_code).is_equal("not_built")


func test_cannot_demolish_a_corridor_a_room_hangs_on() -> void:
	var game := ConstructionFixture.state()
	var run: Array[Vector2i] = [Vector2i(10, 16)]
	ConstructionFixture.run(game, PaintCorridorCommand.create(2, run))
	var cell: RoomState = game.base.rooms[-1]
	ConstructionFixture.run(game, PlaceRoomCommand.create(&"room_quarters", 2, Vector2i(9, 17)))
	ConstructionFixture.advance(game, ConstructionSystem.new(), 3000)
	assert_str(DemolishRoomCommand.create(cell.id).validate(game).error_code).is_equal(
		"leaves_room_unconnected"
	)


func test_save_mid_build_keeps_progress() -> void:
	var game := ConstructionFixture.state()
	_place_lab(game)
	var run: Array[Vector2i] = [Vector2i(10, 16), Vector2i(10, 17)]
	ConstructionFixture.run(game, PaintCorridorCommand.create(2, run))
	ConstructionFixture.advance(game, ConstructionSystem.new(), 100)
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.base.to_dict()))
	assert_array(BaseState.validate_dict(data)).is_empty()
	var loaded := BaseState.from_dict(data)
	assert_dict(loaded.to_dict()).is_equal(game.base.to_dict())
	assert_int(loaded.rooms[-1].build_ticks_left).is_equal(20)
