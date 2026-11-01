class_name DigLevelCommand
extends Command
## The player digs a new level below the deepest: pays BalanceConfig.dig_level_costs_k and
## the level arrives after dig_level_ticks (ConstructionSystem). One dig at a time; it uses no
## construction slot and draws no power. Posts budget_changed when applied.
## Bible: docs/content/m2-base.md section 4

## The command's stable type id.
const TYPE: StringName = &"dig_level"


## Rebuilds a command from its to_dict() data; it has no arguments, so this never fails.
static func from_dict(_data: Dictionary) -> Result:
	return Result.ok(DigLevelCommand.new())


## The cost in $k of digging level [param level] of [param state], or 0 past the limit.
static func cost_k(state: GameState, level: int) -> int:
	var index: int = level - state.balance.starting_levels - 1
	if index < 0 or index >= state.balance.dig_level_costs_k.size():
		return 0
	return state.balance.dig_level_costs_k[index]


## Returns &"dig_level".
func get_type() -> StringName:
	return TYPE


## Rejects a second dig (&"dig_running"), a dig past the extra levels allowed or with no
## balance (&"level_limit") and too little money (&"insufficient_funds").
func validate(state: GameState) -> CommandResult:
	if state.base.digging_level() != 0:
		return CommandResult.fail(&"dig_running")
	if state.balance == null:
		return CommandResult.fail(&"level_limit", "no balance")
	var index: int = state.base.level_count - state.balance.starting_levels
	if index < 0 or index >= mini(
		state.balance.dig_level_costs_k.size(), state.balance.dig_level_ticks.size()
	):
		return CommandResult.fail(&"level_limit")
	var cost: int = state.balance.dig_level_costs_k[index]
	var funds_error: StringName = state.budget.spend_error(cost)
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error, "needs %dk" % cost)
	return CommandResult.ok()


## Pays and starts digging the new deepest level.
func apply(state: GameState) -> void:
	var index: int = state.base.level_count - state.balance.starting_levels
	state.budget.spend(state.balance.dig_level_costs_k[index])
	state.base.start_dig(state.balance.dig_level_ticks[index])
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data: the type only.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
