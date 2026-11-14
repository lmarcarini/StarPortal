class_name IntruderRules
extends RefCounted
## What intruders do once through the Ring, pure (M4c-07): each group walks the shortest
## open path to its objective room (never toward squads), waits at the first sealed door when
## none is open, works the objective while no squad is in the room, then the incursion
## retreats to the Ring and leaves. A group with nobody standing is gone; what it carried
## goes back to holding. The incursion ends when no group is left, posting incursion_ended.
## Bible: docs/content/m4c-incursions.md sections 3 and 5


## At the breach: each group's target room for the def's objective.
static func assign_targets(state: GameState) -> void:
	var objective: StringName = _objective(state)
	for group: IntruderGroup in state.incursion.groups:
		group.target_room = ObjectiveRules.target_room(state, objective)


## One tick of every group (those in [param engaged] fought and stand still), then the end
## check.
static func tick(state: GameState, engaged: Array[IntruderGroup] = []) -> void:
	var incursion: IncursionState = state.incursion
	for group: IntruderGroup in incursion.groups.duplicate():
		if group.standing().is_empty():
			_wipe(state, group)
			continue
		if engaged.has(group):
			continue
		if incursion.phase == IncursionState.Phase.RETREAT:
			_retreat(state, group)
		else:
			_advance(state, group)
	if incursion.phase == IncursionState.Phase.BREACH and _half_down(state):
		incursion.phase = IncursionState.Phase.RETREAT
	if incursion.groups.is_empty():
		finish(state)
	else:
		state.events.post(&"intruders_moved", [])


## Ends the incursion: posts incursion_ended with the report and clears it.
static func finish(state: GameState) -> void:
	var incursion: IncursionState = state.incursion
	var report: Dictionary = incursion.report.duplicate(true)
	report["def"] = String(incursion.def_id)
	report["objective"] = String(_objective(state))
	var outcome: String = "left"
	if report.has("shutter"):
		outcome = "shutter"
	elif not report.has("escaped"):
		outcome = "stopped"
	elif report.get("done", false):
		outcome = "done"
	report["outcome"] = outcome
	_judge(state, report)
	incursion.phase = IncursionState.Phase.NONE
	incursion.groups.clear()
	incursion.report = {}
	incursion.countdown = 0
	state.events.post(&"incursion_ended", [report])


## Walks [param group] of [param state] toward [param goal] by up to squad_cells_per_tick
## cells; with no open path, to the cell before the first sealed door on the way. Returns
## true when it stands on [param goal].
static func walk_toward(state: GameState, group: IntruderGroup, goal: Vector3i) -> bool:
	var from: Vector3i = group.pos()
	if from == goal:
		return true
	var path: PackedVector3Array = BasePaths.find(state.base, from, goal, state.room_defs)
	if path.is_empty():
		path = _to_door(state, from, goal)
		if path.size() <= 1:
			_breach(state, group, goal)
			return false
	var budget: int = state.balance.squad_cells_per_tick
	var at: Vector3i = from
	for index: int in range(1, path.size()):
		var step := Vector3i(int(path[index].x), int(path[index].y), int(path[index].z))
		var cost: int = budget if step.z != at.z else 1
		if cost > budget and at != from:
			break
		budget -= cost
		at = step
		if budget <= 0:
			break
	group.move_to(at)
	return at == goal


## True when a squad stands in room [param room_id].
static func contested(state: GameState, room_id: StringName) -> bool:
	var cells: Dictionary[Vector3i, RoomState] = BasePaths.occupancy(state.base, state.room_defs)
	for squad: SquadState in state.security.squads:
		var room: RoomState = cells.get(squad.pos)
		if room != null and room.id == room_id:
			return true
	return false


static func _advance(state: GameState, group: IntruderGroup) -> void:
	var room_id: StringName = group.target_room
	var goal: Vector3i = ObjectiveRules.target_cell(state, room_id)
	if not walk_toward(state, group, goal):
		return
	var objective: StringName = _objective(state) if not room_id.is_empty() else &"hold"
	var needed: int = ObjectiveRules.WORK_TICKS.get(objective, ObjectiveRules.HOLD_GATE_TICKS)
	if not room_id.is_empty() and contested(state, room_id):
		group.work_ticks = 0
		return
	group.work_ticks += 1
	if needed < 0 or group.work_ticks < needed:
		return
	_complete(state, group, objective)
	state.incursion.phase = IncursionState.Phase.RETREAT


