## Tests for the Address Workbench placeholder driven through input: mouse clicks and drags,
## the keyboard and gamepad focus. The placed glyphs are view-local: the view never submits a
## command, and get_address() returns the seven placed glyphs with CAIRN's origin.
## Bible: gate-and-address-spec.md#glyphs-and-the-hidden-address-math,
## game-design.md#difficulty-and-accessibility,
## technical-architecture.md#architecture-overview
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/workbench_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
const HERON: int = 0
const ANVIL: int = 1

var _simulation: Simulation = null
var _workbench: Workbench = null
var _runner: GdUnitSceneRunner = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = Fixture.build_simulation()
	_workbench = Fixture.instantiate()
	_runner = scene_runner(_workbench)
	_workbench.setup(_simulation)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_workbench):
		_workbench.free()
	TranslationServer.set_locale(_real_locale)


## Mouse: click a glyph to pick it, then click a seal slot to place it.
func test_click_to_pick_and_click_to_place() -> void:
	await _click(_palette().get_button(HERON))
	assert_int(_workbench.get_picker().glyph).is_equal(HERON)
	assert_bool(_palette().get_button(HERON).button_pressed).is_true()
	await _click(_seals().get_slot(2))
	assert_int(_workbench.get_placed(2)).is_equal(HERON)
	assert_int(_seals().get_slot(2).get_glyph()).is_equal(HERON)
	assert_bool(_palette().get_button(HERON).button_pressed).is_false()
	assert_bool(_workbench.get_picker().has_glyph()).is_false()


## Mouse: drag a glyph from the palette and drop it on a seal slot.
func test_drag_and_drop_places_a_glyph() -> void:
	await UiInput.drag(_palette().get_button(ANVIL), _seals().get_slot(5))
	assert_int(_workbench.get_placed(5)).is_equal(ANVIL)
	assert_int(_seals().get_slot(5).get_glyph()).is_equal(ANVIL)


## Keyboard and gamepad: pick with Enter, place with the gamepad's accept button.
func test_keyboard_and_gamepad_place_a_glyph() -> void:
	await _key_accept(_palette().get_button(ANVIL))
	await _pad_accept(_seals().get_slot(3))
	assert_int(_workbench.get_placed(3)).is_equal(ANVIL)


## A glyph placed again moves out of its old seal; another glyph replaces a placed one.
func test_placing_moves_and_replaces() -> void:
	await UiInput.drag(_palette().get_button(HERON), _seals().get_slot(1))
	await UiInput.drag(_palette().get_button(HERON), _seals().get_slot(4))
	assert_int(_workbench.get_placed(1)).is_equal(-1)
	assert_int(_workbench.get_placed(4)).is_equal(HERON)
	await UiInput.drag(_palette().get_button(ANVIL), _seals().get_slot(4))
	assert_int(_workbench.get_placed(4)).is_equal(ANVIL)
	assert_int(_seals().get_slot(1).get_glyph()).is_equal(-1)


## Seal 8 always shows CAIRN's origin and takes no glyph.
func test_the_origin_seal_is_fixed() -> void:
	var origin: int = _simulation.state.galaxy.home().origin_glyph
	var other: int = (origin + 1) % GateAddress.GLYPH_COUNT
	assert_int(_seals().get_slot(8).get_glyph()).is_equal(origin)
	await _click(_palette().get_button(other))
	await _click(_seals().get_slot(8))
	await UiInput.drag(_palette().get_button(other), _seals().get_slot(8))
	assert_int(_seals().get_slot(8).get_glyph()).is_equal(origin)


## get_address() is null until all seven seals are filled, then the seven glyphs and CAIRN's
## origin; setup() empties the seals again.
func test_get_address_needs_all_seven_seals() -> void:
	var target: GateAddress = Fixture.target_address(_simulation.state)
	for index: int in GateAddress.COORDINATE_COUNT - 1:
		_seals().glyph_dropped.emit(index + 1, target.coordinates[index])
		assert_object(_workbench.get_address()).is_null()
	_seals().glyph_dropped.emit(GateAddress.COORDINATE_COUNT, target.coordinates[6])
	assert_bool(_workbench.get_address().equals(target)).is_true()
	_workbench.setup(_simulation)
	assert_object(_workbench.get_address()).is_null()
	assert_int(_seals().get_slot(1).get_glyph()).is_equal(-1)


## Escape (ui_cancel) drops the pick.
func test_cancel_drops_the_pick() -> void:
	await _key_accept(_palette().get_button(HERON))
	await _key(_palette().get_button(HERON), KEY_ESCAPE)
	assert_bool(_workbench.get_picker().has_glyph()).is_false()


## The root is one focus stop in the Analysis view; gamepad accept enters it.
func test_gamepad_accept_on_the_root_enters_the_workbench() -> void:
	await _pad_accept(_workbench)
	assert_object(_workbench.get_viewport().gui_get_focus_owner()).is_same(_seals().get_slot(1))


## The view never changes the state or submits a command.
func test_view_never_touches_the_state() -> void:
	var before: Dictionary = _simulation.state.to_dict()
	await _click(_palette().get_button(HERON))
	await _click(_seals().get_slot(1))
	await UiInput.drag(_palette().get_button(ANVIL), _seals().get_slot(2))
	assert_dict(_simulation.state.to_dict()).is_equal(before)
	assert_int(_simulation.commands.pending_count()).is_equal(0)


func _palette() -> GlyphPalette:
	return _workbench.get_node("%Palette") as GlyphPalette


func _seals() -> SealRow:
	return _workbench.get_node("%SealRow") as SealRow


func _click(control: Control) -> void:
	await UiInput.click(control)


func _key_accept(control: Control) -> void:
	await UiInput.key(control, KEY_ENTER)


func _key(control: Control, keycode: Key) -> void:
	await UiInput.key(control, keycode)


func _pad_accept(control: Control) -> void:
	await UiInput.pad(control, JOY_BUTTON_A)
