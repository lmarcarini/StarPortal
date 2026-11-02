## Tests for painting corridors on the Base plan with real input events: the ghost follows the
## hovered cell, a drag paints an L-shaped run anywhere (after a pan, at the edges), a click builds
## one cell, the keyboard sets a start and builds, and Esc or a right click puts the ghost away.
## Bible: docs/content/m2-base.md section 6
extends GdUnitTestSuite

const VIEW_SCENE: String = "res://src/ui/views/base/base_view.tscn"
const VIEW_SIZE: Vector2 = Vector2(1280, 640)

var _root: Control = null
var _view: BaseView = null
var _simulation: Simulation = null


func before_test() -> void:
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


func _ghost() -> PlacementGhost:
	return _view.get_build().get_ghost()


func _at(cell: Vector2i) -> Vector2:
	var plan: BasePlan = _view.get_plan()
	return (
		plan.view.offset
		+ (Vector2(cell) + Vector2(0.5, 0.5)) * BasePlanPainter.CELL * plan.view.scale()
	)


## A mouse motion to [param cell], given to the ghost's GUI entry (the one the viewport calls:
## headless Godot picks no control under the pointer), then to the plan when the ghost passes it.
func _move(cell: Vector2i, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _at(cell)
	event.button_mask = mask
	_ghost()._gui_input(event)
	if not _ghost().is_painting():
		BasePlanInput.handle(_view.get_plan(), event)


func _button(pressed: bool, cell: Vector2i, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = _at(cell)
	_ghost()._gui_input(event)
	if button != MOUSE_BUTTON_LEFT:
		BasePlanInput.handle(_view.get_plan(), event)


func _corridors() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for room: RoomState in _simulation.state.base.rooms:
		if room.def_id == StartingBase.CORRIDOR_DEF:
			cells.append(room.origin)
	return cells


## Enters the plan from the palette below: up the column from the bottom row to [param to].
func _hover_up_to(to: Vector2i) -> void:
	var bottom: int = _simulation.state.base.grid_size.y - 1
	for y: int in range(bottom, to.y - 1, -1):
		_move(Vector2i(to.x, y))
		await get_tree().process_frame


func test_ghost_follows_the_pointer_in_from_the_palette() -> void:
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	await get_tree().process_frame
	await _hover_up_to(Vector2i(24, 11))
	assert_that(_ghost().origin).is_equal(Vector2i(24, 11))
	assert_array(_ghost().run).is_equal([Vector2i(24, 11)])


func _drag_l(from: Vector2i, bend: Vector2i, to: Vector2i) -> void:
	_move(from)
	_button(true, from)
	await get_tree().process_frame
	for cell: Vector2i in _line(from, bend) + _line(bend, to):
		_move(cell, MOUSE_BUTTON_MASK_LEFT)
	await get_tree().process_frame
	_button(false, to)
	await get_tree().process_frame


func test_an_l_shaped_drag_builds_on_release_after_a_pan() -> void:
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	await get_tree().process_frame
	await _hover_up_to(Vector2i(24, 11))
	_view.get_plan().view.pan(Vector2(-150, -90))
	var before: int = _corridors().size()
	await _drag_l(Vector2i(24, 11), Vector2i(24, 13), Vector2i(26, 13))
	var built: Array[Vector2i] = _corridors()
	assert_int(built.size()).is_equal(before + 5)
	for cell: Vector2i in [Vector2i(24, 12), Vector2i(24, 13), Vector2i(26, 13)]:
		assert_bool(cell in built).is_true()
	assert_bool(_ghost().is_placing()).is_true()
	assert_bool(_ghost().has_start()).is_false()
	_move(Vector2i(10, 5))
	assert_array(_ghost().run).is_equal([Vector2i(10, 5)])


func test_the_ghost_reaches_the_plan_edges() -> void:
	var last: Vector2i = _simulation.state.base.grid_size - Vector2i.ONE
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	for cell: Vector2i in [Vector2i.ZERO, last, Vector2i(0, last.y), Vector2i(last.x, 0)]:
		_move(cell)
		assert_array(_ghost().run).is_equal([cell])


func test_a_click_builds_one_cell() -> void:
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	await _hover_up_to(Vector2i(24, 11))
	var before: int = _corridors().size()
	_button(true, Vector2i(24, 11))
	_button(false, Vector2i(24, 11))
	assert_int(_corridors().size()).is_equal(before + 1)
	assert_bool(Vector2i(24, 11) in _corridors()).is_true()


func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		get_viewport().push_input(event)
		await _frames()


## Waits two frames: the ghost follows the plan's cursor in its own process step.
func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func test_the_keyboard_sets_the_start_then_builds() -> void:
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	_view.get_plan().cursor = Vector2i(24, 11)
	await _frames()
	assert_str(_view.get_palette().get_hint()).contains("sets the start")
	await _key(KEY_ENTER)
	assert_bool(_ghost().has_start()).is_true()
	assert_str(_view.get_palette().get_hint()).contains("clears the start")
	for step: Key in [KEY_DOWN, KEY_DOWN, KEY_RIGHT]:
		await _key(step)
	assert_int(_ghost().run.size()).is_equal(4)
	var before: int = _corridors().size()
	await _key(KEY_ENTER)
	assert_int(_corridors().size()).is_equal(before + 4)
	assert_bool(_ghost().has_start()).is_false()


func test_esc_clears_the_start_then_puts_the_ghost_away() -> void:
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	_view.get_plan().cursor = Vector2i(24, 11)
	await _frames()
	await _key(KEY_ENTER)
	await _key(KEY_DOWN)
	await _key(KEY_ESCAPE)
	assert_bool(_ghost().has_start()).is_false()
	assert_int(_ghost().run.size()).is_equal(1)
	await _key(KEY_ESCAPE)
	assert_bool(_ghost().is_placing()).is_false()


func test_a_right_click_puts_the_ghost_away() -> void:
	_view.get_build().start_placing(StartingBase.CORRIDOR_DEF)
	await _hover_up_to(Vector2i(24, 11))
	_button(true, Vector2i(24, 11), MOUSE_BUTTON_RIGHT)
	_button(false, Vector2i(24, 11), MOUSE_BUTTON_RIGHT)
	assert_bool(_ghost().is_placing()).is_false()


## The cells from [param from] to [param to] along one row or column, both ends included.
static func _line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [from]
	var step: Vector2i = (to - from).sign()
	while cells[-1] != to:
		cells.append(cells[-1] + step)
	return cells
