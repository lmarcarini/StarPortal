class_name OrderMissionCommand
extends Command
## Orders a mission from a closed gate (M4.9-12): readies the plan, then the base dials
## [member address] (at once, or when charged), sends the team once the wormhole opens and
## closes it once they are through (MissionOrderSystem). Refused if the gate is busy, the charge
## is short for the dial plus ten minutes open, the plan is refused, or an incursion is on.
## Bible: docs/content/interface-rethink.md section 4 (Gate, A mission order)

## The command's stable type id.
const TYPE: StringName = &"order_mission"

## The address to dial.
var address: GateAddress = null
## The plan, as PlanExpeditionCommand takes it.
var plan: PlanExpeditionCommand = null
## Wait for the charge instead of refusing.
var when_charged: bool = false


## A command dialling [param target] for [param planned].
static func create(
	target: GateAddress, planned: PlanExpeditionCommand, wait: bool = false
) -> OrderMissionCommand:
	var command: OrderMissionCommand = OrderMissionCommand.new()
	command.address = GateAddress.from_dict(target.to_dict())
	command.plan = planned
	command.when_charged = wait
	return command


## Rebuilds the command from {"address", "plan", "when_charged"}.
static func from_dict(data: Dictionary) -> Result:
	var read: Result = DialCommand.read_address(data.get("address"), TYPE)
	if not read.is_ok:
		return read
	if not data.get("plan") is Dictionary:
		return Result.fail(&"malformed_command", "order_mission needs a plan")
	var plan_data: Dictionary = data["plan"]
	var plan_read: Result = PlanExpeditionCommand.from_dict(plan_data)
	if not plan_read.is_ok:
		return plan_read
	var target: GateAddress = read.value
	var planned: PlanExpeditionCommand = plan_read.value
	var wait: bool = data.get("when_charged", false) == true
	return Result.ok(create(target, planned, wait))


## Returns &"order_mission".
func get_type() -> StringName:
	return TYPE


## Rejects with the order's refusal or the plan's.
func validate(state: GameState) -> CommandResult:
	var why: StringName = MissionOrderRules.refusal(state, address, when_charged)
	if why != &"":
		return CommandResult.fail(why)
	if plan == null:
		return CommandResult.fail(&"no_plan")
	return plan.validate(state)


## Readies the plan and starts the order (dialling at once when the charge is there).
func apply(state: GameState) -> void:
	plan.apply(state)
	var order: MissionOrder = state.expedition.order
	order.world_id = plan.plan.world_id
	order.address = GateAddress.from_dict(address.to_dict())
	order.reason = &""
	order.enter(MissionOrder.Phase.WAIT_CHARGE, state.clock.tick)
	MissionOrderSystem.try_dial(state)
	state.events.post(&"mission_ordered", [order.world_id])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {
		"type": String(TYPE),
		"address": address.to_dict(),
		"plan": plan.to_dict(),
		"when_charged": when_charged,
	}
