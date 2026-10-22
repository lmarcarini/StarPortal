## Layout checks for the Address Workbench at its share of a 1280 x 720 screen (two fifths of
## the width, beside the Analysis Board): nothing is wider than the column in English,
## Brazilian Portuguese or the expanded pseudo-locale, so no text is clipped sideways; labels
## wrap and grow downwards inside the scroll area instead.
## Bible: technical-architecture.md#input-accessibility-and-localisation,
## gate-and-address-spec.md#player-tools
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/fixtures/workbench_fixture.gd")
const UiInput := preload("res://tests/ui/fixtures/ui_input.gd")
## The Workbench's width at 1280 px: stretch ratio 2 of 5 in the Analysis view.
const COLUMN_SIZE: Vector2 = Vector2(512, 720)

var _simulation: Simulation = null
var _workbench: Workbench = null
var _real_locale: String = ""
var _real_pseudo: bool = false


func before_test() -> void:
	_real_locale = TranslationServer.get_locale()
	_real_pseudo = TranslationServer.pseudolocalization_enabled
	_simulation = Fixture.build_simulation()
	EventBus.bind_simulation(_simulation)
	_workbench = Fixture.instantiate()
	add_child(_workbench)
	_workbench.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_workbench.size = COLUMN_SIZE
	_workbench.setup(_simulation)
	var target: GateAddress = Fixture.target_address(_simulation.state)
	var c: Array[int] = target.coordinates
	var constraints: Array[AddressConstraint] = [AddressConstraint.exact_set(c)]
	for index: int in 5:
		constraints.append(AddressConstraint.nearer_than(c[index], c[index + 1]))
	constraints.append(AddressConstraint.glyph_not_at(7, c[0]))
	_simulation.submit(SetWorkbenchCommand.create(WorkbenchState.HOME_ORIGIN, constraints))
	_simulation.submit(QueueAddressCommand.create(target))


func after_test() -> void:
	TranslationServer.pseudolocalization_enabled = _real_pseudo
	TranslationServer.set_locale(_real_locale)
	if is_instance_valid(_workbench):
		_workbench.free()
	EventBus.bind_simulation(SimClock.simulation)


func test_fits_the_column_in_english() -> void:
	TranslationServer.set_locale("en")
	await _assert_fits()


func test_fits_the_column_in_portuguese() -> void:
	TranslationServer.set_locale("pt_BR")
	await _assert_fits()


func test_fits_the_column_in_the_pseudo_locale() -> void:
	TranslationServer.set_locale("pt_BR")
	TranslationServer.pseudolocalization_enabled = true
	await _assert_fits()


## Every visible control lies within the scroll area's width, and every label that does not
## wrap is at least as wide as its text.
func _assert_fits() -> void:
	_workbench.setup(_simulation)
	await UiInput.settle(_workbench)
	await UiInput.settle(_workbench)
	var scroll: ScrollContainer = _workbench.get_node("%Scroll") as ScrollContainer
	var right_edge: float = scroll.get_global_rect().end.x
	assert_array(_candidates_rows()).is_not_empty()
	for control: Control in _visible_controls(scroll):
		var rect: Rect2 = control.get_global_rect()
		var message: String = (
			"%s ends at %.0f, past %.0f" % [control.get_path(), rect.end.x, right_edge]
		)
		assert_float(rect.end.x).override_failure_message(message).is_less_equal(right_edge + 0.5)
		if control is Label and (control as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			var needed: float = control.get_minimum_size().x
			(
				assert_float(rect.size.x)
				. override_failure_message(str(control.get_path()))
				. is_greater_equal(needed)
			)


func _candidates_rows() -> Array[CandidateRow]:
	return (_workbench.get_node("%Candidates") as CandidateList).get_rows()


func _visible_controls(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in root.get_children():
		var control: Control = child as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control is ScrollBar:
			continue
		found.append(control)
		found.append_array(_visible_controls(control))
	return found
