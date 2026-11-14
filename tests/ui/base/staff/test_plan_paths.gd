## Walking paths over fixed layouts: through corridors, never through walls, between levels
## by a lift, none when cut off.
## Bible: docs/content/interface-pass.md section 5 (Staff walk)
extends GdUnitTestSuite

var _defs: Dictionary = {}


func before_test() -> void:
	for id: StringName in [&"room_corridor", &"room_lift", &"room_quarters", &"room_research_lab"]:
		_defs[id] = Registry.get_def(id)


func _base(rooms: Array) -> BaseState:
	var base := BaseState.new()
	base.grid_size = Vector2i(30, 20)
	base.level_count = 2
	for entry: Array in rooms:
		var def_id: StringName = entry[0]
		var level: int = entry[1]
		var origin: Vector2i = entry[2]
		var room: RoomState = base.add_room(def_id, level, origin)
		room.build_ticks_left = 0
	return base


func test_two_rooms_side_by_side_connect_only_through_the_corridor() -> void:
	var lab: Vector2i = (Registry.get_def(&"room_research_lab") as RoomDef).size_cells
	var quarters: Vector2i = (Registry.get_def(&"room_quarters") as RoomDef).size_cells
	var row: int = maxi(lab.y, quarters.y)
	var from := Vector3i(0, row - lab.y, 1)
	var to := Vector3i(lab.x, row - quarters.y, 1)
	var rooms: Array = [
		[&"room_research_lab", 1, Vector2i(from.x, from.y)],
		[&"room_quarters", 1, Vector2i(to.x, to.y)],
	]
	var base: BaseState = _base(rooms)
	assert_int(PlanPaths.find(base, from, to, _defs).size()).is_equal(0)
	for x: int in range(0, lab.x + quarters.x):
		base.add_room(&"room_corridor", 1, Vector2i(x, row)).build_ticks_left = 0
	var path: PackedVector3Array = PlanPaths.find(base, from, to, _defs)
	assert_int(path.size()).is_greater(0)
	var used_corridor: bool = false
	for point: Vector3 in path:
		if is_equal_approx(point.y, row + 0.5):
			used_corridor = true
	assert_bool(used_corridor).is_true()


func test_levels_join_through_the_lift_shaft() -> void:
	var rooms: Array = [
		[&"room_corridor", 1, Vector2i(0, 0)],
		[&"room_lift", 1, Vector2i(1, 0)],
		[&"room_lift", 2, Vector2i(1, 0)],
		[&"room_corridor", 2, Vector2i(2, 0)],
	]
	var base: BaseState = _base(rooms)
	var path: PackedVector3Array = PlanPaths.find(base, Vector3i(0, 0, 1), Vector3i(2, 0, 2), _defs)
	assert_int(path.size()).is_greater(0)
	assert_float(path[0].z).is_equal(1.0)
	assert_float(path[path.size() - 1].z).is_equal(2.0)


func test_unbuilt_rooms_and_missing_cells_give_no_path() -> void:
	var base: BaseState = _base([[&"room_corridor", 1, Vector2i(0, 0)]])
	var site: RoomState = base.add_room(&"room_corridor", 1, Vector2i(1, 0))
	site.build_ticks_left = 50
	base.add_room(&"room_corridor", 1, Vector2i(2, 0)).build_ticks_left = 0
	assert_int(PlanPaths.find(base, Vector3i(0, 0, 1), Vector3i(2, 0, 1), _defs).size()).is_equal(0)
	assert_int(PlanPaths.find(base, Vector3i(9, 9, 1), Vector3i(0, 0, 1), _defs).size()).is_equal(0)


func test_walker_moves_stops_while_paused_and_snaps() -> void:
	var walker := TokenWalker.new()
	var token := StaffToken.new()
	token.person_id = &"p"
	token.position = Vector2(12, 12)
	token.home = Vector2(12 + 24 * 4, 12)
	var path := PackedVector3Array(
		[Vector3(0.5, 0.5, 1), Vector3(2.5, 0.5, 1), Vector3(4.5, 0.5, 1)]
	)
	walker.walk(token, path)
	var tokens: Dictionary[StringName, StaffToken] = {&"p": token}
	assert_bool(walker.step(tokens, 0.5, 1, true)).is_false()
	assert_object(token.position).is_equal(Vector2(12, 12))
	walker.step(tokens, 0.5, 1, false)
	assert_float(token.position.x).is_greater(12.0)
	assert_bool(walker.is_moving(&"p")).is_true()
	walker.snap_all([token])
	assert_object(token.position).is_equal(token.home)
	assert_bool(walker.is_moving(&"p")).is_false()


func test_no_path_fades_out_and_in_at_home() -> void:
	var walker := TokenWalker.new()
	var token := StaffToken.new()
	token.person_id = &"p"
	token.home = Vector2(100, 100)
	walker.walk(token, PackedVector3Array())
	var tokens: Dictionary[StringName, StaffToken] = {&"p": token}
	walker.step(tokens, TokenWalker.FADE_SECONDS * 0.5, 1, false)
	assert_float(walker.alpha_of(&"p")).is_less(1.0)
	walker.step(tokens, TokenWalker.FADE_SECONDS, 1, false)
	assert_object(token.position).is_equal(token.home)
	walker.step(tokens, TokenWalker.FADE_SECONDS, 1, false)
	assert_bool(walker.is_moving(&"p")).is_false()
