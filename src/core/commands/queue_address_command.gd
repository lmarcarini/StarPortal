class_name QueueAddressCommand
extends Command
## Adds an address to the end of the Ring's dialing queue. Posts dial_queue_changed when
## applied.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"queue_address"
## Most addresses the queue holds.
const MAX_QUEUE: int = 20

## The address to queue.
var address: GateAddress = null

## Returns a command that queues a copy of [param address].
@warning_ignore("shadowed_variable")
static func create(address: GateAddress) -> QueueAddressCommand:
	var command := QueueAddressCommand.new()
	if address != null:
		command.address = GateAddress.create(address.coordinates, address.origin)
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "address" is not an object passing GateAddress.validate_dict().
static func from_dict(data: Dictionary) -> Result:
	var read: Result = DialCommand.read_address(data.get("address"), TYPE)
	if not read.is_ok:
		return read
	var address_read: GateAddress = read.value
	return Result.ok(create(address_read))


## Returns &"queue_address".
func get_type() -> StringName:
	return TYPE


## Rejects a missing or malformed address (&"bad_address"), an address already in the queue
## (&"already_queued") and a full queue of MAX_QUEUE addresses (&"queue_full").
func validate(state: GameState) -> CommandResult:
	if address == null or not address.is_well_formed():
		return CommandResult.fail(&"bad_address")
	for queued: GateAddress in state.gate.dial_queue:
		if queued.equals(address):
			return CommandResult.fail(&"already_queued", address.key())
	if state.gate.dial_queue.size() >= MAX_QUEUE:
		return CommandResult.fail(&"queue_full")
	return CommandResult.ok()


## Appends a copy of the address to the queue and posts dial_queue_changed.
func apply(state: GameState) -> void:
	state.gate.dial_queue.append(GateAddress.create(address.coordinates, address.origin))
	state.events.post(&"dial_queue_changed")


## Returns JSON-safe data: type and address.
func to_dict() -> Dictionary:
	var address_data: Variant = address.to_dict() if address != null else null
	return {"type": String(TYPE), "address": address_data}
