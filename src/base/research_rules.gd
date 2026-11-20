class_name ResearchRules
extends RefCounted
## Pure rules of research (docs/content/research-and-progression.md sections 2-3): which
## projects the player can see, which can start where, and the queues. Each research
## building (a room whose def names a discipline) runs one project with its own queue;
## progress comes from that building's own staff (ResearchSpeed). A project is visible only
## once revealed: done, running or queued, recorded as revealed, or its discipline is open
## (from the start, or by a building) and its needs and reveal conditions hold. Story
## projects never show until the story reveals them. Never touches a Node or an autoload,
## and never changes the state.
## Bible: docs/content/research-and-progression.md sections 2-3

## The Research Lab's def id.
const LAB_DEF: StringName = &"room_research_lab"
## Share of the cost a cancel refunds, in percent.
const REFUND_PERCENT: int = 50
## Disciplines open from the start (section 3): their projects show before their building
## stands (they cannot start until it does).
const START_DISCIPLINES: Array[StringName] = [&"engineering", &"science"]
## Ticks in an hour.
const TICKS_PER_HOUR: int = TimeMath.TICKS_PER_DAY / 24

static var _cached_defs_id: int = 0
static var _cached_size: int = -1
static var _cached_list: Array[ResearchDef] = []


## Every ResearchDef of [param state], in list order (discipline order, then order, then id).
## Cached per set of def objects (the list is read only).
static func projects(state: GameState) -> Array[ResearchDef]:
	var defs_id: int = hash(state.research_defs.values())
	if defs_id == _cached_defs_id and state.research_defs.size() == _cached_size:
		return _cached_list
	var list: Array[ResearchDef] = []
	list.assign(state.research_defs.values())
	list.sort_custom(_before)
	_cached_defs_id = defs_id
	_cached_size = list.size()
	_cached_list = list
	return list


## The research buildings of [param discipline] in [param state] that stand (built, not
## coming down), in base order.
static func buildings(state: GameState, discipline: StringName) -> Array[RoomState]:
	var found: Array[RoomState] = []
	for room: RoomState in state.base.rooms:
		var def: RoomDef = state.room_defs.get(room.def_id)
		if def != null and def.research_discipline == discipline and PowerRules.is_standing(room):
			found.append(room)
	return found


## The open disciplines: those of the start and those with a standing building, in
## ResearchDef.DISCIPLINES order.
static func open_disciplines(state: GameState) -> Array[StringName]:
	var found: Array[StringName] = []
	for discipline: StringName in ResearchDef.DISCIPLINES:
		if discipline in START_DISCIPLINES or not buildings(state, discipline).is_empty():
			found.append(discipline)
	return found


## True when [param def] may be shown: done, running, queued or revealed; or (not a story
## project) its discipline is open, its needs are done and its reveal conditions hold.
static func visible(state: GameState, def: ResearchDef) -> bool:
	var research: ResearchState = state.research
	if research.is_done(def.id) or research.revealed.has(def.id):
		return true
	if not research.room_running(def.id).is_empty() or not research.room_queuing(def.id).is_empty():
		return true
	return reveals_now(state, def)


## True when [param def] (not yet revealed) qualifies to be revealed in [param state].
static func reveals_now(state: GameState, def: ResearchDef) -> bool:
	if def.story:
		return false
	if not def.discipline in START_DISCIPLINES and buildings(state, def.discipline).is_empty():
		return false
	for need: StringName in def.needs:
		if not state.research.is_done(need):
			return false
	return StoryRules.failing(state, def.reveal_when).is_empty()


## True when [param def] is visible, not done, not running or queued, and its start
## requirements hold (it may still wait for money, materials or an idle bench).
static func available(state: GameState, def: ResearchDef) -> bool:
	var research: ResearchState = state.research
	if not visible(state, def) or research.is_done(def.id):
		return false
	if not research.room_running(def.id).is_empty():
		return false
	return first_failing(state, def) == null


## The visible projects of [param state], in list order; with [param discipline], of that
## discipline only. Nothing invisible is ever returned.
static func visible_projects(state: GameState, discipline: StringName = &"") -> Array[ResearchDef]:
	var found: Array[ResearchDef] = []
	for def: ResearchDef in projects(state):
		if (discipline.is_empty() or def.discipline == discipline) and visible(state, def):
			found.append(def)
	return found


## The visible projects not yet recorded as revealed (to reveal, with an event, once).
static func newly_visible(state: GameState) -> Array[ResearchDef]:
	var found: Array[ResearchDef] = []
	if state.research.revealed.size() >= state.research_defs.size():
		return found
	var open: Array[StringName] = open_disciplines(state)
	for def: ResearchDef in projects(state):
		if state.research.revealed.has(def.id) or not def.discipline in open:
			continue
		if visible(state, def):
			found.append(def)
	return found


