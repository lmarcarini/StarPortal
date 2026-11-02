## Tests for one-click building on the Base tab: a click, Enter or (A) builds at once, the ghost
## stays out for another, a right click or Esc puts it away while a right drag only pans, a
## corridor drag builds on release, the palette's Build button is one click, and Cancel keeps
## its hold.
## Bible: docs/content/m2-base.md section 6
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)

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


func _count(def_id: StringName) -> int:
	var found: int = 0
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == def_id:
			found += 1
	return found


func _mouse(
	button: MouseButton, pressed: bool, cell: Vector2i, nudge: Vector2 = Vector2.ZERO
) -> void:
	var plan: BasePlan = _view.get_plan()
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = (
		plan.view.offset
		+ (Vector2(cell) + Vector2(0.5, 0.5)) * BasePlanPainter.CELL * plan.view.scale()
		+ nudge
	)
	# Headless Godot picks no control under the pointer, so the event goes to the ghost's own
	# GUI entry (the one the viewport calls), then to the plan when the ghost leaves it.
	_ghost()._gui_input(event)
	if button != MOUSE_BUTTON_LEFT:
		BasePlanInput.handle(plan, event)


func _drag(cell: Vector2i) -> void:
	var plan: BasePlan = _view.get_plan()
	var event := InputEventMouseMotion.new()
	event.position = (
		plan.view.offset
		+ (Vector2(cell) + Vector2(0.5, 0.5)) * BasePlanPainter.CELL * plan.view.scale()
	)
	_ghost()._gui_input(event)


func test_one_enter_builds_and_the_ghost_stays_for_another() -> void:
	_view.get_build().start_placing(&"room_quarters")
	_ghost().move_to(Vector2i(4, 16))
	assert_str(_ghost().reason()).is_empty()
	var before: int = _count(&"room_quarters")
	await get_tree().process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	get_viewport().push_input(key)
	await get_tree().process_frame
	assert_int(_count(&"room_quarters")).is_equal(before + 1)
	assert_bool(_ghost().is_placing()).is_true()
	assert_str(String(_ghost().def_id)).is_equal("room_quarters")
	key.pressed = false
	get_viewport().push_input(key)
	_ghost().move_to(Vector2i(4, 18))
	if _ghost().reason().is_empty():
		_ghost().confirm()
		assert_int(_count(&"room_quarters")).is_equal(before + 2)


func test_invalid_click_shows_the_reason_and_builds_nothing() -> void:
	_view.get_build().start_placing(&"room_physics_lab")
	await get_tree().process_frame
	var before: int = _simulation.state.base.rooms.size()
	_mouse(MOUSE_BUTTON_LEFT, true, Vector2i(0, 0))
	assert_str(_ghost().reason()).is_equal("Must touch a corridor.")
	assert_str(_view.get_palette().get_hint()).is_equal("Must touch a corridor.")
	assert_int(_simulation.state.base.rooms.size()).is_equal(before)
	_mouse(MOUSE_BUTTON_LEFT, false, Vector2i(0, 0))


func test_right_click_puts_the_ghost_away_but_a_right_drag_pans() -> void:
	_view.get_build().start_placing(&"room_quarters")
	await get_tree().process_frame
	_mouse(MOUSE_BUTTON_RIGHT, true, Vector2i(4, 16))
	_mouse(MOUSE_BUTTON_RIGHT, false, Vector2i(4, 16), Vector2(40, 0))
	assert_bool(_ghost().is_placing()).is_true()
	_mouse(MOUSE_BUTTON_RIGHT, true, Vector2i(4, 16))
	_mouse(MOUSE_BUTTON_RIGHT, false, Vector2i(4, 16), Vector2(2, 1))
	assert_bool(_ghost().is_placing()).is_false()
	assert_bool(_view.get_plan().is_dragging()).is_false()


func test_esc_puts_the_ghost_away() -> void:
	_view.get_build().start_placing(&"room_quarters")
	await get_tree().process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	get_viewport().push_input(key)
	await get_tree().process_frame
	assert_bool(_ghost().is_placing()).is_false()


func test_corridor_drag_builds_on_release() -> void:
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	await get_tree().process_frame
	var before: int = _count(StartingBase.CORRIDOR_DEF)
	_mouse(MOUSE_BUTTON_LEFT, true, Vector2i(10, 16))
	_drag(Vector2i(10, 17))
	_drag(Vector2i(11, 17))
	assert_int(_count(StartingBase.CORRIDOR_DEF)).is_equal(before)
	assert_int(_ghost().run.size()).is_equal(3)
	_mouse(MOUSE_BUTTON_LEFT, false, Vector2i(11, 17))
	assert_int(_count(StartingBase.CORRIDOR_DEF)).is_equal(before + 3)
	assert_bool(_ghost().is_placing()).is_true()
	assert_int(_ghost().run.size()).is_equal(1)


func test_palette_build_button_is_one_click() -> void:
	_view.place_capacitor_bank()
	var build: Button = _view.get_palette().get_build_button()
	assert_bool(build is HoldButton).is_false()
	assert_str(tr(build.text)).is_equal("Build")
	build.pressed.emit()
	assert_int(_count(StartingBase.CAPACITOR_BANK_DEF)).is_equal(1)


func test_cancel_keeps_its_hold() -> void:
	_view.place_capacitor_bank()
	_ghost().confirm()
	_ghost().stop(true)
	var site: RoomState = _simulation.state.base.rooms[-1]
	_view.get_plan().select(site.id)
	var action: HoldButton = _view.get_room_panel().get_action_button()
	action.begin_hold()
	action.advance(HoldButton.HOLD_SECONDS * 0.5)
	action.cancel_hold()
	assert_int(_count(StartingBase.CAPACITOR_BANK_DEF)).is_equal(1)
