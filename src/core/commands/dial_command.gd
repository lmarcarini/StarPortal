class_name DialCommand
extends Command
## Dials an address from the Workbench: a bet of stored energy. Validates, then starts the
## dial; GateSystem resolves it and spends the cost. Posts dial_started(address key) when
## applied.
## Bible: gate-and-address-spec.md#dialing-outcomes-and-energy,
## technical-architecture.md#errors-and-guard-clauses,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"dial"

## The address to dial.
var address: GateAddress = null

## Returns a command that dials a copy of [param address].
@warning_ignore("shadowed_variable")
static func create(address: GateAddress) -> DialCommand:
	var command := DialCommand.new()
	command.address = _copy(address)
	return command


## Rebuilds a command from its to_dict() [param data], e.g. after a JSON round trip. Fails
## with &"malformed_command" when "address" is not an object passing
## GateAddress.validate_dict().
static func from_dict(data: Dictionary) -> Result:
	var read: Result = read_address(data.get("address"), TYPE)
	if not read.is_ok:
		return read
	var address_read: GateAddress = read.value
	return Result.ok(create(address_read))


## Reads saved command data [param value] as a GateAddress for a command of [param type]:
## the Result's value is the address, or it fails with &"malformed_command" when the value
## is not an object passing GateAddress.validate_dict(). Shared by the Ring's commands.
static func read_address(value: Variant, type: StringName) -> Result:
	if not value is Dictionary:
		return Result.fail(&"malformed_command", "%s needs an address object" % type)
	var address_data: Dictionary = value
	var errors: Array[String] = GateAddress.validate_dict(address_data)
	if not errors.is_empty():
		return Result.fail(&"malformed_command", "%s address: %s" % [type, "; ".join(errors)])
	return Result.ok(GateAddress.from_dict(address_data))


## Returns &"dial".
func get_type() -> StringName:
	return TYPE


## Rejects a missing or malformed address (&"bad_address"), a Ring that is not IDLE
## (&"ring_busy") and a bank holding less than the address's lock energy
## (&"insufficient_charge").
func validate(state: GameState) -> CommandResult:
	if address == null or not address.is_well_formed():
		return CommandResult.fail(&"bad_address")
	if state.gate.mode != GateState.RingMode.IDLE:
		return CommandResult.fail(&"ring_busy")
	var needed_mwh: float = GateQueries.lock_energy_mwh(state, address)
	if state.power.stored_mwh < needed_mwh:
		return CommandResult.fail(
			&"insufficient_charge", "%f of %f MWh" % [state.power.stored_mwh, needed_mwh]
		)
	return CommandResult.ok()


## Starts the dial at the clock's tick and posts dial_started.
func apply(state: GameState) -> void:
	var needed_mwh: float = GateQueries.lock_energy_mwh(state, address)
	RingControl.start_dial(state.gate, address, needed_mwh, state.clock.tick)
	state.events.post(&"dial_started", [address.key()])


## Returns JSON-safe data: type and address.
func to_dict() -> Dictionary:
	var address_data: Variant = address.to_dict() if address != null else null
	return {"type": String(TYPE), "address": address_data}


static func _copy(source: GateAddress) -> GateAddress:
	if source == null:
		return null
	return GateAddress.create(source.coordinates, source.origin)
