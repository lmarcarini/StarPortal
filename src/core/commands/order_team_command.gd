class_name OrderTeamCommand
extends Command
## An order to the team, given through an open gate: on a hail Carry on, Come home now (the
## team walks through this wormhole) or Stay one more day; on the team's call Come through
## (they return now and the mission fails) or Hold on (rescue promised: the call ends and they
## wait for the base to dial).
## Bible: docs/content/interface-rethink.md section 4 (A team can only talk through an open gate)

## The command's stable type id.
const TYPE: StringName = &"order_team"

## The order.
var order: TeamContactRules.Order = TeamContactRules.Order.CARRY_ON


## A command giving [param given].
static func create(given: TeamContactRules.Order) -> OrderTeamCommand:
	var command: OrderTeamCommand = OrderTeamCommand.new()
	command.order = given
	return command


## Rebuilds the command from {"order": name}.
static func from_dict(data: Dictionary) -> Result:
	var index: int = TeamContactRules.ORDER_NAMES.find(str(data.get("order", "")))
	if index < 0:
		return Result.fail(&"malformed_command", "order_team needs a known order")
	return Result.ok(create(index as TeamContactRules.Order))


## Returns &"order_team".
func get_type() -> StringName:
	return TYPE


## Rejects with &"no_team_there" unless [member order] is open now.
func validate(state: GameState) -> CommandResult:
	if not TeamContactRules.open_orders(state).has(order):
		return CommandResult.fail(&"no_team_there")
	return CommandResult.ok()


## Carries the order out (TeamContactRules.give_order).
func apply(state: GameState) -> void:
	TeamContactRules.give_order(state, order)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "order": TeamContactRules.ORDER_NAMES[order]}
