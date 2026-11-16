## Tests for the destination rack: every Address Book entry is a card (a noted, never dialled
## one shows its glyphs), selecting a card fills the console as loading an entry did, the
## order puts pinned and team worlds first, the filter cycles, a flip shows the report, and
## the rack stays clear of the Ring.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Destinations)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null


func before_test() -> void:
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
	for kind: int in [DialOutcome.Kind.HOSTILE_LOCK, DialOutcome.Kind.LOCK]:
		_simulation.submit(DialCommand.create(Fixture.address_for(_simulation.state, kind)))
		for i: int in _simulation.state.balance.dial_duration_ticks + 1:
			_simulation.advance_tick()
		_simulation.submit(CloseWormholeCommand.new())
	var noted: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.BLOCKED)
	_simulation.state.address_book.entries.append(
		AddressEntry.create(noted.key(), AddressEntry.Source.DOCUMENT, &"doc_x")
	)
	_holder = Control.new()
	_holder.size = Vector2(1920, 1080)
	_holder.theme = UiThemeBuilder.build(1.0)
	add_child(_holder)
	_view = VIEW.instantiate() as GateStationView
	_holder.add_child(_view)
	_view.setup(_simulation)


func after_test() -> void:
	SimClock.stop()
	_holder.free()


func test_every_entry_is_a_card() -> void:
	var cards: Array[DestinationCard] = _view.get_rack().get_cards()
	assert_int(cards.size()).is_equal(_simulation.state.address_book.entries.size())
	var last: DestinationCard = cards[cards.size() - 1]
	assert_str(last.get_destination().title).is_empty()


func test_select_fills_console() -> void:
	var card: DestinationCard = _view.get_rack().get_cards()[0]
	card.pressed.emit()
	var chosen: GateDestination = _view.get_console().get_destination()
	assert_str(chosen.address.key()).is_equal(card.get_key())
	_view.get_console().press_main_key()
	assert_int(_simulation.state.gate.mode).is_equal(GateState.RingMode.DIALING)


func test_order_and_pin() -> void:
	var cards: Array[DestinationCard] = _view.get_rack().get_cards()
	var last_key: String = cards[cards.size() - 1].get_key()
	cards[cards.size() - 1].pin_toggled.emit(cards[cards.size() - 1])
	assert_str(_view.get_rack().get_cards()[0].get_key()).is_equal(last_key)


func test_filter_cycles() -> void:
	var rack: DestinationRack = _view.get_rack()
	rack.cycle_filter()
	assert_int(rack.get_filter()).is_equal(DestinationText.Filter.TEAM)
	assert_int(rack.get_cards().size()).is_equal(0)
	rack.cycle_filter()
	assert_int(rack.get_cards().size()).is_equal(1)


func test_flip_shows_report() -> void:
	var card: DestinationCard = _view.get_rack().get_cards()[0]
	card.flipped.emit(card)
	assert_bool(_view.get_report_card().visible).is_true()


func test_hostile_icon() -> void:
	var icons: Array[StringName] = []
	for card: DestinationCard in _view.get_rack().get_cards():
		icons.append_array(card.get_destination().icons)
	assert_array(icons).contains([&"threat"])


func test_rack_clear_of_ring() -> void:
	_view._layout()
	var ring_right: float = _view.get_station().anchor(&"ring_outer").x
	ring_right += _view.get_station().radius(&"ring_outer")
	assert_float(_view.get_rack().position.x).is_greater(ring_right)
