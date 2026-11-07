## Tests for the Base tab: the plan shows each level's rooms at their cells, no reserved
## cells, and rooms under construction as sites; selection by mouse, keyboard and action
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
	EventBus.bind_simulation(null)
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func test_starts_on_the_gate_level_with_rooms_at_their_cells() -> void:
	var plan: BasePlan = _view.get_plan()
	assert_int(plan.level).is_equal(1)
	assert_str(_def_at(Vector2i(16, 6))).is_equal("room_gate")
	assert_str(_def_at(Vector2i(16, 13))).is_equal("room_control")
	assert_str(_def_at(Vector2i(10, 10))).is_equal("room_corridor")
	assert_str(_def_at(Vector2i(7, 12))).is_equal("room_power_plant")
	# The former capacitor alcove's cells are ordinary free cells (card #158).
	assert_str(String(plan.item_at(Vector2i(23, 11)))).is_equal("")
	assert_str(String(plan.item_at(Vector2i(0, 0)))).is_equal("")
	assert_str(_view.get_title_key()).is_equal("BASE_TITLE")
	assert_object(_view.get_default_focus()).is_same(plan)


func test_level_actions_change_level_and_rooms() -> void:
	var plan: BasePlan = _view.get_plan()
	await _press_action(&"base_level_up")
	assert_int(plan.level).is_equal(1)
	await _press_action(&"base_level_down")
	assert_int(plan.level).is_equal(1)
	var base: BaseState = _simulation.state.base
	base.levels.append(LevelState.new())
	base.add_room(&"room_corridor", 2, Vector2i(5, 5))
	_view.setup(_simulation)
	await _press_action(&"base_level_down")
	assert_int(plan.level).is_equal(2)
	assert_str(_def_at(Vector2i(5, 5))).is_equal("room_corridor")
	await _press_action(&"base_level_up")
	assert_int(plan.level).is_equal(1)


## The level caption follows the shown level, in pt_BR too (PO note on card #164: it read
## "NÍVEL 3" while Level 1 was shown).
func test_level_caption_follows_the_shown_level() -> void:
	var heading: Label = _view.get_node("%LevelHeading")
	assert_str(heading.text).is_equal("LEVEL 1")
	TranslationServer.set_locale("pt_BR")
	await _runner.await_input_processed()
	assert_str(heading.text).is_equal("NÍVEL 1")
	_simulation.state.base.levels.append(LevelState.new())
	_view.setup(_simulation)
	await _press_action(&"base_level_down")
	assert_str(heading.text).is_equal("NÍVEL 2")


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


func test_cursor_and_accept_on_a_free_cell_select_nothing() -> void:
	var plan: BasePlan = _view.get_plan()
	plan.grab_focus()
	plan.cursor = Vector2i(21, 11)
	_send(plan, _action(&"ui_right"))
	assert_vector(Vector2(plan.cursor)).is_equal(Vector2(22, 11))
	_send(plan, _action(&"ui_accept"))
	assert_str(String(plan.selected())).is_equal("")
	assert_str(_view.get_room_panel().lines()[1]).is_equal("")
	plan.cursor = Vector2i.ZERO
	_send(plan, _action(&"ui_up"))
	assert_vector(Vector2(plan.cursor)).is_equal(Vector2.ZERO)


func test_a_room_under_construction_shows_its_progress() -> void:
	for def: DefBase in Registry.get_all_of(RoomDef):
		_simulation.state.room_defs[def.id] = def
	var room: RoomState = _simulation.state.base.add_room(&"room_research_lab", 1, Vector2i(4, 4))
	room.build_ticks_left = 120
	EventBus.room_build_started.emit(room.id)
	_view.get_plan().select(room.id)
	var lines: Array[String] = _view.get_room_panel().lines()
	assert_str(lines[1]).is_equal("Research Lab")
	assert_str(lines[3]).is_equal("Draw 5 MW")
	assert_str(lines[4]).is_equal("Upkeep $60k per 30 days")
	assert_str(lines[5]).is_equal("Under construction: 75%, 2 h left")
	var bar: SiteProgress = _view.get_plan().progress_of(room.id)
	assert_float(bar.fraction).is_equal_approx(0.75, 0.001)
	room.build_ticks_left = 0
	room.demolish_ticks_left = 60
	EventBus.room_demolished.emit(&"none")
	assert_str(_view.get_room_panel().lines()[5]).is_equal("Demolishing: 50%, 1 h left")
	assert_int(_view.get_plan().progress_of(room.id).kind).is_equal(SiteProgress.Kind.DEMOLISHING)


