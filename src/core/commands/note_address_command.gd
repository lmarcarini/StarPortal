class_name NoteAddressCommand
extends Command
## The player writes their own note on an Address Book entry, replacing the old one; an empty
## note clears it. Posts address_book_changed() when applied.
## Bible: gate-and-address-spec.md#the-dial-console (Address Book),
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"note_address"

## GateAddress.key() of the entry.
var address_key: String = ""
## The new note: at most AddressEntry.MAX_NOTE_LENGTH characters, no control characters.
var note: String = ""


## Returns a command that sets the note of entry [param key] to [param text].
static func create(key: String, text: String) -> NoteAddressCommand:
	var command := NoteAddressCommand.new()
	command.address_key = key
	command.note = text
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "address_key" or "note" is not a string.
static func from_dict(data: Dictionary) -> Result:
	var key_data: Variant = data.get("address_key")
	var note_data: Variant = data.get("note")
	if not key_data is String or not note_data is String:
		return Result.fail(&"malformed_command", "%s needs string address_key and note" % TYPE)
	var key: String = key_data
	var text: String = note_data
	return Result.ok(create(key, text))


## Returns &"note_address".
func get_type() -> StringName:
	return TYPE


## Rejects an address the book has no entry for (&"unknown_address") and a note that is too
## long or holds a control character (&"invalid_note").
func validate(state: GameState) -> CommandResult:
	if state.address_book.find(address_key) == null:
		return CommandResult.fail(&"unknown_address", address_key)
	var errors: Array[String] = AddressEntry.note_errors(note)
	if not errors.is_empty():
		return CommandResult.fail(&"invalid_note", "; ".join(errors))
	return CommandResult.ok()


## Sets the note and posts address_book_changed.
func apply(state: GameState) -> void:
	state.address_book.find(address_key).note = note
	state.events.post(&"address_book_changed", [])


## Returns JSON-safe data: type, address_key and note.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "address_key": address_key, "note": note}
