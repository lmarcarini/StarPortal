## Tests for M4.9-16: an address pin and the alien panel's draft (firm glyphs and pencilled
## guesses) are set by commands and survive a save and load; bad data is refused.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Destinations and Composing)
extends GdUnitTestSuite

const Fixture := preload("res://tests/ui/gate_room_fixture.gd")
const PANEL: PackedScene = preload("res://src/ui/station/gate/alien_panel.tscn")

var _simulation: Simulation = null


func before_test() -> void:
	_simulation = Fixture.simulation()
	var address: GateAddress = Fixture.address_for(_simulation.state, DialOutcome.Kind.BLOCKED)
	_simulation.state.address_book.entries.append(
		AddressEntry.create(address.key(), AddressEntry.Source.DOCUMENT, &"doc_x")
	)


func _reloaded() -> GameState:
	var text: String = JSON.stringify(_simulation.state.to_dict())
	var data: Dictionary = JSON.parse_string(text)
	assert_array(GameState.validate_dict(data)).is_empty()
	return GameState.from_dict(data)


func test_pin_survives_save_and_load() -> void:
	var key: String = _simulation.state.address_book.entries[0].address_key
	assert_bool(_simulation.submit(PinAddressCommand.create(key, true)).is_ok).is_true()
	assert_bool(_reloaded().address_book.find(key).pinned).is_true()
	assert_bool(_simulation.submit(PinAddressCommand.create(key, false)).is_ok).is_true()
	assert_bool(_reloaded().address_book.find(key).pinned).is_false()
	assert_bool(_simulation.submit(PinAddressCommand.create("1-2-3", true)).is_ok).is_false()


func test_pencil_survives_save_and_load() -> void:
	var firm: Array[int] = [4, -1, -1, -1, -1, -1, -1]
	var pencil: Array[int] = [-1, 9, -1, -1, -1, -1, -1]
	assert_bool(_simulation.submit(SetAddressDraftCommand.create(firm, pencil)).is_ok).is_true()
	var back: GameState = _reloaded()
	assert_array(back.address_book.draft_firm).is_equal(firm)
	assert_array(back.address_book.draft_pencil).is_equal(pencil)


func test_bad_draft_is_refused() -> void:
	var bad: Array[int] = [40, -1, -1, -1, -1, -1, -1]
	var none: Array[int] = [-1, -1, -1, -1, -1, -1, -1]
	assert_bool(_simulation.submit(SetAddressDraftCommand.create(bad, none)).is_ok).is_false()
	var data: Dictionary = _simulation.state.address_book.to_dict()
	data["draft"] = {"firm": [1, 2], "pencil": none}
	assert_array(AddressBookState.validate_dict(data)).is_not_empty()


func test_commands_round_trip_through_the_factory() -> void:
	var firm: Array[int] = [4, -1, -1, -1, -1, -1, -1]
	for command: Command in [
		PinAddressCommand.create("x", true), SetAddressDraftCommand.create(firm, firm)
	]:
		var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
		var built: Result = CommandFactory.from_dict(data)
		assert_bool(built.is_ok).is_true()
		var made: Command = built.value
		assert_dict(made.to_dict()).is_equal(command.to_dict())


func test_panel_keeps_the_draft_in_the_state() -> void:
	var panel: AlienPanel = PANEL.instantiate() as AlienPanel
	add_child(panel)
	panel.setup(_simulation)
	panel.press_glyph(5)
	assert_int(_simulation.state.address_book.draft_firm[0]).is_equal(5)
	var again: AlienPanel = PANEL.instantiate() as AlienPanel
	add_child(again)
	again.setup(_simulation)
	assert_int(again.get_draft().firm[0]).is_equal(5)
	panel.free()
	again.free()
