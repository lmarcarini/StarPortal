## The schematic plan painter: room states, type icons and palette colours.
## Bible: docs/content/interface-pass.md section 5 (The plan)
extends GdUnitTestSuite


func _def(id: StringName) -> RoomDef:
	return Registry.get_def(id) as RoomDef


func _room(def_id: StringName) -> RoomState:
	var room := RoomState.new()
	room.id = &"r1"
	room.def_id = def_id
	return room


func test_states_site_coming_down_on_and_off() -> void:
	var lab: RoomDef = _def(&"room_research_lab")
	var room: RoomState = _room(&"room_research_lab")
	assert_str(String(BasePlanPainter.state_of(room, lab))).is_equal("on")
	room.powered_on = false
	assert_str(String(BasePlanPainter.state_of(room, lab))).is_equal("off")
	room.build_ticks_left = 10
	assert_str(String(BasePlanPainter.state_of(room, lab))).is_equal("site")
	room.build_ticks_left = 0
	room.demolish_ticks_left = 5
	assert_str(String(BasePlanPainter.state_of(room, lab))).is_equal("coming_down")


func test_a_room_with_no_switch_is_drawn_on() -> void:
	var quarters: RoomDef = _def(&"room_lift")
	var room: RoomState = _room(&"room_lift")
	room.powered_on = false
	assert_str(String(BasePlanPainter.state_of(room, quarters))).is_equal("on")


func test_every_room_type_but_the_corridor_has_an_icon() -> void:
	for def: DefBase in Registry.get_all_of(RoomDef):
		var id: StringName = def.id
		if id == StartingBase.CORRIDOR_DEF:
			continue
		assert_bool(RoomIcon.has_icon(id)).override_failure_message(String(id)).is_true()


func test_icon_sits_top_right_inside_the_room() -> void:
	var cells := Rect2i(2, 3, 3, 2)
	var area := Rect2(Vector2(cells.position) * BasePlanPainter.CELL, Vector2(cells.size) * 24.0)
	var centre: Vector2 = BasePlanPainter.icon_centre(cells)
	assert_bool(area.has_point(centre)).is_true()
	assert_float(centre.x).is_greater(area.get_center().x)
	assert_float(centre.y).is_less(area.get_center().y)


func test_colours_come_from_the_palette() -> void:
	assert_float(BasePlanPainter.ROCK.a).is_equal(0.0)
	assert_object(BasePlanPainter.SELECTED).is_equal(UiPalette.SELECT)
	assert_object(BasePlanPainter.GLOW).is_equal(UiPalette.GOOD)
	assert_object(EnergyLayer.ON).is_equal(UiPalette.GOOD)
	for color: Color in [EnergyLayer.ON, EnergyLayer.CHARGE, BasePlanPainter.FLOOR]:
		assert_bool(color.is_equal_approx(UiPalette.RING)).is_false()


func test_every_state_draws_without_errors() -> void:
	var canvas := PlanCanvas.new()
	canvas.size = Vector2(400, 300)
	add_child(canvas)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(canvas.drawn).is_greater(0)
	canvas.free()


class PlanCanvas:
	extends Control
	var drawn: int = 0

	func _draw() -> void:
		var cells := Rect2i(1, 1, 3, 2)
		BasePlanPainter.draw_ground(self, Vector2i(12, 8))
		for id: StringName in RoomIcon.TYPES:
			BasePlanPainter.draw_room(self, cells, id, BasePlanPainter.ON, 2.0)
			BasePlanPainter.draw_room(self, cells, id, BasePlanPainter.OFF, 0.5)
		BasePlanPainter.draw_site(self, cells)
		BasePlanPainter.draw_site(self, cells, true)
		BasePlanPainter.draw_label(self, cells, "RESEARCH LAB", UiThemeBuilder.stencil_font())
		BasePlanPainter.draw_selection(self, cells)
		drawn += 1
