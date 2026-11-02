## Tests for the review fixes: connection rules counting demolitions as gone, cancel removing
## whole runs, one room_demolished per order, rounded-down refunds, a full game save
## mid-demolition, construction validation, grid-sized corridor runs and lift level range.
## Bible: docs/content/m2-base.md section 4
extends GdUnitTestSuite


func _state() -> GameState:
	return ConstructionFixture.grown()


func _paint(game: GameState, run: Array[Vector2i]) -> RoomState:
	ConstructionFixture.run(game, PaintCorridorCommand.create(2, run))
	return BaseRules.site_rooms(game.base, game.base.rooms[-1].site_key())[0]


## Quarters at (11,17) touch only corridor cells (10,17) and (14,17).
func _hanging_quarters(game: GameState) -> Array[RoomState]:
	var west: RoomState = _paint(game, [Vector2i(10, 16), Vector2i(10, 17)])
	var east: RoomState = _paint(game, [Vector2i(14, 16), Vector2i(14, 17)])
	ConstructionFixture.run(game, PlaceRoomCommand.create(&"room_quarters", 2, Vector2i(11, 17)))
	ConstructionFixture.advance(game, ConstructionSystem.new(), 3000)
	game.events.drain()
	return [game.base.rooms[-4], game.base.rooms[-2]]


func test_second_demolition_cannot_strand_a_room() -> void:
	var game := _state()
	var cells: Array[RoomState] = _hanging_quarters(game)
	assert_object(cells[0].origin).is_equal(Vector2i(10, 17))
	assert_object(cells[1].origin).is_equal(Vector2i(14, 17))
	(
		assert_bool(ConstructionFixture.run(game, DemolishRoomCommand.create(cells[0].id)).is_ok)
		. is_true()
	)
	var second := DemolishRoomCommand.create(cells[1].id).validate(game)
	assert_str(second.error_code).is_equal("leaves_room_unconnected")


func test_each_corridor_demolition_posts_once() -> void:
	var game := _state()
	var first: RoomState = _paint(game, [Vector2i(10, 16), Vector2i(10, 17), Vector2i(10, 18)])
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, 180)
	game.events.drain()
	var last: RoomState = BaseRules.site_rooms(game.base, first.id)[2]
	ConstructionFixture.run(game, DemolishRoomCommand.create(last.id))
	ConstructionFixture.advance(game, system, 100)
	var events: Array[SimEvent] = game.events.drain()
	var demolished: Array = []
	for event: SimEvent in events:
		if event.name == &"room_demolished":
			demolished.append(event.args[0])
	assert_array(demolished).is_equal([last.id])
	assert_int(BaseRules.site_rooms(game.base, first.id).size()).is_equal(2)


func test_cancel_removes_the_whole_run_and_refunds_its_full_cost() -> void:
	var game := _state()
	var first: RoomState = _paint(game, [Vector2i(10, 16), Vector2i(10, 17), Vector2i(10, 18)])
	ConstructionFixture.advance(game, ConstructionSystem.new(), 10)
	assert_bool(first.is_built()).is_true()
	assert_bool(ConstructionFixture.run(game, CancelBuildCommand.create(first.id)).is_ok).is_true()
	assert_array(BaseRules.site_rooms(game.base, first.id)).is_empty()
	assert_int(game.budget.funds_k).is_equal(12000 - 15 + 11)


func test_cancel_cannot_strand_a_room() -> void:
	var game := _state()
	var cell: RoomState = _paint(game, [Vector2i(10, 16)])
	ConstructionFixture.run(game, PlaceRoomCommand.create(&"room_quarters", 2, Vector2i(9, 17)))
	var result := CancelBuildCommand.create(cell.id).validate(game)
	assert_str(result.error_code).is_equal("leaves_room_unconnected")


func test_refunds_round_down_to_whole_k() -> void:
	var game := _state()
	var cell: RoomState = _paint(game, [Vector2i(10, 16)])
	ConstructionFixture.run(game, CancelBuildCommand.create(cell.id))
	assert_int(game.budget.funds_k).is_equal(12000 - 5 + 3)
	cell = _paint(game, [Vector2i(10, 16)])
	ConstructionFixture.advance(game, ConstructionSystem.new(), 60)
	ConstructionFixture.run(game, DemolishRoomCommand.create(cell.id))
	assert_int(game.budget.funds_k).is_equal(12000 - 5 + 3 - 5 + 2)


