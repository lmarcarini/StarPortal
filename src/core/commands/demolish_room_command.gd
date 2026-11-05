class_name DemolishRoomCommand
extends Command
## The player demolishes a built room: 50% of what was paid for it (RoomState.paid_k) comes
## back at once and the room is off while it comes down, over a quarter of its build time
## (ConstructionSystem removes it). A lift or stairs comes down on all its levels; a corridor
## run one cell at a time. A lift shaft's built segments are part of it (refunded at this
## rate); its segments still building are removed at once at the cancel rate (75% of what was
## paid for them, CancelBuildCommand.SITE_REFUND_PERCENT), so no segment is left alone. The
## people working in the rooms become Unassigned at once (StaffChanges.release(), logged).
## Posts budget_changed when applied.
## Bible: docs/content/m2-base.md section 4, docs/content/m25-lean-start.md section 2,
## docs/content/m26-staff-and-money.md section 3

## The command's stable type id.
const TYPE: StringName = &"demolish_room"
## Percent of a room's cost refunded on demolition, rounded down to whole $k.
const REFUND_PERCENT: int = 50

## Id of the room to demolish.
var room_id: StringName = &""


## Returns a command that demolishes room [param target].
static func create(target: StringName) -> DemolishRoomCommand:
	var command := DemolishRoomCommand.new()
	command.room_id = target
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when
## "room_id" is not a String.
static func from_dict(data: Dictionary) -> Result:
	var value: Variant = data.get("room_id")
	if not value is String:
		return Result.fail(&"malformed_command", "%s needs a string room_id" % TYPE)
	return Result.ok(create(StringName(str(value))))


## The rooms demolishing [param room] takes down in [param base]: the room alone for a
## corridor, every room of its site otherwise.
static func targets(base: BaseState, room: RoomState) -> Array[RoomState]:
	if room.def_id == StartingBase.CORRIDOR_DEF:
		return [room]
	return BaseRules.site_rooms(base, room.site_key())


## What demolishing [param room] of [param state] refunds, in $k: REFUND_PERCENT of what was
## paid for targets(), plus, for a lift, the cancel share of its segments still building.
static func refund_k(state: GameState, room: RoomState) -> int:
	var refund: int = BaseRules.paid_k(targets(state.base, room)) * REFUND_PERCENT / 100
	var building: Array[RoomState] = LiftShafts.building_segments(state.base, room)
	if room.def_id == StartingBase.LIFT_DEF and not building.is_empty():
		refund += BaseRules.paid_k(building) * CancelBuildCommand.SITE_REFUND_PERCENT / 100
	return refund


## Returns &"demolish_room".
func get_type() -> StringName:
	return TYPE


## Rejects an unknown room (&"unknown_room"), a site (&"not_built"), a room already coming
## down (&"already_demolishing"), the Gate and Control Rooms (&"fixed_room"), the last Power
## Plant (&"last_plant"), a room whose beds the people on the roster need (&"beds_needed":
## "Dismiss someone first.") and a connector whose removal
## leaves a room or site touching no corridor, lift or stairs, counting rooms already coming
## down as gone (&"leaves_room_unconnected").
func validate(state: GameState) -> CommandResult:
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = null if room == null else state.room_defs.get(room.def_id)
	if def == null:
		return CommandResult.fail(&"unknown_room", String(room_id))
	if not room.is_built():
		return CommandResult.fail(&"not_built")
	if room.is_demolishing():
		return CommandResult.fail(&"already_demolishing")
	var error: StringName = _protection_error(state, room, def)
	if not error.is_empty():
		return CommandResult.fail(error)
	return CommandResult.ok()


## Refunds refund_k(), removes the shaft's segments still building, and starts taking the
## room down, switched off.
func apply(state: GameState) -> void:
	var room: RoomState = state.base.find_room(room_id)
	var def: RoomDef = state.room_defs[room.def_id]
	var refund: int = refund_k(state, room)
	for segment: RoomState in LiftShafts.building_segments(state.base, room):
		state.base.remove_room(segment.id)
	for target: RoomState in targets(state.base, room):
		target.demolish_ticks_left = maxi(1, def.build_ticks / 4)
		target.powered_on = false
	StaffChanges.release(state, targets(state.base, room))
	PowerSystem.settle(state, room.id if def.power_output_mw > 0.0 else &"")
	state.budget.credit(refund)
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data: type and room_id.
func to_dict() -> Dictionary:
	return {"type": String(TYPE), "room_id": String(room_id)}


## Why [param room] may never come down, or &"".
func _protection_error(state: GameState, room: RoomState, def: RoomDef) -> StringName:
	if def.fixed:
		return &"fixed_room"
	if def.power_output_mw > 0.0 and _plants_left(state) <= 1:
		return &"last_plant"
	if def.beds > 0 and StaffRules.beds_free(state) < def.beds:
		return &"beds_needed"
	if BaseRules.strands_a_room(state.base, state.room_defs, targets(state.base, room)):
		return &"leaves_room_unconnected"
	return &""


## Running plants of the base: built, not coming down and switched on (m2-base.md section 3).
func _plants_left(state: GameState) -> int:
	var count: int = 0
	for other: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(other.def_id)
		if def != null and def.power_output_mw > 0.0 and PowerRules.is_running(other, def):
			count += 1
	return count
