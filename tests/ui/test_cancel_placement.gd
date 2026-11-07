## Tests for putting a room's ghost away (card M2.7-03): a right click (also with a corridor
## start set), Esc or (B), the selected palette entry again, the palette's Cancel button,
## switching tab, switching level; the prompt names the ways out in en and pt_BR.
## Bible: docs/content/m2-base.md section 6
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)
const LAB: StringName = &"room_research_lab"

var _root: Control = null
var _view: BaseView = null
var _simulation: Simulation = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var defs: GameDefs = GameDefs.from_registry(Registry)
	_simulation = GameSetup.build_new(GameState.new_game(1, defs.balance), defs).value
	_root = Control.new()
	_root.size = VIEW_SIZE
	_view = (load(VIEW_SCENE) as PackedScene).instantiate() as BaseView
	_root.add_child(_view)
	scene_runner(_root)
	_view.setup(_simulation)


func after_test() -> void:
	if is_instance_valid(_root):
		_root.free()
	TranslationServer.set_locale(_real_locale)


func _ghost() -> PlacementGhost:
	return _view.get_build().get_ghost()


func _right_click(cell: Vector2i) -> void:
	var plan: BasePlan = _view.get_plan()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_RIGHT
		event.pressed = pressed
		event.position = (
			plan.view.offset
			+ (Vector2(cell) + Vector2(0.5, 0.5)) * BasePlanPainter.CELL * plan.view.scale()
		)
		_ghost()._gui_input(event)
		BasePlanInput.handle(plan, event)


func _push(event: InputEventJoypadButton) -> void:
	event.pressed = true
	get_viewport().push_input(event)
	await get_tree().process_frame
	event.pressed = false
	get_viewport().push_input(event)
	await get_tree().process_frame


func test_a_right_click_with_a_corridor_start_set_puts_the_ghost_away() -> void:
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	_ghost().move_to(Vector2i(24, 11))
	_ghost().set_start()
	assert_bool(_ghost().has_start()).is_true()
	_right_click(Vector2i(24, 11))
	assert_bool(_ghost().is_placing()).is_false()
	assert_bool(_view.get_palette().get_cancel_button().visible).is_false()


func test_gamepad_b_puts_the_ghost_away() -> void:
	_view.get_build().start_placing(LAB)
	await get_tree().process_frame
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	await _push(b)
	assert_bool(_ghost().is_placing()).is_false()


func test_the_selected_palette_entry_again_puts_the_ghost_away() -> void:
	var entry: Button = _view.get_palette().get_room_button(LAB)
	entry.pressed.emit()
	assert_bool(_ghost().is_placing()).is_true()
	assert_bool(entry.button_pressed).is_true()
	entry.pressed.emit()
	assert_bool(_ghost().is_placing()).is_false()
	assert_bool(entry.button_pressed).is_false()


func test_another_palette_entry_switches_the_ghost() -> void:
	_view.get_palette().get_room_button(LAB).pressed.emit()
	_view.get_palette().get_room_button(StartingBase.CORRIDOR_DEF).pressed.emit()
	assert_str(String(_ghost().def_id)).is_equal(String(StartingBase.CORRIDOR_DEF))
	assert_bool(_view.get_palette().get_room_button(LAB).button_pressed).is_false()


func test_the_cancel_button_puts_the_ghost_away() -> void:
	var cancel: Button = _view.get_palette().get_cancel_button()
	assert_bool(cancel.visible).is_false()
	_view.get_build().start_placing(LAB)
	assert_bool(cancel.visible).is_true()
	assert_str(tr(cancel.text)).is_equal("Cancel")
	cancel.pressed.emit()
	assert_bool(_ghost().is_placing()).is_false()
	assert_bool(cancel.visible).is_false()
	assert_bool(_view.get_plan().has_focus()).is_true()


func test_esc_on_the_palette_puts_the_ghost_away() -> void:
	_view.get_build().start_placing(LAB)
	var entry: Button = _view.get_palette().get_room_button(LAB)
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	entry.gui_input.emit(esc)
	assert_bool(_ghost().is_placing()).is_false()


func test_switching_tab_puts_the_ghost_away() -> void:
	_view.get_build().start_placing(LAB)
	_view.visible = false
	assert_bool(_ghost().is_placing()).is_false()
	_view.visible = true
	assert_bool(_ghost().is_placing()).is_false()


func test_switching_level_puts_the_ghost_away() -> void:
	_simulation.state.base.levels.append(LevelState.new())
	_view.setup(_simulation)
	var plan: BasePlan = _view.get_plan()
	var from: int = plan.level
	_view.get_build().start_placing(LAB)
	await get_tree().process_frame
	var step := InputEventAction.new()
	step.action = &"base_level_down" if from == 1 else &"base_level_up"
	step.pressed = true
	get_viewport().push_input(step)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(plan.level).is_not_equal(from)
	assert_bool(_ghost().is_placing()).is_false()


func test_the_prompt_names_the_ways_out() -> void:
	_view.get_build().start_placing(LAB)
	_ghost().move_to(Vector2i(24, 11))
	assert_str(_view.get_palette().get_hint()).contains("right-click, Esc or (B) cancels")
	TranslationServer.set_locale("pt_BR")
	_ghost().recheck()
	assert_str(_view.get_palette().get_hint()).contains("botão direito, Esc ou (B) cancela")
