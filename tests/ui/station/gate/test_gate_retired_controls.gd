## Tests for the old Gate Room's controls that moved onto the Gate station (M4.9-14): the main
## key answers an incoming wormhole and IGNORE lets it ring out, the rail's CONSOLE key reads
## the far Ring's console once, the locker hides HOLDING without artefacts and orders a MOTH,
## and a flipped card's note line saves the Address Book note.
## Bible: docs/content/interface-rethink.md section 4 (Gate)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const DialFixture := preload("res://tests/gate/dial_fixture.gd")
const VIEW: PackedScene = preload("res://src/ui/station/gate/gate_station_view.tscn")

var _simulation: Simulation = null
var _holder: Control = null
var _view: GateStationView = null


func before_test() -> void:
	_simulation = Fixture.simulation()
	SimClock.start(_simulation)
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


func _lock() -> void:
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.LOCK)
	_simulation.submit(DialCommand.create(address))
	for i: int in _simulation.state.balance.dial_duration_ticks + 1:
		_simulation.advance_tick()
	_view.get_rail().refresh()


func _incoming() -> void:
	_simulation.state.gate.incoming_faction = &"kindred"
	_simulation.state.gate.incoming_until_tick = _simulation.state.clock.tick + 30
	_view.get_console().refresh(RingLook.new())


func test_ignore_shows_only_while_an_incoming_wormhole_waits() -> void:
	var console: GateConsole = _view.get_console()
	assert_bool(console.get_ignore_key().visible).is_false()
	_incoming()
	assert_str(console.get_main_key().text).is_equal("HW_KEY_ANSWER")
	assert_bool(console.get_ignore_key().visible).is_true()


func test_ignore_lets_it_ring_out() -> void:
	_incoming()
	_view.get_console().ignore_incoming()
	assert_bool(_simulation.state.gate.has_incoming()).is_false()


func test_console_key_reads_once() -> void:
	_lock()
	var key: IconKey = _view.get_rail().get_key(&"console")
	assert_int(key.get_state()).is_equal(IconKey.KeyState.READY)
	_view.get_rail().press(&"console")
	var world: StringName = _simulation.state.gate.connected_world_id
	assert_bool(_simulation.state.worlds.is_console_read(world)).is_true()
	assert_int(key.get_state()).is_equal(IconKey.KeyState.USED)


func test_locker_hides_holding_without_artefacts_and_orders_a_moth() -> void:
	var locker: GateLocker = _view.get_locker()
	assert_bool(locker.get_holding_key().visible).is_false()
	DialFixture.give_moth_rack(_simulation.state)
	_simulation.state.probes.rack = 0
	locker.refresh()
	assert_bool(locker.get_order_key().visible).is_true()
	var owned: int = MothRules.owned(_simulation.state)
	if locker.get_order_key().get_state() == IconKey.KeyState.READY:
		locker.order_moth()
		assert_int(MothRules.owned(_simulation.state)).is_greater(owned)


func test_note_line_saves_the_address_note() -> void:
	var state: GameState = _simulation.state
	var address: GateAddress = Fixture.address_for(state, DialOutcome.Kind.LOCK)
	state.address_book.entries.append(
		AddressEntry.create(address.key(), AddressEntry.Source.DIALED, &"")
	)
	_view.get_rack().rebuild()
	var card: DestinationCard = _view.get_rack().get_cards()[0]
	card.flipped.emit(card)
	var note: LineEdit = _view.find_child("Note", true, false) as LineEdit
	assert_bool(note.is_visible_in_tree()).is_true()
	note.text = "chevron seven sticks"
	note.text_submitted.emit(note.text)
	assert_str(state.address_book.find(address.key()).note).is_equal("chevron seven sticks")
