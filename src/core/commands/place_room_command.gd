class_name PlaceRoomCommand
extends Command
## The player places a room's ghost and holds to build: pays the full cost and starts a site
## (ConstructionSystem builds it). A lift takes the same cells on every dug level, stairs the
## same cells on this level and the one below; either is one site. A lift placed on an
## existing shaft only fills the dug levels the shaft misses, at the lift segment price and
## time (LiftShafts). Stairs and lifts need to touch a connector on one of their levels only,
## so placed from a level above they reach an empty new level, where corridors then join
## them (m25-lean-start.md section 2). Corridors use
## PaintCorridorCommand. Posts room_build_started(site id) and budget_changed when applied.
## Bible: docs/content/m2-base.md sections 1 and 4, docs/content/m25-lean-start.md section 2

## The command's stable type id.
const TYPE: StringName = &"place_room"
## Defs placed on more than one level as one site.
const MULTI_LEVEL_DEFS: Array[StringName] = [StartingBase.LIFT_DEF, BaseRules.STAIRS_DEF]

## Id of the RoomDef to build.
var def_id: StringName = &""
## Level number (1 the top); for stairs, the upper of the two levels.
var level: int = 1
## Top-left cell of the footprint.
var origin: Vector2i = Vector2i.ZERO
## True when turned a quarter turn.
var rotated: bool = false


## Returns a command that builds [param room_def] on [param on_level] at [param at], turned
## when [param turned].
static func create(
	room_def: StringName, on_level: int, at: Vector2i, turned: bool = false
) -> PlaceRoomCommand:
	var command := PlaceRoomCommand.new()
	command.def_id = room_def
	command.level = on_level
	command.origin = at
	command.rotated = turned
	return command


## Rebuilds a command from its to_dict() [param data]. Fails with &"malformed_command" when a
## field is missing or of the wrong type.
static func from_dict(data: Dictionary) -> Result:
	var def_data: Variant = data.get("def_id")
	if not (def_data is String and data.get("rotated") is bool):
		return Result.fail(&"malformed_command", "%s needs def_id and rotated" % TYPE)
	if not (RoomState.is_count(data.get("level")) and RoomState.is_cell(data.get("origin"))):
		return Result.fail(&"malformed_command", "%s needs level and origin" % TYPE)
	var turned: bool = data["rotated"]
	return Result.ok(
		create(
			StringName(str(def_data)),
			RoomState.read_count(data["level"]),
			RoomState.read_cell(data["origin"]),
			turned
		)
	)


## Returns &"place_room".
func get_type() -> StringName:
	return TYPE


## Rejects, in the doc's rule order: an unknown def (&"unknown_room"), a fixed room or a
## corridor (&"not_buildable"), a room research has not unlocked or past the bank cap
## (BaseRules.can_build_room(): &"needs_research", &"needs_staff", &"bank_cap"), a placement
## rule broken on any level (&"not_rotatable",
## &"no_such_level", &"level_not_dug", &"outside_level", &"overlap"), no edge touching a
## corridor, lift or stairs on any of its levels (&"not_connected"), and too little money
## (&"insufficient_funds").
func validate(state: GameState) -> CommandResult:
	var def: RoomDef = state.room_defs.get(def_id)
	var buildable: CommandResult = _buildable(state, def)
	if not buildable.is_ok:
		return buildable
	var planned: Array[RoomState] = _planned(state.base)
	if planned.is_empty():
		return _nothing_planned(state.base)
	var connected: bool = false
	for room: RoomState in planned:
		var error: StringName = BaseRules.placement_error(state.base, state.room_defs, room)
		if not error.is_empty():
			return CommandResult.fail(error, "level %d" % room.level)
		connected = connected or BaseRules.touches_connector(state.base, state.room_defs, room)
	if not connected and not _extends_shaft(state.base):
		return CommandResult.fail(&"not_connected")
	var cost_k: int = cost_of(state)
	var funds_error: StringName = state.budget.spend_error(cost_k)
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error, "needs %dk" % cost_k)
	return CommandResult.ok()


