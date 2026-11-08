class_name RecallTeamCommand
extends Command
## Recall team (Expeditions tab; docs/content/m3-beyond-the-ring.md section 4, Check-ins are
## automatic): the team's next due check-in becomes its return. A team recalled before its
## last field day brings back nothing for its objective. Posts team_recalled(world id).
## Bible: docs/content/m3-beyond-the-ring.md section 4

## The command's stable type id.
const TYPE: StringName = &"recall_team"
## Refusals: no team away (or the rescue window is open), or already recalled.
const NOT_AWAY: StringName = &"team_not_away"
const ALREADY_RECALLED: StringName = &"team_already_recalled"

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(RecallTeamCommand.new())


## Returns &"recall_team".
func get_type() -> StringName:
	return TYPE


## Rejects a team not AWAY (NOT_AWAY) or already recalled (ALREADY_RECALLED).
func validate(state: GameState) -> CommandResult:
	if state.expedition.mode != ExpeditionState.Mode.AWAY:
		return CommandResult.fail(NOT_AWAY)
	if state.expedition.recalled:
		return CommandResult.fail(ALREADY_RECALLED)
	return CommandResult.ok()


## Marks the team recalled.
func apply(state: GameState) -> void:
	state.expedition.recalled = true
	state.events.post(&"team_recalled", [state.expedition.world_id])


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
