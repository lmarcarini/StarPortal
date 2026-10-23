## Tests for the dial console driven through input: mouse clicks, right-clicks and drags, the
## keyboard and the gamepad. Seal 8 and CAIRN's origin glyph are locked, the palette highlights
## exactly the placed glyphs, and the slots are view-local: the console never changes state.
## Bible: gate-and-address-spec.md#the-dial-console,
## game-design.md#difficulty-and-accessibility,
## technical-architecture.md#architecture-overview
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/console_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")

var _simulation: Simulation = null
var _console: DialConsole = null
var _runner: GdUnitSceneRunner = null
var _real_locale: String = ""
## Two glyphs that are not CAIRN's origin.
var _first: int = -1
var _second: int = -1


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = Fixture.build_simulation()
	_console = Fixture.instantiate()
	_runner = scene_runner(_console)
	_console.setup(_simulation)
	var free: Array[int] = _free_glyphs()
	_first = free[0]
	_second = free[1]
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_console):
		_console.free()
	TranslationServer.set_locale(_real_locale)


## Mouse: click a glyph to pick it, then click a seal slot to place it.
func test_click_to_pick_and_click_to_place() -> void:
	await UiInput.click(_palette().get_button(_first))
	assert_int(_console.get_picker().glyph).is_equal(_first)
	assert_bool(_palette().get_button(_first).button_pressed).is_true()
	await UiInput.click(_seals().get_slot(2))
	assert_int(_console.get_placed(2)).is_equal(_first)
	assert_int(_seals().get_slot(2).get_glyph()).is_equal(_first)
	assert_bool(_palette().get_button(_first).button_pressed).is_false()
	assert_bool(_console.get_picker().has_glyph()).is_false()


## Mouse: drag a glyph from the palette and drop it on a seal slot.
func test_drag_and_drop_places_a_glyph() -> void:
	await UiInput.drag(_palette().get_button(_second), _seals().get_slot(5))
	assert_int(_console.get_placed(5)).is_equal(_second)
	assert_int(_seals().get_slot(5).get_glyph()).is_equal(_second)


## Keyboard and gamepad: pick with Enter, place with the gamepad's accept button.
func test_keyboard_and_gamepad_place_a_glyph() -> void:
	await UiInput.key(_palette().get_button(_second), KEY_ENTER)
	await UiInput.pad(_seals().get_slot(3), JOY_BUTTON_A)
	assert_int(_console.get_placed(3)).is_equal(_second)


## Gamepad alone fills all seven slots: accept on a glyph, accept on a slot.
func test_gamepad_alone_fills_the_address() -> void:
	var target: GateAddress = Fixture.target_address(_simulation.state)
	for index: int in GateAddress.COORDINATE_COUNT:
		await UiInput.pad(_palette().get_button(target.coordinates[index]), JOY_BUTTON_A)
		await UiInput.pad(_seals().get_slot(index + 1), JOY_BUTTON_A)
	assert_bool(_console.get_address().equals(target)).is_true()


## A glyph placed again moves out of its old seal; another glyph overwrites a placed one.
func test_placing_moves_and_overwrites() -> void:
	await UiInput.drag(_palette().get_button(_first), _seals().get_slot(1))
	await UiInput.drag(_palette().get_button(_first), _seals().get_slot(4))
	assert_int(_console.get_placed(1)).is_equal(-1)
	assert_int(_console.get_placed(4)).is_equal(_first)
	await UiInput.drag(_palette().get_button(_second), _seals().get_slot(4))
	assert_int(_console.get_placed(4)).is_equal(_second)
	assert_int(_seals().get_slot(1).get_glyph()).is_equal(-1)
	assert_array(_palette().get_highlighted()).is_equal([_second])


## Right-click, Delete, Backspace and gamepad cancel each clear a filled slot.
func test_clearing_a_slot_by_mouse_keyboard_and_gamepad() -> void:
	for seal: int in [1, 2, 3, 4]:
		_console.place(seal, _free_glyphs()[seal])
	await UiInput.right_click(_seals().get_slot(1))
	await UiInput.key(_seals().get_slot(2), KEY_DELETE)
	await UiInput.key(_seals().get_slot(3), KEY_BACKSPACE)
	await UiInput.pad(_seals().get_slot(4), JOY_BUTTON_B)
	for seal: int in [1, 2, 3, 4]:
		assert_int(_console.get_placed(seal)).is_equal(-1)
	assert_array(_palette().get_highlighted()).is_empty()


## Cancel first drops a pick; only a second cancel clears the focused slot.
func test_cancel_drops_the_pick_before_clearing() -> void:
	_console.place(1, _first)
	await UiInput.key(_palette().get_button(_second), KEY_ENTER)
	await UiInput.key(_seals().get_slot(1), KEY_ESCAPE)
	assert_bool(_console.get_picker().has_glyph()).is_false()
	assert_int(_console.get_placed(1)).is_equal(_first)
	await UiInput.key(_seals().get_slot(1), KEY_ESCAPE)
	assert_int(_console.get_placed(1)).is_equal(-1)


