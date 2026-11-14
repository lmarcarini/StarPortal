## Squads (M4c-05): a Security Post with an able soldier is a squad, numbered by build order;
## Move to walks 2 cells a tick and holds, Fall back returns home; orders work paused; a
## soldier unassigned, injured or sent through the Ring leaves at once; saves continue a move.
## Bible: docs/content/m4c-incursions.md sections 2 and 3
extends GdUnitTestSuite

var _state: GameState
var _simulation: Simulation
var _post: RoomState


func before_test() -> void:
	_state = GameState.new_game(5, Registry.balance())
	_simulation = GameSetup.build_new(_state, GameDefs.from_registry(Registry)).value
	_post = _place_post()
	_hire(&"soldier_a")
	_hire(&"soldier_b")


## A built Security Post on the spine row's level, touching the corridor.
func _place_post() -> RoomState:
	var spine: int = StartingBase.SPINE_ROW
	for x: int in range(2, _state.base.grid_size.x - 2):
		var command := PlaceRoomCommand.create(SquadRules.POST_DEF, 1, Vector2i(x, spine + 1))
		if command.validate(_state).is_ok:
			command.apply(_state)
			var room: RoomState = _state.base.rooms[_state.base.rooms.size() - 1]
			for site_room: RoomState in BaseRules.site_rooms(_state.base, room.site_key()):
				site_room.build_ticks_left = 0
			return room
	return null


func _hire(id: StringName) -> PersonState:
	var person := PersonState.new()
	person.id = id
	person.role = SquadRules.SOLDIER
	person.name = String(id)
	person.skill = 3
	person.room_id = _post.id
	_state.staff.people.append(person)
	return person


func _ticks(count: int) -> void:
	for index: int in count:
		_simulation.advance_tick()


func _corridor_cell(away: int) -> Vector3i:
	var home: Vector3i = SquadRules.home_of(_post)
	var best := Vector3i(-1, -1, -1)
	var best_distance: int = -1
	for room: RoomState in _state.base.rooms:
		if room.def_id != StartingBase.CORRIDOR_DEF or room.level != 1:
			continue
		var cell := Vector3i(room.origin.x, room.origin.y, 1)
		var distance: int = BasePaths.walking_distance(_state.base, home, cell, _state.room_defs)
		if distance >= away and (best_distance < 0 or distance < best_distance):
			best = cell
			best_distance = distance
	return best


func test_a_post_with_soldiers_is_squad_one() -> void:
	_ticks(1)
	assert_int(_state.security.squads.size()).is_equal(1)
	assert_int(SquadRules.number_of(_state, _post.id)).is_equal(1)
	assert_array(SquadRules.members(_state, _post.id)).has_size(2)


func test_move_walks_two_cells_a_tick_and_holds_then_falls_back() -> void:
	_ticks(1)
	var target: Vector3i = _corridor_cell(6)
	var home: Vector3i = SquadRules.home_of(_post)
	var far: int = BasePaths.walking_distance(_state.base, home, target, _state.room_defs)
	var order := OrderSquadCommand.create(_post.id, SquadState.Order.MOVE, target)
	assert_bool(order.validate(_state).is_ok).is_true()
	order.apply(_state)
	var squad: SquadState = _state.security.squad_of(_post.id)
	assert_str(str(squad.pos)).is_equal(str(home))
	_ticks(1)
	var walked: int = (
		far - BasePaths.walking_distance(_state.base, squad.pos, target, _state.room_defs)
	)
	assert_int(walked).is_equal(2)
	_ticks(far)
	assert_str(str(squad.pos)).is_equal(str(target))
	assert_int(squad.order).is_equal(SquadState.Order.HOLD)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(saved)).is_empty()
	(
		assert_bool(
			_simulation.submit(OrderSquadCommand.create(_post.id, SquadState.Order.FALL_BACK)).is_ok
		)
		. is_true()
	)
	_ticks(1)
	var reread: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	var loaded: GameState = GameState.from_dict(reread)
	assert_int(loaded.security.squads[0].order).is_equal(SquadState.Order.FALL_BACK)
	_ticks(far)
	assert_str(str(squad.pos)).is_equal(str(home))


func test_refusals() -> void:
	_ticks(1)
	(
		assert_str(
			String(
				(
					OrderSquadCommand
					. create(&"room_x", SquadState.Order.HOLD)
					. validate(_state)
					. error_code
				)
			)
		)
		. is_equal("no_squad")
	)
	var nowhere := OrderSquadCommand.create(_post.id, SquadState.Order.MOVE, Vector3i(0, 0, 1))
	assert_str(String(nowhere.validate(_state).error_code)).is_equal("no_path")
	for person: PersonState in _state.staff.people:
		if person.room_id == _post.id:
			person.injury = PersonState.Injury.SERIOUS
	var held := OrderSquadCommand.create(_post.id, SquadState.Order.HOLD)
	assert_str(String(held.validate(_state).error_code)).is_equal("squad_down")


func test_leaving_the_post_leaves_the_squad_at_once() -> void:
	_ticks(1)
	for person: PersonState in _state.staff.people:
		if person.room_id == _post.id:
			person.room_id = &""
	_ticks(1)
	assert_array(_state.security.squads).is_empty()
