class_name SquadRules
extends RefCounted
## Squads, pure (M4c-05): the soldiers of each Security Post form one squad, named by its
## post's room id and numbered by build order. Members are soldiers assigned to the post, on
## base, not lent, not injured and not out through the Ring.
## Bible: docs/content/m4c-incursions.md sections 2 and 3

## The Security Post room type.
const POST_DEF: StringName = &"room_security_post"
## The soldier role.
const SOLDIER: StringName = &"role_soldier"


## The person ids able to fight in squad [param squad_id] (its post's room id) of [param state].
static func members(state: GameState, squad_id: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	var away: Array[StringName] = []
	if state.expedition.is_out():
		away = state.expedition.member_ids()
	for person: PersonState in state.staff.people:
		if person.room_id != squad_id or person.role != SOLDIER or person.lent:
			continue
		if person.is_injured() or not person.is_on_base(state.clock.tick):
			continue
		if not away.has(person.id):
			found.append(person.id)
	return found


## Every built Security Post of [param state], in build order.
static func posts(state: GameState) -> Array[RoomState]:
	var found: Array[RoomState] = []
	for room: RoomState in state.base.rooms:
		if room.def_id == POST_DEF and room.is_built():
			found.append(room)
	return found


## The cell a squad of post [param room] stands on at home: the post's top-left cell.
static func home_of(room: RoomState) -> Vector3i:
	return Vector3i(room.origin.x, room.origin.y, room.level)


## The squad's number (1, 2, …) by its post's build order, or 0 when it has none.
static func number_of(state: GameState, squad_id: StringName) -> int:
	var index: int = 1
	for squad: SquadState in state.security.squads:
		if squad.post_room == squad_id:
			return index
		index += 1
	return 0


## Makes the squads of [param state] match its posts: a post with a member has a squad (new
## ones stand at home), and a squad whose post has none, or is gone, is removed. Posts
## squad_changed for each squad added or removed.
static func sync(state: GameState) -> void:
	var wanted: Array[SquadState] = []
	for room: RoomState in posts(state):
		if members(state, room.id).is_empty():
			continue
		var squad: SquadState = state.security.squad_of(room.id)
		if squad == null:
			squad = SquadState.new()
			squad.post_room = room.id
			squad.pos = home_of(room)
			squad.target = squad.pos
			state.events.post(&"squad_changed", [room.id])
		wanted.append(squad)
	for squad: SquadState in state.security.squads:
		if not wanted.has(squad):
			state.events.post(&"squad_changed", [squad.post_room])
	state.security.squads = wanted


## Walks [param squad] of [param state] one tick along its path: squad_cells_per_tick steps,
## a change of level costing squad_level_ticks ticks' worth. Arriving holds. Returns true
## when it moved.
static func walk(state: GameState, squad: SquadState) -> bool:
	if squad.order == SquadState.Order.HOLD:
		return false
	var path: PackedVector3Array = BasePaths.find(
		state.base, squad.pos, squad.target, state.room_defs
	)
	if path.size() <= 1:
		squad.order = SquadState.Order.HOLD
		return false
	var budget: int = state.balance.squad_cells_per_tick
	var level_cost: int = state.balance.squad_level_ticks * budget
	var index: int = 1
	while index < path.size():
		var step := Vector3i(int(path[index].x), int(path[index].y), int(path[index].z))
		var cost: int = level_cost if step.z != squad.pos.z else 1
		if cost > budget and index > 1:
			break
		budget -= cost
		squad.pos = step
		index += 1
		if budget <= 0:
			break
	if squad.pos == squad.target:
		squad.order = SquadState.Order.HOLD
	return true
