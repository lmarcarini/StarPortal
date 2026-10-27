## Tests for the Gate Room's secrecy and accessibility rules: no view reveals the world behind
## No gate, Blocked or Origin rejected, and every control is reachable by gamepad focus alone.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## game-design.md#difficulty-and-accessibility
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateRoomView = null
var _real_locale: String = ""


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	_holder = Fixture.mount_view()
	add_child(_holder)
	_view = Fixture.view_of(_holder)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	if is_instance_valid(_holder):
		_holder.free()
	TranslationServer.set_locale(_real_locale)


func _enter(address: GateAddress) -> void:
	Fixture.select(_view, address)


func _dial(address: GateAddress) -> void:
	_enter(address)
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)
	SimClock.step_ticks(2)


## Names of the worlds in every visible text under the view.
func _leaks() -> Array[String]:
	var found: Array[String] = []
	for text: String in Fixture.visible_texts(_view):
		for designation: String in Fixture.DESIGNATIONS.values():
			if text.contains(designation):
				found.append(text)
		if text.contains("world_"):
			found.append(text)
	return found


@warning_ignore("unused_parameter")
func test_no_view_reveals_the_world_behind_a_failed_dial(
	kind: int,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		[DialOutcome.Kind.NO_GATE],
		[DialOutcome.Kind.BLOCKED],
		[DialOutcome.Kind.ORIGIN_REJECTED],
	]
) -> void:
	_dial(Fixture.address_for(_simulation.state, kind))
	assert_int(_simulation.state.gate.dial_log[0].outcome).is_equal(kind)
	assert_array(Fixture.visible_texts(_view)).contains([GateRoomFormat.outcome_name(kind)])
	assert_array(_leaks()).is_empty()


func test_a_shielded_world_is_not_revealed_either() -> void:
	var address: GateAddress = DialFixture.address_of(
		_simulation.state.galaxy, DialFixture.SHIELDED_ID
	)
	_dial(address)
	assert_int(_simulation.state.gate.dial_log[0].outcome).is_equal(DialOutcome.Kind.BLOCKED)
	assert_array(_leaks()).is_empty()


@warning_ignore("unused_parameter")
func test_a_lock_names_the_world_in_the_wormhole_screen_and_the_address_book(
	kind: int,
	designation: String,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		[DialOutcome.Kind.LOCK, "P3X-111"],
		[DialOutcome.Kind.HOSTILE_LOCK, "P3X-444"],
	]
) -> void:
	_dial(Fixture.address_for(_simulation.state, kind))
	var found: int = 0
	for text: String in Fixture.visible_texts(_view):
		if text.contains(designation):
			found += 1
	assert_int(found).is_equal(2)


