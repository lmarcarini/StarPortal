## Tests for the Gate Room view: loading an address into the dial console, holding dial,
## advancing two ticks and reading the outcome banner, the capacitor gauge and the Dial Log,
## for each of the five outcomes, plus the wormhole panel.
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
func test_each_outcome_shows_banner_gauge_drop_and_log_row(
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
	var banner: OutcomeBanner = _panel("OutcomeBanner") as OutcomeBanner
	assert_str(banner.get_name_text()).is_equal("Seals engaging")
	SimClock.step_ticks(2)
	assert_int(banner.get_shown_kind()).is_equal(outcome)
	assert_str(banner.get_name_text()).is_equal(GateRoomFormat.outcome_name(outcome))
	assert_str(banner.get_meaning_text()).is_equal(GateRoomFormat.outcome_meaning(outcome))
	assert_str(banner.get_caption_text()).is_equal(GateRoomFormat.outcome_caption(outcome))
	var entry: DialLogEntry = _simulation.state.gate.dial_log[0]
	assert_int(entry.outcome).is_equal(outcome)
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


func test_banner_icon_shape_differs_per_outcome() -> void:
	var shapes: Dictionary[StringName, bool] = {}
	for kind: int in 5:
		shapes[OutcomeIcon.shape_of(kind)] = true
	assert_int(shapes.size()).is_equal(5)
	assert_bool(shapes.has(&"")).is_false()
	assert_str(String(OutcomeIcon.shape_of(-1))).is_empty()
	assert_str(String(OutcomeIcon.shape_of(5))).is_empty()


## The Dial button needs all seven slots filled; the gauge marks the console's address.
func test_dial_needs_seven_glyphs_in_the_console() -> void:
	var controls: DialControls = _panel("DialControls") as DialControls
	var console: DialConsole = _view.get_console()
	var gauge: CapacitorGauge = _panel("CapacitorGauge") as CapacitorGauge
	assert_bool(controls.get_dial_button().disabled).is_true()
	assert_str(controls.get_reason_text()).is_equal(tr(&"GATE_REASON_INCOMPLETE"))
	assert_float(gauge.get_marker_mwh()).is_equal(-1.0)
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	for index: int in GateAddress.COORDINATE_COUNT - 1:
		console.place(index + 1, address.coordinates[index])
	assert_bool(controls.get_dial_button().disabled).is_true()
	assert_str(controls.get_reason_text()).is_equal(tr(&"GATE_REASON_INCOMPLETE"))
	console.place(GateAddress.COORDINATE_COUNT, address.coordinates[6])
	assert_bool(controls.get_dial_button().disabled).is_false()
	var needed: float = GateQueries.lock_energy_mwh(_simulation.state, address)
	assert_float(gauge.get_marker_mwh()).is_equal_approx(needed, 1e-9)
	console.clear_seal(3)
	assert_bool(controls.get_dial_button().disabled).is_true()
	assert_float(gauge.get_marker_mwh()).is_equal(-1.0)


func test_wormhole_panel_shows_a_lock_and_closes_it() -> void:
	var wormhole: WormholePanel = _panel("WormholePanel") as WormholePanel
	assert_bool(wormhole.visible).is_false()
	_enter(Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	_hold_dial()
	SimClock.step_ticks(2)
	assert_bool(wormhole.visible).is_true()
	assert_str(wormhole.get_destination_text()).is_equal("Destination: P3X-111")
	assert_str(wormhole.get_time_left_text()).is_equal("Time left: 1 h 0 min of 1 h 0 min")
	assert_str(wormhole.get_drain_text()).contains("20.0")
	SimClock.step_ticks(10)
	assert_str(wormhole.get_time_left_text()).is_equal("Time left: 50 min of 1 h 0 min")
	wormhole.get_close_button().pressed.emit()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_str(wormhole.get_closed_text()).is_equal("Wormhole closed on your order.")
	assert_str(wormhole.get_destination_text()).is_empty()


@warning_ignore("unused_parameter")
func test_wormhole_panel_says_why_it_closed(
	reason: StringName,
	expected: String,
	test_parameters: Array = [  # gdlint: ignore=unused-argument
		[&"timeout", "Wormhole closed: the maximum open time ran out."],
		[&"power", "Wormhole collapsed: the capacitors ran dry."],
	]
) -> void:
	var wormhole: WormholePanel = _panel("WormholePanel") as WormholePanel
	EventBus.wormhole_closed.emit(reason)
	assert_str(wormhole.get_closed_text()).is_equal(expected)
	EventBus.dial_started.emit("0")
	assert_bool(wormhole.visible).is_false()


func test_timeout_closes_the_wormhole_and_the_panel_says_so() -> void:
	_enter(Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK))
	_hold_dial()
	SimClock.step_ticks(2 + _simulation.state.balance.max_open_ticks)
	var wormhole: WormholePanel = _panel("WormholePanel") as WormholePanel
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.IDLE)
	assert_str(wormhole.get_closed_text()).contains("maximum open time")


func test_log_lists_newest_first_and_names_the_world_for_locks_only() -> void:
	var log_panel: DialLogPanel = _panel("DialLogPanel") as DialLogPanel
	assert_bool((_panel("DialLogPanel").get_node("%EmptyLabel") as Label).visible).is_true()
	var kinds: Array[int] = [DialOutcome.Kind.NO_GATE, DialOutcome.Kind.LOCK]
	for kind: int in kinds:
		_enter(Fixture.address_for(_simulation.state, kind))
		_hold_dial()
		SimClock.step_ticks(2)
		if kind == DialOutcome.Kind.LOCK:
			(_panel("WormholePanel") as WormholePanel).get_close_button().pressed.emit()
	var rows: Array[LogRow] = log_panel.get_rows()
	assert_int(rows.size()).is_equal(2)
	assert_int(rows[0].get_entry().outcome).is_equal(DialOutcome.Kind.LOCK)
	assert_int(rows[1].get_entry().outcome).is_equal(DialOutcome.Kind.NO_GATE)
	assert_str(rows[0].get_designation_text()).is_equal("Destination: P3X-111")
	assert_str(rows[1].get_designation_text()).is_empty()
