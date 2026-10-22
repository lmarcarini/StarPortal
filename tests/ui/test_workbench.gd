## Tests for the Address Workbench driven through input: mouse clicks and drags, the keyboard
## and gamepad focus. Every action must reach the state as one SetWorkbenchCommand.
## Bible: gate-and-address-spec.md#player-tools,
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
	EventBus.bind_simulation(_simulation)
	_workbench = Fixture.instantiate()
	_runner = scene_runner(_workbench)
	_workbench.setup(_simulation)
	await _runner.await_input_processed()


func after_test() -> void:
	if is_instance_valid(_workbench):
		_workbench.free()
	EventBus.bind_simulation(SimClock.simulation)
	TranslationServer.set_locale(_real_locale)


## Mouse: click a glyph to pick it, then click a seal slot to place it.
func test_click_to_pick_and_click_to_place() -> void:
	await _click(_palette().get_button(HERON))
	assert_int(_workbench.get_picker().glyph).is_equal(HERON)
	assert_bool(_palette().get_button(HERON).button_pressed).is_true()
	await _click(_seals().get_slot(2))
	_assert_constraints([AddressConstraint.glyph_at(2, HERON)])
	assert_int(_seals().get_slot(2).get_glyph()).is_equal(HERON)
	assert_int(_palette().get_button(HERON).get_status()).is_equal(
		WorkbenchEdits.GlyphStatus.IN_ADDRESS
	)
	assert_bool(_palette().get_button(HERON).button_pressed).is_false()


## Mouse: drag a glyph from the palette and drop it on a seal slot.
func test_drag_and_drop_places_a_glyph() -> void:
	await UiInput.drag(_palette().get_button(ANVIL), _seals().get_slot(5))
	_assert_constraints([AddressConstraint.glyph_at(5, ANVIL)])


## Keyboard: pick with Enter, rule out, and rule out again to take it back.
func test_keyboard_rules_a_glyph_out_and_back() -> void:
	await _key_accept(_palette().get_button(ANVIL))
	await _key_accept(_actions().get_button(ActionBar.Action.RULE_OUT))
	_assert_constraints([AddressConstraint.excluded(ANVIL)])
	assert_int(_palette().get_button(ANVIL).get_status()).is_equal(
		WorkbenchEdits.GlyphStatus.RULED_OUT
	)
	await _key_accept(_palette().get_button(ANVIL))
	await _key_accept(_actions().get_button(ActionBar.Action.RULE_OUT))
	_assert_constraints([])


## Gamepad: rule a glyph out at one seal.
func test_gamepad_rules_a_glyph_out_at_one_seal() -> void:
	await _pad_accept(_palette().get_button(HERON))
	await _pad_accept(_actions().get_button(ActionBar.Action.NOT_AT))
	assert_int(_workbench.get_picker().mode).is_equal(WorkbenchPicker.Mode.AWAIT_NOT_AT)
	await _pad_accept(_seals().get_slot(4))
	_assert_constraints([AddressConstraint.glyph_not_at(4, HERON)])
	assert_str(_constraints().get_rows()[0].get_text()).is_equal("Heron is not at seal 4")


## Gamepad: an order relation is pick A, "nearer than", pick B.
func test_gamepad_adds_an_order_relation() -> void:
	await _pad_accept(_palette().get_button(ANVIL))
	await _pad_accept(_actions().get_button(ActionBar.Action.NEARER))
	assert_int(_workbench.get_picker().mode).is_equal(WorkbenchPicker.Mode.AWAIT_FARTHER)
	await _pad_accept(_palette().get_button(HERON))
	_assert_constraints([AddressConstraint.nearer_than(ANVIL, HERON)])
	var anvil: String = tr(WorkbenchText.glyph_name_key(ANVIL))
	assert_str(_constraints().get_rows()[0].get_text()).is_equal("%s is nearer than Heron" % anvil)


## Keyboard: mark seven glyphs as in the address, then group them as the exact set.
func test_include_seven_then_group_as_set() -> void:
	var group: Button = _actions().get_button(ActionBar.Action.GROUP)
	var home: int = _simulation.state.galaxy.home().origin_glyph
	var glyphs: Array[int] = []
	for glyph: int in GateAddress.GLYPH_COUNT:
		if glyph != home and glyphs.size() < GateAddress.COORDINATE_COUNT:
			glyphs.append(glyph)
	for glyph: int in glyphs:
		assert_bool(group.disabled).is_true()
		await _key_accept(_palette().get_button(glyph))
		await _key_accept(_actions().get_button(ActionBar.Action.INCLUDE))
	assert_int(_draft().constraints.size()).is_equal(7)
	assert_bool(group.disabled).is_false()
	await _key_accept(group)
	_assert_constraints([AddressConstraint.exact_set(glyphs)])
	assert_int(_workbench.get_summary().count).is_equal(5040)