func test_full_game_save_mid_demolition_keeps_progress() -> void:
	var game := _state()
	ConstructionFixture.run(
		game, PlaceRoomCommand.create(&"room_research_lab", 2, Vector2i(20, 16))
	)
	var lab: RoomState = game.base.rooms[-1]
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, lab.build_ticks_left)
	ConstructionFixture.run(game, DemolishRoomCommand.create(lab.id))
	ConstructionFixture.run(game, DigLevelCommand.new())
	ConstructionFixture.advance(game, system, 50)
	var data: Dictionary = JSON.parse_string(JSON.stringify(game.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded := GameState.from_dict(data)
	assert_dict(loaded.to_dict()).is_equal(game.to_dict())
	var copy: RoomState = loaded.base.find_room(lab.id)
	assert_int(copy.demolish_ticks_left).is_equal(lab.demolish_ticks_left)
	assert_bool(copy.powered_on).is_false()
	assert_int(loaded.base.levels[3].dig_ticks_left).is_equal(5 * 1440 - 50)


func test_validate_rejects_inconsistent_construction() -> void:
	var game := _state()
	game.base.start_dig(10)
	var data: Dictionary = game.base.to_dict()
	assert_array(BaseState.validate_dict(data)).is_empty()
	var rooms: Array = data["rooms"]
	var first_room: Dictionary = rooms[0]
	var bad_room: Dictionary = first_room.duplicate()
	bad_room["id"] = "room_999"
	bad_room["level"] = 4
	data["next_room_number"] = 1000
	rooms.append(bad_room)
	assert_array(BaseState.validate_dict(data)).is_not_empty()
	rooms.pop_back()
	var levels: Array = data["levels"]
	levels[2] = {"dig_ticks_left": 5}
	assert_array(BaseState.validate_dict(data)).is_not_empty()
	levels[2] = {"dig_ticks_left": 0}
	first_room["build_ticks_left"] = 5
	first_room["demolish_ticks_left"] = 5
	assert_array(BaseState.validate_dict(data)).is_not_empty()


func test_corridor_run_limit_follows_the_grid() -> void:
	var game := _state()
	game.base.grid_size = Vector2i(36, 16)
	var run: Array[Vector2i] = []
	for index: int in 36 * 16 + 1:
		run.append(Vector2i(index % 36, 16))
	var result := PaintCorridorCommand.create(2, run).validate(game)
	assert_str(result.error_code).is_equal("invalid_run")


func test_lift_rejects_a_level_out_of_range() -> void:
	var game := _state()
	for level: int in [0, 4, 99]:
		var result := PlaceRoomCommand.create(&"room_lift", level, Vector2i(2, 14)).validate(game)
		assert_str(result.error_code).is_equal("no_such_level")


## Funds spent minus funds refunded on [param game] since it started at 12000.
func _net_cost(game: GameState) -> int:
	return 12000 - game.budget.funds_k


func test_cancel_refused_while_run_cells_are_demolished() -> void:
	var game := _state()
	var run: Array[Vector2i] = [
		Vector2i(10, 16), Vector2i(10, 17), Vector2i(10, 18), Vector2i(10, 19)
	]
	var first: RoomState = _paint(game, run)
	var system := ConstructionSystem.new()
	ConstructionFixture.advance(game, system, 30)
	var cells: Array[RoomState] = BaseRules.site_rooms(game.base, first.id)
	for index: int in [2, 1, 0]:
		ConstructionFixture.run(game, DemolishRoomCommand.create(cells[index].id))
	var result := CancelBuildCommand.create(cells[3].id).validate(game)
	assert_str(result.error_code).is_equal("demolition_in_progress")
	assert_int(_net_cost(game)).is_greater_equal(0)


## Every order of paint, demolish and cancel on one run, with the clock running between them,
## refunds no more than the run cost.
func test_refunds_never_exceed_cost_on_one_run() -> void:
	var run: Array[Vector2i] = [Vector2i(10, 16), Vector2i(10, 17), Vector2i(10, 18)]
	for plan: int in 81:
		var game := _state()
		var first: RoomState = _paint(game, run)
		var system := ConstructionSystem.new()
		var cells: Array[RoomState] = BaseRules.site_rooms(game.base, first.id)
		var step_plan: int = plan
		for step: int in 4:
			var choice: int = step_plan % 3
			step_plan /= 3
			ConstructionFixture.advance(game, system, 60)
			if choice == 1:
				ConstructionFixture.run(game, CancelBuildCommand.create(cells[step % 3].id))
			elif choice == 2:
				ConstructionFixture.run(game, DemolishRoomCommand.create(cells[2 - step % 3].id))
		ConstructionFixture.advance(game, system, 200)
		assert_int(_net_cost(game)).is_greater_equal(0)
