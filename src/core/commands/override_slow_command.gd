class_name OverrideSlowCommand
extends Command
## The player's Faster while slowed (docs/content/event-time.md section 2): releases every
## active slow reason that can be overridden and remembers each as overridden, so it does not
## slow again until its event ends. Conversations and incursions cannot be overridden.
## Bible: docs/content/event-time.md section 2

## The command's stable type id.
const TYPE: StringName = &"override_slow"


## A new override.
static func create() -> OverrideSlowCommand:
	return OverrideSlowCommand.new()


## Rebuilds the command from {"type"}.
static func from_dict(_data: Dictionary) -> Result:
	return Result.ok(create())


## Returns &"override_slow".
func get_type() -> StringName:
	return TYPE


## Rejects when no active slow can be overridden (&"nothing_to_override").
func validate(state: GameState) -> CommandResult:
	if not TimeControl.can_override(state.clock):
		return CommandResult.fail(&"nothing_to_override")
	return CommandResult.ok()


## Overrides the overridable slows.
func apply(state: GameState) -> void:
	TimeControl.override(state.clock)


## Returns JSON-safe data.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
