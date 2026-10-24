class_name InstallCapacitorsCommand
extends Command
## Starts installing a capacitor bank: free, it takes BalanceConfig.capacitor_bank_install_ticks
## of in-game time, then PowerSystem adds the bank's capacity. One install at a time, up to
## BalanceConfig.max_capacitor_banks banks. Posts nothing when applied: the install is read
## from PowerState.
## Bible: gate-and-address-spec.md#the-dial-console, game-design.md#core-loop,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"install_capacitors"


## Rebuilds a command from its to_dict() data; it has no arguments, so this never fails.
static func from_dict(_data: Dictionary) -> Result:
	return Result.ok(InstallCapacitorsCommand.new())


## Returns &"install_capacitors".
func get_type() -> StringName:
	return TYPE


## Rejects an install while one is running (&"install_running") and one past the number of
## banks the base has room for, or with no balance to read it from (&"no_bank_slot").
func validate(state: GameState) -> CommandResult:
	if state.power.install_ticks_left > 0:
		return CommandResult.fail(&"install_running")
	if state.balance == null:
		return CommandResult.fail(&"no_bank_slot", "no balance")
	if state.power.banks_installed >= state.balance.max_capacitor_banks:
		return CommandResult.fail(&"no_bank_slot")
	return CommandResult.ok()


## Starts the install job.
func apply(state: GameState) -> void:
	state.power.install_ticks_left = state.balance.capacitor_bank_install_ticks


## Returns JSON-safe data: the type only.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
