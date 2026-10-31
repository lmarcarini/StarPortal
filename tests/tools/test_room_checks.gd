## Tests for ContentCheckRooms: the real room defs pass; a bad size, a negative cost and a
## duplicate id are rejected.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model
extends GdUnitTestSuite


func _def(id: StringName, size: Vector2i) -> RoomDef:
	var def := RoomDef.new()
	def.id = id
	def.size_cells = size
	return def


## The placeholder room defs in data/rooms pass, and the Gate Room is among them and fixed.
func test_real_rooms_pass() -> void:
	var rooms: Array[RoomDef] = []
	for def: DefBase in Registry.get_all_of(RoomDef):
		rooms.append(def as RoomDef)
	assert_array(rooms).is_not_empty()
	assert_array(ContentCheckRooms.check(rooms)).is_empty()
	var gate: RoomDef = Registry.get_def(BaseState.GATE_ROOM_DEF) as RoomDef
	assert_bool(gate.fixed).is_true()


## A size below one cell, or larger than a level either way it may stand, is rejected.
func test_bad_size() -> void:
	var rooms: Array[RoomDef] = [
		_def(&"zero", Vector2i(0, 2)),
		_def(&"huge", Vector2i(37, 1)),
		_def(&"tall_turned", Vector2i(25, 2)),
		_def(&"ok", Vector2i(20, 2)),
	]
	var errors := ContentCheckRooms.check(rooms)
	assert_int(errors.size()).is_equal(3)
	assert_str(errors[0]).contains("zero")
	assert_str(errors[1]).contains("huge")
	assert_str(errors[2]).contains("tall_turned")
	rooms[2].rotatable = false
	rooms[3].rotatable = false
	assert_int(ContentCheckRooms.check(rooms).size()).is_equal(2)


## Negative cost, build time or power draw is rejected.
func test_negative_numbers() -> void:
	var room := _def(&"bad", Vector2i(2, 2))
	room.build_cost_k = -1
	room.build_ticks = -5
	room.power_draw_mw = -0.5
	var rooms: Array[RoomDef] = [room]
	assert_array(ContentCheckRooms.check(rooms)).has_size(3)


## The same id twice is rejected.
func test_duplicate_id() -> void:
	var rooms: Array[RoomDef] = [_def(&"same", Vector2i.ONE), _def(&"same", Vector2i.ONE)]
	assert_array(ContentCheckRooms.check(rooms)).is_equal(["room same: duplicate id"])
