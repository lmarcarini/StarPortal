class_name PinAddressCommand
extends Command
## The player pins an Address Book entry to the top of the Gate's destination rack, or unpins
## it. Posts address_book_changed() when applied.
## Bible: docs/content/interface-rethink.md section 4 (Gate, Destinations)

## The command's stable type id.
const TYPE: StringName = &"pin_address"

## GateAddress.key() of the entry.
var address_key: String = ""
## Pinned after the command.
var pinned: bool = true


## Returns a command that sets entry [param key]'s pin to [param on].
static func create(key: String, on: bool) -> PinAddressCommand:
	var command := PinAddressCommand.new()
	command.address_key = key
	command.pinned = on
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "address_key" is not a string or "pinned" not a bool.
static func from_dict(data: Dictionary) -> Result:
	var key_data: Variant = data.get("address_key")
	var pin_data: Variant = data.get("pinned")
	if not key_data is String or not pin_data is bool:
		return Result.fail(&"malformed_command", "%s needs address_key and pinned" % TYPE)
	var key: String = key_data
	var on: bool = pin_data
	return Result.ok(create(key, on))


## Returns &"pin_address".
func get_type() -> StringName:
	return TYPE


## Rejects an address the book has no entry for (&"unknown_address").
func validate(state: GameState) -> CommandResult:
	if state.address_book.find(address_key) == null:
		return CommandResult.fail(&"unknown_address", address_key)
	return CommandResult.ok()


## Sets the pin and posts address_book_changed.
func apply(state: GameState) -> void:
	state.address_book.find(address_key).pinned = pinned
	state.events.post(&"address_book_changed", [])


## Returns JSON-safe data: type, address_key and pinned.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "address_key": address_key, "pinned": pinned}
