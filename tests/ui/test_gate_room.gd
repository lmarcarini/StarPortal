## Tests for the Gate Room view: queueing an address, holding dial, advancing two ticks and
## reading the outcome banner, the capacitor gauge and the Dial Log, for each of the five
## outcomes, plus the wormhole panel and the queue panel.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## gate-and-address-spec.md#player-tools, game-design.md#core-loop
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


## Types [param address] into the pickers and presses "add to queue".
func _enter(address: GateAddress) -> void:
	var entry: AddressEntry = _view.find_child("AddressEntry", true, false) as AddressEntry
	entry.set_entered_address(address)
	entry.get_add_button().pressed.emit()


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
	var queue: DialQueuePanel = _panel("DialQueuePanel") as DialQueuePanel
	assert_int(queue.get_rows().size()).is_equal(1)
	assert_str(queue.get_selected().key()).is_equal(address.key())
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


func test_queue_rows_show_energy_and_ready_time() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	_enter(address)
	var row: QueueRow = (_panel("DialQueuePanel") as DialQueuePanel).get_rows()[0]
	var needed: float = GateQueries.lock_energy_mwh(_simulation.state, address)
	assert_str(row.get_info_label().text).contains(GateRoomFormat.energy(needed))
	assert_str(row.get_info_label().text).contains("Charged, ready now")
	assert_array((row.get_node("%Strip") as AddressStrip).get_glyph_indices()).is_equal(
		address.seals()
	)
	_simulation.state.power.stored_mwh = 0.0
	_simulation.state.power.plant_output_mw = 30.0
	SimClock.step_ticks(1)
	assert_str(row.get_info_label().text).contains("Ready in")
	_simulation.state.power.plant_output_mw = 0.0
	SimClock.step_ticks(1)
	assert_str(row.get_info_label().text).contains("Never at current output")


func test_remove_deletes_the_row_and_keeps_a_selection() -> void:
	var first: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	var second: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.BLOCKED)
	_enter(first)
	_enter(second)
	var queue: DialQueuePanel = _panel("DialQueuePanel") as DialQueuePanel
	assert_int(queue.get_rows().size()).is_equal(2)
	assert_str(queue.get_selected().key()).is_equal(second.key())
	queue.get_rows()[1].get_remove_button().pressed.emit()
	assert_int(_simulation.state.gate.dial_queue.size()).is_equal(1)
	assert_int(queue.get_rows().size()).is_equal(1)
	assert_str(queue.get_selected().key()).is_equal(first.key())
	queue.get_rows()[0].get_remove_button().pressed.emit()
	assert_object(queue.get_selected()).is_null()
	assert_bool((_panel("DialQueuePanel").get_node("%EmptyLabel") as Label).visible).is_true()


func test_entry_rejects_incomplete_duplicate_and_queued_addresses() -> void:
	var entry: AddressEntry = _panel("AddressEntry") as AddressEntry
	assert_bool(entry.get_add_button().disabled).is_true()
	assert_str(entry.get_message_text()).is_equal("Choose a glyph for each of the eight seals.")
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	var repeated: GateAddress = GateAddress.create(address.coordinates, address.coordinates[0])
	entry.set_entered_address(repeated)
	assert_bool(entry.get_add_button().disabled).is_true()
	assert_str(entry.get_message_text()).is_equal("A glyph cannot appear twice in an address.")
	_enter(address)
	(
		assert_array(entry.get_pickers().map(func(p: GlyphPicker) -> int: return p.get_glyph()))
		. is_equal([-1, -1, -1, -1, -1, -1, -1, -1])
	)
	entry.set_entered_address(address)
	entry.get_add_button().pressed.emit()
	assert_str(entry.get_message_text()).is_equal("That address is already in the queue.")
	assert_int(_simulation.state.gate.dial_queue.size()).is_equal(1)


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
		(
			(_panel("DialQueuePanel") as DialQueuePanel)
			. get_rows()[-1]
			. get_select_button()
			. pressed
			. emit()
		)
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