## Why nothing can be planned: the shaft already fills every level (&"overlap"), else
## &"no_such_level".
func _nothing_planned(base: BaseState) -> CommandResult:
	if _extends_shaft(base) and level >= 1 and level <= base.level_count:
		return CommandResult.fail(&"overlap", "level %d" % level)
	return CommandResult.fail(&"no_such_level")


## What the command costs in $k in [param state]: the def's cost, or for a lift extending a
## shaft the segment price per level it adds.
func cost_of(state: GameState) -> int:
	if _extends_shaft(state.base) and state.balance != null:
		return state.balance.lift_segment_cost_k * _planned(state.base).size()
	var def: RoomDef = state.room_defs.get(def_id)
	return 0 if def == null else def.build_cost_k


## Ticks each room of the site takes in [param state]: the def's build time, or for a lift
## extending a shaft the segment time (the ghost shows the same).
func ticks_of(state: GameState) -> int:
	if _extends_shaft(state.base) and state.balance != null:
		return state.balance.lift_segment_ticks
	var def: RoomDef = state.room_defs.get(def_id)
	return 0 if def == null else def.build_ticks


## Pays the cost and adds the site's rooms, unbuilt and switched on.
func apply(state: GameState) -> void:
	var ticks: int = ticks_of(state)
	state.budget.spend(cost_of(state))
	var site_id: StringName = &""
	for planned: RoomState in _planned(state.base):
		var room: RoomState = state.base.add_room(def_id, planned.level, origin)
		room.rotated = rotated
		room.build_ticks_left = maxi(1, ticks)
		if site_id.is_empty():
			site_id = room.id
		room.site = site_id if def_id in MULTI_LEVEL_DEFS else &""
	state.events.post(&"room_build_started", [site_id])
	state.events.post(&"budget_changed", [state.budget.funds_k])


## Returns JSON-safe data: type, def_id, level, origin and rotated.
func to_dict() -> Dictionary:
	return {
		"type": String(TYPE),
		"def_id": String(def_id),
		"level": level,
		"origin": [origin.x, origin.y],
		"rotated": rotated,
	}


## Fails with [method _def_error]'s code, then with BaseRules.can_build_room()'s; else ok.
func _buildable(state: GameState, def: RoomDef) -> CommandResult:
	var def_error: StringName = _def_error(def)
	if not def_error.is_empty():
		return CommandResult.fail(def_error, String(def_id))
	return BaseRules.can_build_room(state, def_id)


## &"unknown_room" without a def, &"not_buildable" for a fixed room or a corridor, else &"".
func _def_error(def: RoomDef) -> StringName:
	if def == null:
		return &"unknown_room"
	if def.fixed or def_id == StartingBase.CORRIDOR_DEF:
		return &"not_buildable"
	return &""


## True when this is a lift placed on an existing shaft: it only fills the levels it misses.
func _extends_shaft(base: BaseState) -> bool:
	return def_id == StartingBase.LIFT_DEF and not LiftShafts.shaft_levels(base, origin).is_empty()


## The rooms this command would add, with empty ids: one per dug level for a lift (the levels
## its shaft misses when one stands at [member origin]), two for
## stairs (empty when the level below does not exist), one otherwise; empty when [member level]
## is not a level of [param base] (a lift's level must exist too).
func _planned(base: BaseState) -> Array[RoomState]:
	var levels: Array[int] = [level]
	if level < 1 or level > base.level_count:
		return []
	if def_id == StartingBase.LIFT_DEF:
		levels.clear()
		var shaft: Array[int] = LiftShafts.shaft_levels(base, origin)
		for number: int in range(1, base.level_count + 1):
			if base.levels[number - 1].is_dug() and not number in shaft:
				levels.append(number)
	elif def_id == BaseRules.STAIRS_DEF:
		if level >= base.level_count:
			return []
		levels.append(level + 1)
	var planned: Array[RoomState] = []
	for number: int in levels:
		var room := RoomState.create(&"", def_id, number, origin)
		room.rotated = rotated
		planned.append(room)
	return planned
