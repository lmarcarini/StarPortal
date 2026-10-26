class_name ExtendPoleCameraCommand
extends Command
## While a wormhole is open, the player pushes the Gate Room's pole camera and sampling line
## through the horizon. It takes [constant EXTEND_TICKS] ticks; then DocumentSystem takes the
## world's horizon record, once per world, and delivers the documents it carries. If the wormhole
## closes first, nothing is taken and the camera can go out again on a later lock.
## Bible: game-design.md#base-building-and-power (the pole camera, horizon record),
## gate-and-address-spec.md#the-dialing-sequence-and-an-open-wormhole,
## technical-architecture.md#simulation-clock-and-commands

## The command's stable type id.
const TYPE: StringName = &"extend_pole_camera"
## Ticks from extending the camera to the horizon record.
const EXTEND_TICKS: int = 5

## Rebuilds a command from its to_dict() data; it has no fields, so it always succeeds.
@warning_ignore("unused_parameter")
static func from_dict(data: Dictionary) -> Result:  # gdlint: ignore=unused-argument
	return Result.ok(ExtendPoleCameraCommand.new())


## Returns &"extend_pole_camera".
func get_type() -> StringName:
	return TYPE


## Rejects a Ring with no open wormhole (&"no_wormhole"), a camera already out
## (&"camera_busy") and a world whose horizon record was taken (&"already_taken").
func validate(state: GameState) -> CommandResult:
	if state.gate.mode != GateState.RingMode.LOCKED:
		return CommandResult.fail(&"no_wormhole")
	if state.worlds.is_pole_camera_out():
		return CommandResult.fail(&"camera_busy")
	var world_id: StringName = state.gate.connected_world_id
	if state.worlds.is_horizon_record_taken(world_id):
		return CommandResult.fail(&"already_taken", String(world_id))
	return CommandResult.ok()


## Sends the camera out towards the connected world, [constant EXTEND_TICKS] ticks from its
## horizon record.
func apply(state: GameState) -> void:
	state.worlds.pole_camera_world_id = state.gate.connected_world_id
	state.worlds.pole_camera_ticks_left = EXTEND_TICKS


## Returns JSON-safe data: just the type.
func to_dict() -> Dictionary:
	return {"type": String(TYPE)}
