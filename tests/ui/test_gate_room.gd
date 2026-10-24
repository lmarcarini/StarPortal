## Tests for the Gate Room view: loading an address into the dial console, holding dial,
## letting the dialing sequence resolve it and reading the result card or wormhole screen, the
## capacitor gauge and the Dial Log, for each of the five outcomes.
## Bible: gate-and-address-spec.md#the-dial-console,
## gate-and-address-spec.md#dialing-outcomes-and-energy, game-design.md#core-loop
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


## Makes [param address] the address to dial.
func _enter(address: GateAddress) -> void:
	Fixture.select(_view, address)


## Holds the dial button for the whole confirmation time.
func _hold_dial() -> void:
	var button: HoldButton = _view.find_child("DialButton", true, false) as HoldButton
	button.begin_hold()
	button.advance(HoldButton.HOLD_SECONDS)


func _panel(node_name: String) -> Node:
	return _view.find_child(node_name, true, false)


@warning_ignore("unused_parameter")
func test_each_outcome_ends_on_its_card_or_screen_with_gauge_drop_and_log_row(
	outcome: int,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		[DialOutcome.Kind.NO_GATE],
		[DialOutcome.Kind.BLOCKED],
		[DialOutcome.Kind.ORIGIN_REJECTED],
		[DialOutcome.Kind.LOCK],
		[DialOutcome.Kind.HOSTILE_LOCK],
	]
) -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, outcome)
	_enter(address)
	_hold_dial()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)
	var overlays: GateOverlays = _view.get_overlays()
	assert_bool(overlays.get_sequence().is_open()).is_true()
	assert_str(overlays.get_sequence().get_status_text()).is_equal("Seals engaging: 0 of 8")
	overlays.get_sequence().skip()
	var entry: DialLogEntry = _simulation.state.gate.dial_log[0]
	assert_int(entry.outcome).is_equal(outcome)
	var card: ResultCard = overlays.get_result_card()
	var is_lock: bool = DialOutcome.is_lock(outcome)
	assert_bool(overlays.get_wormhole_screen().is_showing_open()).is_equal(is_lock)
	assert_bool(card.is_open()).is_equal(not is_lock)
	if not is_lock:
		assert_int(card.get_shown_kind()).is_equal(outcome)
		assert_str(card.get_name_text()).is_equal(GateRoomFormat.outcome_name(outcome))
		assert_str(card.get_meaning_text()).is_equal(GateRoomFormat.outcome_meaning(outcome))
		assert_str(card.get_caption_text()).is_equal(GateRoomFormat.outcome_caption(outcome))
		assert_str(card.get_energy_text()).is_equal(
			"Energy spent: " + GateRoomFormat.energy(entry.energy_spent_mwh)
		)
	var gauge: CapacitorGauge = _panel("CapacitorGauge") as CapacitorGauge
	assert_float(entry.energy_spent_mwh).is_greater(0.0)
	assert_float(gauge.get_bar_value()).is_equal_approx(
		DialFixture.CAPACITY_MWH - entry.energy_spent_mwh, 0.01
	)
	var log_panel: DialLogPanel = _panel("DialLogPanel") as DialLogPanel
	assert_int(log_panel.get_rows().size()).is_equal(1)
	var row: LogRow = log_panel.get_rows()[0]
	assert_object(row.get_entry()).is_same(entry)
	assert_str(GateRoomFormat.date_time(entry.tick)).is_equal("2026-01-01 00:02")


func test_outcome_icon_shape_differs_per_outcome() -> void:
	var shapes: Dictionary[StringName, bool] = {}
	for kind: int in 5:
		shapes[OutcomeIcon.shape_of(kind)] = true
	assert_int(shapes.size()).is_equal(5)
	assert_bool(shapes.has(&"")).is_false()
	assert_str(String(OutcomeIcon.shape_of(-1))).is_empty()
	assert_str(String(OutcomeIcon.shape_of(5))).is_empty()


## The Dial button needs all seven slots filled. Nothing in the view shows the energy the
## address needs: no text mentions it, at any step.
func test_dial_needs_seven_glyphs_and_never_shows_the_needed_charge() -> void:
	var controls: DialControls = _panel("DialControls") as DialControls
	var console: DialConsole = _view.get_console()
	assert_bool(controls.get_dial_button().disabled).is_true()
	assert_str(controls.get_reason_text()).is_equal(tr(&"GATE_REASON_INCOMPLETE"))
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	for index: int in GateAddress.COORDINATE_COUNT - 1:
		console.place(index + 1, address.coordinates[index])
	assert_bool(controls.get_dial_button().disabled).is_true()
	assert_str(controls.get_reason_text()).is_equal(tr(&"GATE_REASON_INCOMPLETE"))
	console.place(GateAddress.COORDINATE_COUNT, address.coordinates[6])
	assert_bool(controls.get_dial_button().disabled).is_false()
	var needed: String = GateRoomFormat.energy(
		GateQueries.lock_energy_mwh(_simulation.state, address)
	)
	for text: String in Fixture.visible_texts(_view):
		assert_str(text).override_failure_message("shows the needed charge: " + text).not_contains(
			needed
		)
	console.clear_seal(3)
	assert_bool(controls.get_dial_button().disabled).is_true()


func test_log_lists_newest_first_and_names_the_world_for_locks_only() -> void:
	var log_panel: DialLogPanel = _panel("DialLogPanel") as DialLogPanel
	assert_bool((_panel("DialLogPanel").get_node("%EmptyLabel") as Label).visible).is_true()
	var kinds: Array[int] = [DialOutcome.Kind.NO_GATE, DialOutcome.Kind.LOCK]
	for kind: int in kinds:
		_enter(Fixture.address_for(_simulation.state, kind))
		_hold_dial()
		SimClock.step_ticks(2)
		if kind == DialOutcome.Kind.LOCK:
			_view.get_overlays().get_wormhole_screen().get_close_button().pressed.emit()
	var rows: Array[LogRow] = log_panel.get_rows()
	assert_int(rows.size()).is_equal(2)
	assert_int(rows[0].get_entry().outcome).is_equal(DialOutcome.Kind.LOCK)
	assert_int(rows[1].get_entry().outcome).is_equal(DialOutcome.Kind.NO_GATE)
	assert_str(rows[0].get_designation_text()).is_equal("Destination: P3X-111")
	assert_str(rows[1].get_designation_text()).is_empty()
