## Tests for the Base tab: the plan shows each level's rooms at their cells, the alcove as a
## marked site and rooms under construction as sites; selection by mouse, keyboard and action
## fills the panel; level actions change level; zoom and pan; the layout fits 1280 × 720 in
## both languages.
## Bible: docs/content/m2-base.md section 6
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
## Size of the area the shell gives a view at 1280 × 720.
const VIEW_SIZE: Vector2 = Vector2(1280, 640)

var _root: Control = null
var _view: BaseView = null
var _runner: GdUnitSceneRunner = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = Simulation.new(GameState.new_game(1, Registry.balance()))
	_root = Control.new()
	_root.size = VIEW_SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as BaseView
	_root.add_child(_view)
	_runner = scene_runner(_root)
	_view.setup(_simulation)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func test_starts_on_the_gate_level_with_rooms_at_their_cells() -> void:
	var plan: BasePlan = _view.get_plan()
	assert_int(plan.level).is_equal(3)
	assert_str(_def_at(Vector2i(16, 6))).is_equal("room_gate")
	assert_str(_def_at(Vector2i(16, 13))).is_equal("room_control")
	assert_str(_def_at(Vector2i(10, 15))).is_equal("room_corridor")
	assert_str(String(plan.item_at(Vector2i(23, 11)))).is_equal(String(BasePlan.ALCOVE))
	assert_str(String(plan.item_at(Vector2i(0, 0)))).is_equal("")
	assert_str(_view.get_title_key()).is_equal("BASE_TITLE")
	assert_object(_view.get_default_focus()).is_same(plan)


func test_level_actions_change_level_and_rooms() -> void:
	var plan: BasePlan = _view.get_plan()
	await _press_action(&"base_level_up")
	assert_int(plan.level).is_equal(2)
	assert_str(_def_at(Vector2i(13, 13))).is_equal("room_archive")
	assert_str(String(plan.item_at(Vector2i(23, 11)))).is_equal("")
	await _press_action(&"base_level_up")
	await _press_action(&"base_level_up")
	assert_int(plan.level).is_equal(1)
	assert_str(_def_at(Vector2i(7, 12))).is_equal("room_power_plant")
	await _press_action(&"base_level_down")
	assert_int(plan.level).is_equal(2)


func test_click_selects_a_room_and_fills_the_panel() -> void:
	var plan: BasePlan = _view.get_plan()
	_click(plan, Vector2i(16, 6))
	assert_str(_def_of(plan.selected())).is_equal("room_gate")
	var lines: Array[String] = _view.get_room_panel().lines()
	assert_str(lines[0]).is_equal("SELECTED")
	assert_str(lines[1]).is_equal("Gate Room")
	assert_str(lines[2]).is_equal("Size 8 × 8 cells")
	assert_str(lines[3]).contains("MW")
	assert_str(lines[5]).is_equal("Always on")
	_click(plan, Vector2i(0, 0))
	assert_str(String(plan.selected())).is_equal("")


func test_cursor_and_accept_select_the_alcove() -> void:
	var plan: BasePlan = _view.get_plan()
	plan.grab_focus()
	plan.cursor = Vector2i(21, 11)
	_send(plan, _action(&"ui_right"))
	assert_vector(Vector2(plan.cursor)).is_equal(Vector2(22, 11))
	_send(plan, _action(&"ui_accept"))
	assert_str(String(plan.selected())).is_equal(String(BasePlan.ALCOVE))
	assert_str(_view.get_room_panel().lines()[1]).is_equal("Capacitor alcove")
	plan.cursor = Vector2i.ZERO
	_send(plan, _action(&"ui_up"))
	assert_vector(Vector2(plan.cursor)).is_equal(Vector2.ZERO)


func test_a_room_under_construction_shows_days_left() -> void:
	var room: RoomState = _simulation.state.base.add_room(&"room_physics_lab", 3, Vector2i(4, 4))
	room.build_ticks_left = TimeMath.TICKS_PER_DAY * 5 - 10
	_view.get_plan().select(room.id)
	var lines: Array[String] = _view.get_room_panel().lines()
	assert_str(lines[1]).is_equal("Physics Lab")
	assert_str(lines[3]).is_equal("Draw 4 MW")
	assert_str(lines[4]).is_equal("Upkeep $60k / month")
	assert_str(lines[5]).is_equal("Under construction: 5 d left")


func test_wheel_zooms_and_drag_pans() -> void:
	var plan: BasePlan = _view.get_plan()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = plan.size * 0.5
	_send(plan, wheel)
	assert_float(plan.view.zoom).is_greater(1.0)
	var before: Vector2 = plan.view.offset
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	_send(plan, press)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(-30, 0)
	_send(plan, motion)
	assert_float(plan.view.offset.x).is_equal_approx(before.x - 30.0, 0.01)


func test_layout_fits_in_both_languages() -> void:
	for locale: String in ["en", "pt_BR"]:
		TranslationServer.set_locale(locale)
		_view.get_plan().select(_view.get_plan().item_at(Vector2i(16, 13)))
		await _runner.simulate_frames(2)
		var columns: Control = _view.get_node("Columns") as Control
		var needed: Vector2 = columns.get_combined_minimum_size()
		assert_bool(needed.x <= VIEW_SIZE.x and needed.y <= VIEW_SIZE.y).is_true()
		assert_str(_view.get_room_panel().lines()[1]).is_not_empty()


func _def_at(cell: Vector2i) -> String:
	return _def_of(_view.get_plan().item_at(cell))


func _def_of(room_id: StringName) -> String:
	var room: RoomState = _simulation.state.base.find_room(room_id)
	return String(room.def_id) if room != null else ""


func _click(plan: BasePlan, cell: Vector2i) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var centre: Vector2 = (Vector2(cell) + Vector2.ONE * 0.5) * BasePlanPainter.CELL
	event.position = plan.view.offset + centre * plan.view.scale()
	_send(plan, event)


func _send(plan: BasePlan, event: InputEvent) -> void:
	BasePlanInput.handle(plan, event)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _press_action(action: StringName) -> void:
	_runner.simulate_action_pressed(String(action))
	await _runner.await_input_processed()