func test_the_default_focus_is_the_dial_button_or_the_first_free_glyph() -> void:
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	var palette: GlyphPalette = _view.find_child("Palette", true, false) as GlyphPalette
	var first: Control = _view.get_default_focus()
	assert_object(first).is_same(palette.get_first_focus())
	assert_int(first.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_bool((first as PaletteGlyph).is_locked()).is_false()
	_dial(Fixture.address_for(_simulation.state, DialOutcome.Kind.NO_GATE))
	var card: ResultCard = _view.get_overlays().get_result_card()
	assert_object(_view.get_default_focus()).is_same(card.get_ok_button())
	card.get_ok_button().pressed.emit()
	assert_bool(button.disabled).is_false()
	assert_object(_view.get_default_focus()).is_same(button)
	_view.get_console().clear_all()
	assert_object(_view.get_default_focus()).is_same(palette.get_first_focus())


func test_every_control_is_reachable_by_focus_alone() -> void:
	var overlays: GateOverlays = _view.get_overlays()
	_dial(Fixture.address_for(_simulation.state, DialOutcome.Kind.NO_GATE))
	overlays.get_result_card().get_ok_button().pressed.emit()
	_dial(Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	Fixture.close_wormhole(_view)
	overlays.get_wormhole_screen().get_back_button().pressed.emit()
	_enter(Fixture.address_for(_simulation.state, DialOutcome.Kind.BLOCKED))
	assert_bool(overlays.is_open()).is_false()
	await get_tree().process_frame
	await get_tree().process_frame
	var expected: Array[Control] = []
	for control: Control in Fixture.focusable(_view):
		if not (control is BaseButton and (control as BaseButton).disabled):
			expected.append(control)
	assert_int(expected.size()).is_greater_equal(3)
	var reached: Array[Control] = _reach_by_directions(_view.get_default_focus())
	for control: Control in expected:
		(
			assert_bool(reached.has(control))
			. override_failure_message("not reachable by direction: %s" % control.get_path())
			. is_true()
		)
	var cycled: Array[Control] = _reach_by_tab(_view.get_default_focus())
	for control: Control in expected:
		(
			assert_bool(cycled.has(control))
			. override_failure_message("not reachable by tab order: %s" % control.get_path())
			. is_true()
		)


func test_the_dial_button_is_a_focusable_hold_button_with_a_reason_when_disabled() -> void:
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	assert_int(button.focus_mode).is_equal(Control.FOCUS_ALL)
	assert_bool(button.disabled).is_true()
	assert_str(button.tooltip_text).is_equal("Place a glyph in each of the seven seals first.")


func test_focus_moves_to_the_view_when_the_focused_button_goes_away() -> void:
	_dial(Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	var screen: WormholeScreen = _view.get_overlays().get_wormhole_screen()
	Fixture.open_actions(_view)
	var close: Button = screen.get_actions().get_close_button()
	close.grab_focus()
	await get_tree().process_frame
	assert_object(_holder.get_viewport().gui_get_focus_owner()).is_same(close)
	Fixture.close_wormhole(_view)
	await get_tree().process_frame
	assert_object(_holder.get_viewport().gui_get_focus_owner()).is_same(_view.get_default_focus())
	assert_bool(_view.get_console().is_ancestor_of(_view.get_default_focus())).is_true()


## While an overlay is open, focus cannot leave it by direction or tab: the console behind
## stays out of reach until it closes.
func test_an_open_overlay_keeps_focus_inside_it() -> void:
	var overlays: GateOverlays = _view.get_overlays()
	_dial(Fixture.address_for(_simulation.state, DialOutcome.Kind.NO_GATE))
	_assert_trapped(overlays.get_default_focus(), overlays)
	overlays.get_result_card().get_ok_button().pressed.emit()
	_dial(Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	Fixture.open_actions(_view)
	_assert_trapped(overlays.get_default_focus(), overlays)
	var palette_glyph: Control = (
		(_view.find_child("Palette", true, false) as GlyphPalette).get_first_focus()
	)
	palette_glyph.grab_focus()
	_view._ensure_focus()
	assert_object(_holder.get_viewport().gui_get_focus_owner()).is_same(
		overlays.get_default_focus()
	)


func _assert_trapped(start: Control, overlays: GateOverlays) -> void:
	assert_object(start).is_not_null()
	for control: Control in _reach_by_directions(start) + _reach_by_tab(start):
		assert_bool(overlays.is_ancestor_of(control)).is_true()


## Controls reached from [param start] by repeatedly moving focus up, down, left and right.
func _reach_by_directions(start: Control) -> Array[Control]:
	var seen: Array[Control] = [start]
	var pending: Array[Control] = [start]
	var sides: Array[Side] = [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]
	while not pending.is_empty():
		var current: Control = pending.pop_back()
		for side: Side in sides:
			var next: Control = current.find_valid_focus_neighbor(side)
			if next != null and _view.is_ancestor_of(next) and not seen.has(next):
				seen.append(next)
				pending.append(next)
	return seen


## Controls reached from [param start] by repeatedly tabbing forward, until it wraps.
func _reach_by_tab(start: Control) -> Array[Control]:
	var seen: Array[Control] = [start]
	var current: Control = start.find_next_valid_focus()
	while current != null and not seen.has(current) and _view.is_ancestor_of(current):
		seen.append(current)
		current = current.find_next_valid_focus()
	return seen
