class_name IncursionRules
extends RefCounted
## Incursions, pure (M4c-06): the daily chance a hostile faction sends one, the cooldown,
## starting the warning and the breach into the Gate Room.
## Bible: docs/content/m4c-incursions.md section 1

## Standing at or below which a faction is hostile enough to send one.
const HOSTILE_STANDING: int = -50
## Days after a faction's last incursion before it may send another.
const COOLDOWN_DAYS: int = 10
## Why an outgoing wormhole closes when the warning starts.
const CLOSE_REASON: StringName = &"incursion"


## The chance a day of a faction at [param standing]: 0 above −50, 2% at −50 rising
## linearly to 10% at −100 and below.
static func daily_chance(standing: int) -> float:
	if standing > HOSTILE_STANDING:
		return 0.0
	var depth: float = clampf(float(HOSTILE_STANDING - standing) / 50.0, 0.0, 1.0)
	return 0.02 + 0.08 * depth


## The IncursionDef ids of [param faction] in [param state], sorted.
static func defs_of(state: GameState, faction: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for def: IncursionDef in state.incursion_defs.values():
		if def.faction == faction:
			ids.append(def.id)
	IdOrder.sort(ids)
	return ids


## True when [param faction] may roll on day [param day]: none under way and its last more
## than COOLDOWN_DAYS ago.
static func off_cooldown(state: GameState, faction: StringName, day: int) -> bool:
	if not state.incursion.last_day.has(faction):
		return true
	return day - state.incursion.last_day[faction] >= COOLDOWN_DAYS


## Starts incursion [param def_id] in [param state]: WARNING with its countdown; closes an
## open outgoing wormhole; posts incursion_warning. Refused while one runs
## (&"incursion_running") or for an unknown def (&"unknown_incursion").
static func start(state: GameState, def_id: StringName) -> CommandResult:
	var def: IncursionDef = state.incursion_defs.get(def_id)
	if def == null:
		return CommandResult.fail(&"unknown_incursion")
	if state.incursion.is_active():
		return CommandResult.fail(&"incursion_running")
	var incursion: IncursionState = state.incursion
	incursion.phase = IncursionState.Phase.WARNING
	incursion.def_id = def_id
	incursion.countdown = maxi(1, def.warning_ticks)
	incursion.groups.clear()
	incursion.last_day[def.faction] = TimeMath.day_index(state.clock.tick)
	close_outgoing(state)
	state.events.post(&"incursion_warning", [def_id])
	return CommandResult.ok()


## Closes an open wormhole the player dialled (an answered incoming one is left alone).
static func close_outgoing(state: GameState) -> void:
	if state.gate.mode == GateState.RingMode.LOCKED and not state.gate.is_incoming_lock():
		RingControl.close(state.gate)
		state.events.post(&"wormhole_closed", [CLOSE_REASON])


## The breach: the def's groups appear in the Gate Room at full health; BREACH.
static func breach(state: GameState) -> void:
	var incursion: IncursionState = state.incursion
	var def: IncursionDef = state.incursion_defs.get(incursion.def_id)
	var at: Vector3i = gate_cell(state)
	incursion.phase = IncursionState.Phase.BREACH
	incursion.countdown = 0
	if def != null:
		for index: int in def.group_units.size():
			incursion.groups.append(
				_group(state, def.group_units[index], def.group_counts[index], at)
			)
	IntruderRules.assign_targets(state)
	state.events.post(&"incursion_breached", [])


## Where intruders arrive: the Gate Room's top-left cell, or (0, 0, 1) without one.
static func gate_cell(state: GameState) -> Vector3i:
	for room: RoomState in state.base.rooms:
		if room.def_id == StartingBase.GATE_ROOM_DEF:
			return Vector3i(room.origin.x, room.origin.y, room.level)
	return Vector3i(0, 0, 1)


static func _group(
	state: GameState, unit_id: StringName, count: int, at: Vector3i
) -> IntruderGroup:
	var group := IntruderGroup.new()
	var unit_def: UnitDef = state.unit_defs.get(unit_id)
	for index: int in count:
		var unit := UnitState.new()
		unit.unit = unit_id
		unit.health = unit_def.health if unit_def != null else 1
		unit.pos = at
		group.units.append(unit)
	return group