## "Clear all" empties the seven slots and moves focus off the button it disables.
func test_clear_all_empties_every_slot() -> void:
	var clear: Button = _console.get_node("%ClearAllButton") as Button
	assert_bool(clear.disabled).is_true()
	_console.load_address(Fixture.target_address(_simulation.state))
	assert_bool(clear.disabled).is_false()
	await UiInput.pad(clear, JOY_BUTTON_A)
	for seal: int in range(1, GateAddress.COORDINATE_COUNT + 1):
		assert_int(_console.get_placed(seal)).is_equal(-1)
	assert_bool(clear.disabled).is_true()
	assert_bool(clear.has_focus()).is_false()


## Seal 8 always shows CAIRN's origin and takes no glyph, pick, drop or clear.
func test_the_origin_seal_is_fixed() -> void:
	var origin: int = _origin()
	var eighth: SealSlot = _seals().get_slot(8)
	assert_int(eighth.get_glyph()).is_equal(origin)
	assert_bool(eighth.is_locked()).is_true()
	await UiInput.click(_palette().get_button(_first))
	await UiInput.click(eighth)
	await UiInput.drag(_palette().get_button(_second), eighth)
	await UiInput.right_click(eighth)
	_console.place(8, _first)
	assert_int(eighth.get_glyph()).is_equal(origin)


## CAIRN's origin glyph is locked on the palette: greyed, with a reason, and never placed by
## click, drag or a loaded address.
func test_the_origin_glyph_cannot_be_placed() -> void:
	var button: PaletteGlyph = _palette().get_button(_origin())
	assert_bool(button.is_locked()).is_true()
	assert_bool(button.disabled).is_true()
	assert_float(button.modulate.a).is_less(1.0)
	assert_str(button.tooltip_text).contains("CAIRN's origin glyph")
	await UiInput.click(button)
	assert_bool(_console.get_picker().has_glyph()).is_false()
	await UiInput.drag(button, _seals().get_slot(1))
	_console.place(2, _origin())
	assert_int(_console.get_placed(1)).is_equal(-1)
	assert_int(_console.get_placed(2)).is_equal(-1)
	var coordinates: Array[int] = [_origin()]
	coordinates.append_array(_free_glyphs().slice(0, 6))
	_console.load_address(GateAddress.create(coordinates, _origin()))
	assert_int(_console.get_placed(1)).is_equal(-1)
	assert_int(_console.get_placed(2)).is_equal(coordinates[1])


## After a random sequence of placements, moves and clears, the highlighted glyphs are exactly
## the placed ones; nothing else on the palette changes.
func test_highlights_follow_the_slots_exactly() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	var free: Array[int] = _free_glyphs()
	for step: int in 200:
		var seal: int = rng.randi_range(1, GateAddress.COORDINATE_COUNT)
		match rng.randi_range(0, 4):
			0:
				_console.clear_seal(seal)
			1:
				_seals().clear_requested.emit(seal)
			2:
				_seals().glyph_dropped.emit(seal, free[rng.randi_range(0, free.size() - 1)])
			3:
				_palette().glyph_chosen.emit(free[rng.randi_range(0, free.size() - 1)])
				_seals().slot_chosen.emit(seal)
			_:
				_console.place(seal, free[rng.randi_range(0, free.size() - 1)])
		if step % 50 == 49:
			_console.clear_all()
		_assert_highlights_match()


## get_address() is null until all seven seals are filled, then the seven glyphs and CAIRN's
## origin; setup() empties the seals again.
func test_get_address_needs_all_seven_seals() -> void:
	var target: GateAddress = Fixture.target_address(_simulation.state)
	for index: int in GateAddress.COORDINATE_COUNT - 1:
		_seals().glyph_dropped.emit(index + 1, target.coordinates[index])
		assert_object(_console.get_address()).is_null()
	_seals().glyph_dropped.emit(GateAddress.COORDINATE_COUNT, target.coordinates[6])
	assert_bool(_console.get_address().equals(target)).is_true()
	_console.setup(_simulation)
	assert_object(_console.get_address()).is_null()
	assert_int(_seals().get_slot(1).get_glyph()).is_equal(-1)


## The console never changes the state or submits a command.
func test_console_never_touches_the_state() -> void:
	var before: Dictionary = _simulation.state.to_dict()
	await UiInput.click(_palette().get_button(_first))
	await UiInput.click(_seals().get_slot(1))
	await UiInput.drag(_palette().get_button(_second), _seals().get_slot(2))
	await UiInput.right_click(_seals().get_slot(2))
	assert_dict(_simulation.state.to_dict()).is_equal(before)
	assert_int(_simulation.commands.pending_count()).is_equal(0)


func _assert_highlights_match() -> void:
	var placed: Array[int] = []
	for seal: int in range(1, GateAddress.COORDINATE_COUNT + 1):
		if _console.get_placed(seal) >= 0:
			placed.append(_console.get_placed(seal))
		assert_int(_seals().get_slot(seal).get_glyph()).is_equal(_console.get_placed(seal))
	placed.sort()
	assert_array(_palette().get_highlighted()).is_equal(placed)


func _origin() -> int:
	return _simulation.state.galaxy.home().origin_glyph


func _free_glyphs() -> Array[int]:
	var free: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != _origin():
			free.append(glyph)
	return free


func _palette() -> GlyphPalette:
	return _console.get_node("%Palette") as GlyphPalette


func _seals() -> SealRow:
	return _console.get_node("%SealRow") as SealRow
