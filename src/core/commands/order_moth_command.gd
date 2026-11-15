class_name OrderMothCommand
extends Command
## Orders a MOTH for the rack (M4c-20): $150k, ready in a day. Posts budget_changed.
## Bible: docs/content/m4c-incursions.md section 6

## The command's stable type id.
const TYPE: StringName = &"order_moth"


## Rebuilds the command from {"type"}.
static func from_dict(_data: Dictionary) -> Result:
	return Result.ok(OrderMothCommand.new())


## Returns &"order_moth".
func get_type() -> StringName:
	return TYPE


## Rejects without a built rack (&"no_rack"), with the rack full counting MOTHs out and on
## order (&"rack_full"), and with too little money (&"insufficient_funds").
func validate(state: GameState) -> CommandResult:
	if not MothRules.has_rack(state):
		return CommandResult.fail(&"no_rack")
	if MothRules.owned(state) >= MothRules.RACK_SIZE:
		return CommandResult.fail(&"rack_full")
	var funds_error: StringName = state.budget.spend_error(MothRules.REORDER_COST_K)
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error)
	return CommandResult.ok()


## Pays and puts it on order.
func apply(state: GameState) -> void:
	state.budget.spend(MothRules.REORDER_COST_K)
	state.probes.reorders.append(state.clock.tick + MothRules.REORDER_TICKS)
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
