class_name ResearchSystem
extends SimSystem
## Advances each research building's project while the clock runs, the building is on and
## staff of its field are present, at the speed they give (ResearchSpeed); with no staff it
## makes no progress and keeps what it has. A finished project applies its effects, joins
## the done list, posts research_done(project id, room id) and pause_requested(&"research_done"),
## and the bench starts its next queued project. Every hour, projects that have become
## visible are revealed once each, posting research_revealed(project id).
## Bible: docs/content/research-and-progression.md sections 2-3

## Reason of the pause a finished project asks for.
const PAUSE_REASON: StringName = &"research_done"
## How often newly visible projects are looked for, in ticks (an in-game hour); a finished
## project looks at once.
const REVEAL_TICKS: int = 60


## Returns the system id, &"research".
func get_id() -> StringName:
	return &"research"


## Advances every bench; checks for new projects every REVEAL_TICKS.
func tick(state: GameState) -> void:
	if state.clock.tick % REVEAL_TICKS == 0:
		reveal_new(state)
	if state.incursion.is_active() or state.research.benches.is_empty():
		return
	for room_id: StringName in state.research.benches:
		_advance(state, room_id)


## Once a day: benches waiting for money or requirements try their queues again.
func on_day(state: GameState) -> void:
	for room_id: StringName in state.research.benches.keys():
		start_next(state, room_id)


## Records every newly visible project as revealed, posting research_revealed for each.
## Returns how many were revealed.
static func reveal_new(state: GameState) -> int:
	var found: Array[ResearchDef] = ResearchRules.newly_visible(state)
	for def: ResearchDef in found:
		state.research.revealed.append(def.id)
		state.events.post(&"research_revealed", [def.id])
	return found.size()


## Starts [param room_id]'s first queued project when nothing runs there and it can start
## now, posting research_queue_started for the Log.
static func start_next(state: GameState, room_id: StringName) -> bool:
	var bench: ResearchBench = state.research.bench_of(room_id)
	if bench == null or bench.is_running() or bench.queue.is_empty():
		return false
	var next: StringName = bench.queue[0]
	if not ResearchRules.can_start(state, next, room_id).is_ok:
		return false
	StartResearchCommand.begin(state, next, room_id)
	state.events.post(&"research_queue_started", [next, room_id])
	return true


## Applies [param def]'s effects to [param state], marks it done, clears [param room_id]'s
## bench and posts research_done and the pause request.
static func finish(state: GameState, def: ResearchDef, room_id: StringName) -> void:
	StoryRules.apply_all(state, def.effects, def.id)
	if not state.research.is_done(def.id):
		state.research.done.append(def.id)
	var bench: ResearchBench = state.research.bench_of(room_id)
	if bench != null and bench.active == def.id:
		bench.active = &""
		bench.ticks_done = 0
	state.events.post(&"research_done", [def.id, room_id])
	state.events.post(&"pause_requested", [PAUSE_REASON])
	reveal_new(state)


func _advance(state: GameState, room_id: StringName) -> void:
	var bench: ResearchBench = state.research.benches[room_id]
	if not bench.is_running():
		return
	var room: RoomState = state.base.find_room(room_id)
	if room == null:
		return
	var def: ResearchDef = state.research_defs.get(bench.active)
	# A requirement that stops holding (an artefact handed over mid-study) pauses the project.
	if def == null or ResearchRules.first_failing(state, def) != null:
		return
	bench.ticks_done += ResearchSpeed.step(state, room)
	if bench.ticks_done >= ResearchRules.total_ticks(def):
		finish(state, def, room_id)
		start_next(state, room_id)
