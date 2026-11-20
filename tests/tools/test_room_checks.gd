## Tests for ContentCheckRooms: the real room defs pass; a bad size, a negative cost and a
## duplicate id are rejected.
## Bible: game-design.md#base-building-and-power, technical-architecture.md#data-model
extends GdUnitTestSuite


func _def(id: StringName, size: Vector2i) -> RoomDef:
	var def := RoomDef.new()
	def.id = id
	def.size_cells = size
	return def


## The M2 room defs in data/rooms pass, and the Gate Room is among them and fixed.
func test_real_rooms_pass() -> void:
	var rooms: Array[RoomDef] = []
	for def: DefBase in Registry.get_all_of(RoomDef):
		rooms.append(def as RoomDef)
	assert_array(rooms).is_not_empty()
	assert_array(ContentCheckRooms.check(rooms)).is_empty()
	var gate: RoomDef = Registry.get_def(StartingBase.GATE_ROOM_DEF) as RoomDef
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


## Negative cost, build time, power draw or upkeep is rejected.
func test_negative_numbers() -> void:
	var room := _def(&"bad", Vector2i(2, 2))
	room.build_cost_k = -1
	room.build_ticks = -5
	room.power_draw_mw = -5.0
	room.upkeep_k = -1
	var rooms: Array[RoomDef] = [room]
	assert_array(ContentCheckRooms.check(rooms)).has_size(4)


## Power comes in 5 MW blocks: a draw, output or charge rate off the block is rejected
## (m25-lean-start.md section 6).
func test_power_in_5_mw_blocks() -> void:
	var room := _def(&"odd", Vector2i(2, 2))
	room.power_draw_mw = 4.0
	room.power_output_mw = 32.0
	room.max_charge_rate_mw = 25.0
	var rooms: Array[RoomDef] = [room]
	var errors: Array[String] = ContentCheckRooms.check(rooms)
	assert_array(errors).has_size(2)
	assert_str(errors[0]).contains("not a multiple of 5")


## The same id twice is rejected.
func test_duplicate_id() -> void:
	var rooms: Array[RoomDef] = [_def(&"same", Vector2i.ONE), _def(&"same", Vector2i.ONE)]
	assert_array(ContentCheckRooms.check(rooms)).is_equal(["room same: duplicate id"])


## The always-on rooms' draw must not exceed the smallest plant's output; with no plant the
## catalogue is rejected too.
func test_always_on_rule() -> void:
	var gate := _def(&"gate", Vector2i.ONE)
	gate.always_on = true
	gate.power_draw_mw = 2.0
	var plant := _def(&"plant", Vector2i.ONE)
	plant.power_output_mw = 30.0
	var rooms: Array[RoomDef] = [gate, plant]
	assert_array(ContentCheckRooms.always_on_errors(rooms)).is_empty()
	gate.power_draw_mw = 31.0
	assert_str(ContentCheckRooms.check(rooms)[0]).contains("always-on draw")
	var no_plant: Array[RoomDef] = [gate]
	assert_str(ContentCheckRooms.always_on_errors(no_plant)[0]).contains(
		"no room gives power output"
	)


## The real catalogue has the doc's numbers for every row (m25-lean-start.md sections 4-6;
## Quarters and Infirmary keep their M2 numbers, the Infirmary's draw rounded up to a block).
func test_catalogue_numbers() -> void:
	# id: [w, h, rotatable, cost, ticks, draw, output, charge, upkeep]
	var table: Dictionary = {
		&"room_gate": [8, 8, false, 0, 0, 5.0, 0.0, 0.0, 0],
		&"room_control": [5, 3, false, 0, 0, 0.0, 0.0, 0.0, 40],
		&"room_power_plant": [5, 4, true, 2000, 1440, 0.0, 30.0, 0.0, 150],
		&"room_capacitor_bank": [3, 2, true, 600, 60, 0.0, 0.0, 30.0, 10],
		&"room_quarters": [3, 2, true, 150, 120, 0.0, 0.0, 0.0, 10],
		&"room_research_lab": [4, 3, true, 800, 480, 5.0, 0.0, 0.0, 60],
		&"room_workshop": [5, 4, true, 700, 360, 5.0, 0.0, 0.0, 50],
		&"room_infirmary": [4, 3, true, 300, 360, 5.0, 0.0, 0.0, 40],
		&"room_lift": [2, 2, false, 400, 240, 0.0, 0.0, 0.0, 10],
		&"room_stairs": [2, 1, true, 100, 120, 0.0, 0.0, 0.0, 0],
		&"room_corridor": [1, 1, false, 5, 10, 0.0, 0.0, 0.0, 0],
		&"room_artefact_vault": [4, 3, true, 600, 360, 5.0, 0.0, 0.0, 40],
		&"room_containment": [3, 3, true, 900, 480, 10.0, 0.0, 0.0, 60],
		&"room_security_post": [2, 2, false, 200, 240, 5.0, 0.0, 0.0, 20],
		&"room_personnel_office": [3, 3, true, 400, 360, 5.0, 0.0, 0.0, 40],
		&"room_xenotech_lab": [4, 3, true, 1200, 600, 10.0, 0.0, 0.0, 80],
		&"room_bio_lab": [4, 3, true, 1000, 600, 5.0, 0.0, 0.0, 70],
		&"room_ready_room": [3, 2, true, 300, 240, 5.0, 0.0, 0.0, 20],
	}
	assert_int(Registry.get_all_of(RoomDef).size()).is_equal(table.size())
	for id: StringName in table:
		var row: Array = table[id]
		var def: RoomDef = Registry.get_def(id) as RoomDef
		assert_object(def).override_failure_message(String(id)).is_not_null()
		var got: Array = [
			def.size_cells.x,
			def.size_cells.y,
			def.rotatable,
			def.build_cost_k,
			def.build_ticks,
			def.power_draw_mw,
			def.power_output_mw,
			def.max_charge_rate_mw,
			def.upkeep_k,
		]
		assert_array(got).override_failure_message(String(id)).is_equal(row)
		assert_bool(def.always_on).is_equal(id in [&"room_gate", &"room_control"])
		assert_str(String(def.name_key)).is_equal(
			"ROOM_%s_NAME" % String(id).trim_prefix("room_").to_upper()
		)
