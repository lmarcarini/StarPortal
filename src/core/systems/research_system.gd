class_name ResearchSystem
extends SimSystem
## Advances the running research project while the clock runs and a Research Lab is on, at the
## speed its scientists give (ResearchRules.step(): 25% to 200% of the listed time); with no lab on
## it pauses and keeps its progress. A finished project applies each of its effects through
## UnlockRules.apply_to_game(), is added to the done list, and posts research_done(project id) and
## pause_requested(&"research_done"), which writes the Log line. Draws no power of its own (the lab
## does).
## Bible: docs/content/m25-lean-start.md section 3, docs/content/m26-staff-and-money.md section 3

## Reason of the pause a finished project asks for.
const PAUSE_REASON: StringName = &"research_done"


## Returns the system id, &"research".
func get_id() -> StringName:
	return &"research"


## Adds the speed's ticks of progress to the active project when a lab is on, and finishes it when
## its time is reached. An active id with no def (content changed) is left alone.
func tick(state: GameState) -> void:
	var research: ResearchState = state.research
	if not research.is_running():
		return
	var def: ResearchDef = state.research_defs.get(research.active)
	if def == null or not ResearchRules.has_lab_on(state):
		return
	# A requirement that stops holding (an artefact handed over mid-study) pauses the project
	# until it holds again; the Research tab shows the reason (M4-30).
	if ResearchRules.first_failing(state, def) != null:
		return
	research.ticks_done += ResearchRules.step(state)
	if research.ticks_done >= ResearchRules.total_ticks(def):
		finish(state, def)
		start_next(state)


## Once a day: a queue waiting for money or requirements tries again.
func on_day(state: GameState) -> void:
	if not state.research.is_running():
		start_next(state)


## Starts the first queued project when nothing runs and it can start now (paid at start),
## posting research_queue_started for the Log. Otherwise the queue waits (queue_wait()).
static func start_next(state: GameState) -> bool:
	var research: ResearchState = state.research
	if research.is_running() or research.queue.is_empty():
		return false
	var next: StringName = research.queue[0]
	if not ResearchRules.can_start(state, next).is_ok:
		return false
	StartResearchCommand.begin(state, next)
	state.events.post(&"research_queue_started", [next])
	return true


## Applies [param def]'s effects to [param state], marks it done, clears the active project
## and posts research_done and the pause request.
static func finish(state: GameState, def: ResearchDef) -> void:
	StoryRules.apply_all(state, def.effects, def.id)
	if not state.research.is_done(def.id):
		state.research.done.append(def.id)
	state.research.active = &""
	state.research.ticks_done = 0
	state.events.post(&"research_done", [def.id])
	state.events.post(&"pause_requested", [PAUSE_REASON])
