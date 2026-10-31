## Tests for BaseRules: footprints, fitting inside the grid and on a dug level, overlaps,
## rotation and neighbours. Placeholder RoomDefs built in the test.
## Bible: game-design.md#base-building-and-power
extends GdUnitTestSuite

var _defs: Dictionary = {}


func before_test() -> void:
	_defs = {
		&"wide": _def(&"wide", Vector2i(4, 2), true),
		&"fixed_wide": _def(&"fixed_wide", Vector2i(4, 2), false),
		&"one": _def(&"one", Vector2i(1, 1), true),
	}


func _def(id: StringName, size: Vector2i, rotatable: bool) -> RoomDef:
	var def := RoomDef.new()
	def.id = id
	def.size_cells = size
	def.rotatable = rotatable
	return def


func _wide() -> RoomDef:
	return _defs[&"wide"]


func _base() -> BaseState:
	var base := BaseState.new()
	for index: int in 2:
		base.levels.append(LevelState.new())
	base.grid_size = Vector2i(10, 6)
	return base


func _room(id: StringName, def_id: StringName, level: int, origin: Vector2i) -> RoomState:
	return RoomState.create(id, def_id, level, origin)


## The footprint is the origin and the def's size, swapped when turned.
func test_footprint() -> void:
	var room := _room(&"a", &"wide", 1, Vector2i(2, 1))
	assert_that(BaseRules.footprint(room, _wide())).is_equal(Rect2i(2, 1, 4, 2))
	room.rotated = true
	assert_that(BaseRules.footprint(room, _wide())).is_equal(Rect2i(2, 1, 2, 4))


## A room fits only fully inside the grid.
func test_inside_grid() -> void:
	var base := _base()
	assert_bool(BaseRules.fits(base, _defs, _room(&"a", &"wide", 1, Vector2i(6, 4)))).is_true()
	assert_bool(BaseRules.fits(base, _defs, _room(&"a", &"wide", 1, Vector2i(7, 4)))).is_false()
	assert_bool(BaseRules.fits(base, _defs, _room(&"a", &"wide", 1, Vector2i(6, 5)))).is_false()
	assert_bool(BaseRules.fits(base, _defs, _room(&"a", &"wide", 1, Vector2i(-1, 0)))).is_false()


## A room needs a known def and an existing (1 to level_count), dug level.
func test_def_and_level() -> void:
	var base := _base()
	assert_bool(BaseRules.fits(base, _defs, _room(&"a", &"nope", 1, Vector2i.ZERO))).is_false()
	assert_bool(BaseRules.fits(base, _defs, _room(&"a", &"one", 3, Vector2i.ZERO))).is_false()
	assert_bool(BaseRules.fits(base, _defs, _room(&"a", &"one", 0, Vector2i.ZERO))).is_false()
	base.levels[1].dig_ticks_left = 10
	assert_bool(BaseRules.fits(base, _defs, _room(&"a", &"one", 2, Vector2i.ZERO))).is_false()


## Rooms on the same level may not overlap; other levels and the room itself do not count.
func test_overlap() -> void:
	var base := _base()
	base.rooms.append(_room(&"a", &"wide", 1, Vector2i(2, 2)))
	assert_bool(BaseRules.fits(base, _defs, _room(&"b", &"one", 1, Vector2i(5, 3)))).is_false()
	assert_bool(BaseRules.fits(base, _defs, _room(&"b", &"one", 1, Vector2i(6, 3)))).is_true()
	assert_bool(BaseRules.fits(base, _defs, _room(&"b", &"one", 2, Vector2i(3, 3)))).is_true()
	assert_bool(BaseRules.fits(base, _defs, base.rooms[0])).is_true()


## A turned room needs a rotatable def, and its turned footprint must fit.
func test_rotation() -> void:
	var base := _base()
	var room := _room(&"a", &"wide", 1, Vector2i(0, 2))
	room.rotated = true
	assert_bool(BaseRules.fits(base, _defs, room)).is_true()
	room.origin = Vector2i(0, 3)
	assert_bool(BaseRules.fits(base, _defs, room)).is_false()
	var fixed := _room(&"b", &"fixed_wide", 1, Vector2i(5, 0))
	fixed.rotated = true
	assert_bool(BaseRules.fits(base, _defs, fixed)).is_false()


## rooms_on_level() lists the rooms of one level in placement order.
func test_rooms_on_level() -> void:
	var base := _base()
	base.rooms.append(_room(&"a", &"one", 2, Vector2i.ZERO))
	base.rooms.append(_room(&"b", &"one", 1, Vector2i.ZERO))
	base.rooms.append(_room(&"c", &"one", 2, Vector2i(3, 3)))
	var ids: Array[StringName] = []
	for room: RoomState in BaseRules.rooms_on_level(base, 2):
		ids.append(room.id)
	assert_array(ids).is_equal([&"a", &"c"])


## Neighbours share an edge on the same level; corners, gaps and other levels do not count.
func test_neighbours() -> void:
	var base := _base()
	var centre := _room(&"centre", &"wide", 1, Vector2i(2, 2))
	base.rooms.append(centre)
	base.rooms.append(_room(&"left", &"one", 1, Vector2i(1, 3)))
	base.rooms.append(_room(&"above", &"one", 1, Vector2i(5, 1)))
	base.rooms.append(_room(&"corner", &"one", 1, Vector2i(6, 4)))
	base.rooms.append(_room(&"gap", &"one", 1, Vector2i(0, 2)))
	base.rooms.append(_room(&"below_other_level", &"one", 2, Vector2i(2, 4)))
	var ids: Array[StringName] = []
	for room: RoomState in BaseRules.neighbours(base, _defs, centre):
		ids.append(room.id)
	assert_array(ids).is_equal([&"left", &"above"])