func test_switching_the_workshop_while_paused_updates_the_time_left() -> void:
	var state: GameState = _simulation.state
	for def: DefBase in Registry.get_all_of(RoomDef):
		state.room_defs[def.id] = def
	state.clock.is_paused = true
	state.clock.tick = 0
	EventBus.bind_simulation(_simulation)
	var workshop: RoomState = state.base.add_room(BuildSpeed.WORKSHOP_DEF, 1, Vector2i(26, 2))
	workshop.powered_on = false
	StaffFixture.engineers(state, workshop, [3, 3])
	var lab: RoomState = state.base.add_room(&"room_research_lab", 1, Vector2i(4, 4))
	lab.build_ticks_left = 480
	EventBus.room_build_started.emit(lab.id)
	_view.get_plan().select(lab.id)
	assert_int(_view.get_plan().progress_of(lab.id).ticks_left).is_equal(480)
	assert_str(_view.get_room_panel().lines()[5]).contains("8 h left")
	var result: CommandResult = _simulation.submit(SwitchRoomCommand.create(workshop.id, true))
	assert_bool(result.is_ok).override_failure_message(result.detail).is_true()
	assert_int(_view.get_plan().progress_of(lab.id).ticks_left).is_equal(384)
	assert_str(_view.get_room_panel().lines()[5]).contains("7 h left")


func test_progress_text_formats_time_left() -> void:
	assert_str(ProgressText.time_left(35)).is_equal("35 min")
	assert_str(ProgressText.time_left(180)).is_equal("3 h")
	assert_str(ProgressText.time_left(TimeMath.TICKS_PER_DAY + 239)).is_equal("1 d 4 h")
	assert_str(ProgressText.time_left(TimeMath.TICKS_PER_DAY * 2)).is_equal("2 d")
	var queued := SiteProgress.new()
	queued.kind = SiteProgress.Kind.QUEUED
	assert_str(ProgressText.caption(queued)).is_equal("Queued")


func test_a_dig_shows_on_its_level_tab() -> void:
	var level := LevelState.new()
	level.dig_ticks_left = 100
	var progress := SiteProgress.new()
	progress.fraction = 0.456
	assert_str(LevelTabs.label_for(level, 4, progress)).is_equal("L4 45%")
	level.dig_ticks_left = 0
	assert_str(LevelTabs.label_for(level, 4, progress)).is_equal("L4")


func test_bar_text_only_when_the_room_is_big_enough() -> void:
	var font: Font = _view.get_theme_default_font()
	var cell: float = BasePlanPainter.CELL
	assert_bool(SiteBar.fits(Rect2(0, 0, cell * 4, cell * 3), "1 d 4 h", font)).is_true()
	assert_bool(SiteBar.fits(Rect2(0, 0, cell, cell), "3 h", font)).is_false()
	var bar: Rect2 = SiteBar.bar_rect(Rect2(0, 0, cell * 4, cell * 3))
	assert_float(bar.end.y).is_equal_approx(cell * 3 - SiteBar.INSET, 0.01)


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


func test_signature_changes_only_with_what_is_shown() -> void:
	var base: BaseState = _simulation.state.base
	var before: int = BaseView.signature(base)
	assert_int(BaseView.signature(base)).is_equal(before)
	var room: RoomState = base.add_room(&"room_research_lab", 1, Vector2i(4, 4))
	room.build_ticks_left = TimeMath.TICKS_PER_DAY * 2
	var built: int = BaseView.signature(base)
	assert_int(built).is_not_equal(before)
	room.build_ticks_left -= 1
	assert_int(BaseView.signature(base)).is_equal(built)
	room.build_ticks_left = TimeMath.TICKS_PER_DAY
	assert_int(BaseView.signature(base)).is_not_equal(built)
	assert_int(BaseView.gate_level(base)).is_equal(1)
