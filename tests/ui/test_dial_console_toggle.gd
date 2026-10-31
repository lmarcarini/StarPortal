## Tests for toggling a placed glyph from the palette: a click or gamepad A takes it out of
## its seal, while a drag dropped back on its own palette button never counts as a click.
## Bible: gate-and-address-spec.md#the-dial-console
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/console_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")

var _console: DialConsole = null
var _runner: GdUnitSceneRunner = null
var _glyph: int = -1


func before_test() -> void:
	var simulation: Simulation = Fixture.build_simulation()
	_console = Fixture.instantiate()
	_runner = scene_runner(_console)
	_console.setup(simulation)
	_glyph = 1 if _console.get_address_origin() == 0 else 0
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_console):
		_console.free()


## A placed glyph dragged out over a seal and dropped back on its own palette button stays in
## its seal; a later plain click still takes it out.
func test_a_drag_back_onto_the_palette_is_not_a_click() -> void:
	var button: PaletteGlyph = _palette().get_button(_glyph)
	await UiInput.click(button)
	assert_int(_console.get_placed(1)).is_equal(_glyph)
	var clicks: Array[int] = []
	_palette().glyph_chosen.connect(func(glyph: int) -> void: clicks.append(glyph))
	await _drag_out_and_back(button, _seals().get_slot(4))
	assert_bool(button.get_viewport().gui_is_drag_successful()).is_false()
	assert_array(clicks).is_empty()
	assert_int(_console.get_placed(1)).is_equal(_glyph)
	assert_bool(button.is_placed()).is_true()
	await UiInput.click(button)
	assert_int(_console.get_placed(1)).is_equal(-1)
	assert_bool(button.is_placed()).is_false()


## A glyph dragged onto a seal is toggled off by gamepad A on its palette button.
func test_gamepad_toggles_a_dragged_glyph_off() -> void:
	var button: PaletteGlyph = _palette().get_button(_glyph)
	await UiInput.drag(button, _seals().get_slot(3))
	assert_int(_console.get_placed(3)).is_equal(_glyph)
	await UiInput.pad(button, JOY_BUTTON_A)
	assert_int(_console.get_placed(3)).is_equal(-1)
	assert_bool(button.is_placed()).is_false()


# Presses on [param from], moves over [param via] with the left button held and back, and
# releases on [param from].
func _drag_out_and_back(from: Control, via: Control) -> void:
	var start: Vector2 = from.get_global_rect().get_center()
	var far: Vector2 = via.get_global_rect().get_center()
	_push_button(from, start, true)
	await UiInput.settle(from)
	var previous: Vector2 = start
	for at: Vector2 in [start.lerp(far, 0.5), far, start.lerp(far, 0.5), start]:
		_push_motion(from, at, at - previous)
		previous = at
		await UiInput.settle(from)
	_push_button(from, start, false)
	await UiInput.settle(from)


func _push_button(control: Control, at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.global_position = at
	control.get_viewport().push_input(event, true)


func _palette() -> GlyphPalette:
	return _console.get_node("%Palette") as GlyphPalette


func _seals() -> SealRow:
	return _console.get_node("%SealRow") as SealRow


func _push_motion(control: Control, at: Vector2, relative: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.relative = relative
	motion.position = at
	motion.global_position = at
	control.get_viewport().push_input(motion, true)