## The origin slot shows CAIRN's origin at -1; the player may change it and change it back.
func test_origin_slot_changes_and_resets() -> void:
	var home: int = _simulation.state.galaxy.home().origin_glyph
	var other: int = (home + 1) % GateAddress.GLYPH_COUNT
	var origin_slot: SealSlot = _seals().get_slot(GateAddress.SEAL_COUNT)
	assert_int(origin_slot.get_glyph()).is_equal(home)
	assert_bool(_seals().get_reset_button().disabled).is_true()
	await _click(_palette().get_button(other))
	await _click(origin_slot)
	assert_int(_draft().origin_glyph).is_equal(other)
	assert_int(origin_slot.get_glyph()).is_equal(other)
	await _key_accept(_seals().get_reset_button())
	assert_int(_draft().origin_glyph).is_equal(WorkbenchState.HOME_ORIGIN)
	assert_int(origin_slot.get_glyph()).is_equal(home)


## Each row's remove button removes that constraint only.
func test_remove_button_removes_its_row() -> void:
	_set_draft([AddressConstraint.excluded(HERON), AddressConstraint.excluded(ANVIL)])
	assert_int(_constraints().get_rows().size()).is_equal(2)
	await _pad_accept(_constraints().get_rows()[0].get_remove_button())
	_assert_constraints([AddressConstraint.excluded(ANVIL)])
	var focused: Control = _workbench.get_viewport().gui_get_focus_owner()
	assert_object(focused).is_same(_constraints().get_rows()[0].get_remove_button())
	await _pad_accept(focused)
	_assert_constraints([])
	assert_object(_workbench.get_viewport().gui_get_focus_owner()).is_same(
		_constraints().get_clear_button()
	)


## "Clear all" asks first: cancelling keeps everything, confirming clears it.
func test_clear_all_asks_for_confirmation() -> void:
	_set_draft([AddressConstraint.excluded(HERON), AddressConstraint.included(ANVIL)])
	var dialog: ConfirmationDialog = _constraints().get_clear_dialog()
	await _key_accept(_constraints().get_clear_button())
	assert_bool(dialog.visible).is_true()
	assert_int(_draft().constraints.size()).is_equal(2)
	dialog.get_cancel_button().pressed.emit()
	await _runner.await_input_processed()
	assert_int(_draft().constraints.size()).is_equal(2)
	await _key_accept(_constraints().get_clear_button())
	dialog.get_ok_button().pressed.emit()
	await _runner.await_input_processed()
	_assert_constraints([])
	assert_bool(_constraints().get_clear_button().disabled).is_true()


## Escape (ui_cancel) drops the pick without touching the draft.
func test_cancel_drops_the_pick() -> void:
	await _key_accept(_palette().get_button(HERON))
	await _key(_palette().get_button(HERON), KEY_ESCAPE)
	assert_bool(_workbench.get_picker().has_glyph()).is_false()
	_assert_constraints([])


## The root is one focus stop in the Analysis view; gamepad accept enters it.
func test_gamepad_accept_on_the_root_enters_the_workbench() -> void:
	await _pad_accept(_workbench)
	assert_object(_workbench.get_viewport().gui_get_focus_owner()).is_same(_seals().get_slot(1))


## While the clock runs, actions only queue commands: the view writes nothing to the state,
## and quick edits build on each other before the tick applies them.
func test_view_only_submits_commands() -> void:
	_simulation.state.clock.mode = ClockState.Mode.RUNNING
	var before: Dictionary = _simulation.state.to_dict()
	await _click(_palette().get_button(HERON))
	await _click(_seals().get_slot(1))
	await _key_accept(_palette().get_button(ANVIL))
	await _key_accept(_actions().get_button(ActionBar.Action.RULE_OUT))
	assert_dict(_simulation.state.to_dict()).is_equal(before)
	assert_int(_simulation.commands.pending_count()).is_equal(2)
	_simulation.advance_tick()
	await _runner.await_input_processed()
	_assert_constraints([AddressConstraint.glyph_at(1, HERON), AddressConstraint.excluded(ANVIL)])
	assert_int(_seals().get_slot(1).get_glyph()).is_equal(HERON)


func _draft() -> WorkbenchState:
	return _simulation.state.workbench


func _set_draft(constraints: Array[AddressConstraint]) -> void:
	var result: CommandResult = _simulation.submit(
		SetWorkbenchCommand.create(WorkbenchState.HOME_ORIGIN, constraints)
	)
	assert_bool(result.is_ok).is_true()


func _assert_constraints(expected: Array[AddressConstraint]) -> void:
	var actual: Array = _draft().constraints.map(
		func(c: AddressConstraint) -> Dictionary: return c.to_dict()
	)
	var wanted: Array = expected.map(func(c: AddressConstraint) -> Dictionary: return c.to_dict())
	assert_array(actual).is_equal(wanted)


func _palette() -> GlyphPalette:
	return _workbench.get_node("%Palette") as GlyphPalette


func _seals() -> SealRow:
	return _workbench.get_node("%SealRow") as SealRow


func _actions() -> ActionBar:
	return _workbench.get_node("%ActionBar") as ActionBar


func _constraints() -> ConstraintList:
	return _workbench.get_node("%Constraints") as ConstraintList


func _click(control: Control) -> void:
	await UiInput.click(control)


func _key_accept(control: Control) -> void:
	await UiInput.key(control, KEY_ENTER)


func _key(control: Control, keycode: Key) -> void:
	await UiInput.key(control, keycode)


func _pad_accept(control: Control) -> void:
	await UiInput.pad(control, JOY_BUTTON_A)
