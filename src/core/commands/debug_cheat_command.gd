class_name DebugCheatCommand
extends Command
## A cheat for testing (M4.6-04): funds, confidence, charge, finish_research, finish_sites,
## add_staff, standing, grant_artefact, unlock_all_research, heal_all. Goes through the command
## queue like any command and writes a Log line marked "(cheat)". Refused unless cheats are on
## (a debug build, or --cheats on the command line).
## Bible: docs/bible/technical-architecture.md#testing-and-tooling

## The command's stable type id.
const TYPE: StringName = &"debug_cheat"
## The actions.
const ACTIONS: Array[StringName] = [
	&"funds",
	&"confidence",
	&"charge",
	&"finish_research",
	&"finish_sites",
	&"add_staff",
	&"standing",
	&"grant_artefact",
	&"unlock_all_research",
	&"heal_all",
]

## Test hook: overrides whether cheats are on (-1 uses CheatRules.enabled()).
static var force_enabled: int = -1

## One of ACTIONS.
var action: StringName = &""
## Role (add_staff), faction (standing) or artefact def (grant_artefact).
var id: StringName = &""
## $k (funds), Confidence, skill (add_staff) or standing.
var value: int = 0


## A command doing [param what] with [param target] and [param amount].
static func create(
	what: StringName, target: StringName = &"", amount: int = 0
) -> DebugCheatCommand:
	var command := DebugCheatCommand.new()
	command.action = what
	command.id = target
	command.value = amount
	return command


## Rebuilds the command from {"type", "action", "id", "value"}.
static func from_dict(data: Dictionary) -> Result:
	if not data.get("action") is String or not data.get("id") is String:
		return Result.fail(&"malformed_command", "debug_cheat needs action and id")
	if not (data.get("value") is int or data.get("value") is float):
		return Result.fail(&"malformed_command", "debug_cheat needs value")
	var amount: int = type_convert(data["value"], TYPE_INT)
	return Result.ok(create(StringName(str(data["action"])), StringName(str(data["id"])), amount))


## Returns &"debug_cheat".
func get_type() -> StringName:
	return TYPE


## True when cheats are on.
static func cheats_on() -> bool:
	if force_enabled >= 0:
		return force_enabled == 1
	return CheatRules.enabled()


## Rejects when cheats are off (&"cheats_off"), an unknown action (&"bad_action") or an id
## the action cannot use (&"unknown_id").
func validate(state: GameState) -> CommandResult:
	if not cheats_on():
		return CommandResult.fail(&"cheats_off")
	if not ACTIONS.has(action):
		return CommandResult.fail(&"bad_action")
	var known: bool = true
	match action:
		&"standing":
			known = state.faction_defs.has(id)
		&"grant_artefact":
			known = state.artefact_defs.has(id)
		&"add_staff":
			known = String(id).begins_with("role_")
	return CommandResult.ok() if known else CommandResult.fail(&"unknown_id")


## Does the cheat and posts debug_cheat (logged "(cheat)").
func apply(state: GameState) -> void:
	match action:
		&"funds":
			CheatRules.funds(state, value)
		&"confidence":
			CheatRules.confidence(state, value)
		&"charge":
			CheatRules.charge(state)
		&"finish_research":
			CheatRules.finish_research(state)
		&"finish_sites":
			CheatRules.finish_sites(state)
		&"add_staff":
			CheatRules.add_staff(state, id, value)
		&"standing":
			FactionRules.change(state, id, value - FactionRules.standing(state, id), &"DEBUG_CAUSE")
		&"grant_artefact":
			CheatRules.grant_artefact(state, id)
		&"unlock_all_research":
			CheatRules.unlock_all_research(state)
		&"heal_all":
			CheatRules.heal_all(state)
	state.events.post(&"debug_cheat", [action, id, value])


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "action": String(action), "id": String(id), "value": value}
