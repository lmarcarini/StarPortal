class_name AskEmergencyFundsCommand
extends Command
## Committee liaison (O07): ask the Committee for emergency funds, once a month.
## Bible: docs/content/research-and-progression.md section 10

## The command's stable type id.
const TYPE: StringName = &"ask_emergency_funds"

## Rebuilds the command; it has no fields.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(AskEmergencyFundsCommand.new())


## Returns &"ask_emergency_funds".
func get_type() -> StringName:
	return TYPE


## Refuses with &"not_now" without Committee liaison or within a month of the last funds.
func validate(state: GameState) -> CommandResult:
	return (
		CommandResult.ok() if OfficePerks.can_ask_funds(state) else CommandResult.fail(&"not_now")
	)


## Credits the funds and stamps the tick.
func apply(state: GameState) -> void:
	state.budget.credit(OfficePerks.FUNDS_K)
	state.flags[OfficePerks.LAST_FUNDS] = state.clock.tick
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