static func _complete(state: GameState, group: IntruderGroup, objective: StringName) -> void:
	var report: Dictionary = state.incursion.report
	match objective:
		&"sabotage":
			var room: RoomState = state.base.find_room(group.target_room)
			if room != null and not room.damaged:
				room.damaged = true
				_append(report, "damaged", String(room.id))
				state.events.post(&"room_damaged", [room.id])
		&"theft":
			var uid: int = ObjectiveRules.loot(state, group.target_room)
			if ArtefactRules.carry(state, uid):
				group.standing()[0].carrying = uid
				_append(report, "stolen", uid)
	if objective != &"hold":
		report["done"] = true


static func _retreat(state: GameState, group: IntruderGroup) -> void:
	if not walk_toward(state, group, IncursionRules.gate_cell(state)):
		return
	for unit: UnitState in group.units:
		if unit.carrying >= 0 and ArtefactRules.lose(state, unit.carrying):
			_append(state.incursion.report, "lost", unit.carrying)
	state.incursion.report["escaped"] = true
	state.incursion.groups.erase(group)


static func _wipe(state: GameState, group: IntruderGroup) -> void:
	for unit: UnitState in group.units:
		if unit.carrying >= 0 and ArtefactRules.recover(state, unit.carrying):
			_append(state.incursion.report, "recovered", unit.carrying)
	var wiped: int = type_convert(state.incursion.report.get("wiped", 0), TYPE_INT)
	state.incursion.report["wiped"] = wiped + 1
	state.incursion.groups.erase(group)


static func _half_down(state: GameState) -> bool:
	var def: IncursionDef = state.incursion_defs.get(state.incursion.def_id)
	if def == null:
		return false
	var total: int = 0
	for count: int in def.group_counts:
		total += count
	var up: int = 0
	for group: IntruderGroup in state.incursion.groups:
		up += group.standing().size()
	return total > 0 and up * 2 <= total


# Works on the sealed door between [param group] and [param goal]: at the group's fastest
# breach time (its standing units' UnitDefs) the door is destroyed (door_changed).
static func _breach(state: GameState, group: IntruderGroup, goal: Vector3i) -> void:
	var at: Vector3i = BasePaths.first_sealed_door(state.base, group.pos(), goal, state.room_defs)
	var door: DoorState = DoorRules.find(state.base, at.z, Vector2i(at.x, at.y))
	if door == null:
		return
	var needed: int = 0
	for unit: UnitState in group.standing():
		var def: UnitDef = state.unit_defs.get(unit.unit)
		var ticks: int = def.door_breach_ticks if def != null else 15
		needed = ticks if needed == 0 else mini(needed, ticks)
	door.breach_ticks += 1
	if door.breach_ticks < needed:
		return
	state.base.doors.erase(door)
	state.events.post(&"door_changed", [door.level, door.cell])


static func _to_door(state: GameState, from: Vector3i, goal: Vector3i) -> PackedVector3Array:
	var door: Vector3i = BasePaths.first_sealed_door(state.base, from, goal, state.room_defs)
	if door == BasePaths.NO_DOOR:
		return PackedVector3Array()
	var full: PackedVector3Array = BasePaths.find(state.base, from, goal, state.room_defs, true)
	var trimmed := PackedVector3Array()
	for point: Vector3 in full:
		if Vector3i(int(point.x), int(point.y), int(point.z)) == door:
			break
		trimmed.append(point)
	return trimmed


# The Committee's reaction to [param report] (m4c-incursions.md section 5).
static func _judge(state: GameState, report: Dictionary) -> void:
	var subject: StringName = StringName(str(report.get("def", "")))
	var before: int = state.committee.confidence
	var losses: bool = report.has("damaged") or report.has("lost")
	if losses:
		ConfidenceEvents.raise(
			state,
			ConfidenceRules.INCURSION_DAMAGE,
			subject,
			Vector2i(1, ConfidenceRules.INCURSION_DAMAGE_CHANGE)
		)
	var stopped: bool = report["outcome"] == "stopped" or report["outcome"] == "shutter"
	if report.has("injured") and not stopped:
		ConfidenceEvents.raise(
			state,
			ConfidenceRules.INCURSION_DOWN,
			subject,
			Vector2i(1, ConfidenceRules.INCURSION_DOWN_CHANGE)
		)
	if stopped and not losses and not report.has("injured"):
		ConfidenceEvents.raise(
			state,
			ConfidenceRules.INCURSION_STOPPED,
			subject,
			Vector2i(1, ConfidenceRules.INCURSION_STOPPED_CHANGE)
		)
	report["confidence"] = (state.committee.confidence - before) / ConfidenceRules.TENTHS


static func _objective(state: GameState) -> StringName:
	var def: IncursionDef = state.incursion_defs.get(state.incursion.def_id)
	return def.objective if def != null else &""


static func _append(report: Dictionary, key: String, value: Variant) -> void:
	var list: Array = report.get(key, [])
	list.append(value)
	report[key] = list
