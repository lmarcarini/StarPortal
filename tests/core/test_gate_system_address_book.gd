## Tests for GateSystem's Address Book record: every resolved dial adds or updates the entry for
## its address with the outcome and tick, a lock also records the world, a failed dial never
## does, and address_book_changed is posted once per dial, after dial_resolved.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## gate-and-address-spec.md#dialing-outcomes-and-energy
extends GdUnitTestSuite

const DialFixture := preload("res://tests/gate/dial_fixture.gd")

var _state: GameState
var _simulation: Simulation
var _events: Array[StringName] = []


func before_test() -> void:
	_state = DialFixture.state(null, true)
	_simulation = DialFixture.simulation(_state)
	_events.clear()
	_simulation.event_posted.connect(
		func(event_name: StringName, _args: Array) -> void: _events.append(event_name)
	)


## Dials [param address] while paused, then runs the clock until it resolves, and closes any
## wormhole it opened.
func _dial(address: GateAddress) -> void:
	_state.clock.is_paused = true
	assert_bool(_simulation.submit(DialCommand.create(address)).is_ok).is_true()
	_state.clock.is_paused = false
	_simulation.advance_tick()
	_simulation.advance_tick()
	_state.clock.is_paused = true
	if _state.gate.mode == GateState.RingMode.LOCKED:
		_simulation.submit(CloseWormholeCommand.new())


func _address(id: StringName) -> GateAddress:
	return DialFixture.address_of(_state.galaxy, id)


## A lock adds a DIALED entry with the outcome, the tick and the world; the event comes once.
func test_lock_adds_entry_with_world() -> void:
	var address := _address(DialFixture.OPEN_ID)
	_dial(address)
	assert_int(_state.address_book.entries.size()).is_equal(1)
	var entry: AddressEntry = _state.address_book.find(address.key())
	assert_int(entry.source).is_equal(AddressEntry.Source.DIALED)
	assert_int(entry.last_outcome).is_equal(DialOutcome.Kind.LOCK)
	assert_int(entry.last_dialed_tick).is_equal(_state.gate.dial_log[0].tick)
	assert_str(String(entry.world_id)).is_equal(String(DialFixture.OPEN_ID))
	assert_int(_events.count(&"address_book_changed")).is_equal(1)
	var resolved_at: int = _events.find(&"dial_resolved")
	assert_int(_events.find(&"address_book_changed")).is_equal(resolved_at + 1)
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## A hostile lock also records the world.
func test_hostile_lock_records_world() -> void:
	var address := _address(DialFixture.GUARDED_ID)
	_dial(address)
	var entry: AddressEntry = _state.address_book.find(address.key())
	assert_int(entry.last_outcome).is_equal(DialOutcome.Kind.HOSTILE_LOCK)
	assert_str(String(entry.world_id)).is_equal(String(DialFixture.GUARDED_ID))


## Blocked, no gate and a rejected origin record the outcome but never the world, though the
## Dial Log knows it.
func test_failed_dials_record_no_world() -> void:
	var blocked := _address(DialFixture.BURIED_ID)
	var shielded := _address(DialFixture.SHIELDED_ID)
	var home := _state.galaxy.home()
	var no_gate := _state.galaxy.address_of(home.id, home.origin_glyph)
	var wrong_origin: GateAddress = null
	for glyph: int in GateAddress.GLYPH_COUNT:
		if wrong_origin == null and not blocked.seals().has(glyph):
			wrong_origin = GateAddress.create(blocked.coordinates, glyph)
	for address: GateAddress in [blocked, shielded, no_gate, wrong_origin]:
		_dial(address)
	assert_str(String(_state.gate.dial_log[0].world_id)).is_equal(String(DialFixture.BURIED_ID))
	assert_int(_state.address_book.entries.size()).is_equal(4)
	for entry: AddressEntry in _state.address_book.entries:
		assert_str(String(entry.world_id)).override_failure_message(entry.address_key).is_empty()
	assert_str(_state.address_book.entries[0].address_key).is_equal(wrong_origin.key())
	var outcomes: Array[int] = []
	for address: GateAddress in [blocked, shielded, no_gate, wrong_origin]:
		outcomes.append(_state.address_book.find(address.key()).last_outcome)
	(
		assert_array(outcomes)
		. is_equal(
			[
				DialOutcome.Kind.BLOCKED,
				DialOutcome.Kind.BLOCKED,
				DialOutcome.Kind.NO_GATE,
				DialOutcome.Kind.ORIGIN_REJECTED,
			]
		)
	)
	assert_int(_events.count(&"address_book_changed")).is_equal(4)
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## Dialing a known address again updates its entry in place, keeping the note.
func test_redial_updates_entry() -> void:
	var address := _address(DialFixture.BURIED_ID)
	_dial(address)
	var first_tick: int = _state.address_book.find(address.key()).last_dialed_tick
	_state.address_book.find(address.key()).note = "buried"
	_dial(address)
	var entry: AddressEntry = _state.address_book.find(address.key())
	assert_int(_state.address_book.entries.size()).is_equal(1)
	assert_int(entry.last_dialed_tick).is_greater(first_tick)
	assert_int(entry.last_dialed_tick).is_equal(_state.gate.dial_log[1].tick)
	assert_str(entry.note).is_equal("buried")


## A world learned through a lock stays known after a later failed dial of the same address,
## and the state still saves and loads as valid. (The fixture Ring is buried after the lock,
## so the same address then answers Blocked.)
func test_world_stays_known_after_a_later_failed_dial() -> void:
	var address := _address(DialFixture.OPEN_ID)
	_dial(address)
	assert_int(_state.gate.mode).is_equal(GateState.RingMode.IDLE)
	_state.galaxy.get_world(DialFixture.OPEN_ID).ring_status = WorldDef.RingStatus.BURIED
	_dial(address)
	assert_int(_state.gate.dial_log[1].outcome).is_equal(DialOutcome.Kind.BLOCKED)
	var entry: AddressEntry = _state.address_book.find(address.key())
	assert_int(entry.last_outcome).is_equal(DialOutcome.Kind.BLOCKED)
	assert_str(String(entry.world_id)).is_equal(String(DialFixture.OPEN_ID))
	var data: Dictionary = JSON.parse_string(JSON.stringify(_state.to_dict()))
	assert_array(GameState.validate_dict(data)).is_empty()
	var loaded := GameState.from_dict(data)
	assert_str(String(loaded.address_book.find(address.key()).world_id)).is_equal(
		String(DialFixture.OPEN_ID)
	)
