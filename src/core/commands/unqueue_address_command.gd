class_name UnqueueAddressCommand
extends Command
## Removes an address from the Ring's dialing queue; the others keep their order. Posts
## dial_queue_changed when applied.
## Bible: gate-and-address-spec.md#player-tools,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"unqueue_address"

## The address to remove.
var address: GateAddress = null

## Returns a command that removes [param address] from the queue.
@warning_ignore("shadowed_variable")
static func create(address: GateAddress) -> UnqueueAddressCommand:
	var command := UnqueueAddressCommand.new()
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


## Returns &"unqueue_address".
func get_type() -> StringName:
	return TYPE


## Rejects a missing address (&"bad_address") and one that is not in the queue
## (&"not_queued").
func validate(state: GameState) -> CommandResult:
	if address == null:
		return CommandResult.fail(&"bad_address")
	if _index_in(state.gate.dial_queue) < 0:
		return CommandResult.fail(&"not_queued", address.key())
	return CommandResult.ok()


## Removes the address from the queue and posts dial_queue_changed.
func apply(state: GameState) -> void:
	state.gate.dial_queue.remove_at(_index_in(state.gate.dial_queue))
	state.events.post(&"dial_queue_changed")


## Returns JSON-safe data: type and address.
func to_dict() -> Dictionary:
	var address_data: Variant = address.to_dict() if address != null else null
	return {"type": String(TYPE), "address": address_data}


## Index of the address in [param queue], or -1.
func _index_in(queue: Array[GateAddress]) -> int:
	for index: int in queue.size():
		if queue[index].equals(address):
			return index
	return -1