## Whether [param project_id] may start now in [param room_id] (&"" picks the first idle
## building of its discipline): ok, or failed with &"unknown_project" (also when not
## visible), &"project_done", &"project_running", &"needs_building", &"wrong_building",
## &"bench_busy", &"needs_project" (detail: the first unmet need), &"requirement_unmet",
## &"needs_pieces", &"needs_specimens" or &"insufficient_funds" (detail: the cost in $k).
static func can_start(
	state: GameState, project_id: StringName, room_id: StringName = &""
) -> CommandResult:
	var def: ResearchDef = state.research_defs.get(project_id)
	if def == null or not visible(state, def):
		return CommandResult.fail(&"unknown_project", String(project_id))
	if state.research.is_done(project_id):
		return CommandResult.fail(&"project_done", String(project_id))
	if not state.research.room_running(project_id).is_empty():
		return CommandResult.fail(&"project_running", String(project_id))
	var where: CommandResult = _bench_check(state, def, room_id)
	if not where.is_ok:
		return where
	for need: StringName in def.needs:
		if not state.research.is_done(need):
			return CommandResult.fail(&"needs_project", String(need))
	if first_failing(state, def) != null:
		return CommandResult.fail(&"requirement_unmet", String(project_id))
	var material: StringName = ResearchMaterials.missing(state, def)
	if not material.is_empty():
		return CommandResult.fail(material, String(project_id))
	var funds_error: StringName = state.budget.spend_error(def.cost_k)
	if not funds_error.is_empty():
		return CommandResult.fail(funds_error, "%d" % def.cost_k)
	return CommandResult.ok()


## The room [param def] would start in when the player names none: the first idle building
## of its discipline, else the first; &"" when there is none.
static func pick_room(state: GameState, def: ResearchDef) -> StringName:
	var rooms: Array[RoomState] = buildings(state, def.discipline)
	for room: RoomState in rooms:
		var bench: ResearchBench = state.research.bench_of(room.id)
		if bench == null or not bench.is_running():
			return room.id
	return &"" if rooms.is_empty() else rooms[0].id


## The first of [param def]'s requires that does not hold in [param state], or null.
static func first_failing(state: GameState, def: ResearchDef) -> ConditionDef:
	var failing: Array[ConditionDef] = StoryRules.failing(state, def.requires)
	return null if failing.is_empty() else failing[0]


## Ticks of work [param def] needs: its hours in ticks, the time for a standard crew.
static func total_ticks(def: ResearchDef) -> int:
	return def.hours * TICKS_PER_HOUR


## What cancelling [param def] refunds, in $k: half its cost, rounded down (materials spent
## are not returned).
static func refund_k(def: ResearchDef) -> int:
	return def.cost_k * REFUND_PERCENT / 100


## Why the first queued project of [param room_id] has not started: &"" when nothing waits
## or it runs; &"waiting_for_funds", &"requirements_not_met" or the can_start() code.
static func queue_wait(state: GameState, room_id: StringName) -> StringName:
	var bench: ResearchBench = state.research.bench_of(room_id)
	if bench == null or bench.is_running() or bench.queue.is_empty():
		return &""
	var result: CommandResult = can_start(state, bench.queue[0], room_id)
	if result.is_ok:
		return &""
	match result.error_code:
		&"insufficient_funds":
			return &"waiting_for_funds"
		&"requirement_unmet", &"needs_project", &"needs_pieces", &"needs_specimens":
			return &"requirements_not_met"
	return result.error_code


## Why [param project_id] cannot be queued at [param room_id]: &"" when it can;
## &"unknown_project" (also not visible), &"project_done", &"already_queued",
## &"project_running", &"wrong_building" or &"queue_full".
static func queue_error(
	state: GameState, project_id: StringName, room_id: StringName
) -> StringName:
	var def: ResearchDef = state.research_defs.get(project_id)
	if def == null or not visible(state, def):
		return &"unknown_project"
	if state.research.is_done(project_id):
		return &"project_done"
	if not state.research.room_queuing(project_id).is_empty():
		return &"already_queued"
	if not state.research.room_running(project_id).is_empty():
		return &"project_running"
	if not _is_building_of(state, room_id, def.discipline):
		return &"wrong_building"
	var bench: ResearchBench = state.research.bench_of(room_id)
	var most: int = 5 if state.balance == null else state.balance.research_queue_max
	if bench != null and bench.queue.size() >= most:
		return &"queue_full"
	return &""


static func _bench_check(state: GameState, def: ResearchDef, room_id: StringName) -> CommandResult:
	if buildings(state, def.discipline).is_empty():
		return CommandResult.fail(&"needs_building", String(def.discipline))
	var room: StringName = room_id if not room_id.is_empty() else pick_room(state, def)
	if not _is_building_of(state, room, def.discipline):
		return CommandResult.fail(&"wrong_building", String(room))
	var bench: ResearchBench = state.research.bench_of(room)
	if bench != null and bench.is_running():
		return CommandResult.fail(&"bench_busy", String(bench.active))
	return CommandResult.ok()


static func _is_building_of(state: GameState, room_id: StringName, discipline: StringName) -> bool:
	for room: RoomState in buildings(state, discipline):
		if room.id == room_id:
			return true
	return false


static func _before(a: ResearchDef, b: ResearchDef) -> bool:
	var da: int = ResearchDef.DISCIPLINES.find(a.discipline)
	var db: int = ResearchDef.DISCIPLINES.find(b.discipline)
	if da != db:
		return da < db
	if a.order != b.order:
		return a.order < b.order
	return String(a.id) < String(b.id)
