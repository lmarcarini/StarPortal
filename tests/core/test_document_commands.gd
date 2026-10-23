## Tests for DeliverDocumentCommand, MarkDocumentReadCommand and NoteAddressCommand: validation
## against the state, what apply() changes and posts, and rebuilding from to_dict() through the
## CommandFactory, including after a JSON round trip.
## Bible: gate-and-address-spec.md#where-addresses-come-from,
## gate-and-address-spec.md#the-dial-console (Address Book),
## technical-architecture.md#simulation-clock-and-commands
extends GdUnitTestSuite

const KEY: String = "3-17-0-22-9-14-30-5"

var _state: GameState


func before_test() -> void:
	_state = GameState.new_game(7)
	_state.clock.tick = 500
	var entry := AddressEntry.create(KEY, AddressEntry.Source.DIALED, &"")
	_state.address_book.entries.append(entry)


## The events posted so far, as [name, args] pairs.
func _events() -> Array[Array]:
	var posted: Array[Array] = []
	for event: SimEvent in _state.events.drain():
		posted.append([event.name, event.args])
	return posted


func _rebuilt(command: Command) -> Command:
	var data: Dictionary = JSON.parse_string(JSON.stringify(command.to_dict()))
	var result: Result = CommandFactory.from_dict(data)
	assert_bool(result.is_ok).override_failure_message(str(result.detail)).is_true()
	var rebuilt: Command = result.value
	assert_dict(rebuilt.to_dict()).is_equal(command.to_dict())
	assert_object(rebuilt.get_script()).is_same(command.get_script())
	return rebuilt


## Delivering adds the document unread at the clock's tick and posts document_received once.
func test_deliver_adds_and_posts() -> void:
	var command := DeliverDocumentCommand.create(&"doc_note")
	assert_bool(command.validate(_state).is_ok).is_true()
	command.apply(_state)
	assert_array(_state.archive.received).is_equal([&"doc_note"])
	assert_int(_state.archive.received_tick[&"doc_note"]).is_equal(500)
	assert_bool(_state.archive.is_read(&"doc_note")).is_false()
	assert_array(_events()).is_equal([[&"document_received", [&"doc_note"]]])
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## A document cannot be delivered twice, nor an empty id.
func test_deliver_rejects_repeat_and_empty() -> void:
	DeliverDocumentCommand.create(&"doc_note").apply(_state)
	var again: CommandResult = DeliverDocumentCommand.create(&"doc_note").validate(_state)
	assert_str(String(again.error_code)).is_equal("already_received")
	var empty: CommandResult = DeliverDocumentCommand.create(&"").validate(_state)
	assert_str(String(empty.error_code)).is_equal("empty_document_id")


## Marking read needs a received document; marking it again is harmless.
func test_mark_read() -> void:
	var unknown: CommandResult = MarkDocumentReadCommand.create(&"doc_note").validate(_state)
	assert_str(String(unknown.error_code)).is_equal("unknown_document")
	DeliverDocumentCommand.create(&"doc_note").apply(_state)
	_events()
	var command := MarkDocumentReadCommand.create(&"doc_note")
	assert_bool(command.validate(_state).is_ok).is_true()
	command.apply(_state)
	assert_bool(_state.archive.is_read(&"doc_note")).is_true()
	assert_bool(command.validate(_state).is_ok).is_true()
	assert_array(_events()).is_empty()
	assert_array(GameState.validate_dict(_state.to_dict())).is_empty()


## A note sets the entry's note and posts address_book_changed once.
func test_note_address_sets_note() -> void:
	var command := NoteAddressCommand.create(KEY, "Dead world. Safe.")
	assert_bool(command.validate(_state).is_ok).is_true()
	command.apply(_state)
	assert_str(_state.address_book.find(KEY).note).is_equal("Dead world. Safe.")
	assert_array(_events()).is_equal([[&"address_book_changed", []]])
	NoteAddressCommand.create(KEY, "").apply(_state)
	assert_str(_state.address_book.find(KEY).note).is_empty()


## A note needs a known address and valid text.
func test_note_address_rejects_bad_input() -> void:
	var unknown: CommandResult = NoteAddressCommand.create("1-2-3-4-6-7-8-5", "x").validate(_state)
	assert_str(String(unknown.error_code)).is_equal("unknown_address")
	var long_note: CommandResult = NoteAddressCommand.create(KEY, "x".repeat(141)).validate(_state)
	assert_str(String(long_note.error_code)).is_equal("invalid_note")
	var control: CommandResult = NoteAddressCommand.create(KEY, "a\u0007b").validate(_state)
	assert_str(String(control.error_code)).is_equal("invalid_note")
	assert_bool(NoteAddressCommand.create(KEY, "x".repeat(140)).validate(_state).is_ok).is_true()


## Every command rebuilds equal through the CommandFactory after a JSON round trip.
func test_commands_rebuild_from_to_dict() -> void:
	var deliver := DeliverDocumentCommand.create(&"doc_note")
	assert_dict(deliver.to_dict()).is_equal({"type": "deliver_document", "document_id": "doc_note"})
	_rebuilt(deliver)
	_rebuilt(MarkDocumentReadCommand.create(&"doc_note"))
	var note := NoteAddressCommand.create(KEY, "Ωμέγα")
	assert_dict(note.to_dict()).is_equal(
		{"type": "note_address", "address_key": KEY, "note": "Ωμέγα"}
	)
	_rebuilt(note)


## Data without the right string fields fails with &"malformed_command".
func test_malformed_data_fails() -> void:
	var cases: Array[Dictionary] = [
		{"type": "deliver_document"},
		{"type": "deliver_document", "document_id": 4},
		{"type": "mark_document_read", "document_id": null},
		{"type": "note_address", "address_key": KEY},
		{"type": "note_address", "note": "x"},
		{"type": "note_address", "address_key": 3, "note": "x"},
	]
	for data: Dictionary in cases:
		var result: Result = CommandFactory.from_dict(data)
		assert_str(String(result.error_code)).override_failure_message(str(data)).is_equal(
			"malformed_command"
		)
